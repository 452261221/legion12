extends RefCounted
class_name MatchHistoryStore

const ReplayIO = preload("res://client/scripts/replay/replay_io.gd")
const MatchReplaySession = preload("res://client/scripts/replay/match_replay_session.gd")

const BATTLE_LOG_DIR := "user://battle_logs"
const HISTORY_ROOT_DIR := "user://match_history"
const HISTORY_INDEX_PATH := "user://match_history/index.json"
const HISTORY_REPLAY_DIR := "user://match_history/replays"
const DEFAULT_RECORD_LIMIT := 200

static var _storage_root_dir: String = HISTORY_ROOT_DIR
static var _storage_index_path: String = HISTORY_INDEX_PATH
static var _storage_replay_dir: String = HISTORY_REPLAY_DIR

static func configure_storage_paths(root_dir: String) -> void:
	_storage_root_dir = root_dir
	_storage_index_path = "%s/index.json" % root_dir.trim_suffix("/")
	_storage_replay_dir = "%s/replays" % root_dir.trim_suffix("/")

static func reset_storage_paths() -> void:
	_storage_root_dir = HISTORY_ROOT_DIR
	_storage_index_path = HISTORY_INDEX_PATH
	_storage_replay_dir = HISTORY_REPLAY_DIR

static func get_storage_root_dir() -> String:
	return _storage_root_dir

static func get_storage_index_path() -> String:
	return _storage_index_path

static func get_storage_replay_dir() -> String:
	return _storage_replay_dir

func ensure_storage_ready() -> Dictionary:
	var root_abs := ProjectSettings.globalize_path(get_storage_root_dir())
	if DirAccess.make_dir_recursive_absolute(root_abs) != OK:
		return {"ok": false, "code": "CREATE_DIR_FAILED", "message": "failed to create history root dir"}
	var replay_abs := ProjectSettings.globalize_path(get_storage_replay_dir())
	if DirAccess.make_dir_recursive_absolute(replay_abs) != OK:
		return {"ok": false, "code": "CREATE_DIR_FAILED", "message": "failed to create history replay dir"}
	return {"ok": true}

func load_index() -> Dictionary:
	var ensure_result = ensure_storage_ready()
	if not bool(ensure_result.get("ok", false)):
		return ensure_result
	if not FileAccess.file_exists(get_storage_index_path()):
		var empty_index = _create_empty_index()
		var save_result = save_index(empty_index)
		if not bool(save_result.get("ok", false)):
			return save_result
		return {"ok": true, "data": empty_index}
	var content = FileAccess.get_file_as_string(get_storage_index_path())
	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return {"ok": false, "code": "INDEX_INVALID_JSON", "message": "index json is invalid"}
	var errors = _validate_index_data(parsed)
	if not errors.is_empty():
		return {"ok": false, "code": "INDEX_INVALID_SCHEMA", "message": "index schema invalid", "errors": errors}
	return {"ok": true, "data": _normalize_index_data(parsed)}

