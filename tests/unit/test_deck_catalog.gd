extends RefCounted
class_name TestDeckCatalog

const CardDatabase = preload("res://rules/core/card_database.gd")
const DeckCatalog = preload("res://rules/core/deck_catalog.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_load_demo_preset(failures)
	_test_demo_preset_can_create_game(failures)
	return failures

static func _test_load_demo_preset(failures: Array[String]) -> void:
	var preset = DeckCatalog.load_duel_preset("demo_starter_duel")
	_expect(not preset.is_empty(), "demo starter duel preset should load", failures)
	var players: Array = preset.get("players", [])
	_expect(players.size() == 2, "demo preset should define exactly 2 players", failures)
	if players.size() != 2:
		return
	for player_index in range(players.size()):
		var deck: Array = players[player_index].get("deck", [])
		_expect(deck.size() == 40, "demo preset player %s should use a 40-card deck" % player_index, failures)
		var has_expected_faction_card := false
		for card_id in deck:
			var id_text = str(card_id)
			_expect(not id_text.begins_with("demo_"), "demo preset player %s should no longer use legacy demo_* cards" % player_index, failures)
			if player_index == 0 and id_text.begins_with("takamagahara_"):
				has_expected_faction_card = true
			if player_index == 1 and id_text.begins_with("asgard_"):
				has_expected_faction_card = true
		_expect(has_expected_faction_card, "demo preset player %s should include the expected faction cards" % player_index, failures)

static func _test_demo_preset_can_create_game(failures: Array[String]) -> void:
	var definitions = CardDatabase.load_definitions()
	var resolved = DeckCatalog.resolve_duel_preset("demo_starter_duel", definitions)
	_expect(resolved.get("ok", false), "demo preset should resolve against current card data", failures)
	if not resolved.get("ok", false):
		return
	var definitions_by_id := {}
	for definition in definitions:
		definitions_by_id[str(definition.get("id", ""))] = definition
	var preset: Dictionary = resolved.get("preset", {})
	var decks: Array = resolved.get("decks", [])
	_expect(decks.size() == 2, "resolved demo preset should expose 2 deck lists", failures)
	if decks.size() != 2:
		return
	_expect(int(definitions_by_id.get("takamagahara_s01_0401", {}).get("cost", -1)) == 8, "本多忠胜 cost should be imported as 8", failures)
	_expect(int(definitions_by_id.get("takamagahara_s01_0401", {}).get("calamity_level", -1)) == 3, "本多忠胜 calamity level should be imported as 3", failures)
	_expect(int(definitions_by_id.get("takamagahara_s01_0404", {}).get("calamity_level", -1)) == 1, "真田幸村 calamity level should be imported as 1", failures)
	_expect(int(definitions_by_id.get("takamagahara_s01_0405", {}).get("calamity_level", -1)) == 1, "宫本武藏 calamity level should be imported as 1", failures)
	_expect(int(definitions_by_id.get("asgard_s01_0303", {}).get("cost", -1)) == 6, "传奇的拉格纳 cost should be imported as 6", failures)
	_expect(int(definitions_by_id.get("asgard_s01_0303", {}).get("calamity_level", -1)) == 2, "传奇的拉格纳 calamity level should be imported as 2", failures)
	_expect(int(definitions_by_id.get("asgard_s01_0312", {}).get("calamity_level", -1)) == 0, "铁盾拉葛莎 calamity level should be imported as 0", failures)
	_expect(int(definitions_by_id.get("neutral_s01_0001", {}).get("calamity_level", -1)) == 2, "黑胡子蒂奇 calamity level should be imported as 2", failures)
	_expect(int(definitions_by_id.get("neutral_s01_0015", {}).get("cost", -1)) == 0, "议和谈判 cost should be imported as 0", failures)
	_expect(int(definitions_by_id.get("takamagahara_s01_0417", {}).get("cost", -1)) == 3, "草薙剑 cost should be imported as 3", failures)
	var engine = GameEngine.new()
	var state = engine.create_game(definitions, decks, 1201, preset.get("players", []))
	_expect(state.initial_decks.size() == 2, "game state should keep both initial demo decks", failures)
	_expect(state.initial_decks[0].size() == 40, "player 1 initial demo deck should contain 40 cards", failures)
	_expect(state.initial_decks[1].size() == 40, "player 2 initial demo deck should contain 40 cards", failures)
	_expect(state.players[0].deck.cards.size() == 35, "player 1 live deck should contain 35 cards after opening draw", failures)
	_expect(state.players[1].deck.cards.size() == 35, "player 2 live deck should contain 35 cards after opening draw", failures)
	_expect(state.players[0].name == "高天原·除魔物语", "player 1 name should come from preset metadata", failures)
	_expect(state.players[1].name == "阿斯加德·万千面相", "player 2 name should come from preset metadata", failures)
	_expect(state.players[0].master_name == "须佐之男", "player 1 master name should come from preset metadata", failures)
	_expect(state.players[1].master_name == "洛基", "player 2 master name should come from preset metadata", failures)
	_expect(state.players[0].master_definition_id == "takamagahara_s01_04m2", "player 1 master id should come from preset metadata", failures)
	_expect(state.players[1].master_definition_id == "asgard_s01_03m2a", "player 2 master id should come from preset metadata", failures)
	_expect(state.players[0].master_hp == 9 and state.players[0].master_max_hp == 9, "player 1 master hp should come from preset metadata", failures)
	_expect(state.players[1].master_hp == 12 and state.players[1].master_max_hp == 12, "player 2 master hp should come from preset metadata", failures)

static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
