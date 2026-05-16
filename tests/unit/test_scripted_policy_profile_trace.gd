extends RefCounted
class_name TestScriptedPolicyProfileTrace

const CardDatabase = preload("res://rules/core/card_database.gd")
const ForcedRankingPolicy = preload("res://tests/unit/support/forced_ranking_policy.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const SequenceRankingPolicy = preload("res://tests/unit/support/sequence_ranking_policy.gd")
const ScriptedPolicyProfile = preload("res://ai/scripted/scripted_policy_profile.gd")
const VetoRankingPolicy = preload("res://tests/unit/support/veto_ranking_policy.gd")

class FakePriorityState extends RefCounted:
	var players := [{}, {}]
	var pending_attack: Dictionary = {}

class FakePriorityEngine extends RefCounted:
	var waiting_state: Dictionary = {"state": "WaitingForPriority"}
	var legal_actions: Array = []

	func get_waiting_state(_state) -> Dictionary:
		return waiting_state.duplicate(true)

	func get_legal_actions(_state, _player_id: int) -> Array:
		return legal_actions.duplicate(true)

class FakeCardInstance extends RefCounted:
	var definition_id := ""

class FakePlayCardState extends RefCounted:
	var card_instances: Dictionary = {}
	var definitions: Dictionary = {}

	func get_definition(definition_id: String):
		return definitions.get(definition_id)

static func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: card definitions are empty")
		return failures
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		992,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var actions := engine.get_legal_actions(state, 0)
	_expect(not actions.is_empty(), "profile trace: player 0 should have legal actions", failures)
	if actions.is_empty():
		return failures
	var policy := ScriptedPolicyProfile.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(not decision.is_empty(), "profile trace: decision should not be empty", failures)
	_expect(not str(decision.get("candidate_id", "")).is_empty(), "profile trace: decision should expose selected candidate_id", failures)
	_expect(str(decision.get("profile_id", "")) == "takamagahara_starter_tempo", "profile trace: decision should expose selected profile", failures)
	_expect(not str(decision.get("stage_id", "")).is_empty(), "profile trace: decision should expose selected stage", failures)
	_expect(decision.has("stage_reasons"), "profile trace: decision should include stage reasons", failures)
	_expect(decision.has("opponent_guess"), "profile trace: decision should include opponent guess", failures)
	_expect(decision.has("score_trace"), "profile trace: decision should include score trace", failures)
	_expect(decision.has("bucket_totals"), "profile trace: decision should include bucket totals", failures)
	_expect(decision.has("feature_summary"), "profile trace: decision should include feature summary", failures)
	_expect(not str(decision.get("feature_summary", "")).is_empty(), "profile trace: feature summary should not be empty", failures)
	_expect(decision.has("simulation_score"), "profile trace: decision should include simulation score", failures)
	_expect(decision.has("simulation_summary"), "profile trace: decision should include simulation summary", failures)
	_expect(decision.has("simulation_breakdown"), "profile trace: decision should include simulation breakdown", failures)
	_expect(decision.has("top_candidates"), "profile trace: decision should include top candidates", failures)
	_expect(decision.has("script_analysis"), "profile trace: decision should include script_analysis", failures)
	var top_candidates = decision.get("top_candidates", [])
	var script_analysis = decision.get("script_analysis", [])
	_expect(top_candidates is Array and not top_candidates.is_empty(), "profile trace: top candidates should be a non-empty array", failures)
	_expect(script_analysis is Array and not script_analysis.is_empty(), "profile trace: script_analysis should be a non-empty array", failures)
	if top_candidates is Array and not top_candidates.is_empty():
		_expect(not str(top_candidates[0].get("candidate_id", "")).is_empty(), "profile trace: top candidate should expose candidate_id", failures)
		_expect(not str(top_candidates[0].get("feature_summary", "")).is_empty(), "profile trace: top candidate should expose feature summary", failures)
		_expect(top_candidates[0].has("simulation_score"), "profile trace: top candidate should expose simulation score", failures)
		_expect(top_candidates[0].has("simulation_summary"), "profile trace: top candidate should expose simulation summary", failures)
		_expect(top_candidates[0].has("simulation_breakdown"), "profile trace: top candidate should expose simulation breakdown", failures)
	if script_analysis is Array and not script_analysis.is_empty():
		var chosen_analysis := _find_script_analysis(script_analysis, str(decision.get("candidate_id", "")))
		_expect(not chosen_analysis.is_empty(), "profile trace: chosen candidate should have script_analysis entry", failures)
		if not chosen_analysis.is_empty():
			_expect(chosen_analysis.get("objective_facts", []) is Array, "profile trace: chosen script_analysis should include objective facts", failures)
			_expect(chosen_analysis.get("heuristic_notes", []) is Array, "profile trace: chosen script_analysis should include heuristic notes", failures)
			_expect(chosen_analysis.get("warnings", []) is Array, "profile trace: chosen script_analysis should include warnings array", failures)
	_expect(not str(decision.get("debug_summary", "")).is_empty(), "profile trace: decision should include debug summary", failures)
	_expect(str(decision.get("debug_summary", "")).find("stage=") != -1, "profile trace: debug summary should include stage id", failures)
	_expect(str(decision.get("debug_summary", "")).find("final=") != -1, "profile trace: debug summary should include final score", failures)
	_test_invalid_top_candidate_is_skipped(failures)
	_test_suicidal_attack_veto(failures)
	_test_stronger_defender_attack_veto(failures)
	_test_end_phase_skips_available_attack_veto(failures)
	_test_end_phase_skips_master_attack_veto(failures)
	_test_pass_priority_master_defense_veto(failures)
	_test_pass_priority_available_response_veto(failures)
	_test_multi_guard_cheaper_defense_veto(failures)
	_test_empty_followup_effect_veto(failures)
	_test_end_phase_skips_effect_value_veto(failures)
	_test_end_phase_skips_play_develop_veto(failures)
	_test_end_phase_skips_effect_combo_veto(failures)
	_test_end_phase_skips_play_combo_veto(failures)
	_test_end_phase_skips_move_develop_veto(failures)
	_test_end_phase_skips_move_combo_veto(failures)
	_test_move_legion_followup_sequence_rerank(failures)
	_test_pass_priority_available_defense_reason(failures)
	_test_pass_priority_effect_response_reason(failures)
	_test_pass_priority_counter_tactic_reason(failures)
	_test_priority_response_preference_bonus_ordering(failures)
	_test_choose_defense_preference_bonus_ordering(failures)
	_test_play_card_preference_bonus_ordering(failures)
	_test_attack_followup_pressure_sequence_rerank(failures)
	_test_play_card_followup_sequence_rerank(failures)
	_test_activate_effect_followup_play_card_sequence_rerank(failures)
	_test_move_legion_skips_available_attack_veto(failures)
	_test_prefer_killable_defender_over_nonlethal_target(failures)
	_test_coordinated_clear_plan_allows_high_threat_target(failures)
	return failures

static func _test_invalid_top_candidate_is_skipped(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: invalid-top setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		993,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var attacker_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	var defender_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not attacker_id.is_empty() and not defender_id.is_empty(), "profile trace: invalid-top setup should draw attacker and defender", failures)
	if attacker_id.is_empty() or defender_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, attacker_id, "back", 0, "test_profile_trace_back_attacker")
	engine._deploy_hand_card_to_slot(state, 1, defender_id, "front", 0, "test_profile_trace_front_defender")
	var attacker = state.card_instances.get(attacker_id)
	if attacker != null:
		attacker.entered_turn = -1
		attacker.orientation = "active"
	var defender = state.card_instances.get(defender_id)
	if defender != null:
		defender.entered_turn = -1
		defender.orientation = "active"
	var invalid_attack := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"target_kind": "card"
	}))
	_expect(not bool(invalid_attack.get("ok", false)) and str(invalid_attack.get("code", "")) == "UNSUPPORTED_RANGE", "profile trace: setup attack should be invalid due to unsupported range", failures)
	var policy := ForcedRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
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
	_expect(str(decision.get("command_type", "")) == "EndPhase", "profile trace: policy should skip a currently invalid top-ranked candidate", failures)

