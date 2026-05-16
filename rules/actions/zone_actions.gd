extends RefCounted
class_name ZoneActions

const GameEvent = preload("res://rules/core/game_event.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")

static func _is_sun_city_gravebound_definition(definition_id: String) -> bool:
    return definition_id == "suncity_s01_0212" or definition_id == "suncity_s02_0201"

static func _is_sun_city_gravebound_instance(instance) -> bool:
    return instance != null and _is_sun_city_gravebound_definition(str(instance.definition_id))

static func _leave_ignores_interceptors(options: Dictionary) -> bool:
    return bool(options.get("ignore_leave_interceptors", false)) or str(options.get("source_kind", "")) == "calamity"

static func _leave_is_unpreventable(options: Dictionary) -> bool:
    return bool(options.get("unpreventable_leave", false)) or str(options.get("source_kind", "")) == "calamity"

static func _payload_with_option_flags(base_payload: Dictionary, options: Dictionary = {}) -> Dictionary:
    var payload: Dictionary = base_payload.duplicate(true)
    for key in ["source_kind", "source_id", "source_card_id", "source_player_id", "reason", "calamity_id", "suppress_triggers"]:
        if options.has(key):
            payload[key] = options[key]
    return payload

static func _track_suncity_tomb_leave(state, instance) -> void:
    if instance == null:
        return
    var definition = state.get_definition(instance.definition_id)
    if definition == null:
        return
    if str(definition.name).find("陵墓") < 0:
        return
    var controller = int(instance.controller)
    var current = int(state.players[controller].flags.get("suncity_tomb_left_count", 0))
    state.players[controller].flags["suncity_tomb_left_count"] = current + 1

static func _maybe_revert_master_fighter(state, card_id: String, from: String, command_id: String = "") -> Array[GameEvent]:
    var instance = state.card_instances.get(card_id)
    if instance == null:
        return []
    var controller = int(instance.flags.get("sunwukong_master_controller", -1))
    if controller < 0 or controller >= state.players.size():
        return []
    var player = state.players[controller]
    if str(player.flags.get("sunwukong_fighter_card_id", "")) == card_id:
        player.flags.erase("sunwukong_fighter_card_id")
    state.card_instances.erase(card_id)
    var reverted_event = GameEvent.create(state.next_event_id(), "MasterFighterReverted", controller, {
        "card_id": card_id,
        "from": from
    })
    reverted_event.created_by_command = command_id
    state.event_log.append(reverted_event)
    return [reverted_event]

static func _restore_overlay_base_to_slot(state, slot, top_card_id: String, command_id: String = "") -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    var top_instance = state.card_instances.get(top_card_id)
    if top_instance == null or top_instance.overlay_cards.is_empty():
        return events
    var base_id = str(top_instance.overlay_cards[0])
    top_instance.overlay_cards.clear()
    top_instance.flags.erase("promotion_base_card_id")
    slot.cover = ""
    var base_instance = state.card_instances.get(base_id)
    if base_instance == null:
        return events
    slot.occupant = base_id
    base_instance.zone = "battle_%s" % str(slot.row)
    base_instance.position = {"row": str(slot.row), "col": int(slot.col)}
    base_instance.orientation = str(top_instance.orientation)
    base_instance.has_attacked_this_turn = bool(top_instance.has_attacked_this_turn)
    base_instance.flags.erase("overlaid_by_card_id")
    var restore_event = GameEvent.create(state.next_event_id(), "CardOverlayRestored", int(base_instance.controller), {
        "card_id": base_id,
        "row": str(slot.row),
        "col": int(slot.col),
        "restored_from": top_card_id
    })
    restore_event.created_by_command = command_id
    state.event_log.append(restore_event)
    events.append(restore_event)
    return events

