extends RefCounted
class_name TestProfileFeatureExtractor

const CardDatabase = preload("res://rules/core/card_database.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const ProfileFeatureExtractor = preload("res://ai/scripted/profile_feature_extractor.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_lane_support_and_last_frontline(failures)
	_test_next_turn_master_threat(failures)
	_test_next_turn_master_lane_pressure(failures)
	_test_next_turn_master_lethal_pressure(failures)
	_test_pressure_guard_window_features(failures)
	_test_multi_guard_tax_window_features(failures)
	_test_multi_guard_hand_tax_features(failures)
	_test_post_guard_vacuum_features(failures)
	_test_master_guard_risk_tiering(failures)
	_test_support_defense_intent(failures)
	_test_hand_response_retention_features(failures)
	_test_defense_retention_features(failures)
	_test_artifact_activation_retention_features(failures)
	_test_pass_priority_pressure_features(failures)
	return failures

static func _test_lane_support_and_last_frontline(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 333)
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"source_frontline": 1.0,
			"source_has_supporter": 1.0,
			"target_frontline": 1.0,
			"target_open_no_support": 1.0,
			"target_last_frontline": 1.0
		}
	}

	var p0_front = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_front,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: player 0 front play should succeed", failures)

	_advance_to_next_main(engine, state, failures, "feature extractor: advance to player 1 main should succeed")
	var p1_front = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": p1_front,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: player 1 front play should succeed", failures)

	_advance_to_next_main(engine, state, failures, "feature extractor: advance back to player 0 main should succeed")
	var p0_back = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_back,
		"row": "back",
		"col": 0
	})).ok, "feature extractor: player 0 back play should succeed", failures)

	var attacker_id: String = state.players[0].battle_front[0].occupant
	var defender_id: String = state.players[1].battle_front[0].occupant
	var evaluation := extractor.evaluate(profile, engine, state, 0, {
		"kind": "declare_attack",
		"payload": {
			"attacker_id": attacker_id,
			"defender_id": defender_id
		}
	}, {})
	var trace = evaluation.get("trace", [])
	_expect(_trace_has_key(trace, "source_frontline"), "feature extractor: attacker should expose source_frontline", failures)
	_expect(_trace_has_key(trace, "source_has_supporter"), "feature extractor: attacker should expose source_has_supporter", failures)
	_expect(_trace_has_key(trace, "target_frontline"), "feature extractor: defender should expose target_frontline", failures)
	_expect(_trace_has_key(trace, "target_open_no_support"), "feature extractor: defender should expose target_open_no_support", failures)
	_expect(_trace_has_key(trace, "target_last_frontline"), "feature extractor: defender should expose target_last_frontline", failures)

static func _test_master_guard_risk_tiering(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 334)
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"open_master_lane": 1.0,
			"master_guard_risk": 1.0,
			"master_guard_single_card_risk": 1.0,
			"master_guard_multi_card_only": 1.0
		}
	}

	var attacker_card_id = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: master attack source play should succeed", failures)

	var attacker_id: String = state.players[0].battle_front[0].occupant
	var evaluation := extractor.evaluate(profile, engine, state, 0, {
		"kind": "declare_attack",
		"payload": {
			"attacker_id": attacker_id,
			"target_kind": "master",
			"target_player": 1
		}
	}, {})
	var trace = evaluation.get("trace", [])
	_expect(_trace_has_key(trace, "open_master_lane"), "feature extractor: direct master line should expose open_master_lane", failures)
	_expect(_trace_has_key(trace, "master_guard_risk"), "feature extractor: direct master line should expose master_guard_risk", failures)
	_expect(_trace_has_key(trace, "master_guard_single_card_risk"), "feature extractor: direct master line should expose master_guard_single_card_risk", failures)
	_expect(not _trace_has_key(trace, "master_guard_multi_card_only"), "feature extractor: single-card guard should not expose multi-card-only risk", failures)

