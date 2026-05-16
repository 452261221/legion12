extends RefCounted
class_name TestMasterBatch1

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameEvent = preload("res://rules/core/game_event.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_amaterasu_effects(failures)
	_test_valkyrie_first_turn_draw_replacement_prompt(failures)
	_test_valkyrie_draw_replacement_and_grave_split(failures)
	_test_thor_opening_hammer_charge_and_no_heal(failures)
	_test_thor_opening_hammer_can_be_suppressed_by_opening_choice(failures)
	_test_tsukuyomi_move_chain(failures)
	_test_tsukuyomi_can_move_enemy_legion(failures)
	_test_tsukuyomi_inline_drag_move_choice(failures)
	return failures

static func _test_amaterasu_effects(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["qa_taka_legion_a", "qa_taka_legion_b", "qa_blank", "qa_blank"],
		["qa_enemy_zero", "qa_enemy_one", "qa_blank", "qa_blank"]
	], 5101, [
		{"name": "P1", "master_name": "天照大神", "master_id": "takamagahara_s01_04m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(2, 3))
	var ally_front = _find_hand_card_by_definition(state, 0, "qa_taka_legion_a")
	var ally_discard = _find_hand_card_by_definition(state, 0, "qa_taka_legion_b")
	var enemy_zero = _find_hand_card_by_definition(state, 1, "qa_enemy_zero")
	var enemy_one = _find_hand_card_by_definition(state, 1, "qa_enemy_one")
	_expect(ally_front != "" and ally_discard != "" and enemy_zero != "" and enemy_one != "", "amaterasu test should draw setup cards", failures)
	if ally_front == "" or ally_discard == "" or enemy_zero == "" or enemy_one == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_front, "front", 0, "test_amaterasu_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_one, "front", 0, "test_amaterasu_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_zero, "front", 1, "test_amaterasu_setup")
	MoraleActions.consume_morale(state, 0, 2, "test_amaterasu_setup")
	var amaterasu_first = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "amaterasu_weaken_then_destroy_zero",
		"target_card_id": enemy_one
	}))
	_expect(amaterasu_first.ok, "天照大神 first effect should activate (%s %s)" % [str(amaterasu_first.get("code", "")), str(amaterasu_first.get("message", amaterasu_first.get("errors", [])))], failures)
	_pass_stack_pair(engine, state, failures, "天照大神 first effect should resolve to destroy choice")
	_expect(_resolve_card_choice(engine, state, "destroy_battlefield_card", [enemy_zero]), "天照大神 first effect should destroy a zero-cost enemy (choices=%s)" % [str(_pending_operations(state))], failures)
	var enemy_one_instance = state.card_instances.get(enemy_one)
	_expect(enemy_one_instance != null and int(enemy_one_instance.flags.get("cost_modifier_until_turn_end", 0)) == -1, "天照大神 first effect should reduce the chosen enemy cost by 1", failures)
	_expect(state.get_player(1).grave.cards.has(enemy_zero), "天照大神 first effect should move the zero-cost target to grave (zone=%s grave=%s)" % [str(state.card_instances.get(enemy_zero).zone if state.card_instances.get(enemy_zero) != null else ""), str(state.get_player(1).grave.cards)], failures)
	var amaterasu_second = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "amaterasu_ready_morale_and_buff"
	}))
	_expect(amaterasu_second.ok, "天照大神 second effect should activate (%s %s)" % [str(amaterasu_second.get("code", "")), str(amaterasu_second.get("message", amaterasu_second.get("errors", [])))], failures)
	_pass_stack_pair(engine, state, failures, "天照大神 second effect should resolve")
	_expect(MoraleActions.count_active_morale(state, 0) == 2, "天照大神 second effect should ready up to two spent morale (active=%s spent=%s)" % [MoraleActions.count_active_morale(state, 0), state.get_player(0).spent_cost_area.cards.size()], failures)
	_expect(state.get_player(0).grave.cards.has(ally_discard), "天照大神 second effect should discard one hand card", failures)
	_expect(engine.get_card_power(state, ally_front) == 3000, "天照大神 second effect should buff allied front-row takamagahara by 1000 (power=%s)" % engine.get_card_power(state, ally_front), failures)

