extends RefCounted
class_name TestBijieBatch8

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_definitions_load(failures)
	_test_gawain_attack_scales_with_runes(failures)
	_test_fiana_complete_weaken_and_ready_bijie(failures)
	_test_mistletoe_spell_uses_runes_to_reduce_cast_cost(failures)
	_test_amagin_rested_protects_trial_legion(failures)
	_test_amagin_rest_reveal_top_bijie_or_reorder(failures)
	_test_richard_entry_advances_trial_and_gains_cannot_die_once(failures)
	_test_richard_attaches_squires_and_cashs_them_for_power(failures)
	_test_richard_attack_support_requires_extra_discard(failures)
	_test_crusade_grants_trial_legion_attack_no_loss(failures)
	_test_crusade_grants_richard_pierce_after_first_kill(failures)
	_test_crusade_discards_and_returns_bijie_from_grave(failures)
	return failures


static func _test_definitions_load(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	_expect(_find_definition(definitions, "bijie_s02_052") != null, "彼界：未加载高文定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_057") != null, "彼界：未加载芬尼亚传奇定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_048") != null, "彼界：未加载槲寄生符咒定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_038") != null, "彼界：未加载阿麦金定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_053") != null, "彼界：未加载狮心王理查一世定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_058") != null, "彼界：未加载十字军东征定义", failures)


