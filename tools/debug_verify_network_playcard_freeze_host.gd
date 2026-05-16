extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")

const VERIFY_PORT := 24572
const TIMEOUT_MS := 30000
const FLOWER_EFFECT_ID := "oiran_search"

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var host_result: Dictionary = table._network_session.host_session(VERIFY_PORT)
	if not bool(host_result.get("ok", false)):
		push_error("network playcard freeze host: failed to host session")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return table._network_session.has_remote_peer()):
		push_error("network playcard freeze host: client did not connect in time")
		quit(1)
		return
	table._on_start_test_pressed()
	if not await _wait_for(func() -> bool: return table._state != null):
		push_error("network playcard freeze host: duel did not start in time")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _play_flower_gift(table)):
		push_error("network playcard freeze host: failed to play 花魁的馈赠")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return not table._state.pending_choices.is_empty()):
		push_error("network playcard freeze host: effect did not advance to choice")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _resolve_first_choice(table)):
		push_error("network playcard freeze host: failed to resolve 花魁的馈赠 choice")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return table._network_session.has_remote_peer() and table._state != null and table._state.stack.is_empty() and table._state.pending_choices.is_empty()
	):
		push_error("network playcard freeze host: state did not settle after resolving choice")
		quit(1)
		return
	print("network playcard freeze host passed %s" % JSON.stringify(_summary(table)))
	quit(0)


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await process_frame
	return false


func _play_flower_gift(table) -> bool:
	if table._state == null:
		return false
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return false
	for action in table._player_actions(player_id):
		if str(action.get("kind", "")) != "play_card":
			continue
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("effect_id", "")) != FLOWER_EFFECT_ID:
			continue
		return table._execute_command(player_id, "PlayCard", payload)
	return false


func _resolve_first_choice(table) -> bool:
	if table._state == null:
		return false
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return false
	var choice_action: Dictionary = table._find_action(table._player_actions(player_id), "resolve_choice")
	if choice_action.is_empty():
		return false
	var payload: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	var count: int = max(1, int(choice_action.get("count", 1)))
	var selected_card_ids: Array[String] = []
	for raw_card_id in choice_action.get("candidate_card_ids", []):
		selected_card_ids.append(str(raw_card_id))
		if selected_card_ids.size() >= count:
			break
	if not selected_card_ids.is_empty():
		payload["selected_card_ids"] = selected_card_ids
	return table._execute_command(player_id, str(choice_action.get("command_type", "")), payload)


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