static func _test_valkyrie_draw_replacement_and_grave_split(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["qa_asgard_legion_a", "qa_asgard_legion_b", "qa_asgard_legion_c", "qa_blank", "qa_blank", "qa_blank"],
		["qa_enemy_plain", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
	], 5102, [
		{"name": "P1", "master_name": "瓦尔基里", "master_id": "asgard_s01_03m1", "master_hp": 14, "master_max_hp": 14},
		{"name": "P2", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	], _formal_options(2, 3))
	var hand_before = state.get_player(0).hand.cards.size()
	_expect(_resolve_option_choice(engine, state, "valkyrie_first_turn_draw_replacement", "yes"), "瓦尔基里 first-turn prompt should allow choosing to mill 2 instead of skipping the first draw", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "瓦尔基里 first-turn prompt should not draw cards", failures)
	var deck_before = state.get_player(0).deck.cards.size()
	_advance_to_next_main(engine, state, failures, "valkyrie test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "valkyrie test should return to player 1 main after draw replacement")
	_expect(state.get_player(0).hand.cards.size() == hand_before, "瓦尔基里 should replace the draw step instead of drawing cards", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 2, "瓦尔基里 should mill two cards during the draw phase", failures)
	_expect(state.get_player(0).grave.cards.size() >= 2, "瓦尔基里 draw replacement should put two cards into grave", failures)
	var grave_pair: Array[String] = []
	for card_id in state.get_player(0).grave.cards:
		grave_pair.append(str(card_id))
		if grave_pair.size() == 2:
			break
	var hp_before = state.get_player(0).master_hp
	var hand_before_effect = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "valkyrie_grave_split"
	})).ok, "瓦尔基里 active effect should activate", failures)
	_pass_stack_pair(engine, state, failures, "瓦尔基里 active effect should resolve to a grave pair choice")
	_expect(_resolve_card_choice(engine, state, "split_grave_pick_two", grave_pair), "瓦尔基里 should choose two grave cards", failures)
	_expect(_resolve_card_choice(engine, state, "split_grave_choose_hand", [grave_pair[0]]), "瓦尔基里 should choose one of the pair to return to hand", failures)
	_expect(state.get_player(0).master_hp == hp_before - 1, "瓦尔基里 active effect should deal 1 damage to its controller master", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_effect + 1, "瓦尔基里 active effect should return one chosen grave card to hand", failures)
	_expect(not state.get_player(0).grave.cards.has(grave_pair[0]) and not state.get_player(0).grave.cards.has(grave_pair[1]), "瓦尔基里 active effect should remove the chosen pair from grave", failures)

