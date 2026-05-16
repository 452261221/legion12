extends RefCounted
class_name TestBijieBatch3

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_merlin_entry_and_prepare_weaken(failures)
	_test_merlin_prepare_search_tactic(failures)
	return failures


static func _test_merlin_entry_and_prepare_weaken(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_045", "qa_vanilla"], 10),
		_pad_deck(["dev_legion_alpha"], 10)
	], 7801, [], _formal_options(1, 6, 6))
	var merlin_id = _find_hand_card_by_definition(state, 0, "bijie_s02_045")
	var enemy_id = _find_hand_card_by_definition(state, 1, "dev_legion_alpha")
	_expect(not merlin_id.is_empty() and not enemy_id.is_empty(), "彼界：梅林测试初始化失败", failures)
	if merlin_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_bijie_merlin_enemy_setup")
	var enemy_base_power = engine.get_card_power(state, enemy_id)
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": merlin_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：梅林打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：梅林打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "彼界：梅林登场应获得1符文", failures)
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": merlin_id,
		"effect_id": "merlin_prepare_choice"
	}))
	_expect(bool(activate.get("ok", false)), "彼界：梅林主动休整发动失败", failures)
	if not bool(activate.get("ok", false)):
		failures.append("彼界：梅林主动休整错误=%s %s" % [str(activate.get("code", "")), str(activate.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "weaken_enemy"), "彼界：梅林应可选择敌方军团-3000", failures)
	var choice = _pending_choice_by_operation(state, "modify_power_until_turn_end")
	_expect(not choice.is_empty(), "彼界：梅林减益应请求选择目标", failures)
	if choice.is_empty():
		return
	_expect(_resolve_candidate_choice(engine, state, "modify_power_until_turn_end", [enemy_id]), "彼界：梅林减益目标选择失败", failures)
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：梅林主动休整应消耗1符文", failures)
	_expect(engine.get_card_power(state, enemy_id) == enemy_base_power - 3000, "彼界：梅林应使敌方军团本回合-3000", failures)


static func _test_merlin_prepare_search_tactic(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_045", "dev_tactic_bolt", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7802, [], _formal_options(1, 6, 0))
	var merlin_id = _find_hand_card_by_definition(state, 0, "bijie_s02_045")
	_expect(not merlin_id.is_empty(), "彼界：梅林检索战术测试初始化失败", failures)
	if merlin_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": merlin_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：梅林打出失败（检索战术）", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：梅林打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "彼界：梅林登场应获得1符文（检索战术）", failures)
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": merlin_id,
		"effect_id": "merlin_prepare_choice"
	}))
	_expect(bool(activate.get("ok", false)), "彼界：梅林主动休整发动失败（检索战术）", failures)
	if not bool(activate.get("ok", false)):
		failures.append("彼界：梅林主动休整错误=%s %s" % [str(activate.get("code", "")), str(activate.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "search_tactic"), "彼界：梅林应可选择检索主动战术", failures)
	_pass_stack_pair(engine, state)
	var search_choice = _pending_choice_by_operation(state, "search_deck")
	if not search_choice.is_empty():
		var bolt_id := ""
		for raw_card_id in search_choice.get("candidate_card_ids", []):
			var card_id = str(raw_card_id)
			var instance = state.card_instances.get(card_id)
			if instance != null and str(instance.definition_id) == "dev_tactic_bolt":
				bolt_id = card_id
				break
		_expect(not bolt_id.is_empty(), "彼界：梅林检索候选应包含测试战术", failures)
		if not bolt_id.is_empty():
			_expect(_resolve_candidate_choice(engine, state, "search_deck", [bolt_id]), "彼界：梅林检索战术结算失败", failures)
	_expect(_find_hand_card_by_definition(state, 0, "dev_tactic_bolt") != "", "彼界：梅林应将战术加入手牌", failures)


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
	if state.stack.is_empty() and state.pending_attack.is_empty() and state.pending_triggers.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
