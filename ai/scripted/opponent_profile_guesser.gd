extends RefCounted
class_name OpponentProfileGuesser

const DeckProfileRegistry = preload("res://ai/scripted/deck_profile_registry.gd")

var registry := DeckProfileRegistry.new()

func guess(match_context: Dictionary, state, player_id: int) -> Dictionary:
	if state == null or state.players.size() < 2:
		return {
			"primary_profile_id": "unknown",
			"distribution": {"unknown": 1.0},
			"reasons": ["state_unavailable"]
		}
	var opponent_id := 1 - player_id
	var reasons: Array[String] = []
	var distribution := {"unknown": 1.0}
	var override_profiles = match_context.get("opponent_profile_overrides", [])
	if override_profiles is Array and opponent_id >= 0 and opponent_id < override_profiles.size():
		var override_id := str(override_profiles[opponent_id])
		if not override_id.is_empty():
			return {
				"primary_profile_id": override_id,
				"distribution": {override_id: 1.0},
				"reasons": ["override"]
			}
	var master_profile := registry.resolve_profile({}, opponent_id, state)
	var master_profile_id := str(master_profile.get("profile_id", ""))
	if not master_profile_id.is_empty():
		distribution.erase("unknown")
		distribution[master_profile_id] = 0.65
		distribution["unknown"] = 0.35
		reasons.append("master_profile:%s" % master_profile_id)
	var opponent = state.get_player(opponent_id)
	var board_units := _board_unit_count(opponent)
	if board_units >= 2:
		_add_distribution(distribution, "tempo", 0.15)
		reasons.append("board_pressure")
	var grave_cards: int = opponent.grave.cards.size()
	if grave_cards >= 4:
		_add_distribution(distribution, "control", 0.10)
		reasons.append("grave_density")
	var primary_profile_id := _primary_distribution_key(distribution)
	return {
		"primary_profile_id": primary_profile_id,
		"distribution": distribution,
		"reasons": reasons
	}

func _board_unit_count(player) -> int:
	var count := 0
	for slot in player.battle_front:
		if not slot.occupant.is_empty():
			count += 1
	for slot in player.battle_back:
		if not slot.occupant.is_empty():
			count += 1
	return count

func _add_distribution(distribution: Dictionary, key: String, delta: float) -> void:
	distribution[key] = float(distribution.get(key, 0.0)) + delta
	var total := 0.0
	for value in distribution.values():
		total += float(value)
	if total <= 0.0:
		return
	for entry_key in distribution.keys():
		distribution[entry_key] = float(distribution[entry_key]) / total

func _primary_distribution_key(distribution: Dictionary) -> String:
	var best_key := "unknown"
	var best_value := -INF
	for key in distribution.keys():
		var value := float(distribution.get(key, 0.0))
		if value > best_value:
			best_value = value
			best_key = str(key)
	return best_key
