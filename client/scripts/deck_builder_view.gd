extends Control
class_name DeckBuilderView

signal back_requested
signal decks_changed(message: String)
signal background_changed(message: String)

const DeckBuilderStore = preload("res://client/scripts/deck_builder_store.gd")
const DeckBuilderCardPool = preload("res://client/scripts/deck_builder_card_pool.gd")
const CardGalleryCatalog = preload("res://client/scripts/card_gallery_catalog.gd")
const RULE_START_BACKGROUND_PATH := "res://client/assets/start_background.png"
const USER_BACKGROUND_OUTPUT_PATH := "user://custom_start_background.png"
const NO_TEST_MODE_FEATURE := "no_test_mode"

const VIEW_HOME := "home"
const VIEW_CREATE := "create"
const VIEW_LIST := "list"
const VIEW_TEST_LIST := "test_list"
const VIEW_PLAYER := "player"
const VIEW_AI := "ai"
const VIEW_GALLERY := "gallery"
const FIRST_PAGE_SYNC_COUNT := 12
const CARD_RENDER_BATCH_SIZE := 12
const LAZY_IMAGE_BATCH_SIZE := 4
const BACKGROUND_PREWARM_BATCH_SIZE := 2
const SCROLL_RENDER_TRIGGER_PX := 240

var _card_definitions: Dictionary = {}
var _master_ids: Array[String] = []
var _library_card_ids: Array[String] = []
var _gallery_entries: Array[Dictionary] = []

var _current_view := VIEW_HOME
var _editing_deck_id := ""
var _editing_deck_mode := "formal"
var _create_return_view := VIEW_HOME
var _selected_card_ids: Array[String] = []
var _selected_master_id := ""
var _create_view_dirty := true
var _list_view_dirty := true
var _test_list_view_dirty := true
var _player_view_dirty := true
var _ai_view_dirty := true
var _gallery_filters_dirty := true
var _gallery_grid_dirty := true

var _title_label: Label
var _message_label: Label
var _gallery_reset_button: Button
var _back_button: Button
var _background_texture_rect: TextureRect

var _home_view: Control
var _create_view: Control
var _list_view: Control
var _test_list_view: Control
var _player_view: Control
var _ai_view: Control
var _gallery_view: Control
var _detail_overlay: Control
var _detail_title_label: Label
var _detail_summary_label: Label
var _detail_master_box: VBoxContainer
var _detail_card_grid: GridContainer
var _preview_overlay: Control
var _preview_dimmer: Control
var _preview_panel: PanelContainer
var _preview_click_target: Button
var _preview_apply_button: Button
var _preview_texture: TextureRect
var _settings_overlay: Control
var _settings_title_label: Label
var _settings_primary_button: Button
var _settings_secondary_button: Button
var _settings_tertiary_button: Button
var _settings_target_deck_id := ""
var _settings_target_deck_mode := "formal"
var _settings_target_role := ""
var _settings_target_card_id := ""
var _hold_preview_serial := 0
var _create_scroll: ScrollContainer
var _list_scroll: ScrollContainer
var _player_scroll: ScrollContainer
var _ai_scroll: ScrollContainer
var _gallery_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _touch_scroll_active := false
var _touch_scroll_started := false
var _touch_scroll_distance := 0.0
var _touch_scroll_last_position := Vector2.ZERO
var _touch_scroll_target: ScrollContainer

var _create_name_edit: LineEdit
var _create_desc_edit: LineEdit
var _create_search_edit: LineEdit
var _create_master_faction_chip_box: HFlowContainer
var _create_faction_chip_box: HFlowContainer
var _create_type_chip_box: HFlowContainer
var _create_master_box: VBoxContainer
var _create_master_cards_box: VBoxContainer
var _create_card_grid: GridContainer
var _create_selected_box: VBoxContainer
var _create_summary_label: Label
var _create_error_label: Label
var _create_submit_button: Button
var _selected_master_faction := ""
var _selected_create_faction := ""
var _selected_create_type := ""

var _list_box: VBoxContainer
var _test_list_box: VBoxContainer
var _player_current_box: VBoxContainer
var _player_list_box: VBoxContainer
var _ai_current_box: VBoxContainer
var _ai_list_box: VBoxContainer
var _gallery_search_edit: LineEdit
var _gallery_faction_chip_box: GridContainer
var _gallery_type_chip_box: GridContainer
var _gallery_grid: GridContainer
var _gallery_summary_label: Label
var _selected_gallery_faction := ""
var _selected_gallery_type := ""
var _texture_cache := {}
var _gallery_entry_by_source_code: Dictionary = {}
var _gallery_entry_by_name: Dictionary = {}
var _gallery_render_serial := 0
var _gallery_pending_entries: Array[Dictionary] = []
var _gallery_pending_background_id := ""
var _gallery_rendered_count := 0
var _create_render_serial := 0
var _create_pending_card_ids: Array[String] = []
var _create_rendered_count := 0
var _lazy_image_serial := 0
var _lazy_image_jobs: Array[Dictionary] = []
var _lazy_image_pump_scheduled := false
var _background_prewarm_started := false
var _background_prewarm_jobs: Array[String] = []
var _background_prewarm_scheduled := false


func _is_test_deck_module_available() -> bool:
	return not OS.has_feature(NO_TEST_MODE_FEATURE)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _input(event: InputEvent) -> void:
	if not OS.has_feature("android"):
		return
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_scroll_last_position = event.position
			_touch_scroll_target = _pick_scroll_target(event.position)
			_touch_scroll_active = _touch_scroll_target != null
			_touch_scroll_started = false
			_touch_scroll_distance = 0.0
		else:
			_touch_scroll_active = false
			_touch_scroll_started = false
			_touch_scroll_distance = 0.0
			_touch_scroll_target = null
		return
	if event is InputEventScreenDrag:
		if not _touch_scroll_active:
			return
		_touch_scroll_distance += absf(event.relative.y)
		if not _touch_scroll_started and _touch_scroll_distance >= 8.0:
			_touch_scroll_started = true
			_hold_preview_serial += 1
		if _touch_scroll_started:
			_scroll_vertical_by(_touch_scroll_target, event.relative.y)
		_touch_scroll_last_position = event.position
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_scroll_last_position = event.position
			_touch_scroll_target = _pick_scroll_target(event.position)
			_touch_scroll_active = _touch_scroll_target != null
			_touch_scroll_started = false
			_touch_scroll_distance = 0.0
		else:
			_touch_scroll_active = false
			_touch_scroll_started = false
			_touch_scroll_distance = 0.0
			_touch_scroll_target = null
		return
	if event is InputEventMouseMotion:
		if not _touch_scroll_active:
			return
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		_touch_scroll_distance += absf(event.relative.y)
		if not _touch_scroll_started and _touch_scroll_distance >= 8.0:
			_touch_scroll_started = true
			_hold_preview_serial += 1
		if _touch_scroll_started:
			_scroll_vertical_by(_touch_scroll_target, event.relative.y)
		_touch_scroll_last_position = event.position
		return


func setup(card_definitions: Dictionary) -> void:
	_card_definitions = card_definitions.duplicate(true)
	_background_prewarm_started = false
	_background_prewarm_jobs.clear()
	_background_prewarm_scheduled = false
	_master_ids.clear()
	_library_card_ids.clear()
	_gallery_entries = CardGalleryCatalog.get_entries()
	_rebuild_gallery_entry_indexes()
	_sort_gallery_entries()
	for master_id in DeckBuilderCardPool.get_formal_master_ids():
		var master_definition = _card_definitions.get(master_id, {})
		if not (master_definition is Dictionary):
			continue
		_master_ids.append(master_id)
	for card_id in DeckBuilderCardPool.get_formal_deck_card_ids():
		var definition = _card_definitions.get(card_id, {})
		if not (definition is Dictionary):
			continue
		_library_card_ids.append(card_id)
	_master_ids.sort_custom(func(left: String, right: String) -> bool:
		return _card_name(left) < _card_name(right)
	)
	_library_card_ids.sort_custom(func(left: String, right: String) -> bool:
		var left_priority := _library_sort_priority(left)
		var right_priority := _library_sort_priority(right)
		if left_priority != right_priority:
			return left_priority < right_priority
		var left_cost := int(_definition(left).get("cost", 0))
		var right_cost := int(_definition(right).get("cost", 0))
		if left_cost != right_cost:
			return left_cost < right_cost
		return _card_name(left) < _card_name(right)
	)
	_mark_all_views_dirty()
	_message_label.text = "卡组构筑已就绪。"


func start_background_prewarm() -> void:
	if _background_prewarm_started:
		return
	_background_prewarm_started = true
	var queued := {}
	for master_id in _master_ids:
		_push_background_prewarm_path(queued, _card_image_path(master_id))
	for index in range(mini(FIRST_PAGE_SYNC_COUNT, _library_card_ids.size())):
		_push_background_prewarm_path(queued, _card_image_path(_library_card_ids[index]))
	for index in range(mini(FIRST_PAGE_SYNC_COUNT, _gallery_entries.size())):
		_push_background_prewarm_path(queued, _gallery_display_path(_gallery_entries[index]))
	if _background_prewarm_jobs.is_empty():
		return
	_background_prewarm_scheduled = true
	call_deferred("_process_background_prewarm_jobs")


func _rebuild_gallery_entry_indexes() -> void:
	_gallery_entry_by_source_code.clear()
	_gallery_entry_by_name.clear()
	for raw_entry in _gallery_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var source_code := str(entry.get("source_code", "")).strip_edges().to_upper()
		if not source_code.is_empty() and not _gallery_entry_by_source_code.has(source_code):
			_gallery_entry_by_source_code[source_code] = entry
		var entry_name := _normalize_catalog_name(str(entry.get("name", "")))
		if not entry_name.is_empty() and not _gallery_entry_by_name.has(entry_name):
			_gallery_entry_by_name[entry_name] = entry


func _sort_gallery_entries() -> void:
	_gallery_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority := _gallery_sort_priority(left)
		var right_priority := _gallery_sort_priority(right)
		if left_priority != right_priority:
			return left_priority < right_priority
		var left_calamity := _is_calamity_gallery_entry(left)
		var right_calamity := _is_calamity_gallery_entry(right)
		if left_calamity != right_calamity:
			return not left_calamity
		var left_faction := str(left.get("faction", ""))
		var right_faction := str(right.get("faction", ""))
		if left_faction != right_faction:
			return left_faction < right_faction
		var left_type := str(left.get("type", ""))
		var right_type := str(right.get("type", ""))
		if left_type != right_type:
			return left_type < right_type
		var left_no := str(left.get("card_no", ""))
		var right_no := str(right.get("card_no", ""))
		if left_no != right_no:
			return left_no < right_no
		return str(left.get("name", "")) < str(right.get("name", ""))
	)


