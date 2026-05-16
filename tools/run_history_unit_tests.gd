extends SceneTree

const TestMatchHistoryStore = preload("res://tests/unit/test_match_history_store.gd")

func _initialize() -> void:
	var failures: Array[String] = TestMatchHistoryStore.run()
	if failures.is_empty():
		print("history unit tests passed")
		quit(0)
		return
	print("history unit tests failed: %s failures" % failures.size())
	printerr("history unit tests failed: %s failures" % failures.size())
	for message in failures:
		push_error(message)
	quit(1)
