extends RefCounted
class_name NetworkAutoplayer

const BattleTable = preload("res://client/scripts/battle_table.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")

static var _last_state_signature_by_table: Dictionary = {}

static func drive_local_step(table) -> void:
	if table == null:
		return
	var table_id: int = int(table.get_instance_id())
	if table._state == null or table._game_over:
		_clear_table_state(table_id)
		return
	if table._network_input_locked():
		return
	if not table._pending_network_commands.is_empty():
		return
	_refresh_waiting_state(table)
	if _state_just_changed(table, table_id):
		return
	var player_id: int = table._current_input_player()
	if player_id != BattleTable.PLAYER_BOTTOM:
		return
	var actions: Array = table._player_actions(player_id)
	if actions.is_empty():
		return
	var choice_action: Dictionary = table._find_action(actions, "resolve_choice")
	if not choice_action.is_empty():
		var choice_payload := build_choice_payload(choice_action)
		if not choice_payload.is_empty():
			table._execute_command(player_id, str(choice_action.get("command_type", "")), choice_payload)
		return
	var stack_open: bool = table._state != null and not table._state.stack.is_empty()
	var pending_attack_open: bool = table._state != null and not table._state.pending_attack.is_empty()
	if stack_open or pending_attack_open:
		if try_response_action(table, player_id, actions):
			return
		var pass_action: Dictionary = table._find_action(actions, "pass_priority")
		if not pass_action.is_empty() and _can_pass_priority(table, player_id):
			table._execute_command(player_id, "PassPriority", {})
		return
	if try_main_phase_action(table, player_id, actions):
		return
	if stack_open or pending_attack_open:
		return
	var end_action: Dictionary = table._find_action(actions, "end_phase")
	if not end_action.is_empty() and _can_end_phase(table, player_id):
		table._execute_command(player_id, "EndPhase", {})


static func try_response_action(table, player_id: int, actions: Array) -> bool:
	var stack_open: bool = table._state != null and not table._state.stack.is_empty()
	var pending_attack_open: bool = table._state != null and not table._state.pending_attack.is_empty()
	var defense_action: Dictionary = table._find_action(actions, "choose_defense")
	if pending_attack_open and not stack_open and not defense_action.is_empty():
		if _defense_payload_already_selected(table, defense_action.get("payload_template", {})):
			return false
		return table._execute_command(player_id, "ChooseDefense", defense_action.get("payload_template", {}))
	for action in actions:
		var kind := str(action.get("kind", ""))
		if kind == "play_card":
			var play_kind := str(action.get("play_kind", ""))
			if play_kind != "hand_response" and play_kind != "counter_tactic":
				continue
			if not _can_afford_play_card(table, player_id, action):
				continue
			var target := first_target(action.get("targets", []))
			if target.is_empty():
				if _play_card_requires_target(action):
					continue
				continue
			return table._execute_action_with_target(player_id, action, target)
		if kind == "activate_effect":
			var target := first_target(action.get("targets", []))
			if target.is_empty():
				if _activate_effect_requires_target(table, player_id, action):
					continue
				var payload: Dictionary = action.get("payload_template", {}).duplicate(true)
				return table._execute_command(player_id, str(action.get("command_type", "")), payload)
			return table._execute_action_with_target(player_id, action, target)
	return false


static func try_main_phase_action(table, player_id: int, actions: Array) -> bool:
	for action in actions:
		var kind := str(action.get("kind", ""))
		if kind == "play_card":
			var play_kind := str(action.get("play_kind", ""))
			if play_kind == "hand_response" or play_kind == "counter_tactic":
				continue
			if not _can_afford_play_card(table, player_id, action):
				continue
			var target := preferred_target(action.get("targets", []))
			if target.is_empty():
				if _play_card_requires_target(action):
					continue
				var payload: Dictionary = action.get("payload_template", {}).duplicate(true)
				if payload.is_empty():
					continue
				return table._execute_command(player_id, str(action.get("command_type", "")), payload)
			return table._execute_action_with_target(player_id, action, target)
	for action in actions:
		var kind := str(action.get("kind", ""))
		if kind == "activate_effect":
			var target := preferred_target(action.get("targets", []))
			if target.is_empty():
				if _activate_effect_requires_target(table, player_id, action):
					continue
				var payload: Dictionary = action.get("payload_template", {}).duplicate(true)
				return table._execute_command(player_id, str(action.get("command_type", "")), payload)
			return table._execute_action_with_target(player_id, action, target)
	for action in actions:
		if str(action.get("kind", "")) != "declare_attack":
			continue
		var target := preferred_attack_target(action.get("targets", []))
		if target.is_empty():
			continue
		return table._execute_action_with_target(player_id, action, target)
	return false


static func response_window_active(table) -> bool:
	return table._state != null and (not table._state.pending_attack.is_empty() or not table._state.stack.is_empty())


