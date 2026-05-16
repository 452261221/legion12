extends RefCounted
class_name ReplayRunner

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ReplayIO = preload("res://client/scripts/replay/replay_io.gd")

func run_replay_file(replay_path: String, card_data_path: String = CardDatabase.DEFAULT_CARD_DATA_PATH) -> Dictionary:
	var loaded = ReplayIO.load_replay_data(replay_path)
	if not loaded.ok:
		return loaded
	return run_replay_data(loaded.data, card_data_path)

func run_replay_file_until(replay_path: String, command_index: int, card_data_path: String = CardDatabase.DEFAULT_CARD_DATA_PATH, ignore_hash_verification: bool = false) -> Dictionary:
	var loaded = ReplayIO.load_replay_data(replay_path)
	if not loaded.ok:
		return loaded
	return run_replay_data_until(loaded.data, command_index, card_data_path, ignore_hash_verification)

func run_replay_data(replay_data: Dictionary, card_data_path: String = CardDatabase.DEFAULT_CARD_DATA_PATH) -> Dictionary:
	var normalized = ReplayIO.normalize_replay_data(replay_data)
	if normalized.is_empty():
		return {
			"ok": false,
			"code": "INVALID_REPLAY_SCHEMA",
			"message": "replay data could not be normalized"
		}
	var validation_errors = ReplayIO.validate_replay_v2(normalized)
	if not validation_errors.is_empty():
		return {
			"ok": false,
			"code": "INVALID_REPLAY_SCHEMA",
			"message": "replay data does not match expected schema",
			"errors": validation_errors
		}
	var definitions = _load_card_definitions(card_data_path)
	if definitions.is_empty():
		return {
			"ok": false,
			"code": "CARD_DATA_LOAD_FAILED",
			"message": "failed to load card definitions for replay",
			"card_data_path": card_data_path
		}
	var setup: Dictionary = normalized.get("setup", {})
	var seed := int(setup.get("seed", 1))
	var deck_lists: Array = []
	var player_metadata: Array = []
	var players = setup.get("players", [])
	if players is Array:
		for player_row in players:
			if player_row is Dictionary:
				deck_lists.append(player_row.get("deck_cards", []).duplicate(true))
				player_metadata.append({
					"name": str(player_row.get("name", "")),
					"master_name": str(player_row.get("master_name", "")),
					"master_id": str(player_row.get("master_id", ""))
				})
	var game_options: Dictionary = setup.get("game_options", {})
	var engine = GameEngine.new()
	var state = engine.create_game(definitions, deck_lists, seed, player_metadata, game_options)
	var replay_ruleset_id = str(normalized.get("metadata", {}).get("ruleset_id", ""))
	if replay_ruleset_id != state.ruleset_id:
		return {
			"ok": false,
			"code": "REPLAY_RULESET_MISMATCH",
			"message": "replay ruleset does not match current engine ruleset",
			"replay_ruleset_id": replay_ruleset_id,
			"engine_ruleset_id": state.ruleset_id
		}
	for row in normalized.get("commands", []):
		var command = GameCommand.create(int(row.get("player_id", -1)), str(row.get("type", "")), row.get("payload", {}))
		command.command_id = str(row.get("command_id", command.command_id))
		command.client_time = int(row.get("client_time", command.client_time))
		command.source = str(row.get("source", command.source))
		var result = engine.apply_command(state, command)
		if not result.ok:
			return {
				"ok": false,
				"code": "REPLAY_COMMAND_FAILED",
				"message": "replay command failed",
				"failed_command": row,
				"result": result,
				"state": state
			}
		var expected_before = str(row.get("state_hash_before", ""))
		var expected_after = str(row.get("state_hash_after", ""))
		if not expected_before.is_empty() and expected_before != str(result.get("state_hash_before", "")):
			return {
				"ok": false,
				"code": "REPLAY_HASH_MISMATCH_BEFORE",
				"message": "replay state hash before command does not match",
				"failed_command": row,
				"result": result,
				"state": state
			}
		if not expected_after.is_empty() and expected_after != str(result.get("state_hash_after", "")):
			return {
				"ok": false,
				"code": "REPLAY_HASH_MISMATCH_AFTER",
				"message": "replay state hash after command does not match",
				"failed_command": row,
				"result": result,
				"state": state
			}
	return {
		"ok": true,
		"state": state,
		"engine": engine
	}

