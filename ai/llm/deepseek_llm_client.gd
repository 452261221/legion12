extends "res://ai/llm/openai_compatible_llm_client.gd"
class_name DeepseekLlmClient

func _init() -> void:
	configure({
		"provider_name": "deepseek",
		"base_url": "https://api.deepseek.com/chat/completions",
		"model": "deepseek-v4-flash"
	})
