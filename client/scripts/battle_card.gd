class_name BattleCard
extends Control

signal card_clicked(card)
signal card_double_clicked(card)
signal drag_started(card)
signal drag_moved(card, global_drag_position: Vector2)
signal drag_finished(card, global_drop_position: Vector2)
signal hover_started(card)
signal hover_finished(card)
signal long_press_preview_requested(card)
signal long_press_preview_finished(card)

var card_data: Dictionary = {}
var draggable := false
var selected := false
var dimmed := false
var use_overlay_long_press_preview := false

const HOVER_SCALE := 5.0
const HOVER_MARGIN := 10.0
const RESTED_ROTATION_DEGREES := 90.0
const LONG_PRESS_SECONDS := 0.28
const RULE_CARD_BACK_PATH := "res://client/assets/rule_card_back.png"

var _art_texture: TextureRect
var _fallback_panel: Panel
var _fallback_label: Label
var _selection_wash: ColorRect
var _power_wash: ColorRect
var _selection_frame: Panel
var _power_badge: Panel
var _power_label: Label
var _cost_badge: Panel
var _cost_label: Label
var _status_badge_box: Control
var _pressing := false
var _dragging := false
var _double_click_consumed := false
var _press_position := Vector2.ZERO
var _drag_pointer_offset := Vector2.ZERO
var _last_pointer_global_position := Vector2.ZERO
var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _base_rotation_degrees := 0.0
var _base_modulate := Color.WHITE
var _base_z_index := 0
var _hovered := false
var _hover_tween: Tween
var _power_tween: Tween
var _long_press_timer: SceneTreeTimer
var _long_press_preview_active := false
var _setup_initialized := false
var _last_setup_signature: int = 0

static var _texture_cache: Dictionary = {}
static var _fallback_panel_style: StyleBoxFlat
static var _selection_frame_style_default: StyleBoxFlat
static var _selection_frame_style_selected: StyleBoxFlat
static var _power_badge_style_default: StyleBoxFlat
static var _power_badge_style_buffed: StyleBoxFlat
static var _power_badge_style_damaged: StyleBoxFlat
static var _cost_badge_style_discount: StyleBoxFlat
static var _cost_badge_style_surcharge: StyleBoxFlat
static var _status_badge_style: StyleBoxFlat
static var _rule_card_back_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_build_visuals()
	_apply_card_data()
	_layout_visuals()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func setup(data: Dictionary, can_drag: bool, is_selected: bool, is_dimmed: bool) -> void:
	var next_signature: int = hash([data, can_drag, is_selected, is_dimmed])
	if _setup_initialized and next_signature == _last_setup_signature:
		return
	_reset_interaction_state_for_setup()
	_setup_initialized = true
	_last_setup_signature = next_signature
	card_data = data
	draggable = can_drag
	selected = is_selected
	dimmed = is_dimmed
	if is_inside_tree():
		_apply_card_data()
		_layout_visuals()


func set_use_overlay_long_press_preview(value: bool) -> void:
	use_overlay_long_press_preview = value


func set_selected(value: bool) -> void:
	selected = value
	if is_inside_tree():
		_apply_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout_visuals()


func _build_visuals() -> void:
	_fallback_panel = Panel.new()
	_fallback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fallback_panel)
	_fallback_label = Label.new()
	_fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fallback_label.add_theme_font_size_override("font_size", 12)
	_fallback_panel.add_child(_fallback_label)

	_art_texture = TextureRect.new()
	_art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_art_texture)

	_selection_wash = ColorRect.new()
	_selection_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_wash.color = Color(1.0, 0.94, 0.48, 0.18)
	add_child(_selection_wash)

	_power_wash = ColorRect.new()
	_power_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_wash.visible = false
	add_child(_power_wash)

	_selection_frame = Panel.new()
	_selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selection_frame)

	_power_badge = Panel.new()
	_power_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_badge.z_index = 90
	add_child(_power_badge)

	_power_label = Label.new()
	_power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_power_label.add_theme_font_size_override("font_size", 14)
	_power_badge.add_child(_power_label)

	_cost_badge = Panel.new()
	_cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_badge)

	_cost_label = Label.new()
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 12)
	_cost_badge.add_child(_cost_label)

	_status_badge_box = Control.new()
	_status_badge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_badge_box.z_index = 92
	_status_badge_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_status_badge_box)
	pivot_offset = size * 0.5
	_fallback_panel.add_theme_stylebox_override("panel", _get_fallback_panel_style())


