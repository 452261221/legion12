extends RefCounted
class_name DeckBuilderStore

const DeckBuilderCardPool = preload("res://client/scripts/deck_builder_card_pool.gd")

const STORE_PATH := "user://deck_builder_store.json"
const GENERATED_FORMAL_DUEL_PATH := "user://generated_formal_duel.json"
const GENERATED_TEST_DUEL_PATH := "user://generated_test_duel.json"
const BUILTIN_STARTER_PRESET_PATH := "res://data/decks/starter_takamagahara_asgard_raw.json"
const BUILTIN_TEST_PRESET_PATH := "res://data/decks/test_duel.json"
const NO_TEST_MODE_FEATURE := "no_test_mode"
const STORE_VERSION := 3
const NETWORK_DECK_SELECTION_VERSION := 1
const MIN_DECK_SIZE := 40
const MAX_DECK_SIZE := 50
static var _runtime_selected_player_deck_id := ""
static var _has_runtime_selected_player_deck_override := false
static var _store_path_override := ""

static func _is_test_mode_available() -> bool:
	return not OS.has_feature(NO_TEST_MODE_FEATURE)


static func configure_store_path(store_path: String) -> void:
	_store_path_override = str(store_path).strip_edges()


static func reset_store_path() -> void:
	_store_path_override = ""


static func get_store_path() -> String:
	return _store_path_override if not _store_path_override.is_empty() else STORE_PATH


static func load_store() -> Dictionary:
	if not FileAccess.file_exists(get_store_path()):
		var default_store := _default_store()
		_seed_builtin_decks(default_store)
		if _is_test_mode_available():
			_seed_builtin_test_decks(default_store)
		_write_store(default_store)
		return default_store
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(get_store_path()))
	if not (parsed is Dictionary):
		var fallback_store := _default_store()
		_seed_builtin_decks(fallback_store)
		if _is_test_mode_available():
			_seed_builtin_test_decks(fallback_store)
		_write_store(fallback_store)
		return fallback_store
	var store := _normalize_store(parsed)
	var wrote_store := false
	if _normalize_decks(store.get("decks", [])).is_empty():
		_seed_builtin_decks(store)
		wrote_store = true
	if _is_test_mode_available() and _normalize_decks(store.get("test_decks", [])).is_empty():
		_seed_builtin_test_decks(store)
		wrote_store = true
	if wrote_store:
		_write_store(store)
	return store


static func list_decks(deck_mode: String = "formal") -> Array[Dictionary]:
	var store := load_store()
	if deck_mode == "test":
		if not _is_test_mode_available():
			return []
		return _normalize_decks(store.get("test_decks", []))
	return _normalize_decks(store.get("decks", []))


static func get_deck(deck_id: String, deck_mode: String = "") -> Dictionary:
	var decks: Array[Dictionary] = []
	if deck_mode == "formal" or deck_mode.is_empty():
		decks.append_array(list_decks("formal"))
	if deck_mode == "test" or deck_mode.is_empty():
		decks.append_array(list_decks("test"))
	for deck in decks:
		if str(deck.get("id", "")) == deck_id:
			return deck.duplicate(true)
	return {}


static func save_deck(deck: Dictionary, card_definitions: Dictionary, deck_mode: String = "formal") -> Dictionary:
	if deck_mode == "test" and not _is_test_mode_available():
		return {"ok": false, "reason": "测试卡组模块已禁用。"}
	var normalized := _normalize_deck(deck)
	var validation := validate_deck(normalized, card_definitions, deck_mode)
	if not bool(validation.get("ok", false)):
		return validation
	var store := load_store()
	var store_key := "test_decks" if deck_mode == "test" else "decks"
	var decks := _normalize_decks(store.get(store_key, []))
	var target_id := str(normalized.get("id", "")).strip_edges()
	if target_id.is_empty():
		target_id = "deck_%s" % str(Time.get_unix_time_from_system()).replace(".", "_")
		normalized["id"] = target_id
	normalized["updated_at"] = int(Time.get_unix_time_from_system())
	if int(normalized.get("created_at", 0)) <= 0:
		normalized["created_at"] = int(Time.get_unix_time_from_system())
	var replaced := false
	for index in range(decks.size()):
		if str(decks[index].get("id", "")) != target_id:
			continue
		decks[index] = normalized.duplicate(true)
		replaced = true
		break
	if not replaced:
		decks.append(normalized.duplicate(true))
	store[store_key] = decks
	_write_store(store)
	return {
		"ok": true,
		"deck": normalized.duplicate(true)
	}


