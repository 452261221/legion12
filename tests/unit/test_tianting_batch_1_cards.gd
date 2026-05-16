extends RefCounted
class_name TestTiantingBatch1Cards

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_liubei_entry_deploys_brother(failures)
	_test_sunwu_makes_next_tactic_free(failures)
	_test_sunwu_died_return_requires_low_calamity(failures)
	_test_wuzetian_freezes_rested_enemy_units(failures)
	_test_yingzheng_clears_board_and_locks_morale_gain(failures)
	_test_yingzheng_blocks_low_power_master_attack(failures)
	_test_lijing_reveals_and_deploys_top_tianting_legion(failures)
	_test_zhugeliang_adjusts_calamity_and_sets_artifact_from_top(failures)
	_test_xishi_replaces_self_and_draws(failures)
	_test_mozi_grants_cannot_die_once(failures)
	_test_shanhe_entry_and_scout_mode(failures)
	_test_guanxing_adds_active_morale(failures)
	_test_limu_triggers_on_master_refund_four(failures)
	_test_limu_entry_reveals_top_tactic_and_optional_draw(failures)
	_test_mulan_gains_charge_on_entry(failures)
	_test_mulan_died_freeze_morale_allows_choice(failures)
	_test_qiankun_yang_destroys_small_unit(failures)
	_test_qiankun_yang_optional_refund_draws(failures)
	_test_pingyang_grants_master_damage_bonus(failures)
	_test_pingyang_attack_reveal_buffs_self(failures)
	_test_zhangfei_discount_and_frontline_bonus(failures)
	_test_baiqi_adds_rested_morale(failures)
	_test_shennongding_resets_master_once_per_turn(failures)
	_test_shenmiao_buffs_frontline_power(failures)
	_test_shenmiao_optional_destroy(failures)
	_test_qinliangyu_discount_and_entry_morale(failures)
	_test_hanxin_attack_boosts_power_and_master_damage_bonus(failures)
	_test_jingke_draws_and_death_kills_small_unit(failures)
	_test_kongchengji_counters_pending_attack(failures)
	_test_qiankun_yin_buffs_allied_unit_from_top_card(failures)
	_test_guanyu_moves_and_gains_attack_power(failures)
	_test_guanyu_attack_target_cannot_be_supported(failures)
	_test_guanyu_cannot_be_blocked(failures)
	_test_yangyouji_ranged_attack_is_no_loss(failures)
	_test_lvbu_entry_destroy_and_attack_ready(failures)
	_test_lvbu_cannot_be_attacked_by_ranged(failures)
	_test_wuzetian_died_draws_and_heals(failures)
	_test_kongchengji_draws_if_no_frontline(failures)
	return failures


static func _test_liubei_entry_deploys_brother(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0105", "tianting_s01_0106"],
		[]
	], 6401, _masters(), _formal_options(2, 6, 6))
	var liubei_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0105")
	var guanyu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0106")
	_expect(not liubei_id.is_empty() and not guanyu_id.is_empty(), "刘备：测试初始化失败（未抽到刘备/关羽）", failures)
	if liubei_id.is_empty() or guanyu_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": liubei_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "刘备：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "刘备：未能确认发动登场效果", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [guanyu_id]), "刘备：未能选择关羽登场", failures)
	_expect(_resolve_first_option_choice(engine, state, "deploy_selected_hand_to_slot", "front:1"), "刘备：未能选择关羽登场位置", failures)
	_expect(str(state.get_player(0).battle_front[1].occupant) == guanyu_id, "刘备：未将关羽活跃登场到目标位置", failures)
	var guanyu_instance = state.card_instances.get(guanyu_id)
	_expect(guanyu_instance != null and str(guanyu_instance.orientation) == "active", "刘备：关羽应以活跃状态登场", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 4, "刘备：返还 1 士气后 spent_cost_area 应剩 4 张", failures)


static func _test_sunwu_makes_next_tactic_free(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0112", "tianting_s01_0119"],
		[]
	], 6402, _masters(), _formal_options(2, 2, 6))
	var sunwu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0112")
	var guanxing_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0119")
	_expect(not sunwu_id.is_empty() and not guanxing_id.is_empty(), "孙武：测试初始化失败（未抽到孙武/观星）", failures)
	if sunwu_id.is_empty() or guanxing_id.is_empty():
		return
	var play_sunwu = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sunwu_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play_sunwu.get("ok", false)), "孙武：打出失败", failures)
	if not bool(play_sunwu.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "孙武：未能确认发动免费战术效果", failures)
	var spent_before_tactic = state.get_player(0).spent_cost_area.cards.size()
	var play_tactic = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": guanxing_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play_tactic.get("ok", false)), "孙武：免费打出高费用战术失败", failures)
	if not bool(play_tactic.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).spent_cost_area.cards.size() == spent_before_tactic, "孙武：免费战术不应额外消耗士气", failures)
	_expect(not state.get_player(0).flags.has("tianting_next_tactic_free"), "孙武：免费战术标记应在打出后移除", failures)