func _apply_card_data() -> void:
	var definition: Dictionary = card_data.get("definition", {})
	var face_down := str(card_data.get("face", "face_up")) == "face_down"
	var face_path := str(definition.get("card_face_path", ""))
	if face_path == "":
		face_path = str(definition.get("image_path", ""))
	var back_path := str(card_data.get("card_back_path", definition.get("card_back_path", RULE_CARD_BACK_PATH)))
	if back_path.is_empty():
		back_path = RULE_CARD_BACK_PATH
	_art_texture.texture = _load_card_texture(back_path) if face_down else _load_card_texture(face_path)
	if _fallback_panel != null and _fallback_label != null:
		var has_texture := _art_texture.texture != null
		_fallback_panel.visible = not has_texture
		_fallback_label.text = _fallback_card_text(definition)
	_base_rotation_degrees = _rest_rotation_for_card()
	if not _dragging and not _pressing:
		rotation_degrees = _base_rotation_degrees
	_apply_power_badge(definition)
	_apply_cost_badge(definition)
	_apply_status_badges()
	_apply_style()


func _apply_style() -> void:
	if _selection_frame == null:
		return
	if dimmed:
		modulate = Color(1.0, 1.0, 1.0, 0.42)
	elif selected:
		modulate = Color(1.16, 1.13, 1.02, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _selection_wash != null:
		_selection_wash.visible = selected
	_selection_frame.add_theme_stylebox_override("panel", _get_selection_frame_style(selected))


func _layout_visuals() -> void:
	if _art_texture == null:
		return

	_fallback_panel.position = Vector2.ZERO
	_fallback_panel.size = size
	_fallback_label.position = Vector2(8, 8)
	_fallback_label.size = size - Vector2(16, 16)
	_art_texture.position = Vector2.ZERO
	_art_texture.size = size
	_selection_wash.position = Vector2.ZERO
	_selection_wash.size = size
	if _power_wash != null:
		_power_wash.position = Vector2.ZERO
		_power_wash.size = size
	_selection_frame.position = Vector2.ZERO
	_selection_frame.size = size
	if _power_badge != null:
		_power_badge.size = Vector2(42, 22)
		_power_badge.position = Vector2((size.x - _power_badge.size.x) * 0.5, size.y + 3)
		_power_label.position = Vector2.ZERO
		_power_label.size = _power_badge.size
	if _cost_badge != null:
		_cost_badge.position = Vector2(6, 6)
		_cost_badge.size = Vector2(24, 21)
		_cost_label.position = Vector2.ZERO
		_cost_label.size = _cost_badge.size
	if _status_badge_box != null:
		_status_badge_box.position = Vector2(6.0, 4.0)
		_status_badge_box.size = Vector2(maxf(0.0, size.x - 12.0), 18.0)
		_layout_status_badges()
	pivot_offset = size * 0.5


func _apply_power_badge(definition: Dictionary) -> void:
	if _power_badge == null or _power_label == null:
		return
	var card_type := str(definition.get("type", ""))
	var zone := str(card_data.get("zone", ""))
	var manifests_battle_power := card_type == "artifact" and zone.begins_with("battle_")
	if str(card_data.get("face", "face_up")) == "face_down":
		_power_badge.visible = false
		if _power_wash != null:
			_power_wash.visible = false
		return
	var current_power := int(card_data.get("current_hp", 0))
	var base_power := int(definition.get("hp", definition.get("power", 0)))
	var should_show := manifests_battle_power and current_power > 0
	if not should_show:
		should_show = card_type == "legion" and base_power > 0 and current_power != base_power
	_power_badge.visible = should_show
	if not should_show:
		if _power_tween != null:
			_power_tween.kill()
			_power_tween = null
		_power_badge.scale = Vector2.ONE
		if _power_wash != null:
			_power_wash.visible = false
		return
	if _power_wash != null:
		_power_wash.visible = true
	_power_label.text = str(current_power)
	if current_power < base_power:
		_power_badge.add_theme_stylebox_override("panel", _get_power_badge_style("damaged"))
		_power_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.78, 1.0))
		if _power_wash != null:
			_power_wash.color = Color(1.0, 0.18, 0.08, 0.06)
	elif current_power > base_power:
		_power_badge.add_theme_stylebox_override("panel", _get_power_badge_style("buffed"))
		_power_label.add_theme_color_override("font_color", Color(0.84, 1.0, 0.88, 1.0))
		if _power_wash != null:
			_power_wash.color = Color(0.10, 1.0, 0.28, 0.05)
	else:
		_power_badge.add_theme_stylebox_override("panel", _get_power_badge_style("default"))
		_power_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	_animate_power_badge()


