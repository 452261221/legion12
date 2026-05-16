extends RefCounted
class_name TestOlympusBatch6

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_hannibal_guard_and_adjacent_buff(failures)
	_test_hannibal_attack_weaken_choice_chain(failures)
	_test_helen_entry_discard_if_divine(failures)
	_test_helen_lethal_replace_candidates_and_resolution(failures)
	_test_helen_cancelled_lethal_choice_continues_death(failures)
	return failures


static func _test_hannibal_guard_and_adjacent_buff(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0508", "olympus_s02_0516", "olympus_s02_0519"],
		["olympus_s02_0508", "neutral_s01_0015", "neutral_s01_0016"]
	], 7601, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(3, 4, 4))
	var left_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0508")
	var hannibal_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0516")
	var right_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0519")
	var enemy_id = _find_hand_card_by_definition(state, 1, "olympus_s02_0508")
	_expect(not left_id.is_empty() and not hannibal_id.is_empty() and not right_id.is_empty() and not enemy_id.is_empty(), "汉尼拔：起手应包含左右友军、汉尼拔与敌军", failures)
	if left_id.is_empty() or hannibal_id.is_empty() or right_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, left_id, "front", 0, "test_hannibal_left")
	var left_power_before = engine.get_card_power(state, left_id)
	engine._deploy_hand_card_to_slot(state, 0, right_id, "front", 2, "test_hannibal_right")
	var right_power_before = engine.get_card_power(state, right_id)
	engine._deploy_hand_card_to_slot(state, 0, hannibal_id, "front", 1, "test_hannibal_center")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 1, "test_hannibal_enemy")
	state.card_instances.get(enemy_id).entered_turn = state.turn_number - 1
	_expect(engine.get_card_power(state, left_id) == left_power_before + 1000, "汉尼拔：左侧相邻军团应+1000", failures)
	_expect(engine.get_card_power(state, right_id) == right_power_before + 1000, "汉尼拔：右侧相邻军团应+1000", failures)
	state.active_player = 1
	state.priority_player = 1
	var targets = engine.get_legal_attack_targets(state, enemy_id)
	_expect(not _targets_include_card(targets, hannibal_id), "汉尼拔：活跃时不应成为可被进攻目标", failures)
	state.card_instances.get(hannibal_id).orientation = "rested"
	_expect(_targets_include_card(engine.get_legal_attack_targets(state, enemy_id), hannibal_id), "汉尼拔：休整后应重新可被进攻", failures)


static func _test_hannibal_attack_weaken_choice_chain(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0516", "olympus_s02_0508"],
		["olympus_s02_0519", "neutral_s01_0015"]
	], 7602, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 4, 4))
	var hannibal_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0516")
	var ally_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0508")
	var enemy_id = _find_hand_card_by_definition(state, 1, "olympus_s02_0519")
	_expect(not hannibal_id.is_empty() and not ally_id.is_empty() and not enemy_id.is_empty(), "汉尼拔减攻：应抽到双方测试卡", failures)
	if hannibal_id.is_empty() or ally_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, hannibal_id, "front", 0, "test_hannibal_attack")
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 1, "test_hannibal_ally")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_hannibal_enemy")
	var enemy_power_before = engine.get_card_power(state, enemy_id)
	var ally_power_before = engine.get_card_power(state, ally_id)
	engine._olympus_hannibal_attack_weaken(state, {
		"controller": 0,
		"source_instance_id": hannibal_id,
		"resolution": {}
	}, "test_hannibal_weaken")
	_expect(_resolve_candidate_choice(engine, state, "olympus_hannibal_pick_enemy_weaken", [enemy_id]), "汉尼拔减攻：应先选择敌方军团", failures)
	_expect(_resolve_candidate_choice(engine, state, "olympus_hannibal_pick_ally_weaken", [ally_id]), "汉尼拔减攻：应再选择我方军团", failures)
	_expect(engine.get_card_power(state, enemy_id) == enemy_power_before - 2000, "汉尼拔减攻：敌方军团应-2000", failures)
	_expect(engine.get_card_power(state, ally_id) == ally_power_before - 2000, "汉尼拔减攻：我方军团应-2000", failures)


static func _test_helen_entry_discard_if_divine(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0515", "olympus_s02_0508", "neutral_s01_0015"],
		["olympus_s02_0508", "olympus_s02_0519", "neutral_s01_0015"]
	], 7603, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(3, 4, 4))
	var helen_play_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0515")
	var fodder_id = _find_other_hand_card_by_definition(state, 0, "olympus_s02_0508")
	var enemy_discard_id = _find_hand_card_by_definition(state, 1, "olympus_s02_0508")
	_expect(not helen_play_id.is_empty() and not fodder_id.is_empty() and not enemy_discard_id.is_empty(), "海伦：应抽到本体、弃牌素材与对手手牌", failures)
	if helen_play_id.is_empty() or fodder_id.is_empty() or enemy_discard_id.is_empty():
		return
	var divine_id = str(state.get_player(0).cost_area.cards[0])
	state.card_instances.get(divine_id).flags["divine"] = true
	var opponent_hand_before = state.get_player(1).hand.cards.size()
	engine._olympus_helen_entry_discard_if_divine(state, {
		"controller": 0,
		"source_instance_id": helen_play_id,
		"resolution": {}
	}, "test_helen_entry")
	_expect(_resolve_candidate_choice(engine, state, "discard_from_hand", [enemy_discard_id]), "海伦：登场时应让对手选择弃置1张手牌", failures)
	_expect(state.get_player(1).hand.cards.size() == opponent_hand_before - 1, "海伦：登场弃牌后对手手牌应-1", failures)


