extends RefCounted
class_name CombatActions

const GameEvent = preload("res://rules/core/game_event.gd")
const ZoneActions = preload("res://rules/actions/zone_actions.gd")

static func resolve_simple_attack(state, attacker_id: String, defender_id: String, command_id: String = "", options: Dictionary = {}) -> Array[GameEvent]:
    var events: Array[GameEvent] = []
    var attacker = state.card_instances[attacker_id]
    var defender = state.card_instances[defender_id]
    var defender_damage_before = int(defender.damage_marked)
    var support_prevents_death = bool(options.get("support_prevents_death", false))
    var supporter_id = str(options.get("supporter_id", ""))
    var attacker_takes_no_damage = bool(options.get("attacker_takes_no_damage", false))
    var attacker_power = max(0, _current_power(state, attacker_id, attacker_id) + int(options.get("attacker_power_modifier", 0)))
    var defender_power = max(0, _current_power(state, defender_id, attacker_id) + int(options.get("defender_power_modifier", 0)))
    defender.damage_marked += attacker_power
    if not attacker_takes_no_damage:
        attacker.damage_marked += defender_power
    var damage_event = GameEvent.create(state.next_event_id(), "DamageDealt", attacker.controller, {"attacker_id": attacker_id, "defender_id": defender_id, "attacker_power": attacker_power, "defender_power": defender_power})
    damage_event.created_by_command = command_id
    state.event_log.append(damage_event)
    events.append(damage_event)
    if _current_power(state, defender_id) <= 0 and support_prevents_death:
        var support_instance = state.card_instances.get(supporter_id)
        if support_instance != null and support_instance.zone.begins_with("battle_"):
            var support_row := str(support_instance.position.get("row", ""))
            var support_col := int(support_instance.position.get("col", -1))
            if not support_row.is_empty() and support_col >= 0:
                events.append_array(ZoneActions.move_battlefield_to_grave(state, support_instance.controller, support_row, support_col, command_id))
        defender.damage_marked = defender_damage_before
        var support_event = GameEvent.create(state.next_event_id(), "SupportPreventedDeath", defender.controller, {
            "defender_id": defender_id,
            "supporter_id": supporter_id,
            "attacker_id": attacker_id
        })
        support_event.created_by_command = command_id
        state.event_log.append(support_event)
        events.append(support_event)
    elif _current_power(state, defender_id) <= 0:
        var dpos = defender.position
        events.append_array(ZoneActions.move_battlefield_to_grave(state, defender.controller, dpos.get("row", "front"), int(dpos.get("col", 0)), command_id, {
            "source_card_id": attacker_id,
            "source_kind": "attack"
        }))
    if _current_power(state, attacker_id) <= 0:
        var apos = attacker.position
        events.append_array(ZoneActions.move_battlefield_to_grave(state, attacker.controller, apos.get("row", "front"), int(apos.get("col", 0)), command_id, {
            "source_card_id": defender_id,
            "source_kind": "attack"
        }))
    attacker.has_attacked_this_turn = true
    attacker.orientation = "rested"
    return events

static func _current_power(state, card_id: String, attacking_card_id: String = "") -> int:
    var instance = state.card_instances.get(card_id)
    if instance == null:
        return 0
    var modified_power = int(instance.base_power)
    if int(instance.flags.get("manifested_power", 0)) > 0:
        modified_power = int(instance.flags.get("manifested_power", modified_power))
    if int(instance.flags.get("front_attack_power_bonus_turn", -1)) == state.turn_number and str(instance.position.get("row", "")) == "front":
        modified_power += int(instance.flags.get("front_attack_power_bonus_amount", 0))
    if int(instance.flags.get("power_modifier_until_turn_end_turn", -1)) == state.turn_number:
        modified_power += int(instance.flags.get("power_modifier_until_turn_end_amount", 0))
    for modifier in state.continuous_modifiers:
        if not _modifier_applies_to_card(state, modifier, card_id, attacking_card_id):
            continue
        if str(modifier.get("stat", "")) == "power":
            modified_power += int(modifier.get("amount", 0))
    return max(0, modified_power - int(instance.damage_marked))

static func _modifier_applies_to_card(state, modifier: Dictionary, card_id: String, attacking_card_id: String = "") -> bool:
    var source_id = str(modifier.get("source_id", ""))
    var source_instance = state.card_instances.get(source_id)
    var target_instance = state.card_instances.get(card_id)
    if source_instance == null or target_instance == null:
        return false
    if not target_instance.zone.begins_with("battle_"):
        return false
    if bool(modifier.get("only_during_opponent_turn", false)) and source_instance.controller == state.active_player:
        return false
    if bool(modifier.get("exclude_self", false)) and source_id == card_id:
        return false
    if bool(modifier.get("only_when_attacking", false)) and card_id != attacking_card_id:
        return false
    var required_row = str(modifier.get("required_row", ""))
    if not required_row.is_empty() and str(target_instance.position.get("row", "")) != required_row:
        return false
    match str(modifier.get("target_scope", "allied_battlefield")):
        "allied_battlefield":
            return source_instance.controller == target_instance.controller
        "allied_other_battlefield":
            return source_instance.controller == target_instance.controller and source_id != card_id
        "enemy_battlefield":
            return source_instance.controller != target_instance.controller
        "self":
            return source_id == card_id
    return false
