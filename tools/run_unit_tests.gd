extends SceneTree

const TestCoreFlow = preload("res://tests/unit/test_core_flow.gd")
const TestReplayIO = preload("res://tests/unit/test_replay_io.gd")
const TestMatchHistoryStore = preload("res://tests/unit/test_match_history_store.gd")
const TestCandidateSimulator = preload("res://tests/unit/test_candidate_simulator.gd")
const TestBlockQuery = preload("res://tests/unit/test_block_query.gd")
const TestSupportQuery = preload("res://tests/unit/test_support_query.gd")
const TestEffectStack = preload("res://tests/unit/test_effect_stack.gd")
const TestDeckCatalog = preload("res://tests/unit/test_deck_catalog.gd")
const TestDeckBuilderStore = preload("res://tests/unit/test_deck_builder_store.gd")
const TestCardDatabase = preload("res://tests/unit/test_card_database.gd")
const TestBijieCore = preload("res://tests/unit/test_bijie_core.gd")
const TestBijieBatch1 = preload("res://tests/unit/test_bijie_batch_1.gd")
const TestBijieBatch2 = preload("res://tests/unit/test_bijie_batch_2.gd")
const TestBijieBatch3 = preload("res://tests/unit/test_bijie_batch_3.gd")
const TestBijieBatch4 = preload("res://tests/unit/test_bijie_batch_4.gd")
const TestBijieBatch5 = preload("res://tests/unit/test_bijie_batch_5.gd")
const TestBijieBatch6 = preload("res://tests/unit/test_bijie_batch_6.gd")
const TestBijieBatch7 = preload("res://tests/unit/test_bijie_batch_7.gd")
const TestBijieBatch8 = preload("res://tests/unit/test_bijie_batch_8.gd")
const TestStateValidator = preload("res://tests/unit/test_state_validator.gd")
const TestCalamity = preload("res://tests/unit/test_calamity.gd")
const TestContinuousEffects = preload("res://tests/unit/test_continuous_effects.gd")
const TestCommonEffectActions = preload("res://tests/unit/test_common_effect_actions.gd")
const TestLegalActions = preload("res://tests/unit/test_legal_actions.gd")
const TestDebugCommand = preload("res://tests/unit/test_debug_command.gd")
const TestArtifactPlay = preload("res://tests/unit/test_artifact_play.gd")
const TestTacticPlay = preload("res://tests/unit/test_tactic_play.gd")
const TestDemoStarterDuelEffects = preload("res://tests/unit/test_demo_starter_duel_effects.gd")
const TestDemoDevRemainingCards = preload("res://tests/unit/test_demo_dev_remaining_cards.gd")
const TestClassicBatch1 = preload("res://tests/unit/test_classic_batch_1.gd")
const TestClassicBatch2 = preload("res://tests/unit/test_classic_batch_2.gd")
const TestClassicBatch3 = preload("res://tests/unit/test_classic_batch_3.gd")
const TestTakamagaharaAsgardBatch1 = preload("res://tests/unit/test_takamagahara_asgard_batch_1.gd")
const TestTakamagaharaAsgardBatch2 = preload("res://tests/unit/test_takamagahara_asgard_batch_2.gd")
const TestAsgardBatch3 = preload("res://tests/unit/test_asgard_batch_3.gd")
const TestAsgardBatch4 = preload("res://tests/unit/test_asgard_batch_4.gd")
const TestAsgardBatch5 = preload("res://tests/unit/test_asgard_batch_5.gd")
const TestAsgardBatch6 = preload("res://tests/unit/test_asgard_batch_6.gd")
const TestAsgardBatch7 = preload("res://tests/unit/test_asgard_batch_7.gd")
const TestMasterBatch1 = preload("res://tests/unit/test_master_batch_1.gd")
const TestTiantingMasterBatch1 = preload("res://tests/unit/test_tianting_master_batch_1.gd")
const TestSuncityBatch1 = preload("res://tests/unit/test_suncity_batch_1.gd")
const TestOlympusBatch1 = preload("res://tests/unit/test_olympus_batch_1.gd")
const TestOlympusBatch2 = preload("res://tests/unit/test_olympus_batch_2.gd")
const TestOlympusBatch3 = preload("res://tests/unit/test_olympus_batch_3.gd")
const TestOlympusBatch4 = preload("res://tests/unit/test_olympus_batch_4.gd")
const TestOlympusBatch5 = preload("res://tests/unit/test_olympus_batch_5.gd")
const TestOlympusBatch6 = preload("res://tests/unit/test_olympus_batch_6.gd")
const TestOlympusBatch7 = preload("res://tests/unit/test_olympus_batch_7.gd")
const TestOlympusBatch8 = preload("res://tests/unit/test_olympus_batch_8.gd")
const TestTakamagaharaBatch3 = preload("res://tests/unit/test_takamagahara_batch_3.gd")
const TestTakamagaharaBatch4 = preload("res://tests/unit/test_takamagahara_batch_4.gd")
const TestTakamagaharaBatch5 = preload("res://tests/unit/test_takamagahara_batch_5.gd")
const TestTakamagaharaBatch6 = preload("res://tests/unit/test_takamagahara_batch_6.gd")
const TestTakamagaharaBatch7 = preload("res://tests/unit/test_takamagahara_batch_7.gd")
const TestTakamagaharaBatch8 = preload("res://tests/unit/test_takamagahara_batch_8.gd")
const TestBattleStatusBadges = preload("res://tests/unit/test_battle_status_badges.gd")
const TestScriptedAiSmoke = preload("res://tests/unit/test_scripted_ai_smoke.gd")
const TestDeckProfileRegistry = preload("res://tests/unit/test_deck_profile_registry.gd")
const TestOpponentProfileGuess = preload("res://tests/unit/test_opponent_profile_guess.gd")
const TestAiCandidateBuilder = preload("res://tests/unit/test_ai_candidate_builder.gd")
const TestAiControllerPolicyMode = preload("res://tests/unit/test_ai_controller_policy_mode.gd")
const TestAiObservationVisibility = preload("res://tests/unit/test_ai_observation_visibility.gd")
const TestAiScriptAnalysis = preload("res://tests/unit/test_ai_script_analysis.gd")
const TestRuleRegressions = preload("res://tests/unit/test_rule_regressions.gd")
const TestLlmDecisionValidator = preload("res://tests/unit/test_llm_decision_validator.gd")
const TestLlmPolicyFallback = preload("res://tests/unit/test_llm_policy_fallback.gd")
const TestLlmProviderRegistry = preload("res://tests/unit/test_llm_provider_registry.gd")
const TestProfileFeatureExtractor = preload("res://tests/unit/test_profile_feature_extractor.gd")
const TestScriptedPolicyProfileTrace = preload("res://tests/unit/test_scripted_policy_profile_trace.gd")
const TestScriptedPolicyProfileStageSelection = preload("res://tests/unit/test_scripted_policy_profile_stage_selection.gd")

