extends RefCounted
class_name TestDemoDevRemainingCards

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_dawn_legions_keywords_and_aura(failures)
	_test_demo_artifact_and_basic_tactics(failures)
	_test_veil_search_and_counter(failures)
	_test_veil_legion_utility_effects(failures)
	return failures


static func _test_dawn_legions_keywords_and_aura(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["demo_breakthrough_knight", "demo_banner_captain", "demo_vanguard_raider", "demo_linebreaker_archer", "dev_legion_alpha", "dev_legion_alpha"],
		["demo_bastion_guard", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 980, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 4
	})
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for taunt setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for dawn keyword setup")
		return
	var taunt_id := _find_hand_card_by_definition(state, 1, "demo_bastion_guard")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": taunt_id,
		"row": "front",
		"col": 0
	})).ok, "taunt guard play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for dawn keyword test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for dawn keyword test")
		return
	var knight_id := _find_hand_card_by_definition(state, 0, "demo_breakthrough_knight")
	var captain_id := _find_hand_card_by_definition(state, 0, "demo_banner_captain")
	var raider_id := _find_hand_card_by_definition(state, 0, "demo_vanguard_raider")
	var archer_id := _find_hand_card_by_definition(state, 0, "demo_linebreaker_archer")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "dawn keyword setup should add one extra morale for the fourth deployment", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": captain_id,
		"row": "front",
		"col": 0
	})).ok, "banner captain play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": raider_id,
		"row": "front",
		"col": 1
	})).ok, "vanguard raider play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": knight_id,
		"row": "front",
		"col": 2
	})).ok, "breakthrough knight play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": archer_id,
		"row": "back",
		"col": 0
	})).ok, "linebreaker archer play should succeed", failures)
	var captain_instance_id := state.get_player(0).battle_front[0].occupant
	var raider_instance_id := state.get_player(0).battle_front[1].occupant
	var knight_instance_id := state.get_player(0).battle_front[2].occupant
	var archer_instance_id := state.get_player(0).battle_back[0].occupant
	var taunt_instance_id := state.get_player(1).battle_front[0].occupant
	_expect(engine.get_card_power(state, raider_instance_id) == 4000, "banner captain should grant +1000 power to other allied units", failures)
	_expect(engine.get_card_power(state, knight_instance_id) == 4000, "banner captain should buff breakthrough knight too", failures)
	var knight_targets = engine.get_legal_attack_targets(state, knight_instance_id)
	_expect(_targets_include_card(knight_targets, taunt_instance_id), "breakthrough knight charge should allow attacking on the turn it enters", failures)
	_expect(knight_targets.size() == 1, "enemy taunt should force the charged knight to attack only the taunt unit", failures)
	var archer_targets = engine.get_legal_attack_targets(state, archer_instance_id)
	_expect(archer_targets.is_empty(), "linebreaker archer should still wait a turn before attacking because it has ranged but not charge", failures)
	_expect(str(state.card_instances.get(raider_instance_id).definition_id) == "demo_vanguard_raider", "vanguard raider should remain a normal deployed front unit", failures)
	_expect(str(state.card_instances.get(captain_instance_id).definition_id) == "demo_banner_captain", "banner captain should remain on battlefield as aura source", failures)


