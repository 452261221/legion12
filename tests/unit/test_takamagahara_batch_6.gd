extends RefCounted
class_name TestTakamagaharaBatch6

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_okita_entry_and_attack_free_play(failures)
	_test_okita_attack_draws_ineligible_top_card(failures)
	_test_okita_attack_reveals_to_both_and_direct_plays_tactic(failures)
	_test_okita_attack_direct_plays_artifact_to_artifact_zone(failures)
	_test_okita_choice_action_exposes_revealed_card_context(failures)
	return failures

static func _test_okita_entry_and_attack_free_play(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0403", "takamagahara_s01_0417", "takamagahara_s01_0410", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3501, _masters(), _formal_options(2, 6))
	var okita_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0403")
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(okita_id != "" and kusanagi_id != "" and enemy_id != "", "okita free-play test should draw 冲田总司, 草薙剑 and an enemy legion", failures)
	if okita_id == "" or kusanagi_id == "" or enemy_id == "":
		return
	engine._manifest_kusanagi_to_slot(state, 0, kusanagi_id, "front", 0, "test_okita_manifest")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_okita_enemy")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": okita_id,
		"row": "front",
		"col": 1
	})).ok, "冲田总司 should play successfully", failures)
	_drain_stack(engine, state, failures, "冲田总司 entry buffs should resolve")
	var okita_instance = state.get_player(0).battle_front[1].occupant
	_expect(okita_instance == okita_id, "冲田总司 should enter the selected front slot", failures)
	_expect(engine.get_card_power(state, okita_id) == 4000, "冲田总司 should gain +1000 power while 草薙剑 is in the front row", failures)
	var targets = engine.get_legal_attack_targets(state, okita_id)
	_expect(_targets_include_card(targets, enemy_id), "冲田总司 should gain charge and attack immediately while 草薙剑 is in the front row", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": okita_id,
		"defender_id": enemy_id
	})).ok, "冲田总司 should be able to declare an attack on the same turn", failures)
	_drain_stack(engine, state, failures, "冲田总司 attack trigger should resolve to the revealed-card choice")
	_expect(_count_event_type(state, "CardsRevealedToAll") == 1, "冲田总司进攻时应向双方展示牌库顶卡牌", failures)
	_expect(_resolve_option_choice(engine, state, "revealed_top_card_play_or_hand", "play"), "冲田总司 attack trigger should allow choosing to free-play the revealed card", failures)
	_expect(_resolve_option_choice(engine, state, "play_revealed_deck_card_to_slot", "back:0"), "冲田总司 should allow choosing a slot for the revealed legion", failures)
	var tomoe_id = state.get_player(0).battle_back[0].occupant
	_expect(not tomoe_id.is_empty(), "冲田总司 should free-play the revealed 巴御前 onto the battlefield", failures)
	var tomoe_instance = state.card_instances.get(tomoe_id)
	_expect(tomoe_instance != null and tomoe_instance.definition_id == "takamagahara_s01_0410", "冲田总司 should free-play the revealed eligible 高天原 card", failures)

static func _test_okita_attack_draws_ineligible_top_card(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0403", "takamagahara_s01_0417", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3502, _masters(), _formal_options(2, 6))
	var okita_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0403")
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(okita_id != "" and kusanagi_id != "" and enemy_id != "", "okita draw test should draw 冲田总司, 草薙剑 and an enemy legion", failures)
	if okita_id == "" or kusanagi_id == "" or enemy_id == "":
		return
	engine._manifest_kusanagi_to_slot(state, 0, kusanagi_id, "front", 0, "test_okita_draw_manifest")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_okita_draw_enemy")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": okita_id,
		"row": "front",
		"col": 1
	})).ok, "冲田总司 draw test should play successfully", failures)
	_drain_stack(engine, state, failures, "冲田总司 draw test entry buffs should resolve")
	var hand_before_attack = state.get_player(0).hand.cards.size()
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": okita_id,
		"defender_id": enemy_id
	})).ok, "冲田总司 draw test should declare an attack", failures)
	_drain_stack(engine, state, failures, "冲田总司 draw test attack trigger should resolve")
	_expect(_count_event_type(state, "CardsRevealedToAll") == 1, "冲田总司不满足条件时也应向双方展示牌库顶卡牌", failures)
	_expect(state.get_player(0).hand.cards.size() == hand_before_attack + 1, "冲田总司 should add the revealed ineligible top card to hand", failures)
	_expect(_find_hand_card_by_definition(state, 0, "qa_vanilla") != "", "冲田总司 should draw the revealed neutral top card when it is not an eligible 高天原 card", failures)

