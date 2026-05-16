extends RefCounted
class_name ObservationBuilder

const GameEvent = preload("res://rules/core/game_event.gd")

const RECENT_EVENT_LIMIT := 8

func build(engine, state, viewer_player_id: int) -> Dictionary:
	var waiting_state: Dictionary = engine.get_waiting_state(state)
	var self_player = state.get_player(viewer_player_id)
	var opponent_player = state.get_player(1 - viewer_player_id)
	return {
		"schema_version": 1,
		"viewer_player_id": viewer_player_id,
		"turn_number": int(state.turn_number),
		"phase": str(state.phase),
		"active_player": int(state.active_player),
		"priority_player": int(state.priority_player),
		"waiting_state": waiting_state.duplicate(true),
		"self": _build_player_view(engine, state, viewer_player_id, self_player, true),
		"opponent": _build_player_view(engine, state, viewer_player_id, opponent_player, false),
		"battlefield": {
			"players": [
				_build_battlefield_player_view(engine, state, viewer_player_id, self_player, true),
				_build_battlefield_player_view(engine, state, viewer_player_id, opponent_player, false)
			]
		},
		"stack": _build_stack_view(engine, state, viewer_player_id),
		"pending_attack": _build_pending_attack_view(engine, state, viewer_player_id),
		"pending_choice": _build_pending_choice_view(engine, state, viewer_player_id),
		"recent_events": _build_recent_events_view(state, viewer_player_id),
		"public_reveals": _build_public_reveals_view(state, viewer_player_id),
		"profiles": {}
	}

func _build_player_view(engine, state, viewer_player_id: int, player, is_self: bool) -> Dictionary:
	return {
		"player_id": int(player.player_id),
		"name": str(player.name),
		"master_name": str(player.master_name),
		"master_id": str(player.master_definition_id),
		"master_hp": int(player.master_hp),
		"master_max_hp": int(player.master_max_hp),
		"hand_count": int(player.hand.cards.size()),
		"hand": _build_hand_view(state, viewer_player_id, player, is_self),
		"deck_count": int(player.deck.cards.size()),
		"cost_deck_count": int(player.cost_deck.cards.size()),
		"grave": _build_zone_cards(engine, state, viewer_player_id, player.grave.cards),
		"cost_area": _build_zone_cards(engine, state, viewer_player_id, player.cost_area.cards),
		"spent_cost_area": _build_zone_cards(engine, state, viewer_player_id, player.spent_cost_area.cards),
		"artifact_zone": _build_zone_cards(engine, state, viewer_player_id, player.artifact_zone.cards),
		"front": _build_row_view(engine, state, viewer_player_id, player.battle_front),
		"back": _build_row_view(engine, state, viewer_player_id, player.battle_back),
		"counters": player.counters.duplicate(true) if is_self else {},
		"flags": player.flags.duplicate(true) if is_self else {}
	}

func _build_battlefield_player_view(engine, state, viewer_player_id: int, player, is_self: bool) -> Dictionary:
	return {
		"player_id": int(player.player_id),
		"is_self": is_self,
		"front": _build_row_view(engine, state, viewer_player_id, player.battle_front),
		"back": _build_row_view(engine, state, viewer_player_id, player.battle_back)
	}

func _build_hand_view(state, viewer_player_id: int, player, is_self: bool) -> Array:
	var cards: Array = []
	if not is_self:
		return cards
	for card_id in player.hand.cards:
		cards.append(_build_card_view(state, viewer_player_id, str(card_id), true))
	return cards

func _build_zone_cards(engine, state, viewer_player_id: int, card_ids: Array) -> Array:
	var cards: Array = []
	for card_id in card_ids:
		var view := _build_card_view(state, viewer_player_id, str(card_id), _is_card_visible_to_viewer(state, viewer_player_id, str(card_id)))
		if not view.is_empty():
			cards.append(view)
	return cards

func _build_row_view(engine, state, viewer_player_id: int, slots: Array) -> Array:
	var row: Array = []
	for slot in slots:
		var slot_view := {
			"row": str(slot.row),
			"col": int(slot.col),
			"owner": int(slot.owner),
			"flags": slot.flags.duplicate(true),
			"occupant": {},
			"cover": {}
		}
		if not str(slot.occupant).is_empty():
			slot_view["occupant"] = _build_card_view(state, viewer_player_id, str(slot.occupant), _is_card_visible_to_viewer(state, viewer_player_id, str(slot.occupant)))
		if not str(slot.cover).is_empty():
			slot_view["cover"] = _build_card_view(state, viewer_player_id, str(slot.cover), _is_card_visible_to_viewer(state, viewer_player_id, str(slot.cover)))
		row.append(slot_view)
	return row