static func _test_valkyrie_first_turn_draw_replacement_prompt(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var yes_state = engine.create_game(_definitions(), [
		["qa_asgard_legion_a", "qa_asgard_legion_b", "qa_blank", "qa_blank"],
		["qa_enemy_plain", "qa_blank", "qa_blank", "qa_blank"]
	], 51021, [
		{"name": "P1", "master_name": "瓦尔基里", "master_id": "asgard_s01_03m1", "master_hp": 14, "master_max_hp": 14},
		{"name": "P2", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	], _formal_options(2, 3))
	var yes_deck_before = yes_state.get_player(0).deck.cards.size()
	_expect(_resolve_option_choice(engine, yes_state, "valkyrie_first_turn_draw_replacement", "yes"), "瓦尔基里 should prompt on the starting player's first turn", failures)
	_expect(yes_state.get_player(0).deck.cards.size() == yes_deck_before - 2, "瓦尔基里 choosing yes on turn 1 should mill 2 immediately", failures)
	_expect(yes_state.get_player(0).hand.cards.size() == 2, "瓦尔基里 first-turn replacement should not change opening hand size", failures)
	var no_state = engine.create_game(_definitions(), [
		["qa_asgard_legion_a", "qa_asgard_legion_b", "qa_blank", "qa_blank"],
		["qa_enemy_plain", "qa_blank", "qa_blank", "qa_blank"]
	], 51022, [
		{"name": "P1", "master_name": "瓦尔基里", "master_id": "asgard_s01_03m1", "master_hp": 14, "master_max_hp": 14},
		{"name": "P2", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9}
	], _formal_options(2, 3))
	var no_deck_before = no_state.get_player(0).deck.cards.size()
	var no_hand_before = no_state.get_player(0).hand.cards.size()
	_expect(_resolve_option_choice(engine, no_state, "valkyrie_first_turn_draw_replacement", "no"), "瓦尔基里 first-turn prompt should allow skipping the replacement", failures)
	_expect(no_state.get_player(0).deck.cards.size() == no_deck_before, "瓦尔基里 choosing no on turn 1 should keep the deck unchanged", failures)
	_expect(no_state.get_player(0).hand.cards.size() == no_hand_before, "瓦尔基里 choosing no on turn 1 should behave like the normal first-player opening", failures)

static func _test_thor_opening_hammer_charge_and_no_heal(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s02_0301", "qa_asgard_legion_a", "qa_blank", "qa_blank"],
		["qa_enemy_plain", "qa_blank", "qa_blank", "qa_blank"]
	], 5103, [
		{"name": "P1", "master_name": "雷神索尔", "master_id": "asgard_s02_03m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_name": "月读", "master_id": "takamagahara_s02_04m1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 4))
	var hammer_id = _find_hand_card_by_definition(state, 0, "asgard_s02_0301")
	_expect(hammer_id != "", "雷神索尔 should add 雷神之锤 to the opening hand when the deck contains it", failures)
	var asgard_legion = _find_hand_card_by_definition(state, 0, "qa_asgard_legion_a")
	var enemy_legion = _find_hand_card_by_definition(state, 1, "qa_enemy_plain")
	_expect(asgard_legion != "" and enemy_legion != "", "thor test should draw both an allied and enemy legion", failures)
	if asgard_legion == "" or enemy_legion == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_legion, "front", 0, "test_thor_setup")
	state.card_instances[enemy_legion].entered_turn = -1
	var thor_set_hp = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 3
	}))
	_expect(thor_set_hp.ok, "thor test should lower master hp to enable activation (%s %s)" % [str(thor_set_hp.get("code", "")), str(thor_set_hp.get("message", thor_set_hp.get("errors", [])))], failures)
	var thor_activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "thor_charge_all_played_legions"
	}))
	_expect(thor_activate.ok, "雷神索尔 active effect should activate at 3 hp (%s %s)" % [str(thor_activate.get("code", "")), str(thor_activate.get("message", thor_activate.get("errors", [])))], failures)
	_pass_stack_pair(engine, state, failures, "雷神索尔 active effect should resolve")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": asgard_legion,
		"row": "front",
		"col": 0
	})).ok, "雷神索尔 test should play an asgard legion after granting charge", failures)
	_drain_stack_and_choices(engine, state, failures, "雷神索尔 played legion should resolve cleanly")
	var attack_targets = engine.get_legal_attack_targets(state, asgard_legion)
	_expect(not attack_targets.is_empty(), "雷神索尔 should grant charge to asgard legions that enter this turn", failures)
	var hp_before_heal = state.get_player(0).master_hp
	_append_effect_resolved_event(state, 0, asgard_legion, "test_thor_heal_block")
	var heal_events = engine._heal_master(state, 0, 1, "test_thor_heal_block")
	_expect(heal_events.is_empty(), "雷神索尔 should block all future master healing after activation", failures)
	_expect(state.get_player(0).master_hp == hp_before_heal, "雷神索尔 should keep master hp unchanged when healing is blocked", failures)

