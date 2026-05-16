extends RefCounted
class_name TestTakamagaharaBatch3

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_hijikata_entry_and_attack_destroy(failures)
	_test_hijikata_entry_with_only_one_valid_target(failures)
	_test_hijikata_entry_skips_without_valid_targets(failures)
	_test_naotora_entry_ready_and_died_draw(failures)
	_test_tenkabufu_modes(failures)
	return failures

static func _test_hijikata_entry_and_attack_destroy(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0406", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["asgard_s01_0316", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3201, [], _formal_options(3, 8))
	var enemy_cost_two = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	var enemy_small_a = _find_hand_card_by_definition(state, 1, "qa_plain")
	var enemy_small_b = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(enemy_cost_two != "" and enemy_small_a != "" and enemy_small_b != "", "hijikata test should draw one cost-2 and two cost-1 targets", failures)
	if enemy_cost_two == "" or enemy_small_a == "" or enemy_small_b == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_cost_two, "front", 0, "test_hijikata_cost_two")
	engine._deploy_hand_card_to_slot(state, 1, enemy_small_a, "front", 1, "test_hijikata_small_a")
	engine._deploy_hand_card_to_slot(state, 1, enemy_small_b, "front", 2, "test_hijikata_small_b")
	var hijikata_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0406")
	_expect(hijikata_id != "", "hijikata should be in opening hand", failures)
	if hijikata_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hijikata_id,
		"row": "front",
		"col": 0
	})).ok, "土方岁三 should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "土方岁三 entry should resolve to the combined destroy choice")
	var entry_choice = _pending_choice_by_operation(state, "hijikata_entry_destroy_combo")
	_expect(entry_choice != null, "土方岁三 entry should open a combined destroy choice when valid targets exist", failures)
	if entry_choice == null:
		return
	_expect(bool(entry_choice.get("requires_confirm", false)), "土方岁三 entry choice should require explicit confirm", failures)
	_expect(int(entry_choice.get("count", -1)) == 2, "土方岁三 entry choice should allow up to two selected targets when a cost-1 target exists", failures)
	_expect(not _resolve_candidate_choice(engine, state, "hijikata_entry_destroy_combo", [enemy_cost_two]), "土方岁三 entry should not confirm after selecting only one target while a valid second target still exists", failures)
	_expect(_resolve_candidate_choice(engine, state, "hijikata_entry_destroy_combo", [enemy_small_a, enemy_small_b]), "土方岁三 entry should also allow selecting two cost-1 targets together", failures)
	_expect(state.get_player(1).battle_front[1].occupant == "", "土方岁三 entry should destroy the first selected cost-1 target", failures)
	_expect(state.get_player(1).battle_front[2].occupant == "", "土方岁三 entry should destroy the second selected cost-1 target", failures)
	_advance_to_next_main(engine, state, failures, "hijikata test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "hijikata test should return to player 1 main")
	var hijikata_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(hijikata_instance_id == hijikata_id, "土方岁三 should remain on the battlefield for the attack test", failures)
	var defender_id = state.get_player(1).battle_front[0].occupant
	_expect(defender_id == enemy_cost_two, "hijikata attack test should keep the cost-2 target on the battlefield when entry destroys two cost-1 targets", failures)
	if defender_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hijikata_instance_id,
		"defender_id": defender_id
	})).ok, "土方岁三 should be able to declare an attack on the next turn", failures)
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "土方岁三 attack trigger should allow paying morale for the optional destroy effect", failures)
	_resolve_top_stack(engine, state, failures, "土方岁三 attack trigger should resolve to a destroy choice")
	_expect(_resolve_candidate_choice(engine, state, "destroy_battlefield_card", [enemy_cost_two]), "土方岁三 attack trigger should be able to destroy the remaining cost-2 target", failures)
	_expect(state.get_player(1).battle_front[0].occupant == "", "土方岁三 attack trigger should clear the last remaining target", failures)

static func _test_hijikata_entry_with_only_one_valid_target(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0406", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["asgard_s01_0316", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3206, [], _formal_options(2, 8))
	var enemy_cost_two = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	var hijikata_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0406")
	_expect(enemy_cost_two != "" and hijikata_id != "", "hijikata one-target test should draw hijikata and one cost-2 target", failures)
	if enemy_cost_two == "" or hijikata_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_cost_two, "front", 0, "test_hijikata_only_cost_two")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hijikata_id,
		"row": "front",
		"col": 0
	})).ok, "土方岁三 one-target test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "土方岁三 one-target entry should resolve to the combined destroy choice")
	var entry_choice = _pending_choice_by_operation(state, "hijikata_entry_destroy_combo")
	_expect(entry_choice != null, "土方岁三 one-target entry should still open a choice when one valid target exists", failures)
	if entry_choice == null:
		return
	_expect(int(entry_choice.get("count", -1)) == 1, "土方岁三 one-target entry should only allow one selection when no cost-1 target exists", failures)
	_expect(_resolve_candidate_choice(engine, state, "hijikata_entry_destroy_combo", [enemy_cost_two]), "土方岁三 one-target entry should confirm after selecting the only valid target", failures)
	_expect(state.get_player(1).battle_front[0].occupant == "", "土方岁三 one-target entry should destroy the only valid target", failures)

