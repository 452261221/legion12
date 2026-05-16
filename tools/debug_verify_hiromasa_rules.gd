extends SceneTree

const TestDemoStarterDuelEffects = preload("res://tests/unit/test_demo_starter_duel_effects.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	TestDemoStarterDuelEffects._test_hiromasa_enters_draws_and_disables_enemy_counter_tactic(failures)
	TestDemoStarterDuelEffects._test_hiromasa_targeted_absolute_defense_can_counter_the_disable(failures)
	if failures.is_empty():
		print("hiromasa rules verification passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