static func delete_deck(deck_id: String, deck_mode: String = "formal") -> void:
	if deck_mode == "test" and not _is_test_mode_available():
		return
	var store := load_store()
	var next_decks: Array[Dictionary] = []
	var store_key := "test_decks" if deck_mode == "test" else "decks"
	for deck in _normalize_decks(store.get(store_key, [])):
		if str(deck.get("id", "")) == deck_id:
			continue
		next_decks.append(deck)
	store[store_key] = next_decks
	if deck_mode == "test":
		if str(store.get("selected_test_player_deck_id", "")) == deck_id:
			store["selected_test_player_deck_id"] = ""
		if str(store.get("selected_test_opponent_deck_id", "")) == deck_id:
			store["selected_test_opponent_deck_id"] = ""
	else:
		if str(store.get("selected_player_deck_id", "")) == deck_id:
			store["selected_player_deck_id"] = ""
		if _has_runtime_selected_player_deck_override and _runtime_selected_player_deck_id == deck_id:
			_set_runtime_selected_player_deck_override("")
		if str(store.get("selected_ai_deck_id", "")) == deck_id:
			store["selected_ai_deck_id"] = ""
	_write_store(store)


static func set_selected_player_deck(deck_id: String) -> void:
	_set_runtime_selected_player_deck_override(deck_id)
	var store := load_store()
	store["selected_player_deck_id"] = deck_id
	_write_store(store)


static func set_selected_ai_deck(deck_id: String) -> void:
	var store := load_store()
	store["selected_ai_deck_id"] = deck_id
	_write_store(store)


static func clear_selected_player_deck() -> void:
	_set_runtime_selected_player_deck_override("")
	var store := load_store()
	store["selected_player_deck_id"] = ""
	_write_store(store)


static func clear_selected_ai_deck() -> void:
	var store := load_store()
	store["selected_ai_deck_id"] = ""
	_write_store(store)


static func set_selected_test_player_deck(deck_id: String) -> void:
	if not _is_test_mode_available():
		return
	var store := load_store()
	store["selected_test_player_deck_id"] = deck_id
	_write_store(store)


static func set_selected_test_opponent_deck(deck_id: String) -> void:
	if not _is_test_mode_available():
		return
	var store := load_store()
	store["selected_test_opponent_deck_id"] = deck_id
	_write_store(store)


static func clear_selected_test_player_deck() -> void:
	if not _is_test_mode_available():
		return
	var store := load_store()
	store["selected_test_player_deck_id"] = ""
	_write_store(store)


static func clear_selected_test_opponent_deck() -> void:
	if not _is_test_mode_available():
		return
	var store := load_store()
	store["selected_test_opponent_deck_id"] = ""
	_write_store(store)


static func set_selected_background_card(background_card_id: String) -> void:
	var store := load_store()
	store["selected_background_card_id"] = str(background_card_id).strip_edges()
	_write_store(store)


static func clear_selected_background_card() -> void:
	var store := load_store()
	store["selected_background_card_id"] = ""
	_write_store(store)


static func get_selected_player_deck_id() -> String:
	if _has_runtime_selected_player_deck_override:
		return _runtime_selected_player_deck_id
	return str(load_store().get("selected_player_deck_id", ""))


static func reset_runtime_selection_cache() -> void:
	_has_runtime_selected_player_deck_override = false
	_runtime_selected_player_deck_id = ""


static func get_selected_ai_deck_id() -> String:
	return str(load_store().get("selected_ai_deck_id", ""))


static func get_selected_test_player_deck_id() -> String:
	if not _is_test_mode_available():
		return ""
	return str(load_store().get("selected_test_player_deck_id", ""))


static func get_selected_test_opponent_deck_id() -> String:
	if not _is_test_mode_available():
		return ""
	return str(load_store().get("selected_test_opponent_deck_id", ""))


