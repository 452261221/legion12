extends RefCounted
class_name DecisionValidator

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")
const GameCommand = preload("res://rules/core/game_command.gd")

func validate_response(engine, state, player_id: int, actions: Array, llm_response, expected_waiting_state: Dictionary = {}) -> Dictionary:
	if engine == null or state == null:
		return {"ok": false, "reason": "invalid_state"}
	var parsed := _parse_response(llm_response)
	if not bool(parsed.get("ok", false)):
		return parsed
	var response: Dictionary = parsed.get("response", {})
	var plan: Array = parsed.get("plan", [])
	var candidate_id := str(response.get("candidate_id", ""))
	var current_waiting: Dictionary = engine.get_waiting_state(state)
	if not expected_waiting_state.is_empty() and not _waiting_state_matches(expected_waiting_state, current_waiting):
		return {
			"ok": false,
			"reason": "stale_waiting_state",
			"expected_waiting_state": expected_waiting_state.duplicate(true),
			"current_waiting_state": current_waiting.duplicate(true)
		}
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	if candidate_id.is_empty():
		var hinted := _find_candidate_by_response_hints(candidates, response)
		if not hinted.is_empty():
			candidate_id = str(hinted.get("candidate_id", ""))
			response["candidate_id"] = candidate_id
		if candidate_id.is_empty():
			return {"ok": false, "reason": "missing_candidate_id"}
	var candidate := _find_candidate_by_id(candidates, candidate_id)
	if candidate.is_empty():
		var matched := _find_candidate_by_response_hints(candidates, response)
		if not matched.is_empty():
			candidate = matched.duplicate(true)
			candidate_id = str(candidate.get("candidate_id", ""))
			response["candidate_id"] = candidate_id
		if candidate.is_empty():
			return {"ok": false, "reason": "candidate_id_not_found", "candidate_id": candidate_id}
	var command_type := str(candidate.get("command_type", ""))
	var payload: Dictionary = candidate.get("payload", {}).duplicate(true)
	var validation: Dictionary = engine.validate_command(state, GameCommand.create(player_id, command_type, payload))
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"reason": "validate_failed",
			"candidate_id": candidate_id,
			"validation": validation.duplicate(true)
		}
	return {
		"ok": true,
		"candidate_id": candidate_id,
		"command_type": command_type,
		"payload": payload,
		"candidate": candidate.duplicate(true),
		"response": response.duplicate(true),
		"plan": plan.duplicate(true)
	}

func _parse_response(llm_response) -> Dictionary:
	if llm_response is Dictionary:
		var response: Dictionary = llm_response.duplicate(true)
		return _normalize_response_container(response)
	if llm_response is String:
		var parsed = JSON.parse_string(str(llm_response))
		if parsed is Dictionary:
			return _normalize_response_container(parsed.duplicate(true))
		return {"ok": false, "reason": "invalid_json"}
	return {"ok": false, "reason": "invalid_response_type"}

func _normalize_response_container(container: Dictionary) -> Dictionary:
	if container.has("plan") and container.get("plan") is Array:
		var plan: Array = container.get("plan", [])
		if not plan.is_empty() and plan[0] is Dictionary:
			return {"ok": true, "response": (plan[0] as Dictionary).duplicate(true), "plan": plan.duplicate(true)}
		return {"ok": false, "reason": "invalid_plan"}
	return {"ok": true, "response": container.duplicate(true), "plan": []}

func _waiting_state_matches(expected: Dictionary, current: Dictionary) -> bool:
	for key in ["state", "player_id", "choice_id", "phase", "stack_size", "pending_attack"]:
		if expected.has(key) and expected.get(key) != current.get(key):
			return false
	return true

func _find_candidate_by_id(candidates: Array[Dictionary], candidate_id: String) -> Dictionary:
	for candidate in candidates:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return candidate
	return {}

func _find_candidate_by_command(candidates: Array[Dictionary], command_type: String, payload: Dictionary) -> Dictionary:
	var normalized_command := command_type.strip_edges()
	for candidate in candidates:
		if str(candidate.get("command_type", "")).strip_edges() != normalized_command:
			continue
		var candidate_payload = candidate.get("payload", {})
		if candidate_payload is Dictionary and _payloads_equivalent(candidate_payload, payload):
			return candidate
	return {}

func _find_candidate_by_response_hints(candidates: Array[Dictionary], response: Dictionary) -> Dictionary:
	var candidate_id_hint := str(response.get("candidate_id", "")).strip_edges()
	var proposal_id_hint := str(response.get("proposal_id", candidate_id_hint)).strip_edges()
	if not proposal_id_hint.is_empty():
		for candidate in candidates:
			if str(candidate.get("proposal_id", "")).strip_edges() == proposal_id_hint:
				return candidate
	var command_type_guess := str(response.get("command_type", "")).strip_edges()
	var payload_guess = response.get("payload", {})
	if not command_type_guess.is_empty() and payload_guess is Dictionary:
		var exact := _find_candidate_by_command(candidates, command_type_guess, payload_guess)
		if not exact.is_empty():
			return exact
		var payload_match := _find_candidate_by_command_payload_subset(candidates, command_type_guess, payload_guess)
		if not payload_match.is_empty():
			return payload_match
	if not command_type_guess.is_empty():
		var unique_by_command := _find_unique_candidate_by_command(candidates, command_type_guess)
		if not unique_by_command.is_empty():
			return unique_by_command
	return {}

func _find_candidate_by_command_payload_subset(candidates: Array[Dictionary], command_type: String, payload: Dictionary) -> Dictionary:
	var normalized_command := command_type.strip_edges()
	var matches: Array[Dictionary] = []
	for candidate in candidates:
		if str(candidate.get("command_type", "")).strip_edges() != normalized_command:
			continue
		var candidate_payload = candidate.get("payload", {})
		if candidate_payload is Dictionary and _payload_contains_subset(candidate_payload, payload):
			matches.append(candidate)
	if matches.size() == 1:
		return matches[0]
	return {}

func _find_unique_candidate_by_command(candidates: Array[Dictionary], command_type: String) -> Dictionary:
	var normalized_command := command_type.strip_edges()
	var matches: Array[Dictionary] = []
	for candidate in candidates:
		if str(candidate.get("command_type", "")).strip_edges() == normalized_command:
			matches.append(candidate)
	if matches.size() == 1:
		return matches[0]
	return {}

func _payloads_equivalent(left: Dictionary, right: Dictionary) -> bool:
	return _normalize_payload_value(left) == _normalize_payload_value(right)

func _payload_contains_subset(candidate_payload: Dictionary, response_payload: Dictionary) -> bool:
	var normalized_candidate = _normalize_payload_value(candidate_payload)
	var normalized_response = _normalize_payload_value(response_payload)
	for key in normalized_response.keys():
		if not normalized_candidate.has(key):
			return false
		if normalized_candidate.get(key) != normalized_response.get(key):
			return false
	return true

func _normalize_payload_value(value):
	if value is Dictionary:
		var normalized: Dictionary = {}
		var keys = (value as Dictionary).keys()
		keys.sort()
		for key in keys:
			normalized[key] = _normalize_payload_value((value as Dictionary).get(key))
		return normalized
	if value is Array:
		var array_value: Array = value
		var normalized_array: Array = []
		var string_items_only := true
		for item in array_value:
			normalized_array.append(_normalize_payload_value(item))
			if not (item is String):
				string_items_only = false
		if string_items_only:
			normalized_array.sort()
		return normalized_array
	return value
