extends RefCounted
class_name TestCommonEffectActions

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_destroy_target_unit_effect(failures)
	_test_discard_cards_effect(failures)
	_test_deal_master_damage_effect(failures)
	_test_deal_legion_damage_effect(failures)
	_test_mill_cards_effect(failures)
	_test_return_target_unit_to_hand_effect(failures)
	_test_search_deck_effect(failures)
	_test_search_deck_choice_effect(failures)
	return failures

static func _test_destroy_target_unit_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _destroy_decks(), 901)
	var executioner_id = _find_hand_card_by_definition(state, 0, "qa_executioner")
	_expect(executioner_id != "", "destroy source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": executioner_id,
		"row": "front",
		"col": 0
	})).ok, "destroy source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for destroy setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for destroy setup")
		return
	var target_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(target_id != "", "destroy target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "destroy target play should succeed", failures)
	var target_instance_id = state.players[1].battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for destroy activation should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for destroy activation")
		return
	var activate_result = engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": executioner_id,
		"effect_id": "destroy_unit",
		"target_card_id": target_instance_id
	}))
	_expect(activate_result.ok, "destroy effect activation should succeed", failures)
	_expect(state.stack.size() == 1, "destroy effect should enter stack", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "destroy first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "destroy second pass should resolve", failures)
	_expect(state.players[1].battle_front[0].occupant == "", "destroy effect should clear the target battlefield slot", failures)
	_expect(state.players[1].grave.cards.has(target_instance_id), "destroyed unit should move to grave", failures)
	_expect(_has_event_type(state, "CardDied"), "destroy effect should log CardDied", failures)

static func _test_discard_cards_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _discard_decks(), 902)
	var disruptor_id = _find_hand_card_by_definition(state, 0, "qa_disruptor")
	_expect(disruptor_id != "", "discard source should be in opening hand", failures)
	var hand_before_play = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": disruptor_id,
		"row": "front",
		"col": 0
	})).ok, "discard source play should succeed", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_play - 1, "playing discard source should reduce hand by one", failures)
	var hand_before_effect = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": disruptor_id,
		"effect_id": "discard_one"
	})).ok, "discard effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "discard first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "discard second pass should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_effect - 1, "discard effect should reduce hand by one", failures)
	_expect(state.get_player(0).grave.cards.size() == 1, "discarded card should move to grave", failures)
	_expect(_has_event_type(state, "CardDiscarded"), "discard effect should log CardDiscarded", failures)

static func _test_deal_master_damage_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _master_damage_decks(), 903)
	var firebolt_id = _find_hand_card_by_definition(state, 0, "qa_firebolt")
	_expect(firebolt_id != "", "master damage source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": firebolt_id,
		"row": "front",
		"col": 0
	})).ok, "master damage source play should succeed", failures)
	var hp_before = state.players[1].master_hp
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": firebolt_id,
		"effect_id": "burn_master"
	})).ok, "master damage effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "master damage first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "master damage second pass should resolve", failures)
	_expect(state.players[1].master_hp == hp_before - 2, "master damage effect should reduce enemy master hp by 2", failures)
	_expect(_has_event_type(state, "MasterDamaged"), "master damage effect should log MasterDamaged", failures)

static func _test_deal_legion_damage_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _legion_damage_decks(), 904)
	var marksman_id = _find_hand_card_by_definition(state, 0, "qa_marksman")
	_expect(marksman_id != "", "legion damage source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": marksman_id,
		"row": "front",
		"col": 0
	})).ok, "legion damage source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for legion damage setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for legion damage setup")
		return
	var target_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(target_id != "", "legion damage target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "legion damage target play should succeed", failures)
	var target_instance_id = state.players[1].battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for legion damage activation should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for legion damage activation")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": marksman_id,
		"effect_id": "ping_unit",
		"target_card_id": target_instance_id
	})).ok, "legion damage effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "legion damage first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "legion damage second pass should resolve", failures)
	_expect(state.players[1].battle_front[0].occupant == "", "legion damage effect should remove lethal target from battlefield", failures)
	_expect(state.players[1].grave.cards.has(target_instance_id), "lethal legion damage target should move to grave", failures)
	_expect(_has_event_type(state, "CardDamaged"), "legion damage effect should log CardDamaged", failures)

static func _test_mill_cards_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _mill_decks(), 905)
	var miller_id = _find_hand_card_by_definition(state, 0, "qa_miller")
	_expect(miller_id != "", "mill source should be in opening hand", failures)
	var deck_before_play = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": miller_id,
		"row": "front",
		"col": 0
	})).ok, "mill source play should succeed", failures)
	var deck_before_effect = state.get_player(0).deck.cards.size()
	_expect(deck_before_effect == deck_before_play, "playing mill source should not change deck size", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": miller_id,
		"effect_id": "mill_two"
	})).ok, "mill effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "mill first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "mill second pass should resolve", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before_effect - 2, "mill effect should reduce deck size by two", failures)
	_expect(state.get_player(0).grave.cards.size() == 2, "mill effect should move two cards to grave", failures)
	_expect(_has_event_type(state, "CardMilled"), "mill effect should log CardMilled", failures)

