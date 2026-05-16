extends RefCounted
class_name TestCoreFlow

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 100)

	_expect(state.players[0].hand.cards.size() == 5, "player 1 hand count should be 5", failures)
	_expect(state.players[1].hand.cards.size() == 5, "player 2 hand count should be 5", failures)
	_expect(engine.get_legal_play_slots(state, 0, state.players[0].hand.cards[0]).size() == 6, "empty battlefield should expose 6 play slots", failures)

	var p0_card = state.players[0].hand.cards[0]
	var play_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_card,
		"row": "front",
		"col": 0
	}))
	_expect(play_result.ok, "player 1 play should succeed", failures)
	var opening_actions = engine.get_legal_actions(state, 0)
	_expect(_has_command_type(opening_actions, "EndPhase"), "main phase legal actions should include EndPhase", failures)

	_advance_to_next_main(engine, state, failures, "phase advance to player 2 should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("turn should pass to player 2 main")
		return failures
	var p1_card = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": p1_card,
		"row": "front",
		"col": 0
	})).ok, "player 2 play should succeed", failures)

	_advance_to_next_main(engine, state, failures, "phase advance back to player 1 should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("turn should return to player 1 main")
		return failures
	var legal_targets = engine.get_legal_attack_targets(state, state.players[0].battle_front[0].occupant)
	_expect(_has_attack_target_kind(legal_targets, "card"), "front-row attacker should still be able to attack the enemy legion", failures)
	_expect(_has_attack_target_kind(legal_targets, "master"), "front-row attacker should also be able to attack master even when the enemy front row is occupied", failures)

	var attack_result = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": state.players[0].battle_front[0].occupant,
		"defender_id": state.players[1].battle_front[0].occupant
	}))
	_expect(attack_result.ok, "basic attack should succeed", failures)
	_expect(str(attack_result.get("state_hash_before", "")) != "", "command result should include state_hash_before", failures)
	_expect(str(attack_result.get("state_hash_after", "")) != "", "command result should include state_hash_after", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForPriority", "declared attack should wait for priority", failures)
	_expect(int(waiting.get("player_id", -1)) == 1, "defending player should receive priority after attack declaration", failures)
	var defender_actions = engine.get_legal_actions(state, 1)
	_expect(_has_command_type(defender_actions, "PassPriority"), "priority player should be able to pass during attack response window", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "attack response first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "attack response second pass should resolve attack", failures)
	_expect(state.players[1].grave.cards.size() == 1, "defender should move to grave after the response window closes", failures)
	_expect(state.players[0].battle_front[0].occupant == p0_card, "attacker should remain on battlefield after surviving combat", failures)
	_expect(engine.get_card_power(state, p0_card) == 1000, "surviving attacker should lose power equal to defender power this turn", failures)
	var last_command = state.command_log.back()
	_expect(str(last_command.get("state_hash_before", "")) != "", "command log should include state_hash_before", failures)
	_expect(str(last_command.get("state_hash_after", "")) != "", "command log should include state_hash_after", failures)
	_test_formal_opening_and_turn_progression(failures)
	_test_formal_opening_supports_custom_active_player_and_deck_order(failures)
	_test_opening_draws_from_shuffled_deck_top(failures)
	_test_formal_morale_faction_effect_activates_from_morale_source(failures)
	_test_formal_takamagahara_morale_draw_can_move_active_legion(failures)
	_test_formal_move_legion_consumes_morale(failures)
	_test_formal_cavalry_manual_move_is_free_any_slot_same_turn(failures)
	_test_formal_hiromasa_attack_draw_requests_optional_choice(failures)
	_test_formal_komatsu_requires_target_choice_on_play_and_attack(failures)
	_test_formal_kusanagi_enter_requires_destroy_target_choice(failures)
	_test_formal_counter_tactic_sets_on_battlefield_and_responds(failures)
	_test_choose_defense_rejects_generic_hand_blocker(failures)
	_test_master_guard_prevents_master_damage(failures)
	_test_block_then_counter_pending_attack(failures)
	_test_master_guard_then_counter_pending_attack(failures)
	_test_back_row_legion_cannot_attack_master(failures)
	_test_empty_deck_draw_causes_immediate_loss(failures)

	return failures

static func _test_empty_deck_draw_causes_immediate_loss(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 108, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	_expect(state.get_player(1).deck.cards.size() == 0, "deck-out test should leave player 2 with no cards after opening draw", failures)
	for _i in range(4):
		if state.winner != -1:
			break
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, "deck-out test should advance into player 2 turn start", failures)
	_expect(state.winner == 0, "empty-deck draw should immediately make the opponent win", failures)
	_expect(str(state.loss_reason) == "deck_out", "empty-deck draw should use deck_out as loss reason", failures)

static func _test_formal_opening_and_turn_progression(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _formal_decks(), 101, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	_expect(state.active_player == 0 and state.phase == "main", "formal game should begin at player 1 main phase", failures)
	_expect(state.players[0].hand.cards.size() == 6, "formal opening hand count for player 1 should be 6", failures)
	_expect(state.players[1].hand.cards.size() == 6, "formal opening hand count for player 2 should be 6", failures)
	_expect(state.players[0].cost_area.cards.size() == 1, "formal opening should give player 1 exactly 1 morale", failures)
	_expect(state.players[1].cost_area.cards.is_empty(), "formal opening should give player 2 no starting morale", failures)

	var p0_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_card,
		"row": "front",
		"col": 0
	})).ok, "formal game player 1 should still be able to play a 1-cost legion", failures)
	var p0_legion = state.players[0].battle_front[0].occupant
	_expect(p0_legion != "", "formal game should place the played legion on the battlefield", failures)
	if p0_legion != "":
		state.card_instances[p0_legion].damage_marked = 1000

	_advance_to_next_main(engine, state, failures, "formal game should advance to player 2 main")
	_expect(state.active_player == 1 and state.phase == "main", "formal game should hand turn to player 2 main", failures)
	_expect(state.players[1].hand.cards.size() == 7, "formal turn start should draw 1 card for player 2", failures)
	_expect(state.players[1].cost_area.cards.size() == 2, "formal turn start should add 2 morale for player 2", failures)
	_expect(state.calamity_value == 1, "formal end of turn should increase calamity value by 1", failures)
	if p0_legion != "":
		_expect(state.card_instances[p0_legion].damage_marked == 0, "formal end of turn should restore battlefield legion power", failures)

