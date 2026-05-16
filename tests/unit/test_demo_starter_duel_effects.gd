extends RefCounted
class_name TestDemoStarterDuelEffects

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_susanoo_can_manifest_kusanagi(failures)
	_test_susanoo_manifest_requires_kusanagi_in_artifact_zone(failures)
	_test_kusanagi_manifest_from_artifact_zone_keeps_prior_entry_turn(failures)
	_test_kusanagi_battlefield_and_artifact_zone_can_coexist_and_activate_separately(failures)
	_test_kusanagi_frontline_attack_and_activate_are_independent_once_each_turn(failures)
	_test_kusanagi_leaving_frontline_can_return_to_deck_top(failures)
	_test_kusanagi_returned_to_deck_top_draws_face_up_and_playable(failures)
	_test_susanoo_targeted_master_effect_exposes_targets(failures)
	_test_amaterasu_ready_morale_requires_manual_discard_choice(failures)
	_test_truce_offer_creates_option_choice(failures)
	_test_asgard_faction_morale_prompts_optional_heal_when_master_hp_is_low(failures)
	_test_asgard_faction_morale_skips_optional_heal_when_master_hp_is_high(failures)
	_test_asgard_s02_faction_morale_is_exposed_from_morale_source(failures)
	_test_loki_recycle_heal_uses_candidate_choice(failures)
	_test_loki_draw_discard_requires_hand_choice(failures)
	_test_lagertha_gains_power_on_opponent_turn(failures)
	_test_lagertha_back_row_does_not_force_taunt_targets(failures)
	_test_oiran_search_then_ready_morale(failures)
	_test_oiran_search_chooses_card_then_orders_remaining_bottom(failures)
	_test_oiran_search_cancel_does_not_deadlock(failures)
	_test_oiran_reorder_cancel_uses_default_bottom_order(failures)
	_test_honda_attack_trigger_resolves_before_attack_damage(failures)
	_test_honda_attack_cost_modifier_stacks_across_multiple_attacks(failures)
	_test_olaf_low_hp_discount_applies_on_play(failures)
	_test_olaf_attack_recycle_grants_bonus_damage(failures)
	_test_olaf_death_trigger_draws_then_discards(failures)
	_test_gustav_attack_cycle_buffs_and_readies_once_per_turn(failures)
	_test_komatsu_enter_buffs_other_frontline_takamagahara(failures)
	_test_komatsu_attack_buffs_other_frontline_takamagahara(failures)
	_test_counter_tactic_cannot_be_set_to_front_row(failures)
	_test_hiromasa_enters_draws_and_disables_enemy_counter_tactic(failures)
	_test_hiromasa_targeted_absolute_defense_can_counter_the_disable(failures)
	_test_yoshitsune_manual_move_targets_any_empty_slot_and_updates_display_power(failures)
	_test_yoshitsune_repositions_backline_and_draws_on_kill(failures)
	_test_yoshitsune_backline_keeps_4000_when_defending(failures)
	_test_hunt_execute_destroys_enemy_and_recycles_grave_cards(failures)
	_test_hunt_execute_requires_four_grave_cards_to_cast(failures)
	_test_kusanagi_enters_destroy_and_supports_allies(failures)
	_test_teach_enter_loot_and_death_refill(failures)
	_test_hanzo_can_reveal_on_entry_turn(failures)
	_test_hanzo_conceals_then_reveals_for_frontline_ranged_pressure(failures)
	_test_tomoe_backline_ranged_attack_stays_lossless(failures)
	_test_mercenary_legion_repositions_and_counters_pending_attack_from_hand(failures)
	_test_egil_enter_effect_damages_self_mills_and_weakens_enemy(failures)
	_test_egil_revived_from_grave_still_triggers_enter_effect(failures)
	_test_legacy_cardplayed_entry_trigger_still_fires_on_revive(failures)
	_test_egil_enter_effect_kills_enemy_reduced_to_zero(failures)
	_test_valkyrie_call_revives_and_waives_damage_at_low_hp(failures)
	_test_bjorn_discount_and_death_return_cycle(failures)
	_test_bjorn_death_trigger_requires_four_other_grave_cards(failures)
	_test_kogoro_attack_returns_to_deck_top_and_readies_morale(failures)
	_test_kogoro_dead_source_skips_optional_trigger_prompt(failures)
	_test_musashi_gains_charge_only_when_frontline_is_empty_and_draws_on_attack(failures)
	_test_ragnar_requires_play_option_and_gains_charge_from_blood_price(failures)
	_test_erik_master_hit_discard_does_not_trigger_when_blocked(failures)
	_test_erik_blood_price_master_hit_discard_and_death_revive(failures)
	_test_harald_blood_price_entry_damage_and_death_strike(failures)
	_test_alvilda_sacrifices_into_level2_legion_and_salvages_grave_card(failures)
	_test_alvilda_skips_deploy_choice_when_no_level2_in_hand(failures)
	_test_alvilda_real_death_prompts_salvage_choice(failures)
	return failures

static func _test_susanoo_can_manifest_kusanagi(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1301, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "susanoo manifest test should add morale for playing and activating 草薙剑", failures)
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(not kusanagi_id.is_empty(), "susanoo manifest test should draw 草薙剑", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kusanagi_id,
		"row": "artifact",
		"col": -1
	})).ok, "susanoo manifest test should first play 草薙剑 into the artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "susanoo manifest test enter first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "susanoo manifest test enter second pass should resolve", failures)
	var result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "susanoo_manifest_kusanagi"
	}))
	_expect(result.ok, "susanoo manifest effect should activate", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "susanoo manifest first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "susanoo manifest second pass should resolve into a front-slot choice", failures)
	_expect(state.pending_choices.size() == 1, "susanoo manifest should request a front-slot choice before placing 草薙剑", failures)
	if state.pending_choices.is_empty():
		return
	var manifest_choice: Dictionary = state.pending_choices[0]
	_expect(str(manifest_choice.get("operation", "")) == "manifest_kusanagi_to_slot", "susanoo manifest should pause on the front-slot choice", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(manifest_choice.get("choice_id", "")),
		"selected_option": "front:0"
	})).ok, "susanoo manifest front-slot choice should resolve", failures)
	var manifested_id = state.get_player(0).battle_front[0].occupant
	_expect(not manifested_id.is_empty(), "susanoo manifest should place a card into the front row", failures)
	var manifested_instance = state.card_instances.get(manifested_id)
	_expect(manifested_instance != null and manifested_instance.definition_id == "takamagahara_s01_0417", "susanoo manifest should place 草薙剑", failures)
	_expect(engine.get_card_power(state, manifested_id) == 5000, "manifested 草薙剑 should become 5000 power", failures)
	_expect(engine.get_legal_attack_targets(state, manifested_id).is_empty(), "freshly manifested 草薙剑 should not attack on the same turn it entered", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for manifested kusanagi target setup should succeed")
	var enemy_legion_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	if enemy_legion_id == "":
		enemy_legion_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	_expect(enemy_legion_id != "", "enemy should have a legion to test manifested kusanagi combat", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 4
	})).ok, "manifested kusanagi combat test should add morale for player 2", failures)
	if enemy_legion_id != "":
		_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
			"card_id": enemy_legion_id,
			"row": "front",
			"col": 0
		})).ok, "enemy should deploy a legion so manifested kusanagi can be attacked", failures)
		var enemy_instance = state.card_instances.get(enemy_legion_id)
		if enemy_instance != null:
			enemy_instance.entered_turn = state.turn_number - 1
			enemy_instance.orientation = "active"
		var enemy_targets = engine.get_legal_attack_targets(state, enemy_legion_id)
		var can_attack_manifested := false
		for target in enemy_targets:
			if str(target.get("defender_id", "")) == manifested_id:
				can_attack_manifested = true
				break
		_expect(can_attack_manifested, "manifested kusanagi should be attackable like a legion", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for manifested kusanagi attack test should succeed")
	var manifested_targets = engine.get_legal_attack_targets(state, manifested_id)
	_expect(not manifested_targets.is_empty(), "manifested kusanagi should be able to declare attacks like a legion", failures)
	_expect(_has_event_type(state, "MasterCardManifested"), "susanoo manifest should log MasterCardManifested", failures)

static func _test_susanoo_manifest_requires_kusanagi_in_artifact_zone(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1302, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "susanoo manifest availability test should add morale", failures)
	var morale_before = MoraleActions.count_active_morale(state, 0)
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(not kusanagi_id.is_empty(), "susanoo manifest availability test should draw 草薙剑 into hand", failures)
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "susanoo_manifest_kusanagi"
	}))
	_expect(not activate.ok and str(activate.get("code", "")) == "EFFECT_UNAVAILABLE", "susanoo should not manifest 草薙剑 unless it is in the artifact zone", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == morale_before, "failed susanoo manifest should not consume morale", failures)
	_expect(state.get_player(0).hand.cards.has(kusanagi_id), "failed susanoo manifest should not move 草薙剑 out of hand", failures)

static func _test_kusanagi_manifest_from_artifact_zone_keeps_prior_entry_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"takamagahara_s01_0416",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1324, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "artifact-zone kusanagi test should add morale for playing 草薙剑", failures)
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(not kusanagi_id.is_empty(), "artifact-zone kusanagi test should draw 草薙剑", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kusanagi_id,
		"row": "artifact",
		"col": -1
	})).ok, "artifact-zone kusanagi test should first play 草薙剑 into the artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "artifact-zone kusanagi enter first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "artifact-zone kusanagi enter second pass should resolve", failures)
	_advance_to_next_main(engine, state, failures, "artifact-zone kusanagi test should reach player 2 main")
	_advance_to_next_main(engine, state, failures, "artifact-zone kusanagi test should return to player 1 main")
	var artifact_instance = state.card_instances.get(kusanagi_id)
	_expect(artifact_instance != null and str(artifact_instance.zone) == "artifact_zone", "artifact-zone kusanagi should remain in the artifact zone before being manifested", failures)
	var prior_entered_turn := int(artifact_instance.entered_turn) if artifact_instance != null else -1
	var result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "susanoo_manifest_kusanagi"
	}))
	_expect(result.ok, "artifact-zone kusanagi should be manifestable by 须佐之男", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "artifact-zone kusanagi manifest first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "artifact-zone kusanagi manifest second pass should resolve into a front-slot choice", failures)
	_expect(state.pending_choices.size() == 1, "artifact-zone kusanagi manifest should request a front-slot choice", failures)
	if state.pending_choices.is_empty():
		return
	var manifest_choice: Dictionary = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(manifest_choice.get("choice_id", "")),
		"selected_option": "front:0"
	})).ok, "artifact-zone kusanagi front-slot choice should resolve", failures)
	var manifested_id = state.get_player(0).battle_front[0].occupant
	_expect(manifested_id == kusanagi_id, "artifact-zone kusanagi should move from artifact zone to the selected front slot", failures)
	var manifested_instance = state.card_instances.get(manifested_id)
	_expect(manifested_instance != null and int(manifested_instance.entered_turn) == prior_entered_turn, "manifesting from an older artifact zone should keep 草薙剑's prior entered turn", failures)
	var manifested_targets = engine.get_legal_attack_targets(state, manifested_id)
	_expect(not manifested_targets.is_empty(), "草薙剑 already resting in the artifact zone from a previous turn should attack immediately after being manifested", failures)

static func _test_kusanagi_battlefield_and_artifact_zone_can_coexist_and_activate_separately(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"takamagahara_s01_0417",
			"takamagahara_s01_0416",
			"takamagahara_s01_0418",
			"neutral_s01_0015",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0318",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0316"
		]
	], 1326, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 10
	})).ok, "coexisting kusanagi test should add morale for player 1", failures)
	var ally_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	_expect(ally_id != "", "coexisting kusanagi test should draw an allied takamagahara legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 0
	})).ok, "coexisting kusanagi test should deploy the allied legion first", failures)
	_drain_stack_and_choices(engine, state, failures, "coexisting kusanagi allied legion setup should resolve cleanly")
	var first_kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(first_kusanagi_id != "", "coexisting kusanagi test should draw the first 草薙剑", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_kusanagi_id,
		"row": "artifact",
		"col": -1
	})).ok, "coexisting kusanagi test should play the first 草薙剑 into the artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "coexisting kusanagi first 草薙剑 enter first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "coexisting kusanagi first 草薙剑 enter second pass should resolve", failures)
	_advance_to_next_main(engine, state, failures, "coexisting kusanagi test should advance to player 2 main")
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "coexisting kusanagi test should add morale for player 2 target setup", failures)
	var enemy_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	if enemy_id == "":
		enemy_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	_expect(enemy_id != "", "coexisting kusanagi test should draw an enemy target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_id,
		"row": "front",
		"col": 0
	})).ok, "coexisting kusanagi test should deploy the enemy target", failures)
	_drain_stack_and_choices(engine, state, failures, "coexisting kusanagi enemy target setup should resolve cleanly")
	var enemy_instance_id = state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "coexisting kusanagi test should return to player 1 main")
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "susanoo_manifest_kusanagi"
	})).ok, "coexisting kusanagi test should allow 须佐之男 to manifest the first 草薙剑", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "coexisting kusanagi manifest first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "coexisting kusanagi manifest second pass should resolve into a slot choice", failures)
	var manifest_choice = _require_pending_choice(state, failures, "coexisting kusanagi manifest should request a front-slot choice")
	if manifest_choice.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(manifest_choice.get("choice_id", "")),
		"selected_option": "front:1"
	})).ok, "coexisting kusanagi manifest front-slot choice should resolve", failures)
	_expect(state.get_player(0).battle_front[1].occupant == first_kusanagi_id, "coexisting kusanagi test should move the first 草薙剑 onto the battlefield", failures)
	_expect(state.get_player(0).artifact_zone.cards.is_empty(), "coexisting kusanagi test should empty the artifact zone after manifesting the first 草薙剑", failures)
	var second_kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(second_kusanagi_id != "" and second_kusanagi_id != first_kusanagi_id, "coexisting kusanagi test should still have a second 草薙剑 in hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_kusanagi_id,
		"row": "artifact",
		"col": -1
	})).ok, "coexisting kusanagi test should allow playing a second 草薙剑 into the artifact zone while the first remains on the battlefield", failures)
	_expect(state.get_player(0).artifact_zone.cards.size() == 1 and str(state.get_player(0).artifact_zone.cards[0]) == second_kusanagi_id, "coexisting kusanagi test should keep exactly one 草薙剑 in the artifact zone", failures)
	_expect(state.get_player(0).battle_front[1].occupant == first_kusanagi_id, "coexisting kusanagi test should keep the manifested 草薙剑 on the battlefield", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "coexisting kusanagi second 草薙剑 enter first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "coexisting kusanagi second 草薙剑 enter second pass should resolve", failures)
	var ally_instance_id = state.get_player(0).battle_front[0].occupant
	var first_actions = engine.get_legal_actions(state, 0)
	_expect(not _find_activate_action(first_actions, first_kusanagi_id, "kusanagi_assault").is_empty(), "battlefield 草薙剑 should expose its own once-per-turn activated effect", failures)
	_expect(not _find_activate_action(first_actions, second_kusanagi_id, "kusanagi_weaken").is_empty(), "artifact-zone 草薙剑 should expose its own once-per-turn activated effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": first_kusanagi_id,
		"effect_id": "kusanagi_assault",
		"target_card_id": ally_instance_id
	})).ok, "battlefield 草薙剑 should activate its assault effect while another copy stays in artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "battlefield 草薙剑 assault first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "battlefield 草薙剑 assault second pass should resolve", failures)
	var after_first_use_actions = engine.get_legal_actions(state, 0)
	_expect(_find_activate_action(after_first_use_actions, first_kusanagi_id, "kusanagi_assault").is_empty(), "battlefield 草薙剑 should be exhausted for its own once-per-turn key after use", failures)
	_expect(not _find_activate_action(after_first_use_actions, second_kusanagi_id, "kusanagi_weaken").is_empty(), "artifact-zone 草薙剑 should still be activatable after the battlefield copy has used its own effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": second_kusanagi_id,
		"effect_id": "kusanagi_weaken",
		"target_card_id": enemy_instance_id
	})).ok, "artifact-zone 草薙剑 should still activate independently in the same turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "artifact-zone 草薙剑 weaken first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "artifact-zone 草薙剑 weaken second pass should resolve", failures)
	var after_both_use_actions = engine.get_legal_actions(state, 0)
	_expect(_find_activate_action(after_both_use_actions, second_kusanagi_id, "kusanagi_weaken").is_empty(), "artifact-zone 草薙剑 should also respect its own once-per-turn limit after use", failures)


static func _test_kusanagi_frontline_attack_and_activate_are_independent_once_each_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"takamagahara_s01_0416",
			"neutral_s01_0015",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0318",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0316"
		]
	], 13261, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 6
	})).ok, "frontline kusanagi independence test should add morale for player 1", failures)
	var ally_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(ally_id != "" and kusanagi_id != "", "frontline kusanagi independence test should draw ally and 草薙剑", failures)
	if ally_id == "" or kusanagi_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 0
	})).ok, "frontline kusanagi independence test should deploy allied target first", failures)
	_drain_stack_and_choices(engine, state, failures, "frontline kusanagi allied target setup should resolve cleanly")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kusanagi_id,
		"row": "artifact",
		"col": -1
	})).ok, "frontline kusanagi independence test should first play 草薙剑 into the artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "frontline kusanagi enter first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "frontline kusanagi enter second pass should resolve", failures)
	_advance_to_next_main(engine, state, failures, "frontline kusanagi independence test should advance to player 2 main")
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 4
	})).ok, "frontline kusanagi independence test should add morale for player 2 target setup", failures)
	var enemy_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	if enemy_id == "":
		enemy_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	_expect(enemy_id != "", "frontline kusanagi independence test should draw enemy legion", failures)
	if enemy_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_id,
		"row": "front",
		"col": 0
	})).ok, "frontline kusanagi independence test should deploy the enemy legion", failures)
	_drain_stack_and_choices(engine, state, failures, "frontline kusanagi enemy target setup should resolve cleanly")
	var enemy_instance_id = state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "frontline kusanagi independence test should return to player 1 main")
	var artifact_instance = state.card_instances.get(kusanagi_id)
	_expect(artifact_instance != null and str(artifact_instance.zone) == "artifact_zone", "frontline kusanagi independence test should keep 草薙剑 in the artifact zone before manifesting it", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "susanoo_manifest_kusanagi"
	})).ok, "frontline kusanagi independence test should let 须佐之男 manifest 草薙剑 from the artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "frontline kusanagi manifest first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "frontline kusanagi manifest second pass should resolve into a front-slot choice", failures)
	var manifest_choice = _require_pending_choice(state, failures, "frontline kusanagi manifest should request a front-slot choice")
	if manifest_choice.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(manifest_choice.get("choice_id", "")),
		"selected_option": "front:1"
	})).ok, "frontline kusanagi front-slot choice should resolve", failures)
	_expect(state.get_player(0).battle_front[1].occupant == kusanagi_id, "frontline kusanagi manifest should move 草薙剑 into the chosen frontline slot", failures)
	var attack_targets = engine.get_legal_attack_targets(state, kusanagi_id)
	_expect(not attack_targets.is_empty(), "frontline 草薙剑 should be able to attack before using its skill", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": kusanagi_id,
		"defender_id": enemy_instance_id
	})).ok, "frontline 草薙剑 should be able to attack the enemy frontline target first", failures)
	_resolve_pending_attack(engine, state, failures, "frontline kusanagi attack first pass should succeed", "frontline kusanagi attack second pass should resolve")
	var rested_kusanagi = state.card_instances.get(kusanagi_id)
	_expect(rested_kusanagi != null and str(rested_kusanagi.orientation) == "rested", "frontline 草薙剑 should rest after attacking", failures)
	var after_attack_actions = engine.get_legal_actions(state, 0)
	var assault_action = _find_activate_action(after_attack_actions, kusanagi_id, "kusanagi_assault")
	_expect(not assault_action.is_empty(), "frontline 草薙剑 should still expose its once-per-turn skill after attacking", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": kusanagi_id,
		"effect_id": "kusanagi_assault",
		"target_card_id": ally_id
	})).ok, "frontline 草薙剑 should still activate after attacking in the same turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "frontline kusanagi post-attack skill first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "frontline kusanagi post-attack skill second pass should resolve", failures)
	var after_activate_instance = state.card_instances.get(kusanagi_id)
	_expect(after_activate_instance != null and str(after_activate_instance.orientation) == "rested", "frontline 草薙剑 skill activation should not change its rested state after attack", failures)
	var after_skill_actions = engine.get_legal_actions(state, 0)
	_expect(_find_activate_action(after_skill_actions, kusanagi_id, "kusanagi_assault").is_empty(), "frontline 草薙剑 should still respect its once-per-turn skill limit after using it", failures)
	_expect(_find_activate_action(after_skill_actions, kusanagi_id, "kusanagi_weaken").is_empty(), "frontline 草薙剑 should not expose its other option after using one once-per-turn skill", failures)
	_expect(engine.get_legal_attack_targets(state, kusanagi_id).is_empty(), "frontline 草薙剑 should still only attack once per turn after using its skill", failures)

static func _test_susanoo_targeted_master_effect_exposes_targets(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"takamagahara_s01_0417",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1302, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	var legion_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	_expect(legion_id != "", "susanoo target test should draw a takamagahara legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": legion_id,
		"row": "front",
		"col": 0
	})).ok, "susanoo target test should play a takamagahara legion", failures)
	_drain_stack_and_choices(engine, state, failures, "susanoo target setup should resolve cleanly")
	var battlefield_id = state.get_player(0).battle_front[0].occupant
	var targets = engine.get_legal_effect_targets(state, 0, "master_0", "susanoo_front_blessing")
	_expect(targets.size() == 1, "susanoo blessing should expose one legal target", failures)
	if not targets.is_empty():
		_expect(str(targets[0].get("target_card_id", "")) == battlefield_id, "susanoo blessing should target the allied takamagahara legion", failures)