static func _test_suicidal_attack_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: suicidal-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		994,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var attacker_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	var defender_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not attacker_id.is_empty() and not defender_id.is_empty(), "profile trace: suicidal-veto setup should draw attacker and defender", failures)
	if attacker_id.is_empty() or defender_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, attacker_id, "front", 0, "test_profile_trace_veto_attacker")
	engine._deploy_hand_card_to_slot(state, 1, defender_id, "front", 0, "test_profile_trace_veto_defender")
	var attacker = state.card_instances.get(attacker_id)
	if attacker != null:
		attacker.entered_turn = -1
		attacker.orientation = "active"
	var defender = state.card_instances.get(defender_id)
	if defender != null:
		defender.entered_turn = -1
		defender.orientation = "active"
	var valid_attack := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"target_kind": "card"
	}))
	_expect(bool(valid_attack.get("ok", false)), "profile trace: suicidal-veto setup attack should be legal before veto", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"DeclareAttack": {
			"final_score": 9.0,
			"summary": "forced_suicidal_attack",
			"breakdown": {
				"self_board_loss": 1,
				"enemy_board_cleared": 0,
				"enemy_master_damage": 0,
				"self_board_gain": 0
			}
		},
		"EndPhase": {
			"final_score": 1.0,
			"summary": "forced_safe_fallback"
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
	_expect(str(decision.get("command_type", "")) == "EndPhase", "profile trace: veto should reject suicidal attack even when it is force-ranked first", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "DeclareAttack", "suicidal_attack_no_followup"), "profile trace: vetoed attack should remain visible in top candidates with veto reason", failures)
	_expect(not _find_script_analysis_by_warning(decision.get("script_analysis", []), "veto:suicidal_attack_no_followup").is_empty(), "profile trace: vetoed suicidal attack should remain visible in script_analysis warnings", failures)

static func _test_stronger_defender_attack_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: stronger-defender-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"],
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"]
		],
		996,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var attacker_id := _find_hand_card_by_definition(state, 0, "dev_legion_beta")
	var defender_id := _find_hand_card_by_definition(state, 1, "dev_legion_alpha")
	_expect(not attacker_id.is_empty() and not defender_id.is_empty(), "profile trace: stronger-defender-veto setup should draw attacker and defender", failures)
	if attacker_id.is_empty() or defender_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, attacker_id, "front", 0, "test_profile_trace_stronger_veto_attacker")
	engine._deploy_hand_card_to_slot(state, 1, defender_id, "front", 0, "test_profile_trace_stronger_veto_defender")
	var attacker = state.card_instances.get(attacker_id)
	if attacker != null:
		attacker.entered_turn = -1
		attacker.orientation = "active"
	var defender = state.card_instances.get(defender_id)
	if defender != null:
		defender.entered_turn = -1
		defender.orientation = "active"
	var valid_attack := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"target_kind": "card"
	}))
	_expect(bool(valid_attack.get("ok", false)), "profile trace: stronger-defender-veto setup attack should still be legal before veto", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"DeclareAttack": {
			"final_score": 9.0,
			"summary": "forced_attack_into_stronger_defender"
		},
		"EndPhase": {
			"final_score": 1.0,
			"summary": "forced_safe_fallback"
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
	_expect(str(decision.get("command_type", "")) == "EndPhase", "profile trace: veto should reject attacking a strictly stronger defender with no immediate payoff", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "DeclareAttack", "skip_stronger_defender_attack"), "profile trace: stronger-defender attack should expose veto reason in top candidates", failures)

static func _test_end_phase_skips_available_attack_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: end-phase-attack-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		1006,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var attacker_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	var defender_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not attacker_id.is_empty() and not defender_id.is_empty(), "profile trace: end-phase-attack-veto setup should draw attacker and defender", failures)
	if attacker_id.is_empty() or defender_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, attacker_id, "front", 0, "test_profile_trace_end_phase_attack_attacker")
	engine._deploy_hand_card_to_slot(state, 1, defender_id, "front", 0, "test_profile_trace_end_phase_attack_defender")
	var attacker = state.card_instances.get(attacker_id)
	if attacker != null:
		attacker.entered_turn = -1
		attacker.orientation = "active"
	var defender = state.card_instances.get(defender_id)
	if defender != null:
		defender.entered_turn = -1
		defender.orientation = "active"
	var valid_attack := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"target_kind": "card"
	}))
	_expect(bool(valid_attack.get("ok", false)), "profile trace: end-phase-attack-veto setup should have a legal attack", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"EndPhase": {
			"final_score": 9.0,
			"summary": "forced_premature_end"
		},
		"DeclareAttack": {
			"final_score": 1.0,
			"summary": "forced_attack_fallback"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		},
		{
			"kind": "declare_attack",
			"command_type": "DeclareAttack",
			"payload_template": {
				"attacker_id": attacker_id
			},
			"targets": [{
				"target_kind": "card",
				"defender_id": defender_id
			}]
		}
	])
	_expect(str(decision.get("command_type", "")) == "DeclareAttack", "profile trace: veto should reject ending the phase while a legal attack is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "EndPhase", "end_phase_skips_available_attack"), "profile trace: end phase should expose the available-attack veto reason", failures)

static func _test_end_phase_skips_master_attack_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: end-phase-master-attack-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		1008,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var attacker_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not attacker_id.is_empty(), "profile trace: end-phase-master-attack-veto setup should draw attacker", failures)
	if attacker_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, attacker_id, "front", 0, "test_profile_trace_end_phase_master_attack_attacker")
	var attacker = state.card_instances.get(attacker_id)
	if attacker != null:
		attacker.entered_turn = -1
		attacker.orientation = "active"
	var valid_attack := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "master",
		"target_player": 1
	}))
	_expect(bool(valid_attack.get("ok", false)), "profile trace: end-phase-master-attack-veto setup should have a legal master attack", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"EndPhase": {
			"final_score": 9.0,
			"summary": "forced_premature_end"
		},
		"DeclareAttack": {
			"final_score": 1.0,
			"summary": "forced_master_attack_fallback"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		},
		{
			"kind": "declare_attack",
			"command_type": "DeclareAttack",
			"payload_template": {
				"attacker_id": attacker_id,
				"target_kind": "master",
				"target_player": 1
			}
		}
	])
	_expect(str(decision.get("command_type", "")) == "DeclareAttack" and str(decision.get("payload", {}).get("target_kind", "")) == "master", "profile trace: veto should reject ending the phase while a legal master attack is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "EndPhase", "end_phase_skips_master_attack"), "profile trace: end phase should expose the master-attack veto reason", failures)

static func _test_pass_priority_master_defense_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: pass-priority-defense-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		997,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 8, "master_max_hp": 8},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var blocker_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	var attacker_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not blocker_id.is_empty() and not attacker_id.is_empty(), "profile trace: pass-priority-defense-veto setup should draw blocker and attacker", failures)
	if blocker_id.is_empty() or attacker_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": blocker_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: pass-priority-defense-veto should deploy blocker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: pass-priority-defense-veto should deploy attacker", failures)
	var attacker_instance_id := str(state.players[1].battle_front[0].occupant)
	var blocker_instance_id := str(state.players[0].battle_front[0].occupant)
	state.pending_attack = {
		"attacker_id": attacker_instance_id,
		"target_kind": "master",
		"target_player": 0
	}
	state.priority_player = 0
	var waiting := engine.get_waiting_state(state)
	_expect(str(waiting.get("state", "")) == "WaitingForPriority", "profile trace: pass-priority-defense-veto setup should be waiting for priority", failures)
	var defense_check := engine.validate_command(state, GameCommand.create(0, "ChooseDefense", {
		"blocker_id": blocker_instance_id
	}))
	_expect(bool(defense_check.get("ok", false)), "profile trace: pass-priority-defense-veto should have a legal blocker defense", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"PassPriority": {
			"final_score": 9.0,
			"summary": "forced_bad_pass_priority"
		},
		"ChooseDefense": {
			"final_score": 1.0,
			"summary": "forced_defense_fallback"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "pass_priority",
			"command_type": "PassPriority",
			"payload_template": {}
		},
		{
			"kind": "choose_defense",
			"command_type": "ChooseDefense",
			"payload_template": {
				"blocker_id": blocker_instance_id
			}
		}
	])
	_expect(str(decision.get("command_type", "")) == "ChooseDefense", "profile trace: veto should reject pass priority when master defense is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "PassPriority", "pass_priority_skips_master_defense"), "profile trace: pass priority should expose master-defense veto reason", failures)

static func _test_pass_priority_available_response_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: pass-priority-response-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["asgard_s01_0312", "neutral_s01_0002", "neutral_s01_0015", "neutral_s01_0016", "takamagahara_s01_0419", "takamagahara_s01_0417"],
			["takamagahara_s01_0404", "neutral_s01_0015", "neutral_s01_0016", "asgard_s01_0318", "asgard_s01_0306", "asgard_s01_0312"]
		],
		1007,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 8, "master_max_hp": 8},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 1
	})).ok, "profile trace: pass-priority-response-veto should add morale for defender deployment", failures)
	var defender_card_id := _find_hand_card_by_definition(state, 0, "asgard_s01_0312")
	_expect(not defender_card_id.is_empty(), "profile trace: pass-priority-response-veto setup should draw the defender", failures)
	if defender_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": defender_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: pass-priority-response-veto should deploy the defender", failures)
	var defender_instance_id := str(state.get_player(0).battle_front[0].occupant)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: pass-priority-response-veto should reach player 2 main")
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "profile trace: pass-priority-response-veto should add morale for attacker deployment", failures)
	var attacker_card_id := _find_hand_card_by_definition(state, 1, "takamagahara_s01_0404")
	_expect(not attacker_card_id.is_empty(), "profile trace: pass-priority-response-veto setup should draw the attacker", failures)
	if attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: pass-priority-response-veto should deploy the attacker", failures)
	_expect(engine.apply_command(state, GameCommand.create(0, "PassPriority")).ok, "profile trace: pass-priority-response-veto attacker enter trigger first pass should succeed", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PassPriority")).ok, "profile trace: pass-priority-response-veto attacker enter trigger second pass should resolve", failures)
	var attacker_instance_id := str(state.get_player(1).battle_front[0].occupant)
	_expect(engine.apply_command(state, GameCommand.create(1, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id
	})).ok, "profile trace: pass-priority-response-veto should declare the unit attack", failures)
	var response_actions := engine.get_legal_actions(state, 0)
	var response_payload := {}
	for action in response_actions:
		if str(action.get("kind", "")) != "play_card":
			continue
		var play_kind := str(action.get("play_kind", action.get("extra", {}).get("play_kind", "")))
		if play_kind == "hand_response":
			response_payload = action.get("payload_template", {}).duplicate(true)
			break
	_expect(not response_payload.is_empty(), "profile trace: pass-priority-response-veto should expose a hand response action", failures)
	if response_payload.is_empty():
		return
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["asgard_starter_grave_midrange", "takamagahara_starter_tempo"]
	})
	policy.set_forced_rows({
		"PassPriority": {
			"final_score": 9.0,
			"summary": "forced_bad_pass_priority"
		},
		"PlayCard": {
			"final_score": 1.0,
			"summary": "forced_response_fallback"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "pass_priority",
			"command_type": "PassPriority",
			"payload_template": {}
		},
		{
			"kind": "play_card",
			"command_type": "PlayCard",
			"play_kind": "hand_response",
			"payload_template": response_payload
		}
	])
	_expect(str(decision.get("command_type", "")) == "PlayCard", "profile trace: veto should reject pass priority when a hand response is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "PassPriority", "pass_priority_skips_hand_response"), "profile trace: pass priority should expose the hand-response veto reason", failures)

static func _test_multi_guard_cheaper_defense_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: multi-guard-defense-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		998,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 8, "master_max_hp": 8},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var blocker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	var attacker_card_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not blocker_card_id.is_empty() and not attacker_card_id.is_empty(), "profile trace: multi-guard-defense-veto setup should draw blocker and attacker", failures)
	if blocker_card_id.is_empty() or attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": blocker_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: multi-guard-defense-veto should deploy blocker", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: multi-guard-defense-veto should deploy attacker", failures)
	var attacker_instance_id := str(state.players[1].battle_front[0].occupant)
	var blocker_instance_id := str(state.players[0].battle_front[0].occupant)
	state.pending_attack = {
		"attacker_id": attacker_instance_id,
		"target_kind": "master",
		"target_player": 0
	}
	state.priority_player = 0
	var blocker_check := engine.validate_command(state, GameCommand.create(0, "ChooseDefense", {
		"blocker_id": blocker_instance_id
	}))
	_expect(bool(blocker_check.get("ok", false)), "profile trace: multi-guard-defense-veto should have a legal blocker defense", failures)
	var multi_guard_check := engine.validate_command(state, GameCommand.create(0, "ChooseDefense", {
		"master_guard_card_ids": state.players[0].hand.cards.slice(0, 2)
	}))
	_expect(bool(multi_guard_check.get("ok", false)), "profile trace: multi-guard-defense-veto should have a legal multi-card guard", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"ChooseDefense": {
			"final_score": 9.0,
			"summary": "forced_expensive_master_guard"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "choose_defense",
			"command_type": "ChooseDefense",
			"payload_template": {
				"master_guard_card_ids": state.players[0].hand.cards.slice(0, 2)
			}
		},
		{
			"kind": "choose_defense",
			"command_type": "ChooseDefense",
			"payload_template": {
				"blocker_id": blocker_instance_id
			}
		}
	])
	_expect(str(decision.get("command_type", "")) == "ChooseDefense" and str(decision.get("payload", {}).get("blocker_id", "")) == blocker_instance_id, "profile trace: veto should reject multi-card guard when a blocker defense exists", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "ChooseDefense", "prefer_non_guard_defense_over_multi_guard"), "profile trace: expensive multi-card guard should expose cheaper-defense veto reason", failures)

