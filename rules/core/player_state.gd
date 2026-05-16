extends RefCounted
class_name PlayerState

const BattleSlot = preload("res://rules/core/battle_slot.gd")
const Zone = preload("res://rules/core/zone.gd")

var player_id: int = -1
var name: String = ""
var master_name: String = ""
var master_definition_id: String = ""
var master: Zone
var master_hp: int = 20
var master_max_hp: int = 20
var hand: Zone
var deck: Zone
var grave: Zone
var cost_deck: Zone
var cost_area: Zone
var spent_cost_area: Zone
var artifact_zone: Zone
var trial_zone: Zone
var city_zone: Zone
var battle_front: Array[BattleSlot] = []
var battle_back: Array[BattleSlot] = []
var counters: Dictionary = {}
var flags: Dictionary = {}
var once_per_turn: Dictionary = {}
var once_per_game: Dictionary = {}

func _init(p_player_id: int = -1, p_name: String = ""):
    player_id = p_player_id
    name = p_name
    master = _make_zone("master", "public")
    hand = _make_zone("hand", "private")
    deck = _make_zone("deck", "private")
    grave = _make_zone("grave", "public")
    cost_deck = _make_zone("cost_deck", "private")
    cost_area = _make_zone("cost_area", "public")
    spent_cost_area = _make_zone("spent_cost_area", "public")
    artifact_zone = _make_zone("artifact_zone", "public")
    trial_zone = _make_zone("trial_zone", "public")
    city_zone = _make_zone("city_zone", "public")
    battle_front = _make_slots("front")
    battle_back = _make_slots("back")

func get_slot(row: String, col: int) -> BattleSlot:
    if col < 0 or col > 2:
        return null
    if row == "front":
        return battle_front[col]
    return battle_back[col]

func all_zone_card_ids() -> Array[String]:
    var result: Array[String] = []
    result.append_array(master.cards)
    result.append_array(hand.cards)
    result.append_array(deck.cards)
    result.append_array(grave.cards)
    result.append_array(cost_deck.cards)
    result.append_array(cost_area.cards)
    result.append_array(spent_cost_area.cards)
    result.append_array(artifact_zone.cards)
    result.append_array(trial_zone.cards)
    result.append_array(city_zone.cards)
    for slot in battle_front:
        if not slot.occupant.is_empty():
            result.append(slot.occupant)
        if not slot.cover.is_empty():
            result.append(slot.cover)
    for slot in battle_back:
        if not slot.occupant.is_empty():
            result.append(slot.occupant)
        if not slot.cover.is_empty():
            result.append(slot.cover)
    return result

func _make_zone(kind_name: String, visibility_name: String) -> Zone:
    var zone = Zone.new()
    zone.zone_id = "p%s_%s" % [player_id, kind_name]
    zone.owner = player_id
    zone.kind = kind_name
    zone.visibility = visibility_name
    return zone

func _make_slots(row_name: String) -> Array[BattleSlot]:
    var slots: Array[BattleSlot] = []
    for col in range(3):
        var slot = BattleSlot.new()
        slot.owner = player_id
        slot.row = row_name
        slot.col = col
        slots.append(slot)
    return slots
