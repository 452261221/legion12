extends RefCounted
class_name TestClassicBatch3

const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEvent = preload("res://rules/core/game_event.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_forged_order_requires_a_movable_enemy_legion(failures)
	_test_forged_order_moves_enemy_legion_and_can_be_interrupted(failures)
	_test_frontline_scout_reveals_then_opens_paid_shuffle_flow(failures)
	_test_siege_catapult_effect_grants_normal_back_row_and_master_attacks(failures)
	_test_defensive_deployment_draws_after_setting_counters(failures)
	_test_universal_ring_entry_discards_with_choice_and_reveals_found_card(failures)
	_test_universal_ring_makes_neutral_grave_match_master_faction(failures)
	_test_grain_plunder_chooses_enemy_hand_and_draws(failures)
	_test_grain_plunder_triggers_on_truce_draw(failures)
	_test_grain_plunder_triggers_on_effect_tutor(failures)
	_test_black_lotus_can_become_morale_and_goes_to_grave_on_refund(failures)
	_test_desperate_resistance_only_activates_after_enemy_attack(failures)
	_test_desperate_resistance_can_decline_and_stay_set(failures)
	_test_desperate_resistance_can_choose_single_rested_target(failures)
	_test_desperate_resistance_can_hit_all_rested_targets(failures)
	_test_landlord_coercion_waits_for_manual_response_activation(failures)
	_test_landlord_coercion_forces_extra_discard_before_block(failures)
	_test_landlord_coercion_forces_extra_discard_before_support(failures)
	_test_landlord_coercion_can_cancel_support_when_discard_refused(failures)
	_test_fanatic_discarded_by_coercion_offers_free_prompt(failures)
	_test_fanatic_free_prompt_can_activate_morale_effect_without_spending_morale(failures)
	_test_fanatic_discarded_by_generic_effect_offers_free_prompt(failures)
	_test_poison_burst_triggers_on_enemy_legion_ready_by_effect(failures)
	_test_poison_burst_triggers_on_enemy_artifact_ready_by_effect(failures)
	_test_poison_burst_triggers_on_enemy_morale_ready_by_effect(failures)
	_test_poison_burst_ignores_ready_phase_morale_refresh(failures)
	_test_ruined_ritual_can_choose_enemy_discard_only(failures)
	_test_ruined_ritual_can_choose_blank_entry_only(failures)
	_test_ruined_ritual_ignores_enemy_hand_entry(failures)
	_test_sacred_shackle_requires_enemy_artifact(failures)
	_test_sacred_shackle_locks_enemy_artifact_and_can_be_released(failures)
	_test_sacred_shackle_discards_when_target_leaves_artifact_zone(failures)
	_test_sacred_shackle_discards_when_target_manifests_from_artifact_zone(failures)
	_test_sacred_shackle_blocks_triggered_artifact_effects_without_prompt(failures)
	_test_sacred_shackle_blocks_response_artifact_effects_from_actions(failures)
	_test_plague_infection_freezes_selected_legion(failures)
	_test_plague_infection_skips_enemy_morale_ready(failures)
	_test_nameless_infiltrator_can_deploy_to_enemy_field_and_self_destruct(failures)
	_test_luying_entry_tax_applies_on_deploy(failures)
	_test_luying_optional_prompt_describes_trigger_and_result(failures)
	_test_regency_authority_can_be_confirmed_to_deploy_and_go_to_grave(failures)
	_test_regency_authority_does_not_trigger_without_valid_hand_legion(failures)
	return failures

static func _test_forged_order_requires_a_movable_enemy_legion(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _forged_order_blocked_decks(), 3097, [], _formal_options(3))
	_advance_to_next_main(engine, state, failures, "forged order blocked test should advance to player 2 main")
	var enemy_front = _find_hand_card_by_definition(state, 1, "qa_plain")
	var enemy_back = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_front,
		"row": "front",
		"col": 0
	})).ok, "forged order blocked test should deploy the enemy front legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_back,
		"row": "back",
		"col": 0
	})).ok, "forged order blocked test should deploy the enemy back legion", failures)
	_advance_to_next_main(engine, state, failures, "forged order blocked test should return to player 1 main")
	var forged_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0010")
	_expect(forged_id != "", "forged order blocked test should draw 伪造密令", failures)
	_expect(engine.get_castable_tactic_effects(state, 0, forged_id).is_empty(), "forged order blocked test should hide the tactic when no enemy legion can move vertically", failures)

static func _test_forged_order_moves_enemy_legion_and_can_be_interrupted(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _forged_order_live_decks(), 3098, [], _formal_options(3))
	_advance_to_next_main(engine, state, failures, "forged order live test should advance to player 2 main")
	var enemy_legion = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_legion,
		"row": "front",
		"col": 0
	})).ok, "forged order live test should deploy the enemy legion", failures)
	var enemy_legion_id := str(state.get_player(1).battle_front[0].occupant)
	_advance_to_next_main(engine, state, failures, "forged order live test should return to player 1 main")
	var forged_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0010")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": forged_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "forged_order_move_enemy_units"
	})).ok, "forged order live test should play successfully when an enemy legion can move", failures)
	_resolve_top_stack(engine, state, failures, "forged order live test should resolve to the enemy move window")
	var move_choice = _pending_choice_by_operation(state, "forged_order_choose_enemy_move_card")
	_expect(move_choice != null, "forged order live test should open the special enemy move choice", failures)
	_expect(_resolve_candidate_choice_with_slot(engine, state, "forged_order_choose_enemy_move_card", [enemy_legion_id], "back", 0), "forged order live test should allow resolving the enemy move by direct drag payload", failures)
	var moved_enemy = state.card_instances.get(enemy_legion_id)
	_expect(moved_enemy != null and str(moved_enemy.position.get("row", "")) == "back" and int(moved_enemy.position.get("col", -1)) == 0, "forged order live test should move the enemy legion to the opposite row", failures)
	var second_choice = _pending_choice_by_operation(state, "forged_order_choose_enemy_move_card")
	_expect(second_choice == null, "forged order live test should stop asking for more moves when no second movable enemy legion remains", failures)
	_advance_to_next_main(engine, state, failures, "forged order interrupt test should rebuild a fresh main phase")
	_advance_to_next_main(engine, state, failures, "forged order interrupt test should return to player 1 main again")
	var enemy_legion_again = _find_hand_card_by_definition(state, 1, "qa_plain")
	if enemy_legion_again != "":
		_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
			"card_id": enemy_legion_again,
			"row": "front",
			"col": 1
		})).ok, "forged order interrupt test should deploy another enemy legion", failures)
		_advance_to_next_main(engine, state, failures, "forged order interrupt test should return to player 1 main with another target")
		var forged_again = _find_hand_card_by_definition(state, 0, "neutral_s01_0010")
		if forged_again != "":
			_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
				"card_id": forged_again,
				"row": "tactic",
				"col": -1,
				"effect_id": "forged_order_move_enemy_units"
			})).ok, "forged order interrupt test should cast a second forged order", failures)
			_resolve_top_stack(engine, state, failures, "forged order interrupt test should open the second move window")
			_expect(_pending_choice_by_operation(state, "forged_order_choose_enemy_move_card") != null, "forged order interrupt test should have a pending move choice before doing something else", failures)
			var ally_legion = _find_hand_card_by_definition(state, 0, "qa_vanilla")
			_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
				"card_id": ally_legion,
				"row": "front",
				"col": 0
			})).ok, "forged order interrupt test should allow another normal main-phase action while the move window is open", failures)
			_expect(_pending_choice_by_operation(state, "forged_order_choose_enemy_move_card") == null, "forged order interrupt test should close the move window once another action is taken", failures)

static func _test_frontline_scout_reveals_then_opens_paid_shuffle_flow(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _frontline_scout_decks(), 3099, [], _formal_options(3))
	var scout_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0013")
	_expect(scout_id != "", "frontline scout test should draw 前线侦查", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": scout_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "frontline_scout_reveal"
	})).ok, "frontline scout test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "frontline scout test should resolve to the reveal confirm choice")
	var confirm_choice = _pending_choice_by_operation(state, "frontline_scout_confirm_enemy_hand")
	_expect(confirm_choice != null, "frontline scout test should wait for the player to confirm the revealed enemy hand", failures)
	var viewed_event = _last_event_payload(state, "CardsViewedPrivately")
	_expect(viewed_event.get("card_ids", []).size() == state.get_player(1).hand.cards.size(), "frontline scout test should privately show all enemy hand cards", failures)
	_expect(_resolve_option_choice(engine, state, "frontline_scout_confirm_enemy_hand", "confirm"), "frontline scout test should accept the confirm button after viewing enemy hand", failures)
	var paid_choice = _pending_choice_by_operation(state, "resolve_option_with_shared_cost")
	_expect(paid_choice != null, "frontline scout test should open the paid follow-up option after confirming the hand view", failures)
	if paid_choice != null:
		var option_to_use := ""
		for option in paid_choice.get("options", []):
			var option_id := str(option.get("id", ""))
			if option_id != "skip":
				option_to_use = option_id
				break
		_expect(not option_to_use.is_empty(), "frontline scout test should offer a non-skip paid follow-up option", failures)
		if not option_to_use.is_empty():
			_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", option_to_use), "frontline scout test should allow paying 1 morale for the shuffle-back follow-up", failures)
	var enemy_choice = _pending_choice_by_operation(state, "return_hand_to_deck_bottom")
	_expect(enemy_choice != null and int(enemy_choice.get("player_id", -1)) == 1, "frontline scout test should make the opponent choose 1 hand card to shuffle back", failures)

static func _test_siege_catapult_effect_grants_normal_back_row_and_master_attacks(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _siege_catapult_decks(), 3100, [], _formal_options(2))
	_advance_to_next_main(engine, state, failures, "siege catapult test should advance to player 2 main")
	var enemy_legion = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_legion,
		"row": "back",
		"col": 0
	})).ok, "siege catapult test should let the enemy deploy a back-row legion", failures)
	var enemy_legion_id := str(state.get_player(1).battle_back[0].occupant)
	_advance_to_next_main(engine, state, failures, "siege catapult test should return to player 1 main")
	var catapult_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0003")
	_expect(catapult_id != "", "siege catapult test should draw 攻城投石车", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": catapult_id,
		"row": "back",
		"col": 0
	})).ok, "siege catapult test should deploy to the back row", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": catapult_id,
		"effect_id": "siege_catapult_backline_breach"
	})).ok, "siege catapult test should activate its effect", failures)
	_resolve_top_stack(engine, state, failures, "siege catapult test should resolve the attack permission effect")
	var targets = engine.get_legal_attack_targets(state, catapult_id)
	_expect(_has_card_attack_target(targets, enemy_legion_id), "siege catapult test should gain a normal attack target on the enemy back row", failures)
	_expect(_has_master_attack_target(targets, 1), "siege catapult test should gain a normal attack target on the enemy master", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": catapult_id,
		"target_kind": "card",
		"defender_id": enemy_legion_id
	})).ok, "siege catapult test should attack the enemy back-row legion through the normal attack command", failures)

static func _test_defensive_deployment_draws_after_setting_counters(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _defensive_deployment_decks(), 3108, [], _formal_options(6))
	var defensive_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0009")
	_expect(defensive_id != "", "defensive deployment test should draw 防御部署", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": defensive_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "defensive_deployment"
	})).ok, "defensive deployment test should play successfully", failures)
	_drain_stack_and_choices(engine, state, failures, "defensive deployment test should finish setting counters and resolving the follow-up draw")
	_expect(_player_has_battlefield_card(state, 0, "neutral_s02_0015"), "defensive deployment test should set the chosen counter tactic onto the battlefield first", failures)
	_expect(state.get_player(0).hand.cards.size() == 5, "defensive deployment test should draw only after the counter tactic leaves hand and drops the hand size to 4", failures)

