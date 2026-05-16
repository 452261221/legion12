extends RefCounted
class_name MatchReplaySession

const CardDatabase = preload("res://rules/core/card_database.gd")
const ReplayRunner = preload("res://client/scripts/replay/replay_runner.gd")

var _runner := ReplayRunner.new()
var _replay_data: Dictionary = {}
var _current_command_index := 0
var _current_state = null
var _current_engine = null
var _last_command_row: Dictionary = {}
var _ignore_hash_verification := true

func load_replay_data(replay_data: Dictionary) -> Dictionary:
	_replay_data = replay_data.duplicate(true)
	return jump_to_command(0)

func jump_to_command(command_index: int) -> Dictionary:
	var result = _runner.run_replay_data_until(_replay_data, command_index, CardDatabase.DEFAULT_CARD_DATA_PATH, _ignore_hash_verification)
	if not bool(result.get("ok", false)):
		return result
	_current_command_index = command_index
	_current_state = result.get("state", null)
	_current_engine = result.get("engine", null)
	_last_command_row = result.get("last_command_row", {})
	return {
		"ok": true,
		"data": {
			"command_index": _current_command_index,
			"state": _current_state,
			"engine": _current_engine,
			"last_command_row": _last_command_row,
			"public_view": get_current_public_view()
		}
	}

func step_forward() -> Dictionary:
	return jump_to_command(min(_current_command_index + 1, get_total_command_count()))

func step_backward() -> Dictionary:
	return jump_to_command(max(_current_command_index - 1, 0))

func jump_to_start() -> Dictionary:
	return jump_to_command(0)

func jump_to_end() -> Dictionary:
	return jump_to_command(get_total_command_count())

func get_total_command_count() -> int:
	var commands = _replay_data.get("commands", [])
	return commands.size() if commands is Array else 0

func get_current_command_index() -> int:
	return _current_command_index

func get_current_state():
	return _current_state

func get_current_engine():
	return _current_engine

func get_current_public_view() -> Dictionary:
	if _current_state == null:
		return {}
	return _current_state.build_public_view_model(-1)

func get_current_command_row() -> Dictionary:
	return _last_command_row.duplicate(true)
