extends RefCounted
class_name TestAsgardBatch7

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_andvaranot_setup_rules_draw_and_replacement(failures)
	_test_andvaranot_setup_can_be_suppressed_by_opening_choice(failures)
	_test_andvaranot_and_thor_hammer_combined_opening_choice(failures)
	_test_mimir_well_threshold_once_per_turn_and_optional_mill(failures)
	_test_blood_eagle_only_responds_to_own_legion_died(failures)
	_test_hammer_entry_and_died_trigger(failures)
	_test_hammer_grave_revive_with_thor(failures)
	return failures

static func _test_andvaranot_setup_rules_draw_and_replacement(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0305", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 4301, [
		{"name": "P1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(5, 4))
	_expect(state.get_player(0).artifact_zone.cards.size() == 1, "安德华拉诺特 should enter the artifact zone during setup", failures)
	var artifact_id = str(state.get_player(0).artifact_zone.cards[0]) if not state.get_player(0).artifact_zone.cards.is_empty() else ""
	var artifact_instance = state.card_instances.get(artifact_id)
	_expect(artifact_instance != null and str(artifact_instance.definition_id) == "asgard_s02_0305", "安德华拉诺特 setup artifact should be the correct definition", failures)
	_expect(state.get_player(0).hand.cards.size() == 4, "安德华拉诺特 should reduce the opening hand size to 4", failures)

	var extra_artifact_id = _add_card_to_hand(state, 0, "asgard_s02_0305")
	for _i in range(3):
		_add_card_to_hand(state, 0, "qa_blank")
	var artifact_play_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": extra_artifact_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(not artifact_play_result.ok and str(artifact_play_result.get("code", "")) == "ARTIFACT_PLAY_LOCKED", "安德华拉诺特 should forbid playing artifacts from hand while active", failures)

	var hand_before_draw = state.get_player(0).hand.cards.size()
	var first_damage_events = engine._deal_master_damage(state, 0, 1, "test_andvaranot_own_turn_damage")
	engine._enqueue_pending_triggers(state, first_damage_events)
	_expect(state.pending_triggers.size() == 1, "安德华拉诺特 should queue its draw trigger the first time the controller master is damaged on its turn", failures)
	_expect(not engine._promote_next_pending_trigger(state, "test_andvaranot_promote").is_empty(), "安德华拉诺特 should promote the queued trigger", failures)
	_resolve_top_stack(engine, state, failures, "安德华拉诺特 draw trigger should resolve to the optional draw choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "安德华拉诺特 should allow choosing to draw a card", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_draw + 1, "安德华拉诺特 should draw 1 card after choosing the trigger", failures)

	var second_damage_events = engine._deal_master_damage(state, 0, 1, "test_andvaranot_second_damage")
	engine._enqueue_pending_triggers(state, second_damage_events)
	_expect(state.pending_triggers.is_empty() and state.stack.is_empty(), "安德华拉诺特 draw trigger should only happen once per turn", failures)

	var hand_before_end = state.get_player(0).hand.cards.size()
	_expect(hand_before_end > 6, "安德华拉诺特 end-phase test should have more than 6 cards in hand", failures)
	var end_phase_result = engine.apply_command(state, GameCommand.create(0, "EndPhase"))
	_expect(end_phase_result.ok, "安德华拉诺特 should allow advancing to end phase", failures)
	var discard_choice = _pending_choice_by_operation(state, "discard_from_hand")
	_expect(discard_choice != null, "安德华拉诺特 should request a discard choice when hand size exceeds 6 at end phase", failures)
	if discard_choice != null:
		var selected_discards: Array[String] = []
		for raw_card_id in discard_choice.get("candidate_card_ids", []):
			selected_discards.append(str(raw_card_id))
			if selected_discards.size() == hand_before_end - 6:
				break
		_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
			"choice_id": str(discard_choice.get("choice_id", "")),
			"selected_card_ids": selected_discards
		})).ok, "安德华拉诺特 end-phase discard choice should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == 6, "安德华拉诺特 should discard down to exactly 6 cards", failures)

	engine._begin_turn_for_player(state, 1)
	var hp_before_replacement = state.get_player(0).master_hp
	var replacement_events = engine._deal_master_damage(state, 0, 1, "test_andvaranot_opponent_turn_damage", {
		"source_card_id": "master_1",
		"source_kind": "attack"
	})
	_expect(state.get_player(0).master_hp == hp_before_replacement - 2, "安德华拉诺特 should replace the first opponent-turn damage with 2", failures)
	_expect(_event_types_include(replacement_events, "ReplacementEffectApplied"), "安德华拉诺特 should log a replacement event when changing damage to 2", failures)
	engine._begin_turn_for_player(state, 1)
	var hp_before_calamity = state.get_player(0).master_hp
	var calamity_events = engine._deal_master_damage(state, 0, 1, "test_andvaranot_calamity_damage", {
		"source_kind": "calamity"
	})
	_expect(state.get_player(0).master_hp == hp_before_calamity - 1, "安德华拉诺特 should not replace non-opponent-source damage", failures)
	_expect(not _event_types_include(calamity_events, "ReplacementEffectApplied"), "安德华拉诺特 should not log a replacement event for non-opponent-source damage", failures)

