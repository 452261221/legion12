extends RefCounted
class_name ScriptedPolicyProfile

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")
const TacticalFactBuilder = preload("res://ai/core/tactical_fact_builder.gd")
const CandidateSimulator = preload("res://ai/scripted/candidate_simulator.gd")
const DeckProfileRegistry = preload("res://ai/scripted/deck_profile_registry.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const OpponentProfileGuesser = preload("res://ai/scripted/opponent_profile_guesser.gd")
const ProfileFeatureExtractor = preload("res://ai/scripted/profile_feature_extractor.gd")
const ScriptedPolicyRandom = preload("res://ai/scripted/scripted_policy_random.gd")

var match_context: Dictionary = {}
var registry := DeckProfileRegistry.new()
var opponent_guesser := OpponentProfileGuesser.new()
var feature_extractor := ProfileFeatureExtractor.new()
var candidate_simulator := CandidateSimulator.new()
var tactical_fact_builder := TacticalFactBuilder.new()
var fallback := ScriptedPolicyRandom.new()

func set_match_context(context: Dictionary) -> void:
	match_context = context.duplicate(true)

func choose(engine, state, player_id: int, actions: Array) -> Dictionary:
	if engine == null or state == null or actions.is_empty():
		return {}
	var candidates := ActionCandidateBuilder.expand(actions)
	if candidates.is_empty():
		return fallback.choose(engine, state, player_id, actions)
	var resolved_profile := registry.resolve_profile(match_context, player_id, state)
	if resolved_profile.is_empty():
		return fallback.choose(engine, state, player_id, actions)
	var profile := _materialize_profile_for_state(resolved_profile, state, player_id)
	var opponent_guess := opponent_guesser.guess(match_context, state, player_id)
	var ranked: Array[Dictionary] = []
	for candidate in candidates:
		var evaluation := feature_extractor.evaluate(profile, engine, state, player_id, candidate, opponent_guess)
		var score := float(evaluation.get("score", -INF))
		ranked.append({
			"candidate": candidate,
			"evaluation": evaluation,
			"score": score,
			"simulation_score": 0.0,
			"simulation_summary": "",
			"simulation_breakdown": {},
			"followup_sequence_score": 0.0,
			"followup_sequence_summary": "",
			"followup_sequence_payload": {},
			"vetoed": false,
			"veto_reason": ""
		})
	if ranked.is_empty():
		return fallback.choose(engine, state, player_id, actions)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", -INF)) > float(b.get("score", -INF))
	)
	_apply_simulation_rerank(profile, engine, state, player_id, ranked, opponent_guess)
	_apply_priority_response_preference(engine, state, player_id, ranked)
	_apply_defense_preference(ranked)
	_apply_play_card_preference(state, ranked)
	_apply_hard_veto_filter(engine, state, player_id, ranked)
	var best_row := _pick_best_currently_valid_row(engine, state, player_id, ranked)
	if best_row.is_empty():
		best_row = ranked[0]
	var best_candidate: Dictionary = best_row.get("candidate", {})
	var best_eval: Dictionary = best_row.get("evaluation", {})
	var best_score: float = float(best_row.get("final_score", best_row.get("score", -INF)))
	var top_candidates := _build_top_candidates(ranked, 3)
	var profile_id := str(profile.get("profile_id", ""))
	var stage_id := str(profile.get("stage_id", "base"))
	var stage_reasons: Array = profile.get("stage_reasons", [])
	var script_analysis := tactical_fact_builder.build_script_analysis(ranked, stage_id, stage_reasons, opponent_guess)
	return {
		"candidate_id": str(best_candidate.get("candidate_id", "")),
		"command_type": str(best_candidate.get("command_type", "")),
		"payload": best_candidate.get("payload", {}).duplicate(true),
		"description": str(best_candidate.get("description", "")),
		"profile_id": profile_id,
		"stage_id": stage_id,
		"stage_reasons": stage_reasons.duplicate(true),
		"opponent_guess": opponent_guess.duplicate(true),
		"score_trace": best_eval.get("trace", []).duplicate(true),
		"bucket_totals": best_eval.get("bucket_totals", {}).duplicate(true),
		"feature_summary": str(best_eval.get("feature_summary", "")),
		"simulation_score": float(best_row.get("simulation_score", 0.0)),
		"simulation_summary": str(best_row.get("simulation_summary", "")),
		"simulation_breakdown": best_row.get("simulation_breakdown", {}).duplicate(true),
		"followup_sequence_score": float(best_row.get("followup_sequence_score", 0.0)),
		"followup_sequence_summary": str(best_row.get("followup_sequence_summary", "")),
		"followup_sequence_payload": best_row.get("followup_sequence_payload", {}).duplicate(true),
		"veto_reason": str(best_row.get("veto_reason", "")),
		"score": best_score,
		"top_candidates": top_candidates,
		"script_analysis": script_analysis,
		"debug_summary": _build_debug_summary(profile_id, stage_id, opponent_guess, best_candidate, best_eval, best_score, str(best_row.get("simulation_summary", "")), top_candidates)
	}

