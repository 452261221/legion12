extends RefCounted
class_name StateValidator

static func validate(state) -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for player in state.players:
		_validate_player(state, player, seen, errors)
	_validate_stack_pending_sources(state, seen, errors)
	_validate_pending_choice_stack_pending_sources(state, seen, errors)
	_validate_instances(state, seen, errors)
	_validate_calamity_state(state, errors)
	_validate_winner(state, errors)
	_validate_stack_items(state, state.stack, "stack", errors)
	_validate_stack_items(state, state.pending_triggers, "pending_trigger", errors)
	_validate_pending_choices(state, errors)
	_validate_pending_attack(state, errors)
	return errors

static func _validate_player(state, player, seen: Dictionary, errors: Array[String]) -> void:
	if player.master_hp < 0:
		errors.append("Player %s master hp is negative" % player.player_id)
	_validate_zone(state, player.player_id, player.master, "master", seen, errors)
	_validate_zone(state, player.player_id, player.hand, "hand", seen, errors)
	_validate_zone(state, player.player_id, player.deck, "deck", seen, errors)
	_validate_zone(state, player.player_id, player.grave, "grave", seen, errors)
	_validate_zone(state, player.player_id, player.cost_deck, "cost_deck", seen, errors)
	_validate_zone(state, player.player_id, player.cost_area, "cost_area", seen, errors)
	_validate_zone(state, player.player_id, player.spent_cost_area, "spent_cost_area", seen, errors)
	_validate_zone(state, player.player_id, player.artifact_zone, "artifact_zone", seen, errors)
	_validate_zone(state, player.player_id, player.trial_zone, "trial_zone", seen, errors)
	_validate_zone(state, player.player_id, player.city_zone, "city_zone", seen, errors)
	_validate_slots(state, player.player_id, "front", player.battle_front, seen, errors)
	_validate_slots(state, player.player_id, "back", player.battle_back, seen, errors)

static func _validate_zone(state, player_id: int, zone, expected_kind: String, seen: Dictionary, errors: Array[String]) -> void:
	if zone == null:
		errors.append("Player %s zone is missing: %s" % [player_id, expected_kind])
		return
	if zone.owner != player_id:
		errors.append("Zone owner mismatch: p%s %s owner=%s" % [player_id, expected_kind, zone.owner])
	if zone.kind != expected_kind:
		errors.append("Zone kind mismatch: p%s expected %s got %s" % [player_id, expected_kind, zone.kind])
	for card_id in zone.cards:
		_register_card_reference(state, card_id, "zone:%s:%s" % [player_id, expected_kind], expected_kind, {}, seen, errors)

static func _validate_slots(state, player_id: int, row: String, slots: Array, seen: Dictionary, errors: Array[String]) -> void:
	for index in range(slots.size()):
		var slot = slots[index]
		if slot.owner != player_id:
			errors.append("Slot owner mismatch: p%s %s[%s] owner=%s" % [player_id, row, index, slot.owner])
		if slot.row != row:
			errors.append("Slot row mismatch: p%s %s[%s] row=%s" % [player_id, row, index, slot.row])
		if slot.col != index:
			errors.append("Slot col mismatch: p%s %s[%s] col=%s" % [player_id, row, index, slot.col])
		if not slot.occupant.is_empty():
			_register_card_reference(
				state,
				slot.occupant,
				"slot:%s:%s:%s:occupant" % [player_id, row, index],
				"battle_%s" % row,
				{"row": row, "col": index},
				seen,
				errors
			)
			_validate_attached_underlay_for_host(
				state,
				slot.occupant,
				"slot:%s:%s:%s:occupant" % [player_id, row, index],
				seen,
				errors
			)
		if not slot.cover.is_empty():
			_register_card_reference(
				state,
				slot.cover,
				"slot:%s:%s:%s:cover" % [player_id, row, index],
				"battle_%s" % row,
				{"row": row, "col": index},
				seen,
				errors
			)

static func _validate_attached_underlay_for_host(state, host_id: String, host_location: String, seen: Dictionary, errors: Array[String]) -> void:
	if host_id.is_empty() or not state.card_instances.has(host_id):
		return
	var host = state.card_instances[host_id]
	for raw_attached_id in host.attached_cards:
		var attached_id = str(raw_attached_id)
		if attached_id.is_empty():
			continue
		_register_attached_underlay_reference(state, attached_id, host_id, "%s:attached" % host_location, seen, errors)