func _is_calamity_gallery_entry(entry: Dictionary) -> bool:
	var faction := str(entry.get("faction", ""))
	var card_type := str(entry.get("type", ""))
	return faction == "天灾" or card_type.contains("天灾")


func _is_trial_gallery_entry(entry: Dictionary) -> bool:
	var card_type := str(entry.get("type", ""))
	return card_type == "trial" or card_type.contains("试炼")


func _gallery_sort_priority(entry: Dictionary) -> int:
	if _is_trial_gallery_entry(entry):
		return 2
	if _is_calamity_gallery_entry(entry):
		return 1
	return 0


func _library_sort_priority(card_id: String) -> int:
	var card_type := str(_definition(card_id).get("type", ""))
	if card_type == "trial":
		return 1
	return 0


func open_view() -> void:
	visible = true
	_refresh_background()
	_show_view(VIEW_HOME)


func close_view() -> void:
	visible = false
	_hide_detail()
	_hide_card_preview()


func _build_ui() -> void:
	_background_texture_rect = TextureRect.new()
	_background_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background_texture_rect.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(_background_texture_rect)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.24)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var shell := Panel.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 20
	shell.offset_top = 20
	shell.offset_right = -20
	shell.offset_bottom = -20
	shell.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.05, 0.07, 0.14), Color(0.90, 0.82, 0.48, 0.56), 1, 14))
	add_child(shell)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 16
	root.offset_right = -16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 12)
	shell.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var header_left := VBoxContainer.new()
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_left)

	_title_label = _make_label("", 22, HORIZONTAL_ALIGNMENT_LEFT)
	header_left.add_child(_title_label)
	_message_label = _make_label("", 12, HORIZONTAL_ALIGNMENT_LEFT)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_left.add_child(_message_label)

	_gallery_reset_button = _make_button("恢复默认背景")
	_gallery_reset_button.custom_minimum_size = Vector2(144, 42)
	_gallery_reset_button.visible = false
	_gallery_reset_button.pressed.connect(_clear_background_selection)
	header.add_child(_gallery_reset_button)

	_back_button = _make_button("返回")
	_back_button.custom_minimum_size = Vector2(96, 42)
	_back_button.pressed.connect(_on_back_pressed)
	header.add_child(_back_button)

	var content := Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	_home_view = _build_home_view()
	_create_view = _build_create_view()
	_list_view = _build_list_view()
	_test_list_view = _build_test_list_view() if _is_test_deck_module_available() else Control.new()
	_player_view = _build_role_view(true)
	_ai_view = _build_role_view(false)
	_gallery_view = _build_gallery_view()

	for view in [_home_view, _create_view, _list_view, _test_list_view, _player_view, _ai_view, _gallery_view]:
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.visible = false
		content.add_child(view)

	_detail_overlay = _build_detail_overlay()
	add_child(_detail_overlay)
	_preview_overlay = _build_preview_overlay()
	add_child(_preview_overlay)
	_settings_overlay = _build_settings_overlay()
	add_child(_settings_overlay)


func _build_home_view() -> Control:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)

	root.add_child(_module_button("卡牌图鉴", VIEW_GALLERY))
	root.add_child(_module_button("创建卡组", VIEW_CREATE))
	root.add_child(_module_button("卡组列表", VIEW_LIST))
	if _is_test_deck_module_available():
		root.add_child(_module_button("测试卡组", VIEW_TEST_LIST))
	root.add_child(_module_button("玩家卡组", VIEW_PLAYER))
	root.add_child(_module_button("人机卡组", VIEW_AI))

	return root


func _build_create_view() -> Control:
	var scroll := ScrollContainer.new()
	_create_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.get_v_scroll_bar().value_changed.connect(_on_create_scroll_changed)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, 1200)
	root.add_theme_constant_override("separation", 12)
	scroll.add_child(root)

	var info_panel := _panel_container("信息")
	root.add_child(info_panel["panel"])
	var info_box: VBoxContainer = info_panel["body"]
	_create_name_edit = LineEdit.new()
	_create_name_edit.placeholder_text = "输入卡组名称"
	info_box.add_child(_field_row("卡组名称", _create_name_edit))
	_create_desc_edit = LineEdit.new()
	_create_desc_edit.placeholder_text = "输入卡组介绍"
	info_box.add_child(_field_row("卡组介绍", _create_desc_edit))

	_create_summary_label = _make_label("", 12, HORIZONTAL_ALIGNMENT_LEFT)
	_create_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(_create_summary_label)

	var master_panel := _panel_container("选择主宰")
	root.add_child(master_panel["panel"])
	_create_master_faction_chip_box = HFlowContainer.new()
	_create_master_faction_chip_box.add_theme_constant_override("h_separation", 8)
	_create_master_faction_chip_box.add_theme_constant_override("v_separation", 8)
	master_panel["body"].add_child(_create_master_faction_chip_box)
	_create_master_cards_box = VBoxContainer.new()
	_create_master_cards_box.add_theme_constant_override("separation", 8)
	master_panel["body"].add_child(_create_master_cards_box)
	_create_master_box = _create_master_cards_box

	var card_panel := _panel_container("选择卡牌")
	root.add_child(card_panel["panel"])
	var card_box: VBoxContainer = card_panel["body"]
	_create_faction_chip_box = HFlowContainer.new()
	_create_faction_chip_box.add_theme_constant_override("h_separation", 8)
	_create_faction_chip_box.add_theme_constant_override("v_separation", 8)
	card_box.add_child(_create_faction_chip_box)
	_create_type_chip_box = HFlowContainer.new()
	_create_type_chip_box.add_theme_constant_override("h_separation", 8)
	_create_type_chip_box.add_theme_constant_override("v_separation", 8)
	card_box.add_child(_create_type_chip_box)
	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 8)
	card_box.add_child(filter_bar)
	_create_search_edit = LineEdit.new()
	_create_search_edit.placeholder_text = "搜索名称、阵营、类型"
	_create_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_search_edit.text_changed.connect(func(_value: String) -> void:
		_mark_create_view_dirty()
		_refresh_create_view()
	)
	filter_bar.add_child(_create_search_edit)
	_create_card_grid = GridContainer.new()
	_create_card_grid.columns = 3
	_create_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_card_grid.add_theme_constant_override("h_separation", 6)
	_create_card_grid.add_theme_constant_override("v_separation", 8)
	card_box.add_child(_create_card_grid)

	var selected_panel := _panel_container("已选卡牌")
	root.add_child(selected_panel["panel"])
	_create_selected_box = selected_panel["body"]

	_create_error_label = _make_label("", 12, HORIZONTAL_ALIGNMENT_LEFT)
	_create_error_label.add_theme_color_override("font_color", Color(1.0, 0.74, 0.74, 1.0))
	_create_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_create_error_label)

	_create_submit_button = _make_button("创建卡组")
	_create_submit_button.custom_minimum_size = Vector2(0, 48)
	_create_submit_button.pressed.connect(_save_current_deck)
	root.add_child(_create_submit_button)

	return scroll


func _build_list_view() -> Control:
	var scroll := ScrollContainer.new()
	_list_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.custom_minimum_size = Vector2(0, 720)
	_list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_list_box)
	return scroll


func _build_test_list_view() -> Control:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)

	var create_button := _action_button("创建卡组", _open_test_create_view, true)
	create_button.custom_minimum_size = Vector2(0, 46)
	root.add_child(create_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.custom_minimum_size = Vector2(0, 720)
	list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(list_box)
	_test_list_box = list_box
	return root


func _build_role_view(for_player: bool) -> Control:
	var scroll := ScrollContainer.new()
	if for_player:
		_player_scroll = scroll
	else:
		_ai_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, 900)
	root.add_theme_constant_override("separation", 12)
	scroll.add_child(root)

	var current_panel := _panel_container("当前卡组")
	root.add_child(current_panel["panel"])
	if for_player:
		_player_current_box = current_panel["body"]
	else:
		_ai_current_box = current_panel["body"]

	var list_panel := _panel_container("卡组列表")
	root.add_child(list_panel["panel"])
	if for_player:
		_player_list_box = list_panel["body"]
	else:
		_ai_list_box = list_panel["body"]

	return scroll


func _build_gallery_view() -> Control:
	var scroll := ScrollContainer.new()
	_gallery_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.get_v_scroll_bar().value_changed.connect(_on_gallery_scroll_changed)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, 1200)
	root.add_theme_constant_override("separation", 12)
	scroll.add_child(root)

	var filter_panel := _panel_container("筛选")
	root.add_child(filter_panel["panel"])
	var filter_box: VBoxContainer = filter_panel["body"]
	filter_box.add_theme_constant_override("separation", 12)
	_gallery_summary_label = _make_subtle_label("", 12, HORIZONTAL_ALIGNMENT_LEFT)
	_gallery_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gallery_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_box.add_child(_gallery_summary_label)
	_gallery_faction_chip_box = GridContainer.new()
	_gallery_faction_chip_box.columns = 4
	_gallery_faction_chip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_faction_chip_box.add_theme_constant_override("h_separation", 10)
	_gallery_faction_chip_box.add_theme_constant_override("v_separation", 10)
	filter_box.add_child(_gallery_faction_chip_box)
	_gallery_type_chip_box = GridContainer.new()
	_gallery_type_chip_box.columns = 4
	_gallery_type_chip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_type_chip_box.add_theme_constant_override("h_separation", 10)
	_gallery_type_chip_box.add_theme_constant_override("v_separation", 10)
	filter_box.add_child(_gallery_type_chip_box)
	_gallery_search_edit = LineEdit.new()
	_gallery_search_edit.placeholder_text = "搜索卡名、编号、阵营、种类"
	_gallery_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_search_edit.custom_minimum_size = Vector2(0, 42)
	_gallery_search_edit.text_changed.connect(func(_value: String) -> void:
		_rebuild_gallery_grid()
	)
	filter_box.add_child(_gallery_search_edit)

	var cards_panel := _panel_container("全部卡牌")
	root.add_child(cards_panel["panel"])
	_gallery_grid = GridContainer.new()
	_gallery_grid.columns = 3
	_gallery_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_grid.add_theme_constant_override("h_separation", 6)
	_gallery_grid.add_theme_constant_override("v_separation", 8)
	cards_panel["body"].add_child(_gallery_grid)

	return scroll


