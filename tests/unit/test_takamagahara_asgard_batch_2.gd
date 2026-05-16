extends RefCounted
class_name TestTakamagaharaAsgardBatch2

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_uesugi_entry_destroy_and_died_set(failures)
	_test_uesugi_died_skips_without_back_slot(failures)
	_test_uesugi_died_with_one_back_slot_only_allows_one_counter(failures)
	_test_seppuku_set_counter_responds_after_attack_finishes(failures)
	_test_brynhildr_entry_choose_source_then_deploy_sigurd(failures)
	_test_brynhildr_entry_without_grave_sigurd_goes_direct_to_hand(failures)
	_test_brynhildr_entry_without_hand_sigurd_goes_direct_to_grave(failures)
	_test_brynhildr_entry_skips_when_no_slot_or_no_sigurd(failures)
	_test_brynhildr_died_draw(failures)
	_test_wuyun_search_discount_and_charge(failures)
	return failures

static func _test_uesugi_entry_destroy_and_died_set(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0403", "takamagahara_s01_0420", "asgard_s01_0320", "takamagahara_s01_0420", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3101, [], _formal_options(5, 8))
	var allied_set_a = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0420")
	var allied_set_b = _find_hand_card_by_definition(state, 0, "asgard_s01_0320")
	var reserve_counter_id = _find_second_hand_card_by_definition(state, 0, "takamagahara_s01_0420", allied_set_a)
	var enemy_big = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	var enemy_small = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(allied_set_a != "" and allied_set_b != "" and reserve_counter_id != "" and enemy_big != "" and enemy_small != "", "uesugi test should draw the setup cards", failures)
	if allied_set_a == "" or allied_set_b == "" or reserve_counter_id == "" or enemy_big == "" or enemy_small == "":
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, allied_set_a, 0, "test_uesugi_set_a").is_empty(), "uesugi setup should set the first counter tactic", failures)
	_expect(not engine._deploy_hand_card_to_slot(state, 1, enemy_big, "front", 0, "test_uesugi_enemy_big").is_empty(), "uesugi setup should deploy the expensive enemy legion", failures)
	_expect(not engine._deploy_hand_card_to_slot(state, 1, enemy_small, "front", 1, "test_uesugi_enemy_small").is_empty(), "uesugi setup should deploy the cheap enemy legion", failures)
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, allied_set_b, 1, "test_uesugi_set_b").is_empty(), "uesugi setup should set the second counter tactic", failures)
	var uesugi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0403")
	_expect(uesugi_id != "", "uesugi should be in opening hand", failures)
	if uesugi_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": uesugi_id,
		"row": "front",
		"col": 0
	})).ok, "uesugi should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "uesugi entry trigger should resolve to a destroy choice")
	_expect(_resolve_candidate_choice(engine, state, "destroy_battlefield_card", [enemy_small]), "uesugi entry trigger should only be able to choose the lower-cost target", failures)
	_expect(state.get_player(1).battle_front[1].occupant == "", "uesugi entry trigger should destroy the cost-1 enemy legion", failures)
	_expect(state.get_player(1).battle_front[0].occupant == enemy_big, "uesugi entry trigger should not destroy the cost-2 enemy legion when only two counter tactics are on the battlefield", failures)
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {
			"target_card_id": uesugi_id
		},
		"resolution": {}
	}, "test_uesugi_destroy")
	engine._enqueue_pending_triggers(state, destroy_events)
	engine._promote_next_pending_trigger(state, "test_uesugi_promote")
	_resolve_top_stack(engine, state, failures, "uesugi death trigger should resolve after the direct destroy helper removes it from the battlefield")
	_expect(_resolve_candidate_choice(engine, state, "set_counter_tactics_from_hand", [reserve_counter_id]), "uesugi death trigger should allow choosing up to two hand counter tactics", failures)
	_expect(_resolve_option_choice(engine, state, "set_counter_tactic_from_hand_to_slot", "back:2"), "uesugi death trigger should let the player choose which back-row slot receives the counter tactic", failures)
	_expect(state.get_player(0).battle_back[2].occupant == reserve_counter_id, "uesugi death trigger should place the chosen counter tactic into the selected back-row slot", failures)
	var set_instance = state.card_instances.get(reserve_counter_id)
	_expect(set_instance != null and str(set_instance.face) == "face_down", "uesugi death trigger should set the moved counter tactic face-down", failures)

