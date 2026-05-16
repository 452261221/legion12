extends RefCounted
class_name TestScriptedPolicyProfileStageSelection

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ScriptedPolicyProfile = preload("res://ai/scripted/scripted_policy_profile.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_opening_stage(failures)
	_test_midgame_stage(failures)
	_test_closing_stage(failures)
	_test_desperation_stage(failures)
	return failures

static func _test_opening_stage(failures: Array[String]) -> void:
	var context := _build_context(993)
	context.state.turn_number = 2
	var actions: Array = context.engine.get_legal_actions(context.state, 0)
	var decision: Dictionary = context.policy.choose(context.engine, context.state, 0, actions)
	_expect(str(decision.get("stage_id", "")) == "opening", "stage selection: initial takamagahara state should use opening stage", failures)

static func _test_midgame_stage(failures: Array[String]) -> void:
	var context := _build_context(994)
	context.state.turn_number = 5
	context.state.players[0].hand.cards = context.state.players[0].hand.cards.slice(0, 3)
	var actions: Array = context.engine.get_legal_actions(context.state, 0)
	var decision: Dictionary = context.policy.choose(context.engine, context.state, 0, actions)
	_expect(str(decision.get("stage_id", "")) == "midgame", "stage selection: stabilized takamagahara state should use midgame stage", failures)

static func _test_closing_stage(failures: Array[String]) -> void:
	var context := _build_context(995)
	context.state.turn_number = 6
	context.state.players[1].master_hp = 3
	var actions: Array = context.engine.get_legal_actions(context.state, 0)
	var decision: Dictionary = context.policy.choose(context.engine, context.state, 0, actions)
	_expect(str(decision.get("stage_id", "")) == "closing", "stage selection: low enemy master hp should use closing stage", failures)

static func _test_desperation_stage(failures: Array[String]) -> void:
	var context := _build_context(996)
	context.state.turn_number = 6
	context.state.players[0].master_hp = 3
	context.state.players[0].hand.cards = context.state.players[0].hand.cards.slice(0, 2)
	var actions: Array = context.engine.get_legal_actions(context.state, 0)
	var decision: Dictionary = context.policy.choose(context.engine, context.state, 0, actions)
	_expect(str(decision.get("stage_id", "")) == "desperation", "stage selection: low self master hp should use desperation stage", failures)

static func _build_context(seed: int) -> Dictionary:
	var engine = GameEngine.new()
	var definitions: Array = CardDatabase.load_definitions()
	var state = engine.create_game(
		definitions,
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
	var policy := ScriptedPolicyProfile.new()
	policy.set_match_context({
		"deck_id": "stage_test",
		"player_profiles": ["takamagahara_starter_tempo", "asgard_starter_grave_midrange"]
	})
	return {
		"engine": engine,
		"state": state,
		"policy": policy
	}

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