static func _register_attached_underlay_reference(state, card_id: String, host_id: String, location: String, seen: Dictionary, errors: Array[String]) -> void:
	if not state.card_instances.has(card_id):
		errors.append("Missing attached card instance: %s at %s" % [card_id, location])
		return
	if seen.has(card_id):
		errors.append("Card appears multiple times: %s (%s and %s)" % [card_id, seen[card_id], location])
	else:
		seen[card_id] = location
	var instance = state.card_instances[card_id]
	if not state.card_definitions.has(instance.definition_id):
		errors.append("Card definition is missing: %s -> %s" % [card_id, instance.definition_id])
	if instance.zone != "attached_underlay":
		errors.append("Card zone mismatch: %s expected attached_underlay got %s" % [card_id, instance.zone])
	if str(instance.position.get("host_id", "")) != host_id:
		errors.append("Attached card host mismatch: %s expected %s got %s" % [card_id, host_id, str(instance.position.get("host_id", ""))])
	_validate_instance_owner_controller(state, instance, errors)

static func _register_card_reference(state, card_id: String, location: String, expected_zone: String, expected_position: Dictionary, seen: Dictionary, errors: Array[String]) -> void:
	if not state.card_instances.has(card_id):
		errors.append("Missing card instance: %s at %s" % [card_id, location])
		return
	if seen.has(card_id):
		errors.append("Card appears multiple times: %s (%s and %s)" % [card_id, seen[card_id], location])
	else:
		seen[card_id] = location
	var instance = state.card_instances[card_id]
	if not state.card_definitions.has(instance.definition_id):
		errors.append("Card definition is missing: %s -> %s" % [card_id, instance.definition_id])
	if instance.zone != expected_zone:
		errors.append("Card zone mismatch: %s expected %s got %s" % [card_id, expected_zone, instance.zone])
	if expected_position.is_empty():
		if not instance.position.is_empty():
			errors.append("Card position should be empty outside battlefield: %s at %s" % [card_id, location])
	else:
		if str(instance.position.get("row", "")) != str(expected_position.get("row", "")) or int(instance.position.get("col", -1)) != int(expected_position.get("col", -1)):
			errors.append("Card position mismatch: %s expected %s got %s" % [card_id, expected_position, instance.position])
	_validate_instance_owner_controller(state, instance, errors)

static func _validate_instance_owner_controller(state, instance, errors: Array[String]) -> void:
	if instance.owner < 0 or instance.owner >= state.players.size():
		errors.append("Card owner is out of range: %s owner=%s" % [instance.instance_id, instance.owner])
	if instance.controller < 0 or instance.controller >= state.players.size():
		errors.append("Card controller is out of range: %s controller=%s" % [instance.instance_id, instance.controller])
	if instance.damage_marked < 0:
		errors.append("Card damage_marked is negative: %s" % instance.instance_id)

static func _validate_instances(state, seen: Dictionary, errors: Array[String]) -> void:
	var ids: Array = state.card_instances.keys()
	for card_id in ids:
		var instance = state.card_instances[card_id]
		if instance.instance_id != card_id:
			errors.append("Card instance id mismatch: key=%s instance_id=%s" % [card_id, instance.instance_id])
		if not seen.has(card_id):
			errors.append("Card is not referenced by any zone: %s" % card_id)
		_validate_instance_owner_controller(state, instance, errors)

static func _validate_stack_pending_sources(state, seen: Dictionary, errors: Array[String]) -> void:
	for item in state.stack:
		_register_stack_pending_source(state, item, "stack", seen, errors)
	for item in state.pending_triggers:
		_register_stack_pending_source(state, item, "pending_trigger", seen, errors)

static func _register_stack_pending_source(state, item, label: String, seen: Dictionary, errors: Array[String]) -> void:
	if not (item is Dictionary):
		return
	var source_id = str(item.get("source_instance_id", ""))
	if source_id.is_empty() or not state.card_instances.has(source_id):
		return
	var instance = state.card_instances[source_id]
	if instance.zone != "stack_pending":
		return
	if seen.has(source_id):
		return
	_register_card_reference(state, source_id, "%s:stack_pending" % label, "stack_pending", {}, seen, errors)