static func _test_andvaranot_setup_can_be_suppressed_by_opening_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var options := _formal_options(1, 4)
	options["opening_setup_choices"] = [
		{"andvaranot_to_artifact": false},
		{}
	]
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0305", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 43011, [
		{"name": "P1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_hp": 8, "master_max_hp": 8}
	], options)
	_expect(state.get_player(0).artifact_zone.cards.is_empty(), "安德华拉诺特 explicit normal opening should leave the artifact in deck/hand flow", failures)
	var artifact_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0305")
	_expect(artifact_id != "", "安德华拉诺特 explicit normal opening should allow drawing the artifact normally", failures)
	if artifact_id == "":
		return
	var play_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(play_result.ok, "安德华拉诺特 explicit normal opening should not lock artifact plays from hand", failures)

static func _test_andvaranot_and_thor_hammer_combined_opening_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var options := _formal_options(6, 1)
	options["opening_setup_choices"] = [
		{
			"andvaranot_to_artifact": true,
			"thor_add_hammer_to_hand": true
		},
		{}
	]
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0305", "asgard_s02_0301", "qa_blank_a", "qa_blank_b", "qa_blank_c", "qa_blank_d", "qa_blank_e", "qa_blank_f"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 43012, [
		{"name": "P1", "master_name": "雷神索尔", "master_id": "asgard_s02_03m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_hp": 8, "master_max_hp": 8}
	], options)
	_expect(state.get_player(0).artifact_zone.cards.size() == 1, "combined opening should still place 安德华拉诺特 into the artifact zone", failures)
	var artifact_id = str(state.get_player(0).artifact_zone.cards[0]) if not state.get_player(0).artifact_zone.cards.is_empty() else ""
	var artifact_instance = state.card_instances.get(artifact_id)
	_expect(artifact_instance != null and str(artifact_instance.definition_id) == "asgard_s02_0305", "combined opening should place the correct 安德华拉诺特 copy into the artifact zone", failures)
	var hammer_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0301")
	_expect(hammer_id != "", "combined opening should put 雷神之锤 into the opening hand", failures)
	_expect(state.get_player(0).hand.cards.size() == 4, "combined opening should still end with exactly 4 opening hand cards", failures)
	var blank_count := 0
	for raw_card_id in state.get_player(0).hand.cards:
		var instance = state.card_instances.get(str(raw_card_id))
		if instance != null and str(instance.definition_id).begins_with("qa_blank"):
			blank_count += 1
	_expect(blank_count == 3, "combined opening should draw only 3 additional non-hammer opening cards", failures)
	_expect(not state.get_player(0).deck.cards.has(artifact_id), "combined opening should remove 安德华拉诺特 from the deck", failures)
	_expect(not state.get_player(0).deck.cards.has(hammer_id), "combined opening should remove 雷神之锤 from the deck after adding it to hand", failures)

