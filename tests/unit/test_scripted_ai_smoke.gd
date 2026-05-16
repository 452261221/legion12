extends RefCounted
class_name TestScriptedAiSmoke

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const AiController = preload("res://ai/runtime/ai_controller.gd")
const ScriptedPolicyProfile = preload("res://ai/scripted/scripted_policy_profile.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	if definitions.is_empty():
		failures.append("ai smoke: card definitions are empty")
		return failures
	var state = engine.create_game(
		definitions,
		[
			["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
			["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
		],
		991
	)
	var controller := AiController.new()
	controller.set_policy(ScriptedPolicyProfile.new())
	controller.set_match_context({
		"deck_id": "ai_smoke_dev",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	var guard := 0
	while state.winner == -1 and guard < 400:
		guard += 1
		var waiting := engine.get_waiting_state(state)
		var player_id := int(waiting.get("player_id", -1))
		if player_id < 0:
			failures.append("ai smoke: missing waiting player")
			return failures
		var actions = engine.get_legal_actions(state, player_id)
		if actions.is_empty():
			failures.append("ai smoke: no legal actions for player %s" % player_id)
			return failures
		var decision := controller.drive_engine_step(engine, state, player_id, actions)
		if decision.is_empty():
			failures.append("ai smoke: no decision")
			return failures
		var command_type := str(decision.get("command_type", ""))
		var payload: Dictionary = decision.get("payload", {})
		var applied = engine.apply_command(state, GameCommand.create(player_id, command_type, payload))
		if not bool(applied.get("ok", false)):
			failures.append("ai smoke: apply failed code=%s message=%s" % [str(applied.get("code", applied.get("error_code", "UNKNOWN"))), str(applied.get("message", ""))])
			return failures
	return failures
