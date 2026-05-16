extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const TestDemoStarterDuelEffects = preload("res://tests/unit/test_demo_starter_duel_effects.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	await _verify_hiromasa_board_click_flow(failures)
	if failures.is_empty():
		print("hiromasa set-counter ui verification passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_hiromasa_board_click_flow(failures: Array[String]) -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"takamagahara_s01_0413",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"neutral_s01_0016",
			"neutral_s01_0015",
			"neutral_s01_0015",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1422, [], {"mode": "formal"})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "ui verify should add two morale for casting 源博雅 under formal rules", failures)
	var hiromasa_id := _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	var counter_id := _find_hand_card_by_definition(state, 1, "neutral_s01_0016")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hiromasa_id,
		"row": "front",
		"col": 0
	})).ok, "ui verify should play 源博雅", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "ui verify hiromasa enter first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "ui verify hiromasa enter second pass should resolve", failures)
	var hiromasa_instance_id = state.get_player(0).battle_front[0].occupant
	TestDemoStarterDuelEffects._advance_to_next_main(engine, state, failures, "ui verify should advance to player 2 main")
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "ui verify should add one morale for setting 绝对防御", failures)
	var set_result = engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "front",
		"col": 0
	}))
	_expect(set_result.ok, "ui verify should set 绝对防御 onto the battlefield", failures)
	TestDemoStarterDuelEffects._advance_to_next_main(engine, state, failures, "ui verify should advance back to player 1 main")
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hiromasa_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "ui verify hiromasa attack should declare successfully", failures)
	table._state = state
	table._sync_from_engine()
	table._refresh()
	await process_frame
	_expect(state.pending_choices.size() == 1, "ui verify should reach the hiromasa target choice", failures)
	_expect(table._choice_panel != null and not table._choice_panel.visible, "ui verify should keep the choice panel hidden for board-click target selection", failures)
	_expect(table._try_click_choice_candidate(counter_id), "ui verify should allow directly clicking the facedown counter tactic as the target", failures)
	_expect(state.pending_choices.is_empty(), "ui verify direct click should resolve the pending choice immediately", failures)
	_expect(state.stack.size() == 1, "ui verify direct click should put hiromasa's disable effect on stack", failures)
	table.queue_free()
	await process_frame


func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
