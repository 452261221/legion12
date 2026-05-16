extends RefCounted
class_name TestOlympusBatch3

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_perseus_promotion_freeze_and_move(failures)
	_test_heracles_promotion_reveal_destroy(failures)
	return failures


static func _test_perseus_promotion_freeze_and_move(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0506", "olympus_s02_0525", "olympus_s02_0513"],
		["olympus_s02_0508"]
	], 7301, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 6, 6))
	var divine_seed = str(state.get_player(0).cost_area.cards[0])
	MoraleActions.flip_morale_cards(state, 0, [divine_seed], true, "test_perseus_setup")
	state.active_player = 1
	state.priority_player = 1
	var enemy_id = _find_hand_card_by_definition(state, 1, "olympus_s02_0508")
	var enemy_play = engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(enemy_play.get("ok", false)), "珀尔修斯·晋升：对手基础军团未能布置", failures)
	if not bool(enemy_play.get("ok", false)):
		return
	_drain_stack(engine, state)
	var enemy_instance = state.card_instances.get(enemy_id)
	if enemy_instance != null:
		enemy_instance.orientation = "rested"
	state.active_player = 0
	state.priority_player = 0
	var base_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0506")
	var promo_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0525")
	_expect(not base_id.is_empty() and not promo_id.is_empty(), "珀尔修斯·晋升：起手缺少基础卡或晋升卡", failures)
	if base_id.is_empty() or promo_id.is_empty():
		return
	var base_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": base_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(base_play.get("ok", false)), "珀尔修斯：基础登场失败", failures)
	if not bool(base_play.get("ok", false)):
		return
	_drain_stack(engine, state)
	var promo_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": promo_id,
		"row": "front",
		"col": 1,
		"play_option_id": "promotion"
	}))
	_expect(bool(promo_play.get("ok", false)), "珀尔修斯·晋升：晋升登场失败", failures)
	if not bool(promo_play.get("ok", false)):
		return
	_drain_stack(engine, state)
	_expect(_resolve_first_candidate_choice(engine, state, "target_then_stack_effect", [enemy_id]), "珀尔修斯·晋升：未能选择冻结目标", failures)
	_drain_stack(engine, state)
	enemy_instance = state.card_instances.get(enemy_id)
	_expect(enemy_instance != null and int(enemy_instance.flags.get("cannot_ready_on_ready_phase_player", -1)) == 1, "珀尔修斯·晋升：目标未被正确冻结", failures)
	var move_buff = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": promo_id,
		"effect_id": "perseus_free_move_once"
	}))
	_expect(bool(move_buff.get("ok", false)), "珀尔修斯·晋升：免费位移效果无法发动", failures)
	if not bool(move_buff.get("ok", false)):
		return
	_drain_stack(engine, state)
	var morale_before = state.get_player(0).cost_area.cards.size()
	var move_result = engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": promo_id,
		"row": "back",
		"col": 1
	}))
	_expect(bool(move_result.get("ok", false)), "珀尔修斯·晋升：免费位移执行失败", failures)
	if not bool(move_result.get("ok", false)):
		return
	var moved_instance = state.card_instances.get(promo_id)
	_expect(moved_instance != null and str(moved_instance.position.get("row", "")) == "back", "珀尔修斯·晋升：位移后应处于后排", failures)
	_expect(state.get_player(0).cost_area.cards.size() == morale_before, "珀尔修斯·晋升：免费位移不应额外消耗士气", failures)


static func _test_heracles_promotion_reveal_destroy(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0502", "olympus_s02_0501", "olympus_s02_0513"],
		["olympus_s02_0508"]
	], 7302, [
		{"name": "P0", "master_name": "普罗米修斯", "master_id": "olympus_s02_05m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(3, 8, 8))
	var divine_seed: Array[String] = [
		str(state.get_player(0).cost_area.cards[0]),
		str(state.get_player(0).cost_area.cards[1])
	]
	MoraleActions.flip_morale_cards(state, 0, divine_seed, true, "test_heracles_setup")
	state.active_player = 1
	state.priority_player = 1
	var enemy_id = _find_hand_card_by_definition(state, 1, "olympus_s02_0508")
	var enemy_play = engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_id,
		"row": "front",
		"col": 0
	}))
	_expect(bool(enemy_play.get("ok", false)), "赫拉克勒斯·晋升：对手目标军团未能布置", failures)
	if not bool(enemy_play.get("ok", false)):
		return
	_drain_stack(engine, state)
	state.active_player = 0
	state.priority_player = 0
	var base_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0502")
	var promo_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0501")
	var reveal_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0513")
	_expect(not base_id.is_empty() and not promo_id.is_empty() and not reveal_id.is_empty(), "赫拉克勒斯·晋升：起手缺少必要卡牌", failures)
	if base_id.is_empty() or promo_id.is_empty() or reveal_id.is_empty():
		return
	var base_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": base_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(base_play.get("ok", false)), "赫拉克勒斯：基础登场失败", failures)
	if not bool(base_play.get("ok", false)):
		return
	_drain_stack(engine, state)
	var promo_play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": promo_id,
		"row": "front",
		"col": 1,
		"play_option_id": "promotion"
	}))
	_expect(bool(promo_play.get("ok", false)), "赫拉克勒斯·晋升：晋升登场失败", failures)
	if not bool(promo_play.get("ok", false)):
		return
	_drain_stack(engine, state)
	_expect(_resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"), "赫拉克勒斯·晋升：未能确认发动展示击杀效果", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "olympus_reveal_hand_legion_to_deck_top", [reveal_id]), "赫拉克勒斯·晋升：未能选择展示并回顶的军团", failures)
	_expect(_resolve_first_candidate_choice(engine, state, "olympus_destroy_enemy_by_revealed_cost", [enemy_id]), "赫拉克勒斯·晋升：未能选择击杀目标", failures)
	_drain_stack(engine, state)
	_expect(state.get_player(1).grave.cards.has(enemy_id), "赫拉克勒斯·晋升：目标军团应被击杀进入墓地", failures)
	_expect(state.get_player(0).deck.cards.size() > 0 and str(state.get_player(0).deck.cards[0]) == reveal_id, "赫拉克勒斯·晋升：展示军团应回到牌库顶", failures)
	_expect(state.get_player(0).master_hp == 8 and state.get_player(1).master_hp == 7, "赫拉克勒斯·晋升：双方主宰应各受1点非致命伤害", failures)


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
	while guard < 20:
		guard += 1
		if _resolve_first_option_choice(engine, state, "optional_stack_effect", "yes"):
			continue
		if not state.pending_choices.is_empty():
			break
		if state.stack.is_empty():
			break
		_pass_stack_pair(engine, state)


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


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