static func _test_opening_draws_from_shuffled_deck_top(failures: Array[String]) -> void:
	var definitions := _unique_opening_definitions()
	var decks := _unique_opening_decks()
	var seed := 20260430
	var no_draw_options := {
		"mode": "formal",
		"shuffle_player_decks": true,
		"opening_hand_size": 0,
		"opening_active_player_morale": 0,
		"opening_non_active_player_morale": 0
	}
	var draw_options := no_draw_options.duplicate(true)
	draw_options["opening_hand_size"] = 6
	var shuffled_only = GameEngine.new().create_game(definitions, decks, seed, [], no_draw_options)
	var drawn = GameEngine.new().create_game(definitions, decks, seed, [], draw_options)
	for player_id in range(2):
		var expected_hand := _definition_ids_for_cards(shuffled_only, shuffled_only.players[player_id].deck.cards, 0, 6)
		var actual_hand := _definition_ids_for_cards(drawn, drawn.players[player_id].hand.cards)
		_expect(_same_string_arrays(expected_hand, actual_hand), "formal opening hand should be drawn from shuffled deck top for player %d" % (player_id + 1), failures)
		var expected_remaining_deck := _definition_ids_for_cards(shuffled_only, shuffled_only.players[player_id].deck.cards, 6)
		var actual_remaining_deck := _definition_ids_for_cards(drawn, drawn.players[player_id].deck.cards)
		_expect(_same_string_arrays(expected_remaining_deck, actual_remaining_deck), "formal opening draw should remove the top 6 cards for player %d" % (player_id + 1), failures)
	var original_top: Array[String] = []
	for index in range(6):
		original_top.append(str(decks[0][index]))
	var shuffled_top := _definition_ids_for_cards(shuffled_only, shuffled_only.players[0].deck.cards, 0, 6)
	_expect(not _same_string_arrays(original_top, shuffled_top), "formal shuffle should alter the opening deck top order for the verification seed", failures)


static func _test_formal_opening_supports_custom_active_player_and_deck_order(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var custom_p0_deck = _formal_decks()[0].duplicate()
	var custom_p1_deck = _formal_decks()[1].duplicate()
	custom_p0_deck.reverse()
	var state = engine.create_game(_definitions(), _formal_decks(), 199, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"starting_active_player": 1,
		"player_deck_orders": [custom_p0_deck, custom_p1_deck]
	})
	_expect(state.active_player == 1, "custom formal opening should respect starting_active_player", failures)
	_expect(state.priority_player == 1, "custom formal opening should align priority with starting_active_player", failures)
	_expect(state.players[0].hand.cards.size() == 6 and state.players[1].hand.cards.size() == 6, "custom formal opening should still draw 6 cards for both players", failures)
	_expect(state.players[0].cost_area.cards.is_empty(), "custom non-active player should not receive starting morale", failures)
	_expect(state.players[1].cost_area.cards.size() == 1, "custom active player should receive starting morale", failures)
	var p0_top_card_id := str(state.players[0].hand.cards[0])
	var p1_top_card_id := str(state.players[1].hand.cards[0])
	var p0_top_instance = state.card_instances.get(p0_top_card_id)
	var p1_top_instance = state.card_instances.get(p1_top_card_id)
	var p0_top := str(p0_top_instance.definition_id) if p0_top_instance != null else ""
	var p1_top := str(p1_top_instance.definition_id) if p1_top_instance != null else ""
	_expect(p0_top == custom_p0_deck[0], "custom player 1 deck order should determine the opening hand top", failures)
	_expect(p1_top == custom_p1_deck[0], "custom player 2 deck order should determine the opening hand top", failures)