static func _test_helen_lethal_replace_candidates_and_resolution(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0515", "olympus_s02_0515", "olympus_s02_0508"],
		["olympus_s02_0519", "neutral_s01_0015", "neutral_s01_0016"]
	], 7604, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(3, 4, 4))
	var helen_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0515")
	var reserve_helen_id = _find_other_hand_card_by_definition(state, 0, "olympus_s02_0515", helen_id)
	var fodder_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0508")
	_expect(not helen_id.is_empty() and not reserve_helen_id.is_empty() and not fodder_id.is_empty(), "海伦替死：应抽到上场海伦、手牌海伦与其他军团", failures)
	if helen_id.is_empty() or reserve_helen_id.is_empty() or fodder_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, helen_id, "front", 0, "test_helen_front")
	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_helen_lethal_yes")
	var choice = _pending_choice_by_operation(state, "olympus_helen_lethal_replace")
	_expect(not choice.is_empty(), "海伦替死：前排致死时应弹出替代选择", failures)
	_expect(str(state.get_player(0).battle_front[0].occupant) == helen_id, "海伦替死：选择前不应直接离场", failures)
	if choice.is_empty():
		return
	var candidates = choice.get("candidate_card_ids", [])
	_expect(not candidates.has(reserve_helen_id), "海伦替死：不应允许弃置手牌中的海伦", failures)
	_expect(candidates.has(fodder_id), "海伦替死：应允许弃置其他手牌军团", failures)
	_expect(_resolve_candidate_choice(engine, state, "olympus_helen_lethal_replace", [fodder_id]), "海伦替死：选择弃置其他军团应成功", failures)
	var helen_instance = state.card_instances.get(helen_id)
	_expect(str(state.get_player(0).battle_front[0].occupant) == helen_id, "海伦替死：发动后应继续留场", failures)
	_expect(helen_instance != null and str(helen_instance.zone) == "battle_front", "海伦替死：发动后区域应仍为战场", failures)
	_expect(helen_instance != null and helen_instance.damage_marked == 0, "海伦替死：发动后应清除伤害", failures)
	_expect(helen_instance != null and int(helen_instance.flags.get("olympus_helen_lethal_replace_used_turn", -1)) == state.turn_number, "海伦替死：本回合应标记已发动", failures)
	_expect(state.get_player(0).grave.cards.has(fodder_id), "海伦替死：应把弃置的军团送入墓地", failures)
	_expect(state.get_player(0).hand.cards.has(reserve_helen_id), "海伦替死：未被选中的手牌海伦应保留", failures)


static func _test_helen_cancelled_lethal_choice_continues_death(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0515", "olympus_s02_0508"],
		["olympus_s02_0519", "neutral_s01_0015"]
	], 7605, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 4, 4))
	var helen_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0515")
	var fodder_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0508")
	_expect(not helen_id.is_empty() and not fodder_id.is_empty(), "海伦取消替死：应抽到海伦与其他军团", failures)
	if helen_id.is_empty() or fodder_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, helen_id, "front", 0, "test_helen_cancel_front")
	var hand_before = state.get_player(0).hand.cards.size()
	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_helen_lethal_cancel")
	var choice = _pending_choice_by_operation(state, "olympus_helen_lethal_replace")
	_expect(not choice.is_empty(), "海伦取消替死：前排致死时应弹出替代选择", failures)
	if choice.is_empty():
		return
	var cancel = engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"cancelled": true
	}))
	_expect(bool(cancel.get("ok", false)), "海伦取消替死：取消选择应成功", failures)
	var helen_instance = state.card_instances.get(helen_id)
	_expect(str(state.get_player(0).battle_front[0].occupant) == "", "海伦取消替死：取消后应继续正常死亡离场", failures)
	_expect(helen_instance != null and str(helen_instance.zone) == "grave", "海伦取消替死：取消后应进入墓地", failures)
	_expect(state.get_player(0).grave.cards.has(helen_id), "海伦取消替死：取消后墓地应包含海伦", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "海伦取消替死：取消后不应额外弃牌", failures)


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


static func _find_other_hand_card_by_definition(state, player_id: int, definition_id: String, exclude_card_id: String = "") -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if str(card_id) == exclude_card_id:
			continue
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _pending_choice_by_operation(state, operation: String) -> Dictionary:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return {}


static func _drain_stack(engine: GameEngine, state) -> void:
	var guard := 0
	while guard < 25:
		guard += 1
		if _resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"):
			continue
		if not state.pending_choices.is_empty():
			break
		if state.stack.is_empty():
			break
		_pass_stack_pair(engine, state)


static func _resolve_first_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_option": selected_option
		})).get("ok", false))
	return false


static func _pass_stack_pair(engine: GameEngine, state) -> void:
	if state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority", {}))
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority", {}))


static func _resolve_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice.is_empty():
		return false
	return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected_card_ids
	})).get("ok", false))


static func _targets_include_card(targets: Array, defender_id: String) -> bool:
	for target in targets:
		if not (target is Dictionary):
			continue
		if str(target.get("target_kind", "")) == "card" and str(target.get("defender_id", "")) == defender_id:
			return true
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
