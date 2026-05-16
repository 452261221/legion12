extends Control
class_name MatchHistoryView

signal back_requested
signal resume_requested(replay_data: Dictionary, command_index: int, options: Dictionary)
signal table_replay_requested(record_id: String, command_index: int)

const MatchHistoryStore = preload("res://client/scripts/history/match_history_store.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const MatchReplaySession = preload("res://client/scripts/replay/match_replay_session.gd")

var _store := MatchHistoryStore.new()
var _current_tab := "all"
var _records: Array[Dictionary] = []
var _card_definitions := {}
var _replay_session := MatchReplaySession.new()
var _current_replay_data: Dictionary = {}

var _background_rect: TextureRect
var _panel: PanelContainer
var _panel_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _panel_root_vbox: VBoxContainer
var _title_label: Label
var _message_label: Label
var _statistics_hint_label: Label
var _health_hint_label: Label
var _repair_index_button: Button
var _capacity_hint_label: Label
var _cleanup_history_button: Button
var _tab_all_button: Button
var _tab_fav_button: Button
var _import_button: Button
var _search_edit: LineEdit
var _time_range_filter_option: OptionButton
var _mode_filter_option: OptionButton
var _status_filter_option: OptionButton
var _sort_filter_option: OptionButton
var _sort_order_toggle: CheckBox
var _favorites_only_toggle: CheckBox
var _resumable_only_toggle: CheckBox
var _imported_only_toggle: CheckBox
var _batch_select_all_button: Button
var _batch_clear_button: Button
var _batch_favorite_button: Button
var _batch_export_button: Button
var _batch_delete_button: Button
var _batch_selection_label: Label
var _reset_filters_button: Button
var _advanced_options_vbox: VBoxContainer
var _toggle_advanced_button: Button
var _export_button: Button
var _delete_button: Button
var _back_button: Button
var _list_scroll: ScrollContainer
var _list_box: VBoxContainer
var _list_section_label: Label
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_body: RichTextLabel
var _detail_ai_log_button: Button
var _timeline_scroll: ScrollContainer
var _timeline_box: VBoxContainer
var _timeline_key_only_toggle: CheckBox
var _timeline_prev_key_button: Button
var _timeline_next_key_button: Button
var _timeline_hint: RichTextLabel
var _timeline_view_replay_button: Button
var _timeline_resume_button: Button
var _timeline_view_log_button: Button
var _timeline_resume_recommend_button: Button
var _replay_panel: PanelContainer
var _replay_scroll: ScrollContainer
var _replay_board_panel: PanelContainer
var _replay_board_title: Label
var _replay_top_summary: Label
var _replay_top_front: HBoxContainer
var _replay_top_back: HBoxContainer
var _replay_bottom_summary: Label
var _replay_bottom_front: HBoxContainer
var _replay_bottom_back: HBoxContainer
var _replay_state_label: RichTextLabel
var _replay_step_label: Label
var _replay_first_button: Button
var _replay_prev_button: Button
var _replay_play_button: Button
var _replay_next_button: Button
var _replay_last_button: Button
var _replay_seek_label: Label
var _replay_seek_slider: HSlider
var _replay_close_button: Button
var _replay_timer: Timer
var _detail_back: Button
var _import_dialog: FileDialog
var _export_dialog: FileDialog
var _batch_export_dialog: FileDialog
var _resume_dialog: ConfirmationDialog
var _resume_ai_mode_option: OptionButton
var _resume_ai_side_option: OptionButton
var _resume_kind_option: OptionButton
var _resume_network_host_side_option: OptionButton
var _resume_llm_toggle: CheckBox
var _import_conflict_dialog: ConfirmationDialog
var _batch_delete_dialog: ConfirmationDialog
var _duel_log_dialog: ConfirmationDialog
var _duel_log_text: TextEdit
var _ai_log_dialog: ConfirmationDialog
var _ai_log_text: TextEdit

var _selected_record_id := ""
var _selected_record: Dictionary = {}
var _selected_record_ids: Dictionary = {}
var _replay_auto_playing := false
var _replay_seek_internal_update := false
var _replay_seek_dragging := false
var _pending_resume_replay_data: Dictionary = {}
var _pending_resume_command_index := 0
var _recommended_resume_command_index := -1
var _pending_focus_command_index := -1
var _timeline_focus_buttons: Dictionary = {}
var _timeline_collapsed_turns: Dictionary = {}
var _timeline_step_to_turn: Dictionary = {}
var _timeline_turn_rows_boxes: Dictionary = {}
var _timeline_turn_toggle_buttons: Dictionary = {}
var _timeline_key_only_enabled := false
var _timeline_selected_command_index := -1
var _timeline_key_indices: Array[int] = []
var _network_resume_available := false
var _pending_import_path := ""
var _mode_filter_values: Array[String] = ["", "formal", "network_formal", "resume_local", "resume_ai", "resume_network", "network_resume", "imported", "test", "network_test"]
var _status_filter_values: Array[String] = ["", "finished", "interrupted", "invalid"]
var _time_range_filter_values: Array[String] = ["", "7", "30", "90"]
var _sort_filter_values: Array[String] = ["started_at", "finished_at", "turn_count", "command_count", "title"]
var _record_capacity_limit := MatchHistoryStore.DEFAULT_RECORD_LIMIT
var _touch_scroll_target: ScrollContainer
var _touch_scroll_active := false
var _touch_scroll_started := false
var _touch_scroll_distance := 0.0

func _input(event: InputEvent) -> void:
	if not OS.has_feature("android"):
		return
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
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
		if _touch_scroll_started:
			_scroll_vertical_by(_touch_scroll_target, event.relative.y)
		return

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_load_card_definitions()

	_background_rect = TextureRect.new()
	_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background_rect)

	_panel = PanelContainer.new()
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override("panel", _make_history_panel_style("main"))
	add_child(_panel)

	_panel_scroll = ScrollContainer.new()
	_panel_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_panel_scroll)

	var panel_margin := MarginContainer.new()
	panel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_top", 16)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_bottom", 16)
	_panel_scroll.add_child(panel_margin)

	_panel_root_vbox = VBoxContainer.new()
	_panel_root_vbox.add_theme_constant_override("separation", 10)
	_panel_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_child(_panel_root_vbox)

	var header_hbox := _make_flow_row(10)
	_panel_root_vbox.add_child(header_hbox)

	_back_button = Button.new()
	_back_button.text = "返回"
	_back_button.custom_minimum_size = Vector2(80, 40)
	_back_button.add_theme_font_size_override("font_size", 16)
	_back_button.pressed.connect(_on_back_pressed)
	header_hbox.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "历史对局"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_hbox.add_child(_title_label)

	_import_button = Button.new()
	_import_button.text = "导入"
	_import_button.custom_minimum_size = Vector2(80, 40)
	_import_button.add_theme_font_size_override("font_size", 16)
	_import_button.pressed.connect(_on_import_pressed)
	header_hbox.add_child(_import_button)

	var tab_hbox := _make_flow_row(8)
	_panel_root_vbox.add_child(tab_hbox)

	_tab_all_button = Button.new()
	_tab_all_button.text = "全部"
	_tab_all_button.custom_minimum_size = Vector2(80, 40)
	_tab_all_button.add_theme_font_size_override("font_size", 16)
	_tab_all_button.toggle_mode = true
	_tab_all_button.button_pressed = true
	_tab_all_button.pressed.connect(func(): _switch_tab("all"))
	tab_hbox.add_child(_tab_all_button)

	_tab_fav_button = Button.new()
	_tab_fav_button.text = "收藏"
	_tab_fav_button.custom_minimum_size = Vector2(80, 40)
	_tab_fav_button.add_theme_font_size_override("font_size", 16)
	_tab_fav_button.toggle_mode = true
	_tab_fav_button.pressed.connect(func(): _switch_tab("favorites"))
	tab_hbox.add_child(_tab_fav_button)

	var advanced_panel := PanelContainer.new()
	advanced_panel.visible = false
	var advanced_style := StyleBoxFlat.new()
	advanced_style.bg_color = Color(0.04, 0.06, 0.09, 0.75)
	advanced_style.border_color = Color(0.3, 0.4, 0.6, 0.5)
	advanced_style.border_width_left = 1
	advanced_style.border_width_top = 1
	advanced_style.border_width_right = 1
	advanced_style.border_width_bottom = 1
	advanced_style.corner_radius_top_left = 6
	advanced_style.corner_radius_top_right = 6
	advanced_style.corner_radius_bottom_left = 6
	advanced_style.corner_radius_bottom_right = 6
	advanced_panel.add_theme_stylebox_override("panel", advanced_style)
	_panel_root_vbox.add_child(advanced_panel)

	var advanced_margin := MarginContainer.new()
	advanced_margin.add_theme_constant_override("margin_left", 12)
	advanced_margin.add_theme_constant_override("margin_top", 12)
	advanced_margin.add_theme_constant_override("margin_right", 12)
	advanced_margin.add_theme_constant_override("margin_bottom", 12)
	advanced_panel.add_child(advanced_margin)

	_advanced_options_vbox = VBoxContainer.new()
	_advanced_options_vbox.add_theme_constant_override("separation", 12)
	advanced_margin.add_child(_advanced_options_vbox)

	_toggle_advanced_button = Button.new()
	_toggle_advanced_button.text = "展开筛选与操作 ▼"
	_toggle_advanced_button.custom_minimum_size = Vector2(160, 40)
	_toggle_advanced_button.add_theme_font_size_override("font_size", 16)
	_toggle_advanced_button.toggle_mode = true
	_toggle_advanced_button.pressed.connect(func():
		var is_pressed := _toggle_advanced_button.button_pressed
		advanced_panel.visible = is_pressed
		_toggle_advanced_button.text = "收起筛选与操作 ▲" if is_pressed else "展开筛选与操作 ▼"
	)
	tab_hbox.add_child(_toggle_advanced_button)

	var search_row := VBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	_advanced_options_vbox.add_child(search_row)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索标题、主宰名、模式"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_submitted.connect(func(_text: String): _refresh_list())
	_search_edit.text_changed.connect(func(_text: String): _refresh_list())
	search_row.add_child(_search_edit)

	var filter_toggle_row := _make_flow_row(8)
	search_row.add_child(filter_toggle_row)

	_favorites_only_toggle = CheckBox.new()
	_favorites_only_toggle.text = "仅收藏"
	_favorites_only_toggle.custom_minimum_size = Vector2(80, 36)
	_favorites_only_toggle.toggled.connect(func(_value: bool): _refresh_list())
	filter_toggle_row.add_child(_favorites_only_toggle)

	_resumable_only_toggle = CheckBox.new()
	_resumable_only_toggle.text = "仅可继续"
	_resumable_only_toggle.custom_minimum_size = Vector2(90, 36)
	_resumable_only_toggle.toggled.connect(func(_value: bool): _refresh_list())
	filter_toggle_row.add_child(_resumable_only_toggle)

	_imported_only_toggle = CheckBox.new()
	_imported_only_toggle.text = "仅导入"
	_imported_only_toggle.custom_minimum_size = Vector2(80, 36)
	_imported_only_toggle.toggled.connect(func(_value: bool): _refresh_list())
	filter_toggle_row.add_child(_imported_only_toggle)

	_reset_filters_button = Button.new()
	_reset_filters_button.text = "重置条件"
	_reset_filters_button.custom_minimum_size = Vector2(80, 36)
	_reset_filters_button.pressed.connect(_reset_list_filters)
	filter_toggle_row.add_child(_reset_filters_button)

	var filter_row_2 := _make_flow_row(8)
	_advanced_options_vbox.add_child(filter_row_2)

	_time_range_filter_option = OptionButton.new()
	_time_range_filter_option.custom_minimum_size = Vector2(150, 36)
	_time_range_filter_option.item_selected.connect(func(_index: int): _refresh_list())
	filter_row_2.add_child(_time_range_filter_option)

	_mode_filter_option = OptionButton.new()
	_mode_filter_option.custom_minimum_size = Vector2(160, 36)
	_mode_filter_option.item_selected.connect(func(_index: int): _refresh_list())
	filter_row_2.add_child(_mode_filter_option)

	_status_filter_option = OptionButton.new()
	_status_filter_option.custom_minimum_size = Vector2(140, 36)
	_status_filter_option.item_selected.connect(func(_index: int): _refresh_list())
	filter_row_2.add_child(_status_filter_option)

	_sort_filter_option = OptionButton.new()
	_sort_filter_option.custom_minimum_size = Vector2(140, 36)
	_sort_filter_option.item_selected.connect(func(_index: int): _refresh_list())
	filter_row_2.add_child(_sort_filter_option)

	_sort_order_toggle = CheckBox.new()
	_sort_order_toggle.text = "升序"
	_sort_order_toggle.custom_minimum_size = Vector2(80, 36)
	_sort_order_toggle.toggled.connect(func(_value: bool): _refresh_list())
	filter_row_2.add_child(_sort_order_toggle)

	_setup_filter_options()

	var batch_row := HBoxContainer.new()
	batch_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	batch_row.add_theme_constant_override("separation", 6)
	_advanced_options_vbox.add_child(batch_row)

	_batch_select_all_button = Button.new()
	_batch_select_all_button.text = "全选"
	_batch_select_all_button.custom_minimum_size = Vector2(60, 36)
	_batch_select_all_button.pressed.connect(_on_batch_select_all_pressed)
	batch_row.add_child(_batch_select_all_button)

	_batch_clear_button = Button.new()
	_batch_clear_button.text = "清空选择"
	_batch_clear_button.custom_minimum_size = Vector2(82, 36)
	_batch_clear_button.pressed.connect(_on_batch_clear_pressed)
	batch_row.add_child(_batch_clear_button)

	_batch_favorite_button = Button.new()
	_batch_favorite_button.text = "批量收藏/取消收藏"
	_batch_favorite_button.custom_minimum_size = Vector2(134, 36)
	_batch_favorite_button.pressed.connect(_on_batch_favorite_pressed)
	batch_row.add_child(_batch_favorite_button)

	_batch_export_button = Button.new()
	_batch_export_button.text = "批量导出"
	_batch_export_button.custom_minimum_size = Vector2(74, 36)
	_batch_export_button.pressed.connect(_on_batch_export_pressed)
	batch_row.add_child(_batch_export_button)

	_batch_delete_button = Button.new()
	_batch_delete_button.text = "删除"
	_batch_delete_button.custom_minimum_size = Vector2(56, 36)
	_batch_delete_button.pressed.connect(_on_batch_delete_pressed)
	batch_row.add_child(_batch_delete_button)

	_batch_selection_label = Label.new()
	_batch_selection_label.text = "已选0条"
	_batch_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_batch_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_batch_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	batch_row.add_child(_batch_selection_label)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_root_vbox.add_child(_message_label)

	_statistics_hint_label = Label.new()
	_statistics_hint_label.text = ""
	_statistics_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_statistics_hint_label.visible = false
	_panel_root_vbox.add_child(_statistics_hint_label)

	var health_row := _make_flow_row(8)
	_panel_root_vbox.add_child(health_row)

	_health_hint_label = Label.new()
	_health_hint_label.text = ""
	_health_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_health_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(_health_hint_label)

	_repair_index_button = Button.new()
	_repair_index_button.text = "修复索引"
	_repair_index_button.visible = false
	_repair_index_button.pressed.connect(_on_repair_index_pressed)
	health_row.add_child(_repair_index_button)

	var capacity_row := _make_flow_row(8)
	_panel_root_vbox.add_child(capacity_row)

	_capacity_hint_label = Label.new()
	_capacity_hint_label.text = ""
	_capacity_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_capacity_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity_row.add_child(_capacity_hint_label)

	_cleanup_history_button = Button.new()
	_cleanup_history_button.text = "清理旧记录"
	_cleanup_history_button.visible = false
	_cleanup_history_button.pressed.connect(_on_cleanup_history_pressed)
	capacity_row.add_child(_cleanup_history_button)

	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.custom_minimum_size = Vector2(0.0, 420.0)
	_panel_root_vbox.add_child(_list_scroll)

	var list_section := VBoxContainer.new()
	list_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_section.add_theme_constant_override("separation", 10)
	_list_scroll.add_child(list_section)

	_list_section_label = Label.new()
	_list_section_label.text = "对局记录"
	_list_section_label.add_theme_font_size_override("font_size", 18)
	_style_history_label(_list_section_label, true)
	list_section.add_child(_list_section_label)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	list_section.add_child(_list_box)

	_detail_panel = PanelContainer.new()
	_detail_panel.visible = false
	_detail_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_detail_panel.add_theme_stylebox_override("panel", _make_history_panel_style("overlay"))
	add_child(_detail_panel)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_panel.add_child(_detail_scroll)

	var detail_margin := MarginContainer.new()
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_theme_constant_override("margin_left", 14)
	detail_margin.add_theme_constant_override("margin_top", 14)
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 14)
	_detail_scroll.add_child(detail_margin)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 10)
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(detail_vbox)

	var detail_header := HBoxContainer.new()
	detail_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_header.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_header.add_theme_constant_override("separation", 10)
	detail_vbox.add_child(detail_header)

	_detail_back = Button.new()
	_detail_back.text = "返回列表"
	_detail_back.custom_minimum_size = Vector2(116, 46)
	_detail_back.add_theme_font_size_override("font_size", 15)
	_detail_back.pressed.connect(_close_detail)
	detail_header.add_child(_detail_back)

	_detail_title = Label.new()
	_detail_title.text = ""
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_header.add_child(_detail_title)

	var detail_header_spacer := Control.new()
	detail_header_spacer.custom_minimum_size = Vector2(116, 46)
	detail_header.add_child(detail_header_spacer)

	_detail_body = RichTextLabel.new()
	_detail_body.fit_content = false
	_detail_body.scroll_active = true
	_detail_body.bbcode_enabled = true
	_detail_body.custom_minimum_size = Vector2(0.0, 280.0)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_stylebox_override("normal", _make_history_card_style(false))
	detail_vbox.add_child(_detail_body)

	var detail_action_row := _make_flow_row(10)
	detail_vbox.add_child(detail_action_row)
	_timeline_view_replay_button = Button.new()
	_timeline_view_replay_button.text = "查看回放"
	_timeline_view_replay_button.custom_minimum_size = Vector2(116, 44)
	_timeline_view_replay_button.pressed.connect(_on_timeline_view_replay_pressed)
	detail_action_row.add_child(_timeline_view_replay_button)
	_timeline_resume_button = Button.new()
	_timeline_resume_button.text = "继续对局"
	_timeline_resume_button.custom_minimum_size = Vector2(116, 44)
	_timeline_resume_button.pressed.connect(_on_timeline_resume_pressed)
	detail_action_row.add_child(_timeline_resume_button)
	_timeline_view_log_button = Button.new()
	_timeline_view_log_button.text = "查看日志"
	_timeline_view_log_button.custom_minimum_size = Vector2(116, 44)
	_timeline_view_log_button.pressed.connect(_on_timeline_view_log_pressed)
	detail_action_row.add_child(_timeline_view_log_button)
	_detail_ai_log_button = Button.new()
	_detail_ai_log_button.text = "AI日志"
	_detail_ai_log_button.custom_minimum_size = Vector2(100, 44)
	_detail_ai_log_button.pressed.connect(func():
		if not _selected_record_id.is_empty():
			_open_ai_log(_selected_record_id)
	)
	detail_action_row.add_child(_detail_ai_log_button)
	_export_button = Button.new()
	_export_button.text = "导出"
	_export_button.custom_minimum_size = Vector2(100, 44)
	_export_button.pressed.connect(_on_export_pressed)
	detail_action_row.add_child(_export_button)
	_delete_button = Button.new()
	_delete_button.text = "删除"
	_delete_button.custom_minimum_size = Vector2(100, 44)
	_delete_button.pressed.connect(_on_delete_pressed)
	detail_action_row.add_child(_delete_button)

	_replay_panel = PanelContainer.new()
	_replay_panel.visible = false
	_replay_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_replay_panel.add_theme_stylebox_override("panel", _make_history_panel_style("overlay"))
	add_child(_replay_panel)

	_replay_scroll = ScrollContainer.new()
	_replay_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_replay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_replay_panel.add_child(_replay_scroll)

	var replay_margin := MarginContainer.new()
	replay_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replay_margin.add_theme_constant_override("margin_left", 14)
	replay_margin.add_theme_constant_override("margin_top", 14)
	replay_margin.add_theme_constant_override("margin_right", 14)
	replay_margin.add_theme_constant_override("margin_bottom", 14)
	_replay_scroll.add_child(replay_margin)

	var replay_vbox := VBoxContainer.new()
	replay_vbox.add_theme_constant_override("separation", 10)
	replay_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_margin.add_child(replay_vbox)

	var replay_header := _make_flow_row(8)
	replay_vbox.add_child(replay_header)

	_replay_close_button = Button.new()
	_replay_close_button.text = "关闭回放"
	_replay_close_button.pressed.connect(_close_replay_view)
	replay_header.add_child(_replay_close_button)

	_replay_step_label = Label.new()
	_replay_step_label.text = "回放"
	_replay_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_header.add_child(_replay_step_label)

	_replay_first_button = Button.new()
	_replay_first_button.text = "开头"
	_replay_first_button.pressed.connect(_on_replay_first_pressed)
	replay_header.add_child(_replay_first_button)

	_replay_prev_button = Button.new()
	_replay_prev_button.text = "上一步"
	_replay_prev_button.pressed.connect(_on_replay_prev_pressed)
	replay_header.add_child(_replay_prev_button)

	_replay_play_button = Button.new()
	_replay_play_button.text = "播放"
	_replay_play_button.pressed.connect(_on_replay_play_pressed)
	replay_header.add_child(_replay_play_button)

	_replay_next_button = Button.new()
	_replay_next_button.text = "下一步"
	_replay_next_button.pressed.connect(_on_replay_next_pressed)
	replay_header.add_child(_replay_next_button)

	_replay_last_button = Button.new()
	_replay_last_button.text = "结尾"
	_replay_last_button.pressed.connect(_on_replay_last_pressed)
	replay_header.add_child(_replay_last_button)

	var replay_seek_row := _make_flow_row(8)
	replay_vbox.add_child(replay_seek_row)

	_replay_seek_label = Label.new()
	_replay_seek_label.text = "进度 0/0"
	_replay_seek_label.custom_minimum_size = Vector2(110.0, 0.0)
	replay_seek_row.add_child(_replay_seek_label)

	_replay_seek_slider = HSlider.new()
	_replay_seek_slider.min_value = 0
	_replay_seek_slider.max_value = 0
	_replay_seek_slider.step = 1
	_replay_seek_slider.value = 0
	_replay_seek_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay_seek_slider.value_changed.connect(_on_replay_seek_value_changed)
	_replay_seek_slider.drag_ended.connect(_on_replay_seek_drag_ended)
	_replay_seek_slider.gui_input.connect(_on_replay_seek_gui_input)
	replay_seek_row.add_child(_replay_seek_slider)

	_replay_board_panel = PanelContainer.new()
	_replay_board_panel.add_theme_stylebox_override("panel", _make_history_panel_style("section"))
	replay_vbox.add_child(_replay_board_panel)

	var board_vbox := VBoxContainer.new()
	board_vbox.add_theme_constant_override("separation", 8)
	_replay_board_panel.add_child(board_vbox)

	_replay_board_title = Label.new()
	_replay_board_title.text = "只读战场"
	_replay_board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_vbox.add_child(_replay_board_title)

	_replay_top_summary = Label.new()
	_replay_top_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_vbox.add_child(_replay_top_summary)

	var top_back_title := Label.new()
	top_back_title.text = "对手后排"
	board_vbox.add_child(top_back_title)
	_replay_top_back = HBoxContainer.new()
	_replay_top_back.add_theme_constant_override("separation", 6)
	board_vbox.add_child(_replay_top_back)

	var top_front_title := Label.new()
	top_front_title.text = "对手前排"
	board_vbox.add_child(top_front_title)
	_replay_top_front = HBoxContainer.new()
	_replay_top_front.add_theme_constant_override("separation", 6)
	board_vbox.add_child(_replay_top_front)

	var divider := HSeparator.new()
	board_vbox.add_child(divider)

	_replay_bottom_summary = Label.new()
	_replay_bottom_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_vbox.add_child(_replay_bottom_summary)

	var bottom_front_title := Label.new()
	bottom_front_title.text = "我方前排"
	board_vbox.add_child(bottom_front_title)
	_replay_bottom_front = HBoxContainer.new()
	_replay_bottom_front.add_theme_constant_override("separation", 6)
	board_vbox.add_child(_replay_bottom_front)

	var bottom_back_title := Label.new()
	bottom_back_title.text = "我方后排"
	board_vbox.add_child(bottom_back_title)
	_replay_bottom_back = HBoxContainer.new()
	_replay_bottom_back.add_theme_constant_override("separation", 6)
	board_vbox.add_child(_replay_bottom_back)

	_replay_state_label = RichTextLabel.new()
	_replay_state_label.bbcode_enabled = true
	_replay_state_label.fit_content = false
	_replay_state_label.scroll_active = true
	_replay_state_label.custom_minimum_size = Vector2(0.0, 180.0)
	_replay_state_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replay_vbox.add_child(_replay_state_label)

	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.add_filter("*.json; Replay JSON")
	_import_dialog.file_selected.connect(_on_import_file_selected)
	add_child(_import_dialog)

	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.add_filter("*.json; Replay JSON")
	_export_dialog.file_selected.connect(_on_export_file_selected)
	add_child(_export_dialog)

	_batch_export_dialog = FileDialog.new()
	_batch_export_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_batch_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_batch_export_dialog.dir_selected.connect(_on_batch_export_dir_selected)
	add_child(_batch_export_dialog)

	_resume_dialog = ConfirmationDialog.new()
	_resume_dialog.title = "继续对局"
	_resume_dialog.ok_button_text = "开始"
	_resume_dialog.cancel_button_text = "取消"
	_resume_dialog.confirmed.connect(_on_resume_confirmed)
	add_child(_resume_dialog)

	var resume_vbox := VBoxContainer.new()
	resume_vbox.add_theme_constant_override("separation", 10)
	_resume_dialog.add_child(resume_vbox)

	var resume_kind_row := _make_flow_row(10)
	resume_vbox.add_child(resume_kind_row)

	var resume_kind_label := Label.new()
	resume_kind_label.text = "续战方式"
	resume_kind_row.add_child(resume_kind_label)

	_resume_kind_option = OptionButton.new()
	_resume_kind_option.custom_minimum_size = Vector2(220, 36)
	_resume_kind_option.add_item("本地继续", 0)
	_resume_kind_option.add_item("联机继续（房主）", 1)
	_resume_kind_option.selected = 0
	_resume_kind_option.disabled = true
	_resume_kind_option.item_selected.connect(_on_resume_kind_selected)
	resume_kind_row.add_child(_resume_kind_option)

	var resume_network_row := _make_flow_row(10)
	resume_vbox.add_child(resume_network_row)

	var resume_network_label := Label.new()
	resume_network_label.text = "房主操作"
	resume_network_row.add_child(resume_network_label)

	_resume_network_host_side_option = OptionButton.new()
	_resume_network_host_side_option.custom_minimum_size = Vector2(220, 36)
	_resume_network_host_side_option.add_item("玩家1（推荐）", 0)
	_resume_network_host_side_option.add_item("玩家2", 1)
	_resume_network_host_side_option.selected = 0
	_resume_network_host_side_option.disabled = true
	resume_network_row.add_child(_resume_network_host_side_option)

	var resume_mode_row := _make_flow_row(10)
	resume_vbox.add_child(resume_mode_row)

	var resume_mode_label := Label.new()
	resume_mode_label.text = "模式"
	resume_mode_row.add_child(resume_mode_label)

	_resume_ai_mode_option = OptionButton.new()
	_resume_ai_mode_option.custom_minimum_size = Vector2(220, 36)
	_resume_ai_mode_option.add_item("无AI（双方都可操作）", 0)
	_resume_ai_mode_option.add_item("对战人机", 1)
	_resume_ai_mode_option.add_item("双方人机（双方 AI）", 2)
	_resume_ai_mode_option.selected = 0
	_resume_ai_mode_option.item_selected.connect(_on_resume_ai_mode_selected)
	resume_mode_row.add_child(_resume_ai_mode_option)

	var resume_side_row := _make_flow_row(10)
	resume_vbox.add_child(resume_side_row)

	var resume_side_label := Label.new()
	resume_side_label.text = "AI 控制"
	resume_side_row.add_child(resume_side_label)

	_resume_ai_side_option = OptionButton.new()
	_resume_ai_side_option.custom_minimum_size = Vector2(220, 36)
	_resume_ai_side_option.add_item("玩家2（推荐）", 1)
	_resume_ai_side_option.add_item("玩家1", 0)
	_resume_ai_side_option.selected = 0
	_resume_ai_side_option.disabled = true
	resume_side_row.add_child(_resume_ai_side_option)

	_resume_llm_toggle = CheckBox.new()
	_resume_llm_toggle.text = "接入大模型"
	_resume_llm_toggle.button_pressed = false
	_resume_llm_toggle.disabled = true
	resume_vbox.add_child(_resume_llm_toggle)

	_import_conflict_dialog = ConfirmationDialog.new()
	_import_conflict_dialog.title = "导入冲突"
	_import_conflict_dialog.ok_button_text = "覆盖导入"
	_import_conflict_dialog.cancel_button_text = "取消"
	_import_conflict_dialog.confirmed.connect(_on_import_conflict_confirmed)
	add_child(_import_conflict_dialog)

	_batch_delete_dialog = ConfirmationDialog.new()
	_batch_delete_dialog.title = "批量删除"
	_batch_delete_dialog.ok_button_text = "删除所选"
	_batch_delete_dialog.cancel_button_text = "取消"
	_batch_delete_dialog.confirmed.connect(_on_batch_delete_confirmed)
	add_child(_batch_delete_dialog)

	_duel_log_dialog = ConfirmationDialog.new()
	_duel_log_dialog.title = "对局日志"
	_duel_log_dialog.ok_button_text = "关闭"
	_duel_log_dialog.cancel_button_text = "关闭"
	add_child(_duel_log_dialog)
	var duel_log_margin := MarginContainer.new()
	duel_log_margin.add_theme_constant_override("margin_left", 10)
	duel_log_margin.add_theme_constant_override("margin_top", 10)
	duel_log_margin.add_theme_constant_override("margin_right", 10)
	duel_log_margin.add_theme_constant_override("margin_bottom", 10)
	_duel_log_dialog.add_child(duel_log_margin)
	_duel_log_text = TextEdit.new()
	_duel_log_text.custom_minimum_size = Vector2(980, 560)
	_duel_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_duel_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_duel_log_text.editable = false
	_duel_log_text.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	duel_log_margin.add_child(_duel_log_text)

	_ai_log_dialog = ConfirmationDialog.new()
	_ai_log_dialog.title = "AI日志"
	_ai_log_dialog.ok_button_text = "关闭"
	_ai_log_dialog.cancel_button_text = "关闭"
	add_child(_ai_log_dialog)
	var ai_log_margin := MarginContainer.new()
	ai_log_margin.add_theme_constant_override("margin_left", 10)
	ai_log_margin.add_theme_constant_override("margin_top", 10)
	ai_log_margin.add_theme_constant_override("margin_right", 10)
	ai_log_margin.add_theme_constant_override("margin_bottom", 10)
	_ai_log_dialog.add_child(ai_log_margin)
	_ai_log_text = TextEdit.new()
	_ai_log_text.custom_minimum_size = Vector2(980, 560)
	_ai_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ai_log_text.editable = false
	_ai_log_text.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	ai_log_margin.add_child(_ai_log_text)

	_replay_timer = Timer.new()
	_replay_timer.one_shot = false
	_replay_timer.wait_time = 0.65
	_replay_timer.timeout.connect(_on_replay_timer_timeout)
	add_child(_replay_timer)
	_apply_history_theme()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func _pick_scroll_target(global_position: Vector2) -> ScrollContainer:
	if _replay_panel != null and _replay_panel.visible and _replay_scroll != null:
		if _replay_scroll.get_global_rect().has_point(global_position):
			return _replay_scroll
	if _detail_panel != null and _detail_panel.visible:
		if _timeline_scroll != null and _timeline_scroll.get_global_rect().has_point(global_position):
			return _timeline_scroll
		if _detail_scroll != null and _detail_scroll.get_global_rect().has_point(global_position):
			return _detail_scroll
	if _list_scroll != null and _list_scroll.visible and _list_scroll.get_global_rect().has_point(global_position):
		return _list_scroll
	if _panel_scroll != null and _panel_scroll.visible and _panel_scroll.get_global_rect().has_point(global_position):
		return _panel_scroll
	return null


