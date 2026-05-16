extends RefCounted
class_name TestBijieCore

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_setup_extracts_trial_cards(failures)
	_test_trial_effects_are_activatable(failures)
	_test_rune_cost_is_consumed_and_trial_can_complete(failures)
	_test_morrigan_master_effects(failures)
	_test_aengus_master_effects(failures)
	return failures

static func _test_setup_extracts_trial_cards(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _setup_decks(), 1501, [], {
		"shuffle_player_decks": false,
		"opening_hand_size": 5
	})
	var player = state.get_player(0)
	_expect(player.trial_zone.cards.size() == 1, "setup should extract one trial card into trial_zone", failures)
	_expect(player.city_zone.cards.size() == 0, "setup should not extract any city cards when none are provided", failures)
	_expect(player.hand.cards.size() == 5, "setup should still draw five opening cards after extracting trial/city", failures)
	for card_id in player.hand.cards:
		var instance = state.card_instances.get(str(card_id))
		var definition_id = str(instance.definition_id) if instance != null else ""
		_expect(definition_id != "qa_bijie_trial", "opening hand should not contain setup trial cards", failures)

static func _test_trial_effects_are_activatable(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _effect_decks(), 1502, [], {
		"shuffle_player_decks": false,
		"opening_hand_size": 0
	})
	var player = state.get_player(0)
	_expect(player.trial_zone.cards.size() == 1, "activatable test should set up one trial card", failures)
	_expect(player.city_zone.cards.size() == 0, "activatable test should not set up any city card", failures)
	if player.trial_zone.cards.is_empty():
		return
	var trial_id := str(player.trial_zone.cards[0])
	var actions = engine.get_activatable_effects(state, 0)
	_expect(_has_action(actions, trial_id, "progress_self"), "trial zone card should expose activated effects", failures)
	var trial_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": trial_id,
		"effect_id": "progress_self"
	}))
	_expect(trial_result.ok, "trial effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "trial effect first priority pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "trial effect second priority pass should resolve", failures)
	var trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and int(trial_instance.flags.get("trial_progress", 0)) == 1, "trial effect should advance its trial progress by one", failures)
	_expect(_has_event_type(state, "TrialProgressChanged"), "trial progress action should log TrialProgressChanged", failures)

static func _test_rune_cost_is_consumed_and_trial_can_complete(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _effect_decks(), 1503, [], {
		"shuffle_player_decks": false,
		"opening_hand_size": 0
	})
	var player = state.get_player(0)
	if player.trial_zone.cards.is_empty():
		failures.append("rune-cost test should set up trial cards")
		return
	var trial_id := str(player.trial_zone.cards[0])
	state.get_player(0).counters["rune"] = 2
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": trial_id,
		"effect_id": "progress_self"
	})).ok, "rune-cost test first trial activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "rune-cost test first trial first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "rune-cost test first trial second pass should resolve", failures)
	var complete_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": trial_id,
		"effect_id": "complete_with_rune"
	}))
	_expect(complete_result.ok, "trial completion activation should succeed after gaining progress and runes", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "trial completion first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "trial completion second pass should resolve", failures)
	var trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and bool(trial_instance.flags.get("trial_completed", false)), "trial should become completed at the configured threshold", failures)
	_expect(trial_instance != null and int(trial_instance.flags.get("trial_progress", 0)) == 2, "trial completion should move progress to two", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "trial completion should consume one rune cost", failures)
	_expect(_has_event_type(state, "TrialCompleted"), "trial completion should log TrialCompleted", failures)


