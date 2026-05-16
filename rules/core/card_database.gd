extends RefCounted
class_name CardDatabase

const DEFAULT_CARD_DATA_PATH := "res://data/cards"
const ALLOWED_CARD_TYPES := ["legion", "artifact", "tactic", "counter_tactic", "morale", "calamity", "trial", "city", "token"]
const ALLOWED_CARD_STATUSES := ["raw_imported", "data_imported", "effects_stubbed", "implemented", "tested"]
const ALLOWED_EFFECT_KINDS := ["activated", "triggered", "continuous", "replacement"]
const SUPPORTED_STACK_ACTIONS := [
	"draw_cards",
	"draw_source_owner_cards",
	"add_morale",
	"add_rune",
	"advance_trial_progress",
	"adjust_calamity_value",
	"counter_target_stack",
	"disable_matching_support_until_turn_end",
	"destroy_target_unit",
	"discard_cards",
	"deal_master_damage",
	"heal_master",
	"deal_legion_damage",
	"mill_cards",
	"both_players_discard_then_draw",
	"conceal_source",
	"reveal_source_face_up",
	"counter_pending_attack",
	"return_target_unit_to_hand",
	"return_target_unit_to_deck_bottom",
	"search_deck",
	"shuffle_deck",
	"reveal_calamity",
	"offer_truce_draw",
	"offer_reveal_calamity",
	"choose_option_with_cost",
	"grant_master_damage_bonus",
	"modify_target_cost",
	"modify_target_cost_until_next_own_turn_end",
	"modify_matching_cost",
	"modify_matching_cost_until_next_own_turn_end",
	"modify_matching_power_until_next_own_turn_end",
	"bjorn_recycle_and_maybe_rested_revive",
	"recycle_grave_to_deck",
	"revive_from_grave",
	"choose_and_destroy_unit",
	"choose_and_destroy_units",
	"choose_and_rest_unit",
	"choose_and_ready_unit",
	"choose_and_grant_cannot_die_until_turn_end",
	"choose_and_grant_cannot_die_once_until_next_own_turn_start",
	"choose_and_return_unit_to_deck_bottom",
	"choose_and_modify_cost_until_turn_end",
	"choose_and_modify_cost_until_next_own_turn_end",
	"choose_and_modify_power_until_next_own_turn_end",
	"choose_and_modify_power_until_turn_end",
	"hijikata_entry_destroy_combo",
	"choose_attach_matching_cards_under_source",
	"destroy_unit_by_battlefield_counter_tactic_count",
	"modify_matching_power_until_turn_end",
	"modify_source_power_until_turn_end",
	"discard_attached_cards_for_power_until_turn_end",
	"grant_source_keyword_until_turn_end",
	"prepare_next_played_legion_keyword",
	"prepare_next_played_legion_cost_modifier",
	"grant_matching_free_move_until_turn_end",
	"ready_spent_morale",
	"prevent_master_ready_spent_morale",
	"ready_source_card",
	"rest_source_card",
	"revive_source_from_grave",
	"return_source_to_deck_top",
	"sacrifice_source_and_deploy_from_hand",
	"sacrifice_source_then_follow_up",
	"return_from_grave_to_hand",
	"split_grave_two_cards_to_deck_bottom_and_hand",
	"trigger_selected_legion_died_effects",
	"grant_source_can_attack_master_until_turn_end",
	"recycle_grave_then_revive_source_from_grave",
	"disable_enemy_hand_counter_tactic_until_turn_end",
	"disable_matching_counter_tactics_until_next_own_turn_start",
	"set_counter_tactics_from_hand",
	"forged_order_prepare_enemy_moves",
	"frontline_scout_view_enemy_hand",
	"reveal_enemy_hand_to_all",
	"return_enemy_hand_to_deck_and_shuffle",
	"return_enemy_hand_to_deck_top",
	"move_source_tactic_to_spent_morale",
	"return_source_to_hand",
	"prepare_free_master_morale_effect_activation",
	"attach_source_to_enemy_artifact_lock",
	"discard_source_to_owner_grave",
	"set_pending_attack_extra_discard_requirement",
	"undo_ready_event_and_discard_enemy_hand",
	"choose_and_move_units",
	"deploy_matching_legion_from_hand",
	"deploy_matching_legion_from_hand_deck_or_grave",
	"attach_named_token_under_source",
	"grant_controller_master_cannot_be_attacked_until_next_own_turn_start",
	"return_matching_card_from_deck_or_grave_to_hand",
	"choose_rune_payment_for_source_attack_bonus",
	"bijie_reveal_top_bijie_or_reorder",
	"choose_and_grant_keyword_until_turn_end",
	"prepare_next_matching_legion_cost_modifier",
	"reveal_top_card_play_or_hand",
	"grant_cannot_die_until_turn_end",
	"grant_cannot_die_once_until_next_own_turn_start",
	"ready_battlefield_card",
	"deploy_sigurd_from_hand_or_grave",
	"search_top_for_artifact_and_named_legion",
	"move_source_one_step",
	"master_draw_then_discard",
	"choose_discard_from_hand_then_follow_up",
	"block_legion_source_heal_for_controller_until_turn_end",
	"grant_front_attack_power_bonus",
	"manifest_kusanagi",
	"disable_target_died_effects_until_turn_end",
	"deploy_source_from_hand_to_front_and_redirect_pending_attack",
	"send_source_to_grave",
	"plague_infection_apply",
	"suncity_add_temporary_morale",
	"suncity_ankh_rest_tomb_guard_draw",
	"suncity_canopic_one_buff",
	"suncity_canopic_four_protect",
	"suncity_pharaoh_celebration",
	"suncity_horemheb_entry_charge",
	"suncity_ramesses_replay_entries",
	"suncity_codex_volume_one",
	"suncity_siwa_hand_response",
	"suncity_siwa_after_attack",
	"suncity_menes_attack_buff",
	"suncity_tomb_construct_attach_tomb_guards",
	"suncity_tomb_construct_release_tomb_guards",
	"suncity_thutmose_entry",
	"suncity_thutmose_crush",
	"suncity_place_named_artifact_from_grave",
	"suncity_replace_isis_with_osiris",
	"suncity_prepare_discount_from_battlefield",
	"suncity_tutankhamun_entry",
	"suncity_tutankhamun_death",
	"suncity_fearless_assassination",
	"suncity_golden_scarab_weaken",
	"suncity_desert_sovereignty",
	"suncity_repeat_last_active_tactic",
	"tianting_qiankun_yin",
	"tianting_liu_bei_deploy_brother",
	"tianting_liu_bei_search_brother",
	"tianting_mozi_grant_cannot_die",
	"tianting_yingzheng_entry",
	"tianting_sunwu_prepare_free_tactic",
	"tianting_shanhe_scout",
	"tianting_limu_refund_morale_trigger",
	"tianting_lijing_reveal_top",
	"tianting_freeze_enemy_units",
	"tianting_freeze_enemy_morale",
	"tianting_reset_master_effect_once",
	"tianting_xishi_swap",
	"tianting_guanxing",
	"tianting_zhugeliang_peek_calamity",
	"tianting_zhugeliang_reveal_top_artifact_or_hand",
	"tianting_counter_pending_attack_then_draw_if_no_frontline",
	"tianting_pingyang_attack_reveal_top",
	"tianting_limu_entry_reveal_top_tactic",
	"tianting_yangyouji_enable_back_attack",
	"olympus_flip_morale",
	"olympus_search_top_pick_and_reorder",
	"olympus_artemis_grant_choice",
	"olympus_grant_next_tactic_free",
	"olympus_freeze_target_until_next_ready",
	"olympus_grant_source_free_move_until_turn_end",
	"olympus_reveal_hand_legion_and_destroy",
	"olympus_reveal_hand_tactic_for_power",
	"request_hand_discard_choice",
	"ruined_ritual_force_discard_and_blank_entry",
	"disable_entry_effects_and_weaken_entered_legion",
	"olympus_hannibal_attack_weaken",
	"olympus_helen_entry_discard_if_divine",
	"olympus_trojan_horse_after_attack",
	"olympus_prepare_promotion_divine_flip_discount",
	"olympus_prepare_ready_after_kill",
	"olympus_grant_source_can_attack_legions_until_turn_end",
	"olympus_grant_source_front_taunt_until_next_own_turn_start"
]
const SUPPORTED_CONTINUOUS_ACTIONS := ["modify_power", "modify_play_cost", "grant_keyword", "cannot_be_supported", "cannot_be_attacked", "prevent_master_ready_spent_morale"]
const SUPPORTED_REPLACEMENT_ACTIONS := ["prevent_lethal_master_damage"]

