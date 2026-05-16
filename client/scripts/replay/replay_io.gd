extends RefCounted
class_name ReplayIO

const DEFAULT_REPLAY_DIR := "user://replays"
const REPOSITORY_REPLAY_DIR := "res://data/replays"
const REPLAY_FORMAT := "l12_replay"

static func save_replay_data(replay_data: Dictionary, path: String = "") -> Dictionary:
	var normalized = normalize_replay_data(replay_data)
	if normalized.is_empty():
		return {
			"ok": false,
			"code": "INVALID_REPLAY_SCHEMA",
			"message": "replay data could not be normalized",
			"path": path
		}
	var errors = validate_replay_v2(normalized)
	if not errors.is_empty():
		return {
			"ok": false,
			"code": "INVALID_REPLAY_SCHEMA",
			"message": "replay data failed schema validation before save",
			"errors": errors,
			"path": path
		}
	var resolved_path = path
	if resolved_path.is_empty():
		var file_name = "replay_%s.json" % Time.get_unix_time_from_system()
		resolved_path = "%s/%s" % [DEFAULT_REPLAY_DIR, file_name]
	var dir_path = resolved_path.get_base_dir()
	var absolute_dir_path = ProjectSettings.globalize_path(dir_path)
	var dir_result = DirAccess.make_dir_recursive_absolute(absolute_dir_path)
	if dir_result != OK:
		return {
			"ok": false,
			"code": "CREATE_DIR_FAILED",
			"message": "failed to create replay directory",
			"path": resolved_path
		}
	var file = FileAccess.open(resolved_path, FileAccess.WRITE)
	var opened_path = resolved_path
	if file == null and (resolved_path.begins_with("user://") or resolved_path.begins_with("res://")):
		opened_path = ProjectSettings.globalize_path(resolved_path)
		file = FileAccess.open(opened_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"code": "OPEN_WRITE_FAILED",
			"message": "failed to open replay file for write",
			"path": resolved_path,
			"opened_path": opened_path
		}
	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return {
		"ok": true,
		"path": resolved_path
	}

static func load_replay_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"code": "FILE_NOT_FOUND",
			"message": "replay file not found",
			"path": path
		}
	var content = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return {
			"ok": false,
			"code": "INVALID_JSON",
			"message": "invalid replay json",
			"path": path
		}
	var normalized = normalize_replay_data(parsed)
	if normalized.is_empty():
		return {
			"ok": false,
			"code": "INVALID_REPLAY_SCHEMA",
			"message": "replay json could not be normalized",
			"path": path
		}
	var validation_errors = validate_replay_v2(normalized)
	if not validation_errors.is_empty():
		return {
			"ok": false,
			"code": "INVALID_REPLAY_SCHEMA",
			"message": "replay json does not match expected schema",
			"path": path,
			"errors": validation_errors
		}
	return {
		"ok": true,
		"path": path,
		"data": normalized
	}

static func list_replay_file_paths(replay_dir_path: String = DEFAULT_REPLAY_DIR) -> Array[String]:
	var replay_dir = DirAccess.open(replay_dir_path)
	if replay_dir == null:
		return []
	var replay_paths: Array[String] = []
	replay_dir.list_dir_begin()
	while true:
		var file_name = replay_dir.get_next()
		if file_name.is_empty():
			break
		if replay_dir.current_is_dir():
			continue
		if not file_name.to_lower().ends_with(".json"):
			continue
		replay_paths.append("%s/%s" % [replay_dir_path.trim_suffix("/"), file_name])
	replay_dir.list_dir_end()
	replay_paths.sort()
	return replay_paths

static func find_latest_replay_path(replay_dir_path: String = DEFAULT_REPLAY_DIR) -> String:
	var replay_paths = list_replay_file_paths(replay_dir_path)
	if replay_paths.is_empty():
		return ""
	return replay_paths.back()

static func list_repository_replay_paths() -> Array[String]:
	return list_replay_file_paths(REPOSITORY_REPLAY_DIR)

