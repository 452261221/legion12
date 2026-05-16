extends RefCounted
class_name TestAiCandidateBuilder

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_multi_target_candidates_have_unique_ids_and_schema(failures)
	_test_option_choice_expands_all_legal_options(failures)
	_test_single_card_choice_expands_each_card(failures)
	_test_two_card_choice_expands_combinations(failures)
	_test_three_card_choice_expands_full_combination(failures)
	_test_objective_candidate_fields_are_exposed(failures)
	_test_objective_consequence_fields_are_exposed(failures)
	_test_guard_candidate_reports_cards_and_tags(failures)
	_test_candidate_builder_dedupes_and_sorts_candidates(failures)
	return failures

static func _test_multi_target_candidates_have_unique_ids_and_schema(failures: Array[String]) -> void:
	var actions := [{
		"proposal_id": "declare_attack:attacker_a",
		"kind": "declare_attack",
		"command_type": "DeclareAttack",
		"label": "Attack with QA Attacker",
		"payload_template": {
			"attacker_id": "attacker_a"
		},
		"source": {
			"card_id": "attacker_a",
			"card_name": "QA Attacker",
			"play_kind": "attacker"
		},
		"target_mode": "card",
		"targets": [
			{"target_kind": "card", "defender_id": "defender_small"},
			{"target_kind": "master", "target_player": 1}
		]
	}]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 2, "candidate builder: multi-target attack should expand into two candidates", failures)
	if candidates.size() != 2:
		return
	var first := candidates[0]
	var second := candidates[1]
	_expect(not str(first.get("candidate_id", "")).is_empty(), "candidate builder: expanded candidate should expose candidate_id", failures)
	_expect(str(first.get("candidate_id", "")) != str(second.get("candidate_id", "")), "candidate builder: expanded candidates should have unique candidate_id values", failures)
	_expect(str(first.get("proposal_id", "")) == "declare_attack:attacker_a", "candidate builder: expanded candidate should preserve proposal_id", failures)
	_expect(not str(first.get("description", "")).is_empty(), "candidate builder: expanded candidate should include description", failures)
	_expect(not str(first.get("cost_summary", "")).is_empty(), "candidate builder: expanded candidate should include cost_summary", failures)
	_expect(not str(first.get("risk_summary", "")).is_empty(), "candidate builder: expanded candidate should include risk_summary", failures)
	_expect(first.get("source", {}) is Dictionary, "candidate builder: expanded candidate should expose source", failures)
	_expect(first.get("target", {}) is Dictionary, "candidate builder: expanded candidate should expose target", failures)
	var first_identity = first.get("identity", {})
	_expect(first_identity is Dictionary and str(first_identity.get("candidate_id", "")) == str(first.get("candidate_id", "")), "candidate builder: identity group should mirror candidate_id", failures)
	_expect(first_identity is Dictionary and str(first_identity.get("command_type", "")) == "DeclareAttack", "candidate builder: identity group should mirror command_type", failures)
	_expect(str(first.get("source_card_id", "")) == "attacker_a", "candidate builder: attack candidate should expose source_card_id", failures)
	_expect(str(first.get("target_card_id", "")) == "defender_small", "candidate builder: attack candidate should expose target_card_id", failures)
	_expect(int(second.get("target_player_id", -1)) == 1, "candidate builder: master-target attack should expose target_player_id", failures)
	var second_target_summary = second.get("target_summary", {})
	_expect(second_target_summary is Dictionary and str(second_target_summary.get("target_kind", "")) == "master", "candidate builder: target_summary should preserve target_kind", failures)
	var first_source_target = first.get("source_target", {})
	_expect(first_source_target is Dictionary and str(first_source_target.get("source_card_id", "")) == "attacker_a", "candidate builder: source_target group should mirror source_card_id", failures)
	_expect(first.get("involved_card_ids", []) is Array and first.get("involved_card_ids", []).has("attacker_a"), "candidate builder: involved_card_ids should include the attacker", failures)
	_expect(first.get("tags", []) is Array and first.get("tags", []).has("declare_attack"), "candidate builder: attack candidate should include kind tag", failures)

