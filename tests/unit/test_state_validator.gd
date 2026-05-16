extends RefCounted
class_name TestStateValidator

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const StateValidator = preload("res://rules/core/validators.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_duplicate_zone_detection(failures)
	_test_invalid_stack_effect_detection(failures)
	return failures

static func _test_duplicate_zone_detection(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 404)
	var duplicated_card_id = state.players[0].hand.cards[0]
	state.players[0].grave.add_card(duplicated_card_id)
	var errors = StateValidator.validate(state)
	_expect(_contains_message(errors, "Card appears multiple times"), "validator should report duplicate card references", failures)

static func _test_invalid_stack_effect_detection(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 405)
	var source_id = state.players[0].hand.cards[0]
	state.stack.append({
		"stack_id": "stack_bad",
		"controller": 0,
		"source_instance_id": source_id,
		"effect_id": "missing_effect",
		"effect_type": "activated",
		"resolution": {}
	})
	var errors = StateValidator.validate(state)
	_expect(_contains_message(errors, "effect does not exist on source"), "validator should report missing stack effects", failures)

static func _contains_message(messages: Array[String], needle: String) -> bool:
	for message in messages:
		if needle in message:
			return true
	return false

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