static func _test_sunwu_died_return_requires_low_calamity(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0112", "tianting_s01_0120"],
		[]
	], 6431, _masters(), _formal_options(1, 6, 6))
	state.calamity_value = 5
	var sunwu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0112")
	_expect(not sunwu_id.is_empty(), "孙武：阵亡回收条件测试初始化失败", failures)
	if sunwu_id.is_empty():
		return
	var grave_seed_id = str(state.get_player(0).deck.cards[0])
	state.get_player(0).deck.remove_card(grave_seed_id)
	state.get_player(0).grave.add_card_to_top(grave_seed_id)
	var grave_instance = state.card_instances.get(grave_seed_id)
	if grave_instance != null:
		grave_instance.zone = "grave"
		grave_instance.position = {}
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sunwu_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "孙武：阵亡回收条件测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_sunwu_die_high_calamity")
	_pass_stack_pair(engine, state)
	var has_choice := false
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == "return_grave_to_hand":
			has_choice = true
			break
	_expect(not has_choice, "孙武：天灾值大于4时不应触发阵亡回收", failures)

	var state2 = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0112", "tianting_s01_0120"],
		[]
	], 6432, _masters(), _formal_options(1, 6, 6))
	state2.calamity_value = 4
	var sunwu_id_2 = _find_hand_card_by_definition(state2, 0, "tianting_s01_0112")
	if sunwu_id_2.is_empty():
		failures.append("孙武：阵亡回收条件测试初始化失败（第二局未抽到孙武）")
		return
	var grave_seed_id_2 = str(state2.get_player(0).deck.cards[0])
	state2.get_player(0).deck.remove_card(grave_seed_id_2)
	state2.get_player(0).grave.add_card_to_top(grave_seed_id_2)
	var grave_instance_2 = state2.card_instances.get(grave_seed_id_2)
	if grave_instance_2 != null:
		grave_instance_2.zone = "grave"
		grave_instance_2.position = {}
	var play2 = engine.apply_command(state2, GameCommand.create(0, "PlayCard", {
		"card_id": sunwu_id_2,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play2.get("ok", false)), "孙武：第二局打出失败", failures)
	if not bool(play2.get("ok", false)):
		return
	ZoneActions.move_battlefield_to_grave(state2, 0, "front", 0, "test_sunwu_die_low_calamity")
	_pass_stack_pair(engine, state2)
	var has_choice_2 := false
	for choice in state2.pending_choices:
		if str(choice.get("operation", "")) == "return_grave_to_hand":
			has_choice_2 = true
			break
	_expect(has_choice_2, "孙武：天灾值不高于4时应触发阵亡回收选择", failures)


static func _test_wuzetian_freezes_rested_enemy_units(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0102"],
		["neutral_s01_0006", "neutral_s01_0006"]
	], 6403, _masters(), _formal_options(1, 4, 6))
	var wuzetian_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0102")
	var enemy_a = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	var enemy_b = ""
	for card_id in state.get_player(1).hand.cards:
		if str(card_id) != enemy_a:
			enemy_b = str(card_id)
			break
	_expect(not wuzetian_id.is_empty() and not enemy_a.is_empty() and not enemy_b.is_empty(), "武则天：测试初始化失败（缺少目标军团）", failures)
	if wuzetian_id.is_empty() or enemy_a.is_empty() or enemy_b.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_a, "front", 0, "test_wuzetian_enemy_a")
	engine._deploy_hand_card_to_slot(state, 1, enemy_b, "back", 0, "test_wuzetian_enemy_b")
	state.card_instances[enemy_a].orientation = "rested"
	state.card_instances[enemy_b].orientation = "rested"
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": wuzetian_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "武则天：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "武则天：未能确认发动冻结效果", failures)
	_expect(int(state.card_instances[enemy_a].flags.get("cannot_ready_on_ready_phase_player", -1)) == 1, "武则天：前排目标未被标记冻结", failures)
	_expect(int(state.card_instances[enemy_b].flags.get("cannot_ready_on_ready_phase_player", -1)) == 1, "武则天：后排目标未被标记冻结", failures)
	_advance_to_player_main(engine, state, 1, failures, "武则天：推进到对方主阶段失败")
	_expect(str(state.card_instances[enemy_a].orientation) == "rested", "武则天：冻结目标在对方重置阶段不应转为活跃", failures)
	_expect(str(state.card_instances[enemy_b].orientation) == "rested", "武则天：冻结目标在对方重置阶段不应转为活跃", failures)
	_expect(not state.card_instances[enemy_a].flags.has("cannot_ready_on_ready_phase_player"), "武则天：冻结标记应在对方重置阶段后清除", failures)
	_expect(not state.card_instances[enemy_b].flags.has("cannot_ready_on_ready_phase_player"), "武则天：冻结标记应在对方重置阶段后清除", failures)


static func _test_yingzheng_clears_board_and_locks_morale_gain(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0101", "asgard_s01_0302", "neutral_s01_0006"],
		["neutral_s01_0006"]
	], 6404, _masters(), _formal_options(3, 8, 6))
	var yingzheng_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0101")
	var discard_cost8_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0302")
	var allied_unit_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0006")
	var enemy_unit_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not yingzheng_id.is_empty() and not discard_cost8_id.is_empty() and not allied_unit_id.is_empty() and not enemy_unit_id.is_empty(), "嬴政：测试初始化失败（缺少必要手牌）", failures)
	if yingzheng_id.is_empty() or discard_cost8_id.is_empty() or allied_unit_id.is_empty() or enemy_unit_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, allied_unit_id, "front", 0, "test_yingzheng_ally")
	engine._deploy_hand_card_to_slot(state, 1, enemy_unit_id, "front", 0, "test_yingzheng_enemy")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yingzheng_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(play.get("ok", false)), "嬴政：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(str(state.get_player(0).battle_front[1].occupant) == yingzheng_id, "嬴政：自身应留在场上", failures)
	_expect(str(state.get_player(0).battle_front[0].occupant).is_empty(), "嬴政：应击杀我方其他军团", failures)
	_expect(str(state.get_player(1).battle_front[0].occupant).is_empty(), "嬴政：应击杀对方军团", failures)
	_expect(_find_hand_card_by_definition(state, 0, "asgard_s01_0302").is_empty(), "嬴政：未弃置手牌中的 8 费军团", failures)
	_expect(state.get_player(0).spent_cost_area.cards.is_empty(), "嬴政：返还所有士气后 spent_cost_area 应为空", failures)
	var morale_before = state.get_player(0).cost_area.cards.size()
	var add_events = MoraleActions.add_morale_from_cost_deck(state, 0, 1, "active", "test_yingzheng_morale_lock")
	_expect(add_events.is_empty(), "嬴政：本回合应锁定额外追加士气", failures)
	_expect(state.get_player(0).cost_area.cards.size() == morale_before, "嬴政：锁定后不应追加新士气", failures)


static func _test_yingzheng_blocks_low_power_master_attack(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0101"],
		["neutral_s01_0006"]
	], 6438, _masters(), _formal_options(1, 6, 6))
	var yingzheng_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0101")
	var attacker_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not yingzheng_id.is_empty() and not attacker_id.is_empty(), "嬴政：主宰防护测试初始化失败", failures)
	if yingzheng_id.is_empty() or attacker_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yingzheng_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "嬴政：主宰防护测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	state.card_instances[yingzheng_id].entered_turn = -1
	_advance_to_player_main(engine, state, 1, failures, "嬴政：主宰防护测试推进到对方主阶段失败")
	engine._deploy_hand_card_to_slot(state, 1, attacker_id, "front", 0, "test_yingzheng_low_power_attacker")
	state.card_instances[attacker_id].entered_turn = -1
	var attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_player": 0
	}))
	_expect(not bool(attack.get("ok", false)) and str(attack.get("error", {}).get("code", "")) == "MASTER_ATTACK_BLOCKED_BY_YINGZHENG", "嬴政：前排在场时低兵力军团不应能进攻我方主宰", failures)


static func _test_lijing_reveals_and_deploys_top_tianting_legion(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0103", "tianting_s01_0115", "neutral_s01_0006"],
		[]
	], 6405, _masters(), _formal_options(1, 6, 6))
	var lijing_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0103")
	var top_tianting_id = str(state.get_player(0).deck.cards[0])
	_expect(not lijing_id.is_empty(), "李靖：测试初始化失败（未抽到李靖）", failures)
	if lijing_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": lijing_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "李靖：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "tianting_lijing_choose_position_or_deploy", "deploy"), "李靖：未能选择返还1士气活跃登场", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_lijing_deploy_to_slot", "front:1"), "李靖：未能选择登场位置", failures)
	_expect(str(state.get_player(0).battle_front[1].occupant) == top_tianting_id, "李靖：应将展示的天廷军团活跃登场", failures)
	var top_instance = state.card_instances.get(top_tianting_id)
	_expect(top_instance != null and str(top_instance.orientation) == "active", "李靖：展示军团应以活跃状态登场", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 5, "李靖：返还 1 士气后 spent_cost_area 应剩 5 张", failures)


