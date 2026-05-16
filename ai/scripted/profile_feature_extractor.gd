extends RefCounted
class_name ProfileFeatureExtractor

func evaluate(profile: Dictionary, engine, state, player_id: int, candidate: Dictionary, opponent_guess: Dictionary) -> Dictionary:
	var weights: Dictionary = profile.get("weights", {})
	var matchup_adjustments: Dictionary = profile.get("matchup_adjustments", {})
	var trace: Array[Dictionary] = []
	var bucket_totals := {
		"base": 0.0,
		"timing": 0.0,
		"action_kind": 0.0,
		"deploy": 0.0,
		"combat": 0.0,
		"state": 0.0,
		"source": 0.0,
		"target": 0.0,
		"matchup": 0.0
	}
	var active_features := _collect_active_features(engine, state, player_id, candidate)
	for feature in active_features:
		var bucket := str(feature.get("bucket", "base"))
		var key := str(feature.get("key", ""))
		var default_value := float(feature.get("default", 0.0))
		_add_trace(trace, bucket_totals, bucket, key, float(weights.get(key, default_value)))
	var primary_opponent_profile := str(opponent_guess.get("primary_profile_id", "unknown"))
	var matchup_weights: Dictionary = matchup_adjustments.get(primary_opponent_profile, {})
	for feature in active_features:
		var key := str(feature.get("key", ""))
		if matchup_weights.has(key):
			_add_trace(trace, bucket_totals, "matchup", "matchup:%s:%s" % [primary_opponent_profile, key], float(matchup_weights.get(key, 0.0)))
	var total_score := 0.0
	for row in trace:
		total_score += float(row.get("value", 0.0))
	var top_positive := _top_trace_items(trace, true, 3)
	var top_negative := _top_trace_items(trace, false, 2)
	return {
		"score": total_score,
		"trace": trace,
		"bucket_totals": bucket_totals,
		"top_positive": top_positive,
		"top_negative": top_negative,
		"feature_summary": _format_feature_summary(top_positive, top_negative)
	}

