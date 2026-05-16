extends RefCounted
class_name TestTacticPlay

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_tactic_enters_stack_and_resolves_to_grave(failures)
	_test_tactic_without_target_resolves(failures)
	_test_tactic_deferred_option_choice_keeps_state_valid(failures)
	_test_tactic_can_target_master(failures)
	_test_tactic_can_choose_between_multiple_effects(failures)
	_test_tactic_search_can_request_choice_and_resolve(failures)
	_test_dawn_multi_mode_tactic_can_chain_into_search_choice(failures)
	_test_multi_mode_tactic_can_chain_into_search_choice(failures)
	return failures

static func _test_tactic_enters_stack_and_resolves_to_grave(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 920)
	var tactic_id = _find_hand_card_by_definition(state, 0, "dev_tactic_bolt")
	_expect(tactic_id != "", "tactic should be in opening hand", failures)
	var target_id = _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(target_id != "", "target legion should be in opening hand", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for tactic setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for tactic setup")
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "target legion play should succeed", failures)
	var target_instance_id = state.players[1].battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for tactic cast should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for tactic cast")
		return
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"target_card_id": target_instance_id
	}))
	_expect(cast_result.ok, "tactic cast should succeed", failures)
	_expect(state.stack.size() == 1, "tactic should put one stack item on the stack", failures)
	_expect(state.priority_player == 1, "priority should move to opponent after tactic cast", failures)
	var tactic_instance = state.card_instances.get(tactic_id)
	_expect(tactic_instance != null and tactic_instance.zone == "stack_pending", "tactic should wait in stack_pending before resolution", failures)
	_expect(_has_event_type(state, "CardPlayed"), "tactic cast should log CardPlayed", failures)
	_expect(_has_event_type(state, "EffectPutOnStack"), "tactic cast should log EffectPutOnStack", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "tactic first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "tactic second pass should resolve", failures)
	_expect(state.stack.is_empty(), "tactic stack should resolve after two passes", failures)
	_expect(state.players[1].battle_front[0].occupant == "", "tactic damage should remove lethal target", failures)
	_expect(state.players[1].grave.cards.has(target_instance_id), "tactic target should move to grave", failures)
	_expect(state.players[0].grave.cards.has(tactic_id), "resolved tactic should move to grave", failures)
	_expect(tactic_instance != null and tactic_instance.zone == "grave", "tactic instance zone should become grave after resolution", failures)
	_expect(_has_event_type(state, "EffectResolved"), "tactic should log EffectResolved", failures)
	_expect(_has_event_type(state, "CardSentToGrave"), "tactic resolution should log CardSentToGrave", failures)

static func _test_tactic_without_target_resolves(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _no_target_decks(), 921)
	var tactic_id = _find_hand_card_by_definition(state, 0, "dev_tactic_rally")
	_expect(tactic_id != "", "no-target tactic should be in opening hand", failures)
	var legal_targets = engine.get_legal_tactic_targets(state, 0, tactic_id)
	_expect(legal_targets.size() == 1, "no-target tactic should expose one cast entry", failures)
	_expect(str(legal_targets[0].get("target_kind", "")) == "none", "no-target tactic should expose none target kind", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	var deck_before = state.get_player(0).deck.cards.size()
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(cast_result.ok, "no-target tactic cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "no-target tactic first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "no-target tactic second pass should resolve", failures)
	_expect(state.players[0].grave.cards.has(tactic_id), "resolved no-target tactic should move to grave", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 1, "no-target tactic should draw one card", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "no-target tactic should restore hand size after drawing", failures)
	_expect(_has_event_type(state, "CardDrawn"), "no-target tactic should log CardDrawn", failures)

static func _test_tactic_deferred_option_choice_keeps_state_valid(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _truce_decks(), 928, [], {
		"mode": "formal",
		"shuffle_player_decks": false
	})
	var tactic_id = _find_hand_card_by_definition(state, 0, "neutral_s01_0015")
	_expect(tactic_id != "", "truce tactic should be in opening hand", failures)
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "truce_offer"
	}))
	_expect(cast_result.ok, "truce tactic cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "truce tactic first pass should succeed", failures)
	var resolve_stack_result = engine.apply_command(state, GameCommand.create(0, "PassPriority"))
	_expect(resolve_stack_result.ok, "truce tactic second pass should open the option choice without invalidating state", failures)
	_expect(state.pending_choices.size() == 1, "truce tactic should create one pending option choice", failures)
	var tactic_instance = state.card_instances.get(tactic_id)
	_expect(tactic_instance != null and tactic_instance.zone == "stack_pending", "truce tactic should stay referenced while its option choice is pending", failures)
	var choice = state.pending_choices[0]
	var choice_result = engine.apply_command(state, GameCommand.create(1, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": "agree"
	}))
	_expect(choice_result.ok, "truce option choice should resolve without leaving an orphan tactic", failures)
	_expect(state.pending_choices.is_empty(), "truce option choice should clear pending choices", failures)
	_expect(state.get_player(0).grave.cards.has(tactic_id), "truce tactic should move to grave after its deferred choice resolves", failures)
	_expect(tactic_instance != null and tactic_instance.zone == "grave", "truce tactic instance zone should become grave after deferred choice", failures)

