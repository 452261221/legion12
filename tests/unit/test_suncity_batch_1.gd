extends RefCounted
class_name TestSuncityBatch1

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")
const TEST_FILLER_CARD_ID := "asgard_s01_0301"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_suncity_definitions_and_masters_load(failures)
	_test_canopic_box_search_heal_and_self_send(failures)
	_test_canopic_one_grants_power_and_strong_attack(failures)
	_test_canopic_two_grants_next_tactic_free(failures)
	_test_canopic_three_adds_temporary_morale(failures)
	_test_canopic_four_grants_protection_and_self_discards(failures)
	_test_cleopatra_rest_revives_tomb_guard(failures)
	_test_tomb_construct_attaches_and_releases_tomb_guards(failures)
	_test_tutankhamun_entry_and_death_recycle(failures)
	_test_tutankhamun_entry_requires_fewer_legions(failures)
	_test_menes_attack_buff_and_opponent_turn_bonus(failures)
	_test_medjed_master_effects(failures)
	_test_suncity_morale_effects(failures)
	_test_horemheb_entry_grants_charge(failures)
	_test_horemheb_substitutes_tomb_guard_on_lethal(failures)
	_test_hatshepsut_entry_and_death(failures)
	_test_tomb_paladin_cost_and_death_revive(failures)
	_test_golden_scarab_entry_rest_and_weaken(failures)
	_test_saladin_taunt_and_adjacent_attack_buff(failures)
	_test_saladin_move_and_triggered_reposition(failures)
	_test_siwa_hand_response_and_ready_lock(failures)
	_test_ai_entry_and_attack_buff(failures)
	_test_ramesses_cost_and_replay_entries(failures)
	_test_codex_volume_one_counters_or_rewards(failures)
	_test_osiris_replace_and_tomb_guard_buff(failures)
	_test_nefertiti_entry_and_death(failures)
	_test_nefertiti_conditions_gate_effects(failures)
	_test_nitocris_entry_and_death(failures)
	_test_ankh_entry_and_options(failures)
	_test_duat_gate_modes(failures)
	_test_duat_gate_without_valid_targets(failures)
	_test_pharaoh_celebration_pick_and_reorder(failures)
	_test_pharaoh_celebration_without_targets_only_reorders(failures)
	_test_immortal_gift_triggers_on_attack_and_effect(failures)
	_test_immortal_gift_ignores_low_cost_legion(failures)
	_test_ptolemy_repeats_last_active_tactic(failures)
	_test_ptolemy_requires_last_active_tactic(failures)
	_test_imhotep_entry_and_discount(failures)
	_test_desert_sovereignty_deploys_matching_calamity(failures)
	_test_fearless_assassination_buffs_and_discards_at_turn_end(failures)
	_test_thutmose_entry_and_crush(failures)
	_test_suncity_cost_rules_use_correct_definition_ids(failures)
	return failures


static func _test_suncity_definitions_and_masters_load(failures: Array[String]) -> void:
	var definitions = _definitions_with_suncity_masters()
	_expect(_find_definition(definitions, "suncity_s01_0219") != null, "太阳城：未加载卡诺匹斯罐 三定义", failures)
	_expect(_find_definition(definitions, "suncity_s02_0203") != null, "太阳城：未加载哈特谢普苏特定义", failures)
	_expect(_find_definition(definitions, "suncity_s02_0202") != null, "太阳城：未加载陵墓圣武士定义", failures)
	_expect(_find_definition(definitions, "suncity_s01_0223") != null, "太阳城：未加载不朽之礼定义", failures)
	_expect(_find_definition(definitions, "suncity_s01_0224") != null, "太阳城：未加载智慧法典 卷一定义", failures)
	_expect(_find_definition(definitions, "suncity_s01_0213") != null, "太阳城：未加载锡瓦的卡巴定义", failures)
	_expect(_find_definition(definitions, "suncity_s01_0204") != null, "太阳城：未加载陵墓构造体定义", failures)
	var isis = _find_definition(definitions, "suncity_s01_02m1")
	var medjed = _find_definition(definitions, "suncity_s01_02m3a")
	var nephthys = _find_definition(definitions, "suncity_s02_02m1")
	_expect(isis != null and int(isis.get("hp", 0)) == 8, "太阳城：伊西斯主宰原始数据缺失或血量错误", failures)
	_expect(medjed != null and int(medjed.get("hp", 0)) == 8, "太阳城：梅杰德主宰原始数据缺失或血量错误", failures)
	_expect(nephthys != null and int(nephthys.get("hp", 0)) == 7, "太阳城：奈芙蒂斯主宰原始数据缺失或血量错误", failures)


static func _test_canopic_three_adds_temporary_morale(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0219"],
		[]
	], 7201, _formal_options(1, 6, 6))
	var canopic_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0219")
	_expect(not canopic_id.is_empty(), "太阳城：测试初始化失败（未抽到卡诺匹斯罐 三）", failures)
	if canopic_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：卡诺匹斯罐 三打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).flags.get("temporary_morale_turn", -1)) == int(state.turn_number), "太阳城：卡诺匹斯罐 三未写入临时士气回合标记", failures)
	_expect(int(state.get_player(0).flags.get("temporary_morale_count", 0)) == 2, "太阳城：卡诺匹斯罐 三应提供 2 点临时士气", failures)
	_expect(MoraleActions.count_active_morale(state, 0) == 8, "太阳城：临时士气未计入可用士气", failures)
	_expect(state.get_player(0).grave.cards.has(canopic_id), "太阳城：卡诺匹斯罐 三结算后应进入墓地", failures)
	_expect(not state.get_player(0).artifact_zone.cards.has(canopic_id), "太阳城：卡诺匹斯罐 三结算后不应停留在圣物区", failures)
	engine._begin_turn_for_player(state, 1)
	_expect(not state.get_player(0).flags.has("temporary_morale_turn"), "太阳城：临时士气回合开始时应清理回合标记", failures)
	_expect(not state.get_player(0).flags.has("temporary_morale_count"), "太阳城：临时士气回合开始时应清理数量标记", failures)


static func _test_canopic_box_search_heal_and_self_send(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0216", "suncity_s01_0217", TEST_FILLER_CARD_ID],
		[]
	], 7202, _formal_options(1, 6, 6))
	var canopic_box_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0216")
	var canopic_one_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0217")
	_expect(not canopic_box_id.is_empty() and canopic_one_id.is_empty(), "太阳城：卡诺匹斯箱测试初始化失败", failures)
	if canopic_box_id.is_empty():
		return
	state.get_player(0).master_hp = max(0, state.get_player(0).master_hp - 1)
	var master_hp_before = state.get_player(0).master_hp
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_box_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：卡诺匹斯箱打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var searched_canopic_one_id = ""
	for card_id in state.get_player(0).hand.cards:
		if str(card_id) == canopic_box_id:
			continue
		var hand_instance = state.card_instances.get(str(card_id))
		if hand_instance != null and str(hand_instance.definition_id) == "suncity_s01_0217":
			searched_canopic_one_id = str(card_id)
			break
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != "search_deck":
			continue
		for card_id in choice.get("candidate_card_ids", []):
			var instance = state.card_instances.get(str(card_id))
			if instance != null and str(instance.definition_id) == "suncity_s01_0217":
				searched_canopic_one_id = str(card_id)
				break
		if not searched_canopic_one_id.is_empty():
			break
	_expect(not searched_canopic_one_id.is_empty(), "太阳城：卡诺匹斯箱未能在牌库中找到卡诺匹斯罐目标", failures)
	if searched_canopic_one_id.is_empty():
		return
	if _has_pending_choice(state, "search_deck"):
		_expect(_resolve_first_candidate_choice(engine, state, "search_deck", [searched_canopic_one_id]), "太阳城：卡诺匹斯箱未能完成检索选择", failures)
	_expect(state.get_player(0).hand.cards.has(searched_canopic_one_id), "太阳城：卡诺匹斯箱应将选中的卡诺匹斯罐加入手牌", failures)
	_expect(state.get_player(0).master_hp == master_hp_before + 1, "太阳城：卡诺匹斯箱结算后应令我方主宰回复1点血量", failures)
	_expect(state.get_player(0).grave.cards.has(canopic_box_id), "太阳城：卡诺匹斯箱结算后应将自身送入墓地", failures)
	_expect(not state.get_player(0).artifact_zone.cards.has(canopic_box_id), "太阳城：卡诺匹斯箱结算后不应继续留在圣物区", failures)


static func _test_canopic_one_grants_power_and_strong_attack(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0217", "suncity_s01_0212"],
		[]
	], 7203, _formal_options(2, 6, 6))
	var canopic_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0217")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not canopic_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：卡诺匹斯罐 一测试初始化失败", failures)
	if canopic_id.is_empty() or tomb_guard_id.is_empty():
		return
	engine._revive_grave_card_to_first_slot(state, 0, tomb_guard_id, "test_suncity_canopic_one_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：卡诺匹斯罐 一打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_canopic_one_buff", [tomb_guard_id]), "太阳城：未能为卡诺匹斯罐 一选择目标", failures)
	_expect(engine.get_card_power(state, tomb_guard_id) == 4000, "太阳城：卡诺匹斯罐 一应给予目标 +2000 兵力", failures)
	var target_instance = state.card_instances.get(tomb_guard_id)
	_expect(target_instance != null and int(target_instance.flags.get("temporary_keyword_strong_attack_turn", -1)) == int(state.turn_number), "太阳城：卡诺匹斯罐 一未给予强攻", failures)
	_expect(state.get_player(0).grave.cards.has(canopic_id), "太阳城：卡诺匹斯罐 一结算后应进入墓地", failures)


static func _test_canopic_two_grants_next_tactic_free(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0218", "suncity_s02_0206", "suncity_s02_0203", TEST_FILLER_CARD_ID],
		["suncity_s02_0203"]
	], 72031, _formal_options(3, 6, 6))
	var canopic_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0218")
	var tactic_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0206")
	var ally_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	var enemy_id = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	_expect(not canopic_id.is_empty() and not tactic_id.is_empty() and not ally_id.is_empty() and not enemy_id.is_empty(), "太阳城：卡诺匹斯罐 二测试初始化失败", failures)
	if canopic_id.is_empty() or tactic_id.is_empty() or ally_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_canopic_two_ally_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_canopic_two_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：卡诺匹斯罐 二打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).flags.get("tianting_next_tactic_free", {}).get("turn", -1)) == int(state.turn_number), "太阳城：卡诺匹斯罐 二应给出本回合下张战术免费标记", failures)
	_expect(state.get_player(0).grave.cards.has(canopic_id), "太阳城：卡诺匹斯罐 二结算后应进入墓地", failures)
	var cost_before = engine._get_effective_play_cost(state, tactic_id)
	_expect(cost_before == 0, "太阳城：卡诺匹斯罐 二生效后下张战术费用应变为0", failures)
	var tactic_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"target_card_id": ally_id
	}))
	_expect(bool(tactic_play.get("ok", false)), "太阳城：卡诺匹斯罐 二给予免费后战术打出失败", failures)
	if not bool(tactic_play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(engine.get_card_power(state, ally_id) == 6000, "太阳城：无畏的刺杀在卡诺匹斯罐 二加持下仍应正常给予目标+3000", failures)
	_expect(not state.get_player(0).flags.has("tianting_next_tactic_free"), "太阳城：卡诺匹斯罐 二的免费战术标记在使用后应被清除", failures)


static func _test_canopic_four_grants_protection_and_self_discards(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0220", "suncity_s02_0203", "suncity_s01_0212"],
		[]
	], 7204, _formal_options(3, 6, 6))
	var canopic_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0220")
	var hatshepsut_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not canopic_id.is_empty() and not hatshepsut_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：卡诺匹斯罐 四测试初始化失败", failures)
	if canopic_id.is_empty() or hatshepsut_id.is_empty() or tomb_guard_id.is_empty():
		return
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hatshepsut_id,
		"row": "front",
		"col": 0
	})).get("ok", false)), "太阳城：未能先部署哈特谢普苏特", failures)
	_pass_stack_pair(engine, state)
	_decline_optional_stack_effect_if_present(engine, state)
	engine._revive_grave_card_to_first_slot(state, 0, tomb_guard_id, "test_suncity_canopic_four_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：卡诺匹斯罐 四打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_canopic_four_protect", [hatshepsut_id, tomb_guard_id]), "太阳城：未能为卡诺匹斯罐 四选择保护目标", failures)
	var hatshepsut_instance = state.card_instances.get(hatshepsut_id)
	var tomb_guard_instance = state.card_instances.get(tomb_guard_id)
	_expect(hatshepsut_instance != null and int(hatshepsut_instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) == 0, "太阳城：卡诺匹斯罐 四未给哈特谢普苏特附加免死", failures)
	_expect(tomb_guard_instance != null and int(tomb_guard_instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) == 0, "太阳城：卡诺匹斯罐 四未给陵墓守卫附加免死", failures)
	_expect(state.get_player(0).grave.cards.has(canopic_id), "太阳城：卡诺匹斯罐 四结算后应进入墓地", failures)


static func _test_tutankhamun_entry_and_death_recycle(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0207", "suncity_s02_0203", "suncity_s01_0212"],
		["suncity_s02_0203", "suncity_s02_0203"]
	], 7205, _formal_options(2, 6, 6))
	var tut_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0207")
	var recycle_setup_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	var enemy_a = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	var enemy_b = _find_other_hand_card_by_definition(state, 1, "suncity_s02_0203", enemy_a)
	var first_tomb_guard = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	var second_tomb_guard = _find_other_grave_card_by_definition(state, 0, "suncity_s01_0212", first_tomb_guard)
	_expect(not tut_id.is_empty() and not recycle_setup_id.is_empty() and not enemy_a.is_empty() and not enemy_b.is_empty() and not first_tomb_guard.is_empty(), "太阳城：图坦卡蒙测试初始化失败", failures)
	if tut_id.is_empty() or recycle_setup_id.is_empty() or enemy_a.is_empty() or enemy_b.is_empty() or first_tomb_guard.is_empty():
		return
	state.get_player(0).hand.remove_card(recycle_setup_id)
	state.get_player(0).grave.add_card_to_top(recycle_setup_id)
	state.card_instances[recycle_setup_id].zone = "grave"
	state.card_instances[recycle_setup_id].position = {}
	engine._deploy_hand_card_to_slot(state, 1, enemy_a, "front", 0, "test_tutankhamun_enemy_a")
	engine._deploy_hand_card_to_slot(state, 1, enemy_b, "front", 1, "test_tutankhamun_enemy_b")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tut_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：图坦卡蒙打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var revive_targets: Array = [first_tomb_guard]
	if not second_tomb_guard.is_empty():
		revive_targets.append(second_tomb_guard)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_tutankhamun_entry", revive_targets), "太阳城：图坦卡蒙未能选择复活陵墓守卫", failures)
	_expect(_count_battlefield_definition(state, 0, "suncity_s01_0212") == revive_targets.size(), "太阳城：图坦卡蒙登场后应按选择数量复活陵墓守卫", failures)
	for slot in state.get_player(0).battle_front:
		var revived_id = str(slot.occupant)
		if revived_id.is_empty():
			continue
		var revived_instance = state.card_instances.get(revived_id)
		if revived_instance != null and str(revived_instance.definition_id) == "suncity_s01_0212":
			_expect(str(revived_instance.orientation) == "active", "太阳城：图坦卡蒙登场复活的陵墓守卫应为活跃状态", failures)
	var recycle_id = _find_grave_card_by_definition(state, 0, "suncity_s02_0203")
	_expect(not recycle_id.is_empty(), "太阳城：图坦卡蒙阵亡回顶测试缺少目标墓地牌", failures)
	if recycle_id.is_empty():
		return
	engine._append_logged_event(state, "CardDied", 0, {
		"card_id": tut_id,
		"source_card_id": enemy_a
	}, "test_tutankhamun_death")
	engine.drain_until_waiting_for_input(state, [state.event_log[state.event_log.size() - 1]], "test_tutankhamun_death")
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_tutankhamun_death", [recycle_id]), "太阳城：图坦卡蒙未能选择回顶目标", failures)
	_expect(not state.get_player(0).grave.cards.has(recycle_id), "太阳城：图坦卡蒙回顶后目标不应留在墓地", failures)
	_expect(state.get_player(0).deck.cards.size() > 0 and str(state.get_player(0).deck.cards[0]) == recycle_id, "太阳城：图坦卡蒙应将目标放回牌库顶部", failures)


