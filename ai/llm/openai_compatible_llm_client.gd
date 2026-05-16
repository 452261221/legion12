extends RefCounted
class_name OpenAICompatibleLlmClient

const DEFAULT_BASE_URL := "https://api.deepseek.com/chat/completions"
const DEFAULT_MODEL := "deepseek-v4-flash"
const HELPER_SCRIPT_PATH := "res://tools/llm/deepseek_chat_completion.ps1"

var api_key: String = ""
var base_url: String = DEFAULT_BASE_URL
var model: String = DEFAULT_MODEL
var provider_name: String = "openai_compatible"
var timeout_seconds: float = 30.0
var include_script_analysis: bool = true
var debug: bool = false
var max_retries: int = 2
var retry_delay_ms: int = 1200
var use_external_helper: bool = true
var enable_thinking: bool = false
var response_max_tokens: int = 512
var extra_headers: Array[String] = []
var request_extras: Dictionary = {}
var debug_force_invalid_candidate_count: int = 0
var _debug_forced_invalid_remaining: int = 0

func configure(options: Dictionary = {}) -> void:
	api_key = str(options.get("api_key", api_key)).strip_edges()
	base_url = str(options.get("base_url", base_url)).strip_edges()
	model = str(options.get("model", model)).strip_edges()
	provider_name = str(options.get("provider_name", provider_name)).strip_edges()
	timeout_seconds = max(5.0, float(options.get("timeout_seconds", timeout_seconds)))
	include_script_analysis = bool(options.get("include_script_analysis", include_script_analysis))
	debug = bool(options.get("debug", debug))
	max_retries = max(0, int(options.get("max_retries", max_retries)))
	retry_delay_ms = max(0, int(options.get("retry_delay_ms", retry_delay_ms)))
	use_external_helper = bool(options.get("use_external_helper", use_external_helper))
	enable_thinking = bool(options.get("enable_thinking", enable_thinking))
	response_max_tokens = max(1, int(options.get("response_max_tokens", options.get("max_tokens", response_max_tokens))))
	request_extras = options.get("request_extras", {}).duplicate(true)
	debug_force_invalid_candidate_count = max(0, int(options.get("debug_force_invalid_candidate_count", 0)))
	_debug_forced_invalid_remaining = debug_force_invalid_candidate_count
	extra_headers.clear()
	var raw_headers = options.get("extra_headers", [])
	if raw_headers is Array:
		for item in raw_headers:
			extra_headers.append(str(item))
	if base_url.is_empty():
		base_url = DEFAULT_BASE_URL
	if model.is_empty():
		model = DEFAULT_MODEL
	if provider_name.is_empty():
		provider_name = "openai_compatible"

