extends RefCounted
class_name AiController

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")
const LlmPolicy = preload("res://ai/llm/llm_policy.gd")
const ScriptedPolicyProfile = preload("res://ai/scripted/scripted_policy_profile.gd")

const POLICY_MODE_SCRIPTED := "scripted"
const POLICY_MODE_LLM := "llm"

static var _last_state_signature_by_owner: Dictionary = {}

var policy = null
var policy_mode: String = POLICY_MODE_SCRIPTED
var _match_context: Dictionary = {}
var _llm_client_override = null

func set_policy(p_policy) -> void:
	policy = p_policy
	_apply_match_context()

func set_policy_mode(mode: String, options: Dictionary = {}) -> void:
	var requested_mode := str(mode).to_lower()
	if requested_mode != POLICY_MODE_LLM:
		requested_mode = POLICY_MODE_SCRIPTED
	policy_mode = requested_mode
	if policy_mode == POLICY_MODE_LLM:
		var llm_policy := LlmPolicy.new()
		llm_policy.set_enabled(bool(options.get("enabled", true)))
		var configured_client = options.get("llm_client", _llm_client_override)
		if configured_client != null and llm_policy.has_method("set_llm_client"):
			llm_policy.set_llm_client(configured_client)
		set_policy(llm_policy)
		return
	set_policy(ScriptedPolicyProfile.new())

func get_policy_mode() -> String:
	return policy_mode

func set_match_context(context: Dictionary) -> void:
	_match_context = context.duplicate(true)
	_apply_match_context()

func set_llm_client(client) -> void:
	_llm_client_override = client
	if policy_mode == POLICY_MODE_LLM and policy != null and policy.has_method("set_llm_client"):
		policy.set_llm_client(client)

func get_llm_client():
	return _llm_client_override

func _apply_match_context() -> void:
	if policy == null:
		return
	if policy.has_method("set_match_context"):
		policy.set_match_context(_match_context.duplicate(true))

func drive_table_step(table, display_player_id: int, actions: Array) -> bool:
	if table == null or policy == null:
		return false
	if table._state == null or table._game_over:
		_clear_owner(table)
		return false
	var controller_started_us := _now_usec()
	var policy_started_us := _now_usec()
	var decision: Dictionary = policy.choose(table._engine, table._state, table._logical_player_for_display(display_player_id), actions)
	decision = _attach_controller_timing(decision, {
		"policy_choose_ms": _elapsed_ms(policy_started_us)
	})
	if decision.is_empty():
		return _fallback_table_step(table, display_player_id, actions, "empty_decision")
	var command_type := str(decision.get("command_type", ""))
	var payload: Dictionary = decision.get("payload", {})
	if command_type.is_empty() or (payload.is_empty() and command_type != "PassPriority" and command_type != "EndPhase"):
		return _fallback_table_step(table, display_player_id, actions, "invalid_decision")
	var debug_summary := str(decision.get("debug_summary", ""))
	if not debug_summary.is_empty() and table.has_method("_append_file_log"):
		table._append_file_log(debug_summary)
	var execute_started_us := _now_usec()
	if table._execute_command(display_player_id, command_type, payload):
		decision = _attach_controller_timing(decision, {
			"execute_ms": _elapsed_ms(execute_started_us),
			"controller_total_ms": _elapsed_ms(controller_started_us)
		})
		_record_execution(table, display_player_id, decision, {"ok": true})
		return true
	decision = _attach_controller_timing(decision, {
		"execute_ms": _elapsed_ms(execute_started_us),
		"controller_total_ms": _elapsed_ms(controller_started_us)
	})
	return _fallback_table_step(table, display_player_id, actions, "failed_execute", command_type, payload, decision)

func drive_engine_step(engine, state, player_id: int, actions: Array) -> Dictionary:
	if engine == null or state == null or policy == null:
		return {}
	if actions.is_empty():
		return {}
	var policy_started_us := _now_usec()
	var decision: Dictionary = policy.choose(engine, state, player_id, actions)
	decision = _attach_controller_timing(decision, {
		"policy_choose_ms": _elapsed_ms(policy_started_us)
	})
	var command_type := str(decision.get("command_type", ""))
	var payload: Dictionary = decision.get("payload", {})
	if not command_type.is_empty() and (not payload.is_empty() or command_type == "PassPriority" or command_type == "EndPhase"):
		return decision
	var waiting: Dictionary = engine.get_waiting_state(state)
	var waiting_state := str(waiting.get("state", ""))
	if waiting_state == "WaitingForPriority":
		for action in actions:
			if str(action.get("kind", "")) != "pass_priority":
				continue
			return {
				"command_type": str(action.get("command_type", "PassPriority")),
				"payload": action.get("payload_template", {}).duplicate(true)
			}
	var expanded: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	if not expanded.is_empty():
		var candidate: Dictionary = expanded[0]
		return {
			"command_type": str(candidate.get("command_type", "")),
			"payload": candidate.get("payload", {}).duplicate(true)
		}
	for action in actions:
		if str(action.get("kind", "")) != "end_phase":
			continue
		return {
			"command_type": str(action.get("command_type", "EndPhase")),
			"payload": action.get("payload_template", {}).duplicate(true)
		}
	return {}

