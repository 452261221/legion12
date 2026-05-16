extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	table._on_start_duel_pressed()
	await process_frame
	await process_frame
	if table._state == null:
		push_error("restart after result dialog verify: first duel should start")
		quit(1)
		return
	table._state.winner = 0
	table._sync_from_engine()
	table._refresh()
	await process_frame
	await process_frame
	if table._game_result_confirm_button == null:
		push_error("restart after result dialog verify: confirm button missing")
		quit(1)
		return
	table._game_result_confirm_button.emit_signal("pressed")
	await process_frame
	await process_frame
	table._on_start_duel_pressed()
	await process_frame
	await process_frame
	if table._state == null:
		push_error("restart after result dialog verify: second duel should start")
		quit(1)
		return
	if table._end_turn_button == null or not table._end_turn_button.visible:
		push_error("restart after result dialog verify: end turn button should be visible after restarting")
		quit(1)
		return
	print("restart after result dialog verify passed")
	quit(0)