func _build_stack_view(engine, state, viewer_player_id: int) -> Array:
	var stack_view: Array = []
	for item in state.stack:
		var source_id := str(item.get("source_instance_id", ""))
		stack_view.append({
			"stack_id": str(item.get("stack_id", "")),
			"controller": int(item.get("controller", -1)),
			"effect_id": str(item.get("effect_id", "")),
			"effect_type": str(item.get("effect_type", "")),
			"source_instance_id": source_id,
			"source_card": _build_card_view(state, viewer_player_id, source_id, _is_card_visible_to_viewer(state, viewer_player_id, source_id))
		})
	return stack_view

func _build_pending_attack_view(engine, state, viewer_player_id: int) -> Dictionary:
	if state.pending_attack.is_empty():
		return {}
	var pending: Dictionary = state.pending_attack
	var attacker_id := str(pending.get("attacker_id", ""))
	var blocker_id := str(pending.get("blocker_id", ""))
	var supporter_id := str(pending.get("supporter_id", ""))
	var defender_id := str(pending.get("defender_id", ""))
	return {
		"attacker_id": attacker_id,
		"attacker": _build_card_view(state, viewer_player_id, attacker_id, _is_card_visible_to_viewer(state, viewer_player_id, attacker_id)),
		"target_kind": str(pending.get("target_kind", "")),
		"target_player": int(pending.get("target_player", -1)),
		"defender_id": defender_id,
		"defender": _build_card_view(state, viewer_player_id, defender_id, _is_card_visible_to_viewer(state, viewer_player_id, defender_id)),
		"blocker_id": blocker_id,
		"blocker": _build_card_view(state, viewer_player_id, blocker_id, _is_card_visible_to_viewer(state, viewer_player_id, blocker_id)),
		"supporter_id": supporter_id,
		"supporter": _build_card_view(state, viewer_player_id, supporter_id, _is_card_visible_to_viewer(state, viewer_player_id, supporter_id))
	}

func _build_pending_choice_view(engine, state, viewer_player_id: int) -> Dictionary:
	if state.pending_choices.is_empty():
		return {}
	var choice: Dictionary = state.pending_choices[0].duplicate(true)
	var owner_id := int(choice.get("player_id", -1))
	var result := {
		"choice_id": str(choice.get("choice_id", "")),
		"player_id": owner_id,
		"type": str(choice.get("type", "")),
		"operation": str(choice.get("operation", "")),
		"title": str(choice.get("title", "")),
		"count": int(choice.get("count", 0)),
		"is_viewer_owner": owner_id == viewer_player_id
	}
	if owner_id != viewer_player_id:
		return result
	if choice.has("options"):
		result["options"] = choice.get("options", []).duplicate(true)
	if choice.has("candidate_card_ids"):
		result["candidate_card_ids"] = choice.get("candidate_card_ids", []).duplicate(true)
	if choice.has("looked_cards"):
		var looked_cards: Array = []
		for card_id in choice.get("looked_cards", []):
			looked_cards.append(_build_card_view(state, viewer_player_id, str(card_id), true))
		result["looked_cards"] = looked_cards
	var context: Dictionary = choice.get("context", {})
	if not context.is_empty():
		result["context"] = _sanitize_choice_context(engine, state, viewer_player_id, context)
	return result

func _sanitize_choice_context(engine, state, viewer_player_id: int, context: Dictionary) -> Dictionary:
	var safe: Dictionary = {}
	for key in context.keys():
		match str(key):
			"card_id", "source_id", "target_card_id":
				var card_id := str(context.get(key, ""))
				safe[key] = card_id
				safe["%s_view" % str(key)] = _build_card_view(state, viewer_player_id, card_id, true)
			"slot_options", "stack_item":
				safe[key] = context.get(key, []).duplicate(true) if context.get(key) is Array else context.get(key, {}).duplicate(true)
			_:
				var value = context.get(key)
				if value is Array:
					safe[key] = value.duplicate(true)
				elif value is Dictionary:
					safe[key] = value.duplicate(true)
				else:
					safe[key] = value
	return safe

func _build_recent_events_view(state, viewer_player_id: int) -> Array:
	var events: Array = []
	var start: int = max(0, state.event_log.size() - RECENT_EVENT_LIMIT)
	for index in range(start, state.event_log.size()):
		var event: GameEvent = state.event_log[index]
		var event_view := {
			"event_id": int(event.event_id),
			"type": str(event.type),
			"player_id": int(event.player_id),
			"created_by_command": str(event.created_by_command)
		}
		event_view.merge(_build_recent_event_details(state, viewer_player_id, event), true)
		events.append(event_view)
	return events


func _build_recent_event_details(state, viewer_player_id: int, event: GameEvent) -> Dictionary:
	match str(event.type):
		"CardsRevealedToAll":
			return _build_revealed_event_view(state, viewer_player_id, event, true)
		"CardsRevealedToOpponent":
			return _build_revealed_event_view(state, viewer_player_id, event, int(event.player_id) == viewer_player_id)
		_:
			return {}