static func validate_replay_data(replay_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	_validate_required_int_like(replay_data, "version", errors)
	_validate_required_int_like(replay_data, "seed", errors)
	_validate_required_string(replay_data, "ruleset_id", errors)
	_validate_optional_int_like(replay_data, "winner", errors)
	_validate_optional_string(replay_data, "loss_reason", errors)
	_validate_initial_decks(replay_data.get("initial_decks", null), errors)
	_validate_commands(replay_data.get("commands", null), errors)
	return errors

static func detect_replay_version(replay_data: Dictionary) -> int:
	if str(replay_data.get("format", "")) == REPLAY_FORMAT:
		return int(replay_data.get("version", 0))
	if replay_data.has("version") and replay_data.has("seed") and replay_data.has("ruleset_id") and replay_data.has("initial_decks") and replay_data.has("commands"):
		return 1
	return 0

static func normalize_replay_data(raw: Dictionary) -> Dictionary:
	var version = detect_replay_version(raw)
	if version >= 2:
		return raw.duplicate(true)
	if version == 1:
		var legacy_errors = validate_replay_data(raw)
		if not legacy_errors.is_empty():
			return {}
		return upgrade_v1_to_v2(raw)
	return {}

static func upgrade_v1_to_v2(raw: Dictionary) -> Dictionary:
	var seed := int(raw.get("seed", 1))
	var ruleset_id := str(raw.get("ruleset_id", ""))
	var initial_decks = raw.get("initial_decks", [])
	var players: Array[Dictionary] = []
	if initial_decks is Array:
		for player_id in range(min(2, initial_decks.size())):
			var deck_cards: Array[String] = []
			var raw_deck = initial_decks[player_id]
			if raw_deck is Array:
				for card in raw_deck:
					deck_cards.append(str(card))
			players.append({
				"player_id": player_id,
				"name": "Player %s" % (player_id + 1),
				"master_id": "",
				"master_name": "",
				"deck_name": "",
				"deck_cards": deck_cards
			})
	while players.size() < 2:
		var missing_id = players.size()
		players.append({
			"player_id": missing_id,
			"name": "Player %s" % (missing_id + 1),
			"master_id": "",
			"master_name": "",
			"deck_name": "",
			"deck_cards": []
		})
	var winner := int(raw.get("winner", -1))
	var status := "finished" if winner != -1 else "interrupted"
	return {
		"format": REPLAY_FORMAT,
		"version": 2,
		"metadata": {
			"replay_id": "",
			"created_at": 0,
			"started_at": 0,
			"finished_at": 0,
			"game_version": "legacy_v1",
			"ruleset_id": ruleset_id,
			"card_pool_hash": "legacy_v1",
			"exported_by": "legacy_upgrade"
		},
		"history_info": {
			"mode": "unknown",
			"status": status,
			"source_record_id": "",
			"source_command_index": -1
		},
		"setup": {
			"seed": seed,
			"game_options": {},
			"players": players
		},
		"result": {
			"winner": winner,
			"winner_master_id": "",
			"winner_master_name": "",
			"loss_reason": str(raw.get("loss_reason", ""))
		},
		"commands": raw.get("commands", []).duplicate(true)
	}

static func validate_replay_v2(replay_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	_validate_required_string(replay_data, "format", errors)
	if str(replay_data.get("format", "")) != REPLAY_FORMAT:
		errors.append("format must be %s" % REPLAY_FORMAT)
	_validate_required_int_like(replay_data, "version", errors)
	var metadata = replay_data.get("metadata", null)
	if not (metadata is Dictionary):
		errors.append("metadata must be an object")
	else:
		_validate_required_string(metadata, "ruleset_id", errors, "metadata")
		_validate_required_string(metadata, "card_pool_hash", errors, "metadata")
	var setup = replay_data.get("setup", null)
	if not (setup is Dictionary):
		errors.append("setup must be an object")
	else:
		_validate_required_int_like(setup, "seed", errors, "setup")
		var players = setup.get("players", null)
		if not (players is Array):
			errors.append("setup.players must be an array")
		else:
			for player_index in range(players.size()):
				var player = players[player_index]
				if not (player is Dictionary):
					errors.append("setup.players[%s] must be an object" % player_index)
					continue
				var deck_cards = player.get("deck_cards", null)
				if not (deck_cards is Array):
					errors.append("setup.players[%s].deck_cards must be an array" % player_index)
					continue
				for card_index in range(deck_cards.size()):
					if not (deck_cards[card_index] is String):
						errors.append("setup.players[%s].deck_cards[%s] must be a string" % [player_index, card_index])
						break
	var result = replay_data.get("result", null)
	if not (result is Dictionary):
		errors.append("result must be an object")
	else:
		_validate_required_int_like(result, "winner", errors, "result")
		_validate_optional_string(result, "loss_reason", errors, "result")
	_validate_commands(replay_data.get("commands", null), errors)
	return errors

static func _validate_initial_decks(initial_decks, errors: Array[String]) -> void:
	if not (initial_decks is Array):
		errors.append("initial_decks must be an array")
		return
	for player_index in range(initial_decks.size()):
		var deck = initial_decks[player_index]
		if not (deck is Array):
			errors.append("initial_decks[%s] must be an array" % player_index)
			continue
		for card_index in range(deck.size()):
			if not (deck[card_index] is String):
				errors.append("initial_decks[%s][%s] must be a string" % [player_index, card_index])
				return

static func _validate_commands(commands, errors: Array[String]) -> void:
	if not (commands is Array):
		errors.append("commands must be an array")
		return
	for command_index in range(commands.size()):
		var row = commands[command_index]
		if not (row is Dictionary):
			errors.append("commands[%s] must be an object" % command_index)
			continue
		_validate_required_int_like(row, "player_id", errors, "commands[%s]" % command_index)
		_validate_required_string(row, "type", errors, "commands[%s]" % command_index)
		if not (row.get("payload", {}) is Dictionary):
			errors.append("commands[%s].payload must be an object" % command_index)
		_validate_optional_int_like(row, "index", errors, "commands[%s]" % command_index)
		_validate_optional_int_like(row, "client_time", errors, "commands[%s]" % command_index)
		_validate_optional_string(row, "command_id", errors, "commands[%s]" % command_index)
		_validate_optional_string(row, "phase_before", errors, "commands[%s]" % command_index)
		_validate_optional_string(row, "phase_after", errors, "commands[%s]" % command_index)
		_validate_optional_string(row, "source", errors, "commands[%s]" % command_index)
		_validate_optional_string(row, "state_hash_before", errors, "commands[%s]" % command_index)
		_validate_optional_string(row, "state_hash_after", errors, "commands[%s]" % command_index)
		if row.has("ok") and not (row.get("ok") is bool):
			errors.append("commands[%s].ok must be a bool" % command_index)

static func _validate_required_string(row: Dictionary, key: String, errors: Array[String], prefix: String = "") -> void:
	var value = row.get(key, null)
	if not (value is String) or str(value).is_empty():
		errors.append("%s%s must be a non-empty string" % [_field_prefix(prefix), key])

static func _validate_optional_string(row: Dictionary, key: String, errors: Array[String], prefix: String = "") -> void:
	if not row.has(key) or row.get(key) == null:
		return
	if not (row.get(key) is String):
		errors.append("%s%s must be a string" % [_field_prefix(prefix), key])

static func _validate_required_int_like(row: Dictionary, key: String, errors: Array[String], prefix: String = "") -> void:
	if not row.has(key):
		errors.append("%s%s is required" % [_field_prefix(prefix), key])
		return
	if not _is_int_like(row.get(key)):
		errors.append("%s%s must be an integer" % [_field_prefix(prefix), key])

static func _validate_optional_int_like(row: Dictionary, key: String, errors: Array[String], prefix: String = "") -> void:
	if not row.has(key) or row.get(key) == null:
		return
	if not _is_int_like(row.get(key)):
		errors.append("%s%s must be an integer" % [_field_prefix(prefix), key])

static func _field_prefix(prefix: String) -> String:
	return "" if prefix.is_empty() else "%s." % prefix

static func _is_int_like(value) -> bool:
	return value is int or (value is float and int(value) == value) or (value is String and String(value).is_valid_int())