func _scroll_vertical_by(target: ScrollContainer, delta_y: float) -> void:
	if target == null:
		return
	var bar := target.get_v_scroll_bar()
	if bar == null:
		return
	var max_value := int(bar.max_value)
	target.scroll_vertical = clampi(target.scroll_vertical - int(delta_y), 0, max_value)

func _make_history_panel_style(kind: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.20)
	style.border_color = Color(0.74, 0.82, 0.98, 0.18)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	if kind == "overlay":
		style.bg_color = Color(0.02, 0.03, 0.05, 0.28)
		style.border_color = Color(0.74, 0.82, 0.98, 0.20)
	elif kind == "section":
		style.bg_color = Color(0.03, 0.05, 0.07, 0.36)
		style.border_color = Color(0.74, 0.82, 0.98, 0.18)
	return style

func _make_history_card_style(selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.88)
	style.border_color = Color(0.86, 0.90, 1.0, 0.34)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	if selected:
		style.bg_color = Color(0.08, 0.12, 0.18, 0.94)
		style.border_color = Color(0.96, 0.98, 1.0, 0.52)
	return style

func _style_history_button(button: BaseButton, accent: bool = false) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	button.remove_theme_color_override("font_hover_color")
	button.remove_theme_color_override("font_pressed_color")
	button.remove_theme_color_override("font_focus_color")
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.08, 0.11, 0.82)
	normal.border_color = Color(0.78, 0.84, 1.0, 0.55)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	if accent:
		normal.border_color = Color(0.92, 0.95, 1.0, 0.72)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.12, 0.16, 0.20, 0.92)
	hover.border_color = Color(0.66, 0.92, 1.0, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.04, 0.06, 0.08, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)

