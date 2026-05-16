extends RefCounted
class_name TestClassicBatch1

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_golden_harald_cost_discount_and_last_heal(failures)
	_test_odell_optional_draw_and_last_rest(failures)
	_test_odell_entry_from_deck_triggers_once(failures)
	_test_ivar_search_and_reorder(failures)
	_test_evil_ritual_is_nonlethal(failures)
	_test_arrow_barrage_modes(failures)
	_test_wild_camp_search_and_bonus_choice(failures)
	_test_under_siege_front_debuff_and_disable_support(failures)
	_test_ritual_of_heaven_draw_and_calamity_choice(failures)
	_test_all_out_attack_grants_charge_to_next_cheap_legion(failures)
	_test_yukimura_gains_charge_on_entry(failures)
	_test_ambush_counters_stack_and_pending_attack(failures)
	_test_fight_till_dawn_counter_buff_and_grave_draw(failures)
	_test_fleeting_insight_hand_size_gate(failures)
	_test_prayer_ritual_reveal_branches(failures)
	_test_crazy_alice_kill_readies_once_per_turn(failures)
	_test_louis_mandrin_frontline_taunt_and_opponent_turn_power(failures)
	_test_louis_mandrin_back_row_does_not_force_taunt(failures)
	_test_truce_offer_branches(failures)
	_test_absolute_defense_counters_pending_attack(failures)
	_test_absolute_defense_counters_master_attack(failures)
	_test_absolute_defense_does_not_respond_to_own_actions(failures)
	_test_strategic_transfer_bounce_and_buff(failures)
	return failures

static func _test_golden_harald_cost_discount_and_last_heal(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _golden_harald_decks(), 2001, [], _formal_options(6))
	var first_vanilla = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(first_vanilla != "", "golden harald setup needs first allied legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_vanilla,
		"row": "front",
		"col": 0
	})).ok, "first allied legion should play for golden harald cost test", failures)
	var second_vanilla = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(second_vanilla != "", "golden harald setup needs second allied legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_vanilla,
		"row": "front",
		"col": 1
	})).ok, "second allied legion should play for golden harald cost test", failures)
	var harald_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0302")
	_expect(harald_id != "", "golden harald should be in hand", failures)
	_expect(engine._get_base_effective_play_cost(state, harald_id) == 6, "golden harald should cost 6 with two allied legions on battlefield", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": harald_id,
		"row": "front",
		"col": 2
	})).ok, "golden harald should play after discount", failures)
	state.players[0].master_hp = 6
	var death_events = engine._deal_legion_damage(state, "", harald_id, 7000, "test_golden_harald_die")
	engine._process_generated_events(state, death_events, "test_golden_harald_die")
	_resolve_top_stack(engine, state, failures, "golden harald death trigger should resolve")
	_expect(state.players[0].master_hp == 7, "golden harald death trigger should heal own master by 1", failures)

static func _test_odell_optional_draw_and_last_rest(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _odell_decks(), 2002, [], _formal_options(5))
	var odell_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0313")
	_expect(odell_id != "", "odell should be in hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": odell_id,
		"row": "front",
		"col": 0
	})).ok, "odell should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "odell entry trigger should reach optional choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "odell entry optional should resolve as yes", failures)
	_expect(state.players[0].master_hp == 19, "odell entry trigger should deal 1 damage to own master", failures)
	_expect(state.get_player(0).hand.cards.size() == 5, "odell entry trigger should restore one card to hand", failures)
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(enemy_id != "", "odell death test needs an enemy legion in hand", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_odell_enemy_setup")
	var death_events = engine._deal_legion_damage(state, "", odell_id, 2000, "test_odell_die")
	engine._process_generated_events(state, death_events, "test_odell_die")
	_resolve_top_stack(engine, state, failures, "odell death trigger should reach optional choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "odell death optional should resolve as yes", failures)
	_expect(_resolve_candidate_choice(engine, state, "rest_battlefield_card", [enemy_id]), "odell death should select an enemy legion to rest", failures)
	var enemy_instance = state.card_instances.get(enemy_id)
	_expect(enemy_instance != null and str(enemy_instance.orientation) == "rested", "odell death trigger should turn the chosen enemy legion to rested", failures)

static func _test_odell_entry_from_deck_triggers_once(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _odell_from_deck_decks(), 20021, [], _formal_options(0))
	var odell_id = _find_deck_card_by_definition(state, 0, "asgard_s01_0313")
	_expect(odell_id != "", "odell deck-entry test should keep 奥德尔 in deck", failures)
	if odell_id == "":
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var deploy_events = engine._deploy_deck_card_to_slot(state, 0, odell_id, "front", 0, "test_odell_from_deck")
	engine._process_generated_events(state, deploy_events, "test_odell_from_deck")
	_resolve_top_stack(engine, state, failures, "odell deck-entry trigger should reach the optional choice once")
	_expect(state.pending_choices.size() == 1, "odell deck-entry test should create exactly one optional trigger choice", failures)
	if state.pending_choices.size() != 1:
		return
	_expect(str(state.pending_choices[0].get("operation", "")) == "optional_stack_effect", "odell deck-entry test should stop on the optional trigger choice", failures)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "odell deck-entry optional should resolve as yes", failures)
	_expect(state.players[0].master_hp == 19, "odell deck-entry trigger should only deal 1 damage once", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + 1, "odell deck-entry trigger should only draw one card", failures)

static func _test_ivar_search_and_reorder(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _ivar_decks(), 2003, [], _formal_options(1))
	var ivar_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0315")
	_expect(ivar_id != "", "ivar should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ivar_id,
		"row": "front",
		"col": 0
	})).ok, "ivar should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "ivar search trigger should resolve to a choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "ivar search optional should resolve as yes", failures)
	var choice = _pending_choice_by_operation(state, "search_deck")
	_expect(choice != null, "ivar should create a search choice", failures)
	if choice == null:
		return
	var candidates = choice.get("candidate_card_ids", [])
	_expect(candidates is Array and candidates.size() == 2, "ivar search should expose two asgard candidates from the top three cards", failures)
	var odell_candidate = _find_candidate_by_definition(state, candidates, "asgard_s01_0313")
	_expect(odell_candidate != "", "ivar search should allow choosing odell", failures)
	_expect(_resolve_candidate_choice(engine, state, "search_deck", [odell_candidate]), "ivar search choice should resolve", failures)
	_expect(_has_event_type(state, "CardsRevealedToOpponent"), "ivar search should reveal the chosen card to the opponent after adding it to hand", failures)
	var reorder_choice = _pending_choice_by_operation(state, "search_deck_reorder_bottom")
	_expect(reorder_choice != null, "ivar search should request bottom-of-deck reorder", failures)
	if reorder_choice == null:
		return
	var reorder_candidates = reorder_choice.get("candidate_card_ids", [])
	var ritual_card = _find_candidate_by_definition(state, reorder_candidates, "neutral_s01_0006")
	var harald_card = _find_candidate_by_definition(state, reorder_candidates, "asgard_s01_0302")
	_expect(ritual_card != "" and harald_card != "", "ivar reorder choice should include the remaining looked cards", failures)
	_expect(_resolve_candidate_choice(engine, state, "search_deck_reorder_bottom", [ritual_card, harald_card]), "ivar reorder choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.has(odell_candidate), "ivar should add the selected asgard card to hand", failures)
	var deck_cards = state.get_player(0).deck.cards
	_expect(deck_cards.size() >= 2, "ivar deck should still contain reordered cards", failures)
	_expect(str(deck_cards[deck_cards.size() - 2]) == ritual_card and str(deck_cards[deck_cards.size() - 1]) == harald_card, "ivar should return remaining cards to deck bottom in chosen order", failures)

static func _test_evil_ritual_is_nonlethal(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _evil_ritual_decks(), 2006, [], _formal_options(2))
	state.players[1].master_hp = 1
	var ritual_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0006")
	_expect(ritual_id != "", "evil ritual should be in hand", failures)
	var discard_candidate = ""
	for hand_card_id in state.get_player(0).hand.cards:
		if str(hand_card_id) != ritual_id:
			discard_candidate = str(hand_card_id)
			break
	_expect(discard_candidate != "", "evil ritual setup should provide another hand card to discard", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ritual_id,
		"row": "tactic",
		"col": -1
	})).ok, "evil ritual should play successfully", failures)
	var discard_choice = _pending_choice_by_operation(state, "discard_from_hand")
	_expect(discard_choice != null, "evil ritual should request choosing a hand card to discard as its cost", failures)
	_expect(state.stack.is_empty(), "evil ritual should wait for the discard choice before putting its effect on stack", failures)
	if discard_choice == null:
		return
	_expect(_resolve_candidate_choice(engine, state, "discard_from_hand", [discard_candidate]), "evil ritual should resolve the discard cost choice", failures)
	_resolve_top_stack(engine, state, failures, "evil ritual should resolve from the stack")
	_expect(state.players[1].master_hp == 1, "evil ritual should not reduce the opponent master below 1 hp", failures)
	_expect(state.get_player(0).hand.cards.is_empty(), "evil ritual should still discard one card from hand as its cost", failures)
	_expect(state.get_player(0).grave.cards.size() == 2, "evil ritual and the discarded card should both end up in grave", failures)