static func _test_okita_attack_reveals_to_both_and_direct_plays_tactic(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0403", "takamagahara_s01_0417", "takamagahara_s02_0406", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3503, _masters(), _formal_options(2, 6))
	var okita_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0403")
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(okita_id != "" and kusanagi_id != "" and enemy_id != "", "okita tactic test should draw 冲田总司, 草薙剑 and an enemy legion", failures)
	if okita_id == "" or kusanagi_id == "" or enemy_id == "":
		return
	engine._manifest_kusanagi_to_slot(state, 0, kusanagi_id, "front", 0, "test_okita_tactic_manifest")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_okita_tactic_enemy")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": okita_id,
		"row": "front",
		"col": 1
	})).ok, "冲田总司 tactic test should play successfully", failures)
	_drain_stack(engine, state, failures, "冲田总司 tactic test entry buffs should resolve")
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": okita_id,
		"defender_id": enemy_id
	})).ok, "冲田总司 tactic test should declare an attack", failures)
	_drain_stack(engine, state, failures, "冲田总司 tactic test attack trigger should resolve")
	_expect(_count_event_type(state, "CardsRevealedToAll") == 1, "冲田总司展示战术时应向双方展示牌库顶卡牌", failures)
	_expect(_resolve_option_choice(engine, state, "revealed_top_card_play_or_hand", "play"), "冲田总司应允许选择无消耗打出展示的战术", failures)
	_expect(_pending_choice_by_operation(state, "play_revealed_deck_card_to_slot") == null, "冲田总司展示主动战术时不应再要求选择军团落点", failures)
	_expect(_pending_choice_by_operation(state, "set_revealed_deck_counter_to_slot") == null, "冲田总司展示主动战术时不应再要求选择反击落点", failures)
	var revealed_tactic_id := _find_card_by_definition(state, "takamagahara_s02_0406")
	var revealed_instance = state.card_instances.get(revealed_tactic_id)
	_expect(revealed_instance != null and str(revealed_instance.zone) == "stack_pending", "冲田总司应直接无消耗打出展示的主动战术", failures)
	_expect(not state.stack.is_empty(), "冲田总司无消耗打出展示的主动战术后应进入战术结算", failures)


static func _test_okita_attack_direct_plays_artifact_to_artifact_zone(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0403", "takamagahara_s01_0417", "takamagahara_s02_0404", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3504, _masters(), _formal_options(2, 6))
	var okita_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0403")
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(okita_id != "" and kusanagi_id != "" and enemy_id != "", "okita artifact test should draw 冲田总司, 草薙剑 and an enemy legion", failures)
	if okita_id == "" or kusanagi_id == "" or enemy_id == "":
		return
	engine._manifest_kusanagi_to_slot(state, 0, kusanagi_id, "front", 0, "test_okita_artifact_manifest")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_okita_artifact_enemy")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": okita_id,
		"row": "front",
		"col": 1
	})).ok, "冲田总司 artifact test should play successfully", failures)
	_drain_stack(engine, state, failures, "冲田总司 artifact test entry buffs should resolve")
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": okita_id,
		"defender_id": enemy_id
	})).ok, "冲田总司 artifact test should declare an attack", failures)
	_drain_stack(engine, state, failures, "冲田总司 artifact test attack trigger should resolve")
	_expect(_resolve_option_choice(engine, state, "revealed_top_card_play_or_hand", "play"), "冲田总司应允许选择无消耗打出展示的圣物", failures)
	_expect(_pending_choice_by_operation(state, "play_revealed_deck_card_to_slot") == null, "冲田总司展示圣物时不应再要求选择军团落点", failures)
	_expect(_pending_choice_by_operation(state, "set_revealed_deck_counter_to_slot") == null, "冲田总司展示圣物时不应再要求选择反击落点", failures)
	var artifact_id := _find_card_by_definition(state, "takamagahara_s02_0404")
	var artifact_instance = state.card_instances.get(artifact_id)
	_expect(artifact_instance != null and str(artifact_instance.zone) == "artifact_zone", "冲田总司应直接把展示的圣物打入圣物区", failures)
	_expect(state.get_player(0).artifact_zone.cards.has(artifact_id), "冲田总司展示的圣物应进入我方圣物区列表", failures)


