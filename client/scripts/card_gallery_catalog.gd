extends RefCounted
class_name CardGalleryCatalog

const GALLERY_DATA_PATH := "res://client/assets/cards/card_gallery_catalog.json"
const H5_PUBLIC_PREFIX := "res://规则/h5-app/public"
const FACE_PATH_SEGMENT := "/cards/faces/"
const THUMB_PATH_SEGMENT := "/cards/thumbs/"

static var _loaded := false
static var _entries: Array[Dictionary] = []
static var _entry_by_id := {}


static func get_entries() -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	for entry in _entries:
		result.append(entry.duplicate(true))
	return result


static func get_entry(entry_id: String) -> Dictionary:
	_ensure_loaded()
	var entry = _entry_by_id.get(entry_id, {})
	if entry is Dictionary:
		return entry.duplicate(true)
	return {}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_entries.clear()
	_entry_by_id.clear()
	if not FileAccess.file_exists(GALLERY_DATA_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GALLERY_DATA_PATH))
	if not (parsed is Array):
		return
	for raw_entry in parsed:
		if not (raw_entry is Dictionary):
			continue
		var entry_id := str(raw_entry.get("id", "")).strip_edges()
		if entry_id.is_empty():
			continue
		var image_relative := str(raw_entry.get("image", "")).strip_edges()
		var face_path := ""
		var thumb_path := ""
		if not image_relative.is_empty():
			face_path = "%s%s" % [H5_PUBLIC_PREFIX, image_relative]
			thumb_path = face_path.replace(FACE_PATH_SEGMENT, THUMB_PATH_SEGMENT).replace(".png", ".webp").replace(".PNG", ".webp")
		var search_text := str(raw_entry.get("searchText", "")).strip_edges()
		if search_text.is_empty():
			search_text = "%s %s %s %s" % [
				str(raw_entry.get("name", "")),
				str(raw_entry.get("faction", "")),
				str(raw_entry.get("type", "")),
				str(raw_entry.get("effectText", ""))
			]
		var source_dict = raw_entry.get("source", {})
		var source_code := ""
		if source_dict is Dictionary:
			source_code = str(source_dict.get("code", "")).strip_edges()
		var normalized := {
			"id": entry_id,
			"name": str(raw_entry.get("name", entry_id)),
			"faction": str(raw_entry.get("faction", "")),
			"type": str(raw_entry.get("type", "")),
			"series": str(raw_entry.get("series", "")),
			"card_no": str(raw_entry.get("cardNo", "")),
			"verified": bool(raw_entry.get("verified", false)),
			"search_text": search_text,
			"face_path": face_path,
			"thumb_path": thumb_path,
			"source_code": source_code
		}
		_entries.append(normalized)
		_entry_by_id[entry_id] = normalized