func choose_candidate(request: Dictionary) -> Dictionary:
	if api_key.is_empty():
		return {"error": "missing_api_key"}
	var choose_started_us := _now_usec()
	var resolved_url := _normalize_chat_completions_url(base_url)
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key
	])
	for header_line in extra_headers:
		headers.append(header_line)
	var request_enable_thinking := enable_thinking
	var thinking_downgraded := false
	var strict_json_recovery := false
	var fast_json_mode := _should_force_opening_fast_json_mode(request)
	var request_max_tokens := response_max_tokens
	var attempt_traces: Array[Dictionary] = []
	if fast_json_mode:
		request_enable_thinking = false
		request_max_tokens = min(request_max_tokens, 96)
	var attempt := 0
	while attempt <= max_retries:
		attempt += 1
		var attempt_started_us := _now_usec()
		var attempt_trace: Dictionary = {
			"attempt": attempt,
			"thinking_enabled": request_enable_thinking,
			"strict_json_recovery": strict_json_recovery,
			"fast_json_mode": fast_json_mode,
			"request_max_tokens": request_max_tokens
		}
		var payload_started_us := _now_usec()
		var payload: Dictionary = _build_payload(request, request_enable_thinking, strict_json_recovery, fast_json_mode, request_max_tokens)
		var body_text: String = JSON.stringify(payload)
		attempt_trace["payload_build_ms"] = _elapsed_ms(payload_started_us)
		var status: Dictionary = {}
		if use_external_helper:
			var helper_started_us := _now_usec()
			status = _do_helper_request(body_text, resolved_url)
			attempt_trace["transport_mode"] = "external_helper"
			attempt_trace["helper_ms"] = _elapsed_ms(helper_started_us)
			attempt_trace["helper_status"] = _extract_transport_status(status)
			if status.has("timing"):
				attempt_trace["helper_timing"] = status.get("timing", {}).duplicate(true)
			if _should_fallback_from_helper(status):
				attempt_trace["helper_fallback"] = true
				var helper_fallback_client := HTTPClient.new()
				var helper_fallback_deadline_ms: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
				var http_fallback_started_us := _now_usec()
				status = _do_request(helper_fallback_client, helper_fallback_deadline_ms, headers, body_text, resolved_url)
				attempt_trace["http_fallback_ms"] = _elapsed_ms(http_fallback_started_us)
				attempt_trace["http_fallback_status"] = _extract_transport_status(status)
				if status.has("timing"):
					attempt_trace["http_fallback_timing"] = status.get("timing", {}).duplicate(true)
		else:
			attempt_trace["transport_mode"] = "http_client"
			var result := HTTPClient.new()
			var deadline_ms: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
			var request_started_us := _now_usec()
			status = _do_request(result, deadline_ms, headers, body_text, resolved_url)
			attempt_trace["http_ms"] = _elapsed_ms(request_started_us)
			attempt_trace["http_status"] = _extract_transport_status(status)
			if status.has("timing"):
				attempt_trace["http_timing"] = status.get("timing", {}).duplicate(true)
		attempt_trace["transport_ok"] = bool(status.get("ok", false))
		if not bool(status.get("ok", false)):
			attempt_trace["result"] = "transport_error"
			attempt_trace["error"] = str(status.get("error", ""))
			attempt_trace["total_ms"] = _elapsed_ms(attempt_started_us)
			attempt_traces.append(attempt_trace)
			if request_enable_thinking and _should_disable_thinking_from_error(status):
				request_enable_thinking = false
				thinking_downgraded = true
				continue
			if attempt <= max_retries and _should_retry(status):
				attempt_trace["retried"] = true
				attempt_trace["retry_delay_ms"] = retry_delay_ms
				OS.delay_msec(retry_delay_ms)
				continue
			return _attach_client_timing(status, choose_started_us, attempt_traces)
		var response_code: int = int(status.get("status_code", 0))
		var response_text: String = str(status.get("body", ""))
		if response_code < 200 or response_code >= 300:
			var error_result := {
				"error": "http_error",
				"status_code": response_code,
				"body": response_text
			}
			attempt_trace["result"] = "http_error"
			attempt_trace["status_code"] = response_code
			attempt_trace["total_ms"] = _elapsed_ms(attempt_started_us)
			attempt_traces.append(attempt_trace)
			if request_enable_thinking and _should_disable_thinking_from_error(error_result):
				request_enable_thinking = false
				thinking_downgraded = true
				continue
			if attempt <= max_retries and _should_retry(error_result):
				attempt_trace["retried"] = true
				attempt_trace["retry_delay_ms"] = retry_delay_ms
				OS.delay_msec(retry_delay_ms)
				continue
			return _attach_client_timing(error_result, choose_started_us, attempt_traces)
		var parsed = JSON.parse_string(response_text)
		if not (parsed is Dictionary):
			attempt_trace["result"] = "invalid_json"
			attempt_trace["total_ms"] = _elapsed_ms(attempt_started_us)
			attempt_traces.append(attempt_trace)
			return _attach_client_timing({"error": "invalid_json", "body": response_text}, choose_started_us, attempt_traces)
		var choice_message: Dictionary = _extract_choice_message(parsed)
		if choice_message.is_empty():
			attempt_trace["result"] = "missing_choice"
			attempt_trace["total_ms"] = _elapsed_ms(attempt_started_us)
			attempt_traces.append(attempt_trace)
			return _attach_client_timing({"error": "missing_choice", "body": response_text}, choose_started_us, attempt_traces)
		var content := str(choice_message.get("content", ""))
		var parse_started_us := _now_usec()
		var content_parsed = JSON.parse_string(content)
		attempt_trace["content_parse_ms"] = _elapsed_ms(parse_started_us)
		if content_parsed is Dictionary:
			var response: Dictionary = _decorate_success_response(content_parsed, content, response_text, choice_message)
			response["thinking_downgraded"] = thinking_downgraded
			response["fast_json_mode_applied"] = fast_json_mode
			var meta = request.get("meta", {})
			var extra = meta.get("extra", {}) if meta is Dictionary else {}
			var repair_context = extra.get("repair", {}) if extra is Dictionary else {}
			var is_repair_request: bool = repair_context is Dictionary and not repair_context.is_empty()
			if _debug_forced_invalid_remaining > 0:
				_debug_forced_invalid_remaining -= 1
				response["candidate_id"] = "invalid_candidate_id_for_probe"
				response["brief_reason"] = "%s [forced_invalid_probe]" % str(response.get("brief_reason", ""))
				if debug:
					print("[%s] forced_invalid_candidate applied remaining=%s repair=%s" % [
						provider_name,
						str(_debug_forced_invalid_remaining),
						str(is_repair_request)
					])
			attempt_trace["result"] = "ok"
			attempt_trace["status_code"] = response_code
			attempt_trace["total_ms"] = _elapsed_ms(attempt_started_us)
			attempt_traces.append(attempt_trace)
			return _attach_client_timing(response, choose_started_us, attempt_traces)
		var recovered_from := ""
		var recovery_started_us := _now_usec()
		var recovered_parsed: Dictionary = _try_parse_json_object_from_text(content)
		if not recovered_parsed.is_empty():
			recovered_from = "content"
		if recovered_parsed.is_empty():
			var reasoning_text := str(choice_message.get("reasoning_content", ""))
			recovered_parsed = _try_parse_json_object_from_text(reasoning_text)
			if not recovered_parsed.is_empty():
				recovered_from = "reasoning_content"
		if recovered_parsed.is_empty():
			recovered_parsed = _try_parse_json_object_from_text(response_text)
			if not recovered_parsed.is_empty():
				recovered_from = "body"
		attempt_trace["recovery_parse_ms"] = _elapsed_ms(recovery_started_us)
		if not recovered_parsed.is_empty():
			var recovered_text := JSON.stringify(recovered_parsed)
			var response: Dictionary = _decorate_success_response(recovered_parsed, recovered_text, response_text, choice_message)
			response["thinking_downgraded"] = thinking_downgraded
			response["fast_json_mode_applied"] = fast_json_mode
			response["json_recovered"] = true
			response["json_recovered_from"] = recovered_from
			attempt_trace["result"] = "ok_recovered"
			attempt_trace["json_recovered_from"] = recovered_from
			attempt_trace["status_code"] = response_code
			attempt_trace["total_ms"] = _elapsed_ms(attempt_started_us)
			attempt_traces.append(attempt_trace)
			return _attach_client_timing(response, choose_started_us, attempt_traces)
		if request_enable_thinking and _should_retry_without_thinking_for_invalid_content(parsed, choice_message, content):
			attempt_trace["result"] = "retry_without_thinking"
			attempt_trace["status_code"] = response_code
			attempt_trace["total_ms"] = _elapsed_ms(attempt_started_us)
			attempt_trace["thinking_disabled_for_retry"] = true
			attempt_traces.append(attempt_trace)
			request_enable_thinking = false
			thinking_downgraded = true
			strict_json_recovery = true
			request_max_tokens = _get_invalid_content_recovery_max_tokens(response_max_tokens, parsed)
			continue
		attempt_trace["result"] = "invalid_content_json"
		attempt_trace["status_code"] = response_code
		attempt_trace["total_ms"] = _elapsed_ms(attempt_started_us)
		attempt_traces.append(attempt_trace)
		return _attach_client_timing({
			"error": "invalid_content_json",
			"content": content,
			"body": response_text,
			"thinking_downgraded": thinking_downgraded,
			"fast_json_mode_applied": fast_json_mode,
			"recovery_attempted": strict_json_recovery,
			"finish_reason": _extract_finish_reason(parsed),
			"reasoning_content_present": not str(choice_message.get("reasoning_content", "")).strip_edges().is_empty(),
			"max_tokens_used": request_max_tokens
		}, choose_started_us, attempt_traces)
	return _attach_client_timing({"error": "request_exhausted"}, choose_started_us, attempt_traces)

