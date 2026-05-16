extends RefCounted
class_name TestMatchHistoryStore

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MatchHistoryStore = preload("res://client/scripts/history/match_history_store.gd")
const ReplayIO = preload("res://tools/replay_runner/replay_io.gd")

const IMPORT_DIR := "res://.tmp_history_test_data/imports"
const TEST_HISTORY_ROOT := "res://.tmp_history_test_data/match_history"

static func run() -> Array[String]:
	var failures: Array[String] = []
	var setup = _begin_isolated_history_storage()
	if not bool(setup.get("ok", false)):
		failures.append("history test setup failed: %s" % str(setup.get("message", "")))
		return failures
	var store := MatchHistoryStore.new()
	_test_save_and_filter_records(store, failures)
	_test_import_duplicate_and_replace(store, failures)
	_test_export_conflict(store, failures)
	_test_health_scan_and_repair(store, failures)
	_test_capacity_prune_keeps_favorites(store, failures)
	_test_ai_log_lookup(store, failures)
	var teardown = _end_isolated_history_storage(setup)
	if not bool(teardown.get("ok", false)):
		failures.append("history test teardown failed: %s" % str(teardown.get("message", "")))
	return failures

static func _test_save_and_filter_records(store: MatchHistoryStore, failures: Array[String]) -> void:
	_reset_runtime_storage()
	var replay_a := _sample_replay("history_filter_a", 101, 100, 180)
	replay_a["history_info"] = {"mode": "formal", "status": "finished"}
	var save_a = store.save_match_record(replay_a, {"notes": "alpha note"})
	_expect_ok(save_a, "history save/filter: first record should save", failures)
	if not bool(save_a.get("ok", false)):
		return
	var replay_b := _sample_replay("history_filter_b", 102, 200, 260)
	replay_b["history_info"] = {"mode": "network_resume", "status": "interrupted"}
	var save_b = store.save_match_record(replay_b, {"notes": "beta note"})
	_expect_ok(save_b, "history save/filter: second record should save", failures)
	if not bool(save_b.get("ok", false)):
		return
	_expect(bool(store.set_favorite(str(save_b.get("data", {}).get("record_id", "")), true).get("ok", false)), "history save/filter: should mark second record favorite", failures)
	var keyword_result = store.list_records("all", {"keyword": "beta"})
	_expect(bool(keyword_result.get("ok", false)), "history save/filter: keyword listing should succeed", failures)
	if bool(keyword_result.get("ok", false)):
		var keyword_records: Array = keyword_result.get("data", {}).get("records", [])
		_expect(keyword_records.size() == 1, "history save/filter: keyword should match one record", failures)
		if keyword_records.size() == 1:
			_expect(str(keyword_records[0].get("replay_id", "")) == "history_filter_b", "history save/filter: keyword should return beta replay", failures)
	var favorite_result = store.list_records("all", {"favorites_only": true})
	_expect(bool(favorite_result.get("ok", false)), "history save/filter: favorites listing should succeed", failures)
	if bool(favorite_result.get("ok", false)):
		var favorite_records: Array = favorite_result.get("data", {}).get("records", [])
		_expect(favorite_records.size() == 1, "history save/filter: favorites filter should keep one record", failures)
	var resumable_result = store.list_records("all", {"resumable_only": true})
	_expect(bool(resumable_result.get("ok", false)), "history save/filter: resumable listing should succeed", failures)
	if bool(resumable_result.get("ok", false)):
		var resumable_records: Array = resumable_result.get("data", {}).get("records", [])
		_expect(resumable_records.size() == 2, "history save/filter: resumable filter should keep both fixture records", failures)
	var imported_result = store.list_records("all", {"imported_only": true})
	_expect(bool(imported_result.get("ok", false)), "history save/filter: imported listing should succeed", failures)
	if bool(imported_result.get("ok", false)):
		var imported_records: Array = imported_result.get("data", {}).get("records", [])
		_expect(imported_records.is_empty(), "history save/filter: imported-only filter should exclude local fixtures", failures)
	var time_range_result = store.list_records("all", {"started_at_min": 150})
	_expect(bool(time_range_result.get("ok", false)), "history save/filter: time range listing should succeed", failures)
	if bool(time_range_result.get("ok", false)):
		var time_range_records: Array = time_range_result.get("data", {}).get("records", [])
		_expect(time_range_records.size() == 1, "history save/filter: started_at_min should keep one newer record", failures)
		if time_range_records.size() == 1:
			_expect(str(time_range_records[0].get("replay_id", "")) == "history_filter_b", "history save/filter: started_at_min should keep beta replay", failures)
	var sort_result = store.list_records("all", {"sort_by": "started_at", "sort_order": "asc"})
	_expect(bool(sort_result.get("ok", false)), "history save/filter: sorted listing should succeed", failures)
	if bool(sort_result.get("ok", false)):
		var sorted_records: Array = sort_result.get("data", {}).get("records", [])
		_expect(sorted_records.size() == 2, "history save/filter: sorted listing should return both records", failures)
		if sorted_records.size() == 2:
			_expect(str(sorted_records[0].get("replay_id", "")) == "history_filter_a", "history save/filter: ascending sort should place earlier record first", failures)
	var stats_result = store.get_statistics_summary("all", {})
	_expect(bool(stats_result.get("ok", false)), "history save/filter: statistics summary should succeed", failures)
	if bool(stats_result.get("ok", false)):
		var stats: Dictionary = stats_result.get("data", {})
		_expect(int(stats.get("total_count", 0)) == 2, "history save/filter: statistics should count both records", failures)
		_expect(int(stats.get("favorite_count", 0)) == 1, "history save/filter: statistics should count one favorite", failures)
		_expect(int(stats.get("resumable_count", 0)) == 2, "history save/filter: statistics should count two resumable records", failures)
		_expect(int(stats.get("interrupted_count", 0)) == 1, "history save/filter: statistics should count interrupted records", failures)