static func load_definitions(card_data_path: String = DEFAULT_CARD_DATA_PATH) -> Array:
	if not card_data_path.to_lower().ends_with(".json"):
		return _load_definition_directory(card_data_path)
	return _load_definition_file(card_data_path)

static func _load_definition_directory(card_data_dir: String) -> Array:
	var dir = DirAccess.open(card_data_dir)
	if dir == null:
		push_warning("card data directory is missing: %s" % card_data_dir)
		return []
	var file_names: Array[String] = []
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.to_lower().ends_with(".json"):
			continue
		file_names.append(file_name)
	dir.list_dir_end()
	file_names.sort()
	var merged: Array = []
	for file_name in file_names:
		merged.append_array(_load_definition_file("%s/%s" % [card_data_dir.trim_suffix("/"), file_name], false))
	var errors = validate_definition_dicts(merged)
	if not errors.is_empty():
		for error in errors:
			push_error("card data validation failed: %s" % error)
		return []
	return merged

static func _load_definition_file(card_data_path: String, validate_loaded_data: bool = true) -> Array:
	var file_text := FileAccess.get_file_as_string(card_data_path)
	if file_text.is_empty():
		push_error("card data file is empty or missing: %s" % card_data_path)
		return []
	var parsed = JSON.parse_string(file_text)
	if not (parsed is Array):
		push_error("card data must be a JSON array: %s" % card_data_path)
		return []
	if validate_loaded_data:
		var errors = validate_definition_dicts(parsed)
		if not errors.is_empty():
			for error in errors:
				push_error("card data validation failed: %s" % error)
			return []
	return parsed