func _decorate_success_response(content_parsed, content: String, response_text: String, choice_message: Dictionary) -> Dictionary:
	var response: Dictionary = {}
	if content_parsed is Dictionary:
		response = content_parsed.duplicate(true)
	response["content"] = content
	response["body"] = response_text
	response["provider_message"] = choice_message.duplicate(true)
	return response

func _do_helper_request(body_text: String, resolved_url: String) -> Dictionary:
	var helper_started_us := _now_usec()
	var helper_path := ProjectSettings.globalize_path(HELPER_SCRIPT_PATH)
	if not FileAccess.file_exists(helper_path):
		return _attach_transport_timing({"ok": false, "error": "helper_script_missing", "path": helper_path}, helper_started_us)
	var temp_dir := str(OS.get_environment("TEMP")).strip_edges()
	if temp_dir.is_empty():
		temp_dir = ProjectSettings.globalize_path("user://")
	temp_dir = temp_dir.replace("\\", "/").trim_suffix("/")
	var request_path := "%s/llm_helper_request.json" % temp_dir
	var response_path := "%s/llm_helper_response.json" % temp_dir
	var request_file := FileAccess.open(request_path, FileAccess.WRITE)
	if request_file == null:
		return _attach_transport_timing({"ok": false, "error": "request_file_open_failed"}, helper_started_us)
	request_file.store_string(body_text)
	request_file.close()
	var request_arg_path := request_path
	var response_arg_path := response_path
	if request_arg_path.begins_with("user://") or request_arg_path.begins_with("res://"):
		request_arg_path = ProjectSettings.globalize_path(request_arg_path)
	if response_arg_path.begins_with("user://") or response_arg_path.begins_with("res://"):
		response_arg_path = ProjectSettings.globalize_path(response_arg_path)
	var output: Array = []
	var args: Array[String] = [
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", helper_path,
		"-RequestPath", request_arg_path,
		"-ResponsePath", response_arg_path,
		"-ApiKey", api_key,
		"-BaseUrl", resolved_url,
		"-ConnectTimeoutSeconds", str(int(min(timeout_seconds, 10.0))),
		"-TimeoutSeconds", str(int(timeout_seconds))
	]
	for header_line in extra_headers:
		args.append("-ExtraHeader")
		args.append(header_line)
	var shell_candidates: Array[String] = ["powershell"]
	if OS.has_feature("windows"):
		shell_candidates = ["powershell.exe", "powershell", "pwsh.exe", "pwsh"]
	var exit_code := -1
	for shell_name in shell_candidates:
		output.clear()
		exit_code = OS.execute(shell_name, args, output, true, false)
		if exit_code != -1 or FileAccess.file_exists(response_path):
			break
	if debug:
		print("[%s helper] exit=%s output=%s" % [provider_name, str(exit_code), JSON.stringify(output)])
	if exit_code != 0 and not FileAccess.file_exists(response_path):
		return _attach_transport_timing({"ok": false, "error": "helper_execute_failed", "exit_code": exit_code, "output": output}, helper_started_us)
	var response_text := FileAccess.get_file_as_string(response_path)
	if response_text.is_empty():
		return _attach_transport_timing({"ok": false, "error": "helper_empty_response", "exit_code": exit_code, "output": output}, helper_started_us)
	var parsed = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return _attach_transport_timing({"ok": false, "error": "helper_invalid_json", "body": response_text, "exit_code": exit_code}, helper_started_us)
	return _attach_transport_timing(parsed.duplicate(true), helper_started_us)

