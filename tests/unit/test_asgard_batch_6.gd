extends RefCounted
class_name TestAsgardBatch6

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_canute_blood_price_and_trigger_died_effects(failures)
	_test_canute_requires_distinct_names(failures)
	_test_canute_is_playable_at_six_morale_with_blood_price(failures)
	return failures

static func _test_canute_blood_price_and_trigger_died_effects(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0303", "asgard_s01_0309", "asgard_s01_0301", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 4101, [
		{"name": "P1", "master_hp": 5, "master_max_hp": 20},
		{"name": "P2", "master_hp": 6, "master_max_hp": 20}
	], _formal_options(3, 8))
	var canute_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0303")
	var brynhildr_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0309")
	var beowulf_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0301")
	_expect(canute_id != "" and brynhildr_id != "" and beowulf_id != "", "canute test should draw 卡纽特大帝、布伦希尔德和贝奥武夫", failures)
	if canute_id == "" or brynhildr_id == "" or beowulf_id == "":
		return
	_move_hand_card_to_grave(state, 0, beowulf_id)
	engine._deploy_hand_card_to_slot(state, 0, brynhildr_id, "front", 0, "test_canute_setup")
	state.card_instances[brynhildr_id].entered_turn = -1
	var hand_before_play = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canute_id,
		"play_option_id": "canute_blood_price",
		"row": "back",
		"col": 0
	})).ok, "卡纽特大帝 should play successfully with blood price", failures)
	_expect(state.get_player(0).master_hp == 4, "卡纽特大帝 blood price should deal 1 damage to its controller master", failures)
	_resolve_top_stack(engine, state, failures, "卡纽特大帝 entry should resolve to the died-effect target choice")
	_expect(_resolve_card_choice(engine, state, "trigger_selected_legion_died_effects", [brynhildr_id, beowulf_id]), "卡纽特大帝 should select one battlefield and one grave asgard legion", failures)
	_resolve_optional_stack_effects_yes(engine, state, failures, "卡纽特大帝 should resolve selected died effects")
	_expect(state.get_player(0).hand.cards.size() == hand_before_play + 1, "卡纽特大帝 should net +1 card after spending itself and resolving two draw-on-death effects", failures)
	_expect(_event_types_include(state, "TriggerQueued"), "卡纽特大帝 should queue triggered death effects from the selected cards", failures)

static func _test_canute_requires_distinct_names(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0303", "asgard_s01_0301", "asgard_s01_0301", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 4102, [], _formal_options(3, 8))
	var canute_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0303")
	var beowulf_hand_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0301")
	_expect(canute_id != "" and beowulf_hand_id != "", "canute duplicate-name test should draw 卡纽特大帝 and 贝奥武夫", failures)
	if canute_id == "" or beowulf_hand_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, beowulf_hand_id, "front", 0, "test_canute_duplicate_setup")
	state.card_instances[beowulf_hand_id].entered_turn = -1
	var beowulf_grave_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0301")
	_expect(beowulf_grave_id != "", "canute duplicate-name test should keep a second 贝奥武夫 in hand", failures)
	if beowulf_grave_id == "":
		return
	_move_hand_card_to_grave(state, 0, beowulf_grave_id)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canute_id,
		"row": "back",
		"col": 0
	})).ok, "卡纽特大帝 duplicate-name test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "卡纽特大帝 duplicate-name test should resolve to target choice")
	var duplicate_choice = _pending_choice_by_operation(state, "trigger_selected_legion_died_effects")
	_expect(duplicate_choice != null, "卡纽特大帝 duplicate-name test should present the died-effect target choice", failures)
	if duplicate_choice == null:
		return
	var invalid_result = engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(duplicate_choice.get("choice_id", "")),
		"selected_card_ids": [beowulf_hand_id, beowulf_grave_id]
	}))
	_expect(not invalid_result.ok and str(invalid_result.get("code", "")) == "INVALID_CHOICE", "卡纽特大帝 should reject duplicate legion names when choosing died effects", failures)

static func _test_canute_is_playable_at_six_morale_with_blood_price(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0303", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 4103, [
		{"name": "P1", "master_hp": 6, "master_max_hp": 20},
		{"name": "P2", "master_hp": 6, "master_max_hp": 20}
	], _formal_options(1, 6))
	var canute_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0303")
	_expect(canute_id != "", "卡纽特大帝 6费 test should draw 卡纽特大帝", failures)
	if canute_id == "":
		return
	var found_blood_price := false
	for action in engine.get_legal_actions(state, 0):
		if str(action.get("kind", "")) != "play_card":
			continue
		var payload = action.get("payload_template", {})
		if str(payload.get("card_id", "")) != canute_id:
			continue
		if str(payload.get("play_option_id", "")) == "canute_blood_price":
			found_blood_price = true
			break
	_expect(found_blood_price, "卡纽特大帝 should expose the blood-price play action at six morale", failures)

static func _definitions() -> Array:
	var definitions = CardDatabase.load_definitions()
	definitions.append_array([
		{
			"id": "qa_blank",
			"name": "测试空白卡",
			"faction": "neutral",
			"type": "tactic",
			"cost": 1,
			"power": 0,
			"hp": 0,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试用空白卡。"
		}
	])
	return definitions

static func _formal_options(opening_hand_size: int, opening_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": 8
	}

static func _move_hand_card_to_grave(state, player_id: int, card_id: String) -> void:
	var player = state.get_player(player_id)
	player.hand.remove_card(card_id)
	player.grave.add_card(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "grave"
		instance.position = {}
		instance.orientation = "active"

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, message, failures)
	if not first_pass.ok or not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, message, failures)

static func _resolve_optional_stack_effects_yes(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(16):
		if state.pending_choices.is_empty() and state.stack.is_empty() and state.pending_triggers.is_empty():
			return
		if not state.pending_choices.is_empty():
			var choice = state.pending_choices[0]
			if str(choice.get("operation", "")) != "optional_stack_effect":
				failures.append("%s (unexpected pending choice: %s)" % [message, str(choice.get("operation", ""))])
				return
			var resolved = engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
				"choice_id": str(choice.get("choice_id", "")),
				"selected_option": "yes"
			}))
			_expect(resolved.ok, message, failures)
			continue
		if not state.stack.is_empty():
			_resolve_top_stack(engine, state, failures, message)
			continue
		if not state.pending_triggers.is_empty():
			var promoted = engine._promote_next_pending_trigger(state, "test_canute_promote")
			_expect(not promoted.is_empty(), message, failures)
			continue
	failures.append("%s (did not settle)" % message)

static func _resolve_card_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array[String]) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected_card_ids
	})).ok

static func _pending_choice_by_operation(state, operation: String):
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return null

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

static func _event_types_include(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