static func _test_hijikata_entry_skips_without_valid_targets(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0406", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3207, [], _formal_options(2, 8))
	var hijikata_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0406")
	_expect(hijikata_id != "", "hijikata skip test should draw hijikata", failures)
	if hijikata_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hijikata_id,
		"row": "front",
		"col": 0
	})).ok, "土方岁三 skip test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "土方岁三 skip test should resolve without creating a choice")
	_expect(_pending_choice_by_operation(state, "hijikata_entry_destroy_combo") == null, "土方岁三 entry should skip directly when no valid targets exist", failures)

static func _test_naotora_entry_ready_and_died_draw(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0402", "takamagahara_s01_0413", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3202, [], _formal_options(3, 8))
	var ally_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	var fodder_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var naotora_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0402")
	_expect(ally_id != "" and fodder_id != "" and naotora_id != "", "naotora test should draw ally, discard fodder and 井伊直虎", failures)
	if ally_id == "" or fodder_id == "" or naotora_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 0
	})).ok, "naotora setup should deploy the allied 高天原 legion", failures)
	var ally_instance_id = state.get_player(0).battle_front[0].occupant
	var ally_instance = state.card_instances.get(ally_instance_id)
	_expect(ally_instance != null, "naotora setup should create the allied legion instance", failures)
	if ally_instance == null:
		return
	ally_instance.orientation = "rested"
	var hand_before = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": naotora_id,
		"row": "front",
		"col": 1
	})).ok, "井伊直虎 should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "井伊直虎 entry should resolve to the optional discard choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "井伊直虎 entry should allow choosing the discard-to-ready effect", failures)
	_expect(_resolve_candidate_choice(engine, state, "discard_from_hand", [fodder_id]), "井伊直虎 entry should let the player choose the discarded hand card", failures)
	_expect(_resolve_candidate_choice(engine, state, "ready_battlefield_card", [ally_instance_id]), "井伊直虎 entry should let the player choose a rested allied 高天原 legion to ready", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before - 2, "井伊直虎 entry should spend itself and discard one extra hand card", failures)
	_expect(str(state.card_instances.get(ally_instance_id).orientation) == "active", "井伊直虎 entry should ready the selected allied legion", failures)
	var hand_before_draw = state.get_player(0).hand.cards.size()
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {
			"target_card_id": naotora_id
		},
		"resolution": {}
	}, "test_naotora_destroy")
	engine._enqueue_pending_triggers(state, destroy_events)
	engine._promote_next_pending_trigger(state, "test_naotora_promote")
	_resolve_top_stack(engine, state, failures, "井伊直虎 death trigger should resolve to the optional draw choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "井伊直虎 death trigger should allow choosing to draw", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_draw + 1, "井伊直虎 death trigger should draw one card when chosen", failures)

static func _test_tenkabufu_modes(failures: Array[String]) -> void:
	_test_tenkabufu_enemy_row_cost_down(failures)
	_test_tenkabufu_front_attack_bonus(failures)
	_test_tenkabufu_free_move(failures)

static func _test_tenkabufu_enemy_row_cost_down(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0406", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["asgard_s01_0316", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3203, [], _formal_options(2, 8))
	var tactic_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0406")
	var enemy_front = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	var enemy_back = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(tactic_id != "" and enemy_front != "" and enemy_back != "", "tenkabufu row-cost test should draw the setup cards", failures)
	if tactic_id == "" or enemy_front == "" or enemy_back == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_front, "front", 0, "test_tenkabufu_front")
	engine._deploy_hand_card_to_slot(state, 1, enemy_back, "back", 0, "test_tenkabufu_back")
	var enemy_front_id = state.get_player(1).battle_front[0].occupant
	var enemy_back_id = state.get_player(1).battle_back[0].occupant
	var front_cost_before = engine._get_effective_card_cost(state, enemy_front_id)
	var back_cost_before = engine._get_effective_card_cost(state, enemy_back_id)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id
	})).ok, "天下布武 should play successfully for the row-cost test", failures)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "enemy_front_cost_down"), "天下布武 should offer the enemy front-row cost-down option", failures)
	_expect(engine._get_effective_card_cost(state, enemy_front_id) == max(0, front_cost_before - 2), "天下布武 should reduce the enemy front-row legion cost by 2 this turn", failures)
	_expect(engine._get_effective_card_cost(state, enemy_back_id) == back_cost_before, "天下布武 front-row option should not affect enemy back-row legions", failures)

