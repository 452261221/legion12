extends RefCounted
class_name TestDebugCommand

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_debug_draw_cards(failures)
	_test_debug_add_morale(failures)
	_test_debug_set_master_hp(failures)
	_test_debug_invalid_inputs(failures)
	return failures

static func _test_debug_draw_cards(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 801)
	var hand_before = state.players[0].hand.cards.size()
	var deck_before = state.players[0].deck.cards.size()
	var result = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "draw_cards",
		"player_id": 0,
		"count": 1
	}))
	_expect(result.ok, "debug draw should succeed", failures)
	_expect(state.players[0].hand.cards.size() == hand_before + 1, "debug draw should increase hand size by 1", failures)
	_expect(state.players[0].deck.cards.size() == deck_before - 1, "debug draw should decrease deck size by 1", failures)
	_expect(_has_event_type(state, "CardDrawn"), "debug draw should log CardDrawn", failures)

static func _test_debug_add_morale(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 802)
	var morale_before = state.players[0].cost_area.cards.size()
	var cost_deck_before = state.players[0].cost_deck.cards.size()
	var result = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	}))
	_expect(result.ok, "debug add morale should succeed", failures)
	_expect(state.players[0].cost_area.cards.size() == morale_before + 1, "debug add morale should increase active morale area by 1", failures)
	_expect(state.players[0].cost_deck.cards.size() == cost_deck_before - 1, "debug add morale should decrease cost deck by 1", failures)
	_expect(_has_event_type(state, "MoraleAdded"), "debug add morale should log MoraleAdded", failures)

static func _test_debug_set_master_hp(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 803)
	var result = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 7
	}))
	_expect(result.ok, "debug set master hp should succeed", failures)
	_expect(state.players[1].master_hp == 7, "debug set master hp should update master hp", failures)
	_expect(_has_event_type(state, "MasterHpSet"), "debug set master hp should log MasterHpSet", failures)

static func _test_debug_invalid_inputs(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 804)
	var unknown_action = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "not_real"
	}))
	_expect(not unknown_action.ok and str(unknown_action.get("code", "")) == "UNKNOWN_DEBUG_ACTION", "unknown debug action should fail", failures)
	var invalid_player = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "draw_cards",
		"player_id": 99,
		"count": 1
	}))
	_expect(not invalid_player.ok and str(invalid_player.get("code", "")) == "INVALID_PLAYER", "debug draw with invalid player should fail", failures)
	var invalid_count = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 0
	}))
	_expect(not invalid_count.ok and str(invalid_count.get("code", "")) == "INVALID_COUNT", "debug add morale with non-positive count should fail", failures)
	var invalid_hp = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": -1
	}))
	_expect(not invalid_hp.ok and str(invalid_hp.get("code", "")) == "INVALID_HP", "debug set master hp with negative hp should fail", failures)
	var invalid_calamity = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_calamity_value",
		"value": -1
	}))
	_expect(not invalid_calamity.ok and str(invalid_calamity.get("code", "")) == "INVALID_CALAMITY_VALUE", "debug set calamity value with negative value should fail", failures)
	var unknown_calamity = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "missing_calamity"
	}))
	_expect(not unknown_calamity.ok and str(unknown_calamity.get("code", "")) == "UNKNOWN_CALAMITY", "debug reveal unknown calamity should fail", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
