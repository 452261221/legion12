extends RefCounted
class_name DrawActions

const GameEvent = preload("res://rules/core/game_event.gd")
const MoraleActions = preload("res://rules/actions/morale_actions.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")

static func _payload_with_options(base_payload: Dictionary, options: Dictionary = {}) -> Dictionary:
    var payload: Dictionary = base_payload.duplicate(true)
    for key in ["source_kind", "source_card_id", "source_player_id", "reason", "calamity_id", "suppress_triggers"]:
        if options.has(key):
            payload[key] = options[key]
    return payload

static func _decide_loss_from_empty_deck(state, player_id: int, command_id: String) -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    if state.winner != -1:
        return events
    state.winner = 1 - player_id
    state.loss_reason = "deck_out"
    var event = GameEvent.create(state.next_event_id(), "WinnerDecided", state.winner, {
        "winner": state.winner,
        "loser": player_id,
        "reason": state.loss_reason
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    events.append(event)
    return events

static func draw_cards(state, player_id: int, count: int, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    for _i in range(count):
        var card_id = player.deck.take_top()
        if card_id.is_empty():
            if command_id != "setup" and str(state.rules_config.get("mode", "demo")) == "formal":
                events.append_array(_decide_loss_from_empty_deck(state, player_id, command_id))
            break
        player.hand.add_card(card_id)
        var instance = state.card_instances[card_id]
        instance.zone = "hand"
        instance.position = {}
        instance.controller = instance.owner
        instance.face = "face_up"
        var event = GameEvent.create(state.next_event_id(), "CardDrawn", player_id, _payload_with_options({
            "card_id": card_id
        }, options))
        event.created_by_command = command_id
        state.event_log.append(event)
        events.append(event)
    return events

static func mill_cards(state, player_id: int, count: int, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    for _i in range(count):
        var card_id = player.deck.take_top()
        if card_id.is_empty():
            break
        player.grave.add_card_to_top(card_id)
        var instance = state.card_instances[card_id]
        instance.zone = "grave"
        instance.position = {}
        var mill_event = GameEvent.create(state.next_event_id(), "CardMilled", player_id, _payload_with_options({
            "card_id": card_id
        }, options))
        mill_event.created_by_command = command_id
        state.event_log.append(mill_event)
        events.append(mill_event)
        var moved_event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, _payload_with_options({
            "card_id": card_id,
            "from": "deck",
            "to": "grave"
        }, options))
        moved_event.created_by_command = command_id
        state.event_log.append(moved_event)
        events.append(moved_event)
    return events

static func search_deck(state, player_id: int, max_look: int, match_rules: Dictionary = {}, count: int = 1, command_id: String = "", choice_context: Dictionary = {}) -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    var looked: Array[String] = []
    var look_count = max(0, max_look)
    var take_count = max(0, count)
    var reorder_remaining_to_bottom = bool(choice_context.get("reorder_remaining_to_bottom", false))
    var deck_size = min(look_count, player.deck.cards.size())
    for index in range(deck_size):
        looked.append(player.deck.cards[index])
    var matching: Array[String] = []
    for card_id in looked:
        if _matches_search_rules(state, card_id, match_rules):
            matching.append(card_id)
    var requires_choice = bool(choice_context.get("always_request_choice", false)) \
        or matching.size() > take_count \
        or (reorder_remaining_to_bottom and take_count > 0 and matching.size() > 0)
    var found: Array[String] = []
    var search_payload = {
        "looked_cards": looked.duplicate(),
        "found_cards": found.duplicate(),
        "max_look": look_count,
        "match_rules": match_rules.duplicate(true),
        "requires_choice": requires_choice
    }
    if not requires_choice:
        for card_id in matching:
            if found.size() >= take_count:
                break
            found.append(card_id)
        search_payload["found_cards"] = found.duplicate()
        _move_cards_from_deck_to_hand(state, player_id, found, command_id, events, choice_context)
        var follow_up_action = _build_search_follow_up_action(choice_context, found, player_id)
        var remaining = _ordered_difference(looked, found)
        if reorder_remaining_to_bottom and remaining.size() > 1:
            var reorder_choice = _create_search_reorder_choice(state, player_id, remaining, {
                "source_instance_id": str(choice_context.get("source_instance_id", "")),
                "follow_up_action": follow_up_action
            })
            state.pending_choices.append(reorder_choice)
            search_payload["reorder_choice_id"] = str(reorder_choice.get("choice_id", ""))
            search_payload["remaining_cards"] = remaining.duplicate()
            var reorder_choice_event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
                "choice_id": str(reorder_choice.get("choice_id", "")),
                "choice_type": "candidate_cards_pick",
                "operation": "search_deck_reorder_bottom",
                "count": remaining.size(),
                "candidate_cards": remaining.duplicate()
            })
            reorder_choice_event.created_by_command = command_id
            state.event_log.append(reorder_choice_event)
            events.append(reorder_choice_event)
        else:
            _move_looked_cards_to_deck_bottom(state, player_id, remaining, command_id, events)
            _append_follow_up_action(state, player_id, follow_up_action, command_id, events, str(choice_context.get("source_instance_id", "")))
    if requires_choice:
        var choice = _create_search_choice(state, player_id, looked, matching, take_count, match_rules, choice_context)
        state.pending_choices.append(choice)
        search_payload["choice_id"] = str(choice.get("choice_id", ""))
        search_payload["candidate_cards"] = choice.get("candidate_card_ids", []).duplicate()
    var search_event = GameEvent.create(state.next_event_id(), "DeckSearched", player_id, search_payload)
    search_event.created_by_command = command_id
    state.event_log.append(search_event)
    events.push_front(search_event)
    if requires_choice:
        var choice_event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
            "choice_id": str(state.pending_choices.back().get("choice_id", "")),
            "choice_type": "candidate_cards_pick",
            "operation": "search_deck",
            "count": take_count,
            "candidate_cards": matching.duplicate(),
            "looked_cards": looked.duplicate()
        })
        choice_event.created_by_command = command_id
        state.event_log.append(choice_event)
        events.append(choice_event)
    return events