func _style_history_option(option: OptionButton) -> void:
	if option == null:
		return
	_style_history_button(option, false)

func _style_history_checkbox(checkbox: CheckBox, compact: bool = false) -> void:
	if checkbox == null:
		return
	checkbox.add_theme_font_size_override("font_size", 13)
	checkbox.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	checkbox.add_theme_color_override("font_hover_color", Color(0.98, 0.99, 1.0, 1.0))
	checkbox.add_theme_color_override("font_pressed_color", Color(0.98, 0.99, 1.0, 1.0))
	checkbox.add_theme_color_override("font_focus_color", Color(0.98, 0.99, 1.0, 1.0))
	checkbox.add_theme_constant_override("h_separation", 6 if not compact else 0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.08, 0.11, 0.72) if not compact else Color(0.05, 0.07, 0.10, 0.42)
	normal.border_color = Color(0.78, 0.84, 1.0, 0.55)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	normal.content_margin_left = 8 if not compact else 4
	normal.content_margin_top = 5 if not compact else 3
	normal.content_margin_right = 8 if not compact else 4
	normal.content_margin_bottom = 5 if not compact else 3
	checkbox.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.12, 0.16, 0.20, 0.88) if not compact else Color(0.10, 0.16, 0.20, 0.62)
	hover.border_color = Color(0.66, 0.92, 1.0, 0.95)
	checkbox.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.08, 0.12, 0.18, 0.92) if not compact else Color(0.09, 0.14, 0.20, 0.74)
	pressed.border_color = Color(0.78, 0.92, 1.0, 0.98)
	checkbox.add_theme_stylebox_override("pressed", pressed)
	checkbox.add_theme_stylebox_override("focus", hover)
	if compact:
		checkbox.custom_minimum_size = Vector2(30.0, 30.0)
		checkbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _style_history_label(label: Label, emphasis: bool = false) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0) if emphasis else Color(0.86, 0.90, 0.97, 0.95))

func _apply_history_theme() -> void:
	for button in [_back_button, _import_button, _tab_all_button, _tab_fav_button, _toggle_advanced_button, _reset_filters_button, _batch_select_all_button, _batch_clear_button, _batch_favorite_button, _batch_export_button, _batch_delete_button, _repair_index_button, _cleanup_history_button, _detail_back, _export_button, _detail_ai_log_button, _delete_button, _timeline_view_replay_button, _timeline_resume_button, _timeline_view_log_button, _timeline_prev_key_button, _timeline_next_key_button, _timeline_resume_recommend_button, _replay_close_button, _replay_first_button, _replay_prev_button, _replay_play_button, _replay_next_button, _replay_last_button]:
		_style_history_button(button, button in [_import_button, _export_button, _timeline_resume_recommend_button, _batch_export_button, _timeline_view_replay_button, _timeline_resume_button])
	for toggle in [_favorites_only_toggle, _resumable_only_toggle, _imported_only_toggle, _sort_order_toggle, _timeline_key_only_toggle, _resume_llm_toggle]:
		_style_history_checkbox(toggle, false)
	for option in [_time_range_filter_option, _mode_filter_option, _status_filter_option, _sort_filter_option, _resume_kind_option, _resume_network_host_side_option, _resume_ai_mode_option, _resume_ai_side_option]:
		_style_history_option(option)
	for label in [_message_label, _statistics_hint_label, _health_hint_label, _capacity_hint_label, _batch_selection_label, _replay_seek_label, _replay_step_label, _replay_board_title, _replay_top_summary, _replay_bottom_summary, _detail_title, _title_label]:
		_style_history_label(label, label in [_detail_title, _title_label, _replay_board_title, _replay_step_label])
	
	# Override font size for primary header buttons
	for b in [_back_button, _import_button, _tab_all_button, _tab_fav_button, _toggle_advanced_button]:
		if b != null:
			b.add_theme_font_size_override("font_size", 16)
	for b in [_timeline_view_replay_button, _timeline_resume_button, _timeline_view_log_button, _detail_ai_log_button, _export_button, _delete_button]:
		if b != null:
			b.add_theme_font_size_override("font_size", 15)

func _make_flow_row(separation: int = 8) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", separation)
	row.add_theme_constant_override("v_separation", separation)
	return row

func _update_responsive_layout() -> void:
	if _panel == null:
		return
	var layout_size := size
	if layout_size.x < 240.0 or layout_size.y < 240.0:
		layout_size = get_viewport_rect().size
	var side_margin: float = clamp(layout_size.x * 0.02, 8.0, 18.0)
	var top_margin: float = clamp(layout_size.y * 0.01, 8.0, 18.0)
	var bottom_margin: float = clamp(layout_size.y * 0.01, 8.0, 18.0)
	var panel_width: float = max(layout_size.x - side_margin * 2.0, 320.0)
	var panel_height: float = max(layout_size.y - top_margin - bottom_margin, 320.0)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.position = Vector2(side_margin, top_margin)
	if _detail_panel != null:
		_detail_panel.size = Vector2(panel_width, panel_height)
		_detail_panel.position = Vector2(side_margin, top_margin)
	if _replay_panel != null:
		_replay_panel.size = Vector2(panel_width, panel_height)
		_replay_panel.position = Vector2(side_margin, top_margin)
	if _panel_root_vbox != null:
		_panel_root_vbox.custom_minimum_size.x = max(panel_width - 32.0, 280.0)
	if _list_box != null:
		_list_box.custom_minimum_size.x = max(panel_width - 64.0, 240.0)

func set_background_texture(texture: Texture2D) -> void:
	if _background_rect == null:
		return
	_background_rect.texture = texture

func open_view() -> void:
	_update_responsive_layout()
	visible = true
	_panel.visible = true
	_detail_panel.visible = false
	_selected_record_id = ""
	_selected_record_ids.clear()
	_reset_resume_recommendation()
	_refresh_list()
	call_deferred("_update_responsive_layout")

func open_view_with_record(record_id: String) -> void:
	open_view()
	call_deferred("_open_detail", record_id)

func open_view_with_record_and_step(record_id: String, command_index: int) -> void:
	_pending_focus_command_index = command_index
	open_view()
	call_deferred("_open_detail", record_id)

func close_view() -> void:
	visible = false
	_panel.visible = false
	_detail_panel.visible = false
	_selected_record_id = ""
	_selected_record_ids.clear()
	_pending_focus_command_index = -1
	_reset_resume_recommendation()
	_close_replay_view()

func _on_back_pressed() -> void:
	close_view()
	back_requested.emit()

func _switch_tab(tab: String) -> void:
	_current_tab = tab
	_tab_all_button.button_pressed = tab == "all"
	_tab_fav_button.button_pressed = tab == "favorites"
	_refresh_list()