static func _test_uesugi_died_skips_without_back_slot(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0403", "takamagahara_s01_0420", "asgard_s01_0320", "takamagahara_s01_0420", "asgard_s01_0320", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31011, [], _formal_options(7, 8))
	var counter_ids := _find_hand_counter_tactic_ids(state, 0)
	var enemy_big = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	var enemy_small = _find_hand_card_by_definition(state, 1, "qa_plain")
	var uesugi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0403")
	_expect(counter_ids.size() >= 3 and enemy_big != "" and enemy_small != "" and uesugi_id != "", "uesugi full-back test should draw 上杉谦信, three counter tactics and enemy setup", failures)
	if counter_ids.size() < 3 or enemy_big == "" or enemy_small == "" or uesugi_id == "":
		return
	for col in range(3):
		_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, counter_ids[col], col, "test_uesugi_full_back_set_%d" % col).is_empty(), "uesugi full-back test should fill every back-row slot", failures)
	_expect(not engine._deploy_hand_card_to_slot(state, 1, enemy_big, "front", 0, "test_uesugi_full_back_enemy_big").is_empty(), "uesugi full-back test should deploy the expensive enemy legion", failures)
	_expect(not engine._deploy_hand_card_to_slot(state, 1, enemy_small, "front", 1, "test_uesugi_full_back_enemy_small").is_empty(), "uesugi full-back test should deploy the cheap enemy legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": uesugi_id,
		"row": "front",
		"col": 0
	})).ok, "uesugi full-back test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "uesugi full-back entry trigger should resolve to the destroy choice")
	_expect(_resolve_candidate_choice(engine, state, "destroy_battlefield_card", [enemy_small]), "uesugi full-back entry trigger should still destroy the lower-cost target", failures)
	var reserve_counter_ids := _find_hand_counter_tactic_ids(state, 0)
	_expect(not reserve_counter_ids.is_empty(), "uesugi full-back test should still keep at least one counter tactic in hand", failures)
	if reserve_counter_ids.is_empty():
		return
	var reserved_counter_id := reserve_counter_ids[0]
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {"target_card_id": uesugi_id},
		"resolution": {}
	}, "test_uesugi_destroy_full_back")
	engine._enqueue_pending_triggers(state, destroy_events)
	engine._promote_next_pending_trigger(state, "test_uesugi_promote_full_back")
	_resolve_top_stack(engine, state, failures, "uesugi full-back death trigger should skip when no back slot is empty")
	_expect(_pending_choice_by_operation(state, "set_counter_tactics_from_hand") == null, "uesugi full-back death trigger should not open a candidate choice when no back slot is empty", failures)
	_expect(_pending_choice_by_operation(state, "set_counter_tactic_from_hand_to_slot") == null, "uesugi full-back death trigger should not ask for a back-row slot when no slot is available", failures)
	_expect(state.get_player(0).hand.cards.has(reserved_counter_id), "uesugi full-back death trigger should leave the reserve counter tactic in hand when no back slot is available", failures)

static func _test_uesugi_died_with_one_back_slot_only_allows_one_counter(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0403", "takamagahara_s01_0420", "asgard_s01_0320", "takamagahara_s01_0420", "asgard_s01_0320", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31012, [], _formal_options(7, 8))
	var counter_ids := _find_hand_counter_tactic_ids(state, 0)
	var enemy_big = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	var enemy_small = _find_hand_card_by_definition(state, 1, "qa_plain")
	var uesugi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0403")
	_expect(counter_ids.size() >= 4 and enemy_big != "" and enemy_small != "" and uesugi_id != "", "uesugi one-slot test should draw 上杉谦信, four counter tactics and enemy setup", failures)
	if counter_ids.size() < 4 or enemy_big == "" or enemy_small == "" or uesugi_id == "":
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, counter_ids[0], 0, "test_uesugi_one_slot_set_0").is_empty(), "uesugi one-slot test should fill back row column 0", failures)
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, counter_ids[1], 1, "test_uesugi_one_slot_set_1").is_empty(), "uesugi one-slot test should fill back row column 1", failures)
	_expect(not engine._deploy_hand_card_to_slot(state, 1, enemy_big, "front", 0, "test_uesugi_one_slot_enemy_big").is_empty(), "uesugi one-slot test should deploy the expensive enemy legion", failures)
	_expect(not engine._deploy_hand_card_to_slot(state, 1, enemy_small, "front", 1, "test_uesugi_one_slot_enemy_small").is_empty(), "uesugi one-slot test should deploy the cheap enemy legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": uesugi_id,
		"row": "front",
		"col": 0
	})).ok, "uesugi one-slot test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "uesugi one-slot entry trigger should resolve to the destroy choice")
	_expect(_resolve_candidate_choice(engine, state, "destroy_battlefield_card", [enemy_small]), "uesugi one-slot entry trigger should still destroy the lower-cost target", failures)
	var reserve_counter_ids := _find_hand_counter_tactic_ids(state, 0)
	_expect(reserve_counter_ids.size() >= 2, "uesugi one-slot test should leave at least two counter tactics in hand before the death trigger", failures)
	if reserve_counter_ids.size() < 2:
		return
	var first_reserve_id := reserve_counter_ids[0]
	var second_reserve_id := reserve_counter_ids[1]
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {"target_card_id": uesugi_id},
		"resolution": {}
	}, "test_uesugi_destroy_one_slot")
	engine._enqueue_pending_triggers(state, destroy_events)
	engine._promote_next_pending_trigger(state, "test_uesugi_promote_one_slot")
	_resolve_top_stack(engine, state, failures, "uesugi one-slot death trigger should resolve to the candidate choice")
	var set_choice = _pending_choice_by_operation(state, "set_counter_tactics_from_hand")
	_expect(set_choice != null, "uesugi one-slot death trigger should request a counter tactic choice", failures)
	if set_choice != null:
		_expect(int(set_choice.get("count", -1)) == 1, "uesugi one-slot death trigger should only allow selecting one counter tactic when only one back slot is empty", failures)
	_expect(not _resolve_candidate_choice(engine, state, "set_counter_tactics_from_hand", [first_reserve_id, second_reserve_id]), "uesugi one-slot death trigger should reject selecting two counter tactics when only one back slot is empty", failures)
	_expect(_resolve_candidate_choice(engine, state, "set_counter_tactics_from_hand", [first_reserve_id]), "uesugi one-slot death trigger should still allow selecting a single counter tactic", failures)
	_expect(_resolve_option_choice(engine, state, "set_counter_tactic_from_hand_to_slot", "back:2"), "uesugi one-slot death trigger should allow choosing the only empty back slot", failures)
	_expect(state.get_player(0).battle_back[2].occupant == first_reserve_id, "uesugi one-slot death trigger should place the chosen counter tactic into the only empty back-row slot", failures)
	_expect(state.get_player(0).hand.cards.has(second_reserve_id), "uesugi one-slot death trigger should leave the extra reserve counter tactic in hand", failures)

