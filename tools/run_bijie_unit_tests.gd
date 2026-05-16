extends SceneTree

const TestCardDatabase = preload("res://tests/unit/test_card_database.gd")
const TestBijieCore = preload("res://tests/unit/test_bijie_core.gd")
const TestBijieBatch1 = preload("res://tests/unit/test_bijie_batch_1.gd")
const TestBijieBatch2 = preload("res://tests/unit/test_bijie_batch_2.gd")
const TestBijieBatch3 = preload("res://tests/unit/test_bijie_batch_3.gd")
const TestBijieBatch4 = preload("res://tests/unit/test_bijie_batch_4.gd")
const TestBijieBatch5 = preload("res://tests/unit/test_bijie_batch_5.gd")
const TestBijieBatch6 = preload("res://tests/unit/test_bijie_batch_6.gd")
const TestBijieBatch7 = preload("res://tests/unit/test_bijie_batch_7.gd")
const TestBijieBatch8 = preload("res://tests/unit/test_bijie_batch_8.gd")

const RESULT_PATH := "res://tmp_bijie_unit_test_results.json"

func _initialize() -> void:
	var suites = [
		{"name": "TestCardDatabase", "script": TestCardDatabase},
		{"name": "TestBijieCore", "script": TestBijieCore},
		{"name": "TestBijieBatch1", "script": TestBijieBatch1},
		{"name": "TestBijieBatch2", "script": TestBijieBatch2},
		{"name": "TestBijieBatch3", "script": TestBijieBatch3},
		{"name": "TestBijieBatch4", "script": TestBijieBatch4},
		{"name": "TestBijieBatch5", "script": TestBijieBatch5},
		{"name": "TestBijieBatch6", "script": TestBijieBatch6},
		{"name": "TestBijieBatch7", "script": TestBijieBatch7},
		{"name": "TestBijieBatch8", "script": TestBijieBatch8}
	]
	print("Running %s bijie test suites..." % suites.size())
	var suite_summaries: Array[Dictionary] = []
	var failures: Array[String] = []
	for suite in suites:
		var suite_name = str(suite.get("name", "UnknownSuite"))
		var suite_failures: Array[String] = suite.script.run()
		suite_summaries.append({
			"name": suite_name,
			"failure_count": suite_failures.size()
		})
		if suite_failures.is_empty():
			print("PASS %s" % suite_name)
		else:
			print("FAIL %s (%s failures)" % [suite_name, suite_failures.size()])
		for message in suite_failures:
			failures.append("%s: %s" % [suite_name, message])
	var ok = failures.is_empty()
	_write_result_file(ok, suite_summaries, failures)
	quit(0 if ok else 1)

func _write_result_file(ok: bool, suite_summaries: Array[Dictionary], failures: Array[String]) -> void:
	var payload = {
		"ok": ok,
		"failure_count": failures.size(),
		"suite_count": suite_summaries.size(),
		"suites": suite_summaries.duplicate(true),
		"failures": failures.duplicate()
	}
	var path = ProjectSettings.globalize_path(RESULT_PATH)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Unable to write bijie unit test result file: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file = null
	print("bijie unit test results written to: %s" % path)
