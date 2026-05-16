extends RefCounted
class_name TestTakamagaharaBatch8

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_seimei_entry_grants_one_time_survival_and_ranged(failures)
	_test_seimei_survival_expires_at_next_own_turn_start(failures)
	return failures

static func _test_seimei_entry_grants_one_time_survival_and_ranged(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0411", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3701, [], _formal_options(2, 8))
	var seimei_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0411")
	var ally_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(seimei_id != "" and ally_id != "" and enemy_id != "", "seimei test should draw 安倍晴明, an allied legion and an enemy legion", failures)
	if seimei_id == "" or ally_id == "" or enemy_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_seimei_ally_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_seimei_enemy_setup")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": seimei_id,
		"row": "back",
		"col": 0
	})).ok, "安倍晴明 should play successfully", failures)
	_expect(state.pending_choices.size() == 1, "安倍晴明 should request one allied target when entering", failures)
	_expect(_resolve_candidate_choice(engine, state, "target_then_stack_effect", [ally_id]), "安倍晴明 should allow selecting an allied legion to gain survival", failures)
	_expect(state.stack.size() == 1, "安倍晴明 target selection should put the effect onto the stack", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "安倍晴明 entry first response pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "安倍晴明 entry second response pass should resolve", failures)
	var protected_instance = state.card_instances.get(ally_id)
	_expect(protected_instance != null and int(protected_instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) == 0, "安倍晴明 should grant survival until its controller next turn start", failures)
	var attack_targets = engine.get_legal_attack_targets(state, seimei_id)
	_expect(_targets_include_card(attack_targets, enemy_id), "安倍晴明 should be able to attack from the back row with ranged", failures)
	var first_destroy = engine._destroy_target_unit(state, {
		"targets": {
			"target_card_id": ally_id
		},
		"resolution": {
			"type": "legion",
			"target_scope": "allied_battlefield"
		}
	}, "test_seimei_first_destroy")
	_expect(not first_destroy.is_empty() and str(first_destroy[0].type) == "CardDeathPrevented", "安倍晴明 should prevent the first destruction of the protected legion", failures)
	_expect(state.get_player(0).battle_front[0].occupant == ally_id, "安倍晴明 should keep the protected legion on the battlefield after the first replacement", failures)
	_expect(engine.get_card_power(state, ally_id) == 1000, "安倍晴明 should set the protected legion power to 1000 for the turn after replacement", failures)
	var second_destroy = engine._destroy_target_unit(state, {
		"targets": {
			"target_card_id": ally_id
		},
		"resolution": {
			"type": "legion",
			"target_scope": "allied_battlefield"
		}
	}, "test_seimei_second_destroy")
	_expect(_event_types_include(second_destroy, "CardDied"), "安倍晴明 survival replacement should only work once", failures)
	_expect(state.get_player(0).grave.cards.has(ally_id), "安倍晴明 should allow the protected legion to die on the second destruction", failures)

static func _test_seimei_survival_expires_at_next_own_turn_start(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0411", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3702, [], _formal_options(2, 8))
	var seimei_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0411")
	var ally_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(seimei_id != "" and ally_id != "", "seimei expiry test should draw 安倍晴明 and an allied legion", failures)
	if seimei_id == "" or ally_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_seimei_expiry_ally_setup")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": seimei_id,
		"row": "back",
		"col": 0
	})).ok, "安倍晴明 expiry test should play successfully", failures)
	_expect(_resolve_candidate_choice(engine, state, "target_then_stack_effect", [ally_id]), "安倍晴明 expiry test should select an allied target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "安倍晴明 expiry test first response pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "安倍晴明 expiry test second response pass should resolve", failures)
	engine._begin_turn_for_player(state, 1)
	engine._begin_turn_for_player(state, 0)
	var protected_instance = state.card_instances.get(ally_id)
	_expect(protected_instance != null and int(protected_instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) == -1, "安倍晴明 survival effect should expire at the start of its controller next turn", failures)
	var destroy_after_expiry = engine._destroy_target_unit(state, {
		"targets": {
			"target_card_id": ally_id
		},
		"resolution": {
			"type": "legion",
			"target_scope": "allied_battlefield"
		}
	}, "test_seimei_destroy_after_expiry")
	_expect(_event_types_include(destroy_after_expiry, "CardDied"), "安倍晴明 should not prevent death after the next own turn begins", failures)
	_expect(state.get_player(0).grave.cards.has(ally_id), "安倍晴明 target should die normally after the protection expires", failures)

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

static func _event_types_include(events: Array, event_type: String) -> bool:
	for event in events:
		if str(event.type) == event_type:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