func _collect_active_features(engine, state, player_id: int, candidate: Dictionary) -> Array[Dictionary]:
	var features: Array[Dictionary] = []
	var action: Dictionary = candidate.get("action", {})
	var kind := str(candidate.get("kind", str(action.get("kind", ""))))
	var waiting: Dictionary = engine.get_waiting_state(state)
	var phase := str(state.phase)
	var payload: Dictionary = candidate.get("payload", {})
	var self_player = state.get_player(player_id)
	var enemy_player = state.get_player(1 - player_id)
	var source_definition = _resolve_source_definition(state, candidate)
	var effect_context: Dictionary = _build_effect_context(state, player_id, candidate, source_definition)
	var self_board_units := _board_unit_count(self_player)
	var enemy_board_units := _board_unit_count(enemy_player)
	var stage_context: Dictionary = _build_stage_context(state, player_id, self_board_units, enemy_board_units)
	var priority_context: Dictionary = _build_priority_context(engine, state, player_id)
	features.append({"bucket": "base", "key": "base", "default": 0.0})
	features.append({"bucket": "timing", "key": "phase:%s" % phase, "default": 0.0})
	features.append({"bucket": "timing", "key": "waiting:%s" % str(waiting.get("state", "")), "default": 0.0})
	features.append({"bucket": "action_kind", "key": "kind:%s" % kind, "default": 0.0})
	match kind:
		"pass_priority":
			features.append({"bucket": "action_kind", "key": "pass_priority", "default": -0.5})
			if bool(priority_context.get("response_available", false)):
				features.append({"bucket": "combat", "key": "pass_priority_with_response_available", "default": 0.0})
			if bool(priority_context.get("defending_master", false)):
				features.append({"bucket": "combat", "key": "pass_priority_while_defending_master", "default": 0.0})
			if bool(priority_context.get("defense_action_available", false)):
				features.append({"bucket": "combat", "key": "pass_priority_skips_defense_action", "default": 0.0})
			if bool(priority_context.get("hand_response_available", false)):
				features.append({"bucket": "combat", "key": "pass_priority_skips_hand_response", "default": 0.0})
			if bool(priority_context.get("counter_tactic_available", false)):
				features.append({"bucket": "combat", "key": "pass_priority_skips_counter_tactic", "default": 0.0})
			if bool(stage_context.get("survival_mode", false)):
				features.append({"bucket": "combat", "key": "pass_priority_in_survival_mode", "default": 0.0})
		"end_phase":
			features.append({"bucket": "action_kind", "key": "end_phase", "default": -1.0})
			var end_phase_context: Dictionary = _build_end_phase_context(engine, state, player_id)
			if bool(end_phase_context.get("play_available", false)):
				features.append({"bucket": "timing", "key": "end_phase_with_play_available", "default": 0.0})
			if bool(end_phase_context.get("attack_available", false)):
				features.append({"bucket": "timing", "key": "end_phase_with_attack_available", "default": 0.0})
			if bool(end_phase_context.get("effect_available", false)):
				features.append({"bucket": "timing", "key": "end_phase_with_effect_available", "default": 0.0})
			if bool(end_phase_context.get("move_available", false)):
				features.append({"bucket": "timing", "key": "end_phase_with_move_available", "default": 0.0})
			if bool(end_phase_context.get("hand_cards_available", false)):
				features.append({"bucket": "state", "key": "end_phase_with_hand_cards", "default": 0.0})
			if bool(end_phase_context.get("open_master_lane", false)):
				features.append({"bucket": "combat", "key": "end_phase_with_open_master_lane", "default": 0.0})
			if bool(end_phase_context.get("board_ahead", false)):
				features.append({"bucket": "state", "key": "end_phase_while_board_ahead", "default": 0.0})
			if bool(end_phase_context.get("front_ahead", false)):
				features.append({"bucket": "state", "key": "end_phase_while_front_ahead", "default": 0.0})
			if bool(end_phase_context.get("no_proactive_actions", false)):
				features.append({"bucket": "timing", "key": "end_phase_no_proactive_actions", "default": 0.0})
			if bool(stage_context.get("closing_window", false)):
				features.append({"bucket": "combat", "key": "end_phase_in_closing_window", "default": 0.0})
			if bool(stage_context.get("survival_mode", false)):
				features.append({"bucket": "combat", "key": "end_phase_in_survival_mode", "default": 0.0})
		"play_card":
			features.append({"bucket": "action_kind", "key": "play_card", "default": 1.0})
			var play_kind := str(action.get("play_kind", ""))
			features.append({"bucket": "deploy", "key": "play_kind:%s" % play_kind, "default": 0.0})
			var remaining_hand: int = self_player.hand.cards.size() - 1
			if play_kind == "hand_response":
				features.append({"bucket": "combat", "key": "plays_hand_response", "default": 0.0})
				if remaining_hand <= 0:
					features.append({"bucket": "combat", "key": "plays_hand_response_forces_topdeck", "default": 0.0})
				elif remaining_hand <= 1:
					features.append({"bucket": "combat", "key": "plays_hand_response_leaves_low_hand", "default": 0.0})
				if bool(stage_context.get("survival_mode", false)):
					features.append({"bucket": "combat", "key": "survival_mode_hand_response", "default": 0.0})
			elif play_kind == "counter_tactic":
				features.append({"bucket": "combat", "key": "plays_counter_tactic", "default": 0.0})
				if remaining_hand <= 0:
					features.append({"bucket": "combat", "key": "plays_counter_tactic_forces_topdeck", "default": 0.0})
				elif remaining_hand <= 1:
					features.append({"bucket": "combat", "key": "plays_counter_tactic_leaves_low_hand", "default": 0.0})
				if bool(stage_context.get("survival_mode", false)):
					features.append({"bucket": "combat", "key": "survival_mode_counter_tactic", "default": 0.0})
		"declare_attack":
			features.append({"bucket": "combat", "key": "declare_attack", "default": 0.6})
			if str(payload.get("target_kind", "card")) == "master":
				features.append({"bucket": "combat", "key": "attack_master", "default": 0.0})
				if bool(stage_context.get("closing_window", false)):
					features.append({"bucket": "combat", "key": "closing_window_attack_master", "default": 0.0})
		"activate_effect":
			features.append({"bucket": "action_kind", "key": "activate_effect", "default": 0.4})
		"move_legion":
			features.append({"bucket": "deploy", "key": "move_legion", "default": 0.2})
			var move_context: Dictionary = _build_move_legion_context(state, player_id, candidate)
			if bool(stage_context.get("needs_frontline_to_close", false)) and bool(move_context.get("move_to_frontline", false)):
				features.append({"bucket": "combat", "key": "closing_window_move_to_frontline", "default": 0.0})
			if bool(move_context.get("move_to_frontline", false)):
				features.append({"bucket": "deploy", "key": "move_to_frontline", "default": 0.0})
			if bool(move_context.get("move_to_backline", false)):
				features.append({"bucket": "deploy", "key": "move_to_backline", "default": 0.0})
			if bool(move_context.get("move_opens_master_lane_pressure", false)):
				features.append({"bucket": "combat", "key": "move_opens_master_lane_pressure", "default": 0.0})
			if bool(move_context.get("move_from_frontline_without_backup", false)):
				features.append({"bucket": "combat", "key": "move_from_frontline_without_backup", "default": 0.0})
		"choose_defense":
			features.append({"bucket": "combat", "key": "choose_defense", "default": 1.5})
			if bool(stage_context.get("survival_mode", false)):
				features.append({"bucket": "combat", "key": "survival_mode_choose_defense", "default": 0.0})
		"resolve_choice":
			features.append({"bucket": "timing", "key": "resolve_choice", "default": 1.8})
	if _is_board_deploy(candidate):
		features.append({"bucket": "deploy", "key": "board_deploy", "default": 0.8})
	var source_context := _build_source_context(state, candidate)
	if not source_definition.is_empty():
		var definition_id := str(source_definition.get("id", ""))
		var faction := str(source_definition.get("faction", ""))
		var card_type := str(source_definition.get("type", ""))
		if not definition_id.is_empty():
			features.append({"bucket": "source", "key": "source_def:%s" % definition_id, "default": 0.0})
		if not faction.is_empty():
			features.append({"bucket": "source", "key": "source_faction:%s" % faction, "default": 0.0})
		if not card_type.is_empty():
			features.append({"bucket": "source", "key": "source_type:%s" % card_type, "default": 0.0})
	if bool(source_context.get("source_frontline", false)):
		features.append({"bucket": "source", "key": "source_frontline", "default": 0.0})
	if bool(source_context.get("source_backline", false)):
		features.append({"bucket": "source", "key": "source_backline", "default": 0.0})
	if bool(source_context.get("source_has_supporter", false)):
		features.append({"bucket": "source", "key": "source_has_supporter", "default": 0.0})
	if bool(source_context.get("source_open_no_support", false)):
		features.append({"bucket": "source", "key": "source_open_no_support", "default": 0.0})
	if bool(effect_context.get("effect_search_deck", false)):
		features.append({"bucket": "combat", "key": "effect_search_deck", "default": 0.0})
	if bool(effect_context.get("effect_symmetric_draw", false)):
		features.append({"bucket": "combat", "key": "effect_symmetric_draw", "default": 0.0})
	if bool(effect_context.get("effect_reposition", false)):
		features.append({"bucket": "deploy", "key": "effect_reposition", "default": 0.0})
	if bool(effect_context.get("effect_targets_none", false)):
		features.append({"bucket": "target", "key": "effect_targets_none", "default": 0.0})
	if bool(effect_context.get("effect_targets_ally", false)):
		features.append({"bucket": "target", "key": "effect_targets_ally", "default": 0.0})
	if bool(effect_context.get("effect_targets_enemy", false)):
		features.append({"bucket": "target", "key": "effect_targets_enemy", "default": 0.0})
	if bool(effect_context.get("effect_self_master_damage", false)):
		features.append({"bucket": "combat", "key": "effect_self_master_damage", "default": 0.0})
	if bool(effect_context.get("effect_sacrifice_source", false)):
		features.append({"bucket": "combat", "key": "effect_sacrifice_source", "default": 0.0})
	if bool(effect_context.get("effect_deploy_from_hand", false)):
		features.append({"bucket": "deploy", "key": "effect_deploy_from_hand", "default": 0.0})
	if bool(effect_context.get("effect_unimplemented", false)):
		features.append({"bucket": "combat", "key": "effect_unimplemented", "default": 0.0})
	var self_grave_count: int = self_player.grave.cards.size()
	var enemy_grave_count: int = enemy_player.grave.cards.size()
	if kind == "activate_effect" and str(source_definition.get("type", "")) == "artifact":
		features.append({"bucket": "combat", "key": "activate_artifact_effect", "default": 0.0})
		if self_player.hand.cards.size() <= 1:
			features.append({"bucket": "combat", "key": "activate_artifact_effect_low_hand_tax", "default": 0.0})
		if enemy_player.master_hp <= 6 or (enemy_board_units == 0 and self_board_units > 0):
			features.append({"bucket": "combat", "key": "activate_artifact_effect_closing_window", "default": 0.0})
		elif enemy_player.master_hp > 6 and enemy_board_units >= self_board_units:
			features.append({"bucket": "combat", "key": "activate_artifact_effect_without_pressure", "default": 0.0})
	if self_grave_count >= 2:
		features.append({"bucket": "state", "key": "self_grave_ge_2", "default": 0.0})
	if self_grave_count >= 4:
		features.append({"bucket": "state", "key": "self_grave_ge_4", "default": 0.0})
	if self_grave_count >= 6:
		features.append({"bucket": "state", "key": "self_grave_ge_6", "default": 0.0})
	if enemy_grave_count >= 2:
		features.append({"bucket": "state", "key": "enemy_grave_ge_2", "default": 0.0})
	if enemy_grave_count >= 4:
		features.append({"bucket": "state", "key": "enemy_grave_ge_4", "default": 0.0})
	if self_board_units >= 2:
		features.append({"bucket": "state", "key": "self_board_units_ge_2", "default": 0.0})
	if enemy_board_units >= 2:
		features.append({"bucket": "state", "key": "enemy_board_units_ge_2", "default": 0.0})
	if self_player.master_hp <= 6:
		features.append({"bucket": "state", "key": "self_master_hp_le_6", "default": 0.0})
	if self_player.master_hp <= 3:
		features.append({"bucket": "state", "key": "self_master_hp_le_3", "default": 0.0})
	if enemy_player.master_hp <= 6:
		features.append({"bucket": "state", "key": "enemy_master_hp_le_6", "default": 0.0})
	if enemy_player.master_hp <= 3:
		features.append({"bucket": "state", "key": "enemy_master_hp_le_3", "default": 0.0})
	var combat_context := _build_combat_context(engine, state, player_id, candidate)
	if bool(combat_context.get("has_target_master", false)):
		features.append({"bucket": "target", "key": "target_master", "default": 0.0})
	if bool(combat_context.get("target_enemy_unit", false)):
		features.append({"bucket": "target", "key": "target_enemy_unit", "default": 0.0})
	if bool(combat_context.get("target_own_unit", false)):
		features.append({"bucket": "target", "key": "target_own_unit", "default": 0.0})
	if bool(combat_context.get("target_own_frontline", false)):
		features.append({"bucket": "target", "key": "target_own_frontline", "default": 0.0})
	if bool(combat_context.get("target_own_backline", false)):
		features.append({"bucket": "target", "key": "target_own_backline", "default": 0.0})
	if bool(combat_context.get("target_frontline", false)):
		features.append({"bucket": "target", "key": "target_frontline", "default": 0.0})
	if bool(combat_context.get("target_backline", false)):
		features.append({"bucket": "target", "key": "target_backline", "default": 0.0})
	if bool(combat_context.get("target_has_supporter", false)):
		features.append({"bucket": "target", "key": "target_has_supporter", "default": 0.0})
	if bool(combat_context.get("target_open_no_support", false)):
		features.append({"bucket": "target", "key": "target_open_no_support", "default": 0.0})
	if bool(combat_context.get("target_last_frontline", false)):
		features.append({"bucket": "target", "key": "target_last_frontline", "default": 0.0})
	if bool(combat_context.get("breaks_last_frontline_now", false)):
		features.append({"bucket": "combat", "key": "breaks_last_frontline_now", "default": 0.0})
	if bool(combat_context.get("next_turn_master_single_lane_pressure", false)):
		features.append({"bucket": "combat", "key": "next_turn_master_single_lane_pressure", "default": 0.0})
	if bool(combat_context.get("next_turn_master_multi_lane_pressure", false)):
		features.append({"bucket": "combat", "key": "next_turn_master_multi_lane_pressure", "default": 0.0})
	if bool(combat_context.get("next_turn_master_threat", false)):
		features.append({"bucket": "combat", "key": "next_turn_master_threat", "default": 0.0})
	if bool(combat_context.get("next_turn_master_lethal_pressure", false)):
		features.append({"bucket": "combat", "key": "next_turn_master_lethal_pressure", "default": 0.0})
	if bool(combat_context.get("next_turn_pressure_blunted_by_single_guard", false)):
		features.append({"bucket": "combat", "key": "next_turn_pressure_blunted_by_single_guard", "default": 0.0})
	if bool(combat_context.get("next_turn_multi_lane_overwhelms_single_guard", false)):
		features.append({"bucket": "combat", "key": "next_turn_multi_lane_overwhelms_single_guard", "default": 0.0})
	if bool(combat_context.get("next_turn_lethal_through_multi_guard_tax", false)):
		features.append({"bucket": "combat", "key": "next_turn_lethal_through_multi_guard_tax", "default": 0.0})
	if bool(combat_context.get("next_turn_multi_lane_draws_multi_guard", false)):
		features.append({"bucket": "combat", "key": "next_turn_multi_lane_draws_multi_guard", "default": 0.0})
	if bool(combat_context.get("next_turn_multi_guard_consumes_half_hand", false)):
		features.append({"bucket": "combat", "key": "next_turn_multi_guard_consumes_half_hand", "default": 0.0})
	if bool(combat_context.get("next_turn_multi_guard_nearly_exhausts_hand", false)):
		features.append({"bucket": "combat", "key": "next_turn_multi_guard_nearly_exhausts_hand", "default": 0.0})
	if bool(combat_context.get("next_turn_multi_guard_leaves_low_hand", false)):
		features.append({"bucket": "combat", "key": "next_turn_multi_guard_leaves_low_hand", "default": 0.0})
	if bool(combat_context.get("next_turn_multi_guard_forces_topdeck", false)):
		features.append({"bucket": "combat", "key": "next_turn_multi_guard_forces_topdeck", "default": 0.0})
	if bool(combat_context.get("target_power_ge_4000", false)):
		features.append({"bucket": "target", "key": "target_power_ge_4000", "default": 0.0})
	if bool(combat_context.get("target_power_ge_6000", false)):
		features.append({"bucket": "target", "key": "target_power_ge_6000", "default": 0.0})
	if bool(combat_context.get("target_power_le_2000", false)):
		features.append({"bucket": "target", "key": "target_power_le_2000", "default": 0.0})
	if bool(combat_context.get("favorable_trade", false)):
		features.append({"bucket": "combat", "key": "favorable_trade", "default": 0.0})
	if bool(combat_context.get("risky_trade", false)):
		features.append({"bucket": "combat", "key": "risky_trade", "default": 0.0})
	if bool(combat_context.get("cleanup_low_power_enemy", false)):
		features.append({"bucket": "combat", "key": "cleanup_low_power_enemy", "default": 0.0})
	if bool(combat_context.get("defending_master", false)):
		features.append({"bucket": "combat", "key": "defending_master", "default": 0.0})
	if bool(combat_context.get("intercept_high_power_attack", false)):
		features.append({"bucket": "combat", "key": "intercept_high_power_attack", "default": 0.0})
	if bool(combat_context.get("open_master_lane", false)):
		features.append({"bucket": "combat", "key": "open_master_lane", "default": 0.0})
	if bool(combat_context.get("master_guard_risk", false)):
		features.append({"bucket": "combat", "key": "master_guard_risk", "default": 0.0})
	if bool(combat_context.get("master_guard_single_card_risk", false)):
		features.append({"bucket": "combat", "key": "master_guard_single_card_risk", "default": 0.0})
	if bool(combat_context.get("master_guard_multi_card_only", false)):
		features.append({"bucket": "combat", "key": "master_guard_multi_card_only", "default": 0.0})
	if bool(combat_context.get("enemy_set_counter_risk", false)):
		features.append({"bucket": "combat", "key": "enemy_set_counter_risk", "default": 0.0})
	if bool(combat_context.get("defense_with_blocker", false)):
		features.append({"bucket": "combat", "key": "defense_with_blocker", "default": 0.0})
	if bool(combat_context.get("defense_with_blocker_preserves_hand", false)):
		features.append({"bucket": "combat", "key": "defense_with_blocker_preserves_hand", "default": 0.0})
	if bool(combat_context.get("defense_with_supporter", false)):
		features.append({"bucket": "combat", "key": "defense_with_supporter", "default": 0.0})
	if bool(combat_context.get("defense_with_supporter_preserves_hand", false)):
		features.append({"bucket": "combat", "key": "defense_with_supporter_preserves_hand", "default": 0.0})
	if bool(combat_context.get("defense_support_preserves_counterattack_window", false)):
		features.append({"bucket": "combat", "key": "defense_support_preserves_counterattack_window", "default": 0.0})
	if bool(combat_context.get("defense_support_protects_master", false)):
		features.append({"bucket": "combat", "key": "defense_support_protects_master", "default": 0.0})
	if bool(combat_context.get("defense_support_protects_board", false)):
		features.append({"bucket": "combat", "key": "defense_support_protects_board", "default": 0.0})
	if bool(combat_context.get("defense_with_master_guard", false)):
		features.append({"bucket": "combat", "key": "defense_with_master_guard", "default": 0.0})
	if bool(combat_context.get("defense_single_card_master_guard", false)):
		features.append({"bucket": "combat", "key": "defense_single_card_master_guard", "default": 0.0})
	if bool(combat_context.get("defense_multi_card_master_guard", false)):
		features.append({"bucket": "combat", "key": "defense_multi_card_master_guard", "default": 0.0})
	if bool(combat_context.get("defense_master_guard_keeps_counterattack_window", false)):
		features.append({"bucket": "combat", "key": "defense_master_guard_keeps_counterattack_window", "default": 0.0})
	if bool(combat_context.get("defense_master_guard_only_buys_time", false)):
		features.append({"bucket": "combat", "key": "defense_master_guard_only_buys_time", "default": 0.0})
	if bool(combat_context.get("defense_master_guard_consumes_half_hand", false)):
		features.append({"bucket": "combat", "key": "defense_master_guard_consumes_half_hand", "default": 0.0})
	if bool(combat_context.get("defense_master_guard_leaves_low_hand", false)):
		features.append({"bucket": "combat", "key": "defense_master_guard_leaves_low_hand", "default": 0.0})
	if bool(combat_context.get("defense_master_guard_forces_topdeck", false)):
		features.append({"bucket": "combat", "key": "defense_master_guard_forces_topdeck", "default": 0.0})
	var target_definition: Dictionary = combat_context.get("target_definition", {})
	if not target_definition.is_empty():
		var target_definition_id := str(target_definition.get("id", ""))
		var target_faction := str(target_definition.get("faction", ""))
		if not target_definition_id.is_empty():
			features.append({"bucket": "target", "key": "target_def:%s" % target_definition_id, "default": 0.0})
		if not target_faction.is_empty():
			features.append({"bucket": "target", "key": "target_faction:%s" % target_faction, "default": 0.0})
	return features

