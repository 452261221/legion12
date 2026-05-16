extends RefCounted
class_name TestReplayIO

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ReplayIO = preload("res://client/scripts/replay/replay_io.gd")
const ReplayRunner = preload("res://client/scripts/replay/replay_runner.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 321)

	var p0_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_card,
		"row": "front",
		"col": 0
	})).ok, "replay setup play should succeed", failures)

	var replay_data = engine.export_replay_data(state)
	var replay_path = _runtime_replay_path("unit_test_replay.json")
	var save_result = ReplayIO.save_replay_data(replay_data, replay_path)
	_expect(save_result.ok, "replay file should save", failures)
	_expect(str(replay_data.get("commands", [])[0].get("state_hash_before", "")) != "", "replay command should include state_hash_before", failures)
	_expect(str(replay_data.get("commands", [])[0].get("state_hash_after", "")) != "", "replay command should include state_hash_after", failures)

	var load_result = ReplayIO.load_replay_data(replay_path)
	_expect(load_result.ok, "replay file should load", failures)
	var loaded_replay: Dictionary = load_result.get("data", {})
	_expect(int(loaded_replay.get("setup", {}).get("seed", 0)) == 321, "replay seed should match", failures)

	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_file(replay_path)
	_expect(replay_result.ok, "replay runner should succeed", failures)
	if replay_result.ok:
		_expect(replay_result.state.players[0].battle_front[0].occupant != "", "replayed battlefield should contain the unit", failures)
		_expect(replay_result.state.command_log.size() == state.command_log.size(), "replayed command count should match", failures)
	_test_hash_mismatch_detection(failures)
	_test_invalid_replay_schema_detection(failures)
	_test_save_rejects_invalid_replay_schema(failures)
	_test_replay_runner_rejects_missing_card_data(failures)
	_test_replay_runner_rejects_ruleset_mismatch(failures)
	_test_find_latest_replay_path(failures)
	_test_starter_duel_hand_response_replay_round_trip(failures)
	_test_starter_duel_play_option_replay_round_trip(failures)
	_test_starter_duel_artifact_replay_round_trip(failures)
	_test_repo_starter_replay_example_file(failures)
	_test_repo_starter_play_option_replay_example_file(failures)
	_test_repo_starter_hand_response_replay_example_file(failures)

	return failures

static func _test_hash_mismatch_detection(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 654)
	var p0_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_card,
		"row": "front",
		"col": 0
	})).ok, "hash mismatch setup play should succeed", failures)
	var replay_data = engine.export_replay_data(state)
	var commands = replay_data.get("commands", [])
	if commands.is_empty():
		failures.append("hash mismatch test requires at least one replay command")
		return
	var command_row = commands[0].duplicate(true)
	command_row["state_hash_after"] = "bad_hash"
	replay_data["commands"] = [command_row]
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_data(replay_data)
	_expect(not replay_result.ok, "tampered hash replay should fail", failures)
	_expect(str(replay_result.get("code", "")) == "REPLAY_HASH_MISMATCH_AFTER", "tampered hash replay should report after-hash mismatch", failures)

static func _test_invalid_replay_schema_detection(failures: Array[String]) -> void:
	var invalid_replay = {
		"version": 1,
		"ruleset_id": "dev_ruleset",
		"seed": 777,
		"initial_decks": [["dev_legion_alpha"], ["dev_legion_beta"]],
		"commands": [
			{
				"player_id": 0,
				"type": "PlayCard",
				"payload": []
			}
		]
	}
	var replay_path = _runtime_replay_path("unit_test_invalid_replay.json")
	var absolute_path = ProjectSettings.globalize_path(replay_path)
	var dir_result = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	_expect(dir_result == OK, "invalid replay test should create replay directory", failures)
	if dir_result != OK:
		return
	var file = FileAccess.open(absolute_path, FileAccess.WRITE)
	_expect(file != null, "invalid replay test should open replay file for write", failures)
	if file == null:
		return
	file.store_string(JSON.stringify(invalid_replay, "\t"))
	file.close()
	var load_result = ReplayIO.load_replay_data(replay_path)
	_expect(not load_result.ok, "invalid replay schema should fail during load", failures)
	_expect(str(load_result.get("code", "")) == "INVALID_REPLAY_SCHEMA", "invalid replay load should report schema error", failures)
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_data(invalid_replay)
	_expect(not replay_result.ok, "invalid replay schema should fail during run", failures)
	_expect(str(replay_result.get("code", "")) == "INVALID_REPLAY_SCHEMA", "invalid replay run should report schema error", failures)