static func _test_zhugeliang_adjusts_calamity_and_sets_artifact_from_top(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0111", "qa_vanilla"],
		[]
	], 6406, _masters(), _formal_options(1, 4, 6))
	state.calamity_deck.clear()
	state.calamity_deck.append("calamity_s01_ds01")
	state.calamity_value = 2
	var zhugeliang_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0111")
	_expect(not zhugeliang_id.is_empty(), "诸葛亮：测试初始化失败（未抽到诸葛亮）", failures)
	if zhugeliang_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": zhugeliang_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "诸葛亮：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "tianting_zhugeliang_calamity_adjust", "plus"), "诸葛亮：未能选择调整天灾值", failures)
	_expect(state.calamity_value == 3, "诸葛亮：天灾值应增加 1", failures)

	var state2 = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0111", "qa_vanilla", "tianting_s01_0117"],
		[]
	], 6407, _masters(), _formal_options(1, 4, 6))
	var zhugeliang_id_2 = _find_hand_card_by_definition(state2, 0, "tianting_s01_0111")
	_expect(not zhugeliang_id_2.is_empty(), "诸葛亮：第二测试初始化失败（未抽到诸葛亮）", failures)
	if zhugeliang_id_2.is_empty():
		return
	var play2 = engine.apply_command(state2, GameCommand.create(0, "PlayCard", {
		"card_id": zhugeliang_id_2,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play2.get("ok", false)), "诸葛亮：第二次打出失败", failures)
	if not bool(play2.get("ok", false)):
		return
	_pass_stack_pair(engine, state2)
	_resolve_first_option_choice(engine, state2, "tianting_zhugeliang_calamity_adjust", "keep")
	var attack = engine.apply_command(state2, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": zhugeliang_id_2,
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "诸葛亮：应可直接进攻对方主宰", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state2)
	_expect(not state2.get_player(0).artifact_zone.cards.is_empty(), "诸葛亮：应将牌库顶圣物直接置入圣物区", failures)
	var artifact_id = str(state2.get_player(0).artifact_zone.cards[0])
	var artifact_instance = state2.card_instances.get(artifact_id)
	_expect(artifact_instance != null and str(artifact_instance.definition_id) == "tianting_s01_0117", "诸葛亮：应置入山河社稷图", failures)


static func _test_xishi_replaces_self_and_draws(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0116", "tianting_s01_0115", "qa_vanilla"],
		[]
	], 6408, _masters(), _formal_options(2, 4, 6))
	var xishi_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0116")
	var jingke_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0115")
	_expect(not xishi_id.is_empty() and not jingke_id.is_empty(), "西施：测试初始化失败（未抽到西施/荆轲）", failures)
	if xishi_id.is_empty() or jingke_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": xishi_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "西施：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": xishi_id,
		"effect_id": "xishi_trade"
	}))
	_expect(bool(activate.get("ok", false)), "西施：能力发动失败", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [jingke_id]), "西施：未能选择替换登场军团", failures)
	_expect(_resolve_first_option_choice(engine, state, "deploy_selected_hand_to_slot", "front:0"), "西施：未能选择替换登场位置", failures)
	_expect(str(state.get_player(0).battle_front[0].occupant) == jingke_id, "西施：荆轲应替换西施站上原位置", failures)
	_expect(state.card_instances.get(xishi_id) != null and str(state.card_instances[xishi_id].zone) == "grave", "西施：自身应进入墓地", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before - 1, "西施：替换并抽 1 后手牌数量应净减 1", failures)


static func _test_mozi_grants_cannot_die_once(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0110", "tianting_s01_0115", "tianting_s01_0106"],
		[]
	], 6409, _masters(), _formal_options(3, 7, 6))
	var mozi_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0110")
	var jingke_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0115")
	var guanyu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0106")
	_expect(not mozi_id.is_empty() and not jingke_id.is_empty() and not guanyu_id.is_empty(), "墨子：测试初始化失败（缺少必要手牌）", failures)
	if mozi_id.is_empty() or jingke_id.is_empty() or guanyu_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, jingke_id, "front", 0, "test_mozi_jingke")
	engine._deploy_hand_card_to_slot(state, 0, guanyu_id, "back", 0, "test_mozi_guanyu")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mozi_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(play.get("ok", false)), "墨子：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "墨子：未能确认发动免死效果", failures)
	var jingke_instance = state.card_instances.get(jingke_id)
	var mozi_instance = state.card_instances.get(mozi_id)
	_expect(jingke_instance != null and int(jingke_instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) == 0, "墨子：未给第一个天廷军团附加免死", failures)
	_expect(mozi_instance != null and int(mozi_instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) == 0, "墨子：未给第二个天廷军团附加免死", failures)


static func _test_shanhe_entry_and_scout_mode(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0117", "qa_vanilla", "tianting_s01_0115", "tianting_s01_0112", "neutral_s01_0006", "qa_vanilla"],
		[]
	], 6410, _masters(), _formal_options(2, 3, 6))
	var shanhe_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0117")
	_expect(not shanhe_id.is_empty(), "山河社稷图：测试初始化失败（未抽到山河社稷图）", failures)
	if shanhe_id.is_empty():
		return
	var cost_before = state.get_player(0).cost_area.cards.size()
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": shanhe_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "山河社稷图：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).cost_area.cards.size() == cost_before - 2 + 1, "山河社稷图：登场应追加 1 张活跃士气", failures)
	var artifact_id = str(state.get_player(0).artifact_zone.cards[0])
	var hand_before = state.get_player(0).hand.cards.size()
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": artifact_id,
		"effect_id": "shanhe_rested_choose_mode"
	}))
	_expect(bool(activate.get("ok", false)), "山河社稷图：主动休整效果发动失败", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "resolve_option_with_shared_cost", "scout"), "山河社稷图：未能选择观顶模式", failures)
	var picked_tianting_id = _find_top_deck_instance_id_by_definition(state, 0, "tianting_s01_0112")
	var remaining_tianting_id = _find_top_deck_instance_id_by_definition(state, 0, "tianting_s01_0115")
	var neutral_id = _find_top_deck_instance_id_by_definition(state, 0, "neutral_s01_0006")
	_expect(not picked_tianting_id.is_empty() and not remaining_tianting_id.is_empty() and not neutral_id.is_empty(), "山河社稷图：测试初始化失败（未定位到观顶牌）", failures)
	if picked_tianting_id.is_empty() or remaining_tianting_id.is_empty() or neutral_id.is_empty():
		return
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_shanhe_pick_card", [picked_tianting_id]), "山河社稷图：未能选择加入手牌的天廷卡", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [remaining_tianting_id]), "山河社稷图：未能选择第一张返回的牌", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "top"), "山河社稷图：未能选择第一张放回顶部", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [neutral_id]), "山河社稷图：未能选择第二张返回的牌", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "bottom"), "山河社稷图：未能选择第二张放回底部", failures)
	_expect(state.get_player(0).hand.cards.has(picked_tianting_id), "山河社稷图：应将选择的天廷卡加入手牌", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "山河社稷图：弃 1 抽 1 后手牌数量应持平", failures)
	_expect(str(state.get_player(0).deck.cards[0]) == remaining_tianting_id, "山河社稷图：剩余卡应按选择放回牌库顶部", failures)
	_expect(str(state.get_player(0).deck.cards[state.get_player(0).deck.cards.size() - 1]) == neutral_id, "山河社稷图：剩余卡应按选择放回牌库底部", failures)