func _build_debug_summary(profile_id: String, stage_id: String, opponent_guess: Dictionary, candidate: Dictionary, evaluation: Dictionary, final_score: float, simulation_summary: String, top_candidates: Array[Dictionary]) -> String:
	var kind := str(candidate.get("kind", ""))
	var command_type := str(candidate.get("command_type", ""))
	var static_score := float(evaluation.get("score", 0.0))
	var opponent_profile := str(opponent_guess.get("primary_profile_id", "unknown"))
	return "[AI] profile=%s stage=%s opponent=%s kind=%s command=%s static=%.2f final=%.2f sim=%s top=%s" % [
		profile_id,
		stage_id,
		opponent_profile,
		kind,
		command_type,
		static_score,
		final_score,
		simulation_summary,
		_format_top_candidates(top_candidates)
	]

func _materialize_profile_for_state(base_profile: Dictionary, state, player_id: int) -> Dictionary:
	var profile := base_profile.duplicate(true)
	var stage_info := _select_stage(profile, state, player_id)
	var stage_id := str(stage_info.get("stage_id", "base"))
	var stage_reasons: Array = stage_info.get("reasons", [])
	profile["stage_id"] = stage_id
	profile["stage_reasons"] = stage_reasons.duplicate(true)
	var base_weights: Dictionary = profile.get("weights", {}).duplicate(true)
	var stage_weights_by_id: Dictionary = profile.get("weights_by_stage", {})
	var stage_weights: Dictionary = stage_weights_by_id.get(stage_id, {})
	if stage_weights is Dictionary and not stage_weights.is_empty():
		for key in stage_weights.keys():
			base_weights[key] = stage_weights[key]
	profile["weights"] = base_weights
	return profile

func _select_stage(profile: Dictionary, state, player_id: int) -> Dictionary:
	var weights_by_stage: Dictionary = profile.get("weights_by_stage", {})
	if weights_by_stage.is_empty() or state == null or player_id < 0 or player_id >= state.players.size():
		return {"stage_id": "base", "reasons": []}
	var self_player = state.get_player(player_id)
	var enemy_player = state.get_player(1 - player_id)
	var self_front := _front_row_unit_count(self_player)
	var enemy_front := _front_row_unit_count(enemy_player)
	var self_board := _board_unit_count(self_player)
	var enemy_board := _board_unit_count(enemy_player)
	var self_grave: int = self_player.grave.cards.size()
	var self_hand: int = self_player.hand.cards.size()
	var enemy_hand: int = enemy_player.hand.cards.size()
	var reasons: Array[String] = []
	if self_player.master_hp <= 3:
		reasons.append("self_master_hp_le_3")
	if self_hand <= 1 and enemy_front > self_front:
		reasons.append("self_hand_le_1")
	if self_player.master_hp <= 6 and enemy_front >= self_front + 2:
		reasons.append("enemy_front_ahead")
	if not reasons.is_empty() and weights_by_stage.has("desperation"):
		return {"stage_id": "desperation", "reasons": reasons}
	reasons.clear()
	if enemy_player.master_hp <= 3:
		reasons.append("enemy_master_hp_le_3")
	if enemy_player.master_hp <= 6 and enemy_front == 0 and self_front > 0:
		reasons.append("open_master_lane")
	if enemy_player.master_hp <= 6 and self_board >= enemy_board + 2:
		reasons.append("board_ahead")
	if enemy_player.master_hp <= 6 and self_hand >= enemy_hand + 1:
		reasons.append("hand_not_behind")
	if not reasons.is_empty() and weights_by_stage.has("closing"):
		return {"stage_id": "closing", "reasons": reasons}
	reasons.clear()
	if state.turn_number <= 3 and self_grave <= 1 and enemy_board <= 1:
		reasons.append("early_turn")
	if state.turn_number <= 3 and self_board <= 1 and self_hand >= 4:
		reasons.append("setup_window")
	if not reasons.is_empty() and weights_by_stage.has("opening"):
		return {"stage_id": "opening", "reasons": reasons}
	if weights_by_stage.has("midgame"):
		return {"stage_id": "midgame", "reasons": ["default_midgame"]}
	var fallback_stage := str(weights_by_stage.keys()[0])
	return {"stage_id": fallback_stage, "reasons": ["fallback_first_stage"]}

