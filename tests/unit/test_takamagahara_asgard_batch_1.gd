extends RefCounted
class_name TestTakamagaharaAsgardBatch1

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_takasugi_entry_draw_and_attack_cost_down(failures)
	_test_sigurd_blood_price_move_and_gram_attack_bonus(failures)
	_test_gram_recycle_damage_rest_ready_and_nonlethal(failures)
	_test_tachibana_death_reduces_enemy_hand_legion_cost_until_next_own_turn_end(failures)
	return failures

static func _test_takasugi_entry_draw_and_attack_cost_down(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0408", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3001, [], _formal_options(6, 10))
	var enemy_a = _find_hand_card_by_definition(state, 1, "qa_plain")
	var enemy_b = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(enemy_a != "" and enemy_b != "", "takasugi test should draw two enemy legions", failures)
	if enemy_a == "" or enemy_b == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_a, "front", 0, "test_takasugi_enemy_a")
	engine._deploy_hand_card_to_slot(state, 1, enemy_b, "front", 1, "test_takasugi_enemy_b")
	var enemy_a_cost_before = engine._get_effective_card_cost(state, enemy_a)
	var enemy_b_cost_before = engine._get_effective_card_cost(state, enemy_b)
	var hand_before = state.get_player(0).hand.cards.size()
	var takasugi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0408")
	_expect(takasugi_id != "", "takasugi should be in opening hand", failures)
	if takasugi_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": takasugi_id,
		"row": "front",
		"col": 0
	})).ok, "takasugi should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "takasugi entry should resolve to a target choice")
	_expect(_resolve_candidate_choice(engine, state, "modify_cost_until_turn_end", [enemy_a]), "takasugi entry should choose an enemy legion", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before, "takasugi entry should draw one card after leaving hand", failures)
	_expect(engine._get_effective_card_cost(state, enemy_a) == max(0, enemy_a_cost_before - 2), "takasugi entry should reduce the chosen enemy legion cost by 2 this turn", failures)
	_advance_to_next_main(engine, state, failures, "takasugi test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "takasugi test should return to player 1 main")
	var takasugi_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(takasugi_instance_id == takasugi_id, "takasugi should remain on the battlefield for the attack test", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": takasugi_instance_id,
		"defender_id": enemy_a
	})).ok, "takasugi should be able to declare an attack on the next turn", failures)
	_expect(_resolve_option_choice(engine, state, "pre_stack_optional_attack_trigger", "yes"), "takasugi attack trigger should allow paying morale for the optional effect", failures)
	_resolve_top_stack(engine, state, failures, "takasugi attack trigger should resolve to a target choice")
	_expect(_resolve_candidate_choice(engine, state, "modify_cost_until_turn_end", [enemy_b]), "takasugi attack trigger should choose an enemy legion", failures)
	_expect(engine._get_effective_card_cost(state, enemy_b) == max(0, enemy_b_cost_before - 2), "takasugi attack trigger should reduce the chosen enemy legion cost by 2 this turn", failures)