func _refresh_list(preserve_message: bool = false) -> void:
	if not preserve_message:
		_message_label.text = ""
	if _statistics_hint_label != null:
		_statistics_hint_label.text = ""
	_refresh_storage_health_hint()
	_refresh_capacity_hint()
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var result = _store.list_records(_current_tab, _build_list_filters())
	if not bool(result.get("ok", false)):
		_message_label.text = "加载失败：%s" % str(result.get("message", ""))
		_update_batch_action_state()
		return
	_records = result.get("data", {}).get("records", [])
	if _list_section_label != null:
		_list_section_label.text = "对局记录（%s）" % _records.size()
	_prune_batch_selection_to_visible_records()
	_refresh_statistics_hint()
	if _records.is_empty():
		_message_label.text = "没有符合条件的历史对局" if _has_active_list_filters() else "暂无历史对局"
		_update_batch_action_state()
		return
	for record in _records:
		_list_box.add_child(_build_record_row(record))
	_update_batch_action_state()

func _refresh_statistics_hint() -> void:
	if _statistics_hint_label == null:
		return
	var result = _store.get_statistics_summary(_current_tab, _build_list_filters())
	if not bool(result.get("ok", false)):
		_statistics_hint_label.text = ""
		return
	var data: Dictionary = result.get("data", {})
	var total_count := int(data.get("total_count", 0))
	if total_count <= 0:
		_statistics_hint_label.text = ""
		return
	var average_turn_count := float(data.get("average_turn_count", 0.0))
	var average_command_count := float(data.get("average_command_count", 0.0))
	var top_mode := _format_mode(str(data.get("top_mode", "")))
	_statistics_hint_label.text = "统计摘要：共 %s 条，收藏 %s 条，可继续 %s 条，导入 %s 条，已结束 %s 条，中断 %s 条，平均 %.1f 回合 / %.1f 步，最多模式 %s（%s 条）" % [
		total_count,
		int(data.get("favorite_count", 0)),
		int(data.get("resumable_count", 0)),
		int(data.get("imported_count", 0)),
		int(data.get("finished_count", 0)),
		int(data.get("interrupted_count", 0)),
		average_turn_count,
		average_command_count,
		top_mode,
		int(data.get("top_mode_count", 0))
	]

func _refresh_detail_after_storage_change(status_message: String = "") -> void:
	if _selected_record_id.is_empty():
		if not status_message.is_empty():
			_message_label.text = status_message
		return
	var record_result = _store.get_record(_selected_record_id)
	if not bool(record_result.get("ok", false)):
		_close_detail()
		_message_label.text = "当前查看的历史记录已失效，详情已关闭。"
		if not status_message.is_empty():
			_message_label.text = "%s 当前查看的历史记录已失效，详情已关闭。" % status_message
		return
	_open_detail(_selected_record_id)
	if not status_message.is_empty():
		_message_label.text = status_message

func _build_record_row(record: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 126.0)
	card.add_theme_stylebox_override("panel", _make_history_card_style(_selected_record_id == str(record.get("record_id", ""))))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var record_id := str(record.get("record_id", ""))
	var top_row := HFlowContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("h_separation", 8)
	top_row.add_theme_constant_override("v_separation", 8)
	row.add_child(top_row)
	var select_box := CheckBox.new()
	select_box.button_pressed = _selected_record_ids.has(record_id)
	select_box.toggled.connect(func(value: bool): _set_record_selected(record_id, value))
	_style_history_checkbox(select_box, true)
	top_row.add_child(select_box)
	var title_label := Label.new()
	title_label.text = str(record.get("title", "未命名历史记录"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 16)
	_style_history_label(title_label, true)
	top_row.add_child(title_label)
	var state_label := Label.new()
	state_label.text = _format_status(str(record.get("status", "")))
	_style_history_label(state_label, false)
	top_row.add_child(state_label)
	var main_button := Button.new()
	main_button.text = "查看详情"
	main_button.pressed.connect(func(): _open_detail(record_id))
	_style_history_button(main_button, false)
	top_row.add_child(main_button)
	var fav_button := Button.new()
	fav_button.toggle_mode = true
	fav_button.button_pressed = bool(record.get("is_favorite", false))
	fav_button.text = "★" if fav_button.button_pressed else "☆"
	fav_button.add_theme_font_size_override("font_size", 20)
	fav_button.custom_minimum_size = Vector2(40, 40)
	fav_button.pressed.connect(func():
		var rid := str(record.get("record_id", ""))
		var new_value := not bool(record.get("is_favorite", false))
		var toggle_result = _store.set_favorite(rid, new_value)
		if bool(toggle_result.get("ok", false)):
			record["is_favorite"] = new_value
			fav_button.button_pressed = new_value
			fav_button.text = "★" if new_value else "☆"
			if _current_tab == "favorites" and not new_value:
				_refresh_list()
	)
	_style_history_button(fav_button, fav_button.button_pressed)
	top_row.add_child(fav_button)
	var meta_label := Label.new()
	meta_label.text = _format_record_row_text(record)
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.add_theme_font_size_override("font_size", 14)
	_style_history_label(meta_label, false)
	row.add_child(meta_label)
	var info_row := HFlowContainer.new()
	info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_theme_constant_override("h_separation", 8)
	info_row.add_theme_constant_override("v_separation", 6)
	row.add_child(info_row)
	for tag_text in _build_record_tags(record):
		var tag := Label.new()
		tag.text = tag_text
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.92))
		tag.add_theme_stylebox_override("normal", _make_history_card_style(false))
		info_row.add_child(tag)
	return card

func _prune_batch_selection_to_visible_records() -> void:
	var visible_ids := {}
	for record in _records:
		if record is Dictionary:
			visible_ids[str(record.get("record_id", ""))] = true
	var kept := {}
	for record_id in _selected_record_ids.keys():
		if visible_ids.has(str(record_id)):
			kept[str(record_id)] = true
	_selected_record_ids = kept

func _set_record_selected(record_id: String, value: bool) -> void:
	if record_id.is_empty():
		return
	if value:
		_selected_record_ids[record_id] = true
	else:
		_selected_record_ids.erase(record_id)
	_update_batch_action_state()

func _visible_record_ids() -> Array[String]:
	var ids: Array[String] = []
	for record in _records:
		if record is Dictionary:
			var record_id := str(record.get("record_id", ""))
			if not record_id.is_empty():
				ids.append(record_id)
	return ids

func _update_batch_action_state() -> void:
	var selected_count := _selected_record_ids.size()
	if _batch_selection_label != null:
		_batch_selection_label.text = "已选%s条" % selected_count
	if _batch_clear_button != null:
		_batch_clear_button.disabled = selected_count <= 0
	if _batch_favorite_button != null:
		_batch_favorite_button.disabled = selected_count <= 0
	if _batch_export_button != null:
		_batch_export_button.disabled = selected_count <= 0
	if _batch_delete_button != null:
		_batch_delete_button.disabled = selected_count <= 0
	if _batch_select_all_button != null:
		_batch_select_all_button.disabled = _records.is_empty()

func _on_batch_select_all_pressed() -> void:
	for record_id in _visible_record_ids():
		_selected_record_ids[record_id] = true
	_refresh_list(true)

func _on_batch_clear_pressed() -> void:
	_selected_record_ids.clear()
	_refresh_list(true)

func _toggle_batch_favorite() -> void:
	var selected_ids: Array[String] = []
	for record_id in _selected_record_ids.keys():
		selected_ids.append(str(record_id))
	selected_ids.sort()
	var favorited_count := 0
	var unfavorited_count := 0
	var failed_count := 0
	for record_id in selected_ids:
		var record_result = _store.get_record(record_id)
		if not bool(record_result.get("ok", false)):
			failed_count += 1
			continue
		var record: Dictionary = record_result.get("data", {})
		var new_value := not bool(record.get("is_favorite", false))
		var result = _store.set_favorite(record_id, new_value)
		if bool(result.get("ok", false)):
			if new_value:
				favorited_count += 1
			else:
				unfavorited_count += 1
			continue
		failed_count += 1
	_refresh_list(true)
	var message_parts: Array[String] = []
	if favorited_count > 0:
		message_parts.append("收藏 %s 条" % favorited_count)
	if unfavorited_count > 0:
		message_parts.append("取消收藏 %s 条" % unfavorited_count)
	if message_parts.is_empty():
		message_parts.append("更新 0 条")
	_message_label.text = "批量收藏/取消收藏完成：%s" % "，".join(message_parts)
	if failed_count > 0:
		_message_label.text += "，失败 %s 条" % failed_count
	if _selected_record_id.is_empty():
		return
	_refresh_detail_after_storage_change(_message_label.text)

func _on_batch_favorite_pressed() -> void:
	if _selected_record_ids.is_empty():
		return
	_toggle_batch_favorite()

func _on_batch_export_pressed() -> void:
	if _selected_record_ids.is_empty():
		return
	_batch_export_dialog.popup_centered_ratio(0.7)

func _on_batch_export_dir_selected(path: String) -> void:
	var selected_ids: Array[String] = []
	for record_id in _selected_record_ids.keys():
		selected_ids.append(str(record_id))
	selected_ids.sort()
	var success_count := 0
	var skipped_count := 0
	var failure_messages: Array[String] = []
	for record_id in selected_ids:
		var record_result = _store.get_record(record_id)
		if not bool(record_result.get("ok", false)):
			failure_messages.append("读取记录失败")
			continue
		var record: Dictionary = record_result.get("data", {})
		var replay_id := str(record.get("replay_id", record_id))
		var target_path := "%s/%s.l12r.json" % [path, replay_id]
		var export_result = _store.export_record(record_id, target_path)
		if bool(export_result.get("ok", false)):
			success_count += 1
			continue
		if str(export_result.get("code", "")) == "EXPORT_TARGET_EXISTS":
			skipped_count += 1
			continue
		failure_messages.append(_format_store_result_message(export_result))
	var message := "批量导出完成：成功 %s 条" % success_count
	if skipped_count > 0:
		message += "，跳过已存在 %s 条" % skipped_count
	if not failure_messages.is_empty():
		message += "，失败 %s 条（%s）" % [failure_messages.size(), failure_messages[0]]
	_message_label.text = message

func _on_batch_delete_pressed() -> void:
	if _selected_record_ids.is_empty():
		return
	_batch_delete_dialog.dialog_text = "确认删除当前选中的 %s 条历史记录？此操作会同时删除对应回放文件。" % _selected_record_ids.size()
	_batch_delete_dialog.popup_centered()

func _on_batch_delete_confirmed() -> void:
	var selected_ids: Array[String] = []
	for record_id in _selected_record_ids.keys():
		selected_ids.append(str(record_id))
	selected_ids.sort()
	var removed_count := 0
	var failed_count := 0
	for record_id in selected_ids:
		var result = _store.delete_record(record_id, true)
		if bool(result.get("ok", false)):
			removed_count += 1
			continue
		failed_count += 1
	if _selected_record_id.is_empty():
		_selected_record_ids.clear()
		_refresh_list(true)
		_message_label.text = "批量删除完成：删除 %s 条" % removed_count
		if failed_count > 0:
			_message_label.text += "，失败 %s 条" % failed_count
		return
	_refresh_list(true)
	var status_message := "批量删除完成：删除 %s 条" % removed_count
	if failed_count > 0:
		status_message += "，失败 %s 条" % failed_count
	_selected_record_ids.clear()
	_refresh_detail_after_storage_change(status_message)

func _format_record_row_text(record: Dictionary) -> String:
	var title := str(record.get("title", "未命名历史记录"))
	var mode := _format_mode(str(record.get("mode", "")))
	var winner := str(record.get("winner_master_name", ""))
	if winner.is_empty():
		winner = "未分胜负"
	var started_at := int(record.get("started_at", 0))
	var turns := int(record.get("turn_count", 0))
	var steps := int(record.get("command_count", 0))
	return "%s\n模式：%s | 胜者：%s\n时间：%s | %s 回合 | %s 步" % [title, mode, winner, _format_time(started_at), turns, steps]