func _do_request(client: HTTPClient, deadline_ms: int, headers: PackedStringArray, body_text: String, resolved_url: String) -> Dictionary:
	var request_started_us := _now_usec()
	var host := _extract_host(resolved_url)
	var port := _extract_port(resolved_url)
	var path := _extract_path(resolved_url)
	var tls_options := TLSOptions.client()
	if debug:
		print("[%s] connect host=%s port=%s path=%s body_bytes=%s" % [provider_name, host, str(port), path, str(body_text.length())])
	var connect_code := client.connect_to_host(host, port, tls_options)
	if connect_code != OK:
		return _attach_http_timing({"ok": false, "error": "connect_failed", "code": connect_code}, request_started_us, 0.0, 0.0, 0.0)
	var connect_started_us := _now_usec()
	while true:
		client.poll()
		var status := client.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			break
		if status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE:
			client.close()
			return _attach_http_timing({"ok": false, "error": "connect_failed", "status": status}, request_started_us, _elapsed_ms(connect_started_us), 0.0, 0.0)
		if Time.get_ticks_msec() > deadline_ms:
			client.close()
			return _attach_http_timing({"ok": false, "error": "connect_timeout", "status": status}, request_started_us, _elapsed_ms(connect_started_us), 0.0, 0.0)
		OS.delay_msec(20)
	var connect_ms := _elapsed_ms(connect_started_us)
	var request_code := client.request(HTTPClient.METHOD_POST, path, headers, body_text)
	if request_code != OK:
		client.close()
		return _attach_http_timing({"ok": false, "error": "request_failed", "code": request_code}, request_started_us, connect_ms, 0.0, 0.0)
	var response_wait_started_us := _now_usec()
	while true:
		client.poll()
		var status := client.get_status()
		if status == HTTPClient.STATUS_BODY:
			break
		if status == HTTPClient.STATUS_CONNECTED and client.has_response():
			break
		if status == HTTPClient.STATUS_DISCONNECTED and not client.has_response():
			break
		if Time.get_ticks_msec() > deadline_ms:
			client.close()
			return _attach_http_timing({"ok": false, "error": "response_timeout", "status": status}, request_started_us, connect_ms, _elapsed_ms(response_wait_started_us), 0.0)
		OS.delay_msec(20)
	var response_code: int = client.get_response_code()
	var body := PackedByteArray()
	var idle_rounds := 0
	var body_read_started_us := _now_usec()
	while client.get_status() == HTTPClient.STATUS_BODY or client.has_response():
		client.poll()
		var chunk := PackedByteArray()
		if client.get_status() == HTTPClient.STATUS_BODY:
			chunk = client.read_response_body_chunk()
		if not chunk.is_empty():
			body.append_array(chunk)
			idle_rounds = 0
		else:
			idle_rounds += 1
		var status := client.get_status()
		if status != HTTPClient.STATUS_BODY and idle_rounds > 3:
			break
		if Time.get_ticks_msec() > deadline_ms:
			client.close()
			return _attach_http_timing({"ok": false, "error": "body_timeout", "status_code": response_code}, request_started_us, connect_ms, _elapsed_ms(response_wait_started_us), _elapsed_ms(body_read_started_us))
		if chunk.is_empty():
			OS.delay_usec(1000)
	client.close()
	return _attach_http_timing({"ok": true, "status_code": response_code, "body": body.get_string_from_utf8()}, request_started_us, connect_ms, _elapsed_ms(response_wait_started_us), _elapsed_ms(body_read_started_us))

