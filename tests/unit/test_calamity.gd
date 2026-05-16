extends RefCounted
class_name TestCalamity

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_end_phase_increases_calamity(failures)
	_test_eight_does_not_reveal_yet(failures)
	_test_threshold_reveals_and_resets(failures)
	_test_threshold_reveal_happens_after_turn_passes_into_calamity(failures)
	_test_end_phase_increment_to_threshold_reveals_after_turn_pass(failures)
	_test_formal_legion_entry_can_trigger_calamity(failures)
	_test_effect_hand_deploy_adds_calamity(failures)
	_test_grave_revive_adds_calamity(failures)
	_test_bjorn_rested_revive_adds_calamity(failures)
	_test_manifest_entry_adds_calamity(failures)
	_test_continuous_calamity_blocks_back_row(failures)
	_test_silence_calamity_allows_back_row_counter_tactic_for_free(failures)
	_test_silence_calamity_preserves_set_counter_tactics(failures)
	_test_thunder_wrath_reveal_rolls_and_returns_lowest_legion(failures)
	_test_thunder_wrath_attack_roll_can_fail(failures)
	_test_thunder_wrath_attack_roll_can_succeed(failures)
	_test_thunder_wrath_invalid_target_still_consumes_attack(failures)
	_test_thunder_wrath_pending_attack_fallback_rolls(failures)
	_test_fallen_morning_star_even_roll_rests_one_morale(failures)
	_test_fallen_morning_star_free_tactic_option_waives_play_cost(failures)
	_test_fallen_morning_star_backline_troop_type_option_allows_master_attack(failures)
	_test_magic_dragon_reveal_clears_column_and_recycles_graves(failures)
	_test_world_upheaval_reverses_decks_face_up_and_blocks_same_top_troop_type(failures)
	_test_storm_chaos_returns_back_row_and_disables_ranged(failures)
	_test_sleepless_night_clears_low_power_and_punishes_active_rest(failures)
	_test_calamity_destruction_ignores_prevention_and_died_triggers(failures)
	_test_calamity_return_to_hand_suppresses_leave_triggers(failures)
	_test_false_grail_punishes_artifact_effects(failures)
	_test_false_grail_punishes_rested_artifact_effects(failures)
	_test_hundred_demons_bonus_damage_and_end_phase_hand_limit(failures)
	_test_divine_balance_equalizes_hp_and_rewards_changed_players(failures)
	_test_divine_balance_draws_all_players_when_hp_is_already_equal(failures)
	_test_apocalypse_clears_to_two_and_reorders_all_hands(failures)
	_test_apocalypse_in_calamity_phase_finishes_into_ready(failures)
	_test_ragnarok_opening_trigger_clears_board_and_draws_all(failures)
	_test_ragnarok_preserves_set_counter_tactics(failures)
	_test_ragnarok_active_trigger_grants_extra_turn(failures)
	_test_fog_desperation_discards_down_to_five_and_restricts_attacks(failures)
	_test_pride_sin_battlefield_choice_and_master_cost(failures)
	_test_pride_sin_hand_choice_and_hand_legion_cost(failures)
	_test_new_calamity_clears_previous_continuous_effect(failures)
	_test_final_calamity_locks_value(failures)
	_test_formal_random_calamity_deck_ends_with_annihilation(failures)
	return failures

static func _test_end_phase_increases_calamity(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 700)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "ending main phase should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "ending end phase should succeed", failures)
	_expect(state.calamity_value == 1, "end phase should increase calamity value by 1", failures)


static func _test_eight_does_not_reveal_yet(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 706)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_calamity_value",
		"value": 7
	})).ok, "debug set calamity value to 7 should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "advance to end phase at 7 calamity should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "advance into next turn at 7 calamity should succeed", failures)
	_expect(state.current_calamity == "", "value 8 should not reveal a calamity yet", failures)
	_expect(state.calamity_value == 8, "value 8 should remain lit and should not reset", failures)
	_expect(not _has_event_type(state, "CalamityRevealed"), "value 8 should not log a calamity reveal", failures)

static func _test_threshold_reveals_and_resets(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 701)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_calamity_value",
		"value": 9
	})).ok, "debug set calamity value should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "advance to end phase before calamity should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "advance into calamity phase should succeed", failures)
	_expect(state.phase == "ready", "threshold reveal should auto-advance out of calamity into ready phase", failures)
	_expect(state.current_calamity == "sys_calamity_embers", "threshold reveal should flip 暴怒之罪 first", failures)
	_expect(state.calamity_value == 0, "revealed calamity should reset calamity value to 0", failures)
	_expect(state.players[0].master_hp == 19 and state.players[1].master_hp == 19, "暴怒之罪 should deal one non-lethal damage to both masters", failures)
	_expect(_has_event_type(state, "CalamityRevealed"), "calamity reveal should be logged", failures)
	_expect(_has_event_type(state, "CalamityResolved"), "calamity resolution should be logged", failures)

static func _test_threshold_reveal_happens_after_turn_passes_into_calamity(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 795)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_calamity_value",
		"value": 9
	})).ok, "debug set calamity value to 9 should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "advance to end phase before turn pass should succeed", failures)
	var pass_turn_result = engine.apply_command(state, GameCommand.create(0, "EndPhase"))
	_expect(pass_turn_result.ok, "advance into next turn calamity step should succeed", failures)
	var phase_to_calamity_index := -1
	var reveal_index := -1
	var result_events: Array = pass_turn_result.get("events", [])
	for index in range(result_events.size()):
		var event = result_events[index]
		if event == null:
			continue
		if str(event.type) == "PhaseChanged" and event.payload is Dictionary and str(event.payload.get("to", "")) == "calamity":
			phase_to_calamity_index = index
		elif str(event.type) == "CalamityRevealed" and reveal_index == -1:
			reveal_index = index
	_expect(phase_to_calamity_index >= 0, "threshold reveal should first enter calamity phase on the next turn", failures)
	_expect(reveal_index > phase_to_calamity_index, "threshold reveal should happen after entering calamity on the next turn", failures)
	_expect(state.active_player == 1, "threshold reveal should occur on opponent turn start after turn passes", failures)

static func _test_end_phase_increment_to_threshold_reveals_after_turn_pass(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 798)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_calamity_value",
		"value": 8
	})).ok, "debug set calamity value to 8 should succeed", failures)
	var to_end_result = engine.apply_command(state, GameCommand.create(0, "EndPhase"))
	_expect(to_end_result.ok, "advance from main into end phase at 8 calamity should succeed", failures)
	_expect(state.phase == "end", "value 8 should not reveal while merely entering end phase", failures)
	_expect(state.active_player == 0, "active player should remain unchanged before the turn is passed", failures)
	var reveal_during_to_end := false
	for event in to_end_result.get("events", []):
		if event != null and str(event.type) == "CalamityRevealed":
			reveal_during_to_end = true
			break
	_expect(not reveal_during_to_end, "value 8 should not reveal before the end phase pass increments it to 9", failures)
	var pass_turn_result = engine.apply_command(state, GameCommand.create(0, "EndPhase"))
	_expect(pass_turn_result.ok, "advance out of end phase at 8 calamity should succeed", failures)
	var phase_to_calamity_index := -1
	var reveal_index := -1
	var increment_to_nine_index := -1
	var result_events: Array = pass_turn_result.get("events", [])
	for index in range(result_events.size()):
		var event = result_events[index]
		if event == null:
			continue
		if str(event.type) == "CalamityValueChanged" and event.payload is Dictionary and int(event.payload.get("value", -1)) == 9 and increment_to_nine_index == -1:
			increment_to_nine_index = index
		elif str(event.type) == "PhaseChanged" and event.payload is Dictionary and str(event.payload.get("to", "")) == "calamity":
			phase_to_calamity_index = index
		elif str(event.type) == "CalamityRevealed" and reveal_index == -1:
			reveal_index = index
	_expect(increment_to_nine_index >= 0, "end-phase pass should first increment calamity from 8 to 9", failures)
	_expect(phase_to_calamity_index > increment_to_nine_index, "end-phase threshold reveal should pass the turn before entering calamity", failures)
	_expect(reveal_index > phase_to_calamity_index, "end-phase threshold reveal should happen only after entering next-turn calamity", failures)
	_expect(state.active_player == 1, "end-phase threshold reveal should happen on the opponent turn after passing turn", failures)

static func _test_formal_legion_entry_can_trigger_calamity(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_calamity_legion",
		"name": "天灾先锋",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"calamity_level": 2,
		"keywords": [],
		"effects": [],
		"text": "登场时用于测试天灾值推进"
	})
	var state = engine.create_game(definitions, [
		["qa_calamity_legion", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 705, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_calamity_value",
		"value": 7
	})).ok, "formal calamity test should seed calamity value to 7", failures)
	var card_id = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": card_id,
		"row": "front",
		"col": 0
	})).ok, "formal legion entry should succeed", failures)
	_expect(state.current_calamity == "sys_calamity_embers", "formal legion entry over threshold should reveal 暴怒之罪 immediately", failures)
	_expect(state.calamity_value == 0, "immediate calamity reveal should reset calamity value to 0", failures)
	_expect(state.players[0].master_hp == 19 and state.players[1].master_hp == 19, "immediate 暴怒之罪 reveal should resolve its non-lethal damage", failures)
	_expect(_has_event_type(state, "CalamityRevealed"), "formal legion entry should log calamity reveal", failures)
	_expect(_has_event_type(state, "CalamityResolved"), "formal legion entry should log calamity resolution", failures)

