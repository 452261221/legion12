extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")

const LOG_PATH := "user://battle_logs/duel_1777662745_正式对局.log"


func _initialize() -> void:
	var failures: Array[String] = []
	_replay_latest_alvilda_log(failures)
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _replay_latest_alvilda_log(failures: Array[String]) -> void:
	var lines := _read_log_lines(failures)
	if lines.is_empty():
		return
	var setup := _parse_setup(lines, failures)
	if setup.is_empty():
		return
	var state = _create_state_from_setup(setup, failures)
	if state == null:
		return
	var engine := GameEngine.new()
	var before_activate_dumped := false
	for line in lines:
		if not line.begins_with("[CMD] "):
			continue
		var parsed := _parse_cmd_line(line)
		if parsed.is_empty():
			continue
		var player_id := int(parsed.get("player_id", -1))
		var command_type := str(parsed.get("command_type", ""))
		var payload: Dictionary = parsed.get("payload", {})
		if command_type == "ActivateEffect" and str(payload.get("effect_id", "")) == "alvilda_blood_summon":
			_dump_player_hand(state, 1, "BEFORE_ACTIVATE")
			before_activate_dumped = true
		var result = engine.apply_command(state, GameCommand.create(player_id, command_type, payload))
		if not bool(result.get("ok", false)):
			failures.append("replay latest alvilda log: command failed %s %s" % [command_type, JSON.stringify(payload)])
			return
		if command_type == "ActivateEffect" and str(payload.get("effect_id", "")) == "alvilda_blood_summon":
			_auto_pass_priority(engine, state, failures)
			print("AFTER_ACTIVATE waiting=%s" % JSON.stringify(engine.get_waiting_state(state)))
			print("AFTER_ACTIVATE pending_choices=%s stack=%s" % [str(state.pending_choices.size()), str(state.stack.size())])
			if not state.pending_choices.is_empty():
				print("AFTER_ACTIVATE choice=%s" % JSON.stringify(state.pending_choices[0]))
			break
	if not before_activate_dumped:
		failures.append("replay latest alvilda log: did not find alvilda activate command")


func _read_log_lines(failures: Array[String]) -> PackedStringArray:
	var text := FileAccess.get_file_as_string(LOG_PATH)
	if text.is_empty():
		failures.append("replay latest alvilda log: failed to read log %s" % LOG_PATH)
		return PackedStringArray()
	return text.split("\n", false)


func _parse_setup(lines: PackedStringArray, failures: Array[String]) -> Dictionary:
	var deck_path := ""
	var seed := -1
	for line in lines:
		if line.begins_with("deck="):
			deck_path = line.trim_prefix("deck=")
		elif line.contains("种子="):
			var marker := "种子="
			var seed_text := line.substr(line.find(marker) + marker.length())
			if seed_text.is_valid_int():
				seed = int(seed_text)
	if deck_path.is_empty() or seed < 0:
		failures.append("replay latest alvilda log: missing deck path or seed")
		return {}
	return {
		"deck_path": deck_path,
		"seed": seed
	}


func _create_state_from_setup(setup: Dictionary, failures: Array[String]):
	var deck_text := FileAccess.get_file_as_string(str(setup.get("deck_path", "")))
	var deck_data = JSON.parse_string(deck_text)
	if not (deck_data is Dictionary):
		failures.append("replay latest alvilda log: failed to parse deck file")
		return null
	var definitions = CardDatabase.load_definitions()
	var raw_players: Array = deck_data.get("players", [])
	var deck_lists: Array = []
	var player_metadata: Array = []
	for player_index in range(2):
		var raw_player: Dictionary = {}
		if player_index < raw_players.size():
			raw_player = raw_players[player_index]
		deck_lists.append(raw_player.get("deck", []).duplicate())
		player_metadata.append({
			"name": str(raw_player.get("name", "Player %d" % (player_index + 1))),
			"master_name": str(raw_player.get("master_name", "Master")),
			"master_id": str(raw_player.get("master_id", "")),
			"master_hp": int(raw_player.get("master_hp", 20)),
			"master_max_hp": int(raw_player.get("master_max_hp", 20))
		})
	var engine := GameEngine.new()
	return engine.create_game(definitions, deck_lists, int(setup.get("seed", 1)), player_metadata, {
		"mode": "formal"
	})


func _parse_cmd_line(line: String) -> Dictionary:
	var payload_start := line.find("{")
	var payload_text := "{}"
	var prefix := line
	if payload_start != -1:
		payload_text = line.substr(payload_start)
		prefix = line.substr(0, payload_start).strip_edges()
	var parts := prefix.split(" ", false)
	if parts.size() < 3:
		return {}
	var player_text := str(parts[1]).trim_prefix("P")
	if not player_text.is_valid_int():
		return {}
	var payload = JSON.parse_string(payload_text)
	if not (payload is Dictionary):
		payload = {}
	return {
		"player_id": int(player_text),
		"command_type": str(parts[2]),
		"payload": payload
	}


func _auto_pass_priority(engine: GameEngine, state, failures: Array[String]) -> void:
	for _i in range(12):
		if state.pending_choices.is_empty() and state.stack.is_empty() and state.pending_attack.is_empty():
			return
		var waiting: Dictionary = engine.get_waiting_state(state)
		if str(waiting.get("state", "")) != "WaitingForPriority":
			return
		var result = engine.apply_command(state, GameCommand.create(int(waiting.get("player_id", -1)), "PassPriority"))
		if not bool(result.get("ok", false)):
			failures.append("replay latest alvilda log: auto pass priority failed")
			return


func _dump_player_hand(state, player_id: int, tag: String) -> void:
	var rows: Array[String] = []
	var level2: Array[String] = []
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance == null:
			continue
		var definition = state.get_definition(instance.definition_id)
		if definition == null:
			continue
		rows.append("%s|%s|%s|calamity=%s|cost=%s" % [
			card_id,
			str(instance.definition_id),
			str(definition.name),
			str(definition.calamity_level),
			str(definition.cost)
		])
		if int(definition.calamity_level) == 2 and str(definition.type) == "legion":
			level2.append("%s|%s" % [card_id, str(definition.name)])
	print("%s HAND=%s" % [tag, JSON.stringify(rows)])
	print("%s LEVEL2=%s" % [tag, JSON.stringify(level2)])
