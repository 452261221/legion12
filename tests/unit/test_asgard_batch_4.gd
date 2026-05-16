extends RefCounted
class_name TestAsgardBatch4

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_rollo_recycles_grave_for_play_discount_and_heal(failures)
	_test_rollo_front_row_has_taunt_and_cannot_be_supported(failures)
	return failures

static func _test_rollo_recycles_grave_for_play_discount_and_heal(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["asgard_s02_0302", "asgard_s01_0302", "asgard_s01_0303", "asgard_s01_0304", "asgard_s01_0305", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3901, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 5,
		"opening_active_player_morale": 7,
		"opening_non_active_player_morale": 10
	})
	var rollo_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0302")
	_expect(rollo_id != "", "rollo discount test should draw 步行者罗洛", failures)
	if rollo_id == "":
		return
	var recycle_ids = _move_hand_cards_to_grave_by_definition_ids(state, 0, [
		"asgard_s01_0302",
		"asgard_s01_0303",
		"asgard_s01_0304",
		"asgard_s01_0305"
	])
	_expect(recycle_ids.size() == 4, "rollo discount test should seed four 阿斯加德 cards into grave", failures)
	if recycle_ids.size() != 4:
		return
	var selected_recycle_ids = recycle_ids.slice(0, 3)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": rollo_id,
		"row": "front",
		"col": 0,
		"play_option_id": "rollo_recycle_up_to_8",
		"selected_grave_card_ids": selected_recycle_ids.duplicate()
	})).ok, "步行者罗洛 should play using the selectable grave recycle discount", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == 0, "步行者罗洛 recycling 3 cards should reduce the play cost by 1", failures)
	_expect(state.get_player(0).master_hp == 21, "步行者罗洛 should heal its controller master by 1 on entry", failures)
	_expect(state.get_player(0).battle_front[0].occupant == rollo_id, "步行者罗洛 should enter the chosen front-row slot", failures)
	_expect(_deck_ends_with(state.get_player(0).deck.cards, selected_recycle_ids), "步行者罗洛 should return the selected grave cards to the bottom of the deck in chosen order", failures)

static func _test_rollo_front_row_has_taunt_and_cannot_be_supported(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["asgard_s02_0302", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3902, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 3,
		"opening_active_player_morale": 10,
		"opening_non_active_player_morale": 10
	})
	var rollo_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0302")
	var ally_front_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var ally_back_id = _find_hand_card_by_definition(state, 0, "qa_vanilla", ally_front_id)
	var enemy_attacker_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	var enemy_other_target_id = _find_hand_card_by_definition(state, 1, "qa_plain", enemy_attacker_id)
	_expect(rollo_id != "" and ally_front_id != "" and ally_back_id != "" and enemy_attacker_id != "" and enemy_other_target_id != "", "rollo front test should draw all setup cards", failures)
	if rollo_id == "" or ally_front_id == "" or ally_back_id == "" or enemy_attacker_id == "" or enemy_other_target_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, rollo_id, "front", 0, "test_rollo_front_setup")
	engine._deploy_hand_card_to_slot(state, 0, ally_back_id, "back", 0, "test_rollo_supporter_setup")
	engine._deploy_hand_card_to_slot(state, 0, ally_front_id, "front", 1, "test_rollo_other_front_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_attacker_id, "front", 0, "test_rollo_enemy_attacker_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_other_target_id, "front", 1, "test_rollo_enemy_other_front_setup")
	state.card_instances[rollo_id].entered_turn = -1
	state.card_instances[ally_front_id].entered_turn = -1
	state.card_instances[ally_back_id].entered_turn = -1
	state.card_instances[enemy_attacker_id].entered_turn = -1
	state.card_instances[enemy_other_target_id].entered_turn = -1
	var supporters = engine.get_legal_supporters(state, rollo_id, enemy_attacker_id)
	_expect(supporters.is_empty(), "步行者罗洛 should not be supportable from the back row while in front", failures)
	var invalid_attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": enemy_attacker_id,
		"defender_id": ally_front_id
	}))
	_expect(not invalid_attack.ok and str(invalid_attack.error.get("code", "")) == "TAUNT_REQUIRED", "步行者罗洛 front-row taunt should force enemy attacks to target it first", failures)

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String, exclude_card_id: String = "") -> String:
	for card_id in state.get_player(player_id).hand.cards:
		if not exclude_card_id.is_empty() and card_id == exclude_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _move_hand_cards_to_grave_by_definition_ids(state, player_id: int, definition_ids: Array) -> Array[String]:
	var moved: Array[String] = []
	var player = state.get_player(player_id)
	for definition_id in definition_ids:
		var card_id = _find_hand_card_by_definition(state, player_id, str(definition_id))
		if card_id.is_empty():
			continue
		player.hand.remove_card(card_id)
		player.grave.add_card_to_top(card_id)
		var instance = state.card_instances.get(card_id)
		if instance != null:
			instance.zone = "grave"
			instance.position = {}
			instance.face = "face_up"
		moved.append(card_id)
	return moved

static func _deck_ends_with(deck_cards: Array, suffix: Array) -> bool:
	if suffix.size() > deck_cards.size():
		return false
	var start = deck_cards.size() - suffix.size()
	for index in range(suffix.size()):
		if str(deck_cards[start + index]) != str(suffix[index]):
			return false
	return true

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
