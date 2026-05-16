extends SceneTree

const TestSuncityBatch1 = preload("res://tests/unit/test_suncity_batch_1.gd")

const RESULT_PATH := "user://suncity_unit_test_results.json"
const RESULT_FALLBACK_PATH := "res://tmp_suncity_unit_test_results.json"

func _initialize() -> void:
	var failures: Array[String] = TestSuncityBatch1.run()
	if failures.is_empty():
		print("suncity unit tests passed")
		_write_result_file(true, failures)
		quit(0)
		return
	print("suncity unit tests failed: %s failures" % failures.size())
	for message in failures:
		push_error(message)
	_write_result_file(false, failures)
	quit(1)

func _write_result_file(ok: bool, failures: Array[String]) -> void:
	var payload = {
		"ok": ok,
		"failure_count": failures.size(),
		"failures": failures.duplicate()
	}
	var file = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	var resolved_path = RESULT_PATH
	if file == null:
		var fallback_path = ProjectSettings.globalize_path(RESULT_FALLBACK_PATH)
		file = FileAccess.open(fallback_path, FileAccess.WRITE)
		resolved_path = fallback_path
	if file == null:
		push_error("Unable to write suncity unit test result file: %s" % RESULT_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file = null
	print("suncity unit test results written to: %s" % resolved_path)
