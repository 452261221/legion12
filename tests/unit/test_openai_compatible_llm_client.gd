extends RefCounted
class_name TestOpenAICompatibleLlmClient

class StubOpenAICompatibleLlmClient extends OpenAICompatibleLlmClient:
	var queued_results: Array[Dictionary] = []
	var captured_payloads: Array[Dictionary] = []

	func _do_helper_request(body_text: String, _resolved_url: String) -> Dictionary:
		var parsed = JSON.parse_string(body_text)
		if parsed is Dictionary:
			captured_payloads.append(parsed.duplicate(true))
		else:
			captured_payloads.append({})
		if queued_results.is_empty():
			return {"ok": false, "error": "missing_stub_result"}
		return queued_results.pop_front()

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_system_prompt_stays_minimal_and_strict(failures)
	_test_conversation_mode_keeps_runtime_system_prompt(failures)
	_test_payload_uses_configurable_thinking_and_max_tokens(failures)
	_test_payload_can_disable_thinking_per_request(failures)
	_test_thinking_unsupported_error_triggers_downgrade_detection(failures)
	_test_non_thinking_error_does_not_trigger_downgrade_detection(failures)
	_test_invalid_content_with_thinking_retries_without_thinking(failures)
	_test_empty_content_recovers_from_reasoning_content(failures)
	_test_opening_fast_json_mode_disables_thinking_and_limits_tokens(failures)
	_test_payload_keeps_request_context_in_user_message(failures)
	_test_success_response_keeps_raw_output_metadata(failures)
	return failures

static func _test_system_prompt_stays_minimal_and_strict(failures: Array[String]) -> void:
	var client := OpenAICompatibleLlmClient.new()
	var payload: Dictionary = client._build_payload({
		"observation": {"turn_number": 1},
		"candidates": [
			{"candidate_id": "cand_play", "kind": "play_card", "command_type": "PlayCard"},
			{"candidate_id": "cand_end", "kind": "end_phase", "command_type": "EndPhase"}
		],
		"script_analysis": [],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 2
		}
	})
	var messages = payload.get("messages", [])
	_expect(messages is Array and messages.size() >= 1, "openai compatible llm client: payload should include messages", failures)
	if not (messages is Array) or messages.is_empty():
		return
	var system_message = messages[0]
	_expect(system_message is Dictionary, "openai compatible llm client: first message should be system message", failures)
	if not (system_message is Dictionary):
		return
	var system_text := str(system_message.get("content", ""))
	_expect(system_text.contains("如果只有一个 candidate，则必须选择它"), "openai compatible llm client: prompt should enforce single-candidate selection", failures)
	_expect(system_text.contains("brief_reason 只能解释你最终选择的那个 candidate_id"), "openai compatible llm client: prompt should constrain reason to chosen candidate", failures)
	_expect(system_text.contains("绝不能编造不存在的 candidate_id、command_type 或 payload"), "openai compatible llm client: prompt should forbid invented candidate fields", failures)
	_expect(not system_text.contains("不要轻易选择 end_phase 或 pass_priority"), "openai compatible llm client: prompt should not inject passive-action bias", failures)

static func _test_conversation_mode_keeps_runtime_system_prompt(failures: Array[String]) -> void:
	var client := OpenAICompatibleLlmClient.new()
	var payload: Dictionary = client._build_payload({
		"observation": {"turn_number": 1},
		"candidates": [
			{"candidate_id": "cand_play", "kind": "play_card", "command_type": "PlayCard"},
			{"candidate_id": "cand_end", "kind": "end_phase", "command_type": "EndPhase"}
		],
		"conversation_messages": [
			{"role": "system", "content": "session-base"},
			{"role": "user", "content": "{\"kind\":\"knowledge\"}"}
		],
		"script_analysis": [],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 2,
			"extra": {
				"repair": {"reason": "candidate_id_not_found"}
			}
		}
	})
	var messages = payload.get("messages", [])
	_expect(messages is Array and messages.size() >= 3, "openai compatible llm client: conversation payload should preserve session messages and append request", failures)
	if not (messages is Array) or messages.is_empty():
		return
	var system_message = messages[0]
	_expect(system_message is Dictionary, "openai compatible llm client: merged conversation system message should remain a dictionary", failures)
	if not (system_message is Dictionary):
		return
	var system_text := str(system_message.get("content", ""))
	_expect(system_text.contains("session-base"), "openai compatible llm client: conversation payload should retain session system context", failures)
	_expect(system_text.contains("输出格式：{\"candidate_id\":\"...\""), "openai compatible llm client: conversation payload should still include single-step output prompt", failures)
	_expect(system_text.contains("忽略上一次回答"), "openai compatible llm client: conversation payload should include repair prompt", failures)

