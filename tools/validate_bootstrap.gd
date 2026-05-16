extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var engine = GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		99
	)
	_expect(state.players[0].hand.cards.size() == 5, "player 1 should draw 5", failures)
	_expect(state.players[1].hand.cards.size() == 5, "player 2 should draw 5", failures)
	_expect(state.players[0].cost_area.cards.size() == 3, "player 1 should start with 3 morale", failures)
	_expect(state.players[1].cost_area.cards.size() == 3, "player 2 should start with 3 morale", failures)
	_expect(engine.build_status_snapshot(state, 0).can_play_card, "active player should be allowed to play card in main phase", failures)
	var p0_card = state.players[0].hand.cards[0]
	var legal_play_slots = engine.get_legal_play_slots(state, 0, p0_card)
	_expect(legal_play_slots.size() == 6, "empty battlefield should expose 6 legal play slots", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {"card_id": p0_card, "row": "front", "col": 0})).ok, "player 1 play should succeed", failures)
	_expect(state.players[0].spent_cost_area.cards.size() == 1, "playing a 1-cost card should consume 1 morale", failures)
	var phase_trace: Array[String] = []
	for _i in range(6):
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, "advance to p2 main", failures)
		phase_trace.append(state.phase)
	_expect(phase_trace == ["end", "calamity", "ready", "draw", "morale", "main"], "phase order before returning to main should match document", failures)
	_expect(state.active_player == 1 and state.phase == "main", "turn should pass to player 2 main", failures)
	_expect(not engine.build_status_snapshot(state, 0).can_play_card, "inactive player should not be allowed to play card", failures)
	var p1_card = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {"card_id": p1_card, "row": "front", "col": 0})).ok, "player 2 play should succeed", failures)
	for _i in range(6):
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, "advance back to p1 main", failures)
	_expect(state.active_player == 0 and state.phase == "main", "turn should return to player 1 main", failures)
	_expect(state.players[0].spent_cost_area.cards.is_empty(), "ready phase should return spent morale to active area", failures)
	_expect(state.players[0].cost_area.cards.size() >= 3, "player 1 should have active morale again after ready/morale phases", failures)
	var legal_targets = engine.get_legal_attack_targets(state, state.players[0].battle_front[0].occupant)
	_expect(legal_targets.size() == 1, "occupied lane should expose one legal attack target", failures)
	if legal_targets.size() > 0:
		_expect(legal_targets[0].get("target_kind") == "card", "occupied lane should only allow attacking the enemy card", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {"attacker_id": state.players[0].battle_front[0].occupant, "defender_id": state.players[1].battle_front[0].occupant})).ok, "attack should succeed", failures)
	_resolve_priority_window(engine, state, failures, "combat first pass should succeed", "combat second pass should resolve")
	_expect(state.players[1].grave.cards.size() == 1, "defender should die", failures)
	_expect(state.players[0].battle_front[0].occupant != "", "attacker should survive", failures)
	var second_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {"attacker_id": state.players[0].battle_front[0].occupant, "defender_id": state.players[1].battle_front[0].occupant}))
	_expect(not second_attack.ok, "same attacker should not be able to attack twice in one turn", failures)
	_advance_to_player_next_main(engine, state, 0, failures, "advance to next player 1 main")
	_expect(state.active_player == 0 and state.phase == "main", "should reach player 1 main again", failures)
	var direct_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": state.players[0].battle_front[0].occupant,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(direct_attack.ok, "direct attack to enemy master should succeed when lane is open", failures)
	_resolve_priority_window(engine, state, failures, "direct attack first pass should succeed", "direct attack second pass should resolve")
	_expect(state.players[1].master_hp == 19, "damaged attacker should deal 1 damage to master", failures)
	var debug_finish = engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 0
	}))
	_expect(debug_finish.ok, "debug lethal setup should succeed", failures)
	_expect(state.winner == 0, "player 1 should win after reducing enemy master hp to 0", failures)
	_expect(state.loss_reason == "master_hp_zero", "loss reason should record master hp reaching zero", failures)
	var replay = engine.export_replay_data(state)
	_expect(replay.get("seed") == 99, "replay should include seed", failures)
	_expect(replay.get("winner") == 0, "replay should include winner", failures)
	_expect(replay.get("initial_decks", []).size() == 2, "replay should include initial decks", failures)
	_expect(replay.get("commands", []).size() == state.command_log.size(), "replay command list should mirror command log", failures)
	var finished_result = engine.apply_command(state, GameCommand.create(1, "EndPhase"))
	_expect(not finished_result.ok and finished_result.code == "GAME_ALREADY_FINISHED", "finished game should reject later commands", failures)
	if not failures.is_empty():
		for message in failures:
			push_error(message)
		quit(1)
		return
	print("bootstrap validation passed")
	quit(0)

func _advance_to_player_next_main(engine: GameEngine, state, player_id: int, failures: Array[String], message: String) -> void:
	var advanced = false
	for _i in range(12):
		if advanced and state.active_player == player_id and state.phase == "main":
			return
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		advanced = true
	if state.active_player != player_id or state.phase != "main":
		failures.append(message)

func _resolve_priority_window(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	if state.stack.is_empty() and state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, first_message, failures)
	if state.stack.is_empty() and state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, second_message, failures)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
