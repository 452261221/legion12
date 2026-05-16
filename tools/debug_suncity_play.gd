extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const TEST_FILLER_CARD_ID := "asgard_s01_0301"

func _initialize() -> void:
	var definitions = CardDatabase.load_definitions()
	definitions.append_array(CardDatabase.load_definitions("res://data/raw_rule_cards/suncity_master_cards.json"))
	var masters = [
		"suncity_s01_02m1",
		"suncity_s02_02m1"
	]
	var engine := GameEngine.new()

	var canopic_state = engine.create_game(definitions, [
		["suncity_s01_0219", TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID]
	], 7201, masters, {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 1,
		"opening_active_player_morale": 6,
		"opening_non_active_player_morale": 6
	})
	var canopic_id = _find_hand_card_by_definition(canopic_state, 0, "suncity_s01_0219")
	print("canopic_state_winner=", canopic_state.winner, " loss_reason=", canopic_state.loss_reason, " master0=", canopic_state.get_player(0).master_definition_id, " master1=", canopic_state.get_player(1).master_definition_id)
	print("canopic_id=", canopic_id)
	print("canopic_play=", engine.apply_command(canopic_state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_id,
		"row": "artifact",
		"col": -1
	})))

	var hats_state = engine.create_game(definitions, [
		["suncity_s02_0203", TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID]
	], 7202, masters, {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 1,
		"opening_active_player_morale": 6,
		"opening_non_active_player_morale": 6
	})
	var hats_id = _find_hand_card_by_definition(hats_state, 0, "suncity_s02_0203")
	print("hats_state_winner=", hats_state.winner, " loss_reason=", hats_state.loss_reason, " master0=", hats_state.get_player(0).master_definition_id, " master1=", hats_state.get_player(1).master_definition_id)
	print("hats_id=", hats_id)
	print("hats_play=", engine.apply_command(hats_state, GameCommand.create(0, "PlayCard", {
		"card_id": hats_id,
		"row": "front",
		"col": 0
	})))

	var canopic_one_state = engine.create_game(definitions, [
		["suncity_s01_0217", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID]
	], 7203, masters, {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 2,
		"opening_active_player_morale": 6,
		"opening_non_active_player_morale": 6
	})
	var canopic_one_id = _find_hand_card_by_definition(canopic_one_state, 0, "suncity_s01_0217")
	var tomb_guard_id = _find_grave_card_by_definition(canopic_one_state, 0, "suncity_s01_0212")
	print("canopic_one_state_winner=", canopic_one_state.winner, " loss_reason=", canopic_one_state.loss_reason)
	print("canopic_one_id=", canopic_one_id, " tomb_guard_id=", tomb_guard_id)
	if not tomb_guard_id.is_empty():
		engine._revive_grave_card_to_first_slot(canopic_one_state, 0, tomb_guard_id, "debug_canopic_one_setup")
	print("canopic_one_play=", engine.apply_command(canopic_one_state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_one_id,
		"row": "artifact",
		"col": -1
	})))

	var canopic_four_state = engine.create_game(definitions, [
		["suncity_s01_0220", "suncity_s02_0203", "suncity_s01_0212", TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID]
	], 7204, masters, {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 3,
		"opening_active_player_morale": 6,
		"opening_non_active_player_morale": 6
	})
	var canopic_four_id = _find_hand_card_by_definition(canopic_four_state, 0, "suncity_s01_0220")
	var hats_four_id = _find_hand_card_by_definition(canopic_four_state, 0, "suncity_s02_0203")
	var tomb_four_id = _find_grave_card_by_definition(canopic_four_state, 0, "suncity_s01_0212")
	print("canopic_four_state_winner=", canopic_four_state.winner, " loss_reason=", canopic_four_state.loss_reason)
	print("hats_four_play=", engine.apply_command(canopic_four_state, GameCommand.create(0, "PlayCard", {
		"card_id": hats_four_id,
		"row": "front",
		"col": 0
	})))
	if not canopic_four_state.stack.is_empty():
		engine.apply_command(canopic_four_state, GameCommand.create(canopic_four_state.priority_player, "PassPriority"))
		if not canopic_four_state.pending_choices.is_empty() and int(canopic_four_state.pending_choices[0].get("player_id", -1)) == canopic_four_state.priority_player:
			engine.apply_command(canopic_four_state, GameCommand.create(canopic_four_state.priority_player, "ResolveChoice", {
				"choice_id": str(canopic_four_state.pending_choices[0].get("id", "")),
				"selected_card_ids": []
			}))
		if not canopic_four_state.stack.is_empty():
			engine.apply_command(canopic_four_state, GameCommand.create(canopic_four_state.priority_player, "PassPriority"))
	if not tomb_four_id.is_empty():
		engine._revive_grave_card_to_first_slot(canopic_four_state, 0, tomb_four_id, "debug_canopic_four_setup")
	print("canopic_four_play=", engine.apply_command(canopic_four_state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_four_id,
		"row": "artifact",
		"col": -1
	})))

	var thutmose_state = engine.create_game(definitions, [
		["suncity_s01_0201", TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID],
		["suncity_s02_0203", "suncity_s02_0204", TEST_FILLER_CARD_ID]
	], 7209, masters, {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 2,
		"opening_active_player_morale": 8,
		"opening_non_active_player_morale": 8
	})
	var thutmose_id = _find_hand_card_by_definition(thutmose_state, 0, "suncity_s01_0201")
	var enemy_a = _find_hand_card_by_definition(thutmose_state, 1, "suncity_s02_0203")
	var enemy_b = _find_hand_card_by_definition(thutmose_state, 1, "suncity_s02_0204")
	print("thutmose_state_winner=", thutmose_state.winner, " loss_reason=", thutmose_state.loss_reason)
	print("thutmose_id=", thutmose_id)
	engine._deploy_hand_card_to_slot(thutmose_state, 1, enemy_a, "front", 0, "debug_thutmose_enemy_a")
	engine._deploy_hand_card_to_slot(thutmose_state, 1, enemy_b, "front", 1, "debug_thutmose_enemy_b")
	var thutmose_play = engine.apply_command(thutmose_state, GameCommand.create(0, "PlayCard", {
		"card_id": thutmose_id,
		"row": "front",
		"col": 0
	}))
	print("thutmose_play=", thutmose_play)
	if not thutmose_state.stack.is_empty():
		engine.apply_command(thutmose_state, GameCommand.create(thutmose_state.priority_player, "PassPriority"))
		if not thutmose_state.pending_choices.is_empty():
			var choice = thutmose_state.pending_choices[0]
			engine.apply_command(thutmose_state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
				"choice_id": str(choice.get("id", "")),
				"selected_card_ids": [enemy_a]
			}))
	if not thutmose_state.stack.is_empty():
		engine.apply_command(thutmose_state, GameCommand.create(thutmose_state.priority_player, "PassPriority"))
		if not thutmose_state.stack.is_empty():
			engine.apply_command(thutmose_state, GameCommand.create(thutmose_state.priority_player, "PassPriority"))
	var enemy_b_instance = thutmose_state.card_instances.get(enemy_b)
	print("enemy_b_zone=", enemy_b_instance.zone if enemy_b_instance != null else "null", " power=", engine.get_card_power(thutmose_state, enemy_b))

	var ptolemy_state = engine.create_game(definitions, [
		["suncity_s01_0219", "suncity_s01_0222", "suncity_s01_0211", "suncity_s01_0208", "suncity_s01_0215", "suncity_s02_0203", "suncity_s02_0204", TEST_FILLER_CARD_ID],
		[TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID, TEST_FILLER_CARD_ID]
	], 7225, masters, {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 3,
		"opening_active_player_morale": 8,
		"opening_non_active_player_morale": 8
	})
	var canopic_three = _find_hand_card_by_definition(ptolemy_state, 0, "suncity_s01_0219")
	var celebration_id = _find_hand_card_by_definition(ptolemy_state, 0, "suncity_s01_0222")
	var ptolemy_id = _find_hand_card_by_definition(ptolemy_state, 0, "suncity_s01_0211")
	print("ptolemy_morale_before_canopic=", MoraleActions.count_active_morale(ptolemy_state, 0))
	print("canopic_three_play=", engine.apply_command(ptolemy_state, GameCommand.create(0, "PlayCard", {
		"card_id": canopic_three,
		"row": "artifact",
		"col": -1
	})))
	if not ptolemy_state.stack.is_empty():
		engine.apply_command(ptolemy_state, GameCommand.create(ptolemy_state.priority_player, "PassPriority"))
		if not ptolemy_state.stack.is_empty() and ptolemy_state.pending_choices.is_empty():
			engine.apply_command(ptolemy_state, GameCommand.create(ptolemy_state.priority_player, "PassPriority"))
	print("ptolemy_morale_before_celebration=", MoraleActions.count_active_morale(ptolemy_state, 0))
	print("deck_before_celebration=", ptolemy_state.get_player(0).deck.cards)
	print("celebration_play=", engine.apply_command(ptolemy_state, GameCommand.create(0, "PlayCard", {
		"card_id": celebration_id,
		"row": "tactic",
		"col": -1
	})))
	print("last_active_after_play=", ptolemy_state.get_player(0).flags.get("last_active_tactic", {}))
	print("after_celebration_play_pending=", ptolemy_state.pending_choices.size(), " stack=", ptolemy_state.stack.size())
	_pass_stack_pair(engine, ptolemy_state)
	print("after_celebration_pass1_pending=", ptolemy_state.pending_choices.size(), " stack=", ptolemy_state.stack.size())
	if not ptolemy_state.pending_choices.is_empty():
		var celebration_choice = ptolemy_state.pending_choices[0]
		print("celebration_choice_operation=", celebration_choice.get("operation", ""), " candidates=", celebration_choice.get("candidate_card_ids", []))
		engine.apply_command(ptolemy_state, GameCommand.create(int(celebration_choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(celebration_choice.get("id", "")),
			"selected_card_ids": [
				str(ptolemy_state.get_player(0).deck.cards[0]),
				str(ptolemy_state.get_player(0).deck.cards[1])
			]
		}))
	print("after_celebration_pick_pending=", ptolemy_state.pending_choices.size(), " stack=", ptolemy_state.stack.size())
	if not ptolemy_state.pending_choices.is_empty():
		var celebration_hand_choice = ptolemy_state.pending_choices[0]
		print("celebration_hand_choice_operation=", celebration_hand_choice.get("operation", ""), " candidates=", celebration_hand_choice.get("candidate_card_ids", []))
		engine.apply_command(ptolemy_state, GameCommand.create(int(celebration_hand_choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(celebration_hand_choice.get("id", "")),
			"selected_card_ids": [str(ptolemy_state.get_player(0).deck.cards[0])]
		}))
	print("after_celebration_hand_pick_pending=", ptolemy_state.pending_choices.size(), " stack=", ptolemy_state.stack.size())
	while ptolemy_state.pending_choices.is_empty() and not ptolemy_state.stack.is_empty():
		_pass_stack_pair(engine, ptolemy_state)
	while not ptolemy_state.pending_choices.is_empty() and str(ptolemy_state.pending_choices[0].get("operation", "")) == "olympus_reorder_bottom_pick":
		var reorder_choice = ptolemy_state.pending_choices[0]
		print("reorder_operation=", reorder_choice.get("operation", ""), " candidates=", reorder_choice.get("candidate_card_ids", []))
		engine.apply_command(ptolemy_state, GameCommand.create(int(reorder_choice.get("player_id", 0)), "ResolveChoice", {
			"choice_id": str(reorder_choice.get("id", "")),
			"selected_card_ids": [str(reorder_choice.get("candidate_card_ids", [])[0])]
		}))
	print("deck_after_celebration=", ptolemy_state.get_player(0).deck.cards)
	print("last_active_before_ptolemy=", ptolemy_state.get_player(0).flags.get("last_active_tactic", {}))
	print("ptolemy_morale_before_play=", MoraleActions.count_active_morale(ptolemy_state, 0))
	print("ptolemy_pending_choices=", ptolemy_state.pending_choices.size(), " stack=", ptolemy_state.stack.size())
	if not ptolemy_state.pending_choices.is_empty():
		print("ptolemy_pending_operation=", ptolemy_state.pending_choices[0].get("operation", ""))
	print("ptolemy_play=", engine.apply_command(ptolemy_state, GameCommand.create(0, "PlayCard", {
		"card_id": ptolemy_id,
		"row": "front",
		"col": 0
	})))
	print("ptolemy_pending_after=", ptolemy_state.pending_choices.size(), " stack_after=", ptolemy_state.stack.size(), " last_active=", ptolemy_state.get_player(0).flags.get("last_active_tactic", {}))
	_pass_stack_pair(engine, ptolemy_state)
	print("ptolemy_after_passes_pending=", ptolemy_state.pending_choices.size(), " stack=", ptolemy_state.stack.size())
	if not ptolemy_state.pending_choices.is_empty():
		print("ptolemy_choice_operation=", ptolemy_state.pending_choices[0].get("operation", ""), " candidates=", ptolemy_state.pending_choices[0].get("candidate_card_ids", []))

	quit()

func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

func _find_grave_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).grave.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

func _pass_stack_pair(engine: GameEngine, state) -> void:
	if state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
