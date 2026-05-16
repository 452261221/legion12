extends RefCounted
class_name MoraleActions

const GameEvent = preload("res://rules/core/game_event.gd")

static func _is_sun_city_battlefield_morale(state, card_id: String, player_id: int) -> bool:
    if player_id != int(state.active_player):
        return false
    var instance = state.card_instances.get(card_id)
    if instance == null or int(instance.controller) != player_id:
        return false
    if not str(instance.zone).begins_with("battle_") or str(instance.orientation) != "active":
        return false
    var definition = state.get_definition(instance.definition_id)
    return definition != null and str(definition.id) == "suncity_s01_0212"

static func _battlefield_morale_candidates(state, player_id: int) -> Array[String]:
    var result: Array[String] = []
    var player = state.players[player_id]
    for row in [player.battle_front, player.battle_back]:
        for slot in row:
            var card_id := str(slot.occupant)
            if card_id.is_empty():
                continue
            if _is_sun_city_battlefield_morale(state, card_id, player_id):
                result.append(card_id)
    return result

static func add_morale_from_cost_deck(state, player_id: int, count: int, orientation: String = "active", command_id: String = "", source_faction: String = "") -> Array[GameEvent]:
    var player = state.players[player_id]
    if int(player.flags.get("tianting_morale_add_locked_turn", -1)) == int(state.turn_number) and source_faction != "tianting":
        return []
    var events: Array[GameEvent] = []
    for _i in range(count):
        var card_id = player.cost_deck.take_top()
        if card_id.is_empty():
            break
        player.cost_area.add_card(card_id)
        var instance = state.card_instances[card_id]
        instance.zone = "cost_area"
        instance.orientation = orientation
        var event = GameEvent.create(state.next_event_id(), "MoraleAdded", player_id, {"card_id": card_id, "orientation": orientation})
        event.created_by_command = command_id
        state.event_log.append(event)
        events.append(event)
    return events

static func count_active_morale(state, player_id: int) -> int:
    var total = 0
    for card_id in state.players[player_id].cost_area.cards:
        if state.card_instances[card_id].orientation == "active":
            total += 1
    if int(state.players[player_id].flags.get("temporary_morale_turn", -1)) == int(state.turn_number):
        total += int(state.players[player_id].flags.get("temporary_morale_count", 0))
    total += _battlefield_morale_candidates(state, player_id).size()
    return total

static func is_divine_morale(state, card_id: String) -> bool:
    var instance = state.card_instances.get(card_id)
    if instance == null:
        return false
    return bool(instance.flags.get("divine", false))

static func count_divine_morale(state, player_id: int) -> int:
    var total = 0
    for zone in [state.players[player_id].cost_area, state.players[player_id].spent_cost_area]:
        for card_id in zone.cards:
            if is_divine_morale(state, str(card_id)):
                total += 1
    return total

static func count_active_divine_morale(state, player_id: int) -> int:
    var total = 0
    for card_id in state.players[player_id].cost_area.cards:
        var instance = state.card_instances.get(card_id)
        if instance == null:
            continue
        if instance.orientation == "active" and bool(instance.flags.get("divine", false)):
            total += 1
    return total

static func count_spent_morale(state, player_id: int) -> int:
    return state.players[player_id].spent_cost_area.cards.size()

static func consume_morale(state, player_id: int, count: int, command_id: String = "") -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    var consumed = 0
    for card_id in player.cost_area.cards.duplicate():
        if consumed >= count:
            break
        var instance = state.card_instances[card_id]
        if instance.orientation != "active":
            continue
        instance.orientation = "rested"
        player.cost_area.remove_card(card_id)
        player.spent_cost_area.add_card(card_id)
        instance.zone = "spent_cost_area"
        consumed += 1
        var event = GameEvent.create(state.next_event_id(), "MoraleConsumed", player_id, {"card_id": card_id})
        event.created_by_command = command_id
        state.event_log.append(event)
        events.append(event)
    if consumed < count and int(player.flags.get("temporary_morale_turn", -1)) == int(state.turn_number):
        var available_temp = int(player.flags.get("temporary_morale_count", 0))
        var temp_to_consume = min(available_temp, count - consumed)
        if temp_to_consume > 0:
            player.flags["temporary_morale_count"] = available_temp - temp_to_consume
            consumed += temp_to_consume
            var temp_event = GameEvent.create(state.next_event_id(), "MoraleConsumed", player_id, {
                "temporary": true,
                "amount": temp_to_consume
            })
            temp_event.created_by_command = command_id
            state.event_log.append(temp_event)
            events.append(temp_event)
    for card_id in _battlefield_morale_candidates(state, player_id):
        if consumed >= count:
            break
        var instance = state.card_instances.get(card_id)
        if instance == null:
            continue
        instance.orientation = "rested"
        instance.flags["consumed_as_morale_turn"] = int(state.turn_number)
        consumed += 1
        var battlefield_event = GameEvent.create(state.next_event_id(), "MoraleConsumed", player_id, {
            "card_id": card_id,
            "from": str(instance.zone),
            "as_battlefield_morale": true
        })
        battlefield_event.created_by_command = command_id
        state.event_log.append(battlefield_event)
        events.append(battlefield_event)
    return events