static func validate_definition_dicts(definitions: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_card_ids := {}
	for index in range(definitions.size()):
		var row = definitions[index]
		if not (row is Dictionary):
			errors.append("row %s is not an object" % index)
			continue
		var definition_id = str(row.get("id", ""))
		if definition_id.is_empty():
			errors.append("row %s is missing card id" % index)
			continue
		if seen_card_ids.has(definition_id):
			errors.append("duplicate card id: %s" % definition_id)
			continue
		seen_card_ids[definition_id] = true
		_validate_definition_row(row, errors)
	return errors

static func _validate_definition_row(row: Dictionary, errors: Array[String]) -> void:
	var definition_id = str(row.get("id", ""))
	var card_type = str(row.get("type", "legion"))
	var status = str(row.get("status", ""))
	if not ALLOWED_CARD_TYPES.has(card_type):
		errors.append("%s has unsupported type: %s" % [definition_id, card_type])
	if not status.is_empty() and not ALLOWED_CARD_STATUSES.has(status):
		errors.append("%s has unsupported status: %s" % [definition_id, status])
	for number_key in ["cost", "power", "calamity_level", "limit"]:
		_validate_int_like(row, definition_id, number_key, errors)
	if row.has("hp") and row.get("hp") != null:
		_validate_int_like(row, definition_id, "hp", errors)
	_validate_string_array(row.get("keywords", []), definition_id, "keywords", errors)
	_validate_string_array(row.get("traits", []), definition_id, "traits", errors)
	_validate_effects(row.get("effects", []), definition_id, status, errors)

static func _validate_effects(effects, definition_id: String, status: String, errors: Array[String]) -> void:
	if not (effects is Array):
		errors.append("%s effects must be an array" % definition_id)
		return
	var requires_supported_action_validation = _requires_supported_action_validation(status)
	var seen_effect_ids := {}
	for effect in effects:
		if not (effect is Dictionary):
			errors.append("%s contains a non-object effect" % definition_id)
			continue
		var effect_id = str(effect.get("id", ""))
		if effect_id.is_empty():
			errors.append("%s has an effect without id" % definition_id)
			continue
		if seen_effect_ids.has(effect_id):
			errors.append("%s has duplicate effect id: %s" % [definition_id, effect_id])
			continue
		seen_effect_ids[effect_id] = true
		var kind = str(effect.get("kind", ""))
		if not ALLOWED_EFFECT_KINDS.has(kind):
			errors.append("%s.%s has unsupported effect kind: %s" % [definition_id, effect_id, kind])
			continue
		var resolution = effect.get("resolution", {})
		match kind:
			"activated", "triggered":
				_validate_action_resolution(definition_id, effect_id, resolution, SUPPORTED_STACK_ACTIONS, requires_supported_action_validation, errors)
			"continuous":
				_validate_action_resolution(definition_id, effect_id, resolution, SUPPORTED_CONTINUOUS_ACTIONS, requires_supported_action_validation, errors)
			"replacement":
				_validate_action_resolution(definition_id, effect_id, resolution, SUPPORTED_REPLACEMENT_ACTIONS, requires_supported_action_validation, errors)

static func _validate_action_resolution(definition_id: String, effect_id: String, resolution, supported_actions: Array, requires_supported_action_validation: bool, errors: Array[String]) -> void:
	if not (resolution is Dictionary):
		errors.append("%s.%s resolution must be an object" % [definition_id, effect_id])
		return
	var action = str(resolution.get("action", ""))
	if action.is_empty():
		errors.append("%s.%s resolution is missing action" % [definition_id, effect_id])
		return
	if requires_supported_action_validation and not supported_actions.has(action):
		errors.append("%s.%s uses unsupported action: %s" % [definition_id, effect_id, action])

static func _requires_supported_action_validation(status: String) -> bool:
	return status.is_empty() or status == "implemented" or status == "tested"

static func _validate_int_like(row: Dictionary, definition_id: String, key: String, errors: Array[String]) -> void:
	if not row.has(key):
		return
	var value = row.get(key)
	if value == null:
		return
	if value is int:
		return
	if value is float and int(value) == value:
		return
	if value is String and String(value).is_valid_int():
		return
	errors.append("%s field %s must be an integer" % [definition_id, key])

static func _validate_string_array(value, definition_id: String, key: String, errors: Array[String]) -> void:
	if not (value is Array):
		errors.append("%s field %s must be an array" % [definition_id, key])
		return
	for item in value:
		if not (item is String):
			errors.append("%s field %s must contain only strings" % [definition_id, key])
			return