static func _test_sigurd_blood_price_move_and_gram_attack_bonus(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s01_0317", "asgard_s01_0310", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3002, [], _formal_options(6, 7))
	var gram_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0317")
	var sigurd_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0310")
	_expect(gram_id != "" and sigurd_id != "", "sigurd test should draw 神剑格拉墨 and 齐格鲁德", failures)
	if gram_id == "" or sigurd_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": gram_id,
		"row": "artifact",
		"col": -1
	})).ok, "神剑格拉墨 should play into the artifact zone", failures)
	_resolve_top_stack(engine, state, failures, "神剑格拉墨 entry should resolve")
	if _pending_choice_by_operation(state, "optional_stack_effect") != null:
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "神剑格拉墨 entry should allow skipping the optional mill effect in this test", failures)
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(enemy_id != "", "sigurd test should draw an enemy legion", failures)
	if enemy_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_sigurd_enemy")
	_expect(not engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sigurd_id,
		"row": "front",
		"col": 0
	})).ok, "齐格鲁德 should require a play option when only the blood-price discount makes it affordable", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": sigurd_id,
		"row": "front",
		"col": 0,
		"play_option_id": "sigurd_blood_price"
	})).ok, "齐格鲁德 should play successfully with the blood-price option", failures)
	_expect(state.get_player(0).master_hp == 19, "齐格鲁德 blood-price option should deal 1 damage to the controller master", failures)
	var sigurd_instance_id = state.get_player(0).battle_front[0].occupant
	_expect(sigurd_instance_id == sigurd_id, "齐格鲁德 should enter the front row", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": sigurd_instance_id,
		"effect_id": "sigurd_shift"
	})).ok, "齐格鲁德 should be able to move once on the turn it enters", failures)
	_resolve_top_stack(engine, state, failures, "齐格鲁德 move effect should resolve")
	_expect(state.get_player(0).battle_front[0].occupant == "", "齐格鲁德 move effect should vacate the original front slot", failures)
	_expect(state.get_player(0).battle_back[0].occupant == sigurd_instance_id, "齐格鲁德 move effect should move it to the back row", failures)
	_expect(not engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": sigurd_instance_id,
		"effect_id": "sigurd_shift"
	})).ok, "齐格鲁德 should not be able to use the move effect twice in one turn", failures)
	_advance_to_next_main(engine, state, failures, "sigurd test should advance to player 2 main")
	_advance_to_next_main(engine, state, failures, "sigurd test should return to player 1 main")
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": sigurd_instance_id,
		"effect_id": "sigurd_shift"
	})).ok, "齐格鲁德 should regain the move effect on a later turn", failures)
	_resolve_top_stack(engine, state, failures, "齐格鲁德 second-turn move effect should resolve")
	_expect(state.get_player(0).battle_front[0].occupant == sigurd_instance_id, "齐格鲁德 second-turn move should return it to the front row", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": sigurd_instance_id,
		"defender_id": enemy_id
	})).ok, "齐格鲁德 should be able to declare an attack after returning to the front row", failures)
	_resolve_top_stack(engine, state, failures, "齐格鲁德 attack trigger should resolve")
	_expect(engine.get_card_power(state, sigurd_instance_id) == 5000, "齐格鲁德 should gain 1000 power while 神剑格拉墨 is in the artifact zone", failures)

