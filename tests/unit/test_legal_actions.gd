extends RefCounted
class_name TestLegalActions

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_main_phase_actions_are_standardized(failures)
	_test_formal_move_actions_are_standardized(failures)
	_test_play_option_board_actions_are_flattened(failures)
	_test_priority_actions_surface_only_response_window_commands(failures)
	_test_choice_actions_are_standardized(failures)
	_test_option_pick_choice_actions_expose_options(failures)
	_test_counter_tactic_priority_actions_expose_stack_targets(failures)
	_test_counter_tactic_can_target_pending_attack_window(failures)
	_test_disabled_counter_tactic_is_hidden_from_priority_actions(failures)
	_test_candidate_cards_pick_choice_actions_expose_candidate_cards(failures)
	_test_multi_mode_tactic_actions_are_flattened(failures)
	return failures

static func _test_main_phase_actions_are_standardized(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _core_decks(), 1401)
	var actions = engine.get_legal_actions(state, 0)
	_expect(not actions.is_empty(), "active player should have legal actions in opening main phase", failures)
	_expect(engine.get_legal_actions(state, 1).is_empty(), "inactive player should have no legal actions while waiting for action", failures)
	var play_action = _find_action(actions, "play_card", "board_or_artifact")
	_expect(not play_action.is_empty(), "opening main phase should expose a board play proposal", failures)
	if not play_action.is_empty():
		_expect(_is_standardized_action(play_action), "board play proposal should use the standardized action schema", failures)
		_expect(play_action.has("source") and str(play_action.get("source", {}).get("card_id", "")) != "", "board play proposal should expose source card metadata", failures)
		_expect(play_action.has("targets") and play_action.get("targets", []).size() == 6, "board play proposal should include all legal slot targets", failures)
		_expect(not str(play_action.get("proposal_id", "")).is_empty(), "board play proposal should include a stable proposal_id", failures)
	var end_action = _find_action(actions, "end_phase")
	_expect(not end_action.is_empty(), "opening main phase should expose an end phase proposal", failures)
	if not end_action.is_empty():
		_expect(_is_standardized_action(end_action), "end phase proposal should use the standardized action schema", failures)

static func _test_formal_move_actions_are_standardized(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _formal_core_decks(), 1410, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var legion_id = state.get_player(0).hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": legion_id,
		"row": "front",
		"col": 1
	})).ok, "formal move legal actions test should deploy the opening legion", failures)
	_advance_to_next_main(engine, state, failures, "formal move legal actions test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "formal move legal actions test should advance back to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("formal move legal actions test did not return to player 1 main")
		return
	var legion_instance_id = state.get_player(0).battle_front[1].occupant
	var actions = engine.get_legal_actions(state, 0)
	var move_action := {}
	for action in actions:
		if str(action.get("kind", "")) == "move_legion" and str(action.get("payload_template", {}).get("card_id", "")) == legion_instance_id:
			move_action = action
			break
	_expect(not move_action.is_empty(), "formal main phase should expose a move_legion proposal for an active battlefield legion", failures)
	if not move_action.is_empty():
		_expect(_is_standardized_action(move_action), "move_legion proposal should use the standardized action schema", failures)
		_expect(str(move_action.get("command_type", "")) == "MoveLegion", "move_legion proposal should use the MoveLegion command", failures)
		var targets = move_action.get("targets", [])
		_expect(targets is Array and targets.size() == 3, "move_legion proposal should expose front-back and left-right one-step targets", failures)
		if targets is Array:
			var target_keys: Array[String] = []
			for target in targets:
				target_keys.append("%s:%s" % [str(target.get("row", "")), int(target.get("col", -1))])
			_expect(target_keys.has("back:1"), "move_legion should include the mirrored back-row target", failures)
			_expect(target_keys.has("front:0"), "move_legion should include the left adjacent target", failures)
			_expect(target_keys.has("front:2"), "move_legion should include the right adjacent target", failures)

static func _test_play_option_board_actions_are_flattened(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _play_option_decks(), 1405)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 6
	})).ok, "play option actions test should add six morale", failures)
	var ragnar_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0303")
	_expect(ragnar_id != "", "play option actions test should draw Ragnar", failures)
	var actions = engine.get_legal_actions(state, 0)
	var ragnar_actions = _find_card_actions(actions, ragnar_id, "board_or_artifact")
	_expect(ragnar_actions.size() == 2, "Ragnar should still expose both play options to the client action feed", failures)
	var option_ids: Array[String] = []
	for action in ragnar_actions:
		_expect(_is_standardized_action(action), "Ragnar play option actions should use the standardized action schema", failures)
		option_ids.append(str(action.get("payload_template", {}).get("play_option_id", "")))
		_expect(action.get("targets", []).size() == 6, "each Ragnar play option action should preserve all legal slot targets", failures)
	_expect(option_ids.has("default"), "Ragnar actions should include the default play option", failures)
	_expect(option_ids.has("ragnar_blood_price"), "Ragnar actions should include the blood-price play option", failures)