static func _test_empty_followup_effect_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: empty-followup-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["asgard_s01_0307", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		995,
		[
			{"name": "P1", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12},
			{"name": "P2", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9}
		]
	)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 5
	})).ok, "profile trace: empty-followup-veto setup should add morale for 阿尔维达", failures)
	var alvilda_id := _find_hand_card_by_definition(state, 0, "asgard_s01_0307")
	_expect(not alvilda_id.is_empty(), "profile trace: empty-followup-veto setup should draw 阿尔维达", failures)
	if alvilda_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": alvilda_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: empty-followup-veto setup should deploy 阿尔维达", failures)
	var alvilda_instance_id := str(state.get_player(0).battle_front[0].occupant)
	var valid_effect := engine.validate_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": alvilda_instance_id,
		"effect_id": "alvilda_blood_summon"
	}))
	_expect(bool(valid_effect.get("ok", false)), "profile trace: empty-followup-veto setup effect should be legal before veto", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["asgard_starter_grave_midrange", "takamagahara_starter_tempo"]
	})
	policy.set_forced_rows({
		"ActivateEffect": {
			"final_score": 9.0,
			"summary": "forced_empty_followup_effect"
		},
		"EndPhase": {
			"final_score": 1.0,
			"summary": "forced_safe_fallback"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "activate_effect",
			"command_type": "ActivateEffect",
			"payload_template": {
				"source_id": alvilda_instance_id,
				"effect_id": "alvilda_blood_summon"
			}
		},
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		}
	])
	_expect(str(decision.get("command_type", "")) == "EndPhase", "profile trace: veto should reject empty follow-up self-sacrifice effects", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "ActivateEffect", "effect_followup_missing"), "profile trace: vetoed effect should expose missing follow-up reason in top candidates", failures)