static func _test_save_rejects_invalid_replay_schema(failures: Array[String]) -> void:
	var save_result = ReplayIO.save_replay_data({
		"version": 1,
		"ruleset_id": "dev_ruleset",
		"seed": 1,
		"initial_decks": {},
		"commands": []
	}, _runtime_replay_path("unit_test_invalid_save.json"))
	_expect(not save_result.ok, "saving invalid replay schema should fail", failures)
	_expect(str(save_result.get("code", "")) == "INVALID_REPLAY_SCHEMA", "saving invalid replay should report schema error", failures)

static func _test_replay_runner_rejects_missing_card_data(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 888)
	var replay_data = engine.export_replay_data(state)
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_data(replay_data, "res://data/cards/not_found")
	_expect(not replay_result.ok, "replay runner should fail when card data path cannot be loaded", failures)
	_expect(str(replay_result.get("code", "")) == "CARD_DATA_LOAD_FAILED", "missing replay card data should report explicit load failure", failures)

static func _test_replay_runner_rejects_ruleset_mismatch(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 889)
	var replay_data = engine.export_replay_data(state)
	replay_data["ruleset_id"] = "legacy_ruleset"
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_data(replay_data)
	_expect(not replay_result.ok, "replay runner should fail when replay ruleset mismatches engine ruleset", failures)
	_expect(str(replay_result.get("code", "")) == "REPLAY_RULESET_MISMATCH", "ruleset mismatch should report explicit code", failures)

static func _test_find_latest_replay_path(failures: Array[String]) -> void:
	var replay_dir = _runtime_replay_dir("test_latest")
	var absolute_dir = ProjectSettings.globalize_path(replay_dir)
	var dir_result = DirAccess.make_dir_recursive_absolute(absolute_dir)
	_expect(dir_result == OK, "latest replay test should create replay directory", failures)
	if dir_result != OK:
		return
	var older_file = FileAccess.open("%s/replay_001.json" % absolute_dir, FileAccess.WRITE)
	_expect(older_file != null, "latest replay test should open older replay file", failures)
	if older_file == null:
		return
	older_file.store_string("{}")
	older_file.close()
	var newer_file = FileAccess.open("%s/replay_999.json" % absolute_dir, FileAccess.WRITE)
	_expect(newer_file != null, "latest replay test should open newer replay file", failures)
	if newer_file == null:
		return
	newer_file.store_string("{}")
	newer_file.close()
	var latest_path = ReplayIO.find_latest_replay_path(replay_dir)
	_expect(latest_path == "%s/replay_999.json" % replay_dir, "latest replay helper should return lexicographically newest replay file", failures)

