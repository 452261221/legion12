extends RefCounted
class_name TestOlympusBatch4

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_forge_discount_affects_promotion_cost(failures)
	_test_forge_ready_after_kill(failures)
	_test_achilles_lethal_replace_yes(failures)
	_test_achilles_lethal_replace_cancel_continues_death(failures)
	return failures


static func _test_forge_discount_affects_promotion_cost(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0504", "olympus_s02_0503", "olympus_s02_0520"],
		["olympus_s02_0508", "neutral_s01_0015", "neutral_s01_0016"]
	], 7401, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(3, 10, 6))
	state.active_player = 0
	state.priority_player = 0
	var base_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0504")
	var promo_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0503")
	var forge_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0520")
	_expect(not base_id.is_empty() and not promo_id.is_empty() and not forge_id.is_empty(), "锻造炉折扣：起手缺少必要卡牌", failures)
	if base_id.is_empty() or promo_id.is_empty() or forge_id.is_empty():
		return
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "PlayCard", {"card_id": base_id, "row": "front", "col": 0})).get("ok", false)), "锻造炉折扣：阿喀琉斯基础登场失败", failures)
	_drain_stack(engine, state)
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "PlayCard", {"card_id": forge_id, "row": "artifact", "col": -1})).get("ok", false)), "锻造炉折扣：锻造炉登场失败", failures)
	_drain_stack(engine, state)
	var forge_flip_choice = _pending_choice_by_operation(state, "olympus_flip_morale_pick")
	if not forge_flip_choice.is_empty():
		var candidate_ids = forge_flip_choice.get("candidate_card_ids", [])
		_expect(not candidate_ids.is_empty() and bool(engine.apply_command(state, GameCommand.create(int(forge_flip_choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(forge_flip_choice.get("choice_id", "")),
			"selected_card_ids": [candidate_ids[0]]
		})).get("ok", false)), "锻造炉折扣：登场翻转士气选择应能结算", failures)
	state.active_player = 0
	state.priority_player = 0
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": forge_id,
		"effect_id": "forge_prepare_choice"
	}))
	_expect(bool(activate.get("ok", false)), "锻造炉折扣：主动休整发动失败", failures)
	if not bool(activate.get("ok", false)):
		return
	_drain_stack(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "resolve_option_with_shared_cost", "discount"), "锻造炉折扣：未能选择折扣选项", failures)
	_drain_stack(engine, state)
	if MoraleActions.count_active_divine_morale(state, 0) < 1:
		MoraleActions.ready_spent_morale(state, 0, 1, "test_forge_discount_seed")
		var active_morale_cards = state.get_player(0).cost_area.cards
		if active_morale_cards.is_empty():
			MoraleActions.add_morale_from_cost_deck(state, 0, 1, "active", "test_forge_discount_seed")
			active_morale_cards = state.get_player(0).cost_area.cards
		_expect(not active_morale_cards.is_empty(), "锻造炉折扣：补充晋升神力时应能获得可翻转的士气", failures)
		if active_morale_cards.is_empty():
			return
		var seeded_divine_id = str(active_morale_cards[active_morale_cards.size() - 1])
		MoraleActions.flip_morale_cards(state, 0, [seeded_divine_id], true, "test_forge_discount_seed")
	var divine_before = MoraleActions.count_active_divine_morale(state, 0)
	var promo_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": promo_id,
		"row": "front",
		"col": 0,
		"play_option_id": "promotion"
	}))
	_expect(bool(promo_play.get("ok", false)), "锻造炉折扣：阿喀琉斯·晋升登场失败", failures)
	_drain_stack(engine, state)
	var divine_after = MoraleActions.count_active_divine_morale(state, 0)
	_expect(divine_before - divine_after == 1, "锻造炉折扣：晋升登场应只消耗并翻转1神力", failures)


static func _test_forge_ready_after_kill(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0504", "olympus_s02_0520"],
		["olympus_s02_0508", "neutral_s01_0015"]
	], 7402, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 8, 6))
	state.active_player = 0
	state.priority_player = 0
	var attacker_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0504")
	var forge_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0520")
	var defender_id = _find_hand_card_by_definition(state, 1, "olympus_s02_0508")
	_expect(not attacker_id.is_empty() and not forge_id.is_empty() and not defender_id.is_empty(), "锻造炉击杀转活：起手缺少必要卡牌", failures)
	if attacker_id.is_empty() or forge_id.is_empty() or defender_id.is_empty():
		return
	state.active_player = 1
	state.priority_player = 1
	_expect(bool(engine.apply_command(state, GameCommand.create(1, "PlayCard", {"card_id": defender_id, "row": "front", "col": 0})).get("ok", false)), "锻造炉击杀转活：对手军团登场失败", failures)
	_drain_stack(engine, state)
	state.active_player = 0
	state.priority_player = 0
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "PlayCard", {"card_id": attacker_id, "row": "front", "col": 1})).get("ok", false)), "锻造炉击杀转活：进攻方军团登场失败", failures)
	_drain_stack(engine, state)
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "PlayCard", {"card_id": forge_id, "row": "artifact", "col": -1})).get("ok", false)), "锻造炉击杀转活：锻造炉登场失败", failures)
	_drain_stack(engine, state)
	var forge_flip_choice = _pending_choice_by_operation(state, "olympus_flip_morale_pick")
	if not forge_flip_choice.is_empty():
		var candidate_ids = forge_flip_choice.get("candidate_card_ids", [])
		_expect(not candidate_ids.is_empty() and bool(engine.apply_command(state, GameCommand.create(int(forge_flip_choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(forge_flip_choice.get("choice_id", "")),
			"selected_card_ids": [candidate_ids[0]]
		})).get("ok", false)), "锻造炉击杀转活：登场翻转士气选择应能结算", failures)
	state.active_player = 0
	state.priority_player = 0
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": forge_id,
		"effect_id": "forge_prepare_choice"
	}))
	_expect(bool(activate.get("ok", false)), "锻造炉击杀转活：主动休整发动失败", failures)
	if not bool(activate.get("ok", false)):
		return
	_drain_stack(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "resolve_option_with_shared_cost", "ready_after_kill"), "锻造炉击杀转活：未能选择击杀转活选项", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "olympus_ready_after_kill_pick", [attacker_id]), "锻造炉击杀转活：未能选择目标军团", failures)
	_drain_stack(engine, state)
	var attacker_instance = state.card_instances.get(attacker_id)
	if attacker_instance != null:
		attacker_instance.entered_turn = -1
	var attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"target_kind": "card"
	}))
	_expect(bool(attack.get("ok", false)), "锻造炉击杀转活：进攻声明失败", failures)
	_drain_stack(engine, state)
	attacker_instance = state.card_instances.get(attacker_id)
	_expect(attacker_instance != null and str(attacker_instance.orientation) == "active", "锻造炉击杀转活：击杀后应转为活跃", failures)


