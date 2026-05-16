extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	await _verify_alvilda_hand_deploy_choice_ui(failures)
	if failures.is_empty():
		print("alvilda hand deploy ui verification passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_alvilda_hand_deploy_choice_ui(failures: Array[String]) -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"asgard_s01_0307",
			"asgard_s01_0304",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0312",
			"neutral_s01_0015"
		],
		[
			"takamagahara_s01_0418",
			"neutral_s01_0016",
			"neutral_s01_0015",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410"
		]
	], 4125, [], {"mode": "formal"})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "alvilda ui verify should add five morale", failures)
	var alvilda_id := _find_hand_card_by_definition(state, 0, "asgard_s01_0307")
	var harald_id := _find_hand_card_by_definition(state, 0, "asgard_s01_0304")
	_expect(alvilda_id != "" and harald_id != "", "alvilda ui verify should seed both 阿尔维达 and 无情者哈拉尔 into hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": alvilda_id,
		"row": "front",
		"col": 0
	})).ok, "alvilda ui verify should play 阿尔维达", failures)
	var alvilda_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": alvilda_instance_id,
		"effect_id": "alvilda_blood_summon"
	})).ok, "alvilda ui verify should activate the blood summon", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "alvilda ui verify first stack pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, "alvilda ui verify second stack pass should resolve into the deploy choice", failures)
	table._state = state
	table._engine = engine
	table._sync_from_engine()
	table._refresh()
	await process_frame
	await process_frame
	var waiting = table._waiting_state
	_expect(str(waiting.get("state", "")) == "WaitingForChoice", "alvilda ui verify should stop in WaitingForChoice", failures)
	var choice_action: Dictionary = table._find_action(table._player_actions(table._current_input_player()), "resolve_choice")
	print("ALVILDA_UI waiting=%s" % JSON.stringify(waiting))
	print("ALVILDA_UI choice_action=%s" % JSON.stringify(choice_action))
	_expect(not choice_action.is_empty(), "alvilda ui verify should expose resolve_choice to battle_table", failures)
	_expect(table._is_hand_deploy_choice_action(choice_action), "alvilda ui verify should recognize the hand deploy choice", failures)
	_expect(table._choice_panel != null and not table._choice_panel.visible, "alvilda ui verify should hide the central choice panel during hand deploy", failures)
	_expect(table._choice_allows_drag_hand_card(0, harald_id), "alvilda ui verify should allow dragging the candidate hand card", failures)
	var slot_options: Array = table._current_deploy_choice_slot_options()
	print("ALVILDA_UI slot_options=%s" % JSON.stringify(slot_options))
	_expect(slot_options.size() == 6, "alvilda ui verify should expose six deploy slot options on an empty board", failures)
	_expect(table._highlight_layer != null and table._highlight_layer.get_child_count() > 0, "alvilda ui verify should paint visible highlights for the pending deploy choice", failures)
	if slot_options.is_empty():
		table.queue_free()
		await process_frame
		return
	_expect(table._execute_choice_deploy_drag(0, harald_id, slot_options[0]), "alvilda ui verify should submit the drag deploy command through battle_table", failures)
	print("ALVILDA_UI after_drop waiting=%s" % JSON.stringify(table._waiting_state))
	print("ALVILDA_UI after_drop pending_choices=%s stack=%s battlefield_front=%s battlefield_back=%s" % [
		str(state.pending_choices.size()),
		str(state.stack.size()),
		str(state.get_player(0).battle_front[0].occupant),
		str(state.get_player(0).battle_back[0].occupant)
	])
	_expect(str(table._waiting_state.get("state", "")) == "WaitingForChoice", "alvilda ui verify should continue into the next optional trigger choice after the drop", failures)
	_expect(str(table._waiting_state.get("operation", "")) == "optional_stack_effect", "alvilda ui verify should hand off into Harald's optional entry trigger", failures)
	_expect(_is_card_on_battlefield(state, harald_id), "alvilda ui verify should place 无情者哈拉尔 onto the battlefield", failures)
	table.queue_free()
	await process_frame


func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""


func _is_card_on_battlefield(state, card_id: String) -> bool:
	var instance = state.card_instances.get(card_id)
	return instance != null and str(instance.zone).begins_with("battle_")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