static func _test_tutankhamun_entry_requires_fewer_legions(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0207", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		["suncity_s02_0203"]
	], 72072, _formal_options(2, 8, 8))
	var tut_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0207")
	var ally_other_id = _find_hand_card_by_definition(state, 0, TEST_FILLER_CARD_ID)
	var enemy_id = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	_expect(not tut_id.is_empty() and not ally_other_id.is_empty() and not enemy_id.is_empty(), "太阳城：图坦卡蒙条件测试初始化失败", failures)
	if tut_id.is_empty() or ally_other_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_other_id, "front", 1, "test_tutankhamun_gate_ally_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_tutankhamun_gate_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tut_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：图坦卡蒙条件测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(not _has_pending_choice(state, "suncity_tutankhamun_entry"), "太阳城：图坦卡蒙在我方军团数量不少于对方时不应触发复活选择", failures)
	_expect(_count_battlefield_definition(state, 0, "suncity_s01_0212") == 0, "太阳城：图坦卡蒙条件不满足时不应复活陵墓守卫", failures)


static func _test_cleopatra_rest_revives_tomb_guard(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0214", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		[]
	], 72055, _formal_options(2, 6, 6))
	var cleopatra_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0214")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not cleopatra_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：克利奥帕特拉七世测试初始化失败", failures)
	if cleopatra_id.is_empty() or tomb_guard_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": cleopatra_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：克利奥帕特拉七世打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	var spent_morale_before = MoraleActions.count_spent_morale(state, 0)
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": cleopatra_id,
		"effect_id": "cleopatra_rest_revive_tomb_guard"
	}))
	_expect(bool(activate.get("ok", false)), "太阳城：克利奥帕特拉七世主动休整效果发动失败", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "revive_from_grave", [tomb_guard_id]), "太阳城：克利奥帕特拉七世未能选择复活陵墓守卫", failures)
	_expect(_resolve_first_option_choice(engine, state, "revive_selected_grave_to_slot", "front:1"), "太阳城：克利奥帕特拉七世未能为复活目标选择位置", failures)
	var cleopatra_instance = state.card_instances.get(cleopatra_id)
	var tomb_guard_instance = state.card_instances.get(tomb_guard_id)
	_expect(cleopatra_instance != null and str(cleopatra_instance.orientation) == "rested", "太阳城：克利奥帕特拉七世发动主动休整后应转为休整", failures)
	_expect(tomb_guard_instance != null and str(tomb_guard_instance.zone) == "battle_front" and int(tomb_guard_instance.position.get("col", -1)) == 1 and str(tomb_guard_instance.orientation) == "active", "太阳城：克利奥帕特拉七世应将陵墓守卫活跃登场", failures)
	_expect(MoraleActions.count_spent_morale(state, 0) == spent_morale_before + 1, "太阳城：克利奥帕特拉七世发动效果应额外消耗1点士气", failures)


static func _test_tomb_construct_attaches_and_releases_tomb_guards(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0204", "suncity_s01_0212", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		["suncity_s02_0203", TEST_FILLER_CARD_ID]
	], 72057, _formal_options(3, 8, 8))
	var construct_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0204")
	var hand_tomb_guard_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0212")
	var enemy_attacker_id = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	var ally_other_id = _find_hand_card_by_definition(state, 0, TEST_FILLER_CARD_ID)
	_expect(not construct_id.is_empty() and not hand_tomb_guard_id.is_empty() and not enemy_attacker_id.is_empty() and not ally_other_id.is_empty(), "太阳城：陵墓构造体测试初始化失败", failures)
	if construct_id.is_empty() or hand_tomb_guard_id.is_empty() or enemy_attacker_id.is_empty() or ally_other_id.is_empty():
		return
	state.get_player(0).hand.remove_card(hand_tomb_guard_id)
	state.get_player(0).grave.add_card_to_top(hand_tomb_guard_id)
	state.card_instances[hand_tomb_guard_id].zone = "grave"
	state.card_instances[hand_tomb_guard_id].position = {}
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": construct_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：陵墓构造体打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var construct_instance = state.card_instances.get(construct_id)
	var attached = construct_instance.flags.get("suncity_tomb_construct_underlays", []) if construct_instance != null else []
	_expect(construct_instance != null and attached is Array and attached.size() == 2, "太阳城：陵墓构造体登场时应吸收墓地所有陵墓守卫", failures)
	_expect(_find_grave_card_by_definition(state, 0, "suncity_s01_0212").is_empty(), "太阳城：陵墓构造体登场后墓地中不应残留被吸收的陵墓守卫", failures)
	_expect(engine.get_card_power(state, construct_id) == 5000, "太阳城：陵墓构造体每吸收1张陵墓守卫应获得兵力+1000", failures)
	engine._deploy_hand_card_to_slot(state, 0, ally_other_id, "front", 1, "test_tomb_construct_ally_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_attacker_id, "front", 0, "test_tomb_construct_enemy_setup")
	state.card_instances[enemy_attacker_id].entered_turn = -1
	engine._begin_turn_for_player(state, 1)
	var invalid_attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": enemy_attacker_id,
		"target_kind": "card",
		"defender_id": ally_other_id
	}))
	_expect(not bool(invalid_attack.get("ok", false)), "太阳城：陵墓构造体位于前排时应强制敌方优先进攻自身", failures)
	var destroy_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_tomb_construct_death")
	engine.drain_until_waiting_for_input(state, destroy_events, "test_tomb_construct_death")
	_pass_stack_pair(engine, state)
	_expect(_count_battlefield_definition(state, 0, "suncity_s01_0212") == 2, "太阳城：陵墓构造体阵亡时应将下方所有陵墓守卫休整登场", failures)
	for slot in state.get_player(0).battle_front:
		var card_id = str(slot.occupant)
		if card_id.is_empty():
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == "suncity_s01_0212":
			_expect(str(instance.orientation) == "rested", "太阳城：陵墓构造体放出的陵墓守卫应以休整状态登场", failures)
	_expect(_find_battlefield_card_by_definition(state, 0, "suncity_s01_0204") != construct_id, "太阳城：陵墓构造体阵亡后本体不应继续留在战场", failures)


static func _test_menes_attack_buff_and_opponent_turn_bonus(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0203", "suncity_s02_0203"],
		[]
	], 7206, _formal_options(2, 6, 6))
	var menes_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0203")
	var sacrifice_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	_expect(not menes_id.is_empty() and not sacrifice_id.is_empty(), "太阳城：美尼斯测试初始化失败", failures)
	if menes_id.is_empty() or sacrifice_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, menes_id, "front", 0, "test_menes_setup")
	engine._deploy_hand_card_to_slot(state, 0, sacrifice_id, "front", 1, "test_menes_sacrifice_setup")
	state.card_instances[menes_id].entered_turn = -1
	state.card_instances[sacrifice_id].entered_turn = -1
	engine._begin_turn_for_player(state, 1)
	_expect(engine.get_card_power(state, menes_id) == 6000, "太阳城：美尼斯在对方回合且无陵墓守卫时应 +1000", failures)
	engine._begin_turn_for_player(state, 0)
	state.card_instances[menes_id].entered_turn = -1
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": menes_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "太阳城：美尼斯宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_menes_attack_buff", [sacrifice_id]), "太阳城：美尼斯未能选择弃置目标", failures)
	_expect(state.get_player(0).grave.cards.has(sacrifice_id), "太阳城：美尼斯进攻强化应弃置所选我方军团", failures)
	_expect(engine.get_card_power(state, menes_id) == 7000, "太阳城：美尼斯进攻强化后应 +2000", failures)
	var menes_instance = state.card_instances.get(menes_id)
	_expect(menes_instance != null and int(menes_instance.flags.get("temporary_keyword_strong_attack_turn", -1)) == int(state.turn_number), "太阳城：美尼斯进攻强化后应获得强攻", failures)