static func _test_brynhildr_entry_choose_source_then_deploy_sigurd(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s01_0309", "asgard_s01_0310", "qa_vanilla", "qa_vanilla", "qa_plain", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3102, [], _formal_options(4, 8))
	var brynhildr_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0309")
	var hand_sigurd_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0310")
	var grave_other_a = _add_card_to_grave(state, 0, "qa_vanilla")
	var grave_sigurd_id = _add_card_to_grave(state, 0, "asgard_s01_0310")
	var grave_other_b = _add_card_to_grave(state, 0, "qa_plain")
	_expect(brynhildr_id != "" and hand_sigurd_id != "" and grave_sigurd_id != "" and grave_other_a != "" and grave_other_b != "", "brynhildr source-choice test should draw 布伦希尔德、手牌齐格鲁德并预置墓地", failures)
	if brynhildr_id == "" or hand_sigurd_id == "" or grave_sigurd_id == "" or grave_other_a == "" or grave_other_b == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": brynhildr_id,
		"row": "back",
		"col": 0
	})).ok, "布伦希尔德 should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "布伦希尔德 entry should resolve to the optional self-damage choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "布伦希尔德 entry should offer the optional self-damage choice", failures)
	_expect(state.get_player(0).master_hp == 19, "布伦希尔德 entry should deal 1 damage to its controller master when the option is chosen", failures)
	var source_choice = _pending_choice_by_operation(state, "brynhildr_choose_sigurd_source")
	_expect(source_choice != null, "布伦希尔德 entry should ask whether 齐格鲁德 comes from hand or grave when both zones contain one", failures)
	if source_choice != null:
		_expect(_resolve_option_choice(engine, state, "brynhildr_choose_sigurd_source", "hand"), "布伦希尔德 entry should accept choosing the hand source", failures)
		var hand_choice = _pending_choice_by_operation(state, "deploy_from_hand_to_battlefield")
		_expect(hand_choice != null, "布伦希尔德 hand branch should open the hand deployment choice", failures)
		if hand_choice != null:
			_expect(_same_string_arrays(_string_array_from_variant_array(hand_choice.get("candidate_card_ids", [])), [hand_sigurd_id]), "布伦希尔德 hand branch should only expose hand 齐格鲁德 as a candidate", failures)
			_expect(_same_string_arrays(_string_array_from_variant_array(hand_choice.get("context", {}).get("highlight_card_ids", [])), [hand_sigurd_id]), "布伦希尔德 hand branch should highlight hand 齐格鲁德", failures)
		_expect(_resolve_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [hand_sigurd_id]), "布伦希尔德 hand branch should accept choosing hand 齐格鲁德", failures)
		_expect(_resolve_option_choice(engine, state, "deploy_selected_hand_to_slot", "front:0"), "布伦希尔德 hand branch should accept choosing a battlefield slot", failures)
		_expect(state.get_player(0).battle_front[0].occupant == hand_sigurd_id, "布伦希尔德 hand branch should deploy the hand 齐格鲁德 onto the battlefield", failures)

	var engine_grave = GameEngine.new()
	var state_grave = engine_grave.create_game(_definitions(), [
		["asgard_s01_0309", "asgard_s01_0310", "qa_vanilla", "qa_vanilla", "qa_plain", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31021, [], _formal_options(4, 8))
	var brynhildr_grave_id = _find_hand_card_by_definition(state_grave, 0, "asgard_s01_0309")
	var grave_branch_hand_sigurd_id = _find_hand_card_by_definition(state_grave, 0, "asgard_s01_0310")
	var grave_branch_other_a = _add_card_to_grave(state_grave, 0, "qa_vanilla")
	var grave_branch_sigurd_id = _add_card_to_grave(state_grave, 0, "asgard_s01_0310")
	var grave_branch_other_b = _add_card_to_grave(state_grave, 0, "qa_plain")
	_expect(brynhildr_grave_id != "" and grave_branch_hand_sigurd_id != "" and grave_branch_sigurd_id != "" and grave_branch_other_a != "" and grave_branch_other_b != "", "brynhildr grave-branch test should draw 布伦希尔德、手牌齐格鲁德并预置墓地", failures)
	if brynhildr_grave_id == "" or grave_branch_hand_sigurd_id == "" or grave_branch_sigurd_id == "" or grave_branch_other_a == "" or grave_branch_other_b == "":
		return
	_expect(engine_grave.apply_command(state_grave, GameCommand.create(0, "PlayCard", {
		"card_id": brynhildr_grave_id,
		"row": "back",
		"col": 0
	})).ok, "布伦希尔德 grave-branch test should play successfully", failures)
	_resolve_top_stack(engine_grave, state_grave, failures, "布伦希尔德 grave-branch entry trigger should resolve to the optional self-damage choice")
	_expect(_resolve_option_choice(engine_grave, state_grave, "optional_stack_effect", "yes"), "布伦希尔德 grave-branch entry should offer the optional self-damage choice", failures)
	var source_choice_grave = _pending_choice_by_operation(state_grave, "brynhildr_choose_sigurd_source")
	_expect(source_choice_grave != null, "布伦希尔德 grave-branch entry should ask for the source when both hand and grave contain 齐格鲁德", failures)
	if source_choice_grave != null:
		_expect(_resolve_option_choice(engine_grave, state_grave, "brynhildr_choose_sigurd_source", "grave"), "布伦希尔德 entry should accept choosing the grave source", failures)
		var grave_choice = _pending_choice_by_operation(state_grave, "revive_from_grave")
		_expect(grave_choice != null, "布伦希尔德 grave branch should open the grave selection choice", failures)
		if grave_choice != null:
			_expect(_same_string_arrays(_string_array_from_variant_array(grave_choice.get("candidate_card_ids", [])), [grave_branch_sigurd_id]), "布伦希尔德 grave branch should only expose grave 齐格鲁德 as a selectable target", failures)
			_expect(_same_string_arrays(_string_array_from_variant_array(grave_choice.get("context", {}).get("highlight_card_ids", [])), [grave_branch_sigurd_id]), "布伦希尔德 grave branch should only highlight grave 齐格鲁德", failures)
			_expect(_same_string_arrays(_string_array_from_variant_array(grave_choice.get("context", {}).get("display_card_ids", [])), _string_array_from_variant_array(state_grave.get_player(0).grave.cards)), "布伦希尔德 grave branch should display the full grave in order", failures)
		_expect(_resolve_candidate_choice(engine_grave, state_grave, "revive_from_grave", [grave_branch_sigurd_id]), "布伦希尔德 grave branch should accept choosing grave 齐格鲁德", failures)
		_expect(_resolve_option_choice(engine_grave, state_grave, "revive_selected_grave_to_slot", "front:0"), "布伦希尔德 grave branch should accept choosing a battlefield slot", failures)
		_expect(state_grave.get_player(0).battle_front[0].occupant == grave_branch_sigurd_id, "布伦希尔德 grave branch should revive 齐格鲁德 onto the battlefield", failures)
		_expect(not state_grave.get_player(0).grave.cards.has(grave_branch_sigurd_id), "布伦希尔德 grave branch should remove the revived 齐格鲁德 from grave", failures)

static func _test_brynhildr_entry_without_grave_sigurd_goes_direct_to_hand(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s01_0309", "asgard_s01_0310", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31022, [], _formal_options(4, 8))
	var brynhildr_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0309")
	var sigurd_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0310")
	_expect(brynhildr_id != "" and sigurd_id != "", "brynhildr hand-only test should draw both 布伦希尔德 and 齐格鲁德", failures)
	if brynhildr_id == "" or sigurd_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": brynhildr_id,
		"row": "back",
		"col": 0
	})).ok, "布伦希尔德 hand-only test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "布伦希尔德 hand-only entry trigger should resolve to the optional self-damage choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "布伦希尔德 hand-only entry should offer the optional self-damage choice", failures)
	_expect(_pending_choice_by_operation(state, "brynhildr_choose_sigurd_source") == null, "布伦希尔德 hand-only entry should skip the source choice when grave has no 齐格鲁德", failures)
	var hand_choice = _pending_choice_by_operation(state, "deploy_from_hand_to_battlefield")
	_expect(hand_choice != null, "布伦希尔德 hand-only entry should go directly to the hand deployment choice", failures)
	if hand_choice != null:
		_expect(_same_string_arrays(_string_array_from_variant_array(hand_choice.get("candidate_card_ids", [])), [sigurd_id]), "布伦希尔德 hand-only entry should only expose hand 齐格鲁德", failures)
	_expect(_resolve_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [sigurd_id]), "布伦希尔德 hand-only entry should accept choosing hand 齐格鲁德", failures)
	_expect(_resolve_option_choice(engine, state, "deploy_selected_hand_to_slot", "front:0"), "布伦希尔德 hand-only entry should accept choosing a battlefield slot", failures)
	_expect(state.get_player(0).battle_front[0].occupant == sigurd_id, "布伦希尔德 hand-only entry should deploy 齐格鲁德 onto the battlefield", failures)

