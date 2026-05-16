extends RefCounted
class_name ScriptedPolicyRandom

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")

func choose(engine, state, player_id: int, actions: Array) -> Dictionary:
	if engine == null or state == null:
		return {}
	if actions.is_empty():
		return {}
	var indexed: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	if indexed.is_empty():
		return {}
	var pick_index := randi() % indexed.size()
	return {
		"command_type": str(indexed[pick_index].get("command_type", "")),
		"payload": indexed[pick_index].get("payload", {}).duplicate(true)
	}