static func _test_gawain_attack_scales_with_runes(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_052"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8301, [], _formal_options(1, 7, 0))
	var gawain_id = _find_hand_card_by_definition(state, 0, "bijie_s02_052")
	_expect(not gawain_id.is_empty(), "彼界：高文测试初始化失败", failures)
	if gawain_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": gawain_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：高文打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：高文打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "彼界：高文登场时应获得1符文", failures)
	state.get_player(0).counters["rune"] = 3
	state.card_instances[gawain_id].entered_turn = -1
	state.card_instances[gawain_id].orientation = "active"
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": gawain_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "彼界：高文应可宣告攻击主宰", failures)
	if not bool(attack.get("ok", false)):
		failures.append("彼界：高文宣告进攻错误=%s %s" % [str(attack.get("code", "")), str(attack.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "彼界：高文进攻时应可选择发动符文强化", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "choose_rune_payment_for_source_attack_bonus", "3"), "彼界：高文应可选择消耗3符文", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：高文应消耗所选数量的符文", failures)
	_expect(engine.get_card_power(state, gawain_id) == 9000, "彼界：高文每消耗1符文应获得+1000兵力", failures)
	_expect(int(state.card_instances[gawain_id].flags.get("master_damage_bonus_amount", 0)) == 3, "彼界：高文每消耗1符文应获得+1主宰伤害", failures)
	_resolve_pending_attack(engine, state)
	_expect(int(state.get_player(1).master_hp) == 16, "彼界：高文消耗3符文后应对主宰造成4点伤害", failures)


static func _test_fiana_complete_weaken_and_ready_bijie(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_057", "bijie_s02_042"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8302, [], _formal_options(1, 3, 0))
	var trial_id = _find_trial_card_by_definition(state, 0, "bijie_s02_057")
	var ally_id = _find_hand_card_by_definition(state, 0, "bijie_s02_042")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not trial_id.is_empty() and not ally_id.is_empty() and not enemy_id.is_empty(), "彼界：芬尼亚传奇测试初始化失败", failures)
	if trial_id.is_empty() or ally_id.is_empty() or enemy_id.is_empty():
		return
	var ally_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(ally_play.get("ok", false)), "彼界：芬尼亚传奇测试我方军团打出失败", failures)
	if not bool(ally_play.get("ok", false)):
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_bijie_fiana_enemy_setup")
	state.card_instances[enemy_id].entered_turn = -1
	state.card_instances[enemy_id].orientation = "active"
	var ally_instance = state.card_instances.get(ally_id)
	if ally_instance != null:
		ally_instance.orientation = "rested"
	state.get_player(0).counters["rune"] = 1
	var trial_activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": trial_id,
		"effect_id": "fiana_ready_bijie_once"
	}))
	_expect(bool(trial_activate.get("ok", false)), "彼界：芬尼亚传奇应可发动转活跃效果", failures)
	if not bool(trial_activate.get("ok", false)):
		failures.append("彼界：芬尼亚传奇转活跃错误=%s %s" % [str(trial_activate.get("code", "")), str(trial_activate.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_candidate_choice(engine, state, "ready_battlefield_card", [ally_id]), "彼界：芬尼亚传奇应可选择彼界军团转为活跃", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：芬尼亚传奇转活跃应消耗1符文", failures)
	_expect(str(state.card_instances[ally_id].orientation) == "active", "彼界：芬尼亚传奇应将目标军团转为活跃", failures)
	state.get_player(0).counters["rune"] = 1
	var second_activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": trial_id,
		"effect_id": "fiana_ready_bijie_once"
	}))
	_expect(not bool(second_activate.get("ok", false)), "彼界：芬尼亚传奇同回合不应再次发动转活跃", failures)
	var trial_instance = state.card_instances.get(trial_id)
	if trial_instance != null:
		trial_instance.flags["trial_progress"] = 2
		trial_instance.flags["trial_completed"] = true
	state.get_player(0).counters["rune"] = 1
	var complete_event = engine._append_logged_event(state, "TrialCompleted", 0, {
		"card_id": trial_id,
		"source_card_id": trial_id,
		"progress": 2
	}, "test_bijie_fiana_complete")
	engine.drain_until_waiting_for_input(state, [complete_event], "test_bijie_fiana_complete")
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：芬尼亚传奇完成时应可选择发动减攻", failures)
	_expect(_resolve_candidate_choice(engine, state, "modify_power_until_turn_end", [enemy_id]), "彼界：芬尼亚传奇完成时应可选择敌方军团减攻", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：芬尼亚传奇完成减攻应消耗1符文", failures)
	_expect(engine.get_card_power(state, enemy_id) == 0, "彼界：芬尼亚传奇完成后应使目标军团本回合兵力降至0", failures)


static func _test_mistletoe_spell_uses_runes_to_reduce_cast_cost(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_048"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8303, [], _formal_options(1, 1, 0))
	var spell_id = _find_hand_card_by_definition(state, 0, "bijie_s02_048")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not spell_id.is_empty() and not enemy_id.is_empty(), "彼界：槲寄生符咒测试初始化失败", failures)
	if spell_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_bijie_mistletoe_enemy_setup")
	state.get_player(0).counters["rune"] = 2
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": spell_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "mistletoe_spell_cast",
		"play_option_id": "mistletoe_rune_2"
	}))
	_expect(bool(play.get("ok", false)), "彼界：槲寄生符咒应可通过消耗2符文降费打出", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：槲寄生符咒打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：槲寄生符咒应消耗2符文", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == 1, "彼界：槲寄生符咒消耗2符文后应只支付1士气", failures)
	_pass_stack_pair(engine, state)
	_expect(_resolve_candidate_choice(engine, state, "modify_power_until_turn_end", [enemy_id]), "彼界：槲寄生符咒应可选择敌方军团", failures)
	_expect(engine.get_card_power(state, enemy_id) == 0, "彼界：槲寄生符咒应使目标军团本回合兵力降至0", failures)


static func _test_amagin_rested_protects_trial_legion(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_038", "bijie_s02_043"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8304, [], _formal_options(2, 4, 4))
	var amagin_id = _find_hand_card_by_definition(state, 0, "bijie_s02_038")
	var finn_id = _find_hand_card_by_definition(state, 0, "bijie_s02_043")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not amagin_id.is_empty() and not finn_id.is_empty() and not enemy_id.is_empty(), "彼界：阿麦金保护测试初始化失败", failures)
	if amagin_id.is_empty() or finn_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, amagin_id, "front", 0, "test_bijie_amagin_setup")
	engine._deploy_hand_card_to_slot(state, 0, finn_id, "front", 1, "test_bijie_amagin_trial_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 1, "test_bijie_amagin_enemy_setup")
	state.card_instances[amagin_id].orientation = "rested"
	state.card_instances[finn_id].orientation = "active"
	state.card_instances[finn_id].entered_turn = state.turn_number - 1
	state.card_instances[enemy_id].entered_turn = state.turn_number - 1
	state.active_player = 1
	state.priority_player = 1
	_expect(not _targets_include_card(engine.get_legal_attack_targets(state, enemy_id), finn_id), "彼界：阿麦金休整时应使活跃试炼军团不可被进攻", failures)
	state.card_instances[amagin_id].orientation = "active"
	_expect(_targets_include_card(engine.get_legal_attack_targets(state, enemy_id), finn_id), "彼界：阿麦金不休整时试炼军团应重新可被进攻", failures)


static func _test_amagin_rest_reveal_top_bijie_or_reorder(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_038", "bijie_s02_048"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8305, [], _formal_options(1, 3, 0))
	var amagin_id = _find_hand_card_by_definition(state, 0, "bijie_s02_038")
	_expect(not amagin_id.is_empty(), "彼界：阿麦金翻顶测试初始化失败", failures)
	if amagin_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": amagin_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：阿麦金打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	if not _pending_choice_by_operation(state, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：阿麦金登场时应可处理加符文选择", failures)
	var before_hand = state.get_player(0).hand.cards.size()
	var before_deck_top = str(state.get_player(0).deck.cards[0]) if not state.get_player(0).deck.cards.is_empty() else ""
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": amagin_id,
		"effect_id": "amagin_rest_reveal_top"
	}))
	_expect(bool(activate.get("ok", false)), "彼界：阿麦金应可发动主动休整翻顶", failures)
	if not bool(activate.get("ok", false)):
		failures.append("彼界：阿麦金主动休整错误=%s %s" % [str(activate.get("code", "")), str(activate.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(str(state.card_instances[amagin_id].orientation) == "rested", "彼界：阿麦金发动后应转为休整", failures)
	_expect(_resolve_option_choice(engine, state, "bijie_reveal_top_bijie_or_reorder", "hand"), "彼界：阿麦金翻到彼界卡时应可加入手牌", failures)
	_expect(state.get_player(0).hand.cards.size() == before_hand + 1, "彼界：阿麦金翻到彼界卡后应加入手牌", failures)
	_expect(state.get_player(0).deck.cards.is_empty() or str(state.get_player(0).deck.cards[0]) != before_deck_top, "彼界：阿麦金加入手牌后牌库顶不应仍保留原卡", failures)
	var state_bottom = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_038", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8306, [], _formal_options(1, 3, 0))
	var amagin_bottom_id = _find_hand_card_by_definition(state_bottom, 0, "bijie_s02_038")
	_expect(not amagin_bottom_id.is_empty(), "彼界：阿麦金放底测试初始化失败", failures)
	if amagin_bottom_id.is_empty():
		return
	var play_bottom = engine.apply_command(state_bottom, GameCommand.create(0, "PlayCard", {
		"card_id": amagin_bottom_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play_bottom.get("ok", false)), "彼界：阿麦金放底测试打出失败", failures)
	if not bool(play_bottom.get("ok", false)):
		return
	_pass_stack_pair(engine, state_bottom)
	if not _pending_choice_by_operation(state_bottom, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state_bottom, "optional_stack_effect", "yes"), "彼界：阿麦金放底测试应可处理登场加符文选择", failures)
	var moved_card_id = str(state_bottom.get_player(0).deck.cards[0]) if not state_bottom.get_player(0).deck.cards.is_empty() else ""
	var activate_bottom = engine.apply_command(state_bottom, GameCommand.create(0, "ActivateEffect", {
		"source_id": amagin_bottom_id,
		"effect_id": "amagin_rest_reveal_top"
	}))
	_expect(bool(activate_bottom.get("ok", false)), "彼界：阿麦金应可在非彼界顶牌时发动翻顶", failures)
	if not bool(activate_bottom.get("ok", false)):
		return
	_pass_stack_pair(engine, state_bottom)
	_expect(_resolve_option_choice(engine, state_bottom, "bijie_reveal_top_bijie_or_reorder", "bottom"), "彼界：阿麦金翻到非彼界卡时应可放回牌库底", failures)
	_expect(str(state_bottom.get_player(0).deck.cards[state_bottom.get_player(0).deck.cards.size() - 1]) == moved_card_id, "彼界：阿麦金选择放底后该牌应位于牌库底", failures)


static func _test_richard_entry_advances_trial_and_gains_cannot_die_once(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_057", "bijie_s02_053"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 83065, [], _formal_options(1, 8, 0))
	var trial_id = _find_trial_card_by_definition(state, 0, "bijie_s02_057")
	var richard_id = _find_hand_card_by_definition(state, 0, "bijie_s02_053")
	_expect(not trial_id.is_empty() and not richard_id.is_empty(), "彼界：理查登场测试初始化失败", failures)
	if trial_id.is_empty() or richard_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": richard_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：理查打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：理查打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	var trial_instance = state.card_instances.get(trial_id)
	_expect(int(trial_instance.flags.get("trial_progress", 0)) == 2, "彼界：理查登场时应使试炼+2", failures)
	_expect(int(state.card_instances[richard_id].flags.get("cannot_die_until_next_own_turn_start_player", -1)) == 0, "彼界：理查登场后应获得直到下个我方回合开始前的免死", failures)


static func _test_richard_attaches_squires_and_cashs_them_for_power(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_053", "bijie_s02_033", "bijie_s02_033"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 83066, [], _formal_options(2, 8, 0))
	var richard_id = _find_hand_card_by_definition(state, 0, "bijie_s02_053")
	var hand_squire_id = _find_hand_card_by_definition(state, 0, "bijie_s02_033")
	var deck_squire_id = _find_deck_card_by_definition(state, 0, "bijie_s02_033")
	var grave_squire_id = state.create_instance("bijie_s02_033", 0, 0)
	state.get_player(0).grave.add_card_to_top(grave_squire_id)
	state.card_instances[grave_squire_id].zone = "grave"
	state.card_instances[grave_squire_id].face = "face_up"
	_expect(not richard_id.is_empty() and not hand_squire_id.is_empty() and not deck_squire_id.is_empty(), "彼界：理查叠放侍从测试初始化失败", failures)
	if richard_id.is_empty() or hand_squire_id.is_empty() or deck_squire_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": richard_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：理查叠放侍从测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	if not _pending_choice_by_operation(state, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：理查登场时应可选择发动叠放侍从", failures)
	_expect(_resolve_candidate_choice(engine, state, "attach_matching_cards_under_source", [hand_squire_id, deck_squire_id, grave_squire_id]), "彼界：理查应可选择最多3张侍从骑士叠放到下方", failures)
	var richard_instance = state.card_instances.get(richard_id)
	_expect(richard_instance != null and richard_instance.attached_cards.size() == 3, "彼界：理查下方应有3张侍从骑士", failures)
	_expect(str(state.card_instances[hand_squire_id].zone) == "attached_underlay", "彼界：手牌侍从应变为理查下方牌", failures)
	_expect(str(state.card_instances[deck_squire_id].zone) == "attached_underlay", "彼界：牌库侍从应变为理查下方牌", failures)
	_expect(str(state.card_instances[grave_squire_id].zone) == "attached_underlay", "彼界：墓地侍从应变为理查下方牌", failures)
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": richard_id,
		"effect_id": "richard_discard_attached_for_power"
	}))
	_expect(bool(activate.get("ok", false)), "彼界：理查应可发动弃下方加攻效果", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_candidate_choice(engine, state, "discard_attached_cards_for_power_until_turn_end", [hand_squire_id, deck_squire_id]), "彼界：理查应可选择弃置下方侍从换兵力", failures)
	_expect(engine.get_card_power(state, richard_id) == 10000, "彼界：理查每弃置1张下方侍从应本回合获得+1000兵力", failures)
	_expect(state.get_player(0).grave.cards.has(hand_squire_id) and state.get_player(0).grave.cards.has(deck_squire_id), "彼界：被弃置的理查下方侍从应进入墓地", failures)
	_expect(state.card_instances[richard_id].attached_cards.size() == 1, "彼界：理查弃置两张下方侍从后应剩1张", failures)


static func _test_richard_attack_support_requires_extra_discard(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_053"], 10),
		_pad_deck(["qa_vanilla", "qa_vanilla", "qa_vanilla"], 10)
	], 83067, [], _formal_options(3, 8, 0))
	var richard_id = _find_hand_card_by_definition(state, 0, "bijie_s02_053")
	var enemy_front_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not richard_id.is_empty() and not enemy_front_id.is_empty(), "彼界：理查额外弃手防御测试初始化失败", failures)
	if richard_id.is_empty() or enemy_front_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": richard_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：理查额外弃手防御测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	if not _pending_choice_by_operation(state, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "彼界：理查额外弃手防御测试可跳过叠放侍从", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_front_id, "front", 0, "test_bijie_richard_enemy_front")
	var enemy_support_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	var enemy_discard_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	if enemy_discard_id == enemy_support_id:
		for card_id in state.get_player(1).hand.cards:
			var candidate_id = str(card_id)
			if candidate_id != enemy_support_id:
				enemy_discard_id = candidate_id
				break
	_expect(not enemy_support_id.is_empty() and not enemy_discard_id.is_empty(), "彼界：理查额外弃手防御测试敌方支援/弃牌初始化失败", failures)
	if enemy_support_id.is_empty() or enemy_discard_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_support_id, "back", 0, "test_bijie_richard_enemy_support")
	state.card_instances[richard_id].entered_turn = -1
	state.card_instances[richard_id].orientation = "active"
	state.card_instances[enemy_front_id].entered_turn = -1
	state.card_instances[enemy_front_id].orientation = "active"
	state.card_instances[enemy_support_id].entered_turn = -1
	state.card_instances[enemy_support_id].orientation = "active"
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": richard_id,
		"target_kind": "card",
		"target_player": 1,
		"defender_id": enemy_front_id
	}))
	_expect(bool(attack.get("ok", false)), "彼界：理查额外弃手防御测试宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	var legal_actions = engine.get_legal_actions(state, 1)
	var support_action := {}
	for action in legal_actions:
		if str(action.get("command_type", "")) != "ChooseDefense":
			continue
		var payload = action.get("payload_template", {})
		if str(payload.get("supporter_id", "")) == enemy_support_id and str(payload.get("extra_discard_card_id", "")) == enemy_discard_id:
			support_action = action
			break
	_expect(not support_action.is_empty(), "彼界：理查进攻时，敌方支援应要求额外弃置1张手牌", failures)
	if support_action.is_empty():
		return
	var choose = engine.apply_command(state, GameCommand.create(1, "ChooseDefense", support_action.get("payload_template", {})))
	_expect(bool(choose.get("ok", false)), "彼界：理查额外弃手防御测试选择支援失败", failures)
	if not bool(choose.get("ok", false)):
		return
	_resolve_pending_attack(engine, state)
	_expect(state.get_player(1).grave.cards.has(enemy_discard_id), "彼界：理查进攻时的额外弃牌应进入墓地", failures)
	_expect(state.get_player(1).grave.cards.has(enemy_support_id), "彼界：进行支援的军团应照常进入墓地", failures)


static func _test_crusade_grants_trial_legion_attack_no_loss(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_058", "bijie_s02_043"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8307, [], _formal_options(1, 4, 0))
	var crusade_id = _find_trial_card_by_definition(state, 0, "bijie_s02_058")
	var finn_id = _find_hand_card_by_definition(state, 0, "bijie_s02_043")
	_expect(not crusade_id.is_empty() and not finn_id.is_empty(), "彼界：十字军东征无损测试初始化失败", failures)
	if crusade_id.is_empty() or finn_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, finn_id, "front", 0, "test_bijie_crusade_trial_legion")
	state.card_instances[finn_id].orientation = "active"
	state.get_player(0).counters["rune"] = 1
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": crusade_id,
		"effect_id": "crusade_choose_mode"
	}))
	_expect(bool(activate.get("ok", false)), "彼界：十字军东征应可发动模式选择", failures)
	if not bool(activate.get("ok", false)):
		failures.append("彼界：十字军东征发动错误=%s %s" % [str(activate.get("code", "")), str(activate.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "trial_no_loss"), "彼界：十字军东征应可选择试炼军团无损分支", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：十字军东征无损分支应消耗1符文", failures)
	_expect(int(state.card_instances[finn_id].flags.get("temporary_keyword_attack_no_loss_turn", -1)) == state.turn_number, "彼界：十字军东征应令所选试炼军团本回合获得无损", failures)


static func _test_crusade_grants_richard_pierce_after_first_kill(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_058", "bijie_s02_053"], 10),
		_pad_deck(["qa_vanilla", "qa_vanilla"], 10)
	], 83075, [], _formal_options(1, 8, 0))
	var crusade_id = _find_trial_card_by_definition(state, 0, "bijie_s02_058")
	var richard_id = _find_hand_card_by_definition(state, 0, "bijie_s02_053")
	var first_enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not crusade_id.is_empty() and not richard_id.is_empty() and not first_enemy_id.is_empty(), "彼界：十字军东征理查贯穿测试初始化失败", failures)
	if crusade_id.is_empty() or richard_id.is_empty() or first_enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, first_enemy_id, "front", 0, "test_bijie_crusade_richard_first_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": richard_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：十字军东征理查贯穿测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	if not _pending_choice_by_operation(state, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "彼界：十字军东征理查贯穿测试可跳过理查叠放侍从", failures)
	state.get_player(0).counters["rune"] = 2
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": crusade_id,
		"effect_id": "crusade_choose_mode"
	}))
	_expect(bool(activate.get("ok", false)), "彼界：十字军东征理查贯穿分支应可发动", failures)
	if not bool(activate.get("ok", false)):
		failures.append("彼界：十字军东征理查贯穿分支发动错误=%s %s" % [str(activate.get("code", "")), str(activate.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "richard_pierce_on_kill"), "彼界：十字军东征应可选择理查击杀后获得贯穿分支", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：十字军东征理查贯穿分支应消耗2符文", failures)
	_expect(int(state.card_instances[richard_id].flags.get("kill_grant_keyword_until_turn_end_turn", -1)) == state.turn_number, "彼界：十字军东征应为理查设置本回合击杀后获得贯穿", failures)
	state.card_instances[richard_id].entered_turn = -1
	state.card_instances[richard_id].orientation = "active"
	var first_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": richard_id,
		"target_kind": "card",
		"target_player": 1,
		"defender_id": first_enemy_id
	}))
	_expect(bool(first_attack.get("ok", false)), "彼界：理查首次击杀宣告进攻失败", failures)
	if not bool(first_attack.get("ok", false)):
		failures.append("彼界：理查首次击杀宣告进攻错误=%s %s" % [str(first_attack.get("code", "")), str(first_attack.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	_expect(int(state.card_instances[richard_id].flags.get("temporary_keyword_pierce_turn", -1)) == state.turn_number, "彼界：理查首次击杀后应获得贯穿", failures)
	var second_enemy_id = state.create_instance("qa_vanilla", 1, 1)
	state.get_player(1).hand.add_card(second_enemy_id)
	engine._deploy_hand_card_to_slot(state, 1, second_enemy_id, "front", 0, "test_bijie_crusade_richard_second_enemy_setup")
	state.card_instances[richard_id].has_attacked_this_turn = false
	state.card_instances[richard_id].orientation = "active"
	state.card_instances[richard_id].entered_turn = -1
	var enemy_hp_before = state.get_player(1).master_hp
	var second_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": richard_id,
		"target_kind": "card",
		"target_player": 1,
		"defender_id": second_enemy_id
	}))
	_expect(bool(second_attack.get("ok", false)), "彼界：理查贯穿二次击杀宣告进攻失败", failures)
	if not bool(second_attack.get("ok", false)):
		failures.append("彼界：理查贯穿二次击杀宣告进攻错误=%s %s" % [str(second_attack.get("code", "")), str(second_attack.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(state.get_player(1).master_hp == enemy_hp_before - 1, "彼界：理查获得贯穿后再次击杀应额外对主宰造成1点伤害", failures)


static func _test_crusade_discards_and_returns_bijie_from_grave(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_058", "qa_vanilla", "bijie_s02_048"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8308, [], _formal_options(2, 4, 0))
	var crusade_id = _find_trial_card_by_definition(state, 0, "bijie_s02_058")
	var discard_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var recover_id = _find_hand_card_by_definition(state, 0, "bijie_s02_048")
	_expect(not crusade_id.is_empty() and not discard_id.is_empty() and not recover_id.is_empty(), "彼界：十字军东征回收测试初始化失败", failures)
	if crusade_id.is_empty() or discard_id.is_empty() or recover_id.is_empty():
		return
	state.get_player(0).hand.remove_card(recover_id)
	state.get_player(0).grave.add_card_to_top(recover_id)
	var recover_instance = state.card_instances.get(recover_id)
	if recover_instance != null:
		recover_instance.zone = "grave"
		recover_instance.position = {}
	state.get_player(0).counters["rune"] = 2
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": crusade_id,
		"effect_id": "crusade_choose_mode"
	}))
	_expect(bool(activate.get("ok", false)), "彼界：十字军东征回收分支应可发动", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "recover_bijie"), "彼界：十字军东征应可选择弃手回收彼界卡分支", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：十字军东征回收分支应消耗2符文", failures)
	_expect(not state.get_player(0).hand.cards.has(discard_id), "彼界：十字军东征回收分支应弃置1张手牌", failures)
	_expect(state.get_player(0).hand.cards.has(recover_id), "彼界：十字军东征应将墓地彼界卡加入手牌", failures)
	_expect(not state.get_player(0).grave.cards.has(recover_id), "彼界：十字军东征回收后目标不应仍留在墓地", failures)


static func _formal_options(opening_hand_size: int, opening_active_player_morale: int, opening_non_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": opening_non_active_player_morale
	}


static func _pad_deck(source: Array, minimum_size: int) -> Array:
	var padded: Array = []
	padded.append_array(source)
	while padded.size() < minimum_size:
		padded.append("qa_vanilla")
	return padded


static func _find_definition(definitions: Array, definition_id: String):
	for row in definitions:
		if row is Dictionary and str(row.get("id", "")) == definition_id:
			return row
	return null


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _find_deck_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).deck.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _find_trial_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).trial_zone.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _targets_include_card(targets: Array, defender_id: String) -> bool:
	for target in targets:
		if target is Dictionary and str(target.get("target_kind", "")) == "card" and str(target.get("defender_id", "")) == defender_id:
			return true
	return false


static func _pending_choice_by_operation(state, operation: String) -> Dictionary:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return {}


static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice.is_empty():
		return false
	return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("id", choice.get("choice_id", ""))),
		"selected_option": selected_option
	})).get("ok", false))


static func _resolve_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice.is_empty():
		return false
	return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("id", choice.get("choice_id", ""))),
		"selected_card_ids": selected_card_ids
	})).get("ok", false))


static func _resolve_pending_attack(engine: GameEngine, state) -> void:
	if state.pending_attack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if state.pending_attack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))


static func _pass_stack_pair(engine: GameEngine, state) -> void:
	if state.stack.is_empty() and state.pending_attack.is_empty() and state.pending_triggers.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if not state.pending_choices.is_empty() or (state.stack.is_empty() and state.pending_attack.is_empty() and state.pending_triggers.is_empty()):
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
