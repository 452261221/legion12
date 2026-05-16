extends RefCounted
class_name TestArtifactPlay

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_artifact_can_be_played_to_artifact_zone(failures)
	_test_artifact_play_replaces_existing_artifact(failures)
	_test_artifact_activatable_effects_are_exposed(failures)
	_test_artifact_activated_effect_from_artifact_zone(failures)
	return failures

static func _test_artifact_can_be_played_to_artifact_zone(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 910)
	var artifact_id = _find_hand_card_by_definition(state, 0, "dev_artifact_lens")
	_expect(artifact_id != "", "artifact should be in opening hand", failures)
	var legal_slots = engine.get_legal_play_slots(state, 0, artifact_id)
	_expect(legal_slots.size() == 1, "artifact should expose exactly one legal play target", failures)
	if not legal_slots.is_empty():
		_expect(str(legal_slots[0].get("row", "")) == "artifact", "artifact play target should be artifact zone", failures)
	var play_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(play_result.ok, "artifact play should succeed", failures)
	_expect(state.players[0].artifact_zone.cards.has(artifact_id), "artifact should move to artifact zone", failures)
	_expect(not state.players[0].hand.cards.has(artifact_id), "artifact should leave hand after play", failures)
	var instance = state.card_instances.get(artifact_id)
	_expect(instance != null and instance.zone == "artifact_zone", "artifact instance zone should become artifact_zone", failures)
	_expect(_has_event_type(state, "CardPlayed"), "artifact play should log CardPlayed", failures)

static func _test_artifact_play_replaces_existing_artifact(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _replacement_decks(), 913)
	var first_artifact_id = _find_hand_card_by_definition(state, 0, "dev_artifact_lens")
	_expect(first_artifact_id != "", "first artifact should be in opening hand for replacement test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "first artifact play should succeed in replacement test", failures)
	var second_artifact_id = _find_hand_card_by_definition(state, 0, "dev_artifact_lens")
	_expect(second_artifact_id != "" and second_artifact_id != first_artifact_id, "second artifact copy should remain in hand for replacement test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "second artifact play should replace the existing artifact", failures)
	_expect(state.players[0].artifact_zone.cards.size() == 1, "artifact zone should still contain exactly one artifact after replacement", failures)
	_expect(state.players[0].artifact_zone.cards.has(second_artifact_id), "new artifact should occupy the artifact zone after replacement", failures)
	_expect(not state.players[0].artifact_zone.cards.has(first_artifact_id), "old artifact should leave artifact zone after replacement", failures)
	_expect(state.players[0].grave.cards.has(first_artifact_id), "old artifact should be moved to grave when replaced", failures)
	var old_instance = state.card_instances.get(first_artifact_id)
	var new_instance = state.card_instances.get(second_artifact_id)
	_expect(old_instance != null and old_instance.zone == "grave", "replaced artifact instance zone should become grave", failures)
	_expect(new_instance != null and new_instance.zone == "artifact_zone", "replacement artifact instance zone should become artifact_zone", failures)
	_expect(_has_card_sent_to_grave_from_artifact_zone(state, first_artifact_id), "artifact replacement should log CardSentToGrave from artifact_zone", failures)

static func _test_artifact_activatable_effects_are_exposed(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 912)
	var artifact_id = _find_hand_card_by_definition(state, 0, "dev_artifact_lens")
	_expect(artifact_id != "", "artifact should be in opening hand for activatable query test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "artifact play for activatable query test should succeed", failures)
	var activatable = engine.get_activatable_effects(state, 0)
	_expect(activatable.size() == 1, "artifact zone should expose one activatable effect", failures)
	if not activatable.is_empty():
		_expect(str(activatable[0].get("source_id", "")) == artifact_id, "artifact activatable effect source should match played artifact", failures)
		_expect(str(activatable[0].get("effect_id", "")) == "lens_draw", "artifact activatable effect id should match data definition", failures)
		_expect(str(activatable[0].get("zone", "")) == "artifact_zone", "artifact activatable effect should report artifact zone source", failures)

static func _test_artifact_activated_effect_from_artifact_zone(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 911)
	var artifact_id = _find_hand_card_by_definition(state, 0, "dev_artifact_lens")
	_expect(artifact_id != "", "artifact should be in opening hand for activation test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "artifact play for activation test should succeed", failures)
	var hand_before = state.players[0].hand.cards.size()
	var morale_before = state.players[0].cost_area.cards.size()
	var result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": artifact_id,
		"effect_id": "lens_draw"
	}))
	_expect(result.ok, "artifact activated effect should succeed from artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "artifact effect first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "artifact effect second pass should resolve", failures)
	_expect(state.players[0].hand.cards.size() == hand_before + 1, "artifact activated effect should draw one card", failures)
	_expect(state.players[0].cost_area.cards.size() == morale_before - 1, "artifact activated effect should consume one active morale", failures)
	_expect(_has_event_type(state, "CardDrawn"), "artifact activated effect should log CardDrawn", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_artifact_lens", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _replacement_decks() -> Array:
	return [
		["dev_artifact_lens", "dev_artifact_lens", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _has_card_sent_to_grave_from_artifact_zone(state, card_id: String) -> bool:
	for event in state.event_log:
		if str(event.type) != "CardSentToGrave":
			continue
		var payload = event.payload
		if not (payload is Dictionary):
			continue
		if str(payload.get("card_id", "")) == card_id and str(payload.get("from", "")) == "artifact_zone":
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