static func _test_osiris_replace_and_tomb_guard_buff(failures: Array[String]) -> void:
	var duel_engine := GameEngine.new()
	var duel_state = duel_engine.create_game(_definitions_with_suncity_masters(), [
		["suncity_s01_0217", "suncity_s01_0218", "suncity_s01_0219", "suncity_s01_0220", "suncity_s01_0216", TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID]
	], 72060, [
		{"name": "P0", "master_name": "伊西斯", "master_id": "suncity_s01_02m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 8, 8))
	for definition_id in ["suncity_s01_0217", "suncity_s01_0218", "suncity_s01_0219", "suncity_s01_0220", "suncity_s01_0216"]:
		var artifact_id = _find_owned_card_by_definition(duel_state, 0, definition_id)
		if artifact_id.is_empty():
			continue
		duel_state.get_player(0).hand.remove_card(artifact_id)
		duel_state.get_player(0).deck.remove_card(artifact_id)
		duel_state.get_player(0).grave.remove_card(artifact_id)
		duel_state.get_player(0).artifact_zone.add_card(artifact_id)
		duel_state.card_instances[artifact_id].zone = "artifact_zone"
		duel_state.card_instances[artifact_id].position = {}
	var replace = duel_engine.apply_command(duel_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": duel_engine._master_source_id(0),
		"effect_id": "isis_replace_with_osiris"
	}))
	_expect(bool(replace.get("ok", false)), "太阳城：伊西斯替换为复苏的奥西里斯发动失败", failures)
	_pass_stack_pair(duel_engine, duel_state)
	_expect(str(duel_state.get_player(0).master_definition_id) == "suncity_s01_02m2", "太阳城：满足5个卡诺匹斯后应切换为复苏的奥西里斯", failures)
	_expect(duel_state.winner == 0, "太阳城：双人模式下复苏的奥西里斯替换登场后应直接获胜", failures)

	var buff_engine := GameEngine.new()
	var buff_state = buff_engine.create_game(_definitions_with_suncity_masters(), [
		["suncity_s01_0212", TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID]
	], 72061, [
		{"name": "P0", "master_name": "复苏的奥西里斯", "master_id": "suncity_s01_02m2", "master_hp": 10, "master_max_hp": 10},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 8, 8))
	var tomb_guard_id = _find_grave_card_by_definition(buff_state, 0, "suncity_s01_0212")
	_expect(not tomb_guard_id.is_empty(), "太阳城：复苏的奥西里斯加攻测试初始化失败", failures)
	if tomb_guard_id.is_empty():
		return
	buff_engine._revive_grave_card_to_first_slot(buff_state, 0, tomb_guard_id, "test_osiris_tomb_guard_setup")
	_expect(buff_engine.get_card_power(buff_state, tomb_guard_id) == 3000, "太阳城：复苏的奥西里斯在场时陵墓守卫应获得兵力+1000", failures)


static func _test_medjed_master_effects(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_suncity_masters(), [
		["suncity_s01_0212", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		["suncity_s02_0203", TEST_FILLER_CARD_ID]
	], 72058, [
		{"name": "P0", "master_name": "梅杰德", "master_id": "suncity_s01_02m3a", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(2, 8, 8))
	var tomb_guard_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0212")
	var enemy_id = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	_expect(not tomb_guard_id.is_empty() and not enemy_id.is_empty(), "太阳城：梅杰德测试初始化失败", failures)
	if tomb_guard_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, tomb_guard_id, "front", 0, "test_medjed_guard_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_medjed_enemy_setup")
	var enemy_power_before = engine.get_card_power(state, enemy_id)
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": engine._master_source_id(0),
		"effect_id": "medjed_weaken_enemy"
	}))
	_expect(bool(activate.get("ok", false)), "太阳城：梅杰德主宰主动效果发动失败", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "suncity_medjed_weaken_mode", "empower"), "太阳城：梅杰德未能选择强化减攻模式", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_medjed_rest_tomb_guard_for_weaken", [tomb_guard_id]), "太阳城：梅杰德未能选择要休整的陵墓守卫", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_medjed_weaken_target", [enemy_id]), "太阳城：梅杰德未能选择减攻目标", failures)
	var tomb_guard_instance = state.card_instances.get(tomb_guard_id)
	_expect(tomb_guard_instance != null and str(tomb_guard_instance.orientation) == "rested", "太阳城：梅杰德强化模式应令所选陵墓守卫休整", failures)
	_expect(engine.get_card_power(state, enemy_id) == enemy_power_before - 3000, "太阳城：梅杰德强化模式应令目标本回合兵力-3000", failures)
	_expect(MoraleActions.count_spent_morale(state, 0) >= 1, "太阳城：梅杰德主宰主动效果应消耗1点士气", failures)

	var trigger_engine := GameEngine.new()
	var trigger_state = trigger_engine.create_game(_definitions_with_suncity_masters(), [
		["suncity_s01_0212", TEST_FILLER_CARD_ID],
		["suncity_s02_0203", TEST_FILLER_CARD_ID]
	], 72059, [
		{"name": "P0", "master_name": "梅杰德", "master_id": "suncity_s01_02m3a", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 8, 8))
	var grave_guard_id = _find_hand_card_by_definition(trigger_state, 0, "suncity_s01_0212")
	var enemy_attacker_id = _find_hand_card_by_definition(trigger_state, 1, "suncity_s02_0203")
	if grave_guard_id.is_empty():
		grave_guard_id = _find_deck_card_by_definition(trigger_state, 0, "suncity_s01_0212")
	if enemy_attacker_id.is_empty():
		enemy_attacker_id = _find_deck_card_by_definition(trigger_state, 1, "suncity_s02_0203")
	if grave_guard_id.is_empty():
		grave_guard_id = _find_owned_card_by_definition(trigger_state, 0, "suncity_s01_0212")
	if enemy_attacker_id.is_empty():
		enemy_attacker_id = _find_owned_card_by_definition(trigger_state, 1, "suncity_s02_0203")
	_expect(not grave_guard_id.is_empty() and not enemy_attacker_id.is_empty(), "太阳城：梅杰德受伤触发测试初始化失败", failures)
	if grave_guard_id.is_empty() or enemy_attacker_id.is_empty():
		return
	trigger_state.get_player(0).hand.remove_card(grave_guard_id)
	trigger_state.get_player(0).deck.remove_card(grave_guard_id)
	trigger_state.get_player(0).grave.remove_card(grave_guard_id)
	trigger_state.get_player(0).grave.add_card_to_top(grave_guard_id)
	trigger_state.card_instances[grave_guard_id].zone = "grave"
	trigger_state.card_instances[grave_guard_id].position = {}
	trigger_state.get_player(1).hand.remove_card(enemy_attacker_id)
	trigger_state.get_player(1).deck.remove_card(enemy_attacker_id)
	trigger_state.get_player(1).grave.remove_card(enemy_attacker_id)
	trigger_state.get_player(1).hand.add_card(enemy_attacker_id)
	trigger_state.card_instances[enemy_attacker_id].zone = "hand"
	trigger_state.card_instances[enemy_attacker_id].position = {}
	trigger_engine._deploy_hand_card_to_slot(trigger_state, 1, enemy_attacker_id, "front", 0, "test_medjed_trigger_enemy_setup")
	trigger_engine._begin_turn_for_player(trigger_state, 1)
	var damage_events = trigger_engine._deal_master_damage(trigger_state, 0, 1, "test_medjed_master_damaged", {
		"source_card_id": enemy_attacker_id,
		"source_kind": "attack"
	})
	trigger_engine.drain_until_waiting_for_input(trigger_state, damage_events, "test_medjed_master_damaged")
	_pass_stack_pair(trigger_engine, trigger_state)
	_expect(_resolve_first_optional_stack_effect(trigger_engine, trigger_state, true), "太阳城：梅杰德主宰受伤后未能出现可选复活效果", failures)
	if _has_pending_choice(trigger_state, "revive_from_grave"):
		_expect(_resolve_first_candidate_choice(trigger_engine, trigger_state, "revive_from_grave", [grave_guard_id]), "太阳城：梅杰德主宰受伤后未能选择要复活的陵墓守卫", failures)
	if _has_pending_choice(trigger_state, "revive_selected_grave_to_slot"):
		_expect(_resolve_first_option_choice(trigger_engine, trigger_state, "revive_selected_grave_to_slot", "front:0"), "太阳城：梅杰德主宰受伤后未能为复活目标选择位置", failures)
	_expect(_find_battlefield_card_by_definition(trigger_state, 0, "suncity_s01_0212") == grave_guard_id, "太阳城：梅杰德主宰受伤后应将墓地1张陵墓守卫活跃登场", failures)
	var revived_instance = trigger_state.card_instances.get(grave_guard_id)
	_expect(revived_instance != null and str(revived_instance.orientation) == "active", "太阳城：梅杰德主宰复活的陵墓守卫应为活跃状态", failures)


static func _test_suncity_morale_effects(failures: Array[String]) -> void:
	var revive_engine := GameEngine.new()
	var revive_state = _create_suncity_test_game(revive_engine, [
		["suncity_s01_0212", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 72066, _formal_options(3, 8, 8))
	var morale_actions = revive_engine.get_activatable_effects(revive_state, 0)
	var has_revive := false
	var has_draw := false
	for action in morale_actions:
		if str(action.get("source_id", "")) != "morale_0":
			continue
		if str(action.get("effect_id", "")) == "suncity_morale_revive_tomb_guard":
			has_revive = true
		elif str(action.get("effect_id", "")) == "suncity_morale_draw_if_low_hand":
			has_draw = true
	_expect(has_revive and has_draw, "太阳城：阵营士气应同时暴露复活守卫与低手牌抽牌两个效果", failures)
	var tomb_guard_id = _find_hand_card_by_definition(revive_state, 0, "suncity_s01_0212")
	if tomb_guard_id.is_empty():
		tomb_guard_id = _find_deck_card_by_definition(revive_state, 0, "suncity_s01_0212")
	if tomb_guard_id.is_empty():
		tomb_guard_id = _find_owned_card_by_definition(revive_state, 0, "suncity_s01_0212")
	_expect(not tomb_guard_id.is_empty(), "太阳城：士气复活测试初始化失败（未抽到陵墓守卫）", failures)
	if tomb_guard_id.is_empty():
		return
	revive_state.get_player(0).hand.remove_card(tomb_guard_id)
	revive_state.get_player(0).deck.remove_card(tomb_guard_id)
	revive_state.get_player(0).grave.remove_card(tomb_guard_id)
	revive_state.get_player(0).grave.add_card_to_top(tomb_guard_id)
	revive_state.card_instances[tomb_guard_id].zone = "grave"
	revive_state.card_instances[tomb_guard_id].position = {}
	var spent_morale_before = MoraleActions.count_spent_morale(revive_state, 0)
	var revive_activate = revive_engine.apply_command(revive_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "morale_0",
		"effect_id": "suncity_morale_revive_tomb_guard"
	}))
	_expect(bool(revive_activate.get("ok", false)), "太阳城：阵营士气复活守卫效果发动失败", failures)
	if not bool(revive_activate.get("ok", false)):
		return
	_pass_stack_pair(revive_engine, revive_state)
	_expect(_resolve_first_candidate_choice(revive_engine, revive_state, "revive_from_grave", [tomb_guard_id]), "太阳城：阵营士气复活守卫未能选择墓地目标", failures)
	_expect(_resolve_first_option_choice(revive_engine, revive_state, "revive_selected_grave_to_slot", "front:0"), "太阳城：阵营士气复活守卫未能为目标选择登场位置", failures)
	var revived_instance = revive_state.card_instances.get(tomb_guard_id)
	_expect(revived_instance != null and str(revived_instance.zone) == "battle_front" and str(revived_instance.orientation) == "active", "太阳城：阵营士气应将陵墓守卫活跃登场", failures)
	_expect(MoraleActions.count_spent_morale(revive_state, 0) == spent_morale_before + 2, "太阳城：阵营士气复活守卫应消耗2点士气", failures)

	var draw_engine := GameEngine.new()
	var draw_state = _create_suncity_test_game(draw_engine, [
		[TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 72067, _formal_options(3, 8, 8))
	var hand_before_draw = draw_state.get_player(0).hand.cards.size()
	var draw_spent_before = MoraleActions.count_spent_morale(draw_state, 0)
	var draw_activate = draw_engine.apply_command(draw_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "morale_0",
		"effect_id": "suncity_morale_draw_if_low_hand"
	}))
	_expect(bool(draw_activate.get("ok", false)), "太阳城：阵营士气低手牌抽牌效果在手牌不高于3张时应可发动", failures)
	if bool(draw_activate.get("ok", false)):
		_pass_stack_pair(draw_engine, draw_state)
		_expect(draw_state.get_player(0).hand.cards.size() == hand_before_draw + 1, "太阳城：阵营士气低手牌抽牌效果应抽取1张牌", failures)
		_expect(MoraleActions.count_spent_morale(draw_state, 0) == draw_spent_before + 1, "太阳城：阵营士气低手牌抽牌效果应消耗1点士气", failures)

	var blocked_engine := GameEngine.new()
	var blocked_state = _create_suncity_test_game(blocked_engine, [
		[TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 72068, _formal_options(4, 8, 8))
	var blocked_actions = blocked_engine.get_activatable_effects(blocked_state, 0)
	var blocked_has_draw := false
	for action in blocked_actions:
		if str(action.get("source_id", "")) == "morale_0" and str(action.get("effect_id", "")) == "suncity_morale_draw_if_low_hand":
			blocked_has_draw = true
			break
	_expect(not blocked_has_draw, "太阳城：阵营士气低手牌抽牌效果在手牌高于3张时不应暴露可发动行动", failures)
	_expect(not bool(blocked_engine.apply_command(blocked_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "morale_0",
		"effect_id": "suncity_morale_draw_if_low_hand"
	})).get("ok", false)), "太阳城：阵营士气低手牌抽牌效果在手牌高于3张时不应允许发动", failures)


static func _test_horemheb_entry_grants_charge(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0205", "suncity_s01_0212"],
		[]
	], 7207, _formal_options(2, 6, 6))
	var horemheb_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0205")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not horemheb_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：霍列姆赫布测试初始化失败", failures)
	if horemheb_id.is_empty() or tomb_guard_id.is_empty():
		return
	engine._revive_grave_card_to_first_slot(state, 0, tomb_guard_id, "test_horemheb_tomb_guard_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": horemheb_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：霍列姆赫布打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_horemheb_entry_charge", [tomb_guard_id]), "太阳城：霍列姆赫布未能选择弃置陵墓守卫", failures)
	var horemheb_instance = state.card_instances.get(horemheb_id)
	_expect(state.get_player(0).grave.cards.has(tomb_guard_id), "太阳城：霍列姆赫布进场冲锋应弃置陵墓守卫", failures)
	_expect(horemheb_instance != null and int(horemheb_instance.flags.get("temporary_keyword_charge_turn", -1)) == int(state.turn_number), "太阳城：霍列姆赫布进场后应获得冲锋", failures)


static func _test_horemheb_substitutes_tomb_guard_on_lethal(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0205", "suncity_s01_0212"],
		[]
	], 7208, _formal_options(2, 6, 6))
	var horemheb_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0205")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not horemheb_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：霍列姆赫布代承伤测试初始化失败", failures)
	if horemheb_id.is_empty() or tomb_guard_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, horemheb_id, "front", 0, "test_horemheb_substitute_setup")
	engine._revive_grave_card_to_first_slot(state, 0, tomb_guard_id, "test_horemheb_substitute_tomb_guard")
	var horemheb_instance = state.card_instances.get(horemheb_id)
	if horemheb_instance == null:
		failures.append("太阳城：霍列姆赫布代承伤测试未能找到已登场本体")
		return
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {"target_card_id": horemheb_id},
		"resolution": {}
	}, "test_horemheb_substitute_destroy")
	_expect(not destroy_events.is_empty(), "太阳城：霍列姆赫布代承伤应产生替代事件", failures)
	_expect(_find_battlefield_card_by_definition(state, 0, "suncity_s01_0205") == horemheb_id, "太阳城：霍列姆赫布代承伤后本体应留在战场", failures)
	_expect(state.get_player(0).grave.cards.has(tomb_guard_id), "太阳城：霍列姆赫布代承伤后陵墓守卫应进入墓地", failures)
	_expect(int(horemheb_instance.flags.get("suncity_horemheb_substitute_turn", -1)) == int(state.turn_number), "太阳城：霍列姆赫布代承伤应记录本回合已使用", failures)


static func _test_hatshepsut_entry_and_death(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s02_0203", "suncity_s02_0201", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 72069, _formal_options(2, 8, 8))
	var hatshepsut_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	var beetle_id = _find_grave_card_by_definition(state, 0, "suncity_s02_0201")
	_expect(not hatshepsut_id.is_empty() and not beetle_id.is_empty(), "太阳城：哈特谢普苏特测试初始化失败", failures)
	if hatshepsut_id.is_empty() or beetle_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hatshepsut_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：哈特谢普苏特打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_optional_stack_effect(engine, state, true), "太阳城：哈特谢普苏特登场时应可选择复活增殖的甲虫", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "revive_from_grave", [beetle_id]), "太阳城：哈特谢普苏特登场时未能选择复活增殖的甲虫", failures)
	_expect(_resolve_first_option_choice(engine, state, "revive_selected_grave_to_slot", "front:1"), "太阳城：哈特谢普苏特登场时未能为复活目标选择位置", failures)
	var beetle_instance = state.card_instances.get(beetle_id)
	_expect(beetle_instance != null and str(beetle_instance.zone) == "battle_front" and int(beetle_instance.position.get("col", -1)) == 1 and str(beetle_instance.orientation) == "active", "太阳城：哈特谢普苏特登场时应将增殖的甲虫活跃登场", failures)
	var hand_before_draw = state.get_player(0).hand.cards.size()
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {"target_card_id": hatshepsut_id},
		"resolution": {}
	}, "test_hatshepsut_death")
	engine.drain_until_waiting_for_input(state, destroy_events, "test_hatshepsut_death")
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_optional_stack_effect(engine, state, true), "太阳城：哈特谢普苏特阵亡时应可选择抽牌", failures)
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).hand.cards.size() == hand_before_draw + 1, "太阳城：哈特谢普苏特阵亡时应可抽取1张牌", failures)


static func _test_tomb_paladin_cost_and_death_revive(failures: Array[String]) -> void:
	var cost_engine := GameEngine.new()
	var cost_state = _create_suncity_test_game(cost_engine, [
		["suncity_s02_0202", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		[]
	], 72070, _formal_options(2, 8, 8))
	var paladin_id = _find_hand_card_by_definition(cost_state, 0, "suncity_s02_0202")
	_expect(not paladin_id.is_empty(), "太阳城：陵墓圣武士费用测试初始化失败", failures)
	if paladin_id.is_empty():
		return
	_expect(cost_engine._get_effective_play_cost(cost_state, paladin_id) == 6, "太阳城：陵墓圣武士基础费用应为6", failures)
	cost_state.get_player(0).flags["suncity_tomb_left_count"] = 2
	_expect(cost_engine._get_effective_play_cost(cost_state, paladin_id) == 4, "太阳城：陵墓圣武士应按本回合陵墓离场数减费", failures)

	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s02_0202", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		[]
	], 72071, _formal_options(2, 8, 8))
	var revive_paladin_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0202")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not revive_paladin_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：陵墓圣武士复活测试初始化失败", failures)
	if revive_paladin_id.is_empty() or tomb_guard_id.is_empty():
		return
	var paladin_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": revive_paladin_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(paladin_play.get("ok", false)), "太阳城：陵墓圣武士打出失败", failures)
	if not bool(paladin_play.get("ok", false)):
		return
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {"target_card_id": revive_paladin_id},
		"resolution": {}
	}, "test_tomb_paladin_death")
	engine.drain_until_waiting_for_input(state, destroy_events, "test_tomb_paladin_death")
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "revive_from_grave", [tomb_guard_id]), "太阳城：陵墓圣武士阵亡后未能选择复活陵墓守卫", failures)
	_expect(_resolve_first_option_choice(engine, state, "revive_selected_grave_to_slot", "front:0"), "太阳城：陵墓圣武士阵亡后未能为复活目标选择位置", failures)
	var revived_instance = state.card_instances.get(tomb_guard_id)
	_expect(revived_instance != null and str(revived_instance.zone) == "battle_front" and str(revived_instance.orientation) == "active", "太阳城：陵墓圣武士阵亡后应将陵墓守卫活跃登场", failures)