static func _test_thor_opening_hammer_can_be_suppressed_by_opening_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var options := _formal_options(2, 4)
	options["opening_setup_choices"] = [
		{"thor_add_hammer_to_hand": false},
		{}
	]
	var state = engine.create_game(_definitions(), [
		["qa_asgard_legion_a", "qa_blank", "asgard_s02_0301", "qa_blank"],
		["qa_enemy_plain", "qa_blank", "qa_blank", "qa_blank"]
	], 51031, [
		{"name": "P1", "master_name": "雷神索尔", "master_id": "asgard_s02_03m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_name": "月读", "master_id": "takamagahara_s02_04m1", "master_hp": 8, "master_max_hp": 8}
	], options)
	_expect(_find_hand_card_by_definition(state, 0, "asgard_s02_0301") == "", "雷神索尔 explicit normal opening should not auto-add 雷神之锤", failures)
	_expect(state.get_player(0).hand.cards.size() == 2, "雷神索尔 explicit normal opening should keep the default opening hand size", failures)

static func _test_tsukuyomi_move_chain(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["qa_taka_legion_a", "qa_taka_legion_b", "qa_blank", "qa_blank"],
		["qa_enemy_plain", "qa_blank", "qa_blank", "qa_blank"]
	], 5104, [
		{"name": "P1", "master_name": "月读", "master_id": "takamagahara_s02_04m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(2, 3))
	var mover_a = _find_hand_card_by_definition(state, 0, "qa_taka_legion_a")
	var mover_b = _find_hand_card_by_definition(state, 0, "qa_taka_legion_b")
	_expect(mover_a != "" and mover_b != "", "tsukuyomi test should draw two takamagahara legions", failures)
	if mover_a == "" or mover_b == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, mover_a, "back", 0, "test_tsukuyomi_setup")
	engine._deploy_hand_card_to_slot(state, 0, mover_b, "front", 1, "test_tsukuyomi_setup")
	state.card_instances[mover_a].entered_turn = -1
	state.card_instances[mover_b].entered_turn = -1
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_a,
		"row": "front",
		"col": 0
	})).ok, "月读 should allow moving the first legion manually", failures)
	_expect(engine.get_card_power(state, mover_a) == 3000, "月读 should give +1000 after moving a takamagahara legion from back to front", failures)
	_expect(_resolve_option_choice(engine, state, "tsukuyomi_move_trigger", "yes"), "月读 should offer and resolve its once-per-turn follow-up move prompt", failures)
	_expect(_resolve_card_choice(engine, state, "tsukuyomi_choose_move_card", [mover_b]), "月读 should choose another legion to move", failures)
	_expect(_resolve_option_choice(engine, state, "tsukuyomi_choose_move_slot", "back:1"), "月读 should move the second legion to the chosen slot", failures)
	var moved_b = state.card_instances.get(mover_b)
	_expect(moved_b != null and str(moved_b.position.get("row", "")) == "back" and int(moved_b.position.get("col", -1)) == 1, "月读 should move the chosen second legion by 1 slot", failures)
	_expect(moved_b != null and int(moved_b.flags.get("cost_modifier_until_turn_end", 0)) == -1, "月读 should reduce the moved legion cost by 1 for the turn", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == 2, "月读 front-to-back bonus should ready one morale after the follow-up move", failures)


static func _test_tsukuyomi_can_move_enemy_legion(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["qa_taka_legion_a", "qa_blank", "qa_blank", "qa_blank"],
		["qa_enemy_plain", "qa_blank", "qa_blank", "qa_blank"]
	], 5105, [
		{"name": "P1", "master_name": "月读", "master_id": "takamagahara_s02_04m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(2, 3))
	var mover_a = _find_hand_card_by_definition(state, 0, "qa_taka_legion_a")
	var enemy_legion = _find_hand_card_by_definition(state, 1, "qa_enemy_plain")
	_expect(mover_a != "" and enemy_legion != "", "tsukuyomi enemy-move test should draw both setup legions", failures)
	if mover_a == "" or enemy_legion == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, mover_a, "back", 0, "test_tsukuyomi_enemy_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_legion, "front", 0, "test_tsukuyomi_enemy_setup")
	state.card_instances[mover_a].entered_turn = -1
	state.card_instances[enemy_legion].entered_turn = -1
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_a,
		"row": "front",
		"col": 0
	})).ok, "月读 should allow the initial allied move before moving an enemy legion", failures)
	_expect(_resolve_option_choice(engine, state, "tsukuyomi_move_trigger", "yes"), "月读 should allow confirming the follow-up move prompt", failures)
	_expect(_resolve_card_choice(engine, state, "tsukuyomi_choose_move_card", [enemy_legion]), "月读 should allow selecting an enemy legion for the follow-up move", failures)
	_expect(_resolve_option_choice(engine, state, "tsukuyomi_choose_move_slot", "back:0"), "月读 should allow moving the chosen enemy legion by 1 slot", failures)
	var moved_enemy = state.card_instances.get(enemy_legion)
	_expect(moved_enemy != null and str(moved_enemy.position.get("row", "")) == "back" and int(moved_enemy.position.get("col", -1)) == 0, "月读 should move the chosen enemy legion onto its own back row slot", failures)
	_expect(moved_enemy != null and int(moved_enemy.flags.get("cost_modifier_until_turn_end", 0)) == -1, "月读 should reduce the moved enemy legion cost by 1 for the turn", failures)