static func _test_payload_uses_configurable_thinking_and_max_tokens(failures: Array[String]) -> void:
	var client := OpenAICompatibleLlmClient.new()
	client.configure({
		"enable_thinking": true,
		"response_max_tokens": 1536
	})
	var payload: Dictionary = client._build_payload({
		"observation": {"turn_number": 1},
		"candidates": [{"candidate_id": "cand_only", "kind": "play_card", "command_type": "PlayCard"}],
		"script_analysis": [],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 1
		}
	})
	_expect(int(payload.get("max_tokens", 0)) == 1536, "openai compatible llm client: payload should use configurable max_tokens", failures)
	var thinking = payload.get("thinking", {})
	_expect(thinking is Dictionary and str(thinking.get("type", "")) == "enabled", "openai compatible llm client: payload should enable thinking when configured", failures)

static func _test_payload_can_disable_thinking_per_request(failures: Array[String]) -> void:
	var client := OpenAICompatibleLlmClient.new()
	client.configure({
		"enable_thinking": true,
		"response_max_tokens": 1024
	})
	var payload: Dictionary = client._build_payload({
		"observation": {"turn_number": 1},
		"candidates": [{"candidate_id": "cand_only", "kind": "play_card", "command_type": "PlayCard"}],
		"script_analysis": [],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 1
		}
	}, false)
	_expect(not payload.has("thinking"), "openai compatible llm client: per-request override should disable thinking field", failures)

static func _test_thinking_unsupported_error_triggers_downgrade_detection(failures: Array[String]) -> void:
	var client := OpenAICompatibleLlmClient.new()
	var should_downgrade := client._should_disable_thinking_from_error({
		"error": "http_error",
		"status_code": 400,
		"body": "{\"error\":{\"message\":\"unsupported parameter: thinking\"}}"
	})
	_expect(should_downgrade, "openai compatible llm client: unsupported thinking errors should trigger downgrade detection", failures)

static func _test_non_thinking_error_does_not_trigger_downgrade_detection(failures: Array[String]) -> void:
	var client := OpenAICompatibleLlmClient.new()
	var should_downgrade := client._should_disable_thinking_from_error({
		"error": "http_error",
		"status_code": 400,
		"body": "{\"error\":{\"message\":\"unsupported parameter: tools\"}}"
	})
	_expect(not should_downgrade, "openai compatible llm client: unrelated parameter errors should not trigger thinking downgrade detection", failures)

