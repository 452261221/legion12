extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")

const VERIFY_PORT := 24569
const TIMEOUT_MS := 20000

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var join_result: Dictionary = table._network_session.join_session("127.0.0.1", VERIFY_PORT)
	if not bool(join_result.get("ok", false)):
		push_error("network smoke client: failed to join session")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return table._state != null):
		push_error("network smoke client: state should not be null after host start")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return int(table._state.active_player) == 1 and str(table._state.phase) == "main"):
		push_error("network smoke client: did not reach client main phase")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _play_first_board_card(table)):
		push_error("network smoke client: failed to play first client card")
		quit(1)
		return
	var summary := _state_summary(table)
	print("network smoke client passed %s" % JSON.stringify(summary))
	quit(0)


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await process_frame
	return false


func _play_first_board_card(table) -> bool:
	if table._state == null:
		return false
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return false
	for action in table._player_actions(player_id):
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("play_kind", "")) != "board_or_artifact":
			continue
		var targets = action.get("targets", [])
		if targets.is_empty():
			continue
		var target: Dictionary = targets[0]
		return table._execute_action_with_target(player_id, action, target)
	return false


func _state_summary(table) -> Dictionary:
	var hash := ""
	if table._state != null:
		hash = StateHasher.hash_public_and_private_state(table._state)
	return {
		"phase": str(table._state.phase),
		"active_player": int(table._state.active_player),
		"command_count": table._state.command_log.size(),
		"hash": hash
	}