static func _test_morrigan_master_effects(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_master_test_definitions(), [
		["qa_bijie_legion"],
		["qa_enemy_legion"]
	], 1504, [
		{"name": "P0", "master_name": "莫瑞甘", "master_id": "bijie_s02_06m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 0, 0))
	var ally_id := _find_hand_card_by_definition(state, 0, "qa_bijie_legion")
	var enemy_id := _find_hand_card_by_definition(state, 1, "qa_enemy_legion")
	_expect(not ally_id.is_empty() and not enemy_id.is_empty(), "莫瑞甘：测试初始化失败", failures)
	if ally_id.is_empty() or enemy_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, ally_id, "front", 0, "test_morrigan_setup")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_morrigan_setup")
	state.get_player(0).counters["rune"] = 2
	var activate = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": "master_0",
		"effect_id": "morrigan_prepare_ready_after_kill"
	}))
	_expect(bool(activate.get("ok", false)), "莫瑞甘：消耗2符文能力无法发动", failures)
	if not bool(activate.get("ok", false)):
		return
	_pass_until_idle(engine, state, failures, "莫瑞甘：发动能力后未能进入选取彼界军团")
	_expect(_resolve_candidate_choice(engine, state, "bijie_ready_after_kill_pick", [ally_id]), "莫瑞甘：未能选择彼界军团", failures)
	var ally_instance = state.card_instances.get(ally_id)
	if ally_instance != null:
		ally_instance.orientation = "rested"
	var kill_events = ZoneActions.move_battlefield_to_grave(state, 1, "front", 0, "test_morrigan_kill", {
		"source_card_id": ally_id,
		"source_kind": "attack"
	})
	engine.drain_until_waiting_for_input(state, kill_events, "test_morrigan_kill")
	_pass_until_idle(engine, state, failures, "莫瑞甘：击杀后未能结算转为活跃")
	ally_instance = state.card_instances.get(ally_id)
	_expect(ally_instance != null and str(ally_instance.orientation) == "active", "莫瑞甘：彼界军团击杀后应转为活跃", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 0, "莫瑞甘：发动能力应消耗2符文", failures)

	var state_rune = engine.create_game(_master_test_definitions(), [
		["qa_bijie_legion"],
		["qa_enemy_legion"]
	], 1505, [
		{"name": "P0", "master_name": "莫瑞甘", "master_id": "bijie_s02_06m1", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 0, 0))
	var enemy_rune_id := _find_hand_card_by_definition(state_rune, 1, "qa_enemy_legion")
	_expect(not enemy_rune_id.is_empty(), "莫瑞甘：符文触发测试初始化失败", failures)
	if enemy_rune_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state_rune, 1, enemy_rune_id, "front", 0, "test_morrigan_rune_setup")
	var enemy_died_events = ZoneActions.move_battlefield_to_grave(state_rune, 1, "front", 0, "test_morrigan_enemy_died")
	engine.drain_until_waiting_for_input(state_rune, enemy_died_events, "test_morrigan_enemy_died")
	_pass_until_idle(engine, state_rune, failures, "莫瑞甘：对方军团阵亡后未能进入可选触发")
	_expect(_resolve_option_choice(engine, state_rune, "optional_stack_effect", "yes"), "莫瑞甘：未能确认获得1符文", failures)
	_pass_until_idle(engine, state_rune, failures, "莫瑞甘：获得1符文未完成结算")
	_expect(int(state_rune.get_player(0).counters.get("rune", 0)) == 1, "莫瑞甘：对方军团阵亡时应可获得1符文", failures)


static func _test_aengus_master_effects(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_master_test_definitions(), [
		["qa_bijie_trial", "qa_bijie_tactic"],
		["qa_enemy_legion"]
	], 1506, [
		{"name": "P0", "master_name": "安格斯·麦·奥格", "master_id": "bijie_s02_06m2", "master_hp": 8, "master_max_hp": 8},
		{"name": "P1", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	], _formal_options(1, 0, 0))
	var trial_id := _find_trial_card_by_definition(state, 0, "qa_bijie_trial")
	var tactic_id := _find_hand_card_by_definition(state, 0, "qa_bijie_tactic")
	_expect(not trial_id.is_empty() and not tactic_id.is_empty(), "安格斯：测试初始化失败", failures)
	if trial_id.is_empty() or tactic_id.is_empty():
		return
	var play = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id
	}))
	_expect(bool(play.get("ok", false)), "安格斯：战术牌打出失败", failures)
	if not bool(play.get("ok", false)):
		return
	_pass_until_idle(engine, state, failures, "安格斯：战术效果未完成结算")
	var trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and int(trial_instance.flags.get("trial_progress", 0)) == 1, "安格斯：我方成功发动战术效果时应推进试炼", failures)
	var complete = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": trial_id,
		"effect_id": "complete_with_rune"
	}))
	_expect(bool(complete.get("ok", false)), "安格斯：试炼完成效果无法发动", failures)
	if not bool(complete.get("ok", false)):
		return
	_pass_until_idle(engine, state, failures, "安格斯：试炼完成后未完成结算")
	trial_instance = state.card_instances.get(trial_id)
	_expect(trial_instance != null and bool(trial_instance.flags.get("trial_completed", false)), "安格斯：试炼应正常完成", failures)
	_expect(int(state.get_player(0).counters.get("rune", 0)) == 1, "安格斯：完成试炼后应获得1符文", failures)