static func _test_universal_ring_entry_discards_with_choice_and_reveals_found_card(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["neutral_s02_0008", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_plain", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31221, [], _formal_options(6))
	var ring_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0008")
	_expect(ring_id != "", "universal ring entry test should draw 万物统御之戒", failures)
	if ring_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ring_id,
		"row": "artifact",
		"col": -1
	})).ok, "universal ring entry test should play 万物统御之戒 successfully", failures)
	_resolve_top_stack(engine, state, failures, "universal ring entry test should resolve the entry trigger into the optional prompt")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "universal ring entry test should allow confirming the optional discard-and-search effect", failures)
	var discard_choice = _pending_choice_by_operation(state, "discard_from_hand")
	_expect(discard_choice != null and int(discard_choice.get("player_id", -1)) == 0, "universal ring entry test should ask the controller to choose a hand card to discard", failures)
	if discard_choice == null:
		return
	var discard_candidates = discard_choice.get("candidate_card_ids", [])
	_expect(discard_candidates is Array and not discard_candidates.is_empty(), "universal ring entry test should offer discard candidates from hand", failures)
	if not (discard_candidates is Array) or discard_candidates.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [str(discard_candidates[0])]
	})).ok, "universal ring entry test should allow confirming the discard choice", failures)
	var search_choice = _pending_choice_by_operation(state, "search_deck")
	_expect(search_choice != null, "universal ring entry test should open a deck search after paying the discard cost", failures)
	if search_choice == null:
		return
	var picked_id := ""
	for raw_card_id in search_choice.get("candidate_card_ids", []):
		var candidate_id := str(raw_card_id)
		var candidate_instance = state.card_instances.get(candidate_id)
		var candidate_definition = state.get_definition(candidate_instance.definition_id) if candidate_instance != null else null
		if candidate_definition != null and str(candidate_definition.id) == "qa_plain":
			picked_id = candidate_id
			break
	if picked_id.is_empty():
		var candidate_card_ids = search_choice.get("candidate_card_ids", [])
		if candidate_card_ids is Array and not candidate_card_ids.is_empty():
			picked_id = str(candidate_card_ids[0])
	_expect(not picked_id.is_empty(), "universal ring entry test should find a searchable neutral card to add to hand", failures)
	if picked_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(search_choice.get("choice_id", "")),
		"selected_card_ids": [picked_id]
	})).ok, "universal ring entry test should allow choosing the searched neutral card", failures)
	var reveal_payload = _last_event_payload(state, "CardsRevealedToOpponent")
	var revealed_ids = reveal_payload.get("card_ids", [])
	_expect(revealed_ids is Array and revealed_ids.has(picked_id), "universal ring entry test should reveal the added neutral card to the opponent", failures)
	_expect(state.get_player(0).hand.cards.has(picked_id), "universal ring entry test should add the revealed neutral card to hand", failures)
	_expect(_has_event_type(state, "DeckShuffled"), "universal ring entry test should shuffle the deck after the search resolves", failures)

static func _test_universal_ring_makes_neutral_grave_match_master_faction(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["neutral_s02_0008", "asgard_s01_0318", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31222, [], _formal_options(6))
	state.get_player(0).master_definition_id = "asgard_s01_03m1"
	var ring_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0008")
	var valkyrie_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0318")
	var neutral_legion_id = _find_hand_card_by_definition(state, 0, "qa_plain")
	_expect(ring_id != "" and valkyrie_id != "" and neutral_legion_id != "", "universal ring faction test should draw the ring, 女武神的召唤 and a neutral legion", failures)
	if ring_id == "" or valkyrie_id == "" or neutral_legion_id == "":
		return
	var player = state.get_player(0)
	player.hand.remove_card(neutral_legion_id)
	player.grave.add_card_to_top(neutral_legion_id)
	var neutral_instance = state.card_instances.get(neutral_legion_id)
	if neutral_instance != null:
		neutral_instance.zone = "grave"
	var grave_matches_before = engine._matching_grave_card_ids(state, 0, {"type": "legion", "faction": "asgard", "max_target_cost": 5})
	_expect(not grave_matches_before.has(neutral_legion_id), "universal ring faction test should not treat the neutral grave legion as 阿斯加德 before the ring enters the artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ring_id,
		"row": "artifact",
		"col": -1
	})).ok, "universal ring faction test should play 万物统御之戒 successfully", failures)
	_resolve_top_stack(engine, state, failures, "universal ring faction test should resolve the entry trigger into the optional prompt")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "universal ring faction test should allow declining the entry discard-and-search effect", failures)
	var grave_matches_after = engine._matching_grave_card_ids(state, 0, {"type": "legion", "faction": "asgard", "max_target_cost": 5})
	_expect(grave_matches_after.has(neutral_legion_id), "universal ring faction test should treat the neutral grave legion as 阿斯加德 while the ring is in the artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": valkyrie_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "valkyrie_call"
	})).ok, "universal ring faction test should let 女武神的召唤 be played", failures)
	_resolve_top_stack(engine, state, failures, "universal ring faction test should resolve 女武神的召唤 into a revive choice")
	var revive_choice = _pending_choice_by_operation(state, "revive_from_grave")
	_expect(revive_choice != null, "universal ring faction test should create a revive choice that includes the neutral legion", failures)
	if revive_choice == null:
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(revive_choice.get("choice_id", "")),
		"selected_card_ids": [neutral_legion_id]
	})).ok, "universal ring faction test should allow selecting the neutral legion as the revive target", failures)
	var slot_choice = _pending_choice_by_operation(state, "revive_selected_grave_to_slot")
	_expect(slot_choice != null, "universal ring faction test should ask for the revived neutral legion's slot", failures)
	if slot_choice == null:
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(slot_choice.get("choice_id", "")),
		"selected_option": "front:0"
	})).ok, "universal ring faction test should allow placing the revived neutral legion onto the battlefield", failures)
	var revived_instance = state.card_instances.get(neutral_legion_id)
	_expect(revived_instance != null and str(revived_instance.zone).begins_with("battle_"), "universal ring faction test should revive the neutral legion to the battlefield", failures)
	_expect(revived_instance != null and str(revived_instance.orientation) == "active", "universal ring faction test should revive the neutral legion in active orientation", failures)

static func _test_grain_plunder_chooses_enemy_hand_and_draws(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _grain_plunder_decks(), 3111, [], _formal_options(6))
	var grain_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0017")
	_expect(grain_id != "", "grain plunder test should draw 粮草掠夺", failures)
	if grain_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, grain_id, 0, "test_grain_plunder_set").is_empty(), "grain plunder test should be able to set 粮草掠夺 onto the battlefield", failures)
	var own_hand_before_draw := state.get_player(0).hand.cards.size()
	_advance_to_next_main(engine, state, failures, "grain plunder test should advance to the opponent main phase")
	var enemy_bouncer_id = _find_hand_card_by_definition(state, 1, "qa_bouncer")
	var enemy_target_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(enemy_bouncer_id != "", "grain plunder test should draw QA 回响使 for the opponent", failures)
	_expect(enemy_target_id != "", "grain plunder test should draw a bounce target for the opponent", failures)
	if enemy_bouncer_id.is_empty() or enemy_target_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_bouncer_id,
		"row": "front",
		"col": 0
	})).ok, "grain plunder test should let the opponent deploy QA 回响使", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_target_id,
		"row": "front",
		"col": 1
	})).ok, "grain plunder test should let the opponent deploy the return target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": enemy_bouncer_id,
		"effect_id": "bounce_unit",
		"target_card_id": enemy_target_id
	})).ok, "grain plunder test should let the opponent bounce its own battlefield card to hand", failures)
	_resolve_top_stack(engine, state, failures, "grain plunder test should resolve the enemy bounce effect first")
	var activate_action = _find_activate_action(engine.get_legal_actions(state, 0), grain_id, "supply_raid")
	_expect(not activate_action.is_empty(), "grain plunder test should expose an activation after the opponent returns a card to hand by effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": grain_id,
		"effect_id": "supply_raid"
	})).ok, "grain plunder test should let the controller activate 粮草掠夺", failures)
	_resolve_top_stack(engine, state, failures, "grain plunder test should resolve to the enemy-hand selection choice")
	var hand_choice = _pending_choice_by_operation(state, "return_enemy_hand_to_deck_top")
	_expect(hand_choice != null and int(hand_choice.get("player_id", -1)) == 0, "grain plunder test should let player 1 choose from the opponent hand", failures)
	if hand_choice == null:
		return
	var hand_context: Dictionary = hand_choice.get("context", {})
	_expect(int(hand_context.get("target_hand_player_id", -1)) == 1, "grain plunder test should keep the enemy hand owner in choice context", failures)
	_expect(bool(hand_context.get("allow_hidden_hand_highlight", false)), "grain plunder test should mark the choice as allowing hidden enemy-hand highlights", failures)
	var enemy_hand_cards: Array = state.get_player(1).hand.cards.duplicate()
	var candidate_ids: Array = hand_choice.get("candidate_card_ids", [])
	_expect(candidate_ids.size() == enemy_hand_cards.size(), "grain plunder test should highlight all opponent hand cards as candidates", failures)
	for enemy_card_id in enemy_hand_cards:
		_expect(candidate_ids.has(enemy_card_id), "grain plunder test should keep every opponent hand card selectable", failures)
	var returned_id := str(candidate_ids[0]) if not candidate_ids.is_empty() else ""
	_expect(not returned_id.is_empty(), "grain plunder test should have at least one opponent hand card to return", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(hand_choice.get("choice_id", "")),
		"selected_card_ids": [returned_id]
	})).ok, "grain plunder test should resolve the enemy-hand selection", failures)
	_expect(not state.get_player(1).hand.cards.has(returned_id), "grain plunder test should remove the chosen card from the opponent hand", failures)
	_expect(not state.get_player(1).deck.cards.is_empty() and str(state.get_player(1).deck.cards[0]) == returned_id, "grain plunder test should put the chosen opponent hand card on top of its owner's deck", failures)
	_expect(state.get_player(0).hand.cards.size() == own_hand_before_draw + 1, "grain plunder test should have the controller draw 1 after returning the enemy hand card", failures)

static func _test_grain_plunder_triggers_on_truce_draw(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _grain_plunder_truce_decks(), 3113, [], _formal_options(6))
	var grain_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0017")
	_expect(grain_id != "", "grain plunder truce test should draw 粮草掠夺", failures)
	if grain_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, grain_id, 0, "test_grain_truce_set").is_empty(), "grain plunder truce test should set 粮草掠夺 onto the battlefield", failures)
	_advance_to_next_main(engine, state, failures, "grain plunder truce test should advance to the opponent main phase")
	var truce_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0015")
	_expect(truce_id != "", "grain plunder truce test should draw 议和谈判", failures)
	if truce_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": truce_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "truce_offer"
	})).ok, "grain plunder truce test should let the opponent play 议和谈判", failures)
	_resolve_top_stack(engine, state, failures, "grain plunder truce test should resolve the truce effect into the opponent decision")
	var truce_choice = _pending_choice_by_operation(state, "truce_offer")
	_expect(truce_choice != null, "grain plunder truce test should open the truce decision choice", failures)
	_expect(_resolve_option_choice(engine, state, "truce_offer", "decline"), "grain plunder truce test should allow declining the extra shared draw", failures)
	var activate_action = _find_activate_action(engine.get_legal_actions(state, 0), grain_id, "supply_raid")
	_expect(not activate_action.is_empty(), "grain plunder truce test should expose 粮草掠夺 after the opponent draws from 议和谈判", failures)

static func _test_grain_plunder_triggers_on_effect_tutor(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _grain_plunder_tutor_decks(), 3118, [], _formal_options(2))
	var grain_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0017")
	_expect(grain_id != "", "grain plunder tutor test should draw 粮草掠夺", failures)
	if grain_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, grain_id, 0, "test_grain_tutor_set").is_empty(), "grain plunder tutor test should set 粮草掠夺 onto the battlefield", failures)
	_advance_to_next_main(engine, state, failures, "grain plunder tutor test should advance to the opponent main phase")
	var scout_id = _find_hand_card_by_definition(state, 1, "qa_scout")
	_expect(scout_id != "", "grain plunder tutor test should draw QA 侦查兵", failures)
	if scout_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": scout_id,
		"row": "front",
		"col": 0
	})).ok, "grain plunder tutor test should let the opponent deploy QA 侦查兵", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": scout_id,
		"effect_id": "search_legion"
	})).ok, "grain plunder tutor test should let QA 侦查兵 activate its deck search effect", failures)
	_resolve_top_stack(engine, state, failures, "grain plunder tutor test should resolve the scout search into a deck choice")
	var search_choice = _pending_choice_by_operation(state, "search_deck")
	_expect(search_choice != null, "grain plunder tutor test should open the deck search choice", failures)
	if search_choice == null:
		return
	var tutor_target = str(search_choice.get("candidate_card_ids", [])[0]) if search_choice.get("candidate_card_ids", []) is Array and not search_choice.get("candidate_card_ids", []).is_empty() else ""
	_expect(tutor_target != "", "grain plunder tutor test should offer a searchable legion target", failures)
	if tutor_target.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(search_choice.get("choice_id", "")),
		"selected_card_ids": [tutor_target]
	})).ok, "grain plunder tutor test should let the opponent finish the deck search", failures)
	var activate_action = _find_activate_action(engine.get_legal_actions(state, 0), grain_id, "supply_raid_tutored")
	_expect(not activate_action.is_empty(), "grain plunder tutor test should expose 粮草掠夺 after the opponent searches a card into hand by effect", failures)