static func _validate_pending_choice_stack_pending_sources(state, seen: Dictionary, errors: Array[String]) -> void:
	for index in range(state.pending_choices.size()):
		var choice = state.pending_choices[index]
		if not (choice is Dictionary):
			continue
		for source_id in _pending_choice_source_ids(choice):
			if source_id.is_empty() or not state.card_instances.has(source_id):
				continue
			var instance = state.card_instances[source_id]
			if instance.zone != "stack_pending":
				continue
			if seen.has(source_id):
				continue
			_register_card_reference(
				state,
				source_id,
				"pending_choice:%s:stack_pending_source" % index,
				"stack_pending",
				{},
				seen,
				errors
			)

static func _pending_choice_source_ids(choice: Dictionary) -> Array[String]:
	var result: Array[String] = []
	_append_unique_source_id(result, str(choice.get("source_instance_id", "")))
	var context = choice.get("context", {})
	if context is Dictionary:
		_append_unique_source_id(result, str(context.get("source_instance_id", "")))
		var stack_item = context.get("stack_item", {})
		if stack_item is Dictionary:
			_append_unique_source_id(result, str(stack_item.get("source_instance_id", "")))
		var stack_items = context.get("stack_items", [])
		if stack_items is Array:
			for raw_item in stack_items:
				if raw_item is Dictionary:
					_append_unique_source_id(result, str(raw_item.get("source_instance_id", "")))
	return result

static func _append_unique_source_id(result: Array[String], source_id: String) -> void:
	if source_id.is_empty() or result.has(source_id):
		return
	result.append(source_id)

static func _validate_winner(state, errors: Array[String]) -> void:
	var defeated_players: Array[int] = []
	for player in state.players:
		if player.master_hp <= 0:
			defeated_players.append(player.player_id)
	if state.winner == -1:
		if not defeated_players.is_empty():
			errors.append("Winner is not decided even though a master reached 0 hp")
		return
	if state.winner < 0 or state.winner >= state.players.size():
		errors.append("Winner index is out of range: %s" % state.winner)
	if state.loss_reason == "master_hp_zero":
		if defeated_players.size() != 1:
			errors.append("master_hp_zero should have exactly one defeated player")
		elif state.winner == defeated_players[0]:
			errors.append("Winner cannot be the defeated player")

static func _validate_calamity_state(state, errors: Array[String]) -> void:
	if state.calamity_value < 0:
		errors.append("Calamity value cannot be negative")
	if not state.current_calamity.is_empty() and not state.card_definitions.has(state.current_calamity):
		errors.append("Current calamity definition is missing: %s" % state.current_calamity)
	for definition_id in state.calamity_deck:
		if not state.card_definitions.has(definition_id):
			errors.append("Calamity deck definition is missing: %s" % definition_id)
	for definition_id in state.calamity_grave:
		if not state.card_definitions.has(definition_id):
			errors.append("Calamity grave definition is missing: %s" % definition_id)