static func _test_brynhildr_entry_without_hand_sigurd_goes_direct_to_grave(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s01_0309", "qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31023, [], _formal_options(4, 8))
	var brynhildr_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0309")
	var grave_other_a = _add_card_to_grave(state, 0, "qa_vanilla")
	var grave_sigurd_id = _add_card_to_grave(state, 0, "asgard_s01_0310")
	var grave_other_b = _add_card_to_grave(state, 0, "qa_plain")
	_expect(brynhildr_id != "" and grave_sigurd_id != "" and grave_other_a != "" and grave_other_b != "", "brynhildr grave-only test should draw 布伦希尔德 and prefill the grave", failures)
	if brynhildr_id == "" or grave_sigurd_id == "" or grave_other_a == "" or grave_other_b == "":
		return
	_expect(_find_hand_card_by_definition(state, 0, "asgard_s01_0310") == "", "布伦希尔德 grave-only test should not keep 齐格鲁德 in hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": brynhildr_id,
		"row": "back",
		"col": 0
	})).ok, "布伦希尔德 grave-only test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "布伦希尔德 grave-only entry trigger should resolve to the optional self-damage choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "布伦希尔德 grave-only entry should offer the optional self-damage choice", failures)
	_expect(_pending_choice_by_operation(state, "brynhildr_choose_sigurd_source") == null, "布伦希尔德 grave-only entry should skip the source choice when hand has no 齐格鲁德", failures)
	var grave_choice = _pending_choice_by_operation(state, "revive_from_grave")
	_expect(grave_choice != null, "布伦希尔德 grave-only entry should go directly to the grave selection choice", failures)
	if grave_choice != null:
		_expect(_same_string_arrays(_string_array_from_variant_array(grave_choice.get("candidate_card_ids", [])), [grave_sigurd_id]), "布伦希尔德 grave-only entry should only expose grave 齐格鲁德", failures)
		_expect(_same_string_arrays(_string_array_from_variant_array(grave_choice.get("context", {}).get("display_card_ids", [])), _string_array_from_variant_array(state.get_player(0).grave.cards)), "布伦希尔德 grave-only entry should display the full grave in order", failures)
	_expect(_resolve_candidate_choice(engine, state, "revive_from_grave", [grave_sigurd_id]), "布伦希尔德 grave-only entry should accept choosing grave 齐格鲁德", failures)
	_expect(_resolve_option_choice(engine, state, "revive_selected_grave_to_slot", "front:0"), "布伦希尔德 grave-only entry should accept choosing a battlefield slot", failures)
	_expect(state.get_player(0).battle_front[0].occupant == grave_sigurd_id, "布伦希尔德 grave-only entry should revive 齐格鲁德 onto the battlefield", failures)

