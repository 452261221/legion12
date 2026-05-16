extends RefCounted
class_name TestRuleRegressions

const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_support_requires_combined_power(failures)
	_test_supported_attack_disables_kill_trigger(failures)
	_test_invalid_pending_support_does_not_prevent_combat(failures)
	_test_back_row_ranged_cannot_target_back_row(failures)
	_test_back_row_ranged_no_loss_still_cannot_target_back_row(failures)
	_test_combat_trigger_order_single_death(failures)
	_test_combat_trigger_order_simultaneous_death(failures)
	_test_set_counter_tactic_back_row_only_and_replaceable(failures)
	return failures


static func _test_support_requires_combined_power(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["rr_support_attacker_big", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 901, [], {"shuffle_player_decks": false})
	var attacker_id := _find_hand_card_by_definition(state, 0, "rr_support_attacker_big")
	var defender_id := _find_hand_card_by_definition(state, 1, "rr_vanilla_1000")
	var supporter_id := _find_nth_hand_card_by_definition(state, 1, "rr_vanilla_1000", 1)
	_deploy_for_attack_test(engine, state, 0, attacker_id, "front", 0, "rr_support_big_attacker")
	_deploy_for_attack_test(engine, state, 1, defender_id, "front", 0, "rr_support_defender")
	_deploy_for_attack_test(engine, state, 1, supporter_id, "back", 0, "rr_support_supporter")
	var supporters = engine.get_legal_supporters(state, defender_id, attacker_id)
	_expect(supporters.is_empty(), "support should fail when same-column front+back power is lower than the attack value", failures)
	var invalid_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"supporter_id": supporter_id
	}))
	_expect(not bool(invalid_attack.get("ok", false)) and str(invalid_attack.get("code", "")) == "INVALID_SUPPORTER", "insufficient support should reject DeclareAttack with supporter_id", failures)


static func _test_supported_attack_disables_kill_trigger(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["rr_kill_attacker", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 902, [], {"shuffle_player_decks": false})
	var attacker_id := _find_hand_card_by_definition(state, 0, "rr_kill_attacker")
	var defender_id := _find_hand_card_by_definition(state, 1, "rr_vanilla_1000")
	var supporter_id := _find_nth_hand_card_by_definition(state, 1, "rr_vanilla_1000", 1)
	_deploy_for_attack_test(engine, state, 0, attacker_id, "front", 0, "rr_kill_attacker_deploy")
	_deploy_for_attack_test(engine, state, 1, defender_id, "front", 0, "rr_kill_defender_deploy")
	_deploy_for_attack_test(engine, state, 1, supporter_id, "back", 0, "rr_kill_supporter_deploy")
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"supporter_id": supporter_id
	}))
	_expect(bool(attack.get("ok", false)), "supported combat test should allow a legal support declaration", failures)
	_resolve_pending_attack(engine, state, failures, "supported combat test first priority pass should succeed", "supported combat test second priority pass should resolve")
	_expect(state.get_player(1).battle_front[0].occupant == defender_id, "supported defender should remain on the battlefield", failures)
	_expect(state.get_player(1).grave.cards.has(supporter_id), "supporter should die to protect the front-row defender", failures)
	_expect(not _queued_trigger_effect_ids(state).has("kill_gain"), "supported combat should not queue attacker kill triggers", failures)