func _should_fallback_from_helper(result: Dictionary) -> bool:
	if bool(result.get("ok", false)):
		return false
	var error_code := str(result.get("error", ""))
	return error_code == "helper_execute_failed" \
		or error_code == "helper_script_missing" \
		or error_code == "helper_empty_response" \
		or error_code == "helper_invalid_json" \
		or error_code == "helper_exception"


func _should_retry(result: Dictionary) -> bool:
	var error_code := str(result.get("error", ""))
	if error_code == "connect_timeout" or error_code == "request_timeout" or error_code == "response_timeout" or error_code == "body_timeout":
		return true
	if error_code == "http_error":
		var status_code := int(result.get("status_code", 0))
		return status_code == 429 or status_code >= 500
	return false

func _should_disable_thinking_from_error(result: Dictionary) -> bool:
	var body_text := _collect_error_text(result).to_lower()
	if body_text.is_empty():
		return false
	if not body_text.contains("thinking"):
		return false
	for keyword in [
		"unsupported",
		"not support",
		"does not support",
		"unknown parameter",
		"unexpected parameter",
		"unrecognized",
		"invalid parameter",
		"not allowed",
		"extra inputs are not permitted",
		"additional properties are not allowed"
	]:
		if body_text.contains(keyword):
			return true
	return false

func _should_retry_without_thinking_for_invalid_content(response_payload: Dictionary, choice_message: Dictionary, content: String) -> bool:
	var reasoning_content := str(choice_message.get("reasoning_content", "")).strip_edges()
	var choices = response_payload.get("choices", [])
	var has_content := not content.strip_edges().is_empty()
	if not (choices is Array) or choices.is_empty():
		return not has_content and not reasoning_content.is_empty()
	var first_choice = choices[0]
	if not (first_choice is Dictionary):
		return not has_content and not reasoning_content.is_empty()
	var finish_reason := str(first_choice.get("finish_reason", "")).strip_edges().to_lower()
	if finish_reason == "length":
		return true
	return not has_content and not reasoning_content.is_empty()

func _get_invalid_content_recovery_max_tokens(base_max_tokens: int, response_payload: Dictionary) -> int:
	var floor_value: int = max(2048, base_max_tokens * 2)
	if _extract_finish_reason(response_payload) == "length":
		return floor_value
	return max(base_max_tokens, floor_value)

func _extract_finish_reason(response_payload: Dictionary) -> String:
	var choices = response_payload.get("choices", [])
	if not (choices is Array) or choices.is_empty():
		return ""
	var first_choice = choices[0]
	if not (first_choice is Dictionary):
		return ""
	return str(first_choice.get("finish_reason", "")).strip_edges().to_lower()