static func _test_black_lotus_can_become_morale_and_goes_to_grave_on_refund(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _black_lotus_decks(), 3112, [], _formal_options(6))
	var lotus_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0010")
	_expect(lotus_id != "", "black lotus test should draw 黑色莲花", failures)
	if lotus_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": lotus_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "black_lotus_raise_calamity"
	})).ok, "black lotus test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "black lotus test should resolve the calamity change and open the optional morale choice")
	_expect(int(state.calamity_value) == 1, "black lotus test should increase the calamity value by 1 first", failures)
	var paid_choice = _pending_choice_by_operation(state, "resolve_option_with_shared_cost")
	_expect(paid_choice != null, "black lotus test should open the follow-up optional pay-3-morale choice", failures)
	if paid_choice == null:
		return
	var lotus_instance = state.card_instances.get(lotus_id)
	_expect(lotus_instance != null and str(lotus_instance.zone) == "stack_pending", "black lotus test should remain pending until the optional morale choice is decided", failures)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "move_to_morale"), "black lotus test should allow paying 3 morale to move itself into the morale area", failures)
	lotus_instance = state.card_instances.get(lotus_id)
	_expect(lotus_instance != null and str(lotus_instance.zone) == "spent_cost_area", "black lotus test should become a spent morale card after the paid follow-up", failures)
	_expect(not state.get_player(0).spent_cost_area.cards.is_empty() and str(state.get_player(0).spent_cost_area.cards[0]) == lotus_id, "black lotus test should stay on top of the spent morale area after moving there", failures)
	_expect(lotus_instance != null and bool(lotus_instance.flags.get("grave_when_leaving_morale", false)), "black lotus test should mark itself to enter grave when refunded as morale", failures)
	var refund_all := MoraleActions.count_spent_morale(state, 0)
	_expect(refund_all > 0, "black lotus test should create at least one spent morale to refund", failures)
	var refund_result = engine._pay_effect_costs(state, 0, {"cost": {"refund_morale": refund_all}}, "test_black_lotus_refund")
	_expect(refund_result.get("events", []).size() > 0, "black lotus test should allow refunding spent morale as a cost", failures)
	lotus_instance = state.card_instances.get(lotus_id)
	_expect(lotus_instance != null and str(lotus_instance.zone) == "grave", "black lotus test should go to grave instead of returning to the morale area when refunded", failures)
	_expect(state.get_player(0).grave.cards.has(lotus_id), "black lotus test should end up in its owner's grave after refund", failures)
	_expect(not state.get_player(0).cost_area.cards.has(lotus_id), "black lotus test should not remain in the active morale area after refund", failures)

static func _test_desperate_resistance_only_activates_after_enemy_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _desperate_resistance_decks(), 31135, [], _formal_options(6))
	var desperate_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0017")
	_expect(desperate_id != "", "desperate resistance timing test should draw 拼死反抗", failures)
	if desperate_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, desperate_id, 0, "test_desperate_timing_set").is_empty(), "desperate resistance timing test should set 拼死反抗", failures)
	_advance_to_next_main(engine, state, failures, "desperate resistance timing test should advance to the opponent main phase")
	var before_attack_action = _find_activate_action(engine.get_legal_actions(state, 0), desperate_id, "desperate_resistance")
	_expect(before_attack_action.is_empty(), "desperate resistance timing test should not offer activation before the opponent attacks", failures)
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(attacker_id != "", "desperate resistance timing test should draw the attacker", failures)
	if attacker_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "desperate resistance timing test should deploy the attacker", failures)
	var attacker_instance = state.card_instances.get(attacker_id)
	if attacker_instance != null:
		attacker_instance.entered_turn = state.turn_number - 1
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_player": 0
	})).ok, "desperate resistance timing test should allow the enemy attack", failures)
	var during_attack_action = _find_activate_action(engine.get_legal_actions(state, 0), desperate_id, "desperate_resistance")
	_expect(during_attack_action.is_empty(), "desperate resistance timing test should not offer activation while the attack is still pending", failures)
	_resolve_pending_attack(engine, state, failures, "desperate resistance timing test first priority pass should succeed", "desperate resistance timing test second priority pass should finish the attack and queue the trigger")
	_expect(state.pending_attack.is_empty(), "desperate resistance timing test should clear the pending attack after combat finishes", failures)
	_expect(_pending_choice_by_operation(state, "pre_stack_optional_attack_trigger") != null, "desperate resistance timing test should ask whether to respond after combat finishes", failures)
	var after_finish_action = _find_activate_action(engine.get_legal_actions(state, 0), desperate_id, "desperate_resistance")
	_expect(after_finish_action.is_empty(), "desperate resistance timing test should not expose 拼死反抗 as a manual activation after combat finishes", failures)

static func _test_desperate_resistance_can_decline_and_stay_set(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _desperate_resistance_decks(), 31136, [], _formal_options(6))
	var desperate_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0017")
	_expect(desperate_id != "", "desperate resistance decline test should draw 拼死反抗", failures)
	if desperate_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, desperate_id, 0, "test_desperate_decline_set").is_empty(), "desperate resistance decline test should set 拼死反抗", failures)
	_advance_to_next_main(engine, state, failures, "desperate resistance decline test should advance to the opponent main phase")
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(attacker_id != "", "desperate resistance decline test should draw the attacker", failures)
	if attacker_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "desperate resistance decline test should deploy the attacker", failures)
	var attacker_instance = state.card_instances.get(attacker_id)
	if attacker_instance != null:
		attacker_instance.entered_turn = state.turn_number - 1
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_player": 0
	})).ok, "desperate resistance decline test should allow the enemy attack", failures)
	_resolve_pending_attack(engine, state, failures, "desperate resistance decline test first priority pass should succeed", "desperate resistance decline test second priority pass should finish the attack and offer the trigger")
	_expect(_pending_choice_by_operation(state, "pre_stack_optional_attack_trigger") != null, "desperate resistance decline test should ask whether to respond", failures)
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "no"), "desperate resistance decline test should allow declining the response", failures)
	_expect(state.stack.is_empty(), "desperate resistance decline test should keep the stack empty after declining", failures)
	_expect(state.get_player(0).grave.cards.has(desperate_id) == false, "desperate resistance decline test should not send 拼死反抗 to grave when declining", failures)
	_expect(str(state.get_player(0).battle_back[0].occupant) == desperate_id, "desperate resistance decline test should keep 拼死反抗 set on the battlefield", failures)

static func _test_desperate_resistance_can_choose_single_rested_target(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _desperate_resistance_decks(), 3114, [], _formal_options(6))
	var desperate_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0017")
	_expect(desperate_id != "", "desperate resistance single test should draw 拼死反抗", failures)
	if desperate_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, desperate_id, 0, "test_desperate_set").is_empty(), "desperate resistance single test should set 拼死反抗", failures)
	_advance_to_next_main(engine, state, failures, "desperate resistance single test should advance to the opponent main phase")
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	var rested_target_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(attacker_id != "" and rested_target_id != "", "desperate resistance single test should draw the attacker and rested target", failures)
	if attacker_id.is_empty() or rested_target_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "desperate resistance single test should deploy the attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": rested_target_id,
		"row": "back",
		"col": 0
	})).ok, "desperate resistance single test should deploy the future debuff target", failures)
	var attacker_instance = state.card_instances.get(attacker_id)
	var rested_target = state.card_instances.get(rested_target_id)
	if attacker_instance != null:
		attacker_instance.entered_turn = state.turn_number - 1
	if rested_target != null:
		rested_target.orientation = "rested"
	var power_before = engine.get_card_power(state, rested_target_id)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_player": 0
	})).ok, "desperate resistance single test should allow the enemy attack", failures)
	_resolve_pending_attack(engine, state, failures, "desperate resistance single test first priority pass should succeed", "desperate resistance single test second priority pass should finish the attack and queue the trigger")
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "desperate resistance single test should allow confirming the response", failures)
	_expect(not state.stack.is_empty(), "desperate resistance single test should put 拼死反抗 onto the stack after confirming", failures)
	_resolve_top_stack(engine, state, failures, "desperate resistance single test should resolve to the option choice")
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "single_rested_minus_2000"), "desperate resistance single test should allow choosing the single-target branch", failures)
	var target_choice = _pending_choice_by_operation(state, "modify_power_until_next_own_turn_end")
	_expect(target_choice != null, "desperate resistance single test should request a rested enemy legion target", failures)
	if target_choice == null:
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(target_choice.get("choice_id", "")),
		"selected_card_ids": [rested_target_id]
	})).ok, "desperate resistance single test should allow selecting the rested enemy legion", failures)
	_expect(engine.get_card_power(state, rested_target_id) == max(0, power_before - 2000), "desperate resistance single test should reduce the chosen rested legion by 2000", failures)

static func _test_desperate_resistance_can_hit_all_rested_targets(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _desperate_resistance_all_decks(), 3115, [], _formal_options(6))
	var desperate_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0017")
	_expect(desperate_id != "", "desperate resistance all test should draw 拼死反抗", failures)
	if desperate_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, desperate_id, 0, "test_desperate_all_set").is_empty(), "desperate resistance all test should set 拼死反抗", failures)
	_advance_to_next_main(engine, state, failures, "desperate resistance all test should advance to the opponent main phase")
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	var rested_one = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	var rested_two = _find_nth_hand_card_by_definition(state, 1, "qa_vanilla", 2)
	_expect(attacker_id != "" and rested_one != "" and rested_two != "", "desperate resistance all test should draw the attacker and two rested targets", failures)
	if attacker_id.is_empty() or rested_one.is_empty() or rested_two.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "desperate resistance all test should deploy the attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": rested_one,
		"row": "back",
		"col": 0
	})).ok, "desperate resistance all test should deploy the first rested target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": rested_two,
		"row": "back",
		"col": 1
	})).ok, "desperate resistance all test should deploy the second rested target", failures)
	var attacker_instance = state.card_instances.get(attacker_id)
	var rested_one_instance = state.card_instances.get(rested_one)
	var rested_two_instance = state.card_instances.get(rested_two)
	if attacker_instance != null:
		attacker_instance.entered_turn = state.turn_number - 1
	if rested_one_instance != null:
		rested_one_instance.orientation = "rested"
	if rested_two_instance != null:
		rested_two_instance.orientation = "rested"
	var power_one_before = engine.get_card_power(state, rested_one)
	var power_two_before = engine.get_card_power(state, rested_two)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_player": 0
	})).ok, "desperate resistance all test should allow the enemy attack", failures)
	_resolve_pending_attack(engine, state, failures, "desperate resistance all test first priority pass should succeed", "desperate resistance all test second priority pass should finish the attack and queue the trigger")
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "desperate resistance all test should allow confirming the response", failures)
	_expect(not state.stack.is_empty(), "desperate resistance all test should put 拼死反抗 onto the stack after confirming", failures)
	_resolve_top_stack(engine, state, failures, "desperate resistance all test should resolve to the option choice")
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "all_rested_minus_1000"), "desperate resistance all test should allow choosing the all-target branch", failures)
	_expect(engine.get_card_power(state, rested_one) == max(0, power_one_before - 1000), "desperate resistance all test should reduce the first rested legion by 1000", failures)
	_expect(engine.get_card_power(state, rested_two) == max(0, power_two_before - 1000), "desperate resistance all test should reduce the second rested legion by 1000", failures)

static func _test_landlord_coercion_forces_extra_discard_before_block(failures: Array[String]) -> void:
	var setup = _setup_landlord_coercion_probe_state(31155, true, failures, "landlord coercion block test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var blocker_id := str(setup.get("secondary", ""))
	_trigger_landlord_coercion_probe(setup, true, failures, "landlord coercion block test")
	var discard_choice = _pending_choice_by_operation(state, "landlord_coercion_extra_discard")
	_expect(discard_choice != null and int(discard_choice.get("player_id", -1)) == 0, "landlord coercion block test should force the defender to handle the extra discard choice", failures)
	if discard_choice == null:
		return
	var discard_card = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(discard_card != "" and discard_card != blocker_id, "landlord coercion block test should keep a spare hand card for the extra discard", failures)
	if discard_card.is_empty() or discard_card == blocker_id:
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [discard_card]
	})).ok, "landlord coercion block test should allow paying the extra discard", failures)
	_expect(not state.get_player(0).hand.cards.has(discard_card), "landlord coercion block test should discard the chosen hand card before block resolves", failures)
	_expect(not state.pending_attack.is_empty() and str(state.pending_attack.get("blocker_id", "")) == blocker_id, "landlord coercion block test should keep the chosen block after the extra discard is paid", failures)