func _build_top_candidates(ranked: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var top: Array[Dictionary] = []
	for i in range(min(limit, ranked.size())):
		var row: Dictionary = ranked[i]
		var candidate: Dictionary = row.get("candidate", {})
		top.append({
			"candidate_id": str(candidate.get("candidate_id", "")),
			"kind": str(candidate.get("kind", "")),
			"command_type": str(candidate.get("command_type", "")),
			"description": str(candidate.get("description", "")),
			"payload": candidate.get("payload", {}).duplicate(true),
			"score": float(row.get("final_score", row.get("score", 0.0))),
			"static_score": float(row.get("score", 0.0)),
			"simulation_score": float(row.get("simulation_score", 0.0)),
			"simulation_summary": str(row.get("simulation_summary", "")),
			"simulation_breakdown": row.get("simulation_breakdown", {}).duplicate(true),
			"followup_sequence_score": float(row.get("followup_sequence_score", 0.0)),
			"followup_sequence_summary": str(row.get("followup_sequence_summary", "")),
			"followup_sequence_payload": row.get("followup_sequence_payload", {}).duplicate(true),
			"vetoed": bool(row.get("vetoed", false)),
			"veto_reason": str(row.get("veto_reason", "")),
			"bucket_totals": row.get("evaluation", {}).get("bucket_totals", {}).duplicate(true),
			"feature_summary": str(row.get("evaluation", {}).get("feature_summary", ""))
		})
	return top

func _apply_simulation_rerank(profile: Dictionary, engine, state, player_id: int, ranked: Array[Dictionary], opponent_guess: Dictionary) -> void:
	var simulation_top_n: int = int(profile.get("simulation_top_n", 2))
	if simulation_top_n <= 0:
		for row in ranked:
			row["final_score"] = float(row.get("score", 0.0))
		return
	var simulation_weight: float = float(profile.get("simulation_weight", 0.6))
	var followup_sequence_weight: float = float(profile.get("followup_sequence_weight", 0.35))
	var followup_sequence_top_n: int = int(profile.get("followup_sequence_top_n", simulation_top_n))
	for i in range(ranked.size()):
		var row: Dictionary = ranked[i]
		var static_score: float = float(row.get("score", 0.0))
		if i < simulation_top_n:
			var simulation := candidate_simulator.simulate_candidate(engine, state, player_id, row.get("candidate", {}))
			var simulation_score: float = float(simulation.get("score", 0.0))
			row["simulation_score"] = simulation_score
			row["simulation_summary"] = str(simulation.get("summary", ""))
			row["simulation_breakdown"] = simulation.get("breakdown", {}).duplicate(true)
			var followup_sequence := {}
			if i < followup_sequence_top_n:
				followup_sequence = _evaluate_followup_sequence(profile, engine, state, player_id, row.get("candidate", {}), opponent_guess, simulation)
			var followup_sequence_score: float = float(followup_sequence.get("score", 0.0))
			row["followup_sequence_score"] = followup_sequence_score
			row["followup_sequence_summary"] = str(followup_sequence.get("summary", ""))
			row["followup_sequence_payload"] = followup_sequence.get("payload", {}).duplicate(true)
			row["final_score"] = static_score + simulation_score * simulation_weight + followup_sequence_score * followup_sequence_weight
		else:
			row["final_score"] = static_score
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("final_score", a.get("score", -INF))) > float(b.get("final_score", b.get("score", -INF)))
	)

func _apply_priority_response_preference(engine, state, player_id: int, ranked: Array[Dictionary]) -> void:
	if engine == null or state == null or ranked.is_empty():
		return
	if not engine.has_method("get_waiting_state"):
		return
	var waiting: Dictionary = engine.get_waiting_state(state)
	if str(waiting.get("state", "")) != "WaitingForPriority":
		return
	for row in ranked:
		var candidate: Dictionary = row.get("candidate", {})
		var bonus := _priority_response_preference_bonus(candidate)
		if bonus == 0.0:
			continue
		row["final_score"] = float(row.get("final_score", row.get("score", 0.0))) + bonus
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("final_score", a.get("score", -INF))) > float(b.get("final_score", b.get("score", -INF)))
	)

func _priority_response_preference_bonus(candidate: Dictionary) -> float:
	var kind := str(candidate.get("kind", ""))
	if kind == "choose_defense":
		return 0.24
	if kind == "activate_effect":
		return 0.08
	if kind != "play_card":
		return 0.0
	var play_kind := str(candidate.get("play_kind", candidate.get("extra", {}).get("play_kind", "")))
	if play_kind == "counter_tactic":
		return 0.20
	if play_kind == "hand_response":
		return 0.14
	return 0.0

func _apply_defense_preference(ranked: Array[Dictionary]) -> void:
	if ranked.is_empty():
		return
	for row in ranked:
		var candidate: Dictionary = row.get("candidate", {})
		var bonus := _choose_defense_preference_bonus(candidate)
		if bonus == 0.0:
			continue
		row["final_score"] = float(row.get("final_score", row.get("score", 0.0))) + bonus
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("final_score", a.get("score", -INF))) > float(b.get("final_score", b.get("score", -INF)))
	)

func _choose_defense_preference_bonus(candidate: Dictionary) -> float:
	if str(candidate.get("kind", "")) != "choose_defense":
		return 0.0
	var payload: Dictionary = candidate.get("payload", {})
	if not str(payload.get("blocker_id", "")).is_empty():
		return 0.18
	if not str(payload.get("supporter_id", "")).is_empty():
		return 0.12
	var guard_card_ids: Array[String] = _payload_string_array(payload.get("master_guard_card_ids", []))
	if guard_card_ids.size() == 1:
		return 0.06
	if guard_card_ids.size() >= 2:
		return 0.0
	return 0.0

func _apply_play_card_preference(state, ranked: Array[Dictionary]) -> void:
	if state == null or ranked.is_empty():
		return
	for row in ranked:
		var candidate: Dictionary = row.get("candidate", {})
		var bonus := _play_card_preference_bonus(state, candidate)
		if bonus == 0.0:
			continue
		row["final_score"] = float(row.get("final_score", row.get("score", 0.0))) + bonus
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("final_score", a.get("score", -INF))) > float(b.get("final_score", b.get("score", -INF)))
	)