static func _test_golden_scarab_entry_rest_and_weaken(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s02_0205", TEST_FILLER_CARD_ID, "suncity_s02_0201", TEST_FILLER_CARD_ID],
		["suncity_s02_0203", "suncity_s02_0203"]
	], 72065, _formal_options(2, 8, 8))
	var scarab_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0205")
	var discard_id = _find_other_hand_card_by_definition(state, 0, TEST_FILLER_CARD_ID, scarab_id)
	var beetle_id = _find_grave_card_by_definition(state, 0, "suncity_s02_0201")
	var enemy_a = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	var enemy_b = _find_other_hand_card_by_definition(state, 1, "suncity_s02_0203", enemy_a)
	_expect(not scarab_id.is_empty() and not discard_id.is_empty() and not beetle_id.is_empty() and not enemy_a.is_empty() and not enemy_b.is_empty(), "太阳城：黄金圣甲虫测试初始化失败", failures)
	if scarab_id.is_empty() or discard_id.is_empty() or beetle_id.is_empty() or enemy_a.is_empty() or enemy_b.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_a, "front", 0, "test_golden_scarab_enemy_a")
	engine._deploy_hand_card_to_slot(state, 1, enemy_b, "front", 1, "test_golden_scarab_enemy_b")
	var enemy_a_instance = state.card_instances.get(enemy_a)
	var enemy_b_instance = state.card_instances.get(enemy_b)
	var enemy_a_power_before = engine.get_card_power(state, enemy_a)
	var enemy_b_power_before = engine.get_card_power(state, enemy_b)
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": scarab_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：黄金圣甲虫打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_optional_stack_effect(engine, state, true), "太阳城：黄金圣甲虫登场时应可选择复活增殖的甲虫", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "revive_from_grave", [beetle_id]), "太阳城：黄金圣甲虫登场时未能选择复活增殖的甲虫", failures)
	_expect(_resolve_first_option_choice(engine, state, "revive_selected_grave_to_slot", "front:0"), "太阳城：黄金圣甲虫登场时未能为复活目标选择位置", failures)
	var beetle_instance = state.card_instances.get(beetle_id)
	_expect(beetle_instance != null and str(beetle_instance.zone) == "battle_front" and str(beetle_instance.orientation) == "active", "太阳城：黄金圣甲虫登场时应将增殖的甲虫活跃登场", failures)
	var beetle_grave_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_golden_scarab_rebury")
	engine.drain_until_waiting_for_input(state, beetle_grave_events, "test_golden_scarab_rebury")
	var activate_revive = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": scarab_id,
		"effect_id": "golden_scarab_rest_revive_beetle"
	}))
	_expect(bool(activate_revive.get("ok", false)), "太阳城：黄金圣甲虫主动休整复活效果发动失败", failures)
	if not bool(activate_revive.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_optional_stack_effect(engine, state, true), "太阳城：黄金圣甲虫主动休整后应可选择复活增殖的甲虫", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "revive_from_grave", [beetle_id]), "太阳城：黄金圣甲虫主动休整后未能选择复活增殖的甲虫", failures)
	_expect(_resolve_first_option_choice(engine, state, "revive_selected_grave_to_slot", "front:0"), "太阳城：黄金圣甲虫主动休整后未能为复活目标选择位置", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": scarab_id,
		"effect_id": "golden_scarab_discard_weaken"
	})).get("ok", false), "太阳城：黄金圣甲虫弃牌减攻效果发动失败", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_golden_scarab_weaken", [enemy_a, enemy_b]), "太阳城：黄金圣甲虫未能选择减攻目标", failures)
	_expect(enemy_a_instance != null and enemy_b_instance != null and engine.get_card_power(state, enemy_a) == enemy_a_power_before - 1000 and engine.get_card_power(state, enemy_b) == enemy_b_power_before - 1000, "太阳城：黄金圣甲虫应令所选敌方军团各-1000", failures)
	_expect(not state.get_player(0).hand.cards.has(discard_id), "太阳城：黄金圣甲虫发动弃牌减攻后应弃置1张手牌", failures)
	_expect(state.get_player(0).grave.cards.has(discard_id), "太阳城：黄金圣甲虫弃置的手牌应进入墓地", failures)


static func _test_fearless_assassination_buffs_and_discards_at_turn_end(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s02_0206", "suncity_s02_0203", TEST_FILLER_CARD_ID],
		["suncity_s02_0203"]
	], 72062, _formal_options(2, 8, 8))
	var tactic_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0206")
	var ally_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	var enemy_id = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	_expect(not tactic_id.is_empty() and not ally_id.is_empty() and not enemy_id.is_empty(), "太阳城：无畏的刺杀测试初始化失败", failures)
	if tactic_id.is_empty() or ally_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_fearless_assassination_ally_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_fearless_assassination_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"target_card_id": ally_id
	}))
	_expect(bool(play.get("ok", false)), "太阳城：无畏的刺杀打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var ally_instance = state.card_instances.get(ally_id)
	_expect(engine.get_card_power(state, ally_id) == 6000, "太阳城：无畏的刺杀应给予目标本回合兵力+3000", failures)
	_expect(ally_instance != null and int(ally_instance.flags.get("temporary_keyword_must_hit_turn", -1)) == int(state.turn_number), "太阳城：无畏的刺杀应给予目标本回合必中", failures)
	_expect(ally_instance != null and int(ally_instance.flags.get("cannot_ready_by_effect_turn", -1)) == int(state.turn_number), "太阳城：无畏的刺杀应令目标本回合无法因效果重置为活跃", failures)
	engine._rest_target_unit(state, ally_id, "test_fearless_assassination_rest")
	var ready_events = engine._ready_target_unit(state, ally_id, "test_fearless_assassination_ready")
	_expect(ready_events.is_empty(), "太阳城：无畏的刺杀期间目标不应被效果重置为活跃", failures)
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "EndPhase")).get("ok", false)), "太阳城：无畏的刺杀测试推进到结束阶段失败", failures)
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "EndPhase")).get("ok", false)), "太阳城：无畏的刺杀测试离开结束阶段失败", failures)
	_expect(state.get_player(0).grave.cards.has(ally_id), "太阳城：无畏的刺杀目标应在回合结束时进入墓地", failures)
	_expect(_find_battlefield_card_by_definition(state, 0, "suncity_s02_0203").is_empty(), "太阳城：无畏的刺杀目标在回合结束后不应继续留在战场", failures)


static func _test_saladin_taunt_and_adjacent_attack_buff(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0206", "suncity_s02_0203", "suncity_s02_0204"],
		["suncity_s02_0203"]
	], 7223, _formal_options(3, 8, 8))
	var saladin_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0206")
	var ally_attacker_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	var ally_other_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0204")
	var enemy_attacker_id = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	_expect(not saladin_id.is_empty() and not ally_attacker_id.is_empty() and not ally_other_id.is_empty() and not enemy_attacker_id.is_empty(), "太阳城：萨拉丁挑畔测试初始化失败", failures)
	if saladin_id.is_empty() or ally_attacker_id.is_empty() or ally_other_id.is_empty() or enemy_attacker_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, saladin_id, "front", 0, "test_saladin_setup")
	engine._deploy_hand_card_to_slot(state, 0, ally_attacker_id, "front", 1, "test_saladin_adjacent_setup")
	engine._deploy_hand_card_to_slot(state, 0, ally_other_id, "front", 2, "test_saladin_other_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_attacker_id, "front", 0, "test_saladin_enemy_setup")
	state.card_instances[saladin_id].entered_turn = -1
	state.card_instances[ally_attacker_id].entered_turn = -1
	state.card_instances[ally_other_id].entered_turn = -1
	state.card_instances[enemy_attacker_id].entered_turn = -1
	engine._begin_turn_for_player(state, 1)
	var taunt_attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": enemy_attacker_id,
		"target_kind": "card",
		"defender_id": ally_other_id
	}))
	_expect(not bool(taunt_attack.get("ok", false)), "太阳城：萨拉丁位于前排时应强制敌方优先进攻自身", failures)
	engine._begin_turn_for_player(state, 0)
	state.card_instances[saladin_id].entered_turn = -1
	state.card_instances[ally_attacker_id].entered_turn = -1
	var ally_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": ally_attacker_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(ally_attack.get("ok", false)), "太阳城：萨拉丁相邻军团宣告进攻失败", failures)
	if not bool(ally_attack.get("ok", false)):
		return
	_expect(engine._power_before_damage(state, ally_attacker_id, true) == 4000, "太阳城：萨拉丁位于前排时相邻太阳城军团进攻应 +1000", failures)


static func _test_saladin_move_and_triggered_reposition(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0206", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		[]
	], 7224, _formal_options(2, 8, 8))
	var saladin_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0206")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not saladin_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：萨拉丁位移测试初始化失败", failures)
	if saladin_id.is_empty() or tomb_guard_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, saladin_id, "front", 0, "test_saladin_reposition_setup")
	engine._revive_grave_card_to_first_slot(state, 0, tomb_guard_id, "test_saladin_tomb_guard_setup")
	var tomb_guard_instance = state.card_instances.get(tomb_guard_id)
	var saladin_instance = state.card_instances.get(saladin_id)
	if tomb_guard_instance == null or saladin_instance == null:
		failures.append("太阳城：萨拉丁位移测试未能完成战场初始化")
		return
	saladin_instance.entered_turn = -1
	var activate_move = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": saladin_id,
		"effect_id": "saladin_move_once"
	}))
	_expect(bool(activate_move.get("ok", false)), "太阳城：萨拉丁主动位移效果发动失败", failures)
	if not bool(activate_move.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "choose_battlefield_cards_to_move", [tomb_guard_id]), "太阳城：萨拉丁主动位移未能选择目标", failures)
	_expect(_resolve_first_option_choice(engine, state, "move_selected_battlefield_card_to_slot", "back:1"), "太阳城：萨拉丁主动位移未能选择目标位置", failures)
	_expect(str(tomb_guard_instance.position.get("row", "")) == "back" and int(tomb_guard_instance.position.get("col", -1)) == 1, "太阳城：萨拉丁主动效果应能完成1次位移", failures)
	var activate_again = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": saladin_id,
		"effect_id": "saladin_move_once"
	}))
	_expect(not bool(activate_again.get("ok", false)), "太阳城：萨拉丁主动位移应受回合1次限制", failures)
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": saladin_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "太阳城：萨拉丁宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "太阳城：萨拉丁进攻时应可选择发动位移", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "choose_battlefield_cards_to_move", [tomb_guard_id]), "太阳城：萨拉丁进攻触发未能选择位移目标", failures)
	_expect(_resolve_first_option_choice(engine, state, "move_selected_battlefield_card_to_slot", "front:1"), "太阳城：萨拉丁进攻触发未能选择位移位置", failures)
	_expect(str(tomb_guard_instance.position.get("row", "")) == "front" and int(tomb_guard_instance.position.get("col", -1)) == 1, "太阳城：萨拉丁进攻触发后应能位移陵墓守卫", failures)
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {"target_card_id": saladin_id},
		"resolution": {}
	}, "test_saladin_death")
	engine.drain_until_waiting_for_input(state, destroy_events, "test_saladin_death")
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_optional_stack_effect(engine, state, true), "太阳城：萨拉丁阵亡时应可选择发动位移", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "choose_battlefield_cards_to_move", [tomb_guard_id]), "太阳城：萨拉丁阵亡触发未能选择位移目标", failures)
	_expect(_resolve_first_option_choice(engine, state, "move_selected_battlefield_card_to_slot", "back:1"), "太阳城：萨拉丁阵亡触发未能选择位移位置", failures)
	_expect(str(tomb_guard_instance.position.get("row", "")) == "back" and int(tomb_guard_instance.position.get("col", -1)) == 1, "太阳城：萨拉丁阵亡触发后应能位移陵墓守卫", failures)


static func _test_siwa_hand_response_and_ready_lock(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0213", TEST_FILLER_CARD_ID],
		["suncity_s02_0203", TEST_FILLER_CARD_ID]
	], 72235, _formal_options(2, 8, 8))
	var siwa_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0213")
	var enemy_attacker_id = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	_expect(not siwa_id.is_empty() and not enemy_attacker_id.is_empty(), "太阳城：锡瓦的卡巴测试初始化失败", failures)
	if siwa_id.is_empty() or enemy_attacker_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, siwa_id, "back", 0, "test_siwa_back_setup")
	var siwa_instance = state.card_instances.get(siwa_id)
	if siwa_instance == null:
		failures.append("太阳城：锡瓦的卡巴后排测试未找到本体")
		return
	_expect(not engine._has_attack_keyword(state, siwa_id, "ranged"), "太阳城：锡瓦的卡巴位于后排外不应默认获得远程", failures)
	engine._move_battlefield_card(state, 0, siwa_id, "front", 0, "test_siwa_move_front")
	_expect(engine._has_attack_keyword(state, siwa_id, "ranged") and engine._has_attack_keyword(state, siwa_id, "ranged_no_loss"), "太阳城：锡瓦的卡巴位于前排时应获得远程与远程无损", failures)

	var response_engine := GameEngine.new()
	var response_state = _create_suncity_test_game(response_engine, [
		["suncity_s01_0213", TEST_FILLER_CARD_ID],
		["suncity_s02_0203", TEST_FILLER_CARD_ID]
	], 72236, _formal_options(2, 8, 8))
	var response_siwa_id = _find_hand_card_by_definition(response_state, 0, "suncity_s01_0213")
	var response_enemy_id = _find_hand_card_by_definition(response_state, 1, "suncity_s02_0203")
	_expect(not response_siwa_id.is_empty() and not response_enemy_id.is_empty(), "太阳城：锡瓦的卡巴响应测试初始化失败", failures)
	if response_siwa_id.is_empty() or response_enemy_id.is_empty():
		return
	response_engine._deploy_hand_card_to_slot(response_state, 1, response_enemy_id, "front", 0, "test_siwa_enemy_setup")
	response_state.card_instances[response_enemy_id].entered_turn = -1
	response_engine._begin_turn_for_player(response_state, 1)
	var declare = response_engine.apply_command(response_state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": response_enemy_id,
		"target_kind": "master",
		"target_player": 0
	}))
	_expect(bool(declare.get("ok", false)), "太阳城：锡瓦的卡巴前置宣告进攻失败", failures)
	if not bool(declare.get("ok", false)):
		return
	_resolve_pending_attack(response_engine, response_state, failures, "太阳城：锡瓦的卡巴第一次优先权放弃应成功", "太阳城：锡瓦的卡巴第二次优先权放弃应完成进攻并排入触发")
	_expect(response_state.pending_attack.is_empty(), "太阳城：锡瓦的卡巴应在进攻结束后再触发，而非保留进行中的攻击", failures)
	_expect(not response_state.stack.is_empty(), "太阳城：锡瓦的卡巴应在进攻结束后将触发效果置入堆栈", failures)
	_resolve_top_stack(response_engine, response_state, failures, "太阳城：锡瓦的卡巴应在堆栈结算时询问是否发动")
	_expect(_has_pending_choice(response_state, "optional_stack_effect"), "太阳城：锡瓦的卡巴进攻后应出现是否发动的可选提示", failures)
	_expect(_resolve_first_option_choice(response_engine, response_state, "optional_stack_effect", "yes"), "太阳城：锡瓦的卡巴进攻后应可选择发动登场效果", failures)
	var deployed_siwa_id = _find_battlefield_card_by_definition(response_state, 0, "suncity_s01_0213")
	var deployed_siwa = response_state.card_instances.get(deployed_siwa_id)
	_expect(deployed_siwa_id == response_siwa_id and deployed_siwa != null and str(deployed_siwa.position.get("row", "")) == "front" and str(deployed_siwa.orientation) == "active", "太阳城：锡瓦的卡巴进攻结束后应活跃登场于前排", failures)
	_expect(response_state.pending_attack.is_empty(), "太阳城：锡瓦的卡巴进攻结束后登场不应改写已经完成的攻击", failures)
	_expect(int(response_state.get_player(0).flags.get("suncity_skip_next_ready_morale_count", 0)) == 1, "太阳城：锡瓦的卡巴进攻结束后登场应记录下个重置阶段锁1士气", failures)

	var morale_a = str(response_state.get_player(0).cost_area.cards[0]) if response_state.get_player(0).cost_area.cards.size() > 0 else ""
	var morale_b = str(response_state.get_player(0).cost_area.cards[1]) if response_state.get_player(0).cost_area.cards.size() > 1 else ""
	_expect(not morale_a.is_empty() and not morale_b.is_empty(), "太阳城：锡瓦的卡巴测试初始化失败（士气不足）", failures)
	if morale_a.is_empty() or morale_b.is_empty():
		return
	response_state.card_instances[morale_a].orientation = "rested"
	response_state.card_instances[morale_b].orientation = "rested"
	response_state.get_player(0).cost_area.remove_card(morale_a)
	response_state.get_player(0).cost_area.remove_card(morale_b)
	response_state.get_player(0).spent_cost_area.add_card(morale_a)
	response_state.get_player(0).spent_cost_area.add_card(morale_b)
	response_state.card_instances[morale_a].zone = "spent_cost_area"
	response_state.card_instances[morale_b].zone = "spent_cost_area"
	response_state.pending_attack = {}
	response_engine._begin_turn_for_player(response_state, 0)
	response_state.phase = "ready"
	response_engine._on_enter_phase(response_state, "test_siwa_ready_lock")
	_expect(MoraleActions.count_spent_morale(response_state, 0) == 1, "太阳城：锡瓦的卡巴在下个我方重置阶段应少翻1张士气", failures)
	_expect(not response_state.get_player(0).flags.has("suncity_skip_next_ready_morale_count"), "太阳城：锡瓦的卡巴的锁士气标记应在生效后清除", failures)