static func _test_brynhildr_entry_skips_when_no_slot_or_no_sigurd(failures: Array[String]) -> void:
	var engine_no_slot = GameEngine.new()
	var state_no_slot = engine_no_slot.create_game(_definitions(), [
		["asgard_s01_0309", "asgard_s01_0310", "qa_vanilla", "qa_vanilla", "qa_vanilla", "takamagahara_s01_0420", "asgard_s01_0320"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31024, [], _formal_options(7, 8))
	var brynhildr_no_slot_id = _find_hand_card_by_definition(state_no_slot, 0, "asgard_s01_0309")
	var sigurd_no_slot_id = _find_hand_card_by_definition(state_no_slot, 0, "asgard_s01_0310")
	var front_fillers = _find_hand_cards_by_definition(state_no_slot, 0, "qa_vanilla", 3)
	var back_counter_a = _find_hand_card_by_definition(state_no_slot, 0, "takamagahara_s01_0420")
	var back_counter_b = _find_hand_card_by_definition(state_no_slot, 0, "asgard_s01_0320")
	_expect(brynhildr_no_slot_id != "" and sigurd_no_slot_id != "" and front_fillers.size() == 3 and back_counter_a != "" and back_counter_b != "", "brynhildr no-slot test should draw 布伦希尔德、齐格鲁德、three front fillers and two back fillers", failures)
	if brynhildr_no_slot_id == "" or sigurd_no_slot_id == "" or front_fillers.size() != 3 or back_counter_a == "" or back_counter_b == "":
		return
	_add_card_to_grave(state_no_slot, 0, "asgard_s01_0310")
	for col in range(front_fillers.size()):
		_expect(not engine_no_slot._deploy_hand_card_to_slot(state_no_slot, 0, front_fillers[col], "front", col, "test_brynhildr_fill_front_%d" % col).is_empty(), "布伦希尔德 no-slot test should fill every front slot before 布伦希尔德 enters", failures)
	_expect(not engine_no_slot._set_counter_tactic_from_hand_to_slot(state_no_slot, 0, back_counter_a, 0, "test_brynhildr_fill_back_0").is_empty(), "布伦希尔德 no-slot test should fill one back slot with a counter tactic", failures)
	_expect(not engine_no_slot._set_counter_tactic_from_hand_to_slot(state_no_slot, 0, back_counter_b, 1, "test_brynhildr_fill_back_1").is_empty(), "布伦希尔德 no-slot test should fill the second back slot with a counter tactic", failures)
	_expect(engine_no_slot.apply_command(state_no_slot, GameCommand.create(0, "PlayCard", {
		"card_id": brynhildr_no_slot_id,
		"row": "back",
		"col": 2
	})).ok, "布伦希尔德 no-slot test should play successfully into the last empty slot", failures)
	_resolve_top_stack(engine_no_slot, state_no_slot, failures, "布伦希尔德 no-slot entry trigger should resolve to the optional self-damage choice")
	_expect(_resolve_option_choice(engine_no_slot, state_no_slot, "optional_stack_effect", "yes"), "布伦希尔德 no-slot entry should still offer the optional self-damage choice", failures)
	_expect(state_no_slot.get_player(0).master_hp == 19, "布伦希尔德 no-slot entry should still deal 1 damage to its controller master", failures)
	_expect(state_no_slot.pending_choices.is_empty(), "布伦希尔德 no-slot entry should end immediately without extra choices when no slot is available", failures)
	_expect(state_no_slot.get_player(0).hand.cards.has(sigurd_no_slot_id), "布伦希尔德 no-slot entry should leave hand 齐格鲁德 in hand when no slot is available", failures)

	var engine_no_sigurd = GameEngine.new()
	var state_no_sigurd = engine_no_sigurd.create_game(_definitions(), [
		["asgard_s01_0309", "qa_vanilla", "qa_plain", "qa_vanilla", "qa_plain", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31026, [], _formal_options(4, 8))
	var brynhildr_no_sigurd_id = _find_hand_card_by_definition(state_no_sigurd, 0, "asgard_s01_0309")
	_expect(brynhildr_no_sigurd_id != "", "brynhildr no-sigurd test should draw 布伦希尔德", failures)
	if brynhildr_no_sigurd_id == "":
		return
	_expect(_find_hand_card_by_definition(state_no_sigurd, 0, "asgard_s01_0310") == "", "布伦希尔德 no-sigurd test should not draw 齐格鲁德 in hand", failures)
	_expect(state_no_sigurd.get_player(0).grave.cards.is_empty(), "布伦希尔德 no-sigurd test should start with an empty grave", failures)
	_expect(engine_no_sigurd.apply_command(state_no_sigurd, GameCommand.create(0, "PlayCard", {
		"card_id": brynhildr_no_sigurd_id,
		"row": "back",
		"col": 0
	})).ok, "布伦希尔德 no-sigurd test should play successfully", failures)
	_resolve_top_stack(engine_no_sigurd, state_no_sigurd, failures, "布伦希尔德 no-sigurd entry trigger should resolve to the optional self-damage choice")
	_expect(_resolve_option_choice(engine_no_sigurd, state_no_sigurd, "optional_stack_effect", "yes"), "布伦希尔德 no-sigurd entry should still offer the optional self-damage choice", failures)
	_expect(state_no_sigurd.get_player(0).master_hp == 19, "布伦希尔德 no-sigurd entry should still deal 1 damage to its controller master", failures)
	_expect(state_no_sigurd.pending_choices.is_empty(), "布伦希尔德 no-sigurd entry should end immediately when neither hand nor grave contains 齐格鲁德", failures)

static func _test_brynhildr_died_draw(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s01_0309", "asgard_s01_0310", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31027, [], _formal_options(4, 8))
	var brynhildr_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0309")
	var sigurd_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0310")
	_expect(brynhildr_id != "" and sigurd_id != "", "brynhildr death test should draw both 布伦希尔德 and 齐格鲁德", failures)
	if brynhildr_id == "" or sigurd_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": brynhildr_id,
		"row": "back",
		"col": 0
	})).ok, "布伦希尔德 death test should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "布伦希尔德 death test entry trigger should resolve to the optional self-damage choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "布伦希尔德 death test entry should offer the optional self-damage choice", failures)
	_expect(_resolve_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [sigurd_id]), "布伦希尔德 death test should accept choosing hand 齐格鲁德", failures)
	_expect(_resolve_option_choice(engine, state, "deploy_selected_hand_to_slot", "front:0"), "布伦希尔德 death test should accept choosing a battlefield slot for hand 齐格鲁德", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 15
	})).ok, "布伦希尔德 death test should lower the controller master HP", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 18
	})).ok, "布伦希尔德 death test should keep the opponent master HP higher", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	var brynhildr_destroy_events = engine._destroy_target_unit(state, {
		"targets": {
			"target_card_id": brynhildr_id
		},
		"resolution": {}
	}, "test_brynhildr_destroy")
	engine._enqueue_pending_triggers(state, brynhildr_destroy_events)
	engine._promote_next_pending_trigger(state, "test_brynhildr_promote")
	_resolve_top_stack(engine, state, failures, "布伦希尔德 death trigger should resolve to the optional draw choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "布伦希尔德 death trigger should allow choosing to draw", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + 1, "布伦希尔德 death trigger should draw one card when the controller HP is not higher than the opponent", failures)

static func _test_seppuku_set_counter_responds_after_attack_finishes(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0420", "qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 31025, [], _formal_options(2, 10))
	var seppuku_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0420")
	var defender_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(seppuku_id != "" and defender_id != "" and attacker_id != "", "seppuku response test should draw setup cards", failures)
	if seppuku_id == "" or defender_id == "" or attacker_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": seppuku_id,
		"row": "back",
		"col": 0
	})).ok, "seppuku response test should set the counter tactic", failures)
	engine._deploy_hand_card_to_slot(state, 0, defender_id, "front", 0, "test_seppuku_defender")
	engine._deploy_hand_card_to_slot(state, 1, attacker_id, "front", 0, "test_seppuku_attacker")
	engine._begin_turn_for_player(state, 1)
	var attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	}))
	_expect(bool(attack.get("ok", false)), "seppuku response test should let the opponent declare an attack", failures)
	if not bool(attack.get("ok", false)):
		return
	var counter_action = _find_activate_effect_action(engine.get_legal_actions(state, 0), seppuku_id, "seppuku")
	_expect(counter_action.is_empty(), "seppuku should not appear while the attack is still pending", failures)
	_resolve_pending_attack(engine, state, failures, "seppuku post-attack test first priority pass should succeed", "seppuku post-attack test second priority pass should finish the attack and queue the trigger")
	_expect(state.pending_attack.is_empty(), "seppuku should clear the pending attack after combat finishes", failures)
	_expect(not state.stack.is_empty(), "seppuku should queue after the opponent attack finishes", failures)
	_resolve_top_stack(engine, state, failures, "seppuku post-attack trigger should resolve to a cost-modifier choice")
	_expect(_pending_choice_by_operation(state, "modify_cost_until_next_own_turn_end") != null, "seppuku should request the enemy legion cost modifier target", failures)
	_expect(_resolve_candidate_choice(engine, state, "modify_cost_until_next_own_turn_end", [attacker_id]), "seppuku should apply its follow-up target choice", failures)
	_expect(engine._get_effective_card_cost(state, attacker_id) == 0, "seppuku should reduce the enemy legion cost by 2", failures)
	_expect(state.pending_attack.is_empty(), "seppuku should not recreate a pending attack window after choosing the cost modifier target", failures)