static func _test_arrow_barrage_modes(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _arrow_barrage_decks(), 2004, [], _formal_options(3))
	var barrage_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0005")
	_expect(barrage_id != "", "arrow barrage should be in opening hand", failures)
	var tactic_effects = engine.get_castable_tactic_effects(state, 0, barrage_id)
	_expect(tactic_effects.size() == 3, "arrow barrage should expose three castable mode effects", failures)
	var enemy_front = _find_hand_card_by_definition(state, 1, "qa_plain")
	var enemy_front_two = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	var enemy_back = _find_hand_card_by_definition(state, 1, "qa_ranged")
	_expect(enemy_front != "" and enemy_front_two != "" and enemy_back != "", "arrow barrage setup should provide enemy units for both rows", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_front, "front", 0, "test_arrow_barrage_enemy_front")
	engine._deploy_hand_card_to_slot(state, 1, enemy_front_two, "front", 1, "test_arrow_barrage_enemy_front_two")
	engine._deploy_hand_card_to_slot(state, 1, enemy_back, "back", 0, "test_arrow_barrage_enemy_back")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": barrage_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "arrow_barrage_enemy_front"
	})).ok, "arrow barrage front-row mode should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "arrow barrage front-row mode should resolve")
	_expect(engine.get_card_power(state, enemy_front) == 0, "arrow barrage front-row mode should reduce the first front-row enemy by 2000", failures)
	_expect(engine.get_card_power(state, enemy_front_two) == 1000, "arrow barrage front-row mode should reduce the second front-row enemy by 2000", failures)
	_expect(engine.get_card_power(state, enemy_back) == 3000, "arrow barrage front-row mode should not affect back-row enemies", failures)

	var focus_engine = GameEngine.new()
	var focus_state = focus_engine.create_game(_definitions(), _arrow_barrage_decks(), 2005, [], _formal_options(3))
	var focus_barrage_id = _find_hand_card_by_definition(focus_state, 0, "neutral_s01_0005")
	var focus_front = _find_hand_card_by_definition(focus_state, 1, "qa_plain")
	var focus_back = _find_hand_card_by_definition(focus_state, 1, "qa_ranged")
	_expect(focus_barrage_id != "" and focus_front != "" and focus_back != "", "arrow barrage focus setup should provide a tactic and enemy targets", failures)
	focus_engine._deploy_hand_card_to_slot(focus_state, 1, focus_front, "front", 0, "test_arrow_barrage_focus_front")
	focus_engine._deploy_hand_card_to_slot(focus_state, 1, focus_back, "back", 0, "test_arrow_barrage_focus_back")
	_expect(focus_engine.apply_command(focus_state, GameCommand.create(0, "PlayCard", {
		"card_id": focus_barrage_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "arrow_barrage_focus",
		"target_card_id": focus_back
	})).ok, "arrow barrage focus mode should play successfully", failures)
	_resolve_top_stack(focus_engine, focus_state, failures, "arrow barrage focus mode should resolve directly with the selected target")
	_expect(focus_engine.get_card_power(focus_state, focus_back) == 0, "arrow barrage focus mode should reduce the chosen unit by 4000", failures)
	_expect(focus_engine.get_card_power(focus_state, focus_front) == 2000, "arrow barrage focus mode should not affect non-chosen enemy units", failures)

