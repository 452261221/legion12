extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const AiController = preload("res://ai/runtime/ai_controller.gd")
const FakeLlmClient = preload("res://ai/llm/fake_llm_client.gd")
const LlmProviderRegistry = preload("res://ai/llm/llm_provider_registry.gd")
const OpenAICompatibleLlmClient = preload("res://ai/llm/openai_compatible_llm_client.gd")
const TRACE_DIR := "user://battle_logs"
const TRACE_FALLBACK_DIR := "res://tmp_ai_eval"

const CARD_DATA_PATHS := [
	"res://data/cards/starter_duel_raw_cards.json",
	"res://data/cards/calamity_cards.json",
	"res://data/cards/classic_batch_1.json",
	"res://data/cards/dev_cards.json",
	"res://data/cards/demo_cards.json",
	"res://data/cards/test_cards.json",
	"res://data/raw_rule_cards/starter_duel_master_cards.json",
]

const DEFAULT_DECK_PATH := "res://data/decks/starter_takamagahara_asgard_raw.json"

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	print("ai selfplay starting args=%s" % JSON.stringify(args))
	if not args.is_empty() and str(args[0]).to_lower().ends_with(".json"):
		_run_fixed_eval_suite(str(args[0]))
		return
	var game_count := 10
	var deck_path := DEFAULT_DECK_PATH
	var seed_base := 9000
	var ai_policy_mode := AiController.POLICY_MODE_SCRIPTED
	var trace_prefix := ""
	var max_steps := 400
	var allow_turn_limit := false
	var fake_llm_mode := "first_candidate"
	var use_real_llm := false
	var llm_provider := "deepseek"
	if args.size() >= 1 and String(args[0]).is_valid_int():
		game_count = int(args[0])
	if args.size() >= 2:
		deck_path = str(args[1])
	if args.size() >= 3 and String(args[2]).is_valid_int():
		seed_base = int(args[2])
	if args.size() >= 4:
		var raw_mode := str(args[3]).to_lower()
		if raw_mode == AiController.POLICY_MODE_LLM:
			ai_policy_mode = AiController.POLICY_MODE_LLM
	allow_turn_limit = ai_policy_mode == AiController.POLICY_MODE_LLM
	if args.size() >= 5:
		var raw_trace := str(args[4]).strip_edges()
		if raw_trace.to_lower() == "trace":
			trace_prefix = "%s/ai_selfplay_trace" % TRACE_DIR
		else:
			trace_prefix = raw_trace.replace("\\", "/")
			if trace_prefix.find("://") < 0 and trace_prefix.find(":") < 0:
				var base := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
				trace_prefix = "%s/%s" % [base, trace_prefix.lstrip("./").lstrip(".\\").lstrip("/")]
	if args.size() >= 6 and String(args[5]).is_valid_int():
		max_steps = max(10, int(args[5]))
	if args.size() >= 7 and str(args[6]).to_lower() == "strict":
		allow_turn_limit = false
	if args.size() >= 8:
		fake_llm_mode = str(args[7]).strip_edges()
		if fake_llm_mode.is_empty():
			fake_llm_mode = "first_candidate"
	if ai_policy_mode == AiController.POLICY_MODE_LLM:
		var registry := LlmProviderRegistry.new()
		var probe_provider := str(fake_llm_mode).strip_edges().to_lower()
		if probe_provider == "real":
			use_real_llm = true
		elif registry.get_supported_providers().has(probe_provider):
			use_real_llm = true
			llm_provider = probe_provider
		if args.size() >= 9:
			var explicit_provider := str(args[8]).strip_edges().to_lower()
			if registry.get_supported_providers().has(explicit_provider):
				use_real_llm = true
				llm_provider = explicit_provider
	if not trace_prefix.is_empty():
		var trace_dir := trace_prefix
		var last_slash := trace_dir.rfind("/")
		if last_slash >= 0:
			trace_dir = trace_dir.substr(0, last_slash)
		var absolute_trace_dir := trace_dir
		if trace_dir.begins_with("user://") or trace_dir.begins_with("res://"):
			absolute_trace_dir = ProjectSettings.globalize_path(trace_dir)
		DirAccess.make_dir_recursive_absolute(absolute_trace_dir)
		var probe := FileAccess.open("%s/ai_selfplay_probe.txt" % absolute_trace_dir, FileAccess.WRITE)
		if probe != null:
			probe.store_line("ai selfplay probe mode=%s deck=%s llm=%s provider=%s" % [ai_policy_mode, deck_path, str(use_real_llm), llm_provider])
			probe.close()
	var definitions := _load_definitions()
	if definitions.is_empty():
		push_error("ai selfplay failed: no card definitions loaded")
		quit(1)
		return
	var deck_info := _load_deck(deck_path)
	if deck_info.is_empty():
		push_error("ai selfplay failed: unable to load deck %s" % deck_path)
		quit(1)
		return
	var batch_result := _run_selfplay_batch(
		definitions,
		deck_info,
		game_count,
		seed_base,
		ai_policy_mode,
		trace_prefix,
		max_steps,
		allow_turn_limit,
		fake_llm_mode,
		use_real_llm,
		llm_provider,
		{}
	)
	if bool(batch_result.get("ok", false)):
		quit(0)
		return
	for message in batch_result.get("failures", []):
		push_error(str(message))
	quit(1)