static func _test_demo_artifact_and_basic_tactics(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["demo_lens_relay", "demo_rally_signal", "demo_shock_barrage", "demo_final_decree", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 981, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 4
	})
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for tactic target setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for demo tactic setup")
		return
	var target_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": target_id,
		"row": "front",
		"col": 0
	})).ok, "enemy target unit play should succeed", failures)
	var target_instance_id := state.get_player(1).battle_front[0].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for demo tactics should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for demo tactics")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "demo tactics setup should add extra morale for the artifact, activation and three tactics", failures)
	var artifact_id := _find_hand_card_by_definition(state, 0, "demo_lens_relay")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "demo lens relay play should succeed", failures)
	var hand_before := state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": artifact_id,
		"effect_id": "relay_draw"
	})).ok, "demo lens relay activation should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo lens relay first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo lens relay second pass should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before + 1, "demo lens relay should draw one card", failures)
	var rally_id := _find_hand_card_by_definition(state, 0, "demo_rally_signal")
	var deck_before_rally := state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": rally_id,
		"row": "tactic",
		"col": -1
	})).ok, "demo rally signal cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo rally signal first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo rally signal second pass should resolve", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before_rally - 1, "demo rally signal should draw one card", failures)
	var barrage_id := _find_hand_card_by_definition(state, 0, "demo_shock_barrage")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": barrage_id,
		"row": "tactic",
		"col": -1,
		"target_card_id": target_instance_id
	})).ok, "demo shock barrage cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo shock barrage first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo shock barrage second pass should resolve", failures)
	_expect(state.get_player(1).battle_front[0].occupant == "", "demo shock barrage should destroy the 2000-power target", failures)
	var decree_id := _find_hand_card_by_definition(state, 0, "demo_final_decree")
	var hp_before := state.get_player(1).master_hp
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": decree_id,
		"row": "tactic",
		"col": -1,
		"target_player": 1
	})).ok, "demo final decree cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo final decree first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo final decree second pass should resolve", failures)
	_expect(state.get_player(1).master_hp == hp_before - 2, "demo final decree should deal 2 damage to enemy master", failures)


static func _test_veil_search_and_counter(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["demo_recon_order", "demo_null_field", "dev_legion_alpha", "demo_exile_magus", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_tactic_rally", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 982, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 2
	})
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "demo veil setup should add one extra morale for recon order plus a set counter tactic", failures)
	var counter_id := _find_hand_card_by_definition(state, 0, "demo_null_field")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": counter_id,
		"row": "back",
		"col": 0
	})).ok, "demo null field should be set face-down before the response window", failures)
	var exile_in_hand_before := _find_hand_card_by_definition(state, 0, "demo_exile_magus")
	_expect(exile_in_hand_before.is_empty(), "demo recon order setup should leave exile magus in the deck", failures)
	var recon_id := _find_hand_card_by_definition(state, 0, "demo_recon_order")
	var hand_before_recon := state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": recon_id,
		"row": "tactic",
		"col": -1
	})).ok, "demo recon order cast should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo recon order first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo recon order second pass should resolve into choice", failures)
	_expect(state.pending_choices.is_empty(), "demo recon order should resolve immediately when only one Veil legion is found", failures)
	var tutored_exile_id := _find_hand_card_by_definition(state, 0, "demo_exile_magus")
	_expect(not tutored_exile_id.is_empty(), "demo recon order should tutor exile magus directly into hand", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_recon, "demo recon order should replace itself with the tutored card when no search choice is needed", failures)
	if tutored_exile_id.is_empty():
		return
	var selected_instance = state.card_instances.get(tutored_exile_id)
	_expect(selected_instance != null and selected_instance.definition_id == "demo_exile_magus", "demo recon order should tutor a Legion Veil unit", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for demo null field setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for demo null field setup")
		return
	var enemy_tactic_id := _find_hand_card_by_definition(state, 1, "dev_tactic_rally")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_tactic_id,
		"row": "tactic",
		"col": -1
	})).ok, "enemy tactic cast for demo null field should succeed", failures)
	var set_counter_instance_id := state.get_player(0).battle_back[0].occupant
	var target_stack_id := str(state.stack[0].get("stack_id", ""))
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": set_counter_instance_id,
		"effect_id": "nullify_stack",
		"target_stack_id": target_stack_id
	})).ok, "demo null field should counter the enemy stack item from its set position", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo null field first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo null field second pass should resolve", failures)
	_expect(state.stack.is_empty(), "demo null field should clear the stack after countering", failures)
	_expect(_has_event_type(state, "EffectCountered"), "demo null field should emit EffectCountered", failures)