func _build_revealed_event_view(state, viewer_player_id: int, event: GameEvent, include_cards: bool) -> Dictionary:
	var payload: Dictionary = event.payload if event.payload is Dictionary else {}
	var result := {
		"title": str(payload.get("title", "")),
		"revealing_player_id": int(payload.get("revealing_player_id", -1))
	}
	if not include_cards:
		return result
	var revealed_cards: Array = []
	for raw_card_id in payload.get("card_ids", []):
		var card_id := str(raw_card_id)
		if card_id.is_empty():
			continue
		var card_view := _build_card_view(state, viewer_player_id, card_id, true)
		if not card_view.is_empty():
			revealed_cards.append(card_view)
	result["revealed_cards"] = revealed_cards
	return result


func _build_public_reveals_view(state, viewer_player_id: int) -> Array:
	var reveals: Array = []
	var start: int = max(0, state.event_log.size() - RECENT_EVENT_LIMIT)
	for index in range(start, state.event_log.size()):
		var event: GameEvent = state.event_log[index]
		var event_type := str(event.type)
		if event_type != "CardsRevealedToAll" and event_type != "CardsRevealedToOpponent":
			continue
		var include_cards := event_type == "CardsRevealedToAll" or int(event.player_id) == viewer_player_id
		if not include_cards:
			continue
		var reveal_view := _build_revealed_event_view(state, viewer_player_id, event, true)
		var revealed_cards = reveal_view.get("revealed_cards", [])
		if not (revealed_cards is Array) or revealed_cards.is_empty():
			continue
		reveal_view["event_id"] = int(event.event_id)
		reveal_view["type"] = event_type
		reveal_view["target_player_id"] = int(event.player_id)
		reveal_view["created_by_command"] = str(event.created_by_command)
		reveals.append(reveal_view)
	return reveals

func _is_card_visible_to_viewer(state, viewer_player_id: int, card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return false
	if int(instance.owner) == viewer_player_id and str(instance.zone) == "hand":
		return true
	if str(instance.zone) == "deck" or str(instance.zone) == "cost_deck":
		return false
	if str(instance.face) == "face_down" and int(instance.owner) != viewer_player_id:
		return false
	if bool(instance.flags.get("concealed", false)) and int(instance.owner) != viewer_player_id:
		return false
	return true

func _build_card_view(state, viewer_player_id: int, card_id: String, is_visible: bool) -> Dictionary:
	if card_id.is_empty():
		return {}
	var instance = state.card_instances.get(card_id)
	if instance == null:
		return {}
	var result := {
		"instance_id": str(instance.instance_id),
		"owner": int(instance.owner),
		"controller": int(instance.controller),
		"zone": str(instance.zone),
		"position": instance.position.duplicate(true),
		"face": str(instance.face),
		"orientation": str(instance.orientation)
	}
	if not is_visible:
		result["visibility"] = "hidden"
		return result
	var definition = state.get_definition(str(instance.definition_id))
	result["visibility"] = "visible"
	result["definition_id"] = str(instance.definition_id)
	if definition != null:
		result["name"] = str(definition.name)
		result["type"] = str(definition.type)
		result["faction"] = str(definition.faction)
		result["cost"] = int(definition.cost)
		result["base_power"] = int(definition.power)
		result["hp"] = int(definition.hp)
		result["keywords"] = definition.keywords.duplicate(true)
		result["traits"] = definition.traits.duplicate(true)
		result["definition"] = _build_definition_view(definition)
		result["text"] = str(definition.text)
	result["current_power"] = max(0, int(instance.base_power) - int(instance.damage_marked))
	result["damage_marked"] = int(instance.damage_marked)
	result["entered_turn"] = int(instance.entered_turn)
	result["has_attacked_this_turn"] = bool(instance.has_attacked_this_turn)
	result["tags"] = instance.tags.duplicate(true)
	result["flags"] = instance.flags.duplicate(true) if int(instance.owner) == viewer_player_id or str(instance.face) != "face_down" else {}
	return result

func _build_definition_view(definition) -> Dictionary:
	if definition == null:
		return {}
	return {
		"id": str(definition.id),
		"name": str(definition.name),
		"faction": str(definition.faction),
		"type": str(definition.type),
		"subtypes": definition.subtypes.duplicate(true),
		"troop_type": str(definition.troop_type),
		"cost": int(definition.cost),
		"power": int(definition.power),
		"calamity_level": int(definition.calamity_level),
		"hp": int(definition.hp),
		"limit": int(definition.limit),
		"traits": definition.traits.duplicate(true),
		"keywords": definition.keywords.duplicate(true),
		"effects": definition.effects.duplicate(true),
		"play_options": definition.play_options.duplicate(true),
		"text": str(definition.text),
		"image_path": str(definition.image_path),
		"source": definition.source.duplicate(true)
	}