static func _test_landlord_coercion_waits_for_manual_response_activation(failures: Array[String]) -> void:
	var setup = _setup_landlord_coercion_probe_state(31118, false, failures, "landlord coercion manual response test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var defender_id := str(setup.get("defender", ""))
	var supporter_id := str(setup.get("secondary", ""))
	var coercion_id := str(setup.get("coercion", ""))
	var attacker_id := str(setup.get("attacker", ""))
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id
	})).ok, "landlord coercion manual response test should allow the attack", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ChooseDefense", {
		"supporter_id": supporter_id
	})).ok, "landlord coercion manual response test should allow choosing support first", failures)
	_expect(_pending_choice_by_operation(state, "landlord_coercion_extra_discard") == null, "landlord coercion manual response test should not auto-open the discard choice before the controller confirms activation", failures)
	_expect(not bool(state.pending_attack.get("extra_defense_discard_required", false)), "landlord coercion manual response test should not mark the extra discard as required before activation", failures)
	var actions = engine.get_legal_actions(state, 1)
	var found := false
	for action in actions:
		if str(action.get("command_type", "")) != "ActivateEffect":
			continue
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("source_id", "")) == coercion_id and str(payload.get("effect_id", "")) == "landlord_coercion":
			found = true
			break
	_expect(found, "landlord coercion manual response test should expose 地主的胁迫 as an optional response action", failures)

static func _test_landlord_coercion_forces_extra_discard_before_support(failures: Array[String]) -> void:
	var setup = _setup_landlord_coercion_probe_state(3116, false, failures, "landlord coercion discard test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var supporter_id := str(setup.get("secondary", ""))
	_trigger_landlord_coercion_probe(setup, false, failures, "landlord coercion discard test")
	var discard_choice = _pending_choice_by_operation(state, "landlord_coercion_extra_discard")
	_expect(discard_choice != null and int(discard_choice.get("player_id", -1)) == 0, "landlord coercion discard test should force the defender to handle the extra discard choice", failures)
	if discard_choice == null:
		return
	var discard_card = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(discard_card != "", "landlord coercion discard test should keep a spare hand card for the extra discard", failures)
	if discard_card.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [discard_card]
	})).ok, "landlord coercion discard test should allow paying the extra discard", failures)
	_expect(not state.get_player(0).hand.cards.has(discard_card), "landlord coercion discard test should discard the chosen hand card before support resolves", failures)
	_expect(not state.pending_attack.is_empty() and str(state.pending_attack.get("supporter_id", "")) == supporter_id, "landlord coercion discard test should keep the chosen support after the extra discard is paid", failures)

static func _test_landlord_coercion_can_cancel_support_when_discard_refused(failures: Array[String]) -> void:
	var setup = _setup_landlord_coercion_probe_state(3117, false, failures, "landlord coercion cancel test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var hand_before = state.get_player(0).hand.cards.size()
	_trigger_landlord_coercion_probe(setup, false, failures, "landlord coercion cancel test")
	var discard_choice = _pending_choice_by_operation(state, "landlord_coercion_extra_discard")
	_expect(discard_choice != null, "landlord coercion cancel test should force the defender to handle the extra discard choice", failures)
	if discard_choice == null:
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"cancelled": true
	})).ok, "landlord coercion cancel test should let the defender refuse the extra discard", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "landlord coercion cancel test should keep the defender hand unchanged when the extra discard is refused", failures)
	_expect(not state.pending_attack.is_empty() and str(state.pending_attack.get("supporter_id", "")) == "", "landlord coercion cancel test should invalidate the chosen support when the extra discard is refused", failures)

static func _test_fanatic_discarded_by_coercion_offers_free_prompt(failures: Array[String]) -> void:
	var setup = _setup_fanatic_coercion_state(31188, failures, "fanatic coercion prompt test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var fanatic_id := str(setup.get("fanatic_id", ""))
	var discard_choice_id := str(setup.get("discard_choice_id", ""))
	_expect(fanatic_id != "" and not discard_choice_id.is_empty(), "fanatic coercion prompt test should keep the discardable 信仰狂热者 and choice id", failures)
	if fanatic_id.is_empty() or discard_choice_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": discard_choice_id,
		"selected_card_ids": [fanatic_id]
	})).ok, "fanatic coercion prompt test should allow discarding 信仰狂热者 for 地主的胁迫", failures)
	_resolve_top_stack(engine, state, failures, "fanatic coercion prompt test should resolve the trigger stack item into the optional yes/no prompt")
	var optional_choice = _pending_choice_by_operation(state, "optional_stack_effect")
	_expect(optional_choice != null, "fanatic coercion prompt test should queue the optional free-effect trigger after 信仰狂热者 is discarded by effect", failures)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "fanatic coercion prompt test should allow confirming the optional free-effect trigger", failures)
	var player = state.get_player(0)
	_expect(int(player.flags.get("free_master_morale_effect_activation_turn", -1)) == state.turn_number, "fanatic coercion prompt test should mark the free activation as available this turn", failures)
	_expect(int(player.flags.get("free_master_morale_effect_activation_count", 0)) == 1, "fanatic coercion prompt test should grant exactly 1 free activation", failures)
	var free_action = _find_activate_action(engine.get_legal_actions(state, 0), "master_0", "yangjian_draw_then_put_back")
	_expect(not free_action.is_empty(), "fanatic coercion prompt test should expose a morale-cost master effect during the attack response window", failures)

static func _test_fanatic_free_prompt_can_activate_morale_effect_without_spending_morale(failures: Array[String]) -> void:
	var setup = _setup_fanatic_coercion_state(31189, failures, "fanatic free activation test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var fanatic_id := str(setup.get("fanatic_id", ""))
	var discard_choice_id := str(setup.get("discard_choice_id", ""))
	_expect(fanatic_id != "" and not discard_choice_id.is_empty(), "fanatic free activation test should keep the discardable 信仰狂热者 and choice id", failures)
	if fanatic_id.is_empty() or discard_choice_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": discard_choice_id,
		"selected_card_ids": [fanatic_id]
	})).ok, "fanatic free activation test should discard 信仰狂热者 to the coercion choice", failures)
	_resolve_top_stack(engine, state, failures, "fanatic free activation test should resolve the trigger stack item into the optional yes/no prompt")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "fanatic free activation test should accept the free activation prompt", failures)
	var morale_before := MoraleActions.count_active_morale(state, 0)
	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "yangjian_draw_then_put_back"
	}))
	_expect(activate_result.ok, "fanatic free activation test should allow activating the morale-cost master effect during the response window", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == morale_before, "fanatic free activation test should not spend morale for the free activation", failures)
	_expect(int(state.get_player(0).flags.get("free_master_morale_effect_activation_count", 0)) == 0, "fanatic free activation test should consume the one free activation charge", failures)
	_expect(not bool(state.get_player(0).once_per_turn.get("yangjian_draw_then_put_back", false)), "fanatic free activation test should not consume the normal master once-per-turn usage count", failures)

static func _test_fanatic_discarded_by_generic_effect_offers_free_prompt(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["qa_disruptor", "neutral_s02_0006", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		31190,
		[
			{"master_id": "tianting_s01_01m1", "master_name": "测试主宰A"},
			{"master_id": "tianting_s01_01m1", "master_name": "测试主宰B"}
		],
		_formal_options(6)
	)
	state.phase = "main"
	state.active_player = 0
	state.priority_player = 0
	state.turn_number = 1
	var disruptor_id = _find_hand_card_by_definition(state, 0, "qa_disruptor")
	var fanatic_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0006")
	_expect(disruptor_id != "" and fanatic_id != "", "fanatic generic discard test should draw QA 扰乱者和信仰狂热者", failures)
	if disruptor_id.is_empty() or fanatic_id.is_empty():
		return
	_expect(not engine._deploy_hand_card_to_slot(state, 0, disruptor_id, "front", 0, "test_fanatic_generic_discard_deploy").is_empty(), "fanatic generic discard test should deploy QA 扰乱者", failures)
	_expect(not state.get_player(0).hand.cards.is_empty() and str(state.get_player(0).hand.cards[0]) == fanatic_id, "fanatic generic discard test should keep 信仰狂热者 at the front of hand for the forced discard", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": disruptor_id,
		"effect_id": "discard_one"
	})).ok, "fanatic generic discard test should allow activating QA 扰乱者", failures)
	_resolve_top_stack(engine, state, failures, "fanatic generic discard test should resolve QA 扰乱者 to the discard result")
	var discard_payload = _last_event_payload(state, "CardDiscarded")
	_expect(str(discard_payload.get("card_id", "")) == fanatic_id, "fanatic generic discard test should discard 信仰狂热者 from hand", failures)
	_expect(str(discard_payload.get("source_kind", "")) == "effect", "fanatic generic discard test should mark the discard as effect-caused", failures)
	_expect(str(discard_payload.get("source_id", "")) == disruptor_id, "fanatic generic discard test should record the real effect source id on CardDiscarded", failures)
	_expect(str(discard_payload.get("source_card_id", "")) == disruptor_id, "fanatic generic discard test should keep the source card id for card effects", failures)
	_resolve_top_stack(engine, state, failures, "fanatic generic discard test should continue resolving into the 信仰狂热者 optional prompt")
	var optional_choice = _pending_choice_by_operation(state, "optional_stack_effect")
	_expect(optional_choice != null, "fanatic generic discard test should queue the free master prompt after a non-coercion effect discard", failures)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "fanatic generic discard test should allow accepting the free master prompt", failures)
	_expect(int(state.get_player(0).flags.get("free_master_morale_effect_activation_count", 0)) == 1, "fanatic generic discard test should grant exactly one free activation after a generic effect discard", failures)

static func _test_poison_burst_triggers_on_enemy_legion_ready_by_effect(failures: Array[String]) -> void:
	var setup = _setup_poison_burst_response_state(31190, ["qa_self_ready_legion", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"], failures, "poison burst legion test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var poison_id := str(setup.get("poison_id", ""))
	var target_id = _find_hand_card_by_definition(state, 1, "qa_self_ready_legion")
	_expect(target_id != "", "poison burst legion test should draw QA 自醒军团", failures)
	if target_id.is_empty():
		return
	_expect(not engine._deploy_hand_card_to_slot(state, 1, target_id, "front", 0, "test_poison_burst_legion_deploy").is_empty(), "poison burst legion test should deploy QA 自醒军团", failures)
	var target_instance = state.card_instances.get(target_id)
	if target_instance != null:
		target_instance.orientation = "rested"
	var enemy_hand_before: int = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": target_id,
		"effect_id": "qa_self_ready_legion_activate"
	})).ok, "poison burst legion test should allow the enemy legion to ready itself by effect", failures)
	_resolve_top_stack(engine, state, failures, "poison burst legion test should resolve the ready effect and open the response window")
	_expect(not _find_activate_action(engine.get_legal_actions(state, 0), poison_id, "poison_burst").is_empty(), "poison burst legion test should expose 毒药发作 after an enemy legion readies by effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": poison_id,
		"effect_id": "poison_burst"
	})).ok, "poison burst legion test should allow activating 毒药发作 in response to the ready event", failures)
	_resolve_top_stack(engine, state, failures, "poison burst legion test should resolve 毒药发作 into the enemy discard choice")
	var discard_choice = _pending_choice_by_operation(state, "discard_from_hand")
	_expect(discard_choice != null and int(discard_choice.get("player_id", -1)) == 1, "poison burst legion test should force the readied legion controller to choose a hand card to discard", failures)
	if discard_choice == null:
		return
	var discard_candidates = discard_choice.get("candidate_card_ids", [])
	_expect(discard_candidates is Array and not discard_candidates.is_empty(), "poison burst legion test should offer at least one enemy hand card to discard", failures)
	if not (discard_candidates is Array) or discard_candidates.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [str(discard_candidates[0])]
	})).ok, "poison burst legion test should allow the opponent to confirm the discard", failures)
	_drain_stack_and_choices(engine, state, failures, "poison burst legion test should finish resolving the discard choice")
	target_instance = state.card_instances.get(target_id)
	_expect(target_instance != null and str(target_instance.orientation) == "rested", "poison burst legion test should return the enemy legion to rested after countering the ready effect", failures)
	_expect(state.get_player(1).hand.cards.size() == enemy_hand_before - 1, "poison burst legion test should force the enemy to discard 1 card", failures)

