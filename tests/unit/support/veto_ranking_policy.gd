extends "res://ai/scripted/scripted_policy_profile.gd"
class_name VetoRankingPolicy

var _forced_rows_by_command: Dictionary = {}

func set_forced_rows(config: Dictionary) -> void:
	_forced_rows_by_command = config.duplicate(true)

func _apply_simulation_rerank(_profile: Dictionary, _engine, _state, _player_id: int, ranked: Array[Dictionary], _opponent_guess: Dictionary) -> void:
	for row in ranked:
		var candidate: Dictionary = row.get("candidate", {})
		var command_type := str(candidate.get("command_type", ""))
		var forced: Dictionary = _forced_rows_by_command.get(command_type, {})
		if forced.is_empty():
			row["final_score"] = float(row.get("score", 0.0))
			continue
		row["simulation_score"] = float(forced.get("simulation_score", 0.0))
		row["simulation_summary"] = str(forced.get("summary", "forced"))
		var forced_breakdown = forced.get("simulation_breakdown", forced.get("breakdown", {}))
		row["simulation_breakdown"] = forced_breakdown.duplicate(true) if forced_breakdown is Dictionary else {}
		row["followup_sequence_score"] = float(forced.get("followup_sequence_score", 0.0))
		row["followup_sequence_summary"] = str(forced.get("followup_sequence_summary", ""))
		var forced_followup_payload = forced.get("followup_sequence_payload", {})
		row["followup_sequence_payload"] = forced_followup_payload.duplicate(true) if forced_followup_payload is Dictionary else {}
		row["final_score"] = float(forced.get("final_score", row.get("score", 0.0)))
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("final_score", 0.0)) > float(b.get("final_score", 0.0))
	)
