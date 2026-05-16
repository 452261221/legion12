extends "res://ai/scripted/scripted_policy_profile.gd"
class_name SequenceRankingPolicy

func _materialize_profile_for_state(base_profile: Dictionary, state, player_id: int) -> Dictionary:
	var profile := super._materialize_profile_for_state(base_profile, state, player_id)
	profile["simulation_top_n"] = 3
	profile["simulation_weight"] = 0.0
	profile["followup_sequence_top_n"] = 3
	profile["followup_sequence_weight"] = 1.0
	return profile