func _apply_cost_badge(definition: Dictionary) -> void:
	if _cost_badge == null or _cost_label == null:
		return
	var card_type := str(definition.get("type", ""))
	if str(card_data.get("face", "face_up")) == "face_down":
		_cost_badge.visible = false
		return
	var base_cost := int(definition.get("cost", 0))
	var current_cost := int(card_data.get("current_cost", base_cost))
	var should_show := card_type == "legion" and current_cost != base_cost
	_cost_badge.visible = should_show
	if not should_show:
		return
	_cost_label.text = str(current_cost)
	if current_cost < base_cost:
		_cost_badge.add_theme_stylebox_override("panel", _get_cost_badge_style(true))
		_cost_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 1.0))
	else:
		_cost_badge.add_theme_stylebox_override("panel", _get_cost_badge_style(false))
		_cost_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.78, 1.0))


func _apply_status_badges() -> void:
	if _status_badge_box == null:
		return
	for child in _status_badge_box.get_children():
		_status_badge_box.remove_child(child)
		child.queue_free()
	var badges_variant = card_data.get("status_badges", [])
	if str(card_data.get("face", "face_up")) == "face_down" or not (badges_variant is Array) or badges_variant.is_empty():
		_status_badge_box.visible = false
		return
	var zone := str(card_data.get("zone", ""))
	if not zone.begins_with("battle_"):
		_status_badge_box.visible = false
		return
	var badge_count := 0
	for raw_badge in badges_variant:
		var badge_text := str(raw_badge)
		if badge_text.is_empty():
			continue
		var badge_panel := Panel.new()
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge_panel.custom_minimum_size = Vector2(36, 16)
		badge_panel.add_theme_stylebox_override("panel", _get_status_badge_style())
		var badge_label := Label.new()
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", 9)
		badge_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
		badge_label.text = badge_text
		badge_label.position = Vector2.ZERO
		badge_label.size = badge_panel.custom_minimum_size
		badge_panel.add_child(badge_label)
		_status_badge_box.add_child(badge_panel)
		badge_count += 1
	_status_badge_box.visible = badge_count > 0
	_layout_status_badges()


func _layout_status_badges() -> void:
	if _status_badge_box == null or not _status_badge_box.visible:
		return
	var badge_controls: Array[Control] = []
	var total_width := 0.0
	var separation := 4.0
	for child in _status_badge_box.get_children():
		if child is Control:
			var badge_control := child as Control
			badge_controls.append(badge_control)
			total_width += badge_control.custom_minimum_size.x
	if badge_controls.is_empty():
		return
	total_width += separation * float(max(0, badge_controls.size() - 1))
	var current_x := maxf(0.0, (_status_badge_box.size.x - total_width) * 0.5)
	for badge_control in badge_controls:
		var badge_size := badge_control.custom_minimum_size
		badge_control.position = Vector2(current_x, maxf(0.0, (_status_badge_box.size.y - badge_size.y) * 0.5))
		badge_control.size = badge_size
		for child in badge_control.get_children():
			if child is Label:
				var badge_label := child as Label
				badge_label.position = Vector2.ZERO
				badge_label.size = badge_size
		current_x += badge_size.x + separation


