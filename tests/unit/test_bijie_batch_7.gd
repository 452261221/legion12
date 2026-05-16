extends RefCounted
class_name TestBijieBatch7

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_definitions_load(failures)
	_test_finn_entry_trial_and_rune_ready(failures)
	_test_lady_lake_complete_returns_arthur_and_prepares_discount(failures)
	_test_lady_lake_excalibur_substitutes_lethal_once(failures)
	return failures


static func _test_definitions_load(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	_expect(_find_definition(definitions, "bijie_s02_043") != null, "彼界：未加载芬恩定义", failures)
	_expect(_find_definition(definitions, "bijie_s02_055") != null, "彼界：未加载湖中仙女的馈赠定义", failures)


static func _test_finn_entry_trial_and_rune_ready(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_055", "bijie_s02_043"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8201, [], _formal_options(1, 4, 0))
	var finn_id = _find_hand_card_by_definition(state, 0, "bijie_s02_043")
	var trial_id = _find_trial_card_by_definition(state, 0, "bijie_s02_055")
	_expect(not finn_id.is_empty() and not trial_id.is_empty(), "彼界：芬恩测试初始化失败", failures)
	if finn_id.is_empty() or trial_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": finn_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：芬恩打出失败", failures)
	if not bool(play.get("ok", false)):
		failures.append("彼界：芬恩打出错误=%s %s" % [str(play.get("code", "")), str(play.get("message", ""))])
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：芬恩应可选择发动试炼", failures)
	var trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and int(trial_instance.flags.get("trial_progress", 0)) == 1, "彼界：芬恩登场后应推进试炼", failures)
	var finn_instance = state.card_instances.get(finn_id)
	_expect(finn_instance != null and str(finn_instance.orientation) == "rested", "彼界：芬恩登场后应先处于休整", failures)
	state.get_player(0).counters["rune"] = 1
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：芬恩发动试炼后应可消耗1符文转为活跃", failures)
	finn_instance = state.card_instances.get(finn_id)
	_expect(finn_instance != null and str(finn_instance.orientation) == "active", "彼界：芬恩发动试炼后应转为活跃", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "彼界：芬恩转为活跃应消耗1符文", failures)


static func _test_lady_lake_complete_returns_arthur_and_prepares_discount(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_055", "bijie_s02_050", "bijie_s02_034", "qa_vanilla"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8202, [], _formal_options(2, 4, 0))
	var trial_id = _find_trial_card_by_definition(state, 0, "bijie_s02_055")
	var arthur_id = _find_hand_card_by_definition(state, 0, "bijie_s02_050")
	_expect(not trial_id.is_empty() and not arthur_id.is_empty(), "彼界：湖中仙女的馈赠测试初始化失败", failures)
	if trial_id.is_empty() or arthur_id.is_empty():
		return
	state.get_player(0).hand.remove_card(arthur_id)
	state.get_player(0).grave.add_card_to_top(arthur_id)
	var arthur_instance = state.card_instances.get(arthur_id)
	if arthur_instance != null:
		arthur_instance.zone = "grave"
		arthur_instance.position = {}
		arthur_instance.orientation = "active"
	var trial_instance = state.card_instances.get(trial_id)
	if trial_instance != null:
		trial_instance.flags["trial_progress"] = 2
		trial_instance.flags["trial_completed"] = true
	var complete_event = engine._append_logged_event(state, "TrialCompleted", 0, {
		"card_id": trial_id,
		"source_card_id": trial_id,
		"progress": 2
	}, "test_bijie_lady_lake_complete")
	engine.drain_until_waiting_for_input(state, [complete_event], "test_bijie_lady_lake_complete")
	_pass_stack_pair(engine, state)
	var reward_optional = _pending_choice_by_operation(state, "optional_stack_effect")
	if not reward_optional.is_empty():
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：湖中仙女的馈赠完成时应可选择发动", failures)
	_pass_stack_pair(engine, state)
	var return_choice = _pending_choice_by_operation(state, "return_from_deck_or_grave_to_hand")
	if not return_choice.is_empty():
		_expect(_resolve_candidate_choice(engine, state, "return_from_deck_or_grave_to_hand", [arthur_id]), "彼界：湖中仙女的馈赠应可选择墓地亚瑟王加入手牌", failures)
	_pass_stack_pair(engine, state)
	_expect(state.get_player(0).hand.cards.has(arthur_id), "彼界：湖中仙女的馈赠应将亚瑟王加入手牌", failures)
	_expect(not state.get_player(0).grave.cards.has(arthur_id), "彼界：湖中仙女的馈赠应先将选中的亚瑟王移出墓地", failures)
	_expect(engine.get_card_power(state, arthur_id) == 5000, "彼界：亚瑟王回手后不应残留战场加成", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": arthur_id,
		"row": "front",
		"col": 0
	})).get("ok", false), "彼界：湖中仙女的馈赠准备的亚瑟王减费应使其本回合可被打出", failures)


static func _test_lady_lake_excalibur_substitutes_lethal_once(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		_pad_deck(["bijie_s02_055", "bijie_s02_050"], 10),
		_pad_deck(["qa_vanilla"], 10)
	], 8203, [], _formal_options(1, 6, 0))
	var arthur_id = _find_hand_card_by_definition(state, 0, "bijie_s02_050")
	_expect(not arthur_id.is_empty(), "彼界：亚瑟王王者之剑代死测试初始化失败", failures)
	if arthur_id.is_empty():
		return
	state.get_player(0).counters["rune"] = 1
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": arthur_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(play.get("ok", false)), "彼界：亚瑟王代死测试打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "彼界：亚瑟王代死测试应可装备王者之剑", failures)
	var first_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_bijie_lady_lake_first_lethal")
	_expect(_event_types_include(first_events, "CardDeathPrevented"), "彼界：王者之剑应代替亚瑟王承受首次致命结果", failures)
	_expect(str(state.get_player(0).battle_front[0].occupant) == arthur_id, "彼界：首次致命后亚瑟王应仍留在战场", failures)
	var arthur_instance = state.card_instances.get(arthur_id)
	_expect(arthur_instance != null and str(arthur_instance.flags.get("attached_underlay_token_id", "")).is_empty(), "彼界：首次代死后王者之剑应被移除", failures)
	var second_events = ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_bijie_lady_lake_second_lethal")
	_expect(_event_types_include(second_events, "CardSentToGrave"), "彼界：失去王者之剑后亚瑟王再次致命应正常阵亡", failures)
	_expect(str(state.get_player(0).battle_front[0].occupant) == "", "彼界：第二次致命后亚瑟王应离开战场", failures)


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


static func _find_trial_card_by_definition(state, player_id: int, definition_id: String) -> String:
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


static func _event_types_include(events: Array, event_type: String) -> bool:
	for event in events:
		if str(event.type) == event_type:
			return true
	return false


static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false


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
