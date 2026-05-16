extends SceneTree

const TestDemoStarterDuelEffects = preload("res://tests/unit/test_demo_starter_duel_effects.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	TestDemoStarterDuelEffects._test_loki_draw_discard_requires_hand_choice(failures)
	TestDemoStarterDuelEffects._test_olaf_death_trigger_draws_then_discards(failures)
	TestDemoStarterDuelEffects._test_teach_enter_loot_and_death_refill(failures)
	if failures.is_empty():
		print("targeted discard choice tests passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