static func _test_priority_actions_surface_only_response_window_commands(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _hand_response_decks(), 1402)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "priority actions test should add morale for defender deployment", failures)
	var defender_card_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	_expect(defender_card_id != "", "priority actions test should draw a defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": defender_card_id,
		"row": "front",
		"col": 0
	})).ok, "priority actions defender play should succeed", failures)
	var defender_instance_id = state.get_player(0).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "priority actions test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("priority actions test did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "priority actions test should add morale for attacker deployment", failures)
	var attacker_card_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0404")
	_expect(attacker_card_id != "", "priority actions test should draw an attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "priority actions attacker play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "priority actions attacker enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "priority actions attacker enter trigger second pass should resolve", failures)
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	})).ok, "priority actions attack declaration should succeed", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForPriority", "attack declaration should enter priority waiting state", failures)
	_expect(int(waiting.get("player_id", -1)) == 0, "defending player should receive priority during pending attack response", failures)
	var actions = engine.get_legal_actions(state, 0)
	_expect(not actions.is_empty(), "priority player should receive response actions", failures)
	for action in actions:
		_expect(_is_standardized_action(action), "priority response actions should use the standardized action schema", failures)
		_expect(str(action.get("kind", "")) != "end_phase", "priority response actions should not include unrelated end phase commands", failures)
	var pass_action = _find_action(actions, "pass_priority")
	_expect(not pass_action.is_empty(), "priority response actions should include pass priority", failures)
	var defense_action = _find_action(actions, "choose_defense")
	_expect(defense_action.is_empty(), "priority response actions should not expose choose_defense while generic blocker actions remain unsupported", failures)
	if not defense_action.is_empty():
		_expect(str(defense_action.get("command_type", "")) == "ChooseDefense", "defense proposal should use the ChooseDefense command", failures)
	var master_guard_action = _find_action(actions, "choose_defense", "", "master_guard")
	_expect(master_guard_action.is_empty(), "priority response actions should not expose master guard choices when the target is a unit", failures)
	var hand_response_action = _find_action(actions, "play_card", "hand_response")
	_expect(not hand_response_action.is_empty(), "priority response actions should expose playable hand responses", failures)
	if not hand_response_action.is_empty():
		var payload = hand_response_action.get("payload_template", {})
		_expect(str(payload.get("row", "")) == "hand_response", "hand response proposal should prefill the hand_response row", failures)
		_expect(str(payload.get("effect_id", "")) != "", "hand response proposal should prefill effect_id", failures)

