extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const FakeLlmClient = preload("res://ai/llm/fake_llm_client.gd")


func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	table._on_ai_mode_selected(2)
	table._ai_use_llm = true
	var fake_llm = FakeLlmClient.new()
	fake_llm.set_mode("last_candidate")
	table._ai_controller.set_llm_client(fake_llm)
	table._ai_controller.set_policy_mode(table._ai_controller.POLICY_MODE_LLM, {
		"enabled": true,
		"llm_client": fake_llm
	})
	var duel_data := {
		"id": "llm_opening_special_setup_verify",
		"name": "llm_opening_special_setup_verify",
		"players": [
			{
				"name": "P1",
				"master_name": "雷神索尔",
				"master_id": "asgard_s02_03m1",
				"master_hp": 8,
				"master_max_hp": 8,
				"deck": ["asgard_s02_0305", "asgard_s02_0301", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
			},
			{
				"name": "P2",
				"master_name": "雷神索尔",
				"master_id": "asgard_s02_03m1",
				"master_hp": 8,
				"master_max_hp": 8,
				"deck": ["asgard_s02_0305", "asgard_s02_0301", "qa_blank", "qa_blank", "qa_blank", "qa_blank"]
			}
		]
	}
	var game_options: Dictionary = table.FORMAL_GAME_OPTIONS.duplicate(true)
	game_options["inline_duel_data"] = duel_data
	if not table._begin_formal_opening_flow("verify_llm_opening", game_options, "LLM正式开局验证", 73001):
		push_error("llm opening special setup verify: opening flow should start")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline and table._state == null:
		await process_frame
		if table._opening_overlay != null and table._opening_overlay.visible:
			await process_frame
	if table._state == null:
		push_error("llm opening special setup verify: duel state should be created")
		quit(1)
		return
	if fake_llm.get_request_count() <= 0:
		push_error("llm opening special setup verify: opening flow should call LLM candidate selection")
		quit(1)
		return
	var player0 = table._state.get_player(0)
	var player1 = table._state.get_player(1)
	if player0.artifact_zone.cards.is_empty() or player1.artifact_zone.cards.is_empty():
		push_error("llm opening special setup verify: fake LLM should be able to pick special opening options that place 安德华拉诺特")
		quit(1)
		return
	if not _hand_has_definition(table, 0, "asgard_s02_0301") or not _hand_has_definition(table, 1, "asgard_s02_0301"):
		push_error("llm opening special setup verify: fake LLM should be able to pick special opening options that add 雷神之锤")
		quit(1)
		return
	print("llm opening special setup verify passed requests=%s" % str(fake_llm.get_request_count()))
	quit(0)


func _hand_has_definition(table, player_id: int, definition_id: String) -> bool:
	for card_id in table._state.get_player(player_id).hand.cards:
		var instance = table._state.card_instances.get(card_id, null)
		if instance != null and str(instance.definition_id) == definition_id:
			return true
	return false