static func _test_wild_camp_search_and_bonus_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var heal_state = engine.create_game(_definitions(), _wild_camp_decks(), 2008, _wild_camp_metadata(), _formal_options(1))
	var wild_camp_id = _find_hand_card_by_definition(heal_state, 0, "neutral_s01_0007")
	_expect(wild_camp_id != "", "wild camp should be in opening hand for heal branch", failures)
	_expect(engine.apply_command(heal_state, GameCommand.create(0, "PlayCard", {
		"card_id": wild_camp_id,
		"row": "tactic",
		"col": -1
	})).ok, "wild camp should play successfully for heal branch", failures)
	_resolve_top_stack(engine, heal_state, failures, "wild camp search should resolve to a choice")
	var heal_search_choice = _pending_choice_by_operation(heal_state, "search_deck")
	_expect(heal_search_choice != null, "wild camp should create a search choice", failures)
	if heal_search_choice == null:
		return
	var heal_candidates = heal_search_choice.get("candidate_card_ids", [])
	_expect(heal_candidates is Array and heal_candidates.size() == 1, "wild camp should only expose legions matching the controller master faction", failures)
	var asgard_candidate = _find_candidate_by_definition(heal_state, heal_candidates, "asgard_s01_0313")
	_expect(asgard_candidate != "", "wild camp should allow choosing the asgard legion when own master is asgard", failures)
	_expect(_find_candidate_by_definition(heal_state, heal_candidates, "takamagahara_s01_0401") == "", "wild camp should not expose off-faction legions", failures)
	_expect(_resolve_candidate_choice(engine, heal_state, "search_deck", [asgard_candidate]), "wild camp should resolve the tutored card choice", failures)
	var heal_reorder_choice = _pending_choice_by_operation(heal_state, "search_deck_reorder_bottom")
	_expect(heal_reorder_choice != null, "wild camp should request a bottom-of-deck reorder", failures)
	if heal_reorder_choice == null:
		return
	var heal_reorder_candidates = heal_reorder_choice.get("candidate_card_ids", [])
	var neutral_card = _find_candidate_by_definition(heal_state, heal_reorder_candidates, "neutral_s01_0006")
	var takamagahara_card = _find_candidate_by_definition(heal_state, heal_reorder_candidates, "takamagahara_s01_0401")
	_expect(neutral_card != "" and takamagahara_card != "", "wild camp reorder should include the non-selected looked cards", failures)
	_expect(_resolve_candidate_choice(engine, heal_state, "search_deck_reorder_bottom", [neutral_card, takamagahara_card]), "wild camp reorder should resolve", failures)
	_expect(heal_state.get_player(0).hand.cards.has(asgard_candidate), "wild camp should add the selected same-faction legion to hand", failures)
	_expect(_has_event_type(heal_state, "CardsRevealedToOpponent"), "wild camp should reveal the chosen legion to the opponent after adding it to hand", failures)
	var heal_bonus_choice = _pending_choice_by_operation(heal_state, "resolve_option_with_shared_cost")
	_expect(heal_bonus_choice != null, "wild camp should offer the optional morale-paid bonus choice", failures)
	_expect(_resolve_option_choice(engine, heal_state, "resolve_option_with_shared_cost", "heal_master"), "wild camp should resolve the heal option", failures)
	_expect(heal_state.get_player(0).master_hp == 12, "wild camp heal option should restore 1 master hp after paying morale", failures)

	var draw_engine = GameEngine.new()
	var draw_state = draw_engine.create_game(_definitions(), _wild_camp_decks(), 2009, _wild_camp_metadata(), _formal_options(1))
	var draw_wild_camp_id = _find_hand_card_by_definition(draw_state, 0, "neutral_s01_0007")
	_expect(draw_wild_camp_id != "", "wild camp should be in opening hand for draw branch", failures)
	_expect(draw_engine.apply_command(draw_state, GameCommand.create(0, "PlayCard", {
		"card_id": draw_wild_camp_id,
		"row": "tactic",
		"col": -1
	})).ok, "wild camp should play successfully for draw branch", failures)
	_resolve_top_stack(draw_engine, draw_state, failures, "wild camp draw branch should resolve to a choice")
	var draw_search_choice = _pending_choice_by_operation(draw_state, "search_deck")
	_expect(draw_search_choice != null, "wild camp draw branch should create a search choice", failures)
	if draw_search_choice == null:
		return
	var draw_asgard_candidate = _find_candidate_by_definition(draw_state, draw_search_choice.get("candidate_card_ids", []), "asgard_s01_0313")
	_expect(draw_asgard_candidate != "", "wild camp draw branch should still expose the same-faction legion", failures)
	_expect(_resolve_candidate_choice(draw_engine, draw_state, "search_deck", [draw_asgard_candidate]), "wild camp draw branch should resolve the tutored card choice", failures)
	var draw_reorder_choice = _pending_choice_by_operation(draw_state, "search_deck_reorder_bottom")
	_expect(draw_reorder_choice != null, "wild camp draw branch should request a bottom-of-deck reorder", failures)
	if draw_reorder_choice == null:
		return
	var draw_reorder_candidates = draw_reorder_choice.get("candidate_card_ids", [])
	var draw_neutral_card = _find_candidate_by_definition(draw_state, draw_reorder_candidates, "neutral_s01_0006")
	var draw_takamagahara_card = _find_candidate_by_definition(draw_state, draw_reorder_candidates, "takamagahara_s01_0401")
	_expect(_resolve_candidate_choice(draw_engine, draw_state, "search_deck_reorder_bottom", [draw_neutral_card, draw_takamagahara_card]), "wild camp draw branch reorder should resolve", failures)
	_expect(_has_event_type(draw_state, "CardsRevealedToOpponent"), "wild camp draw branch should also reveal the chosen legion to the opponent", failures)
	_expect(_resolve_option_choice(draw_engine, draw_state, "resolve_option_with_shared_cost", "draw_cards"), "wild camp should resolve the draw option", failures)
	_expect(draw_state.get_player(0).hand.cards.size() == 2, "wild camp draw option should leave the controller with the tutored legion plus one drawn card", failures)
	_expect(draw_state.get_player(0).master_hp == 11, "wild camp draw option should not change master hp", failures)

	var empty_engine = GameEngine.new()
	var empty_state = empty_engine.create_game(_definitions(), _wild_camp_decks(), 2019, _wild_camp_metadata(), _formal_options(1))
	var empty_wild_camp_id = _find_hand_card_by_definition(empty_state, 0, "neutral_s01_0007")
	_expect(empty_wild_camp_id != "", "wild camp empty branch should keep the tactic in opening hand", failures)
	_expect(empty_engine.apply_command(empty_state, GameCommand.create(0, "PlayCard", {
		"card_id": empty_wild_camp_id,
		"row": "tactic",
		"col": -1
	})).ok, "wild camp should play successfully for the empty branch", failures)
	_resolve_top_stack(empty_engine, empty_state, failures, "wild camp empty branch should resolve to a choice")
	var empty_search_choice = _pending_choice_by_operation(empty_state, "search_deck")
	_expect(empty_search_choice != null, "wild camp empty branch should still create the search choice before the player decides to skip taking a card", failures)
	if empty_search_choice == null:
		return
	_expect(empty_engine.apply_command(empty_state, GameCommand.create(int(empty_search_choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(empty_search_choice.get("choice_id", "")),
		"cancelled": true
	})).ok, "wild camp empty branch should allow skipping the tutored legion", failures)
	_expect(not _has_event_type(empty_state, "CardsRevealedToOpponent"), "wild camp empty branch should not reveal cards when nothing is added to hand", failures)
	var empty_bonus_choice = _pending_choice_by_operation(empty_state, "resolve_option_with_shared_cost")
	_expect(empty_bonus_choice != null, "wild camp empty branch should still offer the optional morale-paid bonus choice", failures)
	_expect(_resolve_option_choice(empty_engine, empty_state, "resolve_option_with_shared_cost", "draw_cards"), "wild camp empty branch should still resolve the paid draw option", failures)
	_expect(empty_state.get_player(0).hand.cards.size() == 1, "wild camp empty branch paid draw should leave only the drawn card in hand", failures)
	_expect(empty_state.get_player(0).master_hp == 8, "wild camp empty branch paid draw should not change master hp", failures)

static func _test_under_siege_front_debuff_and_disable_support(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _under_siege_decks(), 2009, [], _formal_options(2))
	var siege_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0008")
	var attacker_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var enemy_front = _find_hand_card_by_definition(state, 1, "qa_plain")
	var enemy_back = _find_hand_card_by_definition(state, 1, "qa_ranged")
	_expect(siege_id != "" and attacker_id != "" and enemy_front != "" and enemy_back != "", "under siege setup should provide both the tactic and battlefield units", failures)
	engine._deploy_hand_card_to_slot(state, 0, attacker_id, "front", 0, "test_under_siege_attacker")
	engine._deploy_hand_card_to_slot(state, 1, enemy_front, "front", 0, "test_under_siege_enemy_front")
	engine._deploy_hand_card_to_slot(state, 1, enemy_back, "back", 0, "test_under_siege_enemy_back")
	_expect(engine.get_legal_supporters(state, enemy_front, attacker_id) == [enemy_back], "under siege setup should start with a legal back-row supporter", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": siege_id,
		"row": "tactic",
		"col": -1
	})).ok, "under siege should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "under siege should resolve its row debuff and support lock")
	_expect(engine.get_card_power(state, enemy_front) == 1000, "under siege should reduce all enemy front-row power by 1000", failures)
	_expect(engine.get_card_power(state, enemy_back) == 3000, "under siege should not change enemy back-row power", failures)
	_expect(engine.get_legal_supporters(state, enemy_front, attacker_id).is_empty(), "under siege should disable enemy back-row support for the turn", failures)

static func _test_ritual_of_heaven_draw_and_calamity_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var raise_state = engine.create_game(_definitions(), _ritual_of_heaven_decks(), 2010, [], _formal_options(1))
	raise_state.calamity_value = 3
	var ritual_id = _find_hand_card_by_definition(raise_state, 0, "neutral_s01_0014")
	_expect(ritual_id != "", "ritual of heaven should be in opening hand for raise branch", failures)
	_expect(engine.apply_command(raise_state, GameCommand.create(0, "PlayCard", {
		"card_id": ritual_id,
		"row": "tactic",
		"col": -1
	})).ok, "ritual of heaven should play successfully for raise branch", failures)
	_resolve_top_stack(engine, raise_state, failures, "ritual of heaven should draw then ask for calamity adjustment")
	_expect(raise_state.get_player(0).hand.cards.size() == 1, "ritual of heaven should draw one card before the calamity choice", failures)
	_expect(_resolve_option_choice(engine, raise_state, "resolve_option_with_shared_cost", "raise_two"), "ritual of heaven should resolve the +2 calamity option", failures)
	_expect(raise_state.calamity_value == 5, "ritual of heaven should increase calamity value by 2", failures)

	var lower_engine = GameEngine.new()
	var lower_state = lower_engine.create_game(_definitions(), _ritual_of_heaven_decks(), 2011, [], _formal_options(1))
	lower_state.calamity_value = 1
	var lower_ritual_id = _find_hand_card_by_definition(lower_state, 0, "neutral_s01_0014")
	_expect(lower_ritual_id != "", "ritual of heaven should be in opening hand for lower branch", failures)
	_expect(lower_engine.apply_command(lower_state, GameCommand.create(0, "PlayCard", {
		"card_id": lower_ritual_id,
		"row": "tactic",
		"col": -1
	})).ok, "ritual of heaven should play successfully for lower branch", failures)
	_resolve_top_stack(lower_engine, lower_state, failures, "ritual of heaven lower branch should draw then ask for calamity adjustment")
	_expect(_resolve_option_choice(lower_engine, lower_state, "resolve_option_with_shared_cost", "lower_two"), "ritual of heaven should resolve the -2 calamity option", failures)
	_expect(lower_state.calamity_value == 0, "ritual of heaven should not reduce calamity value below 0", failures)

