extends RefCounted
class_name TestClassicBatch2

const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_court_magician_entry_and_lock(failures)
	_test_pitfall_counters_enemy_entry_effect(failures)
	_test_trickster_puppet_redirects_master_attack(failures)
	_test_confusion_arrows_destroy_up_to_three_small_legions(failures)
	return failures

static func _test_court_magician_entry_and_lock(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _court_magician_decks(), 2101, [], _formal_options(3))
	var allied_counter_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0019")
	_expect(allied_counter_id != "", "court magician test should draw allied 伏击", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": allied_counter_id,
		"row": "back",
		"col": 0
	})).ok, "court magician test should allow setting allied 伏击", failures)
	_advance_to_next_main(engine, state, failures, "court magician test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("court magician test did not reach player 2 main")
		return
	var enemy_counter_id = _find_hand_card_by_definition(state, 1, "neutral_s01_0019")
	_expect(enemy_counter_id != "", "court magician test should draw enemy 伏击", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_counter_id,
		"row": "back",
		"col": 0
	})).ok, "court magician test should allow setting enemy 伏击", failures)
	_advance_to_next_main(engine, state, failures, "court magician test should return to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("court magician test did not return to player 1 main")
		return
	var magician_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0003")
	_expect(magician_id != "", "court magician test should draw 宫廷魔术师", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": magician_id,
		"row": "front",
		"col": 0
	})).ok, "court magician should deploy successfully", failures)
	_resolve_top_stack(engine, state, failures, "court magician entry should resolve to optional choice")
	_expect(_resolve_candidate_choice(engine, state, "destroy_battlefield_cards", [str(state.get_player(1).battle_back[0].occupant)]), "court magician should select the enemy counter tactic", failures)
	_expect(state.get_player(1).grave.cards.has(str(state.get_player(1).grave.cards.back())), "court magician should move the selected counter tactic to grave", failures)
	_expect(str(state.get_player(1).battle_back[0].occupant) == "", "court magician should clear the enemy back slot after the entry effect", failures)
	var magician_instance_id = str(state.get_player(0).battle_front[0].occupant)
	_expect(magician_instance_id != "", "court magician should remain on the battlefield after deployment", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": magician_instance_id,
		"effect_id": "court_magician_disable_counters"
	})).ok, "court magician activated effect should be playable", failures)
	_resolve_top_stack(engine, state, failures, "court magician activated effect should resolve")
	var allied_battle_counter_id = str(state.get_player(0).battle_back[0].occupant)
	_expect(allied_battle_counter_id != "", "court magician test should keep the allied counter tactic on battlefield", failures)
	_expect(engine._is_counter_tactic_disabled_this_turn(state, allied_battle_counter_id), "court magician should disable battlefield counter tactics immediately", failures)
	_advance_to_next_main(engine, state, failures, "court magician disable should persist into the opponent turn")
	_expect(engine._is_counter_tactic_disabled_this_turn(state, allied_battle_counter_id), "court magician should keep counters disabled during the opponent turn", failures)
	_advance_to_next_main(engine, state, failures, "court magician disable should expire at the next allied turn start")
	_expect(not engine._is_counter_tactic_disabled_this_turn(state, allied_battle_counter_id), "court magician should clear the disable when the controller next turn starts", failures)

