extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")

func _initialize() -> void:
	_debug_honda_attack_chain()
	_debug_olaf_attack_chain()
	_debug_gustav_attack_chain()
	quit(0)

func _debug_honda_attack_chain() -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"takamagahara_s01_0401",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		],
		[
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"asgard_s01_0318",
			"neutral_s01_0016",
			"asgard_s01_0303"
		]
	], 1309)
	_apply(engine, state, 0, {"action":"add_morale","player_id":0,"count":5}, "DebugCommand", "honda add morale")
	var honda_id := _find_hand(state, 0, "takamagahara_s01_0401")
	_apply(engine, state, 0, {"card_id":honda_id,"row":"front","col":0}, "PlayCard", "honda play")
	_advance_to_next_main(engine, state)
	_advance_to_next_main(engine, state)
	var honda_instance_id := state.get_player(0).battle_front[0].occupant
	var hp_before := state.get_player(1).master_hp
	print("honda attack:", engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": honda_instance_id,
		"target_kind": "master",
		"target_player": 1
	})))
	print("honda after declare stack:", state.stack)
	print("honda after declare pending_attack:", state.pending_attack)
	print("honda pass1:", engine.apply_command(state, GameCommand.create(1, "PassPriority")))
	print("honda after pass1 stack:", state.stack)
	print("honda after pass1 pending_choices:", state.pending_choices)
	print("honda pass2:", engine.apply_command(state, GameCommand.create(0, "PassPriority")))
	print("honda hp delta:", hp_before, "->", state.get_player(1).master_hp)
	print("honda event tail:", _tail_events(state, 8))

func _debug_olaf_attack_chain() -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"asgard_s01_0306",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0312",
			"neutral_s01_0015"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1310)
	_apply(engine, state, 0, {"action":"add_morale","player_id":0,"count":2}, "DebugCommand", "olaf add morale")
	var seed := _seed_grave(state, 0, 1)
	print("olaf grave seed:", seed)
	var olaf_id := _find_hand(state, 0, "asgard_s01_0306")
	_apply(engine, state, 0, {"card_id":olaf_id,"row":"front","col":0}, "PlayCard", "olaf play")
	_advance_to_next_main(engine, state)
	_advance_to_next_main(engine, state)
	var olaf_instance_id := state.get_player(0).battle_front[0].occupant
	var hp_before := state.get_player(1).master_hp
	print("olaf attack:", engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": olaf_instance_id,
		"target_kind": "master",
		"target_player": 1
	})))
	print("olaf stack after declare:", state.stack)
	print("olaf pass1:", engine.apply_command(state, GameCommand.create(1, "PassPriority")))
	print("olaf after pass1 choice:", state.pending_choices)
	print("olaf pass2:", engine.apply_command(state, GameCommand.create(0, "PassPriority")))
	print("olaf hp delta:", hp_before, "->", state.get_player(1).master_hp)
	print("olaf event tail:", _tail_events(state, 8))

func _debug_gustav_attack_chain() -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		[
			"asgard_s01_0311",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0316",
			"asgard_s01_0303",
			"asgard_s01_0312",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"asgard_s01_0318",
			"neutral_s01_0015"
		],
		[
			"takamagahara_s01_0410",
			"neutral_s01_0015",
			"neutral_s01_0016",
			"takamagahara_s01_0418",
			"takamagahara_s01_0409",
			"takamagahara_s01_0417"
		]
	], 1311)
	_apply(engine, state, 0, {"action":"add_morale","player_id":0,"count":1}, "DebugCommand", "gustav add morale")
	var seed := _seed_grave(state, 0, 4)
	print("gustav grave seed:", seed)
	var gustav_id := _find_hand(state, 0, "asgard_s01_0311")
	_apply(engine, state, 0, {"card_id":gustav_id,"row":"front","col":0}, "PlayCard", "gustav play")
	_advance_to_next_main(engine, state)
	_advance_to_next_main(engine, state)
	var gustav_instance_id := state.get_player(0).battle_front[0].occupant
	print("gustav attack:", engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": gustav_instance_id,
		"target_kind": "master",
		"target_player": 1
	})))
	print("gustav stack after declare:", state.stack)
	print("gustav pass1:", engine.apply_command(state, GameCommand.create(1, "PassPriority")))
	print("gustav pending choices after pass1:", state.pending_choices)
	print("gustav pass2:", engine.apply_command(state, GameCommand.create(0, "PassPriority")))
	print("gustav pending choices after pass2:", state.pending_choices)
	if not state.pending_choices.is_empty():
		var choice = state.pending_choices[0]
		var selected := []
		for raw in choice.get("candidate_card_ids", []):
			selected.append(str(raw))
			if selected.size() >= 2:
				break
		print("gustav resolve choice:", engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
			"choice_id": str(choice.get("choice_id", "")),
			"selected_card_ids": selected
		})))
	print("gustav after choice pending_attack:", state.pending_attack)
	print("gustav pass3:", engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")))
	print("gustav pass4:", engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority")))
	print("gustav stack end:", state.stack)
	print("gustav event tail:", _tail_events(state, 12))

func _apply(engine: GameEngine, state, player_id: int, payload: Dictionary, command_type: String, label: String) -> void:
	print(label, ":", engine.apply_command(state, GameCommand.create(player_id, command_type, payload)))

func _find_hand(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return str(card_id)
	return ""

func _advance_to_next_main(engine: GameEngine, state) -> void:
	for _i in range(6):
		engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase"))
		if state.phase == "main":
			return

func _seed_grave(state, player_id: int, count: int) -> Array[String]:
	var moved: Array[String] = []
	var player = state.get_player(player_id)
	for _i in range(count):
		if player.deck.cards.is_empty():
			break
		var card_id = str(player.deck.cards[0])
		player.deck.remove_card(card_id)
		player.grave.add_card(card_id)
		var instance = state.card_instances.get(card_id)
		if instance != null:
			instance.zone = "grave"
			instance.position = {}
		moved.append(card_id)
	return moved

func _tail_events(state, count: int) -> Array[String]:
	var result: Array[String] = []
	var start: int = max(0, state.event_log.size() - count)
	for i in range(start, state.event_log.size()):
		var event = state.event_log[i]
		result.append("%s:%s" % [str(event.event_id), str(event.type)])
	return result