static func _test_all_out_attack_grants_charge_to_next_cheap_legion(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _all_out_attack_decks(), 2014, [], _formal_options(4))
	var tactic_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0012")
	var first_cheap_legion_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var second_cheap_legion_id = _find_second_hand_card_by_definition(state, 0, "qa_vanilla", first_cheap_legion_id)
	var enemy_legion_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(tactic_id != "" and first_cheap_legion_id != "" and second_cheap_legion_id != "" and enemy_legion_id != "", "all out attack setup should draw tactic, two cheap legions and enemy target", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	})).ok, "all out attack should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "all out attack should resolve and prepare the next cheap legion buff")
	engine._deploy_hand_card_to_slot(state, 1, enemy_legion_id, "front", 0, "test_all_out_attack_enemy_target")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_cheap_legion_id,
		"row": "front",
		"col": 0
	})).ok, "all out attack should allow playing the first cheap legion", failures)
	var first_instance_id = state.get_player(0).battle_front[0].occupant
	var enemy_instance_id = state.get_player(1).battle_front[0].occupant
	var first_attack_targets = engine.get_legal_attack_targets(state, first_instance_id)
	_expect(_targets_include_card(first_attack_targets, enemy_instance_id), "all out attack should give the next cheap legion charge so it can attack this turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_cheap_legion_id,
		"row": "front",
		"col": 1
	})).ok, "all out attack should allow playing the second cheap legion", failures)
	var second_instance_id = state.get_player(0).battle_front[1].occupant
	_expect(engine.get_legal_attack_targets(state, second_instance_id).is_empty(), "all out attack should only buff the first qualifying legion this turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": first_instance_id,
		"defender_id": enemy_instance_id
	})).ok, "all out attack should let the buffed first cheap legion declare an attack on the turn it entered", failures)

static func _test_yukimura_gains_charge_on_entry(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _yukimura_decks(), 20145, [], _formal_options(4))
	var yukimura_card_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0404")
	var enemy_legion_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(yukimura_card_id != "" and enemy_legion_id != "", "yukimura test should draw Yukimura and an enemy target", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_legion_id, "front", 0, "test_yukimura_enemy_target")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yukimura_card_id,
		"row": "front",
		"col": 0
	})).ok, "yukimura should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "yukimura entry trigger should resolve before charge is checked")
	var yukimura_instance_id = state.get_player(0).battle_front[0].occupant
	var enemy_instance_id = state.get_player(1).battle_front[0].occupant
	var targets = engine.get_legal_attack_targets(state, yukimura_instance_id)
	_expect(_targets_include_card(targets, enemy_instance_id), "yukimura should gain charge on entry and attack immediately", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": yukimura_instance_id,
		"defender_id": enemy_instance_id
	})).ok, "yukimura should be able to declare an attack on the turn it entered", failures)

static func _test_ambush_counters_stack_and_pending_attack(failures: Array[String]) -> void:
	var attack_engine = GameEngine.new()
	var attack_state = attack_engine.create_game(_definitions(), _ambush_decks(), 2015, [], _formal_options(3))
	var front_id = _find_hand_card_by_definition(attack_state, 0, "qa_plain")
	var counter_id = _find_hand_card_by_definition(attack_state, 0, "neutral_s01_0019")
	_expect(front_id != "" and counter_id != "", "ambush attack branch should draw the allied defender and counter tactic", failures)
	_expect(attack_engine.apply_command(attack_state, GameCommand.create(0, "PlayCard", {
		"card_id": front_id,
		"row": "front",
		"col": 0
	})).ok, "ambush attack branch should deploy the allied defender", failures)
	_expect(attack_engine.apply_command(attack_state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 1
	})).ok, "ambush attack branch should set the counter tactic during own main phase", failures)
	_advance_to_next_main(attack_engine, attack_state, failures, "ambush attack branch should advance to player 2 main")
	var enemy_attacker = _find_hand_card_by_definition(attack_state, 1, "qa_vanilla")
	_expect(enemy_attacker != "", "ambush attack branch should draw an enemy attacker", failures)
	_expect(attack_engine.apply_command(attack_state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_attacker,
		"row": "front",
		"col": 0
	})).ok, "ambush attack branch should deploy the enemy attacker", failures)
	_advance_to_next_main(attack_engine, attack_state, failures, "ambush attack branch should advance back to player 1 main")
	_advance_to_next_main(attack_engine, attack_state, failures, "ambush attack branch should advance to player 2 main attack turn")
	var attacker_instance_id = attack_state.get_player(1).battle_front[0].occupant
	var defender_instance_id = attack_state.get_player(0).battle_front[0].occupant
	_expect(attack_engine.apply_command(attack_state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	})).ok, "ambush attack branch should declare an attack", failures)
	var attack_actions = attack_engine.get_legal_actions(attack_state, 0)
	_expect(not _find_activate_action(attack_actions, counter_id, "ambush_response").is_empty(), "ambush should expose an activate action in the pending attack response window", failures)
	_expect(attack_engine.apply_command(attack_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "ambush_response",
		"target_card_id": defender_instance_id
	})).ok, "ambush should be activatable against a live pending attack", failures)
	_resolve_top_stack(attack_engine, attack_state, failures, "ambush attack branch should resolve from the counter stack")
	_expect(attack_engine.get_card_power(attack_state, defender_instance_id) == 4000, "ambush should give the selected allied defender +2000 power this turn during attack response", failures)

	var stack_engine = GameEngine.new()
	var stack_state = stack_engine.create_game(_definitions(), _ambush_decks(), 2018, [], _formal_options(3))
	var stack_front_id = _find_hand_card_by_definition(stack_state, 0, "qa_plain")
	var stack_counter_id = _find_hand_card_by_definition(stack_state, 0, "neutral_s01_0019")
	_expect(stack_front_id != "" and stack_counter_id != "", "ambush stack branch should draw the allied defender and counter tactic", failures)
	_expect(stack_engine.apply_command(stack_state, GameCommand.create(0, "PlayCard", {
		"card_id": stack_front_id,
		"row": "front",
		"col": 0
	})).ok, "ambush stack branch should deploy the allied defender", failures)
	_expect(stack_engine.apply_command(stack_state, GameCommand.create(0, "PlayCard", {
		"card_id": stack_counter_id,
		"row": "front",
		"col": 1
	})).ok, "ambush stack branch should set the counter tactic during own main phase", failures)
	_advance_to_next_main(stack_engine, stack_state, failures, "ambush stack branch should advance to player 2 main")
	var enemy_tactic = _find_hand_card_by_definition(stack_state, 1, "neutral_s01_0015")
	_expect(enemy_tactic != "", "ambush stack branch should draw an enemy tactic", failures)
	_expect(stack_engine.apply_command(stack_state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_tactic,
		"row": "tactic",
		"col": -1,
		"effect_id": "truce_offer"
	})).ok, "ambush stack branch should let the opponent play a tactic", failures)
	var stack_actions = stack_engine.get_legal_actions(stack_state, 0)
	var stack_defender_id = stack_state.get_player(0).battle_front[0].occupant
	_expect(not _find_activate_action(stack_actions, stack_counter_id, "ambush_response").is_empty(), "ambush should expose an activate action while the enemy tactic is on stack", failures)
	_expect(stack_engine.apply_command(stack_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": stack_counter_id,
		"effect_id": "ambush_response",
		"target_card_id": stack_defender_id
	})).ok, "ambush should be activatable while the enemy tactic is on stack", failures)
	_resolve_top_stack(stack_engine, stack_state, failures, "ambush stack branch should resolve the counter tactic first")
	_expect(stack_engine.get_card_power(stack_state, stack_defender_id) == 4000, "ambush should give the selected allied defender +2000 power this turn while responding to a stack effect", failures)