static func _detach_attached_underlay_token(state, card_id: String, instance, command_id: String = "", reason: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    if instance == null:
        return events
    var token_id = str(instance.flags.get("attached_underlay_token_id", ""))
    if token_id.is_empty():
        return events
    var row = str(instance.position.get("row", ""))
    var col = int(instance.position.get("col", -1))
    if not row.is_empty() and col >= 0:
        var slot = state.players[int(instance.controller)].get_slot(row, col)
        if slot != null and str(slot.cover) == token_id:
            slot.cover = ""
    instance.flags.erase("attached_underlay_token_id")
    instance.flags.erase("persistent_power_bonus")
    instance.flags.erase("persistent_keywords")
    if state.card_instances.has(token_id):
        state.card_instances.erase(token_id)
    var detach_event = GameEvent.create(state.next_event_id(), "CardOverlayDetached", int(instance.controller), _payload_with_option_flags({
        "base_card_id": card_id,
        "cover_card_id": token_id,
        "reason": reason
    }, options))
    detach_event.created_by_command = command_id
    state.event_log.append(detach_event)
    events.append(detach_event)
    return events

static func _release_attached_cards_to_grave(state, host_card_id: String, instance, command_id: String = "", reason: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    if instance == null or instance.attached_cards.is_empty():
        return events
    var attached_snapshot = instance.attached_cards.duplicate()
    instance.attached_cards.clear()
    for raw_card_id in attached_snapshot:
        var card_id = str(raw_card_id)
        var attached_instance = state.card_instances.get(card_id)
        if attached_instance == null:
            continue
        var owner_player = state.players[int(attached_instance.owner)]
        owner_player.hand.remove_card(card_id)
        owner_player.deck.erase(card_id)
        owner_player.grave.remove_card(card_id)
        owner_player.grave.add_card_to_top(card_id)
        attached_instance.zone = "grave"
        attached_instance.position = {}
        attached_instance.controller = attached_instance.owner
        attached_instance.orientation = "active"
        attached_instance.face = "face_up"
        attached_instance.damage_marked = 0
        attached_instance.has_attacked_this_turn = false
        var moved_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", int(attached_instance.owner), _payload_with_option_flags({
            "card_id": card_id,
            "from": "attached_underlay",
            "to": "grave",
            "host_id": host_card_id,
            "reason": reason
        }, options))
        moved_event.created_by_command = command_id
        state.event_log.append(moved_event)
        events.append(moved_event)
    return events

