extends SceneTree

const TestReplayIO = preload("res://tests/unit/test_replay_io.gd")

func _initialize() -> void:
	var failures: Array[String] = TestReplayIO.run()
	if failures.is_empty():
		print("replayio unit tests passed")
		quit(0)
		return
	print("replayio unit tests failed: %s failures" % failures.size())
	printerr("replayio unit tests failed: %s failures" % failures.size())
	for message in failures:
		push_error(message)
	quit(1)
