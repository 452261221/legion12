extends RefCounted
class_name Zone

var zone_id: String = ""
var owner: int = -1
var kind: String = ""
var cards: Array[String] = []
var visibility: String = "private"
var ordering: String = "stack"
var capacity: int = -1

func clone() -> Zone:
    var copy = Zone.new()
    copy.zone_id = zone_id
    copy.owner = owner
    copy.kind = kind
    copy.cards = cards.duplicate()
    copy.visibility = visibility
    copy.ordering = ordering
    copy.capacity = capacity
    return copy

func add_card(card_id: String) -> void:
    cards.append(card_id)

func add_card_to_top(card_id: String) -> void:
    cards.push_front(card_id)

func take_top() -> String:
    if cards.is_empty():
        return ""
    return cards.pop_front()

func remove_card(card_id: String) -> bool:
    var index = cards.find(card_id)
    if index == -1:
        return false
    cards.remove_at(index)
    return true

func has_card(card_id: String) -> bool:
    return cards.has(card_id)
