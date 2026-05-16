extends RefCounted
class_name CardPoolHasher

const CardDatabase = preload("res://rules/core/card_database.gd")

static func hash_card_pool(card_data_paths: Array[String]) -> String:
	var merged: Array = []
	for path in card_data_paths:
		if str(path).is_empty():
			continue
		merged.append_array(CardDatabase.load_definitions(str(path)))
	return _stable_stringify(_normalize_definitions(merged)).sha256_text()

static func _normalize_definitions(definitions: Array) -> Array:
	var rows: Array = []
	for row in definitions:
		if row is Dictionary:
			rows.append(_normalize_value(row))
	rows.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return rows

static func _normalize_value(value):
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var normalized := {}
		for key in keys:
			normalized[str(key)] = _normalize_value(value[key])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize_value(item))
		return normalized_array
	return value

static func _stable_stringify(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts: Array[String] = []
		for key in keys:
			parts.append("%s:%s" % [JSON.stringify(str(key)), _stable_stringify(value[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts: Array[String] = []
		for item in value:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	return JSON.stringify(value)