func _is_board_deploy(candidate: Dictionary) -> bool:
	var payload: Dictionary = candidate.get("payload", {})
	var row := str(payload.get("row", ""))
	return row == "front" or row == "back"


func _build_stage_context(state, player_id: int, self_board_units: int, enemy_board_units: int) -> Dictionary:
	var context := {
		"survival_mode": false,
		"closing_window": false,
		"needs_frontline_to_close": false
	}
	if state == null or player_id < 0 or player_id >= state.players.size():
		return context
	var self_player = state.get_player(player_id)
	var enemy_player = state.get_player(1 - player_id)
	var self_front: int = _front_row_unit_count(self_player)
	var enemy_front: int = _front_row_unit_count(enemy_player)
	context["survival_mode"] = self_player.master_hp <= 3 or (self_player.master_hp <= 6 and enemy_board_units > self_board_units)
	context["closing_window"] = enemy_player.master_hp <= 3 or (enemy_player.master_hp <= 6 and enemy_front == 0 and self_front > 0)
	context["needs_frontline_to_close"] = enemy_player.master_hp <= 6 and enemy_front == 0 and self_front == 0 and self_board_units > 0
	return context

func _build_priority_context(engine, state, player_id: int) -> Dictionary:
	var context := {
		"response_available": false,
		"defending_master": false,
		"defense_action_available": false,
		"hand_response_available": false,
		"counter_tactic_available": false
	}
	if engine == null or state == null or player_id < 0 or player_id >= state.players.size():
		return context
	var waiting: Dictionary = engine.get_waiting_state(state)
	if str(waiting.get("state", "")) != "WaitingForPriority":
		return context
	if not state.pending_attack.is_empty() and int(state.pending_attack.get("target_player", -1)) == player_id:
		context["defending_master"] = str(state.pending_attack.get("target_kind", "")) == "master"
	var actions: Array = engine.get_legal_actions(state, player_id)
	for action in actions:
		var action_kind := str(action.get("kind", ""))
		if action_kind == "choose_defense":
			context["response_available"] = true
			context["defense_action_available"] = true
			continue
		if action_kind != "play_card":
			continue
		var play_kind := str(action.get("play_kind", action.get("extra", {}).get("play_kind", "")))
		if play_kind == "hand_response":
			context["response_available"] = true
			context["hand_response_available"] = true
		elif play_kind == "counter_tactic":
			context["response_available"] = true
			context["counter_tactic_available"] = true
	return context