static func _test_tactic_can_target_master(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _master_target_decks(), 922)
	var tactic_id = _find_hand_card_by_definition(state, 0, "dev_tactic_smite")
	_expect(tactic_id != "", "master-target tactic should be in opening hand", failures)
	var legal_targets = engine.get_legal_tactic_targets(state, 0, tactic_id)
	_expect(legal_targets.size() == 1, "master-target tactic should expose one master target", failures)
	_expect(str(legal_targets[0].get("target_kind", "")) == "master", "master-target tactic should expose master target kind", failures)
	_expect(int(legal_targets[0].get("target_player", -1)) == 1, "master-target tactic should target enemy master", failures)
	var hp_before = state.players[1].master_hp
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"target_player": 1
	}))
	_expect(cast_result.ok, "master-target tactic cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "master-target tactic first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "master-target tactic second pass should resolve", failures)
	_expect(state.players[1].master_hp == hp_before - 2, "master-target tactic should damage enemy master", failures)
	_expect(state.players[0].grave.cards.has(tactic_id), "resolved master-target tactic should move to grave", failures)
	_expect(_has_event_type(state, "MasterDamaged"), "master-target tactic should log MasterDamaged", failures)

static func _test_tactic_can_choose_between_multiple_effects(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _multi_mode_decks(), 923)
	var tactic_id = _find_hand_card_by_definition(state, 0, "demo_twin_command")
	_expect(tactic_id != "", "multi-mode tactic should be in opening hand", failures)
	var castable_effects = engine.get_castable_tactic_effects(state, 0, tactic_id)
	_expect(castable_effects.size() == 2, "multi-mode tactic should expose two castable effects", failures)
	var draw_targets = engine.get_legal_tactic_targets(state, 0, tactic_id, "command_draw")
	_expect(draw_targets.size() == 1 and str(draw_targets[0].get("target_kind", "")) == "none", "draw mode should expose no-target cast entry", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	var deck_before = state.get_player(0).deck.cards.size()
	var draw_cast = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "command_draw"
	}))
	_expect(draw_cast.ok, "multi-mode tactic draw cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "multi-mode draw first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "multi-mode draw second pass should resolve", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 1, "draw mode should reduce deck by one", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "draw mode should restore hand size", failures)

	var engine2 = GameEngine.new()
	var state2 = engine2.create_game(_definitions(), _multi_mode_damage_decks(), 924)
	var tactic_id2 = _find_hand_card_by_definition(state2, 0, "demo_twin_command")
	var target_id = _find_hand_card_by_definition(state2, 1, "dev_legion_beta")
	_expect(tactic_id2 != "", "multi-mode tactic should be in opening hand for damage test", failures)
	_expect(target_id != "", "damage target legion should be in opening hand", failures)
	_advance_to_next_main(engine2, state2, failures, "advance to player 2 main for multi-mode target setup should succeed")
	if state2.active_player != 1 or state2.phase != "main":
		failures.append("player 2 main phase was not reached for multi-mode target setup")
		return
	_expect(engine2.apply_command(state2, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "multi-mode target legion play should succeed", failures)
	var target_instance_id = state2.players[1].battle_front[0].occupant
	_advance_to_next_main(engine2, state2, failures, "advance back to player 1 main for multi-mode cast should succeed")
	if state2.active_player != 0 or state2.phase != "main":
		failures.append("player 1 main phase was not reached for multi-mode cast")
		return
	var damage_targets = engine2.get_legal_tactic_targets(state2, 0, tactic_id2, "command_bolt")
	_expect(damage_targets.size() >= 1, "damage mode should expose at least one target", failures)
	var damage_cast = engine2.apply_command(state2, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id2,
		"row": "tactic",
		"col": -1,
		"effect_id": "command_bolt",
		"target_card_id": target_instance_id
	}))
	_expect(damage_cast.ok, "multi-mode tactic damage cast should succeed", failures)
	_expect(engine2.apply_command(state2, GameCommand.create(1, "PassPriority")).ok, "multi-mode damage first pass should succeed", failures)
	_expect(engine2.apply_command(state2, GameCommand.create(0, "PassPriority")).ok, "multi-mode damage second pass should resolve", failures)
	_expect(state2.players[1].battle_front[0].occupant == "", "damage mode should destroy the target unit", failures)
	_expect(_has_event_type(state2, "CardDamaged"), "damage mode should log CardDamaged", failures)