static func _test_starter_duel_hand_response_replay_round_trip(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _starter_replay_decks(), 1327)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "starter replay test should add morale for player 1 deployment", failures)
	var defender_card_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	_expect(defender_card_id != "", "starter replay test should draw a defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": defender_card_id,
		"row": "front",
		"col": 0
	})).ok, "starter replay defender should be playable", failures)
	var defender_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(defender_instance_id != "", "starter replay defender should reach battlefield", failures)
	_advance_to_next_main(engine, state, failures, "starter replay should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("starter replay did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "starter replay test should add morale for player 2 attacker", failures)
	var attacker_card_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0404")
	_expect(attacker_card_id != "", "starter replay test should draw attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "starter replay attacker should be playable", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(attacker_instance_id != "", "starter replay attacker should reach battlefield", failures)
	_drain_stack_and_choices(engine, state, failures, "starter replay attacker entry trigger should resolve before declaring the attack")
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	})).ok, "starter replay attack should open pending attack window", failures)
	_expect(not state.pending_attack.is_empty(), "starter replay should create pending attack", failures)
	var hand_response_card_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0002")
	_expect(hand_response_card_id != "", "starter replay test should keep a mercenary in hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hand_response_card_id,
		"row": "hand_response",
		"col": -1,
		"effect_id": "mercenary_hand_guard"
	})).ok, "starter replay hand response should be playable", failures)
	_expect(state.pending_attack.is_empty(), "starter replay hand response should clear pending attack", failures)
	var replay_data = engine.export_replay_data(state)
	var replay_path = _runtime_replay_path("unit_test_starter_hand_response.json")
	var save_result = ReplayIO.save_replay_data(replay_data, replay_path)
	_expect(save_result.ok, "starter replay file should save", failures)
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_file(replay_path)
	_expect(replay_result.ok, "starter replay runner should succeed", failures)
	if replay_result.ok:
		_expect(replay_result.state.pending_attack.is_empty(), "starter replay state should finish without pending attack", failures)
		_expect(replay_result.state.players[0].battle_front[0].occupant != "", "starter replay defender should survive after replay", failures)
		_expect(replay_result.state.players[1].battle_front[0].occupant != "", "starter replay attacker should remain after replayed counter", failures)
		_expect(replay_result.state.command_log.size() == state.command_log.size(), "starter replay command count should match original execution", failures)
		_expect(_has_event_type(replay_result.state, "AttackCountered"), "starter replay should preserve AttackCountered event", failures)
		_expect(_has_event_type(replay_result.state, "HandResponsePlayed"), "starter replay should preserve HandResponsePlayed event", failures)

static func _test_starter_duel_play_option_replay_round_trip(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _starter_play_option_replay_decks(), 1328)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "starter play option replay should add five morale", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 0,
		"hp": 8
	})).ok, "starter play option replay should set master hp to 8", failures)
	var ragnar_card_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0303")
	_expect(ragnar_card_id != "", "starter play option replay should draw Ragnar", failures)
	var missing_option_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ragnar_card_id,
		"row": "front",
		"col": 0
	}))
	_expect(not missing_option_result.ok and str(missing_option_result.get("code", "")) == "PLAY_OPTION_REQUIRED", "starter play option replay should require explicit option selection", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ragnar_card_id,
		"row": "front",
		"col": 0,
		"play_option_id": "ragnar_blood_price"
	})).ok, "starter play option replay should play Ragnar with blood price", failures)
	var replay_data = engine.export_replay_data(state)
	var play_option_found = false
	for row in replay_data.get("commands", []):
		if str(row.get("type", "")) != "PlayCard":
			continue
		var payload = row.get("payload", {})
		if str(payload.get("play_option_id", "")) == "ragnar_blood_price":
			play_option_found = true
			break
	_expect(play_option_found, "starter play option replay should export play_option_id in replay payload", failures)
	var replay_path = _runtime_replay_path("unit_test_starter_play_option.json")
	var save_result = ReplayIO.save_replay_data(replay_data, replay_path)
	_expect(save_result.ok, "starter play option replay file should save", failures)
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_file(replay_path)
	_expect(replay_result.ok, "starter play option replay runner should succeed", failures)
	if replay_result.ok:
		_expect(replay_result.state.players[0].master_hp == 7, "starter play option replay should preserve self-damage from blood price", failures)
		_expect(replay_result.state.players[0].battle_front[0].occupant != "", "starter play option replay should leave Ragnar on battlefield", failures)
		_expect(replay_result.state.command_log.size() == state.command_log.size(), "starter play option replay command count should match original execution", failures)
		_expect(_has_event_type(replay_result.state, "MasterDamaged"), "starter play option replay should preserve MasterDamaged event", failures)

