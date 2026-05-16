extends RefCounted
class_name TestCandidateSimulator

const CandidateSimulator = preload("res://ai/scripted/candidate_simulator.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_board_deploy_breakdown(failures)
	_test_tactic_cast_breakdown(failures)
	_test_move_legion_followup_attack_breakdown(failures)
	_test_declare_attack_followup_pressure_breakdown(failures)
	_test_declare_attack_coordinated_clear_breakdown(failures)
	return failures

static func _test_board_deploy_breakdown(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(definitions, [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 1601)
	var simulator := CandidateSimulator.new()
	var card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not card_id.is_empty(), "candidate simulator: board deploy test should draw dev_legion_alpha", failures)
	if card_id.is_empty():
		return
	var simulation: Dictionary = simulator.simulate_candidate(engine, state, 0, {
		"command_type": "PlayCard",
		"payload": {
			"card_id": card_id,
			"row": "front",
			"col": 0
		}
	})
	_expect(bool(simulation.get("ok", false)), "candidate simulator: board deploy simulation should succeed", failures)
	var breakdown: Dictionary = simulation.get("breakdown", {})
	_expect(int(breakdown.get("self_front_gain", 0)) == 1, "candidate simulator: board deploy should record self_front_gain", failures)
	_expect(int(breakdown.get("self_board_gain", 0)) == 1, "candidate simulator: board deploy should record self_board_gain", failures)
	_expect(int(breakdown.get("self_hand_delta", 0)) == -1, "candidate simulator: board deploy should record hand spend", failures)
	_expect(bool(breakdown.get("keeps_own_action_window", false)), "candidate simulator: board deploy should keep own action window", failures)
	_expect(str(simulation.get("summary", "")).find("self_front+1") != -1, "candidate simulator: board deploy summary should mention frontline gain", failures)

static func _test_tactic_cast_breakdown(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(definitions, [
		["dev_tactic_bolt", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 1602)
	_advance_to_player_main(engine, state, 1, failures, "candidate simulator: tactic test should reach player 2 main")
	var target_hand_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not target_hand_id.is_empty(), "candidate simulator: tactic test should draw dev_legion_beta", failures)
	if target_hand_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_hand_id,
		"row": "front",
		"col": 0
	})).ok, "candidate simulator: tactic test should deploy the enemy target", failures)
	var target_instance_id: String = state.get_player(1).battle_front[0].occupant
	_advance_to_player_main(engine, state, 0, failures, "candidate simulator: tactic test should return to player 1 main")
	var bolt_id := _find_hand_card_by_definition(state, 0, "dev_tactic_bolt")
	_expect(not bolt_id.is_empty(), "candidate simulator: tactic test should draw dev_tactic_bolt", failures)
	if bolt_id.is_empty():
		return
	var simulator := CandidateSimulator.new()
	var simulation: Dictionary = simulator.simulate_candidate(engine, state, 0, {
		"command_type": "PlayCard",
		"payload": {
			"card_id": bolt_id,
			"row": "tactic",
			"col": -1,
			"target_card_id": target_instance_id
		}
	})
	_expect(bool(simulation.get("ok", false)), "candidate simulator: tactic cast simulation should succeed", failures)
	var breakdown: Dictionary = simulation.get("breakdown", {})
	_expect(int(breakdown.get("self_hand_delta", 0)) == -1, "candidate simulator: tactic cast should record the spent hand card", failures)
	_expect(bool(breakdown.get("gives_enemy_priority_window", false)), "candidate simulator: unresolved tactic stack should give enemy priority window", failures)
	_expect(int(breakdown.get("stack_size_after", 0)) >= 1, "candidate simulator: tactic cast should leave a stack item pending after one-step simulation", failures)
	_expect(str(simulation.get("summary", "")).find("gives_enemy_priority_window") != -1, "candidate simulator: tactic cast summary should mention the enemy priority window", failures)