func _build_detail_overlay() -> Control:
	var overlay := Control.new()
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 999

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.07, 0.10, 0.98), Color(0.90, 0.82, 0.48, 0.55), 2, 14))
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_detail_title_label = _make_label("卡组详情", 20, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_detail_title_label)
	_detail_summary_label = _make_subtle_label("", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_detail_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_summary_label)

	var scroll := ScrollContainer.new()
	_detail_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var detail_content := VBoxContainer.new()
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 12)
	scroll.add_child(detail_content)

	var master_panel := _panel_container("主宰")
	detail_content.add_child(master_panel["panel"])
	_detail_master_box = master_panel["body"]

	var cards_panel := _panel_container("卡牌列表")
	detail_content.add_child(cards_panel["panel"])
	_detail_card_grid = GridContainer.new()
	_detail_card_grid.columns = 2
	_detail_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_card_grid.add_theme_constant_override("h_separation", 10)
	_detail_card_grid.add_theme_constant_override("v_separation", 10)
	cards_panel["body"].add_child(_detail_card_grid)

	var close_button := _make_button("关闭")
	close_button.pressed.connect(_hide_detail)
	box.add_child(close_button)

	return overlay


func _build_preview_overlay() -> Control:
	var overlay := Control.new()
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1000

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_card_preview()
	)
	overlay.add_child(dim)
	_preview_dimmer = dim

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.07, 0.10, 0.98), Color(0.90, 0.82, 0.48, 0.55), 2, 16))
	center.add_child(panel)
	_preview_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_preview_click_target = Button.new()
	_preview_click_target.flat = true
	_preview_click_target.focus_mode = Control.FOCUS_NONE
	_preview_click_target.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_preview_click_target.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_preview_click_target.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_preview_click_target.custom_minimum_size = Vector2(320, 460)
	_preview_click_target.pressed.connect(_on_preview_texture_pressed)
	box.add_child(_preview_click_target)

	_preview_texture = TextureRect.new()
	_preview_texture.custom_minimum_size = Vector2(320, 460)
	_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_click_target.add_child(_preview_texture)
	_preview_apply_button = _action_button("设置背景", _on_apply_preview_background_pressed, true)
	_preview_apply_button.custom_minimum_size = Vector2(0, 42)
	box.add_child(_preview_apply_button)

	return overlay


func _build_settings_overlay() -> Control:
	var overlay := Control.new()
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1001
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_deck_settings()
	)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.07, 0.10, 0.98), Color(0.90, 0.82, 0.48, 0.55), 2, 16))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_settings_title_label = _make_label("设置卡组", 18, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_settings_title_label)
	_settings_primary_button = _action_button("设为玩家卡组", _on_settings_primary_pressed, true)
	box.add_child(_settings_primary_button)
	_settings_secondary_button = _action_button("设为人机卡组", _on_settings_secondary_pressed, true)
	box.add_child(_settings_secondary_button)
	_settings_tertiary_button = _action_button("设为背景图", _on_settings_tertiary_pressed, true)
	box.add_child(_settings_tertiary_button)
	box.add_child(_make_button("关闭"))
	var close_button: Button = box.get_child(box.get_child_count() - 1)
	close_button.pressed.connect(_hide_deck_settings)

	return overlay


func _module_button(title: String, target_view: String) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 96)
	button.text = title
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.09, 0.11, 0.16, 0.56), Color(0.78, 0.84, 1.0, 0.34), 1, 12))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.13, 0.16, 0.22, 0.74), Color(0.90, 0.82, 0.48, 0.68), 1, 12))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.07, 0.09, 0.12, 0.84), Color(0.90, 0.82, 0.48, 0.76), 1, 12))
	button.pressed.connect(_open_module.bind(target_view))
	return button


func _on_back_pressed() -> void:
	_hide_detail()
	_hide_card_preview()
	_hide_deck_settings()
	if _current_view == VIEW_HOME:
		emit_signal("back_requested")
		return
	if _current_view == VIEW_CREATE:
		_show_view(_create_return_view)
		return
	_show_view(VIEW_HOME)


func _show_view(view_name: String) -> void:
	if view_name == VIEW_TEST_LIST and not _is_test_deck_module_available():
		view_name = VIEW_HOME
	_ensure_view_fresh(view_name)
	_current_view = view_name
	_home_view.visible = view_name == VIEW_HOME
	_create_view.visible = view_name == VIEW_CREATE
	_list_view.visible = view_name == VIEW_LIST
	_test_list_view.visible = view_name == VIEW_TEST_LIST
	_player_view.visible = view_name == VIEW_PLAYER
	_ai_view.visible = view_name == VIEW_AI
	_gallery_view.visible = view_name == VIEW_GALLERY
	if _gallery_reset_button != null:
		_gallery_reset_button.visible = view_name == VIEW_GALLERY
	match view_name:
		VIEW_HOME:
			_title_label.text = "卡组构筑"
			_message_label.text = ""
			_back_button.text = "关闭"
		VIEW_CREATE:
			_title_label.text = "创建测试卡组" if _editing_deck_mode == "test" else "创建卡组"
			_message_label.text = "上方填写信息，中间选择主宰与卡牌，下方确认保存。测试卡组不限制卡牌数量。" if _editing_deck_mode == "test" else "上方填写信息，中间选择主宰与卡牌，下方确认创建。"
			_back_button.text = "返回"
		VIEW_LIST:
			_title_label.text = "卡组列表"
			_message_label.text = "查看、编辑、删除卡组，也可以直接设置为玩家卡组或人机卡组。"
			_back_button.text = "返回"
		VIEW_TEST_LIST:
			_title_label.text = "测试卡组"
			_message_label.text = "顶部可直接创建测试卡组。列表中的设置按钮可指定测试模式的玩家卡组或对手卡组。"
			_back_button.text = "返回"
		VIEW_PLAYER:
			_title_label.text = "玩家卡组"
			_message_label.text = "上方显示当前玩家卡组，下方从卡组列表中应用。"
			_back_button.text = "返回"
		VIEW_AI:
			_title_label.text = "人机卡组"
			_message_label.text = "上方显示当前人机卡组，下方从卡组列表中应用。测试模式不受此处影响。"
			_back_button.text = "返回"
		VIEW_GALLERY:
			_title_label.text = "卡牌图鉴"
			_message_label.text = ""
			_back_button.text = "返回"


func _refresh_background() -> void:
	if _background_texture_rect == null:
		return
	var active_path := _active_background_path()
	if active_path == USER_BACKGROUND_OUTPUT_PATH and _texture_cache.has(USER_BACKGROUND_OUTPUT_PATH):
		_texture_cache.erase(USER_BACKGROUND_OUTPUT_PATH)
	var texture := _load_texture_from_asset(active_path)
	_background_texture_rect.texture = texture


func sync_background_from_store() -> void:
	_refresh_background()


func _active_background_path() -> String:
	if not DeckBuilderStore.get_selected_background_card_id().is_empty() and FileAccess.file_exists(USER_BACKGROUND_OUTPUT_PATH):
		return USER_BACKGROUND_OUTPUT_PATH
	return RULE_START_BACKGROUND_PATH


func _open_module(view_name: String) -> void:
	if view_name == VIEW_TEST_LIST and not _is_test_deck_module_available():
		_show_view(VIEW_HOME)
		_message_label.text = "正式版已禁用测试卡组模块。"
		return
	if view_name == VIEW_CREATE:
		_reset_editor()
		_editing_deck_mode = "formal"
		_create_return_view = VIEW_HOME
	_show_view(view_name)


func _open_test_create_view() -> void:
	if not _is_test_deck_module_available():
		_show_view(VIEW_HOME)
		_message_label.text = "正式版已禁用测试卡组模块。"
		return
	_reset_editor()
	_editing_deck_mode = "test"
	_create_return_view = VIEW_TEST_LIST
	_show_view(VIEW_CREATE)


func _refresh_all(message: String) -> void:
	if not message.is_empty():
		_message_label.text = message
	_mark_all_views_dirty()
	if visible and _current_view != VIEW_HOME:
		_ensure_view_fresh(_current_view)


func _refresh_create_view() -> void:
	_create_view_dirty = false
	_begin_lazy_image_cycle()
	_rebuild_filter_options()
	_rebuild_master_cards()
	_rebuild_card_grid()
	_rebuild_selected_cards()
	_refresh_create_summary()


func _refresh_list_view() -> void:
	_list_view_dirty = false
	_clear_container(_list_box)
	var decks := DeckBuilderStore.list_decks("formal")
	if decks.is_empty():
		_list_box.add_child(_make_label("暂无卡组。", 14, HORIZONTAL_ALIGNMENT_LEFT))
		return
	for deck in decks:
		_list_box.add_child(_deck_list_card(deck, "formal"))


func _refresh_test_list_view() -> void:
	_test_list_view_dirty = false
	if _test_list_box == null:
		return
	_clear_container(_test_list_box)
	var decks := DeckBuilderStore.list_decks("test")
	if decks.is_empty():
		_test_list_box.add_child(_make_label("暂无测试卡组。", 14, HORIZONTAL_ALIGNMENT_LEFT))
		return
	for deck in decks:
		_test_list_box.add_child(_deck_list_card(deck, "test"))


