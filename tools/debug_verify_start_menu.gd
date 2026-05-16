extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")


func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var failures: Array[String] = []
	if table._start_panel == null:
		failures.append("start menu verify: start panel should exist")
	elif not table._start_panel.visible:
		failures.append("start menu verify: start panel should be visible on boot")
	elif table._start_panel.size.x <= 0 or table._start_panel.size.y <= 0:
		failures.append("start menu verify: start panel size should be positive on boot")
	if table.size.x <= 0 or table.size.y <= 0:
		failures.append("start menu verify: battle table root size should be positive on boot")
	if table._start_panel_title == null or table._start_panel_title.text.is_empty():
		failures.append("start menu verify: start title should not be empty")
	if table._start_panel_desc == null or table._start_panel_desc.text.is_empty():
		failures.append("start menu verify: start desc should not be empty")
	if table._network_status_label == null or table._network_status_label.text.is_empty():
		failures.append("start menu verify: network status should not be empty")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("start menu verify passed")
	quit(0)