static func _test_choice_actions_are_standardized(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _search_choice_decks(), 1403)
	var scout_id = _find_hand_card_by_definition(state, 0, "qa_scout")
	_expect(scout_id != "", "choice actions test should draw qa_scout", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": scout_id,
		"row": "front",
		"col": 0
	})).ok, "choice actions source play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": scout_id,
		"effect_id": "search_legion"
	})).ok, "choice actions effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "choice actions first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "choice actions second pass should resolve to a pending choice", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForChoice", "search choice should stop in waiting-for-choice state", failures)
	var actions = engine.get_legal_actions(state, 0)
	_expect(actions.size() == 1, "waiting-for-choice should expose exactly one choice resolution proposal", failures)
	_expect(engine.get_legal_actions(state, 1).is_empty(), "non-owner should not receive choice actions", failures)
	if actions.size() == 1:
		var action = actions[0]
		_expect(_is_standardized_action(action), "choice proposal should use the standardized action schema", failures)
		_expect(str(action.get("kind", "")) == "resolve_choice", "choice proposal kind should be resolve_choice", failures)
		_expect(action.has("candidate_card_ids") and action.get("candidate_card_ids", []).size() == 2, "choice proposal should expose candidate card ids", failures)
		_expect(str(action.get("payload_template", {}).get("choice_id", "")) != "", "choice proposal should prefill choice_id", failures)

static func _test_option_pick_choice_actions_expose_options(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _option_pick_decks(), 1406)
	var tactic_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0015")
	_expect(tactic_id != "", "option-pick legal actions test should draw 议和谈判", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	})).ok, "option-pick legal actions test should play 议和谈判", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "option-pick legal actions first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "option-pick legal actions second pass should resolve to a choice", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForChoice", "option-pick legal actions should enter waiting-for-choice", failures)
	_expect(int(waiting.get("player_id", -1)) == 1, "option-pick legal actions should wait on the defending player", failures)
	_expect(str(waiting.get("choice_type", "")) == "option_pick", "waiting state should expose option_pick for truce offer", failures)
	var actions = engine.get_legal_actions(state, 1)
	_expect(actions.size() == 1, "option-pick legal actions should expose exactly one resolve-choice action", failures)
	if actions.size() == 1:
		var action = actions[0]
		_expect(_is_standardized_action(action), "option-pick choice proposal should use the standardized action schema", failures)
		_expect(str(action.get("choice_type", "")) == "option_pick", "option-pick proposal should expose the choice type", failures)
		var options = action.get("options", [])
		_expect(options is Array and options.size() == 2, "option-pick proposal should expose both choice options", failures)
		var option_ids: Array[String] = []
		for option in options:
			option_ids.append(str(option.get("id", "")))
		_expect(option_ids.has("agree"), "option-pick proposal should include the agree branch", failures)
		_expect(option_ids.has("decline"), "option-pick proposal should include the decline branch", failures)

static func _test_counter_tactic_priority_actions_expose_stack_targets(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _counter_tactic_decks(), 1407)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 2
	})).ok, "counter-tactic legal actions test should add two morale for the responder", failures)
	var tactic_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0015")
	_expect(tactic_id != "", "counter-tactic legal actions test should draw 议和谈判", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	})).ok, "counter-tactic legal actions test should play the source tactic", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForPriority", "counter-tactic legal actions should enter waiting-for-priority immediately after casting", failures)
	_expect(int(waiting.get("player_id", -1)) == 1, "counter-tactic legal actions should give priority to the opposing player", failures)
	_expect(state.stack.size() == 1, "counter-tactic legal actions test should create one stack item", failures)
	var actions = engine.get_legal_actions(state, 1)
	_expect(not actions.is_empty(), "priority player should receive counter-tactic actions", failures)
	var counter_action = _find_action(actions, "play_card", "counter_tactic")
	_expect(not counter_action.is_empty(), "priority player should see a counter-tactic play action", failures)
	if not counter_action.is_empty():
		var payload = counter_action.get("payload_template", {})
		_expect(str(payload.get("row", "")) == "counter_tactic", "counter-tactic proposal should prefill the counter_tactic row", failures)
		_expect(str(payload.get("effect_id", "")) == "absolute_defense", "counter-tactic proposal should prefill the selected effect id", failures)
		var targets = counter_action.get("targets", [])
		_expect(targets is Array and targets.size() == 1, "counter-tactic proposal should expose the only stack target", failures)
		if targets is Array and targets.size() == 1:
			var target = targets[0]
			_expect(str(target.get("target_kind", "")) == "stack", "counter-tactic proposal target should be a stack target", failures)
			_expect(str(target.get("target_stack_id", "")) == str(state.stack[0].get("stack_id", "")), "counter-tactic proposal should point at the live stack item", failures)