static func _test_next_turn_master_threat(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 335)
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"next_turn_master_threat": 1.0
		}
	}

	var p0_front = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_front,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: next-turn threat attacker play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "feature extractor: advance to player 1 main for next-turn threat should succeed")
	var p1_front = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": p1_front,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: next-turn threat defender play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "feature extractor: advance back to player 0 main for next-turn threat should succeed")

	var attacker_id: String = state.players[0].battle_front[0].occupant
	var defender_id: String = state.players[1].battle_front[0].occupant
	state.card_instances[defender_id].damage_marked = 1000

	var evaluation := extractor.evaluate(profile, engine, state, 0, {
		"kind": "declare_attack",
		"payload": {
			"attacker_id": attacker_id,
			"defender_id": defender_id
		}
	}, {})
	var trace = evaluation.get("trace", [])
	_expect(_trace_has_key(trace, "next_turn_master_threat"), "feature extractor: clearing the last front line with survivor should expose next_turn_master_threat", failures)

static func _test_hand_response_retention_features(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 351)
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"plays_hand_response": 1.0,
			"plays_hand_response_leaves_low_hand": 1.0,
			"plays_hand_response_forces_topdeck": 1.0,
			"plays_counter_tactic": 1.0,
			"plays_counter_tactic_leaves_low_hand": 1.0,
			"plays_counter_tactic_forces_topdeck": 1.0
		}
	}
	state.players[0].hand.cards = state.players[0].hand.cards.slice(0, 2)
	var response_card_id := str(state.players[0].hand.cards[0])
	var response_eval := extractor.evaluate(profile, engine, state, 0, {
		"kind": "play_card",
		"action": {"kind": "play_card", "play_kind": "hand_response"},
		"payload": {"card_id": response_card_id, "row": "hand_response", "col": -1, "effect_id": "hand_response_dummy"}
	}, {})
	var response_trace = response_eval.get("trace", [])
	_expect(_trace_has_key(response_trace, "plays_hand_response"), "feature extractor: hand response play should expose plays_hand_response", failures)
	_expect(_trace_has_key(response_trace, "plays_hand_response_leaves_low_hand"), "feature extractor: hand response play at 2 cards should expose low-hand retention risk", failures)
	_expect(not _trace_has_key(response_trace, "plays_hand_response_forces_topdeck"), "feature extractor: hand response play at 2 cards should not force topdeck", failures)

	state.players[0].hand.cards = state.players[0].hand.cards.slice(0, 1)
	var response_last_card_id := str(state.players[0].hand.cards[0])
	var response_topdeck_eval := extractor.evaluate(profile, engine, state, 0, {
		"kind": "play_card",
		"action": {"kind": "play_card", "play_kind": "hand_response"},
		"payload": {"card_id": response_last_card_id, "row": "hand_response", "col": -1, "effect_id": "hand_response_dummy"}
	}, {})
	var response_topdeck_trace = response_topdeck_eval.get("trace", [])
	_expect(_trace_has_key(response_topdeck_trace, "plays_hand_response_forces_topdeck"), "feature extractor: hand response play at 1 card should expose topdeck risk", failures)

	var counter_state = engine.create_game(_definitions(), _decks(), 352)
	counter_state.players[0].hand.cards = counter_state.players[0].hand.cards.slice(0, 2)
	var counter_card_id := str(counter_state.players[0].hand.cards[0])
	var counter_eval := extractor.evaluate(profile, engine, counter_state, 0, {
		"kind": "play_card",
		"action": {"kind": "play_card", "play_kind": "counter_tactic"},
		"payload": {"card_id": counter_card_id, "row": "counter_tactic", "col": -1, "effect_id": "counter_dummy"}
	}, {})
	var counter_trace = counter_eval.get("trace", [])
	_expect(_trace_has_key(counter_trace, "plays_counter_tactic"), "feature extractor: counter tactic play should expose plays_counter_tactic", failures)
	_expect(_trace_has_key(counter_trace, "plays_counter_tactic_leaves_low_hand"), "feature extractor: counter tactic play at 2 cards should expose low-hand retention risk", failures)