static func _test_effect_hand_deploy_adds_calamity(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 707, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var card_id = state.players[0].hand.cards[0]
	var instance = state.card_instances.get(card_id)
	_expect(instance != null, "effect deploy calamity test should have a legion in hand", failures)
	if instance == null:
		return
	instance.definition_id = "asgard_s01_0303"
	state.calamity_value = 1
	var events = engine._deploy_hand_card_to_slot(state, 0, card_id, "front", 0, "test_effect_hand_deploy_adds_calamity")
	_expect(events.size() >= 3, "effect deploy calamity test should emit entry plus calamity events", failures)
	_expect(state.calamity_value == 3, "effect deploy should add the deployed legion calamity level", failures)
	_expect(_has_event_type(state, "CalamityValueChanged"), "effect deploy should log CalamityValueChanged", failures)

static func _test_grave_revive_adds_calamity(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 708, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var card_id = state.players[0].hand.cards[0]
	var instance = state.card_instances.get(card_id)
	_expect(instance != null, "grave revive calamity test should have a legion to seed into grave", failures)
	if instance == null:
		return
	instance.definition_id = "takamagahara_s01_0401"
	state.players[0].hand.remove_card(card_id)
	state.players[0].grave.add_card_to_top(card_id)
	instance.zone = "grave"
	instance.position = {}
	state.calamity_value = 2
	var events = engine._revive_grave_card_to_slot(state, 0, card_id, "front", 0, "test_grave_revive_adds_calamity")
	_expect(events.size() >= 3, "grave revive calamity test should emit revive plus calamity events", failures)
	_expect(state.calamity_value == 5, "grave revive should add the revived legion calamity level", failures)
	_expect(_count_event_type(state, "CalamityValueChanged") >= 1, "grave revive should log CalamityValueChanged", failures)

static func _test_bjorn_rested_revive_adds_calamity(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 709, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var card_id = state.players[0].hand.cards[0]
	var instance = state.card_instances.get(card_id)
	_expect(instance != null, "Bjorn revive calamity test should have a legion to seed into grave", failures)
	if instance == null:
		return
	instance.definition_id = "asgard_s01_0305"
	state.players[0].hand.remove_card(card_id)
	state.players[0].grave.add_card_to_top(card_id)
	instance.zone = "grave"
	instance.position = {}
	state.calamity_value = 4
	var events = engine._revive_bjorn_source_rested(state, 0, card_id, "test_bjorn_rested_revive_adds_calamity")
	_expect(events.size() >= 3, "Bjorn revive calamity test should emit revive plus calamity events", failures)
	_expect(state.calamity_value == 5, "Bjorn rested revive should add the revived legion calamity level", failures)
	_expect(_count_event_type(state, "CalamityValueChanged") >= 1, "Bjorn rested revive should log CalamityValueChanged", failures)

static func _test_manifest_entry_adds_calamity(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_manifest_legion",
		"name": "显现测试军团",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"calamity_level": 2,
		"keywords": [],
		"effects": [],
		"text": "显现时用于测试天灾值推进"
	})
	var state = engine.create_game(definitions, [
		["qa_manifest_legion", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 710, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var card_id = state.players[0].hand.cards[0]
	var instance = state.card_instances.get(card_id)
	_expect(instance != null, "manifest calamity test should have a legion available", failures)
	if instance == null:
		return
	state.players[0].hand.remove_card(card_id)
	state.players[0].artifact_zone.add_card(card_id)
	instance.zone = "artifact_zone"
	instance.position = {}
	state.calamity_value = 6
	var events = engine._manifest_kusanagi_to_slot(state, 0, card_id, "front", 0, "test_manifest_entry_adds_calamity")
	_expect(events.size() >= 2, "manifest calamity test should emit manifest plus calamity events", failures)
	_expect(state.calamity_value == 8, "manifest entry should add the manifested legion calamity level", failures)
	_expect(_count_event_type(state, "CalamityValueChanged") >= 1, "manifest entry should log CalamityValueChanged", failures)

static func _test_continuous_calamity_blocks_back_row(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 702)
	engine._deploy_hand_card_to_slot(state, 0, state.players[0].hand.cards[0], "back", 0, "test_calamity_back_row_p0")
	engine._deploy_hand_card_to_slot(state, 1, state.players[1].hand.cards[0], "back", 0, "test_calamity_back_row_p1")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "sys_calamity_silence"
	})).ok, "debug reveal continuous calamity should succeed", failures)
	_expect(state.get_player(0).battle_back[0].occupant == "" and state.get_player(1).battle_back[0].occupant == "", "腐秽大地 trigger should clear all back-row legions", failures)
	var card_id = state.players[0].hand.cards[0]
	var slots = engine.get_legal_play_slots(state, 0, card_id)
	_expect(slots.size() == 3, "continuous calamity should leave only front-row slots legal", failures)
	for slot in slots:
		_expect(str(slot.get("row", "")) == "front", "continuous calamity should block all back-row placements", failures)
	var play_back = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": card_id,
		"row": "back",
		"col": 0
	}))
	_expect(not play_back.ok and str(play_back.get("code", "")) == "BACK_ROW_BLOCKED", "continuous calamity should reject back-row deployment", failures)

static func _test_silence_calamity_allows_back_row_counter_tactic_for_free(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_counter_tactic_nullify", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 792, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 0,
		"opening_non_active_player_morale": 0
	})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "sys_calamity_silence"
	})).ok, "silence calamity counter test should reveal 腐秽大地", failures)
	var counter_card_id := _find_hand_card_by_definition(state, 0, "dev_counter_tactic_nullify")
	_expect(counter_card_id != "", "silence calamity counter test should draw a counter tactic", failures)
	if counter_card_id.is_empty():
		return
	var slots = engine.get_legal_play_slots(state, 0, counter_card_id)
	var has_back_slot := false
	for slot in slots:
		if str(slot.get("row", "")) == "back":
			has_back_slot = true
	_expect(has_back_slot, "腐秽大地 should still allow back-row counter tactic set slots", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_card_id,
		"row": "back",
		"col": 1
	})).ok, "腐秽大地 should allow setting a counter tactic to back row", failures)
	_expect(state.get_player(0).battle_back[1].occupant == counter_card_id, "腐秽大地 should place the counter tactic in back row", failures)
	_expect(state.get_player(0).cost_area.cards.is_empty() and state.get_player(0).spent_cost_area.cards.is_empty(), "腐秽大地 should make back-row counter tactic set cost 0", failures)

static func _test_silence_calamity_preserves_set_counter_tactics(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_counter_tactic_nullify", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_counter_tactic_nullify", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 793, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 0,
		"opening_non_active_player_morale": 0
	})
	var p0_counter := _find_hand_card_by_definition(state, 0, "dev_counter_tactic_nullify")
	var p1_counter := _find_hand_card_by_definition(state, 1, "dev_counter_tactic_nullify")
	_expect(p0_counter != "" and p1_counter != "", "腐秽大地 preserved-counter test should draw both counter tactics", failures)
	if p0_counter.is_empty() or p1_counter.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, p0_counter, 1, "test_silence_preserve_p0_counter").is_empty(), "腐秽大地 preserved-counter test should set player 1 counter tactic", failures)
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 1, p1_counter, 1, "test_silence_preserve_p1_counter").is_empty(), "腐秽大地 preserved-counter test should set player 2 counter tactic", failures)
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "back", 0, "test_silence_preserve_p0_legion")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "back", 0, "test_silence_preserve_p1_legion")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "sys_calamity_silence"
	})).ok, "腐秽大地 preserved-counter test should reveal successfully", failures)
	_expect(state.get_player(0).battle_back[0].occupant == "" and state.get_player(1).battle_back[0].occupant == "", "腐秽大地 should still clear back-row legions", failures)
	_expect(state.get_player(0).battle_back[1].occupant == p0_counter and state.get_player(1).battle_back[1].occupant == p1_counter, "腐秽大地 should not clear set counter tactics", failures)

static func _test_thunder_wrath_reveal_rolls_and_returns_lowest_legion(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 727, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_thunder_wrath_trigger_p0")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 0, "test_thunder_wrath_trigger_p1")
	var returned_id := state.get_player(0).battle_front[0].occupant
	state.rng.state = 1
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds04"
	})).ok, "debug reveal 雷霆天怒 should succeed", failures)
	var dice_payloads := _event_payloads(state, "DiceRolled")
	_expect(dice_payloads.size() == 2, "雷霆天怒 should roll one die for each player on reveal", failures)
	if dice_payloads.size() >= 2:
		_expect(int(dice_payloads[0].get("result", 0)) == 1 and int(dice_payloads[1].get("result", 0)) == 4, "雷霆天怒 reveal should use deterministic dice results in tests", failures)
	_expect(state.pending_choices.size() == 1, "雷霆天怒 reveal should request a return choice for the lowest roller", failures)
	if state.pending_choices.is_empty():
		return
	var choice = state.pending_choices[0]
	_expect(int(choice.get("player_id", -1)) == 0, "雷霆天怒 reveal should ask the lowest rolling player to choose", failures)
	_expect(choice.get("candidate_card_ids", []).has(returned_id), "雷霆天怒 reveal choice should include the lowest roller's battlefield legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": [returned_id]
	})).ok, "雷霆天怒 reveal choice should resolve", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "", "雷霆天怒 should return the lowest roller's chosen legion to hand", failures)
	_expect(state.get_player(0).hand.cards.has(returned_id), "雷霆天怒 should place the chosen legion back into its owner's hand", failures)
	_expect(state.get_player(1).battle_front[0].occupant != "", "雷霆天怒 should leave the non-lowest roller's legion on battlefield", failures)
	_expect(_count_event_type(state, "CardReturnedToHand") >= 1, "雷霆天怒 reveal should log the returned legion", failures)

static func _test_thunder_wrath_attack_roll_can_fail(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_thunder_strong",
		"name": "雷霆先锋",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 3000,
		"hp": 3000,
		"keywords": ["charge"],
		"effects": [],
		"text": "高兵力进攻掷骰测试"
	})
	definitions.append({
		"id": "qa_thunder_target",
		"name": "雷鸣靶子",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"keywords": [],
		"effects": [],
		"text": "承受雷霆天怒进攻测试"
	})
	var state = engine.create_game(definitions, [
		["qa_thunder_strong", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_thunder_target", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 728, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, _find_hand_card_by_definition(state, 0, "qa_thunder_strong"), "front", 0, "test_thunder_wrath_attack_fail_attacker")
	engine._deploy_hand_card_to_slot(state, 1, _find_hand_card_by_definition(state, 1, "qa_thunder_target"), "front", 0, "test_thunder_wrath_attack_fail_defender")
	var attacker_id := state.get_player(0).battle_front[0].occupant
	var defender_id := state.get_player(1).battle_front[0].occupant
	state.current_calamity = "calamity_s01_ds04"
	state.rng.state = 1
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id
	})).ok, "雷霆天怒 should allow declaring the attack before the die result is checked", failures)
	_expect(state.pending_attack.is_empty(), "雷霆天怒 should cancel the attack immediately on a low die roll", failures)
	_expect(str(state.card_instances.get(attacker_id).orientation) == "rested", "雷霆天怒 low roll should turn the attacker to rested", failures)
	_expect(bool(state.card_instances.get(attacker_id).has_attacked_this_turn), "雷霆天怒 low roll should still consume the attack", failures)
	_expect(_count_event_type(state, "AttackDeclared") == 0, "雷霆天怒 low roll should stop the attack before AttackDeclared is logged", failures)
	_expect(int(_last_event_payload(state, "DiceRolled").get("result", 0)) == 1, "雷霆天怒 attack-fail test should roll a deterministic 1", failures)
	_expect(bool(_last_event_payload(state, "AttackFinished").get("canceled_by_dice", false)), "雷霆天怒 low roll should mark AttackFinished as canceled by dice", failures)