static func _test_amaterasu_ready_morale_requires_manual_discard_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"takamagahara_s01_0417",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 13021, [
		{"name": "高天原·日轮御座", "master_name": "天照大神", "master_id": "takamagahara_s01_04m1", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(MoraleActions.consume_morale(state, 0, 2, "test_amaterasu_ready_setup").size() >= 2, "amaterasu discard-choice test should spend two morale for setup", failures)
	var hand_before: int = state.get_player(0).hand.cards.size()
	var active_before: int = state.get_player(0).cost_area.cards.size()
	var spent_before: int = state.get_player(0).cost_area.spent.size()
	var chosen_discard_id := str(state.get_player(0).hand.cards[0]) if hand_before > 0 else ""
	_expect(not chosen_discard_id.is_empty(), "amaterasu discard-choice test should start with a hand card to discard", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "amaterasu_ready_morale_and_buff"
	})).ok, "amaterasu ready effect should activate", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "amaterasu ready effect first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "amaterasu ready effect second pass should resolve into discard choice", failures)
	_expect(state.pending_choices.size() == 1, "amaterasu ready effect should stop at a mandatory discard choice", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForChoice", "amaterasu ready effect should wait for discard choice before continuing", failures)
	_expect(int(waiting.get("player_id", -1)) == 0, "amaterasu ready discard choice should belong to Amaterasu's controller", failures)
	var choice = _require_pending_choice(state, failures, "amaterasu ready effect should create one pending discard choice")
	if choice.is_empty():
		return
	var candidates = choice.get("candidate_card_ids", [])
	_expect(str(choice.get("operation", "")) == "discard_from_hand", "amaterasu ready effect should use discard_from_hand choice operation", failures)
	_expect(bool(choice.get("context", {}).get("requires_confirm", false)), "amaterasu ready effect should require explicit confirm before discarding", failures)
	_expect(candidates is Array and candidates.size() == hand_before, "amaterasu ready effect should highlight all current hand cards", failures)
	_expect(candidates is Array and candidates.has(chosen_discard_id), "amaterasu ready effect should allow choosing the selected hand card to discard", failures)
	_expect(not state.get_player(0).grave.cards.has(chosen_discard_id), "amaterasu ready effect should not discard before the choice is confirmed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": [chosen_discard_id]
	})).ok, "amaterasu ready discard choice should resolve", failures)
	_expect(state.pending_choices.is_empty(), "amaterasu ready effect should clear pending choice after discard is chosen", failures)
	_expect(state.get_player(0).grave.cards.has(chosen_discard_id), "amaterasu ready effect should move the chosen hand card into grave", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before - 1, "amaterasu ready effect should reduce hand size by one after the chosen discard", failures)
	_expect(state.get_player(0).cost_area.cards.size() == min(active_before + 2, active_before + spent_before), "amaterasu ready effect should ready up to two spent morale after the discard choice", failures)
	_expect(_count_event_type(state, "CardDiscarded") >= 1, "amaterasu ready effect should log CardDiscarded after resolving the choice", failures)
	_expect(_count_event_type(state, "MoraleReadied") >= 2, "amaterasu ready effect should log MoraleReadied for the restored morale", failures)

static func _test_truce_offer_creates_option_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s01_0015",
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1303)
	var tactic_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0015")
	_expect(tactic_id != "", "truce offer should be in opening hand", failures)
	var p1_hand_before = state.get_player(0).hand.cards.size()
	var p2_hand_before = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	})).ok, "truce offer cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "truce offer first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "truce offer second pass should resolve into option choice", failures)
	_expect(state.pending_choices.size() == 1, "truce offer should create one pending choice", failures)
	var choice = state.pending_choices[0]
	_expect(str(choice.get("type", "")) == "option_pick", "truce offer should request an option_pick choice", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": "agree"
	})).ok, "truce offer agree choice should resolve", failures)
	_expect(state.pending_choices.is_empty(), "truce offer should clear pending choice after resolution", failures)
	_expect(state.get_player(0).hand.cards.size() == p1_hand_before + 1, "truce offer should net player 1 one extra hand card after agree", failures)
	_expect(state.get_player(1).hand.cards.size() == p2_hand_before + 1, "truce offer agree should draw one card for player 2", failures)
	_expect(_has_event_type(state, "ChoiceRequested"), "truce offer should log ChoiceRequested", failures)
	_expect(_has_event_type(state, "ChoiceResolved"), "truce offer should log ChoiceResolved", failures)

static func _test_asgard_faction_morale_prompts_optional_heal_when_master_hp_is_low(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 13031, [
		{"name": "阿斯加德·英灵殿", "master_name": "奥丁", "master_id": "asgard_s01_03m1", "master_hp": 5, "master_max_hp": 12},
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "asgard faction morale low-hp test should add three morale", failures)
	var actions = engine.get_legal_actions(state, 0)
	_expect(not _find_activate_action(actions, "morale_0", "asgard_morale_draw").is_empty(), "asgard faction morale should be exposed from the controller morale source", failures)
	var deck_before = state.get_player(0).deck.cards.size()
	var hand_before = state.get_player(0).hand.cards.size()
	var hp_before = state.get_player(0).master_hp
	var active_morale_before = state.get_player(0).cost_area.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "morale_0",
		"effect_id": "asgard_morale_draw"
	})).ok, "asgard faction morale low-hp test should activate successfully", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "asgard faction morale low-hp first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "asgard faction morale low-hp second pass should resolve into optional heal choice", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 1, "asgard faction morale should draw one card before offering the optional heal", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + 1, "asgard faction morale should add the drawn card to hand before optional heal", failures)
	var pending_choice = _require_pending_choice(state, failures, "asgard faction morale low-hp test should create exactly one pending choice after drawing")
	_expect(str(pending_choice.get("operation", "")) != "optional_stack_effect", "asgard faction morale should not create an extra optional trigger confirmation before the heal choice", failures)
	var heal_choice = _require_pending_choice(state, failures, "asgard faction morale low-hp test should create an optional shared-cost heal choice")
	if heal_choice.is_empty():
		return
	_expect(str(heal_choice.get("operation", "")) == "resolve_option_with_shared_cost", "asgard faction morale low-hp test should use the shared-cost option choice", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(heal_choice.get("choice_id", "")),
		"selected_option": "heal_master"
	})).ok, "asgard faction morale low-hp heal choice should resolve", failures)
	_expect(state.get_player(0).master_hp == hp_before + 1, "asgard faction morale low-hp branch should heal the controller master by one", failures)
	_expect(state.get_player(0).cost_area.cards.size() == active_morale_before - 3, "asgard faction morale low-hp branch should spend two morale to draw and one extra morale to heal", failures)

static func _test_asgard_faction_morale_skips_optional_heal_when_master_hp_is_high(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 13032, [
		{"name": "阿斯加德·英灵殿", "master_name": "奥丁", "master_id": "asgard_s01_03m1", "master_hp": 6, "master_max_hp": 12},
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "asgard faction morale high-hp test should add three morale", failures)
	var hp_before = state.get_player(0).master_hp
	var active_morale_before = state.get_player(0).cost_area.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "morale_0",
		"effect_id": "asgard_morale_draw"
	})).ok, "asgard faction morale high-hp test should activate successfully", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "asgard faction morale high-hp first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "asgard faction morale high-hp second pass should resolve cleanly", failures)
	_expect(state.pending_choices.is_empty(), "asgard faction morale should not offer the extra-heal choice when master hp is above five", failures)
	_expect(state.get_player(0).master_hp == hp_before, "asgard faction morale high-hp branch should not change master hp", failures)
	_expect(state.get_player(0).cost_area.cards.size() == active_morale_before - 2, "asgard faction morale high-hp branch should only spend the initial two morale", failures)

static func _test_asgard_s02_faction_morale_is_exposed_from_morale_source(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 13033, [
		{"name": "阿斯加德·战歌", "master_name": "布伦希尔德", "master_id": "asgard_s02_03m1", "master_hp": 5, "master_max_hp": 12},
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "asgard s02 morale exposure test should add three morale", failures)
	var actions = engine.get_legal_actions(state, 0)
	_expect(not _find_activate_action(actions, "morale_0", "asgard_morale_draw").is_empty(), "asgard s02 morale effect should be exposed from the controller morale source", failures)

static func _test_loki_recycle_heal_uses_candidate_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s01_0015",
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"asgard_s01_0311",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303",
			"asgard_s01_0305",
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0318"
		]
	], 1304, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for loki recycle should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for loki recycle test")
		return
	state.get_player(1).master_hp = 10
	var moved_ids = _seed_grave_from_deck(state, 1, 3)
	_expect(moved_ids.size() == 3, "loki recycle test should seed three grave cards", failures)
	var result = engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": "master_1",
		"effect_id": "loki_recycle_heal"
	}))
	_expect(result.ok, "loki recycle effect should activate", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "loki recycle first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "loki recycle second pass should resolve into candidate choice", failures)
	var loki_waiting = engine.get_waiting_state(state)
	_expect(str(loki_waiting.get("state", "")) == "WaitingForChoice", "loki recycle should stop in waiting-for-choice state", failures)
	_expect(str(loki_waiting.get("choice_type", "")) == "candidate_cards_pick", "loki recycle should expose candidate_cards_pick waiting state", failures)
	var loki_choice_actions = engine.get_legal_actions(state, 1)
	_expect(loki_choice_actions.size() == 1, "loki recycle should expose exactly one resolve-choice action", failures)
	if loki_choice_actions.size() == 1:
		_expect(str(loki_choice_actions[0].get("kind", "")) == "resolve_choice", "loki recycle legal action should be a resolve-choice proposal", failures)
		_expect((loki_choice_actions[0].get("candidate_card_ids", []) as Array).size() == 3, "loki recycle legal action should expose all three grave candidates", failures)
	var choice = _require_pending_choice(state, failures, "loki recycle should create one pending choice")
	if choice.is_empty():
		return
	_expect(str(choice.get("type", "")) == "candidate_cards_pick", "loki recycle should request candidate_cards_pick", failures)
	var candidates = choice.get("candidate_card_ids", [])
	_expect(candidates is Array and candidates.size() == 3, "loki recycle should expose all seeded grave cards", failures)
	if not (candidates is Array) or candidates.size() < 2:
		failures.append("loki recycle should expose at least two grave candidates")
		return
	var selected = [str(candidates[0]), str(candidates[1])]
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected
	})).ok, "loki recycle choice resolution should succeed", failures)
	_expect(state.pending_choices.is_empty(), "loki recycle should clear pending choice after resolution", failures)
	_expect(state.get_player(1).grave.cards.size() == 1, "loki recycle should remove exactly two cards from grave", failures)
	_expect(state.get_player(1).deck.cards.size() == 5, "loki recycle should return two cards to deck bottom", failures)
	_expect(state.get_player(1).master_hp == 11, "loki recycle should heal master by one", failures)
	_expect(_has_event_type(state, "MasterHealed"), "loki recycle should log MasterHealed", failures)

static func _test_loki_draw_discard_requires_hand_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s01_0015",
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"asgard_s01_0311",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303",
			"asgard_s01_0305",
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016"
		]
	], 1330, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for loki draw-discard should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for loki draw-discard test")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "loki draw-discard test should add one morale", failures)
	var hand_before := state.get_player(1).hand.cards.size()
	var chosen_discard_id := str(state.get_player(1).hand.cards[0]) if hand_before > 0 else ""
	_expect(not chosen_discard_id.is_empty(), "loki draw-discard test should start with a hand card to discard", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": "master_1",
		"effect_id": "loki_draw_discard"
	})).ok, "loki draw-discard effect should activate", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "loki draw-discard first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "loki draw-discard second pass should resolve into a discard choice", failures)
	_expect(state.pending_choices.size() == 1, "loki draw-discard should stop at a mandatory hand discard choice", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForChoice", "loki draw-discard should wait for the discard choice before continuing", failures)
	_expect(int(waiting.get("player_id", -1)) == 1, "loki draw-discard discard choice should belong to Loki's controller", failures)
	var phase_before_choice := str(state.phase)
	var turn_before_choice := int(state.turn_number)
	var end_phase_while_choice = engine.apply_command(state, GameCommand.create(1, "EndPhase"))
	_expect(not bool(end_phase_while_choice.get("ok", false)), "loki draw-discard should not allow ending phase while discard choice is pending", failures)
	_expect(str(end_phase_while_choice.get("code", "")) == "CHOICE_PENDING", "loki draw-discard pending discard should reject EndPhase with CHOICE_PENDING", failures)
	_expect(str(state.phase) == phase_before_choice and int(state.turn_number) == turn_before_choice, "loki draw-discard pending discard should not mutate phase state when EndPhase is rejected", failures)
	var choice = _require_pending_choice(state, failures, "loki draw-discard should create one pending choice")
	if choice.is_empty():
		return
	var candidates = choice.get("candidate_card_ids", [])
	_expect(str(choice.get("operation", "")) == "discard_from_hand", "loki draw-discard should use the discard_from_hand choice operation", failures)
	_expect(bool(choice.get("context", {}).get("requires_confirm", false)), "loki draw-discard should require explicit confirm before discarding", failures)
	_expect(candidates is Array and candidates.size() == hand_before + 1, "loki draw-discard should highlight all current hand cards after drawing", failures)
	_expect(candidates is Array and candidates.has(chosen_discard_id), "loki draw-discard should allow choosing an original hand card to discard", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": [chosen_discard_id]
	})).ok, "loki draw-discard discard choice should resolve", failures)
	_expect(state.pending_choices.is_empty(), "loki draw-discard should clear pending choice after the discard is chosen", failures)
	_expect(state.get_player(1).hand.cards.size() == hand_before, "loki draw-discard should end with net zero hand size after draw then discard", failures)
	_expect(state.get_player(1).grave.cards.has(chosen_discard_id), "loki draw-discard should move the chosen hand card into grave", failures)
	_expect(_has_event_type(state, "CardDiscarded"), "loki draw-discard should log CardDiscarded", failures)

static func _test_lagertha_gains_power_on_opponent_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0312",
			"asgard_s01_0316",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0303",
			"asgard_s01_0306"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1305)
	var lagertha_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	_expect(lagertha_id != "", "lagertha should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": lagertha_id,
		"row": "front",
		"col": 0
	})).ok, "lagertha should be playable", failures)
	var battlefield_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.get_card_power(state, battlefield_id) == 3000, "lagertha should keep base power on its controller turn", failures)
	_advance_to_next_main(engine, state, failures, "advance to opponent main for lagertha power test should succeed")
	_expect(state.active_player == 1, "lagertha power test should reach player 2 turn", failures)
	_expect(engine.get_card_power(state, battlefield_id) == 4000, "lagertha should gain 1000 power on opponent turn while in front row", failures)

static func _test_lagertha_back_row_does_not_force_taunt_targets(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0303",
			"asgard_s01_0306"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 13051)
	var lagertha_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	var front_guard_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0316")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "lagertha taunt test should add enough morale for both defending legions", failures)
	_expect(lagertha_id != "" and front_guard_id != "", "lagertha taunt test should have both back-row and front-row defenders", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": front_guard_id,
		"row": "front",
		"col": 0
	})).ok, "lagertha taunt test should deploy a front defender", failures)
	_drain_stack_and_choices(engine, state, failures, "lagertha taunt test should resolve the front defender entry trigger before deploying Lagertha")
	var front_defender_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": lagertha_id,
		"row": "back",
		"col": 0
	})).ok, "lagertha taunt test should deploy Lagertha to the back row", failures)
	var back_lagertha_id = state.get_player(0).battle_back[0].occupant
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for lagertha taunt test should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for lagertha taunt test")
		return
	var attacker_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0410")
	_expect(attacker_id != "", "lagertha taunt test should draw a ranged attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "lagertha taunt test should deploy the attacker", failures)
	var attack_actions = engine.get_legal_actions(state, 1)
	var attack_action = {}
	for action in attack_actions:
		if str(action.get("kind", "")) != "declare_attack":
			continue
		if str(action.get("payload_template", {}).get("attacker_id", "")) == state.get_player(1).battle_front[0].occupant:
			attack_action = action
			break
	_expect(not attack_action.is_empty(), "lagertha taunt test should expose an attack action", failures)
	if attack_action.is_empty():
		return
	_expect(_targets_include_card(attack_action.get("targets", []), front_defender_id), "back-row Lagertha should not force attacks away from the front-row defender", failures)
	_expect(_targets_include_card(attack_action.get("targets", []), back_lagertha_id), "ranged attacker should still be allowed to target back-row Lagertha normally", failures)

static func _test_oiran_search_then_ready_morale(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0419",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1306)
	var oiran_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0419")
	_expect(oiran_id != "", "oiran should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "oiran test should add one extra morale for setup", failures)
	var player = state.get_player(0)
	_expect(MoraleActions.consume_morale(state, 0, 1, "setup").size() == 1, "oiran test should seed one spent morale", failures)
	var active_before = player.cost_area.cards.size()
	var spent_before = player.spent_cost_area.cards.size()
	var looked_cards: Array[String] = player.deck.cards.slice(0, 3)
	var expected_tutored_id := str(looked_cards[0])
	var expected_bottom_order: Array[String] = [str(looked_cards[2]), str(looked_cards[1])]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": oiran_id,
		"row": "tactic",
		"col": -1
	})).ok, "oiran should be playable", failures)
	var oiran_waiting = engine.get_waiting_state(state)
	_expect(str(oiran_waiting.get("state", "")) == "WaitingForPriority", "oiran cast should enter waiting-for-priority", failures)
	_expect(int(oiran_waiting.get("player_id", -1)) == 1, "oiran cast should first give priority to the opposing player", failures)
	var oiran_response_actions = engine.get_legal_actions(state, 1)
	_expect(not _find_action_by_kind(oiran_response_actions, "pass_priority").is_empty(), "oiran response window should expose pass priority", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "oiran first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "oiran second pass should resolve", failures)
	_expect(state.pending_choices.size() == 1, "oiran should first pause on the card-pick choice even when only one card matches", failures)
	_expect(player.cost_area.cards.size() == active_before - 1, "oiran should not ready morale until the bottom-order choice resolves", failures)
	if state.pending_choices.size() == 1:
		var first_choice: Dictionary = state.pending_choices[0]
		_expect(str(first_choice.get("operation", "")) == "search_deck", "oiran should request the hand-pick choice first", failures)
		_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
			"choice_id": str(first_choice.get("choice_id", "")),
			"selected_card_ids": [expected_tutored_id]
		})).ok, "oiran hand-pick choice should resolve", failures)
	_expect(_player_has_definition_in_hand(state, 0, "takamagahara_s01_0410"), "oiran should tutor the chosen takamagahara card after the first confirm", failures)
	_expect(state.pending_choices.size() == 1, "oiran should then pause for ordering the remaining looked cards", failures)
	if state.pending_choices.size() == 1:
		var reorder_choice: Dictionary = state.pending_choices[0]
		_expect(str(reorder_choice.get("operation", "")) == "search_deck_reorder_bottom", "oiran second choice should be the bottom-order prompt", failures)
		_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
			"choice_id": str(reorder_choice.get("choice_id", "")),
			"selected_card_ids": expected_bottom_order
		})).ok, "oiran bottom-order choice should resolve", failures)
	_expect(player.cost_area.cards.size() == active_before, "oiran follow-up should ready one spent morale after paying its cost", failures)
	_expect(player.spent_cost_area.cards.size() == spent_before, "oiran follow-up should leave spent morale count unchanged after netting back one", failures)
	_expect(player.deck.cards[player.deck.cards.size() - 2] == expected_bottom_order[0], "oiran should place the first selected card above the final bottom card", failures)
	_expect(player.deck.cards[player.deck.cards.size() - 1] == expected_bottom_order[1], "oiran should place the last selected card at the very bottom", failures)
	_expect(player.hand.cards.has(expected_tutored_id), "oiran should add the selected looked card to hand", failures)
	_expect(_has_event_type(state, "DeckSearched"), "oiran should log DeckSearched", failures)
	_expect(_has_event_type(state, "CardsRevealedToOpponent"), "oiran should log showing the chosen card to the opponent", failures)
	_expect(_count_event_type(state, "CardReturnedToDeck") >= 2, "oiran should log the remaining looked cards returning to deck bottom", failures)
	_expect(_has_event_type(state, "MoraleReadied"), "oiran should log MoraleReadied", failures)


