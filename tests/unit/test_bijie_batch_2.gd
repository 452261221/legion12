extends RefCounted
class_name TestBijieBatch2

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_definitions_load(failures)
	_test_round_table_domain_search_and_buff(failures)
	_test_claudia_entry_optional_weaken(failures)
	_test_percival_attack_optional_discard_buff(failures)
	_test_percival_pierce_hits_master_after_second_kill(failures)
	return failures


static func _test_definitions_load(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	_expect(_find_definition(definitions, "bijie_s02_035") != null, "彼界：未加载克劳迪娅定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_036") != null, "彼界：未加载圆桌领域定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_044") != null, "彼界：未加载帕西瓦尔定义", failures)


static func _test_round_table_domain_search_and_buff(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_036", "bijie_s02_041", "bijie_s02_033"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7701, [], _formal_options(2, 3, 0))
	var galahad_id = _find_hand_card_by_definition(state, 0, "bijie_s02_041")
	var domain_id = _find_hand_card_by_definition(state, 0, "bijie_s02_036")
	_expect(not galahad_id.is_empty() and not domain_id.is_empty(), "彼界：圆桌领域测试初始化失败", failures)
	if galahad_id.is_empty() or domain_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, galahad_id, "front", 0, "test_bijie_round_table_domain_setup")
	var base_power = engine.get_card_power(state, galahad_id)
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": domain_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "彼界：圆桌领域打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：圆桌领域打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_find_hand_card_by_definition(state, 0, "bijie_s02_033") != "", "彼界：圆桌领域应将圆桌骑士加入手牌", failures)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "buff_round_table"), "彼界：圆桌领域应可选择强化圆桌骑士", failures)
	var buff_choice = _pending_choice_by_operation(state, "modify_power_until_turn_end")
	_expect(not buff_choice.is_empty(), "彼界：圆桌领域强化应请求选择目标", failures)
	if buff_choice.is_empty():
		return
	_expect(_resolve_candidate_choice(engine, state, "modify_power_until_turn_end", [galahad_id]), "彼界：圆桌领域强化选择失败", failures)
	_pass_stack_pair(engine, state)
	_expect(engine.get_card_power(state, galahad_id) == base_power + 2000, "彼界：圆桌领域应使圆桌骑士本回合+2000", failures)


