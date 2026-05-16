extends RefCounted
class_name LlmPolicy

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")
const DecisionValidator = preload("res://ai/llm/decision_validator.gd")
const LlmRequestBuilder = preload("res://ai/llm/llm_request_builder.gd")
const ScriptedPolicyProfile = preload("res://ai/scripted/scripted_policy_profile.gd")

var enabled: bool = true
var llm_client = null
var request_builder := LlmRequestBuilder.new()
var decision_validator := DecisionValidator.new()
var fallback_policy = ScriptedPolicyProfile.new()
var match_context: Dictionary = {}
var _session_key: String = ""
var _session_cache: Dictionary = {}
static var _rules_markdown_loaded: bool = false
static var _rules_markdown_cache: String = ""
const MAX_EXECUTED_HISTORY := 30
const RECENT_HISTORY_WINDOW := 6
const MAX_REPAIR_DEPTH := 2

func set_match_context(context: Dictionary) -> void:
	match_context = context.duplicate(true)
	if fallback_policy != null and fallback_policy.has_method("set_match_context"):
		fallback_policy.set_match_context(context)

func set_enabled(value: bool) -> void:
	enabled = value

func set_llm_client(client) -> void:
	llm_client = client

func choose(engine, state, player_id: int, actions: Array) -> Dictionary:
	if engine == null or state == null or actions.is_empty():
		return {}
	var choose_started_us := _now_usec()
	var fallback_prefetch_started_us := _now_usec()
	var fallback_decision: Dictionary = _choose_fallback(engine, state, player_id, actions, "")
	var fallback_prefetch_ms := _elapsed_ms(fallback_prefetch_started_us)
	var session_refresh_started_us := _now_usec()
	_refresh_session(engine, state, player_id)
	var session_refresh_ms := _elapsed_ms(session_refresh_started_us)
	if not enabled:
		return _attach_root_policy_timing(_choose_fallback(engine, state, player_id, actions, "llm_disabled"), choose_started_us, fallback_prefetch_ms, session_refresh_ms)
	if llm_client == null:
		return _attach_root_policy_timing(_choose_fallback(engine, state, player_id, actions, "llm_client_missing"), choose_started_us, fallback_prefetch_ms, session_refresh_ms)
	return _attach_root_policy_timing(_choose_with_llm(engine, state, player_id, actions, fallback_decision, false, {}, 0), choose_started_us, fallback_prefetch_ms, session_refresh_ms)

func record_executed(decision: Dictionary, waiting_state: Dictionary, result: Dictionary = {}) -> void:
	if decision.is_empty():
		return
	var player_id := int(decision.get("llm_request", {}).get("meta", {}).get("player_id", -1))
	var session_key := _session_key_for_player(player_id)
	if session_key.is_empty():
		return
	var entry := {
		"turn_number": int(decision.get("llm_request", {}).get("observation", {}).get("turn_number", -1)),
		"phase": str(decision.get("llm_request", {}).get("observation", {}).get("phase", "")),
		"player_id": player_id,
		"source": str(decision.get("source", "")),
		"candidate_id": str(decision.get("candidate_id", "")),
		"command_type": str(decision.get("command_type", "")),
		"payload": decision.get("payload", {}).duplicate(true),
		"brief_reason": str(decision.get("brief_reason", "")),
		"repair_attempted": bool(decision.get("repair_attempted", false)),
		"repaired_from": str(decision.get("repaired_from", "")),
		"fallback_reason": str(decision.get("fallback_reason", result.get("fallback_reason", ""))),
		"waiting_state": waiting_state.duplicate(true),
		"result": result.duplicate(true)
	}
	var session: Dictionary = _session_cache.get(session_key, {}).duplicate(true)
	var history: Array = session.get("executed_history", []).duplicate(true)
	history.append(entry)
	if history.size() > MAX_EXECUTED_HISTORY:
		history = history.slice(history.size() - MAX_EXECUTED_HISTORY, history.size())
	session["executed_history"] = history
	_session_cache[session_key] = session

