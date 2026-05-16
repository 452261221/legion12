extends RefCounted
class_name TestOlympusBatch2

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_atalanta_promotion_and_restore(failures)
	_test_atalanta_promotion_restore_keeps_current_orientation(failures)
	_test_atalanta_promotion_restore_keeps_attack_state(failures)
	_test_atalanta_promotion_restore_on_return_to_hand(failures)
	_test_atalanta_promotion_restore_on_return_to_deck_bottom(failures)
	_test_theseus_no_divine_discount(failures)
	return failures


static func _test_atalanta_promotion_and_restore(failures: Array[String]) -> void:
	var setup = _setup_promoted_atalanta_state(7201, "test_promotion_setup", failures)
	if setup.is_empty():
		return
	var state = setup["state"]
	var base_id = str(setup["base_id"])
	var promo_id = str(setup["promo_id"])
	var slot = state.get_player(0).battle_back[0]
	_expect(str(slot.occupant) == promo_id, "Atalanta promotion: promoted unit should become the battlefield occupant", failures)
	_expect(str(slot.cover) == base_id, "Atalanta promotion: slot cover should point to the covered base unit", failures)
	var promoted_instance = state.card_instances.get(promo_id)
	var base_instance = state.card_instances.get(base_id)
	_expect(promoted_instance != null and promoted_instance.overlay_cards.size() == 1 and str(promoted_instance.overlay_cards[0]) == base_id, "Atalanta promotion: base unit should be stored under the promoted unit", failures)
	_expect(base_instance != null and str(base_instance.zone) == "battle_back", "Atalanta promotion: base unit should stay in the covered battlefield slot state", failures)
	_expect(_has_card_in_hand_definition(state, 0, "olympus_s02_0513"), "Atalanta promotion: first optional draw should add Aristotle to hand", failures)
	_expect(_has_card_in_hand_definition(state, 0, "olympus_s02_0512"), "Atalanta promotion: second optional draw should add Aeneas to hand", failures)
	ZoneActions.move_battlefield_to_grave(state, 0, "back", 0, "test_promotion_restore")
	slot = state.get_player(0).battle_back[0]
	base_instance = state.card_instances.get(base_id)
	_expect(str(slot.occupant) == base_id, "Atalanta promotion: base unit should return to the slot after the promoted unit leaves", failures)
	_expect(str(slot.cover) == "", "Atalanta promotion: grave restore should clear slot cover", failures)
	_expect(base_instance != null and str(base_instance.zone) == "battle_back", "Atalanta promotion: restored base unit should return to the battlefield", failures)
	_expect(state.get_player(0).grave.cards.has(promo_id), "Atalanta promotion: promoted unit should go to grave after leaving play", failures)


static func _test_atalanta_promotion_restore_on_return_to_hand(failures: Array[String]) -> void:
	var setup = _setup_promoted_atalanta_state(7203, "test_promotion_return_hand_setup", failures)
	if setup.is_empty():
		return
	var state = setup["state"]
	var base_id = str(setup["base_id"])
	var promo_id = str(setup["promo_id"])
	ZoneActions.return_battlefield_to_hand(state, 0, "back", 0, "test_promotion_return_hand")
	var slot = state.get_player(0).battle_back[0]
	var base_instance = state.card_instances.get(base_id)
	var promo_instance = state.card_instances.get(promo_id)
	_expect(str(slot.occupant) == base_id, "Atalanta promotion hand restore: base unit should return to slot", failures)
	_expect(str(slot.cover) == "", "Atalanta promotion hand restore: slot cover should be cleared", failures)
	_expect(base_instance != null and str(base_instance.zone) == "battle_back", "Atalanta promotion hand restore: base unit should return to battlefield", failures)
	_expect(promo_instance != null and str(promo_instance.zone) == "hand", "Atalanta promotion hand restore: promoted unit should return to hand", failures)
	_expect(state.get_player(0).hand.cards.has(promo_id), "Atalanta promotion hand restore: hand should contain promoted unit", failures)


static func _test_atalanta_promotion_restore_keeps_current_orientation(failures: Array[String]) -> void:
	var setup = _setup_promoted_atalanta_state(7205, "test_promotion_orientation_setup", failures)
	if setup.is_empty():
		return
	var state = setup["state"]
	var base_id = str(setup["base_id"])
	var promo_id = str(setup["promo_id"])
	var promo_instance = state.card_instances.get(promo_id)
	if promo_instance == null:
		_expect(false, "Atalanta promotion orientation restore: promoted instance should exist", failures)
		return
	promo_instance.orientation = "rested"
	ZoneActions.move_battlefield_to_grave(state, 0, "back", 0, "test_promotion_orientation_restore")
	var base_instance = state.card_instances.get(base_id)
	_expect(base_instance != null and str(base_instance.orientation) == "rested", "Atalanta promotion orientation restore: restored base unit should inherit the promoted unit orientation", failures)