static func _test_tactic_search_can_request_choice_and_resolve(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _search_choice_tactic_decks(), 925)
	var tactic_id = _find_hand_card_by_definition(state, 0, "demo_pathfinder_orders")
	_expect(tactic_id != "", "search tactic should be in opening hand", failures)
	var targets = engine.get_legal_tactic_targets(state, 0, tactic_id)
	_expect(targets.size() == 1 and str(targets[0].get("target_kind", "")) == "none", "search tactic should expose no-target cast entry", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	var deck_before = state.get_player(0).deck.cards.size()
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1
	}))
	_expect(cast_result.ok, "search tactic cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "search tactic first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "search tactic second pass should resolve into choice", failures)
	_expect(state.pending_choices.size() == 1, "search tactic should create one pending choice", failures)
	var choice = state.pending_choices[0]
	var candidates = choice.get("candidate_card_ids", [])
	_expect(candidates is Array and candidates.size() >= 2, "search tactic should expose multiple Dawn candidates", failures)
	var selected_card_id = str(candidates[1])
	var selected_instance = state.card_instances.get(selected_card_id)
	_expect(selected_instance != null, "selected search candidate should exist", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": [selected_card_id]
	})).ok, "search tactic choice resolution should succeed", failures)
	_expect(state.pending_choices.is_empty(), "resolving search tactic choice should clear pending choices", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "search tactic should restore hand size after tutoring", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 1, "search tactic should remove one selected card from deck", failures)
	_expect(state.get_player(0).hand.cards.has(selected_card_id), "search tactic should add selected Dawn card to hand", failures)
	_expect(selected_instance != null and selected_instance.definition_id == "demo_breakthrough_knight", "search tactic should be able to take the chosen Dawn unit", failures)
	_expect(_has_event_type(state, "ChoiceRequested"), "search tactic should log ChoiceRequested", failures)
	_expect(_has_event_type(state, "ChoiceResolved"), "search tactic should log ChoiceResolved", failures)

static func _test_dawn_multi_mode_tactic_can_chain_into_search_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _sunmarch_decks(), 926)
	var tactic_id = _find_hand_card_by_definition(state, 0, "demo_sunmarch_decree")
	_expect(tactic_id != "", "sunmarch decree should be in opening hand", failures)
	var effects = engine.get_castable_tactic_effects(state, 0, tactic_id)
	_expect(effects.size() == 2, "sunmarch decree should expose two castable effects", failures)
	var search_targets = engine.get_legal_tactic_targets(state, 0, tactic_id, "sunmarch_search")
	_expect(search_targets.size() == 1 and str(search_targets[0].get("target_kind", "")) == "none", "sunmarch search mode should expose no-target cast entry", failures)
	var strike_targets = engine.get_legal_tactic_targets(state, 0, tactic_id, "sunmarch_strike")
	_expect(strike_targets.size() == 1 and str(strike_targets[0].get("target_kind", "")) == "master", "sunmarch strike mode should expose enemy master target", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	var deck_before = state.get_player(0).deck.cards.size()
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "sunmarch_search"
	}))
	_expect(cast_result.ok, "sunmarch search cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "sunmarch first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "sunmarch second pass should resolve into choice", failures)
	_expect(state.pending_choices.size() == 1, "sunmarch should create one pending choice", failures)
	var choice = state.pending_choices[0]
	var candidates = choice.get("candidate_card_ids", [])
	_expect(candidates is Array and candidates.size() >= 2, "sunmarch should expose multiple Dawn candidates", failures)
	var selected_card_id = str(candidates[1])
	var selected_instance = state.card_instances.get(selected_card_id)
	_expect(selected_instance != null, "sunmarch chosen candidate should exist", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": [selected_card_id]
	})).ok, "sunmarch choice resolution should succeed", failures)
	_expect(state.pending_choices.is_empty(), "sunmarch should clear pending choice after selection", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "sunmarch should restore hand size after tutoring", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 1, "sunmarch should remove one selected card from deck", failures)
	_expect(state.get_player(0).hand.cards.has(selected_card_id), "sunmarch should add selected Dawn card to hand", failures)
	_expect(selected_instance != null and selected_instance.definition_id == "demo_breakthrough_knight", "sunmarch should be able to tutor the chosen Dawn unit", failures)
	_expect(_has_event_type(state, "ChoiceRequested"), "sunmarch should log ChoiceRequested", failures)
	_expect(_has_event_type(state, "ChoiceResolved"), "sunmarch should log ChoiceResolved", failures)