static func search_top_for_artifact_and_named_legion(state, player_id: int, max_look: int, artifact_match_rules: Dictionary, legion_match_rules: Dictionary, command_id: String = "", choice_context: Dictionary = {}) -> Array[GameEvent]:
    var player = state.players[player_id]
    var events: Array[GameEvent] = []
    var looked: Array[String] = []
    var deck_size = min(max(0, max_look), player.deck.cards.size())
    for index in range(deck_size):
        looked.append(player.deck.cards[index])
    var artifact_candidates: Array[String] = []
    var legion_candidates: Array[String] = []
    for card_id in looked:
        if _matches_search_rules(state, card_id, artifact_match_rules):
            artifact_candidates.append(card_id)
        if _matches_search_rules(state, card_id, legion_match_rules):
            legion_candidates.append(card_id)
    var search_payload = {
        "looked_cards": looked.duplicate(),
        "artifact_candidates": artifact_candidates.duplicate(),
        "named_legion_candidates": legion_candidates.duplicate(),
        "max_look": deck_size,
        "requires_choice": true
    }
    if not looked.is_empty():
        var reveal_event = GameEvent.create(state.next_event_id(), "CardsRevealedToOpponent", 1 - player_id, {
            "revealing_player_id": player_id,
            "title": str(choice_context.get("reveal_title", "武运在天：向对方展示牌库顶部5张牌")),
            "card_ids": looked.duplicate()
        })
        reveal_event.created_by_command = command_id
        state.event_log.append(reveal_event)
        events.append(reveal_event)
    var required_count = 0
    if not artifact_candidates.is_empty():
        required_count += 1
    if not legion_candidates.is_empty():
        required_count += 1
    if required_count <= 0:
        if looked.size() > 1:
            var reorder_choice = _create_search_reorder_choice(state, player_id, looked, {
                "source_instance_id": str(choice_context.get("source_instance_id", "")),
                "follow_up_action": choice_context.get("follow_up_action", {}).duplicate(true)
            })
            state.pending_choices.append(reorder_choice)
            search_payload["reorder_choice_id"] = str(reorder_choice.get("choice_id", ""))
            var reorder_event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
                "choice_id": str(reorder_choice.get("choice_id", "")),
                "choice_type": "candidate_cards_pick",
                "operation": "search_deck_reorder_bottom",
                "count": looked.size(),
                "candidate_cards": looked.duplicate()
            })
            reorder_event.created_by_command = command_id
            state.event_log.append(reorder_event)
            events.append(reorder_event)
        else:
            _move_looked_cards_to_deck_bottom(state, player_id, looked, command_id, events)
            _append_follow_up_action(state, player_id, choice_context.get("follow_up_action", {}), command_id, events, str(choice_context.get("source_instance_id", "")))
        search_payload["requires_choice"] = false
        var empty_search_event = GameEvent.create(state.next_event_id(), "DeckSearched", player_id, search_payload)
        empty_search_event.created_by_command = command_id
        state.event_log.append(empty_search_event)
        events.push_front(empty_search_event)
        return events
    var choice = {
        "choice_id": state.next_choice_id(),
        "type": "candidate_cards_pick",
        "title": "选择加入手牌的圣物与上杉谦信",
        "player_id": player_id,
        "count": required_count,
        "looked_cards": looked.duplicate(),
        "candidate_card_ids": _merge_unique_cards(artifact_candidates, legion_candidates),
        "operation": "search_top_for_artifact_and_named_legion",
        "source_instance_id": str(choice_context.get("source_instance_id", "")),
        "source_kind": str(choice_context.get("source_kind", "")),
        "source_card_id": str(choice_context.get("source_card_id", "")),
        "source_player_id": int(choice_context.get("source_player_id", player_id)),
        "follow_up_action": choice_context.get("follow_up_action", {}).duplicate(true),
        "context": {
            "artifact_candidates": artifact_candidates.duplicate(),
            "named_legion_candidates": legion_candidates.duplicate(),
            "reorder_remaining_to_bottom": true,
            "requires_confirm": true,
            "hint_text": "先选择最多1张圣物和最多1张上杉谦信加入手牌，再点击确认；同类牌只能选择1张。",
            "top_hint_text": "武运在天：选择1张圣物和1张上杉谦信；若某类不存在，则只选存在的那一类。"
        }
    }
    state.pending_choices.append(choice)
    search_payload["choice_id"] = str(choice.get("choice_id", ""))
    var search_event = GameEvent.create(state.next_event_id(), "DeckSearched", player_id, search_payload)
    search_event.created_by_command = command_id
    state.event_log.append(search_event)
    events.append(search_event)
    var choice_event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
        "choice_id": str(choice.get("choice_id", "")),
        "choice_type": "candidate_cards_pick",
        "operation": "search_top_for_artifact_and_named_legion",
        "count": required_count,
        "candidate_cards": choice.get("candidate_card_ids", []).duplicate(),
        "looked_cards": looked.duplicate()
    })
    choice_event.created_by_command = command_id
    state.event_log.append(choice_event)
    events.append(choice_event)
    return events