static func _test_poison_burst_triggers_on_enemy_artifact_ready_by_effect(failures: Array[String]) -> void:
	var setup = _setup_poison_burst_response_state(31191, ["qa_self_ready_artifact", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"], failures, "poison burst artifact test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var poison_id := str(setup.get("poison_id", ""))
	var target_id = _find_hand_card_by_definition(state, 1, "qa_self_ready_artifact")
	_expect(target_id != "", "poison burst artifact test should draw QA 自醒圣物", failures)
	if target_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "artifact",
		"col": -1
	})).ok, "poison burst artifact test should let the opponent play QA 自醒圣物", failures)
	var target_instance = state.card_instances.get(target_id)
	if target_instance != null:
		target_instance.orientation = "rested"
	var enemy_hand_before: int = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": target_id,
		"effect_id": "qa_self_ready_artifact_activate"
	})).ok, "poison burst artifact test should allow the enemy artifact to ready itself by effect", failures)
	_resolve_top_stack(engine, state, failures, "poison burst artifact test should resolve the artifact ready effect and open the response window")
	_expect(not _find_activate_action(engine.get_legal_actions(state, 0), poison_id, "poison_burst").is_empty(), "poison burst artifact test should expose 毒药发作 after an enemy artifact readies by effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": poison_id,
		"effect_id": "poison_burst"
	})).ok, "poison burst artifact test should allow responding to the enemy artifact ready event", failures)
	_resolve_top_stack(engine, state, failures, "poison burst artifact test should resolve 毒药发作 into the enemy discard choice")
	var discard_choice = _pending_choice_by_operation(state, "discard_from_hand")
	_expect(discard_choice != null and int(discard_choice.get("player_id", -1)) == 1, "poison burst artifact test should force the readied artifact controller to choose a hand card to discard", failures)
	if discard_choice == null:
		return
	var discard_candidates = discard_choice.get("candidate_card_ids", [])
	_expect(discard_candidates is Array and not discard_candidates.is_empty(), "poison burst artifact test should offer at least one enemy hand card to discard", failures)
	if not (discard_candidates is Array) or discard_candidates.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [str(discard_candidates[0])]
	})).ok, "poison burst artifact test should allow the opponent to confirm the discard", failures)
	_drain_stack_and_choices(engine, state, failures, "poison burst artifact test should finish resolving the discard choice")
	target_instance = state.card_instances.get(target_id)
	_expect(target_instance != null and str(target_instance.orientation) == "rested", "poison burst artifact test should return the enemy artifact to rested after the response resolves", failures)
	_expect(state.get_player(1).hand.cards.size() == enemy_hand_before - 1, "poison burst artifact test should force the enemy to discard 1 card after the artifact ready is negated", failures)

static func _test_poison_burst_triggers_on_enemy_morale_ready_by_effect(failures: Array[String]) -> void:
	var setup = _setup_poison_burst_response_state(31192, ["qa_ready_spent_morale_tactic", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"], failures, "poison burst morale test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var poison_id := str(setup.get("poison_id", ""))
	var morale_tactic_id = _find_hand_card_by_definition(state, 1, "qa_ready_spent_morale_tactic")
	_expect(morale_tactic_id != "", "poison burst morale test should draw QA 复苏士气", failures)
	if morale_tactic_id.is_empty():
		return
	MoraleActions.consume_morale(state, 1, 1, "test_poison_burst_seed_spent_morale")
	var enemy_hand_before: int = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": morale_tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "qa_ready_one_spent_morale"
	})).ok, "poison burst morale test should let the opponent play QA 复苏士气", failures)
	_resolve_top_stack(engine, state, failures, "poison burst morale test should resolve the morale-readying tactic and open the response window")
	var active_after_ready := MoraleActions.count_active_morale(state, 1)
	var spent_after_ready := MoraleActions.count_spent_morale(state, 1)
	var readied_payload := _last_event_payload(state, "MoraleReadied")
	_expect(not _find_activate_action(engine.get_legal_actions(state, 0), poison_id, "poison_burst").is_empty(), "poison burst morale test should expose 毒药发作 after the enemy readies spent morale by effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": poison_id,
		"effect_id": "poison_burst"
	})).ok, "poison burst morale test should allow responding to the enemy morale ready event", failures)
	_resolve_top_stack(engine, state, failures, "poison burst morale test should resolve 毒药发作 into the enemy discard choice")
	var discard_choice = _pending_choice_by_operation(state, "discard_from_hand")
	_expect(discard_choice != null and int(discard_choice.get("player_id", -1)) == 1, "poison burst morale test should force the morale-ready controller to choose a hand card to discard", failures)
	if discard_choice == null:
		return
	var discard_candidates = discard_choice.get("candidate_card_ids", [])
	_expect(discard_candidates is Array and not discard_candidates.is_empty(), "poison burst morale test should offer at least one enemy hand card to discard", failures)
	if not (discard_candidates is Array) or discard_candidates.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [str(discard_candidates[0])]
	})).ok, "poison burst morale test should allow the opponent to confirm the discard", failures)
	_drain_stack_and_choices(engine, state, failures, "poison burst morale test should finish resolving the discard choice")
	_expect(MoraleActions.count_active_morale(state, 1) == active_after_ready - 1, "poison burst morale test should undo the newly readied morale", failures)
	_expect(MoraleActions.count_spent_morale(state, 1) == spent_after_ready + 1, "poison burst morale test should send the readied morale back to spent area", failures)
	var morale_rested_payload := _last_event_payload(state, "MoraleRested")
	_expect(str(morale_rested_payload.get("card_id", "")) == str(readied_payload.get("card_id", "")), "poison burst morale test should revert the same morale card that was just readied", failures)
	_expect(state.get_player(1).hand.cards.size() == enemy_hand_before - 2, "poison burst morale test should still force the enemy to discard 1 card after the morale tactic leaves hand", failures)

static func _test_poison_burst_ignores_ready_phase_morale_refresh(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0018", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		31193,
		[],
		_formal_options(6)
	)
	var poison_definition = state.get_definition("neutral_s02_0018")
	_expect(poison_definition != null and not poison_definition.effects.is_empty(), "poison burst phase-ready test should load 毒药发作 definition", failures)
	if poison_definition == null or poison_definition.effects.is_empty():
		return
	var poison_effect: Dictionary = poison_definition.effects[0]
	var morale_id := str(state.get_player(1).cost_area.cards[0]) if not state.get_player(1).cost_area.cards.is_empty() else ""
	_expect(not morale_id.is_empty(), "poison burst phase-ready test should have at least one enemy morale card", failures)
	if morale_id.is_empty():
		return
	var effect_ready_event = GameEvent.create(state.next_event_id(), "MoraleReadied", 1, {
		"card_id": morale_id,
		"from_orientation": "rested",
		"source_kind": "effect"
	})
	var phase_ready_event = GameEvent.create(state.next_event_id(), "MoraleReadied", 1, {
		"card_id": morale_id,
		"from_orientation": "rested",
		"source_kind": "phase"
	})
	_expect(engine._source_event_matches_response_filters(state, effect_ready_event, 0, poison_effect), "poison burst phase-ready test should treat effect-driven morale ready as a valid response source", failures)
	_expect(not engine._source_event_matches_response_filters(state, phase_ready_event, 0, poison_effect), "poison burst phase-ready test should ignore ready-phase morale refresh", failures)

static func _test_ruined_ritual_can_choose_enemy_discard_only(failures: Array[String]) -> void:
	var setup = _setup_ruined_ritual_response_state(31194, failures, "ruined ritual non-hand entry test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var ritual_id := str(setup.get("ritual_id", ""))
	var revive_tactic_id := str(setup.get("revive_tactic_id", ""))
	var revived_legion_id := str(setup.get("revived_legion_id", ""))
	var enemy_hand_before: int = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": revive_tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "qa_revive_nonhand_entry_legion"
	})).ok, "ruined ritual non-hand entry test should let the opponent play the revive tactic", failures)
	_resolve_top_stack(engine, state, failures, "ruined ritual non-hand entry test should resolve the revive tactic into a revive choice")
	var revive_choice = _pending_choice_by_operation(state, "revive_from_grave")
	_expect(revive_choice != null and int(revive_choice.get("player_id", -1)) == 1, "ruined ritual non-hand entry test should ask the opponent to choose the grave legion to revive", failures)
	if revive_choice == null:
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(revive_choice.get("choice_id", "")),
		"selected_card_ids": [revived_legion_id]
	})).ok, "ruined ritual non-hand entry test should allow the opponent to confirm the revive target", failures)
	var slot_choice = _pending_choice_by_operation(state, "revive_selected_grave_to_slot")
	_expect(slot_choice != null and int(slot_choice.get("player_id", -1)) == 1, "ruined ritual non-hand entry test should ask the opponent to choose the revived legion's slot", failures)
	if slot_choice == null:
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(slot_choice.get("choice_id", "")),
		"selected_option": "front:0"
	})).ok, "ruined ritual non-hand entry test should allow the opponent to confirm the revived legion's slot", failures)
	_expect(not _find_activate_action(engine.get_legal_actions(state, 0), ritual_id, "ruined_ritual_counter_entry").is_empty(), "ruined ritual non-hand entry test should expose 破败仪式 after an enemy legion enters from a non-hand zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": ritual_id,
		"effect_id": "ruined_ritual_counter_entry"
	})).ok, "ruined ritual non-hand entry test should allow activating 破败仪式 in response to the non-hand entry", failures)
	_resolve_top_stack(engine, state, failures, "ruined ritual discard-mode test should resolve 破败仪式 into the mode choice")
	var mode_choice = _pending_choice_by_operation(state, "resolve_option_with_shared_cost")
	_expect(mode_choice != null and int(mode_choice.get("player_id", -1)) == 0, "ruined ritual discard-mode test should let the controller choose one branch", failures)
	if mode_choice == null:
		return
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "discard"), "ruined ritual discard-mode test should allow choosing the discard branch", failures)
	var discard_choice = _pending_choice_by_operation(state, "discard_from_hand")
	_expect(discard_choice != null and int(discard_choice.get("player_id", -1)) == 1, "ruined ritual discard-mode test should force the entering legion's controller to choose a hand card to discard", failures)
	if discard_choice == null:
		return
	var candidates = discard_choice.get("candidate_card_ids", [])
	_expect(candidates is Array and not candidates.is_empty(), "ruined ritual discard-mode test should provide at least one discard candidate", failures)
	if not (candidates is Array) or candidates.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(discard_choice.get("choice_id", "")),
		"selected_card_ids": [str(candidates[0])]
	})).ok, "ruined ritual discard-mode test should allow the opponent to confirm the discard", failures)
	_drain_stack_and_choices(engine, state, failures, "ruined ritual discard-mode test should finish resolving the chosen branch and remaining entry flow")
	var revived_instance = state.card_instances.get(revived_legion_id)
	_expect(revived_instance != null and str(revived_instance.zone).begins_with("battle_"), "ruined ritual discard-mode test should keep the revived legion on the battlefield", failures)
	_expect(engine.get_card_power(state, revived_legion_id) == 5000, "ruined ritual discard-mode test should not reduce the entering legion power when only the discard branch is chosen", failures)
	_expect(int(state.get_player(1).hand.cards.size()) == enemy_hand_before - 1, "ruined ritual discard-mode test should spend the revive tactic, discard one hand card, then let the entry draw resolve", failures)