static func _test_thunder_wrath_attack_roll_can_succeed(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_thunder_strong",
		"name": "雷霆先锋",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 3000,
		"hp": 3000,
		"keywords": ["charge"],
		"effects": [],
		"text": "高兵力进攻掷骰测试"
	})
	definitions.append({
		"id": "qa_thunder_target",
		"name": "雷鸣靶子",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"keywords": [],
		"effects": [],
		"text": "承受雷霆天怒进攻测试"
	})
	var state = engine.create_game(definitions, [
		["qa_thunder_strong", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_thunder_target", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 729, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, _find_hand_card_by_definition(state, 0, "qa_thunder_strong"), "front", 0, "test_thunder_wrath_attack_success_attacker")
	engine._deploy_hand_card_to_slot(state, 1, _find_hand_card_by_definition(state, 1, "qa_thunder_target"), "front", 0, "test_thunder_wrath_attack_success_defender")
	var attacker_id := state.get_player(0).battle_front[0].occupant
	var defender_id := state.get_player(1).battle_front[0].occupant
	state.current_calamity = "calamity_s01_ds04"
	state.rng.state = 6
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id
	})).ok, "雷霆天怒 should allow the attack to continue on a high die roll", failures)
	_expect(not state.pending_attack.is_empty(), "雷霆天怒 high roll should keep the pending attack alive", failures)
	_expect(str(state.pending_attack.get("attacker_id", "")) == attacker_id, "雷霆天怒 high roll should preserve the pending attacker", failures)
	_expect(_count_event_type(state, "AttackDeclared") == 1, "雷霆天怒 high roll should still log AttackDeclared", failures)
	_expect(int(_last_event_payload(state, "DiceRolled").get("result", 0)) == 4, "雷霆天怒 attack-success test should roll a deterministic 4", failures)
	_expect(str(state.card_instances.get(attacker_id).orientation) == "active", "雷霆天怒 high roll should not rest the attacker before combat resolves", failures)

static func _test_thunder_wrath_invalid_target_still_consumes_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_thunder_strong",
		"name": "雷霆先锋",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 3000,
		"hp": 3000,
		"keywords": ["charge"],
		"effects": [],
		"text": "高兵力进攻掷骰测试"
	})
	definitions.append({
		"id": "qa_thunder_target",
		"name": "雷鸣靶子",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"keywords": [],
		"effects": [],
		"text": "承受雷霆天怒进攻测试"
	})
	var state = engine.create_game(definitions, [
		["qa_thunder_strong", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_thunder_target", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 730, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, _find_hand_card_by_definition(state, 0, "qa_thunder_strong"), "front", 0, "test_thunder_wrath_invalid_target_attacker")
	engine._deploy_hand_card_to_slot(state, 1, _find_hand_card_by_definition(state, 1, "qa_thunder_target"), "front", 0, "test_thunder_wrath_invalid_target_defender")
	var attacker_id := state.get_player(0).battle_front[0].occupant
	var defender_id := state.get_player(1).battle_front[0].occupant
	state.current_calamity = "calamity_s01_ds04"
	state.rng.state = 6
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id
	})).ok, "雷霆天怒 invalid-target test should allow the initial declaration", failures)
	var defender_instance = state.card_instances.get(defender_id)
	state.get_player(1).battle_front[0].occupant = ""
	if defender_instance != null:
		defender_instance.zone = "grave"
		defender_instance.position = {}
	var resolution_events = engine._resolve_pending_attack_if_ready(state, "test_thunder_wrath_invalid_target_resolve")
	_expect(state.pending_attack.is_empty(), "雷霆天怒 invalid-target branch should clear pending attack", failures)
	_expect(str(state.card_instances.get(attacker_id).orientation) == "rested", "雷霆天怒 invalid-target branch should still rest the attacker", failures)
	_expect(bool(state.card_instances.get(attacker_id).has_attacked_this_turn), "雷霆天怒 invalid-target branch should still consume the attack", failures)
	_expect(bool(_last_event_payload(state, "AttackFinished").get("canceled_by_invalid_state", false)), "雷霆天怒 invalid-target branch should mark the attack as canceled by invalid state", failures)
	_expect(_count_event_type(state, "DiceRolled") == 1, "雷霆天怒 invalid-target branch should not roll more than once", failures)
	_expect(resolution_events.size() >= 2, "雷霆天怒 invalid-target branch should emit rest plus attack-finished events when the invalid defender is detected", failures)

static func _test_thunder_wrath_pending_attack_fallback_rolls(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_thunder_strong",
		"name": "雷霆先锋",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 3000,
		"hp": 3000,
		"keywords": ["charge"],
		"effects": [],
		"text": "高兵力进攻掷骰测试"
	})
	definitions.append({
		"id": "qa_thunder_target",
		"name": "雷鸣靶子",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"keywords": [],
		"effects": [],
		"text": "承受雷霆天怒进攻测试"
	})
	var state = engine.create_game(definitions, [
		["qa_thunder_strong", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_thunder_target", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 731, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, _find_hand_card_by_definition(state, 0, "qa_thunder_strong"), "front", 0, "test_thunder_wrath_fallback_attacker")
	engine._deploy_hand_card_to_slot(state, 1, _find_hand_card_by_definition(state, 1, "qa_thunder_target"), "front", 0, "test_thunder_wrath_fallback_defender")
	var attacker_id := state.get_player(0).battle_front[0].occupant
	var defender_id := state.get_player(1).battle_front[0].occupant
	state.current_calamity = "calamity_s01_ds04"
	state.rng.state = 1
	state.pending_attack = {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id,
		"response_window_opened": true
	}
	var events = engine._resolve_pending_attack_if_ready(state, "test_thunder_wrath_pending_attack_fallback")
	_expect(state.pending_attack.is_empty(), "雷霆天怒 fallback branch should clear the pending attack after the roll", failures)
	_expect(_count_event_type(state, "DiceRolled") == 1, "雷霆天怒 fallback branch should still roll once", failures)
	_expect(int(_last_event_payload(state, "DiceRolled").get("result", 0)) == 1, "雷霆天怒 fallback branch should use the deterministic low roll", failures)
	_expect(str(state.card_instances.get(attacker_id).orientation) == "rested", "雷霆天怒 fallback branch should rest the attacker on a low roll", failures)
	_expect(bool(state.card_instances.get(attacker_id).has_attacked_this_turn), "雷霆天怒 fallback branch should consume the attack on a low roll", failures)
	_expect(bool(_last_event_payload(state, "AttackFinished").get("canceled_by_dice", false)), "雷霆天怒 fallback branch should still mark the attack as canceled by dice", failures)
	_expect(events.size() >= 3, "雷霆天怒 fallback branch should emit dice, rest and finish events", failures)


static func _test_fallen_morning_star_even_roll_rests_one_morale(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 732, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 0,
		"opening_non_active_player_morale": 0
	})
	MoraleActions.add_morale_from_cost_deck(state, 0, 2, "active", "test_fallen_morning_star_seed_morale")
	state.current_calamity = "calamity_s01_ds01"
	state.phase = "main"
	state.rng.state = 6
	var active_before := MoraleActions.count_active_morale(state, 0)
	var events = engine._on_enter_phase(state, "test_fallen_morning_star_even_roll")
	_expect(active_before == 2, "黯陨晨星 even-roll test should seed two active morale", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == 1, "黯陨晨星 even roll should rest one active morale", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 1, "黯陨晨星 even roll should move one morale to spent area", failures)
	_expect(_count_event_type(state, "DiceRolled") == 1, "黯陨晨星 even roll should log one die result", failures)
	_expect(_count_event_type(state, "ChoiceRequested") == 0, "黯陨晨星 even roll should not request a choice", failures)
	_expect(events.size() >= 2, "黯陨晨星 even roll should emit dice and morale events", failures)


static func _test_fallen_morning_star_free_tactic_option_waives_play_cost(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_star_tactic",
		"name": "晨星战术测试",
		"faction": "neutral",
		"type": "tactic",
		"cost": 2,
		"power": 0,
		"hp": 0,
		"keywords": [],
		"effects": [
			{
				"id": "qa_star_draw",
				"kind": "activated",
				"text": "测试抽牌",
				"resolution": {
					"action": "draw_cards",
					"count": 1
				}
			}
		],
		"text": "用于测试黯陨晨星主动战术免费"
	})
	var state = engine.create_game(definitions, [
		["qa_star_tactic", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 733, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	state.current_calamity = "calamity_s01_ds01"
	state.phase = "main"
	state.rng.state = 1
	var events = engine._on_enter_phase(state, "test_fallen_morning_star_free_tactic_roll")
	_expect(state.pending_choices.size() == 1, "黯陨晨星 odd roll should request a choice", failures)
	if state.pending_choices.is_empty():
		return
	var choice = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": "free_tactic"
	})).ok, "黯陨晨星 free tactic option should resolve", failures)
	var tactic_id := _find_hand_card_by_definition(state, 0, "qa_star_tactic")
	_expect(engine._get_effective_play_cost(state, tactic_id) == 0, "黯陨晨星 free tactic option should reduce tactic play cost to 0", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "qa_star_draw"
	})).ok, "黯陨晨星 free tactic option should allow tactic play with no morale", failures)
	_expect(_count_event_type(state, "CardPlayed") >= 1, "黯陨晨星 free tactic option should still play the tactic normally", failures)


static func _test_fallen_morning_star_backline_troop_type_option_allows_master_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_star_archer",
		"name": "晨星弓手测试",
		"faction": "neutral",
		"type": "legion",
		"troop_type": "弓手",
		"cost": 1,
		"power": 3000,
		"hp": 3000,
		"keywords": ["charge"],
		"effects": [],
		"text": "用于测试黯陨晨星后排攻击主宰"
	})
	var state = engine.create_game(definitions, [
		["qa_star_archer", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 734, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, _find_hand_card_by_definition(state, 0, "qa_star_archer"), "back", 0, "test_fallen_morning_star_archer")
	var attacker_id := state.get_player(0).battle_back[0].occupant
	state.current_calamity = "calamity_s01_ds01"
	state.phase = "main"
	state.rng.state = 1
	engine._on_enter_phase(state, "test_fallen_morning_star_backline_roll")
	_expect(state.pending_choices.size() == 1, "黯陨晨星 backline option should request a choice", failures)
	if state.pending_choices.is_empty():
		return
	var choice = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": "backline_master_attack"
	})).ok, "黯陨晨星 backline option should resolve", failures)
	_expect(_targets_include_master(engine.get_legal_attack_targets(state, attacker_id), 1), "黯陨晨星 backline option should let a back-row archer troop-type unit attack the enemy master", failures)