static func _validate_stack_items(state, items: Array, label: String, errors: Array[String]) -> void:
	for index in range(items.size()):
		var item = items[index]
		if not (item is Dictionary):
			errors.append("%s[%s] is not a dictionary" % [label, index])
			continue
		if str(item.get("effect_type", "")) == "event_response_window":
			var event_controller = int(item.get("controller", -1))
			if event_controller < 0 or event_controller >= state.players.size():
				errors.append("%s[%s] controller is out of range" % [label, index])
			if str(item.get("effect_id", "")).is_empty():
				errors.append("%s[%s] effect id is empty" % [label, index])
			continue
		var source_id = str(item.get("source_instance_id", ""))
		var effect_id = str(item.get("effect_id", ""))
		var controller = int(item.get("controller", -1))
		if controller < 0 or controller >= state.players.size():
			errors.append("%s[%s] controller is out of range" % [label, index])
		if source_id.begins_with("master_"):
			var master_player_id_text = source_id.trim_prefix("master_")
			if not master_player_id_text.is_valid_int():
				errors.append("%s[%s] references invalid master source: %s" % [label, index, source_id])
				continue
			var master_player_id = int(master_player_id_text)
			if master_player_id < 0 or master_player_id >= state.players.size():
				errors.append("%s[%s] master source is out of range: %s" % [label, index, source_id])
				continue
			if effect_id.is_empty():
				errors.append("%s[%s] effect id is empty" % [label, index])
			continue
		if source_id.begins_with("morale_"):
			var morale_player_id_text = source_id.trim_prefix("morale_")
			if not morale_player_id_text.is_valid_int():
				errors.append("%s[%s] references invalid morale source: %s" % [label, index, source_id])
				continue
			var morale_player_id = int(morale_player_id_text)
			if morale_player_id < 0 or morale_player_id >= state.players.size():
				errors.append("%s[%s] morale source is out of range: %s" % [label, index, source_id])
				continue
			if effect_id.is_empty():
				errors.append("%s[%s] effect id is empty" % [label, index])
			continue
		if source_id.begins_with("trial_") or source_id.begins_with("city_"):
			var source_parts = source_id.split("_", false, 2)
			if source_parts.size() != 2 or not source_parts[1].is_valid_int():
				errors.append("%s[%s] references invalid special source: %s" % [label, index, source_id])
				continue
			var source_player_id = int(source_parts[1])
			if source_player_id < 0 or source_player_id >= state.players.size():
				errors.append("%s[%s] special source is out of range: %s" % [label, index, source_id])
				continue
			if effect_id.is_empty():
				errors.append("%s[%s] effect id is empty" % [label, index])
			continue
		if source_id.is_empty() or not state.card_instances.has(source_id):
			errors.append("%s[%s] references missing source card" % [label, index])
			continue
		var instance = state.card_instances[source_id]
		if not state.card_definitions.has(instance.definition_id):
			errors.append("%s[%s] source definition is missing" % [label, index])
			continue
		if effect_id.is_empty():
			errors.append("%s[%s] effect id is empty" % [label, index])
			continue
		if not _card_has_effect(state, source_id, effect_id):
			errors.append("%s[%s] effect does not exist on source: %s.%s" % [label, index, source_id, effect_id])

static func _card_has_effect(state, source_id: String, effect_id: String) -> bool:
	var instance = state.card_instances.get(source_id)
	if instance == null:
		return false
	var definition = state.card_definitions.get(instance.definition_id)
	if definition == null:
		return false
	for effect in definition.effects:
		if str(effect.get("id", "")) == effect_id:
			return true
	return false

static func _validate_pending_choices(state, errors: Array[String]) -> void:
	for index in range(state.pending_choices.size()):
		var choice = state.pending_choices[index]
		if not (choice is Dictionary):
			errors.append("pending_choice[%s] is not a dictionary" % index)
			continue
		var choice_id = str(choice.get("choice_id", ""))
		var choice_type = str(choice.get("type", ""))
		var player_id = int(choice.get("player_id", -1))
		if choice_id.is_empty():
			errors.append("pending_choice[%s] choice_id is empty" % index)
		if choice_type.is_empty():
			errors.append("pending_choice[%s] type is empty" % index)
		if player_id < 0 or player_id >= state.players.size():
			errors.append("pending_choice[%s] player is out of range" % index)
		if choice_type == "search_deck_pick":
			var candidate_cards = choice.get("candidate_card_ids", [])
			if not (candidate_cards is Array) or candidate_cards.is_empty():
				errors.append("pending_choice[%s] search candidates are missing" % index)
				continue
			for raw_card_id in candidate_cards:
				var card_id = str(raw_card_id)
				var instance = state.card_instances.get(card_id)
				if instance == null:
					errors.append("pending_choice[%s] candidate card is missing: %s" % [index, card_id])
					continue
				if instance.zone != "deck":
					errors.append("pending_choice[%s] candidate card must stay in deck: %s" % [index, card_id])

static func _validate_pending_attack(state, errors: Array[String]) -> void:
	if state.pending_attack.is_empty():
		return
	var attacker_id = str(state.pending_attack.get("attacker_id", ""))
	if attacker_id.is_empty():
		errors.append("pending_attack attacker_id is empty")
	elif not state.card_instances.has(attacker_id):
		errors.append("pending_attack attacker is missing: %s" % attacker_id)