static func _test_next_turn_master_lane_pressure(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var extractor := ProfileFeatureExtractor.new()

	var single_state = engine.create_game(_definitions(), _decks(), 339)
	var single_profile := {
		"weights": {
			"next_turn_master_single_lane_pressure": 1.0
		}
	}
	var single_eval := _build_master_pressure_evaluation(engine, single_state, extractor, single_profile, false, failures, "single-lane")
	var single_trace = single_eval.get("trace", [])
	_expect(_trace_has_key(single_trace, "next_turn_master_single_lane_pressure"), "feature extractor: one surviving front lane should expose next_turn_master_single_lane_pressure", failures)
	_expect(not _trace_has_key(single_trace, "next_turn_master_multi_lane_pressure"), "feature extractor: one surviving front lane should not expose next_turn_master_multi_lane_pressure", failures)

	var multi_state = engine.create_game(_definitions(), _decks(), 340)
	var multi_profile := {
		"weights": {
			"next_turn_master_multi_lane_pressure": 1.0
		}
	}
	var multi_eval := _build_master_pressure_evaluation(engine, multi_state, extractor, multi_profile, true, failures, "multi-lane")
	var multi_trace = multi_eval.get("trace", [])
	_expect(_trace_has_key(multi_trace, "next_turn_master_multi_lane_pressure"), "feature extractor: two surviving front lanes should expose next_turn_master_multi_lane_pressure", failures)
	_expect(not _trace_has_key(multi_trace, "next_turn_master_single_lane_pressure"), "feature extractor: two surviving front lanes should not expose next_turn_master_single_lane_pressure", failures)

static func _test_next_turn_master_lethal_pressure(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), 338)
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"next_turn_master_lethal_pressure": 1.0
		}
	}

	var p0_front_a = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_front_a,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: lethal pressure first attacker play should succeed", failures)
	var p0_front_b = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_front_b,
		"row": "front",
		"col": 1
	})).ok, "feature extractor: lethal pressure second attacker play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "feature extractor: advance to player 1 main for lethal pressure should succeed")
	var p1_front = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": p1_front,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: lethal pressure defender play should succeed", failures)
	_advance_to_next_main(engine, state, failures, "feature extractor: advance back to player 0 main for lethal pressure should succeed")

	state.players[1].master_hp = 2
	var attacker_id: String = state.players[0].battle_front[0].occupant
	var defender_id: String = state.players[1].battle_front[0].occupant
	state.card_instances[defender_id].damage_marked = 1000

	var evaluation := extractor.evaluate(profile, engine, state, 0, {
		"kind": "declare_attack",
		"payload": {
			"attacker_id": attacker_id,
			"defender_id": defender_id
		}
	}, {})
	var trace = evaluation.get("trace", [])
	_expect(_trace_has_key(trace, "next_turn_master_lethal_pressure"), "feature extractor: clearing the last front line with two attackers into 2 hp should expose next_turn_master_lethal_pressure", failures)

