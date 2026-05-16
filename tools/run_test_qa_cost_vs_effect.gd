extends SceneTree

const TestQaCostVsEffect = preload("res://tests/qa/test_qa_cost_vs_effect.gd")

func _initialize() -> void:
	var failures: Array[String] = TestQaCostVsEffect.run()
	if failures.is_empty():
		print("qa cost vs effect passed")
		quit(0)
		return
	for message in failures:
		push_error(message)
	quit(1)
