extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")

const VERIFY_PORT := 24573
const TIMEOUT_MS := 90000
const FLOWER_EFFECT_ID := "oiran_search"


func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var host_result: Dictionary = table._network_session.host_session(VERIFY_PORT)
	if not bool(host_result.get("ok", false)):
		push_error("network ui chain host: failed to host session")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return table._network_session.has_remote_peer()
	, table):
		push_error("network ui chain host: client did not connect in time")
		quit(1)
		return
	table._on_start_test_pressed()
	if not await _wait_for(func() -> bool:
		return table._state != null and table._end_turn_button != null and table._end_turn_button.visible
	, table):
		push_error("network ui chain host: duel did not start with visible end-turn button")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return _play_flower_gift(table)
	, table):
		push_error("network ui chain host: failed to play 花魁的馈赠")
		quit(1)
		return
	var saw_stack_window := false
	if not await _wait_for(func() -> bool:
		if table._state != null and not table._state.stack.is_empty():
			saw_stack_window = true
		return saw_stack_window and table._state != null and not table._state.pending_choices.is_empty()
	, table):
		push_error("network ui chain host: stack response or choice did not appear")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return _resolve_first_choice(table)
	, table):
		push_error("network ui chain host: failed to resolve first choice")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return _battle_is_idle(table) and _is_local_main_phase(table)
	, table):
		push_error("network ui chain host: battle did not settle after resolving choice")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return _play_first_board_card(table)
	, table):
		push_error("network ui chain host: failed to play first board card")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return _end_phase_if_available(table)
	, table):
		push_error("network ui chain host: failed to end first host turn")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return _is_local_main_phase(table) and not _first_attack_action(table).is_empty()
	, table, true):
		push_error("network ui chain host: did not return to host main phase with an available attack")
		quit(1)
		return
	var saw_pending_attack := false
	if not await _wait_for(func() -> bool:
		if not _first_attack_action(table).is_empty():
			_declare_first_attack(table)
		if table._state != null and not table._state.pending_attack.is_empty():
			saw_pending_attack = true
		return saw_pending_attack and _battle_is_idle(table)
	, table):
		push_error("network ui chain host: attack/defense chain did not resolve")
		quit(1)
		return
	_force_result(table, 0)
	if not await _wait_for(func() -> bool:
		return table._game_result_overlay != null and table._game_result_overlay.visible
	, table):
		push_error("network ui chain host: result dialog did not appear")
		quit(1)
		return
	table._game_result_confirm_button.emit_signal("pressed")
	if not await _wait_for(func() -> bool:
		return table._state == null and table._start_panel != null and table._start_panel.visible and not table._network_session.is_network_active()
	, table):
		push_error("network ui chain host: return-to-home reset did not finish")
		quit(1)
		return
	table._on_host_duel_pressed()
	if not await _wait_for(func() -> bool:
		return table._network_session.has_remote_peer()
	, table):
		push_error("network ui chain host: client did not reconnect for second duel")
		quit(1)
		return
	table._on_start_test_pressed()
	if not await _wait_for(func() -> bool:
		return table._state != null and table._end_turn_button != null and table._end_turn_button.visible and not table._game_result_overlay.visible
	, table):
		push_error("network ui chain host: second duel did not start cleanly")
		quit(1)
		return
	print("network ui chain host passed %s" % JSON.stringify(_summary(table)))
	quit(0)


func _wait_for(predicate: Callable, table, allow_end_phase: bool = false) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		_drive_local_step(table, allow_end_phase)
		await process_frame
	return false


func _drive_local_step(table, allow_end_phase: bool) -> void:
	if table == null or table._state == null:
		return
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return
	var choice_action: Dictionary = table._find_action(table._player_actions(player_id), "resolve_choice")
	if not choice_action.is_empty():
		return
	var defense_action: Dictionary = table._find_action(table._player_actions(player_id), "choose_defense")
	if not defense_action.is_empty():
		table._execute_command(player_id, "ChooseDefense", defense_action.get("payload_template", {}))
		return
	var pass_action: Dictionary = table._find_action(table._player_actions(player_id), "pass_priority")
	if not pass_action.is_empty() and _response_window_active(table):
		table._execute_command(player_id, "PassPriority", {})
		return
	if allow_end_phase:
		_end_phase_if_available(table)