static func _test_end_phase_skips_effect_value_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: end-phase-effect-value-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["qa_taka_legion_a", "qa_taka_legion_b", "qa_blank", "qa_blank"],
			["qa_enemy_zero", "qa_enemy_one", "qa_blank", "qa_blank"]
		],
		10085,
		[
			{"name": "P1", "master_name": "天照大神", "master_id": "takamagahara_s01_04m1", "master_hp": 8, "master_max_hp": 8},
			{"name": "P2", "master_name": "洛基", "master_id": "asgard_s01_03m2a", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var enemy_zero := _find_hand_card_by_definition(state, 1, "qa_enemy_zero")
	var enemy_one := _find_hand_card_by_definition(state, 1, "qa_enemy_one")
	_expect(not enemy_zero.is_empty() and not enemy_one.is_empty(), "profile trace: end-phase-effect-value-veto setup should draw both enemy targets", failures)
	if enemy_zero.is_empty() or enemy_one.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, enemy_one, "front", 0, "test_profile_trace_effect_value_enemy_one")
	engine._deploy_hand_card_to_slot(state, 1, enemy_zero, "front", 1, "test_profile_trace_effect_value_enemy_zero")
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 2
	})).ok, "profile trace: end-phase-effect-value-veto should add morale for the master effect", failures)
	var activate_payload := {
		"source_id": "master_0",
		"effect_id": "amaterasu_weaken_then_destroy_zero",
		"target_card_id": enemy_one
	}
	var activate_check := engine.validate_command(state, GameCommand.create(0, "ActivateEffect", activate_payload))
	_expect(bool(activate_check.get("ok", false)), "profile trace: end-phase-effect-value-veto setup should have a legal immediate-value effect", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"EndPhase": {
			"final_score": 9.0,
			"summary": "forced_premature_end"
		},
		"ActivateEffect": {
			"final_score": 1.0,
			"summary": "forced_effect_value_fallback",
			"breakdown": {
				"enemy_board_cleared": 1
			}
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		},
		{
			"kind": "activate_effect",
			"command_type": "ActivateEffect",
			"payload_template": activate_payload
		}
	])
	_expect(str(decision.get("command_type", "")) == "ActivateEffect", "profile trace: veto should reject ending the phase while an immediate-value effect is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "EndPhase", "end_phase_skips_effect_value"), "profile trace: end phase should expose the effect-value veto reason", failures)

static func _test_end_phase_skips_effect_combo_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: end-phase-effect-combo-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["qa_trial", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		1009,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false,
			"opening_active_player_morale": 1,
			"opening_non_active_player_morale": 0
		}
	)
	var trial_card_id := _find_hand_card_by_definition(state, 0, "qa_trial")
	var vanilla_card_id := _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(not trial_card_id.is_empty() and not vanilla_card_id.is_empty(), "profile trace: end-phase-effect-combo-veto setup should draw qa_trial and qa_vanilla", failures)
	if trial_card_id.is_empty() or vanilla_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": trial_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: end-phase-effect-combo-veto should deploy qa_trial", failures)
	var trial_instance_id := str(state.get_player(0).battle_front[0].occupant)
	_expect(not trial_instance_id.is_empty(), "profile trace: end-phase-effect-combo-veto should keep qa_trial on board", failures)
	if trial_instance_id.is_empty():
		return
	var activate_payload := {
		"source_id": trial_instance_id,
		"effect_id": "trial_progress"
	}
	var activate_check := engine.validate_command(state, GameCommand.create(0, "ActivateEffect", activate_payload))
	_expect(bool(activate_check.get("ok", false)), "profile trace: end-phase-effect-combo-veto should have a legal morale effect", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"EndPhase": {
			"final_score": 9.0,
			"summary": "forced_premature_end"
		},
		"ActivateEffect": {
			"final_score": 1.0,
			"summary": "forced_effect_combo_fallback",
			"followup_sequence_score": 1.0,
			"followup_sequence_summary": "followup:PlayCard"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		},
		{
			"kind": "activate_effect",
			"command_type": "ActivateEffect",
			"payload_template": activate_payload
		}
	])
	_expect(str(decision.get("command_type", "")) == "ActivateEffect", "profile trace: veto should reject ending the phase while an effect combo line is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "EndPhase", "end_phase_skips_effect_combo"), "profile trace: end phase should expose the effect-combo veto reason", failures)

static func _test_end_phase_skips_play_develop_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: end-phase-play-develop-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		1010,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)
	var card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not card_id.is_empty(), "profile trace: end-phase-play-develop-veto setup should draw a legion", failures)
	if card_id.is_empty():
		return
	var play_payload := {
		"card_id": card_id,
		"row": "front",
		"col": 0
	}
	var play_check := engine.validate_command(state, GameCommand.create(0, "PlayCard", play_payload))
	_expect(bool(play_check.get("ok", false)), "profile trace: end-phase-play-develop-veto setup should have a legal deploy", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"EndPhase": {
			"final_score": 9.0,
			"summary": "forced_premature_end"
		},
		"PlayCard": {
			"final_score": 1.0,
			"summary": "forced_play_develop_fallback",
			"breakdown": {
				"self_front_gain": 1,
				"self_board_gain": 1
			}
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		},
		{
			"kind": "play_card",
			"command_type": "PlayCard",
			"payload_template": play_payload
		}
	])
	_expect(str(decision.get("command_type", "")) == "PlayCard", "profile trace: veto should reject ending the phase while a proactive deploy is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "EndPhase", "end_phase_skips_play_develop"), "profile trace: end phase should expose the play-develop veto reason", failures)

static func _test_end_phase_skips_play_combo_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: end-phase-play-combo-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		1011,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false
		}
	)
	var first_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not first_card_id.is_empty(), "profile trace: end-phase-play-combo-veto setup should draw the first legion", failures)
	if first_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: end-phase-play-combo-veto should deploy the first legion", failures)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: end-phase-play-combo-veto should reach player 2 main")
	_advance_to_player_main(engine, state, 0, failures, "profile trace: end-phase-play-combo-veto should return to player 1 main")
	var second_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not second_card_id.is_empty(), "profile trace: end-phase-play-combo-veto should keep one more playable legion", failures)
	if second_card_id.is_empty():
		return
	var play_payload := {
		"card_id": second_card_id,
		"row": "back",
		"col": 1
	}
	var play_check := engine.validate_command(state, GameCommand.create(0, "PlayCard", play_payload))
	_expect(bool(play_check.get("ok", false)), "profile trace: end-phase-play-combo-veto setup should have a legal combo deploy", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"EndPhase": {
			"final_score": 9.0,
			"summary": "forced_premature_end"
		},
		"PlayCard": {
			"final_score": 1.0,
			"summary": "forced_play_combo_fallback",
			"followup_sequence_score": 1.0,
			"followup_sequence_summary": "followup:DeclareAttack"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		},
		{
			"kind": "play_card",
			"command_type": "PlayCard",
			"payload_template": play_payload
		}
	])
	_expect(str(decision.get("command_type", "")) == "PlayCard", "profile trace: veto should reject ending the phase while a play-card combo line is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "EndPhase", "end_phase_skips_play_combo"), "profile trace: end phase should expose the play-combo veto reason", failures)

static func _test_end_phase_skips_move_develop_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: end-phase-move-develop-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		10115,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false
		}
	)
	var mover_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not mover_card_id.is_empty(), "profile trace: end-phase-move-develop-veto setup should draw the mover", failures)
	if mover_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mover_card_id,
		"row": "back",
		"col": 1
	})).ok, "profile trace: end-phase-move-develop-veto should deploy the mover to the back row", failures)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: end-phase-move-develop-veto should reach player 2 main")
	_advance_to_player_main(engine, state, 0, failures, "profile trace: end-phase-move-develop-veto should return to player 1 main")
	var mover_instance_id := str(state.get_player(0).battle_back[1].occupant)
	_expect(not mover_instance_id.is_empty(), "profile trace: end-phase-move-develop-veto should keep the mover on board", failures)
	if mover_instance_id.is_empty():
		return
	var move_payload := {
		"card_id": mover_instance_id,
		"row": "front",
		"col": 1
	}
	var move_check := engine.validate_command(state, GameCommand.create(0, "MoveLegion", move_payload))
	_expect(bool(move_check.get("ok", false)), "profile trace: end-phase-move-develop-veto setup should have a legal front-develop move", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"EndPhase": {
			"final_score": 9.0,
			"summary": "forced_premature_end"
		},
		"MoveLegion": {
			"final_score": 1.0,
			"summary": "forced_move_develop_fallback",
			"breakdown": {
				"self_front_gain": 1
			}
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		},
		{
			"kind": "move_legion",
			"command_type": "MoveLegion",
			"payload_template": move_payload
		}
	])
	_expect(str(decision.get("command_type", "")) == "MoveLegion", "profile trace: veto should reject ending the phase while a front-develop move is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "EndPhase", "end_phase_skips_move_develop"), "profile trace: end phase should expose the move-develop veto reason", failures)

static func _test_end_phase_skips_move_combo_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: end-phase-move-combo-veto setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		1012,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false
		}
	)
	var mover_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not mover_card_id.is_empty(), "profile trace: end-phase-move-combo-veto setup should draw the mover", failures)
	if mover_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mover_card_id,
		"row": "back",
		"col": 1
	})).ok, "profile trace: end-phase-move-combo-veto should deploy the mover to the back row", failures)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: end-phase-move-combo-veto should reach player 2 main")
	var enemy_card_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not enemy_card_id.is_empty(), "profile trace: end-phase-move-combo-veto setup should draw the enemy frontliner", failures)
	if enemy_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: end-phase-move-combo-veto should deploy the enemy frontliner", failures)
	_advance_to_player_main(engine, state, 0, failures, "profile trace: end-phase-move-combo-veto should return to player 1 main")
	var mover_instance_id := str(state.get_player(0).battle_back[1].occupant)
	_expect(not mover_instance_id.is_empty(), "profile trace: end-phase-move-combo-veto should keep the mover on board", failures)
	if mover_instance_id.is_empty():
		return
	var move_payload := {
		"card_id": mover_instance_id,
		"row": "front",
		"col": 1
	}
	var move_check := engine.validate_command(state, GameCommand.create(0, "MoveLegion", move_payload))
	_expect(bool(move_check.get("ok", false)), "profile trace: end-phase-move-combo-veto setup should have a legal move", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"EndPhase": {
			"final_score": 9.0,
			"summary": "forced_premature_end"
		},
		"MoveLegion": {
			"final_score": 1.0,
			"summary": "forced_move_combo_fallback",
			"followup_sequence_score": 1.0,
			"followup_sequence_summary": "followup:DeclareAttack"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		},
		{
			"kind": "move_legion",
			"command_type": "MoveLegion",
			"payload_template": move_payload
		}
	])
	_expect(str(decision.get("command_type", "")) == "MoveLegion", "profile trace: veto should reject ending the phase while a move-legion combo line is available", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "EndPhase", "end_phase_skips_move_combo"), "profile trace: end phase should expose the move-combo veto reason", failures)

