extends RefCounted
class_name LlmProviderRegistry

const SETTINGS_PATH := "user://llm_settings.json"
const SETTINGS_FALLBACK_PATH := "res://tmp_llm_settings.json"
const EXAMPLE_SETTINGS_PATH := "res://data/ai/llm_settings.example.json"
const RUNTIME_MODE_FAST := "fast"
const RUNTIME_MODE_STABLE := "stable"
const PROVIDER_PRESETS := {
	"deepseek": {
		"provider_name": "deepseek",
		"base_url": "https://api.deepseek.com",
		"model": "deepseek-v4-flash",
		"api_key_env": "DEEPSEEK_API_KEY",
		"use_external_helper": false
	},
	"qwen": {
		"provider_name": "qwen",
		"base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
		"model": "qwen-plus",
		"api_key_env": "QWEN_API_KEY",
		"use_external_helper": true
	},
	"glm": {
		"provider_name": "glm",
		"base_url": "https://open.bigmodel.cn/api/paas/v4/chat/completions",
		"model": "glm-4-plus",
		"api_key_env": "GLM_API_KEY",
		"use_external_helper": true
	},
	"openai": {
		"provider_name": "openai",
		"base_url": "https://api.openai.com/v1/chat/completions",
		"model": "gpt-4.1-mini",
		"api_key_env": "OPENAI_API_KEY",
		"use_external_helper": true
	},
	"kimi": {
		"provider_name": "kimi",
		"base_url": "https://api.moonshot.cn/v1/chat/completions",
		"model": "moonshot-v1-8k",
		"api_key_env": "MOONSHOT_API_KEY",
		"use_external_helper": true
	}
}

func get_supported_providers() -> Array[String]:
	var keys: Array[String] = []
	for key in PROVIDER_PRESETS.keys():
		keys.append(str(key))
	keys.sort()
	return keys

func get_runtime_modes() -> Array[String]:
	return [RUNTIME_MODE_FAST, RUNTIME_MODE_STABLE]

func get_runtime_mode_defaults(provider_name: String, mode_name: String) -> Dictionary:
	var normalized_provider := _normalize_provider_name(provider_name)
	if normalized_provider.is_empty():
		normalized_provider = "deepseek"
	var normalized_mode := _normalize_runtime_mode(mode_name)
	var defaults := {
		"runtime_mode": normalized_mode,
		"timeout_seconds": 20.0,
		"enable_thinking": false,
		"response_max_tokens": 512,
		"max_retries": 2,
		"retry_delay_ms": 1200
	}
	if normalized_mode == RUNTIME_MODE_FAST:
		defaults["timeout_seconds"] = 5.0
		defaults["enable_thinking"] = false
		defaults["response_max_tokens"] = 128
		defaults["max_retries"] = 0
		defaults["retry_delay_ms"] = 0
	return defaults

func get_preset(provider_name: String) -> Dictionary:
	var normalized := _normalize_provider_name(provider_name)
	if not PROVIDER_PRESETS.has(normalized):
		normalized = "deepseek"
	return PROVIDER_PRESETS.get(normalized, {}).duplicate(true)

