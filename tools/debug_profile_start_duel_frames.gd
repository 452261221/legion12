extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	table._on_start_duel_pressed()
	for _i in range(20):
		await process_frame
	if table._state == null:
		push_error("profile start duel: state should not be null")
		quit(1)
		return
	if table._players.size() != 2:
		push_error("profile start duel: expected 2 player views, got %s" % str(table._players.size()))
		quit(1)
		return
	print("profile start duel phase=%s active=%s players=%s log=%s" % [
		str(table._state.phase),
		str(table._state.active_player),
		str(table._players.size()),
		str(table._duel_log_path)
	])
	quit(0)