func _refresh_role_view(for_player: bool) -> void:
	if for_player:
		_player_view_dirty = false
	else:
		_ai_view_dirty = false
	var current_box := _player_current_box if for_player else _ai_current_box
	var list_box := _player_list_box if for_player else _ai_list_box
	_clear_container(current_box)
	_clear_container(list_box)

	var current_id := DeckBuilderStore.get_selected_player_deck_id() if for_player else DeckBuilderStore.get_selected_ai_deck_id()
	var current_deck := {}
	if not current_id.is_empty():
		current_deck = DeckBuilderStore.get_deck(current_id, "formal")
	if current_deck.is_empty():
		current_box.add_child(_make_label("当前为默认预组。", 14, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		current_box.add_child(_deck_summary_card(current_deck, false))

	var decks := DeckBuilderStore.list_decks("formal")
	if decks.is_empty():
		list_box.add_child(_make_label("暂无卡组。", 14, HORIZONTAL_ALIGNMENT_LEFT))
		return
	for deck in decks:
		list_box.add_child(_role_apply_card(deck, for_player))


func _refresh_gallery_view() -> void:
	_begin_lazy_image_cycle()
	if _gallery_filters_dirty:
		_rebuild_gallery_filters()
		_gallery_filters_dirty = false
	if _gallery_grid_dirty:
		_rebuild_gallery_grid()
		_gallery_grid_dirty = false


func _ensure_view_fresh(view_name: String) -> void:
	match view_name:
		VIEW_CREATE:
			if _create_view_dirty:
				_refresh_create_view()
		VIEW_LIST:
			if _list_view_dirty:
				_refresh_list_view()
		VIEW_TEST_LIST:
			if not _is_test_deck_module_available():
				return
			if _test_list_view_dirty:
				_refresh_test_list_view()
		VIEW_PLAYER:
			if _player_view_dirty:
				_refresh_role_view(true)
		VIEW_AI:
			if _ai_view_dirty:
				_refresh_role_view(false)
		VIEW_GALLERY:
			if _gallery_filters_dirty or _gallery_grid_dirty:
				_refresh_gallery_view()


func _mark_create_view_dirty() -> void:
	_create_view_dirty = true


func _mark_all_views_dirty() -> void:
	_create_view_dirty = true
	_list_view_dirty = true
	_test_list_view_dirty = true
	_player_view_dirty = true
	_ai_view_dirty = true
	_gallery_filters_dirty = true
	_gallery_grid_dirty = true


func _rebuild_gallery_filters() -> void:
	_clear_container(_gallery_faction_chip_box)
	_clear_container(_gallery_type_chip_box)
	var factions := {}
	var types := {}
	for entry in _gallery_entries:
		factions[str(entry.get("faction", ""))] = true
		types[str(entry.get("type", ""))] = true
	var faction_keys = factions.keys()
	faction_keys.sort()
	_gallery_faction_chip_box.add_child(_gallery_faction_chip("全部阵营", ""))
	for faction in faction_keys:
		var faction_text := str(faction)
		if faction_text.is_empty():
			continue
		_gallery_faction_chip_box.add_child(_gallery_faction_chip(_faction_display_name(faction_text), faction_text))
	_gallery_type_chip_box.add_child(_gallery_type_chip("全部种类", ""))
	for card_type in _ordered_type_keys(types):
		_gallery_type_chip_box.add_child(_gallery_type_chip(_type_display_name(card_type), card_type))


func _rebuild_gallery_grid() -> void:
	_gallery_render_serial += 1
	_gallery_rendered_count = 0
	_clear_container(_gallery_grid)
	var matched_count := 0
	var current_background_id := DeckBuilderStore.get_selected_background_card_id()
	var keyword := ""
	if _gallery_search_edit != null:
		keyword = _gallery_search_edit.text.strip_edges().to_lower()
	var matched_entries: Array[Dictionary] = []
	for entry in _gallery_entries:
		if not _gallery_matches_filter(entry, keyword):
			continue
		matched_entries.append(entry)
		matched_count += 1
	if matched_entries.is_empty():
		_gallery_grid.add_child(_make_label("没有符合筛选条件的卡牌。", 14, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		_gallery_pending_entries = matched_entries
		_gallery_pending_background_id = current_background_id
		var first_page_end := mini(FIRST_PAGE_SYNC_COUNT, _gallery_pending_entries.size())
		for index in range(first_page_end):
			var entry := _gallery_pending_entries[index]
			_gallery_grid.add_child(_gallery_card(entry, _gallery_pending_background_id == str(entry.get("id", "")), true))
		_gallery_rendered_count = first_page_end
		call_deferred("_maybe_append_gallery_batch")
	if _gallery_summary_label != null:
		var background_name := "默认背景"
		if not current_background_id.is_empty():
			background_name = _gallery_item_name(current_background_id)
		_gallery_summary_label.text = "共 %s 张，当前展示 %s 张。当前背景：%s。" % [
			_gallery_entries.size(),
			matched_count,
			background_name
		]


func _append_gallery_batch(serial: int, start_index: int) -> void:
	if serial != _gallery_render_serial:
		return
	var end_index := mini(start_index + CARD_RENDER_BATCH_SIZE, _gallery_pending_entries.size())
	for index in range(start_index, end_index):
		var entry := _gallery_pending_entries[index]
		_gallery_grid.add_child(_gallery_card(entry, _gallery_pending_background_id == str(entry.get("id", "")), false))
	_gallery_rendered_count = end_index


func _gallery_matches_filter(entry: Dictionary, keyword: String) -> bool:
	var faction := str(entry.get("faction", ""))
	var card_type := str(entry.get("type", ""))
	var searchable := "%s %s %s %s %s %s %s" % [
		str(entry.get("id", "")),
		str(entry.get("name", "")),
		faction,
		card_type,
		str(entry.get("series", "")),
		str(entry.get("card_no", "")),
		str(entry.get("search_text", ""))
	]
	if not keyword.is_empty() and not searchable.to_lower().contains(keyword):
		return false
	if not _selected_gallery_faction.is_empty() and _selected_gallery_faction != faction:
		return false
	if not _selected_gallery_type.is_empty() and _selected_gallery_type != card_type:
		return false
	return true


func _gallery_card(entry: Dictionary, selected_background: bool, load_image_now: bool = false) -> Control:
	var card_size := _gallery_card_size(entry)
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, card_size.y + 70)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_child(_gallery_card_visual(entry, card_size, selected_background, load_image_now))
	button.pressed.connect(_show_gallery_card_preview.bind(entry))
	return button


func _gallery_card_visual(entry: Dictionary, card_size: Vector2, selected_background: bool, load_image_now: bool = false) -> Control:
	var image := _image_holder_for_path(_gallery_display_path(entry), card_size, "暂无卡图", load_image_now)
	var subtitle := "%s / %s" % [
		_type_display_name(str(entry.get("type", ""))),
		_faction_display_name(str(entry.get("faction", "")))
	]
	return _make_light_catalog_card(
		image,
		card_size,
		str(entry.get("name", entry.get("id", ""))),
		subtitle,
		selected_background
	)


func _gallery_card_size(entry: Dictionary) -> Vector2:
	if _is_calamity_gallery_entry(entry) or _is_trial_gallery_entry(entry):
		return Vector2(150, 112)
	return Vector2(150, 214)


func _rebuild_filter_options() -> void:
	_clear_container(_create_faction_chip_box)
	_clear_container(_create_type_chip_box)

	var factions := {}
	var types := {}
	for card_id in _library_card_ids:
		var definition = _definition(card_id)
		factions[str(definition.get("faction", ""))] = true
		types[str(definition.get("type", ""))] = true

	var faction_keys = factions.keys()
	faction_keys.sort()
	_create_faction_chip_box.add_child(_faction_chip("全部", ""))
	for faction in faction_keys:
		var faction_text := str(faction)
		if faction_text.is_empty():
			continue
		_create_faction_chip_box.add_child(_faction_chip(_faction_display_name(faction_text), faction_text))

	_create_type_chip_box.add_child(_type_chip("全部种类", ""))
	for card_type in _ordered_type_keys(types):
		_create_type_chip_box.add_child(_type_chip(_type_display_name(card_type), card_type))


func _rebuild_master_cards() -> void:
	_clear_container(_create_master_faction_chip_box)
	_clear_container(_create_master_box)
	var grouped := {}
	for master_id in _master_ids:
		var faction := str(_definition(master_id).get("faction", "其他"))
		if not grouped.has(faction):
			grouped[faction] = []
		grouped[faction].append(master_id)
	var faction_keys = grouped.keys()
	faction_keys.sort()
	_create_master_faction_chip_box.add_child(_master_faction_chip("全部", ""))
	for faction in faction_keys:
		var faction_text := str(faction)
		if faction_text.is_empty():
			continue
		_create_master_faction_chip_box.add_child(_master_faction_chip(_faction_display_name(faction_text), faction_text))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	_create_master_box.add_child(grid)
	for faction in faction_keys:
		var faction_text := str(faction)
		if not _selected_master_faction.is_empty() and _selected_master_faction != faction_text:
			continue
		for master_id in grouped[faction]:
			grid.add_child(_master_card(master_id))


func _rebuild_card_grid() -> void:
	_create_render_serial += 1
	_create_rendered_count = 0
	_clear_container(_create_card_grid)
	var keyword := _create_search_edit.text.strip_edges().to_lower()
	var selected_faction := _selected_create_faction
	var selected_type := _selected_create_type
	var matched_card_ids: Array[String] = []
	for card_id in _library_card_ids:
		var definition = _definition(card_id)
		var name_text := str(definition.get("name", card_id))
		var faction := str(definition.get("faction", ""))
		var card_type := str(definition.get("type", ""))
		var searchable := "%s %s %s %s %s %s %s" % [
			card_id,
			name_text,
			faction,
			card_type,
			str(definition.get("series", "")),
			str(definition.get("card_no", "")),
			str(definition.get("search_text", ""))
		]
		if not keyword.is_empty() and not searchable.to_lower().contains(keyword):
			continue
		if not selected_faction.is_empty() and selected_faction != faction:
			continue
		if not selected_type.is_empty() and selected_type != card_type:
			continue
		matched_card_ids.append(card_id)
	_create_pending_card_ids = matched_card_ids
	var first_page_end := mini(FIRST_PAGE_SYNC_COUNT, _create_pending_card_ids.size())
	for index in range(first_page_end):
		_create_card_grid.add_child(_library_card(_create_pending_card_ids[index], true))
	_create_rendered_count = first_page_end
	call_deferred("_maybe_append_create_batch")


func _append_create_card_batch(serial: int, start_index: int) -> void:
	if serial != _create_render_serial:
		return
	var end_index := mini(start_index + CARD_RENDER_BATCH_SIZE, _create_pending_card_ids.size())
	for index in range(start_index, end_index):
		_create_card_grid.add_child(_library_card(_create_pending_card_ids[index], false))
	_create_rendered_count = end_index


func _on_create_scroll_changed(_value: float) -> void:
	_maybe_append_create_batch()


func _on_gallery_scroll_changed(_value: float) -> void:
	_maybe_append_gallery_batch()


func _maybe_append_create_batch() -> void:
	if _create_scroll == null:
		return
	var appended := 0
	while _create_rendered_count < _create_pending_card_ids.size() and _should_append_for_scroll(_create_scroll) and appended < 3:
		var start_index := _create_rendered_count
		_append_create_card_batch(_create_render_serial, start_index)
		if _create_rendered_count == start_index:
			break
		appended += 1


func _maybe_append_gallery_batch() -> void:
	if _gallery_scroll == null:
		return
	var appended := 0
	while _gallery_rendered_count < _gallery_pending_entries.size() and _should_append_for_scroll(_gallery_scroll) and appended < 3:
		var start_index := _gallery_rendered_count
		_append_gallery_batch(_gallery_render_serial, start_index)
		if _gallery_rendered_count == start_index:
			break
		appended += 1


func _should_append_for_scroll(scroll: ScrollContainer) -> bool:
	var bar := scroll.get_v_scroll_bar()
	if bar == null:
		return false
	var bottom_limit := maxf(0.0, float(bar.max_value) - float(bar.page))
	var remaining := bottom_limit - float(scroll.scroll_vertical)
	return remaining <= SCROLL_RENDER_TRIGGER_PX


func _rebuild_selected_cards() -> void:
	_clear_container(_create_selected_box)
	var counts := _selected_count_map()
	if counts.is_empty():
		_create_selected_box.add_child(_make_label("暂未选择卡牌。", 13, HORIZONTAL_ALIGNMENT_LEFT))
		return
	var ids = counts.keys()
	ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _card_name(str(left)) < _card_name(str(right))
	)
	for raw_card_id in ids:
		var card_id := str(raw_card_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := _make_label("%s ×%s" % [_card_name(card_id), int(counts.get(card_id, 0))], 13, HORIZONTAL_ALIGNMENT_LEFT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var minus_button := _small_button("-")
		minus_button.pressed.connect(_change_card_count.bind(card_id, -1))
		row.add_child(minus_button)
		var plus_button := _small_button("+")
		plus_button.pressed.connect(_change_card_count.bind(card_id, 1))
		row.add_child(plus_button)
		_create_selected_box.add_child(row)


func _master_card(master_id: String) -> Control:
	var definition: Dictionary = _definition(master_id)
	var selected := _selected_master_id == master_id
	var card_size := Vector2(138, 178)
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 264)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_child(_make_light_catalog_card(
		_image_holder_for_path(_card_image_path(master_id), card_size, "暂无卡图", true),
		card_size,
		_card_name(master_id),
		"主宰 / %s" % _faction_display_name(str(definition.get("faction", ""))),
		selected
	))
	button.pressed.connect(_select_master.bind(master_id))
	_attach_card_long_press(button, master_id)
	return button


func _library_card(card_id: String, load_image_now: bool = false) -> Control:
	var definition: Dictionary = _definition(card_id)
	var count := _selected_card_count(card_id)
	var limit: int = max(1, int(definition.get("limit", 3)))
	var card_size := _library_card_image_size(card_id)
	var panel := VBoxContainer.new()
	panel.set_meta("card_id", card_id)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, card_size.y + 88)
	panel.add_theme_constant_override("separation", 4)
	var image_button := Button.new()
	image_button.flat = true
	image_button.focus_mode = Control.FOCUS_NONE
	image_button.custom_minimum_size = Vector2(0, card_size.y + 16)
	image_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	image_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	image_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	panel.add_child(image_button)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var image := _image_holder_for_path(_card_image_path(card_id), card_size, "暂无卡图", load_image_now)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_button.add_child(image)
	_attach_card_long_press(image_button, card_id)
	image_button.pressed.connect(_change_card_count.bind(card_id, 1))
	box.add_child(_make_dark_label(_card_name(card_id), 13, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_make_muted_label(_type_display_name(str(definition.get("type", ""))), 11, HORIZONTAL_ALIGNMENT_CENTER))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 6)
	box.add_child(actions)
	var minus_button := _small_button("-")
	minus_button.pressed.connect(_change_card_count.bind(card_id, -1))
	actions.add_child(minus_button)
	var count_label := _make_dark_label(str(count), 13, HORIZONTAL_ALIGNMENT_CENTER)
	count_label.name = "CountLabel"
	count_label.custom_minimum_size = Vector2(40, 30)
	actions.add_child(count_label)
	var plus_button := _small_button("+")
	plus_button.name = "PlusButton"
	if _editing_deck_mode == "formal":
		plus_button.disabled = count >= limit or _selected_card_ids.size() >= DeckBuilderStore.MAX_DECK_SIZE
	else:
		plus_button.disabled = false
	plus_button.pressed.connect(_change_card_count.bind(card_id, 1))
	actions.add_child(plus_button)
	var limit_label := _make_muted_label("%s / %s" % [count, limit], 10, HORIZONTAL_ALIGNMENT_CENTER) if _editing_deck_mode == "formal" else _make_muted_label("测试模式不限数量", 10, HORIZONTAL_ALIGNMENT_CENTER)
	limit_label.name = "LimitLabel"
	box.add_child(limit_label)
	_attach_card_long_press(panel, card_id)

	return panel


func _library_card_image_size(card_id: String) -> Vector2:
	var card_type := str(_definition(card_id).get("type", ""))
	if card_type == "trial":
		return Vector2(116, 86)
	return Vector2(116, 166)


func _deck_list_card(deck: Dictionary, deck_mode: String = "formal") -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 230)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.98), Color(0.72, 0.78, 0.92, 0.24), 1, 18))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var image := _card_image_texture_rect(str(deck.get("master_id", "")), Vector2(110, 156))
	image.custom_minimum_size = Vector2(110, 156)
	row.add_child(image)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	box.add_child(_make_label(str(deck.get("name", "")), 18, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_make_subtle_label(str(deck.get("description", "暂无介绍")), 14, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_make_subtle_label("%s 张卡牌" % Array(deck.get("cards", [])).size(), 14, HORIZONTAL_ALIGNMENT_LEFT))
	var summary_label := _make_label(_deck_card_summary_text(deck, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary_label)

	var actions := HFlowContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	box.add_child(actions)

	actions.add_child(_menu_action_button("查看", _show_deck_detail.bind(str(deck.get("id", "")), deck_mode)))
	actions.add_child(_menu_action_button("编辑", _edit_deck_from_list.bind(str(deck.get("id", "")), deck_mode)))
	actions.add_child(_menu_action_button("删除", _delete_deck_from_list.bind(str(deck.get("id", "")), deck_mode)))
	actions.add_child(_menu_action_button("设置", _show_deck_settings.bind(str(deck.get("id", "")), deck_mode)))

	return panel


func _deck_summary_card(deck: Dictionary, show_actions: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 230)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.98), Color(0.72, 0.78, 0.92, 0.24), 1, 18))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var image := _card_image_texture_rect(str(deck.get("master_id", "")), Vector2(110, 156))
	image.custom_minimum_size = Vector2(110, 156)
	row.add_child(image)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	box.add_child(_make_label(str(deck.get("name", "")), 18, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_make_subtle_label(str(deck.get("description", "暂无介绍")), 14, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_make_subtle_label("主宰：%s" % _card_name(str(deck.get("master_id", ""))), 14, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_make_subtle_label("%s 张卡牌" % Array(deck.get("cards", [])).size(), 14, HORIZONTAL_ALIGNMENT_LEFT))
	var summary_label := _make_label(_deck_card_summary_text(deck, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary_label)
	if show_actions:
		box.add_child(_menu_action_button("查看", _show_deck_detail.bind(str(deck.get("id", "")))))
	return panel


func _role_apply_card(deck: Dictionary, for_player: bool) -> Control:
	var card := _deck_summary_card(deck, false)
	var margin: MarginContainer = card.get_child(0)
	var row: HBoxContainer = margin.get_child(0)
	var box: VBoxContainer = row.get_child(1)
	var actions := HFlowContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	box.add_child(actions)
	actions.add_child(_menu_action_button("查看", _show_deck_detail.bind(str(deck.get("id", "")))))
	actions.add_child(_menu_action_button("设置", _show_role_deck_setting_confirm.bind(str(deck.get("id", "")), for_player)))
	return card


func _select_master(master_id: String) -> void:
	_selected_master_id = master_id
	_create_error_label.text = ""
	_rebuild_master_cards()
	_refresh_create_view()


func _change_card_count(card_id: String, delta: int) -> void:
	if delta > 0:
		if _editing_deck_mode == "formal":
			var definition: Dictionary = _definition(card_id)
			var limit: int = max(1, int(definition.get("limit", 3)))
			if _selected_card_count(card_id) >= limit:
				_create_error_label.text = "%s 已达到数量上限 %s。" % [_card_name(card_id), limit]
				return
			if _selected_card_ids.size() >= DeckBuilderStore.MAX_DECK_SIZE:
				_create_error_label.text = "当前卡组已达到 %s 张上限。" % DeckBuilderStore.MAX_DECK_SIZE
				return
		_selected_card_ids.append(card_id)
	else:
		var index := _selected_card_ids.rfind(card_id)
		if index != -1:
			_selected_card_ids.remove_at(index)
	_create_error_label.text = ""
	_rebuild_selected_cards()
	_refresh_create_summary()
	_refresh_rendered_library_cards()


func _refresh_create_summary() -> void:
	var title := "创建测试卡组" if _editing_deck_mode == "test" else "创建卡组"
	if not _editing_deck_id.is_empty():
		title = "保存修改"
	_create_submit_button.text = title
	if _editing_deck_mode == "test":
		_create_summary_label.text = "当前主宰：%s\n当前卡数：%s 张（测试卡组不限制数量）" % [_current_master_name(), _selected_card_ids.size()]
	else:
		_create_summary_label.text = "当前主宰：%s\n当前卡数：%s 张" % [_current_master_name(), _selected_card_ids.size()]


func _refresh_rendered_library_cards() -> void:
	if _create_card_grid == null:
		return
	var total_selected := _selected_card_ids.size()
	for child in _create_card_grid.get_children():
		if not (child is VBoxContainer):
			continue
		var card_id := str(child.get_meta("card_id", ""))
		if card_id.is_empty():
			continue
		var box: VBoxContainer = child.get_child(1) if child.get_child_count() > 1 and child.get_child(1) is VBoxContainer else null
		if box == null:
			continue
		var actions: HBoxContainer = box.get_child(2) if box.get_child_count() > 2 and box.get_child(2) is HBoxContainer else null
		if actions == null:
			continue
		var count := _selected_card_count(card_id)
		var definition: Dictionary = _definition(card_id)
		var limit: int = max(1, int(definition.get("limit", 3)))
		var count_label := actions.get_node_or_null("CountLabel") as Label
		if count_label != null:
			count_label.text = str(count)
		var plus_button := actions.get_node_or_null("PlusButton") as Button
		if plus_button != null:
			if _editing_deck_mode == "formal":
				plus_button.disabled = count >= limit or total_selected >= DeckBuilderStore.MAX_DECK_SIZE
			else:
				plus_button.disabled = false
		var limit_label := box.get_node_or_null("LimitLabel") as Label
		if limit_label != null and _editing_deck_mode == "formal":
			limit_label.text = "%s / %s" % [count, limit]


func _save_current_deck() -> void:
	var payload := {
		"id": _editing_deck_id,
		"name": _create_name_edit.text.strip_edges(),
		"description": _create_desc_edit.text.strip_edges(),
		"master_id": _selected_master_id,
		"cards": _selected_card_ids.duplicate()
	}
	var result := DeckBuilderStore.save_deck(payload, _card_definitions, _editing_deck_mode)
	if not bool(result.get("ok", false)):
		_create_error_label.text = str(result.get("reason", "保存失败。"))
		return
	var deck = result.get("deck", {})
	_editing_deck_id = str(deck.get("id", ""))
	_create_error_label.text = ""
	var saved_name := str(deck.get("name", ""))
	if _editing_deck_mode == "test":
		_refresh_all("测试卡组已保存：%s" % saved_name)
		_show_view(VIEW_TEST_LIST)
	else:
		_refresh_all("卡组已保存：%s" % saved_name)
		emit_signal("decks_changed", "正式对局卡组配置已更新。")
		_show_view(VIEW_LIST)


func _edit_deck_from_list(deck_id: String, deck_mode: String = "formal") -> void:
	var deck := DeckBuilderStore.get_deck(deck_id, deck_mode)
	if deck.is_empty():
		return
	_editing_deck_mode = deck_mode
	_create_return_view = VIEW_TEST_LIST if deck_mode == "test" else VIEW_LIST
	_load_deck_to_editor(deck)
	_refresh_all("已载入%s，可继续编辑。" % ("测试卡组" if deck_mode == "test" else "卡组"))
	_show_view(VIEW_CREATE)


func _delete_deck_from_list(deck_id: String, deck_mode: String = "formal") -> void:
	DeckBuilderStore.delete_deck(deck_id, deck_mode)
	if _editing_deck_id == deck_id:
		_reset_editor()
	_refresh_all("已删除%s。" % ("测试卡组" if deck_mode == "test" else "卡组"))
	if deck_mode == "formal":
		emit_signal("decks_changed", "正式对局卡组配置已更新。")


func _apply_deck_to_role(deck_id: String, for_player: bool, deck_mode: String = "formal") -> void:
	var deck := DeckBuilderStore.get_deck(deck_id, deck_mode)
	if deck.is_empty():
		return
	if deck_mode == "test":
		if for_player:
			DeckBuilderStore.set_selected_test_player_deck(deck_id)
			_refresh_all("测试模式玩家卡组已切换为：%s" % str(deck.get("name", "")))
		else:
			DeckBuilderStore.set_selected_test_opponent_deck(deck_id)
			_refresh_all("测试模式对手卡组已切换为：%s" % str(deck.get("name", "")))
	else:
		if for_player:
			DeckBuilderStore.set_selected_player_deck(deck_id)
			_refresh_all("玩家卡组已切换为：%s" % str(deck.get("name", "")))
		else:
			DeckBuilderStore.set_selected_ai_deck(deck_id)
			_refresh_all("人机卡组已切换为：%s" % str(deck.get("name", "")))
		emit_signal("decks_changed", "正式对局卡组配置已更新。")


func _show_deck_settings(deck_id: String, deck_mode: String = "formal") -> void:
	var deck := DeckBuilderStore.get_deck(deck_id, deck_mode)
	if deck.is_empty():
		return
	_settings_target_deck_id = deck_id
	_settings_target_deck_mode = deck_mode
	_settings_target_role = ""
	_settings_target_card_id = ""
	if _settings_title_label != null:
		_settings_title_label.text = "设置卡组：%s" % str(deck.get("name", ""))
	if _settings_primary_button != null:
		_settings_primary_button.text = "设为玩家卡组"
		_settings_primary_button.visible = true
	if _settings_secondary_button != null:
		_settings_secondary_button.text = "设为对手卡组" if deck_mode == "test" else "设为人机卡组"
		_settings_secondary_button.visible = true
	if _settings_tertiary_button != null:
		_settings_tertiary_button.visible = false
	if _settings_overlay != null:
		_settings_overlay.visible = true


func _show_role_deck_setting_confirm(deck_id: String, for_player: bool) -> void:
	var deck := DeckBuilderStore.get_deck(deck_id, "formal")
	if deck.is_empty():
		return
	_settings_target_deck_id = deck_id
	_settings_target_deck_mode = "formal"
	_settings_target_role = "formal_player" if for_player else "formal_ai"
	_settings_target_card_id = ""
	if _settings_title_label != null:
		_settings_title_label.text = "确认将「%s」设为%s卡组？" % [
			str(deck.get("name", "")),
			"玩家" if for_player else "人机"
		]
	if _settings_primary_button != null:
		_settings_primary_button.text = "确认设置"
		_settings_primary_button.visible = true
	if _settings_secondary_button != null:
		_settings_secondary_button.visible = false
	if _settings_tertiary_button != null:
		_settings_tertiary_button.visible = false
	if _settings_overlay != null:
		_settings_overlay.visible = true


func _show_card_settings(card_id: String) -> void:
	_settings_target_deck_id = ""
	_settings_target_deck_mode = "formal"
	_settings_target_role = ""
	_settings_target_card_id = card_id
	if _settings_title_label != null:
		_settings_title_label.text = "卡牌操作：%s" % _card_name(card_id)
	if _settings_primary_button != null:
		_settings_primary_button.visible = false
	if _settings_secondary_button != null:
		_settings_secondary_button.visible = false
	if _settings_tertiary_button != null:
		_settings_tertiary_button.text = "设为背景图"
		_settings_tertiary_button.visible = true
	if _settings_overlay != null:
		_settings_overlay.visible = true


func _hide_deck_settings() -> void:
	_settings_target_deck_id = ""
	_settings_target_deck_mode = "formal"
	_settings_target_role = ""
	_settings_target_card_id = ""
	if _settings_overlay != null:
		_settings_overlay.visible = false


func _apply_deck_setting(for_player: bool) -> void:
	if _settings_target_deck_id.is_empty():
		return
	_apply_deck_to_role(_settings_target_deck_id, for_player, _settings_target_deck_mode)
	_hide_deck_settings()


func _on_settings_primary_pressed() -> void:
	if _settings_target_role == "formal_player":
		_apply_deck_setting(true)
		return
	if _settings_target_role == "formal_ai":
		_apply_deck_setting(false)
		return
	_apply_deck_setting(true)


func _on_settings_secondary_pressed() -> void:
	_apply_deck_setting(false)


func _on_settings_tertiary_pressed() -> void:
	if _settings_target_card_id.is_empty():
		return
	_set_card_as_background(_settings_target_card_id)
	_hide_deck_settings()


func _show_deck_detail(deck_id: String, deck_mode: String = "formal") -> void:
	var deck := DeckBuilderStore.get_deck(deck_id, deck_mode)
	if deck.is_empty():
		return
	if _detail_title_label != null:
		_detail_title_label.text = "卡组详情：%s" % str(deck.get("name", ""))
	if _detail_summary_label != null:
		_detail_summary_label.text = "介绍：%s\n主宰：%s\n卡数：%s 张\n长按任意卡牌可放大。" % [
			str(deck.get("description", "暂无介绍")),
			_card_name(str(deck.get("master_id", ""))),
			Array(deck.get("cards", [])).size()
		]
	_rebuild_deck_detail_content(deck)
	_detail_overlay.visible = true


func _hide_detail() -> void:
	if _detail_overlay != null:
		_detail_overlay.visible = false


func _rebuild_deck_detail_content(deck: Dictionary) -> void:
	_clear_container(_detail_master_box)
	_clear_container(_detail_card_grid)
	if _detail_master_box == null or _detail_card_grid == null:
		return
	var master_id := str(deck.get("master_id", ""))
	if not master_id.is_empty():
		_detail_master_box.add_child(_detail_master_card(master_id))
	var counts := {}
	for raw_card_id in deck.get("cards", []):
		var card_id := str(raw_card_id)
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	var card_ids = counts.keys()
	card_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_id := str(left)
		var right_id := str(right)
		var left_cost := int(_definition(left_id).get("cost", 0))
		var right_cost := int(_definition(right_id).get("cost", 0))
		if left_cost != right_cost:
			return left_cost < right_cost
		return _card_name(left_id) < _card_name(right_id)
	)
	for raw_card_id in card_ids:
		var card_id := str(raw_card_id)
		_detail_card_grid.add_child(_detail_deck_card(card_id, int(counts.get(card_id, 0))))


func _detail_master_card(master_id: String) -> Control:
	var definition: Dictionary = _definition(master_id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 286)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.98), Color(0.95, 0.82, 0.45, 0.72), 1, 14))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(_card_image_texture_rect(master_id, Vector2(150, 186)))
	box.add_child(_make_label(_card_name(master_id), 14, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_make_subtle_label("主宰卡 / %s" % _faction_display_name(str(definition.get("faction", ""))), 12, HORIZONTAL_ALIGNMENT_LEFT))
	_attach_card_long_press(panel, master_id)
	return panel


func _detail_deck_card(card_id: String, count: int) -> Control:
	var definition: Dictionary = _definition(card_id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 290)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.98), Color(0.72, 0.78, 0.92, 0.24), 1, 14))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(_card_image_texture_rect(card_id, Vector2(150, 174)))
	box.add_child(_make_label(_card_name(card_id), 14, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_make_subtle_label("%s / %s" % [_type_display_name(str(definition.get("type", ""))), _faction_display_name(str(definition.get("faction", "")))], 12, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_make_subtle_label("数量 ×%s" % count, 12, HORIZONTAL_ALIGNMENT_LEFT))
	_attach_card_long_press(panel, card_id)
	return panel


func _show_card_preview(card_id: String) -> void:
	if _preview_texture == null:
		return
	var texture := _load_texture_from_asset(_card_preview_path(card_id))
	if texture == null:
		return
	_apply_preview_layout(texture)
	_preview_texture.texture = texture
	_preview_texture.set_meta("background_key", card_id)
	if _preview_apply_button != null:
		_preview_apply_button.visible = false
	if _preview_overlay != null:
		_preview_overlay.visible = true


func _show_gallery_card_preview(entry: Dictionary) -> void:
	if _preview_texture == null:
		return
	var texture := _load_texture_from_asset(_gallery_image_path(entry, true))
	if texture == null:
		texture = _load_texture_from_asset(_gallery_image_path(entry, false))
	if texture == null:
		return
	_apply_preview_layout(texture)
	_preview_texture.texture = texture
	_preview_texture.set_meta("background_key", str(entry.get("id", "")))
	if _preview_apply_button != null:
		_preview_apply_button.visible = true
	if _preview_overlay != null:
		_preview_overlay.visible = true


func _hide_card_preview() -> void:
	_hold_preview_serial += 1
	if _preview_overlay != null:
		_preview_overlay.visible = false
	if _preview_texture != null:
		_preview_texture.texture = null
		_preview_texture.remove_meta("background_key")


func _apply_preview_layout(texture: Texture2D) -> void:
	if _preview_panel == null or _preview_click_target == null or _preview_texture == null:
		return
	var preview_size := Vector2(320, 460)
	var panel_size := Vector2(360, 520)
	if texture.get_width() > texture.get_height():
		preview_size = Vector2(520, 292)
		panel_size = Vector2(560, 368)
	_preview_click_target.custom_minimum_size = preview_size
	_preview_texture.custom_minimum_size = preview_size
	_preview_panel.custom_minimum_size = panel_size


func _attach_card_long_press(target: Control, card_id: String) -> void:
	target.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_card_long_press(card_id)
			else:
				_hold_preview_serial += 1
				if _current_view == VIEW_GALLERY and _touch_scroll_distance < 8.0 and (_preview_overlay == null or not _preview_overlay.visible):
					_show_card_settings(card_id)
	)


func _begin_card_long_press(card_id: String) -> void:
	_hold_preview_serial += 1
	var current_serial := _hold_preview_serial
	_wait_and_preview(card_id, current_serial)


func _wait_and_preview(card_id: String, current_serial: int) -> void:
	await get_tree().create_timer(0.35).timeout
	if current_serial != _hold_preview_serial:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_show_card_preview(card_id)


func _load_deck_to_editor(deck: Dictionary) -> void:
	_editing_deck_id = str(deck.get("id", ""))
	_create_name_edit.text = str(deck.get("name", ""))
	_create_desc_edit.text = str(deck.get("description", ""))
	_selected_master_id = str(deck.get("master_id", ""))
	var removed_master := false
	var removed_cards := 0
	if _editing_deck_mode == "formal" and not _selected_master_id.is_empty() and not DeckBuilderCardPool.is_formal_master(_selected_master_id):
		_selected_master_id = ""
		removed_master = true
	_selected_card_ids.clear()
	for raw_card_id in deck.get("cards", []):
		var card_id := str(raw_card_id)
		if _editing_deck_mode == "test":
			var definition: Dictionary = _definition(card_id)
			var card_type := str(definition.get("type", ""))
			var card_kind := str(definition.get("kind", ""))
			if not definition.is_empty() and card_kind != "master" and card_type != "morale" and card_type != "calamity":
				_selected_card_ids.append(card_id)
			else:
				removed_cards += 1
		elif DeckBuilderCardPool.is_formal_deck_card(card_id):
			_selected_card_ids.append(card_id)
		else:
			removed_cards += 1
	if removed_master and removed_cards > 0:
		_create_error_label.text = "已清除无效主宰，并剔除 %s 张非正式构筑池卡牌。" % removed_cards
	elif removed_master:
		_create_error_label.text = "原卡组主宰不在正式构筑池内，已清除。"
	elif removed_cards > 0:
		_create_error_label.text = "已自动剔除 %s 张非正式构筑池卡牌。" % removed_cards


func _reset_editor() -> void:
	_editing_deck_id = ""
	_selected_master_id = ""
	_selected_master_faction = ""
	_selected_create_faction = ""
	_selected_create_type = ""
	_selected_card_ids.clear()
	if _create_name_edit != null:
		_create_name_edit.text = ""
	if _create_desc_edit != null:
		_create_desc_edit.text = ""
	if _create_search_edit != null:
		_create_search_edit.text = ""
	_create_error_label.text = ""


func _selected_count_map() -> Dictionary:
	var result := {}
	for card_id in _selected_card_ids:
		result[card_id] = int(result.get(card_id, 0)) + 1
	return result


func _selected_card_count(card_id: String) -> int:
	var count := 0
	for current_id in _selected_card_ids:
		if current_id == card_id:
			count += 1
	return count


func _current_master_name() -> String:
	if _selected_master_id.is_empty():
		return "未选择"
	return _card_name(_selected_master_id)


func _definition(card_id: String) -> Dictionary:
	var definition = _card_definitions.get(card_id, {})
	if definition is Dictionary:
		return definition
	return {}


func _card_name(card_id: String) -> String:
	return str(_definition(card_id).get("name", card_id))


func _card_image_path(card_id: String) -> String:
	var definition = _definition(card_id)
	var face_path := str(definition.get("card_face_path", ""))
	if _path_has_texture_asset(face_path):
		return face_path
	var image_path := str(definition.get("image_path", ""))
	if _path_has_texture_asset(image_path):
		return image_path
	for extension in ["jpg", "png", "jpeg", "webp"]:
		var local_path := "res://client/assets/cards/%s.%s" % [card_id, extension]
		if _path_has_texture_asset(local_path):
			return local_path
	var gallery_entry := _gallery_entry_for_card(card_id, definition)
	if not gallery_entry.is_empty():
		var gallery_face_path := str(gallery_entry.get("face_path", ""))
		if _path_has_texture_asset(gallery_face_path):
			return gallery_face_path
		var gallery_thumb_path := str(gallery_entry.get("thumb_path", ""))
		if _path_has_texture_asset(gallery_thumb_path):
			return gallery_thumb_path
	return ""


func _card_preview_path(card_id: String) -> String:
	return _card_image_path(card_id)


func _pick_scroll_target(global_position: Vector2) -> ScrollContainer:
	if _detail_overlay != null and _detail_overlay.visible and _detail_scroll != null:
		if _detail_scroll.get_global_rect().has_point(global_position):
			return _detail_scroll
	var target: ScrollContainer = null
	match _current_view:
		VIEW_CREATE:
			target = _create_scroll
		VIEW_LIST:
			target = _list_scroll
		VIEW_PLAYER:
			target = _player_scroll
		VIEW_AI:
			target = _ai_scroll
		VIEW_GALLERY:
			target = _gallery_scroll
		_:
			target = null
	if target != null and target.visible and target.get_global_rect().has_point(global_position):
		return target
	return null


func _scroll_vertical_by(target: ScrollContainer, delta_y: float) -> void:
	if target == null:
		return
	var bar := target.get_v_scroll_bar()
	if bar == null:
		return
	var max_value := int(bar.max_value)
	var next_value := target.scroll_vertical - int(delta_y)
	next_value = clampi(next_value, 0, max_value)
	target.scroll_vertical = next_value


func _restore_create_scroll(scroll_value: int) -> void:
	if _create_scroll == null:
		return
	var bar := _create_scroll.get_v_scroll_bar()
	if bar == null:
		return
	var max_value := int(bar.max_value)
	_create_scroll.scroll_vertical = clampi(scroll_value, 0, max_value)


func _card_image_texture_rect(card_id: String, image_size: Vector2) -> Control:
	var path := _card_image_path(card_id)
	var texture := _load_texture_from_asset(path)
	return _texture_image_texture_rect(texture, image_size, "暂无卡图")


func _image_holder_for_path(path: String, image_size: Vector2, placeholder_text: String, load_now: bool) -> Control:
	if load_now:
		return _texture_image_texture_rect(_load_texture_from_asset(path), image_size, placeholder_text)
	return _make_lazy_texture_holder(path, image_size, placeholder_text)


func _make_lazy_texture_holder(path: String, image_size: Vector2, placeholder_text: String) -> Control:
	var holder := _texture_image_texture_rect(null, image_size, placeholder_text)
	if path.is_empty():
		return holder
	_queue_lazy_image_load(holder, path, image_size, placeholder_text)
	return holder



func _texture_image_texture_rect(texture: Texture2D, image_size: Vector2, placeholder_text: String) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = image_size
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture is Texture2D:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = image_size
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(image)
	else:
		var placeholder := PanelContainer.new()
		placeholder.custom_minimum_size = image_size
		placeholder.add_theme_stylebox_override("panel", _panel_style(Color(0.90, 0.93, 0.98, 0.96), Color(0.76, 0.81, 0.90, 0.55), 1, 10))
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_child(center)
		var label := _make_muted_label(placeholder_text, 12, HORIZONTAL_ALIGNMENT_CENTER)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(label)
		holder.add_child(placeholder)
	return holder


func _replace_texture_holder_content(holder: Control, texture: Texture2D, image_size: Vector2, placeholder_text: String) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	if texture is Texture2D:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = image_size
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(image)
		return
	var placeholder := PanelContainer.new()
	placeholder.custom_minimum_size = image_size
	placeholder.add_theme_stylebox_override("panel", _panel_style(Color(0.90, 0.93, 0.98, 0.96), Color(0.76, 0.81, 0.90, 0.55), 1, 10))
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_child(center)
	var label := _make_muted_label(placeholder_text, 12, HORIZONTAL_ALIGNMENT_CENTER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)
	holder.add_child(placeholder)


func _begin_lazy_image_cycle() -> void:
	_lazy_image_serial += 1
	_lazy_image_jobs.clear()
	_lazy_image_pump_scheduled = false


func _queue_lazy_image_load(holder: Control, path: String, image_size: Vector2, placeholder_text: String) -> void:
	_lazy_image_jobs.append({
		"serial": _lazy_image_serial,
		"holder": holder,
		"path": path,
		"image_size": image_size,
		"placeholder_text": placeholder_text
	})
	if _lazy_image_pump_scheduled:
		return
	_lazy_image_pump_scheduled = true
	call_deferred("_process_lazy_image_jobs")


func _process_lazy_image_jobs() -> void:
	_lazy_image_pump_scheduled = false
	var pending: Array[Dictionary] = []
	var loaded := 0
	for job in _lazy_image_jobs:
		if int(job.get("serial", -1)) != _lazy_image_serial:
			continue
		if loaded >= LAZY_IMAGE_BATCH_SIZE:
			pending.append(job)
			continue
		var holder = job.get("holder", null)
		if not (holder is Control) or not is_instance_valid(holder):
			continue
		var texture := _load_texture_from_asset(str(job.get("path", "")))
		_replace_texture_holder_content(holder, texture, job.get("image_size", Vector2.ZERO), str(job.get("placeholder_text", "暂无卡图")))
		loaded += 1
	_lazy_image_jobs = pending
	if _lazy_image_jobs.is_empty():
		return
	_lazy_image_pump_scheduled = true
	call_deferred("_process_lazy_image_jobs")


func _push_background_prewarm_path(queued: Dictionary, path: String) -> void:
	if path.is_empty() or queued.has(path) or _texture_cache.has(path):
		return
	queued[path] = true
	_background_prewarm_jobs.append(path)


func _process_background_prewarm_jobs() -> void:
	_background_prewarm_scheduled = false
	var warmed := 0
	while warmed < BACKGROUND_PREWARM_BATCH_SIZE and not _background_prewarm_jobs.is_empty():
		var path := str(_background_prewarm_jobs.pop_front())
		_load_texture_from_asset(path)
		warmed += 1
	if _background_prewarm_jobs.is_empty():
		return
	_background_prewarm_scheduled = true
	call_deferred("_process_background_prewarm_jobs")



func _gallery_image_path(entry: Dictionary, prefer_face: bool) -> String:
	var face_path := str(entry.get("face_path", ""))
	var thumb_path := str(entry.get("thumb_path", ""))
	if prefer_face:
		if not face_path.is_empty():
			return face_path
		return thumb_path
	if not thumb_path.is_empty():
		return thumb_path
	return face_path


func _gallery_display_path(entry: Dictionary) -> String:
	var thumb_path := _gallery_image_path(entry, false)
	if _path_has_texture_asset(thumb_path):
		return thumb_path
	return _gallery_image_path(entry, true)


func _gallery_entry_for_card(card_id: String, definition: Dictionary) -> Dictionary:
	var source_code_keys: Array[String] = []
	var explicit_source_code := str(definition.get("source_code", "")).strip_edges()
	if not explicit_source_code.is_empty():
		source_code_keys.append(explicit_source_code.to_upper())
	var card_id_source_code := _source_code_from_card_id(card_id)
	if not card_id_source_code.is_empty():
		source_code_keys.append(card_id_source_code)
	for source_code in source_code_keys:
		if _gallery_entry_by_source_code.has(source_code):
			var entry = _gallery_entry_by_source_code.get(source_code, {})
			if entry is Dictionary:
				return entry
	var card_name := _normalize_catalog_name(str(definition.get("name", card_id)))
	if not card_name.is_empty() and _gallery_entry_by_name.has(card_name):
		var matched_entry = _gallery_entry_by_name.get(card_name, {})
		if matched_entry is Dictionary:
			return matched_entry
	return {}


func _source_code_from_card_id(card_id: String) -> String:
	var normalized := card_id.strip_edges().to_upper()
	if normalized.is_empty():
		return ""
	var parts := normalized.split("_", false)
	if parts.size() < 3:
		return ""
	return "%s-%s" % [parts[1], parts[2]]


func _normalize_catalog_name(name_text: String) -> String:
	return name_text.strip_edges().replace(" ", "").replace("　", "")


func _path_has_texture_asset(path: String) -> bool:
	if path.is_empty():
		return false
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var file := FileAccess.open(global_path, FileAccess.READ)
		if file != null and file.get_length() <= 0:
			return false
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(global_path)


func _load_texture_from_asset(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		var cached = _texture_cache.get(path, null)
		if cached is Texture2D:
			return cached
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		var global_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_path):
			var image := Image.load_from_file(global_path)
			if image != null and not image.is_empty():
				texture = ImageTexture.create_from_image(image)
	if texture != null:
		_texture_cache[path] = texture
	return texture


func _deck_card_summary_text(deck: Dictionary, max_items: int) -> String:
	var counts := {}
	for raw_card_id in deck.get("cards", []):
		var card_id := str(raw_card_id)
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	var card_ids = counts.keys()
	card_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _card_name(str(left)) < _card_name(str(right))
	)
	var parts: Array[String] = []
	var added := 0
	for raw_card_id in card_ids:
		if added >= max_items:
			break
		var card_id := str(raw_card_id)
		parts.append("%s×%s" % [_card_name(card_id), int(counts.get(card_id, 0))])
		added += 1
	if parts.is_empty():
		return "暂无卡牌"
	return "，".join(parts)