static func get_selected_background_card_id() -> String:
	return str(load_store().get("selected_background_card_id", ""))


static func build_local_formal_duel(card_definitions: Dictionary, fallback_formal_duel_path: String) -> Dictionary:
	var player_selected := get_deck(get_selected_player_deck_id(), "formal")
	var ai_selected := get_deck(get_selected_ai_deck_id(), "formal")
	return build_local_formal_duel_from_selections(card_definitions, fallback_formal_duel_path, player_selected, ai_selected)


static func build_local_formal_duel_from_selections(card_definitions: Dictionary, fallback_formal_duel_path: String, player_selected_deck: Dictionary, ai_selected_deck: Dictionary) -> Dictionary:
	var fallback_result := _load_fallback_duel_data(fallback_formal_duel_path, "正式对局默认预组读取失败。", "正式对局默认预组缺少双方玩家数据。")
	if not bool(fallback_result.get("ok", false)):
		return fallback_result
	var fallback_players: Array = fallback_result.get("players", [])
	var player_entry := _merge_player_entry(player_selected_deck, fallback_players[0], card_definitions, "玩家", "formal")
	var ai_entry := _merge_player_entry(ai_selected_deck, fallback_players[1], card_definitions, "人机", "formal")
	var duel_data := {
		"id": "user_formal_duel",
		"name": "自定义正式对局",
		"description": "根据卡组构筑模块生成。",
		"players": [
			player_entry,
			ai_entry
		]
	}
	var duel_path := _write_generated_duel_or_fallback(duel_data, GENERATED_FORMAL_DUEL_PATH, fallback_formal_duel_path)
	return {
		"ok": true,
		"duel_path": duel_path,
		"duel_label": "正式对局",
		"duel_data": duel_data.duplicate(true),
		"summary": _build_selection_summary_from_decks(player_selected_deck, ai_selected_deck, card_definitions, "玩家卡组", "人机卡组")
	}


static func build_network_formal_duel(card_definitions: Dictionary, fallback_formal_duel_path: String, remote_selection: Dictionary = {}) -> Dictionary:
	var local_selected := get_deck(get_selected_player_deck_id(), "formal")
	return build_network_formal_duel_from_selections(card_definitions, fallback_formal_duel_path, local_selected, remote_selection)


static func build_network_formal_duel_from_selections(card_definitions: Dictionary, fallback_formal_duel_path: String, local_selected_deck: Dictionary, remote_selection: Dictionary = {}) -> Dictionary:
	var fallback_result := _load_fallback_duel_data(fallback_formal_duel_path, "正式对局默认预组读取失败。", "正式对局默认预组缺少双方玩家数据。")
	if not bool(fallback_result.get("ok", false)):
		return fallback_result
	var fallback_players: Array = fallback_result.get("players", [])
	var local_entry := _sanitize_network_player_entry(_merge_player_entry(local_selected_deck, fallback_players[0], card_definitions, "房主", "formal"))
	var remote_resolution := _resolve_network_remote_player_entry(remote_selection, fallback_players[0], card_definitions)
	var remote_entry := _sanitize_network_player_entry(remote_resolution.get("entry", fallback_players[0]).duplicate(true))
	var duel_data := {
		"id": "network_formal_duel",
		"name": "联机正式对局",
		"description": "根据房主与加入方当前卡组设置生成。",
		"players": [
			local_entry,
			remote_entry
		]
	}
	var duel_path := _write_generated_duel_or_fallback(duel_data, GENERATED_FORMAL_DUEL_PATH, fallback_formal_duel_path)
	var remote_summary_name := str(remote_entry.get("name", "高天原预组"))
	var remote_summary_reason := str(remote_resolution.get("reason", ""))
	if not bool(remote_resolution.get("used_remote_deck", false)) and not remote_summary_reason.is_empty():
		remote_summary_name = "%s（%s）" % [remote_summary_name, remote_summary_reason]
	return {
		"ok": true,
		"duel_path": duel_path,
		"duel_label": "联机正式对局",
		"duel_data": duel_data.duplicate(true),
		"summary": _build_selection_summary_from_decks(local_selected_deck, {}, card_definitions, "房主卡组", "对手卡组", remote_summary_name)
	}


