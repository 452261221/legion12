extends RefCounted
class_name TestTakamagaharaBatch4

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_takeda_search_deploy_and_master_morale_lock(failures)
	return failures

static func _test_takeda_search_deploy_and_master_morale_lock(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0401", "takamagahara_s01_0404", "takamagahara_s01_0413", "takamagahara_s01_0403", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3301, [], _formal_options(2, 9))
	var takeda_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0401")
	var yukimura_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0404")
	_expect(takeda_id != "" and yukimura_id != "", "takeda test should draw 武田信玄 and 真田幸村", failures)
	if takeda_id == "" or yukimura_id == "":
		return
	var searchable_id := ""
	for card_id in state.get_player(0).deck.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and instance.definition_id == "takamagahara_s01_0413":
			searchable_id = str(card_id)
			break
	_expect(searchable_id != "", "takeda test deck should contain a searchable 5000-power 高天原 legion", failures)
	if searchable_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": takeda_id,
		"row": "front",
		"col": 0
	})).ok, "武田信玄 should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "武田信玄 entry should resolve to a search choice")
	_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "yes"), "武田信玄 entry should allow choosing to use the search effect", failures)
	_expect(_find_hand_card_by_definition(state, 0, "takamagahara_s01_0413") != "", "武田信玄 should add the selected 5000-power 高天原 legion to hand even when the search auto-resolves to a single match", failures)
	_expect(_find_hand_card_by_definition(state, 0, "takamagahara_s01_0413") != "", "武田信玄 should add the selected 5000-power 高天原 legion to hand", failures)
	var revealed_payload := _last_event_payload(state, "CardsRevealedToOpponent")
	_expect(int(revealed_payload.get("revealing_player_id", -1)) == 0, "武田信玄 should reveal the searched legion to the opponent", failures)
	var revealed_ids = revealed_payload.get("card_ids", [])
	_expect(revealed_ids is Array and revealed_ids.has(searchable_id), "武田信玄 should reveal the actually added legion card to the opponent", failures)
	_expect(_last_event_payload(state, "DeckShuffled").get("player_id", -1) == 0, "武田信玄 should shuffle its controller deck after the search", failures)
	var active_morale_before_deploy = state.get_player(0).cost_area.cards.size()
	_expect(_resolve_candidate_choice(engine, state, "deploy_from_hand_to_battlefield", [yukimura_id]), "武田信玄 should request deploying 真田幸村 from hand", failures)
	_expect(_resolve_option_choice(engine, state, "deploy_selected_hand_to_slot", "front:1"), "武田信玄 should let 真田幸村 choose a battlefield slot", failures)
	_expect(state.get_player(0).battle_front[1].occupant == yukimura_id, "武田信玄 should deploy 真田幸村 to the selected battlefield slot", failures)
	var yukimura_instance = state.card_instances.get(yukimura_id)
	_expect(yukimura_instance != null and str(yukimura_instance.orientation) == "active", "武田信玄 should deploy 真田幸村 in active orientation", failures)
	_expect(state.get_player(0).cost_area.cards.size() == active_morale_before_deploy + 1, "武田信玄 should ready one spent morale after 真田幸村 enters", failures)
	var active_morale_before_master_ready = state.get_player(0).cost_area.cards.size()
	var blocked_ready_events = engine._ready_spent_morale(state, {
		"controller": 0,
		"source_instance_id": "master_0",
		"resolution": {
			"count": 1
		}
	}, "test_takeda_master_ready_lock")
	_expect(blocked_ready_events.is_empty(), "武田信玄 should stop master-sourced morale ready effects", failures)
	_expect(state.get_player(0).cost_area.cards.size() == active_morale_before_master_ready, "武田信玄 should keep active morale unchanged when the source is the master", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _formal_options(opening_hand_size: int, opening_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": 10
	}

static func _resolve_top_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	if state.stack.is_empty():
		return
	var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(first_pass.ok, message, failures)
	if not state.pending_choices.is_empty() or state.stack.is_empty():
		return
	var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
	_expect(second_pass.ok, message, failures)

static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
	})).ok

static func _resolve_candidate_choice(engine: GameEngine, state, operation: String, selected_card_ids: Array) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": selected_card_ids.duplicate()
	})).ok

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

static func _last_event_payload(state, event_type: String) -> Dictionary:
	for index in range(state.event_log.size() - 1, -1, -1):
		var event = state.event_log[index]
		if str(event.type) == event_type:
			return event.payload.duplicate(true)
	return {}

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
