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
		push_error("start duel verify: state should not be null after pressing start")
		quit(1)
		return
	print("start duel verify state phase=%s active=%s stack=%s pending_choices=%s pending_attack=%s" % [
		str(table._state.phase),
		str(table._state.active_player),
		str(table._state.stack.size()),
		str(table._state.pending_choices.size()),
		str(table._state.pending_attack.size())
	])
	print("start duel verify passed")
	quit(0)