static func build_local_test_duel(card_definitions: Dictionary, fallback_test_duel_path: String) -> Dictionary:
	if not _is_test_mode_available():
		return {
			"ok": false,
			"reason": "测试卡组模块已禁用。"
		}
	var player_selected := get_deck(get_selected_test_player_deck_id(), "test")
	var opponent_selected := get_deck(get_selected_test_opponent_deck_id(), "test")
	var fallback_result := _load_fallback_duel_data(fallback_test_duel_path, "测试对局默认预组读取失败。", "测试对局默认预组缺少双方玩家数据。")
	if not bool(fallback_result.get("ok", false)):
		return fallback_result
	var fallback_players: Array = fallback_result.get("players", [])
	var player_entry := _merge_player_entry(player_selected, fallback_players[0], card_definitions, "测试方A", "test")
	var opponent_entry := _merge_player_entry(opponent_selected, fallback_players[1], card_definitions, "测试方B", "test")
	var duel_data := {
		"id": "user_test_duel",
		"name": "自定义测试对局",
		"description": "根据测试卡组配置生成。",
		"players": [
			player_entry,
			opponent_entry
		]
	}
	var duel_path := _write_generated_duel_or_fallback(duel_data, GENERATED_TEST_DUEL_PATH, fallback_test_duel_path)
	return {
		"ok": true,
		"duel_path": duel_path,
		"duel_label": "测试对局",
		"duel_data": duel_data.duplicate(true),
		"summary": _build_selection_summary_from_decks(player_selected, opponent_selected, card_definitions, "玩家卡组", "对手卡组")
	}


static func _write_generated_duel_or_fallback(duel_data: Dictionary, generated_duel_path: String, fallback_duel_path: String) -> String:
	var file := FileAccess.open(generated_duel_path, FileAccess.WRITE)
	if file == null:
		return fallback_duel_path
	file.store_string(JSON.stringify(duel_data, "  "))
	file.close()
	return generated_duel_path


static func build_local_network_player_deck_selection(card_definitions: Dictionary) -> Dictionary:
	var selected_deck := get_deck(get_selected_player_deck_id(), "formal")
	return build_network_player_deck_selection_from_deck(selected_deck, card_definitions)


static func build_network_player_deck_selection_from_deck(selected_deck: Dictionary, card_definitions: Dictionary) -> Dictionary:
	var normalized_deck := _normalize_deck(selected_deck)
	if normalized_deck.is_empty() or str(normalized_deck.get("id", "")).is_empty():
		return {
			"protocol_version": NETWORK_DECK_SELECTION_VERSION,
			"has_deck": false
		}
	var validation := validate_deck(normalized_deck, card_definitions, "formal")
	if not bool(validation.get("ok", false)):
		return {
			"protocol_version": NETWORK_DECK_SELECTION_VERSION,
			"has_deck": false
		}
	return {
		"protocol_version": NETWORK_DECK_SELECTION_VERSION,
		"has_deck": true,
		"deck": normalized_deck.duplicate(true)
	}


static func build_selection_summary(card_definitions: Dictionary) -> String:
	var player_deck := get_deck(get_selected_player_deck_id(), "formal")
	var ai_deck := get_deck(get_selected_ai_deck_id(), "formal")
	return _build_selection_summary_from_decks(player_deck, ai_deck, card_definitions, "玩家卡组", "人机卡组")


