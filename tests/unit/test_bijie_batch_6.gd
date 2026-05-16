extends RefCounted
class_name TestBijieBatch6

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_definitions_load(failures)
	_test_arthur_entry_attaches_excalibur_and_gains_strong_attack(failures)
	_test_arthur_death_deploys_low_cost_round_table_from_hand(failures)
	_test_jeanne_entry_protects_master_from_attack(failures)
	_test_jeanne_death_heals_both_masters(failures)
	return failures


static func _test_definitions_load(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	_expect(_find_definition(definitions, "bijie_s02_050") != null, "彼界：未加载亚瑟王定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_051") != null, "彼界：未加载圣女贞德定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_059") != null, "彼界：未加载王者之剑定义", failures)


static func _test_arthur_entry_attaches_excalibur_and_gains_strong_attack(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_050"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8101, [], _formal_options(1, 6, 0))
	var arthur_id = _find_hand_card_by_definition(state, 0, "bijie_s02_050")
	_expect(not arthur_id.is_empty(), "彼界：亚瑟王王者之剑测试初始化失败", failures)
	if arthur_id.is_empty():
		return
	state.get_player(0).counters["rune"] = 1
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": arthur_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：亚瑟王打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：亚瑟王打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：亚瑟王应可确认消耗1符文装备王者之剑", failures)
	var arthur_instance = state.card_instances.get(arthur_id)
	var sword_id = str(arthur_instance.flags.get("attached_underlay_token_id", "")) if arthur_instance != null else ""
	var sword_instance = state.card_instances.get(sword_id)
	_expect(not sword_id.is_empty() and sword_instance != null and str(sword_instance.definition_id) == "bijie_s02_059", "彼界：亚瑟王应附着王者之剑", failures)
	_expect(engine.get_card_power(state, arthur_id) == 6000, "彼界：亚瑟王附着王者之剑后应获得+1000兵力", failures)
	state.card_instances[arthur_id].entered_turn = -1
	state.card_instances[arthur_id].orientation = "active"
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": arthur_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "彼界：亚瑟王装备王者之剑后应可宣告攻击主宰", failures)
	if not bool(attack.get("ok", false)):
		failures.append("彼界：亚瑟王宣告进攻错误=%s %s" % [str(attack.get("code", "")), str(attack.get("message", ""))])
		return
	_resolve_pending_attack(engine, state)
	_expect(int(state.get_player(1).master_hp) == 18, "彼界：亚瑟王装备王者之剑后应因强攻造成2点主宰伤害", failures)


static func _test_arthur_death_deploys_low_cost_round_table_from_hand(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_050", "bijie_s02_041"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8102, [], _formal_options(2, 6, 0))
	var arthur_id = _find_hand_card_by_definition(state, 0, "bijie_s02_050")
	var galahad_id = _find_hand_card_by_definition(state, 0, "bijie_s02_041")
	_expect(not arthur_id.is_empty() and not galahad_id.is_empty(), "彼界：亚瑟王阵亡登场测试初始化失败", failures)
	if arthur_id.is_empty() or galahad_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": arthur_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：亚瑟王阵亡登场测试打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：亚瑟王阵亡登场测试打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	if not _pending_choice_by_operation(state, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "彼界：亚瑟王阵亡登场测试应可跳过入场装备王者之剑", failures)
	var death_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_bijie_arthur_death")
	engine.drain_until_waiting_for_input(state, death_events, "test_bijie_arthur_death")
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：亚瑟王阵亡后应可确认登场圆桌骑士", failures)
	_expect(_resolve_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [galahad_id]), "彼界：亚瑟王阵亡后应可选择加拉哈德登场", failures)
	_expect(_resolve_option_choice(engine, state, "deploy_selected_hand_to_slot", "front:0"), "彼界：亚瑟王阵亡后应可为加拉哈德选择登场位置", failures)
	var galahad_instance = state.card_instances.get(galahad_id)
	_expect(galahad_instance != null and str(galahad_instance.zone) == "battle_front", "彼界：亚瑟王阵亡后应将低费圆桌骑士活跃登场", failures)
	_expect(str(state.get_player(0).battle_front[0].occupant) == galahad_id, "彼界：亚瑟王阵亡后应将加拉哈德登场到所选位置", failures)


static func _test_jeanne_entry_protects_master_from_attack(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["qa_vanilla", "bijie_s02_051"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8103, [], _formal_options(2, 6, 0))
	var jeanne_id = _find_hand_card_by_definition(state, 0, "bijie_s02_051")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not jeanne_id.is_empty() and not enemy_id.is_empty(), "彼界：圣女贞德保护主宰测试初始化失败", failures)
	if jeanne_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_jeanne_enemy_setup")
	state.card_instances[enemy_id].entered_turn = -1
	state.card_instances[enemy_id].orientation = "active"
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": jeanne_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：圣女贞德打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：圣女贞德打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：圣女贞德应可确认弃牌保护主宰", failures)
	engine._begin_turn_for_player(state, 1)
	var attack = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": enemy_id,
		"target_kind": "master",
		"target_player": 0
	}))
	_expect(not bool(attack.get("ok", false)), "彼界：受圣女贞德保护时对方不应可进攻我方主宰", failures)
	_expect(str(attack.get("code", "")) == "MASTER_ATTACK_FORBIDDEN", "彼界：圣女贞德主宰保护应拦截主宰攻击", failures)


static func _test_jeanne_death_heals_both_masters(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_051"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8104, [], _formal_options(1, 6, 0))
	var jeanne_id = _find_hand_card_by_definition(state, 0, "bijie_s02_051")
	_expect(not jeanne_id.is_empty(), "彼界：圣女贞德阵亡回血测试初始化失败", failures)
	if jeanne_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": jeanne_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：圣女贞德阵亡回血测试打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：圣女贞德阵亡回血测试打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	if not _pending_choice_by_operation(state, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "彼界：圣女贞德回血测试应可跳过入场保护", failures)
	state.get_player(0).master_hp = 18
	state.get_player(1).master_hp = 17
	var death_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_bijie_jeanne_death")
	engine.drain_until_waiting_for_input(state, death_events, "test_bijie_jeanne_death")
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).master_hp) == 19, "彼界：圣女贞德阵亡时我方主宰应回复1血", failures)
	_expect(int(state.get_player(1).master_hp) == 18, "彼界：圣女贞德阵亡时对方主宰也应回复1血", failures)


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


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
