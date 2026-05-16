extends SceneTree

const LlmProviderRegistry = preload("res://ai/llm/llm_provider_registry.gd")
const OpenAICompatibleLlmClient = preload("res://ai/llm/openai_compatible_llm_client.gd")

func _initialize() -> void:
	var provider := "deepseek"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		provider = str(args[0]).strip_edges().to_lower()
	var registry := LlmProviderRegistry.new()
	var resolved := registry.resolve_runtime_options({
		"llm_provider": provider,
		"llm_debug": true
	})
	if str(resolved.get("api_key", "")).is_empty():
		push_error("llm smoke: missing api key for provider=%s env=%s" % [provider, str(resolved.get("api_key_env", ""))])
		quit(1)
		return
	var request := {
		"observation": {
			"schema_version": 1,
			"viewer_player_id": 0,
			"turn_number": 1,
			"phase": "main",
			"waiting_state": {
				"state": "WaitingForAction",
				"player_id": 0
			}
		},
		"candidates": [
			{
				"candidate_id": "cand_play_alpha",
				"kind": "play_card",
				"command_type": "PlayCard",
				"description": "打出军团 Alpha 到前排 1 号位",
				"cost_summary": "消耗 1 士气",
				"risk_summary": "会交出优先权"
			},
			{
				"candidate_id": "cand_end_phase",
				"kind": "end_phase",
				"command_type": "EndPhase",
				"description": "结束当前阶段",
				"cost_summary": "无额外消耗",
				"risk_summary": "放弃当前行动窗口"
			}
		],
		"script_analysis": [
			{
				"candidate_id": "cand_play_alpha",
				"heuristic_score": 1.2,
				"heuristic_notes": ["脚本更倾向于先展开场面"],
				"warnings": []
			},
			{
				"candidate_id": "cand_end_phase",
				"heuristic_score": -0.5,
				"heuristic_notes": [],
				"warnings": ["过早结束阶段可能亏节奏"]
			}
		],
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": 0,
			"candidate_count": 2
		}
	}
	var client := OpenAICompatibleLlmClient.new()
	client.configure(resolved)
	var response: Dictionary = client.choose_candidate(request)
	print("llm smoke provider=%s response: %s" % [provider, JSON.stringify(response)])
	if response.has("candidate_id") and not str(response.get("candidate_id", "")).is_empty():
		quit(0)
		return
	push_error("llm smoke: missing candidate_id response=%s" % JSON.stringify(response))
	quit(1)