static func resolve_search_choice(state, choice: Dictionary, selected_card_ids: Array[String], command_id: String = "") -> Array[GameEvent]:
    var player_id = int(choice.get("player_id", -1))
    var events: Array[GameEvent] = []
    if player_id < 0 or player_id >= state.players.size():
        return events
    var resolved: Array[String] = []
    for card_id in selected_card_ids:
        if resolved.has(card_id):
            continue
        resolved.append(card_id)
    var resolve_event = GameEvent.create(state.next_event_id(), "ChoiceResolved", player_id, {
        "choice_id": str(choice.get("choice_id", "")),
        "choice_type": str(choice.get("type", "")),
        "selected_card_ids": resolved.duplicate()
    })
    resolve_event.created_by_command = command_id
    state.event_log.append(resolve_event)
    events.append(resolve_event)
    if str(choice.get("operation", "")) == "search_deck_reorder_bottom":
        _move_looked_cards_to_deck_bottom(state, player_id, resolved, command_id, events)
        _append_follow_up_action(state, player_id, choice.get("follow_up_action", {}), command_id, events, str(choice.get("source_instance_id", "")))
        return events
    if str(choice.get("operation", "")) == "search_top_for_artifact_and_named_legion":
        _move_cards_from_deck_to_hand(state, player_id, resolved, command_id, events, choice)
        var remaining = _ordered_difference(choice.get("looked_cards", []), resolved)
        if remaining.size() > 1:
            var reorder_choice = _create_search_reorder_choice(state, player_id, remaining, {
                "source_instance_id": str(choice.get("source_instance_id", "")),
                "follow_up_action": choice.get("follow_up_action", {}).duplicate(true)
            })
            state.pending_choices.append(reorder_choice)
            var reorder_event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
                "choice_id": str(reorder_choice.get("choice_id", "")),
                "choice_type": "candidate_cards_pick",
                "operation": "search_deck_reorder_bottom",
                "count": remaining.size(),
                "candidate_cards": remaining.duplicate()
            })
            reorder_event.created_by_command = command_id
            state.event_log.append(reorder_event)
            events.append(reorder_event)
            return events
        _move_looked_cards_to_deck_bottom(state, player_id, remaining, command_id, events)
        _append_follow_up_action(state, player_id, choice.get("follow_up_action", {}), command_id, events, str(choice.get("source_instance_id", "")))
        return events
    _move_cards_from_deck_to_hand(state, player_id, resolved, command_id, events, choice)
    var follow_up_action = _build_search_follow_up_action(choice, resolved, player_id)
    var remaining = _ordered_difference(choice.get("looked_cards", []), resolved)
    if bool(choice.get("reorder_remaining_to_bottom", false)) and remaining.size() > 1:
        var reorder_choice = _create_search_reorder_choice(state, player_id, remaining, {
            "source_instance_id": str(choice.get("source_instance_id", "")),
            "follow_up_action": follow_up_action
        })
        state.pending_choices.append(reorder_choice)
        var reorder_event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
            "choice_id": str(reorder_choice.get("choice_id", "")),
            "choice_type": "candidate_cards_pick",
            "operation": "search_deck_reorder_bottom",
            "count": remaining.size(),
            "candidate_cards": remaining.duplicate()
        })
        reorder_event.created_by_command = command_id
        state.event_log.append(reorder_event)
        events.append(reorder_event)
        return events
    _move_looked_cards_to_deck_bottom(state, player_id, remaining, command_id, events)
    _append_follow_up_action(state, player_id, follow_up_action, command_id, events, str(choice.get("source_instance_id", "")))
    return events