func _build_end_phase_context(engine, state, player_id: int) -> Dictionary:
	var context := {
		"play_available": false,
		"attack_available": false,
		"effect_available": false,
		"move_available": false,
		"hand_cards_available": false,
		"open_master_lane": false,
		"board_ahead": false,
		"front_ahead": false,
		"no_proactive_actions": true
	}
	if engine == null or state == null or player_id < 0 or player_id >= state.players.size():
		return context
	var self_player = state.get_player(player_id)
	var enemy_player = state.get_player(1 - player_id)
	var actions: Array = engine.get_legal_actions(state, player_id)
	for action in actions:
		var kind := str(action.get("kind", ""))
		match kind:
			"play_card":
				context["play_available"] = true
				context["no_proactive_actions"] = false
			"declare_attack":
				context["attack_available"] = true
				context["no_proactive_actions"] = false
			"activate_effect":
				context["effect_available"] = true
				context["no_proactive_actions"] = false
			"move_legion":
				context["move_available"] = true
				context["no_proactive_actions"] = false
	var self_front: int = _front_row_unit_count(self_player)
	var enemy_front: int = _front_row_unit_count(enemy_player)
	var self_board: int = _board_unit_count(self_player)
	var enemy_board: int = _board_unit_count(enemy_player)
	context["hand_cards_available"] = self_player.hand.cards.size() > 0
	context["open_master_lane"] = enemy_front == 0 and self_front > 0
	context["board_ahead"] = self_board > enemy_board
	context["front_ahead"] = self_front > enemy_front
	return context


