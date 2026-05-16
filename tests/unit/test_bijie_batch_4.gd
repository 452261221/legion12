extends RefCounted
class_name TestBijieBatch4

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_definitions_load(failures)
	_test_gwenllian_effect_death_draws(failures)
	_test_cu_chulainn_discount_and_entry_protection(failures)
	_test_scathach_discount_charge_and_attack_buff(failures)
	_test_bors_discount_and_attack_bonus(failures)
	_test_bors_death_discard(failures)
	return failures


static func _test_definitions_load(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	_expect(_find_definition(definitions, "bijie_s02_042") != null, "彼界：未加载格温莉安定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_046") != null, "彼界：未加载库丘林定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_047") != null, "彼界：未加载斯卡哈定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_049") != null, "彼界：未加载鲍斯定义", failures)


static func _test_gwenllian_effect_death_draws(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_042", "qa_executioner", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7901, [], _formal_options(2, 5, 0))
	var gwenllian_id = _find_hand_card_by_definition(state, 0, "bijie_s02_042")
	var executioner_id = _find_hand_card_by_definition(state, 0, "qa_executioner")
	_expect(not gwenllian_id.is_empty() and not executioner_id.is_empty(), "彼界：格温莉安测试初始化失败", failures)
	if gwenllian_id.is_empty() or executioner_id.is_empty():
		return
	var play_gwenllian = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": gwenllian_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play_gwenllian.get("ok", false)), "彼界：格温莉安打出失败", failures)
	if not bool(play_gwenllian.get("ok", false)):
		failures.append("彼界：格温莉安打出错误=%s %s" % [str(play_gwenllian.get("code", "")), str(play_gwenllian.get("message", ""))])
		return
	var play_executioner = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": executioner_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play_executioner.get("ok", false)), "彼界：QA 处决者打出失败（格温莉安前置）", failures)
	if not bool(play_executioner.get("ok", false)):
		failures.append("彼界：QA 处决者打出错误=%s %s" % [str(play_executioner.get("code", "")), str(play_executioner.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	var hand_before = state.get_player(0).hand.cards.size()
	var hp_before = state.get_player(0).master_hp
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": executioner_id,
		"effect_id": "destroy_unit",
		"target_card_id": gwenllian_id
	}))
	_expect(bool(activate.get("ok", false)), "彼界：QA 处决者发动失败（格温莉安前置）", failures)
	if not bool(activate.get("ok", false)):
		failures.append("彼界：QA 处决者发动错误=%s %s" % [str(activate.get("code", "")), str(activate.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：格温莉安因效果阵亡后应可确认发动奖励", failures)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "draw_card"), "彼界：格温莉安因效果阵亡后应可选择抽牌", failures)
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).grave.cards.has(gwenllian_id), "彼界：格温莉安应因效果进入墓地", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + 1, "彼界：格温莉安因效果阵亡后应抽1张牌", failures)
	_expect(state.get_player(0).master_hp == hp_before, "彼界：格温莉安选择抽牌时不应回复主宰生命", failures)


static func _test_cu_chulainn_discount_and_entry_protection(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_046", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7902, [], _formal_options(1, 5, 0))
	var cu_id = _find_hand_card_by_definition(state, 0, "bijie_s02_046")
	_expect(not cu_id.is_empty(), "彼界：库丘林测试初始化失败", failures)
	if cu_id.is_empty():
		return
	_expect(engine._get_effective_play_cost(state, cu_id) == 5, "彼界：库丘林在无斯卡哈时费用应为5", failures)
	var scathach_setup_id = state.create_instance("bijie_s02_047", 0, 0)
	state.get_player(0).hand.add_card(scathach_setup_id)
	engine._deploy_hand_card_to_slot(state, 0, scathach_setup_id, "back", 0, "test_bijie_cu_scathach_setup")
	_expect(engine._get_effective_play_cost(state, cu_id) == 3, "彼界：库丘林在有斯卡哈时费用应-2", failures)
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": cu_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：库丘林打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：库丘林打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).cost_area.cards.size()) == 2, "彼界：库丘林有斯卡哈时应只消耗3点士气", failures)
	var cu_instance = state.card_instances.get(cu_id)
	_expect(cu_instance != null and int(cu_instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) == 0, "彼界：库丘林登场后应获得直到下个我方回合开始前的免死", failures)
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not enemy_id.is_empty(), "彼界：库丘林贯穿测试初始化失败", failures)
	if enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_bijie_cu_pierce_enemy_setup")
	state.card_instances[cu_id].entered_turn = -1
	state.card_instances[cu_id].orientation = "active"
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": cu_id,
		"target_kind": "card",
		"target_player": 1,
		"defender_id": enemy_id
	}))
	_expect(bool(attack.get("ok", false)), "彼界：库丘林贯穿测试宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	_expect(int(state.card_instances[cu_id].flags.get("temporary_keyword_pierce_turn", -1)) == state.turn_number, "彼界：库丘林击杀后应在本回合获得贯穿", failures)


static func _test_scathach_discount_charge_and_attack_buff(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_047", "bijie_s02_034", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7903, [], _formal_options(2, 6, 0))
	var scathach_id = _find_hand_card_by_definition(state, 0, "bijie_s02_047")
	var runic_id = _find_hand_card_by_definition(state, 0, "bijie_s02_034")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not scathach_id.is_empty() and not runic_id.is_empty() and not enemy_id.is_empty(), "彼界：斯卡哈测试初始化失败", failures)
	if scathach_id.is_empty() or runic_id.is_empty() or enemy_id.is_empty():
		return
	_expect(engine._get_effective_play_cost(state, scathach_id) == 5, "彼界：斯卡哈在无库丘林时费用应为5", failures)
	var cu_setup_id = state.create_instance("bijie_s02_046", 0, 0)
	state.get_player(0).hand.add_card(cu_setup_id)
	engine._deploy_hand_card_to_slot(state, 0, cu_setup_id, "back", 0, "test_bijie_scathach_cu_setup")
	_expect(engine._get_effective_play_cost(state, scathach_id) == 3, "彼界：斯卡哈在有库丘林时费用应-2", failures)
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_bijie_scathach_enemy_setup")
	var play_runic = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": runic_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play_runic.get("ok", false)), "彼界：符文之力打出失败（斯卡哈前置）", failures)
	if not bool(play_runic.get("ok", false)):
		failures.append("彼界：符文之力打出错误=%s %s" % [str(play_runic.get("code", "")), str(play_runic.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_resolve_option_choice(engine, state, "optional_stack_effect", "no")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": scathach_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(play.get("ok", false)), "彼界：斯卡哈打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：斯卡哈打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).cost_area.cards.size()) == 2, "彼界：斯卡哈有库丘林时应只消耗3点士气", failures)
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": scathach_id,
		"target_kind": "card",
		"target_player": 1,
		"target_card_id": enemy_id
	}))
	_expect(bool(attack.get("ok", false)), "彼界：斯卡哈登场后本回合应因冲锋可立刻宣告进攻", failures)
	if not bool(attack.get("ok", false)):
		failures.append("彼界：斯卡哈宣告进攻错误=%s %s" % [str(attack.get("code", "")), str(attack.get("message", ""))])
		return
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "彼界：斯卡哈应可确认消耗符文强化进攻", failures)
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：斯卡哈发动进攻效果后应消耗1符文", failures)
	_expect(engine.get_card_power(state, scathach_id) == 6000, "彼界：斯卡哈发动后应获得+2000", failures)
	_expect(_has_attack_keyword(state, scathach_id, "attack_no_loss"), "彼界：斯卡哈发动后应获得进攻无损", failures)


