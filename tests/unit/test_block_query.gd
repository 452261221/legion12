extends RefCounted
class_name TestBlockQuery

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = GameEngine.new()
	var state = engine.create_game(_block_master_definitions(), _block_master_decks(), 333)

	var p0_card = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_card,
		"row": "front",
		"col": 0
	})).ok, "player 1 front play should succeed", failures)

	var blockers = engine.get_legal_blockers(state, 1, state.players[0].battle_front[0].occupant)
	_expect(blockers.is_empty(), "master attack should not expose generic hand blockers", failures)

	var defense_options = engine.get_defense_options(state, state.players[0].battle_front[0].occupant, {
		"target_kind": "master",
		"target_player": 1
	})
	_expect(defense_options.get("blockers", []).is_empty(), "master attack should not expose generic blocker actions", failures)
	_expect(defense_options.get("supporters", []).is_empty(), "master attack should not expose supporters", failures)
	var guard_sets = engine.get_legal_master_guard_card_sets(state, 1, state.players[0].battle_front[0].occupant, {
		"target_kind": "master",
		"target_player": 1
	})
	_expect(not guard_sets.is_empty(), "master attack should expose hand-guard combinations", failures)
	if guard_sets.is_empty():
		return failures
	var multi_guard_set: Array = []
	for guard_set in guard_sets:
		if guard_set is Array and guard_set.size() > 1:
			multi_guard_set = guard_set.duplicate()
			break

	var block_master_result = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": state.players[0].battle_front[0].occupant,
		"target_kind": "master",
		"target_player": 1,
		"master_guard_card_ids": guard_sets[0]
	}))
	_expect(block_master_result.ok, "guarding master attack should succeed", failures)
	_resolve_pending_attack(engine, state, failures, "guarding master attack first pass should succeed", "guarding master attack second pass should resolve")
	_expect(state.players[1].master_hp == 20, "guarded master should take no damage", failures)
	for guard_card_id in guard_sets[0]:
		_expect(state.players[1].grave.cards.has(str(guard_card_id)), "master guard cards should move to grave", failures)

	if multi_guard_set.is_empty():
		failures.append("master guard reverse-order test requires a multi-card guard set")
	else:
		var engine3 = GameEngine.new()
		var state3 = engine3.create_game(_block_master_definitions(), _block_master_decks(), 335)
		var p0_card_3 = state3.players[0].hand.cards[0]
		_expect(engine3.apply_command(state3, GameCommand.create(0, "PlayCard", {
			"card_id": p0_card_3,
			"row": "front",
			"col": 0
		})).ok, "reverse-order guard setup should succeed", failures)
		var reversed_guard_cards: Array = multi_guard_set.duplicate()
		reversed_guard_cards.reverse()
		_expect(engine3.apply_command(state3, GameCommand.create(0, "DeclareAttack", {
			"attacker_id": state3.players[0].battle_front[0].occupant,
			"target_kind": "master",
			"target_player": 1
		})).ok, "reverse-order guard attack declaration should succeed", failures)
		_expect(engine3.apply_command(state3, GameCommand.create(1, "ChooseDefense", {
			"master_guard_card_ids": reversed_guard_cards
		})).ok, "master guard should accept the same cards regardless of selection order", failures)
		_resolve_pending_attack(engine3, state3, failures, "reverse-order guard first pass should succeed", "reverse-order guard second pass should resolve")
		_expect(state3.players[1].master_hp == 20, "reverse-order master guard should still prevent damage", failures)
		for guard_card_id in reversed_guard_cards:
			_expect(state3.players[1].grave.cards.has(str(guard_card_id)), "reverse-order guard cards should move to grave", failures)
		var engine4 = GameEngine.new()
		var state4 = engine4.create_game(_block_master_definitions(), _block_master_decks(), 336)
		var p0_card_4 = state4.players[0].hand.cards[0]
		_expect(engine4.apply_command(state4, GameCommand.create(0, "PlayCard", {
			"card_id": p0_card_4,
			"row": "front",
			"col": 0
		})).ok, "1 hp guard setup should succeed", failures)
		_expect(engine4.apply_command(state4, GameCommand.create(1, "DebugCommand", {
			"action": "set_master_hp",
			"player_id": 1,
			"hp": 1
		})).ok, "1 hp guard setup should set the defending master to 1 hp", failures)
		_expect(engine4.apply_command(state4, GameCommand.create(0, "DeclareAttack", {
			"attacker_id": state4.players[0].battle_front[0].occupant,
			"target_kind": "master",
			"target_player": 1
		})).ok, "1 hp guard attack declaration should succeed", failures)
		_expect(engine4.apply_command(state4, GameCommand.create(1, "ChooseDefense", {
			"master_guard_card_ids": reversed_guard_cards
		})).ok, "1 hp master guard should still accept the same multi-card guard set", failures)
		_resolve_pending_attack(engine4, state4, failures, "1 hp guard first pass should succeed", "1 hp guard second pass should resolve")
		_expect(state4.players[1].master_hp == 1, "1 hp master guard should still prevent lethal damage", failures)
		for guard_card_id in reversed_guard_cards:
			_expect(state4.players[1].grave.cards.has(str(guard_card_id)), "1 hp guard cards should still move to grave", failures)

	var engine2 = GameEngine.new()
	var state2 = engine2.create_game(_definitions(), _decks(), 334)
	var p0_card_2 = state2.players[0].hand.cards[0]
	_expect(engine2.apply_command(state2, GameCommand.create(0, "PlayCard", {
		"card_id": p0_card_2,
		"row": "front",
		"col": 0
	})).ok, "second game player 1 front play should succeed", failures)
	_advance_to_next_main(engine2, state2, failures, "advance to player 2 main should succeed")
	if state2.active_player != 1 or state2.phase != "main":
		failures.append("player 2 main phase was not reached")
		return failures
	var p1_front = state2.players[1].hand.cards[0]
	_expect(engine2.apply_command(state2, GameCommand.create(1, "PlayCard", {
		"card_id": p1_front,
		"row": "front",
		"col": 0
	})).ok, "second game player 2 front play should succeed", failures)
	_advance_to_next_main(engine2, state2, failures, "advance back to player 1 main should succeed")
	if state2.active_player != 0 or state2.phase != "main":
		failures.append("player 1 main phase was not reached")
		return failures
	var attacker2 = state2.players[0].battle_front[0].occupant
	var defender2 = state2.players[1].battle_front[0].occupant
	var blockers2 = engine2.get_legal_blockers(state2, 1, attacker2, defender2)
	_expect(blockers2.is_empty(), "unit defense should not expose battlefield blockers when no other front legion is present", failures)
	var block_unit_result = engine2.apply_command(state2, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker2,
		"defender_id": defender2
	}))
	_expect(block_unit_result.ok, "unit attack without generic hand blocker should still declare", failures)
	_resolve_pending_attack(engine2, state2, failures, "blocking unit attack first pass should succeed", "blocking unit attack second pass should resolve")
	_expect(not state2.players[1].battle_front[0].occupant.is_empty() or not state2.players[1].grave.cards.is_empty(), "unit combat should resolve normally without generic hand blocker", failures)
	var engine5 = GameEngine.new()
	var state5 = engine5.create_game(_definitions(), _decks(), 337)
	_expect(engine5.apply_command(state5, GameCommand.create(0, "PlayCard", {
		"card_id": state5.players[0].hand.cards[0],
		"row": "front",
		"col": 0
	})).ok, "battlefield blocker test player 1 front play should succeed", failures)
	_advance_to_next_main(engine5, state5, failures, "battlefield blocker test should advance to player 2 main")
	if state5.active_player != 1 or state5.phase != "main":
		failures.append("battlefield blocker test did not reach player 2 main")
		return failures
	_expect(engine5.apply_command(state5, GameCommand.create(1, "PlayCard", {
		"card_id": state5.players[1].hand.cards[0],
		"row": "front",
		"col": 0
	})).ok, "battlefield blocker test player 2 first front play should succeed", failures)
	_expect(engine5.apply_command(state5, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 1
	})).ok, "battlefield blocker test should add morale for second defender", failures)
	_expect(engine5.apply_command(state5, GameCommand.create(1, "PlayCard", {
		"card_id": state5.players[1].hand.cards[0],
		"row": "front",
		"col": 1
	})).ok, "battlefield blocker test player 2 second front play should succeed", failures)
	_advance_to_next_main(engine5, state5, failures, "battlefield blocker test should advance back to player 1 main")
	if state5.active_player != 0 or state5.phase != "main":
		failures.append("battlefield blocker test did not return to player 1 main")
		return failures
	var attacker5 = state5.players[0].battle_front[0].occupant
	var defender5 = state5.players[1].battle_front[0].occupant
	var blocker5 = state5.players[1].battle_front[1].occupant
	var blockers5 = engine5.get_legal_blockers(state5, 1, attacker5, defender5)
	_expect(blockers5.is_empty(), "unit defense should not expose same-row front legions as blockers", failures)
	var defense_options5 = engine5.get_defense_options(state5, attacker5, {
		"target_kind": "card",
		"defender_id": defender5
	})
	_expect(defense_options5.get("blockers", []).is_empty(), "unit defense options should not include same-row front blockers", failures)
	_expect(engine5.apply_command(state5, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker5,
		"defender_id": defender5
	})).ok, "battlefield blocker test attack should declare", failures)
	var rejected_same_row_block = engine5.apply_command(state5, GameCommand.create(1, "ChooseDefense", {
		"blocker_id": blocker5
	}))
	_expect(not rejected_same_row_block.ok and str(rejected_same_row_block.get("code", "")) == "NO_DEFENSE_OPTIONS", "unit defense should reject choosing a same-row front legion as blocker", failures)
	_resolve_pending_attack(engine5, state5, failures, "battlefield blocker test first pass should succeed", "battlefield blocker test second pass should resolve")
	_expect(not state5.players[1].grave.cards.has(blocker5), "same-row front legion should not be spent as a unit defense blocker", failures)
	_expect(str(state5.players[1].battle_front[1].occupant) == blocker5, "same-row front legion should remain on battlefield after rejected unit defense", failures)
	_test_taunt_targeting(failures)
	_test_cannot_attack_keyword(failures)
	_test_ranged_keyword_cross_row_attack(failures)
	_test_summoning_sickness_and_charge(failures)
	_test_attack_no_loss_keyword(failures)
	_test_ranged_no_loss_does_not_prevent_front_to_front_damage(failures)

	return failures

