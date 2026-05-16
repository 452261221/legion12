extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")

const VERIFY_PORT := 24568
const TIMEOUT_MS := 15000

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var host_result: Dictionary = table._network_session.host_session(VERIFY_PORT)
	if not bool(host_result.get("ok", false)):
		push_error("network host verify: failed to host session")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if table._network_session.has_remote_peer():
			table._on_start_duel_pressed()
			break
		await process_frame
	if not table._network_session.has_remote_peer():
		push_error("network host verify: client did not connect in time")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if table._state != null:
			print("network host verify passed phase=%s active=%s" % [
				str(table._state.phase),
				str(table._state.active_player)
			])
			quit(0)
			return
		await process_frame
	push_error("network host verify: host state should not be null after start")
	quit(1)