func _choose_with_llm(engine, state, player_id: int, actions: Array, fallback_decision: Dictionary, repair: bool, repair_context: Dictionary, repair_depth: int) -> Dictionary:
	var call_started_us := _now_usec()
	var session: Dictionary = _session_cache.get(_session_key, {}).duplicate(true)
	var history: Array = session.get("executed_history", []).duplicate(true)
	var history_payload := _build_history_payload(history)
	var request_build_started_us := _now_usec()
	var request: Dictionary = request_builder.build_request(
		engine,
		state,
		player_id,
		actions,
		fallback_decision.get("script_analysis", []),
		{
			"match_context": match_context.duplicate(true),
			"history": history_payload.get("recent_entries", []).duplicate(true),
			"history_summary": history_payload.get("summary", {}).duplicate(true),
			"repair": repair_context.duplicate(true) if repair else {}
		}
	)
	var request_build_ms := _elapsed_ms(request_build_started_us)
	request["conversation_messages"] = session.get("conversation_base", []).duplicate(true)
	var llm_response: Dictionary = {}
	var llm_choose_started_us := _now_usec()
	if llm_client.has_method("choose_candidate"):
		llm_response = llm_client.choose_candidate(request)
	var llm_choose_ms := _elapsed_ms(llm_choose_started_us)
	if llm_response.has("error") and str(llm_response.get("candidate_id", "")).is_empty():
		var fallback_started_us := _now_usec()
		var fallback_decision_result := _choose_fallback(engine, state, player_id, actions, "llm_client_%s" % str(llm_response.get("error", "unknown_error")), llm_response)
		var fallback_ms := _elapsed_ms(fallback_started_us)
		return _attach_policy_timing(
			fallback_decision_result,
			_combine_policy_timing(
				_build_policy_stage_trace(repair_depth, request_build_ms, llm_choose_ms, 0.0, fallback_ms, llm_response, "fallback_llm_client_error", str(llm_response.get("error", ""))),
				{},
				_elapsed_ms(call_started_us),
				str(fallback_decision_result.get("source", ""))
			)
		)
	var validation_started_us := _now_usec()
	var validated := decision_validator.validate_response(
		engine,
		state,
		player_id,
		actions,
		llm_response,
		request.get("meta", {}).get("waiting_state", {})
	)
	var validation_ms := _elapsed_ms(validation_started_us)
	if not bool(validated.get("ok", false)):
		var validation_reason := str(validated.get("reason", ""))
		if repair_depth < MAX_REPAIR_DEPTH and validation_reason in ["missing_candidate_id", "candidate_id_not_found", "invalid_json", "invalid_content_json", "validate_failed"]:
			var repair_result := _choose_with_llm(engine, state, player_id, actions, fallback_decision, true, {
				"reason": validation_reason,
				"previous_response": llm_response.duplicate(true),
				"repair_depth": repair_depth + 1,
				"failed_candidate_id": str(validated.get("candidate_id", "")),
				"candidate_digest": _build_candidate_digest(actions),
				"validation": validated.duplicate(true),
				"previous_failures": _append_repair_failure(repair_context.get("previous_failures", []), validation_reason)
			}, repair_depth + 1)
			var merged_timing := _combine_policy_timing(
				_build_policy_stage_trace(repair_depth, request_build_ms, llm_choose_ms, validation_ms, 0.0, llm_response, "repair", validation_reason),
				repair_result.get("timing_trace", {}) if repair_result is Dictionary else {},
				_elapsed_ms(call_started_us),
				str(repair_result.get("source", "")) if repair_result is Dictionary else ""
			)
			if not repair_result.is_empty() and str(repair_result.get("source", "")) == "llm":
				repair_result = repair_result.duplicate(true)
				repair_result["repair_attempted"] = true
				repair_result["repaired_from"] = validation_reason
				repair_result["repair_depth"] = repair_depth + 1
				repair_result["debug_summary"] = "[AI LLM] ok repaired_from=%s %s" % [
					validation_reason,
					str(repair_result.get("debug_summary", "")).trim_prefix("[AI LLM] ")
				]
				return _attach_policy_timing(repair_result, merged_timing)
			if not repair_result.is_empty():
				repair_result = repair_result.duplicate(true)
				repair_result["repair_attempted"] = true
				repair_result["repaired_from"] = validation_reason
				repair_result["repair_depth"] = repair_depth + 1
				repair_result["debug_summary"] = "[AI LLM] fallback after_repair=%s %s" % [
					validation_reason,
					str(repair_result.get("debug_summary", "")).trim_prefix("[AI LLM] ")
				]
				return _attach_policy_timing(repair_result, merged_timing)
		var fallback_started_us := _now_usec()
		var fallback_result := _choose_fallback(engine, state, player_id, actions, str(validated.get("reason", "llm_validation_failed")), llm_response)
		var fallback_ms := _elapsed_ms(fallback_started_us)
		return _attach_policy_timing(
			fallback_result,
			_combine_policy_timing(
				_build_policy_stage_trace(repair_depth, request_build_ms, llm_choose_ms, validation_ms, fallback_ms, llm_response, "fallback_validation_failed", validation_reason),
				{},
				_elapsed_ms(call_started_us),
				str(fallback_result.get("source", ""))
			)
		)
	var response: Dictionary = validated.get("response", {})
	var history_size := history.size()
	var waiting_state := str(request.get("meta", {}).get("waiting_state", {}).get("state", ""))
	return _attach_policy_timing({
		"source": "llm",
		"candidate_id": str(validated.get("candidate_id", "")),
		"command_type": str(validated.get("command_type", "")),
		"payload": validated.get("payload", {}).duplicate(true),
		"description": str(validated.get("candidate", {}).get("description", "")),
		"confidence": float(response.get("confidence", 0.0)),
		"brief_reason": str(response.get("brief_reason", "")),
		"repair_depth": repair_depth,
		"history_size": history_size,
		"debug_summary": "[AI LLM] ok waiting=%s candidate_id=%s confidence=%s history=%s reason=%s" % [
			waiting_state,
			str(validated.get("candidate_id", "")),
			str(response.get("confidence", 0.0)),
			str(history_size),
			str(response.get("brief_reason", ""))
		],
		"llm_request": request,
		"llm_response": response.duplicate(true),
		"fallback_decision": fallback_decision.duplicate(true)
	}, _combine_policy_timing(
		_build_policy_stage_trace(repair_depth, request_build_ms, llm_choose_ms, validation_ms, 0.0, llm_response, "ok", ""),
		{},
		_elapsed_ms(call_started_us),
		"llm"
	))