func _deck_detail_text(deck: Dictionary) -> String:
	var counts := {}
	for raw_card_id in deck.get("cards", []):
		var card_id := str(raw_card_id)
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	var card_ids = counts.keys()
	card_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _card_name(str(left)) < _card_name(str(right))
	)
	var lines: Array[String] = []
	for raw_card_id in card_ids:
		var card_id := str(raw_card_id)
		lines.append("%s ×%s" % [_card_name(card_id), int(counts.get(card_id, 0))])
	return "名称：%s\n介绍：%s\n主宰：%s\n卡数：%s\n\n卡牌：\n%s" % [
		str(deck.get("name", "")),
		str(deck.get("description", "暂无介绍")),
		_card_name(str(deck.get("master_id", ""))),
		Array(deck.get("cards", [])).size(),
		"\n".join(lines)
	]


func _panel_container(title: String) -> Dictionary:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 6)
	wrapper.add_child(_make_label(title, 16, HORIZONTAL_ALIGNMENT_LEFT))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.09, 0.12, 0.24), Color(0.72, 0.78, 0.92, 0.18), 1, 10))
	wrapper.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	return {"panel": wrapper, "body": body}


func _field_row(label_text: String, field: Control) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := _make_label(label_text, 13, HORIZONTAL_ALIGNMENT_LEFT)
	row.add_child(label)
	field.custom_minimum_size = Vector2(0, 40)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row