static func _test_back_row_legion_cannot_attack_master(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 106)
	var p0_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_card,
		"row": "back",
		"col": 0
	})).ok, "back-row master attack test should deploy the attacker", failures)
	_advance_to_next_main(engine, state, failures, "back-row master attack test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "back-row master attack test should advance back to player 1 main")
	var attacker_id = state.players[0].battle_back[0].occupant
	var legal_targets = engine.get_legal_attack_targets(state, attacker_id)
	_expect(not _has_attack_target_kind(legal_targets, "master"), "back-row legion should not be able to attack master", failures)

static func _test_formal_morale_faction_effect_activates_from_morale_source(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _formal_decks(), 107, [
		{"name": "P1", "master_name": "椤讳綈涔嬬敺", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "P2", "master_name": "娲涘熀", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 0,
		"opening_active_player_morale": 2,
		"opening_non_active_player_morale": 0
	})
	var morale_action := _find_activate_effect_action(engine.get_legal_actions(state, 0), "morale_0", "takamagahara_morale_draw")
	_expect(not morale_action.is_empty(), "morale area faction effect should be exposed as an activatable morale source", failures)
	var hand_before := state.get_player(0).hand.cards.size()
	var deck_before := state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "morale_0",
		"effect_id": "takamagahara_morale_draw"
	})).ok, "morale faction effect should activate from morale source", failures)
	_expect(state.get_player(0).cost_area.cards.size() == 0, "morale faction effect should consume two active morale", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 2, "morale faction effect should move paid morale to spent area", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "opponent should pass morale effect stack", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "controller should pass to resolve morale effect", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + 1, "morale faction effect should draw one card", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 1, "morale faction effect should draw from deck top", failures)
	_expect(_find_activate_effect_action(engine.get_legal_actions(state, 0), "morale_0", "takamagahara_morale_draw").is_empty(), "morale faction effect should be once per turn", failures)


static func _test_formal_takamagahara_morale_draw_can_move_active_legion(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _formal_decks(), 1007, [
		{"name": "P1", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "P2", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 1,
		"opening_active_player_morale": 3,
		"opening_non_active_player_morale": 0,
		"turn_start_draw_count": 0
	})
	var opening_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": opening_card,
		"row": "front",
		"col": 1
	})).ok, "takamagahara morale move test should deploy an active legion before using the morale effect", failures)
	var legion_id = state.players[0].battle_front[1].occupant
	_expect(legion_id != "", "takamagahara morale move test should place the legion onto the battlefield", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "morale_0",
		"effect_id": "takamagahara_morale_draw"
	})).ok, "takamagahara morale move test should activate the morale effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "takamagahara morale move test first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "takamagahara morale move test second pass should resolve into a temporary drag move window", failures)
	_expect(state.pending_choices.is_empty(), "takamagahara morale move test should not open a popup choice after drawing", failures)
	var move_targets = engine.get_legal_move_targets(state, legion_id)
	_expect(_has_move_target(move_targets, "back", 1), "takamagahara morale move test should expose a one-step drag move target", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": legion_id,
		"row": "back",
		"col": 1
	})).ok, "takamagahara morale move test should let the player use the granted move directly", failures)
	_expect(state.players[0].battle_front[1].occupant == "", "takamagahara morale move test should clear the original slot", failures)
	_expect(state.players[0].battle_back[1].occupant == legion_id, "takamagahara morale move test should move the chosen active legion by one step", failures)

static func _test_formal_move_legion_consumes_morale(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _formal_decks(), 102, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var opening_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": opening_card,
		"row": "front",
		"col": 1
	})).ok, "formal move test should deploy the opening legion", failures)
	_advance_to_next_main(engine, state, failures, "formal move test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "formal move test should advance back to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("formal move test did not return to player 1 main")
		return
	var legion_id = state.players[0].battle_front[1].occupant
	_expect(legion_id != "", "formal move test should keep the legion on the front row before moving", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": legion_id,
		"row": "front",
		"col": 2
	})).ok, "formal move test should allow moving the legion horizontally by one slot", failures)
	_expect(state.players[0].battle_front[1].occupant == "", "formal move test should clear the original slot", failures)
	_expect(state.players[0].battle_front[2].occupant == legion_id, "formal move test should place the legion into the destination slot", failures)
	_expect(state.card_instances[legion_id].zone == "battle_front", "formal move test should keep the moved legion on the front row after lateral movement", failures)
	_expect(int(state.card_instances[legion_id].position.get("col", -1)) == 2, "formal move test should update the moved legion column", failures)
	_expect(state.players[0].cost_area.cards.size() == 2 and state.players[0].spent_cost_area.cards.size() == 1, "formal move test should consume exactly one morale", failures)


static func _test_formal_cavalry_manual_move_is_free_any_slot_same_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["neutral_s01_0002", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 1008, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 1,
		"opening_active_player_morale": 4,
		"opening_non_active_player_morale": 0,
		"turn_start_draw_count": 0
	})
	var cavalry_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": cavalry_card,
		"row": "front",
		"col": 0
	})).ok, "cavalry manual move test should deploy 佣兵部队 on the same turn", failures)
	var cavalry_id = state.players[0].battle_front[0].occupant
	var same_turn_targets = engine.get_legal_move_targets(state, cavalry_id)
	_expect(_has_move_target(same_turn_targets, "back", 2), "cavalry manual move test should allow same-turn movement to any own empty slot", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": cavalry_id,
		"row": "back",
		"col": 2
	})).ok, "cavalry manual move test should allow same-turn manual reposition", failures)
	_expect(state.players[0].battle_front[0].occupant == "", "cavalry manual move test should clear the original slot", failures)
	_expect(state.players[0].battle_back[2].occupant == cavalry_id, "cavalry manual move test should place cavalry into the chosen empty slot", failures)
	_expect(state.players[0].cost_area.cards.is_empty() and state.players[0].spent_cost_area.cards.size() == 4, "cavalry manual move test should not spend extra morale after deployment", failures)
	_expect(engine.get_legal_move_targets(state, cavalry_id).is_empty(), "cavalry manual move test should only allow one move per turn", failures)