static func _test_option_choice_expands_all_legal_options(failures: Array[String]) -> void:
	var actions := [{
		"proposal_id": "resolve_choice:pick_mode",
		"kind": "resolve_choice",
		"command_type": "ResolveChoice",
		"label": "选择本回合效果",
		"choice_type": "option_pick",
		"payload_template": {
			"choice_id": "choice_001"
		},
		"options": [
			{"id": "draw_mode", "label": "抽牌模式"},
			{"id": "power_mode", "label": "兵力模式"}
		]
	}]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 2, "candidate builder: option choice should expand every legal option into a candidate", failures)
	if candidates.size() != 2:
		return
	var first := candidates[0]
	var second := candidates[1]
	_expect(str(first.get("payload", {}).get("selected_option", "")) == "draw_mode", "candidate builder: first option candidate should keep draw_mode payload", failures)
	_expect(str(second.get("payload", {}).get("selected_option", "")) == "power_mode", "candidate builder: second option candidate should keep power_mode payload", failures)
	_expect(str(first.get("description", "")).find("选择本回合效果") != -1, "candidate builder: choice candidate description should preserve the choice label", failures)
	_expect(first.get("target", {}) is Dictionary and str(first.get("target", {}).get("selected_option", "")) == "draw_mode", "candidate builder: first choice candidate should expose selected option in target summary", failures)
	_expect(second.get("target", {}) is Dictionary and str(second.get("target", {}).get("selected_option", "")) == "power_mode", "candidate builder: second choice candidate should expose selected option in target summary", failures)
	_expect(str(first.get("choice_type", "")) == "option_pick", "candidate builder: option choice should expose choice_type", failures)
	_expect(int(first.get("selection_count", 0)) == 1, "candidate builder: option choice should expose selection_count", failures)
	_expect(str(first.get("selected_option_label", "")) == "抽牌模式", "candidate builder: option choice should expose selected option label", failures)
	_expect(first.get("tags", []) is Array and first.get("tags", []).has("option_pick"), "candidate builder: option choice should include option_pick tag", failures)

static func _test_single_card_choice_expands_each_card(failures: Array[String]) -> void:
	var actions := [{
		"proposal_id": "resolve_choice:pick_card",
		"kind": "resolve_choice",
		"command_type": "ResolveChoice",
		"label": "选择一张牌",
		"choice_type": "card_pick",
		"count": 1,
		"payload_template": {
			"choice_id": "choice_card_001"
		},
		"candidate_card_ids": ["card_a", "card_b", "card_c"]
	}]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 3, "candidate builder: single-card choice should expand each legal card into a candidate", failures)
	if candidates.size() != 3:
		return
	_expect(candidates[0].get("payload", {}).get("selected_card_ids", []) == ["card_a"], "candidate builder: first single-card choice should select card_a", failures)
	_expect(candidates[1].get("payload", {}).get("selected_card_ids", []) == ["card_b"], "candidate builder: second single-card choice should select card_b", failures)
	_expect(candidates[2].get("payload", {}).get("selected_card_ids", []) == ["card_c"], "candidate builder: third single-card choice should select card_c", failures)

static func _test_two_card_choice_expands_combinations(failures: Array[String]) -> void:
	var actions := [{
		"proposal_id": "resolve_choice:pick_two_cards",
		"kind": "resolve_choice",
		"command_type": "ResolveChoice",
		"label": "选择两张牌",
		"choice_type": "card_pick",
		"count": 2,
		"payload_template": {
			"choice_id": "choice_card_002"
		},
		"candidate_card_ids": ["card_a", "card_b", "card_c"]
	}]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 3, "candidate builder: two-card choice should expand all legal pairs into candidates", failures)
	if candidates.size() != 3:
		return
	_expect(candidates[0].get("payload", {}).get("selected_card_ids", []) == ["card_a", "card_b"], "candidate builder: first two-card choice should keep the first pair", failures)
	_expect(candidates[1].get("payload", {}).get("selected_card_ids", []) == ["card_a", "card_c"], "candidate builder: second two-card choice should keep the second pair", failures)
	_expect(candidates[2].get("payload", {}).get("selected_card_ids", []) == ["card_b", "card_c"], "candidate builder: third two-card choice should keep the third pair", failures)