static func _test_ruined_ritual_can_choose_blank_entry_only(failures: Array[String]) -> void:
	var setup = _setup_ruined_ritual_response_state(31196, failures, "ruined ritual blank-entry test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var ritual_id := str(setup.get("ritual_id", ""))
	var revive_tactic_id := str(setup.get("revive_tactic_id", ""))
	var revived_legion_id := str(setup.get("revived_legion_id", ""))
	var enemy_hand_before: int = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": revive_tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "qa_revive_nonhand_entry_legion"
	})).ok, "ruined ritual blank-entry test should let the opponent play the revive tactic", failures)
	_resolve_top_stack(engine, state, failures, "ruined ritual blank-entry test should resolve the revive tactic into a revive choice")
	var revive_choice = _pending_choice_by_operation(state, "revive_from_grave")
	_expect(revive_choice != null and int(revive_choice.get("player_id", -1)) == 1, "ruined ritual blank-entry test should ask the opponent to choose the grave legion to revive", failures)
	if revive_choice == null:
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(revive_choice.get("choice_id", "")),
		"selected_card_ids": [revived_legion_id]
	})).ok, "ruined ritual blank-entry test should allow the opponent to confirm the revive target", failures)
	var slot_choice = _pending_choice_by_operation(state, "revive_selected_grave_to_slot")
	_expect(slot_choice != null and int(slot_choice.get("player_id", -1)) == 1, "ruined ritual blank-entry test should ask the opponent to choose the revived legion's slot", failures)
	if slot_choice == null:
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(slot_choice.get("choice_id", "")),
		"selected_option": "front:0"
	})).ok, "ruined ritual blank-entry test should allow the opponent to confirm the revived legion's slot", failures)
	_expect(not _find_activate_action(engine.get_legal_actions(state, 0), ritual_id, "ruined_ritual_counter_entry").is_empty(), "ruined ritual blank-entry test should expose 破败仪式 after an enemy legion enters from a non-hand zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": ritual_id,
		"effect_id": "ruined_ritual_counter_entry"
	})).ok, "ruined ritual blank-entry test should allow activating 破败仪式 in response to the non-hand entry", failures)
	_resolve_top_stack(engine, state, failures, "ruined ritual blank-entry test should resolve 破败仪式 into the mode choice")
	var mode_choice = _pending_choice_by_operation(state, "resolve_option_with_shared_cost")
	_expect(mode_choice != null and int(mode_choice.get("player_id", -1)) == 0, "ruined ritual blank-entry test should let the controller choose one branch", failures)
	if mode_choice == null:
		return
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "blank_entry"), "ruined ritual blank-entry test should allow choosing the entry-suppression branch", failures)
	_expect(_pending_choice_by_operation(state, "discard_from_hand") == null, "ruined ritual blank-entry test should not ask for a discard after choosing the entry-suppression branch", failures)
	_drain_stack_and_choices(engine, state, failures, "ruined ritual blank-entry test should finish resolving the chosen branch and remaining entry flow")
	var revived_instance = state.card_instances.get(revived_legion_id)
	_expect(revived_instance != null and str(revived_instance.zone).begins_with("battle_"), "ruined ritual blank-entry test should keep the revived legion on the battlefield", failures)
	_expect(engine.get_card_power(state, revived_legion_id) == 2000, "ruined ritual blank-entry test should make the entering legion lose 3000 power this turn", failures)
	_expect(int(state.get_player(1).hand.cards.size()) == enemy_hand_before - 1, "ruined ritual blank-entry test should spend only the revive tactic because the entry draw is blanked and no discard branch was chosen", failures)

static func _test_ruined_ritual_ignores_enemy_hand_entry(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0016", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_nonhand_entry_draw_legion", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		31195,
		[],
		_formal_options(6)
	)
	var ritual_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0016")
	var enemy_legion_id = _find_hand_card_by_definition(state, 1, "qa_nonhand_entry_draw_legion")
	_expect(ritual_id != "" and enemy_legion_id != "", "ruined ritual hand-entry test should draw both setup cards", failures)
	if ritual_id.is_empty() or enemy_legion_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, ritual_id, 0, "test_ruined_ritual_set").is_empty(), "ruined ritual hand-entry test should set 破败仪式 onto the battlefield", failures)
	state.phase = "main"
	state.turn_number = 2
	state.active_player = 1
	state.priority_player = 1
	var enemy_hand_before: int = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_legion_id,
		"row": "front",
		"col": 0
	})).ok, "ruined ritual hand-entry test should let the opponent deploy the legion from hand", failures)
	_drain_stack_and_choices(engine, state, failures, "ruined ritual hand-entry test should finish resolving the normal hand-entry draw")
	_expect(_find_activate_action(engine.get_legal_actions(state, 0), ritual_id, "ruined_ritual_counter_entry").is_empty(), "ruined ritual hand-entry test should not expose 破败仪式 after a normal hand deployment", failures)
	_expect(int(state.get_player(1).hand.cards.size()) == enemy_hand_before, "ruined ritual hand-entry test should let the legion's hand-entry draw resolve normally", failures)

static func _test_sacred_shackle_requires_enemy_artifact(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0013", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		31191,
		[],
		_formal_options(6)
	)
	state.phase = "main"
	state.active_player = 0
	state.priority_player = 0
	state.turn_number = 1
	var shackle_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0013")
	_expect(shackle_id != "", "sacred shackle no-target test should draw 神圣枷锁", failures)
	if shackle_id.is_empty():
		return
	_expect(engine.get_castable_tactic_effects(state, 0, shackle_id).is_empty(), "sacred shackle no-target test should not be castable when the opponent has no artifact", failures)

static func _test_sacred_shackle_locks_enemy_artifact_and_can_be_released(failures: Array[String]) -> void:
	var setup = _setup_sacred_shackle_attached_state(31192, "tianting_s01_0117", failures, "sacred shackle release test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var target_id := str(setup.get("target_id", ""))
	var shackle_id := str(setup.get("shackle_id", ""))
	_expect(target_id != "" and shackle_id != "", "sacred shackle release test should keep both the target artifact and 神圣枷锁 ids", failures)
	if target_id.is_empty() or shackle_id.is_empty():
		return
	var shackle_instance = state.card_instances.get(shackle_id)
	_expect(shackle_instance != null and str(shackle_instance.zone) == "artifact_zone", "sacred shackle release test should place 神圣枷锁 into the enemy artifact zone", failures)
	_expect(shackle_instance != null and int(shackle_instance.controller) == 1, "sacred shackle release test should hand control of the attached tactic to the host artifact side", failures)
	_expect(shackle_instance != null and str(shackle_instance.flags.get("artifact_lock_target_id", "")) == target_id, "sacred shackle release test should record the locked artifact id on 神圣枷锁", failures)
	state.phase = "main"
	state.active_player = 1
	state.priority_player = 1
	state.turn_number = 3
	_expect(_find_activate_action(engine.get_legal_actions(state, 1), target_id, "shanhe_rested_choose_mode").is_empty(), "sacred shackle release test should stop the locked artifact from exposing its activated effect", failures)
	var release_action = _find_activate_action(engine.get_legal_actions(state, 1), shackle_id, "sacred_shackle_release")
	_expect(not release_action.is_empty(), "sacred shackle release test should let the opponent activate the attached 神圣枷锁", failures)
	var morale_before := MoraleActions.count_active_morale(state, 1)
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": shackle_id,
		"effect_id": "sacred_shackle_release"
	})).ok, "sacred shackle release test should allow paying 3 morale to discard 神圣枷锁", failures)
	_resolve_top_stack(engine, state, failures, "sacred shackle release test should resolve the self-release effect")
	_expect(MoraleActions.count_active_morale(state, 1) == morale_before - 3, "sacred shackle release test should spend exactly 3 morale", failures)
	_expect(state.get_player(0).grave.cards.has(shackle_id), "sacred shackle release test should send 神圣枷锁 to its owner's grave", failures)
	_expect(not state.get_player(1).artifact_zone.cards.has(shackle_id), "sacred shackle release test should remove 神圣枷锁 from the enemy artifact zone", failures)
	_expect(not _find_activate_action(engine.get_legal_actions(state, 1), target_id, "shanhe_rested_choose_mode").is_empty(), "sacred shackle release test should restore the target artifact activation after 神圣枷锁 is discarded", failures)

static func _test_sacred_shackle_discards_when_target_leaves_artifact_zone(failures: Array[String]) -> void:
	var setup = _setup_sacred_shackle_attached_state(31193, "tianting_s01_0117", failures, "sacred shackle leave-zone test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var target_id := str(setup.get("target_id", ""))
	var shackle_id := str(setup.get("shackle_id", ""))
	_expect(not engine._send_artifact_to_grave(state, 1, target_id, "test_sacred_shackle_target_leave").is_empty(), "sacred shackle leave-zone test should move the locked artifact out of artifact zone", failures)
	_expect(state.get_player(1).grave.cards.has(target_id), "sacred shackle leave-zone test should send the locked artifact to its controller grave", failures)
	_expect(state.get_player(0).grave.cards.has(shackle_id), "sacred shackle leave-zone test should discard 神圣枷锁 when the locked artifact leaves artifact zone", failures)
	_expect(not state.get_player(1).artifact_zone.cards.has(shackle_id), "sacred shackle leave-zone test should remove 神圣枷锁 from the artifact zone after cleanup", failures)

static func _test_sacred_shackle_discards_when_target_manifests_from_artifact_zone(failures: Array[String]) -> void:
	var setup = _setup_sacred_shackle_attached_state(31194, "takamagahara_s01_0417", failures, "sacred shackle manifest test setup should succeed")
	if setup.is_empty():
		return
	var engine: GameEngine = setup.engine
	var state = setup.state
	var target_id := str(setup.get("target_id", ""))
	var shackle_id := str(setup.get("shackle_id", ""))
	_expect(not engine._manifest_kusanagi_to_slot(state, 1, target_id, "front", 0, "test_sacred_shackle_manifest_leave").is_empty(), "sacred shackle manifest test should let 草薙剑 leave the artifact zone and manifest onto the battlefield", failures)
	_expect(str(state.get_player(1).battle_front[0].occupant) == target_id, "sacred shackle manifest test should move the locked 草薙剑 onto the battlefield", failures)
	_expect(state.get_player(0).grave.cards.has(shackle_id), "sacred shackle manifest test should discard 神圣枷锁 when the locked artifact leaves artifact zone to the battlefield", failures)
	_expect(not state.get_player(1).artifact_zone.cards.has(shackle_id), "sacred shackle manifest test should remove 神圣枷锁 from the artifact zone after manifest cleanup", failures)

static func _test_sacred_shackle_blocks_triggered_artifact_effects_without_prompt(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0013", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_trigger_artifact", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		31195,
		[],
		_formal_options(6)
	)
	state.phase = "main"
	state.active_player = 1
	state.priority_player = 1
	state.turn_number = 1
	var target_id = _find_hand_card_by_definition(state, 1, "qa_trigger_artifact")
	var shackle_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0013")
	var follow_up_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(target_id != "" and shackle_id != "" and follow_up_id != "", "sacred shackle trigger-lock test should draw the trigger artifact, 神圣枷锁, and a follow-up card", failures)
	if target_id.is_empty() or shackle_id.is_empty() or follow_up_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "artifact",
		"col": -1
	})).ok, "sacred shackle trigger-lock test should play the trigger artifact first", failures)
	_drain_stack_and_choices(engine, state, failures, "sacred shackle trigger-lock test should finish any setup stack after playing the trigger artifact")
	state.phase = "main"
	state.active_player = 0
	state.priority_player = 0
	state.turn_number = 2
	MoraleActions.add_temporary_morale(state, 0, 1, "test_sacred_shackle_trigger_lock_attach_morale")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": shackle_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "sacred_shackle_attach"
	})).ok, "sacred shackle trigger-lock test should attach 神圣枷锁 onto the trigger artifact", failures)
	_resolve_top_stack(engine, state, failures, "sacred shackle trigger-lock test should resolve 神圣枷锁")
	state.phase = "main"
	state.active_player = 1
	state.priority_player = 1
	state.turn_number = 3
	MoraleActions.add_temporary_morale(state, 1, 1, "test_sacred_shackle_trigger_lock_morale")
	var event_start: int = state.event_log.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": follow_up_id,
		"row": "front",
		"col": 0
	})).ok, "sacred shackle trigger-lock test should let the controller play another card after being locked", failures)
	var locked_trigger_queued := false
	for index in range(event_start, state.event_log.size()):
		var event = state.event_log[index]
		if str(event.type) != "TriggerQueued":
			continue
		var payload: Dictionary = event.payload
		if str(payload.get("source_id", "")) == target_id and str(payload.get("effect_id", "")) == "qa_trigger_artifact_draw":
			locked_trigger_queued = true
			break
	_expect(not locked_trigger_queued, "sacred shackle trigger-lock test should not queue the locked artifact's triggered effect or open a follow-up prompt", failures)