static func _test_invalid_content_with_thinking_retries_without_thinking(failures: Array[String]) -> void:
	var client := StubOpenAICompatibleLlmClient.new()
	client.configure({
		"api_key": "test-key",
		"use_external_helper": true,
		"enable_thinking": true,
		"response_max_tokens": 1024,
		"max_retries": 1
	})
	client.queued_results = [
		{
			"ok": true,
			"status_code": 200,
			"body": "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"candidate_id\\\":\\\"cand_only\\\",\\\"confidence\\\":1.0,\\\"brief_reason\\\":\\\"truncated\",\"reasoning_content\":\"long reasoning\"},\"finish_reason\":\"length\"}]}"
		},
		{
			"ok": true,
			"status_code": 200,
			"body": "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"candidate_id\\\":\\\"cand_only\\\",\\\"confidence\\\":1.0,\\\"brief_reason\\\":\\\"only candidate\\\"}\"},\"finish_reason\":\"stop\"}]}"
		}
	]
	var response := client.choose_candidate({
		"observation": {"turn_number": 1},
		"candidates": [{"candidate_id": "cand_only", "kind": "end_phase", "command_type": "EndPhase"}],
		"script_analysis": [],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 1
		}
	})
	_expect(str(response.get("candidate_id", "")) == "cand_only", "openai compatible llm client: retry without thinking should recover valid candidate output", failures)
	_expect(bool(response.get("thinking_downgraded", false)), "openai compatible llm client: retry without thinking should mark thinking_downgraded", failures)
	_expect(client.captured_payloads.size() == 2, "openai compatible llm client: invalid thinking output should trigger exactly one retry", failures)
	var timing_trace: Dictionary = response.get("timing_trace", {})
	var timing_summary: Dictionary = timing_trace.get("summary", {}) if timing_trace is Dictionary else {}
	_expect(int(timing_summary.get("attempt_count", 0)) == 2, "openai compatible llm client: timing should record both attempts after retry", failures)
	if client.captured_payloads.size() >= 2:
		_expect(client.captured_payloads[0].has("thinking"), "openai compatible llm client: first retry attempt should include thinking", failures)
		_expect(not client.captured_payloads[1].has("thinking"), "openai compatible llm client: second retry attempt should disable thinking", failures)
		_expect(int(client.captured_payloads[1].get("max_tokens", 0)) >= 2048, "openai compatible llm client: recovery retry should increase max_tokens budget", failures)
		var retry_messages = client.captured_payloads[1].get("messages", [])
		if retry_messages is Array and not retry_messages.is_empty() and retry_messages[0] is Dictionary:
			_expect(str(retry_messages[0].get("content", "")).contains("恢复模式"), "openai compatible llm client: retry payload should enable strict json recovery prompt", failures)

static func _test_empty_content_recovers_from_reasoning_content(failures: Array[String]) -> void:
	var client := StubOpenAICompatibleLlmClient.new()
	client.configure({
		"api_key": "test-key",
		"use_external_helper": true,
		"enable_thinking": true,
		"response_max_tokens": 256,
		"max_retries": 0
	})
	client.queued_results = [
		{
			"ok": true,
			"status_code": 200,
			"body": "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"\",\"reasoning_content\":\"{\\\"candidate_id\\\":\\\"cand_only\\\",\\\"confidence\\\":0.9,\\\"brief_reason\\\":\\\"from reasoning\\\"}\"},\"finish_reason\":\"stop\"}]}"
		}
	]
	var response := client.choose_candidate({
		"observation": {"turn_number": 1},
		"candidates": [{"candidate_id": "cand_only", "kind": "end_phase", "command_type": "EndPhase"}],
		"script_analysis": [],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 1
		}
	})
	_expect(str(response.get("candidate_id", "")) == "cand_only", "openai compatible llm client: should recover json from reasoning_content when content is empty", failures)
	_expect(bool(response.get("json_recovered", false)), "openai compatible llm client: recovered response should set json_recovered", failures)
	_expect(str(response.get("json_recovered_from", "")) == "reasoning_content", "openai compatible llm client: recovered response should record source reasoning_content", failures)