func _play_card_preference_bonus(state, candidate: Dictionary) -> float:
	if state == null or str(candidate.get("kind", "")) != "play_card":
		return 0.0
	var play_kind := str(candidate.get("play_kind", candidate.get("extra", {}).get("play_kind", "")))
	if play_kind == "hand_response" or play_kind == "counter_tactic":
		return 0.0
	var payload: Dictionary = candidate.get("payload", {})
	var bonus := 0.0
	if str(payload.get("row", "")) == "front":
		bonus += 0.10
	var card_id := str(payload.get("card_id", ""))
	if card_id.is_empty():
		return bonus
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return bonus
	var definition = state.get_definition(str(instance.definition_id))
	if definition == null:
		return bonus
	var cost := int(definition.cost)
	if cost <= 1:
		bonus += 0.05
	elif cost == 2:
		bonus += 0.02
	return bonus

func _evaluate_followup_sequence(profile: Dictionary, engine, state, player_id: int, candidate: Dictionary, opponent_guess: Dictionary, simulation: Dictionary) -> Dictionary:
	var result := {
		"score": 0.0,
		"summary": "",
		"payload": {}
	}
	var candidate_kind := str(candidate.get("kind", ""))
	if candidate_kind == "declare_attack":
		var breakdown: Dictionary = simulation.get("breakdown", {})
		var attack_followup_score: float = float(breakdown.get("attack_followup_pressure_score", 0.0))
		if attack_followup_score <= 0.0:
			return result
		result["score"] = attack_followup_score
		result["summary"] = "followup:master_pressure %s" % str(breakdown.get("attack_followup_pressure_summary", ""))
		result["payload"] = {
			"projected_master_damage": int(breakdown.get("attack_followup_projected_master_damage", 0))
		}
		return result
	if candidate_kind != "move_legion" and candidate_kind != "play_card" and candidate_kind != "activate_effect":
		return result
	var preview: Dictionary = candidate_simulator.preview_state_after_candidate(engine, state, player_id, candidate)
	if not bool(preview.get("ok", false)):
		return result
	var after_metrics: Dictionary = preview.get("after", {})
	if str(after_metrics.get("waiting_state", "")) != "WaitingForAction" or int(after_metrics.get("waiting_player", -1)) != player_id:
		return result
	if int(after_metrics.get("stack_size", 0)) != 0 or bool(after_metrics.get("pending_attack", false)):
		return result
	var preview_engine = preview.get("engine")
	var preview_state = preview.get("state")
	if preview_engine == null or preview_state == null:
		return result
	var actions: Array = preview_engine.get_legal_actions(preview_state, player_id)
	if actions.is_empty():
		return result
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(actions)
	if candidates.is_empty():
		return result
	var best_followup_score := -INF
	var best_followup_summary := ""
	var best_followup_payload: Dictionary = {}
	for followup_candidate in candidates:
		if not _is_proactive_followup_candidate(followup_candidate):
			continue
		var evaluation := feature_extractor.evaluate(profile, preview_engine, preview_state, player_id, followup_candidate, opponent_guess)
		var static_score: float = float(evaluation.get("score", 0.0))
		var followup_simulation := candidate_simulator.simulate_candidate(preview_engine, preview_state, player_id, followup_candidate)
		var simulation_score: float = float(followup_simulation.get("score", 0.0))
		var combo_bonus: float = _followup_sequence_combo_bonus(candidate_kind, str(followup_candidate.get("kind", "")))
		var combined_score: float = static_score + simulation_score * float(profile.get("simulation_weight", 0.6)) + combo_bonus
		if combined_score > best_followup_score:
			best_followup_score = combined_score
			best_followup_payload = followup_candidate.get("payload", {}).duplicate(true)
			best_followup_summary = "followup:%s static=%.2f sim=%.2f combo=%.2f %s" % [
				str(followup_candidate.get("command_type", "")),
				static_score,
				simulation_score,
				combo_bonus,
				str(followup_simulation.get("summary", ""))
			]
	if best_followup_score == -INF:
		return result
	result["score"] = best_followup_score
	result["summary"] = best_followup_summary
	result["payload"] = best_followup_payload
	return result

func _is_proactive_followup_candidate(candidate: Dictionary) -> bool:
	var kind := str(candidate.get("kind", ""))
	return kind == "declare_attack" or kind == "play_card" or kind == "activate_effect"

func _followup_sequence_combo_bonus(first_kind: String, second_kind: String) -> float:
	if first_kind == "activate_effect":
		if second_kind == "play_card":
			return 0.18
		if second_kind == "activate_effect":
			return 0.10
	if first_kind == "play_card" and second_kind == "declare_attack":
		return 0.06
	return 0.0

func _apply_hard_veto_filter(engine, state, player_id: int, ranked: Array[Dictionary]) -> void:
	if state == null or ranked.is_empty():
		return
	var veto_count := 0
	for row in ranked:
		row["vetoed"] = false
		row["veto_reason"] = ""
		var veto_reason := _candidate_veto_reason(engine, state, player_id, row)
		if veto_reason.is_empty():
			continue
		row["vetoed"] = true
		row["veto_reason"] = veto_reason
		veto_count += 1
	_apply_passive_action_vetoes(engine, state, player_id, ranked)
	veto_count = 0
	for row in ranked:
		if bool(row.get("vetoed", false)):
			veto_count += 1
	if veto_count <= 0 or veto_count >= ranked.size():
		if veto_count >= ranked.size():
			for row in ranked:
				row["vetoed"] = false
				row["veto_reason"] = ""
		return
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_vetoed := bool(a.get("vetoed", false))
		var b_vetoed := bool(b.get("vetoed", false))
		if a_vetoed != b_vetoed:
			return not a_vetoed
		return float(a.get("final_score", a.get("score", -INF))) > float(b.get("final_score", b.get("score", -INF)))
	)

