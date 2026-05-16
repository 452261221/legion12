extends RefCounted
class_name TestOlympusBatch5

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_penthesilea_frontline_ranged_and_entry_attack(failures)
	_test_spartan_opponent_turn_bonus(failures)
	_test_odysseus_discount_free_tactic_and_reveal_buff(failures)
	return failures


static func _test_penthesilea_frontline_ranged_and_entry_attack(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0517"],
		["olympus_s02_0508"]
	], 7501, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(1, 3, 3))
	var penthesilea_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0517")
	var enemy_id = _find_hand_card_by_definition(state, 1, "olympus_s02_0508")
	_expect(not penthesilea_id.is_empty() and not enemy_id.is_empty(), "彭忒西勒亚：起手缺少必要卡牌", failures)
	if penthesilea_id.is_empty() or enemy_id.is_empty():
		return
	state.active_player = 1
	state.priority_player = 1
	_expect(bool(engine.apply_command(state, GameCommand.create(1, "PlayCard", {"card_id": enemy_id, "row": "front", "col": 0})).get("ok", false)), "彭忒西勒亚：对手军团登场失败", failures)
	_drain_stack(engine, state)
	state.active_player = 0
	state.priority_player = 0
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "PlayCard", {"card_id": penthesilea_id, "row": "front", "col": 1})).get("ok", false)), "彭忒西勒亚：登场失败", failures)
	_drain_stack(engine, state)
	_expect(engine._has_attack_keyword(state, penthesilea_id, "ranged"), "彭忒西勒亚：位于前排时应获得远程", failures)
	_expect(engine._has_attack_keyword(state, penthesilea_id, "ranged_no_loss"), "彭忒西勒亚：位于前排时应获得远程进攻无损", failures)
	_expect(_targets_include_card(engine.get_legal_attack_targets(state, penthesilea_id), enemy_id), "彭忒西勒亚：登场回合应可进攻敌方军团", failures)


static func _test_spartan_opponent_turn_bonus(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0519"],
		["olympus_s02_0508"]
	], 7502, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(1, 3, 3))
	var spartan_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0519")
	_expect(not spartan_id.is_empty(), "斯巴达勇士：起手缺少卡牌", failures)
	if spartan_id.is_empty():
		return
	state.active_player = 0
	state.priority_player = 0
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "PlayCard", {"card_id": spartan_id, "row": "front", "col": 0})).get("ok", false)), "斯巴达勇士：登场失败", failures)
	_drain_stack(engine, state)
	_expect(engine.get_card_power(state, spartan_id) == 3000, "斯巴达勇士：我方回合兵力应为3000", failures)
	state.active_player = 1
	engine._refresh_continuous_modifiers(state)
	_expect(engine.get_card_power(state, spartan_id) == 5000, "斯巴达勇士：对方回合兵力应为5000", failures)


static func _test_odysseus_discount_free_tactic_and_reveal_buff(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0509", "olympus_s02_0521"],
		["olympus_s02_0508"]
	], 7503, [
		{"name": "P0", "master_name": "普罗米修斯", "master_id": "olympus_s02_05m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 3, 3))
	var odysseus_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0509")
	var tactic_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0521")
	_expect(not odysseus_id.is_empty() and not tactic_id.is_empty(), "奥德修斯：起手缺少必要卡牌", failures)
	if odysseus_id.is_empty() or tactic_id.is_empty():
		return
	_expect(engine._get_effective_play_cost(state, odysseus_id) == 5, "奥德修斯：神力为0时登场费用应为5", failures)
	state.active_player = 0
	state.priority_player = 0
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "PlayCard", {"card_id": odysseus_id, "row": "front", "col": 0})).get("ok", false)), "奥德修斯：登场失败", failures)
	_drain_stack(engine, state)
	_expect(engine._get_effective_play_cost(state, tactic_id) == 0, "奥德修斯：本回合下1张战术应免费", failures)
	var buff_events = engine._olympus_reveal_hand_tactic_for_power(state, {
		"controller": 0,
		"source_instance_id": odysseus_id,
		"resolution": {"amount": 1000}
	}, "test_odysseus_reveal")
	_expect(buff_events.size() >= 2, "奥德修斯：展示手牌战术后应产生展示与加攻事件", failures)
	_expect(engine.get_card_power(state, odysseus_id) == 6000, "奥德修斯：展示手牌战术后兵力应为6000", failures)


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


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


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
