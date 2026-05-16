extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame

	var result = await _verify_ragnar_play_option_ui(table)
	if not result.get("ok", false):
		push_error(str(result.get("error", "ragnar ui verify failed")))
		quit(1)
		return

	print("ragnar play option ui verified")
	quit(0)


func _verify_ragnar_play_option_ui(table) -> Dictionary:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"asgard_s01_0306",
			"neutral_s01_0001"
		],
		[
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta"
		]
	], 1881)
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
		return {"ok": false, "error": "failed to add morale for Ragnar UI verify"}
	table._sync_from_engine()
	table._refresh()
	await process_frame

	var ragnar_id := _find_hand_card_by_definition(state, 0, "asgard_s01_0303")
	if ragnar_id.is_empty():
		return {"ok": false, "error": "missing Ragnar in hand"}
	var actions = engine.get_legal_actions(state, 0)
	var ragnar_action := {}
	for action in actions:
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("play_kind", "")) != "board_or_artifact":
			continue
		if str(action.get("payload_template", {}).get("card_id", "")) != ragnar_id:
			continue
		ragnar_action = action
		break
	if ragnar_action.is_empty():
		return {"ok": false, "error": "missing Ragnar play action"}
	var targets: Array = ragnar_action.get("targets", [])
	if targets.is_empty():
		return {"ok": false, "error": "Ragnar play action missing slot target"}
	if not table._execute_action_with_target(0, ragnar_action, targets[0]):
		return {"ok": false, "error": "failed to open Ragnar option choice"}
	await process_frame
	if not table._choice_panel.visible:
		return {"ok": false, "error": "Ragnar option choice panel should be visible"}
	if _find_button_with_text(table._choice_panel, "正常登场") == null:
		return {"ok": false, "error": "Ragnar option choice missing default button"}
	if _find_button_with_text(table._choice_panel, "对我方主宰造成1点伤害：此军团登场费用-1") == null:
		return {"ok": false, "error": "Ragnar option choice missing blood-price button"}
	if table._turn_label.text.find("传奇的拉格纳打出时") == -1:
		return {"ok": false, "error": "Ragnar option choice missing top hint"}
	var default_button = _find_button_with_text(table._choice_panel, "正常登场")
	default_button.pressed.emit()
	await process_frame
	var occupant := str(state.get_player(0).battle_front[0].occupant)
	if occupant.is_empty():
		return {"ok": false, "error": "Ragnar default play button should deploy the card"}
	if state.get_player(0).master_hp != 10:
		return {"ok": false, "error": "Ragnar default play should not damage the controller master"}
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
