extends RefCounted
class_name TestBattleStatusBadges

const BattleTableScript = preload("res://client/scripts/battle_table.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_front_row_continuous_taunt_badge(failures)
	_test_temporary_and_persistent_keyword_badges(failures)
	_test_engine_granted_strong_attack_badge(failures)
	_test_master_damage_bonus_grants_strong_attack_badge(failures)
	_test_timed_cost_modifier_updates_view_cost(failures)
	_test_non_battle_or_face_down_cards_hide_badges(failures)
	_test_gram_artifact_double_click_panel_hint(failures)
	return failures


static func _test_front_row_continuous_taunt_badge(failures: Array[String]) -> void:
	var harness := _create_badge_harness()
	var definitions: Array = harness.get("definitions", [])
	var definitions_by_id: Dictionary = harness.get("definitions_by_id", {})
	var table = harness.get("table", null)
	var engine := GameEngine.new()
	var state = engine.create_game(definitions, [
		["asgard_s01_0312", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 9101, [], _formal_options(1, 3))
	var lagertha_id := _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	_expect(not lagertha_id.is_empty(), "词条标签：测试初始化失败，未抽到铁盾拉葛莎", failures)
	if lagertha_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, lagertha_id, "front", 0, "test_taunt_badge_front")
	table._state = state
	var instance = state.card_instances.get(lagertha_id)
	var definition: Dictionary = definitions_by_id.get("asgard_s01_0312", {})
	var front_badges: Array[String] = table._active_status_badges_for_card(instance, definition)
	_expect(front_badges.has("嘲讽"), "词条标签：铁盾拉葛莎位于前排时应显示嘲讽", failures)
	instance.zone = "battle_back"
	instance.position["row"] = "back"
	var back_badges: Array[String] = table._active_status_badges_for_card(instance, definition)
	_expect(not back_badges.has("嘲讽"), "词条标签：铁盾拉葛莎不在前排时不应显示嘲讽", failures)
	_free_badge_harness(harness)


static func _test_temporary_and_persistent_keyword_badges(failures: Array[String]) -> void:
	var harness := _create_badge_harness()
	var definitions: Array = harness.get("definitions", [])
	var definitions_by_id: Dictionary = harness.get("definitions_by_id", {})
	var table = harness.get("table", null)
	var engine := GameEngine.new()
	var state = engine.create_game(definitions, [
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 9102, [], _formal_options(1, 3))
	var card_id := _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(not card_id.is_empty(), "词条标签：测试初始化失败，未抽到 qa_vanilla", failures)
	if card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, card_id, "front", 0, "test_keyword_badges_flags")
	table._state = state
	var instance = state.card_instances.get(card_id)
	instance.flags["temporary_keyword_strong_attack_turn"] = state.turn_number
	instance.flags["cannot_die_until_turn_end_turn"] = state.turn_number
	instance.flags["temporary_keyword_must_hit_turn"] = state.turn_number
	instance.flags["taunt_until_next_own_turn_start_player"] = 0
	instance.flags["persistent_keywords"] = ["shock"]
	instance.flags["temporary_keyword_pierce_turn"] = state.turn_number
	var definition: Dictionary = definitions_by_id.get("qa_vanilla", {})
	var badges: Array[String] = table._active_status_badges_for_card(instance, definition)
	var expected := ["强攻", "免死", "必中", "嘲讽", "震击", "贯穿"]
	for badge in expected:
		_expect(badges.has(badge), "词条标签：应显示 %s" % badge, failures)
	_free_badge_harness(harness)


static func _test_engine_granted_strong_attack_badge(failures: Array[String]) -> void:
	var harness := _create_badge_harness()
	var definitions: Array = harness.get("definitions", [])
	var definitions_by_id: Dictionary = harness.get("definitions_by_id", {})
	var table = harness.get("table", null)
	var engine := GameEngine.new()
	var state = engine.create_game(definitions, [
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 9104, [], _formal_options(1, 3))
	var card_id := _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(not card_id.is_empty(), "词条标签：强攻授予测试初始化失败，未抽到 qa_vanilla", failures)
	if card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, card_id, "front", 0, "test_keyword_badges_engine_grant")
	engine._grant_keyword_to_card_until_turn_end(state, card_id, "strong_attack", "test_keyword_badges_engine_grant")
	table._state = state
	var instance = state.card_instances.get(card_id)
	var definition: Dictionary = definitions_by_id.get("qa_vanilla", {})
	var badges: Array[String] = table._active_status_badges_for_card(instance, definition)
	_expect(badges.has("强攻"), "词条标签：规则授予强攻后应显示强攻标签", failures)
	_free_badge_harness(harness)


static func _test_master_damage_bonus_grants_strong_attack_badge(failures: Array[String]) -> void:
	var harness := _create_badge_harness()
	var definitions: Array = harness.get("definitions", [])
	var definitions_by_id: Dictionary = harness.get("definitions_by_id", {})
	var table = harness.get("table", null)
	var engine := GameEngine.new()
	var state = engine.create_game(definitions, [
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 9106, [], _formal_options(1, 3))
	var card_id := _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(not card_id.is_empty(), "词条标签：主宰额伤转强攻测试初始化失败，未抽到 qa_vanilla", failures)
	if card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, card_id, "front", 0, "test_master_damage_bonus_badge")
	engine._grant_master_damage_bonus(state, {
		"targets": {"target_card_id": card_id},
		"resolution": {"amount": 1}
	}, "test_master_damage_bonus_badge")
	table._state = state
	var instance = state.card_instances.get(card_id)
	var definition: Dictionary = definitions_by_id.get("qa_vanilla", {})
	var badges: Array[String] = table._active_status_badges_for_card(instance, definition)
	_expect(badges.has("强攻"), "词条标签：授予主宰额伤的效果也应显示强攻标签", failures)
	_free_badge_harness(harness)


static func _test_timed_cost_modifier_updates_view_cost(failures: Array[String]) -> void:
	var harness := _create_badge_harness()
	var definitions: Array = harness.get("definitions", [])
	var table = harness.get("table", null)
	var engine := GameEngine.new()
	var state = engine.create_game(definitions, [
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 9105, [], _formal_options(1, 3))
	var card_id := _find_hand_card_by_definition(state, 1, "qa_vanilla")
	_expect(not card_id.is_empty(), "词条标签：费用显示测试初始化失败，未抽到敌方 qa_vanilla", failures)
	if card_id.is_empty():
		return
	var cost_before := engine._get_effective_play_cost(state, card_id)
	engine._modify_cost_until_next_own_turn_end(state, card_id, -1, 0, "test_timed_cost_modifier_updates_view_cost")
	table._state = state
	var view_card: Dictionary = table._build_view_card(card_id)
	_expect(int(view_card.get("current_cost", cost_before)) == max(0, cost_before - 1), "词条标签：带持续时限的费用修正应同步显示到牌面费用", failures)
	_free_badge_harness(harness)


static func _test_non_battle_or_face_down_cards_hide_badges(failures: Array[String]) -> void:
	var harness := _create_badge_harness()
	var definitions: Array = harness.get("definitions", [])
	var definitions_by_id: Dictionary = harness.get("definitions_by_id", {})
	var table = harness.get("table", null)
	var engine := GameEngine.new()
	var state = engine.create_game(definitions, [
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 9103, [], _formal_options(1, 3))
	var card_id := _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(not card_id.is_empty(), "词条标签：隐藏显示测试初始化失败，未抽到 qa_vanilla", failures)
	if card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, card_id, "front", 0, "test_keyword_badges_hidden")
	table._state = state
	var instance = state.card_instances.get(card_id)
	instance.flags["temporary_keyword_strong_attack_turn"] = state.turn_number
	instance.flags["temporary_keyword_pierce_turn"] = state.turn_number
	var definition: Dictionary = definitions_by_id.get("qa_vanilla", {})
	instance.face = "face_down"
	var face_down_badges: Array[String] = table._active_status_badges_for_card(instance, definition)
	_expect(face_down_badges.is_empty(), "词条标签：背面战场卡不应显示标签", failures)
	instance.face = "face_up"
	instance.zone = "hand"
	var hand_badges: Array[String] = table._active_status_badges_for_card(instance, definition)
	_expect(hand_badges.is_empty(), "词条标签：非战场区域卡牌不应显示标签", failures)
	_free_badge_harness(harness)


static func _test_gram_artifact_double_click_panel_hint(failures: Array[String]) -> void:
	var harness := _create_badge_harness()
	var definitions: Array = harness.get("definitions", [])
	var table = harness.get("table", null)
	var engine := GameEngine.new()
	var state = engine.create_game(definitions, [
		["asgard_s01_0317", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
		["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
	], 9107, [], _formal_options(1, 4))
	var gram_id := _find_hand_card_by_definition(state, 0, "asgard_s01_0317")
	_expect(not gram_id.is_empty(), "格拉墨交互：测试初始化失败，未抽到神剑格拉墨", failures)
	if gram_id.is_empty():
		_free_badge_harness(harness)
		return
	table._state = state
	_expect(table._source_requires_double_click_to_open_panel(gram_id), "格拉墨交互：神剑格拉墨应通过双击打开发动面板，避免单击抢先发动", failures)
	var hint: String = table._activation_unavailable_hint(gram_id)
	_expect(hint.contains("至少4张") and hint.contains("目前0张"), "格拉墨交互：墓地不足时应提示需要4张阿斯加德军团", failures)
	_free_badge_harness(harness)


static func _create_badge_harness() -> Dictionary:
	var definitions: Array = CardDatabase.load_definitions()
	var definitions_by_id := {}
	for row in definitions:
		if row is Dictionary:
			definitions_by_id[str(row.get("id", ""))] = (row as Dictionary).duplicate(true)
	var table = BattleTableScript.new()
	table._card_definitions = definitions_by_id
	return {
		"table": table,
		"definitions": definitions,
		"definitions_by_id": definitions_by_id
	}


static func _free_badge_harness(harness: Dictionary) -> void:
	var table = harness.get("table", null)
	if table != null:
		table.free()


static func _formal_options(opening_hand_size: int, opening_active_player_morale: int) -> Dictionary:
	return {
		"mode": "formal",
		"shuffle_player_decks": false,
		"opening_hand_size": opening_hand_size,
		"opening_active_player_morale": opening_active_player_morale,
		"opening_non_active_player_morale": 10
	}


static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