static func _test_pressure_guard_window_features(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var extractor := ProfileFeatureExtractor.new()

	var single_state = engine.create_game(_definitions(), _decks(), 341)
	var single_profile := {
		"weights": {
			"next_turn_pressure_blunted_by_single_guard": 1.0
		}
	}
	var single_eval := _build_master_pressure_evaluation(engine, single_state, extractor, single_profile, false, failures, "guard-window-single")
	var single_trace = single_eval.get("trace", [])
	_expect(_trace_has_key(single_trace, "next_turn_pressure_blunted_by_single_guard"), "feature extractor: single-lane pressure with one-card guard should expose next_turn_pressure_blunted_by_single_guard", failures)
	_expect(not _trace_has_key(single_trace, "next_turn_multi_lane_overwhelms_single_guard"), "feature extractor: single-lane pressure should not expose next_turn_multi_lane_overwhelms_single_guard", failures)

	var multi_state = engine.create_game(_definitions(), _decks(), 342)
	var multi_profile := {
		"weights": {
			"next_turn_multi_lane_overwhelms_single_guard": 1.0
		}
	}
	var multi_eval := _build_master_pressure_evaluation(engine, multi_state, extractor, multi_profile, true, failures, "guard-window-multi")
	var multi_trace = multi_eval.get("trace", [])
	_expect(_trace_has_key(multi_trace, "next_turn_multi_lane_overwhelms_single_guard"), "feature extractor: multi-lane pressure into one-card guard should expose next_turn_multi_lane_overwhelms_single_guard", failures)
	_expect(not _trace_has_key(multi_trace, "next_turn_pressure_blunted_by_single_guard"), "feature extractor: multi-lane pressure should not expose next_turn_pressure_blunted_by_single_guard", failures)

static func _test_multi_guard_tax_window_features(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var extractor := ProfileFeatureExtractor.new()

	var tax_state = engine.create_game(_definitions(), _decks(), 343)
	var tax_profile := {
		"weights": {
			"next_turn_multi_lane_draws_multi_guard": 1.0,
			"next_turn_lethal_through_multi_guard_tax": 1.0
		}
	}
	var tax_eval := _build_master_pressure_evaluation(engine, tax_state, extractor, tax_profile, true, failures, "guard-tax", {
		"attacker_bonus_power": 1000,
		"enemy_master_hp": 2
	})
	var tax_trace = tax_eval.get("trace", [])
	_expect(_trace_has_key(tax_trace, "next_turn_multi_lane_draws_multi_guard"), "feature extractor: multi-lane pressure into multi-card guard should expose next_turn_multi_lane_draws_multi_guard", failures)
	_expect(_trace_has_key(tax_trace, "next_turn_lethal_through_multi_guard_tax"), "feature extractor: lethal pressure through multi-card guard tax should expose next_turn_lethal_through_multi_guard_tax", failures)
	_expect(not _trace_has_key(tax_trace, "next_turn_multi_lane_overwhelms_single_guard"), "feature extractor: multi-card guard tax should not expose single-guard overwhelm feature", failures)

static func _test_multi_guard_hand_tax_features(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var extractor := ProfileFeatureExtractor.new()

	var tax_state = engine.create_game(_definitions(), _decks(), 344)
	var tax_profile := {
		"weights": {
			"next_turn_multi_guard_consumes_half_hand": 1.0,
			"next_turn_multi_guard_nearly_exhausts_hand": 1.0
		}
	}
	var tax_eval := _build_master_pressure_evaluation(engine, tax_state, extractor, tax_profile, true, failures, "guard-hand-tax", {
		"attacker_bonus_power": 1000,
		"enemy_hand_size": 3
	})
	var tax_trace = tax_eval.get("trace", [])
	_expect(_trace_has_key(tax_trace, "next_turn_multi_guard_consumes_half_hand"), "feature extractor: multi-card guard should expose next_turn_multi_guard_consumes_half_hand when it eats half the hand", failures)
	_expect(_trace_has_key(tax_trace, "next_turn_multi_guard_nearly_exhausts_hand"), "feature extractor: multi-card guard should expose next_turn_multi_guard_nearly_exhausts_hand when it nearly empties the hand", failures)

static func _test_post_guard_vacuum_features(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var extractor := ProfileFeatureExtractor.new()

	var low_hand_state = engine.create_game(_definitions(), _decks(), 345)
	var low_hand_profile := {
		"weights": {
			"next_turn_multi_guard_leaves_low_hand": 1.0
		}
	}
	var low_hand_eval := _build_master_pressure_evaluation(engine, low_hand_state, extractor, low_hand_profile, true, failures, "guard-vacuum-low", {
		"attacker_bonus_power": 1000,
		"enemy_hand_size": 3
	})
	var low_hand_trace = low_hand_eval.get("trace", [])
	_expect(_trace_has_key(low_hand_trace, "next_turn_multi_guard_leaves_low_hand"), "feature extractor: multi-card guard should expose next_turn_multi_guard_leaves_low_hand when only one card remains", failures)
	_expect(not _trace_has_key(low_hand_trace, "next_turn_multi_guard_forces_topdeck"), "feature extractor: one remaining card should not expose next_turn_multi_guard_forces_topdeck", failures)

	var topdeck_state = engine.create_game(_definitions(), _decks(), 346)
	var topdeck_profile := {
		"weights": {
			"next_turn_multi_guard_forces_topdeck": 1.0
		}
	}
	var topdeck_eval := _build_master_pressure_evaluation(engine, topdeck_state, extractor, topdeck_profile, true, failures, "guard-vacuum-topdeck", {
		"attacker_bonus_power": 1000,
		"enemy_hand_size": 2
	})
	var topdeck_trace = topdeck_eval.get("trace", [])
	_expect(_trace_has_key(topdeck_trace, "next_turn_multi_guard_forces_topdeck"), "feature extractor: multi-card guard should expose next_turn_multi_guard_forces_topdeck when it empties the hand", failures)

static func _test_support_defense_intent(failures: Array[String]) -> void:
	var master_state = _create_support_defense_state(false, 336, failures)
	if not master_state.is_empty():
		master_state["state"].players[0].hand.cards = master_state["state"].players[0].hand.cards.slice(0, 1)
		var master_eval = master_state["extractor"].evaluate(master_state["profile"], master_state["engine"], master_state["state"], 0, {
			"kind": "choose_defense",
			"payload": {
				"supporter_id": str(master_state["supporter_id"])
			}
		}, {})
		var master_trace = master_eval.get("trace", [])
		_expect(_trace_has_key(master_trace, "defense_with_supporter"), "feature extractor: support defense should expose defense_with_supporter", failures)
		_expect(_trace_has_key(master_trace, "defense_with_supporter_preserves_hand"), "feature extractor: low-hand support defense should expose defense_with_supporter_preserves_hand", failures)
		_expect(_trace_has_key(master_trace, "defense_support_preserves_counterattack_window"), "feature extractor: support defense with surviving board should preserve counterattack window", failures)
		_expect(_trace_has_key(master_trace, "defense_support_protects_master"), "feature extractor: supporting the last front line should expose defense_support_protects_master", failures)
		_expect(not _trace_has_key(master_trace, "defense_support_protects_board"), "feature extractor: protecting master lane should not expose defense_support_protects_board", failures)

	var board_state = _create_support_defense_state(true, 337, failures)
	if not board_state.is_empty():
		var board_eval = board_state["extractor"].evaluate(board_state["profile"], board_state["engine"], board_state["state"], 0, {
			"kind": "choose_defense",
			"payload": {
				"supporter_id": str(board_state["supporter_id"])
			}
		}, {})
		var board_trace = board_eval.get("trace", [])
		_expect(_trace_has_key(board_trace, "defense_support_protects_board"), "feature extractor: supporting a non-last front line should expose defense_support_protects_board", failures)
		_expect(not _trace_has_key(board_trace, "defense_support_protects_master"), "feature extractor: board preservation support should not expose defense_support_protects_master", failures)

static func _test_defense_retention_features(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"defense_with_master_guard": 1.0,
			"defense_master_guard_keeps_counterattack_window": 1.0,
			"defense_master_guard_only_buys_time": 1.0,
			"defense_master_guard_consumes_half_hand": 1.0,
			"defense_master_guard_leaves_low_hand": 1.0,
			"defense_master_guard_forces_topdeck": 1.0
		}
	}
	var low_hand_state = engine.create_game(_definitions(), _decks(), 353)
	low_hand_state.players[0].hand.cards = low_hand_state.players[0].hand.cards.slice(0, 3)
	low_hand_state.pending_attack = {
		"attacker_id": "dummy_attacker",
		"target_kind": "master",
		"target_player": 0
	}
	var low_hand_eval := extractor.evaluate(profile, engine, low_hand_state, 0, {
		"kind": "choose_defense",
		"payload": {
			"master_guard_card_ids": ["g1", "g2"]
		}
	}, {})
	var low_hand_trace = low_hand_eval.get("trace", [])
	_expect(_trace_has_key(low_hand_trace, "defense_with_master_guard"), "feature extractor: master guard defense should expose defense_with_master_guard", failures)
	_expect(_trace_has_key(low_hand_trace, "defense_master_guard_consumes_half_hand"), "feature extractor: two-card guard from three-card hand should consume half the hand", failures)
	_expect(_trace_has_key(low_hand_trace, "defense_master_guard_leaves_low_hand"), "feature extractor: two-card guard from three-card hand should leave low hand", failures)
	_expect(not _trace_has_key(low_hand_trace, "defense_master_guard_forces_topdeck"), "feature extractor: two-card guard from three-card hand should not force topdeck", failures)

	var topdeck_state = engine.create_game(_definitions(), _decks(), 354)
	topdeck_state.players[0].hand.cards = topdeck_state.players[0].hand.cards.slice(0, 2)
	topdeck_state.pending_attack = {
		"attacker_id": "dummy_attacker",
		"target_kind": "master",
		"target_player": 0
	}
	var topdeck_eval := extractor.evaluate(profile, engine, topdeck_state, 0, {
		"kind": "choose_defense",
		"payload": {
			"master_guard_card_ids": ["g1", "g2"]
		}
	}, {})
	var topdeck_trace = topdeck_eval.get("trace", [])
	_expect(_trace_has_key(topdeck_trace, "defense_master_guard_forces_topdeck"), "feature extractor: two-card guard from two-card hand should force topdeck", failures)

	var keep_window_state = engine.create_game(_definitions(), _decks(), 355)
	_expect(engine.apply_command(keep_window_state, GameCommand.create(0, "PlayCard", {
		"card_id": keep_window_state.players[0].hand.cards[0],
		"row": "front",
		"col": 0
	})).ok, "feature extractor: keep-window defense setup front should succeed", failures)
	keep_window_state.players[0].hand.cards = keep_window_state.players[0].hand.cards.slice(0, 4)
	keep_window_state.pending_attack = {
		"attacker_id": "dummy_attacker",
		"target_kind": "master",
		"target_player": 0
	}
	var keep_window_eval := extractor.evaluate(profile, engine, keep_window_state, 0, {
		"kind": "choose_defense",
		"payload": {
			"master_guard_card_ids": ["g1", "g2"]
		}
	}, {})
	var keep_window_trace = keep_window_eval.get("trace", [])
	_expect(_trace_has_key(keep_window_trace, "defense_master_guard_keeps_counterattack_window"), "feature extractor: master guard with spare hand and surviving board should keep counterattack window", failures)
	_expect(not _trace_has_key(keep_window_trace, "defense_master_guard_only_buys_time"), "feature extractor: stable master guard should not be marked as only buying time", failures)

	_expect(_trace_has_key(topdeck_trace, "defense_master_guard_only_buys_time"), "feature extractor: topdecking master guard with no board should be marked as only buying time", failures)

static func _test_artifact_activation_retention_features(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"activate_effect": 1.0,
			"activate_artifact_effect": 1.0,
			"activate_artifact_effect_low_hand_tax": 1.0,
			"activate_artifact_effect_closing_window": 1.0,
			"activate_artifact_effect_without_pressure": 1.0
		}
	}
	var state = engine.create_game(_definitions(), [
		["dev_artifact_lens", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 356)
	var artifact_id := str(state.players[0].hand.cards[0])
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "feature extractor: artifact retention test should play artifact", failures)
	state.players[0].hand.cards = state.players[0].hand.cards.slice(0, 1)
	state.players[1].master_hp = 8
	var low_hand_eval := extractor.evaluate(profile, engine, state, 0, {
		"kind": "activate_effect",
		"payload": {
			"source_id": artifact_id,
			"effect_id": "lens_draw"
		}
	}, {})
	var low_hand_trace = low_hand_eval.get("trace", [])
	_expect(_trace_has_key(low_hand_trace, "activate_artifact_effect"), "feature extractor: artifact activation should expose activate_artifact_effect", failures)
	_expect(_trace_has_key(low_hand_trace, "activate_artifact_effect_low_hand_tax"), "feature extractor: low-hand artifact activation should expose low-hand tax", failures)
	_expect(_trace_has_key(low_hand_trace, "activate_artifact_effect_without_pressure"), "feature extractor: low-pressure artifact activation should expose without-pressure signal", failures)

	var closing_state = engine.create_game(_definitions(), [
		["dev_artifact_lens", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta", "dev_legion_beta"]
	], 357)
	var closing_artifact_id := str(closing_state.players[0].hand.cards[0])
	_expect(engine.apply_command(closing_state, GameCommand.create(0, "PlayCard", {
		"card_id": closing_artifact_id,
		"row": "artifact",
		"col": -1
	})).ok, "feature extractor: artifact closing-window test should play artifact", failures)
	closing_state.players[1].master_hp = 5
	var closing_eval := extractor.evaluate(profile, engine, closing_state, 0, {
		"kind": "activate_effect",
		"payload": {
			"source_id": closing_artifact_id,
			"effect_id": "lens_draw"
		}
	}, {})
	var closing_trace = closing_eval.get("trace", [])
	_expect(_trace_has_key(closing_trace, "activate_artifact_effect_closing_window"), "feature extractor: artifact activation near kill range should expose closing-window signal", failures)

static func _test_pass_priority_pressure_features(failures: Array[String]) -> void:
	var engine := GameEngine.new()
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"pass_priority_with_response_available": 1.0,
			"pass_priority_while_defending_master": 1.0,
			"pass_priority_skips_defense_action": 1.0,
			"pass_priority_in_survival_mode": 1.0
		}
	}
	var state = engine.create_game(_definitions(), _decks(), 358)
	_advance_to_next_main(engine, state, failures, "feature extractor: pass-priority test should advance to player 1 main")
	var attacker_card_id := str(state.players[1].hand.cards[0])
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": attacker_card_id,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: pass-priority test should deploy the enemy attacker", failures)
	var attacker_id := str(state.players[1].battle_front[0].occupant)
	state.pending_attack = {
		"attacker_id": attacker_id,
		"target_kind": "master",
		"target_player": 0
	}
	state.priority_player = 0
	state.players[0].master_hp = 3
	var evaluation := extractor.evaluate(profile, engine, state, 0, {
		"kind": "pass_priority",
		"payload": {}
	}, {})
	var trace = evaluation.get("trace", [])
	_expect(_trace_has_key(trace, "pass_priority_with_response_available"), "feature extractor: passing with available defense should expose pass_priority_with_response_available", failures)
	_expect(_trace_has_key(trace, "pass_priority_while_defending_master"), "feature extractor: passing while master is under attack should expose pass_priority_while_defending_master", failures)
	_expect(_trace_has_key(trace, "pass_priority_skips_defense_action"), "feature extractor: passing instead of a legal defense should expose pass_priority_skips_defense_action", failures)
	_expect(_trace_has_key(trace, "pass_priority_in_survival_mode"), "feature extractor: passing at low hp should expose pass_priority_in_survival_mode", failures)

static func _advance_to_next_main(engine: GameEngine, state, failures: Array[String], message: String) -> void:
	for _i in range(6):
		_expect(engine.apply_command(state, GameCommand.create(state.active_player, "EndPhase")).ok, message, failures)
		if state.phase == "main":
			return
	failures.append(message)

static func _trace_has_key(trace, key: String) -> bool:
	if trace is Array:
		for row in trace:
			if str(row.get("key", "")) == key:
				return true
	return false

static func _definitions() -> Array:
	return CardDatabase.load_definitions()

static func _build_master_pressure_evaluation(engine: GameEngine, state, extractor: ProfileFeatureExtractor, profile: Dictionary, include_extra_front: bool, failures: Array[String], label: String, options: Dictionary = {}) -> Dictionary:
	var p0_front_a = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_front_a,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: %s pressure first attacker play should succeed" % label, failures)
	if include_extra_front:
		var p0_front_b = state.players[0].hand.cards[0]
		_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
			"card_id": p0_front_b,
			"row": "front",
			"col": 1
		})).ok, "feature extractor: %s pressure second attacker play should succeed" % label, failures)
	_advance_to_next_main(engine, state, failures, "feature extractor: %s pressure advance to player 1 main should succeed" % label)
	var p1_front = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": p1_front,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: %s pressure defender play should succeed" % label, failures)
	_advance_to_next_main(engine, state, failures, "feature extractor: %s pressure advance back to player 0 main should succeed" % label)

	var attacker_id: String = state.players[0].battle_front[0].occupant
	var defender_id: String = state.players[1].battle_front[0].occupant
	var attacker_bonus_power := int(options.get("attacker_bonus_power", 0))
	if attacker_bonus_power > 0:
		state.card_instances[attacker_id].flags["power_modifier_until_turn_end_turn"] = state.turn_number
		state.card_instances[attacker_id].flags["power_modifier_until_turn_end_amount"] = attacker_bonus_power
	var enemy_master_hp := int(options.get("enemy_master_hp", -1))
	if enemy_master_hp > 0:
		state.players[1].master_hp = enemy_master_hp
	var enemy_hand_size := int(options.get("enemy_hand_size", -1))
	if enemy_hand_size >= 0 and enemy_hand_size < state.players[1].hand.cards.size():
		state.players[1].hand.cards = state.players[1].hand.cards.slice(0, enemy_hand_size)
	state.card_instances[defender_id].damage_marked = 1000
	return extractor.evaluate(profile, engine, state, 0, {
		"kind": "declare_attack",
		"payload": {
			"attacker_id": attacker_id,
			"defender_id": defender_id
		}
	}, {})

