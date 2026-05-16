extends RefCounted
class_name TestTakamagaharaBatch5

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_sakamoto_entry_can_select_one_and_grant_free_move(failures)
	_test_sakamoto_move_and_rested_deploy(failures)
	_test_sakamoto_can_move_and_swap_rested_legions(failures)
	return failures

static func _test_sakamoto_entry_can_select_one_and_grant_free_move(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0407", "qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3400, [], _formal_options(3, 8))
	var sakamoto_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0407")
	var mover_a = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var mover_b = _find_hand_card_by_definition(state, 0, "qa_plain")
	_expect(sakamoto_id != "" and mover_a != "" and mover_b != "", "sakamoto single-select test should draw 坂本龙马 and two allied legions", failures)
	if sakamoto_id == "" or mover_a == "" or mover_b == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, mover_a, "front", 0, "test_sakamoto_single_setup_a")
	engine._deploy_hand_card_to_slot(state, 0, mover_b, "back", 0, "test_sakamoto_single_setup_b")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sakamoto_id,
		"row": "front",
		"col": 1
	})).ok, "坂本龙马 single-select test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "坂本龙马 single-select entry should resolve to a move choice")
	_expect(_resolve_candidate_choice(engine, state, "choose_battlefield_cards_to_move", [mover_a]), "坂本龙马 should allow selecting only one allied legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_a,
		"row": "front",
		"col": 2
	})).ok, "坂本龙马 selected legion should gain one free move to any empty slot this turn", failures)
	_expect(state.get_player(0).battle_front[2].occupant == mover_a, "坂本龙马 selected legion should move to the chosen distant slot", failures)
	_expect(not engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_a,
		"row": "back",
		"col": 2
	})).ok, "坂本龙马 selected legion should only gain one free move this turn", failures)
	_expect(not engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_b,
		"row": "back",
		"col": 2
	})).ok, "坂本龙马 unselected legion should not gain the free move", failures)

static func _test_sakamoto_move_and_rested_deploy(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0407", "qa_vanilla", "qa_plain", "takamagahara_s01_0413", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3401, [], _formal_options(4, 8))
	var sakamoto_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0407")
	var mover_a = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var mover_b = _find_hand_card_by_definition(state, 0, "qa_plain")
	var reserve_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	_expect(sakamoto_id != "" and mover_a != "" and mover_b != "" and reserve_id != "", "sakamoto test should draw 坂本龙马, two allied legions and one low-cost 高天原 reserve", failures)
	if sakamoto_id == "" or mover_a == "" or mover_b == "" or reserve_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, mover_a, "front", 0, "test_sakamoto_setup_a")
	engine._deploy_hand_card_to_slot(state, 0, mover_b, "back", 0, "test_sakamoto_setup_b")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sakamoto_id,
		"row": "front",
		"col": 1
	})).ok, "坂本龙马 should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "坂本龙马 entry should resolve to a move choice")
	_expect(_resolve_candidate_choice(engine, state, "choose_battlefield_cards_to_move", [mover_a, mover_b]), "坂本龙马 entry should allow selecting up to two allied legions to move", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_a,
		"row": "back",
		"col": 1
	})).ok, "坂本龙马 should let the first selected allied legion move once this turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_b,
		"row": "front",
		"col": 2
	})).ok, "坂本龙马 should let the second selected allied legion also move once this turn", failures)
	_expect(state.get_player(0).battle_back[1].occupant == mover_a, "坂本龙马 should move the first selected allied legion to back row column 2", failures)
	_expect(state.get_player(0).battle_front[2].occupant == mover_b, "坂本龙马 should move the second selected allied legion to front row column 3", failures)
	var death_events = engine._destroy_target_unit(state, {
		"targets": {
			"target_card_id": sakamoto_id
		},
		"resolution": {}
	}, "test_sakamoto_destroy")
	engine._enqueue_pending_triggers(state, death_events)
	engine._promote_next_pending_trigger(state, "test_sakamoto_promote")
	_resolve_top_stack(engine, state, failures, "坂本龙马 death trigger should resolve to a rested deploy choice")
	_expect(_resolve_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [reserve_id]), "坂本龙马 death trigger should allow selecting one low-cost 高天原 legion from hand", failures)
	_expect(_resolve_option_choice(engine, state, "deploy_selected_hand_to_slot", "back:0"), "坂本龙马 death trigger should allow choosing where the rested legion enters", failures)
	_expect(state.get_player(0).battle_back[0].occupant == reserve_id, "坂本龙马 death trigger should deploy the selected reserve legion to the chosen slot", failures)
	var reserve_instance = state.card_instances.get(reserve_id)
	_expect(reserve_instance != null and str(reserve_instance.orientation) == "rested", "坂本龙马 death trigger should deploy the selected 高天原 legion rested", failures)

static func _test_sakamoto_can_move_and_swap_rested_legions(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0407", "qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3402, [], _formal_options(3, 8))
	var sakamoto_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0407")
	var mover_a = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var mover_b = _find_hand_card_by_definition(state, 0, "qa_plain")
	_expect(sakamoto_id != "" and mover_a != "" and mover_b != "", "sakamoto rested swap test should draw 坂本龙马 and two allied legions", failures)
	if sakamoto_id == "" or mover_a == "" or mover_b == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, mover_a, "front", 0, "test_sakamoto_rested_setup_a")
	engine._deploy_hand_card_to_slot(state, 0, mover_b, "back", 0, "test_sakamoto_rested_setup_b")
	state.card_instances[mover_a].orientation = "rested"
	state.card_instances[mover_b].orientation = "rested"
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sakamoto_id,
		"row": "front",
		"col": 1
	})).ok, "坂本龙马 rested swap test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "坂本龙马 rested swap entry should resolve to a move choice")
	_expect(_resolve_candidate_choice(engine, state, "choose_battlefield_cards_to_move", [mover_a, mover_b]), "坂本龙马 rested swap test should allow selecting rested allied legions", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_a,
		"row": "back",
		"col": 0
	})).ok, "坂本龙马 should let a rested selected legion swap with another rested allied legion", failures)
	_expect(state.get_player(0).battle_back[0].occupant == mover_a, "坂本龙马 rested swap should move the dragged legion into the occupied target slot", failures)
	_expect(state.get_player(0).battle_front[0].occupant == mover_b, "坂本龙马 rested swap should move the original occupied legion back to the source slot", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _formal_options(opening_hand_size: int, opening_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": 10
	}

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, message, failures)
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, message, failures)

static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
	})).ok

static func _resolve_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected_card_ids.duplicate()
	})).ok

static func _pending_choice_by_operation(state, operation: String):
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return null

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
