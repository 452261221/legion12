extends RefCounted
class_name CardInstance

var instance_id: String = ""
var definition_id: String = ""
var owner: int = -1
var controller: int = -1
var zone: String = ""
var position: Dictionary = {}
var face: String = "face_up"
var orientation: String = "active"
var visibility: Dictionary = {}
var base_power: int = 0
var damage_marked: int = 0
var temp_modifiers: Array[String] = []
var attached_cards: Array[String] = []
var overlay_cards: Array[String] = []
var entered_turn: int = 0
var has_attacked_this_turn: bool = false
var tags: Array[String] = []
var flags: Dictionary = {}

func current_power() -> int:
    return max(0, base_power - damage_marked)