func resolve_runtime_options(game_options: Dictionary = {}) -> Dictionary:
	var config: Dictionary = _load_settings_file()
	var configured_default := str(config.get("default_provider", "deepseek")).strip_edges().to_lower()
	var requested_provider := str(game_options.get("llm_provider", configured_default)).strip_edges().to_lower()
	if requested_provider.is_empty():
		requested_provider = configured_default if not configured_default.is_empty() else "deepseek"
	var preset := get_preset(requested_provider)
	var config_providers: Dictionary = config.get("providers", {})
	var provider_config: Dictionary = config_providers.get(str(preset.get("provider_name", requested_provider)), {}).duplicate(true)
	var resolved := preset.duplicate(true)
	_merge_dictionary(resolved, provider_config)
	var runtime_mode := _normalize_runtime_mode(str(game_options.get("llm_runtime_mode", provider_config.get("runtime_mode", resolved.get("runtime_mode", RUNTIME_MODE_STABLE)))))
	var runtime_defaults := get_runtime_mode_defaults(requested_provider, runtime_mode)
	resolved["runtime_mode"] = runtime_mode
	var api_key_env := str(resolved.get("api_key_env", "")).strip_edges()
	var env_api_key := ""
	if not api_key_env.is_empty():
		env_api_key = str(OS.get_environment(api_key_env)).strip_edges()
	resolved["provider_name"] = str(resolved.get("provider_name", requested_provider))
	resolved["api_key"] = str(game_options.get("llm_api_key", provider_config.get("api_key", env_api_key))).strip_edges()
	if resolved["api_key"].is_empty():
		resolved["api_key"] = env_api_key
	resolved["base_url"] = str(game_options.get("llm_base_url", resolved.get("base_url", ""))).strip_edges()
	resolved["model"] = str(game_options.get("llm_model", resolved.get("model", ""))).strip_edges()
	resolved["timeout_seconds"] = float(game_options.get("llm_timeout_seconds", resolved.get("timeout_seconds", 20.0)))
	resolved["use_external_helper"] = bool(game_options.get("llm_use_external_helper", resolved.get("use_external_helper", true)))
	resolved["enable_thinking"] = bool(game_options.get("llm_enable_thinking", resolved.get("enable_thinking", false)))
	resolved["response_max_tokens"] = int(game_options.get("llm_response_max_tokens", resolved.get("response_max_tokens", resolved.get("max_tokens", 512))))
	resolved["debug"] = bool(game_options.get("llm_debug", resolved.get("debug", false)))
	resolved["max_retries"] = int(game_options.get("llm_max_retries", resolved.get("max_retries", runtime_defaults.get("max_retries", 2))))
	resolved["retry_delay_ms"] = int(game_options.get("llm_retry_delay_ms", resolved.get("retry_delay_ms", runtime_defaults.get("retry_delay_ms", 1200))))
	var extra_headers: Array = []
	var resolved_headers = resolved.get("extra_headers", [])
	if resolved_headers is Array:
		for item in resolved_headers:
			extra_headers.append(str(item))
	var option_headers = game_options.get("llm_extra_headers", [])
	if option_headers is Array:
		for item in option_headers:
			extra_headers.append(str(item))
	resolved["extra_headers"] = extra_headers
	var request_extras: Dictionary = {}
	var resolved_extras = resolved.get("request_extras", {})
	if resolved_extras is Dictionary:
		request_extras = resolved_extras.duplicate(true)
	var option_extras = game_options.get("llm_request_extras", {})
	if option_extras is Dictionary:
		_merge_dictionary(request_extras, option_extras)
	resolved["request_extras"] = request_extras
	resolved["settings_path"] = SETTINGS_PATH
	resolved["example_settings_path"] = EXAMPLE_SETTINGS_PATH
	return resolved

func load_settings() -> Dictionary:
	return _load_settings_file()

func save_settings(settings: Dictionary) -> bool:
	_ensure_settings_directory_exists()
	var serialized := JSON.stringify(settings, "\t")
	var saved := false
	var file: FileAccess = _open_settings_file_for_write(SETTINGS_PATH)
	if file != null:
		file.store_string(serialized)
		file.close()
		saved = true
	var fallback_file: FileAccess = _open_settings_file_for_write(SETTINGS_FALLBACK_PATH)
	if fallback_file != null:
		fallback_file.store_string(serialized)
		fallback_file.close()
		saved = true
	if not saved:
		return false
	return true

func _load_settings_file() -> Dictionary:
	var resolved_path := _resolve_existing_settings_path()
	if resolved_path.is_empty():
		return {}
	var raw_text := FileAccess.get_file_as_string(resolved_path)
	if raw_text.is_empty():
		return {}
	var parsed = JSON.parse_string(raw_text)
	return parsed.duplicate(true) if parsed is Dictionary else {}

func _ensure_settings_directory_exists() -> void:
	var settings_dir := ProjectSettings.globalize_path("user://")
	if settings_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(settings_dir)

func _resolve_existing_settings_path() -> String:
	for path in [SETTINGS_FALLBACK_PATH, ProjectSettings.globalize_path(SETTINGS_FALLBACK_PATH), SETTINGS_PATH, ProjectSettings.globalize_path(SETTINGS_PATH)]:
		if not str(path).is_empty() and FileAccess.file_exists(path):
			return str(path)
	return ""

func _open_settings_file_for_write(path: String):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		return file
	if path.begins_with("user://") or path.begins_with("res://"):
		return FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	return null

func _merge_dictionary(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = source.get(key)

func _normalize_provider_name(provider_name: String) -> String:
	var normalized := provider_name.strip_edges().to_lower()
	if normalized == "moonshot":
		return "kimi"
	if normalized == "zhipu":
		return "glm"
	if normalized == "tongyi":
		return "qwen"
	return normalized

func _normalize_runtime_mode(mode_name: String) -> String:
	var normalized := mode_name.strip_edges().to_lower()
	if normalized == RUNTIME_MODE_FAST:
		return RUNTIME_MODE_FAST
	return RUNTIME_MODE_STABLE
