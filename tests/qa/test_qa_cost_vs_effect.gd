extends RefCounted
class_name TestQaCostVsEffect

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_cost_paid_but_effect_countered(failures)
	_test_unrespondable_stack_item_rejects_counter(failures)
	_test_segmented_effect_counters_only_one_segment(failures)
	_test_replacement_prevents_lethal_master_damage_once(failures)
	return failures

static func _test_cost_paid_but_effect_countered(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 606)
	var caster_id = _find_hand_card_by_definition(state, 0, "qa_sage")
	_expect(caster_id != "", "qa source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": caster_id,
		"row": "front",
		"col": 0
	})).ok, "qa source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for qa setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for qa setup")
		return
	var counter_id = _find_hand_card_by_definition(state, 1, "qa_nullifier")
	_expect(counter_id != "", "qa counter source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 0
	})).ok, "qa counter source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for qa activation should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for qa activation")
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var morale_before = state.get_player(0).cost_area.cards.size()
	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": caster_id,
		"effect_id": "draw_one"
	}))
	_expect(activate_result.ok, "qa effect activation should succeed", failures)
	_expect(state.stack.size() == 1, "qa source effect should be on stack", failures)
	var target_stack_id = str(state.stack[0].get("stack_id", ""))
	var counter_result = engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "counter_top",
		"target_stack_id": target_stack_id
	}))
	_expect(counter_result.ok, "qa counter activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "qa first priority pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "qa second priority pass should succeed", failures)
	_expect(state.stack.is_empty(), "qa counter should leave stack empty", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "qa countered effect should not change hand count", failures)
	_expect(state.get_player(0).cost_area.cards.size() == morale_before - 1, "qa paid morale should remain consumed after counter", failures)
	_expect(_has_event_type(state, "CostPaid"), "qa sequence should log CostPaid", failures)
	_expect(_has_event_type(state, "EffectCountered"), "qa sequence should log EffectCountered", failures)

static func _test_unrespondable_stack_item_rejects_counter(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 607)
	var trial_id = _find_hand_card_by_definition(state, 0, "qa_trial")
	_expect(trial_id != "", "qa unrespondable source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": trial_id,
		"row": "front",
		"col": 0
	})).ok, "qa unrespondable source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for unrespondable setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for unrespondable setup")
		return
	var counter_id = _find_hand_card_by_definition(state, 1, "qa_nullifier")
	_expect(counter_id != "", "qa counter source should be in opening hand for unrespondable test", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 0
	})).ok, "qa counter source play should succeed for unrespondable test", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for unrespondable activation should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for unrespondable activation")
		return
	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": trial_id,
		"effect_id": "trial_progress"
	}))
	_expect(activate_result.ok, "qa unrespondable effect activation should succeed", failures)
	_expect(state.stack.size() == 1, "qa unrespondable effect should enter stack", failures)
	var target_stack_id = str(state.stack[0].get("stack_id", ""))
	var counter_attempt = engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "counter_top",
		"target_stack_id": target_stack_id
	}))
	_expect(not counter_attempt.ok, "qa counter should reject non-respondable stack items", failures)
	_expect(str(counter_attempt.get("code", "")) == "INVALID_EFFECT_TARGET", "qa counter should fail with INVALID_EFFECT_TARGET for non-respondable stack items", failures)
	_expect(state.stack.size() == 1, "qa unrespondable stack item should remain on stack after rejected counter", failures)