static func _test_move_legion_followup_attack_breakdown(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(definitions, [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 1603, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 2,
		"turn_start_draw_count": 0
	})
	var mover_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not mover_card_id.is_empty(), "candidate simulator: move follow-up test should draw dev_legion_alpha", failures)
	if mover_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mover_card_id,
		"row": "back",
		"col": 1
	})).ok, "candidate simulator: move follow-up test should deploy the mover to the back row", failures)
	_advance_to_player_main(engine, state, 1, failures, "candidate simulator: move follow-up test should reach player 2 main")
	var enemy_card_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not enemy_card_id.is_empty(), "candidate simulator: move follow-up test should draw dev_legion_beta", failures)
	if enemy_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_card_id,
		"row": "front",
		"col": 0
	})).ok, "candidate simulator: move follow-up test should deploy the enemy frontliner", failures)
	_advance_to_player_main(engine, state, 0, failures, "candidate simulator: move follow-up test should return to player 1 main")
	var mover_instance_id := str(state.get_player(0).battle_back[1].occupant)
	_expect(not mover_instance_id.is_empty(), "candidate simulator: move follow-up test should keep the mover on the back row before moving", failures)
	if mover_instance_id.is_empty():
		return
	var simulator := CandidateSimulator.new()
	var simulation: Dictionary = simulator.simulate_candidate(engine, state, 0, {
		"kind": "move_legion",
		"command_type": "MoveLegion",
		"payload": {
			"card_id": mover_instance_id,
			"row": "front",
			"col": 1
		}
	})
	_expect(bool(simulation.get("ok", false)), "candidate simulator: move follow-up simulation should succeed", failures)
	var breakdown: Dictionary = simulation.get("breakdown", {})
	_expect(bool(breakdown.get("followup_attack_found", false)), "candidate simulator: move follow-up should detect a legal attack after moving", failures)
	_expect(float(breakdown.get("followup_attack_score", 0.0)) > 0.0, "candidate simulator: move follow-up should assign positive follow-up attack score", failures)
	_expect(str(breakdown.get("followup_attack_target_kind", "")) == "master", "candidate simulator: move follow-up should prefer the newly unlocked master attack", failures)
	_expect(str(simulation.get("summary", "")).find("move_followup_attack_master") != -1, "candidate simulator: move follow-up summary should mention the master-attack follow-up", failures)

static func _test_declare_attack_followup_pressure_breakdown(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(definitions, [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 1604, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_active_player_morale": 2,
		"turn_start_draw_count": 0
	})
	var first_attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not first_attacker_card_id.is_empty(), "candidate simulator: attack follow-up test should draw the first attacker", failures)
	if first_attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "candidate simulator: attack follow-up test should deploy the first attacker", failures)
	var second_attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not second_attacker_card_id.is_empty(), "candidate simulator: attack follow-up test should draw the second attacker", failures)
	if second_attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_attacker_card_id,
		"row": "front",
		"col": 1
	})).ok, "candidate simulator: attack follow-up test should deploy the second attacker", failures)
	_advance_to_player_main(engine, state, 1, failures, "candidate simulator: attack follow-up test should reach player 2 main")
	var enemy_card_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not enemy_card_id.is_empty(), "candidate simulator: attack follow-up test should draw the enemy frontliner", failures)
	if enemy_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_card_id,
		"row": "front",
		"col": 0
	})).ok, "candidate simulator: attack follow-up test should deploy the enemy frontliner", failures)
	_advance_to_player_main(engine, state, 0, failures, "candidate simulator: attack follow-up test should return to player 1 main")
	var attacker_instance_id := str(state.get_player(0).battle_front[0].occupant)
	var defender_instance_id := str(state.get_player(1).battle_front[0].occupant)
	_expect(not attacker_instance_id.is_empty() and not defender_instance_id.is_empty(), "candidate simulator: attack follow-up test should keep both units on board", failures)
	if attacker_instance_id.is_empty() or defender_instance_id.is_empty():
		return
	var attack_check := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id,
		"target_kind": "card"
	}))
	_expect(bool(attack_check.get("ok", false)), "candidate simulator: attack follow-up test should have a legal attack", failures)
	var simulator := CandidateSimulator.new()
	var simulation: Dictionary = simulator.simulate_candidate(engine, state, 0, {
		"kind": "declare_attack",
		"command_type": "DeclareAttack",
		"payload": {
			"attacker_id": attacker_instance_id,
			"defender_id": defender_instance_id,
			"target_kind": "card"
		}
	})
	_expect(bool(simulation.get("ok", false)), "candidate simulator: attack follow-up pressure simulation should succeed", failures)
	var breakdown: Dictionary = simulation.get("breakdown", {})
	_expect(bool(breakdown.get("attack_followup_pressure_found", false)), "candidate simulator: clearing the last frontliner should expose follow-up pressure", failures)
	_expect(int(breakdown.get("attack_followup_projected_master_damage", 0)) >= 2, "candidate simulator: clearing the last frontliner should project multi-lane master pressure", failures)
	_expect(str(simulation.get("summary", "")).find("attack_followup_master_pressure") != -1, "candidate simulator: attack follow-up pressure summary should mention master pressure", failures)

