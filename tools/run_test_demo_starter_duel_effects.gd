extends SceneTree

const TestDemoStarterDuelEffects = preload("res://tests/unit/test_demo_starter_duel_effects.gd")

func _initialize() -> void:
	var failures: Array[String] = TestDemoStarterDuelEffects.run()
	if failures.is_empty():
		print("demo starter duel effects passed")
		quit(0)
		return
	for message in failures:
		push_error(message)
	quit(1)