static func _test_magic_dragon_reveal_clears_column_and_recycles_graves(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_counter_tactic_nullify", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_counter_tactic_nullify", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 735, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var p0_counter := _find_hand_card_by_definition(state, 0, "dev_counter_tactic_nullify")
	var p1_counter := _find_hand_card_by_definition(state, 1, "dev_counter_tactic_nullify")
	_expect(p0_counter != "" and p1_counter != "", "魔龙降世 test should draw both counter tactics", failures)
	if p0_counter == "" or p1_counter == "":
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, p0_counter, 0, "test_magic_dragon_p0_back_left_counter").is_empty(), "魔龙降世 should set player 0 counter tactic into the target column", failures)
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 1, p1_counter, 2, "test_magic_dragon_p1_back_right_counter").is_empty(), "魔龙降世 should set player 1 counter tactic into the mirrored target column", failures)
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_magic_dragon_p0_front_left")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 1, "test_magic_dragon_p0_front_mid")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 2, "test_magic_dragon_p1_front_right")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 1, "test_magic_dragon_p1_front_mid")
	var p0_deck_before := state.get_player(0).deck.cards.size()
	var p1_deck_before := state.get_player(1).deck.cards.size()
	state.rng.state = 1
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds05"
	})).ok, "debug reveal 魔龙降世 should succeed", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "" and state.get_player(0).battle_back[0].occupant == "", "魔龙降世 low roll should clear the active player's left column", failures)
	_expect(state.get_player(1).battle_front[2].occupant == "" and state.get_player(1).battle_back[2].occupant == "", "魔龙降世 low roll should clear the opponent's mirrored right column", failures)
	_expect(state.get_player(1).battle_front[0].occupant != "", "魔龙降世 low roll should not clear the opponent's non-mirrored left column", failures)
	_expect(state.get_player(0).battle_front[1].occupant != "" and state.get_player(1).battle_front[1].occupant != "", "魔龙降世 low roll should leave middle column intact", failures)
	_expect(state.pending_choices.size() == 1, "魔龙降世 should request the first grave recycle choice", failures)
	if state.pending_choices.is_empty():
		return
	var p0_choice = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(p0_choice.get("choice_id", "")),
		"selected_card_ids": state.get_player(0).grave.cards.duplicate()
	})).ok, "魔龙降世 player 0 grave recycle should resolve", failures)
	_expect(state.pending_choices.size() == 1, "魔龙降世 should chain to player 1 grave recycle choice", failures)
	if state.pending_choices.is_empty():
		return
	var p1_choice = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(p1_choice.get("choice_id", "")),
		"selected_card_ids": state.get_player(1).grave.cards.duplicate()
	})).ok, "魔龙降世 player 1 grave recycle should resolve", failures)
	_expect(state.get_player(0).grave.cards.is_empty() and state.get_player(1).grave.cards.is_empty(), "魔龙降世 should move the selected grave cards back to each player's deck", failures)
	_expect(state.get_player(0).deck.cards.size() == p0_deck_before + 2 and state.get_player(1).deck.cards.size() == p1_deck_before + 2, "魔龙降世 should recycle all destroyed cards in the chosen column back into deck bottoms", failures)
	_expect(_count_event_type(state, "DiceRolled") == 1, "魔龙降世 should roll one die for the active player on reveal", failures)
	_expect(_count_event_type(state, "CardSentToGrave") >= 4, "魔龙降世 should send the destroyed column cards to grave", failures)


static func _test_world_upheaval_reverses_decks_face_up_and_blocks_same_top_troop_type(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_world_alpha",
		"name": "天地先锋甲",
		"faction": "neutral",
		"type": "legion",
		"troop_type": "骑兵",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"keywords": [],
		"effects": [],
		"text": "用于测试天地异变翻转"
	})
	definitions.append({
		"id": "qa_world_beta",
		"name": "天地先锋乙",
		"faction": "neutral",
		"type": "legion",
		"troop_type": "弓手",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"keywords": [],
		"effects": [],
		"text": "用于测试天地异变翻转"
	})
	definitions.append({
		"id": "qa_world_gamma",
		"name": "天地先锋丙",
		"faction": "neutral",
		"type": "legion",
		"troop_type": "术师",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"keywords": [],
		"effects": [],
		"text": "用于测试天地异变翻转"
	})
	var state = engine.create_game(definitions, [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "qa_world_alpha", "qa_world_beta", "qa_world_gamma"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "qa_world_gamma", "qa_world_beta", "qa_world_alpha"]
	], 736, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 4
	})
	var p0_top_before := str(state.get_player(0).deck.cards[0])
	var p0_bottom_before := str(state.get_player(0).deck.cards[state.get_player(0).deck.cards.size() - 1])
	var p1_top_before := str(state.get_player(1).deck.cards[0])
	var p1_bottom_before := str(state.get_player(1).deck.cards[state.get_player(1).deck.cards.size() - 1])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds01"
	})).ok, "debug reveal 天地异变 should succeed", failures)
	_expect(str(state.get_player(0).deck.cards[0]) == p0_bottom_before and str(state.get_player(0).deck.cards[state.get_player(0).deck.cards.size() - 1]) == p0_top_before, "天地异变 should reverse player 0 deck order", failures)
	_expect(str(state.get_player(1).deck.cards[0]) == p1_bottom_before and str(state.get_player(1).deck.cards[state.get_player(1).deck.cards.size() - 1]) == p1_top_before, "天地异变 should reverse player 1 deck order", failures)
	for card_id in state.get_player(0).deck.cards:
		_expect(str(state.card_instances.get(card_id).face) == "face_up", "天地异变 should turn every player 0 deck card face up", failures)
	for card_id in state.get_player(1).deck.cards:
		_expect(str(state.card_instances.get(card_id).face) == "face_up", "天地异变 should turn every player 1 deck card face up", failures)
	_expect(_count_event_type(state, "DeckReversed") == 2, "天地异变 should log one DeckReversed event per player", failures)
	var blocked_hand_id := str(state.get_player(0).hand.cards[0])
	var blocked_instance = state.card_instances.get(blocked_hand_id)
	var top_instance = state.card_instances.get(str(state.get_player(0).deck.cards[0]))
	_expect(blocked_instance != null and top_instance != null, "天地异变 test should have valid hand and top-deck instances", failures)
	if blocked_instance != null and top_instance != null:
		var top_definition = state.get_definition(top_instance.definition_id)
		var blocked_definition = state.get_definition(blocked_instance.definition_id)
		if top_definition != null and blocked_definition != null:
			blocked_definition.troop_type = top_definition.troop_type
	_expect(not blocked_hand_id.is_empty(), "天地异变 test should have a hand legion matching the reversed deck top troop type", failures)
	if blocked_hand_id.is_empty():
		return
	var blocked_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": blocked_hand_id,
		"row": "front",
		"col": 0
	}))
	_expect(not blocked_result.ok and str(blocked_result.get("code", "")) == "WORLD_UPHEAVAL_TOP_TROOP_TYPE_BLOCK", "天地异变 should block playing a hand legion with the same troop type as the deck top", failures)

static func _test_storm_chaos_returns_back_row_and_disables_ranged(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["qa_ranged", "qa_vanilla", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_plain", "qa_vanilla", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 712, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, state.players[0].hand.cards[0], "front", 0, "test_storm_chaos_p0_front")
	engine._deploy_hand_card_to_slot(state, 0, state.players[0].hand.cards[0], "back", 0, "test_storm_chaos_p0_back")
	engine._deploy_hand_card_to_slot(state, 1, state.players[1].hand.cards[0], "front", 0, "test_storm_chaos_p1_front")
	engine._deploy_hand_card_to_slot(state, 1, state.players[1].hand.cards[0], "back", 0, "test_storm_chaos_p1_back")
	var p0_hand_before = state.get_player(0).hand.cards.size()
	var p1_hand_before = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds04"
	})).ok, "debug reveal 风暴乱象 should succeed", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "" and state.get_player(0).battle_back[0].occupant != "", "风暴乱象 should move player 0 front legion to back row", failures)
	_expect(state.get_player(1).battle_front[0].occupant == "" and state.get_player(1).battle_back[0].occupant != "", "风暴乱象 should move player 1 front legion to back row", failures)
	_expect(state.get_player(0).hand.cards.size() == p0_hand_before + 1 and state.get_player(1).hand.cards.size() == p1_hand_before + 1, "风暴乱象 should return each back-row card to its owner's hand", failures)
	_expect(_count_event_type(state, "CardReturnedToHand") >= 2, "风暴乱象 should log returned-to-hand events for cleared back rows", failures)
	var ranged_id = state.get_player(0).battle_back[0].occupant
	_expect(engine.get_legal_attack_targets(state, ranged_id).is_empty(), "风暴乱象 should disable ranged attacks so the ranged legion cannot attack from the back row", failures)

static func _test_sleepless_night_clears_low_power_and_punishes_active_rest(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_active_rest_legion",
		"name": "主动休整测试军团",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 3000,
		"hp": 3000,
		"calamity_level": 0,
		"keywords": [],
		"effects": [
			{
				"id": "qa_active_rest",
				"kind": "activated",
				"rest_source": true,
				"text": "测试主动休整",
				"resolution": {
					"action": "draw_cards",
					"count": 1
				}
			}
		],
		"text": "用于测试无眠之夜"
	})
	var state = engine.create_game(definitions, [
		["qa_plain", "qa_active_rest_legion", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_plain", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 713, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, _find_hand_card_by_definition(state, 0, "qa_plain"), "front", 0, "test_sleepless_night_low_power")
	engine._deploy_hand_card_to_slot(state, 0, _find_hand_card_by_definition(state, 0, "qa_active_rest_legion"), "front", 1, "test_sleepless_night_active_rest_source")
	engine._deploy_hand_card_to_slot(state, 1, _find_hand_card_by_definition(state, 1, "qa_plain"), "front", 0, "test_sleepless_night_enemy_low_power")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds03"
	})).ok, "debug reveal 无眠之夜 should succeed", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "", "无眠之夜 should clear the allied low-power legion", failures)
	_expect(state.get_player(1).battle_front[0].occupant == "", "无眠之夜 should clear the enemy low-power legion", failures)
	_expect(state.get_player(0).battle_front[1].occupant != "", "无眠之夜 should keep the allied 3000-power legion on battlefield", failures)
	_expect(_count_event_type(state, "CardDied") >= 2, "无眠之夜 should log destroyed low-power legions", failures)
	var active_rest_id = state.get_player(0).battle_front[1].occupant
	var hp_before = state.get_player(0).master_hp
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": active_rest_id,
		"effect_id": "qa_active_rest"
	})).ok, "无眠之夜 test should allow the active rest effect to activate", failures)
	_expect(state.get_player(0).master_hp == hp_before - 1, "无眠之夜 should deal one non-lethal damage when using active rest", failures)
	_expect(_count_event_type(state, "MasterDamaged") >= 1, "无眠之夜 active rest punishment should log MasterDamaged", failures)

static func _test_calamity_destruction_ignores_prevention_and_died_triggers(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_calamity_died_draw",
		"name": "天灾阵亡测试军团",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"calamity_level": 0,
		"keywords": [],
		"effects": [
			{
				"id": "draw_on_died",
				"kind": "triggered",
				"event": "CardDied",
				"self_only": true,
				"resolution": {"action": "draw_cards", "count": 1},
				"text": "阵亡时：抽1张牌。"
			}
		],
		"text": "用于测试天灾不会触发阵亡时。"
	})
	var state = engine.create_game(definitions, [
		["qa_calamity_died_draw", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 732, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var hand_before := state.get_player(0).hand.cards.size()
	var card_id := _find_hand_card_by_definition(state, 0, "qa_calamity_died_draw")
	_expect(card_id != "", "天灾阵亡测试 should draw the custom died-trigger legion", failures)
	if card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, card_id, "front", 0, "test_calamity_died_deploy")
	var instance = state.card_instances.get(card_id)
	_expect(instance != null, "天灾阵亡测试 should deploy the custom legion", failures)
	if instance == null:
		return
	instance.flags["cannot_die_until_turn_end_turn"] = state.turn_number
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds03"
	})).ok, "debug reveal 无眠之夜 should succeed for no-trigger death test", failures)
	_expect(_battlefield_count(state, 0) == 0, "天灾击杀 should still remove the legion from battlefield even if it has cannot-die protection", failures)
	_expect(state.get_player(0).grave.cards.has(card_id), "天灾击杀 should send the legion to grave", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before - 1, "天灾击杀 should not trigger the legion's died draw", failures)
	_expect(_count_event_type(state, "CardDeathPrevented") == 0, "天灾击杀 should not log death prevented events", failures)
	_expect(_count_event_type(state, "ReplacementEffectApplied") == 0, "天灾击杀 should not apply death replacement effects", failures)
	_expect(_count_event_type(state, "TriggerQueued") == 0, "天灾击杀 should not queue died triggers", failures)