static func _test_achilles_lethal_replace_yes(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0504", "olympus_s02_0508"],
		["olympus_s02_0508", "neutral_s01_0015"]
	], 7403, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 4, 4))
	var achilles_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0504")
	_expect(not achilles_id.is_empty(), "阿喀琉斯替死：起手应抽到阿喀琉斯", failures)
	if achilles_id.is_empty():
		return
	var divine_id = str(state.get_player(0).cost_area.cards[0])
	MoraleActions.flip_morale_cards(state, 0, [divine_id], true, "test_achilles_divine_setup")
	engine._deploy_hand_card_to_slot(state, 0, achilles_id, "front", 0, "test_achilles_front")
	var divine_before = MoraleActions.count_active_divine_morale(state, 0)
	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_achilles_lethal_yes")
	var choice = _pending_choice_by_operation(state, "olympus_achilles_lethal_replace")
	_expect(not choice.is_empty(), "阿喀琉斯替死：前排致死时应弹出替代选择", failures)
	_expect(str(state.get_player(0).battle_front[0].occupant) == achilles_id, "阿喀琉斯替死：选择前不应直接离场", failures)
	if choice.is_empty():
		return
	var resolve = engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": "yes"
	}))
	_expect(bool(resolve.get("ok", false)), "阿喀琉斯替死：选择发动应成功", failures)
	var instance = state.card_instances.get(achilles_id)
	_expect(str(state.get_player(0).battle_front[0].occupant) == achilles_id, "阿喀琉斯替死：发动后应继续留场", failures)
	_expect(instance != null and str(instance.zone) == "battle_front", "阿喀琉斯替死：发动后区域应仍为战场", failures)
	_expect(MoraleActions.count_active_divine_morale(state, 0) == divine_before - 1, "阿喀琉斯替死：应消耗并翻转1神力", failures)
	_expect(instance != null and int(instance.flags.get("fixed_power_until_turn_end_value", 0)) == 1000, "阿喀琉斯替死：发动后兵力应固定为1000", failures)
	_expect(instance != null and int(instance.flags.get("olympus_achilles_lethal_replace_used_turn", -1)) == state.turn_number, "阿喀琉斯替死：本回合应标记已发动", failures)
	_expect(instance != null and instance.damage_marked == 0, "阿喀琉斯替死：发动后应清除伤害", failures)


static func _test_achilles_lethal_replace_cancel_continues_death(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0504", "olympus_s02_0508"],
		["olympus_s02_0508", "neutral_s01_0015"]
	], 7404, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 4, 4))
	var achilles_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0504")
	_expect(not achilles_id.is_empty(), "阿喀琉斯取消替死：起手应抽到阿喀琉斯", failures)
	if achilles_id.is_empty():
		return
	var divine_id = str(state.get_player(0).cost_area.cards[0])
	MoraleActions.flip_morale_cards(state, 0, [divine_id], true, "test_achilles_cancel_divine_setup")
	engine._deploy_hand_card_to_slot(state, 0, achilles_id, "front", 0, "test_achilles_cancel_front")
	var divine_before = MoraleActions.count_active_divine_morale(state, 0)
	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_achilles_lethal_cancel")
	var choice = _pending_choice_by_operation(state, "olympus_achilles_lethal_replace")
	_expect(not choice.is_empty(), "阿喀琉斯取消替死：前排致死时应弹出替代选择", failures)
	if choice.is_empty():
		return
	var cancel = engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"cancelled": true
	}))
	_expect(bool(cancel.get("ok", false)), "阿喀琉斯取消替死：取消选择应成功", failures)
	var instance = state.card_instances.get(achilles_id)
	_expect(str(state.get_player(0).battle_front[0].occupant) == "", "阿喀琉斯取消替死：取消后应继续正常死亡离场", failures)
	_expect(instance != null and str(instance.zone) == "grave", "阿喀琉斯取消替死：取消后应进入墓地", failures)
	_expect(state.get_player(0).grave.cards.has(achilles_id), "阿喀琉斯取消替死：取消后墓地应包含阿喀琉斯", failures)
	_expect(MoraleActions.count_active_divine_morale(state, 0) == divine_before, "阿喀琉斯取消替死：取消后不应支付神力", failures)


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


static func _resolve_first_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array) -> bool:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) != operation:
			continue
		return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_card_ids": selected_card_ids
		})).get("ok", false))
	return false


static func _pending_choice_by_operation(state, operation: String) -> Dictionary:
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return {}


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