static func _test_guanxing_adds_active_morale(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0119", "qa_vanilla", "tianting_s01_0115", "neutral_s01_0006", "tianting_s01_0112", "qa_vanilla", "neutral_s01_0007", "qa_vanilla"],
		[]
	], 6411, _masters(), _formal_options(1, 6, 6))
	var guanxing_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0119")
	_expect(not guanxing_id.is_empty(), "观星：测试初始化失败（未抽到观星）", failures)
	if guanxing_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": guanxing_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "观星：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	var deck_ids: Array[String] = []
	for index in range(min(5, state.get_player(0).deck.cards.size())):
		deck_ids.append(str(state.get_player(0).deck.cards[index]))
	_expect(deck_ids.size() == 5, "观星：测试初始化失败（牌库顶部不足 5 张）", failures)
	if deck_ids.size() < 5:
		return
	var first_top_id = deck_ids[2]
	var second_top_id = deck_ids[0]
	var first_bottom_id = deck_ids[4]
	var second_bottom_id = deck_ids[1]
	var third_top_id = deck_ids[3]
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [first_top_id]), "观星：未能选择第一张返回的牌", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "top"), "观星：未能选择第一张放回顶部", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [second_top_id]), "观星：未能选择第二张返回的牌", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "top"), "观星：未能选择第二张放回顶部", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [first_bottom_id]), "观星：未能选择第三张返回的牌", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "bottom"), "观星：未能选择第三张放回底部", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [second_bottom_id]), "观星：未能选择第四张返回的牌", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "bottom"), "观星：未能选择第四张放回底部", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [third_top_id]), "观星：未能选择第五张返回的牌", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "top"), "观星：未能选择第五张放回顶部", failures)
	_expect(state.get_player(0).cost_area.cards.size() == 1, "观星：结算后应仅留下 1 张新增的活跃士气", failures)
	if state.get_player(0).cost_area.cards.size() == 1:
		var added_id = str(state.get_player(0).cost_area.cards[0])
		_expect(str(state.card_instances[added_id].orientation) == "active", "观星：追加的士气应为活跃状态", failures)
	_expect(str(state.get_player(0).deck.cards[0]) == first_top_id, "观星：第一张顶部顺序不正确", failures)
	_expect(str(state.get_player(0).deck.cards[1]) == second_top_id, "观星：第二张顶部顺序不正确", failures)
	_expect(str(state.get_player(0).deck.cards[2]) == third_top_id, "观星：第三张顶部顺序不正确", failures)
	var deck_size = state.get_player(0).deck.cards.size()
	_expect(str(state.get_player(0).deck.cards[deck_size - 2]) == first_bottom_id, "观星：第一张底部顺序不正确", failures)
	_expect(str(state.get_player(0).deck.cards[deck_size - 1]) == second_bottom_id, "观星：第二张底部顺序不正确", failures)


static func _test_limu_triggers_on_master_refund_four(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0102", "qa_vanilla"],
		[]
	], 6412, _masters(), _formal_options(1, 10, 6))
	var limu_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0102")
	_expect(not limu_id.is_empty(), "李牧：测试初始化失败（未抽到李牧）", failures)
	if limu_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": limu_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "李牧：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	MoraleActions.consume_morale(state, 0, 4, "test_limu_setup")
	var cost_before = state.get_player(0).cost_area.cards.size()
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "yangjian_refund_nonlethal_damage"
	}))
	_expect(bool(activate.get("ok", false)), "李牧：主宰返还 4 士气效果发动失败", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).cost_area.cards.size() == cost_before + 5, "李牧：应因主宰返还 4 士气并额外追加 1 张士气", failures)
	var added_id = str(state.get_player(0).cost_area.cards[-1])
	_expect(str(state.card_instances[added_id].orientation) == "rested", "李牧：额外追加的士气应为休整状态", failures)


static func _test_limu_entry_reveals_top_tactic_and_optional_draw(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0102", "tianting_s01_0120", "qa_vanilla"],
		[]
	], 6435, _masters(), _formal_options(1, 6, 6))
	var limu_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0102")
	_expect(not limu_id.is_empty(), "李牧：登场翻战术测试初始化失败", failures)
	if limu_id.is_empty():
		return
	var revealed_tactic_id = str(state.get_player(0).deck.cards[0])
	var hand_before = state.get_player(0).hand.cards.size()
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": limu_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "李牧：登场翻战术测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "李牧：未能确认发动登场翻战术效果", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_limu_reveal_top_tactic_choice", "play"), "李牧：未能选择免费打出展示的战术", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "李牧：未能确认登场翻战术后的抽牌", failures)
	_expect(state.get_player(0).grave.cards.has(revealed_tactic_id), "李牧：展示的战术应被免费打出并进入墓地", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "李牧：打出李牧并随后抽1后手牌数量应回到打出前", failures)


static func _test_mulan_gains_charge_on_entry(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0108"],
		["neutral_s01_0006"]
	], 6413, _masters(), _formal_options(1, 3, 6))
	var mulan_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0108")
	var enemy_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not mulan_id.is_empty() and not enemy_id.is_empty(), "花木兰：测试初始化失败（缺少必要手牌）", failures)
	if mulan_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_mulan_enemy")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mulan_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "花木兰：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "花木兰：未能确认发动冲锋效果", failures)
	var mulan_instance = state.card_instances.get(mulan_id)
	_expect(mulan_instance != null and int(mulan_instance.flags.get("temporary_keyword_charge_turn", -1)) == state.turn_number, "花木兰：未获得本回合冲锋标记", failures)
	_expect(_targets_include_card(engine.get_legal_attack_targets(state, mulan_id), enemy_id), "花木兰：获得冲锋后应可立即进攻敌方军团", failures)


static func _test_mulan_died_freeze_morale_allows_choice(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0108"],
		[]
	], 6439, _masters(), _formal_options(1, 6, 2))
	var mulan_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0108")
	_expect(not mulan_id.is_empty(), "花木兰：冻结士气选择测试初始化失败", failures)
	if mulan_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mulan_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "花木兰：冻结士气选择测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_advance_to_player_main(engine, state, 1, failures, "花木兰：冻结士气选择测试推进到对方主阶段失败")
	var enemy_morale_ids: Array[String] = []
	for card_id in state.get_player(1).cost_area.cards:
		var morale_id = str(card_id)
		if morale_id.is_empty():
			continue
		state.card_instances[morale_id].orientation = "rested"
		enemy_morale_ids.append(morale_id)
	if enemy_morale_ids.size() < 2:
		failures.append("花木兰：冻结士气选择测试初始化失败（对方休整士气不足2张）")
		return
	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_mulan_die_on_opponent_turn")
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_freeze_enemy_morale_pick", [enemy_morale_ids[1]]), "花木兰：未能选择要冻结的对方休整士气", failures)
	var frozen = state.card_instances.get(enemy_morale_ids[1])
	_expect(frozen != null and int(frozen.flags.get("cannot_ready_on_ready_phase_player", -1)) == 1, "花木兰：选择的对方休整士气应被冻结", failures)