static func _definitions() -> Array:
	return [
		{
			"id": "qa_bijie_trial",
			"type": "trial",
			"cost": 0,
			"power": 0,
			"hp": 0,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "progress_self",
					"kind": "activated",
					"resolution": {"action": "advance_trial_progress", "target": "source", "count": 1}
				},
				{
					"id": "complete_with_rune",
					"kind": "activated",
					"cost": {"rune": 1},
					"source_trial_progress_at_least": 1,
					"source_trial_uncompleted": true,
					"resolution": {"action": "advance_trial_progress", "target": "source", "count": 1, "complete_at": 2}
				}
			]
		},
		{
			"id": "qa_bijie_legion",
			"type": "legion",
			"cost": 0,
			"power": 1000,
			"hp": 1000,
			"keywords": [],
			"traits": [],
			"effects": []
		}
	]


static func _master_test_definitions() -> Array:
	var definitions := CardDatabase.load_definitions()
	definitions.append_array([
		{
			"id": "qa_bijie_trial",
			"name": "测试试炼",
			"faction": "bijie",
			"type": "trial",
			"kind": "card",
			"cost": 0,
			"power": 0,
			"hp": 0,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "complete_with_rune",
					"kind": "activated",
					"text": "试炼完成",
					"source_trial_uncompleted": true,
					"resolution": {"action": "advance_trial_progress", "target": "source", "count": 1, "complete_at": 2}
				}
			]
		},
		{
			"id": "qa_bijie_tactic",
			"name": "测试战术",
			"faction": "bijie",
			"type": "tactic",
			"kind": "card",
			"cost": 0,
			"power": 0,
			"hp": 0,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "draw_one",
					"kind": "activated",
					"text": "抽1张牌",
					"resolution": {"action": "draw_cards", "count": 1}
				}
			]
		},
		{
			"id": "qa_bijie_legion",
			"name": "测试彼界军团",
			"faction": "bijie",
			"type": "legion",
			"kind": "card",
			"cost": 0,
			"power": 1000,
			"hp": 1000,
			"keywords": [],
			"traits": [],
			"effects": []
		},
		{
			"id": "qa_enemy_legion",
			"name": "测试敌方军团",
			"faction": "asgard",
			"type": "legion",
			"kind": "card",
			"cost": 0,
			"power": 1000,
			"hp": 1000,
			"keywords": [],
			"traits": [],
			"effects": []
		}
	])
	return definitions

static func _setup_decks() -> Array:
	return [
		[
			"qa_bijie_trial",
			"qa_bijie_legion",
			"qa_bijie_legion",
			"qa_bijie_legion",
			"qa_bijie_legion",
			"qa_bijie_legion"
		],
		[
			"qa_bijie_legion",
			"qa_bijie_legion",
			"qa_bijie_legion",
			"qa_bijie_legion",
			"qa_bijie_legion"
		]
	]

static func _effect_decks() -> Array:
	return [
		["qa_bijie_trial"],
		["qa_bijie_legion"]
	]


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

static func _has_action(actions: Array, source_id: String, effect_id: String) -> bool:
	for action in actions:
		if str(action.get("source_id", "")) == source_id and str(action.get("effect_id", "")) == effect_id:
			return true
	return false

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)


static func _pass_until_idle(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(8):
		if state.stack.is_empty() and state.pending_triggers.is_empty():
			return
		_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
		if state.stack.is_empty() and state.pending_triggers.is_empty():
			return
		_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
		if not state.pending_choices.is_empty():
			return
	if not state.stack.is_empty() or not state.pending_triggers.is_empty():
		failures.append(message)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