static func _test_calamity_return_to_hand_suppresses_leave_triggers(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_calamity_return_draw",
		"name": "天灾离场测试军团",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 3000,
		"hp": 3000,
		"calamity_level": 0,
		"keywords": [],
		"effects": [
			{
				"id": "draw_on_return",
				"kind": "triggered",
				"event": "CardReturnedToHand",
				"self_only": true,
				"resolution": {"action": "draw_cards", "count": 1},
				"text": "返回手牌时：抽1张牌。"
			}
		],
		"text": "用于测试天灾不会触发离场时。"
	})
	var state = engine.create_game(definitions, [
		["qa_calamity_return_draw", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 733, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var hand_before := state.get_player(0).hand.cards.size()
	var card_id := _find_hand_card_by_definition(state, 0, "qa_calamity_return_draw")
	_expect(card_id != "", "天灾离场测试 should draw the custom return-trigger legion", failures)
	if card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, card_id, "back", 0, "test_calamity_return_deploy")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds04"
	})).ok, "debug reveal 风暴乱象 should succeed for no-trigger return test", failures)
	_expect(_battlefield_count(state, 0) == 0, "风暴乱象 should remove the custom back-row legion from battlefield", failures)
	_expect(state.get_player(0).hand.cards.has(card_id), "风暴乱象 should return the legion to hand", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "风暴乱象 should not trigger the legion's return-to-hand draw", failures)
	_expect(_count_event_type(state, "TriggerQueued") == 0, "风暴乱象 should not queue leave triggers", failures)

static func _test_false_grail_punishes_artifact_effects(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_artifact_lens", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 714, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 2
	})
	var artifact_id = _find_hand_card_by_definition(state, 0, "dev_artifact_lens")
	_expect(artifact_id != "", "虚构的圣杯 test should have an artifact in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "虚构的圣杯 test should allow playing the artifact", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds08"
	})).ok, "debug reveal 虚构的圣杯 should succeed", failures)
	var hp_before = state.get_player(0).master_hp
	var hand_before = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": artifact_id,
		"effect_id": "lens_draw"
	})).ok, "虚构的圣杯 should still allow artifact activation", failures)
	_expect(state.get_player(0).master_hp == hp_before - 1, "虚构的圣杯 should deal one non-lethal damage when using an artifact effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "虚构的圣杯 test first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "虚构的圣杯 test second pass should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + 1, "虚构的圣杯 should not stop the artifact effect from resolving", failures)
	_expect(_count_event_type(state, "MasterDamaged") >= 1, "虚构的圣杯 should log MasterDamaged for the punishment", failures)

static func _test_false_grail_punishes_rested_artifact_effects(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["tianting_s01_0117", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 715, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 3
	})
	var artifact_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0117")
	_expect(artifact_id != "", "虚构的圣杯 rested-artifact test should have 山河社稷图 in opening hand", failures)
	if artifact_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "虚构的圣杯 rested-artifact test should allow playing 山河社稷图", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds08"
	})).ok, "debug reveal 虚构的圣杯 should succeed for 山河社稷图", failures)
	var hp_before = state.get_player(0).master_hp
	var active_morale_before = MoraleActions.count_active_morale(state, 0)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": artifact_id,
		"effect_id": "shanhe_rested_choose_mode"
	})).ok, "虚构的圣杯 should still allow 山河社稷图 activation", failures)
	_expect(state.get_player(0).master_hp == hp_before - 1, "虚构的圣杯 should punish rested artifact activations like 山河社稷图", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "虚构的圣杯 rested-artifact first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "虚构的圣杯 rested-artifact second pass should resolve", failures)
	_expect(state.pending_choices.size() == 1, "山河社稷图 should request an option choice under 虚构的圣杯", failures)
	var option_choice = state.pending_choices[0] if not state.pending_choices.is_empty() else {}
	_expect(str(option_choice.get("operation", "")) == "resolve_option_with_shared_cost", "山河社稷图 should use the shared-cost option resolver", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(option_choice.get("choice_id", "")),
		"selected_option": "draw"
	})).ok, "山河社稷图 should still offer and resolve the draw mode under 虚构的圣杯", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "虚构的圣杯 rested-artifact third pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "虚构的圣杯 rested-artifact fourth pass should resolve", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == active_morale_before - 1, "山河社稷图 draw mode should still refund 1 active morale", failures)
	_expect(_count_event_type(state, "MasterDamaged") >= 1, "虚构的圣杯 rested-artifact test should log MasterDamaged for the punishment", failures)

static func _test_hundred_demons_bonus_damage_and_end_phase_hand_limit(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_calamity_attacker",
		"name": "天灾进攻测试军团",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 3000,
		"hp": 3000,
		"calamity_level": 2,
		"keywords": ["charge"],
		"effects": [],
		"text": "用于测试百鬼夜行"
	})
	var state = engine.create_game(definitions, [
		["qa_calamity_attacker", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 715, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 8
	})
	var attacker_id = _find_hand_card_by_definition(state, 0, "qa_calamity_attacker")
	_expect(attacker_id != "", "百鬼夜行 test should draw the calamity attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "百鬼夜行 test should allow playing the calamity attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds02"
	})).ok, "debug reveal 百鬼夜行 should succeed", failures)
	var hp_after_reveal = state.get_player(1).master_hp
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": state.get_player(0).battle_front[0].occupant,
		"target_kind": "master",
		"target_player": 1
	})).ok, "百鬼夜行 calamity attacker should be able to attack the enemy master", failures)
	_expect(_resolve_pending_attack_window(engine, state, failures, "百鬼夜行 master attack should resolve through the response window"), "百鬼夜行 master attack should resolve through the response window", failures)
	_expect(state.get_player(1).master_hp == hp_after_reveal - 2, "百鬼夜行 should give calamity legions +1 damage when attacking the master", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "百鬼夜行 should allow advancing into end phase", failures)
	_expect(state.phase == "end", "百鬼夜行 hand-limit test should now be in end phase", failures)
	_expect(state.pending_choices.size() == 1, "百鬼夜行 should request a hand-to-deck choice when the active player has more than five cards", failures)
	var choice = state.pending_choices[0]
	_expect(str(choice.get("operation", "")) == "return_hand_to_deck_bottom", "百鬼夜行 should use the hand-to-deck-bottom choice operation", failures)
	var candidates = choice.get("candidate_card_ids", [])
	_expect(candidates is Array and candidates.size() == 7, "百鬼夜行 should expose all current hand cards as return candidates", failures)
	if not (candidates is Array) or candidates.size() < 2:
		failures.append("百鬼夜行 should expose at least two hand cards to return")
		return
	var selected = [str(candidates[0]), str(candidates[1])]
	var deck_before = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected
	})).ok, "百鬼夜行 hand-to-deck choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == 5, "百鬼夜行 should leave the active player with five cards in hand", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before + 2, "百鬼夜行 should return the selected cards to deck bottom", failures)
	_expect(state.get_player(0).deck.cards.slice(deck_before, deck_before + 2) == selected, "百鬼夜行 should keep the chosen return order at deck bottom", failures)
	_expect(_count_event_type(state, "CardReturnedToDeck") >= 2, "百鬼夜行 should log returned-to-deck events for the returned hand cards", failures)

static func _test_divine_balance_equalizes_hp_and_rewards_changed_players(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _divine_balance_changed_players_decks(), 716, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 5
	})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 18
	})).ok, "神之天平 changed-players test should set player 0 hp", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 16
	})).ok, "神之天平 changed-players test should set player 1 hp", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds06"
	})).ok, "debug reveal 神之天平 should succeed for changed-players branch", failures)
	_expect(state.get_player(0).master_hp == 16 and state.get_player(1).master_hp == 16, "神之天平 should reduce all masters to the lowest current hp", failures)
	_expect(state.get_player(0).hand.cards.size() == 7 and state.get_player(1).hand.cards.size() == 5, "神之天平 should let only hp-changed players draw two cards before the discard prompts", failures)
	_expect(_count_event_type(state, "MasterHpSet") >= 1, "神之天平 should log MasterHpSet when a master hp changes", failures)
	_expect(state.pending_choices.size() == 1, "神之天平 should request the first discard choice immediately after drawing", failures)
	var first_choice = state.pending_choices[0]
	_expect(str(first_choice.get("operation", "")) == "discard_from_hand", "神之天平 first choice should discard from hand", failures)
	var first_candidates = first_choice.get("candidate_card_ids", [])
	_expect(first_candidates is Array and first_candidates.size() == 7, "神之天平 first discard choice should expose all current player 0 hand cards", failures)
	if not (first_candidates is Array) or first_candidates.is_empty():
		failures.append("神之天平 first discard choice should expose at least one card")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(first_choice.get("choice_id", "")),
		"selected_card_ids": [str(first_candidates[0])]
	})).ok, "神之天平 player 0 discard choice should resolve", failures)
	_expect(state.pending_choices.size() == 1, "神之天平 should then request player 1 discard", failures)
	var second_choice = state.pending_choices[0]
	var second_candidates = second_choice.get("candidate_card_ids", [])
	_expect(second_candidates is Array and second_candidates.size() == 5, "神之天平 second discard choice should expose all current player 1 hand cards", failures)
	if not (second_candidates is Array) or second_candidates.is_empty():
		failures.append("神之天平 second discard choice should expose at least one card")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(second_choice.get("choice_id", "")),
		"selected_card_ids": [str(second_candidates[0])]
	})).ok, "神之天平 player 1 discard choice should resolve", failures)
	_expect(state.pending_choices.is_empty(), "神之天平 should clear pending choices after both discards resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == 7 and state.get_player(1).hand.cards.size() == 5, "神之天平 changed-players branch should end with expected hand counts after discard then draw", failures)
	_expect(_count_event_type(state, "CardDrawn") >= 4, "神之天平 changed-players branch should log the expected draws", failures)
	_expect(_count_event_type(state, "CardDiscarded") >= 2, "神之天平 changed-players branch should log both discards", failures)

static func _test_divine_balance_draws_all_players_when_hp_is_already_equal(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _divine_balance_decks(), 717, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 5
	})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds06"
	})).ok, "debug reveal 神之天平 should succeed for equal-hp branch", failures)
	_expect(not _has_event_type(state, "MasterHpSet"), "神之天平 equal-hp branch should not change master hp", failures)
	_expect(state.get_player(0).hand.cards.size() == 6 and state.get_player(1).hand.cards.size() == 6, "神之天平 equal-hp branch should let both players draw one before discarding", failures)
	_expect(state.pending_choices.size() == 1, "神之天平 equal-hp branch should still request a discard choice", failures)
	var first_choice = state.pending_choices[0]
	var first_candidates = first_choice.get("candidate_card_ids", [])
	if not (first_candidates is Array) or first_candidates.is_empty():
		failures.append("神之天平 equal-hp first discard choice should expose cards")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(first_choice.get("choice_id", "")),
		"selected_card_ids": [str(first_candidates[0])]
	})).ok, "神之天平 equal-hp player 0 discard should resolve", failures)
	var second_choice = state.pending_choices[0]
	var second_candidates = second_choice.get("candidate_card_ids", [])
	if not (second_candidates is Array) or second_candidates.is_empty():
		failures.append("神之天平 equal-hp second discard choice should expose cards")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(second_choice.get("choice_id", "")),
		"selected_card_ids": [str(second_candidates[0])]
	})).ok, "神之天平 equal-hp player 1 discard should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == 6 and state.get_player(1).hand.cards.size() == 6, "神之天平 equal-hp branch should end with both players net plus one card", failures)
	_expect(_count_event_type(state, "CardDrawn") >= 4, "神之天平 equal-hp branch should log four draws total", failures)
	_expect(_count_event_type(state, "CardDiscarded") >= 2, "神之天平 equal-hp branch should log two discards total", failures)