static func _test_invalid_pending_support_does_not_prevent_combat(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["rr_kill_attacker", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 912, [], {"shuffle_player_decks": false})
	var attacker_id := _find_hand_card_by_definition(state, 0, "rr_kill_attacker")
	var defender_id := _find_hand_card_by_definition(state, 1, "rr_vanilla_1000")
	var same_row_id := _find_nth_hand_card_by_definition(state, 1, "rr_vanilla_1000", 1)
	_deploy_for_attack_test(engine, state, 0, attacker_id, "front", 0, "rr_invalid_support_attacker")
	_deploy_for_attack_test(engine, state, 1, defender_id, "front", 0, "rr_invalid_support_defender")
	_deploy_for_attack_test(engine, state, 1, same_row_id, "front", 1, "rr_invalid_support_same_row")
	state.pending_attack = {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id,
		"supporter_id": same_row_id,
		"response_window_opened": true
	}
	state.priority_player = 1
	state.priority_pass_count = 0
	_resolve_pending_attack(engine, state, failures, "invalid pending support first priority pass should succeed", "invalid pending support second priority pass should resolve")
	_expect(state.get_player(1).grave.cards.has(defender_id), "same-row pending support should not prevent normal combat from killing the defender", failures)
	_expect(not state.get_player(1).grave.cards.has(same_row_id), "same-row pending support should not be spent as a supporter", failures)
	_expect(state.get_player(1).battle_front[1].occupant == same_row_id, "same-row pending support should remain in its front-row slot", failures)
	_expect(not _has_event_type(state, "SupportDeclared"), "same-row pending support should not emit SupportDeclared", failures)
	_expect(not _has_event_type(state, "SupportPreventedDeath"), "same-row pending support should not emit SupportPreventedDeath", failures)


static func _test_back_row_ranged_cannot_target_back_row(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["rr_ranged", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 903, [], {"shuffle_player_decks": false})
	var attacker_id := _find_hand_card_by_definition(state, 0, "rr_ranged")
	var front_target_id := _find_hand_card_by_definition(state, 1, "rr_vanilla_1000")
	var back_target_id := _find_nth_hand_card_by_definition(state, 1, "rr_vanilla_1000", 1)
	_deploy_for_attack_test(engine, state, 0, attacker_id, "back", 0, "rr_ranged_attacker")
	_deploy_for_attack_test(engine, state, 1, front_target_id, "front", 0, "rr_ranged_front_target")
	_deploy_for_attack_test(engine, state, 1, back_target_id, "back", 0, "rr_ranged_back_target")
	var targets = engine.get_legal_attack_targets(state, attacker_id)
	_expect(_targets_include_card(targets, front_target_id), "back-row ranged attacker should still target enemy front row", failures)
	_expect(not _targets_include_card(targets, back_target_id), "back-row ranged attacker should not target enemy back row", failures)
	var invalid_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": back_target_id
	}))
	_expect(not bool(invalid_attack.get("ok", false)) and str(invalid_attack.get("code", "")) == "RANGED_TARGET_NOT_ALLOWED", "back-row ranged DeclareAttack should reject enemy back-row targets", failures)


static func _test_back_row_ranged_no_loss_still_cannot_target_back_row(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["rr_ranged_no_loss", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 913, [], {"shuffle_player_decks": false})
	var attacker_id := _find_hand_card_by_definition(state, 0, "rr_ranged_no_loss")
	var front_target_id := _find_hand_card_by_definition(state, 1, "rr_vanilla_1000")
	var back_target_id := _find_nth_hand_card_by_definition(state, 1, "rr_vanilla_1000", 1)
	_deploy_for_attack_test(engine, state, 0, attacker_id, "back", 0, "rr_ranged_no_loss_attacker")
	_deploy_for_attack_test(engine, state, 1, front_target_id, "front", 0, "rr_ranged_no_loss_front_target")
	_deploy_for_attack_test(engine, state, 1, back_target_id, "back", 0, "rr_ranged_no_loss_back_target")
	var targets = engine.get_legal_attack_targets(state, attacker_id)
	_expect(_targets_include_card(targets, front_target_id), "back-row ranged no-loss attacker should still target enemy front row", failures)
	_expect(not _targets_include_card(targets, back_target_id), "back-row ranged no-loss attacker should not target enemy back row", failures)
	var invalid_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": back_target_id
	}))
	_expect(not bool(invalid_attack.get("ok", false)) and str(invalid_attack.get("code", "")) == "RANGED_TARGET_NOT_ALLOWED", "back-row ranged no-loss DeclareAttack should reject enemy back-row targets", failures)


static func _test_combat_trigger_order_single_death(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["rr_kill_attacker", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_death_defender", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 904, [], {"shuffle_player_decks": false})
	var attacker_id := _find_hand_card_by_definition(state, 0, "rr_kill_attacker")
	var defender_id := _find_hand_card_by_definition(state, 1, "rr_death_defender")
	_deploy_for_attack_test(engine, state, 0, attacker_id, "front", 0, "rr_single_order_attacker")
	_deploy_for_attack_test(engine, state, 1, defender_id, "front", 0, "rr_single_order_defender")
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	}))
	_expect(bool(attack.get("ok", false)), "single-death order test attack should declare", failures)
	_resolve_pending_attack(engine, state, failures, "single-death order test first priority pass should succeed", "single-death order test second priority pass should resolve")
	_expect(_queued_trigger_effect_ids(state) == ["kill_gain", "death_gain"], "single-death combat should queue kill trigger before defender death trigger", failures)


