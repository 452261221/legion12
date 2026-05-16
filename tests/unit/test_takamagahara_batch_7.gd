extends RefCounted
class_name TestTakamagaharaBatch7

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_magatama_entry_searches_takamagahara_cavalry(failures)
	_test_magatama_entry_still_opens_search_without_cavalry_targets(failures)
	_test_magatama_rested_effect_moves_active_ally(failures)
	_test_magatama_rested_effect_supports_inline_move_drag(failures)
	_test_magatama_rested_effect_supports_inline_move_drag_to_non_adjacent_slot(failures)
	_test_magatama_rested_move_hidden_when_board_full(failures)
	_test_magatama_rested_effect_grants_cannot_die(failures)
	return failures

static func _test_magatama_entry_searches_takamagahara_cavalry(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0404", "qa_vanilla", "qa_takamagahara_cavalry", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3601, [], _formal_options(2, 8))
	var magatama_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0404")
	_expect(magatama_id != "", "magatama search test should draw 八尺琼勾玉", failures)
	if magatama_id == "":
		return
	_expect(_find_hand_card_by_definition(state, 0, "qa_takamagahara_cavalry") == "", "magatama search test should leave the 高天原骑兵 in deck before resolution", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": magatama_id,
		"row": "artifact",
		"col": -1
	})).ok, "八尺琼勾玉 should play successfully to the artifact zone", failures)
	_resolve_top_stack(engine, state, failures, "八尺琼勾玉 entry should resolve to the optional search choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "八尺琼勾玉 should allow choosing to search for a 高天原骑兵", failures)
	_expect(_find_hand_card_by_definition(state, 0, "qa_takamagahara_cavalry") != "", "八尺琼勾玉 should add the searched 高天原骑兵 to hand", failures)
	var revealed_payload := _last_event_payload(state, "CardsRevealedToOpponent")
	_expect(int(revealed_payload.get("revealing_player_id", -1)) == 0, "八尺琼勾玉 should reveal the searched cavalry to the opponent", failures)
	_expect(_last_event_payload(state, "DeckShuffled").get("player_id", -1) == 0, "八尺琼勾玉 should shuffle its controller deck after the search", failures)

static func _test_magatama_entry_still_opens_search_without_cavalry_targets(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0404", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 36011, [], _formal_options(2, 8))
	var magatama_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0404")
	_expect(magatama_id != "", "magatama empty-search test should draw 八尺琼勾玉", failures)
	if magatama_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": magatama_id,
		"row": "artifact",
		"col": -1
	})).ok, "magatama empty-search test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "magatama empty-search test should reach the optional entry search")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "magatama empty-search test should still allow choosing to查看牌库", failures)
	var search_choice = _pending_choice_by_operation(state, "search_deck")
	_expect(search_choice != null, "八尺琼勾玉 should still open a search choice even without cavalry targets", failures)
	if search_choice == null:
		return
	_expect(search_choice.get("looked_cards", []).size() > 0, "八尺琼勾玉 should still reveal deck cards to the searching player", failures)
	_expect(search_choice.get("candidate_card_ids", []).is_empty(), "八尺琼勾玉 empty-search choice should have no selectable cavalry cards", failures)
	_expect(engine.apply_command(state, GameCommand.create(int(search_choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(search_choice.get("choice_id", "")),
		"cancelled": true
	})).ok, "magatama empty-search choice should be cancellable after查看牌库", failures)

