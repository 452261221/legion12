extends RefCounted
class_name GameState

const CardDefinition = preload("res://rules/core/card_definition.gd")
const CardInstance = preload("res://rules/core/card_instance.gd")
const GameEvent = preload("res://rules/core/game_event.gd")
const PlayerState = preload("res://rules/core/player_state.gd")
const RngService = preload("res://rules/core/rng.gd")

var game_id: String = "dev_game"
var ruleset_id: String = "dev_ruleset"
var rules_config: Dictionary = {}
var seed: int = 1
var rng: RngService
var initial_decks: Array = []
var players: Array[PlayerState] = []
var active_player: int = 0
var priority_player: int = 0
var turn_number: int = 1
var phase: String = "main"
var step: String = ""
var calamity_value: int = 0
var current_calamity: String = ""
var calamity_deck: Array[String] = []
var calamity_grave: Array[String] = []
var calamity_value_locked: bool = false
var stack: Array[Dictionary] = []
var pending_triggers: Array[Dictionary] = []
var pending_choices: Array[Dictionary] = []
var pending_attack: Dictionary = {}
var continuous_modifiers: Array[Dictionary] = []
var timed_modifiers: Array[Dictionary] = []
var command_log: Array[Dictionary] = []
var event_log: Array[GameEvent] = []
var last_event_id: int = 0
var priority_pass_count: int = 0
var last_stack_id: int = 0
var last_choice_id: int = 0
var winner: int = -1
var loss_reason: String = ""
var card_definitions: Dictionary = {}
var card_instances: Dictionary = {}
var _instance_counter: int = 0

func _init(p_seed: int = 1):
    seed = p_seed
    rng = RngService.new(p_seed)

func next_event_id() -> int:
    last_event_id += 1
    return last_event_id

func next_stack_id() -> String:
    last_stack_id += 1
    return "stack_%04d" % last_stack_id

func next_choice_id() -> String:
    last_choice_id += 1
    return "choice_%04d" % last_choice_id

func register_definition(definition: CardDefinition) -> void:
    card_definitions[definition.id] = definition

func get_definition(definition_id: String) -> CardDefinition:
    return card_definitions.get(definition_id)

func create_instance(definition_id: String, owner: int, controller: int = -1) -> String:
    var definition: CardDefinition = get_definition(definition_id)
    assert(definition != null, "Unknown definition: %s" % definition_id)
    _instance_counter += 1
    var instance = CardInstance.new()
    instance.instance_id = "c_%04d" % _instance_counter
    instance.definition_id = definition_id
    instance.owner = owner
    if controller == -1:
        instance.controller = owner
    else:
        instance.controller = controller
    instance.base_power = definition.power
    card_instances[instance.instance_id] = instance
    return instance.instance_id

func add_player(player_id: int, player_name: String, metadata: Dictionary = {}) -> PlayerState:
    var player = PlayerState.new(player_id, player_name)
    player.master_name = str(metadata.get("master_name", ""))
    player.master_definition_id = str(metadata.get("master_id", ""))
    var starting_master_hp = int(metadata.get("master_hp", player.master_hp))
    player.master_hp = max(0, starting_master_hp)
    player.master_max_hp = max(player.master_hp, int(metadata.get("master_max_hp", player.master_hp)))
    players.append(player)
    return player

func get_player(player_id: int) -> PlayerState:
    return players[player_id]

func build_public_view_model(_viewer_id: int) -> Dictionary:
    var data = {
        "turn_number": turn_number,
        "active_player": active_player,
        "phase": phase,
        "calamity_value": calamity_value,
        "current_calamity": current_calamity,
        "winner": winner,
        "loss_reason": loss_reason,
        "players": []
    }
    for player in players:
        var row = {
            "player_id": player.player_id,
            "name": player.name,
            "master_name": player.master_name,
            "master_id": player.master_definition_id,
            "master_hp": player.master_hp,
            "master_max_hp": player.master_max_hp,
            "hand_count": player.hand.cards.size(),
            "deck_count": player.deck.cards.size(),
            "grave_count": player.grave.cards.size(),
            "cost_count": player.cost_area.cards.size(),
            "rune_count": int(player.counters.get("rune", 0)),
            "trial_count": player.trial_zone.cards.size(),
            "city_count": player.city_zone.cards.size(),
            "front": [],
            "back": []
        }
        for slot in player.battle_front:
            row.front.append(slot.occupant)
        for slot in player.battle_back:
            row.back.append(slot.occupant)
        data.players.append(row)
    return data