static func _test_combat_trigger_order_simultaneous_death(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["rr_both_attacker", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_both_defender", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 905, [], {"shuffle_player_decks": false})
	var attacker_id := _find_hand_card_by_definition(state, 0, "rr_both_attacker")
	var defender_id := _find_hand_card_by_definition(state, 1, "rr_both_defender")
	_deploy_for_attack_test(engine, state, 0, attacker_id, "front", 0, "rr_both_order_attacker")
	_deploy_for_attack_test(engine, state, 1, defender_id, "front", 0, "rr_both_order_defender")
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	}))
	_expect(bool(attack.get("ok", false)), "simultaneous-death order test attack should declare", failures)
	_resolve_pending_attack(engine, state, failures, "simultaneous-death order test first priority pass should succeed", "simultaneous-death order test second priority pass should resolve")
	_expect(_queued_trigger_effect_ids(state) == ["attacker_kill", "defender_kill", "attacker_death", "defender_death"], "simultaneous combat should queue attacker kill, defender kill, attacker death, defender death", failures)


static func _test_set_counter_tactic_back_row_only_and_replaceable(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["rr_counter", "rr_counter", "rr_legion_small", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 906, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 3,
		"opening_non_active_player_morale": 0
	})
	var counter_id := _find_hand_card_by_definition(state, 0, "rr_counter")
	var counter_slots = engine.get_legal_play_slots(state, 0, counter_id)
	_expect(counter_slots.size() == 3, "set counter tactics should only expose three back-row slots", failures)
	for slot in counter_slots:
		_expect(str(slot.get("row", "")) == "back", "all set counter tactic slots should stay in the back row", failures)
	var front_invalid = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 0
	}))
	_expect(not bool(front_invalid.get("ok", false)) and str(front_invalid.get("code", "")) == "COUNTER_TACTIC_BACK_ROW_ONLY", "set counter tactics should reject front-row placement", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "back",
		"col": 0
	})).ok, "set counter tactics should still deploy to the back row", failures)
	var covered_counter_id := counter_id
	var legion_id := _find_hand_card_by_definition(state, 0, "rr_legion_small")
	var legion_slots = engine.get_legal_play_slots(state, 0, legion_id)
	_expect(_slot_list_has(legion_slots, "back", 0), "legions should be able to replace a facedown covered card", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": legion_id,
		"row": "back",
		"col": 0
	})).ok, "legion should replace the facedown covered card", failures)
	_expect(state.get_player(0).grave.cards.has(covered_counter_id), "replaced covered card should go to grave", failures)
	_expect(state.get_player(0).battle_back[0].occupant == legion_id, "replacement legion should occupy the covered slot", failures)

	var counter_state = engine.create_game(_definitions(), [
		["rr_counter", "rr_counter", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"],
		["rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000", "rr_vanilla_1000"]
	], 907, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 3,
		"opening_non_active_player_morale": 0
	})
	var first_counter_id := _find_hand_card_by_definition(counter_state, 0, "rr_counter")
	_expect(engine.apply_command(counter_state, GameCommand.create(0, "PlayCard", {
		"card_id": first_counter_id,
		"row": "back",
		"col": 1
	})).ok, "first covered counter should deploy", failures)
	var second_counter_id := _find_hand_card_by_definition(counter_state, 0, "rr_counter")
	_expect(second_counter_id != "" and second_counter_id != first_counter_id, "counter replacement test should still have a second counter in hand", failures)
	if second_counter_id != "" and second_counter_id != first_counter_id:
		_expect(engine.apply_command(counter_state, GameCommand.create(0, "PlayCard", {
			"card_id": second_counter_id,
			"row": "back",
			"col": 1
		})).ok, "counter tactics should also replace facedown covered cards", failures)
		_expect(counter_state.get_player(0).grave.cards.has(first_counter_id), "replaced covered counter should go to grave", failures)
		_expect(counter_state.get_player(0).battle_back[1].occupant == second_counter_id, "replacement counter should occupy the covered slot", failures)


static func _deploy_for_attack_test(engine: GameEngine, state, player_id: int, card_id: String, row: String, col: int, command_id: String) -> void:
	if card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, player_id, card_id, row, col, command_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.entered_turn = max(-1, state.turn_number - 1)


static func _resolve_pending_attack(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	if state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, first_message, failures)
	if state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, second_message, failures)


static func _queued_trigger_effect_ids(state) -> Array[String]:
	var ordered: Array[String] = []
	for stack_item in state.stack:
		ordered.append(str((stack_item as Dictionary).get("effect_id", "")))
	for trigger_item in state.pending_triggers:
		ordered.append(str((trigger_item as Dictionary).get("effect_id", "")))
	return ordered


