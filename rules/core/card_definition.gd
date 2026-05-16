extends RefCounted
class_name CardDefinition

var id: String = ""
var name: String = ""
var faction: String = "neutral"
var type: String = "legion"
var subtypes: Array[String] = []
var troop_type: String = ""
var cost: int = 0
var power: int = 0
var calamity_level: int = 0
var hp: int = 0
var limit: int = 3
var traits: Array[String] = []
var keywords: Array[String] = []
var effects: Array[Dictionary] = []
var play_options: Array[Dictionary] = []
var text: String = ""
var image_path: String = ""
var source: Dictionary = {}

static func from_dict(data: Dictionary) -> CardDefinition:
	var definition = CardDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.name = str(data.get("name", definition.id))
	definition.faction = str(data.get("faction", "neutral"))
	definition.type = str(data.get("type", "legion"))
	definition.subtypes = _to_string_array(data.get("subtypes", []))
	definition.troop_type = str(data.get("troop_type", ""))
	definition.cost = int(data.get("cost", 0))
	definition.power = int(data.get("power", 0))
	definition.hp = int(data.get("hp", definition.power))
	definition.calamity_level = int(data.get("calamity_level", 0))
	definition.limit = int(data.get("limit", 3))
	definition.traits = _to_string_array(data.get("traits", []))
	definition.keywords = _to_string_array(data.get("keywords", []))
	definition.effects = _to_dict_array(data.get("effects", []))
	definition.play_options = _to_dict_array(data.get("play_options", []))
	definition.image_path = str(data.get("image_path", ""))
	var source_value = data.get("source", {})
	if source_value is Dictionary:
		definition.source = source_value.duplicate(true)
	else:
		definition.source = {}
	definition.text = str(data.get("text", ""))
	return definition

static func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

static func _to_dict_array(value) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item.duplicate(true))
	return result

func is_legion() -> bool:
	return type == "legion"

func is_artifact() -> bool:
	return type == "artifact"

func is_tactic() -> bool:
	return type == "tactic"

func is_counter_tactic() -> bool:
	return type == "counter_tactic"

func is_calamity() -> bool:
	return type == "calamity"

func is_trial() -> bool:
	return type == "trial"

func is_city() -> bool:
	return type == "city"

func is_token() -> bool:
	return type == "token"
