extends RefCounted
class_name TestEffectStack

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_activated_effect_stack(failures)
	_test_trigger_queue(failures)
	_test_response_counter_keeps_paid_cost(failures)
	_test_counter_tactic_from_hand_counters_tactic(failures)
	_test_counter_tactic_sees_multiple_stack_targets(failures)
	_test_mystery_effect_resolves_draw(failures)
	return failures

static func _test_activated_effect_stack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 55)
	var effect_card_id = _find_hand_card_by_definition(state, 0, "dev_legion_sage")
	_expect(effect_card_id != "", "activated effect source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": effect_card_id,
		"row": "front",
		"col": 0
	})).ok, "effect source play should succeed", failures)
	var activatable = engine.get_activatable_effects(state, 0)
	_expect(activatable.size() == 1, "one activated effect should be exposed", failures)
	_expect(str(activatable[0].get("effect_id", "")) == "draw_one", "activated effect id should match", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": effect_card_id,
		"effect_id": "draw_one"
	}))
	_expect(activate_result.ok, "activate effect should succeed", failures)
	_expect(state.stack.size() == 1, "activated effect should enter stack", failures)
	_expect(state.priority_player == 1, "priority should pass to opponent after activation", failures)
	var blocked_result = engine.apply_command(state, GameCommand.create(0, "EndPhase"))
	_expect(not blocked_result.ok, "other commands should be blocked while stack is not empty", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "opponent first pass should succeed", failures)
	_expect(state.priority_player == 0, "priority should return after first pass", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "second pass should resolve stack", failures)
	_expect(state.stack.is_empty(), "stack should resolve after two passes", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + 1, "activated draw effect should draw one card", failures)
	_expect(_has_event_type(state, "CostPaid"), "cost paid event should be logged", failures)
	_expect(_has_event_type(state, "EffectResolved"), "effect resolved event should be logged", failures)

static func _test_trigger_queue(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 77)
	var trigger_card_id = _find_hand_card_by_definition(state, 0, "dev_legion_herald")
	var vanilla_card_id = _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(trigger_card_id != "", "trigger source should be in opening hand", failures)
	_expect(vanilla_card_id != "", "vanilla card should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": trigger_card_id,
		"row": "front",
		"col": 0
	})).ok, "trigger source play should succeed", failures)
	_expect(state.stack.size() == 1, "trigger source play should queue its own triggered effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "first pass for self trigger should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "second pass for self trigger should resolve", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": vanilla_card_id,
		"row": "front",
		"col": 1
	})).ok, "second play should succeed and queue trigger", failures)
	_expect(state.pending_triggers.is_empty(), "pending trigger should be promoted immediately when stack is empty", failures)
	_expect(state.stack.size() == 1, "triggered effect should be promoted to stack", failures)
	_expect(state.priority_player == 1, "priority should move to opponent for triggered stack item", failures)
	_expect(_has_event_type(state, "TriggerQueued"), "trigger queued event should be logged", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "first pass for trigger stack should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "second pass for trigger stack should succeed", failures)
	_expect(state.stack.is_empty(), "trigger stack should resolve after two passes", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "triggered draw should restore one hand card after second play", failures)

static func _test_response_counter_keeps_paid_cost(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_response_definitions(), _response_decks(), 66)
	var sage_id = _find_hand_card_by_definition(state, 0, "dev_legion_sage")
	_expect(sage_id != "", "response test source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sage_id,
		"row": "front",
		"col": 0
	})).ok, "response test source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for counter setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for counter setup")
		return
	var counter_id = _find_hand_card_by_definition(state, 1, "dev_legion_nullifier")
	_expect(counter_id != "", "counter source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 0
	})).ok, "counter source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for activation should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for activation")
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": sage_id,
		"effect_id": "draw_one"
	}))
	_expect(activate_result.ok, "base effect activation should succeed before counter", failures)
	_expect(state.stack.size() == 1, "base effect should enter stack before counter", failures)
	var target_stack_id = str(state.stack[0].get("stack_id", ""))
	var counter_effects = engine.get_activatable_effects(state, 1)
	_expect(counter_effects.size() == 1, "priority player should see one response effect", failures)
	var counter_result = engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "counter_draw",
		"target_stack_id": target_stack_id
	}))
	_expect(counter_result.ok, "response counter activation should succeed on stack", failures)
	_expect(state.stack.size() == 2, "counter effect should stack above original effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "active player should be able to pass to counter resolution", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "counter owner should be able to resolve response", failures)
	_expect(state.stack.is_empty(), "counter resolution should remove the original stack item", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "countered effect should not draw cards", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 1, "paid activation cost should not roll back after counter", failures)
	_expect(_has_event_type(state, "EffectCountered"), "counter resolution should emit EffectCountered", failures)

static func _test_counter_tactic_from_hand_counters_tactic(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _counter_tactic_decks(), 67)
	var tactic_id = _find_hand_card_by_definition(state, 0, "dev_tactic_rally")
	var counter_tactic_id = _find_hand_card_by_definition(state, 1, "dev_counter_tactic_nullify")
	_expect(tactic_id != "", "base tactic should be in opening hand", failures)
	_expect(counter_tactic_id != "", "counter tactic should be in opening hand", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	var deck_before = state.get_player(0).deck.cards.size()
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(cast_result.ok, "base tactic cast should succeed", failures)
	_expect(state.stack.size() == 1, "base tactic should enter stack", failures)
	var legal_counter_targets = engine.get_legal_tactic_targets(state, 1, counter_tactic_id)
	_expect(legal_counter_targets.size() == 1, "counter tactic should expose one stack target", failures)
	_expect(str(legal_counter_targets[0].get("target_kind", "")) == "stack", "counter tactic should target stack entries", failures)
	var target_stack_id = str(state.stack[0].get("stack_id", ""))
	var counter_cast_result = engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_tactic_id,
		"row": "counter_tactic",
		"col": -1,
		"target_stack_id": target_stack_id
	}))
	_expect(counter_cast_result.ok, "counter tactic cast should succeed on stack", failures)
	_expect(state.stack.size() == 2, "counter tactic should stack above original tactic", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "active player should pass to counter tactic", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "counter tactic owner should resolve response", failures)
	_expect(state.stack.is_empty(), "counter tactic should clear the full stack", failures)
	_expect(state.players[0].grave.cards.has(tactic_id), "countered tactic should move to grave", failures)
	_expect(state.players[1].grave.cards.has(counter_tactic_id), "resolved counter tactic should move to grave", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before, "countered tactic should not resolve its draw", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before - 1, "countered tactic should leave hand without replacing itself", failures)
	_expect(_has_event_type(state, "EffectCountered"), "counter tactic should emit EffectCountered", failures)

