extends RefCounted
class_name TestAiControllerPolicyMode

const AiController = preload("res://ai/runtime/ai_controller.gd")
const FakeLlmClient = preload("res://ai/llm/fake_llm_client.gd")
const LlmPolicy = preload("res://ai/llm/llm_policy.gd")
const ScriptedPolicyProfile = preload("res://ai/scripted/scripted_policy_profile.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_scripted_mode_builds_scripted_policy(failures)
	_test_llm_mode_builds_llm_policy_and_replays_context(failures)
	return failures

static func _test_scripted_mode_builds_scripted_policy(failures: Array[String]) -> void:
	var controller := AiController.new()
	controller.set_policy_mode(AiController.POLICY_MODE_SCRIPTED)
	_expect(controller.get_policy_mode() == AiController.POLICY_MODE_SCRIPTED, "ai controller: scripted mode should be persisted", failures)
	_expect(is_instance_of(controller.policy, ScriptedPolicyProfile), "ai controller: scripted mode should build ScriptedPolicyProfile", failures)

static func _test_llm_mode_builds_llm_policy_and_replays_context(failures: Array[String]) -> void:
	var controller := AiController.new()
	var fake_client := FakeLlmClient.new()
	controller.set_match_context({
		"deck_id": "mode_test",
		"player_profiles": ["p1", "p2"]
	})
	controller.set_llm_client(fake_client)
	controller.set_policy_mode(AiController.POLICY_MODE_LLM)
	_expect(controller.get_policy_mode() == AiController.POLICY_MODE_LLM, "ai controller: llm mode should be persisted", failures)
	_expect(is_instance_of(controller.policy, LlmPolicy), "ai controller: llm mode should build LlmPolicy", failures)
	if not is_instance_of(controller.policy, LlmPolicy):
		return
	var llm_policy = controller.policy
	var match_context: Dictionary = llm_policy.match_context
	_expect(llm_policy.llm_client == fake_client, "ai controller: llm mode should forward injected llm client", failures)
	_expect(str(match_context.get("deck_id", "")) == "mode_test", "ai controller: llm mode should retain match context deck_id", failures)
	_expect(match_context.get("player_profiles", []) == ["p1", "p2"], "ai controller: llm mode should retain player profiles", failures)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