static func _test_claudia_entry_optional_weaken(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_034", "bijie_s02_035", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7702, [], _formal_options(2, 3, 0))
	var runic_id = _find_hand_card_by_definition(state, 0, "bijie_s02_034")
	var claudia_id = _find_hand_card_by_definition(state, 0, "bijie_s02_035")
	var enemy_hand_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not runic_id.is_empty() and not claudia_id.is_empty() and not enemy_hand_id.is_empty(), "彼界：克劳迪娅测试初始化失败", failures)
	if runic_id.is_empty() or claudia_id.is_empty() or enemy_hand_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_hand_id, "front", 0, "test_bijie_claudia_enemy_setup")
	var enemy_base_power = engine.get_card_power(state, enemy_hand_id)
	var play_runic = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": runic_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play_runic.get("ok", false)), "彼界：符文之力打出失败（克劳迪娅前置）", failures)
	if not bool(play_runic.get("ok", false)):
		failures.append("彼界：符文之力打出错误=%s %s" % [str(play_runic.get("code", "")), str(play_runic.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "彼界：符文之力应提供1符文（克劳迪娅前置）", failures)
	_resolve_option_choice(engine, state, "optional_stack_effect", "no")
	var play_claudia = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": claudia_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play_claudia.get("ok", false)), "彼界：克劳迪娅打出失败", failures)
	if not bool(play_claudia.get("ok", false)):
		failures.append("彼界：克劳迪娅打出错误=%s %s" % [str(play_claudia.get("code", "")), str(play_claudia.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：克劳迪娅应可确认发动登场效果", failures)
	var weaken_choice = _pending_choice_by_operation(state, "modify_power_until_turn_end")
	_expect(not weaken_choice.is_empty(), "彼界：克劳迪娅应请求选择减益目标", failures)
	if weaken_choice.is_empty():
		return
	_expect(_resolve_candidate_choice(engine, state, "modify_power_until_turn_end", [enemy_hand_id]), "彼界：克劳迪娅选择减益目标失败", failures)
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：克劳迪娅发动后应消耗1符文", failures)
	_expect(engine.get_card_power(state, enemy_hand_id) == enemy_base_power - 2000, "彼界：克劳迪娅应使敌方军团本回合-2000", failures)


static func _test_percival_attack_optional_discard_buff(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_044", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7703, [], _formal_options(2, 4, 0))
	var percival_id = _find_hand_card_by_definition(state, 0, "bijie_s02_044")
	var discard_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var enemy_hand_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not percival_id.is_empty() and not discard_id.is_empty() and not enemy_hand_id.is_empty(), "彼界：帕西瓦尔测试初始化失败", failures)
	if percival_id.is_empty() or discard_id.is_empty() or enemy_hand_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_hand_id, "front", 0, "test_bijie_percival_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": percival_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：帕西瓦尔打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：帕西瓦尔打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	var base_power = engine.get_card_power(state, percival_id)
	state.card_instances[percival_id].entered_turn = -1
	state.card_instances[percival_id].orientation = "active"
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": percival_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "彼界：帕西瓦尔宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		failures.append("彼界：帕西瓦尔宣告进攻错误=%s %s" % [str(attack.get("code", "")), str(attack.get("message", ""))])
		return
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "彼界：帕西瓦尔应可确认弃牌强化本次进攻", failures)
	_expect(state.get_player(0).grave.cards.has(discard_id), "彼界：帕西瓦尔弃牌费用应自动弃置1张手牌", failures)
	_pass_stack_pair(engine, state)
	_expect(engine.get_card_power(state, percival_id) == base_power + 2000, "彼界：帕西瓦尔弃牌后应获得+2000（直到回合结束）", failures)


static func _test_percival_pierce_hits_master_after_second_kill(failures: Array[String]) -> void:
	# Verify the observable pierce result instead of depending on transient flag timing.
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_044", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla", "qa_vanilla"], 10)
	], 7704, [], _formal_options(2, 4, 0))
	var percival_id = _find_hand_card_by_definition(state, 0, "bijie_s02_044")
	var first_enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not percival_id.is_empty() and not first_enemy_id.is_empty(), "彼界：帕西瓦尔贯穿测试初始化失败", failures)
	if percival_id.is_empty() or first_enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, first_enemy_id, "front", 0, "test_bijie_percival_first_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": percival_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：帕西瓦尔贯穿测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	state.card_instances[percival_id].entered_turn = -1
	state.card_instances[percival_id].orientation = "active"
	var first_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": percival_id,
		"target_kind": "card",
		"target_player": 1,
		"defender_id": first_enemy_id
	}))
	_expect(bool(first_attack.get("ok", false)), "彼界：帕西瓦尔首次击杀宣告进攻失败", failures)
	if not bool(first_attack.get("ok", false)):
		return
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "no"), "彼界：帕西瓦尔首次击杀应可跳过弃牌强化", failures)
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	var second_enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not second_enemy_id.is_empty(), "彼界：帕西瓦尔第二次击杀初始化失败", failures)
	if second_enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, second_enemy_id, "front", 0, "test_bijie_percival_second_enemy_setup")
	state.card_instances[percival_id].has_attacked_this_turn = false
	state.card_instances[percival_id].orientation = "active"
	state.card_instances[percival_id].entered_turn = -1
	var enemy_hp_before = state.get_player(1).master_hp
	var second_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": percival_id,
		"target_kind": "card",
		"target_player": 1,
		"defender_id": second_enemy_id
	}))
	_expect(bool(second_attack.get("ok", false)), "彼界：帕西瓦尔贯穿二次击杀宣告进攻失败", failures)
	if not bool(second_attack.get("ok", false)):
		failures.append("彼界：帕西瓦尔贯穿二次击杀宣告进攻错误=%s %s" % [str(second_attack.get("code", "")), str(second_attack.get("message", ""))])
		return
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "no"), "彼界：帕西瓦尔贯穿二次击杀应可跳过弃牌强化", failures)
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	_expect(state.get_player(1).master_hp == enemy_hp_before - 1, "彼界：帕西瓦尔拥有贯穿后再次击杀应额外对主宰造成1点伤害", failures)


static func _formal_options(opening_hand_size: int, opening_active_player_morale: int, opening_non_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": opening_non_active_player_morale
	}


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


static func _pass_stack_pair(engine: GameEngine, state) -> void:
	if state.stack.is_empty() and state.pending_attack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))

static func _pad_deck(source: Array, minimum_size: int) -> Array:
	var padded: Array = []
	padded.append_array(source)
	while padded.size() < minimum_size:
		padded.append("qa_vanilla")
	return padded


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