static func _test_move_legion_followup_sequence_rerank(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: move-followup-sequence setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		999,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false
		}
	)
	var mover_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not mover_card_id.is_empty(), "profile trace: move-followup-sequence setup should draw the mover", failures)
	if mover_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": mover_card_id,
		"row": "back",
		"col": 1
	})).ok, "profile trace: move-followup-sequence should deploy the mover to the back row", failures)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: move-followup-sequence should reach player 2 main")
	var enemy_card_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not enemy_card_id.is_empty(), "profile trace: move-followup-sequence setup should draw the enemy frontliner", failures)
	if enemy_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: move-followup-sequence should deploy the enemy frontliner", failures)
	_advance_to_player_main(engine, state, 0, failures, "profile trace: move-followup-sequence should return to player 1 main")
	state.players[0].hand.cards.clear()
	state.players[1].hand.cards.clear()
	var actions := engine.get_legal_actions(state, 0)
	_expect(not actions.is_empty(), "profile trace: move-followup-sequence should have legal actions", failures)
	if actions.is_empty():
		return
	var policy := SequenceRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(str(decision.get("command_type", "")) == "MoveLegion", "profile trace: sequence rerank should choose the move that unlocks a follow-up attack", failures)
	_expect(float(decision.get("followup_sequence_score", 0.0)) > 0.0, "profile trace: sequence rerank should expose a positive follow-up sequence score", failures)
	_expect(str(decision.get("followup_sequence_summary", "")).find("followup:DeclareAttack") != -1, "profile trace: sequence rerank summary should mention the follow-up DeclareAttack", failures)
	var top_candidates = decision.get("top_candidates", [])
	if top_candidates is Array and not top_candidates.is_empty():
		_expect(float(top_candidates[0].get("followup_sequence_score", 0.0)) > 0.0, "profile trace: top candidate should carry the follow-up sequence score", failures)

static func _test_pass_priority_effect_response_reason(failures: Array[String]) -> void:
	var policy := ScriptedPolicyProfile.new()
	var engine := FakePriorityEngine.new()
	var state := FakePriorityState.new()
	engine.legal_actions = [{
		"kind": "activate_effect",
		"payload_template": {
			"source_id": "unit_1",
			"effect_id": "ambush_response"
		}
	}]
	var reason := policy._pass_priority_veto_reason(engine, state, 0)
	_expect(reason == "pass_priority_skips_effect_response", "profile trace: pass priority helper should distinguish effect responses", failures)

static func _test_pass_priority_available_defense_reason(failures: Array[String]) -> void:
	var policy := ScriptedPolicyProfile.new()
	var engine := FakePriorityEngine.new()
	var state := FakePriorityState.new()
	engine.legal_actions = [{
		"kind": "choose_defense",
		"payload_template": {
			"blocker_id": "unit_1"
		}
	}]
	var reason := policy._pass_priority_veto_reason(engine, state, 0)
	_expect(reason == "pass_priority_skips_available_defense", "profile trace: pass priority helper should distinguish available defense", failures)

static func _test_pass_priority_counter_tactic_reason(failures: Array[String]) -> void:
	var policy := ScriptedPolicyProfile.new()
	var engine := FakePriorityEngine.new()
	var state := FakePriorityState.new()
	engine.legal_actions = [{
		"kind": "play_card",
		"play_kind": "counter_tactic",
		"payload_template": {
			"card_id": "card_1"
		}
	}]
	var reason := policy._pass_priority_veto_reason(engine, state, 0)
	_expect(reason == "pass_priority_skips_counter_tactic", "profile trace: pass priority helper should distinguish counter tactics", failures)