static func _test_starter_duel_artifact_replay_round_trip(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _starter_artifact_replay_decks(), 1329)
	_advance_to_next_main(engine, state, failures, "starter artifact replay should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("starter artifact replay did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "starter artifact replay should add morale for enemy target", failures)
	var destroy_target_card_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0416")
	_expect(destroy_target_card_id != "", "starter artifact replay should draw low-cost destroy target", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": destroy_target_card_id,
		"row": "front",
		"col": 0
	})).ok, "starter artifact replay destroy target should be playable", failures)
	_advance_to_next_main(engine, state, failures, "starter artifact replay should advance back to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("starter artifact replay did not return to player 1 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "starter artifact replay should add morale for ally and artifact plays", failures)
	var ally_card_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0416")
	var kusanagi_card_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	_expect(ally_card_id != "" and kusanagi_card_id != "", "starter artifact replay should draw ally legion and 草薙剑", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": ally_card_id,
		"row": "front",
		"col": 0
	})).ok, "starter artifact replay ally should be playable", failures)
	var ally_instance_id = state.get_player(0).battle_front[0].occupant
	_drain_stack_and_choices(engine, state, failures, "starter artifact replay ally entry trigger should resolve before 草薙剑 enters")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": kusanagi_card_id,
		"row": "artifact",
		"col": -1
	})).ok, "starter artifact replay should play 草薙剑 to artifact zone", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "starter artifact replay enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "starter artifact replay enter trigger second pass should resolve", failures)
	_expect(state.get_player(1).battle_front[0].occupant == "", "starter artifact replay enter trigger should destroy the only enemy target", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": kusanagi_card_id,
		"effect_id": "kusanagi_assault",
		"target_card_id": ally_instance_id
	})).ok, "starter artifact replay should activate 草薙剑 assault", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "starter artifact replay assault first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "starter artifact replay assault second pass should resolve", failures)
	var ally_instance = state.card_instances.get(ally_instance_id)
	_expect(ally_instance != null and int(ally_instance.flags.get("master_damage_bonus_amount", 0)) == 1, "starter artifact replay should grant ally assault bonus before export", failures)
	var replay_data = engine.export_replay_data(state)
	var replay_path = _runtime_replay_path("unit_test_starter_artifact.json")
	var save_result = ReplayIO.save_replay_data(replay_data, replay_path)
	_expect(save_result.ok, "starter artifact replay file should save", failures)
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_file(replay_path)
	_expect(replay_result.ok, "starter artifact replay runner should succeed", failures)
	if replay_result.ok:
		_expect(replay_result.state.players[0].artifact_zone.cards.size() == 1, "starter artifact replay should preserve artifact zone state", failures)
		_expect(replay_result.state.players[1].battle_front[0].occupant == "", "starter artifact replay should preserve enter-destroy result", failures)
		var replayed_ally_instance = replay_result.state.card_instances.get(ally_instance_id)
		_expect(replayed_ally_instance != null and int(replayed_ally_instance.flags.get("master_damage_bonus_amount", 0)) == 1, "starter artifact replay should preserve 草薙剑 assault buff", failures)
		_expect(replay_result.state.command_log.size() == state.command_log.size(), "starter artifact replay command count should match original execution", failures)
		_expect(_has_event_type(replay_result.state, "CardCostModified") or _has_event_type(replay_result.state, "CardBuffApplied"), "starter artifact replay should preserve artifact follow-up events", failures)

static func _test_repo_starter_replay_example_file(failures: Array[String]) -> void:
	var replay_path = "res://data/replays/starter_duel_artifact_example.json"
	var load_result = ReplayIO.load_replay_data(replay_path)
	_expect(load_result.ok, "repo starter replay example should load", failures)
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_file(replay_path)
	_expect(replay_result.ok, "repo starter replay example should validate successfully", failures)
	if replay_result.ok:
		_expect(replay_result.state.players[0].artifact_zone.cards.size() == 1, "repo starter replay example should leave exactly one artifact in artifact zone", failures)
		_expect(replay_result.state.players[1].battle_front[0].occupant == "", "repo starter replay example should preserve enter-destroy result", failures)
		_expect(_has_event_type(replay_result.state, "CardBuffApplied"), "repo starter replay example should preserve artifact buff events", failures)

static func _test_repo_starter_play_option_replay_example_file(failures: Array[String]) -> void:
	var replay_path = "res://data/replays/starter_duel_play_option_example.json"
	var load_result = ReplayIO.load_replay_data(replay_path)
	_expect(load_result.ok, "repo starter play option replay example should load", failures)
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_file(replay_path)
	_expect(replay_result.ok, "repo starter play option replay example should validate successfully", failures)
	if replay_result.ok:
		_expect(replay_result.state.players[0].master_hp == 7, "repo starter play option replay example should preserve blood price self-damage", failures)
		_expect(replay_result.state.players[0].battle_front[0].occupant == "c_0001", "repo starter play option replay example should leave Ragnar in front row", failures)
		_expect(_has_event_type(replay_result.state, "MasterDamaged"), "repo starter play option replay example should preserve self-damage event", failures)