func _build_record_tags(record: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	if bool(record.get("can_continue", false)):
		tags.append("可继续")
	if bool(record.get("is_imported", false)):
		tags.append("导入")
	if bool(record.get("is_favorite", false)):
		tags.append("已收藏")
	var ai_enabled := bool(record.get("ai_enabled", false))
	if ai_enabled:
		tags.append("AI")
	return tags

func _format_time(timestamp: int) -> String:
	if timestamp <= 0:
		return "-"
	var dt := Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func _on_import_pressed() -> void:
	_import_dialog.popup_centered_ratio(0.7)

func _setup_filter_options() -> void:
	if _time_range_filter_option != null:
		_time_range_filter_option.clear()
		_time_range_filter_option.add_item("时间：全部")
		_time_range_filter_option.add_item("近 7 天")
		_time_range_filter_option.add_item("近 30 天")
		_time_range_filter_option.add_item("近 90 天")
		_time_range_filter_option.selected = 0
	if _mode_filter_option != null:
		_mode_filter_option.clear()
		_mode_filter_option.add_item("模式：全部")
		_mode_filter_option.add_item("模式：正式对局")
		_mode_filter_option.add_item("模式：联机正式")
		_mode_filter_option.add_item("模式：续战")
		_mode_filter_option.add_item("模式：续战AI")
		_mode_filter_option.add_item("模式：联机续战")
		_mode_filter_option.add_item("模式：网络续战")
		_mode_filter_option.add_item("模式：导入")
		_mode_filter_option.add_item("模式：测试")
		_mode_filter_option.add_item("模式：联机测试")
		_mode_filter_option.selected = 0
	if _status_filter_option != null:
		_status_filter_option.clear()
		_status_filter_option.add_item("状态：全部")
		_status_filter_option.add_item("状态：已结束")
		_status_filter_option.add_item("状态：中断")
		_status_filter_option.add_item("状态：异常")
		_status_filter_option.selected = 0
	if _sort_filter_option != null:
		_sort_filter_option.clear()
		_sort_filter_option.add_item("按开始时间")
		_sort_filter_option.add_item("按结束时间")
		_sort_filter_option.add_item("按回合数")
		_sort_filter_option.add_item("按步骤数")
		_sort_filter_option.add_item("按标题")
		_sort_filter_option.selected = 0

func _build_list_filters() -> Dictionary:
	var time_range_days := _selected_filter_value(_time_range_filter_option, _time_range_filter_values)
	var started_at_min := 0
	if not time_range_days.is_empty():
		started_at_min = int(Time.get_unix_time_from_system()) - int(time_range_days) * 86400
	return {
		"keyword": _search_edit.text.strip_edges() if _search_edit != null else "",
		"started_at_min": started_at_min,
		"mode": _selected_filter_value(_mode_filter_option, _mode_filter_values),
		"status": _selected_filter_value(_status_filter_option, _status_filter_values),
		"favorites_only": bool(_favorites_only_toggle.button_pressed) if _favorites_only_toggle != null else false,
		"resumable_only": bool(_resumable_only_toggle.button_pressed) if _resumable_only_toggle != null else false,
		"imported_only": bool(_imported_only_toggle.button_pressed) if _imported_only_toggle != null else false,
		"sort_by": _selected_filter_value(_sort_filter_option, _sort_filter_values, "started_at"),
		"sort_order": "asc" if _sort_order_toggle != null and _sort_order_toggle.button_pressed else "desc"
	}

func _selected_filter_value(option: OptionButton, values: Array[String], default_value: String = "") -> String:
	if option == null:
		return default_value
	var selected_index := option.selected
	if selected_index >= 0 and selected_index < values.size():
		return values[selected_index]
	return default_value

func _has_active_list_filters() -> bool:
	var filters := _build_list_filters()
	return not str(filters.get("keyword", "")).is_empty() \
		or int(filters.get("started_at_min", 0)) > 0 \
		or not str(filters.get("mode", "")).is_empty() \
		or not str(filters.get("status", "")).is_empty() \
		or bool(filters.get("favorites_only", false)) \
		or bool(filters.get("resumable_only", false)) \
		or bool(filters.get("imported_only", false)) \
		or str(filters.get("sort_by", "started_at")) != "started_at" \
		or str(filters.get("sort_order", "desc")) != "desc"

func _reset_list_filters() -> void:
	if _search_edit != null:
		_search_edit.text = ""
	if _time_range_filter_option != null:
		_time_range_filter_option.selected = 0
	if _mode_filter_option != null:
		_mode_filter_option.selected = 0
	if _status_filter_option != null:
		_status_filter_option.selected = 0
	if _sort_filter_option != null:
		_sort_filter_option.selected = 0
	if _sort_order_toggle != null:
		_sort_order_toggle.button_pressed = false
	if _favorites_only_toggle != null:
		_favorites_only_toggle.button_pressed = false
	if _resumable_only_toggle != null:
		_resumable_only_toggle.button_pressed = false
	if _imported_only_toggle != null:
		_imported_only_toggle.button_pressed = false
	_refresh_list()

func _refresh_storage_health_hint() -> void:
	if _health_hint_label == null:
		return
	var health_result = _store.scan_storage_health()
	if not bool(health_result.get("ok", false)):
		_health_hint_label.text = "历史存储检查失败：%s" % _format_store_result_message(health_result)
		if _repair_index_button != null:
			_repair_index_button.visible = false
		return
	var data: Dictionary = health_result.get("data", {})
	var issues = data.get("issues", [])
	if not (issues is Array) or issues.is_empty():
		_health_hint_label.text = ""
		if _repair_index_button != null:
			_repair_index_button.visible = false
		return
	var counts := {}
	for issue in issues:
		if not (issue is Dictionary):
			continue
		var code := str(issue.get("code", "UNKNOWN"))
		counts[code] = int(counts.get(code, 0)) + 1
	var parts: Array[String] = []
	for code in counts.keys():
		parts.append("%s x%s" % [_format_storage_issue_code(str(code)), int(counts[code])])
	_health_hint_label.text = "检测到历史存储问题：%s" % "，".join(parts)
	if _repair_index_button != null:
		_repair_index_button.visible = true

func _on_repair_index_pressed() -> void:
	var result = _store.repair_storage_index()
	if bool(result.get("ok", false)):
		var data: Dictionary = result.get("data", {})
		var message := "索引修复完成：恢复 %s 条记录，跳过 %s 个无效回放文件" % [
			int(data.get("record_count", 0)),
			int(data.get("skipped_invalid_count", 0))
		]
		_refresh_list(true)
		_refresh_detail_after_storage_change(message)
	else:
		_message_label.text = "索引修复失败：%s" % _format_store_result_message(result)

func _refresh_capacity_hint() -> void:
	if _capacity_hint_label == null:
		return
	var result = _store.get_capacity_status(_record_capacity_limit)
	if not bool(result.get("ok", false)):
		_capacity_hint_label.text = "历史容量检查失败：%s" % _format_store_result_message(result)
		if _cleanup_history_button != null:
			_cleanup_history_button.visible = false
		return
	var data: Dictionary = result.get("data", {})
	var record_count := int(data.get("record_count", 0))
	var record_limit := int(data.get("record_limit", _record_capacity_limit))
	var favorite_count := int(data.get("favorite_count", 0))
	var overflow_count := int(data.get("overflow_count", 0))
	_capacity_hint_label.text = "历史容量：%s / %s，收藏 %s 条" % [record_count, record_limit, favorite_count]
	if overflow_count > 0:
		_capacity_hint_label.text += "，已超出 %s 条" % overflow_count
	if _cleanup_history_button != null:
		_cleanup_history_button.visible = overflow_count > 0

func _on_cleanup_history_pressed() -> void:
	var result = _store.prune_old_records(_record_capacity_limit, true)
	if bool(result.get("ok", false)):
		var data: Dictionary = result.get("data", {})
		var message := "清理完成：删除 %s 条最旧非收藏记录，剩余 %s 条" % [
			int(data.get("removed_count", 0)),
			int(data.get("remaining_count", 0))
		]
		_refresh_list(true)
		_refresh_detail_after_storage_change(message)
	else:
		_message_label.text = "清理失败：%s" % _format_store_result_message(result)

func _on_import_file_selected(path: String) -> void:
	_pending_import_path = path
	var result = _store.import_replay_file(path)
	if bool(result.get("ok", false)):
		_switch_tab("all")
		_message_label.text = "导入成功"
	elif str(result.get("code", "")) == "REPLAY_ALREADY_EXISTS":
		var replay_id := str(result.get("data", {}).get("replay_id", ""))
		_import_conflict_dialog.dialog_text = "检测到 replay_id 为 %s 的历史记录已存在，是否覆盖旧记录并重新导入？" % replay_id
		_import_conflict_dialog.popup_centered()
	else:
		_message_label.text = "导入失败：%s" % _format_store_result_message(result)

func _on_import_conflict_confirmed() -> void:
	if _pending_import_path.is_empty():
		return
	var result = _store.import_replay_file(_pending_import_path, {"replace_existing": true})
	if bool(result.get("ok", false)):
		_switch_tab("all")
		_message_label.text = "已覆盖旧记录并重新导入"
	else:
		_message_label.text = "覆盖导入失败：%s" % _format_store_result_message(result)
	_pending_import_path = ""

func _open_detail(record_id: String) -> void:
	_selected_record_id = record_id
	_selected_record = {}
	_timeline_selected_command_index = -1
	var record_result = _store.get_record(record_id)
	if not bool(record_result.get("ok", false)):
		_message_label.text = "打开失败：%s" % _format_store_result_message(record_result)
		_update_detail_action_state()
		return
	var record: Dictionary = record_result.get("data", {})
	_selected_record = record.duplicate(true)
	_detail_title.text = str(record.get("title", ""))
	var replay_result = _store.get_replay_data(record_id)
	if not bool(replay_result.get("ok", false)):
		_current_replay_data = {}
		_detail_body.text = "读取回放失败：%s" % _format_store_result_message(replay_result)
		_detail_panel.visible = true
		_update_detail_action_state()
		return
	var replay_data: Dictionary = replay_result.get("data", {})
	_current_replay_data = replay_data
	_detail_body.text = _build_detail_text(record, replay_data)
	_panel.visible = false
	_detail_panel.visible = true
	_update_detail_action_state()

func _open_ai_log(record_id: String) -> void:
	if _ai_log_dialog == null or _ai_log_text == null:
		return
	var result = _store.read_ai_log(record_id)
	var record_result = _store.get_record(record_id)
	var record: Dictionary = record_result.get("data", {}) if bool(record_result.get("ok", false)) else {}
	var title := str(record.get("title", "AI日志"))
	if bool(result.get("ok", false)):
		var data: Dictionary = result.get("data", {})
		_ai_log_dialog.title = "AI日志 - %s" % title
		_ai_log_text.text = "路径：%s\n\n%s" % [
			str(data.get("path", "")),
			str(data.get("content", ""))
		]
	else:
		_ai_log_dialog.title = "AI日志 - %s" % title
		_ai_log_text.text = "未找到 AI 日志。\n\n原因：%s" % _format_store_result_message(result)
	_ai_log_text.set_caret_line(0)
	_ai_log_text.set_caret_column(0)
	_ai_log_dialog.popup_centered_ratio(0.86)

func _open_duel_log(record_id: String) -> void:
	if _duel_log_dialog == null or _duel_log_text == null:
		return
	var record_result = _store.get_record(record_id)
	var record: Dictionary = record_result.get("data", {}) if bool(record_result.get("ok", false)) else {}
	var replay_result = _store.get_replay_data(record_id)
	var replay_data: Dictionary = replay_result.get("data", {}) if bool(replay_result.get("ok", false)) else {}
	var title := str(record.get("title", "对局日志"))
	var log_path := _resolve_duel_log_path(record, replay_data)
	var content := _read_history_text(log_path)
	_duel_log_dialog.title = "对局日志 - %s" % title
	if log_path.is_empty():
		_duel_log_text.text = "未找到对局日志。"
	elif content.is_empty():
		_duel_log_text.text = "路径：%s\n\n日志文件为空或不可读取。" % log_path
	else:
		_duel_log_text.text = "路径：%s\n\n%s" % [log_path, content]
	_duel_log_text.set_caret_line(0)
	_duel_log_text.set_caret_column(0)
	_duel_log_dialog.popup_centered_ratio(0.86)

func _build_detail_text(record: Dictionary, replay_data: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % str(record.get("title", "")))
	lines.append("模式：%s" % _format_mode(str(record.get("mode", ""))))
	lines.append("状态：%s" % _format_status(str(record.get("status", ""))))
	lines.append("胜者：%s" % _format_winner(record))
	lines.append("开始时间：%s" % _format_time(int(record.get("started_at", 0))))
	lines.append("结束时间：%s" % _format_time(int(record.get("finished_at", 0))))
	lines.append("回合：%s" % str(record.get("turn_count", 0)))
	lines.append("步骤：%s" % str(record.get("command_count", 0)))
	if bool(record.get("is_imported", false)):
		lines.append("来源：导入对局")
	var source_record_id := str(record.get("source_record_id", ""))
	var source_command_index := int(record.get("source_command_index", -1))
	if source_record_id.is_empty():
		lines.append("对局来源：原始对局")
	else:
		var source_title := source_record_id
		var source_lookup = _store.find_record_by_replay_id(source_record_id)
		if bool(source_lookup.get("ok", false)):
			source_title = str(source_lookup.get("data", {}).get("title", source_title))
		lines.append("对局来源：从《%s》的第 %s 步继续" % [source_title, source_command_index])
	var setup: Dictionary = replay_data.get("setup", {})
	var players = setup.get("players", [])
	if players is Array and players.size() >= 2:
		for i in range(2):
			var player: Dictionary = players[i]
			lines.append("")
			lines.append("[b]玩家%s[/b]" % str(i + 1))
			lines.append("主宰：%s" % _format_master_name(player))
			var deck_name := str(player.get("deck_name", ""))
			if not deck_name.is_empty():
				lines.append("卡组名：%s" % deck_name)
			var deck_cards = player.get("deck_cards", [])
			lines.append("卡组张数：%s" % str(deck_cards.size() if deck_cards is Array else 0))
			if deck_cards is Array:
				lines.append("卡组列表：")
				for deck_line in _format_deck_lines(deck_cards):
					lines.append(deck_line)
	return "\n".join(lines)

func _resolve_history_path(path: String) -> String:
	var normalized := str(path).strip_edges()
	if normalized.is_empty():
		return ""
	if FileAccess.file_exists(normalized):
		return normalized
	if normalized.begins_with("user://") or normalized.begins_with("res://"):
		var absolute := ProjectSettings.globalize_path(normalized)
		if FileAccess.file_exists(absolute):
			return absolute
	return ""

func _read_history_text(path: String) -> String:
	var resolved := _resolve_history_path(path)
	if resolved.is_empty():
		return ""
	return FileAccess.get_file_as_string(resolved)

func _resolve_duel_log_path(record: Dictionary, replay_data: Dictionary = {}) -> String:
	var history_info: Dictionary = replay_data.get("history_info", {})
	var candidates: Array[String] = [
		str(record.get("duel_log_path", "")),
		str(history_info.get("duel_log_path", ""))
	]
	for candidate in candidates:
		var resolved := _resolve_history_path(candidate)
		if not resolved.is_empty():
			return resolved
	return ""

func _has_llm_ai_log(replay_data: Dictionary) -> bool:
	var game_options: Dictionary = replay_data.get("setup", {}).get("game_options", {})
	return bool(game_options.get("ai_use_llm", false))

func _render_timeline(replay_data: Dictionary) -> void:
	if _timeline_box == null:
		return
	_reset_resume_recommendation()
	var previous_selected := _timeline_selected_command_index
	_timeline_focus_buttons.clear()
	_timeline_step_to_turn.clear()
	_timeline_turn_rows_boxes.clear()
	_timeline_turn_toggle_buttons.clear()
	_timeline_key_indices = _rebuild_timeline_key_indices(replay_data)
	for child in _timeline_box.get_children():
		_timeline_box.remove_child(child)
		child.queue_free()
	if _timeline_hint != null:
		_timeline_hint.text = "时间轴已按回合分组。点击某一步后，可在下方使用查看回放、继续对局、查看日志等操作。"
	var commands = replay_data.get("commands", [])
	if not (commands is Array) or commands.is_empty():
		_timeline_selected_command_index = -1
		var empty_label := Label.new()
		empty_label.text = "暂无对局记录"
		_timeline_box.add_child(empty_label)
		_update_detail_action_state()
		_update_timeline_key_jump_buttons()
		return
	var grouped := {}
	var ordered_turns: Array[int] = []
	for row in commands:
		if not (row is Dictionary):
			continue
		if _timeline_key_only_enabled and _timeline_key_tags(row, replay_data).is_empty():
			continue
		var turn_key := _timeline_turn_key(row)
		if not grouped.has(turn_key):
			grouped[turn_key] = []
			ordered_turns.append(turn_key)
		var rows: Array = grouped[turn_key]
		rows.append(row)
		grouped[turn_key] = rows
	for turn_key in ordered_turns:
		var turn_rows: Array = grouped.get(turn_key, [])
		if turn_rows.is_empty():
			continue
		_timeline_box.add_child(_build_timeline_turn_group(turn_key, turn_rows, replay_data))
	var desired_focus := _pending_focus_command_index if _pending_focus_command_index >= 0 else previous_selected
	var focus_index := _pick_visible_timeline_index(desired_focus)
	if focus_index >= 0:
		call_deferred("_focus_timeline_step", focus_index)
	else:
		_timeline_selected_command_index = -1
		_pending_focus_command_index = -1
	if _timeline_hint != null and _timeline_key_only_enabled:
		_timeline_hint.text = "当前只显示关键步骤（带★）。取消勾选可查看完整时间轴。"
	_update_detail_action_state()
	_update_timeline_key_jump_buttons()

func _pick_visible_timeline_index(preferred: int) -> int:
	if _timeline_focus_buttons.is_empty():
		return -1
	if preferred >= 0 and _timeline_focus_buttons.has(preferred):
		return preferred
	var indices: Array[int] = []
	for raw_index in _timeline_focus_buttons.keys():
		indices.append(int(raw_index))
	indices.sort()
	if indices.is_empty():
		return -1
	if preferred < 0:
		return int(indices[0])
	var best: int = int(indices[0])
	var best_delta: int = abs(best - preferred)
	for idx in indices:
		var delta: int = abs(int(idx) - preferred)
		if delta < best_delta:
			best = int(idx)
			best_delta = delta
	return best

func _timeline_turn_key(row: Dictionary) -> int:
	var turn_after := int(row.get("turn_after", 0))
	var turn_before := int(row.get("turn_before", 0))
	return max(turn_after, turn_before, 0)

func _build_timeline_turn_group(turn_key: int, rows: Array, replay_data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_history_card_style(false))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var header_row := _make_flow_row(8)
	content.add_child(header_row)
	var toggle_button := Button.new()
	toggle_button.toggle_mode = true
	toggle_button.custom_minimum_size = Vector2(78, 34)
	toggle_button.pressed.connect(func(): _toggle_timeline_turn(turn_key))
	_style_history_button(toggle_button, false)
	header_row.add_child(toggle_button)
	var header := Label.new()
	header.text = _format_timeline_turn_title(turn_key, rows)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_history_label(header, true)
	header_row.add_child(header)
	var divider := HSeparator.new()
	content.add_child(divider)
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 6)
	content.add_child(rows_box)
	for row in rows:
		if row is Dictionary:
			rows_box.add_child(_build_timeline_row(row, replay_data, turn_key))
	var collapsed := bool(_timeline_collapsed_turns.get(turn_key, false))
	rows_box.visible = not collapsed
	toggle_button.button_pressed = collapsed
	toggle_button.text = "展开" if collapsed else "收起"
	_timeline_turn_rows_boxes[turn_key] = rows_box
	_timeline_turn_toggle_buttons[turn_key] = toggle_button
	return panel

