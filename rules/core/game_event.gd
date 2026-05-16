extends RefCounted
class_name GameEvent

var event_id: int = 0
var type: String = ""
var player_id: int = -1
var source_id: String = ""
var targets: Array[String] = []
var payload: Dictionary = {}
var created_by_command: String = ""

static func create(p_event_id: int, p_type: String, p_player_id: int = -1, p_payload: Dictionary = {}) -> GameEvent:
    var event = GameEvent.new()
    event.event_id = p_event_id
    event.type = p_type
    event.player_id = p_player_id
    event.payload = p_payload.duplicate(true)
    return event