static func validate_deck(deck: Dictionary, card_definitions: Dictionary, deck_mode: String = "formal") -> Dictionary:
	if deck_mode == "test" and not _is_test_mode_available():
		return {"ok": false, "reason": "测试卡组模块已禁用。"}
	var name := str(deck.get("name", "")).strip_edges()
	if name.is_empty():
		return {"ok": false, "reason": "请输入卡组名称。"}
	var master_id := str(deck.get("master_id", "")).strip_edges()
	if master_id.is_empty():
		return {"ok": false, "reason": "请选择 1 张主宰。"}
	if deck_mode == "formal" and not DeckBuilderCardPool.is_formal_master(master_id):
		return {"ok": false, "reason": "当前主宰不在正式构筑卡池内。"}
	var master_definition: Dictionary = card_definitions.get(master_id, {})
	if master_definition.is_empty() or str(master_definition.get("kind", "")) != "master":
		return {"ok": false, "reason": "当前主宰无效。"}
	var cards := _normalize_card_ids(deck.get("cards", []))
	if deck_mode == "formal" and (cards.size() < MIN_DECK_SIZE or cards.size() > MAX_DECK_SIZE):
		return {"ok": false, "reason": "卡组张数需在 %s-%s 张之间。当前为 %s 张。" % [MIN_DECK_SIZE, MAX_DECK_SIZE, cards.size()]}
	if deck_mode == "test" and cards.is_empty():
		return {"ok": false, "reason": "测试卡组至少需要 1 张卡牌。"}
	var count_by_card := {}
	var trial_count := 0
	for card_id in cards:
		if deck_mode == "formal" and not DeckBuilderCardPool.is_formal_deck_card(card_id):
			return {"ok": false, "reason": "卡组中存在不属于正式构筑池的卡牌：%s" % card_id}
		var definition: Dictionary = card_definitions.get(card_id, {})
		if definition.is_empty():
			return {"ok": false, "reason": "卡组中存在未知卡牌：%s" % card_id}
		if str(definition.get("kind", "")) == "master":
			return {"ok": false, "reason": "主宰不能加入牌库。"}
		var card_type := str(definition.get("type", ""))
		if card_type == "morale" or card_type == "calamity":
			return {"ok": false, "reason": "士气牌和天灾牌不能加入卡组。"}
		if deck_mode == "formal" and card_type == "trial":
			trial_count += 1
		if deck_mode == "formal":
			count_by_card[card_id] = int(count_by_card.get(card_id, 0)) + 1
			var card_limit := int(definition.get("limit", 3))
			if int(count_by_card[card_id]) > max(1, card_limit):
				return {"ok": false, "reason": "%s 超出数量上限（最多 %s 张）。" % [str(definition.get("name", card_id)), max(1, card_limit)]}
	if deck_mode == "formal":
		var max_trial_cards := _max_trial_cards_for_master(master_id)
		if trial_count > max_trial_cards:
			return {"ok": false, "reason": "%s 最多可携带 %s 张试炼卡。当前为 %s 张。" % [str(master_definition.get("name", "当前主宰")), max_trial_cards, trial_count]}
	return {"ok": true}


static func _merge_player_entry(selected_deck: Dictionary, fallback_player: Dictionary, card_definitions: Dictionary, fallback_name: String, deck_mode: String = "formal") -> Dictionary:
	if selected_deck.is_empty():
		return fallback_player.duplicate(true)
	var validation := validate_deck(_normalize_deck(selected_deck), card_definitions, deck_mode)
	if not bool(validation.get("ok", false)):
		return fallback_player.duplicate(true)
	var master_id := str(selected_deck.get("master_id", ""))
	var master_definition: Dictionary = card_definitions.get(master_id, {})
	if master_definition.is_empty():
		return fallback_player.duplicate(true)
	var hp := int(master_definition.get("hp", selected_deck.get("master_hp", 20)))
	var max_hp := int(master_definition.get("max_hp", master_definition.get("hp", hp)))
	return {
		"name": str(selected_deck.get("name", fallback_name)),
		"ai_profile_id": "",
		"master_name": str(master_definition.get("name", "主宰")),
		"master_id": master_id,
		"master_hp": hp,
		"master_max_hp": max_hp,
		"deck": _normalize_card_ids(selected_deck.get("cards", []))
	}


static func _max_trial_cards_for_master(master_id: String) -> int:
	match master_id:
		"bijie_s02_06m2":
			return 2
		_:
			return 1