func _build_move_legion_context(state, player_id: int, candidate: Dictionary) -> Dictionary:
	var context := {
		"move_to_frontline": false,
		"move_to_backline": false,
		"move_opens_master_lane_pressure": false,
		"move_from_frontline_without_backup": false
	}
	if state == null or player_id < 0 or player_id >= state.players.size():
		return context
	var payload: Dictionary = candidate.get("payload", {})
	var card_id := str(payload.get("card_id", ""))
	if card_id.is_empty():
		return context
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return context
	var from_row := str(instance.position.get("row", ""))
	var to_row := str(payload.get("row", ""))
	if to_row.is_empty() or from_row == to_row:
		return context
	var self_player = state.get_player(player_id)
	var enemy_player = state.get_player(1 - player_id)
	var self_front_before: int = _front_row_unit_count(self_player)
	var enemy_front: int = _front_row_unit_count(enemy_player)
	context["move_to_frontline"] = to_row == "front"
	context["move_to_backline"] = to_row == "back"
	if from_row == "back" and to_row == "front" and enemy_front == 0:
		context["move_opens_master_lane_pressure"] = true
	if from_row == "front" and to_row == "back" and self_front_before <= 1:
		context["move_from_frontline_without_backup"] = true
	return context

func _build_effect_context(state, player_id: int, candidate: Dictionary, source_definition: Dictionary) -> Dictionary:
	var context := {
		"effect_search_deck": false,
		"effect_symmetric_draw": false,
		"effect_reposition": false,
		"effect_targets_none": false,
		"effect_targets_ally": false,
		"effect_targets_enemy": false,
		"effect_self_master_damage": false,
		"effect_sacrifice_source": false,
		"effect_deploy_from_hand": false,
		"effect_unimplemented": false
	}
	if state == null or player_id < 0 or player_id >= state.players.size():
		return context
	var payload: Dictionary = candidate.get("payload", {})
	var effect_id := str(payload.get("effect_id", ""))
	if effect_id.is_empty():
		return context
	var target_kind := str(payload.get("target_kind", ""))
	context["effect_targets_none"] = target_kind == "none"
	var target_card_id := str(payload.get("target_card_id", ""))
	if not target_card_id.is_empty():
		var target_instance = state.card_instances.get(target_card_id)
		if target_instance != null:
			var target_controller: int = int(target_instance.controller)
			context["effect_targets_ally"] = target_controller == player_id
			context["effect_targets_enemy"] = target_controller != player_id
	if effect_id == "oiran_search":
		context["effect_search_deck"] = true
	elif effect_id == "truce_offer":
		context["effect_symmetric_draw"] = true
	elif effect_id == "yoshitsune_reposition":
		context["effect_reposition"] = true
	var resolution_action := _resolve_effect_action(source_definition, effect_id)
	var resolution: Dictionary = _resolve_effect_definition(source_definition, effect_id).get("resolution", {})
	context["effect_self_master_damage"] = int(resolution.get("self_master_damage", 0)) > 0
	context["effect_sacrifice_source"] = resolution_action == "sacrifice_source_and_deploy_from_hand"
	context["effect_deploy_from_hand"] = resolution_action == "sacrifice_source_and_deploy_from_hand" or resolution_action == "deploy_matching_legion_from_hand"
	if resolution_action in [
		"grant_master_damage_bonus",
		"grant_front_attack_power_bonus",
		"modify_target_cost",
		"modify_target_cost_until_next_own_turn_end"
	]:
		context["effect_unimplemented"] = true
	return context

func _resolve_effect_action(source_definition: Dictionary, effect_id: String) -> String:
	var effect_definition: Dictionary = _resolve_effect_definition(source_definition, effect_id)
	if effect_definition.is_empty():
		return ""
	var resolution: Dictionary = effect_definition.get("resolution", {})
	return str(resolution.get("action", ""))