static func _test_apocalypse_clears_to_two_and_reorders_all_hands(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 724, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_apocalypse_p0_front_0")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 1, "test_apocalypse_p0_front_1")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "back", 0, "test_apocalypse_p0_back_0")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 0, "test_apocalypse_p1_front_0")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 1, "test_apocalypse_p1_front_1")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "back", 0, "test_apocalypse_p1_back_0")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "back", 1, "test_apocalypse_p1_back_1")
	var p0_hand_before: Array = state.get_player(0).hand.cards.duplicate()
	var p1_hand_before: Array = state.get_player(1).hand.cards.duplicate()
	_expect(p0_hand_before.size() == 3 and p1_hand_before.size() == 2, "天启默示录 test should seed hands after battlefield deployment", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds07"
	})).ok, "debug reveal 天启默示录 should succeed", failures)
	_expect(state.pending_choices.size() == 1, "天启默示录 should first request player 1 battlefield reduction", failures)
	var p0_battle_choice = state.pending_choices[0]
	_expect(str(p0_battle_choice.get("operation", "")) == "destroy_battlefield_card" and int(p0_battle_choice.get("count", 0)) == 1, "天启默示录 should ask player 1 to send one legion to grave", failures)
	var p0_battle_candidates = p0_battle_choice.get("candidate_card_ids", [])
	if not (p0_battle_candidates is Array) or p0_battle_candidates.is_empty():
		failures.append("天启默示录 should expose player 1 battlefield candidates")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(p0_battle_choice.get("choice_id", "")),
		"selected_card_ids": [str(p0_battle_candidates[0])]
	})).ok, "天启默示录 player 1 battlefield reduction should resolve", failures)
	_expect(state.pending_choices.size() == 1, "天启默示录 should then request player 2 battlefield reduction", failures)
	var p1_battle_choice = state.pending_choices[0]
	_expect(str(p1_battle_choice.get("operation", "")) == "destroy_battlefield_card" and int(p1_battle_choice.get("count", 0)) == 2, "天启默示录 should ask player 2 to send two legions to grave", failures)
	var p1_battle_candidates = p1_battle_choice.get("candidate_card_ids", [])
	if not (p1_battle_candidates is Array) or p1_battle_candidates.size() < 2:
		failures.append("天启默示录 should expose enough player 2 battlefield candidates")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(p1_battle_choice.get("choice_id", "")),
		"selected_card_ids": [str(p1_battle_candidates[0]), str(p1_battle_candidates[1])]
	})).ok, "天启默示录 player 2 battlefield reduction should resolve", failures)
	_expect(state.pending_choices.size() == 1, "天启默示录 should next request player 1 whole-hand reorder", failures)
	var p0_hand_choice = state.pending_choices[0]
	_expect(str(p0_hand_choice.get("operation", "")) == "return_hand_to_deck_bottom", "天启默示录 should use the hand-to-deck-bottom choice for player 1", failures)
	_expect(bool(p0_hand_choice.get("context", {}).get("drag_reorder_all_candidates", false)), "天启默示录 should mark player 1 hand reorder as full-hand drag reorder", failures)
	var p0_return_order: Array[String] = []
	for i in range(p0_hand_before.size() - 1, -1, -1):
		p0_return_order.append(str(p0_hand_before[i]))
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(p0_hand_choice.get("choice_id", "")),
		"selected_card_ids": p0_return_order
	})).ok, "天启默示录 player 1 whole-hand reorder should resolve", failures)
	_expect(state.pending_choices.size() == 1, "天启默示录 should then request player 2 whole-hand reorder", failures)
	var p1_hand_choice = state.pending_choices[0]
	_expect(str(p1_hand_choice.get("operation", "")) == "return_hand_to_deck_bottom", "天启默示录 should use the hand-to-deck-bottom choice for player 2", failures)
	_expect(bool(p1_hand_choice.get("context", {}).get("drag_reorder_all_candidates", false)), "天启默示录 should mark player 2 hand reorder as full-hand drag reorder", failures)
	var p1_return_order: Array[String] = []
	for i in range(p1_hand_before.size() - 1, -1, -1):
		p1_return_order.append(str(p1_hand_before[i]))
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(p1_hand_choice.get("choice_id", "")),
		"selected_card_ids": p1_return_order
	})).ok, "天启默示录 player 2 whole-hand reorder should resolve", failures)
	_expect(state.pending_choices.is_empty(), "天启默示录 should clear pending choices after both whole-hand reorders", failures)
	_expect(_battlefield_count(state, 0) == 2 and _battlefield_count(state, 1) == 2, "天启默示录 should leave each player with at most two battlefield legions", failures)
	_expect(state.get_player(0).hand.cards.size() == 4 and state.get_player(1).hand.cards.size() == 4, "天启默示录 should leave both players with four cards after drawing", failures)
	_expect(_count_event_type(state, "CardDied") >= 3, "天启默示录 should log destroyed battlefield legions", failures)
	_expect(_count_event_type(state, "CardReturnedToDeck") >= p0_return_order.size() + p1_return_order.size(), "天启默示录 should log returning all hand cards to deck bottom", failures)
	var p0_deck := state.get_player(0).deck.cards
	var p1_deck := state.get_player(1).deck.cards
	_expect(p0_deck.slice(p0_deck.size() - p0_return_order.size(), p0_deck.size()) == p0_return_order, "天启默示录 should preserve player 1 whole-hand return order at deck bottom", failures)
	_expect(p1_deck.slice(p1_deck.size() - p1_return_order.size(), p1_deck.size()) == p1_return_order, "天启默示录 should preserve player 2 whole-hand return order at deck bottom", failures)

static func _test_apocalypse_in_calamity_phase_finishes_into_ready(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_counter_tactic_nullify", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_counter_tactic_nullify", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 796, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 0,
		"opening_non_active_player_morale": 0
	})
	var p0_counter := _find_hand_card_by_definition(state, 0, "dev_counter_tactic_nullify")
	var p1_counter := _find_hand_card_by_definition(state, 1, "dev_counter_tactic_nullify")
	_expect(p0_counter != "" and p1_counter != "", "天启默示录 ready-transition test should draw both counter tactics", failures)
	if p0_counter.is_empty() or p1_counter.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, p0_counter, 2, "test_apocalypse_ready_p0_counter").is_empty(), "天启默示录 ready-transition test should set player 1 counter tactic", failures)
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 1, p1_counter, 2, "test_apocalypse_ready_p1_counter").is_empty(), "天启默示录 ready-transition test should set player 2 counter tactic", failures)
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_apocalypse_ready_p0_front_0")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 1, "test_apocalypse_ready_p0_front_1")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "back", 0, "test_apocalypse_ready_p0_back_0")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 0, "test_apocalypse_ready_p1_front_0")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 1, "test_apocalypse_ready_p1_front_1")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "back", 0, "test_apocalypse_ready_p1_back_0")
	state.phase = "calamity"
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds07"
	})).ok, "天启默示录 ready-transition test should reveal successfully", failures)
	var first_choice = state.pending_choices[0] if not state.pending_choices.is_empty() else {}
	_expect(not first_choice.is_empty(), "天启默示录 ready-transition test should request the first reduction choice", failures)
	if first_choice.is_empty():
		return
	var first_candidates = first_choice.get("candidate_card_ids", [])
	_expect(not first_candidates.has(p0_counter), "天启默示录 should not include set counter tactics in player 1 reduction candidates", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(first_choice.get("choice_id", "")),
		"selected_card_ids": [str(first_candidates[0])]
	})).ok, "天启默示录 ready-transition test should resolve player 1 reduction", failures)
	var second_choice = state.pending_choices[0] if not state.pending_choices.is_empty() else {}
	_expect(not second_choice.is_empty(), "天启默示录 ready-transition test should request the second reduction choice", failures)
	if second_choice.is_empty():
		return
	var second_candidates = second_choice.get("candidate_card_ids", [])
	_expect(not second_candidates.has(p1_counter), "天启默示录 should not include set counter tactics in player 2 reduction candidates", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(second_choice.get("choice_id", "")),
		"selected_card_ids": [str(second_candidates[0])]
	})).ok, "天启默示录 ready-transition test should resolve player 2 reduction", failures)
	var p0_hand_choice = state.pending_choices[0] if not state.pending_choices.is_empty() else {}
	if p0_hand_choice.is_empty():
		failures.append("天启默示录 ready-transition test should request player 1 hand reorder")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(p0_hand_choice.get("choice_id", "")),
		"selected_card_ids": state.get_player(0).hand.cards.duplicate()
	})).ok, "天启默示录 ready-transition test should resolve player 1 hand reorder", failures)
	var p1_hand_choice = state.pending_choices[0] if not state.pending_choices.is_empty() else {}
	if p1_hand_choice.is_empty():
		failures.append("天启默示录 ready-transition test should request player 2 hand reorder")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(p1_hand_choice.get("choice_id", "")),
		"selected_card_ids": state.get_player(1).hand.cards.duplicate()
	})).ok, "天启默示录 ready-transition test should resolve player 2 hand reorder", failures)
	_expect(state.pending_choices.is_empty(), "天启默示录 ready-transition test should finish all pending choices", failures)
	_expect(state.phase == "ready", "天启默示录 in calamity phase should auto-advance into ready after all choices finish", failures)
	_expect(state.get_player(0).battle_back[2].occupant == p0_counter and state.get_player(1).battle_back[2].occupant == p1_counter, "天启默示录 should preserve set counter tactics on the battlefield", failures)