static func _test_import_duplicate_and_replace(store: MatchHistoryStore, failures: Array[String]) -> void:
	_reset_runtime_storage()
	var import_path := _runtime_import_path("history_import_duplicate.json")
	var original := _sample_replay("history_import_same", 201, 1000, 1100)
	var original_save = ReplayIO.save_replay_data(original, import_path)
	_expect_ok(original_save, "history import: should save source replay", failures)
	if not bool(original_save.get("ok", false)):
		return
	var first_import = store.import_replay_file(import_path)
	_expect(bool(first_import.get("ok", false)), "history import: first import should succeed", failures)
	var duplicate_import = store.import_replay_file(import_path)
	_expect(not bool(duplicate_import.get("ok", false)), "history import: duplicate import should fail before replacement", failures)
	_expect(str(duplicate_import.get("code", "")) == "REPLAY_ALREADY_EXISTS", "history import: duplicate import should return explicit conflict code", failures)
	var replacement := _sample_replay("history_import_same", 202, 2000, 2100)
	replacement["setup"]["players"][0]["master_name"] = "替换后主宰A"
	var replacement_save = ReplayIO.save_replay_data(replacement, import_path)
	_expect_ok(replacement_save, "history import: should overwrite source replay fixture", failures)
	var replace_result = store.import_replay_file(import_path, {"replace_existing": true})
	_expect(bool(replace_result.get("ok", false)), "history import: replace existing should succeed", failures)
	var records_result = store.list_records()
	_expect(bool(records_result.get("ok", false)), "history import: listing after replacement should succeed", failures)
	if bool(records_result.get("ok", false)):
		var records: Array = records_result.get("data", {}).get("records", [])
		_expect(records.size() == 1, "history import: replacement should still leave one record", failures)
		if records.size() == 1:
			_expect(str(records[0].get("player_a_master_name", "")) == "替换后主宰A", "history import: replacement should refresh stored record data", failures)

static func _test_export_conflict(store: MatchHistoryStore, failures: Array[String]) -> void:
	_reset_runtime_storage()
	var save_result = store.save_match_record(_sample_replay("history_export_target", 301, 3000, 3200), {})
	_expect_ok(save_result, "history export: record should save", failures)
	if not bool(save_result.get("ok", false)):
		return
	var target_path := _runtime_import_path("history_export_target.json")
	var first_export = store.export_record(str(save_result.get("data", {}).get("record_id", "")), target_path)
	_expect(bool(first_export.get("ok", false)), "history export: first export should succeed", failures)
	var second_export = store.export_record(str(save_result.get("data", {}).get("record_id", "")), target_path)
	_expect(not bool(second_export.get("ok", false)), "history export: second export without overwrite should fail", failures)
	_expect(str(second_export.get("code", "")) == "EXPORT_TARGET_EXISTS", "history export: should report target exists conflict", failures)

