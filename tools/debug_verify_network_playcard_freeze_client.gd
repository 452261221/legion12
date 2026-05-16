extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")

const VERIFY_PORT := 24572
const TIMEOUT_MS := 30000

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var join_result: Dictionary = table._network_session.join_session("127.0.0.1", VERIFY_PORT)
	if not bool(join_result.get("ok", false)):
		push_error("network playcard freeze client: failed to join session")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return table._state != null):
		push_error("network playcard freeze client: duel did not start in time")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _pass_priority_if_available(table)):
		push_error("network playcard freeze client: pass button never became available after PlayCard")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return table._network_session.is_network_active() and table._state != null and table._state.stack.is_empty() and table._state.pending_choices.is_empty()
	):
		push_error("network playcard freeze client: state did not settle after host resolved choice")
		quit(1)
		return
	print("network playcard freeze client passed %s" % JSON.stringify(_summary(table)))
	quit(0)


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await process_frame
	return false


func _pass_priority_if_available(table) -> bool:
	if table._state == null:
		return false
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return false
	var pass_action: Dictionary = table._find_action(table._player_actions(player_id), "pass_priority")
	if pass_action.is_empty():
		return false
	return table._execute_command(player_id, "PassPriority", {})


func _summary(table) -> Dictionary:
	var hash := ""
	if table._state != null:
		hash = StateHasher.hash_public_and_private_state(table._state)
	return {
		"phase": str(table._state.phase),
		"active_player": int(table._state.active_player),
		"stack": table._state.stack.size(),
		"pending_choices": table._state.pending_choices.size(),
		"command_count": table._state.command_log.size(),
		"hash": hash
	}