static func _test_oiran_search_chooses_card_then_orders_remaining_bottom(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0419",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0410",
			"takamagahara_s01_0417",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 13061)
	var oiran_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0419")
	_expect(oiran_id != "", "second oiran test should find oiran in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "second oiran test should add one extra morale for setup", failures)
	_expect(MoraleActions.consume_morale(state, 0, 1, "setup").size() == 1, "second oiran test should seed one spent morale", failures)
	var player = state.get_player(0)
	var active_before = player.cost_area.cards.size()
	var spent_before = player.spent_cost_area.cards.size()
	var looked_cards: Array[String] = player.deck.cards.slice(0, 3)
	_expect(looked_cards.size() == 3, "second oiran test should have three looked cards", failures)
	var first_choice_id := str(looked_cards[0])
	var expected_bottom_order: Array[String] = [str(looked_cards[2]), str(looked_cards[1])]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": oiran_id,
		"row": "tactic",
		"col": -1
	})).ok, "second oiran test should cast oiran", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "second oiran test first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "second oiran test second pass should resolve", failures)
	_expect(state.pending_choices.size() == 1, "second oiran test should first pause on the card-pick choice", failures)
	if state.pending_choices.size() == 1:
		var first_choice: Dictionary = state.pending_choices[0]
		_expect(str(first_choice.get("operation", "")) == "search_deck", "second oiran test first choice should be search_deck", failures)
		_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
			"choice_id": str(first_choice.get("choice_id", "")),
			"selected_card_ids": [first_choice_id]
		})).ok, "second oiran test first choice should resolve", failures)
	_expect(_player_has_definition_in_hand(state, 0, "takamagahara_s01_0410"), "second oiran test should add the chosen looked card to hand", failures)
	_expect(player.cost_area.cards.size() == active_before - 1, "second oiran test should delay morale ready until reorder confirm", failures)
	_expect(state.pending_choices.size() == 1, "second oiran test should then pause on the reorder choice", failures)
	if state.pending_choices.size() == 1:
		var reorder_choice: Dictionary = state.pending_choices[0]
		_expect(str(reorder_choice.get("operation", "")) == "search_deck_reorder_bottom", "second oiran test should request bottom reorder after the pick", failures)
		var reorder_candidates = reorder_choice.get("candidate_card_ids", [])
		_expect(reorder_candidates is Array and reorder_candidates.size() == 2, "second oiran test reorder choice should only expose the remaining two looked cards", failures)
		if reorder_candidates is Array:
			_expect(not reorder_candidates.has(first_choice_id), "second oiran test reorder choice should not include the already tutored card", failures)
			_expect(reorder_candidates.has(expected_bottom_order[0]) and reorder_candidates.has(expected_bottom_order[1]), "second oiran test reorder choice should contain both remaining looked cards", failures)
		_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
			"choice_id": str(reorder_choice.get("choice_id", "")),
			"selected_card_ids": expected_bottom_order
		})).ok, "second oiran test reorder choice should resolve", failures)
	_expect(player.cost_area.cards.size() == active_before, "second oiran test should ready morale only after reorder confirm", failures)
	_expect(player.spent_cost_area.cards.size() == spent_before, "second oiran test should restore spent morale after reorder confirm", failures)
	_expect(player.deck.cards[player.deck.cards.size() - 2] == expected_bottom_order[0], "second oiran test should place the first ordered card above the bottom card", failures)
	_expect(player.deck.cards[player.deck.cards.size() - 1] == expected_bottom_order[1], "second oiran test should place the last ordered card at the bottom", failures)
	_expect(_count_event_type(state, "CardsRevealedToOpponent") == 1, "second oiran test should emit exactly one reveal event for the chosen card", failures)


static func _test_oiran_search_cancel_does_not_deadlock(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0419",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"neutral_s01_0002",
			"neutral_s01_0015",
			"takamagahara_s01_0410",
			"takamagahara_s01_0413",
			"neutral_s01_0016"
		],
		[
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 13062)
	var oiran_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0419")
	_expect(oiran_id != "", "oiran cancel test should find oiran in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "oiran cancel test should add one extra morale for setup", failures)
	var player = state.get_player(0)
	var deck_before: Array = player.deck.cards.duplicate()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": oiran_id,
		"row": "tactic",
		"col": -1
	})).ok, "oiran cancel test should cast oiran", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "oiran cancel test first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "oiran cancel test second pass should resolve", failures)
	_expect(state.pending_choices.size() == 1, "oiran cancel test should pause on the first search choice", failures)
	if state.pending_choices.is_empty():
		return
	var first_choice: Dictionary = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(first_choice.get("choice_id", "")),
		"cancelled": true
	})).ok, "oiran cancel test should allow cancelling the search choice", failures)
	_expect(state.pending_choices.is_empty(), "oiran cancel test should clear pending choices after cancelling", failures)
	_expect(player.deck.cards == deck_before, "oiran cancel test should leave the deck order unchanged after cancelling before taking a card", failures)


static func _test_oiran_reorder_cancel_uses_default_bottom_order(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0419",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"neutral_s01_0002",
			"neutral_s01_0015",
			"takamagahara_s01_0410",
			"takamagahara_s01_0413",
			"neutral_s01_0016"
		],
		[
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 13063)
	var oiran_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0419")
	_expect(oiran_id != "", "oiran reorder-cancel test should find oiran in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "oiran reorder-cancel test should add one extra morale for setup", failures)
	var player = state.get_player(0)
	var looked_cards: Array[String] = player.deck.cards.slice(0, 3)
	var picked_id := str(looked_cards[0])
	var remaining_order: Array[String] = [str(looked_cards[1]), str(looked_cards[2])]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": oiran_id,
		"row": "tactic",
		"col": -1
	})).ok, "oiran reorder-cancel test should cast oiran", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "oiran reorder-cancel test first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "oiran reorder-cancel test second pass should resolve", failures)
	_expect(state.pending_choices.size() == 1, "oiran reorder-cancel test should first pause on the search choice", failures)
	if state.pending_choices.is_empty():
		return
	var first_choice: Dictionary = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(first_choice.get("choice_id", "")),
		"selected_card_ids": [picked_id]
	})).ok, "oiran reorder-cancel test should resolve the first pick", failures)
	_expect(state.pending_choices.size() == 1, "oiran reorder-cancel test should then pause on the reorder choice", failures)
	if state.pending_choices.is_empty():
		return
	var reorder_choice: Dictionary = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(reorder_choice.get("choice_id", "")),
		"cancelled": true
	})).ok, "oiran reorder-cancel test should allow cancelling the reorder choice", failures)
	_expect(state.pending_choices.is_empty(), "oiran reorder-cancel test should clear pending choices after cancelling reorder", failures)
	_expect(player.deck.cards[player.deck.cards.size() - 2] == remaining_order[0], "oiran reorder-cancel test should return the first remaining card above the final bottom card by default", failures)
	_expect(player.deck.cards[player.deck.cards.size() - 1] == remaining_order[1], "oiran reorder-cancel test should return the last remaining card to the bottom by default", failures)
	_expect(_has_event_type(state, "CardsRevealedToOpponent"), "oiran reorder-cancel test should still show the selected card to the opponent", failures)

static func _test_kusanagi_leaving_frontline_can_return_to_deck_top(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"takamagahara_s01_0416",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1330, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "kusanagi leave-choice test should add morale", failures)
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(kusanagi_id != "", "kusanagi leave-choice test should draw 草薙剑", failures)
	if kusanagi_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kusanagi_id,
		"row": "artifact",
		"col": -1
	})).ok, "kusanagi leave-choice test should first play 草薙剑 into artifact zone", failures)
	_drain_stack_and_choices(engine, state, failures, "kusanagi leave-choice test should resolve artifact entry cleanly")
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "susanoo_manifest_kusanagi"
	})).ok, "kusanagi leave-choice test should let 须佐之男 manifest 草薙剑", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "kusanagi leave-choice test manifest first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "kusanagi leave-choice test manifest second pass should resolve into a slot choice", failures)
	var manifest_choice = _require_pending_choice(state, failures, "kusanagi leave-choice test should request a front-slot choice")
	if manifest_choice.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(manifest_choice.get("choice_id", "")),
		"selected_option": "front:0"
	})).ok, "kusanagi leave-choice test should resolve the manifest slot choice", failures)
	var leave_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "kusanagi_leave_choice_test")
	_expect(not leave_events.is_empty(), "kusanagi leave-choice test should create a pending leave choice instead of directly leaving", failures)
	_expect(state.pending_choices.size() == 1, "kusanagi leave-choice test should open exactly one pending leave choice", failures)
	if state.pending_choices.is_empty():
		return
	var leave_choice: Dictionary = state.pending_choices[0]
	_expect(str(leave_choice.get("operation", "")) == "kusanagi_leave_to_top_choice", "kusanagi leave-choice test should request whether 草薙剑 goes to deck top", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(leave_choice.get("choice_id", "")),
		"selected_option": "yes"
	})).ok, "kusanagi leave-choice test should allow returning 草薙剑 to deck top", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "", "kusanagi leave-choice test should clear the front slot after returning to deck top", failures)
	_expect(not state.get_player(0).deck.cards.is_empty() and str(state.get_player(0).deck.cards[0]) == kusanagi_id, "kusanagi leave-choice test should place 草薙剑 on top of the deck", failures)

static func _test_kusanagi_returned_to_deck_top_draws_face_up_and_playable(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"takamagahara_s01_0416",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1331, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "kusanagi redraw test should add morale", failures)
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(kusanagi_id != "", "kusanagi redraw test should draw 草薙剑", failures)
	if kusanagi_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kusanagi_id,
		"row": "artifact",
		"col": -1
	})).ok, "kusanagi redraw test should play 草薙剑 into artifact zone", failures)
	_drain_stack_and_choices(engine, state, failures, "kusanagi redraw test should resolve artifact entry")
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "susanoo_manifest_kusanagi"
	})).ok, "kusanagi redraw test should activate 须佐之男", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "kusanagi redraw test first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "kusanagi redraw test second pass should resolve slot choice", failures)
	var manifest_choice = _require_pending_choice(state, failures, "kusanagi redraw test should request a front-slot choice")
	if manifest_choice.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(manifest_choice.get("choice_id", "")),
		"selected_option": "front:0"
	})).ok, "kusanagi redraw test should resolve manifest slot choice", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "draw_cards",
		"player_id": 0,
		"count": 0
	})).ok, "kusanagi redraw test should allow unrelated debug command execution", failures)
	var leave_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "kusanagi_redraw_test")
	_expect(not leave_events.is_empty(), "kusanagi redraw test should open leave choice", failures)
	if state.pending_choices.is_empty():
		failures.append("kusanagi redraw test should have a pending leave choice")
		return
	var leave_choice: Dictionary = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(leave_choice.get("choice_id", "")),
		"selected_option": "yes"
	})).ok, "kusanagi redraw test should return 草薙剑 to deck top", failures)
	var draw_events = DrawActions.draw_cards(state, 0, 1, "kusanagi_redraw_test")
	_expect(draw_events.size() == 1, "kusanagi redraw test should draw exactly one card from deck top", failures)
	var redrawn_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(redrawn_id == kusanagi_id, "kusanagi redraw test should redraw the same 草薙剑 from deck top", failures)
	var redrawn_instance = state.card_instances.get(kusanagi_id)
	_expect(redrawn_instance != null and str(redrawn_instance.zone) == "hand", "kusanagi redraw test should move 草薙剑 back to hand", failures)
	_expect(redrawn_instance != null and str(redrawn_instance.face) == "face_up", "kusanagi redraw test should redraw 草薙剑 face up", failures)
	var legal_actions = engine.get_legal_actions(state, 0)
	var playable_again := false
	for action in legal_actions:
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("payload_template", {}).get("card_id", "")) != kusanagi_id:
			continue
		playable_again = true
		break
	_expect(playable_again, "kusanagi redraw test should let the redrawn 草薙剑 be playable again", failures)

static func _test_honda_attack_trigger_resolves_before_attack_damage(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0401",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410"
		],
		[
			"takamagahara_s01_0416",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410"
		]
	], 1307)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "honda test should add enough morale to cast Honda", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for honda target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for honda target setup")
		return
	var target_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0416")
	_expect(target_id != "", "honda target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 1
	})).ok, "honda target should be playable", failures)
	_drain_stack_and_choices(engine, state, failures, "honda target setup should resolve cleanly")
	var target_instance_id = state.get_player(1).battle_front[1].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for honda attack should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for honda attack")
		return
	var honda_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0401")
	_expect(honda_id != "", "Honda should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": honda_id,
		"row": "front",
		"col": 0
	})).ok, "Honda should be playable", failures)
	var honda_instance_id = state.get_player(0).battle_front[0].occupant
	var enemy_hp_before = state.get_player(1).master_hp
	var attack_result = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": honda_instance_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(attack_result.ok, "Honda attack declaration should succeed", failures)
	_expect(state.stack.size() == 1, "Honda attack trigger should be put on stack before attack resolves", failures)
	_expect(state.get_player(1).master_hp == enemy_hp_before, "master damage should wait until Honda trigger stack resolves", failures)
	var honda_waiting = engine.get_waiting_state(state)
	_expect(str(honda_waiting.get("state", "")) == "WaitingForPriority", "Honda attack trigger should enter waiting-for-priority", failures)
	_expect(int(honda_waiting.get("player_id", -1)) == 1, "Honda attack trigger should first hand priority to the defending player", failures)
	var honda_response_actions = engine.get_legal_actions(state, 1)
	_expect(not _find_action_by_kind(honda_response_actions, "pass_priority").is_empty(), "Honda response window should expose pass priority", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Honda trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Honda trigger second pass should resolve the trigger", failures)
	_expect(state.stack.is_empty(), "Honda attack stack should be empty after resolution", failures)
	_expect(state.get_player(1).battle_front[1].occupant == "", "Honda trigger should destroy the enemy unit reduced to 0 cost", failures)
	_expect(state.get_player(1).grave.cards.has(target_instance_id), "Honda trigger should move destroyed unit to grave", failures)
	_resolve_pending_attack(engine, state, failures, "Honda combat first pass should succeed", "Honda combat second pass should resolve")
	_expect(state.get_player(1).master_hp == enemy_hp_before - 1, "Honda should still deal 1 master damage after trigger resolution", failures)
	_expect(_has_event_type(state, "AttackDeclared"), "Honda attack should log AttackDeclared", failures)
	_expect(_has_event_type(state, "EffectResolved"), "Honda trigger should log EffectResolved", failures)

static func _test_honda_attack_cost_modifier_stacks_across_multiple_attacks(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0401",
			"takamagahara_s01_0401",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417"
		],
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 13071)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 13
	})).ok, "double Honda test should add enough morale for both Hondas", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for double Honda target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for double Honda target setup")
		return
	var target_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	_expect(target_id != "", "double Honda test should draw the enemy cost-2 legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 1
	})).ok, "double Honda target should be playable", failures)
	_drain_stack_and_choices(engine, state, failures, "double Honda target setup should resolve cleanly")
	var target_instance_id = state.get_player(1).battle_front[1].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for double Honda attacks should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for double Honda attacks")
		return
	var first_honda_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0401")
	_expect(first_honda_id != "", "double Honda test should draw the first Honda", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_honda_id,
		"row": "front",
		"col": 0
	})).ok, "first Honda should be playable", failures)
	var second_honda_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0401")
	_expect(second_honda_id != "", "double Honda test should still have a second Honda in hand", failures)
	var first_honda_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": first_honda_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "first Honda attack should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "first Honda trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "first Honda trigger second pass should resolve", failures)
	var first_modifier_instance = state.card_instances.get(target_instance_id)
	_expect(first_modifier_instance != null and int(first_modifier_instance.flags.get("cost_modifier_until_turn_end", 0)) == -1, "first Honda should reduce the enemy cost by one", failures)
	_resolve_pending_attack(engine, state, failures, "first Honda combat first pass should succeed", "first Honda combat second pass should resolve")
	_expect(_is_card_on_battlefield(state, target_instance_id), "enemy cost-2 legion should survive the first Honda attack trigger at effective cost 1", failures)
	_expect(MoraleActions.ready_all_morale(state, 0, "test_double_honda_ready").size() == 8, "double Honda test should ready the spent morale before the second same-turn deployment", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_honda_id,
		"row": "front",
		"col": 1
	})).ok, "second Honda should be playable", failures)
	var second_honda_instance_id = state.get_player(0).battle_front[1].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": second_honda_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "second Honda attack should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "second Honda trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "second Honda trigger second pass should resolve", failures)
	_expect(state.get_player(1).grave.cards.has(target_instance_id), "second Honda should stack another cost reduction and destroy the enemy legion at cost 0", failures)
	_expect(_count_event_type(state, "CardCostModified") >= 2, "double Honda should log both cost-reduction applications", failures)

static func _test_olaf_low_hp_discount_applies_on_play(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0303",
			"asgard_s01_0312"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1308)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "olaf discount test should add one morale", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 6
	})).ok, "olaf discount test should lower master hp to 6", failures)
	var olaf_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0306")
	_expect(olaf_id != "", "Olaf should be in opening hand", failures)
	var slots = engine.get_legal_play_slots(state, 0, olaf_id)
	_expect(not slots.is_empty(), "Olaf should become playable at 4 active morale when master hp is 6", failures)
	var olaf_discount_actions = engine.get_legal_actions(state, 0)
	var olaf_board_action = _find_board_action_for_card(olaf_discount_actions, olaf_id)
	_expect(not olaf_board_action.is_empty(), "Olaf discounted state should also be exposed through get_legal_actions", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": olaf_id,
		"row": "front",
		"col": 0
	})).ok, "Olaf discounted play should succeed", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 4, "Olaf discounted play should consume 4 morale", failures)

static func _test_olaf_attack_recycle_grants_bonus_damage(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0303",
			"asgard_s01_0312"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0410",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1309)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "olaf attack test should add morale for casting Olaf", failures)
	var grave_seed = _seed_grave_from_deck(state, 0, 1)
	_expect(grave_seed.size() == 1, "olaf attack test should seed one grave card", failures)
	var olaf_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0306")
	_expect(olaf_id != "", "Olaf should be in opening hand for attack test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": olaf_id,
		"row": "front",
		"col": 0
	})).ok, "Olaf should be playable for attack test", failures)
	var olaf_instance_id = state.get_player(0).battle_front[0].occupant
	_make_attack_ready(state, olaf_instance_id)
	var enemy_hp_before = state.get_player(1).master_hp
	var deck_before = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": olaf_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "Olaf attack declaration should succeed", failures)
	var olaf_choice = _require_pending_choice(state, failures, "Olaf attack should pause on the optional recycle choice before the trigger enters the stack")
	if olaf_choice.is_empty():
		return
	var olaf_waiting = engine.get_waiting_state(state)
	_expect(str(olaf_waiting.get("state", "")) == "WaitingForChoice", "Olaf attack trigger should first wait on the optional recycle choice", failures)
	_expect(int(olaf_waiting.get("player_id", -1)) == 0, "Olaf optional recycle choice should belong to the attacking player", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(olaf_choice.get("choice_id", "")),
		"selected_option": "yes"
	})).ok, "Olaf optional recycle choice should resolve as yes", failures)
	_expect(state.stack.size() == 1, "Olaf attack should create one triggered stack item after choosing to recycle", failures)
	olaf_waiting = engine.get_waiting_state(state)
	_expect(str(olaf_waiting.get("state", "")) == "WaitingForPriority", "Olaf attack trigger should enter waiting-for-priority after the choice resolves", failures)
	_expect(int(olaf_waiting.get("player_id", -1)) == 1, "Olaf attack trigger should first hand priority to the defending player", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Olaf trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Olaf trigger second pass should resolve", failures)
	_expect(state.get_player(0).grave.cards.is_empty(), "Olaf attack trigger should recycle the only grave card", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before + 1, "Olaf attack trigger should return one card to deck bottom", failures)
	_resolve_pending_attack(engine, state, failures, "Olaf combat first pass should succeed", "Olaf combat second pass should resolve")
	_expect(state.get_player(1).master_hp == enemy_hp_before - 2, "Olaf attack should deal 1 base master damage plus 1 assault bonus", failures)
	_expect(_has_event_type(state, "CardReturnedToDeck"), "Olaf attack should log CardReturnedToDeck", failures)
	_expect(_has_event_type(state, "CardBuffApplied"), "Olaf attack should log master damage bonus buff", failures)

static func _test_olaf_death_trigger_draws_then_discards(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0303",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1310)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "olaf death test should add morale for casting Olaf", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "olaf death test should add morale for casting attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 7
	})).ok, "olaf death test should lower enemy master hp so Ragnar gains charge", failures)
	var olaf_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0306")
	var attacker_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0303")
	_expect(olaf_id != "", "Olaf should be in opening hand for death test", failures)
	_expect(attacker_id != "", "enemy attacker should be in opening hand for death test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": olaf_id,
		"row": "front",
		"col": 0
	})).ok, "Olaf should be playable for death test", failures)
	var olaf_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for olaf death test should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for olaf death test")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0,
		"play_option_id": "default"
	})).ok, "enemy attacker should be playable for death test", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	_drain_stack_and_choices(engine, state, failures, "enemy attacker charge setup should resolve")
	var hand_before = state.get_player(0).hand.cards.size()
	var deck_before = state.get_player(0).deck.cards.size()
	var expected_olaf_draws = min(2, deck_before)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": olaf_instance_id
	})).ok, "enemy attack into Olaf should succeed", failures)
	_resolve_pending_attack(engine, state, failures, "enemy combat first pass into Olaf should succeed", "enemy combat second pass into Olaf should resolve")
	_expect(state.get_player(0).battle_front[0].occupant == "", "Olaf should die in combat before death trigger resolves", failures)
	_expect(state.stack.size() == 1, "Olaf death trigger should be promoted to stack after combat", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Olaf death trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Olaf death trigger second pass should resolve into a discard choice", failures)
	var olaf_choice = _require_pending_choice(state, failures, "Olaf death trigger should request a discard choice after drawing")
	if olaf_choice.is_empty():
		return
	var olaf_discard_id := str(olaf_choice.get("candidate_card_ids", [])[0]) if not olaf_choice.get("candidate_card_ids", []).is_empty() else ""
	_expect(olaf_discard_id != "", "Olaf death trigger should expose at least one discard candidate", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(olaf_choice.get("choice_id", "")),
		"selected_card_ids": [olaf_discard_id]
	})).ok, "Olaf death discard choice should resolve", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - expected_olaf_draws, "Olaf death trigger should draw up to two cards from the remaining deck", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + expected_olaf_draws - 1, "Olaf death trigger hand delta should match actual cards drawn minus one discard", failures)
	_expect(_has_event_type(state, "CardDrawn"), "Olaf death trigger should log CardDrawn", failures)
	_expect(_has_event_type(state, "CardDiscarded"), "Olaf death trigger should log CardDiscarded", failures)