static func _resolve_network_remote_player_entry(remote_selection: Dictionary, fallback_player: Dictionary, card_definitions: Dictionary) -> Dictionary:
	var fallback_entry := _sanitize_network_player_entry(fallback_player.duplicate(true))
	if remote_selection.is_empty():
		return {
			"entry": fallback_entry,
			"used_remote_deck": false,
			"reason": "未检测到对方卡组设置，已改用高天原预组"
		}
	if int(remote_selection.get("protocol_version", -1)) != NETWORK_DECK_SELECTION_VERSION:
		return {
			"entry": fallback_entry,
			"used_remote_deck": false,
			"reason": "对方版本不一致，已改用高天原预组"
		}
	if not bool(remote_selection.get("has_deck", false)):
		return {
			"entry": fallback_entry,
			"used_remote_deck": false,
			"reason": "对方未设置有效卡组，已改用高天原预组"
		}
	var remote_deck = remote_selection.get("deck", {})
	if not (remote_deck is Dictionary):
		return {
			"entry": fallback_entry,
			"used_remote_deck": false,
			"reason": "未检测到对方卡组设置，已改用高天原预组"
		}
	var normalized_remote_deck := _normalize_deck(remote_deck)
	var validation := validate_deck(normalized_remote_deck, card_definitions, "formal")
	if not bool(validation.get("ok", false)):
		return {
			"entry": fallback_entry,
			"used_remote_deck": false,
			"reason": "对方卡组无效，已改用高天原预组"
		}
	var merged_entry := _merge_player_entry(normalized_remote_deck, fallback_entry, card_definitions, "联机对手")
	return {
		"entry": _sanitize_network_player_entry(merged_entry),
		"used_remote_deck": true,
		"reason": ""
	}


static func _sanitize_network_player_entry(player_entry: Dictionary) -> Dictionary:
	var sanitized := player_entry.duplicate(true)
	sanitized["ai_profile_id"] = ""
	return sanitized


static func _build_selection_summary_from_decks(primary_deck: Dictionary, secondary_deck: Dictionary, card_definitions: Dictionary, primary_label: String, secondary_label: String, secondary_override_text: String = "") -> String:
	var primary_name := "默认玩家预组"
	var secondary_name := "默认人机预组"
	if not primary_deck.is_empty():
		primary_name = str(primary_deck.get("name", primary_name))
	if not secondary_deck.is_empty():
		secondary_name = str(secondary_deck.get("name", secondary_name))
	var primary_master := _deck_master_name(primary_deck, card_definitions)
	var secondary_master := _deck_master_name(secondary_deck, card_definitions)
	var primary_desc := primary_name if primary_master.is_empty() else "%s（%s）" % [primary_name, primary_master]
	var secondary_desc := secondary_name if secondary_master.is_empty() else "%s（%s）" % [secondary_name, secondary_master]
	if not secondary_override_text.is_empty():
		secondary_desc = secondary_override_text
	return "%s：%s\n%s：%s" % [primary_label, primary_desc, secondary_label, secondary_desc]


static func _load_fallback_duel_data(fallback_duel_path: String, read_failure_reason: String, players_failure_reason: String) -> Dictionary:
	var fallback_parsed = JSON.parse_string(FileAccess.get_file_as_string(fallback_duel_path))
	if not (fallback_parsed is Dictionary):
		return {
			"ok": false,
			"reason": read_failure_reason
		}
	var fallback_data: Dictionary = fallback_parsed
	var fallback_players: Array = fallback_data.get("players", [])
	if fallback_players.size() < 2:
		return {
			"ok": false,
			"reason": players_failure_reason
		}
	return {
		"ok": true,
		"data": fallback_data,
		"players": fallback_players
	}


static func _deck_master_name(deck: Dictionary, card_definitions: Dictionary) -> String:
	if deck.is_empty():
		return ""
	var master_definition: Dictionary = card_definitions.get(str(deck.get("master_id", "")), {})
	return str(master_definition.get("name", ""))


static func _default_store() -> Dictionary:
	return {
		"version": STORE_VERSION,
		"decks": [],
		"test_decks": [],
		"selected_player_deck_id": "",
		"selected_ai_deck_id": "",
		"selected_test_player_deck_id": "",
		"selected_test_opponent_deck_id": "",
		"selected_background_card_id": ""
	}