static func _test_gram_recycle_damage_rest_ready_and_nonlethal(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["asgard_s01_0317", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3004, [], _formal_options(1, 8))
	var gram_id = _find_hand_card_by_definition(state, 0, "asgard_s01_0317")
	_expect(gram_id != "", "gram active effect test should draw 神剑格拉墨", failures)
	if gram_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": gram_id,
		"row": "artifact",
		"col": -1
	})).ok, "神剑格拉墨 should play into the artifact zone for its active effect test", failures)
	_resolve_top_stack(engine, state, failures, "神剑格拉墨 active effect test should resolve its entry trigger")
	if _pending_choice_by_operation(state, "optional_stack_effect") != null:
		_expect(_resolve_option_choice(engine, state, "optional_stack_effect", "no"), "神剑格拉墨 active effect test should be able to skip the entry mill", failures)

	var asgard_a = _add_card_to_grave(state, 0, "asgard_s01_0309")
	var asgard_b = _add_card_to_grave(state, 0, "asgard_s01_0310")
	var asgard_c = _add_card_to_grave(state, 0, "asgard_s01_0314")
	var asgard_d = _add_card_to_grave(state, 0, "asgard_s02_0304")
	var non_asgard_legion = _add_card_to_grave(state, 0, "qa_plain")
	var active_actions = engine.get_activatable_effects(state, 0)
	_expect(_has_activatable_effect(active_actions, gram_id, "gram_rested_recycle_then_nonlethal"), "神剑格拉墨 should be activatable while active with four Asgard legions in grave", failures)
	_expect(not _has_activatable_effect(active_actions, gram_id, "gram_ready"), "神剑格拉墨 ready effect should not be available while it is already active", failures)

	var opponent_hp_before = state.get_player(1).master_hp
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": gram_id,
		"effect_id": "gram_rested_recycle_then_nonlethal"
	})).ok, "神剑格拉墨 should activate its recycle damage effect when four matching grave cards exist", failures)
	var gram_instance = state.card_instances.get(gram_id)
	_expect(gram_instance != null and str(gram_instance.orientation) == "rested", "神剑格拉墨 should rest as the activation cost/result of its recycle effect", failures)
	_resolve_top_stack(engine, state, failures, "神剑格拉墨 recycle effect should resolve to a grave reorder choice")
	var choice = _pending_choice_by_operation(state, "recycle_grave_to_deck")
	_expect(choice != null, "神剑格拉墨 should request choosing four grave cards for bottom-deck order", failures)
	if choice == null:
		return
	var candidates = choice.get("candidate_card_ids", [])
	_expect(_array_has_exactly(candidates, [asgard_a, asgard_b, asgard_c, asgard_d]), "神剑格拉墨 choice should contain exactly four Asgard legion grave cards", failures)
	_expect(not candidates.has(non_asgard_legion), "神剑格拉墨 choice should not include non-Asgard grave cards", failures)
	var selected_order = [asgard_c, asgard_a, asgard_d, asgard_b]
	_expect(_resolve_candidate_choice(engine, state, "recycle_grave_to_deck", selected_order), "神剑格拉墨 should accept a player-chosen bottom-deck order", failures)
	var deck = state.get_player(0).deck.cards
	_expect(_array_equals(deck.slice(deck.size() - selected_order.size(), deck.size()), selected_order), "神剑格拉墨 should put the selected grave cards on the deck bottom in chosen order", failures)
	_expect(state.get_player(1).master_hp == opponent_hp_before - 1, "神剑格拉墨 should deal 1 damage to the opposing master after recycling four cards", failures)
	_expect(gram_instance != null and str(gram_instance.orientation) == "rested", "神剑格拉墨 should remain rested after the recycle damage effect resolves", failures)

	var spent_before_ready = state.get_player(0).spent_cost_area.cards.size()
	var rested_actions = engine.get_activatable_effects(state, 0)
	_expect(_has_activatable_effect(rested_actions, gram_id, "gram_ready"), "神剑格拉墨 should offer its 2-morale ready effect while rested", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": gram_id,
		"effect_id": "gram_ready"
	})).ok, "神剑格拉墨 should activate its 2-morale ready effect while rested", failures)
	_resolve_top_stack(engine, state, failures, "神剑格拉墨 ready effect should resolve")
	_expect(gram_instance != null and str(gram_instance.orientation) == "active", "神剑格拉墨 should become active after paying 2 morale", failures)
	_expect(state.get_player(0).spent_cost_area.cards.size() == spent_before_ready + 2, "神剑格拉墨 ready effect should consume exactly 2 morale", failures)

	var short_a = _add_card_to_grave(state, 0, "asgard_s01_0309")
	var short_b = _add_card_to_grave(state, 0, "asgard_s01_0310")
	var short_c = _add_card_to_grave(state, 0, "asgard_s01_0314")
	var short_actions = engine.get_activatable_effects(state, 0)
	_expect(not _has_activatable_effect(short_actions, gram_id, "gram_rested_recycle_then_nonlethal"), "神剑格拉墨 should not be activatable with fewer than four matching grave cards", failures)
	_expect(not engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": gram_id,
		"effect_id": "gram_rested_recycle_then_nonlethal"
	})).ok, "神剑格拉墨 activation should be rejected before resting when fewer than four matching grave cards exist", failures)
	_expect(gram_instance != null and str(gram_instance.orientation) == "active", "failed 神剑格拉墨 activation should leave the artifact active", failures)

	var short_d = _add_card_to_grave(state, 0, "asgard_s02_0304")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "set_master_hp",
		"player_id": 1,
		"hp": 1
	})).ok, "神剑格拉墨 nonlethal test should set the opponent master to 1 HP", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": gram_id,
		"effect_id": "gram_rested_recycle_then_nonlethal"
	})).ok, "神剑格拉墨 should activate again once the fourth matching grave card is present", failures)
	_resolve_top_stack(engine, state, failures, "神剑格拉墨 nonlethal recycle should resolve to a grave choice")
	_expect(_resolve_candidate_choice(engine, state, "recycle_grave_to_deck", [short_a, short_b, short_c, short_d]), "神剑格拉墨 nonlethal test should recycle the four matching cards", failures)
	_expect(state.get_player(1).master_hp == 1, "神剑格拉墨 should not damage an opposing master already at 1 HP", failures)