static func _test_tsukuyomi_inline_drag_move_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["qa_taka_legion_a", "qa_taka_legion_b", "qa_blank", "qa_blank"],
		["qa_enemy_plain", "qa_blank", "qa_blank", "qa_blank"]
	], 5106, [
		{"name": "P1", "master_name": "月读", "master_id": "takamagahara_s02_04m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P2", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(2, 3))
	var mover_a = _find_hand_card_by_definition(state, 0, "qa_taka_legion_a")
	var mover_b = _find_hand_card_by_definition(state, 0, "qa_taka_legion_b")
	_expect(mover_a != "" and mover_b != "", "tsukuyomi inline drag test should draw two takamagahara legions", failures)
	if mover_a == "" or mover_b == "":
		return
	engine._deploy_hand_card_to_slot(state, 0, mover_a, "back", 0, "test_tsukuyomi_inline_setup")
	engine._deploy_hand_card_to_slot(state, 0, mover_b, "front", 1, "test_tsukuyomi_inline_setup")
	state.card_instances[mover_a].entered_turn = -1
	state.card_instances[mover_b].entered_turn = -1
	_expect(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": mover_a,
		"row": "front",
		"col": 0
	})).ok, "月读 inline drag test should allow the initial allied move", failures)
	_expect(_resolve_option_choice(engine, state, "tsukuyomi_move_trigger", "yes"), "月读 inline drag test should confirm the follow-up move prompt", failures)
	_expect(_resolve_card_choice_drag(engine, state, "tsukuyomi_choose_move_card", [mover_b], "back", 1), "月读 inline drag test should support resolving card choice with direct slot payload", failures)
	var moved_b = state.card_instances.get(mover_b)
	_expect(moved_b != null and str(moved_b.position.get("row", "")) == "back" and int(moved_b.position.get("col", -1)) == 1, "月读 inline drag test should move the dragged legion directly to the chosen slot", failures)
	_expect(moved_b != null and int(moved_b.flags.get("cost_modifier_until_turn_end", 0)) == -1, "月读 inline drag test should still apply the cost reduction", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == 2, "月读 inline drag test should still ready one morale after front-to-back movement", failures)

