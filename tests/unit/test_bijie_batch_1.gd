extends RefCounted
class_name TestBijieBatch1

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_bijie_definitions_load_and_trial_extracts(failures)
	_test_elizabeth_entry_adds_rune(failures)
	_test_runic_power_adds_rune_and_searches(failures)
	_test_constance_and_squire_complete_trial_and_search(failures)
	_test_galahad_optional_entry_advances_trial(failures)
	return failures


static func _test_bijie_definitions_load_and_trial_extracts(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	_expect(_find_definition(definitions, "bijie_s02_033") != null, "彼界：未加载侍从骑士定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_034") != null, "彼界：未加载符文之力定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_037") != null, "彼界：未加载伊丽莎白·都铎定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_040") != null, "彼界：未加载康斯坦丝定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_041") != null, "彼界：未加载加拉哈德定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_056") != null, "彼界：未加载寻找圣杯之旅定义", failures)
	var engine := GameEngine.new()
	var state = engine.create_game(definitions, [
		_pad_deck(["bijie_s02_056", "bijie_s02_037", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7601, [], _formal_options(1, 0, 0))
	_expect(state.get_player(0).trial_zone.cards.size() == 1, "彼界：试炼卡应在开局被抽离至试炼区", failures)
	_expect(_find_hand_card_by_definition(state, 0, "bijie_s02_037") != "", "彼界：开局手牌应保留非试炼卡", failures)


static func _test_elizabeth_entry_adds_rune(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_037", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7602, [], _formal_options(1, 2, 0))
	var elizabeth_id = _find_hand_card_by_definition(state, 0, "bijie_s02_037")
	_expect(not elizabeth_id.is_empty(), "彼界：伊丽莎白·都铎测试初始化失败", failures)
	if elizabeth_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": elizabeth_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：伊丽莎白·都铎打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：伊丽莎白·都铎打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "彼界：伊丽莎白·都铎登场后应获得1符文", failures)
	_expect(_has_event_type(state, "RuneChanged"), "彼界：伊丽莎白·都铎登场应记录 RuneChanged", failures)


static func _test_runic_power_adds_rune_and_searches(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_034", "bijie_s02_033", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7603, [], _formal_options(1, 2, 0))
	var tactic_id = _find_hand_card_by_definition(state, 0, "bijie_s02_034")
	_expect(not tactic_id.is_empty(), "彼界：符文之力测试初始化失败", failures)
	if tactic_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(bool(play.get("ok", false)), "彼界：符文之力打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：符文之力打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "彼界：符文之力应先获得1符文", failures)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：符文之力应可选择是否追加发动", failures)
	var option_ok = _resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "search_bijie")
	_expect(option_ok, "彼界：符文之力应可选择发动检索", failures)
	if not option_ok:
		failures.append("彼界：符文之力未出现选项 choice_ops=%s" % str(_pending_choice_operations(state)))
	var choice = _pending_choice_by_operation(state, "search_deck")
	_expect(not choice.is_empty(), "彼界：符文之力应创建检索选择", failures)
	if choice.is_empty():
		return
	var selected_card_id := ""
	for raw_card_id in choice.get("candidate_card_ids", []):
		var card_id = str(raw_card_id)
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == "bijie_s02_033":
			selected_card_id = card_id
			break
	_expect(not selected_card_id.is_empty(), "彼界：符文之力检索候选中应包含侍从骑士", failures)
	if selected_card_id.is_empty():
		return
	_expect(_resolve_candidate_choice(engine, state, "search_deck", [selected_card_id]), "彼界：符文之力应能完成检索结算", failures)
	_expect(_find_hand_card_by_definition(state, 0, "bijie_s02_033") != "", "彼界：符文之力应将检索到的彼界卡加入手牌", failures)
	_expect(state.get_player(0).grave.cards.has(tactic_id), "彼界：符文之力结算后应进入墓地", failures)


static func _test_constance_and_squire_complete_trial_and_search(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_056", "bijie_s02_040", "bijie_s02_033", "bijie_s02_041", "bijie_s02_041"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7604, [], _formal_options(2, 3, 0))
	var trial_id = _find_trial_instance_by_definition(state, 0, "bijie_s02_056")
	var constance_id = _find_hand_card_by_definition(state, 0, "bijie_s02_040")
	var squire_id = _find_hand_card_by_definition(state, 0, "bijie_s02_033")
	_expect(not trial_id.is_empty() and not constance_id.is_empty() and not squire_id.is_empty(), "彼界：康斯坦丝/侍从骑士试炼测试初始化失败", failures)
	if trial_id.is_empty() or constance_id.is_empty() or squire_id.is_empty():
		return
	var constance_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": constance_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(constance_play.get("ok", false)), "彼界：康斯坦丝打出失败", failures)
	if not bool(constance_play.get("ok", false)):
		failures.append("彼界：康斯坦丝打出错误=%s %s" % [str(constance_play.get("code", "")), str(constance_play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "resolve_option_with_shared_cost", "advance_trial"), "彼界：康斯坦丝应可选择发动试炼", failures)
	var trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and int(trial_instance.flags.get("trial_progress", 0)) == 1, "彼界：康斯坦丝应使试炼进度+1", failures)
	engine._deploy_hand_card_to_slot(state, 0, squire_id, "front", 0, "test_bijie_squire_setup")
	var death_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_bijie_squire_die")
	engine.drain_until_waiting_for_input(state, death_events, "test_bijie_squire_die")
	_pass_stack_pair(engine, state)
	trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and int(trial_instance.flags.get("trial_progress", 0)) == 2, "彼界：侍从骑士阵亡后应再推进1次试炼", failures)
	_expect(trial_instance != null and bool(trial_instance.flags.get("trial_completed", false)), "彼界：侍从骑士应完成寻找圣杯之旅", failures)
	_expect(_has_event_type(state, "TrialCompleted"), "彼界：试炼完成应记录 TrialCompleted", failures)
	_expect(_has_trigger_queued(state, "holy_grail_complete_search"), "彼界：寻找圣杯之旅完成后应排队触发奖励效果", failures)
	_pass_stack_pair(engine, state)
	_pass_stack_pair(engine, state)
	for _i in range(6):
		_pass_stack_pair(engine, state)
	if not _pending_choice_by_operation(state, "optional_stack_effect").is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：寻找圣杯之旅奖励应可选择是否发动", failures)
		for _i in range(6):
			_pass_stack_pair(engine, state)
	var reward_choice = _pending_choice_by_operation(state, "search_deck")
	if not reward_choice.is_empty():
		var galahad_card_id := ""
		for raw_card_id in reward_choice.get("candidate_card_ids", []):
			var card_id = str(raw_card_id)
			var instance = state.card_instances.get(card_id)
			if instance != null and str(instance.definition_id) == "bijie_s02_041":
				galahad_card_id = card_id
				break
		_expect(not galahad_card_id.is_empty(), "彼界：寻找圣杯之旅奖励检索候选中应包含加拉哈德", failures)
		if not galahad_card_id.is_empty():
			_expect(_resolve_candidate_choice(engine, state, "search_deck", [galahad_card_id]), "彼界：寻找圣杯之旅奖励检索结算失败", failures)
	_expect(_find_hand_card_by_definition(state, 0, "bijie_s02_041") != "", "彼界：寻找圣杯之旅应将加拉哈德加入手牌", failures)


static func _test_galahad_optional_entry_advances_trial(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_056", "bijie_s02_041", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 7605, [], _formal_options(1, 3, 0))
	var trial_id = _find_trial_instance_by_definition(state, 0, "bijie_s02_056")
	var galahad_id = _find_hand_card_by_definition(state, 0, "bijie_s02_041")
	_expect(not trial_id.is_empty() and not galahad_id.is_empty(), "彼界：加拉哈德试炼测试初始化失败", failures)
	if trial_id.is_empty() or galahad_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": galahad_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：加拉哈德打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：加拉哈德应可确认发动登场试炼", failures)
	var trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and int(trial_instance.flags.get("trial_progress", 0)) == 1, "彼界：加拉哈德确认发动后应使试炼进度+1", failures)


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

static func _pending_choice_operations(state) -> Array[String]:
	var ops: Array[String] = []
	for choice in state.pending_choices:
		ops.append(str(choice.get("operation", "")))
	return ops

static func _pad_deck(source: Array, minimum_size: int) -> Array:
	var padded: Array = []
	padded.append_array(source)
	while padded.size() < minimum_size:
		padded.append("qa_vanilla")
	return padded


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


static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _has_trigger_queued(state, effect_id: String) -> bool:
	for event in state.event_log:
		if str(event.type) != "TriggerQueued":
			continue
		var payload = event.payload
		if payload is Dictionary and str(payload.get("effect_id", "")) == effect_id:
			return true
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