static func _test_sacred_shackle_blocks_response_artifact_effects_from_actions(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0013", "dev_tactic_rally", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_response_artifact", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		31196,
		[],
		_formal_options(6)
	)
	state.phase = "main"
	state.active_player = 1
	state.priority_player = 1
	state.turn_number = 1
	var response_artifact_id = _find_hand_card_by_definition(state, 1, "qa_response_artifact")
	var shackle_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0013")
	var rally_id = _find_hand_card_by_definition(state, 0, "dev_tactic_rally")
	_expect(response_artifact_id != "" and shackle_id != "" and rally_id != "", "sacred shackle response-lock test should draw the response artifact, 神圣枷锁, and a stack source", failures)
	if response_artifact_id.is_empty() or shackle_id.is_empty() or rally_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": response_artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "sacred shackle response-lock test should play the response artifact first", failures)
	_drain_stack_and_choices(engine, state, failures, "sacred shackle response-lock test should finish any setup stack after playing the response artifact")
	state.phase = "main"
	state.active_player = 0
	state.priority_player = 0
	state.turn_number = 2
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": shackle_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "sacred_shackle_attach"
	})).ok, "sacred shackle response-lock test should attach 神圣枷锁 onto the response artifact", failures)
	_resolve_top_stack(engine, state, failures, "sacred shackle response-lock test should resolve 神圣枷锁")
	state.phase = "main"
	state.active_player = 0
	state.priority_player = 0
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": rally_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "rally_draw"
	})).ok, "sacred shackle response-lock test should create a normal stack item for the locked artifact to respond to", failures)
	_expect(_find_activate_action(engine.get_legal_actions(state, 1), response_artifact_id, "qa_response_artifact_counter").is_empty(), "sacred shackle response-lock test should remove the locked artifact from response actions so no response popup can appear", failures)

static func _setup_poison_burst_response_state(seed: int, enemy_deck: Array, failures: Array[String], message: String) -> Dictionary:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0018", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			enemy_deck
		],
		seed,
		[],
		_formal_options(6)
	)
	var poison_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0018")
	_expect(poison_id != "", message, failures)
	if poison_id.is_empty():
		return {}
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, poison_id, 0, "test_poison_burst_set").is_empty(), message, failures)
	state.phase = "main"
	state.turn_number = max(int(state.turn_number), 2)
	state.active_player = 1
	state.priority_player = 1
	return {
		"engine": engine,
		"state": state,
		"poison_id": poison_id
	}

static func _setup_ruined_ritual_response_state(seed: int, failures: Array[String], message: String) -> Dictionary:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0016", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_revive_nonhand_entry_tactic", "qa_nonhand_entry_draw_legion", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		seed,
		[],
		_formal_options(6)
	)
	var ritual_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0016")
	var revive_tactic_id = _find_hand_card_by_definition(state, 1, "qa_revive_nonhand_entry_tactic")
	var revived_legion_id = _find_hand_card_by_definition(state, 1, "qa_nonhand_entry_draw_legion")
	_expect(ritual_id != "" and revive_tactic_id != "" and revived_legion_id != "", message, failures)
	if ritual_id.is_empty() or revive_tactic_id.is_empty() or revived_legion_id.is_empty():
		return {}
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, ritual_id, 0, "test_ruined_ritual_set").is_empty(), message, failures)
	var enemy_player = state.get_player(1)
	enemy_player.hand.remove_card(revived_legion_id)
	enemy_player.grave.add_card_to_top(revived_legion_id)
	var revived_instance = state.card_instances.get(revived_legion_id)
	if revived_instance != null:
		revived_instance.zone = "grave"
		revived_instance.position = {}
		revived_instance.controller = revived_instance.owner
		revived_instance.orientation = "active"
	state.phase = "main"
	state.turn_number = max(int(state.turn_number), 2)
	state.active_player = 1
	state.priority_player = 1
	return {
		"engine": engine,
		"state": state,
		"ritual_id": ritual_id,
		"revive_tactic_id": revive_tactic_id,
		"revived_legion_id": revived_legion_id
	}

static func _setup_landlord_coercion_probe_state(seed: int, use_block: bool, failures: Array[String], message: String) -> Dictionary:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _landlord_coercion_decks(), seed, [], _formal_options(6))
	state.phase = "main"
	state.active_player = 1
	state.priority_player = 1
	state.turn_number = 2
	var defender_id = _find_hand_card_by_definition(state, 0, "qa_plain")
	var secondary_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var coercion_id = _find_hand_card_by_definition(state, 1, "neutral_s02_0015")
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(defender_id != "" and secondary_id != "" and coercion_id != "" and attacker_id != "", message, failures)
	if defender_id.is_empty() or secondary_id.is_empty() or coercion_id.is_empty() or attacker_id.is_empty():
		return {}
	_expect(not engine._deploy_hand_card_to_slot(state, 0, defender_id, "front", 0, "test_landlord_probe_defender").is_empty(), message, failures)
	_expect(not engine._deploy_hand_card_to_slot(state, 0, secondary_id, "front" if use_block else "back", 1 if use_block else 0, "test_landlord_probe_secondary").is_empty(), message, failures)
	_expect(not engine._deploy_hand_card_to_slot(state, 1, attacker_id, "front", 0, "test_landlord_probe_attacker").is_empty(), message, failures)
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 1, coercion_id, 0, "test_landlord_probe_set").is_empty(), message, failures)
	var defender_instance = state.card_instances.get(defender_id)
	var secondary_instance = state.card_instances.get(secondary_id)
	var attacker_instance = state.card_instances.get(attacker_id)
	if defender_instance != null:
		defender_instance.entered_turn = state.turn_number - 1
	if secondary_instance != null:
		secondary_instance.entered_turn = state.turn_number - 1
	if attacker_instance != null:
		attacker_instance.entered_turn = state.turn_number - 1
	return {
		"engine": engine,
		"state": state,
		"defender": defender_id,
		"secondary": secondary_id,
		"coercion": coercion_id,
		"attacker": attacker_id
	}

static func _setup_fanatic_coercion_state(seed: int, failures: Array[String], message: String) -> Dictionary:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0006", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["neutral_s02_0015", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		seed,
		[
			{"master_id": "tianting_s01_01m1", "master_name": "测试主宰A"},
			{"master_id": "tianting_s01_01m1", "master_name": "测试主宰B"}
		],
		_formal_options(6)
	)
	state.phase = "main"
	state.active_player = 1
	state.priority_player = 1
	state.turn_number = 2
	var coercion_id = _find_hand_card_by_definition(state, 1, "neutral_s02_0015")
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	var fanatic_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0006")
	_expect(coercion_id != "" and attacker_id != "" and fanatic_id != "", message, failures)
	if coercion_id.is_empty() or attacker_id.is_empty() or fanatic_id.is_empty():
		return {}
	_expect(not engine._deploy_hand_card_to_slot(state, 1, attacker_id, "front", 0, "test_fanatic_probe_attacker").is_empty(), message, failures)
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 1, coercion_id, 0, "test_fanatic_probe_set").is_empty(), message, failures)
	var attacker_instance = state.card_instances.get(attacker_id)
	if attacker_instance != null:
		attacker_instance.entered_turn = state.turn_number - 1
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "master"
	})).ok, "%s should allow the attacker to declare a master attack" % message, failures)
	var guard_payload: Dictionary = {}
	for action in engine.get_legal_actions(state, 0):
		if str(action.get("command_type", "")) != "ChooseDefense":
			continue
		var payload: Dictionary = action.get("payload_template", {})
		if payload.has("master_guard_card_ids"):
			guard_payload = payload
			break
	_expect(not guard_payload.is_empty(), "%s should offer a master-guard response" % message, failures)
	if guard_payload.is_empty():
		return {}
	_expect(engine.apply_command(state, GameCommand.create(0, "ChooseDefense", guard_payload)).ok, "%s should allow choosing the master-guard response" % message, failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": coercion_id,
		"effect_id": "landlord_coercion"
	})).ok, "%s should allow activating 地主的胁迫 after the guard choice" % message, failures)
	_resolve_top_stack(engine, state, failures, "%s should resolve 地主的胁迫 into the extra discard choice" % message)
	var discard_choice = _pending_choice_by_operation(state, "landlord_coercion_extra_discard")
	_expect(discard_choice != null, "%s should open the extra discard choice" % message, failures)
	if discard_choice == null:
		return {}
	return {
		"engine": engine,
		"state": state,
		"fanatic_id": fanatic_id,
		"discard_choice_id": str(discard_choice.get("choice_id", ""))
	}

static func _setup_sacred_shackle_attached_state(seed: int, target_definition_id: String, failures: Array[String], message: String) -> Dictionary:
	var engine = GameEngine.new()
	var state = engine.create_game(
		_definitions(),
		[
			["neutral_s02_0013", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			[target_definition_id, "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		seed,
		[],
		_formal_options(6)
	)
	state.phase = "main"
	state.active_player = 1
	state.priority_player = 1
	state.turn_number = 1
	var target_id = _find_hand_card_by_definition(state, 1, target_definition_id)
	var shackle_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0013")
	_expect(target_id != "" and shackle_id != "", message, failures)
	if target_id.is_empty() or shackle_id.is_empty():
		return {}
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "artifact",
		"col": -1
	})).ok, message, failures)
	_drain_stack_and_choices(engine, state, failures, message)
	state.phase = "main"
	state.active_player = 0
	state.priority_player = 0
	state.turn_number = 2
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": shackle_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "sacred_shackle_attach"
	})).ok, message, failures)
	_resolve_top_stack(engine, state, failures, message)
	return {
		"engine": engine,
		"state": state,
		"target_id": target_id,
		"shackle_id": shackle_id
	}

static func _trigger_landlord_coercion_probe(setup: Dictionary, use_block: bool, failures: Array[String], prefix: String) -> void:
	var engine: GameEngine = setup.engine
	var state = setup.state
	var defender_id := str(setup.get("defender", ""))
	var secondary_id := str(setup.get("secondary", ""))
	var coercion_id := str(setup.get("coercion", ""))
	var attacker_id := str(setup.get("attacker", ""))
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id
	})).ok, "%s should allow the attack" % prefix, failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ChooseDefense", {
		"blocker_id": secondary_id
	} if use_block else {
		"supporter_id": secondary_id
	})).ok, "%s should allow choosing %s first" % [prefix, "block" if use_block else "support"], failures)
	var actions = engine.get_legal_actions(state, 1)
	var found := false
	for action in actions:
		if str(action.get("command_type", "")) != "ActivateEffect":
			continue
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("source_id", "")) == coercion_id and str(payload.get("effect_id", "")) == "landlord_coercion":
			found = true
			break
	_expect(found, "%s should expose 地主的胁迫 after the defense choice" % prefix, failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": coercion_id,
		"effect_id": "landlord_coercion"
	})).ok, "%s should let the attacker respond with 地主的胁迫" % prefix, failures)
	_resolve_top_stack(engine, state, failures, "%s should resolve to the extra discard choice" % prefix)

static func _test_plague_infection_freezes_selected_legion(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _plague_enemy_legion_decks(), 3101, [], _formal_options(2))
	_advance_to_next_main(engine, state, failures, "plague legion test should advance to player 2 main")
	var enemy_legion = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(enemy_legion != "", "plague legion test should draw the enemy legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_legion,
		"row": "front",
		"col": 0
	})).ok, "plague legion test should deploy the enemy legion", failures)
	var enemy_legion_id := str(state.get_player(1).battle_front[0].occupant)
	_expect(enemy_legion_id != "", "plague legion test should keep the enemy legion on battlefield", failures)
	_advance_to_next_main(engine, state, failures, "plague legion test should return to player 1 main")
	var plague_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0011")
	_expect(plague_id != "", "plague legion test should draw 瘟疫感染", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": plague_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "plague_infection_choose",
		"target_kind": "card",
		"target_card_id": enemy_legion_id
	})).ok, "plague legion test should allow targeting an enemy legion directly", failures)
	_resolve_top_stack(engine, state, failures, "plague legion test should resolve the tactic stack")
	var enemy_instance = state.card_instances.get(enemy_legion_id)
	_expect(enemy_instance != null and int(enemy_instance.flags.get("cannot_ready_on_ready_phase_player", -1)) == 1, "plague legion test should mark the chosen enemy legion as unable to ready next reset", failures)
	if enemy_instance != null:
		enemy_instance.orientation = "rested"
	_advance_to_next_main(engine, state, failures, "plague legion test should advance to the enemy next main phase")
	enemy_instance = state.card_instances.get(enemy_legion_id)
	_expect(enemy_instance != null and int(enemy_instance.flags.get("cannot_ready_on_ready_phase_player", -1)) == -1, "plague legion test should clear the freeze marker after the blocked reset", failures)

