extends RefCounted
class_name TestContinuousEffects

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_aura_modifier_updates_power_query(failures)
	_test_aura_modifier_affects_combat(failures)
	return failures

static func _test_aura_modifier_updates_power_query(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _query_decks(), 801)
	var aura_id = _find_hand_card_by_definition(state, 0, "qa_banner")
	var ally_id = _find_hand_card_by_definition(state, 0, "qa_charge")
	_expect(aura_id != "", "continuous aura should be in opening hand", failures)
	_expect(ally_id != "", "continuous ally should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": aura_id,
		"row": "back",
		"col": 1
	})).ok, "continuous aura play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 0
	})).ok, "continuous ally play should succeed", failures)
	var ally_instance_id = state.players[0].battle_front[0].occupant
	var aura_instance_id = state.players[0].battle_back[1].occupant
	_expect(state.continuous_modifiers.size() == 1, "continuous aura should register one active modifier", failures)
	_expect(engine.get_card_power(state, ally_instance_id) == 4000, "continuous aura should raise allied unit power by 1000", failures)
	_expect(engine.get_card_power(state, aura_instance_id) == 1000, "continuous aura should not buff itself when exclude_self is true", failures)

static func _test_aura_modifier_affects_combat(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _combat_decks(), 802)
	var aura_id = _find_hand_card_by_definition(state, 0, "qa_banner")
	_expect(aura_id != "", "continuous aura should be in opening hand for combat test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": aura_id,
		"row": "back",
		"col": 1
	})).ok, "continuous aura play should succeed for combat test", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for combat setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for continuous combat setup")
		return
	var defender_id = _find_hand_card_by_definition(state, 1, "qa_equal")
	_expect(defender_id != "", "continuous defender should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": defender_id,
		"row": "front",
		"col": 0
	})).ok, "continuous defender play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for continuous combat test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for continuous combat test")
		return
	var attacker_id = _find_hand_card_by_definition(state, 0, "qa_charge")
	_expect(attacker_id != "", "continuous attacker should still be in hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "continuous attacker play should succeed", failures)
	var attacker_instance_id = state.players[0].battle_front[0].occupant
	var defender_instance_id = state.players[1].battle_front[0].occupant
	_expect(engine.get_card_power(state, attacker_instance_id) == 4000, "continuous aura should apply before combat", failures)
	var attack_result = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	}))
	_expect(attack_result.ok, "continuous aura combat attack should succeed", failures)
	_resolve_pending_attack(engine, state, failures, "continuous aura combat first pass should succeed", "continuous aura combat second pass should resolve")
	_expect(state.players[1].grave.cards.has(defender_instance_id), "buffed attacker should defeat equal defender", failures)
	_expect(state.players[0].battle_front[0].occupant == attacker_instance_id, "buffed attacker should survive combat", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _query_decks() -> Array:
	return [
		["qa_banner", "qa_charge", "qa_equal", "qa_equal", "qa_equal", "qa_equal"],
		["qa_equal", "qa_equal", "qa_equal", "qa_equal", "qa_equal", "qa_equal"]
	]

static func _combat_decks() -> Array:
	return [
		["qa_banner", "qa_charge", "qa_equal", "qa_equal", "qa_equal", "qa_equal"],
		["qa_equal", "qa_equal", "qa_equal", "qa_equal", "qa_equal", "qa_equal"]
	]

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)

static func _resolve_pending_attack(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	if state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, first_message, failures)
	if state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, second_message, failures)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