static func _test_gustav_attack_cycle_buffs_and_readies_once_per_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0311",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0303",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"neutral_s01_0015"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1311)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "gustav test should add one morale for casting Gustav", failures)
	var grave_seed = _seed_grave_from_deck(state, 0, 4)
	_expect(grave_seed.size() == 4, "gustav test should seed four grave cards", failures)
	var gustav_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0311")
	_expect(gustav_id != "", "Gustav should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": gustav_id,
		"row": "front",
		"col": 0
	})).ok, "Gustav should be playable", failures)
	var gustav_instance_id = state.get_player(0).battle_front[0].occupant
	var enemy_hp_before = state.get_player(1).master_hp
	_advance_to_next_main(engine, state, failures, "advance to player 2 main after Gustav setup should succeed")
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for Gustav first attack should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for Gustav first attack")
		return
	var deck_before = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": gustav_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "Gustav first attack should declare successfully", failures)
	_expect(state.stack.is_empty(), "Gustav first attack should not expose the optional trigger on stack before the attacker confirms whether to use it", failures)
	var gustav_waiting = engine.get_waiting_state(state)
	_expect(str(gustav_waiting.get("state", "")) == "WaitingForChoice", "Gustav first trigger should stop in waiting-for-choice state", failures)
	_expect(str(gustav_waiting.get("choice_type", "")) == "option_pick", "Gustav first trigger should ask whether to activate first", failures)
	var activate_choice = _require_pending_choice(state, failures, "Gustav first attack should request an optional yes-no choice")
	if activate_choice.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(activate_choice.get("choice_id", "")),
		"selected_option": "yes"
	})).ok, "Gustav first optional attack choice should resolve", failures)
	_expect(state.stack.size() == 1, "Gustav first attack should put the chosen optional trigger onto the stack after the attacker confirms", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Gustav first chosen trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Gustav first chosen trigger second pass should resolve into a grave choice", failures)
	var recycle_choice = _require_pending_choice(state, failures, "Gustav first attack should then request a grave recycle choice")
	if recycle_choice.is_empty():
		return
	var recycle_candidates = recycle_choice.get("candidate_card_ids", [])
	_expect(recycle_candidates is Array and recycle_candidates.size() == 4, "Gustav first attack should expose four grave candidates", failures)
	var selected = [str(recycle_candidates[0]), str(recycle_candidates[1])]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(recycle_choice.get("choice_id", "")),
		"selected_card_ids": selected
	})).ok, "Gustav first recycle choice should resolve", failures)
	_resolve_pending_attack(engine, state, failures, "Gustav combat first pass should succeed", "Gustav combat second pass should resolve and queue the ready trigger")
	_expect(state.get_player(1).master_hp == enemy_hp_before - 1, "Gustav first attack should still deal 1 master damage after the +2000 buff", failures)
	_expect(engine.get_card_power(state, gustav_instance_id) == 6000, "Gustav should gain 2000 power until turn end after the first recycle", failures)
	var gustav_instance = state.card_instances.get(gustav_instance_id)
	_expect(gustav_instance != null and gustav_instance.orientation == "rested", "Gustav should stay rested after the first attack until its active skill is used", failures)
	_expect(gustav_instance != null and gustav_instance.has_attacked_this_turn, "Gustav first attack should mark it as having attacked before the active ready skill", failures)
	_expect(state.stack.is_empty(), "Gustav should not auto-queue a ready trigger after attack anymore", failures)
	_expect(state.get_player(0).grave.cards.size() == 2, "Gustav first attack should recycle exactly two of the four seeded grave cards", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before + 2, "Gustav first attack should return exactly two cards to deck bottom", failures)
	var gustav_actions = engine.get_legal_actions(state, 0)
	_expect(_find_activate_action(gustav_actions, gustav_instance_id, "gustav_second_wind").is_empty(), "Gustav should no longer expose the ready effect as a manual activated skill", failures)
	var ready_waiting = engine.get_waiting_state(state)
	_expect(str(ready_waiting.get("state", "")) == "WaitingForChoice", "Gustav ready trigger should stop in waiting-for-choice state after attack finishes", failures)
	_expect(str(ready_waiting.get("choice_type", "")) == "option_pick", "Gustav ready trigger should ask whether to activate after attack finishes", failures)
	var ready_prompt = _require_pending_choice(state, failures, "Gustav first attack should request an optional ready prompt after combat")
	if ready_prompt.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(ready_prompt.get("choice_id", "")),
		"selected_option": "yes"
	})).ok, "Gustav ready prompt should resolve", failures)
	_expect(state.stack.size() == 1, "Gustav chosen ready trigger should go onto the stack", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Gustav ready trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Gustav ready trigger second pass should resolve into a grave choice", failures)
	var active_choice = _require_pending_choice(state, failures, "Gustav ready trigger should request a grave recycle choice")
	if active_choice.is_empty():
		return
	var active_candidates = active_choice.get("candidate_card_ids", [])
	_expect(active_candidates is Array and active_candidates.size() == 2, "Gustav ready trigger should expose the remaining two grave cards", failures)
	var active_selected = [str(active_candidates[0]), str(active_candidates[1])]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(active_choice.get("choice_id", "")),
		"selected_card_ids": active_selected
	})).ok, "Gustav ready trigger grave choice should resolve", failures)
	gustav_instance = state.card_instances.get(gustav_instance_id)
	_expect(gustav_instance != null and gustav_instance.orientation == "active", "Gustav ready trigger should turn the source back to active", failures)
	_expect(gustav_instance != null and not gustav_instance.has_attacked_this_turn, "Gustav ready trigger should clear has_attacked_this_turn", failures)
	var gustav_second_targets = engine.get_legal_attack_targets(state, gustav_instance_id)
	_expect(not gustav_second_targets.is_empty(), "Gustav should regain legal attack targets after the ready trigger resolves", failures)
	_expect(state.get_player(0).grave.cards.is_empty(), "Gustav full cycle should recycle all four seeded grave cards", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before + 4, "Gustav full cycle should return four cards to deck bottom", failures)
	var second_hp_before = state.get_player(1).master_hp
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": gustav_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "Gustav second attack should be allowed after readying", failures)
	_expect(state.pending_choices.is_empty(), "Gustav second attack should not ask whether to activate when grave is below two cards", failures)
	_resolve_pending_attack(engine, state, failures, "Gustav second combat first pass should succeed", "Gustav second combat second pass should resolve")
	_expect(state.pending_choices.is_empty(), "Gustav second attack should finish without lingering grave choices after choosing not to activate", failures)
	_expect(state.stack.is_empty(), "Gustav second attack should finish with an empty stack", failures)
	_expect(state.get_player(1).master_hp == second_hp_before - 1, "Gustav second attack should still deal 1 master damage because power no longer scales master damage", failures)
	_expect(gustav_instance != null and gustav_instance.orientation == "rested", "Gustav should remain rested after the second attack", failures)
	_expect(gustav_instance != null and gustav_instance.has_attacked_this_turn, "Gustav second attack should mark it as having attacked", failures)
	var gustav_actions_after_second_attack = engine.get_legal_actions(state, 0)
	_expect(_find_activate_action(gustav_actions_after_second_attack, gustav_instance_id, "gustav_second_wind").is_empty(), "Gustav should still not expose the ready effect as a manual action after the second attack", failures)
	_expect(_count_event_type(state, "AttackFinished") == 2, "Gustav test should log two AttackFinished events across both attacks", failures)
	_expect(_count_event_type(state, "CardReadied") == 1, "Gustav ready effect should only resolve once per turn", failures)
	_expect(_count_event_type(state, "CardBuffApplied") >= 1, "Gustav test should log at least one power buff event", failures)

static func _test_komatsu_attack_buffs_other_frontline_takamagahara(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0416",
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1312)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "komatsu test should add one morale for the second legion", failures)
	var ally_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0410")
	var komatsu_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	_expect(ally_id != "", "komatsu test should draw 巴御前 as buff target", failures)
	_expect(komatsu_id != "", "komatsu test should draw 稻姬本多小松", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 1
	})).ok, "komatsu test should play the allied frontline target", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": komatsu_id,
		"row": "front",
		"col": 0
	})).ok, "komatsu test should play 稻姬本多小松", failures)
	var ally_instance_id = state.get_player(0).battle_front[1].occupant
	var komatsu_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.get_card_power(state, ally_instance_id) == 2000, "komatsu target should start at base 2000 power", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main after komatsu setup should succeed")
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for komatsu attack should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for komatsu attack")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": komatsu_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "komatsu attack should declare successfully", failures)
	_expect(state.stack.size() == 1, "komatsu attack should put its trigger on stack before damage", failures)
	var komatsu_waiting = engine.get_waiting_state(state)
	_expect(str(komatsu_waiting.get("state", "")) == "WaitingForPriority", "komatsu attack trigger should enter waiting-for-priority", failures)
	_expect(int(komatsu_waiting.get("player_id", -1)) == 1, "komatsu attack trigger should first give priority to the opposing player", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "komatsu trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "komatsu trigger second pass should resolve", failures)
	_expect(engine.get_card_power(state, ally_instance_id) == 3000, "komatsu should buff the other frontline takamagahara legion by 1000", failures)
	_expect(engine.get_card_power(state, komatsu_instance_id) == 1000, "komatsu should not buff itself", failures)
	_expect(_has_event_type(state, "CardBuffApplied"), "komatsu trigger should log CardBuffApplied", failures)
	_expect(_has_event_type(state, "AttackDeclared"), "komatsu attack should log AttackDeclared", failures)

static func _test_komatsu_enter_buffs_other_frontline_takamagahara(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0416",
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418"
		],
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0312"
		]
	], 1712)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "komatsu enter test should add one morale for the second legion", failures)
	var ally_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0410")
	var komatsu_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	_expect(ally_id != "" and komatsu_id != "", "komatsu enter test should draw 巴御前 and 稻姬本多小松", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 1
	})).ok, "komatsu enter test should play the allied frontline target", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": komatsu_id,
		"row": "front",
		"col": 0
	})).ok, "komatsu enter test should play 稻姬本多小松", failures)
	var ally_instance_id = state.get_player(0).battle_front[1].occupant
	var komatsu_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(state.stack.size() == 1, "komatsu enter should queue its enter trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "komatsu enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "komatsu enter trigger second pass should resolve", failures)
	_expect(engine.get_card_power(state, ally_instance_id) == 3000, "komatsu enter should buff the other frontline takamagahara legion by 1000", failures)
	_expect(engine.get_card_power(state, komatsu_instance_id) == 1000, "komatsu enter should not buff itself", failures)
	_expect(_has_event_type(state, "CardBuffApplied"), "komatsu enter trigger should log CardBuffApplied", failures)

static func _test_counter_tactic_cannot_be_set_to_front_row(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0413",
			"neutral_s01_0015",
			"neutral_s01_0002",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"neutral_s01_0016",
			"neutral_s01_0015",
			"neutral_s01_0002",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1399, [], {"mode": "formal", "shuffle_player_decks": false, "turn_start_draw_count": 0})
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "counter tactic front-row test should add one morale for setting 绝对防御", failures)
	var counter_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0016")
	_expect(counter_id != "", "counter tactic front-row test should draw 绝对防御", failures)
	if counter_id == "":
		return
	var front_result = engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 0
	}))
	_expect(not front_result.ok, "counter tactic front-row test should reject setting 绝对防御 to the front row", failures)
	_expect(str(front_result.get("code", "")) == "INVALID_ZONE", "counter tactic front-row test should reject with INVALID_ZONE", failures)
	_expect(state.get_player(1).battle_front[0].occupant == "", "counter tactic front-row test should keep the front slot empty", failures)
	_expect(state.get_player(1).hand.cards.has(counter_id), "counter tactic front-row test should keep 绝对防御 in hand after rejection", failures)

static func _test_hiromasa_enters_draws_and_disables_enemy_counter_tactic(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0413",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"neutral_s01_0016",
			"neutral_s01_0015",
			"neutral_s01_0015",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1322, [], {"mode": "formal", "shuffle_player_decks": false, "turn_start_draw_count": 0})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "hiromasa test should add two morale for casting 源博雅 under formal rules", failures)
	var hiromasa_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	var truce_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0015")
	var counter_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0016")
	_expect(hiromasa_id != "" and truce_id != "" and counter_id != "", "hiromasa test should draw 源博雅, 议和谈判 and 绝对防御", failures)
	var hand_before_play = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hiromasa_id,
		"row": "front",
		"col": 0
	})).ok, "hiromasa should be playable", failures)
	_expect(state.stack.size() == 1, "hiromasa play should queue its enter draw trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "hiromasa enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "hiromasa enter trigger second pass should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_play - 1, "hiromasa enter draw should not trigger in formal rules when casting from a six-card opening hand", failures)
	_expect(_count_event_type(state, "CardDrawn") >= 1, "hiromasa enter effect should log CardDrawn", failures)
	var hiromasa_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for hiromasa set-counter test should succeed")
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "hiromasa test should add one morale for setting 绝对防御", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "back",
		"col": 0
	})).ok, "hiromasa test should set 绝对防御 onto the back row", failures)
	var set_counter_instance = state.card_instances.get(counter_id)
	_expect(set_counter_instance != null and str(set_counter_instance.zone) == "battle_back" and str(set_counter_instance.face) == "face_down", "hiromasa should target a facedown battlefield counter tactic", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for hiromasa attack test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for hiromasa attack test")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hiromasa_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "hiromasa attack should declare successfully", failures)
	_expect(state.pending_choices.size() == 1, "hiromasa attack should first pause on selecting an enemy counter tactic", failures)
	var hiromasa_waiting = engine.get_waiting_state(state)
	_expect(str(hiromasa_waiting.get("state", "")) == "WaitingForChoice", "hiromasa attack should wait on the counter-tactic choice before any response window", failures)
	_expect(int(hiromasa_waiting.get("player_id", -1)) == 0, "hiromasa attack choice should belong to the attacking player", failures)
	var hiromasa_choice: Dictionary = {}
	if state.pending_choices.size() == 1:
		hiromasa_choice = state.pending_choices[0]
		_expect(str(hiromasa_choice.get("operation", "")) == "target_set_counter_tactic_then_stack_effect", "hiromasa attack choice should target a set enemy counter tactic on the battlefield", failures)
		var hiromasa_candidates = hiromasa_choice.get("candidate_card_ids", [])
		_expect(hiromasa_candidates is Array and hiromasa_candidates.size() == 1 and hiromasa_candidates.has(counter_id), "hiromasa attack choice should only expose the facedown enemy counter tactic as a selectable card", failures)
	var hand_before_attack_trigger = state.get_player(0).hand.cards.size()
	if hiromasa_choice.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(hiromasa_choice.get("choice_id", "")),
		"selected_card_ids": [counter_id]
	})).ok, "hiromasa counter-disable choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_attack_trigger, "hiromasa attack should not draw cards during attack resolution", failures)
	_expect(state.pending_choices.is_empty(), "hiromasa target pick should finish immediately after selecting the battlefield counter", failures)
	_expect(state.stack.size() == 1, "hiromasa target pick should place the disable effect onto the stack", failures)
	_expect(str(state.stack[0].get("targets", {}).get("target_card_id", "")) == counter_id, "hiromasa stack item should keep the targeted facedown counter tactic", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "hiromasa disable stack first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "hiromasa disable stack second pass should resolve", failures)
	var disabled_counter_instance = state.card_instances.get(counter_id)
	_expect(disabled_counter_instance != null and int(disabled_counter_instance.flags.get("counter_tactic_disabled_turn", -1)) == state.turn_number, "hiromasa attack should disable the enemy counter tactic for this turn", failures)
	var disabled_counter_actions = engine.get_legal_actions(state, 1)
	_expect(not _find_action_by_kind(disabled_counter_actions, "pass_priority").is_empty(), "disabled counter response window should still expose pass priority", failures)
	_expect(_find_activate_action(disabled_counter_actions, counter_id, "absolute_defense").is_empty(), "disabled facedown 绝对防御 should not expose an activate action during the same turn", failures)
	_expect(not truce_id.is_empty(), "hiromasa test should still keep 议和谈判 in hand for later checks", failures)
	_expect(_has_event_type(state, "CardBuffApplied"), "hiromasa disable trigger should log CardBuffApplied", failures)

static func _test_hiromasa_targeted_absolute_defense_can_counter_the_disable(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0413",
			"neutral_s01_0015",
			"neutral_s01_0002",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"neutral_s01_0016",
			"neutral_s01_0015",
			"neutral_s01_0002",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1323, [], {"mode": "formal", "shuffle_player_decks": false, "turn_start_draw_count": 0})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "hiromasa counter-test should add two morale for casting 源博雅 under formal rules", failures)
	var hiromasa_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	var counter_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0016")
	_expect(hiromasa_id != "" and counter_id != "", "hiromasa counter-test should draw 源博雅 and 绝对防御", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hiromasa_id,
		"row": "front",
		"col": 0
	})).ok, "hiromasa counter-test should play 源博雅", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "hiromasa counter-test enter first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "hiromasa counter-test enter second pass should resolve", failures)
	var hiromasa_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for hiromasa absolute defense test should succeed")
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "hiromasa counter-test should add one morale for setting 绝对防御", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "back",
		"col": 0
	})).ok, "hiromasa counter-test should set 绝对防御 onto the back row", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for hiromasa absolute defense test should succeed")
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hiromasa_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "hiromasa counter-test attack should declare successfully", failures)
	_expect(state.pending_choices.size() == 1, "hiromasa counter-test should pause on selecting the set counter tactic", failures)
	if state.pending_choices.is_empty():
		return
	var hiromasa_choice: Dictionary = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(hiromasa_choice.get("choice_id", "")),
		"selected_card_ids": [counter_id]
	})).ok, "hiromasa counter-test should select the facedown 绝对防御", failures)
	_expect(state.stack.size() == 1, "hiromasa counter-test should put the targeted disable effect on stack", failures)
	var hiromasa_stack_id := str(state.stack[0].get("stack_id", ""))
	var response_actions = engine.get_legal_actions(state, 1)
	var absolute_defense_action = _find_activate_action(response_actions, counter_id, "absolute_defense")
	_expect(not absolute_defense_action.is_empty(), "targeted facedown 绝对防御 should still be activatable in response to hiromasa's effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ActivateEffect", {
		"source_id": counter_id,
		"effect_id": "absolute_defense",
		"target_stack_id": hiromasa_stack_id
	})).ok, "targeted 绝对防御 should be able to counter hiromasa's disable effect", failures)
	var absolute_defense_discard_choice = _require_pending_choice(state, failures, "absolute defense response should request choosing a hand card to discard")
	if absolute_defense_discard_choice.is_empty():
		return
	_expect(str(absolute_defense_discard_choice.get("operation", "")) == "discard_from_hand", "absolute defense response should pause on a discard_from_hand choice instead of auto-discarding", failures)
	var discard_candidates = absolute_defense_discard_choice.get("candidate_card_ids", [])
	_expect(discard_candidates is Array and discard_candidates.size() == 2, "absolute defense response should expose the defender hand cards as discard candidates after the counter tactic leaves hand", failures)
	var discard_pick := ""
	if discard_candidates is Array and not discard_candidates.is_empty():
		discard_pick = str(discard_candidates[0])
	_expect(not discard_pick.is_empty(), "absolute defense response should provide a selectable discard candidate", failures)
	if discard_pick.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(absolute_defense_discard_choice.get("choice_id", "")),
		"selected_card_ids": [discard_pick]
	})).ok, "absolute defense discard choice should resolve after picking a hand card", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "absolute defense counter first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "absolute defense counter second pass should resolve", failures)
	var counter_instance = state.card_instances.get(counter_id)
	_expect(counter_instance != null and int(counter_instance.flags.get("counter_tactic_disabled_turn", -1)) != state.turn_number, "if 绝对防御 counters the effect, it should not become disabled by hiromasa that turn", failures)
	_expect(_has_event_type(state, "EffectCountered"), "absolute defense response should log EffectCountered when it counters hiromasa's effect", failures)

