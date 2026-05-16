extends RefCounted
class_name TestAsgardBatch5

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameEvent = preload("res://rules/core/game_event.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_margaret_entry_mills_and_has_ranged(failures)
	_test_margaret_effect_damage_rests_heals_and_blocks_legion_heal(failures)
	_test_margaret_triggers_for_play_option_damage_and_requires_active(failures)
	_test_margaret_only_triggers_for_own_master_on_own_turn(failures)
	return failures

static func _test_margaret_entry_mills_and_has_ranged(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0304", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 4001, [], _formal_options(1, 3))
	var margaret_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0304")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(margaret_id != "" and enemy_id != "", "margaret entry test should draw 玛格丽特一世 and an enemy legion", failures)
	if margaret_id == "" or enemy_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_margaret_enemy_setup")
	var milled_card_id = str(state.get_player(0).deck.cards[0])
	var deck_size_before_play = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": margaret_id,
		"row": "back",
		"col": 0
	})).ok, "玛格丽特一世 should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "玛格丽特一世 entry should resolve to the optional mill choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "玛格丽特一世 should allow choosing to mill the top card", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_size_before_play - 1, "玛格丽特一世 should mill exactly one card from its controller deck", failures)
	_expect(state.get_player(0).grave.cards.has(milled_card_id), "玛格丽特一世 should put the milled top card into its controller grave", failures)
	state.card_instances[margaret_id].entered_turn = -1
	state.card_instances[enemy_id].entered_turn = -1
	var legal_targets = engine.get_legal_attack_targets(state, margaret_id)
	_expect(_targets_include_card(legal_targets, enemy_id), "玛格丽特一世 should be able to attack from the back row with ranged", failures)

static func _test_margaret_effect_damage_rests_heals_and_blocks_legion_heal(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0304", "asgard_s02_0302", "takamagahara_s02_0406", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 4002, [], _formal_options(3, 3))
	var margaret_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0304")
	var rollo_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0302")
	var tactic_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0406")
	_expect(margaret_id != "" and rollo_id != "" and tactic_id != "", "margaret trigger test should draw 玛格丽特一世, 步行者罗洛 and a tactic source", failures)
	if margaret_id == "" or rollo_id == "" or tactic_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": margaret_id,
		"row": "back",
		"col": 0
	})).ok, "玛格丽特一世 trigger test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "玛格丽特一世 trigger test should resolve to the optional mill choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "玛格丽特一世 trigger test should be able to skip the entry mill", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 18
	})).ok, "玛格丽特一世 trigger test should set the controller master hp for setup", failures)
	var damage_events = engine._deal_master_damage(state, 0, 1, "test_margaret_effect_damage", {
		"source_card_id": tactic_id,
		"source_kind": "effect"
	})
	engine._enqueue_pending_triggers(state, damage_events)
	engine._promote_next_pending_trigger(state, "test_margaret_promote")
	_resolve_top_stack(engine, state, failures, "玛格丽特一世 effect-damage trigger should resolve to the optional rest choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "玛格丽特一世 should allow choosing to rest and heal after effect damage", failures)
	var margaret_instance = state.card_instances.get(margaret_id)
	_expect(margaret_instance != null and str(margaret_instance.orientation) == "rested", "玛格丽特一世 should rest itself after choosing the triggered effect", failures)
	_expect(state.get_player(0).master_hp == 18, "玛格丽特一世 should heal back the 1 master damage it responded to", failures)
	_expect(bool(state.get_player(0).flags.get("legion_source_heal_block_until_turn_end", false)), "玛格丽特一世 should block further legion-source healing for the turn", failures)
	_expect(_has_event_type(state, "CardRested"), "玛格丽特一世 trigger should log CardRested", failures)
	_expect(_has_event_type(state, "MasterHealed"), "玛格丽特一世 trigger should log MasterHealed", failures)

	var blocked_hp = state.get_player(0).master_hp
	_append_effect_resolved_event(state, 0, rollo_id, "test_margaret_legion_heal_blocked")
	var blocked_heal_events = engine._heal_master(state, 0, 1, "test_margaret_legion_heal_blocked")
	_expect(blocked_heal_events.is_empty(), "玛格丽特一世 should block healing from legion effects for the rest of the turn", failures)
	_expect(state.get_player(0).master_hp == blocked_hp, "玛格丽特一世 should keep master hp unchanged when blocking a legion heal", failures)

	_append_effect_resolved_event(state, 0, tactic_id, "test_margaret_tactic_heal_allowed")
	var tactic_heal_events = engine._heal_master(state, 0, 1, "test_margaret_tactic_heal_allowed")
	_expect(_event_types_include(tactic_heal_events, "MasterHealed"), "玛格丽特一世 should not block healing from non-legion effects", failures)
	_expect(state.get_player(0).master_hp == blocked_hp + 1, "玛格丽特一世 should still allow non-legion healing during the same turn", failures)

	engine._begin_turn_for_player(state, 1)
	engine._begin_turn_for_player(state, 0)
	_expect(not bool(state.get_player(0).flags.get("legion_source_heal_block_until_turn_end", false)), "玛格丽特一世 heal block should expire by the start of its controller next turn", failures)
	var hp_before_expired_legion_heal = state.get_player(0).master_hp
	_append_effect_resolved_event(state, 0, rollo_id, "test_margaret_legion_heal_after_expiry")
	var expired_legion_heal_events = engine._heal_master(state, 0, 1, "test_margaret_legion_heal_after_expiry")
	_expect(_event_types_include(expired_legion_heal_events, "MasterHealed"), "玛格丽特一世 should allow legion healing again after the block expires", failures)
	_expect(state.get_player(0).master_hp == hp_before_expired_legion_heal + 1, "玛格丽特一世 should stop blocking legion healing after the next own turn begins", failures)

static func _test_margaret_triggers_for_play_option_damage_and_requires_active(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0304", "asgard_s01_0314", "asgard_s01_0314", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 4004, [], _formal_options(3, 5))
	var margaret_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0304")
	var first_olga_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0314")
	var second_olga_id = _find_second_hand_card_by_definition(state, 0, "asgard_s01_0314", first_olga_id)
	_expect(margaret_id != "" and first_olga_id != "" and second_olga_id != "", "margaret play-option test should draw 玛格丽特一世 and two blood-price legions", failures)
	if margaret_id == "" or first_olga_id == "" or second_olga_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": margaret_id,
		"row": "back",
		"col": 0
	})).ok, "玛格丽特一世 play-option test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "玛格丽特一世 play-option test should resolve to the optional mill choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "玛格丽特一世 play-option test should be able to skip the entry mill", failures)

	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_olga_id,
		"row": "front",
		"col": 0,
		"play_option_id": "olga_blood_price"
	})).ok, "first blood-price legion should play successfully beside 玛格丽特一世", failures)
	_resolve_top_stack(engine, state, failures, "玛格丽特一世 should trigger from play-option self damage")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "玛格丽特一世 should allow resting to heal after play-option self damage", failures)
	var margaret_instance = state.card_instances.get(margaret_id)
	_expect(margaret_instance != null and str(margaret_instance.orientation) == "rested", "玛格丽特一世 should rest after responding to play-option self damage", failures)
	_expect(state.get_player(0).master_hp == 20, "玛格丽特一世 should heal the blood-price damage back to full HP", failures)
	_expect(int(state.get_player(0).flags.get("master_effect_damage_taken_this_turn", 0)) == 1, "blood-price damage should count as effect damage for turn tracking", failures)

	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_olga_id,
		"row": "front",
		"col": 1,
		"play_option_id": "olga_blood_price"
	})).ok, "second blood-price legion should still play successfully", failures)
	_expect(_pending_choice_by_operation(state, "optional_stack_effect") == null, "rested 玛格丽特一世 should not offer its heal trigger again", failures)
	_expect(state.stack.is_empty() and state.pending_triggers.is_empty(), "rested 玛格丽特一世 should not leave a queued trigger after the second blood-price damage", failures)
	_expect(state.get_player(0).master_hp == 19, "second blood-price damage should remain when 玛格丽特一世 is already rested", failures)