static func _test_ragnarok_opening_trigger_clears_board_and_draws_all(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 725, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_ragnarok_opening_p0_front")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "back", 0, "test_ragnarok_opening_p1_back")
	var p0_hand_before := state.get_player(0).hand.cards.size()
	var p1_hand_before := state.get_player(1).hand.cards.size()
	state.phase = "calamity"
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds09"
	})).ok, "debug reveal 诸神黄昏 should succeed for opening-trigger branch", failures)
	_expect(_battlefield_count(state, 0) == 0 and _battlefield_count(state, 1) == 0, "诸神黄昏 opening-trigger branch should clear all battlefield legions", failures)
	_expect(state.get_player(0).hand.cards.size() == p0_hand_before + 2 and state.get_player(1).hand.cards.size() == p1_hand_before + 2, "诸神黄昏 opening-trigger branch should let both players draw two cards", failures)
	_expect(state.active_player == 0 and state.phase == "ready", "诸神黄昏 opening-trigger branch should auto-advance out of calamity without starting an extra turn", failures)
	_expect(_count_event_type(state, "CardDied") >= 2, "诸神黄昏 opening-trigger branch should log destroyed battlefield legions", failures)
	_expect(_count_event_type(state, "CardDrawn") >= 4, "诸神黄昏 opening-trigger branch should log four opening-trigger draws", failures)
	_expect(not _has_event_type(state, "ExtraTurnStarted"), "诸神黄昏 opening-trigger branch should not log an extra turn", failures)

static func _test_ragnarok_preserves_set_counter_tactics(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_counter_tactic_nullify", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_counter_tactic_nullify", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 797, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 0,
		"opening_non_active_player_morale": 0
	})
	var p0_counter := _find_hand_card_by_definition(state, 0, "dev_counter_tactic_nullify")
	var p1_counter := _find_hand_card_by_definition(state, 1, "dev_counter_tactic_nullify")
	_expect(p0_counter != "" and p1_counter != "", "诸神黄昏 preserved-counter test should draw both counter tactics", failures)
	if p0_counter.is_empty() or p1_counter.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, p0_counter, 1, "test_ragnarok_preserve_p0_counter").is_empty(), "诸神黄昏 preserved-counter test should set player 1 counter tactic", failures)
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 1, p1_counter, 1, "test_ragnarok_preserve_p1_counter").is_empty(), "诸神黄昏 preserved-counter test should set player 2 counter tactic", failures)
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_ragnarok_preserve_p0_front")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "back", 0, "test_ragnarok_preserve_p1_back")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds09"
	})).ok, "诸神黄昏 preserved-counter test should reveal successfully", failures)
	_expect(state.get_player(0).battle_back[1].occupant == p0_counter and state.get_player(1).battle_back[1].occupant == p1_counter, "诸神黄昏 should not clear set counter tactics", failures)

static func _test_ragnarok_active_trigger_grants_extra_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 726, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_ragnarok_active_p0_front")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 0, "test_ragnarok_active_p1_front")
	var p0_hand_before := state.get_player(0).hand.cards.size()
	var p1_hand_before := state.get_player(1).hand.cards.size()
	var turn_before: int = state.turn_number
	_expect(state.phase == "main" and state.active_player == 0, "诸神黄昏 active-trigger test should start in player 1 main phase", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s01_ds09"
	})).ok, "debug reveal 诸神黄昏 should succeed for active-trigger branch", failures)
	_expect(_battlefield_count(state, 0) == 0 and _battlefield_count(state, 1) == 0, "诸神黄昏 active-trigger branch should clear all battlefield legions", failures)
	_expect(state.get_player(0).hand.cards.size() == p0_hand_before and state.get_player(1).hand.cards.size() == p1_hand_before + 2, "诸神黄昏 active-trigger branch should only let the other player draw two cards", failures)
	_expect(state.active_player == 0 and state.phase == "ready", "诸神黄昏 active-trigger branch should immediately start a new turn for the current active player", failures)
	_expect(state.turn_number == turn_before + 1, "诸神黄昏 active-trigger branch should increment the turn number", failures)
	_expect(_count_event_type(state, "CardDied") >= 2, "诸神黄昏 active-trigger branch should log destroyed battlefield legions", failures)
	_expect(_count_event_type(state, "CardDrawn") >= 2, "诸神黄昏 active-trigger branch should log the two opponent draws", failures)
	_expect(_has_event_type(state, "ExtraTurnStarted"), "诸神黄昏 active-trigger branch should log the extra turn event", failures)

static func _test_fog_desperation_discards_down_to_five_and_restricts_attacks(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append_array([
		{
			"id": "qa_fog_low",
			"name": "迷雾低兵力测试军团",
			"faction": "neutral",
			"type": "legion",
			"cost": 1,
			"power": 2000,
			"hp": 2000,
			"calamity_level": 0,
			"keywords": ["charge"],
			"effects": [],
			"text": "用于测试迷雾绝境的主宰攻击限制"
		},
		{
			"id": "qa_fog_strong",
			"name": "迷雾高兵力测试军团",
			"faction": "neutral",
			"type": "legion",
			"cost": 1,
			"power": 3000,
			"hp": 3000,
			"calamity_level": 0,
			"keywords": ["charge"],
			"effects": [],
			"text": "用于测试迷雾绝境"
		},
		{
			"id": "qa_fog_taunt",
			"name": "迷雾挑衅测试军团",
			"faction": "neutral",
			"type": "legion",
			"cost": 1,
			"power": 3000,
			"hp": 3000,
			"calamity_level": 0,
			"keywords": ["taunt"],
			"effects": [],
			"text": "用于测试迷雾绝境的挑衅失效"
		}
	])
	var discard_state = engine.create_game(definitions, [
		["qa_fog_strong", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_fog_taunt", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 718, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 5
	})
	_expect(engine.apply_command(discard_state, GameCommand.create(0, "DebugCommand", {
		"action": "draw_cards",
		"player_id": 0,
		"count": 2
	})).ok, "迷雾绝境 discard test should draw two cards for player 0", failures)
	_expect(engine.apply_command(discard_state, GameCommand.create(0, "DebugCommand", {
		"action": "draw_cards",
		"player_id": 1,
		"count": 2
	})).ok, "迷雾绝境 discard test should draw two cards for player 1", failures)
	_expect(engine.apply_command(discard_state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds02"
	})).ok, "debug reveal 迷雾绝境 should succeed for discard branch", failures)
	_expect(discard_state.pending_choices.size() == 1, "迷雾绝境 should request the first discard-down-to-five choice", failures)
	var p0_choice = discard_state.pending_choices[0]
	var p0_candidates = p0_choice.get("candidate_card_ids", [])
	_expect(p0_candidates is Array and p0_candidates.size() == 7, "迷雾绝境 should expose all player 0 hand cards for the first discard choice", failures)
	if not (p0_candidates is Array) or p0_candidates.size() < 2:
		failures.append("迷雾绝境 should expose at least two player 0 hand cards to discard")
		return
	_expect(engine.apply_command(discard_state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(p0_choice.get("choice_id", "")),
		"selected_card_ids": [str(p0_candidates[0]), str(p0_candidates[1])]
	})).ok, "迷雾绝境 player 0 discard-down-to-five choice should resolve", failures)
	_expect(discard_state.pending_choices.size() == 1, "迷雾绝境 should then request the player 1 discard-down-to-five choice", failures)
	var p1_choice = discard_state.pending_choices[0]
	var p1_candidates = p1_choice.get("candidate_card_ids", [])
	_expect(p1_candidates is Array and p1_candidates.size() == 7, "迷雾绝境 should expose all player 1 hand cards for the second discard choice", failures)
	if not (p1_candidates is Array) or p1_candidates.size() < 2:
		failures.append("迷雾绝境 should expose at least two player 1 hand cards to discard")
		return
	_expect(engine.apply_command(discard_state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(p1_choice.get("choice_id", "")),
		"selected_card_ids": [str(p1_candidates[0]), str(p1_candidates[1])]
	})).ok, "迷雾绝境 player 1 discard-down-to-five choice should resolve", failures)
	_expect(discard_state.get_player(0).hand.cards.size() == 5 and discard_state.get_player(1).hand.cards.size() == 5, "迷雾绝境 should leave both players with five cards after its trigger", failures)
	_expect(_count_event_type(discard_state, "CardDiscarded") >= 4, "迷雾绝境 trigger should log four hand discards", failures)

	var master_block_state = engine.create_game(definitions, [
		["qa_fog_low", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 719, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 5
	})
	var low_id = _find_hand_card_by_definition(master_block_state, 0, "qa_fog_low")
	_expect(engine.apply_command(master_block_state, GameCommand.create(0, "PlayCard", {
		"card_id": low_id,
		"row": "front",
		"col": 0
	})).ok, "迷雾绝境 low-power attacker should enter the battlefield", failures)
	_expect(engine.apply_command(master_block_state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds02"
	})).ok, "debug reveal 迷雾绝境 should succeed for low-power master attack branch", failures)
	var low_targets = engine.get_legal_attack_targets(master_block_state, master_block_state.get_player(0).battle_front[0].occupant)
	_expect(not _targets_include_master(low_targets, 1), "迷雾绝境 should stop low-power legions from attacking the enemy master", failures)
	var blocked_master_attack = engine.apply_command(master_block_state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": master_block_state.get_player(0).battle_front[0].occupant,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(not blocked_master_attack.ok and str(blocked_master_attack.get("code", "")) == "MASTER_ATTACK_BLOCKED_BY_CALAMITY", "迷雾绝境 should reject low-power master attacks with the calamity-specific code", failures)

	var taunt_state = engine.create_game(definitions, [
		["qa_fog_strong", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_fog_taunt", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 720, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 5
	})
	var strong_id = _find_hand_card_by_definition(taunt_state, 0, "qa_fog_strong")
	var taunt_id = _find_hand_card_by_definition(taunt_state, 1, "qa_fog_taunt")
	_expect(engine.apply_command(taunt_state, GameCommand.create(0, "PlayCard", {
		"card_id": strong_id,
		"row": "front",
		"col": 0
	})).ok, "迷雾绝境 taunt branch should deploy the attacker", failures)
	_advance_to_next_main(engine, taunt_state, failures, "迷雾绝境 taunt branch should advance to player 2 main")
	_expect(engine.apply_command(taunt_state, GameCommand.create(1, "PlayCard", {
		"card_id": taunt_id,
		"row": "back",
		"col": 0
	})).ok, "迷雾绝境 taunt branch should deploy the taunt unit in back row", failures)
	_advance_to_next_main(engine, taunt_state, failures, "迷雾绝境 taunt branch should advance back to player 1 main")
	_expect(engine.apply_command(taunt_state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds02"
	})).ok, "debug reveal 迷雾绝境 should succeed for taunt branch", failures)
	var strong_targets = engine.get_legal_attack_targets(taunt_state, taunt_state.get_player(0).battle_front[0].occupant)
	_expect(_targets_include_master(strong_targets, 1), "迷雾绝境 should make taunt ineffective so master remains attackable", failures)

	var front_state = engine.create_game(definitions, [
		["qa_fog_strong", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_fog_strong", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 721, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 5
	})
	var front_attacker = _find_hand_card_by_definition(front_state, 0, "qa_fog_strong")
	var front_defender = _find_hand_card_by_definition(front_state, 1, "qa_fog_strong")
	_expect(engine.apply_command(front_state, GameCommand.create(0, "PlayCard", {
		"card_id": front_attacker,
		"row": "front",
		"col": 0
	})).ok, "迷雾绝境 front branch should deploy the attacker", failures)
	_advance_to_next_main(engine, front_state, failures, "迷雾绝境 front branch should advance to player 2 main")
	_expect(engine.apply_command(front_state, GameCommand.create(1, "PlayCard", {
		"card_id": front_defender,
		"row": "front",
		"col": 0
	})).ok, "迷雾绝境 front branch should deploy the defender", failures)
	_advance_to_next_main(engine, front_state, failures, "迷雾绝境 front branch should advance back to player 1 main")
	_expect(engine.apply_command(front_state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds02"
	})).ok, "debug reveal 迷雾绝境 should succeed for front-row restriction branch", failures)
	var defender_instance_id = front_state.get_player(1).battle_front[0].occupant
	var active_front_attack = engine.apply_command(front_state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": front_state.get_player(0).battle_front[0].occupant,
		"defender_id": defender_instance_id
	}))
	_expect(not active_front_attack.ok and str(active_front_attack.get("code", "")) == "ACTIVE_FRONT_ROW_BLOCKED_BY_CALAMITY", "迷雾绝境 should block attacks against active front-row legions", failures)
	engine._rest_target_unit(front_state, defender_instance_id, "test_fog_desperation_front_row_rest")
	_expect(engine.apply_command(front_state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": front_state.get_player(0).battle_front[0].occupant,
		"defender_id": defender_instance_id
	})).ok, "迷雾绝境 should allow attacking the front-row legion once it is rested", failures)