static func _test_declare_attack_coordinated_clear_breakdown(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(definitions, [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_plain", "asgard_s01_0307", "qa_plain", "asgard_s01_0307", "qa_plain", "asgard_s01_0307"]
	], 1605)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "candidate simulator: coordinated-clear test should add morale for player 1", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 5
	})).ok, "candidate simulator: coordinated-clear test should add morale for player 2", failures)
	var first_attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not first_attacker_card_id.is_empty(), "candidate simulator: coordinated-clear test should draw the first attacker", failures)
	if first_attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "candidate simulator: coordinated-clear test should deploy the first attacker", failures)
	var second_attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not second_attacker_card_id.is_empty(), "candidate simulator: coordinated-clear test should draw the second attacker", failures)
	if second_attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_attacker_card_id,
		"row": "front",
		"col": 1
	})).ok, "candidate simulator: coordinated-clear test should deploy the second attacker", failures)
	_advance_to_player_main(engine, state, 1, failures, "candidate simulator: coordinated-clear test should reach player 2 main")
	var small_defender_card_id := _find_hand_card_by_definition(state, 1, "qa_plain")
	var big_defender_card_id := _find_hand_card_by_definition(state, 1, "asgard_s01_0307")
	_expect(not small_defender_card_id.is_empty() and not big_defender_card_id.is_empty(), "candidate simulator: coordinated-clear test should draw both defenders", failures)
	if small_defender_card_id.is_empty() or big_defender_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": small_defender_card_id,
		"row": "front",
		"col": 0
	})).ok, "candidate simulator: coordinated-clear test should deploy the small defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": big_defender_card_id,
		"row": "front",
		"col": 1
	})).ok, "candidate simulator: coordinated-clear test should deploy the big defender", failures)
	_advance_to_player_main(engine, state, 0, failures, "candidate simulator: coordinated-clear test should return to player 1 main")
	var attacker_instance_id := str(state.get_player(0).battle_front[0].occupant)
	var big_defender_instance_id := str(state.get_player(1).battle_front[1].occupant)
	_expect(not attacker_instance_id.is_empty() and not big_defender_instance_id.is_empty(), "candidate simulator: coordinated-clear test should keep attacker and big defender on board", failures)
	if attacker_instance_id.is_empty() or big_defender_instance_id.is_empty():
		return
	var attack_check := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": big_defender_instance_id,
		"target_kind": "card"
	}))
	_expect(bool(attack_check.get("ok", false)), "candidate simulator: coordinated-clear test should have a legal big-target attack", failures)
	var simulator := CandidateSimulator.new()
	var simulation: Dictionary = simulator.simulate_candidate(engine, state, 0, {
		"kind": "declare_attack",
		"command_type": "DeclareAttack",
		"payload": {
			"attacker_id": attacker_instance_id,
			"defender_id": big_defender_instance_id,
			"target_kind": "card"
		}
	})
	_expect(bool(simulation.get("ok", false)), "candidate simulator: coordinated-clear simulation should succeed", failures)
	var breakdown: Dictionary = simulation.get("breakdown", {})
	_expect(bool(breakdown.get("coordinated_clear_found", false)), "candidate simulator: coordinated-clear attack should expose multi-attacker clear follow-up", failures)
	_expect(float(breakdown.get("coordinated_clear_score", 0.0)) > 0.0, "candidate simulator: coordinated-clear attack should assign positive setup score", failures)
	_expect(int(breakdown.get("coordinated_clear_remaining_power", 0)) == 0, "candidate simulator: coordinated-clear attack should project a full clear with available support", failures)
	_expect(str(simulation.get("summary", "")).find("attack_sets_up_coordinated_clear") != -1, "candidate simulator: coordinated-clear summary should mention the coordinated clear line", failures)

static func _advance_to_player_main(engine: GameEngine, state, player_id: int, failures: Array[String], message: String) -> void:
	for _i in range(16):
		if state.phase == "main" and state.active_player == player_id:
			return
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase", {})).ok, message, failures)
	failures.append(message)

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
