extends SceneTree

const TestClassicBatch1 = preload("res://tests/unit/test_classic_batch_1.gd")

func _initialize() -> void:
	var failures: Array[String] = TestClassicBatch1.run()
	if failures.is_empty():
		print("classic batch 1 tests passed")
		quit(0)
		return
	for message in failures:
		push_error(message)
	quit(1)