static func _test_pride_sin_battlefield_choice_and_master_cost(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 722, [
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12},
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_pride_sin_p0_front_0")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 1, "test_pride_sin_p0_front_1")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "back", 0, "test_pride_sin_p0_back_0")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 0, "test_pride_sin_p1_front_0")
	_expect(_battlefield_count(state, 0) == 3 and _battlefield_count(state, 1) == 1, "傲慢之罪 battlefield branch should seed a 3 versus 1 battlefield count", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds06"
	})).ok, "debug reveal 傲慢之罪 should succeed for battlefield branch", failures)
	_expect(state.pending_choices.size() == 1, "傲慢之罪 should request a choice from the player with more legions", failures)
	var option_choice = state.pending_choices[0]
	_expect(str(option_choice.get("operation", "")) == "pride_sin_resolution", "傲慢之罪 should use its dedicated option choice operation", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(option_choice.get("choice_id", "")),
		"selected_option": "discard_battlefield"
	})).ok, "傲慢之罪 battlefield option should resolve", failures)
	_expect(state.pending_choices.size() == 1, "傲慢之罪 battlefield option should request a battlefield discard choice", failures)
	var discard_choice = state.pending_choices[0]
	var candidates = discard_choice.get("candidate_card_ids", [])
	_expect(str(discard_choice.get("operation", "")) == "destroy_battlefield_card", "傲慢之罪 battlefield branch should destroy chosen battlefield cards", failures)
	_expect(candidates is Array and candidates.size() == 3 and int(discard_choice.get("count", 0)) == 2, "傲慢之罪 battlefield branch should force discarding two of the three allied legions", failures)
	if not (candidates is Array) or candidates.size() < 2:
		failures.append("傲慢之罪 battlefield branch should expose enough candidate battlefield cards")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [str(candidates[0]), str(candidates[1])]
	})).ok, "傲慢之罪 battlefield discard choice should resolve", failures)
	_expect(_battlefield_count(state, 0) == 1 and _battlefield_count(state, 1) == 1, "傲慢之罪 battlefield branch should leave both players with equal legion counts", failures)
	_expect(_count_event_type(state, "CardDied") >= 2, "傲慢之罪 battlefield branch should log two destroyed legions", failures)
	var blocked_master = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "loki_draw_discard"
	}))
	_expect(not blocked_master.ok and str(blocked_master.get("code", "")) == "NOT_ENOUGH_MORALE", "傲慢之罪 should make master effects cost one extra morale", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "傲慢之罪 battlefield branch should add one extra morale for the master effect retest", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "loki_draw_discard"
	})).ok, "傲慢之罪 should allow the master effect once the extra morale is available", failures)

static func _test_pride_sin_hand_choice_and_hand_legion_cost(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 723, [
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12},
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 0, "test_pride_sin_hand_p0_front_0")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "front", 1, "test_pride_sin_hand_p0_front_1")
	engine._deploy_hand_card_to_slot(state, 0, state.get_player(0).hand.cards[0], "back", 0, "test_pride_sin_hand_p0_back_0")
	engine._deploy_hand_card_to_slot(state, 1, state.get_player(1).hand.cards[0], "front", 0, "test_pride_sin_hand_p1_front_0")
	var hand_before = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "calamity_s02_ds06"
	})).ok, "debug reveal 傲慢之罪 should succeed for hand branch", failures)
	var option_choice = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(option_choice.get("choice_id", "")),
		"selected_option": "discard_hand"
	})).ok, "傲慢之罪 hand option should resolve", failures)
	_expect(state.pending_choices.size() == 1, "傲慢之罪 hand option should request a hand discard choice", failures)
	var discard_choice = state.pending_choices[0]
	var candidates = discard_choice.get("candidate_card_ids", [])
	_expect(str(discard_choice.get("operation", "")) == "discard_from_hand", "傲慢之罪 hand branch should discard from hand", failures)
	_expect(candidates is Array and candidates.size() == hand_before and int(discard_choice.get("count", 0)) == 2, "傲慢之罪 hand branch should force discarding the battlefield count difference", failures)
	if not (candidates is Array) or candidates.size() < 2:
		failures.append("傲慢之罪 hand branch should expose enough hand cards")
		return
	var kept_card = str(candidates[2])
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [str(candidates[0]), str(candidates[1])]
	})).ok, "傲慢之罪 hand discard choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before - 2, "傲慢之罪 hand branch should discard two hand cards", failures)
	var blocked_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kept_card,
		"row": "front",
		"col": 2
	}))
	_expect(not blocked_play.ok and str(blocked_play.get("code", "")) == "NOT_ENOUGH_MORALE", "傲慢之罪 should make hand legions cost one extra morale to play", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "傲慢之罪 hand branch should add one extra morale for the legion play retest", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kept_card,
		"row": "front",
		"col": 2
	})).ok, "傲慢之罪 should allow the same legion to be played once the extra morale is paid", failures)

static func _test_new_calamity_clears_previous_continuous_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 704)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "sys_calamity_silence"
	})).ok, "debug reveal silence calamity should succeed", failures)
	_expect(state.current_calamity == "sys_calamity_silence", "silence calamity should become current", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "sys_calamity_embers"
	})).ok, "debug reveal next calamity should succeed", failures)
	_expect(state.current_calamity == "sys_calamity_embers", "new calamity should replace the previous calamity", failures)
	_expect(state.calamity_grave.has("sys_calamity_silence"), "previous calamity should move to calamity grave", failures)
	var card_id = state.players[0].hand.cards[0]
	var slots = engine.get_legal_play_slots(state, 0, card_id)
	_expect(slots.size() == 6, "back-row restriction should be cleared after a new calamity replaces silence", failures)
	_expect(_has_event_type(state, "CalamityCleared"), "replacing calamity should emit CalamityCleared", failures)

static func _test_final_calamity_locks_value(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 703)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "reveal_calamity",
		"definition_id": "sys_calamity_annihilation"
	})).ok, "debug reveal final calamity should succeed", failures)
	_expect(state.current_calamity == "sys_calamity_annihilation", "final calamity should become current calamity", failures)
	_expect(state.calamity_value_locked, "final calamity should lock calamity value", failures)
	_expect(state.players[0].master_hp == 20 and state.players[1].master_hp == 20, "最终天灾 湮灭 should not damage masters immediately on reveal", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "advance to end phase with final calamity should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "advance into calamity phase with final calamity should succeed", failures)
	_expect(state.calamity_value == 0, "locked final calamity should prevent future calamity value increases", failures)
	_expect(state.phase == "ready", "最终天灾 湮灭 should auto-advance into ready after calamity resolution", failures)
	_expect(state.players[0].master_hp == 19 and state.players[1].master_hp == 19, "最终天灾 湮灭 should deal one non-lethal damage to both masters when auto-entering turn start", failures)

static func _test_formal_random_calamity_deck_ends_with_annihilation(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 793, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"calamity_random_three_plus_annihilation": true
	})
	_expect(state.calamity_deck.size() == 4, "formal calamity deck should contain 3 random calamities plus 湮灭", failures)
	if state.calamity_deck.size() == 4:
		_expect(str(state.calamity_deck[3]) == "sys_calamity_annihilation", "formal calamity deck should always end with 最终天灾 湮灭", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _divine_balance_decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _divine_balance_changed_players_decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _count_event_type(state, event_type: String) -> int:
	var count := 0
	for event in state.event_log:
		if str(event.type) == event_type:
			count += 1
	return count

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _event_payloads(state, event_type: String) -> Array:
	var payloads := []
	for event in state.event_log:
		if str(event.type) != event_type or not (event.payload is Dictionary):
			continue
		payloads.append(event.payload.duplicate(true))
	return payloads

static func _last_event_payload(state, event_type: String) -> Dictionary:
	for index in range(state.event_log.size() - 1, -1, -1):
		var event = state.event_log[index]
		if str(event.type) == event_type and event.payload is Dictionary:
			return event.payload.duplicate(true)
	return {}

static func _resolve_pending_attack_window(engine, state, failures: Array[String], message: String) -> bool:
	if state.pending_attack.is_empty():
		return true
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, message, failures)
	if not bool(first_pass.get("ok", false)):
		return false
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, message, failures)
	if not bool(second_pass.get("ok", false)):
		return false
	return state.pending_attack.is_empty()

static func _targets_include_master(targets: Array, player_id: int) -> bool:
	for target in targets:
		if str(target.get("target_kind", "")) == "master" and int(target.get("target_player", -1)) == player_id:
			return true
	return false

static func _battlefield_count(state, player_id: int) -> int:
	var count := 0
	for slot in state.get_player(player_id).battle_front:
		if not str(slot.occupant).is_empty():
			count += 1
	for slot in state.get_player(player_id).battle_back:
		if not str(slot.occupant).is_empty():
			count += 1
	return count

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