static func _test_margaret_only_triggers_for_own_master_on_own_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0304", "takamagahara_s02_0406", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 4003, [], _formal_options(2, 3))
	var margaret_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0304")
	var tactic_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0406")
	_expect(margaret_id != "" and tactic_id != "", "margaret restriction test should draw 玛格丽特一世 and a tactic source", failures)
	if margaret_id == "" or tactic_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": margaret_id,
		"row": "back",
		"col": 0
	})).ok, "玛格丽特一世 restriction test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "玛格丽特一世 restriction test should resolve to the optional mill choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "玛格丽特一世 restriction test should be able to skip the entry mill", failures)

	var opponent_master_damage_events = engine._deal_master_damage(state, 1, 1, "test_margaret_opponent_master_damage", {
		"source_card_id": tactic_id,
		"source_kind": "effect"
	})
	engine._enqueue_pending_triggers(state, opponent_master_damage_events)
	_expect(state.pending_triggers.is_empty() and state.stack.is_empty(), "玛格丽特一世 should not trigger when the opponent master takes effect damage", failures)

	engine._begin_turn_for_player(state, 1)
	var own_master_damage_on_opponent_turn = engine._deal_master_damage(state, 0, 1, "test_margaret_wrong_turn", {
		"source_card_id": tactic_id,
		"source_kind": "effect"
	})
	engine._enqueue_pending_triggers(state, own_master_damage_on_opponent_turn)
	_expect(state.pending_triggers.is_empty() and state.stack.is_empty(), "玛格丽特一世 should not trigger during the opponent turn", failures)

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

static func _append_effect_resolved_event(state, player_id: int, source_id: String, command_id: String) -> void:
	var event = GameEvent.create(state.next_event_id(), "EffectResolved", player_id, {
		"stack_id": "",
		"source_id": source_id,
		"effect_id": "test_effect",
		"effect_type": "activated"
	})
	event.created_by_command = command_id
	state.event_log.append(event)

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, message, failures)
	if not first_pass.ok or not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, message, failures)

static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
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

static func _find_second_hand_card_by_definition(state, player_id: int, definition_id: String, first_card_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		if card_id == first_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _targets_include_card(targets: Array, target_card_id: String) -> bool:
	for target in targets:
		if target is Dictionary and str(target.get("defender_id", "")) == target_card_id:
			return true
	return false

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
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