static func _test_fight_till_dawn_counter_buff_and_grave_draw(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _fight_till_dawn_decks(), 2016, [], _formal_options(3))
	var ally_front = _find_hand_card_by_definition(state, 0, "qa_plain")
	var ally_back = _find_hand_card_by_definition(state, 0, "qa_ranged")
	var counter_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0020")
	_expect(ally_front != "" and ally_back != "" and counter_id != "", "fight till dawn setup should draw allied units and the counter tactic", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_front,
		"row": "front",
		"col": 0
	})).ok, "fight till dawn should allow allied front deployment", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_back,
		"row": "back",
		"col": 0
	})).ok, "fight till dawn should allow allied back deployment", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 1
	})).ok, "fight till dawn should allow setting the counter tactic during own main phase", failures)
	var seeded = _seed_grave_from_deck(state, 0, 5)
	_expect(seeded.size() == 5, "fight till dawn draw branch should seed five grave cards", failures)
	_advance_to_next_main(engine, state, failures, "fight till dawn should advance to player 2 main for the attack turn")
	if state.active_player != 1 or state.phase != "main":
		failures.append("fight till dawn did not reach player 2 main for the draw branch")
		return
	var enemy_tactic = _find_hand_card_by_definition(state, 1, "neutral_s01_0012")
	var enemy_attacker = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(enemy_tactic != "" and enemy_attacker != "", "fight till dawn draw branch should draw an enemy tactic and attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_tactic,
		"row": "tactic",
		"col": -1
	})).ok, "fight till dawn draw branch should allow enemy tactic deployment", failures)
	var non_attack_actions = engine.get_legal_actions(state, 0)
	_expect(_find_activate_action(non_attack_actions, counter_id, "fight_till_dawn").is_empty(), "fight till dawn should not expose an activate action while only an enemy tactic is on stack", failures)
	_resolve_top_stack(engine, state, failures, "fight till dawn should stay inactive while the enemy tactic resolves")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_attacker,
		"row": "front",
		"col": 0
	})).ok, "fight till dawn draw branch should allow enemy attacker deployment", failures)
	_advance_to_next_main(engine, state, failures, "fight till dawn should advance through turns until player 2 can attack")
	_advance_to_next_main(engine, state, failures, "fight till dawn should return to player 2 main for the attack declaration")
	if state.active_player != 1 or state.phase != "main":
		failures.append("fight till dawn did not return to player 2 main for attack declaration")
		return
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var defender_instance_id = state.get_player(0).battle_front[0].occupant
	var ally_back_instance_id = state.get_player(0).battle_back[0].occupant
	var hand_before_counter = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	})).ok, "fight till dawn draw branch should declare an attack", failures)
	var counter_actions = engine.get_legal_actions(state, 0)
	_expect(not _find_activate_action(counter_actions, counter_id, "fight_till_dawn").is_empty(), "fight till dawn should expose an activate action from the facedown counter tactic during the opponent attack", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "fight_till_dawn"
	})).ok, "fight till dawn should be activatable from the facedown counter tactic during the opponent attack", failures)
	_resolve_top_stack(engine, state, failures, "fight till dawn draw branch should resolve from the counter stack")
	_expect(engine.get_card_power(state, defender_instance_id) == 3000, "fight till dawn should give the allied front legion +1000 this turn", failures)
	_expect(engine.get_card_power(state, ally_back_instance_id) == 4000, "fight till dawn should give the allied back legion +1000 this turn", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_counter + 1, "fight till dawn should draw one card when own grave has at least five cards", failures)

	var no_draw_engine = GameEngine.new()
	var no_draw_state = no_draw_engine.create_game(_definitions(), _fight_till_dawn_decks(), 2017, [], _formal_options(3))
	var no_draw_front = _find_hand_card_by_definition(no_draw_state, 0, "qa_plain")
	var no_draw_back = _find_hand_card_by_definition(no_draw_state, 0, "qa_ranged")
	var no_draw_counter = _find_hand_card_by_definition(no_draw_state, 0, "neutral_s01_0020")
	_expect(no_draw_front != "" and no_draw_back != "" and no_draw_counter != "", "fight till dawn no-draw setup should draw allied units and the counter tactic", failures)
	_expect(no_draw_engine.apply_command(no_draw_state, GameCommand.create(0, "PlayCard", {
		"card_id": no_draw_front,
		"row": "front",
		"col": 0
	})).ok, "fight till dawn no-draw branch should allow allied front deployment", failures)
	_expect(no_draw_engine.apply_command(no_draw_state, GameCommand.create(0, "PlayCard", {
		"card_id": no_draw_back,
		"row": "back",
		"col": 0
	})).ok, "fight till dawn no-draw branch should allow allied back deployment", failures)
	_expect(no_draw_engine.apply_command(no_draw_state, GameCommand.create(0, "PlayCard", {
		"card_id": no_draw_counter,
		"row": "front",
		"col": 1
	})).ok, "fight till dawn no-draw branch should allow setting the counter tactic during own main phase", failures)
	var seeded_short = _seed_grave_from_deck(no_draw_state, 0, 4)
	_expect(seeded_short.size() == 4, "fight till dawn no-draw branch should seed four grave cards", failures)
	_advance_to_next_main(no_draw_engine, no_draw_state, failures, "fight till dawn no-draw branch should advance to player 2 main")
	var no_draw_enemy = _find_hand_card_by_definition(no_draw_state, 1, "qa_vanilla")
	_expect(no_draw_enemy != "", "fight till dawn no-draw branch should draw an enemy attacker", failures)
	_expect(no_draw_engine.apply_command(no_draw_state, GameCommand.create(1, "PlayCard", {
		"card_id": no_draw_enemy,
		"row": "front",
		"col": 0
	})).ok, "fight till dawn no-draw branch should allow enemy attacker deployment", failures)
	_advance_to_next_main(no_draw_engine, no_draw_state, failures, "fight till dawn no-draw branch should advance through turns until player 2 can attack")
	_advance_to_next_main(no_draw_engine, no_draw_state, failures, "fight till dawn no-draw branch should return to player 2 main for the attack declaration")
	var no_draw_attacker_instance_id = no_draw_state.get_player(1).battle_front[0].occupant
	var no_draw_defender_instance_id = no_draw_state.get_player(0).battle_front[0].occupant
	var no_draw_back_instance_id = no_draw_state.get_player(0).battle_back[0].occupant
	var hand_before_no_draw = no_draw_state.get_player(0).hand.cards.size()
	_expect(no_draw_engine.apply_command(no_draw_state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": no_draw_attacker_instance_id,
		"defender_id": no_draw_defender_instance_id
	})).ok, "fight till dawn no-draw branch should declare an attack", failures)
	var no_draw_actions = no_draw_engine.get_legal_actions(no_draw_state, 0)
	_expect(not _find_activate_action(no_draw_actions, no_draw_counter, "fight_till_dawn").is_empty(), "fight till dawn should still expose an activate action when own grave has only four cards", failures)
	_expect(no_draw_engine.apply_command(no_draw_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": no_draw_counter,
		"effect_id": "fight_till_dawn"
	})).ok, "fight till dawn should still be activatable when own grave has only four cards", failures)
	_resolve_top_stack(no_draw_engine, no_draw_state, failures, "fight till dawn no-draw branch should resolve from the counter stack")
	_expect(no_draw_engine.get_card_power(no_draw_state, no_draw_defender_instance_id) == 3000, "fight till dawn no-draw branch should still buff the allied front legion", failures)
	_expect(no_draw_engine.get_card_power(no_draw_state, no_draw_back_instance_id) == 4000, "fight till dawn no-draw branch should still buff the allied back legion", failures)
	_expect(no_draw_state.get_player(0).hand.cards.size() == hand_before_no_draw, "fight till dawn should not draw when own grave has fewer than five cards", failures)

