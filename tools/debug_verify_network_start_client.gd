extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")

const VERIFY_PORT := 24568
const TIMEOUT_MS := 15000

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var join_result: Dictionary = table._network_session.join_session("127.0.0.1", VERIFY_PORT)
	if not bool(join_result.get("ok", false)):
		push_error("network client verify: failed to join session")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if table._state != null:
			print("network client verify passed phase=%s active=%s" % [
				str(table._state.phase),
				str(table._state.active_player)
			])
			quit(0)
			return
		await process_frame
	push_error("network client verify: client state should not be null after host start")
	quit(1)