static func _test_atalanta_promotion_restore_keeps_attack_state(failures: Array[String]) -> void:
	var setup = _setup_promoted_atalanta_state(7206, "test_promotion_attack_state_setup", failures)
	if setup.is_empty():
		return
	var state = setup["state"]
	var base_id = str(setup["base_id"])
	var promo_id = str(setup["promo_id"])
	var promo_instance = state.card_instances.get(promo_id)
	if promo_instance == null:
		_expect(false, "Atalanta promotion attack-state restore: promoted instance should exist", failures)
		return
	promo_instance.has_attacked_this_turn = true
	promo_instance.orientation = "rested"
	ZoneActions.move_battlefield_to_grave(state, 0, "back", 0, "test_promotion_attack_state_restore")
	var base_instance = state.card_instances.get(base_id)
	_expect(base_instance != null and bool(base_instance.has_attacked_this_turn), "Atalanta promotion attack-state restore: restored base unit should inherit attack state", failures)


static func _test_atalanta_promotion_restore_on_return_to_deck_bottom(failures: Array[String]) -> void:
	var setup = _setup_promoted_atalanta_state(7204, "test_promotion_return_deck_setup", failures)
	if setup.is_empty():
		return
	var state = setup["state"]
	var base_id = str(setup["base_id"])
	var promo_id = str(setup["promo_id"])
	ZoneActions.return_battlefield_to_deck_bottom(state, 0, "back", 0, "test_promotion_return_deck")
	var slot = state.get_player(0).battle_back[0]
	var base_instance = state.card_instances.get(base_id)
	var promo_instance = state.card_instances.get(promo_id)
	var deck_cards = state.get_player(0).deck.cards
	_expect(str(slot.occupant) == base_id, "Atalanta promotion deck restore: base unit should return to slot", failures)
	_expect(str(slot.cover) == "", "Atalanta promotion deck restore: slot cover should be cleared", failures)
	_expect(base_instance != null and str(base_instance.zone) == "battle_back", "Atalanta promotion deck restore: base unit should return to battlefield", failures)
	_expect(promo_instance != null and str(promo_instance.zone) == "deck", "Atalanta promotion deck restore: promoted unit should return to deck", failures)
	_expect(not deck_cards.is_empty() and str(deck_cards[deck_cards.size() - 1]) == promo_id, "Atalanta promotion deck restore: promoted unit should go to deck bottom", failures)


static func _test_theseus_no_divine_discount(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0518", "olympus_s02_0513", "olympus_s02_0512"],
		["olympus_s02_0514", "neutral_s01_0015"]
	], 7202, [
		{"name": "P0", "master_name": "普罗米修斯", "master_id": "olympus_s02_05m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(1, 2, 2))
	var theseus_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0518")
	_expect(not theseus_id.is_empty(), "Theseus: setup hand is missing Theseus", failures)
	if theseus_id.is_empty():
		return
	var play_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": theseus_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play_result.get("ok", false)), "Theseus: should be playable with only 2 morale when divine count is 0", failures)
	if not bool(play_result.get("ok", false)):
		return
	_drain_stack(engine, state)
	_expect(state.get_player(0).cost_area.cards.is_empty(), "Theseus: discounted play should consume exactly the available 2 morale", failures)


static func _setup_promoted_atalanta_state(seed: int, command_prefix: String, failures: Array[String]) -> Dictionary:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0508", "olympus_s02_0507", "olympus_s02_0513", "olympus_s02_0512"],
		["olympus_s02_0514", "neutral_s01_0015", "neutral_s01_0016"]
	], seed, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 6, 6))
	var base_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0508")
	var promo_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0507")
	_expect(not base_id.is_empty() and not promo_id.is_empty(), "Atalanta promotion setup: hand is missing required cards", failures)
	if base_id.is_empty() or promo_id.is_empty():
		return {}
	var base_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": base_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(base_play.get("ok", false)), "Atalanta promotion setup: base Atalanta failed to deploy", failures)
	if not bool(base_play.get("ok", false)):
		return {}
	_drain_stack(engine, state)
	state.active_player = 0
	state.priority_player = 0
	var divine_seed = str(state.get_player(0).cost_area.cards[0])
	MoraleActions.flip_morale_cards(state, 0, [divine_seed], true, "%s_divine" % command_prefix)
	var promo_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": promo_id,
		"row": "back",
		"col": 0,
		"play_option_id": "promotion"
	}))
	_expect(bool(promo_play.get("ok", false)), "Atalanta promotion setup: promotion play failed", failures)
	if not bool(promo_play.get("ok", false)):
		return {}
	_drain_stack(engine, state)
	return {
		"engine": engine,
		"state": state,
		"base_id": base_id,
		"promo_id": promo_id
	}

static func _definitions_with_olympus_masters() -> Array:
	var definitions: Array = []
	definitions.append_array(CardDatabase.load_definitions())
	definitions.append_array(CardDatabase.load_definitions("res://data/raw_rule_cards/olympus_master_cards.json"))
	return definitions


static func _formal_options(opening_hand_size: int, opening_active_player_morale: int, opening_non_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": opening_non_active_player_morale
	}


static func _drain_stack(engine: GameEngine, state) -> void:
	var guard := 0
	while guard < 20:
		guard += 1
		if _resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"):
			continue
		if state.stack.is_empty():
			break
		_pass_stack_pair(engine, state)


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

static func _has_card_in_hand_definition(state, player_id: int, definition_id: String) -> bool:
	return not _find_hand_card_by_definition(state, player_id, definition_id).is_empty()


static func _pass_stack_pair(engine: GameEngine, state) -> void:
	if state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))


static func _resolve_first_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_option": selected_option
		})).get("ok", false))
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