static func _test_priority_response_preference_bonus_ordering(failures: Array[String]) -> void:
	var policy := ScriptedPolicyProfile.new()
	var choose_defense_bonus := float(policy._priority_response_preference_bonus({
		"kind": "choose_defense"
	}))
	var counter_tactic_bonus := float(policy._priority_response_preference_bonus({
		"kind": "play_card",
		"play_kind": "counter_tactic"
	}))
	var hand_response_bonus := float(policy._priority_response_preference_bonus({
		"kind": "play_card",
		"play_kind": "hand_response"
	}))
	var effect_response_bonus := float(policy._priority_response_preference_bonus({
		"kind": "activate_effect"
	}))
	var pass_priority_bonus := float(policy._priority_response_preference_bonus({
		"kind": "pass_priority"
	}))
	_expect(choose_defense_bonus > counter_tactic_bonus, "profile trace: priority response bonus should rank choose defense above counter tactic", failures)
	_expect(counter_tactic_bonus > hand_response_bonus, "profile trace: priority response bonus should rank counter tactic above hand response", failures)
	_expect(hand_response_bonus > effect_response_bonus, "profile trace: priority response bonus should rank hand response above effect response", failures)
	_expect(effect_response_bonus > pass_priority_bonus, "profile trace: priority response bonus should rank effect response above pass priority", failures)

static func _test_choose_defense_preference_bonus_ordering(failures: Array[String]) -> void:
	var policy := ScriptedPolicyProfile.new()
	var blocker_bonus := float(policy._choose_defense_preference_bonus({
		"kind": "choose_defense",
		"payload": {
			"blocker_id": "unit_1"
		}
	}))
	var supporter_bonus := float(policy._choose_defense_preference_bonus({
		"kind": "choose_defense",
		"payload": {
			"supporter_id": "unit_2"
		}
	}))
	var single_guard_bonus := float(policy._choose_defense_preference_bonus({
		"kind": "choose_defense",
		"payload": {
			"master_guard_card_ids": ["card_1"]
		}
	}))
	var multi_guard_bonus := float(policy._choose_defense_preference_bonus({
		"kind": "choose_defense",
		"payload": {
			"master_guard_card_ids": ["card_1", "card_2"]
		}
	}))
	_expect(blocker_bonus > supporter_bonus, "profile trace: defense preference bonus should rank blocker above supporter", failures)
	_expect(supporter_bonus > single_guard_bonus, "profile trace: defense preference bonus should rank supporter above single-card guard", failures)
	_expect(single_guard_bonus > multi_guard_bonus, "profile trace: defense preference bonus should rank single-card guard above multi-card guard", failures)

static func _test_play_card_preference_bonus_ordering(failures: Array[String]) -> void:
	var policy := ScriptedPolicyProfile.new()
	var state := FakePlayCardState.new()
	var cheap_front := FakeCardInstance.new()
	cheap_front.definition_id = "cheap_unit"
	var expensive_front := FakeCardInstance.new()
	expensive_front.definition_id = "expensive_unit"
	var cheap_back := FakeCardInstance.new()
	cheap_back.definition_id = "cheap_unit"
	state.card_instances = {
		"cheap_front_card": cheap_front,
		"expensive_front_card": expensive_front,
		"cheap_back_card": cheap_back
	}
	state.definitions = {
		"cheap_unit": {"cost": 1},
		"expensive_unit": {"cost": 3}
	}
	var cheap_front_bonus := float(policy._play_card_preference_bonus(state, {
		"kind": "play_card",
		"payload": {
			"card_id": "cheap_front_card",
			"row": "front"
		}
	}))
	var expensive_front_bonus := float(policy._play_card_preference_bonus(state, {
		"kind": "play_card",
		"payload": {
			"card_id": "expensive_front_card",
			"row": "front"
		}
	}))
	var cheap_back_bonus := float(policy._play_card_preference_bonus(state, {
		"kind": "play_card",
		"payload": {
			"card_id": "cheap_back_card",
			"row": "back"
		}
	}))
	var response_bonus := float(policy._play_card_preference_bonus(state, {
		"kind": "play_card",
		"play_kind": "hand_response",
		"payload": {
			"card_id": "cheap_front_card",
			"row": "front"
		}
	}))
	_expect(cheap_front_bonus > expensive_front_bonus, "profile trace: play-card preference bonus should rank cheaper front deploy above expensive front deploy", failures)
	_expect(cheap_front_bonus > cheap_back_bonus, "profile trace: play-card preference bonus should rank front deploy above back deploy", failures)
	_expect(cheap_back_bonus > response_bonus, "profile trace: play-card preference bonus should ignore response plays", failures)

static func _test_attack_followup_pressure_sequence_rerank(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: attack-followup-pressure setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		1000,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false
		}
	)
	_expect(engine.apply_command(state, GameCommand.create(0, "DebugCommand", {
		"action": "add_morale",
		"player_id": 0,
		"count": 3
	})).ok, "profile trace: coordinated-clear veto-exception should add morale for player 1", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "DebugCommand", {
		"action": "add_morale",
		"player_id": 1,
		"count": 3
	})).ok, "profile trace: coordinated-clear veto-exception should add morale for player 2", failures)
	var first_attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not first_attacker_card_id.is_empty(), "profile trace: attack-followup-pressure setup should draw the first attacker", failures)
	if first_attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: attack-followup-pressure should deploy the first attacker", failures)
	var second_attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not second_attacker_card_id.is_empty(), "profile trace: attack-followup-pressure setup should draw the second attacker", failures)
	if second_attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_attacker_card_id,
		"row": "front",
		"col": 1
	})).ok, "profile trace: attack-followup-pressure should deploy the second attacker", failures)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: attack-followup-pressure should reach player 2 main")
	var enemy_card_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not enemy_card_id.is_empty(), "profile trace: attack-followup-pressure setup should draw the enemy frontliner", failures)
	if enemy_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": enemy_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: attack-followup-pressure should deploy the enemy frontliner", failures)
	_advance_to_player_main(engine, state, 0, failures, "profile trace: attack-followup-pressure should return to player 1 main")
	state.players[0].hand.cards.clear()
	state.players[1].hand.cards.clear()
	var attacker_instance_id := str(state.get_player(0).battle_front[0].occupant)
	var defender_instance_id := str(state.get_player(1).battle_front[0].occupant)
	_expect(not attacker_instance_id.is_empty() and not defender_instance_id.is_empty(), "profile trace: attack-followup-pressure should keep both combatants on board", failures)
	if attacker_instance_id.is_empty() or defender_instance_id.is_empty():
		return
	var attack_check := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id,
		"target_kind": "card"
	}))
	_expect(bool(attack_check.get("ok", false)), "profile trace: attack-followup-pressure setup should have a legal attack", failures)
	var policy := SequenceRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "declare_attack",
			"command_type": "DeclareAttack",
			"payload_template": {
				"attacker_id": attacker_instance_id
			},
			"targets": [{
				"target_kind": "card",
				"defender_id": defender_instance_id
			}]
		},
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		}
	])
	_expect(str(decision.get("command_type", "")) == "DeclareAttack", "profile trace: sequence rerank should choose the attack that clears the last frontliner", failures)
	_expect(float(decision.get("followup_sequence_score", 0.0)) > 0.0, "profile trace: attack sequence rerank should expose positive follow-up pressure score", failures)
	_expect(str(decision.get("followup_sequence_summary", "")).find("followup:master_pressure") != -1, "profile trace: attack sequence rerank summary should mention follow-up master pressure", failures)