static func _test_magatama_rested_effect_moves_active_ally(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0404", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3602, [], _formal_options(2, 8))
	var magatama_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0404")
	var ally_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(magatama_id != "" and ally_id != "", "magatama move test should draw 八尺琼勾玉 and an allied legion", failures)
	if magatama_id == "" or ally_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_magatama_move_setup")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": magatama_id,
		"row": "artifact",
		"col": -1
	})).ok, "八尺琼勾玉 move test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "八尺琼勾玉 move test should reach the optional entry search")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "八尺琼勾玉 move test should be able to skip the entry search", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": magatama_id,
		"effect_id": "magatama_rested_move_active_ally"
	})).ok, "八尺琼勾玉 should activate its rested effect", failures)
	var magatama_instance = state.card_instances.get(magatama_id)
	_expect(magatama_instance != null and str(magatama_instance.orientation) == "rested", "八尺琼勾玉 rested effect should rest the source artifact", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "八尺琼勾玉 mode choice first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "八尺琼勾玉 mode choice second pass should resolve", failures)
	_expect(_resolve_candidate_choice(engine, state, "choose_battlefield_cards_to_move", [ally_id]), "八尺琼勾玉 should allow selecting an active allied legion to move", failures)
	_expect(_resolve_option_choice(engine, state, "move_selected_battlefield_card_to_slot", "front:1"), "八尺琼勾玉 should allow choosing the moved legion destination", failures)
	_expect(state.get_player(0).battle_front[1].occupant == ally_id, "八尺琼勾玉 should move the selected allied legion to the chosen slot", failures)
	var last_move = _last_event_payload(state, "CardMoved")
	_expect(str(last_move.get("card_id", "")) == ally_id, "八尺琼勾玉 move mode should log the selected legion as moved", failures)

static func _test_magatama_rested_effect_supports_inline_move_drag(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0404", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 36021, [], _formal_options(2, 8))
	var magatama_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0404")
	var ally_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(magatama_id != "" and ally_id != "", "magatama inline move test should draw setup cards", failures)
	if magatama_id == "" or ally_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_magatama_inline_move_setup")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": magatama_id,
		"row": "artifact",
		"col": -1
	})).ok, "magatama inline move test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "magatama inline move test should reach the optional entry search")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "magatama inline move test should skip the entry search", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": magatama_id,
		"effect_id": "magatama_rested_move_active_ally"
	})).ok, "magatama inline move effect should activate", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "magatama inline move first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "magatama inline move second pass should resolve", failures)
	_expect(_resolve_candidate_choice_with_slot(engine, state, "choose_battlefield_cards_to_move", [ally_id], "front", 1), "magatama inline move should accept a card-and-slot payload", failures)
	_expect(_pending_choice_by_operation(state, "move_selected_battlefield_card_to_slot") == null, "magatama inline move should not open a second slot popup", failures)
	_expect(state.get_player(0).battle_front[1].occupant == ally_id, "magatama inline move should move directly to the dropped slot", failures)

static func _test_magatama_rested_effect_supports_inline_move_drag_to_non_adjacent_slot(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0404", "qa_takamagahara_cavalry", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 36022, [], _formal_options(2, 8))
	var magatama_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0404")
	var cavalry_id = _find_hand_card_by_definition(state, 0, "qa_takamagahara_cavalry")
	_expect(magatama_id != "" and cavalry_id != "", "magatama long-drag test should draw setup cards", failures)
	if magatama_id == "" or cavalry_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, cavalry_id, "front", 0, "test_magatama_long_drag_setup")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": magatama_id,
		"row": "artifact",
		"col": -1
	})).ok, "magatama long-drag test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "magatama long-drag test should reach the optional entry search")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "magatama long-drag test should skip the entry search", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": magatama_id,
		"effect_id": "magatama_rested_move_active_ally"
	})).ok, "magatama long-drag effect should activate", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "magatama long-drag first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "magatama long-drag second pass should resolve", failures)
	_expect(_resolve_candidate_choice_with_slot(engine, state, "choose_battlefield_cards_to_move", [cavalry_id], "back", 2), "magatama inline move should accept a non-adjacent dropped slot when the moved unit can legally reach it", failures)
	_expect(_pending_choice_by_operation(state, "move_selected_battlefield_card_to_slot") == null, "magatama long-drag should still skip the extra slot popup", failures)
	_expect(state.get_player(0).battle_back[2].occupant == cavalry_id, "magatama inline move should move the cavalry directly to the remote dropped slot", failures)

