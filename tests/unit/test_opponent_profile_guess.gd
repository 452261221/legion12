extends RefCounted
class_name TestOpponentProfileGuess

const GameEngine = preload("res://rules/core/game_engine.gd")
const OpponentProfileGuesser = preload("res://ai/scripted/opponent_profile_guesser.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = GameEngine.new()
	var state = engine.create_game([], [[], []], 77, [
		{
			"name": "P1",
			"master_id": "takamagahara_s01_04m2",
			"master_name": "须佐之男",
			"master_hp": 9,
			"master_max_hp": 9
		},
		{
			"name": "P2",
			"master_id": "asgard_s01_03m2a",
			"master_name": "洛基",
			"master_hp": 12,
			"master_max_hp": 12
		}
	])
	var guesser := OpponentProfileGuesser.new()
	var guess := guesser.guess({}, state, 0)
	_expect(str(guess.get("primary_profile_id", "")) == "asgard_starter_grave_midrange", "opponent guess should use opponent master profile as weak prior", failures)
	_expect(guess.has("distribution"), "opponent guess should expose distribution", failures)
	_expect(guess.has("reasons"), "opponent guess should expose reasons", failures)
	return failures

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