static func _normalize_store(raw_store: Dictionary) -> Dictionary:
	return {
		"version": int(raw_store.get("version", STORE_VERSION)),
		"decks": _normalize_decks(raw_store.get("decks", [])),
		"test_decks": _normalize_decks(raw_store.get("test_decks", [])),
		"selected_player_deck_id": str(raw_store.get("selected_player_deck_id", "")),
		"selected_ai_deck_id": str(raw_store.get("selected_ai_deck_id", "")),
		"selected_test_player_deck_id": str(raw_store.get("selected_test_player_deck_id", "")),
		"selected_test_opponent_deck_id": str(raw_store.get("selected_test_opponent_deck_id", "")),
		"selected_background_card_id": str(raw_store.get("selected_background_card_id", ""))
	}


static func _normalize_decks(raw_decks) -> Array[Dictionary]:
	var decks: Array[Dictionary] = []
	if not (raw_decks is Array):
		return decks
	for raw_deck in raw_decks:
		if not (raw_deck is Dictionary):
			continue
		decks.append(_normalize_deck(raw_deck))
	return decks


static func _normalize_deck(raw_deck: Dictionary) -> Dictionary:
	return {
		"id": str(raw_deck.get("id", "")),
		"name": str(raw_deck.get("name", "")).strip_edges(),
		"description": str(raw_deck.get("description", "")).strip_edges(),
		"master_id": str(raw_deck.get("master_id", "")),
		"cards": _normalize_card_ids(raw_deck.get("cards", [])),
		"created_at": int(raw_deck.get("created_at", 0)),
		"updated_at": int(raw_deck.get("updated_at", 0))
	}


static func _normalize_card_ids(raw_cards) -> Array[String]:
	var cards: Array[String] = []
	if not (raw_cards is Array):
		return cards
	for raw_card in raw_cards:
		var card_id := str(raw_card).strip_edges()
		if card_id.is_empty():
			continue
		cards.append(card_id)
	return cards


static func _set_runtime_selected_player_deck_override(deck_id: String) -> void:
	_has_runtime_selected_player_deck_override = true
	_runtime_selected_player_deck_id = str(deck_id).strip_edges()


static func _write_store(store: Dictionary) -> void:
	var resolved_path := get_store_path()
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null and (resolved_path.begins_with("user://") or resolved_path.begins_with("res://")):
		var absolute_path := ProjectSettings.globalize_path(resolved_path)
		DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_normalize_store(store), "  "))
	file.close()


static func _seed_builtin_decks(store: Dictionary) -> void:
	if not FileAccess.file_exists(BUILTIN_STARTER_PRESET_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUILTIN_STARTER_PRESET_PATH))
	if not (parsed is Dictionary):
		return
	var players = parsed.get("players", [])
	if not (players is Array) or players.size() < 2:
		return
	var builtin_decks: Array[Dictionary] = []
	for player_index in range(2):
		var player = players[player_index]
		if not (player is Dictionary):
			continue
		var deck_id := "builtin_starter_%s" % str(player_index + 1)
		var deck_name := str(player.get("name", "默认卡组%s" % str(player_index + 1)))
		builtin_decks.append({
			"id": deck_id,
			"name": deck_name,
			"description": "系统初始卡组",
			"master_id": str(player.get("master_id", "")),
			"cards": _normalize_card_ids(player.get("deck", [])),
			"created_at": 0,
			"updated_at": 0
		})
	store["decks"] = builtin_decks


static func _seed_builtin_test_decks(store: Dictionary) -> void:
	if not _is_test_mode_available():
		return
	if not FileAccess.file_exists(BUILTIN_TEST_PRESET_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUILTIN_TEST_PRESET_PATH))
	if not (parsed is Dictionary):
		return
	var players = parsed.get("players", [])
	if not (players is Array) or players.size() < 2:
		return
	var builtin_test_decks: Array[Dictionary] = []
	for player_index in range(2):
		var player = players[player_index]
		if not (player is Dictionary):
			continue
		builtin_test_decks.append({
			"id": "builtin_test_%s" % str(player_index + 1),
			"name": str(player.get("name", "测试卡组%s" % str(player_index + 1))),
			"description": "系统测试卡组",
			"master_id": str(player.get("master_id", "")),
			"cards": _normalize_card_ids(player.get("deck", [])),
			"created_at": 0,
			"updated_at": 0
		})
	store["test_decks"] = builtin_test_decks
