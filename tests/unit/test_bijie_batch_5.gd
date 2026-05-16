extends RefCounted
class_name TestBijieBatch5

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_definitions_load(failures)
	_test_robin_hood_entry_deploys_squire_from_deck(failures)
	_test_robin_hood_entry_deploys_squire_from_grave_and_attack_adds_rune(failures)
	_test_lancelot_entry_charge(failures)
	_test_lancelot_kill_advances_trial(failures)
	return failures


static func _test_definitions_load(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	_expect(_find_definition(definitions, "bijie_s02_039") != null, "彼界：未加载罗宾汉定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_054") != null, "彼界：未加载兰斯洛特定义", failures)


static func _test_robin_hood_entry_deploys_squire_from_deck(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_039", "bijie_s02_033", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8001, [], _formal_options(1, 3, 0))
	var robin_id = _find_hand_card_by_definition(state, 0, "bijie_s02_039")
	var squire_id = _find_deck_card_by_definition(state, 0, "bijie_s02_033")
	_expect(not robin_id.is_empty() and not squire_id.is_empty(), "彼界：罗宾汉牌库登场测试初始化失败", failures)
	if robin_id.is_empty() or squire_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": robin_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：罗宾汉打出失败（牌库侍从）", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：罗宾汉打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：罗宾汉应可确认发动登场拉侍从", failures)
	_expect(_resolve_candidate_choice(engine, state, "deploy_from_hand_deck_or_grave", [squire_id]), "彼界：罗宾汉应可从牌库选择侍从骑士", failures)
	_expect(_resolve_option_choice(engine, state, "deploy_selected_hand_or_grave_to_slot", "back:0"), "彼界：罗宾汉应可为牌库侍从选择登场位置", failures)
	_pass_stack_pair(engine, state)
	var squire_instance = state.card_instances.get(squire_id)
	_expect(squire_instance != null and str(squire_instance.zone) == "battle_back", "彼界：罗宾汉应将牌库中的侍从骑士活跃登场", failures)
	_expect(str(state.get_player(0).battle_back[0].occupant) == squire_id, "彼界：牌库中的侍从骑士应进入所选后排位置", failures)


static func _test_robin_hood_entry_deploys_squire_from_grave_and_attack_adds_rune(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_039", "bijie_s02_033", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8002, [], _formal_options(2, 3, 0))
	var robin_id = _find_hand_card_by_definition(state, 0, "bijie_s02_039")
	var squire_id = _find_hand_card_by_definition(state, 0, "bijie_s02_033")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not robin_id.is_empty() and not squire_id.is_empty() and not enemy_id.is_empty(), "彼界：罗宾汉墓地/进攻测试初始化失败", failures)
	if robin_id.is_empty() or squire_id.is_empty() or enemy_id.is_empty():
		return
	state.get_player(0).hand.remove_card(squire_id)
	state.get_player(0).grave.add_card_to_top(squire_id)
	var squire_instance = state.card_instances.get(squire_id)
	if squire_instance != null:
		squire_instance.zone = "grave"
		squire_instance.position = {}
		squire_instance.orientation = "active"
		squire_instance.controller = squire_instance.owner
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_robin_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": robin_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：罗宾汉打出失败（墓地侍从）", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：罗宾汉打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：罗宾汉墓地分支应可确认发动", failures)
	_expect(_resolve_candidate_choice(engine, state, "deploy_from_hand_deck_or_grave", [squire_id]), "彼界：罗宾汉应可从墓地选择侍从骑士", failures)
	_expect(_resolve_option_choice(engine, state, "deploy_selected_hand_or_grave_to_slot", "back:0"), "彼界：罗宾汉应可为墓地侍从选择登场位置", failures)
	_pass_stack_pair(engine, state)
	state.card_instances[robin_id].entered_turn = -1
	state.card_instances[robin_id].orientation = "active"
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": robin_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(attack.get("ok", false)), "彼界：罗宾汉宣告进攻失败", failures)
	if not bool(attack.get("ok", false)):
		failures.append("彼界：罗宾汉宣告进攻错误=%s %s" % [str(attack.get("code", "")), str(attack.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_resolve_pending_attack(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "彼界：罗宾汉进攻时应获得1符文", failures)


static func _test_lancelot_entry_charge(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_054", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8003, [], _formal_options(1, 8, 0))
	var lancelot_id = _find_hand_card_by_definition(state, 0, "bijie_s02_054")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not lancelot_id.is_empty() and not enemy_id.is_empty(), "彼界：兰斯洛特冲锋测试初始化失败", failures)
	if lancelot_id.is_empty() or enemy_id.is_empty():
		return
	state.get_player(0).counters["rune"] = 1
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_lancelot_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": lancelot_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：兰斯洛特打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：兰斯洛特打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：兰斯洛特应可确认消耗符文获得冲锋", failures)
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": lancelot_id,
		"target_kind": "card",
		"target_player": 1,
		"defender_id": enemy_id
	}))
	_expect(bool(attack.get("ok", false)), "彼界：兰斯洛特获得冲锋后应可当回合宣告进攻", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：兰斯洛特获得冲锋后应消耗1符文", failures)


static func _test_lancelot_kill_advances_trial(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_056", "bijie_s02_054"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8004, [], _formal_options(1, 8, 0))
	var lancelot_id = _find_hand_card_by_definition(state, 0, "bijie_s02_054")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	var trial_id = _find_trial_instance_by_definition(state, 0, "bijie_s02_056")
	_expect(not lancelot_id.is_empty() and not enemy_id.is_empty() and not trial_id.is_empty(), "彼界：兰斯洛特击杀测试初始化失败", failures)
	if lancelot_id.is_empty() or enemy_id.is_empty() or trial_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_lancelot_trial_enemy_setup")
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": lancelot_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：兰斯洛特打出失败（击杀测试）", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：兰斯洛特打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	if not _pending_choice_by_operation(state, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "彼界：兰斯洛特击杀测试应可跳过登场冲锋", failures)
	state.card_instances[lancelot_id].entered_turn = -1
	state.card_instances[lancelot_id].orientation = "active"
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": lancelot_id,
		"target_kind": "card",
		"target_player": 1,
		"defender_id": enemy_id
	}))
	_expect(bool(attack.get("ok", false)), "彼界：兰斯洛特宣告击杀进攻失败", failures)
	if not bool(attack.get("ok", false)):
		failures.append("彼界：兰斯洛特宣告进攻错误=%s %s" % [str(attack.get("code", "")), str(attack.get("message", ""))])
		return
	_resolve_pending_attack(engine, state)
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "advance_trial"), "彼界：兰斯洛特击杀后应可选择试炼+1", failures)
	_pass_stack_pair(engine, state)
	var trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and int(trial_instance.flags.get("trial_progress", 0)) == 1, "彼界：兰斯洛特选择试炼+1后应推进试炼", failures)


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


static func _find_trial_instance_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).trial_zone.cards:
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