static func _test_tachibana_death_reduces_enemy_hand_legion_cost_until_next_own_turn_end(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s01_0412", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3003, [], _formal_options(2, 10))
	var enemy_field_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	var enemy_hand_id = _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(enemy_field_id != "" and enemy_hand_id != "", "tachibana test should draw one enemy field target and one enemy hand legion", failures)
	if enemy_field_id == "" or enemy_hand_id == "":
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_field_id, "front", 0, "test_tachibana_enemy_setup")
	var enemy_hand_cost_before = engine._get_effective_play_cost(state, enemy_hand_id)
	var tachibana_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0412")
	_expect(tachibana_id != "", "tachibana should be in opening hand", failures)
	if tachibana_id == "":
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": tachibana_id,
		"row": "front",
		"col": 0
	})).ok, "tachibana should play successfully", failures)
	_resolve_top_stack(engine, state, failures, "tachibana entry should resolve to a target choice")
	_expect(_resolve_candidate_choice(engine, state, "modify_cost_until_turn_end", [enemy_field_id]), "tachibana entry should choose the enemy battlefield legion", failures)
	var death_events = engine._deal_legion_damage(state, "", tachibana_id, 3000, "test_tachibana_die")
	engine._process_generated_events(state, death_events, "test_tachibana_die")
	_resolve_top_stack(engine, state, failures, "tachibana death trigger should resolve")
	_expect(engine._get_effective_play_cost(state, enemy_hand_id) == max(0, enemy_hand_cost_before - 1), "tachibana death trigger should reduce an enemy hand legion's play cost by 1", failures)
	_advance_to_next_main(engine, state, failures, "tachibana death modifier should persist into the opponent main phase")
	_expect(engine._get_effective_play_cost(state, enemy_hand_id) == max(0, enemy_hand_cost_before - 1), "tachibana death modifier should still apply during the opponent turn", failures)
	_advance_to_next_main(engine, state, failures, "tachibana death modifier should still persist into the next allied main phase")
	_expect(engine._get_effective_play_cost(state, enemy_hand_id) == max(0, enemy_hand_cost_before - 1), "tachibana death modifier should still apply on the controller's next turn", failures)
	_advance_to_next_main(engine, state, failures, "tachibana death modifier should expire after the next allied turn ends")
	_expect(engine._get_effective_play_cost(state, enemy_hand_id) == enemy_hand_cost_before, "tachibana death modifier should expire after the next own turn ends", failures)

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

static func _add_card_to_grave(state, player_id: int, definition_id: String) -> String:
	var card_id = state.create_instance(definition_id, player_id, player_id)
	state.get_player(player_id).grave.add_card(card_id)
	var instance = state.card_instances.get(card_id)
	if instance != null:
		instance.zone = "grave"
		instance.position = {}
		instance.orientation = "active"
		instance.face = "face_up"
		instance.controller = player_id
	return card_id

static func _has_activatable_effect(actions: Array, source_id: String, effect_id: String) -> bool:
	for action in actions:
		if action is Dictionary and str(action.get("source_id", "")) == source_id and str(action.get("effect_id", "")) == effect_id:
			return true
	return false

static func _array_has_exactly(values: Array, expected: Array) -> bool:
	if values.size() != expected.size():
		return false
	for item in expected:
		if not values.has(item):
			return false
	return true

static func _array_equals(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if str(left[index]) != str(right[index]):
			return false
	return true

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