func _build_candidate_digest(actions: Array) -> Array[Dictionary]:
	var digest: Array[Dictionary] = []
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	for index in range(min(candidates.size(), 12)):
		var candidate: Dictionary = candidates[index]
		digest.append({
			"candidate_id": str(candidate.get("candidate_id", "")),
			"proposal_id": str(candidate.get("proposal_id", "")),
			"command_type": str(candidate.get("command_type", "")),
			"action_group": str(candidate.get("action_group", "")),
			"description": _truncate_text(str(candidate.get("description", "")), 80)
		})
	return digest

func _append_repair_failure(previous_failures_value, reason: String) -> Array[Dictionary]:
	var failures: Array[Dictionary] = []
	if previous_failures_value is Array:
		for item in previous_failures_value:
			if item is Dictionary:
				failures.append((item as Dictionary).duplicate(true))
	failures.append({
		"reason": reason,
		"attempt": failures.size() + 1
	})
	return failures

func _refresh_session(engine, state, player_id: int) -> void:
	var session_key := _session_key_for_player(player_id)
	_session_key = session_key
	if _session_cache.has(session_key):
		return
	var knowledge_payload := _build_knowledge_payload(state, player_id)
	var conversation_base: Array[Dictionary] = []
	conversation_base.append({
		"role": "system",
		"content": "\n".join([
			"这是《十二军团》当前对局的长期会话上下文。",
			"下面会给出本局一次性知识，以及后续步骤中持续追加的历史记录。"
		])
	})
	var rules_markdown := _load_rules_markdown()
	if not rules_markdown.is_empty():
		conversation_base.append({
			"role": "user",
			"content": JSON.stringify({
				"kind": "rules_markdown",
				"content": rules_markdown
			})
		})
	conversation_base.append({
		"role": "user",
		"content": JSON.stringify({
			"kind": "knowledge",
			"knowledge": knowledge_payload.duplicate(true)
		})
	})
	var ai_prompt := str(match_context.get("ai_prompt", ""))
	if not ai_prompt.is_empty():
		conversation_base.append({
			"role": "user",
			"content": JSON.stringify({
				"kind": "ai_prompt",
				"content": ai_prompt
			})
		})
	_session_cache[session_key] = {
		"conversation_base": conversation_base.duplicate(true),
		"executed_history": [],
		"knowledge_payload": knowledge_payload.duplicate(true),
		"rules_markdown": rules_markdown,
		"ai_prompt": ai_prompt
	}