func _make_label(text: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	return label


func _make_dark_label(text: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.14, 0.19, 0.28, 1.0))
	return label


func _make_muted_label(text: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.42, 0.50, 0.62, 1.0))
	return label


func _make_subtle_label(text: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.70, 0.77, 0.86, 0.95))
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.10, 0.12, 0.16, 0.96), Color(0.74, 0.82, 0.98, 0.46), 1, 6))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.14, 0.18, 0.22, 0.98), Color(0.90, 0.82, 0.48, 0.82), 1, 6))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.06, 0.08, 0.10, 1.0), Color(0.90, 0.82, 0.48, 0.82), 1, 6))
	return button


func _small_button(text: String) -> Button:
	var button := _make_button(text)
	button.custom_minimum_size = Vector2(44, 38)
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _make_chip_button(text: String, selected: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0) if selected else Color(0.88, 0.92, 1.0, 0.92))
	button.add_theme_stylebox_override("normal", _panel_style(
		Color(0.16, 0.14, 0.08, 0.98) if selected else Color(0.10, 0.12, 0.16, 0.98),
		Color(0.80, 0.66, 0.18, 1.0) if selected else Color(0.48, 0.56, 0.68, 0.85),
		1,
		18
	))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.14, 0.17, 0.22, 1.0), Color(0.88, 0.73, 0.32, 1.0), 1, 18))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.08, 0.10, 0.14, 1.0), Color(0.88, 0.73, 0.32, 1.0), 1, 18))
	return button