static func _test_formal_hiromasa_attack_draw_requests_optional_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0413",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha"
		],
		[
			"neutral_s01_0016",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta"
		]
	], 108, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "formal hiromasa test should add morale for deployment", failures)
	var hiromasa_card_id := _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	_expect(not hiromasa_card_id.is_empty(), "formal hiromasa test should draw source card", failures)
	if hiromasa_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hiromasa_card_id,
		"row": "front",
		"col": 0
	})).ok, "formal hiromasa test should deploy source card", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "formal hiromasa enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "formal hiromasa enter trigger second pass should resolve", failures)
	_expect(state.pending_choices.size() == 1, "formal hiromasa enter trigger should request an optional draw choice", failures)
	if state.pending_choices.is_empty():
		return
	var enter_choice = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(enter_choice.get("choice_id", "")),
		"selected_option": "no"
	})).ok, "formal hiromasa enter optional draw choice should resolve", failures)
	_advance_to_next_main(engine, state, failures, "formal hiromasa test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "formal hiromasa test should advance back to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("formal hiromasa test did not return to player 1 main")
		return
	var hiromasa_id: String = str(state.players[0].battle_front[0].occupant)
	_expect(not hiromasa_id.is_empty(), "formal hiromasa test should keep 婧愬崥闆?on battlefield", failures)
	if hiromasa_id.is_empty():
		return
	var hand_before_attack: int = state.players[0].hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hiromasa_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "formal hiromasa test should declare attack", failures)
	_expect(state.stack.size() == 1, "formal hiromasa attack should promote one trigger onto the stack first", failures)
	_expect(state.pending_triggers.is_empty(), "formal hiromasa attack should only queue the attack trigger defined in the current card data", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "formal hiromasa attack first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "formal hiromasa attack second pass should resolve the top trigger", failures)
	_expect(state.pending_choices.is_empty(), "formal hiromasa attack should not request an optional draw choice under the current card definition", failures)
	_expect(state.players[0].hand.cards.size() == hand_before_attack, "formal hiromasa attack should not draw cards during attack resolution", failures)


static func _test_formal_komatsu_requires_target_choice_on_play_and_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0416",
			"takamagahara_s01_0410",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha"
		],
		[
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta"
		]
	], 109, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "formal komatsu test should add morale for two deployments", failures)
	var ally_card_id := _find_hand_card_by_definition(state, 0, "takamagahara_s01_0410")
	var komatsu_card_id := _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	_expect(not ally_card_id.is_empty() and not komatsu_card_id.is_empty(), "formal komatsu test should draw ally target and 绋诲К鏈灏忔澗", failures)
	if ally_card_id.is_empty() or komatsu_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_card_id,
		"row": "front",
		"col": 1
	})).ok, "formal komatsu test should deploy the allied target first", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": komatsu_card_id,
		"row": "front",
		"col": 0
	})).ok, "formal komatsu test should deploy 绋诲К鏈灏忔澗", failures)
	var ally_instance_id: String = str(state.players[0].battle_front[1].occupant)
	var komatsu_instance_id: String = str(state.players[0].battle_front[0].occupant)
	_expect(engine.get_card_power(state, ally_instance_id) == 2000, "formal komatsu ally should start at base power", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "formal komatsu enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "formal komatsu enter trigger second pass should resolve into target choice", failures)
	_expect(state.pending_choices.size() == 1, "formal komatsu enter trigger should request one target choice", failures)
	if state.pending_choices.is_empty():
		return
	var enter_choice = state.pending_choices[0]
	_expect(str(enter_choice.get("type", "")) == "candidate_cards_pick", "formal komatsu enter trigger should use candidate_cards_pick", failures)
	_expect(str(enter_choice.get("operation", "")) == "modify_power_until_turn_end", "formal komatsu enter trigger should expose a power target choice", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(enter_choice.get("choice_id", "")),
		"selected_card_ids": [ally_instance_id]
	})).ok, "formal komatsu enter target choice should resolve", failures)
	_expect(engine.get_card_power(state, ally_instance_id) == 3000, "formal komatsu enter trigger should buff the chosen ally by 1000", failures)
	_advance_to_next_main(engine, state, failures, "formal komatsu test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "formal komatsu test should advance back to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("formal komatsu test did not return to player 1 main")
		return
	_expect(engine.get_card_power(state, ally_instance_id) == 2000, "formal komatsu enter buff should expire before the next attack turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": komatsu_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "formal komatsu test should declare attack", failures)
	_expect(state.stack.size() == 1, "formal komatsu attack should put its trigger on stack", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "formal komatsu attack trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "formal komatsu attack trigger second pass should resolve into target choice", failures)
	_expect(state.pending_choices.size() == 1, "formal komatsu attack trigger should request one target choice", failures)
	if state.pending_choices.is_empty():
		return
	var attack_choice = state.pending_choices[0]
	_expect(str(attack_choice.get("type", "")) == "candidate_cards_pick", "formal komatsu attack trigger should use candidate_cards_pick", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(attack_choice.get("choice_id", "")),
		"selected_card_ids": [ally_instance_id]
	})).ok, "formal komatsu attack target choice should resolve", failures)
	_expect(engine.get_card_power(state, ally_instance_id) == 3000, "formal komatsu attack trigger should buff the chosen ally by 1000", failures)
	_expect(engine.get_card_power(state, komatsu_instance_id) == 1000, "formal komatsu should still not buff itself", failures)
	_expect(_has_event_type(state, "ChoiceRequested"), "formal komatsu trigger chain should log ChoiceRequested", failures)
	_expect(_has_event_type(state, "ChoiceResolved"), "formal komatsu trigger chain should log ChoiceResolved", failures)


