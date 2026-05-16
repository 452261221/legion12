extends RefCounted
class_name TestTurnStateMachine

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const PhaseMachine = preload("res://rules/core/phase_machine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_phase_machine_order(failures)
	_test_turn_flow_smoke_over_several_rounds(failures)
	return failures

static func _test_phase_machine_order(failures: Array[String]) -> void:
	_expect(PhaseMachine.next_phase("calamity") == "ready", "phase machine should advance calamity -> ready", failures)
	_expect(PhaseMachine.next_phase("ready") == "draw", "phase machine should advance ready -> draw", failures)
	_expect(PhaseMachine.next_phase("draw") == "morale", "phase machine should advance draw -> morale", failures)
	_expect(PhaseMachine.next_phase("morale") == "main", "phase machine should advance morale -> main", failures)
	_expect(PhaseMachine.next_phase("main") == "end", "phase machine should advance main -> end", failures)
	_expect(PhaseMachine.next_phase("end") == "calamity", "phase machine should advance end -> calamity", failures)
	_expect(PhaseMachine.can_use_command("PlayCard", "main"), "phase machine should allow PlayCard during main", failures)
	_expect(not PhaseMachine.can_use_command("PlayCard", "draw"), "phase machine should forbid PlayCard during draw", failures)
	_expect(PhaseMachine.can_use_command("EndPhase", "main"), "phase machine should allow EndPhase during main", failures)

static func _test_turn_flow_smoke_over_several_rounds(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _smoke_decks(), 4001, [], _formal_options(3))
	var expected_active_player = state.active_player
	var previous_turn = state.turn_number
	for main_index in range(6):
		_expect(str(state.phase) == "main", "turn smoke test should always enter a main phase before acting", failures)
		_expect(state.active_player == expected_active_player, "turn smoke test should alternate the active player each main phase", failures)
		_play_first_hand_legion_if_possible(engine, state, failures, "turn smoke test should allow a normal legion play")
		_declare_first_available_attack_if_possible(engine, state, failures, "turn smoke test should allow old legions to attack when targets exist")
		_drain_until_idle(engine, state, failures, "turn smoke test should resolve the stack, pending attacks, and choices without getting stuck")
		if main_index == 5 or state.winner != -1:
			break
		_advance_to_next_main(engine, state, failures, "turn smoke test should advance to the next player's main phase")
		_expect(state.turn_number == previous_turn + 1, "turn smoke test should increment the turn number when passing to the next main", failures)
		previous_turn = state.turn_number
		expected_active_player = 1 - expected_active_player
	_expect(state.winner == -1, "turn smoke test should not unexpectedly finish the game during the smoke sequence", failures)
	_expect(state.pending_choices.is_empty(), "turn smoke test should finish with no pending choices", failures)
	_expect(state.stack.is_empty(), "turn smoke test should finish with an empty stack", failures)
	_expect(state.pending_attack.is_empty(), "turn smoke test should finish with no pending attack", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _formal_options(opening_hand_size: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": 10,
		"opening_non_active_player_morale": 10
	}

static func _smoke_decks() -> Array:
	return [
		["qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"],
		["qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _play_first_hand_legion_if_possible(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	var player_id = state.active_player
	var card_id = _find_hand_legion(state, player_id)
	if card_id.is_empty():
		return
	var slot = _first_open_battle_slot(state, player_id)
	if slot.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(player_id, "PlayCard", {
		"card_id": card_id,
		"row": str(slot.get("row", "front")),
		"col": int(slot.get("col", 0))
	})).ok, message, failures)

static func _declare_first_available_attack_if_possible(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	var player_id = state.active_player
	var attacker_id = _find_ready_attacker(state, player_id)
	var defender_id = _first_battlefield_card_id(state, 1 - player_id)
	if attacker_id.is_empty() or defender_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(player_id, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id
	})).ok, message, failures)

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		if not state.pending_choices.is_empty() or not state.stack.is_empty() or not state.pending_attack.is_empty():
			_drain_until_idle(engine, state, failures, message)
			if state.winner != -1:
				return
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)

static func _drain_until_idle(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(24):
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
	if not state.pending_choices.is_empty() or not state.stack.is_empty() or not state.pending_attack.is_empty():
		failures.append(message)

static func _find_hand_legion(state, player_id: int) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(str(card_id))
		var definition = state.get_definition(str(instance.definition_id)) if instance != null else null
		if definition != null and str(definition.type) == "legion":
			return str(card_id)
	return ""

static func _first_open_battle_slot(state, player_id: int) -> Dictionary:
	for row_name in ["front", "back"]:
		var row = state.get_player(player_id).battle_front if row_name == "front" else state.get_player(player_id).battle_back
		for index in range(row.size()):
			if str(row[index].occupant).is_empty():
				return {"row": row_name, "col": index}
	return {}

static func _find_ready_attacker(state, player_id: int) -> String:
	for row_name in ["front", "back"]:
		var row = state.get_player(player_id).battle_front if row_name == "front" else state.get_player(player_id).battle_back
		for slot in row:
			var card_id = str(slot.occupant)
			if card_id.is_empty():
				continue
			var instance = state.card_instances.get(card_id)
			if instance == null:
				continue
			if str(instance.orientation) != "active":
				continue
			if int(instance.entered_turn) == state.turn_number:
				continue
			if bool(instance.has_attacked_this_turn):
				continue
			return card_id
	return ""

static func _first_battlefield_card_id(state, player_id: int) -> String:
	for row_name in ["front", "back"]:
		var row = state.get_player(player_id).battle_front if row_name == "front" else state.get_player(player_id).battle_back
		for slot in row:
			var card_id = str(slot.occupant)
			if not card_id.is_empty():
				return card_id
	return ""

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
