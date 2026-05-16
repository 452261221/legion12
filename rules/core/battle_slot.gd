extends RefCounted
class_name BattleSlot

var owner: int = -1
var row: String = "front"
var col: int = 0
var occupant: String = ""
var cover: String = ""
var flags: Dictionary = {}

func clone() -> BattleSlot:
    var copy = BattleSlot.new()
    copy.owner = owner
    copy.row = row
    copy.col = col
    copy.occupant = occupant
    copy.cover = cover
    copy.flags = flags.duplicate(true)
    return copy
