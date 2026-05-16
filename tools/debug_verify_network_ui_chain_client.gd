extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")

const VERIFY_PORT := 24573
const TIMEOUT_MS := 90000


func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var join_result: Dictionary = table._network_session.join_session("127.0.0.1", VERIFY_PORT)
	if not bool(join_result.get("ok", false)):
		push_error("network ui chain client: failed to join session")
		quit(1)
		return
	if not await _wait_for(func() -> bool:
		return table._state != null
	, table):
		push_error("network ui chain client: duel did not start in time")
		quit(1)
		return
	var saw_stack_response := false
	var saw_combat_response := false
	var played_first_board_card := false
	var saw_first_reset := false
	var rejoined := false
	var next_join_attempt_ms := 0
	if not await _wait_for(func() -> bool:
		if table._state != null and not table._state.stack.is_empty():
			saw_stack_response = true
		if table._state != null and not table._state.pending_attack.is_empty():
			saw_combat_response = true
		if not played_first_board_card and _is_local_main_phase(table):
			played_first_board_card = _play_first_board_card(table)
		if not saw_first_reset and table._state == null and table._start_panel != null and table._start_panel.visible:
			saw_first_reset = true
		if saw_first_reset and not rejoined and not table._network_session.is_network_active():
			var now_ms := Time.get_ticks_msec()
			if now_ms >= next_join_attempt_ms:
				next_join_attempt_ms = now_ms + 1000
				var retry_result: Dictionary = table._network_session.join_session("127.0.0.1", VERIFY_PORT)
				rejoined = bool(retry_result.get("ok", false))
		return saw_stack_response and played_first_board_card and saw_combat_response and saw_first_reset and rejoined and table._state != null
	, table, true):
		push_error("network ui chain client: did not complete ui chain and second duel restart")
		quit(1)
		return
	if table._game_result_overlay != null and table._game_result_overlay.visible and table._game_result_confirm_button != null:
		table._game_result_confirm_button.emit_signal("pressed")
		await process_frame
		await process_frame
	if table._state == null or table._game_result_overlay.visible:
		push_error("network ui chain client: second duel did not start cleanly")
		quit(1)
		return
	print("network ui chain client passed %s" % JSON.stringify(_summary(table)))
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
	if allow_end_phase:
		_end_phase_if_available(table)


func _choice_payload(choice_action: Dictionary) -> Dictionary:
	var payload: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	var choice_type := str(choice_action.get("choice_type", choice_action.get("type", "")))
	if choice_type == "option_pick":
		var options = choice_action.get("options", [])
		if options.is_empty():
			return {}
		payload["selected_option"] = str(options[0].get("id", ""))
		return payload
	var count: int = max(1, int(choice_action.get("count", 1)))
	var selected: Array[String] = []
	for raw_card_id in choice_action.get("candidate_card_ids", []):
		selected.append(str(raw_card_id))
		if selected.size() >= count:
			break
	if selected.is_empty():
		return {}
	payload["selected_card_ids"] = selected
	return payload


func _is_local_main_phase(table) -> bool:
	if table == null or table._state == null:
		return false
	return (
		table._current_input_player() == BattleTable.PLAYER_BOTTOM
		and int(table._state.active_player) == table._logical_player_for_display(BattleTable.PLAYER_BOTTOM)
		and str(table._state.phase) == "main"
		and _battle_is_idle(table)
	)


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
