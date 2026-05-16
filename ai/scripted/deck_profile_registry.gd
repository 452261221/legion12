extends RefCounted
class_name DeckProfileRegistry

const DEFAULT_CONFIG_PATH := "res://data/ai/profiles.json"

var _config_path: String = DEFAULT_CONFIG_PATH
var _loaded := false
var _profiles_by_id: Dictionary = {}
var _deck_player_profile_map: Dictionary = {}
var _master_profile_map: Dictionary = {}
var _default_profile_id := "midrange"

func _init(config_path: String = DEFAULT_CONFIG_PATH) -> void:
	_config_path = config_path

func resolve_profile(match_context: Dictionary, player_id: int, state = null) -> Dictionary:
	_ensure_loaded()
	var profile_id := _resolve_profile_id(match_context, player_id, state)
	var profile: Dictionary = _profiles_by_id.get(profile_id, {})
	if profile.is_empty():
		profile = _profiles_by_id.get(_default_profile_id, {})
	return profile.duplicate(true)

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_profiles_by_id.clear()
	_deck_player_profile_map.clear()
	_master_profile_map.clear()
	if not FileAccess.file_exists(_config_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_config_path))
	if not (parsed is Dictionary):
		return
	_default_profile_id = str(parsed.get("default_profile_id", _default_profile_id))
	for row in parsed.get("profiles", []):
		if not (row is Dictionary):
			continue
		var profile_id := str(row.get("profile_id", ""))
		if profile_id.is_empty():
			continue
		_profiles_by_id[profile_id] = row.duplicate(true)
	for row in parsed.get("deck_player_profiles", []):
		if not (row is Dictionary):
			continue
		var deck_id := str(row.get("deck_id", ""))
		var player_index := int(row.get("player_index", -1))
		var profile_id := str(row.get("profile_id", ""))
		if deck_id.is_empty() or player_index < 0 or profile_id.is_empty():
			continue
		_deck_player_profile_map["%s:%s" % [deck_id, player_index]] = profile_id
	for row in parsed.get("master_profiles", []):
		if not (row is Dictionary):
			continue
		var master_id := str(row.get("master_id", ""))
		var profile_id := str(row.get("profile_id", ""))
		if master_id.is_empty() or profile_id.is_empty():
			continue
		_master_profile_map[master_id] = profile_id

func _resolve_profile_id(match_context: Dictionary, player_id: int, state = null) -> String:
	var player_profiles = match_context.get("player_profiles", [])
	if player_profiles is Array and player_id >= 0 and player_id < player_profiles.size():
		var direct_id := str(player_profiles[player_id])
		if not direct_id.is_empty():
			return direct_id
	var deck_id := str(match_context.get("deck_id", ""))
	if not deck_id.is_empty():
		var key := "%s:%s" % [deck_id, player_id]
		if _deck_player_profile_map.has(key):
			return str(_deck_player_profile_map[key])
	if state != null and state.players.size() > player_id:
		var master_id := str(state.get_player(player_id).master_definition_id)
		if _master_profile_map.has(master_id):
			return str(_master_profile_map[master_id])
	return _default_profile_id

