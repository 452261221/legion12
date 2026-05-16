extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")

func _initialize() -> void:
	_debug_mercenary_opening()
	_debug_hiromasa_truce()
	_debug_yoshitsune_target()
	quit(0)


func _debug_mercenary_opening() -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"neutral_s01_0002",
			"neutral_s01_0002",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0419",
			"takamagahara_s01_0417",
			"neutral_s01_0015"
		],
		[
			"asgard_s01_0303",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0306",
			"asgard_s01_0312"
		]
	], 1326)
	_apply_ok(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 4
	})), "mercenary add morale")
	var mercenary_id := _find_hand_card_by_definition(state, 0, "neutral_s01_0002")
	print("mercenary hand:", state.get_player(0).hand.cards)
	print("mercenary active morale:", state.get_player(0).cost_area.cards.size())
	print("mercenary id:", mercenary_id)
	print("mercenary slots:", engine.get_legal_play_slots(state, 0, mercenary_id))
	print("mercenary play:", engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mercenary_id,
		"row": "front",
		"col": 0
	})))


func _debug_hiromasa_truce() -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"takamagahara_s01_0413",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"neutral_s01_0016",
			"neutral_s01_0015",
			"neutral_s01_0015",
			"asgard_s01_0312",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1322)
	_apply_ok(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})), "hiromasa add morale")
	var hiromasa_id := _find_hand_card_by_definition(state, 0, "takamagahara_s01_0413")
	var truce_id := _find_hand_card_by_definition(state, 0, "neutral_s01_0015")
	_apply_ok(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": hiromasa_id,
		"row": "front",
		"col": 0
	})), "hiromasa play")
	_drain(engine, state)
	_advance_to_next_main(engine, state)
	_advance_to_next_main(engine, state)
	var hiromasa_instance_id := state.get_player(0).battle_front[0].occupant
	print("hiromasa hand before attack:", state.get_player(0).hand.cards)
	print("hiromasa attack:", engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": hiromasa_instance_id,
		"target_kind": "master",
		"target_player": 1
	})))
	_drain(engine, state)
	print("hiromasa waiting:", engine.get_waiting_state(state))
	print("hiromasa truce id:", truce_id)
	print("hiromasa hand after attack:", state.get_player(0).hand.cards)
	print("hiromasa truce play:", engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": truce_id,
		"row": "tactic",
		"col": -1
	})))


func _debug_yoshitsune_target() -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"takamagahara_s01_0409",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0417",
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016"
		],
		[
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"asgard_s01_0303",
			"asgard_s01_0306"
		]
	], 1323)
	_apply_ok(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})), "yoshi add morale")
	_advance_to_next_main(engine, state)
	var target_id := _find_hand_card_by_definition(state, 1, "asgard_s01_0312")
	_apply_ok(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})), "yoshi target play")
	_advance_to_next_main(engine, state)
	var yoshi_id := _find_hand_card_by_definition(state, 0, "takamagahara_s01_0409")
	_apply_ok(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": yoshi_id,
		"row": "front",
		"col": 0
	})), "yoshi play")
	_advance_to_next_main(engine, state)
	_advance_to_next_main(engine, state)
	var yoshi_instance_id := state.get_player(0).battle_front[0].occupant
	_apply_ok(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": yoshi_instance_id,
		"effect_id": "yoshitsune_reposition"
	})), "yoshi reposition")
	_drain(engine, state)
	var target_instance_id := state.get_player(1).battle_front[0].occupant
	print("yoshi power:", engine.get_card_power(state, yoshi_instance_id))
	print("target power:", engine.get_card_power(state, target_instance_id))
	print("yoshi legal targets:", engine.get_legal_attack_targets(state, yoshi_instance_id))
	print("yoshi attack:", engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": yoshi_instance_id,
		"defender_id": target_instance_id
	})))


func _apply_ok(result: Dictionary, label: String) -> void:
	print(label, ": ", result)


func _advance_to_next_main(engine: GameEngine, state) -> void:
	for _i in range(6):
		engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase"))
		if state.phase == "main":
			return


func _drain(engine: GameEngine, state) -> void:
	for _i in range(16):
		if state.pending_choices.is_empty() and state.stack.is_empty() and state.pending_attack.is_empty():
			return
		if not state.pending_choices.is_empty():
			var choice = state.pending_choices[0]
			var payload = {"choice_id": str(choice.get("choice_id", ""))}
			match str(choice.get("type", "")):
				"candidate_cards_pick":
					var selected: Array[String] = []
					for raw_card_id in choice.get("candidate_card_ids", []):
						selected.append(str(raw_card_id))
						if selected.size() >= int(choice.get("count", 1)):
							break
					payload["selected_card_ids"] = selected
				"option_pick":
					var options = choice.get("options", [])
					if options is Array and not options.is_empty():
						payload["selected_option"] = str(options[0].get("id", ""))
			engine.apply_command(state, GameCommand.create(int(choice.get("player_id", -1)), "ResolveChoice", payload))
			continue
		engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))


func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return str(card_id)
	return ""
