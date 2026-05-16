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
	var host_result: Dictionary = table._network_session.host_session(VERIFY_PORT)
	if not bool(host_result.get("ok", false)):
		push_error("network smoke host: failed to host session")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return table._network_session.has_remote_peer()):
		push_error("network smoke host: client did not connect in time")
		quit(1)
		return
	table._on_start_test_pressed()
	if not await _wait_for(func() -> bool: return table._state != null):
		push_error("network smoke host: state should not be null after start")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _play_first_board_card(table)):
		push_error("network smoke host: failed to play first host card")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _advance_to_remote_main(table)):
		push_error("network smoke host: failed to advance to remote main phase")
		quit(1)
		return
	var summary := _state_summary(table)
	print("network smoke host passed %s" % JSON.stringify(summary))
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


func _advance_to_remote_main(table) -> bool:
	if table._state == null:
		return false
	var guard: int = 0
	while guard < 12:
		guard += 1
		if int(table._state.active_player) == 1 and str(table._state.phase) == "main":
			return true
		if table._has_pending_network_command():
			return false
		var end_action: Dictionary = table._find_action(table._player_actions(BattleTable.PLAYER_BOTTOM), "end_phase")
		if end_action.is_empty():
			return false
		if not table._execute_command(BattleTable.PLAYER_BOTTOM, "EndPhase", {}):
			return false
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
