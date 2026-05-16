extends RefCounted
class_name FakeLlmClient

var _forced_response: Dictionary = {}
var _mode: String = "first_candidate"
var _queued_responses: Array[Dictionary] = []
var _request_count: int = 0

func set_forced_response(response: Dictionary) -> void:
	_forced_response = response.duplicate(true)

func set_queued_responses(responses: Array[Dictionary]) -> void:
	_queued_responses = []
	for item in responses:
		_queued_responses.append(item.duplicate(true))

func set_mode(mode: String) -> void:
	_mode = mode

func get_request_count() -> int:
	return _request_count

func choose_candidate(request: Dictionary) -> Dictionary:
	_request_count += 1
	if not _queued_responses.is_empty():
		var response: Dictionary = _queued_responses[0].duplicate(true)
		_queued_responses.remove_at(0)
		return response
	if not _forced_response.is_empty():
		return _forced_response.duplicate(true)
	var candidates: Array = request.get("candidates", [])
	if not (candidates is Array) or candidates.is_empty():
		return {}
	match _mode:
		"last_candidate":
			var raw_last = candidates[candidates.size() - 1]
			var last: Dictionary = raw_last.duplicate(true) if raw_last is Dictionary else {}
			return {
				"candidate_id": str(last.get("candidate_id", "")),
				"confidence": 0.51,
				"brief_reason": "fake_llm_selects_last_candidate"
			}
		"invalid_candidate":
			return {
				"candidate_id": "invalid_candidate_id",
				"confidence": 0.01,
				"brief_reason": "fake_llm_returns_invalid_candidate"
			}
		_:
			var raw_first = candidates[0]
			var first: Dictionary = raw_first.duplicate(true) if raw_first is Dictionary else {}
			return {
				"candidate_id": str(first.get("candidate_id", "")),
				"confidence": 0.5,
				"brief_reason": "fake_llm_selects_first_candidate"
			}
