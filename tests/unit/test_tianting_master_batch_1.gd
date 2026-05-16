extends RefCounted
class_name TestTiantingMasterBatch1

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_mengpo_refund_cost_and_disable_died_effects(failures)
	_test_mengpo_discard_add_rested_morale_requires_lower_morale(failures)
	_test_sunwukong_transform_and_revert(failures)
	_test_yangjian_draw_then_put_back_and_nonlethal(failures)
	return failures


static func _test_mengpo_refund_cost_and_disable_died_effects(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["neutral_s01_0006"],
		["asgard_s01_0302"]
	], 6101, [
		{"name": "P0", "master_name": "孟婆", "master_id": "tianting_s01_01m2", "master_hp": 10, "master_max_hp": 10},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 1, 1))
	var enemy = _find_hand_card_by_definition(state, 1, "asgard_s01_0302")
	if enemy.is_empty():
		failures.append("孟婆：测试初始化失败（未抽到目标军团）")
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy, "front", 0, "test_mengpo_setup")
	MoraleActions.consume_morale(state, 0, 1, "test_mengpo_setup")

	var result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "mengpo_disable_died_effects_then_draw",
		"target_card_id": enemy
	}))
	if not bool(result.get("ok", false)):
		failures.append("孟婆：返还士气效果无法发动（%s %s）" % [str(result.get("code", "")), str(result.get("message", result.get("errors", [])))])
		return
	_pass_stack_pair(engine, state)

	if state.get_player(0).spent_cost_area.cards.size() != 0:
		failures.append("孟婆：返还士气未生效（spent_cost_area 未减少）")
	var target_instance = state.card_instances.get(enemy)
	if target_instance == null or int(target_instance.flags.get("died_effects_disabled_turn", -1)) != int(state.turn_number):
		failures.append("孟婆：未正确标记阵亡效果禁用")


static func _test_mengpo_discard_add_rested_morale_requires_lower_morale(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state_equal = engine.create_game(CardDatabase.load_definitions(), [
		["neutral_s01_0006"],
		["neutral_s01_0006"]
	], 6102, [
		{"name": "P0", "master_name": "孟婆", "master_id": "tianting_s01_01m2", "master_hp": 10, "master_max_hp": 10},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 2, 2))
	var equal_result = engine.apply_command(state_equal, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "mengpo_discard_then_add_rested_morale"
	}))
	if str(equal_result.get("code", "")) != "MORALE_NOT_LOWER":
		failures.append("孟婆：士气相等时不应允许发动第二项能力（%s）" % str(equal_result.get("code", "")))

	var state = engine.create_game(CardDatabase.load_definitions(), [
		["neutral_s01_0006"],
		["neutral_s01_0006"]
	], 6103, [
		{"name": "P0", "master_name": "孟婆", "master_id": "tianting_s01_01m2", "master_hp": 10, "master_max_hp": 10},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 1, 2))
	var cost_area_before = state.get_player(0).cost_area.cards.size()
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "mengpo_discard_then_add_rested_morale"
	}))
	if not bool(activate.get("ok", false)):
		failures.append("孟婆：士气落后时能力无法发动（%s %s）" % [str(activate.get("code", "")), str(activate.get("message", activate.get("errors", [])))])
		return
	if state.get_player(0).hand.cards.size() != 0:
		failures.append("孟婆：弃牌费用未生效")
	_pass_stack_pair(engine, state)
	if state.get_player(0).cost_area.cards.size() != cost_area_before + 1:
		failures.append("孟婆：未追加士气")
	else:
		var added_id = state.get_player(0).cost_area.cards[-1]
		if str(state.card_instances[added_id].orientation) != "rested":
			failures.append("孟婆：追加的士气未为休整状态")