static func _test_play_card_followup_sequence_rerank(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: play-card-followup setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		1001,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false
		}
	)
	var first_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not first_card_id.is_empty(), "profile trace: play-card-followup setup should draw the first legion", failures)
	if first_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": first_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: play-card-followup should deploy the first legion", failures)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: play-card-followup should reach player 2 main")
	_advance_to_player_main(engine, state, 0, failures, "profile trace: play-card-followup should return to player 1 main")
	var existing_attacker_id := str(state.get_player(0).battle_front[0].occupant)
	var second_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not existing_attacker_id.is_empty() and not second_card_id.is_empty(), "profile trace: play-card-followup should keep one attacker and one playable legion", failures)
	if existing_attacker_id.is_empty() or second_card_id.is_empty():
		return
	var play_check := engine.validate_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": second_card_id,
		"row": "back",
		"col": 1
	}))
	_expect(bool(play_check.get("ok", false)), "profile trace: play-card-followup setup should have a legal board deploy", failures)
	var policy := SequenceRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "play_card",
			"command_type": "PlayCard",
			"payload_template": {
				"card_id": second_card_id,
				"row": "back",
				"col": 1
			}
		},
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		}
	])
	_expect(str(decision.get("command_type", "")) == "PlayCard", "profile trace: play-card follow-up sequence should keep the proactive deploy", failures)
	_expect(float(decision.get("followup_sequence_score", 0.0)) > 0.0, "profile trace: play-card follow-up should expose positive follow-up sequence score", failures)
	_expect(str(decision.get("followup_sequence_summary", "")).find("followup:DeclareAttack") != -1, "profile trace: play-card follow-up summary should mention the preserved attack line", failures)

static func _test_activate_effect_followup_play_card_sequence_rerank(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: activate-effect-followup setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["qa_trial", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"],
			["qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla", "qa_vanilla"]
		],
		1002,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false,
			"opening_active_player_morale": 1,
			"opening_non_active_player_morale": 0
		}
	)
	var trial_card_id := _find_hand_card_by_definition(state, 0, "qa_trial")
	var vanilla_card_id := _find_hand_card_by_definition(state, 0, "qa_vanilla")
	_expect(not trial_card_id.is_empty() and not vanilla_card_id.is_empty(), "profile trace: activate-effect-followup setup should draw qa_trial and qa_vanilla", failures)
	if trial_card_id.is_empty() or vanilla_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": trial_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: activate-effect-followup should deploy qa_trial", failures)
	var trial_instance_id := str(state.get_player(0).battle_front[0].occupant)
	_expect(not trial_instance_id.is_empty(), "profile trace: activate-effect-followup should keep qa_trial on board", failures)
	if trial_instance_id.is_empty():
		return
	var activate_check := engine.validate_command(state, GameCommand.create(0, "ActivateEffect", {
		"source_id": trial_instance_id,
		"effect_id": "trial_progress"
	}))
	_expect(bool(activate_check.get("ok", false)), "profile trace: activate-effect-followup should have a legal morale effect", failures)
	var play_before := engine.validate_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": vanilla_card_id,
		"row": "back",
		"col": 1
	}))
	_expect(not bool(play_before.get("ok", false)), "profile trace: activate-effect-followup should not be able to play qa_vanilla before gaining morale", failures)
	var policy := SequenceRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "activate_effect",
			"command_type": "ActivateEffect",
			"payload_template": {
				"source_id": trial_instance_id,
				"effect_id": "trial_progress"
			}
		},
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		}
	])
	_expect(str(decision.get("command_type", "")) == "ActivateEffect", "profile trace: activate-effect follow-up should prefer the morale combo line", failures)
	_expect(float(decision.get("followup_sequence_score", 0.0)) > 0.0, "profile trace: activate-effect follow-up should expose positive sequence score", failures)
	_expect(str(decision.get("followup_sequence_summary", "")).find("followup:PlayCard") != -1, "profile trace: activate-effect follow-up summary should mention the follow-up PlayCard", failures)

static func _test_move_legion_skips_available_attack_veto(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: move-skips-attack setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		1003,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false
		}
	)
	var attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not attacker_card_id.is_empty(), "profile trace: move-skips-attack setup should draw attacker", failures)
	if attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: move-skips-attack should deploy attacker", failures)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: move-skips-attack should reach player 2 main")
	var defender_card_id := _find_hand_card_by_definition(state, 1, "dev_legion_beta")
	_expect(not defender_card_id.is_empty(), "profile trace: move-skips-attack setup should draw defender", failures)
	if defender_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": defender_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: move-skips-attack should deploy defender", failures)
	_advance_to_player_main(engine, state, 0, failures, "profile trace: move-skips-attack should return to player 1 main")
	var attacker_instance_id := str(state.get_player(0).battle_front[0].occupant)
	var defender_instance_id := str(state.get_player(1).battle_front[0].occupant)
	_expect(not attacker_instance_id.is_empty() and not defender_instance_id.is_empty(), "profile trace: move-skips-attack should keep both units on board", failures)
	if attacker_instance_id.is_empty() or defender_instance_id.is_empty():
		return
	var attack_check := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": defender_instance_id,
		"target_kind": "card"
	}))
	_expect(bool(attack_check.get("ok", false)), "profile trace: move-skips-attack should have a legal attack before moving", failures)
	var move_check := engine.validate_command(state, GameCommand.create(0, "MoveLegion", {
		"card_id": attacker_instance_id,
		"row": "front",
		"col": 1
	}))
	_expect(bool(move_check.get("ok", false)), "profile trace: move-skips-attack should still allow a lateral move", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"MoveLegion": {
			"final_score": 9.0,
			"summary": "forced_useless_front_move",
			"breakdown": {
				"self_active_morale_loss": 1,
				"followup_attack_found": false
			}
		},
		"DeclareAttack": {
			"final_score": 1.0,
			"summary": "forced_attack_fallback"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "move_legion",
			"command_type": "MoveLegion",
			"payload_template": {
				"card_id": attacker_instance_id,
				"row": "front",
				"col": 1
			}
		},
		{
			"kind": "declare_attack",
			"command_type": "DeclareAttack",
			"payload_template": {
				"attacker_id": attacker_instance_id
			},
			"targets": [{
				"target_kind": "card",
				"defender_id": defender_instance_id
			}]
		}
	])
	_expect(str(decision.get("command_type", "")) == "DeclareAttack", "profile trace: veto should reject lateral move when the same frontliner can already attack", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "MoveLegion", "move_legion_skips_available_attack"), "profile trace: skipped-attack move should expose the available-attack veto reason", failures)