static func cancel_search_choice(state, choice: Dictionary, command_id: String = "") -> Array[GameEvent]:
    var player_id = int(choice.get("player_id", -1))
    var events: Array[GameEvent] = []
    if player_id < 0 or player_id >= state.players.size():
        return events
    var operation := str(choice.get("operation", ""))
    var resolve_event = GameEvent.create(state.next_event_id(), "ChoiceResolved", player_id, {
        "choice_id": str(choice.get("choice_id", "")),
        "choice_type": str(choice.get("type", "")),
        "cancelled": true
    })
    resolve_event.created_by_command = command_id
    state.event_log.append(resolve_event)
    events.append(resolve_event)
    if operation == "search_deck":
        var looked_cards = _string_array_from_variant_array(choice.get("looked_cards", []))
        var follow_up_action = _build_search_follow_up_action(choice, [], player_id)
        _move_looked_cards_to_deck_bottom(state, player_id, looked_cards, command_id, events)
        _append_follow_up_action(state, player_id, follow_up_action, command_id, events, str(choice.get("source_instance_id", "")))
        return events
    if operation == "search_deck_reorder_bottom":
        var remaining = _string_array_from_variant_array(choice.get("candidate_card_ids", []))
        _move_looked_cards_to_deck_bottom(state, player_id, remaining, command_id, events)
        _append_follow_up_action(state, player_id, choice.get("follow_up_action", {}), command_id, events, str(choice.get("source_instance_id", "")))
    return events

static func _create_search_choice(state, player_id: int, looked: Array[String], matching: Array[String], count: int, match_rules: Dictionary, choice_context: Dictionary) -> Dictionary:
    return {
        "choice_id": state.next_choice_id(),
        "type": "candidate_cards_pick",
        "title": "选择加入手牌的卡牌",
        "player_id": player_id,
        "count": count,
        "looked_cards": looked.duplicate(),
        "candidate_card_ids": matching.duplicate(),
        "operation": "search_deck",
        "match_rules": match_rules.duplicate(true),
        "source_instance_id": str(choice_context.get("source_instance_id", "")),
        "effect_id": str(choice_context.get("effect_id", "")),
        "effect_type": str(choice_context.get("effect_type", "")),
        "stack_id": str(choice_context.get("stack_id", "")),
        "source_kind": str(choice_context.get("source_kind", "")),
        "source_card_id": str(choice_context.get("source_card_id", "")),
        "source_player_id": int(choice_context.get("source_player_id", player_id)),
        "reorder_remaining_to_bottom": bool(choice_context.get("reorder_remaining_to_bottom", false)),
        "follow_up_action": choice_context.get("follow_up_action", {}).duplicate(true)
    }

static func _create_search_reorder_choice(state, player_id: int, remaining: Array[String], choice_context: Dictionary) -> Dictionary:
    return {
        "choice_id": state.next_choice_id(),
        "type": "candidate_cards_pick",
        "title": "选择其余卡牌返回牌库底部的顺序",
        "player_id": player_id,
        "count": remaining.size(),
        "candidate_card_ids": remaining.duplicate(),
        "operation": "search_deck_reorder_bottom",
        "source_instance_id": str(choice_context.get("source_instance_id", "")),
        "follow_up_action": choice_context.get("follow_up_action", {}).duplicate(true)
    }

static func _move_cards_from_deck_to_hand(state, player_id: int, card_ids: Array[String], command_id: String, events: Array[GameEvent], options: Dictionary = {}) -> void:
    var player = state.players[player_id]
    for card_id in card_ids:
        if card_id.is_empty():
            continue
        if not player.deck.remove_card(card_id):
            continue
        player.hand.add_card(card_id)
        var instance = state.card_instances.get(card_id)
        if instance != null:
            instance.zone = "hand"
            instance.position = {}
            instance.controller = instance.owner
            instance.face = "face_up"
        var tutor_event = GameEvent.create(state.next_event_id(), "CardTutored", player_id, _payload_with_options({
            "card_id": card_id,
            "from": "deck",
            "to": "hand"
        }, options))
        tutor_event.created_by_command = command_id
        state.event_log.append(tutor_event)
        events.append(tutor_event)