static func _test_plague_infection_skips_enemy_morale_ready(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _plague_enemy_legion_decks(), 3102, [], _formal_options(2))
	_advance_to_next_main(engine, state, failures, "plague morale test should advance to player 2 main")
	var enemy_legion = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_legion,
		"row": "front",
		"col": 0
	})).ok, "plague morale test should let the enemy spend one morale", failures)
	var enemy_active_after_play = MoraleActions.count_active_morale(state, 1)
	var enemy_spent_after_play = state.get_player(1).spent_cost_area.cards.size()
	_expect(enemy_spent_after_play > 0, "plague morale test should create spent morale before the tactic resolves", failures)
	_advance_to_next_main(engine, state, failures, "plague morale test should return to player 1 main")
	var plague_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0011")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": plague_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "plague_infection_choose",
		"target_kind": "morale_area",
		"target_player": 1
	})).ok, "plague morale test should allow targeting the enemy morale area directly", failures)
	_resolve_top_stack(engine, state, failures, "plague morale test should resolve the tactic stack")
	_expect(int(state.get_player(1).flags.get("suncity_skip_next_ready_morale_count", 0)) == 1, "plague morale test should set the next enemy morale-ready skip counter", failures)
	_advance_to_next_main(engine, state, failures, "plague morale test should advance to the enemy next main phase")
	_expect(MoraleActions.count_active_morale(state, 1) == enemy_active_after_play, "plague morale test should stop the next enemy reset from readying one spent morale", failures)
	_expect(state.get_player(1).spent_cost_area.cards.size() == enemy_spent_after_play, "plague morale test should keep the skipped morale spent after the blocked ready", failures)

static func _test_nameless_infiltrator_can_deploy_to_enemy_field_and_self_destruct(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _infiltrator_decks(), 3103, [], _formal_options(2))
	var infiltrator_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0004")
	_expect(infiltrator_id != "", "infiltrator test should draw 无名的渗透者", failures)
	var owner_hand_before = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": infiltrator_id,
		"row": "front",
		"col": 0,
		"host_player": 1
	})).ok, "infiltrator test should allow deploying to the enemy battlefield", failures)
	_expect(str(state.get_player(1).battle_front[0].occupant) == infiltrator_id, "infiltrator test should place the card onto the enemy battlefield slot", failures)
	var infiltrator_instance = state.card_instances.get(infiltrator_id)
	_expect(infiltrator_instance != null and int(infiltrator_instance.owner) == 0 and int(infiltrator_instance.controller) == 1, "infiltrator test should keep ownership with the player who played it while control follows the host battlefield", failures)
	_expect(infiltrator_instance != null and str(infiltrator_instance.orientation) == "rested", "infiltrator test should still enter rested on the enemy battlefield", failures)
	var spent_after_play = state.get_player(0).spent_cost_area.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": infiltrator_id,
		"effect_id": "nameless_infiltrator_suicide"
	})).ok, "infiltrator test should allow the active player to activate the self-destruct effect immediately after enemy-field deployment", failures)
	_resolve_top_stack(engine, state, failures, "infiltrator test should resolve the self-destruct stack")
	_expect(state.get_player(1).grave.cards.has(infiltrator_id), "infiltrator test should move the transferred card into the host player's grave", failures)
	_expect(str(state.get_player(1).battle_front[0].occupant) == "", "infiltrator test should clear the enemy battlefield slot after self-destruction", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == spent_after_play + 2, "infiltrator test should still spend 2 morale to self-destruct in the same turn", failures)
	_expect(state.get_player(0).hand.cards.size() == owner_hand_before, "infiltrator test should have the card owner draw 1 after death even on the enemy battlefield", failures)

static func _test_luying_entry_tax_applies_on_deploy(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _luying_decks(), 3104, [], _formal_options(2))
	var plague_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0011")
	_expect(plague_id != "", "luying test should keep an enemy tactic in hand", failures)
	var tactic_instance = state.card_instances.get(plague_id)
	var tactic_definition = state.get_definition(tactic_instance.definition_id) if tactic_instance != null else null
	var base_cost = int(tactic_definition.cost) if tactic_definition != null else -1
	var luying_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0001")
	_expect(luying_id != "", "luying test should draw 驱魔道士 陆瑛", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": luying_id,
		"row": "front",
		"col": 0
	})).ok, "luying test should deploy successfully", failures)
	_drain_stack_and_choices(engine, state, failures, "luying entry trigger should resolve")
	_expect(engine._effective_hand_play_cost(state, plague_id, {}, "tactic") == base_cost + 1, "luying test should increase the enemy tactic hand play cost by 1 immediately on entry", failures)

static func _test_luying_optional_prompt_describes_trigger_and_result(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _luying_decks(), 3107, [], _formal_options(2))
	var luying_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0001")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": luying_id,
		"row": "front",
		"col": 0
	})).ok, "luying prompt test should deploy successfully", failures)
	_drain_stack_and_choices(engine, state, failures, "luying prompt test should resolve the entry effect")
	_advance_to_next_main(engine, state, failures, "luying prompt test should advance to the opponent main phase")
	var plague_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0011")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": plague_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "plague_infection_choose",
		"target_kind": "morale_area",
		"target_player": 0
	})).ok, "luying prompt test should let the opponent resolve a tactic", failures)
	_resolve_top_stack(engine, state, failures, "luying prompt test should resolve the opponent tactic")
	_expect(not state.pending_choices.is_empty(), "luying prompt test should create an optional trigger choice after the opponent tactic resolves", failures)
	if not state.pending_choices.is_empty():
		var choice = state.pending_choices[0]
		var title := str(choice.get("title", ""))
		_expect(str(choice.get("operation", "")) == "optional_stack_effect", "luying prompt test should use the optional stack effect prompt", failures)
		_expect(title.find("对方1个战术效果结算后") >= 0, "luying prompt test title should explain why the trigger appeared", failures)
		_expect(title.find("返回手牌") >= 0, "luying prompt test title should explain what happens when it resolves", failures)

static func _test_regency_authority_can_be_confirmed_to_deploy_and_go_to_grave(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _regency_trigger_decks(), 3105, [], _formal_options(2))
	var regency_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0021")
	_expect(regency_id != "", "regency trigger test should draw 摄政皇权", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": regency_id,
		"row": "back",
		"col": 0
	})).ok, "regency trigger test should set 摄政皇权 onto the battlefield", failures)
	_advance_to_next_main(engine, state, failures, "regency trigger test should advance to player 2 main")
	var attacker = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker,
		"row": "front",
		"col": 0
	})).ok, "regency trigger test should deploy the attacking legion", failures)
	_advance_to_next_main(engine, state, failures, "regency trigger test should advance through player 1 turn")
	_advance_to_next_main(engine, state, failures, "regency trigger test should return to player 2 main for the attack")
	var attacker_id := str(state.get_player(1).battle_front[0].occupant)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_player": 0
	})).ok, "regency trigger test should allow the direct attack", failures)
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "regency trigger test should ask whether to respond before consuming 摄政皇权", failures)
	_drain_stack_and_choices(engine, state, failures, "regency trigger test should resolve the triggered counter tactic and deployment choice")
	_expect(state.get_player(0).grave.cards.has(regency_id), "regency trigger test should move 摄政皇权 to grave after the trigger resolves", failures)
	_expect(_find_hand_card_by_definition(state, 0, "qa_plain") == "", "regency trigger test should consume the low-cost legion from hand when the trigger resolves", failures)
	_expect(_player_has_battlefield_card(state, 0, "qa_plain"), "regency trigger test should deploy a low-cost legion from hand onto the battlefield", failures)

static func _test_regency_authority_does_not_trigger_without_valid_hand_legion(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _regency_no_target_decks(), 3106, [], _formal_options(1))
	var regency_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0021")
	_expect(regency_id != "", "regency no-target test should draw 摄政皇权", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": regency_id,
		"row": "back",
		"col": 0
	})).ok, "regency no-target test should set 摄政皇权", failures)
	_advance_to_next_main(engine, state, failures, "regency no-target test should advance to player 2 main")
	var attacker = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker,
		"row": "front",
		"col": 0
	})).ok, "regency no-target test should deploy the attacking legion", failures)
	_advance_to_next_main(engine, state, failures, "regency no-target test should pass player 1 turn")
	_advance_to_next_main(engine, state, failures, "regency no-target test should return to player 2 main for the attack")
	var attacker_id := str(state.get_player(1).battle_front[0].occupant)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_player": 0
	})).ok, "regency no-target test should allow the direct attack", failures)
	_drain_stack_and_choices(engine, state, failures, "regency no-target test should finish the attack sequence")
	_expect(not state.get_player(0).grave.cards.has(regency_id), "regency no-target test should not send 摄政皇权 to grave when no valid legion exists", failures)
	_expect(str(state.get_player(0).battle_back[0].occupant) == regency_id, "regency no-target test should keep 摄政皇权 set on battlefield if it cannot trigger", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _formal_options(opening_hand_size: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": 10,
		"opening_non_active_player_morale": 10
	}

static func _plague_enemy_legion_decks() -> Array:
	return [
		["neutral_s01_0011", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _infiltrator_decks() -> Array:
	return [
		["neutral_s01_0004", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _luying_decks() -> Array:
	return [
		["neutral_s02_0001", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["neutral_s01_0011", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _regency_trigger_decks() -> Array:
	return [
		["neutral_s01_0021", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _regency_no_target_decks() -> Array:
	return [
		["neutral_s01_0021", "neutral_s01_0011", "neutral_s01_0011", "neutral_s01_0011", "neutral_s01_0011", "neutral_s01_0011"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _forged_order_blocked_decks() -> Array:
	return [
		["neutral_s01_0010", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _forged_order_live_decks() -> Array:
	return [
		["neutral_s01_0010", "neutral_s01_0010", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _frontline_scout_decks() -> Array:
	return [
		["neutral_s01_0013", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["neutral_s01_0011", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _siege_catapult_decks() -> Array:
	return [
		["neutral_s01_0003", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _defensive_deployment_decks() -> Array:
	return [
		["neutral_s02_0009", "neutral_s02_0015", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _grain_plunder_decks() -> Array:
	return [
		["neutral_s02_0017", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_bouncer", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _grain_plunder_truce_decks() -> Array:
	return [
		["neutral_s02_0017", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["neutral_s01_0015", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _grain_plunder_tutor_decks() -> Array:
	return [
		["neutral_s02_0017", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_scout", "qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _black_lotus_decks() -> Array:
	return [
		["neutral_s02_0010", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _desperate_resistance_decks() -> Array:
	return [
		["neutral_s01_0017", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _desperate_resistance_all_decks() -> Array:
	return [
		["neutral_s01_0017", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _landlord_coercion_decks() -> Array:
	return [
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["neutral_s02_0015", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, message, failures)
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, message, failures)

static func _resolve_pending_attack(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, first_message, failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, second_message, failures)

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
	for _i in range(24):
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

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _find_nth_hand_card_by_definition(state, player_id: int, definition_id: String, ordinal: int) -> String:
	var seen := 0
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance == null or instance.definition_id != definition_id:
			continue
		seen += 1
		if seen == ordinal:
			return card_id
	return ""

static func _player_has_battlefield_card(state, player_id: int, definition_id: String) -> bool:
	for row in [state.get_player(player_id).battle_front, state.get_player(player_id).battle_back]:
		for slot in row:
			var occupant_id := str(slot.occupant)
			if occupant_id.is_empty():
				continue
			var instance = state.card_instances.get(occupant_id)
			if instance != null and instance.definition_id == definition_id:
				return true
	return false

static func _has_card_attack_target(targets: Array, defender_id: String) -> bool:
	for target in targets:
		if not (target is Dictionary):
			continue
		if str(target.get("target_kind", "card")) == "card" and str(target.get("defender_id", "")) == defender_id:
			return true
	return false

static func _has_master_attack_target(targets: Array, target_player: int) -> bool:
	for target in targets:
		if not (target is Dictionary):
			continue
		if str(target.get("target_kind", "")) == "master" and int(target.get("target_player", -1)) == target_player:
			return true
	return false

static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
	})).ok

static func _resolve_candidate_choice_with_slot(engine: GameEngine, state, operation: String, selected_card_ids: Array, row: String, col: int) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected_card_ids.duplicate(),
		"row": row,
		"col": col
	})).ok

static func _pending_choice_by_operation(state, operation: String):
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return null

static func _last_event_payload(state, event_type: String) -> Dictionary:
	for index in range(state.event_log.size() - 1, -1, -1):
		var event = state.event_log[index]
		if str(event.type) == event_type:
			return event.payload.duplicate(true)
	return {}

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _find_activate_action(actions: Array, source_id: String, effect_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("kind", "")) != "activate_effect":
			continue
		var payload = action.get("payload_template", {})
		if str(payload.get("source_id", "")) == source_id and str(payload.get("effect_id", "")) == effect_id:
			return action
	return {}

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