static func _refresh_waiting_state(table) -> void:
	if table == null or table._state == null or table._engine == null:
		return
	table._waiting_state = table._engine.get_waiting_state(table._state)
	table._invalidate_action_cache()


static func _state_just_changed(table, table_id: int) -> bool:
	var state_signature: int = hash([
		table._waiting_state,
		table._state.phase,
		table._state.active_player,
		table._state.priority_player,
		table._state.priority_pass_count,
		table._state.pending_choices,
		table._state.pending_attack,
		table._state.stack
	])
	var last_signature: int = int(_last_state_signature_by_table.get(table_id, -1))
	_last_state_signature_by_table[table_id] = state_signature
	return last_signature != state_signature


static func _clear_table_state(table_id: int) -> void:
	_last_state_signature_by_table.erase(table_id)


static func _play_card_requires_target(action: Dictionary) -> bool:
	var target_mode := str(action.get("target_mode", ""))
	return target_mode != "" and target_mode != "none" and target_mode != "slot"


static func _defense_payload_already_selected(table, payload: Dictionary) -> bool:
	if table == null or table._state == null:
		return false
	var pending_attack: Dictionary = table._state.pending_attack
	if pending_attack.is_empty():
		return false
	if str(pending_attack.get("blocker_id", "")) != str(payload.get("blocker_id", "")):
		return false
	if str(pending_attack.get("supporter_id", "")) != str(payload.get("supporter_id", "")):
		return false
	return _same_string_arrays(
		_payload_string_array(pending_attack.get("master_guard_card_ids", [])),
		_payload_string_array(payload.get("master_guard_card_ids", []))
	)


static func _can_afford_play_card(table, player_id: int, action: Dictionary) -> bool:
	if table == null or table._state == null or table._engine == null:
		return false
	var payload: Dictionary = action.get("payload_template", {})
	var card_id := str(payload.get("card_id", ""))
	if card_id.is_empty():
		return false
	var logical_player_id: int = table._logical_player_for_display(player_id)
	var play_option_id := str(payload.get("play_option_id", ""))
	var play_option: Dictionary = {}
	if not play_option_id.is_empty():
		var options: Array = table._engine._get_available_play_options(table._state, card_id)
		play_option = table._engine._find_selected_play_option(options, play_option_id)
	var required_morale: int = table._engine._get_effective_play_cost(table._state, card_id, play_option)
	return MoraleActions.count_active_morale(table._state, logical_player_id) >= required_morale


static func _activate_effect_requires_target(table, player_id: int, action: Dictionary) -> bool:
	if table == null or table._state == null or table._engine == null:
		return false
	var payload: Dictionary = action.get("payload_template", {})
	var source_id := str(payload.get("source_id", ""))
	var effect_id := str(payload.get("effect_id", ""))
	if source_id.is_empty() or effect_id.is_empty():
		return false
	var effect: Dictionary = table._engine._find_source_effect_definition(table._state, source_id, effect_id, "activated", player_id)
	if effect.is_empty():
		return false
	var target_mode := str(table._engine._get_effect_target_mode(effect))
	return target_mode != "" and target_mode != "none"


static func _can_pass_priority(table, player_id: int) -> bool:
	if table == null or table._state == null:
		return false
	return int(table._state.priority_player) == table._logical_player_for_display(player_id)


static func _can_end_phase(table, player_id: int) -> bool:
	if table == null or table._state == null:
		return false
	if not table._state.stack.is_empty() or not table._state.pending_attack.is_empty():
		return false
	return int(table._state.active_player) == table._logical_player_for_display(player_id)


static func build_choice_payload(choice_action: Dictionary) -> Dictionary:
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


static func preferred_target(targets: Array) -> Dictionary:
	var fallback: Dictionary = {}
	for target in targets:
		if fallback.is_empty() and target is Dictionary:
			fallback = target
		var row := str(target.get("row", ""))
		var col := int(target.get("col", -1))
		if row == "front" and col == 0:
			return target
	for target in targets:
		if str(target.get("row", "")) == "front":
			return target
	for target in targets:
		if str(target.get("target_kind", "")) == "card":
			return target
	for target in targets:
		if str(target.get("target_kind", "")) == "master":
			return target
	return fallback


static func preferred_attack_target(targets: Array) -> Dictionary:
	for target in targets:
		if str(target.get("target_kind", "")) == "card":
			return target
	for target in targets:
		if str(target.get("target_kind", "")) == "master":
			return target
	return first_target(targets)


static func first_target(targets: Array) -> Dictionary:
	for target in targets:
		if target is Dictionary:
			return target
	return {}


static func _payload_string_array(raw_value) -> Array[String]:
	var result: Array[String] = []
	if raw_value is Array:
		for item in raw_value:
			result.append(str(item))
	return result


static func _same_string_arrays(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if left[index] != right[index]:
			return false
	return true