static func _test_ai_entry_and_attack_buff(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0208", "suncity_s01_0212"],
		[]
	], 7210, _formal_options(2, 6, 6))
	var ai_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0208")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not ai_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：阿伊测试初始化失败", failures)
	if ai_id.is_empty() or tomb_guard_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ai_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：阿伊打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "revive_from_grave", [tomb_guard_id]), "太阳城：阿伊未能选择复活的陵墓守卫", failures)
	_expect(_resolve_first_option_choice(engine, state, "revive_selected_grave_to_slot", "front:1"), "太阳城：阿伊未能为休整登场选择位置", failures)
	var tomb_guard_instance = state.card_instances.get(tomb_guard_id)
	_expect(tomb_guard_instance != null and str(tomb_guard_instance.zone) == "battle_front" and str(tomb_guard_instance.orientation) == "rested", "太阳城：阿伊应将陵墓守卫休整登场", failures)
	var ai_instance = state.card_instances.get(ai_id)
	if ai_instance != null:
		ai_instance.entered_turn = -1
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": ai_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "太阳城：阿伊宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "太阳城：阿伊进攻时应可选择发动强化", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "modify_power_until_turn_end", [ai_id]), "太阳城：阿伊未能选择强化目标", failures)
	_expect(engine.get_card_power(state, ai_id) == 4000, "太阳城：阿伊进攻强化后目标应 +2000", failures)


static func _test_ramesses_cost_and_replay_entries(failures: Array[String]) -> void:
	var cost_engine := GameEngine.new()
	var cost_state = _create_suncity_test_game(cost_engine, [
		["suncity_s01_0202", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		[]
	], 7226, _formal_options(2, 8, 8))
	var ramesses_id = _find_hand_card_by_definition(cost_state, 0, "suncity_s01_0202")
	var tomb_guard_id = _find_grave_card_by_definition(cost_state, 0, "suncity_s01_0212")
	_expect(not ramesses_id.is_empty(), "太阳城：拉美西斯二世费用测试初始化失败", failures)
	if ramesses_id.is_empty():
		return
	_expect(cost_engine._get_effective_play_cost(cost_state, ramesses_id) == 6, "太阳城：拉美西斯二世在无陵墓守卫时应费用 -2", failures)
	if not tomb_guard_id.is_empty():
		cost_engine._revive_grave_card_to_first_slot(cost_state, 0, tomb_guard_id, "test_ramesses_cost_tomb_guard")
		_expect(cost_engine._get_effective_play_cost(cost_state, ramesses_id) == 8, "太阳城：拉美西斯二世在存在陵墓守卫时不应继续费用 -2", failures)

	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0202", "suncity_s01_0208", "suncity_s01_0210", "suncity_s01_0212", "suncity_s02_0201", TEST_FILLER_CARD_ID],
		[]
	], 7227, _formal_options(3, 8, 8))
	var replay_ramesses_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0202")
	var ai_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0208")
	var nitocris_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0210")
	var revive_tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	var revive_beetle_id = _find_grave_card_by_definition(state, 0, "suncity_s02_0201")
	_expect(not replay_ramesses_id.is_empty() and not ai_id.is_empty() and not nitocris_id.is_empty() and not revive_tomb_guard_id.is_empty() and not revive_beetle_id.is_empty(), "太阳城：拉美西斯二世重放登场效果测试初始化失败", failures)
	if replay_ramesses_id.is_empty() or ai_id.is_empty() or nitocris_id.is_empty() or revive_tomb_guard_id.is_empty() or revive_beetle_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, ai_id, "front", 1, "test_ramesses_ai_setup")
	engine._deploy_hand_card_to_slot(state, 0, nitocris_id, "front", 2, "test_ramesses_nitocris_setup")
	var nitocris_instance = state.card_instances.get(nitocris_id)
	if nitocris_instance != null:
		nitocris_instance.entered_turn = -1
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": replay_ramesses_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：拉美西斯二世打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_ramesses_replay_entries", [ai_id, nitocris_id]), "太阳城：拉美西斯二世未能选择要重放登场效果的太阳城军团", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "revive_from_grave", [revive_tomb_guard_id]), "太阳城：拉美西斯二世未能按顺序先重放阿伊登场效果", failures)
	_expect(_resolve_first_option_choice(engine, state, "revive_selected_grave_to_slot", "back:0"), "太阳城：拉美西斯二世未能为阿伊重放目标选择位置", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "ready_battlefield_card", [revive_tomb_guard_id]), "太阳城：拉美西斯二世未能继续重放尼托克丽丝登场效果", failures)
	var tomb_guard_instance = state.card_instances.get(revive_tomb_guard_id)
	_expect(tomb_guard_instance != null and str(tomb_guard_instance.zone) == "battle_back" and str(tomb_guard_instance.orientation) == "active", "太阳城：拉美西斯二世重放后应先让陵墓守卫休整登场再被尼托克丽丝转为活跃", failures)
	var ramesses_instance = state.card_instances.get(replay_ramesses_id)
	_expect(ramesses_instance != null and int(ramesses_instance.flags.get("suncity_ignore_counter_tactics_turn", -1)) == int(state.turn_number), "太阳城：拉美西斯二世登场回合应获得免反击标记", failures)


static func _test_codex_volume_one_counters_or_rewards(failures: Array[String]) -> void:
	var counter_engine := GameEngine.new()
	var counter_state = _create_suncity_test_game(counter_engine, [
		["suncity_s01_0224", TEST_FILLER_CARD_ID],
		["suncity_s01_0219"]
	], 7228, _formal_options(1, 8, 8))
	var counter_codex_id = _find_hand_card_by_definition(counter_state, 0, "suncity_s01_0224")
	var enemy_canopic_id = _find_hand_card_by_definition(counter_state, 1, "suncity_s01_0219")
	_expect(not counter_codex_id.is_empty() and not enemy_canopic_id.is_empty(), "太阳城：智慧法典 卷一反制测试初始化失败", failures)
	if counter_codex_id.is_empty() or enemy_canopic_id.is_empty():
		return
	counter_engine._begin_turn_for_player(counter_state, 1)
	var enemy_play = counter_engine.apply_command(counter_state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_canopic_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(enemy_play.get("ok", false)) and counter_state.stack.size() == 1, "太阳城：智慧法典 卷一前置目标效果未能正常入栈", failures)
	if not bool(enemy_play.get("ok", false)) or counter_state.stack.is_empty():
		return
	var enemy_stack_id = str(counter_state.stack[0].get("stack_id", ""))
	var counter_play = counter_engine.apply_command(counter_state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_codex_id,
		"row": "counter_tactic",
		"col": -1,
		"target_stack_id": enemy_stack_id
	}))
	_expect(bool(counter_play.get("ok", false)), "太阳城：智慧法典 卷一反击战术打出失败", failures)
	if not bool(counter_play.get("ok", false)):
		return
	_pass_stack_pair(counter_engine, counter_state)
	_expect(counter_state.stack.is_empty(), "太阳城：智慧法典 卷一在对方无手牌时应直接使目标效果无效", failures)
	_expect(not counter_state.get_player(1).flags.has("temporary_morale_turn"), "太阳城：智慧法典 卷一反制成功后不应让目标圣物效果生效", failures)
	_expect(counter_state.get_player(1).artifact_zone.cards.has(enemy_canopic_id), "太阳城：被反制的卡诺匹斯罐 三本体仍应留在圣物区", failures)

	var reward_engine := GameEngine.new()
	var reward_state = _create_suncity_test_game(reward_engine, [
		["suncity_s01_0224", TEST_FILLER_CARD_ID, "suncity_s01_0217", TEST_FILLER_CARD_ID],
		["suncity_s01_0219", TEST_FILLER_CARD_ID]
	], 7229, _formal_options(2, 8, 8))
	var reward_codex_id = _find_hand_card_by_definition(reward_state, 0, "suncity_s01_0224")
	var reward_target_id = _find_hand_card_by_definition(reward_state, 1, "suncity_s01_0219")
	var enemy_discard_id = _find_other_hand_card_by_definition(reward_state, 1, TEST_FILLER_CARD_ID, reward_target_id)
	reward_engine._move_deck_definition_to_grave(reward_state, 0, "suncity_s01_0217", "test_codex_reward_setup")
	var recover_id = _find_grave_card_by_definition(reward_state, 0, "suncity_s01_0217")
	_expect(not reward_codex_id.is_empty() and not reward_target_id.is_empty() and not enemy_discard_id.is_empty() and not recover_id.is_empty(), "太阳城：智慧法典 卷一奖励测试初始化失败", failures)
	if reward_codex_id.is_empty() or reward_target_id.is_empty() or enemy_discard_id.is_empty() or recover_id.is_empty():
		return
	reward_engine._begin_turn_for_player(reward_state, 1)
	var reward_enemy_play = reward_engine.apply_command(reward_state, GameCommand.create(1, "PlayCard", {
		"card_id": reward_target_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(reward_enemy_play.get("ok", false)) and reward_state.stack.size() == 1, "太阳城：智慧法典 卷一奖励测试前置目标效果未能正常入栈", failures)
	if not bool(reward_enemy_play.get("ok", false)) or reward_state.stack.is_empty():
		return
	var reward_stack_id = str(reward_state.stack[0].get("stack_id", ""))
	var reward_play = reward_engine.apply_command(reward_state, GameCommand.create(0, "PlayCard", {
		"card_id": reward_codex_id,
		"row": "counter_tactic",
		"col": -1,
		"target_stack_id": reward_stack_id
	}))
	_expect(bool(reward_play.get("ok", false)), "太阳城：智慧法典 卷一奖励测试打出失败", failures)
	if not bool(reward_play.get("ok", false)):
		return
	_pass_stack_pair(reward_engine, reward_state)
	_expect(_resolve_first_option_choice(reward_engine, reward_state, "suncity_codex_force_discard_or_counter", "discard"), "太阳城：智慧法典 卷一未能要求对方选择弃牌继续发动", failures)
	_expect(_resolve_first_candidate_choice(reward_engine, reward_state, "discard_from_hand", [enemy_discard_id]), "太阳城：智慧法典 卷一未能让对方弃置1张手牌", failures)
	_pass_stack_pair(reward_engine, reward_state)
	_expect(_resolve_first_candidate_choice(reward_engine, reward_state, "return_grave_to_hand", [recover_id]), "太阳城：智慧法典 卷一在对方成功发动效果后未能选择回收目标", failures)
	_expect(reward_state.get_player(1).flags.has("temporary_morale_turn"), "太阳城：智慧法典 卷一允许弃牌后目标圣物效果应继续生效", failures)
	_expect(reward_state.get_player(0).hand.cards.has(recover_id), "太阳城：智慧法典 卷一奖励后应将所选墓地战术/圣物加入手牌", failures)
	_expect(not reward_state.get_player(0).grave.cards.has(recover_id), "太阳城：智慧法典 卷一回收后目标不应继续留在墓地", failures)


static func _test_nefertiti_entry_and_death(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0209", "suncity_s02_0203", "suncity_s02_0204", "asgard_s01_0301", "asgard_s01_0301", "asgard_s01_0301"],
		["asgard_s01_0301", "asgard_s01_0301", "asgard_s01_0301", "asgard_s01_0301", "asgard_s01_0301", "asgard_s01_0301"]
	], 7211, _formal_options(6, 6, 6))
	var nefertiti_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0209")
	var enemy_discard_id = str(state.get_player(1).hand.cards[0]) if state.get_player(1).hand.cards.size() > 0 else ""
	_expect(not nefertiti_id.is_empty() and not enemy_discard_id.is_empty(), "太阳城：纳芙蒂蒂测试初始化失败", failures)
	if nefertiti_id.is_empty() or enemy_discard_id.is_empty():
		return
	var enemy_hand_before = state.get_player(1).hand.cards.size()
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": nefertiti_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：纳芙蒂蒂打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "discard_from_hand", [enemy_discard_id]), "太阳城：纳芙蒂蒂未能令对手弃牌", failures)
	_expect(state.get_player(1).hand.cards.size() == enemy_hand_before - 1, "太阳城：纳芙蒂蒂登场后对手手牌应 -1", failures)
	_expect(state.get_player(1).grave.cards.has(enemy_discard_id), "太阳城：纳芙蒂蒂登场后弃掉的牌应进入对手墓地", failures)
	if state.get_player(0).hand.cards.size() > 0:
		var own_card = str(state.get_player(0).hand.cards[0])
		state.get_player(0).hand.remove_card(own_card)
		state.get_player(0).grave.add_card_to_top(own_card)
		state.card_instances[own_card].zone = "grave"
		state.card_instances[own_card].position = {}
	state.get_player(0).master_hp = 7
	var own_hp_before = int(state.get_player(0).master_hp)
	var enemy_hp_before = int(state.get_player(1).master_hp)
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {"target_card_id": nefertiti_id},
		"resolution": {}
	}, "test_nefertiti_death")
	engine.drain_until_waiting_for_input(state, destroy_events, "test_nefertiti_death")
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(1).master_hp) == enemy_hp_before - 1, "太阳城：纳芙蒂蒂阵亡后应对敌方主宰造成1点伤害", failures)
	_expect(int(state.get_player(0).master_hp) == own_hp_before + 1, "太阳城：纳芙蒂蒂阵亡后应回复我方主宰1点生命", failures)