func save_index(index_data: Dictionary) -> Dictionary:
	var ensure_result = ensure_storage_ready()
	if not bool(ensure_result.get("ok", false)):
		return ensure_result
	var errors = _validate_index_data(index_data)
	if not errors.is_empty():
		return {"ok": false, "code": "INDEX_INVALID_SCHEMA", "message": "index schema invalid", "errors": errors}
	var normalized = _normalize_index_data(index_data)
	normalized["updated_at"] = int(Time.get_unix_time_from_system())
	var file = FileAccess.open(get_storage_index_path(), FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(ProjectSettings.globalize_path(get_storage_index_path()), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": "OPEN_WRITE_FAILED", "message": "failed to open index for write"}
	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return {"ok": true}

func list_records(tab: String = "all", filters: Dictionary = {}) -> Dictionary:
	var load_result = load_index()
	if not bool(load_result.get("ok", false)):
		return load_result
	var index_data: Dictionary = load_result.get("data", {})
	var result: Array[Dictionary] = []
	var keyword_filter := str(filters.get("keyword", "")).strip_edges().to_lower()
	var mode_filter := str(filters.get("mode", ""))
	var status_filter := str(filters.get("status", ""))
	var favorites_only := bool(filters.get("favorites_only", false))
	var resumable_only := bool(filters.get("resumable_only", false))
	var imported_only := bool(filters.get("imported_only", false))
	var started_at_min := int(filters.get("started_at_min", 0))
	var started_at_max := int(filters.get("started_at_max", 0))
	var sort_by := str(filters.get("sort_by", "started_at"))
	var sort_order := str(filters.get("sort_order", "desc"))
	for record in index_data.get("records", []):
		if not (record is Dictionary):
			continue
		if tab == "favorites" and not bool(record.get("is_favorite", false)):
			continue
		if favorites_only and not bool(record.get("is_favorite", false)):
			continue
		if resumable_only and not bool(record.get("can_continue", false)):
			continue
		if imported_only and not bool(record.get("is_imported", false)):
			continue
		if not mode_filter.is_empty() and str(record.get("mode", "")) != mode_filter:
			continue
		if not status_filter.is_empty() and str(record.get("status", "")) != status_filter:
			continue
		var started_at := int(record.get("started_at", 0))
		if started_at_min > 0 and started_at < started_at_min:
			continue
		if started_at_max > 0 and started_at > started_at_max:
			continue
		if not keyword_filter.is_empty() and not _record_matches_keyword(record, keyword_filter):
			continue
		result.append(record.duplicate(true))
	result.sort_custom(func(a, b): return _compare_record_order(a, b, sort_by, sort_order))
	return {"ok": true, "data": {"records": result}}

func get_statistics_summary(tab: String = "all", filters: Dictionary = {}) -> Dictionary:
	var list_result = list_records(tab, filters)
	if not bool(list_result.get("ok", false)):
		return list_result
	var records = list_result.get("data", {}).get("records", [])
	if not (records is Array):
		return {"ok": false, "code": "INDEX_INVALID_SCHEMA", "message": "records must be an array"}
	var total_count := 0
	var favorite_count := 0
	var imported_count := 0
	var resumable_count := 0
	var finished_count := 0
	var interrupted_count := 0
	var total_turns := 0
	var total_commands := 0
	var mode_counts := {}
	for record in records:
		if not (record is Dictionary):
			continue
		total_count += 1
		if bool(record.get("is_favorite", false)):
			favorite_count += 1
		if bool(record.get("is_imported", false)):
			imported_count += 1
		if bool(record.get("can_continue", false)):
			resumable_count += 1
		match str(record.get("status", "")):
			"finished":
				finished_count += 1
			"interrupted":
				interrupted_count += 1
		total_turns += int(record.get("turn_count", 0))
		total_commands += int(record.get("command_count", 0))
		var mode := str(record.get("mode", "unknown"))
		mode_counts[mode] = int(mode_counts.get(mode, 0)) + 1
	var top_mode := ""
	var top_mode_count := 0
	for mode in mode_counts.keys():
		var count := int(mode_counts.get(mode, 0))
		if count > top_mode_count:
			top_mode = str(mode)
			top_mode_count = count
	return {
		"ok": true,
		"data": {
			"total_count": total_count,
			"favorite_count": favorite_count,
			"imported_count": imported_count,
			"resumable_count": resumable_count,
			"finished_count": finished_count,
			"interrupted_count": interrupted_count,
			"average_turn_count": 0.0 if total_count <= 0 else float(total_turns) / float(total_count),
			"average_command_count": 0.0 if total_count <= 0 else float(total_commands) / float(total_count),
			"top_mode": top_mode,
			"top_mode_count": top_mode_count
		}
	}

func get_record(record_id: String) -> Dictionary:
	var load_result = load_index()
	if not bool(load_result.get("ok", false)):
		return load_result
	var index_data: Dictionary = load_result.get("data", {})
	for record in index_data.get("records", []):
		if record is Dictionary and str(record.get("record_id", "")) == record_id:
			return {"ok": true, "data": record.duplicate(true)}
	return {"ok": false, "code": "INDEX_RECORD_NOT_FOUND", "message": "record not found"}

func find_record_by_replay_id(replay_id: String) -> Dictionary:
	if replay_id.is_empty():
		return {"ok": false, "code": "INDEX_RECORD_NOT_FOUND", "message": "replay id is empty"}
	var load_result = load_index()
	if not bool(load_result.get("ok", false)):
		return load_result
	var index_data: Dictionary = load_result.get("data", {})
	for record in index_data.get("records", []):
		if record is Dictionary and str(record.get("replay_id", "")) == replay_id:
			return {"ok": true, "data": record.duplicate(true)}
	return {"ok": false, "code": "INDEX_RECORD_NOT_FOUND", "message": "record not found"}

func get_replay_data(record_id: String) -> Dictionary:
	var record_result = get_record(record_id)
	if not bool(record_result.get("ok", false)):
		return record_result
	var record: Dictionary = record_result.get("data", {})
	var replay_path := str(record.get("replay_path", ""))
	if replay_path.is_empty():
		return {"ok": false, "code": "REPLAY_FILE_NOT_FOUND", "message": "replay path missing in record"}
	return ReplayIO.load_replay_data(replay_path)

func read_ai_log(record_id: String) -> Dictionary:
	var record_result = get_record(record_id)
	if not bool(record_result.get("ok", false)):
		return record_result
	var record: Dictionary = record_result.get("data", {})
	var replay_result = get_replay_data(record_id)
	var replay_data: Dictionary = replay_result.get("data", {}) if bool(replay_result.get("ok", false)) else {}
	var resolved_path := resolve_ai_log_path(record, replay_data)
	if resolved_path.is_empty():
		return {"ok": false, "code": "AI_LOG_NOT_FOUND", "message": "ai log path not found"}
	var content := _read_text_file(resolved_path)
	if content.is_empty() and not _path_exists(resolved_path):
		return {"ok": false, "code": "AI_LOG_NOT_FOUND", "message": "ai log file not found", "path": resolved_path}
	return {"ok": true, "data": {"path": resolved_path, "content": content}}

func resolve_ai_log_path(record: Dictionary, replay_data: Dictionary = {}) -> String:
	var history_info: Dictionary = replay_data.get("history_info", {})
	var candidates: Array[String] = [
		str(record.get("ai_log_path", "")),
		str(history_info.get("ai_log_path", ""))
	]
	var duel_log_path := str(record.get("duel_log_path", history_info.get("duel_log_path", "")))
	if not duel_log_path.is_empty():
		candidates.append(_derive_ai_log_path_from_duel_log(duel_log_path))
	for candidate in candidates:
		var resolved := _resolve_existing_path(candidate)
		if not resolved.is_empty():
			return resolved
	var started_at := int(record.get("started_at", 0))
	if started_at > 0:
		return _find_ai_log_by_started_at(started_at)
	return ""

func save_match_record(replay_data: Dictionary, summary: Dictionary = {}) -> Dictionary:
	var ensure_result = ensure_storage_ready()
	if not bool(ensure_result.get("ok", false)):
		return ensure_result
	var normalized = ReplayIO.normalize_replay_data(replay_data)
	if normalized.is_empty():
		return {"ok": false, "code": "INVALID_REPLAY_SCHEMA", "message": "replay data could not be normalized"}
	var replay_id := str(normalized.get("metadata", {}).get("replay_id", ""))
	if replay_id.is_empty():
		replay_id = _generate_id("rpl")
		normalized["metadata"]["replay_id"] = replay_id
	var record_id := _generate_id("rec")
	var replay_path := "%s/%s.l12r.json" % [get_storage_replay_dir(), replay_id]
	var save_result = ReplayIO.save_replay_data(normalized, replay_path)
	if not bool(save_result.get("ok", false)):
		return save_result
	var record = _build_record_from_replay(record_id, replay_id, replay_path, normalized, _with_replay_runtime_summary(normalized, summary))
	var load_index_result = load_index()
	if not bool(load_index_result.get("ok", false)):
		return load_index_result
	var index_data: Dictionary = load_index_result.get("data", {})
	index_data["records"].append(record)
	var index_save = save_index(index_data)
	if not bool(index_save.get("ok", false)):
		return index_save
	return {"ok": true, "data": {"record_id": record_id, "replay_id": replay_id, "replay_path": replay_path}}

func import_replay_file(source_path: String, options: Dictionary = {}) -> Dictionary:
	var ensure_result = ensure_storage_ready()
	if not bool(ensure_result.get("ok", false)):
		return ensure_result
	var loaded = ReplayIO.load_replay_data(source_path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var normalized: Dictionary = loaded.get("data", {})
	var replay_id := str(normalized.get("metadata", {}).get("replay_id", ""))
	if replay_id.is_empty():
		replay_id = _generate_id("rpl")
		normalized["metadata"]["replay_id"] = replay_id
	var load_index_result = load_index()
	if not bool(load_index_result.get("ok", false)):
		return load_index_result
	var index_data: Dictionary = load_index_result.get("data", {})
	var replace_existing := bool(options.get("replace_existing", false))
	var existing_record_id := ""
	for record in index_data.get("records", []):
		if record is Dictionary and str(record.get("replay_id", "")) == replay_id:
			existing_record_id = str(record.get("record_id", ""))
			if not replace_existing:
				return {
					"ok": false,
					"code": "REPLAY_ALREADY_EXISTS",
					"message": "replay already imported",
					"data": {
						"record_id": existing_record_id,
						"replay_id": replay_id
					}
				}
			break
	if replace_existing and not existing_record_id.is_empty():
		var delete_result = delete_record(existing_record_id, true)
		if not bool(delete_result.get("ok", false)):
			return delete_result
		load_index_result = load_index()
		if not bool(load_index_result.get("ok", false)):
			return load_index_result
		index_data = load_index_result.get("data", {})
	var record_id := _generate_id("rec")
	var replay_path := "%s/%s.l12r.json" % [get_storage_replay_dir(), replay_id]
	var save_result = ReplayIO.save_replay_data(normalized, replay_path)
	if not bool(save_result.get("ok", false)):
		return save_result
	var record = _build_record_from_replay(record_id, replay_id, replay_path, normalized, _with_replay_runtime_summary(normalized, {"is_imported": true}))
	index_data["records"].append(record)
	var index_save = save_index(index_data)
	if not bool(index_save.get("ok", false)):
		return index_save
	return {"ok": true, "data": {"record_id": record_id}}

func export_record(record_id: String, target_path: String, options: Dictionary = {}) -> Dictionary:
	var record_result = get_record(record_id)
	if not bool(record_result.get("ok", false)):
		return record_result
	var record: Dictionary = record_result.get("data", {})
	var replay_path := str(record.get("replay_path", ""))
	if replay_path.is_empty() or not FileAccess.file_exists(replay_path):
		return {"ok": false, "code": "REPLAY_FILE_NOT_FOUND", "message": "replay file is missing"}
	var content = FileAccess.get_file_as_string(replay_path)
	if content.is_empty():
		return {"ok": false, "code": "EXPORT_READ_FAILED", "message": "failed to read replay file"}
	var dir_abs := ProjectSettings.globalize_path(target_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(dir_abs) != OK:
		return {"ok": false, "code": "EXPORT_WRITE_FAILED", "message": "failed to create export dir"}
	var overwrite_existing := bool(options.get("overwrite_existing", false))
	if FileAccess.file_exists(target_path) and not overwrite_existing:
		return {"ok": false, "code": "EXPORT_TARGET_EXISTS", "message": "target file already exists"}
	var file = FileAccess.open(target_path, FileAccess.WRITE)
	if file == null and (target_path.begins_with("user://") or target_path.begins_with("res://")):
		file = FileAccess.open(ProjectSettings.globalize_path(target_path), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": "EXPORT_WRITE_FAILED", "message": "failed to open export file for write"}
	file.store_string(content)
	file.close()
	return {"ok": true}

func delete_record(record_id: String, delete_replay_file: bool = true) -> Dictionary:
	var load_result = load_index()
	if not bool(load_result.get("ok", false)):
		return load_result
	var index_data: Dictionary = load_result.get("data", {})
	var target_index := -1
	var replay_path := ""
	for i in range(index_data.get("records", []).size()):
		var record = index_data["records"][i]
		if record is Dictionary and str(record.get("record_id", "")) == record_id:
			target_index = i
			replay_path = str(record.get("replay_path", ""))
			break
	if target_index < 0:
		return {"ok": false, "code": "INDEX_RECORD_NOT_FOUND", "message": "record not found"}
	index_data["records"].remove_at(target_index)
	var save_result = save_index(index_data)
	if not bool(save_result.get("ok", false)):
		return save_result
	if delete_replay_file and not replay_path.is_empty():
		var abs := ProjectSettings.globalize_path(replay_path)
		if FileAccess.file_exists(replay_path):
			DirAccess.remove_absolute(abs)
	return {"ok": true}

func set_favorite(record_id: String, value: bool) -> Dictionary:
	var load_result = load_index()
	if not bool(load_result.get("ok", false)):
		return load_result
	var index_data: Dictionary = load_result.get("data", {})
	for record in index_data.get("records", []):
		if record is Dictionary and str(record.get("record_id", "")) == record_id:
			record["is_favorite"] = value
			var save_result = save_index(index_data)
			if not bool(save_result.get("ok", false)):
				return save_result
			return {"ok": true}
	return {"ok": false, "code": "INDEX_RECORD_NOT_FOUND", "message": "record not found"}

func toggle_favorite(record_id: String) -> Dictionary:
	var record_result = get_record(record_id)
	if not bool(record_result.get("ok", false)):
		return record_result
	var record: Dictionary = record_result.get("data", {})
	return set_favorite(record_id, not bool(record.get("is_favorite", false)))

func scan_storage_health() -> Dictionary:
	var ensure_result = ensure_storage_ready()
	if not bool(ensure_result.get("ok", false)):
		return ensure_result
	var issues: Array[Dictionary] = []
	var replay_files := _list_replay_files()
	var load_result = load_index()
	if not bool(load_result.get("ok", false)):
		issues.append({
			"code": str(load_result.get("code", "INDEX_LOAD_FAILED")),
			"message": str(load_result.get("message", "index load failed")),
			"severity": "error"
		})
		for replay_path in replay_files:
			issues.append({
				"code": "ORPHAN_REPLAY_FILE",
				"message": "orphan replay file",
				"severity": "warning",
				"replay_path": replay_path
			})
		return {"ok": true, "data": {"healthy": issues.is_empty(), "issues": issues}}
	var index_data: Dictionary = load_result.get("data", {})
	var seen_record_ids := {}
	var seen_replay_ids := {}
	var indexed_paths := {}
	for record in index_data.get("records", []):
		if not (record is Dictionary):
			issues.append({"code": "INDEX_RECORD_INVALID", "message": "index record is invalid", "severity": "error"})
			continue
		var record_id := str(record.get("record_id", ""))
		var replay_id := str(record.get("replay_id", ""))
		var replay_path := str(record.get("replay_path", ""))
		if record_id.is_empty():
			issues.append({"code": "INDEX_RECORD_ID_MISSING", "message": "record id missing", "severity": "error"})
		elif seen_record_ids.has(record_id):
			issues.append({"code": "INDEX_RECORD_ID_DUPLICATED", "message": "duplicate record id", "severity": "error", "record_id": record_id})
		else:
			seen_record_ids[record_id] = true
		if replay_id.is_empty():
			issues.append({"code": "INDEX_REPLAY_ID_MISSING", "message": "replay id missing", "severity": "error"})
		elif seen_replay_ids.has(replay_id):
			issues.append({"code": "INDEX_REPLAY_ID_DUPLICATED", "message": "duplicate replay id", "severity": "error", "replay_id": replay_id})
		else:
			seen_replay_ids[replay_id] = true
		if replay_path.is_empty():
			issues.append({"code": "INDEX_REPLAY_PATH_MISSING", "message": "replay path missing", "severity": "error", "record_id": record_id})
			continue
		indexed_paths[replay_path] = true
		if not FileAccess.file_exists(replay_path):
			issues.append({"code": "INDEX_REPLAY_FILE_MISSING", "message": "indexed replay file missing", "severity": "error", "record_id": record_id, "replay_path": replay_path})
	for replay_path in replay_files:
		if not indexed_paths.has(replay_path):
			issues.append({"code": "ORPHAN_REPLAY_FILE", "message": "orphan replay file", "severity": "warning", "replay_path": replay_path})
	return {"ok": true, "data": {"healthy": issues.is_empty(), "issues": issues}}

func repair_storage_index() -> Dictionary:
	var ensure_result = ensure_storage_ready()
	if not bool(ensure_result.get("ok", false)):
		return ensure_result
	var previous_records: Array = []
	var load_result = load_index()
	if bool(load_result.get("ok", false)):
		previous_records = load_result.get("data", {}).get("records", [])
	var summary_by_replay_id := {}
	for old_record in previous_records:
		if not (old_record is Dictionary):
			continue
		var replay_id := str(old_record.get("replay_id", ""))
		if replay_id.is_empty() or summary_by_replay_id.has(replay_id):
			continue
		summary_by_replay_id[replay_id] = {
			"record_id": str(old_record.get("record_id", "")),
			"is_favorite": bool(old_record.get("is_favorite", false)),
			"is_imported": bool(old_record.get("is_imported", false)),
			"can_continue": bool(old_record.get("can_continue", false)),
			"continue_check_code": str(old_record.get("continue_check_code", "")),
			"recommended_command_index": int(old_record.get("recommended_command_index", -1)),
			"tags": old_record.get("tags", []).duplicate(true) if old_record.get("tags", null) is Array else [],
			"notes": str(old_record.get("notes", "")),
			"mode": str(old_record.get("mode", "")),
			"status": str(old_record.get("status", "")),
			"source_record_id": str(old_record.get("source_record_id", "")),
			"source_command_index": int(old_record.get("source_command_index", -1))
		}
	var rebuilt_records: Array[Dictionary] = []
	var repaired_count := 0
	var skipped_invalid_count := 0
	var seen_replay_ids := {}
	for replay_path in _list_replay_files():
		var loaded = ReplayIO.load_replay_data(replay_path)
		if not bool(loaded.get("ok", false)):
			skipped_invalid_count += 1
			continue
		var replay_data: Dictionary = loaded.get("data", {})
		var replay_id := str(replay_data.get("metadata", {}).get("replay_id", ""))
		if replay_id.is_empty():
			replay_id = replay_path.get_file().trim_suffix(".l12r.json").trim_suffix(".json")
			replay_data["metadata"]["replay_id"] = replay_id
		if seen_replay_ids.has(replay_id):
			skipped_invalid_count += 1
			continue
		seen_replay_ids[replay_id] = true
		var summary: Dictionary = summary_by_replay_id.get(replay_id, {})
		var record_id := str(summary.get("record_id", ""))
		if record_id.is_empty():
			record_id = _generate_id("rec")
		var record = _build_record_from_replay(record_id, replay_id, replay_path, replay_data, _with_replay_runtime_summary(replay_data, summary))
		rebuilt_records.append(record)
		repaired_count += 1
	var rebuilt_index := _create_empty_index()
	rebuilt_index["records"] = rebuilt_records
	var save_result = save_index(rebuilt_index)
	if not bool(save_result.get("ok", false)):
		return save_result
	return {
		"ok": true,
		"data": {
			"record_count": rebuilt_records.size(),
			"repaired_count": repaired_count,
			"skipped_invalid_count": skipped_invalid_count
		}
	}

func get_capacity_status(record_limit: int = DEFAULT_RECORD_LIMIT) -> Dictionary:
	var ensure_result = ensure_storage_ready()
	if not bool(ensure_result.get("ok", false)):
		return ensure_result
	var load_result = load_index()
	if not bool(load_result.get("ok", false)):
		return load_result
	var index_data: Dictionary = load_result.get("data", {})
	var record_count := 0
	var favorite_count := 0
	for record in index_data.get("records", []):
		if not (record is Dictionary):
			continue
		record_count += 1
		if bool(record.get("is_favorite", false)):
			favorite_count += 1
	return {
		"ok": true,
		"data": {
			"record_limit": record_limit,
			"record_count": record_count,
			"favorite_count": favorite_count,
			"overflow_count": max(record_count - record_limit, 0),
			"is_over_limit": record_count > record_limit
		}
	}

func prune_old_records(record_limit: int = DEFAULT_RECORD_LIMIT, keep_favorites: bool = true) -> Dictionary:
	var load_result = load_index()
	if not bool(load_result.get("ok", false)):
		return load_result
	var index_data: Dictionary = load_result.get("data", {})
	var records = index_data.get("records", [])
	if not (records is Array):
		return {"ok": false, "code": "INDEX_INVALID_SCHEMA", "message": "records must be an array"}
	var total_count: int = records.size()
	var overflow_count: int = max(total_count - record_limit, 0)
	if overflow_count <= 0:
		return {"ok": true, "data": {"removed_count": 0, "remaining_count": total_count}}
	var removable: Array[Dictionary] = []
	for record in records:
		if not (record is Dictionary):
			continue
		if keep_favorites and bool(record.get("is_favorite", false)):
			continue
		removable.append(record)
	removable.sort_custom(func(a, b): return int(a.get("started_at", 0)) < int(b.get("started_at", 0)))
	var removed_count: int = 0
	for record in removable:
		if total_count <= record_limit:
			break
		var delete_result = delete_record(str(record.get("record_id", "")), true)
		if not bool(delete_result.get("ok", false)):
			continue
		total_count -= 1
		removed_count += 1
	return {"ok": true, "data": {"removed_count": removed_count, "remaining_count": total_count}}

func _create_empty_index() -> Dictionary:
	return {
		"format": "l12_match_history_index",
		"version": 1,
		"updated_at": 0,
		"records": []
	}

func _validate_index_data(index_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(index_data.get("format", "")) != "l12_match_history_index":
		errors.append("format must be l12_match_history_index")
	if not _is_int_like(index_data.get("version", null)):
		errors.append("version must be an integer")
	if not (index_data.get("records", null) is Array):
		errors.append("records must be an array")
	return errors

func _normalize_index_data(index_data: Dictionary) -> Dictionary:
	var normalized = index_data.duplicate(true)
	normalized["version"] = int(normalized.get("version", 1))
	if not normalized.has("updated_at"):
		normalized["updated_at"] = 0
	normalized["updated_at"] = int(normalized.get("updated_at", 0))
	if not (normalized.get("records", null) is Array):
		normalized["records"] = []
	return normalized

func _build_record_from_replay(record_id: String, replay_id: String, replay_path: String, replay_data: Dictionary, summary: Dictionary) -> Dictionary:
	var setup: Dictionary = replay_data.get("setup", {})
	var players = setup.get("players", [])
	var p0: Dictionary = players[0] if players is Array and players.size() > 0 and players[0] is Dictionary else {}
	var p1: Dictionary = players[1] if players is Array and players.size() > 1 and players[1] is Dictionary else {}
	var p0_name := str(p0.get("master_name", p0.get("name", "Player 1")))
	var p1_name := str(p1.get("master_name", p1.get("name", "Player 2")))
	var title := "%s vs %s" % [p0_name, p1_name]
	var result: Dictionary = replay_data.get("result", {})
	var winner := int(result.get("winner", -1))
	var winner_master_id := str(result.get("winner_master_id", ""))
	var winner_master_name := str(result.get("winner_master_name", ""))
	var mode := str(replay_data.get("history_info", {}).get("mode", summary.get("mode", "unknown")))
	var status := str(replay_data.get("history_info", {}).get("status", summary.get("status", "finished" if winner != -1 else "interrupted")))
	var started_at := int(replay_data.get("metadata", {}).get("started_at", 0))
	var finished_at := int(replay_data.get("metadata", {}).get("finished_at", 0))
	var command_count := int(replay_data.get("commands", []).size())
	var turn_count := 0
	if replay_data.get("commands", []) is Array and command_count > 0:
		var last_row = replay_data.get("commands", [])[command_count - 1]
		if last_row is Dictionary:
			turn_count = int(last_row.get("turn_after", last_row.get("turn_before", 0)))
	var source_record_id := str(replay_data.get("history_info", {}).get("source_record_id", summary.get("source_record_id", "")))
	var source_command_index := int(replay_data.get("history_info", {}).get("source_command_index", summary.get("source_command_index", -1)))
	var duel_log_path := str(replay_data.get("history_info", {}).get("duel_log_path", summary.get("duel_log_path", "")))
	var ai_log_path := str(replay_data.get("history_info", {}).get("ai_log_path", summary.get("ai_log_path", "")))
	return {
		"record_id": record_id,
		"replay_id": replay_id,
		"replay_path": replay_path,
		"title": title,
		"mode": mode,
		"status": status,
		"player_a_master_id": str(p0.get("master_id", "")),
		"player_a_master_name": str(p0.get("master_name", "")),
		"player_b_master_id": str(p1.get("master_id", "")),
		"player_b_master_name": str(p1.get("master_name", "")),
		"winner_player_id": winner,
		"winner_master_id": winner_master_id,
		"winner_master_name": winner_master_name,
		"started_at": started_at,
		"finished_at": finished_at,
		"turn_count": turn_count,
		"command_count": command_count,
		"is_favorite": bool(summary.get("is_favorite", false)),
		"is_imported": bool(summary.get("is_imported", false)),
		"is_replay_compatible": true,
		"compatibility_code": "",
		"compatibility_message": "",
		"can_continue": bool(summary.get("can_continue", false)),
		"continue_check_code": str(summary.get("continue_check_code", "")),
		"recommended_command_index": int(summary.get("recommended_command_index", -1)),
		"source_record_id": source_record_id,
		"source_command_index": source_command_index,
		"duel_log_path": duel_log_path,
		"ai_log_path": ai_log_path,
		"tags": summary.get("tags", []),
		"notes": str(summary.get("notes", ""))
	}

func _resolve_existing_path(path: String) -> String:
	var normalized := str(path).strip_edges()
	if normalized.is_empty():
		return ""
	if _path_exists(normalized):
		return normalized
	if normalized.begins_with("user://") or normalized.begins_with("res://"):
		var absolute := ProjectSettings.globalize_path(normalized)
		if _path_exists(absolute):
			return absolute
	return ""

func _derive_ai_log_path_from_duel_log(duel_log_path: String) -> String:
	var normalized := str(duel_log_path).replace("\\", "/")
	var file_name := normalized.get_file()
	if file_name.begins_with("duel_"):
		return "%s/%s" % [normalized.get_base_dir(), "ai_%s" % file_name.trim_prefix("duel_")]
	return ""

func _find_ai_log_by_started_at(started_at: int) -> String:
	var root_path := ProjectSettings.globalize_path(BATTLE_LOG_DIR)
	var dir := DirAccess.open(root_path)
	if dir == null:
		return ""
	var prefix := "ai_%s_" % str(started_at)
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if name.begins_with(prefix) and name.to_lower().ends_with(".log"):
			dir.list_dir_end()
			return root_path.path_join(name).replace("\\", "/")
	dir.list_dir_end()
	return ""

func _path_exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func _read_text_file(path: String) -> String:
	var resolved := _resolve_existing_path(path)
	if resolved.is_empty():
		return ""
	return FileAccess.get_file_as_string(resolved)

static func _with_replay_runtime_summary(replay_data: Dictionary, base_summary: Dictionary) -> Dictionary:
	var summary := base_summary.duplicate(true)
	var runtime := _build_replay_runtime_summary(replay_data)
	for key in runtime.keys():
		summary[key] = runtime[key]
	return summary

static func _build_replay_runtime_summary(replay_data: Dictionary) -> Dictionary:
	var session := MatchReplaySession.new()
	var load_result := session.load_replay_data(replay_data)
	if not bool(load_result.get("ok", false)):
		return {
			"can_continue": false,
			"continue_check_code": "REPLAY_LOAD_FAILED",
			"recommended_command_index": -1
		}
	var total_commands := session.get_total_command_count()
	for command_index in range(total_commands, -1, -1):
		var jump_result := session.jump_to_command(command_index)
		if not bool(jump_result.get("ok", false)):
			continue
		var state = session.get_current_state()
		if _can_resume_from_state(state):
			return {
				"can_continue": true,
				"continue_check_code": "",
				"recommended_command_index": command_index
			}
	return {
		"can_continue": false,
		"continue_check_code": "NO_STABLE_RESUME_POINT",
		"recommended_command_index": -1
	}

static func _can_resume_from_state(state) -> bool:
	if state == null:
		return false
	if int(state.winner) != -1:
		return false
	if not state.stack.is_empty():
		return false
	if not state.pending_choices.is_empty():
		return false
	if not state.pending_attack.is_empty():
		return false
	return true

static func _generate_id(prefix: String) -> String:
	var raw := "%s_%s_%s" % [prefix, str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	var digest := raw.sha256_text()
	return "%s_%s" % [prefix, digest.substr(0, 16)]

static func _is_int_like(value) -> bool:
	return value is int or (value is float and int(value) == value) or (value is String and String(value).is_valid_int())

static func _record_matches_keyword(record: Dictionary, keyword: String) -> bool:
	var search_parts: Array[String] = [
		str(record.get("title", "")),
		str(record.get("winner_master_name", "")),
		str(record.get("player_a_master_name", "")),
		str(record.get("player_b_master_name", "")),
		str(record.get("mode", "")),
		str(record.get("status", "")),
		str(record.get("replay_id", "")),
		str(record.get("notes", ""))
	]
	if record.get("tags", null) is Array:
		for tag in record.get("tags", []):
			search_parts.append(str(tag))
	for part in search_parts:
		if part.to_lower().contains(keyword):
			return true
	return false

static func _compare_record_order(a: Dictionary, b: Dictionary, sort_by: String, sort_order: String) -> bool:
	var left
	var right
	match sort_by:
		"finished_at":
			left = int(a.get("finished_at", 0))
			right = int(b.get("finished_at", 0))
		"turn_count":
			left = int(a.get("turn_count", 0))
			right = int(b.get("turn_count", 0))
		"command_count":
			left = int(a.get("command_count", 0))
			right = int(b.get("command_count", 0))
		"title":
			left = str(a.get("title", "")).to_lower()
			right = str(b.get("title", "")).to_lower()
		_:
			left = int(a.get("started_at", 0))
			right = int(b.get("started_at", 0))
	if left == right:
		return int(a.get("started_at", 0)) > int(b.get("started_at", 0))
	if sort_order == "asc":
		return left < right
	return left > right

func _list_replay_files() -> Array[String]:
	var ensure_result = ensure_storage_ready()
	if not bool(ensure_result.get("ok", false)):
		return []
	var files: Array[String] = []
	var dir := DirAccess.open(get_storage_replay_dir())
	if dir == null:
		return files
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and (name.ends_with(".json") or name.ends_with(".l12r.json")):
			files.append("%s/%s" % [get_storage_replay_dir(), name])
		name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files