func _animate_power_badge() -> void:
	if _power_badge == null:
		return
	if _power_tween != null:
		_power_tween.kill()
		_power_tween = null
	_power_badge.scale = Vector2(0.92, 0.92)
	_power_badge.pivot_offset = _power_badge.size * 0.5
	_power_tween = create_tween()
	_power_tween.set_parallel(true)
	_power_tween.tween_property(_power_badge, "scale", Vector2(1.10, 1.10), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_power_tween.set_parallel(false)
	_power_tween.tween_property(_power_badge, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _fallback_card_text(definition: Dictionary) -> String:
	if str(card_data.get("face", "face_up")) == "face_down":
		if str(definition.get("type", "")) == "hidden_hand":
			return ""
		if str(definition.get("type", "")) == "counter_tactic":
			return "伏置\n反击"
		return "伏置"
	var zone := str(card_data.get("zone", ""))
	if zone == "cost_area" or zone == "spent_cost_area":
		return "士气"
	var name := str(definition.get("name", ""))
	if not name.is_empty():
		return name
	return str(card_data.get("definition_id", "卡牌"))


static func _get_fallback_panel_style() -> StyleBoxFlat:
	if _fallback_panel_style == null:
		_fallback_panel_style = StyleBoxFlat.new()
		_fallback_panel_style.bg_color = Color(0.07, 0.09, 0.12, 0.96)
		_fallback_panel_style.border_color = Color(0.78, 0.82, 0.94, 0.78)
		_fallback_panel_style.border_width_left = 1
		_fallback_panel_style.border_width_top = 1
		_fallback_panel_style.border_width_right = 1
		_fallback_panel_style.border_width_bottom = 1
		_fallback_panel_style.corner_radius_top_left = 6
		_fallback_panel_style.corner_radius_top_right = 6
		_fallback_panel_style.corner_radius_bottom_left = 6
		_fallback_panel_style.corner_radius_bottom_right = 6
	return _fallback_panel_style


static func _get_selection_frame_style(is_selected: bool) -> StyleBoxFlat:
	if is_selected:
		if _selection_frame_style_selected == null:
			_selection_frame_style_selected = StyleBoxFlat.new()
			_selection_frame_style_selected.bg_color = Color.TRANSPARENT
			_selection_frame_style_selected.border_color = Color(0.62, 0.92, 1.0, 0.95)
			_selection_frame_style_selected.border_width_left = 3
			_selection_frame_style_selected.border_width_top = 3
			_selection_frame_style_selected.border_width_right = 3
			_selection_frame_style_selected.border_width_bottom = 3
			_selection_frame_style_selected.corner_radius_top_left = 6
			_selection_frame_style_selected.corner_radius_top_right = 6
			_selection_frame_style_selected.corner_radius_bottom_left = 6
			_selection_frame_style_selected.corner_radius_bottom_right = 6
		return _selection_frame_style_selected
	if _selection_frame_style_default == null:
		_selection_frame_style_default = StyleBoxFlat.new()
		_selection_frame_style_default.bg_color = Color.TRANSPARENT
		_selection_frame_style_default.border_color = Color(0.62, 0.92, 1.0, 0.0)
		_selection_frame_style_default.border_width_left = 0
		_selection_frame_style_default.border_width_top = 0
		_selection_frame_style_default.border_width_right = 0
		_selection_frame_style_default.border_width_bottom = 0
		_selection_frame_style_default.corner_radius_top_left = 6
		_selection_frame_style_default.corner_radius_top_right = 6
		_selection_frame_style_default.corner_radius_bottom_left = 6
		_selection_frame_style_default.corner_radius_bottom_right = 6
	return _selection_frame_style_default


static func _get_power_badge_style(style_kind: String) -> StyleBoxFlat:
	match style_kind:
		"damaged":
			if _power_badge_style_damaged == null:
				_power_badge_style_damaged = _make_badge_style(Color(0.22, 0.06, 0.04, 0.94), Color(1.0, 0.42, 0.26, 0.98))
			return _power_badge_style_damaged
		"buffed":
			if _power_badge_style_buffed == null:
				_power_badge_style_buffed = _make_badge_style(Color(0.03, 0.18, 0.08, 0.94), Color(0.42, 1.0, 0.58, 0.98))
			return _power_badge_style_buffed
	if _power_badge_style_default == null:
		_power_badge_style_default = _make_badge_style(Color(0.05, 0.07, 0.09, 0.90), Color(0.88, 0.91, 0.98, 0.90))
	return _power_badge_style_default


static func _get_cost_badge_style(is_discount: bool) -> StyleBoxFlat:
	if is_discount:
		if _cost_badge_style_discount == null:
			_cost_badge_style_discount = _make_badge_style(Color(0.07, 0.12, 0.18, 0.92), Color(0.46, 0.78, 1.0, 0.98))
		return _cost_badge_style_discount
	if _cost_badge_style_surcharge == null:
		_cost_badge_style_surcharge = _make_badge_style(Color(0.18, 0.09, 0.04, 0.92), Color(1.0, 0.68, 0.34, 0.98))
	return _cost_badge_style_surcharge


static func _get_status_badge_style() -> StyleBoxFlat:
	if _status_badge_style == null:
		_status_badge_style = _make_badge_style(Color(0.05, 0.07, 0.09, 0.90), Color(0.92, 0.96, 1.0, 0.92))
		_status_badge_style.content_margin_left = 4
		_status_badge_style.content_margin_right = 4
		_status_badge_style.content_margin_top = 1
		_status_badge_style.content_margin_bottom = 1
	return _status_badge_style


static func _make_badge_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _load_card_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if path == RULE_CARD_BACK_PATH:
		return _load_rule_card_back_texture()
	if _texture_cache.has(path):
		return _texture_cache[path]

	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		var global_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_path):
			var image := Image.load_from_file(global_path)
			if image != null and not image.is_empty():
				texture = ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture


static func _load_rule_card_back_texture() -> Texture2D:
	if _rule_card_back_texture != null:
		return _rule_card_back_texture
	var texture := load(RULE_CARD_BACK_PATH) as Texture2D
	if texture == null:
		push_warning("Unable to load rule card back image: %s" % RULE_CARD_BACK_PATH)
		return null
	_rule_card_back_texture = texture
	return _rule_card_back_texture


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_last_pointer_global_position = event.global_position
		if event.pressed:
			if event.double_click:
				_double_click_consumed = true
				_pressing = false
				_dragging = false
				_finish_long_press_preview()
				_cancel_long_press_timer()
				if _hover_tween != null:
					_hover_tween.kill()
					_hover_tween = null
				_set_hovered(false)
				card_double_clicked.emit(self)
				accept_event()
				return
			_double_click_consumed = false
			_pressing = true
			_dragging = false
			_long_press_preview_active = false
			_press_position = event.global_position
			_drag_pointer_offset = event.global_position - global_position
			if _hover_tween != null:
				_hover_tween.kill()
				_hover_tween = null
			_set_hovered(false)
			_start_long_press_timer()
			accept_event()
		else:
			if _double_click_consumed:
				_double_click_consumed = false
				accept_event()
				return
			_cancel_long_press_timer()
			if _dragging:
				drag_finished.emit(self, event.global_position)
			elif _long_press_preview_active:
				_finish_long_press_preview()
			elif event.double_click:
				card_double_clicked.emit(self)
			else:
				card_clicked.emit(self)
			_pressing = false
			_dragging = false
			_long_press_preview_active = false
			accept_event()
	elif event is InputEventScreenTouch:
		var global_touch_position := _event_global_position(event)
		_last_pointer_global_position = global_touch_position
		if event.pressed:
			_double_click_consumed = false
			_pressing = true
			_dragging = false
			_long_press_preview_active = false
			_press_position = global_touch_position
			_drag_pointer_offset = global_touch_position - global_position
			if _hover_tween != null:
				_hover_tween.kill()
				_hover_tween = null
			_set_hovered(false)
			_start_long_press_timer()
			accept_event()
		else:
			_cancel_long_press_timer()
			if _dragging:
				drag_finished.emit(self, global_touch_position)
			elif _long_press_preview_active:
				_finish_long_press_preview()
			else:
				card_clicked.emit(self)
			_pressing = false
			_dragging = false
			_long_press_preview_active = false
			accept_event()
	elif event is InputEventMouseMotion and _pressing and draggable:
		_last_pointer_global_position = event.global_position
		if not _dragging and event.global_position.distance_to(_press_position) > 5.0:
			_dragging = true
			_cancel_long_press_timer()
			_set_hovered(false)
			drag_started.emit(self)
		if _dragging:
			global_position = event.global_position - _drag_pointer_offset
			drag_moved.emit(self, event.global_position)
			accept_event()
	elif event is InputEventScreenDrag and _pressing and draggable:
		var global_drag_position := _event_global_position(event)
		_last_pointer_global_position = global_drag_position
		if not _dragging and global_drag_position.distance_to(_press_position) > 5.0:
			_dragging = true
			_cancel_long_press_timer()
			_set_hovered(false)
			drag_started.emit(self)
		if _dragging:
			global_position = global_drag_position - _drag_pointer_offset
			drag_moved.emit(self, global_drag_position)
			accept_event()


func get_last_pointer_global_position() -> Vector2:
	return _last_pointer_global_position


func _event_global_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.global_position
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return get_global_transform_with_canvas() * event.position
	return _last_pointer_global_position


func _on_mouse_entered() -> void:
	hover_started.emit(self)


func _on_mouse_exited() -> void:
	_cancel_long_press_timer()
	_finish_long_press_preview()
	hover_finished.emit(self)


func _set_hovered(value: bool) -> void:
	if _dragging or (_pressing and not _long_press_preview_active):
		value = false
	if value == _hovered:
		return
	if use_overlay_long_press_preview:
		_hovered = value
		if value:
			long_press_preview_requested.emit(self)
		else:
			long_press_preview_finished.emit(self)
		return
	_hovered = value
	if _hover_tween != null:
		_hover_tween.kill()
		_hover_tween = null
	if value:
		_base_position = position
		_base_scale = scale
		_base_rotation_degrees = rotation_degrees
		_base_modulate = modulate
		_base_z_index = z_index
		z_index = max(z_index, 900)
		if _should_clear_dim_on_hover():
			modulate = Color.WHITE
		var target_scale: Vector2 = _base_scale * HOVER_SCALE
		var target_position: Vector2 = _clamped_position_for_scale(target_scale)
		_hover_tween = create_tween()
		_hover_tween.set_parallel(true)
		_hover_tween.tween_property(self, "position", target_position, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "rotation_degrees", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_hover_tween = create_tween()
		_hover_tween.set_parallel(true)
		_hover_tween.tween_property(self, "position", _base_position, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "scale", _base_scale, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "rotation_degrees", _base_rotation_degrees, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.set_parallel(false)
		_hover_tween.tween_callback(func() -> void:
			modulate = _base_modulate
			z_index = _base_z_index
		)


func _clamped_position_for_scale(target_scale: Vector2) -> Vector2:
	var viewport_size: Vector2 = _hover_bounds_size()
	var target_size: Vector2 = Vector2(size.x * abs(target_scale.x), size.y * abs(target_scale.y))
	var center: Vector2 = position + pivot_offset
	var target_top_left: Vector2 = center - target_size * 0.5
	var min_position := Vector2(HOVER_MARGIN, HOVER_MARGIN)
	var max_position := viewport_size - target_size - Vector2(HOVER_MARGIN, HOVER_MARGIN)
	if max_position.x < min_position.x:
		target_top_left.x = (viewport_size.x - target_size.x) * 0.5
	else:
		target_top_left.x = clamp(target_top_left.x, min_position.x, max_position.x)
	if max_position.y < min_position.y:
		target_top_left.y = (viewport_size.y - target_size.y) * 0.5
	else:
		target_top_left.y = clamp(target_top_left.y, min_position.y, max_position.y)
	var clamped_center: Vector2 = target_top_left + target_size * 0.5
	return clamped_center - pivot_offset


func _hover_bounds_size() -> Vector2:
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		return parent_control.size
	return get_viewport_rect().size


func _should_clear_dim_on_hover() -> bool:
	return dimmed


func _rest_rotation_for_card() -> float:
	return RESTED_ROTATION_DEGREES if str(card_data.get("orientation", "active")) == "rested" else 0.0


func _start_long_press_timer() -> void:
	_cancel_long_press_timer()
	_long_press_timer = get_tree().create_timer(LONG_PRESS_SECONDS)
	_long_press_timer.timeout.connect(_on_long_press_timeout)


func _cancel_long_press_timer() -> void:
	_long_press_timer = null


func _on_long_press_timeout() -> void:
	if not _pressing or _dragging:
		return
	_long_press_preview_active = true
	_set_hovered(true)


func _finish_long_press_preview() -> void:
	if _long_press_preview_active:
		_set_hovered(false)
	_long_press_preview_active = false


func _restore_base_visual_state(target_position: Variant = null) -> void:
	if target_position is Vector2:
		position = target_position
	else:
		position = _base_position
	scale = _base_scale
	rotation_degrees = _base_rotation_degrees
	modulate = _base_modulate
	z_index = _base_z_index


func _reset_interaction_state_for_setup() -> void:
	var intended_position := position
	_cancel_long_press_timer()
	_pressing = false
	_dragging = false
	_double_click_consumed = false
	_last_pointer_global_position = Vector2.ZERO
	_finish_long_press_preview()
	if _hover_tween != null:
		_hover_tween.kill()
		_hover_tween = null
	_restore_base_visual_state(intended_position)
