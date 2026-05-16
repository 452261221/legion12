extends RefCounted
class_name TestOlympusBatch7

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_hippolyta_divine_discount(failures)
	_test_hippolyta_rested_vertical_move_is_free(failures)
	_test_hippolyta_rest_revive_olympus(failures)
	return failures


static func _test_hippolyta_divine_discount(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0510"],
		["olympus_s02_0508"]
	], 7701, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(1, 5, 3))
	var hippolyta_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0510")
	_expect(not hippolyta_id.is_empty(), "希波吕忒：起手应抽到本体", failures)
	if hippolyta_id.is_empty():
		return
	for morale_id in state.get_player(0).cost_area.cards:
		state.card_instances.get(str(morale_id)).flags["divine"] = true
	_expect(engine._get_effective_play_cost(state, hippolyta_id) == 3, "希波吕忒：5神力时登场费用应为3", failures)


static func _test_hippolyta_rested_vertical_move_is_free(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0510", "olympus_s02_0508"],
		["olympus_s02_0519"]
	], 7702, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(2, 0, 0))
	var hippolyta_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0510")
	var ally_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0508")
	_expect(not hippolyta_id.is_empty() and not ally_id.is_empty(), "希波吕忒位移：应抽到本体与友军", failures)
	if hippolyta_id.is_empty() or ally_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, hippolyta_id, "front", 1, "test_hippolyta_front")
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_hippolyta_ally")
	state.card_instances.get(hippolyta_id).orientation = "rested"
	var targets = engine.get_legal_move_targets(state, ally_id)
	_expect(_targets_include_slot(targets, "back", 0), "希波吕忒位移：休整时应允许友军前后位移", failures)
	_expect(not _targets_include_slot(targets, "front", 1), "希波吕忒位移：无士气时不应额外允许横向位移", failures)
	_expect(bool(engine.apply_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": ally_id,
		"row": "back",
		"col": 0
	})).get("ok", false)), "希波吕忒位移：应可免费执行前后位移", failures)
	_expect(state.get_player(0).battle_back[0].occupant == ally_id, "希波吕忒位移：友军应移动到后排同列", failures)
	_expect(state.get_player(0).cost_area.cards.size() == 0, "希波吕忒位移：免费前后位移不应消耗士气", failures)


static func _test_hippolyta_rest_revive_olympus(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions_with_olympus_masters(), [
		["olympus_s02_0510", "olympus_s02_0508", "olympus_s02_0519"],
		["olympus_s02_0508"]
	], 7703, [
		{"name": "P0", "master_name": "阿尔忒弥斯", "master_id": "olympus_s02_05m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_hp": 8, "master_max_hp": 8}
	], _formal_options(3, 3, 0))
	var hippolyta_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0510")
	var revive_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0508")
	var fodder_id = _find_hand_card_by_definition(state, 0, "olympus_s02_0519")
	_expect(not hippolyta_id.is_empty() and not revive_id.is_empty() and not fodder_id.is_empty(), "希波吕忒复活：应抽到本体、复活目标与弃牌素材", failures)
	if hippolyta_id.is_empty() or revive_id.is_empty() or fodder_id.is_empty():
		return
	var player = state.get_player(0)
	player.hand.remove_card(revive_id)
	player.grave.add_card_to_top(revive_id)
	state.card_instances.get(revive_id).zone = "grave"
	engine._deploy_hand_card_to_slot(state, 0, hippolyta_id, "front", 1, "test_hippolyta_deploy")
	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": hippolyta_id,
		"effect_id": "hippolyta_rest_revive_olympus"
	}))
	_expect(bool(activate_result.get("ok", false)), "希波吕忒复活：主动休整效果应可发动", failures)
	_expect(state.get_player(0).hand.cards.is_empty(), "希波吕忒复活：发动后应弃置1张手牌", failures)
	_expect(str(state.card_instances.get(hippolyta_id).orientation) == "rested", "希波吕忒复活：发动后本体应休整", failures)
	_expect(_resolve_candidate_choice(engine, state, "revive_from_grave", [revive_id]), "希波吕忒复活：应可选择墓地低费奥林匹斯军团", failures)
	_expect(_resolve_option_choice(engine, state, "revive_selected_grave_to_slot", "front:0"), "希波吕忒复活：应可选择活跃登场位置", failures)
	_expect(state.get_player(0).battle_front[0].occupant == revive_id, "希波吕忒复活：目标军团应登场到指定空位", failures)
	_expect(str(state.card_instances.get(revive_id).orientation) == "active", "希波吕忒复活：目标军团应活跃登场", failures)
	_expect(state.get_player(0).cost_area.cards.is_empty(), "希波吕忒复活：应消耗3士气", failures)


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


static func _resolve_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice.is_empty():
		return false
	return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected_card_ids
	})).get("ok", false))


static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice.is_empty():
		return false
	return bool(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
	})).get("ok", false))


static func _targets_include_slot(targets: Array, row: String, col: int) -> bool:
	for target in targets:
		if not (target is Dictionary):
			continue
		if str(target.get("row", "")) == row and int(target.get("col", -1)) == col:
			return true
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
