extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")

func _initialize() -> void:
	var card_data_path = CardDatabase.DEFAULT_CARD_DATA_PATH
	if OS.get_cmdline_user_args().size() > 0:
		card_data_path = OS.get_cmdline_user_args()[0]
	var definitions = CardDatabase.load_definitions(card_data_path)
	if definitions.is_empty():
		push_error("card data validation failed")
		quit(1)
		return
	print("card data validation passed")
	quit()
