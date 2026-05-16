extends RefCounted
class_name TestOlympusBatch1

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_olympus_faction_flip_and_prometheus_search(failures)
	_test_plato_entry_search_and_bottom_reorder(failures)
	_test_glory_road_divine_flip_search(failures)
	return failures


static func _test_olympus_faction_flip_and_prometheus_search(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0514", "olympus_s02_0522", "olympus_s02_0502"],
		["olympus_s02_0508"]
	], 7101, [
		{"name": "P0", "master_name": "普罗米修斯", "master_id": "olympus_s02_05m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(0, 3, 3))
	var flip_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "morale_0",
		"effect_id": "olympus_morale_flip"
	}))
	_expect(bool(flip_result.get("ok", false)), "奥林匹斯阵营效果：翻转士气能力无法发动", failures)
	if not bool(flip_result.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var flipped_id = str(state.get_player(0).cost_area.cards[0])
	_expect(_resolve_first_candidate_choice(engine, state, "olympus_flip_morale_pick", [flipped_id]), "奥林匹斯阵营效果：未能选择要翻转的士气", failures)
	_expect(MoraleActions.count_active_divine_morale(state, 0) == 1, "奥林匹斯阵营效果：应得到1张活跃神力", failures)

	var search_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "prometheus_search_top"
	}))
	_expect(bool(search_result.get("ok", false)), "普罗米修斯：检索能力无法发动", failures)
	if not bool(search_result.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var heracles_top = _find_top_deck_instance_id_by_definition(state, 0, "olympus_s02_0502")
	_expect(not heracles_top.is_empty(), "普罗米修斯：牌库顶部应包含赫拉克勒斯供选择", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "olympus_revealed_pick_to_hand", [heracles_top]), "普罗米修斯：未能选择加入手牌的奥林匹斯卡牌", failures)
	var nyx_top = _find_top_deck_instance_id_by_definition(state, 0, "olympus_s02_0522")
	var plato_top = _find_top_deck_instance_id_by_definition(state, 0, "olympus_s02_0514")
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [plato_top]), "普罗米修斯：未能选择放回牌库顶部的剩余卡", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "top"), "普罗米修斯：未能将柏拉图放回顶部", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "tianting_reorder_pick_next_card", [nyx_top]), "普罗米修斯：未能选择放回牌库底部的倪克斯的陨星", failures)
	_expect(_resolve_first_option_choice(engine, state, "tianting_reorder_choose_destination", "bottom"), "普罗米修斯：未能将倪克斯的陨星放回底部", failures)
	_expect(_has_card_in_hand_definition(state, 0, "olympus_s02_0502"), "普罗米修斯：应将赫拉克勒斯加入手牌", failures)
	_expect(str(state.get_player(0).deck.cards[0]) == plato_top, "普罗米修斯：柏拉图应回到牌库顶部", failures)
	_expect(str(state.get_player(0).deck.cards[-1]) == nyx_top, "普罗米修斯：倪克斯的陨星应回到牌库底部", failures)
	_expect(MoraleActions.count_active_divine_morale(state, 0) == 0, "普罗米修斯：支付神力后不应保留活跃神力", failures)
	_expect(MoraleActions.count_divine_morale(state, 0) == 1, "普罗米修斯：支付神力不应把神力翻回普通士气", failures)


static func _test_plato_entry_search_and_bottom_reorder(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0514", "olympus_s02_0502", "olympus_s02_0522", "olympus_s02_0508"],
		["olympus_s02_0508"]
	], 7102, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(1, 3, 3))
	var plato_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0514")
	_expect(not plato_id.is_empty(), "柏拉图：测试初始化失败（未抽到柏拉图）", failures)
	if plato_id.is_empty():
		return
	var play_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": plato_id,
		"row": "back",
		"col": 0
	}))
	_expect(bool(play_result.get("ok", false)), "柏拉图：打出失败", failures)
	if not bool(play_result.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "柏拉图：未能确认发动登场检索效果", failures)
	var heracles_id = _find_top_deck_instance_id_by_definition(state, 0, "olympus_s02_0502")
	var nyx_id = _find_top_deck_instance_id_by_definition(state, 0, "olympus_s02_0522")
	var atalanta_id = _find_top_deck_instance_id_by_definition(state, 0, "olympus_s02_0508")
	_expect(_resolve_first_candidate_choice(engine, state, "olympus_revealed_pick_to_hand", [heracles_id]), "柏拉图：未能选择加入手牌的卡牌", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "olympus_reorder_bottom_pick", [atalanta_id]), "柏拉图：未能选择第一张置底卡牌", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "olympus_reorder_bottom_pick", [nyx_id]), "柏拉图：未能选择第二张置底卡牌", failures)
	_expect(_has_card_in_hand_definition(state, 0, "olympus_s02_0502"), "柏拉图：应将赫拉克勒斯加入手牌", failures)
	_expect(state.get_player(0).deck.cards.size() >= 2 and str(state.get_player(0).deck.cards[-2]) == atalanta_id and str(state.get_player(0).deck.cards[-1]) == nyx_id, "柏拉图：剩余卡应按选择顺序回到底部", failures)


static func _test_glory_road_divine_flip_search(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0521", "olympus_s02_0502", "olympus_s02_0522"],
		["olympus_s02_0508"]
	], 7103, [
		{"name": "P0", "master_name": "普罗米修斯", "master_id": "olympus_s02_05m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(1, 6, 6))
	var glory_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0521")
	_expect(not glory_id.is_empty(), "荣耀之路：测试初始化失败（未抽到荣耀之路）", failures)
	if glory_id.is_empty():
		return
	var divine_seed: Array[String] = []
	divine_seed.append(str(state.get_player(0).cost_area.cards[4]))
	divine_seed.append(str(state.get_player(0).cost_area.cards[5]))
	MoraleActions.flip_morale_cards(state, 0, divine_seed, true, "test_glory_setup")
	var play_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": glory_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "glory_search_olympus"
	}))
	_expect(bool(play_result.get("ok", false)), "荣耀之路：神力检索效果打出失败", failures)
	if not bool(play_result.get("ok", false)):
		return
	_pass_stack_pair(engine, state)
	var heracles_id = _find_deck_card_by_definition(state, 0, "olympus_s02_0502")
	_expect(_resolve_first_candidate_choice(engine, state, "search_deck", [heracles_id]), "荣耀之路：未能从牌库中选择奥林匹斯卡牌", failures)
	_expect(_has_card_in_hand_definition(state, 0, "olympus_s02_0502"), "荣耀之路：应将赫拉克勒斯加入手牌", failures)
	_expect(MoraleActions.count_divine_morale(state, 0) == 0, "荣耀之路：消耗并翻转神力后不应保留神力标记", failures)


static func _definitions_with_olympus_masters() -> Array:
	var definitions: Array = []
	definitions.append_array(CardDatabase.load_definitions())
	definitions.append_array(CardDatabase.load_definitions("res://data/raw_rule_cards/olympus_master_cards.json"))
	return definitions


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


static func _find_deck_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).deck.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _find_top_deck_instance_id_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).deck.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _has_card_in_hand_definition(state, player_id: int, definition_id: String) -> bool:
	return not _find_hand_card_by_definition(state, player_id, definition_id).is_empty()


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


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