func run_replay_data_until(replay_data: Dictionary, command_index: int, card_data_path: String = CardDatabase.DEFAULT_CARD_DATA_PATH, ignore_hash_verification: bool = false) -> Dictionary:
	var normalized = ReplayIO.normalize_replay_data(replay_data)
	if normalized.is_empty():
		return {
			"ok": false,
			"code": "INVALID_REPLAY_SCHEMA",
			"message": "replay data could not be normalized"
		}
	var validation_errors = ReplayIO.validate_replay_v2(normalized)
	if not validation_errors.is_empty():
		return {
			"ok": false,
			"code": "INVALID_REPLAY_SCHEMA",
			"message": "replay data does not match expected schema",
			"errors": validation_errors
		}
	var commands = normalized.get("commands", [])
	if command_index < 0 or command_index > commands.size():
		return {
			"ok": false,
			"code": "REPLAY_COMMAND_INDEX_OUT_OF_RANGE",
			"message": "command index is out of range",
			"command_index": command_index,
			"command_count": commands.size()
		}
	var definitions = _load_card_definitions(card_data_path)
	if definitions.is_empty():
		return {
			"ok": false,
			"code": "CARD_DATA_LOAD_FAILED",
			"message": "failed to load card definitions for replay",
			"card_data_path": card_data_path
		}
	var setup: Dictionary = normalized.get("setup", {})
	var seed := int(setup.get("seed", 1))
	var deck_lists: Array = []
	var player_metadata: Array = []
	var players = setup.get("players", [])
	if players is Array:
		for player_row in players:
			if player_row is Dictionary:
				deck_lists.append(player_row.get("deck_cards", []).duplicate(true))
				player_metadata.append({
					"name": str(player_row.get("name", "")),
					"master_name": str(player_row.get("master_name", "")),
					"master_id": str(player_row.get("master_id", ""))
				})
	var game_options: Dictionary = setup.get("game_options", {})
	var engine = GameEngine.new()
	var state = engine.create_game(definitions, deck_lists, seed, player_metadata, game_options)
	var replay_ruleset_id = str(normalized.get("metadata", {}).get("ruleset_id", ""))
	if replay_ruleset_id != state.ruleset_id:
		return {
			"ok": false,
			"code": "REPLAY_RULESET_MISMATCH",
			"message": "replay ruleset does not match current engine ruleset",
			"replay_ruleset_id": replay_ruleset_id,
			"engine_ruleset_id": state.ruleset_id
		}
	var applied_command_count := 0
	var last_command_row: Dictionary = {}
	for i in range(command_index):
		var row: Dictionary = commands[i]
		var command = GameCommand.create(int(row.get("player_id", -1)), str(row.get("type", "")), row.get("payload", {}))
		command.command_id = str(row.get("command_id", command.command_id))
		command.client_time = int(row.get("client_time", command.client_time))
		command.source = str(row.get("source", command.source))
		var result = engine.apply_command(state, command)
		if not result.ok:
			return {
				"ok": false,
				"code": "REPLAY_COMMAND_FAILED",
				"message": "replay command failed",
				"failed_command": row,
				"result": result,
				"state": state
			}
		var expected_before = str(row.get("state_hash_before", ""))
		var expected_after = str(row.get("state_hash_after", ""))
		if not ignore_hash_verification and not expected_before.is_empty() and expected_before != str(result.get("state_hash_before", "")):
			return {
				"ok": false,
				"code": "REPLAY_HASH_MISMATCH_BEFORE",
				"message": "replay state hash before command does not match",
				"failed_command": row,
				"result": result,
				"state": state
			}
		if not ignore_hash_verification and not expected_after.is_empty() and expected_after != str(result.get("state_hash_after", "")):
			return {
				"ok": false,
				"code": "REPLAY_HASH_MISMATCH_AFTER",
				"message": "replay state hash after command does not match",
				"failed_command": row,
				"result": result,
				"state": state
			}
		applied_command_count += 1
		last_command_row = row
	return {
		"ok": true,
		"state": state,
		"engine": engine,
		"applied_command_count": applied_command_count,
		"last_command_row": last_command_row
	}

func _load_card_definitions(card_data_path: String) -> Array:
	return CardDatabase.load_definitions(card_data_path)