func _is_local_main_phase(table) -> bool:
	if table == null or table._state == null:
		return false
	return (
		table._current_input_player() == BattleTable.PLAYER_BOTTOM
		and int(table._state.active_player) == table._logical_player_for_display(BattleTable.PLAYER_BOTTOM)
		and str(table._state.phase) == "main"
		and _battle_is_idle(table)
	)


func _play_flower_gift(table) -> bool:
	if not _is_local_main_phase(table):
		return false
	for action in table._player_actions(BattleTable.PLAYER_BOTTOM):
		if str(action.get("kind", "")) != "play_card":
			continue
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("effect_id", "")) != FLOWER_EFFECT_ID:
			continue
		return table._execute_command(BattleTable.PLAYER_BOTTOM, "PlayCard", payload)
	return false


func _resolve_first_choice(table) -> bool:
	if table == null or table._state == null:
		return false
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return false
	var choice_action: Dictionary = table._find_action(table._player_actions(player_id), "resolve_choice")
	if choice_action.is_empty():
		return false
	var payload: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	var choice_type := str(choice_action.get("choice_type", choice_action.get("type", "")))
	if choice_type == "option_pick":
		var options = choice_action.get("options", [])
		if options.is_empty():
			return false
		payload["selected_option"] = str(options[0].get("id", ""))
		return table._execute_command(player_id, str(choice_action.get("command_type", "")), payload)
	var count: int = max(1, int(choice_action.get("count", 1)))
	var selected_ids: Array[String] = []
	for raw_card_id in choice_action.get("candidate_card_ids", []):
		selected_ids.append(str(raw_card_id))
		if selected_ids.size() >= count:
			break
	if selected_ids.is_empty():
		return false
	payload["selected_card_ids"] = selected_ids
	return table._execute_command(player_id, str(choice_action.get("command_type", "")), payload)


func _play_first_board_card(table) -> bool:
	if not _is_local_main_phase(table):
		return false
	for action in table._player_actions(BattleTable.PLAYER_BOTTOM):
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("play_kind", "")) != "board_or_artifact":
			continue
		var target := _preferred_board_target(action.get("targets", []))
		if target.is_empty():
			continue
		return table._execute_action_with_target(BattleTable.PLAYER_BOTTOM, action, target)
	return false


func _end_phase_if_available(table) -> bool:
	if not _is_local_main_phase(table):
		return false
	var action: Dictionary = table._find_action(table._player_actions(BattleTable.PLAYER_BOTTOM), "end_phase")
	if action.is_empty():
		return false
	return table._execute_command(BattleTable.PLAYER_BOTTOM, "EndPhase", {})


func _declare_first_attack(table) -> bool:
	if not _is_local_main_phase(table):
		return false
	var action := _first_attack_action(table)
	if action.is_empty():
		return false
	var targets = action.get("targets", [])
	if targets.is_empty():
		return false
	return table._execute_action_with_target(BattleTable.PLAYER_BOTTOM, action, targets[0])


func _first_attack_action(table) -> Dictionary:
	if table == null or table._state == null:
		return {}
	for action in table._player_actions(BattleTable.PLAYER_BOTTOM):
		if str(action.get("kind", "")) == "declare_attack":
			return action
	return {}


func _preferred_board_target(targets: Array) -> Dictionary:
	var fallback: Dictionary = {}
	for target in targets:
		if fallback.is_empty() and target is Dictionary:
			fallback = target
		if str(target.get("row", "")) == "front" and int(target.get("col", -1)) == 0:
			return target
	for target in targets:
		if str(target.get("row", "")) == "front":
			return target
	return fallback


func _response_window_active(table) -> bool:
	return table != null and table._state != null and (not table._state.stack.is_empty() or not table._state.pending_attack.is_empty())


func _battle_is_idle(table) -> bool:
	return table != null and table._state != null and table._state.stack.is_empty() and table._state.pending_choices.is_empty() and table._state.pending_attack.is_empty() and not table._has_pending_network_command()


func _force_result(table, winner: int) -> void:
	if table == null or table._state == null:
		return
	table._state.winner = winner
	table._state.loss_reason = "network_ui_chain_verify"
	table._sync_from_engine()
	table._refresh()


func _summary(table) -> Dictionary:
	var hash := ""
	if table != null and table._state != null:
		hash = StateHasher.hash_public_and_private_state(table._state)
	return {
		"phase": str(table._state.phase) if table._state != null else "<none>",
		"active_player": int(table._state.active_player) if table._state != null else -1,
		"command_count": table._state.command_log.size() if table._state != null else 0,
		"hash": hash
	}