static func _test_three_card_choice_expands_full_combination(failures: Array[String]) -> void:
	var actions := [{
		"proposal_id": "resolve_choice:pick_three_cards",
		"kind": "resolve_choice",
		"command_type": "ResolveChoice",
		"label": "选择三张牌",
		"choice_type": "card_pick",
		"count": 3,
		"payload_template": {
			"choice_id": "choice_card_003"
		},
		"candidate_card_ids": ["card_a", "card_b", "card_c", "card_d"]
	}]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 4, "candidate builder: three-card choice should expand all legal three-card combinations", failures)
	if candidates.size() != 4:
		return
	_expect(candidates[0].get("payload", {}).get("selected_card_ids", []) == ["card_a", "card_b", "card_c"], "candidate builder: first three-card choice should keep abc", failures)
	_expect(candidates[3].get("payload", {}).get("selected_card_ids", []) == ["card_b", "card_c", "card_d"], "candidate builder: last three-card choice should keep bcd", failures)

static func _test_objective_candidate_fields_are_exposed(failures: Array[String]) -> void:
	var actions := [
		{
			"proposal_id": "pass_priority:test",
			"kind": "pass_priority",
			"command_type": "PassPriority",
			"label": "让出优先权",
			"payload_template": {},
			"target_mode": "none"
		},
		{
			"proposal_id": "end_phase:test",
			"kind": "end_phase",
			"command_type": "EndPhase",
			"label": "结束阶段",
			"payload_template": {},
			"target_mode": "none"
		}
	]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 2, "candidate builder: pass/end actions should each expand into one candidate", failures)
	if candidates.size() != 2:
		return
	_expect(bool(candidates[0].get("passes_priority", false)), "candidate builder: pass_priority should expose passes_priority=true", failures)
	_expect(not bool(candidates[0].get("ends_phase", true)), "candidate builder: pass_priority should expose ends_phase=false", failures)
	_expect(bool(candidates[1].get("ends_phase", false)), "candidate builder: end_phase should expose ends_phase=true", failures)
	_expect(not bool(candidates[1].get("passes_priority", true)), "candidate builder: end_phase should expose passes_priority=false", failures)

static func _test_objective_consequence_fields_are_exposed(failures: Array[String]) -> void:
	var actions := [
		{
			"proposal_id": "play_card:tactic",
			"kind": "play_card",
			"command_type": "PlayCard",
			"play_kind": "tactic",
			"label": "施放战术",
			"payload_template": {
				"card_id": "tactic_card_a"
			},
			"cost": {
				"morale": 2,
				"discard_cards": 1
			},
			"target_mode": "none"
		},
		{
			"proposal_id": "move_legion:test",
			"kind": "move_legion",
			"command_type": "MoveLegion",
			"label": "移动军团",
			"payload_template": {
				"card_id": "legion_a"
			},
			"targets": [
				{"row": "front", "col": 1}
			]
		},
		{
			"proposal_id": "resolve_choice:test",
			"kind": "resolve_choice",
			"command_type": "ResolveChoice",
			"label": "处理选择",
			"choice_type": "option_pick",
			"payload_template": {
				"choice_id": "choice_900"
			},
			"options": [
				{"id": "option_a", "label": "选项A"}
			]
		}
	]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 3, "candidate builder: consequence field setup should expand into three candidates", failures)
	if candidates.size() != 3:
		return
	var play_candidate := candidates[0]
	var move_candidate := candidates[1]
	var choice_candidate := candidates[2]
	_expect(int(play_candidate.get("morale_cost", 0)) == 2, "candidate builder: play candidate should expose morale_cost", failures)
	_expect(int(play_candidate.get("discard_card_count", 0)) == 1, "candidate builder: play candidate should expose discard_card_count", failures)
	_expect(bool(play_candidate.get("enters_priority_window", false)), "candidate builder: tactic play should expose enters_priority_window", failures)
	_expect(bool(play_candidate.get("enters_stack_resolution", false)), "candidate builder: tactic play should expose enters_stack_resolution", failures)
	var play_costs = play_candidate.get("costs", {})
	_expect(play_costs is Dictionary and int(play_costs.get("morale_cost", 0)) == 2, "candidate builder: costs group should mirror morale_cost", failures)
	_expect(bool(move_candidate.get("changes_board_position", false)), "candidate builder: move candidate should expose changes_board_position", failures)
	_expect(not bool(move_candidate.get("enters_stack_resolution", true)), "candidate builder: move candidate should not expose enters_stack_resolution", failures)
	var move_consequences = move_candidate.get("consequences", {})
	_expect(move_consequences is Dictionary and bool(move_consequences.get("changes_board_position", false)), "candidate builder: consequences group should mirror move consequence fields", failures)
	_expect(bool(choice_candidate.get("resolves_pending_choice", false)), "candidate builder: resolve_choice candidate should expose resolves_pending_choice", failures)
	var choice_summaries = choice_candidate.get("summaries", {})
	_expect(choice_summaries is Dictionary and str(choice_summaries.get("description", "")).find("处理选择") != -1, "candidate builder: summaries group should mirror description", failures)