func _pick_best_currently_valid_row(engine, state, player_id: int, ranked: Array[Dictionary]) -> Dictionary:
	if engine == null or state == null or not engine.has_method("validate_command"):
		return ranked[0] if not ranked.is_empty() else {}
	var has_non_veto := false
	for row in ranked:
		if not bool(row.get("vetoed", false)):
			has_non_veto = true
			break
	for row in ranked:
		if has_non_veto and bool(row.get("vetoed", false)):
			continue
		if _candidate_is_currently_valid(engine, state, player_id, row.get("candidate", {})):
			return row
	if has_non_veto:
		return {}
	for row in ranked:
		if _candidate_is_currently_valid(engine, state, player_id, row.get("candidate", {})):
			return row
	return {}

func _candidate_is_currently_valid(engine, state, player_id: int, candidate: Dictionary) -> bool:
	var command_type := str(candidate.get("command_type", ""))
	if command_type.is_empty():
		return false
	var payload: Dictionary = candidate.get("payload", {}).duplicate(true)
	var validation: Dictionary = engine.validate_command(state, GameCommand.create(player_id, command_type, payload))
	return bool(validation.get("ok", false))

func _board_unit_count(player) -> int:
	var count := 0
	for slot in player.battle_front:
		if not slot.occupant.is_empty():
			count += 1
	for slot in player.battle_back:
		if not slot.occupant.is_empty():
			count += 1
	return count

func _front_row_unit_count(player) -> int:
	var count := 0
	for slot in player.battle_front:
		if not slot.occupant.is_empty():
			count += 1
	return count

func _candidate_veto_reason(engine, state, player_id: int, row: Dictionary) -> String:
	var candidate: Dictionary = row.get("candidate", {})
	var breakdown: Dictionary = row.get("simulation_breakdown", {})
	var kind := str(candidate.get("kind", ""))
	if kind == "declare_attack":
		var attack_veto_reason := _declare_attack_veto_reason(engine, state, player_id, candidate)
		if not attack_veto_reason.is_empty():
			return attack_veto_reason
	if kind == "move_legion":
		var move_veto_reason := _move_legion_veto_reason(engine, state, player_id, candidate, breakdown)
		if not move_veto_reason.is_empty():
			return move_veto_reason
	if kind == "pass_priority":
		var pass_veto_reason := _pass_priority_veto_reason(engine, state, player_id)
		if not pass_veto_reason.is_empty():
			return pass_veto_reason
	if kind == "choose_defense":
		var defense_veto_reason := _choose_defense_veto_reason(engine, state, player_id, candidate)
		if not defense_veto_reason.is_empty():
			return defense_veto_reason
	if kind == "declare_attack" and _is_zero_payoff_attack_trade(breakdown):
		return "suicidal_attack_no_followup"
	if kind == "move_legion" and _is_zero_payoff_morale_move(breakdown):
		return "move_legion_burns_morale_without_payoff"
	if kind == "activate_effect" and _effect_requires_followup_without_candidate(state, player_id, candidate):
		return "effect_followup_missing"
	return ""

func _declare_attack_veto_reason(engine, state, player_id: int, candidate: Dictionary) -> String:
	if engine == null or state == null or player_id < 0 or player_id >= state.players.size():
		return ""
	if not engine.has_method("get_card_power") or not engine.has_method("validate_command"):
		return ""
	var payload: Dictionary = candidate.get("payload", {})
	if str(payload.get("target_kind", "card")) == "master":
		return ""
	var attacker_id := str(payload.get("attacker_id", ""))
	var defender_id := str(payload.get("defender_id", payload.get("target_card_id", "")))
	if attacker_id.is_empty() or defender_id.is_empty():
		return ""
	var attacker = state.card_instances.get(attacker_id)
	var defender = state.card_instances.get(defender_id)
	if attacker == null or defender == null:
		return ""
	if int(defender.controller) == player_id:
		return ""
	var attacker_power: int = int(engine.get_card_power(state, attacker_id))
	var defender_power: int = int(engine.get_card_power(state, defender_id))
	if attacker_power <= 0 or defender_power <= 0:
		return ""
	var better_kill_target := _find_better_killable_attack_target(engine, state, player_id, attacker_id, defender_id, attacker_power)
	if not better_kill_target.is_empty() and not _has_coordinated_attack_clear_plan(engine, state, player_id, attacker_id, defender_id, attacker_power, defender_power):
		return "prefer_killable_defender_over_nonlethal_target"
	if attacker_power >= defender_power:
		return ""
	var master_attack_validation: Dictionary = engine.validate_command(state, GameCommand.create(player_id, "DeclareAttack", {
		"attacker_id": attacker_id,
		"target_kind": "master",
		"target_player": 1 - player_id
	}))
	if bool(master_attack_validation.get("ok", false)):
		return "skip_stronger_defender_attack_master_available"
	return "skip_stronger_defender_attack"