func _format_timeline_turn_title(turn_key: int, rows: Array) -> String:
	var step_count := rows.size()
	if turn_key <= 0:
		return "开局阶段 | %s 步" % step_count
	return "第 %s 回合 | %s 步" % [turn_key, step_count]

func _build_timeline_row(row: Dictionary, replay_data: Dictionary, turn_key: int) -> Control:
	var container := _make_flow_row(8)
	var command_index := int(row.get("index", 0))
	_timeline_step_to_turn[command_index] = turn_key
	var summary_button := Button.new()
	summary_button.text = _format_command_line(row, replay_data)
	summary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_button.pressed.connect(func(): _show_timeline_step_detail(row, replay_data))
	_timeline_focus_buttons[command_index] = summary_button
	_style_history_button(summary_button, false)
	container.add_child(summary_button)
	return container

func _focus_timeline_step(command_index: int) -> void:
	var turn_key = _timeline_step_to_turn.get(command_index, null)
	if turn_key != null:
		_set_timeline_turn_collapsed(int(turn_key), false)
	_timeline_selected_command_index = command_index
	var target_button: Button = _timeline_focus_buttons.get(command_index, null)
	for raw_index in _timeline_focus_buttons.keys():
		var button: Button = _timeline_focus_buttons.get(raw_index, null)
		if button == null:
			continue
		_set_timeline_button_focused(button, int(raw_index) == command_index)
	if target_button != null and _timeline_scroll != null:
		_timeline_scroll.ensure_control_visible(target_button)
		var row := _find_timeline_row_by_index(command_index, _current_replay_data)
		if not row.is_empty():
			_show_timeline_step_detail(row, _current_replay_data)
	_pending_focus_command_index = -1
	_update_detail_action_state()
	_update_timeline_key_jump_buttons()

func _toggle_timeline_turn(turn_key: int) -> void:
	var current := bool(_timeline_collapsed_turns.get(turn_key, false))
	_set_timeline_turn_collapsed(turn_key, not current)

func _set_timeline_turn_collapsed(turn_key: int, collapsed: bool) -> void:
	_timeline_collapsed_turns[turn_key] = collapsed
	var rows_box: VBoxContainer = _timeline_turn_rows_boxes.get(turn_key, null)
	if rows_box != null:
		rows_box.visible = not collapsed
	var toggle_button: Button = _timeline_turn_toggle_buttons.get(turn_key, null)
	if toggle_button != null:
		toggle_button.button_pressed = collapsed
		toggle_button.text = "展开" if collapsed else "收起"

func _set_timeline_button_focused(button: Button, focused: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.11, 0.13, 0.95)
	normal.border_color = Color(0.35, 0.35, 0.4, 1.0)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	if focused:
		normal.bg_color = Color(0.16, 0.28, 0.40, 0.98)
		normal.border_color = Color(0.70, 0.90, 1.0, 1.0)
	var hover := normal.duplicate()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal.duplicate())

func _find_timeline_row_by_index(command_index: int, replay_data: Dictionary) -> Dictionary:
	var commands = replay_data.get("commands", [])
	if not (commands is Array):
		return {}
	for row in commands:
		if row is Dictionary and int(row.get("index", -1)) == command_index:
			return row
	return {}

func _show_timeline_step_detail(row: Dictionary, replay_data: Dictionary) -> void:
	if _timeline_hint == null:
		return
	var index := int(row.get("index", 0))
	var should_highlight := _timeline_focus_buttons.has(index)
	_timeline_selected_command_index = index
	if should_highlight:
		for raw_index in _timeline_focus_buttons.keys():
			var button: Button = _timeline_focus_buttons.get(raw_index, null)
			if button == null:
				continue
			_set_timeline_button_focused(button, int(raw_index) == index)
		var target_button: Button = _timeline_focus_buttons.get(index, null)
		if target_button != null and _timeline_scroll != null:
			_timeline_scroll.ensure_control_visible(target_button)
	var command_type := str(row.get("type", ""))
	var player_id := int(row.get("player_id", -1))
	var payload: Dictionary = row.get("payload", {})
	var detail_lines: Array[String] = []
	detail_lines.append("[b]第 %s 步[/b]" % index)
	var key_tags := _timeline_key_tags(row, replay_data)
	if not key_tags.is_empty():
		detail_lines.append("关键：%s" % "、".join(key_tags))
	detail_lines.append("玩家：%s" % _format_command_player(player_id, replay_data))
	detail_lines.append("命令：%s" % command_type)
	detail_lines.append("摘要：%s" % _format_command_summary(command_type, payload, replay_data))
	detail_lines.append("阶段：%s -> %s" % [_format_phase_name(str(row.get("phase_before", ""))), _format_phase_name(str(row.get("phase_after", "")))])
	if not payload.is_empty():
		detail_lines.append("参数：%s" % JSON.stringify(payload))
	detail_lines.append("")
	detail_lines.append("可在下方点击“查看回放”或“继续对局”。")
	_timeline_hint.text = "\n".join(detail_lines)
	_update_detail_action_state()
	_update_timeline_key_jump_buttons()

func _update_detail_action_state() -> void:
	var has_record := not _selected_record_id.is_empty()
	var has_replay := has_record and not _current_replay_data.is_empty()
	var can_continue := has_replay and bool(_selected_record.get("can_continue", false))
	var has_duel_log := has_replay and not _resolve_duel_log_path(_selected_record, _current_replay_data).is_empty()
	var has_llm_ai_log := has_replay and _has_llm_ai_log(_current_replay_data)
	if _timeline_view_replay_button != null:
		_timeline_view_replay_button.disabled = not has_replay
	if _timeline_resume_button != null:
		_timeline_resume_button.disabled = not can_continue
	if _timeline_view_log_button != null:
		_timeline_view_log_button.disabled = not has_duel_log
	if _detail_ai_log_button != null:
		_detail_ai_log_button.disabled = not has_llm_ai_log
	if _export_button != null:
		_export_button.disabled = not has_record
	if _delete_button != null:
		_delete_button.disabled = not has_record

func _on_timeline_view_replay_pressed() -> void:
	if _selected_record_id.is_empty():
		return
	table_replay_requested.emit(_selected_record_id, 0)

func _on_timeline_resume_pressed() -> void:
	if _current_replay_data.is_empty() or not bool(_selected_record.get("can_continue", false)):
		return
	_request_resume_from_step(_current_replay_data.get("commands", []).size())

func _on_timeline_view_log_pressed() -> void:
	if _selected_record_id.is_empty():
		return
	_open_duel_log(_selected_record_id)

func _open_replay_at_step(command_index: int) -> void:
	if _current_replay_data.is_empty():
		return
	_focus_timeline_step(command_index)
	_stop_replay_auto_play()
	var load_result = _replay_session.load_replay_data(_current_replay_data)
	if not bool(load_result.get("ok", false)):
		_timeline_hint.text = "回放初始化失败：%s" % str(load_result.get("message", ""))
		return
	var jump_result = _replay_session.jump_to_command(command_index)
	if not bool(jump_result.get("ok", false)):
		_timeline_hint.text = "回放跳转失败：%s" % str(jump_result.get("message", ""))
		return
	_render_replay_state(jump_result.get("data", {}))
	_replay_panel.visible = true
	_replay_panel.move_to_front()

func _request_resume_from_step(command_index: int) -> void:
	if _current_replay_data.is_empty():
		return
	_stop_replay_auto_play()
	_reset_resume_recommendation()
	var load_result = _replay_session.load_replay_data(_current_replay_data)
	if not bool(load_result.get("ok", false)):
		_message_label.text = "继续对局失败：回放初始化失败"
		return
	var jump_result = _replay_session.jump_to_command(command_index)
	if not bool(jump_result.get("ok", false)):
		_message_label.text = "继续对局失败：无法跳转到该步"
		return
	var state = _replay_session.get_current_state()
	if not _can_resume_from_state(state):
		_show_resume_unavailable_hint(command_index, state)
		return
	_pending_resume_replay_data = _current_replay_data.duplicate(true)
	_pending_resume_command_index = command_index
	_resume_kind_option.disabled = true
	_resume_kind_option.selected = 0
	_resume_network_host_side_option.selected = 0
	_resume_network_host_side_option.disabled = true
	if _resume_ai_mode_option != null:
		_resume_ai_mode_option.clear()
		_resume_ai_mode_option.add_item("无人机", 0)
		_resume_ai_mode_option.add_item("对战人机", 1)
	_resume_ai_mode_option.selected = 0
	_resume_ai_side_option.selected = 1
	_resume_llm_toggle.button_pressed = false
	_resume_llm_toggle.disabled = true
	var is_full_resume := command_index == int(_current_replay_data.get("commands", []).size())
	_resume_dialog.dialog_text = "将从当前对局结尾继续对局。请选择对手模式后开始。" if is_full_resume else "从第 %s 步重新开始一局。请选择对手模式后开始。" % command_index
	_resume_dialog.popup_centered()

func _show_resume_unavailable_hint(command_index: int, state) -> void:
	var reason_lines := _describe_resume_blockers(state)
	var lines: Array[String] = []
	lines.append("[b]第 %s 步暂不可继续[/b]" % command_index)
	if reason_lines.is_empty():
		lines.append("原因：该节点不是稳定节点。")
	else:
		lines.append("原因：%s" % "；".join(reason_lines))
	var recommended_index := _find_nearest_resumable_command_index(command_index)
	if recommended_index >= 0:
		_recommended_resume_command_index = recommended_index
		lines.append("建议：可改从最近稳定节点第 %s 步继续。" % recommended_index)
		if _timeline_resume_recommend_button != null:
			_timeline_resume_recommend_button.text = "改从第 %s 步继续对局" % recommended_index
			_timeline_resume_recommend_button.visible = true
	else:
		lines.append("建议：当前之前没有找到可继续的稳定节点。")
	_message_label.text = "\n".join(lines)