static func _test_formal_kusanagi_enter_requires_destroy_target_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha",
			"dev_legion_alpha"
		],
		[
			"dev_legion_beta",
			"asgard_s01_0312",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta"
		]
	], 110, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	_advance_to_next_main(engine, state, failures, "formal kusanagi test should advance to player 2 main for target setup")
	if state.active_player != 1 or state.phase != "main":
		failures.append("formal kusanagi test did not reach player 2 main for target setup")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 4
	})).ok, "formal kusanagi test should add morale for enemy target deployment", failures)
	var low_cost_target_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	var high_cost_target_id := _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	_expect(not low_cost_target_id.is_empty() and not high_cost_target_id.is_empty(), "formal kusanagi test should draw both low and high cost enemy targets", failures)
	if low_cost_target_id.is_empty() or high_cost_target_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": low_cost_target_id,
		"row": "front",
		"col": 0
	})).ok, "formal kusanagi test should deploy the low-cost enemy target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": high_cost_target_id,
		"row": "front",
		"col": 1
	})).ok, "formal kusanagi test should deploy the high-cost enemy target", failures)
	var low_cost_target_instance_id: String = str(state.get_player(1).battle_front[0].occupant)
	var high_cost_target_instance_id: String = str(state.get_player(1).battle_front[1].occupant)
	_advance_to_next_main(engine, state, failures, "formal kusanagi test should advance back to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("formal kusanagi test did not return to player 1 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "formal kusanagi test should add morale for artifact play", failures)
	var kusanagi_card_id := _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(not kusanagi_card_id.is_empty(), "formal kusanagi test should draw artifact", failures)
	if kusanagi_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kusanagi_card_id,
		"row": "artifact",
		"col": -1
	})).ok, "formal kusanagi test should play 鑽夎枡鍓?to artifact zone", failures)
	_expect(state.pending_choices.size() == 1, "formal kusanagi enter trigger should request one destroy target choice", failures)
	if state.pending_choices.is_empty():
		return
	var destroy_choice = state.pending_choices[0]
	_expect(str(destroy_choice.get("type", "")) == "candidate_cards_pick", "formal kusanagi enter trigger should use candidate_cards_pick", failures)
	_expect(str(destroy_choice.get("operation", "")) == "target_then_stack_effect", "formal kusanagi enter trigger should require target before stack response", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(destroy_choice.get("choice_id", "")),
		"selected_card_ids": [low_cost_target_instance_id]
	})).ok, "formal kusanagi destroy target choice should resolve", failures)
	_expect(state.stack.size() == 1, "formal kusanagi target choice should put effect on stack after target is selected", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "formal kusanagi enter trigger first response pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "formal kusanagi enter trigger second response pass should resolve", failures)
	_expect(state.get_player(1).grave.cards.has(low_cost_target_instance_id), "formal kusanagi should send the chosen low-cost target to grave", failures)
	_expect(not state.get_player(1).grave.cards.has(high_cost_target_instance_id), "formal kusanagi should not destroy the unchosen high-cost target", failures)
	_expect(state.get_player(0).artifact_zone.cards.has(kusanagi_card_id), "formal kusanagi should remain in artifact zone after resolving enter trigger", failures)
	_expect(_has_event_type(state, "ChoiceRequested"), "formal kusanagi enter trigger should log ChoiceRequested", failures)
	_expect(_has_event_type(state, "ChoiceResolved"), "formal kusanagi enter trigger should log ChoiceResolved", failures)

static func _test_formal_counter_tactic_sets_on_battlefield_and_responds(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_counter_tactic_nullify", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "qa_blank"],
		["dev_tactic_rally", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "qa_blank"]
	], 111, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 1,
		"opening_non_active_player_morale": 0
	})
	var counter_card_id := _find_hand_card_by_definition(state, 0, "dev_counter_tactic_nullify")
	_expect(counter_card_id != "", "formal set counter test should draw counter tactic", failures)
	if counter_card_id.is_empty():
		return
	var slots = engine.get_legal_play_slots(state, 0, counter_card_id)
	_expect(slots.size() == 3, "formal counter tactic should expose only the three back-row slots", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_card_id,
		"row": "back",
		"col": 2
	})).ok, "formal counter tactic should be set onto a battlefield slot", failures)
	_expect(state.get_player(0).battle_back[2].occupant == counter_card_id, "set counter tactic should occupy the chosen slot", failures)
	_expect(str(state.card_instances[counter_card_id].face) == "face_down", "set counter tactic should be face down", failures)
	_advance_to_next_main(engine, state, failures, "formal set counter test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("formal set counter test did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "formal set counter test should add morale for tactic", failures)
	var tactic_id := _find_hand_card_by_definition(state, 1, "dev_tactic_rally")
	_expect(tactic_id != "", "formal set counter test should draw enemy tactic", failures)
	if tactic_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "rally_draw"
	})).ok, "formal set counter test should put enemy tactic on stack", failures)
	var counter_action := _find_activate_effect_action(engine.get_legal_actions(state, 0), counter_card_id, "nullify_stack")
	_expect(not counter_action.is_empty(), "set counter tactic should be activatable from its battlefield slot during response", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": counter_card_id,
		"effect_id": "nullify_stack",
		"target_stack_id": str(state.stack[0].get("stack_id", ""))
	})).ok, "set counter tactic should reveal and target the enemy stack item", failures)
	_expect(state.get_player(0).battle_back[2].occupant == "", "revealed counter tactic should leave its battlefield slot", failures)
	_expect(str(state.card_instances[counter_card_id].zone) == "stack_pending", "revealed counter tactic should move to stack_pending", failures)
	_expect(str(state.card_instances[counter_card_id].face) == "face_up", "revealed counter tactic should turn face up", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "formal set counter test first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "formal set counter test second pass should resolve counter", failures)
	_expect(state.get_player(0).grave.cards.has(counter_card_id), "resolved set counter tactic should go to grave", failures)
	_expect(state.get_player(1).grave.cards.has(tactic_id), "countered enemy tactic should go to grave", failures)

static func _test_choose_defense_rejects_generic_hand_blocker(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 103)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": state.players[0].hand.cards[0],
		"row": "front",
		"col": 0
	})).ok, "choose defense test should deploy player 1 attacker target", failures)
	_advance_to_next_main(engine, state, failures, "choose defense test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("choose defense test did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": state.players[1].hand.cards[0],
		"row": "front",
		"col": 0
	})).ok, "choose defense test should deploy player 2 attacker", failures)
	_advance_to_next_main(engine, state, failures, "choose defense test should advance to player 1 main before attacker can act")
	_advance_to_next_main(engine, state, failures, "choose defense test should advance back to player 2 main before attacker can act")
	if state.active_player != 1 or state.phase != "main":
		failures.append("choose defense test did not return to player 2 main for attack")
		return
	var attacker_id = state.players[1].battle_front[0].occupant
	var defender_id = state.players[0].battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	})).ok, "choose defense test should declare attack successfully", failures)
	var blocker_id = state.players[0].hand.cards[0]
	var choose_defense_result = engine.apply_command(state, GameCommand.create(0, "ChooseDefense", {
		"blocker_id": blocker_id
	}))
	_expect(not choose_defense_result.ok and str(choose_defense_result.get("code", "")) == "NO_DEFENSE_OPTIONS", "choose defense test should reject generic hand blockers against unit attacks", failures)
	_expect(not state.pending_attack.is_empty(), "choose defense test should leave the pending attack open after rejecting a generic hand blocker", failures)
	_expect(not state.players[0].grave.cards.has(blocker_id), "choose defense test should not move a rejected blocker to grave", failures)

