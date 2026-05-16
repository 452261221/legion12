extends RefCounted
class_name TestAsgardBatch3

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_olga_blood_price_and_ranged(failures)
	_test_olga_sacrifice_reduces_enemy_front_power(failures)
	return failures

static func _test_olga_blood_price_and_ranged(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["asgard_s01_0314", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3801, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 2,
		"opening_active_player_morale": 1,
		"opening_non_active_player_morale": 10
	})
	var olga_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0314")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(olga_id != "" and enemy_id != "", "olga blood-price test should draw 奥尔加 and an enemy legion", failures)
	if olga_id == "" or enemy_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_olga_enemy_setup")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": olga_id,
		"row": "back",
		"col": 0,
		"play_option_id": "olga_blood_price"
	})).ok, "奥尔加 should be playable with its blood-price discount", failures)
	_expect(state.get_player(0).master_hp == 19, "奥尔加 blood-price play option should deal 1 damage to its controller master", failures)
	_expect(state.get_player(0).battle_back[0].occupant == olga_id, "奥尔加 should enter the back row after being played", failures)
	var legal_targets = engine.get_legal_attack_targets(state, olga_id)
	_expect(_targets_include_card(legal_targets, enemy_id), "奥尔加 should be able to attack from the back row with ranged", failures)

static func _test_olga_sacrifice_reduces_enemy_front_power(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["asgard_s01_0314", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3802, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 2,
		"opening_active_player_morale": 4,
		"opening_non_active_player_morale": 10
	})
	var olga_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0314")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(olga_id != "" and enemy_id != "", "olga sacrifice test should draw 奥尔加 and an enemy legion", failures)
	if olga_id == "" or enemy_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_olga_enemy_front_setup")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": olga_id,
		"row": "front",
		"col": 0
	})).ok, "奥尔加 sacrifice test should play 奥尔加 normally", failures)
	var power_before = engine.get_card_power(state, enemy_id)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": olga_id,
		"effect_id": "olga_sacrifice_weaken_front"
	})).ok, "奥尔加 should activate its sacrifice effect during its controller turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "奥尔加 sacrifice effect first priority pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "奥尔加 sacrifice effect second priority pass should resolve", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "", "奥尔加 sacrifice effect should remove 奥尔加 from the battlefield", failures)
	_expect(state.get_player(0).grave.cards.has(olga_id), "奥尔加 sacrifice effect should put 奥尔加 into the grave", failures)
	_expect(_resolve_candidate_choice(engine, state, "modify_power_until_turn_end", [enemy_id]), "奥尔加 should request an enemy front-row target for the -2000 power effect", failures)
	_expect(engine.get_card_power(state, enemy_id) == max(0, power_before - 2000), "奥尔加 should reduce the selected enemy front-row legion power by 2000 this turn", failures)

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

static func _targets_include_card(targets: Array, target_card_id: String) -> bool:
	for target in targets:
		if target is Dictionary and str(target.get("defender_id", "")) == target_card_id:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