func _describe_resume_blockers(state) -> Array[String]:
	var lines: Array[String] = []
	if state == null:
		lines.append("状态为空")
		return lines
	if int(state.winner) != -1:
		lines.append("对局已结束")
	if not state.stack.is_empty():
		lines.append("仍有 %s 个结算未处理" % state.stack.size())
	if not state.pending_choices.is_empty():
		lines.append("仍有 %s 个选择未完成" % state.pending_choices.size())
	if not state.pending_attack.is_empty():
		lines.append("仍有攻击/防御流程未结束")
	return lines

func _find_nearest_resumable_command_index(command_index: int) -> int:
	for index in range(command_index - 1, -1, -1):
		var jump_result = _replay_session.jump_to_command(index)
		if not bool(jump_result.get("ok", false)):
			continue
		if _can_resume_from_state(_replay_session.get_current_state()):
			return index
	return -1

func _on_timeline_resume_recommend_pressed() -> void:
	if _recommended_resume_command_index < 0:
		return
	_request_resume_from_step(_recommended_resume_command_index)

func _reset_resume_recommendation() -> void:
	_recommended_resume_command_index = -1
	if _timeline_resume_recommend_button != null:
		_timeline_resume_recommend_button.visible = false
		_timeline_resume_recommend_button.text = ""

func _render_replay_state(data: Dictionary) -> void:
	if _replay_state_label == null:
		return
	var public_view: Dictionary = data.get("public_view", {})
	var command_index := int(data.get("command_index", 0))
	if _detail_panel != null and _detail_panel.visible and command_index != _timeline_selected_command_index:
		if _timeline_focus_buttons.has(command_index):
			_focus_timeline_step(command_index)
	var total_steps := _replay_session.get_total_command_count()
	_replay_step_label.text = "回放步骤 %s / %s" % [command_index, total_steps]
	_update_replay_seek_controls(command_index, total_steps)
	var lines: Array[String] = []
	lines.append("[b]当前步骤[/b] %s / %s" % [command_index, total_steps])
	var last_row: Dictionary = data.get("last_command_row", {})
	if not last_row.is_empty():
		lines.append("最近操作：%s" % _format_command_line(last_row, _current_replay_data))
	lines.append("回合：%s" % str(public_view.get("turn_number", 0)))
	lines.append("当前阶段：%s" % _format_phase_name(str(public_view.get("phase", ""))))
	lines.append("当前行动方：玩家%s" % str(int(public_view.get("active_player", 0)) + 1))
	lines.append("灾厄值：%s" % str(public_view.get("calamity_value", 0)))
	lines.append("胜者：%s" % _format_public_view_winner(public_view))
	lines.append("")
	lines.append("[b]当前场面[/b]")
	var players = public_view.get("players", [])
	_render_replay_board(public_view)
	if players is Array:
		for player in players:
			if not (player is Dictionary):
				continue
			var pid := int(player.get("player_id", -1))
			lines.append("")
			lines.append("[b]%s[/b]" % _format_command_player(pid, _current_replay_data))
			lines.append("主宰生命：%s/%s" % [str(player.get("master_hp", 0)), str(player.get("master_max_hp", 0))])
			lines.append("手牌：%s | 牌库：%s | 墓地：%s | 士气：%s" % [
				str(player.get("hand_count", 0)),
				str(player.get("deck_count", 0)),
				str(player.get("grave_count", 0)),
				str(player.get("cost_count", 0))
			])
			lines.append("前排：%s" % _format_zone_cards(player.get("front", [])))
			lines.append("后排：%s" % _format_zone_cards(player.get("back", [])))
	_replay_state_label.text = "\n".join(lines)
	_replay_first_button.disabled = command_index <= 0
	_replay_prev_button.disabled = command_index <= 0
	_replay_next_button.disabled = command_index >= total_steps
	_replay_last_button.disabled = command_index >= total_steps
	_replay_play_button.disabled = total_steps <= 0
	_replay_play_button.text = "暂停" if _replay_auto_playing else "播放"

func _update_replay_seek_controls(command_index: int, total_steps: int) -> void:
	if _replay_seek_label != null:
		_replay_seek_label.text = "进度 %s/%s" % [command_index, total_steps]
	if _replay_seek_slider != null:
		_replay_seek_internal_update = true
		_replay_seek_slider.min_value = 0
		_replay_seek_slider.max_value = total_steps
		_replay_seek_slider.step = 1
		_replay_seek_slider.value = command_index
		_replay_seek_slider.editable = total_steps > 0
		_replay_seek_internal_update = false

func _render_replay_board(public_view: Dictionary) -> void:
	var players = public_view.get("players", [])
	if not (players is Array):
		return
	var top_player: Dictionary = players[1] if players.size() > 1 and players[1] is Dictionary else {}
	var bottom_player: Dictionary = players[0] if players.size() > 0 and players[0] is Dictionary else {}
	_replay_board_title.text = "只读战场 | 回合 %s | %s" % [
		str(public_view.get("turn_number", 0)),
		_format_phase_name(str(public_view.get("phase", "")))
	]
	_replay_top_summary.text = _format_replay_player_summary(top_player)
	_replay_bottom_summary.text = _format_replay_player_summary(bottom_player)
	_render_zone_container(_replay_top_front, top_player.get("front", []))
	_render_zone_container(_replay_top_back, top_player.get("back", []))
	_render_zone_container(_replay_bottom_front, bottom_player.get("front", []))
	_render_zone_container(_replay_bottom_back, bottom_player.get("back", []))

func _format_replay_player_summary(player: Dictionary) -> String:
	if player.is_empty():
		return "-"
	var player_name := _format_command_player(int(player.get("player_id", -1)), _current_replay_data)
	return "%s | 主宰生命 %s/%s | 手牌 %s | 牌库 %s | 墓地 %s | 士气 %s" % [
		player_name,
		str(player.get("master_hp", 0)),
		str(player.get("master_max_hp", 0)),
		str(player.get("hand_count", 0)),
		str(player.get("deck_count", 0)),
		str(player.get("grave_count", 0)),
		str(player.get("cost_count", 0))
	]

func _render_zone_container(container: HBoxContainer, zone_cards) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	if not (zone_cards is Array) or zone_cards.is_empty():
		container.add_child(_make_zone_slot("空位", true))
		return
	for card_id in zone_cards:
		container.add_child(_make_zone_slot(_resolve_instance_or_card_name(str(card_id)), false))

func _make_zone_slot(text: String, is_empty: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120.0, 52.0)
	panel.add_theme_stylebox_override("panel", _make_history_card_style(not is_empty))
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_empty:
		label.modulate = Color(0.7, 0.7, 0.75, 0.9)
	panel.add_child(label)
	return panel

func _format_public_view_winner(public_view: Dictionary) -> String:
	var winner := int(public_view.get("winner", -1))
	if winner < 0:
		return "未分胜负"
	return _format_command_player(winner, _current_replay_data)

func _format_zone_cards(zone_cards) -> String:
	if not (zone_cards is Array) or zone_cards.is_empty():
		return "空"
	var names: Array[String] = []
	for card_id in zone_cards:
		var card_name := _resolve_instance_or_card_name(str(card_id))
		names.append(card_name)
	return " | ".join(names)

func _resolve_instance_or_card_name(card_id: String) -> String:
	if card_id.begins_with("c_"):
		var state = _replay_session.get_current_state()
		if state != null:
			var instance = state.card_instances.get(card_id, null)
			if instance != null:
				var definition_id := str(instance.definition_id)
				if not definition_id.is_empty():
					return _resolve_card_name(definition_id)
		return card_id
	return _resolve_card_name(card_id)

func _on_replay_prev_pressed() -> void:
	_stop_replay_auto_play()
	var result = _replay_session.step_backward()
	if bool(result.get("ok", false)):
		_render_replay_state(result.get("data", {}))

func _on_replay_next_pressed() -> void:
	_stop_replay_auto_play()
	var result = _replay_session.step_forward()
	if bool(result.get("ok", false)):
		_render_replay_state(result.get("data", {}))

func _on_replay_first_pressed() -> void:
	_stop_replay_auto_play()
	var result = _replay_session.jump_to_start()
	if bool(result.get("ok", false)):
		_render_replay_state(result.get("data", {}))

func _on_replay_last_pressed() -> void:
	_stop_replay_auto_play()
	var result = _replay_session.jump_to_end()
	if bool(result.get("ok", false)):
		_render_replay_state(result.get("data", {}))

func _on_replay_play_pressed() -> void:
	if _replay_auto_playing:
		_stop_replay_auto_play()
		_render_replay_state({
			"command_index": _replay_session.get_current_command_index(),
			"state": _replay_session.get_current_state(),
			"last_command_row": _replay_session.get_current_command_row(),
			"public_view": _replay_session.get_current_public_view()
		})
		return
	if _replay_session.get_current_command_index() >= _replay_session.get_total_command_count():
		return
	_replay_auto_playing = true
	if _replay_timer != null:
		_replay_timer.start()
	_replay_play_button.text = "暂停"

func _on_replay_timer_timeout() -> void:
	if not _replay_auto_playing:
		return
	var result = _replay_session.step_forward()
	if not bool(result.get("ok", false)):
		_stop_replay_auto_play()
		return
	_render_replay_state(result.get("data", {}))
	if _replay_session.get_current_command_index() >= _replay_session.get_total_command_count():
		_stop_replay_auto_play()
		_render_replay_state({
			"command_index": _replay_session.get_current_command_index(),
			"state": _replay_session.get_current_state(),
			"last_command_row": _replay_session.get_current_command_row(),
			"public_view": _replay_session.get_current_public_view()
		})

func _stop_replay_auto_play() -> void:
	_replay_auto_playing = false
	if _replay_timer != null:
		_replay_timer.stop()
	if _replay_play_button != null:
		_replay_play_button.text = "播放"

func _close_replay_view() -> void:
	_stop_replay_auto_play()
	_replay_seek_dragging = false
	if _replay_panel != null:
		_replay_panel.visible = false

func _on_replay_seek_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			_replay_seek_dragging = true
			_stop_replay_auto_play()
		else:
			_replay_seek_dragging = false

func _on_replay_seek_value_changed(value: float) -> void:
	if _replay_seek_internal_update:
		return
	if _replay_seek_label != null:
		_replay_seek_label.text = "进度 %s/%s" % [int(value), _replay_session.get_total_command_count()]

func _on_replay_seek_drag_ended(value_changed: bool) -> void:
	if _replay_seek_internal_update:
		return
	if not value_changed:
		return
	_stop_replay_auto_play()
	if _replay_seek_slider == null:
		return
	_seek_replay_to_step(int(_replay_seek_slider.value))

func _seek_replay_to_step(command_index: int) -> void:
	if _current_replay_data.is_empty():
		return
	var jump_result = _replay_session.jump_to_command(command_index)
	if not bool(jump_result.get("ok", false)):
		var load_result = _replay_session.load_replay_data(_current_replay_data)
		if not bool(load_result.get("ok", false)):
			if _replay_state_label != null:
				_replay_state_label.text = "回放跳转失败：%s" % _format_store_result_message(load_result)
			return
		jump_result = _replay_session.jump_to_command(command_index)
	if not bool(jump_result.get("ok", false)):
		if _replay_state_label != null:
			_replay_state_label.text = "回放跳转失败：%s" % _format_store_result_message(jump_result)
		return
	_render_replay_state(jump_result.get("data", {}))

func _can_resume_from_state(state) -> bool:
	if state == null:
		return false
	if int(state.winner) != -1:
		return false
	if not state.stack.is_empty():
		return false
	if not state.pending_choices.is_empty():
		return false
	if not state.pending_attack.is_empty():
		return false
	return true

func _on_resume_ai_mode_selected(_index: int) -> void:
	var ai_mode := int(_resume_ai_mode_option.get_selected_id())
	_resume_llm_toggle.button_pressed = false
	_resume_llm_toggle.disabled = true
	_resume_ai_side_option.selected = 1
	_resume_ai_side_option.disabled = true

func _on_resume_confirmed() -> void:
	if _pending_resume_replay_data.is_empty():
		return
	var ai_mode := int(_resume_ai_mode_option.get_selected_id())
	var ai_use_llm := bool(_resume_llm_toggle.button_pressed)
	var ai_players: Array[int] = []
	if ai_mode == 1:
		ai_players = [int(_resume_ai_side_option.get_selected_id())]
	if ai_mode == 2:
		ai_players = [0, 1]
	var resume_kind_id := int(_resume_kind_option.get_selected_id())
	if resume_kind_id == 1:
		ai_mode = 0
		ai_use_llm = false
		ai_players = []
	var options := {
		"resume_kind": "network" if resume_kind_id == 1 else "local",
		"network_host_player_id": int(_resume_network_host_side_option.get_selected_id()),
		"ai_mode": ai_mode,
		"ai_use_llm": ai_use_llm,
		"ai_players": ai_players,
		"history_record_id": _selected_record_id,
		"history_replay_id": str(_current_replay_data.get("metadata", {}).get("replay_id", ""))
	}
	resume_requested.emit(_pending_resume_replay_data.duplicate(true), _pending_resume_command_index, options)
	_pending_resume_replay_data = {}

func configure_network_resume_available(value: bool) -> void:
	_network_resume_available = value
	if _resume_kind_option != null:
		_resume_kind_option.disabled = not value

func _on_resume_kind_selected(_index: int) -> void:
	var network_selected := int(_resume_kind_option.get_selected_id()) == 1
	_resume_network_host_side_option.disabled = not network_selected
	if network_selected:
		_resume_ai_mode_option.selected = 0
		_resume_ai_side_option.selected = 0
		_resume_ai_side_option.disabled = true
		_resume_llm_toggle.button_pressed = false
		_resume_llm_toggle.disabled = true
		return
	_on_resume_ai_mode_selected(_resume_ai_mode_option.selected)