static func _move_looked_cards_to_deck_bottom(state, player_id: int, card_ids: Array, command_id: String, events: Array[GameEvent]) -> void:
    var player = state.players[player_id]
    for raw_card_id in card_ids:
        var card_id = str(raw_card_id)
        if card_id.is_empty():
            continue
        if not player.deck.remove_card(card_id):
            continue
        player.deck.cards.append(card_id)
        var instance = state.card_instances.get(card_id)
        if instance != null:
            instance.zone = "deck"
            instance.position = {}
        var event = GameEvent.create(state.next_event_id(), "CardReturnedToDeck", player_id, {
            "card_id": card_id,
            "from": "deck_look",
            "to": "deck_bottom"
        })
        event.created_by_command = command_id
        state.event_log.append(event)
        events.append(event)

static func _append_follow_up_action(state, player_id: int, follow_up_action, command_id: String, events: Array[GameEvent], source_instance_id: String = "") -> void:
    if not (follow_up_action is Dictionary) or follow_up_action.is_empty():
        return
    match str(follow_up_action.get("action", "")):
        "reveal_cards_to_opponent":
            events.append_array(_reveal_cards_to_opponent(state, player_id, follow_up_action, command_id))
        "ready_spent_morale":
            events.append_array(MoraleActions.ready_spent_morale(state, player_id, int(follow_up_action.get("count", 1)), command_id))
            _append_follow_up_action(state, player_id, follow_up_action.get("follow_up_action", {}), command_id, events, source_instance_id)
        "shuffle_deck":
            events.append_array(_shuffle_deck(state, player_id, command_id))
            _append_follow_up_action(state, player_id, follow_up_action.get("follow_up_action", {}), command_id, events, source_instance_id)
        "heal_master":
            events.append_array(_heal_master(state, player_id, int(follow_up_action.get("amount", 0)), command_id))
            _append_follow_up_action(state, player_id, follow_up_action.get("follow_up_action", {}), command_id, events, source_instance_id)
        "prepare_next_played_legion_cost_modifier":
            events.append_array(_prepare_next_played_legion_cost_modifier(state, player_id, follow_up_action, command_id, source_instance_id))
            _append_follow_up_action(state, player_id, follow_up_action.get("follow_up_action", {}), command_id, events, source_instance_id)
        "prepare_next_played_legion_keyword":
            events.append_array(_prepare_next_played_legion_keyword(state, player_id, follow_up_action, command_id, source_instance_id))
            _append_follow_up_action(state, player_id, follow_up_action.get("follow_up_action", {}), command_id, events, source_instance_id)
        "send_source_to_grave":
            events.append_array(_send_source_to_grave(state, source_instance_id, command_id))
            _append_follow_up_action(state, player_id, follow_up_action.get("follow_up_action", {}), command_id, events, source_instance_id)
        "deploy_matching_legion_from_hand":
            events.append_array(_request_deploy_matching_legion_from_hand(state, player_id, follow_up_action, command_id))
        "choose_option_with_cost":
            events.append_array(_request_option_with_shared_cost(state, player_id, follow_up_action, command_id, source_instance_id))


static func _build_search_follow_up_action(choice_context: Dictionary, found_cards: Array[String], player_id: int) -> Dictionary:
    var follow_up_action: Dictionary = choice_context.get("follow_up_action", {}).duplicate(true)
    if found_cards.is_empty():
        if str(follow_up_action.get("action", "")) == "reveal_found_cards_to_opponent":
            return follow_up_action.get("follow_up_action", {}).duplicate(true)
        return follow_up_action
    if str(follow_up_action.get("action", "")) == "reveal_found_cards_to_opponent":
        return {
            "action": "reveal_cards_to_opponent",
            "player_id": int(follow_up_action.get("player_id", 1 - player_id)),
            "card_ids": found_cards.duplicate(),
            "title": str(follow_up_action.get("title", "向对方展示加入手牌的卡牌")),
            "follow_up_action": follow_up_action.get("follow_up_action", {}).duplicate(true)
        }
    if str(choice_context.get("effect_id", "")) != "oiran_search":
        return follow_up_action
    return {
        "action": "reveal_cards_to_opponent",
        "player_id": 1 - player_id,
        "card_ids": found_cards.duplicate(),
        "title": "花魁的馈赠：向对方展示加入手牌的卡牌",
        "follow_up_action": follow_up_action
    }