static func _test_qiankun_yang_destroys_small_unit(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0105"],
		["neutral_s01_0006"]
	], 6414, _masters(), _formal_options(1, 4, 6))
	var tactic_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0105")
	var enemy_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not tactic_id.is_empty() and not enemy_id.is_empty(), "乾坤阳：测试初始化失败（缺少必要手牌）", failures)
	if tactic_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_qiankun_yang_enemy")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"target_card_id": enemy_id
	}))
	_expect(bool(play.get("ok", false)), "乾坤阳：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(str(state.get_player(1).battle_front[0].occupant).is_empty(), "乾坤阳：应击杀原本兵力不高于3000的目标", failures)


static func _test_qiankun_yang_optional_refund_draws(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0105", "qa_vanilla"],
		["neutral_s01_0006"]
	], 6433, _masters(), _formal_options(1, 4, 6))
	var tactic_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0105")
	var enemy_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not tactic_id.is_empty() and not enemy_id.is_empty(), "乾坤阳：抽牌测试初始化失败", failures)
	if tactic_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_qiankun_yang_draw_enemy")
	var hand_before = state.get_player(0).hand.cards.size()
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"target_card_id": enemy_id
	}))
	_expect(bool(play.get("ok", false)), "乾坤阳：抽牌测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "乾坤阳：未能确认返还士气抽牌", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "乾坤阳：打出并抽1后手牌数量应回到打出前", failures)


static func _test_pingyang_grants_master_damage_bonus(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0103"],
		[]
	], 6415, _masters(), _formal_options(1, 4, 6))
	var pingyang_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0103")
	_expect(not pingyang_id.is_empty(), "平阳昭公主：测试初始化失败（未抽到本体）", failures)
	if pingyang_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": pingyang_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "平阳昭公主：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var damage = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "yangjian_refund_nonlethal_damage"
	}))
	_expect(bool(damage.get("ok", false)), "平阳昭公主：后续主宰伤害效果发动失败", failures)
	if not bool(damage.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(1).master_hp == 10, "平阳昭公主：应让下一次主宰伤害额外 +1", failures)


static func _test_pingyang_attack_reveal_buffs_self(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0103", "tianting_s01_0120", "qa_vanilla"],
		["neutral_s01_0006"]
	], 6434, _masters(), _formal_options(1, 6, 6))
	var pingyang_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0103")
	var enemy_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not pingyang_id.is_empty() and not enemy_id.is_empty(), "平阳昭公主：进攻翻顶测试初始化失败", failures)
	if pingyang_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_pingyang_enemy")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": pingyang_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "平阳昭公主：进攻翻顶测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	state.card_instances[pingyang_id].entered_turn = -1
	state.card_instances[enemy_id].entered_turn = -1
	_advance_to_next_main(engine, state, failures, "平阳昭公主：推进到对方主阶段失败")
	_advance_to_next_main(engine, state, failures, "平阳昭公主：推进回我方主阶段失败")
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": pingyang_id,
		"defender_id": enemy_id
	}))
	_expect(bool(attack.get("ok", false)), "平阳昭公主：宣言进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "平阳昭公主：未能确认发动进攻翻顶效果", failures)
	_expect(engine.get_card_power(state, pingyang_id) == 5000, "平阳昭公主：翻到低费天廷卡后本回合应 +2000 兵力", failures)
static func _test_zhangfei_discount_and_frontline_bonus(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0107"],
		[]
	], 6416, _masters(), _formal_options(1, 4, 6))
	var zhangfei_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0107")
	_expect(not zhangfei_id.is_empty(), "张飞：测试初始化失败（未抽到张飞）", failures)
	if zhangfei_id.is_empty():
		return
	_expect(engine._get_effective_play_cost(state, zhangfei_id) == 4, "张飞：我方士气少于对方时登场费用应 -1", failures)
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": zhangfei_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "张飞：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_expect(state.get_player(0).spent_cost_area.cards.size() == 4, "张飞：应按折扣后的 4 费结算", failures)
	_advance_to_player_main(engine, state, 1, failures, "张飞：推进到对方主阶段失败")
	_expect(engine.get_card_power(state, zhangfei_id) == 5000, "张飞：在对方回合且位于前排时兵力应 +1000", failures)


static func _test_baiqi_adds_rested_morale(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0109"],
		[]
	], 6417, _masters(), _formal_options(1, 4, 6))
	var baiqi_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0109")
	_expect(not baiqi_id.is_empty(), "白起：测试初始化失败（未抽到白起）", failures)
	if baiqi_id.is_empty():
		return
	var cost_before = state.get_player(0).cost_area.cards.size()
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": baiqi_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "白起：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).cost_area.cards.size() == cost_before, "白起：4 费打出后再追加 3 张休整士气，最终数量应回到初始值", failures)
	for index in range(max(0, state.get_player(0).cost_area.cards.size() - 3), state.get_player(0).cost_area.cards.size()):
		var morale_id = str(state.get_player(0).cost_area.cards[index])
		_expect(str(state.card_instances[morale_id].orientation) == "rested", "白起：登场追加的士气应为休整状态", failures)
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": baiqi_id,
		"effect_id": "baiqi_rested_add_rested_morale"
	}))
	_expect(bool(activate.get("ok", false)), "白起：主动休整效果发动失败", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).cost_area.cards.size() == cost_before + 1, "白起：主动休整后应再追加 1 张休整士气", failures)


static func _test_shennongding_resets_master_once_per_turn(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s02_0104", "qa_vanilla"],
		[]
	], 6418, _masters(), _formal_options(1, 4, 6))
	var ding_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0104")
	_expect(not ding_id.is_empty(), "神农鼎：测试初始化失败（未抽到神农鼎）", failures)
	if ding_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ding_id,
		"row": "artifact",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "神农鼎：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var first_use = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "yangjian_draw_then_put_back"
	}))
	_expect(bool(first_use.get("ok", false)), "神农鼎：主宰首次发动失败", failures)
	if not bool(first_use.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var drawn_id = str(state.get_player(0).hand.cards[-1])
	_resolve_first_candidate_choice(engine, state, "yangjian_choose_hand_to_put_back", [drawn_id])
	_resolve_first_option_choice(engine, state, "yangjian_choose_put_back_position", "top")
	var second_blocked = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "yangjian_draw_then_put_back"
	}))
	_expect(not bool(second_blocked.get("ok", false)), "神农鼎：重置前主宰同回合第二次发动应被禁止", failures)
	var artifact_id = str(state.get_player(0).artifact_zone.cards[0])
	var reset = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": artifact_id,
		"effect_id": "shennongding_reset_master_effect"
	}))
	_expect(bool(reset.get("ok", false)), "神农鼎：重置主宰次数效果发动失败", failures)
	if not bool(reset.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var third_use = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "yangjian_draw_then_put_back"
	}))
	_expect(bool(third_use.get("ok", false)), "神农鼎：重置后应允许主宰再次发动", failures)