func _resolve_effect_definition(source_definition: Dictionary, effect_id: String) -> Dictionary:
	if effect_id.is_empty() or source_definition.is_empty():
		return {}
	var effects = source_definition.get("effects", [])
	if not (effects is Array):
		return {}
	for raw_effect in effects:
		if not (raw_effect is Dictionary):
			continue
		if str(raw_effect.get("id", "")) != effect_id:
			continue
		return raw_effect
	return {}
func _resolve_source_definition(state, candidate: Dictionary) -> Dictionary:
	var instance = _resolve_source_instance(state, candidate)
	if instance == null:
		return {}
	var definition = state.get_definition(str(instance.definition_id))
	if definition == null:
		return {}
	return {
		"id": str(definition.id),
		"name": str(definition.name),
		"faction": str(definition.faction),
		"type": str(definition.type)
	}

func _resolve_source_instance(state, candidate: Dictionary):
	var payload: Dictionary = candidate.get("payload", {})
	var action: Dictionary = candidate.get("action", {})
	var source_instance_id := ""
	for key in ["card_id", "source_id", "attacker_id", "blocker_id", "supporter_id", "defender_id"]:
		var value := str(payload.get(key, ""))
		if not value.is_empty():
			source_instance_id = value
			break
	if source_instance_id.is_empty():
		var source_dict: Dictionary = action.get("source", {})
		source_instance_id = str(source_dict.get("card_id", ""))
	if source_instance_id.is_empty():
		return null
	return state.card_instances.get(source_instance_id)

func _build_source_context(state, candidate: Dictionary) -> Dictionary:
	var context := {
		"source_frontline": false,
		"source_backline": false,
		"source_has_supporter": false,
		"source_open_no_support": false
	}
	var instance = _resolve_source_instance(state, candidate)
	if instance == null or not str(instance.zone).begins_with("battle_"):
		return context
	var row := str(instance.position.get("row", ""))
	var col := int(instance.position.get("col", -1))
	context["source_frontline"] = row == "front"
	context["source_backline"] = row == "back"
	if row != "front" or col < 0:
		return context
	var player = state.get_player(int(instance.controller))
	var support_slot = player.get_slot("back", col)
	if support_slot == null or support_slot.occupant.is_empty():
		context["source_open_no_support"] = true
		return context
	var supporter = state.card_instances.get(str(support_slot.occupant))
	if supporter == null:
		context["source_open_no_support"] = true
		return context
	var can_support: bool = supporter.orientation == "active" and int(supporter.flags.get("cannot_support_until_turn_end_turn", -1)) != state.turn_number
	context["source_has_supporter"] = can_support
	context["source_open_no_support"] = not can_support
	return context

