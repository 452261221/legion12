extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")

func _initialize() -> void:
	var source_path = CardDatabase.DEFAULT_CARD_DATA_PATH
	var output_path = "user://card_data_snapshot.json"
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		source_path = args[0]
	if args.size() > 1:
		output_path = args[1]
	var definitions = CardDatabase.load_definitions(source_path)
	if definitions.is_empty():
		push_error("failed to export merged card data")
		quit(1)
		return
	var normalized = _normalize_definitions(definitions)
	var absolute_output_path = ProjectSettings.globalize_path(output_path)
	var dir_error = DirAccess.make_dir_recursive_absolute(absolute_output_path.get_base_dir())
	if dir_error != OK:
		push_error("failed to create output directory: %s" % absolute_output_path.get_base_dir())
		quit(1)
		return
	var file = FileAccess.open(absolute_output_path, FileAccess.WRITE)
	if file == null:
		push_error("failed to open output file: %s" % absolute_output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(normalized, "  ") + "\n")
	file.close()
	print("merged %s cards from %s to %s" % [normalized.size(), source_path, absolute_output_path])
	quit()

static func _normalize_definitions(definitions: Array) -> Array:
	var normalized: Array = []
	for definition in definitions:
		if not (definition is Dictionary):
			continue
		var row: Dictionary = definition.duplicate(true)
		if row.get("keywords", null) is Array:
			row["keywords"] = row.get("keywords", []).duplicate()
			row["keywords"].sort()
		if row.get("traits", null) is Array:
			row["traits"] = row.get("traits", []).duplicate()
			row["traits"].sort()
		if row.get("effects", null) is Array:
			var effects: Array = row.get("effects", []).duplicate(true)
			effects.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
			row["effects"] = effects
		normalized.append(row)
	normalized.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return normalized
