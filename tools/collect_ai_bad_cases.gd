extends SceneTree

const DEFAULT_LOG_ROOT := "user://battle_logs"
const DEFAULT_OUTPUT_PATH := "user://battle_logs/ai_bad_cases.json"
const FALLBACK_OUTPUT_PATH := "res://tmp_ai_bad_cases.json"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var log_root := DEFAULT_LOG_ROOT
	var output_path := DEFAULT_OUTPUT_PATH
	if args.size() >= 1:
		log_root = str(args[0])
	if args.size() >= 2:
		output_path = str(args[1])
	var resolved_log_root := _resolve_path(log_root)
	var resolved_output_path := _resolve_path(output_path)
	var log_files: Array[String] = []
	_collect_log_files(resolved_log_root, log_files)
	var bad_cases: Array[Dictionary] = []
	for file_path in log_files:
		bad_cases.append_array(_extract_bad_cases_from_file(file_path))
	var payload := {
		"log_root": resolved_log_root,
		"file_count": log_files.size(),
		"bad_case_count": bad_cases.size(),
		"bad_cases": bad_cases
	}
	var file := _open_output_file(resolved_output_path)
	var final_output_path := resolved_output_path
	if file == null:
		final_output_path = ProjectSettings.globalize_path(FALLBACK_OUTPUT_PATH)
		file = _open_output_file(final_output_path)
	if file == null:
		push_error("collect ai bad cases failed: unable to write %s" % resolved_output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	print("collect ai bad cases wrote %s items to %s" % [str(bad_cases.size()), final_output_path])
	quit(0)

func _resolve_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

func _collect_log_files(root_path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		var child_path := root_path.path_join(name)
		if dir.current_is_dir():
			_collect_log_files(child_path, results)
		elif name.to_lower().ends_with(".log"):
			results.append(child_path)
	dir.list_dir_end()

func _extract_bad_cases_from_file(file_path: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		return results
	var lines := text.split("\n", false)
	for index in range(lines.size()):
		var line := str(lines[index]).strip_edges()
		if line.is_empty():
			continue
		var category := _categorize_bad_case_line(line)
		if category.is_empty():
			continue
		results.append({
			"file_path": file_path,
			"line_number": index + 1,
			"category": category,
			"line": line,
			"context_before": str(lines[max(0, index - 1)]).strip_edges(),
			"context_after": str(lines[min(lines.size() - 1, index + 1)]).strip_edges()
		})
	return results

func _categorize_bad_case_line(line: String) -> String:
	if line.contains("repaired_from="):
		return "repair"
	if line.contains("[AI LLM] fallback") or line.contains("[AI FALLBACK]"):
		return "fallback"
	if line.contains("apply_failed"):
		return "apply_failed"
	if line.contains("missing_api_key"):
		return "missing_api_key"
	if line.contains("[ERR]"):
		return "error"
	return ""

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