static func _test_pitfall_counters_enemy_entry_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _pitfall_decks(), 2102, [], _formal_options(2))
	var pitfall_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0018")
	_expect(pitfall_id != "", "pitfall test should draw 落穴陷阱", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": pitfall_id,
		"row": "back",
		"col": 0
	})).ok, "pitfall test should allow setting 落穴陷阱", failures)
	_advance_to_next_main(engine, state, failures, "pitfall test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("pitfall test did not reach player 2 main")
		return
	var odell_id = _find_hand_card_by_definition(state, 1, "asgard_s01_0313")
	_expect(odell_id != "", "pitfall test should draw 神箭奥德尔", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": odell_id,
		"row": "front",
		"col": 0
	})).ok, "pitfall test should allow the enemy legion to enter", failures)
	_expect(not state.stack.is_empty(), "pitfall test should create an entry-effect stack item", failures)
	var stack_id = str(state.stack[0].get("stack_id", ""))
	var pitfall_instance_id = str(state.get_player(0).battle_back[0].occupant)
	_expect(pitfall_instance_id != "", "pitfall test should keep the set trap on battlefield", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": pitfall_instance_id,
		"effect_id": "pitfall_counter_enemy_entry",
		"target_stack_id": stack_id
	})).ok, "pitfall should activate against an enemy legion entry effect", failures)
	_resolve_top_stack(engine, state, failures, "pitfall should resolve from the counter stack")
	_expect(state.stack.is_empty(), "pitfall should remove the targeted entry effect from the stack", failures)
	_expect(state.get_player(0).grave.cards.has(pitfall_instance_id), "pitfall should move to grave after resolving", failures)
	_expect(state.players[1].master_hp == 20, "pitfall should stop 奥德尔的登场自伤效果 from resolving", failures)
	_expect(state.get_player(1).hand.cards.size() == 0, "pitfall should stop 奥德尔 from drawing a card", failures)

static func _test_trickster_puppet_redirects_master_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _trickster_puppet_decks(), 2103, [], _formal_options(2))
	_advance_to_next_main(engine, state, failures, "trickster puppet test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("trickster puppet test did not reach player 2 main")
		return
	var attacker_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(attacker_id != "", "trickster puppet test should draw the attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "trickster puppet test should deploy the attacker", failures)
	_advance_to_next_main(engine, state, failures, "trickster puppet test should advance until the attacker can act")
	_advance_to_next_main(engine, state, failures, "trickster puppet test should return to player 2 main for the attack")
	if state.active_player != 1 or state.phase != "main":
		failures.append("trickster puppet test did not return to player 2 main for the attack")
		return
	var attacker_instance_id = str(state.get_player(1).battle_front[0].occupant)
	var master_target := _find_master_target(engine.get_legal_attack_targets(state, attacker_instance_id), 0)
	_expect(not master_target.is_empty(), "trickster puppet test should allow attacking the defending master", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"target_player": 0
	})).ok, "trickster puppet test should declare a master attack", failures)
	var puppet_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0005")
	_expect(puppet_id != "", "trickster puppet test should keep the puppet in hand for response", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": puppet_id,
		"row": "hand_response",
		"effect_id": "trickster_puppet_redirect_master_attack"
	})).ok, "trickster puppet should be playable as a master-attack hand response", failures)
	var slot_choice = _pending_choice_by_operation(state, "hand_response_deploy_to_front_and_redirect_pending_attack")
	_expect(slot_choice != null, "trickster puppet should ask for a front-row deployment slot", failures)
	if slot_choice == null:
		return
	var selected_option = ""
	var options = slot_choice.get("options", [])
	if options is Array and not options.is_empty():
		selected_option = str(options[0].get("id", ""))
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(slot_choice.get("choice_id", "")),
		"selected_option": selected_option
	})).ok, "trickster puppet should resolve its deployment slot choice", failures)
	_expect(str(state.pending_attack.get("target_kind", "")) == "card", "trickster puppet should retarget the pending attack to a defender", failures)
	_expect(str(state.pending_attack.get("defender_id", "")) == puppet_id, "trickster puppet should make itself the pending defender", failures)
	_drain_stack_and_choices(engine, state, failures, "trickster puppet redirected attack should fully resolve")
	_expect(state.players[0].master_hp == 20, "trickster puppet should prevent the master from taking the redirected attack damage", failures)
	_expect(state.get_player(0).grave.cards.has(puppet_id), "trickster puppet should die after taking the redirected hit", failures)