func _load_card_definitions() -> void:
	_card_definitions.clear()
	for row in CardDatabase.load_definitions():
		if row is Dictionary:
			var card_id := str(row.get("id", ""))
			if not card_id.is_empty():
				_card_definitions[card_id] = row

func _format_mode(mode: String) -> String:
	match mode:
		"formal":
			return "正式对局"
		"network_formal":
			return "联机正式对局"
		"resume_local":
			return "续战对局"
		"resume_ai":
			return "续战对局（AI）"
		"resume_network", "network_resume":
			return "联机续战"
		"imported":
			return "导入对局"
		"test":
			return "测试对局"
		"network_test":
			return "联机测试对局"
	return mode if not mode.is_empty() else "未知"

func _format_status(status: String) -> String:
	match status:
		"finished":
			return "已结束"
		"interrupted":
			return "中断"
		"invalid":
			return "异常"
	return status if not status.is_empty() else "未知"

func _format_winner(record: Dictionary) -> String:
	var winner := str(record.get("winner_master_name", ""))
	if winner.is_empty():
		return "未分胜负"
	return winner

func _format_master_name(player: Dictionary) -> String:
	var master_name := str(player.get("master_name", ""))
	if not master_name.is_empty():
		return master_name
	var master_id := str(player.get("master_id", ""))
	if _card_definitions.has(master_id):
		return str(_card_definitions[master_id].get("name", master_id))
	return str(player.get("name", master_id if not master_id.is_empty() else "未知主宰"))

func _format_deck_lines(deck_cards: Array) -> Array[String]:
	var counts := {}
	var order: Array[String] = []
	for raw_card_id in deck_cards:
		var card_id := str(raw_card_id)
		if not counts.has(card_id):
			counts[card_id] = 0
			order.append(card_id)
		counts[card_id] = int(counts[card_id]) + 1
	var lines: Array[String] = []
	for card_id in order:
		var card_name := _resolve_card_name(card_id)
		lines.append("- x%s %s" % [int(counts[card_id]), card_name])
	return lines

func _resolve_card_name(card_id: String) -> String:
	if _card_definitions.has(card_id):
		var row: Dictionary = _card_definitions[card_id]
		var name := str(row.get("name", ""))
		if not name.is_empty():
			return name
	return card_id

func _format_command_line(row: Dictionary, replay_data: Dictionary) -> String:
	var index := int(row.get("index", 0))
	var player_id := int(row.get("player_id", -1))
	var command_type := str(row.get("type", ""))
	var phase_before := str(row.get("phase_before", ""))
	var phase_after := str(row.get("phase_after", ""))
	var payload: Dictionary = row.get("payload", {})
	var player_name := _format_command_player(player_id, replay_data)
	var summary := _format_command_summary(command_type, payload, replay_data)
	var star := "" if _timeline_key_tags(row, replay_data).is_empty() else "★"
	var phase_text := ""
	if not phase_before.is_empty() or not phase_after.is_empty():
		var before_label := _format_phase_name(phase_before)
		var after_label := _format_phase_name(phase_after)
		if before_label == after_label:
			phase_text = " [%s]" % before_label
		else:
			phase_text = " [%s -> %s]" % [before_label, after_label]
	return "%02d%s. %s：%s%s" % [index, star, player_name, summary, phase_text]

func _format_command_player(player_id: int, replay_data: Dictionary) -> String:
	var players = replay_data.get("setup", {}).get("players", [])
	if players is Array and player_id >= 0 and player_id < players.size():
		var player: Dictionary = players[player_id]
		var master_name := _format_master_name(player)
		return "玩家%s（%s）" % [player_id + 1, master_name]
	return "玩家%s" % (player_id + 1)

func _format_command_summary(command_type: String, payload: Dictionary, replay_data: Dictionary) -> String:
	match command_type:
		"PlayCard":
			var card_name := _resolve_card_name(str(payload.get("card_id", "")))
			var row_name := _format_row_name(str(payload.get("row", "")))
			var col := int(payload.get("col", -1))
			var pos := row_name if col < 0 else "%s%s号位" % [row_name, col + 1]
			return "打出 %s 到 %s" % [card_name, pos]
		"MoveLegion":
			var moved_name := _resolve_card_name(str(payload.get("card_id", "")))
			var target_row := _format_row_name(str(payload.get("row", "")))
			var target_col := int(payload.get("col", -1))
			var move_pos := target_row if target_col < 0 else "%s%s号位" % [target_row, target_col + 1]
			return "移动 %s 到 %s" % [moved_name, move_pos]
		"DeclareAttack":
			var attacker_name := _resolve_card_name(str(payload.get("card_id", "")))
			var target_kind := str(payload.get("target_kind", ""))
			if target_kind == "master":
				var target_player := int(payload.get("target_player", -1))
				return "%s 对 %s 的主宰发起攻击" % [attacker_name, _format_command_player(target_player, replay_data)]
			var target_card := _resolve_card_name(str(payload.get("target_card_id", "")))
			return "%s 对 %s 发起攻击" % [attacker_name, target_card]
		"ChooseDefense":
			var blocker := _resolve_card_name(str(payload.get("card_id", "")))
			return "选择 %s 进行防御" % blocker
		"ActivateEffect":
			var source_name := _resolve_card_name(str(payload.get("card_id", payload.get("source_id", ""))))
			var effect_id := str(payload.get("effect_id", ""))
			return "发动 %s 的效果%s" % [source_name, "" if effect_id.is_empty() else "（%s）" % effect_id]
		"ResolveChoice":
			return _format_resolve_choice_summary(payload)
		"EndPhase":
			return "结束当前阶段"
		"PassPriority":
			return "让过优先权"
		"DebugCommand":
			return "执行调试命令"
	return command_type if not command_type.is_empty() else "未知操作"

func _format_resolve_choice_summary(payload: Dictionary) -> String:
	var choice_type := str(payload.get("choice_type", ""))
	match choice_type:
		"option_pick":
			var option_id := str(payload.get("option_id", ""))
			return "作出选项选择%s" % ("" if option_id.is_empty() else "（%s）" % option_id)
		"candidate_cards_pick":
			var cards = payload.get("card_ids", [])
			if cards is Array and not cards.is_empty():
				var names: Array[String] = []
				for card_id in cards:
					names.append(_resolve_card_name(str(card_id)))
				return "选择卡牌：%s" % "、".join(names)
	return "处理选择"

func _timeline_key_tags(row: Dictionary, replay_data: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	if not (row is Dictionary):
		return tags
	var command_type := str(row.get("type", ""))
	var payload: Dictionary = row.get("payload", {})
	var phase_before := str(row.get("phase_before", ""))
	var phase_after := str(row.get("phase_after", ""))
	if not phase_before.is_empty() and not phase_after.is_empty() and phase_before != phase_after:
		tags.append("阶段切换")
	match command_type:
		"PlayCard":
			tags.append("出牌")
		"DeclareAttack":
			if str(payload.get("target_kind", "")) == "master":
				tags.append("攻击主宰")
			else:
				tags.append("攻击")
		"ChooseDefense":
			tags.append("防御")
		"ActivateEffect":
			tags.append("效果")
		"ResolveChoice":
			tags.append("选择")
		"EndPhase":
			tags.append("阶段结束")
	return tags

func _on_timeline_key_only_toggled(value: bool) -> void:
	_timeline_key_only_enabled = value
	if _current_replay_data.is_empty():
		return
	if _timeline_selected_command_index >= 0:
		_pending_focus_command_index = _timeline_selected_command_index
	_render_timeline(_current_replay_data)

func _rebuild_timeline_key_indices(replay_data: Dictionary) -> Array[int]:
	var indices: Array[int] = []
	var commands = replay_data.get("commands", [])
	if not (commands is Array):
		return indices
	for row in commands:
		if not (row is Dictionary):
			continue
		if _timeline_key_tags(row, replay_data).is_empty():
			continue
		indices.append(int(row.get("index", 0)))
	indices.sort()
	return indices

func _find_prev_key_index() -> int:
	if _timeline_key_indices.is_empty():
		return -1
	if _timeline_selected_command_index < 0:
		return int(_timeline_key_indices[_timeline_key_indices.size() - 1])
	var prev := -1
	for idx in _timeline_key_indices:
		if idx < _timeline_selected_command_index:
			prev = int(idx)
		else:
			break
	return prev

func _find_next_key_index() -> int:
	if _timeline_key_indices.is_empty():
		return -1
	if _timeline_selected_command_index < 0:
		return int(_timeline_key_indices[0])
	for idx in _timeline_key_indices:
		if idx > _timeline_selected_command_index:
			return int(idx)
	return -1

func _update_timeline_key_jump_buttons() -> void:
	if _timeline_prev_key_button == null or _timeline_next_key_button == null:
		return
	_timeline_prev_key_button.disabled = _find_prev_key_index() < 0
	_timeline_next_key_button.disabled = _find_next_key_index() < 0

func _on_timeline_prev_key_pressed() -> void:
	if _current_replay_data.is_empty():
		return
	var target := _find_prev_key_index()
	if target >= 0:
		_focus_timeline_step(target)

func _on_timeline_next_key_pressed() -> void:
	if _current_replay_data.is_empty():
		return
	var target := _find_next_key_index()
	if target >= 0:
		_focus_timeline_step(target)

func _format_phase_name(phase: String) -> String:
	match phase:
		"draw":
			return "抽牌阶段"
		"main":
			return "主阶段"
		"battle":
			return "战斗阶段"
		"end":
			return "结束阶段"
		"":
			return "-"
	return phase

func _format_row_name(row: String) -> String:
	match row:
		"front":
			return "前排"
		"back":
			return "后排"
		"support":
			return "支援区"
		"artifact":
			return "神器区"
		"master":
			return "主宰区"
		"":
			return "未知区域"
	return row

func _close_detail() -> void:
	_close_replay_view()
	_detail_panel.visible = false
	_panel.visible = true
	_selected_record_id = ""
	_selected_record = {}
	_current_replay_data = {}
	_timeline_selected_command_index = -1
	_update_detail_action_state()

func _on_export_pressed() -> void:
	if _selected_record_id.is_empty():
		return
	var record_result = _store.get_record(_selected_record_id)
	if bool(record_result.get("ok", false)):
		var record: Dictionary = record_result.get("data", {})
		_export_dialog.current_file = "%s.l12r.json" % str(record.get("replay_id", "replay"))
	_export_dialog.popup_centered_ratio(0.7)

func _on_export_file_selected(path: String) -> void:
	if _selected_record_id.is_empty():
		return
	var result = _store.export_record(_selected_record_id, path)
	if bool(result.get("ok", false)):
		_message_label.text = "导出成功"
	elif str(result.get("code", "")) == "EXPORT_TARGET_EXISTS":
		_message_label.text = "导出失败：%s" % _format_store_result_message(result)
	else:
		_message_label.text = "导出失败：%s" % _format_store_result_message(result)

func _on_delete_pressed() -> void:
	if _selected_record_id.is_empty():
		return
	var result = _store.delete_record(_selected_record_id, true)
	if bool(result.get("ok", false)):
		_detail_panel.visible = false
		_selected_record_id = ""
		_refresh_list()
		_message_label.text = "已删除"
	else:
		_message_label.text = "删除失败：%s" % _format_store_result_message(result)

func _format_store_result_message(result: Dictionary) -> String:
	var code := str(result.get("code", ""))
	match code:
		"INDEX_INVALID_JSON":
			return "历史索引文件已损坏，请先尝试“修复索引”。"
		"INDEX_INVALID_SCHEMA":
			return "历史索引结构异常，请先尝试“修复索引”。"
		"INDEX_RECORD_NOT_FOUND":
			return "历史记录不存在，可能已被删除或被修复流程移除。"
		"REPLAY_FILE_NOT_FOUND":
			return "回放文件缺失，请尝试“修复索引”或重新导入该记录。"
		"INVALID_REPLAY_SCHEMA":
			return "回放文件格式无效，可能已损坏。"
		"REPLAY_ALREADY_EXISTS":
			return "该回放已导入，如需替换请使用覆盖导入。"
		"EXPORT_TARGET_EXISTS":
			return "目标文件已存在，请更换文件名后再试。"
		"EXPORT_READ_FAILED":
			return "读取回放文件失败，请确认原始历史记录仍然完整。"
		"EXPORT_WRITE_FAILED":
			return "无法写入导出文件，请检查目标目录权限。"
		"OPEN_WRITE_FAILED":
			return "无法写入历史数据，请检查目录权限或磁盘状态。"
		"CREATE_DIR_FAILED":
			return "无法创建历史目录，请检查目录权限。"
		_:
			var message := str(result.get("message", "")).strip_edges()
			if not message.is_empty():
				return message
	return "发生未知错误，请稍后重试。"

func _format_storage_issue_code(code: String) -> String:
	match code:
		"INDEX_INVALID_JSON", "INDEX_INVALID_SCHEMA":
			return "索引损坏"
		"INDEX_RECORD_INVALID":
			return "索引记录异常"
		"INDEX_RECORD_ID_MISSING":
			return "记录ID缺失"
		"INDEX_RECORD_ID_DUPLICATED":
			return "记录ID重复"
		"INDEX_REPLAY_ID_MISSING":
			return "回放ID缺失"
		"INDEX_REPLAY_ID_DUPLICATED":
			return "回放ID重复"
		"INDEX_REPLAY_PATH_MISSING":
			return "回放路径缺失"
		"INDEX_REPLAY_FILE_MISSING":
			return "回放文件缺失"
		"ORPHAN_REPLAY_FILE":
			return "孤立回放文件"
		_:
			return code
