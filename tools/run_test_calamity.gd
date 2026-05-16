extends SceneTree

const TestCalamity = preload("res://tests/unit/test_calamity.gd")

func _initialize() -> void:
	var failures: Array[String] = TestCalamity.run()
	if failures.is_empty():
		print("calamity tests passed")
		quit(0)
		return
	for message in failures:
		push_error(message)
	quit(1)