static func _test_tenkabufu_front_attack_bonus(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0406", "takamagahara_s01_0413", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3204, [], _formal_options(2, 8))
	var tactic_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0406")
	var ally_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(tactic_id != "" and ally_id != "" and enemy_id != "", "tenkabufu front-bonus test should draw the setup cards", failures)
	if tactic_id == "" or ally_id == "" or enemy_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 0
	})).ok, "tenkabufu front-bonus test should deploy the allied front legion", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_tenkabufu_bonus_enemy")
	var ally_instance_id = state.get_player(0).battle_front[0].occupant
	var power_before = engine.get_card_power(state, ally_instance_id)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id
	})).ok, "天下布武 should play successfully for the front-bonus test", failures)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "allied_front_attack_bonus"), "天下布武 should offer the allied front attack bonus option", failures)
	_expect(engine.get_card_power(state, ally_instance_id) == power_before, "天下布武 attack bonus should not change displayed power outside combat", failures)
	_advance_to_next_main(engine, state, failures, "tenkabufu front-bonus test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "tenkabufu front-bonus test should return to player 1 main")
	var defender_id = state.get_player(1).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": ally_instance_id,
		"defender_id": defender_id
	})).ok, "天下布武 front-bonus test should let the allied front legion attack next turn", failures)
	_expect(engine.get_card_power(state, ally_instance_id) == power_before + 1000, "天下布武 should grant +1000 power while the buffed front legion is attacking", failures)

static func _test_tenkabufu_free_move(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0406", "takamagahara_s01_0413", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3205, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 2,
		"opening_active_player_morale": 4,
		"opening_non_active_player_morale": 10,
		"manual_legion_move_enabled": true
	})
	var tactic_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0406")
	var ally_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	_expect(tactic_id != "" and ally_id != "", "tenkabufu free-move test should draw the tactic and an allied legion", failures)
	if tactic_id == "" or ally_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 1
	})).ok, "tenkabufu free-move test should deploy the allied legion", failures)
	_advance_to_next_main(engine, state, failures, "tenkabufu free-move test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "tenkabufu free-move test should return to player 1 main")
	var ally_instance_id = state.get_player(0).battle_front[1].occupant
	var active_morale_before = state.get_player(0).cost_area.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id
	})).ok, "天下布武 should play successfully for the free-move test", failures)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "allied_free_move"), "天下布武 should offer the allied free-move option", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": ally_instance_id,
		"row": "front",
		"col": 2
	})).ok, "天下布武 should allow the allied active legion to move for free this turn", failures)
	var last_move = _last_event_payload(state, "CardMoved")
	_expect(int(last_move.get("morale_cost", -1)) == 0, "天下布武 free-move option should make the first manual move cost 0 morale", failures)
	_expect(state.get_player(0).cost_area.cards.size() == active_morale_before, "天下布武 free-move option should not consume active morale on the free move", failures)

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

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, message, failures)
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, message, failures)

static func _drain_stack_and_choices(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(16):
		if state.pending_choices.is_empty() and state.stack.is_empty() and state.pending_attack.is_empty():
			return
		if not state.pending_choices.is_empty():
			var choice = state.pending_choices[0]
			var operation = str(choice.get("operation", ""))
			if operation == "optional_stack_effect" or operation == "pre_stack_optional_attack_trigger":
				_expect(_resolve_option_choice(engine, state, operation, "yes"), message, failures)
				continue
			if operation == "discard_from_hand":
				_expect(_resolve_candidate_choice(engine, state, operation, choice.get("candidate_card_ids", []).slice(0, 1)), message, failures)
				continue
			if operation == "search_deck_reorder_bottom":
				_expect(_resolve_candidate_choice(engine, state, operation, choice.get("candidate_card_ids", []).duplicate()), message, failures)
				continue
			failures.append(message)
			return
		_resolve_top_stack(engine, state, failures, message)
	failures.append(message)

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		if not state.pending_choices.is_empty() or not state.stack.is_empty() or not state.pending_attack.is_empty():
			_drain_stack_and_choices(engine, state, failures, message)
			if state.winner != -1:
				return
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)

static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
	})).ok

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

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

static func _last_event_payload(state, event_type: String) -> Dictionary:
	for index in range(state.event_log.size() - 1, -1, -1):
		var event = state.event_log[index]
		if str(event.type) == event_type:
			return event.payload.duplicate(true)
	return {}