static func _test_counter_tactic_can_target_pending_attack_window(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _hand_response_decks(), 1411)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "pending-attack counter test should add morale for defender deployment", failures)
	var defender_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	_expect(defender_id != "", "pending-attack counter test should draw a defender unit", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": defender_id,
		"row": "front",
		"col": 0
	})).ok, "pending-attack counter test defender play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "pending-attack counter test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("pending-attack counter test did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "pending-attack counter test should add morale for attacker deployment", failures)
	var attacker_id = _find_hand_card_by_definition(state, 1, "takamagahara_s01_0404")
	var counter_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0016")
	_expect(attacker_id != "" and counter_id != "", "pending-attack counter test should draw attacker and 绝对防御", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "pending-attack counter test attacker play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "pending-attack counter test should advance to player 1 main before attacker can act")
	_advance_to_next_main(engine, state, failures, "pending-attack counter test should advance back to player 2 main before attacker can act")
	if state.active_player != 1 or state.phase != "main":
		failures.append("pending-attack counter test did not return to player 2 main for attack")
		return
	var attacker_instance_id = state.get_player(1).battle_front[0].occupant
	var defender_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	})).ok, "pending-attack counter test should declare attack", failures)
	var actions = engine.get_legal_actions(state, 0)
	var counter_action = _find_action(actions, "play_card", "counter_tactic")
	_expect(not counter_action.is_empty(), "pending-attack counter test should expose a counter-tactic action during attack response", failures)
	if counter_action.is_empty():
		return
	var targets = counter_action.get("targets", [])
	var pending_target_found := false
	for target in targets:
		if str(target.get("target_stack_id", "")) == "__pending_attack__":
			pending_target_found = true
			break
	_expect(pending_target_found, "pending-attack counter test should expose the live pending attack as a counter target", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "counter_tactic",
		"col": -1,
		"effect_id": "absolute_defense",
		"target_stack_id": "__pending_attack__"
	})).ok, "pending-attack counter test should allow countering the pending attack with 绝对防御", failures)
	_expect(not state.pending_attack.is_empty(), "pending-attack counter test should keep the pending attack open until the counter effect resolves", failures)
	_expect(state.stack.size() == 1, "pending-attack counter test should put 绝对防御 on the stack first", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "pending-attack counter test first pass on the counter stack should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "pending-attack counter test second pass on the counter stack should resolve the effect", failures)
	_expect(state.pending_attack.is_empty(), "pending-attack counter test should clear the pending attack after 绝对防御 resolves", failures)
	_expect(state.stack.is_empty(), "pending-attack counter test should clear the stack after the counter resolves", failures)

static func _test_disabled_counter_tactic_is_hidden_from_priority_actions(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _disabled_counter_tactic_decks(), 1408, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var hiromasa_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	var truce_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0015")
	var counter_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0016")
	_expect(hiromasa_id != "" and truce_id != "" and counter_id != "", "disabled counter legal actions test should draw 源博雅, 议和谈判 and 绝对防御", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "disabled counter legal actions test should add enough morale for 源博雅", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hiromasa_id,
		"row": "front",
		"col": 0
	})).ok, "disabled counter legal actions test should play 源博雅", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "disabled counter legal actions enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "disabled counter legal actions enter trigger second pass should resolve", failures)
	_advance_to_next_main(engine, state, failures, "disabled counter legal actions should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("disabled counter legal actions did not reach player 2 main")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "disabled counter legal actions test should add one morale for setting 绝对防御", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": counter_id,
		"row": "back",
		"col": 0
	})).ok, "disabled counter legal actions test should set 绝对防御 onto the battlefield", failures)
	_advance_to_next_main(engine, state, failures, "disabled counter legal actions should advance back to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("disabled counter legal actions did not return to player 1 main")
		return
	var hiromasa_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hiromasa_instance_id,
		"target_kind": "master",
		"target_player": 1
	})).ok, "disabled counter legal actions hiromasa attack should succeed", failures)
	_expect(state.pending_choices.size() == 1, "disabled counter legal actions should request a facedown counter-tactic choice first", failures)
	if state.pending_choices.is_empty():
		return
	var hiromasa_choice = state.pending_choices[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(hiromasa_choice.get("choice_id", "")),
		"selected_card_ids": [counter_id]
	})).ok, "disabled counter legal actions trigger choice should resolve", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "disabled counter legal actions trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "disabled counter legal actions trigger second pass should resolve", failures)
	var disabled_counter_instance = state.card_instances.get(counter_id)
	_expect(disabled_counter_instance != null and int(disabled_counter_instance.flags.get("counter_tactic_disabled_turn", -1)) == state.turn_number, "disabled counter legal actions should mark the enemy counter tactic as disabled", failures)
	_resolve_pending_attack(engine, state, failures, "disabled counter legal actions combat first pass should succeed", "disabled counter legal actions combat second pass should resolve")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": truce_id,
		"row": "tactic",
		"col": -1
	})).ok, "disabled counter legal actions should play 议和谈判", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForPriority", "disabled counter legal actions should enter waiting-for-priority on the stack response window", failures)
	_expect(int(waiting.get("player_id", -1)) == 1, "disabled counter legal actions should hand priority to the defending player", failures)
	var actions = engine.get_legal_actions(state, 1)
	_expect(not actions.is_empty(), "disabled counter legal actions should still expose some priority actions", failures)
	var disabled_counter_action := {}
	for action in actions:
		if str(action.get("kind", "")) != "activate_effect":
			continue
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("source_id", "")) == counter_id and str(payload.get("effect_id", "")) == "absolute_defense":
			disabled_counter_action = action
			break
	_expect(disabled_counter_action.is_empty(), "disabled counter legal actions should not expose disabled counter tactics", failures)

