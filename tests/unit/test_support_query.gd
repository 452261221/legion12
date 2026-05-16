extends RefCounted
class_name TestSupportQuery

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 222)

	var p0_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_card,
		"row": "front",
		"col": 0
	})).ok, "player 1 front play should succeed", failures)

	_advance_to_next_main(engine, state, failures, "advance to player 2 main should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached")
		return failures
	var p1_front = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": p1_front,
		"row": "front",
		"col": 0
	})).ok, "player 2 front play should succeed", failures)

	_advance_to_next_main(engine, state, failures, "advance to player 1 main should succeed")
	_advance_to_next_main(engine, state, failures, "advance to player 2 second main should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 second main phase was not reached")
		return failures
	var p1_back = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": p1_back,
		"row": "back",
		"col": 0
	})).ok, "player 2 back play should succeed", failures)

	_advance_to_next_main(engine, state, failures, "advance back to player 1 main should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached")
		return failures
	var attacker_id = state.players[0].battle_front[0].occupant
	var defender_id = state.players[1].battle_front[0].occupant
	var supporters = engine.get_legal_supporters(state, defender_id, attacker_id)
	_expect(supporters.size() == 1, "should find one legal supporter", failures)
	if supporters.size() == 1:
		_expect(supporters[0] == state.players[1].battle_back[0].occupant, "supporter should be the back-row unit in same lane", failures)
		var supporter_id = supporters[0]
		var attack_result = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
			"attacker_id": attacker_id,
			"defender_id": defender_id,
			"supporter_id": supporter_id
		}))
		_expect(attack_result.ok, "attack with support should succeed", failures)
		_resolve_pending_attack(engine, state, failures, "attack with support first pass should succeed", "attack with support second pass should resolve")
		_expect(state.players[1].battle_front[0].occupant == defender_id, "supported defender should remain on battlefield", failures)
		_expect(state.players[1].battle_back[0].occupant == "", "support should sacrifice the same-lane back-row legion", failures)
		_expect(state.players[1].grave.cards.has(supporter_id), "support should send the supporting legion to grave", failures)
		_expect(int(state.card_instances[defender_id].damage_marked) == 0, "support should fully negate the attack on the front-row defender", failures)

	return failures

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

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"]
	]

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