static func _targets_include_card(targets: Array, defender_id: String) -> bool:
	for target in targets:
		if str((target as Dictionary).get("defender_id", "")) == defender_id:
			return true
	return false


static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false


static func _slot_list_has(slots: Array, row: String, col: int) -> bool:
	for slot in slots:
		if str((slot as Dictionary).get("row", "")) == row and int((slot as Dictionary).get("col", -1)) == col:
			return true
	return false


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	return _find_nth_hand_card_by_definition(state, player_id, definition_id, 0)


static func _find_nth_hand_card_by_definition(state, player_id: int, definition_id: String, occurrence: int) -> String:
	var found := 0
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance == null or str(instance.definition_id) != definition_id:
			continue
		if found == occurrence:
			return str(card_id)
		found += 1
	return ""


static func _definitions() -> Array:
	return [
		{
			"id": "rr_vanilla_1000",
			"type": "legion",
			"cost": 1,
			"power": 1000,
			"hp": 1000,
			"keywords": [],
			"traits": [],
			"effects": []
		},
		{
			"id": "rr_legion_small",
			"type": "legion",
			"cost": 1,
			"power": 1000,
			"hp": 1000,
			"keywords": [],
			"traits": [],
			"effects": []
		},
		{
			"id": "rr_support_attacker_big",
			"type": "legion",
			"cost": 1,
			"power": 3000,
			"hp": 3000,
			"keywords": [],
			"traits": [],
			"effects": []
		},
		{
			"id": "rr_ranged",
			"type": "legion",
			"cost": 1,
			"power": 2000,
			"hp": 2000,
			"keywords": ["ranged"],
			"traits": [],
			"effects": []
		},
		{
			"id": "rr_counter",
			"type": "counter_tactic",
			"cost": 1,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "counter_stack",
					"kind": "activated",
					"can_activate_on_stack": true,
					"response_only": true,
					"resolution": {"action": "counter_target_stack"}
				}
			]
		},
		{
			"id": "rr_kill_attacker",
			"type": "legion",
			"cost": 1,
			"power": 2000,
			"hp": 2000,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "kill_gain",
					"kind": "triggered",
					"event": "CardDied",
					"self_only": true,
					"allow_grave_source": true,
					"condition": {
						"source_card_id_is_self": true,
						"source_kind_is": "attack"
					},
					"resolution": {
						"action": "add_morale",
						"count": 1,
						"orientation": "active"
					}
				}
			]
		},
		{
			"id": "rr_ranged_no_loss",
			"type": "legion",
			"cost": 1,
			"power": 2000,
			"hp": 2000,
			"keywords": ["ranged", "attack_no_loss"],
			"traits": [],
			"effects": []
		},
		{
			"id": "rr_death_defender",
			"type": "legion",
			"cost": 1,
			"power": 1000,
			"hp": 1000,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "death_gain",
					"kind": "triggered",
					"event": "CardDied",
					"self_only": true,
					"allow_grave_source": true,
					"resolution": {
						"action": "draw_cards",
						"count": 1
					}
				}
			]
		},
		{
			"id": "rr_both_attacker",
			"type": "legion",
			"cost": 1,
			"power": 2000,
			"hp": 2000,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "attacker_kill",
					"kind": "triggered",
					"event": "CardDied",
					"self_only": true,
					"allow_grave_source": true,
					"condition": {
						"source_card_id_is_self": true,
						"source_kind_is": "attack"
					},
					"resolution": {
						"action": "add_morale",
						"count": 1,
						"orientation": "active"
					}
				},
				{
					"id": "attacker_death",
					"kind": "triggered",
					"event": "CardDied",
					"self_only": true,
					"allow_grave_source": true,
					"resolution": {
						"action": "draw_cards",
						"count": 1
					}
				}
			]
		},
		{
			"id": "rr_both_defender",
			"type": "legion",
			"cost": 1,
			"power": 2000,
			"hp": 2000,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "defender_kill",
					"kind": "triggered",
					"event": "CardDied",
					"self_only": true,
					"allow_grave_source": true,
					"condition": {
						"source_card_id_is_self": true,
						"source_kind_is": "attack"
					},
					"resolution": {
						"action": "add_morale",
						"count": 1,
						"orientation": "active"
					}
				},
				{
					"id": "defender_death",
					"kind": "triggered",
					"event": "CardDied",
					"self_only": true,
					"allow_grave_source": true,
					"resolution": {
						"action": "draw_cards",
						"count": 1
					}
				}
			]
		}
	]


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
