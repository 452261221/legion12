extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")

const VERIFY_PORT := 24570
const TIMEOUT_MS := 30000

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var host_result: Dictionary = table._network_session.host_session(VERIFY_PORT)
	if not bool(host_result.get("ok", false)):
		push_error("network response host: failed to host session")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return table._network_session.has_remote_peer(), table):
		push_error("network response host: client did not connect in time")
		quit(1)
		return
	table._on_start_test_pressed()
	if not await _wait_for(func() -> bool: return table._state != null, table):
		push_error("network response host: state should not be null after start")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _play_first_board_card(table), table):
		push_error("network response host: failed to play first host card")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _wait_until_host_next_main(table), table):
		push_error("network response host: did not return to host main")
		quit(1)
		return
	var attack_ok := false
	if not await _wait_for(func() -> bool:
		if attack_ok:
			return true
		attack_ok = _declare_first_attack(table)
		return attack_ok
	, table):
		push_error("network response host: failed to declare attack")
		quit(1)
		return
	var saw_pending_attack := false
	if not await _wait_for(func() -> bool:
		_drive_local_step(table)
		if table._state != null and not table._state.pending_attack.is_empty():
			saw_pending_attack = true
		return saw_pending_attack and _battle_is_idle(table)
	, table):
		push_error("network response host: pending attack did not resolve in time")
		quit(1)
		return
	for _i in range(30):
		await process_frame
	var summary := _state_summary(table)
	print("network response host passed %s" % JSON.stringify(summary))
	quit(0)


func _wait_for(predicate: Callable, table) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		_drive_local_step(table)
		if bool(predicate.call()):
			return true
		await process_frame
	return false


func _drive_local_step(table) -> void:
	if table._state == null:
		return
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return
	var choice_action: Dictionary = table._find_action(table._player_actions(player_id), "resolve_choice")
	if not choice_action.is_empty():
		var payload := _choice_payload(choice_action)
		if not payload.is_empty():
			table._execute_command(player_id, str(choice_action.get("command_type", "")), payload)
		return
	var defense_action: Dictionary = table._find_action(table._player_actions(player_id), "choose_defense")
	if not defense_action.is_empty():
		table._execute_command(player_id, "ChooseDefense", defense_action.get("payload_template", {}))
		return
	var pass_action: Dictionary = table._find_action(table._player_actions(player_id), "pass_priority")
	if not pass_action.is_empty() and _response_window_active(table):
		table._execute_command(player_id, "PassPriority", {})
		return
	if int(table._state.active_player) == 0 and str(table._state.phase) != "main":
		var end_action: Dictionary = table._find_action(table._player_actions(player_id), "end_phase")
		if not end_action.is_empty():
			table._execute_command(player_id, "EndPhase", {})


func _choice_payload(choice_action: Dictionary) -> Dictionary:
	var payload: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	var choice_type := str(choice_action.get("choice_type", ""))
	if choice_type == "option_pick":
		var options = choice_action.get("options", [])
		if options.is_empty():
			return {}
		payload["selected_option"] = str(options[0].get("id", ""))
		return payload
	var count: int = max(1, int(choice_action.get("count", 1)))
	var selected: Array[String] = []
	for card_id in choice_action.get("candidate_card_ids", []):
		selected.append(str(card_id))
		if selected.size() >= count:
			break
	if selected.is_empty():
		return {}
	payload["selected_card_ids"] = selected
	return payload


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
		var target := _preferred_board_target(action.get("targets", []))
		if target.is_empty():
			continue
		return table._execute_action_with_target(player_id, action, target)
	return false


func _preferred_board_target(targets: Array) -> Dictionary:
	var fallback: Dictionary = {}
	for target in targets:
		var row := str(target.get("row", ""))
		var col := int(target.get("col", -1))
		if fallback.is_empty():
			fallback = target
		if row == "front" and col == 0:
			return target
	for target in targets:
		if str(target.get("row", "")) == "front":
			return target
	return fallback


func _wait_until_host_next_main(table) -> bool:
	return table._state != null and int(table._state.active_player) == 0 and str(table._state.phase) == "main" and not table._player_actions(BattleTable.PLAYER_BOTTOM).is_empty() and not _first_attack_action(table).is_empty()


func _declare_first_attack(table) -> bool:
	if table._state == null:
		return false
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return false
	var action := _first_attack_action(table)
	if action.is_empty():
		return false
	var targets = action.get("targets", [])
	if targets.is_empty():
		return false
	return table._execute_action_with_target(player_id, action, targets[0])


func _first_attack_action(table) -> Dictionary:
	for action in table._player_actions(BattleTable.PLAYER_BOTTOM):
		if str(action.get("kind", "")) == "declare_attack":
			return action
	return {}


func _response_window_active(table) -> bool:
	return table._state != null and (not table._state.pending_attack.is_empty() or not table._state.stack.is_empty())


func _battle_is_idle(table) -> bool:
	return table._state != null and table._state.pending_attack.is_empty() and table._state.stack.is_empty() and table._state.pending_choices.is_empty() and not table._has_pending_network_command()


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