func _find_better_killable_attack_target(engine, state, player_id: int, attacker_id: String, current_defender_id: String, attacker_power: int) -> String:
	if engine == null or state == null or attacker_id.is_empty() or current_defender_id.is_empty():
		return ""
	if not engine.has_method("get_legal_actions") or not engine.has_method("get_card_power"):
		return ""
	var current_defender_power: int = int(engine.get_card_power(state, current_defender_id))
	if current_defender_power <= 0 or attacker_power >= current_defender_power:
		return ""
	var legal_actions: Array = engine.get_legal_actions(state, player_id)
	for action in legal_actions:
		if str(action.get("kind", "")) != "declare_attack":
			continue
		var payload_template: Dictionary = action.get("payload_template", {})
		if str(payload_template.get("attacker_id", "")) != attacker_id:
			continue
		for target in action.get("targets", []):
			if not (target is Dictionary):
				continue
			if str(target.get("target_kind", "card")) != "card":
				continue
			var defender_id := str(target.get("defender_id", target.get("target_card_id", "")))
			if defender_id.is_empty() or defender_id == current_defender_id:
				continue
			var defender_power: int = int(engine.get_card_power(state, defender_id))
			if defender_power > 0 and attacker_power >= defender_power:
				return defender_id
	return ""

func _has_coordinated_attack_clear_plan(engine, state, player_id: int, attacker_id: String, defender_id: String, attacker_power: int, defender_power: int) -> bool:
	if engine == null or state == null:
		return false
	if attacker_id.is_empty() or defender_id.is_empty() or attacker_power <= 0 or defender_power <= 0:
		return false
	if attacker_power >= defender_power:
		return false
	if not engine.has_method("get_legal_actions") or not engine.has_method("get_card_power"):
		return false
	var defender_instance = state.card_instances.get(defender_id)
	if defender_instance == null or int(defender_instance.controller) == player_id:
		return false
	var defender_definition = state.get_definition(str(defender_instance.definition_id))
	var defender_keywords = defender_definition.keywords if defender_definition != null else []
	var high_threat: bool = defender_power >= 4000 or (defender_keywords is Array and (defender_keywords.has("taunt") or defender_keywords.has("ranged") or defender_keywords.has("ranged_attack")))
	if not high_threat:
		return false
	var total_power := attacker_power
	var support_count := 0
	var legal_actions: Array = engine.get_legal_actions(state, player_id)
	for action in legal_actions:
		if str(action.get("kind", "")) != "declare_attack":
			continue
		var payload_template: Dictionary = action.get("payload_template", {})
		var other_attacker_id := str(payload_template.get("attacker_id", ""))
		if other_attacker_id.is_empty() or other_attacker_id == attacker_id:
			continue
		var can_hit_same_target := false
		for target in action.get("targets", []):
			if str(target.get("target_kind", "card")) != "card":
				continue
			if str(target.get("defender_id", target.get("target_card_id", ""))) == defender_id:
				can_hit_same_target = true
				break
		if not can_hit_same_target:
			continue
		var other_power: int = int(engine.get_card_power(state, other_attacker_id))
		if other_power <= 0:
			continue
		total_power += other_power
		support_count += 1
		if total_power >= defender_power:
			return true
	return false

func _move_legion_veto_reason(engine, state, player_id: int, candidate: Dictionary, breakdown: Dictionary) -> String:
	if engine == null or state == null or player_id < 0 or player_id >= state.players.size():
		return ""
	if not engine.has_method("get_legal_actions"):
		return ""
	var payload: Dictionary = candidate.get("payload", {})
	var card_id := str(payload.get("card_id", ""))
	if card_id.is_empty():
		return ""
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return ""
	var current_row := str(instance.position.get("row", ""))
	var legal_actions: Array = engine.get_legal_actions(state, player_id)
	var same_card_attack_available := false
	var any_attack_available := false
	for action in legal_actions:
		if str(action.get("kind", "")) != "declare_attack":
			continue
		var action_payload: Dictionary = action.get("payload_template", {})
		var attacker_id := str(action_payload.get("attacker_id", ""))
		if attacker_id.is_empty():
			for target in action.get("targets", []):
				if str(target.get("attacker_id", "")) == card_id:
					attacker_id = card_id
					break
		if attacker_id.is_empty():
			continue
		any_attack_available = true
		if attacker_id == card_id:
			same_card_attack_available = true
			break
	if current_row == "front" and same_card_attack_available:
		return "move_legion_skips_available_attack"
	var morale_loss := int(breakdown.get("self_active_morale_loss", 0))
	var followup_attack_found := bool(breakdown.get("followup_attack_found", false))
	if morale_loss > 0 and any_attack_available and not followup_attack_found:
		return "move_legion_burns_morale_when_attack_available"
	return ""