static func _try_suncity_horemheb_substitute(state, instance, player_id: int, row: String, col: int, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    if instance == null or str(instance.definition_id) != "suncity_s01_0205":
        return events
    if int(instance.flags.get("suncity_horemheb_substitute_turn", -1)) == int(state.turn_number):
        return events
    var replacement_source_id = str(options.get("source_card_id", ""))
    var replacement_source_kind = str(options.get("source_kind", ""))
    var tomb_guard_id := ""
    var tomb_guard_row := ""
    var tomb_guard_col := -1
    for candidate_row in ["front", "back"]:
        var row_slots = state.players[player_id].battle_front if candidate_row == "front" else state.players[player_id].battle_back
        for slot in row_slots:
            if str(slot.occupant).is_empty():
                continue
            if str(slot.occupant) == str(instance.instance_id):
                continue
            var candidate_instance = state.card_instances.get(str(slot.occupant))
            if candidate_instance == null or str(candidate_instance.definition_id) != "suncity_s01_0212":
                continue
            tomb_guard_id = str(slot.occupant)
            tomb_guard_row = candidate_row
            tomb_guard_col = int(slot.col)
            break
        if not tomb_guard_id.is_empty():
            break
    if tomb_guard_id.is_empty():
        return events
    instance.flags["suncity_horemheb_substitute_turn"] = int(state.turn_number)
    instance.damage_marked = 0
    var prevented = GameEvent.create(state.next_event_id(), "CardDeathPrevented", player_id, {
        "card_id": str(instance.instance_id),
        "row": row,
        "col": col,
        "replacement": "suncity_horemheb_substitute"
    })
    prevented.created_by_command = command_id
    state.event_log.append(prevented)
    events.append(prevented)
    var replacement = GameEvent.create(state.next_event_id(), "ReplacementEffectApplied", player_id, {
        "card_id": str(instance.instance_id),
        "effect": "suncity_horemheb_substitute",
        "substitute_card_id": tomb_guard_id
    })
    replacement.created_by_command = command_id
    state.event_log.append(replacement)
    events.append(replacement)
    events.append_array(move_battlefield_to_grave(state, player_id, tomb_guard_row, tomb_guard_col, command_id, {
        "source_card_id": replacement_source_id,
        "source_kind": replacement_source_kind
    }))
    return events

static func _has_pending_olympus_lethal_choice(state, card_id: String) -> bool:
    for raw_choice in state.pending_choices:
        if not (raw_choice is Dictionary):
            continue
        var operation = str(raw_choice.get("operation", ""))
        if operation != "olympus_achilles_lethal_replace" and operation != "olympus_helen_lethal_replace":
            continue
        var context = raw_choice.get("context", {})
        if context is Dictionary and str(context.get("card_id", "")) == card_id:
            return true
    return false

static func _has_pending_kusanagi_leave_choice(state, card_id: String) -> bool:
    for raw_choice in state.pending_choices:
        if not (raw_choice is Dictionary):
            continue
        if str(raw_choice.get("operation", "")) != "kusanagi_leave_to_top_choice":
            continue
        var context = raw_choice.get("context", {})
        if context is Dictionary and str(context.get("card_id", "")) == card_id:
            return true
    return false

static func _request_option_choice(state, player_id: int, options: Array, title: String, operation: String, context: Dictionary, command_id: String = "") -> Array[GameEvent]:
    if options.is_empty():
        return []
    var choice = {
        "choice_id": state.next_choice_id(),
        "player_id": player_id,
        "type": "option_pick",
        "operation": operation,
        "title": title,
        "options": options,
        "context": context.duplicate(true)
    }
    state.pending_choices.append(choice)
    var event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
        "choice_id": choice.choice_id,
        "choice_type": choice.type,
        "operation": operation,
        "title": title
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func _request_candidate_cards_choice(state, player_id: int, candidate_card_ids: Array, count: int, title: String, operation: String, context: Dictionary, command_id: String = "") -> Array[GameEvent]:
    if candidate_card_ids.is_empty() or count <= 0:
        return []
    var choice = {
        "choice_id": state.next_choice_id(),
        "player_id": player_id,
        "type": "candidate_cards_pick",
        "operation": operation,
        "title": title,
        "count": count,
        "candidate_card_ids": candidate_card_ids.duplicate(),
        "context": context.duplicate(true)
    }
    state.pending_choices.append(choice)
    var event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
        "choice_id": choice.choice_id,
        "choice_type": choice.type,
        "operation": operation,
        "title": title
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func _maybe_request_olympus_lethal_choice(state, instance, player_id: int, row: String, col: int, command_id: String, options: Dictionary) -> Array[GameEvent]:
    if instance == null or bool(options.get("skip_lethal_replacement_choice", false)):
        return []
    var card_id = str(instance.instance_id)
    if card_id.is_empty() or _has_pending_olympus_lethal_choice(state, card_id):
        return []
    var context = {
        "card_id": card_id,
        "player_id": player_id,
        "row": row,
        "col": col,
        "grave_options": options.duplicate(true)
    }
    match str(instance.definition_id):
        "olympus_s02_0504":
            if row != "front":
                return []
            if int(instance.flags.get("olympus_achilles_lethal_replace_used_turn", -1)) == state.turn_number:
                return []
            if MoraleActions.count_active_divine_morale(state, player_id) < 1:
                return []
            return _request_option_choice(state, player_id, [
                {"id": "yes", "label": "消耗并翻转1神力"},
                {"id": "no", "label": "不发动"}
            ], "阿喀琉斯：是否代替承受本次致命伤害？", "olympus_achilles_lethal_replace", context, command_id)
        "olympus_s02_0515":
            if row != "front":
                return []
            if int(instance.flags.get("olympus_helen_lethal_replace_used_turn", -1)) == state.turn_number:
                return []
            var candidates: Array[String] = []
            for raw_card_id in state.get_player(player_id).hand.cards:
                var hand_card_id = str(raw_card_id)
                var hand_instance = state.card_instances.get(hand_card_id)
                var definition = state.get_definition(hand_instance.definition_id) if hand_instance != null else null
                if definition == null or not definition.is_legion():
                    continue
                if str(definition.id) == "olympus_s02_0515":
                    continue
                candidates.append(hand_card_id)
            if candidates.is_empty():
                return []
            return _request_candidate_cards_choice(state, player_id, candidates, 1, "海伦：选择弃置1张手牌军团，代替承受本次致命伤害", "olympus_helen_lethal_replace", context, command_id)
        _:
            return []

static func _maybe_request_kusanagi_leave_choice(state, instance, player_id: int, row: String, col: int, command_id: String, fallback_action: String, options: Dictionary = {}) -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    if instance == null or bool(options.get("skip_kusanagi_leave_choice", false)):
        return events
    if row != "front":
        return events
    if str(instance.definition_id) != "takamagahara_s01_0417":
        return events
    if not bool(instance.flags.get("kusanagi_leave_choice_enabled", false)):
        return events
    var card_id = str(instance.instance_id)
    if card_id.is_empty() or _has_pending_kusanagi_leave_choice(state, card_id):
        return events
    return _request_option_choice(state, player_id, [
        {"id": "yes", "label": "放回牌库顶部"},
        {"id": "no", "label": "按原效果离场"}
    ], "草薙剑：离开前排时，是否改为放回牌库顶部？", "kusanagi_leave_to_top_choice", {
        "card_id": card_id,
        "player_id": player_id,
        "row": row,
        "col": col,
        "fallback_action": fallback_action,
        "battle_options": options.duplicate(true)
    }, command_id)

static func _begin_battlefield_leave(state, player_id: int, row: String, col: int, command_id: String, leave_target: String, options: Dictionary = {}) -> Dictionary:
    var player = state.players[player_id]
    var slot = player.get_slot(row, col)
    var events: Array[GameEvent] = []
    if slot == null or slot.occupant.is_empty():
        return {"blocked": true, "events": events}
    var card_id = str(slot.occupant)
    var instance = state.card_instances.get(card_id)
    if instance != null and int(instance.flags.get("sunwukong_master_controller", -1)) >= 0:
        slot.occupant = ""
        return {"blocked": true, "events": _maybe_revert_master_fighter(state, card_id, "battle_%s" % row, command_id)}
    if not _leave_ignores_interceptors(options):
        var leave_choice = _maybe_request_kusanagi_leave_choice(state, instance, player_id, row, col, command_id, leave_target, options)
        if not leave_choice.is_empty():
            return {"blocked": true, "events": leave_choice}
    return {
        "blocked": false,
        "events": events,
        "player": player,
        "slot": slot,
        "card_id": card_id,
        "instance": instance
    }

static func move_battlefield_to_grave(state, player_id: int, row: String, col: int, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var leave_context = _begin_battlefield_leave(state, player_id, row, col, command_id, "grave", options)
    if bool(leave_context.get("blocked", false)):
        return leave_context.get("events", [])
    var slot = leave_context.get("slot")
    var events: Array[GameEvent] = leave_context.get("events", [])
    var card_id = str(leave_context.get("card_id", ""))
    var instance = leave_context.get("instance")
    var unpreventable_leave := _leave_is_unpreventable(options)
    if not unpreventable_leave:
        var olympus_lethal_choice = _maybe_request_olympus_lethal_choice(state, instance, player_id, row, col, command_id, options)
        if not olympus_lethal_choice.is_empty():
            return olympus_lethal_choice
        if instance != null and int(instance.flags.get("cannot_die_until_turn_end_turn", -1)) == state.turn_number:
            var prevented = GameEvent.create(state.next_event_id(), "CardDeathPrevented", player_id, {
                "card_id": card_id,
                "row": row,
                "col": col
            })
            prevented.created_by_command = command_id
            state.event_log.append(prevented)
            events.append(prevented)
            return events
        if instance != null \
            and int(instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) >= 0 \
            and not bool(instance.flags.get("cannot_die_until_next_own_turn_start_used", false)):
            instance.flags["cannot_die_until_next_own_turn_start_used"] = true
            instance.flags["fixed_power_until_turn_end_turn"] = state.turn_number
            instance.flags["fixed_power_until_turn_end_value"] = 1000
            instance.damage_marked = 0
            var prevented_once = GameEvent.create(state.next_event_id(), "CardDeathPrevented", player_id, {
                "card_id": card_id,
                "row": row,
                "col": col,
                "replacement": "set_power_to_1000"
            })
            prevented_once.created_by_command = command_id
            state.event_log.append(prevented_once)
            events.append(prevented_once)
            var replacement = GameEvent.create(state.next_event_id(), "ReplacementEffectApplied", player_id, {
                "card_id": card_id,
                "effect": "cannot_die_once_until_next_own_turn_start",
                "power": 1000
            })
            replacement.created_by_command = command_id
            state.event_log.append(replacement)
            events.append(replacement)
            return events
        var horemheb_substitute = _try_suncity_horemheb_substitute(state, instance, player_id, row, col, command_id, options)
        if not horemheb_substitute.is_empty():
            return horemheb_substitute
        var bijie_excalibur_substitute = _try_bijie_excalibur_substitute(state, instance, player_id, row, col, command_id, options)
        if not bijie_excalibur_substitute.is_empty():
            return bijie_excalibur_substitute
    events.append_array(_detach_attached_underlay_token(state, card_id, instance, command_id, "leave_battlefield_to_grave", options))
    events.append_array(_release_attached_cards_to_grave(state, card_id, instance, command_id, "leave_battlefield_to_grave", options))
    slot.occupant = ""
    _track_suncity_tomb_leave(state, instance)
    var owner_player = state.players[int(instance.owner)]
    owner_player.grave.add_card_to_top(card_id)
    instance.zone = "grave"
    instance.position = {}
    instance.face = "face_up"
    instance.controller = int(instance.owner)
    instance.flags.erase("manifested_power")
    instance.flags.erase("manifested_traits")
    instance.flags.erase("kusanagi_leave_choice_enabled")
    if bool(options.get("emit_died", true)):
        var died_payload = {"card_id": card_id, "row": row, "col": col}
        for key in options.keys():
            if key == "emit_died":
                continue
            died_payload[key] = options[key]
        var died = GameEvent.create(state.next_event_id(), "CardDied", player_id, _payload_with_option_flags(died_payload, options))
        died.created_by_command = command_id
        state.event_log.append(died)
        events.append(died)
    var moved = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, _payload_with_option_flags({"card_id": card_id, "from": "battle_%s" % row, "to": "grave"}, options))
    moved.created_by_command = command_id
    state.event_log.append(moved)
    events.append(moved)
    events.append_array(_restore_overlay_base_to_slot(state, slot, card_id, command_id))
    return events

static func _try_bijie_excalibur_substitute(state, instance, player_id: int, row: String, col: int, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    if instance == null:
        return events
    if not bool(instance.flags.get("bijie_excalibur_substitute_enabled", false)):
        return events
    var token_id = str(instance.flags.get("attached_underlay_token_id", ""))
    if token_id.is_empty():
        return events
    var slot = state.players[player_id].get_slot(row, col)
    if slot == null:
        return events
    if str(slot.cover) == token_id:
        slot.cover = ""
    instance.flags.erase("attached_underlay_token_id")
    instance.flags.erase("persistent_power_bonus")
    instance.flags.erase("persistent_keywords")
    if state.card_instances.has(token_id):
        state.card_instances.erase(token_id)
    var prevented = GameEvent.create(state.next_event_id(), "CardDeathPrevented", player_id, {
        "card_id": str(instance.instance_id),
        "row": row,
        "col": col,
        "replacement": "bijie_excalibur_substitute"
    })
    prevented.created_by_command = command_id
    state.event_log.append(prevented)
    events.append(prevented)
    var replacement = GameEvent.create(state.next_event_id(), "ReplacementEffectApplied", player_id, {
        "card_id": str(instance.instance_id),
        "effect": "bijie_excalibur_substitute",
        "substitute_card_id": token_id
    })
    replacement.created_by_command = command_id
    state.event_log.append(replacement)
    events.append(replacement)
    return events

static func return_battlefield_to_hand(state, player_id: int, row: String, col: int, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var leave_context = _begin_battlefield_leave(state, player_id, row, col, command_id, "hand", options)
    if bool(leave_context.get("blocked", false)):
        return leave_context.get("events", [])
    var slot = leave_context.get("slot")
    var events: Array[GameEvent] = leave_context.get("events", [])
    var card_id = str(leave_context.get("card_id", ""))
    var instance = leave_context.get("instance")
    if instance == null:
        return events
    slot.occupant = ""
    if _is_sun_city_gravebound_instance(instance) and not _leave_is_unpreventable(options):
        return move_card_to_grave(state, card_id, "battle_%s" % row, command_id)
    events.append_array(_detach_attached_underlay_token(state, card_id, instance, command_id, "leave_battlefield_to_hand", options))
    events.append_array(_release_attached_cards_to_grave(state, card_id, instance, command_id, "leave_battlefield_to_hand", options))
    events.append_array(_release_attached_cards_to_grave(state, card_id, instance, command_id, "leave_battlefield_to_deck", options))
    _track_suncity_tomb_leave(state, instance)
    var owner_player = state.players[int(instance.owner)]
    owner_player.hand.add_card(card_id)
    instance.zone = "hand"
    instance.position = {}
    instance.controller = instance.owner
    instance.orientation = "active"
    instance.face = "face_up"
    instance.damage_marked = 0
    instance.has_attacked_this_turn = false
    instance.flags.erase("manifested_power")
    instance.flags.erase("manifested_traits")
    instance.flags.erase("kusanagi_leave_choice_enabled")
    var returned_event = GameEvent.create(state.next_event_id(), "CardReturnedToHand", int(instance.owner), _payload_with_option_flags({
        "card_id": card_id,
        "from": "battle_%s" % row,
        "to": "hand"
    }, options))
    returned_event.created_by_command = command_id
    state.event_log.append(returned_event)
    events.append(returned_event)
    events.append_array(_restore_overlay_base_to_slot(state, slot, card_id, command_id))
    return events

static func return_battlefield_to_deck_bottom(state, player_id: int, row: String, col: int, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var leave_context = _begin_battlefield_leave(state, player_id, row, col, command_id, "deck_bottom", options)
    if bool(leave_context.get("blocked", false)):
        return leave_context.get("events", [])
    var slot = leave_context.get("slot")
    var events: Array[GameEvent] = leave_context.get("events", [])
    var card_id = str(leave_context.get("card_id", ""))
    var instance = leave_context.get("instance")
    if instance == null:
        return events
    slot.occupant = ""
    if _is_sun_city_gravebound_instance(instance) and not _leave_is_unpreventable(options):
        return move_card_to_grave(state, card_id, "battle_%s" % row, command_id)
    _track_suncity_tomb_leave(state, instance)
    var owner_player = state.players[int(instance.owner)]
    owner_player.deck.add_card(card_id)
    instance.zone = "deck"
    instance.position = {}
    instance.controller = instance.owner
    instance.orientation = "active"
    instance.face = "face_down"
    instance.damage_marked = 0
    instance.has_attacked_this_turn = false
    instance.flags.erase("manifested_power")
    instance.flags.erase("manifested_traits")
    instance.flags.erase("kusanagi_leave_choice_enabled")
    var returned_event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", int(instance.owner), _payload_with_option_flags({
        "card_id": card_id,
        "from": "battle_%s" % row,
        "to": "deck_bottom"
    }, options))
    returned_event.created_by_command = command_id
    state.event_log.append(returned_event)
    events.append(returned_event)
    events.append_array(_restore_overlay_base_to_slot(state, slot, card_id, command_id))
    return events

static func return_battlefield_to_deck_top(state, player_id: int, row: String, col: int, command_id: String = "") -> Array[GameEvent]:
    var player = state.players[player_id]
    var slot = player.get_slot(row, col)
    var events: Array[GameEvent] = []
    if slot == null or slot.occupant.is_empty():
        return events
    var card_id = slot.occupant
    slot.occupant = ""
    var instance = state.card_instances.get(card_id)
    if instance == null:
        return events
    if int(instance.flags.get("sunwukong_master_controller", -1)) >= 0:
        return _maybe_revert_master_fighter(state, card_id, "battle_%s" % row, command_id)
    _track_suncity_tomb_leave(state, instance)
    var owner_player = state.players[int(instance.owner)]
    owner_player.deck.cards.push_front(card_id)
    instance.zone = "deck"
    instance.position = {}
    instance.controller = instance.owner
    instance.orientation = "active"
    instance.face = "face_down"
    instance.damage_marked = 0
    instance.has_attacked_this_turn = false
    instance.flags.erase("manifested_power")
    instance.flags.erase("manifested_traits")
    instance.flags.erase("kusanagi_leave_choice_enabled")
    var returned_event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", int(instance.owner), {
        "card_id": card_id,
        "from": "battle_%s" % row,
        "to": "deck_top"
    })
    returned_event.created_by_command = command_id
    state.event_log.append(returned_event)
    events.append(returned_event)
    events.append_array(_restore_overlay_base_to_slot(state, slot, card_id, command_id))
    return events

