extends RefCounted
class_name TestAiObservationVisibility

const ObservationBuilder = preload("res://ai/core/observation_builder.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameEvent = preload("res://rules/core/game_event.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_self_hand_visible_and_opponent_private_zones_hidden(failures)
	_test_concealed_enemy_battlefield_card_stays_hidden(failures)
	_test_pending_choice_private_details_only_visible_to_owner(failures)
	_test_revealed_cards_to_opponent_visible_only_to_target_viewer(failures)
	_test_revealed_cards_to_all_visible_to_both_viewers(failures)
	return failures

static func _test_self_hand_visible_and_opponent_private_zones_hidden(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["dev_legion_alpha", "qa_plain", "qa_ranged", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged"],
		["asgard_s01_0307", "qa_plain", "qa_ranged", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged"]
	], 4101)
	var builder := ObservationBuilder.new()
	var observation := builder.build(engine, state, 0)
	var self_hand = observation.get("self", {}).get("hand", [])
	var opponent_hand = observation.get("opponent", {}).get("hand", [])
	_expect(self_hand is Array and self_hand.size() == state.get_player(0).hand.cards.size(), "observation: self hand should expose full visible cards", failures)
	if self_hand is Array and not self_hand.is_empty():
		_expect(not str(self_hand[0].get("definition_id", "")).is_empty(), "observation: self hand cards should expose definition_id", failures)
		_expect(not str(self_hand[0].get("name", "")).is_empty(), "observation: self hand cards should expose card name", failures)
	_expect(opponent_hand is Array and opponent_hand.is_empty(), "observation: opponent hand contents should stay hidden", failures)
	_expect(int(observation.get("opponent", {}).get("hand_count", -1)) == state.get_player(1).hand.cards.size(), "observation: opponent hand should expose count only", failures)
	_expect(not observation.get("self", {}).has("deck"), "observation: self deck order should not be exposed", failures)
	_expect(not observation.get("opponent", {}).has("deck"), "observation: opponent deck order should not be exposed", failures)

static func _test_concealed_enemy_battlefield_card_stays_hidden(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["dev_legion_alpha", "qa_plain", "qa_ranged", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged"],
		["qa_ranged", "qa_plain", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged", "dev_legion_alpha"]
	], 4102)
	var enemy_card_id := str(state.get_player(1).hand.cards[0])
	engine._deploy_hand_card_to_slot(state, 1, enemy_card_id, "front", 0, "test_observation_hidden_enemy")
	var enemy_instance = state.card_instances.get(enemy_card_id)
	enemy_instance.face = "face_down"
	enemy_instance.flags["concealed"] = true
	var builder := ObservationBuilder.new()
	var observation := builder.build(engine, state, 0)
	var enemy_front = observation.get("opponent", {}).get("front", [])
	_expect(enemy_front is Array and not enemy_front.is_empty(), "observation: enemy battlefield should expose slot structure", failures)
	if enemy_front is Array and not enemy_front.is_empty():
		var occupant = enemy_front[0].get("occupant", {})
		_expect(str(occupant.get("visibility", "")) == "hidden", "observation: concealed enemy battlefield card should remain hidden", failures)
		_expect(not occupant.has("definition_id"), "observation: concealed enemy battlefield card should not expose definition_id", failures)
		_expect(str(occupant.get("face", "")) == "face_down", "observation: concealed enemy battlefield card should still expose face-down state", failures)

static func _test_pending_choice_private_details_only_visible_to_owner(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["dev_legion_alpha", "qa_plain", "qa_ranged", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged"],
		["qa_ranged", "qa_plain", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged", "dev_legion_alpha"]
	], 4103)
	var looked_card_id := str(state.get_player(1).deck.cards[0])
	state.pending_choices = [{
		"choice_id": "choice_test_private",
		"player_id": 1,
		"type": "candidate_cards_pick",
		"operation": "search_pick",
		"title": "选择一张加入手牌",
		"count": 1,
		"candidate_card_ids": [looked_card_id],
		"looked_cards": [looked_card_id],
		"context": {
			"card_id": looked_card_id
		},
		"options": []
	}]
	var builder := ObservationBuilder.new()
	var viewer_zero_observation := builder.build(engine, state, 0)
	var viewer_one_observation := builder.build(engine, state, 1)
	var hidden_choice = viewer_zero_observation.get("pending_choice", {})
	var owner_choice = viewer_one_observation.get("pending_choice", {})
	_expect(hidden_choice.get("candidate_card_ids", null) == null, "observation: non-owner should not see pending choice candidate_card_ids", failures)
	_expect(hidden_choice.get("looked_cards", null) == null, "observation: non-owner should not see looked_cards", failures)
	_expect(owner_choice.get("candidate_card_ids", []) is Array and owner_choice.get("candidate_card_ids", []).size() == 1, "observation: choice owner should see candidate_card_ids", failures)
	_expect(owner_choice.get("looked_cards", []) is Array and owner_choice.get("looked_cards", []).size() == 1, "observation: choice owner should see looked_cards", failures)
	if owner_choice.get("looked_cards", []) is Array and not owner_choice.get("looked_cards", []).is_empty():
		_expect(not str(owner_choice.get("looked_cards", [])[0].get("definition_id", "")).is_empty(), "observation: choice owner should see looked card definition", failures)

static func _test_revealed_cards_to_opponent_visible_only_to_target_viewer(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["dev_legion_alpha", "qa_plain", "qa_ranged", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged"],
		["asgard_s01_0307", "qa_plain", "qa_ranged", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged"]
	], 4104)
	var revealed_card_id := str(state.get_player(0).hand.cards[0])
	var reveal_event = GameEvent.create(state.next_event_id(), "CardsRevealedToOpponent", 1, {
		"revealing_player_id": 0,
		"title": "向对方展示的卡牌",
		"card_ids": [revealed_card_id]
	})
	state.event_log.append(reveal_event)
	var builder := ObservationBuilder.new()
	var viewer_zero_observation := builder.build(engine, state, 0)
	var viewer_one_observation := builder.build(engine, state, 1)
	var self_side_events = viewer_zero_observation.get("recent_events", [])
	var opponent_side_events = viewer_one_observation.get("recent_events", [])
	var self_side_reveals = viewer_zero_observation.get("public_reveals", [])
	var opponent_side_reveals = viewer_one_observation.get("public_reveals", [])
	_expect(self_side_events is Array and not self_side_events.is_empty(), "observation: revealing player should still receive recent reveal event", failures)
	_expect(opponent_side_events is Array and not opponent_side_events.is_empty(), "observation: target opponent should receive recent reveal event", failures)
	_expect(self_side_reveals is Array and self_side_reveals.is_empty(), "observation: revealing player should not receive public_reveals entry for opponent-only reveal", failures)
	_expect(opponent_side_reveals is Array and opponent_side_reveals.size() == 1, "observation: target opponent should receive one public_reveals entry", failures)
	if self_side_events is Array and not self_side_events.is_empty():
		var self_event: Dictionary = self_side_events[self_side_events.size() - 1]
		_expect(self_event.get("revealed_cards", null) == null, "observation: revealing player should not receive revealed_cards payload for opponent-only reveal", failures)
	if opponent_side_events is Array and not opponent_side_events.is_empty():
		var opponent_event: Dictionary = opponent_side_events[opponent_side_events.size() - 1]
		var revealed_cards = opponent_event.get("revealed_cards", [])
		_expect(revealed_cards is Array and revealed_cards.size() == 1, "observation: target opponent should receive revealed_cards payload", failures)
		if revealed_cards is Array and not revealed_cards.is_empty():
			_expect(str(revealed_cards[0].get("definition_id", "")) == str(state.card_instances.get(revealed_card_id).definition_id), "observation: target opponent should receive the revealed card definition", failures)
	if opponent_side_reveals is Array and not opponent_side_reveals.is_empty():
		var reveal_summary: Dictionary = opponent_side_reveals[0]
		var summary_cards = reveal_summary.get("revealed_cards", [])
		_expect(str(reveal_summary.get("type", "")) == "CardsRevealedToOpponent", "observation: opponent-only public_reveals entry should keep event type", failures)
		_expect(summary_cards is Array and summary_cards.size() == 1, "observation: opponent-only public_reveals entry should expose one revealed card", failures)


static func _test_revealed_cards_to_all_visible_to_both_viewers(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(CardDatabase.load_definitions(), [
		["dev_legion_alpha", "qa_plain", "qa_ranged", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged"],
		["asgard_s01_0307", "qa_plain", "qa_ranged", "qa_trial", "dev_legion_beta", "qa_plain", "qa_ranged"]
	], 4105)
	var revealed_card_id := str(state.get_player(1).hand.cards[0])
	var reveal_event = GameEvent.create(state.next_event_id(), "CardsRevealedToAll", 1, {
		"revealing_player_id": 1,
		"title": "展示的卡牌",
		"card_ids": [revealed_card_id]
	})
	state.event_log.append(reveal_event)
	var builder := ObservationBuilder.new()
	for viewer_player_id in [0, 1]:
		var observation := builder.build(engine, state, viewer_player_id)
		var recent_events = observation.get("recent_events", [])
		var public_reveals = observation.get("public_reveals", [])
		_expect(recent_events is Array and not recent_events.is_empty(), "observation: all-viewers reveal should appear in recent events", failures)
		_expect(public_reveals is Array and public_reveals.size() == 1, "observation: all-viewers reveal should appear in public_reveals", failures)
		if recent_events is Array and not recent_events.is_empty():
			var event_view: Dictionary = recent_events[recent_events.size() - 1]
			var revealed_cards = event_view.get("revealed_cards", [])
			_expect(revealed_cards is Array and revealed_cards.size() == 1, "observation: all-viewers reveal should expose revealed_cards to both viewers", failures)
			if revealed_cards is Array and not revealed_cards.is_empty():
				_expect(str(revealed_cards[0].get("definition_id", "")) == str(state.card_instances.get(revealed_card_id).definition_id), "observation: all-viewers reveal should expose the revealed card definition", failures)
		if public_reveals is Array and not public_reveals.is_empty():
			var reveal_summary: Dictionary = public_reveals[0]
			var summary_cards = reveal_summary.get("revealed_cards", [])
			_expect(str(reveal_summary.get("type", "")) == "CardsRevealedToAll", "observation: all-viewers public_reveals entry should keep event type", failures)
			_expect(summary_cards is Array and summary_cards.size() == 1, "observation: all-viewers public_reveals entry should expose one revealed card", failures)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