func _build_combat_context(engine, state, player_id: int, candidate: Dictionary) -> Dictionary:
	var payload: Dictionary = candidate.get("payload", {})
	var action: Dictionary = candidate.get("action", {})
	var kind := str(candidate.get("kind", str(action.get("kind", ""))))
	var context := {
		"has_target_master": false,
		"has_target_card": false,
		"target_enemy_unit": false,
		"target_own_unit": false,
		"target_own_frontline": false,
		"target_own_backline": false,
		"target_frontline": false,
		"target_backline": false,
		"target_has_supporter": false,
		"target_open_no_support": false,
		"target_last_frontline": false,
		"breaks_last_frontline_now": false,
		"next_turn_master_single_lane_pressure": false,
		"next_turn_master_multi_lane_pressure": false,
		"next_turn_master_threat": false,
		"next_turn_master_lethal_pressure": false,
		"next_turn_pressure_blunted_by_single_guard": false,
		"next_turn_multi_lane_overwhelms_single_guard": false,
		"next_turn_lethal_through_multi_guard_tax": false,
		"next_turn_multi_lane_draws_multi_guard": false,
		"next_turn_multi_guard_consumes_half_hand": false,
		"next_turn_multi_guard_nearly_exhausts_hand": false,
		"next_turn_multi_guard_leaves_low_hand": false,
		"next_turn_multi_guard_forces_topdeck": false,
		"target_power_ge_4000": false,
		"target_power_ge_6000": false,
		"target_power_le_2000": false,
		"favorable_trade": false,
		"risky_trade": false,
		"cleanup_low_power_enemy": false,
		"defending_master": false,
		"intercept_high_power_attack": false,
		"open_master_lane": false,
		"master_guard_risk": false,
		"master_guard_single_card_risk": false,
		"master_guard_multi_card_only": false,
		"enemy_set_counter_risk": false,
		"defense_with_blocker": false,
		"defense_with_blocker_preserves_hand": false,
		"defense_with_supporter": false,
		"defense_with_supporter_preserves_hand": false,
		"defense_support_preserves_counterattack_window": false,
		"defense_support_protects_master": false,
		"defense_support_protects_board": false,
		"defense_with_master_guard": false,
		"defense_single_card_master_guard": false,
		"defense_multi_card_master_guard": false,
		"defense_master_guard_keeps_counterattack_window": false,
		"defense_master_guard_only_buys_time": false,
		"defense_master_guard_consumes_half_hand": false,
		"defense_master_guard_leaves_low_hand": false,
		"defense_master_guard_forces_topdeck": false,
		"target_definition": {}
	}
	var target_kind := str(payload.get("target_kind", ""))
	if target_kind == "master":
		context["has_target_master"] = true
	if kind == "declare_attack":
		var attacker_id := str(payload.get("attacker_id", ""))
		var target_card_id := _resolve_target_card_id(candidate)
		if target_card_id.is_empty() and target_kind == "master":
			context["has_target_master"] = true
			context["open_master_lane"] = _front_row_unit_count(state.get_player(1 - player_id)) == 0
			var target_player := int(payload.get("target_player", candidate.get("target", {}).get("target_player", 1 - player_id)))
			var guard_sets = engine.get_legal_master_guard_card_sets(state, target_player, attacker_id, {
				"target_kind": "master",
				"target_player": target_player
			})
			context["master_guard_risk"] = not guard_sets.is_empty()
			if not guard_sets.is_empty():
				var minimum_guard_count: int = _minimum_guard_count(guard_sets)
				context["master_guard_single_card_risk"] = minimum_guard_count == 1
				context["master_guard_multi_card_only"] = minimum_guard_count >= 2
			context["enemy_set_counter_risk"] = _count_set_counter_tactics(state, target_player) > 0
		_fill_target_context(engine, state, player_id, target_card_id, context)
		context["enemy_set_counter_risk"] = bool(context.get("enemy_set_counter_risk", false)) or _count_set_counter_tactics(state, 1 - player_id) > 0
		_fill_trade_context(engine, state, attacker_id, target_card_id, context)
		if not target_card_id.is_empty():
			var supporters = engine.get_legal_supporters(state, target_card_id, attacker_id)
			context["target_has_supporter"] = not supporters.is_empty()
			context["target_open_no_support"] = supporters.is_empty()
			context["breaks_last_frontline_now"] = bool(context.get("target_last_frontline", false)) and bool(context.get("favorable_trade", false))
			var projected_damage := _project_next_turn_master_damage_after_clear(engine, state, attacker_id, target_card_id)
			context["next_turn_master_single_lane_pressure"] = projected_damage == 1
			context["next_turn_master_multi_lane_pressure"] = projected_damage >= 2
			context["next_turn_master_threat"] = _can_create_next_turn_master_threat(engine, state, attacker_id, target_card_id, context)
			context["next_turn_master_lethal_pressure"] = _can_create_next_turn_master_lethal_pressure(engine, state, attacker_id, target_card_id, context)
			var target_player := int(state.card_instances[target_card_id].controller)
			var future_guard_sets = engine.get_legal_master_guard_card_sets(state, target_player, attacker_id, {
				"target_kind": "master",
				"target_player": target_player
			})
			var future_minimum_guard_count := _minimum_guard_count(future_guard_sets)
			var target_hand_size: int = state.get_player(target_player).hand.cards.size()
			var remaining_after_guard: int = target_hand_size - max(0, future_minimum_guard_count)
			context["next_turn_pressure_blunted_by_single_guard"] = projected_damage == 1 and future_minimum_guard_count == 1
			context["next_turn_multi_lane_overwhelms_single_guard"] = projected_damage >= 2 and future_minimum_guard_count == 1
			context["next_turn_multi_lane_draws_multi_guard"] = projected_damage >= 2 and future_minimum_guard_count >= 2
			context["next_turn_lethal_through_multi_guard_tax"] = bool(context.get("next_turn_master_lethal_pressure", false)) and future_minimum_guard_count >= 2
			context["next_turn_multi_guard_forces_topdeck"] = future_minimum_guard_count >= 2 and remaining_after_guard <= 0
			context["next_turn_multi_guard_consumes_half_hand"] = future_minimum_guard_count >= 2 and target_hand_size > 0 and float(future_minimum_guard_count) / float(target_hand_size) >= 0.5
			context["next_turn_multi_guard_nearly_exhausts_hand"] = future_minimum_guard_count >= 2 and target_hand_size > 0 and future_minimum_guard_count >= target_hand_size - 1
			context["next_turn_multi_guard_leaves_low_hand"] = future_minimum_guard_count >= 2 and (remaining_after_guard <= 1 or bool(context.get("next_turn_multi_guard_forces_topdeck", false)))
		return context
	if kind == "choose_defense":
		var pending_attack: Dictionary = state.pending_attack
		var self_player = state.get_player(player_id)
		var attacker_id := str(pending_attack.get("attacker_id", ""))
		var defender_id := str(payload.get("defender_id", payload.get("target_card_id", "")))
		if defender_id.is_empty():
			defender_id = str(pending_attack.get("defender_id", ""))
		if str(pending_attack.get("target_kind", "card")) == "master":
			context["defending_master"] = true
		_fill_target_context(engine, state, player_id, attacker_id, context)
		_fill_trade_context(engine, state, defender_id, attacker_id, context)
		var attacker_power := int(context.get("target_power", 0))
		if attacker_power >= 5000:
			context["intercept_high_power_attack"] = true
		context["defense_with_blocker"] = not str(payload.get("blocker_id", "")).is_empty()
		if bool(context.get("defense_with_blocker", false)):
			context["defense_with_blocker_preserves_hand"] = true
		context["defense_with_supporter"] = not str(payload.get("supporter_id", "")).is_empty()
		if bool(context.get("defense_with_supporter", false)):
			context["defense_with_supporter_preserves_hand"] = self_player.hand.cards.size() <= 2
			context["defense_support_preserves_counterattack_window"] = _board_unit_count(self_player) >= 2
			if _support_defense_protects_master(state, defender_id):
				context["defense_support_protects_master"] = true
			else:
				context["defense_support_protects_board"] = true
		var guard_card_ids := _payload_string_array(payload.get("master_guard_card_ids", []))
		context["defense_with_master_guard"] = not guard_card_ids.is_empty()
		context["defense_single_card_master_guard"] = guard_card_ids.size() == 1
		context["defense_multi_card_master_guard"] = guard_card_ids.size() >= 2
		if bool(context.get("defense_with_master_guard", false)):
			var self_hand_size: int = self_player.hand.cards.size()
			var remaining_after_guard: int = self_hand_size - guard_card_ids.size()
			context["defense_master_guard_forces_topdeck"] = remaining_after_guard <= 0
			context["defense_master_guard_consumes_half_hand"] = self_hand_size > 0 and float(guard_card_ids.size()) / float(self_hand_size) >= 0.5
			context["defense_master_guard_leaves_low_hand"] = remaining_after_guard <= 1
			context["defense_master_guard_keeps_counterattack_window"] = remaining_after_guard >= 2 and _board_unit_count(self_player) >= 1
			context["defense_master_guard_only_buys_time"] = remaining_after_guard <= 1 and _board_unit_count(self_player) == 0
		return context
	if kind == "activate_effect":
		_fill_target_context(engine, state, player_id, _resolve_target_card_id(candidate), context)
	return context

func _resolve_target_card_id(candidate: Dictionary) -> String:
	var payload: Dictionary = candidate.get("payload", {})
	for key in ["target_card_id", "defender_id"]:
		var value := str(payload.get(key, ""))
		if not value.is_empty():
			return value
	var target: Dictionary = candidate.get("target", {})
	for key in ["target_card_id", "defender_id"]:
		var value := str(target.get(key, ""))
		if not value.is_empty():
			return value
	return ""