func _pass_priority_veto_reason(engine, state, player_id: int) -> String:
	if engine == null or state == null or player_id < 0 or player_id >= state.players.size():
		return ""
	if not engine.has_method("get_waiting_state") or not engine.has_method("get_legal_actions"):
		return ""
	var waiting: Dictionary = engine.get_waiting_state(state)
	if str(waiting.get("state", "")) != "WaitingForPriority":
		return ""
	var pending_attack: Dictionary = state.pending_attack
	var master_attack_on_self := false
	if not pending_attack.is_empty():
		master_attack_on_self = str(pending_attack.get("target_kind", "")) == "master" and int(pending_attack.get("target_player", -1)) == player_id
	var legal_actions: Array = engine.get_legal_actions(state, player_id)
	for action in legal_actions:
		var action_kind := str(action.get("kind", ""))
		if action_kind == "choose_defense":
			return "pass_priority_skips_master_defense" if master_attack_on_self else "pass_priority_skips_available_defense"
		if action_kind == "activate_effect":
			return "pass_priority_skips_master_defense" if master_attack_on_self else "pass_priority_skips_effect_response"
		if action_kind == "play_card":
			var play_kind := str(action.get("play_kind", action.get("extra", {}).get("play_kind", "")))
			if play_kind == "hand_response":
				return "pass_priority_skips_master_defense" if master_attack_on_self else "pass_priority_skips_hand_response"
			if play_kind == "counter_tactic":
				return "pass_priority_skips_master_defense" if master_attack_on_self else "pass_priority_skips_counter_tactic"
	return ""

func _apply_passive_action_vetoes(engine, state, player_id: int, ranked: Array[Dictionary]) -> void:
	if engine == null or state == null or ranked.is_empty():
		return
	for row in ranked:
		if bool(row.get("vetoed", false)):
			continue
		var candidate: Dictionary = row.get("candidate", {})
		if str(candidate.get("kind", "")) != "end_phase":
			continue
		var veto_reason := _end_phase_veto_reason(engine, state, player_id, row, ranked)
		if veto_reason.is_empty():
			continue
		row["vetoed"] = true
		row["veto_reason"] = veto_reason

func _end_phase_veto_reason(engine, state, player_id: int, passive_row: Dictionary, ranked: Array[Dictionary]) -> String:
	if engine == null or state == null:
		return ""
	if not engine.has_method("get_waiting_state"):
		return ""
	var waiting: Dictionary = engine.get_waiting_state(state)
	if str(waiting.get("state", "")) != "WaitingForAction":
		return ""
	for row in ranked:
		if _is_same_ranked_row(passive_row, row):
			continue
		if bool(row.get("vetoed", false)):
			continue
		if not _candidate_is_currently_valid(engine, state, player_id, row.get("candidate", {})):
			continue
		var proactive_reason := _proactive_reason_to_keep_over_end_phase(row)
		if not proactive_reason.is_empty():
			return proactive_reason
	return ""

func _is_same_ranked_row(a: Dictionary, b: Dictionary) -> bool:
	var a_candidate: Dictionary = a.get("candidate", {})
	var b_candidate: Dictionary = b.get("candidate", {})
	return str(a_candidate.get("candidate_id", "")) == str(b_candidate.get("candidate_id", "")) \
		and str(a_candidate.get("command_type", "")) == str(b_candidate.get("command_type", "")) \
		and JSON.stringify(a_candidate.get("payload", {})) == JSON.stringify(b_candidate.get("payload", {}))

func _proactive_reason_to_keep_over_end_phase(row: Dictionary) -> String:
	var candidate: Dictionary = row.get("candidate", {})
	var kind := str(candidate.get("kind", ""))
	if kind == "declare_attack":
		var payload: Dictionary = candidate.get("payload", {})
		if str(payload.get("target_kind", "card")) == "master":
			return "end_phase_skips_master_attack"
		return "end_phase_skips_available_attack"
	if kind == "activate_effect":
		if _row_has_positive_followup(row):
			return "end_phase_skips_effect_combo"
		if _row_has_immediate_gain(row):
			return "end_phase_skips_effect_value"
	if kind == "play_card":
		if _row_has_positive_followup(row):
			return "end_phase_skips_play_combo"
		if _row_has_immediate_gain(row):
			return "end_phase_skips_play_develop"
	if kind == "move_legion":
		if _row_has_positive_followup(row):
			return "end_phase_skips_move_combo"
		if _row_has_immediate_gain(row):
			return "end_phase_skips_move_develop"
	return ""

func _row_has_positive_momentum(row: Dictionary) -> bool:
	return _row_has_positive_followup(row) or _row_has_immediate_gain(row)

func _row_has_positive_followup(row: Dictionary) -> bool:
	if float(row.get("followup_sequence_score", 0.0)) > 0.0:
		return true
	var breakdown: Dictionary = row.get("simulation_breakdown", {})
	return bool(breakdown.get("followup_attack_found", false))

func _row_has_immediate_gain(row: Dictionary) -> bool:
	var breakdown: Dictionary = row.get("simulation_breakdown", {})
	return int(breakdown.get("enemy_master_damage", 0)) > 0 \
		or int(breakdown.get("enemy_board_cleared", 0)) > 0 \
		or int(breakdown.get("self_board_gain", 0)) > 0 \
		or int(breakdown.get("self_front_gain", 0)) > 0


func _payload_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _choose_defense_veto_reason(engine, state, player_id: int, candidate: Dictionary) -> String:
	if engine == null or state == null or player_id < 0 or player_id >= state.players.size():
		return ""
	if not engine.has_method("get_legal_actions"):
		return ""
	var payload: Dictionary = candidate.get("payload", {})
	var guard_card_ids: Array[String] = _payload_string_array(payload.get("master_guard_card_ids", []))
	if guard_card_ids.size() < 2:
		return ""
	var legal_actions: Array = engine.get_legal_actions(state, player_id)
	for action in legal_actions:
		if str(action.get("kind", "")) != "choose_defense":
			continue
		var alt_payload: Dictionary = action.get("payload", {})
		if not str(alt_payload.get("blocker_id", "")).is_empty():
			return "prefer_non_guard_defense_over_multi_guard"
		if not str(alt_payload.get("supporter_id", "")).is_empty():
			return "prefer_non_guard_defense_over_multi_guard"
		var alt_guard_card_ids: Array[String] = _payload_string_array(alt_payload.get("master_guard_card_ids", []))
		if alt_guard_card_ids.size() == 1:
			return "prefer_single_card_guard_over_multi_guard"
	return ""