static func _test_confusion_arrows_destroy_up_to_three_small_legions(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _confusion_arrows_decks(), 2104, [], _formal_options(4))
	_advance_to_next_main(engine, state, failures, "confusion arrows test should advance to player 2 main")
	if state.active_player != 1 or state.phase != "main":
		failures.append("confusion arrows test did not reach player 2 main")
		return
	for payload in [
		{"row": "front", "col": 0},
		{"row": "front", "col": 1},
		{"row": "back", "col": 0}
	]:
		var small_id = _find_hand_card_by_definition(state, 1, "qa_plain")
		_expect(small_id != "", "confusion arrows test should keep drawing small enemy legions", failures)
		_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
			"card_id": small_id,
			"row": str(payload.row),
			"col": int(payload.col)
		})).ok, "confusion arrows test should deploy each small legion", failures)
	var large_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(large_id != "", "confusion arrows test should draw the large enemy legion", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": large_id,
		"row": "back",
		"col": 1
	})).ok, "confusion arrows test should deploy the large legion", failures)
	var buff_target_id = str(state.get_player(1).battle_front[0].occupant)
	_expect(buff_target_id != "", "confusion arrows test should keep the first small legion on battlefield for the buff check", failures)
	engine._process_generated_events(state, engine._modify_power_until_turn_end(state, buff_target_id, 3000, "test_confusion_arrows_temp_buff"), "test_confusion_arrows_temp_buff")
	_advance_to_next_main(engine, state, failures, "confusion arrows test should return to player 1 main")
	if state.active_player != 0 or state.phase != "main":
		failures.append("confusion arrows test did not return to player 1 main")
		return
	var arrows_id = _find_hand_card_by_definition(state, 0, "neutral_s02_0011")
	_expect(arrows_id != "", "confusion arrows test should draw 纷乱箭", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": arrows_id,
		"row": "tactic",
		"col": -1
	})).ok, "confusion arrows should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "confusion arrows should resolve to a target choice")
	var choice = _pending_choice_by_operation(state, "destroy_battlefield_cards")
	_expect(choice != null, "confusion arrows should open a destroy target choice after resolving", failures)
	if choice == null:
		return
	var candidate_ids = choice.get("candidate_card_ids", [])
	_expect(candidate_ids is Array and candidate_ids.size() == 3, "confusion arrows should only offer the three small enemy legions as targets", failures)
	_expect(candidate_ids.has(buff_target_id), "confusion arrows should still allow targeting a 1000-power legion even after temporary power buffs", failures)
	_expect(_resolve_candidate_choice(engine, state, "destroy_battlefield_cards", candidate_ids), "confusion arrows should destroy all eligible low-power targets", failures)
	_expect(state.get_player(1).grave.cards.size() == 3, "confusion arrows should destroy exactly three small legions", failures)
	_expect(str(state.get_player(1).battle_back[1].occupant) != "", "confusion arrows should leave the 3000-power legion on the battlefield", failures)

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

static func _court_magician_decks() -> Array:
	return [
		["neutral_s01_0019", "neutral_s02_0003", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["neutral_s01_0019", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _pitfall_decks() -> Array:
	return [
		["neutral_s01_0018", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["asgard_s01_0313", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _trickster_puppet_decks() -> Array:
	return [
		["neutral_s02_0005", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _confusion_arrows_decks() -> Array:
	return [
		["neutral_s02_0011", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_plain", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, message, failures)
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, message, failures)

static func _resolve_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	var resolved_selected: Array = []
	if selected_card_ids is Array:
		for card_id in selected_card_ids:
			resolved_selected.append(str(card_id))
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": resolved_selected
	})).ok

static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
	})).ok

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

static func _pending_choice_by_operation(state, operation: String):
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return null

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _find_master_target(targets, target_player: int) -> Dictionary:
	if not (targets is Array):
		return {}
	for target in targets:
		if str(target.get("target_kind", "")) != "master":
			continue
		if int(target.get("target_player", -1)) == target_player:
			return target
	return {}

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