static func _test_shenmiao_buffs_frontline_power(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0118", "neutral_s01_0006"],
		[]
	], 6419, _masters(), _formal_options(2, 5, 6))
	var tactic_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0118")
	var ally_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0006")
	_expect(not tactic_id.is_empty() and not ally_id.is_empty(), "神妙行军：测试初始化失败（缺少必要手牌）", failures)
	if tactic_id.is_empty() or ally_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_shenmiao_ally")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"target_card_id": ally_id
	}))
	_expect(bool(play.get("ok", false)), "神妙行军：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(engine.get_card_power(state, ally_id) == 3000, "神妙行军：应给前排军团 +2000 兵力", failures)


static func _test_shenmiao_optional_destroy(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0118", "neutral_s01_0006"],
		["neutral_s01_0006"]
	], 6436, _masters(), _formal_options(2, 6, 6))
	var tactic_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0118")
	var ally_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0006")
	var enemy_hand_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not tactic_id.is_empty() and not ally_id.is_empty() and not enemy_hand_id.is_empty(), "神妙行军：追加击杀测试初始化失败", failures)
	if tactic_id.is_empty() or ally_id.is_empty() or enemy_hand_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_shenmiao_ally2")
	engine._deploy_hand_card_to_slot(state, 1, enemy_hand_id, "front", 0, "test_shenmiao_enemy")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"target_card_id": ally_id
	}))
	_expect(bool(play.get("ok", false)), "神妙行军：追加击杀测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(engine.get_card_power(state, ally_id) == 3000, "神妙行军：追加击杀测试应先给前排军团 +2000", failures)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "神妙行军：未能确认返还2士气击杀", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "destroy_battlefield_card", [enemy_hand_id]), "神妙行军：未能选择要击杀的军团", failures)
	_pass_stack_pair(engine, state)
	_expect(str(state.get_player(1).battle_front[0].occupant).is_empty(), "神妙行军：应击杀对方军团", failures)


static func _test_qinliangyu_discount_and_entry_morale(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0114"],
		[]
	], 6420, _masters(), _formal_options(1, 2, 6))
	var qin_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0114")
	_expect(not qin_id.is_empty(), "秦良玉：测试初始化失败（未抽到本体）", failures)
	if qin_id.is_empty():
		return
	_expect(engine._get_effective_play_cost(state, qin_id) == 2, "秦良玉：我方士气少于对方时登场费用应 -1", failures)
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": qin_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "秦良玉：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 2, "秦良玉：应按折扣后的 2 费结算", failures)
	_expect(state.get_player(0).cost_area.cards.size() == 1, "秦良玉：登场后应追加 1 张休整士气", failures)
	if state.get_player(0).cost_area.cards.size() == 1:
		var added_id = str(state.get_player(0).cost_area.cards[0])
		_expect(str(state.card_instances[added_id].orientation) == "rested", "秦良玉：追加士气应为休整状态", failures)


static func _test_hanxin_attack_boosts_power_and_master_damage_bonus(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0104", "qa_vanilla"],
		[]
	], 6437, _masters(), _formal_options(1, 6, 6))
	var hanxin_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0104")
	_expect(not hanxin_id.is_empty(), "韩信：进攻强化测试初始化失败", failures)
	if hanxin_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hanxin_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "韩信：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	state.card_instances[hanxin_id].entered_turn = -1
	_advance_to_next_main(engine, state, failures, "韩信：推进到对方主阶段失败")
	_advance_to_next_main(engine, state, failures, "韩信：推进回我方主阶段失败")
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hanxin_id,
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "韩信：宣言进攻主宰失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "韩信：未能确认进攻返还士气强化", failures)
	_pass_stack_pair(engine, state)
	_expect(engine.get_card_power(state, hanxin_id) == 6000, "韩信：进攻强化后本回合兵力应 +1000", failures)
	_expect(int(state.card_instances[hanxin_id].flags.get("master_damage_bonus_amount", 0)) == 1, "韩信：进攻强化后应获得强攻（主宰伤害+1）", failures)


static func _test_jingke_draws_and_death_kills_small_unit(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0115"],
		["neutral_s01_0006"]
	], 6421, _masters(), _formal_options(1, 2, 6))
	var jingke_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0115")
	var enemy_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not jingke_id.is_empty() and not enemy_id.is_empty(), "荆轲：测试初始化失败（缺少必要手牌）", failures)
	if jingke_id.is_empty() or enemy_id.is_empty():
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": jingke_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "荆轲：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "荆轲：士气不高于7时应登场抽1，手牌数量应持平", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_jingke_enemy")
	MoraleActions.consume_morale(state, 0, 1, "test_jingke_refund_setup")
	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_jingke_die")
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "荆轲：未能确认阵亡击杀效果", failures)
	_pass_stack_pair(engine, state)
	_expect(str(state.get_player(1).battle_front[0].occupant).is_empty(), "荆轲：阵亡后应击杀对方低兵力军团", failures)