static func _test_okita_choice_action_exposes_revealed_card_context(failures: Array[String]) -> void:
	var engine = GameEngine.new()
	var state = engine.create_game(_definitions(), [
		["takamagahara_s02_0403", "takamagahara_s01_0417", "takamagahara_s02_0406", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_plain", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 3505, _masters(), _formal_options(2, 6))
	var okita_id = _find_hand_card_by_definition(state, 0, "takamagahara_s02_0403")
	var kusanagi_id = _find_hand_card_by_definition(state, 0, "takamagahara_s01_0417")
	var enemy_id = _find_hand_card_by_definition(state, 1, "qa_plain")
	_expect(okita_id != "" and kusanagi_id != "" and enemy_id != "", "okita choice action test should draw 冲田总司, 草薙剑 and an enemy legion", failures)
	if okita_id == "" or kusanagi_id == "" or enemy_id == "":
		return
	engine._manifest_kusanagi_to_slot(state, 0, kusanagi_id, "front", 0, "test_okita_choice_action_manifest")
	engine._deploy_hand_card_to_slot(state, 1, enemy_id, "front", 0, "test_okita_choice_action_enemy")
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": okita_id,
		"row": "front",
		"col": 1
	})).ok, "冲田总司 choice action test should play successfully", failures)
	_drain_stack(engine, state, failures, "冲田总司 choice action test entry buffs should resolve")
	_expect(engine.apply_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": okita_id,
		"defender_id": enemy_id
	})).ok, "冲田总司 choice action test should declare an attack", failures)
	_drain_stack(engine, state, failures, "冲田总司 choice action test attack trigger should resolve")
	var expected_revealed_id := _find_card_by_definition(state, "takamagahara_s02_0406")
	var actions: Array[Dictionary] = engine.get_legal_actions(state, 0)
	var resolve_choice := {}
	for action in actions:
		if str(action.get("kind", "")) == "resolve_choice" and str(action.get("operation", "")) == "revealed_top_card_play_or_hand":
			resolve_choice = action
			break
	_expect(not resolve_choice.is_empty(), "冲田总司进攻后应生成展示牌处理选择 action", failures)
	if resolve_choice.is_empty():
		return
	var context: Dictionary = resolve_choice.get("context", {})
	_expect(str(context.get("card_id", "")) == expected_revealed_id, "冲田总司展示牌处理选择 action 应暴露展示牌的 card_id 给前端", failures)

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _masters() -> Array:
	return [
		{"name": "高天原·除魔物语", "master_name": "须佐之男", "master_id": "takamagahara_s01_04m2", "master_hp": 9, "master_max_hp": 9},
		{"name": "阿斯加德·万千面相", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
	]

static func _formal_options(opening_hand_size: int, opening_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": 10
	}

static func _drain_stack(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(8):
		if state.stack.is_empty():
			return
		var first_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
		_expect(first_pass.ok, message, failures)
		if not state.pending_choices.is_empty() or state.stack.is_empty():
			return
		var second_pass = engine.apply_command(state, GameCommand.create(state.priority_player, "PassPriority"))
		_expect(second_pass.ok, message, failures)
		if not state.pending_choices.is_empty():
			return
	failures.append(message)

static func _resolve_option_choice(engine: GameEngine, state, operation: String, selected_option: String) -> bool:
	var choice = _pending_choice_by_operation(state, operation)
	if choice == null:
		return false
	return engine.apply_command(state, GameCommand.create(int(choice.get("player_id", 0)), "ResolveChoice", {
		"choice_id": str(choice.get("choice_id", "")),
		"selected_option": selected_option
	})).ok

static func _pending_choice_by_operation(state, operation: String):
	for choice in state.pending_choices:
		if str(choice.get("operation", "")) == operation:
			return choice
	return null

static func _find_card_by_definition(state, definition_id: String) -> String:
	for card_id in state.card_instances.keys():
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

static func _count_event_type(state, event_type: String) -> int:
	var count := 0
	for event in state.event_log:
		if str(event.type) == event_type:
			count += 1
	return count

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _targets_include_card(targets: Array, target_card_id: String) -> bool:
	for target in targets:
		if target is Dictionary and str(target.get("defender_id", "")) == target_card_id:
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
