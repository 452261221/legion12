extends "res://ai/scripted/scripted_policy_profile.gd"
class_name ForcedRankingPolicy

func _apply_simulation_rerank(_profile: Dictionary, _engine, _state, _player_id: int, ranked: Array[Dictionary], _opponent_guess: Dictionary) -> void:
	for row in ranked:
		var candidate: Dictionary = row.get("candidate", {})
		var command_type := str(candidate.get("command_type", ""))
		if command_type == "DeclareAttack":
			row["final_score"] = 9.0
			row["simulation_summary"] = "forced_invalid_top"
		elif command_type == "EndPhase":
			row["final_score"] = 1.0
			row["simulation_summary"] = "forced_valid_fallback"
		else:
			row["final_score"] = 0.0
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("final_score", 0.0)) > float(b.get("final_score", 0.0))
	)
