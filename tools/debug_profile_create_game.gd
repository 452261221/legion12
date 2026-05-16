extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

const DECK_PATH := "res://data/decks/starter_takamagahara_asgard_raw.json"

func _initialize() -> void:
	var started_at := Time.get_ticks_msec()
	var deck_text := FileAccess.get_file_as_string(DECK_PATH)
	var deck_data = JSON.parse_string(deck_text)
	if not (deck_data is Dictionary):
		push_error("profile create_game: failed to load duel deck")
		quit(1)
		return
	var defs_started := Time.get_ticks_msec()
	var definitions = CardDatabase.load_definitions()
	print("profile create_game: load_definitions ms=%s count=%s" % [str(Time.get_ticks_msec() - defs_started), str(definitions.size())])
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
	var trace_path := "user://battle_logs/profile_create_game_trace.log"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://battle_logs"))
	var reset_file := FileAccess.open(trace_path, FileAccess.WRITE)
	if reset_file != null:
		reset_file.store_line("profile create_game trace")
		reset_file.close()
	var engine := GameEngine.new()
	var create_started := Time.get_ticks_msec()
	var state = engine.create_game(definitions, deck_lists, 246810, player_metadata, {
		"mode": "formal",
		"debug_trace_path": trace_path
	})
	print("profile create_game: create_game ms=%s state=%s" % [str(Time.get_ticks_msec() - create_started), str(state != null)])
	if state != null:
		print("profile create_game: hand0=%s hand1=%s morale0=%s morale1=%s" % [
			str(state.get_player(0).hand.cards.size()),
			str(state.get_player(1).hand.cards.size()),
			str(state.get_player(0).cost_area.cards.size()),
			str(state.get_player(1).cost_area.cards.size())
		])
	print("profile create_game: total ms=%s" % [str(Time.get_ticks_msec() - started_at)])
	quit(0)
