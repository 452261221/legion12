extends RefCounted
class_name GameCommand

var command_id: String = ""
var player_id: int = -1
var type: String = ""
var payload: Dictionary = {}
var client_time: int = 0
var source: String = "local"

static func create(p_player_id: int, p_type: String, p_payload: Dictionary = {}) -> GameCommand:
    var command = GameCommand.new()
    command.command_id = "%s_%s" % [p_type, Time.get_unix_time_from_system()]
    command.player_id = p_player_id
    command.type = p_type
    command.payload = p_payload.duplicate(true)
    command.client_time = Time.get_unix_time_from_system()
    return command
