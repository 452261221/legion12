extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")
const FakeLlmClient = preload("res://ai/llm/fake_llm_client.gd")


func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var prompt := {
		"prompt_id": "opening_test_001",
		"stage": "opening_special_setup_0",
		"choice_type": "option_pick",
		"actor_player_id": 0,
		"title": "起手额外规则",
		"description": "测试",
		"status_text": "测试",
		"options": [
			{"id": "normal_opening", "label": "正常开局"},
			{"id": "andvaranot_only", "label": "置入安德华拉诺特"},
			{"id": "thor_hammer_only", "label": "拿雷神之锤"},
			{"id": "andvaranot_and_thor_hammer", "label": "两项都用"}
		]
	}
	var candidates: Array = table._opening_prompt_candidates(prompt)
	if candidates.size() != 4:
		push_error("opening option pick candidate verify: expected 4 candidates, got %s" % str(candidates.size()))
		quit(1)
		return
	var fake_llm = FakeLlmClient.new()
	fake_llm.set_mode("last_candidate")
	var request := {
		"task": "choose_one_candidate",
		"candidates": candidates
	}
	var llm_response: Dictionary = fake_llm.choose_candidate(request)
	if str(llm_response.get("candidate_id", "")) != "andvaranot_and_thor_hammer":
		push_error("opening option pick candidate verify: fake llm should be able to choose the last option candidate")
		quit(1)
		return
	print("opening option pick candidate verify passed")
	quit(0)