static func _test_nefertiti_conditions_gate_effects(failures: Array[String]) -> void:
	var entry_engine := GameEngine.new()
	var entry_state = _create_suncity_test_game(entry_engine, [
		["suncity_s01_0209", TEST_FILLER_CARD_ID],
		["asgard_s01_0301", "asgard_s01_0301", "asgard_s01_0301", "asgard_s01_0301", "asgard_s01_0301"]
	], 72073, _formal_options(2, 8, 8))
	var nefertiti_id = _find_hand_card_by_definition(entry_state, 0, "suncity_s01_0209")
	_expect(not nefertiti_id.is_empty(), "太阳城：纳芙蒂蒂条件测试初始化失败（未抽到本体）", failures)
	if nefertiti_id.is_empty():
		return
	var enemy_hand_before = entry_state.get_player(1).hand.cards.size()
	var play = entry_engine.apply_command(entry_state, GameCommand.create(0, "PlayCard", {
		"card_id": nefertiti_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：纳芙蒂蒂条件测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(entry_engine, entry_state)
	_expect(not _has_pending_choice(entry_state, "discard_from_hand"), "太阳城：纳芙蒂蒂在对方手牌低于6张时不应触发弃牌", failures)
	_expect(entry_state.get_player(1).hand.cards.size() == enemy_hand_before, "太阳城：纳芙蒂蒂在对方手牌低于6张时不应令对方弃牌", failures)

	var death_engine := GameEngine.new()
	var death_state = _create_suncity_test_game(death_engine, [
		["suncity_s01_0209", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID]
	], 72074, _formal_options(3, 8, 8))
	var death_nefertiti_id = _find_hand_card_by_definition(death_state, 0, "suncity_s01_0209")
	var enemy_setup_id = _find_hand_card_by_definition(death_state, 1, TEST_FILLER_CARD_ID)
	_expect(not death_nefertiti_id.is_empty() and not enemy_setup_id.is_empty(), "太阳城：纳芙蒂蒂阵亡条件测试初始化失败", failures)
	if death_nefertiti_id.is_empty() or enemy_setup_id.is_empty():
		return
	death_engine._deploy_hand_card_to_slot(death_state, 1, enemy_setup_id, "front", 0, "test_nefertiti_gate_enemy_setup")
	var death_play = death_engine.apply_command(death_state, GameCommand.create(0, "PlayCard", {
		"card_id": death_nefertiti_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(death_play.get("ok", false)), "太阳城：纳芙蒂蒂阵亡条件测试打出失败", failures)
	if not bool(death_play.get("ok", false)):
		return
	_expect(death_state.get_player(0).hand.cards.size() >= death_state.get_player(1).hand.cards.size(), "太阳城：纳芙蒂蒂阵亡条件测试前提失败（我方手牌仍少于对方）", failures)
	death_state.get_player(0).master_hp = 7
	var own_hp_before = int(death_state.get_player(0).master_hp)
	var enemy_hp_before = int(death_state.get_player(1).master_hp)
	var destroy_events = death_engine._destroy_target_unit(death_state, {
		"targets": {"target_card_id": death_nefertiti_id},
		"resolution": {}
	}, "test_nefertiti_gate_death")
	death_engine.drain_until_waiting_for_input(death_state, destroy_events, "test_nefertiti_gate_death")
	_pass_stack_pair(death_engine, death_state)
	_expect(int(death_state.get_player(1).master_hp) == enemy_hp_before, "太阳城：纳芙蒂蒂在我方手牌不少于对方时阵亡不应造成伤害", failures)
	_expect(int(death_state.get_player(0).master_hp) == own_hp_before, "太阳城：纳芙蒂蒂在我方手牌不少于对方时阵亡不应回复生命", failures)


static func _test_nitocris_entry_and_death(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0210", "suncity_s01_0212", "suncity_s02_0201", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 7212, _formal_options(2, 6, 6))
	var nitocris_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0210")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	var beetle_id = _find_grave_card_by_definition(state, 0, "suncity_s02_0201")
	_expect(not nitocris_id.is_empty() and not tomb_guard_id.is_empty() and not beetle_id.is_empty(), "太阳城：尼托克丽丝测试初始化失败", failures)
	if nitocris_id.is_empty() or tomb_guard_id.is_empty() or beetle_id.is_empty():
		return
	engine._revive_grave_card_to_first_slot(state, 0, tomb_guard_id, "test_nitocris_tomb_guard_setup")
	var tomb_guard_instance = state.card_instances.get(tomb_guard_id)
	if tomb_guard_instance != null:
		tomb_guard_instance.orientation = "rested"
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": nitocris_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：尼托克丽丝打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "ready_battlefield_card", [tomb_guard_id]), "太阳城：尼托克丽丝未能选择重置陵墓守卫", failures)
	_expect(tomb_guard_instance != null and str(tomb_guard_instance.orientation) == "active", "太阳城：尼托克丽丝登场后应重置陵墓守卫", failures)
	var destroy_events = engine._destroy_target_unit(state, {
		"targets": {"target_card_id": nitocris_id},
		"resolution": {}
	}, "test_nitocris_death")
	engine.drain_until_waiting_for_input(state, destroy_events, "test_nitocris_death")
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "revive_from_grave", [beetle_id]), "太阳城：尼托克丽丝阵亡后未能选择复活目标", failures)
	_expect(_resolve_first_option_choice(engine, state, "revive_selected_grave_to_slot", "front:1"), "太阳城：尼托克丽丝阵亡后未能为复活目标选择位置", failures)
	var beetle_instance = state.card_instances.get(beetle_id)
	_expect(beetle_instance != null and str(beetle_instance.zone) == "battle_front" and str(beetle_instance.orientation) == "active", "太阳城：尼托克丽丝阵亡后应将低费太阳城军团活跃登场", failures)


static func _test_ankh_entry_and_options(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var entry_state = _create_suncity_test_game(engine, [
		["suncity_s01_0215", "suncity_s01_0212", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 7215, _formal_options(2, 6, 6))
	var ankh_id = _find_hand_card_by_definition(entry_state, 0, "suncity_s01_0215")
	var tomb_guard_id = _find_grave_card_by_definition(entry_state, 0, "suncity_s01_0212")
	_expect(not ankh_id.is_empty() and not tomb_guard_id.is_empty(), "太阳城：安卡神碑测试初始化失败", failures)
	if ankh_id.is_empty() or tomb_guard_id.is_empty():
		return
	entry_state.get_player(0).master_definition_id = "asgard_s01_03m2a"
	engine._revive_grave_card_to_first_slot(entry_state, 0, tomb_guard_id, "test_ankh_entry_setup")
	var play = engine.apply_command(entry_state, GameCommand.create(0, "PlayCard", {
		"card_id": ankh_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：安卡神碑打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, entry_state)
	_expect(_resolve_first_candidate_choice(engine, entry_state, "modify_power_until_turn_end", [tomb_guard_id]), "太阳城：安卡神碑登场未能选择陵墓守卫强化", failures)
	_expect(engine.get_card_power(entry_state, tomb_guard_id) == 4000, "太阳城：安卡神碑登场后应使陵墓守卫本回合 +2000", failures)

	var ready_engine := GameEngine.new()
	var ready_state = _create_suncity_test_game(ready_engine, [
		["suncity_s01_0215", "suncity_s01_0212", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 7216, _formal_options(2, 6, 6))
	var ready_ankh_id = _find_hand_card_by_definition(ready_state, 0, "suncity_s01_0215")
	var ready_tomb_guard_id = _find_grave_card_by_definition(ready_state, 0, "suncity_s01_0212")
	ready_state.get_player(0).master_definition_id = "asgard_s01_03m2a"
	engine = ready_engine
	engine._revive_grave_card_to_first_slot(ready_state, 0, ready_tomb_guard_id, "test_ankh_ready_setup")
	_expect(bool(engine.apply_command(ready_state, GameCommand.create(0, "PlayCard", {
		"card_id": ready_ankh_id,
		"row": "artifact",
		"col": -1
	})).get("ok", false)), "太阳城：安卡神碑转活分支打出失败", failures)
	_pass_stack_pair(engine, ready_state)
	_resolve_first_candidate_choice(engine, ready_state, "modify_power_until_turn_end", [ready_tomb_guard_id])
	var ready_tomb_guard_instance = ready_state.card_instances.get(ready_tomb_guard_id)
	if ready_tomb_guard_instance != null:
		ready_tomb_guard_instance.orientation = "rested"
	var hand_before_discard = ready_state.get_player(0).hand.cards.size()
	var activate_ready = engine.apply_command(ready_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": ready_ankh_id,
		"effect_id": "ankh_activate_mode"
	}))
	_expect(bool(activate_ready.get("ok", false)), "太阳城：安卡神碑主动效果发动失败（转活分支）", failures)
	if bool(activate_ready.get("ok", false)):
		_pass_stack_pair(engine, ready_state)
		_expect(_resolve_first_option_choice(engine, ready_state, "resolve_option_with_shared_cost", "discard_to_ready"), "太阳城：安卡神碑未能选择弃牌转活分支", failures)
		_expect(_resolve_first_candidate_choice(engine, ready_state, "ready_battlefield_card", [ready_tomb_guard_id]), "太阳城：安卡神碑未能选择转活目标", failures)
		_expect(ready_tomb_guard_instance != null and str(ready_tomb_guard_instance.orientation) == "active", "太阳城：安卡神碑弃牌分支应将陵墓守卫转为活跃", failures)
		_expect(ready_state.get_player(0).hand.cards.size() == hand_before_discard - 1, "太阳城：安卡神碑弃牌分支应弃置1张手牌", failures)

	var draw_engine := GameEngine.new()
	var draw_state = _create_suncity_test_game(draw_engine, [
		["suncity_s01_0215", "suncity_s01_0212", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 7217, _formal_options(2, 6, 6))
	var draw_ankh_id = _find_hand_card_by_definition(draw_state, 0, "suncity_s01_0215")
	var draw_tomb_guard_id = _find_grave_card_by_definition(draw_state, 0, "suncity_s01_0212")
	draw_state.get_player(0).master_definition_id = "asgard_s01_03m2a"
	draw_engine._revive_grave_card_to_first_slot(draw_state, 0, draw_tomb_guard_id, "test_ankh_draw_setup")
	_expect(bool(draw_engine.apply_command(draw_state, GameCommand.create(0, "PlayCard", {
		"card_id": draw_ankh_id,
		"row": "artifact",
		"col": -1
	})).get("ok", false)), "太阳城：安卡神碑抽牌分支打出失败", failures)
	_pass_stack_pair(draw_engine, draw_state)
	_resolve_first_candidate_choice(draw_engine, draw_state, "modify_power_until_turn_end", [draw_tomb_guard_id])
	var hand_before_draw = draw_state.get_player(0).hand.cards.size()
	var activate_draw = draw_engine.apply_command(draw_state, GameCommand.create(0, "ActivateEffect", {
		"source_id": draw_ankh_id,
		"effect_id": "ankh_activate_mode"
	}))
	_expect(bool(activate_draw.get("ok", false)), "太阳城：安卡神碑主动效果发动失败（抽牌分支）", failures)
	if bool(activate_draw.get("ok", false)):
		_pass_stack_pair(draw_engine, draw_state)
		_expect(_resolve_first_option_choice(draw_engine, draw_state, "resolve_option_with_shared_cost", "rest_to_draw"), "太阳城：安卡神碑未能选择休整抽牌分支", failures)
		_expect(_resolve_first_candidate_choice(draw_engine, draw_state, "suncity_ankh_rest_tomb_guard_draw", [draw_tomb_guard_id]), "太阳城：安卡神碑未能选择休整目标", failures)
		var draw_tomb_guard_instance = draw_state.card_instances.get(draw_tomb_guard_id)
		_expect(draw_tomb_guard_instance != null and str(draw_tomb_guard_instance.orientation) == "rested", "太阳城：安卡神碑抽牌分支应将陵墓守卫转为休整", failures)
		_expect(draw_state.get_player(0).hand.cards.size() == hand_before_draw + 1, "太阳城：安卡神碑抽牌分支应抽取1张牌", failures)


static func _test_duat_gate_modes(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var destroy_state = _create_suncity_test_game(engine, [
		["suncity_s01_0221"],
		["suncity_s02_0204"]
	], 7213, _formal_options(1, 6, 6))
	var duat_gate_id = _find_hand_card_by_definition(destroy_state, 0, "suncity_s01_0221")
	var enemy_id = _find_hand_card_by_definition(destroy_state, 1, "suncity_s02_0204")
	_expect(not duat_gate_id.is_empty() and not enemy_id.is_empty(), "太阳城：杜阿特之门击杀模式测试初始化失败", failures)
	if duat_gate_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(destroy_state, 1, enemy_id, "front", 0, "test_duat_gate_enemy_setup")
	var destroy_play = engine.apply_command(destroy_state, GameCommand.create(0, "PlayCard", {
		"card_id": duat_gate_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(destroy_play.get("ok", false)), "太阳城：杜阿特之门打出失败", failures)
	if not bool(destroy_play.get("ok", false)):
		return
	_pass_stack_pair(engine, destroy_state)
	_expect(_resolve_first_option_choice(engine, destroy_state, "resolve_option_with_shared_cost", "destroy_enemy_unit"), "太阳城：杜阿特之门未能选择击杀模式", failures)
	_expect(_resolve_first_candidate_choice(engine, destroy_state, "destroy_battlefield_card", [enemy_id]), "太阳城：杜阿特之门未能选择要击杀的敌军", failures)
	_expect(destroy_state.get_player(1).grave.cards.has(enemy_id), "太阳城：杜阿特之门击杀模式应将目标送入墓地", failures)
	var recover_engine := GameEngine.new()
	var recover_state = _create_suncity_test_game(recover_engine, [
		["suncity_s01_0221", "suncity_s02_0203"],
		[]
	], 7214, _formal_options(2, 6, 6))
	var recover_gate_id = _find_hand_card_by_definition(recover_state, 0, "suncity_s01_0221")
	var recover_card_id = _find_hand_card_by_definition(recover_state, 0, "suncity_s02_0203")
	_expect(not recover_gate_id.is_empty() and not recover_card_id.is_empty(), "太阳城：杜阿特之门回收模式测试初始化失败", failures)
	if recover_gate_id.is_empty() or recover_card_id.is_empty():
		return
	recover_state.get_player(0).hand.remove_card(recover_card_id)
	recover_state.get_player(0).grave.add_card_to_top(recover_card_id)
	recover_state.card_instances[recover_card_id].zone = "grave"
	recover_state.card_instances[recover_card_id].position = {}
	var recover_result = recover_engine.apply_command(recover_state, GameCommand.create(0, "PlayCard", {
		"card_id": recover_gate_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(recover_result.get("ok", false)), "太阳城：杜阿特之门回收模式打出失败", failures)
	if not bool(recover_result.get("ok", false)):
		return
	_pass_stack_pair(recover_engine, recover_state)
	_expect(_resolve_first_option_choice(recover_engine, recover_state, "resolve_option_with_shared_cost", "recover_suncity_card"), "太阳城：杜阿特之门未能选择回收模式", failures)
	_expect(_resolve_first_candidate_choice(recover_engine, recover_state, "return_grave_to_hand", [recover_card_id]), "太阳城：杜阿特之门未能选择回收目标", failures)
	_expect(recover_state.get_player(0).hand.cards.has(recover_card_id), "太阳城：杜阿特之门回收模式应将墓地太阳城卡加入手牌", failures)


static func _test_duat_gate_without_valid_targets(failures: Array[String]) -> void:
	var destroy_engine := GameEngine.new()
	var destroy_state = _create_suncity_test_game(destroy_engine, [
		["suncity_s01_0221"],
		["suncity_s02_0202"]
	], 72141, _formal_options(1, 8, 8))
	var destroy_gate_id = _find_hand_card_by_definition(destroy_state, 0, "suncity_s01_0221")
	var big_enemy_id = _find_hand_card_by_definition(destroy_state, 1, "suncity_s02_0202")
	_expect(not destroy_gate_id.is_empty() and not big_enemy_id.is_empty(), "太阳城：杜阿特之门无击杀目标测试初始化失败", failures)
	if destroy_gate_id.is_empty() or big_enemy_id.is_empty():
		return
	destroy_engine._deploy_hand_card_to_slot(destroy_state, 1, big_enemy_id, "front", 0, "test_duat_gate_big_enemy_setup")
	var destroy_play = destroy_engine.apply_command(destroy_state, GameCommand.create(0, "PlayCard", {
		"card_id": destroy_gate_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(destroy_play.get("ok", false)), "太阳城：杜阿特之门无击杀目标测试打出失败", failures)
	if not bool(destroy_play.get("ok", false)):
		return
	_pass_stack_pair(destroy_engine, destroy_state)
	_expect(_resolve_first_option_choice(destroy_engine, destroy_state, "resolve_option_with_shared_cost", "destroy_enemy_unit"), "太阳城：杜阿特之门无击杀目标测试未能选择击杀模式", failures)
	_expect(not _has_pending_choice(destroy_state, "destroy_battlefield_card"), "太阳城：杜阿特之门在无合法击杀目标时不应弹出选敌军", failures)
	_expect(not destroy_state.get_player(1).grave.cards.has(big_enemy_id), "太阳城：杜阿特之门在无合法击杀目标时不应错误击杀敌军", failures)
	_expect(destroy_state.pending_choices.is_empty() and destroy_state.stack.is_empty(), "太阳城：杜阿特之门无击杀目标时结算后不应残留选择或堆栈", failures)

	var recover_engine := GameEngine.new()
	var recover_state = _create_suncity_test_game(recover_engine, [
		["suncity_s01_0221", TEST_FILLER_CARD_ID],
		[]
	], 72142, _formal_options(2, 8, 8))
	var recover_gate_id = _find_hand_card_by_definition(recover_state, 0, "suncity_s01_0221")
	_expect(not recover_gate_id.is_empty(), "太阳城：杜阿特之门无回收目标测试初始化失败", failures)
	if recover_gate_id.is_empty():
		return
	var hand_before = recover_state.get_player(0).hand.cards.size()
	var grave_before = recover_state.get_player(0).grave.cards.size()
	var recover_play = recover_engine.apply_command(recover_state, GameCommand.create(0, "PlayCard", {
		"card_id": recover_gate_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(recover_play.get("ok", false)), "太阳城：杜阿特之门无回收目标测试打出失败", failures)
	if not bool(recover_play.get("ok", false)):
		return
	_pass_stack_pair(recover_engine, recover_state)
	_expect(_resolve_first_option_choice(recover_engine, recover_state, "resolve_option_with_shared_cost", "recover_suncity_card"), "太阳城：杜阿特之门无回收目标测试未能选择回收模式", failures)
	_expect(not _has_pending_choice(recover_state, "return_grave_to_hand"), "太阳城：杜阿特之门在墓地无合法太阳城卡时不应弹出回收选择", failures)
	_expect(recover_state.get_player(0).hand.cards.size() == hand_before - 1, "太阳城：杜阿特之门在无回收目标时不应额外加入手牌", failures)
	_expect(recover_state.get_player(0).grave.cards.size() == grave_before + 1 and recover_state.get_player(0).grave.cards.has(recover_gate_id), "太阳城：杜阿特之门在无回收目标时应仅自身进入墓地", failures)
	_expect(recover_state.pending_choices.is_empty() and recover_state.stack.is_empty(), "太阳城：杜阿特之门无回收目标时结算后不应残留选择或堆栈", failures)


static func _test_pharaoh_celebration_pick_and_reorder(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0222", "suncity_s01_0208", "suncity_s01_0215", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 7218, _formal_options(1, 6, 6))
	var celebration_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0222")
	_expect(not celebration_id.is_empty(), "太阳城：法老王的庆典测试初始化失败", failures)
	if celebration_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": celebration_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：法老王的庆典打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var ai_id = str(state.get_player(0).deck.cards[0])
	var ankh_id = str(state.get_player(0).deck.cards[1])
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_pharaoh_pick_cards", [ai_id, ankh_id]), "太阳城：法老王的庆典未能选择2张太阳城卡", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_pharaoh_pick_to_hand", [ai_id]), "太阳城：法老王的庆典未能选择加入手牌的卡", failures)
	_resolve_all_bottom_reorder_choices(engine, state)
	_expect(state.get_player(0).hand.cards.has(ai_id), "太阳城：法老王的庆典应将所选卡加入手牌", failures)
	_expect(state.get_player(0).grave.cards.has(ankh_id), "太阳城：法老王的庆典应将另一张所选卡置入墓地", failures)
	var deck_cards = state.get_player(0).deck.cards
	var bottom_card_id = str(deck_cards[deck_cards.size() - 1]) if deck_cards.size() >= 3 else ""
	var bottom_instance = state.card_instances.get(bottom_card_id)
	_expect(deck_cards.size() >= 3 and bottom_instance != null and str(bottom_instance.definition_id) == TEST_FILLER_CARD_ID, "太阳城：法老王的庆典其余卡应回到牌库底部", failures)


static func _test_pharaoh_celebration_without_targets_only_reorders(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0222", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 72181, _formal_options(1, 6, 6))
	var celebration_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0222")
	_expect(not celebration_id.is_empty(), "太阳城：法老王的庆典负向测试初始化失败", failures)
	if celebration_id.is_empty():
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var grave_before = state.get_player(0).grave.cards.size()
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": celebration_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：法老王的庆典负向测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(not _has_pending_choice(state, "suncity_pharaoh_pick_cards"), "太阳城：法老王的庆典在顶部没有可选太阳城卡时不应弹出选牌", failures)
	_resolve_all_bottom_reorder_choices(engine, state)
	_expect(state.pending_choices.is_empty() and state.stack.is_empty(), "太阳城：法老王的庆典在无目标时结算后不应残留选择或堆栈", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before - 1, "太阳城：法老王的庆典在无目标时不应额外加入手牌", failures)
	_expect(state.get_player(0).grave.cards.size() == grave_before + 1 and state.get_player(0).grave.cards.has(celebration_id), "太阳城：法老王的庆典在无目标时应仅自身进入墓地", failures)
	var deck_cards = state.get_player(0).deck.cards
	_expect(deck_cards.size() >= 5, "太阳城：法老王的庆典无目标时其余查看牌应回到底部", failures)
	for index in range(max(0, deck_cards.size() - 5), deck_cards.size()):
		var instance = state.card_instances.get(str(deck_cards[index]))
		_expect(instance != null and str(instance.definition_id) == TEST_FILLER_CARD_ID, "太阳城：法老王的庆典无目标时查看过的其余卡应回到底部", failures)


static func _test_immortal_gift_triggers_on_attack_and_effect(failures: Array[String]) -> void:
	var attack_engine := GameEngine.new()
	var attack_state = _create_suncity_test_game(attack_engine, [
		["suncity_s01_0223", "suncity_s02_0203", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		["suncity_s01_0201"]
	], 7219, _formal_options(2, 6, 6))
	var attack_gift_id = _find_hand_card_by_definition(attack_state, 0, "suncity_s01_0223")
	var attack_ally_id = _find_hand_card_by_definition(attack_state, 0, "suncity_s02_0203")
	var attack_enemy_id = _find_hand_card_by_definition(attack_state, 1, "suncity_s01_0201")
	_expect(not attack_gift_id.is_empty() and not attack_ally_id.is_empty() and not attack_enemy_id.is_empty(), "太阳城：不朽之礼进攻触发测试初始化失败", failures)
	if attack_gift_id.is_empty() or attack_ally_id.is_empty() or attack_enemy_id.is_empty():
		return
	var set_attack = attack_engine.apply_command(attack_state, GameCommand.create(0, "PlayCard", {
		"card_id": attack_gift_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(set_attack.get("ok", false)), "太阳城：不朽之礼进攻触发测试盖放失败", failures)
	if not bool(set_attack.get("ok", false)):
		return
	attack_engine._deploy_hand_card_to_slot(attack_state, 0, attack_ally_id, "front", 0, "test_immortal_gift_attack_ally")
	attack_engine._deploy_hand_card_to_slot(attack_state, 1, attack_enemy_id, "front", 0, "test_immortal_gift_attack_enemy")
	var attack_events = ZoneActions.move_battlefield_to_grave(attack_state, 0, "front", 0, "test_immortal_gift_attack_death", {
		"source_card_id": attack_enemy_id,
		"source_kind": "attack"
	})
	attack_engine.drain_until_waiting_for_input(attack_state, attack_events, "test_immortal_gift_attack_drain")
	_pass_stack_pair(attack_engine, attack_state)
	_decline_optional_stack_effect_if_present(attack_engine, attack_state)
	_pass_stack_pair(attack_engine, attack_state)
	_expect(attack_state.get_player(0).hand.cards.size() == 1, "太阳城：不朽之礼应在我方高费军团被进攻击杀后抽1张牌", failures)
	var attack_tomb_guard_id = _find_grave_card_by_definition(attack_state, 0, "suncity_s01_0212")
	_expect(not attack_tomb_guard_id.is_empty(), "太阳城：不朽之礼进攻触发后墓地中应存在陵墓守卫供复活", failures)
	if not attack_tomb_guard_id.is_empty():
		_expect(_resolve_first_candidate_choice(attack_engine, attack_state, "revive_from_grave", [attack_tomb_guard_id]), "太阳城：不朽之礼进攻触发后未能选择复活目标", failures)
		_expect(_resolve_first_option_choice(attack_engine, attack_state, "revive_selected_grave_to_slot", "front:0"), "太阳城：不朽之礼进攻触发后未能为复活目标选择位置", failures)
	_expect(_count_battlefield_definition(attack_state, 0, "suncity_s01_0212") >= 1, "太阳城：不朽之礼进攻触发后应可复活陵墓守卫", failures)

	var effect_engine := GameEngine.new()
	var effect_state = _create_suncity_test_game(effect_engine, [
		["suncity_s01_0223", "suncity_s02_0203", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		["suncity_s01_0201"]
	], 7220, _formal_options(2, 6, 6))
	var effect_gift_id = _find_hand_card_by_definition(effect_state, 0, "suncity_s01_0223")
	var effect_ally_id = _find_hand_card_by_definition(effect_state, 0, "suncity_s02_0203")
	var effect_enemy_id = _find_hand_card_by_definition(effect_state, 1, "suncity_s01_0201")
	_expect(not effect_gift_id.is_empty() and not effect_ally_id.is_empty() and not effect_enemy_id.is_empty(), "太阳城：不朽之礼效果触发测试初始化失败", failures)
	if effect_gift_id.is_empty() or effect_ally_id.is_empty() or effect_enemy_id.is_empty():
		return
	var set_effect = effect_engine.apply_command(effect_state, GameCommand.create(0, "PlayCard", {
		"card_id": effect_gift_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(set_effect.get("ok", false)), "太阳城：不朽之礼效果触发测试盖放失败", failures)
	if not bool(set_effect.get("ok", false)):
		return
	effect_engine._deploy_hand_card_to_slot(effect_state, 0, effect_ally_id, "front", 0, "test_immortal_gift_effect_ally")
	effect_engine._deploy_hand_card_to_slot(effect_state, 1, effect_enemy_id, "front", 0, "test_immortal_gift_effect_enemy")
	var effect_events = ZoneActions.move_battlefield_to_grave(effect_state, 0, "front", 0, "test_immortal_gift_effect_death", {
		"source_card_id": effect_enemy_id,
		"source_kind": "effect"
	})
	effect_engine.drain_until_waiting_for_input(effect_state, effect_events, "test_immortal_gift_effect_drain")
	_pass_stack_pair(effect_engine, effect_state)
	_decline_optional_stack_effect_if_present(effect_engine, effect_state)
	_pass_stack_pair(effect_engine, effect_state)
	_expect(effect_state.get_player(0).hand.cards.size() == 1, "太阳城：不朽之礼应在对方效果造成我方高费军团离场后抽1张牌", failures)
	var effect_tomb_guard_id = _find_grave_card_by_definition(effect_state, 0, "suncity_s01_0212")
	_expect(not effect_tomb_guard_id.is_empty(), "太阳城：不朽之礼效果触发后墓地中应存在陵墓守卫供复活", failures)
	if not effect_tomb_guard_id.is_empty():
		_expect(_resolve_first_candidate_choice(effect_engine, effect_state, "revive_from_grave", [effect_tomb_guard_id]), "太阳城：不朽之礼效果触发后未能选择复活目标", failures)
		_expect(_resolve_first_option_choice(effect_engine, effect_state, "revive_selected_grave_to_slot", "front:0"), "太阳城：不朽之礼效果触发后未能为复活目标选择位置", failures)
	_expect(_count_battlefield_definition(effect_state, 0, "suncity_s01_0212") >= 1, "太阳城：不朽之礼效果触发后应可复活陵墓守卫", failures)


static func _test_immortal_gift_ignores_low_cost_legion(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0223", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		["suncity_s01_0201"]
	], 72252, _formal_options(2, 6, 6))
	var gift_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0223")
	var low_cost_ally_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0212")
	if low_cost_ally_id.is_empty():
		low_cost_ally_id = _find_deck_card_by_definition(state, 0, "suncity_s01_0212")
	if low_cost_ally_id.is_empty():
		low_cost_ally_id = _find_owned_card_by_definition(state, 0, "suncity_s01_0212")
	var enemy_id = _find_hand_card_by_definition(state, 1, "suncity_s01_0201")
	_expect(not gift_id.is_empty() and not low_cost_ally_id.is_empty() and not enemy_id.is_empty(), "太阳城：不朽之礼低费负向测试初始化失败", failures)
	if gift_id.is_empty() or low_cost_ally_id.is_empty() or enemy_id.is_empty():
		return
	var set_gift = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": gift_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(set_gift.get("ok", false)), "太阳城：不朽之礼低费负向测试盖放失败", failures)
	if not bool(set_gift.get("ok", false)):
		return
	state.get_player(0).hand.remove_card(low_cost_ally_id)
	state.get_player(0).deck.remove_card(low_cost_ally_id)
	state.get_player(0).grave.remove_card(low_cost_ally_id)
	state.card_instances[low_cost_ally_id].zone = "hand"
	state.card_instances[low_cost_ally_id].position = {}
	state.get_player(0).hand.add_card_to_top(low_cost_ally_id)
	engine._deploy_hand_card_to_slot(state, 0, low_cost_ally_id, "front", 0, "test_immortal_gift_low_cost_ally")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_immortal_gift_low_cost_enemy")
	var hand_before = state.get_player(0).hand.cards.size()
	var death_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_immortal_gift_low_cost_death", {
		"source_card_id": enemy_id,
		"source_kind": "attack"
	})
	engine.drain_until_waiting_for_input(state, death_events, "test_immortal_gift_low_cost_drain")
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "太阳城：不朽之礼在低费军团离场时不应抽牌", failures)
	_expect(not _has_pending_choice(state, "revive_from_grave"), "太阳城：不朽之礼在低费军团离场时不应弹出复活选择", failures)
	_expect(state.stack.is_empty(), "太阳城：不朽之礼在低费军团离场时不应残留触发堆栈", failures)


static func _test_ptolemy_repeats_last_active_tactic(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0219", "suncity_s01_0222", "suncity_s01_0211", "suncity_s01_0208", "suncity_s01_0215", "suncity_s02_0203", "suncity_s02_0204", TEST_FILLER_CARD_ID],
		[]
	], 7225, _formal_options(3, 8, 8))
	var canopic_three_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0219")
	var celebration_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0222")
	var ptolemy_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0211")
	_expect(not canopic_three_id.is_empty() and not celebration_id.is_empty() and not ptolemy_id.is_empty(), "太阳城：托勒密十三世测试初始化失败", failures)
	if canopic_three_id.is_empty() or celebration_id.is_empty() or ptolemy_id.is_empty():
		return
	var play_canopic = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_three_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play_canopic.get("ok", false)), "太阳城：托勒密十三世前置临时士气来源打出失败", failures)
	if not bool(play_canopic.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var ai_id = str(state.get_player(0).deck.cards[0])
	var ankh_id = str(state.get_player(0).deck.cards[1])
	var hatshepsut_id = str(state.get_player(0).deck.cards[2])
	var imhotep_id = str(state.get_player(0).deck.cards[3])
	var play_celebration = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": celebration_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play_celebration.get("ok", false)), "太阳城：托勒密十三世前置战术打出失败", failures)
	if not bool(play_celebration.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_pharaoh_pick_cards", [ai_id, ankh_id]), "太阳城：托勒密十三世前置战术未能选择法老王的庆典目标", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_pharaoh_pick_to_hand", [ai_id]), "太阳城：托勒密十三世前置战术未能选择加入手牌的卡", failures)
	_resolve_all_bottom_reorder_choices(engine, state)
	_drain_stack_until_idle(engine, state)
	_expect(state.pending_choices.is_empty() and state.stack.is_empty(), "太阳城：托勒密十三世前置战术结算后不应残留未处理的选择或堆栈", failures)
	var play_ptolemy = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ptolemy_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play_ptolemy.get("ok", false)), "太阳城：托勒密十三世打出失败", failures)
	if not bool(play_ptolemy.get("ok", false)):
		return
	_drain_stack_until_idle(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_pharaoh_pick_cards", [hatshepsut_id, imhotep_id]), "太阳城：托勒密十三世未能再次发动上1张主动战术效果", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_pharaoh_pick_to_hand", [hatshepsut_id]), "太阳城：托勒密十三世重发动战术后未能选择加入手牌的卡", failures)
	_resolve_all_bottom_reorder_choices(engine, state)
	_expect(state.get_player(0).hand.cards.has(hatshepsut_id), "太阳城：托勒密十三世登场后应再次发动上1张主动战术并将所选卡加入手牌", failures)
	_expect(state.get_player(0).grave.cards.has(imhotep_id), "太阳城：托勒密十三世重发动法老王的庆典后应将另一张所选卡置入墓地", failures)


static func _test_ptolemy_requires_last_active_tactic(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0211", "suncity_s01_0219", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		[]
	], 72251, _formal_options(2, 8, 8))
	var ptolemy_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0211")
	var canopic_three_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0219")
	_expect(not ptolemy_id.is_empty() and not canopic_three_id.is_empty(), "太阳城：托勒密十三世负向测试初始化失败", failures)
	if ptolemy_id.is_empty() or canopic_three_id.is_empty():
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var grave_before = state.get_player(0).grave.cards.size()
	var temporary_morale_before = int(state.get_player(0).flags.get("temporary_morale_count", 0))
	var play_artifact = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_three_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play_artifact.get("ok", false)), "太阳城：托勒密十三世负向测试前置圣物打出失败", failures)
	if not bool(play_artifact.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).flags.get("temporary_morale_count", 0)) == temporary_morale_before + 2, "太阳城：托勒密十三世负向测试前置圣物应正常提供临时士气", failures)
	var play_ptolemy = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ptolemy_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play_ptolemy.get("ok", false)), "太阳城：托勒密十三世负向测试打出失败", failures)
	if not bool(play_ptolemy.get("ok", false)):
		return
	_drain_stack_until_idle(engine, state)
	_expect(state.pending_choices.is_empty() and state.stack.is_empty(), "太阳城：托勒密十三世在本回合没有主动战术时不应产生额外选择或堆栈", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before - 2, "太阳城：托勒密十三世在未满足条件时不应额外获得手牌资源", failures)
	_expect(state.get_player(0).grave.cards.size() == grave_before + 1, "太阳城：托勒密十三世负向测试中仅前置圣物应进入墓地", failures)


static func _test_imhotep_entry_and_discount(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s02_0204", "suncity_s02_0202", TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID]
	], 7221, _formal_options(2, 8, 8))
	var imhotep_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0204")
	var paladin_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0202")
	_expect(not imhotep_id.is_empty() and not paladin_id.is_empty(), "太阳城：伊姆何泰普测试初始化失败", failures)
	if imhotep_id.is_empty() or paladin_id.is_empty():
		return
	state.get_player(0).hand.remove_card(paladin_id)
	state.get_player(0).grave.add_card_to_top(paladin_id)
	state.card_instances[paladin_id].zone = "grave"
	state.card_instances[paladin_id].position = {}
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": imhotep_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：伊姆何泰普打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_optional_stack_effect(engine, state, true), "太阳城：伊姆何泰普进场后应可选择回收高费太阳城军团", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "return_grave_to_hand", [paladin_id]), "太阳城：伊姆何泰普未能选择回手目标", failures)
	_expect(state.get_player(0).hand.cards.has(paladin_id), "太阳城：伊姆何泰普进场后应将高费太阳城军团加入手牌", failures)
	_expect(engine._get_effective_play_cost(state, paladin_id) == 6, "太阳城：伊姆何泰普发动前不应预先减免天灾军团费用", failures)
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": imhotep_id,
		"effect_id": "imhotep_rest_prepare_discount"
	}))
	_expect(bool(activate.get("ok", false)), "太阳城：伊姆何泰普主动休整效果发动失败", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var pending_discount = state.get_player(0).flags.get("suncity_next_calamity_discount", {})
	_expect(pending_discount is Dictionary and int(pending_discount.get("amount", 0)) == -1, "太阳城：伊姆何泰普主动休整后应记录下张天灾军团费用-1", failures)
	_expect(engine._get_effective_play_cost(state, paladin_id) == 5, "太阳城：伊姆何泰普主动休整后应使下张天灾军团费用-1", failures)
	var play_paladin = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": paladin_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(play_paladin.get("ok", false)), "太阳城：伊姆何泰普减费后应能打出天灾军团", failures)
	_expect(not state.get_player(0).flags.has("suncity_next_calamity_discount"), "太阳城：伊姆何泰普减费效果在打出天灾军团后应被消耗", failures)


static func _test_desert_sovereignty_deploys_matching_calamity(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s02_0207", "suncity_s02_0203", "suncity_s02_0204", "suncity_s02_0202", TEST_FILLER_CARD_ID],
		[]
	], 7222, _formal_options(4, 8, 8))
	var desert_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0207")
	var unit_a_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	var unit_b_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0204")
	var paladin_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0202")
	_expect(not desert_id.is_empty() and not unit_a_id.is_empty() and not unit_b_id.is_empty() and not paladin_id.is_empty(), "太阳城：沙漠君临测试初始化失败", failures)
	if desert_id.is_empty() or unit_a_id.is_empty() or unit_b_id.is_empty() or paladin_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, unit_a_id, "front", 0, "test_desert_sovereignty_setup_a")
	engine._deploy_hand_card_to_slot(state, 0, unit_b_id, "front", 1, "test_desert_sovereignty_setup_b")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": desert_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "太阳城：沙漠君临打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "suncity_desert_discard_count", "2"), "太阳城：沙漠君临未能选择弃置数量", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "suncity_desert_discard_units", [unit_a_id, unit_b_id]), "太阳城：沙漠君临未能选择要弃置的军团", failures)
	_expect(state.get_player(0).grave.cards.has(unit_a_id) and state.get_player(0).grave.cards.has(unit_b_id), "太阳城：沙漠君临应先弃置所选我方军团", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [paladin_id]), "太阳城：沙漠君临未能选择同天灾等级的手牌军团登场", failures)
	_expect(_resolve_first_option_choice(engine, state, "deploy_selected_hand_to_slot", "front:0"), "太阳城：沙漠君临未能为登场军团选择位置", failures)
	var paladin_instance = state.card_instances.get(paladin_id)
	_expect(paladin_instance != null and str(paladin_instance.zone) == "battle_front" and str(paladin_instance.orientation) == "active", "太阳城：沙漠君临应将匹配天灾等级的太阳城军团活跃登场", failures)
	_expect(not state.get_player(0).hand.cards.has(paladin_id), "太阳城：沙漠君临结算后登场目标不应继续留在手牌", failures)