static func _test_kongchengji_counters_pending_attack(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["neutral_s01_0006", "tianting_s01_0120"],
		["neutral_s01_0006"]
	], 6422, _masters(), _formal_options(2, 4, 6))
	var defender_hand_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0006")
	var kongchengji_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0120")
	var attacker_hand_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not defender_hand_id.is_empty() and not kongchengji_id.is_empty() and not attacker_hand_id.is_empty(), "空城计：测试初始化失败（缺少必要手牌）", failures)
	if defender_hand_id.is_empty() or kongchengji_id.is_empty() or attacker_hand_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, defender_hand_id, "front", 0, "test_kongchengji_defender")
	_advance_to_player_main(engine, state, 1, failures, "空城计：推进到对方主阶段失败")
	engine._deploy_hand_card_to_slot(state, 1, attacker_hand_id, "front", 0, "test_kongchengji_attacker")
	_advance_to_next_main(engine, state, failures, "空城计：推进到我方下个主阶段失败")
	_advance_to_next_main(engine, state, failures, "空城计：推进回对方攻击回合失败")
	var attacker_id = str(state.get_player(1).battle_front[0].occupant)
	var defender_id = str(state.get_player(0).battle_front[0].occupant)
	var attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	}))
	_expect(bool(attack.get("ok", false)), "空城计：对方宣言进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	var actions = engine.get_legal_actions(state, 0)
	var counter_action = _find_action(actions, "play_card", "counter_tactic")
	_expect(not counter_action.is_empty(), "空城计：进攻响应窗口应暴露反击战术行动", failures)
	if counter_action.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kongchengji_id,
		"row": "counter_tactic",
		"col": -1,
		"effect_id": "kongchengji_counter_attack",
		"target_stack_id": "__pending_attack__"
	}))
	_expect(bool(play.get("ok", false)), "空城计：反击战术打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_expect(not state.pending_attack.is_empty(), "空城计：在栈结算前应保留 pending attack", failures)
	_pass_stack_pair(engine, state)
	_expect(state.pending_attack.is_empty(), "空城计：结算后应清空 pending attack", failures)
	_expect(state.card_instances[attacker_id].orientation == "rested", "空城计：被反掉的攻击者应转为休整", failures)


static func _test_qiankun_yin_buffs_allied_unit_from_top_card(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0106", "tianting_s02_0106", "tianting_s01_0115"],
		["neutral_s01_0006"]
	], 6423, _masters(), _formal_options(2, 6, 6))
	var ally_hand_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0106")
	var qiankunyin_id = _find_hand_card_by_definition(state, 0, "tianting_s02_0106")
	var attacker_hand_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not ally_hand_id.is_empty() and not qiankunyin_id.is_empty() and not attacker_hand_id.is_empty(), "乾坤阴：测试初始化失败（缺少必要手牌）", failures)
	if ally_hand_id.is_empty() or qiankunyin_id.is_empty() or attacker_hand_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_hand_id, "front", 0, "test_qiankun_yin_ally")
	_advance_to_player_main(engine, state, 1, failures, "乾坤阴：推进到对方主阶段失败")
	engine._deploy_hand_card_to_slot(state, 1, attacker_hand_id, "front", 0, "test_qiankun_yin_attacker")
	_advance_to_next_main(engine, state, failures, "乾坤阴：推进到我方下个主阶段失败")
	_advance_to_next_main(engine, state, failures, "乾坤阴：推进回对方攻击回合失败")
	var attacker_id = str(state.get_player(1).battle_front[0].occupant)
	var defender_id = str(state.get_player(0).battle_front[0].occupant)
	var top_deck_id = str(state.get_player(0).deck.cards[0])
	var power_before = engine.get_card_power(state, ally_hand_id)
	var cost_before = engine._get_effective_play_cost(state, ally_hand_id)
	var attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	}))
	_expect(bool(attack.get("ok", false)), "乾坤阴：对方宣言进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": qiankunyin_id,
		"row": "counter_tactic",
		"col": -1,
		"effect_id": "qiankun_yin_counter",
		"target_stack_id": "__pending_attack__"
	}))
	_expect(bool(play.get("ok", false)), "乾坤阴：反击战术打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(engine.get_card_power(state, ally_hand_id) == power_before + 2000, "乾坤阴：应按弃置顶牌费用给我方军团 +2000 兵力", failures)
	_expect(engine._get_effective_play_cost(state, ally_hand_id) == cost_before + 2, "乾坤阴：应按弃置顶牌费用提高我方军团费用", failures)
	_expect(state.get_player(0).grave.cards.has(top_deck_id), "乾坤阴：应将牌库顶的低费天廷军团弃置进墓地", failures)


static func _test_guanyu_moves_and_gains_attack_power(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0106"],
		["neutral_s01_0006"]
	], 6424, _masters(), _formal_options(1, 7, 6))
	var guanyu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0106")
	var enemy_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not guanyu_id.is_empty() and not enemy_id.is_empty(), "关羽：测试初始化失败（缺少必要手牌）", failures)
	if guanyu_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_guanyu_enemy")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": guanyu_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "关羽：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	var activate_move = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": guanyu_id,
		"effect_id": "guanyu_free_move"
	}))
	_expect(bool(activate_move.get("ok", false)), "关羽：位移效果发动失败", failures)
	if not bool(activate_move.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(str(state.get_player(0).battle_back[0].occupant) == guanyu_id, "关羽：应从前排移动到同列后排", failures)
	_advance_to_next_main(engine, state, failures, "关羽：推进到对方主阶段失败")
	_advance_to_next_main(engine, state, failures, "关羽：推进回我方主阶段失败")
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": guanyu_id,
		"defender_id": enemy_id
	}))
	_expect(bool(attack.get("ok", false)), "关羽：宣言进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "关羽：未能确认进攻加攻效果", failures)
	_expect(engine.get_card_power(state, guanyu_id) == 6000, "关羽：返还 1 士气后本回合兵力应 +1000", failures)


static func _test_guanyu_attack_target_cannot_be_supported(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0106"],
		["neutral_s01_0006", "neutral_s01_0006"]
	], 6427, _masters(), _formal_options(1, 6, 6))
	var guanyu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0106")
	var enemy_front = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	var enemy_back := ""
	for card_id in state.get_player(1).hand.cards:
		if str(card_id) != enemy_front:
			enemy_back = str(card_id)
			break
	_expect(not guanyu_id.is_empty() and not enemy_front.is_empty() and not enemy_back.is_empty(), "关羽：不可支援测试初始化失败", failures)
	if guanyu_id.is_empty() or enemy_front.is_empty() or enemy_back.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, guanyu_id, "front", 0, "test_guanyu_support_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_front, "front", 0, "test_guanyu_enemy_front")
	engine._deploy_hand_card_to_slot(state, 1, enemy_back, "back", 0, "test_guanyu_enemy_back")
	state.card_instances[guanyu_id].entered_turn = -1
	state.card_instances[enemy_front].entered_turn = -1
	state.card_instances[enemy_back].entered_turn = -1
	var supporters = engine.get_legal_supporters(state, enemy_front, guanyu_id)
	_expect(supporters.is_empty(), "关羽：其进攻目标不应允许后排支援", failures)


static func _test_guanyu_cannot_be_blocked(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0106"],
		["neutral_s01_0006", "neutral_s01_0006"]
	], 6428, _masters(), _formal_options(1, 6, 6))
	var guanyu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0106")
	var enemy_front = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	var enemy_blocker := ""
	for card_id in state.get_player(1).hand.cards:
		if str(card_id) != enemy_front:
			enemy_blocker = str(card_id)
			break
	_expect(not guanyu_id.is_empty() and not enemy_front.is_empty() and not enemy_blocker.is_empty(), "关羽：不可阻挡测试初始化失败", failures)
	if guanyu_id.is_empty() or enemy_front.is_empty() or enemy_blocker.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, guanyu_id, "front", 0, "test_guanyu_block_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_front, "front", 0, "test_guanyu_block_enemy_front")
	engine._deploy_hand_card_to_slot(state, 1, enemy_blocker, "front", 1, "test_guanyu_block_enemy_other_front")
	state.card_instances[guanyu_id].entered_turn = -1
	state.card_instances[enemy_front].entered_turn = -1
	state.card_instances[enemy_blocker].entered_turn = -1
	var blockers = engine.get_legal_blockers(state, 1, guanyu_id)
	_expect(blockers.is_empty(), "关羽：进攻时不应允许对方声明阻挡", failures)
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": guanyu_id,
		"defender_id": enemy_front,
		"blocker_id": enemy_blocker
	}))
	_expect(not bool(attack.get("ok", false)) and str(attack.get("code", "")) == "INVALID_BLOCKER", "关羽：宣言带 blocker 的进攻应被拒绝", failures)


