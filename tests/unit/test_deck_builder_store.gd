extends RefCounted
class_name TestDeckBuilderStore

const CardDatabase = preload("res://rules/core/card_database.gd")
const DeckBuilderCardPool = preload("res://client/scripts/deck_builder_card_pool.gd")
const DeckBuilderStore = preload("res://client/scripts/deck_builder_store.gd")

const FORMAL_DECK_PATH := "res://data/decks/starter_takamagahara_asgard_raw.json"
const TEST_STORE_PATH := "res://.tmp_deck_builder_test_data/deck_builder_store.json"

static func run() -> Array[String]:
	var failures: Array[String] = []
	_begin_isolated_store()
	_test_bijie_noncity_cards_are_in_formal_pool(failures)
	_test_classic_batch_3_cards_are_in_formal_pool(failures)
	_test_bijie_noncity_deck_validates_with_formal_master(failures)
	_test_bijie_masters_are_in_formal_pool_and_validate_trial_limits(failures)
	_test_asgard_batch_7_legendary_cards_validate_single_copy_limit(failures)
	_test_network_formal_duel_uses_remote_selected_deck(failures)
	_test_network_formal_duel_falls_back_to_takamagahara_when_remote_missing(failures)
	_test_network_formal_duel_falls_back_to_takamagahara_on_protocol_mismatch(failures)
	_test_runtime_player_selection_override_wins_over_shared_store(failures)
	_end_isolated_store()
	return failures

static func _begin_isolated_store() -> void:
	DeckBuilderStore.reset_runtime_selection_cache()
	DeckBuilderStore.configure_store_path(TEST_STORE_PATH)
	var absolute_path := ProjectSettings.globalize_path(TEST_STORE_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)

static func _end_isolated_store() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_STORE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	DeckBuilderStore.reset_store_path()
	DeckBuilderStore.reset_runtime_selection_cache()

static func _test_bijie_noncity_cards_are_in_formal_pool(failures: Array[String]) -> void:
	_expect(DeckBuilderCardPool.is_formal_deck_card("bijie_s02_033"), "bijie non-city card should be selectable in formal deck pool", failures)
	_expect(DeckBuilderCardPool.is_formal_deck_card("bijie_s02_058"), "bijie trial card should be selectable in formal deck pool", failures)
	_expect(not DeckBuilderCardPool.is_formal_deck_card("bijie_s02_060"), "bijie city card should not be added to formal deck pool while city cards stay out of scope", failures)

static func _test_classic_batch_3_cards_are_in_formal_pool(failures: Array[String]) -> void:
	var card_ids := [
		"neutral_s01_0003",
		"neutral_s01_0004",
		"neutral_s01_0010",
		"neutral_s01_0011",
		"neutral_s01_0013",
		"neutral_s01_0017",
		"neutral_s01_0021",
		"neutral_s02_0001",
		"neutral_s02_0006",
		"neutral_s02_0007",
		"neutral_s02_0008",
		"neutral_s02_0009",
		"neutral_s02_0010",
		"neutral_s02_0013",
		"neutral_s02_0015",
		"neutral_s02_0016",
		"neutral_s02_0017",
		"neutral_s02_0018"
	]
	for card_id in card_ids:
		_expect(DeckBuilderCardPool.is_formal_deck_card(card_id), "%s should be selectable in formal deck pool" % card_id, failures)

static func _test_bijie_noncity_deck_validates_with_formal_master(failures: Array[String]) -> void:
	var definitions := _definitions_by_id()
	var starter_players := _starter_players()
	_expect(not starter_players.is_empty(), "bijie deck validation test requires a fallback starter player", failures)
	if starter_players.is_empty():
		return
	var deck := _deck_from_player(starter_players[0], "bijie_noncity_validation")
	deck["name"] = "彼界非主城构筑校验"
	deck["cards"] = _build_bijie_noncity_cards_for_test(definitions)
	_expect(deck["cards"].size() == DeckBuilderStore.MIN_DECK_SIZE, "bijie deck validation test should assemble a legal 40-card list", failures)
	var validation := DeckBuilderStore.validate_deck(deck, definitions)
	_expect(bool(validation.get("ok", false)), "bijie non-city cards should pass formal deck validation", failures)


