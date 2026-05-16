extends SceneTree

const BattleTableScene = preload("res://client/scenes/battle_table.tscn")

const DEFAULT_GAME_COUNT := 12
const DEFAULT_MAX_STEPS_PER_GAME := 1600
const DEFAULT_STALL_STEP_LIMIT := 36
const DEFAULT_STEP_WAIT_SEC := 0.10
const DEFAULT_OPENING_TIMEOUT_SEC := 60.0
const DEFAULT_SEED_BASE := 620000

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var parsed := _extract_numeric_args(args)
	var game_count: int = int(parsed.get("game_count", DEFAULT_GAME_COUNT))
	var seed_base: int = int(parsed.get("seed_base", DEFAULT_SEED_BASE))
	var results_path := _build_results_path()
	print("ui_dual_ai_soak_v2: start results=%s game_count=%s seed_base=%s args=%s" % [
		results_path,
		str(game_count),
		str(seed_base),
		JSON.stringify(args)
	])
	var failures: Array[String] = []
	var summaries: Array[String] = []
	for i in range(game_count):
		var result := await _run_one_game(i, seed_base + i)
		summaries.append(JSON.stringify(result))
		if not bool(result.get("ok", false)):
			failures.append("game_%s seed=%s code=%s detail=%s" % [
				str(i),
				str(result.get("seed", -1)),
				str(result.get("code", "UNKNOWN")),
				str(result.get("detail", ""))
			])
	if not _write_results(results_path, game_count, failures, summaries):
		push_error("ui_dual_ai_soak_v2: write failed path=%s open_error=%s" % [
			results_path,
			str(FileAccess.get_open_error())
		])
		quit(1)
		return
	if failures.is_empty():
		print("ui_dual_ai_soak_v2: all %s games ok results=%s" % [game_count, results_path])
		quit(0)
		return
	for message in failures:
		push_error(message)
	push_error("ui_dual_ai_soak_v2: failed=%s results=%s" % [failures.size(), results_path])
	quit(1)

func _run_one_game(index: int, seed: int) -> Dictionary:
	var table = BattleTableScene.instantiate()
	root.add_child(table)
	await process_frame
	table._on_ai_mode_selected(2)
	table._ai_use_llm = true
	table._apply_ai_policy_mode({
		"ai_policy_mode": table.AI_POLICY_MODE_LLM,
		"ai_use_llm": true
	})
	table._pending_start_duel_seed = seed
	table._on_start_duel_pressed()
	await process_frame
	var opening_result := await _wait_for_formal_opening(table, DEFAULT_OPENING_TIMEOUT_SEC)
	if not bool(opening_result.get("ok", false)):
		table.queue_free()
		await process_frame
		return {
			"ok": false,
			"index": index,
			"seed": seed,
			"code": str(opening_result.get("code", "OPENING_TIMEOUT")),
			"detail": str(opening_result.get("detail", ""))
		}
	var last_command_count := _command_count(table)
	var stall_steps := 0
	for step in range(DEFAULT_MAX_STEPS_PER_GAME):
		await create_timer(DEFAULT_STEP_WAIT_SEC).timeout
		if table._state == null:
			table.queue_free()
			await process_frame
			return {"ok": false, "index": index, "seed": seed, "code": "NO_STATE_AFTER_OPENING"}
		table._on_ai_timer_timeout()
		await process_frame
		var current_count := _command_count(table)
		if int(table._state.winner) != -1:
			print("ui_dual_ai_soak_v2: game=%s seed=%s winner=%s steps=%s commands=%s" % [
				str(index),
				str(seed),
				str(int(table._state.winner)),
				str(step + 1),
				str(current_count)
			])
			table.queue_free()
			await process_frame
			return {
				"ok": true,
				"index": index,
				"seed": seed,
				"winner": int(table._state.winner),
				"steps": step + 1,
				"commands": current_count
			}
		if current_count != last_command_count:
			last_command_count = current_count
			stall_steps = 0
			continue
		stall_steps += 1
		if stall_steps < DEFAULT_STALL_STEP_LIMIT:
			continue
		var waiting: Dictionary = table._engine.get_waiting_state(table._state)
		var waiting_player := int(waiting.get("player_id", -1))
		var actions: Array = []
		if waiting_player >= 0:
			actions = table._engine.get_legal_actions(table._state, table._logical_player_for_display(waiting_player))
		var detail: String = JSON.stringify({
			"step": step + 1,
			"waiting": waiting,
			"phase": table._state.phase,
			"active_player": table._state.active_player,
			"priority_player": table._state.priority_player,
			"stack_size": table._state.stack.size(),
			"pending_attack": table._state.pending_attack,
			"pending_choice_count": table._state.pending_choices.size(),
			"waiting_player_actions": actions,
			"command_count": current_count
		})
		print("ui_dual_ai_soak_v2: stall index=%s seed=%s detail=%s" % [str(index), str(seed), detail])
		table.queue_free()
		await process_frame
		return {"ok": false, "index": index, "seed": seed, "code": "STALL", "detail": detail}
	table.queue_free()
	await process_frame
	return {"ok": false, "index": index, "seed": seed, "code": "STEP_LIMIT", "detail": str(DEFAULT_MAX_STEPS_PER_GAME)}

func _wait_for_formal_opening(table, timeout_sec: float) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if table != null and table._state != null:
			return {"ok": true}
		await create_timer(DEFAULT_STEP_WAIT_SEC).timeout
		await process_frame
	var active_prompt: Dictionary = {}
	var opening_visible := false
	var session_active := false
	if table != null:
		active_prompt = table._opening_session.get("active_prompt", {}) if table._opening_session is Dictionary else {}
		opening_visible = table._opening_overlay != null and table._opening_overlay.visible
		session_active = not table._opening_session.is_empty()
	return {
		"ok": false,
		"code": "OPENING_TIMEOUT",
		"detail": JSON.stringify({
			"session_active": session_active,
			"opening_visible": opening_visible,
			"active_prompt": active_prompt
		})
	}

func _command_count(table) -> int:
	if table == null or table._state == null:
		return 0
	return table._state.command_log.size()

func _build_results_path() -> String:
	var stamp: int = int(Time.get_unix_time_from_system())
	var root := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	return "%s/ui_dual_ai_soak_v2_%s.jsonl" % [root, str(stamp)]

func _write_results(results_path: String, game_count: int, failures: Array[String], summaries: Array[String]) -> bool:
	var file := FileAccess.open(results_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_line("game_count=%s" % game_count)
	file.store_line("failure_count=%s" % failures.size())
	for row in summaries:
		file.store_line(row)
	file.flush()
	file.close()
	return true

func _extract_numeric_args(args: Array) -> Dictionary:
	var numeric: Array[int] = []
	for item in args:
		var token := str(item)
		if token.is_valid_int():
			numeric.append(int(token))
	if numeric.size() >= 1:
		return {
			"game_count": numeric[0],
			"seed_base": numeric[1] if numeric.size() >= 2 else DEFAULT_SEED_BASE
		}
	return {}