static func _test_taunt_targeting(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_taunt_definitions(), _taunt_decks(), 335)
	var attacker_card = _find_hand_card_by_definition(state, 0, "qa_attacker")
	_expect(attacker_card != "", "taunt test attacker should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_card,
		"row": "front",
		"col": 0
	})).ok, "taunt test attacker play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for taunt setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for taunt setup")
		return
	var taunt_card = _find_hand_card_by_definition(state, 1, "qa_taunt")
	var vanilla_card = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(taunt_card != "", "taunt defender should be in opening hand", failures)
	_expect(vanilla_card != "", "plain defender should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": taunt_card,
		"row": "front",
		"col": 1
	})).ok, "taunt defender play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": vanilla_card,
		"row": "front",
		"col": 0
	})).ok, "plain defender play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for taunt attack should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for taunt attack")
		return
	var attacker_id = state.players[0].battle_front[0].occupant
	var taunt_id = state.get_player(1).battle_front[1].occupant
	var plain_id = state.get_player(1).battle_front[0].occupant
	var targets = engine.get_legal_attack_targets(state, attacker_id)
	_expect(targets.size() == 1, "taunt should narrow legal targets to exactly one unit", failures)
	if targets.size() == 1:
		_expect(str(targets[0].get("defender_id", "")) == taunt_id, "taunt should be the only legal target", failures)
	var invalid_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": plain_id
	}))
	_expect(not invalid_attack.ok and str(invalid_attack.get("code", "")) == "TAUNT_REQUIRED", "manual attack should not bypass taunt restriction", failures)

