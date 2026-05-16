extends RefCounted
class_name TestLlmProviderRegistry

const LlmProviderRegistry = preload("res://ai/llm/llm_provider_registry.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_supported_providers(failures)
	_test_alias_resolution(failures)
	_test_runtime_override(failures)
	_test_custom_ai_prompt_round_trip(failures)
	_test_battle_table_settings_round_trip(failures)
	return failures

static func _test_supported_providers(failures: Array[String]) -> void:
	var registry := LlmProviderRegistry.new()
	var providers := registry.get_supported_providers()
	_expect(providers.has("deepseek"), "llm provider registry: should include deepseek", failures)
	_expect(providers.has("qwen"), "llm provider registry: should include qwen", failures)
	_expect(providers.has("glm"), "llm provider registry: should include glm", failures)
	_expect(providers.has("openai"), "llm provider registry: should include openai", failures)
	_expect(providers.has("kimi"), "llm provider registry: should include kimi", failures)

static func _test_alias_resolution(failures: Array[String]) -> void:
	var registry := LlmProviderRegistry.new()
	var kimi := registry.get_preset("moonshot")
	var glm := registry.get_preset("zhipu")
	var qwen := registry.get_preset("tongyi")
	_expect(str(kimi.get("provider_name", "")) == "kimi", "llm provider registry: moonshot alias should map to kimi", failures)
	_expect(str(glm.get("provider_name", "")) == "glm", "llm provider registry: zhipu alias should map to glm", failures)
	_expect(str(qwen.get("provider_name", "")) == "qwen", "llm provider registry: tongyi alias should map to qwen", failures)

static func _test_runtime_override(failures: Array[String]) -> void:
	var registry := LlmProviderRegistry.new()
	var resolved := registry.resolve_runtime_options({
		"llm_provider": "glm",
		"llm_model": "glm-4.5-air",
		"llm_base_url": "https://open.bigmodel.cn/api/paas/v4/chat/completions",
		"llm_timeout_seconds": 18.0,
		"llm_use_external_helper": true,
		"llm_enable_thinking": true,
		"llm_response_max_tokens": 1536
	})
	_expect(str(resolved.get("provider_name", "")) == "glm", "llm provider registry: runtime provider should resolve to glm", failures)
	_expect(str(resolved.get("api_key_env", "")) == "GLM_API_KEY", "llm provider registry: glm should use GLM_API_KEY", failures)
	_expect(str(resolved.get("model", "")) == "glm-4.5-air", "llm provider registry: runtime model override should win", failures)
	_expect(int(resolved.get("timeout_seconds", 0)) == 18, "llm provider registry: timeout override should win", failures)
	_expect(bool(resolved.get("enable_thinking", false)), "llm provider registry: thinking override should win", failures)
	_expect(int(resolved.get("response_max_tokens", 0)) == 1536, "llm provider registry: response_max_tokens override should win", failures)

static func _test_custom_ai_prompt_round_trip(failures: Array[String]) -> void:
	var registry := LlmProviderRegistry.new()
	var original := registry.load_settings()
	var updated := original.duplicate(true)
	updated["ai_prompt"] = "provider_registry_prompt_test"
	_expect(registry.save_settings(updated), "llm provider registry: save_settings should persist ai_prompt", failures)
	var reloaded := registry.load_settings()
	_expect(str(reloaded.get("ai_prompt", "")) == "provider_registry_prompt_test", "llm provider registry: load_settings should preserve ai_prompt", failures)
	registry.save_settings(original)

static func _test_battle_table_settings_round_trip(failures: Array[String]) -> void:
	var registry := LlmProviderRegistry.new()
	var original := registry.load_settings()
	var updated := original.duplicate(true)
	updated["battle_table"] = {
		"ai_mode": 2,
		"ai_use_llm": true
	}
	_expect(registry.save_settings(updated), "llm provider registry: save_settings should persist battle_table settings", failures)
	var reloaded := registry.load_settings()
	var table_settings = reloaded.get("battle_table", {})
	_expect(table_settings is Dictionary, "llm provider registry: battle_table settings should remain a dictionary", failures)
	_expect(int(table_settings.get("ai_mode", -1)) == 2, "llm provider registry: ai_mode should round-trip", failures)
	_expect(bool(table_settings.get("ai_use_llm", false)), "llm provider registry: ai_use_llm should round-trip", failures)
	registry.save_settings(original)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