func _session_key_for_player(player_id: int) -> String:
	if player_id < 0:
		return ""
	var deck_id := str(match_context.get("deck_id", "")).strip_edges()
	var match_seed := str(match_context.get("match_seed", match_context.get("seed", ""))).strip_edges()
	return "%s|%s|%s" % [deck_id, match_seed, str(player_id)]

func _build_knowledge_payload(state, player_id: int) -> Dictionary:
	if state == null:
		return {}
	var self_master_id := ""
	var opp_master_id := ""
	var self_player = state.get_player(player_id)
	var opp_player = state.get_player(1 - player_id)
	if self_player != null:
		self_master_id = str(self_player.master_definition_id)
	if opp_player != null:
		opp_master_id = str(opp_player.master_definition_id)
	var self_faction := _faction_from_master(state, self_master_id)
	var opp_faction := _faction_from_master(state, opp_master_id)
	return {
		"factions": {
			"self": self_faction,
			"opponent": opp_faction
		},
		"decks": {
			"self": _build_deck_knowledge(state, player_id),
			"opponent": _build_deck_knowledge(state, 1 - player_id)
		}
	}

func _load_rules_markdown() -> String:
	if _rules_markdown_loaded:
		return _rules_markdown_cache
	_rules_markdown_loaded = true
	var path := "res://规则/规则.md"
	if not FileAccess.file_exists(path):
		_rules_markdown_cache = ""
		return _rules_markdown_cache
	_rules_markdown_cache = FileAccess.get_file_as_string(path)
	return _rules_markdown_cache

func _faction_from_master(state, master_id: String) -> String:
	if master_id.is_empty() or state == null:
		return "neutral"
	var defn = state.get_definition(master_id)
	if defn == null:
		return "neutral"
	var faction := str(defn.faction).strip_edges()
	return faction if not faction.is_empty() else "neutral"

func _build_history_payload(history: Array) -> Dictionary:
	var summary := {
		"entry_count": history.size(),
		"successful_count": 0,
		"failed_count": 0,
		"llm_count": 0,
		"repair_success_count": 0,
		"fallback_count": 0,
		"command_counts": {},
		"waiting_state_counts": {},
		"phase_counts": {}
	}
	var recent_entries: Array[Dictionary] = []
	for entry_value in history:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var result: Dictionary = entry.get("result", {})
		if bool(result.get("ok", false)):
			summary["successful_count"] = int(summary.get("successful_count", 0)) + 1
		else:
			summary["failed_count"] = int(summary.get("failed_count", 0)) + 1
		var source := str(entry.get("source", ""))
		if source == "llm":
			summary["llm_count"] = int(summary.get("llm_count", 0)) + 1
			if bool(entry.get("repair_attempted", false)):
				summary["repair_success_count"] = int(summary.get("repair_success_count", 0)) + 1
		if source.contains("fallback") or not str(entry.get("fallback_reason", "")).is_empty():
			summary["fallback_count"] = int(summary.get("fallback_count", 0)) + 1
		_increment_summary_count(summary, "command_counts", str(entry.get("command_type", "")))
		var waiting_state: Dictionary = entry.get("waiting_state", {})
		_increment_summary_count(summary, "waiting_state_counts", str(waiting_state.get("state", "")))
		_increment_summary_count(summary, "phase_counts", str(entry.get("phase", "")))
	var recent_start: int = max(0, history.size() - RECENT_HISTORY_WINDOW)
	for index in range(recent_start, history.size()):
		if history[index] is Dictionary:
			recent_entries.append(_compact_history_entry(history[index]))
	return {
		"summary": summary,
		"recent_entries": recent_entries
	}