static func _test_sunwukong_transform_and_revert(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		[],
		[]
	], 6201, [
		{"name": "P0", "master_name": "孙悟空", "master_id": "tianting_s02_01m1", "master_hp": 12, "master_max_hp": 12},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(0, 3, 3))

	MoraleActions.consume_morale(state, 0, 3, "test_sunwukong_setup")
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "sunwukong_transform_to_legion"
	}))
	if not bool(activate.get("ok", false)):
		failures.append("孙悟空：能力无法发动（%s %s）" % [str(activate.get("code", "")), str(activate.get("message", activate.get("errors", [])))])
		return
	_pass_stack_pair(engine, state)
	if not _resolve_first_option_choice(engine, state, "resolve_option_with_shared_cost", "refund_2"):
		failures.append("孙悟空：未能选择返还士气数量")
		return
	if not _resolve_first_option_choice(engine, state, "sunwukong_deploy_fighter_to_slot", "front:0"):
		failures.append("孙悟空：未能选择登场位置")
		return

	var fighter_id = str(state.get_player(0).battle_front[0].occupant)
	if fighter_id.is_empty():
		failures.append("孙悟空：斗士军团未登场")
		return
	var fighter = state.card_instances.get(fighter_id)
	if fighter == null or int(fighter.flags.get("manifested_power", 0)) != 2000:
		failures.append("孙悟空：斗士军团兵力不正确")
	if str(state.get_player(0).flags.get("sunwukong_fighter_card_id", "")) != fighter_id:
		failures.append("孙悟空：未记录斗士军团实例 id")
	if state.get_player(0).spent_cost_area.cards.size() != 1:
		failures.append("孙悟空：返还士气费用未生效（spent=%d）" % state.get_player(0).spent_cost_area.cards.size())

	var activate_again = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "sunwukong_transform_to_legion"
	}))
	if str(activate_again.get("code", "")) != "EFFECT_UNAVAILABLE":
		failures.append("孙悟空：斗士在场时不应允许再次发动（%s）" % str(activate_again.get("code", "")))

	ZoneActions.move_battlefield_to_grave(state, 0, "front", 0, "test_sunwukong_leave")
	if not state.get_player(0).battle_front[0].occupant.is_empty():
		failures.append("孙悟空：斗士离场后战场位置应为空")
	if state.get_player(0).flags.has("sunwukong_fighter_card_id"):
		failures.append("孙悟空：斗士离场后应清除标记")
	if state.card_instances.has(fighter_id):
		failures.append("孙悟空：斗士离场后不应作为普通卡留在实例表")
	if state.get_player(0).grave.cards.has(fighter_id):
		failures.append("孙悟空：斗士离场后不应进入墓地")

static func _test_yangjian_draw_then_put_back_and_nonlethal(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_tianting_masters(), [
		["neutral_s01_0006", "neutral_s01_0006"],
		["neutral_s01_0006"]
	], 6301, [
		{"name": "P0", "master_name": "杨戬", "master_id": "tianting_s01_01m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 1, 1))

	var hand_before = state.get_player(0).hand.cards.size()
	var deck_before = state.get_player(0).deck.cards.size()
	var draw_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "yangjian_draw_then_put_back"
	}))
	if not bool(draw_result.get("ok", false)):
		failures.append("杨戬：抽牌放回能力无法发动（%s）" % str(draw_result.get("code", "")))
		return
	_pass_stack_pair(engine, state)
	if state.get_player(0).hand.cards.is_empty():
		failures.append("杨戬：抽牌后手牌为空（测试初始化异常）")
		return
	if not _resolve_first_candidate_choice(engine, state, "yangjian_choose_hand_to_put_back", [str(state.get_player(0).hand.cards[0])]):
		failures.append("杨戬：未能选择放回的手牌")
		return
	if not _resolve_first_option_choice(engine, state, "yangjian_choose_put_back_position", "top"):
		failures.append("杨戬：未能选择放回位置")
		return
	if state.get_player(0).hand.cards.size() != hand_before:
		failures.append("杨戬：结算后手牌数量不正确")
	if state.get_player(0).deck.cards.size() != deck_before:
		failures.append("杨戬：结算后牌库数量不正确")
	if state.get_player(0).spent_cost_area.cards.size() != 1:
		failures.append("杨戬：消耗士气费用未生效")

	var state2 = engine.create_game(_definitions_with_tianting_masters(), [
		[],
		[]
	], 6302, [
		{"name": "P0", "master_name": "杨戬", "master_id": "tianting_s01_01m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 1, "master_max_hp": 12}
	], _formal_options(0, 4, 4))
	MoraleActions.consume_morale(state2, 0, 4, "test_yangjian_setup")
	var damage = engine.apply_command(state2, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "yangjian_refund_nonlethal_damage"
	}))
	if not bool(damage.get("ok", false)):
		failures.append("杨戬：返还士气非致命伤害无法发动（%s）" % str(damage.get("code", "")))
		return
	_pass_stack_pair(engine, state2)
	if state2.get_player(1).master_hp != 1:
		failures.append("杨戬：非致命伤害不应将主宰血量降到 0")
	if state2.get_player(0).spent_cost_area.cards.size() != 0:
		failures.append("杨戬：返还士气费用未生效")


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


static func _pass_stack_pair(engine: GameEngine, state) -> void:
	if state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))

static func _definitions_with_tianting_masters() -> Array:
	var definitions: Array = []
	definitions.append_array(CardDatabase.load_definitions())
	definitions.append_array(CardDatabase.load_definitions("res://data/raw_rule_cards/tianting_master_cards.json"))
	return definitions

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