static func _test_bijie_masters_are_in_formal_pool_and_validate_trial_limits(failures: Array[String]) -> void:
	var definitions := _definitions_by_id()
	_expect(DeckBuilderCardPool.is_formal_master("bijie_s02_06m1"), "bijie Morrigan master should be selectable in formal master pool", failures)
	_expect(DeckBuilderCardPool.is_formal_master("bijie_s02_06m2"), "bijie Aengus master should be selectable in formal master pool", failures)
	var base_cards := _build_bijie_noncity_cards_for_test(definitions)
	var non_trial_cards: Array[String] = []
	for card_id in base_cards:
		var definition: Dictionary = definitions.get(card_id, {})
		if str(definition.get("type", "")) == "trial":
			continue
		non_trial_cards.append(card_id)
		if non_trial_cards.size() >= DeckBuilderStore.MIN_DECK_SIZE - 2:
			break
	_expect(non_trial_cards.size() == DeckBuilderStore.MIN_DECK_SIZE - 2, "bijie trial-limit test should assemble enough non-trial cards", failures)
	if non_trial_cards.size() != DeckBuilderStore.MIN_DECK_SIZE - 2:
		return
	var two_trials: Array[String] = non_trial_cards.duplicate()
	two_trials.append_array(["bijie_s02_055", "bijie_s02_058"])
	var morrigan_deck := {
		"id": "bijie_morrigan_trial_limit",
		"name": "莫瑞甘试炼限制",
		"description": "test deck",
		"master_id": "bijie_s02_06m1",
		"cards": two_trials,
		"created_at": 0,
		"updated_at": 0
	}
	var morrigan_validation := DeckBuilderStore.validate_deck(morrigan_deck, definitions)
	_expect(not bool(morrigan_validation.get("ok", false)), "bijie Morrigan should not allow carrying 2 trial cards", failures)
	var aengus_deck := morrigan_deck.duplicate(true)
	aengus_deck["id"] = "bijie_aengus_trial_limit"
	aengus_deck["name"] = "安格斯试炼限制"
	aengus_deck["master_id"] = "bijie_s02_06m2"
	var aengus_validation := DeckBuilderStore.validate_deck(aengus_deck, definitions)
	_expect(bool(aengus_validation.get("ok", false)), "bijie Aengus should allow carrying 2 trial cards", failures)

static func _test_asgard_batch_7_legendary_cards_validate_single_copy_limit(failures: Array[String]) -> void:
	var definitions := _definitions_by_id()
	var base_cards := _build_bijie_noncity_cards_for_test(definitions)
	_expect(base_cards.size() == DeckBuilderStore.MIN_DECK_SIZE, "single-copy limit test should assemble a legal 40-card base list", failures)
	if base_cards.size() != DeckBuilderStore.MIN_DECK_SIZE:
		return
	var hammer_deck := {
		"id": "asgard_hammer_single_copy_limit",
		"name": "雷神之锤单卡限制",
		"description": "test deck",
		"master_id": "asgard_s02_03m1",
		"cards": base_cards.duplicate(),
		"created_at": 0,
		"updated_at": 0
	}
	hammer_deck["cards"][0] = "asgard_s02_0301"
	hammer_deck["cards"][1] = "asgard_s02_0301"
	var hammer_validation := DeckBuilderStore.validate_deck(hammer_deck, definitions)
	_expect(not bool(hammer_validation.get("ok", false)), "雷神之锤 should be limited to 1 copy in formal deck validation", failures)
	_expect(str(hammer_validation.get("reason", "")).contains("雷神之锤"), "雷神之锤 single-copy validation should mention the card name", failures)
	var ring_deck := hammer_deck.duplicate(true)
	ring_deck["id"] = "asgard_andvaranot_single_copy_limit"
	ring_deck["name"] = "安德华拉诺特单卡限制"
	ring_deck["cards"][0] = "asgard_s02_0305"
	ring_deck["cards"][1] = "asgard_s02_0305"
	var ring_validation := DeckBuilderStore.validate_deck(ring_deck, definitions)
	_expect(not bool(ring_validation.get("ok", false)), "安德华拉诺特 should be limited to 1 copy in formal deck validation", failures)
	_expect(str(ring_validation.get("reason", "")).contains("安德华拉诺特"), "安德华拉诺特 single-copy validation should mention the card name", failures)