static func _test_veil_legion_utility_effects(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var definitions = _definitions()
	definitions.append({
		"id": "qa_demo_victim",
		"name": "暮纱受害者",
		"faction": "neutral",
		"type": "legion",
		"cost": 1,
		"power": 1000,
		"hp": 1000,
		"keywords": [],
		"effects": [],
		"text": "用于测试 demo 剩余军团"
	})
	var state = engine.create_game(definitions, [
		["demo_warden_of_ashes", "demo_exile_magus", "demo_sanctioner", "demo_field_scholar", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["qa_demo_victim", "qa_demo_victim", "qa_demo_victim", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 983, [], {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": 4
	})
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for demo utility targets should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for demo utility target setup")
		return
	var victim_a := _find_hand_card_by_definition(state, 1, "qa_demo_victim")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": victim_a,
		"row": "front",
		"col": 0
	})).ok, "first demo utility victim should enter battlefield", failures)
	var victim_b := _find_hand_card_by_definition(state, 1, "qa_demo_victim")
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": victim_b,
		"row": "front",
		"col": 1
	})).ok, "second demo utility victim should enter battlefield", failures)
	var victim_instance_a := state.get_player(1).battle_front[0].occupant
	var victim_instance_b := state.get_player(1).battle_front[1].occupant
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for demo utility effects should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for demo utility effects")
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "demo utility setup should add enough morale for multiple deployments and activated effects", failures)
	var warden_id := _find_hand_card_by_definition(state, 0, "demo_warden_of_ashes")
	var exile_id := _find_hand_card_by_definition(state, 0, "demo_exile_magus")
	var sanctioner_id := _find_hand_card_by_definition(state, 0, "demo_sanctioner")
	var scholar_id := _find_hand_card_by_definition(state, 0, "demo_field_scholar")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": warden_id,
		"row": "front",
		"col": 0
	})).ok, "demo warden play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": exile_id,
		"row": "front",
		"col": 1
	})).ok, "demo exile magus play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sanctioner_id,
		"row": "front",
		"col": 2
	})).ok, "demo sanctioner play should succeed", failures)
	var warden_instance := state.get_player(0).battle_front[0].occupant
	var exile_instance := state.get_player(0).battle_front[1].occupant
	var sanctioner_instance := state.get_player(0).battle_front[2].occupant
	var deck_before_mill := state.get_player(0).deck.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": warden_instance,
		"effect_id": "mill_two"
	})).ok, "demo warden activated effect should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo warden first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo warden second pass should resolve", failures)
	_expect(state.get_player(0).deck.cards.size() == deck_before_mill - 2, "demo warden should mill two cards", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": exile_instance,
		"effect_id": "bounce_unit",
		"target_card_id": victim_instance_a
	})).ok, "demo exile magus activated effect should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo exile magus first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo exile magus second pass should resolve", failures)
	_expect(state.get_player(1).hand.cards.has(victim_instance_a), "demo exile magus should return the target unit to hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": scholar_id,
		"row": "back",
		"col": 0
	})).ok, "demo field scholar play should succeed", failures)
	var scholar_instance := state.get_player(0).battle_back[0].occupant
	var scholar_hand_size_before := state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": scholar_instance,
		"effect_id": "draw_one"
	})).ok, "demo field scholar activated effect should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo field scholar first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo field scholar second pass should resolve", failures)
	_expect(state.get_player(0).hand.cards.size() == scholar_hand_size_before + 1, "demo field scholar should draw one card after activation", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": sanctioner_instance,
		"effect_id": "destroy_unit",
		"target_card_id": victim_instance_b
	})).ok, "demo sanctioner activated effect should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "demo sanctioner first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "demo sanctioner second pass should resolve", failures)
	_expect(state.get_player(1).battle_front[1].occupant == "", "demo sanctioner should destroy the target unit", failures)
	_expect(_has_event_type(state, "CardSentToGrave"), "demo utility effects should emit grave movement events where appropriate", failures)


static func _definitions() -> Array:
	return CardDatabase.load_definitions()


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


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""


static func _targets_include_card(targets: Array, target_card_id: String) -> bool:
	for target in targets:
		if str(target.get("target_kind", "")) == "card" and str(target.get("defender_id", "")) == target_card_id:
			return true
	return false


static func _has_event_type(state, event_type: String) -> bool:
	for event in state.event_log:
		if str(event.type) == event_type:
			return true
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