static func _test_yoshitsune_repositions_backline_and_draws_on_kill(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0409",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1323)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "yoshitsune test should add two morale for casting 源义经", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for yoshitsune target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for yoshitsune target setup")
		return
	var target_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	_expect(target_id != "", "yoshitsune test should draw enemy 埃吉尔 as target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "yoshitsune test should play the enemy front target", failures)
	_drain_stack_and_choices(engine, state, failures, "yoshitsune target setup should resolve cleanly")
	var target_instance_id = state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for yoshitsune test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for yoshitsune test")
		return
	var yoshitsune_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0409")
	_expect(yoshitsune_id != "", "yoshitsune should be in opening hand", failures)
	var deck_before_kill = state.get_player(0).deck.cards.size()
	var expected_yoshitsune_draws = min(1, deck_before_kill)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yoshitsune_id,
		"row": "front",
		"col": 0
	})).ok, "yoshitsune should be playable", failures)
	var yoshitsune_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.get_card_power(state, yoshitsune_instance_id) == 4000, "yoshitsune should keep 4000 power in front row", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main after yoshitsune deployment should succeed")
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for yoshitsune reposition should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for yoshitsune reposition and attack")
		return
	var activatable = engine.get_activatable_effects(state, 0)
	var move_found = false
	for effect in activatable:
		if str(effect.get("source_id", "")) == yoshitsune_instance_id and str(effect.get("effect_id", "")) == "yoshitsune_reposition":
			move_found = true
			break
	_expect(move_found, "yoshitsune reposition effect should be activatable in main phase", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": yoshitsune_instance_id,
		"effect_id": "yoshitsune_reposition"
	})).ok, "yoshitsune reposition should activate", failures)
	_drain_stack_and_choices(engine, state, failures, "yoshitsune reposition should resolve cleanly")
	_expect(state.get_player(0).battle_front[0].occupant == "", "yoshitsune should leave the front slot after reposition", failures)
	_expect(state.get_player(0).battle_back[0].occupant == yoshitsune_instance_id, "yoshitsune should move to the back row in the same column", failures)
	_expect(engine.get_card_power(state, yoshitsune_instance_id) == 4000, "yoshitsune should still show 4000 power while waiting in back row", failures)
	var yoshitsune_targets = engine.get_legal_attack_targets(state, yoshitsune_instance_id)
	var can_attack_seeded_target = false
	for target in yoshitsune_targets:
		if str(target.get("defender_id", "")) == target_instance_id:
			can_attack_seeded_target = true
			break
	_expect(can_attack_seeded_target, "back-row yoshitsune should still list the seeded front-row target as a legal attack target", failures)
	var second_move = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": yoshitsune_instance_id,
		"effect_id": "yoshitsune_reposition"
	}))
	_expect(not second_move.ok and str(second_move.get("code", "")) == "EFFECT_ALREADY_USED", "yoshitsune reposition should only be usable once per turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": yoshitsune_instance_id,
		"defender_id": target_instance_id
	})).ok, "back-row yoshitsune should still attack the front target", failures)
	_resolve_pending_attack(engine, state, failures, "yoshitsune attack first pass should succeed", "yoshitsune attack second pass should resolve")
	_expect(state.get_player(1).battle_front[0].occupant == "", "yoshitsune attack should kill the 2000-power target from back row", failures)
	_expect(state.get_player(0).battle_back[0].occupant == yoshitsune_instance_id, "yoshitsune should survive the attack because back-row ranged attacks are lossless", failures)
	_expect(state.stack.size() == 1, "yoshitsune kill should queue its draw trigger", failures)
	var hand_before_kill_trigger = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "yoshitsune kill trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "yoshitsune kill trigger second pass should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_kill_trigger + expected_yoshitsune_draws, "yoshitsune kill trigger hand delta should match the actual available draws", failures)
	_expect(_count_event_type(state, "CardDrawn") >= expected_yoshitsune_draws, "yoshitsune kill trigger should log the actual number of cards drawn", failures)
	_expect(_has_event_type(state, "CardMoved"), "yoshitsune reposition should log CardMoved", failures)

static func _test_yoshitsune_manual_move_targets_any_empty_slot_and_updates_display_power(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0409",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410"
		],
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0312"
		]
	], 2423, [], {"manual_legion_move_enabled": true})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "yoshitsune manual move test should add morale for casting 源义经", failures)
	var yoshitsune_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0409")
	_expect(yoshitsune_id != "", "yoshitsune manual move test should draw 源义经", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yoshitsune_id,
		"row": "front",
		"col": 0
	})).ok, "yoshitsune manual move test should play 源义经", failures)
	var yoshitsune_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.get_display_card_power(state, yoshitsune_instance_id) == 4000, "yoshitsune display power should stay 4000 in the front row", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main after yoshitsune manual move setup should succeed")
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for yoshitsune manual move should succeed")
	var move_targets = engine.get_legal_move_targets(state, yoshitsune_instance_id)
	var can_reach_far_back := false
	var can_reach_far_front := false
	for target in move_targets:
		if str(target.get("row", "")) == "back" and int(target.get("col", -1)) == 2:
			can_reach_far_back = true
		if str(target.get("row", "")) == "front" and int(target.get("col", -1)) == 2:
			can_reach_far_front = true
	_expect(can_reach_far_back, "yoshitsune manual move should be able to reach any empty back-row slot", failures)
	_expect(can_reach_far_front, "yoshitsune manual move should be able to reach any empty front-row slot", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": yoshitsune_instance_id,
		"row": "back",
		"col": 2
	})).ok, "yoshitsune manual move should allow moving directly to a distant empty slot", failures)
	_expect(state.get_player(0).battle_back[2].occupant == yoshitsune_instance_id, "yoshitsune manual move should place 源义经 into the chosen distant slot", failures)
	_expect(engine.get_display_card_power(state, yoshitsune_instance_id) == 2000, "yoshitsune display power should show 2000 in the back row", failures)

static func _test_yoshitsune_backline_keeps_4000_when_defending(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0409",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0312",
			"asgard_s01_0303"
		]
	], 2323)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 4
	})).ok, "yoshitsune defend test should add morale for source setup", failures)
	var yoshitsune_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0409")
	_expect(yoshitsune_id != "", "yoshitsune defend test should draw 源义经", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yoshitsune_id,
		"row": "front",
		"col": 0
	})).ok, "yoshitsune defend test should play 源义经", failures)
	var yoshitsune_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance to player 2 main before yoshitsune defend reposition should succeed")
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main before yoshitsune defend reposition should succeed")
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": yoshitsune_instance_id,
		"effect_id": "yoshitsune_reposition"
	})).ok, "yoshitsune defend test should reposition to the back row", failures)
	_drain_stack_and_choices(engine, state, failures, "yoshitsune defend reposition should resolve cleanly")
	_expect(state.get_player(0).battle_back[0].occupant == yoshitsune_instance_id, "yoshitsune defend test should leave 源义经 in the back row", failures)
	_expect(engine.get_card_power(state, yoshitsune_instance_id) == 4000, "yoshitsune should remain 4000 before being attacked from the back row", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for yoshitsune defend test should succeed")
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "yoshitsune defend test should add morale for enemy 巴御前", failures)
	var tomoe_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0410")
	_expect(tomoe_id != "", "yoshitsune defend test should draw enemy 巴御前", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": tomoe_id,
		"row": "front",
		"col": 0
	})).ok, "enemy 巴御前 should be playable in yoshitsune defend test", failures)
	var tomoe_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": tomoe_instance_id,
		"defender_id": yoshitsune_instance_id
	})).ok, "enemy 巴御前 should be able to attack back-row yoshitsune", failures)
	_resolve_pending_attack(engine, state, failures, "yoshitsune defend combat first pass should succeed", "yoshitsune defend combat second pass should resolve")
	_expect(state.get_player(0).battle_back[0].occupant == yoshitsune_instance_id, "back-row yoshitsune should survive a 2000 ranged hit while defending", failures)
	_expect(engine.get_card_power(state, yoshitsune_instance_id) == 2000, "back-row yoshitsune should keep 2000 remaining power after taking exactly 2000 damage", failures)

static func _test_hunt_execute_destroys_enemy_and_recycles_grave_cards(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0319",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0306",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"takamagahara_s01_0419"
		]
	], 1310)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for hunt target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for hunt target setup")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "hunt target setup should add morale for player 2", failures)
	var target_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	_expect(target_id != "", "hunt target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "hunt target should deploy to the battlefield", failures)
	var target_instance_id = state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for hunt tactic should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for hunt tactic")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "hunt tactic test should add morale for player 1", failures)
	var seeded_ids = _seed_grave_from_deck(state, 0, 4)
	_expect(seeded_ids.size() == 4, "hunt tactic test should seed four grave cards", failures)
	var deck_before = state.get_player(0).deck.cards.size()
	var hunt_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0319")
	_expect(hunt_id != "", "hunt execute should be in opening hand", failures)
	var hunt_targets = engine.get_legal_tactic_targets(state, 0, hunt_id, "hunt_execute")
	_expect(_targets_include_card(hunt_targets, target_instance_id), "hunt execute legal targets should include the seeded enemy legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hunt_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "hunt_execute",
		"target_card_id": target_instance_id
	})).ok, "hunt execute should cast successfully", failures)
	var hunt_waiting = engine.get_waiting_state(state)
	_expect(str(hunt_waiting.get("state", "")) == "WaitingForPriority", "hunt execute should enter waiting-for-priority with both stack items pending", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "hunt recycle first stack pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "hunt recycle second stack pass should resolve first", failures)
	_expect(state.pending_choices.is_empty(), "hunt recycle should not request a grave reorder choice when exactly four cards are recycled", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before + 4, "hunt execute should return four grave cards to deck bottom before the destroy stack item resolves", failures)
	_expect(_has_event_type(state, "CardReturnedToDeck"), "hunt execute should log CardReturnedToDeck", failures)
	_expect(_count_event_type(state, "EffectResolved") >= 1, "hunt execute should log at least the recycle effect resolution", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "hunt destroy first stack pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "hunt destroy second stack pass should resolve the targeted kill", failures)
	_expect(state.get_player(1).grave.cards.has(target_instance_id), "hunt execute should destroy the targeted enemy legion after the second stack item resolves", failures)

static func _test_hunt_execute_requires_four_grave_cards_to_cast(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0319",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0306",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0416",
			"takamagahara_s01_0415",
			"takamagahara_s01_0419"
		]
	], 13101)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for short-grave hunt target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for short-grave hunt target setup")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "short-grave hunt target setup should add morale for player 2", failures)
	var target_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	_expect(target_id != "", "short-grave hunt target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "short-grave hunt target should deploy to the battlefield", failures)
	var target_instance_id = state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for short-grave hunt tactic should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for short-grave hunt tactic")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "short-grave hunt test should add morale for player 1", failures)
	var seeded_ids = _seed_grave_from_deck(state, 0, 3)
	_expect(seeded_ids.size() == 3, "short-grave hunt test should seed exactly three grave cards", failures)
	var hunt_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0319")
	_expect(hunt_id != "", "short-grave hunt execute should be in opening hand", failures)
	var hunt_targets = engine.get_legal_tactic_targets(state, 0, hunt_id, "hunt_execute")
	_expect(hunt_targets.is_empty(), "hunt execute should have no legal targets when its required grave recycle is unavailable", failures)
	var play_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hunt_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "hunt_execute",
		"target_card_id": target_instance_id
	}))
	_expect(not play_result.ok, "hunt execute should not cast successfully when grave has fewer than four cards", failures)

static func _test_kusanagi_enters_destroy_and_supports_allies(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0417",
			"takamagahara_s01_0416",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409"
		],
		[
			"takamagahara_s01_0416",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0303",
			"asgard_s01_0318"
		]
	], 1311)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for kusanagi target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for kusanagi target setup")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 4
	})).ok, "kusanagi target setup should add morale for player 2", failures)
	var destroy_target_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0416")
	var weaken_target_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	_expect(destroy_target_id != "" and weaken_target_id != "", "kusanagi test should have both low-cost and high-cost enemy targets", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": destroy_target_id,
		"row": "front",
		"col": 0
	})).ok, "kusanagi destroy target should deploy", failures)
	_drain_stack_and_choices(engine, state, failures, "kusanagi destroy target setup should resolve cleanly")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": weaken_target_id,
		"row": "front",
		"col": 1
	})).ok, "kusanagi weaken target should deploy", failures)
	_drain_stack_and_choices(engine, state, failures, "kusanagi weaken target setup should resolve cleanly")
	var destroy_target_instance_id = state.get_player(1).battle_front[0].occupant
	var weaken_target_instance_id = state.get_player(1).battle_front[1].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for kusanagi should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for kusanagi")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "kusanagi test should add morale for player 1", failures)
	var ally_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(ally_id != "" and kusanagi_id != "", "kusanagi and allied legion should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 0
	})).ok, "kusanagi test should deploy an allied takamagahara legion", failures)
	_drain_stack_and_choices(engine, state, failures, "kusanagi allied setup should resolve cleanly")
	var ally_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kusanagi_id,
		"row": "artifact",
		"col": -1
	})).ok, "kusanagi should be playable to artifact zone", failures)
	var kusanagi_waiting = engine.get_waiting_state(state)
	_expect(str(kusanagi_waiting.get("state", "")) == "WaitingForPriority", "kusanagi enter trigger should enter waiting-for-priority", failures)
	_drain_stack_and_choices(engine, state, failures, "kusanagi enter trigger should resolve cleanly")
	_expect(state.get_player(1).grave.cards.has(destroy_target_instance_id), "kusanagi enter trigger should destroy the low-cost enemy legion", failures)
	_expect(state.get_player(0).artifact_zone.cards.has(kusanagi_id), "kusanagi should remain in artifact zone after entering play", failures)
	var kusanagi_actions = engine.get_legal_actions(state, 0)
	var kusanagi_weaken_action = _find_activate_action(kusanagi_actions, kusanagi_id, "kusanagi_weaken")
	var kusanagi_assault_action = _find_activate_action(kusanagi_actions, kusanagi_id, "kusanagi_assault")
	_expect(not kusanagi_weaken_action.is_empty(), "kusanagi weaken should be exposed through get_legal_actions", failures)
	_expect(not kusanagi_assault_action.is_empty(), "kusanagi assault should be exposed through get_legal_actions", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": kusanagi_id,
		"effect_id": "kusanagi_weaken",
		"target_card_id": weaken_target_instance_id
	})).ok, "kusanagi weaken effect should activate", failures)
	_drain_stack_and_choices(engine, state, failures, "kusanagi weaken effect should resolve cleanly")
	var weaken_instance = state.card_instances.get(weaken_target_instance_id)
	_expect(weaken_instance != null and int(weaken_instance.flags.get("cost_modifier_until_turn_end", 0)) == -1, "kusanagi weaken should reduce the target cost by one this turn", failures)
	var rested_kusanagi = state.card_instances.get(kusanagi_id)
	_expect(rested_kusanagi != null and rested_kusanagi.orientation == "active", "kusanagi should remain active after activating a once-per-turn effect", failures)
	_expect(not engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": kusanagi_id,
		"effect_id": "kusanagi_assault",
		"target_card_id": ally_instance_id
	})).ok, "kusanagi assault should not activate again in the same turn after another kusanagi effect was used", failures)
	var ally_instance = state.card_instances.get(ally_instance_id)
	_expect(ally_instance != null and int(ally_instance.flags.get("master_damage_bonus_amount", 0)) == 0, "kusanagi assault should not apply after another kusanagi effect was used this turn", failures)
	_expect(_has_event_type(state, "CardCostModified"), "kusanagi weaken should log CardCostModified", failures)

static func _test_teach_enter_loot_and_death_refill(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s01_0001",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"takamagahara_s01_0401",
			"takamagahara_s01_0401",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016"
		]
	], 1324)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 4
	})).ok, "teach test should add four morale for casting 黑胡子蒂奇", failures)
	var teach_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0001")
	_expect(teach_id != "", "teach should be in opening hand", failures)
	var p1_hand_before = state.get_player(0).hand.cards.size()
	var p2_hand_before = state.get_player(1).hand.cards.size()
	var discard_before = _count_event_type(state, "CardDiscarded")
	var draw_before = _count_event_type(state, "CardDrawn")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": teach_id,
		"row": "front",
		"col": 0
	})).ok, "teach should be playable", failures)
	_expect(state.stack.size() == 1, "teach play should queue its enter loot trigger", failures)
	var teach_waiting = engine.get_waiting_state(state)
	_expect(str(teach_waiting.get("state", "")) == "WaitingForPriority", "teach enter trigger should enter waiting-for-priority", failures)
	_expect(int(teach_waiting.get("player_id", -1)) == 1, "teach enter trigger should first give priority to the opposing player", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "teach enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "teach enter trigger second pass should resolve into the controller discard choice", failures)
	var teach_controller_choice = _require_pending_choice(state, failures, "teach enter should first request the controller discard choice")
	if teach_controller_choice.is_empty():
		return
	_expect(bool(teach_controller_choice.get("context", {}).get("requires_confirm", false)), "teach enter controller discard should require explicit confirm", failures)
	var teach_highlight_ids = teach_controller_choice.get("context", {}).get("highlight_card_ids", [])
	_expect(teach_highlight_ids is Array and teach_highlight_ids.size() == state.get_player(0).hand.cards.size() + state.get_player(1).hand.cards.size(), "teach enter should highlight both players' current hands during discard selection", failures)
	var teach_controller_candidates = teach_controller_choice.get("candidate_card_ids", [])
	_expect(teach_controller_candidates is Array and teach_controller_candidates.size() >= 2, "teach enter controller discard should expose at least two candidates", failures)
	var teach_controller_discard_ids: Array = []
	if teach_controller_candidates is Array and teach_controller_candidates.size() >= 2:
		teach_controller_discard_ids = [str(teach_controller_candidates[0]), str(teach_controller_candidates[1])]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(teach_controller_choice.get("choice_id", "")),
		"selected_card_ids": teach_controller_discard_ids
	})).ok, "teach enter controller discard choice should resolve", failures)
	_expect(_count_event_type(state, "CardDrawn") == draw_before, "teach enter should not draw before both discard choices finish", failures)
	var teach_opponent_choice = _require_pending_choice(state, failures, "teach enter should then request the opponent discard choice")
	if teach_opponent_choice.is_empty():
		return
	_expect(bool(teach_opponent_choice.get("context", {}).get("requires_confirm", false)), "teach enter opponent discard should require explicit confirm", failures)
	var teach_opponent_candidates = teach_opponent_choice.get("candidate_card_ids", [])
	_expect(teach_opponent_candidates is Array and teach_opponent_candidates.size() >= 2, "teach enter opponent discard should expose at least two candidates", failures)
	var teach_opponent_discard_ids: Array = []
	if teach_opponent_candidates is Array and teach_opponent_candidates.size() >= 2:
		for raw_candidate_id in teach_opponent_candidates:
			var candidate_id := str(raw_candidate_id)
			var candidate_instance = state.card_instances.get(candidate_id)
			if candidate_instance != null and str(candidate_instance.definition_id) == "takamagahara_s01_0401":
				continue
			teach_opponent_discard_ids.append(candidate_id)
			if teach_opponent_discard_ids.size() == 2:
				break
		if teach_opponent_discard_ids.size() < 2:
			teach_opponent_discard_ids.clear()
			teach_opponent_discard_ids = [str(teach_opponent_candidates[0]), str(teach_opponent_candidates[1])]
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(teach_opponent_choice.get("choice_id", "")),
		"selected_card_ids": teach_opponent_discard_ids
	})).ok, "teach enter opponent discard choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == p1_hand_before - 1, "teach enter effect should net controller hand size to pre-cast minus one after discarding two then drawing two", failures)
	_expect(state.get_player(1).hand.cards.size() == p2_hand_before - 1, "teach enter effect should net opponent hand size to original minus one after discarding two then drawing one", failures)
	_expect(_count_event_type(state, "CardDiscarded") == discard_before + 4, "teach enter effect should discard exactly two cards from each player", failures)
	_expect(_count_event_type(state, "CardDrawn") == draw_before + 3, "teach enter effect should draw two for controller and one for opponent", failures)
	var teach_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(teach_instance_id != "", "teach should remain on battlefield after enter trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "teach death test should add five morale for enemy Honda", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for teach death setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for teach death setup")
		return
	var honda_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0401")
	_expect(honda_id != "", "teach death test should draw enemy Honda", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": honda_id,
		"row": "front",
		"col": 0
	})).ok, "enemy Honda should be playable for teach death test", failures)
	var honda_instance_id = state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance through one full turn cycle so Honda can attack should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached during teach death setup")
		return
	_advance_to_next_main(engine, state, failures, "advance back to player 2 main for Honda attack should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for Honda attack on teach")
		return
	var hand_before_death = state.get_player(0).hand.cards.size()
	var deck_before_death = state.get_player(0).deck.cards.size()
	var expected_teach_draws = min(2, deck_before_death)
	var discard_before_death = _count_event_type(state, "CardDiscarded")
	var draw_before_death = _count_event_type(state, "CardDrawn")
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": honda_instance_id,
		"defender_id": teach_instance_id
	})).ok, "enemy Honda attack into teach should succeed", failures)
	_expect(state.stack.size() == 1, "Honda attack should first queue Honda's own attack trigger", failures)
	var teach_death_waiting = engine.get_waiting_state(state)
	_expect(str(teach_death_waiting.get("state", "")) == "WaitingForPriority", "teach death setup should enter waiting-for-priority on Honda's trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Honda trigger first pass should succeed in teach death test", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Honda trigger second pass should resolve the trigger before combat", failures)
	_resolve_pending_attack(engine, state, failures, "teach death combat first pass should succeed", "teach death combat second pass should resolve and queue teach death trigger")
	_expect(state.stack.size() == 1, "teach death should queue exactly one refill trigger after Honda attack resolves", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "teach death trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "teach death trigger second pass should resolve into a discard choice", failures)
	var teach_death_choice = _require_pending_choice(state, failures, "teach death trigger should request a discard choice after drawing")
	if teach_death_choice.is_empty():
		return
	var teach_death_discard_id := str(teach_death_choice.get("candidate_card_ids", [])[0]) if not teach_death_choice.get("candidate_card_ids", []).is_empty() else ""
	_expect(teach_death_discard_id != "", "teach death discard should expose at least one candidate", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(teach_death_choice.get("choice_id", "")),
		"selected_card_ids": [teach_death_discard_id]
	})).ok, "teach death discard choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_death + expected_teach_draws - 1, "teach death trigger hand delta should match actual cards drawn minus one discard", failures)
	_expect(_count_event_type(state, "CardDrawn") == draw_before_death + expected_teach_draws, "teach death trigger should draw up to two cards from the remaining deck", failures)
	_expect(_count_event_type(state, "CardDiscarded") == discard_before_death + 1, "teach death trigger should discard exactly one card", failures)

static func _test_hanzo_can_reveal_on_entry_turn(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0415",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"neutral_s01_0017",
			"neutral_s01_0018",
			"neutral_s01_0019"
		],
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"neutral_s01_0017",
			"neutral_s01_0018",
			"neutral_s01_0019"
		]
	], 1438, [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	])
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "hanzo same-turn reveal test should add morale", failures)
	var hanzo_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0415")
	_expect(hanzo_id != "", "hanzo same-turn reveal test should draw hanzo", failures)
	if hanzo_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hanzo_id,
		"row": "front",
		"col": 0
	})).ok, "hanzo same-turn reveal test should play hanzo", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "hanzo same-turn reveal conceal first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "hanzo same-turn reveal conceal second pass should resolve", failures)
	var hanzo_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(hanzo_instance_id != "", "hanzo same-turn reveal should stay on battlefield", failures)
	if hanzo_instance_id == "":
		return
	_expect(bool(state.card_instances[hanzo_instance_id].flags.get("concealed", false)), "hanzo same-turn reveal test should conceal hanzo first", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": hanzo_instance_id,
		"effect_id": "hanzo_reveal"
	})).ok, "hanzo should be able to reveal itself on the same turn it concealed", failures)
	_drain_stack_and_choices(engine, state, failures, "hanzo same-turn reveal should resolve cleanly")
	_expect(not bool(state.card_instances[hanzo_instance_id].flags.get("concealed", false)), "hanzo should lose concealed state after same-turn reveal", failures)
	_expect(str(state.card_instances[hanzo_instance_id].face) == "face_up", "hanzo should turn face up after same-turn reveal", failures)

