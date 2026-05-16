extends RefCounted
class_name CandidateSimulator

const ActionCandidateBuilder = preload("res://ai/core/action_candidate_builder.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")

func simulate_candidate(_engine, state, player_id: int, candidate: Dictionary) -> Dictionary:
	if state == null or player_id < 0 or player_id >= state.players.size():
		return {"ok": false, "score": 0.0, "summary": "invalid_state"}
	var before := _collect_metrics(state, player_id)
	var clone_result := _clone_state(state)
	if not bool(clone_result.get("ok", false)):
		return {"ok": false, "score": 0.0, "summary": str(clone_result.get("summary", "clone_failed"))}
	var sim_engine: GameEngine = clone_result.get("engine")
	var sim_state = clone_result.get("state")
	var command := GameCommand.create(player_id, str(candidate.get("command_type", "")), candidate.get("payload", {}))
	var applied: Dictionary = sim_engine.apply_command(sim_state, command)
	if not bool(applied.get("ok", false)):
		var failure_code := str(applied.get("code", applied.get("error_code", "UNKNOWN")))
		return {
			"ok": false,
			"score": -6.0,
			"summary": "apply_failed:%s" % failure_code,
			"breakdown": {
				"failure_code": failure_code
			}
		}
	var after := _collect_metrics(sim_state, player_id)
	var score := 0.0
	var reasons: Array[String] = []
	var enemy_master_damage: int = before.enemy_master_hp - after.enemy_master_hp
	if enemy_master_damage > 0:
		score += 0.24 * float(enemy_master_damage)
		reasons.append("enemy_master_hp-%s" % enemy_master_damage)
	var enemy_front_cleared: int = before.enemy_front - after.enemy_front
	if enemy_front_cleared > 0:
		score += 0.22 * float(enemy_front_cleared)
		reasons.append("enemy_front-%s" % enemy_front_cleared)
	var enemy_board_cleared: int = before.enemy_board - after.enemy_board
	if enemy_board_cleared > 0:
		score += 0.14 * float(enemy_board_cleared)
		reasons.append("enemy_board-%s" % enemy_board_cleared)
	var enemy_hand_delta: int = after.enemy_hand - before.enemy_hand
	if enemy_hand_delta < 0:
		score += 0.10 * float(-enemy_hand_delta)
		reasons.append("enemy_hand-%s" % (-enemy_hand_delta))
	var self_master_loss: int = before.self_master_hp - after.self_master_hp
	if self_master_loss > 0:
		score -= 0.35 * float(self_master_loss)
		reasons.append("self_master_hp-%s" % self_master_loss)
	var self_front_gain: int = after.self_front - before.self_front
	if self_front_gain > 0:
		score += 0.16 * float(self_front_gain)
		reasons.append("self_front+%s" % self_front_gain)
	var self_board_gain: int = after.self_board - before.self_board
	if self_board_gain > 0:
		score += 0.12 * float(self_board_gain)
		reasons.append("self_board+%s" % self_board_gain)
	var self_front_loss: int = before.self_front - after.self_front
	if self_front_loss > 0:
		score -= 0.18 * float(self_front_loss)
		reasons.append("self_front-%s" % self_front_loss)
	var self_board_loss: int = before.self_board - after.self_board
	if self_board_loss > 0:
		score -= 0.12 * float(self_board_loss)
		reasons.append("self_board-%s" % self_board_loss)
	var candidate_kind := str(candidate.get("kind", ""))
	var self_hand_delta: int = after.self_hand - before.self_hand
	if self_hand_delta > 0:
		score += 0.08 * float(self_hand_delta)
		reasons.append("self_hand+%s" % self_hand_delta)
	if self_hand_delta < 0 and enemy_master_damage == 0 and enemy_board_cleared == 0 and self_board_gain == 0:
		score -= 0.07 * float(-self_hand_delta)
		reasons.append("self_hand-%s_without_immediate_gain" % (-self_hand_delta))
	var self_active_morale_loss: int = before.self_active_morale - after.self_active_morale
	if self_active_morale_loss > 0:
		score -= 0.05 * float(self_active_morale_loss)
		reasons.append("self_active_morale-%s" % self_active_morale_loss)
		if enemy_master_damage == 0 and enemy_board_cleared == 0 and self_board_gain == 0:
			score -= 0.10 * float(self_active_morale_loss)
			reasons.append("self_active_morale-%s_without_immediate_gain" % self_active_morale_loss)
	if self_board_loss > 0 and enemy_board_cleared == 0 and enemy_master_damage == 0 and self_board_gain == 0:
		score -= 0.28 * float(self_board_loss)
		reasons.append("self_board-%s_without_immediate_gain" % self_board_loss)
	if self_master_loss > 0 and enemy_master_damage == 0 and enemy_board_cleared == 0 and self_board_gain == 0:
		score -= 0.32 * float(self_master_loss)
		reasons.append("self_master_hp-%s_without_immediate_gain" % self_master_loss)
	if candidate_kind == "declare_attack" and self_board_loss > 0 and enemy_board_cleared == 0 and enemy_master_damage == 0 and self_board_gain == 0:
		score -= 0.40 * float(self_board_loss)
		reasons.append("suicidal_attack_no_followup")
	if after.enemy_front == 0 and after.self_front > 0:
		score += 0.16
		reasons.append("open_master_lane_after_sim")
	var keeps_own_action_window: bool = after.waiting_player == player_id and after.waiting_state == "WaitingForAction" and after.stack_size == 0 and not after.pending_attack
	if keeps_own_action_window:
		score += 0.06
		reasons.append("keeps_own_action_window")
	var gives_enemy_priority_window: bool = after.waiting_player != player_id and (after.stack_size > 0 or after.pending_attack)
	if gives_enemy_priority_window:
		score -= 0.10
		reasons.append("gives_enemy_priority_window")
	var attack_followup_pressure := {
		"found": false,
		"score": 0.0,
		"summary": "",
		"projected_master_damage": 0,
		"reasons": []
	}
	if candidate_kind == "declare_attack":
		attack_followup_pressure = _evaluate_attack_followup_pressure(_engine, state, player_id, candidate)
		if bool(attack_followup_pressure.get("found", false)):
			var attack_followup_score: float = float(attack_followup_pressure.get("score", 0.0))
			score += attack_followup_score
			for reason in attack_followup_pressure.get("reasons", []):
				reasons.append(str(reason))
	var coordinated_clear := {
		"found": false,
		"score": 0.0,
		"summary": "",
		"remaining_power": 0,
		"reasons": []
	}
	if candidate_kind == "declare_attack":
		coordinated_clear = _evaluate_coordinated_attack_clear_plan(_engine, state, player_id, candidate)
		if bool(coordinated_clear.get("found", false)):
			var coordinated_score: float = float(coordinated_clear.get("score", 0.0))
			score += coordinated_score
			for reason in coordinated_clear.get("reasons", []):
				reasons.append(str(reason))
	var followup_attack := {
		"found": false,
		"score": 0.0,
		"summary": "",
		"target_kind": "",
		"payload": {},
		"reasons": []
	}
	if candidate_kind == "move_legion" and keeps_own_action_window:
		followup_attack = _evaluate_move_followup_attack(sim_engine, sim_state, player_id, str(candidate.get("payload", {}).get("card_id", "")))
		if bool(followup_attack.get("found", false)):
			var followup_score: float = float(followup_attack.get("score", 0.0))
			score += followup_score
			for reason in followup_attack.get("reasons", []):
				reasons.append(str(reason))
	if reasons.is_empty():
		reasons.append("neutral_followup")
	var breakdown := {
		"enemy_master_damage": enemy_master_damage,
		"enemy_front_cleared": enemy_front_cleared,
		"enemy_board_cleared": enemy_board_cleared,
		"enemy_hand_delta": enemy_hand_delta,
		"self_master_loss": self_master_loss,
		"self_front_gain": self_front_gain,
		"self_board_gain": self_board_gain,
		"self_front_loss": self_front_loss,
		"self_board_loss": self_board_loss,
		"self_hand_delta": self_hand_delta,
		"self_active_morale_loss": self_active_morale_loss,
		"open_master_lane_after_sim": after.enemy_front == 0 and after.self_front > 0,
		"keeps_own_action_window": keeps_own_action_window,
		"gives_enemy_priority_window": gives_enemy_priority_window,
		"attack_followup_pressure_found": bool(attack_followup_pressure.get("found", false)),
		"attack_followup_pressure_score": float(attack_followup_pressure.get("score", 0.0)),
		"attack_followup_pressure_summary": str(attack_followup_pressure.get("summary", "")),
		"attack_followup_projected_master_damage": int(attack_followup_pressure.get("projected_master_damage", 0)),
		"coordinated_clear_found": bool(coordinated_clear.get("found", false)),
		"coordinated_clear_score": float(coordinated_clear.get("score", 0.0)),
		"coordinated_clear_summary": str(coordinated_clear.get("summary", "")),
		"coordinated_clear_remaining_power": int(coordinated_clear.get("remaining_power", 0)),
		"followup_attack_found": bool(followup_attack.get("found", false)),
		"followup_attack_score": float(followup_attack.get("score", 0.0)),
		"followup_attack_summary": str(followup_attack.get("summary", "")),
		"followup_attack_target_kind": str(followup_attack.get("target_kind", "")),
		"followup_attack_payload": followup_attack.get("payload", {}).duplicate(true),
		"waiting_state_after": str(after.waiting_state),
		"waiting_player_after": int(after.waiting_player),
		"stack_size_after": int(after.stack_size),
		"pending_attack_after": bool(after.pending_attack)
	}
	return {
		"ok": true,
		"score": score,
		"summary": ",".join(reasons),
		"breakdown": breakdown,
		"before": before,
		"after": after
	}