static func _test_cannot_attack_keyword(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_keyword_definitions(), _cannot_attack_decks(), 336)
	var attacker_card = _find_hand_card_by_definition(state, 0, "qa_cannot_attack")
	_expect(attacker_card != "", "cannot_attack source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_card,
		"row": "front",
		"col": 0
	})).ok, "cannot_attack source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for cannot_attack setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for cannot_attack setup")
		return
	var defender_card = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(defender_card != "", "cannot_attack target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": defender_card,
		"row": "front",
		"col": 0
	})).ok, "cannot_attack target play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for cannot_attack test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for cannot_attack test")
		return
	var attacker_id = state.players[0].battle_front[0].occupant
	_expect(engine.get_legal_attack_targets(state, attacker_id).is_empty(), "cannot_attack unit should have no legal attack targets", failures)
	var invalid_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": state.players[1].battle_front[0].occupant
	}))
	_expect(not invalid_attack.ok and str(invalid_attack.get("code", "")) == "CANNOT_ATTACK", "cannot_attack keyword should reject declared attacks", failures)

static func _test_ranged_keyword_cross_row_attack(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_keyword_definitions(), _ranged_decks(), 337)
	var attacker_card = _find_hand_card_by_definition(state, 0, "qa_ranged")
	_expect(attacker_card != "", "ranged source should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_card,
		"row": "back",
		"col": 0
	})).ok, "ranged source play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for ranged setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for ranged setup")
		return
	var defender_card = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(defender_card != "", "ranged target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": defender_card,
		"row": "front",
		"col": 0
	})).ok, "ranged target play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for ranged test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for ranged test")
		return
	var attacker_id = state.players[0].battle_back[0].occupant
	var defender_id = state.players[1].battle_front[0].occupant
	var targets = engine.get_legal_attack_targets(state, attacker_id)
	var found_target = false
	for target in targets:
		if str(target.get("defender_id", "")) == defender_id:
			found_target = true
			break
	_expect(found_target, "ranged unit should be able to target a cross-row defender", failures)
	var attack_result = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	}))
	_expect(attack_result.ok, "ranged keyword should allow cross-row attack declaration", failures)