func _compact_history_entry(entry: Dictionary) -> Dictionary:
	var waiting_state: Dictionary = entry.get("waiting_state", {})
	var result: Dictionary = entry.get("result", {})
	return {
		"turn_number": int(entry.get("turn_number", -1)),
		"phase": str(entry.get("phase", "")),
		"source": str(entry.get("source", "")),
		"candidate_id": str(entry.get("candidate_id", "")),
		"command_type": str(entry.get("command_type", "")),
		"brief_reason": _truncate_text(str(entry.get("brief_reason", "")), 80),
		"waiting_state": str(waiting_state.get("state", "")),
		"repair_attempted": bool(entry.get("repair_attempted", false)),
		"repaired_from": str(entry.get("repaired_from", "")),
		"fallback_reason": str(entry.get("fallback_reason", "")),
		"result_ok": bool(result.get("ok", false))
	}

func _increment_summary_count(summary: Dictionary, field: String, key: String) -> void:
	if key.is_empty():
		return
	var counts: Dictionary = summary.get(field, {})
	counts[key] = int(counts.get(key, 0)) + 1
	summary[field] = counts

func _build_deck_knowledge(state, player_id: int) -> Dictionary:
	if state == null or player_id < 0:
		return {}
	var player = state.get_player(player_id)
	var master_id := ""
	var master_name := ""
	if player != null:
		master_id = str(player.master_definition_id)
		master_name = str(player.master_name)
	var initial_deck: Array = []
	if player_id < state.initial_decks.size() and state.initial_decks[player_id] is Array:
		initial_deck = (state.initial_decks[player_id] as Array).duplicate(true)
	var card_counts: Dictionary = {}
	for raw_card_id in initial_deck:
		var card_id := str(raw_card_id)
		if card_id.is_empty():
			continue
		card_counts[card_id] = int(card_counts.get(card_id, 0)) + 1
	var cards: Array[Dictionary] = []
	var sorted_ids := card_counts.keys()
	sorted_ids.sort()
	for raw_definition_id in sorted_ids:
		var definition_id := str(raw_definition_id)
		var definition = state.get_definition(definition_id)
		if definition == null:
			continue
		cards.append({
			"definition_id": definition_id,
			"count": int(card_counts.get(definition_id, 0)),
			"definition": _serialize_card_definition(definition)
		})
	return {
		"player_id": player_id,
		"master_id": master_id,
		"master_name": master_name,
		"deck_size": initial_deck.size(),
		"cards": cards
	}

func _serialize_card_definition(definition) -> Dictionary:
	if definition == null:
		return {}
	return {
		"id": str(definition.id),
		"name": str(definition.name),
		"faction": str(definition.faction),
		"type": str(definition.type),
		"subtypes": definition.subtypes.duplicate(true),
		"troop_type": str(definition.troop_type),
		"cost": int(definition.cost),
		"power": int(definition.power),
		"hp": int(definition.hp),
		"calamity_level": int(definition.calamity_level),
		"limit": int(definition.limit),
		"traits": definition.traits.duplicate(true),
		"keywords": definition.keywords.duplicate(true),
		"effects": definition.effects.duplicate(true),
		"play_options": definition.play_options.duplicate(true),
		"text": str(definition.text),
		"image_path": str(definition.image_path),
		"source": definition.source.duplicate(true)
	}

func _choose_fallback(engine, state, player_id: int, actions: Array, reason: String, llm_response: Dictionary = {}) -> Dictionary:
	var decision: Dictionary = {}
	var response_summary := _summarize_llm_response(llm_response)
	if fallback_policy != null and fallback_policy.has_method("choose"):
		decision = fallback_policy.choose(engine, state, player_id, actions)
	if not decision.is_empty():
		decision = decision.duplicate(true)
		decision["source"] = "scripted_fallback"
		decision["fallback_reason"] = reason
		decision["llm_response"] = llm_response.duplicate(true)
		decision["llm_response_summary"] = response_summary
		decision["debug_summary"] = "[AI LLM] fallback reason=%s command=%s candidate_id=%s response=%s" % [
			reason,
			str(decision.get("command_type", "")),
			str(decision.get("candidate_id", "")),
			response_summary
		]
		return decision
	var expanded: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	if not expanded.is_empty():
		var candidate: Dictionary = expanded[0]
		return {
			"source": "first_candidate_fallback",
			"fallback_reason": reason,
			"candidate_id": str(candidate.get("candidate_id", "")),
			"command_type": str(candidate.get("command_type", "")),
			"payload": candidate.get("payload", {}).duplicate(true),
			"description": str(candidate.get("description", "")),
			"script_analysis": [],
			"llm_response": llm_response.duplicate(true),
			"llm_response_summary": response_summary,
			"debug_summary": "[AI LLM] fallback reason=%s first_candidate command=%s candidate_id=%s response=%s" % [
				reason,
				str(candidate.get("command_type", "")),
				str(candidate.get("candidate_id", "")),
				response_summary
			]
		}
	return {}

