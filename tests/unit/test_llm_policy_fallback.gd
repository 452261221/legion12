extends RefCounted
class_name TestLlmPolicyFallback

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const FakeLlmClient = preload("res://ai/llm/fake_llm_client.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const LlmPolicy = preload("res://ai/llm/llm_policy.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_llm_policy_uses_valid_candidate_id(failures)
	_test_llm_policy_repairs_invalid_response_before_fallback(failures)
	_test_llm_policy_uses_second_repair_round_before_fallback(failures)
	_test_llm_policy_marks_repair_then_fallback_when_second_response_still_invalid(failures)
	_test_llm_policy_falls_back_on_invalid_candidate_id(failures)
	_test_llm_policy_injects_knowledge_via_session_messages(failures)
	_test_llm_policy_includes_execution_history_in_next_request(failures)
	_test_llm_policy_keeps_history_separated_per_player(failures)
	return failures

static func _test_llm_policy_uses_valid_candidate_id(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4501)
	var actions := engine.get_legal_actions(state, 0)
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(not candidates.is_empty(), "llm policy: valid-response setup should have candidates", failures)
	if candidates.is_empty():
		return
	var fake_client := FakeLlmClient.new()
	fake_client.set_mode("first_candidate")
	var policy := LlmPolicy.new()
	policy.set_llm_client(fake_client)
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(str(decision.get("source", "")) == "llm", "llm policy: valid fake response should select llm path", failures)
	_expect(str(decision.get("candidate_id", "")) == str(candidates[0].get("candidate_id", "")), "llm policy: valid fake response should use returned candidate_id", failures)
	_expect(str(decision.get("command_type", "")) == str(candidates[0].get("command_type", "")), "llm policy: valid fake response should map back to local command_type", failures)
	_expect(decision.get("payload", {}) == candidates[0].get("payload", {}), "llm policy: valid fake response should use local payload", failures)
	_expect(not str(decision.get("debug_summary", "")).is_empty(), "llm policy: llm decision should include debug_summary", failures)
	var timing_trace: Dictionary = decision.get("timing_trace", {})
	var timing_summary: Dictionary = timing_trace.get("summary", {}) if timing_trace is Dictionary else {}
	_expect(timing_trace is Dictionary and not timing_trace.is_empty(), "llm policy: llm decision should include timing_trace", failures)
	_expect(int(timing_summary.get("llm_call_count", 0)) >= 1, "llm policy: timing summary should record at least one llm call", failures)

static func _test_llm_policy_falls_back_on_invalid_candidate_id(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4502)
	var actions := engine.get_legal_actions(state, 0)
	var fake_client := FakeLlmClient.new()
	fake_client.set_mode("invalid_candidate")
	var policy := LlmPolicy.new()
	policy.set_llm_client(fake_client)
	policy.set_match_context({
		"deck_id": "trace_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(str(decision.get("source", "")) == "scripted_fallback", "llm policy: invalid candidate_id should fall back to scripted policy", failures)
	_expect(str(decision.get("fallback_reason", "")) == "candidate_id_not_found", "llm policy: invalid candidate_id should expose fallback reason", failures)
	_expect(not str(decision.get("command_type", "")).is_empty(), "llm policy: fallback decision should still expose command_type", failures)
	_expect(decision.get("script_analysis", []) is Array and not decision.get("script_analysis", []).is_empty(), "llm policy: fallback decision should preserve script_analysis", failures)
	_expect(str(decision.get("debug_summary", "")).contains("candidate_id_not_found"), "llm policy: fallback debug_summary should include reason", failures)

static func _test_llm_policy_repairs_invalid_response_before_fallback(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4505)
	var actions := engine.get_legal_actions(state, 0)
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(not candidates.is_empty(), "llm policy: repair setup should have candidates", failures)
	if candidates.is_empty():
		return
	var fake_client := FakeLlmClient.new()
	fake_client.set_queued_responses([
		{
			"candidate_id": "invalid_candidate_id",
			"confidence": 0.01,
			"brief_reason": "first_invalid"
		},
		{
			"candidate_id": str(candidates[0].get("candidate_id", "")),
			"confidence": 0.77,
			"brief_reason": "repair_valid"
		}
	])
	var policy := LlmPolicy.new()
	policy.set_llm_client(fake_client)
	policy.set_match_context({
		"deck_id": "trace_test",
		"match_seed": 4505,
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(str(decision.get("source", "")) == "llm", "llm policy: repair should recover to llm path when second response is valid", failures)
	_expect(str(decision.get("candidate_id", "")) == str(candidates[0].get("candidate_id", "")), "llm policy: repair should accept valid second response", failures)
	_expect(fake_client.get_request_count() == 2, "llm policy: repair should trigger a second llm request", failures)
	_expect(bool(decision.get("repair_attempted", false)), "llm policy: repair success should mark repair_attempted", failures)
	_expect(str(decision.get("repaired_from", "")) == "candidate_id_not_found", "llm policy: repair success should expose original validation reason", failures)
	_expect(str(decision.get("debug_summary", "")).contains("repaired_from=candidate_id_not_found"), "llm policy: repair success debug_summary should expose repaired_from reason", failures)
	_expect(int(decision.get("repair_depth", -1)) == 1, "llm policy: first repair success should expose repair_depth=1", failures)
	var repair_timing_trace: Dictionary = decision.get("timing_trace", {})
	var repair_timing_summary: Dictionary = repair_timing_trace.get("summary", {}) if repair_timing_trace is Dictionary else {}
	_expect(int(repair_timing_summary.get("repair_count", 0)) >= 1, "llm policy: repaired decision timing should record repair_count", failures)

static func _test_llm_policy_uses_second_repair_round_before_fallback(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4508)
	var actions := engine.get_legal_actions(state, 0)
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	_expect(not candidates.is_empty(), "llm policy: second repair setup should have candidates", failures)
	if candidates.is_empty():
		return
	var fake_client := FakeLlmClient.new()
	fake_client.set_queued_responses([
		{
			"candidate_id": "invalid_candidate_id",
			"confidence": 0.01,
			"brief_reason": "first_invalid"
		},
		{
			"candidate_id": "still_invalid_candidate_id",
			"confidence": 0.02,
			"brief_reason": "second_invalid"
		},
		{
			"proposal_id": str(candidates[0].get("proposal_id", "")),
			"brief_reason": "third_repair_valid"
		}
	])
	var policy := LlmPolicy.new()
	policy.set_llm_client(fake_client)
	policy.set_match_context({
		"deck_id": "trace_test",
		"match_seed": 4508,
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(str(decision.get("source", "")) == "llm", "llm policy: second repair round should still recover to llm path", failures)
	_expect(fake_client.get_request_count() == 3, "llm policy: second repair round should use three llm attempts", failures)
	_expect(bool(decision.get("repair_attempted", false)), "llm policy: second repair success should still mark repair_attempted", failures)
	_expect(int(decision.get("repair_depth", -1)) == 2, "llm policy: second repair success should expose repair_depth=2", failures)

static func _test_llm_policy_marks_repair_then_fallback_when_second_response_still_invalid(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4507)
	var actions := engine.get_legal_actions(state, 0)
	var fake_client := FakeLlmClient.new()
	fake_client.set_queued_responses([
		{
			"candidate_id": "invalid_candidate_id",
			"confidence": 0.01,
			"brief_reason": "first_invalid"
		},
		{
			"candidate_id": "still_invalid_candidate_id",
			"confidence": 0.02,
			"brief_reason": "second_invalid"
		},
		{
			"candidate_id": "third_invalid_candidate_id",
			"confidence": 0.03,
			"brief_reason": "third_invalid"
		}
	])
	var policy := LlmPolicy.new()
	policy.set_llm_client(fake_client)
	policy.set_match_context({
		"deck_id": "trace_test",
		"match_seed": 4507,
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(str(decision.get("source", "")) == "scripted_fallback", "llm policy: repeated invalid responses should eventually fall back", failures)
	_expect(bool(decision.get("repair_attempted", false)), "llm policy: fallback after repair should still mark repair_attempted", failures)
	_expect(str(decision.get("repaired_from", "")) == "candidate_id_not_found", "llm policy: fallback after repair should expose original validation reason", failures)
	_expect(str(decision.get("debug_summary", "")).contains("after_repair=candidate_id_not_found"), "llm policy: fallback debug_summary should expose after_repair reason", failures)
	_expect(int(decision.get("repair_depth", -1)) == 2, "llm policy: fallback after second repair should expose repair_depth=2", failures)
	_expect(fake_client.get_request_count() == 3, "llm policy: repeated invalid responses should use three llm attempts before fallback", failures)

static func _test_llm_policy_injects_knowledge_via_session_messages(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4503)
	var actions := engine.get_legal_actions(state, 0)
	var fake_client := FakeLlmClient.new()
	fake_client.set_mode("first_candidate")
	var policy := LlmPolicy.new()
	policy.set_llm_client(fake_client)
	policy.set_match_context({
		"deck_id": "trace_test",
		"match_seed": 4503,
		"ai_prompt": "test_ai_prompt_text",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	var request: Dictionary = decision.get("llm_request", {})
	var extra: Dictionary = request.get("meta", {}).get("extra", {})
	var conversation_messages = request.get("conversation_messages", [])
	_expect(not extra.has("knowledge"), "llm policy: per-step request meta should not duplicate knowledge payload", failures)
	_expect(conversation_messages is Array and conversation_messages.size() >= 4, "llm policy: session messages should include base context, rules, knowledge, and ai prompt", failures)
	if not (conversation_messages is Array) or conversation_messages.size() < 4:
		return
	var rules_message = conversation_messages[1]
	_expect(rules_message is Dictionary and str(rules_message.get("role", "")) == "user", "llm policy: rules markdown should be sent as a session user message", failures)
	if rules_message is Dictionary:
		var rules_text := str(rules_message.get("content", ""))
		_expect(rules_text.contains("\"kind\":\"rules_markdown\""), "llm policy: session rules message should mark itself as rules_markdown", failures)
	var knowledge_message = conversation_messages[2]
	_expect(knowledge_message is Dictionary and str(knowledge_message.get("role", "")) == "user", "llm policy: knowledge payload should be sent as a session user message", failures)
	if not (knowledge_message is Dictionary):
		return
	var knowledge_text := str(knowledge_message.get("content", ""))
	_expect(knowledge_text.contains("\"kind\":\"knowledge\""), "llm policy: session knowledge message should mark itself as knowledge", failures)
	var parsed_knowledge = JSON.parse_string(knowledge_text)
	_expect(parsed_knowledge is Dictionary, "llm policy: session knowledge message should remain valid json", failures)
	if parsed_knowledge is Dictionary:
		var knowledge_payload: Dictionary = parsed_knowledge.get("knowledge", {})
		_expect(not knowledge_payload.has("faction_pools"), "llm policy: knowledge payload should no longer include full faction pools", failures)
		var decks: Dictionary = knowledge_payload.get("decks", {})
		_expect(decks is Dictionary, "llm policy: knowledge payload should include decks section", failures)
		if decks is Dictionary:
			var self_deck: Dictionary = decks.get("self", {})
			var opponent_deck: Dictionary = decks.get("opponent", {})
			_expect(int(self_deck.get("deck_size", 0)) == 6, "llm policy: self deck knowledge should include actual deck size", failures)
			_expect(int(opponent_deck.get("deck_size", 0)) == 6, "llm policy: opponent deck knowledge should include actual deck size", failures)
			var self_cards = self_deck.get("cards", [])
			var opponent_cards = opponent_deck.get("cards", [])
			_expect(self_cards is Array and self_cards.size() == 1, "llm policy: self deck knowledge should collapse duplicates into counted entries", failures)
			_expect(opponent_cards is Array and opponent_cards.size() == 1, "llm policy: opponent deck knowledge should collapse duplicates into counted entries", failures)
			if self_cards is Array and self_cards.size() == 1 and self_cards[0] is Dictionary:
				var self_entry: Dictionary = self_cards[0]
				_expect(int(self_entry.get("count", 0)) == 6, "llm policy: self deck knowledge should record card count", failures)
				var self_definition: Dictionary = self_entry.get("definition", {})
				_expect(str(self_definition.get("id", "")) == "dev_legion_alpha", "llm policy: self deck knowledge should include card definition details", failures)
			if opponent_cards is Array and opponent_cards.size() == 1 and opponent_cards[0] is Dictionary:
				var opponent_entry: Dictionary = opponent_cards[0]
				_expect(int(opponent_entry.get("count", 0)) == 6, "llm policy: opponent deck knowledge should record card count", failures)
				var opponent_definition: Dictionary = opponent_entry.get("definition", {})
				_expect(str(opponent_definition.get("id", "")) == "dev_legion_beta", "llm policy: opponent deck knowledge should include opponent card definition details", failures)
	var prompt_message = conversation_messages[3]
	_expect(prompt_message is Dictionary and str(prompt_message.get("role", "")) == "user", "llm policy: ai prompt should be sent as a session user message", failures)
	if prompt_message is Dictionary:
		var prompt_text := str(prompt_message.get("content", ""))
		_expect(prompt_text.contains("\"kind\":\"ai_prompt\""), "llm policy: session ai prompt message should mark itself as ai_prompt", failures)
		_expect(prompt_text.contains("test_ai_prompt_text"), "llm policy: session ai prompt message should include configured ai prompt text", failures)

static func _test_llm_policy_includes_execution_history_in_next_request(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4504)
	var actions := engine.get_legal_actions(state, 0)
	var fake_client := FakeLlmClient.new()
	fake_client.set_mode("first_candidate")
	var policy := LlmPolicy.new()
	policy.set_llm_client(fake_client)
	policy.set_match_context({
		"deck_id": "trace_test",
		"match_seed": 4504,
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var first_decision := policy.choose(engine, state, 0, actions)
	_expect(str(first_decision.get("source", "")) == "llm", "llm policy: history setup should first produce an llm decision", failures)
	if first_decision.is_empty():
		return
	policy.record_executed(first_decision, engine.get_waiting_state(state), {"ok": true})
	var second_decision := policy.choose(engine, state, 0, actions)
	var request: Dictionary = second_decision.get("llm_request", {})
	var history = request.get("meta", {}).get("extra", {}).get("history", [])
	var history_summary = request.get("meta", {}).get("extra", {}).get("history_summary", {})
	_expect(history is Array and history.size() == 1, "llm policy: next request should include one compact history entry", failures)
	_expect(history_summary is Dictionary and int(history_summary.get("entry_count", 0)) == 1, "llm policy: next request should include structured history summary", failures)
	if history is Array and history.size() == 1 and history[0] is Dictionary:
		var history_entry: Dictionary = history[0]
		_expect(str(history_entry.get("candidate_id", "")) == str(first_decision.get("candidate_id", "")), "llm policy: history should preserve previous candidate_id", failures)
		_expect(str(history_entry.get("source", "")) == "llm", "llm policy: compact history should preserve previous source", failures)
		_expect(bool(history_entry.get("result_ok", false)), "llm policy: compact history should preserve execution result", failures)

static func _test_llm_policy_keeps_history_separated_per_player(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = _create_state(engine, 4506)
	var actions := engine.get_legal_actions(state, 0)
	var fake_client := FakeLlmClient.new()
	fake_client.set_mode("first_candidate")
	var policy := LlmPolicy.new()
	policy.set_llm_client(fake_client)
	policy.set_match_context({
		"deck_id": "trace_test",
		"match_seed": 4506,
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var decision := policy.choose(engine, state, 0, actions)
	_expect(not decision.is_empty(), "llm policy: per-player history setup should produce an initial decision", failures)
	if decision.is_empty():
		return
	policy.record_executed(decision, engine.get_waiting_state(state), {"ok": true})
	policy._refresh_session(engine, state, 1)
	var player0_key := policy._session_key_for_player(0)
	var player1_key := policy._session_key_for_player(1)
	var player0_session: Dictionary = policy._session_cache.get(player0_key, {})
	var player1_session: Dictionary = policy._session_cache.get(player1_key, {})
	var player0_history = player0_session.get("executed_history", [])
	var player1_history = player1_session.get("executed_history", [])
	_expect(player0_history is Array and player0_history.size() == 1, "llm policy: player 0 session should retain its own history", failures)
	_expect(player1_history is Array and player1_history.is_empty(), "llm policy: player 1 session should start with empty history", failures)

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
