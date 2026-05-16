extends RefCounted
class_name TestOlympusBatch8

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_trojan_horse_triggers_after_attack_finishes(failures)
	_test_trojan_horse_foreign_battlefield_and_expire(failures)
	return failures


static func _test_trojan_horse_triggers_after_attack_finishes(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0523", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla"]
	], 7800, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(3, 0, 0))
	var horse_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0523")
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(not horse_id.is_empty() and not attacker_id.is_empty(), "特洛伊木马：进攻后触发测试应抽到木马与进攻者", failures)
	if horse_id.is_empty() or attacker_id.is_empty():
		return
	_expect(not engine._set_counter_tactic_from_hand_to_slot(state, 0, horse_id, 0, "test_trojan_set").is_empty(), "特洛伊木马：应能先置入后排", failures)
	engine._deploy_hand_card_to_slot(state, 1, attacker_id, "front", 0, "test_trojan_attacker")
	state.card_instances[attacker_id].entered_turn = -1
	state.active_player = 1
	state.priority_player = 1
	var declare = engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "master",
		"target_player": 0
	}))
	_expect(bool(declare.get("ok", false)), "特洛伊木马：应允许对方宣告进攻", failures)
	if not bool(declare.get("ok", false)):
		return
	_resolve_pending_attack(engine, state, failures, "特洛伊木马：第一次优先权放弃应成功", "特洛伊木马：第二次优先权放弃应完成进攻并排入触发")
	_expect(state.pending_attack.is_empty(), "特洛伊木马：进攻结束后应清空进行中的攻击", failures)
	_expect(_pending_choice_by_operation(state, "pre_stack_optional_attack_trigger") != null, "特洛伊木马：进攻结束后应先出现是否响应的选择", failures)
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "特洛伊木马：应可选择响应本次进攻后效果", failures)
	if _pending_choice_by_operation(state, "olympus_trojan_horse_choose_slot").is_empty():
		_expect(_find_battlefield_card_by_definition(state, 1, "olympus_s02_0523") == horse_id, "特洛伊木马：单槽位时应直接进入对方战场", failures)
	else:
		_expect(_resolve_option_choice(engine, state, "olympus_trojan_horse_choose_slot", "back:0"), "特洛伊木马：应可在进攻结束后选择置入位置", failures)

static func _test_trojan_horse_foreign_battlefield_and_expire(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0523", "qa_vanilla", "qa_vanilla"],
		["olympus_s02_0508", "qa_vanilla"]
	], 7801, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 0, 0))
	var horse_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0523")
	var draw_fodder_id = _find_hand_card_by_definition(state, 0, "qa_vanilla")
	var enemy_legion_id = _find_hand_card_by_definition(state, 1, "olympus_s02_0508")
	_expect(not horse_id.is_empty() and not draw_fodder_id.is_empty() and not enemy_legion_id.is_empty(), "特洛伊木马：应抽到木马、抽牌素材与敌方军团", failures)
	if horse_id.is_empty() or draw_fodder_id.is_empty() or enemy_legion_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_legion_id, "front", 1, "test_trojan_enemy_legion")
	var enemy_power_before = engine.get_card_power(state, enemy_legion_id)
	state.get_player(0).hand.remove_card(horse_id)
	var horse_instance = state.card_instances.get(horse_id)
	horse_instance.zone = "stack_pending"
	horse_instance.position = {}
	horse_instance.controller = 0
	var hand_before_expire_draw = state.get_player(0).hand.cards.size()
	state.active_player = 1
	state.priority_player = 1
	var place_events = engine._olympus_trojan_horse_after_attack(state, {
		"controller": 0,
		"source_instance_id": horse_id,
		"resolution": {}
	}, "test_trojan_place")
	_expect(not place_events.is_empty(), "特洛伊木马：应能请求或执行置入对方战场", failures)
	if _pending_choice_by_operation(state, "olympus_trojan_horse_choose_slot").is_empty():
		_expect(state.get_player(1).battle_back[0].occupant == horse_id or state.get_player(1).battle_front[0].occupant == horse_id, "特洛伊木马：单槽位时应直接置入对方战场", failures)
	else:
		_expect(_resolve_option_choice(engine, state, "olympus_trojan_horse_choose_slot", "back:0"), "特洛伊木马：应可选择置入对方后排空位", failures)
	_expect(state.get_player(1).battle_back[0].occupant == horse_id, "特洛伊木马：应进入对方后排空位", failures)
	_expect(int(state.card_instances.get(horse_id).controller) == 1, "特洛伊木马：寄存在对方战场时控制者应为宿主玩家", failures)
	_expect(engine.get_card_power(state, enemy_legion_id) == enemy_power_before - 1000, "特洛伊木马：在对方战场时应使对方军团兵力-1000", failures)
	state.active_player = 0
	engine._discard_turn_end_marked_legions(state, "test_trojan_expire")
	_expect(not state.get_player(0).grave.cards.is_empty() and str(state.get_player(0).grave.cards[0]) == horse_id, "特洛伊木马：到期后应进入拥有者墓地", failures)
	_expect(state.get_player(1).battle_back[0].occupant == "", "特洛伊木马：到期后应离开对方战场", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_expire_draw + 1, "特洛伊木马：到期弃置后拥有者应抽1张牌", failures)


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
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
	})).get("ok", false))

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	_expect(bool(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).get("ok", false)), message, failures)
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	_expect(bool(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).get("ok", false)), message, failures)

static func _resolve_pending_attack(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	_expect(bool(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).get("ok", false)), first_message, failures)
	_expect(bool(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).get("ok", false)), second_message, failures)

static func _find_battlefield_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for slot in state.get_player(player_id).battle_front:
		var occupant_id := str(slot.occupant)
		if occupant_id.is_empty():
			continue
		var instance = state.card_instances.get(occupant_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return occupant_id
	for slot in state.get_player(player_id).battle_back:
		var occupant_id := str(slot.occupant)
		if occupant_id.is_empty():
			continue
		var instance = state.card_instances.get(occupant_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return occupant_id
	return ""


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