func _run_selfplay_batch(definitions: Array, deck_info: Dictionary, game_count: int, seed_base: int, ai_policy_mode: String, trace_prefix: String, max_steps: int, allow_turn_limit: bool, fake_llm_mode: String, use_real_llm: bool, llm_provider: String, llm_runtime_options: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = []
	var finished := 0
	var summary_path := ""
	var summary_lines: Array[String] = []
	if not trace_prefix.is_empty():
		var resolved_summary_prefix := trace_prefix
		if resolved_summary_prefix.begins_with("user://") or resolved_summary_prefix.begins_with("res://"):
			resolved_summary_prefix = ProjectSettings.globalize_path(resolved_summary_prefix)
		summary_path = "%s_%s_summary.log" % [resolved_summary_prefix, ai_policy_mode]
		summary_lines.append("ai selfplay summary mode=%s games=%s seed_base=%s" % [ai_policy_mode, str(game_count), str(seed_base)])
		_flush_summary_trace(summary_path, summary_lines)
	for i in range(game_count):
		var engine = GameEngine.new()
		var seed := seed_base + i
		print("ai selfplay game_start index=%s seed=%s mode=%s real_llm=%s provider=%s" % [str(i), str(seed), ai_policy_mode, str(use_real_llm), llm_provider])
		var game_options: Dictionary = deck_info.get("game_options", {}).duplicate(true)
		var step_trace_path := ""
		var ai_trace_path := ""
		if not trace_prefix.is_empty():
			var resolved_trace_prefix := trace_prefix
			if resolved_trace_prefix.begins_with("user://") or resolved_trace_prefix.begins_with("res://"):
				resolved_trace_prefix = ProjectSettings.globalize_path(resolved_trace_prefix)
			var engine_trace_path := "%s_%s_%s_engine.log" % [resolved_trace_prefix, ai_policy_mode, str(seed)]
			step_trace_path = "%s_%s_%s_steps.log" % [resolved_trace_prefix, ai_policy_mode, str(seed)]
			ai_trace_path = "%s_%s_%s_ai.log" % [resolved_trace_prefix, ai_policy_mode, str(seed)]
			var reset_file := FileAccess.open(engine_trace_path, FileAccess.WRITE)
			if reset_file != null:
				reset_file.store_line("ai selfplay engine trace seed=%s mode=%s" % [str(seed), ai_policy_mode])
				reset_file.close()
			var step_reset := FileAccess.open(step_trace_path, FileAccess.WRITE)
			if step_reset != null:
				step_reset.store_line("ai selfplay step trace seed=%s mode=%s max_steps=%s" % [str(seed), ai_policy_mode, str(max_steps)])
				step_reset.close()
			var ai_reset := FileAccess.open(ai_trace_path, FileAccess.WRITE)
			if ai_reset != null:
				ai_reset.store_line("ai selfplay raw llm trace seed=%s mode=%s max_steps=%s" % [str(seed), ai_policy_mode, str(max_steps)])
				ai_reset.close()
			game_options["debug_trace_path"] = engine_trace_path
		var state = engine.create_game(definitions, deck_info.get("deck_lists", []), seed, deck_info.get("player_metadata", []), game_options)
		var result := _run_one_game(engine, state, deck_info, seed, ai_policy_mode, max_steps, allow_turn_limit, step_trace_path, ai_trace_path, fake_llm_mode, use_real_llm, llm_provider, llm_runtime_options)
		if not bool(result.get("ok", false)):
			_append_step_trace(step_trace_path, "[GAME] fail seed=%s code=%s message=%s" % [str(seed), str(result.get("code", "")), str(result.get("message", ""))])
			summary_lines.append("[GAME] fail index=%s seed=%s code=%s message=%s" % [str(i), str(seed), str(result.get("code", "")), str(result.get("message", ""))])
			_flush_summary_trace(summary_path, summary_lines)
			print("ai selfplay game_fail index=%s seed=%s code=%s message=%s" % [str(i), str(seed), str(result.get("code", "")), str(result.get("message", ""))])
			failures.append("game_%s: %s" % [str(i), str(result.get("message", result.get("code", "UNKNOWN")))])
		else:
			_append_step_trace(step_trace_path, "[GAME] ok seed=%s winner=%s ended=%s" % [str(seed), str(result.get("winner", -1)), str(result.get("ended", "winner"))])
			summary_lines.append("[GAME] ok index=%s seed=%s winner=%s ended=%s" % [str(i), str(seed), str(result.get("winner", -1)), str(result.get("ended", "winner"))])
			_flush_summary_trace(summary_path, summary_lines)
			print("ai selfplay game_ok index=%s seed=%s winner=%s ended=%s" % [str(i), str(seed), str(result.get("winner", -1)), str(result.get("ended", "winner"))])
			finished += 1
	summary_lines.append("[DONE] finished=%s total=%s failures=%s" % [str(finished), str(game_count), str(failures.size())])
	_flush_summary_trace(summary_path, summary_lines)
	print("ai selfplay finished: %s/%s ok" % [finished, game_count])
	return {
		"ok": failures.is_empty(),
		"finished": finished,
		"total": game_count,
		"failures": failures.duplicate(),
		"summary_path": summary_path
	}

func _run_one_game(engine: GameEngine, state, deck_info: Dictionary, seed: int, ai_policy_mode: String, max_steps: int, allow_turn_limit: bool, step_trace_path: String, ai_trace_path: String, fake_llm_mode: String, use_real_llm: bool, llm_provider: String, llm_runtime_options: Dictionary = {}) -> Dictionary:
	var controller := AiController.new()
	var client = null
	var persisted_settings: Dictionary = {}
	if ai_policy_mode == AiController.POLICY_MODE_LLM:
		var registry := LlmProviderRegistry.new()
		persisted_settings = registry.load_settings()
		if use_real_llm:
			var runtime_options := {
				"llm_provider": llm_provider,
				"llm_debug": true
			}
			for key in llm_runtime_options.keys():
				runtime_options[str(key)] = llm_runtime_options.get(key)
			var resolved := registry.resolve_runtime_options(runtime_options)
			var debug_probe_mode := str(fake_llm_mode).strip_edges().to_lower()
			if debug_probe_mode == "repair_probe_real":
				resolved["debug_force_invalid_candidate_count"] = 1
			elif debug_probe_mode == "fallback_probe_real":
				resolved["debug_force_invalid_candidate_count"] = 2
			if str(resolved.get("api_key", "")).is_empty():
				_append_step_trace(step_trace_path, "[ERR] missing_api_key provider=%s env=%s" % [llm_provider, str(resolved.get("api_key_env", ""))])
				return {"ok": false, "code": "MISSING_API_KEY"}
			var real_client := OpenAICompatibleLlmClient.new()
			real_client.configure(resolved)
			client = real_client
		else:
			var fake_client := FakeLlmClient.new()
			fake_client.set_mode(fake_llm_mode)
			client = fake_client
		controller.set_llm_client(client)
	controller.set_policy_mode(ai_policy_mode, {
		"enabled": true
	})
	controller.set_match_context({
		"deck_id": str(deck_info.get("deck_id", "")),
		"match_seed": seed,
		"player_profiles": deck_info.get("player_profiles", []).duplicate(),
		"ai_policy_mode": ai_policy_mode,
		"ai_prompt": str(persisted_settings.get("ai_prompt", ""))
	})
	_append_step_trace(step_trace_path, "[SETUP] rules_md=%s ai_prompt_chars=%s" % [
		str(FileAccess.file_exists("res://规则/规则.md")),
		str(str(persisted_settings.get("ai_prompt", "")).length())
	])
	var guard := 0
	while state != null and state.winner == -1 and guard < max_steps:
		guard += 1
		var waiting: Dictionary = engine.get_waiting_state(state)
		var player_id := int(waiting.get("player_id", -1))
		if player_id < 0:
			_append_step_trace(step_trace_path, "[STEP] %s err=no_waiting_player waiting=%s" % [str(guard), JSON.stringify(waiting)])
			return {"ok": false, "code": "NO_WAITING_PLAYER"}
		var actions: Array = engine.get_legal_actions(state, player_id)
		if actions.is_empty():
			_append_step_trace(step_trace_path, "[STEP] %s err=no_legal_actions p=%s waiting=%s" % [str(guard), str(player_id), JSON.stringify(waiting)])
			return {"ok": false, "code": "NO_LEGAL_ACTIONS"}
		_append_step_trace(step_trace_path, "[STEP] %s waiting=%s p=%s actions=%s" % [str(guard), str(waiting.get("state", "")), str(player_id), str(actions.size())])
		var decision: Dictionary = controller.drive_engine_step(engine, state, player_id, actions)
		if decision.is_empty():
			_append_step_trace(step_trace_path, "[STEP] %s err=no_decision p=%s waiting=%s" % [str(guard), str(player_id), JSON.stringify(waiting)])
			return {"ok": false, "code": "NO_DECISION"}
		var debug_summary := str(decision.get("debug_summary", ""))
		if debug_summary.is_empty():
			debug_summary = "[AI] source=%s cmd=%s candidate_id=%s fallback_reason=%s" % [
				str(decision.get("source", "")),
				str(decision.get("command_type", "")),
				str(decision.get("candidate_id", "")),
				str(decision.get("fallback_reason", decision.get("reason", "")))
			]
		_append_step_trace(step_trace_path, "[STEP] %s %s" % [str(guard), debug_summary])
		var fallback_reason := str(decision.get("fallback_reason", ""))
		if not fallback_reason.is_empty():
			_append_step_trace(step_trace_path, "[STEP] %s fallback reason=%s source=%s candidate_id=%s command=%s" % [
				str(guard),
				fallback_reason,
				str(decision.get("source", "")),
				str(decision.get("candidate_id", "")),
				str(decision.get("command_type", ""))
			])
		var command_type := str(decision.get("command_type", ""))
		var payload: Dictionary = decision.get("payload", {})
		var applied = engine.apply_command(state, GameCommand.create(player_id, command_type, payload))
		if not bool(applied.get("ok", false)):
			_append_ai_raw_trace(ai_trace_path, seed, guard, player_id, waiting, decision, {
				"ok": false,
				"code": str(applied.get("code", applied.get("error_code", "APPLY_FAILED"))),
				"message": str(applied.get("message", ""))
			})
			if controller != null and controller.has_method("record_engine_execution"):
				controller.record_engine_execution(engine, state, decision.duplicate(true), {
					"ok": false,
					"code": str(applied.get("code", applied.get("error_code", "APPLY_FAILED"))),
					"message": str(applied.get("message", ""))
				})
			_append_step_trace(step_trace_path, "[STEP] %s apply_failed code=%s message=%s" % [
				str(guard),
				str(applied.get("code", applied.get("error_code", "APPLY_FAILED"))),
				str(applied.get("message", ""))
			])
			return {"ok": false, "code": str(applied.get("code", applied.get("error_code", "APPLY_FAILED"))), "message": str(applied.get("message", ""))}
		_append_ai_raw_trace(ai_trace_path, seed, guard, player_id, waiting, decision, {"ok": true})
		if controller != null and controller.has_method("record_engine_execution"):
			controller.record_engine_execution(engine, state, decision.duplicate(true), {"ok": true})
	if state == null:
		_append_step_trace(step_trace_path, "[END] no_state")
		return {"ok": false, "code": "NO_STATE"}
	if state.winner == -1:
		if allow_turn_limit:
			_append_step_trace(step_trace_path, "[END] turn_limit steps=%s" % str(guard))
			return {"ok": true, "winner": -1, "ended": "turn_limit"}
		_append_step_trace(step_trace_path, "[END] turn_limit_fail steps=%s" % str(guard))
		return {"ok": false, "code": "TURN_LIMIT"}
	_append_step_trace(step_trace_path, "[END] winner=%s steps=%s" % [str(state.winner), str(guard)])
	return {"ok": true, "winner": int(state.winner)}

func _append_step_trace(step_trace_path: String, line: String) -> void:
	if step_trace_path.is_empty():
		return
	var file := FileAccess.open(step_trace_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()

func _append_ai_raw_trace(ai_trace_path: String, seed: int, step_index: int, player_id: int, waiting: Dictionary, decision: Dictionary, result: Dictionary) -> void:
	if ai_trace_path.is_empty() or decision.is_empty():
		return
	var llm_response: Dictionary = decision.get("llm_response", {})
	var response_summary := str(decision.get("llm_response_summary", ""))
	var source := str(decision.get("source", ""))
	if source != "llm" and llm_response.is_empty() and response_summary.is_empty():
		return
	var entry := {
		"timestamp": int(Time.get_unix_time_from_system()),
		"seed": seed,
		"step_index": step_index,
		"player_id": player_id,
		"waiting_state": waiting.duplicate(true),
		"decision": {
			"source": source,
			"candidate_id": str(decision.get("candidate_id", "")),
			"command_type": str(decision.get("command_type", "")),
			"payload": decision.get("payload", {}).duplicate(true),
			"brief_reason": str(decision.get("brief_reason", "")),
			"repair_attempted": bool(decision.get("repair_attempted", false)),
			"repaired_from": str(decision.get("repaired_from", "")),
			"fallback_reason": str(decision.get("fallback_reason", result.get("fallback_reason", ""))),
			"llm_response_summary": response_summary
		},
		"result": result.duplicate(true),
		"llm_response": llm_response.duplicate(true)
	}
	var file := FileAccess.open(ai_trace_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("=== AI RAW BEGIN ===")
	for line in JSON.stringify(entry, "\t").split("\n"):
		file.store_line(line)
	file.store_line("=== AI RAW END ===")
	file.close()

func _flush_summary_trace(summary_path: String, lines: Array[String]) -> void:
	if summary_path.is_empty() or lines.is_empty():
		return
	var file := FileAccess.open(summary_path, FileAccess.WRITE)
	if file == null:
		return
	for line in lines:
		file.store_line(line)
	file.close()

func _load_definitions() -> Array:
	var merged: Array = []
	for path in CARD_DATA_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if parsed is Array:
			merged.append_array(parsed)
	var errors = CardDatabase.validate_definition_dicts(merged)
	if not errors.is_empty():
		for message in errors:
			push_error("ai selfplay card data validation failed: %s" % message)
		return []
	return merged

func _load_deck(deck_path: String) -> Dictionary:
	var deck_text := FileAccess.get_file_as_string(deck_path)
	var deck_data = JSON.parse_string(deck_text)
	if not (deck_data is Dictionary):
		return {}
	var raw_players: Array = deck_data.get("players", [])
	var deck_lists: Array = []
	var player_metadata: Array = []
	var player_profiles: Array[String] = []
	for player_index in range(2):
		var raw_player: Dictionary = {}
		if player_index < raw_players.size() and raw_players[player_index] is Dictionary:
			raw_player = raw_players[player_index]
		deck_lists.append(raw_player.get("deck", []).duplicate())
		player_metadata.append({
			"name": str(raw_player.get("name", "Player %d" % (player_index + 1))),
			"master_id": str(raw_player.get("master_id", "")),
			"master_name": str(raw_player.get("master_name", "")),
		})
		player_profiles.append(str(raw_player.get("ai_profile_id", "")))
	var game_options: Dictionary = deck_data.get("game_options", {})
	return {
		"deck_id": str(deck_data.get("id", "")),
		"deck_lists": deck_lists,
		"player_metadata": player_metadata,
		"game_options": game_options,
		"player_profiles": player_profiles
	}

func _run_fixed_eval_suite(suite_path: String) -> void:
	var suite_text := FileAccess.get_file_as_string(suite_path)
	var parsed = JSON.parse_string(suite_text)
	if not (parsed is Dictionary):
		push_error("ai fixed eval failed: invalid suite json %s" % suite_path)
		quit(1)
		return
	var suite: Dictionary = parsed
	var suite_name := str(suite.get("name", "fixed_eval"))
	var suite_cases: Array = suite.get("cases", [])
	if suite_cases.is_empty():
		push_error("ai fixed eval failed: suite has no cases %s" % suite_path)
		quit(1)
		return
	var definitions := _load_definitions()
	if definitions.is_empty():
		push_error("ai fixed eval failed: no card definitions loaded")
		quit(1)
		return
	var trace_root := str(suite.get("trace_root", "user://battle_logs/fixed_eval/%s" % suite_name)).replace("\\", "/")
	var trace_root_absolute := trace_root
	if trace_root.begins_with("user://") or trace_root.begins_with("res://"):
		trace_root_absolute = ProjectSettings.globalize_path(trace_root)
	if DirAccess.make_dir_recursive_absolute(trace_root_absolute) != OK and trace_root.begins_with("user://"):
		trace_root_absolute = "%s/%s" % [ProjectSettings.globalize_path(TRACE_FALLBACK_DIR), suite_name]
		DirAccess.make_dir_recursive_absolute(trace_root_absolute)
	var suite_summary_path := "%s/suite_summary.log" % trace_root_absolute
	var suite_lines: Array[String] = ["ai fixed eval suite=%s cases=%s" % [suite_name, str(suite_cases.size())]]
	_flush_summary_trace(suite_summary_path, suite_lines)
	var suite_failures: Array[String] = []
	for raw_case in suite_cases:
		if not (raw_case is Dictionary):
			continue
		var case_config: Dictionary = raw_case
		var case_name := str(case_config.get("name", "case_%s" % str(suite_lines.size())))
		var deck_path := str(case_config.get("deck_path", DEFAULT_DECK_PATH))
		var deck_info := _load_deck(deck_path)
		if deck_info.is_empty():
			suite_failures.append("%s: invalid_deck" % case_name)
			suite_lines.append("[CASE] fail name=%s reason=invalid_deck" % case_name)
			_flush_summary_trace(suite_summary_path, suite_lines)
			continue
		var case_trace_prefix := str(case_config.get("trace_prefix", "%s/%s" % [trace_root_absolute, case_name])).replace("\\", "/")
		var ai_policy_mode := str(case_config.get("ai_policy_mode", AiController.POLICY_MODE_LLM)).to_lower()
		if ai_policy_mode != AiController.POLICY_MODE_LLM:
			ai_policy_mode = AiController.POLICY_MODE_SCRIPTED
		var case_result := _run_selfplay_batch(
			definitions,
			deck_info,
			max(1, int(case_config.get("game_count", 1))),
			int(case_config.get("seed_base", 9000)),
			ai_policy_mode,
			case_trace_prefix,
			max(10, int(case_config.get("max_steps", 40))),
			bool(case_config.get("allow_turn_limit", ai_policy_mode == AiController.POLICY_MODE_LLM)),
			str(case_config.get("fake_llm_mode", "first_candidate")),
			bool(case_config.get("use_real_llm", ai_policy_mode == AiController.POLICY_MODE_LLM)),
			str(case_config.get("llm_provider", "deepseek")),
			case_config.get("llm_runtime_options", {}).duplicate(true) if case_config.get("llm_runtime_options", {}) is Dictionary else {}
		)
		if bool(case_result.get("ok", false)):
			suite_lines.append("[CASE] ok name=%s finished=%s total=%s summary=%s" % [
				case_name,
				str(case_result.get("finished", 0)),
				str(case_result.get("total", 0)),
				str(case_result.get("summary_path", ""))
			])
		else:
			suite_failures.append("%s: failed" % case_name)
			suite_lines.append("[CASE] fail name=%s finished=%s total=%s summary=%s" % [
				case_name,
				str(case_result.get("finished", 0)),
				str(case_result.get("total", 0)),
				str(case_result.get("summary_path", ""))
			])
		_flush_summary_trace(suite_summary_path, suite_lines)
	suite_lines.append("[DONE] ok=%s total=%s failures=%s" % [
		str(suite_failures.is_empty()),
		str(suite_cases.size()),
		str(suite_failures.size())
	])
	_flush_summary_trace(suite_summary_path, suite_lines)
	if suite_failures.is_empty():
		print("ai fixed eval suite passed: %s" % suite_summary_path)
		quit(0)
		return
	for failure in suite_failures:
		push_error(failure)
	quit(1)