static func _test_fleeting_insight_hand_size_gate(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _fleeting_insight_decks(), 2012, [], _formal_options(4))
	var insight_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0014")
	_expect(insight_id != "", "fleeting insight should be in opening hand", failures)
	_expect(engine.get_castable_tactic_effects(state, 0, insight_id).size() == 1, "fleeting insight should be castable when hand size after play is at most 4", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": insight_id,
		"row": "tactic",
		"col": -1
	})).ok, "fleeting insight should play successfully when the hand-size condition is satisfied", failures)
	_resolve_top_stack(engine, state, failures, "fleeting insight should resolve and draw two cards")
	_expect(state.get_player(0).hand.cards.size() == 5, "fleeting insight should draw two cards after leaving hand", failures)

	var blocked_engine = GameEngine.new()
	var blocked_state = blocked_engine.create_game(_definitions(), _fleeting_insight_decks(), 2013, [], _formal_options(6))
	var blocked_insight_id = _find_hand_card_by_definition(blocked_state, 0, "neutral_s02_0014")
	_expect(blocked_insight_id != "", "fleeting insight should be in opening hand for blocked branch", failures)
	_expect(blocked_engine.get_castable_tactic_effects(blocked_state, 0, blocked_insight_id).is_empty(), "fleeting insight should not be castable when hand size after play would still exceed 4", failures)

static func _test_prayer_ritual_reveal_branches(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var agree_state = engine.create_game(_definitions(), _prayer_ritual_decks(), 2014, [], _formal_options(1))
	var prayer_id = _find_hand_card_by_definition(agree_state, 0, "neutral_s02_0012")
	_expect(prayer_id != "", "prayer ritual should be in opening hand for agree branch", failures)
	_expect(engine.apply_command(agree_state, GameCommand.create(0, "PlayCard", {
		"card_id": prayer_id,
		"row": "tactic",
		"col": -1
	})).ok, "prayer ritual should play successfully for agree branch", failures)
	_resolve_top_stack(engine, agree_state, failures, "prayer ritual should ask the opponent whether to reveal calamity")
	_expect(_resolve_option_choice(engine, agree_state, "prayer_reveal_offer", "agree"), "prayer ritual agree branch should resolve", failures)
	_expect(agree_state.current_calamity.is_empty(), "prayer ritual agree branch should not directly reveal or开启 the next calamity", failures)
	_expect(_has_event_type(agree_state, "CardsRevealedToAll"), "prayer ritual agree branch should publicly reveal the next calamity card to both players", failures)
	_expect(not _has_event_type(agree_state, "CalamityRevealed"), "prayer ritual agree branch should not log a calamity trigger reveal event", failures)

	var decline_engine = GameEngine.new()
	var decline_state = decline_engine.create_game(_definitions(), _prayer_ritual_decks(), 2015, [], _formal_options(1))
	var decline_prayer_id = _find_hand_card_by_definition(decline_state, 0, "neutral_s02_0012")
	_expect(decline_prayer_id != "", "prayer ritual should be in opening hand for decline branch", failures)
	_expect(decline_engine.apply_command(decline_state, GameCommand.create(0, "PlayCard", {
		"card_id": decline_prayer_id,
		"row": "tactic",
		"col": -1
	})).ok, "prayer ritual should play successfully for decline branch", failures)
	_resolve_top_stack(decline_engine, decline_state, failures, "prayer ritual decline branch should ask the opponent whether to reveal calamity")
	_expect(_resolve_option_choice(decline_engine, decline_state, "prayer_reveal_offer", "decline"), "prayer ritual decline branch should resolve opponent refusal", failures)
	_expect(_resolve_option_choice(decline_engine, decline_state, "resolve_option_with_shared_cost", "preview"), "prayer ritual decline branch should allow the caster to pay 1 morale and privately view the next calamity", failures)
	_expect(decline_state.current_calamity.is_empty(), "prayer ritual paid decline branch should still not directly reveal or开启 the next calamity", failures)
	_expect(decline_state.get_player(0).spent_cost_area.cards.size() == 2, "prayer ritual paid decline branch should spend one morale in addition to the card's play cost", failures)
	_expect(_has_event_type(decline_state, "CardsViewedPrivately"), "prayer ritual paid decline branch should log a private calamity preview event", failures)
	_expect(not _has_event_type(decline_state, "CalamityRevealed"), "prayer ritual paid decline branch should not log a calamity reveal trigger event", failures)

static func _test_crazy_alice_kill_readies_once_per_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _crazy_alice_decks(), 2023, [], _formal_options(1))
	var alice_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0002")
	_expect(alice_id != "", "crazy alice test should draw 疯狂的爱丽丝", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": alice_id,
		"row": "front",
		"col": 0
	})).ok, "crazy alice test should deploy 疯狂的爱丽丝", failures)
	_advance_to_next_main(engine, state, failures, "crazy alice test should advance to the opponent main phase")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_equal")
	_expect(enemy_id != "", "crazy alice test should draw an equal-power enemy defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_id,
		"row": "front",
		"col": 0
	})).ok, "crazy alice test should deploy the enemy defender", failures)
	_advance_to_next_main(engine, state, failures, "crazy alice test should return to the controller main phase")
	if state.active_player != 0 or state.phase != "main":
		failures.append("crazy alice test did not return to controller main phase")
		return
	var alice_instance_id = state.get_player(0).battle_front[0].occupant
	var defender_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": alice_instance_id,
		"defender_id": defender_instance_id
	})).ok, "crazy alice test should declare the attack", failures)
	_drain_stack_and_choices(engine, state, failures, "crazy alice kill attack should fully resolve")
	var alice_instance = state.card_instances.get(alice_instance_id)
	_expect(state.get_player(1).grave.cards.has(defender_instance_id), "crazy alice should defeat the equal-power defender", failures)
	_expect(state.get_player(0).battle_front[0].occupant == alice_instance_id, "crazy alice should survive combat because it attacks without loss", failures)
	_expect(alice_instance != null and alice_instance.orientation == "active", "crazy alice should ready itself after killing a unit on its own turn", failures)
	_expect(alice_instance != null and not alice_instance.has_attacked_this_turn, "crazy alice ready trigger should clear has_attacked_this_turn", failures)
	_expect(_has_event_type(state, "CardReadied"), "crazy alice kill trigger should log CardReadied", failures)

