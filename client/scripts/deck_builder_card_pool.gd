extends RefCounted
class_name DeckBuilderCardPool

const FORMAL_DECK_CARD_PATHS := [
	"res://data/cards/starter_duel_raw_cards.json",
	"res://data/cards/classic_batch_1.json",
	"res://data/cards/classic_batch_2.json",
	"res://data/cards/classic_batch_3.json",
	"res://data/cards/takamagahara_asgard_batch_0.json",
	"res://data/cards/takamagahara_asgard_batch_1.json",
	"res://data/cards/takamagahara_asgard_batch_2.json",
	"res://data/cards/asgard_batch_3.json",
	"res://data/cards/asgard_batch_4.json",
	"res://data/cards/asgard_batch_5.json",
	"res://data/cards/asgard_batch_6.json",
	"res://data/cards/asgard_batch_7.json",
	"res://data/cards/takamagahara_batch_3.json",
	"res://data/cards/takamagahara_batch_4.json",
	"res://data/cards/takamagahara_batch_5.json",
	"res://data/cards/takamagahara_batch_6.json",
	"res://data/cards/takamagahara_batch_7.json",
	"res://data/cards/takamagahara_batch_8.json",
	"res://data/cards/tianting_batch_1.json",
	"res://data/cards/olympus_batch_1.json",
	"res://data/cards/olympus_batch_2.json",
	"res://data/cards/olympus_batch_3.json",
	"res://data/cards/olympus_batch_4.json",
	"res://data/cards/olympus_batch_5.json",
	"res://data/cards/olympus_batch_6.json",
	"res://data/cards/olympus_batch_7.json",
	"res://data/cards/olympus_batch_8.json",
	"res://data/cards/bijie_batch_1.json",
	"res://data/cards/bijie_batch_2.json",
	"res://data/cards/bijie_batch_3.json",
	"res://data/cards/bijie_batch_4.json",
	"res://data/cards/bijie_batch_5.json",
	"res://data/cards/bijie_batch_6.json",
	"res://data/cards/bijie_batch_7.json",
	"res://data/cards/bijie_batch_8.json",
	"res://data/cards/suncity_batch_1.json",
]
const EXTRA_FORMAL_DECK_CARD_IDS := [
	"neutral_s01_0019",
	"neutral_s02_0004",
	"asgard_s01_0302",
	"asgard_s01_0313",
	"asgard_s01_0315",
	"takamagahara_s01_0404",
]
const FORMAL_MASTER_CARD_PATHS := [
	"res://data/raw_rule_cards/starter_duel_master_cards.json",
	"res://data/raw_rule_cards/tianting_master_cards.json",
	"res://data/raw_rule_cards/olympus_master_cards.json",
	"res://data/raw_rule_cards/bijie_master_cards.json",
	"res://data/raw_rule_cards/suncity_master_cards.json",
]
const ALLOWED_FACTIONS := ["takamagahara", "asgard", "tianting", "olympus", "bijie", "suncity", "neutral"]
const EXCLUDED_CARD_ID_PREFIXES := ["qa_", "dev_", "demo_", "sys_", "calamity_"]
const EXCLUDED_CARD_TYPES := ["morale", "calamity"]

static var _loaded := false
static var _formal_deck_card_ids := {}
static var _formal_master_ids := {}


static func get_formal_deck_card_ids() -> Array[String]:
	_ensure_loaded()
	return _sorted_keys(_formal_deck_card_ids)


static func get_formal_master_ids() -> Array[String]:
	_ensure_loaded()
	return _sorted_keys(_formal_master_ids)


static func is_formal_deck_card(card_id: String) -> bool:
	_ensure_loaded()
	return _formal_deck_card_ids.has(card_id)


static func is_formal_master(card_id: String) -> bool:
	_ensure_loaded()
	return _formal_master_ids.has(card_id)


static func summary() -> Dictionary:
	_ensure_loaded()
	return {
		"master_count": _formal_master_ids.size(),
		"deck_card_count": _formal_deck_card_ids.size()
	}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_formal_deck_card_ids.clear()
	_formal_master_ids.clear()
	for path in FORMAL_DECK_CARD_PATHS:
		_load_file_into_pool(path, false)
	for card_id in EXTRA_FORMAL_DECK_CARD_IDS:
		_formal_deck_card_ids[card_id] = true
	for path in FORMAL_MASTER_CARD_PATHS:
		_load_file_into_pool(path, true)
	_loaded = true


static func _load_file_into_pool(path: String, master_only: bool) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Array):
		return
	for row in parsed:
		if not (row is Dictionary):
			continue
		var card_id := str(row.get("id", "")).strip_edges()
		if card_id.is_empty():
			continue
		var faction := str(row.get("faction", "")).strip_edges()
		if not ALLOWED_FACTIONS.has(faction):
			continue
		var is_master := str(row.get("kind", "")) == "master"
		if master_only:
			if is_master:
				_formal_master_ids[card_id] = true
			continue
		if is_master:
			continue
		if _is_excluded_card_id(card_id):
			continue
		var card_type := str(row.get("type", "")).strip_edges()
		if EXCLUDED_CARD_TYPES.has(card_type):
			continue
		_formal_deck_card_ids[card_id] = true


static func _is_excluded_card_id(card_id: String) -> bool:
	for prefix in EXCLUDED_CARD_ID_PREFIXES:
		if card_id.begins_with(prefix):
			return true
	return false


static func _sorted_keys(source: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for raw_key in source.keys():
		keys.append(str(raw_key))
	keys.sort()
	return keys