static func _test_counter_tactic_sees_multiple_stack_targets(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _multi_stack_counter_decks(), 68)
	var combo_id = _find_hand_card_by_definition(state, 0, "qa_combo")
	var counter_tactic_id = _find_hand_card_by_definition(state, 1, "dev_counter_tactic_nullify")
	_expect(combo_id != "", "combo source should be in opening hand", failures)
	_expect(counter_tactic_id != "", "counter tactic should be in opening hand for multi-stack test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": combo_id,
		"row": "front",
		"col": 0
	})).ok, "combo source play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": combo_id,
		"effect_id": "combo_draw"
	})).ok, "combo activation should succeed", failures)
	_expect(state.stack.size() == 2, "combo activation should create two stack items", failures)
	var legal_counter_targets = engine.get_legal_tactic_targets(state, 1, counter_tactic_id)
	_expect(legal_counter_targets.size() == 2, "counter tactic should expose two stack targets for segmented effect", failures)
	for target in legal_counter_targets:
		_expect(str(target.get("target_kind", "")) == "stack", "multi-stack targets should all be stack entries", failures)

static func _test_mystery_effect_resolves_draw(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _unimplemented_decks(), 88)
	var source_id = _find_hand_card_by_definition(state, 0, "dev_legion_mystery")
	_expect(source_id != "", "mystery effect source should be in opening hand", failures)
	var hand_before := state.get_player(0).hand.cards.size()
	var deck_before := state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": source_id,
		"row": "front",
		"col": 0
	})).ok, "mystery effect source play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": source_id,
		"effect_id": "mystery_action"
	})).ok, "mystery effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "first pass for mystery effect should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "second pass for mystery effect should resolve", failures)
	_expect(not _has_event_type(state, "UnimplementedEffectTriggered"), "implemented mystery effect should not emit unimplemented events", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "mystery effect should replace itself by drawing one card", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 1, "mystery effect should consume one card from deck", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _response_definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_sage", "dev_legion_herald", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"]
	]

static func _unimplemented_decks() -> Array:
	return [
		["dev_legion_mystery", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"]
	]

static func _response_decks() -> Array:
	return [
		["dev_legion_sage", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_nullifier", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"]
	]

static func _counter_tactic_decks() -> Array:
	return [
		["dev_tactic_rally", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_counter_tactic_nullify", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"]
	]

static func _multi_stack_counter_decks() -> Array:
	return [
		["qa_combo"],
		["dev_counter_tactic_nullify"]
	]

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)

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

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
