extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame

	var result = await _verify_gustav_attack_ui(table)
	if not result.get("ok", false):
		push_error(str(result.get("error", "gustav attack ui verify failed")))
		quit(1)
		return

	print("gustav attack ui verified")
	quit(0)


func _verify_gustav_attack_ui(table) -> Dictionary:
	var no_result = await _verify_gustav_attack_decline_ui(table)
	if not no_result.get("ok", false):
		return no_result
	return await _verify_gustav_attack_accept_ui(table)


func _verify_gustav_attack_decline_ui(table) -> Dictionary:
	var setup = await _create_gustav_attack_setup(table, 1960)
	if not setup.get("ok", false):
		return setup
	var engine = setup.get("engine")
	var state = setup.get("state")
	var enemy_hp_before := int(state.get_player(1).master_hp)
	var choice_result = await _open_gustav_attack_optional_choice(table, engine, state)
	if not choice_result.get("ok", false):
		return choice_result
	var no_button = _find_button_with_text(table._choice_panel, "不发动")
	if no_button == null:
		return {"ok": false, "error": "gustav optional effect missing 不发动 button"}
	no_button.pressed.emit()
	await process_frame
	if not state.pending_choices.is_empty():
		return {"ok": false, "error": "gustav decline choice should not leave a pending choice"}
	if not state.pending_attack.is_empty():
		return {"ok": false, "error": "gustav decline choice should continue resolving the pending attack"}
	if int(state.get_player(1).master_hp) != enemy_hp_before - 1:
		return {"ok": false, "error": "gustav decline choice should still let the master attack resolve"}
	return {"ok": true}


func _verify_gustav_attack_accept_ui(table) -> Dictionary:
	var setup = await _create_gustav_attack_setup(table, 1961)
	if not setup.get("ok", false):
		return setup
	var engine = setup.get("engine")
	var state = setup.get("state")
	var choice_result = await _open_gustav_attack_optional_choice(table, engine, state)
	if not choice_result.get("ok", false):
		return choice_result
	var yes_button = _find_button_with_text(table._choice_panel, "发动")
	if yes_button == null:
		return {"ok": false, "error": "gustav optional effect missing 发动 button"}
	yes_button.pressed.emit()
	await process_frame
	if state.pending_choices.is_empty():
		return {"ok": false, "error": "gustav yes choice should create grave recycle choice"}
	var choice: Dictionary = state.pending_choices[0]
	if str(choice.get("operation", "")) != "recycle_grave_to_deck":
		return {"ok": false, "error": "gustav yes choice should open recycle_grave_to_deck choice"}
	if int(choice.get("count", 0)) != 2:
		return {"ok": false, "error": "gustav recycle choice should still require selecting two grave cards"}
	if not table._choice_panel.visible:
		return {"ok": false, "error": "gustav grave recycle choice panel should remain visible"}
	return {"ok": true}


func _create_gustav_attack_setup(table, seed: int) -> Dictionary:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"asgard_s01_0311",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0303",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta",
			"dev_legion_beta"
		]
	], seed)
	table._state = state
	table._engine = engine
	table._sync_from_engine()
	table._refresh()
	await process_frame

	if not engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 4
	})).ok:
		return {"ok": false, "error": "failed to add morale for Gustav UI verify"}
	_seed_grave_from_deck(state, 0, 4)
	table._sync_from_engine()
	table._refresh()
	await process_frame

	var gustav_id := _find_hand_card_by_definition(state, 0, "asgard_s01_0311")
	if gustav_id.is_empty():
		return {"ok": false, "error": "missing Gustav in hand"}
	if not engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": gustav_id,
		"row": "front",
		"col": 0,
		"play_option_id": "default"
	})).ok:
		return {"ok": false, "error": "failed to play Gustav"}
	table._sync_from_engine()
	table._refresh()
	await process_frame
	_advance_to_player_one_main(engine, state)
	table._sync_from_engine()
	table._refresh()
	await process_frame
	return {"ok": true, "engine": engine, "state": state}


func _open_gustav_attack_optional_choice(table, engine, state) -> Dictionary:

	var gustav_instance_id := str(state.get_player(0).battle_front[0].occupant)
	if gustav_instance_id.is_empty():
		return {"ok": false, "error": "gustav not on battlefield"}
	var actions = engine.get_legal_actions(state, 0)
	var attack_action := {}
	for action in actions:
		if str(action.get("kind", "")) != "declare_attack":
			continue
		if str(action.get("payload_template", {}).get("attacker_id", "")) != gustav_instance_id:
			continue
		for target in action.get("targets", []):
			if str(target.get("target_kind", "")) == "master":
				attack_action = action.duplicate(true)
				attack_action["__target"] = target.duplicate(true)
				break
		if not attack_action.is_empty():
			break
	if attack_action.is_empty():
		return {"ok": false, "error": "gustav master attack action missing"}
	if not table._execute_action_with_target(0, attack_action, attack_action.get("__target", {})):
		return {"ok": false, "error": "failed to declare Gustav master attack from battle table"}
	await process_frame

	if state.stack.size() != 1:
		return {"ok": false, "error": "gustav attack should create one trigger on stack"}
	if not engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok:
		return {"ok": false, "error": "defender pass for gustav attack failed"}
	table._sync_from_engine()
	table._refresh()
	await process_frame
	if not engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok:
		return {"ok": false, "error": "attacker pass for gustav attack failed"}
	table._sync_from_engine()
	table._refresh()
	await process_frame

	if not table._choice_panel.visible:
		return {"ok": false, "error": "gustav optional effect choice panel should be visible"}
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


func _seed_grave_from_deck(state, player_id: int, count: int) -> void:
	var moved := 0
	var player = state.get_player(player_id)
	for raw_card_id in player.deck.cards.duplicate():
		if moved >= count:
			return
		var card_id := str(raw_card_id)
		player.deck.remove_card(card_id)
		player.grave.add_card_to_top(card_id)
		var instance = state.card_instances.get(card_id)
		if instance != null:
			instance.zone = "grave"
			instance.position = {}
			instance.face = "face_up"
		moved += 1


func _advance_to_player_one_main(engine, state) -> void:
	for _i in range(4):
		if state.active_player == 0 and state.phase == "main":
			return
		engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase"))
