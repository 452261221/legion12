extends SceneTree

const TestAiCandidateBuilder = preload("res://tests/unit/test_ai_candidate_builder.gd")
const TestAiControllerPolicyMode = preload("res://tests/unit/test_ai_controller_policy_mode.gd")
const TestAiObservationVisibility = preload("res://tests/unit/test_ai_observation_visibility.gd")
const TestAiScriptAnalysis = preload("res://tests/unit/test_ai_script_analysis.gd")
const TestLlmDecisionValidator = preload("res://tests/unit/test_llm_decision_validator.gd")
const TestLlmRequestBuilder = preload("res://tests/unit/test_llm_request_builder.gd")
const TestOpenAICompatibleLlmClient = preload("res://tests/unit/test_openai_compatible_llm_client.gd")
const TestLlmPolicyFallback = preload("res://tests/unit/test_llm_policy_fallback.gd")
const TestLlmProviderRegistry = preload("res://tests/unit/test_llm_provider_registry.gd")

const RESULT_PATH := "user://ai_llm_unit_test_results.json"
const RESULT_FALLBACK_PATH := "res://tmp_ai_llm_unit_test_results.json"

func _initialize() -> void:
	var suites = [
		{"name": "TestAiCandidateBuilder", "script": TestAiCandidateBuilder},
		{"name": "TestAiControllerPolicyMode", "script": TestAiControllerPolicyMode},
		{"name": "TestAiObservationVisibility", "script": TestAiObservationVisibility},
		{"name": "TestAiScriptAnalysis", "script": TestAiScriptAnalysis},
		{"name": "TestLlmDecisionValidator", "script": TestLlmDecisionValidator},
		{"name": "TestLlmRequestBuilder", "script": TestLlmRequestBuilder},
		{"name": "TestOpenAICompatibleLlmClient", "script": TestOpenAICompatibleLlmClient},
		{"name": "TestLlmPolicyFallback", "script": TestLlmPolicyFallback},
		{"name": "TestLlmProviderRegistry", "script": TestLlmProviderRegistry}
	]
	var failures: Array[String] = []
	var suite_summaries: Array[Dictionary] = []
	print("Running %s AI/LLM test suites..." % suites.size())
	for suite in suites:
		var suite_name = str(suite.get("name", "UnknownSuite"))
		var suite_failures: Array[String] = []
		if suite.script != null and suite.script.has_method("run"):
			suite_failures = suite.script.run()
		else:
			suite_failures = ["missing_run_method"]
		suite_summaries.append({
			"name": suite_name,
			"failure_count": suite_failures.size()
		})
		if suite_failures.is_empty():
			print("PASS %s" % suite_name)
		else:
			print("FAIL %s (%s failures)" % [suite_name, suite_failures.size()])
		for message in suite_failures:
			failures.append("%s: %s" % [suite_name, message])
	if failures.is_empty():
		print("AI/LLM unit tests passed (%s suites)" % suites.size())
		_write_result_file(true, suite_summaries, failures)
		quit(0)
		return
	print("AI/LLM unit tests failed: %s failures across %s suites" % [failures.size(), suites.size()])
	printerr("AI/LLM unit tests failed: %s failures across %s suites" % [failures.size(), suites.size()])
	for suite_summary in suite_summaries:
		var failure_count = int(suite_summary.get("failure_count", 0))
		if failure_count <= 0:
			continue
		print(" - %s: %s failures" % [str(suite_summary.get("name", "UnknownSuite")), failure_count])
		printerr(" - %s: %s failures" % [str(suite_summary.get("name", "UnknownSuite")), failure_count])
	_write_result_file(false, suite_summaries, failures)
	for message in failures:
		push_error(message)
	quit(1)

func _write_result_file(ok: bool, suite_summaries: Array[Dictionary], failures: Array[String]) -> void:
	var payload = {
		"ok": ok,
		"failure_count": failures.size(),
		"suite_count": suite_summaries.size(),
		"suites": suite_summaries.duplicate(true),
		"failures": failures.duplicate()
	}
	var file = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	var resolved_path = RESULT_PATH
	if file == null:
		var fallback_path = ProjectSettings.globalize_path(RESULT_FALLBACK_PATH)
		file = FileAccess.open(fallback_path, FileAccess.WRITE)
		resolved_path = fallback_path
	if file == null:
		push_error("Unable to write AI/LLM unit test result file: %s" % RESULT_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file = null
	print("AI/LLM unit test results written to: %s" % resolved_path)