static func _test_yangyouji_ranged_attack_is_no_loss(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0113"],
		["neutral_s01_0006"]
	], 6425, _masters(), _formal_options(1, 5, 6))
	var yangyouji_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0113")
	var enemy_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not yangyouji_id.is_empty() and not enemy_id.is_empty(), "养由基：测试初始化失败（缺少必要手牌）", failures)
	if yangyouji_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "back", 0, "test_yangyouji_enemy")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yangyouji_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "养由基：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_advance_to_next_main(engine, state, failures, "养由基：推进到对方主阶段失败")
	_advance_to_next_main(engine, state, failures, "养由基：推进回我方主阶段失败")
	var enable = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": yangyouji_id,
		"effect_id": "yangyouji_enable_back_attack"
	}))
	_expect(bool(enable.get("ok", false)), "养由基：启用进攻后排效果失败", failures)
	if not bool(enable.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_targets_include_card(engine.get_legal_attack_targets(state, yangyouji_id), enemy_id), "养由基：启用效果后应可远程攻击敌方后排", failures)
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": yangyouji_id,
		"defender_id": enemy_id
	}))
	_expect(bool(attack.get("ok", false)), "养由基：宣言远程进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.card_instances.has(yangyouji_id), "养由基：远程无损后自身应留在场上", failures)
	_expect(str(state.get_player(1).battle_back[0].occupant).is_empty(), "养由基：应击杀敌方后排目标", failures)


static func _test_lvbu_entry_destroy_and_attack_ready(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0101"],
		["neutral_s01_0006", "neutral_s01_0006"]
	], 6426, _masters(), _formal_options(1, 9, 6))
	var lvbu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0101")
	var enemy_first = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	var enemy_second := ""
	for card_id in state.get_player(1).hand.cards:
		if str(card_id) != enemy_first:
			enemy_second = str(card_id)
			break
	_expect(not lvbu_id.is_empty() and not enemy_first.is_empty() and not enemy_second.is_empty(), "吕布：测试初始化失败（缺少必要手牌）", failures)
	if lvbu_id.is_empty() or enemy_first.is_empty() or enemy_second.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_first, "front", 0, "test_lvbu_enemy_first")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": lvbu_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "吕布：打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "吕布：未能确认登场击杀效果", failures)
	_expect(str(state.get_player(1).battle_front[0].occupant).is_empty(), "吕布：登场应击杀天灾等级 2 及以下敌军", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_second, "front", 1, "test_lvbu_enemy_second")
	_advance_to_next_main(engine, state, failures, "吕布：推进到对方主阶段失败")
	_advance_to_next_main(engine, state, failures, "吕布：推进回我方主阶段失败")
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": lvbu_id,
		"defender_id": enemy_second
	}))
	_expect(bool(attack.get("ok", false)), "吕布：宣言进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "吕布：未能确认进攻后再站起效果", failures)
	_expect(state.card_instances.has(lvbu_id) and str(state.card_instances[lvbu_id].orientation) == "active", "吕布：返还 4 士气后应重新转为活跃", failures)


static func _test_lvbu_cannot_be_attacked_by_ranged(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0101"],
		["tianting_s01_0113"]
	], 6428, _masters(), _formal_options(1, 6, 6))
	var lvbu_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0101")
	var enemy_archer_id = _find_hand_card_by_definition(state, 1, "tianting_s01_0113")
	_expect(not lvbu_id.is_empty() and not enemy_archer_id.is_empty(), "吕布：远程免疫测试初始化失败", failures)
	if lvbu_id.is_empty() or enemy_archer_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, lvbu_id, "front", 0, "test_lvbu_ranged_defender")
	engine._deploy_hand_card_to_slot(state, 1, enemy_archer_id, "back", 0, "test_lvbu_ranged_attacker")
	state.card_instances[lvbu_id].entered_turn = -1
	state.card_instances[enemy_archer_id].entered_turn = -1
	_advance_to_player_main(engine, state, 1, failures, "吕布：推进到对方主阶段失败")
	var invalid_attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": enemy_archer_id,
		"defender_id": lvbu_id
	}))
	_expect(not bool(invalid_attack.get("ok", false)) and str(invalid_attack.get("error", {}).get("code", "")) == "RANGED_ATTACK_FORBIDDEN", "吕布：应无法被远程进攻", failures)


static func _test_wuzetian_died_draws_and_heals(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var masters = [
		{"name": "P0", "master_name": "杨戬", "master_id": "tianting_s01_01m1", "master_hp": 7, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	]
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0102", "qa_vanilla"],
		[]
	], 6429, masters, _formal_options(2, 4, 6))
	var wuzetian_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0102")
	_expect(not wuzetian_id.is_empty(), "武则天：阵亡收益测试初始化失败", failures)
	if wuzetian_id.is_empty():
		return
	var hand_before = state.get_player(0).hand.cards.size()
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": wuzetian_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "武则天：阵亡收益测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_wuzetian_die")
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).master_hp == 8, "武则天：阵亡时应治疗我方主宰 1 点", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "武则天：阵亡时应额外抽 1，手牌数量应回到打出前", failures)


static func _test_kongchengji_draws_if_no_frontline(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["tianting_s01_0120"],
		["neutral_s01_0006"]
	], 6430, _masters(), _formal_options(1, 4, 6))
	var kongchengji_id = _find_hand_card_by_definition(state, 0, "tianting_s01_0120")
	var attacker_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0006")
	_expect(not kongchengji_id.is_empty() and not attacker_id.is_empty(), "空城计：空前排抽牌测试初始化失败", failures)
	if kongchengji_id.is_empty() or attacker_id.is_empty():
		return
	_advance_to_player_main(engine, state, 1, failures, "空城计：推进到对方主阶段失败")
	engine._deploy_hand_card_to_slot(state, 1, attacker_id, "front", 0, "test_kongchengji_master_attacker")
	_advance_to_next_main(engine, state, failures, "空城计：推进到我方下个主阶段失败")
	_advance_to_next_main(engine, state, failures, "空城计：推进回对方攻击回合失败")
	attacker_id = str(state.get_player(1).battle_front[0].occupant)
	var hand_before = state.get_player(0).hand.cards.size()
	var attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_player": 0
	}))
	_expect(bool(attack.get("ok", false)), "空城计：对我方主宰的进攻宣言失败", failures)
	if not bool(attack.get("ok", false)):
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kongchengji_id,
		"row": "counter_tactic",
		"col": -1,
		"effect_id": "kongchengji_counter_attack",
		"target_stack_id": "__pending_attack__"
	}))
	_expect(bool(play.get("ok", false)), "空城计：空前排测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "空城计：前排没有军团时，打出后应抽 1 补回手牌", failures)


static func _definitions_with_tianting_masters() -> Array:
	var definitions: Array = []
	definitions.append_array(CardDatabase.load_definitions())
	definitions.append_array(CardDatabase.load_definitions("res://data/raw_rule_cards/tianting_master_cards.json"))
	return definitions


static func _masters() -> Array:
	return [
		{"name": "P0", "master_name": "杨戬", "master_id": "tianting_s01_01m1", "master_hp": 8, "master_max_hp": 8},
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


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _pass_stack_pair(engine: GameEngine, state) -> void:
	if state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))


static func _resolve_first_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_option": selected_option
		})).get("ok", false))
	return false


static func _resolve_first_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_card_ids": selected_card_ids
		})).get("ok", false))
	return false


static func _find_top_deck_instance_id_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).deck.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _targets_include_card(targets: Array, target_card_id: String) -> bool:
	for target in targets:
		if target is Dictionary and str(target.get("defender_id", "")) == target_card_id:
			return true
	return false


static func _find_action(actions: Array, kind: String, play_kind: String = "") -> Dictionary:
	for action in actions:
		if not (action is Dictionary):
			continue
		if str(action.get("kind", "")) != kind:
			continue
		if not play_kind.is_empty() and str(action.get("play_kind", "")) != play_kind:
			continue
		return action
	return {}


static func _advance_to_player_main(engine: GameEngine, state, player_id: int, failures: Array[String], message: String) -> void:
	for _i in range(8):
		if state.active_player == player_id and str(state.phase) == "main":
			return
		var result = engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase", {}))
		_expect(bool(result.get("ok", false)), message, failures)
		if not bool(result.get("ok", false)):
			return
	failures.append(message)


static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(8):
		var result = engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase", {}))
		_expect(bool(result.get("ok", false)), message, failures)
		if not bool(result.get("ok", false)):
			return
		if str(state.phase) == "main":
			return
	failures.append(message)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