const RESULT_PATH := "user://unit_test_results.json"
const RESULT_FALLBACK_PATH := "res://tmp_unit_test_results.json"

func _initialize() -> void:
    var suites = [
        {"name": "TestCoreFlow", "script": TestCoreFlow},
        {"name": "TestReplayIO", "script": TestReplayIO},
        {"name": "TestMatchHistoryStore", "script": TestMatchHistoryStore},
        {"name": "TestCandidateSimulator", "script": TestCandidateSimulator},
        {"name": "TestBlockQuery", "script": TestBlockQuery},
        {"name": "TestSupportQuery", "script": TestSupportQuery},
        {"name": "TestEffectStack", "script": TestEffectStack},
        {"name": "TestDeckCatalog", "script": TestDeckCatalog},
        {"name": "TestDeckBuilderStore", "script": TestDeckBuilderStore},
        {"name": "TestCardDatabase", "script": TestCardDatabase},
        {"name": "TestBijieCore", "script": TestBijieCore},
        {"name": "TestBijieBatch1", "script": TestBijieBatch1},
        {"name": "TestBijieBatch2", "script": TestBijieBatch2},
        {"name": "TestBijieBatch3", "script": TestBijieBatch3},
        {"name": "TestBijieBatch4", "script": TestBijieBatch4},
        {"name": "TestBijieBatch5", "script": TestBijieBatch5},
        {"name": "TestBijieBatch6", "script": TestBijieBatch6},
        {"name": "TestBijieBatch7", "script": TestBijieBatch7},
        {"name": "TestBijieBatch8", "script": TestBijieBatch8},
        {"name": "TestStateValidator", "script": TestStateValidator},
        {"name": "TestCalamity", "script": TestCalamity},
        {"name": "TestContinuousEffects", "script": TestContinuousEffects},
        {"name": "TestCommonEffectActions", "script": TestCommonEffectActions},
        {"name": "TestLegalActions", "script": TestLegalActions},
        {"name": "TestDebugCommand", "script": TestDebugCommand},
        {"name": "TestArtifactPlay", "script": TestArtifactPlay},
        {"name": "TestTacticPlay", "script": TestTacticPlay},
        {"name": "TestDemoStarterDuelEffects", "script": TestDemoStarterDuelEffects},
        {"name": "TestDemoDevRemainingCards", "script": TestDemoDevRemainingCards},
        {"name": "TestClassicBatch1", "script": TestClassicBatch1},
        {"name": "TestClassicBatch2", "script": TestClassicBatch2},
        {"name": "TestClassicBatch3", "script": TestClassicBatch3},
        {"name": "TestTakamagaharaAsgardBatch1", "script": TestTakamagaharaAsgardBatch1},
        {"name": "TestTakamagaharaAsgardBatch2", "script": TestTakamagaharaAsgardBatch2},
        {"name": "TestAsgardBatch3", "script": TestAsgardBatch3},
        {"name": "TestAsgardBatch4", "script": TestAsgardBatch4},
        {"name": "TestAsgardBatch5", "script": TestAsgardBatch5},
        {"name": "TestAsgardBatch6", "script": TestAsgardBatch6},
        {"name": "TestAsgardBatch7", "script": TestAsgardBatch7},
        {"name": "TestMasterBatch1", "script": TestMasterBatch1},
        {"name": "TestTiantingMasterBatch1", "script": TestTiantingMasterBatch1},
        {"name": "TestSuncityBatch1", "script": TestSuncityBatch1},
        {"name": "TestOlympusBatch1", "script": TestOlympusBatch1},
        {"name": "TestOlympusBatch2", "script": TestOlympusBatch2},
        {"name": "TestOlympusBatch3", "script": TestOlympusBatch3},
        {"name": "TestOlympusBatch4", "script": TestOlympusBatch4},
        {"name": "TestOlympusBatch5", "script": TestOlympusBatch5},
        {"name": "TestOlympusBatch6", "script": TestOlympusBatch6},
        {"name": "TestOlympusBatch7", "script": TestOlympusBatch7},
        {"name": "TestOlympusBatch8", "script": TestOlympusBatch8},
        {"name": "TestTakamagaharaBatch3", "script": TestTakamagaharaBatch3},
        {"name": "TestTakamagaharaBatch4", "script": TestTakamagaharaBatch4},
        {"name": "TestTakamagaharaBatch5", "script": TestTakamagaharaBatch5},
        {"name": "TestTakamagaharaBatch6", "script": TestTakamagaharaBatch6},
        {"name": "TestTakamagaharaBatch7", "script": TestTakamagaharaBatch7},
        {"name": "TestTakamagaharaBatch8", "script": TestTakamagaharaBatch8},
        {"name": "TestBattleStatusBadges", "script": TestBattleStatusBadges},
        {"name": "TestScriptedAiSmoke", "script": TestScriptedAiSmoke},
        {"name": "TestDeckProfileRegistry", "script": TestDeckProfileRegistry},
        {"name": "TestOpponentProfileGuess", "script": TestOpponentProfileGuess},
        {"name": "TestAiCandidateBuilder", "script": TestAiCandidateBuilder},
        {"name": "TestAiControllerPolicyMode", "script": TestAiControllerPolicyMode},
        {"name": "TestAiObservationVisibility", "script": TestAiObservationVisibility},
        {"name": "TestAiScriptAnalysis", "script": TestAiScriptAnalysis},
        {"name": "TestRuleRegressions", "script": TestRuleRegressions},
        {"name": "TestLlmDecisionValidator", "script": TestLlmDecisionValidator},
        {"name": "TestLlmPolicyFallback", "script": TestLlmPolicyFallback},
        {"name": "TestLlmProviderRegistry", "script": TestLlmProviderRegistry},
        {"name": "TestProfileFeatureExtractor", "script": TestProfileFeatureExtractor},
        {"name": "TestScriptedPolicyProfileTrace", "script": TestScriptedPolicyProfileTrace},
        {"name": "TestScriptedPolicyProfileStageSelection", "script": TestScriptedPolicyProfileStageSelection}
    ]
    var failures: Array[String] = []
    var suite_summaries: Array[Dictionary] = []
    print("Running %s test suites..." % suites.size())
    for suite in suites:
        var suite_name = str(suite.get("name", "UnknownSuite"))
        var raw_failures = suite.script.run()
        var suite_failures: Array[String] = []
        if raw_failures is Array:
            for message in raw_failures:
                suite_failures.append(str(message))
        else:
            suite_failures.append("suite returned invalid failures type: %s" % str(typeof(raw_failures)))
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
        print("unit tests passed (%s suites)" % suites.size())
        _write_result_file(true, suite_summaries, failures)
        quit(0)
        return
    print("unit tests failed: %s failures across %s suites" % [failures.size(), suites.size()])
    printerr("unit tests failed: %s failures across %s suites" % [failures.size(), suites.size()])
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
        push_error("Unable to write unit test result file: %s" % RESULT_PATH)
        return
    file.store_string(JSON.stringify(payload, "\t"))
    file.flush()
    file = null
    print("unit test results written to: %s" % resolved_path)