static func _test_segmented_effect_counters_only_one_segment(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 608)
	var combo_id = _find_hand_card_by_definition(state, 0, "qa_combo")
	_expect(combo_id != "", "qa segmented source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": combo_id,
		"row": "front",
		"col": 0
	})).ok, "qa segmented source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for segmented setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for segmented setup")
		return
	var counter_id = _find_hand_card_by_definition(state, 1, "qa_nullifier")
	_expect(counter_id != "", "qa counter source should be in opening hand for segmented test", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 0
	})).ok, "qa counter source play should succeed for segmented test", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for segmented activation should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for segmented activation")
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var cost_before = state.get_player(0).cost_area.cards.size()
	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": combo_id,
		"effect_id": "combo_draw"
	}))
	_expect(activate_result.ok, "qa segmented activation should succeed", failures)
	_expect(state.stack.size() == 2, "qa segmented activation should create two stack items", failures)
	var draw_stack_id = ""
	for item in state.stack:
		if str(item.get("effect_id", "")) == "combo_draw":
			draw_stack_id = str(item.get("stack_id", ""))
			break
	_expect(not draw_stack_id.is_empty(), "qa segmented draw stack item should exist", failures)
	if draw_stack_id.is_empty():
		return
	var counter_result = engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "counter_top",
		"target_stack_id": draw_stack_id
	}))
	_expect(counter_result.ok, "qa segmented counter activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "qa segmented first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "qa segmented second pass should resolve counter", failures)
	_expect(state.stack.size() == 1, "qa segmented counter should remove only the targeted segment", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "qa segmented third pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "qa segmented fourth pass should resolve surviving segment", failures)
	_expect(state.stack.is_empty(), "qa segmented stack should be empty after surviving segment resolves", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "qa segmented draw segment should stay countered", failures)
	_expect(state.get_player(0).cost_area.cards.size() == cost_before, "qa segmented surviving segment should add one morale after paying one cost", failures)
	_expect(_has_event_type(state, "EffectCountered"), "qa segmented sequence should log EffectCountered", failures)

static func _test_replacement_prevents_lethal_master_damage_once(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 609)
	var attacker_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(attacker_id != "", "qa attacker should be in opening hand for replacement test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "qa attacker play should succeed for replacement test", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for replacement setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for replacement setup")
		return
	var guardian_id = _find_hand_card_by_definition(state, 1, "qa_guardian")
	_expect(guardian_id != "", "qa guardian should be in opening hand for replacement test", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": guardian_id,
		"row": "back",
		"col": 1
	})).ok, "qa guardian play should succeed for replacement test", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for replacement attack should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for replacement attack")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 1
	})).ok, "qa replacement hp setup should succeed", failures)
	var lethal_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": state.players[0].battle_front[0].occupant,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(lethal_attack.ok, "qa lethal direct attack should succeed", failures)
	_resolve_priority_window(engine, state, failures, "qa lethal attack first pass should succeed", "qa lethal attack second pass should resolve")
	_expect(state.players[1].master_hp == 1, "replacement should keep defending master at 1 hp", failures)
	_expect(state.winner == -1, "replacement should prevent immediate loss", failures)
	_expect(_has_event_type(state, "ReplacementEffectApplied"), "replacement usage should be logged", failures)
	_advance_to_player_next_main(engine, state, 0, failures, "advance back to player 1 main for second lethal attack should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for second lethal attack")
		return
	var second_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": state.players[0].battle_front[0].occupant,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(second_attack.ok, "qa second direct attack should succeed", failures)
	_resolve_priority_window(engine, state, failures, "qa second lethal attack first pass should succeed", "qa second lethal attack second pass should resolve")
	_expect(state.players[1].master_hp == 0, "second lethal attack should resolve after one-time replacement is consumed", failures)
	_expect(state.winner == 0, "second lethal attack should decide the winner", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["qa_sage", "qa_trial", "qa_combo", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_nullifier", "qa_guardian", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
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

static func _advance_to_player_next_main(engine: GameEngine, state, player_id: int, failures: Array[String], message: String) -> void:
	var advanced = false
	for _i in range(12):
		if advanced and state.active_player == player_id and state.phase == "main":
			return
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		advanced = true
	if advanced and state.active_player == player_id and state.phase == "main":
		return
	failures.append(message)

static func _resolve_priority_window(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	if state.stack.is_empty() and state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, first_message, failures)
	if state.stack.is_empty() and state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, second_message, failures)

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