static func _test_hanzo_conceals_then_reveals_for_frontline_ranged_pressure(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0415",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0417",
			"takamagahara_s01_0419",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0316",
			"takamagahara_s01_0416",
			"takamagahara_s01_0418",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312"
		]
	], 1325)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "hanzo test should add morale for the enemy setup turn", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for hanzo setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for hanzo setup")
		return
	var enemy_attacker_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	var enemy_back_target_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0416")
	var tenchu_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0418")
	_expect(enemy_attacker_id != "" and enemy_back_target_id != "" and tenchu_id != "", "hanzo test should draw enemy attacker, back-row target and 天诛", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_attacker_id,
		"row": "front",
		"col": 0
	})).ok, "enemy front attacker should be playable for hanzo test", failures)
	_drain_stack_and_choices(engine, state, failures, "hanzo enemy attacker setup should resolve cleanly")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_back_target_id,
		"row": "back",
		"col": 0
	})).ok, "enemy back-row target should be playable for hanzo ranged test", failures)
	var enemy_attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var enemy_back_target_instance_id = state.get_player(1).battle_back[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for hanzo play should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for hanzo play")
		return
	var hanzo_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0415")
	_expect(hanzo_id != "", "hanzo should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hanzo_id,
		"row": "front",
		"col": 0
	})).ok, "hanzo should be playable", failures)
	_expect(state.stack.size() == 1, "hanzo play should queue its conceal trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "hanzo conceal trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "hanzo conceal trigger second pass should resolve", failures)
	var hanzo_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(hanzo_instance_id != "", "hanzo should remain on the battlefield after concealing", failures)
	_expect(bool(state.card_instances[hanzo_instance_id].flags.get("concealed", false)), "hanzo should gain concealed state on entry", failures)
	_expect(str(state.card_instances[hanzo_instance_id].face) == "face_down", "hanzo should turn face down when concealed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for concealed hanzo pressure test should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for concealed hanzo pressure test")
		return
	var attack_targets_before_reveal = engine.get_legal_attack_targets(state, enemy_attacker_instance_id)
	var can_attack_concealed_hanzo = false
	for target in attack_targets_before_reveal:
		if str(target.get("defender_id", "")) == hanzo_instance_id:
			can_attack_concealed_hanzo = true
			break
	_expect(not can_attack_concealed_hanzo, "concealed hanzo should not appear in enemy legal attack targets", failures)
	var blocked_tenchu = engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": tenchu_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "tenchu",
		"target_card_id": hanzo_instance_id
	}))
	var blocked_tenchu_targets = engine.get_legal_tactic_targets(state, 1, tenchu_id, "tenchu")
	_expect(not _targets_include_card(blocked_tenchu_targets, hanzo_instance_id), "concealed hanzo should be absent from 天诛 legal targets", failures)
	_expect(not blocked_tenchu.ok and str(blocked_tenchu.get("code", "")) == "INVALID_EFFECT_TARGET", "concealed hanzo should not be a legal 天诛 target", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 1 main for hanzo reveal should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for hanzo reveal")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": hanzo_instance_id,
		"effect_id": "hanzo_reveal"
	})).ok, "hanzo should be able to reveal itself", failures)
	_drain_stack_and_choices(engine, state, failures, "hanzo reveal should resolve cleanly")
	_expect(not bool(state.card_instances[hanzo_instance_id].flags.get("concealed", false)), "hanzo should lose concealed state after reveal", failures)
	_expect(str(state.card_instances[hanzo_instance_id].face) == "face_up", "hanzo should turn face up after reveal", failures)
	var hanzo_targets = engine.get_legal_attack_targets(state, hanzo_instance_id)
	var can_attack_back_row = false
	for target in hanzo_targets:
		if str(target.get("defender_id", "")) == enemy_back_target_instance_id:
			can_attack_back_row = true
			break
	_expect(can_attack_back_row, "front-row hanzo should gain ranged attack against the enemy back row after reveal", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hanzo_instance_id,
		"defender_id": enemy_back_target_instance_id
	})).ok, "revealed hanzo should be able to attack the enemy back row", failures)
	_resolve_pending_attack(engine, state, failures, "hanzo attack first pass should succeed", "hanzo attack second pass should resolve")
	_expect(state.get_player(1).battle_back[0].occupant == "", "hanzo ranged attack should defeat the enemy back-row target", failures)
	_expect(state.get_player(0).battle_front[0].occupant == hanzo_instance_id, "hanzo should survive the ranged attack because it is lossless in front row", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for revealed hanzo targeting should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for revealed hanzo targeting")
		return
	var revealed_tenchu_targets = engine.get_legal_tactic_targets(state, 1, tenchu_id, "tenchu")
	var revealed_tenchu = engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": tenchu_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "tenchu",
		"target_card_id": hanzo_instance_id
	}))
	_expect(_targets_include_card(revealed_tenchu_targets, hanzo_instance_id), "revealed hanzo should reappear in 天诛 legal targets", failures)
	_expect(revealed_tenchu.ok, "revealed hanzo should become a legal 天诛 target again", failures)
	_expect(_count_event_type(state, "CardBuffApplied") >= 2, "hanzo conceal and reveal should both log CardBuffApplied", failures)

static func _test_tomoe_backline_ranged_attack_stays_lossless(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0417",
			"takamagahara_s01_0418",
			"asgard_s01_0312"
		],
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"takamagahara_s01_0417",
			"takamagahara_s01_0418"
		]
	], 2324)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 2
	})).ok, "tomoe ranged test should add morale for enemy target setup", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for tomoe ranged test should succeed")
	var enemy_target_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0316")
	_expect(enemy_target_id != "", "tomoe ranged test should draw enemy 埃吉尔", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_target_id,
		"row": "back",
		"col": 0
	})).ok, "enemy 埃吉尔 should be playable to the back row", failures)
	var enemy_target_instance_id = state.get_player(1).battle_back[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for tomoe ranged attack should succeed")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "tomoe ranged test should add morale for 巴御前", failures)
	var tomoe_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0410")
	_expect(tomoe_id != "", "tomoe ranged test should draw 巴御前", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tomoe_id,
		"row": "back",
		"col": 0
	})).ok, "巴御前 should be playable to the back row", failures)
	var tomoe_instance_id = state.get_player(0).battle_back[0].occupant
	var tomoe_targets = engine.get_legal_attack_targets(state, tomoe_instance_id)
	var can_attack_enemy_back_row := false
	for target in tomoe_targets:
		if str(target.get("defender_id", "")) == enemy_target_instance_id:
			can_attack_enemy_back_row = true
			break
	_expect(not can_attack_enemy_back_row, "back-row 巴御前 should not target the enemy back row", failures)
	var invalid_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": tomoe_instance_id,
		"defender_id": enemy_target_instance_id
	}))
	_expect(not bool(invalid_attack.get("ok", false)) and str(invalid_attack.get("code", "")) == "RANGED_TARGET_NOT_ALLOWED", "back-row 巴御前 should reject enemy back-row attacks", failures)

static func _test_mercenary_legion_repositions_and_counters_pending_attack_from_hand(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s01_0002",
			"neutral_s01_0002",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0419",
			"takamagahara_s01_0417",
			"neutral_s01_0015"
		],
		[
			"takamagahara_s01_0401",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0306",
			"asgard_s01_0312"
		]
	], 1326)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 4
	})).ok, "mercenary test should add four morale for legion deployment and defender setup", failures)
	var mercenary_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0002")
	var defender_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	_expect(mercenary_id != "" and defender_id != "", "mercenary test should draw 佣兵部队 and a battlefield defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mercenary_id,
		"row": "front",
		"col": 0
	})).ok, "mercenary legion should be deployable to the battlefield", failures)
	var mercenary_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(mercenary_instance_id != "", "mercenary should enter the front row", failures)
	var spent_before_free_move = state.get_player(0).spent_cost_area.cards.size()
	var active_before_free_move = MoraleActions.count_active_morale(state, 0)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": mercenary_instance_id,
		"effect_id": "mercenary_reposition"
	})).ok, "mercenary should be able to use its once-per-turn free move through its activated reposition effect", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "mercenary reposition first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "mercenary reposition second pass should resolve into a destination choice", failures)
	_expect(state.pending_choices.size() == 1, "mercenary reposition should request a slot choice after resolving", failures)
	if state.pending_choices.size() != 1:
		return
	var mercenary_move_choice = state.pending_choices[0]
	_expect(str(mercenary_move_choice.get("operation", "")) == "effect_move_source_slot", "mercenary reposition should expose a move-source slot choice", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(mercenary_move_choice.get("choice_id", "")),
		"selected_option": "back:2"
	})).ok, "mercenary reposition slot choice should resolve", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "", "mercenary reposition should clear the original front slot", failures)
	_expect(state.get_player(0).battle_back[2].occupant == mercenary_instance_id, "mercenary reposition should let cavalry move to any own empty slot", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == spent_before_free_move, "mercenary first move should not spend morale", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == active_before_free_move, "mercenary first move should keep active morale unchanged", failures)
	var second_move = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": mercenary_instance_id,
		"effect_id": "mercenary_reposition"
	}))
	_expect(not second_move.ok and str(second_move.get("code", "")) == "EFFECT_ALREADY_USED", "mercenary reposition should only be usable once per turn", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": defender_id,
		"row": "front",
		"col": 0
	})).ok, "mercenary response test should deploy a front-row defender", failures)
	var defender_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for mercenary response test should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for mercenary response test")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "mercenary response test should add morale for the attacking enemy Honda", failures)
	var attacker_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0401")
	var hand_guard_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0002")
	_expect(attacker_id != "" and hand_guard_id != "", "mercenary response test should have enemy Honda and a second mercenary in hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "enemy attacker should be playable for mercenary response test", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var defender_hand_before = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	})).ok, "enemy attack into the front defender should succeed", failures)
	_expect(not state.pending_attack.is_empty(), "mercenary response test should create a pending attack window", failures)
	_expect(state.priority_player == 0, "mercenary response window should first give priority to the defending player", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForPriority", "mercenary response should stop in waiting-for-priority state", failures)
	_expect(int(waiting.get("player_id", -1)) == 0, "mercenary response waiting state should identify the defending priority player", failures)
	var response_actions = engine.get_legal_actions(state, 0)
	var hand_response_action = {}
	for action in response_actions:
		if str(action.get("kind", "")) == "play_card" \
				and str(action.get("play_kind", "")) == "hand_response" \
				and str(action.get("payload_template", {}).get("card_id", "")) == hand_guard_id:
			hand_response_action = action
			break
	_expect(not hand_response_action.is_empty(), "mercenary response window should expose the in-hand guard through get_legal_actions", failures)
	if not hand_response_action.is_empty():
		_expect(str(hand_response_action.get("payload_template", {}).get("effect_id", "")) == "mercenary_hand_guard", "mercenary response action should prefill the hand guard effect id", failures)
	_expect(_find_action_by_kind(response_actions, "end_phase").is_empty(), "mercenary response window should not expose unrelated end-phase actions", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hand_guard_id,
		"row": "hand_response",
		"col": -1,
		"effect_id": "mercenary_hand_guard"
	})).ok, "mercenary should be playable from hand to counter the pending attack", failures)
	_expect(state.pending_attack.is_empty(), "mercenary hand response should clear the pending attack", failures)
	_expect(state.get_player(0).battle_front[0].occupant == defender_instance_id, "mercenary hand response should keep the defending unit alive", failures)
	_expect(state.get_player(1).battle_front[0].occupant == attacker_instance_id, "mercenary hand response should not remove the attacker", failures)
	_expect(state.get_player(0).hand.cards.size() == defender_hand_before - 1, "mercenary hand response should spend the in-hand legion", failures)
	_expect(_has_event_type(state, "AttackCountered"), "mercenary hand response should log AttackCountered", failures)
	_expect(_has_event_type(state, "HandResponsePlayed"), "mercenary hand response should log HandResponsePlayed", failures)
	_expect(_has_event_type(state, "CardDiscarded"), "mercenary hand response should log CardDiscarded", failures)

static func _test_egil_enter_effect_damages_self_mills_and_weakens_enemy(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1313)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for egil target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for egil target setup")
		return
	var target_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	_expect(target_id != "", "egil test should draw enemy 铁盾拉葛莎 as the only target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "egil test should play the only enemy target", failures)
	var target_instance_id = state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for egil test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for egil test")
		return
	var egil_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0316")
	_expect(egil_id != "", "egil should be in opening hand", failures)
	var master_hp_before = state.get_player(0).master_hp
	var deck_before = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": egil_id,
		"row": "front",
		"col": 0
	})).ok, "egil should be playable", failures)
	_expect(state.stack.size() == 1, "egil enter effect should be promoted onto the stack", failures)
	var egil_waiting = engine.get_waiting_state(state)
	_expect(str(egil_waiting.get("state", "")) == "WaitingForPriority", "egil enter effect should enter waiting-for-priority", failures)
	_expect(int(egil_waiting.get("player_id", -1)) == 1, "egil enter effect should first give priority to the opposing player", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "egil trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "egil trigger second pass should resolve", failures)
	_expect(state.get_player(0).master_hp == master_hp_before - 1, "egil enter effect should damage its controller master by one", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 2, "egil enter effect should mill two cards from deck", failures)
	_expect(state.get_player(0).grave.cards.size() == 2, "egil enter effect should put two cards into grave", failures)
	_expect(engine.get_card_power(state, target_instance_id) == 2000, "egil enter effect should reduce the only enemy target by 2000 after its opponent-turn +1000 guard bonus", failures)
	_expect(_has_event_type(state, "MasterDamaged"), "egil enter effect should log MasterDamaged", failures)
	_expect(_count_event_type(state, "CardMilled") == 2, "egil enter effect should log exactly two CardMilled events", failures)
	_expect(_has_event_type(state, "CardBuffApplied"), "egil enter effect should log the temporary power modification", failures)

static func _test_egil_revived_from_grave_still_triggers_enter_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1331)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for revived egil target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for revived egil target setup")
		return
	var target_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	_expect(target_id != "", "revived egil test should draw enemy 铁盾拉葛莎 as the only target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "revived egil test should play the only enemy target", failures)
	var target_instance_id = state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for revived egil test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for revived egil test")
		return
	var egil_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0316")
	_expect(egil_id != "", "revived egil test should have Egil available", failures)
	if egil_id == "":
		return
	state.get_player(0).hand.remove_card(egil_id)
	state.get_player(0).grave.add_card_to_top(egil_id)
	var egil_instance = state.card_instances.get(egil_id)
	if egil_instance != null:
		egil_instance.zone = "grave"
		egil_instance.position = {}
	var master_hp_before = state.get_player(0).master_hp
	var deck_before = state.get_player(0).deck.cards.size()
	var revive_events = engine._revive_grave_card_to_first_slot(state, 0, egil_id, "test_revive_egil")
	_expect(not revive_events.is_empty(), "revived egil test should move Egil from grave onto battlefield", failures)
	engine._process_generated_events(state, revive_events, "test_revive_egil")
	_expect(state.stack.size() == 1, "revived Egil should still put its enter effect on stack after entering from grave", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "revived egil trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "revived egil trigger second pass should resolve", failures)
	_expect(state.get_player(0).master_hp == master_hp_before - 1, "revived Egil should still damage its controller master by one", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 2, "revived Egil should still mill two cards from deck", failures)
	_expect(engine.get_card_power(state, target_instance_id) == 2000, "revived Egil should still reduce the only enemy target by 2000 after revival", failures)
	_expect(_has_event_type(state, "CardRevived"), "revived Egil test should log CardRevived", failures)
	_expect(_has_event_type(state, "CardBuffApplied"), "revived Egil should still apply its temporary power modification", failures)

static func _test_legacy_cardplayed_entry_trigger_still_fires_on_revive(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0306",
			"asgard_s01_0318"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"takamagahara_s01_0401"
		]
	], 1332)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 7
	})).ok, "legacy entry revive test should set master hp to 7", failures)
	var ragnar_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0303")
	_expect(ragnar_id != "", "legacy entry revive test should start with Ragnar in hand", failures)
	if ragnar_id == "":
		return
	state.get_player(0).hand.remove_card(ragnar_id)
	state.get_player(0).grave.add_card_to_top(ragnar_id)
	var ragnar_instance = state.card_instances.get(ragnar_id)
	if ragnar_instance != null:
		ragnar_instance.zone = "grave"
		ragnar_instance.position = {}
	var revive_events = engine._revive_grave_card_to_first_slot(state, 0, ragnar_id, "test_revive_ragnar")
	_expect(not revive_events.is_empty(), "legacy entry revive test should move Ragnar from grave onto battlefield", failures)
	engine._process_generated_events(state, revive_events, "test_revive_ragnar")
	_expect(state.stack.size() == 1, "legacy CardPlayed entry trigger should still queue once after revive", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "legacy entry revive trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "legacy entry revive trigger second pass should resolve", failures)
	var ragnar_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(ragnar_instance_id == ragnar_id, "legacy entry revive test should place Ragnar onto battlefield", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": ragnar_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "revived Ragnar should gain charge from its legacy entry trigger and attack immediately", failures)
	_expect(_count_event_type(state, "TriggerQueued") >= 1, "legacy entry revive test should log the queued trigger", failures)

static func _test_egil_enter_effect_kills_enemy_reduced_to_zero(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0316",
			"neutral_s01_0015",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318"
		],
		[
			"takamagahara_s01_0413",
			"neutral_s01_0015",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"neutral_s01_0015"
		]
	], 1329)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for egil lethal target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for egil lethal target setup")
		return
	var target_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0413")
	_expect(target_id != "", "egil lethal test should draw a 2000-power enemy target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "egil lethal test should play the 2000-power enemy target", failures)
	var target_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(engine.get_card_power(state, target_instance_id) == 2000, "egil lethal target should start at 2000 power", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for egil lethal test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for egil lethal test")
		return
	var egil_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0316")
	_expect(egil_id != "", "egil lethal test should have Egil in hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": egil_id,
		"row": "front",
		"col": 0
	})).ok, "egil lethal test should play Egil", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "egil lethal trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "egil lethal trigger second pass should resolve", failures)
	_expect(state.get_player(1).battle_front[0].occupant == "", "egil -2000 should remove a 2000-power target from battlefield", failures)
	_expect(state.get_player(1).grave.cards.has(target_instance_id), "egil -2000 lethal target should move to grave", failures)
	_expect(_has_event_type(state, "CardDied"), "egil -2000 lethal target should log CardDied", failures)

static func _test_valkyrie_call_revives_and_waives_damage_at_low_hp(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"neutral_s02_0008",
			"asgard_s01_0318",
			"qa_plain",
			"neutral_s01_0016",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"asgard_s01_0312"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1314, [], _formal_options(6))
	state.get_player(0).master_definition_id = "asgard_s01_03m1"
	state.get_player(0).master_name = "瓦尔基里"
	var ring_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0008")
	var revived_id = _find_hand_card_by_definition(state, 0, "qa_plain")
	var revived_instance = state.card_instances.get(revived_id)
	_expect(ring_id != "" and revived_id != "", "valkyrie call test should draw 万物统御之戒 and a neutral legion", failures)
	if ring_id == "" or revived_id == "":
		return
	state.get_player(0).hand.remove_card(revived_id)
	state.get_player(0).grave.add_card_to_top(revived_id)
	if revived_instance != null:
		revived_instance.zone = "grave"
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 5
	})).ok, "valkyrie call test should set master hp to 5", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ring_id,
		"row": "artifact",
		"col": -1
	})).ok, "valkyrie call test should play 万物统御之戒 before resolving 女武神的召唤", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "valkyrie ring setup first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "valkyrie ring setup second pass should resolve the optional prompt", failures)
	if not state.pending_choices.is_empty():
		var ring_choice = state.pending_choices[0]
		_expect(str(ring_choice.get("operation", "")) == "optional_stack_effect", "valkyrie ring setup should stop on the optional stack-effect prompt in formal rules", failures)
		_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
			"choice_id": str(ring_choice.get("choice_id", "")),
			"selected_option": "no"
		})).ok, "valkyrie ring setup should allow declining the optional entry search", failures)
	var tactic_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0318")
	_expect(tactic_id != "", "valkyrie call should be in opening hand", failures)
	var master_hp_before = state.get_player(0).master_hp
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	})).ok, "valkyrie call should be playable", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "valkyrie call first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "valkyrie call second pass should resolve", failures)
	var revive_choice = _require_pending_choice(state, failures, "valkyrie call should request a grave revive choice in formal rules")
	if revive_choice.is_empty():
		return
	_expect(str(revive_choice.get("operation", "")) == "revive_from_grave", "valkyrie call should pause on revive_from_grave choice operation", failures)
	var revive_candidates = revive_choice.get("candidate_card_ids", [])
	_expect(revive_candidates is Array and revive_candidates.has(revived_id), "valkyrie call should include the neutral legion in revive candidates while 万物统御之戒 is active", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(revive_choice.get("choice_id", "")),
		"selected_card_ids": [revived_id]
	})).ok, "valkyrie call revive choice should resolve", failures)
	var revive_slot_choice = _require_pending_choice(state, failures, "valkyrie call should request a revive slot choice in formal rules")
	if revive_slot_choice.is_empty():
		return
	_expect(str(revive_slot_choice.get("operation", "")) == "revive_selected_grave_to_slot", "valkyrie call should pause on revive_selected_grave_to_slot after choosing the grave target", failures)
	var revive_slot_options = revive_slot_choice.get("options", [])
	_expect(revive_slot_options is Array and not revive_slot_options.is_empty(), "valkyrie call should expose at least one legal revive slot", failures)
	var revive_slot_option_id = str(revive_slot_options[0].get("id", "")) if revive_slot_options is Array and not revive_slot_options.is_empty() else ""
	_expect(not revive_slot_option_id.is_empty(), "valkyrie call should encode a revive slot option id", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(revive_slot_choice.get("choice_id", "")),
		"selected_option": revive_slot_option_id
	})).ok, "valkyrie call revive slot choice should resolve", failures)
	_expect(state.get_player(0).master_hp == master_hp_before, "valkyrie call should waive self-damage when master hp is at most 5", failures)
	_expect(not state.get_player(0).grave.cards.has(revived_id), "valkyrie call should remove the neutral legion from grave when 戒指 makes it count as 阿斯加德", failures)
	_expect(_is_card_on_battlefield(state, revived_id), "valkyrie call should revive the neutral legion onto battlefield while 万物统御之戒 is in the artifact zone", failures)
	_expect(_has_event_type(state, "CardEnteredBattlefield"), "valkyrie call should log CardEnteredBattlefield", failures)
	_expect(not _has_event_type(state, "MasterDamaged"), "valkyrie call should not log MasterDamaged when damage is waived", failures)

