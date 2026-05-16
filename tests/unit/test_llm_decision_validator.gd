extends RefCounted
class_name TestLlmDecisionValidator

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const DecisionValidator = preload("res://ai/llm/decision_validator.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_validator_accepts_existing_candidate_id(failures)
	_test_validator_rejects_unknown_candidate_id(failures)
	_test_validator_accepts_unique_command_type_without_candidate_id(failures)
	_test_validator_accepts_proposal_id_hint(failures)
	_test_validator_rejects_stale_waiting_state(failures)
	return failures

static func _test_validator_accepts_existing_candidate_id(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4401)
	var actions := engine.get_legal_actions(state, 0)
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(not candidates.is_empty(), "llm validator: setup should have candidates", failures)
	if candidates.is_empty():
		return
	var chosen := candidates[0]
	var validator := DecisionValidator.new()
	var result := validator.validate_response(engine, state, 0, actions, {
		"candidate_id": str(chosen.get("candidate_id", "")),
		"payload": {"tampered": true},
		"brief_reason": "pick first"
	}, engine.get_waiting_state(state))
	_expect(bool(result.get("ok", false)), "llm validator: existing candidate_id should validate", failures)
	if not bool(result.get("ok", false)):
		return
	_expect(str(result.get("candidate_id", "")) == str(chosen.get("candidate_id", "")), "llm validator: validated result should preserve candidate_id", failures)
	_expect(result.get("payload", {}) == chosen.get("payload", {}), "llm validator: validator should use local payload instead of model payload", failures)

static func _test_validator_rejects_unknown_candidate_id(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4402)
	var actions := engine.get_legal_actions(state, 0)
	var validator := DecisionValidator.new()
	var result := validator.validate_response(engine, state, 0, actions, {
		"candidate_id": "cand_missing"
	}, engine.get_waiting_state(state))
	_expect(not bool(result.get("ok", false)) and str(result.get("reason", "")) == "candidate_id_not_found", "llm validator: unknown candidate_id should be rejected", failures)

static func _test_validator_accepts_unique_command_type_without_candidate_id(failures: Array[String]) -> void:
	var validator := DecisionValidator.new()
	var actions := [{
		"proposal_id": "end_phase:test",
		"kind": "end_phase",
		"command_type": "EndPhase",
		"label": "结束阶段",
		"payload_template": {},
		"target_mode": "none"
	}]
	var engine := GameEngine.new()
	var state = _create_state(engine, 4404)
	var result := validator.validate_response(engine, state, 0, actions, {
		"command_type": "EndPhase"
	})
	_expect(bool(result.get("ok", false)), "llm validator: unique command_type should resolve without candidate_id", failures)
	if not bool(result.get("ok", false)):
		return
	_expect(str(result.get("command_type", "")) == "EndPhase", "llm validator: unique command_type resolution should preserve local command_type", failures)

static func _test_validator_accepts_proposal_id_hint(failures: Array[String]) -> void:
	var validator := DecisionValidator.new()
	var actions := [{
		"proposal_id": "end_phase:test",
		"kind": "end_phase",
		"command_type": "EndPhase",
		"label": "结束阶段",
		"payload_template": {},
		"target_mode": "none"
	}]
	var engine := GameEngine.new()
	var state = _create_state(engine, 4405)
	var result := validator.validate_response(engine, state, 0, actions, {
		"proposal_id": "end_phase:test"
	})
	_expect(bool(result.get("ok", false)), "llm validator: proposal_id hint should resolve candidate without candidate_id", failures)
	if not bool(result.get("ok", false)):
		return
	_expect(str(result.get("command_type", "")) == "EndPhase", "llm validator: proposal_id resolution should map to local command_type", failures)

static func _test_validator_rejects_stale_waiting_state(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4403)
	var actions := engine.get_legal_actions(state, 0)
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(not candidates.is_empty(), "llm validator: stale waiting-state setup should have candidates", failures)
	if candidates.is_empty():
		return
	var validator := DecisionValidator.new()
	var result := validator.validate_response(engine, state, 0, actions, {
		"candidate_id": str(candidates[0].get("candidate_id", ""))
	}, {
		"state": "WaitingForPriority",
		"player_id": 1
	})
	_expect(not bool(result.get("ok", false)) and str(result.get("reason", "")) == "stale_waiting_state", "llm validator: stale waiting-state response should be rejected", failures)

static func _create_state(engine: GameEngine, seed: int):
	return engine.create_game(
		CardDatabase.load_definitions(),
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		seed,
		[
			{"name": "P1", "master_id": "takamagahara_s01_04m2", "master_name": "须佐之男", "master_hp": 9, "master_max_hp": 9},
			{"name": "P2", "master_id": "asgard_s01_03m2a", "master_name": "洛基", "master_hp": 12, "master_max_hp": 12}
		]
	)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