static func _test_louis_mandrin_frontline_taunt_and_opponent_turn_power(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _louis_mandrin_decks(), 2021, [], _formal_options(2))
	var plain_id = _find_hand_card_by_definition(state, 0, "qa_plain")
	var mandrin_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0004")
	_expect(plain_id != "" and mandrin_id != "", "louis mandrin frontline test should draw both a plain defender and 路易芒德兰", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": plain_id,
		"row": "front",
		"col": 0
	})).ok, "louis mandrin frontline test should deploy the plain defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mandrin_id,
		"row": "front",
		"col": 1
	})).ok, "louis mandrin frontline test should deploy 路易芒德兰 to the front row", failures)
	var mandrin_instance_id = state.get_player(0).battle_front[1].occupant
	_expect(engine.get_card_power(state, mandrin_instance_id) == 5000, "louis mandrin should keep base power on its controller turn", failures)
	_advance_to_next_main(engine, state, failures, "louis mandrin frontline test should advance to the opponent main phase")
	if state.active_player != 1 or state.phase != "main":
		failures.append("louis mandrin frontline test did not reach opponent main phase")
		return
	_expect(engine.get_card_power(state, mandrin_instance_id) == 6000, "louis mandrin should gain 1000 power on the opponent turn while in the front row", failures)
	var attacker_card_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0410")
	_expect(attacker_card_id != "", "louis mandrin frontline test should draw an enemy attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "louis mandrin frontline test should deploy the enemy attacker", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var targets = engine.get_legal_attack_targets(state, attacker_instance_id)
	_expect(targets.size() == 1, "louis mandrin front-row taunt should narrow legal targets to exactly one unit", failures)
	if targets.size() == 1:
		_expect(str(targets[0].get("defender_id", "")) == mandrin_instance_id, "louis mandrin should be the only legal attack target while front-row taunt is active", failures)

static func _test_louis_mandrin_back_row_does_not_force_taunt(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _louis_mandrin_decks(), 2022, [], _formal_options(2))
	var plain_id = _find_hand_card_by_definition(state, 0, "qa_plain")
	var mandrin_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0004")
	_expect(plain_id != "" and mandrin_id != "", "louis mandrin back-row test should draw both a plain defender and 路易芒德兰", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": plain_id,
		"row": "front",
		"col": 0
	})).ok, "louis mandrin back-row test should deploy the plain defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mandrin_id,
		"row": "back",
		"col": 0
	})).ok, "louis mandrin back-row test should deploy 路易芒德兰 to the back row", failures)
	var mandrin_instance_id = state.get_player(0).battle_back[0].occupant
	_expect(engine.get_card_power(state, mandrin_instance_id) == 5000, "louis mandrin should not gain power on its controller turn while in the back row", failures)
	_advance_to_next_main(engine, state, failures, "louis mandrin back-row test should advance to the opponent main phase")
	if state.active_player != 1 or state.phase != "main":
		failures.append("louis mandrin back-row test did not reach opponent main phase")
		return
	_expect(engine.get_card_power(state, mandrin_instance_id) == 5000, "louis mandrin should not gain power on the opponent turn while in the back row", failures)
	var attacker_card_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0410")
	_expect(attacker_card_id != "", "louis mandrin back-row test should draw an enemy attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "louis mandrin back-row test should deploy the enemy attacker", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var targets = engine.get_legal_attack_targets(state, attacker_instance_id)
	_expect(_targets_include_card(targets, state.get_player(0).battle_front[0].occupant), "back-row 路易芒德兰 should not force attacks away from the front-row defender", failures)
	_expect(targets.size() >= 2, "back-row 路易芒德兰 should leave multiple legal attack targets available", failures)

static func _test_truce_offer_branches(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var agree_state = engine.create_game(_definitions(), _truce_offer_decks(), 2018, [], _formal_options(1))
	var truce_id = _find_hand_card_by_definition(agree_state, 0, "neutral_s01_0015")
	_expect(truce_id != "", "truce offer agree branch should draw 议和谈判", failures)
	_expect(engine.apply_command(agree_state, GameCommand.create(0, "PlayCard", {
		"card_id": truce_id,
		"row": "tactic",
		"col": -1
	})).ok, "truce offer agree branch should play successfully", failures)
	_resolve_top_stack(engine, agree_state, failures, "truce offer agree branch should resolve to opponent choice")
	_expect(_resolve_option_choice(engine, agree_state, "truce_offer", "agree"), "truce offer agree branch should resolve the opponent agreement", failures)
	_expect(agree_state.get_player(0).hand.cards.size() == 2, "truce offer agree branch should let the caster draw once more after the opponent agrees", failures)
	_expect(agree_state.get_player(1).hand.cards.size() == 2, "truce offer agree branch should let the opponent also draw one extra card", failures)

	var decline_engine = GameEngine.new()
	var decline_state = decline_engine.create_game(_definitions(), _truce_offer_decks(), 2019, [], _formal_options(1))
	var decline_truce_id = _find_hand_card_by_definition(decline_state, 0, "neutral_s01_0015")
	_expect(decline_truce_id != "", "truce offer decline branch should draw 议和谈判", failures)
	_expect(decline_engine.apply_command(decline_state, GameCommand.create(0, "PlayCard", {
		"card_id": decline_truce_id,
		"row": "tactic",
		"col": -1
	})).ok, "truce offer decline branch should play successfully", failures)
	_resolve_top_stack(decline_engine, decline_state, failures, "truce offer decline branch should resolve to opponent choice")
	_expect(_resolve_option_choice(decline_engine, decline_state, "truce_offer", "decline"), "truce offer decline branch should resolve the opponent refusal", failures)
	_expect(decline_state.get_player(0).hand.cards.size() == 1, "truce offer decline branch should only keep the self draw", failures)
	_expect(decline_state.get_player(1).hand.cards.size() == 1, "truce offer decline branch should not give the opponent an extra draw", failures)

static func _test_absolute_defense_counters_pending_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _absolute_defense_decks(), 2020, [], _formal_options(3))
	var defender_id = _find_hand_card_by_definition(state, 0, "qa_plain")
	var counter_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0016")
	var discard_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(defender_id != "" and counter_id != "" and discard_id != "", "absolute defense setup should draw defender, counter tactic and discard cost card", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": defender_id,
		"row": "front",
		"col": 0
	})).ok, "absolute defense setup should deploy the allied defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 1
	})).ok, "absolute defense setup should allow setting the counter tactic during own main phase", failures)
	_advance_to_next_main(engine, state, failures, "absolute defense setup should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("absolute defense setup did not reach player 2 main")
		return
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(attacker_id != "", "absolute defense setup should draw an enemy attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "absolute defense setup should deploy the enemy attacker", failures)
	_advance_to_next_main(engine, state, failures, "absolute defense setup should advance through turns until the attacker can act")
	_advance_to_next_main(engine, state, failures, "absolute defense setup should return to player 2 main for the live attack")
	if state.active_player != 1 or state.phase != "main":
		failures.append("absolute defense setup did not return to player 2 main for attack")
		return
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var defender_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	})).ok, "absolute defense test should declare an attack", failures)
	_expect(not state.pending_attack.is_empty(), "absolute defense test should create a pending attack window", failures)
	var response_actions = engine.get_legal_actions(state, 0)
	_expect(not _find_activate_action(response_actions, counter_id, "absolute_defense").is_empty(), "absolute defense should expose an activate action against the live pending attack", failures)
	var discarded_by_cost = str(state.get_player(0).hand.cards[0]) if not state.get_player(0).hand.cards.is_empty() else ""
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "absolute_defense",
		"target_stack_id": "__pending_attack__"
	})).ok, "absolute defense should be activatable against the live pending attack", failures)
	_resolve_top_stack(engine, state, failures, "absolute defense should resolve from the counter stack")
	_expect(state.pending_attack.is_empty(), "absolute defense should clear the pending attack after resolution", failures)
	_expect(state.stack.is_empty(), "absolute defense should leave no stack items after resolution", failures)
	_expect(state.get_player(0).grave.cards.has(counter_id), "absolute defense card should move to grave after resolving", failures)
	_expect(not discarded_by_cost.is_empty() and state.get_player(0).grave.cards.has(discarded_by_cost), "absolute defense should discard one extra hand card as its activation cost", failures)

static func _test_absolute_defense_counters_master_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _absolute_defense_decks(), 2024, [], _formal_options(3))
	var counter_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0016")
	_expect(counter_id != "", "absolute defense master attack test should draw the counter tactic", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 1
	})).ok, "absolute defense master attack test should allow setting the counter tactic during own main phase", failures)
	_advance_to_next_main(engine, state, failures, "absolute defense master attack test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("absolute defense master attack test did not reach player 2 main")
		return
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(attacker_id != "", "absolute defense master attack test should draw an enemy attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "absolute defense master attack test should deploy the enemy attacker", failures)
	_advance_to_next_main(engine, state, failures, "absolute defense master attack test should advance through turns until the attacker can act")
	_advance_to_next_main(engine, state, failures, "absolute defense master attack test should return to player 2 main for the live attack")
	if state.active_player != 1 or state.phase != "main":
		failures.append("absolute defense master attack test did not return to player 2 main for attack")
		return
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var master_target := _find_master_target(engine.get_legal_attack_targets(state, attacker_instance_id), 0)
	_expect(not master_target.is_empty(), "absolute defense master attack test should be able to target the defending master", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"target_player": 0
	})).ok, "absolute defense should allow declaring an attack against the defending master", failures)
	_expect(not state.pending_attack.is_empty() and str(state.pending_attack.get("target_kind", "")) == "master", "absolute defense master attack test should create a pending master attack", failures)
	var response_actions = engine.get_legal_actions(state, 0)
	_expect(not _find_activate_action(response_actions, counter_id, "absolute_defense").is_empty(), "absolute defense should expose an activate action against a pending master attack", failures)
	var discarded_by_cost = str(state.get_player(0).hand.cards[0]) if not state.get_player(0).hand.cards.is_empty() else ""
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "absolute_defense",
		"target_stack_id": "__pending_attack__"
	})).ok, "absolute defense should be activatable against a pending master attack", failures)
	_resolve_top_stack(engine, state, failures, "absolute defense master attack should resolve from the counter stack")
	_expect(state.pending_attack.is_empty(), "absolute defense should clear the pending master attack after resolution", failures)
	_expect(state.players[0].master_hp == 20, "absolute defense should prevent damage from the master attack", failures)
	_expect(state.get_player(0).grave.cards.has(counter_id), "absolute defense card should move to grave after countering a master attack", failures)
	_expect(not discarded_by_cost.is_empty() and state.get_player(0).grave.cards.has(discarded_by_cost), "absolute defense should still pay its discard cost when countering a master attack", failures)