static func _test_network_formal_duel_uses_remote_selected_deck(failures: Array[String]) -> void:
	var definitions := _definitions_by_id()
	var starter_players := _starter_players()
	var host_deck := _deck_from_player(starter_players[1], "host_asgard")
	var remote_deck := _deck_from_player(starter_players[0], "remote_takamagahara")
	remote_deck["name"] = "加入方自选卡组"
	var remote_payload := DeckBuilderStore.build_network_player_deck_selection_from_deck(remote_deck, definitions)
	var result := DeckBuilderStore.build_network_formal_duel_from_selections(definitions, FORMAL_DECK_PATH, host_deck, remote_payload)
	_expect(bool(result.get("ok", false)), "network formal duel should build successfully with remote selected deck", failures)
	if not bool(result.get("ok", false)):
		return
	var duel_data: Dictionary = result.get("duel_data", {})
	var players: Array = duel_data.get("players", [])
	_expect(players.size() == 2, "network formal duel should contain 2 players", failures)
	if players.size() < 2:
		return
	var remote_entry: Dictionary = players[1]
	_expect(str(remote_entry.get("name", "")) == "加入方自选卡组", "network formal duel should use the remote deck name when payload is valid", failures)
	_expect(str(remote_entry.get("master_id", "")) == str(remote_deck.get("master_id", "")), "network formal duel should use the remote selected master when payload is valid", failures)
	_expect(remote_entry.get("deck", []) == remote_deck.get("cards", []), "network formal duel should use the remote selected deck list when payload is valid", failures)
	_expect(str(remote_entry.get("ai_profile_id", "")) == "", "network formal duel remote entry should not keep AI profile data", failures)

static func _test_network_formal_duel_falls_back_to_takamagahara_when_remote_missing(failures: Array[String]) -> void:
	var definitions := _definitions_by_id()
	var starter_players := _starter_players()
	var host_deck := _deck_from_player(starter_players[1], "host_asgard")
	var result := DeckBuilderStore.build_network_formal_duel_from_selections(definitions, FORMAL_DECK_PATH, host_deck, {})
	_expect(bool(result.get("ok", false)), "network formal duel should still build when remote payload is missing", failures)
	if not bool(result.get("ok", false)):
		return
	var duel_data: Dictionary = result.get("duel_data", {})
	var players: Array = duel_data.get("players", [])
	_expect(players.size() == 2, "fallback network formal duel should contain 2 players", failures)
	if players.size() < 2:
		return
	var remote_entry: Dictionary = players[1]
	var takamagahara_fallback: Dictionary = starter_players[0]
	_expect(str(remote_entry.get("master_id", "")) == str(takamagahara_fallback.get("master_id", "")), "missing remote payload should fall back to the Takamagahara starter master", failures)
	_expect(remote_entry.get("deck", []) == takamagahara_fallback.get("deck", []), "missing remote payload should fall back to the Takamagahara starter deck", failures)

static func _test_network_formal_duel_falls_back_to_takamagahara_on_protocol_mismatch(failures: Array[String]) -> void:
	var definitions := _definitions_by_id()
	var starter_players := _starter_players()
	var host_deck := _deck_from_player(starter_players[1], "host_asgard")
	var remote_deck := _deck_from_player(starter_players[1], "remote_asgard")
	var result := DeckBuilderStore.build_network_formal_duel_from_selections(definitions, FORMAL_DECK_PATH, host_deck, {
		"protocol_version": DeckBuilderStore.NETWORK_DECK_SELECTION_VERSION + 1,
		"has_deck": true,
		"deck": remote_deck
	})
	_expect(bool(result.get("ok", false)), "network formal duel should still build when remote protocol mismatches", failures)
	if not bool(result.get("ok", false)):
		return
	var duel_data: Dictionary = result.get("duel_data", {})
	var players: Array = duel_data.get("players", [])
	_expect(players.size() == 2, "protocol mismatch fallback should contain 2 players", failures)
	if players.size() < 2:
		return
	var remote_entry: Dictionary = players[1]
	var takamagahara_fallback: Dictionary = starter_players[0]
	_expect(str(remote_entry.get("master_id", "")) == str(takamagahara_fallback.get("master_id", "")), "protocol mismatch should fall back to the Takamagahara starter master", failures)
	_expect(remote_entry.get("deck", []) == takamagahara_fallback.get("deck", []), "protocol mismatch should fall back to the Takamagahara starter deck", failures)

