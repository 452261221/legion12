extends RefCounted
class_name GameEngine

const CardDefinition = preload("res://rules/core/card_definition.gd")
const DrawActions = preload("res://rules/actions/draw_actions.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const CombatActions = preload("res://rules/actions/combat_actions.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEvent = preload("res://rules/core/game_event.gd")
const GameState = preload("res://rules/core/game_state.gd")
const PhaseMachine = preload("res://rules/core/phase_machine.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")
const StateValidator = preload("res://rules/core/validators.gd")

const DEFAULT_RULES_CONFIG := {
	"mode": "demo",
	"shuffle_player_decks": false,
	"opening_hand_size": 5,
	"opening_active_player_morale": 3,
	"opening_non_active_player_morale": 3,
	"turn_start_draw_count": 1,
	"turn_start_morale_count": 2,
	"restore_battlefield_power_on_turn_end": false,
}

const FORMAL_RULES_CONFIG := {
	"mode": "formal",
	"shuffle_player_decks": true,
	"opening_hand_size": 6,
	"opening_active_player_morale": 1,
	"opening_non_active_player_morale": 0,
	"turn_start_draw_count": 1,
	"turn_start_morale_count": 2,
	"restore_battlefield_power_on_turn_end": true,
	"legion_entry_adds_calamity": true,
	"manual_legion_move_enabled": true,
	"counter_tactics_require_set": true,
}

func create_game(card_definition_dicts: Array, deck_lists: Array, p_seed: int = 1, player_metadata: Array = [], options: Dictionary = {}) -> GameState:
	var trace_path := str(options.get("debug_trace_path", ""))
	var trace_started_at := Time.get_ticks_msec()
	_append_create_game_trace(trace_path, "create_game:start seed=%s defs=%s decks=%s" % [str(p_seed), str(card_definition_dicts.size()), str(deck_lists.size())])
	var state = GameState.new(p_seed)
	var resolved_deck_lists := _resolve_initial_deck_lists(deck_lists, options)
	state.initial_decks = resolved_deck_lists.duplicate(true)
	state.rules_config = _build_rules_config(options)
	_register_builtin_definitions(state)
	_append_create_game_trace(trace_path, "create_game:builtin_definitions_registered")
	for row in card_definition_dicts:
		if row is CardDefinition:
			state.register_definition(row)
		elif row is Dictionary:
			state.register_definition(CardDefinition.from_dict(row))
	_append_create_game_trace(trace_path, "create_game:card_definitions_registered total=%s" % [str(state.card_definitions.size())])
	for player_id in range(2):
		var metadata: Dictionary = {}
		if player_id < player_metadata.size() and player_metadata[player_id] is Dictionary:
			metadata = player_metadata[player_id]
		var player_name = str(metadata.get("name", "Player %s" % [player_id + 1]))
		state.add_player(player_id, player_name, metadata)
	_append_create_game_trace(trace_path, "create_game:players_added")
	for player_id in range(2):
		var player_deck_list: Array = resolved_deck_lists[player_id] if player_id < resolved_deck_lists.size() else []
		_append_create_game_trace(trace_path, "create_game:build_deck:p%s size=%s" % [str(player_id), str(player_deck_list.size())])
		_build_deck(state, player_id, player_deck_list)
		_build_cost_deck(state, player_id, 8)
	_append_create_game_trace(trace_path, "create_game:cost_decks_built")
	_build_calamity_deck(state, options)
	_append_create_game_trace(trace_path, "create_game:calamity_built")
	_shuffle_player_decks_if_needed(state)
	_append_create_game_trace(trace_path, "create_game:decks_shuffled")
	_start_game(state, options)
	_append_create_game_trace(trace_path, "create_game:game_started hand0=%s hand1=%s morale0=%s morale1=%s" % [
		str(state.get_player(0).hand.cards.size()),
		str(state.get_player(1).hand.cards.size()),
		str(state.get_player(0).cost_area.cards.size()),
		str(state.get_player(1).cost_area.cards.size())
	])
	_refresh_continuous_modifiers(state)
	_append_create_game_trace(trace_path, "create_game:continuous_modifiers=%s elapsed_ms=%s" % [str(state.continuous_modifiers.size()), str(Time.get_ticks_msec() - trace_started_at)])
	return state


func _append_create_game_trace(trace_path: String, line: String) -> void:
	if trace_path.is_empty():
		return
	var file := FileAccess.open(trace_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("[ENGINE] %s" % line)
	file.close()

func validate_command(state: GameState, command: GameCommand) -> Dictionary:
	if state.winner != -1:
		return _error("GAME_ALREADY_FINISHED", "瀵瑰眬宸茬粡缁撴潫")
	if command.type == "DebugCommand":
		return _validate_debug_command(state, command)
	if command.type == "ResolveChoice":
		return _validate_resolve_choice(state, command)
	if not state.pending_choices.is_empty():
		if not _can_interrupt_pending_choice_for_command(state, command):
			return _error("CHOICE_PENDING", "must resolve pending choice before other commands")
	if command.type == "PassPriority":
		return _validate_pass_priority(state, command)
	if command.type == "ActivateEffect":
		return _validate_activate_effect(state, command)
	var response_play = command.type == "PlayCard" and _can_play_response_card_on_stack(state, command)
	var defense_choice = command.type == "ChooseDefense"
	if not state.pending_attack.is_empty() and not response_play and not defense_choice:
		return _error("ATTACK_RESPONSE_PENDING", "must resolve pending attack response window first")
	if not state.stack.is_empty() and not response_play:
		return _error("STACK_NOT_EMPTY", "must resolve stack before other commands")
	if response_play:
		if command.player_id != state.priority_player:
			return _error("NOT_PRIORITY_PLAYER", "it is not this player's priority")
	elif defense_choice:
		if command.player_id != state.priority_player:
			return _error("NOT_PRIORITY_PLAYER", "it is not this player's priority")
	elif command.player_id != state.active_player:
		return _error("NOT_ACTIVE_PLAYER", "褰撳墠涓嶆槸璇ョ帺瀹剁殑鎿嶄綔鏃舵満")
	if not PhaseMachine.can_use_command(command.type, state.phase):
		return _error("COMMAND_NOT_ALLOWED_IN_PHASE", "command not allowed in current phase")
	match command.type:
		"PlayCard":
			return _validate_play_card(state, command)
		"DeclareAttack":
			return _validate_attack(state, command)
		"ChooseDefense":
			return _validate_choose_defense(state, command)
		"MoveLegion":
			return _validate_move_legion(state, command)
		"ActivateEffect":
			return _validate_activate_effect(state, command)
		"ResolveChoice":
			return _validate_resolve_choice(state, command)
		"PassPriority":
			return _validate_pass_priority(state, command)
		"EndPhase":
			return {"ok": true}
		_:
			return _error("UNKNOWN_COMMAND", "鏈煡鍛戒护绫诲瀷")

func apply_command(state: GameState, command: GameCommand) -> Dictionary:
	var validation = validate_command(state, command)
	if not validation.ok:
		return validation
	var phase_before = state.phase
	var turn_before = state.turn_number
	var state_hash_before = StateHasher.hash_public_and_private_state(state)
	var command_index = state.command_log.size() + 1
	var events: Array = []
	var deferred_choice_stack_sources := _stack_pending_choice_source_ids_for_command(state, command)
	if command.type != "ResolveChoice":
		_clear_interruptible_pending_choice_for_player(state, command.player_id)
	match command.type:
		"PlayCard":
			events = _apply_play_card(state, command)
		"DeclareAttack":
			events = _apply_attack(state, command)
		"ChooseDefense":
			events = _apply_choose_defense(state, command)
		"MoveLegion":
			events = _apply_move_legion(state, command)
		"ActivateEffect":
			events = _apply_activate_effect(state, command)
		"ResolveChoice":
			events = _apply_resolve_choice(state, command)
		"PassPriority":
			events = _apply_pass_priority(state, command)
		"EndPhase":
			events = _advance_phase(state, command)
		"DebugCommand":
			events = _apply_debug_command(state, command)
	if command.type == "ResolveChoice":
		for source_id in deferred_choice_stack_sources:
			events.append_array(_cleanup_deferred_stack_pending_source_if_needed(state, source_id, command.command_id))
	events.append_array(drain_until_waiting_for_input(state, events, command.command_id))
	_refresh_continuous_modifiers(state)
	var errors = StateValidator.validate(state)
	var state_hash_after = StateHasher.hash_public_and_private_state(state)
	var result = {
		"ok": errors.is_empty(),
		"events": events,
		"errors": errors,
		"state_hash_before": state_hash_before,
		"state_hash_after": state_hash_after
	}
	state.command_log.append({
		"index": command_index,
		"command_id": command.command_id,
		"player_id": command.player_id,
		"type": command.type,
		"phase_before": phase_before,
		"phase_after": state.phase,
		"turn_before": turn_before,
		"turn_after": state.turn_number,
		"payload": command.payload.duplicate(true),
		"client_time": command.client_time,
		"source": command.source,
		"state_hash_before": state_hash_before,
		"state_hash_after": state_hash_after,
		"ok": result.ok,
		"errors": errors
	})
	if not errors.is_empty():
		result.code = "STATE_INVALID"
		result.message = "; ".join(errors)
	return result

func _stack_pending_choice_source_ids_for_command(state: GameState, command: GameCommand) -> Array[String]:
	var result: Array[String] = []
	if command.type != "ResolveChoice":
		return result
	var choice_id := str(command.payload.get("choice_id", ""))
	if choice_id.is_empty():
		return result
	for raw_choice in state.pending_choices:
		if not (raw_choice is Dictionary):
			continue
		if str(raw_choice.get("choice_id", "")) != choice_id:
			continue
		for source_id in _pending_choice_source_ids(raw_choice):
			if source_id.is_empty() or result.has(source_id):
				continue
			var instance = state.card_instances.get(source_id)
			if instance != null and str(instance.zone) == "stack_pending":
				result.append(source_id)
		break
	return result

func _validate_debug_command(state: GameState, command: GameCommand) -> Dictionary:
	var action = str(command.payload.get("action", ""))
	match action:
		"draw_cards":
			var player_id = int(command.payload.get("player_id", state.active_player))
			var count = int(command.payload.get("count", 1))
			if player_id < 0 or player_id >= state.players.size():
				return _error("INVALID_PLAYER", "invalid debug player")
			if count <= 0:
				return _error("INVALID_COUNT", "debug draw count must be positive")
			return {"ok": true}
		"add_morale":
			var morale_player_id = int(command.payload.get("player_id", state.active_player))
			var morale_count = int(command.payload.get("count", 1))
			if morale_player_id < 0 or morale_player_id >= state.players.size():
				return _error("INVALID_PLAYER", "invalid debug player")
			if morale_count <= 0:
				return _error("INVALID_COUNT", "debug morale count must be positive")
			return {"ok": true}
		"add_rune":
			var rune_player_id = int(command.payload.get("player_id", state.active_player))
			var rune_count = int(command.payload.get("count", 1))
			if rune_player_id < 0 or rune_player_id >= state.players.size():
				return _error("INVALID_PLAYER", "invalid debug player")
			if rune_count <= 0:
				return _error("INVALID_COUNT", "debug rune count must be positive")
			return {"ok": true}
		"set_master_hp":
			var hp_player_id = int(command.payload.get("player_id", state.active_player))
			var hp = int(command.payload.get("hp", 20))
			if hp_player_id < 0 or hp_player_id >= state.players.size():
				return _error("INVALID_PLAYER", "invalid debug player")
			if hp < 0:
				return _error("INVALID_HP", "debug hp cannot be negative")
			return {"ok": true}
		"set_calamity_value":
			var calamity_value = int(command.payload.get("value", state.calamity_value))
			if calamity_value < 0:
				return _error("INVALID_CALAMITY_VALUE", "calamity value cannot be negative")
			return {"ok": true}
		"reveal_calamity":
			var definition_id = str(command.payload.get("definition_id", ""))
			if not definition_id.is_empty() and not state.card_definitions.has(definition_id):
				return _error("UNKNOWN_CALAMITY", "unknown calamity definition")
			return {"ok": true}
		_:
			return _error("UNKNOWN_DEBUG_ACTION", "unknown debug action")

func _validate_pass_priority(state: GameState, command: GameCommand) -> Dictionary:
	if not state.pending_choices.is_empty():
		return _error("CHOICE_PENDING", "must resolve pending choice before passing priority")
	if state.stack.is_empty() and state.pending_attack.is_empty():
		return _error("NO_PRIORITY_WINDOW", "no stack item waiting for priority")
	if command.player_id != state.priority_player:
		return _error("NOT_PRIORITY_PLAYER", "it is not this player's priority")
	return {"ok": true}

func _validate_resolve_choice(state: GameState, command: GameCommand) -> Dictionary:
	if state.pending_choices.is_empty():
		return _error("NO_PENDING_CHOICE", "there is no pending choice to resolve")
	var choice_id = str(command.payload.get("choice_id", ""))
	var choice = _find_pending_choice(state, choice_id)
	if choice.is_empty():
		return _error("UNKNOWN_CHOICE", "pending choice does not exist")
	var owner = int(choice.get("player_id", -1))
	if owner != command.player_id:
		return _error("NOT_CHOICE_PLAYER", "choice belongs to a different player")
	var cancelled = bool(command.payload.get("cancelled", false))
	if cancelled:
		return _validate_cancel_choice(choice)
	var selected_card_ids = command.payload.get("selected_card_ids", [])
	match str(choice.get("type", "")):
		"search_deck_pick":
			if not (selected_card_ids is Array):
				return _error("INVALID_CHOICE", "selected_card_ids must be an array")
			return _validate_search_choice_selection(choice, selected_card_ids)
		"candidate_cards_pick":
			if not (selected_card_ids is Array):
				return _error("INVALID_CHOICE", "selected_card_ids must be an array")
			var selection_validation = _validate_candidate_card_selection(choice, selected_card_ids)
			if not selection_validation.ok:
				return selection_validation
			return _validate_candidate_choice_payload(state, choice, command.payload)
		"option_pick":
			return _validate_option_choice_selection(choice, str(command.payload.get("selected_option", "")))
	return _error("UNKNOWN_CHOICE_TYPE", "unsupported pending choice type")

func _validate_cancel_choice(choice: Dictionary) -> Dictionary:
	var operation := str(choice.get("operation", ""))
	if operation == "search_deck" or operation == "search_deck_reorder_bottom" or operation == "olympus_achilles_lethal_replace" or operation == "olympus_helen_lethal_replace" or operation == "forged_order_choose_enemy_move_card" or operation == "landlord_coercion_extra_discard":
		return {"ok": true}
	return _error("INVALID_CHOICE", "this choice cannot be cancelled")

func _is_interruptible_pending_choice(choice: Dictionary) -> bool:
	return str(choice.get("operation", "")) == "forged_order_choose_enemy_move_card"

func _interruptible_pending_choice_for_player(state: GameState, player_id: int) -> Dictionary:
	if state.pending_choices.is_empty():
		return {}
	var choice = state.pending_choices[0]
	if int(choice.get("player_id", -1)) != player_id:
		return {}
	if not _is_interruptible_pending_choice(choice):
		return {}
	return choice

func _can_interrupt_pending_choice_for_command(state: GameState, command: GameCommand) -> bool:
	if command.type == "ResolveChoice":
		return false
	return not _interruptible_pending_choice_for_player(state, command.player_id).is_empty()

func _clear_interruptible_pending_choice_for_player(state: GameState, player_id: int) -> void:
	if state.pending_choices.is_empty():
		return
	var choice = _interruptible_pending_choice_for_player(state, player_id)
	if choice.is_empty():
		return
	state.pending_choices.remove_at(0)

func _validate_activate_effect(state: GameState, command: GameCommand) -> Dictionary:
	if command.player_id != state.priority_player:
		return _error("NOT_PRIORITY_PLAYER", "it is not this player's priority")
	if not PhaseMachine.can_use_command("ActivateEffect", state.phase):
		return _error("COMMAND_NOT_ALLOWED_IN_PHASE", "effect activation is only supported in main phase")
	var source_id = str(command.payload.get("source_id", ""))
	var effect_id = str(command.payload.get("effect_id", ""))
	if source_id.is_empty() or effect_id.is_empty():
		return _error("INVALID_EFFECT_REQUEST", "source_id and effect_id are required")
	var effect = _find_source_effect_definition(state, source_id, effect_id, "activated", command.player_id)
	if effect.is_empty():
		return _error("UNKNOWN_EFFECT", "activated effect was not found on source")
	if not _validate_effect_source(state, command.player_id, source_id, effect):
		return _error("INVALID_ZONE", "activated effects currently require a battlefield, artifact or master source")
	var response_window_open = not state.stack.is_empty() or not state.pending_attack.is_empty()
	if response_window_open:
		if not _effect_can_activate_in_response_window(state, source_id, effect):
			return _error("STACK_NOT_EMPTY", "effect cannot be activated while stack is not empty")
	else:
		if command.player_id != state.active_player:
			return _error("NOT_ACTIVE_PLAYER", "only active player can activate effects now")
	var availability_check = _validate_effect_availability(state, command.player_id, source_id, effect)
	if not availability_check.get("ok", false):
		return availability_check
	var cost_check = _validate_effect_cost(state, command.player_id, effect, {"source_id": source_id})
	if not cost_check.get("ok", false):
		return cost_check
	var target_check = _validate_effect_targets(state, command, effect)
	if not target_check.get("ok", false):
		return target_check
	return {"ok": true}

func _master_source_id(player_id: int) -> String:
	return "master_%s" % player_id

func _is_master_source_id(source_id: String) -> bool:
	return source_id.begins_with("master_") and source_id.trim_prefix("master_").is_valid_int()

func _master_player_from_source_id(source_id: String) -> int:
	if not _is_master_source_id(source_id):
		return -1
	return int(source_id.trim_prefix("master_"))

func _morale_source_id(player_id: int) -> String:
	return "morale_%s" % player_id

func _is_morale_source_id(source_id: String) -> bool:
	return source_id.begins_with("morale_") and source_id.trim_prefix("morale_").is_valid_int()

func _morale_player_from_source_id(source_id: String) -> int:
	if not _is_morale_source_id(source_id):
		return -1
	return int(source_id.trim_prefix("morale_"))

func _validate_effect_source(state: GameState, player_id: int, source_id: String, effect: Dictionary = {}) -> bool:
	if _is_master_source_id(source_id):
		return _master_player_from_source_id(source_id) == player_id
	if _is_morale_source_id(source_id):
		return _morale_player_from_source_id(source_id) == player_id
	if not state.card_instances.has(source_id):
		return false
	var instance = state.card_instances[source_id]
	if instance.controller != player_id and not bool(effect.get("any_player_can_activate", false)):
		return false
	if instance.zone.begins_with("battle_") or instance.zone == "artifact_zone" or instance.zone == "trial_zone" or instance.zone == "city_zone":
		return true
	if instance.zone == "hand" and bool(effect.get("allow_hand_source", false)):
		return true
	return instance.zone == "grave" and bool(effect.get("allow_grave_source", false))


func _effect_required_zone_matches(state: GameState, source_id: String, required_zone_value) -> bool:
	if required_zone_value == null:
		return true
	if _is_master_source_id(source_id):
		return str(required_zone_value).is_empty() or str(required_zone_value) == "master"
	if _is_morale_source_id(source_id):
		return str(required_zone_value).is_empty() or str(required_zone_value) == "morale"
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return false
	var source_zone := str(instance.zone)
	if required_zone_value is Array:
		for raw_zone in required_zone_value:
			if _effect_required_zone_matches(state, source_id, raw_zone):
				return true
		return false
	var required_zone := str(required_zone_value)
	if required_zone.is_empty():
		return true
	if required_zone == "battlefield":
		return source_zone.begins_with("battle_")
	return source_zone == required_zone


func _effect_event_source_options(source_id: String) -> Dictionary:
	var options: Dictionary = {
		"source_kind": "effect"
	}
	if source_id.is_empty():
		return options
	options["source_id"] = source_id
	if not _is_master_source_id(source_id) and not _is_morale_source_id(source_id):
		options["source_card_id"] = source_id
	return options


func _artifact_locking_card_ids_for_target(state: GameState, host_player_id: int, target_artifact_id: String) -> Array[String]:
	var result: Array[String] = []
	if host_player_id < 0 or host_player_id >= state.players.size() or target_artifact_id.is_empty():
		return result
	for raw_card_id in state.get_player(host_player_id).artifact_zone.cards:
		var card_id := str(raw_card_id)
		if card_id == target_artifact_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		if str(instance.flags.get("artifact_lock_target_id", "")) != target_artifact_id:
			continue
		result.append(card_id)
	return result


func _artifact_is_locked_by_enemy_tactic(state: GameState, player_id: int, artifact_id: String) -> bool:
	return not _artifact_locking_card_ids_for_target(state, player_id, artifact_id).is_empty()


func _discard_attached_artifact_locking_cards(state: GameState, host_player_id: int, target_artifact_id: String, command_id: String) -> Array:
	var events: Array = []
	for locking_card_id in _artifact_locking_card_ids_for_target(state, host_player_id, target_artifact_id):
		var locking_instance = state.card_instances.get(locking_card_id)
		if locking_instance != null:
			locking_instance.flags.erase("artifact_lock_target_id")
			locking_instance.position = {}
		events.append_array(_discard_artifact_zone_card_to_owner_grave(state, locking_card_id, command_id))
	return events


func _artifact_zone_leave_cleanup_events(state: GameState, card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var definition = state.get_definition(instance.definition_id)
	if definition == null or not definition.is_artifact():
		return []
	var host_player_id := int(instance.controller)
	return _discard_attached_artifact_locking_cards(state, host_player_id, card_id, command_id)


func _is_effect_ready_transition_event(source_event) -> bool:
	if source_event == null:
		return false
	var event_type := str(source_event.type)
	if event_type != "CardReadied" and event_type != "MoraleReadied":
		return false
	var payload = source_event.payload
	if not (payload is Dictionary):
		return false
	return str(payload.get("source_kind", "")) == "effect" and str(payload.get("from_orientation", "")) == "rested"


func _is_non_hand_legion_entry_event(state: GameState, source_event) -> bool:
	if source_event == null or state == null:
		return false
	if str(source_event.type) != "CardEnteredBattlefield":
		return false
	var payload = source_event.payload
	if not (payload is Dictionary):
		return false
	if str(payload.get("from", "")) == "hand":
		return false
	var card_id := str(payload.get("card_id", ""))
	if card_id.is_empty():
		return false
	var instance = state.card_instances.get(card_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	return definition != null and definition.is_legion()


func _enemy_artifact_candidate_ids(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	var enemy_player_id := 1 - player_id
	if enemy_player_id < 0 or enemy_player_id >= state.players.size():
		return result
	for raw_card_id in state.get_player(enemy_player_id).artifact_zone.cards:
		var card_id := str(raw_card_id)
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null or not definition.is_artifact():
			continue
		result.append(card_id)
	return result


func _is_free_master_morale_effect_activation(state: GameState, player_id: int, source_id: String, effect: Dictionary) -> bool:
	if not _is_master_source_id(source_id) or _master_player_from_source_id(source_id) != player_id:
		return false
	if int(state.get_player(player_id).flags.get("free_master_morale_effect_activation_turn", -1)) != state.turn_number:
		return false
	if int(state.get_player(player_id).flags.get("free_master_morale_effect_activation_count", 0)) <= 0:
		return false
	var cost = effect.get("cost", {})
	return cost is Dictionary and int(cost.get("morale", 0)) > 0


func _has_available_free_master_morale_effect_target(state: GameState, player_id: int) -> bool:
	var player = state.get_player(player_id)
	var previous_turn_flag = int(player.flags.get("free_master_morale_effect_activation_turn", -1))
	var previous_count_flag = int(player.flags.get("free_master_morale_effect_activation_count", 0))
	player.flags["free_master_morale_effect_activation_turn"] = state.turn_number
	player.flags["free_master_morale_effect_activation_count"] = max(previous_count_flag, 1)
	for effect in _build_master_effects(state, player_id):
		if str(effect.get("kind", "")) != "activated":
			continue
		var cost = effect.get("cost", {})
		if not (cost is Dictionary) or int(cost.get("morale", 0)) <= 0:
			continue
		var simulated_effect: Dictionary = effect.duplicate(true)
		simulated_effect.erase("once_per_turn_key")
		simulated_effect.erase("player_once_per_turn")
		if _validate_effect_availability(state, player_id, _master_source_id(player_id), simulated_effect).get("ok", false):
			player.flags["free_master_morale_effect_activation_turn"] = previous_turn_flag
			player.flags["free_master_morale_effect_activation_count"] = previous_count_flag
			return true
	player.flags["free_master_morale_effect_activation_turn"] = previous_turn_flag
	player.flags["free_master_morale_effect_activation_count"] = previous_count_flag
	return false


func _current_response_source_event_id(state: GameState) -> int:
	if state.stack.is_empty():
		return 0
	return int(state.stack.back().get("created_from_event_id", 0))


func _source_card_can_change_orientation(instance) -> bool:
	if instance == null:
		return false
	var zone = str(instance.zone)
	return zone.begins_with("battle_") or zone == "artifact_zone" or zone == "trial_zone" or zone == "city_zone"


func _instance_counts_as_legion(state: GameState, instance) -> bool:
	if instance == null:
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition != null and definition.is_legion():
		return true
	if not str(instance.zone).begins_with("battle_"):
		return false
	if int(instance.flags.get("manifested_power", 0)) > 0:
		return true
	var manifested_traits = instance.flags.get("manifested_traits", [])
	return manifested_traits is Array and manifested_traits.has("legion")


func _card_counts_as_legion(state: GameState, card_id: String) -> bool:
	return _instance_counts_as_legion(state, state.card_instances.get(card_id))

func _find_source_effect_definition(state: GameState, source_id: String, effect_id: String, effect_kind: String, player_id: int = -1) -> Dictionary:
	if _is_master_source_id(source_id):
		var master_player_id = _master_player_from_source_id(source_id)
		if player_id != -1 and master_player_id != player_id:
			return {}
		return _find_master_effect_definition(state, master_player_id, effect_id, effect_kind)
	if _is_morale_source_id(source_id):
		var morale_player_id = _morale_player_from_source_id(source_id)
		if player_id != -1 and morale_player_id != player_id:
			return {}
		return _find_morale_effect_definition(state, morale_player_id, effect_id, effect_kind)
	return _find_effect_definition(state, source_id, effect_id, effect_kind)

func _find_source_effect_definition_by_id(state: GameState, source_id: String, effect_id: String, player_id: int = -1) -> Dictionary:
	if _is_master_source_id(source_id):
		var master_player_id = _master_player_from_source_id(source_id)
		if player_id != -1 and master_player_id != player_id:
			return {}
		return _find_master_effect_definition_by_id(state, master_player_id, effect_id)
	if _is_morale_source_id(source_id):
		var morale_player_id = _morale_player_from_source_id(source_id)
		if player_id != -1 and morale_player_id != player_id:
			return {}
		return _find_morale_effect_definition_by_id(state, morale_player_id, effect_id)
	return _find_effect_definition_by_id(state, source_id, effect_id)

func _find_master_effect_definition(state: GameState, player_id: int, effect_id: String, effect_kind: String) -> Dictionary:
	for effect in _build_master_effects(state, player_id):
		if str(effect.get("id", "")) != effect_id:
			continue
		if str(effect.get("kind", "")) != effect_kind:
			continue
		return effect.duplicate(true)
	return {}

func _find_master_effect_definition_by_id(state: GameState, player_id: int, effect_id: String) -> Dictionary:
	for effect in _build_master_effects(state, player_id):
		if str(effect.get("id", "")) == effect_id:
			return effect.duplicate(true)
	return {}

func _find_morale_effect_definition(state: GameState, player_id: int, effect_id: String, effect_kind: String) -> Dictionary:
	for effect in _build_morale_effects(state, player_id):
		if str(effect.get("id", "")) != effect_id:
			continue
		if str(effect.get("kind", "")) != effect_kind:
			continue
		return effect.duplicate(true)
	return {}

func _find_morale_effect_definition_by_id(state: GameState, player_id: int, effect_id: String) -> Dictionary:
	for effect in _build_morale_effects(state, player_id):
		if str(effect.get("id", "")) == effect_id:
			return effect.duplicate(true)
	return {}

func _build_master_effects(state: GameState, player_id: int) -> Array[Dictionary]:
	if player_id < 0 or player_id >= state.players.size():
		return []
	var player = state.get_player(player_id)
	match player.master_definition_id:
		"takamagahara_s01_04m1":
			return [
				{
					"id": "amaterasu_weaken_then_destroy_zero",
					"kind": "activated",
					"text": "天照大神: 选择对方1张军团，本回合费用-1。随后击杀对方1张费用为0的军团。",
					"target_mode": "card",
					"cost": {"morale": 1},
					"once_per_turn_key": "amaterasu_weaken_then_destroy_zero",
					"resolution": {
						"action": "choose_and_modify_cost_until_turn_end",
						"use_selected_target": true,
						"amount": -1,
						"target_scope": "enemy_battlefield",
						"type": "legion",
						"follow_up_action": {
							"action": "choose_and_destroy_unit",
							"target_scope": "enemy_battlefield",
							"type": "legion",
							"max_target_cost": 0
						}
					}
				},
				{
					"id": "amaterasu_ready_morale_and_buff",
					"kind": "activated",
					"text": "天照大神: 弃置1张手牌，将我方最多2张士气转为活跃，我方前排所有高天原军团本回合兵力+1000。",
					"target_mode": "none",
					"once_per_turn_key": "amaterasu_ready_morale_and_buff",
					"resolution": {
						"action": "choose_discard_from_hand_then_follow_up",
						"discard_count": 1,
						"title": "天照大神：选择1张手牌弃置",
						"hint_text": "请先从高亮手牌中选择1张弃置，再点击确认。",
						"top_hint_text": "天照大神：选择1张手牌弃置，然后将我方最多2张士气转为活跃。",
						"follow_up_action": {
							"action": "ready_spent_morale",
							"count": 2,
							"follow_up_action": {
								"action": "modify_matching_power_until_turn_end",
								"target_scope": "allied_battlefield",
								"faction": "takamagahara",
								"type": "legion",
								"required_row": "front",
								"amount": 1000
							}
						}
					}
				}
			]
		"takamagahara_s02_04m1":
			return []
		"asgard_s01_03m1":
			return [
				{
					"id": "valkyrie_grave_split",
					"kind": "activated",
					"text": "瓦尔基里: 消耗1士气并对我方主宰造成1点伤害，选择墓地2张牌，其中1张回牌库底，另1张加入手牌。",
					"target_mode": "none",
					"cost": {"morale": 1},
					"once_per_turn_key": "valkyrie_grave_split",
					"min_own_grave_cards": 2,
					"resolution": {
						"action": "deal_master_damage",
						"player_scope": "controller",
						"amount": 1,
						"source_kind": "effect",
						"follow_up_action": {
							"action": "split_grave_two_cards_to_deck_bottom_and_hand"
						}
					}
				}
			]
		"asgard_s02_03m1":
			return [
				{
					"id": "thor_charge_all_played_legions",
					"kind": "activated",
					"text": "雷神索尔: 当我方主宰血量不高于3时，消耗2士气，本回合我方所有阿斯加德军团登场时获得冲锋，且本局无法回复主宰血量。",
					"target_mode": "none",
					"cost": {"morale": 2},
					"own_master_hp_at_most": 3,
					"resolution": {
						"action": "grant_played_legion_keyword_until_turn_end",
						"keyword": "charge",
						"faction": "asgard",
						"follow_up_action": {
							"action": "block_master_healing_for_game"
						}
					}
				},
				{
					"id": "thor_hammer_grave_revive",
					"kind": "activated",
					"text": "雷神之锤：将墓地另外3张牌按顺序返回牌库底部，然后将1张雷神之锤活跃登场。",
					"target_mode": "none",
					"resolution": {
						"action": "recycle_grave_then_revive_thor_hammer_from_grave",
						"count": 3,
						"title": "选择墓地3张牌返回牌库底部，然后将雷神之锤活跃登场",
						"hint_text": "请选择墓地另外3张牌，确认后会按你选择的顺序回到底，然后将雷神之锤活跃登场。",
						"top_hint_text": "雷神索尔效果：请选择墓地另外3张牌回到底，再让雷神之锤活跃登场。"
					}
				}
			]
		"asgard_s01_03m1", "asgard_s01_03m2a", "asgard_s02_03m1":
			return [
				{
					"id": "loki_draw_discard",
					"kind": "activated",
					"text": "洛基: 抽1张牌，然后弃1张手牌",
					"target_mode": "none",
					"cost": {"morale": 1},
					"once_per_turn_key": "loki_scheme",
					"resolution": {"action": "master_draw_then_discard", "draw_count": 1, "discard_count": 1}
				},
				{
					"id": "loki_recycle_heal",
					"kind": "activated",
					"text": "洛基: 选墓地2张牌回牌库底，并回复1点血量",
					"target_mode": "none",
					"cost": {"morale": 1},
					"once_per_turn_key": "loki_scheme",
					"resolution": {"action": "recycle_grave_to_deck", "count": 2, "heal_master": 1}
				}
			]
		"tianting_s01_01m1":
			return [
				{
					"id": "yangjian_draw_then_put_back",
					"kind": "activated",
					"text": "杨戬: 消耗1士气，抽1，然后将1张手牌放回牌库顶或牌库底",
					"target_mode": "none",
					"cost": {"morale": 1},
					"once_per_turn_key": "yangjian_draw_then_put_back",
					"resolution": {"action": "yangjian_draw_then_put_back"}
				},
				{
					"id": "yangjian_refund_nonlethal_damage",
					"kind": "activated",
					"text": "杨戬: 返还4士气，对对方主宰造成1点非致命伤害",
					"target_mode": "none",
					"cost": {"refund_morale": 4},
					"once_per_turn_key": "yangjian_refund_nonlethal_damage",
					"resolution": {"action": "deal_master_damage", "player_scope": "opponent", "amount": 1, "non_lethal": true}
				}
			]
		"tianting_s01_01m2":
			return [
				{
					"id": "mengpo_disable_died_effects_then_draw",
					"kind": "activated",
					"text": "孟婆: 返还1士气，选择对方1张军团，本回合失去「阵亡时」效果。若我方手牌≤5，抽1。",
					"target_mode": "card",
					"cost": {"refund_morale": 1},
					"once_per_turn_key": "mengpo_choice",
					"resolution": {
						"action": "disable_target_died_effects_until_turn_end",
						"use_selected_target": true,
						"target_scope": "enemy_battlefield",
						"type": "legion",
						"draw_if_own_hand_size_at_most": 5,
						"draw_count": 1
					}
				},
				{
					"id": "mengpo_discard_then_add_rested_morale",
					"kind": "activated",
					"text": "孟婆: 若我方士气少于对方，弃1，从士气牌库追加1张休整士气。",
					"target_mode": "none",
					"cost": {"discard_cards": 1},
					"once_per_turn_key": "mengpo_choice",
					"controller_morale_less_than_opponent": true,
					"resolution": {"action": "add_morale", "count": 1, "orientation": "rested"}
				}
			]
		"tianting_s02_01m1":
			return [
				{
					"id": "sunwukong_transform_to_legion",
					"kind": "activated",
					"text": "孙悟空: 返还2~8士气，将主宰化身斗士军团登场，兵力=返还士气×1000",
					"target_mode": "none",
					"once_per_turn_key": "sunwukong_transform_to_legion",
					"required_controller_flag_absent": "sunwukong_fighter_card_id",
					"resolution": {
						"action": "choose_option_with_cost",
						"title": "选择返还士气数量",
						"options": [
							{"id": "refund_2", "label": "返还2（2000）", "cost": {"refund_morale": 2}, "resolution": {"action": "sunwukong_deploy_fighter", "amount": 2}},
							{"id": "refund_3", "label": "返还3（3000）", "cost": {"refund_morale": 3}, "resolution": {"action": "sunwukong_deploy_fighter", "amount": 3}},
							{"id": "refund_4", "label": "返还4（4000）", "cost": {"refund_morale": 4}, "resolution": {"action": "sunwukong_deploy_fighter", "amount": 4}},
							{"id": "refund_5", "label": "返还5（5000）", "cost": {"refund_morale": 5}, "resolution": {"action": "sunwukong_deploy_fighter", "amount": 5}},
							{"id": "refund_6", "label": "返还6（6000）", "cost": {"refund_morale": 6}, "resolution": {"action": "sunwukong_deploy_fighter", "amount": 6}},
							{"id": "refund_7", "label": "返还7（7000）", "cost": {"refund_morale": 7}, "resolution": {"action": "sunwukong_deploy_fighter", "amount": 7}},
							{"id": "refund_8", "label": "返还8（8000）", "cost": {"refund_morale": 8}, "resolution": {"action": "sunwukong_deploy_fighter", "amount": 8}}
						]
					}
				}
			]
		"bijie_s02_06m1":
			return [
				{
					"id": "morrigan_gain_rune_on_enemy_legion_death",
					"kind": "triggered",
					"event": "CardDied",
					"text": "莫瑞甘: 我方回合对方军团阵亡时，可获得1符文。",
					"once_per_turn_key": "morrigan_gain_rune_on_enemy_legion_death",
					"player_once_per_turn": true,
					"condition": {
						"controller_turn_only": true,
						"event_player_is_opponent": true,
						"event_card_type_is": "legion"
					},
					"resolution": {
						"optional": true,
						"action": "add_rune",
						"count": 1
					}
				},
				{
					"id": "morrigan_prepare_ready_after_kill",
					"kind": "activated",
					"text": "莫瑞甘: 消耗2符文，选择我方1张彼界军团，本回合下一次击杀对方军团后转为活跃。",
					"target_mode": "none",
					"cost": {"rune": 2},
					"once_per_turn_key": "morrigan_prepare_ready_after_kill",
					"resolution": {"action": "bijie_prepare_ready_after_kill"}
				}
			]
		"bijie_s02_06m2":
			return [
				{
					"id": "aengus_gain_rune_on_trial_completed",
					"kind": "triggered",
					"event": "TrialCompleted",
					"text": "安格斯·麦·奥格: 每完成1次试炼，可获得1符文。",
					"condition": {
						"event_player_is_controller": true
					},
					"resolution": {
						"action": "add_rune",
						"count": 1
					}
				},
				{
					"id": "aengus_advance_trial_on_tactic_resolved",
					"kind": "triggered",
					"event": "EffectResolved",
					"text": "安格斯·麦·奥格: 我方回合成功发动战术效果时，试炼+1。",
					"once_per_turn_key": "aengus_advance_trial_on_tactic_resolved",
					"player_once_per_turn": true,
					"condition": {
						"controller_turn_only": true,
						"event_player_is_controller": true,
						"event_source_type_is": "tactic"
					},
					"resolution": {
						"action": "advance_trial_progress",
						"target_mode": "first_trial",
						"skip_completed": true,
						"count": 1,
						"complete_at": 2
					}
				}
			]
		"olympus_s02_05m1":
			return [
				{
					"id": "artemis_ranged_died_flip_divine",
					"kind": "triggered",
					"event": "CardDied",
					"text": "阿尔忒弥斯: 我方远程军团阵亡时，可翻转1张休整的士气。",
					"once_per_turn_key": "artemis_ranged_died_flip_divine",
					"player_once_per_turn": true,
					"condition": {
						"event_player_is_controller": true,
						"source_card_has_keyword": "ranged",
						"source_card_faction": "olympus"
					},
					"resolution": {
						"action": "olympus_flip_morale",
						"count": 1,
						"include_active": false,
						"include_spent": true
					}
				},
				{
					"id": "artemis_grant_choice",
					"kind": "activated",
					"text": "阿尔忒弥斯: 消耗并翻转1神力或弃置1张手牌，选择我方1张费用3至6的奥林匹斯军团，本回合获得强攻或震击。",
					"target_mode": "none",
					"once_per_turn_key": "artemis_grant_choice",
					"resolution": {
						"action": "choose_option_with_cost",
						"title": "阿尔忒弥斯：选择支付方式",
						"options": [
							{
								"id": "divine",
								"label": "消耗并翻转1神力",
								"cost": {"divine_flip": 1},
								"resolution": {"action": "olympus_artemis_grant_choice"}
							},
							{
								"id": "discard",
								"label": "弃置1张手牌",
								"cost": {"discard_cards": 1},
								"resolution": {"action": "olympus_artemis_grant_choice"}
							}
						]
					}
				}
			]
		"olympus_s02_05m2":
			return [
				{
					"id": "prometheus_search_top",
					"kind": "activated",
					"text": "普罗米修斯: 消耗1神力，查看牌库顶部3张牌，选择其中1张奥林匹斯卡牌加入手牌，其余卡牌自选顺序返回牌库顶部或底部。",
					"target_mode": "none",
					"cost": {"divine": 1},
					"once_per_turn_key": "prometheus_search_top",
					"resolution": {
						"action": "olympus_search_top_pick_and_reorder",
						"count": 3,
						"faction": "olympus",
						"reorder_mode": "top_or_bottom"
					}
				}
			]
		"takamagahara_s01_04m2":
			return [
				{
					"id": "susanoo_front_blessing",
					"kind": "activated",
					"text": "须佐之男: 选择我方1张高天原军团，本回合位于前排进攻时兵力+2000",
					"target_mode": "card",
					"cost": {"morale": 1},
					"once_per_turn_key": "susanoo_front_blessing",
					"resolution": {
						"action": "grant_front_attack_power_bonus",
						"amount": 2000,
						"target_scope": "allied_battlefield",
						"faction": "takamagahara",
						"type": "legion"
					}
				},
				{
					"id": "susanoo_manifest_kusanagi",
					"kind": "activated",
					"text": "须佐之男: 消耗2士气，将圣物区的草薙剑置入前排并视为5000武者",
					"target_mode": "none",
					"cost": {"morale": 2},
					"resolution": {"action": "manifest_kusanagi"}
				}
			]
		"suncity_s01_02m1":
			return [
				{
					"id": "isis_place_canopic",
					"kind": "activated",
					"text": "伊西斯: 弃置我方战场3张陵墓守卫，将墓地1张名字包含<卡诺匹斯>的圣物置入圣物区。随后可抽1张牌或回复1点血量。",
					"target_mode": "none",
					"cost": {"morale": 0},
					"once_per_turn_key": "isis_place_canopic",
					"resolution": {"action": "suncity_place_named_artifact_from_grave"}
				},
				{
					"id": "isis_replace_with_osiris",
					"kind": "activated",
					"text": "伊西斯: 若我方圣物区有5张名字包含<卡诺匹斯>的圣物，则可让复苏的奥西里斯替换登场。",
					"target_mode": "none",
					"once_per_turn_key": "isis_replace_with_osiris",
					"resolution": {"action": "suncity_replace_isis_with_osiris"}
				}
			]
		"suncity_s01_02m3a":
			return [
				{
					"id": "medjed_weaken_enemy",
					"kind": "activated",
					"text": "梅杰德: 消耗1士气，选择对方1张军团本回合兵力-1000。若额外休整我方1张陵墓守卫，则改为-3000。",
					"target_mode": "none",
					"cost": {"morale": 1},
					"once_per_turn_key": "medjed_weaken_enemy",
					"resolution": {"action": "suncity_medjed_weaken"}
				},
				{
					"id": "medjed_master_damaged_revive_tomb_guard",
					"kind": "triggered",
					"event": "MasterDamaged",
					"text": "梅杰德: 对方回合我方主宰因对方进攻或效果受到伤害时，可将我方墓地1张陵墓守卫活跃登场。",
					"once_per_turn_key": "medjed_master_damaged_revive_tomb_guard",
					"player_once_per_turn": true,
					"condition": {
						"opponent_turn_only": true,
						"event_player_is_controller": true,
						"source_card_controller_is_opponent": true
					},
					"resolution": {
						"optional": true,
						"action": "revive_from_grave",
						"count": 1,
						"id": "suncity_s01_0212"
					}
				}
			]
		"suncity_s02_02m1":
			return [
				{
					"id": "nephthys_prepare_discount",
					"kind": "activated",
					"text": "奈芙蒂斯: 弃置我方战场任意数量军团，本回合下1张带天灾等级的太阳城军团费用减少等量。",
					"target_mode": "none",
					"once_per_turn_key": "nephthys_prepare_discount",
					"resolution": {"action": "suncity_prepare_discount_from_battlefield"}
				}
			]
	return []

func _build_morale_effects(state: GameState, player_id: int) -> Array[Dictionary]:
	if player_id < 0 or player_id >= state.players.size():
		return []
	var player = state.get_player(player_id)
	match player.master_definition_id:
		"olympus_s02_05m1", "olympus_s02_05m2":
			return [
				{
					"id": "olympus_morale_flip",
					"kind": "activated",
					"text": "奥林匹斯阵营效果：回合1次，可消耗1士气，翻转1张士气。",
					"target_mode": "none",
					"cost": {"morale": 1},
					"once_per_turn_key": "faction_morale",
					"resolution": {
						"action": "olympus_flip_morale",
						"count": 1,
						"include_active": true,
						"include_spent": true
					}
				}
			]
		"takamagahara_s01_04m2":
			return [
				{
					"id": "takamagahara_morale_draw",
					"kind": "activated",
					"text": "高天原阵营效果：回合1次，可消耗2士气，抽取1张牌；随后可选择我方1张活跃军团进行1格位移。",
					"target_mode": "none",
					"cost": {"morale": 2},
					"once_per_turn_key": "faction_morale",
					"resolution": {
						"action": "draw_cards",
						"count": 1,
						"follow_up_action": {
							"action": "grant_matching_free_move_until_turn_end",
							"effect_id": "takamagahara_morale_follow_move",
							"once_per_turn_key": "takamagahara_morale_follow_move",
							"player_once_per_turn": true,
							"target_scope": "allied_battlefield",
							"type": "legion",
							"required_orientation": "active"
						}
					}
				}
			]
		"suncity_s01_02m1", "suncity_s01_02m2", "suncity_s01_02m3a", "suncity_s02_02m1":
			return [
				{
					"id": "suncity_morale_revive_tomb_guard",
					"kind": "activated",
					"text": "太阳城阵营效果：回合1次，可消耗2士气，将我方墓地1张陵墓守卫活跃登场。",
					"target_mode": "none",
					"cost": {"morale": 2},
					"once_per_turn_key": "suncity_faction_morale_revive",
					"resolution": {
						"action": "revive_from_grave",
						"count": 1,
						"id": "suncity_s01_0212"
					}
				},
				{
					"id": "suncity_morale_draw_if_low_hand",
					"kind": "activated",
					"text": "太阳城阵营效果：回合1次，若我方手牌不高于3张，可消耗1士气，抽取1张牌。",
					"target_mode": "none",
					"cost": {"morale": 1},
					"once_per_turn_key": "suncity_faction_morale_draw",
					"own_hand_size_at_most": 3,
					"resolution": {"action": "draw_cards", "count": 1}
				}
			]
		"asgard_s01_03m1", "asgard_s01_03m2a", "asgard_s02_03m1":
			return [
				{
					"id": "asgard_morale_draw",
					"kind": "activated",
					"text": "阿斯加德阵营效果：回合1次，可消耗2士气，抽取1张牌；若我方主宰血量不高于5，可额外消耗1士气，我方主宰增加1点血量。",
					"target_mode": "none",
					"cost": {"morale": 2},
					"once_per_turn_key": "faction_morale",
					"resolution": {
						"action": "draw_cards",
						"count": 1,
						"follow_up_action": {
							"action": "choose_option_with_cost",
							"title": "是否额外消耗1士气：我方主宰增加1点血量？",
							"optional": true,
							"skip_label": "不额外消耗",
							"cost": {
								"morale": 1
							},
							"own_master_hp_at_most": 5,
							"options": [
								{
									"id": "heal_master",
									"label": "额外消耗1士气并回复1点",
									"resolution": {
										"action": "heal_master",
										"player_scope": "controller",
										"amount": 1
									}
								}
							]
						}
					}
				}
			]
	return []

func _validate_effect_availability(state: GameState, player_id: int, source_id: String, effect: Dictionary, options: Dictionary = {}) -> Dictionary:
	if bool(effect.get("rest_source", false)) and not _is_master_source_id(source_id) and not _is_morale_source_id(source_id):
		var instance = state.card_instances.get(source_id)
		if instance != null and instance.orientation != "active":
			return _error("SOURCE_NOT_READY", "effect source is not active")
	if bool(effect.get("only_during_opponent_turn", false)) and player_id == state.active_player:
		return _error("WRONG_TURN", "effect can only be activated during the opponent turn")
	var required_absent_flag = str(effect.get("required_controller_flag_absent", ""))
	if not required_absent_flag.is_empty() and state.get_player(player_id).flags.has(required_absent_flag):
		var raw_value = state.get_player(player_id).flags.get(required_absent_flag)
		var has_value := false
		match typeof(raw_value):
			TYPE_NIL:
				has_value = false
			TYPE_BOOL:
				has_value = bool(raw_value)
			TYPE_INT:
				has_value = int(raw_value) != 0
			TYPE_STRING:
				has_value = not str(raw_value).is_empty()
			TYPE_ARRAY:
				has_value = raw_value is Array and not raw_value.is_empty()
			TYPE_DICTIONARY:
				has_value = raw_value is Dictionary and not raw_value.is_empty()
			_:
				has_value = true
		if has_value:
			return _error("EFFECT_UNAVAILABLE", "effect requires flag absent")
	if bool(effect.get("controller_morale_less_than_opponent", false)):
		if MoraleActions.count_active_morale(state, player_id) >= MoraleActions.count_active_morale(state, 1 - player_id):
			return _error("MORALE_NOT_LOWER", "controller morale is not lower than opponent")
	var min_runes = int(effect.get("min_runes", -1))
	if min_runes >= 0 and _player_rune_count(state, player_id) < min_runes:
		return _error("INSUFFICIENT_RUNES", "controller rune count does not satisfy effect availability")
	var own_master_hp_at_most = int(effect.get("own_master_hp_at_most", -1))
	if own_master_hp_at_most >= 0 and state.get_player(player_id).master_hp > own_master_hp_at_most:
		return _error("MASTER_HP_TOO_HIGH", "master hp exceeds effect availability limit")
	var required_orientation = str(effect.get("required_orientation", ""))
	if not required_orientation.is_empty() and not _is_master_source_id(source_id) and not _is_morale_source_id(source_id):
		var orientation_instance = state.card_instances.get(source_id)
		if orientation_instance == null or str(orientation_instance.orientation) != required_orientation:
			return _error("INVALID_SOURCE_ORIENTATION", "source orientation does not satisfy effect requirement")
	var required_row = str(effect.get("required_row", ""))
	if not required_row.is_empty() and not _is_master_source_id(source_id) and not _is_morale_source_id(source_id):
		var row_instance = state.card_instances.get(source_id)
		if row_instance == null or str(row_instance.position.get("row", "")) != required_row:
			return _error("INVALID_SOURCE_ROW", "source row does not satisfy effect requirement")
	var required_zone_value = effect.get("required_zone", null)
	if not _effect_required_zone_matches(state, source_id, required_zone_value):
		return _error("INVALID_ZONE", "source zone does not satisfy effect requirement")
	if not _is_master_source_id(source_id) and not _is_morale_source_id(source_id):
		var zone_instance = state.card_instances.get(source_id)
		var zone_definition = state.get_definition(zone_instance.definition_id) if zone_instance != null else null
		if zone_instance != null and str(zone_instance.zone) == "artifact_zone" and zone_definition != null and zone_definition.is_artifact():
			if _artifact_is_locked_by_enemy_tactic(state, player_id, source_id):
				return _error("EFFECT_UNAVAILABLE", "artifact is locked by an enemy tactic")
	var source_trial_progress_at_least = int(effect.get("source_trial_progress_at_least", -1))
	if source_trial_progress_at_least >= 0:
		var progress_instance = state.card_instances.get(source_id)
		if progress_instance == null or int(progress_instance.flags.get("trial_progress", 0)) < source_trial_progress_at_least:
			return _error("INSUFFICIENT_TRIAL_PROGRESS", "source trial progress does not satisfy effect requirement")
	if bool(effect.get("source_trial_completed", false)):
		var completed_instance = state.card_instances.get(source_id)
		if completed_instance == null or not bool(completed_instance.flags.get("trial_completed", false)):
			return _error("TRIAL_NOT_COMPLETED", "source trial is not completed")
	if bool(effect.get("source_trial_uncompleted", false)):
		var uncompleted_instance = state.card_instances.get(source_id)
		if uncompleted_instance != null and bool(uncompleted_instance.flags.get("trial_completed", false)):
			return _error("TRIAL_ALREADY_COMPLETED", "source trial is already completed")
	var min_own_grave_cards = int(effect.get("min_own_grave_cards", 0))
	if min_own_grave_cards > 0:
		if player_id < 0 or player_id >= state.players.size():
			return _error("INVALID_PLAYER", "invalid player for grave requirement")
		if state.get_player(player_id).grave.cards.size() < min_own_grave_cards:
			return _error("INSUFFICIENT_GRAVE_CARDS", "not enough grave cards for effect availability")
	var own_hand_size_at_most = int(effect.get("own_hand_size_at_most", -1))
	if own_hand_size_at_most >= 0:
		var hand_size = int(options.get("hand_cards_after_source_leaves", state.get_player(player_id).hand.cards.size()))
		if hand_size > own_hand_size_at_most:
			return _error("HAND_SIZE_TOO_LARGE", "hand size exceeds effect availability limit")
	var own_master_effect_damage_taken_this_turn_at_least = int(effect.get("own_master_effect_damage_taken_this_turn_at_least", -1))
	if own_master_effect_damage_taken_this_turn_at_least >= 0:
		if int(state.get_player(player_id).flags.get("master_effect_damage_taken_this_turn", 0)) < own_master_effect_damage_taken_this_turn_at_least:
			return _error("INSUFFICIENT_MASTER_EFFECT_DAMAGE", "master has not taken enough effect damage this turn")
	var own_master_damage_taken_this_turn_at_least = int(effect.get("own_master_damage_taken_this_turn_at_least", -1))
	if own_master_damage_taken_this_turn_at_least >= 0:
		if int(state.get_player(player_id).flags.get("master_damage_taken_this_turn", 0)) < own_master_damage_taken_this_turn_at_least:
			return _error("INSUFFICIENT_MASTER_DAMAGE", "master has not taken enough damage this turn")
	var required_master_definition_id = str(effect.get("required_controller_master_definition_id", ""))
	if not required_master_definition_id.is_empty():
		if str(state.get_player(player_id).master_definition_id) != required_master_definition_id:
			return _error("INVALID_MASTER", "controller master does not satisfy effect requirement")
	var resolution = effect.get("resolution", {})
	if resolution is Dictionary and str(resolution.get("action", "")) == "reveal_source_face_up":
		var reveal_instance = state.card_instances.get(source_id)
		if reveal_instance == null or not bool(reveal_instance.flags.get("concealed", false)):
			return _error("NOT_CONCEALED", "source is not concealed")
	if resolution is Dictionary and str(resolution.get("action", "")) == "move_source_one_step":
		var moving_instance = state.card_instances.get(source_id)
		if moving_instance == null or not str(moving_instance.zone).begins_with("battle_"):
			return _error("INVALID_SOURCE", "source must be on the battlefield")
		if _instance_has_troop_type(state, source_id, "cavalry"):
			if str(moving_instance.orientation) != "active":
				return _error("SOURCE_NOT_ACTIVE", "cavalry source must be active to move")
			if bool(moving_instance.flags.get("moved_this_turn", false)):
				return _error("EFFECT_ALREADY_USED", "cavalry move is already used this turn")
	if resolution is Dictionary and str(resolution.get("action", "")) == "manifest_kusanagi":
		var has_kusanagi := false
		var player = state.get_player(player_id)
		for card_id in player.artifact_zone.cards:
			var artifact_instance = state.card_instances.get(card_id)
			if artifact_instance != null and str(artifact_instance.definition_id) == "takamagahara_s01_0417":
				has_kusanagi = true
				break
		if not has_kusanagi:
			return _error("EFFECT_UNAVAILABLE", "kusanagi is not in artifact zone")
	if resolution is Dictionary and str(resolution.get("action", "")) == "choose_discard_from_hand_then_follow_up":
		var discard_count: int = max(1, int(resolution.get("discard_count", 1)))
		var hand_size := int(options.get("hand_cards_after_source_leaves", state.get_player(player_id).hand.cards.size()))
		if hand_size < discard_count:
			return _error("NOT_ENOUGH_HAND_CARDS", "not enough hand cards to choose for discard")
	if resolution is Dictionary and str(resolution.get("action", "")) == "undo_ready_event_and_discard_enemy_hand":
		var response_event = options.get("response_source_event", null)
		if response_event == null:
			response_event = _find_event_by_id(state, _current_response_source_event_id(state))
		if not _is_effect_ready_transition_event(response_event):
			return _error("NO_AVAILABLE_TARGETS", "there is no matching ready event to answer")
	if resolution is Dictionary and str(resolution.get("action", "")) == "ruined_ritual_force_discard_and_blank_entry":
		var response_event = options.get("response_source_event", null)
		if response_event == null:
			response_event = _find_event_by_id(state, _current_response_source_event_id(state))
		if not _is_non_hand_legion_entry_event(state, response_event):
			return _error("NO_AVAILABLE_TARGETS", "there is no matching non-hand legion entry event to answer")
	if resolution is Dictionary and not _resolution_has_available_targets_for_activation(state, player_id, source_id, resolution):
		return _error("NO_AVAILABLE_TARGETS", "effect has no available targets")
	if _is_free_master_morale_effect_activation(state, player_id, source_id, effect):
		return {"ok": true}
	var once_key = str(effect.get("once_per_turn_key", ""))
	if once_key.is_empty():
		return {"ok": true}
	if bool(effect.get("player_once_per_turn", false)):
		if bool(state.get_player(player_id).once_per_turn.get(once_key, false)):
			return _error("EFFECT_ALREADY_USED", "effect is already used this turn")
		return {"ok": true}
	if _is_effect_used_this_turn(state, player_id, source_id, once_key):
		return _error("EFFECT_ALREADY_USED", "effect is already used this turn")
	return {"ok": true}

func _resolution_has_available_targets_for_activation(state: GameState, player_id: int, source_id: String, resolution: Dictionary) -> bool:
	match str(resolution.get("action", "")):
		"deploy_matching_legion_from_hand":
			return not _matching_hand_card_ids(state, player_id, resolution).is_empty() and not _battlefield_slot_options(state, player_id).is_empty()
		"deploy_matching_legion_from_hand_deck_or_grave":
			return not _collect_matching_card_ids_from_controller_regions(state, player_id, resolution).is_empty() and not _battlefield_slot_options(state, player_id).is_empty()
		"forged_order_prepare_enemy_moves":
			return not _forged_order_movable_enemy_legion_ids(state, player_id).is_empty()
		"choose_and_move_units":
			return not _movable_resolution_candidate_ids(state, player_id, source_id, resolution).is_empty()
		"choose_and_grant_cannot_die_until_turn_end", "choose_and_grant_cannot_die_once_until_next_own_turn_start":
			return not _resolution_battlefield_candidate_ids(state, player_id, source_id, resolution, false).is_empty()
		"recycle_grave_to_deck":
			var count = int(resolution.get("count", 1))
			if count <= 0:
				return false
			var candidates = _matching_grave_card_ids(state, player_id, resolution)
			if bool(resolution.get("require_exact_count", false)):
				return candidates.size() >= count
			return not candidates.is_empty()
		"attach_source_to_enemy_artifact_lock":
			return not _enemy_artifact_candidate_ids(state, player_id).is_empty()
		"prepare_free_master_morale_effect_activation":
			return _has_available_free_master_morale_effect_target(state, player_id)
		"set_pending_attack_extra_discard_requirement":
			var pending_attacker_id := str(state.pending_attack.get("attacker_id", ""))
			var pending_attacker = state.card_instances.get(pending_attacker_id)
			var is_pending_attack_controller := pending_attacker != null and int(pending_attacker.controller) == player_id
			return not state.pending_attack.is_empty() \
				and is_pending_attack_controller \
				and _pending_attack_has_defense_selection(state.pending_attack) \
				and not bool(state.pending_attack.get("extra_defense_discard_required", false)) \
				and (
					not str(state.pending_attack.get("blocker_id", "")).is_empty() \
					or not str(state.pending_attack.get("supporter_id", "")).is_empty() \
					or (
						state.pending_attack.get("master_guard_card_ids", []) is Array \
						and not state.pending_attack.get("master_guard_card_ids", []).is_empty()
					)
				)
		"choose_and_modify_power_until_next_own_turn_end":
			return not _resolution_battlefield_candidate_ids(state, player_id, source_id, resolution, false).is_empty()
		"choose_option_with_cost":
			var raw_options = resolution.get("options", [])
			if not (raw_options is Array):
				return false
			for raw_option in raw_options:
				if not (raw_option is Dictionary):
					continue
				var option_resolution = raw_option.get("resolution", {})
				if option_resolution is Dictionary and _resolution_has_available_targets_for_activation(state, player_id, source_id, option_resolution):
					return true
			return false
	return true

func _resolution_battlefield_candidate_ids(state: GameState, player_id: int, source_id: String, resolution: Dictionary, controller_only: bool) -> Array[String]:
	var result: Array[String] = []
	var stack_item = {
		"controller": player_id,
		"source_instance_id": source_id,
		"resolution": resolution
	}
	var candidate_pool: Array[String] = _get_battlefield_card_ids_for_player(state, player_id) if controller_only else _get_battlefield_card_ids(state)
	for target_card_id in candidate_pool:
		if _target_card_matches_stack_resolution_filters(state, stack_item, str(target_card_id)):
			result.append(str(target_card_id))
	return result

func _movable_resolution_candidate_ids(state: GameState, player_id: int, source_id: String, resolution: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for card_id in _resolution_battlefield_candidate_ids(state, player_id, source_id, resolution, true):
		if not _effect_move_slot_options(state, card_id).is_empty():
			result.append(card_id)
	return result

func _forged_order_vertical_move_targets(state: GameState, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var instance = state.card_instances.get(card_id)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return result
	var row := str(instance.position.get("row", ""))
	var col := int(instance.position.get("col", -1))
	if (row != "front" and row != "back") or col < 0:
		return result
	var player = state.get_player(int(instance.controller))
	_append_move_target_if_legal(state, player, row, col, "back" if row == "front" else "front", col, result)
	return result

func _forged_order_movable_enemy_legion_ids(state: GameState, controller: int, excluded_ids: Array[String] = []) -> Array[String]:
	var result: Array[String] = []
	for raw_card_id in _get_battlefield_legion_card_ids_for_player(state, 1 - controller):
		var card_id := str(raw_card_id)
		if card_id.is_empty() or excluded_ids.has(card_id):
			continue
		if _forged_order_vertical_move_targets(state, card_id).is_empty():
			continue
		result.append(card_id)
	return result

func _mark_effect_as_used(state: GameState, player_id: int, source_id: String, effect: Dictionary) -> void:
	if _is_free_master_morale_effect_activation(state, player_id, source_id, effect):
		return
	var once_key = str(effect.get("once_per_turn_key", ""))
	if once_key.is_empty():
		return
	if bool(effect.get("player_once_per_turn", false)):
		state.get_player(player_id).once_per_turn[once_key] = true
		return
	_set_effect_used_this_turn(state, player_id, source_id, once_key)

func _is_effect_used_this_turn(state: GameState, player_id: int, source_id: String, once_key: String) -> bool:
	if _is_master_source_id(source_id) or _is_morale_source_id(source_id):
		return bool(state.get_player(player_id).once_per_turn.get(once_key, false))
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return false
	return int(instance.flags.get("once_per_turn_%s" % once_key, -1)) == state.turn_number

func _set_effect_used_this_turn(state: GameState, player_id: int, source_id: String, once_key: String) -> void:
	if _is_master_source_id(source_id) or _is_morale_source_id(source_id):
		state.get_player(player_id).once_per_turn[once_key] = true
		return
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return
	instance.flags["once_per_turn_%s" % once_key] = state.turn_number

func _validate_candidate_card_selection(choice: Dictionary, selected_card_ids: Array) -> Dictionary:
	var required_count = int(choice.get("count", 1))
	var candidates = choice.get("candidate_card_ids", [])
	if not (candidates is Array):
		return _error("INVALID_CHOICE", "candidate cards are missing")
	var min_select_count = max(0, int(choice.get("context", {}).get("min_select_count", 0)))
	var allow_up_to_count = bool(choice.get("context", {}).get("allow_up_to_count", false))
	if selected_card_ids.size() < min_select_count:
		return _error("INVALID_CHOICE", "must select at least %s card(s)" % min_select_count)
	if allow_up_to_count:
		if selected_card_ids.size() > required_count:
			return _error("INVALID_CHOICE", "must select at most %s card(s)" % required_count)
	else:
		if selected_card_ids.size() != required_count:
			return _error("INVALID_CHOICE", "must select exactly %s card(s)" % required_count)
	var seen := {}
	for raw_card_id in selected_card_ids:
		var card_id = str(raw_card_id)
		if card_id.is_empty():
			return _error("INVALID_CHOICE", "choice contains an empty card id")
		if seen.has(card_id):
			return _error("INVALID_CHOICE", "choice contains duplicate cards")
		if not candidates.has(card_id):
			return _error("INVALID_CHOICE", "choice selected a card outside candidates")
		seen[card_id] = true
	return {"ok": true}

func _validate_option_choice_selection(choice: Dictionary, selected_option: String) -> Dictionary:
	if selected_option.is_empty():
		return _error("INVALID_CHOICE", "selected_option is required")
	for option in choice.get("options", []):
		if str(option.get("id", "")) == selected_option:
			return {"ok": true}
	return _error("INVALID_CHOICE", "unknown selected option")

func _apply_debug_command(state: GameState, command: GameCommand) -> Array:
	var action = str(command.payload.get("action", ""))
	match action:
		"draw_cards":
			var player_id = int(command.payload.get("player_id", state.active_player))
			var count = int(command.payload.get("count", 1))
			return DrawActions.draw_cards(state, player_id, count, command.command_id)
		"add_morale":
			var player_id = int(command.payload.get("player_id", state.active_player))
			var count = int(command.payload.get("count", 1))
			return MoraleActions.add_morale_from_cost_deck(state, player_id, count, "active", command.command_id)
		"add_rune":
			var player_id = int(command.payload.get("player_id", state.active_player))
			var count = int(command.payload.get("count", 1))
			return _add_player_runes(state, player_id, count, command.command_id)
		"set_master_hp":
			var player_id = int(command.payload.get("player_id", state.active_player))
			var hp = int(command.payload.get("hp", 20))
			var player = state.get_player(player_id)
			player.master_hp = min(player.master_max_hp, hp)
			var event = GameEvent.create(state.next_event_id(), "MasterHpSet", player_id, {"hp": player.master_hp})
			event.created_by_command = command.command_id
			state.event_log.append(event)
			var events: Array = [event]
			events.append_array(_check_immediate_loss(state, player_id, command.command_id))
			return events
		"set_calamity_value":
			var value = int(command.payload.get("value", state.calamity_value))
			state.calamity_value = value
			var event = GameEvent.create(state.next_event_id(), "CalamityValueChanged", state.active_player, {"value": state.calamity_value})
			event.created_by_command = command.command_id
			state.event_log.append(event)
			return [event]
		"reveal_calamity":
			var definition_id = str(command.payload.get("definition_id", ""))
			return _reveal_calamity(state, definition_id, command.command_id)
	return []

func _apply_activate_effect(state: GameState, command: GameCommand) -> Array:
	var source_id = str(command.payload.get("source_id", ""))
	var effect_id = str(command.payload.get("effect_id", ""))
	var effect = _find_source_effect_definition(state, source_id, effect_id, "activated", command.player_id)
	var targets = _build_effect_targets(command, effect)
	var cost_result = _pay_effect_costs(state, command.player_id, effect, command.command_id, {"source_id": source_id})
	if not cost_result.get("ok", false):
		return []
	var events: Array = cost_result.get("events", [])
	var paid_costs = cost_result.get("paid_costs", [])
	var cost_event = GameEvent.create(state.next_event_id(), "CostPaid", command.player_id, {
		"source_id": source_id,
		"effect_id": effect_id,
		"paid_costs": paid_costs
	})
	cost_event.created_by_command = command.command_id
	state.event_log.append(cost_event)
	events.append(cost_event)
	var free_master_activation := _is_free_master_morale_effect_activation(state, command.player_id, source_id, effect)
	if free_master_activation:
		var player = state.get_player(command.player_id)
		player.flags["free_master_morale_effect_activation_count"] = max(0, int(player.flags.get("free_master_morale_effect_activation_count", 0)) - 1)
	_mark_effect_as_used(state, command.player_id, source_id, effect)
	if bool(effect.get("rest_source", false)):
		var source_instance = state.card_instances.get(source_id)
		if source_instance != null:
			source_instance.orientation = "rested"
			var rest_event = GameEvent.create(state.next_event_id(), "CardRested", command.player_id, {
				"card_id": source_id,
				"reason": "activate_effect"
			})
			rest_event.created_by_command = command.command_id
			state.event_log.append(rest_event)
			events.append(rest_event)
			if state.current_calamity == "calamity_s02_ds03":
				events.append_array(_deal_master_damage(state, command.player_id, 1, command.command_id, {
					"non_lethal": true,
					"source_kind": "calamity"
				}))
	if state.current_calamity == "calamity_s01_ds08":
		var source_instance = state.card_instances.get(source_id)
		if source_instance != null and source_instance.zone == "artifact_zone":
			events.append_array(_deal_master_damage(state, command.player_id, 1, command.command_id, {
				"non_lethal": true,
				"source_kind": "calamity"
			}))
	var effect_type := "activated"
	if _is_set_counter_tactic_source(state, source_id):
		events.append_array(_move_set_counter_to_stack_pending(state, command.player_id, source_id, command.command_id))
		effect_type = "counter_tactic"
	var created_from_event_id := 0
	if _effect_has_response_source_event_filters(effect):
		created_from_event_id = _current_response_source_event_id(state)
	events.append_array(_put_effect_on_stack(state, command.player_id, source_id, effect, effect_type, paid_costs, created_from_event_id, targets, command.command_id))
	events.append_array(_queue_additional_stack_effects(state, command.player_id, source_id, effect, command.command_id))
	return events

func _apply_pass_priority(state: GameState, command: GameCommand) -> Array:
	var pass_event = GameEvent.create(state.next_event_id(), "PriorityPassed", command.player_id, {
		"stack_size": state.stack.size(),
		"pending_attack": not state.pending_attack.is_empty()
	})
	pass_event.created_by_command = command.command_id
	state.event_log.append(pass_event)
	var events: Array = [pass_event]
	if state.priority_pass_count == 0:
		state.priority_pass_count = 1
		state.priority_player = 1 - command.player_id
		return events
	state.priority_pass_count = 0
	state.priority_player = state.active_player
	if state.stack.is_empty() and not state.pending_attack.is_empty():
		events.append_array(_resolve_pending_attack_if_ready(state, command.command_id))
		return events
	events.append_array(_resolve_top_stack_item(state, command.command_id))
	return events

func _apply_resolve_choice(state: GameState, command: GameCommand) -> Array:
	var choice_id = str(command.payload.get("choice_id", ""))
	var choice_index = _find_pending_choice_index(state, choice_id)
	if choice_index == -1:
		return []
	var choice = state.pending_choices[choice_index]
	state.pending_choices.remove_at(choice_index)
	if bool(command.payload.get("cancelled", false)):
		var canceled_events = _cancel_pending_choice(state, choice, command.command_id)
		canceled_events.append_array(_flush_suncity_pending_codex_rewards(state, command.command_id))
		return canceled_events
	var selected_card_ids = _normalize_selected_card_ids(command.payload.get("selected_card_ids", []))
	var events: Array = []
	match str(choice.get("type", "")):
		"search_deck_pick":
			events = DrawActions.resolve_search_choice(state, choice, selected_card_ids, command.command_id)
		"candidate_cards_pick":
			events = _resolve_candidate_cards_choice(state, choice, selected_card_ids, command.payload, command.command_id)
		"option_pick":
			events = _resolve_option_choice(state, choice, str(command.payload.get("selected_option", "")), command.command_id)
		_:
			events = []
	events.append_array(_flush_suncity_pending_codex_rewards(state, command.command_id))
	return events

func _cancel_pending_choice(state: GameState, choice: Dictionary, command_id: String) -> Array:
	match str(choice.get("type", "")):
		"candidate_cards_pick":
			var operation := str(choice.get("operation", ""))
			if operation == "search_deck" or operation == "search_deck_reorder_bottom" or operation == "search_top_for_artifact_and_named_legion":
				return DrawActions.cancel_search_choice(state, choice, command_id)
			if operation == "olympus_helen_lethal_replace":
				return _resolve_pending_olympus_lethal_death(state, choice.get("context", {}), command_id)
			if operation == "landlord_coercion_extra_discard":
				return _resolve_candidate_cards_choice(state, choice, [], {}, command_id)
		"option_pick":
			var operation = str(choice.get("operation", ""))
			if operation == "optional_stack_effect" or operation == "olympus_achilles_lethal_replace":
				return _resolve_option_choice(state, choice, "no", command_id)
	return []

func _resolve_initial_deck_lists(deck_lists: Array, options: Dictionary) -> Array:
	var prepared_orders = options.get("player_deck_orders", [])
	var resolved: Array = []
	if prepared_orders is Array and prepared_orders.size() >= deck_lists.size():
		for player_id in range(deck_lists.size()):
			var prepared = prepared_orders[player_id]
			if prepared is Array and not prepared.is_empty():
				resolved.append(prepared.duplicate())
				continue
			resolved.append(deck_lists[player_id].duplicate())
		return resolved
	for raw_deck in deck_lists:
		if raw_deck is Array:
			resolved.append(raw_deck.duplicate())
		else:
			resolved.append([])
	return resolved


func _start_game(state: GameState, options: Dictionary = {}) -> void:
	state.phase = "main"
	var requested_active_player := clampi(int(options.get("starting_active_player", 0)), 0, max(0, state.players.size() - 1))
	state.active_player = requested_active_player
	state.priority_player = requested_active_player
	var opening_hand_size := _rules_int(state, "opening_hand_size", 5)
	var active_player_morale := _rules_int(state, "opening_active_player_morale", 3)
	var non_active_player_morale := _rules_int(state, "opening_non_active_player_morale", active_player_morale)
	for player_id in range(2):
		var player_opening_hand_size := _rule_opening_hand_size(state, player_id, opening_hand_size)
		_apply_rule_game_start_effects(state, player_id, "setup")
		_extract_setup_special_cards(state, player_id, "setup")
		player_opening_hand_size = _master_opening_hand_size(state, player_id, player_opening_hand_size)
		_apply_master_pre_draw_game_start_effects(state, player_id, "setup")
		DrawActions.draw_cards(state, player_id, player_opening_hand_size, "setup")
		_apply_master_game_start_effects(state, player_id, "setup")
		var opening_morale := active_player_morale if player_id == state.active_player else non_active_player_morale
		MoraleActions.add_morale_from_cost_deck(state, player_id, opening_morale, "active", "setup")
	state.event_log.append(GameEvent.create(state.next_event_id(), "GameStarted", 0, {
		"seed": state.seed,
		"mode": str(state.rules_config.get("mode", "demo")),
		"active_player": state.active_player
	}))
	_request_valkyrie_first_turn_draw_replacement(state, "setup")

func _player_opening_setup_choice(state: GameState, player_id: int, key: String):
	if player_id < 0 or key.is_empty():
		return null
	var raw_choices = state.rules_config.get("opening_setup_choices", [])
	if not (raw_choices is Array) or player_id >= raw_choices.size():
		return null
	var player_choices = raw_choices[player_id]
	if not (player_choices is Dictionary) or not player_choices.has(key):
		return null
	return player_choices.get(key)

func _should_apply_andvaranot_opening_setup(state: GameState, player_id: int) -> bool:
	var explicit_choice = _player_opening_setup_choice(state, player_id, "andvaranot_to_artifact")
	if explicit_choice != null:
		return bool(explicit_choice)
	return _player_has_definition_in_deck(state, player_id, "asgard_s02_0305")

func _should_apply_thor_opening_hammer(state: GameState, player_id: int) -> bool:
	var explicit_choice = _player_opening_setup_choice(state, player_id, "thor_add_hammer_to_hand")
	if explicit_choice != null:
		return bool(explicit_choice)
	if player_id < 0 or player_id >= state.players.size():
		return false
	var player = state.get_player(player_id)
	return player.master_definition_id == "asgard_s02_03m1" \
		and not _find_player_card_by_definition_in_zone(player.deck.cards, state, "asgard_s02_0301").is_empty()

func _master_opening_hand_size(state: GameState, player_id: int, default_count: int) -> int:
	if player_id < 0 or player_id >= state.players.size():
		return default_count
	if _should_apply_thor_opening_hammer(state, player_id):
		return max(0, default_count - 1)
	return default_count

func _rule_opening_hand_size(state: GameState, player_id: int, default_count: int) -> int:
	if _should_apply_andvaranot_opening_setup(state, player_id):
		return min(default_count, 4)
	return default_count

func _is_suncity_gravebound_definition(definition_id: String) -> bool:
	return definition_id == "suncity_s01_0212" or definition_id == "suncity_s02_0201"

func _is_suncity_canopic_definition(definition_id: String) -> bool:
	return definition_id == "suncity_s01_0216" \
		or definition_id == "suncity_s01_0217" \
		or definition_id == "suncity_s01_0218" \
		or definition_id == "suncity_s01_0219" \
		or definition_id == "suncity_s01_0220"

func _definition_name_contains(definition, text: String) -> bool:
	return definition != null and str(definition.name).find(text) >= 0

func _card_name_contains(state: GameState, card_id: String, text: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	return _definition_name_contains(state.get_definition(instance.definition_id), text)

func _artifact_definition_ignores_limit(definition) -> bool:
	return definition != null and _definition_name_contains(definition, "卡诺匹斯")

func _artifact_card_ignores_limit(state: GameState, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	return _artifact_definition_ignores_limit(state.get_definition(instance.definition_id))

func _replace_existing_artifacts_for_definition(state: GameState, player_id: int, definition, command_id: String) -> Array:
	var player = state.get_player(player_id)
	if player.artifact_zone.cards.is_empty():
		return []
	if _artifact_definition_ignores_limit(definition):
		return []
	var events: Array = []
	for artifact_id in player.artifact_zone.cards.duplicate():
		if _artifact_card_ignores_limit(state, str(artifact_id)):
			continue
		events.append_array(_send_artifact_to_grave(state, player_id, str(artifact_id), command_id))
	return events

func _send_artifact_to_grave(state: GameState, player_id: int, artifact_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	if artifact_id.is_empty() or not player.artifact_zone.remove_card(artifact_id):
		return []
	player.grave.add_card_to_top(artifact_id)
	var instance = state.card_instances.get(artifact_id)
	if instance != null:
		instance.zone = "grave"
		instance.position = {}
		instance.orientation = "active"
	var event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, {
		"card_id": artifact_id,
		"from": "artifact_zone",
		"to": "grave"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	events.append_array(_artifact_zone_leave_cleanup_events(state, artifact_id, command_id))
	return events

func _place_artifact_without_play(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var definition = state.get_definition(instance.definition_id)
	if definition == null or not definition.is_artifact():
		return []
	var events: Array = _replace_existing_artifacts_for_definition(state, player_id, definition, command_id)
	_remove_card_from_current_zone(state, card_id)
	state.get_player(player_id).artifact_zone.add_card(card_id)
	instance.zone = "artifact_zone"
	instance.position = {}
	instance.orientation = "active"
	instance.controller = player_id
	var event = GameEvent.create(state.next_event_id(), "CardMoved", player_id, {
		"card_id": card_id,
		"from": "grave",
		"to": "artifact_zone",
		"placed": true
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	events.append(event)
	return events


func _effect_requires_play_card_discard_choice(effect: Dictionary) -> bool:
	var cost = effect.get("cost", {})
	return cost is Dictionary and int(cost.get("discard_cards", 0)) > 0


func _request_play_card_effect_discard_choice(state: GameState, player_id: int, card_id: String, effect: Dictionary, effect_type: String, targets: Dictionary, command_id: String, extra_context: Dictionary = {}) -> Array:
	var discard_count: int = min(max(1, int(effect.get("cost", {}).get("discard_cards", 0))), max(0, state.get_player(player_id).hand.cards.size() - 1))
	if discard_count <= 0:
		return []
	var candidates: Array[String] = []
	for hand_card_id in state.get_player(player_id).hand.cards:
		var candidate_id := str(hand_card_id)
		if candidate_id == card_id:
			continue
		candidates.append(candidate_id)
	var card_name := _action_card_name(state, card_id)
	var follow_up_context: Dictionary = {
		"action": "continue_pending_play_card_effect",
		"card_id": card_id,
		"effect_id": str(effect.get("id", "")),
		"effect_type": effect_type,
		"targets": targets.duplicate(true),
		"discard_count": discard_count
	}
	for key in extra_context.keys():
		follow_up_context[key] = extra_context.get(key)
	return _request_candidate_cards_choice(state, player_id, candidates, discard_count, "%s：选择手牌弃置" % card_name, "discard_from_hand", {
		"requires_confirm": true,
		"hint_text": "%s：请先从高亮手牌中选择 %d 张弃置，再点击确认。" % [card_name, discard_count],
		"top_hint_text": "%s：请先选择要弃置的手牌，确认后才会发动效果。" % card_name,
		"follow_up_action": follow_up_context,
		"initiator_player": player_id,
		"source_instance_id": card_id
	}, command_id)


func _continue_pending_play_card_effect(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	var controller = int(stack_item.get("controller", state.active_player))
	var card_id := str(resolution.get("card_id", stack_item.get("source_instance_id", "")))
	if card_id.is_empty():
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null or str(instance.zone) != "hand":
		return []
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return []
	var effect_id := str(resolution.get("effect_id", ""))
	var effect := _find_selected_tactic_effect(definition, effect_id)
	if effect.is_empty():
		return []
	var row := str(resolution.get("row", "tactic"))
	var col := int(resolution.get("col", -1))
	var selected_play_option_id := str(resolution.get("play_option_id", ""))
	var targets: Dictionary = resolution.get("targets", {}).duplicate(true) if resolution.get("targets", {}) is Dictionary else {}
	var events: Array = []
	events.append_array(MoraleActions.consume_morale(state, controller, _effective_hand_play_cost(state, card_id, {}, row), command_id))
	if definition.is_tactic():
		var player = state.get_player(controller)
		var free_tactic_state = player.flags.get("tianting_next_tactic_free", {})
		if free_tactic_state is Dictionary and int(free_tactic_state.get("turn", -1)) == state.turn_number:
			player.flags.erase("tianting_next_tactic_free")
	var effect_cost_result = _pay_effect_costs(state, controller, effect, command_id, {
		"skip_discard_cards": true
	})
	var paid_costs: Array = effect_cost_result.get("paid_costs", [])
	events.append_array(effect_cost_result.get("events", []))
	var discard_count := int(resolution.get("discard_count", 0))
	if discard_count > 0:
		paid_costs.append({
			"type": "discard_cards",
			"amount": discard_count
		})
	var effect_type := str(resolution.get("effect_type", "tactic"))
	state.get_player(controller).hand.remove_card(card_id)
	instance.zone = "stack_pending"
	instance.position = {}
	instance.orientation = "active"
	if effect_type == "tactic":
		_remember_last_active_tactic(state, controller, card_id, effect)
	_mark_effect_as_used(state, controller, card_id, effect)
	events.append_array(_put_effect_on_stack(state, controller, card_id, effect, effect_type, paid_costs, 0, targets, command_id))
	events.append_array(_queue_additional_stack_effects(state, controller, card_id, effect, command_id))
	var played_event = GameEvent.create(state.next_event_id(), "CardPlayed", controller, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"zone": instance.zone,
		"play_option_id": selected_play_option_id
	})
	played_event.created_by_command = command_id
	state.event_log.append(played_event)
	events.append(played_event)
	return events

func _move_deck_definition_to_grave(state: GameState, player_id: int, definition_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var card_id := _find_player_card_by_definition_in_zone(player.deck.cards, state, definition_id)
	if card_id.is_empty():
		return []
	player.deck.remove_card(card_id)
	player.grave.add_card_to_top(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "grave"
		instance.position = {}
		instance.controller = instance.owner
		instance.orientation = "active"
	var event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, {
		"card_id": card_id,
		"from": "deck",
		"to": "grave",
		"reason": "setup_rule"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _move_deck_definition_to_hand(state: GameState, player_id: int, definition_id: String, command_id: String, reason: String = "setup_rule") -> Array:
	var player = state.get_player(player_id)
	var card_id := _find_player_card_by_definition_in_zone(player.deck.cards, state, definition_id)
	if card_id.is_empty():
		return []
	player.deck.remove_card(card_id)
	player.hand.add_card(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "hand"
		instance.position = {}
		instance.controller = instance.owner
		instance.orientation = "active"
	var event = GameEvent.create(state.next_event_id(), "CardDrawn", player_id, {
		"card_id": card_id,
		"from": "deck",
		"reason": reason
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _controller_canopic_artifact_count(state: GameState, player_id: int) -> int:
	var total := 0
	for card_id in state.get_player(player_id).artifact_zone.cards:
		if _card_name_contains(state, str(card_id), "卡诺匹斯"):
			total += 1
	return total

func _apply_rule_game_start_effects(state: GameState, player_id: int, command_id: String) -> Array:
	var events: Array = []
	events.append_array(_move_deck_definition_to_grave(state, player_id, "suncity_s01_0212", command_id))
	events.append_array(_move_deck_definition_to_grave(state, player_id, "suncity_s02_0201", command_id))
	if not _should_apply_andvaranot_opening_setup(state, player_id):
		return events
	var player = state.get_player(player_id)
	var artifact_id := _find_player_card_by_definition_in_zone(player.deck.cards, state, "asgard_s02_0305")
	if artifact_id.is_empty():
		return events
	player.deck.remove_card(artifact_id)
	var artifact_instance = state.card_instances.get(artifact_id)
	var artifact_definition = state.get_definition(artifact_instance.definition_id) if artifact_instance != null else null
	events.append_array(_replace_existing_artifacts_for_definition(state, player_id, artifact_definition, command_id))
	player.artifact_zone.add_card(artifact_id)
	var instance = artifact_instance
	if instance != null:
		instance.zone = "artifact_zone"
		instance.position = {}
		instance.orientation = "active"
		instance.controller = player_id
	var played_event = GameEvent.create(state.next_event_id(), "CardPlayed", player_id, {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1,
		"played_as": "setup_rule"
	})
	played_event.created_by_command = command_id
	state.event_log.append(played_event)
	events.append(played_event)
	return events

func _apply_master_pre_draw_game_start_effects(state: GameState, player_id: int, command_id: String) -> Array:
	if not _should_apply_thor_opening_hammer(state, player_id):
		return []
	return _move_deck_definition_to_hand(state, player_id, "asgard_s02_0301", command_id, "thor_opening_hand")

func _extract_setup_special_cards(state: GameState, player_id: int, command_id: String) -> Array:
	var events: Array = []
	var player = state.get_player(player_id)
	for card_id in player.deck.cards.duplicate():
		var instance = state.card_instances.get(str(card_id))
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null:
			continue
		if definition.is_trial():
			player.deck.remove_card(card_id)
			player.trial_zone.add_card(card_id)
			instance.zone = "trial_zone"
			instance.position = {}
			instance.orientation = "rested"
			instance.controller = player_id
			instance.flags["trial_completed"] = false
			var trial_event = GameEvent.create(state.next_event_id(), "CardMoved", player_id, {
				"card_id": card_id,
				"from": "deck",
				"to": "trial_zone",
				"reason": "setup_trial"
			})
			trial_event.created_by_command = command_id
			state.event_log.append(trial_event)
			events.append(trial_event)
		elif definition.is_city():
			player.deck.remove_card(card_id)
			player.city_zone.add_card(card_id)
			instance.zone = "city_zone"
			instance.position = {}
			instance.orientation = "active"
			instance.controller = player_id
			var city_event = GameEvent.create(state.next_event_id(), "CardMoved", player_id, {
				"card_id": card_id,
				"from": "deck",
				"to": "city_zone",
				"reason": "setup_city"
			})
			city_event.created_by_command = command_id
			state.event_log.append(city_event)
			events.append(city_event)
	return events

func _player_has_definition_in_deck(state: GameState, player_id: int, definition_id: String) -> bool:
	if player_id < 0 or player_id >= state.players.size():
		return false
	return not _find_player_card_by_definition_in_zone(state.get_player(player_id).deck.cards, state, definition_id).is_empty()

func _find_player_card_by_definition_in_zone(zone_cards: Array, state: GameState, definition_id: String) -> String:
	for raw_card_id in zone_cards:
		var card_id = str(raw_card_id)
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return card_id
	return ""

func _apply_master_game_start_effects(state: GameState, player_id: int, command_id: String) -> Array:
	if player_id < 0 or player_id >= state.players.size():
		return []
	var player = state.get_player(player_id)
	if player.master_definition_id == "suncity_s01_02m1":
		return _move_deck_definition_to_grave(state, player_id, "suncity_s01_02m2", command_id)
	return []

func _master_replaces_draw_phase_with_mill(state: GameState, player_id: int) -> bool:
	if player_id < 0 or player_id >= state.players.size():
		return false
	return state.get_player(player_id).master_definition_id == "asgard_s01_03m1"

func _request_valkyrie_first_turn_draw_replacement(state: GameState, command_id: String) -> Array:
	if state.turn_number != 1 or state.active_player < 0 or state.active_player >= state.players.size():
		return []
	if state.get_player(state.active_player).master_definition_id != "asgard_s01_03m1":
		return []
	return _request_option_choice(state, state.active_player, [
		{"id": "yes", "label": "发动", "accent": true},
		{"id": "no", "label": "不发动", "accent": false}
	], "瓦尔基里：是否发动规则效果？", "valkyrie_first_turn_draw_replacement", {}, command_id)

func _register_builtin_definitions(state: GameState) -> void:
	state.register_definition(CardDefinition.from_dict({
		"id": "sys_morale",
		"name": "澹皵",
		"type": "morale",
		"cost": 0,
		"power": 0,
		"hp": 0,
		"text": "system resource card"
	}))
	state.register_definition(CardDefinition.from_dict({
		"id": "sys_calamity_embers",
		"name": "暴怒之罪",
		"type": "calamity",
		"text": "对所有主宰造成1点非致命伤害。双方军团进攻时必须优先选择进攻范围内的对方军团作为进攻目标。"
	}))
	state.register_definition(CardDefinition.from_dict({
		"id": "sys_calamity_silence",
		"name": "腐秽大地",
		"type": "calamity",
		"text": "将所有后排军团置入所有者墓地。后排无法放置军团。打出反击战术无需消耗费用。"
	}))
	state.register_definition(CardDefinition.from_dict({
		"id": "sys_calamity_annihilation",
		"name": "最终天灾 湮灭",
		"type": "calamity",
		"text": "回合开始时，对所有主宰造成1点非致命伤害。最终天灾，天灾值锁定为0。"
	}))

func _build_deck(state: GameState, player_id: int, definition_ids: Array) -> void:
	var player = state.get_player(player_id)
	for definition_id in definition_ids:
		var card_id = state.create_instance(str(definition_id), player_id)
		player.deck.add_card(card_id)
		state.card_instances[card_id].zone = "deck"

func _build_cost_deck(state: GameState, player_id: int, count: int) -> void:
	var player = state.get_player(player_id)
	for _i in range(count):
		var card_id = state.create_instance("sys_morale", player_id)
		player.cost_deck.add_card(card_id)
		state.card_instances[card_id].zone = "cost_deck"

func _build_calamity_deck(state: GameState, options: Dictionary = {}) -> void:
	var requested_deck = options.get("calamity_deck", [])
	var resolved_deck: Array[String] = []
	if requested_deck is Array:
		for raw_definition_id in requested_deck:
			var definition_id := str(raw_definition_id).strip_edges()
			if definition_id.is_empty():
				continue
			if not state.card_definitions.has(definition_id):
				continue
			resolved_deck.append(definition_id)
	if resolved_deck.is_empty():
		if _rules_bool(state, "calamity_random_three_plus_annihilation", false):
			var pool: Array[String] = []
			for definition_id in state.card_definitions.keys():
				var candidate_id := str(definition_id)
				if candidate_id == "sys_calamity_annihilation":
					continue
				var definition = state.card_definitions.get(candidate_id)
				if definition == null or not definition.is_calamity():
					continue
				pool.append(candidate_id)
			pool.shuffle()
			for index in range(min(3, pool.size())):
				resolved_deck.append(pool[index])
			resolved_deck.append("sys_calamity_annihilation")
		else:
			resolved_deck = [
				"sys_calamity_embers",
				"sys_calamity_silence"
			]
	state.calamity_deck = resolved_deck

func _validate_play_card(state: GameState, command: GameCommand) -> Dictionary:
	var card_id = str(command.payload.get("card_id", ""))
	var row = str(command.payload.get("row", "front"))
	var col = int(command.payload.get("col", -1))
	var requested_effect_id = str(command.payload.get("effect_id", ""))
	var selected_play_option_id = str(command.payload.get("play_option_id", ""))
	var player = state.get_player(command.player_id)
	if not player.hand.has_card(card_id):
		return _error("CARD_NOT_IN_HAND", "鎵嬬墝涓笉瀛樺湪璇ュ崱")
	var instance = state.card_instances[card_id]
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return _error("UNKNOWN_CARD_DEFINITION", "card definition is missing")
	if _is_world_upheaval_hand_legion_blocked(state, command.player_id, card_id):
		return _error("WORLD_UPHEAVAL_TOP_TROOP_TYPE_BLOCK", "cannot play a hand legion with the same troop type as the top card of your deck")
	if not definition.is_legion() and not definition.is_artifact() and not definition.is_tactic() and not definition.is_counter_tactic():
		return _error("UNSUPPORTED_CARD_TYPE", "only legion, artifact, tactic and counter_tactic cards are supported")
	var available_play_options = _get_available_play_options(state, card_id)
	var selected_play_option = _find_selected_play_option(available_play_options, selected_play_option_id)
	if selected_play_option_id.is_empty():
		selected_play_option = _auto_selected_play_option(available_play_options)
	if not available_play_options.is_empty() and selected_play_option_id.is_empty() and selected_play_option.is_empty():
		return _error("PLAY_OPTION_REQUIRED", "play option selection required", {
			"card_id": card_id,
			"options": available_play_options
		})
	if not selected_play_option_id.is_empty() and selected_play_option.is_empty():
		return _error("UNKNOWN_PLAY_OPTION", "unknown play option")
	var resolved_play_option = _resolved_play_option_for_payload(selected_play_option, command.payload)
	var play_option_check = _validate_play_option_payload(state, command.player_id, card_id, selected_play_option, command.payload)
	if not play_option_check.get("ok", false):
		return play_option_check
	var hand_response_effect = _find_selected_hand_response_effect(definition, requested_effect_id)
	if not hand_response_effect.is_empty() and row == "hand_response":
		if not _can_play_hand_response_legion(state, command.player_id, card_id, hand_response_effect):
			return _error("NO_PRIORITY_WINDOW", "hand response legions require a pending attack window")
		var pending_attack = state.pending_attack
		var pending_target_kind := str(pending_attack.get("target_kind", "card"))
		if pending_target_kind == "card":
			var defender_id = str(pending_attack.get("defender_id", ""))
			var defender = state.card_instances.get(defender_id)
			if defender == null or defender.controller != command.player_id:
				return _error("INVALID_EFFECT_TARGET", "hand response requires your unit to be under attack")
		elif pending_target_kind == "master":
			if int(pending_attack.get("target_player", -1)) != command.player_id:
				return _error("INVALID_EFFECT_TARGET", "hand response requires your master to be under attack")
		else:
			return _error("INVALID_EFFECT_TARGET", "unsupported pending attack target for hand response")
		var response_cost_check = _validate_effect_cost(state, command.player_id, hand_response_effect, {"hand_cards_after_source_leaves": player.hand.cards.size() - 1})
		if not response_cost_check.get("ok", false):
			return response_cost_check
		return {"ok": true}
	if MoraleActions.count_active_morale(state, command.player_id) < _effective_hand_play_cost(state, card_id, resolved_play_option, row):
		return _error("NOT_ENOUGH_MORALE", "澹皵涓嶈冻")
	if definition.is_counter_tactic():
		if _is_counter_tactic_disabled_this_turn(state, card_id):
			return _error("COUNTER_TACTIC_DISABLED", "this counter tactic cannot be activated this turn")
		var response_effect = _find_selected_tactic_effect(definition, requested_effect_id)
		var can_cast_from_hand_in_response = not response_effect.is_empty() and bool(response_effect.get("can_activate_on_stack", false))
		if _counter_tactics_require_set(state) and row == "back":
			if not state.stack.is_empty() or not state.pending_attack.is_empty():
				return _error("PRIORITY_WINDOW_OPEN", "counter tactics can only be set during your main action window")
			if command.player_id != state.active_player:
				return _error("NOT_ACTIVE_PLAYER", "only active player can set counter tactics")
			var slot = player.get_slot(row, col)
			if slot == null:
				return _error("INVALID_SLOT", "target slot does not exist")
			if not _can_replace_face_down_cover_card(state, command.player_id, row, col) and not slot.occupant.is_empty():
				return _error("SLOT_OCCUPIED", "target slot is occupied")
			return {"ok": true}
		if _counter_tactics_require_set(state) and row == "front":
			return _error("INVALID_ZONE", "counter tactics can only be set in the back row")
		if state.stack.is_empty() and state.pending_attack.is_empty():
			return _error("NO_PRIORITY_WINDOW", "counter tactics require a stack item or pending attack")
		if command.player_id != state.priority_player:
			return _error("NOT_PRIORITY_PLAYER", "it is not this player's priority")
		if _counter_tactics_require_set(state) and not can_cast_from_hand_in_response:
			return _error("COUNTER_TACTIC_NOT_SET", "counter tactics must be set before they can respond")
		if row != "counter_tactic":
			return _error("INVALID_ZONE", "counter tactics must be played through counter_tactic cast entry")
		if response_effect.is_empty():
			return _error("UNKNOWN_EFFECT", "counter tactics require an activated or triggered effect")
		var response_target_check = _validate_effect_targets(state, command, response_effect)
		if not response_target_check.get("ok", false):
			return response_target_check
		var remaining_hand_after_cast = player.hand.cards.size() - 1
		var response_availability_check = _validate_effect_availability(state, command.player_id, card_id, response_effect, {"hand_cards_after_source_leaves": remaining_hand_after_cast})
		if not response_availability_check.get("ok", false):
			return response_availability_check
		var response_cost_check = _validate_effect_cost(state, command.player_id, response_effect, {"hand_cards_after_source_leaves": remaining_hand_after_cast})
		if not response_cost_check.get("ok", false):
			return response_cost_check
		if not _additional_stack_effects_available_for_source_effect(state, command.player_id, card_id, response_effect):
			return _error("ADDITIONAL_EFFECT_UNAVAILABLE", "an additional stack effect cannot currently be queued")
		return {"ok": true}
	if definition.is_tactic():
		if row != "tactic":
			return _error("INVALID_ZONE", "tactic cards must be played through tactic cast entry")
		var primary_effect = _find_selected_tactic_effect(definition, requested_effect_id)
		if primary_effect.is_empty():
			return _error("UNKNOWN_EFFECT", "tactic cards require an activated or triggered effect")
		var target_check = _validate_effect_targets(state, command, primary_effect)
		if not target_check.get("ok", false):
			return target_check
		var remaining_hand_after_cast = player.hand.cards.size() - 1
		var availability_check = _validate_effect_availability(state, command.player_id, card_id, primary_effect, {"hand_cards_after_source_leaves": remaining_hand_after_cast})
		if not availability_check.get("ok", false):
			return availability_check
		var cost_check = _validate_effect_cost(state, command.player_id, primary_effect, {"hand_cards_after_source_leaves": remaining_hand_after_cast})
		if not cost_check.get("ok", false):
			return cost_check
		if not _additional_stack_effects_available_for_source_effect(state, command.player_id, card_id, primary_effect):
			return _error("ADDITIONAL_EFFECT_UNAVAILABLE", "an additional stack effect cannot currently be queued")
		return {"ok": true}
	if definition.is_artifact():
		if _player_has_active_artifact_definition(state, command.player_id, "asgard_s02_0305") or _player_has_active_artifact_definition(state, command.player_id, "suncity_s02_0205"):
			return _error("ARTIFACT_PLAY_LOCKED", "current artifact prevents playing artifacts from hand")
		if row != "artifact":
			return _error("INVALID_ZONE", "artifact cards must be played to artifact zone")
		return {"ok": true}
	if row != "front" and row != "back":
		return _error("INVALID_ROW", "浠呮敮鎸佸墠鎺掓垨鍚庢帓")
	var host_player_id = _requested_play_host_player(state, command.player_id, resolved_play_option, command.payload)
	var slot = state.get_player(host_player_id).get_slot(row, col)
	if slot == null:
		return _error("INVALID_SLOT", "target slot does not exist")
	if _is_olympus_promotion_play_option(selected_play_option):
		var promotion_validation = _validate_play_option_payload(state, command.player_id, card_id, selected_play_option, command.payload)
		if not promotion_validation.get("ok", false):
			return promotion_validation
	elif not _can_replace_face_down_cover_card(state, host_player_id, row, col) and not slot.occupant.is_empty():
		return _error("SLOT_OCCUPIED", "鐩爣鏍煎瓙宸叉湁鍐涘洟")
	if row == "back" and _is_back_row_blocked_by_calamity(state) and not definition.is_counter_tactic():
		return _error("BACK_ROW_BLOCKED", "current calamity blocks back-row deployment")
	return {"ok": true}


func _can_replace_face_down_cover_card(state: GameState, player_id: int, row: String, col: int) -> bool:
	var player = state.get_player(player_id)
	var slot = player.get_slot(row, col)
	if slot == null or slot.occupant.is_empty():
		return false
	var covered_instance = state.card_instances.get(slot.occupant)
	if covered_instance == null or covered_instance.controller != player_id:
		return false
	if str(covered_instance.face) != "face_down":
		return false
	var covered_definition = state.get_definition(covered_instance.definition_id)
	return covered_definition != null and covered_definition.is_counter_tactic()


func _replace_face_down_cover_card_if_needed(state: GameState, player_id: int, row: String, col: int, command_id: String) -> Array:
	if not _can_replace_face_down_cover_card(state, player_id, row, col):
		return []
	return ZoneActions.move_battlefield_to_grave(state, player_id, row, col, command_id, {"emit_died": false})


func _apply_play_card(state: GameState, command: GameCommand) -> Array:
	var events: Array = []
	var card_id = str(command.payload.get("card_id", ""))
	var row = str(command.payload.get("row", "front"))
	var col = int(command.payload.get("col", -1))
	var requested_effect_id = str(command.payload.get("effect_id", ""))
	var selected_play_option_id = str(command.payload.get("play_option_id", ""))
	var player = state.get_player(command.player_id)
	var instance = state.card_instances[card_id]
	var definition = state.get_definition(instance.definition_id)
	var available_play_options = _get_available_play_options(state, card_id)
	var selected_play_option = _find_selected_play_option(available_play_options, selected_play_option_id)
	if selected_play_option_id.is_empty():
		selected_play_option = _auto_selected_play_option(available_play_options)
	var hand_response_effect = _find_selected_hand_response_effect(definition, requested_effect_id)
	if not hand_response_effect.is_empty() and row == "hand_response":
		var response_event = GameEvent.create(state.next_event_id(), "HandResponsePlayed", command.player_id, {
			"card_id": card_id,
			"effect_id": str(hand_response_effect.get("id", ""))
		})
		response_event.created_by_command = command.command_id
		state.event_log.append(response_event)
		events.append(response_event)
		var hand_response_resolution: Dictionary = hand_response_effect.get("resolution", {}).duplicate(true)
		var hand_response_action := str(hand_response_resolution.get("action", ""))
		if hand_response_action == "counter_pending_attack":
			player.hand.remove_card(card_id)
			var discard_event = GameEvent.create(state.next_event_id(), "CardDiscarded", command.player_id, {
				"card_id": card_id,
				"from": "hand",
				"to": "grave"
			})
			discard_event.created_by_command = command.command_id
			state.event_log.append(discard_event)
			events.append(discard_event)
			events.append_array(ZoneActions.move_card_to_grave(state, card_id, "hand", command.command_id))
			return events + _counter_pending_attack(state, {
				"controller": command.player_id,
				"source_instance_id": card_id,
				"resolution": hand_response_resolution
			}, command.command_id)
		if hand_response_action == "deploy_source_from_hand_to_front_and_redirect_pending_attack":
			var front_slot_options = _front_battlefield_slot_options(state, command.player_id)
			if front_slot_options.is_empty():
				return events
			if front_slot_options.size() == 1:
				var slot = front_slot_options[0]
				events.append_array(_deploy_hand_response_card_to_front_and_redirect_pending_attack(state, command.player_id, card_id, str(slot.get("row", "front")), int(slot.get("col", -1)), command.command_id))
				return events
			events.append_array(_request_option_choice(state, command.player_id, front_slot_options, "选择登场位置", "hand_response_deploy_to_front_and_redirect_pending_attack", {
				"card_id": card_id,
				"hand_response_action": hand_response_action
			}, command.command_id))
			return events
		if hand_response_action == "suncity_siwa_hand_response":
			var siwa_front_slot_options = _front_battlefield_slot_options(state, command.player_id)
			if siwa_front_slot_options.is_empty():
				return events
			var siwa_slot = siwa_front_slot_options[0]
			events.append_array(_suncity_siwa_hand_response(state, command.player_id, card_id, str(siwa_slot.get("row", "front")), int(siwa_slot.get("col", -1)), command.command_id))
			return events
		return events + [_create_unimplemented_effect_event(state, {
			"controller": command.player_id,
			"source_instance_id": card_id,
			"resolution": hand_response_resolution
		}, hand_response_action, command.command_id)]
	var resolved_play_option = _resolved_play_option_for_payload(selected_play_option, command.payload)
	events.append_array(_apply_play_option_before_play(state, command.player_id, card_id, resolved_play_option, command.payload, command.command_id))
	if state.winner != -1:
		return events
	if definition.is_tactic():
		var pending_effect = _find_selected_tactic_effect(definition, requested_effect_id)
		if _effect_requires_play_card_discard_choice(pending_effect):
			var pending_targets = _build_effect_targets(command, pending_effect)
			return events + _request_play_card_effect_discard_choice(state, command.player_id, card_id, pending_effect, "tactic", pending_targets, command.command_id, {
				"row": row,
				"col": col,
				"play_option_id": selected_play_option_id
			})
	if definition.is_counter_tactic() and (not _counter_tactics_require_set(state) or row != "back"):
		var pending_response_effect = _find_selected_tactic_effect(definition, requested_effect_id)
		if _effect_requires_play_card_discard_choice(pending_response_effect):
			var pending_response_targets = _build_effect_targets(command, pending_response_effect)
			return events + _request_play_card_effect_discard_choice(state, command.player_id, card_id, pending_response_effect, "counter_tactic", pending_response_targets, command.command_id, {
				"row": row,
				"col": col,
				"play_option_id": selected_play_option_id
			})
	events.append_array(MoraleActions.consume_morale(state, command.player_id, _effective_hand_play_cost(state, card_id, resolved_play_option, row), command.command_id))
	if definition.is_tactic():
		var free_tactic_state = player.flags.get("tianting_next_tactic_free", {})
		if free_tactic_state is Dictionary and int(free_tactic_state.get("turn", -1)) == state.turn_number:
			player.flags.erase("tianting_next_tactic_free")
	player.hand.remove_card(card_id)
	if definition.is_counter_tactic():
		if _counter_tactics_require_set(state) and row == "back":
			var slot = player.get_slot(row, col)
			events.append_array(_replace_face_down_cover_card_if_needed(state, command.player_id, row, col, command.command_id))
			slot.occupant = card_id
			instance.zone = "battle_%s" % row
			instance.position = {"row": row, "col": col}
			instance.orientation = "active"
			instance.face = "face_down"
		else:
			instance.zone = "stack_pending"
			instance.position = {}
			instance.orientation = "active"
			var response_effect = _find_selected_tactic_effect(definition, requested_effect_id)
			_mark_effect_as_used(state, command.player_id, card_id, response_effect)
			var response_targets = _build_effect_targets(command, response_effect)
			var response_cost_result = _pay_effect_costs(state, command.player_id, response_effect, command.command_id)
			var response_paid_costs = response_cost_result.get("paid_costs", [])
			events.append_array(response_cost_result.get("events", []))
			events.append_array(_put_effect_on_stack(state, command.player_id, card_id, response_effect, "counter_tactic", response_paid_costs, 0, response_targets, command.command_id))
			events.append_array(_queue_additional_stack_effects(state, command.player_id, card_id, response_effect, command.command_id))
	elif definition.is_tactic():
		instance.zone = "stack_pending"
		instance.position = {}
		instance.orientation = "active"
		var effect = _find_selected_tactic_effect(definition, requested_effect_id)
		_remember_last_active_tactic(state, command.player_id, card_id, effect)
		_mark_effect_as_used(state, command.player_id, card_id, effect)
		var targets = _build_effect_targets(command, effect)
		var effect_cost_result = _pay_effect_costs(state, command.player_id, effect, command.command_id)
		var paid_costs = effect_cost_result.get("paid_costs", [])
		events.append_array(effect_cost_result.get("events", []))
		events.append_array(_put_effect_on_stack(state, command.player_id, card_id, effect, "tactic", paid_costs, 0, targets, command.command_id))
		events.append_array(_queue_additional_stack_effects(state, command.player_id, card_id, effect, command.command_id))
	elif definition.is_artifact():
		events.append_array(_replace_existing_artifacts_for_definition(state, command.player_id, definition, command.command_id))
		player.artifact_zone.add_card(card_id)
		instance.zone = "artifact_zone"
		instance.position = {}
		instance.orientation = "active"
	else:
		var host_player_id = _requested_play_host_player(state, command.player_id, resolved_play_option, command.payload)
		var slot = state.get_player(host_player_id).get_slot(row, col)
		if _is_olympus_promotion_play_option(selected_play_option):
			events.append_array(_deploy_olympus_promotion_to_slot(state, command.player_id, card_id, row, col, selected_play_option, command.command_id))
		else:
			events.append_array(_replace_face_down_cover_card_if_needed(state, host_player_id, row, col, command.command_id))
			slot.occupant = card_id
			instance.zone = "battle_%s" % row
			instance.position = {"row": row, "col": col}
			instance.orientation = str(resolved_play_option.get("deployment_orientation", "active")) if str(resolved_play_option.get("deployment_orientation", "active")) == "rested" else "active"
			instance.controller = host_player_id
			if bool(resolved_play_option.get("transfer_owner_to_host_player", false)):
				instance.owner = host_player_id
			_consume_next_played_legion_cost_modifier(state, command.player_id, card_id)
			_consume_suncity_next_calamity_discount(state, command.player_id, card_id)
			events.append_array(_apply_next_played_legion_keyword(state, command.player_id, card_id, command.command_id))
	instance.entered_turn = state.turn_number
	if instance.zone.begins_with("battle_"):
		var battlefield_controller = int(instance.controller)
		var entered_payload := {
			"card_id": card_id,
			"row": row,
			"col": col,
			"from": "hand",
			"play_option_id": selected_play_option_id
		}
		if battlefield_controller != command.player_id:
			entered_payload["host_player"] = battlefield_controller
			entered_payload["played_by"] = command.player_id
		var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", battlefield_controller, entered_payload)
		entered_event.created_by_command = command.command_id
		state.event_log.append(entered_event)
		events.append(entered_event)
		events.append_array(_apply_master_entry_effects(state, battlefield_controller, card_id, command.command_id))
	var played_payload := {
		"card_id": card_id,
		"row": row,
		"col": col,
		"zone": instance.zone,
		"play_option_id": selected_play_option_id
	}
	if instance.zone.begins_with("battle_") and int(instance.controller) != command.player_id:
		played_payload["host_player"] = int(instance.controller)
		played_payload["played_by"] = command.player_id
	var event_player = int(instance.controller) if instance.zone.begins_with("battle_") else command.player_id
	var event = GameEvent.create(state.next_event_id(), "CardPlayed", event_player, played_payload)
	event.created_by_command = command.command_id
	state.event_log.append(event)
	events.append(event)
	events.append_array(_apply_legion_entry_calamity(state, instance, definition, command.command_id))
	events.append_array(_apply_immediate_self_entry_effects(state, event_player, card_id, command.command_id))
	return events

func _replace_existing_artifact(state: GameState, player_id: int, command_id: String) -> Array:
	var player = state.get_player(player_id)
	if player.artifact_zone.cards.is_empty():
		return []
	for artifact_id in player.artifact_zone.cards:
		if _artifact_card_ignores_limit(state, str(artifact_id)):
			continue
		return _send_artifact_to_grave(state, player_id, str(artifact_id), command_id)
	return []

func _validate_attack(state: GameState, command: GameCommand) -> Dictionary:
	var attacker_id = str(command.payload.get("attacker_id", ""))
	var target_kind = str(command.payload.get("target_kind", "card"))
	var defender_id = str(command.payload.get("defender_id", ""))
	var target_player = int(command.payload.get("target_player", 1 - command.player_id))
	var blocker_id = str(command.payload.get("blocker_id", ""))
	var supporter_id = str(command.payload.get("supporter_id", ""))
	if target_kind != "master" and defender_id.is_empty() and command.payload.has("target_player"):
		target_kind = "master"
	if not state.card_instances.has(attacker_id):
		return _error("UNKNOWN_CARD", "鏀诲嚮鑰呬笉瀛樺湪")
	var attacker = state.card_instances[attacker_id]
	if not _instance_counts_as_legion(state, attacker):
		return _error("NOT_LEGION", "only legion cards can attack")
	if attacker.controller != command.player_id:
		return _error("NOT_CONTROLLER", "鏀诲嚮鑰呬笉鍙椾綘鎺у埗")
	if _has_attack_keyword(state, attacker_id, "cannot_attack"):
		return _error("CANNOT_ATTACK", "attacker cannot declare attacks")
	if _is_concealed(state, attacker_id):
		return _error("CONCEALED", "concealed units must be revealed before attacking")
	var can_ignore_summoning_sickness_for_master = target_kind == "master" and int(attacker.flags.get("can_attack_master_until_turn_end_turn", -1)) == state.turn_number
	var can_ignore_summoning_sickness_for_legions = target_kind != "master" and int(attacker.flags.get("can_attack_legions_until_turn_end_turn", -1)) == state.turn_number
	if attacker.entered_turn == state.turn_number and not _has_attack_keyword(state, attacker_id, "charge") and not can_ignore_summoning_sickness_for_master and not can_ignore_summoning_sickness_for_legions:
		return _error("SUMMONING_SICK", "attacker cannot attack on the turn it entered")
	if attacker.has_attacked_this_turn:
		return _error("ALREADY_ATTACKED", "attacker already attacked this turn")
	if attacker.orientation != "active":
		return _error("ATTACKER_NOT_READY", "attacker is not active")
	if not attacker.zone.begins_with("battle_"):
		return _error("NOT_ON_BATTLEFIELD", "attacker must be on battlefield")
	if not blocker_id.is_empty() and not supporter_id.is_empty():
		return _error("MULTIPLE_DEFENSE_CHOICES", "涓€娆¤繘鏀讳笉鑳藉悓鏃跺０鏄庢姷鎸″拰鏀彺")
	if target_kind == "master":
		if bool(state.get_player(target_player).flags.get("master_cannot_be_attacked_until_next_own_turn_start", false)):
			return _error("MASTER_ATTACK_FORBIDDEN", "target master cannot be attacked right now")
		if _has_required_taunt_target(state, attacker_id):
			return _error("TAUNT_REQUIRED", "a taunt unit must be attacked first")
		if str(attacker.definition_id) == "suncity_s01_0212" and state.get_player(command.player_id).master_definition_id == "suncity_s02_02m1":
			return _error("MASTER_ATTACK_FORBIDDEN", "tomb guards cannot attack master while Nephthys leads them")
		if state.current_calamity == "calamity_s02_ds02" and get_card_power(state, attacker_id) <= 2000:
			return _error("MASTER_ATTACK_BLOCKED_BY_CALAMITY", "low-power legions cannot attack master under current calamity")
		var yingzheng_blocks := false
		for slot in state.get_player(target_player).battle_front:
			var front_id = str(slot.occupant)
			if front_id.is_empty():
				continue
			var front_instance = state.card_instances.get(front_id)
			if front_instance != null and str(front_instance.definition_id) == "tianting_s02_0101":
				yingzheng_blocks = true
				break
		if yingzheng_blocks and get_card_power(state, attacker_id) <= 2000:
			return _error("MASTER_ATTACK_BLOCKED_BY_YINGZHENG", "low-power legions cannot attack master while Yingzheng is on defender front row")
		var achilles_blocks := false
		for slot in state.get_player(target_player).battle_front:
			var front_id = str(slot.occupant)
			if front_id.is_empty():
				continue
			var front_instance = state.card_instances.get(front_id)
			if front_instance != null and str(front_instance.definition_id) == "olympus_s02_0504":
				achilles_blocks = true
				break
		if achilles_blocks and get_card_power(state, attacker_id) <= 2000:
			return _error("MASTER_ATTACK_BLOCKED_BY_ACHILLES", "low-power legions cannot attack master while Achilles is on defender front row")
		if not supporter_id.is_empty():
			return _error("SUPPORT_NOT_ALLOWED", "support is not allowed when attacking master")
		if target_player == command.player_id:
			return _error("INVALID_TARGET", "涓嶈兘鏀诲嚮宸辨柟涓诲")
		if str(attacker.position.get("row", "")) != "front" and not _can_attack_master_from_back_row_this_turn(state, attacker_id, command.player_id):
			return _error("MASTER_FRONT_ONLY", "only front-row legions can attack master")
		if not blocker_id.is_empty():
			var blockers = get_legal_blockers(state, target_player, attacker_id)
			if not blockers.has(blocker_id):
				return _error("INVALID_BLOCKER", "blocker is not legal")
		return {"ok": true}
	if not state.card_instances.has(defender_id):
		return _error("UNKNOWN_CARD", "闃插畧鑰呬笉瀛樺湪")
	if _has_required_taunt_target(state, attacker_id) and not _is_taunt_unit(state, defender_id):
		return _error("TAUNT_REQUIRED", "a taunt unit must be attacked first")
	var defender = state.card_instances[defender_id]
	if not _instance_counts_as_legion(state, defender):
		return _error("NOT_LEGION", "only legion cards can be attacked")
	if not defender.zone.begins_with("battle_"):
		return _error("NOT_ON_BATTLEFIELD", "defender must be on battlefield")
	if _is_concealed(state, defender_id):
		return _error("INVALID_TARGET", "concealed units cannot be attacked")
	if _defender_cannot_be_attacked(state, defender_id):
		return _error("INVALID_TARGET", "defender cannot be attacked")
	if attacker.controller == defender.controller:
		return _error("INVALID_TARGET", "涓嶈兘鏀诲嚮宸辨柟鍗曚綅")
	if state.current_calamity == "calamity_s02_ds02":
		var defender_row = str(defender.position.get("row", ""))
		if defender_row == "front" and defender.orientation == "active":
			return _error("ACTIVE_FRONT_ROW_BLOCKED_BY_CALAMITY", "active front-row legions cannot be attacked under current calamity")
	if _attack_requires_ranged(state, attacker_id, defender_id) and not _has_ranged_attack(state, attacker_id):
		return _error("UNSUPPORTED_RANGE", "褰撳墠浠呮敮鎸佸悓鎺掑熀纭€鏀诲嚮")
	if _attack_requires_ranged(state, attacker_id, defender_id) and not _is_ranged_attack_geometry_allowed(state, attacker_id, defender_id):
		return _error("RANGED_TARGET_NOT_ALLOWED", "back-row ranged attacks cannot target enemy back row")
	if _attack_requires_ranged(state, attacker_id, defender_id) and _has_attack_keyword(state, defender_id, "cannot_be_attacked_by_ranged"):
		return _error("RANGED_ATTACK_FORBIDDEN", "defender cannot be attacked by ranged attacks")
	if not blocker_id.is_empty():
		var blockers = get_legal_blockers(state, defender.controller, attacker_id, defender_id)
		if not blockers.has(blocker_id):
			return _error("INVALID_BLOCKER", "blocker is not legal")
	if not supporter_id.is_empty():
		var supporters = get_legal_supporters(state, defender_id, attacker_id)
		if not supporters.has(supporter_id):
			return _error("INVALID_SUPPORTER", "鎸囧畾鐨勬敮鎻磋€呬笉鍚堟硶")
	return {"ok": true}

func _apply_attack(state: GameState, command: GameCommand) -> Array:
	var attacker_id = str(command.payload.get("attacker_id", ""))
	var target_kind = str(command.payload.get("target_kind", "card"))
	var defender_id = str(command.payload.get("defender_id", ""))
	var target_player = int(command.payload.get("target_player", 1 - command.player_id))
	var blocker_id = str(command.payload.get("blocker_id", ""))
	var supporter_id = str(command.payload.get("supporter_id", ""))
	var master_guard_card_ids = _payload_string_array(command.payload.get("master_guard_card_ids", []))
	if target_kind != "master" and defender_id.is_empty() and command.payload.has("target_player"):
		target_kind = "master"
	var events: Array = []
	var attack_payload = {"attacker_id": attacker_id, "target_kind": target_kind}
	if target_kind == "master":
		attack_payload["target_player"] = target_player
	else:
		attack_payload["defender_id"] = defender_id
	if not blocker_id.is_empty():
		attack_payload["blocker_id"] = blocker_id
	if not supporter_id.is_empty():
		attack_payload["supporter_id"] = supporter_id
	if not master_guard_card_ids.is_empty():
		attack_payload["master_guard_card_ids"] = master_guard_card_ids
	var thunder_result := _maybe_resolve_thunder_wrath_attack_roll(state, attack_payload, command.player_id, command.command_id)
	attack_payload = thunder_result.get("attack", attack_payload)
	events.append_array(thunder_result.get("events", []))
	if bool(thunder_result.get("canceled", false)):
		return events
	var attack_event = GameEvent.create(state.next_event_id(), "AttackDeclared", command.player_id, attack_payload)
	attack_event.created_by_command = command.command_id
	state.event_log.append(attack_event)
	attack_payload["response_window_opened"] = false
	state.pending_attack = attack_payload.duplicate(true)
	state.priority_player = 1 - command.player_id
	state.priority_pass_count = 0
	events.append(attack_event)
	if _has_attack_keyword(state, attacker_id, "shock") and target_kind == "card":
		events.append_array(_apply_shock_on_attack_declared(state, attacker_id, defender_id, command.command_id))
	return events

func _validate_move_legion(state: GameState, command: GameCommand) -> Dictionary:
	if not _rules_bool(state, "manual_legion_move_enabled", false):
		return _error("MOVE_NOT_ENABLED", "manual legion move is not enabled for this ruleset")
	var card_id = str(command.payload.get("card_id", ""))
	var target_row = str(command.payload.get("row", ""))
	var target_col = int(command.payload.get("col", -1))
	var legal_targets = get_legal_move_targets(state, card_id)
	if legal_targets.is_empty():
		return _error("MOVE_NOT_ALLOWED", "the selected legion cannot move right now")
	for target in legal_targets:
		if str(target.get("row", "")) == target_row and int(target.get("col", -1)) == target_col:
			return {"ok": true}
	return _error("INVALID_MOVE_TARGET", "the selected target slot is not a legal move destination")

func _validate_choose_defense(state: GameState, command: GameCommand) -> Dictionary:
	if state.pending_attack.is_empty():
		return _error("NO_PENDING_ATTACK", "there is no pending attack to defend against")
	if command.player_id != state.priority_player:
		return _error("NOT_PRIORITY_PLAYER", "it is not this player's priority")
	if _pending_attack_has_defense_selection(state.pending_attack):
		return _error("DEFENSE_ALREADY_CHOSEN", "defense has already been chosen for this pending attack")
	var defense_proposals = _build_pending_attack_defense_proposals(state, command.player_id)
	if defense_proposals.is_empty():
		return _error("NO_DEFENSE_OPTIONS", "there are no available defense options")
	var blocker_id = str(command.payload.get("blocker_id", ""))
	var supporter_id = str(command.payload.get("supporter_id", ""))
	var master_guard_card_ids = _payload_string_array(command.payload.get("master_guard_card_ids", []))
	for action in defense_proposals:
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("blocker_id", "")) == blocker_id and str(payload.get("supporter_id", "")) == supporter_id and _same_string_sets(_payload_string_array(payload.get("master_guard_card_ids", [])), master_guard_card_ids):
			return {"ok": true}
	return _error("INVALID_DEFENSE_OPTION", "the selected defense option is not legal")

func _apply_move_legion(state: GameState, command: GameCommand) -> Array:
	var card_id = str(command.payload.get("card_id", ""))
	var target_row = str(command.payload.get("row", ""))
	var target_col = int(command.payload.get("col", -1))
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var from_row = str(instance.position.get("row", ""))
	var from_col = int(instance.position.get("col", -1))
	var player = state.get_player(command.player_id)
	var current_slot = player.get_slot(from_row, from_col)
	var destination_slot = player.get_slot(target_row, target_col)
	if current_slot == null or destination_slot == null:
		return []
	var swapped_card_id := str(destination_slot.occupant)
	var swapped_instance = state.card_instances.get(swapped_card_id, null)
	var free_move_effect = _find_free_move_effect_for_manual_move(state, command.player_id, card_id)
	var morale_cost := 1
	if not free_move_effect.is_empty():
		_mark_effect_as_used(state, command.player_id, card_id, free_move_effect)
		morale_cost = 0
	elif _has_cavalry_free_move_available(state, card_id):
		morale_cost = 0
	elif _controller_has_rested_hippolyta_vertical_free_move(state, command.player_id) and target_row != from_row and target_col == from_col:
		morale_cost = 0
	var events: Array = []
	if morale_cost > 0:
		events = MoraleActions.consume_morale(state, command.player_id, morale_cost, command.command_id)
	current_slot.occupant = ""
	if not swapped_card_id.is_empty():
		current_slot.occupant = swapped_card_id
		if swapped_instance != null:
			swapped_instance.zone = "battle_%s" % from_row
			swapped_instance.position = {"row": from_row, "col": from_col}
	destination_slot.occupant = card_id
	instance.zone = "battle_%s" % target_row
	instance.position = {"row": target_row, "col": target_col}
	var move_payload = {
		"card_id": card_id,
		"from_row": from_row,
		"from_col": from_col,
		"to_row": target_row,
		"to_col": target_col,
		"manual": true,
		"morale_cost": morale_cost
	}
	if not free_move_effect.is_empty():
		move_payload["free_move_effect_id"] = str(free_move_effect.get("id", ""))
	if not swapped_card_id.is_empty():
		move_payload["swapped_with_card_id"] = swapped_card_id
		move_payload["swap_from_row"] = target_row
		move_payload["swap_from_col"] = target_col
		move_payload["swap_to_row"] = from_row
		move_payload["swap_to_col"] = from_col
	var move_event = GameEvent.create(state.next_event_id(), "CardMoved", command.player_id, move_payload)
	move_event.created_by_command = command.command_id
	state.event_log.append(move_event)
	_mark_card_as_moved_this_turn(state, card_id)
	events.append(move_event)
	events.append_array(_apply_master_move_effects(state, move_event, command.command_id))
	return events

func _apply_choose_defense(state: GameState, command: GameCommand) -> Array:
	if state.pending_attack.is_empty():
		return []
	var attack = state.pending_attack.duplicate(true)
	attack["response_window_opened"] = true
	attack["blocker_id"] = str(command.payload.get("blocker_id", ""))
	attack["supporter_id"] = str(command.payload.get("supporter_id", ""))
	attack["extra_discard_card_id"] = str(command.payload.get("extra_discard_card_id", ""))
	attack["master_guard_card_ids"] = _payload_string_array(command.payload.get("master_guard_card_ids", []))
	state.pending_attack = attack
	state.priority_pass_count = 0
	state.priority_player = 1 - command.player_id
	return []

func _advance_phase(state: GameState, command: GameCommand) -> Array:
	var events: Array = []
	if state.phase == "end":
		events.append_array(_discard_turn_end_marked_legions(state, command.command_id))
		events.append_array(_restore_battlefield_legions(state, command.command_id))
		if not state.calamity_value_locked:
			state.calamity_value += 1
			var calamity_event = GameEvent.create(state.next_event_id(), "CalamityValueChanged", state.active_player, {"value": state.calamity_value})
			calamity_event.created_by_command = command.command_id
			state.event_log.append(calamity_event)
			events.append(calamity_event)
	var phase_info = PhaseMachine.get_next_phase_info(state.phase)
	var previous_phase = String(phase_info.from)
	var next_phase = String(phase_info.to)
	if phase_info.passes_turn:
		_expire_timed_modifiers_for_player(state, state.active_player)
		_begin_next_turn(state)
	state.phase = next_phase
	var phase_event = GameEvent.create(state.next_event_id(), "PhaseChanged", state.active_player, {"from": previous_phase, "to": next_phase, "turn_number": state.turn_number})
	phase_event.created_by_command = command.command_id
	state.event_log.append(phase_event)
	events.append(phase_event)
	events.append_array(_on_enter_phase(state, command.command_id))
	return events

func _discard_turn_end_marked_legions(state: GameState, command_id: String) -> Array:
	var events: Array = []
	for card_id in _get_battlefield_card_ids(state):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var row = str(instance.position.get("row", ""))
		var col = int(instance.position.get("col", -1))
		if int(instance.flags.get("foreign_battlefield_discard_on_player_turn_end", -1)) == state.active_player:
			var host_player_id = _find_battlefield_host_player_for_card(state, card_id)
			if host_player_id >= 0 and not row.is_empty() and col >= 0:
				var draw_owner = bool(instance.flags.get("foreign_battlefield_draw_owner_on_leave", false))
				instance.flags.erase("foreign_battlefield_discard_on_player_turn_end")
				instance.flags.erase("foreign_battlefield_draw_owner_on_leave")
				instance.flags.erase("foreign_battlefield_owner_player")
				instance.flags.erase("foreign_battlefield_host_player")
				events.append_array(ZoneActions.move_battlefield_to_grave(state, host_player_id, row, col, command_id, {"emit_died": false}))
				if draw_owner:
					events.append_array(DrawActions.draw_cards(state, int(instance.owner), 1, command_id))
				continue
		if int(instance.flags.get("discard_at_turn_end_turn", -1)) != state.turn_number:
			continue
		if row.is_empty() or col < 0:
			continue
		events.append_array(ZoneActions.move_battlefield_to_grave(state, int(instance.controller), row, col, command_id))
	return events

func _find_battlefield_host_player_for_card(state: GameState, card_id: String) -> int:
	for player_id in range(state.players.size()):
		for row in ["front", "back"]:
			var slots = state.get_player(player_id).battle_front if row == "front" else state.get_player(player_id).battle_back
			for slot in slots:
				if str(slot.occupant) == card_id:
					return player_id
	return -1

func _error(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details.duplicate(true)}

func _deal_master_damage_from_attacker(state: GameState, attacker_id: String, target_player: int, command_id: String) -> Array:
	var attacker = state.card_instances[attacker_id]
	var damage = 1
	damage += _master_damage_bonus_for_attacker(state, attacker_id)
	var events = _deal_master_damage(state, target_player, damage, command_id, {
		"source_card_id": attacker_id,
		"source_kind": "attack"
	})
	attacker.has_attacked_this_turn = true
	attacker.orientation = "rested"
	return events

func _is_effect_like_source_kind(source_kind: String) -> bool:
	return source_kind == "effect" or source_kind == "play_option"

func _deal_master_damage(state: GameState, player_id: int, amount: int, command_id: String, options: Dictionary = {}) -> Array:
	var player = state.get_player(player_id)
	var applied_amount = amount
	if options.get("non_lethal", false):
		applied_amount = min(applied_amount, max(0, player.master_hp - 1))
	var replacement_result = _apply_master_damage_replacements(state, player_id, applied_amount, command_id, options)
	applied_amount = int(replacement_result.get("amount", applied_amount))
	var events: Array = replacement_result.get("events", [])
	if applied_amount <= 0:
		return events
	player.master_hp = max(0, player.master_hp - applied_amount)
	var event_payload = _merge_event_payload_options({
		"amount": applied_amount,
		"remaining_hp": player.master_hp
	}, options)
	var event = GameEvent.create(state.next_event_id(), "MasterDamaged", player_id, event_payload)
	event.created_by_command = command_id
	state.event_log.append(event)
	events.append(event)
	player.flags["master_damage_taken_this_turn_count"] = int(player.flags.get("master_damage_taken_this_turn_count", 0)) + 1
	player.flags["master_damage_taken_this_turn"] = int(player.flags.get("master_damage_taken_this_turn", 0)) + applied_amount
	if _is_effect_like_source_kind(str(options.get("source_kind", ""))):
		player.flags["master_effect_damage_taken_this_turn"] = int(player.flags.get("master_effect_damage_taken_this_turn", 0)) + applied_amount
	events.append_array(_check_immediate_loss(state, player_id, command_id))
	return events

func _check_immediate_loss(state: GameState, losing_player: int, command_id: String) -> Array:
	if state.winner != -1:
		return []
	if state.get_player(losing_player).master_hp > 0:
		return []
	state.winner = 1 - losing_player
	state.loss_reason = "master_hp_zero"
	var event = GameEvent.create(state.next_event_id(), "WinnerDecided", state.winner, {
		"winner": state.winner,
		"loser": losing_player,
		"reason": state.loss_reason
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _apply_master_damage_replacements(state: GameState, player_id: int, amount: int, command_id: String, options: Dictionary = {}) -> Dictionary:
	var events: Array = []
	if amount <= 0:
		return {"amount": amount, "events": events}
	if bool(options.get("suppress_triggers", false)) or str(options.get("source_kind", "")) == "calamity" or str(options.get("reason", "")) == "calamity":
		return {"amount": amount, "events": events}
	var player = state.get_player(player_id)
	var source_kind := str(options.get("source_kind", ""))
	var source_is_opponent := false
	var source_card_id := str(options.get("source_card_id", ""))
	if not source_card_id.is_empty():
		if _is_master_source_id(source_card_id):
			source_is_opponent = _master_player_from_source_id(source_card_id) == 1 - player_id
		elif _is_morale_source_id(source_card_id):
			source_is_opponent = _morale_player_from_source_id(source_card_id) == 1 - player_id
		else:
			var source_instance = state.card_instances.get(source_card_id)
			source_is_opponent = source_instance != null and int(source_instance.controller) == 1 - player_id
	if state.active_player != player_id \
			and _player_has_active_artifact_definition(state, player_id, "asgard_s02_0305") \
			and (source_kind == "attack" or _is_effect_like_source_kind(source_kind)) \
			and source_is_opponent:
		if int(player.flags.get("master_damage_taken_this_turn_count", 0)) == 0 and amount != 2:
			var andvaranot_event = GameEvent.create(state.next_event_id(), "ReplacementEffectApplied", player_id, {
				"source_id": "asgard_s02_0305",
				"effect_id": "andvaranot_first_damage_becomes_two",
				"event": "MasterWouldBeDamaged",
				"original_amount": amount,
				"replaced_amount": 2
			})
			andvaranot_event.created_by_command = command_id
			state.event_log.append(andvaranot_event)
			events.append(andvaranot_event)
			amount = 2
	for card_id in _get_trigger_source_ids(state):
		var instance = state.card_instances.get(card_id)
		if instance == null or instance.controller != player_id:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		for effect in definition.effects:
			if str(effect.get("kind", "")) != "replacement":
				continue
			if str(effect.get("event", "")) != "MasterWouldBeDamaged":
				continue
			if _replacement_effect_is_used(instance, str(effect.get("id", ""))):
				continue
			var action = str(effect.get("resolution", {}).get("action", ""))
			if action == "prevent_lethal_master_damage":
				if amount < player.master_hp:
					continue
				var prevented_to = max(1, int(effect.get("resolution", {}).get("prevent_to_hp", 1)))
				var new_amount = max(0, player.master_hp - prevented_to)
				if new_amount == amount:
					continue
				if bool(effect.get("consume_on_use", true)):
					instance.flags["replacement_used_%s" % str(effect.get("id", ""))] = true
				var replacement_event = GameEvent.create(state.next_event_id(), "ReplacementEffectApplied", player_id, {
					"source_id": card_id,
					"effect_id": str(effect.get("id", "")),
					"event": "MasterWouldBeDamaged",
					"original_amount": amount,
					"replaced_amount": new_amount,
					"remaining_hp_after_replacement": player.master_hp - new_amount
				})
				replacement_event.created_by_command = command_id
				state.event_log.append(replacement_event)
				events.append(replacement_event)
				return {"amount": new_amount, "events": events}
	return {"amount": amount, "events": events}

func _replacement_effect_is_used(instance, effect_id: String) -> bool:
	return bool(instance.flags.get("replacement_used_%s" % effect_id, false))

func build_status_snapshot(state: GameState, player_id: int) -> Dictionary:
	var waiting = get_waiting_state(state)
	return {
		"player_id": player_id,
		"active_player": state.active_player,
		"priority_player": state.priority_player,
		"priority_pass_count": state.priority_pass_count,
		"phase": state.phase,
		"turn_number": state.turn_number,
		"winner": state.winner,
		"loss_reason": state.loss_reason,
		"waiting": waiting.duplicate(true),
		"stack_size": state.stack.size(),
		"pending_trigger_count": state.pending_triggers.size(),
		"continuous_modifier_count": state.continuous_modifiers.size(),
		"can_end_phase": player_id == state.active_player and PhaseMachine.can_use_command("EndPhase", state.phase),
		"can_play_card": player_id == state.active_player and PhaseMachine.can_use_command("PlayCard", state.phase),
		"can_declare_attack": player_id == state.active_player and PhaseMachine.can_use_command("DeclareAttack", state.phase),
		"can_activate_effect": not get_activatable_effects(state, player_id).is_empty(),
		"can_pass_priority": player_id == state.priority_player and state.pending_choices.is_empty() and (not state.stack.is_empty() or not state.pending_attack.is_empty())
	}

func get_waiting_state(state: GameState) -> Dictionary:
	if state.winner != -1:
		return {
			"state": "GameOver",
			"player_id": -1,
			"winner": state.winner,
			"loss_reason": state.loss_reason
		}
	if not state.pending_choices.is_empty():
		var choice = state.pending_choices[0]
		return {
			"state": "WaitingForChoice",
			"player_id": int(choice.get("player_id", -1)),
			"choice_id": str(choice.get("choice_id", "")),
			"choice_type": str(choice.get("type", "")),
			"operation": str(choice.get("operation", "")),
			"count": int(choice.get("count", 0))
		}
	if not state.stack.is_empty() or not state.pending_attack.is_empty():
		return {
			"state": "WaitingForPriority",
			"player_id": state.priority_player,
			"stack_size": state.stack.size(),
			"pending_attack": not state.pending_attack.is_empty()
		}
	return {
		"state": "WaitingForAction",
		"player_id": state.active_player,
		"phase": state.phase
	}

func get_legal_actions(state: GameState, player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var waiting = get_waiting_state(state)
	match str(waiting.get("state", "WaitingForAction")):
		"GameOver":
			return result
		"WaitingForChoice":
			if int(waiting.get("player_id", -1)) != player_id:
				return result
			if not state.pending_choices.is_empty():
				result.append(_build_choice_action_proposal(state.pending_choices[0]))
				if _is_interruptible_pending_choice(state.pending_choices[0]):
					result.append_array(_build_main_phase_action_proposals(state, player_id))
			return result
		"WaitingForPriority":
			if int(waiting.get("player_id", -1)) != player_id:
				return result
			if _validate_pass_priority(state, GameCommand.create(player_id, "PassPriority")).get("ok", false):
				result.append(_build_action_proposal(
					"pass_priority",
					"PassPriority",
					"Pass priority",
					{}
				))
			result.append_array(_build_priority_action_proposals(state, player_id))
			return result
		_:
			if int(waiting.get("player_id", -1)) != player_id:
				return result
			result.append_array(_build_main_phase_action_proposals(state, player_id))
			return result

func _build_choice_action_proposal(choice: Dictionary) -> Dictionary:
	var extra = {
		"choice_type": str(choice.get("type", "")),
		"operation": str(choice.get("operation", "")),
		"count": int(choice.get("count", 0)),
		"title": str(choice.get("title", ""))
	}
	var context = choice.get("context", {})
	if context is Dictionary and not context.is_empty():
		extra["context"] = context.duplicate(true)
	if choice.has("candidate_card_ids"):
		extra["candidate_card_ids"] = choice.get("candidate_card_ids", []).duplicate(true)
	if choice.has("looked_cards"):
		extra["looked_cards"] = choice.get("looked_cards", []).duplicate(true)
	if choice.has("options"):
		extra["options"] = choice.get("options", []).duplicate(true)
	if context is Dictionary and context.has("slot_options"):
		extra["slot_options"] = context.get("slot_options", []).duplicate(true)
	if context is Dictionary and context.has("stack_item"):
		extra["stack_item"] = context.get("stack_item", {}).duplicate(true)
	if context is Dictionary and context.has("requires_confirm"):
		extra["requires_confirm"] = bool(context.get("requires_confirm", false))
	if context is Dictionary and context.has("allow_up_to_count"):
		extra["allow_up_to_count"] = bool(context.get("allow_up_to_count", false))
	if context is Dictionary and context.has("min_select_count"):
		extra["min_select_count"] = int(context.get("min_select_count", 0))
	if context is Dictionary and context.has("hint_text"):
		extra["hint_text"] = str(context.get("hint_text", ""))
	if context is Dictionary and context.has("top_hint_text"):
		extra["top_hint_text"] = str(context.get("top_hint_text", ""))
	if context is Dictionary and context.has("highlight_card_ids"):
		extra["highlight_card_ids"] = context.get("highlight_card_ids", []).duplicate(true)
	if context is Dictionary and context.has("drag_reorder_all_candidates"):
		extra["drag_reorder_all_candidates"] = bool(context.get("drag_reorder_all_candidates", false))
	return _build_action_proposal(
		"resolve_choice",
		"ResolveChoice",
		"Resolve choice",
		{
			"choice_id": str(choice.get("choice_id", "")),
			"selected_card_ids": [],
			"selected_option": ""
		},
		{
			"choice_id": str(choice.get("choice_id", "")),
			"player_id": int(choice.get("player_id", -1))
		},
		[],
		extra
	)

func _build_priority_action_proposals(state: GameState, player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(_build_pending_attack_defense_proposals(state, player_id))
	for action in get_activatable_effects(state, player_id):
		var source_id = str(action.get("source_id", ""))
		var effect_id = str(action.get("effect_id", ""))
		var effect_targets := get_legal_effect_targets(state, player_id, source_id, effect_id)
		var target_mode := str(action.get("target_mode", _infer_targets_mode(effect_targets)))
		if _proposal_requires_non_empty_targets(target_mode) and effect_targets.is_empty():
			continue
		result.append(_build_action_proposal(
			"activate_effect",
			"ActivateEffect",
			"Activate %s" % str(action.get("text", "")),
			{
				"source_id": source_id,
				"effect_id": effect_id
			},
			_build_effect_source(state, source_id, effect_id, str(action.get("text", "")), str(action.get("zone", ""))),
			effect_targets,
			{
				"cost": action.get("cost", {}).duplicate(true),
				"target_mode": target_mode
			}
		))
	var player = state.get_player(player_id)
	for card_id in player.hand.cards:
		var hand_response_effects = get_castable_hand_response_effects(state, player_id, card_id)
		result.append_array(_build_effect_play_proposals(state, card_id, hand_response_effects, "hand_response", "hand_response"))
		var counter_effects = get_castable_tactic_effects(state, player_id, card_id)
		result.append_array(_build_effect_play_proposals(state, card_id, counter_effects, "counter_tactic", "counter_tactic"))
	return result

func _build_pending_attack_defense_proposals(state: GameState, player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.pending_attack.is_empty():
		return result
	if not state.stack.is_empty():
		return result
	if player_id != state.priority_player:
		return result
	var attack = state.pending_attack
	if _pending_attack_has_defense_selection(attack):
		return result
	if str(attack.get("target_kind", "card")) == "master":
		if int(attack.get("target_player", -1)) != player_id:
			return result
	else:
		var defender_id := str(attack.get("defender_id", ""))
		var defender = state.card_instances.get(defender_id)
		if defender == null or int(defender.controller) != player_id:
			return result
	var attacker_id = str(attack.get("attacker_id", ""))
	var target = {
		"target_kind": str(attack.get("target_kind", "card")),
		"target_player": int(attack.get("target_player", -1)),
		"defender_id": str(attack.get("defender_id", ""))
	}
	var defense_options = get_defense_options(state, attacker_id, target)
	var extra_discard_candidates: Array[String] = []
	if _ranged_block_requires_extra_discard(state, attacker_id):
		for hand_card_id in state.get_player(player_id).hand.cards:
			extra_discard_candidates.append(str(hand_card_id))
	for blocker_id in defense_options.get("blockers", []):
		if extra_discard_candidates.is_empty():
			result.append(_build_action_proposal(
				"choose_defense",
				"ChooseDefense",
				"Block with %s" % _action_card_name(state, str(blocker_id)),
				{
					"blocker_id": str(blocker_id)
				},
				{
					"card_name": _action_card_name(state, str(blocker_id)),
					"defense_kind": "blocker"
				}
			))
		else:
			for discard_card_id in extra_discard_candidates:
				if discard_card_id == str(blocker_id):
					continue
				result.append(_build_action_proposal(
					"choose_defense",
					"ChooseDefense",
					"Block with %s and discard %s" % [_action_card_name(state, str(blocker_id)), _action_card_name(state, discard_card_id)],
					{
						"blocker_id": str(blocker_id),
						"extra_discard_card_id": discard_card_id
					},
					{
						"card_name": _action_card_name(state, str(blocker_id)),
						"discard_card_name": _action_card_name(state, discard_card_id),
						"defense_kind": "blocker"
					}
				))
	for supporter_id in defense_options.get("supporters", []):
		if extra_discard_candidates.is_empty():
			result.append(_build_action_proposal(
				"choose_defense",
				"ChooseDefense",
				"Support with %s" % _action_card_name(state, str(supporter_id)),
				{
					"supporter_id": str(supporter_id)
				},
				{
					"card_name": _action_card_name(state, str(supporter_id)),
					"defense_kind": "supporter"
				}
			))
		else:
			for discard_card_id in extra_discard_candidates:
				result.append(_build_action_proposal(
					"choose_defense",
					"ChooseDefense",
					"Support with %s and discard %s" % [_action_card_name(state, str(supporter_id)), _action_card_name(state, discard_card_id)],
					{
						"supporter_id": str(supporter_id),
						"extra_discard_card_id": discard_card_id
					},
					{
						"card_name": _action_card_name(state, str(supporter_id)),
						"discard_card_name": _action_card_name(state, discard_card_id),
						"defense_kind": "supporter"
					}
				))
	for guard_cards in get_legal_master_guard_card_sets(state, player_id, attacker_id, target):
		result.append(_build_action_proposal(
			"choose_defense",
			"ChooseDefense",
			"Guard master with %s" % _join_card_names(state, guard_cards),
			{
				"master_guard_card_ids": guard_cards
			},
			{
				"card_name": _join_card_names(state, guard_cards),
				"defense_kind": "master_guard"
			}
		))
	return result

func _pending_attack_has_defense_selection(attack: Dictionary) -> bool:
	if not str(attack.get("blocker_id", "")).is_empty():
		return true
	if not str(attack.get("supporter_id", "")).is_empty():
		return true
	var master_guard_card_ids = attack.get("master_guard_card_ids", [])
	return master_guard_card_ids is Array and not master_guard_card_ids.is_empty()

func _build_main_phase_action_proposals(state: GameState, player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var player = state.get_player(player_id)
	for card_id in player.hand.cards:
		var slots = get_legal_play_slots(state, player_id, card_id)
		if not slots.is_empty():
			result.append_array(_build_board_play_proposals(state, player_id, card_id, slots))
		var tactic_effects = get_castable_tactic_effects(state, player_id, card_id)
		result.append_array(_build_effect_play_proposals(state, card_id, tactic_effects, "tactic", "tactic"))
	for action in get_activatable_effects(state, player_id):
		var source_id = str(action.get("source_id", ""))
		var effect_id = str(action.get("effect_id", ""))
		var effect_targets := get_legal_effect_targets(state, player_id, source_id, effect_id)
		var target_mode := str(action.get("target_mode", _infer_targets_mode(effect_targets)))
		if _proposal_requires_non_empty_targets(target_mode) and effect_targets.is_empty():
			continue
		result.append(_build_action_proposal(
			"activate_effect",
			"ActivateEffect",
			"Activate %s" % str(action.get("text", "")),
			{
				"source_id": source_id,
				"effect_id": effect_id
			},
			_build_effect_source(state, source_id, effect_id, str(action.get("text", "")), str(action.get("zone", ""))),
			effect_targets,
			{
				"cost": action.get("cost", {}).duplicate(true),
				"target_mode": target_mode
			}
		))
	for card_id in _get_battlefield_card_ids(state):
		var instance = state.card_instances.get(card_id)
		if instance == null or instance.controller != player_id:
			continue
		var move_targets = get_legal_move_targets(state, card_id)
		if not move_targets.is_empty():
			result.append(_build_action_proposal(
				"move_legion",
				"MoveLegion",
				"Move %s" % _action_card_name(state, card_id),
				{
					"card_id": card_id
				},
				_build_card_source(state, card_id, "battle_move", {
					"zone": str(instance.zone)
				}),
				move_targets,
				{
					"target_mode": "slot"
				}
			))
		var attack_targets = get_legal_attack_targets(state, card_id)
		if attack_targets.is_empty():
			continue
		result.append(_build_action_proposal(
			"declare_attack",
			"DeclareAttack",
			"Attack with %s" % _action_card_name(state, card_id),
			{
				"attacker_id": card_id
			},
			_build_card_source(state, card_id, "attacker"),
			_decorate_attack_targets_with_defense_options(state, card_id, attack_targets),
			{
				"target_mode": _infer_targets_mode(attack_targets)
			}
		))
	if player_id == state.active_player and PhaseMachine.can_use_command("EndPhase", state.phase):
		result.append(_build_action_proposal(
			"end_phase",
			"EndPhase",
			"End phase",
			{}
		))
	return result

func _build_board_play_proposals(state: GameState, player_id: int, card_id: String, slots: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var available_play_options = _get_available_play_options(state, card_id)
	if available_play_options.is_empty():
		if MoraleActions.count_active_morale(state, player_id) < _get_effective_play_cost(state, card_id):
			return result
		var valid_slots := _filter_valid_play_card_targets(state, player_id, {
			"card_id": card_id
		}, slots)
		if valid_slots.is_empty():
			return result
		result.append(_build_action_proposal(
			"play_card",
			"PlayCard",
			"Play %s" % _action_card_name(state, card_id),
			{
				"card_id": card_id
			},
			_build_card_source(state, card_id, "board_or_artifact"),
			valid_slots,
			{
				"play_kind": "board_or_artifact",
				"target_mode": "slot"
			}
		))
		return result
	var auto_play_option := _auto_selected_play_option(available_play_options)
	if not auto_play_option.is_empty():
		if MoraleActions.count_active_morale(state, player_id) < _get_effective_play_cost(state, card_id, auto_play_option):
			return result
		var auto_option_id := str(auto_play_option.get("id", "default"))
		var valid_auto_slots := _filter_valid_play_card_targets(state, player_id, {
			"card_id": card_id,
			"play_option_id": auto_option_id
		}, slots)
		if valid_auto_slots.is_empty():
			return result
		result.append(_build_action_proposal(
			"play_card",
			"PlayCard",
			"Play %s" % _action_card_name(state, card_id),
			{
				"card_id": card_id
			},
			_build_card_source(state, card_id, "board_or_artifact"),
			valid_auto_slots,
			{
				"play_kind": "board_or_artifact",
				"target_mode": "slot"
			}
		))
		return result
	for play_option in available_play_options:
		if MoraleActions.count_active_morale(state, player_id) < _get_effective_play_cost(state, card_id, play_option):
			continue
		var option_id = str(play_option.get("id", "default"))
		var option_label = str(play_option.get("label", ""))
		var valid_slots := _filter_valid_play_card_targets(state, player_id, {
			"card_id": card_id,
			"play_option_id": option_id
		}, slots)
		if valid_slots.is_empty():
			continue
		result.append(_build_action_proposal(
			"play_card",
			"PlayCard",
			"Play %s" % _action_card_name(state, card_id),
			{
				"card_id": card_id,
				"play_option_id": option_id
			},
			_build_card_source(state, card_id, "board_or_artifact", {
				"play_option_id": option_id,
				"play_option_label": option_label
			}),
			valid_slots,
			{
				"play_kind": "board_or_artifact",
				"target_mode": "slot",
				"play_option_id": option_id,
				"play_option_label": option_label
			}
		))
	return result

func _build_effect_play_proposals(state: GameState, card_id: String, effect_groups: Array[Dictionary], play_kind: String, row_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect_group in effect_groups:
		var effect_id = str(effect_group.get("effect_id", ""))
		var effect_text = str(effect_group.get("effect_text", ""))
		var payload_template := {
			"card_id": card_id,
			"row": row_name,
			"col": -1,
			"effect_id": effect_id
		}
		var targets = _filter_valid_play_card_targets(state, int(state.priority_player if not state.stack.is_empty() or not state.pending_attack.is_empty() else state.active_player), payload_template, effect_group.get("targets", []).duplicate(true))
		var target_mode := str(effect_group.get("target_mode", _infer_targets_mode(targets)))
		if play_kind != "tactic" and _proposal_requires_non_empty_targets(target_mode) and targets.is_empty():
			continue
		result.append(_build_action_proposal(
			"play_card",
			"PlayCard",
			"Play %s" % _action_card_name(state, card_id),
			payload_template,
			_build_card_source(state, card_id, play_kind, {
				"effect_id": effect_id,
				"effect_text": effect_text
			}),
			targets,
			{
				"play_kind": play_kind,
				"target_mode": target_mode,
				"effect_text": effect_text
			}
		))
	return result

func _filter_valid_play_card_targets(state: GameState, player_id: int, payload_template: Dictionary, targets: Array) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	if targets.is_empty():
		return filtered
	for target in targets:
		var payload: Dictionary = payload_template.duplicate(true)
		if target is Dictionary:
			for key in ["row", "col", "host_player", "target_kind", "target_card_id", "target_player", "target_stack_id", "defender_id", "blocker_id", "supporter_id", "effect_id", "play_option_id"]:
				if target.has(key):
					payload[key] = target.get(key)
			if target.has("master_guard_card_ids"):
				payload["master_guard_card_ids"] = target.get("master_guard_card_ids", []).duplicate(true)
		var validation := _validate_play_card(state, GameCommand.create(player_id, "PlayCard", payload))
		if bool(validation.get("ok", false)):
			filtered.append(target.duplicate(true) if target is Dictionary else target)
	return filtered

func _build_action_proposal(kind: String, command_type: String, label: String, payload_template: Dictionary, source: Dictionary = {}, targets: Array = [], extra: Dictionary = {}) -> Dictionary:
	var proposal = {
		"proposal_id": _build_action_proposal_id(kind, payload_template),
		"kind": kind,
		"command_type": command_type,
		"label": label,
		"payload_template": payload_template.duplicate(true),
		"targets": targets.duplicate(true)
	}
	if not source.is_empty():
		proposal["source"] = source.duplicate(true)
	for key in extra.keys():
		proposal[key] = extra.get(key)
	return proposal

func _build_action_proposal_id(kind: String, payload_template: Dictionary) -> String:
	var parts: Array[String] = [kind]
	for key in ["choice_id", "card_id", "source_id", "effect_id", "attacker_id", "row", "blocker_id", "supporter_id", "play_option_id"]:
		var value = str(payload_template.get(key, ""))
		if value.is_empty():
			continue
		parts.append(value)
	if payload_template.has("master_guard_card_ids"):
		parts.append(",".join(_payload_string_array(payload_template.get("master_guard_card_ids", []))))
	return ":".join(parts)

func _build_card_source(state: GameState, card_id: String, play_kind: String, extra: Dictionary = {}) -> Dictionary:
	var source = {
		"card_id": card_id,
		"card_name": _action_card_name(state, card_id),
		"play_kind": play_kind,
		"zone": "hand"
	}
	for key in extra.keys():
		source[key] = extra.get(key)
	return source

func _build_effect_source(state: GameState, source_id: String, effect_id: String, effect_text: String, zone: String) -> Dictionary:
	var source = {
		"source_id": source_id,
		"effect_id": effect_id,
		"effect_text": effect_text,
		"zone": zone
	}
	if source_id.begins_with("master_"):
		source["card_name"] = state.get_player(int(source_id.trim_prefix("master_"))).master_name
	elif _is_morale_source_id(source_id):
		source["card_name"] = "阵营士气"
	else:
		source["card_name"] = _action_card_name(state, source_id)
	return source

func _payload_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text = str(item)
			if text.is_empty():
				continue
			result.append(text)
	return result

func _same_string_arrays(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if left[index] != right[index]:
			return false
	return true

func _same_string_sets(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	var left_copy: Array[String] = left.duplicate()
	var right_copy: Array[String] = right.duplicate()
	left_copy.sort()
	right_copy.sort()
	for index in range(left_copy.size()):
		if left_copy[index] != right_copy[index]:
			return false
	return true

func _join_card_names(state: GameState, card_ids) -> String:
	var names: Array[String] = []
	if card_ids is Array:
		for raw_card_id in card_ids:
			names.append(_action_card_name(state, str(raw_card_id)))
	return " + ".join(names)

func _decorate_attack_targets_with_defense_options(state: GameState, attacker_id: String, targets: Array[Dictionary]) -> Array[Dictionary]:
	var decorated: Array[Dictionary] = []
	for target in targets:
		var row = target.duplicate(true)
		row["defense_options"] = get_defense_options(state, attacker_id, row)
		decorated.append(row)
	return decorated

func _infer_targets_mode(targets: Array) -> String:
	if targets.is_empty():
		return "none"
	var first = targets[0]
	if not (first is Dictionary):
		return "none"
	return str(first.get("target_kind", "slot"))


func _proposal_requires_non_empty_targets(target_mode: String) -> bool:
	return target_mode != "none"

func _single_line_display_text(text: String) -> String:
	var resolved := str(text).replace("\r", " ").replace("\n", " ").strip_edges()
	while resolved.contains("  "):
		resolved = resolved.replace("  ", " ")
	return resolved

func _action_card_name(state: GameState, card_id: String) -> String:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return ""
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return ""
	return definition.name

func _auto_selected_play_option(options: Array[Dictionary]) -> Dictionary:
	if options.size() != 1:
		return {}
	return options[0].duplicate(true)

func _optional_stack_effect_choice_title(state: GameState, stack_item: Dictionary) -> String:
	var source_name := _action_card_name(state, str(stack_item.get("source_instance_id", "")))
	if source_name.is_empty():
		return "是否发动该可选效果？"
	return "%s：是否发动该可选效果？" % source_name

func get_activatable_effects(state: GameState, player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != -1:
		return result
	if player_id != state.priority_player:
		return result
	if not PhaseMachine.can_use_command("ActivateEffect", state.phase):
		return result
	var response_window_open = not state.stack.is_empty() or not state.pending_attack.is_empty()
	if not response_window_open and player_id != state.active_player:
		return result
	var source_ids: Array[String] = _get_battlefield_card_ids(state)
	source_ids.append_array(_get_artifact_card_ids(state, player_id))
	source_ids.append_array(_get_trial_card_ids(state, player_id))
	source_ids.append_array(_get_city_card_ids(state, player_id))
	source_ids.append_array(_get_grave_activatable_card_ids(state, player_id))
	for card_id in source_ids:
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var is_set_counter_source: bool = _is_set_counter_tactic_source(state, card_id)
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		if is_set_counter_source and not response_window_open:
			continue
		if is_set_counter_source and _is_counter_tactic_disabled_this_turn(state, card_id):
			continue
		for effect in definition.effects:
			if str(effect.get("kind", "")) != "activated":
				continue
			if bool(effect.get("hidden_from_actions", false)):
				continue
			if instance.controller != player_id and not bool(effect.get("any_player_can_activate", false)):
				continue
			if response_window_open:
				if not _effect_can_activate_in_response_window(state, card_id, effect):
					continue
			else:
				if bool(effect.get("response_only", false)):
					continue
			var cost_check = _validate_effect_cost(state, player_id, effect, {"source_id": card_id})
			if not cost_check.get("ok", false):
				continue
			var availability_check = _validate_effect_availability(state, player_id, card_id, effect)
			if not availability_check.get("ok", false):
				continue
			result.append({
				"source_id": card_id,
				"effect_id": str(effect.get("id", "")),
				"text": str(effect.get("text", definition.name)),
				"cost": effect.get("cost", {}).duplicate(true),
				"zone": instance.zone,
				"can_activate_on_stack": bool(effect.get("can_activate_on_stack", false)),
				"target_mode": _get_effect_target_mode(effect)
			})
	for effect in _build_master_effects(state, player_id):
		if response_window_open:
			if not _effect_can_activate_in_response_window(state, _master_source_id(player_id), effect):
				continue
		else:
			if bool(effect.get("response_only", false)):
				continue
		var master_cost_check = _validate_effect_cost(state, player_id, effect, {"source_id": _master_source_id(player_id)})
		if not master_cost_check.get("ok", false):
			continue
		var availability_check = _validate_effect_availability(state, player_id, _master_source_id(player_id), effect)
		if not availability_check.get("ok", false):
			continue
		result.append({
			"source_id": _master_source_id(player_id),
			"effect_id": str(effect.get("id", "")),
			"text": str(effect.get("text", state.get_player(player_id).master_name)),
			"cost": effect.get("cost", {}).duplicate(true),
			"zone": "master",
			"can_activate_on_stack": bool(effect.get("can_activate_on_stack", false)),
			"target_mode": _get_effect_target_mode(effect)
		})
	for effect in _build_morale_effects(state, player_id):
		if response_window_open:
			if not bool(effect.get("can_activate_on_stack", false)):
				continue
		else:
			if bool(effect.get("response_only", false)):
				continue
		var morale_cost_check = _validate_effect_cost(state, player_id, effect, {"source_id": _morale_source_id(player_id)})
		if not morale_cost_check.get("ok", false):
			continue
		var morale_source_id := _morale_source_id(player_id)
		var morale_availability_check = _validate_effect_availability(state, player_id, morale_source_id, effect)
		if not morale_availability_check.get("ok", false):
			continue
		result.append({
			"source_id": morale_source_id,
			"effect_id": str(effect.get("id", "")),
			"text": str(effect.get("text", "Morale faction effect")),
			"cost": effect.get("cost", {}).duplicate(true),
			"zone": "morale",
			"can_activate_on_stack": bool(effect.get("can_activate_on_stack", false)),
			"target_mode": _get_effect_target_mode(effect)
		})
	return result

func get_legal_effect_targets(state: GameState, player_id: int, source_id: String, effect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != -1:
		return result
	if player_id != state.priority_player:
		return result
	if not PhaseMachine.can_use_command("ActivateEffect", state.phase):
		return result
	if source_id.is_empty() or effect_id.is_empty():
		return result
	var response_window_open = not state.stack.is_empty() or not state.pending_attack.is_empty()
	if not response_window_open and player_id != state.active_player:
		return result
	var effect = _find_source_effect_definition(state, source_id, effect_id, "activated", player_id)
	if effect.is_empty():
		return result
	if not _validate_effect_source(state, player_id, source_id, effect):
		return result
	if response_window_open:
		if not _effect_can_activate_in_response_window(state, source_id, effect):
			return result
	else:
		if bool(effect.get("response_only", false)):
			return result
	var cost_check = _validate_effect_cost(state, player_id, effect, {"source_id": source_id})
	if not cost_check.get("ok", false):
		return result
	var availability_check = _validate_effect_availability(state, player_id, source_id, effect)
	if not availability_check.get("ok", false):
		return result
	return _build_legal_tactic_targets_for_effect(state, player_id, effect)

func _get_artifact_card_ids(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	if player_id < 0 or player_id >= state.players.size():
		return result
	for card_id in state.get_player(player_id).artifact_zone.cards:
		result.append(card_id)
	return result

func _get_trial_card_ids(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	if player_id < 0 or player_id >= state.players.size():
		return result
	for card_id in state.get_player(player_id).trial_zone.cards:
		result.append(card_id)
	return result

func _get_city_card_ids(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	if player_id < 0 or player_id >= state.players.size():
		return result
	for card_id in state.get_player(player_id).city_zone.cards:
		result.append(card_id)
	return result

func _get_grave_activatable_card_ids(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	if player_id < 0 or player_id >= state.players.size():
		return result
	for card_id in state.get_player(player_id).grave.cards:
		var grave_card_id = str(card_id)
		var instance = state.card_instances.get(grave_card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		for effect in definition.effects:
			if str(effect.get("kind", "")) == "activated" and bool(effect.get("allow_grave_source", false)):
				result.append(grave_card_id)
				break
	return result

func _queue_additional_stack_effects(state: GameState, controller: int, source_id: String, effect: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var additional_ids = effect.get("additional_stack_effect_ids", [])
	if not (additional_ids is Array):
		return events
	for raw_effect_id in additional_ids:
		var linked_effect_id = str(raw_effect_id)
		if linked_effect_id.is_empty():
			continue
		var linked_effect = _find_source_effect_definition_by_id(state, source_id, linked_effect_id, controller)
		if linked_effect.is_empty():
			continue
		events.append_array(_put_effect_on_stack(state, controller, source_id, linked_effect, "activated", [], 0, {}, command_id))
	return events

func _remember_last_active_tactic(state: GameState, player_id: int, source_id: String, effect: Dictionary) -> void:
	if source_id.is_empty() or effect.is_empty():
		return
	state.get_player(player_id).flags["last_active_tactic"] = {
		"turn": state.turn_number,
		"source_id": source_id,
		"effect": effect.duplicate(true)
	}

func _put_effect_on_stack(state: GameState, controller: int, source_id: String, effect: Dictionary, effect_type: String, paid_costs: Array, created_from_event_id: int, targets: Dictionary, command_id: String) -> Array:
	var stack_item = _create_stack_item_from_effect(state, controller, source_id, effect, effect_type, paid_costs, created_from_event_id, targets)
	state.stack.append(stack_item)
	state.priority_player = 1 - controller
	state.priority_pass_count = 0
	var stack_event = GameEvent.create(state.next_event_id(), "EffectPutOnStack", controller, {
		"stack_id": stack_item.get("stack_id", ""),
		"source_id": source_id,
		"effect_id": str(effect.get("id", "")),
		"effect_type": effect_type
	})
	stack_event.created_by_command = command_id
	state.event_log.append(stack_event)
	return [stack_event]

func get_legal_play_slots(state: GameState, player_id: int, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != -1:
		return result
	if not state.stack.is_empty() or not state.pending_attack.is_empty():
		return result
	if player_id != state.active_player:
		return result
	if not PhaseMachine.can_use_command("PlayCard", state.phase):
		return result
	var player = state.get_player(player_id)
	if not player.hand.has_card(card_id):
		return result
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return result
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return result
	if definition.is_counter_tactic():
		if not _counter_tactics_require_set(state):
			return result
		if MoraleActions.count_active_morale(state, player_id) < _effective_hand_play_cost(state, card_id, {}, "back"):
			return result
		for col in range(3):
			var slot = player.get_slot("back", col)
			if slot == null:
				continue
			if slot.occupant.is_empty() or _can_replace_face_down_cover_card(state, player_id, "back", col):
				result.append({"row": "back", "col": col})
		return result
	if definition.is_artifact():
		if MoraleActions.count_active_morale(state, player_id) < _get_effective_play_cost(state, card_id):
			return result
		if _player_has_active_artifact_definition(state, player_id, "asgard_s02_0305") or _player_has_active_artifact_definition(state, player_id, "suncity_s02_0205"):
			return result
		result.append({"row": "artifact", "col": -1})
		return result
	if not definition.is_legion():
		return result
	if MoraleActions.count_active_morale(state, player_id) < _get_minimum_play_cost(state, card_id):
		return result
	var available_play_options = _get_available_play_options(state, card_id)
	var host_players: Array[int] = [player_id]
	for play_option in available_play_options:
		if bool(play_option.get("allow_foreign_battlefield", false)):
			host_players.append(1 - player_id)
			break
	for host_player_id in host_players:
		var host_player = state.get_player(host_player_id)
		for row in ["front", "back"]:
			if row == "back" and _is_back_row_blocked_by_calamity(state):
				continue
			for col in range(3):
				var slot = host_player.get_slot(row, col)
				if slot == null:
					continue
				if slot.occupant.is_empty() or _can_replace_face_down_cover_card(state, host_player_id, row, col) or not available_play_options.is_empty():
					var target := {"row": row, "col": col}
					if host_player_id != player_id:
						target["host_player"] = host_player_id
					result.append(target)
	return result

func get_castable_tactic_effects(state: GameState, player_id: int, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != -1:
		return result
	if not PhaseMachine.can_use_command("PlayCard", state.phase):
		return result
	var player = state.get_player(player_id)
	if not player.hand.has_card(card_id):
		return result
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return result
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return result
	if not definition.is_tactic() and not definition.is_counter_tactic():
		return result
	if definition.is_counter_tactic() and _is_counter_tactic_disabled_this_turn(state, card_id):
		return result
	if definition.is_counter_tactic() and _counter_tactics_require_set(state):
		return result
	if MoraleActions.count_active_morale(state, player_id) < _get_effective_play_cost(state, card_id):
		return result
	if definition.is_counter_tactic():
		if (state.stack.is_empty() and state.pending_attack.is_empty()) or player_id != state.priority_player:
			return result
	elif not state.stack.is_empty() or not state.pending_attack.is_empty():
		return result
	elif player_id != state.active_player:
		return result
	for effect in _get_castable_tactic_effects(definition):
		var remaining_hand_after_cast = player.hand.cards.size() - 1
		var availability_check = _validate_effect_availability(state, player_id, card_id, effect, {"hand_cards_after_source_leaves": remaining_hand_after_cast})
		if not availability_check.get("ok", false):
			continue
		var effect_cost_check = _validate_effect_cost(state, player_id, effect, {"hand_cards_after_source_leaves": player.hand.cards.size() - 1})
		if not effect_cost_check.get("ok", false):
			continue
		if not _additional_stack_effects_available_for_source_effect(state, player_id, card_id, effect):
			continue
		var targets = _build_legal_tactic_targets_for_effect(state, player_id, effect)
		var target_mode := _get_effect_target_mode(effect)
		result.append({
			"effect_id": str(effect.get("id", "")),
			"effect_text": str(effect.get("text", "")),
			"target_mode": target_mode,
			"targets": targets
		})
	return result

func _additional_stack_effects_available_for_source_effect(state: GameState, controller: int, source_id: String, effect: Dictionary) -> bool:
	var additional_ids = effect.get("additional_stack_effect_ids", [])
	if not (additional_ids is Array):
		return true
	for raw_effect_id in additional_ids:
		var linked_effect_id := str(raw_effect_id)
		if linked_effect_id.is_empty():
			continue
		var linked_effect := _find_source_effect_definition_by_id(state, source_id, linked_effect_id, controller)
		if linked_effect.is_empty():
			continue
		if not _stack_effect_is_currently_available(state, controller, source_id, linked_effect):
			return false
	return true

func _stack_effect_is_currently_available(state: GameState, controller: int, source_id: String, effect: Dictionary) -> bool:
	var resolution = effect.get("resolution", {})
	if not (resolution is Dictionary):
		return false
	var stack_item := {
		"controller": controller,
		"source_instance_id": source_id,
		"resolution": resolution
	}
	return _can_offer_optional_stack_effect_choice(state, stack_item)

func get_castable_hand_response_effects(state: GameState, player_id: int, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != -1:
		return result
	if not PhaseMachine.can_use_command("PlayCard", state.phase):
		return result
	var player = state.get_player(player_id)
	if not player.hand.has_card(card_id):
		return result
	if player_id != state.priority_player:
		return result
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return result
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return result
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "activated" or not bool(effect.get("hand_response", false)):
			continue
		if not _can_play_hand_response_legion(state, player_id, card_id, effect):
			continue
		var remaining_hand_after_cast = player.hand.cards.size() - 1
		var availability_check = _validate_effect_availability(state, player_id, card_id, effect, {"hand_cards_after_source_leaves": remaining_hand_after_cast})
		if not availability_check.get("ok", false):
			continue
		var effect_cost_check = _validate_effect_cost(state, player_id, effect, {"hand_cards_after_source_leaves": player.hand.cards.size() - 1})
		if not effect_cost_check.get("ok", false):
			continue
		var targets = _build_legal_tactic_targets_for_effect(state, player_id, effect)
		var target_mode := _get_effect_target_mode(effect)
		result.append({
			"effect_id": str(effect.get("id", "")),
			"effect_text": str(effect.get("text", "")),
			"target_mode": target_mode,
			"targets": targets
		})
	return result

func get_legal_hand_response_targets(state: GameState, player_id: int, card_id: String, effect_id: String = "") -> Array[Dictionary]:
	var effect_groups = get_castable_hand_response_effects(state, player_id, card_id)
	if effect_groups.is_empty():
		return []
	if effect_id.is_empty():
		return effect_groups[0].get("targets", []).duplicate(true)
	for effect_group in effect_groups:
		if str(effect_group.get("effect_id", "")) == effect_id:
			return effect_group.get("targets", []).duplicate(true)
	return []

func get_legal_tactic_targets(state: GameState, player_id: int, card_id: String, effect_id: String = "") -> Array[Dictionary]:
	var effect_groups = get_castable_tactic_effects(state, player_id, card_id)
	if effect_groups.is_empty():
		return []
	if effect_id.is_empty():
		return effect_groups[0].get("targets", []).duplicate(true)
	for effect_group in effect_groups:
		if str(effect_group.get("effect_id", "")) == effect_id:
			return effect_group.get("targets", []).duplicate(true)
	return []

func _build_legal_tactic_targets_for_effect(state: GameState, player_id: int, effect: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if effect.is_empty():
		return result
	match _get_effect_target_mode(effect):
		"none":
			result.append({"target_kind": "none"})
		"stack":
			if _pending_attack_can_be_responded_to_by_player(state, player_id) and _stack_target_matches_effect_filters(state, effect, player_id, "__pending_attack__"):
				result.append({
					"target_kind": "stack",
					"target_stack_id": "__pending_attack__",
					"target_effect_id": "pending_attack",
					"target_source_id": "__pending_attack__"
				})
			for item in state.stack:
				if not _stack_item_can_be_responded_to_by_player(state, item, player_id):
					continue
				if not _stack_target_matches_effect_filters(state, effect, player_id, str(item.get("stack_id", "")), item):
					continue
				result.append({
					"target_kind": "stack",
					"target_stack_id": str(item.get("stack_id", "")),
					"target_effect_id": str(item.get("effect_id", "")),
					"target_source_id": str(item.get("source_instance_id", ""))
				})
		"card":
			for target_card_id in _get_battlefield_card_ids(state):
				if not _target_card_matches_effect_filters(state, effect, player_id, target_card_id):
					continue
				result.append({"target_kind": "card", "target_card_id": target_card_id})
		"master":
			for target_player in range(state.players.size()):
				if target_player == player_id:
					continue
				result.append({"target_kind": "master", "target_player": target_player})
		"plague_infection_target":
			for target_card_id in _get_battlefield_legion_card_ids_for_player(state, 1 - player_id):
				result.append({"target_kind": "card", "target_card_id": target_card_id})
			result.append({"target_kind": "morale_area", "target_player": 1 - player_id})
	return result

func _stack_target_matches_effect_filters(state: GameState, effect: Dictionary, player_id: int, target_stack_id: String, stack_item: Dictionary = {}) -> bool:
	if target_stack_id == "__pending_attack__":
		var required_pending_attack_target_kind := str(effect.get("target_pending_attack_target_kind", ""))
		if required_pending_attack_target_kind.is_empty():
			return true
		return str(state.pending_attack.get("target_kind", "")) == required_pending_attack_target_kind
	if stack_item.is_empty():
		return false
	var source_id := str(stack_item.get("source_instance_id", ""))
	var source_instance = state.card_instances.get(source_id)
	var source_definition = state.get_definition(source_instance.definition_id) if source_instance != null else null
	var required_source_types_raw = effect.get("target_stack_source_types", [])
	var required_source_types: Array[String] = []
	if required_source_types_raw is Array:
		for raw_type in required_source_types_raw:
			var parsed_type = str(raw_type)
			if not parsed_type.is_empty():
				required_source_types.append(parsed_type)
	if not required_source_types.is_empty():
		if source_definition == null or not required_source_types.has(str(source_definition.type)):
			return false
	else:
		var required_source_type := str(effect.get("target_stack_source_type", ""))
		if not required_source_type.is_empty():
			if source_definition == null or str(source_definition.type) != required_source_type:
				return false
	var required_event_type := str(effect.get("target_stack_created_from_event_type", ""))
	if not required_event_type.is_empty():
		var created_from_event_id := int(stack_item.get("created_from_event_id", 0))
		var source_event = _event_by_id(state, created_from_event_id)
		if source_event == null or str(source_event.type) != required_event_type:
			return false
	var required_stack_controller_scope := str(effect.get("target_stack_controller_scope", ""))
	if required_stack_controller_scope == "enemy" and int(stack_item.get("controller", player_id)) == player_id:
		return false
	if required_stack_controller_scope == "ally" and int(stack_item.get("controller", player_id)) != player_id:
		return false
	return true

func get_legal_attack_targets(state: GameState, attacker_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != -1:
		return result
	if not state.card_instances.has(attacker_id):
		return result
	var attacker = state.card_instances[attacker_id]
	if attacker.controller != state.active_player:
		return result
	if _has_attack_keyword(state, attacker_id, "cannot_attack"):
		return result
	if not PhaseMachine.can_use_command("DeclareAttack", state.phase):
		return result
	if attacker.has_attacked_this_turn or attacker.orientation != "active":
		return result
	if not attacker.zone.begins_with("battle_"):
		return result
	var can_attack_cards_this_turn: bool = int(attacker.entered_turn) != state.turn_number or _has_attack_keyword(state, attacker_id, "charge")
	var can_attack_master_this_turn: bool = can_attack_cards_this_turn or int(attacker.flags.get("can_attack_master_until_turn_end_turn", -1)) == state.turn_number
	if not can_attack_cards_this_turn and not can_attack_master_this_turn:
		return result
	var taunt_targets = _get_required_taunt_targets(state, attacker_id)
	if can_attack_cards_this_turn and not taunt_targets.is_empty():
		for defender_id in taunt_targets:
			result.append({"target_kind": "card", "defender_id": defender_id})
		return result
	var target_player = 1 - attacker.controller
	var enemy = state.get_player(target_player)
	if can_attack_cards_this_turn:
		for slot in enemy.battle_front:
			if _can_attack_card(state, attacker_id, slot.occupant):
				result.append({"target_kind": "card", "defender_id": slot.occupant})
		for slot in enemy.battle_back:
			if _can_attack_card(state, attacker_id, slot.occupant):
				result.append({"target_kind": "card", "defender_id": slot.occupant})
	if can_attack_cards_this_turn and _current_calamity_requires_legion_targets_first(state, attacker_id) and not result.is_empty():
		return result
	if _can_attack_master(state, attacker_id, target_player):
		result.append({"target_kind": "master", "target_player": target_player})
	return result

func get_legal_move_targets(state: GameState, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _rules_bool(state, "manual_legion_move_enabled", false):
		return result
	if state.winner != -1:
		return result
	if not state.card_instances.has(card_id):
		return result
	var instance = state.card_instances[card_id]
	if instance.controller != state.active_player:
		return result
	if not instance.zone.begins_with("battle_"):
		return result
	var has_free_move = not _find_free_move_effect_for_manual_move(state, int(instance.controller), card_id).is_empty()
	if (instance.orientation != "active" or instance.has_attacked_this_turn) and not has_free_move:
		return result
	var has_cavalry_free_move = _has_cavalry_free_move_available(state, card_id)
	if instance.entered_turn == state.turn_number and not _has_attack_keyword(state, card_id, "charge") and not has_cavalry_free_move and not has_free_move:
		return result
	if _has_attack_keyword(state, card_id, "cannot_attack"):
		return result
	if not PhaseMachine.can_use_command("MoveLegion", state.phase):
		return result
	var has_hippolyta_vertical_free_move = _controller_has_rested_hippolyta_vertical_free_move(state, int(instance.controller))
	var has_active_morale = MoraleActions.count_active_morale(state, int(instance.controller)) >= 1
	if not has_free_move and not has_hippolyta_vertical_free_move and not has_active_morale and not has_cavalry_free_move:
		return result
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if row != "front" and row != "back":
		return result
	if col < 0:
		return result
	var player = state.get_player(int(instance.controller))
	var free_move_effect = _find_free_move_effect_for_manual_move(state, int(instance.controller), card_id)
	var can_swap_with_allied_occupied_slot = _free_move_effect_allows_swap_with_allied_occupied_slot(free_move_effect)
	if has_cavalry_free_move:
		for target_row in ["front", "back"]:
			for target_col in range(3):
				_append_move_target_if_legal(state, player, row, col, target_row, target_col, result)
		return result
	if _free_move_effect_allows_any_empty_slot(card_id, free_move_effect):
		for target_row in ["front", "back"]:
			for target_col in range(3):
				_append_move_target_if_legal(state, player, row, col, target_row, target_col, result, can_swap_with_allied_occupied_slot)
		return result
	if has_hippolyta_vertical_free_move:
		_append_move_target_if_legal(state, player, row, col, "back" if row == "front" else "front", col, result)
		if not has_active_morale and free_move_effect.is_empty():
			return result
	else:
		_append_move_target_if_legal(state, player, row, col, "back" if row == "front" else "front", col, result)
	_append_move_target_if_legal(state, player, row, col, row, col - 1, result)
	_append_move_target_if_legal(state, player, row, col, row, col + 1, result)
	return result

func _free_move_effect_allows_any_empty_slot(card_id: String, effect: Dictionary) -> bool:
	if effect.is_empty():
		return false
	return bool(effect.get("any_slot", false)) or str(effect.get("id", "")) == "yoshitsune_reposition"


func _free_move_effect_allows_swap_with_allied_occupied_slot(effect: Dictionary) -> bool:
	if effect.is_empty():
		return false
	return bool(effect.get("swap_with_allied_occupied_slot", false))


func _has_cavalry_free_move_available(state: GameState, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return false
	if not _instance_has_troop_type(state, card_id, "cavalry"):
		return false
	return not bool(instance.flags.get("moved_this_turn", false))

func _append_move_target_if_legal(state: GameState, player, from_row: String, from_col: int, target_row: String, target_col: int, result: Array[Dictionary], allow_swap_with_allied_occupied_slot: bool = false) -> void:
	if target_col < 0 or target_col > 2:
		return
	if target_row != "front" and target_row != "back":
		return
	if target_row == from_row and target_col == from_col:
		return
	if target_row == "back" and from_row != "back" and _is_back_row_blocked_by_calamity(state):
		return
	var target_slot = player.get_slot(target_row, target_col)
	if target_slot == null:
		return
	if target_slot.occupant.is_empty():
		result.append({
			"row": target_row,
			"col": target_col
		})
		return
	if not allow_swap_with_allied_occupied_slot:
		return
	result.append({
		"row": target_row,
		"col": target_col,
		"swap_with_card_id": str(target_slot.occupant)
	})

func _get_required_taunt_targets(state: GameState, attacker_id: String) -> Array[String]:
	var result: Array[String] = []
	if state.current_calamity == "calamity_s02_ds02":
		return result
	if not state.card_instances.has(attacker_id):
		return result
	var attacker = state.card_instances[attacker_id]
	if not attacker.zone.begins_with("battle_"):
		return result
	var defending_player = state.get_player(1 - attacker.controller)
	for slot in defending_player.battle_front:
		if not slot.occupant.is_empty() and _is_taunt_unit(state, slot.occupant):
			result.append(slot.occupant)
	for slot in defending_player.battle_back:
		if not slot.occupant.is_empty() and _is_taunt_unit(state, slot.occupant):
			result.append(slot.occupant)
	return result

func _has_required_taunt_target(state: GameState, attacker_id: String) -> bool:
	return not _get_required_taunt_targets(state, attacker_id).is_empty()

func _current_calamity_requires_legion_targets_first(state: GameState, attacker_id: String) -> bool:
	return state.current_calamity == "sys_calamity_embers" and not _get_attackable_legion_targets(state, attacker_id).is_empty()

func _get_attackable_legion_targets(state: GameState, attacker_id: String) -> Array[String]:
	var result: Array[String] = []
	if not state.card_instances.has(attacker_id):
		return result
	var attacker = state.card_instances[attacker_id]
	if not attacker.zone.begins_with("battle_"):
		return result
	var defending_player = state.get_player(1 - attacker.controller)
	for slot in defending_player.battle_front:
		if _can_attack_card(state, attacker_id, slot.occupant):
			result.append(slot.occupant)
	for slot in defending_player.battle_back:
		if _can_attack_card(state, attacker_id, slot.occupant):
			result.append(slot.occupant)
	return result

func _is_taunt_unit(state: GameState, card_id: String) -> bool:
	if _has_attack_keyword(state, card_id, "taunt"):
		return true
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	return int(instance.flags.get("taunt_until_next_own_turn_start_player", -1)) >= 0

func _has_ranged_attack(state: GameState, attacker_id: String) -> bool:
	if state.current_calamity == "calamity_s02_ds04":
		return false
	return _has_attack_keyword(state, attacker_id, "ranged") or _has_attack_keyword(state, attacker_id, "ranged_attack")


func _normalize_troop_type_key(raw_troop_type: String) -> String:
	var normalized := raw_troop_type.strip_edges().to_lower()
	match normalized:
		"术师", "mage", "caster", "wizard":
			return "mage"
		"弓手", "archer":
			return "archer"
		"骑兵", "cavalry":
			return "cavalry"
		_:
			return normalized


func _card_has_troop_type(definition: CardDefinition, troop_type: String) -> bool:
	if definition == null:
		return false
	return _normalize_troop_type_key(str(definition.troop_type)) == _normalize_troop_type_key(troop_type)


func _instance_has_troop_type(state: GameState, card_id: String, troop_type: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	return _card_has_troop_type(state.get_definition(instance.definition_id), troop_type)


func _dark_morning_star_effect_for_player(state: GameState, player_id: int) -> String:
	var player = state.get_player(player_id)
	var effect_state = player.flags.get("dark_morning_star_effect", {})
	if not (effect_state is Dictionary):
		return ""
	if int(effect_state.get("turn", -1)) != state.turn_number:
		return ""
	return str(effect_state.get("effect", ""))


func _can_attack_master_from_back_row_this_turn(state: GameState, attacker_id: String, player_id: int) -> bool:
	var attacker = state.card_instances.get(attacker_id)
	if attacker != null and int(attacker.flags.get("can_attack_master_until_turn_end_turn", -1)) == state.turn_number:
		return true
	return _can_attack_master_from_back_row_under_calamity(state, attacker_id, player_id)

func _can_attack_master_from_back_row_under_calamity(state: GameState, attacker_id: String, player_id: int) -> bool:
	if state.current_calamity != "calamity_s01_ds01":
		return false
	if _dark_morning_star_effect_for_player(state, player_id) != "backline_master_attack":
		return false
	var attacker = state.card_instances.get(attacker_id)
	if attacker == null or str(attacker.position.get("row", "")) != "back":
		return false
	return _instance_has_troop_type(state, attacker_id, "mage") or _instance_has_troop_type(state, attacker_id, "archer")


func _top_deck_troop_type(state: GameState, player_id: int) -> String:
	var player = state.get_player(player_id)
	if player.deck.cards.is_empty():
		return ""
	var top_card_id := str(player.deck.cards[0])
	if top_card_id.is_empty():
		return ""
	var instance = state.card_instances.get(top_card_id)
	if instance == null:
		return ""
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return ""
	return _normalize_troop_type_key(str(definition.troop_type))


func _is_world_upheaval_hand_legion_blocked(state: GameState, player_id: int, card_id: String) -> bool:
	if state.current_calamity != "calamity_s02_ds01":
		return false
	var instance = state.card_instances.get(card_id)
	if instance == null or int(instance.owner) != player_id or str(instance.zone) != "hand":
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null or not definition.is_legion():
		return false
	var hand_troop_type := _normalize_troop_type_key(str(definition.troop_type))
	if hand_troop_type.is_empty():
		return false
	var top_troop_type := _top_deck_troop_type(state, player_id)
	if top_troop_type.is_empty():
		return false
	return hand_troop_type == top_troop_type

func _attack_requires_ranged(state: GameState, attacker_id: String, defender_id: String) -> bool:
	var attacker = state.card_instances.get(attacker_id)
	var defender = state.card_instances.get(defender_id)
	if attacker == null or defender == null:
		return false
	var attacker_row := str(attacker.position.get("row", ""))
	var defender_row := str(defender.position.get("row", ""))
	return attacker_row != "front" or defender_row != "front"


func _is_ranged_attack_geometry_allowed(state: GameState, attacker_id: String, defender_id: String) -> bool:
	var attacker = state.card_instances.get(attacker_id)
	var defender = state.card_instances.get(defender_id)
	if attacker == null or defender == null:
		return false
	var attacker_row := str(attacker.position.get("row", ""))
	var defender_row := str(defender.position.get("row", ""))
	if attacker_row == "front":
		return true
	if attacker_row != "back":
		return false
	if defender_row == "front":
		return true
	if defender_row != "back":
		return false
	return int(attacker.flags.get("yangyouji_can_attack_back_row_turn", -1)) == int(state.turn_number)


func _attacker_ignores_combat_damage(state: GameState, attacker_id: String, defender_id: String) -> bool:
	if _has_attack_keyword(state, attacker_id, "no_damage_on_attack"):
		return true
	if not _is_ranged_combat(state, attacker_id, defender_id):
		return false
	return _has_attack_keyword(state, attacker_id, "attack_no_loss") \
		or _has_attack_keyword(state, attacker_id, "ranged_no_loss")

func _is_ranged_combat(state: GameState, attacker_id: String, defender_id: String) -> bool:
	return _attack_requires_ranged(state, attacker_id, defender_id)

func _find_free_move_effect_for_manual_move(state: GameState, player_id: int, source_id: String) -> Dictionary:
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return {}
	if int(instance.flags.get("free_move_until_turn_end_turn", -1)) == state.turn_number:
		var temporary_effect = {
			"id": str(instance.flags.get("free_move_until_turn_end_effect_id", "granted_free_move")),
			"kind": "activated",
			"once_per_turn_key": str(instance.flags.get("free_move_until_turn_end_once_key", "granted_free_move")),
			"player_once_per_turn": bool(instance.flags.get("free_move_until_turn_end_player_once_per_turn", false)),
			"any_slot": bool(instance.flags.get("free_move_until_turn_end_any_slot", false)),
			"swap_with_allied_occupied_slot": bool(instance.flags.get("free_move_until_turn_end_swap_with_allied_occupied_slot", false))
		}
		if not _validate_effect_availability(state, player_id, source_id, temporary_effect).get("ok", false):
			return {}
		return temporary_effect
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return {}
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "activated":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary) or str(resolution.get("action", "")) != "move_source_one_step":
			continue
		var cost = effect.get("cost", {})
		if cost is Dictionary and not cost.is_empty() and int(cost.get("morale", 0)) > 0:
			continue
		if not _validate_effect_availability(state, player_id, source_id, effect).get("ok", false):
			continue
		return effect.duplicate(true)
	return {}

func _controller_has_rested_hippolyta_vertical_free_move(state: GameState, player_id: int) -> bool:
	for card_id in _get_battlefield_card_ids_for_player(state, player_id):
		var instance = state.card_instances.get(card_id)
		if instance == null or str(instance.orientation) != "rested":
			continue
		if str(instance.definition_id) == "olympus_s02_0510":
			return true
	return false

func _has_attack_keyword(state: GameState, card_id: String, keyword: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return false
	if definition.keywords.has(keyword) or definition.traits.has(keyword):
		return true
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "continuous":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary):
			continue
		if str(resolution.get("action", "")) != "grant_keyword":
			continue
		if str(resolution.get("keyword", "")) != keyword:
			continue
		if str(resolution.get("target_scope", "self")) != "self":
			continue
		var required_row = str(resolution.get("required_row", ""))
		if not required_row.is_empty() and str(instance.position.get("row", "")) != required_row:
			continue
		if bool(resolution.get("only_during_opponent_turn", false)) and instance.controller == state.active_player:
			continue
		return true
	var persistent_keywords = instance.flags.get("persistent_keywords", [])
	if persistent_keywords is Array and persistent_keywords.has(keyword):
		return true
	return int(instance.flags.get("temporary_keyword_%s_turn" % keyword, -1)) == state.turn_number

func _defender_cannot_be_supported(state: GameState, card_id: String, attacker_id: String = "") -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	if int(instance.flags.get("cannot_be_supported_until_turn_end_turn", -1)) == state.turn_number:
		return true
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return false
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "continuous":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary):
			continue
		if str(resolution.get("action", "")) != "cannot_be_supported":
			continue
		if str(resolution.get("target_scope", "self")) != "self":
			continue
		var required_row = str(resolution.get("required_row", ""))
		if not required_row.is_empty() and str(instance.position.get("row", "")) != required_row:
			continue
		if bool(resolution.get("only_when_attacking", false)) and attacker_id != card_id:
			continue
		if bool(resolution.get("only_during_opponent_turn", false)) and instance.controller == state.active_player:
			continue
		return true
	return false


func _defender_cannot_be_attacked(state: GameState, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return false
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "continuous":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary):
			continue
		if str(resolution.get("action", "")) != "cannot_be_attacked":
			continue
		if str(resolution.get("target_scope", "self")) != "self":
			continue
		var required_row = str(resolution.get("required_row", ""))
		if not required_row.is_empty() and str(instance.position.get("row", "")) != required_row:
			continue
		var required_orientation = str(resolution.get("required_orientation", ""))
		if not required_orientation.is_empty() and str(instance.orientation) != required_orientation:
			continue
		if bool(resolution.get("only_during_opponent_turn", false)) and instance.controller == state.active_player:
			continue
		return true
	for source_id in _get_battlefield_card_ids_for_player(state, int(instance.controller)):
		var source_instance = state.card_instances.get(source_id)
		if source_instance == null:
			continue
		var source_definition = state.get_definition(source_instance.definition_id)
		if source_definition == null:
			continue
		for effect in source_definition.effects:
			if str(effect.get("kind", "")) != "continuous":
				continue
			var resolution = effect.get("resolution", {})
			if not (resolution is Dictionary):
				continue
			if str(resolution.get("action", "")) != "cannot_be_attacked":
				continue
			if str(resolution.get("target_scope", "")) != "allied_battlefield":
				continue
			if _cannot_be_attacked_aura_applies_to_target(state, source_instance, resolution, card_id):
				return true
	return false


func _cannot_be_attacked_aura_applies_to_target(state: GameState, source_instance, resolution: Dictionary, target_card_id: String) -> bool:
	if source_instance == null:
		return false
	var target_instance = state.card_instances.get(target_card_id)
	if target_instance == null or not target_instance.zone.begins_with("battle_"):
		return false
	if int(source_instance.controller) != int(target_instance.controller):
		return false
	var required_source_orientation = str(resolution.get("required_source_orientation", ""))
	if not required_source_orientation.is_empty() and str(source_instance.orientation) != required_source_orientation:
		return false
	if bool(resolution.get("only_during_opponent_turn", false)) and int(source_instance.controller) == state.active_player:
		return false
	var target_definition = state.get_definition(target_instance.definition_id)
	if target_definition == null:
		return false
	var required_type = str(resolution.get("type", ""))
	if not required_type.is_empty() and str(target_definition.type) != required_type:
		return false
	var required_definition_id = str(resolution.get("id", ""))
	if not required_definition_id.is_empty() and str(target_definition.id) != required_definition_id:
		return false
	var required_faction = str(resolution.get("faction", ""))
	if not _definition_matches_required_faction_for_instance(state, target_instance, target_definition, required_faction):
		return false
	var target_required_orientation = str(resolution.get("target_required_orientation", ""))
	if not target_required_orientation.is_empty() and str(target_instance.orientation) != target_required_orientation:
		return false
	var target_required_row = str(resolution.get("target_required_row", ""))
	if not target_required_row.is_empty() and str(target_instance.position.get("row", "")) != target_required_row:
		return false
	if bool(resolution.get("target_trial_legion", false)) and not _definition_is_trial_legion(target_definition):
		return false
	return true


func _definition_is_trial_legion(definition) -> bool:
	if definition == null or not definition.is_legion():
		return false
	if _resolution_tree_contains_action(definition.effects, "advance_trial_progress"):
		return true
	for effect in definition.effects:
		if not (effect is Dictionary):
			continue
		var effect_text = str(effect.get("text", ""))
		if effect_text.find("发动试炼") >= 0 or effect_text.find("试炼+") >= 0:
			return true
	return false


func _resolution_tree_contains_action(value, expected_action: String) -> bool:
	if value is Dictionary:
		if str(value.get("action", "")) == expected_action:
			return true
		for nested in value.values():
			if _resolution_tree_contains_action(nested, expected_action):
				return true
	elif value is Array:
		for nested in value:
			if _resolution_tree_contains_action(nested, expected_action):
				return true
	return false


func _attacker_disables_target_support(state: GameState, attacker_id: String) -> bool:
	var attacker = state.card_instances.get(attacker_id)
	if attacker == null:
		return false
	var definition = state.get_definition(attacker.definition_id)
	if definition == null:
		return false
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "continuous":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary):
			continue
		if str(resolution.get("action", "")) != "cannot_be_supported":
			continue
		if str(resolution.get("target_scope", "")) != "attack_target":
			continue
		if bool(resolution.get("only_when_attacking", false)):
			return true
	return false


func _attacker_disables_target_block(state: GameState, attacker_id: String) -> bool:
	var attacker = state.card_instances.get(attacker_id)
	if attacker == null:
		return false
	var definition = state.get_definition(attacker.definition_id)
	if definition == null:
		return false
	if definition.keywords.has("cannot_be_blocked") or definition.keywords.has("must_hit"):
		return true
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "continuous":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary):
			continue
		if str(resolution.get("action", "")) != "cannot_be_blocked":
			continue
		if str(resolution.get("target_scope", "")) != "attack_target":
			continue
		if bool(resolution.get("only_when_attacking", false)):
			return true
	return false

func get_legal_supporters(state: GameState, defending_card_id: String, attacker_id: String) -> Array[String]:
	var result: Array[String] = []
	if state.winner != -1:
		return result
	if not state.card_instances.has(defending_card_id) or not state.card_instances.has(attacker_id):
		return result
	var defender = state.card_instances[defending_card_id]
	var attacker = state.card_instances[attacker_id]
	if not defender.zone.begins_with("battle_") or not attacker.zone.begins_with("battle_"):
		return result
	if defender.controller == attacker.controller:
		return result
	if _defender_cannot_be_supported(state, defending_card_id, attacker_id) or _attacker_disables_target_support(state, attacker_id):
		return result
	var defend_pos: Dictionary = defender.position
	if str(defend_pos.get("row", "")) != "front":
		return result
	var support_slot = state.get_player(defender.controller).get_slot("back", int(defend_pos.get("col", -1)))
	if support_slot == null or support_slot.occupant.is_empty():
		return result
	var supporter_id = support_slot.occupant
	var supporter = state.card_instances[supporter_id]
	if supporter == null:
		return result
	if int(supporter.controller) != int(defender.controller):
		return result
	var supporter_definition = state.get_definition(supporter.definition_id)
	if supporter_definition != null and supporter_definition.keywords.has("cannot_support"):
		return result
	if str(supporter.position.get("row", "")) != "back":
		return result
	if int(supporter.position.get("col", -1)) != int(defend_pos.get("col", -1)):
		return result
	if supporter.orientation != "active":
		return result
	if int(supporter.flags.get("cannot_support_until_turn_end_turn", -1)) == state.turn_number:
		return result
	if _ranged_block_requires_extra_discard(state, attacker_id) and state.get_player(defender.controller).hand.cards.is_empty():
		return result
	var combined_power := get_card_power(state, defending_card_id) + get_card_power(state, supporter_id)
	if combined_power < _combat_attack_power(state, attacker_id, defending_card_id):
		return result
	result.append(supporter_id)
	return result

func _ranged_block_requires_extra_discard(state: GameState, attacker_id: String) -> bool:
	if not state.pending_attack.is_empty() \
			and str(state.pending_attack.get("attacker_id", "")) == attacker_id \
			and bool(state.pending_attack.get("extra_defense_discard_required", false)):
		return true
	var attacker = state.card_instances.get(attacker_id)
	if attacker == null:
		return false
	return str(attacker.definition_id) == "bijie_s02_053"

func get_card_power(state: GameState, card_id: String) -> int:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return 0
	return max(0, _power_before_damage(state, card_id, false) - int(instance.damage_marked))


func _combat_attack_power(state: GameState, attacker_id: String, defender_id: String) -> int:
	var instance = state.card_instances.get(attacker_id)
	if instance == null:
		return 0
	return max(0, _power_before_damage(state, attacker_id, true) - int(instance.damage_marked) + _combat_attacker_power_modifier(state, attacker_id, defender_id))

func get_display_card_power(state: GameState, card_id: String) -> int:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return 0
	var visible_cap := _power_before_damage(state, card_id, true)
	return min(visible_cap, get_card_power(state, card_id))

func _power_before_damage(state: GameState, card_id: String, include_attack_only_modifiers: bool) -> int:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return 0
	var modified_power = int(instance.base_power)
	if int(instance.flags.get("manifested_power", 0)) > 0:
		modified_power = int(instance.flags.get("manifested_power", modified_power))
	if _front_attack_power_bonus_applies(instance, state.turn_number):
		var row = str(instance.position.get("row", ""))
		if row == "front":
			modified_power += int(instance.flags.get("front_attack_power_bonus_amount", 0))
	if int(instance.flags.get("power_modifier_until_turn_end_turn", -1)) == state.turn_number:
		modified_power += int(instance.flags.get("power_modifier_until_turn_end_amount", 0))
	modified_power += int(instance.flags.get("persistent_power_bonus", 0))
	modified_power += _timed_modifier_amount_for_card(state, card_id, "power", include_attack_only_modifiers)
	for modifier in state.continuous_modifiers:
		if not _continuous_modifier_applies_to_card(state, modifier, card_id):
			continue
		if bool(modifier.get("only_when_attacking", false)) and not include_attack_only_modifiers:
			continue
		if str(modifier.get("stat", "")) == "power":
			modified_power += int(modifier.get("amount", 0))
	if int(instance.flags.get("fixed_power_until_turn_end_turn", -1)) == state.turn_number:
		modified_power = int(instance.flags.get("fixed_power_until_turn_end_value", modified_power))
	if str(instance.definition_id) == "suncity_s01_0212" and state.get_player(int(instance.controller)).master_definition_id == "suncity_s01_02m2":
		modified_power += 1000
	if str(instance.definition_id) == "suncity_s01_0203" and int(instance.controller) != state.active_player and not _controller_has_definition_on_battlefield(state, int(instance.controller), "suncity_s01_0212"):
		modified_power += 1000
	if str(instance.definition_id) == "suncity_s01_0204":
		modified_power += 1000 * _suncity_tomb_construct_attached_count(instance)
	return max(0, modified_power)

func _suncity_tomb_construct_attached_count(instance) -> int:
	if instance == null:
		return 0
	var attached = instance.flags.get("suncity_tomb_construct_underlays", [])
	if not (attached is Array):
		return 0
	return attached.size()

func _front_attack_power_bonus_applies(instance, current_turn: int) -> bool:
	return int(instance.flags.get("front_attack_power_bonus_turn", -1)) == current_turn

func _master_damage_bonus_for_attacker(state: GameState, attacker_id: String) -> int:
	var instance = state.card_instances.get(attacker_id)
	if instance == null:
		return 0
	var bonus := 0
	if _has_attack_keyword(state, attacker_id, "strong_attack"):
		bonus += 1
	var definition = state.get_definition(instance.definition_id)
	if definition != null and state.current_calamity == "calamity_s01_ds02" and int(definition.calamity_level) > 0:
		bonus += 1
	if int(instance.flags.get("master_damage_bonus_turn", -1)) != state.turn_number:
		return bonus
	return bonus + int(instance.flags.get("master_damage_bonus_amount", 0))

func _refresh_continuous_modifiers(state: GameState) -> void:
	state.continuous_modifiers = _collect_continuous_modifiers(state)

func _collect_continuous_modifiers(state: GameState) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	for card_id in _get_battlefield_card_ids(state):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		for effect in definition.effects:
			if str(effect.get("kind", "")) != "continuous":
				continue
			var resolution = effect.get("resolution", {})
			if not (resolution is Dictionary):
				continue
			if str(resolution.get("action", "")) != "modify_power":
				continue
			modifiers.append({
				"source_id": card_id,
				"effect_id": str(effect.get("id", "")),
				"stat": "power",
				"amount": int(resolution.get("amount", 0)),
				"target_scope": str(resolution.get("target_scope", "allied_battlefield")),
				"exclude_self": bool(resolution.get("exclude_self", false)),
				"required_faction": str(resolution.get("faction", "")),
				"required_row": str(resolution.get("required_row", "")),
				"source_required_row": str(resolution.get("source_required_row", "")),
				"only_during_opponent_turn": bool(resolution.get("only_during_opponent_turn", false)),
				"only_when_attacking": bool(resolution.get("only_when_attacking", false))
			})
	return modifiers

func _continuous_modifier_applies_to_card(state: GameState, modifier: Dictionary, card_id: String) -> bool:
	var source_id = str(modifier.get("source_id", ""))
	var source_instance = state.card_instances.get(source_id)
	var target_instance = state.card_instances.get(card_id)
	if source_instance == null or target_instance == null:
		return false
	if not target_instance.zone.begins_with("battle_"):
		return false
	var source_required_row = str(modifier.get("source_required_row", ""))
	if not source_required_row.is_empty() and str(source_instance.position.get("row", "")) != source_required_row:
		return false
	if bool(modifier.get("only_during_opponent_turn", false)) and source_instance.controller == state.active_player:
		return false
	if bool(modifier.get("exclude_self", false)) and source_id == card_id:
		return false
	var required_row = str(modifier.get("required_row", ""))
	if not required_row.is_empty() and str(target_instance.position.get("row", "")) != required_row:
		return false
	var required_faction = str(modifier.get("required_faction", ""))
	if not required_faction.is_empty():
		var target_definition = state.get_definition(target_instance.definition_id)
		if target_definition == null or not _definition_matches_required_faction_for_instance(state, target_instance, target_definition, required_faction):
			return false
	match str(modifier.get("target_scope", "allied_battlefield")):
		"allied_battlefield":
			return source_instance.controller == target_instance.controller
		"allied_other_battlefield":
			return source_instance.controller == target_instance.controller and source_id != card_id
		"adjacent_battlefield":
			return source_instance.controller == target_instance.controller and source_id != card_id and _adjacent_battlefield_card_ids(state, source_id).has(card_id)
		"enemy_battlefield":
			return source_instance.controller != target_instance.controller
		"self":
			return source_id == card_id
	return false

func _expire_timed_modifiers_for_player(state: GameState, player_id: int) -> void:
	if state.timed_modifiers.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for modifier in state.timed_modifiers:
		if int(modifier.get("expires_on_player_turn_end", -1)) != player_id:
			remaining.append(modifier)
			continue
		var turns = int(modifier.get("remaining_turn_ends", 1))
		if turns > 1:
			var decremented: Dictionary = modifier.duplicate(true)
			decremented["remaining_turn_ends"] = turns - 1
			remaining.append(decremented)
	state.timed_modifiers = remaining

func _timed_modifier_amount_for_card(state: GameState, card_id: String, stat: String, include_attack_only_modifiers: bool) -> int:
	if state.timed_modifiers.is_empty():
		return 0
	var total := 0
	for modifier in state.timed_modifiers:
		if str(modifier.get("stat", "")) != stat:
			continue
		if bool(modifier.get("only_when_attacking", false)) and not include_attack_only_modifiers:
			continue
		if not _timed_modifier_applies_to_card(state, modifier, card_id):
			continue
		total += int(modifier.get("amount", 0))
	return total

func _timed_modifier_applies_to_card(state: GameState, modifier: Dictionary, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	var target_card_id = str(modifier.get("target_card_id", ""))
	if not target_card_id.is_empty():
		if target_card_id != card_id:
			return false
		if str(modifier.get("stat", "")) == "cost":
			return true
		return str(instance.zone).begins_with("battle_")
	if not str(instance.zone).begins_with("battle_"):
		return false
	var source_player_id = int(modifier.get("source_player_id", -1))
	match str(modifier.get("target_scope", "")):
		"allied_battlefield":
			if source_player_id != int(instance.controller):
				return false
		"enemy_battlefield":
			if source_player_id == int(instance.controller):
				return false
		"all_battlefield":
			pass
		_:
			return false
	var filters = modifier.get("filters", {})
	if filters is Dictionary and not filters.is_empty():
		var stack_item := {"controller": source_player_id, "resolution": filters}
		return _target_card_matches_stack_resolution_filters(state, stack_item, card_id)
	return true

func get_legal_blockers(state: GameState, defending_player_id: int, attacker_id: String, defender_id: String = "") -> Array[String]:
	return []

func get_defense_options(state: GameState, attacker_id: String, target: Dictionary) -> Dictionary:
	var result = {
		"blockers": [],
		"supporters": []
	}
	if state.winner != -1:
		return result
	var target_kind = str(target.get("target_kind", "card"))
	if target_kind == "master":
		return result
	var defender_id = str(target.get("defender_id", ""))
	if not state.card_instances.has(defender_id):
		return result
	result["supporters"] = get_legal_supporters(state, defender_id, attacker_id)
	return result

func get_legal_master_guard_card_sets(state: GameState, defending_player_id: int, attacker_id: String, target: Dictionary) -> Array:
	var result: Array = []
	if str(target.get("target_kind", "")) != "master":
		return result
	if int(target.get("target_player", -1)) != defending_player_id:
		return result
	var required_power = max(1, get_card_power(state, attacker_id))
	var candidates: Array[String] = []
	for card_id in state.get_player(defending_player_id).hand.cards:
		var definition = _definition_for_instance(state, card_id)
		if definition != null and definition.is_legion():
			candidates.append(card_id)
	if candidates.is_empty():
		return result
	var combos: Array[Dictionary] = []
	var total_masks = 1 << candidates.size()
	for mask in range(1, total_masks):
		var combo: Array[String] = []
		var combo_power: int = 0
		for index in range(candidates.size()):
			if (mask & (1 << index)) == 0:
				continue
			var combo_card_id = candidates[index]
			combo.append(combo_card_id)
			combo_power += max(1, get_card_power(state, combo_card_id))
		if combo_power >= required_power:
			combos.append({
				"cards": combo,
				"power": combo_power,
				"count": combo.size()
			})
	if combos.is_empty():
		return result
	combos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var count_a = int(a.get("count", 0))
		var count_b = int(b.get("count", 0))
		if count_a != count_b:
			return count_a < count_b
		var power_a = int(a.get("power", 0))
		var power_b = int(b.get("power", 0))
		if power_a != power_b:
			return power_a < power_b
		return _join_card_names(state, a.get("cards", [])) < _join_card_names(state, b.get("cards", []))
	)
	for combo_entry in combos:
		result.append(_payload_string_array(combo_entry.get("cards", [])))
		if result.size() >= 32:
			break
	return result

func _definition_for_instance(state: GameState, card_id: String) -> CardDefinition:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return null
	return state.get_definition(instance.definition_id)

func export_replay_data(state: GameState) -> Dictionary:
	var commands: Array[Dictionary] = []
	for row in state.command_log:
		commands.append({
			"index": row.get("index", 0),
			"command_id": row.get("command_id", ""),
			"player_id": row.get("player_id", -1),
			"type": row.get("type", ""),
			"phase_before": row.get("phase_before", ""),
			"phase_after": row.get("phase_after", ""),
			"payload": row.get("payload", {}).duplicate(true),
			"client_time": row.get("client_time", 0),
			"source": row.get("source", "local"),
			"state_hash_before": row.get("state_hash_before", ""),
			"state_hash_after": row.get("state_hash_after", ""),
			"ok": row.get("ok", false)
		})
	return {
		"version": 1,
		"ruleset_id": state.ruleset_id,
		"seed": state.seed,
		"initial_decks": state.initial_decks.duplicate(true),
		"winner": state.winner,
		"loss_reason": state.loss_reason,
		"commands": commands
	}

func export_replay_data_v2(state: GameState, meta: Dictionary = {}, history_info: Dictionary = {}, game_options: Dictionary = {}) -> Dictionary:
	var commands: Array[Dictionary] = []
	for row in state.command_log:
		commands.append({
			"index": row.get("index", 0),
			"command_id": row.get("command_id", ""),
			"player_id": row.get("player_id", -1),
			"type": row.get("type", ""),
			"phase_before": row.get("phase_before", ""),
			"phase_after": row.get("phase_after", ""),
			"turn_before": row.get("turn_before", 0),
			"turn_after": row.get("turn_after", 0),
			"payload": row.get("payload", {}).duplicate(true),
			"client_time": row.get("client_time", 0),
			"source": row.get("source", "local"),
			"state_hash_before": row.get("state_hash_before", ""),
			"state_hash_after": row.get("state_hash_after", ""),
			"ok": row.get("ok", false)
		})
	var started_at := int(meta.get("started_at", 0))
	var finished_at := int(meta.get("finished_at", 0))
	var created_at := int(meta.get("created_at", finished_at if finished_at > 0 else Time.get_unix_time_from_system()))
	var replay_id := str(meta.get("replay_id", ""))
	var game_version := str(meta.get("game_version", ""))
	var card_pool_hash := str(meta.get("card_pool_hash", ""))
	var exported_by := str(meta.get("exported_by", "client"))
	var setup_players: Array[Dictionary] = []
	for player_id in range(min(2, state.players.size())):
		var player = state.players[player_id]
		var deck_cards: Array[String] = []
		if player_id < state.initial_decks.size() and state.initial_decks[player_id] is Array:
			for card_id in state.initial_decks[player_id]:
				deck_cards.append(str(card_id))
		setup_players.append({
			"player_id": player_id,
			"name": str(player.name),
			"master_id": str(player.master_definition_id),
			"master_name": str(player.master_name),
			"deck_name": "",
			"deck_cards": deck_cards
		})
	while setup_players.size() < 2:
		var missing_id = setup_players.size()
		setup_players.append({
			"player_id": missing_id,
			"name": "Player %s" % (missing_id + 1),
			"master_id": "",
			"master_name": "",
			"deck_name": "",
			"deck_cards": []
		})
	var winner_master_id := ""
	var winner_master_name := ""
	if state.winner >= 0 and state.winner < setup_players.size():
		winner_master_id = str(setup_players[state.winner].get("master_id", ""))
		winner_master_name = str(setup_players[state.winner].get("master_name", ""))
	var mode := str(history_info.get("mode", "unknown"))
	var status := str(history_info.get("status", "finished" if state.winner != -1 else "interrupted"))
	return {
		"format": "l12_replay",
		"version": 2,
		"metadata": {
			"replay_id": replay_id,
			"created_at": created_at,
			"started_at": started_at,
			"finished_at": finished_at,
			"game_version": game_version,
			"ruleset_id": state.ruleset_id,
			"card_pool_hash": card_pool_hash,
			"exported_by": exported_by
		},
		"history_info": {
			"mode": mode,
			"status": status,
			"source_record_id": str(history_info.get("source_record_id", "")),
			"source_command_index": int(history_info.get("source_command_index", -1)),
			"duel_log_path": str(history_info.get("duel_log_path", "")),
			"ai_log_path": str(history_info.get("ai_log_path", ""))
		},
		"setup": {
			"seed": state.seed,
			"game_options": game_options.duplicate(true),
			"players": setup_players
		},
		"result": {
			"winner": state.winner,
			"winner_master_id": winner_master_id,
			"winner_master_name": winner_master_name,
			"loss_reason": state.loss_reason
		},
		"commands": commands
	}

func _begin_next_turn(state: GameState) -> void:
	_begin_turn_for_player(state, 1 - state.active_player)

func _begin_turn_for_player(state: GameState, next_active_player: int) -> void:
	state.active_player = next_active_player
	state.priority_player = state.active_player
	state.turn_number += 1
	for player in state.players:
		player.once_per_turn.clear()
		player.flags.erase("next_played_legion_keyword")
		player.flags.erase("played_legion_keyword_until_turn_end")
		player.flags.erase("dark_morning_star_effect")
		player.flags.erase("last_active_tactic")
		player.flags.erase("legion_source_heal_block_until_turn_end")
		player.flags.erase("master_damage_taken_this_turn_count")
		player.flags.erase("master_damage_taken_this_turn")
		player.flags.erase("master_effect_damage_taken_this_turn")
		player.flags.erase("tianting_next_tactic_free")
		player.flags.erase("tianting_morale_add_locked_turn")
		player.flags.erase("suncity_tomb_left_count")
		player.flags.erase("suncity_next_calamity_discount")
		player.flags.erase("temporary_morale_turn")
		player.flags.erase("temporary_morale_count")
		player.flags.erase("free_master_morale_effect_activation_turn")
		player.flags.erase("free_master_morale_effect_activation_count")
		if player.player_id == state.active_player:
			player.flags.erase("master_cannot_be_attacked_until_next_own_turn_start")
	for instance in state.card_instances.values():
		instance.flags.erase("front_attack_power_bonus_turn")
		instance.flags.erase("front_attack_power_bonus_amount")
		instance.flags.erase("free_move_until_turn_end_turn")
		instance.flags.erase("free_move_until_turn_end_effect_id")
		instance.flags.erase("free_move_until_turn_end_once_key")
		instance.flags.erase("free_move_until_turn_end_player_once_per_turn")
		instance.flags.erase("free_move_until_turn_end_any_slot")
		instance.flags.erase("free_move_until_turn_end_swap_with_allied_occupied_slot")
		instance.flags.erase("moved_this_turn")
		instance.flags.erase("cannot_die_until_turn_end_turn")
		instance.flags.erase("fixed_power_until_turn_end_turn")
		instance.flags.erase("fixed_power_until_turn_end_value")
		instance.flags.erase("master_damage_bonus_turn")
		instance.flags.erase("master_damage_bonus_amount")
		instance.flags.erase("cost_modifier_until_turn_end")
		instance.flags.erase("cannot_support_until_turn_end_turn")
		instance.flags.erase("power_modifier_until_turn_end_turn")
		instance.flags.erase("power_modifier_until_turn_end_amount")
		if int(instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) == state.active_player:
			instance.flags.erase("cannot_die_until_next_own_turn_start_player")
			instance.flags.erase("cannot_die_until_next_own_turn_start_used")
		if int(instance.flags.get("counter_tactic_disabled_until_next_own_turn_start_player", -1)) == state.active_player:
			instance.flags.erase("counter_tactic_disabled_until_next_own_turn_start_player")
		if int(instance.flags.get("cannot_ready_on_ready_phase_player", -1)) == state.active_player:
			instance.flags.erase("cannot_ready_on_ready_phase_player")
		if int(instance.flags.get("taunt_until_next_own_turn_start_player", -1)) == state.active_player:
			instance.flags.erase("taunt_until_next_own_turn_start_player")
		if instance.controller == state.active_player:
			instance.has_attacked_this_turn = false

func _start_new_turn_for_player(state: GameState, player_id: int, command_id: String) -> Array:
	var previous_phase := str(state.phase)
	_begin_turn_for_player(state, player_id)
	state.phase = "ready"
	var events: Array = []
	var extra_turn_event = GameEvent.create(state.next_event_id(), "ExtraTurnStarted", player_id, {
		"player_id": player_id,
		"turn_number": state.turn_number
	})
	extra_turn_event.created_by_command = command_id
	state.event_log.append(extra_turn_event)
	events.append(extra_turn_event)
	var phase_event = GameEvent.create(state.next_event_id(), "PhaseChanged", player_id, {
		"from": previous_phase,
		"to": "ready",
		"turn_number": state.turn_number
	})
	phase_event.created_by_command = command_id
	state.event_log.append(phase_event)
	events.append(phase_event)
	events.append_array(_on_enter_phase(state, command_id))
	return events

func _on_enter_phase(state: GameState, command_id: String) -> Array:
	var events: Array = []
	match state.phase:
		"ready":
			events.append_array(_apply_turn_start_calamity_effect(state, command_id))
			var skipped_ready_morale = int(state.get_player(state.active_player).flags.get("suncity_skip_next_ready_morale_count", 0))
			if skipped_ready_morale > 0:
				var spent_morale_count = MoraleActions.count_spent_morale(state, state.active_player)
				events.append_array(MoraleActions.ready_spent_morale(state, state.active_player, max(0, spent_morale_count - skipped_ready_morale), command_id))
				for cost_card_id in state.get_player(state.active_player).cost_area.cards:
					var active_morale = state.card_instances.get(str(cost_card_id))
					if active_morale != null:
						active_morale.orientation = "active"
				state.get_player(state.active_player).flags.erase("suncity_skip_next_ready_morale_count")
			else:
				events.append_array(MoraleActions.ready_all_morale(state, state.active_player, command_id))
			for card_id in state.get_player(state.active_player).cost_area.cards:
				var morale_instance = state.card_instances.get(str(card_id))
				if morale_instance != null and int(morale_instance.flags.get("cannot_ready_on_ready_phase_player", -1)) == state.active_player:
					morale_instance.orientation = "rested"
					morale_instance.flags.erase("cannot_ready_on_ready_phase_player")
			for slot in state.get_player(state.active_player).battle_front:
				if not slot.occupant.is_empty():
					var front_instance = state.card_instances[slot.occupant]
					if int(front_instance.flags.get("cannot_ready_on_ready_phase_player", -1)) == state.active_player:
						front_instance.flags.erase("cannot_ready_on_ready_phase_player")
					else:
						front_instance.orientation = "active"
			for slot in state.get_player(state.active_player).battle_back:
				if not slot.occupant.is_empty():
					var back_instance = state.card_instances[slot.occupant]
					if int(back_instance.flags.get("cannot_ready_on_ready_phase_player", -1)) == state.active_player:
						back_instance.flags.erase("cannot_ready_on_ready_phase_player")
					else:
						back_instance.orientation = "active"
			for card_id in state.get_player(state.active_player).artifact_zone.cards:
				if state.card_instances.has(card_id):
					state.card_instances[card_id].orientation = "active"
		"draw":
			if _master_replaces_draw_phase_with_mill(state, state.active_player):
				events.append_array(DrawActions.mill_cards(state, state.active_player, 2, command_id))
			else:
				events.append_array(DrawActions.draw_cards(state, state.active_player, _rules_int(state, "turn_start_draw_count", 1), command_id))
		"morale":
			events.append_array(MoraleActions.add_morale_from_cost_deck(state, state.active_player, _rules_int(state, "turn_start_morale_count", 2), "active", command_id))
		"main":
			events.append_array(_apply_main_phase_calamity_effect(state, command_id))
		"end":
			events.append_array(_apply_end_phase_rule_effects(state, command_id))
			if state.pending_choices.is_empty():
				events.append_array(_apply_end_phase_calamity_effect(state, command_id))
	return events

func _apply_end_phase_rule_effects(state: GameState, command_id: String) -> Array:
	var player_id := int(state.active_player)
	if not _player_has_active_artifact_definition(state, player_id, "asgard_s02_0305"):
		return []
	var discard_count = max(0, state.get_player(player_id).hand.cards.size() - 6)
	if discard_count <= 0:
		return []
	return _request_hand_discard_choice_from_resolution(state, {
		"controller": player_id,
		"resolution": {
			"action": "request_hand_discard_choice",
			"player_id": player_id,
			"discard_count": discard_count,
			"requires_confirm": true,
			"title": "安德华拉诺特：选择弃置的手牌",
			"hint_text": "安德华拉诺特：请弃置手牌，直到手牌数量不高于6张。",
			"top_hint_text": "安德华拉诺特：请弃置多余手牌。"
		}
	}, command_id)

func _player_has_active_artifact_definition(state: GameState, player_id: int, definition_id: String) -> bool:
	if player_id < 0 or player_id >= state.players.size():
		return false
	for card_id in state.get_player(player_id).artifact_zone.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return true
	return false

func _master_faction_for_player(state: GameState, player_id: int) -> String:
	if player_id < 0 or player_id >= state.players.size():
		return ""
	var master_definition_id := str(state.get_player(player_id).master_definition_id)
	if master_definition_id.is_empty():
		return ""
	return master_definition_id.split("_", false, 1)[0]

func _player_treats_neutral_as_master_faction(state: GameState, player_id: int) -> bool:
	return _player_has_active_artifact_definition(state, player_id, "neutral_s02_0008")

func _definition_matches_required_faction_for_player(state: GameState, player_id: int, definition, required_faction: String) -> bool:
	if required_faction.is_empty():
		return true
	if definition == null:
		return false
	var card_faction := str(definition.faction)
	if card_faction == required_faction:
		return true
	if card_faction != "neutral" or not _player_treats_neutral_as_master_faction(state, player_id):
		return false
	return _master_faction_for_player(state, player_id) == required_faction

func _definition_matches_required_faction_for_instance(state: GameState, instance, definition, required_faction: String) -> bool:
	if required_faction.is_empty():
		return true
	if instance == null:
		return false
	return _definition_matches_required_faction_for_player(state, int(instance.controller), definition, required_faction)

func _build_rules_config(options: Dictionary) -> Dictionary:
	var requested_mode := str(options.get("mode", ""))
	var config: Dictionary = DEFAULT_RULES_CONFIG.duplicate(true)
	if requested_mode == "formal":
		config = FORMAL_RULES_CONFIG.duplicate(true)
	for key in options.keys():
		config[key] = options[key]
	return config

func _rules_int(state: GameState, key: String, fallback: int) -> int:
	return int(state.rules_config.get(key, fallback))

func _rules_bool(state: GameState, key: String, fallback: bool) -> bool:
	return bool(state.rules_config.get(key, fallback))


func _uses_formal_rules(state: GameState) -> bool:
	return str(state.rules_config.get("mode", "demo")) == "formal"

func _shuffle_player_decks_if_needed(state: GameState) -> void:
	if not _rules_bool(state, "shuffle_player_decks", false):
		return
	for player in state.players:
		_shuffle_cards_in_place(state, player.deck.cards)

func _shuffle_cards_in_place(state: GameState, cards: Array[String]) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := state.rng.next_int(index + 1)
		if swap_index == index:
			continue
		var buffer := cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = buffer

func _restore_battlefield_legions(state: GameState, command_id: String) -> Array:
	var events: Array = []
	if not _rules_bool(state, "restore_battlefield_power_on_turn_end", false):
		return events
	for card_id in state.card_instances.keys():
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		if not _instance_counts_as_legion(state, instance):
			continue
		var restored_amount := int(instance.damage_marked)
		if restored_amount <= 0:
			continue
		instance.damage_marked = 0
		var event = GameEvent.create(state.next_event_id(), "CardHealed", int(instance.controller), {
			"card_id": card_id,
			"amount": restored_amount,
			"current_power": get_card_power(state, card_id)
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _apply_legion_entry_calamity(state: GameState, instance, definition: CardDefinition, command_id: String) -> Array:
	var events: Array = []
	if not _rules_bool(state, "legion_entry_adds_calamity", false):
		return events
	if definition == null or not definition.is_legion():
		return events
	if not instance.zone.begins_with("battle_"):
		return events
	var added_value: int = max(0, int(definition.calamity_level))
	if added_value <= 0 or state.calamity_value_locked:
		return events
	state.calamity_value += added_value
	var value_event = GameEvent.create(state.next_event_id(), "CalamityValueChanged", int(instance.controller), {
		"value": state.calamity_value,
		"reason": "legion_entry",
		"card_id": str(instance.instance_id),
		"amount": added_value
	})
	value_event.created_by_command = command_id
	state.event_log.append(value_event)
	events.append(value_event)
	if state.calamity_value > 8:
		events.append_array(_reveal_calamity(state, "", command_id))
	return events

func _apply_legion_entry_calamity_for_card(state: GameState, card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var definition = state.get_definition(str(instance.definition_id))
	if definition == null:
		return []
	return _apply_legion_entry_calamity(state, instance, definition, command_id)

func _resolve_block(state: GameState, attacker_id: String, blocker_id: String, command_id: String) -> Array:
	var events: Array = []
	var blocker = state.card_instances[blocker_id]
	var defender_player = state.get_player(blocker.controller)
	var blocker_row := str(blocker.position.get("row", ""))
	var blocker_col := int(blocker.position.get("col", -1))
	if blocker_row == "front" or blocker_row == "back":
		var blocker_slot = defender_player.get_slot(blocker_row, blocker_col)
		if blocker_slot != null and str(blocker_slot.occupant) == blocker_id:
			blocker_slot.occupant = ""
	defender_player.grave.add_card_to_top(blocker_id)
	blocker.zone = "grave"
	blocker.position = {}
	blocker.orientation = "active"
	var block_event = GameEvent.create(state.next_event_id(), "BlockDeclared", blocker.controller, {
		"attacker_id": attacker_id,
		"blocker_id": blocker_id
	})
	block_event.created_by_command = command_id
	state.event_log.append(block_event)
	events.append(block_event)
	var move_event = GameEvent.create(state.next_event_id(), "BlockCardSentToGrave", blocker.controller, {
		"blocker_id": blocker_id
	})
	move_event.created_by_command = command_id
	state.event_log.append(move_event)
	events.append(move_event)
	var attacker = state.card_instances[attacker_id]
	attacker.has_attacked_this_turn = true
	attacker.orientation = "rested"
	return events

func _collect_matching_card_ids_from_controller_regions(state: GameState, controller: int, resolution: Dictionary) -> Array[String]:
	var candidates: Array[String] = []
	var seen := {}
	var player = state.get_player(controller)
	for card_id in player.hand.cards:
		var instance_id = str(card_id)
		if seen.has(instance_id):
			continue
		var instance = state.card_instances.get(instance_id)
		if instance == null:
			continue
		if _card_matches_resolution_definition_filters(state, instance_id, resolution):
			seen[instance_id] = true
			candidates.append(instance_id)
	for card_id in player.deck.cards:
		var instance_id = str(card_id)
		if seen.has(instance_id):
			continue
		var instance = state.card_instances.get(instance_id)
		if instance == null:
			continue
		if _card_matches_resolution_definition_filters(state, instance_id, resolution):
			seen[instance_id] = true
			candidates.append(instance_id)
	for card_id in player.grave.cards:
		var instance_id = str(card_id)
		if seen.has(instance_id):
			continue
		var instance = state.card_instances.get(instance_id)
		if instance == null:
			continue
		if _card_matches_resolution_definition_filters(state, instance_id, resolution):
			seen[instance_id] = true
			candidates.append(instance_id)
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance_id = str(card_id)
		if seen.has(instance_id):
			continue
		if _card_matches_resolution_definition_filters(state, instance_id, resolution):
			seen[instance_id] = true
			candidates.append(instance_id)
	return candidates

func _card_matches_resolution_definition_filters(state: GameState, card_id: String, resolution: Dictionary) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return false
	var required_id = str(resolution.get("id", ""))
	if not required_id.is_empty() and str(definition.id) != required_id:
		return false
	var required_type = str(resolution.get("type", ""))
	if not required_type.is_empty() and str(definition.type) != required_type:
		return false
	var required_faction = str(resolution.get("faction", ""))
	if not _definition_matches_required_faction_for_instance(state, instance, definition, required_faction):
		return false
	return true

func _resolve_master_guard(state: GameState, attacker_id: String, target_player: int, guard_card_ids: Array[String], command_id: String) -> Array:
	var events = ZoneActions.discard_specific_from_hand(state, target_player, guard_card_ids, command_id)
	var guard_event = GameEvent.create(state.next_event_id(), "MasterGuarded", target_player, {
		"attacker_id": attacker_id,
		"guard_card_ids": guard_card_ids.duplicate(),
		"guard_power": _sum_guard_card_power(state, guard_card_ids),
		"required_power": max(1, get_card_power(state, attacker_id))
	})
	guard_event.created_by_command = command_id
	state.event_log.append(guard_event)
	events.append(guard_event)
	var attacker = state.card_instances[attacker_id]
	if attacker != null:
		attacker.has_attacked_this_turn = true
		attacker.orientation = "rested"
	return events

func _can_attack_card(state: GameState, attacker_id: String, defender_id: String) -> bool:
	if defender_id.is_empty():
		return false
	var probe = GameCommand.create(state.active_player, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	})
	return validate_command(state, probe).get("ok", false)

func _can_attack_master(state: GameState, attacker_id: String, target_player: int) -> bool:
	var probe = GameCommand.create(state.active_player, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "master",
		"target_player": target_player
	})
	return validate_command(state, probe).get("ok", false)

func _is_back_row_blocked_by_calamity(state: GameState) -> bool:
	return state.current_calamity == "sys_calamity_silence"

func _effective_hand_play_cost(state: GameState, card_id: String, play_option: Dictionary = {}, row: String = "") -> int:
	var cost := _get_effective_play_cost(state, card_id, play_option)
	var instance = state.card_instances.get(card_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	if row == "back" and state.current_calamity == "sys_calamity_silence" and definition != null and definition.is_counter_tactic():
		return 0
	return cost

func _reveal_calamity(state: GameState, definition_id: String, command_id: String) -> Array:
	var events: Array = []
	var next_calamity_id = definition_id
	if next_calamity_id.is_empty():
		if not state.calamity_deck.is_empty():
			next_calamity_id = str(state.calamity_deck.pop_front())
		else:
			next_calamity_id = "sys_calamity_annihilation"
	if not state.current_calamity.is_empty():
		state.calamity_grave.append(state.current_calamity)
		var leave_event = GameEvent.create(state.next_event_id(), "CalamityCleared", state.active_player, {
			"calamity_id": state.current_calamity
		})
		leave_event.created_by_command = command_id
		state.event_log.append(leave_event)
		events.append(leave_event)
	state.current_calamity = next_calamity_id
	var reveal_event = GameEvent.create(state.next_event_id(), "CalamityRevealed", state.active_player, {
		"calamity_id": next_calamity_id
	})
	reveal_event.created_by_command = command_id
	state.event_log.append(reveal_event)
	events.append(reveal_event)
	events.append_array(_resolve_calamity_effect(state, next_calamity_id, command_id))
	if next_calamity_id == "sys_calamity_annihilation":
		state.calamity_value_locked = true
	state.calamity_value = 0
	var value_event = GameEvent.create(state.next_event_id(), "CalamityValueChanged", state.active_player, {"value": state.calamity_value})
	value_event.created_by_command = command_id
	state.event_log.append(value_event)
	events.append(value_event)
	return events

func _calamity_event_options(calamity_id: String) -> Dictionary:
	return {
		"source_kind": "calamity",
		"reason": "calamity",
		"calamity_id": calamity_id,
		"suppress_triggers": true,
		"ignore_leave_interceptors": true,
		"unpreventable_leave": true
	}

func _merge_event_payload_options(base_payload: Dictionary, options: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = base_payload.duplicate(true)
	for key in ["source_kind", "source_card_id", "source_player_id", "reason", "calamity_id", "suppress_triggers"]:
		if options.has(key):
			payload[key] = options[key]
	return payload


func _effect_event_options_from_stack_item(state: GameState, stack_item: Dictionary, resolution: Dictionary = {}) -> Dictionary:
	var options: Dictionary = resolution.get("event_options", {}).duplicate(true) if resolution.get("event_options", {}) is Dictionary else {}
	if not options.has("source_kind"):
		options["source_kind"] = "effect"
	var source_id := str(stack_item.get("source_instance_id", ""))
	if not source_id.is_empty() and not options.has("source_card_id"):
		options["source_card_id"] = source_id
	if not options.has("source_player_id"):
		options["source_player_id"] = int(stack_item.get("controller", state.active_player))
	return options

func _event_suppresses_triggers(event) -> bool:
	if event == null:
		return false
	var payload = event.payload
	if not (payload is Dictionary):
		return false
	if bool(payload.get("suppress_triggers", false)):
		return true
	if str(payload.get("source_kind", "")) == "calamity":
		return true
	var reason := str(payload.get("reason", ""))
	return reason == "calamity" or reason == "calamity_trigger"

func _resolve_calamity_effect(state: GameState, calamity_id: String, command_id: String) -> Array:
	var events: Array = []
	match calamity_id:
		"calamity_s01_ds01":
			pass
		"calamity_s02_ds01":
			events.append_array(_resolve_world_upheaval_calamity(state, command_id))
		"sys_calamity_embers":
			var embers_options := _calamity_event_options(calamity_id)
			events.append_array(_deal_master_damage(state, 0, 1, command_id, {
				"non_lethal": true,
				"source_kind": str(embers_options.get("source_kind", "")),
				"reason": str(embers_options.get("reason", "")),
				"calamity_id": str(embers_options.get("calamity_id", "")),
				"suppress_triggers": bool(embers_options.get("suppress_triggers", false))
			}))
			events.append_array(_deal_master_damage(state, 1, 1, command_id, {
				"non_lethal": true,
				"source_kind": str(embers_options.get("source_kind", "")),
				"reason": str(embers_options.get("reason", "")),
				"calamity_id": str(embers_options.get("calamity_id", "")),
				"suppress_triggers": bool(embers_options.get("suppress_triggers", false))
			}))
		"sys_calamity_silence":
			events.append_array(_send_all_back_row_legions_to_grave(state, command_id, _calamity_event_options(calamity_id)))
		"calamity_s01_ds02":
			events.append_array(_deal_master_damage(state, 0, 1, command_id, {"non_lethal": true}))
			events.append_array(_deal_master_damage(state, 1, 1, command_id, {"non_lethal": true}))
		"calamity_s01_ds06":
			events.append_array(_resolve_divine_balance_calamity(state, command_id))
		"calamity_s01_ds04":
			events.append_array(_resolve_thunder_wrath_calamity(state, command_id))
		"calamity_s01_ds05":
			events.append_array(_resolve_magic_dragon_calamity(state, command_id))
		"calamity_s02_ds02":
			events.append_array(_resolve_fog_desperation_calamity(state, command_id))
		"calamity_s02_ds03":
			events.append_array(_destroy_low_power_legions_for_calamity(state, 2000, command_id, _calamity_event_options(calamity_id)))
		"calamity_s02_ds04":
			events.append_array(_resolve_storm_chaos_calamity(state, command_id, _calamity_event_options(calamity_id)))
		"calamity_s02_ds06":
			events.append_array(_resolve_pride_sin_calamity(state, command_id))
		"calamity_s01_ds07":
			events.append_array(_resolve_apocalypse_calamity(state, command_id, _calamity_event_options(calamity_id)))
		"calamity_s01_ds09":
			events.append_array(_resolve_ragnarok_calamity(state, command_id, _calamity_event_options(calamity_id)))
		"sys_calamity_annihilation":
			pass
	var resolved_event = GameEvent.create(state.next_event_id(), "CalamityResolved", state.active_player, {
		"calamity_id": calamity_id
	})
	resolved_event.created_by_command = command_id
	state.event_log.append(resolved_event)
	events.append(resolved_event)
	return events

func _send_all_back_row_legions_to_grave(state: GameState, command_id: String, leave_options: Dictionary = {}) -> Array:
	var events: Array = []
	for player_id in range(state.players.size()):
		for col in range(3):
			var slot = state.get_player(player_id).battle_back[col]
			if slot.occupant.is_empty():
				continue
			var instance = state.card_instances.get(str(slot.occupant))
			var definition = state.get_definition(instance.definition_id) if instance != null else null
			if definition == null or not definition.is_legion():
				continue
			events.append_array(ZoneActions.move_battlefield_to_grave(state, player_id, "back", col, command_id, leave_options))
	return events

func _send_all_battlefield_legions_to_grave(state: GameState, command_id: String, leave_options: Dictionary = {}) -> Array:
	var events: Array = []
	for card_id in _get_battlefield_legion_card_ids(state):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var row = str(instance.position.get("row", ""))
		var col = int(instance.position.get("col", -1))
		if row.is_empty() or col < 0:
			continue
		events.append_array(ZoneActions.move_battlefield_to_grave(state, int(instance.controller), row, col, command_id, leave_options))
	return events

func _roll_die(state: GameState, player_id: int, sides: int, command_id: String, payload: Dictionary = {}) -> Dictionary:
	var normalized_sides: int = max(2, sides)
	var result := state.rng.next_int(normalized_sides) + 1
	var event_payload := payload.duplicate(true)
	event_payload["sides"] = normalized_sides
	event_payload["result"] = result
	var event = _append_logged_event(state, "DiceRolled", player_id, event_payload, command_id)
	return {
		"result": result,
		"events": [event]
	}

func _consume_attack_attempt(state: GameState, attacker_id: String, command_id: String, rest_attacker: bool = true) -> Array:
	var events: Array = []
	var attacker = state.card_instances.get(attacker_id)
	if attacker == null:
		return events
	attacker.has_attacked_this_turn = true
	if rest_attacker and attacker.zone.begins_with("battle_"):
		if str(attacker.orientation) != "rested":
			events.append_array(_rest_target_unit(state, attacker_id, command_id))
		else:
			attacker.orientation = "rested"
	return events

func _maybe_resolve_thunder_wrath_attack_roll(state: GameState, attack: Dictionary, player_id: int, command_id: String) -> Dictionary:
	if state.current_calamity != "calamity_s01_ds04":
		return {"attack": attack, "events": [], "canceled": false}
	if bool(attack.get("thunder_wrath_roll_checked", false)):
		return {"attack": attack, "events": [], "canceled": false}
	var attacker_id := str(attack.get("attacker_id", ""))
	if attacker_id.is_empty() or get_card_power(state, attacker_id) <= 2000:
		return {"attack": attack, "events": [], "canceled": false}
	var updated_attack: Dictionary = attack.duplicate(true)
	var events: Array = []
	var roll = _roll_die(state, player_id, 6, command_id, {
		"reason": "attack",
		"card_id": attacker_id,
		"calamity_id": state.current_calamity
	})
	updated_attack["thunder_wrath_roll_checked"] = true
	updated_attack["thunder_wrath_roll_result"] = int(roll.get("result", 0))
	events.append_array(roll.get("events", []))
	if int(roll.get("result", 0)) <= 2:
		events.append_array(_consume_attack_attempt(state, attacker_id, command_id))
		updated_attack["canceled_by_dice"] = true
		events.append(_create_attack_finished_event(state, updated_attack, command_id))
		return {"attack": updated_attack, "events": events, "canceled": true}
	return {"attack": updated_attack, "events": events, "canceled": false}

func _resolve_thunder_wrath_calamity(state: GameState, command_id: String) -> Array:
	var events: Array = []
	var lowest_result := 999
	var lowest_players: Array[int] = []
	for player_id in range(state.players.size()):
		var roll = _roll_die(state, player_id, 6, command_id, {
			"reason": "calamity_trigger",
			"calamity_id": "calamity_s01_ds04"
		})
		events.append_array(roll.get("events", []))
		var result := int(roll.get("result", 0))
		if result < lowest_result:
			lowest_result = result
			lowest_players = [player_id]
		elif result == lowest_result:
			lowest_players.append(player_id)
	var follow_up = _build_return_battlefield_choice_chain(state, lowest_players, 0)
	if follow_up is Dictionary and not follow_up.is_empty():
		events.append_array(_resolve_stack_follow_up_action(state, {"controller": 0, "resolution": {}}, follow_up, command_id))
	return events


func _resolve_magic_dragon_calamity(state: GameState, command_id: String) -> Array:
	var events: Array = []
	var roll = _roll_die(state, state.active_player, 6, command_id, {
		"reason": "calamity_trigger",
		"calamity_id": "calamity_s01_ds05"
	})
	events.append_array(roll.get("events", []))
	var result := int(roll.get("result", 0))
	var target_col := 1
	if result <= 2:
		target_col = 0
	elif result <= 4:
		target_col = 2
	events.append_array(_destroy_column_for_all_players(state, target_col, command_id, _calamity_event_options("calamity_s01_ds05"), false, true, state.active_player))
	var follow_up = _build_magic_dragon_recycle_chain(state, [0, 1], 0)
	if follow_up is Dictionary and not follow_up.is_empty():
		events.append_array(_resolve_stack_follow_up_action(state, {"controller": state.active_player, "resolution": {}}, follow_up, command_id))
	return events


func _resolve_world_upheaval_calamity(state: GameState, command_id: String) -> Array:
	var events: Array = []
	for player in state.players:
		player.deck.cards.reverse()
		for card_id in player.deck.cards:
			var instance = state.card_instances.get(str(card_id))
			if instance == null:
				continue
			instance.face = "face_up"
		events.append(_append_logged_event(state, "DeckReversed", int(player.player_id), {
			"player_id": int(player.player_id),
			"count": player.deck.cards.size(),
			"face": "face_up"
		}, command_id))
	return events


func _destroy_column_for_all_players(state: GameState, col: int, command_id: String, leave_options: Dictionary = {}, legions_only: bool = true, mirror_from_controller: bool = false, controller_player_id: int = -1) -> Array:
	var events: Array = []
	for player_id in range(state.players.size()):
		var target_col := col
		if mirror_from_controller and controller_player_id >= 0 and player_id != controller_player_id:
			target_col = 2 - col
		for row in ["front", "back"]:
			var slot = state.get_player(player_id).get_slot(row, target_col)
			if slot == null or str(slot.occupant).is_empty():
				continue
			if legions_only:
				var instance = state.card_instances.get(str(slot.occupant))
				var definition = state.get_definition(instance.definition_id) if instance != null else null
				if definition == null or not definition.is_legion():
					continue
			events.append_array(ZoneActions.move_battlefield_to_grave(state, player_id, row, target_col, command_id, leave_options))
	return events


func _build_magic_dragon_recycle_chain(state: GameState, player_ids: Array[int], index: int = 0) -> Dictionary:
	for next_index in range(index, player_ids.size()):
		var player_id := int(player_ids[next_index])
		if state.get_player(player_id).grave.cards.is_empty():
			continue
		return {
			"action": "recycle_grave_to_deck",
			"player_id": player_id,
			"event_options": _calamity_event_options("calamity_s01_ds05"),
			"count": 4,
			"always_request_choice": true,
			"requires_confirm": true,
			"drag_reorder_all_candidates": true,
			"title": "魔龙降世：选择返回牌库底部的墓地卡牌",
			"hint_text": "魔龙降世：请选择并确认最多 4 张墓地卡牌，并按顺序返回牌库底部。",
			"top_hint_text": "魔龙降世：拖动调整顺序后确认返回牌库底部。",
			"follow_up_action": _build_magic_dragon_recycle_chain(state, player_ids, next_index + 1)
		}
	return {}

func _build_return_battlefield_choice_chain(state: GameState, player_ids: Array[int], index: int = 0) -> Dictionary:
	for next_index in range(index, player_ids.size()):
		var player_id := int(player_ids[next_index])
		if _get_battlefield_card_ids_for_player(state, player_id).is_empty():
			continue
		return {
			"action": "request_return_battlefield_choice",
			"player_id": player_id,
			"battle_options": _calamity_event_options("calamity_s01_ds04"),
			"legions_only": true,
			"requires_confirm": true,
			"title": "雷霆天怒：选择返回手牌的军团",
			"hint_text": "雷霆天怒：请选择你方 1 张军团，返回所有者手牌。",
			"top_hint_text": "雷霆天怒：请选择并确认要返回手牌的军团。",
			"follow_up_action": _build_return_battlefield_choice_chain(state, player_ids, next_index + 1)
		}
	return {}

func _apply_turn_start_calamity_effect(state: GameState, command_id: String) -> Array:
	var events: Array = []
	match state.current_calamity:
		"sys_calamity_annihilation":
			events.append_array(_deal_master_damage(state, 0, 1, command_id, {"non_lethal": true}))
			events.append_array(_deal_master_damage(state, 1, 1, command_id, {"non_lethal": true}))
		_:
			pass
	return events


func _apply_main_phase_calamity_effect(state: GameState, command_id: String) -> Array:
	var events: Array = []
	if state.current_calamity != "calamity_s01_ds01":
		return events
	var player = state.get_player(state.active_player)
	player.flags.erase("dark_morning_star_effect")
	var roll = _roll_die(state, state.active_player, 6, command_id, {
		"reason": "phase_start",
		"phase": "main",
		"calamity_id": "calamity_s01_ds01"
	})
	events.append_array(roll.get("events", []))
	if int(roll.get("result", 0)) % 2 == 0:
		events.append_array(MoraleActions.consume_morale(state, state.active_player, 1, command_id))
		return events
	return events + _request_option_choice(state, state.active_player, [
		{"id": "free_tactic", "label": "主动战术免费"},
		{"id": "backline_master_attack", "label": "后排术师/弓手可打主宰"}
	], "黯陨晨星：选择本回合生效效果", "dark_morning_star_main_effect", {}, command_id)
	return events

func _apply_end_phase_calamity_effect(state: GameState, command_id: String) -> Array:
	var events: Array = []
	if state.current_calamity != "calamity_s01_ds02":
		return events
	var player_id := int(state.active_player)
	var hand_size := state.get_player(player_id).hand.cards.size()
	if hand_size <= 5:
		return events
	var return_count := hand_size - 5
	var candidate_card_ids: Array[String] = []
	for card_id in state.get_player(player_id).hand.cards:
		candidate_card_ids.append(str(card_id))
	return _request_candidate_cards_choice(state, player_id, candidate_card_ids, return_count, "选择返回牌库底部的手牌", "return_hand_to_deck_bottom", {
		"requires_confirm": true,
		"event_options": _calamity_event_options("calamity_s01_ds02")
	}, command_id)

func _resolve_divine_balance_calamity(state: GameState, command_id: String) -> Array:
	var events: Array = []
	var event_options := _calamity_event_options("calamity_s01_ds06")
	var min_hp := 999
	for player in state.players:
		min_hp = min(min_hp, int(player.master_hp))
	var changed_players: Array[int] = []
	for player_id in range(state.players.size()):
		if state.get_player(player_id).master_hp <= min_hp:
			continue
		events.append_array(_set_master_hp(state, player_id, min_hp, command_id, event_options))
		changed_players.append(player_id)
	if changed_players.is_empty():
		for player_id in range(state.players.size()):
			events.append_array(DrawActions.draw_cards(state, player_id, 1, command_id, event_options))
	else:
		for player_id in changed_players:
			events.append_array(DrawActions.draw_cards(state, player_id, 2, command_id, event_options))
	var discard_then_draw = {
		"action": "request_hand_discard_choice",
		"player_id": 0,
		"event_options": event_options.duplicate(true),
		"discard_count": 1,
		"requires_confirm": true,
		"title": "神之天平：玩家1选择弃置",
		"hint_text": "神之天平：请玩家1选择 1 张手牌并确认弃置。随后玩家2也要弃置，最后双方各抽1张。",
		"top_hint_text": "神之天平：请玩家1选择 1 张手牌并确认弃置。",
		"follow_up_action": {
			"action": "request_hand_discard_choice",
			"player_id": 1,
			"event_options": event_options.duplicate(true),
			"discard_count": 1,
			"requires_confirm": true,
			"title": "神之天平：玩家2选择弃置",
			"hint_text": "神之天平：请玩家2选择 1 张手牌并确认弃置。完成后双方各抽1张。",
			"top_hint_text": "神之天平：请玩家2选择 1 张手牌并确认弃置。",
			"follow_up_action": {
				"action": "draw_cards_after_both_players_discard",
				"controller": 0,
				"opponent": 1,
				"controller_draw": 1,
				"opponent_draw": 1
			}
		}
	}
	events.append_array(_resolve_stack_follow_up_action(state, {"controller": 0, "resolution": {}}, discard_then_draw, command_id))
	return events

func _resolve_fog_desperation_calamity(state: GameState, command_id: String) -> Array:
	var event_options := _calamity_event_options("calamity_s02_ds02")
	var discard_chain = {
		"action": "request_hand_discard_choice",
		"player_id": 0,
		"event_options": event_options.duplicate(true),
		"discard_count": max(0, state.get_player(0).hand.cards.size() - 5),
		"requires_confirm": true,
		"title": "迷雾绝境：玩家1选择弃置",
		"hint_text": "迷雾绝境：请玩家1选择多余手牌并确认弃置，直到手牌不高于5张。随后玩家2也要执行同样操作。",
		"top_hint_text": "迷雾绝境：请玩家1选择多余手牌并确认弃置。",
		"follow_up_action": {
			"action": "request_hand_discard_choice",
			"player_id": 1,
			"event_options": event_options.duplicate(true),
			"discard_count": max(0, state.get_player(1).hand.cards.size() - 5),
			"requires_confirm": true,
			"title": "迷雾绝境：玩家2选择弃置",
			"hint_text": "迷雾绝境：请玩家2选择多余手牌并确认弃置，直到手牌不高于5张。",
			"top_hint_text": "迷雾绝境：请玩家2选择多余手牌并确认弃置。"
		}
	}
	return _resolve_stack_follow_up_action(state, {"controller": 0, "resolution": {}}, discard_chain, command_id)

func _resolve_pride_sin_calamity(state: GameState, command_id: String) -> Array:
	var p0_count := _get_battlefield_card_ids_for_player(state, 0).size()
	var p1_count := _get_battlefield_card_ids_for_player(state, 1).size()
	if p0_count == p1_count:
		return []
	var chooser := 0 if p0_count > p1_count else 1
	var diff: int = abs(p0_count - p1_count)
	return _request_option_choice(state, chooser, [
		{"id": "discard_battlefield", "label": "弃战场军团"},
		{"id": "discard_hand", "label": "弃手牌"}
	], "傲慢之罪：选择以下 1 项", "pride_sin_resolution", {
		"difference": diff,
		"event_options": _calamity_event_options("calamity_s02_ds06")
	}, command_id)

func _resolve_apocalypse_calamity(state: GameState, command_id: String, event_options: Dictionary = {}) -> Array:
	var apocalypse_chain = {
		"action": "request_battlefield_reduce_choice",
		"player_id": 0,
		"battle_options": event_options.duplicate(true),
		"legions_only": true,
		"keep_at_most": 2,
		"requires_confirm": true,
		"title": "天启默示录：玩家1选择保留后的弃置军团",
		"hint_text": "天启默示录：请玩家1选择要置入墓地的军团，直到战场上只剩 2 张军团。随后玩家2也要执行同样操作。",
		"top_hint_text": "天启默示录：请玩家1选择要置入墓地的军团并确认。",
		"follow_up_action": {
			"action": "request_battlefield_reduce_choice",
			"player_id": 1,
			"battle_options": event_options.duplicate(true),
			"legions_only": true,
			"keep_at_most": 2,
			"requires_confirm": true,
			"title": "天启默示录：玩家2选择保留后的弃置军团",
			"hint_text": "天启默示录：请玩家2选择要置入墓地的军团，直到战场上只剩 2 张军团。随后双方依次把全部手牌按自选顺序放回牌库底。",
			"top_hint_text": "天启默示录：请玩家2选择要置入墓地的军团并确认。",
			"follow_up_action": {
				"action": "request_hand_return_to_deck_bottom_choice",
				"player_id": 0,
				"event_options": event_options.duplicate(true),
				"requires_confirm": true,
				"drag_reorder_all_candidates": true,
				"title": "天启默示录：玩家1调整整手回底顺序",
				"hint_text": "天启默示录：请在选择框内拖动全部手牌，调整玩家1整手返回牌库底部的顺序，然后确认。",
				"top_hint_text": "天启默示录：请拖动全部手牌，确定玩家1整手回底顺序。",
				"follow_up_action": {
					"action": "request_hand_return_to_deck_bottom_choice",
					"player_id": 1,
					"event_options": event_options.duplicate(true),
					"requires_confirm": true,
					"drag_reorder_all_candidates": true,
					"title": "天启默示录：玩家2调整整手回底顺序",
					"hint_text": "天启默示录：请在选择框内拖动全部手牌，调整玩家2整手返回牌库底部的顺序，然后确认。完成后双方各抽 4 张牌。",
					"top_hint_text": "天启默示录：请拖动全部手牌，确定玩家2整手回底顺序。",
					"follow_up_action": {
						"action": "draw_cards_for_players",
						"count": 4,
						"event_options": event_options.duplicate(true)
					}
				}
			}
		}
	}
	return _resolve_stack_follow_up_action(state, {"controller": 0, "resolution": {}}, apocalypse_chain, command_id)

func _resolve_ragnarok_calamity(state: GameState, command_id: String, leave_options: Dictionary = {}) -> Array:
	var events: Array = []
	var opening_trigger := state.phase == "calamity"
	var active_player_before := int(state.active_player)
	events.append_array(_send_all_battlefield_legions_to_grave(state, command_id, leave_options))
	if opening_trigger:
		for player_id in range(state.players.size()):
			events.append_array(DrawActions.draw_cards(state, player_id, 2, command_id, leave_options))
		return events
	for player_id in range(state.players.size()):
		if player_id == active_player_before:
			continue
		events.append_array(DrawActions.draw_cards(state, player_id, 2, command_id, leave_options))
	events.append_array(_start_new_turn_for_player(state, active_player_before, command_id))
	return events

func _set_master_hp(state: GameState, player_id: int, hp: int, command_id: String, event_options: Dictionary = {}) -> Array:
	var player = state.get_player(player_id)
	var next_hp: int = max(0, min(player.master_max_hp, hp))
	if next_hp == player.master_hp:
		return []
	player.master_hp = next_hp
	var event = GameEvent.create(state.next_event_id(), "MasterHpSet", player_id, _merge_event_payload_options({
		"hp": player.master_hp
	}, event_options))
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	events.append_array(_check_immediate_loss(state, player_id, command_id))
	return events

func _destroy_low_power_legions_for_calamity(state: GameState, max_base_power: int, command_id: String, leave_options: Dictionary = {}) -> Array:
	var events: Array = []
	for card_id in _get_battlefield_legion_card_ids(state):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		if int(instance.base_power) > max_base_power:
			continue
		var row = str(instance.position.get("row", ""))
		var col = int(instance.position.get("col", -1))
		if row.is_empty() or col < 0:
			continue
		events.append_array(ZoneActions.move_battlefield_to_grave(state, int(instance.controller), row, col, command_id, leave_options))
	return events

func _resolve_storm_chaos_calamity(state: GameState, command_id: String, event_options: Dictionary = {}) -> Array:
	var events: Array = []
	for player_id in range(state.players.size()):
		for col in range(3):
			events.append_array(ZoneActions.return_battlefield_to_hand(state, player_id, "back", col, command_id, event_options))
	for player_id in range(state.players.size()):
		for col in range(3):
			var player = state.get_player(player_id)
			var front_slot = player.battle_front[col]
			if front_slot.occupant.is_empty():
				continue
			var back_slot = player.battle_back[col]
			if not back_slot.occupant.is_empty():
				continue
			var card_id = str(front_slot.occupant)
			var instance = state.card_instances.get(card_id)
			if instance == null:
				continue
			front_slot.occupant = ""
			back_slot.occupant = card_id
			instance.zone = "battle_back"
			instance.position = {"row": "back", "col": col}
			var move_event = GameEvent.create(state.next_event_id(), "CardMoved", player_id, _merge_event_payload_options({
				"card_id": card_id,
				"from_row": "front",
				"from_col": col,
				"to_row": "back",
				"to_col": col,
				"reason": "calamity"
			}, event_options))
			move_event.created_by_command = command_id
			state.event_log.append(move_event)
			_mark_card_as_moved_this_turn(state, card_id)
			events.append(move_event)
	return events

func drain_until_waiting_for_input(state: GameState, source_events: Array, command_id: String) -> Array:
	var all_events: Array = []
	var next_source_events = source_events
	while true:
		var generated_events = _process_generated_events_once(state, next_source_events, command_id)
		if generated_events.is_empty():
			var auto_phase_events = _auto_advance_calamity_phase_if_idle(state, command_id)
			if auto_phase_events.is_empty():
				break
			all_events.append_array(auto_phase_events)
			next_source_events = auto_phase_events
			continue
		all_events.append_array(generated_events)
		if _state_waits_for_player_input(state):
			break
		next_source_events = generated_events
	return all_events

func _auto_advance_calamity_phase_if_idle(state: GameState, command_id: String) -> Array:
	if state == null or state.winner != -1:
		return []
	if state.phase != "calamity":
		return []
	if state.calamity_value > 8:
		return _reveal_calamity(state, "", command_id)
	if _state_waits_for_player_input(state):
		return []
	var phase_info = PhaseMachine.get_next_phase_info(state.phase)
	var previous_phase = String(phase_info.from)
	var next_phase = String(phase_info.to)
	state.phase = next_phase
	state.priority_player = state.active_player
	var phase_event = GameEvent.create(state.next_event_id(), "PhaseChanged", state.active_player, {
		"from": previous_phase,
		"to": next_phase,
		"turn_number": state.turn_number
	})
	phase_event.created_by_command = command_id
	state.event_log.append(phase_event)
	var events: Array = [phase_event]
	events.append_array(_on_enter_phase(state, command_id))
	return events

func _process_generated_events(state: GameState, source_events: Array, command_id: String) -> Array:
	return drain_until_waiting_for_input(state, source_events, command_id)

func _process_generated_events_once(state: GameState, source_events: Array, command_id: String) -> Array:
	var events: Array = []
	events.append_array(_enqueue_pending_triggers(state, source_events))
	if state.stack.is_empty() and state.pending_choices.is_empty() and not state.pending_triggers.is_empty():
		events.append_array(_promote_next_pending_trigger(state, command_id))
	if state.stack.is_empty() and state.pending_choices.is_empty() and state.pending_triggers.is_empty() and _pending_attack_needs_response_window(state):
		events.append_array(_resolve_pending_attack_if_ready(state, command_id))
	return events

func _pending_attack_needs_response_window(state: GameState) -> bool:
	if state.pending_attack.is_empty():
		return false
	return not bool(state.pending_attack.get("response_window_opened", false))

func _state_waits_for_player_input(state: GameState) -> bool:
	if state.winner != -1:
		return true
	if not state.pending_choices.is_empty():
		return true
	if not state.stack.is_empty():
		return true
	if not state.pending_attack.is_empty():
		return true
	return false

func _enqueue_pending_triggers(state: GameState, source_events: Array) -> Array:
	var events: Array = []
	var batched_played_card_ids := {}
	for source_event in source_events:
		if not (source_event is GameEvent):
			continue
		if str(source_event.type) != "CardPlayed":
			continue
		var source_payload = source_event.payload
		if not (source_payload is Dictionary):
			continue
		var played_card_id := str(source_payload.get("card_id", ""))
		if not played_card_id.is_empty():
			batched_played_card_ids[played_card_id] = true
	for event in source_events:
		if not (event is GameEvent):
			continue
		if _event_suppresses_triggers(event):
			continue
		if str(event.type) == "CardDied":
			var payload = event.payload
			if payload is Dictionary:
				var killer_id = str(payload.get("source_card_id", ""))
				var killer_instance = state.card_instances.get(killer_id)
				if killer_instance != null and int(killer_instance.flags.get("olympus_ready_after_kill_turn", -1)) == state.turn_number and not bool(killer_instance.flags.get("olympus_ready_after_kill_used", false)):
					killer_instance.flags["olympus_ready_after_kill_used"] = true
					events.append_array(_ready_target_unit(state, killer_id, str(event.created_by_command)))
				if killer_instance != null and str(payload.get("source_kind", "")) == "attack":
					var granted_keyword = str(killer_instance.flags.get("kill_grant_keyword_until_turn_end_keyword", ""))
					if int(killer_instance.flags.get("kill_grant_keyword_until_turn_end_turn", -1)) == state.turn_number \
							and not granted_keyword.is_empty() \
							and int(killer_instance.flags.get("temporary_keyword_%s_turn" % granted_keyword, -1)) != state.turn_number:
						events.append_array(_grant_keyword_to_card_until_turn_end(state, killer_id, granted_keyword, str(event.created_by_command)))
		if _should_open_event_response_window(state, event):
			var response_marker = _create_event_response_window_marker(state, event)
			state.pending_triggers.append(response_marker)
			var marker_event = GameEvent.create(state.next_event_id(), "TriggerQueued", int(response_marker.get("controller", 0)), {
				"stack_id": response_marker.get("stack_id", ""),
				"source_id": str(response_marker.get("source_instance_id", "")),
				"effect_id": str(response_marker.get("effect_id", "")),
				"event_type": str(event.type)
			})
			marker_event.created_by_command = str(event.created_by_command)
			state.event_log.append(marker_event)
			events.append(marker_event)
		var trigger_source_ids = _get_trigger_source_ids(state)
		for related_card_id in _event_related_card_ids(event):
			if not trigger_source_ids.has(related_card_id):
				trigger_source_ids.append(related_card_id)
		for card_id in trigger_source_ids:
			var instance = state.card_instances.get(card_id)
			if instance == null:
				continue
			if str(event.type) == "CardDied":
				var died_card_id = str(event.payload.get("card_id", ""))
				if died_card_id == card_id and int(instance.flags.get("died_effects_disabled_turn", -1)) == state.turn_number:
					continue
			var definition = state.get_definition(instance.definition_id)
			if definition == null:
				continue
			for effect in definition.effects:
				if bool(effect.get("formal_only", false)) and not _uses_formal_rules(state):
					continue
				if str(effect.get("kind", "")) != "triggered":
					continue
				if _should_skip_legacy_entry_bridge_for_batched_play(effect, event, batched_played_card_ids):
					continue
				if not _effect_event_matches_actual_event(effect, event):
					continue
				if bool(effect.get("self_only", false)) and not _trigger_matches_self_only(event, card_id, effect):
					continue
				if not _trigger_condition_matches(state, event, instance, effect):
					continue
				if bool(effect.get("resolve_immediately_on_entry_without_stack", false)):
					if _should_delay_non_hand_entry_effect(state, event, card_id, effect):
						var immediate_trigger_item = _create_stack_item_from_effect(
							state,
							instance.controller,
							card_id,
							effect,
							"triggered",
							[],
							int(event.event_id)
						)
						immediate_trigger_item["is_entry_effect"] = true
						immediate_trigger_item["resolve_without_stack"] = true
						_append_pending_trigger_in_order(state, immediate_trigger_item)
						var immediate_trigger_event = GameEvent.create(state.next_event_id(), "TriggerQueued", instance.controller, {
							"stack_id": immediate_trigger_item.get("stack_id", ""),
							"source_id": card_id,
							"effect_id": str(effect.get("id", "")),
							"event_type": str(event.type)
						})
						immediate_trigger_event.created_by_command = str(event.created_by_command)
						state.event_log.append(immediate_trigger_event)
						events.append(immediate_trigger_event)
					continue
				if not _should_queue_trigger_for_event(event, effect):
					continue
				if not _validate_effect_availability(state, instance.controller, card_id, effect).get("ok", false):
					continue
				_mark_effect_as_used(state, instance.controller, card_id, effect)
				var trigger_item = _create_stack_item_from_effect(
					state,
					instance.controller,
					card_id,
					effect,
					"triggered",
					[],
					int(event.event_id)
				)
				if _is_self_entry_trigger_event(event, card_id, effect):
					trigger_item["is_entry_effect"] = true
				var pre_stack_target_events = _request_pre_stack_target_choice_for_trigger(state, trigger_item, str(event.type), str(event.created_by_command))
				if not pre_stack_target_events.is_empty():
					var pre_stack_trigger_event = GameEvent.create(state.next_event_id(), "TriggerQueued", instance.controller, {
						"stack_id": trigger_item.get("stack_id", ""),
						"source_id": card_id,
						"effect_id": str(effect.get("id", "")),
						"event_type": str(event.type)
					})
					pre_stack_trigger_event.created_by_command = str(event.created_by_command)
					state.event_log.append(pre_stack_trigger_event)
					events.append(pre_stack_trigger_event)
					events.append_array(pre_stack_target_events)
					continue
				_append_pending_trigger_in_order(state, trigger_item)
				var trigger_event = GameEvent.create(state.next_event_id(), "TriggerQueued", instance.controller, {
					"stack_id": trigger_item.get("stack_id", ""),
					"source_id": card_id,
					"effect_id": str(effect.get("id", "")),
					"event_type": str(event.type)
				})
				trigger_event.created_by_command = str(event.created_by_command)
				state.event_log.append(trigger_event)
				events.append(trigger_event)
		for master_player_id in range(state.players.size()):
			var master_source_id = _master_source_id(master_player_id)
			var master_instance = {
				"controller": master_player_id,
				"instance_id": master_source_id
			}
			for effect in _build_master_effects(state, master_player_id):
				if bool(effect.get("formal_only", false)) and not _uses_formal_rules(state):
					continue
				if str(effect.get("kind", "")) != "triggered":
					continue
				if _should_skip_legacy_entry_bridge_for_batched_play(effect, event, batched_played_card_ids):
					continue
				if not _effect_event_matches_actual_event(effect, event):
					continue
				if bool(effect.get("self_only", false)) and not _trigger_matches_self_only(event, master_source_id, effect):
					continue
				if not _trigger_condition_matches(state, event, master_instance, effect):
					continue
				if not _should_queue_trigger_for_event(event, effect):
					continue
				if not _validate_effect_availability(state, master_player_id, master_source_id, effect).get("ok", false):
					continue
				_mark_effect_as_used(state, master_player_id, master_source_id, effect)
				var trigger_item = _create_stack_item_from_effect(
					state,
					master_player_id,
					master_source_id,
					effect,
					"triggered",
					[],
					int(event.event_id)
				)
				var pre_stack_target_events = _request_pre_stack_target_choice_for_trigger(state, trigger_item, str(event.type), str(event.created_by_command))
				if not pre_stack_target_events.is_empty():
					var pre_stack_trigger_event = GameEvent.create(state.next_event_id(), "TriggerQueued", master_player_id, {
						"stack_id": trigger_item.get("stack_id", ""),
						"source_id": master_source_id,
						"effect_id": str(effect.get("id", "")),
						"event_type": str(event.type)
					})
					pre_stack_trigger_event.created_by_command = str(event.created_by_command)
					state.event_log.append(pre_stack_trigger_event)
					events.append(pre_stack_trigger_event)
					events.append_array(pre_stack_target_events)
					continue
				_append_pending_trigger_in_order(state, trigger_item)
				var trigger_event = GameEvent.create(state.next_event_id(), "TriggerQueued", master_player_id, {
					"stack_id": trigger_item.get("stack_id", ""),
					"source_id": master_source_id,
					"effect_id": str(effect.get("id", "")),
					"event_type": str(event.type)
				})
				trigger_event.created_by_command = str(event.created_by_command)
				state.event_log.append(trigger_event)
				events.append(trigger_event)
	return events


func _append_pending_trigger_in_order(state: GameState, trigger_item: Dictionary) -> void:
	var bucket := _pending_trigger_order_bucket(state, trigger_item)
	if bucket >= 0:
		trigger_item["order_bucket"] = bucket
	if bucket < 0 or state.pending_triggers.is_empty():
		state.pending_triggers.append(trigger_item)
		return
	var insert_index := state.pending_triggers.size()
	for index in range(state.pending_triggers.size()):
		var existing_bucket := int((state.pending_triggers[index] as Dictionary).get("order_bucket", -1))
		if existing_bucket < 0:
			continue
		if existing_bucket > bucket:
			insert_index = index
			break
	state.pending_triggers.insert(insert_index, trigger_item)


func _should_open_event_response_window(state: GameState, source_event) -> bool:
	if source_event == null:
		return false
	for card_id in _get_battlefield_card_ids(state):
		if not _is_set_counter_tactic_source(state, card_id):
			continue
		if _is_counter_tactic_disabled_this_turn(state, card_id):
			continue
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		for effect in definition.effects:
			if str(effect.get("kind", "")) != "activated":
				continue
			if not _effect_has_response_source_event_filters(effect):
				continue
			if not _source_event_matches_response_filters(state, source_event, int(instance.controller), effect):
				continue
			if not _validate_effect_availability(state, int(instance.controller), card_id, effect, {
				"response_source_event": source_event
			}).get("ok", false):
				continue
			if not _validate_effect_cost(state, int(instance.controller), effect, {"source_id": card_id}).get("ok", false):
				continue
			return true
	return false


func _create_event_response_window_marker(state: GameState, source_event) -> Dictionary:
	var payload = source_event.payload if source_event != null else {}
	var source_id := str(payload.get("card_id", "")) if payload is Dictionary else ""
	return {
		"stack_id": state.next_stack_id(),
		"controller": int(source_event.player_id) if source_event != null else state.active_player,
		"source_instance_id": source_id,
		"effect_id": "__event_response_window__",
		"effect_text": "响应时机",
		"effect_type": "event_response_window",
		"targets": {},
		"choices": {},
		"paid_costs": [],
		"cost": {},
		"can_be_responded_to": false,
		"created_from_event_id": int(source_event.event_id) if source_event != null else -1,
		"resolution": {
			"action": "response_window_only"
		}
	}


func _pending_trigger_order_bucket(state: GameState, trigger_item: Dictionary) -> int:
	if str(trigger_item.get("effect_type", "")) != "triggered":
		return -1
	var source_event_id := int(trigger_item.get("created_from_event_id", -1))
	if source_event_id < 0:
		return -1
	var source_event = _find_event_by_id(state, source_event_id)
	if source_event == null or str(source_event.type) != "CardDied":
		return -1
	var payload = source_event.payload
	if not (payload is Dictionary):
		return -1
	if str(payload.get("source_kind", "")) != "attack":
		return -1
	var source_id := str(trigger_item.get("source_instance_id", ""))
	if source_id.is_empty():
		return -1
	var killer_id := str(payload.get("source_card_id", ""))
	var died_card_id := str(payload.get("card_id", ""))
	var source_controller := _controller_for_trigger_source(state, source_id)
	if source_id == killer_id:
		return 0 if source_controller == state.active_player else 1
	if source_id == died_card_id:
		return 2 if source_controller == state.active_player else 3
	return -1


func _controller_for_trigger_source(state: GameState, source_id: String) -> int:
	if _is_master_source_id(source_id):
		return _master_player_from_source_id(source_id)
	if _is_morale_source_id(source_id):
		return _morale_player_from_source_id(source_id)
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return -1
	return int(instance.controller)


func _find_event_by_id(state: GameState, event_id: int) -> GameEvent:
	for event in state.event_log:
		if event is GameEvent and int(event.event_id) == event_id:
			return event
	return null


func _effect_event_matches_actual_event(effect: Dictionary, event: GameEvent) -> bool:
	var expected_event := str(effect.get("event", ""))
	var actual_event := str(event.type)
	if expected_event == actual_event:
		return true
	# Compatibility: legacy self-entry triggers still written as CardPlayed
	# should also fire when the card enters the battlefield from non-hand zones.
	if expected_event == "CardPlayed" and actual_event == "CardEnteredBattlefield":
		var payload = event.payload
		if payload is Dictionary and str(payload.get("from", "")) != "hand" and bool(effect.get("self_only", false)):
			return true
	return false

func _requested_play_host_player(state: GameState, player_id: int, play_option: Dictionary, payload: Dictionary) -> int:
	if not bool(play_option.get("allow_foreign_battlefield", false)):
		return player_id
	var host_player = int(payload.get("host_player", player_id))
	if host_player < 0 or host_player >= state.players.size():
		return player_id
	return host_player

func _should_skip_legacy_entry_bridge_for_batched_play(effect: Dictionary, event: GameEvent, batched_played_card_ids: Dictionary) -> bool:
	if str(effect.get("event", "")) != "CardPlayed":
		return false
	if str(event.type) != "CardEnteredBattlefield":
		return false
	if not bool(effect.get("self_only", false)):
		return false
	var payload = event.payload
	if not (payload is Dictionary):
		return false
	var card_id := str(payload.get("card_id", ""))
	return not card_id.is_empty() and batched_played_card_ids.has(card_id)

func _request_pre_stack_target_choice_for_trigger(state: GameState, trigger_item: Dictionary, event_type: String, command_id: String) -> Array:
	var resolution = trigger_item.get("resolution", {})
	if not (resolution is Dictionary):
		return []
	var source_id := str(trigger_item.get("source_instance_id", ""))
	var uses_pre_stack_optional_prompt := bool(resolution.get("optional", false)) and (
		event_type == "AttackDeclared" or _is_set_counter_tactic_source(state, source_id)
	)
	if uses_pre_stack_optional_prompt:
		if not _can_offer_optional_stack_effect_choice(state, trigger_item):
			return []
		var cost = trigger_item.get("cost", {})
		if cost is Dictionary and not cost.is_empty():
			var controller = int(trigger_item.get("controller", state.active_player))
			var cost_check = _validate_effect_cost(state, controller, {"cost": cost}, {"source_id": str(trigger_item.get("source_instance_id", ""))})
			if not bool(cost_check.get("ok", false)):
				return []
		return _request_option_choice(state, int(trigger_item.get("controller", state.active_player)), [
			{"id": "yes", "label": "发动"},
			{"id": "no", "label": "不发动"}
		], _optional_stack_effect_choice_title(state, trigger_item), "pre_stack_optional_attack_trigger", {
			"stack_item": trigger_item.duplicate(true)
		}, command_id)
	var action = str(resolution.get("action", ""))
	if action == "choose_and_destroy_unit":
		if not _uses_formal_rules(state):
			return []
		if not trigger_item.get("targets", {}).is_empty():
			return []
		var candidates: Array[String] = []
		for target_card_id in _get_battlefield_card_ids(state):
			if _target_card_matches_stack_resolution_filters(state, trigger_item, target_card_id):
				candidates.append(target_card_id)
		if candidates.is_empty():
			return []
		return _request_candidate_cards_choice(
			state,
			int(trigger_item.get("controller", state.active_player)),
			candidates,
			1,
			"选择效果目标",
			"target_then_stack_effect",
			{"stack_item": trigger_item.duplicate(true)},
			command_id
		)
	if action == "disable_enemy_hand_counter_tactic_until_turn_end":
		var controller = int(trigger_item.get("controller", state.active_player))
		var candidates = _matching_set_counter_tactic_ids(state, 1 - controller)
		if candidates.is_empty():
			return []
		return _request_candidate_cards_choice(
			state,
			controller,
			candidates,
			1,
			"选择对方1张反击战术本回合无法发动",
			"target_set_counter_tactic_then_stack_effect",
			{"stack_item": trigger_item.duplicate(true)},
			command_id
		)
	if action == "grant_cannot_die_until_turn_end" or action == "grant_cannot_die_once_until_next_own_turn_start":
		if not _uses_formal_rules(state):
			return []
		if not trigger_item.get("targets", {}).is_empty():
			return []
		if str(resolution.get("target_scope", "")) == "self":
			return []
		var controller = int(trigger_item.get("controller", state.active_player))
		var candidates: Array[String] = []
		for target_card_id in _get_battlefield_card_ids(state):
			if _target_card_matches_stack_resolution_filters(state, trigger_item, target_card_id):
				candidates.append(target_card_id)
		if candidates.is_empty():
			return []
		return _request_candidate_cards_choice(
			state,
			controller,
			candidates,
			1,
			"选择获得免死的军团",
			"target_then_stack_effect",
			{"stack_item": trigger_item.duplicate(true)},
			command_id
		)
	if action == "olympus_freeze_target_until_next_ready":
		if not _uses_formal_rules(state):
			return []
		if not trigger_item.get("targets", {}).is_empty():
			return []
		var controller = int(trigger_item.get("controller", state.active_player))
		var candidates: Array[String] = []
		for target_card_id in _get_battlefield_card_ids_for_player(state, 1 - controller):
			if _target_card_matches_stack_resolution_filters(state, trigger_item, target_card_id):
				candidates.append(target_card_id)
		if candidates.is_empty():
			return []
		return _request_candidate_cards_choice(
			state,
			controller,
			candidates,
			1,
			"选择效果目标",
			"target_then_stack_effect",
			{"stack_item": trigger_item.duplicate(true)},
			command_id
		)
	return []

func _event_related_card_ids(event: GameEvent) -> Array[String]:
	var result: Array[String] = []
	var payload = event.payload
	if not (payload is Dictionary):
		return result
	for key in ["card_id", "source_id", "source_card_id", "attacker_id", "defender_id"]:
		var card_id = str(payload.get(key, ""))
		if not card_id.is_empty() and not result.has(card_id):
			result.append(card_id)
	return result


func _is_self_entry_trigger_event(event: GameEvent, card_id: String, effect: Dictionary) -> bool:
	if event == null:
		return false
	if not bool(effect.get("self_only", false)):
		return false
	if str(event.type) != "CardEnteredBattlefield":
		return false
	var payload = event.payload
	return payload is Dictionary and str(payload.get("card_id", "")) == card_id


func _should_delay_non_hand_entry_effect(state: GameState, event: GameEvent, card_id: String, effect: Dictionary) -> bool:
	if state == null or event == null:
		return false
	if not _is_self_entry_trigger_event(event, card_id, effect):
		return false
	var payload = event.payload
	return payload is Dictionary and str(payload.get("from", "")) != "hand"


func _has_pending_non_hand_entry_response_window(state: GameState, card_id: String) -> bool:
	if state == null or card_id.is_empty():
		return false
	for item in state.pending_triggers:
		if not (item is Dictionary):
			continue
		if str((item as Dictionary).get("effect_type", "")) != "event_response_window":
			continue
		var source_event = _event_by_id(state, int((item as Dictionary).get("created_from_event_id", 0)))
		if not _is_non_hand_legion_entry_event(state, source_event):
			continue
		var payload = source_event.payload
		if payload is Dictionary and str(payload.get("card_id", "")) == card_id:
			return true
	return false


func _card_entry_effects_disabled_this_turn(state: GameState, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	return instance != null and int(instance.flags.get("entry_effects_disabled_turn", -1)) == state.turn_number


func _should_skip_disabled_entry_trigger_item(state: GameState, trigger_item: Dictionary) -> bool:
	if not bool(trigger_item.get("is_entry_effect", false)):
		return false
	return _card_entry_effects_disabled_this_turn(state, str(trigger_item.get("source_instance_id", "")))

func _promote_next_pending_trigger(state: GameState, command_id: String) -> Array:
	if state.pending_triggers.is_empty():
		return []
	var trigger_item = state.pending_triggers.pop_front()
	if _should_skip_disabled_entry_trigger_item(state, trigger_item):
		return []
	if bool(trigger_item.get("resolve_without_stack", false)):
		return _resolve_stack_effect(state, trigger_item, command_id)
	return _put_prebuilt_stack_item_on_stack(state, trigger_item, command_id)

func _put_prebuilt_stack_item_on_stack(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var source_id := str(stack_item.get("source_instance_id", ""))
	if str(stack_item.get("effect_type", "")) == "triggered" and _is_set_counter_tactic_source(state, source_id):
		events.append_array(_move_set_counter_to_stack_pending(state, int(stack_item.get("controller", state.active_player)), source_id, command_id))
		stack_item["effect_type"] = "counter_tactic"
	state.stack.append(stack_item)
	state.priority_player = 1 - int(stack_item.get("controller", state.active_player))
	state.priority_pass_count = 0
	var stack_event = GameEvent.create(state.next_event_id(), "EffectPutOnStack", int(stack_item.get("controller", state.active_player)), {
		"stack_id": stack_item.get("stack_id", ""),
		"source_id": str(stack_item.get("source_instance_id", "")),
		"effect_id": str(stack_item.get("effect_id", "")),
		"effect_type": str(stack_item.get("effect_type", "triggered"))
	})
	stack_event.created_by_command = command_id
	state.event_log.append(stack_event)
	events.append(stack_event)
	return events

func _resolve_top_stack_item(state: GameState, command_id: String) -> Array:
	if state.stack.is_empty():
		return []
	var stack_item = state.stack.pop_back()
	var events: Array = []
	var resolve_event = GameEvent.create(state.next_event_id(), "EffectResolved", int(stack_item.get("controller", state.active_player)), {
		"stack_id": str(stack_item.get("stack_id", "")),
		"source_id": str(stack_item.get("source_instance_id", "")),
		"effect_id": str(stack_item.get("effect_id", "")),
		"effect_type": str(stack_item.get("effect_type", "activated"))
	})
	resolve_event.created_by_command = command_id
	state.event_log.append(resolve_event)
	events.append(resolve_event)
	events.append_array(_resolve_stack_effect(state, stack_item, command_id))
	events.append_array(_suncity_codex_handle_stack_reward(state, stack_item, command_id))
	events.append_array(_cleanup_tactic_source_after_resolution(state, stack_item, command_id))
	return events

func _resolve_stack_effect(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	if not (resolution is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "", command_id)]
	var action = str(resolution.get("action", ""))
	if _uses_formal_rules(state) and bool(resolution.get("optional", false)) and not bool(stack_item.get("optional_choice_resolved", false)):
		if not _can_offer_optional_stack_effect_choice(state, stack_item):
			return []
		var controller = int(stack_item.get("controller", state.active_player))
		return _request_option_choice(state, controller, [
			{"id": "yes", "label": "发动"},
			{"id": "no", "label": "不发动"}
		], _optional_stack_effect_choice_title(state, stack_item), "optional_stack_effect", {
			"stack_item": stack_item.duplicate(true)
		}, command_id)
	var common_resolution = _try_resolve_common_stack_action(state, stack_item, resolution, action, command_id)
	if bool(common_resolution.get("handled", false)):
		var common_events = common_resolution.get("events", [])
		if state.pending_choices.is_empty() and action != "search_deck":
			common_events.append_array(_resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id))
		return common_events
	var grave_choice_resolution = _try_resolve_grave_choice_stack_action(state, stack_item, action, command_id)
	if bool(grave_choice_resolution.get("handled", false)):
		var grave_choice_events = grave_choice_resolution.get("events", [])
		if action != "recycle_grave_to_deck" and state.pending_choices.is_empty():
			grave_choice_events.append_array(_resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id))
		return grave_choice_events
	var target_buff_resolution = _try_resolve_target_buff_stack_action(state, stack_item, action, command_id)
	if bool(target_buff_resolution.get("handled", false)):
		var target_buff_events = target_buff_resolution.get("events", [])
		if state.pending_choices.is_empty():
			target_buff_events.append_array(_resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id))
		return target_buff_events
	var combat_counter_resolution = _try_resolve_combat_counter_stack_action(state, stack_item, action, command_id)
	if bool(combat_counter_resolution.get("handled", false)):
		var combat_counter_events = combat_counter_resolution.get("events", [])
		if state.pending_choices.is_empty():
			combat_counter_events.append_array(_resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id))
		return combat_counter_events
	var special_resolution = _try_resolve_special_stack_action(state, stack_item, action, command_id)
	if bool(special_resolution.get("handled", false)):
		var special_events = special_resolution.get("events", [])
		if state.pending_choices.is_empty():
			special_events.append_array(_resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id))
		return special_events
	return [_create_unimplemented_effect_event(state, stack_item, action, command_id)]

func _try_resolve_common_stack_action(state: GameState, stack_item: Dictionary, resolution: Dictionary, action: String, command_id: String) -> Dictionary:
	match action:
		"response_window_only":
			return {"handled": true, "events": []}
		"adjust_calamity_value":
			var amount = int(resolution.get("amount", 0))
			return {"handled": true, "events": _adjust_calamity_value(state, amount, command_id)}
		"preview_next_calamity":
			return {"handled": true, "events": _preview_next_calamity(state, stack_item, command_id)}
		"reveal_calamity":
			return {"handled": true, "events": _reveal_calamity(state, str(resolution.get("definition_id", "")), command_id)}
		"shuffle_deck":
			return {"handled": true, "events": _shuffle_deck(state, stack_item, command_id)}
		"draw_cards":
			var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var hand_limit = int(resolution.get("own_hand_size_at_most", -1))
			if hand_limit >= 0 and state.get_player(player_id).hand.cards.size() > hand_limit:
				return {"handled": true, "events": []}
			var count = int(resolution.get("count", 1))
			return {"handled": true, "events": DrawActions.draw_cards(state, player_id, count, command_id, _effect_event_options_from_stack_item(state, stack_item, resolution))}
		"draw_source_owner_cards":
			var source_id := str(stack_item.get("source_instance_id", ""))
			var instance = state.card_instances.get(source_id)
			if instance == null:
				return {"handled": true, "events": []}
			var count = int(resolution.get("count", 1))
			return {"handled": true, "events": DrawActions.draw_cards(state, int(instance.owner), count, command_id, _effect_event_options_from_stack_item(state, stack_item, resolution))}
		"add_morale":
			var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var count = int(resolution.get("count", 1))
			var orientation = str(resolution.get("orientation", "active"))
			var source_faction := ""
			var source_id = str(stack_item.get("source_instance_id", ""))
			if not source_id.is_empty():
				var source_instance = state.card_instances.get(source_id)
				var source_definition = state.get_definition(source_instance.definition_id) if source_instance != null else null
				if source_definition != null:
					source_faction = str(source_definition.faction)
			return {"handled": true, "events": MoraleActions.add_morale_from_cost_deck(state, player_id, count, orientation, command_id, source_faction)}
		"add_rune":
			var rune_player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var rune_count = int(resolution.get("count", 1))
			return {"handled": true, "events": _add_player_runes(state, rune_player_id, rune_count, command_id)}
		"advance_trial_progress":
			return {"handled": true, "events": _advance_trial_progress(state, stack_item, resolution, command_id)}
		"discard_cards":
			var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var player_scope = str(resolution.get("player_scope", ""))
			if player_scope == "event_player":
				player_id = _player_id_from_trigger_event(state, int(stack_item.get("created_from_event_id", 0)), player_id)
			var count = int(resolution.get("count", 1))
			var requires_confirm = bool(resolution.get("requires_confirm", false))
			if not requires_confirm and not bool(resolution.get("always_request_choice", false)):
				return {"handled": true, "events": ZoneActions.discard_from_hand(
					state,
					player_id,
					count,
					command_id,
					_effect_event_source_options(str(stack_item.get("source_instance_id", "")))
				)}
			var discard_resolution: Dictionary = resolution.duplicate(true)
			discard_resolution["player_id"] = player_id
			discard_resolution["discard_count"] = count
			if not discard_resolution.has("title"):
				discard_resolution["title"] = "选择手牌弃置"
			if not discard_resolution.has("hint_text"):
				discard_resolution["hint_text"] = "请选择 %d 张手牌，再点击确认弃置。" % max(1, count)
			if not discard_resolution.has("top_hint_text"):
				discard_resolution["top_hint_text"] = "请从高亮手牌中选择 %d 张并确认弃置。" % max(1, count)
			var discard_stack_item: Dictionary = stack_item.duplicate(true)
			discard_stack_item["resolution"] = discard_resolution
			return {"handled": true, "events": _request_hand_discard_choice_from_resolution(state, discard_stack_item, command_id)}
		"deal_master_damage":
			var targets = stack_item.get("targets", {})
			var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var player_scope = str(resolution.get("player_scope", ""))
			var controller = int(stack_item.get("controller", state.active_player))
			if player_scope == "opponent":
				player_id = 1 - controller
			elif player_scope == "controller":
				player_id = controller
			elif player_scope == "event_player":
				player_id = _player_id_from_trigger_event(state, int(stack_item.get("created_from_event_id", 0)), player_id)
			if targets is Dictionary and targets.has("target_player"):
				player_id = int(targets.get("target_player", player_id))
			var amount = int(resolution.get("amount", 0))
			var waive_threshold = int(resolution.get("waive_if_own_master_hp_at_most", -1))
			if waive_threshold >= 0 and player_id == controller and state.get_player(controller).master_hp <= waive_threshold:
				amount = 0
			var target_waive_threshold = int(resolution.get("waive_if_target_master_hp_at_most", -1))
			if target_waive_threshold >= 0 and state.get_player(player_id).master_hp <= target_waive_threshold:
				amount = 0
			return {"handled": true, "events": _deal_master_damage(state, player_id, amount, command_id, {
				"source_card_id": str(stack_item.get("source_instance_id", "")),
				"source_kind": "effect",
				"non_lethal": bool(resolution.get("non_lethal", false))
			})}
		"heal_master":
			var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var player_scope = str(resolution.get("player_scope", ""))
			var controller = int(stack_item.get("controller", state.active_player))
			if player_scope == "opponent":
				player_id = 1 - controller
			elif player_scope == "controller":
				player_id = controller
			var amount = int(resolution.get("amount", 0))
			return {"handled": true, "events": _heal_master(state, player_id, amount, command_id)}
		"mill_cards":
			var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var count = int(resolution.get("count", 1))
			return {"handled": true, "events": DrawActions.mill_cards(state, player_id, count, command_id)}
		"prepare_free_master_morale_effect_activation":
			return {"handled": true, "events": _prepare_free_master_morale_effect_activation(state, stack_item, command_id)}
		"search_deck":
			var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var count = int(resolution.get("count", 1))
			var max_look = int(resolution.get("max_look", 1))
			var match_rules: Dictionary = {}
			if resolution.get("match", {}) is Dictionary:
				match_rules = resolution.get("match", {}).duplicate(true)
			return {"handled": true, "events": DrawActions.search_deck(state, player_id, max_look, match_rules, count, command_id, {
				"source_instance_id": str(stack_item.get("source_instance_id", "")),
				"effect_id": str(stack_item.get("effect_id", "")),
				"effect_type": str(stack_item.get("effect_type", "")),
				"stack_id": str(stack_item.get("stack_id", "")),
				"source_kind": "effect",
				"source_card_id": str(stack_item.get("source_instance_id", "")),
				"source_player_id": int(stack_item.get("controller", state.active_player)),
				"always_request_choice": bool(resolution.get("always_request_choice", false)),
				"reorder_remaining_to_bottom": bool(resolution.get("reorder_remaining_to_bottom", false)),
				"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true)
			})}
		"search_top_for_artifact_and_named_legion":
			var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
			var max_look = int(resolution.get("max_look", 5))
			var artifact_match_rules: Dictionary = {}
			if resolution.get("artifact_match", {}) is Dictionary:
				artifact_match_rules = resolution.get("artifact_match", {}).duplicate(true)
			var legion_match_rules: Dictionary = {}
			if resolution.get("legion_match", {}) is Dictionary:
				legion_match_rules = resolution.get("legion_match", {}).duplicate(true)
			return {"handled": true, "events": DrawActions.search_top_for_artifact_and_named_legion(state, player_id, max_look, artifact_match_rules, legion_match_rules, command_id, {
				"source_instance_id": str(stack_item.get("source_instance_id", "")),
				"source_kind": "effect",
				"source_card_id": str(stack_item.get("source_instance_id", "")),
				"source_player_id": int(stack_item.get("controller", state.active_player)),
				"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true)
			})}
		"plague_infection_apply":
			return {"handled": true, "events": _plague_infection_apply(state, stack_item, command_id)}
		"request_battlefield_reduce_choice":
			return {"handled": true, "events": _request_battlefield_reduce_choice_from_resolution(state, stack_item, command_id)}
		"request_return_battlefield_choice":
			return {"handled": true, "events": _request_return_battlefield_choice_from_resolution(state, stack_item, command_id)}
		"request_hand_return_to_deck_bottom_choice":
			return {"handled": true, "events": _request_hand_return_to_deck_bottom_choice_from_resolution(state, stack_item, command_id)}
		"ruined_ritual_force_discard_and_blank_entry":
			return {"handled": true, "events": _ruined_ritual_force_discard_and_blank_entry(state, stack_item, command_id)}
		"bijie_reveal_top_bijie_or_reorder":
			return {"handled": true, "events": _bijie_reveal_top_bijie_or_reorder(state, stack_item, command_id)}
		"draw_cards_for_players":
			return {"handled": true, "events": _draw_cards_for_players(state, stack_item, command_id)}
		_:
			return {"handled": false, "events": []}

func _try_resolve_grave_choice_stack_action(state: GameState, stack_item: Dictionary, action: String, command_id: String) -> Dictionary:
	match action:
		"bjorn_recycle_and_maybe_rested_revive":
			return {"handled": true, "events": _resolve_bjorn_recycle_and_maybe_rested_revive(state, stack_item, command_id)}
		"recycle_grave_to_deck":
			return {"handled": true, "events": _recycle_grave_to_deck(state, stack_item, command_id)}
		"recycle_grave_then_revive_source_from_grave":
			return {"handled": true, "events": _recycle_grave_then_revive_source_from_grave(state, stack_item, command_id)}
		"recycle_grave_then_revive_thor_hammer_from_grave":
			return {"handled": true, "events": _thor_hammer_grave_revive(state, stack_item, command_id)}
		"revive_from_grave":
			return {"handled": true, "events": _revive_from_grave(state, stack_item, command_id)}
		"return_from_grave_to_hand":
			return {"handled": true, "events": _return_from_grave_to_hand(state, stack_item, command_id)}
		"split_grave_two_cards_to_deck_bottom_and_hand":
			return {"handled": true, "events": _split_grave_two_cards_to_deck_bottom_and_hand(state, stack_item, command_id)}
		"trigger_selected_legion_died_effects":
			return {"handled": true, "events": _trigger_selected_legion_died_effects(state, stack_item, command_id)}
		"disable_enemy_hand_counter_tactic_until_turn_end":
			return {"handled": true, "events": _disable_enemy_hand_counter_tactic_until_turn_end(state, stack_item, command_id)}
		"disable_matching_counter_tactics_until_next_own_turn_start":
			return {"handled": true, "events": _disable_matching_counter_tactics_until_next_own_turn_start(state, stack_item, command_id)}
		_:
			return {"handled": false, "events": []}

func _try_resolve_target_buff_stack_action(state: GameState, stack_item: Dictionary, action: String, command_id: String) -> Dictionary:
	match action:
		"choose_and_destroy_unit":
			return {"handled": true, "events": _choose_and_destroy_unit(state, stack_item, command_id)}
		"choose_and_destroy_units":
			return {"handled": true, "events": _choose_and_destroy_units(state, stack_item, command_id)}
		"destroy_unit_by_battlefield_counter_tactic_count":
			return {"handled": true, "events": _destroy_unit_by_battlefield_counter_tactic_count(state, stack_item, command_id)}
		"choose_and_rest_unit":
			return {"handled": true, "events": _choose_and_rest_unit(state, stack_item, command_id)}
		"choose_and_ready_unit":
			return {"handled": true, "events": _choose_and_ready_unit(state, stack_item, command_id)}
		"choose_and_grant_cannot_die_until_turn_end":
			return {"handled": true, "events": _choose_and_grant_cannot_die_until_turn_end(state, stack_item, command_id)}
		"choose_and_grant_cannot_die_once_until_next_own_turn_start":
			return {"handled": true, "events": _choose_and_grant_cannot_die_once_until_next_own_turn_start(state, stack_item, command_id)}
		"choose_and_grant_keyword_until_turn_end":
			return {"handled": true, "events": _choose_and_grant_keyword_until_turn_end(state, stack_item, command_id)}
		"choose_and_return_unit_to_deck_bottom":
			return {"handled": true, "events": _choose_and_return_unit_to_deck_bottom(state, stack_item, command_id)}
		"choose_and_modify_cost_until_turn_end":
			return {"handled": true, "events": _choose_and_modify_cost_until_turn_end(state, stack_item, command_id)}
		"choose_and_modify_cost_until_next_own_turn_end":
			return {"handled": true, "events": _choose_and_modify_cost_until_next_own_turn_end(state, stack_item, command_id)}
		"choose_and_modify_power_until_next_own_turn_end":
			return {"handled": true, "events": _choose_and_modify_power_until_next_own_turn_end(state, stack_item, command_id)}
		"choose_and_modify_power_until_turn_end":
			return {"handled": true, "events": _choose_and_modify_power_until_turn_end(state, stack_item, command_id)}
		"disable_entry_effects_and_weaken_entered_legion":
			return {"handled": true, "events": _disable_entry_effects_and_weaken_entered_legion(
				state,
				str(stack_item.get("resolution", {}).get("target_card_id", "")),
				str(stack_item.get("source_instance_id", "")),
				command_id
			)}
		"choose_attach_matching_cards_under_source":
			return {"handled": true, "events": _choose_attach_matching_cards_under_source(state, stack_item, command_id)}
		"discard_attached_cards_for_power_until_turn_end":
			return {"handled": true, "events": _discard_attached_cards_for_power_until_turn_end(state, stack_item, command_id)}
		"modify_matching_power_until_turn_end":
			return {"handled": true, "events": _modify_matching_power_until_turn_end(state, stack_item, command_id)}
		"modify_source_power_until_turn_end":
			return {"handled": true, "events": _modify_source_power_until_turn_end(state, stack_item, command_id)}
		"grant_source_keyword_until_turn_end":
			return {"handled": true, "events": _grant_source_keyword_until_turn_end(state, stack_item, command_id)}
		"prepare_next_played_legion_keyword":
			return {"handled": true, "events": _prepare_next_played_legion_keyword(state, stack_item, command_id)}
		"prepare_next_played_legion_cost_modifier":
			return {"handled": true, "events": _prepare_next_played_legion_cost_modifier(state, stack_item, command_id)}
		"grant_matching_free_move_until_turn_end":
			return {"handled": true, "events": _grant_matching_free_move_until_turn_end(state, stack_item, command_id)}
		"grant_played_legion_keyword_until_turn_end":
			return {"handled": true, "events": _grant_played_legion_keyword_until_turn_end(state, stack_item, command_id)}
		"ready_battlefield_card":
			return {"handled": true, "events": _choose_and_ready_unit(state, stack_item, command_id)}
		"ready_spent_morale":
			return {"handled": true, "events": _ready_spent_morale(state, stack_item, command_id)}
		"ready_source_card":
			return {"handled": true, "events": _ready_source_card(state, stack_item, command_id)}
		"rest_source_card":
			return {"handled": true, "events": _rest_source_card(state, stack_item, command_id)}
		"block_master_healing_for_game":
			return {"handled": true, "events": _block_master_healing_for_game(state, stack_item, command_id)}
		"tianting_sunwu_prepare_free_tactic":
			return {"handled": true, "events": _tianting_sunwu_prepare_free_tactic(state, stack_item, command_id)}
		"tianting_reset_master_effect_once":
			return {"handled": true, "events": _tianting_reset_master_effect_once(state, stack_item, command_id)}
		"suncity_repeat_last_active_tactic":
			return {"handled": true, "events": _suncity_repeat_last_active_tactic(state, stack_item, command_id)}
		"suncity_codex_mark_reward":
			_suncity_codex_mark_reward(state, str(stack_item.get("resolution", {}).get("target_stack_id", "")), int(stack_item.get("resolution", {}).get("reward_player", -1)), str(stack_item.get("resolution", {}).get("source_instance_id", "")))
			return {"handled": true, "events": []}
		_:
			return {"handled": false, "events": []}

func _try_resolve_combat_counter_stack_action(state: GameState, stack_item: Dictionary, action: String, command_id: String) -> Dictionary:
	match action:
		"counter_target_stack":
			return {"handled": true, "events": _counter_target_stack_item(state, stack_item, command_id)}
		"destroy_target_unit":
			return {"handled": true, "events": _destroy_target_unit(state, stack_item, command_id)}
		"deal_legion_damage":
			return {"handled": true, "events": _deal_legion_damage_from_effect(state, stack_item, command_id)}
		"both_players_discard_then_draw":
			return {"handled": true, "events": _both_players_discard_then_draw(state, stack_item, command_id)}
		"request_hand_discard_choice":
			return {"handled": true, "events": _request_hand_discard_choice_from_resolution(state, stack_item, command_id)}
		"continue_pending_play_card_effect":
			return {"handled": true, "events": _continue_pending_play_card_effect(state, stack_item, command_id)}
		"draw_cards_after_both_players_discard":
			return {"handled": true, "events": _draw_cards_after_both_players_discard(state, stack_item, command_id)}
		"conceal_source":
			return {"handled": true, "events": _conceal_source(state, stack_item, command_id)}
		"reveal_source_face_up":
			return {"handled": true, "events": _reveal_source_face_up(state, stack_item, command_id)}
		"counter_pending_attack":
			return {"handled": true, "events": _counter_pending_attack(state, stack_item, command_id)}
		"tianting_counter_pending_attack_then_draw_if_no_frontline":
			return {"handled": true, "events": _tianting_counter_pending_attack_then_draw_if_no_frontline(state, stack_item, command_id)}
		"disable_matching_support_until_turn_end":
			return {"handled": true, "events": _disable_matching_support_until_turn_end(state, stack_item, command_id)}
		"return_target_unit_to_hand":
			return {"handled": true, "events": _return_target_unit_to_hand(state, stack_item, command_id)}
		"return_target_unit_to_deck_bottom":
			return {"handled": true, "events": _return_target_unit_to_deck_bottom(state, stack_item, command_id)}
		_:
			return {"handled": false, "events": []}

func _try_resolve_special_stack_action(state: GameState, stack_item: Dictionary, action: String, command_id: String) -> Dictionary:
	match action:
		"disable_target_died_effects_until_turn_end":
			return {"handled": true, "events": _disable_target_died_effects_until_turn_end(state, stack_item, command_id)}
		"hijikata_entry_destroy_combo":
			return {"handled": true, "events": _hijikata_entry_destroy_combo(state, stack_item, command_id)}
		"sunwukong_deploy_fighter":
			return {"handled": true, "events": _sunwukong_deploy_fighter(state, stack_item, command_id)}
		"yangjian_draw_then_put_back":
			return {"handled": true, "events": _yangjian_draw_then_put_back(state, stack_item, command_id)}
		"offer_truce_draw":
			return {"handled": true, "events": _offer_truce_draw(state, stack_item, command_id)}
		"offer_reveal_calamity":
			return {"handled": true, "events": _offer_reveal_calamity(state, stack_item, command_id)}
		"choose_option_with_cost":
			return {"handled": true, "events": _request_option_with_shared_cost(state, int(stack_item.get("controller", state.active_player)), stack_item.get("resolution", {}), command_id, str(stack_item.get("source_instance_id", "")))}
		"choose_rune_payment_for_source_attack_bonus":
			return {"handled": true, "events": _choose_rune_payment_for_source_attack_bonus(state, stack_item, command_id)}
		"grant_master_damage_bonus":
			return {"handled": true, "events": _grant_master_damage_bonus(state, stack_item, command_id)}
		"modify_target_cost":
			return {"handled": true, "events": _modify_target_cost(state, stack_item, command_id)}
		"modify_target_cost_until_next_own_turn_end":
			return {"handled": true, "events": _modify_target_cost_until_next_own_turn_end(state, stack_item, command_id)}
		"modify_matching_cost":
			return {"handled": true, "events": _modify_matching_cost(state, stack_item, command_id)}
		"modify_matching_cost_until_next_own_turn_end":
			return {"handled": true, "events": _modify_matching_cost_until_next_own_turn_end(state, stack_item, command_id)}
		"modify_matching_power_until_next_own_turn_end":
			return {"handled": true, "events": _modify_matching_power_until_next_own_turn_end(state, stack_item, command_id)}
		"revive_source_from_grave":
			return {"handled": true, "events": _revive_source_from_grave(state, stack_item, command_id)}
		"return_source_to_deck_top":
			return {"handled": true, "events": _return_source_to_deck_top(state, stack_item, command_id)}
		"return_matching_card_from_deck_or_grave_to_hand":
			return {"handled": true, "events": _return_matching_card_from_deck_or_grave_to_hand(state, stack_item, command_id)}
		"sacrifice_source_and_deploy_from_hand":
			return {"handled": true, "events": _sacrifice_source_and_deploy_from_hand(state, stack_item, command_id)}
		"sacrifice_source_then_follow_up":
			return {"handled": true, "events": _sacrifice_source_then_follow_up(state, stack_item, command_id)}
		"set_counter_tactics_from_hand":
			return {"handled": true, "events": _set_counter_tactics_from_hand(state, stack_item, command_id)}
		"forged_order_prepare_enemy_moves":
			return {"handled": true, "events": _forged_order_prepare_enemy_moves(state, stack_item, command_id)}
		"frontline_scout_view_enemy_hand":
			return {"handled": true, "events": _frontline_scout_view_enemy_hand(state, stack_item, command_id)}
		"reveal_enemy_hand_to_all":
			return {"handled": true, "events": _reveal_enemy_hand_to_all(state, stack_item, command_id)}
		"return_enemy_hand_to_deck_and_shuffle":
			return {"handled": true, "events": _return_enemy_hand_to_deck_and_shuffle(state, stack_item, command_id)}
		"return_enemy_hand_to_deck_top":
			return {"handled": true, "events": _return_enemy_hand_to_deck_top(state, stack_item, command_id)}
		"move_source_tactic_to_spent_morale":
			return {"handled": true, "events": _move_source_tactic_to_spent_morale(state, stack_item, command_id)}
		"return_source_to_hand":
			return {"handled": true, "events": _return_source_to_hand(state, stack_item, command_id)}
		"attach_source_to_enemy_artifact_lock":
			return {"handled": true, "events": _attach_source_to_enemy_artifact_lock(state, stack_item, command_id)}
		"discard_source_to_owner_grave":
			return {"handled": true, "events": _discard_source_to_owner_grave(state, stack_item, command_id)}
		"set_pending_attack_extra_discard_requirement":
			return {"handled": true, "events": _set_pending_attack_extra_discard_requirement(state, stack_item, command_id)}
		"undo_ready_event_and_discard_enemy_hand":
			return {"handled": true, "events": _undo_ready_event_and_discard_enemy_hand(state, stack_item, command_id)}
		"choose_and_move_units":
			return {"handled": true, "events": _choose_and_move_units(state, stack_item, command_id)}
		"deploy_matching_legion_from_hand":
			return {"handled": true, "events": _deploy_matching_legion_from_hand(state, stack_item, command_id)}
		"deploy_matching_legion_from_hand_deck_or_grave":
			return {"handled": true, "events": _deploy_matching_legion_from_hand_deck_or_grave(state, stack_item, command_id)}
		"attach_named_token_under_source":
			return {"handled": true, "events": _attach_named_token_under_source(state, stack_item, command_id)}
		"grant_controller_master_cannot_be_attacked_until_next_own_turn_start":
			return {"handled": true, "events": _grant_controller_master_cannot_be_attacked_until_next_own_turn_start(state, stack_item, command_id)}
		"reveal_top_card_play_or_hand":
			return {"handled": true, "events": _reveal_top_card_play_or_hand(state, stack_item, command_id)}
		"grant_cannot_die_until_turn_end":
			return {"handled": true, "events": _grant_cannot_die_until_turn_end(state, stack_item, command_id)}
		"grant_cannot_die_once_until_next_own_turn_start":
			return {"handled": true, "events": _grant_cannot_die_once_until_next_own_turn_start(state, stack_item, command_id)}
		"deploy_sigurd_from_hand_or_grave":
			return {"handled": true, "events": _deploy_sigurd_from_hand_or_grave(state, stack_item, command_id)}
		"move_source_one_step":
			return {"handled": true, "events": _move_source_one_step(state, stack_item, command_id)}
		"request_takamagahara_morale_follow_move":
			return {"handled": true, "events": _request_takamagahara_morale_follow_move_choice(state, int(stack_item.get("controller", state.active_player)), command_id)}
		"master_draw_then_discard":
			return {"handled": true, "events": _master_draw_then_discard(state, stack_item, command_id)}
		"choose_discard_from_hand_then_follow_up":
			return {"handled": true, "events": _choose_discard_from_hand_then_follow_up(state, stack_item, command_id)}
		"block_legion_source_heal_for_controller_until_turn_end":
			return {"handled": true, "events": _block_legion_source_heal_for_controller_until_turn_end(state, stack_item, command_id)}
		"grant_front_attack_power_bonus":
			return {"handled": true, "events": _grant_front_attack_power_bonus(state, stack_item, command_id)}
		"grant_source_can_attack_master_until_turn_end":
			return {"handled": true, "events": _grant_source_can_attack_master_until_turn_end(state, stack_item, command_id)}
		"manifest_kusanagi":
			return {"handled": true, "events": _manifest_kusanagi(state, stack_item, command_id)}
		"deploy_source_from_hand_to_front_and_redirect_pending_attack":
			return {"handled": true, "events": _deploy_hand_response_card_to_front_and_redirect_pending_attack(state, int(stack_item.get("controller", state.active_player)), str(stack_item.get("source_instance_id", "")), "front", int(stack_item.get("resolution", {}).get("col", -1)), command_id)}
		"send_source_to_grave":
			return {"handled": true, "events": _send_source_to_grave(state, stack_item, command_id)}
		"suncity_add_temporary_morale":
			return {"handled": true, "events": _suncity_add_temporary_morale(state, stack_item, command_id)}
		"suncity_ankh_rest_tomb_guard_draw":
			return {"handled": true, "events": _suncity_ankh_rest_tomb_guard_draw(state, stack_item, command_id)}
		"suncity_canopic_one_buff":
			return {"handled": true, "events": _suncity_canopic_one_buff(state, stack_item, command_id)}
		"suncity_canopic_four_protect":
			return {"handled": true, "events": _suncity_canopic_four_protect(state, stack_item, command_id)}
		"suncity_pharaoh_celebration":
			return {"handled": true, "events": _suncity_pharaoh_celebration(state, stack_item, command_id)}
		"suncity_horemheb_entry_charge":
			return {"handled": true, "events": _suncity_horemheb_entry_charge(state, stack_item, command_id)}
		"suncity_menes_attack_buff":
			return {"handled": true, "events": _suncity_menes_attack_buff(state, stack_item, command_id)}
		"suncity_tomb_construct_attach_tomb_guards":
			return {"handled": true, "events": _suncity_tomb_construct_attach_tomb_guards(state, stack_item, command_id)}
		"suncity_tomb_construct_release_tomb_guards":
			return {"handled": true, "events": _suncity_tomb_construct_release_tomb_guards(state, stack_item, command_id)}
		"suncity_thutmose_entry":
			return {"handled": true, "events": _suncity_thutmose_entry(state, stack_item, command_id)}
		"suncity_thutmose_crush":
			return {"handled": true, "events": _suncity_thutmose_crush(state, stack_item, command_id)}
		"suncity_codex_volume_one":
			return {"handled": true, "events": _suncity_codex_volume_one(state, stack_item, command_id)}
		"suncity_ramesses_replay_entries":
			return {"handled": true, "events": _suncity_ramesses_replay_entries(state, stack_item, command_id)}
		"suncity_tutankhamun_entry":
			return {"handled": true, "events": _suncity_tutankhamun_entry(state, stack_item, command_id)}
		"suncity_tutankhamun_death":
			return {"handled": true, "events": _suncity_tutankhamun_death(state, stack_item, command_id)}
		"suncity_place_named_artifact_from_grave":
			return {"handled": true, "events": _suncity_place_named_artifact_from_grave(state, stack_item, command_id)}
		"suncity_replace_isis_with_osiris":
			return {"handled": true, "events": _suncity_replace_isis_with_osiris(state, stack_item, command_id)}
		"suncity_prepare_discount_from_battlefield":
			return {"handled": true, "events": _suncity_prepare_discount_from_battlefield(state, stack_item, command_id)}
		"suncity_fearless_assassination":
			return {"handled": true, "events": _suncity_fearless_assassination(state, stack_item, command_id)}
		"suncity_golden_scarab_weaken":
			return {"handled": true, "events": _suncity_golden_scarab_weaken(state, stack_item, command_id)}
		"suncity_desert_sovereignty":
			return {"handled": true, "events": _suncity_desert_sovereignty(state, stack_item, command_id)}
		"suncity_medjed_weaken":
			return {"handled": true, "events": _suncity_medjed_weaken(state, stack_item, command_id)}
		"suncity_siwa_after_attack":
			return {"handled": true, "events": _suncity_siwa_after_attack(state, stack_item, command_id)}
		"tianting_qiankun_yin":
			return {"handled": true, "events": _tianting_qiankun_yin(state, stack_item, command_id)}
		"tianting_liu_bei_deploy_brother":
			return {"handled": true, "events": _tianting_liu_bei_deploy_brother(state, stack_item, command_id)}
		"tianting_liu_bei_search_brother":
			return {"handled": true, "events": _tianting_liu_bei_search_brother(state, stack_item, command_id)}
		"tianting_mozi_grant_cannot_die":
			return {"handled": true, "events": _tianting_mozi_grant_cannot_die(state, stack_item, command_id)}
		"tianting_yingzheng_entry":
			return {"handled": true, "events": _tianting_yingzheng_entry(state, stack_item, command_id)}
		"tianting_shanhe_scout":
			return {"handled": true, "events": _tianting_shanhe_scout(state, stack_item, command_id)}
		"tianting_limu_refund_morale_trigger":
			return {"handled": true, "events": _tianting_limu_refund_morale_trigger(state, stack_item, command_id)}
		"tianting_lijing_reveal_top":
			return {"handled": true, "events": _tianting_lijing_reveal_top(state, stack_item, command_id)}
		"tianting_freeze_enemy_units":
			return {"handled": true, "events": _tianting_freeze_enemy_units(state, stack_item, command_id)}
		"tianting_freeze_enemy_morale":
			return {"handled": true, "events": _tianting_freeze_enemy_morale(state, stack_item, command_id)}
		"tianting_xishi_swap":
			return {"handled": true, "events": _tianting_xishi_swap(state, stack_item, command_id)}
		"tianting_guanxing":
			return {"handled": true, "events": _tianting_guanxing(state, stack_item, command_id)}
		"tianting_zhugeliang_peek_calamity":
			return {"handled": true, "events": _tianting_zhugeliang_peek_calamity(state, stack_item, command_id)}
		"tianting_zhugeliang_reveal_top_artifact_or_hand":
			return {"handled": true, "events": _tianting_zhugeliang_reveal_top_artifact_or_hand(state, stack_item, command_id)}
		"tianting_pingyang_attack_reveal_top":
			return {"handled": true, "events": _tianting_pingyang_attack_reveal_top(state, stack_item, command_id)}
		"tianting_limu_entry_reveal_top_tactic":
			return {"handled": true, "events": _tianting_limu_entry_reveal_top_tactic(state, stack_item, command_id)}
		"tianting_yangyouji_enable_back_attack":
			return {"handled": true, "events": _tianting_yangyouji_enable_back_attack(state, stack_item, command_id)}
		"olympus_flip_morale":
			return {"handled": true, "events": _olympus_flip_morale(state, stack_item, command_id)}
		"olympus_search_top_pick_and_reorder":
			return {"handled": true, "events": _olympus_search_top_pick_and_reorder(state, stack_item, command_id)}
		"olympus_artemis_grant_choice":
			return {"handled": true, "events": _olympus_artemis_grant_choice(state, stack_item, command_id)}
		"olympus_grant_next_tactic_free":
			return {"handled": true, "events": _olympus_grant_next_tactic_free(state, stack_item, command_id)}
		"olympus_freeze_target_until_next_ready":
			return {"handled": true, "events": _olympus_freeze_target_until_next_ready(state, stack_item, command_id)}
		"olympus_grant_source_free_move_until_turn_end":
			return {"handled": true, "events": _olympus_grant_source_free_move_until_turn_end(state, stack_item, command_id)}
		"olympus_reveal_hand_legion_and_destroy":
			return {"handled": true, "events": _olympus_reveal_hand_legion_and_destroy(state, stack_item, command_id)}
		"olympus_reveal_hand_tactic_for_power":
			return {"handled": true, "events": _olympus_reveal_hand_tactic_for_power(state, stack_item, command_id)}
		"olympus_trojan_horse_after_attack":
			return {"handled": true, "events": _olympus_trojan_horse_after_attack(state, stack_item, command_id)}
		"olympus_prepare_promotion_divine_flip_discount":
			return {"handled": true, "events": _olympus_prepare_promotion_divine_flip_discount(state, stack_item, command_id)}
		"olympus_prepare_ready_after_kill":
			return {"handled": true, "events": _olympus_prepare_ready_after_kill(state, stack_item, command_id)}
		"bijie_prepare_ready_after_kill":
			return {"handled": true, "events": _bijie_prepare_ready_after_kill(state, stack_item, command_id)}
		"prepare_kill_grant_keyword_until_turn_end":
			return {"handled": true, "events": _prepare_kill_grant_keyword_until_turn_end(state, stack_item, command_id)}
		"olympus_grant_source_can_attack_legions_until_turn_end":
			return {"handled": true, "events": _olympus_grant_source_can_attack_legions_until_turn_end(state, stack_item, command_id)}
		"olympus_grant_source_front_taunt_until_next_own_turn_start":
			return {"handled": true, "events": _olympus_grant_source_front_taunt_until_next_own_turn_start(state, stack_item, command_id)}
		_:
			return {"handled": false, "events": []}

func _apply_suncity_next_calamity_discount(state: GameState, controller: int, amount: int, source_id: String, command_id: String) -> Array:
	if amount <= 0:
		return []
	var player = state.get_player(controller)
	player.flags["suncity_next_calamity_discount"] = {
		"turn": state.turn_number,
		"amount": -amount,
		"source_instance_id": source_id
	}
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"source_card_id": source_id,
		"card_id": source_id,
		"buff_type": "suncity_next_calamity_discount",
		"amount": amount
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _send_source_to_grave(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return []
	if str(instance.zone) == "artifact_zone":
		return _send_artifact_to_grave(state, int(instance.controller), source_id, command_id)
	if str(instance.zone).begins_with("battle_"):
		var row = str(instance.position.get("row", ""))
		var col = int(instance.position.get("col", -1))
		if row.is_empty() or col < 0:
			return []
		return ZoneActions.move_battlefield_to_grave(state, int(instance.controller), row, col, command_id)
	return []

func _suncity_place_named_artifact_from_grave(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var grave_candidates = _matching_grave_card_ids(state, controller, {"type": "artifact", "name_contains": "卡诺匹斯"})
	if grave_candidates.is_empty():
		return []
	var tomb_guards: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		if str(instance.definition_id) != "suncity_s01_0212":
			continue
		tomb_guards.append(card_id)
	if tomb_guards.size() < 3:
		return []
	return _request_candidate_cards_choice(state, controller, tomb_guards, 3, "选择3张陵墓守卫置入墓地", "suncity_isis_send_tomb_guards", {
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id)

func _suncity_place_canopic_after_cost(state: GameState, controller: int, source_id: String, command_id: String) -> Array:
	var grave_candidates = _matching_grave_card_ids(state, controller, {"type": "artifact", "name_contains": "卡诺匹斯"})
	if grave_candidates.is_empty():
		return []
	if grave_candidates.size() == 1:
		var events = _place_artifact_without_play(state, controller, str(grave_candidates[0]), command_id)
		events.append_array(_request_option_choice(state, controller, [
			{"id": "draw", "label": "抽1张牌"},
			{"id": "heal", "label": "主宰回复1点血量"}
		], "选择伊西斯的额外效果", "suncity_isis_reward", {
			"source_instance_id": source_id
		}, command_id))
		return events
	return _request_candidate_cards_choice(state, controller, grave_candidates, 1, "选择1张卡诺匹斯圣物置入圣物区", "suncity_isis_place_canopic", {
		"source_instance_id": source_id
	}, command_id)

func _suncity_replace_isis_with_osiris(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	if _controller_canopic_artifact_count(state, controller) < 5:
		return []
	var player = state.get_player(controller)
	player.master_definition_id = "suncity_s01_02m2"
	var osiris_definition = state.get_definition("suncity_s01_02m2")
	if osiris_definition != null:
		player.master_name = str(osiris_definition.name)
	var events: Array = []
	var changed_event = GameEvent.create(state.next_event_id(), "MasterChanged", controller, {
		"player_id": controller,
		"master_definition_id": player.master_definition_id
	})
	changed_event.created_by_command = command_id
	state.event_log.append(changed_event)
	events.append(changed_event)
	if state.players.size() <= 2:
		state.winner = controller
		state.loss_reason = "osiris_replaced"
		var victory = GameEvent.create(state.next_event_id(), "WinnerDecided", controller, {
			"winner": controller,
			"reason": "osiris_replaced"
		})
		victory.created_by_command = command_id
		state.event_log.append(victory)
		events.append(victory)
		return events
	player.master_max_hp += 2
	events.append_array(_heal_master(state, controller, 2, command_id))
	var revive_candidates = _matching_grave_card_ids(state, controller, {"type": "legion", "faction": "suncity"})
	if not revive_candidates.is_empty():
		events.append_array(_revive_grave_card_to_first_slot(state, controller, str(revive_candidates[0]), command_id))
	return events

func _suncity_prepare_discount_from_battlefield(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var resolution = stack_item.get("resolution", {})
	var flat_amount = int(resolution.get("discount_amount", 0))
	if flat_amount > 0:
		return _apply_suncity_next_calamity_discount(state, controller, flat_amount, str(stack_item.get("source_instance_id", "")), command_id)
	var candidates = _get_battlefield_card_ids_for_player(state, controller)
	if candidates.is_empty():
		return []
	var options: Array[Dictionary] = []
	for count in range(1, candidates.size() + 1):
		options.append({"id": str(count), "label": "弃置%d张" % count})
	return _request_option_choice(state, controller, options, "选择要弃置的我方军团数量", "suncity_prepare_discount_count", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"candidate_ids": candidates
	}, command_id)

func _suncity_add_temporary_morale(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var resolution = stack_item.get("resolution", {})
	var amount = int(resolution.get("amount", 0))
	if amount <= 0:
		return []
	return MoraleActions.add_temporary_morale(state, controller, amount, command_id, str(stack_item.get("source_instance_id", "")))

func _suncity_ankh_rest_tomb_guard_draw(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(card_id)
		if instance == null or str(instance.definition_id) != "suncity_s01_0212":
			continue
		candidates.append(str(card_id))
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择1张陵墓守卫转为休整并抽1张牌", "suncity_ankh_rest_tomb_guard_draw", {}, command_id)

func _suncity_pharaoh_celebration(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var player = state.get_player(controller)
	var looked: Array[String] = []
	var candidates: Array[String] = []
	for index in range(min(5, player.deck.cards.size())):
		var card_id = str(player.deck.cards[index])
		looked.append(card_id)
		var instance = state.card_instances.get(card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null:
			continue
		if not _definition_matches_required_faction_for_instance(state, instance, definition, "suncity") or str(definition.id) == "suncity_s01_0222":
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return _request_olympus_reorder_bottom_next_card(state, controller, looked, [], str(stack_item.get("source_instance_id", "")), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, min(2, candidates.size()), "选择2张太阳城卡牌，其中1张加入手牌，另1张置入墓地", "suncity_pharaoh_pick_cards", {
		"looked": looked.duplicate(),
		"allow_up_to_count": false
	}, command_id)

func _suncity_canopic_one_buff(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null or not definition.is_legion() or not _definition_matches_required_faction_for_instance(state, instance, definition, "suncity"):
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return _send_source_to_grave(state, stack_item, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择1张太阳城军团获得强化", "suncity_canopic_one_buff", {
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id)

func _suncity_canopic_four_protect(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null or not definition.is_legion() or not _definition_matches_required_faction_for_instance(state, instance, definition, "suncity"):
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return _send_source_to_grave(state, stack_item, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, min(2, candidates.size()), "选择最多2张太阳城军团获得免死", "suncity_canopic_four_protect", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"allow_up_to_count": true
	}, command_id)

func _suncity_horemheb_entry_charge(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(card_id)
		if instance == null or str(instance.definition_id) != "suncity_s01_0212":
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择1张陵墓守卫置入墓地使霍列姆赫布获得冲锋", "suncity_horemheb_entry_charge", {
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id)

func _suncity_menes_attack_buff(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	var source_id = str(stack_item.get("source_instance_id", ""))
	if controller < 0 or source_id.is_empty():
		return []
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		if str(card_id) == source_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null or not definition.is_legion():
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择1张我方军团置入墓地使美尼斯强化", "suncity_menes_attack_buff", {
		"source_instance_id": source_id,
		"allow_up_to_count": true
	}, command_id)

func _suncity_thutmose_entry(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null:
		return []
	source_instance.flags["suncity_ignore_counter_tactics_turn"] = state.turn_number
	var events: Array = []
	var protect_event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(source_instance.controller), {
		"card_id": source_id,
		"buff": "suncity_ignore_counter_tactics"
	})
	protect_event.created_by_command = command_id
	state.event_log.append(protect_event)
	events.append(protect_event)
	var candidates = _matching_battlefield_cards_for_player(state, 1 - int(source_instance.controller), {
		"type": "legion",
		"max_target_power": 5000
	})
	if candidates.is_empty():
		return events
	if candidates.size() == 1:
		events.append_array(_destroy_target_unit(state, {
			"targets": {"target_card_id": str(candidates[0])},
			"resolution": {"max_target_power": 5000}
		}, command_id))
		return events
	events.append_array(_request_candidate_cards_choice(state, int(source_instance.controller), candidates, 1, "选择1张兵力不高于5000的敌方军团击杀", "destroy_battlefield_cards", {
		"resolution": {"max_target_power": 5000},
		"source_instance_id": source_id
	}, command_id))
	return events

func _suncity_thutmose_crush(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var enemy_id = 1 - controller
	var events: Array = []
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, enemy_id):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null or not definition.is_legion():
			continue
		candidates.append(card_id)
		events.append_array(_modify_power_until_turn_end(state, str(card_id), -1000, command_id))
	if candidates.is_empty():
		return events
	var finishers: Array[String] = []
	for card_id in candidates:
		if get_card_power(state, str(card_id)) <= 1000:
			finishers.append(str(card_id))
	if finishers.is_empty():
		return events
	if finishers.size() == 1:
		events.append_array(_destroy_target_unit(state, {
			"targets": {"target_card_id": str(finishers[0])},
			"resolution": {"max_target_power": 1000}
		}, command_id))
		return events
	events.append_array(_request_candidate_cards_choice(state, controller, finishers, 1, "选择1张兵力不高于1000的敌方军团击杀", "destroy_battlefield_cards", {
		"resolution": {"max_target_power": 1000},
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id))
	return events

func _suncity_ramesses_replay_entries(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null:
		return []
	source_instance.flags["suncity_ignore_counter_tactics_turn"] = state.turn_number
	var controller = int(source_instance.controller)
	var events: Array = []
	var protect_event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"card_id": source_id,
		"buff": "suncity_ignore_counter_tactics"
	})
	protect_event.created_by_command = command_id
	state.event_log.append(protect_event)
	events.append(protect_event)
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		if str(card_id) == source_id:
			continue
		var instance = state.card_instances.get(str(card_id))
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null or not definition.is_legion() or not _definition_matches_required_faction_for_instance(state, instance, definition, "suncity"):
			continue
		var has_entry_trigger := false
		for effect in definition.effects:
			if str(effect.get("kind", "")) != "triggered":
				continue
			if str(effect.get("event", "")) != "CardPlayed":
				continue
			if not bool(effect.get("self_only", false)):
				continue
			has_entry_trigger = true
			break
		if has_entry_trigger:
			candidates.append(str(card_id))
	if candidates.is_empty():
		return events
	events.append_array(_request_candidate_cards_choice(state, controller, candidates, min(3, candidates.size()), "选择最多3张太阳城军团，按选择顺序发动其登场时效果", "suncity_ramesses_replay_entries", {
		"allow_up_to_count": true
	}, command_id))
	return events

func _suncity_queue_replayed_entry_effects(state: GameState, controller: int, selected: Array[String], command_id: String) -> Array:
	var replay_stack_items: Array[Dictionary] = []
	for card_id in selected:
		var instance = state.card_instances.get(str(card_id))
		if instance == null or int(instance.controller) != controller:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		var synthetic_event = GameEvent.create(0, "CardPlayed", controller, {
			"card_id": str(card_id),
			"row": str(instance.position.get("row", "")),
			"col": int(instance.position.get("col", -1)),
			"zone": str(instance.zone)
		})
		for effect in definition.effects:
			if str(effect.get("kind", "")) != "triggered":
				continue
			if str(effect.get("event", "")) != "CardPlayed":
				continue
			if not bool(effect.get("self_only", false)):
				continue
			if not _trigger_condition_matches(state, synthetic_event, instance, effect):
				continue
			if not _validate_effect_availability(state, controller, str(card_id), effect).get("ok", false):
				continue
			replay_stack_items.append(_create_stack_item_from_effect(state, controller, str(card_id), effect, "triggered", [], 0, {}))
	for index in range(replay_stack_items.size() - 1, -1, -1):
		state.stack.append(replay_stack_items[index])
	var replay_events: Array = []
	if not replay_stack_items.is_empty():
		state.priority_player = 1 - controller
		state.priority_pass_count = 0
	for stack_item_to_queue in replay_stack_items:
		var stack_event = GameEvent.create(state.next_event_id(), "EffectPutOnStack", controller, {
			"stack_id": str(stack_item_to_queue.get("stack_id", "")),
			"source_id": str(stack_item_to_queue.get("source_instance_id", "")),
			"effect_id": str(stack_item_to_queue.get("effect_id", "")),
			"effect_type": str(stack_item_to_queue.get("effect_type", "triggered"))
		})
		stack_event.created_by_command = command_id
		state.event_log.append(stack_event)
		replay_events.append(stack_event)
	return replay_events

func _suncity_tomb_construct_attach_tomb_guards(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	var source_id = str(stack_item.get("source_instance_id", ""))
	if controller < 0 or source_id.is_empty():
		return []
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null:
		return []
	var player = state.get_player(controller)
	var attached: Array[String] = []
	var events: Array = []
	var grave_cards = player.grave.cards.duplicate()
	for raw_card_id in grave_cards:
		var card_id = str(raw_card_id)
		var instance = state.card_instances.get(card_id)
		if instance == null or str(instance.definition_id) != "suncity_s01_0212":
			continue
		if not player.grave.remove_card(card_id):
			continue
		instance.zone = "attached_underlay"
		instance.position = {"host_id": source_id}
		instance.controller = controller
		instance.orientation = "active"
		attached.append(card_id)
		var attached_event = GameEvent.create(state.next_event_id(), "CardAttachedUnderSource", controller, {
			"card_id": card_id,
			"host_id": source_id
		})
		attached_event.created_by_command = command_id
		state.event_log.append(attached_event)
		events.append(attached_event)
	source_instance.flags["suncity_tomb_construct_underlays"] = attached
	return events

func _suncity_tomb_construct_release_tomb_guards(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	var source_id = str(stack_item.get("source_instance_id", ""))
	if controller < 0 or source_id.is_empty():
		return []
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null:
		return []
	var attached_raw = source_instance.flags.get("suncity_tomb_construct_underlays", [])
	source_instance.flags.erase("suncity_tomb_construct_underlays")
	if not (attached_raw is Array):
		return []
	var player = state.get_player(controller)
	var events: Array = []
	for raw_card_id in attached_raw:
		var card_id = str(raw_card_id)
		if card_id.is_empty():
			continue
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		if not player.grave.cards.has(card_id):
			player.grave.add_card_to_top(card_id)
		instance.zone = "grave"
		instance.position = {}
		instance.controller = controller
		instance.orientation = "active"
		events.append_array(_revive_bjorn_source_rested(state, controller, card_id, command_id))
	return events

func _suncity_tutankhamun_entry(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	if _get_battlefield_card_ids_for_player(state, controller).size() >= _get_battlefield_card_ids_for_player(state, 1 - controller).size():
		return []
	var candidates = _matching_grave_card_ids(state, controller, {
		"id": "suncity_s01_0212"
	})
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, min(2, candidates.size()), "选择最多2张陵墓守卫活跃登场", "suncity_tutankhamun_entry", {
		"allow_up_to_count": true
	}, command_id)

func _suncity_tutankhamun_death(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	var source_id = str(stack_item.get("source_instance_id", ""))
	if controller < 0:
		return []
	var candidates = _matching_grave_card_ids(state, controller, {
		"faction": "suncity",
		"exclude_card_id": source_id,
		"max_target_cost": 4
	})
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择1张太阳城卡牌放回牌库顶部", "suncity_tutankhamun_death", {
		"allow_up_to_count": true
	}, command_id)

func _suncity_fearless_assassination(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var target_card_id = str(stack_item.get("targets", {}).get("target_card_id", ""))
	if target_card_id.is_empty():
		return []
	var instance = state.card_instances.get(target_card_id)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return []
	instance.flags["temporary_keyword_must_hit_turn"] = state.turn_number
	instance.flags["cannot_ready_by_effect_turn"] = state.turn_number
	instance.flags["discard_at_turn_end_turn"] = state.turn_number
	return _modify_power_until_turn_end(state, target_card_id, 3000, command_id)

func _suncity_golden_scarab_weaken(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var enemy_id = 1 - controller
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, enemy_id):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null or not definition.is_legion():
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, min(2, candidates.size()), "选择至多2张敌方军团各-1000", "suncity_golden_scarab_weaken", {
		"allow_up_to_count": true
	}, command_id)

func _suncity_medjed_weaken(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var enemy_candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, 1 - controller):
		var instance = state.card_instances.get(str(card_id))
		if instance == null or not _instance_counts_as_legion(state, instance):
			continue
		enemy_candidates.append(str(card_id))
	if enemy_candidates.is_empty():
		return []
	var active_tomb_guards: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(str(card_id))
		if instance == null or str(instance.definition_id) != "suncity_s01_0212":
			continue
		if str(instance.orientation) != "active":
			continue
		active_tomb_guards.append(str(card_id))
	if active_tomb_guards.is_empty():
		return _request_candidate_cards_choice(state, controller, enemy_candidates, 1, "选择对方1张军团本回合兵力-1000", "suncity_medjed_weaken_target", {
			"amount": -1000
		}, command_id)
	return _request_option_choice(state, controller, [
		{"id": "normal", "label": "减1000"},
		{"id": "empower", "label": "休整守卫并减3000"}
	], "选择梅杰德的效果", "suncity_medjed_weaken_mode", {
		"enemy_candidates": enemy_candidates.duplicate(),
		"active_tomb_guards": active_tomb_guards.duplicate()
	}, command_id)

func _suncity_desert_sovereignty(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var candidates = _get_battlefield_card_ids_for_player(state, controller)
	if candidates.is_empty():
		return []
	var options: Array[Dictionary] = []
	for count in range(1, min(3, candidates.size()) + 1):
		options.append({"id": str(count), "label": "弃置%d张" % count})
	return _request_option_choice(state, controller, options, "选择沙漠君临要弃置的军团数量", "suncity_desert_discard_count", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"candidate_ids": candidates
	}, command_id)

func _suncity_repeat_last_active_tactic(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	if controller < 0:
		return []
	var pending = state.get_player(controller).flags.get("last_active_tactic", {})
	if not (pending is Dictionary):
		return []
	if int(pending.get("turn", -1)) != state.turn_number:
		return []
	var source_id = str(pending.get("source_id", ""))
	var effect = pending.get("effect", {})
	if source_id.is_empty() or not (effect is Dictionary) or effect.is_empty():
		return []
	var events = _put_effect_on_stack(state, controller, source_id, effect, "tactic", [], 0, {}, command_id)
	events.append_array(_queue_additional_stack_effects(state, controller, source_id, effect, command_id))
	return events

func _suncity_codex_volume_one(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", -1))
	var target_stack_id = str(stack_item.get("targets", {}).get("target_stack_id", ""))
	if controller < 0 or target_stack_id.is_empty():
		return []
	for candidate in state.stack:
		if str(candidate.get("stack_id", "")) != target_stack_id:
			continue
		var target_controller = int(candidate.get("controller", -1))
		if target_controller < 0:
			return []
		if state.get_player(target_controller).hand.cards.is_empty():
			return _counter_target_stack_item(state, {
				"controller": controller,
				"source_instance_id": str(stack_item.get("source_instance_id", "")),
				"targets": {"target_stack_id": target_stack_id}
			}, command_id)
		return _request_option_choice(state, target_controller, [
			{"id": "discard", "label": "弃置1张"},
			{"id": "counter", "label": "不弃置"}
		], "是否弃置1张手牌令该效果继续发动？", "suncity_codex_force_discard_or_counter", {
			"target_stack_id": target_stack_id,
			"reward_player": controller,
			"source_instance_id": str(stack_item.get("source_instance_id", ""))
		}, command_id)
	return []

func _suncity_codex_mark_reward(state: GameState, target_stack_id: String, reward_player: int, source_instance_id: String) -> void:
	for index in range(state.stack.size() - 1, -1, -1):
		if str(state.stack[index].get("stack_id", "")) != target_stack_id:
			continue
		state.stack[index]["suncity_codex_reward_player"] = reward_player
		state.stack[index]["suncity_codex_reward_source_id"] = source_instance_id
		return

func _suncity_codex_issue_reward(state: GameState, reward_player: int, source_instance_id: String, command_id: String) -> Array:
	var events: Array = []
	events.append_array(DrawActions.draw_cards(state, reward_player, 1, command_id))
	var candidates: Array[String] = []
	for card_id in state.get_player(reward_player).grave.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		var type_name = str(definition.type)
		if type_name != "tactic" and type_name != "artifact":
			continue
		if int(definition.cost) > 3 or _definition_name_contains(definition, "智慧法典"):
			continue
		candidates.append(str(card_id))
	if candidates.is_empty():
		return events
	events.append_array(_request_candidate_cards_choice(state, reward_player, candidates, 1, "选择墓地1张费用不高于3的战术或圣物加入手牌", "return_grave_to_hand", {
		"allow_up_to_count": true,
		"source_instance_id": source_instance_id
	}, command_id))
	return events

func _suncity_codex_handle_stack_reward(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var reward_player = int(stack_item.get("suncity_codex_reward_player", -1))
	if reward_player < 0:
		return []
	var source_instance_id = str(stack_item.get("suncity_codex_reward_source_id", ""))
	if state.pending_choices.is_empty() and state.stack.is_empty():
		return _suncity_codex_issue_reward(state, reward_player, source_instance_id, command_id)
	var pending_rewards = state.get_player(reward_player).flags.get("suncity_pending_codex_rewards", [])
	if not (pending_rewards is Array):
		pending_rewards = []
	pending_rewards.append({
		"source_instance_id": source_instance_id
	})
	state.get_player(reward_player).flags["suncity_pending_codex_rewards"] = pending_rewards
	return []

func _flush_suncity_pending_codex_rewards(state: GameState, command_id: String) -> Array:
	if not state.pending_choices.is_empty() or not state.stack.is_empty():
		return []
	var events: Array = []
	for player_id in range(state.players.size()):
		var pending_rewards = state.get_player(player_id).flags.get("suncity_pending_codex_rewards", [])
		if not (pending_rewards is Array) or pending_rewards.is_empty():
			continue
		state.get_player(player_id).flags.erase("suncity_pending_codex_rewards")
		for reward_info in pending_rewards:
			if not (reward_info is Dictionary):
				continue
			events.append_array(_suncity_codex_issue_reward(state, player_id, str(reward_info.get("source_instance_id", "")), command_id))
		break
	return events

func _sunwukong_deploy_fighter(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	if not (resolution is Dictionary):
		return []
	var amount = int(resolution.get("amount", 0))
	if amount < 2 or amount > 8:
		return []
	var slot_options = _battlefield_slot_options(state, controller)
	if slot_options.is_empty():
		return []
	return _request_option_choice(state, controller, slot_options, "选择登场位置", "sunwukong_deploy_fighter_to_slot", {
		"amount": amount
	}, command_id)

func _sunwukong_deploy_fighter_to_slot(state: GameState, controller: int, row: String, col: int, amount: int, command_id: String) -> Array:
	if row.is_empty() or col < 0:
		return []
	if row == "back" and _is_back_row_blocked_by_calamity(state):
		return []
	var player = state.get_player(controller)
	var existing_id = str(player.flags.get("sunwukong_fighter_card_id", ""))
	if not existing_id.is_empty():
		var existing_instance = state.card_instances.get(existing_id)
		if existing_instance != null and str(existing_instance.zone).begins_with("battle_"):
			return []
	var slot = player.get_slot(row, col)
	if slot == null or not slot.occupant.is_empty():
		return []
	var definition_id = str(player.master_definition_id)
	if definition_id.is_empty() or state.get_definition(definition_id) == null:
		return []
	var card_id = state.create_instance(definition_id, controller, controller)
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	slot.occupant = card_id
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = "active"
	instance.face = "face_up"
	instance.entered_turn = state.turn_number
	instance.flags["manifested_power"] = amount * 1000
	instance.flags["manifested_traits"] = ["legion"]
	instance.flags["sunwukong_master_controller"] = controller
	player.flags["sunwukong_fighter_card_id"] = card_id
	var event = GameEvent.create(state.next_event_id(), "MasterFighterDeployed", controller, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"power": amount * 1000,
		"refund_morale": amount
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	events.append_array(_apply_legion_entry_calamity_for_card(state, card_id, command_id))
	return events

func _yangjian_draw_then_put_back(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var events: Array = []
	events.append_array(DrawActions.draw_cards(state, controller, 1, command_id))
	var hand_cards = state.get_player(controller).hand.cards.duplicate()
	if hand_cards.is_empty():
		return events
	events.append_array(_request_candidate_cards_choice(state, controller, hand_cards, 1, "选择放回的手牌", "yangjian_choose_hand_to_put_back", {}, command_id))
	return events

func _disable_target_died_effects_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "disable_target_died_effects_until_turn_end", command_id)]
	var target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty():
		return [_create_unimplemented_effect_event(state, stack_item, "disable_target_died_effects_until_turn_end", command_id)]
	if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
		return [_create_unimplemented_effect_event(state, stack_item, "disable_target_died_effects_until_turn_end", command_id)]
	var instance = state.card_instances.get(target_card_id)
	if instance == null or not instance.zone.begins_with("battle_"):
		return [_create_unimplemented_effect_event(state, stack_item, "disable_target_died_effects_until_turn_end", command_id)]
	instance.flags["died_effects_disabled_turn"] = state.turn_number
	var event = GameEvent.create(state.next_event_id(), "DiedEffectsDisabledUntilTurnEnd", int(stack_item.get("controller", state.active_player)), {"target_card_id": target_card_id})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	var resolution = stack_item.get("resolution", {})
	if resolution is Dictionary:
		var draw_limit = int(resolution.get("draw_if_own_hand_size_at_most", -1))
		var draw_count = int(resolution.get("draw_count", 0))
		if draw_limit >= 0 and draw_count > 0:
			var controller = int(stack_item.get("controller", state.active_player))
			if state.get_player(controller).hand.cards.size() <= draw_limit:
				events.append_array(DrawActions.draw_cards(state, controller, draw_count, command_id))
	return events

func _cleanup_tactic_source_after_resolution(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var effect_type = str(stack_item.get("effect_type", ""))
	if effect_type != "tactic" and effect_type != "counter_tactic":
		return []
	var source_id = str(stack_item.get("source_instance_id", ""))
	if source_id.is_empty():
		return []
	if _pending_choice_references_source(state, source_id):
		return []
	var instance = state.card_instances.get(source_id)
	if instance == null or instance.zone != "stack_pending":
		return []
	return ZoneActions.move_card_to_grave(state, source_id, "stack_pending", command_id)


func _pending_choice_references_source(state: GameState, source_id: String) -> bool:
	if source_id.is_empty():
		return false
	for raw_choice in state.pending_choices:
		if not (raw_choice is Dictionary):
			continue
		if _pending_choice_source_ids(raw_choice).has(source_id):
			return true
	return false


func _pending_choice_source_ids(choice: Dictionary) -> Array[String]:
	var result: Array[String] = []
	_append_unique_pending_choice_source_id(result, str(choice.get("source_instance_id", "")))
	var context = choice.get("context", {})
	if context is Dictionary:
		_append_unique_pending_choice_source_id(result, str(context.get("source_instance_id", "")))
		var stack_item = context.get("stack_item", {})
		if stack_item is Dictionary:
			_append_unique_pending_choice_source_id(result, str(stack_item.get("source_instance_id", "")))
		var stack_items = context.get("stack_items", [])
		if stack_items is Array:
			for raw_item in stack_items:
				if raw_item is Dictionary:
					_append_unique_pending_choice_source_id(result, str(raw_item.get("source_instance_id", "")))
	return result


func _append_unique_pending_choice_source_id(result: Array[String], source_id: String) -> void:
	if source_id.is_empty() or result.has(source_id):
		return
	result.append(source_id)


func _cleanup_deferred_stack_pending_source_if_needed(state: GameState, source_id: String, command_id: String) -> Array:
	if source_id.is_empty() or _pending_choice_references_source(state, source_id):
		return []
	var instance = state.card_instances.get(source_id)
	if instance == null or str(instance.zone) != "stack_pending":
		return []
	return ZoneActions.move_card_to_grave(state, source_id, "stack_pending", command_id)

func _counter_target_stack_item(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "counter_target_stack", command_id)]
	var target_stack_id = str(targets.get("target_stack_id", ""))
	if target_stack_id.is_empty():
		return [_create_unimplemented_effect_event(state, stack_item, "counter_target_stack", command_id)]
	if target_stack_id == "__pending_attack__":
		return _counter_pending_attack(state, stack_item, command_id)
	for index in range(state.stack.size() - 1, -1, -1):
		var candidate = state.stack[index]
		if str(candidate.get("stack_id", "")) != target_stack_id:
			continue
		state.stack.remove_at(index)
		var event = GameEvent.create(state.next_event_id(), "EffectCountered", int(stack_item.get("controller", state.active_player)), {
			"counter_stack_id": str(stack_item.get("stack_id", "")),
			"target_stack_id": target_stack_id,
			"target_effect_id": str(candidate.get("effect_id", "")),
			"target_source_id": str(candidate.get("source_instance_id", ""))
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		var events: Array = [event]
		events.append_array(_cleanup_tactic_source_after_resolution(state, candidate, command_id))
		return events
	return [_create_unimplemented_effect_event(state, stack_item, "counter_target_stack", command_id)]

func _destroy_target_unit(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "destroy_target_unit", command_id)]
	var target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty():
		return [_create_unimplemented_effect_event(state, stack_item, "destroy_target_unit", command_id)]
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "destroy_target_unit", command_id)]
	if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
		return [_create_unimplemented_effect_event(state, stack_item, "destroy_target_unit", command_id)]
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if not instance.zone.begins_with("battle_") or row.is_empty() or col < 0:
		return [_create_unimplemented_effect_event(state, stack_item, "destroy_target_unit", command_id)]
	return ZoneActions.move_battlefield_to_grave(state, instance.controller, row, col, command_id, {
		"source_card_id": str(stack_item.get("source_instance_id", "")),
		"source_kind": "effect"
	})

func _deal_legion_damage_from_effect(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "deal_legion_damage", command_id)]
	var target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty():
		return [_create_unimplemented_effect_event(state, stack_item, "deal_legion_damage", command_id)]
	var resolution = stack_item.get("resolution", {})
	if not (resolution is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "deal_legion_damage", command_id)]
	var amount = int(resolution.get("amount", 0))
	return _deal_legion_damage(state, str(stack_item.get("source_instance_id", "")), target_card_id, amount, command_id)

func _deal_legion_damage(state: GameState, source_id: String, target_card_id: String, amount: int, command_id: String) -> Array:
	var target = state.card_instances.get(target_card_id)
	if target == null or not target.zone.begins_with("battle_"):
		return []
	var events: Array = []
	target.damage_marked += max(0, amount)
	var damage_event = GameEvent.create(state.next_event_id(), "CardDamaged", int(target.controller), {
		"source_id": source_id,
		"target_card_id": target_card_id,
		"amount": max(0, amount),
		"remaining_power": get_card_power(state, target_card_id)
	})
	damage_event.created_by_command = command_id
	state.event_log.append(damage_event)
	events.append(damage_event)
	if get_card_power(state, target_card_id) <= 0:
		var row = str(target.position.get("row", ""))
		var col = int(target.position.get("col", -1))
		if not row.is_empty() and col >= 0:
			events.append_array(ZoneActions.move_battlefield_to_grave(state, target.controller, row, col, command_id))
	return events

func _return_target_unit_to_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "return_target_unit_to_hand", command_id)]
	var target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty():
		return [_create_unimplemented_effect_event(state, stack_item, "return_target_unit_to_hand", command_id)]
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "return_target_unit_to_hand", command_id)]
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if not instance.zone.begins_with("battle_") or row.is_empty() or col < 0:
		return [_create_unimplemented_effect_event(state, stack_item, "return_target_unit_to_hand", command_id)]
	return ZoneActions.return_battlefield_to_hand(state, instance.controller, row, col, command_id, _effect_event_options_from_stack_item(state, stack_item, stack_item.get("resolution", {})))

func _return_target_unit_to_deck_bottom(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "return_target_unit_to_deck_bottom", command_id)]
	var target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty():
		return [_create_unimplemented_effect_event(state, stack_item, "return_target_unit_to_deck_bottom", command_id)]
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "return_target_unit_to_deck_bottom", command_id)]
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if not instance.zone.begins_with("battle_") or row.is_empty() or col < 0:
		return [_create_unimplemented_effect_event(state, stack_item, "return_target_unit_to_deck_bottom", command_id)]
	return ZoneActions.return_battlefield_to_deck_bottom(state, instance.controller, row, col, command_id)

func _target_card_matches_stack_resolution_filters(state: GameState, stack_item: Dictionary, target_card_id: String) -> bool:
	return _target_card_matches_effect_filters(state, {
		"source_id": str(stack_item.get("source_instance_id", "")),
		"resolution": stack_item.get("resolution", {})
	}, int(stack_item.get("controller", state.active_player)), target_card_id)

func _cost_modifier_target_card_ids(state: GameState, stack_item: Dictionary) -> Array[String]:
	var resolution = stack_item.get("resolution", {})
	if not (resolution is Dictionary):
		return []
	var controller = int(stack_item.get("controller", state.active_player))
	var target_scope := str(resolution.get("target_scope", ""))
	if target_scope == "enemy_hand":
		return _matching_hand_card_ids(state, 1 - controller, resolution)
	if target_scope == "allied_hand":
		return _matching_hand_card_ids(state, controller, resolution)
	if target_scope == "all_hand":
		var hand_candidates: Array[String] = _matching_hand_card_ids(state, controller, resolution)
		for card_id in _matching_hand_card_ids(state, 1 - controller, resolution):
			if not hand_candidates.has(card_id):
				hand_candidates.append(card_id)
		return hand_candidates
	var candidates: Array[String] = []
	if target_scope == "enemy_all_legions" or target_scope == "allied_all_legions" or target_scope == "all_all_legions":
		var remapped_resolution: Dictionary = resolution.duplicate(true)
		match target_scope:
			"enemy_all_legions":
				remapped_resolution["target_scope"] = "enemy_battlefield"
			"allied_all_legions":
				remapped_resolution["target_scope"] = "allied_battlefield"
			"all_all_legions":
				remapped_resolution.erase("target_scope")
		var remapped_stack_item := {
			"controller": controller,
			"source_instance_id": str(stack_item.get("source_instance_id", "")),
			"resolution": remapped_resolution
		}
		for raw_card_id in state.card_instances.keys():
			var target_card_id := str(raw_card_id)
			if _target_card_matches_stack_resolution_filters(state, remapped_stack_item, target_card_id):
				candidates.append(target_card_id)
		return candidates
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	return candidates

func _offer_truce_draw(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var event_options = _effect_event_options_from_stack_item(state, stack_item, stack_item.get("resolution", {}))
	var events: Array = DrawActions.draw_cards(state, controller, 1, command_id, event_options)
	var opponent = 1 - controller
	events.append_array(_request_option_choice(state, opponent, [
		{"id": "agree", "label": "同意议和"},
		{"id": "decline", "label": "拒绝议和"}
	], "议和谈判\n对方是否同意双方各抽1张牌？", "truce_offer", {
		"initiator_player": controller,
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id))
	return events

func _offer_reveal_calamity(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var opponent = 1 - controller
	return _request_option_choice(state, opponent, [
		{"id": "agree", "label": "同意公开"},
		{"id": "decline", "label": "不同意"}
	], "祷告仪式\n对方是否同意公开下1张天灾卡？", "prayer_reveal_offer", {
		"initiator_player": controller,
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id)


func _next_calamity_preview_id(state: GameState) -> String:
	if not state.calamity_deck.is_empty():
		return str(state.calamity_deck[0])
	return "sys_calamity_annihilation"


func _preview_next_calamity(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var next_calamity_id := _next_calamity_preview_id(state)
	if next_calamity_id.is_empty():
		return []
	var title := str(resolution.get("title", "查看下一张待开启的天灾卡"))
	if str(resolution.get("audience", "all")) == "controller":
		var private_event = GameEvent.create(state.next_event_id(), "CardsViewedPrivately", controller, {
			"viewing_player_id": controller,
			"title": title,
			"card_ids": [next_calamity_id]
		})
		private_event.created_by_command = command_id
		state.event_log.append(private_event)
		return [private_event]
	return _broadcast_revealed_cards_popup(state, controller, [next_calamity_id], title, command_id)

func _choose_rune_payment_for_source_attack_bonus(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var available_runes = _player_rune_count(state, controller)
	if available_runes <= 0:
		return []
	var resolution = stack_item.get("resolution", {})
	var max_runes = int(resolution.get("max_runes", available_runes))
	if max_runes <= 0:
		return []
	var selectable = min(available_runes, max_runes)
	var options: Array[Dictionary] = []
	for rune_count in range(1, selectable + 1):
		options.append({
			"id": str(rune_count),
			"label": "消耗%s符文" % rune_count
		})
	return _request_option_choice(state, controller, options, str(resolution.get("title", "选择要消耗的符文数量")), "choose_rune_payment_for_source_attack_bonus", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"power_per_rune": int(resolution.get("power_per_rune", 0)),
		"master_damage_per_rune": int(resolution.get("master_damage_per_rune", 0))
	}, command_id)

func _bijie_reveal_top_bijie_or_reorder(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	if player.deck.cards.is_empty():
		return []
	var top_id = str(player.deck.cards[0])
	var instance = state.card_instances.get(top_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	var events = _tianting_reveal_card(state, controller, top_id, "deck_top", command_id)
	var options: Array[Dictionary] = [
		{"id": "top", "label": "放回牌库顶部"},
		{"id": "bottom", "label": "放回牌库底部"}
	]
	if _definition_matches_required_faction_for_instance(state, instance, definition, "bijie"):
		options.push_front({"id": "hand", "label": "加入手牌"})
	return events + _request_option_choice(state, controller, options, "阿麦金：选择处理方式", "bijie_reveal_top_bijie_or_reorder", {
		"card_id": top_id
	}, command_id)

func _grant_master_damage_bonus(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "grant_master_damage_bonus", command_id)]
	var target_card_id = ""
	if targets is Dictionary:
		target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty() and str(stack_item.get("resolution", {}).get("target_scope", "")) == "self":
		target_card_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "grant_master_damage_bonus", command_id)]
	var resolution = stack_item.get("resolution", {})
	instance.flags["master_damage_bonus_turn"] = state.turn_number
	instance.flags["master_damage_bonus_amount"] = int(resolution.get("amount", 1))
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": target_card_id,
		"buff": "master_damage_bonus",
		"amount": int(instance.flags.get("master_damage_bonus_amount", 0))
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _grant_cannot_die_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	var target_card_id = ""
	if targets is Dictionary:
		target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty() and str(stack_item.get("resolution", {}).get("target_scope", "")) == "self":
		target_card_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "grant_cannot_die_until_turn_end", command_id)]
	instance.flags["cannot_die_until_turn_end_turn"] = state.turn_number
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": target_card_id,
		"buff": "cannot_die_until_turn_end"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _grant_cannot_die_once_until_next_own_turn_start(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	var target_card_id = ""
	if targets is Dictionary:
		target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty() and str(stack_item.get("resolution", {}).get("target_scope", "")) == "self":
		target_card_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "grant_cannot_die_once_until_next_own_turn_start", command_id)]
	var controller = int(stack_item.get("controller", instance.controller))
	instance.flags["cannot_die_until_next_own_turn_start_player"] = controller
	instance.flags.erase("cannot_die_until_next_own_turn_start_used")
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": target_card_id,
		"buff": "cannot_die_once_until_next_own_turn_start"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _both_players_discard_then_draw(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var opponent = 1 - controller
	var resolution = stack_item.get("resolution", {})
	var controller_discard = int(resolution.get("controller_discard", 1))
	var opponent_discard = int(resolution.get("opponent_discard", 1))
	var first_discard_action = {
		"action": "request_hand_discard_choice",
		"player_id": controller,
		"discard_count": controller_discard,
		"show_all_hands_highlight": true,
		"title": "黑胡子蒂奇：打出方选择弃置",
		"requires_confirm": true,
		"hint_text": "黑胡子蒂奇登场：请打出方先从全部高亮手牌中选择 %d 张，再点击确认。随后对手也要选择并确认；双方都完成后，再由打出方抽2张、对方抽1张。" % max(1, controller_discard),
		"top_hint_text": "黑胡子蒂奇登场：请打出方先从高亮手牌中选择 %d 张并确认弃置。" % max(1, controller_discard),
		"follow_up_action": {
			"action": "request_hand_discard_choice",
			"player_id": opponent,
			"discard_count": opponent_discard,
			"show_all_hands_highlight": true,
			"title": "黑胡子蒂奇：对手选择弃置",
			"requires_confirm": true,
			"hint_text": "黑胡子蒂奇登场：请对手从全部高亮手牌中选择 %d 张，再点击确认。完成后才会开始抽牌结算。" % max(1, opponent_discard),
			"top_hint_text": "黑胡子蒂奇登场：请对手从高亮手牌中选择 %d 张并确认弃置。" % max(1, opponent_discard),
			"follow_up_action": {
				"action": "draw_cards_after_both_players_discard",
				"controller": controller,
				"opponent": opponent,
				"controller_draw": int(resolution.get("controller_draw", 0)),
				"opponent_draw": int(resolution.get("opponent_draw", 0))
			}
		}
	}
	return _resolve_stack_follow_up_action(state, stack_item, first_discard_action, command_id)

func _request_hand_discard_choice_from_resolution(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
	var player_scope = str(resolution.get("player_scope", ""))
	var controller = int(stack_item.get("controller", state.active_player))
	if player_scope == "controller":
		player_id = controller
	elif player_scope == "opponent":
		player_id = 1 - controller
	elif player_scope == "event_player":
		player_id = _player_id_from_trigger_event(state, int(stack_item.get("created_from_event_id", 0)), player_id)
	var discard_count = int(resolution.get("discard_count", 1))
	var candidates: Array[String] = []
	for card_id in state.get_player(player_id).hand.cards:
		candidates.append(str(card_id))
	discard_count = min(discard_count, candidates.size())
	if discard_count <= 0 or candidates.is_empty():
		return _resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id)
	var context: Dictionary = resolution.duplicate(true)
	context.erase("action")
	if bool(resolution.get("show_all_hands_highlight", false)):
		var highlight_card_ids: Array[String] = []
		for hand_card_id in state.get_player(0).hand.cards:
			highlight_card_ids.append(str(hand_card_id))
		for hand_card_id in state.get_player(1).hand.cards:
			highlight_card_ids.append(str(hand_card_id))
		context["highlight_card_ids"] = highlight_card_ids
	return _request_candidate_cards_choice(
		state,
		player_id,
		candidates,
		discard_count,
		str(resolution.get("title", "选择手牌弃置")),
		"discard_from_hand",
		context,
		command_id
	)

func _request_battlefield_reduce_choice_from_resolution(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
	var keep_at_most = int(resolution.get("keep_at_most", 2))
	var candidates: Array[String] = _get_battlefield_legion_card_ids_for_player(state, player_id) if bool(resolution.get("legions_only", false)) else _get_battlefield_card_ids_for_player(state, player_id)
	var remove_count = candidates.size() - keep_at_most
	if remove_count <= 0 or candidates.is_empty():
		return _resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id)
	var context: Dictionary = resolution.duplicate(true)
	context.erase("action")
	return _request_candidate_cards_choice(
		state,
		player_id,
		candidates,
		remove_count,
		str(resolution.get("title", "选择要置入墓地的军团")),
		"destroy_battlefield_card",
		context,
		command_id
	)

func _request_return_battlefield_choice_from_resolution(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
	var candidates: Array[String] = _get_battlefield_legion_card_ids_for_player(state, player_id) if bool(resolution.get("legions_only", false)) else _get_battlefield_card_ids_for_player(state, player_id)
	if candidates.is_empty():
		return _resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id)
	var context: Dictionary = resolution.duplicate(true)
	context.erase("action")
	return _request_candidate_cards_choice(
		state,
		player_id,
		candidates,
		1,
		str(resolution.get("title", "选择返回手牌的军团")),
		"return_battlefield_card_to_hand",
		context,
		command_id
	)

func _request_hand_return_to_deck_bottom_choice_from_resolution(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	var player_id = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
	var candidates: Array[String] = []
	for card_id in state.get_player(player_id).hand.cards:
		candidates.append(str(card_id))
	if candidates.is_empty():
		return _resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id)
	var context: Dictionary = resolution.duplicate(true)
	context.erase("action")
	context["drag_reorder_all_candidates"] = bool(resolution.get("drag_reorder_all_candidates", false))
	return _request_candidate_cards_choice(
		state,
		player_id,
		candidates,
		candidates.size(),
		str(resolution.get("title", "选择返回牌库底部的手牌")),
		"return_hand_to_deck_bottom",
		context,
		command_id
	)

func _draw_cards_for_players(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	var count = int(resolution.get("count", 1))
	var event_options: Dictionary = resolution.get("event_options", {}).duplicate(true) if resolution.get("event_options", {}) is Dictionary else {}
	var events: Array = []
	for player_id in range(state.players.size()):
		events.append_array(DrawActions.draw_cards(state, player_id, count, command_id, event_options))
	return events

func _draw_cards_after_both_players_discard(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	var controller = int(resolution.get("controller", stack_item.get("controller", state.active_player)))
	var opponent = int(resolution.get("opponent", 1 - controller))
	var event_options: Dictionary = resolution.get("event_options", {}).duplicate(true) if resolution.get("event_options", {}) is Dictionary else {}
	var events: Array = []
	var controller_draw = int(resolution.get("controller_draw", 0))
	var opponent_draw = int(resolution.get("opponent_draw", 0))
	if controller_draw > 0:
		events.append_array(DrawActions.draw_cards(state, controller, controller_draw, command_id, event_options))
	if opponent_draw > 0:
		events.append_array(DrawActions.draw_cards(state, opponent, opponent_draw, command_id, event_options))
	return events

func _conceal_source(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return []
	instance.flags["concealed"] = true
	instance.face = "face_down"
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": source_id,
		"buff": "concealed"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _reveal_source_face_up(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if instance == null or not bool(instance.flags.get("concealed", false)):
		return []
	instance.flags.erase("concealed")
	instance.face = "face_up"
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": source_id,
		"buff": "revealed"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _counter_pending_attack(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	if state.pending_attack.is_empty():
		return []
	var attack = state.pending_attack.duplicate(true)
	state.pending_attack.clear()
	state.priority_pass_count = 0
	state.priority_player = state.active_player
	var attacker_id := str(attack.get("attacker_id", ""))
	var attacker = state.card_instances.get(attacker_id)
	if attacker != null:
		attacker.has_attacked_this_turn = true
		attacker.orientation = "rested"
	var event = GameEvent.create(state.next_event_id(), "AttackCountered", int(stack_item.get("controller", state.active_player)), {
		"attacker_id": attacker_id,
		"defender_id": str(attack.get("defender_id", "")),
		"target_kind": str(attack.get("target_kind", "card"))
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _tianting_counter_pending_attack_then_draw_if_no_frontline(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var events = _counter_pending_attack(state, stack_item, command_id)
	var has_frontline := false
	for slot in state.get_player(controller).battle_front:
		if not str(slot.occupant).is_empty():
			has_frontline = true
			break
	if not has_frontline:
		events.append_array(DrawActions.draw_cards(state, controller, 1, command_id))
	return events

func _modify_cost_until_turn_end(state: GameState, target_card_id: String, amount: int, command_id: String) -> Array:
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return []
	instance.flags["cost_modifier_until_turn_end"] = int(instance.flags.get("cost_modifier_until_turn_end", 0)) + amount
	var event = GameEvent.create(state.next_event_id(), "CardCostModified", int(instance.controller), {
		"card_id": target_card_id,
		"amount": int(instance.flags.get("cost_modifier_until_turn_end", 0)),
		"effective_cost": _get_effective_card_cost(state, target_card_id)
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _modify_cost_until_next_own_turn_end(state: GameState, target_card_id: String, amount: int, expires_on_player_turn_end: int, command_id: String) -> Array:
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return []
	_add_timed_modifier_for_card(state, target_card_id, "cost", amount, expires_on_player_turn_end)
	var event = GameEvent.create(state.next_event_id(), "CardCostModified", int(instance.controller), {
		"card_id": target_card_id,
		"amount": amount,
		"duration": "until_next_own_turn_end",
		"effective_cost": _get_effective_card_cost(state, target_card_id)
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _modify_target_cost(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "modify_target_cost", command_id)]
	var target_card_id = str(targets.get("target_card_id", ""))
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "modify_target_cost", command_id)]
	var resolution = stack_item.get("resolution", {})
	instance.flags["cost_modifier_until_turn_end"] = int(instance.flags.get("cost_modifier_until_turn_end", 0)) + int(resolution.get("amount", -1))
	var event = GameEvent.create(state.next_event_id(), "CardCostModified", int(instance.controller), {
		"card_id": target_card_id,
		"amount": int(instance.flags.get("cost_modifier_until_turn_end", 0)),
		"effective_cost": _get_effective_card_cost(state, target_card_id)
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _modify_matching_cost(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var amount = int(stack_item.get("resolution", {}).get("amount", -1))
	for target_card_id in _cost_modifier_target_card_ids(state, stack_item):
		var instance = state.card_instances.get(target_card_id)
		if instance == null:
			continue
		instance.flags["cost_modifier_until_turn_end"] = int(instance.flags.get("cost_modifier_until_turn_end", 0)) + amount
		var event = GameEvent.create(state.next_event_id(), "CardCostModified", int(instance.controller), {
			"card_id": target_card_id,
			"amount": int(instance.flags.get("cost_modifier_until_turn_end", 0)),
			"turn_number": state.turn_number
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _add_timed_modifier_for_card(state: GameState, card_id: String, stat: String, amount: int, expires_on_player_turn_end: int) -> void:
	var remaining_turn_ends := 1
	if state.active_player == expires_on_player_turn_end:
		remaining_turn_ends = 2
	state.timed_modifiers.append({
		"stat": stat,
		"amount": amount,
		"target_card_id": card_id,
		"expires_on_player_turn_end": expires_on_player_turn_end,
		"remaining_turn_ends": remaining_turn_ends
	})

func _modify_target_cost_until_next_own_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "modify_target_cost_until_next_own_turn_end", command_id)]
	var target_card_id = str(targets.get("target_card_id", ""))
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "modify_target_cost_until_next_own_turn_end", command_id)]
	var resolution = stack_item.get("resolution", {})
	var amount = int(resolution.get("amount", 0))
	_add_timed_modifier_for_card(state, target_card_id, "cost", amount, int(stack_item.get("controller", state.active_player)))
	var event = GameEvent.create(state.next_event_id(), "CardCostModified", int(instance.controller), {
		"card_id": target_card_id,
		"amount": amount,
		"duration": "until_next_own_turn_end",
		"effective_cost": _get_effective_card_cost(state, target_card_id)
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _modify_matching_cost_until_next_own_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var controller = int(stack_item.get("controller", state.active_player))
	var amount = int(stack_item.get("resolution", {}).get("amount", 0))
	for target_card_id in _cost_modifier_target_card_ids(state, stack_item):
		var instance = state.card_instances.get(target_card_id)
		if instance == null:
			continue
		_add_timed_modifier_for_card(state, target_card_id, "cost", amount, controller)
		var event = GameEvent.create(state.next_event_id(), "CardCostModified", int(instance.controller), {
			"card_id": target_card_id,
			"amount": amount,
			"duration": "until_next_own_turn_end",
			"effective_cost": _get_effective_card_cost(state, target_card_id)
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _modify_matching_power_until_next_own_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var controller = int(stack_item.get("controller", state.active_player))
	var amount = int(stack_item.get("resolution", {}).get("amount", 0))
	for target_card_id in _get_battlefield_card_ids(state):
		if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			continue
		var instance = state.card_instances.get(target_card_id)
		if instance == null:
			continue
		_add_timed_modifier_for_card(state, target_card_id, "power", amount, controller)
		var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
			"card_id": target_card_id,
			"buff": "power_modifier_until_next_own_turn_end",
			"amount": amount
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
		events.append_array(_move_battlefield_card_to_grave_if_power_zero(state, target_card_id, command_id))
	return events

func _modify_power_until_next_own_turn_end(state: GameState, target_card_id: String, amount: int, expires_on_player_turn_end: int, command_id: String) -> Array:
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return []
	_add_timed_modifier_for_card(state, target_card_id, "power", amount, expires_on_player_turn_end)
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": target_card_id,
		"buff": "power_modifier_until_next_own_turn_end",
		"amount": amount
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	events.append_array(_move_battlefield_card_to_grave_if_power_zero(state, target_card_id, command_id))
	return events

func _recycle_grave_to_deck(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var resolution = stack_item.get("resolution", {})
	var controller = int(resolution.get("player_id", stack_item.get("controller", state.active_player)))
	var count = int(resolution.get("count", 1))
	var event_options: Dictionary = resolution.get("event_options", {}).duplicate(true) if resolution.get("event_options", {}) is Dictionary else {}
	var resolved_count: int = count
	var require_exact_count = bool(resolution.get("require_exact_count", false))
	var always_request_choice = bool(resolution.get("always_request_choice", false))
	var candidates = _matching_grave_card_ids(state, controller, resolution)
	if candidates.is_empty():
		var heal_amount = int(resolution.get("heal_master", 0))
		var no_candidate_events: Array = []
		if heal_amount > 0:
			no_candidate_events.append_array(_heal_master(state, controller, heal_amount, command_id, event_options))
		if not require_exact_count:
			no_candidate_events.append_array(_resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id))
		return no_candidate_events
	if require_exact_count and candidates.size() < count:
		return []
	if not require_exact_count:
		resolved_count = min(count, candidates.size())
	if always_request_choice or candidates.size() > resolved_count:
		return _request_candidate_cards_choice(state, controller, candidates, resolved_count, str(resolution.get("title", "选择墓地卡牌返回牌库底部")), "recycle_grave_to_deck", {
			"heal_master": int(resolution.get("heal_master", 0)),
			"event_options": event_options.duplicate(true),
			"source_instance_id": str(stack_item.get("source_instance_id", "")),
			"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true),
			"require_exact_count": require_exact_count,
			"always_request_choice": always_request_choice,
			"requires_confirm": bool(resolution.get("requires_confirm", false)),
			"drag_reorder_all_candidates": bool(resolution.get("drag_reorder_all_candidates", false)),
			"hint_text": str(resolution.get("hint_text", "")),
			"top_hint_text": str(resolution.get("top_hint_text", ""))
		}, command_id)
	var events = _move_grave_cards_to_deck_bottom(state, controller, candidates.slice(0, resolved_count), command_id, event_options)
	var heal_amount = int(resolution.get("heal_master", 0))
	if heal_amount > 0:
		events.append_array(_heal_master(state, controller, heal_amount, command_id, event_options))
	events.append_array(_resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id))
	return events

func _recycle_grave_then_revive_source_from_grave(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var source_id = str(stack_item.get("source_instance_id", ""))
	var count = int(resolution.get("count", 3))
	if source_id.is_empty() or count <= 0:
		return []
	if not state.get_player(controller).grave.cards.has(source_id):
		return []
	var candidates = _matching_grave_card_ids(state, controller, {
		"exclude_card_id": source_id
	})
	if candidates.size() < count:
		return []
	return _request_candidate_cards_choice(state, controller, candidates, count, str(resolution.get("title", "选择3张墓地卡牌返回牌库底部")), "recycle_grave_then_revive_source_from_grave", {
		"source_instance_id": source_id,
		"requires_confirm": bool(resolution.get("requires_confirm", true)),
		"drag_reorder_all_candidates": bool(resolution.get("drag_reorder_all_candidates", false)),
		"hint_text": str(resolution.get("hint_text", "")),
		"top_hint_text": str(resolution.get("top_hint_text", ""))
	}, command_id)

func _thor_hammer_grave_revive(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var hammer_candidates = _matching_definition_card_ids(state, state.get_player(controller).grave.cards, "asgard_s02_0301")
	if hammer_candidates.is_empty():
		return []
	var forwarded_stack_item = stack_item.duplicate(true)
	forwarded_stack_item["controller"] = controller
	forwarded_stack_item["source_instance_id"] = str(hammer_candidates[0])
	return _recycle_grave_then_revive_source_from_grave(state, forwarded_stack_item, command_id)

func _resolve_bjorn_recycle_and_maybe_rested_revive(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var count = int(resolution.get("count", 4))
	var source_id = str(stack_item.get("source_instance_id", ""))
	if source_id.is_empty():
		return []
	var candidates = _matching_grave_card_ids(state, controller, {
		"exclude_card_id": source_id
	})
	if candidates.size() < count:
		return []
	var revive_slot := _bjorn_rested_revive_slot_from_trigger(state, controller, stack_item)
	if revive_slot.is_empty():
		return []
	var events = _deal_master_damage(state, controller, 1, command_id)
	return events + _request_candidate_cards_choice(state, controller, candidates, count, "选择墓地卡牌返回牌库底部", "bjorn_recycle_then_maybe_revive", {
		"source_instance_id": source_id,
		"revive_row": str(revive_slot.get("row", "")),
		"revive_col": int(revive_slot.get("col", -1))
	}, command_id)

func _revive_from_grave(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var count = int(resolution.get("count", 1))
	var rested = bool(resolution.get("rested", false))
	var allow_up_to_count = bool(resolution.get("allow_up_to_count", false))
	var candidates = _matching_grave_card_ids(state, controller, resolution)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() <= count and not allow_up_to_count:
		if rested:
			return _revive_bjorn_source_rested(state, controller, str(candidates[0]), command_id)
		return _revive_grave_card_to_first_slot(state, controller, str(candidates[0]), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, min(count, candidates.size()), "选择墓地军团%s登场" % ("休整" if rested else "活跃"), "revive_from_grave", {
		"rested": rested,
		"allow_up_to_count": allow_up_to_count
	}, command_id)

func _choose_and_destroy_unit(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var targets = stack_item.get("targets", {})
	if targets is Dictionary and not str(targets.get("target_card_id", "")).is_empty():
		return _destroy_target_unit(state, stack_item, command_id)
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() == 1:
		var choice_stack_item = stack_item.duplicate(true)
		choice_stack_item["targets"] = {"target_card_id": str(candidates[0])}
		return _destroy_target_unit(state, choice_stack_item, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要击杀的军团", "destroy_battlefield_card", {}, command_id)

func _choose_and_destroy_units(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	var max_count: int = min(max(1, int(resolution.get("count", 1))), candidates.size())
	return _request_candidate_cards_choice(state, controller, candidates, max_count, "选择要击杀的军团", "destroy_battlefield_cards", {
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", false)),
		"resolution": resolution.duplicate(true)
	}, command_id)

func _destroy_unit_by_battlefield_counter_tactic_count(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var counter_tactic_count = _battlefield_counter_tactic_count(state)
	if counter_tactic_count <= 0:
		return []
	var scoped_stack_item: Dictionary = stack_item.duplicate(true)
	var resolution = scoped_stack_item.get("resolution", {})
	if not (resolution is Dictionary):
		resolution = {}
	else:
		resolution = resolution.duplicate(true)
	resolution["max_target_cost"] = counter_tactic_count
	scoped_stack_item["resolution"] = resolution
	return _choose_and_destroy_unit(state, scoped_stack_item, command_id)

func _choose_and_return_unit_to_deck_bottom(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var targets = stack_item.get("targets", {})
	if targets is Dictionary and not str(targets.get("target_card_id", "")).is_empty():
		return _return_target_unit_to_deck_bottom(state, stack_item, command_id)
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() == 1:
		return _modify_and_return_battlefield_card_to_deck_bottom(state, str(candidates[0]), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要返回牌库底部的军团", "return_battlefield_card_to_deck_bottom", {}, command_id)

func _choose_and_grant_keyword_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var target_scope = str(resolution.get("target_scope", "allied_battlefield"))
	var candidate_owner = controller if target_scope != "enemy_battlefield" else 1 - controller
	var candidates = _matching_battlefield_cards_for_player(state, candidate_owner, resolution)
	if bool(resolution.get("target_trial_legion", false)):
		var filtered: Array[String] = []
		for candidate_id in candidates:
			var candidate_instance = state.card_instances.get(str(candidate_id))
			var candidate_definition = state.get_definition(candidate_instance.definition_id) if candidate_instance != null else null
			if _definition_is_trial_legion(candidate_definition):
				filtered.append(str(candidate_id))
		candidates = filtered
	if candidates.is_empty():
		return []
	if candidates.size() == 1:
		return _grant_keyword_to_card_until_turn_end(state, str(candidates[0]), str(resolution.get("keyword", "")), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, str(resolution.get("title", "选择军团获得关键词")), "grant_keyword_until_turn_end", {
		"keyword": str(resolution.get("keyword", ""))
	}, command_id)

func _modify_and_return_battlefield_card_to_deck_bottom(state: GameState, card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if row.is_empty() or col < 0:
		return []
	return ZoneActions.return_battlefield_to_deck_bottom(state, instance.controller, row, col, command_id)

func _choose_and_rest_unit(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() == 1:
		return _rest_target_unit(state, str(candidates[0]), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要转为休整的军团", "rest_battlefield_card", {}, command_id)

func _choose_and_ready_unit(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() == 1:
		return _ready_target_unit(state, str(candidates[0]), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要转为活跃的军团", "ready_battlefield_card", {}, command_id)

func _choose_and_grant_cannot_die_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var targets = stack_item.get("targets", {})
	if targets is Dictionary and not str(targets.get("target_card_id", "")).is_empty():
		return _grant_cannot_die_until_turn_end(state, stack_item, command_id)
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() == 1:
		var targeted_stack_item: Dictionary = stack_item.duplicate(true)
		targeted_stack_item["targets"] = {"target_card_id": str(candidates[0])}
		return _grant_cannot_die_until_turn_end(state, targeted_stack_item, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择获得免死的军团", "target_then_stack_effect", {
		"stack_item": stack_item.duplicate(true)
	}, command_id)

func _choose_and_grant_cannot_die_once_until_next_own_turn_start(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var targets = stack_item.get("targets", {})
	if targets is Dictionary and not str(targets.get("target_card_id", "")).is_empty():
		return _grant_cannot_die_once_until_next_own_turn_start(state, stack_item, command_id)
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	var max_count: int = min(max(1, int(resolution.get("count", 1))), candidates.size())
	if not _uses_formal_rules(state) and candidates.size() == 1 and max_count == 1:
		var targeted_stack_item: Dictionary = stack_item.duplicate(true)
		targeted_stack_item["targets"] = {"target_card_id": str(candidates[0])}
		return _grant_cannot_die_once_until_next_own_turn_start(state, targeted_stack_item, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, max_count, "选择获得免死的军团", "target_then_stack_effect", {
		"stack_item": stack_item.duplicate(true),
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", false))
	}, command_id)

func _choose_and_modify_cost_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var targets = stack_item.get("targets", {})
	if bool(resolution.get("use_selected_target", false)) and targets is Dictionary and not str(targets.get("target_card_id", "")).is_empty():
		return _modify_cost_until_turn_end(state, str(targets.get("target_card_id", "")), int(resolution.get("amount", 0)), command_id)
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() == 1:
		return _modify_cost_until_turn_end(state, str(candidates[0]), int(resolution.get("amount", 0)), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要获得费用修正的军团", "modify_cost_until_turn_end", {
		"amount": int(resolution.get("amount", 0)),
		"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true),
		"initiator_player": controller,
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id)

func _hijikata_entry_destroy_combo(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates = _matching_battlefield_cards_for_player(state, 1 - controller, {
		"target_scope": "enemy_battlefield",
		"type": "legion",
		"max_target_cost": 2
	})
	if candidates.is_empty():
		return []
	var cost_one_or_less: Array[String] = []
	var cost_two_only: Array[String] = []
	for card_id in candidates:
		var effective_cost := _get_effective_card_cost(state, str(card_id))
		if effective_cost <= 1:
			cost_one_or_less.append(str(card_id))
		elif effective_cost == 2:
			cost_two_only.append(str(card_id))
	if cost_one_or_less.is_empty() and cost_two_only.is_empty():
		return []
	var max_select_count: int = 1 if cost_one_or_less.is_empty() else min(2, candidates.size())
	return _request_candidate_cards_choice(state, controller, candidates, max_select_count, "选择要击杀的军团", "hijikata_entry_destroy_combo", {
		"requires_confirm": true,
		"min_select_count": 1,
		"allow_single_confirm": candidates.size() < 2 or cost_one_or_less.is_empty(),
		"hint_text": "选择对方1张费用不高于2和1张费用不高于1的军团。",
		"top_hint_text": "土方岁三：选择对方1张费用不高于2和1张费用不高于1的军团。",
		"cost_one_or_less_ids": cost_one_or_less.duplicate(),
		"cost_two_only_ids": cost_two_only.duplicate()
	}, command_id)

func _choose_and_modify_cost_until_next_own_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() == 1:
		return _modify_cost_until_next_own_turn_end(state, str(candidates[0]), int(resolution.get("amount", 0)), controller, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要获得费用修正的军团", "modify_cost_until_next_own_turn_end", {
		"amount": int(resolution.get("amount", 0)),
		"expires_on_player_turn_end": controller
	}, command_id)

func _choose_and_modify_power_until_next_own_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	if not _uses_formal_rules(state) and candidates.size() == 1:
		return _modify_power_until_next_own_turn_end(state, str(candidates[0]), int(resolution.get("amount", 0)), controller, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要获得兵力修正的军团", "modify_power_until_next_own_turn_end", {
		"amount": int(resolution.get("amount", 0)),
		"expires_on_player_turn_end": controller
	}, command_id)

func _choose_and_modify_power_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var targets = stack_item.get("targets", {})
	if bool(resolution.get("use_selected_target", false)) and targets is Dictionary and not str(targets.get("target_card_id", "")).is_empty():
		return _modify_power_until_turn_end(state, str(targets.get("target_card_id", "")), int(resolution.get("amount", 0)), command_id)
	var candidates: Array[String] = []
	for target_card_id in _get_battlefield_card_ids(state):
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			candidates.append(target_card_id)
	if candidates.is_empty():
		return []
	var max_count: int = min(max(1, int(resolution.get("count", 1))), candidates.size())
	if not _uses_formal_rules(state) and candidates.size() == 1 and max_count == 1:
		return _modify_power_until_turn_end(state, str(candidates[0]), int(stack_item.get("resolution", {}).get("amount", 0)), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, max_count, "选择要获得兵力修正的军团", "modify_power_until_turn_end", {
		"amount": int(stack_item.get("resolution", {}).get("amount", 0)),
		"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true),
		"initiator_player": controller,
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", false))
	}, command_id)

func _modify_matching_power_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var amount = int(stack_item.get("resolution", {}).get("amount", 0))
	for target_card_id in _get_battlefield_card_ids(state):
		if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			continue
		events.append_array(_modify_power_until_turn_end(state, target_card_id, amount, command_id))
	return events

func _disable_matching_support_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var events: Array = []
	for target_card_id in _get_battlefield_card_ids(state):
		if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			continue
		var instance = state.card_instances.get(target_card_id)
		if instance == null:
			continue
		instance.flags["cannot_support_until_turn_end_turn"] = state.turn_number
		var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
			"card_id": target_card_id,
			"buff": "cannot_support_until_turn_end",
			"amount": 1
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _modify_source_power_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	if source_id.is_empty():
		return []
	return _modify_power_until_turn_end(state, source_id, int(stack_item.get("resolution", {}).get("amount", 0)), command_id)

func _grant_source_keyword_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var keyword = str(stack_item.get("resolution", {}).get("keyword", ""))
	return _grant_keyword_to_card_until_turn_end(state, source_id, keyword, command_id)

func _grant_keyword_to_card_until_turn_end(state: GameState, card_id: String, keyword: String, command_id: String) -> Array:
	if card_id.is_empty() or keyword.is_empty():
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.flags["temporary_keyword_%s_turn" % keyword] = state.turn_number
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": card_id,
		"buff": "temporary_keyword",
		"keyword": keyword
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _prepare_next_played_legion_keyword(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var keyword = str(resolution.get("keyword", ""))
	if keyword.is_empty():
		return []
	var player = state.get_player(controller)
	player.flags["next_played_legion_keyword"] = {
		"turn": state.turn_number,
		"keyword": keyword,
		"max_cost": int(resolution.get("max_cost", -1)),
		"definition_id": str(resolution.get("definition_id", ""))
	}
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"card_id": str(stack_item.get("source_instance_id", "")),
		"buff": "next_played_legion_keyword",
		"keyword": keyword
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _prepare_next_played_legion_cost_modifier(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var amount = int(resolution.get("amount", 0))
	if amount == 0:
		return []
	var player = state.get_player(controller)
	player.flags["next_played_legion_cost_modifier"] = {
		"turn": state.turn_number,
		"amount": amount,
		"definition_id": str(resolution.get("definition_id", "")),
		"max_cost": int(resolution.get("max_cost", -1)),
		"faction": str(resolution.get("faction", ""))
	}
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"card_id": str(stack_item.get("source_instance_id", "")),
		"buff": "next_played_legion_cost_modifier",
		"amount": amount
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _grant_matching_free_move_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var resolution = stack_item.get("resolution", {})
	var effect_id = str(resolution.get("effect_id", "granted_free_move"))
	var once_key = str(resolution.get("once_per_turn_key", effect_id))
	var player_once_per_turn = bool(resolution.get("player_once_per_turn", false))
	var any_slot = bool(resolution.get("any_slot", false))
	var swap_with_allied_occupied_slot = bool(resolution.get("swap_with_allied_occupied_slot", false))
	for target_card_id in _get_battlefield_card_ids(state):
		if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			continue
		var instance = state.card_instances.get(target_card_id)
		if instance == null:
			continue
		instance.flags["free_move_until_turn_end_turn"] = state.turn_number
		instance.flags["free_move_until_turn_end_effect_id"] = effect_id
		instance.flags["free_move_until_turn_end_once_key"] = once_key
		instance.flags["free_move_until_turn_end_player_once_per_turn"] = player_once_per_turn
		instance.flags["free_move_until_turn_end_any_slot"] = any_slot
		instance.flags["free_move_until_turn_end_swap_with_allied_occupied_slot"] = swap_with_allied_occupied_slot
		var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
			"card_id": target_card_id,
			"buff": "free_move_until_turn_end",
			"effect_id": effect_id,
			"any_slot": any_slot,
			"swap_with_allied_occupied_slot": swap_with_allied_occupied_slot
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _grant_selected_free_move_until_turn_end(state: GameState, selected: Array[String], context: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var effect_id := str(context.get("free_move_effect_id", "granted_free_move"))
	var once_key := str(context.get("free_move_once_per_turn_key", effect_id))
	var player_once_per_turn := bool(context.get("free_move_player_once_per_turn", false))
	var any_slot := bool(context.get("free_move_any_slot", false))
	var swap_with_allied_occupied_slot := bool(context.get("free_move_swap_with_allied_occupied_slot", false))
	for target_card_id in selected:
		var instance = state.card_instances.get(target_card_id)
		if instance == null or not str(instance.zone).begins_with("battle_"):
			continue
		instance.flags["free_move_until_turn_end_turn"] = state.turn_number
		instance.flags["free_move_until_turn_end_effect_id"] = effect_id
		instance.flags["free_move_until_turn_end_once_key"] = once_key
		instance.flags["free_move_until_turn_end_player_once_per_turn"] = player_once_per_turn
		instance.flags["free_move_until_turn_end_any_slot"] = any_slot
		instance.flags["free_move_until_turn_end_swap_with_allied_occupied_slot"] = swap_with_allied_occupied_slot
		var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
			"card_id": target_card_id,
			"buff": "free_move_until_turn_end",
			"effect_id": effect_id,
			"any_slot": any_slot,
			"swap_with_allied_occupied_slot": swap_with_allied_occupied_slot
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _apply_next_played_legion_keyword(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var pending = player.flags.get("next_played_legion_keyword", {})
	if not (pending is Dictionary):
		return []
	if int(pending.get("turn", -1)) != state.turn_number:
		player.flags.erase("next_played_legion_keyword")
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var definition = state.get_definition(instance.definition_id)
	if definition == null or not definition.is_legion():
		return []
	var max_cost = int(pending.get("max_cost", -1))
	if max_cost >= 0 and int(definition.cost) > max_cost:
		return []
	var required_definition_id = str(pending.get("definition_id", ""))
	if not required_definition_id.is_empty() and str(definition.id) != required_definition_id:
		return []
	var keyword = str(pending.get("keyword", ""))
	if keyword.is_empty():
		return []
	instance.flags["temporary_keyword_%s_turn" % keyword] = state.turn_number
	player.flags.erase("next_played_legion_keyword")
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", player_id, {
		"card_id": card_id,
		"buff": "temporary_keyword",
		"keyword": keyword
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _apply_master_entry_effects(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var pending = player.flags.get("played_legion_keyword_until_turn_end", {})
	if not (pending is Dictionary):
		return []
	if int(pending.get("turn", -1)) != state.turn_number:
		player.flags.erase("played_legion_keyword_until_turn_end")
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var definition = state.get_definition(instance.definition_id)
	if definition == null or not definition.is_legion():
		return []
	var required_faction = str(pending.get("faction", ""))
	if not _definition_matches_required_faction_for_player(state, player_id, definition, required_faction):
		return []
	var keyword = str(pending.get("keyword", ""))
	if keyword.is_empty():
		return []
	instance.flags["temporary_keyword_%s_turn" % keyword] = state.turn_number
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", player_id, {
		"card_id": card_id,
		"buff": "temporary_keyword",
		"keyword": keyword
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _apply_immediate_self_entry_effects(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	if _card_entry_effects_disabled_this_turn(state, card_id):
		return []
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return []
	var events: Array = []
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "triggered":
			continue
		if not bool(effect.get("self_only", false)):
			continue
		if not bool(effect.get("resolve_immediately_on_entry_without_stack", false)):
			continue
		var event_name := str(effect.get("event", ""))
		if event_name != "CardPlayed" and event_name != "CardEnteredBattlefield":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary):
			continue
		var stack_item := {
			"controller": player_id,
			"source_instance_id": card_id,
			"resolution": resolution.duplicate(true),
			"effect_id": str(effect.get("id", "")),
			"effect_type": "triggered"
		}
		events.append_array(_resolve_stack_effect(state, stack_item, command_id))
	return events


func _disable_entry_effects_and_weaken_entered_legion(state: GameState, target_card_id: String, source_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return []
	instance.flags["entry_effects_disabled_turn"] = state.turn_number
	var events: Array = []
	var disable_event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": target_card_id,
		"buff": "entry_effects_disabled",
		"source_id": source_id
	})
	disable_event.created_by_command = command_id
	state.event_log.append(disable_event)
	events.append(disable_event)
	events.append_array(_modify_power_until_turn_end(state, target_card_id, -3000, command_id))
	return events


func _ruined_ritual_force_discard_and_blank_entry(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_event = _find_event_by_id(state, int(stack_item.get("created_from_event_id", 0)))
	if not _is_non_hand_legion_entry_event(state, source_event):
		return []
	var payload = source_event.payload
	var target_card_id := str(payload.get("card_id", "")) if payload is Dictionary else ""
	if target_card_id.is_empty():
		return []
	var source_id := str(stack_item.get("source_instance_id", ""))
	var target_instance = state.card_instances.get(target_card_id)
	if target_instance == null:
		return []
	return _request_option_choice(state, int(stack_item.get("controller", state.active_player)), [
		{"id": "discard", "label": "弃置对方1张手牌"},
		{"id": "blank_entry", "label": "使该军团本回合登场效果无效，且兵力-3000"}
	], "破败仪式：选择以下一项", "resolve_option_with_shared_cost", {
		"source_instance_id": source_id,
		"option_payloads": {
			"discard": {
				"resolution": {
					"action": "request_hand_discard_choice",
					"player_id": int(target_instance.controller),
					"discard_count": 1,
					"requires_confirm": true,
					"title": "破败仪式：选择1张手牌弃置",
					"hint_text": "请选择1张手牌，再点击确认弃置。",
					"top_hint_text": "破败仪式：请选择1张手牌并确认弃置。"
				}
			},
			"blank_entry": {
				"resolution": {
					"action": "disable_entry_effects_and_weaken_entered_legion",
					"target_card_id": target_card_id,
					"event_options": _effect_event_source_options(source_id)
				}
			}
		}
	}, command_id)

func _move_target_options(move_targets: Array) -> Array:
	var options: Array = []
	for raw_target in move_targets:
		if not (raw_target is Dictionary):
			continue
		var row = str(raw_target.get("row", ""))
		var col = int(raw_target.get("col", -1))
		if row.is_empty() or col < 0:
			continue
		options.append({
			"id": "%s:%d" % [row, col],
			"label": "%s:%d" % [row, col],
			"row": row,
			"col": col
		})
	return options


func _move_option_list_has_slot(move_options: Array, row: String, col: int) -> bool:
	for raw_option in move_options:
		if not (raw_option is Dictionary):
			continue
		if str(raw_option.get("row", "")) != row:
			continue
		if int(raw_option.get("col", -1)) != col:
			continue
		return true
	return false

func _request_tsukuyomi_follow_move_choice(state: GameState, player_id: int, moved_card_id: String, command_id: String) -> Array:
	if _is_effect_used_this_turn(state, player_id, _master_source_id(player_id), "tsukuyomi_follow_move"):
		return []
	if MoraleActions.count_active_morale(state, player_id) < 1:
		return []
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids(state):
		if card_id == moved_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		if not _instance_counts_as_legion(state, instance):
			continue
		if _one_step_move_targets_for_effect(state, card_id).is_empty():
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return []
	return _request_option_choice(state, player_id, [
		{"id": "yes", "label": "发动"},
		{"id": "no", "label": "不发动"}
	], "是否发动月读效果？", "tsukuyomi_move_trigger", {
		"moved_card_id": moved_card_id,
		"candidate_card_ids": candidates.duplicate()
	}, command_id)


func _request_takamagahara_morale_follow_move_choice(state: GameState, player_id: int, command_id: String) -> Array:
	var candidate_card_ids = _active_legion_ids_with_one_step_move(state, player_id)
	if candidate_card_ids.is_empty():
		return []
	return _request_option_choice(state, player_id, [
		{"id": "yes", "label": "位移"},
		{"id": "no", "label": "不位移"}
	], "选择是否让1张活跃军团位移1格", "takamagahara_morale_follow_move", {
		"candidate_card_ids": candidate_card_ids.duplicate()
	}, command_id)


func _active_legion_ids_with_one_step_move(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	if player_id < 0 or player_id >= state.players.size():
		return result
	var player = state.get_player(player_id)
	for slots in [player.battle_front, player.battle_back]:
		for slot in slots:
			var card_id = str(slot.occupant)
			if card_id.is_empty():
				continue
			var instance = state.card_instances.get(card_id)
			if instance == null or str(instance.orientation) != "active":
				continue
			if _one_step_move_targets_for_effect(state, card_id).is_empty():
				continue
			result.append(card_id)
	return result


func _one_step_move_targets_for_effect(state: GameState, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var instance = state.card_instances.get(card_id)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return result
	if str(instance.orientation) != "active":
		return result
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if (row != "front" and row != "back") or col < 0:
		return result
	var player = state.get_player(int(instance.controller))
	_append_move_target_if_legal(state, player, row, col, "back" if row == "front" else "front", col, result)
	_append_move_target_if_legal(state, player, row, col, row, col - 1, result)
	_append_move_target_if_legal(state, player, row, col, row, col + 1, result)
	return result


func _one_step_move_slot_options(state: GameState, card_id: String) -> Array:
	return _move_target_options(_one_step_move_targets_for_effect(state, card_id))

func _apply_master_move_effects(state: GameState, move_event: GameEvent, command_id: String) -> Array:
	if not (move_event is GameEvent):
		return []
	var controller = int(move_event.player_id)
	if controller != state.active_player or controller < 0 or controller >= state.players.size():
		return []
	var player = state.get_player(controller)
	if player.master_definition_id != "takamagahara_s02_04m1":
		return []
	var payload = move_event.payload
	if not (payload is Dictionary):
		return []
	var moved_card_id = str(payload.get("card_id", ""))
	if moved_card_id.is_empty():
		return []
	var instance = state.card_instances.get(moved_card_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	var from_row = str(payload.get("from_row", ""))
	var to_row = str(payload.get("to_row", ""))
	var events: Array = []
	if definition != null and _instance_counts_as_legion(state, instance) and _definition_matches_required_faction_for_instance(state, instance, definition, "takamagahara"):
		if from_row == "back" and to_row == "front":
			events.append_array(_grant_front_attack_power_bonus(state, {
				"controller": controller,
				"source_instance_id": _master_source_id(controller),
				"targets": {"target_card_id": moved_card_id},
				"resolution": {"amount": 1000}
			}, command_id))
		elif from_row == "front" and to_row == "back":
			events.append_array(_ready_spent_morale(state, {
				"controller": controller,
				"source_instance_id": _master_source_id(controller),
				"resolution": {"count": 1}
			}, command_id))
	events.append_array(_request_tsukuyomi_follow_move_choice(state, controller, moved_card_id, command_id))
	return events

func _consume_next_played_legion_cost_modifier(state: GameState, player_id: int, card_id: String) -> void:
	var player = state.get_player(player_id)
	var pending = player.flags.get("next_played_legion_cost_modifier", {})
	if not (pending is Dictionary):
		return
	if int(pending.get("turn", -1)) != state.turn_number:
		player.flags.erase("next_played_legion_cost_modifier")
		return
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return
	var definition = state.get_definition(instance.definition_id)
	if definition == null or not definition.is_legion():
		return
	var max_cost = int(pending.get("max_cost", -1))
	if max_cost >= 0 and int(definition.cost) > max_cost:
		return
	var required_definition_id = str(pending.get("definition_id", ""))
	if not required_definition_id.is_empty() and str(definition.id) != required_definition_id:
		return
	player.flags.erase("next_played_legion_cost_modifier")

func _consume_suncity_next_calamity_discount(state: GameState, player_id: int, card_id: String) -> void:
	var player = state.get_player(player_id)
	var pending = player.flags.get("suncity_next_calamity_discount", {})
	if not (pending is Dictionary):
		return
	if int(pending.get("turn", -1)) != state.turn_number:
		player.flags.erase("suncity_next_calamity_discount")
		return
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return
	var definition = state.get_definition(instance.definition_id)
	if definition == null or not definition.is_legion() or int(definition.calamity_level) <= 0:
		return
	player.flags.erase("suncity_next_calamity_discount")

func _master_draw_then_discard(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var draw_count: int = int(resolution.get("draw_count", 1))
	draw_count = min(draw_count, state.get_player(controller).deck.cards.size())
	var events = DrawActions.draw_cards(state, controller, draw_count, command_id)
	var discard_count: int = min(int(resolution.get("discard_count", 1)), state.get_player(controller).hand.cards.size())
	if discard_count <= 0:
		return events
	var candidates: Array[String] = []
	for card_id in state.get_player(controller).hand.cards:
		candidates.append(str(card_id))
	events.append_array(_request_candidate_cards_choice(state, controller, candidates, discard_count, "选择手牌弃置", "discard_from_hand", {
		"requires_confirm": true,
		"hint_text": "请先选择 %d 张手牌，再点击确认弃置。未确认前不会继续结算。" % discard_count,
		"top_hint_text": "请从高亮手牌中选择 %d 张并确认弃置。" % discard_count
	}, command_id))
	return events


func _choose_discard_from_hand_then_follow_up(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var discard_count: int = min(max(1, int(resolution.get("discard_count", 1))), state.get_player(controller).hand.cards.size())
	if discard_count <= 0:
		return []
	var candidates: Array[String] = []
	for card_id in state.get_player(controller).hand.cards:
		candidates.append(str(card_id))
	return _request_candidate_cards_choice(state, controller, candidates, discard_count, str(resolution.get("title", "选择手牌弃置")), "discard_from_hand", {
		"requires_confirm": true,
		"hint_text": str(resolution.get("hint_text", "请先从高亮手牌中选择要弃置的卡牌，再点击确认。")),
		"top_hint_text": str(resolution.get("top_hint_text", "请从高亮手牌中选择要弃置的卡牌。")),
		"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true) if resolution.get("follow_up_action", {}) is Dictionary else {},
		"initiator_player": controller,
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id)

func _block_legion_source_heal_for_controller_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	state.get_player(controller).flags["legion_source_heal_block_until_turn_end"] = true
	var source_id = str(stack_item.get("source_instance_id", ""))
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"card_id": source_id,
		"buff": "legion_source_heal_block_until_turn_end"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _grant_front_attack_power_bonus(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return [_create_unimplemented_effect_event(state, stack_item, "grant_front_attack_power_bonus", command_id)]
	var target_card_id = str(targets.get("target_card_id", ""))
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return [_create_unimplemented_effect_event(state, stack_item, "grant_front_attack_power_bonus", command_id)]
	var resolution = stack_item.get("resolution", {})
	instance.flags["front_attack_power_bonus_turn"] = state.turn_number
	instance.flags["front_attack_power_bonus_amount"] = int(resolution.get("amount", 0))
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": target_card_id,
		"buff": "front_attack_power_bonus",
		"amount": int(instance.flags.get("front_attack_power_bonus_amount", 0))
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _ready_spent_morale(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var count = 1
	if resolution is Dictionary:
		count = int(resolution.get("count", 1))
	if _controller_has_master_morale_ready_lock(state, controller) and _is_master_source_id(str(stack_item.get("source_instance_id", ""))):
		return []
	return MoraleActions.ready_spent_morale(state, controller, count, command_id)

func _grant_played_legion_keyword_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var keyword = str(resolution.get("keyword", ""))
	if keyword.is_empty():
		return []
	var player = state.get_player(controller)
	player.flags["played_legion_keyword_until_turn_end"] = {
		"turn": state.turn_number,
		"keyword": keyword,
		"faction": str(resolution.get("faction", "")),
		"type": str(resolution.get("type", "legion"))
	}
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"card_id": str(stack_item.get("source_instance_id", "")),
		"buff": "played_legion_keyword_until_turn_end",
		"keyword": keyword
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _block_master_healing_for_game(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	player.flags["master_cannot_heal_for_game"] = true
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"card_id": str(stack_item.get("source_instance_id", "")),
		"buff": "master_cannot_heal_for_game"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _shuffle_deck(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	_shuffle_cards_in_place(state, state.get_player(controller).deck.cards)
	var event = GameEvent.create(state.next_event_id(), "DeckShuffled", controller, {
		"player_id": controller,
		"count": state.get_player(controller).deck.cards.size()
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _ready_source_card(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if not _source_card_can_change_orientation(instance):
		return []
	if int(instance.flags.get("cannot_ready_by_effect_turn", -1)) == state.turn_number:
		return []
	instance.orientation = "active"
	instance.has_attacked_this_turn = false
	var event = GameEvent.create(state.next_event_id(), "CardReadied", int(instance.controller), {
		"card_id": source_id,
		"zone": str(instance.zone),
		"from_orientation": "rested",
		"source_kind": "effect"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _grant_controller_master_cannot_be_attacked_until_next_own_turn_start(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	player.flags["master_cannot_be_attacked_until_next_own_turn_start"] = true
	var event = GameEvent.create(state.next_event_id(), "MasterProtected", controller, {
		"player_id": controller,
		"until": "next_own_turn_start"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _rest_source_card(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if not _source_card_can_change_orientation(instance):
		return []
	if str(instance.orientation) == "rested":
		return []
	instance.orientation = "rested"
	var event = GameEvent.create(state.next_event_id(), "CardRested", int(instance.controller), {
		"card_id": source_id,
		"zone": str(instance.zone)
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _ready_target_unit(state: GameState, target_card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(target_card_id)
	if instance == null or not instance.zone.begins_with("battle_"):
		return []
	if str(instance.orientation) == "active":
		return []
	if int(instance.flags.get("cannot_ready_by_effect_turn", -1)) == state.turn_number:
		return []
	instance.orientation = "active"
	instance.has_attacked_this_turn = false
	var event = GameEvent.create(state.next_event_id(), "CardReadied", int(instance.controller), {
		"card_id": target_card_id,
		"zone": str(instance.zone),
		"from_orientation": "rested",
		"source_kind": "effect"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _rest_target_unit(state: GameState, target_card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(target_card_id)
	if instance == null or not instance.zone.begins_with("battle_"):
		return []
	if str(instance.orientation) == "rested":
		return []
	instance.orientation = "rested"
	var event = GameEvent.create(state.next_event_id(), "CardRested", int(instance.controller), {
		"card_id": target_card_id,
		"reason": "effect"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _revive_source_from_grave(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	if source_id.is_empty():
		return []
	if not state.get_player(controller).grave.cards.has(source_id):
		return []
	return _revive_grave_card_to_first_slot(state, controller, source_id, command_id)

func _return_source_to_deck_top(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	if source_id.is_empty():
		return []
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return []
	var from_zone = str(instance.zone)
	if not from_zone.begins_with("battle_"):
		return []
	_remove_card_from_current_zone(state, source_id)
	state.get_player(controller).deck.cards.push_front(source_id)
	instance.zone = "deck"
	instance.position = {}
	instance.orientation = "active"
	instance.flags.erase("manifested_power")
	instance.flags.erase("manifested_traits")
	var event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", controller, {
		"card_id": source_id,
		"from": from_zone,
		"to": "deck_top"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _sacrifice_source_and_deploy_from_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if source_id.is_empty() or instance == null or not instance.zone.begins_with("battle_"):
		return []
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if row.is_empty() or col < 0:
		return []
	var resolution = stack_item.get("resolution", {})
	var events = ZoneActions.move_battlefield_to_grave(state, controller, row, col, command_id, {
		"emit_died": false
	})
	var self_master_damage = int(resolution.get("self_master_damage", 0))
	if self_master_damage > 0:
		events.append_array(_deal_master_damage(state, controller, self_master_damage, command_id, {
			"source_card_id": source_id,
			"source_kind": "effect"
		}))
	if state.winner != -1:
		return events
	var candidates = _matching_hand_card_ids(state, controller, resolution)
	var slot_options = _battlefield_slot_options(state, controller)
	if candidates.is_empty() or slot_options.is_empty():
		return events
	return events + _request_candidate_cards_choice(state, controller, candidates, 1, "选择手牌军团活跃登场", "deploy_from_hand_to_battlefield", {
		"slot_options": slot_options.duplicate(true)
	}, command_id)

func _sacrifice_source_then_follow_up(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if source_id.is_empty() or instance == null or not instance.zone.begins_with("battle_"):
		return []
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if row.is_empty() or col < 0:
		return []
	var resolution = stack_item.get("resolution", {})
	var events = ZoneActions.move_battlefield_to_grave(state, controller, row, col, command_id, {
		"emit_died": false
	})
	if state.winner != -1:
		return events
	events.append_array(_resolve_stack_follow_up_action(state, stack_item, resolution.get("follow_up_action", {}), command_id))
	return events

func _deploy_matching_legion_from_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var candidates = _matching_hand_card_ids(state, controller, resolution)
	var slot_options = _battlefield_slot_options(state, controller)
	if candidates.is_empty() or slot_options.is_empty():
		return []
	var count = min(max(1, int(resolution.get("count", 1))), candidates.size())
	return _request_candidate_cards_choice(state, controller, candidates, count, "选择手牌军团登场", "deploy_from_hand_to_battlefield", {
		"slot_options": slot_options.duplicate(true),
		"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true),
		"deployment_orientation": str(resolution.get("deployment_orientation", "active")),
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", false))
	}, command_id)

func _deploy_matching_legion_from_hand_deck_or_grave(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var candidates: Array[String] = []
	for card_id in _matching_hand_card_ids(state, controller, resolution):
		candidates.append(str(card_id))
	for card_id in _matching_deck_card_ids(state, controller, resolution):
		var candidate_id = str(card_id)
		if not candidates.has(candidate_id):
			candidates.append(candidate_id)
	for card_id in _matching_grave_card_ids(state, controller, resolution):
		var candidate_id = str(card_id)
		if not candidates.has(candidate_id):
			candidates.append(candidate_id)
	var slot_options = _battlefield_slot_options(state, controller)
	if candidates.is_empty() or slot_options.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择手牌/牌库/墓地军团活跃登场", "deploy_from_hand_deck_or_grave", {
		"slot_options": slot_options.duplicate(true),
		"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true)
	}, command_id)

func _attach_named_token_under_source(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null or not source_instance.zone.begins_with("battle_"):
		return []
	if not str(source_instance.flags.get("attached_underlay_token_id", "")).is_empty():
		return []
	var row = str(source_instance.position.get("row", ""))
	var col = int(source_instance.position.get("col", -1))
	if row.is_empty() or col < 0:
		return []
	var slot = state.get_player(controller).get_slot(row, col)
	if slot == null or str(slot.occupant) != source_id or not str(slot.cover).is_empty():
		return []
	var resolution = stack_item.get("resolution", {})
	var token_definition_id = str(resolution.get("token_definition_id", ""))
	if token_definition_id.is_empty() or state.get_definition(token_definition_id) == null:
		return []
	var token_id = state.create_instance(token_definition_id, controller, controller)
	var token_instance = state.card_instances.get(token_id)
	if token_instance == null:
		return []
	slot.cover = token_id
	token_instance.zone = "battle_%s" % row
	token_instance.position = {"row": row, "col": col}
	token_instance.controller = controller
	token_instance.face = "face_up"
	source_instance.flags["attached_underlay_token_id"] = token_id
	source_instance.flags["persistent_power_bonus"] = int(source_instance.flags.get("persistent_power_bonus", 0)) + int(resolution.get("power_bonus", 0))
	if bool(resolution.get("enable_substitute_on_lethal", false)):
		source_instance.flags["bijie_excalibur_substitute_enabled"] = true
	var persistent_keywords: Array = []
	var existing_keywords = source_instance.flags.get("persistent_keywords", [])
	if existing_keywords is Array:
		persistent_keywords = existing_keywords.duplicate()
	var keyword = str(resolution.get("keyword", ""))
	if not keyword.is_empty() and not persistent_keywords.has(keyword):
		persistent_keywords.append(keyword)
	source_instance.flags["persistent_keywords"] = persistent_keywords
	var event = GameEvent.create(state.next_event_id(), "CardOverlayAttached", controller, {
		"base_card_id": source_id,
		"cover_card_id": token_id,
		"kind": "attached_underlay_token"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _choose_attach_matching_cards_under_source(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null or not str(source_instance.zone).begins_with("battle_"):
		return []
	var resolution = stack_item.get("resolution", {})
	var candidates = _collect_matching_card_ids_from_controller_regions(state, controller, resolution)
	if candidates.is_empty():
		return []
	var count = min(max(1, int(resolution.get("count", 1))), candidates.size())
	return _request_candidate_cards_choice(state, controller, candidates, count, str(resolution.get("title", "选择要叠放到下方的卡牌")), "attach_matching_cards_under_source", {
		"source_instance_id": source_id,
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", false))
	}, command_id)

func _discard_attached_cards_for_power_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null or not str(source_instance.zone).begins_with("battle_"):
		return []
	if source_instance.attached_cards.is_empty():
		return []
	var resolution = stack_item.get("resolution", {})
	var count = min(max(1, int(resolution.get("count", source_instance.attached_cards.size()))), source_instance.attached_cards.size())
	return _request_candidate_cards_choice(state, int(source_instance.controller), source_instance.attached_cards.duplicate(), count, str(resolution.get("title", "选择要弃置的下方卡")), "discard_attached_cards_for_power_until_turn_end", {
		"source_instance_id": source_id,
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", true)),
		"amount_per_card": int(resolution.get("amount_per_card", 1000))
	}, command_id)

func _choose_and_move_units(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var grants_free_move := bool(resolution.get("grant_free_move_until_turn_end", false))
	var candidates: Array[String] = []
	var target_scope := str(resolution.get("target_scope", "allied_battlefield"))
	var candidate_pool: Array[String] = []
	match target_scope:
		"enemy_battlefield":
			candidate_pool = _get_battlefield_card_ids_for_player(state, 1 - controller)
		"all_battlefield":
			candidate_pool = _get_battlefield_card_ids(state)
		_:
			candidate_pool = _get_battlefield_card_ids_for_player(state, controller)
	for target_card_id in candidate_pool:
		if _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			if not grants_free_move and _effect_move_slot_options(state, str(target_card_id)).is_empty():
				continue
			candidates.append(str(target_card_id))
	if candidates.is_empty():
		return []
	var max_count = min(max(1, int(resolution.get("count", 1))), candidates.size())
	return _request_candidate_cards_choice(state, controller, candidates, max_count, "选择要位移的军团", "choose_battlefield_cards_to_move", {
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", false)),
		"min_select_count": int(resolution.get("min_count", 0)),
		"grant_free_move_until_turn_end": grants_free_move,
		"free_move_effect_id": str(resolution.get("effect_id", "granted_free_move")),
		"free_move_once_per_turn_key": str(resolution.get("once_per_turn_key", resolution.get("effect_id", "granted_free_move"))),
		"free_move_player_once_per_turn": bool(resolution.get("player_once_per_turn", false)),
		"free_move_any_slot": bool(resolution.get("any_slot", false)),
		"free_move_swap_with_allied_occupied_slot": bool(resolution.get("swap_with_allied_occupied_slot", false))
	}, command_id)

func _request_forged_order_enemy_move_choice(state: GameState, controller: int, remaining_moves: int, moved_card_ids: Array[String], source_instance_id: String, command_id: String) -> Array:
	if remaining_moves <= 0:
		return []
	var candidates = _forged_order_movable_enemy_legion_ids(state, controller, moved_card_ids)
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "伪造密令：选择要前后位移的对方军团", "forged_order_choose_enemy_move_card", {
		"remaining_moves": remaining_moves,
		"moved_card_ids": moved_card_ids.duplicate(),
		"source_instance_id": source_instance_id,
		"highlight_card_ids": candidates.duplicate(),
		"hint_text": "请直接拖拽高亮的对方军团进行前后位移；本次最多还能移动 %d 张，进行其他操作也会直接结束。" % remaining_moves,
		"top_hint_text": "伪造密令：拖拽高亮的对方军团前后位移；若改做其他操作，本次位移会直接结束。"
	}, command_id)

func _forged_order_prepare_enemy_moves(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var max_moves = max(1, int(resolution.get("count", 2)))
	return _request_forged_order_enemy_move_choice(state, controller, max_moves, [], str(stack_item.get("source_instance_id", "")), command_id)

func _frontline_scout_view_enemy_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var enemy = state.get_player(1 - controller)
	var viewed_cards: Array[String] = []
	for raw_card_id in enemy.hand.cards:
		var card_id := str(raw_card_id)
		if not card_id.is_empty():
			viewed_cards.append(card_id)
	var resolution = stack_item.get("resolution", {})
	var title := str(resolution.get("title", "前线侦查"))
	var events: Array = []
	var private_event = GameEvent.create(state.next_event_id(), "CardsViewedPrivately", controller, {
		"viewing_player_id": controller,
		"title": title,
		"card_ids": viewed_cards.duplicate(),
		"suppress_auto_popup": true
	})
	private_event.created_by_command = command_id
	state.event_log.append(private_event)
	events.append(private_event)
	events.append_array(_request_option_choice(state, controller, [
		{"id": "confirm", "label": "确认"}
	], "%s：查看对方手牌" % title, "frontline_scout_confirm_enemy_hand", {
		"display_card_ids": viewed_cards.duplicate(),
		"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true) if resolution.get("follow_up_action", {}) is Dictionary else {},
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"hint_text": "点击确认后，再决定是否消耗1士气让对方将1张手牌随机洗回牌库。"
	}, command_id))
	return events

func _reveal_top_card_play_or_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	if player.deck.cards.is_empty():
		return []
	var top_card_id = str(player.deck.cards[0])
	if top_card_id.is_empty():
		return []
	var instance = state.card_instances.get(top_card_id)
	if instance == null:
		return []
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return []
	var event = GameEvent.create(state.next_event_id(), "CardRevealed", controller, {
		"card_id": top_card_id,
		"from": "deck_top"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	var resolution = stack_item.get("resolution", {})
	events.append_array(_broadcast_revealed_cards_popup(state, controller, [top_card_id], str(resolution.get("title", "展示牌库顶部的卡牌")), command_id))
	var eligible = _card_matches_reveal_top_play_filters(state, top_card_id, resolution)
	if not eligible:
		events.append_array(_move_top_deck_card_to_hand(state, controller, command_id))
		return events
	events.append_array(_request_option_choice(state, controller, [
		{"id": "play", "label": "无消耗打出"},
		{"id": "hand", "label": "加入手牌"}
	], "选择展示卡牌的处理方式", "revealed_top_card_play_or_hand", {
		"card_id": top_card_id
	}, command_id))
	return events

func _set_counter_tactics_from_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var max_count = int(resolution.get("count", 1))
	if max_count <= 0:
		return []
	var candidates = _matching_hand_counter_tactic_ids(state, controller)
	var slot_options = _back_battlefield_slot_options(state, controller)
	if candidates.is_empty() or slot_options.is_empty():
		return []
	var selectable_count = min(max_count, min(candidates.size(), slot_options.size()))
	return _request_candidate_cards_choice(state, controller, candidates, selectable_count, "选择要置入后排的反击战术", "set_counter_tactics_from_hand", {
		"allow_up_to_count": true,
		"min_select_count": 1,
		"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true) if resolution.get("follow_up_action", {}) is Dictionary else {},
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}, command_id)

func _reveal_enemy_hand_to_all(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var enemy = state.get_player(1 - controller)
	var revealed: Array[String] = []
	var events: Array = []
	for raw_card_id in enemy.hand.cards:
		var card_id := str(raw_card_id)
		if card_id.is_empty():
			continue
		revealed.append(card_id)
		events.append_array(_tianting_reveal_card(state, 1 - controller, card_id, "hand", command_id))
	if revealed.is_empty():
		return []
	events.append_array(_broadcast_revealed_cards_popup(state, 1 - controller, revealed, str(stack_item.get("resolution", {}).get("title", "公开对方手牌")), command_id))
	events.append_array(_resolve_stack_follow_up_action(state, stack_item, stack_item.get("resolution", {}).get("follow_up_action", {}), command_id))
	return events

func _return_enemy_hand_to_deck_and_shuffle(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var enemy = state.get_player(1 - controller)
	if enemy.hand.cards.is_empty():
		return []
	var resolution = stack_item.get("resolution", {})
	var return_count = min(max(1, int(resolution.get("count", 1))), enemy.hand.cards.size())
	return _request_candidate_cards_choice(state, 1 - controller, enemy.hand.cards.duplicate(), return_count, str(resolution.get("title", "选择返回牌库的手牌")), "return_hand_to_deck_bottom", {
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", false)),
		"min_select_count": int(resolution.get("min_count", return_count)),
		"shuffle_after": true,
		"shuffle_player_id": 1 - controller
	}, command_id)

func _return_enemy_hand_to_deck_top(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var enemy = state.get_player(1 - controller)
	if enemy.hand.cards.is_empty():
		return []
	var resolution = stack_item.get("resolution", {})
	var return_count = min(max(1, int(resolution.get("count", 1))), enemy.hand.cards.size())
	return _request_candidate_cards_choice(state, controller, enemy.hand.cards.duplicate(), return_count, str(resolution.get("title", "选择返回牌库顶部的手牌")), "return_enemy_hand_to_deck_top", {
		"allow_up_to_count": bool(resolution.get("allow_up_to_count", false)),
		"min_select_count": int(resolution.get("min_count", return_count)),
		"target_hand_player_id": 1 - controller,
		"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true) if resolution.get("follow_up_action", {}) is Dictionary else {},
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"initiator_player": controller,
		"hint_text": "请选择对方1张高亮手牌；非测试模式下仍显示牌背。点击后会将该牌返回其所有者牌库顶部，然后我方抽1张牌。",
		"top_hint_text": "粮草掠夺：请选择对方1张手牌返回所有者牌库顶部，然后我方抽1张牌。",
		"allow_hidden_hand_highlight": true,
		"hide_candidate_panel_cards": true
	}, command_id)

func _move_source_tactic_to_spent_morale(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return []
	if str(instance.zone) != "stack_pending":
		return []
	var player = state.get_player(int(instance.controller))
	player.spent_cost_area.add_card_to_top(source_id)
	instance.zone = "spent_cost_area"
	instance.position = {}
	instance.orientation = "rested"
	instance.flags["grave_when_leaving_morale"] = true
	var event = GameEvent.create(state.next_event_id(), "MoraleAdded", int(instance.controller), {
		"card_id": source_id,
		"orientation": "rested",
		"from": "stack_pending",
		"as_card": true
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _return_source_to_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return []
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if not str(instance.zone).begins_with("battle_") or row.is_empty() or col < 0:
		return []
	return ZoneActions.return_battlefield_to_hand(state, int(instance.controller), row, col, command_id)


func _prepare_free_master_morale_effect_activation(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	if not _has_available_free_master_morale_effect_target(state, controller):
		return []
	var player = state.get_player(controller)
	player.flags["free_master_morale_effect_activation_turn"] = state.turn_number
	player.flags["free_master_morale_effect_activation_count"] = int(player.flags.get("free_master_morale_effect_activation_count", 0)) + 1
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"buff": "free_master_morale_effect_activation",
		"count": int(player.flags.get("free_master_morale_effect_activation_count", 0))
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _attach_source_to_enemy_artifact_lock(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	var candidates = _enemy_artifact_candidate_ids(state, controller)
	if candidates.is_empty():
		return []
	if candidates.size() == 1:
		return _attach_source_to_enemy_artifact_lock_target(state, source_id, str(candidates[0]), command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要封锁的对方圣物", "attach_source_to_enemy_artifact_lock", {
		"source_instance_id": source_id
	}, command_id)


func _attach_source_to_enemy_artifact_lock_target(state: GameState, source_id: String, target_artifact_id: String, command_id: String) -> Array:
	var source_instance = state.card_instances.get(source_id)
	var target_instance = state.card_instances.get(target_artifact_id)
	if source_instance == null or target_instance == null:
		return []
	if str(source_instance.zone) != "stack_pending" or str(target_instance.zone) != "artifact_zone":
		return []
	var host_player_id = int(target_instance.controller)
	if host_player_id < 0 or host_player_id >= state.players.size():
		return []
	state.get_player(host_player_id).artifact_zone.add_card(source_id)
	source_instance.zone = "artifact_zone"
	source_instance.position = {}
	source_instance.controller = host_player_id
	source_instance.face = "face_up"
	source_instance.orientation = "active"
	source_instance.flags["artifact_lock_target_id"] = target_artifact_id
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", host_player_id, {
		"card_id": target_artifact_id,
		"buff": "artifact_locked",
		"source_id": source_id
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _discard_artifact_zone_card_to_owner_grave(state: GameState, card_id: String, command_id: String) -> Array:
	for player in state.players:
		if player.artifact_zone.remove_card(card_id):
			var events: Array = ZoneActions.move_card_to_grave(state, card_id, "artifact_zone", command_id)
			events.append_array(_artifact_zone_leave_cleanup_events(state, card_id, command_id))
			return events
	return []


func _discard_source_to_owner_grave(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return []
	if str(instance.zone) == "artifact_zone":
		return _discard_artifact_zone_card_to_owner_grave(state, source_id, command_id)
	if str(instance.zone) == "stack_pending":
		return ZoneActions.move_card_to_grave(state, source_id, "stack_pending", command_id)
	return []


func _set_pending_attack_extra_discard_requirement(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	if state.pending_attack.is_empty():
		return []
	var attack = state.pending_attack.duplicate(true)
	if not _pending_attack_has_defense_selection(attack):
		return []
	var defense_player_id := -1
	if not str(attack.get("blocker_id", "")).is_empty():
		var blocker = state.card_instances.get(str(attack.get("blocker_id", "")))
		if blocker == null or not str(blocker.zone).begins_with("battle_"):
			return []
		defense_player_id = int(blocker.controller)
	elif not str(attack.get("supporter_id", "")).is_empty():
		var supporter = state.card_instances.get(str(attack.get("supporter_id", "")))
		if supporter == null or not str(supporter.zone).begins_with("battle_"):
			return []
		defense_player_id = int(supporter.controller)
	elif attack.get("master_guard_card_ids", []) is Array and not attack.get("master_guard_card_ids", []).is_empty():
		defense_player_id = int(attack.get("target_player", -1))
	if defense_player_id < 0:
		return []
	attack["extra_defense_discard_required"] = true
	attack["extra_defense_discard_source_id"] = str(stack_item.get("source_instance_id", ""))
	state.pending_attack = attack
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(stack_item.get("controller", state.active_player)), {
		"buff": "pending_attack_extra_defense_discard",
		"source_id": str(stack_item.get("source_instance_id", "")),
		"attacker_id": str(attack.get("attacker_id", ""))
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	var hand_candidates: Array = state.get_player(defense_player_id).hand.cards.duplicate()
	events.append_array(_request_candidate_cards_choice(state, defense_player_id, hand_candidates, 1, "地主的胁迫：额外弃置1张手牌，否则本次抵挡/支援无效", "landlord_coercion_extra_discard", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"defense_player_id": defense_player_id,
		"requires_confirm": true,
		"allow_up_to_count": true,
		"min_select_count": 0,
		"hint_text": "请选择1张手牌并点击确认；若不想额外弃置，点击取消，则本次抵挡/支援无效。",
		"top_hint_text": "地主的胁迫：额外弃置1张手牌，否则本次抵挡/支援无效。"
	}, command_id))
	return events


func _undo_ready_event_and_discard_enemy_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_event = _find_event_by_id(state, int(stack_item.get("created_from_event_id", 0)))
	if not _is_effect_ready_transition_event(source_event):
		return []
	var payload = source_event.payload
	var target_card_id = str(payload.get("card_id", ""))
	if target_card_id.is_empty():
		return []
	var target_instance = state.card_instances.get(target_card_id)
	if target_instance == null:
		return []
	var events: Array = []
	if str(source_event.type) == "MoraleReadied":
		var controller := int(target_instance.controller)
		var player = state.get_player(controller)
		if player.cost_area.remove_card(target_card_id):
			player.spent_cost_area.add_card(target_card_id)
			target_instance.zone = "spent_cost_area"
			target_instance.orientation = "rested"
			var morale_rest_event = GameEvent.create(state.next_event_id(), "MoraleRested", controller, {
				"card_id": target_card_id,
				"from": "cost_area",
				"to": "spent_cost_area",
				"reason": "counter_ready_effect"
			})
			morale_rest_event.created_by_command = command_id
			state.event_log.append(morale_rest_event)
			events.append(morale_rest_event)
	elif str(target_instance.orientation) == "active":
		target_instance.orientation = "rested"
		var rest_event = GameEvent.create(state.next_event_id(), "CardRested", int(target_instance.controller), {
			"card_id": target_card_id,
			"reason": "counter_ready_effect"
		})
		rest_event.created_by_command = command_id
		state.event_log.append(rest_event)
		events.append(rest_event)
	events.append_array(_request_hand_discard_choice_from_resolution(state, {
		"controller": int(stack_item.get("controller", state.active_player)),
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"created_from_event_id": int(stack_item.get("created_from_event_id", 0)),
		"resolution": {
			"action": "request_hand_discard_choice",
			"player_id": int(target_instance.controller),
			"discard_count": 1,
			"requires_confirm": true,
			"title": "毒药发作：选择1张手牌弃置",
			"hint_text": "毒药发作：请选择1张手牌，再点击确认弃置。",
			"top_hint_text": "毒药发作：请选择1张手牌并确认弃置。"
		}
	}, command_id))
	return events

func _deploy_sigurd_from_hand_or_grave(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var definition_id = str(resolution.get("definition_id", "asgard_s01_0310"))
	var slot_options = _battlefield_slot_options(state, controller)
	if slot_options.is_empty():
		return []
	var player = state.get_player(controller)
	var hand_candidates = _matching_definition_card_ids(state, player.hand.cards, definition_id)
	var grave_candidates = _matching_definition_card_ids(state, player.grave.cards, definition_id)
	if hand_candidates.is_empty() and grave_candidates.is_empty():
		return []
	if grave_candidates.is_empty():
		return _request_brynhildr_sigurd_from_hand_choice(state, controller, hand_candidates, slot_options, command_id)
	if hand_candidates.is_empty():
		return _request_brynhildr_sigurd_from_grave_choice(state, controller, grave_candidates, player.grave.cards, command_id)
	return _request_option_choice(state, controller, [
		{"id": "hand", "label": "手牌的齐格鲁德活跃登场"},
		{"id": "grave", "label": "墓地的齐格鲁德活跃登场"}
	], "选择要活跃登场的齐格鲁德来源", "brynhildr_choose_sigurd_source", {
		"definition_id": definition_id,
		"slot_options": slot_options.duplicate(true),
		"hand_candidate_ids": hand_candidates.duplicate(),
		"grave_candidate_ids": grave_candidates.duplicate(),
		"grave_display_ids": player.grave.cards.duplicate(),
		"hint_text": "请选择将手牌或墓地中的1张齐格鲁德活跃登场。"
	}, command_id)


func _matching_definition_card_ids(state: GameState, zone_cards: Array, definition_id: String) -> Array[String]:
	var matches: Array[String] = []
	for raw_card_id in zone_cards:
		var card_id = str(raw_card_id)
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			matches.append(card_id)
	return matches


func _request_brynhildr_sigurd_from_hand_choice(state: GameState, controller: int, hand_candidates: Array, slot_options: Array, command_id: String) -> Array:
	if hand_candidates.is_empty() or slot_options.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, hand_candidates, 1, "选择手牌中的齐格鲁德活跃登场", "deploy_from_hand_to_battlefield", {
		"slot_options": slot_options.duplicate(true),
		"deployment_orientation": "active",
		"highlight_card_ids": hand_candidates.duplicate(),
		"hint_text": "请把高亮手牌中的齐格鲁德直接拖到我方高亮空位上活跃登场。",
		"top_hint_text": "布伦希尔德效果：请把高亮的齐格鲁德从手牌拖到我方高亮空位上活跃登场。"
	}, command_id)


func _request_brynhildr_sigurd_from_grave_choice(state: GameState, controller: int, grave_candidates: Array, grave_display_ids: Array, command_id: String) -> Array:
	if grave_candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, grave_candidates, 1, "选择墓地中的齐格鲁德活跃登场", "revive_from_grave", {
		"rested": false,
		"requires_confirm": true,
		"display_card_ids": grave_display_ids.duplicate(),
		"highlight_card_ids": grave_candidates.duplicate(),
		"hint_text": "请选择墓地中高亮的齐格鲁德并点击确认，随后点击高亮空位让其活跃登场。",
		"top_hint_text": "布伦希尔德效果：请先从墓地选择齐格鲁德，再点击高亮位置让其活跃登场。"
	}, command_id)

func _return_from_grave_to_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var count = int(resolution.get("count", 1))
	var event_options = _effect_event_options_from_stack_item(state, stack_item, resolution)
	var candidates = _matching_grave_card_ids(state, controller, resolution)
	if candidates.is_empty():
		return []
	if bool(resolution.get("always_request_choice", false)) or candidates.size() > count:
		return _request_candidate_cards_choice(state, controller, candidates, count, "选择墓地卡牌加入手牌", "return_grave_to_hand", {
			"allow_up_to_count": bool(resolution.get("allow_up_to_count", false)),
			"source_kind": str(event_options.get("source_kind", "")),
			"source_card_id": str(event_options.get("source_card_id", "")),
			"source_player_id": int(event_options.get("source_player_id", controller))
		}, command_id)
	return _move_grave_cards_to_hand(state, controller, [str(candidates[0])], command_id, event_options)

func _return_matching_card_from_deck_or_grave_to_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var event_options = _effect_event_options_from_stack_item(state, stack_item, resolution)
	var candidates: Array[String] = []
	for card_id in _matching_deck_card_ids(state, controller, resolution):
		var candidate_id = str(card_id)
		if not candidates.has(candidate_id):
			candidates.append(candidate_id)
	for card_id in _matching_grave_card_ids(state, controller, resolution):
		var candidate_id = str(card_id)
		if not candidates.has(candidate_id):
			candidates.append(candidate_id)
	if candidates.is_empty():
		return []
	if candidates.size() > 1:
		return _request_candidate_cards_choice(state, controller, candidates, 1, str(resolution.get("title", "选择牌库或墓地中的卡牌加入手牌")), "return_from_deck_or_grave_to_hand", {
			"source_instance_id": str(stack_item.get("source_instance_id", "")),
			"source_kind": str(event_options.get("source_kind", "")),
			"source_card_id": str(event_options.get("source_card_id", "")),
			"source_player_id": int(event_options.get("source_player_id", controller)),
			"follow_up_action": resolution.get("follow_up_action", {}).duplicate(true)
		}, command_id)
	return _move_matching_card_from_deck_or_grave_to_hand(state, controller, str(candidates[0]), stack_item, command_id)

func _split_grave_two_cards_to_deck_bottom_and_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var candidates = _matching_grave_card_ids(state, controller, resolution)
	if candidates.size() < 2:
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 2, "选择2张墓地卡牌", "split_grave_pick_two", {
		"requires_confirm": true
	}, command_id)

func _trigger_selected_legion_died_effects(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var target_card_id = str(card_id)
		if target_card_id.is_empty():
			continue
		if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			continue
		candidates.append(target_card_id)
	for card_id in _matching_grave_card_ids(state, controller, resolution):
		var grave_card_id = str(card_id)
		if grave_card_id.is_empty() or candidates.has(grave_card_id):
			continue
		candidates.append(grave_card_id)
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, min(2, candidates.size()), "选择最多2张非同名的阿斯加德军团，触发其阵亡效果", "trigger_selected_legion_died_effects", {
		"allow_up_to_count": true,
		"requires_confirm": true
	}, command_id)

func _grant_source_can_attack_master_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if source_id.is_empty() or instance == null or not str(instance.zone).begins_with("battle_"):
		return []
	instance.flags["can_attack_master_until_turn_end_turn"] = state.turn_number
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": source_id,
		"buff": "can_attack_master_until_turn_end",
		"turn_number": state.turn_number
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _disable_enemy_hand_counter_tactic_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if targets is Dictionary:
		var target_card_id := str(targets.get("target_card_id", ""))
		if not target_card_id.is_empty():
			if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
				return []
			return _disable_counter_tactic_until_turn_end(state, target_card_id, command_id)
	var controller = int(stack_item.get("controller", state.active_player))
	var enemy_player_id = 1 - controller
	var candidates = _matching_set_counter_tactic_ids(state, enemy_player_id)
	if candidates.is_empty():
		return []
	return _disable_counter_tactic_until_turn_end(state, str(candidates[0]), command_id)

func _disable_matching_counter_tactics_until_next_own_turn_start(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var events: Array = []
	for card_id in _get_battlefield_card_ids(state):
		var target_card_id := str(card_id)
		if target_card_id.is_empty():
			continue
		if not _target_card_matches_stack_resolution_filters(state, stack_item, target_card_id):
			continue
		events.append_array(_disable_counter_tactic_until_next_own_turn_start(state, target_card_id, controller, command_id))
	return events

func _disable_counter_tactic_until_turn_end(state: GameState, card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.flags["counter_tactic_disabled_turn"] = state.turn_number
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": card_id,
		"buff": "counter_tactic_disabled",
		"turn_number": state.turn_number
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _disable_counter_tactic_until_next_own_turn_start(state: GameState, card_id: String, player_id: int, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.flags["counter_tactic_disabled_until_next_own_turn_start_player"] = player_id
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": card_id,
		"buff": "counter_tactic_disabled_until_next_own_turn_start",
		"player_id": player_id
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _deploy_hand_response_card_to_front_and_redirect_pending_attack(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	if state.pending_attack.is_empty():
		return []
	var attack = state.pending_attack.duplicate(true)
	if str(attack.get("target_kind", "")) != "master":
		return []
	if int(attack.get("target_player", -1)) != player_id:
		return []
	var deploy_events = _deploy_hand_card_to_slot_with_orientation(state, player_id, card_id, row, col, "rested", command_id)
	if deploy_events.is_empty():
		return []
	attack["target_kind"] = "card"
	attack["defender_id"] = card_id
	attack.erase("target_player")
	state.pending_attack = attack
	state.priority_player = 1 - player_id
	state.priority_pass_count = 0
	var redirect_event = GameEvent.create(state.next_event_id(), "AttackRedirected", player_id, {
		"attacker_id": str(attack.get("attacker_id", "")),
		"defender_id": card_id
	})
	redirect_event.created_by_command = command_id
	state.event_log.append(redirect_event)
	deploy_events.append(redirect_event)
	return deploy_events

func _suncity_siwa_hand_response(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	if state.pending_attack.is_empty():
		return []
	var attack = state.pending_attack.duplicate(true)
	if str(attack.get("target_kind", "")) != "master":
		return []
	if int(attack.get("target_player", -1)) != player_id:
		return []
	var deploy_events = _deploy_hand_card_to_slot_with_orientation(state, player_id, card_id, row, col, "active", command_id)
	if deploy_events.is_empty():
		return []
	attack["target_kind"] = "card"
	attack["defender_id"] = card_id
	attack.erase("target_player")
	state.pending_attack = attack
	state.priority_player = 1 - player_id
	state.priority_pass_count = 0
	var redirect_event = GameEvent.create(state.next_event_id(), "AttackRedirected", player_id, {
		"attacker_id": str(attack.get("attacker_id", "")),
		"defender_id": card_id
	})
	redirect_event.created_by_command = command_id
	state.event_log.append(redirect_event)
	deploy_events.append(redirect_event)
	var player = state.get_player(player_id)
	player.flags["suncity_skip_next_ready_morale_count"] = int(player.flags.get("suncity_skip_next_ready_morale_count", 0)) + 1
	var lock_event = GameEvent.create(state.next_event_id(), "StatusApplied", player_id, {
		"status": "suncity_skip_next_ready_morale",
		"count": int(player.flags.get("suncity_skip_next_ready_morale_count", 0))
	})
	lock_event.created_by_command = command_id
	state.event_log.append(lock_event)
	deploy_events.append(lock_event)
	return deploy_events

func _suncity_siwa_after_attack(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var card_id = str(stack_item.get("source_instance_id", ""))
	if card_id.is_empty():
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null or int(instance.controller) != controller or str(instance.zone) != "hand":
		return []
	var slot_options = _front_battlefield_slot_options(state, controller)
	if slot_options.is_empty():
		return []
	var slot = slot_options[0]
	var deploy_events = _deploy_hand_card_to_slot_with_orientation(state, controller, card_id, str(slot.get("row", "front")), int(slot.get("col", -1)), "active", command_id)
	if deploy_events.is_empty():
		return []
	var player = state.get_player(controller)
	player.flags["suncity_skip_next_ready_morale_count"] = int(player.flags.get("suncity_skip_next_ready_morale_count", 0)) + 1
	var lock_event = GameEvent.create(state.next_event_id(), "StatusApplied", controller, {
		"status": "suncity_skip_next_ready_morale",
		"count": int(player.flags.get("suncity_skip_next_ready_morale_count", 0)),
		"source_card_id": card_id
	})
	lock_event.created_by_command = command_id
	state.event_log.append(lock_event)
	deploy_events.append(lock_event)
	return deploy_events

func _move_source_one_step(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if instance == null or not instance.zone.begins_with("battle_"):
		return []
	var move_options = _effect_move_slot_options(state, source_id) if _instance_has_troop_type(state, source_id, "cavalry") else _one_step_move_slot_options(state, source_id)
	if move_options.is_empty():
		return []
	if move_options.size() == 1:
		var only_option = move_options[0]
		return _move_battlefield_card_to_slot_without_cost_for_options(state, source_id, str(only_option.get("row", "")), int(only_option.get("col", -1)), move_options, command_id)
	return _request_option_choice(state, int(instance.controller), move_options, "选择位移目标位置", "effect_move_source_slot", {
		"card_id": source_id,
		"move_options": move_options.duplicate(true)
	}, command_id)

func _manifest_kusanagi(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var card_id := ""
	var player = state.get_player(controller)
	for artifact_card_id in player.artifact_zone.cards:
		var artifact_instance = state.card_instances.get(artifact_card_id)
		if artifact_instance != null and str(artifact_instance.definition_id) == "takamagahara_s01_0417":
			card_id = artifact_card_id
			break
	if card_id.is_empty():
		return []
	var target_row = str(stack_item.get("targets", {}).get("row", ""))
	var target_col = int(stack_item.get("targets", {}).get("col", -1))
	if target_row != "front" or target_col < 0:
		var slot_options = _front_battlefield_slot_options(state, controller)
		if slot_options.is_empty():
			return []
		return _request_option_choice(state, controller, slot_options, "选择草薙剑置入的前排位置", "manifest_kusanagi_to_slot", {}, command_id)
	return _manifest_kusanagi_to_slot(state, controller, card_id, target_row, target_col, command_id)

func _manifest_kusanagi_to_slot(state: GameState, controller: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	if row != "front" or col < 0:
		return []
	var player = state.get_player(controller)
	var slot = player.get_slot(row, col)
	if slot == null or not slot.occupant.is_empty():
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var previous_zone := str(instance.zone)
	var previous_entered_turn := int(instance.entered_turn)
	var events: Array = []
	if previous_zone == "artifact_zone":
		events.append_array(_artifact_zone_leave_cleanup_events(state, card_id, command_id))
	_remove_card_from_current_zone(state, card_id)
	slot.occupant = card_id
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = "active"
	instance.controller = controller
	if previous_zone == "artifact_zone":
		instance.entered_turn = previous_entered_turn
	else:
		instance.entered_turn = state.turn_number
	instance.flags["manifested_power"] = 5000
	instance.flags["manifested_traits"] = ["legion"]
	instance.flags["kusanagi_leave_choice_enabled"] = true
	var event = GameEvent.create(state.next_event_id(), "MasterCardManifested", controller, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"power": 5000
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	events.append(event)
	events.append_array(_apply_legion_entry_calamity_for_card(state, card_id, command_id))
	return events

func _modify_power_until_turn_end(state: GameState, target_card_id: String, amount: int, command_id: String) -> Array:
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return []
	if int(instance.flags.get("power_modifier_until_turn_end_turn", -1)) != state.turn_number:
		instance.flags["power_modifier_until_turn_end_turn"] = state.turn_number
		instance.flags["power_modifier_until_turn_end_amount"] = 0
	instance.flags["power_modifier_until_turn_end_amount"] = int(instance.flags.get("power_modifier_until_turn_end_amount", 0)) + amount
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": target_card_id,
		"buff": "power_modifier_until_turn_end",
		"amount": int(instance.flags.get("power_modifier_until_turn_end_amount", 0))
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	events.append_array(_move_battlefield_card_to_grave_if_power_zero(state, target_card_id, command_id))
	return events

func _move_battlefield_card_to_grave_if_power_zero(state: GameState, card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null or not instance.zone.begins_with("battle_"):
		return []
	if get_card_power(state, card_id) > 0:
		return []
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if row.is_empty() or col < 0:
		return []
	return ZoneActions.move_battlefield_to_grave(state, instance.controller, row, col, command_id)

func _heal_master(state: GameState, player_id: int, amount: int, command_id: String, event_options: Dictionary = {}) -> Array:
	if amount <= 0:
		return []
	var player = state.get_player(player_id)
	if bool(player.flags.get("master_cannot_heal_for_game", false)):
		return []
	var source_card_id := ""
	var source_kind := ""
	if not command_id.is_empty():
		for index in range(state.event_log.size() - 1, -1, -1):
			var prior_event = state.event_log[index]
			if str(prior_event.created_by_command) != command_id:
				continue
			if str(prior_event.type) == "EffectResolved":
				source_card_id = str(prior_event.payload.get("source_id", ""))
				source_kind = "effect"
				break
			if str(prior_event.type) == "MasterDamaged":
				source_card_id = str(prior_event.payload.get("source_card_id", ""))
				source_kind = str(prior_event.payload.get("source_kind", ""))
				break
	if bool(player.flags.get("legion_source_heal_block_until_turn_end", false)):
		var source_instance = state.card_instances.get(source_card_id)
		var source_definition = state.get_definition(source_instance.definition_id) if source_instance != null else null
		if source_definition != null and source_definition.is_legion():
			return []
	var healed_amount = min(amount, max(0, player.master_max_hp - player.master_hp))
	if healed_amount <= 0:
		return []
	player.master_hp += healed_amount
	var event = GameEvent.create(state.next_event_id(), "MasterHealed", player_id, _merge_event_payload_options({
		"amount": healed_amount,
		"current_hp": player.master_hp,
		"source_card_id": source_card_id,
		"source_kind": source_kind
	}, event_options))
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _adjust_calamity_value(state: GameState, amount: int, command_id: String) -> Array:
	if amount == 0:
		return []
	if state.calamity_value_locked:
		return []
	state.calamity_value = max(0, state.calamity_value + amount)
	var event = GameEvent.create(state.next_event_id(), "CalamityValueChanged", state.active_player, {
		"value": state.calamity_value
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _request_candidate_cards_choice(state: GameState, player_id: int, candidate_card_ids: Array, count: int, title: String, operation: String, context: Dictionary, command_id: String) -> Array:
	var choice = {
		"choice_id": state.next_choice_id(),
		"type": "candidate_cards_pick",
		"title": title,
		"player_id": player_id,
		"count": count,
		"candidate_card_ids": candidate_card_ids.duplicate(),
		"operation": operation,
		"context": context.duplicate(true)
	}
	state.pending_choices.append(choice)
	var event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
		"choice_id": str(choice.get("choice_id", "")),
		"choice_type": "candidate_cards_pick",
		"title": title,
		"count": count,
		"candidate_cards": candidate_card_ids.duplicate()
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _request_option_choice(state: GameState, player_id: int, options: Array, title: String, operation: String, context: Dictionary, command_id: String) -> Array:
	var choice = {
		"choice_id": state.next_choice_id(),
		"type": "option_pick",
		"title": title,
		"player_id": player_id,
		"options": options.duplicate(true),
		"operation": operation,
		"context": context.duplicate(true)
	}
	state.pending_choices.append(choice)
	var event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
		"choice_id": str(choice.get("choice_id", "")),
		"choice_type": "option_pick",
		"title": title,
		"operation": operation,
		"options": options.duplicate(true)
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _request_option_with_shared_cost(state: GameState, player_id: int, option_action: Dictionary, command_id: String, source_instance_id: String = "") -> Array:
	if not (option_action is Dictionary):
		return []
	var own_master_hp_at_most = int(option_action.get("own_master_hp_at_most", -1))
	if own_master_hp_at_most >= 0 and state.get_player(player_id).master_hp > own_master_hp_at_most:
		return []
	var shared_cost = option_action.get("cost", {})
	var cost_check = _validate_effect_cost(state, player_id, {"cost": shared_cost if shared_cost is Dictionary else {}})
	if not cost_check.get("ok", false):
		return []
	var raw_options = option_action.get("options", [])
	if not (raw_options is Array):
		return []
	var options: Array = []
	var option_payloads := {}
	for raw_option in raw_options:
		if not (raw_option is Dictionary):
			continue
		var option_id = str(raw_option.get("id", ""))
		if option_id.is_empty():
			continue
		var option_resolution = raw_option.get("resolution", {})
		if option_resolution is Dictionary and not _resolution_has_available_targets_for_activation(state, player_id, source_instance_id, option_resolution):
			continue
		options.append({
			"id": option_id,
			"label": str(raw_option.get("label", option_id))
		})
		option_payloads[option_id] = {
			"resolution": option_resolution.duplicate(true) if option_resolution is Dictionary else {},
			"cost": raw_option.get("cost", {}).duplicate(true)
		}
	if bool(option_action.get("optional", false)):
		options.append({
			"id": "skip",
			"label": str(option_action.get("skip_label", "不发动"))
		})
	if options.is_empty():
		return []
	return _request_option_choice(state, player_id, options, str(option_action.get("title", "选择以下一项")), "resolve_option_with_shared_cost", {
		"source_instance_id": source_instance_id,
		"shared_cost": shared_cost.duplicate(true) if shared_cost is Dictionary else {},
		"option_payloads": option_payloads.duplicate(true)
	}, command_id)

func _resolve_candidate_cards_choice(state: GameState, choice: Dictionary, selected_card_ids: Array, resolve_payload: Dictionary, command_id: String) -> Array:
	var operation := str(choice.get("operation", ""))
	if operation == "search_deck" or operation == "search_deck_reorder_bottom" or operation == "search_top_for_artifact_and_named_legion":
		return DrawActions.resolve_search_choice(state, choice, selected_card_ids, command_id)
	var player_id = int(choice.get("player_id", -1))
	var selected: Array[String] = []
	for raw_card_id in selected_card_ids:
		selected.append(str(raw_card_id))
	var resolve_event = GameEvent.create(state.next_event_id(), "ChoiceResolved", player_id, {
		"choice_id": str(choice.get("choice_id", "")),
		"choice_type": str(choice.get("type", "")),
		"operation": operation,
		"title": str(choice.get("title", "")),
		"selected_card_ids": selected.duplicate()
	})
	resolve_event.created_by_command = command_id
	state.event_log.append(resolve_event)
	var events: Array = [resolve_event]
	var choice_context: Dictionary = choice.get("context", {}) if choice.get("context", {}) is Dictionary else {}
	var battle_options: Dictionary = choice_context.get("battle_options", {}).duplicate(true) if choice_context.get("battle_options", {}) is Dictionary else {}
	var event_options: Dictionary = choice_context.get("event_options", {}).duplicate(true) if choice_context.get("event_options", {}) is Dictionary else {}
	match operation:
		"discard_from_hand":
			var discard_event_options: Dictionary = event_options.duplicate(true)
			var discard_source_options := _effect_event_source_options(str(choice_context.get("source_instance_id", "")))
			for key in discard_source_options.keys():
				if not discard_event_options.has(key):
					discard_event_options[key] = discard_source_options[key]
			events.append_array(ZoneActions.discard_specific_from_hand(state, player_id, selected, command_id, discard_event_options))
			var follow_up_action = choice.get("context", {}).get("follow_up_action", {})
			if state.pending_choices.is_empty():
				var follow_up_stack_item = {
					"controller": int(choice.get("context", {}).get("initiator_player", player_id)),
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"resolution": follow_up_action.duplicate(true) if follow_up_action is Dictionary else {}
				}
				events.append_array(_resolve_stack_follow_up_action(state, follow_up_stack_item, follow_up_action, command_id))
		"destroy_battlefield_card":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				var row = str(instance.position.get("row", ""))
				var col = int(instance.position.get("col", -1))
				if row.is_empty() or col < 0:
					continue
				events.append_array(ZoneActions.move_battlefield_to_grave(state, instance.controller, row, col, command_id, battle_options))
			var destroy_follow_up = choice.get("context", {}).get("follow_up_action", {})
			if state.pending_choices.is_empty():
				var destroy_follow_up_stack_item = {
					"controller": int(choice.get("context", {}).get("initiator_player", player_id)),
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"resolution": destroy_follow_up.duplicate(true) if destroy_follow_up is Dictionary else {}
				}
				events.append_array(_resolve_stack_follow_up_action(state, destroy_follow_up_stack_item, destroy_follow_up, command_id))
		"hijikata_entry_destroy_combo":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				var row = str(instance.position.get("row", ""))
				var col = int(instance.position.get("col", -1))
				if row.is_empty() or col < 0:
					continue
				events.append_array(ZoneActions.move_battlefield_to_grave(state, instance.controller, row, col, command_id))
		"suncity_ramesses_replay_entries":
			events.append_array(_suncity_queue_replayed_entry_effects(state, player_id, selected, command_id))
		"olympus_helen_lethal_replace":
			if not selected.is_empty():
				events.append_array(_discard_hand_cards(state, player_id, [selected[0]], command_id, event_options))
				events.append_array(_apply_olympus_helen_lethal_replace(state, choice.get("context", {}), command_id))
			else:
				events.append_array(_resolve_pending_olympus_lethal_death(state, choice.get("context", {}), command_id))
		"tianting_freeze_enemy_morale_pick":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				instance.flags["cannot_ready_on_ready_phase_player"] = int(instance.controller)
				var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
					"card_id": str(card_id),
					"buff": "cannot_ready_on_ready_phase"
				})
				event.created_by_command = command_id
				state.event_log.append(event)
				events.append(event)
		"olympus_flip_morale_pick":
			if not selected.is_empty():
				events.append_array(MoraleActions.flip_morale_cards(state, player_id, selected, true, command_id))
		"tianting_shanhe_pick_card":
			var chosen_id = "" if selected.is_empty() else str(selected[0])
			var looked = choice.get("context", {}).get("looked", [])
			var remaining: Array[String] = []
			if looked is Array:
				for raw_card_id in looked:
					var card_id = str(raw_card_id)
					if card_id.is_empty() or card_id == chosen_id:
						continue
					remaining.append(card_id)
			if not chosen_id.is_empty():
				events.append_array(_tianting_move_revealed_deck_card_to_hand(state, player_id, chosen_id, command_id))
			events.append_array(_request_tianting_reorder_next_card(
				state,
				player_id,
				remaining,
				[],
				[],
				str(choice.get("context", {}).get("source_instance_id", "")),
				{},
				command_id
			))
		"tianting_reorder_pick_next_card":
			if selected.is_empty():
				return events
			var chosen_reorder_id = str(selected[0])
			var remaining_raw = choice.get("context", {}).get("remaining", [])
			var remaining_cards: Array[String] = []
			if remaining_raw is Array:
				for raw_card_id in remaining_raw:
					var card_id = str(raw_card_id)
					if card_id.is_empty() or card_id == chosen_reorder_id:
						continue
					remaining_cards.append(card_id)
			var top_cards_raw = choice.get("context", {}).get("top", [])
			var top_cards: Array[String] = []
			if top_cards_raw is Array:
				for raw_card_id in top_cards_raw:
					top_cards.append(str(raw_card_id))
			var bottom_cards_raw = choice.get("context", {}).get("bottom", [])
			var bottom_cards: Array[String] = []
			if bottom_cards_raw is Array:
				for raw_card_id in bottom_cards_raw:
					bottom_cards.append(str(raw_card_id))
			events.append_array(_request_option_choice(state, player_id, [
				{"id": "top", "label": "放回牌库顶部"},
				{"id": "bottom", "label": "放回牌库底部"}
			], "选择放回位置", "tianting_reorder_choose_destination", {
				"selected_card_id": chosen_reorder_id,
				"remaining": remaining_cards.duplicate(),
				"top": top_cards.duplicate(),
				"bottom": bottom_cards.duplicate(),
				"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
				"follow_up_action": choice.get("context", {}).get("follow_up_action", {}).duplicate(true) if choice.get("context", {}).get("follow_up_action", {}) is Dictionary else {}
			}, command_id))
		"return_battlefield_card_to_hand":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				var row = str(instance.position.get("row", ""))
				var col = int(instance.position.get("col", -1))
				if row.is_empty() or col < 0:
					continue
				events.append_array(ZoneActions.return_battlefield_to_hand(state, instance.controller, row, col, command_id, battle_options))
			var return_battlefield_follow_up = choice.get("context", {}).get("follow_up_action", {})
			if state.pending_choices.is_empty():
				var return_battlefield_follow_up_stack_item = {
					"controller": int(choice.get("context", {}).get("initiator_player", player_id)),
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"resolution": return_battlefield_follow_up.duplicate(true) if return_battlefield_follow_up is Dictionary else {}
				}
				events.append_array(_resolve_stack_follow_up_action(state, return_battlefield_follow_up_stack_item, return_battlefield_follow_up, command_id))
		"return_battlefield_card_to_deck_bottom":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				var row = str(instance.position.get("row", ""))
				var col = int(instance.position.get("col", -1))
				if row.is_empty() or col < 0:
					continue
				events.append_array(ZoneActions.return_battlefield_to_deck_bottom(state, instance.controller, row, col, command_id, battle_options))
		"recycle_grave_to_deck":
			events.append_array(_move_grave_cards_to_deck_bottom(state, player_id, selected, command_id))
			var heal_amount = int(choice.get("context", {}).get("heal_master", 0))
			if heal_amount > 0:
				events.append_array(_heal_master(state, player_id, heal_amount, command_id))
			var follow_up = choice.get("context", {}).get("follow_up_action", {})
			if follow_up is Dictionary and not follow_up.is_empty():
				var follow_up_stack_item = {
					"controller": player_id,
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"resolution": follow_up.duplicate(true)
				}
				events.append_array(_resolve_stack_follow_up_action(state, follow_up_stack_item, follow_up, command_id))
		"recycle_grave_then_revive_source_from_grave":
			events.append_array(_move_grave_cards_to_deck_bottom(state, player_id, selected, command_id))
			var revive_source_id = str(choice.get("context", {}).get("source_instance_id", ""))
			if not revive_source_id.is_empty():
				var slot_options = _battlefield_slot_options(state, player_id)
				if slot_options.is_empty():
					return events
				events.append_array(_request_option_choice(state, player_id, slot_options, "选择登场位置", "revive_selected_grave_to_slot", {
					"card_id": revive_source_id,
					"rested": false
				}, command_id))
		"return_hand_to_deck_bottom":
			if not selected.is_empty():
				events.append_array(_move_hand_cards_to_deck_bottom(state, player_id, selected, command_id, event_options))
			if bool(choice.get("context", {}).get("shuffle_after", false)):
				var shuffle_player_id = int(choice.get("context", {}).get("shuffle_player_id", player_id))
				events.append_array(_shuffle_deck(state, {
					"controller": shuffle_player_id
				}, command_id))
			var return_follow_up = choice.get("context", {}).get("follow_up_action", {})
			if state.pending_choices.is_empty():
				var return_follow_up_stack_item = {
					"controller": int(choice.get("context", {}).get("initiator_player", player_id)),
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"resolution": return_follow_up.duplicate(true) if return_follow_up is Dictionary else {}
				}
				events.append_array(_resolve_stack_follow_up_action(state, return_follow_up_stack_item, return_follow_up, command_id))
		"return_enemy_hand_to_deck_top":
			if not selected.is_empty():
				var target_hand_player_id = int(choice.get("context", {}).get("target_hand_player_id", player_id))
				events.append_array(_move_hand_cards_to_deck_top(state, target_hand_player_id, selected, command_id, event_options))
			var top_follow_up = choice.get("context", {}).get("follow_up_action", {})
			if state.pending_choices.is_empty():
				var top_follow_up_stack_item = {
					"controller": int(choice.get("context", {}).get("initiator_player", player_id)),
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"resolution": top_follow_up.duplicate(true) if top_follow_up is Dictionary else {}
				}
				events.append_array(_resolve_stack_follow_up_action(state, top_follow_up_stack_item, top_follow_up, command_id))
		"yangjian_choose_hand_to_put_back":
			if not selected.is_empty():
				events.append_array(_request_option_choice(state, player_id, [
					{"id": "top", "label": "放回牌库顶"},
					{"id": "bottom", "label": "放回牌库底"}
				], "选择放回位置", "yangjian_choose_put_back_position", {
					"card_id": selected[0]
				}, command_id))
		"bjorn_recycle_then_maybe_revive":
			var source_id = str(choice.get("context", {}).get("source_instance_id", ""))
			if source_id.is_empty():
				return events
			if not selected.is_empty():
				events.append_array(_move_grave_cards_to_deck_bottom(state, player_id, selected, command_id, event_options))
			var revive_row := str(choice.get("context", {}).get("revive_row", ""))
			var revive_col := int(choice.get("context", {}).get("revive_col", -1))
			events.append_array(_maybe_request_bjorn_rested_revive_choice(state, player_id, source_id, revive_row, revive_col, command_id))
		"revive_from_grave":
			if not selected.is_empty():
				if _uses_formal_rules(state):
					var slot_options = _battlefield_slot_options(state, player_id)
					if not slot_options.is_empty():
						events.append_array(_request_option_choice(state, player_id, slot_options, "选择登场位置", "revive_selected_grave_to_slot", {
							"card_id": selected[0],
							"rested": bool(choice.get("context", {}).get("rested", false))
						}, command_id))
				else:
					if bool(choice.get("context", {}).get("rested", false)):
						events.append_array(_revive_bjorn_source_rested(state, player_id, selected[0], command_id))
					else:
						events.append_array(_revive_grave_card_to_first_slot(state, player_id, selected[0], command_id))
		"deploy_from_hand_to_battlefield":
			if not selected.is_empty():
				var row := str(resolve_payload.get("row", ""))
				var col := int(resolve_payload.get("col", -1))
				var deployment_orientation = str(choice.get("context", {}).get("deployment_orientation", "active"))
				if not row.is_empty() and col >= 0:
					events.append_array(_deploy_hand_card_to_slot_with_orientation(state, player_id, selected[0], row, col, deployment_orientation, command_id))
					events.append_array(_resolve_choice_follow_up_action(state, player_id, selected[0], choice.get("context", {}).get("follow_up_action", {}), command_id))
				else:
					var slot_options = _battlefield_slot_options(state, player_id)
					if not slot_options.is_empty():
						events.append_array(_request_option_choice(state, player_id, slot_options, "选择登场位置", "deploy_selected_hand_to_slot", {
							"card_id": selected[0],
							"follow_up_action": choice.get("context", {}).get("follow_up_action", {}).duplicate(true),
							"deployment_orientation": deployment_orientation
						}, command_id))
					else:
						events.append_array(_deploy_hand_card_to_first_slot(state, player_id, selected[0], command_id, deployment_orientation))
						events.append_array(_resolve_choice_follow_up_action(state, player_id, selected[0], choice.get("context", {}).get("follow_up_action", {}), command_id))
		"choose_battlefield_cards_to_move":
			if not selected.is_empty():
				if bool(choice.get("context", {}).get("grant_free_move_until_turn_end", false)):
					events.append_array(_grant_selected_free_move_until_turn_end(state, selected, choice.get("context", {}), command_id))
				else:
					var inline_row := str(resolve_payload.get("row", ""))
					var inline_col := int(resolve_payload.get("col", -1))
					if selected.size() == 1 and not inline_row.is_empty() and inline_col >= 0:
						events.append_array(_move_battlefield_card_to_slot_without_cost(state, str(selected[0]), inline_row, inline_col, command_id))
					else:
						events.append_array(_request_move_slot_choice_for_cards(state, player_id, selected, command_id))
		"set_counter_tactics_from_hand":
			if not selected.is_empty():
				events.append_array(_request_set_counter_tactic_slot_choice_for_cards(
					state,
					player_id,
					selected,
					command_id,
					choice.get("context", {}).get("follow_up_action", {}),
					str(choice.get("context", {}).get("source_instance_id", ""))
				))
		"return_grave_to_hand":
			if not selected.is_empty():
				events.append_array(_move_grave_cards_to_hand(state, player_id, selected, command_id, {
					"source_kind": str(choice.get("context", {}).get("source_kind", "")),
					"source_card_id": str(choice.get("context", {}).get("source_card_id", "")),
					"source_player_id": int(choice.get("context", {}).get("source_player_id", player_id))
				}))
		"return_from_deck_or_grave_to_hand":
			if not selected.is_empty():
				var follow_up_stack_item = {
					"controller": player_id,
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"source_kind": str(choice.get("context", {}).get("source_kind", "")),
					"source_player_id": int(choice.get("context", {}).get("source_player_id", player_id)),
					"resolution": {
						"follow_up_action": choice.get("context", {}).get("follow_up_action", {}).duplicate(true)
					}
				}
				if choice.get("context", {}).has("source_card_id"):
					follow_up_stack_item["source_card_id"] = str(choice.get("context", {}).get("source_card_id", ""))
				events.append_array(_move_matching_card_from_deck_or_grave_to_hand(state, player_id, selected[0], follow_up_stack_item, command_id))
		"landlord_coercion_extra_discard":
			if not state.pending_attack.is_empty():
				var pending_attack = state.pending_attack.duplicate(true)
				pending_attack.erase("extra_defense_discard_required")
				pending_attack.erase("extra_defense_discard_source_id")
				if selected.is_empty():
					pending_attack.erase("blocker_id")
					pending_attack.erase("supporter_id")
					pending_attack.erase("extra_discard_card_id")
					pending_attack.erase("master_guard_card_ids")
				state.pending_attack = pending_attack
			if not selected.is_empty():
				events.append_array(ZoneActions.discard_specific_from_hand(
					state,
					int(choice.get("context", {}).get("defense_player_id", player_id)),
					[selected[0]],
					command_id,
					_effect_event_source_options(str(choice.get("context", {}).get("source_instance_id", "")))
				))
		"deploy_from_hand_or_grave":
			if not selected.is_empty():
				var instance = state.card_instances.get(selected[0])
				if instance == null:
					return events
				var slot_options = _battlefield_slot_options(state, player_id)
				if slot_options.is_empty():
					return events
				events.append_array(_request_option_choice(state, player_id, slot_options, "选择登场位置", "deploy_selected_hand_or_grave_to_slot", {
					"card_id": selected[0],
					"from_zone": str(instance.zone)
				}, command_id))
		"deploy_from_hand_deck_or_grave":
			if not selected.is_empty():
				var instance = state.card_instances.get(selected[0])
				if instance == null:
					return events
				var slot_options = _battlefield_slot_options(state, player_id)
				if slot_options.is_empty():
					return events
				events.append_array(_request_option_choice(state, player_id, slot_options, "选择登场位置", "deploy_selected_hand_or_grave_to_slot", {
					"card_id": selected[0],
					"from_zone": str(instance.zone),
					"follow_up_action": choice.get("context", {}).get("follow_up_action", {}).duplicate(true)
				}, command_id))
		"rest_battlefield_card":
			if not selected.is_empty():
				events.append_array(_rest_target_unit(state, selected[0], command_id))
		"ready_battlefield_card":
			if not selected.is_empty():
				events.append_array(_ready_target_unit(state, selected[0], command_id))
		"disable_counter_tactic_until_turn_end":
			if not selected.is_empty():
				events.append_array(_disable_counter_tactic_until_turn_end(state, selected[0], command_id))
		"destroy_battlefield_cards":
			for card_id in selected:
				var targeted_stack_item := {
					"targets": {"target_card_id": str(card_id)},
					"resolution": choice.get("context", {}).get("resolution", {}).duplicate(true)
				}
				events.append_array(_destroy_target_unit(state, targeted_stack_item, command_id))
		"suncity_isis_send_tomb_guards":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				var row = str(instance.position.get("row", ""))
				var col = int(instance.position.get("col", -1))
				if row.is_empty() or col < 0:
					continue
				events.append_array(ZoneActions.move_battlefield_to_grave(state, instance.controller, row, col, command_id))
			var source_id = str(choice.get("context", {}).get("source_instance_id", ""))
			events.append_array(_suncity_place_canopic_after_cost(state, player_id, source_id, command_id))
		"suncity_canopic_one_buff":
			if not selected.is_empty():
				var target_id = str(selected[0])
				events.append_array(_modify_power_until_turn_end(state, target_id, 2000, command_id))
				var target_instance = state.card_instances.get(target_id)
				if target_instance != null:
					target_instance.flags["temporary_keyword_strong_attack_turn"] = state.turn_number
					var keyword_event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(target_instance.controller), {
						"card_id": target_id,
						"buff": "temporary_keyword",
						"keyword": "strong_attack"
					})
					keyword_event.created_by_command = command_id
					state.event_log.append(keyword_event)
					events.append(keyword_event)
			events.append_array(_send_source_to_grave(state, {
				"source_instance_id": str(choice.get("context", {}).get("source_instance_id", ""))
			}, command_id))
		"suncity_canopic_four_protect":
			for card_id in selected:
				events.append_array(_grant_cannot_die_once_until_next_own_turn_start(state, {
					"controller": player_id,
					"targets": {"target_card_id": str(card_id)},
					"resolution": {}
				}, command_id))
			events.append_array(_send_source_to_grave(state, {
				"source_instance_id": str(choice.get("context", {}).get("source_instance_id", ""))
			}, command_id))
		"suncity_horemheb_entry_charge":
			if not selected.is_empty():
				var tomb_guard_id = str(selected[0])
				var tomb_guard_instance = state.card_instances.get(tomb_guard_id)
				if tomb_guard_instance != null:
					var row = str(tomb_guard_instance.position.get("row", ""))
					var col = int(tomb_guard_instance.position.get("col", -1))
					if not row.is_empty() and col >= 0:
						events.append_array(ZoneActions.move_battlefield_to_grave(state, int(tomb_guard_instance.controller), row, col, command_id))
				events.append_array(_grant_source_keyword_until_turn_end(state, {
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"resolution": {"keyword": "charge"}
				}, command_id))
		"suncity_ankh_rest_tomb_guard_draw":
			if not selected.is_empty():
				events.append_array(_rest_target_unit(state, str(selected[0]), command_id))
				events.append_array(DrawActions.draw_cards(state, player_id, 1, command_id))
		"suncity_pharaoh_pick_cards":
			if selected.size() >= 2:
				events.append_array(_request_candidate_cards_choice(state, player_id, selected, 1, "选择1张加入手牌", "suncity_pharaoh_pick_to_hand", {
					"selected": selected.duplicate(),
					"looked": choice.get("context", {}).get("looked", []).duplicate()
				}, command_id))
			elif selected.size() == 1:
				events.append_array(_tianting_move_revealed_deck_card_to_hand(state, player_id, str(selected[0]), command_id))
				var remaining_one: Array[String] = []
				for raw_card_id in choice.get("context", {}).get("looked", []):
					var looked_id = str(raw_card_id)
					if looked_id == str(selected[0]):
						continue
					remaining_one.append(looked_id)
				events.append_array(_request_olympus_reorder_bottom_next_card(state, player_id, remaining_one, [], "", command_id))
		"suncity_pharaoh_pick_to_hand":
			if not selected.is_empty():
				var chosen_hand_id = str(selected[0])
				events.append_array(_tianting_move_revealed_deck_card_to_hand(state, player_id, chosen_hand_id, command_id))
				var grave_targets: Array[String] = []
				for raw_card_id in choice.get("context", {}).get("selected", []):
					var selected_id = str(raw_card_id)
					if selected_id.is_empty() or selected_id == chosen_hand_id:
						continue
					grave_targets.append(selected_id)
				for grave_id in grave_targets:
					events.append_array(_suncity_move_revealed_deck_card_to_grave(state, player_id, grave_id, command_id))
				var remaining_after: Array[String] = []
				for raw_card_id in choice.get("context", {}).get("looked", []):
					var looked_id = str(raw_card_id)
					if looked_id == chosen_hand_id or grave_targets.has(looked_id):
						continue
					remaining_after.append(looked_id)
				events.append_array(_request_olympus_reorder_bottom_next_card(state, player_id, remaining_after, [], "", command_id))
		"suncity_menes_attack_buff":
			if not selected.is_empty():
				var sacrificed_id = str(selected[0])
				var sacrificed_instance = state.card_instances.get(sacrificed_id)
				if sacrificed_instance != null:
					var row = str(sacrificed_instance.position.get("row", ""))
					var col = int(sacrificed_instance.position.get("col", -1))
					if not row.is_empty() and col >= 0:
						events.append_array(ZoneActions.move_battlefield_to_grave(state, int(sacrificed_instance.controller), row, col, command_id))
				events.append_array(_modify_power_until_turn_end(state, str(choice.get("context", {}).get("source_instance_id", "")), 2000, command_id))
				events.append_array(_grant_source_keyword_until_turn_end(state, {
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
					"resolution": {"keyword": "strong_attack"}
				}, command_id))
		"suncity_tutankhamun_entry":
			for card_id in selected:
				events.append_array(_revive_grave_card_to_first_slot(state, player_id, str(card_id), command_id))
		"suncity_tutankhamun_death":
			if not selected.is_empty():
				events.append_array(_move_grave_cards_to_deck_top(state, player_id, [str(selected[0])], command_id))
		"attach_matching_cards_under_source":
			var attach_source_id = str(choice.get("context", {}).get("source_instance_id", ""))
			var attach_source = state.card_instances.get(attach_source_id)
			if attach_source != null:
				for raw_card_id in selected:
					var card_id = str(raw_card_id)
					var instance = state.card_instances.get(card_id)
					if instance == null:
						continue
					var owner_player = state.get_player(int(instance.owner))
					owner_player.hand.remove_card(card_id)
					owner_player.deck.remove_card(card_id)
					owner_player.grave.remove_card(card_id)
					if str(instance.zone).begins_with("battle_"):
						var row = str(instance.position.get("row", ""))
						var col = int(instance.position.get("col", -1))
						if not row.is_empty() and col >= 0:
							var slot = state.get_player(int(instance.controller)).get_slot(row, col)
							if slot != null and str(slot.occupant) == card_id:
								slot.occupant = ""
					instance.zone = "attached_underlay"
					instance.position = {"host_id": attach_source_id}
					instance.controller = int(attach_source.controller)
					instance.orientation = "active"
					instance.face = "face_up"
					if not attach_source.attached_cards.has(card_id):
						attach_source.attached_cards.append(card_id)
					var attached_event = GameEvent.create(state.next_event_id(), "CardAttachedUnderSource", int(attach_source.controller), {
						"card_id": card_id,
						"host_id": attach_source_id
					})
					attached_event.created_by_command = command_id
					state.event_log.append(attached_event)
					events.append(attached_event)
		"discard_attached_cards_for_power_until_turn_end":
			var host_id = str(choice.get("context", {}).get("source_instance_id", ""))
			var host = state.card_instances.get(host_id)
			if host != null and not selected.is_empty():
				var discarded_count := 0
				for raw_card_id in selected:
					var attached_id = str(raw_card_id)
					if not host.attached_cards.has(attached_id):
						continue
					host.attached_cards.erase(attached_id)
					var attached_instance = state.card_instances.get(attached_id)
					if attached_instance == null:
						continue
					var owner_player = state.get_player(int(attached_instance.owner))
					owner_player.grave.add_card_to_top(attached_id)
					attached_instance.zone = "grave"
					attached_instance.position = {}
					attached_instance.controller = int(attached_instance.owner)
					attached_instance.orientation = "active"
					attached_instance.face = "face_up"
					discarded_count += 1
					var sent_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", int(owner_player.player_id), {
						"card_id": attached_id,
						"from": "attached_underlay",
						"to": "grave"
					})
					sent_event.created_by_command = command_id
					state.event_log.append(sent_event)
					events.append(sent_event)
				if discarded_count > 0:
					events.append_array(_modify_power_until_turn_end(state, host_id, discarded_count * int(choice.get("context", {}).get("amount_per_card", 1000)), command_id))
		"suncity_golden_scarab_weaken":
			for card_id in selected:
				events.append_array(_modify_power_until_turn_end(state, str(card_id), -1000, command_id))
		"suncity_isis_place_canopic":
			if not selected.is_empty():
				events.append_array(_place_artifact_without_play(state, player_id, str(selected[0]), command_id))
				events.append_array(_request_option_choice(state, player_id, [
					{"id": "draw", "label": "抽1张牌"},
					{"id": "heal", "label": "主宰回复1点血量"}
				], "选择伊西斯的额外效果", "suncity_isis_reward", {
					"source_instance_id": str(choice.get("context", {}).get("source_instance_id", ""))
				}, command_id))
		"suncity_prepare_discount_units":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				var row = str(instance.position.get("row", ""))
				var col = int(instance.position.get("col", -1))
				if row.is_empty() or col < 0:
					continue
				events.append_array(ZoneActions.move_battlefield_to_grave(state, instance.controller, row, col, command_id))
			var discount_count = selected.size()
			if discount_count > 0:
				state.get_player(player_id).flags["suncity_next_calamity_discount"] = {
					"turn": state.turn_number,
					"amount": -discount_count
				}
				var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", player_id, {
					"buff": "suncity_next_calamity_discount",
					"amount": -discount_count
				})
				event.created_by_command = command_id
				state.event_log.append(event)
				events.append(event)
		"suncity_desert_discard_units":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				var row = str(instance.position.get("row", ""))
				var col = int(instance.position.get("col", -1))
				if row.is_empty() or col < 0:
					continue
				events.append_array(ZoneActions.move_battlefield_to_grave(state, instance.controller, row, col, command_id))
			var discarded_count = selected.size()
			if discarded_count > 0:
				var hand_candidates = _matching_hand_card_ids(state, player_id, {
					"faction": "suncity",
					"type": "legion",
					"calamity_level": discarded_count
				})
				if not hand_candidates.is_empty():
					events.append_array(_request_candidate_cards_choice(state, player_id, hand_candidates, 1, "选择要登场的太阳城军团", "deploy_from_hand_to_battlefield", {}, command_id))
		"suncity_medjed_weaken_target":
			if not selected.is_empty():
				events.append_array(_modify_power_until_turn_end(state, str(selected[0]), int(choice.get("context", {}).get("amount", -1000)), command_id))
		"suncity_medjed_rest_tomb_guard_for_weaken":
			if not selected.is_empty():
				events.append_array(_rest_target_unit(state, str(selected[0]), command_id))
				var enemy_candidates_raw = choice.get("context", {}).get("enemy_candidates", [])
				var enemy_candidates: Array[String] = []
				if enemy_candidates_raw is Array:
					for raw_card_id in enemy_candidates_raw:
						var enemy_id = str(raw_card_id)
						if enemy_id.is_empty():
							continue
						if state.card_instances.get(enemy_id) == null:
							continue
						enemy_candidates.append(enemy_id)
				if not enemy_candidates.is_empty():
					events.append_array(_request_candidate_cards_choice(state, player_id, enemy_candidates, 1, "选择对方1张军团本回合兵力-3000", "suncity_medjed_weaken_target", {
						"amount": -3000
					}, command_id))
		"modify_power_until_turn_end":
			if not selected.is_empty():
				for card_id in selected:
					events.append_array(_modify_power_until_turn_end(state, card_id, int(choice.get("context", {}).get("amount", 0)), command_id))
				var modify_power_follow_up = choice.get("context", {}).get("follow_up_action", {})
				if state.pending_choices.is_empty():
					var modify_power_follow_up_stack_item = {
						"controller": int(choice.get("context", {}).get("initiator_player", player_id)),
						"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
						"resolution": modify_power_follow_up.duplicate(true) if modify_power_follow_up is Dictionary else {}
					}
					events.append_array(_resolve_stack_follow_up_action(state, modify_power_follow_up_stack_item, modify_power_follow_up, command_id))
		"attach_source_to_enemy_artifact_lock":
			if not selected.is_empty():
				events.append_array(_attach_source_to_enemy_artifact_lock_target(
					state,
					str(choice.get("context", {}).get("source_instance_id", "")),
					str(selected[0]),
					command_id
				))
		"grant_keyword_until_turn_end":
			if not selected.is_empty():
				for card_id in selected:
					events.append_array(_grant_keyword_to_card_until_turn_end(state, card_id, str(choice.get("context", {}).get("keyword", "")), command_id))
		"modify_cost_until_turn_end":
			if not selected.is_empty():
				events.append_array(_modify_cost_until_turn_end(state, selected[0], int(choice.get("context", {}).get("amount", 0)), command_id))
				var modify_cost_follow_up = choice.get("context", {}).get("follow_up_action", {})
				if state.pending_choices.is_empty():
					var modify_cost_follow_up_stack_item = {
						"controller": int(choice.get("context", {}).get("initiator_player", player_id)),
						"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
						"resolution": modify_cost_follow_up.duplicate(true) if modify_cost_follow_up is Dictionary else {}
					}
					events.append_array(_resolve_stack_follow_up_action(state, modify_cost_follow_up_stack_item, modify_cost_follow_up, command_id))
		"modify_cost_until_next_own_turn_end":
			if not selected.is_empty():
				events.append_array(_modify_cost_until_next_own_turn_end(state, selected[0], int(choice.get("context", {}).get("amount", 0)), int(choice.get("context", {}).get("expires_on_player_turn_end", player_id)), command_id))
				events.append_array(_auto_pass_empty_pending_attack_response_window(state, command_id))
		"modify_power_until_next_own_turn_end":
			if not selected.is_empty():
				events.append_array(_modify_power_until_next_own_turn_end(state, selected[0], int(choice.get("context", {}).get("amount", 0)), int(choice.get("context", {}).get("expires_on_player_turn_end", player_id)), command_id))
				events.append_array(_auto_pass_empty_pending_attack_response_window(state, command_id))
		"split_grave_pick_two":
			if selected.size() == 2:
				events.append_array(_request_candidate_cards_choice(state, player_id, selected, 1, "选择加入手牌的卡牌", "split_grave_choose_hand", {
					"selected_pair": selected.duplicate(),
					"requires_confirm": true
				}, command_id))
		"split_grave_choose_hand":
			if not selected.is_empty():
				var pair = choice.get("context", {}).get("selected_pair", [])
				if pair is Array and pair.size() == 2:
					var chosen = selected[0]
					var other = str(pair[0]) if str(pair[0]) != chosen else str(pair[1])
					events.append_array(_move_grave_cards_to_hand(state, player_id, [chosen], command_id))
					events.append_array(_move_grave_cards_to_deck_bottom(state, player_id, [other], command_id))
		"trigger_selected_legion_died_effects":
			for card_id in selected:
				var instance = state.card_instances.get(card_id)
				if instance == null:
					continue
				var died_event = GameEvent.create(state.next_event_id(), "CardDied", int(instance.controller), {
					"card_id": card_id,
					"source_card_id": card_id,
					"reason": "effect"
				})
				died_event.created_by_command = command_id
				state.event_log.append(died_event)
				events.append(died_event)
		"tsukuyomi_choose_move_card":
			if not selected.is_empty():
				var moving_card_id = selected[0]
				var move_options = _one_step_move_slot_options(state, moving_card_id)
				var inline_row := str(resolve_payload.get("row", ""))
				var inline_col := int(resolve_payload.get("col", -1))
				if not move_options.is_empty() and not inline_row.is_empty() and inline_col >= 0 and _move_option_list_has_slot(move_options, inline_row, inline_col):
					events.append_array(_move_battlefield_card_to_slot_without_cost_for_options(state, moving_card_id, inline_row, inline_col, move_options, command_id))
					events.append_array(_modify_cost_until_turn_end(state, moving_card_id, -1, command_id))
				elif not move_options.is_empty():
					events.append_array(_request_option_choice(state, player_id, move_options, "选择月读要位移到的位置", "tsukuyomi_choose_move_slot", {
						"card_id": moving_card_id,
						"move_options": move_options.duplicate(true)
					}, command_id))
		"takamagahara_morale_choose_move_card":
			if not selected.is_empty():
				var moving_card_id = selected[0]
				var move_options = _one_step_move_slot_options(state, moving_card_id)
				var inline_row := str(resolve_payload.get("row", ""))
				var inline_col := int(resolve_payload.get("col", -1))
				if not move_options.is_empty() and not inline_row.is_empty() and inline_col >= 0 and _move_option_list_has_slot(move_options, inline_row, inline_col):
					events.append_array(_move_battlefield_card_to_slot_without_cost_for_options(state, moving_card_id, inline_row, inline_col, move_options, command_id))
				elif not move_options.is_empty():
					events.append_array(_request_option_choice(state, player_id, move_options, "选择高天原要位移到的位置", "takamagahara_morale_choose_move_slot", {
						"card_id": moving_card_id,
						"move_options": move_options.duplicate(true)
					}, command_id))
		"forged_order_choose_enemy_move_card":
			if not selected.is_empty():
				var moving_card_id = selected[0]
				var move_options = _move_target_options(_forged_order_vertical_move_targets(state, moving_card_id))
				var inline_row := str(resolve_payload.get("row", ""))
				var inline_col := int(resolve_payload.get("col", -1))
				if move_options.is_empty():
					return events
				var moved := false
				if not inline_row.is_empty() and inline_col >= 0 and _move_option_list_has_slot(move_options, inline_row, inline_col):
					events.append_array(_move_battlefield_card_to_slot_without_cost_for_options(state, moving_card_id, inline_row, inline_col, move_options, command_id))
					moved = true
				else:
					var only_option = move_options[0]
					events.append_array(_move_battlefield_card_to_slot_without_cost_for_options(state, moving_card_id, str(only_option.get("row", "")), int(only_option.get("col", -1)), move_options, command_id))
					moved = true
				if moved:
					var moved_ids: Array[String] = []
					var moved_ids_raw = choice.get("context", {}).get("moved_card_ids", [])
					if moved_ids_raw is Array:
						for raw_id in moved_ids_raw:
							moved_ids.append(str(raw_id))
					if not moved_ids.has(moving_card_id):
						moved_ids.append(moving_card_id)
					var remaining_moves := int(choice.get("context", {}).get("remaining_moves", 1)) - 1
					events.append_array(_request_forged_order_enemy_move_choice(
						state,
						player_id,
						remaining_moves,
						moved_ids,
						str(choice.get("context", {}).get("source_instance_id", "")),
						command_id
					))
		"target_then_stack_effect":
			if not selected.is_empty():
				var stack_item = choice.get("context", {}).get("stack_item", {})
				if stack_item is Dictionary and not stack_item.is_empty():
					for card_id in selected:
						var targeted_stack_item: Dictionary = stack_item.duplicate(true)
						targeted_stack_item["targets"] = {"target_card_id": str(card_id)}
						events.append_array(_put_prebuilt_stack_item_on_stack(state, targeted_stack_item, command_id))
		"target_set_counter_tactic_then_stack_effect":
			if not selected.is_empty():
				var stack_item = choice.get("context", {}).get("stack_item", {})
				if stack_item is Dictionary and not stack_item.is_empty():
					var targeted_stack_item: Dictionary = stack_item.duplicate(true)
					targeted_stack_item["targets"] = {"target_card_id": selected[0]}
					events.append_array(_put_prebuilt_stack_item_on_stack(state, targeted_stack_item, command_id))
		"olympus_revealed_pick_to_hand":
			var olympus_chosen_id = "" if selected.is_empty() else str(selected[0])
			var looked = choice.get("context", {}).get("looked", [])
			var remaining: Array[String] = []
			if looked is Array:
				for raw_card_id in looked:
					var card_id = str(raw_card_id)
					if card_id.is_empty() or card_id == olympus_chosen_id:
						continue
					remaining.append(card_id)
			if not olympus_chosen_id.is_empty():
				events.append_array(_tianting_move_revealed_deck_card_to_hand(state, player_id, olympus_chosen_id, command_id))
			var reorder_mode = str(choice.get("context", {}).get("reorder_mode", ""))
			if reorder_mode == "top_or_bottom":
				events.append_array(_request_tianting_reorder_next_card(state, player_id, remaining, [], [], str(choice.get("context", {}).get("source_instance_id", "")), {}, command_id))
			elif reorder_mode == "bottom_only":
				events.append_array(_request_olympus_reorder_bottom_next_card(state, player_id, remaining, [], str(choice.get("context", {}).get("source_instance_id", "")), command_id))
		"olympus_reorder_bottom_pick":
			if selected.is_empty():
				return events
			var chosen_bottom_id = str(selected[0])
			var remaining_raw = choice.get("context", {}).get("remaining", [])
			var remaining_cards: Array[String] = []
			if remaining_raw is Array:
				for raw_card_id in remaining_raw:
					var card_id = str(raw_card_id)
					if card_id.is_empty() or card_id == chosen_bottom_id:
						continue
					remaining_cards.append(card_id)
			var bottom_cards_raw = choice.get("context", {}).get("bottom", [])
			var bottom_cards: Array[String] = []
			if bottom_cards_raw is Array:
				for raw_card_id in bottom_cards_raw:
					bottom_cards.append(str(raw_card_id))
			bottom_cards.append(chosen_bottom_id)
			events.append_array(_request_olympus_reorder_bottom_next_card(state, player_id, remaining_cards, bottom_cards, str(choice.get("context", {}).get("source_instance_id", "")), command_id))
		"olympus_artemis_pick_target":
			if not selected.is_empty():
				events.append_array(_request_option_choice(state, player_id, [
					{"id": "strong_attack", "label": "获得强攻"},
					{"id": "shock", "label": "获得震击"}
				], "选择阿尔忒弥斯赋予的能力", "olympus_artemis_choose_keyword", {
					"card_id": selected[0]
				}, command_id))
		"olympus_reveal_hand_legion_to_deck_top":
			if not selected.is_empty():
				var selected_id = str(selected[0])
				events.append_array(_tianting_reveal_card(state, player_id, selected_id, "hand", command_id))
				events.append_array(_move_hand_cards_to_deck_top(state, player_id, [selected_id], command_id))
				var revealed_instance = state.card_instances.get(selected_id)
				var revealed_definition = state.get_definition(revealed_instance.definition_id) if revealed_instance != null else null
				if revealed_definition != null:
					var max_cost = int(revealed_definition.cost)
					var controller = int(choice.get("context", {}).get("initiator_player", player_id))
					var source_instance_id = str(choice.get("context", {}).get("source_instance_id", ""))
					var candidates: Array[String] = []
					for target_card_id in _get_battlefield_card_ids_for_player(state, 1 - controller):
						var target_instance = state.card_instances.get(str(target_card_id))
						var target_definition = state.get_definition(target_instance.definition_id) if target_instance != null else null
						if target_definition == null or int(target_definition.cost) > max_cost:
							continue
						candidates.append(str(target_card_id))
					if not candidates.is_empty():
						events.append_array(_request_candidate_cards_choice(state, controller, candidates, 1, "选择要击杀的军团", "olympus_destroy_enemy_by_revealed_cost", {
							"source_instance_id": source_instance_id,
							"initiator_player": controller,
							"requires_confirm": true
						}, command_id))
		"olympus_destroy_enemy_by_revealed_cost":
			if not selected.is_empty():
				var target_id = str(selected[0])
				var target_instance = state.card_instances.get(target_id)
				if target_instance != null and str(target_instance.zone).begins_with("battle_"):
					var row = str(target_instance.position.get("row", ""))
					var col = int(target_instance.position.get("col", -1))
					if not row.is_empty() and col >= 0:
						events.append_array(ZoneActions.move_battlefield_to_grave(state, int(target_instance.controller), row, col, command_id, {
							"source_card_id": str(choice.get("context", {}).get("source_instance_id", "")),
							"source_kind": "effect"
						}))
		"olympus_reveal_hand_tactic_for_power":
			if not selected.is_empty():
				var selected_id = str(selected[0])
				var source_instance_id = str(choice.get("context", {}).get("source_instance_id", ""))
				events.append_array(_tianting_reveal_card(state, player_id, selected_id, "hand", command_id))
				if not source_instance_id.is_empty():
					events.append_array(_modify_power_until_turn_end(state, source_instance_id, int(choice.get("context", {}).get("amount", 1000)), command_id))
		"olympus_hannibal_pick_enemy_weaken":
			if not selected.is_empty():
				var source_instance_id = str(choice.get("context", {}).get("source_instance_id", ""))
				var ally_candidates: Array[String] = []
				for card_id in _get_battlefield_card_ids_for_player(state, player_id):
					var instance = state.card_instances.get(card_id)
					var definition = state.get_definition(instance.definition_id) if instance != null else null
					if definition == null or not definition.is_legion():
						continue
					ally_candidates.append(str(card_id))
				if not ally_candidates.is_empty():
					events.append_array(_request_candidate_cards_choice(state, player_id, ally_candidates, 1, "选择我方要-2000的军团", "olympus_hannibal_pick_ally_weaken", {
						"source_instance_id": source_instance_id,
						"enemy_target_id": str(selected[0]),
						"requires_confirm": true
					}, command_id))
		"olympus_hannibal_pick_ally_weaken":
			if not selected.is_empty():
				var enemy_target_id = str(choice.get("context", {}).get("enemy_target_id", ""))
				var ally_target_id = str(selected[0])
				if not enemy_target_id.is_empty():
					events.append_array(_modify_power_until_turn_end(state, enemy_target_id, -2000, command_id))
				if not ally_target_id.is_empty():
					events.append_array(_modify_power_until_turn_end(state, ally_target_id, -2000, command_id))
		"olympus_trojan_horse_choose_slot":
			pass
		"olympus_ready_after_kill_pick":
			if not selected.is_empty():
				var target_id = str(selected[0])
				var target_instance = state.card_instances.get(target_id)
				if target_instance != null and str(target_instance.zone).begins_with("battle_"):
					target_instance.flags["olympus_ready_after_kill_turn"] = state.turn_number
					target_instance.flags.erase("olympus_ready_after_kill_used")
					var ready_event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(target_instance.controller), {
						"card_id": target_id,
						"buff": "olympus_ready_after_kill"
					})
					ready_event.created_by_command = command_id
					state.event_log.append(ready_event)
					events.append(ready_event)
		"bijie_ready_after_kill_pick":
			if not selected.is_empty():
				var target_id = str(selected[0])
				var target_instance = state.card_instances.get(target_id)
				if target_instance != null and str(target_instance.zone).begins_with("battle_"):
					target_instance.flags["olympus_ready_after_kill_turn"] = state.turn_number
					target_instance.flags.erase("olympus_ready_after_kill_used")
					var ready_event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(target_instance.controller), {
						"card_id": target_id,
						"buff": "olympus_ready_after_kill"
					})
					ready_event.created_by_command = command_id
					state.event_log.append(ready_event)
					events.append(ready_event)
		"prepare_kill_grant_keyword_until_turn_end_pick":
			if not selected.is_empty():
				events.append_array(_set_kill_grant_keyword_until_turn_end(state, str(selected[0]), str(choice.get("context", {}).get("keyword", "")), command_id))
	return events

func _trigger_matches_self_only(event: GameEvent, card_id: String, effect: Dictionary = {}) -> bool:
	var payload = event.payload
	if not (payload is Dictionary):
		return false
	match str(event.type):
		"AttackDeclared", "AttackFinished":
			return str(payload.get("attacker_id", "")) == card_id
		"CardDied", "CardPlayed":
			if str(payload.get("card_id", "")) == card_id:
				return true
			if str(event.type) == "CardDied":
				var condition = effect.get("condition", {})
				if condition is Dictionary and bool(condition.get("source_card_id_is_self", false)):
					return str(payload.get("source_card_id", "")) == card_id
			return false
		"MasterDamaged", "MasterWouldBeDamaged":
			return str(payload.get("source_card_id", "")) == card_id
		_:
			return str(payload.get("card_id", "")) == card_id or str(payload.get("source_id", "")) == card_id

func _player_id_from_trigger_event(state: GameState, event_id: int, fallback_player_id: int) -> int:
	if event_id <= 0:
		return fallback_player_id
	for event in state.event_log:
		if int(event.event_id) == event_id:
			return int(event.player_id)
	return fallback_player_id

func _event_by_id(state: GameState, event_id: int):
	if event_id <= 0:
		return null
	for event in state.event_log:
		if int(event.event_id) == event_id:
			return event
	return null

func _normalize_selected_card_ids(raw_selected_card_ids) -> Array[String]:
	var result: Array[String] = []
	if not (raw_selected_card_ids is Array):
		return result
	for raw_card_id in raw_selected_card_ids:
		var card_id = str(raw_card_id)
		if card_id.is_empty():
			continue
		result.append(card_id)
	return result

func _sum_guard_card_power(state: GameState, guard_card_ids: Array[String]) -> int:
	var total := 0
	for card_id in guard_card_ids:
		total += max(1, get_card_power(state, card_id))
	return total

func _resolve_option_choice(state: GameState, choice: Dictionary, selected_option: String, command_id: String) -> Array:
	var player_id = int(choice.get("player_id", -1))
	var resolve_event = GameEvent.create(state.next_event_id(), "ChoiceResolved", player_id, {
		"choice_id": str(choice.get("choice_id", "")),
		"choice_type": str(choice.get("type", "")),
		"operation": str(choice.get("operation", "")),
		"title": str(choice.get("title", "")),
		"selected_option": selected_option
	})
	resolve_event.created_by_command = command_id
	state.event_log.append(resolve_event)
	var events: Array = [resolve_event]
	if str(choice.get("operation", "")) == "optional_stack_effect":
		if selected_option != "yes":
			return events
		var stack_item = choice.get("context", {}).get("stack_item", {})
		if not (stack_item is Dictionary) or stack_item.is_empty():
			return events
		var resolved_stack_item: Dictionary = stack_item.duplicate(true)
		resolved_stack_item["optional_choice_resolved"] = true
		var optional_cost = resolved_stack_item.get("cost", {})
		if optional_cost is Dictionary and not optional_cost.is_empty():
			var controller = int(resolved_stack_item.get("controller", state.active_player))
			var cost_result = _pay_effect_costs(state, controller, {"cost": optional_cost}, command_id, {"source_id": str(resolved_stack_item.get("source_instance_id", "")), "effect_id": str(resolved_stack_item.get("effect_id", ""))})
			events.append_array(cost_result.get("events", []))
			var paid_costs = cost_result.get("paid_costs", [])
			if paid_costs is Array and not paid_costs.is_empty():
				resolved_stack_item["paid_costs"].append_array(paid_costs)
		events.append_array(_resolve_stack_effect(state, resolved_stack_item, command_id))
		return events
	if str(choice.get("operation", "")) == "olympus_achilles_lethal_replace":
		if selected_option == "yes":
			events.append_array(_apply_olympus_achilles_lethal_replace(state, choice.get("context", {}), command_id))
		else:
			events.append_array(_resolve_pending_olympus_lethal_death(state, choice.get("context", {}), command_id))
		return events
	if str(choice.get("operation", "")) == "pre_stack_optional_attack_trigger":
		if selected_option != "yes":
			return events
		var stack_item = choice.get("context", {}).get("stack_item", {})
		if not (stack_item is Dictionary) or stack_item.is_empty():
			return events
		var resolved_stack_item: Dictionary = stack_item.duplicate(true)
		resolved_stack_item["optional_choice_resolved"] = true
		var cost = resolved_stack_item.get("cost", {})
		if cost is Dictionary and not cost.is_empty():
			var controller = int(resolved_stack_item.get("controller", state.active_player))
			var cost_result = _pay_effect_costs(state, controller, {"cost": cost}, command_id, {"source_id": str(resolved_stack_item.get("source_instance_id", "")), "effect_id": str(resolved_stack_item.get("effect_id", ""))})
			events.append_array(cost_result.get("events", []))
			var paid_costs = cost_result.get("paid_costs", [])
			if paid_costs is Array and not paid_costs.is_empty():
				resolved_stack_item["paid_costs"].append_array(paid_costs)
		events.append_array(_put_prebuilt_stack_item_on_stack(state, resolved_stack_item, command_id))
		return events
	if str(choice.get("operation", "")) == "valkyrie_first_turn_draw_replacement":
		if selected_option == "yes":
			events.append_array(DrawActions.mill_cards(state, player_id, 2, command_id))
		return events
	if str(choice.get("operation", "")) == "hand_response_deploy_to_front_and_redirect_pending_attack":
		var card_id = str(choice.get("context", {}).get("card_id", ""))
		var slot = _parse_slot_option(selected_option)
		if not card_id.is_empty() and not slot.is_empty():
			var hand_response_action = str(choice.get("context", {}).get("hand_response_action", "deploy_source_from_hand_to_front_and_redirect_pending_attack"))
			if hand_response_action == "suncity_siwa_hand_response":
				events.append_array(_suncity_siwa_hand_response(state, player_id, card_id, str(slot.get("row", "front")), int(slot.get("col", -1)), command_id))
			else:
				events.append_array(_deploy_hand_response_card_to_front_and_redirect_pending_attack(state, player_id, card_id, str(slot.get("row", "front")), int(slot.get("col", -1)), command_id))
		return events
	if str(choice.get("operation", "")) == "suncity_medjed_weaken_mode":
		var enemy_candidates_raw = choice.get("context", {}).get("enemy_candidates", [])
		var enemy_candidates: Array[String] = []
		if enemy_candidates_raw is Array:
			for raw_card_id in enemy_candidates_raw:
				var enemy_id = str(raw_card_id)
				if enemy_id.is_empty():
					continue
				if state.card_instances.get(enemy_id) == null:
					continue
				enemy_candidates.append(enemy_id)
		if enemy_candidates.is_empty():
			return events
		if selected_option != "empower":
			events.append_array(_request_candidate_cards_choice(state, player_id, enemy_candidates, 1, "选择对方1张军团本回合兵力-1000", "suncity_medjed_weaken_target", {
				"amount": -1000
			}, command_id))
			return events
		var guard_candidates_raw = choice.get("context", {}).get("active_tomb_guards", [])
		var guard_candidates: Array[String] = []
		if guard_candidates_raw is Array:
			for raw_card_id in guard_candidates_raw:
				var guard_id = str(raw_card_id)
				if guard_id.is_empty():
					continue
				var guard_instance = state.card_instances.get(guard_id)
				if guard_instance == null or str(guard_instance.orientation) != "active":
					continue
				guard_candidates.append(guard_id)
		if guard_candidates.is_empty():
			events.append_array(_request_candidate_cards_choice(state, player_id, enemy_candidates, 1, "选择对方1张军团本回合兵力-1000", "suncity_medjed_weaken_target", {
				"amount": -1000
			}, command_id))
			return events
		events.append_array(_request_candidate_cards_choice(state, player_id, guard_candidates, 1, "选择1张我方陵墓守卫休整", "suncity_medjed_rest_tomb_guard_for_weaken", {
			"enemy_candidates": enemy_candidates.duplicate()
		}, command_id))
		return events
	if str(choice.get("operation", "")) == "tsukuyomi_move_trigger":
		if selected_option != "yes":
			return events
		if MoraleActions.count_active_morale(state, player_id) < 1:
			return events
		events.append_array(MoraleActions.consume_morale(state, player_id, 1, command_id))
		_set_effect_used_this_turn(state, player_id, _master_source_id(player_id), "tsukuyomi_follow_move")
		var candidates_raw = choice.get("context", {}).get("candidate_card_ids", [])
		var candidates: Array[String] = []
		if candidates_raw is Array:
			for raw_card_id in candidates_raw:
				var candidate_id = str(raw_card_id)
				if candidate_id.is_empty():
					continue
				if _one_step_move_targets_for_effect(state, candidate_id).is_empty():
					continue
				candidates.append(candidate_id)
		if not candidates.is_empty():
			events.append_array(_request_candidate_cards_choice(state, player_id, candidates, 1, "选择月读要再次位移的军团", "tsukuyomi_choose_move_card", {}, command_id))
		return events
	if str(choice.get("operation", "")) == "takamagahara_morale_follow_move":
		if selected_option != "yes":
			return events
		var candidates_raw = choice.get("context", {}).get("candidate_card_ids", [])
		var candidates: Array[String] = []
		if candidates_raw is Array:
			for raw_card_id in candidates_raw:
				var candidate_id = str(raw_card_id)
				if candidate_id.is_empty():
					continue
				if _one_step_move_targets_for_effect(state, candidate_id).is_empty():
					continue
				candidates.append(candidate_id)
		if not candidates.is_empty():
			events.append_array(_request_candidate_cards_choice(state, player_id, candidates, 1, "选择1张活跃军团位移1格", "takamagahara_morale_choose_move_card", {}, command_id))
		return events
	if str(choice.get("operation", "")) == "bjorn_confirm_rested_revive":
		if selected_option != "yes":
			return events
		var source_id = str(choice.get("context", {}).get("source_instance_id", ""))
		if source_id.is_empty():
			return events
		var row := str(choice.get("context", {}).get("revive_row", ""))
		var col := int(choice.get("context", {}).get("revive_col", -1))
		if row.is_empty() or col < 0:
			return events
		events.append_array(_revive_bjorn_source_rested_to_slot(state, player_id, source_id, row, col, command_id))
		return events
	if str(choice.get("operation", "")) == "revive_selected_grave_to_slot":
		var card_id = str(choice.get("context", {}).get("card_id", ""))
		var slot = _parse_slot_option(selected_option)
		if not card_id.is_empty() and not slot.is_empty():
			if bool(choice.get("context", {}).get("rested", false)):
				events.append_array(_revive_bjorn_source_rested_to_slot(state, player_id, card_id, str(slot.get("row", "")), int(slot.get("col", -1)), command_id))
			else:
				events.append_array(_revive_grave_card_to_slot(state, player_id, card_id, str(slot.get("row", "")), int(slot.get("col", -1)), command_id))
		return events
	if str(choice.get("operation", "")) == "deploy_selected_hand_to_slot":
		var card_id = str(choice.get("context", {}).get("card_id", ""))
		var slot = _parse_slot_option(selected_option)
		if not card_id.is_empty() and not slot.is_empty():
			var deployment_orientation = str(choice.get("context", {}).get("deployment_orientation", "active"))
			events.append_array(_deploy_hand_card_to_slot_with_orientation(state, player_id, card_id, str(slot.get("row", "")), int(slot.get("col", -1)), deployment_orientation, command_id))
			events.append_array(_resolve_choice_follow_up_action(state, player_id, card_id, choice.get("context", {}).get("follow_up_action", {}), command_id))
		return events
	if str(choice.get("operation", "")) == "set_counter_tactic_from_hand_to_slot":
		var card_id = str(choice.get("context", {}).get("card_id", ""))
		var slot = _parse_slot_option(selected_option)
		if not card_id.is_empty() and str(slot.get("row", "")) == "back":
			events.append_array(_set_counter_tactic_from_hand_to_slot(state, player_id, card_id, int(slot.get("col", -1)), command_id))
			var remaining = choice.get("context", {}).get("remaining_card_ids", [])
			if remaining is Array and not remaining.is_empty():
				var remaining_ids: Array[String] = []
				for raw_card_id in remaining:
					remaining_ids.append(str(raw_card_id))
				events.append_array(_request_set_counter_tactic_slot_choice_for_cards(
					state,
					player_id,
					remaining_ids,
					command_id,
					choice.get("context", {}).get("follow_up_action", {}),
					str(choice.get("context", {}).get("source_instance_id", ""))
				))
			else:
				var follow_up_source_id := str(choice.get("context", {}).get("source_instance_id", ""))
				if follow_up_source_id.is_empty():
					follow_up_source_id = card_id
				events.append_array(_resolve_choice_follow_up_action(
					state,
					player_id,
					follow_up_source_id,
					choice.get("context", {}).get("follow_up_action", {}),
					command_id
				))
		return events
	if str(choice.get("operation", "")) == "sunwukong_deploy_fighter_to_slot":
		var slot = _parse_slot_option(selected_option)
		var amount = int(choice.get("context", {}).get("amount", 0))
		if not slot.is_empty() and amount >= 2 and amount <= 8:
			events.append_array(_sunwukong_deploy_fighter_to_slot(state, player_id, str(slot.get("row", "")), int(slot.get("col", -1)), amount, command_id))
		return events
	if str(choice.get("operation", "")) == "yangjian_choose_put_back_position":
		var card_id = str(choice.get("context", {}).get("card_id", ""))
		if not card_id.is_empty():
			if selected_option == "top":
				events.append_array(_move_hand_cards_to_deck_top(state, player_id, [card_id], command_id))
			elif selected_option == "bottom":
				events.append_array(_move_hand_cards_to_deck_bottom(state, player_id, [card_id], command_id))
		return events
	if str(choice.get("operation", "")) == "suncity_isis_reward":
		if selected_option == "draw":
			events.append_array(DrawActions.draw_cards(state, player_id, 1, command_id))
		elif selected_option == "heal":
			events.append_array(_heal_master(state, player_id, 1, command_id))
		return events
	if str(choice.get("operation", "")) == "suncity_prepare_discount_count":
		var count = int(selected_option)
		if count <= 0:
			return events
		var candidates = _get_battlefield_card_ids_for_player(state, player_id)
		if not candidates.is_empty():
			events.append_array(_request_candidate_cards_choice(state, player_id, candidates, min(count, candidates.size()), "选择要弃置的军团", "suncity_prepare_discount_units", {}, command_id))
		return events
	if str(choice.get("operation", "")) == "suncity_desert_discard_count":
		var desert_count = int(selected_option)
		if desert_count <= 0:
			return events
		var desert_candidates = _get_battlefield_card_ids_for_player(state, player_id)
		if not desert_candidates.is_empty():
			events.append_array(_request_candidate_cards_choice(state, player_id, desert_candidates, min(desert_count, desert_candidates.size()), "选择要弃置的军团", "suncity_desert_discard_units", {}, command_id))
		return events
	if str(choice.get("operation", "")) == "tianting_reorder_choose_destination":
		var selected_card_id = str(choice.get("context", {}).get("selected_card_id", ""))
		if selected_card_id.is_empty():
			return events
		var remaining_raw = choice.get("context", {}).get("remaining", [])
		var remaining_cards: Array[String] = []
		if remaining_raw is Array:
			for raw_card_id in remaining_raw:
				remaining_cards.append(str(raw_card_id))
		var top_cards_raw = choice.get("context", {}).get("top", [])
		var top_cards: Array[String] = []
		if top_cards_raw is Array:
			for raw_card_id in top_cards_raw:
				top_cards.append(str(raw_card_id))
		var bottom_cards_raw = choice.get("context", {}).get("bottom", [])
		var bottom_cards: Array[String] = []
		if bottom_cards_raw is Array:
			for raw_card_id in bottom_cards_raw:
				bottom_cards.append(str(raw_card_id))
		if selected_option == "top":
			top_cards.append(selected_card_id)
		elif selected_option == "bottom":
			bottom_cards.append(selected_card_id)
		events.append_array(_request_tianting_reorder_next_card(
			state,
			player_id,
			remaining_cards,
			top_cards,
			bottom_cards,
			str(choice.get("context", {}).get("source_instance_id", "")),
			choice.get("context", {}).get("follow_up_action", {}),
			command_id
		))
		return events
	if str(choice.get("operation", "")) == "tianting_zhugeliang_calamity_adjust":
		if selected_option == "plus":
			events.append_array(_adjust_calamity_value(state, 1, command_id))
		elif selected_option == "minus":
			events.append_array(_adjust_calamity_value(state, -1, command_id))
		return events
	if str(choice.get("operation", "")) == "move_selected_battlefield_card_to_slot":
		var moving_card_id = str(choice.get("context", {}).get("card_id", ""))
		var move_slot = _parse_slot_option(selected_option)
		if not moving_card_id.is_empty() and not move_slot.is_empty():
			events.append_array(_move_battlefield_card_to_slot_without_cost(state, moving_card_id, str(move_slot.get("row", "")), int(move_slot.get("col", -1)), command_id))
			var remaining = choice.get("context", {}).get("remaining_card_ids", [])
			if remaining is Array and not remaining.is_empty():
				var remaining_ids: Array[String] = []
				for raw_card_id in remaining:
					remaining_ids.append(str(raw_card_id))
				events.append_array(_request_move_slot_choice_for_cards(state, player_id, remaining_ids, command_id))
		return events
	if str(choice.get("operation", "")) == "tsukuyomi_choose_move_slot":
		var moving_card_id = str(choice.get("context", {}).get("card_id", ""))
		var move_slot = _parse_slot_option(selected_option)
		var move_options = choice.get("context", {}).get("move_options", [])
		if not moving_card_id.is_empty() and not move_slot.is_empty() and move_options is Array:
			events.append_array(_move_battlefield_card_to_slot_without_cost_for_options(state, moving_card_id, str(move_slot.get("row", "")), int(move_slot.get("col", -1)), move_options, command_id))
			events.append_array(_modify_cost_until_turn_end(state, moving_card_id, -1, command_id))
		return events
	if str(choice.get("operation", "")) == "takamagahara_morale_choose_move_slot":
		var moving_card_id = str(choice.get("context", {}).get("card_id", ""))
		var move_slot = _parse_slot_option(selected_option)
		var move_options = choice.get("context", {}).get("move_options", [])
		if not moving_card_id.is_empty() and not move_slot.is_empty() and move_options is Array:
			events.append_array(_move_battlefield_card_to_slot_without_cost_for_options(state, moving_card_id, str(move_slot.get("row", "")), int(move_slot.get("col", -1)), move_options, command_id))
		return events
	if str(choice.get("operation", "")) == "effect_move_source_slot":
		var moving_card_id = str(choice.get("context", {}).get("card_id", ""))
		var move_slot = _parse_slot_option(selected_option)
		var move_options = choice.get("context", {}).get("move_options", [])
		if not moving_card_id.is_empty() and not move_slot.is_empty() and move_options is Array:
			events.append_array(_move_battlefield_card_to_slot_without_cost_for_options(state, moving_card_id, str(move_slot.get("row", "")), int(move_slot.get("col", -1)), move_options, command_id))
		return events
	if str(choice.get("operation", "")) == "tianting_limu_reveal_top_tactic_choice":
		var revealed_card_id = str(choice.get("context", {}).get("card_id", ""))
		if revealed_card_id.is_empty():
			return events
		if selected_option == "play":
			events.append_array(_play_revealed_deck_card_without_cost(state, player_id, revealed_card_id, "", -1, command_id))
		elif selected_option == "bottom":
			var player = state.get_player(player_id)
			if not player.deck.cards.is_empty() and str(player.deck.cards[0]) == revealed_card_id:
				player.deck.remove_card(revealed_card_id)
				player.deck.cards.append(revealed_card_id)
		events.append_array(_resolve_choice_follow_up_action(state, player_id, str(choice.get("context", {}).get("source_instance_id", "")), choice.get("context", {}).get("follow_up_action", {}), command_id))
		return events
	if str(choice.get("operation", "")) == "tianting_lijing_choose_position_or_deploy":
		var revealed_card_id = str(choice.get("context", {}).get("card_id", ""))
		if revealed_card_id.is_empty():
			return events
		if selected_option == "bottom":
			var player = state.get_player(player_id)
			if not player.deck.cards.is_empty() and str(player.deck.cards[0]) == revealed_card_id:
				player.deck.remove_card(revealed_card_id)
				player.deck.cards.append(revealed_card_id)
			return events
		if selected_option == "deploy":
			if MoraleActions.count_spent_morale(state, player_id) < 1:
				return events
			events.append_array(MoraleActions.ready_spent_morale(state, player_id, 1, command_id))
			var slot_options = _battlefield_slot_options(state, player_id)
			if slot_options.is_empty():
				return events
			events.append_array(_request_option_choice(state, player_id, slot_options, "选择登场位置", "tianting_lijing_deploy_to_slot", {
				"card_id": revealed_card_id
			}, command_id))
		return events
	if str(choice.get("operation", "")) == "tianting_lijing_deploy_to_slot":
		var revealed_card_id = str(choice.get("context", {}).get("card_id", ""))
		var slot = _parse_slot_option(selected_option)
		if not revealed_card_id.is_empty() and not slot.is_empty():
			events.append_array(_play_revealed_legion_to_slot_without_cost(state, player_id, revealed_card_id, str(slot.get("row", "")), int(slot.get("col", -1)), command_id))
		return events
	if str(choice.get("operation", "")) == "revealed_top_card_play_or_hand":
		var revealed_card_id = str(choice.get("context", {}).get("card_id", ""))
		if revealed_card_id.is_empty():
			return events
		if selected_option == "hand":
			events.append_array(_move_top_deck_card_to_hand(state, player_id, command_id))
			return events
		var revealed_instance = state.card_instances.get(revealed_card_id)
		if revealed_instance == null:
			return events
		var revealed_definition = state.get_definition(revealed_instance.definition_id)
		if revealed_definition == null:
			return events
		if revealed_definition.is_legion():
			var slot_options = _battlefield_slot_options(state, player_id)
			if slot_options.is_empty():
				events.append_array(_move_top_deck_card_to_hand(state, player_id, command_id))
				return events
			events.append_array(_request_option_choice(state, player_id, slot_options, "选择无消耗打出位置", "play_revealed_deck_card_to_slot", {
				"card_id": revealed_card_id
			}, command_id))
			return events
		if revealed_definition.is_counter_tactic():
			var back_slot_options = _back_battlefield_slot_options(state, player_id)
			if back_slot_options.is_empty():
				events.append_array(_move_top_deck_card_to_hand(state, player_id, command_id))
				return events
			events.append_array(_request_option_choice(state, player_id, back_slot_options, "选择无消耗置入后排的位置", "set_revealed_deck_counter_to_slot", {
				"card_id": revealed_card_id
			}, command_id))
			return events
		events.append_array(_play_revealed_deck_card_without_cost(state, player_id, revealed_card_id, "", -1, command_id))
		return events
	if str(choice.get("operation", "")) == "play_revealed_deck_card_to_slot":
		var revealed_play_card_id = str(choice.get("context", {}).get("card_id", ""))
		var revealed_play_slot = _parse_slot_option(selected_option)
		if not revealed_play_card_id.is_empty() and not revealed_play_slot.is_empty():
			events.append_array(_play_revealed_deck_card_without_cost(state, player_id, revealed_play_card_id, str(revealed_play_slot.get("row", "")), int(revealed_play_slot.get("col", -1)), command_id))
		return events
	if str(choice.get("operation", "")) == "set_revealed_deck_counter_to_slot":
		var revealed_counter_card_id = str(choice.get("context", {}).get("card_id", ""))
		var revealed_counter_slot = _parse_slot_option(selected_option)
		if not revealed_counter_card_id.is_empty() and not revealed_counter_slot.is_empty():
			events.append_array(_play_revealed_deck_card_without_cost(state, player_id, revealed_counter_card_id, str(revealed_counter_slot.get("row", "")), int(revealed_counter_slot.get("col", -1)), command_id))
		return events
	if str(choice.get("operation", "")) == "frontline_scout_confirm_enemy_hand":
		events.append_array(_resolve_choice_follow_up_action(
			state,
			player_id,
			str(choice.get("context", {}).get("source_instance_id", "")),
			choice.get("context", {}).get("follow_up_action", {}),
			command_id
		))
		return events
	if str(choice.get("operation", "")) == "suncity_codex_force_discard_or_counter":
		var target_stack_id = str(choice.get("context", {}).get("target_stack_id", ""))
		var reward_player = int(choice.get("context", {}).get("reward_player", 1 - player_id))
		var source_instance_id = str(choice.get("context", {}).get("source_instance_id", ""))
		if selected_option == "discard":
			return _request_hand_discard_choice_from_resolution(state, {
				"controller": reward_player,
				"source_instance_id": source_instance_id,
				"resolution": {
					"player_id": player_id,
					"discard_count": 1,
					"title": "选择1张手牌弃置，否则本次效果无效",
					"follow_up_action": {
						"action": "suncity_codex_mark_reward",
						"target_stack_id": target_stack_id,
						"reward_player": reward_player,
						"source_instance_id": source_instance_id
					}
				}
			}, command_id)
		return _counter_target_stack_item(state, {
			"controller": reward_player,
			"source_instance_id": source_instance_id,
			"targets": {"target_stack_id": target_stack_id}
		}, command_id)
	if str(choice.get("operation", "")) == "deploy_selected_hand_or_grave_to_slot":
		var card_id = str(choice.get("context", {}).get("card_id", ""))
		var from_zone = str(choice.get("context", {}).get("from_zone", ""))
		var slot = _parse_slot_option(selected_option)
		if card_id.is_empty() or slot.is_empty():
			return events
		if from_zone == "hand":
			events.append_array(_deploy_hand_card_to_slot(state, player_id, card_id, str(slot.get("row", "")), int(slot.get("col", -1)), command_id))
		elif from_zone == "grave":
			events.append_array(_revive_grave_card_to_slot(state, player_id, card_id, str(slot.get("row", "")), int(slot.get("col", -1)), command_id))
		elif from_zone == "deck":
			events.append_array(_deploy_deck_card_to_slot(state, player_id, card_id, str(slot.get("row", "")), int(slot.get("col", -1)), command_id))
		events.append_array(_resolve_choice_follow_up_action(state, player_id, card_id, choice.get("context", {}).get("follow_up_action", {}), command_id))
		return events
	if str(choice.get("operation", "")) == "brynhildr_choose_sigurd_source":
		var context = choice.get("context", {})
		var hand_candidates = context.get("hand_candidate_ids", []).duplicate()
		var grave_candidates = context.get("grave_candidate_ids", []).duplicate()
		var slot_options = context.get("slot_options", []).duplicate()
		if selected_option == "hand":
			return _request_brynhildr_sigurd_from_hand_choice(state, player_id, hand_candidates, slot_options, command_id)
		if selected_option == "grave":
			return _request_brynhildr_sigurd_from_grave_choice(state, player_id, grave_candidates, context.get("grave_display_ids", []).duplicate(), command_id)
		return events
	if str(choice.get("operation", "")) == "olympus_trojan_horse_choose_slot":
		var source_instance_id = str(choice.get("context", {}).get("source_instance_id", ""))
		var host_player = int(choice.get("context", {}).get("host_player", 1 - player_id))
		var slot = _parse_slot_option(selected_option)
		if not source_instance_id.is_empty() and not slot.is_empty():
			events.append_array(_deploy_stack_pending_counter_to_foreign_battlefield(state, source_instance_id, player_id, host_player, str(slot.get("row", "")), int(slot.get("col", -1)), command_id))
		return events
	if str(choice.get("operation", "")) == "olympus_artemis_choose_keyword":
		var target_card_id = str(choice.get("context", {}).get("card_id", ""))
		if target_card_id.is_empty():
			return events
		var target_instance = state.card_instances.get(target_card_id)
		if target_instance == null:
			return events
		target_instance.flags["temporary_keyword_%s_turn" % selected_option] = state.turn_number
		var keyword_event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(target_instance.controller), {
			"card_id": target_card_id,
			"buff": "temporary_keyword",
			"keyword": selected_option
		})
		keyword_event.created_by_command = command_id
		state.event_log.append(keyword_event)
		events.append(keyword_event)
		return events
	if str(choice.get("operation", "")) == "dark_morning_star_main_effect":
		state.get_player(player_id).flags["dark_morning_star_effect"] = {
			"turn": state.turn_number,
			"effect": selected_option
		}
		return events
	if str(choice.get("operation", "")) == "manifest_kusanagi_to_slot":
		var slot = _parse_slot_option(selected_option)
		var card_id = _find_owned_card_by_definition(state, player_id, "takamagahara_s01_0417")
		if not card_id.is_empty() and not slot.is_empty():
			events.append_array(_manifest_kusanagi_to_slot(state, player_id, card_id, str(slot.get("row", "")), int(slot.get("col", -1)), command_id))
		return events
	if str(choice.get("operation", "")) == "kusanagi_leave_to_top_choice":
		var context = choice.get("context", {})
		var target_player = int(context.get("player_id", player_id))
		var row = str(context.get("row", ""))
		var col = int(context.get("col", -1))
		if row.is_empty() or col < 0:
			return events
		if selected_option == "yes":
			events.append_array(ZoneActions.return_battlefield_to_deck_top(state, target_player, row, col, command_id))
			return events
		var battle_options: Dictionary = context.get("battle_options", {}).duplicate(true) if context.get("battle_options", {}) is Dictionary else {}
		battle_options["skip_kusanagi_leave_choice"] = true
		match str(context.get("fallback_action", "grave")):
			"hand":
				events.append_array(ZoneActions.return_battlefield_to_hand(state, target_player, row, col, command_id, battle_options))
			"deck_bottom":
				events.append_array(ZoneActions.return_battlefield_to_deck_bottom(state, target_player, row, col, command_id, battle_options))
			_:
				events.append_array(ZoneActions.move_battlefield_to_grave(state, target_player, row, col, command_id, battle_options))
		return events
	if str(choice.get("operation", "")) == "truce_offer" and selected_option == "agree":
		var initiator = int(choice.get("context", {}).get("initiator_player", 1 - player_id))
		var source_instance_id = str(choice.get("context", {}).get("source_instance_id", ""))
		var initiator_event_options := {"source_kind": "effect", "source_player_id": initiator}
		var opponent_event_options := {"source_kind": "effect", "source_player_id": initiator}
		if not source_instance_id.is_empty():
			initiator_event_options["source_card_id"] = source_instance_id
			opponent_event_options["source_card_id"] = source_instance_id
		events.append_array(DrawActions.draw_cards(state, initiator, 1, command_id, initiator_event_options))
		events.append_array(DrawActions.draw_cards(state, player_id, 1, command_id, opponent_event_options))
	if str(choice.get("operation", "")) == "prayer_reveal_offer":
		var initiator = int(choice.get("context", {}).get("initiator_player", 1 - player_id))
		var source_instance_id = str(choice.get("context", {}).get("source_instance_id", ""))
		if selected_option == "agree":
			var reveal_stack_item = {
				"controller": initiator,
				"source_instance_id": source_instance_id,
				"resolution": {
					"action": "preview_next_calamity",
					"audience": "all",
					"title": "祷告仪式：公开下一张待开启的天灾卡"
				}
			}
			events.append_array(_resolve_stack_follow_up_action(state, reveal_stack_item, reveal_stack_item.get("resolution", {}), command_id))
			return events
		events.append_array(_request_option_with_shared_cost(state, initiator, {
			"title": "对方不同意，是否消耗1士气查看下1张待开启的天灾卡？",
			"optional": true,
			"cost": {
				"morale": 1
			},
			"options": [
				{
					"id": "preview",
					"label": "消耗1士气查看",
					"resolution": {
						"action": "preview_next_calamity",
						"audience": "controller",
						"title": "祷告仪式：查看下一张待开启的天灾卡"
					}
				}
			]
		}, command_id, source_instance_id))
		return events
	if str(choice.get("operation", "")) == "resolve_option_with_shared_cost":
		var deferred_source_id := str(choice.get("context", {}).get("source_instance_id", ""))
		if selected_option == "skip":
			events.append_array(_cleanup_deferred_stack_pending_source_if_needed(state, deferred_source_id, command_id))
			return events
		var option_payloads = choice.get("context", {}).get("option_payloads", {})
		if not (option_payloads is Dictionary):
			events.append_array(_cleanup_deferred_stack_pending_source_if_needed(state, deferred_source_id, command_id))
			return events
		var option_payload = option_payloads.get(selected_option, {})
		if not (option_payload is Dictionary):
			events.append_array(_cleanup_deferred_stack_pending_source_if_needed(state, deferred_source_id, command_id))
			return events
		var shared_cost = choice.get("context", {}).get("shared_cost", {})
		if shared_cost is Dictionary and not shared_cost.is_empty():
			var shared_cost_effect = {"cost": shared_cost.duplicate(true)}
			var shared_cost_check = _validate_effect_cost(state, player_id, shared_cost_effect)
			if not shared_cost_check.get("ok", false):
				events.append_array(_cleanup_deferred_stack_pending_source_if_needed(state, deferred_source_id, command_id))
				return events
			events.append_array(_pay_effect_costs(state, player_id, shared_cost_effect, command_id).get("events", []))
		var option_cost = option_payload.get("cost", {})
		if option_cost is Dictionary and not option_cost.is_empty():
			var option_cost_effect = {"cost": option_cost.duplicate(true)}
			var option_cost_check = _validate_effect_cost(state, player_id, option_cost_effect)
			if not option_cost_check.get("ok", false):
				events.append_array(_cleanup_deferred_stack_pending_source_if_needed(state, deferred_source_id, command_id))
				return events
			events.append_array(_pay_effect_costs(state, player_id, option_cost_effect, command_id).get("events", []))
		var resolution = option_payload.get("resolution", {})
		if resolution is Dictionary and not resolution.is_empty():
			var follow_up_stack_item = {
				"controller": player_id,
				"source_instance_id": str(choice.get("context", {}).get("source_instance_id", "")),
				"resolution": resolution.duplicate(true)
			}
			events.append_array(_resolve_stack_follow_up_action(state, follow_up_stack_item, resolution, command_id))
		events.append_array(_cleanup_deferred_stack_pending_source_if_needed(state, deferred_source_id, command_id))
		return events
	if str(choice.get("operation", "")) == "choose_rune_payment_for_source_attack_bonus":
		var rune_count = int(selected_option)
		if rune_count <= 0 or _player_rune_count(state, player_id) < rune_count:
			return events
		events.append_array(_consume_player_runes(state, player_id, rune_count, command_id))
		var source_id = str(choice.get("context", {}).get("source_instance_id", ""))
		if source_id.is_empty():
			return events
		var power_per_rune = int(choice.get("context", {}).get("power_per_rune", 0))
		if power_per_rune != 0:
			events.append_array(_modify_source_power_until_turn_end(state, {
				"source_instance_id": source_id,
				"resolution": {
					"amount": rune_count * power_per_rune
				}
			}, command_id))
		var master_damage_per_rune = int(choice.get("context", {}).get("master_damage_per_rune", 0))
		if master_damage_per_rune != 0:
			events.append_array(_grant_master_damage_bonus(state, {
				"source_instance_id": source_id,
				"targets": {
					"target_card_id": source_id
				},
				"resolution": {
					"amount": rune_count * master_damage_per_rune
				}
			}, command_id))
		return events
	if str(choice.get("operation", "")) == "bijie_reveal_top_bijie_or_reorder":
		var card_id = str(choice.get("context", {}).get("card_id", ""))
		if card_id.is_empty():
			return events
		if selected_option == "hand":
			events.append_array(_move_top_deck_card_to_hand(state, player_id, command_id))
			return events
		if selected_option == "bottom":
			var player = state.get_player(player_id)
			if not player.deck.cards.is_empty() and str(player.deck.cards[0]) == card_id:
				player.deck.remove_card(card_id)
				player.deck.cards.append(card_id)
		return events
	if str(choice.get("operation", "")) == "pride_sin_resolution":
		var difference := int(choice.get("context", {}).get("difference", 0))
		if difference <= 0:
			return events
		if selected_option == "discard_battlefield":
			var candidates: Array[String] = _get_battlefield_card_ids_for_player(state, player_id)
			if candidates.is_empty():
				return events
			events.append_array(_request_candidate_cards_choice(
				state,
				player_id,
				candidates,
				min(difference, candidates.size()),
				"傲慢之罪：选择要弃置的军团",
				"destroy_battlefield_card",
				{"battle_options": choice.get("context", {}).get("event_options", {}).duplicate(true) if choice.get("context", {}).get("event_options", {}) is Dictionary else {}},
				command_id
			))
			return events
		if selected_option == "discard_hand":
			events.append_array(_request_hand_discard_choice_from_resolution(state, {
				"controller": player_id,
				"resolution": {
					"action": "request_hand_discard_choice",
					"player_id": player_id,
					"event_options": choice.get("context", {}).get("event_options", {}).duplicate(true) if choice.get("context", {}).get("event_options", {}) is Dictionary else {},
					"discard_count": difference,
					"requires_confirm": true,
					"title": "傲慢之罪：选择手牌弃置",
					"hint_text": "傲慢之罪：请选择并确认弃置与战场军团数量差相同的手牌。",
					"top_hint_text": "傲慢之罪：请选择并确认要弃置的手牌。"
				}
			}, command_id))
	return events

func _resolve_stack_follow_up_action(state: GameState, stack_item: Dictionary, follow_up_action, command_id: String) -> Array:
	if not (follow_up_action is Dictionary) or follow_up_action.is_empty():
		return []
	var controller = int(stack_item.get("controller", state.active_player))
	var min_own_grave_cards = int(follow_up_action.get("min_own_grave_cards", 0))
	if min_own_grave_cards > 0 and state.get_player(controller).grave.cards.size() < min_own_grave_cards:
		return []
	var follow_up_stack_item = stack_item.duplicate(true)
	if not bool(follow_up_action.get("use_existing_targets", false)):
		follow_up_stack_item.erase("targets")
	follow_up_stack_item["resolution"] = follow_up_action.duplicate(true)
	return _resolve_stack_effect(state, follow_up_stack_item, command_id)


func _can_offer_optional_stack_effect_choice(state: GameState, stack_item: Dictionary) -> bool:
	var resolution = stack_item.get("resolution", {})
	if not (resolution is Dictionary):
		return false
	var action = str(resolution.get("action", ""))
	match action:
		"draw_cards":
			var controller = int(stack_item.get("controller", state.active_player))
			var count = int(resolution.get("count", 1))
			return state.get_player(controller).deck.cards.size() >= count
		"recycle_grave_to_deck":
			var controller = int(stack_item.get("controller", state.active_player))
			var count = int(resolution.get("count", 1))
			if not bool(resolution.get("require_exact_count", false)):
				return not _matching_grave_card_ids(state, controller, resolution).is_empty()
			return _matching_grave_card_ids(state, controller, resolution).size() >= count
		"recycle_grave_then_revive_source_from_grave":
			var revive_controller = int(stack_item.get("controller", state.active_player))
			var source_id := str(stack_item.get("source_instance_id", ""))
			var revive_count = int(resolution.get("count", 1))
			if source_id.is_empty() or not state.get_player(revive_controller).grave.cards.has(source_id):
				return false
			return _matching_grave_card_ids(state, revive_controller, {
				"exclude_card_id": source_id
			}).size() >= revive_count
		"recycle_grave_then_revive_thor_hammer_from_grave":
			var thor_controller = int(stack_item.get("controller", state.active_player))
			var hammer_candidates = _matching_definition_card_ids(state, state.get_player(thor_controller).grave.cards, "asgard_s02_0301")
			if hammer_candidates.is_empty():
				return false
			return _matching_grave_card_ids(state, thor_controller, {
				"exclude_card_id": str(hammer_candidates[0])
			}).size() >= int(resolution.get("count", 3))
		"bjorn_recycle_and_maybe_rested_revive":
			var bjorn_controller = int(stack_item.get("controller", state.active_player))
			var bjorn_source_id := str(stack_item.get("source_instance_id", ""))
			var bjorn_count = int(resolution.get("count", 4))
			if bjorn_source_id.is_empty():
				return false
			if _matching_grave_card_ids(state, bjorn_controller, {
				"exclude_card_id": bjorn_source_id
			}).size() < bjorn_count:
				return false
			return not _bjorn_rested_revive_slot_from_trigger(state, bjorn_controller, stack_item).is_empty()
		"return_source_to_deck_top":
			var source_id := str(stack_item.get("source_instance_id", ""))
			var instance = state.card_instances.get(source_id)
			return instance != null and str(instance.zone).begins_with("battle_")
		_:
			return true

func _auto_pass_empty_pending_attack_response_window(state: GameState, command_id: String) -> Array:
	if state.pending_attack.is_empty():
		return []
	if not state.stack.is_empty() or not state.pending_choices.is_empty() or not state.pending_triggers.is_empty():
		return []
	if not bool(state.pending_attack.get("response_window_opened", false)):
		return []
	var events: Array = []
	var guard := 0
	while guard < 4 and not state.pending_attack.is_empty() and state.stack.is_empty() and state.pending_choices.is_empty() and state.pending_triggers.is_empty():
		guard += 1
		if _pending_attack_priority_player_has_non_pass_action(state):
			break
		var pass_player := int(state.priority_player)
		if pass_player < 0:
			break
		var pass_event = GameEvent.create(state.next_event_id(), "PriorityPassed", pass_player, {
			"stack_size": state.stack.size(),
			"pending_attack": not state.pending_attack.is_empty(),
			"auto": true,
			"reason": "empty_pending_attack_response_after_choice"
		})
		pass_event.created_by_command = command_id
		state.event_log.append(pass_event)
		events.append(pass_event)
		if state.priority_pass_count == 0:
			state.priority_pass_count = 1
			state.priority_player = 1 - pass_player
			continue
		state.priority_pass_count = 0
		state.priority_player = state.active_player
		events.append_array(_resolve_pending_attack_if_ready(state, command_id))
	return events

func _pending_attack_priority_player_has_non_pass_action(state: GameState) -> bool:
	if state.pending_attack.is_empty():
		return false
	var player_id := int(state.priority_player)
	if player_id < 0:
		return false
	for action in get_legal_actions(state, player_id):
		if str(action.get("kind", "")) != "pass_priority":
			return true
	return false

func _resolve_pending_attack_if_ready(state: GameState, command_id: String) -> Array:
	if state.pending_attack.is_empty():
		return []
	if not state.stack.is_empty() or not state.pending_choices.is_empty() or not state.pending_triggers.is_empty():
		return []
	var attack = state.pending_attack.duplicate(true)
	if not bool(attack.get("response_window_opened", false)):
		attack["response_window_opened"] = true
		state.pending_attack = attack
		state.priority_player = 1 - state.active_player
		state.priority_pass_count = 0
		return []
	state.pending_attack.clear()
	var attacker_id = str(attack.get("attacker_id", ""))
	var target_kind = str(attack.get("target_kind", "card"))
	var target_player = int(attack.get("target_player", -1))
	var defender_id = str(attack.get("defender_id", ""))
	var blocker_id = str(attack.get("blocker_id", ""))
	var supporter_id = str(attack.get("supporter_id", ""))
	var extra_discard_card_id = str(attack.get("extra_discard_card_id", ""))
	var master_guard_card_ids = _payload_string_array(attack.get("master_guard_card_ids", []))
	var attacker = state.card_instances.get(attacker_id)
	if attacker == null or not attacker.zone.begins_with("battle_"):
		return []
	attacker.flags["is_attacking_now"] = true
	var thunder_result := _maybe_resolve_thunder_wrath_attack_roll(state, attack, int(attacker.controller), command_id)
	attack = thunder_result.get("attack", attack)
	if bool(thunder_result.get("canceled", false)):
		attacker.flags.erase("is_attacking_now")
		return thunder_result.get("events", [])
	var events: Array = thunder_result.get("events", [])
	if not blocker_id.is_empty():
		if not extra_discard_card_id.is_empty():
			events.append_array(ZoneActions.discard_specific_from_hand(
				state,
				1 - int(attacker.controller),
				[extra_discard_card_id],
				command_id,
				_effect_event_source_options(str(attack.get("extra_defense_discard_source_id", "")))
			))
		var blocker = state.card_instances.get(blocker_id)
		if blocker == null or not str(blocker.zone).begins_with("battle_"):
			events.append_array(_consume_attack_attempt(state, attacker_id, command_id))
			attack["canceled_by_invalid_state"] = true
			attacker.flags.erase("is_attacking_now")
			events.append(_create_attack_finished_event(state, attack, command_id))
			return events
		var blocked_events = _resolve_block(state, attacker_id, blocker_id, command_id)
		attacker.flags.erase("is_attacking_now")
		blocked_events.append(_create_attack_finished_event(state, attack, command_id))
		return events + blocked_events
	if not master_guard_card_ids.is_empty() and target_kind == "master":
		if bool(attack.get("extra_defense_discard_required", false)):
			attacker.flags.erase("is_attacking_now")
			events.append_array(_deal_master_damage_from_attacker(state, attacker_id, target_player, command_id))
			events.append(_create_attack_finished_event(state, attack, command_id))
			return events
		var guard_events = _resolve_master_guard(state, attacker_id, target_player, master_guard_card_ids, command_id)
		attacker.flags.erase("is_attacking_now")
		guard_events.append(_create_attack_finished_event(state, attack, command_id))
		return events + guard_events
	if target_kind == "master":
		var master_events = _deal_master_damage_from_attacker(state, attacker_id, target_player, command_id)
		attacker.flags.erase("is_attacking_now")
		master_events.append(_create_attack_finished_event(state, attack, command_id))
		return events + master_events
	var defender = state.card_instances.get(defender_id)
	if defender == null or not defender.zone.begins_with("battle_"):
		events.append_array(_consume_attack_attempt(state, attacker_id, command_id))
		attack["canceled_by_invalid_state"] = true
		attacker.flags.erase("is_attacking_now")
		events.append(_create_attack_finished_event(state, attack, command_id))
		return events
	if not supporter_id.is_empty():
		if not get_legal_supporters(state, defender_id, attacker_id).has(supporter_id):
			attack.erase("supporter_id")
			attack.erase("extra_discard_card_id")
			supporter_id = ""
			extra_discard_card_id = ""
		else:
			if not extra_discard_card_id.is_empty():
				events.append_array(ZoneActions.discard_specific_from_hand(
					state,
					int(defender.controller),
					[extra_discard_card_id],
					command_id,
					_effect_event_source_options(str(attack.get("extra_defense_discard_source_id", "")))
				))
			var support_event = GameEvent.create(state.next_event_id(), "SupportDeclared", 1 - int(attacker.controller), {
				"defender_id": defender_id,
				"supporter_id": supporter_id,
				"attacker_id": attacker_id
			})
			support_event.created_by_command = command_id
			state.event_log.append(support_event)
			events.append(support_event)
			var support_instance = state.card_instances.get(supporter_id)
			if support_instance != null and support_instance.zone.begins_with("battle_"):
				var support_row := str(support_instance.position.get("row", ""))
				var support_col := int(support_instance.position.get("col", -1))
				if not support_row.is_empty() and support_col >= 0:
					events.append_array(ZoneActions.move_battlefield_to_grave(state, support_instance.controller, support_row, support_col, command_id))
			events.append_array(_consume_attack_attempt(state, attacker_id, command_id))
			attacker.flags.erase("is_attacking_now")
			var prevented_event = GameEvent.create(state.next_event_id(), "SupportPreventedDeath", int(defender.controller), {
				"defender_id": defender_id,
				"supporter_id": supporter_id,
				"attacker_id": attacker_id
			})
			prevented_event.created_by_command = command_id
			state.event_log.append(prevented_event)
			events.append(prevented_event)
			events.append(_create_attack_finished_event(state, attack, command_id))
			return events
	events.append_array(CombatActions.resolve_simple_attack(state, attacker_id, defender_id, command_id, {
		"attacker_takes_no_damage": _attacker_ignores_combat_damage(state, attacker_id, defender_id),
		"attacker_power_modifier": _combat_attacker_power_modifier(state, attacker_id, defender_id)
	}))
	events.append_array(_resolve_pierce_after_combat(state, attacker_id, defender_id, int(defender.controller), command_id, events))
	attacker.flags.erase("is_attacking_now")
	events.append(_create_attack_finished_event(state, attack, command_id))
	return events

func _create_attack_finished_event(state: GameState, attack: Dictionary, command_id: String) -> GameEvent:
	var payload = attack.duplicate(true)
	var attacker_id = str(payload.get("attacker_id", ""))
	if not attacker_id.is_empty():
		var attacker = state.card_instances.get(attacker_id)
		if attacker != null:
			payload["attacker_zone"] = str(attacker.zone)
	return _append_logged_event(state, "AttackFinished", int(payload.get("target_player", state.active_player)), payload, command_id)

func _combat_attacker_power_modifier(state: GameState, attacker_id: String, defender_id: String) -> int:
	var modifier := 0
	if _has_attack_keyword(state, defender_id, "reduce_ranged_attack_power_1000") and _has_ranged_attack(state, attacker_id):
		modifier -= 1000
	return modifier

func _resolve_pierce_after_combat(state: GameState, attacker_id: String, defender_id: String, target_player: int, command_id: String, combat_events: Array) -> Array:
	if not _has_attack_keyword(state, attacker_id, "pierce"):
		return []
	var attacker = state.card_instances.get(attacker_id)
	if attacker == null or not attacker.zone.begins_with("battle_"):
		return []
	if get_card_power(state, attacker_id) <= 0:
		return []
	var killed_defender := false
	for event in combat_events:
		if not (event is GameEvent):
			continue
		if str(event.type) != "CardDied":
			continue
		var payload = event.payload
		if not (payload is Dictionary):
			continue
		if str(payload.get("card_id", "")) != defender_id:
			continue
		if str(payload.get("source_card_id", "")) != attacker_id:
			continue
		if str(payload.get("source_kind", "")) != "attack":
			continue
		killed_defender = true
		break
	if not killed_defender:
		return []
	var events: Array = []
	events.append(_append_logged_event(state, "PierceTriggered", int(attacker.controller), {
		"attacker_id": attacker_id,
		"target_player": target_player,
		"remaining_power": get_card_power(state, attacker_id)
	}, command_id))
	events.append_array(_deal_master_damage_from_attacker(state, attacker_id, target_player, command_id))
	return events

func _append_logged_event(state: GameState, event_type: String, player_id: int, payload: Dictionary, command_id: String) -> GameEvent:
	var event = GameEvent.create(state.next_event_id(), event_type, player_id, payload)
	event.created_by_command = command_id
	state.event_log.append(event)
	return event

func _matching_grave_card_ids(state: GameState, player_id: int, filters: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var player = state.get_player(player_id)
	var excluded_card_id = str(filters.get("exclude_card_id", ""))
	var excluded_definition_id = str(filters.get("exclude_definition_id", ""))
	for card_id in player.grave.cards:
		if not excluded_card_id.is_empty() and card_id == excluded_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		if not excluded_definition_id.is_empty() and str(definition.id) == excluded_definition_id:
			continue
		var required_type = str(filters.get("type", ""))
		if not required_type.is_empty() and definition.type != required_type:
			continue
		var required_faction = str(filters.get("faction", ""))
		if not _definition_matches_required_faction_for_player(state, player_id, definition, required_faction):
			continue
		var required_definition_id = str(filters.get("id", ""))
		if not required_definition_id.is_empty() and str(definition.id) != required_definition_id:
			continue
		var name_contains = str(filters.get("name_contains", ""))
		if not name_contains.is_empty() and not _definition_name_contains(definition, name_contains):
			continue
		var required_trait = str(filters.get("trait", filters.get("required_trait", "")))
		if not required_trait.is_empty() and not definition.traits.has(required_trait):
			continue
		var min_target_cost = int(filters.get("min_target_cost", -1))
		if min_target_cost >= 0 and int(definition.cost) < min_target_cost:
			continue
		var max_target_cost = int(filters.get("max_target_cost", -1))
		if max_target_cost >= 0 and int(definition.cost) > max_target_cost:
			continue
		result.append(card_id)
	return result

func _matching_hand_card_ids(state: GameState, player_id: int, filters: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var player = state.get_player(player_id)
	for card_id in player.hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		var required_type = str(filters.get("type", ""))
		if not required_type.is_empty() and definition.type != required_type:
			continue
		var required_definition_id = str(filters.get("id", ""))
		if not required_definition_id.is_empty() and definition.id != required_definition_id:
			continue
		var name_contains = str(filters.get("name_contains", ""))
		if not name_contains.is_empty() and not _definition_name_contains(definition, name_contains):
			continue
		var required_faction = str(filters.get("faction", ""))
		if not _definition_matches_required_faction_for_player(state, player_id, definition, required_faction):
			continue
		var required_trait = str(filters.get("trait", filters.get("required_trait", "")))
		if not required_trait.is_empty() and not definition.traits.has(required_trait):
			continue
		var required_calamity_level = int(filters.get("calamity_level", -1))
		if required_calamity_level >= 0 and int(definition.calamity_level) != required_calamity_level:
			continue
		var min_target_cost = int(filters.get("min_target_cost", -1))
		if min_target_cost >= 0 and int(definition.cost) < min_target_cost:
			continue
		var max_target_cost = int(filters.get("max_target_cost", -1))
		if max_target_cost >= 0 and int(definition.cost) > max_target_cost:
			continue
		var max_target_power = int(filters.get("max_target_power", filters.get("max_power", -1)))
		if max_target_power >= 0 and int(definition.power) > max_target_power:
			continue
		result.append(card_id)
	return result

func _matching_deck_card_ids(state: GameState, player_id: int, filters: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var player = state.get_player(player_id)
	for card_id in player.deck.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		var required_type = str(filters.get("type", ""))
		if not required_type.is_empty() and definition.type != required_type:
			continue
		var required_definition_id = str(filters.get("id", ""))
		if not required_definition_id.is_empty() and str(definition.id) != required_definition_id:
			continue
		var name_contains = str(filters.get("name_contains", ""))
		if not name_contains.is_empty() and not _definition_name_contains(definition, name_contains):
			continue
		var required_faction = str(filters.get("faction", ""))
		if not _definition_matches_required_faction_for_player(state, player_id, definition, required_faction):
			continue
		var required_trait = str(filters.get("trait", filters.get("required_trait", "")))
		if not required_trait.is_empty() and not definition.traits.has(required_trait):
			continue
		var min_target_cost = int(filters.get("min_target_cost", -1))
		if min_target_cost >= 0 and int(definition.cost) < min_target_cost:
			continue
		var max_target_cost = int(filters.get("max_target_cost", -1))
		if max_target_cost >= 0 and int(definition.cost) > max_target_cost:
			continue
		var max_target_power = int(filters.get("max_target_power", filters.get("max_power", -1)))
		if max_target_power >= 0 and int(definition.power) > max_target_power:
			continue
		result.append(str(card_id))
	return result

func _matching_battlefield_cards_for_player(state: GameState, player_id: int, filters: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var excluded_card_id = str(filters.get("exclude_card_id", ""))
	for card_id in _get_battlefield_card_ids_for_player(state, player_id):
		if not excluded_card_id.is_empty() and card_id == excluded_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		var required_type = str(filters.get("type", ""))
		if not required_type.is_empty() and definition.type != required_type:
			continue
		var required_definition_id = str(filters.get("id", ""))
		if not required_definition_id.is_empty() and str(definition.id) != required_definition_id:
			continue
		var name_contains = str(filters.get("name_contains", ""))
		if not name_contains.is_empty() and not _definition_name_contains(definition, name_contains):
			continue
		var required_faction = str(filters.get("faction", ""))
		if not _definition_matches_required_faction_for_player(state, player_id, definition, required_faction):
			continue
		var required_row = str(filters.get("row", ""))
		if not required_row.is_empty() and str(instance.position.get("row", "")) != required_row:
			continue
		var min_target_power = int(filters.get("min_target_power", filters.get("min_power", -1)))
		if min_target_power >= 0 and int(definition.power) < min_target_power:
			continue
		var max_target_power = int(filters.get("max_target_power", filters.get("max_power", -1)))
		if max_target_power >= 0 and int(definition.power) > max_target_power:
			continue
		result.append(card_id)
	return result

func _resolve_choice_follow_up_action(state: GameState, player_id: int, source_instance_id: String, follow_up_action, command_id: String) -> Array:
	if not (follow_up_action is Dictionary) or follow_up_action.is_empty():
		return []
	return _resolve_stack_follow_up_action(state, {
		"controller": player_id,
		"source_instance_id": source_instance_id,
		"resolution": {}
	}, follow_up_action, command_id)

func _controller_has_master_morale_ready_lock(state: GameState, player_id: int) -> bool:
	for card_id in _get_battlefield_card_ids_for_player(state, player_id):
		var instance = state.card_instances.get(str(card_id))
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		for effect in definition.effects:
			if not (effect is Dictionary):
				continue
			if str(effect.get("kind", "")) != "continuous":
				continue
			var resolution = effect.get("resolution", {})
			if not (resolution is Dictionary):
				continue
			if str(resolution.get("action", "")) != "prevent_master_ready_spent_morale":
				continue
			var required_row := str(resolution.get("required_row", ""))
			if not required_row.is_empty() and str(instance.position.get("row", "")) != required_row:
				continue
			var required_orientation := str(resolution.get("required_orientation", ""))
			if not required_orientation.is_empty() and str(instance.orientation) != required_orientation:
				continue
			if bool(resolution.get("only_during_opponent_turn", false)) and int(instance.controller) == int(state.active_player):
				continue
			return true
	return false

func _matching_hand_counter_tactic_ids(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	var player = state.get_player(player_id)
	for card_id in player.hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null or not definition.is_counter_tactic():
			continue
		result.append(card_id)
	return result

func _matching_set_counter_tactic_ids(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	for row in [state.get_player(player_id).battle_front, state.get_player(player_id).battle_back]:
		for slot in row:
			var card_id := str(slot.occupant)
			if card_id.is_empty():
				continue
			var instance = state.card_instances.get(card_id)
			if instance == null or str(instance.face) != "face_down":
				continue
			var definition = state.get_definition(instance.definition_id)
			if definition == null or not definition.is_counter_tactic():
				continue
			result.append(card_id)
	return result

func _move_grave_cards_to_deck_bottom(state: GameState, player_id: int, selected_card_ids: Array, command_id: String, event_options: Dictionary = {}) -> Array:
	var player = state.get_player(player_id)
	var events: Array = []
	for card_id in selected_card_ids:
		if not player.grave.remove_card(card_id):
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and _is_suncity_gravebound_definition(str(instance.definition_id)):
			player.grave.add_card_to_top(card_id)
			continue
		player.deck.cards.append(card_id)
		if instance != null:
			instance.zone = "deck"
			instance.position = {}
		var event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", player_id, _merge_event_payload_options({
			"card_id": card_id,
			"from": "grave",
			"to": "deck_bottom"
		}, event_options))
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _move_grave_cards_to_deck_top(state: GameState, player_id: int, selected_card_ids: Array, command_id: String, event_options: Dictionary = {}) -> Array:
	var player = state.get_player(player_id)
	var events: Array = []
	for card_id in selected_card_ids:
		if not player.grave.remove_card(card_id):
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and _is_suncity_gravebound_definition(str(instance.definition_id)):
			player.grave.add_card_to_top(card_id)
			continue
		player.deck.cards.insert(0, card_id)
		if instance != null:
			instance.zone = "deck"
			instance.position = {}
			instance.orientation = "active"
			instance.controller = instance.owner
		var event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", player_id, _merge_event_payload_options({
			"card_id": card_id,
			"from": "grave",
			"to": "deck_top"
		}, event_options))
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _move_hand_cards_to_deck_bottom(state: GameState, player_id: int, selected_card_ids: Array, command_id: String, event_options: Dictionary = {}) -> Array:
	var player = state.get_player(player_id)
	var events: Array = []
	for card_id in selected_card_ids:
		if not player.hand.remove_card(card_id):
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and _is_suncity_gravebound_definition(str(instance.definition_id)):
			player.grave.add_card_to_top(card_id)
			instance.zone = "grave"
			instance.position = {}
			instance.orientation = "active"
			var grave_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, _merge_event_payload_options({
				"card_id": card_id,
				"from": "hand",
				"to": "grave"
			}, event_options))
			grave_event.created_by_command = command_id
			state.event_log.append(grave_event)
			events.append(grave_event)
			continue
		player.deck.cards.append(card_id)
		if instance != null:
			instance.zone = "deck"
			instance.position = {}
			instance.orientation = "active"
			instance.controller = instance.owner
		var event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", player_id, _merge_event_payload_options({
			"card_id": card_id,
			"from": "hand",
			"to": "deck_bottom"
		}, event_options))
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _move_hand_cards_to_deck_top(state: GameState, player_id: int, selected_card_ids: Array, command_id: String, event_options: Dictionary = {}) -> Array:
	var player = state.get_player(player_id)
	var events: Array = []
	for card_id in selected_card_ids:
		if not player.hand.remove_card(card_id):
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and _is_suncity_gravebound_definition(str(instance.definition_id)):
			player.grave.add_card_to_top(card_id)
			instance.zone = "grave"
			instance.position = {}
			instance.orientation = "active"
			var grave_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, _merge_event_payload_options({
				"card_id": card_id,
				"from": "hand",
				"to": "grave"
			}, event_options))
			grave_event.created_by_command = command_id
			state.event_log.append(grave_event)
			events.append(grave_event)
			continue
		player.deck.cards.insert(0, card_id)
		if instance != null:
			instance.zone = "deck"
			instance.position = {}
			instance.orientation = "active"
			instance.controller = instance.owner
		var event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", player_id, _merge_event_payload_options({
			"card_id": card_id,
			"from": "hand",
			"to": "deck_top"
		}, event_options))
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _discard_hand_cards(state: GameState, player_id: int, selected_card_ids: Array, command_id: String, event_options: Dictionary = {}) -> Array:
	var player = state.get_player(player_id)
	var events: Array = []
	for raw_card_id in selected_card_ids:
		var card_id := str(raw_card_id)
		if card_id.is_empty():
			continue
		if not player.hand.remove_card(card_id):
			continue
		events.append_array(ZoneActions.move_card_to_grave(state, card_id, "hand", command_id, event_options))
	return events

func _resolve_pending_olympus_lethal_death(state: GameState, raw_context, command_id: String) -> Array:
	var context = raw_context if raw_context is Dictionary else {}
	var player_id = int(context.get("player_id", -1))
	var row = str(context.get("row", ""))
	var col = int(context.get("col", -1))
	var options = context.get("grave_options", {})
	var grave_options: Dictionary = options.duplicate(true) if options is Dictionary else {}
	grave_options["skip_lethal_replacement_choice"] = true
	if player_id < 0 or row.is_empty() or col < 0:
		return []
	return ZoneActions.move_battlefield_to_grave(state, player_id, row, col, command_id, grave_options)

func _apply_olympus_achilles_lethal_replace(state: GameState, raw_context, command_id: String) -> Array:
	var context = raw_context if raw_context is Dictionary else {}
	var player_id = int(context.get("player_id", -1))
	var card_id = str(context.get("card_id", ""))
	if player_id < 0 or card_id.is_empty():
		return []
	if MoraleActions.count_active_divine_morale(state, player_id) < 1:
		return _resolve_pending_olympus_lethal_death(state, context, command_id)
	var events = MoraleActions.consume_divine_morale(state, player_id, 1, command_id, true)
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return events
	instance.flags["olympus_achilles_lethal_replace_used_turn"] = state.turn_number
	instance.flags["fixed_power_until_turn_end_turn"] = state.turn_number
	instance.flags["fixed_power_until_turn_end_value"] = 1000
	instance.damage_marked = 0
	var prevented = GameEvent.create(state.next_event_id(), "CardDeathPrevented", player_id, {
		"card_id": card_id,
		"replacement": "achilles_divine_flip"
	})
	prevented.created_by_command = command_id
	state.event_log.append(prevented)
	events.append(prevented)
	var replacement = GameEvent.create(state.next_event_id(), "ReplacementEffectApplied", player_id, {
		"card_id": card_id,
		"effect": "olympus_achilles_lethal_replace",
		"power": 1000
	})
	replacement.created_by_command = command_id
	state.event_log.append(replacement)
	events.append(replacement)
	return events

func _apply_olympus_helen_lethal_replace(state: GameState, raw_context, command_id: String) -> Array:
	var context = raw_context if raw_context is Dictionary else {}
	var player_id = int(context.get("player_id", -1))
	var card_id = str(context.get("card_id", ""))
	if player_id < 0 or card_id.is_empty():
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.flags["olympus_helen_lethal_replace_used_turn"] = state.turn_number
	instance.damage_marked = 0
	var prevented = GameEvent.create(state.next_event_id(), "CardDeathPrevented", player_id, {
		"card_id": card_id,
		"replacement": "helen_discard_legion"
	})
	prevented.created_by_command = command_id
	state.event_log.append(prevented)
	var replacement = GameEvent.create(state.next_event_id(), "ReplacementEffectApplied", player_id, {
		"card_id": card_id,
		"effect": "olympus_helen_lethal_replace"
	})
	replacement.created_by_command = command_id
	state.event_log.append(replacement)
	return [prevented, replacement]

func _move_grave_cards_to_hand(state: GameState, player_id: int, selected_card_ids: Array, command_id: String, event_options: Dictionary = {}) -> Array:
	var player = state.get_player(player_id)
	var events: Array = []
	for card_id in selected_card_ids:
		if not player.grave.remove_card(card_id):
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and _is_suncity_gravebound_definition(str(instance.definition_id)):
			player.grave.add_card_to_top(card_id)
			continue
		player.hand.add_card(card_id)
		if instance != null:
			instance.zone = "hand"
			instance.position = {}
			instance.controller = instance.owner
			instance.orientation = "active"
			instance.damage_marked = 0
			instance.has_attacked_this_turn = false
		var event = GameEvent.create(state.next_event_id(), "CardReturnedToHand", player_id, _merge_event_payload_options({
			"card_id": card_id,
			"from": "grave",
			"to": "hand"
		}, event_options))
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events

func _move_matching_card_from_deck_or_grave_to_hand(state: GameState, player_id: int, card_id: String, stack_item: Dictionary, command_id: String) -> Array:
	if card_id.is_empty():
		return []
	var player = state.get_player(player_id)
	var from_zone := ""
	if player.deck.remove_card(card_id):
		from_zone = "deck"
	elif player.grave.remove_card(card_id):
		from_zone = "grave"
	else:
		return []
	var instance = state.card_instances.get(card_id)
	if instance != null and from_zone == "grave" and _is_suncity_gravebound_definition(str(instance.definition_id)):
		player.grave.add_card_to_top(card_id)
		return []
	player.hand.add_card(card_id)
	if instance != null:
		instance.zone = "hand"
		instance.position = {}
		instance.controller = instance.owner
		instance.orientation = "active"
		instance.damage_marked = 0
		instance.has_attacked_this_turn = false
	var event = GameEvent.create(state.next_event_id(), "CardReturnedToHand", player_id, _merge_event_payload_options({
		"card_id": card_id,
		"from": from_zone,
		"to": "hand"
	}, _effect_event_options_from_stack_item(state, stack_item, stack_item.get("resolution", {}))))
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [event]
	events.append_array(_resolve_stack_follow_up_action(state, stack_item, stack_item.get("resolution", {}).get("follow_up_action", {}), command_id))
	return events

func _deploy_hand_card_to_slot(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	return _deploy_hand_card_to_slot_with_orientation(state, player_id, card_id, row, col, "active", command_id)

func _deploy_hand_card_to_slot_with_orientation(state: GameState, player_id: int, card_id: String, row: String, col: int, orientation: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var target_slot = player.get_slot(row, col)
	if target_slot == null or not target_slot.occupant.is_empty():
		return []
	if row == "back" and _is_back_row_blocked_by_calamity(state):
		return []
	if not player.hand.remove_card(card_id):
		return []
	target_slot.occupant = card_id
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = orientation if orientation == "rested" else "active"
	instance.damage_marked = 0
	instance.controller = player_id
	instance.entered_turn = state.turn_number
	var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"from": "hand"
	})
	entered_event.created_by_command = command_id
	state.event_log.append(entered_event)
	var event = GameEvent.create(state.next_event_id(), "CardPlayed", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"played_as": "deployed_from_hand"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [entered_event, event]
	events.append_array(_apply_master_entry_effects(state, player_id, card_id, command_id))
	events.append_array(_apply_legion_entry_calamity_for_card(state, card_id, command_id))
	events.append_array(_apply_immediate_self_entry_effects(state, player_id, card_id, command_id))
	_refresh_continuous_modifiers(state)
	return events

func _set_counter_tactic_from_hand_to_slot(state: GameState, player_id: int, card_id: String, col: int, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var target_slot = player.get_slot("back", col)
	if target_slot == null or not target_slot.occupant.is_empty():
		return []
	if not player.hand.remove_card(card_id):
		return []
	target_slot.occupant = card_id
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.zone = "battle_back"
	instance.position = {"row": "back", "col": col}
	instance.orientation = "active"
	instance.face = "face_down"
	instance.damage_marked = 0
	instance.controller = player_id
	instance.entered_turn = state.turn_number
	var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", player_id, {
		"card_id": card_id,
		"row": "back",
		"col": col,
		"from": "hand"
	})
	entered_event.created_by_command = command_id
	state.event_log.append(entered_event)
	var event = GameEvent.create(state.next_event_id(), "CardPlayed", player_id, {
		"card_id": card_id,
		"row": "back",
		"col": col,
		"played_as": "set_counter_tactic"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [entered_event, event]

func _deploy_stack_pending_counter_to_foreign_battlefield(state: GameState, card_id: String, owner_player_id: int, host_player_id: int, row: String, col: int, command_id: String) -> Array:
	var host_player = state.get_player(host_player_id)
	var target_slot = host_player.get_slot(row, col)
	if target_slot == null or not target_slot.occupant.is_empty():
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null or str(instance.zone) != "stack_pending":
		return []
	target_slot.occupant = card_id
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = "active"
	instance.face = "face_up"
	instance.damage_marked = 0
	instance.controller = host_player_id
	instance.entered_turn = state.turn_number
	instance.flags["foreign_battlefield_owner_player"] = owner_player_id
	instance.flags["foreign_battlefield_host_player"] = host_player_id
	instance.flags["foreign_battlefield_discard_on_player_turn_end"] = owner_player_id
	instance.flags["foreign_battlefield_draw_owner_on_leave"] = true
	var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", owner_player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"from": "stack_pending",
		"host_player": host_player_id
	})
	entered_event.created_by_command = command_id
	state.event_log.append(entered_event)
	var event = GameEvent.create(state.next_event_id(), "CardPlayed", owner_player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"played_as": "foreign_battlefield_counter_tactic",
		"host_player": host_player_id
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [entered_event, event]

func _revive_grave_card_to_first_slot(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var slot = _first_empty_slot(player, "front")
	if slot.is_empty():
		slot = _first_empty_slot(player, "back")
	if slot.is_empty():
		return []
	return _revive_grave_card_to_slot(state, player_id, card_id, str(slot.get("row", "front")), int(slot.get("col", -1)), command_id)

func _revive_grave_card_to_slot(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var target_slot = player.get_slot(row, col)
	if target_slot == null or not target_slot.occupant.is_empty():
		return []
	if not player.grave.remove_card(card_id):
		return []
	target_slot.occupant = card_id
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = "active"
	instance.damage_marked = 0
	instance.controller = player_id
	instance.entered_turn = state.turn_number
	var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"from": "grave"
	})
	entered_event.created_by_command = command_id
	state.event_log.append(entered_event)
	var event = GameEvent.create(state.next_event_id(), "CardRevived", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [entered_event, event]
	events.append_array(_apply_master_entry_effects(state, player_id, card_id, command_id))
	events.append_array(_apply_legion_entry_calamity_for_card(state, card_id, command_id))
	if not _has_pending_non_hand_entry_response_window(state, card_id):
		events.append_array(_apply_immediate_self_entry_effects(state, player_id, card_id, command_id))
	return events

func _deploy_deck_card_to_slot(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var target_slot = player.get_slot(row, col)
	if target_slot == null or not target_slot.occupant.is_empty():
		return []
	if row == "back" and _is_back_row_blocked_by_calamity(state):
		return []
	if not player.deck.remove_card(card_id):
		return []
	target_slot.occupant = card_id
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = "active"
	instance.face = "face_up"
	instance.damage_marked = 0
	instance.controller = player_id
	instance.entered_turn = state.turn_number
	instance.has_attacked_this_turn = false
	var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"from": "deck"
	})
	entered_event.created_by_command = command_id
	state.event_log.append(entered_event)
	var played_event = GameEvent.create(state.next_event_id(), "CardPlayed", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"played_as": "played_from_deck_without_cost"
	})
	played_event.created_by_command = command_id
	state.event_log.append(played_event)
	var events: Array = [entered_event, played_event]
	events.append_array(_apply_master_entry_effects(state, player_id, card_id, command_id))
	events.append_array(_apply_legion_entry_calamity_for_card(state, card_id, command_id))
	if not _has_pending_non_hand_entry_response_window(state, card_id):
		events.append_array(_apply_immediate_self_entry_effects(state, player_id, card_id, command_id))
	_refresh_continuous_modifiers(state)
	return events

func _revive_bjorn_source_rested(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var slot = _first_empty_slot(player, "front")
	if slot.is_empty():
		slot = _first_empty_slot(player, "back")
	if slot.is_empty():
		return []
	return _revive_bjorn_source_rested_to_slot(state, player_id, card_id, str(slot.get("row", "front")), int(slot.get("col", -1)), command_id)


func _revive_bjorn_source_rested_to_slot(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var target_slot = player.get_slot(row, col)
	if target_slot == null or not target_slot.occupant.is_empty():
		return []
	if not player.grave.remove_card(card_id):
		return []
	target_slot.occupant = card_id
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = "rested"
	instance.damage_marked = 0
	instance.controller = player_id
	instance.entered_turn = state.turn_number
	instance.face = "face_up"
	instance.has_attacked_this_turn = false
	instance.flags.erase("concealed")
	instance.flags.erase("front_attack_power_bonus_turn")
	instance.flags.erase("front_attack_power_bonus_amount")
	instance.flags.erase("master_damage_bonus_turn")
	instance.flags.erase("master_damage_bonus_amount")
	instance.flags.erase("cost_modifier_until_turn_end")
	instance.flags.erase("power_modifier_until_turn_end_turn")
	instance.flags.erase("power_modifier_until_turn_end_amount")
	instance.flags.erase("manifested_power")
	instance.flags.erase("manifested_traits")
	for raw_key in instance.flags.keys():
		var flag_key = str(raw_key)
		if flag_key.begins_with("temporary_keyword_") or flag_key.begins_with("once_per_turn_"):
			instance.flags.erase(raw_key)
	var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"from": "grave"
	})
	entered_event.created_by_command = command_id
	state.event_log.append(entered_event)
	var event = GameEvent.create(state.next_event_id(), "CardRevived", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	var events: Array = [entered_event, event]
	events.append_array(_apply_master_entry_effects(state, player_id, card_id, command_id))
	events.append_array(_apply_legion_entry_calamity_for_card(state, card_id, command_id))
	return events

func _maybe_request_bjorn_rested_revive_choice(state: GameState, player_id: int, source_id: String, revive_row: String, revive_col: int, command_id: String) -> Array:
	if source_id.is_empty():
		return []
	if revive_row.is_empty() or revive_col < 0:
		return []
	var slot = state.get_player(player_id).get_slot(revive_row, revive_col)
	if slot == null or not slot.occupant.is_empty():
		return []
	return _request_option_choice(state, player_id, [
		{"id": "yes", "label": "休整登场"},
		{"id": "no", "label": "不登场"}
	], "是否让勇士比约恩休整登场？", "bjorn_confirm_rested_revive", {
		"source_instance_id": source_id,
		"revive_row": revive_row,
		"revive_col": revive_col
	}, command_id)

func _bjorn_rested_revive_slot_from_trigger(state: GameState, player_id: int, stack_item: Dictionary) -> Dictionary:
	var source_event_id := int(stack_item.get("created_from_event_id", -1))
	if source_event_id < 0:
		return {}
	var source_event = _find_event_by_id(state, source_event_id)
	if source_event == null or str(source_event.type) != "CardDied":
		return {}
	var payload = source_event.payload
	if not (payload is Dictionary):
		return {}
	var source_id := str(stack_item.get("source_instance_id", ""))
	if str(payload.get("card_id", "")) != source_id:
		return {}
	var row := str(payload.get("row", ""))
	var col := int(payload.get("col", -1))
	if (row != "front" and row != "back") or col < 0:
		return {}
	if row == "back" and _is_back_row_blocked_by_calamity(state):
		return {}
	var slot = state.get_player(player_id).get_slot(row, col)
	if slot == null or not slot.occupant.is_empty():
		return {}
	return {
		"row": row,
		"col": col
	}

func _battlefield_slot_options(state: GameState, player_id: int) -> Array:
	var result: Array = []
	if player_id < 0 or player_id >= state.players.size():
		return result
	var player = state.get_player(player_id)
	for row in ["front", "back"]:
		if row == "back" and _is_back_row_blocked_by_calamity(state):
			continue
		for col in range(3):
			var slot = player.get_slot(row, col)
			if slot == null or not slot.occupant.is_empty():
				continue
			var label_row := "前排" if row == "front" else "后排"
			result.append({
				"id": "%s:%d" % [row, col],
				"label": "%s%d" % [label_row, col + 1],
				"row": row,
				"col": col
			})
	return result

func _front_battlefield_slot_options(state: GameState, player_id: int) -> Array:
	var result: Array = []
	for option in _battlefield_slot_options(state, player_id):
		if str(option.get("row", "")) == "front":
			result.append(option)
	return result

func _back_battlefield_slot_options(state: GameState, player_id: int) -> Array:
	var result: Array = []
	for option in _battlefield_slot_options(state, player_id):
		if str(option.get("row", "")) == "back":
			result.append(option)
	return result

func _parse_slot_option(option_id: String) -> Dictionary:
	var parts = option_id.split(":")
	if parts.size() != 2:
		return {}
	var row = str(parts[0])
	var col_text = str(parts[1])
	if (row != "front" and row != "back") or not col_text.is_valid_int():
		return {}
	return {"row": row, "col": int(col_text)}

func _validate_candidate_choice_payload(state: GameState, choice: Dictionary, payload: Dictionary) -> Dictionary:
	var operation := str(choice.get("operation", ""))
	if operation == "search_top_for_artifact_and_named_legion":
		var selected = _normalize_selected_card_ids(payload.get("selected_card_ids", []))
		var artifact_candidates = choice.get("context", {}).get("artifact_candidates", [])
		var named_legion_candidates = choice.get("context", {}).get("named_legion_candidates", [])
		var artifact_count := 0
		var legion_count := 0
		for card_id in selected:
			if artifact_candidates is Array and artifact_candidates.has(card_id):
				artifact_count += 1
			if named_legion_candidates is Array and named_legion_candidates.has(card_id):
				legion_count += 1
		var required_artifact_count = 1 if artifact_candidates is Array and not artifact_candidates.is_empty() else 0
		var required_legion_count = 1 if named_legion_candidates is Array and not named_legion_candidates.is_empty() else 0
		if artifact_count != required_artifact_count or legion_count != required_legion_count:
			return _error("INVALID_CHOICE", "must select exactly one artifact and one 上杉谦信 when available")
		return {"ok": true}
	if operation == "trigger_selected_legion_died_effects":
		var selected = _normalize_selected_card_ids(payload.get("selected_card_ids", []))
		var chosen_definition_ids := {}
		for card_id in selected:
			var instance = state.card_instances.get(card_id)
			if instance == null:
				return _error("INVALID_CHOICE", "selected died-effect card does not exist")
			var definition_id = str(instance.definition_id)
			if chosen_definition_ids.has(definition_id):
				return _error("INVALID_CHOICE", "must select non-duplicate legion names")
			chosen_definition_ids[definition_id] = true
		return {"ok": true}
	if operation == "hijikata_entry_destroy_combo":
		var selected = _normalize_selected_card_ids(payload.get("selected_card_ids", []))
		if selected.is_empty():
			return _error("INVALID_CHOICE", "must select at least one target")
		if selected.size() > 2:
			return _error("INVALID_CHOICE", "must select at most two targets")
		var cost_one_or_less_ids = choice.get("context", {}).get("cost_one_or_less_ids", [])
		var cost_two_only_ids = choice.get("context", {}).get("cost_two_only_ids", [])
		var selected_cost_one_or_less := 0
		var selected_cost_two_only := 0
		for card_id in selected:
			if cost_one_or_less_ids is Array and cost_one_or_less_ids.has(card_id):
				selected_cost_one_or_less += 1
				continue
			if cost_two_only_ids is Array and cost_two_only_ids.has(card_id):
				selected_cost_two_only += 1
				continue
			return _error("INVALID_CHOICE", "hijikata selected a target outside allowed costs")
		if selected_cost_two_only > 1:
			return _error("INVALID_CHOICE", "hijikata can select at most one cost-2 target")
		if selected_cost_one_or_less > 2:
			return _error("INVALID_CHOICE", "hijikata can select at most two cost-1-or-less targets")
		var allow_single_confirm = bool(choice.get("context", {}).get("allow_single_confirm", true))
		if not allow_single_confirm and selected.size() != 2:
			return _error("INVALID_CHOICE", "hijikata must select two targets when both cost bands are available")
		if selected.size() == 2 and selected_cost_one_or_less < 1:
			return _error("INVALID_CHOICE", "hijikata must include at least one cost-1-or-less legion")
		return {"ok": true}
	if operation != "deploy_from_hand_to_battlefield":
		return {"ok": true}
	var row := str(payload.get("row", ""))
	if row.is_empty():
		return {"ok": true}
	var col = int(payload.get("col", -1))
	if col < 0:
		return _error("INVALID_CHOICE", "deploy choice requires a valid battlefield slot")
	var valid_slots = _battlefield_slot_options(state, int(choice.get("player_id", -1)))
	for option in valid_slots:
		if str(option.get("row", "")) == row and int(option.get("col", -1)) == col:
			return {"ok": true}
	return _error("INVALID_CHOICE", "deploy choice slot is not available")

func _deploy_hand_card_to_first_slot(state: GameState, player_id: int, card_id: String, command_id: String, orientation: String = "active") -> Array:
	var player = state.get_player(player_id)
	var slot = _first_empty_slot(player, "front")
	if slot.is_empty():
		slot = _first_empty_slot(player, "back")
	if slot.is_empty():
		return []
	return _deploy_hand_card_to_slot_with_orientation(state, player_id, card_id, str(slot.get("row", "front")), int(slot.get("col", -1)), orientation, command_id)

func _request_move_slot_choice_for_cards(state: GameState, player_id: int, card_ids: Array[String], command_id: String) -> Array:
	var remaining_ids: Array[String] = card_ids.duplicate()
	while not remaining_ids.is_empty():
		var current_card_id = str(remaining_ids[0])
		remaining_ids.remove_at(0)
		var slot_options = _effect_move_slot_options(state, current_card_id)
		if slot_options.is_empty():
			continue
		return _request_option_choice(state, player_id, slot_options, "选择位移位置", "move_selected_battlefield_card_to_slot", {
			"card_id": current_card_id,
			"remaining_card_ids": remaining_ids.duplicate()
		}, command_id)
	return []

func _request_set_counter_tactic_slot_choice_for_cards(state: GameState, player_id: int, card_ids: Array[String], command_id: String, follow_up_action = {}, source_instance_id: String = "") -> Array:
	var remaining_ids: Array[String] = card_ids.duplicate()
	while not remaining_ids.is_empty():
		var current_card_id := str(remaining_ids[0])
		remaining_ids.remove_at(0)
		if state.card_instances.get(current_card_id) == null:
			continue
		var slot_options := _back_battlefield_slot_options(state, player_id)
		if slot_options.is_empty():
			return []
		return _request_option_choice(state, player_id, slot_options, "选择置入后排的位置", "set_counter_tactic_from_hand_to_slot", {
			"card_id": current_card_id,
			"remaining_card_ids": remaining_ids.duplicate(),
			"follow_up_action": follow_up_action.duplicate(true) if follow_up_action is Dictionary else {},
			"source_instance_id": source_instance_id
		}, command_id)
	return []

func _effect_move_slot_options(state: GameState, card_id: String) -> Array:
	var result: Array[Dictionary] = []
	var instance = state.card_instances.get(card_id)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return result
	var player = state.get_player(int(instance.controller))
	var current_row = str(instance.position.get("row", ""))
	var current_col = int(instance.position.get("col", -1))
	for target_row in ["front", "back"]:
		for target_col in range(3):
			_append_move_target_if_legal(state, player, current_row, current_col, target_row, target_col, result)
	var options: Array = []
	for slot in result:
		options.append({
			"id": "%s:%d" % [str(slot.get("row", "")), int(slot.get("col", -1))],
			"label": "%s排 %d" % ["前" if str(slot.get("row", "")) == "front" else "后", int(slot.get("col", -1)) + 1],
			"row": str(slot.get("row", "")),
			"col": int(slot.get("col", -1))
		})
	return options

func _move_battlefield_card_to_slot_without_cost_for_options(state: GameState, card_id: String, row: String, col: int, allowed_options: Array, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return []
	var source_row = str(instance.position.get("row", ""))
	var source_col = int(instance.position.get("col", -1))
	if source_row.is_empty() or source_col < 0:
		return []
	var player = state.get_player(int(instance.controller))
	var valid := false
	for option in allowed_options:
		if str(option.get("row", "")) == row and int(option.get("col", -1)) == col:
			valid = true
			break
	if not valid:
		return []
	var from_slot = player.get_slot(source_row, source_col)
	var target_slot = player.get_slot(row, col)
	if from_slot == null or target_slot == null or not target_slot.occupant.is_empty():
		return []
	from_slot.occupant = ""
	target_slot.occupant = card_id
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	var event = GameEvent.create(state.next_event_id(), "CardMoved", int(instance.controller), {
		"card_id": card_id,
		"from_row": source_row,
		"from_col": source_col,
		"to_row": row,
		"to_col": col,
		"morale_cost": 0,
		"manual": false
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	_mark_card_as_moved_this_turn(state, card_id)
	var events: Array = [event]
	events.append_array(_apply_master_move_effects(state, event, command_id))
	return events


func _move_battlefield_card_to_slot_without_cost(state: GameState, card_id: String, row: String, col: int, command_id: String) -> Array:
	return _move_battlefield_card_to_slot_without_cost_for_options(state, card_id, row, col, _effect_move_slot_options(state, card_id), command_id)

func _move_battlefield_card(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null or int(instance.controller) != player_id:
		return []
	var events = _move_battlefield_card_to_slot_without_cost(state, card_id, row, col, command_id)
	_refresh_continuous_modifiers(state)
	return events

func _first_empty_slot(player, preferred_row: String) -> Dictionary:
	var rows = [preferred_row]
	if preferred_row == "front":
		rows.append("back")
	else:
		rows.append("front")
	for row in rows:
		for col in range(3):
			var slot = player.get_slot(row, col)
			if slot != null and slot.occupant.is_empty():
				return {"row": row, "col": col}
	return {}

func _mark_card_as_moved_this_turn(state: GameState, card_id: String) -> void:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return
	instance.flags["moved_this_turn"] = true

func _find_owned_card_by_definition(state: GameState, player_id: int, definition_id: String) -> String:
	var player = state.get_player(player_id)
	for zone_cards in [player.artifact_zone.cards, player.hand.cards, player.grave.cards, player.deck.cards]:
		for card_id in zone_cards:
			var instance = state.card_instances.get(card_id)
			if instance != null and instance.definition_id == definition_id:
				return card_id
	return ""

func _battlefield_counter_tactic_count(state: GameState) -> int:
	var total := 0
	for card_id in _get_battlefield_card_ids(state):
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition != null and definition.is_counter_tactic():
			total += 1
	return total

func _remove_card_from_current_zone(state: GameState, card_id: String) -> void:
	for player in state.players:
		for zone in [player.artifact_zone, player.trial_zone, player.city_zone, player.hand, player.grave, player.deck]:
			if zone.remove_card(card_id):
				return
		for row in ["front", "back"]:
			for col in range(3):
				var slot = player.get_slot(row, col)
				if slot != null and slot.occupant == card_id:
					slot.occupant = ""
					return

func _card_matches_reveal_top_play_filters(state: GameState, card_id: String, filters: Dictionary) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return false
	var required_faction = str(filters.get("faction", ""))
	if not _definition_matches_required_faction_for_instance(state, instance, definition, required_faction):
		return false
	var max_target_cost = int(filters.get("max_target_cost", filters.get("max_cost", -1)))
	if max_target_cost >= 0 and int(definition.cost) > max_target_cost:
		return false
	return definition.is_legion() or definition.is_artifact() or definition.is_tactic() or definition.is_counter_tactic()

func _move_top_deck_card_to_hand(state: GameState, player_id: int, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var card_id = player.deck.take_top()
	if card_id.is_empty():
		return []
	player.hand.add_card(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "hand"
		instance.position = {}
		instance.controller = instance.owner
		instance.orientation = "active"
		instance.damage_marked = 0
		instance.has_attacked_this_turn = false
	var event = GameEvent.create(state.next_event_id(), "CardDrawn", player_id, {"card_id": card_id})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _play_revealed_deck_card_without_cost(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	var player = state.get_player(player_id)
	if player.deck.cards.is_empty() or str(player.deck.cards[0]) != card_id:
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return []
	player.deck.take_top()
	if definition.is_counter_tactic():
		if row.is_empty():
			row = "back"
		return _set_counter_tactic_from_external_zone_to_slot(state, player_id, card_id, row, col, "deck", command_id)
	if definition.is_tactic():
		instance.zone = "stack_pending"
		instance.position = {}
		instance.orientation = "active"
		var effect = _find_selected_tactic_effect(definition)
		if effect.is_empty():
			return []
		_remember_last_active_tactic(state, player_id, card_id, effect)
		var played_event = GameEvent.create(state.next_event_id(), "CardPlayed", player_id, {
			"card_id": card_id,
			"row": "tactic",
			"col": -1,
			"played_as": "played_from_deck_without_cost"
		})
		played_event.created_by_command = command_id
		state.event_log.append(played_event)
		var events: Array = [played_event]
		events.append_array(_put_effect_on_stack(state, player_id, card_id, effect, "tactic", [], 0, {}, command_id))
		events.append_array(_queue_additional_stack_effects(state, player_id, card_id, effect, command_id))
		return events
	if definition.is_artifact():
		var replace_events = _replace_existing_artifacts_for_definition(state, player_id, definition, command_id)
		player.artifact_zone.add_card(card_id)
		instance.zone = "artifact_zone"
		instance.position = {}
		instance.orientation = "active"
		instance.controller = player_id
		var artifact_event = GameEvent.create(state.next_event_id(), "CardPlayed", player_id, {
			"card_id": card_id,
			"row": "artifact",
			"col": -1,
			"played_as": "played_from_deck_without_cost"
		})
		artifact_event.created_by_command = command_id
		state.event_log.append(artifact_event)
		return [artifact_event]
	if row.is_empty() or col < 0:
		return _play_revealed_legion_to_first_slot_without_cost(state, player_id, card_id, command_id)
	return _play_revealed_legion_to_slot_without_cost(state, player_id, card_id, row, col, command_id)

func _play_revealed_legion_to_first_slot_without_cost(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var slot = _first_empty_slot(player, "front")
	if slot.is_empty():
		slot = _first_empty_slot(player, "back")
	if slot.is_empty():
		return []
	return _play_revealed_legion_to_slot_without_cost(state, player_id, card_id, str(slot.get("row", "front")), int(slot.get("col", -1)), command_id)

func _play_revealed_legion_to_slot_without_cost(state: GameState, player_id: int, card_id: String, row: String, col: int, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var target_slot = player.get_slot(row, col)
	if target_slot == null or not target_slot.occupant.is_empty():
		return []
	if row == "back" and _is_back_row_blocked_by_calamity(state):
		return []
	target_slot.occupant = card_id
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = "active"
	instance.damage_marked = 0
	instance.controller = player_id
	instance.entered_turn = state.turn_number
	var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"from": "deck"
	})
	entered_event.created_by_command = command_id
	state.event_log.append(entered_event)
	var played_event = GameEvent.create(state.next_event_id(), "CardPlayed", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"played_as": "played_from_deck_without_cost"
	})
	played_event.created_by_command = command_id
	state.event_log.append(played_event)
	var events: Array = [entered_event, played_event]
	events.append_array(_apply_master_entry_effects(state, player_id, card_id, command_id))
	events.append_array(_apply_legion_entry_calamity_for_card(state, card_id, command_id))
	return events

func _set_counter_tactic_from_external_zone_to_slot(state: GameState, player_id: int, card_id: String, row: String, col: int, from_zone: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var target_slot = player.get_slot(row, col)
	if target_slot == null or not target_slot.occupant.is_empty():
		return []
	target_slot.occupant = card_id
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return []
	instance.zone = "battle_%s" % row
	instance.position = {"row": row, "col": col}
	instance.orientation = "active"
	instance.face = "face_down"
	instance.damage_marked = 0
	instance.controller = player_id
	instance.entered_turn = state.turn_number
	var entered_event = GameEvent.create(state.next_event_id(), "CardEnteredBattlefield", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"from": from_zone
	})
	entered_event.created_by_command = command_id
	state.event_log.append(entered_event)
	var played_event = GameEvent.create(state.next_event_id(), "CardPlayed", player_id, {
		"card_id": card_id,
		"row": row,
		"col": col,
		"played_as": "played_from_deck_without_cost"
	})
	played_event.created_by_command = command_id
	state.event_log.append(played_event)
	return [entered_event, played_event]

func _trigger_condition_matches(state: GameState, event: GameEvent, instance, effect: Dictionary) -> bool:
	var trigger_controller = int(instance.get("controller", -1)) if instance is Dictionary else int(instance.controller)
	var trigger_instance_id = str(instance.get("instance_id", "")) if instance is Dictionary else str(instance.instance_id)
	var condition = effect.get("condition", {})
	if not (condition is Dictionary) or condition.is_empty():
		return true
	var own_master_hp_at_most = int(condition.get("own_master_hp_at_most", -1))
	if own_master_hp_at_most >= 0 and state.get_player(trigger_controller).master_hp > own_master_hp_at_most:
		return false
	if bool(condition.get("controller_master_hp_less_than_opponent", false)):
		if state.get_player(trigger_controller).master_hp >= state.get_player(1 - trigger_controller).master_hp:
			return false
	if bool(condition.get("controller_master_hp_at_most_opponent", false)):
		if state.get_player(trigger_controller).master_hp > state.get_player(1 - trigger_controller).master_hp:
			return false
	var allied_front_other_count_at_most = int(condition.get("allied_front_other_count_at_most", -1))
	if allied_front_other_count_at_most >= 0:
		var player = state.get_player(trigger_controller)
		var other_front_count = 0
		for slot in player.battle_front:
			if slot.occupant.is_empty() or slot.occupant == trigger_instance_id:
				continue
			other_front_count += 1
		if other_front_count > allied_front_other_count_at_most:
			return false
	if bool(condition.get("controller_hand_size_at_most_opponent", false)):
		var own_hand = state.get_player(trigger_controller).hand.cards.size()
		var opponent_hand = state.get_player(1 - trigger_controller).hand.cards.size()
		if own_hand > opponent_hand:
			return false
	if bool(condition.get("controller_hand_size_less_than_opponent", false)):
		var own_hand_strict = state.get_player(trigger_controller).hand.cards.size()
		var opponent_hand_strict = state.get_player(1 - trigger_controller).hand.cards.size()
		if own_hand_strict >= opponent_hand_strict:
			return false
	var opponent_hand_size_at_least = int(condition.get("opponent_hand_size_at_least", -1))
	if opponent_hand_size_at_least >= 0 and state.get_player(1 - trigger_controller).hand.cards.size() < opponent_hand_size_at_least:
		return false
	var own_hand_size_at_most = int(condition.get("own_hand_size_at_most", -1))
	if own_hand_size_at_most >= 0 and state.get_player(trigger_controller).hand.cards.size() > own_hand_size_at_most:
		return false
	var played_with_play_option_id = str(condition.get("played_with_play_option_id", ""))
	if not played_with_play_option_id.is_empty():
		var payload = event.payload
		if not (payload is Dictionary) or str(payload.get("play_option_id", "")) != played_with_play_option_id:
			return false
	var controller_has_battlefield_definition = str(condition.get("controller_has_battlefield_definition", ""))
	if not controller_has_battlefield_definition.is_empty() and not _controller_has_definition_on_battlefield(state, trigger_controller, controller_has_battlefield_definition):
		return false
	var event_target_kind_is = str(condition.get("event_target_kind_is", ""))
	if not event_target_kind_is.is_empty():
		var event_payload = event.payload
		if not (event_payload is Dictionary) or str(event_payload.get("target_kind", "")) != event_target_kind_is:
			return false
	var event_phase_to = str(condition.get("event_phase_to", ""))
	if not event_phase_to.is_empty():
		var phase_payload = event.payload
		if not (phase_payload is Dictionary) or str(phase_payload.get("to", "")) != event_phase_to:
			return false
	var event_phase_from = str(condition.get("event_phase_from", ""))
	if not event_phase_from.is_empty():
		var previous_phase_payload = event.payload
		if not (previous_phase_payload is Dictionary) or str(previous_phase_payload.get("from", "")) != event_phase_from:
			return false
	var own_active_morale_at_most = int(condition.get("own_active_morale_at_most", -1))
	if own_active_morale_at_most >= 0 and MoraleActions.count_active_morale(state, trigger_controller) > own_active_morale_at_most:
		return false
	var own_runes_at_least = int(condition.get("own_runes_at_least", -1))
	if own_runes_at_least >= 0 and _player_rune_count(state, trigger_controller) < own_runes_at_least:
		return false
	var calamity_value_at_most = int(condition.get("calamity_value_at_most", -1))
	if calamity_value_at_most >= 0 and int(state.calamity_value) > calamity_value_at_most:
		return false
	var required_artifact_definition_id = str(condition.get("controller_has_artifact_definition", ""))
	if not required_artifact_definition_id.is_empty():
		var has_required_artifact := false
		for card_id in state.get_player(trigger_controller).artifact_zone.cards:
			var artifact_instance = state.card_instances.get(str(card_id))
			if artifact_instance != null and str(artifact_instance.definition_id) == required_artifact_definition_id:
				has_required_artifact = true
				break
		if not has_required_artifact:
			return false
	var required_front_definition_id = str(condition.get("controller_has_front_battlefield_definition", ""))
	if not required_front_definition_id.is_empty():
		var has_required_front_card := false
		for slot in state.get_player(trigger_controller).battle_front:
			var front_card_id = str(slot.occupant)
			if front_card_id.is_empty():
				continue
			var front_instance = state.card_instances.get(front_card_id)
			if front_instance != null and str(front_instance.definition_id) == required_front_definition_id:
				has_required_front_card = true
				break
		if not has_required_front_card:
			return false
	var canopic_count_at_least = int(condition.get("controller_artifact_name_contains_count_at_least", -1))
	if canopic_count_at_least >= 0 and _controller_canopic_artifact_count(state, trigger_controller) < canopic_count_at_least:
		return false
	if bool(condition.get("controller_turn_only", false)) and state.active_player != trigger_controller:
		return false
	if bool(condition.get("opponent_turn_only", false)) and state.active_player == trigger_controller:
		return false
	if bool(condition.get("event_player_is_controller", false)) and int(event.player_id) != trigger_controller:
		return false
	if bool(condition.get("event_player_is_opponent", false)) and int(event.player_id) != 1 - trigger_controller:
		return false
	if bool(condition.get("event_card_id_is_source", false)):
		var event_payload = event.payload
		if not (event_payload is Dictionary):
			return false
		if str(event_payload.get("card_id", "")) != trigger_instance_id:
			return false
	if bool(condition.get("resolved_source_is_controller_master", false)):
		var payload = event.payload
		if not (payload is Dictionary) or str(payload.get("source_id", "")) != _master_source_id(trigger_controller):
			return false
	var command_created_morale_readied_at_least = int(condition.get("command_created_morale_readied_at_least", -1))
	if command_created_morale_readied_at_least >= 0:
		var morale_readied_count := 0
		for prior_event in state.event_log:
			if str(prior_event.created_by_command) != str(event.created_by_command):
				continue
			if str(prior_event.type) == "MoraleReadied":
				morale_readied_count += 1
		if morale_readied_count < command_created_morale_readied_at_least:
			return false
	var source_kind_is = str(condition.get("source_kind_is", ""))
	if not source_kind_is.is_empty():
		var payload = event.payload
		if not (payload is Dictionary):
			return false
		var payload_source_kind = str(payload.get("source_kind", ""))
		if source_kind_is == "effect":
			if not _is_effect_like_source_kind(payload_source_kind):
				return false
		elif payload_source_kind != source_kind_is:
			return false
	var event_source_type_is = str(condition.get("event_source_type_is", ""))
	if not event_source_type_is.is_empty():
		var source_payload = event.payload
		if not (source_payload is Dictionary):
			return false
		var source_card_id = str(source_payload.get("source_id", source_payload.get("source_card_id", "")))
		if source_card_id.is_empty() or _is_master_source_id(source_card_id) or _is_morale_source_id(source_card_id):
			return false
		var source_instance = state.card_instances.get(source_card_id)
		if source_instance == null:
			return false
		var source_definition = state.get_definition(source_instance.definition_id)
		if source_definition == null:
			return false
		if event_source_type_is == "legion":
			if not _instance_counts_as_legion(state, source_instance):
				return false
		elif str(source_definition.type) != event_source_type_is:
			return false
	var event_card_type_is = str(condition.get("event_card_type_is", ""))
	var event_card_faction_is = str(condition.get("event_card_faction_is", ""))
	var event_card_cost_at_least = int(condition.get("event_card_cost_at_least", -1))
	if not event_card_type_is.is_empty() or not event_card_faction_is.is_empty() or event_card_cost_at_least >= 0:
		var event_payload = event.payload
		if not (event_payload is Dictionary):
			return false
		var event_card_id = str(event_payload.get("card_id", ""))
		if event_card_id.is_empty():
			return false
		var event_instance = state.card_instances.get(event_card_id)
		if event_instance == null:
			return false
		var event_definition = state.get_definition(event_instance.definition_id)
		if event_definition == null:
			return false
		if not event_card_type_is.is_empty():
			if event_card_type_is == "legion":
				if not _instance_counts_as_legion(state, event_instance):
					return false
			elif str(event_definition.type) != event_card_type_is:
				return false
		if not _definition_matches_required_faction_for_instance(state, event_instance, event_definition, event_card_faction_is):
			return false
		if event_card_cost_at_least >= 0 and int(event_definition.cost) < event_card_cost_at_least:
			return false
	var source_card_controller_is_controller = bool(condition.get("source_card_controller_is_controller", false))
	var source_card_controller_is_opponent = bool(condition.get("source_card_controller_is_opponent", false))
	if source_card_controller_is_controller or source_card_controller_is_opponent:
		var source_payload = event.payload
		if not (source_payload is Dictionary):
			return false
		var source_card_id = str(source_payload.get("source_card_id", ""))
		if source_card_id.is_empty():
			return false
		var source_controller := -1
		if _is_master_source_id(source_card_id):
			source_controller = _master_player_from_source_id(source_card_id)
		elif _is_morale_source_id(source_card_id):
			source_controller = _morale_player_from_source_id(source_card_id)
		else:
			var source_instance = state.card_instances.get(source_card_id)
			if source_instance == null:
				return false
			source_controller = int(source_instance.controller)
		if source_card_controller_is_controller and source_controller != trigger_controller:
			return false
		if source_card_controller_is_opponent and source_controller != 1 - trigger_controller:
			return false
	if bool(condition.get("source_card_id_is_self", false)):
		var payload = event.payload
		if not (payload is Dictionary) or str(payload.get("source_card_id", "")) != trigger_instance_id:
			return false
	var source_card_has_keyword = str(condition.get("source_card_has_keyword", ""))
	var source_card_faction = str(condition.get("source_card_faction", ""))
	if not source_card_has_keyword.is_empty() or not source_card_faction.is_empty():
		var payload = event.payload
		if not (payload is Dictionary):
			return false
		var source_card_id = str(payload.get("card_id", payload.get("source_card_id", "")))
		if source_card_id.is_empty():
			return false
		var source_instance = state.card_instances.get(source_card_id)
		if source_instance == null:
			return false
		var source_definition = state.get_definition(source_instance.definition_id)
		if source_definition == null:
			return false
		if not source_card_has_keyword.is_empty() and not _has_attack_keyword(state, source_card_id, source_card_has_keyword):
			return false
		if not _definition_matches_required_faction_for_instance(state, source_instance, source_definition, source_card_faction):
			return false
	return true


func _should_queue_trigger_for_event(event: GameEvent, effect: Dictionary) -> bool:
	if str(event.type) != "AttackFinished":
		return true
	if not bool(effect.get("self_only", false)):
		return true
	var resolution = effect.get("resolution", {})
	if not (resolution is Dictionary):
		return true
	if str(resolution.get("action", "")) != "return_source_to_deck_top":
		return true
	var payload = event.payload
	if not (payload is Dictionary):
		return false
	return str(payload.get("attacker_zone", "")).begins_with("battle_")

func _create_unimplemented_effect_event(state: GameState, stack_item: Dictionary, action: String, command_id: String) -> GameEvent:
	var event = GameEvent.create(state.next_event_id(), "UnimplementedEffectTriggered", int(stack_item.get("controller", state.active_player)), {
		"stack_id": str(stack_item.get("stack_id", "")),
		"source_id": str(stack_item.get("source_instance_id", "")),
		"effect_id": str(stack_item.get("effect_id", "")),
		"effect_type": str(stack_item.get("effect_type", "")),
		"action": action
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return event

func _find_effect_definition(state: GameState, source_id: String, effect_id: String, effect_kind: String) -> Dictionary:
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return {}
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return {}
	for effect in definition.effects:
		if str(effect.get("id", "")) != effect_id:
			continue
		if str(effect.get("kind", "")) != effect_kind:
			continue
		return effect.duplicate(true)
	return {}

func _find_effect_definition_by_id(state: GameState, source_id: String, effect_id: String) -> Dictionary:
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return {}
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return {}
	for effect in definition.effects:
		if str(effect.get("id", "")) == effect_id:
			return effect.duplicate(true)
	return {}

func _get_castable_tactic_effects(definition: CardDefinition) -> Array[Dictionary]:
	if definition == null:
		return []
	var result: Array[Dictionary] = []
	for effect in definition.effects:
		var kind = str(effect.get("kind", ""))
		if kind != "activated" and kind != "triggered":
			continue
		if bool(effect.get("hidden_from_actions", false)):
			continue
		result.append(effect.duplicate(true))
	return result

func _find_selected_tactic_effect(definition: CardDefinition, effect_id: String = "") -> Dictionary:
	var effects = _get_castable_tactic_effects(definition)
	if effects.is_empty():
		return {}
	if effect_id.is_empty():
		return effects[0].duplicate(true)
	for effect in effects:
		if str(effect.get("id", "")) == effect_id:
			return effect.duplicate(true)
	return {}

func _find_selected_hand_response_effect(definition: CardDefinition, effect_id: String = "") -> Dictionary:
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "activated":
			continue
		if not bool(effect.get("hand_response", false)):
			continue
		if effect_id.is_empty() or str(effect.get("id", "")) == effect_id:
			return effect.duplicate(true)
	return {}

func _find_pending_choice(state: GameState, choice_id: String) -> Dictionary:
	for choice in state.pending_choices:
		if choice_id.is_empty() or str(choice.get("choice_id", "")) == choice_id:
			return choice
	return {}

func _find_pending_choice_index(state: GameState, choice_id: String) -> int:
	for index in range(state.pending_choices.size()):
		var choice = state.pending_choices[index]
		if choice_id.is_empty() or str(choice.get("choice_id", "")) == choice_id:
			return index
	return -1

func _validate_search_choice_selection(choice: Dictionary, selected_card_ids: Array) -> Dictionary:
	var required_count = int(choice.get("count", 1))
	var candidates = choice.get("candidate_card_ids", [])
	if not (candidates is Array):
		return _error("INVALID_CHOICE", "candidate cards are missing")
	if selected_card_ids.size() != required_count:
		return _error("INVALID_CHOICE", "must select exactly %s card(s)" % required_count)
	var seen := {}
	for raw_card_id in selected_card_ids:
		var card_id = str(raw_card_id)
		if card_id.is_empty():
			return _error("INVALID_CHOICE", "choice contains an empty card id")
		if seen.has(card_id):
			return _error("INVALID_CHOICE", "choice contains duplicate cards")
		if not candidates.has(card_id):
			return _error("INVALID_CHOICE", "choice selected a card outside candidates")
		seen[card_id] = true
	return {"ok": true}

func _can_play_response_card_on_stack(state: GameState, command: GameCommand) -> bool:
	if command.type != "PlayCard":
		return false
	if state.stack.is_empty() and state.pending_attack.is_empty():
		return false
	var card_id = str(command.payload.get("card_id", ""))
	if card_id.is_empty():
		return false
	if command.player_id < 0 or command.player_id >= state.players.size():
		return false
	var player = state.get_player(command.player_id)
	if not player.hand.has_card(card_id):
		return false
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return false
	if definition.is_counter_tactic():
		if not _counter_tactics_require_set(state):
			return true
		var requested_effect_id = str(command.payload.get("effect_id", ""))
		var response_effect = _find_selected_tactic_effect(definition, requested_effect_id)
		return not response_effect.is_empty() and bool(response_effect.get("can_activate_on_stack", false))
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "activated" or not bool(effect.get("hand_response", false)):
			continue
		if _can_play_hand_response_legion(state, command.player_id, card_id, effect):
			return true
	return false

func _can_play_hand_response_legion(state: GameState, player_id: int, card_id: String, effect: Dictionary = {}) -> bool:
	if state.pending_attack.is_empty():
		return false
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null or not definition.is_legion():
		return false
	if effect.is_empty():
		effect = _find_selected_hand_response_effect(definition)
	if effect.is_empty():
		return false
	var attack = state.pending_attack
	var action := str(effect.get("resolution", {}).get("action", ""))
	if action == "deploy_source_from_hand_to_front_and_redirect_pending_attack" or action == "suncity_siwa_hand_response":
		return str(attack.get("target_kind", "")) == "master" \
			and int(attack.get("target_player", -1)) == player_id \
			and not _front_battlefield_slot_options(state, player_id).is_empty()
	if str(attack.get("target_kind", "card")) != "card":
		return false
	var defender_id = str(attack.get("defender_id", ""))
	var defender = state.card_instances.get(defender_id)
	return defender != null and defender.controller == player_id

func _is_counter_tactic_disabled_this_turn(state: GameState, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	return int(instance.flags.get("counter_tactic_disabled_turn", -1)) == state.turn_number \
		or int(instance.flags.get("counter_tactic_disabled_until_next_own_turn_start_player", -1)) != -1

func _counter_tactics_require_set(state: GameState) -> bool:
	return bool(state.rules_config.get("counter_tactics_require_set", false))

func _is_set_counter_tactic_source(state: GameState, source_id: String) -> bool:
	var instance = state.card_instances.get(source_id)
	if instance == null or not instance.zone.begins_with("battle_"):
		return false
	if str(instance.face) != "face_down":
		return false
	var definition = state.get_definition(instance.definition_id)
	return definition != null and definition.is_counter_tactic()

func _effect_can_activate_in_response_window(state: GameState, source_id: String, effect: Dictionary) -> bool:
	if bool(effect.get("can_activate_on_stack", false)):
		return true
	if _is_master_source_id(source_id):
		var master_player_id := _master_player_from_source_id(source_id)
		return _is_free_master_morale_effect_activation(state, master_player_id, source_id, effect)
	if not _is_set_counter_tactic_source(state, source_id):
		return false
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null:
		return false
	if _effect_has_response_source_event_filters(effect):
		return _response_window_has_matching_source_event_for_player(state, int(source_instance.controller), effect)
	return _response_window_has_enemy_action_for_player(state, int(source_instance.controller), effect)


func _effect_has_response_source_event_filters(effect: Dictionary) -> bool:
	var required_event_types = effect.get("response_created_from_event_types", [])
	var has_event_type_array: bool = required_event_types is Array and not required_event_types.is_empty()
	return has_event_type_array \
		or not str(effect.get("response_created_from_event_type", "")).is_empty() \
		or not str(effect.get("response_event_source_kind", "")).is_empty() \
		or not str(effect.get("response_event_from_orientation", "")).is_empty() \
		or not str(effect.get("response_event_from", "")).is_empty() \
		or not str(effect.get("response_event_from_not", "")).is_empty() \
		or not str(effect.get("response_event_card_type", "")).is_empty() \
		or not str(effect.get("response_event_card_controller_scope", "")).is_empty()


func _response_window_has_matching_source_event_for_player(state: GameState, player_id: int, effect: Dictionary) -> bool:
	for item in state.stack:
		if _stack_item_source_event_matches_response_filters(state, item, player_id, effect):
			return true
	return false


func _stack_item_source_event_matches_response_filters(state: GameState, stack_item: Dictionary, player_id: int, effect: Dictionary) -> bool:
	var source_event = _event_by_id(state, int(stack_item.get("created_from_event_id", 0)))
	if source_event == null:
		return false
	return _source_event_matches_response_filters(state, source_event, player_id, effect)


func _source_event_matches_response_filters(state: GameState, source_event, player_id: int, effect: Dictionary) -> bool:
	var required_event_types = effect.get("response_created_from_event_types", [])
	if required_event_types is Array and not required_event_types.is_empty():
		var matched_event_type := false
		for raw_event_type in required_event_types:
			if str(source_event.type) == str(raw_event_type):
				matched_event_type = true
				break
		if not matched_event_type:
			return false
	var required_event_type := str(effect.get("response_created_from_event_type", ""))
	if not required_event_type.is_empty() and str(source_event.type) != required_event_type:
		return false
	var payload = source_event.payload
	if not (payload is Dictionary):
		return false
	var required_source_kind := str(effect.get("response_event_source_kind", ""))
	if not required_source_kind.is_empty() and str(payload.get("source_kind", "")) != required_source_kind:
		return false
	var required_from_orientation := str(effect.get("response_event_from_orientation", ""))
	if not required_from_orientation.is_empty() and str(payload.get("from_orientation", "")) != required_from_orientation:
		return false
	var required_from := str(effect.get("response_event_from", ""))
	if not required_from.is_empty() and str(payload.get("from", "")) != required_from:
		return false
	var forbidden_from := str(effect.get("response_event_from_not", ""))
	if not forbidden_from.is_empty() and str(payload.get("from", "")) == forbidden_from:
		return false
	var response_card_id := str(payload.get("card_id", ""))
	var required_card_type := str(effect.get("response_event_card_type", ""))
	var required_controller_scope := str(effect.get("response_event_card_controller_scope", ""))
	if response_card_id.is_empty():
		return required_card_type.is_empty() and required_controller_scope.is_empty()
	var instance = state.card_instances.get(response_card_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	if not required_card_type.is_empty():
		if definition == null or str(definition.type) != required_card_type:
			return false
	if required_controller_scope == "ally":
		if instance == null or int(instance.controller) != player_id:
			return false
	elif required_controller_scope == "enemy":
		if instance == null or int(instance.controller) == player_id:
			return false
	return true


func _pending_attack_can_be_responded_to_by_player(state: GameState, player_id: int, effect: Dictionary = {}) -> bool:
	if state.pending_attack.is_empty():
		return false
	if bool(effect.get("response_requires_defense_selection", false)) and not _pending_attack_has_defense_selection(state.pending_attack):
		return false
	var attacker_id := str(state.pending_attack.get("attacker_id", ""))
	var attacker = state.card_instances.get(attacker_id)
	var required_controller_scope := str(effect.get("response_pending_attack_controller_scope", "enemy"))
	if attacker != null:
		if int(attacker.flags.get("suncity_ignore_counter_tactics_turn", -1)) == state.turn_number:
			return false
		if required_controller_scope == "ally":
			return int(attacker.controller) == player_id
		if required_controller_scope == "any":
			return true
		return int(attacker.controller) != player_id
	if required_controller_scope == "ally":
		return int(state.active_player) == player_id
	if required_controller_scope == "any":
		return true
	return int(state.active_player) != player_id


func _stack_item_can_be_responded_to_by_player(state: GameState, stack_item: Dictionary, player_id: int) -> bool:
	if not bool(stack_item.get("can_be_responded_to", true)):
		return false
	var source_id = str(stack_item.get("source_instance_id", ""))
	if not source_id.is_empty():
		var source_instance = state.card_instances.get(source_id)
		if source_instance != null and int(source_instance.flags.get("suncity_ignore_counter_tactics_turn", -1)) == state.turn_number:
			return false
	return int(stack_item.get("controller", player_id)) != player_id


func _response_window_has_enemy_action_for_player(state: GameState, player_id: int, effect: Dictionary = {}) -> bool:
	var effect_target_mode := _get_effect_target_mode(effect)
	var requires_pending_attack := bool(effect.get("response_requires_pending_attack", false))
	if _pending_attack_can_be_responded_to_by_player(state, player_id, effect):
		return true
	if requires_pending_attack:
		return false
	for item in state.stack:
		if not _stack_item_can_be_responded_to_by_player(state, item, player_id):
			continue
		if effect_target_mode == "stack" or effect.is_empty():
			return true
		return true
	return false

func _move_set_counter_to_stack_pending(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var instance = state.card_instances.get(card_id)
	if instance == null or not instance.zone.begins_with("battle_"):
		return []
	var from_zone := str(instance.zone)
	_remove_card_from_current_zone(state, card_id)
	instance.zone = "stack_pending"
	instance.position = {}
	instance.face = "face_up"
	instance.orientation = "active"
	var event = GameEvent.create(state.next_event_id(), "CounterTacticRevealed", player_id, {
		"card_id": card_id,
		"from": from_zone,
		"to": "stack_pending"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _get_effect_target_mode(effect: Dictionary) -> String:
	var explicit_target_mode = str(effect.get("target_mode", ""))
	if not explicit_target_mode.is_empty():
		return explicit_target_mode
	if effect.has("target_stack_controller_scope") or effect.has("target_stack_source_type") or effect.has("target_stack_source_types"):
		return "stack"
	var resolution = effect.get("resolution", {})
	if not (resolution is Dictionary):
		return "none"
	var resolution_target_mode = str(resolution.get("target_mode", ""))
	if not resolution_target_mode.is_empty():
		return resolution_target_mode
	var action = str(resolution.get("action", ""))
	if action == "counter_target_stack":
		return "stack"
	if action == "plague_infection_apply":
		return "plague_infection_target"
	if action == "destroy_target_unit" or action == "deal_legion_damage" or action == "return_target_unit_to_hand" or action == "return_target_unit_to_deck_bottom" or action == "grant_master_damage_bonus" or action == "modify_target_cost" or action == "modify_target_cost_until_next_own_turn_end" or action == "grant_front_attack_power_bonus":
		return "card"
	if action == "deal_master_damage" and str(resolution.get("target", "")) == "enemy_master":
		return "master"
	return "none"

func _validate_effect_cost(state: GameState, player_id: int, effect: Dictionary, options: Dictionary = {}) -> Dictionary:
	var cost = effect.get("cost", {})
	if cost is Dictionary:
		var morale_cost = _get_effective_effect_morale_cost(state, player_id, effect, options)
		if morale_cost > 0 and MoraleActions.count_active_morale(state, player_id) < morale_cost:
			return _error("NOT_ENOUGH_MORALE", "not enough morale for effect cost")
		var rune_cost = int(cost.get("rune", 0))
		if rune_cost > 0 and _player_rune_count(state, player_id) < rune_cost:
			return _error("NOT_ENOUGH_RUNES", "not enough runes for effect cost")
		var divine_cost = int(cost.get("divine", 0))
		if divine_cost > 0 and MoraleActions.count_active_divine_morale(state, player_id) < divine_cost:
			return _error("NOT_ENOUGH_DIVINE_MORALE", "not enough divine morale for effect cost")
		var divine_flip_cost = int(cost.get("divine_flip", 0))
		if divine_flip_cost > 0 and MoraleActions.count_active_divine_morale(state, player_id) < divine_flip_cost:
			return _error("NOT_ENOUGH_DIVINE_MORALE", "not enough divine morale for effect cost")
		var refund_morale_cost = int(cost.get("refund_morale", 0))
		if refund_morale_cost > 0 and MoraleActions.count_spent_morale(state, player_id) < refund_morale_cost:
			return _error("NOT_ENOUGH_SPENT_MORALE", "not enough spent morale for effect cost")
		var discard_cost = int(cost.get("discard_cards", 0))
		if discard_cost > 0:
			var hand_cards_after_source_leaves = int(options.get("hand_cards_after_source_leaves", state.get_player(player_id).hand.cards.size()))
			if hand_cards_after_source_leaves < discard_cost:
				return _error("NOT_ENOUGH_HAND_CARDS", "not enough hand cards for effect cost")
	return {"ok": true}

func _validate_effect_targets(state: GameState, command: GameCommand, effect: Dictionary) -> Dictionary:
	match _get_effect_target_mode(effect):
		"stack":
			var target_stack_id = str(command.payload.get("target_stack_id", ""))
			if target_stack_id.is_empty():
				return _error("INVALID_EFFECT_TARGET", "target_stack_id is required for counter effects")
			if target_stack_id == "__pending_attack__":
				if state.pending_attack.is_empty():
					return _error("INVALID_EFFECT_TARGET", "there is no pending attack to counter")
				if not _pending_attack_can_be_responded_to_by_player(state, command.player_id):
					return _error("INVALID_EFFECT_TARGET", "cannot counter your own pending attack")
				if not _stack_target_matches_effect_filters(state, effect, command.player_id, target_stack_id):
					return _error("INVALID_EFFECT_TARGET", "target stack item does not satisfy effect filters")
				return {"ok": true}
			for item in state.stack:
				if str(item.get("stack_id", "")) != target_stack_id:
					continue
				if not bool(item.get("can_be_responded_to", true)):
					return _error("INVALID_EFFECT_TARGET", "target stack item cannot be responded to")
				if not _stack_item_can_be_responded_to_by_player(state, item, command.player_id):
					return _error("INVALID_EFFECT_TARGET", "cannot counter your own stack item")
				if not _stack_target_matches_effect_filters(state, effect, command.player_id, target_stack_id, item):
					return _error("INVALID_EFFECT_TARGET", "target stack item does not satisfy effect filters")
				return {"ok": true}
			return _error("INVALID_EFFECT_TARGET", "target stack item does not exist")
		"card":
			var target_card_id = str(command.payload.get("target_card_id", ""))
			if target_card_id.is_empty():
				return _error("INVALID_EFFECT_TARGET", "target_card_id is required for unit-target effects")
			var instance = state.card_instances.get(target_card_id)
			if instance == null:
				return _error("INVALID_EFFECT_TARGET", "target unit does not exist")
			if not instance.zone.begins_with("battle_"):
				return _error("INVALID_EFFECT_TARGET", "target unit is not on the battlefield")
			if not _target_card_matches_effect_filters(state, effect, command.player_id, target_card_id):
				return _error("INVALID_EFFECT_TARGET", "target unit does not satisfy effect filters")
			return {"ok": true}
		"master":
			var target_player = int(command.payload.get("target_player", -1))
			if target_player < 0 or target_player >= state.players.size():
				return _error("INVALID_EFFECT_TARGET", "target_player is required for master-target effects")
			if target_player == command.player_id:
				return _error("INVALID_EFFECT_TARGET", "cannot target your own master")
			return {"ok": true}
		"plague_infection_target":
			var requested_target = _build_effect_targets(command, effect)
			for candidate in _build_legal_tactic_targets_for_effect(state, command.player_id, effect):
				var candidate_kind := str(candidate.get("target_kind", ""))
				if candidate_kind != str(requested_target.get("target_kind", "")):
					continue
				if candidate_kind == "card" and str(candidate.get("target_card_id", "")) == str(requested_target.get("target_card_id", "")):
					return {"ok": true}
				if candidate_kind == "morale_area" and int(candidate.get("target_player", -1)) == int(requested_target.get("target_player", -1)):
					return {"ok": true}
			return _error("INVALID_EFFECT_TARGET", "target does not satisfy plague infection requirements")
	return {"ok": true}

func _build_effect_targets(command: GameCommand, effect: Dictionary) -> Dictionary:
	match _get_effect_target_mode(effect):
		"stack":
			return {"target_stack_id": str(command.payload.get("target_stack_id", ""))}
		"card":
			return {"target_card_id": str(command.payload.get("target_card_id", ""))}
		"master":
			return {"target_player": int(command.payload.get("target_player", -1))}
		"plague_infection_target":
			return {
				"target_kind": str(command.payload.get("target_kind", "")),
				"target_card_id": str(command.payload.get("target_card_id", "")),
				"target_player": int(command.payload.get("target_player", -1))
			}
	return {}

func _pay_effect_costs(state: GameState, player_id: int, effect: Dictionary, command_id: String, options: Dictionary = {}) -> Dictionary:
	var events: Array = []
	var paid_costs: Array = []
	var cost = effect.get("cost", {})
	if cost is Dictionary:
		var morale_cost = _get_effective_effect_morale_cost(state, player_id, effect, options)
		if morale_cost > 0:
			events.append_array(MoraleActions.consume_morale(state, player_id, morale_cost, command_id))
			paid_costs.append({"type": "morale", "amount": morale_cost})
		var rune_cost = int(cost.get("rune", 0))
		if rune_cost > 0:
			events.append_array(_consume_player_runes(state, player_id, rune_cost, command_id))
			paid_costs.append({"type": "rune", "amount": rune_cost})
		var divine_cost = int(cost.get("divine", 0))
		if divine_cost > 0:
			events.append_array(MoraleActions.consume_divine_morale(state, player_id, divine_cost, command_id, false))
			paid_costs.append({"type": "divine", "amount": divine_cost})
		var divine_flip_cost = int(cost.get("divine_flip", 0))
		if divine_flip_cost > 0:
			events.append_array(MoraleActions.consume_divine_morale(state, player_id, divine_flip_cost, command_id, true))
			paid_costs.append({"type": "divine_flip", "amount": divine_flip_cost})
		var refund_morale_cost = int(cost.get("refund_morale", 0))
		if refund_morale_cost > 0:
			events.append_array(MoraleActions.refund_spent_morale(state, player_id, refund_morale_cost, command_id))
			paid_costs.append({"type": "refund_morale", "amount": refund_morale_cost})
		var discard_cost = int(cost.get("discard_cards", 0))
		if discard_cost > 0 and not bool(options.get("skip_discard_cards", false)):
			events.append_array(ZoneActions.discard_from_hand(
				state,
				player_id,
				discard_cost,
				command_id,
				_effect_event_source_options(str(options.get("source_id", "")))
			))
			paid_costs.append({"type": "discard_cards", "amount": discard_cost})
	return {"ok": true, "events": events, "paid_costs": paid_costs}

func _create_stack_item_from_effect(state: GameState, controller: int, source_id: String, effect: Dictionary, effect_type: String, paid_costs: Array, created_from_event_id: int, targets: Dictionary = {}) -> Dictionary:
	var resolution: Dictionary = effect.get("resolution", {}).duplicate(true)
	if effect_type == "triggered" and not resolution.has("optional"):
		var source_instance = state.card_instances.get(source_id)
		var source_definition = state.get_definition(source_instance.definition_id) if source_instance != null else null
		if source_definition != null and source_definition.is_counter_tactic():
			resolution["optional"] = true
		elif str(effect.get("text", "")).contains("可"):
			resolution["optional"] = true
	return {
		"stack_id": state.next_stack_id(),
		"controller": controller,
		"source_instance_id": source_id,
		"effect_id": str(effect.get("id", "")),
		"effect_text": str(effect.get("text", "")),
		"effect_type": effect_type,
		"targets": targets.duplicate(true),
		"choices": {},
		"paid_costs": paid_costs.duplicate(true),
		"cost": effect.get("cost", {}).duplicate(true) if effect.get("cost", {}) is Dictionary else {},
		"can_be_responded_to": bool(effect.get("can_be_responded_to", true)),
		"created_from_event_id": created_from_event_id,
		"resolution": resolution
	}

func _get_battlefield_card_ids(state: GameState) -> Array[String]:
	var result: Array[String] = []
	for player in state.players:
		for slot in player.battle_front:
			if not slot.occupant.is_empty():
				result.append(slot.occupant)
		for slot in player.battle_back:
			if not slot.occupant.is_empty():
				result.append(slot.occupant)
	return result

func _get_battlefield_legion_card_ids(state: GameState) -> Array[String]:
	var result: Array[String] = []
	for player_id in range(state.players.size()):
		result.append_array(_get_battlefield_legion_card_ids_for_player(state, player_id))
	return result

func _get_battlefield_card_ids_for_player(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	if player_id < 0 or player_id >= state.players.size():
		return result
	var player = state.get_player(player_id)
	for slot in player.battle_front:
		if not slot.occupant.is_empty():
			result.append(slot.occupant)
	for slot in player.battle_back:
		if not slot.occupant.is_empty():
			result.append(slot.occupant)
	return result

func _get_battlefield_legion_card_ids_for_player(state: GameState, player_id: int) -> Array[String]:
	var result: Array[String] = []
	for raw_card_id in _get_battlefield_card_ids_for_player(state, player_id):
		var card_id := str(raw_card_id)
		var instance = state.card_instances.get(card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null or not definition.is_legion():
			continue
		result.append(card_id)
	return result

func _controller_has_definition_on_battlefield(state: GameState, player_id: int, definition_id: String) -> bool:
	if definition_id.is_empty():
		return false
	for card_id in _get_battlefield_card_ids_for_player(state, player_id):
		var instance = state.card_instances.get(str(card_id))
		if instance == null:
			continue
		if str(instance.definition_id) == definition_id:
			return true
	return false

func _get_trigger_source_ids(state: GameState) -> Array[String]:
	var result = _get_battlefield_card_ids(state)
	for player in state.players:
		for card_id in player.artifact_zone.cards:
			result.append(card_id)
		for card_id in player.trial_zone.cards:
			result.append(card_id)
		for card_id in player.city_zone.cards:
			result.append(card_id)
		for card_id in player.hand.cards:
			var hand_card_id := str(card_id)
			var instance = state.card_instances.get(hand_card_id)
			if instance == null:
				continue
			var definition = state.get_definition(instance.definition_id)
			if definition == null:
				continue
			var has_hand_trigger := false
			for effect in definition.effects:
				if str(effect.get("kind", "")) != "triggered":
					continue
				if not bool(effect.get("allow_hand_source", false)):
					continue
				has_hand_trigger = true
				break
			if has_hand_trigger:
				result.append(hand_card_id)
		for card_id in player.grave.cards:
			var grave_card_id := str(card_id)
			var grave_instance = state.card_instances.get(grave_card_id)
			if grave_instance == null:
				continue
			var grave_definition = state.get_definition(grave_instance.definition_id)
			if grave_definition == null:
				continue
			var has_grave_trigger := false
			for effect in grave_definition.effects:
				if str(effect.get("kind", "")) != "triggered":
					continue
				if not bool(effect.get("allow_grave_source", false)):
					continue
				has_grave_trigger = true
				break
			if has_grave_trigger:
				result.append(grave_card_id)
	return result

func _target_card_matches_effect_filters(state: GameState, effect: Dictionary, controller: int, target_card_id: String) -> bool:
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return false
	if _is_concealed(state, target_card_id):
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return false
	var resolution = effect.get("resolution", {})
	if not (resolution is Dictionary):
		resolution = {}
	var target_scope = str(resolution.get("target_scope", ""))
	if target_scope == "enemy_battlefield" and instance.controller == controller:
		return false
	if target_scope == "allied_battlefield" and instance.controller != controller:
		return false
	var source_id = str(effect.get("source_id", ""))
	if bool(resolution.get("exclude_self", false)) and not source_id.is_empty() and target_card_id == source_id:
		return false
	var required_type = str(resolution.get("type", ""))
	if not required_type.is_empty():
		if required_type == "legion":
			if not _instance_counts_as_legion(state, instance):
				return false
		elif definition.type != required_type:
			return false
	var required_faction = str(resolution.get("faction", ""))
	if not _definition_matches_required_faction_for_instance(state, instance, definition, required_faction):
		return false
	var required_definition_id = str(resolution.get("id", ""))
	if not required_definition_id.is_empty() and str(definition.id) != required_definition_id:
		return false
	var name_contains = str(resolution.get("name_contains", ""))
	if not name_contains.is_empty() and not _definition_name_contains(definition, name_contains):
		return false
	var required_keyword = str(resolution.get("keyword", ""))
	if not required_keyword.is_empty() and not _has_attack_keyword(state, target_card_id, required_keyword):
		return false
	var min_target_cost = int(resolution.get("min_target_cost", -1))
	if min_target_cost >= 0 and _get_effective_card_cost(state, target_card_id) < min_target_cost:
		return false
	var max_target_cost = int(resolution.get("max_target_cost", -1))
	if max_target_cost >= 0 and _get_effective_card_cost(state, target_card_id) > max_target_cost:
		return false
	var max_target_power = int(resolution.get("max_target_power", -1))
	if max_target_power >= 0:
		var compared_power := get_card_power(state, target_card_id) if _uses_formal_rules(state) else int(definition.power)
		if compared_power > max_target_power:
			return false
	var max_original_power = int(resolution.get("max_original_power", -1))
	if max_original_power >= 0 and int(definition.power) > max_original_power:
		return false
	var required_calamity_level = int(resolution.get("calamity_level", -1))
	if required_calamity_level >= 0 and int(definition.calamity_level) != required_calamity_level:
		return false
	var max_calamity_level = int(resolution.get("max_calamity_level", -1))
	if max_calamity_level >= 0 and int(definition.calamity_level) > max_calamity_level:
		return false
	var required_row = str(resolution.get("required_row", ""))
	if not required_row.is_empty() and str(instance.position.get("row", "")) != required_row:
		return false
	var required_face = str(resolution.get("required_face", ""))
	if not required_face.is_empty() and str(instance.face) != required_face:
		return false
	var required_orientation = str(resolution.get("required_orientation", ""))
	if not required_orientation.is_empty() and str(instance.orientation) != required_orientation:
		return false
	if bool(resolution.get("moved_this_turn", false)) and not bool(instance.flags.get("moved_this_turn", false)):
		return false
	return true

func _is_concealed(state: GameState, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	return instance != null and bool(instance.flags.get("concealed", false))

func _get_effective_card_cost(state: GameState, card_id: String) -> int:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return 0
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return 0
	var modifier = int(instance.flags.get("cost_modifier_until_turn_end", 0))
	modifier += _timed_modifier_amount_for_card(state, card_id, "cost", false)
	return max(0, int(definition.cost) + modifier)

func _get_effective_play_cost(state: GameState, card_id: String, play_option: Dictionary = {}) -> int:
	var modified_cost = _get_base_effective_play_cost(state, card_id)
	if not play_option.is_empty():
		if _is_olympus_promotion_play_option(play_option):
			modified_cost = 0
		modified_cost += int(play_option.get("play_cost_modifier", 0))
	var instance = state.card_instances.get(card_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	if instance != null and definition != null and definition.is_tactic() and str(instance.zone) == "hand":
		var free_tactic_state = state.get_player(int(instance.owner)).flags.get("tianting_next_tactic_free", {})
		if free_tactic_state is Dictionary and int(free_tactic_state.get("turn", -1)) == state.turn_number and int(free_tactic_state.get("remaining", 0)) > 0:
			modified_cost = 0
	if state.current_calamity == "calamity_s02_ds06" and instance != null and definition != null and definition.is_legion() and str(instance.zone) == "hand":
		modified_cost += 1
	if state.current_calamity == "calamity_s01_ds01" and instance != null and definition != null and definition.is_tactic() and str(instance.zone) == "hand":
		if int(instance.owner) == state.active_player and _dark_morning_star_effect_for_player(state, state.active_player) == "free_tactic":
			modified_cost = 0
	return max(0, modified_cost)

func _get_effective_effect_morale_cost(state: GameState, player_id: int, effect: Dictionary, options: Dictionary = {}) -> int:
	var cost = effect.get("cost", {})
	if not (cost is Dictionary):
		return 0
	if _is_free_master_morale_effect_activation(state, player_id, str(options.get("source_id", "")), effect):
		return 0
	var morale_cost = int(cost.get("morale", 0))
	var source_id := str(options.get("source_id", ""))
	if state.current_calamity == "calamity_s02_ds06" and _is_master_source_id(source_id) and _master_player_from_source_id(source_id) == player_id:
		morale_cost += 1
	return morale_cost

func _player_rune_count(state: GameState, player_id: int) -> int:
	if player_id < 0 or player_id >= state.players.size():
		return 0
	return int(state.get_player(player_id).counters.get("rune", 0))

func _add_player_runes(state: GameState, player_id: int, count: int, command_id: String) -> Array:
	if player_id < 0 or player_id >= state.players.size() or count <= 0:
		return []
	var player = state.get_player(player_id)
	var before := int(player.counters.get("rune", 0))
	player.counters["rune"] = before + count
	var event = GameEvent.create(state.next_event_id(), "RuneChanged", player_id, {
		"before": before,
		"after": int(player.counters.get("rune", 0)),
		"delta": count
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _consume_player_runes(state: GameState, player_id: int, count: int, command_id: String) -> Array:
	if player_id < 0 or player_id >= state.players.size() or count <= 0:
		return []
	var player = state.get_player(player_id)
	var before := int(player.counters.get("rune", 0))
	if before < count:
		return []
	player.counters["rune"] = before - count
	var event = GameEvent.create(state.next_event_id(), "RuneChanged", player_id, {
		"before": before,
		"after": int(player.counters.get("rune", 0)),
		"delta": -count
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _resolve_trial_progress_target_id(state: GameState, controller: int, source_id: String, resolution: Dictionary) -> String:
	var explicit_target_id := str(resolution.get("target_card_id", ""))
	if not explicit_target_id.is_empty():
		return explicit_target_id
	var target_mode := str(resolution.get("target", ""))
	if target_mode == "source":
		return source_id
	if target_mode == "first_trial" or target_mode.is_empty():
		for card_id in state.get_player(controller).trial_zone.cards:
			var trial_id := str(card_id)
			var trial_instance = state.card_instances.get(trial_id)
			if trial_instance == null:
				continue
			if bool(resolution.get("skip_completed", false)) and bool(trial_instance.flags.get("trial_completed", false)):
				continue
			return trial_id
	if source_id.is_empty():
		return ""
	var source_instance = state.card_instances.get(source_id)
	if source_instance != null and str(source_instance.zone) == "trial_zone":
		return source_id
	return ""

func _advance_trial_progress(state: GameState, stack_item: Dictionary, resolution: Dictionary, command_id: String) -> Array:
	var controller := int(stack_item.get("controller", state.active_player))
	var source_id := str(stack_item.get("source_instance_id", ""))
	var target_id := _resolve_trial_progress_target_id(state, controller, source_id, resolution)
	if target_id.is_empty():
		return []
	var instance = state.card_instances.get(target_id)
	if instance == null or str(instance.zone) != "trial_zone":
		return []
	var amount := int(resolution.get("count", resolution.get("amount", 1)))
	if amount == 0:
		return []
	var before := int(instance.flags.get("trial_progress", 0))
	var after: int = max(0, before + amount)
	instance.flags["trial_progress"] = after
	var events: Array = []
	var progress_event = GameEvent.create(state.next_event_id(), "TrialProgressChanged", controller, {
		"card_id": target_id,
		"source_card_id": source_id,
		"before": before,
		"after": after,
		"delta": after - before
	})
	progress_event.created_by_command = command_id
	state.event_log.append(progress_event)
	events.append(progress_event)
	var complete_at := int(resolution.get("complete_at", -1))
	if complete_at >= 0 and after >= complete_at and not bool(instance.flags.get("trial_completed", false)):
		instance.flags["trial_completed"] = true
		var complete_event = GameEvent.create(state.next_event_id(), "TrialCompleted", controller, {
			"card_id": target_id,
			"source_card_id": source_id,
			"progress": after
		})
		complete_event.created_by_command = command_id
		state.event_log.append(complete_event)
		events.append(complete_event)
	return events

func _get_base_effective_play_cost(state: GameState, card_id: String) -> int:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return 0
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return 0
	var modified_cost = int(definition.cost)
	var owner_player = state.get_player(int(instance.owner))
	if str(definition.id) == "suncity_s01_0202" and not _controller_has_definition_on_battlefield(state, int(instance.controller), "suncity_s01_0212"):
		modified_cost = max(0, modified_cost - 2)
	if str(definition.id) == "suncity_s02_0203" and not _controller_has_definition_on_battlefield(state, int(instance.controller), "suncity_s01_0212"):
		modified_cost = max(0, modified_cost - 1)
	if str(definition.id) == "suncity_s02_0202":
		modified_cost = max(0, modified_cost - int(owner_player.flags.get("suncity_tomb_left_count", 0)))
	for effect in definition.effects:
		if str(effect.get("kind", "")) != "continuous":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary):
			continue
		if str(resolution.get("action", "")) != "modify_play_cost":
			continue
		if bool(resolution.get("controller_morale_less_than_opponent", false)):
			if MoraleActions.count_active_morale(state, int(instance.owner)) >= MoraleActions.count_active_morale(state, 1 - int(instance.owner)):
				continue
		var own_divine_at_least = int(resolution.get("own_divine_at_least", -1))
		if own_divine_at_least >= 0 and MoraleActions.count_divine_morale(state, int(instance.owner)) < own_divine_at_least:
			continue
		var own_divine_at_most = int(resolution.get("own_divine_at_most", -1))
		if own_divine_at_most >= 0 and MoraleActions.count_divine_morale(state, int(instance.owner)) > own_divine_at_most:
			continue
		var own_divine_equals = int(resolution.get("own_divine_equals", -1))
		if own_divine_equals >= 0 and MoraleActions.count_divine_morale(state, int(instance.owner)) != own_divine_equals:
			continue
		var own_master_hp_at_most = int(resolution.get("own_master_hp_at_most", -1))
		if own_master_hp_at_most >= 0 and owner_player.master_hp > own_master_hp_at_most:
			continue
		var required_battlefield_definition_id = str(resolution.get("controller_has_battlefield_definition", ""))
		if not required_battlefield_definition_id.is_empty() and not _controller_has_definition_on_battlefield(state, int(instance.controller), required_battlefield_definition_id):
			continue
		var cost_delta = int(resolution.get("amount", 0))
		var allied_battlefield_count_multiplier = int(resolution.get("allied_battlefield_count_multiplier", 0))
		if allied_battlefield_count_multiplier != 0:
			var required_allied_faction = str(resolution.get("allied_battlefield_matching_faction", ""))
			var required_allied_type = str(resolution.get("allied_battlefield_matching_type", ""))
			var allied_count = 0
			for allied_card_id in _get_battlefield_card_ids_for_player(state, int(instance.owner)):
				var allied_instance = state.card_instances.get(str(allied_card_id))
				if allied_instance == null:
					continue
				var allied_definition = state.get_definition(allied_instance.definition_id)
				if allied_definition == null:
					continue
				if not _definition_matches_required_faction_for_instance(state, allied_instance, allied_definition, required_allied_faction):
					continue
				if not required_allied_type.is_empty():
					if required_allied_type == "legion":
						if not allied_definition.is_legion():
							continue
					elif str(allied_definition.type) != required_allied_type:
						continue
				if not str(allied_card_id).is_empty():
					allied_count += 1
			cost_delta += allied_battlefield_count_multiplier * allied_count
		var own_grave_count_divisor = int(resolution.get("own_grave_count_divisor", 0))
		var own_grave_count_multiplier = int(resolution.get("own_grave_count_multiplier", 0))
		if own_grave_count_divisor > 0 and own_grave_count_multiplier != 0:
			var required_grave_faction = str(resolution.get("own_grave_matching_faction", ""))
			var required_grave_type = str(resolution.get("own_grave_matching_type", ""))
			var grave_count = 0
			for grave_card_id in owner_player.grave.cards:
				var grave_instance = state.card_instances.get(str(grave_card_id))
				if grave_instance == null:
					continue
				var grave_definition = state.get_definition(grave_instance.definition_id)
				if grave_definition == null:
					continue
				if not _definition_matches_required_faction_for_instance(state, grave_instance, grave_definition, required_grave_faction):
					continue
				if not required_grave_type.is_empty() and str(grave_definition.type) != required_grave_type:
					continue
				grave_count += 1
			cost_delta += own_grave_count_multiplier * int(floor(float(grave_count) / float(own_grave_count_divisor)))
		modified_cost += cost_delta
	var pending_modifier = owner_player.flags.get("next_played_legion_cost_modifier", {})
	if pending_modifier is Dictionary and int(pending_modifier.get("turn", -1)) == state.turn_number and definition.is_legion():
		var required_definition_id = str(pending_modifier.get("definition_id", ""))
		var max_cost = int(pending_modifier.get("max_cost", -1))
		var required_faction = str(pending_modifier.get("faction", ""))
		if (required_definition_id.is_empty() or required_definition_id == str(definition.id)) and _definition_matches_required_faction_for_player(state, owner_player.player_id, definition, required_faction) and (max_cost < 0 or int(definition.cost) <= max_cost):
			modified_cost += int(pending_modifier.get("amount", 0))
	var suncity_pending = owner_player.flags.get("suncity_next_calamity_discount", {})
	if suncity_pending is Dictionary and int(suncity_pending.get("turn", -1)) == state.turn_number and definition.is_legion() and int(definition.calamity_level) > 0:
		modified_cost += int(suncity_pending.get("amount", 0))
	modified_cost += _timed_modifier_amount_for_card(state, card_id, "cost", false)
	return max(0, modified_cost)

func _get_minimum_play_cost(state: GameState, card_id: String) -> int:
	var min_cost = _get_base_effective_play_cost(state, card_id)
	for option in _get_available_play_options(state, card_id):
		min_cost = min(min_cost, _get_effective_play_cost(state, card_id, option))
	return max(0, min_cost)

func _get_available_play_options(state: GameState, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return result
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return result
	for raw_option in definition.play_options:
		if raw_option is Dictionary:
			result.append(raw_option.duplicate(true))
	if result.is_empty():
		return result
	for play_option in result:
		if bool(play_option.get("replace_default_play_option", false)):
			return result
	result.insert(0, {
		"id": "default",
		"label": "正常登场"
	})
	return result

func _is_olympus_promotion_play_option(play_option: Dictionary) -> bool:
	return play_option is Dictionary and bool(play_option.get("olympus_promotion", false))

func _deploy_olympus_promotion_to_slot(state: GameState, player_id: int, card_id: String, row: String, col: int, play_option: Dictionary, command_id: String) -> Array:
	var events: Array = []
	var player = state.get_player(player_id)
	var slot = player.get_slot(row, col)
	if slot == null or slot.occupant.is_empty() or not slot.cover.is_empty():
		return events
	var base_card_id = str(slot.occupant)
	var base_instance = state.card_instances.get(base_card_id)
	var promoted_instance = state.card_instances.get(card_id)
	if base_instance == null or promoted_instance == null:
		return events
	slot.cover = base_card_id
	slot.occupant = card_id
	promoted_instance.zone = "battle_%s" % row
	promoted_instance.position = {"row": row, "col": col}
	promoted_instance.orientation = str(base_instance.orientation)
	promoted_instance.face = "face_up"
	promoted_instance.damage_marked = 0
	promoted_instance.controller = player_id
	promoted_instance.overlay_cards.clear()
	promoted_instance.overlay_cards.append(base_card_id)
	promoted_instance.flags["promotion_base_card_id"] = base_card_id
	base_instance.zone = "battle_%s" % row
	base_instance.position = {"row": row, "col": col}
	base_instance.flags["overlaid_by_card_id"] = card_id
	_consume_next_played_legion_cost_modifier(state, player_id, card_id)
	_consume_suncity_next_calamity_discount(state, player_id, card_id)
	events.append_array(_apply_next_played_legion_keyword(state, player_id, card_id, command_id))
	var event = GameEvent.create(state.next_event_id(), "CardOverlayAttached", player_id, {
		"base_card_id": base_card_id,
		"cover_card_id": card_id,
		"row": row,
		"col": col,
		"kind": "promotion"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	events.append(event)
	_refresh_continuous_modifiers(state)
	return events

func _find_selected_play_option(options: Array[Dictionary], option_id: String) -> Dictionary:
	if option_id.is_empty():
		return {}
	for option in options:
		if str(option.get("id", "")) == option_id:
			return option.duplicate(true)
	return {}

func _selected_grave_card_ids_from_payload(payload: Dictionary) -> Array[String]:
	var selected_raw = payload.get("selected_grave_card_ids", [])
	var selected: Array[String] = []
	if selected_raw is Array:
		for raw_card_id in selected_raw:
			var grave_card_id = str(raw_card_id)
			if grave_card_id.is_empty() or selected.has(grave_card_id):
				continue
			selected.append(grave_card_id)
	return selected

func _resolved_play_option_for_payload(play_option: Dictionary, payload: Dictionary) -> Dictionary:
	if play_option.is_empty():
		return {}
	var resolved = play_option.duplicate(true)
	var recycle_up_to_count = int(play_option.get("recycle_own_grave_up_to_count", 0))
	if recycle_up_to_count > 0:
		var selected = _selected_grave_card_ids_from_payload(payload)
		var recycle_count = min(selected.size(), recycle_up_to_count)
		var reduction_step = max(1, int(play_option.get("recycle_own_grave_cost_reduction_step", 2)))
		var reduction_amount = max(1, int(play_option.get("recycle_own_grave_cost_reduction_amount", 1)))
		resolved["recycle_own_grave_count"] = recycle_count
		resolved["play_cost_modifier"] = -int(floor(float(recycle_count) / float(reduction_step))) * reduction_amount
	return resolved

func _validate_play_option_payload(state: GameState, player_id: int, card_id: String, play_option: Dictionary, payload: Dictionary) -> Dictionary:
	if play_option.is_empty() or str(play_option.get("id", "")) == "default":
		return {"ok": true}
	var requested_host_player = int(payload.get("host_player", player_id))
	if requested_host_player != player_id:
		if not bool(play_option.get("allow_foreign_battlefield", false)):
			return _error("INVALID_PLAY_OPTION", "play option does not allow foreign battlefield deployment")
		if requested_host_player < 0 or requested_host_player >= state.players.size():
			return _error("INVALID_PLAY_OPTION", "requested host battlefield is invalid")
	var rune_cost = int(play_option.get("rune_cost", 0))
	if rune_cost > 0 and _player_rune_count(state, player_id) < rune_cost:
		return _error("NOT_ENOUGH_RUNES", "not enough runes for play option")
	if _is_olympus_promotion_play_option(play_option):
		var row = str(payload.get("row", ""))
		var col = int(payload.get("col", -1))
		if row != "front" and row != "back":
			return _error("INVALID_PLAY_OPTION", "promotion must target a battlefield slot")
		var player = state.get_player(player_id)
		var slot = player.get_slot(row, col)
		if slot == null:
			return _error("INVALID_SLOT", "target slot does not exist")
		if slot.occupant.is_empty():
			return _error("INVALID_PLAY_OPTION", "promotion requires a same-name base legion on the battlefield")
		if not slot.cover.is_empty():
			return _error("INVALID_PLAY_OPTION", "target slot already has a promoted card")
		var required_base_definition_id = str(play_option.get("promotion_base_definition_id", ""))
		var base_instance = state.card_instances.get(str(slot.occupant))
		if base_instance == null:
			return _error("INVALID_PLAY_OPTION", "promotion base card is missing")
		if required_base_definition_id.is_empty() or str(base_instance.definition_id) != required_base_definition_id:
			return _error("INVALID_PLAY_OPTION", "target legion does not match the required promotion base")
		var divine_flip_cost = int(play_option.get("promotion_divine_flip_cost", 0))
		var discounted_cost = max(0, divine_flip_cost - _olympus_promotion_divine_flip_discount(state, player_id))
		if discounted_cost > 0 and MoraleActions.count_active_divine_morale(state, player_id) < discounted_cost:
			return _error("NOT_ENOUGH_DIVINE_MORALE", "not enough divine morale for promotion")
	var recycle_count = int(play_option.get("recycle_own_grave_count", 0))
	var recycle_up_to_count = int(play_option.get("recycle_own_grave_up_to_count", 0))
	if recycle_count <= 0 and recycle_up_to_count <= 0:
		return {"ok": true}
	var selected = _selected_grave_card_ids_from_payload(payload)
	if recycle_up_to_count > 0:
		if selected.size() > recycle_up_to_count:
			return _error("INVALID_PLAY_OPTION", "selected grave card count exceeds play option maximum", {
				"max_count": recycle_up_to_count
			})
		recycle_count = selected.size()
	elif selected.size() != recycle_count:
		return _error("INVALID_PLAY_OPTION", "selected grave card count does not match play option requirement", {
			"required_count": recycle_count
		})
	var player = state.get_player(player_id)
	var required_faction = str(play_option.get("recycle_own_grave_faction", ""))
	var required_type = str(play_option.get("recycle_own_grave_type", ""))
	for grave_card_id in selected:
		if not player.grave.cards.has(grave_card_id):
			return _error("INVALID_PLAY_OPTION", "selected grave card is not in your grave")
		var instance = state.card_instances.get(grave_card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null:
			return _error("INVALID_PLAY_OPTION", "selected grave card definition is missing")
		if not _definition_matches_required_faction_for_instance(state, instance, definition, required_faction):
			return _error("INVALID_PLAY_OPTION", "selected grave card does not match required faction")
		if not required_type.is_empty() and str(definition.type) != required_type:
			return _error("INVALID_PLAY_OPTION", "selected grave card does not match required type")
	return {"ok": true}

func _apply_play_option_before_play(state: GameState, player_id: int, card_id: String, play_option: Dictionary, payload: Dictionary, command_id: String) -> Array:
	var events: Array = []
	if play_option.is_empty() or str(play_option.get("id", "")) == "default":
		return events
	var rune_cost = int(play_option.get("rune_cost", 0))
	if rune_cost > 0:
		events.append_array(_consume_player_runes(state, player_id, rune_cost, command_id))
	var promotion_divine_flip_cost = int(play_option.get("promotion_divine_flip_cost", 0))
	var discounted_cost = max(0, promotion_divine_flip_cost - _olympus_promotion_divine_flip_discount(state, player_id))
	if discounted_cost > 0:
		events.append_array(MoraleActions.consume_divine_morale(state, player_id, discounted_cost, command_id, true))
	if promotion_divine_flip_cost > discounted_cost:
		state.get_player(player_id).flags.erase("olympus_promotion_divine_flip_discount")
	var recycle_count = int(play_option.get("recycle_own_grave_count", 0))
	if recycle_count > 0:
		var selected = _selected_grave_card_ids_from_payload(payload)
		var player = state.get_player(player_id)
		for grave_card_id in selected:
			if not player.grave.cards.has(grave_card_id):
				continue
			player.grave.remove_card(grave_card_id)
			player.deck.add_card(grave_card_id)
			var grave_instance = state.card_instances.get(grave_card_id)
			if grave_instance != null:
				grave_instance.zone = "deck"
				grave_instance.position = {}
				grave_instance.controller = grave_instance.owner
				grave_instance.orientation = "active"
				grave_instance.face = "face_down"
				grave_instance.damage_marked = 0
			var recycle_event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", player_id, {
				"card_id": grave_card_id,
				"from": "grave",
				"to": "deck_bottom",
				"reason": "play_option",
				"source_card_id": card_id
			})
			recycle_event.created_by_command = command_id
			state.event_log.append(recycle_event)
			events.append(recycle_event)
	var self_master_damage = int(play_option.get("self_master_damage", 0))
	if self_master_damage > 0:
		events.append_array(_deal_master_damage(state, player_id, self_master_damage, command_id, {
			"source_card_id": card_id,
			"source_kind": "play_option"
		}))
	return events


func _tianting_named_hand_candidates(state: GameState, player_id: int, names: Array) -> Array[String]:
	var result: Array[String] = []
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(str(card_id))
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null:
			continue
		if names.has(str(definition.name)):
			result.append(str(card_id))
	return result


func _tianting_named_deck_candidates(state: GameState, player_id: int, names: Array) -> Array[String]:
	var result: Array[String] = []
	for card_id in state.get_player(player_id).deck.cards:
		var instance = state.card_instances.get(str(card_id))
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null:
			continue
		if names.has(str(definition.name)):
			result.append(str(card_id))
	return result


func _tianting_reveal_card(state: GameState, player_id: int, card_id: String, from: String, command_id: String) -> Array:
	if card_id.is_empty():
		return []
	var event = GameEvent.create(state.next_event_id(), "CardRevealed", player_id, {
		"card_id": card_id,
		"from": from
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _broadcast_revealed_cards_popup(state: GameState, player_id: int, card_ids: Array, title: String, command_id: String) -> Array:
	var revealed_card_ids: Array[String] = []
	for raw_card_id in card_ids:
		var card_id := str(raw_card_id)
		if card_id.is_empty():
			continue
		revealed_card_ids.append(card_id)
	if revealed_card_ids.is_empty():
		return []
	var event = GameEvent.create(state.next_event_id(), "CardsRevealedToAll", player_id, {
		"revealing_player_id": player_id,
		"title": title if not title.is_empty() else "展示的卡牌",
		"card_ids": revealed_card_ids.duplicate()
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _tianting_pingyang_attack_reveal_top(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	if player.deck.cards.is_empty():
		return []
	var top_id = str(player.deck.cards[0])
	var instance = state.card_instances.get(top_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	var events = _tianting_reveal_card(state, controller, top_id, "deck_top", command_id)
	if _definition_matches_required_faction_for_instance(state, instance, definition, "tianting") and int(definition.cost) <= 5:
		var source_id = str(stack_item.get("source_instance_id", ""))
		if not source_id.is_empty():
			events.append_array(_modify_power_until_turn_end(state, source_id, 2000, command_id))
		return events
	player.deck.remove_card(top_id)
	player.deck.cards.append(top_id)
	return events




func _tianting_limu_entry_reveal_top_tactic(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	if player.deck.cards.is_empty():
		return []
	var top_id = str(player.deck.cards[0])
	var instance = state.card_instances.get(top_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	var events = _tianting_reveal_card(state, controller, top_id, "deck_top", command_id)
	var follow_up_action = {"optional": true, "action": "draw_cards", "count": 1}
	if definition == null or not definition.is_tactic() or int(definition.cost) > 4:
		player.deck.remove_card(top_id)
		player.deck.cards.append(top_id)
		events.append_array(_resolve_stack_follow_up_action(state, stack_item, follow_up_action, command_id))
		return events
	var options := [
		{"id": "play", "label": "无需消耗费用打出"},
		{"id": "bottom", "label": "放回牌库底部"}
	]
	events.append_array(_request_option_choice(state, controller, options, "李牧：选择处理方式", "tianting_limu_reveal_top_tactic_choice", {
		"card_id": top_id,
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"follow_up_action": follow_up_action
	}, command_id))
	return events


func _tianting_yangyouji_enable_back_attack(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return []
	instance.flags["yangyouji_can_attack_back_row_turn"] = int(state.turn_number)
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"card_id": source_id,
		"buff": "yangyouji_can_attack_back_row"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _tianting_freeze_enemy_units(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var max_count = max(1, int(resolution.get("count", 1)))
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, 1 - controller):
		var instance = state.card_instances.get(str(card_id))
		if instance == null or str(instance.orientation) != "rested":
			continue
		if not _target_card_matches_stack_resolution_filters(state, stack_item, str(card_id)):
			continue
		candidates.append(str(card_id))
	if candidates.is_empty():
		return []
	var chosen = candidates.slice(0, min(max_count, candidates.size()))
	var events: Array = []
	for card_id in chosen:
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		instance.flags["cannot_ready_on_ready_phase_player"] = int(instance.controller)
		var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
			"card_id": card_id,
			"buff": "cannot_ready_on_ready_phase"
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		events.append(event)
	return events


func _tianting_freeze_enemy_morale(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var enemy = state.get_player(1 - controller)
	var candidates: Array[String] = []
	for card_id in enemy.cost_area.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.orientation) == "rested":
			candidates.append(str(card_id))
	if candidates.is_empty():
		return []
	if candidates.size() > 1:
		return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要冻结的对方休整士气", "tianting_freeze_enemy_morale_pick", {
			"initiator_player": controller,
			"source_instance_id": str(stack_item.get("source_instance_id", ""))
		}, command_id)
	var target_id = str(candidates[0])
	var target_instance = state.card_instances.get(target_id)
	target_instance.flags["cannot_ready_on_ready_phase_player"] = int(target_instance.controller)
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(target_instance.controller), {
		"card_id": target_id,
		"buff": "cannot_ready_on_ready_phase"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _plague_infection_apply(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return []
	if str(targets.get("target_kind", "")) == "morale_area":
		var enemy = state.get_player(1 - controller)
		enemy.flags["suncity_skip_next_ready_morale_count"] = int(enemy.flags.get("suncity_skip_next_ready_morale_count", 0)) + 1
		var morale_event = GameEvent.create(state.next_event_id(), "StatusApplied", 1 - controller, {
			"status": "suncity_skip_next_ready_morale",
			"count": int(enemy.flags.get("suncity_skip_next_ready_morale_count", 0))
		})
		morale_event.created_by_command = command_id
		state.event_log.append(morale_event)
		return [morale_event]
	var target_card_id = str(targets.get("target_card_id", ""))
	if target_card_id.is_empty():
		return []
	var instance = state.card_instances.get(target_card_id)
	if instance == null or not str(instance.zone).begins_with("battle_") or int(instance.controller) != 1 - controller:
		return []
	instance.flags["cannot_ready_on_ready_phase_player"] = int(instance.controller)
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": target_card_id,
		"buff": "cannot_ready_on_ready_phase"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _tianting_reset_master_effect_once(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	for key in player.once_per_turn.keys():
		if str(key) == "faction_morale":
			continue
		player.once_per_turn.erase(key)
		var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
			"card_id": str(stack_item.get("source_instance_id", "")),
			"buff": "master_once_per_turn_reset",
			"effect_key": str(key)
		})
		event.created_by_command = command_id
		state.event_log.append(event)
		return [event]
	return []


func _tianting_sunwu_prepare_free_tactic(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	state.get_player(controller).flags["tianting_next_tactic_free"] = {
		"turn": state.turn_number,
		"remaining": 1
	}
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", controller, {
		"card_id": str(stack_item.get("source_instance_id", "")),
		"buff": "next_tactic_free"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _tianting_liu_bei_deploy_brother(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates = _tianting_named_hand_candidates(state, controller, ["关羽", "张飞"])
	if candidates.is_empty():
		return []
	var slot_options = _battlefield_slot_options(state, controller)
	if slot_options.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择手牌中的关羽或张飞登场", "deploy_from_hand_to_battlefield", {
		"slot_options": slot_options.duplicate(true),
		"deployment_orientation": "active"
	}, command_id)


func _tianting_liu_bei_search_brother(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates = _tianting_named_deck_candidates(state, controller, ["关羽", "张飞"])
	if candidates.is_empty():
		return []
	var target_id = str(candidates[0])
	var player = state.get_player(controller)
	player.deck.remove_card(target_id)
	player.hand.add_card(target_id)
	var instance = state.card_instances.get(target_id)
	if instance != null:
		instance.zone = "hand"
		instance.position = {}
		instance.controller = instance.owner
		instance.orientation = "active"
	var events: Array = []
	events.append_array(_tianting_reveal_card(state, controller, target_id, "deck", command_id))
	var move_event = GameEvent.create(state.next_event_id(), "CardReturnedToHand", controller, _merge_event_payload_options({
		"card_id": target_id,
		"from": "deck",
		"to": "hand"
	}, _effect_event_options_from_stack_item(state, stack_item, stack_item.get("resolution", {}))))
	move_event.created_by_command = command_id
	state.event_log.append(move_event)
	events.append(move_event)
	player.deck.shuffle()
	return events


func _tianting_mozi_grant_cannot_die(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(str(card_id))
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null or not _definition_matches_required_faction_for_instance(state, instance, definition, "tianting"):
			continue
		candidates.append(str(card_id))
	if candidates.is_empty():
		return []
	var events: Array = []
	for index in range(min(2, candidates.size())):
		events.append_array(_grant_cannot_die_once_until_next_own_turn_start(state, {
			"controller": controller,
			"targets": {"target_card_id": str(candidates[index])},
			"resolution": {}
		}, command_id))
	return events


func _tianting_refund_all_morale(state: GameState, player_id: int, command_id: String) -> Array:
	var spent_count = state.get_player(player_id).spent_cost_area.cards.size()
	if spent_count <= 0:
		return []
	return MoraleActions.ready_spent_morale(state, player_id, spent_count, command_id)


func _tianting_yingzheng_entry(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	var player = state.get_player(controller)
	var discard_id := ""
	for card_id in player.hand.cards:
		var instance = state.card_instances.get(str(card_id))
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null or not definition.is_legion():
			continue
		if int(definition.cost) == 8 and str(card_id) != source_id:
			discard_id = str(card_id)
			break
	if discard_id.is_empty():
		var reveal_events: Array = []
		for card_id in player.hand.cards:
			reveal_events.append_array(_tianting_reveal_card(state, controller, str(card_id), "hand", command_id))
		return reveal_events
	var events = ZoneActions.discard_specific_from_hand(
		state,
		controller,
		[discard_id],
		command_id,
		_effect_event_source_options(source_id)
	)
	for card_id in _get_battlefield_card_ids(state):
		if str(card_id) == source_id:
			continue
		var instance = state.card_instances.get(str(card_id))
		if instance == null:
			continue
		var row = str(instance.position.get("row", ""))
		var col = int(instance.position.get("col", -1))
		if row.is_empty() or col < 0:
			continue
		events.append_array(ZoneActions.move_battlefield_to_grave(state, int(instance.controller), row, col, command_id))
	events.append_array(_tianting_refund_all_morale(state, controller, command_id))
	player.flags["tianting_morale_add_locked_turn"] = state.turn_number
	return events


func _tianting_shanhe_scout(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	var events: Array = []
	var looked: Array[String] = []
	for index in range(min(3, player.deck.cards.size())):
		var card_id = str(player.deck.cards[index])
		looked.append(card_id)
		events.append_array(_tianting_reveal_card(state, controller, card_id, "deck_top", command_id))
	var candidates: Array[String] = []
	for card_id in looked:
		var instance = state.card_instances.get(card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if _definition_matches_required_faction_for_instance(state, instance, definition, "tianting"):
			candidates.append(card_id)
	if candidates.size() >= 2:
		events.append_array(_request_candidate_cards_choice(state, controller, candidates, 1, "山河社稷图：选择加入手牌的天廷卡", "tianting_shanhe_pick_card", {
			"looked": looked.duplicate(),
			"source_instance_id": str(stack_item.get("source_instance_id", ""))
		}, command_id))
	elif candidates.size() == 1:
		var chosen_id = str(candidates[0])
		events.append_array(_tianting_move_revealed_deck_card_to_hand(state, controller, chosen_id, command_id))
		var remaining: Array[String] = []
		for card_id in looked:
			if card_id != chosen_id:
				remaining.append(card_id)
		events.append_array(_request_tianting_reorder_next_card(state, controller, remaining, [], [], str(stack_item.get("source_instance_id", "")), {}, command_id))
	else:
		events.append_array(_request_tianting_reorder_next_card(state, controller, looked, [], [], str(stack_item.get("source_instance_id", "")), {}, command_id))
	return events


func _olympus_morale_candidate_ids(state: GameState, player_id: int, include_active: bool, include_spent: bool, require_divine: bool, require_non_divine: bool) -> Array[String]:
	var result: Array[String] = []
	if include_active:
		for raw_card_id in state.get_player(player_id).cost_area.cards:
			var card_id = str(raw_card_id)
			var instance = state.card_instances.get(card_id)
			if instance == null:
				continue
			var is_divine = bool(instance.flags.get("divine", false))
			if require_divine and not is_divine:
				continue
			if require_non_divine and is_divine:
				continue
			result.append(card_id)
	if include_spent:
		for raw_card_id in state.get_player(player_id).spent_cost_area.cards:
			var card_id = str(raw_card_id)
			var instance = state.card_instances.get(card_id)
			if instance == null:
				continue
			var is_divine = bool(instance.flags.get("divine", false))
			if require_divine and not is_divine:
				continue
			if require_non_divine and is_divine:
				continue
			result.append(card_id)
	return result


func _olympus_flip_morale(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	if not (resolution is Dictionary):
		return []
	var count = int(resolution.get("count", 1))
	var include_active = bool(resolution.get("include_active", true))
	var include_spent = bool(resolution.get("include_spent", false))
	var candidates = _olympus_morale_candidate_ids(state, controller, include_active, include_spent, false, true)
	if candidates.is_empty():
		return []
	var allow_up_to_count = bool(resolution.get("allow_up_to_count", false)) or bool(resolution.get("up_to", false))
	if candidates.size() <= count:
		return MoraleActions.flip_morale_cards(state, controller, candidates, true, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, count, str(resolution.get("title", "选择要翻转的士气")), "olympus_flip_morale_pick", {
		"allow_up_to_count": allow_up_to_count
	}, command_id)


func _request_olympus_reorder_bottom_next_card(state: GameState, player_id: int, remaining_cards: Array, bottom_cards: Array, source_instance_id: String, command_id: String) -> Array:
	var remaining: Array[String] = []
	for raw_card_id in remaining_cards:
		remaining.append(str(raw_card_id))
	var bottom: Array[String] = []
	for raw_card_id in bottom_cards:
		bottom.append(str(raw_card_id))
	if remaining.is_empty():
		var player = state.get_player(player_id)
		for card_id in bottom:
			player.deck.remove_card(card_id)
		for card_id in bottom:
			player.deck.cards.append(card_id)
		return []
	return _request_candidate_cards_choice(state, player_id, remaining, 1, "选择下一张要置于牌库底部的卡牌", "olympus_reorder_bottom_pick", {
		"remaining": remaining.duplicate(),
		"bottom": bottom.duplicate(),
		"source_instance_id": source_instance_id
	}, command_id)


func _olympus_search_top_pick_and_reorder(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	if not (resolution is Dictionary):
		return []
	var player = state.get_player(controller)
	var count = int(resolution.get("count", 3))
	var looked: Array[String] = []
	var events: Array = []
	for index in range(min(count, player.deck.cards.size())):
		var card_id = str(player.deck.cards[index])
		looked.append(card_id)
		events.append_array(_tianting_reveal_card(state, controller, card_id, "deck_top", command_id))
	if looked.is_empty():
		return events
	var candidates: Array[String] = []
	var required_faction = str(resolution.get("faction", ""))
	var source_instance = state.card_instances.get(str(stack_item.get("source_instance_id", "")))
	var source_definition_id = str(source_instance.definition_id) if source_instance != null else ""
	for card_id in looked:
		var instance = state.card_instances.get(card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null:
			continue
		if not _definition_matches_required_faction_for_instance(state, instance, definition, required_faction):
			continue
		if bool(resolution.get("exclude_source_definition_id", false)) and str(definition.id) == source_definition_id:
			continue
		candidates.append(card_id)
	var reorder_mode = str(resolution.get("reorder_mode", "top_or_bottom"))
	if candidates.size() >= 2:
		events.append_array(_request_candidate_cards_choice(state, controller, candidates, 1, str(resolution.get("pick_title", "选择加入手牌的卡牌")), "olympus_revealed_pick_to_hand", {
			"looked": looked.duplicate(),
			"reorder_mode": reorder_mode,
			"source_instance_id": str(stack_item.get("source_instance_id", ""))
		}, command_id))
	elif candidates.size() == 1:
		var chosen_id = str(candidates[0])
		events.append_array(_tianting_move_revealed_deck_card_to_hand(state, controller, chosen_id, command_id))
		var remaining: Array[String] = []
		for card_id in looked:
			if card_id != chosen_id:
				remaining.append(card_id)
		if reorder_mode == "top_or_bottom":
			events.append_array(_request_tianting_reorder_next_card(state, controller, remaining, [], [], str(stack_item.get("source_instance_id", "")), {}, command_id))
		else:
			events.append_array(_request_olympus_reorder_bottom_next_card(state, controller, remaining, [], str(stack_item.get("source_instance_id", "")), command_id))
	else:
		if reorder_mode == "top_or_bottom":
			events.append_array(_request_tianting_reorder_next_card(state, controller, looked, [], [], str(stack_item.get("source_instance_id", "")), {}, command_id))
		else:
			events.append_array(_request_olympus_reorder_bottom_next_card(state, controller, looked, [], str(stack_item.get("source_instance_id", "")), command_id))
	return events


func _olympus_artemis_grant_choice(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null:
			continue
		if not _definition_matches_required_faction_for_instance(state, instance, definition, "olympus") or not definition.is_legion():
			continue
		if int(definition.cost) < 3 or int(definition.cost) > 6:
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择获得能力的奥林匹斯军团", "olympus_artemis_pick_target", {}, command_id)


func _olympus_grant_next_tactic_free(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	state.get_player(controller).flags["tianting_next_tactic_free"] = {
		"turn": state.turn_number,
		"remaining": max(1, int(stack_item.get("resolution", {}).get("count", 1)))
	}
	var event = GameEvent.create(state.next_event_id(), "EffectPrepared", controller, {
		"source_id": str(stack_item.get("source_instance_id", "")),
		"effect": "next_tactic_free"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _olympus_freeze_target_until_next_ready(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var targets = stack_item.get("targets", {})
	if not (targets is Dictionary):
		return []
	var target_id = str(targets.get("target_card_id", ""))
	if target_id.is_empty():
		return []
	var target_instance = state.card_instances.get(target_id)
	if target_instance == null or str(target_instance.orientation) != "rested":
		return []
	if not _target_card_matches_stack_resolution_filters(state, stack_item, target_id):
		return []
	target_instance.flags["cannot_ready_on_ready_phase_player"] = int(target_instance.controller)
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(target_instance.controller), {
		"card_id": target_id,
		"buff": "cannot_ready_on_ready_phase"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _olympus_grant_source_free_move_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if source_id.is_empty() or instance == null or not str(instance.zone).begins_with("battle_"):
		return []
	var resolution = stack_item.get("resolution", {})
	var effect_id = str(resolution.get("effect_id", "olympus_free_move"))
	var once_key = str(resolution.get("once_per_turn_key", effect_id))
	instance.flags["free_move_until_turn_end_turn"] = state.turn_number
	instance.flags["free_move_until_turn_end_effect_id"] = effect_id
	instance.flags["free_move_until_turn_end_once_key"] = once_key
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": source_id,
		"buff": "free_move_until_turn_end",
		"effect_id": effect_id
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _olympus_reveal_hand_legion_and_destroy(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates = _matching_hand_card_ids(state, controller, {"type": "legion"})
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择并展示1张手牌军团，将其放回牌库顶", "olympus_reveal_hand_legion_to_deck_top", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"initiator_player": controller,
		"requires_confirm": true
	}, command_id)

func _olympus_reveal_hand_tactic_for_power(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_instance_id = str(stack_item.get("source_instance_id", ""))
	var candidates = _matching_hand_card_ids(state, controller, {"type": "tactic"})
	if candidates.is_empty():
		return []
	if candidates.size() == 1:
		var selected_id = str(candidates[0])
		var events = _tianting_reveal_card(state, controller, selected_id, "hand", command_id)
		if not source_instance_id.is_empty():
			events.append_array(_modify_power_until_turn_end(state, source_instance_id, int(stack_item.get("resolution", {}).get("amount", 1000)), command_id))
		return events
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择并展示1张手牌战术，此军团本回合兵力+1000", "olympus_reveal_hand_tactic_for_power", {
		"source_instance_id": source_instance_id,
		"amount": int(stack_item.get("resolution", {}).get("amount", 1000)),
		"requires_confirm": true
	}, command_id)

func _olympus_hannibal_attack_weaken(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var enemy_candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, 1 - controller):
		var instance = state.card_instances.get(card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null or not definition.is_legion():
			continue
		enemy_candidates.append(str(card_id))
	if enemy_candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, enemy_candidates, 1, "选择敌方要-2000的军团", "olympus_hannibal_pick_enemy_weaken", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"requires_confirm": true
	}, command_id)

func _olympus_helen_entry_discard_if_divine(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	if MoraleActions.count_divine_morale(state, controller) < 1:
		return []
	var opponent = 1 - controller
	var resolution := {
		"player_id": opponent,
		"discard_count": 1,
		"title": "海伦：对方选择弃置1张手牌",
		"requires_confirm": true
	}
	return _request_hand_discard_choice_from_resolution(state, {
		"controller": controller,
		"resolution": resolution
	}, command_id)

func _olympus_trojan_horse_after_attack(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var host_player = 1 - controller
	var slot_options = _battlefield_slot_options(state, host_player)
	if slot_options.is_empty():
		return []
	var source_instance_id = str(stack_item.get("source_instance_id", ""))
	if slot_options.size() == 1:
		var slot = slot_options[0]
		return _deploy_stack_pending_counter_to_foreign_battlefield(state, source_instance_id, controller, host_player, str(slot.get("row", "")), int(slot.get("col", -1)), command_id)
	return _request_option_choice(state, controller, slot_options, "选择置入对方战场的位置", "olympus_trojan_horse_choose_slot", {
		"source_instance_id": source_instance_id,
		"host_player": host_player
	}, command_id)

func _olympus_promotion_divine_flip_discount(state: GameState, player_id: int) -> int:
	var pending = state.get_player(player_id).flags.get("olympus_promotion_divine_flip_discount", {})
	if not (pending is Dictionary):
		return 0
	if int(pending.get("turn", -1)) != state.turn_number:
		return 0
	return max(0, int(pending.get("amount", 0)))

func _olympus_prepare_promotion_divine_flip_discount(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var amount = max(0, int(stack_item.get("resolution", {}).get("amount", 1)))
	if amount <= 0:
		return []
	state.get_player(controller).flags["olympus_promotion_divine_flip_discount"] = {
		"turn": state.turn_number,
		"amount": amount,
		"source_instance_id": str(stack_item.get("source_instance_id", ""))
	}
	var event = GameEvent.create(state.next_event_id(), "EffectPrepared", controller, {
		"source_id": str(stack_item.get("source_instance_id", "")),
		"effect": "olympus_promotion_divine_flip_discount",
		"amount": amount
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _olympus_prepare_ready_after_kill(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null or not definition.is_legion() or not _definition_matches_required_faction_for_instance(state, instance, definition, "olympus"):
			continue
		if definition.traits.has("promoted"):
			continue
		candidates.append(str(card_id))
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要设置击杀转为活跃的军团", "olympus_ready_after_kill_pick", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"initiator_player": controller,
		"requires_confirm": true
	}, command_id)


func _bijie_prepare_ready_after_kill(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var candidates: Array[String] = []
	for card_id in _get_battlefield_card_ids_for_player(state, controller):
		var instance = state.card_instances.get(card_id)
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null or not definition.is_legion() or not _definition_matches_required_faction_for_instance(state, instance, definition, "bijie"):
			continue
		candidates.append(str(card_id))
	if candidates.is_empty():
		return []
	return _request_candidate_cards_choice(state, controller, candidates, 1, "选择要设置击杀转为活跃的彼界军团", "bijie_ready_after_kill_pick", {
		"source_instance_id": str(stack_item.get("source_instance_id", "")),
		"initiator_player": controller,
		"requires_confirm": true
	}, command_id)


func _prepare_kill_grant_keyword_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var resolution = stack_item.get("resolution", {})
	var target_scope = str(resolution.get("target_scope", "allied_battlefield"))
	var candidate_owner = controller if target_scope != "enemy_battlefield" else 1 - controller
	var candidates = _matching_battlefield_cards_for_player(state, candidate_owner, resolution)
	if candidates.is_empty():
		return []
	var keyword = str(resolution.get("keyword", ""))
	if keyword.is_empty():
		return []
	if candidates.size() == 1:
		return _set_kill_grant_keyword_until_turn_end(state, str(candidates[0]), keyword, command_id)
	return _request_candidate_cards_choice(state, controller, candidates, 1, str(resolution.get("title", "选择军团设置击杀后关键词")), "prepare_kill_grant_keyword_until_turn_end_pick", {
		"keyword": keyword,
		"requires_confirm": true
	}, command_id)

func _set_kill_grant_keyword_until_turn_end(state: GameState, card_id: String, keyword: String, command_id: String) -> Array:
	if card_id.is_empty() or keyword.is_empty():
		return []
	var instance = state.card_instances.get(card_id)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return []
	instance.flags["kill_grant_keyword_until_turn_end_turn"] = state.turn_number
	instance.flags["kill_grant_keyword_until_turn_end_keyword"] = keyword
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": card_id,
		"buff": "kill_grant_keyword_until_turn_end",
		"keyword": keyword
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _olympus_grant_source_can_attack_legions_until_turn_end(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if source_id.is_empty() or instance == null or not str(instance.zone).begins_with("battle_"):
		return []
	instance.flags["can_attack_legions_until_turn_end_turn"] = state.turn_number
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": source_id,
		"buff": "can_attack_legions_until_turn_end"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _olympus_grant_source_front_taunt_until_next_own_turn_start(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var source_id = str(stack_item.get("source_instance_id", ""))
	var instance = state.card_instances.get(source_id)
	if source_id.is_empty() or instance == null or not str(instance.zone).begins_with("battle_"):
		return []
	if str(instance.position.get("row", "")) != "front":
		return []
	instance.flags["taunt_until_next_own_turn_start_player"] = int(instance.controller)
	var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", int(instance.controller), {
		"card_id": source_id,
		"buff": "taunt_until_next_own_turn_start"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _adjacent_battlefield_card_ids(state: GameState, card_id: String) -> Array[String]:
	var result: Array[String] = []
	var instance = state.card_instances.get(card_id)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return result
	var player = state.get_player(int(instance.controller))
	var row = str(instance.position.get("row", ""))
	var col = int(instance.position.get("col", -1))
	if row.is_empty() or col < 0:
		return result
	var slots = player.battle_front if row == "front" else player.battle_back
	for offset in [-1, 1]:
		var adjacent_col = col + offset
		if adjacent_col < 0 or adjacent_col >= slots.size():
			continue
		var adjacent_id = str(slots[adjacent_col].occupant)
		if adjacent_id.is_empty():
			continue
		result.append(adjacent_id)
	return result


func _apply_shock_on_attack_declared(state: GameState, attacker_id: String, defender_id: String, command_id: String) -> Array:
	var events: Array = []
	for adjacent_id in _adjacent_battlefield_card_ids(state, defender_id):
		events.append_array(_modify_power_until_turn_end(state, adjacent_id, -2000, command_id))
	return events


func _tianting_limu_refund_morale_trigger(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	return MoraleActions.add_morale_from_cost_deck(state, controller, 1, "rested", command_id, "tianting")


func _tianting_lijing_reveal_top(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	if player.deck.cards.is_empty():
		return []
	var top_id = str(player.deck.cards[0])
	var instance = state.card_instances.get(top_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	var events = _tianting_reveal_card(state, controller, top_id, "deck_top", command_id)
	var options: Array = [
		{"id": "top", "label": "放回牌库顶部"},
		{"id": "bottom", "label": "放回牌库底部"}
	]
	var can_deploy := false
	if definition != null and definition.is_legion() and _definition_matches_required_faction_for_instance(state, instance, definition, "tianting") and int(definition.cost) <= 5 and MoraleActions.count_spent_morale(state, controller) >= 1:
		if not _battlefield_slot_options(state, controller).is_empty():
			can_deploy = true
	if can_deploy:
		options.append({"id": "deploy", "label": "返还1士气，活跃登场"})
	events.append_array(_request_option_choice(state, controller, options, "李靖：选择处理方式", "tianting_lijing_choose_position_or_deploy", {
		"card_id": top_id
	}, command_id))
	return events


func _tianting_qiankun_yin(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	if player.deck.cards.is_empty():
		return []
	var top_id = str(player.deck.cards[0])
	var instance = state.card_instances.get(top_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	var events = _tianting_reveal_card(state, controller, top_id, "deck_top", command_id)
	if definition != null and definition.is_legion() and _definition_matches_required_faction_for_instance(state, instance, definition, "tianting") and int(definition.cost) <= 3:
		player.deck.remove_card(top_id)
		player.grave.add_card_to_top(top_id)
		if instance != null:
			instance.zone = "grave"
			instance.position = {}
			instance.controller = instance.owner
		var dump_event = GameEvent.create(state.next_event_id(), "CardMovedToGrave", controller, {
			"card_id": top_id,
			"from": "deck"
		})
		dump_event.created_by_command = command_id
		state.event_log.append(dump_event)
		events.append(dump_event)
		var allies = _get_battlefield_card_ids_for_player(state, controller)
		if not allies.is_empty():
			var target_id = str(allies[0])
			events.append_array(_modify_power_until_turn_end(state, target_id, int(definition.cost) * 1000, command_id))
			events.append_array(_modify_cost_until_turn_end(state, target_id, int(definition.cost), command_id))
		return events
	player.deck.remove_card(top_id)
	player.deck.cards.append(top_id)
	return events


func _tianting_xishi_swap(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var source_id = str(stack_item.get("source_instance_id", ""))
	var source_instance = state.card_instances.get(source_id)
	if source_instance == null or not str(source_instance.zone).begins_with("battle_"):
		return []
	var row = str(source_instance.position.get("row", ""))
	var col = int(source_instance.position.get("col", -1))
	if row.is_empty() or col < 0:
		return []
	var events = ZoneActions.move_battlefield_to_grave(state, controller, row, col, command_id, {"emit_died": false})
	var candidates: Array[String] = []
	for card_id in state.get_player(controller).hand.cards:
		var instance = state.card_instances.get(str(card_id))
		var definition = state.get_definition(instance.definition_id) if instance != null else null
		if definition == null or not definition.is_legion():
			continue
		if str(definition.name) == "西施":
			continue
		if int(definition.power) > 2000:
			continue
		candidates.append(str(card_id))
	if not candidates.is_empty():
		var slot_options = _battlefield_slot_options(state, controller)
		if not slot_options.is_empty():
			events.append_array(_request_candidate_cards_choice(state, controller, candidates, 1, "选择手牌军团活跃登场", "deploy_from_hand_to_battlefield", {
				"slot_options": slot_options.duplicate(true),
				"deployment_orientation": "active",
				"allow_up_to_count": true,
				"follow_up_action": {"action": "draw_cards", "count": 1}
			}, command_id))
			return events
	events.append_array(DrawActions.draw_cards(state, controller, 1, command_id))
	return events


func _tianting_guanxing(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	var events: Array = []
	var top_cards: Array[String] = []
	for index in range(min(5, player.deck.cards.size())):
		var card_id = str(player.deck.cards[index])
		top_cards.append(card_id)
		events.append_array(_tianting_reveal_card(state, controller, card_id, "deck_top", command_id))
	if top_cards.is_empty():
		return events
	events.append_array(_request_tianting_reorder_next_card(state, controller, top_cards, [], [], str(stack_item.get("source_instance_id", "")), {
		"action": "add_morale",
		"count": 1,
		"orientation": "active"
	}, command_id))
	return events


func _tianting_move_revealed_deck_card_to_hand(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	if not player.deck.cards.has(card_id):
		return []
	player.deck.remove_card(card_id)
	player.hand.add_card(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "hand"
		instance.position = {}
		instance.controller = instance.owner
		instance.orientation = "active"
		instance.damage_marked = 0
		instance.has_attacked_this_turn = false
	var event = GameEvent.create(state.next_event_id(), "CardReturnedToHand", player_id, _merge_event_payload_options({
		"card_id": card_id,
		"from": "deck",
		"to": "hand"
	}, {
		"source_kind": "effect",
		"source_player_id": player_id
	}))
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]

func _suncity_move_revealed_deck_card_to_grave(state: GameState, player_id: int, card_id: String, command_id: String) -> Array:
	var player = state.get_player(player_id)
	if not player.deck.cards.has(card_id):
		return []
	player.deck.remove_card(card_id)
	player.grave.add_card_to_top(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "grave"
		instance.position = {}
		instance.controller = instance.owner
		instance.orientation = "active"
		instance.damage_marked = 0
		instance.has_attacked_this_turn = false
	var event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, {
		"card_id": card_id,
		"from": "deck",
		"to": "grave"
	})
	event.created_by_command = command_id
	state.event_log.append(event)
	return [event]


func _request_tianting_reorder_next_card(state: GameState, player_id: int, remaining_cards: Array, top_cards: Array, bottom_cards: Array, source_instance_id: String, follow_up_action, command_id: String) -> Array:
	var remaining: Array[String] = []
	for raw_card_id in remaining_cards:
		remaining.append(str(raw_card_id))
	var top: Array[String] = []
	for raw_card_id in top_cards:
		top.append(str(raw_card_id))
	var bottom: Array[String] = []
	for raw_card_id in bottom_cards:
		bottom.append(str(raw_card_id))
	if remaining.is_empty():
		return _finalize_tianting_reordered_cards(state, player_id, top, bottom, source_instance_id, follow_up_action, command_id)
	return _request_candidate_cards_choice(state, player_id, remaining, 1, "选择下一张要放回的卡牌", "tianting_reorder_pick_next_card", {
		"remaining": remaining.duplicate(),
		"top": top.duplicate(),
		"bottom": bottom.duplicate(),
		"source_instance_id": source_instance_id,
		"follow_up_action": follow_up_action.duplicate(true) if follow_up_action is Dictionary else {}
	}, command_id)


func _finalize_tianting_reordered_cards(state: GameState, player_id: int, top_cards: Array[String], bottom_cards: Array[String], source_instance_id: String, follow_up_action, command_id: String) -> Array:
	var player = state.get_player(player_id)
	var affected: Array[String] = []
	affected.append_array(top_cards)
	affected.append_array(bottom_cards)
	for card_id in affected:
		player.deck.remove_card(card_id)
	var reordered: Array[String] = []
	reordered.append_array(top_cards)
	for card_id in player.deck.cards:
		reordered.append(str(card_id))
	reordered.append_array(bottom_cards)
	player.deck.cards = reordered
	return _resolve_choice_follow_up_action(state, player_id, source_instance_id, follow_up_action, command_id)


func _tianting_zhugeliang_peek_calamity(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	if state.calamity_deck.is_empty():
		return []
	var next_calamity_id = str(state.calamity_deck[0])
	var events: Array = []
	events.append_array(_tianting_reveal_card(state, controller, next_calamity_id, "calamity_deck_top", command_id))
	var choice = _request_option_choice(state, controller, [
		{"id": "plus", "label": "天灾值+1"},
		{"id": "minus", "label": "天灾值-1"},
		{"id": "keep", "label": "保持不变"}
	], "选择调整天灾值", "tianting_zhugeliang_calamity_adjust", {}, command_id)
	events.append_array(choice)
	return events


func _tianting_zhugeliang_reveal_top_artifact_or_hand(state: GameState, stack_item: Dictionary, command_id: String) -> Array:
	var controller = int(stack_item.get("controller", state.active_player))
	var player = state.get_player(controller)
	if player.deck.cards.is_empty():
		return []
	var top_id = str(player.deck.cards[0])
	var instance = state.card_instances.get(top_id)
	var definition = state.get_definition(instance.definition_id) if instance != null else null
	var events = _tianting_reveal_card(state, controller, top_id, "deck_top", command_id)
	if definition != null and definition.is_artifact():
		events.append_array(_replace_existing_artifacts_for_definition(state, controller, definition, command_id))
		player.deck.take_top()
		player.artifact_zone.add_card(top_id)
		if instance != null:
			instance.zone = "artifact_zone"
			instance.position = {}
			instance.orientation = "active"
			instance.controller = controller
		var play_event = GameEvent.create(state.next_event_id(), "CardPlayed", controller, {
			"card_id": top_id,
			"row": "artifact",
			"col": -1,
			"played_as": "played_from_deck_without_cost"
		})
		play_event.created_by_command = command_id
		state.event_log.append(play_event)
		events.append(play_event)
		return events
	events.append_array(_move_top_deck_card_to_hand(state, controller, command_id))
	return events