static func _test_candidate_cards_pick_choice_actions_expose_candidate_cards(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _search_choice_decks(), 1409)
	var scout_id = _find_hand_card_by_definition(state, 0, "qa_scout")
	_expect(scout_id != "", "candidate choice legal actions test should draw qa_scout", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": scout_id,
		"row": "front",
		"col": 0
	})).ok, "candidate choice legal actions source play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": scout_id,
		"effect_id": "search_legion"
	})).ok, "candidate choice legal actions effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "candidate choice legal actions first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "candidate choice legal actions second pass should resolve to a choice", failures)
	var waiting = engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForChoice", "candidate choice legal actions should enter waiting-for-choice", failures)
	_expect(str(waiting.get("choice_type", "")) == "candidate_cards_pick", "candidate choice waiting state should expose candidate_cards_pick", failures)
	var actions = engine.get_legal_actions(state, 0)
	_expect(actions.size() == 1, "candidate choice legal actions should expose exactly one resolve-choice action", failures)
	if actions.size() == 1:
		var action = actions[0]
		_expect(str(action.get("choice_type", "")) == "candidate_cards_pick", "candidate choice action should expose candidate_cards_pick", failures)
		_expect(int(action.get("count", -1)) == 1, "candidate choice action should preserve the requested selection count", failures)
		var candidate_card_ids = action.get("candidate_card_ids", [])
		_expect(candidate_card_ids is Array and candidate_card_ids.size() == 2, "candidate choice action should expose both candidate card ids", failures)
		_expect(str(action.get("operation", "")) == "search_deck", "candidate choice action should expose the underlying operation", failures)