static func _test_wuyun_search_discount_and_charge(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0405", "asgard_s01_0317", "takamagahara_s01_0403", "qa_vanilla", "qa_plain", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3103, [], _formal_options(1, 5))
	var tactic_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0405")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(tactic_id != "" and enemy_id != "", "wuyun test should draw the tactic and an enemy legion", failures)
	if tactic_id == "" or enemy_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_wuyun_enemy")
	var top_five_before = state.get_player(0).deck.cards.slice(0, 5)
	var artifact_id = ""
	var uesugi_id = ""
	for raw_card_id in top_five_before:
		var card_id = str(raw_card_id)
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		if instance.definition_id == "asgard_s01_0317":
			artifact_id = card_id
		elif instance.definition_id == "takamagahara_s01_0403":
			uesugi_id = card_id
	_expect(artifact_id != "" and uesugi_id != "", "wuyun test top five should contain an artifact and 上杉谦信", failures)
	if artifact_id == "" or uesugi_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "wuyun_search_and_prepare_uesugi"
	})).ok, "武运在天 铠甲在前 should play successfully as a tactic", failures)
	_resolve_top_stack(engine, state, failures, "wuyun should resolve to the top-five selection choice")
	var reveal_payload := _last_event_payload(state, "CardsRevealedToOpponent")
	_expect(int(reveal_payload.get("revealing_player_id", -1)) == 0, "wuyun should reveal the controller top five cards to the opponent", failures)
	_expect(_same_string_arrays(_string_array_from_variant_array(reveal_payload.get("card_ids", [])), _string_array_from_variant_array(top_five_before)), "wuyun should reveal exactly the looked top five cards", failures)
	_expect(_resolve_candidate_choice(engine, state, "search_top_for_artifact_and_named_legion", [artifact_id, uesugi_id]), "武运在天 铠甲在前 should choose one artifact and one 上杉谦信 from the top five cards", failures)
	var reorder_choice = _pending_choice_by_operation(state, "search_deck_reorder_bottom")
	_expect(reorder_choice != null, "武运在天 铠甲在前 should request a reorder choice for the remaining cards", failures)
	if reorder_choice != null:
		_expect(_resolve_candidate_choice(engine, state, "search_deck_reorder_bottom", reorder_choice.get("candidate_card_ids", []).duplicate()), "武运在天 铠甲在前 reorder choice should resolve", failures)
	_drain_stack_and_choices(engine, state, failures, "武运在天 铠甲在前 follow-up effects should finish resolving")
	_expect(_find_hand_card_by_definition(state, 0, "asgard_s01_0317") != "", "武运在天 铠甲在前 should add an artifact from the revealed cards to hand", failures)
	var tutored_uesugi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0403")
	_expect(tutored_uesugi_id != "", "武运在天 铠甲在前 should add 上杉谦信 from the revealed cards to hand", failures)
	if tutored_uesugi_id == "":
		return
	_expect(MoraleActions.count_spent_morale(state, 0) == 1, "武运在天 铠甲在前 should only spend its own 1 cost before the discounted 上杉谦信 is played", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tutored_uesugi_id,
		"row": "front",
		"col": 0
	})).ok, "武运在天 铠甲在前 should reduce the next 上杉谦信 cost by 2 this turn", failures)
	var uesugi_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(uesugi_instance_id == tutored_uesugi_id, "discounted 上杉谦信 should enter the battlefield", failures)
	_drain_stack_and_choices(engine, state, failures, "discounted 上杉谦信 entry effects should finish before the charge attack")
	var enemy_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": uesugi_instance_id,
		"defender_id": enemy_instance_id
	})).ok, "武运在天 铠甲在前 should let the discounted 上杉谦信 gain charge and attack immediately", failures)

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