static func _test_return_target_unit_to_hand_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _bounce_decks(), 906)
	var bouncer_id = _find_hand_card_by_definition(state, 0, "qa_bouncer")
	_expect(bouncer_id != "", "bounce source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": bouncer_id,
		"row": "front",
		"col": 0
	})).ok, "bounce source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for bounce setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for bounce setup")
		return
	var target_definition_id = "qa_plain"
	var target_id = _find_hand_card_by_definition(state, 1, target_definition_id)
	_expect(target_id != "", "bounce target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "bounce target play should succeed", failures)
	var target_instance_id = state.players[1].battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for bounce activation should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for bounce activation")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": bouncer_id,
		"effect_id": "bounce_unit",
		"target_card_id": target_instance_id
	})).ok, "bounce effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "bounce first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "bounce second pass should resolve", failures)
	_expect(state.players[1].battle_front[0].occupant == "", "bounce effect should clear the target battlefield slot", failures)
	_expect(state.players[1].hand.cards.has(target_instance_id), "bounced unit should return to owner's hand", failures)
	var bounced_instance = state.card_instances.get(target_instance_id)
	_expect(bounced_instance != null and bounced_instance.zone == "hand", "bounced unit instance should now be in hand", failures)
	_expect(bounced_instance != null and int(bounced_instance.damage_marked) == 0, "bounced unit should clear marked damage", failures)
	_expect(_has_event_type(state, "CardReturnedToHand"), "bounce effect should log CardReturnedToHand", failures)

static func _test_search_deck_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _search_decks(), 907)
	var scout_id = _find_hand_card_by_definition(state, 0, "qa_scout")
	_expect(scout_id != "", "search source should be in opening hand", failures)
	var hand_before_play = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": scout_id,
		"row": "front",
		"col": 0
	})).ok, "search source play should succeed", failures)
	var hand_before_effect = state.get_player(0).hand.cards.size()
	var deck_before_effect = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": scout_id,
		"effect_id": "search_legion"
	})).ok, "search effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "search first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "search second pass should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_effect + 1, "search effect should add one card to hand", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before_effect - 1, "search effect should remove the tutored card from deck", failures)
	var tutored_card_id = state.get_player(0).hand.cards.back()
	var tutored_instance = state.card_instances.get(tutored_card_id)
	_expect(tutored_instance != null and tutored_instance.definition_id == "qa_plain", "search effect should tutor the first matching legion from the looked cards", failures)
	_expect(_has_event_type(state, "DeckSearched"), "search effect should log DeckSearched", failures)
	_expect(_has_event_type(state, "CardTutored"), "search effect should log CardTutored", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_play, "search effect should restore hand size after the source leaves hand and a card is tutored", failures)
	_expect(state.pending_choices.is_empty(), "single-match search should not leave pending choices", failures)

static func _test_search_deck_choice_effect(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _search_choice_decks(), 908)
	var scout_id = _find_hand_card_by_definition(state, 0, "qa_scout")
	_expect(scout_id != "", "search choice source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": scout_id,
		"row": "front",
		"col": 0
	})).ok, "search choice source play should succeed", failures)
	var hand_before_effect = state.get_player(0).hand.cards.size()
	var deck_before_effect = state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": scout_id,
		"effect_id": "search_legion"
	})).ok, "search choice effect activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "search choice first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "search choice second pass should resolve to pending choice", failures)
	_expect(state.pending_choices.size() == 1, "search choice should create one pending choice", failures)
	var choice = state.pending_choices[0]
	var candidates = choice.get("candidate_card_ids", [])
	_expect(candidates is Array and candidates.size() == 2, "search choice should expose two candidate cards", failures)
	var first_candidate = str(candidates[0])
	var second_candidate = str(candidates[1])
	_expect(first_candidate != "" and second_candidate != "" and first_candidate != second_candidate, "search choice candidates should be distinct cards", failures)
	_expect(not engine.apply_command(state, GameCommand.create(0, "EndPhase")).ok, "cannot advance phase while choice is pending", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": [second_candidate]
	})).ok, "resolving search choice should succeed", failures)
	_expect(state.pending_choices.is_empty(), "resolving search choice should clear pending choices", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_effect + 1, "resolved search choice should add selected card to hand", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before_effect - 1, "resolved search choice should remove exactly one deck card", failures)
	_expect(state.get_player(0).hand.cards.has(second_candidate), "resolved search choice should tutor the selected candidate", failures)
	_expect(not state.get_player(0).hand.cards.has(first_candidate), "resolved search choice should not tutor the unselected candidate", failures)
	_expect(_has_event_type(state, "ChoiceRequested"), "search choice should log ChoiceRequested", failures)
	_expect(_has_event_type(state, "ChoiceResolved"), "search choice should log ChoiceResolved", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _destroy_decks() -> Array:
	return [
		["qa_executioner", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _discard_decks() -> Array:
	return [
		["qa_disruptor", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _master_damage_decks() -> Array:
	return [
		["qa_firebolt", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _legion_damage_decks() -> Array:
	return [
		["qa_marksman", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _mill_decks() -> Array:
	return [
		["qa_miller", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _bounce_decks() -> Array:
	return [
		["qa_bouncer", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _search_decks() -> Array:
	return [
		["qa_scout", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_plain", "neutral_s01_0015"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _search_choice_decks() -> Array:
	return [
		["qa_scout", "qa_vanilla", "qa_plain", "qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	]

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
