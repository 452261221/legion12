extends RefCounted
class_name LlmRequestBuilder

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")
const ObservationBuilder = preload("res://ai/core/observation_builder.gd")

var observation_builder := ObservationBuilder.new()

func build_request(engine, state, player_id: int, actions: Array, script_analysis: Array = [], extra: Dictionary = {}) -> Dictionary:
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	var observation: Dictionary = observation_builder.build(engine, state, player_id)
	var waiting_state: Dictionary = engine.get_waiting_state(state).duplicate(true)
	var sanitized_candidates: Array[Dictionary] = _sanitize_candidates(candidates)
	var opening_protocol_trim := _should_apply_opening_protocol_trim(observation, candidates.size(), extra)
	var meta := {
		"player_id": player_id,
		"candidate_count": candidates.size(),
		"waiting_state": waiting_state.duplicate(true),
		"extra": extra.duplicate(true),
		"opening_protocol_trim": opening_protocol_trim
	}
	return {
		"task": "choose_one_candidate",
		"versions": {
			"observation_schema": 1,
			"candidate_schema": 1,
			"prompt": 1,
			"knowledge": 1
		},
		"observation": observation,
		"candidates": sanitized_candidates,
		"card_refs": [],
		"rule_refs": [],
		"script_analysis": script_analysis.duplicate(true),
		"context": _build_context(player_id, waiting_state, candidates.size(), sanitized_candidates, extra, opening_protocol_trim),
		"output_schema": _build_output_schema(opening_protocol_trim),
		"meta": meta
	}

func _sanitize_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		sanitized.append({
			"candidate_id": str(candidate.get("candidate_id", "")),
			"proposal_id": str(candidate.get("proposal_id", "")),
			"kind": str(candidate.get("kind", "")),
			"command_type": str(candidate.get("command_type", "")),
			"payload": _clone_value(candidate.get("payload", {})),
			"source_card_id": str(candidate.get("source_card_id", "")),
			"target_card_id": str(candidate.get("target_card_id", "")),
			"target_player_id": int(candidate.get("target_player_id", -1)),
			"target_summary": _clone_value(candidate.get("target_summary", {})),
			"choice_type": str(candidate.get("choice_type", "")),
			"selection_count": int(candidate.get("selection_count", 0)),
			"selected_option_label": str(candidate.get("selected_option_label", "")),
			"morale_cost": int(candidate.get("morale_cost", 0)),
			"discard_card_count": int(candidate.get("discard_card_count", 0)),
			"hand_guard_card_count": int(candidate.get("hand_guard_card_count", 0)),
			"action_group": str(candidate.get("action_group", "")),
			"action_group_label": str(candidate.get("action_group_label", "")),
			"group_order": int(candidate.get("group_order", 999)),
			"consequences": _clone_value(candidate.get("consequences", {})),
			"costs": _clone_value(candidate.get("costs", {})),
			"summaries": _clone_value(candidate.get("summaries", {})),
			"presentation": _clone_value(candidate.get("presentation", {}))
		})
	return sanitized

func _build_context(player_id: int, waiting_state: Dictionary, candidate_count: int, candidates: Array[Dictionary], extra: Dictionary, opening_protocol_trim: bool) -> Dictionary:
	var extra_copy: Dictionary = extra.duplicate(true)
	var context := {
		"live": {
			"player_id": player_id,
			"candidate_count": candidate_count,
			"waiting_state": waiting_state.duplicate(true),
			"candidate_groups": _build_candidate_groups(candidates)
		},
		"reference": {
			"history": _clone_value(extra_copy.get("history", [])),
			"history_summary": _clone_value(extra_copy.get("history_summary", {})),
			"match_context": _clone_value(extra_copy.get("match_context", {})),
			"notes": {
				"history_is_reference_only": true,
				"current_decision_must_follow_current_observation_and_candidates": true
			}
		},
		"request_controls": {
			"repair": _clone_value(extra_copy.get("repair", {})),
			"plan_mode": bool(extra_copy.get("plan_mode", false))
		}
	}
	for key in ["history", "history_summary", "match_context", "repair", "plan_mode"]:
		extra_copy.erase(key)
	if not extra_copy.is_empty():
		context["auxiliary"] = extra_copy
	if opening_protocol_trim:
		context = _trim_context_protocol_fields(context)
	return context

func _build_output_schema(opening_protocol_trim: bool) -> Dictionary:
	if opening_protocol_trim:
		return {"candidate_id": "string"}
	return {
		"candidate_id": "string",
		"confidence": "number",
		"brief_reason": "string"
	}

func _should_apply_opening_protocol_trim(observation: Dictionary, candidate_count: int, extra: Dictionary) -> bool:
	var repair = extra.get("repair", {})
	if repair is Dictionary and not repair.is_empty():
		return false
	if bool(extra.get("plan_mode", false)):
		return false
	var turn_number := int(observation.get("turn_number", observation.get("turn", 0)))
	return turn_number <= 1 and candidate_count > 1 and candidate_count <= 12

func _build_candidate_groups(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var groups_by_id: Dictionary = {}
	var ordered_ids: Array[String] = []
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var action_group := str(candidate.get("action_group", "other"))
		if not groups_by_id.has(action_group):
			ordered_ids.append(action_group)
			groups_by_id[action_group] = {
				"action_group": action_group,
				"action_group_label": str(candidate.get("action_group_label", "")),
				"group_order": int(candidate.get("group_order", 999)),
				"count": 0,
				"candidate_ids": []
			}
		var entry: Dictionary = groups_by_id[action_group]
		entry["count"] = int(entry.get("count", 0)) + 1
		var candidate_ids: Array = entry.get("candidate_ids", [])
		candidate_ids.append(str(candidate.get("candidate_id", "")))
		entry["candidate_ids"] = candidate_ids
		groups_by_id[action_group] = entry
	var result: Array[Dictionary] = []
	for action_group in ordered_ids:
		result.append((groups_by_id[action_group] as Dictionary).duplicate(true))
	return result

func _trim_context_protocol_fields(context: Dictionary) -> Dictionary:
	var trimmed: Dictionary = context.duplicate(true)
	var reference = trimmed.get("reference", {})
	if reference is Dictionary:
		reference.erase("notes")
		if reference.get("history", []) is Array and (reference.get("history", []) as Array).is_empty():
			reference.erase("history")
		if reference.get("history_summary", {}) is Dictionary and (reference.get("history_summary", {}) as Dictionary).is_empty():
			reference.erase("history_summary")
		if reference.get("match_context", {}) is Dictionary and (reference.get("match_context", {}) as Dictionary).is_empty():
			reference.erase("match_context")
		trimmed["reference"] = reference
	var request_controls = trimmed.get("request_controls", {})
	if request_controls is Dictionary:
		if request_controls.get("repair", {}) is Dictionary and (request_controls.get("repair", {}) as Dictionary).is_empty():
			request_controls.erase("repair")
		if not bool(request_controls.get("plan_mode", false)):
			request_controls.erase("plan_mode")
		if request_controls.is_empty():
			trimmed.erase("request_controls")
		else:
			trimmed["request_controls"] = request_controls
	if trimmed.get("auxiliary", {}) is Dictionary and (trimmed.get("auxiliary", {}) as Dictionary).is_empty():
		trimmed.erase("auxiliary")
	return trimmed

func _clone_value(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