func _is_zero_payoff_attack_trade(breakdown: Dictionary) -> bool:
	return int(breakdown.get("self_board_loss", 0)) > 0 \
		and int(breakdown.get("enemy_board_cleared", 0)) <= 0 \
		and int(breakdown.get("enemy_master_damage", 0)) <= 0 \
		and int(breakdown.get("self_board_gain", 0)) <= 0

func _is_zero_payoff_morale_move(breakdown: Dictionary) -> bool:
	return int(breakdown.get("self_active_morale_loss", 0)) > 0 \
		and int(breakdown.get("enemy_board_cleared", 0)) <= 0 \
		and int(breakdown.get("enemy_master_damage", 0)) <= 0 \
		and int(breakdown.get("self_board_gain", 0)) <= 0 \
		and int(breakdown.get("self_front_gain", 0)) <= 0

func _effect_requires_followup_without_candidate(state, player_id: int, candidate: Dictionary) -> bool:
	if state == null or player_id < 0 or player_id >= state.players.size():
		return false
	var payload: Dictionary = candidate.get("payload", {})
	var effect_id := str(payload.get("effect_id", ""))
	if effect_id.is_empty():
		return false
	var source_instance = _resolve_source_instance(state, candidate)
	if source_instance == null:
		return false
	var definition = state.get_definition(str(source_instance.definition_id))
	if definition == null:
		return false
	var effect_definition := _resolve_effect_definition(definition.effects, effect_id)
	if effect_definition.is_empty():
		return false
	var resolution: Dictionary = effect_definition.get("resolution", {})
	var action := str(resolution.get("action", ""))
	if action != "sacrifice_source_and_deploy_from_hand" and action != "deploy_matching_legion_from_hand":
		return false
	if not _has_open_battlefield_slot(state, player_id):
		return true
	return _matching_hand_effect_candidates(state, player_id, resolution).is_empty()

func _resolve_source_instance(state, candidate: Dictionary):
	var payload: Dictionary = candidate.get("payload", {})
	for key in ["source_id", "card_id", "attacker_id", "blocker_id", "supporter_id", "defender_id"]:
		var instance_id := str(payload.get(key, ""))
		if not instance_id.is_empty():
			return state.card_instances.get(instance_id)
	return null

func _resolve_effect_definition(effects, effect_id: String) -> Dictionary:
	if effect_id.is_empty() or not (effects is Array):
		return {}
	for raw_effect in effects:
		if not (raw_effect is Dictionary):
			continue
		if str(raw_effect.get("id", "")) == effect_id:
			return raw_effect
	return {}

func _matching_hand_effect_candidates(state, player_id: int, filters: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var player = state.get_player(player_id)
	for card_id in player.hand.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance == null:
			continue
		var definition = state.get_definition(str(instance.definition_id))
		if definition == null:
			continue
		var required_type := str(filters.get("type", ""))
		if not required_type.is_empty() and str(definition.type) != required_type:
			continue
		var required_definition_id := str(filters.get("id", ""))
		if not required_definition_id.is_empty() and str(definition.id) != required_definition_id:
			continue
		var required_faction := str(filters.get("faction", ""))
		if not required_faction.is_empty() and str(definition.faction) != required_faction:
			continue
		var required_calamity_level := int(filters.get("calamity_level", -1))
		if required_calamity_level >= 0 and int(definition.calamity_level) != required_calamity_level:
			continue
		var max_target_cost := int(filters.get("max_target_cost", filters.get("max_cost", -1)))
		if max_target_cost >= 0 and int(definition.cost) > max_target_cost:
			continue
		var max_target_power := int(filters.get("max_target_power", filters.get("max_power", -1)))
		if max_target_power >= 0 and int(definition.power) > max_target_power:
			continue
		result.append(str(card_id))
	return result

func _has_open_battlefield_slot(state, player_id: int) -> bool:
	if state == null or player_id < 0 or player_id >= state.players.size():
		return false
	var player = state.get_player(player_id)
	for row in [player.battle_front, player.battle_back]:
		for slot in row:
			if slot.occupant.is_empty():
				return true
	return false

func _format_top_candidates(top_candidates: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for row in top_candidates:
		var feature_summary := str(row.get("feature_summary", ""))
		var veto_suffix := ""
		if bool(row.get("vetoed", false)):
			veto_suffix = "!%s" % str(row.get("veto_reason", "vetoed"))
		if feature_summary.is_empty():
			parts.append("%s/%.2f%s" % [str(row.get("kind", "")), float(row.get("score", 0.0)), veto_suffix])
		else:
			parts.append("%s/%.2f%s{%s}" % [str(row.get("kind", "")), float(row.get("score", 0.0)), veto_suffix, feature_summary])
	return ",".join(parts)
