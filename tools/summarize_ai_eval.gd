extends SceneTree

const DEFAULT_EVAL_ROOT := "user://battle_logs/fixed_eval"
const DEFAULT_OUTPUT_PATH := "user://battle_logs/fixed_eval/ai_eval_compare_report.json"
const OUTPUT_FALLBACK_PATH := "res://tmp_ai_eval_compare_report.json"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var input_path := DEFAULT_EVAL_ROOT
	var output_path := DEFAULT_OUTPUT_PATH
	if args.size() >= 1:
		input_path = str(args[0])
	if args.size() >= 2:
		output_path = str(args[1])
	var resolved_input_path := _resolve_path(input_path)
	var resolved_output_path := _resolve_path(output_path)
	var suite_paths := _collect_suite_paths(resolved_input_path)
	var suite_reports: Array[Dictionary] = []
	for suite_path in suite_paths:
		suite_reports.append(_summarize_suite(suite_path))
	var payload := {
		"input_path": resolved_input_path,
		"suite_count": suite_reports.size(),
		"suites": suite_reports
	}
	var file := _open_output_file(resolved_output_path)
	var final_output_path := resolved_output_path
	if file == null:
		final_output_path = ProjectSettings.globalize_path(OUTPUT_FALLBACK_PATH)
		file = _open_output_file(final_output_path)
	if file == null:
		push_error("summarize ai eval failed: unable to write %s" % resolved_output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	_print_summary(suite_reports, final_output_path)
	quit(0)

func _resolve_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

func _collect_suite_paths(input_path: String) -> Array[String]:
	var results: Array[String] = []
	if FileAccess.file_exists(input_path):
		results.append(input_path.get_base_dir())
		return results
	var dir := DirAccess.open(input_path)
	if dir == null:
		return results
	if FileAccess.file_exists(input_path.path_join("suite_summary.log")):
		results.append(input_path)
		return results
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		if not dir.current_is_dir():
			continue
		var suite_path := input_path.path_join(name)
		if FileAccess.file_exists(suite_path.path_join("suite_summary.log")):
			results.append(suite_path)
	dir.list_dir_end()
	results.sort()
	return results

func _summarize_suite(suite_path: String) -> Dictionary:
	var suite_name := suite_path.get_file()
	var suite_summary_path := suite_path.path_join("suite_summary.log")
	var suite_summary_text := FileAccess.get_file_as_string(suite_summary_path)
	var case_summaries := _parse_suite_summary(suite_summary_text)
	var case_reports: Array[Dictionary] = []
	for case_summary in case_summaries:
		case_reports.append(_summarize_case(suite_path, case_summary))
	return {
		"suite_name": suite_name,
		"suite_path": suite_path,
		"suite_summary_path": suite_summary_path,
		"suite_ok": bool(_extract_done_value(suite_summary_text, "ok", false)),
		"case_count": case_reports.size(),
		"cases": case_reports,
		"totals": _aggregate_suite_totals(case_reports)
	}

func _parse_suite_summary(text: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for raw_line in text.split("\n", false):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("[CASE]"):
			continue
		results.append({
			"name": _extract_keyed_value(line, "name"),
			"ok": line.contains("[CASE] ok"),
			"summary_path": _extract_keyed_value(line, "summary")
		})
	return results

func _summarize_case(suite_path: String, case_summary: Dictionary) -> Dictionary:
	var case_name := str(case_summary.get("name", "unknown_case"))
	var summary_path := str(case_summary.get("summary_path", ""))
	var resolved_summary_path := _resolve_case_summary_path(suite_path, summary_path, case_name)
	var case_prefix := resolved_summary_path.get_file().trim_suffix("_summary.log")
	var summary_text := FileAccess.get_file_as_string(resolved_summary_path)
	var ai_logs := _collect_case_logs(suite_path, case_prefix, "_ai.log")
	var step_logs := _collect_case_logs(suite_path, case_prefix, "_steps.log")
	var ai_metrics := _collect_ai_metrics(ai_logs)
	return {
		"case_name": case_name,
		"ok": bool(case_summary.get("ok", false)),
		"summary_path": resolved_summary_path,
		"game_count": int(_extract_done_value(summary_text, "total", 0)),
		"failure_count": int(_extract_done_value(summary_text, "failures", 0)),
		"finished_count": int(_extract_done_value(summary_text, "finished", 0)),
		"ended_reasons": _collect_game_ended_reasons(summary_text),
		"ai_log_count": ai_logs.size(),
		"step_log_count": step_logs.size(),
		"metrics": ai_metrics
	}

func _resolve_case_summary_path(suite_path: String, summary_path: String, case_name: String) -> String:
	var trimmed := summary_path.strip_edges()
	if not trimmed.is_empty():
		if FileAccess.file_exists(trimmed):
			return trimmed
		var normalized := trimmed.replace("\\", "/")
		if FileAccess.file_exists(normalized):
			return normalized
	var fallback_path := suite_path.path_join("%s_llm_summary.log" % case_name)
	return fallback_path

func _collect_case_logs(suite_path: String, case_prefix: String, suffix: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(suite_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if name.begins_with(case_prefix + "_") and name.ends_with(suffix):
			results.append(suite_path.path_join(name))
	dir.list_dir_end()
	results.sort()
	return results

func _collect_ai_metrics(ai_logs: Array[String]) -> Dictionary:
	var metrics := {
		"decision_count": 0,
		"repair_attempted_count": 0,
		"repaired_count": 0,
		"fallback_reason_count": 0,
		"thinking_downgraded_count": 0,
		"source_counts": {},
		"command_type_counts": {}
	}
	for file_path in ai_logs:
		var entries := _parse_ai_log_entries(FileAccess.get_file_as_string(file_path))
		for entry in entries:
			metrics["decision_count"] = int(metrics.get("decision_count", 0)) + 1
			var decision = entry.get("decision", {})
			var llm_response = entry.get("llm_response", {})
			if decision is Dictionary:
				if bool(decision.get("repair_attempted", false)):
					metrics["repair_attempted_count"] = int(metrics.get("repair_attempted_count", 0)) + 1
				if not str(decision.get("repaired_from", "")).strip_edges().is_empty():
					metrics["repaired_count"] = int(metrics.get("repaired_count", 0)) + 1
				if not str(decision.get("fallback_reason", "")).strip_edges().is_empty():
					metrics["fallback_reason_count"] = int(metrics.get("fallback_reason_count", 0)) + 1
				_increment_count(metrics["source_counts"], str(decision.get("source", "unknown")))
				_increment_count(metrics["command_type_counts"], str(decision.get("command_type", "unknown")))
			if llm_response is Dictionary and bool(llm_response.get("thinking_downgraded", false)):
				metrics["thinking_downgraded_count"] = int(metrics.get("thinking_downgraded_count", 0)) + 1
	return metrics

func _parse_ai_log_entries(text: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var begin_marker := "=== AI RAW BEGIN ==="
	var end_marker := "=== AI RAW END ==="
	var cursor := 0
	while true:
		var begin_index := text.find(begin_marker, cursor)
		if begin_index < 0:
			break
		var json_start := begin_index + begin_marker.length()
		var end_index := text.find(end_marker, json_start)
		if end_index < 0:
			break
		var block_text := text.substr(json_start, end_index - json_start).strip_edges()
		var parsed = JSON.parse_string(block_text)
		if parsed is Dictionary:
			results.append(parsed)
		cursor = end_index + end_marker.length()
	return results

func _collect_game_ended_reasons(summary_text: String) -> Dictionary:
	var counts := {}
	for raw_line in summary_text.split("\n", false):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("[GAME]"):
			continue
		_increment_count(counts, _extract_keyed_value(line, "ended"))
	return counts

func _aggregate_suite_totals(case_reports: Array[Dictionary]) -> Dictionary:
	var totals := {
		"decision_count": 0,
		"repair_attempted_count": 0,
		"repaired_count": 0,
		"fallback_reason_count": 0,
		"thinking_downgraded_count": 0,
		"command_type_counts": {},
		"source_counts": {}
	}
	for case_report in case_reports:
		var metrics = case_report.get("metrics", {})
		if not (metrics is Dictionary):
			continue
		for key in ["decision_count", "repair_attempted_count", "repaired_count", "fallback_reason_count", "thinking_downgraded_count"]:
			totals[key] = int(totals.get(key, 0)) + int(metrics.get(key, 0))
		_merge_count_maps(totals["command_type_counts"], metrics.get("command_type_counts", {}))
		_merge_count_maps(totals["source_counts"], metrics.get("source_counts", {}))
	return totals

func _extract_done_value(text: String, key: String, default_value):
	for raw_line in text.split("\n", false):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("[DONE]"):
			continue
		var value_text := _extract_keyed_value(line, key)
		if value_text.is_empty():
			return default_value
		if default_value is bool:
			return value_text == "true"
		if default_value is int:
			return int(value_text) if value_text.is_valid_int() else default_value
		return value_text
	return default_value

func _extract_keyed_value(line: String, key: String) -> String:
	var token := "%s=" % key
	var start := line.find(token)
	if start < 0:
		return ""
	start += token.length()
	var end := line.find(" ", start)
	if end < 0:
		return line.substr(start)
	return line.substr(start, end - start)

func _increment_count(target, key: String) -> void:
	if not (target is Dictionary):
		return
	var normalized_key := key if not key.strip_edges().is_empty() else "unknown"
	target[normalized_key] = int(target.get(normalized_key, 0)) + 1

func _merge_count_maps(target, source) -> void:
	if not (target is Dictionary) or not (source is Dictionary):
		return
	for key in source.keys():
		target[str(key)] = int(target.get(str(key), 0)) + int(source.get(key, 0))

func _open_output_file(path: String) -> FileAccess:
	var output_dir := path.get_base_dir()
	if not output_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		return file
	if path.begins_with("user://") or path.begins_with("res://"):
		var absolute_path := ProjectSettings.globalize_path(path)
		var absolute_dir := absolute_path.get_base_dir()
		if not absolute_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(absolute_dir)
		return FileAccess.open(absolute_path, FileAccess.WRITE)
	return null

func _print_summary(suite_reports: Array[Dictionary], output_path: String) -> void:
	print("ai eval summary suites=%s output=%s" % [str(suite_reports.size()), output_path])
	for suite_report in suite_reports:
		var totals = suite_report.get("totals", {})
		print("[SUITE] %s cases=%s decisions=%s repair=%s fallback=%s thinking_downgraded=%s pass=%s end=%s" % [
			str(suite_report.get("suite_name", "unknown_suite")),
			str(suite_report.get("case_count", 0)),
			str(totals.get("decision_count", 0)),
			str(totals.get("repair_attempted_count", 0)),
			str(totals.get("fallback_reason_count", 0)),
			str(totals.get("thinking_downgraded_count", 0)),
			str((totals.get("command_type_counts", {}) as Dictionary).get("PassPriority", 0)),
			str((totals.get("command_type_counts", {}) as Dictionary).get("EndPhase", 0))
		])
		for case_report in suite_report.get("cases", []):
			var metrics = case_report.get("metrics", {})
			print("  - case=%s ok=%s games=%s decisions=%s repair=%s fallback=%s thinking_downgraded=%s ended=%s" % [
				str(case_report.get("case_name", "unknown_case")),
				str(case_report.get("ok", false)),
				str(case_report.get("game_count", 0)),
				str(metrics.get("decision_count", 0)),
				str(metrics.get("repair_attempted_count", 0)),
				str(metrics.get("fallback_reason_count", 0)),
				str(metrics.get("thinking_downgraded_count", 0)),
				JSON.stringify(case_report.get("ended_reasons", {}))
			])