static func _test_opening_fast_json_mode_disables_thinking_and_limits_tokens(failures: Array[String]) -> void:
	var client := StubOpenAICompatibleLlmClient.new()
	client.configure({
		"api_key": "test-key",
		"use_external_helper": true,
		"enable_thinking": true,
		"response_max_tokens": 1024,
		"max_retries": 0
	})
	client.queued_results = [
		{
			"ok": true,
			"status_code": 200,
			"body": "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"candidate_id\\\":\\\"cand_ok\\\",\\\"confidence\\\":1.0,\\\"brief_reason\\\":\\\"ok\\\"}\"},\"finish_reason\":\"stop\"}]}"
		}
	]
	var response := client.choose_candidate({
		"observation": {"turn_number": 1},
		"candidates": [
			{"candidate_id": "cand_a", "kind": "play_card", "command_type": "PlayCard"},
			{"candidate_id": "cand_ok", "kind": "end_phase", "command_type": "EndPhase"}
		],
		"script_analysis": [],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 2
		}
	})
	_expect(str(response.get("candidate_id", "")) == "cand_ok", "openai compatible llm client: opening fast json mode should keep valid output", failures)
	_expect(client.captured_payloads.size() == 1, "openai compatible llm client: opening fast json mode should not require retries", failures)
	if client.captured_payloads.size() >= 1:
		_expect(not client.captured_payloads[0].has("thinking"), "openai compatible llm client: opening fast json mode should disable thinking", failures)
		_expect(int(client.captured_payloads[0].get("max_tokens", 0)) <= 96, "openai compatible llm client: opening fast json mode should lower max_tokens aggressively", failures)
		var messages = client.captured_payloads[0].get("messages", [])
		if messages is Array and not messages.is_empty() and messages[0] is Dictionary:
			_expect(str(messages[0].get("content", "")).contains("快速模式"), "openai compatible llm client: opening fast json mode should add fast mode system prompt", failures)
			_expect(str(messages[0].get("content", "")).contains("不要输出 confidence"), "openai compatible llm client: opening fast json mode should request candidate_id-only output", failures)
		if messages is Array and messages.size() >= 2 and messages[messages.size() - 1] is Dictionary:
			var parsed = JSON.parse_string(str((messages[messages.size() - 1] as Dictionary).get("content", "")))
			if parsed is Dictionary:
				var schema = parsed.get("output_schema", {})
				_expect(schema is Dictionary and schema.size() == 1 and str(schema.get("candidate_id", "")) == "string", "openai compatible llm client: opening fast json mode should shrink output_schema to candidate_id only", failures)

static func _test_payload_keeps_request_context_in_user_message(failures: Array[String]) -> void:
	var client := OpenAICompatibleLlmClient.new()
	var payload: Dictionary = client._build_payload({
		"observation": {"turn_number": 1},
		"candidates": [{"candidate_id": "cand_only", "kind": "play_card", "command_type": "PlayCard"}],
		"context": {
			"live": {"player_id": 0, "candidate_count": 1},
			"reference": {"notes": {"history_is_reference_only": true}}
		},
		"script_analysis": [],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 1
		}
	})
	var messages = payload.get("messages", [])
	_expect(messages is Array and messages.size() >= 2, "openai compatible llm client: payload should include user request message", failures)
	if not (messages is Array) or messages.size() < 2:
		return
	var user_message = messages[messages.size() - 1]
	_expect(user_message is Dictionary, "openai compatible llm client: user request message should be a dictionary", failures)
	if not (user_message is Dictionary):
		return
	var parsed = JSON.parse_string(str(user_message.get("content", "")))
	_expect(parsed is Dictionary and parsed.get("context", {}) is Dictionary, "openai compatible llm client: serialized user request should preserve context", failures)

static func _test_success_response_keeps_raw_output_metadata(failures: Array[String]) -> void:
	var client := OpenAICompatibleLlmClient.new()
	var decorated := client._decorate_success_response(
		{
			"candidate_id": "cand_play",
			"confidence": 0.8,
			"brief_reason": "test_reason"
		},
		"{\"candidate_id\":\"cand_play\"}",
		"{\"choices\":[{\"message\":{\"content\":\"{...}\"}}]}",
		{"role": "assistant", "content": "{\"candidate_id\":\"cand_play\"}"}
	)
	_expect(str(decorated.get("candidate_id", "")) == "cand_play", "openai compatible llm client: decorated response should preserve parsed candidate_id", failures)
	_expect(str(decorated.get("content", "")) == "{\"candidate_id\":\"cand_play\"}", "openai compatible llm client: decorated response should preserve raw content", failures)
	_expect(str(decorated.get("body", "")) == "{\"choices\":[{\"message\":{\"content\":\"{...}\"}}]}", "openai compatible llm client: decorated response should preserve raw body", failures)
	var provider_message = decorated.get("provider_message", {})
	_expect(provider_message is Dictionary and str(provider_message.get("role", "")) == "assistant", "openai compatible llm client: decorated response should preserve provider message", failures)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