func _action_button(text: String, callable: Callable, light_style: bool = false) -> Button:
	var button := _make_button(text)
	if light_style:
		button.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0))
		button.add_theme_stylebox_override("normal", _panel_style(Color(0.18, 0.15, 0.08, 0.96), Color(0.88, 0.73, 0.32, 0.9), 1, 12))
		button.add_theme_stylebox_override("hover", _panel_style(Color(0.22, 0.18, 0.10, 0.98), Color(0.95, 0.82, 0.45, 1.0), 1, 12))
		button.add_theme_stylebox_override("pressed", _panel_style(Color(0.12, 0.10, 0.06, 1.0), Color(0.95, 0.82, 0.45, 1.0), 1, 12))
	button.pressed.connect(callable)
	return button


func _menu_action_button(text: String, callable: Callable) -> Button:
	var button := _action_button(text, callable, true)
	button.custom_minimum_size = Vector2(96, 42)
	return button


func _faction_chip(label_text: String, faction: String) -> Button:
	var button := _make_chip_button(label_text, _selected_create_faction == faction)
	button.pressed.connect(func() -> void:
		_selected_create_faction = faction
		_rebuild_filter_options()
		_rebuild_card_grid()
	)
	return button


func _master_faction_chip(label_text: String, faction: String) -> Button:
	var button := _make_chip_button(label_text, _selected_master_faction == faction)
	button.pressed.connect(func() -> void:
		_selected_master_faction = faction
		_rebuild_master_cards()
	)
	return button


