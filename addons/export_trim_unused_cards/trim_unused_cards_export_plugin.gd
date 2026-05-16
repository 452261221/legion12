@tool
extends EditorExportPlugin

const STARTER_DECK_PATH := "res://data/decks/starter_takamagahara_asgard_raw.json"
const CALAMITY_DATA_PATH := "res://data/cards/calamity_cards.json"
const CARD_FACE_MANIFEST_PATH := "res://client/assets/cards/card_faces_manifest.json"
const STARTER_MASTER_DATA_PATH := "res://data/raw_rule_cards/starter_duel_master_cards.json"
const STRIPPED_DATA_FILES := {
	"res://data/cards/classic_batch_1.json": true,
	"res://data/cards/dev_cards.json": true,
	"res://data/cards/demo_cards.json": true,
	"res://data/cards/test_cards.json": true,
}
const ALWAYS_KEEP_FILES := {
	CARD_FACE_MANIFEST_PATH: true,
	STARTER_MASTER_DATA_PATH: true,
	"res://client/assets/battlefield_background.png": true,
	"res://client/assets/battlefield_background_extended.png": true,
	"res://client/assets/ui/calamity_stars_lit_overlay.png": true,
	"res://client/assets/cards/morale_asgard_v2.png": true,
	"res://client/assets/cards/morale_takamagahara_v2.png": true,
}
const IMAGE_EXTENSIONS := {
	"png": true,
	"jpg": true,
	"jpeg": true,
	"webp": true,
}
const EXCLUDED_PATH_PREFIXES := [
	"res://tests/",
	"res://tools/",
	"res://_external/",
	"res://_rule_extract/",
	"res://_rule_previews/",
	"res://规则/",
	"res://data/raw_rule_cards/",
	"res://android/build/",
	"res://tmp_replays/",
]
const EXCLUDED_EXACT_PATHS := {
	"res://.trae_tmp_capture.gd": true,
}

var _initialized := false
var _used_card_ids: Dictionary = {}
var _used_source_paths: Dictionary = {}


func _get_name() -> String:
	return "TrimUnusedExportCards"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if _features.has("android") or _features.has("no_test_mode"):
		return
	_ensure_initialized()
	if _should_skip_general_path(path):
		skip()
		return
	if STRIPPED_DATA_FILES.has(path):
		skip()
		return
	if _should_skip_card_face(path):
		skip()
		return
	if _should_skip_source_face(path):
		skip()


func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_collect_used_card_ids_from_deck(STARTER_DECK_PATH)
	_collect_used_card_ids_from_cards(CALAMITY_DATA_PATH)
	_collect_used_source_paths_from_manifest(CARD_FACE_MANIFEST_PATH)


func _collect_used_card_ids_from_deck(path: String) -> void:
	var root := _read_json_file(path)
	if typeof(root) != TYPE_DICTIONARY:
		return
	for raw_player in root.get("players", []):
		if typeof(raw_player) != TYPE_DICTIONARY:
			continue
		var master_id := str(raw_player.get("master_id", ""))
		if not master_id.is_empty():
			_used_card_ids[master_id] = true
		for raw_card_id in raw_player.get("deck", []):
			var card_id := str(raw_card_id)
			if not card_id.is_empty():
				_used_card_ids[card_id] = true


func _collect_used_card_ids_from_cards(path: String) -> void:
	var root := _read_json_file(path)
	if typeof(root) != TYPE_ARRAY:
		return
	for raw_card in root:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card_id := str(raw_card.get("id", ""))
		if not card_id.is_empty():
			_used_card_ids[card_id] = true


func _collect_used_source_paths_from_manifest(path: String) -> void:
	var root := _read_json_file(path)
	if typeof(root) != TYPE_DICTIONARY:
		return
	for card_id in _used_card_ids.keys():
		if not root.has(card_id):
			continue
		var entry: Variant = root[card_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_dict := entry as Dictionary
		var source_path := str(entry_dict.get("source_path", ""))
		if not source_path.is_empty():
			_used_source_paths[source_path] = true


func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


func _should_skip_card_face(path: String) -> bool:
	if ALWAYS_KEEP_FILES.has(path):
		return false
	if not path.begins_with("res://client/assets/cards/"):
		return false
	var extension := path.get_extension().to_lower()
	if not IMAGE_EXTENSIONS.has(extension):
		return false
	var card_id := path.get_basename().get_file()
	return not _used_card_ids.has(card_id)


func _should_skip_source_face(path: String) -> bool:
	if not _is_image_file(path):
		return false
	if path.begins_with("res://规则/牌面/"):
		return not _used_source_paths.has(path)
	if path.begins_with("res://data/raw_rule_cards/"):
		return not _used_source_paths.has(path)
	return false


func _is_image_file(path: String) -> bool:
	return IMAGE_EXTENSIONS.has(path.get_extension().to_lower())


func _should_skip_general_path(path: String) -> bool:
	if ALWAYS_KEEP_FILES.has(path):
		return false
	if EXCLUDED_EXACT_PATHS.has(path):
		return true
	if path.begins_with("res://_tmp"):
		return true
	for prefix in EXCLUDED_PATH_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false