static func _test_thutmose_entry_and_crush(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s01_0201"],
		["suncity_s02_0203", "suncity_s02_0204"]
	], 7209, _formal_options(2, 8, 8))
	var thutmose_id = _find_hand_card_by_definition(state, 0, "suncity_s01_0201")
	var enemy_a = _find_hand_card_by_definition(state, 1, "suncity_s02_0203")
	var enemy_b = _find_hand_card_by_definition(state, 1, "suncity_s02_0204")
	_expect(not thutmose_id.is_empty() and not enemy_a.is_empty() and not enemy_b.is_empty(), "太阳城：图特摩斯三世测试初始化失败", failures)
	if thutmose_id.is_empty() or enemy_a.is_empty() or enemy_b.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_a, "front", 0, "test_thutmose_enemy_a")
	engine._deploy_hand_card_to_slot(state, 1, enemy_b, "front", 1, "test_thutmose_enemy_b")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": thutmose_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "太阳城：图特摩斯三世打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "destroy_battlefield_cards", [enemy_a]), "太阳城：图特摩斯三世未能选择登场击杀目标", failures)
	var thutmose_instance = state.card_instances.get(thutmose_id)
	_expect(thutmose_instance != null and int(thutmose_instance.flags.get("suncity_ignore_counter_tactics_turn", -1)) == int(state.turn_number), "太阳城：图特摩斯三世登场回合应获得免反击标记", failures)
	_expect(state.get_player(1).grave.cards.has(enemy_a), "太阳城：图特摩斯三世登场时应击杀选中的敌军", failures)
	_pass_stack_pair(engine, state)
	_decline_optional_stack_effect_if_present(engine, state)
	if thutmose_instance != null:
		thutmose_instance.entered_turn = -1
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": thutmose_id,
		"target_kind": "card",
		"defender_id": enemy_b
	}))
	_expect(bool(attack.get("ok", false)), "太阳城：图特摩斯三世宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(1).grave.cards.has(enemy_b), "太阳城：图特摩斯三世进攻压场后应击杀兵力降至1000的敌军", failures)


static func _test_suncity_cost_rules_use_correct_definition_ids(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_suncity_test_game(engine, [
		["suncity_s02_0203", "suncity_s02_0202", "suncity_s01_0212"],
		[]
	], 7202, _formal_options(2, 6, 6))
	var hatshepsut_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0203")
	var paladin_id = _find_hand_card_by_definition(state, 0, "suncity_s02_0202")
	var tomb_guard_id = _find_grave_card_by_definition(state, 0, "suncity_s01_0212")
	_expect(not hatshepsut_id.is_empty() and not paladin_id.is_empty(), "太阳城：费用测试初始化失败（缺少目标手牌）", failures)
	if hatshepsut_id.is_empty() or paladin_id.is_empty():
		return
	_expect(engine._get_effective_play_cost(state, hatshepsut_id) == 2, "太阳城：哈特谢普苏特在无陵墓守卫时应费用 -1", failures)
	_expect(engine._get_effective_play_cost(state, paladin_id) == 6, "太阳城：陵墓圣武士基础费用不应错误减免", failures)
	state.get_player(0).flags["suncity_tomb_left_count"] = 2
	_expect(engine._get_effective_play_cost(state, paladin_id) == 4, "太阳城：陵墓圣武士应按本回合陵墓离场数减费", failures)
	if not tomb_guard_id.is_empty():
		engine._revive_grave_card_to_first_slot(state, 0, tomb_guard_id, "test_suncity_revive_tomb_guard")
		_expect(engine._get_effective_play_cost(state, hatshepsut_id) == 3, "太阳城：哈特谢普苏特在存在陵墓守卫时不应继续减费", failures)


static func _definitions_with_suncity_masters() -> Array:
	var definitions: Array = []
	definitions.append_array(CardDatabase.load_definitions("res://data/cards/suncity_batch_1.json"))
	definitions.append_array(CardDatabase.load_definitions("res://data/cards/takamagahara_asgard_batch_0.json"))
	definitions.append_array(CardDatabase.load_definitions("res://data/raw_rule_cards/starter_duel_master_cards.json"))
	definitions.append_array(CardDatabase.load_definitions("res://data/raw_rule_cards/suncity_master_cards.json"))
	return definitions


static func _masters() -> Array:
	return [
		{"name": "P0", "master_name": "伊西斯", "master_id": "suncity_s01_02m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	]


static func _formal_options(opening_hand_size: int, opening_active_player_morale: int, opening_non_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": opening_non_active_player_morale
	}


static func _create_suncity_test_game(engine: GameEngine, decks: Array, seed: int, options: Dictionary):
	var padded_decks: Array = []
	var opening_hand_size := int(options.get("opening_hand_size", 0))
	for player_deck in decks:
		var padded: Array = []
		if player_deck is Array:
			padded.append_array(player_deck)
		while padded.size() <= opening_hand_size:
			padded.append(TEST_FILLER_CARD_ID)
		padded_decks.append(padded)
	return engine.create_game(_definitions_with_suncity_masters(), padded_decks, seed, _masters(), options)


static func _find_definition(definitions: Array, definition_id: String):
	for definition in definitions:
		if definition is Dictionary and str(definition.get("id", "")) == definition_id:
			return definition
	return null


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _find_deck_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).deck.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _find_owned_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.card_instances.keys():
		var instance = state.card_instances.get(card_id)
		if instance != null and int(instance.controller) == player_id and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _find_grave_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).grave.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _find_other_hand_card_by_definition(state, player_id: int, definition_id: String, excluded_card_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		if str(card_id) == excluded_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _find_other_grave_card_by_definition(state, player_id: int, definition_id: String, excluded_card_id: String) -> String:
	for card_id in state.get_player(player_id).grave.cards:
		if str(card_id) == excluded_card_id:
			continue
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _count_battlefield_definition(state, player_id: int, definition_id: String) -> int:
	var count := 0
	for slot in state.get_player(player_id).battle_front:
		if not str(slot.occupant).is_empty():
			var instance = state.card_instances.get(str(slot.occupant))
			if instance != null and str(instance.definition_id) == definition_id:
				count += 1
	for slot in state.get_player(player_id).battle_back:
		if not str(slot.occupant).is_empty():
			var instance = state.card_instances.get(str(slot.occupant))
			if instance != null and str(instance.definition_id) == definition_id:
				count += 1
	return count


static func _find_battlefield_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for slot in state.get_player(player_id).battle_front:
		if str(slot.occupant).is_empty():
			continue
		var instance = state.card_instances.get(str(slot.occupant))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(slot.occupant)
	for slot in state.get_player(player_id).battle_back:
		if str(slot.occupant).is_empty():
			continue
		var instance = state.card_instances.get(str(slot.occupant))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(slot.occupant)
	return ""


static func _pass_stack_pair(engine: GameEngine, state) -> void:
	if state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))


static func _drain_stack_until_idle(engine: GameEngine, state, max_steps: int = 8) -> void:
	for _step in range(max_steps):
		if state.stack.is_empty() or not state.pending_choices.is_empty():
			return
		_pass_stack_pair(engine, state)


static func _resolve_first_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("id", choice.get("choice_id", ""))),
			"selected_card_ids": selected_card_ids
		})).get("ok", false))
	return false