static func _resolve_pending_attack(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, first_message, failures)
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, second_message, failures)

static func _drain_stack_and_choices(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(12):
		if state.pending_choices.is_empty() and state.stack.is_empty() and state.pending_attack.is_empty():
			return
		if not state.pending_choices.is_empty():
			var choice = state.pending_choices[0]
			var operation = str(choice.get("operation", ""))
			if operation == "optional_stack_effect" or operation == "pre_stack_optional_attack_trigger":
				_expect(_resolve_option_choice(engine, state, operation, "yes"), message, failures)
				continue
			if operation == "search_deck_reorder_bottom":
				_expect(_resolve_candidate_choice(engine, state, operation, choice.get("candidate_card_ids", []).duplicate()), message, failures)
				continue
			failures.append(message)
			return
		_resolve_top_stack(engine, state, failures, message)
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

static func _last_event_payload(state, event_type: String) -> Dictionary:
	for index in range(state.event_log.size() - 1, -1, -1):
		var event = state.event_log[index]
		if str(event.type) == event_type:
			return event.payload.duplicate(true)
	return {}

static func _string_array_from_variant_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

static func _same_string_arrays(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if left[index] != right[index]:
			return false
	return true

static func _targets_include_pending_attack(targets: Array) -> bool:
	for target in targets:
		if target is Dictionary and str(target.get("target_stack_id", "")) == "__pending_attack__":
			return true
	return false

static func _find_activate_effect_action(actions: Array, source_id: String, effect_id: String) -> Dictionary:
	for action in actions:
		if not (action is Dictionary):
			continue
		if str(action.get("kind", "")) != "activate_effect":
			continue
		var payload = action.get("payload_template", {})
		if not (payload is Dictionary):
			continue
		if str(payload.get("source_id", "")) == source_id and str(payload.get("effect_id", "")) == effect_id:
			return action.duplicate(true)
	return {}

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _find_second_hand_card_by_definition(state, player_id: int, definition_id: String, excluded_card_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		if str(card_id) == excluded_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return str(card_id)
	return ""

static func _find_hand_counter_tactic_ids(state, player_id: int) -> Array[String]:
	var result: Array[String] = []
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition != null and definition.is_counter_tactic():
			result.append(str(card_id))
	return result

static func _find_hand_cards_by_definition(state, player_id: int, definition_id: String, count: int) -> Array[String]:
	var result: Array[String] = []
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			result.append(str(card_id))
			if result.size() >= count:
				break
	return result

static func _add_card_to_grave(state, player_id: int, definition_id: String) -> String:
	var card_id = state.create_instance(definition_id, player_id, player_id)
	state.get_player(player_id).grave.add_card(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "grave"
		instance.position = {}
		instance.orientation = "active"
		instance.face = "face_up"
		instance.controller = player_id
	return card_id

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