func preview_state_after_candidate(_engine, state, player_id: int, candidate: Dictionary) -> Dictionary:
	if state == null or player_id < 0 or player_id >= state.players.size():
		return {"ok": false, "summary": "invalid_state"}
	var clone_result := _clone_state(state)
	if not bool(clone_result.get("ok", false)):
		return {"ok": false, "summary": str(clone_result.get("summary", "clone_failed"))}
	var sim_engine: GameEngine = clone_result.get("engine")
	var sim_state = clone_result.get("state")
	var command := GameCommand.create(player_id, str(candidate.get("command_type", "")), candidate.get("payload", {}))
	var applied: Dictionary = sim_engine.apply_command(sim_state, command)
	if not bool(applied.get("ok", false)):
		return {
			"ok": false,
			"summary": "apply_failed:%s" % str(applied.get("code", applied.get("error_code", "UNKNOWN")))
		}
	return {
		"ok": true,
		"engine": sim_engine,
		"state": sim_state,
		"after": _collect_metrics(sim_state, player_id)
	}

func _evaluate_move_followup_attack(engine, state, player_id: int, moved_card_id: String) -> Dictionary:
	var result := {
		"found": false,
		"score": 0.0,
		"summary": "",
		"target_kind": "",
		"payload": {},
		"reasons": []
	}
	if engine == null or state == null or moved_card_id.is_empty() or player_id < 0 or player_id >= state.players.size():
		return result
	if not engine.has_method("get_legal_actions") or not engine.has_method("get_card_power"):
		return result
	var legal_actions: Array = engine.get_legal_actions(state, player_id)
	if legal_actions.is_empty():
		return result
	var candidates: Array[Dictionary] = ActionCandidateBuilder.expand(legal_actions)
	if candidates.is_empty():
		return result
	var best_score := -INF
	var best_summary := ""
	var best_target_kind := ""
	var best_payload: Dictionary = {}
	var best_reasons: Array[String] = []
	var attacker_power: int = int(engine.get_card_power(state, moved_card_id))
	for attack_candidate in candidates:
		if str(attack_candidate.get("kind", "")) != "declare_attack":
			continue
		var payload: Dictionary = attack_candidate.get("payload", {})
		if str(payload.get("attacker_id", "")) != moved_card_id:
			continue
		var target_kind := str(payload.get("target_kind", "card"))
		var candidate_score := 0.12
		var candidate_reasons: Array[String] = ["move_followup_attack_available"]
		if target_kind == "master":
			candidate_score += 0.80
			candidate_reasons.append("move_followup_attack_master")
			var enemy_player = state.get_player(1 - player_id)
			if int(enemy_player.master_hp) <= 3:
				candidate_score += 0.12
				candidate_reasons.append("move_followup_attack_close_lethal")
		else:
			var defender_id := str(payload.get("defender_id", payload.get("target_card_id", "")))
			if defender_id.is_empty():
				continue
			var defender_power: int = int(engine.get_card_power(state, defender_id))
			if attacker_power > 0 and defender_power > 0:
				if attacker_power >= defender_power:
					candidate_score += 0.14
					candidate_reasons.append("move_followup_favorable_trade")
				else:
					candidate_score -= 0.10
					candidate_reasons.append("move_followup_risky_trade")
			var defender = state.card_instances.get(defender_id)
			if defender != null and str(defender.position.get("row", "")) == "front":
				if _front_row_unit_count(state.get_player(1 - player_id)) == 1 and attacker_power >= defender_power and defender_power > 0:
					candidate_score += 0.16
					candidate_reasons.append("move_followup_breaks_last_frontline")
			var followup_pressure := _evaluate_attack_followup_pressure(engine, state, player_id, attack_candidate)
			if bool(followup_pressure.get("found", false)):
				candidate_score += float(followup_pressure.get("score", 0.0))
				for reason in followup_pressure.get("reasons", []):
					candidate_reasons.append(str(reason))
		if candidate_score > best_score:
			best_score = candidate_score
			best_target_kind = target_kind
			best_payload = payload.duplicate(true)
			best_reasons = candidate_reasons.duplicate()
			best_summary = ",".join(candidate_reasons)
	if best_score == -INF:
		return result
	result["found"] = true
	result["score"] = best_score
	result["summary"] = best_summary
	result["target_kind"] = best_target_kind
	result["payload"] = best_payload
	result["reasons"] = best_reasons
	return result