static func _test_runtime_player_selection_override_wins_over_shared_store(failures: Array[String]) -> void:
	var definitions := _definitions_by_id()
	var starter_players := _starter_players()
	if starter_players.size() < 2:
		failures.append("runtime player selection override test requires starter players")
		return
	var original_store := DeckBuilderStore.load_store().duplicate(true)
	DeckBuilderStore.reset_runtime_selection_cache()
	var runtime_deck := _deck_from_player(starter_players[1], "runtime_host_asgard")
	runtime_deck["name"] = "房主运行时卡组"
	var shared_store_deck := _deck_from_player(starter_players[0], "shared_remote_takamagahara")
	shared_store_deck["name"] = "共享存档卡组"
	var runtime_save := DeckBuilderStore.save_deck(runtime_deck, definitions)
	var shared_save := DeckBuilderStore.save_deck(shared_store_deck, definitions)
	_expect(bool(runtime_save.get("ok", false)), "runtime override test should save the runtime deck", failures)
	_expect(bool(shared_save.get("ok", false)), "runtime override test should save the shared-store deck", failures)
	if bool(runtime_save.get("ok", false)) and bool(shared_save.get("ok", false)):
		var runtime_id := str(runtime_save.get("deck", {}).get("id", ""))
		var shared_id := str(shared_save.get("deck", {}).get("id", ""))
		DeckBuilderStore.set_selected_player_deck(runtime_id)
		_override_store_selected_player_deck_id(shared_id)
		_expect(DeckBuilderStore.get_selected_player_deck_id() == runtime_id, "runtime override should beat the shared store selected player deck id", failures)
		var payload := DeckBuilderStore.build_local_network_player_deck_selection(definitions)
		_expect(bool(payload.get("has_deck", false)), "runtime override should still produce a local network deck payload", failures)
		var payload_deck: Dictionary = payload.get("deck", {})
		_expect(str(payload_deck.get("id", "")) == runtime_id, "runtime override payload should use the instance-selected deck id", failures)
		_expect(str(payload_deck.get("name", "")) == "房主运行时卡组", "runtime override payload should use the instance-selected deck name", failures)
		DeckBuilderStore.reset_runtime_selection_cache()
		_expect(DeckBuilderStore.get_selected_player_deck_id() == shared_id, "resetting runtime selection cache should fall back to the shared store selected player deck id", failures)
	_write_store_snapshot(original_store)
	DeckBuilderStore.reset_runtime_selection_cache()

static func _definitions_by_id() -> Dictionary:
	var result := {}
	for definition in CardDatabase.load_definitions():
		if not (definition is Dictionary):
			continue
		result[str(definition.get("id", ""))] = definition
	for path in [
		"res://data/raw_rule_cards/starter_duel_master_cards.json",
		"res://data/raw_rule_cards/tianting_master_cards.json",
		"res://data/raw_rule_cards/olympus_master_cards.json",
		"res://data/raw_rule_cards/bijie_master_cards.json",
		"res://data/raw_rule_cards/suncity_master_cards.json"
	]:
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Array):
			continue
		for row in parsed:
			if not (row is Dictionary):
				continue
			result[str(row.get("id", ""))] = row
	return result

static func _starter_players() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FORMAL_DECK_PATH))
	if parsed is Dictionary:
		var players = parsed.get("players", [])
		if players is Array:
			return players
	return []

static func _deck_from_player(player: Dictionary, deck_id: String) -> Dictionary:
	return {
		"id": deck_id,
		"name": str(player.get("name", deck_id)),
		"description": "test deck",
		"master_id": str(player.get("master_id", "")),
		"cards": player.get("deck", []).duplicate(),
		"created_at": 0,
		"updated_at": 0
	}

static func _build_bijie_noncity_cards_for_test(definitions: Dictionary) -> Array[String]:
	var candidate_ids: Array[String] = []
	var sorted_ids: Array[String] = []
	for card_id in definitions.keys():
		sorted_ids.append(str(card_id))
	sorted_ids.sort()
	for card_id in sorted_ids:
		if not card_id.begins_with("bijie_s02_"):
			continue
		if card_id == "bijie_s02_060":
			continue
		if not DeckBuilderCardPool.is_formal_deck_card(card_id):
			continue
		var definition: Dictionary = definitions.get(card_id, {})
		if definition.is_empty():
			continue
		if str(definition.get("type", "")) == "token":
			continue
		candidate_ids.append(card_id)
	var deck_cards: Array[String] = []
	for card_id in candidate_ids:
		if deck_cards.size() >= DeckBuilderStore.MIN_DECK_SIZE:
			break
		var definition: Dictionary = definitions.get(card_id, {})
		var limit: int = max(1, int(definition.get("limit", 3)))
		for _copy_index in range(limit):
			if deck_cards.size() >= DeckBuilderStore.MIN_DECK_SIZE:
				break
			deck_cards.append(card_id)
	return deck_cards

static func _override_store_selected_player_deck_id(deck_id: String) -> void:
	var store := DeckBuilderStore.load_store().duplicate(true)
	store["selected_player_deck_id"] = deck_id
	_write_store_snapshot(store)

static func _write_store_snapshot(store: Dictionary) -> void:
	var resolved_path := DeckBuilderStore.get_store_path()
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null and (resolved_path.begins_with("user://") or resolved_path.begins_with("res://")):
		var absolute_path := ProjectSettings.globalize_path(resolved_path)
		DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(store, "  "))
	file.close()

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
