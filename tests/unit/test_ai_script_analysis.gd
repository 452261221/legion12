extends RefCounted
class_name TestAiScriptAnalysis

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ScriptedPolicyProfile = preload("res://ai/scripted/scripted_policy_profile.gd")
const VetoRankingPolicy = preload("res://tests/unit/support/veto_ranking_policy.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_decision_exposes_script_analysis(failures)
	_test_vetoed_candidate_keeps_warning(failures)
	return failures

static func _test_decision_exposes_script_analysis(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		4201,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var actions := engine.get_legal_actions(state, 0)
	_expect(not actions.is_empty(), "script analysis: initial setup should have legal actions", failures)
	if actions.is_empty():
		return
	var policy := ScriptedPolicyProfile.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(not decision.is_empty(), "script analysis: decision should not be empty", failures)
	_expect(not str(decision.get("candidate_id", "")).is_empty(), "script analysis: decision should expose candidate_id", failures)
	var script_analysis = decision.get("script_analysis", [])
	_expect(script_analysis is Array and not script_analysis.is_empty(), "script analysis: decision should include non-empty script_analysis", failures)
	if not (script_analysis is Array) or script_analysis.is_empty():
		return
	var selected_analysis := _find_script_analysis(script_analysis, str(decision.get("candidate_id", "")))
	_expect(not selected_analysis.is_empty(), "script analysis: selected candidate should have a matching analysis entry", failures)
	if selected_analysis.is_empty():
		return
	_expect(selected_analysis.get("objective_facts", []) is Array and not selected_analysis.get("objective_facts", []).is_empty(), "script analysis: selected candidate should expose objective facts", failures)
	_expect(selected_analysis.get("heuristic_notes", []) is Array and not selected_analysis.get("heuristic_notes", []).is_empty(), "script analysis: selected candidate should expose heuristic notes", failures)
	_expect(selected_analysis.get("warnings", []) is Array, "script analysis: selected candidate should expose warnings array", failures)

static func _test_vetoed_candidate_keeps_warning(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		4202,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var attacker_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	var defender_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not attacker_id.is_empty() and not defender_id.is_empty(), "script analysis: veto setup should draw attacker and defender", failures)
	if attacker_id.is_empty() or defender_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, attacker_id, "front", 0, "test_script_analysis_attacker")
	engine._deploy_hand_card_to_slot(state, 1, defender_id, "front", 0, "test_script_analysis_defender")
	var attacker = state.card_instances.get(attacker_id)
	var defender = state.card_instances.get(defender_id)
	if attacker != null:
		attacker.entered_turn = -1
		attacker.orientation = "active"
	if defender != null:
		defender.entered_turn = -1
		defender.orientation = "active"
		defender.damage_marked = 0
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"DeclareAttack": {
			"final_score": 8.0,
			"simulation_breakdown": {
				"self_board_loss": 1,
				"enemy_board_cleared": 0,
				"enemy_master_damage": 0,
				"self_board_gain": 0
			}
		},
		"EndPhase": {
			"final_score": 1.0
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "declare_attack",
			"command_type": "DeclareAttack",
			"payload_template": {"attacker_id": attacker_id},
			"targets": [{"target_kind": "card", "defender_id": defender_id}]
		},
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		}
	])
	var warned_analysis := _find_script_analysis_by_warning(decision.get("script_analysis", []), "veto:suicidal_attack_no_followup")
	_expect(not warned_analysis.is_empty(), "script analysis: vetoed suicidal attack should keep warning entry", failures)

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	for card_id in state.get_player(player_id).hand.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance != null and str(instance.definition_id) == definition_id:
			return str(card_id)
	return ""

static func _find_script_analysis(script_analysis, candidate_id: String) -> Dictionary:
	if not (script_analysis is Array) or candidate_id.is_empty():
		return {}
	for row in script_analysis:
		if row is Dictionary and str(row.get("candidate_id", "")) == candidate_id:
			return row
	return {}

static func _find_script_analysis_by_warning(script_analysis, warning_text: String) -> Dictionary:
	if not (script_analysis is Array) or warning_text.is_empty():
		return {}
	for row in script_analysis:
		if not (row is Dictionary):
			continue
		var warnings = row.get("warnings", [])
		if warnings is Array and warnings.has(warning_text):
			return row
	return {}

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