static func _reveal_cards_to_opponent(state, player_id: int, follow_up_action: Dictionary, command_id: String) -> Array[GameEvent]:
    var opponent_player_id := int(follow_up_action.get("player_id", 1 - player_id))
    var card_ids := _string_array_from_variant_array(follow_up_action.get("card_ids", []))
    var events: Array[GameEvent] = []
    if opponent_player_id < 0 or opponent_player_id >= state.players.size() or card_ids.is_empty():
        _append_follow_up_action(state, player_id, follow_up_action.get("follow_up_action", {}), command_id, events)
        return events
    var event = GameEvent.create(state.next_event_id(), "CardsRevealedToOpponent", opponent_player_id, {
        "revealing_player_id": player_id,
        "title": str(follow_up_action.get("title", "向对方展示的卡牌")),
        "card_ids": card_ids.duplicate()
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    events.append(event)
    _append_follow_up_action(state, player_id, follow_up_action.get("follow_up_action", {}), command_id, events)
    return events

static func _heal_master(state, player_id: int, amount: int, command_id: String) -> Array[GameEvent]:
    if amount <= 0:
        return []
    var player = state.players[player_id]
    if bool(player.flags.get("master_cannot_heal_for_game", false)):
        return []
    var healed_amount = min(amount, max(0, player.master_max_hp - player.master_hp))
    if healed_amount <= 0:
        return []
    player.master_hp += healed_amount
    var event = GameEvent.create(state.next_event_id(), "MasterHealed", player_id, {
        "amount": healed_amount,
        "current_hp": player.master_hp,
        "max_hp": player.master_max_hp
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func _send_source_to_grave(state, source_instance_id: String, command_id: String) -> Array[GameEvent]:
    if source_instance_id.is_empty():
        return []
    var instance = state.card_instances.get(source_instance_id)
    if instance == null:
        return []
    if str(instance.zone) == "artifact_zone":
        return _send_artifact_to_grave(state, int(instance.controller), source_instance_id, command_id)
    if str(instance.zone).begins_with("battle_"):
        var row = str(instance.position.get("row", ""))
        var col = int(instance.position.get("col", -1))
        if row.is_empty() or col < 0:
            return []
        return ZoneActions.move_battlefield_to_grave(state, int(instance.controller), row, col, command_id)
    return []

static func _send_artifact_to_grave(state, player_id: int, artifact_id: String, command_id: String) -> Array[GameEvent]:
    var player = state.players[player_id]
    if artifact_id.is_empty() or not player.artifact_zone.remove_card(artifact_id):
        return []
    player.grave.add_card_to_top(artifact_id)
    var instance = state.card_instances.get(artifact_id)
    if instance != null:
        instance.zone = "grave"
        instance.position = {}
        instance.orientation = "active"
    var event = GameEvent.create(state.next_event_id(), "CardSentToGrave", player_id, {
        "card_id": artifact_id,
        "from": "artifact_zone",
        "to": "grave"
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func _prepare_next_played_legion_cost_modifier(state, player_id: int, follow_up_action: Dictionary, command_id: String, source_instance_id: String = "") -> Array[GameEvent]:
    var amount = int(follow_up_action.get("amount", 0))
    if amount == 0:
        return []
    var player = state.players[player_id]
    player.flags["next_played_legion_cost_modifier"] = {
        "turn": state.turn_number,
        "amount": amount,
        "definition_id": str(follow_up_action.get("definition_id", "")),
        "max_cost": int(follow_up_action.get("max_cost", -1)),
        "faction": str(follow_up_action.get("faction", ""))
    }
    var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", player_id, {
        "card_id": source_instance_id,
        "buff": "next_played_legion_cost_modifier",
        "amount": amount
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func _prepare_next_played_legion_keyword(state, player_id: int, follow_up_action: Dictionary, command_id: String, source_instance_id: String = "") -> Array[GameEvent]:
    var keyword = str(follow_up_action.get("keyword", ""))
    if keyword.is_empty():
        return []
    var player = state.players[player_id]
    player.flags["next_played_legion_keyword"] = {
        "turn": state.turn_number,
        "keyword": keyword,
        "max_cost": int(follow_up_action.get("max_cost", -1)),
        "definition_id": str(follow_up_action.get("definition_id", ""))
    }
    var event = GameEvent.create(state.next_event_id(), "CardBuffApplied", player_id, {
        "card_id": source_instance_id,
        "buff": "next_played_legion_keyword",
        "keyword": keyword
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func _request_option_with_shared_cost(state, player_id: int, option_action: Dictionary, command_id: String, source_instance_id: String = "") -> Array[GameEvent]:
    var shared_cost = option_action.get("cost", {})
    if not _can_pay_follow_up_cost(state, player_id, shared_cost):
        return []
    var options: Array = []
    var option_payloads := {}
    var raw_options = option_action.get("options", [])
    if not (raw_options is Array):
        return []
    for raw_option in raw_options:
        if not (raw_option is Dictionary):
            continue
        var option_id = str(raw_option.get("id", ""))
        if option_id.is_empty():
            continue
        options.append({
            "id": option_id,
            "label": str(raw_option.get("label", option_id))
        })
        option_payloads[option_id] = {
            "resolution": raw_option.get("resolution", {}).duplicate(true),
            "cost": raw_option.get("cost", {}).duplicate(true)
        }
    if bool(option_action.get("optional", false)):
        options.append({
            "id": "skip",
            "label": str(option_action.get("skip_label", "不发动"))
        })
    if options.is_empty():
        return []
    var choice = {
        "choice_id": state.next_choice_id(),
        "type": "option_pick",
        "title": str(option_action.get("title", "选择以下一项")),
        "player_id": player_id,
        "options": options.duplicate(true),
        "operation": "resolve_option_with_shared_cost",
        "context": {
            "source_instance_id": source_instance_id,
            "shared_cost": shared_cost.duplicate(true) if shared_cost is Dictionary else {},
            "option_payloads": option_payloads.duplicate(true)
        }
    }
    state.pending_choices.append(choice)
    var event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
        "choice_id": str(choice.get("choice_id", "")),
        "choice_type": "option_pick",
        "title": str(choice.get("title", "")),
        "options": options.duplicate(true)
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func _can_pay_follow_up_cost(state, player_id: int, cost) -> bool:
    if not (cost is Dictionary):
        return true
    var morale_cost = int(cost.get("morale", 0))
    if morale_cost > 0 and MoraleActions.count_active_morale(state, player_id) < morale_cost:
        return false
    var discard_cost = int(cost.get("discard_cards", 0))
    if discard_cost > 0 and state.get_player(player_id).hand.cards.size() < discard_cost:
        return false
    return true

static func _master_faction_for_player(state, player_id: int) -> String:
    if player_id < 0 or player_id >= state.players.size():
        return ""
    var master_definition_id = str(state.get_player(player_id).master_definition_id)
    if master_definition_id.is_empty():
        return ""
    return master_definition_id.split("_", false, 1)[0]

static func _player_treats_neutral_as_master_faction(state, player_id: int) -> bool:
    if player_id < 0 or player_id >= state.players.size():
        return false
    for card_id in state.get_player(player_id).artifact_zone.cards:
        var instance = state.card_instances.get(str(card_id))
        if instance != null and str(instance.definition_id) == "neutral_s02_0008":
            return true
    return false

static func _definition_matches_required_faction_for_player(state, player_id: int, definition, required_faction: String) -> bool:
    if required_faction.is_empty():
        return true
    if definition == null:
        return false
    var card_faction := str(definition.faction)
    if card_faction == required_faction:
        return true
    if card_faction != "neutral" or not _player_treats_neutral_as_master_faction(state, player_id):
        return false
    return _master_faction_for_player(state, player_id) == required_faction

static func _ordered_difference(source_cards, removed_cards: Array[String]) -> Array[String]:
    var result: Array[String] = []
    var removed_lookup := {}
    for card_id in removed_cards:
        removed_lookup[card_id] = true
    if not (source_cards is Array):
        return result
    for raw_card_id in source_cards:
        var card_id = str(raw_card_id)
        if card_id.is_empty() or removed_lookup.has(card_id):
            continue
        result.append(card_id)
    return result

static func _string_array_from_variant_array(values) -> Array[String]:
    var result: Array[String] = []
    if not (values is Array):
        return result
    for value in values:
        var as_text := str(value)
        if as_text.is_empty():
            continue
        result.append(as_text)
    return result

static func _merge_unique_cards(first: Array[String], second: Array[String]) -> Array[String]:
    var result: Array[String] = []
    for card_id in first:
        if not result.has(card_id):
            result.append(card_id)
    for card_id in second:
        if not result.has(card_id):
            result.append(card_id)
    return result

static func _matches_search_rules(state, card_id: String, match_rules: Dictionary) -> bool:
    var instance = state.card_instances.get(card_id)
    if instance == null:
        return false
    var definition = state.get_definition(instance.definition_id)
    if definition == null:
        return false
    var match_type = str(match_rules.get("type", ""))
    if not match_type.is_empty() and definition.type != match_type:
        return false
    var min_cost = int(match_rules.get("min_cost", -1))
    if min_cost >= 0 and int(definition.cost) < min_cost:
        return false
    var max_cost = int(match_rules.get("max_cost", -1))
    if max_cost >= 0 and int(definition.cost) > max_cost:
        return false
    var match_faction = str(match_rules.get("faction", ""))
    if not _definition_matches_required_faction_for_player(state, int(instance.owner), definition, match_faction):
        return false
    var match_troop_type = str(match_rules.get("troop_type", ""))
    if not match_troop_type.is_empty() and _normalize_troop_type_key(str(definition.troop_type)) != _normalize_troop_type_key(match_troop_type):
        return false
    if bool(match_rules.get("same_faction_as_own_master", false)):
        var master_faction = _master_faction_for_player(state, int(instance.owner))
        if master_faction.is_empty() or not _definition_matches_required_faction_for_player(state, int(instance.owner), definition, master_faction):
            return false
    var max_power = int(match_rules.get("max_power", -1))
    if max_power >= 0 and int(definition.power) > max_power:
        return false
    var match_keyword = str(match_rules.get("keyword", ""))
    if not match_keyword.is_empty() and not definition.keywords.has(match_keyword) and not definition.traits.has(match_keyword):
        return false
    var match_id = str(match_rules.get("id", ""))
    if not match_id.is_empty() and definition.id != match_id:
        return false
    var name_contains = str(match_rules.get("name_contains", ""))
    if not name_contains.is_empty() and str(definition.name).find(name_contains) < 0:
        return false
    var exclude_definition_id = str(match_rules.get("exclude_definition_id", ""))
    if not exclude_definition_id.is_empty() and definition.id == exclude_definition_id:
        return false
    return true

static func _normalize_troop_type_key(raw_troop_type: String) -> String:
    var normalized := raw_troop_type.strip_edges().to_lower()
    match normalized:
        "术师", "mage", "caster", "wizard":
            return "mage"
        "弓手", "archer":
            return "archer"
        "骑兵", "cavalry":
            return "cavalry"
        _:
            return normalized

static func _request_deploy_matching_legion_from_hand(state, player_id: int, filters: Dictionary, command_id: String) -> Array[GameEvent]:
    var candidate_card_ids = _matching_hand_card_ids(state, player_id, filters)
    var slot_options = _battlefield_slot_options(state, player_id)
    if candidate_card_ids.is_empty() or slot_options.is_empty():
        return []
    return _request_candidate_cards_choice(state, player_id, candidate_card_ids, 1, "选择手牌军团活跃登场", "deploy_from_hand_to_battlefield", {
        "slot_options": slot_options.duplicate(true),
        "follow_up_action": filters.get("follow_up_action", {}).duplicate(true)
    }, command_id)

static func _matching_hand_card_ids(state, player_id: int, filters: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for card_id in state.players[player_id].hand.cards:
        var instance = state.card_instances.get(str(card_id))
        if instance == null:
            continue
        var definition = state.get_definition(instance.definition_id)
        if definition == null:
            continue
        var required_type = str(filters.get("type", ""))
        if not required_type.is_empty() and definition.type != required_type:
            continue
        var required_definition_id = str(filters.get("id", ""))
        if not required_definition_id.is_empty() and definition.id != required_definition_id:
            continue
        var required_faction = str(filters.get("faction", ""))
        if not _definition_matches_required_faction_for_player(state, player_id, definition, required_faction):
            continue
        var max_power = int(filters.get("max_power", -1))
        if max_power >= 0 and int(definition.power) > max_power:
            continue
        result.append(str(card_id))
    return result

static func _battlefield_slot_options(state, player_id: int) -> Array:
    var options: Array = []
    var player = state.players[player_id]
    for row in ["front", "back"]:
        for col in range(3):
            var slot = player.get_slot(row, col)
            if slot != null and slot.occupant.is_empty():
                options.append({
                    "id": "%s:%d" % [row, col],
                    "label": "%s排 %d" % ["前" if row == "front" else "后", col + 1],
                    "row": row,
                    "col": col
                })
    return options

static func _request_candidate_cards_choice(state, player_id: int, candidate_card_ids: Array, count: int, title: String, operation: String, context: Dictionary, command_id: String) -> Array[GameEvent]:
    var choice = {
        "choice_id": state.next_choice_id(),
        "type": "candidate_cards_pick",
        "title": title,
        "player_id": player_id,
        "count": count,
        "candidate_card_ids": candidate_card_ids.duplicate(),
        "operation": operation,
        "context": context.duplicate(true)
    }
    state.pending_choices.append(choice)
    var event = GameEvent.create(state.next_event_id(), "ChoiceRequested", player_id, {
        "choice_id": str(choice.get("choice_id", "")),
        "choice_type": "candidate_cards_pick",
        "title": title,
        "count": count,
        "candidate_cards": candidate_card_ids.duplicate()
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]

static func _shuffle_deck(state, player_id: int, command_id: String) -> Array[GameEvent]:
    var cards = state.players[player_id].deck.cards
    for index in range(cards.size() - 1, 0, -1):
        var swap_index: int = state.rng.next_int(index + 1)
        if swap_index == index:
            continue
        var current = cards[index]
        cards[index] = cards[swap_index]
        cards[swap_index] = current
    var event = GameEvent.create(state.next_event_id(), "DeckShuffled", player_id, {
        "player_id": player_id,
        "count": cards.size()
    })
    event.created_by_command = command_id
    state.event_log.append(event)
    return [event]