static func _test_multi_mode_tactic_actions_are_flattened(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _multi_mode_decks(), 1404)
	var tactic_id = _find_hand_card_by_definition(state, 0, "demo_twin_command")
	_expect(tactic_id != "", "multi-mode tactics test should draw twin command", failures)
	var actions = engine.get_legal_actions(state, 0)
	var tactic_actions = _find_card_actions(actions, tactic_id, "tactic")
	_expect(tactic_actions.size() == 2, "multi-mode tactic should be flattened into two separate action proposals", failures)
	var effect_ids: Array[String] = []
	for action in tactic_actions:
		_expect(_is_standardized_action(action), "flattened tactic proposals should use the standardized action schema", failures)
		effect_ids.append(str(action.get("payload_template", {}).get("effect_id", "")))
	_expect(effect_ids.has("command_draw"), "flattened tactic proposals should include the draw mode", failures)
	_expect(effect_ids.has("command_bolt"), "flattened tactic proposals should include the damage mode", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _core_decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _hand_response_decks() -> Array:
	return [
		["asgard_s01_0312", "neutral_s01_0002", "neutral_s01_0015", "neutral_s01_0016", "takamagahara_s01_0419", "takamagahara_s01_0417"],
		["takamagahara_s01_0404", "neutral_s01_0015", "neutral_s01_0016", "asgard_s01_0318", "asgard_s01_0306", "asgard_s01_0312"]
	]

static func _search_choice_decks() -> Array:
	return [
		["qa_scout", "qa_vanilla", "qa_plain", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _multi_mode_decks() -> Array:
	return [
		["demo_twin_command", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _play_option_decks() -> Array:
	return [
		["asgard_s01_0303", "neutral_s01_0015", "neutral_s01_0016", "asgard_s01_0312", "asgard_s01_0306", "neutral_s01_0001", "neutral_s01_0015"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _option_pick_decks() -> Array:
	return [
		["neutral_s01_0015", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _counter_tactic_decks() -> Array:
	return [
		["neutral_s01_0015", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["neutral_s01_0016", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _formal_core_decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _disabled_counter_tactic_decks() -> Array:
	return [
		["takamagahara_s01_0413", "neutral_s01_0015", "neutral_s01_0015", "takamagahara_s01_0418", "takamagahara_s01_0409", "takamagahara_s01_0417", "qa_blank", "qa_blank"],
		["neutral_s01_0016", "neutral_s01_0015", "neutral_s01_0015", "asgard_s01_0312", "asgard_s01_0303", "asgard_s01_0306", "qa_blank", "qa_blank"]
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

static func _resolve_pending_attack(engine: GameEngine, state, failures: Array[String], first_message: String, second_message: String) -> void:
	if state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, first_message, failures)
	if state.pending_attack.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")).ok, second_message, failures)

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _find_action(actions: Array[Dictionary], kind: String, play_kind: String = "", defense_kind: String = "") -> Dictionary:
	for action in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if not play_kind.is_empty() and str(action.get("play_kind", "")) != play_kind:
			continue
		if not defense_kind.is_empty() and str(action.get("source", {}).get("defense_kind", "")) != defense_kind:
			continue
		return action
	return {}

static func _find_card_actions(actions: Array[Dictionary], card_id: String, play_kind: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in actions:
		var payload = action.get("payload_template", {})
		if str(payload.get("card_id", "")) != card_id:
			continue
		if not play_kind.is_empty() and str(action.get("play_kind", "")) != play_kind:
			continue
		result.append(action)
	return result

static func _find_card_action_with_option(actions: Array[Dictionary], play_option_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("payload_template", {}).get("play_option_id", "")) == play_option_id:
			return action
	return {}

static func _is_standardized_action(action: Dictionary) -> bool:
	return action.has("proposal_id") \
		and action.has("kind") \
		and action.has("command_type") \
		and action.has("label") \
		and action.has("payload_template") \
		and action.has("targets")

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
