extends RefCounted
class_name StateHasher

static func hash_public_and_private_state(state) -> String:
	var snapshot = {
		"seed": state.seed,
		"rng_state": state.rng.state,
		"active_player": state.active_player,
		"priority_player": state.priority_player,
		"priority_pass_count": state.priority_pass_count,
		"turn_number": state.turn_number,
		"phase": state.phase,
		"step": state.step,
		"calamity_value": state.calamity_value,
		"calamity_value_locked": state.calamity_value_locked,
		"current_calamity": state.current_calamity,
		"winner": state.winner,
		"loss_reason": state.loss_reason,
		"players": _build_player_rows(state),
		"card_instances": _build_card_rows(state),
		"stack": _normalize_value(state.stack),
		"pending_triggers": _normalize_value(state.pending_triggers),
		"pending_choices": _normalize_value(state.pending_choices),
		"pending_attack": _normalize_value(state.pending_attack),
		"continuous_modifiers": _normalize_value(state.continuous_modifiers)
	}
	return _stable_stringify(snapshot).sha256_text()

static func _build_player_rows(state) -> Array:
	var rows: Array = []
	for player in state.players:
		rows.append({
			"player_id": player.player_id,
			"master_hp": player.master_hp,
			"master_max_hp": player.master_max_hp,
			"master": player.master.cards.duplicate(),
			"hand": player.hand.cards.duplicate(),
			"deck": player.deck.cards.duplicate(),
			"grave": player.grave.cards.duplicate(),
			"cost_deck": player.cost_deck.cards.duplicate(),
			"cost_area": player.cost_area.cards.duplicate(),
			"spent_cost_area": player.spent_cost_area.cards.duplicate(),
			"artifact_zone": player.artifact_zone.cards.duplicate(),
			"trial_zone": player.trial_zone.cards.duplicate(),
			"city_zone": player.city_zone.cards.duplicate(),
			"battle_front": _build_slot_rows(player.battle_front),
			"battle_back": _build_slot_rows(player.battle_back),
			"counters": _normalize_value(player.counters),
			"flags": _normalize_value(player.flags),
			"once_per_turn": _normalize_value(player.once_per_turn),
			"once_per_game": _normalize_value(player.once_per_game)
		})
	return rows

static func _build_slot_rows(slots: Array) -> Array:
	var rows: Array = []
	for slot in slots:
		rows.append({
			"owner": slot.owner,
			"row": slot.row,
			"col": slot.col,
			"occupant": slot.occupant,
			"cover": slot.cover,
			"flags": _normalize_value(slot.flags)
		})
	return rows

static func _build_card_rows(state) -> Array:
	var ids: Array = state.card_instances.keys()
	ids.sort()
	var rows: Array = []
	for card_id in ids:
		var instance = state.card_instances[card_id]
		rows.append({
			"instance_id": instance.instance_id,
			"definition_id": instance.definition_id,
			"owner": instance.owner,
			"controller": instance.controller,
			"zone": instance.zone,
			"position": _normalize_value(instance.position),
			"face": instance.face,
			"orientation": instance.orientation,
			"visibility": _normalize_value(instance.visibility),
			"base_power": instance.base_power,
			"damage_marked": instance.damage_marked,
			"temp_modifiers": instance.temp_modifiers.duplicate(),
			"attached_cards": instance.attached_cards.duplicate(),
			"overlay_cards": instance.overlay_cards.duplicate(),
			"entered_turn": instance.entered_turn,
			"has_attacked_this_turn": instance.has_attacked_this_turn,
			"tags": instance.tags.duplicate(),
			"flags": _normalize_value(instance.flags)
		})
	return rows

static func _normalize_value(value):
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var normalized := {}
		for key in keys:
			normalized[str(key)] = _normalize_value(value[key])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize_value(item))
		return normalized_array
	return value

static func _stable_stringify(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts: Array[String] = []
		for key in keys:
			parts.append("%s:%s" % [JSON.stringify(str(key)), _stable_stringify(value[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts: Array[String] = []
		for item in value:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	return JSON.stringify(value)