func _type_chip(label_text: String, card_type: String) -> Button:
	var button := _make_chip_button(label_text, _selected_create_type == card_type)
	button.pressed.connect(func() -> void:
		_selected_create_type = card_type
		_rebuild_filter_options()
		_rebuild_card_grid()
	)
	return button


func _gallery_faction_chip(label_text: String, faction: String) -> Button:
	var button := _make_chip_button(label_text, _selected_gallery_faction == faction)
	button.pressed.connect(func() -> void:
		_selected_gallery_faction = faction
		_rebuild_gallery_filters()
		_rebuild_gallery_grid()
	)
	return button


func _gallery_type_chip(label_text: String, card_type: String) -> Button:
	var button := _make_chip_button(label_text, _selected_gallery_type == card_type)
	button.pressed.connect(func() -> void:
		_selected_gallery_type = card_type
		_rebuild_gallery_filters()
		_rebuild_gallery_grid()
	)
	return button


func _set_card_as_background(card_id: String) -> void:
	DeckBuilderStore.set_selected_background_card(card_id)
	_refresh_background()
	_gallery_grid_dirty = true
	_refresh_gallery_view()
	emit_signal("background_changed", "主界面背景已切换为：%s" % _gallery_item_name(card_id))


func _clear_background_selection() -> void:
	DeckBuilderStore.clear_selected_background_card()
	_refresh_background()
	_gallery_grid_dirty = true
	_refresh_gallery_view()
	emit_signal("background_changed", "已恢复默认主界面背景。")


func _on_apply_preview_background_pressed() -> void:
	if _preview_texture == null:
		return
	var card_id := str(_preview_texture.get_meta("background_key", ""))
	if card_id.is_empty():
		return
	_set_card_as_background(card_id)


func _on_preview_texture_pressed() -> void:
	_on_apply_preview_background_pressed()
	_hide_card_preview()


func _gallery_item_name(item_id: String) -> String:
	var entry := CardGalleryCatalog.get_entry(item_id)
	if not entry.is_empty():
		return str(entry.get("name", item_id))
	return _card_name(item_id)


func _faction_display_name(faction: String) -> String:
	match faction:
		"":
			return "全部"
		"neutral":
			return "通用"
		"takamagahara":
			return "高天原"
		"heliopolis":
			return "太阳城"
		"suncity":
			return "太阳城"
		"gaotianyuan":
			return "高天原"
		"asgard":
			return "阿斯加德"
		"tianting":
			return "天廷"
		"olympus":
			return "奥林匹斯"
		"otherworld":
			return "彼界"
		"bijie":
			return "彼界"
		"classic":
			return "经典"
		_:
			return faction


func _type_display_name(card_type: String) -> String:
	match card_type:
		"":
			return "全部种类"
		"legion":
			return "军团"
		"tactic":
			return "战术"
		"counter_tactic":
			return "反制战术"
		"relic":
			return "圣物"
		"artifact":
			return "圣物"
		"master":
			return "主宰"
		"trial":
			return "试炼"
		"token":
			return "衍生物"
		"city":
			return "城邦"
		"morale":
			return "士气"
		"calamity":
			return "天灾"
		_:
			return card_type


func _ordered_type_keys(type_map: Dictionary) -> Array[String]:
	var ordered: Array[String] = []
	for card_type in ["legion", "tactic", "counter_tactic", "relic", "artifact", "trial", "city", "morale", "calamity", "token", "master"]:
		if type_map.has(card_type):
			ordered.append(card_type)
	var remaining := type_map.keys()
	remaining.sort()
	for raw_type in remaining:
		var card_type := str(raw_type)
		if card_type.is_empty() or ordered.has(card_type):
			continue
		ordered.append(card_type)
	return ordered


func _panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _make_light_catalog_card(image: Control, card_size: Vector2, title: String, subtitle: String, selected: bool) -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, card_size.y + 70)
	panel.add_theme_stylebox_override("panel", _panel_style(
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.94, 0.80, 0.38, 0.98) if selected else Color(0.0, 0.0, 0.0, 0.0),
		2 if selected else 0,
		12
	))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	box.add_child(image)
	var title_label := _make_label(title, 13, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_label)
	var subtitle_label := _make_subtle_label(subtitle, 11, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle_label)
	_set_mouse_ignore_recursive(panel)
	return panel


func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)


func _select_option_by_metadata(option_button: OptionButton, metadata_text: String) -> void:
	for index in range(option_button.get_item_count()):
		if str(option_button.get_item_metadata(index)) == metadata_text:
			option_button.select(index)
			return
	option_button.select(0)