static func _test_multi_mode_tactic_can_chain_into_search_choice(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), _veil_doctrine_decks(), 927)
	var tactic_id = _find_hand_card_by_definition(state, 0, "demo_veil_doctrine")
	_expect(tactic_id != "", "veil doctrine should be in opening hand", failures)
	var effects = engine.get_castable_tactic_effects(state, 0, tactic_id)
	_expect(effects.size() == 2, "veil doctrine should expose two castable effects", failures)
	var search_targets = engine.get_legal_tactic_targets(state, 0, tactic_id, "doctrine_search")
	_expect(search_targets.size() == 1 and str(search_targets[0].get("target_kind", "")) == "none", "veil doctrine search mode should expose no-target cast entry", failures)
	var hand_before = state.get_player(0).hand.cards.size()
	var deck_before = state.get_player(0).deck.cards.size()
	var cast_result = engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tactic_id,
		"row": "tactic",
		"col": -1,
		"effect_id": "doctrine_search"
	}))
	_expect(cast_result.ok, "veil doctrine search cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "veil doctrine first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "veil doctrine second pass should resolve into choice", failures)
	_expect(state.pending_choices.size() == 1, "veil doctrine should create one pending choice", failures)
	var choice = state.pending_choices[0]
	var candidates = choice.get("candidate_card_ids", [])
	_expect(candidates is Array and candidates.size() >= 2, "veil doctrine should expose multiple Veil candidates", failures)
	var selected_card_id = str(candidates[1])
	var selected_instance = state.card_instances.get(selected_card_id)
	_expect(selected_instance != null, "veil doctrine chosen candidate should exist", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_card_ids": [selected_card_id]
	})).ok, "veil doctrine choice resolution should succeed", failures)
	_expect(state.pending_choices.is_empty(), "veil doctrine should clear pending choice after selection", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "veil doctrine should restore hand size after tutoring", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before - 1, "veil doctrine should remove one selected card from deck", failures)
	_expect(state.get_player(0).hand.cards.has(selected_card_id), "veil doctrine should add selected Veil card to hand", failures)
	_expect(selected_instance != null and selected_instance.definition_id == "demo_exile_magus", "veil doctrine should be able to tutor the chosen Veil unit", failures)
	_expect(_has_event_type(state, "ChoiceRequested"), "veil doctrine should log ChoiceRequested", failures)
	_expect(_has_event_type(state, "ChoiceResolved"), "veil doctrine should log ChoiceResolved", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_tactic_bolt", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _no_target_decks() -> Array:
	return [
		["dev_tactic_rally", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _master_target_decks() -> Array:
	return [
		["dev_tactic_smite", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _truce_decks() -> Array:
	return [
		["neutral_s01_0015", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _multi_mode_decks() -> Array:
	return [
		["demo_twin_command", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _multi_mode_damage_decks() -> Array:
	return [
		["demo_twin_command", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _search_choice_tactic_decks() -> Array:
	return [
		["demo_pathfinder_orders", "demo_lens_relay", "demo_lens_relay", "demo_rally_signal", "demo_twin_command", "demo_vanguard_raider", "demo_breakthrough_knight", "demo_banner_captain", "demo_lens_relay", "demo_final_decree"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _sunmarch_decks() -> Array:
	return [
		["demo_sunmarch_decree", "demo_pathfinder_orders", "demo_lens_relay", "demo_rally_signal", "demo_twin_command", "demo_vanguard_raider", "demo_breakthrough_knight", "demo_banner_captain", "demo_lens_relay", "demo_final_decree"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _veil_doctrine_decks() -> Array:
	return [
		["demo_veil_doctrine", "demo_null_field", "demo_null_field", "demo_recon_order", "demo_lens_relay", "demo_warden_of_ashes", "demo_exile_magus", "demo_field_scholar", "demo_lens_relay", "demo_shock_barrage"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
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