static func _test_health_scan_and_repair(store: MatchHistoryStore, failures: Array[String]) -> void:
	_reset_runtime_storage()
	var indexed_save = store.save_match_record(_sample_replay("history_health_keep", 401, 4000, 4100), {})
	_expect_ok(indexed_save, "history health: indexed record should save", failures)
	if not bool(indexed_save.get("ok", false)):
		return
	var indexed_record_id := str(indexed_save.get("data", {}).get("record_id", ""))
	_expect(bool(store.set_favorite(indexed_record_id, true).get("ok", false)), "history health: should mark indexed record favorite", failures)
	var orphan_replay := _sample_replay("history_orphan_only", 402, 4200, 4300)
	var orphan_path := "%s/%s.l12r.json" % [MatchHistoryStore.get_storage_replay_dir(), "history_orphan_only"]
	_expect_ok(ReplayIO.save_replay_data(orphan_replay, orphan_path), "history health: orphan replay should save", failures)
	var health_result = store.scan_storage_health()
	_expect(bool(health_result.get("ok", false)), "history health: scan should succeed", failures)
	if bool(health_result.get("ok", false)):
		var issues: Array = health_result.get("data", {}).get("issues", [])
		_expect(_issues_contains_code(issues, "ORPHAN_REPLAY_FILE"), "history health: scan should detect orphan replay file", failures)
	var repair_result = store.repair_storage_index()
	_expect(bool(repair_result.get("ok", false)), "history health: repair should succeed", failures)
	var records_result = store.list_records()
	_expect(bool(records_result.get("ok", false)), "history health: list after repair should succeed", failures)
	if bool(records_result.get("ok", false)):
		var records: Array = records_result.get("data", {}).get("records", [])
		_expect(records.size() == 2, "history health: repair should rebuild both indexed and orphan replay records", failures)
		var repaired_favorite := false
		var orphan_found := false
		for record in records:
			if not (record is Dictionary):
				continue
			if str(record.get("replay_id", "")) == "history_health_keep":
				repaired_favorite = bool(record.get("is_favorite", false))
			if str(record.get("replay_id", "")) == "history_orphan_only":
				orphan_found = true
		_expect(repaired_favorite, "history health: repair should preserve favorite flag for rebuilt indexed record", failures)
		_expect(orphan_found, "history health: repair should add orphan replay back into index", failures)

static func _test_capacity_prune_keeps_favorites(store: MatchHistoryStore, failures: Array[String]) -> void:
	_reset_runtime_storage()
	var oldest = store.save_match_record(_sample_replay("history_capacity_oldest", 501, 10, 20), {})
	var middle = store.save_match_record(_sample_replay("history_capacity_middle", 502, 30, 40), {})
	var newest = store.save_match_record(_sample_replay("history_capacity_newest", 503, 50, 60), {})
	_expect(bool(oldest.get("ok", false)) and bool(middle.get("ok", false)) and bool(newest.get("ok", false)), "history capacity: all records should save (%s | %s | %s)" % [_format_result(oldest), _format_result(middle), _format_result(newest)], failures)
	if not (bool(oldest.get("ok", false)) and bool(middle.get("ok", false)) and bool(newest.get("ok", false))):
		return
	_expect(bool(store.set_favorite(str(oldest.get("data", {}).get("record_id", "")), true).get("ok", false)), "history capacity: should favorite oldest record", failures)
	var capacity_status = store.get_capacity_status(2)
	_expect(bool(capacity_status.get("ok", false)), "history capacity: status should succeed", failures)
	if bool(capacity_status.get("ok", false)):
		_expect(bool(capacity_status.get("data", {}).get("is_over_limit", false)), "history capacity: status should report overflow", failures)
		_expect(int(capacity_status.get("data", {}).get("overflow_count", 0)) == 1, "history capacity: overflow count should be one", failures)
	var prune_result = store.prune_old_records(2, true)
	_expect(bool(prune_result.get("ok", false)), "history capacity: prune should succeed", failures)
	var list_result = store.list_records("all", {"sort_by": "started_at", "sort_order": "asc"})
	_expect(bool(list_result.get("ok", false)), "history capacity: listing after prune should succeed", failures)
	if bool(list_result.get("ok", false)):
		var records: Array = list_result.get("data", {}).get("records", [])
		_expect(records.size() == 2, "history capacity: prune should leave two records", failures)
		var replay_ids: Array[String] = []
		for record in records:
			if record is Dictionary:
				replay_ids.append(str(record.get("replay_id", "")))
		_expect(replay_ids.has("history_capacity_oldest"), "history capacity: prune should keep favorite oldest record", failures)
		_expect(not replay_ids.has("history_capacity_middle"), "history capacity: prune should remove oldest non-favorite record", failures)

