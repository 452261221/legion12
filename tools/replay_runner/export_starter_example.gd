extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ReplayIO = preload("res://tools/replay_runner/replay_io.gd")

const OUTPUT_REPLAY_PATH := "res://data/replays/starter_duel_artifact_example.json"

func _initialize() -> void:
	var definitions = CardDatabase.load_definitions()
	if definitions.is_empty():
		push_error("failed to load card definitions")
		quit(1)
		return
	var engine = GameEngine.new()
	var state = engine.create_game(definitions, _starter_artifact_replay_decks(), 1329)
	if not _run_scripted_example(engine, state):
		quit(1)
		return
	var absolute_output_path = ProjectSettings.globalize_path(OUTPUT_REPLAY_PATH)
	var save_result = ReplayIO.save_replay_data(engine.export_replay_data(state), absolute_output_path)
	if not bool(save_result.get("ok", false)):
		push_error("failed to save replay example: %s" % str(save_result.get("code", "UNKNOWN")))
		quit(1)
		return
	print(absolute_output_path)
	quit(0)

func _run_scripted_example(engine: GameEngine, state) -> bool:
	if not _apply(engine, state, 1, "EndPhase"):
		return false
	if not _apply(engine, state, 1, "EndPhase"):
		return false
	if not _apply(engine, state, 1, "EndPhase"):
		return false
	if not _apply(engine, state, 0, "EndPhase"):
		return false
	if not _apply(engine, state, 0, "EndPhase"):
		return false
	if not _apply(engine, state, 0, "EndPhase"):
		return false
	if not _apply(engine, state, 1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	}):
		return false
	var destroy_target_card_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0416")
	if destroy_target_card_id.is_empty():
		push_error("starter replay example is missing enemy target")
		return false
	if not _apply(engine, state, 1, "PlayCard", {
		"card_id": destroy_target_card_id,
		"row": "front",
		"col": 0
	}):
		return false
	if not _apply(engine, state, 1, "EndPhase"):
		return false
	if not _apply(engine, state, 1, "EndPhase"):
		return false
	if not _apply(engine, state, 1, "EndPhase"):
		return false
	if not _apply(engine, state, 0, "EndPhase"):
		return false
	if not _apply(engine, state, 0, "EndPhase"):
		return false
	if not _apply(engine, state, 0, "EndPhase"):
		return false
	if not _apply(engine, state, 0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	}):
		return false
	var ally_card_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	var kusanagi_card_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	if ally_card_id.is_empty() or kusanagi_card_id.is_empty():
		push_error("starter replay example is missing ally or artifact card")
		return false
	if not _apply(engine, state, 0, "PlayCard", {
		"card_id": ally_card_id,
		"row": "front",
		"col": 0
	}):
		return false
	var ally_instance_id = state.get_player(0).battle_front[0].occupant
	if ally_instance_id.is_empty():
		push_error("starter replay example failed to deploy ally")
		return false
	if not _apply(engine, state, 0, "PlayCard", {
		"card_id": kusanagi_card_id,
		"row": "artifact",
		"col": -1
	}):
		return false
	if not _apply(engine, state, 1, "PassPriority"):
		return false
	if not _apply(engine, state, 0, "PassPriority"):
		return false
	if not _apply(engine, state, 0, "ActivateEffect", {
		"source_id": kusanagi_card_id,
		"effect_id": "kusanagi_assault",
		"target_card_id": ally_instance_id
	}):
		return false
	if not _apply(engine, state, 1, "PassPriority"):
		return false
	if not _apply(engine, state, 0, "PassPriority"):
		return false
	return true

func _apply(engine: GameEngine, state, player_id: int, command_type: String, payload: Dictionary = {}) -> bool:
	var result = engine.apply_command(state, GameCommand.create(player_id, command_type, payload))
	if bool(result.get("ok", false)):
		return true
	push_error("starter replay example command failed: %s %s" % [command_type, str(result.get("code", "UNKNOWN"))])
	return false

func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

func _starter_artifact_replay_decks() -> Array:
	return [
		["takamagahara_s01_0417", "takamagahara_s01_0416", "neutral_s01_0015", "neutral_s01_0016", "takamagahara_s01_0418", "takamagahara_s01_0409"],
		["takamagahara_s01_0416", "neutral_s01_0015", "neutral_s01_0016", "asgard_s01_0318", "asgard_s01_0303", "asgard_s01_0312"]
	]