static func _has_pending_choice(state, operation: String) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return true
	return false


static func _resolve_first_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("id", choice.get("choice_id", ""))),
			"selected_option": selected_option
		})).get("ok", false))
	return false

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	_expect(bool(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).get("ok", false)), message, failures)
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	_expect(bool(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).get("ok", false)), message, failures)

static func _resolve_pending_attack(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	_expect(bool(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).get("ok", false)), first_message, failures)
	_expect(bool(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).get("ok", false)), second_message, failures)


static func _resolve_all_bottom_reorder_choices(engine: GameEngine, state) -> void:
	while true:
		var found := false
		for choice in state.pending_choices:
			if str(choice.get("operation", "")) != "olympus_reorder_bottom_pick":
				continue
			var candidates = choice.get("candidate_card_ids", [])
			if not (candidates is Array) or candidates.is_empty():
				return
			engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
				"choice_id": str(choice.get("id", choice.get("choice_id", ""))),
				"selected_card_ids": [str(candidates[0])]
			}))
			found = true
			break
		if not found:
			return


static func _decline_optional_stack_effect_if_present(engine: GameEngine, state) -> bool:
	if state.pending_choices.is_empty():
		return false
	var choice = state.pending_choices[0]
	var operation := str(choice.get("operation", ""))
	if operation != "optional_stack_effect" and operation != "pre_stack_optional_attack_trigger":
		return false
	return _resolve_first_optional_stack_effect(engine, state, false)


static func _resolve_first_optional_stack_effect(engine: GameEngine, state, accept: bool) -> bool:
	for choice in state.pending_choices:
		var operation := str(choice.get("operation", ""))
		if operation != "optional_stack_effect" and operation != "pre_stack_optional_attack_trigger":
			continue
		return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("id", choice.get("choice_id", ""))),
			"selected_option": "yes" if accept else "no"
		})).get("ok", false))
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
