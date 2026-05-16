extends SceneTree

const BattleTable = preload("res://client/scripts/battle_table.gd")

func _initialize() -> void:
	var table = BattleTable.new()
	root.add_child(table)
	await process_frame
	await process_frame
	table._on_start_test_pressed()
	await process_frame
	await process_frame
	if table._state == null:
		push_error("start test duel verify: state should not be null after pressing start test")
		quit(1)
		return
	if table._state.calamity_deck.is_empty():
		push_error("start test duel verify: calamity deck should not be empty")
		quit(1)
		return
	var first_calamity := str(table._state.calamity_deck[0])
	if first_calamity != "calamity_s01_ds04":
		push_error("start test duel verify: expected first calamity to be calamity_s01_ds04, got %s" % first_calamity)
		quit(1)
		return
	print("start test duel verify first calamity=%s" % first_calamity)
	print("start test duel verify passed")
	quit(0)