static func _test_magatama_rested_move_hidden_when_board_full(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0404", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 36023, [], _formal_options(7, 12))
	var magatama_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0404")
	_expect(magatama_id != "", "magatama full-board test should draw the artifact", failures)
	if magatama_id == "":
		return
	var ally_ids: Array[String] = []
	for card_id in state.get_player(0).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == "qa_vanilla":
			ally_ids.append(str(card_id))
	_expect(ally_ids.size() >= 6, "magatama full-board test should draw six allied legions", failures)
	if ally_ids.size() < 6:
		return
	var index := 0
	for row in ["front", "back"]:
		for col in range(3):
			engine._deploy_hand_card_to_slot(state, 0, ally_ids[index], row, col, "test_magatama_full_board_%s_%d" % [row, col])
			index += 1
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": magatama_id,
		"row": "artifact",
		"col": -1
	})).ok, "magatama full-board test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "magatama full-board test should reach the optional entry search")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "magatama full-board test should skip the entry search", failures)
	_expect(_find_activatable_effect(engine.get_activatable_effects(state, 0), magatama_id, "magatama_rested_move_active_ally").is_empty(), "magatama move effect should be hidden when no allied slot can receive a move", failures)

static func _test_magatama_rested_effect_grants_cannot_die(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0404", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3603, [], _formal_options(2, 8))
	var magatama_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0404")
	var ally_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(magatama_id != "" and ally_id != "", "magatama protect test should draw 八尺琼勾玉 and an allied legion", failures)
	if magatama_id == "" or ally_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_magatama_protect_setup")
	engine._move_battlefield_card_to_slot_without_cost(state, ally_id, "front", 1, "test_magatama_mark_move")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": magatama_id,
		"row": "artifact",
		"col": -1
	})).ok, "八尺琼勾玉 protect test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "八尺琼勾玉 protect test should reach the optional entry search")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "八尺琼勾玉 protect test should be able to skip the entry search", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": magatama_id,
		"effect_id": "magatama_rested_protect_moved_ally",
		"target_card_id": ally_id
	})).ok, "八尺琼勾玉 protect mode should activate", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "八尺琼勾玉 protect mode first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "八尺琼勾玉 protect mode second pass should resolve", failures)
	var protected_instance = state.card_instances.get(ally_id)
	_expect(protected_instance != null and int(protected_instance.flags.get("cannot_die_until_turn_end_turn", -1)) == state.turn_number, "八尺琼勾玉 should mark the moved legion as unable to die this turn", failures)
	var events = engine._destroy_target_unit(state, {
		"targets": {
			"target_card_id": ally_id
		},
		"resolution": {
			"type": "legion",
			"target_scope": "allied_battlefield"
		}
	}, "test_magatama_prevent_death")
	_expect(not events.is_empty() and str(events[0].type) == "CardDeathPrevented", "八尺琼勾玉 should prevent the protected legion from being sent to grave this turn", failures)
	_expect(state.get_player(0).battle_front[1].occupant == ally_id, "八尺琼勾玉 should leave the protected moved legion on the battlefield", failures)
	_expect(not state.get_player(0).grave.cards.has(ally_id), "八尺琼勾玉 should keep the protected legion out of the grave", failures)

static func _definitions() -> Array:
	var definitions = CardDatabase.load_definitions()
	definitions.append({
		"id": "qa_takamagahara_cavalry",
		"name": "高天原骑兵测试军团",
		"faction": "takamagahara",
		"type": "legion",
		"troop_type": "骑兵",
		"cost": 2,
		"power": 2000,
		"hp": 2000,
		"calamity_level": 0,
		"status": "implemented",
		"keywords": [],
		"effects": [],
		"text": "用于测试八尺琼勾玉的检索条件。"
	})
	return definitions

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

static func _resolve_candidate_choice_with_slot(engine: GameEngine, state, operation: String, selected_card_ids: Array, row: String, col: int) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected_card_ids.duplicate(),
		"row": row,
		"col": col
	})).ok

static func _pending_choice_by_operation(state, operation: String):
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return null

static func _find_activatable_effect(actions: Array, source_id: String, effect_id: String) -> Dictionary:
	for action in actions:
		if not (action is Dictionary):
			continue
		if str(action.get("source_id", "")) == source_id and str(action.get("effect_id", "")) == effect_id:
			return action.duplicate(true)
	return {}

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _last_event_payload(state, event_type: String) -> Dictionary:
	for index in range(state.event_log.size() - 1, -1, -1):
		var event = state.event_log[index]
		if str(event.type) == event_type:
			return event.payload.duplicate(true)
	return {}

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