static func _definitions() -> Array:
	var definitions = CardDatabase.load_definitions()
	if not _definitions_include_id(definitions, "asgard_s02_0301"):
		definitions.append_array([
		{
			"id": "qa_blank",
			"name": "测试空白卡",
			"faction": "neutral",
			"type": "tactic",
			"cost": 1,
			"power": 0,
			"hp": 0,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试用空白卡。"
		},
		{
			"id": "qa_taka_legion_a",
			"name": "测试高天原A",
			"faction": "takamagahara",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试高天原军团A。"
		},
		{
			"id": "qa_taka_legion_b",
			"name": "测试高天原B",
			"faction": "takamagahara",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试高天原军团B。"
		},
		{
			"id": "qa_asgard_legion_a",
			"name": "测试阿斯加德A",
			"faction": "asgard",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试阿斯加德军团A。"
		},
		{
			"id": "qa_asgard_legion_b",
			"name": "测试阿斯加德B",
			"faction": "asgard",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试阿斯加德军团B。"
		},
		{
			"id": "qa_asgard_legion_c",
			"name": "测试阿斯加德C",
			"faction": "asgard",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试阿斯加德军团C。"
		},
		{
			"id": "qa_enemy_zero",
			"name": "测试0费敌军",
			"faction": "neutral",
			"type": "legion",
			"cost": 0,
			"power": 1000,
			"hp": 1000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试0费敌军。"
		},
		{
			"id": "qa_enemy_one",
			"name": "测试1费敌军",
			"faction": "neutral",
			"type": "legion",
			"cost": 1,
			"power": 1000,
			"hp": 1000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试1费敌军。"
		},
		{
			"id": "qa_enemy_plain",
			"name": "测试敌军",
			"faction": "neutral",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试敌军。"
		},
		{
			"id": "asgard_s02_0301",
			"name": "雷神之锤",
			"faction": "asgard",
			"type": "legion",
			"cost": 1,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试用雷神之锤定义，用于验证雷神索尔起手加入手牌。"
		}
		])
	else:
		definitions.append_array([
		{
			"id": "qa_blank",
			"name": "测试空白卡",
			"faction": "neutral",
			"type": "tactic",
			"cost": 1,
			"power": 0,
			"hp": 0,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试空白卡。"
		},
		{
			"id": "qa_taka_legion_a",
			"name": "测试高天原前排",
			"faction": "takamagahara",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试高天原军团。"
		},
		{
			"id": "qa_taka_legion_b",
			"name": "测试高天原后排",
			"faction": "takamagahara",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试高天原军团。"
		},
		{
			"id": "qa_asgard_legion_a",
			"name": "测试阿斯加德军团",
			"faction": "asgard",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试阿斯加德军团。"
		},
		{
			"id": "qa_asgard_legion_b",
			"name": "测试阿斯加德军团B",
			"faction": "asgard",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试阿斯加德军团B。"
		},
		{
			"id": "qa_asgard_legion_c",
			"name": "测试阿斯加德军团C",
			"faction": "asgard",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试阿斯加德军团C。"
		},
		{
			"id": "qa_enemy_zero",
			"name": "测试0费敌军",
			"faction": "neutral",
			"type": "legion",
			"cost": 0,
			"power": 1000,
			"hp": 1000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试0费敌军。"
		},
		{
			"id": "qa_enemy_one",
			"name": "测试1费敌军",
			"faction": "neutral",
			"type": "legion",
			"cost": 1,
			"power": 1000,
			"hp": 1000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试1费敌军。"
		},
		{
			"id": "qa_enemy_plain",
			"name": "测试敌军",
			"faction": "neutral",
			"type": "legion",
			"cost": 2,
			"power": 2000,
			"hp": 2000,
			"status": "implemented",
			"keywords": [],
			"effects": [],
			"text": "测试敌军。"
		}
		])
	return definitions

static func _definitions_include_id(definitions: Array, definition_id: String) -> bool:
	for row in definitions:
		if row is Dictionary and str(row.get("id", "")) == definition_id:
			return true
	return false

static func _formal_options(opening_hand_size: int, opening_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": 3
	}

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

static func _pass_stack_pair(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)

static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_option": selected_option
		})).ok
	return false

static func _resolve_card_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array[String]) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_card_ids": selected_card_ids
		})).ok
	return false


static func _resolve_card_choice_drag(engine: GameEngine, state, operation: String, selected_card_ids: Array[String], row: String, col: int) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_card_ids": selected_card_ids,
			"row": row,
			"col": col
		})).ok
	return false

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
		if not state.pending_attack.is_empty():
			_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
			continue
		_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
	failures.append(message)

static func _append_effect_resolved_event(state, player_id: int, source_id: String, command_id: String) -> void:
	var event = GameEvent.create(state.next_event_id(), "EffectResolved", player_id, {
		"stack_id": "",
		"source_id": source_id,
		"effect_id": "test_effect",
		"effect_type": "activated"
	})
	event.created_by_command = command_id
	state.event_log.append(event)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

static func _pending_operations(state) -> Array[String]:
	var operations: Array[String] = []
	for choice in state.pending_choices:
		operations.append(str(choice.get("operation", "")))
	return operations