static func _test_summoning_sickness_and_charge(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_keyword_definitions(), _charge_decks(), 338)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for charge defender setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for charge defender setup")
		return
	var defender_card = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(defender_card != "", "charge target should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": defender_card,
		"row": "front",
		"col": 1
	})).ok, "charge target play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for charge summon test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for charge summon test")
		return
	var normal_card = _find_hand_card_by_definition(state, 0, "qa_plain")
	var charge_card = _find_hand_card_by_definition(state, 0, "qa_charge")
	_expect(normal_card != "", "normal attacker should be in opening hand for charge test", failures)
	_expect(charge_card != "", "charge attacker should be in opening hand for charge test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": normal_card,
		"row": "front",
		"col": 0
	})).ok, "normal attacker play should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": charge_card,
		"row": "front",
		"col": 1
	})).ok, "charge attacker play should succeed", failures)
	var normal_id = state.players[0].battle_front[0].occupant
	var charge_id = state.players[0].battle_front[1].occupant
	_expect(engine.get_legal_attack_targets(state, normal_id).is_empty(), "non-charge unit should not attack on the turn it entered", failures)
	var charge_targets = engine.get_legal_attack_targets(state, charge_id)
	_expect(not charge_targets.is_empty(), "charge unit should be able to attack on the turn it entered", failures)
	var invalid_normal_attack = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": normal_id,
		"defender_id": state.players[1].battle_front[0].occupant
	}))
	_expect(not invalid_normal_attack.ok and str(invalid_normal_attack.get("code", "")) == "SUMMONING_SICK", "non-charge unit attack should be rejected on summon turn", failures)