static func _test_repo_starter_hand_response_replay_example_file(failures: Array[String]) -> void:
	var replay_path = "res://data/replays/starter_duel_hand_response_example.json"
	var load_result = ReplayIO.load_replay_data(replay_path)
	_expect(load_result.ok, "repo starter hand response replay example should load", failures)
	var runner = ReplayRunner.new()
	var replay_result = runner.run_replay_file(replay_path)
	_expect(replay_result.ok, "repo starter hand response replay example should validate successfully", failures)
	if replay_result.ok:
		_expect(replay_result.state.pending_attack.is_empty(), "repo starter hand response replay example should finish without pending attack", failures)
		_expect(replay_result.state.players[0].battle_front[0].occupant == "c_0001", "repo starter hand response replay example should preserve the defending frontliner", failures)
		_expect(replay_result.state.players[1].battle_front[0].occupant == "c_0015", "repo starter hand response replay example should preserve the attacking frontliner", failures)
		_expect(_has_event_type(replay_result.state, "AttackCountered"), "repo starter hand response replay example should preserve AttackCountered event", failures)
		_expect(_has_event_type(replay_result.state, "HandResponsePlayed"), "repo starter hand response replay example should preserve HandResponsePlayed event", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _starter_replay_decks() -> Array:
	return [
		["asgard_s01_0312", "neutral_s01_0002", "neutral_s01_0015", "neutral_s01_0016", "takamagahara_s01_0419", "takamagahara_s01_0417"],
		["takamagahara_s01_0404", "neutral_s01_0015", "neutral_s01_0016", "asgard_s01_0318", "asgard_s01_0306", "asgard_s01_0312"]
	]

static func _starter_play_option_replay_decks() -> Array:
	return [
		["asgard_s01_0303", "neutral_s01_0015", "neutral_s01_0016", "asgard_s01_0312", "asgard_s01_0306", "neutral_s01_0001"],
		["neutral_s01_0015", "neutral_s01_0016", "asgard_s01_0318", "asgard_s01_0306", "asgard_s01_0312", "neutral_s01_0002"]
	]

static func _starter_artifact_replay_decks() -> Array:
	return [
		["takamagahara_s01_0417", "takamagahara_s01_0416", "neutral_s01_0015", "neutral_s01_0016", "takamagahara_s01_0418", "takamagahara_s01_0409"],
		["takamagahara_s01_0416", "neutral_s01_0015", "neutral_s01_0016", "asgard_s01_0318", "asgard_s01_0303", "asgard_s01_0312"]
	]

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		if not state.pending_choices.is_empty() or not state.stack.is_empty() or not state.pending_attack.is_empty():
			_drain_stack_and_choices(engine, state, failures, message)
			if state.winner != -1:
				return
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)

static func _drain_stack_and_choices(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(16):
		if state.pending_choices.is_empty() and state.stack.is_empty() and state.pending_attack.is_empty():
			return
		if not state.pending_choices.is_empty():
			var choice = state.pending_choices[0]
			var payload = {"choice_id": str(choice.get("choice_id", ""))}
			match str(choice.get("type", "")):
				"candidate_cards_pick":
					var selected: Array[String] = []
					var candidates = choice.get("candidate_card_ids", [])
					var count = int(choice.get("count", 1))
					for raw_card_id in candidates:
						selected.append(str(raw_card_id))
						if selected.size() == count:
							break
					payload["selected_card_ids"] = selected
				"option_pick":
					var options = choice.get("options", [])
					if options is Array and not options.is_empty():
						payload["selected_option"] = str(options[0].get("id", ""))
			_expect(engine.apply_command(state, GameCommand.create(int(choice.get("player_id", -1)), "ResolveChoice", payload)).ok, message, failures)
			continue
		_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, message, failures)
	failures.append(message)

static func _runtime_replay_dir(name: String = "") -> String:
	if name.is_empty():
		return "res://tmp_replays"
	return "res://tmp_replays/%s" % name

static func _runtime_replay_path(file_name: String) -> String:
	return "%s/%s" % [_runtime_replay_dir(), file_name]

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