func _evaluate_attack_followup_pressure(engine, state, player_id: int, candidate: Dictionary) -> Dictionary:
	var result := {
		"found": false,
		"score": 0.0,
		"summary": "",
		"projected_master_damage": 0,
		"reasons": []
	}
	if engine == null or state == null or player_id < 0 or player_id >= state.players.size():
		return result
	if not engine.has_method("get_card_power"):
		return result
	var payload: Dictionary = candidate.get("payload", {})
	if str(payload.get("target_kind", "card")) == "master":
		return result
	var attacker_id := str(payload.get("attacker_id", ""))
	var defender_id := str(payload.get("defender_id", payload.get("target_card_id", "")))
	if attacker_id.is_empty() or defender_id.is_empty():
		return result
	var attacker = state.card_instances.get(attacker_id)
	var defender = state.card_instances.get(defender_id)
	if attacker == null or defender == null:
		return result
	if int(defender.controller) == player_id:
		return result
	if str(attacker.position.get("row", "")) != "front" or str(defender.position.get("row", "")) != "front":
		return result
	if _front_row_unit_count(state.get_player(1 - player_id)) != 1:
		return result
	var attacker_power: int = int(engine.get_card_power(state, attacker_id))
	var defender_power: int = int(engine.get_card_power(state, defender_id))
	if attacker_power <= defender_power or defender_power <= 0:
		return result
	var projected_master_damage := _project_master_damage_after_clear(state, player_id)
	if projected_master_damage <= 0:
		return result
	var score := 0.12
	var reasons: Array[String] = ["attack_breaks_last_frontline"]
	if projected_master_damage >= 1:
		score += 0.10
		reasons.append("attack_followup_master_pressure")
	if projected_master_damage >= 2:
		score += 0.08
		reasons.append("attack_followup_multi_lane_pressure")
	var enemy_player = state.get_player(1 - player_id)
	if projected_master_damage >= int(enemy_player.master_hp):
		score += 0.16
		reasons.append("attack_followup_master_lethal_pressure")
	result["found"] = true
	result["score"] = score
	result["summary"] = ",".join(reasons)
	result["projected_master_damage"] = projected_master_damage
	result["reasons"] = reasons
	return result