static func _test_mimir_well_threshold_once_per_turn_and_optional_mill(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0306", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 4302, [
		{"name": "P1", "master_hp": 6, "master_max_hp": 6},
		{"name": "P2", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(1, 3))
	var mimir_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0306")
	_expect(mimir_id != "", "密米尔之泉 test should draw 密米尔之泉", failures)
	if mimir_id == "":
		return
	var unavailable_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mimir_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(not unavailable_result.ok and str(unavailable_result.get("code", "")) == "INSUFFICIENT_MASTER_DAMAGE", "密米尔之泉 should require at least 2 total damage to the controller master this turn", failures)

	engine._deal_master_damage(state, 0, 2, "test_mimir_damage_threshold", {
		"source_kind": "attack"
	})
	var hand_before_cast = state.get_player(0).hand.cards.size()
	var deck_before_cast = state.get_player(0).deck.cards.size()
	var hp_before_cast = state.get_player(0).master_hp
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mimir_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(cast_result.ok, "密米尔之泉 should cast after the threshold is met", failures)
	_resolve_top_stack(engine, state, failures, "密米尔之泉 should resolve to the optional mill choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "密米尔之泉 should allow choosing to mill 2 cards after healing and drawing", failures)
	_expect(state.get_player(0).master_hp == hp_before_cast + 1, "密米尔之泉 should heal 1 after meeting the threshold", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_cast, "密米尔之泉 should spend itself and then draw back 1 card", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before_cast - 3, "密米尔之泉 should draw 1 and mill 2 after choosing the optional mill", failures)
	_expect(state.get_player(0).grave.cards.has(mimir_id), "密米尔之泉 should move to grave after resolution", failures)

	var second_mimir_id = _add_card_to_hand(state, 0, "asgard_s02_0306")
	var second_cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_mimir_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(not second_cast_result.ok and str(second_cast_result.get("code", "")) == "EFFECT_ALREADY_USED", "密米尔之泉 should only be usable once per turn across copies", failures)

static func _test_blood_eagle_only_responds_to_own_legion_died(failures: Array[String]) -> void:
	var attack_engine = GameEngine.new()
	var attack_state = attack_engine.create_game(_definitions(), [
		["asgard_s01_0320", "takamagahara_s01_0412", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_plain", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 43025, [], _formal_options(2, 10))
	var attack_blood_eagle_id = _find_hand_card_by_definition(attack_state, 0, "asgard_s01_0320")
	var attack_tachibana_id = _find_hand_card_by_definition(attack_state, 0, "takamagahara_s01_0412")
	var attack_enemy_id = _find_hand_card_by_definition(attack_state, 1, "qa_plain")
	_expect(attack_blood_eagle_id != "" and attack_tachibana_id != "" and attack_enemy_id != "", "复仇血鹰 attack-response test should draw the required setup cards", failures)
	if attack_blood_eagle_id == "" or attack_tachibana_id == "" or attack_enemy_id == "":
		return
	_expect(not attack_engine._set_counter_tactic_from_hand_to_slot(attack_state, 0, attack_blood_eagle_id, 0, "test_blood_eagle_set").is_empty(), "复仇血鹰 should be set to the back row for testing", failures)
	_expect(not attack_engine._deploy_hand_card_to_slot(attack_state, 0, attack_tachibana_id, "front", 0, "test_blood_eagle_ally_setup").is_empty(), "复仇血鹰 attack-response test should deploy the allied legion", failures)
	_expect(not attack_engine._deploy_hand_card_to_slot(attack_state, 1, attack_enemy_id, "front", 0, "test_blood_eagle_enemy_setup").is_empty(), "复仇血鹰 attack-response test should deploy the enemy legion", failures)
	attack_engine._begin_turn_for_player(attack_state, 1)
	attack_state.card_instances[attack_enemy_id].entered_turn = -1
	var declare_attack_result = attack_engine.apply_command(attack_state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attack_enemy_id,
		"defender_id": attack_tachibana_id
	}))
	_expect(declare_attack_result.ok, "复仇血鹰 attack-response test should create a pending attack window", failures)
	var attack_actions = attack_engine.get_legal_actions(attack_state, 0)
	_expect(not _actions_include_activate_effect(attack_actions, attack_blood_eagle_id, "blood_eagle"), "复仇血鹰 should not respond to a plain attack window before any allied legion has died", failures)

	var died_engine = GameEngine.new()
	var died_state = died_engine.create_game(_definitions(), [
		["asgard_s01_0320", "qa_plain", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 43026, [], _formal_options(2, 10))
	var died_blood_eagle_id = _find_hand_card_by_definition(died_state, 0, "asgard_s01_0320")
	var died_plain_id = _find_hand_card_by_definition(died_state, 0, "qa_plain")
	_expect(died_blood_eagle_id != "" and died_plain_id != "", "复仇血鹰 died-response test should draw the required setup cards", failures)
	if died_blood_eagle_id == "" or died_plain_id == "":
		return
	_expect(not died_engine._set_counter_tactic_from_hand_to_slot(died_state, 0, died_blood_eagle_id, 0, "test_blood_eagle_set_for_died").is_empty(), "复仇血鹰 died-response test should set the counter tactic", failures)
	_expect(not died_engine._deploy_hand_card_to_slot(died_state, 0, died_plain_id, "front", 0, "test_blood_eagle_died_setup").is_empty(), "复仇血鹰 died-response test should deploy the allied legion", failures)
	var died_events = ZoneActions.move_battlefield_to_grave(died_state, 0, "front", 0, "test_blood_eagle_died")
	died_engine._enqueue_pending_triggers(died_state, died_events)
	_expect(died_state.pending_triggers.size() == 1, "复仇血鹰 should open a response window even when the allied died legion has no triggered effect", failures)
	_expect(not died_engine._promote_next_pending_trigger(died_state, "test_blood_eagle_promote").is_empty(), "复仇血鹰 died-response test should promote the allied died trigger onto the stack", failures)
	var enemy_pass = died_engine.apply_command(died_state, GameCommand.create(1, "PassPriority"))
	_expect(enemy_pass.ok, "复仇血鹰 died-response test should allow the opponent to pass priority", failures)
	var died_actions = died_engine.get_legal_actions(died_state, 0)
	_expect(_actions_include_activate_effect(died_actions, died_blood_eagle_id, "blood_eagle"), "复仇血鹰 should respond once an allied legion has died and opened a matching response window", failures)

static func _test_hammer_entry_and_died_trigger(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0301", "qa_blank", "qa_blank", "qa_blank", "qa_blank"],
		["asgard_s02_0301", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 4303, [
		{"name": "P1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 4))
	var hammer_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0301")
	var discard_id = _find_first_hand_card_not_definition(state, 0, "asgard_s02_0301")
	var enemy_hammer_id = _find_hand_card_by_definition(state, 1, "asgard_s02_0301")
	_expect(hammer_id != "" and discard_id != "" and enemy_hammer_id != "", "雷神之锤 entry test should draw both hammers and one discard card", failures)
	if hammer_id == "" or discard_id == "" or enemy_hammer_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_hammer_id, "front", 0, "test_enemy_hammer_setup")
	state.card_instances[enemy_hammer_id].entered_turn = -1
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hammer_id,
		"row": "front",
		"col": 0
	})).ok, "雷神之锤 should play successfully", failures)
	_expect(state.stack.is_empty(), "雷神之锤登场进攻主宰效果 should resolve without creating a popup stack item", failures)
	var legal_targets = engine.get_legal_attack_targets(state, hammer_id)
	_expect(_targets_include_master(legal_targets, 1), "雷神之锤 should be able to attack the enemy master on the turn it entered", failures)
	_expect(not _targets_include_card(legal_targets, enemy_hammer_id), "雷神之锤 entry turn should not allow attacking enemy legions", failures)

	var death_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_hammer_die")
	engine._enqueue_pending_triggers(state, death_events)
	_expect(not engine._promote_next_pending_trigger(state, "test_hammer_promote").is_empty(), "雷神之锤 should promote its died trigger", failures)
	_resolve_top_stack(engine, state, failures, "雷神之锤 died trigger should resolve to the optional draw choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "雷神之锤 should allow choosing to draw and discard on death", failures)
	_expect(_resolve_card_choice(engine, state, "discard_from_hand", [discard_id]), "雷神之锤 should request a hand discard after drawing", failures)
	_expect(state.get_player(0).grave.cards.has(discard_id), "雷神之锤 should discard the chosen hand card after drawing", failures)
	_expect(state.get_player(0).grave.cards.has(hammer_id), "雷神之锤 should remain in grave after its died trigger resolves", failures)

static func _test_hammer_grave_revive_with_thor(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0301", "qa_recycle_a", "qa_recycle_b", "qa_recycle_c", "qa_blank", "qa_blank"],
		["qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 4304, [
		{"name": "P1", "master_name": "雷神索尔", "master_id": "asgard_s02_03m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(4, 4))
	var hammer_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0301")
	var recycle_a = _find_hand_card_by_definition(state, 0, "qa_recycle_a")
	var recycle_b = _find_hand_card_by_definition(state, 0, "qa_recycle_b")
	var recycle_c = _find_hand_card_by_definition(state, 0, "qa_recycle_c")
	_expect(hammer_id != "" and recycle_a != "" and recycle_b != "" and recycle_c != "", "雷神之锤 grave test should draw 雷神之锤和3张回收卡", failures)
	if hammer_id == "" or recycle_a == "" or recycle_b == "" or recycle_c == "":
		return
	_move_hand_card_to_grave(state, 0, hammer_id)
	_move_hand_card_to_grave(state, 0, recycle_a)
	_move_hand_card_to_grave(state, 0, recycle_b)
	_move_hand_card_to_grave(state, 0, recycle_c)

	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "thor_hammer_grave_revive"
	}))
	_expect(activate_result.ok, "雷神之锤 should activate from the 雷神索尔 master panel when it is in grave", failures)
	_resolve_top_stack(engine, state, failures, "雷神之锤 grave effect should resolve to the recycle choice")
	var ordered_selection: Array[String] = [recycle_c, recycle_b, recycle_a]
	_expect(_resolve_card_choice(engine, state, "recycle_grave_then_revive_source_from_grave", ordered_selection), "雷神之锤 should choose 3 grave cards in the requested bottom order", failures)
	_expect(_pending_choice_by_operation(state, "revive_selected_grave_to_slot") != null, "雷神之锤 should ask the player to choose a battlefield slot before reviving", failures)
	_expect(_resolve_option_choice(engine, state, "revive_selected_grave_to_slot", "front:0"), "雷神之锤 should revive after the player clicks a highlighted slot", failures)

	var hammer_instance = state.card_instances.get(hammer_id)
	_expect(hammer_instance != null and str(hammer_instance.zone) == "battle_front", "雷神之锤 should revive itself to the selected battlefield slot after recycling 3 cards", failures)
	_expect(hammer_instance != null and int(hammer_instance.position.get("col", -1)) == 0, "雷神之锤 should use the slot chosen in the revive prompt", failures)
	_expect(hammer_instance != null and str(hammer_instance.orientation) == "active", "雷神之锤 should revive in active orientation", failures)
	_expect(not state.get_player(0).grave.cards.has(hammer_id), "雷神之锤 should leave grave after reviving itself", failures)
	var deck = state.get_player(0).deck.cards
	_expect(deck.size() >= 3 and str(deck[deck.size() - 3]) == recycle_c and str(deck[deck.size() - 2]) == recycle_b and str(deck[deck.size() - 1]) == recycle_a, "雷神之锤 should return the chosen grave cards to deck bottom in the selected order", failures)

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

static func _add_card_to_hand(state, player_id: int, definition_id: String) -> String:
	var card_id = state.create_instance(definition_id, player_id, player_id)
	state.get_player(player_id).hand.add_card(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "hand"
		instance.position = {}
		instance.orientation = "active"
	return card_id

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

static func _move_hand_card_to_grave(state, player_id: int, card_id: String) -> void:
	var player = state.get_player(player_id)
	player.hand.remove_card(card_id)
	player.grave.add_card(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "grave"
		instance.position = {}
		instance.orientation = "active"

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

static func _resolve_card_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array[String]) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected_card_ids
	})).ok

static func _pending_choice_by_operation(state, operation: String):
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return null

static func _find_first_hand_card_not_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) != definition_id:
			return str(card_id)
	return ""

static func _targets_include_master(targets: Array, target_player: int) -> bool:
	for target in targets:
		if target is Dictionary and str(target.get("target_kind", "")) == "master" and int(target.get("target_player", -1)) == target_player:
			return true
	return false

static func _targets_include_card(targets: Array, defender_id: String) -> bool:
	for target in targets:
		if target is Dictionary and str(target.get("target_kind", "")) == "card" and str(target.get("defender_id", "")) == defender_id:
			return true
	return false

static func _actions_include_activate_effect(actions: Array, source_id: String, effect_id: String = "") -> bool:
	for action in actions:
		if str(action.get("kind", "")) != "activate_effect":
			continue
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("source_id", "")) != source_id:
			continue
		if effect_id.is_empty() or str(payload.get("effect_id", "")) == effect_id:
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