static func _test_bjorn_discount_and_death_return_cycle(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0305",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318"
		],
		[
			"takamagahara_s01_0401",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1315)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "bjorn test should add one morale for discounted cast", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 6
	})).ok, "bjorn test should lower master hp to 6", failures)
	var grave_seed = _seed_grave_from_deck(state, 0, 4)
	_expect(grave_seed.size() == 4, "bjorn test should seed four extra grave cards", failures)
	var bjorn_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0305")
	_expect(bjorn_id != "", "Bjorn should be in opening hand", failures)
	var play_slots = engine.get_legal_play_slots(state, 0, bjorn_id)
	_expect(not play_slots.is_empty(), "Bjorn should become playable at 4 active morale when master hp is 6", failures)
	var bjorn_actions = engine.get_legal_actions(state, 0)
	var bjorn_board_action = {}
	for action in bjorn_actions:
		if str(action.get("play_kind", "")) == "board_or_artifact" and str(action.get("payload_template", {}).get("card_id", "")) == bjorn_id:
			bjorn_board_action = action
			break
	_expect(not bjorn_board_action.is_empty(), "Bjorn discounted state should be exposed through get_legal_actions", failures)
	if not bjorn_board_action.is_empty():
		_expect(bjorn_board_action.get("targets", []).size() == 6, "Bjorn discounted play should preserve the full set of legal slot targets", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": bjorn_id,
		"row": "front",
		"col": 0
	})).ok, "Bjorn discounted play should succeed", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 4, "Bjorn discounted play should consume 4 morale", failures)
	var bjorn_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(bjorn_instance_id != "", "Bjorn should occupy the front slot after play", failures)
	var bjorn_predeath = state.card_instances.get(bjorn_instance_id)
	if bjorn_predeath != null:
		bjorn_predeath.damage_marked = 2000
		bjorn_predeath.has_attacked_this_turn = true
		bjorn_predeath.flags["cost_modifier_until_turn_end"] = -2
		bjorn_predeath.flags["power_modifier_until_turn_end_turn"] = state.turn_number
		bjorn_predeath.flags["power_modifier_until_turn_end_amount"] = 2000
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "bjorn test should add morale for enemy Honda attacker", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for bjorn death test should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for bjorn death test")
		return
	var attacker_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0401")
	_expect(attacker_id != "", "bjorn test should draw enemy attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "bjorn test should play enemy attacker", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var master_hp_before = state.get_player(0).master_hp
	var deck_before = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": bjorn_instance_id
	})).ok, "enemy attack into Bjorn should succeed", failures)
	_resolve_pending_attack(engine, state, failures, "Bjorn combat first pass should succeed", "Bjorn combat second pass should resolve and queue recycle choice")
	_expect(state.stack.size() == 1, "Bjorn death trigger should be promoted to stack after combat", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Bjorn death trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Bjorn death trigger second pass should resolve into recycle choice", failures)
	var bjorn_waiting = engine.get_waiting_state(state)
	_expect(str(bjorn_waiting.get("state", "")) == "WaitingForChoice", "Bjorn death trigger should stop in waiting-for-choice state", failures)
	_expect(str(bjorn_waiting.get("choice_type", "")) == "candidate_cards_pick", "Bjorn death trigger should expose candidate_cards_pick waiting state", failures)
	var bjorn_choice_actions = engine.get_legal_actions(state, 0)
	_expect(bjorn_choice_actions.size() == 1, "Bjorn death trigger should expose exactly one resolve-choice action", failures)
	var choice = _require_pending_choice(state, failures, "Bjorn death trigger should request a recycle choice")
	if choice.is_empty():
		return
	var candidates = choice.get("candidate_card_ids", [])
	_expect(not candidates.has(bjorn_instance_id), "Bjorn recycle choice should not include Bjorn itself in grave candidates", failures)
	var selected: Array[String] = []
	for raw_card_id in candidates:
		var card_id = str(raw_card_id)
		selected.append(card_id)
		if selected.size() == 4:
			break
	_expect(selected.size() == 4, "Bjorn death trigger should allow selecting four non-source grave cards", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected
	})).ok, "Bjorn recycle choice should resolve", failures)
	_expect(state.get_player(0).master_hp == master_hp_before - 1, "Bjorn death trigger should damage its controller master before revive confirmation", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before + 4, "Bjorn death trigger should return four cards to deck bottom before revive confirmation", failures)
	var bjorn_revive_waiting = engine.get_waiting_state(state)
	_expect(str(bjorn_revive_waiting.get("state", "")) == "WaitingForChoice", "Bjorn death trigger should request a revive confirmation after choosing grave cards", failures)
	_expect(str(bjorn_revive_waiting.get("choice_type", "")) == "option_pick", "Bjorn death trigger should expose option_pick for revive confirmation", failures)
	var revive_choice = _require_pending_choice(state, failures, "Bjorn death trigger should request a revive confirmation choice")
	if revive_choice.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(revive_choice.get("choice_id", "")),
		"selected_option": "yes"
	})).ok, "Bjorn revive confirmation should resolve", failures)
	_expect(state.pending_choices.is_empty(), "Bjorn revive confirmation should not prompt for a separate slot choice", failures)
	_expect(state.get_player(0).grave.cards.is_empty(), "Bjorn should leave grave after reviving and recycling four other cards", failures)
	_expect(_is_card_on_battlefield(state, bjorn_instance_id), "Bjorn should revive itself onto battlefield", failures)
	var bjorn_instance = state.card_instances.get(bjorn_instance_id)
	if bjorn_instance != null:
		_expect(str(bjorn_instance.position.get("row", "")) == "front", "revived Bjorn should return to its original row", failures)
		_expect(int(bjorn_instance.position.get("col", -1)) == 0, "revived Bjorn should return to its original column", failures)
	_expect(bjorn_instance != null and bjorn_instance.orientation == "rested", "revived Bjorn should re-enter rested", failures)
	_expect(bjorn_instance != null and bjorn_instance.damage_marked == 0, "revived Bjorn should clear marked damage", failures)
	_expect(bjorn_instance != null and not bool(bjorn_instance.has_attacked_this_turn), "revived Bjorn should clear its attacked state", failures)
	_expect(bjorn_instance != null and int(bjorn_instance.flags.get("cost_modifier_until_turn_end", 0)) == 0, "revived Bjorn should clear temporary cost modifiers", failures)
	_expect(bjorn_instance != null and not bjorn_instance.flags.has("power_modifier_until_turn_end_turn"), "revived Bjorn should clear temporary power modifier turn tracking", failures)
	_expect(bjorn_instance != null and not bjorn_instance.flags.has("power_modifier_until_turn_end_amount"), "revived Bjorn should clear temporary power modifier amount", failures)
	_expect(engine.get_card_power(state, bjorn_instance_id) == 5000, "revived Bjorn should restore its base power", failures)
	_expect(_has_event_type(state, "MasterDamaged"), "Bjorn death trigger should log MasterDamaged", failures)
	_expect(_count_event_type(state, "CardReturnedToDeck") == 4, "Bjorn death trigger should log four CardReturnedToDeck events", failures)
	_expect(_has_event_type(state, "CardRevived"), "Bjorn death trigger should log CardRevived", failures)

static func _test_bjorn_death_trigger_requires_four_other_grave_cards(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0305",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"neutral_s01_0015"
		],
		[
			"takamagahara_s01_0401",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 2317)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "bjorn short-grave test should add one morale", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 6
	})).ok, "bjorn short-grave test should set master hp to 6", failures)
	var grave_seed = _seed_grave_from_deck(state, 0, 2)
	_expect(grave_seed.size() == 2, "bjorn short-grave test should seed exactly two extra grave cards", failures)
	var bjorn_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0305")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": bjorn_id,
		"row": "front",
		"col": 0
	})).ok, "bjorn short-grave test should play Bjorn", failures)
	var bjorn_instance_id = state.get_player(0).battle_front[0].occupant
	var bjorn_instance = state.card_instances.get(bjorn_instance_id)
	if bjorn_instance != null:
		bjorn_instance.damage_marked = 2000
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "bjorn short-grave test should add enemy morale", failures)
	_advance_to_next_main(engine, state, failures, "bjorn short-grave test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for bjorn short-grave test")
		return
	var attacker_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0401")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "bjorn short-grave test should play enemy attacker", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var master_hp_before = state.get_player(0).master_hp
	var deck_before = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": bjorn_instance_id
	})).ok, "bjorn short-grave test should declare attack", failures)
	_resolve_pending_attack(engine, state, failures, "Bjorn short-grave combat first pass should succeed", "Bjorn short-grave combat second pass should resolve and queue recycle choice")
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Bjorn short-grave trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Bjorn short-grave trigger second pass should finish cleanly when activation is unavailable", failures)
	_expect(state.pending_choices.is_empty(), "Bjorn short-grave trigger should not request any choice when grave has fewer than four other cards", failures)
	_expect(not _has_pending_choice_operation(state, "optional_stack_effect"), "Bjorn short-grave trigger should not open an optional activation prompt when grave has fewer than four other cards", failures)
	_expect(state.get_player(0).master_hp == master_hp_before, "Bjorn short-grave trigger should not deal damage when it cannot activate", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before, "Bjorn short-grave trigger should not return cards when it cannot activate", failures)
	_expect(state.get_player(0).grave.cards.has(bjorn_instance_id), "Bjorn should remain in grave when its death trigger cannot activate", failures)
	_expect(_count_event_type(state, "CardReturnedToDeck") == 0, "Bjorn short-grave trigger should not log returned cards when it cannot activate", failures)

static func _test_kogoro_attack_returns_to_deck_top_and_readies_morale(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0414",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0318",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1316)
	var kogoro_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0414")
	_expect(kogoro_id != "", "Kogoro should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kogoro_id,
		"row": "front",
		"col": 0
	})).ok, "Kogoro should be playable", failures)
	var kogoro_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for kogoro test should succeed")
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for kogoro test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for kogoro test")
		return
	_expect(MoraleActions.consume_morale(state, 0, 2, "kogoro_setup").size() == 2, "kogoro test should seed two spent morale before attacking", failures)
	var active_before = state.get_player(0).cost_area.cards.size()
	var spent_before = state.get_player(0).spent_cost_area.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": kogoro_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "Kogoro attack should declare successfully", failures)
	_resolve_pending_attack(engine, state, failures, "Kogoro combat first pass should succeed", "Kogoro combat second pass should resolve and queue return trigger")
	_expect(state.stack.size() == 1, "Kogoro attack should queue its return trigger after attack", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Kogoro trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Kogoro trigger second pass should resolve", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "", "Kogoro should leave battlefield after returning to deck top", failures)
	_expect(not _is_card_on_battlefield(state, kogoro_instance_id), "Kogoro should no longer be on battlefield after returning to deck top", failures)
	_expect(state.get_player(0).deck.cards.size() > 0 and str(state.get_player(0).deck.cards[0]) == kogoro_instance_id, "Kogoro should be placed on top of its owner's deck", failures)
	_expect(state.get_player(0).cost_area.cards.size() == active_before + 2, "Kogoro should ready up to two spent morale", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == spent_before - 2, "Kogoro should reduce spent morale by two", failures)
	_expect(_has_event_type(state, "CardReturnedToDeck"), "Kogoro effect should log CardReturnedToDeck", failures)
	_expect(_count_event_type(state, "MoraleReadied") >= 2, "Kogoro effect should log two MoraleReadied events when two spent morale exist", failures)


static func _test_kogoro_dead_source_skips_optional_trigger_prompt(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0414",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0318",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1317)
	var kogoro_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0414")
	_expect(kogoro_id != "", "Kogoro dead-source test should draw Kogoro", failures)
	if kogoro_id == "":
		return
	state.get_player(0).hand.remove_card(kogoro_id)
	state.get_player(0).grave.add_card_to_top(kogoro_id)
	var kogoro_instance = state.card_instances.get(kogoro_id)
	kogoro_instance.zone = "grave"
	kogoro_instance.position = {}
	var events = engine._enqueue_pending_triggers(state, [GameEvent.create(9001, "AttackFinished", 0, {
		"attacker_id": kogoro_id,
		"attacker_zone": "grave",
		"target_kind": "master",
		"target_player": 1
	})])
	_expect(events.is_empty(), "Kogoro dead-source trigger should not even be queued after the attacker died in combat", failures)
	_expect(state.pending_triggers.is_empty(), "Kogoro dead-source trigger should leave no pending trigger after the attacker moved to grave", failures)
	_expect(state.pending_choices.is_empty(), "Kogoro dead-source trigger should not open a yes/no prompt after the source moved to grave", failures)


static func _test_musashi_gains_charge_only_when_frontline_is_empty_and_draws_on_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0405",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"neutral_s01_0015"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0318",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"neutral_s01_0015"
		]
	], 1317)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "musashi test should add two morale for casting Musashi", failures)
	var musashi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0405")
	_expect(musashi_id != "", "Musashi should be in opening hand", failures)
	var hand_before_attack = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": musashi_id,
		"row": "front",
		"col": 0
	})).ok, "Musashi should be playable", failures)
	var musashi_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(state.stack.size() == 1, "Musashi play should queue the lone-front charge trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Musashi charge trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Musashi charge trigger second pass should resolve", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": musashi_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "Musashi should be able to attack on the turn it entered when alone in front", failures)
	var musashi_waiting = engine.get_waiting_state(state)
	_expect(str(musashi_waiting.get("state", "")) == "WaitingForChoice", "Musashi attack should pause on the optional draw trigger choice first", failures)
	_expect(str(musashi_waiting.get("choice_type", "")) == "option_pick", "Musashi attack should expose an option choice for the optional draw trigger", failures)
	var musashi_choice = _require_pending_choice(state, failures, "Musashi attack should request an optional yes-no choice before the draw trigger enters the stack")
	if musashi_choice.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(musashi_choice.get("choice_id", "")),
		"selected_option": "yes"
	})).ok, "Musashi optional attack trigger choice should resolve as yes", failures)
	_expect(state.stack.size() == 1, "Musashi attack should put the chosen draw trigger onto the stack after the choice resolves", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Musashi draw trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Musashi draw trigger second pass should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_attack, "Musashi attack draw should replace the card spent to cast it", failures)
	_expect(_count_event_type(state, "CardDrawn") >= 1, "Musashi attack trigger should log CardDrawn", failures)
	_expect(_has_event_type(state, "CardBuffApplied"), "Musashi charge trigger should log CardBuffApplied", failures)

	var blocked_state = engine.create_game(_definitions(), [
		[
			"takamagahara_s01_0410",
			"takamagahara_s01_0405",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0318",
			"asgard_s01_0303",
			"asgard_s01_0306",
			"neutral_s01_0015"
		]
	], 1318)
	_expect(engine.apply_command(blocked_state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "blocked musashi test should add enough morale", failures)
	var ally_id = _find_hand_card_by_definition(blocked_state, 0, "takamagahara_s01_0410")
	_expect(ally_id != "", "blocked musashi test should draw another frontline legion", failures)
	_expect(engine.apply_command(blocked_state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 1
	})).ok, "blocked musashi test should play another frontline legion first", failures)
	var blocked_musashi_id = _find_hand_card_by_definition(blocked_state, 0, "takamagahara_s01_0405")
	_expect(blocked_musashi_id != "", "blocked musashi test should still have Musashi in hand", failures)
	_expect(engine.apply_command(blocked_state, GameCommand.create(0, "PlayCard", {
		"card_id": blocked_musashi_id,
		"row": "front",
		"col": 0
	})).ok, "blocked musashi should still be playable", failures)
	_expect(blocked_state.stack.is_empty(), "Musashi should not queue the charge trigger when another allied front unit exists", failures)
	var blocked_musashi_instance_id = blocked_state.get_player(0).battle_front[0].occupant
	var blocked_attack = engine.apply_command(blocked_state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": blocked_musashi_instance_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(not blocked_attack.ok, "Musashi should not attack on the turn it entered when another allied front unit exists", failures)

static func _test_ragnar_requires_play_option_and_gains_charge_from_blood_price(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0318",
			"asgard_s01_0306"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"takamagahara_s01_0401"
		]
	], 1319)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "ragnar test should add five morale", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 8
	})).ok, "ragnar test should set master hp to 8", failures)
	var ragnar_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0303")
	_expect(ragnar_id != "", "Ragnar should be in opening hand", failures)
	_expect(not engine.get_legal_play_slots(state, 0, ragnar_id).is_empty(), "Ragnar should become playable at five morale because of its optional discount", failures)
	var missing_option_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ragnar_id,
		"row": "front",
		"col": 0
	}))
	_expect(not missing_option_result.ok and str(missing_option_result.get("code", "")) == "PLAY_OPTION_REQUIRED", "Ragnar should require an explicit play option selection", failures)
	var options = missing_option_result.get("details", {}).get("options", [])
	_expect(options is Array and options.size() >= 2, "Ragnar should expose both normal play and blood-price play options", failures)
	var hand_before_death = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ragnar_id,
		"row": "front",
		"col": 0,
		"play_option_id": "ragnar_blood_price"
	})).ok, "Ragnar should be playable after choosing the blood-price option", failures)
	_expect(state.get_player(0).master_hp == 7, "Ragnar blood-price option should damage its controller master by one", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 5, "Ragnar blood-price option should reduce play cost to five", failures)
	var ragnar_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(ragnar_instance_id != "", "Ragnar should enter the battlefield", failures)
	_expect(state.stack.size() == 1, "Ragnar play should queue its desperate charge trigger at 7 hp", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Ragnar charge trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Ragnar charge trigger second pass should resolve", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": ragnar_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "Ragnar should gain charge and attack on the turn it entered", failures)
	_resolve_pending_attack(engine, state, failures, "Ragnar combat first pass should succeed", "Ragnar combat second pass should resolve")
	_expect(_has_event_type(state, "MasterDamaged"), "Ragnar blood-price or attack should log MasterDamaged", failures)
	_expect(_has_event_type(state, "CardBuffApplied"), "Ragnar charge gain should log CardBuffApplied", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 7
	})).ok, "ragnar death test should keep master alive", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 12
	})).ok, "ragnar death test should reset enemy master hp if needed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for ragnar death test should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for ragnar death test")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "ragnar death test should add morale for enemy attacker", failures)
	var attacker_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0401")
	_expect(attacker_id != "", "ragnar death test should draw enemy attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "ragnar death test should play enemy attacker", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": ragnar_instance_id
	})).ok, "enemy attack into Ragnar should succeed", failures)
	_expect(state.stack.size() == 1, "Ragnar death setup should first queue Honda's attack trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Ragnar death Honda trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Ragnar death Honda trigger second pass should resolve", failures)
	_resolve_pending_attack(engine, state, failures, "Ragnar combat first pass should succeed", "Ragnar combat second pass should resolve and queue the death trigger")
	_expect(state.stack.size() == 1, "Ragnar death should queue its draw-discard trigger after combat resolves", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Ragnar death trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Ragnar death trigger second pass should resolve into a discard choice", failures)
	var ragnar_choice = _require_pending_choice(state, failures, "Ragnar death trigger should request a discard choice after drawing")
	if ragnar_choice.is_empty():
		return
	var ragnar_discard_id := str(ragnar_choice.get("candidate_card_ids", [])[0]) if not ragnar_choice.get("candidate_card_ids", []).is_empty() else ""
	_expect(ragnar_discard_id != "", "Ragnar death discard should expose at least one candidate", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(ragnar_choice.get("choice_id", "")),
		"selected_card_ids": [ragnar_discard_id]
	})).ok, "Ragnar death discard choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_death - 1, "Ragnar death draw-discard should net zero cards after having been cast", failures)
	_expect(_has_event_type(state, "CardDiscarded"), "Ragnar death trigger should log CardDiscarded", failures)
	_expect(_count_event_type(state, "CardDrawn") >= 1, "Ragnar death trigger should log CardDrawn", failures)