static func _test_absolute_defense_does_not_respond_to_own_actions(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _absolute_defense_yukimura_decks(), 2025, [], _formal_options(6))
	var counter_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0016")
	var yukimura_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0404")
	var enemy_legion_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(counter_id != "" and yukimura_id != "" and enemy_legion_id != "", "absolute defense self-response test should draw counter tactic, yukimura and enemy target", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_legion_id, "front", 0, "absolute_defense_self_response_enemy")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 1
	})).ok, "absolute defense self-response test should allow setting the counter tactic", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yukimura_id,
		"row": "front",
		"col": 0
	})).ok, "absolute defense self-response test should play yukimura successfully", failures)
	_expect(not state.stack.is_empty(), "absolute defense self-response test should create yukimura's entry stack item", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "absolute defense self-response test should allow the opponent to pass on yukimura's entry effect", failures)
	var own_stack_actions = engine.get_legal_actions(state, 0)
	_expect(_find_activate_action(own_stack_actions, counter_id, "absolute_defense").is_empty(), "absolute defense should not expose an activate action against your own entry trigger", failures)
	_resolve_top_stack(engine, state, failures, "absolute defense self-response test should resolve yukimura's entry stack item")
	var yukimura_instance_id = state.get_player(0).battle_front[0].occupant
	var enemy_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(yukimura_instance_id != "" and enemy_instance_id != "", "absolute defense self-response test should keep both battle participants on board", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": yukimura_instance_id,
		"defender_id": enemy_instance_id
	})).ok, "absolute defense self-response test should allow yukimura to attack after gaining charge", failures)
	_expect(not state.pending_attack.is_empty(), "absolute defense self-response test should create a pending attack window", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "absolute defense self-response test should allow the defender to pass on yukimura's attack", failures)
	var own_attack_actions = engine.get_legal_actions(state, 0)
	_expect(_find_activate_action(own_attack_actions, counter_id, "absolute_defense").is_empty(), "absolute defense should not expose an activate action against your own pending attack", failures)

static func _test_strategic_transfer_bounce_and_buff(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _strategic_transfer_decks(), 2007, [], _formal_options(3))
	var bounce_target = _find_hand_card_by_definition(state, 0, "qa_plain")
	var buff_target = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var tactic_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0009")
	_expect(bounce_target != "" and buff_target != "" and tactic_id != "", "strategic transfer setup should put both allied legions and tactic in hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": bounce_target,
		"row": "front",
		"col": 0
	})).ok, "bounce target should enter battlefield", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": buff_target,
		"row": "front",
		"col": 1
	})).ok, "buff target should enter battlefield", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"target_card_id": bounce_target
	})).ok, "strategic transfer should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "strategic transfer should resolve its bounce step")
	_expect(_resolve_candidate_choice(engine, state, "modify_power_until_turn_end", [buff_target]), "strategic transfer should choose a legion to buff", failures)
	_expect(state.players[0].battle_front[0].occupant == "", "strategic transfer should return the chosen allied legion to hand", failures)
	_expect(state.get_player(0).hand.cards.has(bounce_target), "strategic transfer should put the bounced legion back into hand", failures)
	_expect(engine.get_card_power(state, buff_target) == 5000, "strategic transfer should give the selected legion +2000 power this turn", failures)

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

static func _golden_harald_decks() -> Array:
	return [
		["asgard_s01_0302", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _arrow_barrage_decks() -> Array:
	return [
		["neutral_s01_0005", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_ranged", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _odell_decks() -> Array:
	return [
		["asgard_s01_0313", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _odell_from_deck_decks() -> Array:
	return [
		["asgard_s01_0313", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _ivar_decks() -> Array:
	return [
		["asgard_s01_0315", "asgard_s01_0302", "neutral_s01_0006", "asgard_s01_0313", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _evil_ritual_decks() -> Array:
	return [
		["neutral_s01_0006", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _wild_camp_decks() -> Array:
	return [
		["neutral_s01_0007", "asgard_s01_0313", "takamagahara_s01_0401", "neutral_s01_0006", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _under_siege_decks() -> Array:
	return [
		["neutral_s01_0008", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_ranged", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _wild_camp_metadata() -> Array:
	return [
		{"name": "Asgard", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 11, "master_max_hp": 12},
		{"name": "Takamagahara", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	]

static func _ritual_of_heaven_decks() -> Array:
	return [
		["neutral_s01_0014", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _fight_till_dawn_decks() -> Array:
	return [
		["qa_plain", "qa_ranged", "neutral_s01_0020", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["neutral_s01_0012", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _truce_offer_decks() -> Array:
	return [
		["neutral_s01_0015", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _absolute_defense_decks() -> Array:
	return [
		["qa_plain", "neutral_s01_0016", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _absolute_defense_yukimura_decks() -> Array:
	return [
		["neutral_s01_0016", "takamagahara_s01_0404", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _ambush_decks() -> Array:
	return [
		["qa_plain", "neutral_s01_0019", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "neutral_s01_0015", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _all_out_attack_decks() -> Array:
	return [
		["neutral_s01_0012", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _yukimura_decks() -> Array:
	return [
		["takamagahara_s01_0404", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"],
		["qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _louis_mandrin_decks() -> Array:
	return [
		["qa_plain", "neutral_s02_0004", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["takamagahara_s01_0410", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _crazy_alice_decks() -> Array:
	return [
		["neutral_s02_0002", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_equal", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _fleeting_insight_decks() -> Array:
	return [
		["neutral_s02_0014", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _prayer_ritual_decks() -> Array:
	return [
		["neutral_s02_0012", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _strategic_transfer_decks() -> Array:
	return [
		["neutral_s01_0009", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
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

static func _find_second_hand_card_by_definition(state, player_id: int, definition_id: String, exclude_card_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		if card_id == exclude_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _find_candidate_by_definition(state, card_ids, definition_id: String) -> String:
	if not (card_ids is Array):
		return ""
	for raw_card_id in card_ids:
		var card_id = str(raw_card_id)
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _find_deck_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).deck.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return str(card_id)
	return ""

static func _find_activate_action(actions: Array, source_id: String, effect_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("kind", "")) != "activate_effect":
			continue
		var payload = action.get("payload_template", {})
		if str(payload.get("source_id", "")) == source_id and str(payload.get("effect_id", "")) == effect_id:
			return action
	return {}

static func _targets_include_card(targets, defender_id: String) -> bool:
	if not (targets is Array):
		return false
	for target in targets:
		if str(target.get("defender_id", "")) == defender_id:
			return true
	return false

static func _find_master_target(targets, target_player: int) -> Dictionary:
	if not (targets is Array):
		return {}
	for target in targets:
		if str(target.get("target_kind", "")) != "master":
			continue
		if int(target.get("target_player", -1)) == target_player:
			return target
	return {}

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _seed_grave_from_deck(state, player_id: int, count: int) -> Array[String]:
	var moved: Array[String] = []
	var player = state.get_player(player_id)
	for _i in range(count):
		if player.deck.cards.is_empty():
			break
		var card_id = str(player.deck.cards[0])
		player.deck.remove_card(card_id)
		player.grave.add_card(card_id)
		var instance = state.card_instances.get(card_id)
		if instance != null:
			instance.zone = "grave"
			instance.position = {}
		moved.append(card_id)
	return moved

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