func _attach_root_policy_timing(decision: Dictionary, choose_started_us: int, fallback_prefetch_ms: float, session_refresh_ms: float) -> Dictionary:
	if decision.is_empty():
		return decision
	var updated := decision.duplicate(true)
	var timing_trace: Dictionary = updated.get("timing_trace", {}).duplicate(true)
	if timing_trace.is_empty():
		timing_trace = {
			"kind": "llm_policy",
			"summary": {},
			"stages": []
		}
	var summary: Dictionary = timing_trace.get("summary", {}).duplicate(true)
	summary["choose_total_ms"] = _elapsed_ms(choose_started_us)
	summary["fallback_prefetch_ms"] = fallback_prefetch_ms
	summary["session_refresh_ms"] = session_refresh_ms
	summary["final_source"] = str(updated.get("source", summary.get("final_source", "")))
	timing_trace["summary"] = summary
	updated["timing_trace"] = timing_trace
	updated["timing_summary"] = _build_timing_summary_text(timing_trace)
	updated["debug_summary"] = _append_timing_summary(str(updated.get("debug_summary", "")), str(updated.get("timing_summary", "")))
	return updated

func _attach_policy_timing(decision: Dictionary, timing_trace: Dictionary) -> Dictionary:
	if decision.is_empty():
		return decision
	var updated := decision.duplicate(true)
	updated["timing_trace"] = timing_trace.duplicate(true)
	updated["timing_summary"] = _build_timing_summary_text(timing_trace)
	updated["debug_summary"] = _append_timing_summary(str(updated.get("debug_summary", "")), str(updated.get("timing_summary", "")))
	return updated

func _combine_policy_timing(stage_trace: Dictionary, child_timing: Dictionary = {}, policy_total_ms: float = -1.0, final_source: String = "") -> Dictionary:
	var stages: Array[Dictionary] = [stage_trace.duplicate(true)]
	if child_timing is Dictionary and not child_timing.is_empty():
		var child_stages = child_timing.get("stages", [])
		if child_stages is Array:
			for stage_value in child_stages:
				if stage_value is Dictionary:
					stages.append((stage_value as Dictionary).duplicate(true))
	var llm_call_count := 0
	var transport_attempt_count := 0
	var retry_count := 0
	for stage in stages:
		if float(stage.get("llm_choose_ms", 0.0)) > 0.0:
			llm_call_count += 1
		transport_attempt_count += int(stage.get("llm_transport_attempt_count", 0))
		retry_count += int(stage.get("retry_count", 0))
	return {
		"kind": "llm_policy",
		"summary": {
			"policy_total_ms": policy_total_ms if policy_total_ms >= 0.0 else _sum_stage_field(stages, "self_total_ms"),
			"request_build_total_ms": _sum_stage_field(stages, "request_build_ms"),
			"llm_choose_total_ms": _sum_stage_field(stages, "llm_choose_ms"),
			"validation_total_ms": _sum_stage_field(stages, "validation_ms"),
			"fallback_total_ms": _sum_stage_field(stages, "fallback_ms"),
			"network_total_ms": _sum_stage_field(stages, "network_ms"),
			"llm_call_count": llm_call_count,
			"transport_attempt_count": transport_attempt_count,
			"retry_count": retry_count,
			"repair_count": max(0, stages.size() - 1),
			"final_source": final_source
		},
		"stages": stages
	}

