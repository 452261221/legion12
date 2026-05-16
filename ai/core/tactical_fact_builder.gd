extends RefCounted
class_name TacticalFactBuilder

func build_script_analysis(ranked: Array[Dictionary], stage_id: String, stage_reasons: Array, opponent_guess: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in ranked:
		if not (row is Dictionary):
			continue
		var candidate: Dictionary = row.get("candidate", {})
		var candidate_id := str(candidate.get("candidate_id", ""))
		if candidate_id.is_empty():
			continue
		result.append(_build_candidate_analysis(row, stage_id, stage_reasons, opponent_guess))
	return result

func _build_candidate_analysis(row: Dictionary, stage_id: String, stage_reasons: Array, opponent_guess: Dictionary) -> Dictionary:
	var candidate: Dictionary = row.get("candidate", {})
	var evaluation: Dictionary = row.get("evaluation", {})
	var breakdown: Dictionary = row.get("simulation_breakdown", {})
	var objective_facts: Array[String] = _build_objective_facts(candidate, breakdown)
	var heuristic_notes: Array[String] = _build_heuristic_notes(candidate, row, evaluation, stage_id, stage_reasons, opponent_guess)
	var warnings: Array[String] = _build_warnings(row, evaluation)
	return {
		"candidate_id": str(candidate.get("candidate_id", "")),
		"objective_facts": objective_facts,
		"heuristic_score": float(row.get("final_score", row.get("score", 0.0))),
		"heuristic_notes": heuristic_notes,
		"warnings": warnings
	}

func _build_objective_facts(candidate: Dictionary, breakdown: Dictionary) -> Array[String]:
	var facts: Array[String] = []
	_append_unique(facts, "kind:%s" % str(candidate.get("kind", "")))
	_append_unique(facts, "command_type:%s" % str(candidate.get("command_type", "")))
	_append_unique(facts, "target_kind:%s" % str(candidate.get("payload", {}).get("target_kind", candidate.get("target", {}).get("target_kind", "")))
	)
	for card_id in candidate.get("involved_card_ids", []):
		_append_unique(facts, "involved_card:%s" % str(card_id))
	_append_breakdown_fact(facts, breakdown, "enemy_board_cleared")
	_append_breakdown_fact(facts, breakdown, "enemy_master_damage")
	_append_breakdown_fact(facts, breakdown, "self_board_loss")
	_append_breakdown_fact(facts, breakdown, "self_board_gain")
	_append_breakdown_fact(facts, breakdown, "self_front_gain")
	_append_breakdown_fact(facts, breakdown, "self_active_morale_loss")
	_append_breakdown_fact(facts, breakdown, "attack_followup_projected_master_damage")
	_append_breakdown_bool(facts, breakdown, "followup_attack_found")
	_append_breakdown_bool(facts, breakdown, "attack_followup_pressure_found")
	_append_breakdown_bool(facts, breakdown, "coordinated_clear_found")
	return facts

func _build_heuristic_notes(candidate: Dictionary, row: Dictionary, evaluation: Dictionary, stage_id: String, stage_reasons: Array, opponent_guess: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var description := str(candidate.get("description", ""))
	if not description.is_empty():
		_append_unique(notes, "候选描述: %s" % description)
	var feature_summary := str(evaluation.get("feature_summary", ""))
	if not feature_summary.is_empty():
		_append_unique(notes, "特征摘要: %s" % feature_summary)
	var simulation_summary := str(row.get("simulation_summary", ""))
	if not simulation_summary.is_empty():
		_append_unique(notes, "模拟摘要: %s" % simulation_summary)
	var followup_summary := str(row.get("followup_sequence_summary", ""))
	if not followup_summary.is_empty():
		_append_unique(notes, "后续序列: %s" % followup_summary)
	if not stage_id.is_empty():
		_append_unique(notes, "阶段判断: %s" % stage_id)
	for reason in stage_reasons:
		_append_unique(notes, "阶段依据: %s" % str(reason))
	var primary_opponent_profile := str(opponent_guess.get("primary_profile_id", ""))
	if not primary_opponent_profile.is_empty():
		_append_unique(notes, "对手画像猜测: %s" % primary_opponent_profile)
	for row_item in evaluation.get("top_positive", []):
		if row_item is Dictionary:
			_append_unique(notes, "正向权重: %s=%.2f" % [str(row_item.get("key", "")), float(row_item.get("value", 0.0))])
	return notes

func _build_warnings(row: Dictionary, evaluation: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	var veto_reason := str(row.get("veto_reason", ""))
	if not veto_reason.is_empty():
		_append_unique(warnings, "veto:%s" % veto_reason)
	if bool(row.get("vetoed", false)) and veto_reason.is_empty():
		_append_unique(warnings, "vetoed:true")
	for row_item in evaluation.get("top_negative", []):
		if row_item is Dictionary:
			_append_unique(warnings, "negative_feature:%s=%.2f" % [str(row_item.get("key", "")), float(row_item.get("value", 0.0))])
	var simulation_summary := str(row.get("simulation_summary", ""))
	if simulation_summary.begins_with("apply_failed:"):
		_append_unique(warnings, simulation_summary)
	return warnings

func _append_breakdown_fact(facts: Array[String], breakdown: Dictionary, key: String) -> void:
	if not breakdown.has(key):
		return
	var raw_value = breakdown.get(key)
	if raw_value is int or raw_value is float:
		var numeric_value: float = float(raw_value)
		if is_zero_approx(numeric_value):
			return
		_append_unique(facts, "%s:%s" % [key, str(raw_value)])

func _append_breakdown_bool(facts: Array[String], breakdown: Dictionary, key: String) -> void:
	if not breakdown.has(key):
		return
	_append_unique(facts, "%s:%s" % [key, str(bool(breakdown.get(key, false))).to_lower()])

func _append_unique(items: Array[String], value: String) -> void:
	if value.is_empty() or items.has(value):
		return
	items.append(value)
