extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")


func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame

	var waiting_prompt := {
		"prompt_id": "opening_busy_verify",
		"stage": "opening_special_setup_0",
		"choice_type": "waiting",
		"actor_player_id": 1,
		"title": "起手额外规则",
		"description": "等待对方完成起手额外规则...",
		"status_text": "可改为将安德华拉诺特从牌库置入圣物区，起始手牌改为4张。"
	}
	table._show_opening_overlay(waiting_prompt)
	table._on_hud_loading_timer_timeout()
	if table._opening_overlay_title == null or table._opening_overlay_title.text.find("[") < 0:
		push_error("busy status verify: opening waiting overlay should show loading badge")
		quit(1)
		return
	table._hide_opening_overlay()

	table._show_network_sync_overlay("正在同步联机状态...")
	table._on_hud_loading_timer_timeout()
	if table._network_sync_label == null or table._network_sync_label.text.find("[") < 0:
		push_error("busy status verify: network sync overlay should show loading badge")
		quit(1)
		return
	table._hide_network_sync_overlay()

	table._on_ai_mode_selected(2)
	table._on_start_test_pressed()
	await process_frame
	await process_frame
	table._refresh()
	if table._busy_status_panel == null or not table._busy_status_panel.visible:
		push_error("busy status verify: in dual AI duel the busy status panel should be visible")
		quit(1)
		return
	if table._busy_status_title == null or table._busy_status_title.text.find("正在") < 0:
		push_error("busy status verify: busy status panel should describe the current operation")
		quit(1)
		return
	print("busy status indicator verify passed")
	quit(0)