func _build_policy_stage_trace(repair_depth: int, request_build_ms: float, llm_choose_ms: float, validation_ms: float, fallback_ms: float, llm_response: Dictionary, result: String, validation_reason: String) -> Dictionary:
	var llm_response_timing: Dictionary = llm_response.get("timing_trace", {})
	var client_summary: Dictionary = llm_response_timing.get("summary", {}) if llm_response_timing is Dictionary else {}
	return {
		"repair_depth": repair_depth,
		"result": result,
		"validation_reason": validation_reason,
		"request_build_ms": request_build_ms,
		"llm_choose_ms": llm_choose_ms,
		"validation_ms": validation_ms,
		"fallback_ms": fallback_ms,
		"self_total_ms": request_build_ms + llm_choose_ms + validation_ms + fallback_ms,
		"network_ms": float(client_summary.get("network_total_ms", 0.0)),
		"llm_transport_attempt_count": int(client_summary.get("attempt_count", 0)),
		"retry_count": int(client_summary.get("retry_count", 0)),
		"llm_response_timing": llm_response_timing.duplicate(true) if llm_response_timing is Dictionary else {}
	}

func _build_timing_summary_text(timing_trace: Dictionary) -> String:
	var summary: Dictionary = timing_trace.get("summary", {})
	return "choose=%sms policy=%sms net=%sms llm=%sms validate=%sms fallback=%sms repairs=%s retries=%s attempts=%s" % [
		_format_ms(summary.get("choose_total_ms", summary.get("policy_total_ms", 0.0))),
		_format_ms(summary.get("policy_total_ms", 0.0)),
		_format_ms(summary.get("network_total_ms", 0.0)),
		_format_ms(summary.get("llm_choose_total_ms", 0.0)),
		_format_ms(summary.get("validation_total_ms", 0.0)),
		_format_ms(summary.get("fallback_total_ms", 0.0)),
		str(int(summary.get("repair_count", 0))),
		str(int(summary.get("retry_count", 0))),
		str(int(summary.get("transport_attempt_count", 0)))
	]

func _append_timing_summary(debug_summary: String, timing_summary: String) -> String:
	if timing_summary.is_empty():
		return debug_summary
	var base := debug_summary
	var timing_index := base.find(" timing=")
	if timing_index >= 0:
		base = base.substr(0, timing_index)
	if base.is_empty():
		return "timing=%s" % timing_summary
	return "%s timing=%s" % [base, timing_summary]

func _sum_stage_field(stages: Array[Dictionary], field: String) -> float:
	var total := 0.0
	for stage in stages:
		total += float(stage.get(field, 0.0))
	return total

func _format_ms(value) -> String:
	return "%.1f" % float(value)

func _now_usec() -> int:
	return Time.get_ticks_usec()

func _elapsed_ms(started_us: int) -> float:
	return max(0.0, float(Time.get_ticks_usec() - started_us) / 1000.0)

func _summarize_llm_response(llm_response: Dictionary) -> String:
	if llm_response.is_empty():
		return "none"
	var parts: Array[String] = []
	if llm_response.has("error"):
		parts.append("error=%s" % str(llm_response.get("error", "")))
	if llm_response.has("status_code"):
		parts.append("status=%s" % str(llm_response.get("status_code", "")))
	if llm_response.has("candidate_id"):
		parts.append("candidate_id=%s" % str(llm_response.get("candidate_id", "")))
	if llm_response.has("content"):
		parts.append("content=%s" % _truncate_text(str(llm_response.get("content", "")), 120))
	if llm_response.has("brief_reason"):
		parts.append("brief_reason=%s" % _truncate_text(str(llm_response.get("brief_reason", "")), 80))
	if llm_response.has("body"):
		parts.append("body=%s" % _truncate_text(str(llm_response.get("body", "")), 160))
	if parts.is_empty():
		parts.append(_truncate_text(JSON.stringify(llm_response), 200))
	return " | ".join(parts)

func _truncate_text(value: String, limit: int) -> String:
	var compact := value.replace("\n", "\\n").replace("\r", "")
	if compact.length() <= limit:
		return compact
	return "%s..." % compact.substr(0, limit)