static func discard_from_hand(state, player_id: int, count: int, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    for _i in range(max(0, count)):
        if player.hand.cards.is_empty():
            break
        var card_id = player.hand.cards.pop_front()
        player.grave.add_card_to_top(card_id)
        var instance = state.card_instances.get(card_id)
        if instance != null:
            instance.zone = "grave"
            instance.position = {}
            instance.face = "face_up"
        var discard_event = GameEvent.create(state.next_event_id(), "CardDiscarded", player_id, _payload_with_option_flags({
            "card_id": card_id,
            "from": "hand",
            "to": "grave"
        }, options))
        discard_event.created_by_command = command_id
        state.event_log.append(discard_event)
        events.append(discard_event)
        var moved_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, _payload_with_option_flags({
            "card_id": card_id,
            "from": "hand",
            "to": "grave"
        }, options))
        moved_event.created_by_command = command_id
        state.event_log.append(moved_event)
        events.append(moved_event)
    return events

static func discard_specific_from_hand(state, player_id: int, card_ids: Array[String], command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    for card_id in card_ids:
        if not player.hand.cards.has(card_id):
            continue
        player.hand.remove_card(card_id)
        player.grave.add_card_to_top(card_id)
        var instance = state.card_instances.get(card_id)
        if instance != null:
            instance.zone = "grave"
            instance.position = {}
            instance.face = "face_up"
        var discard_event = GameEvent.create(state.next_event_id(), "CardDiscarded", player_id, _payload_with_option_flags({
            "card_id": card_id,
            "from": "hand",
            "to": "grave"
        }, options))
        discard_event.created_by_command = command_id
        state.event_log.append(discard_event)
        events.append(discard_event)
        var moved_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, _payload_with_option_flags({
            "card_id": card_id,
            "from": "hand",
            "to": "grave"
        }, options))
        moved_event.created_by_command = command_id
        state.event_log.append(moved_event)
        events.append(moved_event)
    return events

static func move_card_to_grave(state, card_id: String, from_zone: String, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    var instance = state.card_instances.get(card_id)
    if instance == null:
        return events
    var owner_player = state.players[int(instance.owner)]
    owner_player.grave.add_card_to_top(card_id)
    instance.zone = "grave"
    instance.position = {}
    instance.controller = instance.owner
    instance.orientation = "active"
    instance.face = "face_up"
    instance.damage_marked = 0
    instance.has_attacked_this_turn = false
    var moved_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", int(instance.owner), _payload_with_option_flags({
        "card_id": card_id,
        "from": from_zone,
        "to": "grave"
    }, options))
    moved_event.created_by_command = command_id
    state.event_log.append(moved_event)
    events.append(moved_event)
    return events