static func _test_guard_candidate_reports_cards_and_tags(failures: Array[String]) -> void:
	var actions := [{
		"proposal_id": "choose_defense:guard",
		"kind": "choose_defense",
		"command_type": "ChooseDefense",
		"label": "Guard master with QA Shield + QA Spear",
		"payload_template": {
			"master_guard_card_ids": ["guard_a", "guard_b"]
		},
		"source": {
			"card_name": "QA Shield + QA Spear",
			"defense_kind": "master_guard"
		},
		"target_mode": "none",
		"targets": []
	}]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 1, "candidate builder: guard choice should remain a single candidate", failures)
	if candidates.is_empty():
		return
	var candidate := candidates[0]
	var involved = candidate.get("involved_card_ids", [])
	_expect(involved is Array and involved.has("guard_a") and involved.has("guard_b"), "candidate builder: guard candidate should expose master guard card ids", failures)
	_expect(int(candidate.get("hand_guard_card_count", 0)) == 2, "candidate builder: guard candidate should expose hand_guard_card_count", failures)
	_expect(str(candidate.get("cost_summary", "")).find("手牌守卫主将") != -1, "candidate builder: guard candidate cost summary should mention master guard hand spend", failures)
	_expect(candidate.get("tags", []) is Array and candidate.get("tags", []).has("master_guard"), "candidate builder: guard candidate should expose master_guard tag", failures)
	_expect(str(candidate.get("risk_summary", "")).find("攻击响应窗口") != -1, "candidate builder: guard candidate risk summary should mention defense timing", failures)

static func _test_candidate_builder_dedupes_and_sorts_candidates(failures: Array[String]) -> void:
	var actions := [
		{
			"proposal_id": "end_phase:test",
			"kind": "end_phase",
			"command_type": "EndPhase",
			"label": "结束阶段",
			"payload_template": {},
			"target_mode": "none"
		},
		{
			"proposal_id": "resolve_choice:dup_cards",
			"kind": "resolve_choice",
			"command_type": "ResolveChoice",
			"label": "选择一张牌",
			"choice_type": "card_pick",
			"count": 1,
			"payload_template": {
				"choice_id": "dup_pick"
			},
			"candidate_card_ids": ["card_a", "card_a", "card_b"]
		},
		{
			"proposal_id": "pass_priority:test",
			"kind": "pass_priority",
			"command_type": "PassPriority",
			"label": "让出优先权",
			"payload_template": {},
			"target_mode": "none"
		}
	]
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(candidates.size() == 4, "candidate builder: duplicate resolve_choice options should be removed while keeping non-duplicate actions", failures)
	if candidates.size() != 4:
		return
	_expect(str(candidates[0].get("action_group", "")) == "choice", "candidate builder: choice actions should sort before pass/end groups", failures)
	_expect(str(candidates[0].get("action_group_label", "")) == "处理选择", "candidate builder: choice actions should expose action_group_label", failures)
	_expect(int(candidates[0].get("group_order", 999)) < int(candidates[3].get("group_order", 0)), "candidate builder: earlier groups should have smaller group_order", failures)
	_expect(str(candidates[2].get("action_group", "")) == "priority", "candidate builder: pass priority should expose priority group", failures)
	_expect(str(candidates[3].get("action_group", "")) == "phase", "candidate builder: end phase should expose phase group", failures)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