func _fill_target_context(engine, state, player_id: int, target_card_id: String, context: Dictionary) -> void:
	if target_card_id.is_empty():
		return
	var instance = state.card_instances.get(target_card_id)
	if instance == null:
		return
	context["has_target_card"] = true
	var target_controller: int = int(instance.controller)
	context["target_enemy_unit"] = target_controller != player_id
	context["target_own_unit"] = target_controller == player_id
	var row := str(instance.position.get("row", ""))
	context["target_frontline"] = row == "front"
	context["target_backline"] = row == "back"
	context["target_own_frontline"] = target_controller == player_id and row == "front"
	context["target_own_backline"] = target_controller == player_id and row == "back"
	if row == "front":
		context["target_last_frontline"] = target_controller != player_id and _front_row_unit_count(state.get_player(target_controller)) == 1
	var power: int = engine.get_card_power(state, target_card_id)
	context["target_power"] = power
	context["target_power_ge_4000"] = power >= 4000
	context["target_power_ge_6000"] = power >= 6000
	context["target_power_le_2000"] = power > 0 and power <= 2000
	context["cleanup_low_power_enemy"] = power > 0 and power <= 2000
	var definition = state.get_definition(str(instance.definition_id))
	if definition != null:
		context["target_definition"] = {
			"id": str(definition.id),
			"name": str(definition.name),
			"faction": str(definition.faction),
			"type": str(definition.type)
		}

func _fill_trade_context(engine, state, source_card_id: String, target_card_id: String, context: Dictionary) -> void:
	if source_card_id.is_empty() or target_card_id.is_empty():
		return
	var source_power: int = engine.get_card_power(state, source_card_id)
	var target_power: int = engine.get_card_power(state, target_card_id)
	if source_power <= 0 or target_power <= 0:
		return
	if source_power >= target_power + 1000:
		context["favorable_trade"] = true
	if source_power + 1000 < target_power:
		context["risky_trade"] = true

func _count_set_counter_tactics(state, player_id: int) -> int:
	if player_id < 0 or player_id >= state.players.size():
		return 0
	var count := 0
	for card_id in state.get_player(player_id).artifact_zone.cards:
		var instance = state.card_instances.get(str(card_id))
		if instance == null:
			continue
		var definition = state.get_definition(str(instance.definition_id))
		if definition != null and definition.is_counter_tactic():
			count += 1
	return count

func _payload_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _minimum_guard_count(guard_sets: Array) -> int:
	var minimum := -1
	for guard_set in guard_sets:
		var cards := _payload_string_array(guard_set)
		if cards.is_empty():
			continue
		if minimum == -1 or cards.size() < minimum:
			minimum = cards.size()
	return minimum

func _can_create_next_turn_master_threat(engine, state, attacker_id: String, target_card_id: String, context: Dictionary) -> bool:
	if not bool(context.get("target_last_frontline", false)):
		return false
	if not bool(context.get("target_open_no_support", false)):
		return false
	var attacker = state.card_instances.get(attacker_id)
	if attacker == null or str(attacker.position.get("row", "")) != "front":
		return false
	var attacker_power: int = engine.get_card_power(state, attacker_id)
	var target_power: int = engine.get_card_power(state, target_card_id)
	return attacker_power > target_power

func _can_create_next_turn_master_lethal_pressure(engine, state, attacker_id: String, target_card_id: String, context: Dictionary) -> bool:
	if not _can_create_next_turn_master_threat(engine, state, attacker_id, target_card_id, context):
		return false
	var target = state.card_instances.get(target_card_id)
	if target == null:
		return false
	var projected_damage := _project_next_turn_master_damage_after_clear(engine, state, attacker_id, target_card_id)
	return projected_damage >= state.get_player(int(target.controller)).master_hp

func _project_next_turn_master_damage_after_clear(engine, state, attacker_id: String, target_card_id: String) -> int:
	var attacker = state.card_instances.get(attacker_id)
	var target = state.card_instances.get(target_card_id)
	if attacker == null or target == null:
		return 0
	if str(attacker.position.get("row", "")) != "front":
		return 0
	var attacker_power: int = engine.get_card_power(state, attacker_id)
	var target_power: int = engine.get_card_power(state, target_card_id)
	if attacker_power <= target_power:
		return 0
	var projected := 0
	var player = state.get_player(int(attacker.controller))
	for slot in player.battle_front:
		if slot.occupant.is_empty():
			continue
		if str(slot.occupant) == target_card_id:
			continue
		projected += 1
	return projected

func _support_defense_protects_master(state, defender_id: String) -> bool:
	if defender_id.is_empty():
		return false
	var defender = state.card_instances.get(defender_id)
	if defender == null or str(defender.position.get("row", "")) != "front":
		return false
	return _front_row_unit_count(state.get_player(int(defender.controller))) == 1

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

func _add_trace(trace: Array[Dictionary], bucket_totals: Dictionary, bucket: String, key: String, value: float) -> void:
	if is_zero_approx(value):
		return
	trace.append({
		"bucket": bucket,
		"key": key,
		"value": value
	})
	bucket_totals[bucket] = float(bucket_totals.get(bucket, 0.0)) + value

func _top_trace_items(trace: Array[Dictionary], positive: bool, limit: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for row in trace:
		var value := float(row.get("value", 0.0))
		if positive and value > 0.0:
			filtered.append(row)
		elif not positive and value < 0.0:
			filtered.append(row)
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_value := float(a.get("value", 0.0))
		var b_value := float(b.get("value", 0.0))
		if positive:
			return a_value > b_value
		return a_value < b_value
	)
	var top: Array[Dictionary] = []
	for i in range(min(limit, filtered.size())):
		top.append(filtered[i].duplicate(true))
	return top

func _format_feature_summary(top_positive: Array[Dictionary], top_negative: Array[Dictionary]) -> String:
	var positive_parts: Array[String] = []
	for row in top_positive:
		positive_parts.append("%s=%.2f" % [str(row.get("key", "")), float(row.get("value", 0.0))])
	var negative_parts: Array[String] = []
	for row in top_negative:
		negative_parts.append("%s=%.2f" % [str(row.get("key", "")), float(row.get("value", 0.0))])
	var parts: Array[String] = []
	if not positive_parts.is_empty():
		parts.append("+[%s]" % ",".join(positive_parts))
	if not negative_parts.is_empty():
		parts.append("-[%s]" % ",".join(negative_parts))
	return " ".join(parts)