static func _test_erik_master_hit_discard_does_not_trigger_when_blocked(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0308",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0306",
			"asgard_s01_0312"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"takamagahara_s01_0401"
		]
	], 1820)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "erik blocked test should add five morale for a normal play", failures)
	var erik_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0308")
	_expect(erik_id != "", "Erik should be in opening hand for blocked test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": erik_id,
		"row": "front",
		"col": 0,
		"play_option_id": "default"
	})).ok, "Erik should be playable in the blocked test", failures)
	var erik_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for blocked erik test should succeed")
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for blocked erik test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for blocked erik attack test")
		return
	var enemy_hand_before = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": erik_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "Erik blocked test attack should declare successfully", failures)
	var defense_actions = engine.get_legal_actions(state, 1)
	var block_action := {}
	for action in defense_actions:
		if str(action.get("kind", "")) != "choose_defense":
			continue
		var payload = action.get("payload_template", {})
		if payload.has("master_guard_card_ids") and payload.get("master_guard_card_ids", []) is Array and not payload.get("master_guard_card_ids", []).is_empty():
			block_action = action
			break
	_expect(not block_action.is_empty(), "Erik blocked test should expose a master-guard defense option", failures)
	if block_action.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "ChooseDefense", block_action.get("payload_template", {}).duplicate(true))).ok, "Erik blocked test should allow choosing the master-guard defense option", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Erik blocked test first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Erik blocked test second pass should resolve the block", failures)
	_expect(state.stack.is_empty(), "Erik blocked test should not queue a discard trigger after the master attack is blocked", failures)
	_expect(state.pending_choices.is_empty(), "Erik blocked test should not request a discard choice when master damage was prevented", failures)
	_expect(state.get_player(1).hand.cards.size() == enemy_hand_before - 1, "Erik blocked test should only spend the blocker card from enemy hand", failures)

static func _test_erik_blood_price_master_hit_discard_and_death_revive(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0308",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0306",
			"asgard_s01_0312"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"takamagahara_s01_0401"
		]
	], 1320)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 4
	})).ok, "erik test should add four morale", failures)
	var revive_seed = _seed_grave_from_deck(state, 0, 1)
	_expect(revive_seed.size() == 1, "erik test should seed one revive target into grave", failures)
	var erik_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0308")
	_expect(erik_id != "", "Erik should be in opening hand", failures)
	_expect(not engine.get_legal_play_slots(state, 0, erik_id).is_empty(), "Erik should become playable at four morale because of its optional discount", failures)
	var missing_option_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": erik_id,
		"row": "front",
		"col": 0
	}))
	_expect(not missing_option_result.ok and str(missing_option_result.get("code", "")) == "PLAY_OPTION_REQUIRED", "Erik should require an explicit play option selection", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": erik_id,
		"row": "front",
		"col": 0,
		"play_option_id": "erik_blood_price"
	})).ok, "Erik should be playable after choosing the blood-price option", failures)
	_expect(state.get_player(0).master_hp == 19, "Erik blood-price option should damage its controller master by one", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 4, "Erik blood-price option should reduce play cost to four", failures)
	var erik_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(erik_instance_id != "", "Erik should enter the battlefield", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for erik test should succeed")
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for erik test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for erik attack test")
		return
	var enemy_hand_before_attack = state.get_player(1).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": erik_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "Erik should attack enemy master on the following turn", failures)
	_resolve_pending_attack(engine, state, failures, "Erik combat first pass should succeed", "Erik combat second pass should resolve and queue the discard trigger")
	_expect(state.stack.size() == 1, "Erik master-hit trigger should queue one discard effect after master damage resolves", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Erik discard trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Erik discard trigger second pass should resolve into a discard choice", failures)
	var erik_choice = _require_pending_choice(state, failures, "Erik master-hit trigger should request an opponent hand discard choice")
	if erik_choice.is_empty():
		return
	_expect(str(erik_choice.get("operation", "")) == "discard_from_hand", "Erik master-hit trigger should use discard_from_hand choice flow", failures)
	_expect(int(erik_choice.get("player_id", -1)) == 1, "Erik master-hit trigger should force the damaged opponent to choose the discard", failures)
	_expect(bool(erik_choice.get("context", {}).get("requires_confirm", false)), "Erik master-hit trigger should require explicit confirm on the discard choice", failures)
	var erik_discard_id := str(erik_choice.get("candidate_card_ids", [])[0]) if not erik_choice.get("candidate_card_ids", []).is_empty() else ""
	_expect(not erik_discard_id.is_empty(), "Erik master-hit discard choice should expose at least one enemy hand card", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(erik_choice.get("choice_id", "")),
		"selected_card_ids": [erik_discard_id]
	})).ok, "Erik master-hit discard choice should resolve", failures)
	_expect(state.get_player(1).hand.cards.size() == enemy_hand_before_attack - 1, "Erik master-hit trigger should make the opponent discard one chosen card", failures)
	_expect(_count_event_type(state, "CardDiscarded") >= 1, "Erik master-hit trigger should log CardDiscarded", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for erik death test should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for erik death test")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "erik death test should add morale for enemy attacker", failures)
	var attacker_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0401")
	_expect(attacker_id != "", "erik death test should draw enemy attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "erik death test should play enemy attacker", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": erik_instance_id
	})).ok, "enemy attack into Erik should succeed", failures)
	_expect(state.stack.size() == 1, "Erik death setup should first queue Honda's attack trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Erik death Honda trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Erik death Honda trigger second pass should resolve", failures)
	_resolve_pending_attack(engine, state, failures, "Erik death combat first pass should succeed", "Erik death combat second pass should resolve and queue the revive trigger")
	_expect(state.stack.size() == 1, "Erik death trigger should queue its revive effect after combat resolves", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Erik revive trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Erik revive trigger second pass should resolve", failures)
	var revived_id = str(revive_seed[0])
	_expect(_is_card_on_battlefield(state, revived_id), "Erik death trigger should revive the seeded low-cost Asgard legion", failures)
	_expect(_has_event_type(state, "CardRevived"), "Erik death trigger should log CardRevived", failures)

static func _test_harald_blood_price_entry_damage_and_death_strike(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0304",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0312",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0303",
			"dev_legion_beta",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417"
		]
	], 1324)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "harald test should add five morale for the blood-price play", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 10
	})).ok, "harald test should set player 1 master hp to 10", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 12
	})).ok, "harald test should set player 2 master hp to 12", failures)
	var harald_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0304")
	_expect(harald_id != "", "Harald should be in opening hand", failures)
	var missing_option_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": harald_id,
		"row": "front",
		"col": 0
	}))
	_expect(not missing_option_result.ok and str(missing_option_result.get("code", "")) == "PLAY_OPTION_REQUIRED", "Harald should require an explicit blood-price play option at five morale", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": harald_id,
		"row": "front",
		"col": 0,
		"play_option_id": "harald_blood_price"
	})).ok, "Harald should be playable after choosing the blood-price option", failures)
	_expect(state.get_player(0).master_hp == 9, "Harald blood-price option should damage its controller master by one", failures)
	_expect(state.stack.size() == 1, "Harald play should queue its entry damage trigger when behind on master hp", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "Harald entry trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "Harald entry trigger second pass should resolve", failures)
	_expect(state.get_player(1).master_hp == 11, "Harald entry trigger should deal one damage to the opposing master", failures)
	var harald_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(harald_instance_id != "", "Harald should remain on battlefield after entry trigger", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for harald death test should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for harald death test")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 6
	})).ok, "harald death test should add enough morale for the enemy setup", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 7
	})).ok, "harald death test should lower enemy master hp so Ragnar gains charge", failures)
	var komatsu_id = _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	var ragnar_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0303")
	_expect(komatsu_id != "" and ragnar_id != "", "harald death test should draw Komatsu and Ragnar", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": komatsu_id,
		"row": "front",
		"col": 1
	})).ok, "harald death test should play the only low-power enemy target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": ragnar_id,
		"row": "front",
		"col": 0,
		"play_option_id": "ragnar_blood_price"
	})).ok, "harald death test should play charge-enabled Ragnar", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "enemy Ragnar charge trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "enemy Ragnar charge trigger second pass should resolve", failures)
	var ragnar_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(ragnar_instance_id != "", "enemy Ragnar should enter the battlefield", failures)
	var komatsu_instance_id = state.get_player(1).battle_front[1].occupant
	_expect(komatsu_instance_id != "", "enemy Komatsu should remain available as Harald's death target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": ragnar_instance_id,
		"defender_id": harald_instance_id
	})).ok, "enemy Ragnar attack into Harald should succeed", failures)
	_resolve_pending_attack(engine, state, failures, "Harald combat first pass should succeed", "Harald combat second pass should resolve and queue the death trigger")
	_expect(state.get_player(0).battle_front[0].occupant == "", "Harald should die in combat before its death trigger resolves", failures)
	_expect(state.stack.size() == 1, "Harald death should queue its destroy trigger", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Harald death trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Harald death trigger second pass should resolve", failures)
	_expect(state.get_player(1).battle_front[1].occupant == "", "Harald death trigger should destroy the only enemy unit at 2000 power or less", failures)
	_expect(state.get_player(1).grave.cards.has(komatsu_instance_id), "Harald death trigger should move the destroyed enemy unit to grave", failures)
	_expect(_count_event_type(state, "MasterDamaged") >= 2, "Harald test should log both blood-price and entry master damage events", failures)
	_expect(_has_event_type(state, "CardDied"), "Harald death test should log CardDied", failures)

static func _test_alvilda_sacrifices_into_level2_legion_and_salvages_grave_card(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0307",
			"asgard_s01_0304",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"asgard_s01_0312",
			"asgard_s01_0304",
			"asgard_s01_0312"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410"
		]
	], 1321)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "alvilda test should add five morale", failures)
	var salvaged_id = _move_owned_card_to_grave_by_definition(state, 0, "asgard_s01_0312")
	_expect(salvaged_id != "", "alvilda test should seed one low-cost Asgard card into grave", failures)
	var alvilda_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0307")
	var harald_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0304")
	_expect(alvilda_id != "" and harald_id != "", "Alvilda and Harald should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": alvilda_id,
		"row": "front",
		"col": 0
	})).ok, "Alvilda should be playable", failures)
	var alvilda_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(alvilda_instance_id != "", "Alvilda should enter battlefield", failures)
	var activatable = engine.get_activatable_effects(state, 0)
	var summon_effect = {}
	for effect in activatable:
		if str(effect.get("source_id", "")) == alvilda_instance_id and str(effect.get("effect_id", "")) == "alvilda_blood_summon":
			summon_effect = effect
			break
	_expect(not summon_effect.is_empty(), "Alvilda activated summon effect should be available on battlefield", failures)
	var alvilda_actions = engine.get_legal_actions(state, 0)
	var alvilda_activate_action = {}
	for action in alvilda_actions:
		if str(action.get("kind", "")) == "activate_effect" \
				and str(action.get("payload_template", {}).get("source_id", "")) == alvilda_instance_id \
				and str(action.get("payload_template", {}).get("effect_id", "")) == "alvilda_blood_summon":
			alvilda_activate_action = action
			break
	_expect(not alvilda_activate_action.is_empty(), "Alvilda summon effect should also be exposed through get_legal_actions", failures)
	if not alvilda_activate_action.is_empty():
		_expect(str(alvilda_activate_action.get("kind", "")) == "activate_effect", "Alvilda summon legal action should be an activate-effect proposal", failures)
		_expect(str(alvilda_activate_action.get("payload_template", {}).get("effect_id", "")) == "alvilda_blood_summon", "Alvilda summon legal action should prefill the summon effect id", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": alvilda_instance_id,
		"effect_id": "alvilda_blood_summon"
	})).ok, "Alvilda activated effect should be cast successfully", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Alvilda summon stack first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Alvilda summon stack second pass should resolve into a hand deploy choice", failures)
	var alvilda_waiting = engine.get_waiting_state(state)
	_expect(str(alvilda_waiting.get("state", "")) == "WaitingForChoice", "Alvilda summon should pause on a hand deploy choice", failures)
	_expect(str(alvilda_waiting.get("choice_type", "")) == "candidate_cards_pick", "Alvilda summon should expose a hand candidate choice", failures)
	var deploy_choice = _require_pending_choice(state, failures, "Alvilda summon should request a level-2 hand choice")
	if deploy_choice.is_empty():
		return
	_expect(str(deploy_choice.get("operation", "")) == "deploy_from_hand_to_battlefield", "Alvilda summon should use deploy_from_hand_to_battlefield choice operation", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(deploy_choice.get("choice_id", "")),
		"selected_card_ids": [harald_id],
		"row": "front",
		"col": 0
	})).ok, "Alvilda summon hand choice should resolve into a battlefield slot", failures)
	_expect(state.get_player(0).master_hp == 19, "Alvilda activated effect should damage its controller master by one", failures)
	_expect(_is_card_on_battlefield(state, harald_id), "Alvilda should deploy the level-2 Harald from hand onto battlefield", failures)
	var deployed_instance = state.card_instances.get(harald_id)
	_expect(deployed_instance != null and deployed_instance.orientation == "active", "Harald should enter active from Alvilda effect", failures)
	_expect(not _is_card_on_battlefield(state, alvilda_instance_id), "Alvilda should sacrifice itself as part of the effect", failures)
	_drain_stack_and_choices(engine, state, failures, "Alvilda follow-up enter triggers should resolve cleanly after the summon choice")
	alvilda_waiting = engine.get_waiting_state(state)
	_expect(str(alvilda_waiting.get("state", "")) == "WaitingForAction", "Alvilda salvage should finish cleanly without leaving a pending waiting state", failures)
	_expect(state.get_player(0).grave.cards.has(salvaged_id), "Alvilda active sacrifice should not consume the seeded grave salvage target", failures)
	_expect(not state.get_player(0).hand.cards.has(salvaged_id), "Alvilda active sacrifice should not trigger the death salvage effect", failures)
	_expect(not _has_event_type(state, "CardReturnedToHand"), "Alvilda active sacrifice should not log CardReturnedToHand from the death effect", failures)
	_expect(not _has_event_type(state, "CardDied"), "Alvilda active sacrifice should not log CardDied", failures)
	_expect(_has_event_type(state, "CardSentToGrave"), "Alvilda active sacrifice should still send itself to grave", failures)

static func _test_alvilda_skips_deploy_choice_when_no_level2_in_hand(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0307",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"asgard_s01_0306",
			"neutral_s01_0015"
		],
		[
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410"
		]
	], 2325)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "alvilda no-target test should add five morale", failures)
	var alvilda_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0307")
	_expect(alvilda_id != "", "alvilda no-target test should draw 阿尔维达", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": alvilda_id,
		"row": "front",
		"col": 0
	})).ok, "alvilda no-target test should play 阿尔维达", failures)
	var alvilda_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": alvilda_instance_id,
		"effect_id": "alvilda_blood_summon"
	})).ok, "alvilda no-target test should still allow activating the blood summon", failures)
	_drain_stack_and_choices(engine, state, failures, "alvilda no-target test should resolve cleanly without a deploy choice")
	_expect(state.pending_choices.is_empty(), "alvilda no-target test should not leave any pending choice", failures)
	_expect(state.get_player(0).battle_front[0].occupant == "", "alvilda no-target test should sacrifice 阿尔维达 even without a valid summon target", failures)
	_expect(state.get_player(0).battle_back[0].occupant == "", "alvilda no-target test should not deploy an unrelated back-row unit", failures)
	_expect(state.get_player(0).master_hp == 19, "alvilda no-target test should still deal 1 damage to its controller master", failures)
	_expect(str(engine.get_waiting_state(state).get("state", "")) == "WaitingForAction", "alvilda no-target test should return to a clean waiting-for-action state", failures)
	_expect(not _has_event_type(state, "CardDied"), "alvilda no-target test should not log CardDied for the active sacrifice", failures)
	_expect(not _has_event_type(state, "CardReturnedToHand"), "alvilda no-target test should not trigger the death salvage effect", failures)

static func _test_alvilda_real_death_prompts_salvage_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		[
			"asgard_s01_0307",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"asgard_s01_0312",
			"neutral_s01_0015"
		],
		[
			"takamagahara_s01_0401",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 2326)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "alvilda death test should add five morale for player 1", failures)
	var salvaged_id = _move_owned_card_to_grave_by_definition(state, 0, "asgard_s01_0312")
	_expect(salvaged_id != "", "alvilda death test should seed one low-cost Asgard card into grave", failures)
	var alvilda_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0307")
	_expect(alvilda_id != "", "alvilda death test should draw 阿尔维达", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": alvilda_id,
		"row": "front",
		"col": 0
	})).ok, "alvilda death test should play 阿尔维达", failures)
	var alvilda_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "alvilda death test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("alvilda death test did not reach player 2 main phase")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 8
	})).ok, "alvilda death test should add eight morale for enemy Honda", failures)
	var attacker_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0401")
	_expect(attacker_id != "", "alvilda death test should draw enemy Honda", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "alvilda death test should play enemy Honda", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	_make_attack_ready(state, attacker_instance_id)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": alvilda_instance_id
	})).ok, "enemy Honda attack into Alvilda should succeed", failures)
	_resolve_pending_attack(engine, state, failures, "Alvilda combat first pass should succeed", "Alvilda combat second pass should resolve and queue salvage")
	for _i in range(8):
		if not state.pending_choices.is_empty():
			break
		if state.stack.is_empty():
			break
		_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "Alvilda real death follow-up stack pass should succeed", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForChoice", "Alvilda real death should stop in waiting-for-choice state", failures)
	_expect(str(waiting.get("choice_type", "")) == "candidate_cards_pick", "Alvilda real death should expose candidate_cards_pick", failures)
	var choice = _require_pending_choice(state, failures, "Alvilda real death should request one salvage choice")
	if choice.is_empty():
		return
	_expect(str(choice.get("operation", "")) == "return_grave_to_hand", "Alvilda real death should use return_grave_to_hand choice operation", failures)
	_expect(choice.get("candidate_card_ids", []).has(salvaged_id), "Alvilda real death choice should include the seeded grave card", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": [salvaged_id]
	})).ok, "Alvilda real death salvage choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.has(salvaged_id), "Alvilda real death should return the chosen grave card to hand", failures)
	_expect(state.get_player(0).grave.cards.has(alvilda_instance_id), "Alvilda itself should remain in grave after real death salvage", failures)
	_expect(not state.get_player(0).grave.cards.has(salvaged_id), "The salvaged grave card should leave grave after being chosen", failures)
	_expect(_has_event_type(state, "CardReturnedToHand"), "Alvilda real death should log CardReturnedToHand", failures)
	_expect(_has_event_type(state, "CardDied"), "Alvilda real death should log CardDied", failures)

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

static func _require_pending_choice(state, failures: Array[String], message: String) -> Dictionary:
	if state.pending_choices.size() != 1:
		failures.append(message)
		return {}
	return state.pending_choices[0]

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
		if not state.pending_attack.is_empty():
			_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
			continue
		_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
	failures.append(message)

static func _resolve_pending_attack(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	if state.pending_attack.is_empty():
		return
	for step in range(4):
		if state.pending_attack.is_empty():
			return
		var message := first_message if step % 2 == 0 else second_message
		_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)

static func _make_attack_ready(state, card_id: String) -> void:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return
	instance.entered_turn = max(0, state.turn_number - 1)
	instance.orientation = "active"
	instance.has_attacked_this_turn = false

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

static func _move_owned_card_to_grave_by_definition(state, player_id: int, definition_id: String) -> String:
	var player = state.get_player(player_id)
	for raw_card_id in player.hand.cards.duplicate():
		var hand_card_id := str(raw_card_id)
		var hand_instance = state.card_instances.get(hand_card_id)
		if hand_instance == null or str(hand_instance.definition_id) != definition_id:
			continue
		player.hand.remove_card(hand_card_id)
		player.grave.add_card_to_top(hand_card_id)
		hand_instance.zone = "grave"
		hand_instance.position = {}
		hand_instance.face = "face_up"
		return hand_card_id
	for raw_card_id in player.deck.cards.duplicate():
		var deck_card_id := str(raw_card_id)
		var deck_instance = state.card_instances.get(deck_card_id)
		if deck_instance == null or str(deck_instance.definition_id) != definition_id:
			continue
		player.deck.remove_card(deck_card_id)
		player.grave.add_card_to_top(deck_card_id)
		deck_instance.zone = "grave"
		deck_instance.position = {}
		deck_instance.face = "face_up"
		return deck_card_id
	return ""

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _find_action_by_kind(actions: Array, kind: String) -> Dictionary:
	for action in actions:
		if str(action.get("kind", "")) == kind:
			return action
	return {}

static func _find_action_with_play_kind(actions: Array, play_kind: String) -> Dictionary:
	for action in actions:
		if str(action.get("play_kind", "")) == play_kind:
			return action
	return {}

static func _find_board_action_for_card(actions: Array, card_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("play_kind", "")) == "board_or_artifact" and str(action.get("payload_template", {}).get("card_id", "")) == card_id:
			return action
	return {}

static func _find_activate_action(actions: Array, source_id: String, effect_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("kind", "")) != "activate_effect":
			continue
		var payload = action.get("payload_template", {})
		if str(payload.get("source_id", "")) == source_id and str(payload.get("effect_id", "")) == effect_id:
			return action
	return {}

static func _targets_include_card(targets: Array, card_id: String) -> bool:
	for target in targets:
		if str(target.get("target_card_id", "")) == card_id or str(target.get("defender_id", "")) == card_id:
			return true
	return false

static func _player_has_definition_in_hand(state, player_id: int, definition_id: String) -> bool:
	return _find_hand_card_by_definition(state, player_id, definition_id) != ""

static func _has_pending_choice_operation(state, operation: String) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return true
	return false

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _count_event_type(state, event_type: String) -> int:
	var count = 0
	for event in state.event_log:
		if str(event.type) == event_type:
			count += 1
	return count

static func _is_card_on_battlefield(state, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	return instance != null and str(instance.zone).begins_with("battle_")

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