func _collect_error_text(result: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["error", "body", "message", "content"]:
		var value := str(result.get(key, "")).strip_edges()
		if not value.is_empty():
			parts.append(value)
	var output_value = result.get("output", [])
	if output_value is Array:
		for item in output_value:
			var output_line := str(item).strip_edges()
			if not output_line.is_empty():
				parts.append(output_line)
	return "\n".join(parts)

func _build_payload(request: Dictionary, include_thinking_override = null, force_strict_json_recovery: bool = false, force_fast_json_mode: bool = false, max_tokens_override: int = -1) -> Dictionary:
	var conversation_messages = request.get("conversation_messages", [])
	var has_conversation: bool = false
	if conversation_messages is Array:
		has_conversation = not (conversation_messages as Array).is_empty()
	var candidates: Array = request.get("candidates", [])
	var script_analysis: Array = request.get("script_analysis", [])
	var requested_output_schema: Dictionary = request.get("output_schema", {}).duplicate(true)
	var candidate_id_only_output := _is_candidate_id_only_schema(requested_output_schema)
	var prompt_request := {
		"observation": request.get("observation", {}).duplicate(true),
		"candidates": candidates.duplicate(true),
		"context": request.get("context", {}).duplicate(true),
		"output_schema": requested_output_schema,
		"meta": _build_prompt_meta(request.get("meta", {}))
	}
	if force_fast_json_mode:
		prompt_request["output_schema"] = {
			"candidate_id": "string"
		}
	if include_script_analysis:
		prompt_request["script_analysis"] = script_analysis.duplicate(true)
	var extra: Dictionary = request.get("meta", {}).get("extra", {})
	var repair_context: Dictionary = extra.get("repair", {})
	var plan_mode: bool = bool(extra.get("plan_mode", false))
	var system_lines: Array[String] = [
		"你是《十二军团》的对局决策助手。",
		"你只能从给定 candidates 中选择候选，绝不能编造不存在的 candidate_id、command_type 或 payload。",
		"如果只有一个 candidate，则必须选择它。",
		"当你想做的动作在 candidates 中不存在时，必须从 candidates 里选择最优替代方案。",
		"必须输出 JSON 对象。"
	]
	if not force_fast_json_mode and not candidate_id_only_output:
		system_lines.append("brief_reason 只能解释你最终选择的那个 candidate_id。")
	var system_text := "\n".join(system_lines)
	if plan_mode:
		system_text = "%s\n%s" % [system_text, "输出格式：{\"plan\":[{\"candidate_id\":\"...\",\"command_type\":\"可选\",\"payload\":{},\"confidence\":0~1,\"brief_reason\":\"...\"},...],\"stop_reason\":\"...\"}；plan 至少 1 步，最多 12 步。plan 中每一步都必须至少提供 candidate_id，或者同时提供 command_type 与 payload，不能只写意图描述。第 1 步优先填写当前 candidates 中的 candidate_id；后续步骤如果未来 candidate_id 尚未知晓，可填写 command_type 与 payload，系统会在该步骤真正变为合法时匹配。"]
	elif force_fast_json_mode or candidate_id_only_output:
		system_text = "%s\n%s" % [system_text, "输出格式：{\"candidate_id\":\"...\"}。不要输出 confidence，不要输出 brief_reason，不要输出任何额外字段。"]
	else:
		system_text = "%s\n%s" % [system_text, "输出格式：{\"candidate_id\":\"...\",\"confidence\":0~1,\"brief_reason\":\"...\"}。"]
	if repair_context is Dictionary and not repair_context.is_empty():
		system_text = "%s\n%s" % [system_text, "你的上一次回答不可用或不合法。请忽略上一次回答，严格从 candidates 中选择最优替代。"]
	if force_strict_json_recovery:
		system_text = "%s\n%s" % [system_text, "恢复模式：不要输出任何解释、前缀、后缀、Markdown 或额外文字，只输出单行 JSON 对象。brief_reason 尽量简短，控制在 32 个字以内。"]
	if force_fast_json_mode:
		system_text = "%s\n%s" % [system_text, "快速模式：只输出单行 JSON，对象内只允许 candidate_id。除了 candidate_id 之外不要输出任何解释或字段。"]
	var user_text := JSON.stringify(prompt_request)
	var messages: Array = []
	if has_conversation:
		messages = conversation_messages.duplicate(true)
		if not messages.is_empty() and messages[0] is Dictionary and str(messages[0].get("role", "")) == "system":
			var merged_system_message: Dictionary = (messages[0] as Dictionary).duplicate(true)
			merged_system_message["content"] = "%s\n%s" % [str(merged_system_message.get("content", "")), system_text]
			messages[0] = merged_system_message
		else:
			messages.insert(0, {"role": "system", "content": system_text})
	else:
		messages = [{"role": "system", "content": system_text}]
	messages.append({"role": "user", "content": user_text})
	var payload := {
		"model": model,
		"messages": messages,
		"response_format": {
			"type": "json_object"
		},
		"stream": false,
		"max_tokens": max_tokens_override if max_tokens_override > 0 else response_max_tokens
	}
	var use_thinking := enable_thinking
	if include_thinking_override is bool:
		use_thinking = bool(include_thinking_override)
	if use_thinking:
		payload["thinking"] = {
			"type": "enabled"
		}
	for key in request_extras.keys():
		payload[str(key)] = request_extras.get(key)
	return payload

func _build_prompt_meta(meta_value) -> Dictionary:
	if not (meta_value is Dictionary):
		return {}
	var meta: Dictionary = meta_value
	var prompt_meta := {
		"player_id": int(meta.get("player_id", -1)),
		"candidate_count": int(meta.get("candidate_count", 0)),
		"waiting_state": _clone_prompt_value(meta.get("waiting_state", {}))
	}
	if bool(meta.get("opening_protocol_trim", false)):
		prompt_meta["opening_protocol_trim"] = true
	return prompt_meta

func _is_candidate_id_only_schema(schema: Dictionary) -> bool:
	return schema.size() == 1 and str(schema.get("candidate_id", "")) == "string"

func _clone_prompt_value(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

func _extract_choice_message(payload: Dictionary) -> Dictionary:
	var choices = payload.get("choices", [])
	if not (choices is Array) or choices.is_empty():
		return {}
	var raw_choice = choices[0]
	if not (raw_choice is Dictionary):
		return {}
	return raw_choice.get("message", {}).duplicate(true)

func _should_force_opening_fast_json_mode(request: Dictionary) -> bool:
	if not enable_thinking:
		return false
	var meta = request.get("meta", {})
	var extra = meta.get("extra", {}) if meta is Dictionary else {}
	var repair_context = extra.get("repair", {}) if extra is Dictionary else {}
	if repair_context is Dictionary and not repair_context.is_empty():
		return false
	if bool(extra.get("plan_mode", false)):
		return false
	var observation = request.get("observation", {})
	var turn_number := 0
	if observation is Dictionary:
		turn_number = int(observation.get("turn_number", observation.get("turn", 0)))
	if turn_number > 1:
		return false
	var candidate_count := 0
	if meta is Dictionary:
		candidate_count = int(meta.get("candidate_count", 0))
	if candidate_count <= 0:
		var candidates = request.get("candidates", [])
		candidate_count = candidates.size() if candidates is Array else 0
	return candidate_count > 1 and candidate_count <= 12

func _try_parse_json_object_from_text(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return {}
	if trimmed.begins_with("```"):
		var first_newline := trimmed.find("\n")
		if first_newline >= 0:
			trimmed = trimmed.substr(first_newline + 1)
			var fence_end := trimmed.rfind("```")
			if fence_end >= 0:
				trimmed = trimmed.substr(0, fence_end)
			trimmed = trimmed.strip_edges()
	if trimmed.begins_with("{") and trimmed.ends_with("}"):
		var parsed = JSON.parse_string(trimmed)
		if parsed is Dictionary:
			return parsed
	var start := trimmed.find("{")
	if start < 0:
		return {}
	var end := trimmed.rfind("}")
	while end > start:
		var candidate := trimmed.substr(start, end - start + 1)
		var parsed2 = JSON.parse_string(candidate)
		if parsed2 is Dictionary:
			return parsed2
		end = trimmed.rfind("}", end - 1)
	return {}

func _extract_host(url: String) -> String:
	var normalized := url.trim_prefix("https://").trim_prefix("http://")
	var slash_index := normalized.find("/")
	var host_port := normalized if slash_index < 0 else normalized.substr(0, slash_index)
	var colon_index := host_port.find(":")
	return host_port if colon_index < 0 else host_port.substr(0, colon_index)

func _extract_port(url: String) -> int:
	var normalized := url.trim_prefix("https://").trim_prefix("http://")
	var slash_index := normalized.find("/")
	var host_port := normalized if slash_index < 0 else normalized.substr(0, slash_index)
	var colon_index := host_port.find(":")
	if colon_index < 0:
		return 443
	var port_text := host_port.substr(colon_index + 1)
	return 443 if not port_text.is_valid_int() else int(port_text)

func _extract_path(url: String) -> String:
	var normalized := url.trim_prefix("https://").trim_prefix("http://")
	var slash_index := normalized.find("/")
	if slash_index < 0:
		return "/"
	return normalized.substr(slash_index)

func _normalize_chat_completions_url(url: String) -> String:
	var trimmed := url.strip_edges()
	if trimmed.is_empty():
		return DEFAULT_BASE_URL
	if trimmed.ends_with("/chat/completions"):
		return trimmed
	if trimmed.ends_with("/v1"):
		return "%s/chat/completions" % trimmed
	if trimmed.ends_with("/"):
		trimmed = trimmed.trim_suffix("/")
	return "%s/chat/completions" % trimmed

func _attach_client_timing(response: Dictionary, choose_started_us: int, attempt_traces: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = response.duplicate(true)
	result["timing_trace"] = _build_client_timing_trace(choose_started_us, attempt_traces)
	return result

func _build_client_timing_trace(choose_started_us: int, attempt_traces: Array[Dictionary]) -> Dictionary:
	var attempts: Array[Dictionary] = []
	var payload_build_total_ms := 0.0
	var parse_total_ms := 0.0
	var network_total_ms := 0.0
	var helper_total_ms := 0.0
	var http_total_ms := 0.0
	var retry_count := 0
	for trace_value in attempt_traces:
		if not (trace_value is Dictionary):
			continue
		var attempt: Dictionary = (trace_value as Dictionary).duplicate(true)
		attempts.append(attempt)
		payload_build_total_ms += float(attempt.get("payload_build_ms", 0.0))
		parse_total_ms += float(attempt.get("content_parse_ms", 0.0))
		parse_total_ms += float(attempt.get("recovery_parse_ms", 0.0))
		if bool(attempt.get("retried", false)):
			retry_count += 1
		var helper_timing: Dictionary = attempt.get("helper_timing", {})
		if helper_timing is Dictionary:
			var helper_summary: Dictionary = helper_timing.get("summary", {})
			var helper_ms := float(helper_summary.get("total_ms", 0.0))
			helper_total_ms += helper_ms
			network_total_ms += helper_ms
		var helper_fallback_timing: Dictionary = attempt.get("http_fallback_timing", {})
		if helper_fallback_timing is Dictionary:
			var http_summary: Dictionary = helper_fallback_timing.get("summary", {})
			var http_ms := float(http_summary.get("total_ms", 0.0))
			http_total_ms += http_ms
			network_total_ms += http_ms
		var http_timing: Dictionary = attempt.get("http_timing", {})
		if http_timing is Dictionary:
			var http_direct_summary: Dictionary = http_timing.get("summary", {})
			var http_direct_ms := float(http_direct_summary.get("total_ms", 0.0))
			http_total_ms += http_direct_ms
			network_total_ms += http_direct_ms
	return {
		"kind": "llm_client",
		"summary": {
			"total_ms": _elapsed_ms(choose_started_us),
			"attempt_count": attempts.size(),
			"retry_count": retry_count,
			"payload_build_total_ms": payload_build_total_ms,
			"parse_total_ms": parse_total_ms,
			"network_total_ms": network_total_ms,
			"helper_total_ms": helper_total_ms,
			"http_total_ms": http_total_ms
		},
		"attempts": attempts
	}

func _attach_transport_timing(result: Dictionary, started_us: int) -> Dictionary:
	var response: Dictionary = result.duplicate(true)
	response["timing"] = {
		"kind": "external_helper",
		"summary": {
			"total_ms": _elapsed_ms(started_us)
		}
	}
	return response

func _attach_http_timing(result: Dictionary, request_started_us: int, connect_ms: float, response_wait_ms: float, body_read_ms: float) -> Dictionary:
	var response: Dictionary = result.duplicate(true)
	response["timing"] = {
		"kind": "http_client",
		"summary": {
			"total_ms": _elapsed_ms(request_started_us),
			"connect_ms": connect_ms,
			"response_wait_ms": response_wait_ms,
			"body_read_ms": body_read_ms
		}
	}
	return response

func _extract_transport_status(result: Dictionary) -> String:
	if bool(result.get("ok", false)):
		return "ok"
	if result.has("error"):
		return str(result.get("error", ""))
	if result.has("status_code"):
		return "status_%s" % str(result.get("status_code", ""))
	return "unknown"

func _now_usec() -> int:
	return Time.get_ticks_usec()

func _elapsed_ms(started_us: int) -> float:
	return max(0.0, float(Time.get_ticks_usec() - started_us) / 1000.0)