static func _test_master_guard_prevents_master_damage(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 104)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": state.players[0].hand.cards[0],
		"row": "front",
		"col": 1
	})).ok, "master guard test should deploy player 1 unit", failures)
	_advance_to_next_main(engine, state, failures, "master guard test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("master guard test did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": state.players[1].hand.cards[0],
		"row": "front",
		"col": 0
	})).ok, "master guard test should deploy player 2 attacker", failures)
	_advance_to_next_main(engine, state, failures, "master guard test should advance to player 1 main before attacker can act")
	_advance_to_next_main(engine, state, failures, "master guard test should advance back to player 2 main before attacker can act")
	if state.active_player != 1 or state.phase != "main":
		failures.append("master guard test did not return to player 2 main for attack")
		return
	var attacker_id = state.players[1].battle_front[0].occupant
	var master_hp_before = state.players[0].master_hp
	var actions_before = engine.get_legal_actions(state, 1)
	_expect(_has_command_type(actions_before, "DeclareAttack"), "master guard test attacker should have an attack command", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "master",
		"target_player": 0
	})).ok, "master guard test should declare attack on the opposing master", failures)
	var defense_actions = engine.get_legal_actions(state, 0)
	var guard_action := {}
	for action in defense_actions:
		if str(action.get("kind", "")) == "choose_defense" and str(action.get("source", {}).get("defense_kind", "")) == "master_guard":
			guard_action = action
			break
	_expect(not guard_action.is_empty(), "master guard test should expose a master guard defense action", failures)
	if guard_action.is_empty():
		return
	var guard_cards = guard_action.get("payload_template", {}).get("master_guard_card_ids", [])
	_expect(engine.apply_command(state, GameCommand.create(0, "ChooseDefense", {
		"master_guard_card_ids": guard_cards
	})).ok, "master guard test should allow discarding the selected hand cards to guard the master", failures)
	_expect(not state.pending_attack.is_empty(), "master guard test should keep the pending attack open after selecting guard cards", failures)
	_expect(state.priority_player == 1, "master guard test should hand priority back to the attacker after selecting guard cards", failures)
	for card_id in guard_cards:
		_expect(not state.players[0].grave.cards.has(str(card_id)), "master guard test should not discard guard cards before the response window closes", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "master guard test attacker pass after guard should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "master guard test defender pass after guard should resolve the attack", failures)
	_expect(state.players[0].master_hp == master_hp_before, "master guard test should prevent damage to the defending master", failures)
	for card_id in guard_cards:
		_expect(state.players[0].grave.cards.has(str(card_id)), "master guard test should move each selected guard card to grave", failures)
	_expect(_has_event_type(state, "MasterGuarded"), "master guard test should log a MasterGuarded event", failures)

static func _test_block_then_counter_pending_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _block_then_counter_decks(), 105)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "block-then-counter test should add morale for defender deployment", failures)
	var defender_card_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	var blocker_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0002")
	var counter_card_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0016")
	_expect(defender_card_id != "" and blocker_id != "" and counter_card_id != "", "block-then-counter test should draw defender, 浣ｅ叺閮ㄩ槦 and 缁濆闃插尽", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": defender_card_id,
		"row": "front",
		"col": 0
	})).ok, "block-then-counter test defender play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "block-then-counter test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("block-then-counter test did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "block-then-counter test should add morale for attacker deployment", failures)
	var attacker_card_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0404")
	_expect(attacker_card_id != "", "block-then-counter test should draw attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "block-then-counter test attacker play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "block-then-counter test should advance to player 1 main before attacker can act")
	_advance_to_next_main(engine, state, failures, "block-then-counter test should advance back to player 2 main before attacker can act")
	if state.active_player != 1 or state.phase != "main":
		failures.append("block-then-counter test did not return to player 2 main for attack")
		return
	var attacker_id = state.get_player(1).battle_front[0].occupant
	var defender_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	})).ok, "block-then-counter test should declare attack", failures)
	var response_actions = engine.get_legal_actions(state, 1)
	_expect(not _has_command_type(response_actions, "PassPriority"), "block-then-counter test should hand priority to the defending player first during the pending attack window", failures)
	var defender_actions = engine.get_legal_actions(state, 0)
	var counter_action := {}
	for action in defender_actions:
		if str(action.get("kind", "")) == "play_card" and str(action.get("play_kind", "")) == "counter_tactic":
			counter_action = action
			break
	_expect(not counter_action.is_empty(), "block-then-counter test defender should still have 缁濆闃插尽 during the pending attack window", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_card_id,
		"row": "counter_tactic",
		"col": -1,
		"effect_id": "absolute_defense",
		"target_stack_id": "__pending_attack__"
	})).ok, "block-then-counter test should allow 缁濆闃插尽 to target the pending attack after blocker selection", failures)
	_expect(not state.pending_attack.is_empty(), "block-then-counter test should keep pending attack until the counter effect resolves", failures)
	_expect(state.stack.size() == 1, "block-then-counter test should put 缁濆闃插尽 onto the stack", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "block-then-counter test first pass on counter stack should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "block-then-counter test second pass on counter stack should resolve the counter", failures)
	_expect(state.pending_attack.is_empty(), "block-then-counter test should clear the pending attack after 缁濆闃插尽 resolves", failures)
	_expect(state.stack.is_empty(), "block-then-counter test should clear the stack after 缁濆闃插尽 resolves", failures)
	_expect(state.players[0].grave.cards.has(counter_card_id), "block-then-counter test should send 缁濆闃插尽 to grave after resolving", failures)
	_expect(state.card_instances[attacker_id].orientation == "rested", "block-then-counter test should still rest the attacker after the countered attack", failures)
	_expect(_has_event_type(state, "AttackCountered"), "block-then-counter test should log AttackCountered", failures)

static func _test_master_guard_then_counter_pending_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _pending_attack_counter_decks(), 106, [
		{"name": "闃挎柉鍔犲痉", "master_name": "濂ヤ竵", "master_id": "asgard_s01_03m1", "master_hp": 12, "master_max_hp": 12},
		{"name": "Takamagahara", "master_name": "Susanoo", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	])
	_advance_to_next_main(engine, state, failures, "master-guard-then-counter test should advance to player 2 main for attacker deployment")
	if state.active_player != 1 or state.phase != "main":
		failures.append("master-guard-then-counter test did not reach player 2 main for attacker deployment")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "master-guard-then-counter test should add morale for attacker deployment", failures)
	var attacker_card_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0404")
	var counter_card_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0016")
	_expect(attacker_card_id != "" and counter_card_id != "", "master-guard-then-counter test should draw attacker and 缁濆闃插尽", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "master-guard-then-counter test attacker play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "master-guard-then-counter test should advance to player 1 main before attacker can act")
	_advance_to_next_main(engine, state, failures, "master-guard-then-counter test should advance back to player 2 main before attacker can act")
	if state.active_player != 1 or state.phase != "main":
		failures.append("master-guard-then-counter test did not return to player 2 main for attack")
		return
	var attacker_id = state.get_player(1).battle_front[0].occupant
	var master_hp_before = state.get_player(0).master_hp
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "master",
		"target_player": 0
	})).ok, "master-guard-then-counter test should declare an attack on the defending master", failures)
	var guard_action := {}
	for action in engine.get_legal_actions(state, 0):
		if str(action.get("kind", "")) == "choose_defense" and str(action.get("source", {}).get("defense_kind", "")) == "master_guard":
			guard_action = action
			break
	_expect(not guard_action.is_empty(), "master-guard-then-counter test should expose a master guard defense action", failures)
	if guard_action.is_empty():
		return
	var guard_cards = guard_action.get("payload_template", {}).get("master_guard_card_ids", [])
	_expect(engine.apply_command(state, GameCommand.create(0, "ChooseDefense", {
		"master_guard_card_ids": guard_cards
	})).ok, "master-guard-then-counter test should allow selecting guard cards first", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "master-guard-then-counter test attacker should be able to pass priority before the counter", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_card_id,
		"row": "counter_tactic",
		"col": -1,
		"effect_id": "absolute_defense",
		"target_stack_id": "__pending_attack__"
	})).ok, "master-guard-then-counter test should allow 缁濆闃插尽 after guard selection", failures)
	_expect(not state.pending_attack.is_empty(), "master-guard-then-counter test should keep pending attack until the counter resolves", failures)
	_expect(state.stack.size() == 1, "master-guard-then-counter test should put 缁濆闃插尽 onto the stack", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "master-guard-then-counter test first pass on counter stack should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "master-guard-then-counter test second pass on counter stack should resolve the counter", failures)
	_expect(state.pending_attack.is_empty(), "master-guard-then-counter test should clear the pending attack after 缁濆闃插尽 resolves", failures)
	_expect(state.players[0].master_hp == master_hp_before, "master-guard-then-counter test should keep the defending master unharmed", failures)
	for card_id in guard_cards:
		_expect(not state.players[0].grave.cards.has(str(card_id)), "master-guard-then-counter test should not discard guard cards once the attack is countered", failures)
	_expect(state.players[0].grave.cards.has(counter_card_id), "master-guard-then-counter test should send 缁濆闃插尽 to grave after resolving", failures)
	_expect(_has_event_type(state, "AttackCountered"), "master-guard-then-counter test should log AttackCountered", failures)

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

static func _drain_stack_and_choices(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(16):
		if state.pending_choices.is_empty() and state.stack.is_empty() and state.pending_attack.is_empty():
			return
		if not state.pending_choices.is_empty():
			var choice = state.pending_choices[0]
			var payload = {"choice_id": str(choice.get("choice_id", ""))}
			match str(choice.get("type", "")):
				"candidate_cards_pick":
					var selected: Array[String] = []
					var candidates = choice.get("candidate_card_ids", [])
					var count = int(choice.get("count", 1))
					for raw_card_id in candidates:
						selected.append(str(raw_card_id))
						if selected.size() == count:
							break
					payload["selected_card_ids"] = selected
				"option_pick":
					var options = choice.get("options", [])
					if options is Array and not options.is_empty():
						payload["selected_option"] = str(options[0].get("id", ""))
			_expect(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", -1)), "ResolveChoice", payload)).ok, message, failures)
			continue
		_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
	failures.append(message)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _formal_decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _unique_opening_definitions() -> Array:
	var definitions := CardDatabase.load_definitions()
	for prefix in ["qa_top_p0_", "qa_top_p1_"]:
		for index in range(12):
			definitions.append({
				"id": "%s%02d" % [prefix, index],
				"name": "%s%02d" % [prefix, index],
				"faction": "neutral",
				"type": "legion",
				"cost": 1,
				"power": 1000 + index,
				"hp": 1000 + index,
				"keywords": [],
				"effects": [],
				"text": "top draw verification card"
			})
	return definitions

static func _unique_opening_decks() -> Array:
	var player_0: Array[String] = []
	var player_1: Array[String] = []
	for index in range(12):
		player_0.append("qa_top_p0_%02d" % index)
		player_1.append("qa_top_p1_%02d" % index)
	return [player_0, player_1]

static func _pending_attack_counter_decks() -> Array:
	return [
		["asgard_s01_0312", "neutral_s01_0016", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["takamagahara_s01_0404", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _block_then_counter_decks() -> Array:
	return [
		["asgard_s01_0312", "neutral_s01_0002", "neutral_s01_0016", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["takamagahara_s01_0404", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.players[player_id].hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

static func _definition_ids_for_cards(state, card_ids: Array, start_index: int = 0, count: int = -1) -> Array[String]:
	var result: Array[String] = []
	var end_index := card_ids.size()
	if count >= 0:
		end_index = min(end_index, start_index + count)
	for index in range(start_index, end_index):
		var instance = state.card_instances.get(str(card_ids[index]))
		if instance != null:
			result.append(str(instance.definition_id))
	return result

static func _same_string_arrays(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if left[index] != right[index]:
			return false
	return true

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

static func _has_command_type(actions: Array[Dictionary], command_type: String) -> bool:
	for action in actions:
		if str(action.get("command_type", "")) == command_type:
			return true
	return false

static func _has_attack_target_kind(targets: Array, target_kind: String) -> bool:
	for target in targets:
		if str(target.get("target_kind", "")) == target_kind:
			return true
	return false


static func _has_move_target(targets: Array, row: String, col: int) -> bool:
	for target in targets:
		if str(target.get("row", "")) == row and int(target.get("col", -1)) == col:
			return true
	return false

static func _find_activate_effect_action(actions: Array, source_id: String, effect_id: String) -> Dictionary:
	for action in actions:
		if not (action is Dictionary):
			continue
		if str(action.get("kind", "")) != "activate_effect":
			continue
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("source_id", "")) == source_id and str(payload.get("effect_id", "")) == effect_id:
			return action
	return {}

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false
