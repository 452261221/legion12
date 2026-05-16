extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const NetworkAutoplayer = preload("res://tools/network_autoplayer.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")

const VERIFY_PORT := 24571
const TIMEOUT_MS := 240000

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var join_result: Dictionary = table._network_session.join_session("127.0.0.1", VERIFY_PORT)
	if not bool(join_result.get("ok", false)):
		push_error("network full duel client: failed to join session")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		NetworkAutoplayer.drive_local_step(table)
		if table._state != null and int(table._state.winner) != -1:
			print("network full duel client passed %s" % JSON.stringify(_summary(table)))
			quit(0)
			return
		await process_frame
	push_error("network full duel client: duel did not finish in time")
	quit(1)


func _summary(table) -> Dictionary:
	var hash := ""
	if table._state != null:
		hash = StateHasher.hash_public_and_private_state(table._state)
	return {
		"winner": int(table._state.winner),
		"loss_reason": str(table._state.loss_reason),
		"turn": int(table._state.turn_number),
		"phase": str(table._state.phase),
		"command_count": table._state.command_log.size(),
		"hash": hash
	}
