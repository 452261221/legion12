extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	await _verify_result_dialog(0, "胜利", failures)
	await _verify_result_dialog(1, "失败", failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("game result dialog verify passed")
	quit(0)


func _verify_result_dialog(winner: int, expected_title: String, failures: Array[String]) -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	table._on_start_duel_pressed()
	await process_frame
	await process_frame
	if table._state == null:
		failures.append("game result dialog verify: state should exist after starting duel")
		table.queue_free()
		await process_frame
		return
	table._state.winner = winner
	table._state.loss_reason = "verify_result_dialog"
	table._sync_from_engine()
	table._refresh()
	await process_frame
	await process_frame
	if table._game_result_overlay == null or not table._game_result_overlay.visible:
		failures.append("game result dialog verify: overlay should be visible for winner=%s" % str(winner))
	elif table._game_result_title == null or table._game_result_title.text != expected_title:
		failures.append("game result dialog verify: expected title %s, got %s" % [expected_title, table._game_result_title.text if table._game_result_title != null else "<null>"])
	if table._game_result_confirm_button == null:
		failures.append("game result dialog verify: confirm button should exist")
	else:
		table._game_result_confirm_button.emit_signal("pressed")
		await process_frame
		await process_frame
		if table._state != null:
			failures.append("game result dialog verify: state should be cleared after confirming result")
		if table._start_panel == null or not table._start_panel.visible:
			failures.append("game result dialog verify: start panel should be visible after confirming result")
		if table._game_result_overlay != null and table._game_result_overlay.visible:
			failures.append("game result dialog verify: result overlay should hide after confirming result")
	table.queue_free()
	await process_frame