static func _test_ai_log_lookup(store: MatchHistoryStore, failures: Array[String]) -> void:
	_reset_runtime_storage()
	var ai_log_path := _runtime_import_path("history_ai_log_sample.log")
	var ai_log_file := FileAccess.open(ai_log_path, FileAccess.WRITE)
	_expect(ai_log_file != null, "history ai log: should create ai log fixture file", failures)
	if ai_log_file == null:
		return
	ai_log_file.store_string("sample ai log body")
	ai_log_file.close()
	var replay := _sample_replay("history_ai_log_record", 601, 70, 80)
	replay["history_info"] = {
		"mode": "formal",
		"status": "finished",
		"ai_log_path": ai_log_path
	}
	var save_result = store.save_match_record(replay, {})
	_expect_ok(save_result, "history ai log: record should save", failures)
	if not bool(save_result.get("ok", false)):
		return
	var record_id := str(save_result.get("data", {}).get("record_id", ""))
	var read_result = store.read_ai_log(record_id)
	_expect(bool(read_result.get("ok", false)), "history ai log: read_ai_log should succeed", failures)
	if bool(read_result.get("ok", false)):
		var data: Dictionary = read_result.get("data", {})
		_expect(str(data.get("content", "")) == "sample ai log body", "history ai log: should return saved ai log content", failures)

static func _sample_replay(replay_id: String, seed: int, started_at: int, finished_at: int) -> Dictionary:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), seed)
	var replay_data: Dictionary = engine.export_replay_data_v2(state, {
		"replay_id": replay_id,
		"started_at": started_at,
		"finished_at": finished_at,
		"card_pool_hash": "test_pool_hash",
		"game_version": "test",
		"exported_by": "history_test"
	})
	var result: Dictionary = replay_data.get("result", {})
	result["winner"] = -1
	result["winner_master_id"] = ""
	result["winner_master_name"] = ""
	replay_data["result"] = result
	var players = replay_data.get("setup", {}).get("players", [])
	if players is Array and players.size() >= 2:
		if players[0] is Dictionary:
			players[0]["master_name"] = "测试主宰A%s" % replay_id
		if players[1] is Dictionary:
			players[1]["master_name"] = "测试主宰B%s" % replay_id
	return replay_data

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _runtime_import_path(file_name: String) -> String:
	var absolute_dir := ProjectSettings.globalize_path(IMPORT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	return "%s/%s" % [IMPORT_DIR, file_name]

static func _begin_isolated_history_storage() -> Dictionary:
	MatchHistoryStore.configure_storage_paths(TEST_HISTORY_ROOT)
	var root_abs := ProjectSettings.globalize_path(MatchHistoryStore.get_storage_root_dir())
	_remove_dir_recursive(root_abs)
	var create_code := DirAccess.make_dir_recursive_absolute(root_abs)
	if create_code != OK:
		return {"ok": false, "message": "failed to create test history root: %s" % create_code}
	return {"ok": true}

static func _end_isolated_history_storage(setup: Dictionary) -> Dictionary:
	var root_abs := ProjectSettings.globalize_path(MatchHistoryStore.get_storage_root_dir())
	_remove_dir_recursive(root_abs)
	_remove_dir_recursive(ProjectSettings.globalize_path(IMPORT_DIR))
	MatchHistoryStore.reset_storage_paths()
	return {"ok": true}

static func _reset_runtime_storage() -> void:
	_remove_dir_recursive(ProjectSettings.globalize_path(MatchHistoryStore.get_storage_root_dir()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MatchHistoryStore.get_storage_root_dir()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MatchHistoryStore.get_storage_replay_dir()))
	_remove_dir_recursive(ProjectSettings.globalize_path(IMPORT_DIR))

static func _remove_dir_recursive(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var child_path := "%s/%s" % [path, name]
			if dir.current_is_dir():
				_remove_dir_recursive(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


static func _issues_contains_code(issues: Array, code: String) -> bool:
	for issue in issues:
		if issue is Dictionary and str(issue.get("code", "")) == code:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

static func _expect_ok(result: Dictionary, message: String, failures: Array[String]) -> void:
	_expect(bool(result.get("ok", false)), "%s (%s)" % [message, _format_result(result)], failures)

static func _format_result(result: Dictionary) -> String:
	var parts: Array[String] = []
	if result.has("code"):
		parts.append("code=%s" % str(result.get("code", "")))
	if result.has("message"):
		parts.append("message=%s" % str(result.get("message", "")))
	if result.has("path"):
		parts.append("path=%s" % str(result.get("path", "")))
	if result.has("errors") and result.get("errors", null) is Array:
		parts.append("errors=%s" % JSON.stringify(result.get("errors", [])))
	if parts.is_empty():
		parts.append(JSON.stringify(result))
	return ", ".join(parts)