func _evaluate_coordinated_attack_clear_plan(engine, state, player_id: int, candidate: Dictionary) -> Dictionary:
	var result := {
		"found": false,
		"score": 0.0,
		"summary": "",
		"remaining_power": 0,
		"reasons": []
	}
	if engine == null or state == null or player_id < 0 or player_id >= state.players.size():
		return result
	if not engine.has_method("get_legal_actions") or not engine.has_method("get_card_power"):
		return result
	var payload: Dictionary = candidate.get("payload", {})
	if str(payload.get("target_kind", "card")) != "card":
		return result
	var attacker_id := str(payload.get("attacker_id", ""))
	var defender_id := str(payload.get("defender_id", payload.get("target_card_id", "")))
	if attacker_id.is_empty() or defender_id.is_empty():
		return result
	var attacker_power: int = int(engine.get_card_power(state, attacker_id))
	var defender_power: int = int(engine.get_card_power(state, defender_id))
	if attacker_power <= 0 or defender_power <= 0 or attacker_power >= defender_power:
		return result
	var defender_instance = state.card_instances.get(defender_id)
	if defender_instance == null or int(defender_instance.controller) == player_id:
		return result
	var defender_definition = state.get_definition(str(defender_instance.definition_id))
	var defender_keywords: Array = defender_definition.keywords if defender_definition != null else []
	var high_threat: bool = defender_power >= 4000 or (defender_keywords is Array and (defender_keywords.has("taunt") or defender_keywords.has("ranged") or defender_keywords.has("ranged_attack")))
	if not high_threat:
		return result
	var total_power: int = attacker_power
	var supporting_attackers: int = 0
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
		supporting_attackers += 1
		if total_power >= defender_power:
			break
	if supporting_attackers <= 0 or total_power < defender_power:
		return result
	var score := 0.18
	var reasons: Array[String] = ["attack_sets_up_coordinated_clear"]
	if defender_power >= 4000:
		score += 0.08
		reasons.append("attack_sets_up_high_threat_clear")
	if supporting_attackers >= 2:
		score += 0.04
		reasons.append("attack_sets_up_multi_attacker_clear")
	result["found"] = true
	result["score"] = score
	result["summary"] = ",".join(reasons)
	result["remaining_power"] = max(0, defender_power - total_power)
	result["reasons"] = reasons
	return result

