extends RefCounted
class_name TestCardDatabase

const CardDatabase = preload("res://rules/core/card_database.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_valid_dev_data_passes(failures)
	_test_duplicate_card_id_fails(failures)
	_test_artifact_type_passes_validation(failures)
	_test_tactic_type_passes_validation(failures)
	_test_counter_tactic_type_passes_validation(failures)
	_test_bijie_card_types_pass_validation(failures)
	_test_invalid_effect_action_fails(failures)
	_test_bijie_effect_actions_pass_validation(failures)
	_test_stubbed_effect_action_passes_import_validation(failures)
	_test_classic_batch_3_cards_load_with_new_actions(failures)
	return failures

static func _test_valid_dev_data_passes(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	_expect(not definitions.is_empty(), "default card data should load successfully", failures)
	_expect(CardDatabase.validate_definition_dicts(definitions).is_empty(), "default card data should pass validation", failures)

static func _test_duplicate_card_id_fails(failures: Array[String]) -> void:
	var errors = CardDatabase.validate_definition_dicts([
		{"id": "dup_card", "type": "legion", "cost": 1, "power": 1000, "hp": 1000, "keywords": [], "traits": [], "effects": []},
		{"id": "dup_card", "type": "legion", "cost": 1, "power": 1000, "hp": 1000, "keywords": [], "traits": [], "effects": []}
	])
	_expect(_contains_error(errors, "duplicate card id"), "duplicate card id should be rejected", failures)

static func _test_artifact_type_passes_validation(failures: Array[String]) -> void:
	var errors = CardDatabase.validate_definition_dicts([
		{
			"id": "artifact_card",
			"type": "artifact",
			"cost": 1,
			"keywords": [],
			"traits": [],
			"effects": []
		}
	])
	_expect(errors.is_empty(), "artifact card type should be accepted", failures)

static func _test_tactic_type_passes_validation(failures: Array[String]) -> void:
	var errors = CardDatabase.validate_definition_dicts([
		{
			"id": "tactic_card",
			"type": "tactic",
			"cost": 1,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "tactic_effect",
					"kind": "activated",
					"resolution": {"action": "draw_cards", "count": 1}
				}
			]
		}
	])
	_expect(errors.is_empty(), "tactic card type should be accepted", failures)

static func _test_counter_tactic_type_passes_validation(failures: Array[String]) -> void:
	var errors = CardDatabase.validate_definition_dicts([
		{
			"id": "counter_tactic_card",
			"type": "counter_tactic",
			"cost": 1,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "counter_effect",
					"kind": "activated",
					"can_activate_on_stack": true,
					"response_only": true,
					"resolution": {"action": "counter_target_stack"}
				}
			]
		}
	])
	_expect(errors.is_empty(), "counter_tactic card type should be accepted", failures)

static func _test_bijie_card_types_pass_validation(failures: Array[String]) -> void:
	var errors = CardDatabase.validate_definition_dicts([
		{
			"id": "trial_card",
			"type": "trial",
			"cost": 0,
			"keywords": [],
			"traits": [],
			"effects": []
		},
		{
			"id": "city_card",
			"type": "city",
			"cost": 0,
			"keywords": [],
			"traits": [],
			"effects": []
		},
		{
			"id": "token_card",
			"type": "token",
			"cost": 0,
			"keywords": [],
			"traits": [],
			"effects": []
		}
	])
	_expect(errors.is_empty(), "trial/city/token card types should be accepted", failures)

static func _test_invalid_effect_action_fails(failures: Array[String]) -> void:
	var errors = CardDatabase.validate_definition_dicts([
		{
			"id": "bad_effect_card",
			"type": "legion",
			"cost": 1,
			"power": 1000,
			"hp": 1000,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "bad_effect",
					"kind": "activated",
					"resolution": {"action": "launch_missiles"}
				}
			]
		}
	])
	_expect(_contains_error(errors, "unsupported action"), "unsupported effect action should be rejected", failures)

static func _test_bijie_effect_actions_pass_validation(failures: Array[String]) -> void:
	var errors = CardDatabase.validate_definition_dicts([
		{
			"id": "bijie_action_card",
			"type": "city",
			"cost": 0,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "gain_rune",
					"kind": "activated",
					"resolution": {"action": "add_rune", "count": 1}
				},
				{
					"id": "progress_trial",
					"kind": "activated",
					"resolution": {"action": "advance_trial_progress", "count": 1}
				}
			]
		}
	])
	_expect(errors.is_empty(), "bijie rune/trial actions should pass validation", failures)

static func _test_stubbed_effect_action_passes_import_validation(failures: Array[String]) -> void:
	var errors = CardDatabase.validate_definition_dicts([
		{
			"id": "stubbed_effect_card",
			"type": "legion",
			"status": "effects_stubbed",
			"cost": 1,
			"power": 1000,
			"hp": 1000,
			"keywords": [],
			"traits": [],
			"effects": [
				{
					"id": "stubbed_effect",
					"kind": "activated",
					"resolution": {"action": "launch_missiles"}
				}
			]
		}
	])
	_expect(errors.is_empty(), "stubbed imported effect action should be allowed before implementation", failures)

static func _test_classic_batch_3_cards_load_with_new_actions(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	var by_id := {}
	for definition in definitions:
		by_id[str(definition.get("id", ""))] = definition
	var target_ids := [
		"neutral_s02_0006",
		"neutral_s02_0007",
		"neutral_s02_0013",
		"neutral_s02_0015",
		"neutral_s02_0018"
	]
	for card_id in target_ids:
		_expect(by_id.has(card_id), "%s should load from client card data" % card_id, failures)
	var heavy_soldier = by_id.get("neutral_s02_0007", {})
	_expect(heavy_soldier.get("keywords", []).has("cannot_be_attacked_by_ranged"), "neutral_s02_0007 should carry ranged-immunity keyword", failures)
	var validation_errors = CardDatabase.validate_definition_dicts([
		by_id.get("neutral_s02_0006", {}),
		by_id.get("neutral_s02_0013", {}),
		by_id.get("neutral_s02_0015", {}),
		by_id.get("neutral_s02_0018", {})
	])
	_expect(validation_errors.is_empty(), "classic batch 3 neutral support cards should pass validation with new actions", failures)

static func _contains_error(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