func _fallback_table_step(table, display_player_id: int, actions: Array, reason: String, failed_command_type: String = "", failed_payload: Dictionary = {}, original_decision: Dictionary = {}) -> bool:
	if table == null or table._state == null or actions.is_empty():
		return false
	var fallback_started_us := _now_usec()
	var waiting: Dictionary = table._engine.get_waiting_state(table._state)
	var waiting_state := str(waiting.get("state", ""))
	if waiting_state == "WaitingForPriority":
		for action in actions:
			if str(action.get("kind", "")) != "pass_priority":
				continue
			if table.has_method("_append_file_log"):
				table._append_file_log("[AI FALLBACK] reason=%s pass_priority after failed %s payload=%s" % [
					reason,
					failed_command_type,
					JSON.stringify(failed_payload)
				])
			var execute_started_us := _now_usec()
			if table._execute_command(display_player_id, str(action.get("command_type", "PassPriority")), action.get("payload_template", {})):
				_record_execution(table, display_player_id, _attach_controller_timing({
					"source": "fallback",
					"candidate_id": "",
					"command_type": str(action.get("command_type", "PassPriority")),
					"payload": action.get("payload_template", {}).duplicate(true),
					"brief_reason": reason
				}, {
					"fallback_ms": _elapsed_ms(fallback_started_us),
					"fallback_execute_ms": _elapsed_ms(execute_started_us)
				}), {"ok": true, "fallback_reason": reason, "failed": original_decision.duplicate(true)})
				return true
			_record_execution(table, display_player_id, _attach_controller_timing(original_decision, {
				"fallback_ms": _elapsed_ms(fallback_started_us),
				"fallback_execute_ms": _elapsed_ms(execute_started_us)
			}), {"ok": false, "fallback_reason": reason})
			return false
	var expanded: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	var failed_payload_text := JSON.stringify(failed_payload)
	for candidate in expanded:
		var command_type := str(candidate.get("command_type", ""))
		var payload: Dictionary = candidate.get("payload", {}).duplicate(true)
		if command_type.is_empty():
			continue
		if payload.is_empty() and command_type != "PassPriority" and command_type != "EndPhase":
			continue
		if not failed_command_type.is_empty() and command_type == failed_command_type and JSON.stringify(payload) == failed_payload_text:
			continue
		if table.has_method("_append_file_log"):
			table._append_file_log("[AI FALLBACK] reason=%s execute %s payload=%s" % [
				reason,
				command_type,
				JSON.stringify(payload)
			])
		var execute_started_us := _now_usec()
		if table._execute_command(display_player_id, command_type, payload):
			_record_execution(table, display_player_id, _attach_controller_timing({
				"source": "fallback",
				"candidate_id": str(candidate.get("candidate_id", "")),
				"command_type": command_type,
				"payload": payload.duplicate(true),
				"brief_reason": reason
			}, {
				"fallback_ms": _elapsed_ms(fallback_started_us),
				"fallback_execute_ms": _elapsed_ms(execute_started_us)
			}), {"ok": true, "fallback_reason": reason, "failed": original_decision.duplicate(true)})
			return true
	for action in actions:
		if str(action.get("kind", "")) != "end_phase":
			continue
		if table.has_method("_append_file_log"):
			table._append_file_log("[AI FALLBACK] reason=%s force end_phase" % reason)
		var execute_started_us := _now_usec()
		if table._execute_command(display_player_id, str(action.get("command_type", "EndPhase")), action.get("payload_template", {})):
			_record_execution(table, display_player_id, _attach_controller_timing({
				"source": "fallback",
				"candidate_id": "",
				"command_type": str(action.get("command_type", "EndPhase")),
				"payload": action.get("payload_template", {}).duplicate(true),
				"brief_reason": reason
			}, {
				"fallback_ms": _elapsed_ms(fallback_started_us),
				"fallback_execute_ms": _elapsed_ms(execute_started_us)
			}), {"ok": true, "fallback_reason": reason, "failed": original_decision.duplicate(true)})
			return true
		_record_execution(table, display_player_id, _attach_controller_timing(original_decision, {
			"fallback_ms": _elapsed_ms(fallback_started_us),
			"fallback_execute_ms": _elapsed_ms(execute_started_us)
		}), {"ok": false, "fallback_reason": reason})
		return false
	_record_execution(table, display_player_id, _attach_controller_timing(original_decision, {
		"fallback_ms": _elapsed_ms(fallback_started_us)
	}), {"ok": false, "fallback_reason": reason})
	return false

