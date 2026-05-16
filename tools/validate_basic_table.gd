extends SceneTree

const MainScene = preload("res://client/scenes/main.tscn")

func _initialize() -> void:
	var failures: Array[String] = []
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	_expect(scene._hands.size() == 2, "should create two hands", failures)
	_expect(scene._table_slots.size() == 5, "should create five table slots", failures)
	if scene._hands.size() < 2 or scene._table_slots.is_empty():
		_finish(failures)
		return

	_expect(scene._hands[0].get_card_count() == 6, "player 1 should start with six cards", failures)
	_expect(scene._hands[1].get_card_count() == 6, "player 2 should start with six cards", failures)

	var active_hand = scene._hands[0]
	var first_slot = scene._table_slots[0]
	var cards_node = active_hand.get_node("Cards")
	_expect(cards_node.get_child_count() > 0, "active hand should contain card nodes", failures)
	if cards_node.get_child_count() > 0:
		var card = cards_node.get_child(0)
		var moved = first_slot.move_cards([card])
		_expect(moved, "card should move from hand to table slot", failures)
		_expect(active_hand.get_card_count() == 5, "moving card should reduce hand size", failures)
		_expect(first_slot.get_card_count() == 1, "table slot should receive the card", failures)

	scene._end_turn()
	_expect(scene._active_player == 1, "end turn should switch active player", failures)
	_expect(scene._hands[0].visible == false, "player 1 hand should hide after turn switch", failures)
	_expect(scene._hands[1].visible == true, "player 2 hand should show after turn switch", failures)

	_finish(failures)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("basic table validation passed")
		quit(0)
		return
	for message in failures:
		push_error(message)
	quit(1)
