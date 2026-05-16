extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const TestDemoStarterDuelEffects = preload("res://tests/unit/test_demo_starter_duel_effects.gd")

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame

	var teach_result = await _verify_teach_choice_ui(table)
	if not teach_result.get("ok", false):
		push_error(str(teach_result.get("error", "teach verify failed")))
		quit(1)
		return

	print("teach discard choice ui verified")
	quit(0)

func _verify_teach_choice_ui(table) -> Dictionary:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"neutral_s01_0001",
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
	], 1771, [], {"mode": "formal"})
	table._state = state
	table._engine = engine
	table._sync_from_engine()
	table._refresh()
	await process_frame
	if not engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 6
	})).ok:
		return {"ok": false, "error": "teach ui verify failed to add morale"}
	var teach_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0001")
	if teach_id == "":
		return {"ok": false, "error": "teach ui verify missing 黑胡子蒂奇"}
	if not engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": teach_id,
		"row": "front",
		"col": 0
	})).ok:
		return {"ok": false, "error": "teach ui verify failed to play 黑胡子蒂奇"}
	table._sync_from_engine()
	table._refresh()
	if not await _pass_until_choice_or_idle(table, 8):
		return {"ok": false, "error": "teach ui verify failed to advance into discard choice"}
	table._sync_from_engine()
	table._refresh()
	await process_frame
	if table._choice_panel.visible:
		return {"ok": false, "error": "teach ui verify should keep choice panel hidden for direct hand discard"}
	var button = _find_button_with_text(table._action_panel, "确认选择")
	if button == null:
		return {"ok": false, "error": "teach ui verify missing confirm button"}
	if table._turn_label.text.find("黑胡子蒂奇登场") == -1:
		return {"ok": false, "error": "teach ui verify missing top hint"}
	return {"ok": true}

func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and str(node.text) == text:
		return node
	for child in node.get_children():
		var found = _find_button_with_text(child, text)
		if found != null:
			return found
	return null

func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

func _pass_until_choice_or_idle(table, guard_limit: int) -> bool:
	var guard := 0
	while guard < guard_limit and table._state != null:
		var state = table._state
		if not state.pending_choices.is_empty():
			table._sync_from_engine()
			table._refresh()
			return true
		if state.stack.is_empty() and state.pending_attack.is_empty():
			table._sync_from_engine()
			table._refresh()
			return false
		if not table._engine.apply_command(state, GameCommand.create(int(state.priority_player), "PassPriority")).ok:
			return false
		table._sync_from_engine()
		table._refresh()
		await process_frame
		guard += 1
	return table._state != null and not table._state.pending_choices.is_empty()