func _record_execution(table, display_player_id: int, decision: Dictionary, result: Dictionary) -> void:
	if table == null or table._engine == null or table._state == null:
		return
	if table.has_method("_append_ai_raw_log_from_decision"):
		table._append_ai_raw_log_from_decision(display_player_id, decision.duplicate(true), result.duplicate(true))
	if table.has_method("_record_ai_decision_status"):
		table._record_ai_decision_status(decision.duplicate(true), result.duplicate(true))
	_record_policy_execution(table._engine, table._state, decision, result)

func record_engine_execution(engine, state, decision: Dictionary, result: Dictionary) -> void:
	if engine == null or state == null:
		return
	_record_policy_execution(engine, state, decision, result)

func _record_policy_execution(engine, state, decision: Dictionary, result: Dictionary) -> void:
	if engine == null or state == null:
		return
	if policy == null or not policy.has_method("record_executed"):
		return
	var waiting: Dictionary = engine.get_waiting_state(state)
	policy.record_executed(decision.duplicate(true), waiting.duplicate(true), result.duplicate(true))

func _clear_owner(table) -> void:
	if table == null:
		return
	var owner_id: int = int(table.get_instance_id())
	_last_state_signature_by_owner.erase(owner_id)

func _attach_controller_timing(decision: Dictionary, controller_fields: Dictionary) -> Dictionary:
	if decision.is_empty():
		return decision
	var updated := decision.duplicate(true)
	var timing_trace: Dictionary = updated.get("timing_trace", {}).duplicate(true)
	var controller: Dictionary = timing_trace.get("controller", {}).duplicate(true)
	for key_value in controller_fields.keys():
		var key := str(key_value)
		controller[key] = controller_fields.get(key_value)
	timing_trace["controller"] = controller
	updated["timing_trace"] = timing_trace
	var controller_summary := _build_controller_timing_summary(controller)
	if not controller_summary.is_empty():
		updated["timing_summary"] = _append_controller_summary(str(updated.get("timing_summary", "")), controller_summary)
		updated["debug_summary"] = _append_controller_summary(str(updated.get("debug_summary", "")), controller_summary)
	return updated

func _build_controller_timing_summary(controller: Dictionary) -> String:
	if controller.is_empty():
		return ""
	var parts: Array[String] = []
	if controller.has("policy_choose_ms"):
		parts.append("ctrl_policy=%sms" % _format_ms(controller.get("policy_choose_ms", 0.0)))
	if controller.has("execute_ms"):
		parts.append("ctrl_exec=%sms" % _format_ms(controller.get("execute_ms", 0.0)))
	if controller.has("fallback_ms"):
		parts.append("ctrl_fallback=%sms" % _format_ms(controller.get("fallback_ms", 0.0)))
	if controller.has("fallback_execute_ms"):
		parts.append("ctrl_fallback_exec=%sms" % _format_ms(controller.get("fallback_execute_ms", 0.0)))
	if controller.has("controller_total_ms"):
		parts.append("ctrl_total=%sms" % _format_ms(controller.get("controller_total_ms", 0.0)))
	return " ".join(parts)

func _append_controller_summary(text: String, controller_summary: String) -> String:
	if controller_summary.is_empty():
		return text
	var base := text
	var ctrl_index := base.find(" ctrl_")
	if ctrl_index >= 0:
		base = base.substr(0, ctrl_index)
	if base.is_empty():
		return controller_summary
	return "%s %s" % [base, controller_summary]

func _format_ms(value) -> String:
	return "%.1f" % float(value)

func _now_usec() -> int:
	return Time.get_ticks_usec()

func _elapsed_ms(started_us: int) -> float:
	return max(0.0, float(Time.get_ticks_usec() - started_us) / 1000.0)