static func _create_support_defense_state(include_extra_front: bool, seed: int, failures: Array[String]) -> Dictionary:
	var engine := GameEngine.new()
	var state = engine.create_game(_definitions(), _decks(), seed)
	var extractor := ProfileFeatureExtractor.new()
	var profile := {
		"weights": {
			"defense_with_supporter": 1.0,
			"defense_with_supporter_preserves_hand": 1.0,
			"defense_support_preserves_counterattack_window": 1.0,
			"defense_support_protects_master": 1.0,
			"defense_support_protects_board": 1.0
		}
	}

	var p0_front = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_front,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: defense setup front 0 should succeed", failures)
	var p0_back = state.players[0].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
		"card_id": p0_back,
		"row": "back",
		"col": 0
	})).ok, "feature extractor: defense setup back 0 should succeed", failures)
	if include_extra_front:
		var p0_front_extra = state.players[0].hand.cards[0]
		_expect(engine.apply_command(state, GameCommand.create(0, "PlayCard", {
			"card_id": p0_front_extra,
			"row": "front",
			"col": 1
		})).ok, "feature extractor: defense setup extra front should succeed", failures)
	_advance_to_next_main(engine, state, failures, "feature extractor: defense setup advance to player 1 main should succeed")
	var p1_front = state.players[1].hand.cards[0]
	_expect(engine.apply_command(state, GameCommand.create(1, "PlayCard", {
		"card_id": p1_front,
		"row": "front",
		"col": 0
	})).ok, "feature extractor: defense setup attacker play should succeed", failures)

	var defender_id: String = state.players[0].battle_front[0].occupant
	var supporter_id: String = state.players[0].battle_back[0].occupant
	var attacker_id: String = state.players[1].battle_front[0].occupant
	state.pending_attack = {
		"attacker_id": attacker_id,
		"target_kind": "card",
		"defender_id": defender_id
	}
	return {
		"engine": engine,
		"state": state,
		"extractor": extractor,
		"profile": profile,
		"supporter_id": supporter_id
	}

static func _decks() -> Array:
	return [
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"],
		["dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha", "dev_legion_alpha"]
	]

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
