extends RefCounted
class_name DeckCatalog

const DEFAULT_DECK_DATA_PATH := "res://data/decks"
const MIN_DEMO_DECK_SIZE := 40
const MAX_DEMO_DECK_SIZE := 50

static func load_duel_preset(preset_id: String, deck_data_path: String = DEFAULT_DECK_DATA_PATH) -> Dictionary:
	var preset_path = "%s/%s.json" % [deck_data_path.trim_suffix("/"), preset_id]
	var file_text := FileAccess.get_file_as_string(preset_path)
	if file_text.is_empty():
		push_error("deck preset file is empty or missing: %s" % preset_path)
		return {}
	var parsed = JSON.parse_string(file_text)
	if not (parsed is Dictionary):
		push_error("deck preset must be a JSON object: %s" % preset_path)
		return {}
	var errors = validate_duel_preset(parsed)
	if not errors.is_empty():
		for error in errors:
			push_error("deck preset validation failed: %s" % error)
		return {}
	return parsed

static func resolve_duel_preset(preset_id: String, card_definition_dicts: Array, deck_data_path: String = DEFAULT_DECK_DATA_PATH) -> Dictionary:
	var preset = load_duel_preset(preset_id, deck_data_path)
	if preset.is_empty():
		return {"ok": false, "error": "failed to load duel preset: %s" % preset_id}
	var known_card_ids := {}
	for row in card_definition_dicts:
		if row is Dictionary:
			var card_id = str(row.get("id", ""))
			if not card_id.is_empty():
				known_card_ids[card_id] = true
	var players: Array = preset.get("players", [])
	var decks: Array = []
	for player_index in range(players.size()):
		var player = players[player_index]
		var deck: Array = player.get("deck", [])
		for card_index in range(deck.size()):
			var card_id = str(deck[card_index])
			if not known_card_ids.has(card_id):
				return {
					"ok": false,
					"error": "unknown card id in preset %s: players[%s].deck[%s]=%s" % [preset_id, player_index, card_index, card_id]
				}
		decks.append(deck.duplicate())
	return {"ok": true, "preset": preset.duplicate(true), "decks": decks}

static func validate_duel_preset(preset: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var preset_id = str(preset.get("id", ""))
	if preset_id.is_empty():
		errors.append("preset is missing id")
	if str(preset.get("name", "")).is_empty():
		errors.append("%s is missing name" % _label_for_error(preset_id))
	var players = preset.get("players", null)
	if not (players is Array):
		errors.append("%s players must be an array" % _label_for_error(preset_id))
		return errors
	if players.size() != 2:
		errors.append("%s must define exactly 2 players" % _label_for_error(preset_id))
	for player_index in range(players.size()):
		var player = players[player_index]
		if not (player is Dictionary):
			errors.append("%s players[%s] must be an object" % [_label_for_error(preset_id), player_index])
			continue
		if str(player.get("name", "")).is_empty():
			errors.append("%s players[%s] is missing name" % [_label_for_error(preset_id), player_index])
		var deck = player.get("deck", null)
		if not (deck is Array):
			errors.append("%s players[%s].deck must be an array" % [_label_for_error(preset_id), player_index])
			continue
		if deck.size() < MIN_DEMO_DECK_SIZE or deck.size() > MAX_DEMO_DECK_SIZE:
			errors.append(
				"%s players[%s].deck size must be between %s and %s" % [
					_label_for_error(preset_id),
					player_index,
					MIN_DEMO_DECK_SIZE,
					MAX_DEMO_DECK_SIZE
				]
			)
		for card_index in range(deck.size()):
			if not (deck[card_index] is String):
				errors.append("%s players[%s].deck[%s] must be a string" % [_label_for_error(preset_id), player_index, card_index])
	return errors

static func _label_for_error(preset_id: String) -> String:
	if preset_id.is_empty():
		return "preset"
	return preset_id