static func _test_attack_no_loss_keyword(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_keyword_definitions(), _attack_no_loss_decks(), 339)
	var attacker_card = _find_hand_card_by_definition(state, 0, "qa_no_loss")
	_expect(attacker_card != "", "no-loss attacker should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_card,
		"row": "front",
		"col": 0
	})).ok, "no-loss attacker play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for no-loss setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for no-loss setup")
		return
	var defender_card = _find_hand_card_by_definition(state, 1, "qa_equal")
	_expect(defender_card != "", "no-loss defender should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": defender_card,
		"row": "front",
		"col": 0
	})).ok, "no-loss defender play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for no-loss test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for no-loss test")
		return
	var attacker_id = state.players[0].battle_front[0].occupant
	var defender_id = state.players[1].battle_front[0].occupant
	var attack_result = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	}))
	_expect(attack_result.ok, "attack_no_loss unit attack should succeed", failures)
	_resolve_pending_attack(engine, state, failures, "attack_no_loss first pass should succeed", "attack_no_loss second pass should resolve")
	_expect(state.players[1].grave.cards.has(defender_id), "attack_no_loss attacker should still defeat equal-power defender", failures)
	_expect(state.players[0].battle_front[0].occupant == attacker_id, "attack_no_loss attacker should stay on battlefield after combat", failures)

static func _test_ranged_no_loss_does_not_prevent_front_to_front_damage(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_keyword_definitions(), _front_ranged_no_loss_decks(), 340)
	var attacker_card = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0410")
	_expect(attacker_card != "", "front-to-front ranged-no-loss attacker should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_card,
		"row": "front",
		"col": 0
	})).ok, "front-to-front ranged-no-loss attacker play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance to player 2 main for front-to-front ranged no-loss setup should succeed")
	if state.active_player != 1 or state.phase != "main":
		failures.append("player 2 main phase was not reached for front-to-front ranged no-loss setup")
		return
	var defender_card = _find_hand_card_by_definition(state, 1, "qa_equal")
	_expect(defender_card != "", "front-to-front ranged-no-loss defender should be in opening hand", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": defender_card,
		"row": "front",
		"col": 0
	})).ok, "front-to-front ranged-no-loss defender play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "advance back to player 1 main for front-to-front ranged no-loss test should succeed")
	if state.active_player != 0 or state.phase != "main":
		failures.append("player 1 main phase was not reached for front-to-front ranged no-loss test")
		return
	var attacker_id = state.players[0].battle_front[0].occupant
	var defender_id = state.players[1].battle_front[0].occupant
	var attack_result = engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	}))
	_expect(attack_result.ok, "front-to-front ranged-no-loss attack should declare", failures)
	_resolve_pending_attack(engine, state, failures, "front-to-front ranged-no-loss first pass should succeed", "front-to-front ranged-no-loss second pass should resolve")
	_expect(state.players[0].grave.cards.has(attacker_id), "front-to-front ranged-no-loss attacker should still take defender power and die", failures)
	_expect(state.players[1].battle_front[0].occupant == defender_id, "front-to-front defender should survive after taking less power", failures)
	_expect(engine.get_card_power(state, defender_id) == 1000, "front-to-front defender should keep only the remaining power this turn", failures)

static func _taunt_definitions() -> Array:
	return CardDatabase.load_definitions()

static func _block_master_definitions() -> Array:
	return CardDatabase.load_definitions()

static func _keyword_definitions() -> Array:
	return CardDatabase.load_definitions()

static func _taunt_decks() -> Array:
	return [
		["qa_attacker", "qa_attacker", "qa_attacker", "qa_attacker", "qa_attacker", "qa_attacker"],
		["qa_taunt", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _block_master_decks() -> Array:
	return [
		["qa_charge", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"],
		["qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _cannot_attack_decks() -> Array:
	return [
		["qa_cannot_attack", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"],
		["qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _ranged_decks() -> Array:
	return [
		["qa_ranged", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"],
		["qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _charge_decks() -> Array:
	return [
		["qa_charge", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"],
		["qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _attack_no_loss_decks() -> Array:
	return [
		["qa_no_loss", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"],
		["qa_equal", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _front_ranged_no_loss_decks() -> Array:
	return [
		["takamagahara_s01_0410", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"],
		["qa_equal", "qa_plain", "qa_plain", "qa_plain", "qa_plain", "qa_plain"]
	]

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

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

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	]

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