func _project_master_damage_after_clear(state, player_id: int) -> int:
	if state == null or player_id < 0 or player_id >= state.players.size():
		return 0
	var projected := 0
	for slot in state.get_player(player_id).battle_front:
		if not slot.occupant.is_empty():
			projected += 1
	return projected

func _clone_state(state) -> Dictionary:
	var sim_engine := GameEngine.new()
	var definitions: Array = []
	for definition in state.card_definitions.values():
		definitions.append(definition)
	var sim_rules_config: Dictionary = state.rules_config.duplicate(true)
	sim_rules_config.erase("debug_trace_path")
	var player_metadata: Array[Dictionary] = []
	for player in state.players:
		player_metadata.append({
			"name": str(player.name),
			"master_id": str(player.master_definition_id),
			"master_name": str(player.master_name),
			"master_hp": int(player.master_hp),
			"master_max_hp": int(player.master_max_hp)
		})
	var sim_state = sim_engine.create_game(
		definitions,
		state.initial_decks.duplicate(true),
		int(state.seed),
		player_metadata,
		sim_rules_config
	)
	for row in state.command_log:
		var command := GameCommand.create(int(row.get("player_id", -1)), str(row.get("type", "")), row.get("payload", {}))
		command.command_id = str(row.get("command_id", command.command_id))
		command.client_time = int(row.get("client_time", command.client_time))
		command.source = str(row.get("source", command.source))
		var result: Dictionary = sim_engine.apply_command(sim_state, command)
		if not bool(result.get("ok", false)):
			return {
				"ok": false,
				"summary": "replay_failed:%s" % str(result.get("code", result.get("error_code", "UNKNOWN")))
			}
	return {
		"ok": true,
		"engine": sim_engine,
		"state": sim_state
	}

func _collect_metrics(state, player_id: int) -> Dictionary:
	var self_player = state.get_player(player_id)
	var enemy_player = state.get_player(1 - player_id)
	var waiting: Dictionary = {
		"state": "",
		"player_id": -1
	}
	if state.pending_choices.is_empty():
		if not state.stack.is_empty() or not state.pending_attack.is_empty():
			waiting = {
				"state": "WaitingForPriority",
				"player_id": int(state.priority_player)
			}
		else:
			waiting = {
				"state": "WaitingForAction",
				"player_id": int(state.active_player)
			}
	return {
		"self_master_hp": int(self_player.master_hp),
		"enemy_master_hp": int(enemy_player.master_hp),
		"self_hand": self_player.hand.cards.size(),
		"enemy_hand": enemy_player.hand.cards.size(),
		"self_active_morale": MoraleActions.count_active_morale(state, player_id),
		"enemy_active_morale": MoraleActions.count_active_morale(state, 1 - player_id),
		"self_front": _front_row_unit_count(self_player),
		"enemy_front": _front_row_unit_count(enemy_player),
		"self_board": _board_unit_count(self_player),
		"enemy_board": _board_unit_count(enemy_player),
		"stack_size": state.stack.size(),
		"pending_attack": not state.pending_attack.is_empty(),
		"waiting_state": str(waiting.get("state", "")),
		"waiting_player": int(waiting.get("player_id", -1))
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

func _front_row_unit_count(player) -> int:
	var count := 0
	for slot in player.battle_front:
		if not slot.occupant.is_empty():
			count += 1
	return count
