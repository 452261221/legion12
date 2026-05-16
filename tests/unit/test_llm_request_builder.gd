extends RefCounted
class_name TestLlmRequestBuilder

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const LlmRequestBuilder = preload("res://ai/llm/llm_request_builder.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_request_builder_exposes_layered_context_without_removing_meta(failures)
	_test_request_builder_applies_opening_protocol_trim_to_prompt_fields(failures)
	return failures

static func _test_request_builder_exposes_layered_context_without_removing_meta(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4601)
	var actions := engine.get_legal_actions(state, 0)
	_expect(actions is Array and not actions.is_empty(), "llm request builder: setup should produce legal actions", failures)
	if not (actions is Array) or actions.is_empty():
		return
	var builder := LlmRequestBuilder.new()
	var request: Dictionary = builder.build_request(engine, state, 0, actions, [], {
		"history": [{"candidate_id": "cand_001"}],
		"history_summary": {"entry_count": 1},
		"match_context": {"deck_id": "request_builder_test"},
		"repair": {"reason": "candidate_id_not_found"},
		"custom_note": "keep_me"
	})
	var context = request.get("context", {})
	_expect(context is Dictionary, "llm request builder: request should expose context dictionary", failures)
	if not (context is Dictionary):
		return
	var live = context.get("live", {})
	var reference = context.get("reference", {})
	var request_controls = context.get("request_controls", {})
	var auxiliary = context.get("auxiliary", {})
	_expect(live is Dictionary and int(live.get("player_id", -1)) == 0, "llm request builder: live context should expose player_id", failures)
	_expect(live is Dictionary and int(live.get("candidate_count", 0)) > 0, "llm request builder: live context should expose candidate_count", failures)
	_expect(live is Dictionary and live.get("waiting_state", {}) is Dictionary, "llm request builder: live context should expose waiting_state", failures)
	_expect(reference is Dictionary and reference.get("history", []) is Array, "llm request builder: reference context should expose history array", failures)
	_expect(reference is Dictionary and reference.get("history_summary", {}) is Dictionary, "llm request builder: reference context should expose history summary", failures)
	_expect(reference is Dictionary and reference.get("match_context", {}) is Dictionary, "llm request builder: reference context should expose match_context", failures)
	var notes = reference.get("notes", {})
	_expect(notes is Dictionary and bool(notes.get("history_is_reference_only", false)), "llm request builder: reference notes should mark history as reference-only", failures)
	_expect(request_controls is Dictionary and request_controls.get("repair", {}) is Dictionary, "llm request builder: request_controls should expose repair info", failures)
	_expect(auxiliary is Dictionary and str(auxiliary.get("custom_note", "")) == "keep_me", "llm request builder: auxiliary context should preserve unclassified extra data", failures)
	var meta = request.get("meta", {})
	_expect(meta is Dictionary and meta.get("waiting_state", {}) is Dictionary, "llm request builder: legacy meta should remain available", failures)
	_expect(meta is Dictionary and meta.get("extra", {}) is Dictionary and str(meta.get("extra", {}).get("custom_note", "")) == "keep_me", "llm request builder: legacy meta.extra should remain intact for compatibility", failures)

static func _test_request_builder_applies_opening_protocol_trim_to_prompt_fields(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4602)
	var actions := engine.get_legal_actions(state, 0)
	_expect(actions is Array and not actions.is_empty(), "llm request builder: opening trim setup should produce legal actions", failures)
	if not (actions is Array) or actions.is_empty():
		return
	var builder := LlmRequestBuilder.new()
	var request: Dictionary = builder.build_request(engine, state, 0, actions, [], {
		"custom_note": "keep_me"
	})
	var output_schema = request.get("output_schema", {})
	_expect(output_schema is Dictionary and output_schema.size() == 1 and str(output_schema.get("candidate_id", "")) == "string", "llm request builder: opening trim should shrink output_schema to candidate_id only", failures)
	var meta = request.get("meta", {})
	_expect(meta is Dictionary and bool(meta.get("opening_protocol_trim", false)), "llm request builder: opening trim should mark opening_protocol_trim in meta", failures)
	var context = request.get("context", {})
	_expect(context is Dictionary, "llm request builder: opening trim request should still expose context", failures)
	if not (context is Dictionary):
		return
	var live = context.get("live", {})
	_expect(live is Dictionary and live.get("candidate_groups", []) is Array, "llm request builder: live context should expose candidate_groups summary", failures)
	var reference = context.get("reference", {})
	_expect(reference is Dictionary and not reference.has("notes"), "llm request builder: opening trim should remove reference notes from prompt context", failures)
	var candidates = request.get("candidates", [])
	_expect(candidates is Array and not candidates.is_empty(), "llm request builder: opening trim should still expose sanitized candidates", failures)
	if candidates is Array and not candidates.is_empty() and candidates[0] is Dictionary:
		var first_candidate: Dictionary = candidates[0]
		_expect(not first_candidate.has("action"), "llm request builder: sanitized candidates should remove raw action field", failures)
		_expect(not first_candidate.has("source"), "llm request builder: sanitized candidates should remove raw source field", failures)
		_expect(not first_candidate.has("target"), "llm request builder: sanitized candidates should remove raw target field", failures)
		_expect(str(first_candidate.get("action_group", "")).strip_edges() != "", "llm request builder: sanitized candidates should keep action_group", failures)

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