static func _test_bors_discount_and_attack_bonus(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_049", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7904, [], _formal_options(2, 7, 2))
	var bors_id = _find_hand_card_by_definition(state, 0, "bijie_s02_049")
	_expect(not bors_id.is_empty(), "彼界：鲍斯测试初始化失败", failures)
	if bors_id.is_empty():
		return
	_expect(engine._get_effective_play_cost(state, bors_id) == 6, "彼界：鲍斯初始费用应为6", failures)
	var bijie_setup_a = state.create_instance("bijie_s02_037", 0, 0)
	var bijie_setup_b = state.create_instance("bijie_s02_042", 0, 0)
	state.get_player(0).hand.add_card(bijie_setup_a)
	state.get_player(0).hand.add_card(bijie_setup_b)
	engine._deploy_hand_card_to_slot(state, 0, bijie_setup_a, "front", 0, "test_bijie_bors_setup_a")
	engine._deploy_hand_card_to_slot(state, 0, bijie_setup_b, "back", 0, "test_bijie_bors_setup_b")
	_expect(engine._get_effective_play_cost(state, bors_id) == 4, "彼界：鲍斯应按彼界军团数量减费", failures)
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": bors_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(play.get("ok", false)), "彼界：鲍斯打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：鲍斯打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).cost_area.cards.size()) == 3, "彼界：鲍斯减费后应只消耗4点士气", failures)
	state.card_instances[bors_id].entered_turn = -1
	state.card_instances[bors_id].orientation = "active"
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": bors_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "彼界：鲍斯宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		failures.append("彼界：鲍斯宣告进攻错误=%s %s" % [str(attack.get("code", "")), str(attack.get("message", ""))])
		return
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "彼界：鲍斯应可确认消耗士气获得强攻", failures)
	_pass_stack_pair(engine, state)
	_resolve_pending_attack(engine, state)
	_expect(state.get_player(1).master_hp == 18, "彼界：鲍斯获得强攻后应对主宰造成2点伤害", failures)


static func _test_bors_death_discard(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_049"], 10),
		_pad_deck(["qa_vanilla", "qa_vanilla"], 10)
	], 7905, [], _formal_options(1, 6, 2))
	var bors_id = _find_hand_card_by_definition(state, 0, "bijie_s02_049")
	_expect(not bors_id.is_empty(), "彼界：鲍斯阵亡测试初始化失败", failures)
	if bors_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": bors_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：鲍斯阵亡测试打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：鲍斯阵亡测试打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	var enemy_hand_before = state.get_player(1).hand.cards.size()
	var enemy_discard_id = str(state.get_player(1).hand.cards[0])
	var death_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_bijie_bors_death")
	engine.drain_until_waiting_for_input(state, death_events, "test_bijie_bors_death")
	_pass_stack_pair(engine, state)
	_expect(_pending_choice_by_operation(state, "discard_from_hand").is_empty() == false, "彼界：鲍斯阵亡后应要求对方弃置手牌", failures)
	_expect(_resolve_candidate_choice(engine, state, "discard_from_hand", [enemy_discard_id]), "彼界：鲍斯阵亡弃牌结算失败", failures)
	_expect(state.get_player(1).hand.cards.size() == enemy_hand_before - 1, "彼界：鲍斯阵亡后对方应弃置1张手牌", failures)


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


static func _has_attack_keyword(state, card_id: String, keyword: String) -> bool:
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	var definition = state.get_definition(instance.definition_id)
	if definition == null:
		return false
	if definition.keywords.has(keyword) or definition.traits.has(keyword):
		return true
	return int(instance.flags.get("temporary_keyword_%s_turn" % keyword, -1)) == state.turn_number


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
