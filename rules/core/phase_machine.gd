extends RefCounted
class_name PhaseMachine

const PHASE_ORDER = ["calamity", "ready", "draw", "morale", "main", "end"]
const FIRST_PHASE = "calamity"
const LAST_PHASE = "end"

static func next_phase(current: String) -> String:
    var index = PHASE_ORDER.find(current)
    if index == -1:
        return PHASE_ORDER[0]
    return PHASE_ORDER[(index + 1) % PHASE_ORDER.size()]

static func get_next_phase_info(current: String) -> Dictionary:
    var next = next_phase(current)
    return {
        "from": current,
        "to": next,
        "passes_turn": next == FIRST_PHASE
    }

static func is_valid_phase(phase_name: String) -> bool:
    return PHASE_ORDER.has(phase_name)

static func is_main_phase(phase_name: String) -> bool:
    return phase_name == "main"

static func can_use_command(command_type: String, phase_name: String) -> bool:
    match command_type:
        "PlayCard", "DeclareAttack", "ActivateEffect", "MoveLegion":
            return is_main_phase(phase_name)
        "ResolveChoice", "ChooseDefense":
            return is_valid_phase(phase_name)
        "PassPriority":
            return is_valid_phase(phase_name)
        "EndPhase":
            return is_valid_phase(phase_name)
        _:
            return false
