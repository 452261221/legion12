extends RefCounted
class_name TestDeckProfileRegistry

const DeckProfileRegistry = preload("res://ai/scripted/deck_profile_registry.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var registry := DeckProfileRegistry.new()
	var starter_top := registry.resolve_profile({
		"deck_id": "starter_takamagahara_asgard_raw",
		"player_profiles": ["", ""]
	}, 0)
	var starter_bottom := registry.resolve_profile({
		"deck_id": "starter_takamagahara_asgard_raw",
		"player_profiles": ["", ""]
	}, 1)
	_expect(str(starter_top.get("profile_id", "")) == "takamagahara_starter_tempo", "starter player 0 should resolve to takamagahara starter tempo profile", failures)
	_expect(str(starter_bottom.get("profile_id", "")) == "asgard_starter_grave_midrange", "starter player 1 should resolve to asgard starter grave midrange profile", failures)
	var direct := registry.resolve_profile({
		"deck_id": "unknown",
		"player_profiles": ["control", ""]
	}, 0)
	_expect(str(direct.get("profile_id", "")) == "control", "direct player profile should override deck mapping", failures)
	return failures

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
