extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")


func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	var failures: Array[String] = []
	if table._llm_provider_option == null:
		failures.append("provider switch verify: provider option should exist")
	else:
		table._llm_runtime_settings = {
			"default_provider": "deepseek",
			"providers": {}
		}
		table._llm_settings_editing_provider = ""
		table._refresh_llm_settings_dialog()
		var deepseek_index := _find_provider_index(table, "deepseek")
		var glm_index := _find_provider_index(table, "glm")
		if deepseek_index < 0:
			failures.append("provider switch verify: deepseek option should exist")
		if glm_index < 0:
			failures.append("provider switch verify: glm option should exist")
		if failures.is_empty():
			_select_provider(table, deepseek_index)
			table._llm_api_key_edit.text = "deepseek_test_key"
			table._llm_base_url_edit.text = "https://api.deepseek.com/custom"
			table._llm_model_edit.text = "deepseek-test-model"
			table._llm_timeout_edit.text = "21"
			_select_provider(table, glm_index)
			var stored_providers: Dictionary = table._llm_runtime_settings.get("providers", {})
			var stored_deepseek: Dictionary = stored_providers.get("deepseek", {})
			if str(stored_deepseek.get("api_key", "")) != "deepseek_test_key":
				failures.append("provider switch verify: switching away should preserve deepseek api key")
			if str(stored_deepseek.get("model", "")) != "deepseek-test-model":
				failures.append("provider switch verify: switching away should preserve deepseek model")
			table._llm_api_key_edit.text = "glm_test_key"
			table._llm_base_url_edit.text = "https://open.bigmodel.cn/custom"
			table._llm_model_edit.text = "glm-test-model"
			table._llm_timeout_edit.text = "33"
			_select_provider(table, deepseek_index)
			if table._llm_api_key_edit.text != "deepseek_test_key":
				failures.append("provider switch verify: switching back should restore deepseek api key")
			if table._llm_base_url_edit.text != "https://api.deepseek.com/custom":
				failures.append("provider switch verify: switching back should restore deepseek base url")
			if table._llm_model_edit.text != "deepseek-test-model":
				failures.append("provider switch verify: switching back should restore deepseek model")
			if abs(float(table._llm_timeout_edit.text) - 21.0) > 0.001:
				failures.append("provider switch verify: switching back should restore deepseek timeout")
			_select_provider(table, glm_index)
			if table._llm_api_key_edit.text != "glm_test_key":
				failures.append("provider switch verify: switching back should restore glm api key")
			if table._llm_model_edit.text != "glm-test-model":
				failures.append("provider switch verify: switching back should restore glm model")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("provider switch verify passed")
	quit(0)


func _find_provider_index(table, provider_name: String) -> int:
	for i in range(table._llm_provider_option.get_item_count()):
		if str(table._llm_provider_option.get_item_metadata(i)).strip_edges().to_lower() == provider_name:
			return i
	return -1


func _select_provider(table, index: int) -> void:
	table._llm_provider_option.select(index)
	table._on_llm_provider_selected(index)
