extends SceneTree

const CardDatabase = preload("res://rules/core/card_database.gd")
const ReplayRunner = preload("res://tools/replay_runner/replay_runner.gd")

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: --headless --path . -s res://tools/replay_runner/validate_replay_file.gd <replay_path> [card_data_path]")
		quit(1)
		return
	var replay_path = args[0]
	var card_data_path = CardDatabase.DEFAULT_CARD_DATA_PATH
	if args.size() > 1:
		card_data_path = args[1]
	var runner = ReplayRunner.new()
	var result = runner.run_replay_file(replay_path, card_data_path)
	if bool(result.get("ok", false)):
		print("replay validation passed: %s" % replay_path)
		quit(0)
		return
	push_error("replay validation failed: %s" % str(result.get("code", "UNKNOWN")))
	for detail in result.get("errors", []):
		push_error(" - %s" % str(detail))
	var failed_command = result.get("failed_command", {})
	if failed_command is Dictionary and not failed_command.is_empty():
		push_error("failed command index: %s" % str(failed_command.get("index", "?")))
		push_error("failed command type: %s" % str(failed_command.get("type", "")))
	quit(1)