static func _test_prefer_killable_defender_over_nonlethal_target(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: killable-target setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["qa_ranged", "qa_ranged", "qa_ranged", "qa_ranged", "qa_ranged", "qa_ranged"],
			["qa_plain", "asgard_s01_0307", "qa_plain", "asgard_s01_0307", "qa_plain", "asgard_s01_0307"]
		],
		1004,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		],
		{
			"mode": "formal",
			"shuffle_player_decks": false
		}
	)
	var attacker_card_id := _find_hand_card_by_definition(state, 0, "qa_ranged")
	_expect(not attacker_card_id.is_empty(), "profile trace: killable-target setup should draw qa_ranged", failures)
	if attacker_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "back",
		"col": 0
	})).ok, "profile trace: killable-target should deploy qa_ranged to back row", failures)
	_advance_to_player_main(engine, state, 1, failures, "profile trace: killable-target should reach player 2 main")
	var small_defender_card_id := _find_hand_card_by_definition(state, 1, "qa_plain")
	var big_defender_card_id := _find_hand_card_by_definition(state, 1, "asgard_s01_0307")
	_expect(not small_defender_card_id.is_empty() and not big_defender_card_id.is_empty(), "profile trace: killable-target setup should draw both small and big defenders", failures)
	if small_defender_card_id.is_empty() or big_defender_card_id.is_empty():
		return
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": small_defender_card_id,
		"row": "front",
		"col": 0
	})).ok, "profile trace: killable-target should deploy the small defender", failures)
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": big_defender_card_id,
		"row": "front",
		"col": 1
	})).ok, "profile trace: killable-target should deploy the big defender", failures)
	_advance_to_player_main(engine, state, 0, failures, "profile trace: killable-target should return to player 1 main")
	var attacker_instance_id := str(state.get_player(0).battle_back[0].occupant)
	var small_defender_instance_id := str(state.get_player(1).battle_front[0].occupant)
	var big_defender_instance_id := str(state.get_player(1).battle_front[1].occupant)
	_expect(not attacker_instance_id.is_empty() and not small_defender_instance_id.is_empty() and not big_defender_instance_id.is_empty(), "profile trace: killable-target should keep all units on board", failures)
	if attacker_instance_id.is_empty() or small_defender_instance_id.is_empty() or big_defender_instance_id.is_empty():
		return
	var small_attack_check := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": small_defender_instance_id,
		"target_kind": "card"
	}))
	var big_attack_check := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": big_defender_instance_id,
		"target_kind": "card"
	}))
	_expect(bool(small_attack_check.get("ok", false)) and bool(big_attack_check.get("ok", false)), "profile trace: killable-target setup should have both attack targets legal", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"DeclareAttack": {
			"final_score": 9.0,
			"summary": "forced_bad_big_target"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "declare_attack",
			"command_type": "DeclareAttack",
			"payload_template": {
				"attacker_id": attacker_instance_id
			},
			"targets": [{
				"target_kind": "card",
				"defender_id": big_defender_instance_id
			}]
		},
		{
			"kind": "declare_attack",
			"command_type": "DeclareAttack",
			"payload_template": {
				"attacker_id": attacker_instance_id
			},
			"targets": [{
				"target_kind": "card",
				"defender_id": small_defender_instance_id
			}]
		}
	])
	_expect(str(decision.get("command_type", "")) == "DeclareAttack" and str(decision.get("payload", {}).get("defender_id", "")) == small_defender_instance_id, "profile trace: policy should prefer the killable defender over the nonlethal bigger target", failures)
	_expect(_top_candidate_has_veto(decision.get("top_candidates", []), "DeclareAttack", "prefer_killable_defender_over_nonlethal_target"), "profile trace: nonlethal big-target attack should expose the killable-target veto reason", failures)

static func _test_coordinated_clear_plan_allows_high_threat_target(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("profile trace: coordinated-clear veto-exception setup requires loaded definitions")
		return
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["qa_plain", "asgard_s01_0307", "qa_plain", "asgard_s01_0307", "qa_plain", "asgard_s01_0307"]
		],
		1005
	)
	var first_attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not first_attacker_card_id.is_empty(), "profile trace: coordinated-clear veto-exception setup should draw the first attacker", failures)
	if first_attacker_card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, first_attacker_card_id, "front", 0, "test_profile_trace_coordinated_first_attacker")
	var second_attacker_card_id := _find_hand_card_by_definition(state, 0, "dev_legion_alpha")
	_expect(not second_attacker_card_id.is_empty(), "profile trace: coordinated-clear veto-exception setup should draw the second attacker", failures)
	if second_attacker_card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 0, second_attacker_card_id, "front", 1, "test_profile_trace_coordinated_second_attacker")
	var small_defender_card_id := _find_hand_card_by_definition(state, 1, "qa_plain")
	var big_defender_card_id := _find_hand_card_by_definition(state, 1, "asgard_s01_0307")
	_expect(not small_defender_card_id.is_empty() and not big_defender_card_id.is_empty(), "profile trace: coordinated-clear veto-exception setup should draw both defenders", failures)
	if small_defender_card_id.is_empty() or big_defender_card_id.is_empty():
		return
	engine._deploy_hand_card_to_slot(state, 1, small_defender_card_id, "front", 0, "test_profile_trace_coordinated_small_defender")
	engine._deploy_hand_card_to_slot(state, 1, big_defender_card_id, "front", 1, "test_profile_trace_coordinated_big_defender")
	for instance_id in [first_attacker_card_id, second_attacker_card_id, small_defender_card_id, big_defender_card_id]:
		var instance = state.card_instances.get(instance_id)
		if instance != null:
			instance.entered_turn = -1
			instance.orientation = "active"
	var attacker_instance_id := str(state.get_player(0).battle_front[0].occupant)
	var big_defender_instance_id := str(state.get_player(1).battle_front[1].occupant)
	_expect(not attacker_instance_id.is_empty() and not big_defender_instance_id.is_empty(), "profile trace: coordinated-clear veto-exception should keep the big target and attacker on board", failures)
	if attacker_instance_id.is_empty() or big_defender_instance_id.is_empty():
		return
	var small_attack_available := false
	for action in engine.get_legal_actions(state, 0):
		if str(action.get("kind", "")) != "declare_attack":
			continue
		var payload_template: Dictionary = action.get("payload_template", {})
		if str(payload_template.get("attacker_id", "")) != attacker_instance_id:
			continue
		for target in action.get("targets", []):
			if str(target.get("target_kind", "card")) == "card":
				var defender_id := str(target.get("defender_id", target.get("target_card_id", "")))
				if defender_id != big_defender_instance_id:
					small_attack_available = true
					break
		if small_attack_available:
			break
	_expect(small_attack_available, "profile trace: coordinated-clear veto-exception should still have an alternative killable target", failures)
	var big_attack_check := engine.validate_command(state, GameCommand.create(0, "DeclareAttack", {
		"attacker_id": attacker_instance_id,
		"defender_id": big_defender_instance_id,
		"target_kind": "card"
	}))
	_expect(bool(big_attack_check.get("ok", false)), "profile trace: coordinated-clear veto-exception should have a legal big-target attack", failures)
	var policy := VetoRankingPolicy.new()
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	policy.set_forced_rows({
		"DeclareAttack": {
			"final_score": 9.0,
			"summary": "forced_coordinated_big_target"
		},
		"EndPhase": {
			"final_score": 1.0,
			"summary": "forced_safe_fallback"
		}
	})
	var decision := policy.choose(engine, state, 0, [
		{
			"kind": "declare_attack",
			"command_type": "DeclareAttack",
			"payload_template": {
				"attacker_id": attacker_instance_id
			},
			"targets": [{
				"target_kind": "card",
				"defender_id": big_defender_instance_id
			}]
		},
		{
			"kind": "end_phase",
			"command_type": "EndPhase",
			"payload_template": {}
		}
	])
	_expect(str(decision.get("command_type", "")) == "DeclareAttack" and str(decision.get("payload", {}).get("defender_id", "")) == big_defender_instance_id, "profile trace: coordinated clear plan should allow the high-threat target instead of vetoing it for the killable small target", failures)
	_expect(not _top_candidate_has_veto(decision.get("top_candidates", []), "DeclareAttack", "prefer_killable_defender_over_nonlethal_target"), "profile trace: coordinated clear big-target line should not expose the killable-target veto reason", failures)

static func _find_hand_card_by_definition(state, player_id: int, definition_id: String) -> String:
	var player = state.get_player(player_id)
	for card_id in player.hand.cards:
		var instance = state.card_instances.get(card_id)
		if instance != null and instance.definition_id == definition_id:
			return card_id
	return ""

static func _advance_to_player_main(engine: GameEngine, state, player_id: int, failures: Array[String], message: String) -> void:
	for _i in range(16):
		if state.phase == "main" and state.active_player == player_id:
			return
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase", {})).ok, message, failures)
	failures.append(message)

static func _top_candidate_has_veto(top_candidates, command_type: String, veto_reason: String) -> bool:
	if not (top_candidates is Array):
		return false
	for row in top_candidates:
		if str(row.get("command_type", "")) != command_type:
			continue
		if bool(row.get("vetoed", false)) and str(row.get("veto_reason", "")) == veto_reason:
			return true
	return false

static func _find_script_analysis(script_analysis, candidate_id: String) -> Dictionary:
	if not (script_analysis is Array) or candidate_id.is_empty():
		return {}
	for row in script_analysis:
		if not (row is Dictionary):
			continue
		if str(row.get("candidate_id", "")) == candidate_id:
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
