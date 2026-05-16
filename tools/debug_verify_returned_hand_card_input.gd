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
		push_error("returned hand card input verify: state should not be null")
		quit(1)
		return
	var player = table._state.get_player(0)
	if player.hand.cards.is_empty():
		push_error("returned hand card input verify: player hand should not be empty")
		quit(1)
		return
	var card_id := str(player.hand.cards[0])
	if not player.hand.remove_card(card_id):
		push_error("returned hand card input verify: failed to remove test card from hand")
		quit(1)
		return
	player.grave.add_card_to_top(card_id)
	var instance = table._state.card_instances.get(card_id, null)
	if instance != null:
		instance.zone = "grave"
		instance.position = {}
	table._sync_from_engine()
	table._refresh()
	var grave_view = table._card_views_by_uid.get(card_id, null)
	if grave_view == null:
		push_error("returned hand card input verify: grave view should exist")
		quit(1)
		return
	if int(grave_view.mouse_filter) != Control.MOUSE_FILTER_IGNORE:
		push_error("returned hand card input verify: grave view should ignore input")
		quit(1)
		return
	if not player.grave.remove_card(card_id):
		push_error("returned hand card input verify: failed to remove test card from grave")
		quit(1)
		return
	player.hand.add_card(card_id)
	if instance != null:
		instance.zone = "hand"
		instance.position = {}
		instance.controller = instance.owner
	table._sync_from_engine()
	table._refresh()
	var hand_view = table._card_views_by_uid.get(card_id, null)
	if hand_view == null:
		push_error("returned hand card input verify: hand view should exist")
		quit(1)
		return
	if int(hand_view.mouse_filter) != Control.MOUSE_FILTER_STOP:
		push_error("returned hand card input verify: hand view should accept input after returning from grave")
		quit(1)
		return
	print("returned hand card input verify passed")
	quit(0)