static func add_temporary_morale(state, player_id: int, count: int, command_id: String = "", source_id: String = "") -> Array[GameEvent]:
    if count <= 0:
        return []
    var player = state.players[player_id]
    if int(player.flags.get("temporary_morale_turn", -1)) != int(state.turn_number):
        player.flags["temporary_morale_turn"] = int(state.turn_number)
        player.flags["temporary_morale_count"] = 0
    player.flags["temporary_morale_count"] = int(player.flags.get("temporary_morale_count", 0)) + count
    var event = GameEvent.create(state.next_event_id(), "MoraleAdded", player_id, {
        "temporary": true,
        "amount": count,
        "source_id": source_id
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func consume_divine_morale(state, player_id: int, count: int, command_id: String = "", flip_to_morale: bool = false) -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    var consumed = 0
    for card_id in player.cost_area.cards.duplicate():
        if consumed >= count:
            break
        var instance = state.card_instances.get(card_id)
        if instance == null:
            continue
        if instance.orientation != "active" or not bool(instance.flags.get("divine", false)):
            continue
        instance.orientation = "rested"
        player.cost_area.remove_card(card_id)
        player.spent_cost_area.add_card(card_id)
        instance.zone = "spent_cost_area"
        if flip_to_morale:
            instance.flags.erase("divine")
        consumed += 1
        var event = GameEvent.create(state.next_event_id(), "MoraleConsumed", player_id, {
            "card_id": card_id,
            "divine": true,
            "flipped_to_morale": flip_to_morale
        })
        event.created_by_command = command_id
        state.event_log.append(event)
        events.append(event)
    return events

static func flip_morale_cards(state, player_id: int, card_ids: Array[String], divine: bool, command_id: String = "") -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    var valid_zones := {
        "cost_area": true,
        "spent_cost_area": true
    }
    for card_id in card_ids:
        var instance = state.card_instances.get(card_id)
        if instance == null:
            continue
        if int(instance.owner) != player_id:
            continue
        if not valid_zones.has(str(instance.zone)):
            continue
        if bool(instance.flags.get("divine", false)) == divine:
            continue
        if divine:
            instance.flags["divine"] = true
        else:
            instance.flags.erase("divine")
        var event = GameEvent.create(state.next_event_id(), "MoraleFlipped", player_id, {
            "card_id": card_id,
            "divine": divine,
            "zone": str(instance.zone)
        })
        event.created_by_command = command_id
        state.event_log.append(event)
        events.append(event)
    return events

static func ready_all_morale(state, player_id: int, command_id: String = "", source_kind: String = "phase") -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    for card_id in player.spent_cost_area.cards.duplicate():
        player.spent_cost_area.remove_card(card_id)
        player.cost_area.add_card(card_id)
        var instance = state.card_instances[card_id]
        instance.zone = "cost_area"
        instance.orientation = "active"
        var event = GameEvent.create(state.next_event_id(), "MoraleReadied", player_id, {
            "card_id": card_id,
            "from_orientation": "rested",
            "source_kind": source_kind
        })
        event.created_by_command = command_id
        state.event_log.append(event)
        events.append(event)
    for card_id in player.cost_area.cards:
        state.card_instances[card_id].orientation = "active"
    return events

static func ready_spent_morale(state, player_id: int, count: int, command_id: String = "", source_kind: String = "effect") -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    var readied = 0
    for card_id in player.spent_cost_area.cards.duplicate():
        if readied >= max(0, count):
            break
        player.spent_cost_area.remove_card(card_id)
        player.cost_area.add_card(card_id)
        var instance = state.card_instances[card_id]
        instance.zone = "cost_area"
        instance.orientation = "active"
        readied += 1
        var event = GameEvent.create(state.next_event_id(), "MoraleReadied", player_id, {
            "card_id": card_id,
            "from_orientation": "rested",
            "source_kind": source_kind
        })
        event.created_by_command = command_id
        state.event_log.append(event)
        events.append(event)
    return events

static func refund_spent_morale(state, player_id: int, count: int, command_id: String = "", source_kind: String = "effect") -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    var refunded = 0
    for card_id in player.spent_cost_area.cards.duplicate():
        if refunded >= max(0, count):
            break
        var instance = state.card_instances.get(card_id)
        if instance == null:
            continue
        player.spent_cost_area.remove_card(card_id)
        if bool(instance.flags.get("grave_when_leaving_morale", false)):
            var owner_id := int(instance.owner)
            state.players[owner_id].grave.add_card_to_top(card_id)
            instance.zone = "grave"
            instance.position = {}
            instance.orientation = "active"
            instance.controller = owner_id
            instance.flags.erase("grave_when_leaving_morale")
            var grave_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", owner_id, {
                "card_id": card_id,
                "from": "spent_cost_area",
                "to": "grave",
                "reason": "refund_morale"
            })
            grave_event.created_by_command = command_id
            state.event_log.append(grave_event)
            events.append(grave_event)
        else:
            player.cost_area.add_card(card_id)
            instance.zone = "cost_area"
            instance.orientation = "active"
            var ready_event = GameEvent.create(state.next_event_id(), "MoraleReadied", player_id, {
                "card_id": card_id,
                "from_orientation": "rested",
                "source_kind": source_kind
            })
            ready_event.created_by_command = command_id
            state.event_log.append(ready_event)
            events.append(ready_event)
        refunded += 1
    return events
