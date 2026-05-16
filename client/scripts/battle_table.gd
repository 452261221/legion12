extends Control

const BattleCardScript = preload("res://client/scripts/battle_card.gd")
const DuelNetworkSession = preload("res://client/scripts/duel_network_session.gd")
const CardDatabase = preload("res://rules/core/card_database.gd")
const CardDefinition = preload("res://rules/core/card_definition.gd")
const GameCommand = preload("res://rules/core/game_command.gd")
const GameEngine = preload("res://rules/core/game_engine.gd")
const StateHasher = preload("res://rules/core/state_hasher.gd")
const AiController = preload("res://ai/runtime/ai_controller.gd")
const LlmProviderRegistry = preload("res://ai/llm/llm_provider_registry.gd")
const OpenAICompatibleLlmClient = preload("res://ai/llm/openai_compatible_llm_client.gd")
const DeckBuilderStore = preload("res://client/scripts/deck_builder_store.gd")
const DeckBuilderView = preload("res://client/scripts/deck_builder_view.gd")
const CardGalleryCatalog = preload("res://client/scripts/card_gallery_catalog.gd")
const MatchHistoryStore = preload("res://client/scripts/history/match_history_store.gd")
const MatchHistoryView = preload("res://client/scripts/history/match_history_view.gd")
const CardPoolHasher = preload("res://rules/core/card_pool_hasher.gd")
const ReplayIO = preload("res://client/scripts/replay/replay_io.gd")
const MatchReplaySession = preload("res://client/scripts/replay/match_replay_session.gd")

const DESIGN_SIZE := Vector2(1123, 1921)
const DESIGN_ASPECT_RATIO := DESIGN_SIZE.x / DESIGN_SIZE.y
const BACKGROUND_PATH := "res://client/assets/battlefield_background_extended.png"
const RULE_CARD_BACK_PATH := "res://client/assets/rule_card_back.png"
const CALAMITY_CARD_BACK_PATH := "res://规则/天灾牌背.png"
const RULE_START_BACKGROUND_PATH := "res://client/assets/start_background.png"
const RULE_ILLUSTRATION_DIR := "res://规则/立绘"
const RULE_ILLUSTRATION_THUMB_DIR := "res://规则/立绘/thumbs"
const USER_BACKGROUND_OUTPUT_PATH := "user://custom_start_background.png"
const TABLE_TOP_PAD := 260.0
const BATTLE_LOG_DIR := "user://battle_logs"
const FORMAL_DECK_PATH := "res://data/decks/starter_takamagahara_asgard_raw.json"
const TEST_DECK_PATH := "res://data/decks/test_duel.json"
const NO_TEST_MODE_FEATURE := "no_test_mode"
const CARD_DATA_DIR := "res://data/cards"
const EXTRA_CARD_DATA_PATHS := [
	"res://data/raw_rule_cards/starter_duel_master_cards.json",
	"res://data/raw_rule_cards/tianting_master_cards.json",
	"res://data/raw_rule_cards/olympus_master_cards.json",
	"res://data/raw_rule_cards/bijie_master_cards.json",
	"res://data/raw_rule_cards/suncity_master_cards.json",
]
const FORMAL_GAME_OPTIONS := {
	"mode": "formal",
	"calamity_random_three_plus_annihilation": true
}
const TEST_GAME_OPTIONS := {
	"mode": "formal",
	"test_mode": true,
	"calamity_deck": [
		"calamity_s01_ds04",
		"sys_calamity_embers",
		"sys_calamity_silence"
	]
}
const AI_POLICY_MODE_SCRIPTED := "scripted"
const AI_POLICY_MODE_LLM := "llm"
const BATTLE_MODE_QUICK := "quick"
const BATTLE_MODE_MATCH := "match"
const START_PANEL_DEFAULT_DESC := ""
const AI_STEP_INTERVAL_SEC := 0.25
const AI_STALL_THRESHOLD_MS := 2200
const AI_STALL_FORCE_COOLDOWN_MS := 400
const NETWORK_COMMAND_TIMEOUT_MS := 12000
const NETWORK_RESYNC_TIMEOUT_MS := 12000
const NETWORK_TERMINATION_REASON_NORMAL_FINISH := "normal_finished"
const NETWORK_TERMINATION_REASON_LOCAL_DISCONNECT := "local_disconnect"
const NETWORK_TERMINATION_REASON_SESSION_CLOSED := "session_closed"
const NETWORK_TERMINATION_REASON_PEER_DISCONNECTED := "peer_disconnected"
const NETWORK_TERMINATION_REASON_COMMAND_TIMEOUT := "command_timeout"
const NETWORK_TERMINATION_REASON_RESYNC_TIMEOUT := "resync_timeout"
const NETWORK_TERMINATION_REASON_RESYNC_FAILED := "resync_failed"
const NETWORK_TERMINATION_REASON_HOST_REJECTED_COMMAND := "host_rejected_command"
const DUEL_LOG_FLUSH_INTERVAL_SEC := 0.25
const NETWORK_PERF_WARN_MS := 16
const NETWORK_HASH_PERF_WARN_MS := 8
const REFRESH_MODE_IMMEDIATE := 0
const REFRESH_MODE_DEFERRED := 1
const REFRESH_MODE_NONE := 2

const PLAYER_BOTTOM := 0
const PLAYER_TOP := 1
const BOARD_SLOT_COUNT := 6
const CARD_FACE_DIR := "res://client/assets/cards"
const CARD_FACE_MANIFEST_PATH := "res://client/assets/cards/card_faces_manifest.json"
const MORALE_IMAGE_BY_MASTER_ID := {
	"takamagahara_s01_04m1": "res://client/assets/cards/morale_takamagahara_v2.png",
	"takamagahara_s02_04m1": "res://client/assets/cards/morale_takamagahara_v2.png",
	"takamagahara_s01_04m2": "res://client/assets/cards/morale_takamagahara_v2.png",
	"asgard_s01_03m1": "res://client/assets/cards/morale_asgard_v2.png",
	"asgard_s02_03m1": "res://client/assets/cards/morale_asgard_v2.png",
	"asgard_s01_03m2a": "res://client/assets/cards/morale_asgard_v2.png",
	"tianting_s01_01m1": "res://规则/牌面/天廷/士气.png",
	"tianting_s01_01m2": "res://规则/牌面/天廷/士气.png",
	"tianting_s02_01m1": "res://规则/牌面/天廷/士气.png",
}

const BLACK_LOTUS_DEFINITION_ID := "neutral_s02_0010"
const MORALE_DISPLAY_RANK_ACTIVE := 0
const MORALE_DISPLAY_RANK_SPENT := 1
const MORALE_DISPLAY_RANK_BLACK_LOTUS := 2

const HAND_RECTS := {
	PLAYER_BOTTOM: Rect2(180, 1681, 765, 165),
	PLAYER_TOP: Rect2(180, 75, 765, 165),
}

const BOARD_RECTS := {
	PLAYER_BOTTOM: [
		Rect2(254, 746, 118, 165),
		Rect2(418, 746, 118, 165),
		Rect2(582, 746, 118, 165),
		Rect2(254, 963, 118, 165),
		Rect2(418, 963, 118, 165),
		Rect2(582, 963, 118, 165),
	],
	PLAYER_TOP: [
		Rect2(751, 490, 118, 165),
		Rect2(587, 490, 118, 165),
		Rect2(423, 490, 118, 165),
		Rect2(751, 273, 118, 165),
		Rect2(587, 273, 118, 165),
		Rect2(423, 273, 118, 165),
	],
}

const DIVINITY_RECTS := {
	PLAYER_BOTTOM: Rect2(35, 742, 139, 193),
	PLAYER_TOP: Rect2(949, 466, 139, 193),
}

const ARTIFACT_RECTS := {
	PLAYER_BOTTOM: Rect2(35, 964, 139, 193),
	PLAYER_TOP: Rect2(949, 244, 139, 193),
}

const CALAMITY_RECTS := {
	PLAYER_BOTTOM: Rect2(854, 746, 193, 139),
	PLAYER_TOP: Rect2(72, 516, 193, 139),
}

const MASTER_RECTS := {
	PLAYER_BOTTOM: Rect2(783, 964, 139, 193),
	PLAYER_TOP: Rect2(201, 244, 139, 193),
}

const DECK_RECTS := {
	PLAYER_BOTTOM: Rect2(958, 964, 139, 193),
	PLAYER_TOP: Rect2(26, 244, 139, 193),
}

const COST_DECK_RECTS := {
	PLAYER_BOTTOM: Rect2(35, 1186, 139, 193),
	PLAYER_TOP: Rect2(949, 22, 139, 193),
}

const COST_AREA_RECTS := {
	PLAYER_BOTTOM: Rect2(323, 1186, 477, 193),
	PLAYER_TOP: Rect2(323, 22, 477, 193),
}

const TABLE_AREA_SIZE := Vector2(1123, 1401)
const CALAMITY_TRACK_STARS := 8
const CALAMITY_STAR_OVERLAY_PATH := "res://client/assets/ui/calamity_stars_lit_overlay.png"
const CALAMITY_STAR_CLIP_RIGHTS := [0.0, 340.0, 414.0, 488.0, 563.0, 637.0, 711.0, 786.0, 860.0]
const POPUP_GAP := 14.0
const POPUP_LEFT_WIDTH := 316.0
const POPUP_MIDDLE_WIDTH := 340.0
const POPUP_RIGHT_WIDTH := 340.0
const PILE_LONG_PRESS_SECONDS := 0.28

const GRAVE_RECTS := {
	PLAYER_BOTTOM: Rect2(958, 1186, 139, 193),
	PLAYER_TOP: Rect2(26, 22, 139, 193),
}

var _background: TextureRect
var _zone_layer: Control
var _highlight_layer: Control
var _zone_static_layer: Control
var _zone_interaction_layer: Control
var _zone_overlay_layer: Control
var _selection_highlight_layer: Control
var _drag_highlight_layer: Control
var _card_layer: Control
var _ui_layer: Control
var _preview_layer: Control
var _overlay_card_preview: Control
var _grave_popup_overlay: Control
var _drag_target_layer: Control
var _drag_line: Line2D
var _start_panel: Panel
var _start_panel_background: TextureRect
var _start_panel_title: Label
var _start_panel_desc: Label
var _system_settings_button: Button
var _system_settings_view: Control
var _system_settings_tabs: TabContainer
var _system_settings_save_button: Button
var _system_settings_back_button: Button
var _startup_notice_dialog: PopupPanel
var _battle_mode_option: OptionButton
var _ai_mode_option: OptionButton
var _ai_llm_toggle: CheckBox
var _ai_llm_settings_button: Button
var _llm_settings_dialog: ConfirmationDialog
var _llm_provider_option: OptionButton
var _llm_api_key_edit: LineEdit
var _llm_base_url_edit: LineEdit
var _llm_model_edit: LineEdit
var _llm_runtime_mode_option: OptionButton
var _llm_timeout_edit: LineEdit
var _llm_enable_thinking_toggle: CheckBox
var _llm_response_max_tokens_edit: LineEdit
var _llm_response_max_tokens_preset_option: OptionButton
var _ai_prompt_edit: TextEdit
var _start_duel_button: Button
var _start_test_button: Button
var _host_duel_button: Button
var _join_duel_button: Button
var _disconnect_button: Button
var _deck_builder_button: Button
var _history_button: Button
var _join_address_dialog: Control
var _join_address_prompt_edit: LineEdit
var _join_address_confirm_button: Button
var _join_address_back_button: Button
var _network_status_label: Label
var _deck_builder_view: DeckBuilderView
var _history_view: MatchHistoryView
var _game_result_overlay: Control
var _game_result_panel: Panel
var _game_result_title: Label
var _game_result_badge: Label
var _game_result_desc: Label
var _game_result_confirm_button: Button
var _network_sync_overlay: Control
var _network_sync_label: Label
var _opening_overlay: Control
var _opening_overlay_title: Label
var _opening_overlay_desc: Label
var _opening_overlay_status: Label
var _opening_overlay_cards: GridContainer
var _opening_overlay_action_box: VBoxContainer
var _opening_overlay_panel: PanelContainer
var _opening_overlay_scroll: ScrollContainer
var _opening_overlay_confirm_button: Button
var _opening_overlay_cancel_button: Button
var _busy_status_panel: PanelContainer
var _busy_status_spinner: Label
var _busy_status_title: Label
var _busy_status_detail: Label
var _table_replay_overlay: Control
var _table_replay_panel: Panel
var _table_replay_step_label: Label
var _table_replay_first_button: Button
var _table_replay_prev_button: Button
var _table_replay_prev_turn_button: Button
var _table_replay_play_button: Button
var _table_replay_speed_button: Button
var _table_replay_next_turn_button: Button
var _table_replay_next_button: Button
var _table_replay_last_button: Button
var _table_replay_seek_label: Label
var _table_replay_seek_slider: HSlider
var _table_replay_close_button: Button
var _table_replay_timeline_hint: Label
var _table_replay_timeline_scroll: ScrollContainer
var _table_replay_timeline_box: VBoxContainer
var _table_replay_timer: Timer
var _table_replay_restart_dialog: ConfirmationDialog
var _table_replay_restart_mode_option: OptionButton
var _table_replay_restart_replay_data: Dictionary = {}
var _table_replay_restart_command_index := 0
var _table_replay_restart_record_id := ""
var _hud_loading_timer: Timer
var _hud_loading_frame := 0
var _hud_loading_frames: Array[String] = ["|", "/", "-", "\\"]
var _turn_label: Label
var _log_label: Label
var _end_turn_button: Button
var _return_to_main_button: Button
var _action_panel: Panel
var _action_panel_title: Label
var _action_panel_body: VBoxContainer
var _response_panel: Panel
var _response_panel_title: Label
var _response_panel_body: VBoxContainer
var _choice_panel: Panel
var _choice_panel_title: Label
var _choice_panel_body: VBoxContainer
var _stack_panel: Panel
var _stack_panel_title: Label
var _stack_panel_body: VBoxContainer
var _card_definitions: Dictionary = {}
var _engine_card_definitions: Array = []
var _card_face_manifest: Dictionary = {}
var _engine := GameEngine.new()
var _state = null
var _waiting_state: Dictionary = {}
var _actions_by_player := {PLAYER_BOTTOM: [], PLAYER_TOP: []}
var _actions_dirty_by_player := {PLAYER_BOTTOM: true, PLAYER_TOP: true}
var _players: Array = []
var _active_player := PLAYER_BOTTOM
var _turn_number := 1
var _selected_attacker_uid := ""
var _dragging_card_uid := ""
var _drag_origin_local := Vector2.ZERO
var _drag_origin_global := Vector2.ZERO
var _hover_slot_index := -1
var _hover_zone_kind := ""
var _touch_scroll_target: ScrollContainer
var _touch_scroll_active := false
var _touch_scroll_started := false
var _touch_scroll_distance := 0.0
var _log_lines: Array[String] = []
var _game_over := false
var _pending_animations: Array[Dictionary] = []
var _last_logged_event_id := 0
var _duel_log_path := ""
var _duel_log_label := ""
var _selected_target_action: Dictionary = {}
var _selected_stack_target_id := ""
var _selected_source_id := ""
var _selected_morale_filter := false
var _active_choice_id := ""
var _choice_selected_card_ids: Array[String] = []
var _choice_reorder_dragging_card_id := ""
var _local_play_option_choice: Dictionary = {}
var _selected_master_guard_cards: Array[String] = []
var _selected_unit_defense_proposal_id := ""
var _master_guard_feedback_text := ""
var _master_guard_submit_pending := false
var _pending_self_response_followup_player := -1
var _suppressed_self_response_followup_signature := ""
var _master_double_click_consumed := false
var _opening_animation_seeded := false
var _last_card_orientation_by_id: Dictionary = {}
var _pile_long_press_token_seed := 0
var _last_master_hp_by_player: Dictionary = {}
var _last_winner := -1
var _calamity_star_overlay_texture: Texture2D
var _rule_card_back_texture: Texture2D
var _rule_start_background_texture: Texture2D
var _battlefield_background_texture: Texture2D
var _user_background_texture: Texture2D
var _network_session: DuelNetworkSession
var _network_mode_active := false
var _network_is_host := false
var _local_player_id := PLAYER_BOTTOM
var _pending_start_duel_seed := 1
var _network_command_index := 0
var _pending_network_commands: Dictionary = {}
var _network_watchdog_timer: Timer
var _network_resync_in_progress := false
var _network_resync_started_at_ms := 0
var _network_terminal_message := ""
var _network_connect_hint := ""
var _network_remote_formal_deck_selection: Dictionary = {}
var _network_opening_response_cache: Dictionary = {}
var _current_duel_path := ""
var _current_game_options: Dictionary = {}
var _current_duel_label := ""
var _current_duel_seed := -1
var _duel_started_at := 0
var _history_saved := false
var _history_store: MatchHistoryStore
var _table_replay_active := false
var _table_replay_session := MatchReplaySession.new()
var _table_replay_record_id := ""
var _table_replay_data: Dictionary = {}
var _table_replay_auto_playing := false
var _table_replay_timeline_buttons: Dictionary = {}
var _table_replay_speed_options := [1.0, 1.8, 3.0]
var _table_replay_speed_index := 0
var _table_replay_seek_internal_update := false
var _table_replay_seek_dragging := false
var _duel_log_buffer: Array[String] = []
var _ai_raw_log_path := ""
var _ai_raw_log_buffer: Array[String] = []
var _duel_log_flush_timer: Timer
var _ai_timer: Timer
var _battle_mode := BATTLE_MODE_QUICK
var _ai_mode := 1
var _ai_override_players: Array[int] = []
var _ai_use_llm := false
var _ai_controller = null
var _llm_runtime_settings: Dictionary = {}
var _llm_settings_editing_provider := ""
var _startup_notice_opened_this_session := false
var _ai_blocked_until_ms := 0
var _ai_stall_last_command_count := 0
var _ai_stall_last_progress_ms := 0
var _ai_stall_last_force_ms := 0
var _ai_async_thread: Thread
var _ai_async_started_ms := 0
var _ai_async_waiting_player := -1
var _ai_async_waiting_state := ""
var _ai_async_expected_command_count := -1
var _ai_async_expected_state_hash := ""
var _ai_async_actions: Array = []
var _ai_async_detached_threads: Array[Thread] = []
var _ai_trace_last_reason := ""
var _ai_trace_last_detail := ""
var _ai_last_decision_status := ""
var _ai_last_decision_detail := ""
var _deferred_refresh_pending := false
var _deferred_network_auto_pass_pending := false
var _startup_ready := false
var _deck_builder_initialized := false
var _card_views_by_uid: Dictionary = {}
var _card_view_seen_ids: Dictionary = {}
var _view_cards_by_uid: Dictionary = {}
var _player_views_cache: Dictionary = {}
var _master_view_cards_by_player: Dictionary = {}
var _zone_static_signature := ""
var _zone_interaction_signature := ""
var _selection_highlight_signature := ""
var _action_panel_signature := ""
var _response_panel_signature := ""
var _choice_panel_signature := ""
var _stack_panel_signature := ""
var _opening_overlay_prompt: Dictionary = {}
var _opening_overlay_selected_ids: Array[String] = []
var _opening_overlay_selected_option := ""
var _network_sync_message := ""
var _opening_session: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if OS.has_feature("android"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	_network_session = DuelNetworkSession.new()
	add_child(_network_session)
	_network_session.status_changed.connect(_on_network_status_changed)
	_network_session.session_changed.connect(_on_network_session_changed)
	_network_session.remote_peer_changed.connect(_on_network_remote_peer_changed)
	_network_session.remote_formal_deck_selection_received.connect(_on_network_remote_formal_deck_selection_received)
	_network_session.opening_prompt_received.connect(_on_network_opening_prompt_received)
	_network_session.opening_response_received.connect(_on_network_opening_response_received)
	_network_session.start_duel_received.connect(_on_network_start_duel_received)
	_network_session.host_command_requested.connect(_on_network_host_command_requested)
	_network_session.command_applied_received.connect(_on_network_command_applied_received)
	_network_session.command_failed_received.connect(_on_network_command_failed_received)
	_network_session.resync_requested.connect(_on_network_resync_requested)
	_network_session.resync_payload_received.connect(_on_network_resync_payload_received)
	_network_watchdog_timer = Timer.new()
	_network_watchdog_timer.wait_time = 1.0
	_network_watchdog_timer.one_shot = false
	_network_watchdog_timer.autostart = true
	_network_watchdog_timer.timeout.connect(_on_network_watchdog_timeout)
	add_child(_network_watchdog_timer)
	_duel_log_flush_timer = Timer.new()
	_duel_log_flush_timer.wait_time = DUEL_LOG_FLUSH_INTERVAL_SEC
	_duel_log_flush_timer.one_shot = false
	_duel_log_flush_timer.autostart = true
	_duel_log_flush_timer.timeout.connect(_flush_duel_log_buffer)
	add_child(_duel_log_flush_timer)
	_history_store = MatchHistoryStore.new()
	_ai_controller = AiController.new()
	_load_llm_runtime_settings()
	_apply_ai_policy_mode({})
	_ai_timer = Timer.new()
	_ai_timer.wait_time = AI_STEP_INTERVAL_SEC
	_ai_timer.one_shot = false
	_ai_timer.autostart = true
	_ai_timer.timeout.connect(_on_ai_timer_timeout)
	add_child(_ai_timer)
	_hud_loading_timer = Timer.new()
	_hud_loading_timer.wait_time = 0.16
	_hud_loading_timer.one_shot = false
	_hud_loading_timer.autostart = true
	_hud_loading_timer.timeout.connect(_on_hud_loading_timer_timeout)
	add_child(_hud_loading_timer)
	_create_layers()
	_show_start_panel_loading("正在加载正式对局资源...")
	call_deferred("_finish_startup_bootstrap")
	resized.connect(_refresh)
	_refresh()


func _input(event: InputEvent) -> void:
	if not OS.has_feature("android"):
		return
	if _history_view != null and _history_view.visible:
		return
	if _system_settings_view == null or not _system_settings_view.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_scroll_target = _pick_touch_scroll_target(event.position)
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


func _pick_touch_scroll_target(global_position: Vector2) -> ScrollContainer:
	if _system_settings_view != null and _system_settings_view.visible and _system_settings_tabs != null:
		var current_control := _system_settings_tabs.get_current_tab_control()
		if current_control is ScrollContainer:
			var scroll := current_control as ScrollContainer
			if scroll.visible and scroll.get_global_rect().has_point(global_position):
				return scroll
	return null


func _scroll_vertical_by(target: ScrollContainer, delta_y: float) -> void:
	if target == null:
		return
	var bar := target.get_v_scroll_bar()
	if bar == null:
		return
	var max_value := int(bar.max_value)
	target.scroll_vertical = clampi(target.scroll_vertical - int(delta_y), 0, max_value)


func _exit_tree() -> void:
	_wait_for_ai_threads_on_exit()
	_flush_duel_log_buffer()
	_flush_ai_raw_log_buffer()


func _create_layers() -> void:
	_background = TextureRect.new()
	_background.name = "BattlefieldBackground"
	var background_texture := _get_battlefield_background_texture()
	if background_texture != null:
		_background.texture = background_texture
	else:
		push_warning("Unable to load battlefield background")
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_zone_layer = Control.new()
	_zone_layer.name = "ZoneLayer"
	_zone_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_zone_layer)
	_zone_static_layer = Control.new()
	_zone_static_layer.name = "ZoneStaticLayer"
	_zone_static_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_static_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zone_layer.add_child(_zone_static_layer)
	_zone_interaction_layer = Control.new()
	_zone_interaction_layer.name = "ZoneInteractionLayer"
	_zone_interaction_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_interaction_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zone_layer.add_child(_zone_interaction_layer)
	_zone_overlay_layer = Control.new()
	_zone_overlay_layer.name = "ZoneOverlayLayer"
	_zone_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_overlay_layer.z_index = 180
	_zone_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_zone_overlay_layer)

	_highlight_layer = Control.new()
	_highlight_layer.name = "DropHighlightLayer"
	_highlight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_highlight_layer)
	_selection_highlight_layer = Control.new()
	_selection_highlight_layer.name = "SelectionHighlightLayer"
	_selection_highlight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_highlight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highlight_layer.add_child(_selection_highlight_layer)
	_drag_highlight_layer = Control.new()
	_drag_highlight_layer.name = "DragHighlightLayer"
	_drag_highlight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_highlight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highlight_layer.add_child(_drag_highlight_layer)

	_card_layer = Control.new()
	_card_layer.name = "CardLayer"
	_card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_layer.z_index = 100
	_card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_card_layer)

	_ui_layer = Control.new()
	_ui_layer.name = "UiLayer"
	_ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.z_index = 700
	_ui_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_layer)

	_preview_layer = Control.new()
	_preview_layer.name = "PreviewLayer"
	_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_layer.z_index = 900
	_preview_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_preview_layer)

	_drag_target_layer = Control.new()
	_drag_target_layer.name = "DragTargetLayer"
	_drag_target_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_target_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_layer.add_child(_drag_target_layer)

	_drag_line = Line2D.new()
	_drag_line.visible = false
	_drag_line.width = 4.0
	_drag_line.default_color = Color(1.0, 0.82, 0.38, 0.92)
	_drag_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_drag_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_drag_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_preview_layer.add_child(_drag_line)

	_start_panel = _make_panel()
	_start_panel.name = "StartPanel"
	_start_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_start_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var start_panel_style := StyleBoxFlat.new()
	start_panel_style.bg_color = Color(0.03, 0.05, 0.07, 0.24)
	start_panel_style.border_color = Color(0.74, 0.82, 0.98, 0.28)
	start_panel_style.border_width_left = 1
	start_panel_style.border_width_top = 1
	start_panel_style.border_width_right = 1
	start_panel_style.border_width_bottom = 1
	start_panel_style.corner_radius_top_left = 8
	start_panel_style.corner_radius_top_right = 8
	start_panel_style.corner_radius_bottom_left = 8
	start_panel_style.corner_radius_bottom_right = 8
	_start_panel.add_theme_stylebox_override("panel", start_panel_style)
	_ui_layer.add_child(_start_panel)
	_start_panel_background = TextureRect.new()
	_start_panel_background.name = "StartPanelBackground"
	_start_panel_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_panel_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_panel_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_start_panel_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_start_panel_background.texture = _get_active_background_texture()
	_start_panel.add_child(_start_panel_background)
	var start_vbox := VBoxContainer.new()
	start_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_vbox.offset_left = 28
	start_vbox.offset_top = 28
	start_vbox.offset_right = -28
	start_vbox.offset_bottom = -28
	start_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	start_vbox.add_theme_constant_override("separation", 14)
	_start_panel.add_child(start_vbox)
	_start_panel_title = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_start_panel_title.text = "十二军团"
	start_vbox.add_child(_start_panel_title)
	_start_panel_desc = _make_label(14, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_start_panel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_start_panel_desc.text = _default_start_panel_desc_text()
	_start_panel_desc.custom_minimum_size = Vector2(320, 96)
	start_vbox.add_child(_start_panel_desc)
	_build_system_settings_dialog()
	_build_startup_notice_dialog()
	_build_join_address_dialog()
	_update_ai_mode_controls()
	_start_duel_button = _make_button("开始对局")
	_start_duel_button.custom_minimum_size = Vector2(180, 42)
	_start_duel_button.pressed.connect(_on_start_duel_pressed)
	start_vbox.add_child(_start_duel_button)
	if _is_test_mode_available():
		_start_test_button = _make_button("测试")
		_start_test_button.custom_minimum_size = Vector2(180, 42)
		_start_test_button.pressed.connect(_on_start_test_pressed)
		start_vbox.add_child(_start_test_button)
	_deck_builder_button = _make_button("卡组构筑")
	_deck_builder_button.custom_minimum_size = Vector2(180, 42)
	_deck_builder_button.pressed.connect(_open_deck_builder)
	start_vbox.add_child(_deck_builder_button)
	_history_button = _make_button("历史对局")
	_history_button.custom_minimum_size = Vector2(180, 42)
	_history_button.pressed.connect(_open_match_history)
	start_vbox.add_child(_history_button)

	_host_duel_button = _make_button("创建房间")
	_host_duel_button.custom_minimum_size = Vector2(180, 42)
	_host_duel_button.pressed.connect(_on_host_duel_pressed)
	start_vbox.add_child(_host_duel_button)

	_join_duel_button = _make_button("加入房间")
	_join_duel_button.custom_minimum_size = Vector2(180, 42)
	_join_duel_button.pressed.connect(_on_join_duel_pressed)
	start_vbox.add_child(_join_duel_button)

	_system_settings_button = _make_button("系统设置")
	_system_settings_button.custom_minimum_size = Vector2(180, 42)
	_system_settings_button.pressed.connect(_on_system_settings_pressed)
	start_vbox.add_child(_system_settings_button)

	_disconnect_button = _make_button("断开联机")
	_disconnect_button.custom_minimum_size = Vector2(180, 42)
	_disconnect_button.visible = false
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	start_vbox.add_child(_disconnect_button)

	_network_status_label = _make_label(12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network_status_label.custom_minimum_size = Vector2(320, 72)
	_network_status_label.text = "本地模式：可直接开始对局。\n联机模式需要在相同局域网环境。"
	start_vbox.add_child(_network_status_label)

	_deck_builder_view = DeckBuilderView.new()
	_deck_builder_view.z_index = 980
	_deck_builder_view.back_requested.connect(_close_deck_builder)
	_deck_builder_view.decks_changed.connect(_on_deck_builder_changed)
	_deck_builder_view.background_changed.connect(_on_background_changed)
	add_child(_deck_builder_view)
	_history_view = MatchHistoryView.new()
	_history_view.z_index = 985
	_history_view.back_requested.connect(_close_match_history)
	_history_view.resume_requested.connect(_on_history_resume_requested)
	_history_view.table_replay_requested.connect(_on_history_table_replay_requested)
	add_child(_history_view)
	if _start_panel_background != null:
		_history_view.set_background_texture(_start_panel_background.texture)

	_game_result_overlay = Control.new()
	_game_result_overlay.name = "GameResultOverlay"
	_game_result_overlay.visible = false
	_game_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_result_overlay.z_index = 950
	_game_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_game_result_overlay)
	var result_backdrop := ColorRect.new()
	result_backdrop.color = Color(0.01, 0.02, 0.04, 0.82)
	result_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	result_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_result_overlay.add_child(result_backdrop)
	_game_result_panel = Panel.new()
	_game_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_result_panel.custom_minimum_size = Vector2(520.0, 0.0)
	_game_result_panel.size = Vector2(520.0, 0.0)
	_game_result_panel.position = (size - Vector2(520.0, 0.0)) * 0.5
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color(0.05, 0.07, 0.10, 0.97)
	result_style.border_color = Color(0.98, 0.86, 0.45, 0.88)
	result_style.border_width_left = 2
	result_style.border_width_top = 2
	result_style.border_width_right = 2
	result_style.border_width_bottom = 2
	result_style.corner_radius_top_left = 18
	result_style.corner_radius_top_right = 18
	result_style.corner_radius_bottom_left = 18
	result_style.corner_radius_bottom_right = 18
	result_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	result_style.shadow_size = 18
	result_style.shadow_offset = Vector2(0, 8)
	_game_result_panel.add_theme_stylebox_override("panel", result_style)
	_game_result_overlay.add_child(_game_result_panel)
	var result_vbox := VBoxContainer.new()
	result_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_vbox.offset_left = 28
	result_vbox.offset_top = 26
	result_vbox.offset_right = -28
	result_vbox.offset_bottom = -26
	result_vbox.add_theme_constant_override("separation", 14)
	_game_result_panel.add_child(result_vbox)
	_game_result_badge = _make_label(14, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_game_result_badge.custom_minimum_size = Vector2(120.0, 34.0)
	result_vbox.add_child(_game_result_badge)
	_game_result_title = _make_label(36, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_game_result_title.custom_minimum_size = Vector2(0.0, 54.0)
	result_vbox.add_child(_game_result_title)
	_game_result_desc = _make_label(15, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_game_result_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_result_desc.custom_minimum_size = Vector2(0.0, 92.0)
	result_vbox.add_child(_game_result_desc)
	_game_result_confirm_button = _make_button("确认返回主页面")
	_game_result_confirm_button.custom_minimum_size = Vector2(220.0, 46.0)
	_game_result_confirm_button.pressed.connect(_on_game_result_confirmed)
	result_vbox.add_child(_game_result_confirm_button)

	_network_sync_overlay = Control.new()
	_network_sync_overlay.name = "NetworkSyncOverlay"
	_network_sync_overlay.visible = false
	_network_sync_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_network_sync_overlay.z_index = 940
	_network_sync_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_network_sync_overlay)
	var network_backdrop := ColorRect.new()
	network_backdrop.color = Color(0.01, 0.02, 0.04, 0.72)
	network_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	network_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_network_sync_overlay.add_child(network_backdrop)
	var network_panel := Panel.new()
	network_panel.custom_minimum_size = Vector2(620.0, 0.0)
	network_panel.size = Vector2(620.0, 0.0)
	network_panel.position = (size - Vector2(620.0, 0.0)) * 0.5
	var network_style := StyleBoxFlat.new()
	network_style.bg_color = Color(0.05, 0.07, 0.10, 0.96)
	network_style.border_color = Color(0.58, 0.74, 0.98, 0.75)
	network_style.border_width_left = 2
	network_style.border_width_top = 2
	network_style.border_width_right = 2
	network_style.border_width_bottom = 2
	network_style.corner_radius_top_left = 14
	network_style.corner_radius_top_right = 14
	network_style.corner_radius_bottom_left = 14
	network_style.corner_radius_bottom_right = 14
	network_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	network_style.shadow_size = 14
	network_style.shadow_offset = Vector2(0, 6)
	network_panel.add_theme_stylebox_override("panel", network_style)
	_network_sync_overlay.add_child(network_panel)
	var network_vbox := VBoxContainer.new()
	network_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	network_vbox.offset_left = 24
	network_vbox.offset_top = 22
	network_vbox.offset_right = -24
	network_vbox.offset_bottom = -22
	network_vbox.add_theme_constant_override("separation", 10)
	network_panel.add_child(network_vbox)
	var network_title := _make_label(18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	network_title.text = "联机同步中"
	network_vbox.add_child(network_title)
	_network_sync_label = _make_label(14, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_network_sync_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network_sync_label.custom_minimum_size = Vector2(0.0, 72.0)
	network_vbox.add_child(_network_sync_label)

	_opening_overlay = Control.new()
	_opening_overlay.name = "OpeningOverlay"
	_opening_overlay.visible = false
	_opening_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_opening_overlay.z_index = 943
	_opening_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_opening_overlay)
	var opening_backdrop := _make_blurred_backdrop(0.76)
	opening_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_opening_overlay.add_child(opening_backdrop)
	var opening_outer := MarginContainer.new()
	opening_outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opening_outer.add_theme_constant_override("margin_left", 16)
	opening_outer.add_theme_constant_override("margin_top", 16)
	opening_outer.add_theme_constant_override("margin_right", 16)
	opening_outer.add_theme_constant_override("margin_bottom", 16)
	_opening_overlay.add_child(opening_outer)
	var opening_center := CenterContainer.new()
	opening_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opening_outer.add_child(opening_center)
	_opening_overlay_panel = PanelContainer.new()
	_opening_overlay_panel.custom_minimum_size = Vector2(640.0, 0.0)
	_opening_overlay_panel.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.04, 0.06, 0.09, 0.98),
		Color(0.96, 0.82, 0.40, 0.52),
		22,
		2,
		22
	))
	opening_center.add_child(_opening_overlay_panel)
	var opening_margin := MarginContainer.new()
	opening_margin.add_theme_constant_override("margin_left", 22)
	opening_margin.add_theme_constant_override("margin_top", 20)
	opening_margin.add_theme_constant_override("margin_right", 22)
	opening_margin.add_theme_constant_override("margin_bottom", 20)
	_opening_overlay_panel.add_child(opening_margin)
	var opening_vbox := VBoxContainer.new()
	opening_vbox.add_theme_constant_override("separation", 12)
	opening_margin.add_child(opening_vbox)
	_opening_overlay_title = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_opening_overlay_title.text = "开局准备"
	_opening_overlay_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	opening_vbox.add_child(_opening_overlay_title)
	_opening_overlay_desc = _make_label(13, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_opening_overlay_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_opening_overlay_desc.add_theme_color_override("font_color", Color(0.82, 0.88, 0.97, 0.94))
	opening_vbox.add_child(_opening_overlay_desc)
	_opening_overlay_status = _make_label(12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_opening_overlay_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_opening_overlay_status.add_theme_color_override("font_color", Color(0.74, 0.82, 0.92, 0.88))
	opening_vbox.add_child(_opening_overlay_status)
	_opening_overlay_scroll = ScrollContainer.new()
	_opening_overlay_scroll.custom_minimum_size = Vector2(0.0, 300.0)
	_opening_overlay_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opening_overlay_scroll.size_flags_vertical = 0
	opening_vbox.add_child(_opening_overlay_scroll)
	var opening_body := VBoxContainer.new()
	opening_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opening_body.add_theme_constant_override("separation", 12)
	_opening_overlay_scroll.add_child(opening_body)
	_opening_overlay_cards = GridContainer.new()
	_opening_overlay_cards.columns = 4
	_opening_overlay_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opening_overlay_cards.add_theme_constant_override("h_separation", 10)
	_opening_overlay_cards.add_theme_constant_override("v_separation", 10)
	opening_body.add_child(_opening_overlay_cards)
	_opening_overlay_action_box = VBoxContainer.new()
	_opening_overlay_action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opening_overlay_action_box.add_theme_constant_override("separation", 10)
	opening_body.add_child(_opening_overlay_action_box)
	var opening_action_row := HBoxContainer.new()
	opening_action_row.alignment = BoxContainer.ALIGNMENT_END
	opening_action_row.add_theme_constant_override("separation", 10)
	opening_vbox.add_child(opening_action_row)
	_opening_overlay_cancel_button = _make_button("返回")
	_opening_overlay_cancel_button.custom_minimum_size = Vector2(112.0, 42.0)
	_style_settings_button(_opening_overlay_cancel_button, false)
	_opening_overlay_cancel_button.pressed.connect(_on_opening_overlay_cancel_pressed)
	opening_action_row.add_child(_opening_overlay_cancel_button)
	_opening_overlay_confirm_button = _make_button("确认")
	_opening_overlay_confirm_button.custom_minimum_size = Vector2(132.0, 42.0)
	_style_settings_button(_opening_overlay_confirm_button, true)
	_opening_overlay_confirm_button.pressed.connect(_on_opening_overlay_confirm_pressed)
	opening_action_row.add_child(_opening_overlay_confirm_button)

	_busy_status_panel = PanelContainer.new()
	_busy_status_panel.name = "BusyStatusPanel"
	_busy_status_panel.visible = false
	_busy_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy_status_panel.z_index = 941
	_busy_status_panel.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.04, 0.07, 0.11, 0.92),
		Color(0.72, 0.86, 1.0, 0.42),
		18,
		1,
		12
	))
	_ui_layer.add_child(_busy_status_panel)
	var busy_margin := MarginContainer.new()
	busy_margin.add_theme_constant_override("margin_left", 16)
	busy_margin.add_theme_constant_override("margin_top", 12)
	busy_margin.add_theme_constant_override("margin_right", 16)
	busy_margin.add_theme_constant_override("margin_bottom", 12)
	_busy_status_panel.add_child(busy_margin)
	var busy_row := HBoxContainer.new()
	busy_row.add_theme_constant_override("separation", 12)
	busy_margin.add_child(busy_row)
	_busy_status_spinner = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_busy_status_spinner.custom_minimum_size = Vector2(28.0, 28.0)
	_busy_status_spinner.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	busy_row.add_child(_busy_status_spinner)
	var busy_text_box := VBoxContainer.new()
	busy_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	busy_text_box.add_theme_constant_override("separation", 4)
	busy_row.add_child(busy_text_box)
	_busy_status_title = _make_label(14, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	_busy_status_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_busy_status_title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	busy_text_box.add_child(_busy_status_title)
	_busy_status_detail = _make_label(12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	_busy_status_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_busy_status_detail.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96, 0.96))
	busy_text_box.add_child(_busy_status_detail)

	_table_replay_overlay = Control.new()
	_table_replay_overlay.name = "TableReplayOverlay"
	_table_replay_overlay.visible = false
	_table_replay_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_table_replay_overlay.z_index = 945
	_table_replay_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_table_replay_overlay)
	var replay_backdrop := ColorRect.new()
	replay_backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	replay_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_table_replay_overlay.add_child(replay_backdrop)
	_table_replay_panel = Panel.new()
	_table_replay_panel.custom_minimum_size = Vector2(0.0, 0.0)
	var replay_style := StyleBoxFlat.new()
	replay_style.bg_color = Color(0.05, 0.07, 0.10, 0.82)
	replay_style.border_color = Color(0.85, 0.85, 0.88, 0.65)
	replay_style.border_width_left = 2
	replay_style.border_width_top = 2
	replay_style.border_width_right = 2
	replay_style.border_width_bottom = 2
	replay_style.corner_radius_top_left = 12
	replay_style.corner_radius_top_right = 12
	replay_style.corner_radius_bottom_left = 12
	replay_style.corner_radius_bottom_right = 12
	_table_replay_panel.add_theme_stylebox_override("panel", replay_style)
	_table_replay_overlay.add_child(_table_replay_panel)
	var replay_vbox := HBoxContainer.new()
	replay_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replay_vbox.offset_left = 12
	replay_vbox.offset_top = 12
	replay_vbox.offset_right = -12
	replay_vbox.offset_bottom = -12
	replay_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	replay_vbox.add_theme_constant_override("separation", 8)
	_table_replay_panel.add_child(replay_vbox)
	_table_replay_close_button = _make_button("退出牌桌回放")
	_table_replay_close_button.custom_minimum_size = Vector2(132.0, 44.0)
	_table_replay_close_button.pressed.connect(_close_table_replay_mode)
	replay_vbox.add_child(_table_replay_close_button)
	_table_replay_prev_button = _make_button("上一步")
	_table_replay_prev_button.custom_minimum_size = Vector2(104.0, 44.0)
	_table_replay_prev_button.pressed.connect(_on_table_replay_prev_pressed)
	replay_vbox.add_child(_table_replay_prev_button)
	_table_replay_next_button = _make_button("下一步")
	_table_replay_next_button.custom_minimum_size = Vector2(104.0, 44.0)
	_table_replay_next_button.pressed.connect(_on_table_replay_next_pressed)
	replay_vbox.add_child(_table_replay_next_button)
	_table_replay_last_button = _make_button("重新对局")
	_table_replay_last_button.custom_minimum_size = Vector2(120.0, 44.0)
	_table_replay_last_button.pressed.connect(_on_table_replay_restart_pressed)
	replay_vbox.add_child(_table_replay_last_button)
	_table_replay_step_label = null
	_table_replay_seek_label = null
	_table_replay_seek_slider = null
	_table_replay_timeline_hint = null
	_table_replay_timeline_scroll = null
	_table_replay_timeline_box = null

	_table_replay_timer = Timer.new()
	_table_replay_timer.one_shot = false
	_table_replay_timer.wait_time = 0.65
	_table_replay_timer.timeout.connect(_on_table_replay_timer_timeout)
	add_child(_table_replay_timer)

	_table_replay_restart_dialog = ConfirmationDialog.new()
	_table_replay_restart_dialog.title = "重新对局"
	_table_replay_restart_dialog.ok_button_text = "开始"
	_table_replay_restart_dialog.cancel_button_text = "取消"
	_table_replay_restart_dialog.confirmed.connect(_on_table_replay_restart_confirmed)
	add_child(_table_replay_restart_dialog)
	var table_replay_restart_vbox := VBoxContainer.new()
	table_replay_restart_vbox.add_theme_constant_override("separation", 10)
	_table_replay_restart_dialog.add_child(table_replay_restart_vbox)
	var table_replay_restart_label := Label.new()
	table_replay_restart_label.text = "从当前回放节点重新开始一局，选择对手模式："
	table_replay_restart_vbox.add_child(table_replay_restart_label)
	_table_replay_restart_mode_option = OptionButton.new()
	_table_replay_restart_mode_option.custom_minimum_size = Vector2(220, 36)
	_table_replay_restart_mode_option.add_item("无人机", 0)
	_table_replay_restart_mode_option.add_item("对战人机", 1)
	_table_replay_restart_mode_option.selected = 0
	table_replay_restart_vbox.add_child(_table_replay_restart_mode_option)
	_update_table_replay_overlay_layout()

	_turn_label = _make_label(16, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_turn_label.name = "TurnStatus"
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_label.add_theme_font_size_override("font_size", 15)
	_turn_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_turn_label.visible = false
	_ui_layer.add_child(_turn_label)

	_log_label = _make_label(12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	_log_label.name = "BattleLog"
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.visible = false
	_ui_layer.add_child(_log_label)

	_end_turn_button = _make_button("结束回合")
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_end_turn_button.add_theme_font_size_override("font_size", 12)
	_end_turn_button.custom_minimum_size = Vector2(112.0, 40.0)
	_end_turn_button.size = Vector2(112.0, 40.0)
	_end_turn_button.scale = Vector2.ONE
	_end_turn_button.pivot_offset = Vector2.ZERO
	_end_turn_button.visible = false
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_ui_layer.add_child(_end_turn_button)

	_return_to_main_button = _make_button("返回主界面")
	_return_to_main_button.name = "ReturnToMainButton"
	_return_to_main_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_return_to_main_button.add_theme_font_size_override("font_size", 12)
	_return_to_main_button.custom_minimum_size = Vector2(96.0, 40.0)
	_return_to_main_button.size = Vector2(96.0, 40.0)
	_return_to_main_button.scale = Vector2.ONE
	_return_to_main_button.pivot_offset = Vector2.ZERO
	_return_to_main_button.visible = false
	_return_to_main_button.pressed.connect(_return_to_main_page)
	_ui_layer.add_child(_return_to_main_button)

	_action_panel = _make_panel()
	_action_panel.name = "ActionPanel"
	_ui_layer.add_child(_action_panel)
	var action_vbox := VBoxContainer.new()
	action_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action_vbox.offset_left = 8
	action_vbox.offset_top = 8
	action_vbox.offset_right = -8
	action_vbox.offset_bottom = -8
	_action_panel.add_child(action_vbox)
	_action_panel_title = _make_label(13, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	action_vbox.add_child(_action_panel_title)
	_action_panel_body = VBoxContainer.new()
	_action_panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_vbox.add_child(_action_panel_body)

	_response_panel = _make_panel()
	_response_panel.name = "ResponsePanel"
	_ui_layer.add_child(_response_panel)
	var response_vbox := VBoxContainer.new()
	response_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	response_vbox.offset_left = 8
	response_vbox.offset_top = 8
	response_vbox.offset_right = -8
	response_vbox.offset_bottom = -8
	_response_panel.add_child(response_vbox)
	_response_panel_title = _make_label(13, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	response_vbox.add_child(_response_panel_title)
	_response_panel_body = VBoxContainer.new()
	_response_panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	response_vbox.add_child(_response_panel_body)

	_choice_panel = _make_panel()
	_choice_panel.name = "ChoicePanel"
	_ui_layer.add_child(_choice_panel)
	var choice_vbox := VBoxContainer.new()
	choice_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_vbox.offset_left = 8
	choice_vbox.offset_top = 8
	choice_vbox.offset_right = -8
	choice_vbox.offset_bottom = -8
	_choice_panel.add_child(choice_vbox)
	_choice_panel_title = _make_label(13, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	choice_vbox.add_child(_choice_panel_title)
	_choice_panel_body = VBoxContainer.new()
	_choice_panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_vbox.add_child(_choice_panel_body)

	_stack_panel = _make_panel()
	_stack_panel.name = "StackPanel"
	_ui_layer.add_child(_stack_panel)
	var stack_vbox := VBoxContainer.new()
	stack_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack_vbox.offset_left = 8
	stack_vbox.offset_top = 8
	stack_vbox.offset_right = -8
	stack_vbox.offset_bottom = -8
	_stack_panel.add_child(stack_vbox)
	_stack_panel_title = _make_label(13, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	stack_vbox.add_child(_stack_panel_title)
	_stack_panel_body = VBoxContainer.new()
	_stack_panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack_vbox.add_child(_stack_panel_body)


func _load_card_definitions() -> void:
	_card_definitions.clear()
	_engine_card_definitions.clear()
	_load_card_face_manifest()
	var merged_definitions: Array = CardDatabase.load_definitions(CARD_DATA_DIR)
	for path in EXTRA_CARD_DATA_PATHS:
		merged_definitions.append_array(CardDatabase.load_definitions(path))
	for raw_card in merged_definitions:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var id := str(raw_card.get("id", ""))
		if id != "":
			var face_path := _find_card_face_path(id)
			if not face_path.is_empty():
				raw_card["card_face_path"] = face_path
			_card_definitions[id] = raw_card
			_engine_card_definitions.append(CardDefinition.from_dict(raw_card))


func _load_card_face_manifest() -> void:
	if not _card_face_manifest.is_empty():
		return
	if not FileAccess.file_exists(CARD_FACE_MANIFEST_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CARD_FACE_MANIFEST_PATH))
	if parsed is Dictionary:
		_card_face_manifest = parsed


func _find_card_face_path(card_id: String) -> String:
	if not _card_face_manifest.is_empty() and _card_face_manifest.has(card_id):
		var entry: Dictionary = _card_face_manifest.get(card_id, {})
		var manifest_path := str(entry.get("face_path", ""))
		if not manifest_path.is_empty() and ResourceLoader.exists(manifest_path):
			return manifest_path
	for extension in ["jpg", "png", "jpeg", "webp"]:
		var face_path := "%s/%s.%s" % [CARD_FACE_DIR, card_id, extension]
		if ResourceLoader.exists(face_path):
			return face_path
	return ""


func _is_test_mode_available() -> bool:
	return not OS.has_feature(NO_TEST_MODE_FEATURE)


func _start_new_duel(duel_path: String = FORMAL_DECK_PATH, game_options: Dictionary = FORMAL_GAME_OPTIONS, duel_label: String = "正式对局", duel_seed: int = -1) -> void:
	if not _is_test_mode_available() and duel_path == TEST_DECK_PATH:
		_push_log("当前发布版本未包含测试模式资源。")
		_show_start_panel()
		return
	_apply_ai_policy_mode(game_options)
	_players.clear()
	_view_cards_by_uid.clear()
	_player_views_cache.clear()
	_master_view_cards_by_player.clear()
	_selected_attacker_uid = ""
	_dragging_card_uid = ""
	_hover_slot_index = -1
	_hover_zone_kind = ""
	_selected_target_action = {}
	_selected_stack_target_id = ""
	_selected_source_id = ""
	_selected_morale_filter = false
	_selected_master_guard_cards.clear()
	_selected_unit_defense_proposal_id = ""
	_master_guard_feedback_text = ""
	_master_guard_submit_pending = false
	_log_lines.clear()
	_pending_animations.clear()
	_game_over = false
	_last_logged_event_id = 0
	_last_card_orientation_by_id.clear()
	_last_master_hp_by_player.clear()
	_last_winner = -1
	_opening_animation_seeded = false
	_ai_blocked_until_ms = 0
	_ai_stall_last_command_count = 0
	_ai_stall_last_progress_ms = Time.get_ticks_msec()
	_ai_stall_last_force_ms = 0
	_network_command_index = 0
	_pending_network_commands.clear()
	_network_resync_in_progress = false
	_network_resync_started_at_ms = 0
	_network_terminal_message = ""
	_network_connect_hint = ""
	_hide_game_result_dialog()
	if _network_mode_active and game_options is Dictionary and game_options.has("resume_commands"):
		_show_network_sync_overlay("正在同步联机续战节点并重建局面...")
	_duel_log_buffer.clear()
	_ai_raw_log_buffer.clear()
	_duel_log_label = duel_label
	_initialize_duel_log(duel_label, duel_path)
	var traced_game_options := game_options.duplicate(true)
	if not _duel_log_path.is_empty():
		traced_game_options["debug_trace_path"] = _duel_log_path
	var deck_data: Dictionary = {}
	var inline_duel_data = traced_game_options.get("inline_duel_data", null)
	if inline_duel_data is Dictionary:
		deck_data = inline_duel_data.duplicate(true)
	else:
		var deck_text := FileAccess.get_file_as_string(duel_path)
		var parsed_deck_data = JSON.parse_string(deck_text)
		if typeof(parsed_deck_data) != TYPE_DICTIONARY:
			_append_file_log("[ERR] 牌组文件读取失败: %s" % duel_path)
			push_error("Unable to load duel deck: %s" % duel_path)
			return
		deck_data = parsed_deck_data

	var raw_players: Array = deck_data.get("players", [])
	var deck_lists: Array = []
	var player_metadata: Array = []
	var ai_profiles: Array[String] = []
	for player_index in range(2):
		var raw_player: Dictionary = {}
		if player_index < raw_players.size():
			raw_player = raw_players[player_index]
		var master_id := str(raw_player.get("master_id", ""))
		var master_definition: Dictionary = _card_definitions.get(master_id, {})
		var master_hp := int(master_definition.get("hp", raw_player.get("master_hp", 20)))
		var master_max_hp := int(master_definition.get("max_hp", master_definition.get("hp", raw_player.get("master_max_hp", master_hp))))
		deck_lists.append(raw_player.get("deck", []).duplicate())
		player_metadata.append({
			"name": str(raw_player.get("name", "Player %d" % (player_index + 1))),
			"master_name": str(raw_player.get("master_name", "Master")),
			"master_id": master_id,
			"master_hp": master_hp,
			"master_max_hp": master_max_hp
		})
		ai_profiles.append(str(raw_player.get("ai_profile_id", "")))
	var resolved_seed := duel_seed
	if resolved_seed <= 0:
		resolved_seed = _make_duel_seed()
	_current_duel_path = duel_path
	_current_game_options = game_options.duplicate(true)
	_current_duel_label = duel_label
	_current_duel_seed = resolved_seed
	_duel_started_at = int(Time.get_unix_time_from_system())
	_history_saved = false
	if _ai_controller != null:
		_ai_controller.set_match_context({
			"deck_id": str(deck_data.get("id", "")),
			"match_seed": resolved_seed,
			"player_profiles": ai_profiles.duplicate(),
			"ai_policy_mode": _current_requested_ai_policy_mode(),
			"ai_use_llm": _ai_use_llm,
			"ai_prompt": _current_ai_prompt_text()
		})
	_append_file_log("[SETUP] 对局标签=%s 路径=%s 种子=%s" % [duel_label, duel_path, resolved_seed])
	_append_file_log("[SETUP] AI mode=%s use_llm=%s" % [_current_requested_ai_policy_mode(), str(_ai_use_llm)])
	_append_file_log("[SETUP] rules_md=%s ai_prompt_chars=%s" % [
		str(FileAccess.file_exists("res://规则/规则.md")),
		str(_current_ai_prompt_text().length())
	])
	_append_file_log("[SETUP] 准备 create_game")
	if _engine_card_definitions.is_empty():
		_append_file_log("[ERR] 规则定义加载失败")
		push_error("Unable to load card definitions for duel startup")
		_show_start_panel()
		return
	_state = _engine.create_game(_engine_card_definitions, deck_lists, resolved_seed, player_metadata, traced_game_options)
	_append_file_log("[SETUP] create_game 完成 state=%s" % [str(_state != null)])
	if _state != null:
		_append_file_log("[SETUP] create_game 后 phase=%s active=%s stack=%s pending_choices=%s pending_attack=%s" % [
			str(_state.phase),
			str(_state.active_player),
			str(_state.stack.size()),
			str(_state.pending_choices.size()),
			str(_state.pending_attack.size())
		])
	if _state != null and traced_game_options is Dictionary and traced_game_options.has("resume_commands"):
		var resume_commands = traced_game_options.get("resume_commands", [])
		var resume_index := int(traced_game_options.get("resume_command_index", resume_commands.size() if resume_commands is Array else 0))
		if resume_commands is Array:
			resume_index = clamp(resume_index, 0, resume_commands.size())
		if resume_commands is Array and resume_index > 0:
			_append_file_log("[RESUME] applying %s commands to reach index %s" % [str(resume_index), str(resume_index)])
			for i in range(resume_index):
				var row: Dictionary = resume_commands[i]
				var command = GameCommand.create(int(row.get("player_id", -1)), str(row.get("type", "")), row.get("payload", {}))
				command.command_id = str(row.get("command_id", command.command_id))
				command.client_time = int(row.get("client_time", command.client_time))
				command.source = str(row.get("source", command.source))
				var result = _engine.apply_command(_state, command)
				if not bool(result.get("ok", false)):
					_append_file_log("[RESUME ERR] command failed at %s" % str(i + 1))
					_network_terminal_message = "续战失败：重放到第 %s 步时执行命令失败。" % str(i + 1)
					_reset_battle_table(true, false, true)
					return
				var expected_before := str(row.get("state_hash_before", ""))
				var expected_after := str(row.get("state_hash_after", ""))
				if not expected_before.is_empty() and expected_before != str(result.get("state_hash_before", "")):
					_append_file_log("[RESUME ERR] hash mismatch before at %s" % str(i + 1))
					_network_terminal_message = "续战失败：重放到第 %s 步时状态校验失败。" % str(i + 1)
					_reset_battle_table(true, false, true)
					return
				if not expected_after.is_empty() and expected_after != str(result.get("state_hash_after", "")):
					_append_file_log("[RESUME ERR] hash mismatch after at %s" % str(i + 1))
					_network_terminal_message = "续战失败：重放到第 %s 步时状态校验失败。" % str(i + 1)
					_reset_battle_table(true, false, true)
					return
		if _network_mode_active:
			_network_command_index = resume_index
	_append_file_log("[SETUP] 准备 _sync_from_engine")
	_sync_from_engine()
	_hide_network_sync_overlay()
	_append_file_log("[SETUP] _sync_from_engine 完成")
	if _state == null:
		_show_start_panel()
		return
	_hide_start_panel()


func _show_start_panel() -> void:
	if _start_panel != null:
		_start_panel.visible = true
	if _busy_status_panel != null:
		_busy_status_panel.visible = false
	if _start_panel_title != null:
		_start_panel_title.text = "十二军团"
	if _start_panel_desc != null and _network_terminal_message.is_empty():
		if not _startup_ready:
			_start_panel_desc.text = "正在加载正式对局资源..."
			_set_start_panel_interactable(false)
			return
		if _network_mode_active and _network_is_host and (_network_session == null or not _network_session.has_remote_peer()):
			_start_panel_desc.text = "房间已创建，请让对方点击“加入房间”后输入房主地址连接。"
		else:
			_start_panel_desc.text = _default_start_panel_desc_text()
	_set_start_panel_interactable(true)
	_refresh_start_panel_network_buttons()
	if _disconnect_button != null:
		_disconnect_button.visible = _network_mode_active
	if _network_status_label != null and _network_terminal_message.is_empty():
		if _network_mode_active and _network_is_host and (_network_session == null or not _network_session.has_remote_peer()):
			_network_status_label.text = _host_waiting_status_text()
		elif not _network_mode_active:
			_network_status_label.text = "本地模式：可直接开始对局。\n联机模式需要在相同局域网环境。"
	_maybe_show_startup_notice()


func _hide_start_panel() -> void:
	if _start_panel != null:
		_start_panel.visible = false


func _refresh_start_panel_network_buttons() -> void:
	var host_active := _network_mode_active and _network_is_host
	if _host_duel_button != null:
		_host_duel_button.visible = not host_active
	if _join_duel_button != null:
		_join_duel_button.visible = not host_active
	if _disconnect_button != null:
		_disconnect_button.visible = _network_mode_active


func _set_start_panel_interactable(enabled: bool) -> void:
	if _start_duel_button != null:
		_start_duel_button.disabled = not enabled
	if _start_test_button != null:
		_start_test_button.disabled = not enabled
	if _host_duel_button != null:
		_host_duel_button.disabled = not enabled
	if _join_duel_button != null:
		_join_duel_button.disabled = not enabled
	if _deck_builder_button != null:
		_deck_builder_button.disabled = not enabled
	if _system_settings_button != null:
		_system_settings_button.disabled = not enabled


func _show_start_panel_loading(message: String) -> void:
	if _start_panel != null:
		_start_panel.visible = true
	if _busy_status_panel != null:
		_busy_status_panel.visible = false
	if _start_panel_title != null:
		_start_panel_title.text = "十二军团"
	if _start_panel_desc != null:
		_start_panel_desc.text = message
	if _network_status_label != null:
		_network_status_label.text = _network_terminal_message if not _network_terminal_message.is_empty() else "本地模式：可直接开始对局。\n联机模式需要在相同局域网环境。"
	_set_start_panel_interactable(false)


func _finish_startup_bootstrap() -> void:
	_load_card_definitions()
	_refresh_custom_background_from_selection()
	_startup_ready = not _card_definitions.is_empty()
	if _start_panel_desc != null and _network_terminal_message.is_empty():
		if _startup_ready:
			_start_panel_desc.text = _default_start_panel_desc_text()
		else:
			_start_panel_desc.text = "启动失败：未加载到正式对局资源。"
	_set_start_panel_interactable(_startup_ready)
	if _startup_ready and not OS.has_feature("android"):
		call_deferred("_prewarm_deck_builder")
	if _start_panel != null and _start_panel.visible:
		call_deferred("_show_start_panel")


func _default_start_panel_desc_text() -> String:
	if _card_definitions.is_empty():
		return START_PANEL_DEFAULT_DESC
	return "当前正式对局配置：\n%s" % DeckBuilderStore.build_selection_summary(_card_definitions)


func _open_deck_builder() -> void:
	if _deck_builder_view == null:
		return
	if not _startup_ready:
		return
	_ensure_deck_builder_ready()
	if _start_panel != null:
		_start_panel.visible = false
	_deck_builder_view.open_view()
	_deck_builder_view.move_to_front()


func _close_deck_builder() -> void:
	if _deck_builder_view == null:
		return
	_deck_builder_view.close_view()
	if _start_panel != null:
		_start_panel.visible = true
	if _start_panel != null and _start_panel.visible and _start_panel_desc != null and _network_terminal_message.is_empty():
		_start_panel_desc.text = _default_start_panel_desc_text()

func _open_match_history() -> void:
	_open_match_history_target("", -1)

func _open_match_history_target(record_id: String, command_index: int = -1) -> void:
	if _history_view == null:
		return
	if _start_panel != null:
		_start_panel.visible = false
	var can_network_resume := _network_mode_active and _network_is_host and _network_session != null and _network_session.has_remote_peer()
	_history_view.configure_network_resume_available(can_network_resume)
	if record_id.is_empty():
		_history_view.open_view()
	elif command_index >= 0:
		_history_view.open_view_with_record_and_step(record_id, command_index)
	else:
		_history_view.open_view_with_record(record_id)
	_history_view.move_to_front()

func _restore_history_after_resume_failure(options: Dictionary, command_index: int, message: String) -> void:
	_push_log(message)
	var record_id := str(options.get("history_record_id", ""))
	if not record_id.is_empty():
		_open_match_history_target(record_id, command_index)
		return
	_show_start_panel()

func _close_match_history() -> void:
	if _history_view == null:
		return
	_history_view.close_view()
	if _start_panel != null:
		_start_panel.visible = true
	if _start_panel != null and _start_panel.visible and _start_panel_desc != null and _network_terminal_message.is_empty():
		_start_panel_desc.text = _default_start_panel_desc_text()

func _on_history_resume_requested(replay_data: Dictionary, command_index: int, options: Dictionary) -> void:
	_close_match_history()
	if str(options.get("resume_kind", "local")) == "network":
		_start_network_resume_duel_from_replay(replay_data, command_index, options)
		return
	_start_resume_duel_from_replay(replay_data, command_index, options)

func _on_history_table_replay_requested(record_id: String, command_index: int) -> void:
	_close_match_history()
	_open_table_replay_mode(record_id, 0)

func _open_table_replay_mode(record_id: String, command_index: int) -> void:
	if not _startup_ready:
		_push_log("资源尚未加载完成，请稍候。")
		_open_match_history_target(record_id, command_index)
		return
	if _state != null and _start_panel != null and not _start_panel.visible:
		_push_log("请先结束当前对局，再打开牌桌回放。")
		_open_match_history_target(record_id, command_index)
		return
	if _history_store == null:
		_history_store = MatchHistoryStore.new()
	var replay_result = _history_store.get_replay_data(record_id)
	if not bool(replay_result.get("ok", false)):
		_push_log("打开牌桌回放失败：%s" % str(replay_result.get("message", "")))
		_open_match_history_target(record_id, command_index)
		return
	_table_replay_record_id = record_id
	_table_replay_data = {}
	_table_replay_active = true
	_table_replay_auto_playing = false
	_table_replay_speed_index = 0
	_table_replay_seek_dragging = false
	if _table_replay_timer != null:
		_table_replay_timer.stop()
	_reset_battle_table(false, false, false)
	_network_mode_active = false
	_network_is_host = false
	_local_player_id = PLAYER_BOTTOM
	_ai_mode = 0
	_ai_override_players.clear()
	if _ai_mode_option != null:
		_ai_mode_option.select(0)
	_ai_use_llm = false
	_apply_ai_policy_mode({
		"ai_policy_mode": _current_requested_ai_policy_mode(),
		"ai_use_llm": _ai_use_llm
	})
	_update_ai_mode_controls()
	if _zone_interaction_layer != null:
		_zone_interaction_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var replay_data: Dictionary = replay_result.get("data", {})
	_table_replay_data = replay_data.duplicate(true)
	_rebuild_table_replay_timeline()
	var load_result = _table_replay_session.load_replay_data(replay_data)
	if not bool(load_result.get("ok", false)):
		_push_log("打开牌桌回放失败：%s" % str(load_result.get("message", "")))
		_table_replay_active = false
		_reset_battle_table(false, false, true)
		_open_match_history_target(record_id, command_index)
		return
	var jump_result = _table_replay_session.jump_to_command(command_index)
	if not bool(jump_result.get("ok", false)):
		_push_log("打开牌桌回放失败：%s" % str(jump_result.get("message", "")))
		_table_replay_active = false
		_reset_battle_table(false, false, true)
		_open_match_history_target(record_id, command_index)
		return
	_apply_table_replay_result(jump_result.get("data", {}))
	_table_replay_overlay.visible = true
	_table_replay_overlay.move_to_front()

func _close_table_replay_mode() -> void:
	var return_command_index := _table_replay_session.get_current_command_index()
	_stop_table_replay_auto_play()
	_table_replay_active = false
	_table_replay_data = {}
	_clear_table_replay_timeline()
	_table_replay_seek_dragging = false
	if _table_replay_overlay != null:
		_table_replay_overlay.visible = false
	if _zone_interaction_layer != null:
		_zone_interaction_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_battle_table(false, false, true)
	if _history_view != null and not _table_replay_record_id.is_empty():
		_open_match_history_target(_table_replay_record_id, return_command_index)
	else:
		_open_match_history_target("", -1)
	_table_replay_record_id = ""

func _apply_table_replay_result(data: Dictionary) -> void:
	_engine = data.get("engine", _engine)
	_state = data.get("state", null)
	_sync_from_engine()
	_refresh()
	_update_table_replay_controls(int(data.get("command_index", 0)))

func _update_table_replay_controls(command_index: int) -> void:
	_update_table_replay_overlay_layout()
	var total_steps := _table_replay_session.get_total_command_count()
	if _table_replay_step_label != null:
		_table_replay_step_label.text = "牌桌回放 %s / %s" % [command_index, total_steps]
	if _table_replay_prev_button != null:
		_table_replay_prev_button.disabled = command_index <= 0
	if _table_replay_next_button != null:
		_table_replay_next_button.disabled = command_index >= total_steps
	if _table_replay_last_button != null:
		_table_replay_last_button.disabled = total_steps <= 0
	_update_table_replay_seek_controls(command_index, total_steps)
	_update_table_replay_timeline_selection(command_index)
	_update_table_replay_timeline_hint(command_index)

func _update_table_replay_overlay_layout() -> void:
	if _table_replay_panel == null:
		return
	var panel_width: float = clamp(size.x - 32.0, 560.0, 640.0)
	var panel_height: float = 72.0
	_table_replay_panel.size = Vector2(panel_width, panel_height)
	_table_replay_panel.position = Vector2((size.x - panel_width) * 0.5, size.y - panel_height - 18.0)

func _update_table_replay_seek_controls(command_index: int, total_steps: int) -> void:
	if _table_replay_seek_label != null:
		_table_replay_seek_label.text = "进度 %s/%s" % [command_index, total_steps]
	if _table_replay_seek_slider != null:
		_table_replay_seek_internal_update = true
		_table_replay_seek_slider.min_value = 0
		_table_replay_seek_slider.max_value = total_steps
		_table_replay_seek_slider.step = 1
		_table_replay_seek_slider.value = command_index
		_table_replay_seek_slider.editable = total_steps > 0
		_table_replay_seek_internal_update = false

func _rebuild_table_replay_timeline() -> void:
	_clear_table_replay_timeline()
	if _table_replay_timeline_box == null:
		return
	var start_button := _make_button("00. 对局开始")
	start_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(func(): _jump_table_replay_to_command(0))
	_table_replay_timeline_box.add_child(start_button)
	_table_replay_timeline_buttons[0] = start_button
	var commands = _table_replay_data.get("commands", [])
	if not (commands is Array):
		return
	for row in commands:
		if not (row is Dictionary):
			continue
		var command_index := int(row.get("index", 0))
		var button := _make_button(_table_replay_command_line(row))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): _jump_table_replay_to_command(command_index))
		_table_replay_timeline_box.add_child(button)
		_table_replay_timeline_buttons[command_index] = button

func _clear_table_replay_timeline() -> void:
	_table_replay_timeline_buttons.clear()
	if _table_replay_timeline_box == null:
		return
	for child in _table_replay_timeline_box.get_children():
		_table_replay_timeline_box.remove_child(child)
		child.queue_free()

func _jump_table_replay_to_command(command_index: int) -> void:
	_stop_table_replay_auto_play()
	var result = _table_replay_session.jump_to_command(command_index)
	if bool(result.get("ok", false)):
		_apply_table_replay_result(result.get("data", {}))

func _on_table_replay_restart_pressed() -> void:
	if _table_replay_data.is_empty():
		return
	_table_replay_restart_replay_data = _table_replay_data.duplicate(true)
	_table_replay_restart_command_index = _table_replay_session.get_current_command_index()
	_table_replay_restart_record_id = _table_replay_record_id
	if _table_replay_restart_mode_option != null:
		_table_replay_restart_mode_option.selected = 0
	if _table_replay_restart_dialog != null:
		_table_replay_restart_dialog.dialog_text = "将从当前回放节点重新开始一局。"
		_table_replay_restart_dialog.popup_centered()

func _on_table_replay_restart_confirmed() -> void:
	if _table_replay_restart_replay_data.is_empty():
		return
	var replay_data := _table_replay_restart_replay_data.duplicate(true)
	var command_index := _table_replay_restart_command_index
	var ai_mode := int(_table_replay_restart_mode_option.get_selected_id()) if _table_replay_restart_mode_option != null else 0
	var options := {
		"resume_kind": "local",
		"network_host_player_id": 0,
		"ai_mode": ai_mode,
		"ai_use_llm": false,
		"ai_players": [PLAYER_TOP] if ai_mode == 1 else [],
		"history_record_id": _table_replay_restart_record_id,
		"history_replay_id": str(replay_data.get("metadata", {}).get("replay_id", ""))
	}
	_stop_table_replay_auto_play()
	_table_replay_active = false
	_table_replay_data = {}
	_clear_table_replay_timeline()
	_table_replay_seek_dragging = false
	if _table_replay_overlay != null:
		_table_replay_overlay.visible = false
	if _zone_interaction_layer != null:
		_zone_interaction_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_table_replay_record_id = ""
	_table_replay_restart_replay_data = {}
	_start_resume_duel_from_replay(replay_data, command_index, options)

func _update_table_replay_timeline_selection(command_index: int) -> void:
	for raw_index in _table_replay_timeline_buttons.keys():
		var button: Button = _table_replay_timeline_buttons.get(raw_index, null)
		if button == null:
			continue
		_set_table_replay_timeline_button_selected(button, int(raw_index) == command_index)
	var current_button: Button = _table_replay_timeline_buttons.get(command_index, null)
	if current_button != null and _table_replay_timeline_scroll != null:
		_table_replay_timeline_scroll.ensure_control_visible(current_button)

func _set_table_replay_timeline_button_selected(button: Button, selected: bool) -> void:
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
	if selected:
		normal.bg_color = Color(0.13, 0.24, 0.34, 0.95)
		normal.border_color = Color(0.62, 0.93, 1.0, 1.0)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.28, 0.38, 0.98) if selected else Color(0.12, 0.16, 0.20, 0.92)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal.duplicate())

func _update_table_replay_timeline_hint(command_index: int) -> void:
	if _table_replay_timeline_hint == null:
		return
	var public_view: Dictionary = _table_replay_session.get_current_public_view()
	var turn_number := int(public_view.get("turn_number", 0))
	var phase_name := _phase_display_text(str(public_view.get("phase", "")))
	var turn_start_index := _find_table_replay_turn_start_index(turn_number)
	var lines: Array[String] = [
		"当前步骤：%s / %s" % [command_index, _table_replay_session.get_total_command_count()],
		"当前回合：%s" % turn_number,
		"本回合起点：%s" % max(turn_start_index, 0),
		"当前阶段：%s" % phase_name,
		"播放速度：%s" % _table_replay_speed_text()
	]
	var row: Dictionary = _table_replay_session.get_current_command_row()
	if row.is_empty():
		lines.append("")
		lines.append("当前处于对局开始状态。")
	else:
		lines.append("")
		lines.append("最近操作：%s" % _table_replay_command_line(row))
		lines.append("说明：可在下方步骤列表中直接跳到任意步骤。")
	_table_replay_timeline_hint.text = "\n".join(lines)

func _table_replay_command_line(row: Dictionary) -> String:
	var command_index := int(row.get("index", 0))
	var player_id := int(row.get("player_id", -1))
	var command_type := str(row.get("type", ""))
	var payload: Dictionary = row.get("payload", {})
	var phase_before := _phase_display_text(str(row.get("phase_before", "")))
	var phase_after := _phase_display_text(str(row.get("phase_after", "")))
	var phase_text := ""
	if phase_before != "-" or phase_after != "-":
		phase_text = " [%s]" % phase_after if phase_before == phase_after else " [%s -> %s]" % [phase_before, phase_after]
	return "%02d. %s：%s%s" % [command_index, _table_replay_player_name(player_id), _table_replay_command_summary(command_type, payload), phase_text]

func _table_replay_player_name(player_id: int) -> String:
	var setup_players = _table_replay_data.get("setup", {}).get("players", [])
	if setup_players is Array and player_id >= 0 and player_id < setup_players.size():
		var player: Dictionary = setup_players[player_id] if setup_players[player_id] is Dictionary else {}
		var master_id := str(player.get("master_id", ""))
		var master_name := str(player.get("master_name", ""))
		if master_name.is_empty() and not master_id.is_empty():
			master_name = str(_card_definitions.get(master_id, {}).get("name", master_id))
		if not master_name.is_empty():
			return "玩家%s（%s）" % [player_id + 1, master_name]
	return "玩家%s" % (player_id + 1)

func _table_replay_command_summary(command_type: String, payload: Dictionary) -> String:
	match command_type:
		"PlayCard":
			var card_name := _table_replay_card_name(str(payload.get("card_id", "")))
			var row_name := _table_replay_row_name(str(payload.get("row", "")))
			var col := int(payload.get("col", -1))
			return "打出 %s 到 %s" % [card_name, row_name if col < 0 else "%s%s号位" % [row_name, col + 1]]
		"MoveLegion":
			var moved_name := _table_replay_card_name(str(payload.get("card_id", "")))
			var move_row := _table_replay_row_name(str(payload.get("row", "")))
			var move_col := int(payload.get("col", -1))
			return "移动 %s 到 %s" % [moved_name, move_row if move_col < 0 else "%s%s号位" % [move_row, move_col + 1]]
		"DeclareAttack":
			var attacker_name := _table_replay_card_name(str(payload.get("card_id", payload.get("attacker_id", ""))))
			if str(payload.get("target_kind", "")) == "master":
				return "%s 攻击 %s 主宰" % [attacker_name, _table_replay_player_name(int(payload.get("target_player", -1)))]
			return "%s 攻击 %s" % [attacker_name, _table_replay_card_name(str(payload.get("target_card_id", "")))]
		"ChooseDefense":
			var blocker_id := str(payload.get("card_id", payload.get("blocker_id", "")))
			return "选择 %s 进行防御" % _table_replay_card_name(blocker_id)
		"ActivateEffect":
			var source_name := _table_replay_card_name(str(payload.get("card_id", payload.get("source_id", ""))))
			return "发动 %s 的效果" % source_name
		"ResolveChoice":
			return _table_replay_resolve_choice_summary(payload)
		"EndPhase":
			return "结束当前阶段"
		"PassPriority":
			return "让过优先权"
	return command_type if not command_type.is_empty() else "未知操作"

func _table_replay_resolve_choice_summary(payload: Dictionary) -> String:
	var choice_type := str(payload.get("choice_type", ""))
	match choice_type:
		"option_pick":
			var option_id := str(payload.get("option_id", payload.get("selected_option", "")))
			return "作出选项选择%s" % ("" if option_id.is_empty() else "（%s）" % option_id)
		"candidate_cards_pick":
			var cards = payload.get("card_ids", payload.get("selected_card_ids", []))
			if cards is Array and not cards.is_empty():
				var names: Array[String] = []
				for card_id in cards:
					names.append(_table_replay_card_name(str(card_id)))
				return "选择卡牌：%s" % "、".join(names)
	return "处理选择"

func _table_replay_card_name(card_id: String) -> String:
	if card_id.is_empty():
		return "-"
	var direct_definition: Dictionary = _card_definitions.get(card_id, {})
	if not direct_definition.is_empty():
		return str(direct_definition.get("name", card_id))
	var state = _table_replay_session.get_current_state()
	if state != null:
		var instance = state.card_instances.get(card_id, null)
		if instance != null:
			var definition_id := str(instance.definition_id)
			if not definition_id.is_empty():
				return str(_card_definitions.get(definition_id, {}).get("name", definition_id))
	return card_id

func _table_replay_row_name(row: String) -> String:
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

func _find_table_replay_turn_start_index(target_turn: int) -> int:
	if target_turn <= 1:
		return 0
	var commands = _table_replay_data.get("commands", [])
	if not (commands is Array):
		return -1
	for row in commands:
		if not (row is Dictionary):
			continue
		if int(row.get("turn_after", row.get("turn_before", 0))) == target_turn:
			return int(row.get("index", -1))
	return -1

func _find_table_replay_previous_turn_index(command_index: int) -> int:
	var public_view: Dictionary = _table_replay_session.get_current_public_view()
	var current_turn := int(public_view.get("turn_number", 1))
	for target_turn in range(current_turn - 1, 0, -1):
		var turn_index := _find_table_replay_turn_start_index(target_turn)
		if turn_index >= 0 and turn_index != command_index:
			return turn_index
	return -1

func _find_table_replay_next_turn_index(command_index: int) -> int:
	var public_view: Dictionary = _table_replay_session.get_current_public_view()
	var current_turn := int(public_view.get("turn_number", 1))
	var commands = _table_replay_data.get("commands", [])
	if not (commands is Array):
		return -1
	for target_turn in range(current_turn + 1, commands.size() + 2):
		var turn_index := _find_table_replay_turn_start_index(target_turn)
		if turn_index > command_index:
			return turn_index
		if turn_index == -1:
			break
	return -1

func _on_table_replay_speed_pressed() -> void:
	if _table_replay_speed_options.is_empty():
		return
	_table_replay_speed_index = (_table_replay_speed_index + 1) % _table_replay_speed_options.size()
	_update_table_replay_speed_button()
	_update_table_replay_timeline_hint(_table_replay_session.get_current_command_index())

func _update_table_replay_speed_button() -> void:
	if _table_replay_timer != null:
		_table_replay_timer.wait_time = 0.65 / float(_table_replay_speed_options[_table_replay_speed_index])
	if _table_replay_speed_button != null:
		_table_replay_speed_button.text = _table_replay_speed_text()

func _table_replay_speed_text() -> String:
	if _table_replay_speed_options.is_empty():
		return "1.0x"
	return "%.1fx" % float(_table_replay_speed_options[_table_replay_speed_index])

func _on_table_replay_first_pressed() -> void:
	_stop_table_replay_auto_play()
	var result = _table_replay_session.jump_to_start()
	if bool(result.get("ok", false)):
		_apply_table_replay_result(result.get("data", {}))

func _on_table_replay_prev_pressed() -> void:
	_stop_table_replay_auto_play()
	var before_index := _table_replay_session.get_current_command_index()
	var result = _table_replay_session.step_backward()
	if bool(result.get("ok", false)):
		_apply_table_replay_result(result.get("data", {}))
		if _table_replay_session.get_current_command_index() == before_index and before_index > 0:
			var message := "牌桌回放未能返回上一步。"
			_push_log(message)
			if _table_replay_timeline_hint != null:
				_table_replay_timeline_hint.text = message
	else:
		var error_message := "牌桌回放上一步失败：%s" % str(result.get("message", result.get("code", "UNKNOWN")))
		_push_log(error_message)
		if _table_replay_timeline_hint != null:
			_table_replay_timeline_hint.text = error_message

func _on_table_replay_prev_turn_pressed() -> void:
	var turn_index := _find_table_replay_previous_turn_index(_table_replay_session.get_current_command_index())
	if turn_index >= 0:
		_jump_table_replay_to_command(turn_index)

func _on_table_replay_next_pressed() -> void:
	_stop_table_replay_auto_play()
	var before_index := _table_replay_session.get_current_command_index()
	var result = _table_replay_session.step_forward()
	if bool(result.get("ok", false)):
		_apply_table_replay_result(result.get("data", {}))
		if _table_replay_session.get_current_command_index() == before_index and before_index < _table_replay_session.get_total_command_count():
			var message := "牌桌回放未能推进到下一步。"
			_push_log(message)
			if _table_replay_timeline_hint != null:
				_table_replay_timeline_hint.text = message
	else:
		var error_message := "牌桌回放下一步失败：%s" % str(result.get("message", result.get("code", "UNKNOWN")))
		_push_log(error_message)
		if _table_replay_timeline_hint != null:
			_table_replay_timeline_hint.text = error_message

func _on_table_replay_next_turn_pressed() -> void:
	var turn_index := _find_table_replay_next_turn_index(_table_replay_session.get_current_command_index())
	if turn_index >= 0:
		_jump_table_replay_to_command(turn_index)

func _on_table_replay_last_pressed() -> void:
	_stop_table_replay_auto_play()
	var result = _table_replay_session.jump_to_end()
	if bool(result.get("ok", false)):
		_apply_table_replay_result(result.get("data", {}))

func _on_table_replay_play_pressed() -> void:
	if _table_replay_auto_playing:
		_stop_table_replay_auto_play()
		_update_table_replay_controls(_table_replay_session.get_current_command_index())
		return
	if _table_replay_session.get_current_command_index() >= _table_replay_session.get_total_command_count():
		return
	_table_replay_auto_playing = true
	if _table_replay_timer != null:
		_table_replay_timer.start()
	if _table_replay_play_button != null:
		_table_replay_play_button.text = "暂停"

func _on_table_replay_timer_timeout() -> void:
	if not _table_replay_auto_playing:
		return
	var result = _table_replay_session.step_forward()
	if not bool(result.get("ok", false)):
		_stop_table_replay_auto_play()
		return
	_apply_table_replay_result(result.get("data", {}))
	if _table_replay_session.get_current_command_index() >= _table_replay_session.get_total_command_count():
		_stop_table_replay_auto_play()
		_update_table_replay_controls(_table_replay_session.get_current_command_index())

func _stop_table_replay_auto_play() -> void:
	_table_replay_auto_playing = false
	if _table_replay_timer != null:
		_table_replay_timer.stop()
	if _table_replay_play_button != null:
		_table_replay_play_button.text = "播放"

func _on_table_replay_seek_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			_table_replay_seek_dragging = true
			_stop_table_replay_auto_play()
		else:
			_table_replay_seek_dragging = false

func _on_table_replay_seek_value_changed(value: float) -> void:
	if _table_replay_seek_internal_update:
		return
	if _table_replay_seek_label != null:
		_table_replay_seek_label.text = "进度 %s/%s" % [int(value), _table_replay_session.get_total_command_count()]

func _on_table_replay_seek_drag_ended(value_changed: bool) -> void:
	if _table_replay_seek_internal_update:
		return
	if not value_changed or _table_replay_seek_slider == null:
		return
	_jump_table_replay_to_command(int(_table_replay_seek_slider.value))

func _start_resume_duel_from_replay(replay_data: Dictionary, command_index: int, options: Dictionary) -> void:
	if not _startup_ready:
		_restore_history_after_resume_failure(options, command_index, "资源尚未加载完成，请稍候。")
		return
	var normalized = ReplayIO.normalize_replay_data(replay_data)
	if normalized.is_empty():
		_restore_history_after_resume_failure(options, command_index, "继续对局失败：回放数据无效。")
		return
	var setup: Dictionary = normalized.get("setup", {})
	var players = setup.get("players", [])
	if not (players is Array) or players.size() < 2:
		_restore_history_after_resume_failure(options, command_index, "继续对局失败：回放玩家数据不完整。")
		return
	var commands = normalized.get("commands", [])
	if not (commands is Array):
		_restore_history_after_resume_failure(options, command_index, "继续对局失败：回放命令列表无效。")
		return
	if command_index < 0 or command_index > commands.size():
		_restore_history_after_resume_failure(options, command_index, "继续对局失败：节点超出范围。")
		return
	var ai_mode := int(options.get("ai_mode", 0))
	_reset_battle_table(false, true, false)
	_ai_mode = ai_mode
	if _ai_mode_option != null:
		_ai_mode_option.select(ai_mode)
	_ai_override_players.clear()
	var ai_players = options.get("ai_players", [])
	if ai_players is Array and not ai_players.is_empty():
		for player_id in ai_players:
			_ai_override_players.append(int(player_id))
	elif ai_mode == 2:
		_ai_override_players = [PLAYER_BOTTOM, PLAYER_TOP]
	_ai_use_llm = bool(options.get("ai_use_llm", false))
	_apply_ai_policy_mode({
		"ai_policy_mode": _current_requested_ai_policy_mode(),
		"ai_use_llm": _ai_use_llm
	})
	_update_ai_mode_controls()
	_network_mode_active = false
	_network_is_host = false
	_local_player_id = PLAYER_BOTTOM
	var duel_label := "续战对局"
	var duel_path := "history_resume"
	_initialize_duel_log(duel_label, duel_path)
	var game_options: Dictionary = setup.get("game_options", {})
	if not (game_options is Dictionary):
		game_options = {}
	game_options = game_options.duplicate(true)
	game_options["mode"] = "resume_local" if ai_mode == 0 else "resume_ai"
	game_options["source_record_id"] = str(options.get("history_replay_id", normalized.get("metadata", {}).get("replay_id", "")))
	game_options["source_command_index"] = command_index
	_current_duel_path = duel_path
	_current_game_options = game_options.duplicate(true)
	_current_duel_label = duel_label
	_current_duel_seed = int(setup.get("seed", 1))
	_duel_started_at = int(Time.get_unix_time_from_system())
	_history_saved = false
	var traced_game_options := game_options.duplicate(true)
	if not _duel_log_path.is_empty():
		traced_game_options["debug_trace_path"] = _duel_log_path
	var inline_duel_data = traced_game_options.get("inline_duel_data", null)
	if inline_duel_data != null and inline_duel_data is Dictionary:
		inline_duel_data["mode"] = "resume_local"
	var deck_lists: Array = []
	var player_metadata: Array = []
	for player_index in range(2):
		var player_row: Dictionary = players[player_index] if players[player_index] is Dictionary else {}
		var master_id := str(player_row.get("master_id", ""))
		var master_definition: Dictionary = _card_definitions.get(master_id, {})
		var master_hp := int(master_definition.get("hp", int(player_row.get("master_hp", 20))))
		var master_max_hp := int(master_definition.get("max_hp", master_definition.get("hp", int(player_row.get("master_max_hp", master_hp)))))
		var deck_cards = player_row.get("deck_cards", [])
		deck_lists.append(deck_cards.duplicate() if deck_cards is Array else [])
		player_metadata.append({
			"name": str(player_row.get("name", "Player %d" % (player_index + 1))),
			"master_name": str(player_row.get("master_name", "Master")),
			"master_id": master_id,
			"master_hp": master_hp,
			"master_max_hp": master_max_hp
		})
	if _engine_card_definitions.is_empty():
		_append_file_log("[ERR] 规则定义加载失败")
		push_error("Unable to load card definitions for resume duel startup")
		_open_match_history_target(str(options.get("history_record_id", "")), command_index)
		return
	_engine = GameEngine.new()
	_state = _engine.create_game(_engine_card_definitions, deck_lists, _current_duel_seed, player_metadata, traced_game_options)
	if _state == null:
		_restore_history_after_resume_failure(options, command_index, "继续对局失败：无法创建对局。")
		return
	for i in range(command_index):
		var row: Dictionary = commands[i]
		var command = GameCommand.create(int(row.get("player_id", -1)), str(row.get("type", "")), row.get("payload", {}))
		command.command_id = str(row.get("command_id", command.command_id))
		command.client_time = int(row.get("client_time", command.client_time))
		command.source = str(row.get("source", command.source))
		var result = _engine.apply_command(_state, command)
		if not bool(result.get("ok", false)):
			_restore_history_after_resume_failure(options, command_index, "继续对局失败：重放到该节点时执行命令失败。")
			return
		var expected_before := str(row.get("state_hash_before", ""))
		var expected_after := str(row.get("state_hash_after", ""))
		if not expected_before.is_empty() and expected_before != str(result.get("state_hash_before", "")):
			_restore_history_after_resume_failure(options, command_index, "继续对局失败：重放校验失败。")
			return
		if not expected_after.is_empty() and expected_after != str(result.get("state_hash_after", "")):
			_restore_history_after_resume_failure(options, command_index, "继续对局失败：重放校验失败。")
			return
	_sync_from_engine()
	_hide_start_panel()

func _start_network_resume_duel_from_replay(replay_data: Dictionary, command_index: int, options: Dictionary) -> void:
	if not _network_mode_active or not _network_is_host or _network_session == null or not _network_session.has_remote_peer():
		_restore_history_after_resume_failure(options, command_index, "联机继续对局失败：当前不是已连接的房主状态。")
		return
	var normalized = ReplayIO.normalize_replay_data(replay_data)
	if normalized.is_empty():
		_restore_history_after_resume_failure(options, command_index, "联机继续对局失败：回放数据无效。")
		return
	var setup: Dictionary = normalized.get("setup", {})
	var players = setup.get("players", [])
	if not (players is Array) or players.size() < 2:
		_restore_history_after_resume_failure(options, command_index, "联机继续对局失败：回放玩家数据不完整。")
		return
	var commands = normalized.get("commands", [])
	if not (commands is Array):
		_restore_history_after_resume_failure(options, command_index, "联机继续对局失败：回放命令列表无效。")
		return
	if command_index < 0 or command_index > commands.size():
		_restore_history_after_resume_failure(options, command_index, "联机继续对局失败：节点超出范围。")
		return
	var deck_players: Array = []
	for i in range(2):
		var player_row: Dictionary = players[i] if players[i] is Dictionary else {}
		deck_players.append({
			"name": str(player_row.get("name", "Player %d" % (i + 1))),
			"master_name": str(player_row.get("master_name", "Master")),
			"master_id": str(player_row.get("master_id", "")),
			"deck": player_row.get("deck_cards", []).duplicate() if player_row.get("deck_cards", null) is Array else []
		})
	var inline_duel_data := {
		"id": "history_resume_network",
		"players": deck_players
	}
	var ai_mode := int(options.get("ai_mode", 0))
	var ai_use_llm := bool(options.get("ai_use_llm", false))
	var ai_players = options.get("ai_players", [])
	var host_player_id := int(options.get("network_host_player_id", PLAYER_BOTTOM))
	_local_player_id = host_player_id
	var game_options: Dictionary = setup.get("game_options", {})
	if not (game_options is Dictionary):
		game_options = {}
	game_options = game_options.duplicate(true)
	game_options["mode"] = "resume"
	game_options["inline_duel_data"] = inline_duel_data
	game_options["resume_commands"] = commands.slice(0, command_index)
	game_options["resume_command_index"] = command_index
	game_options["ai_mode"] = ai_mode
	game_options["ai_use_llm"] = ai_use_llm
	game_options["ai_players"] = ai_players.duplicate() if ai_players is Array else []
	game_options["source_record_id"] = str(options.get("history_replay_id", normalized.get("metadata", {}).get("replay_id", "")))
	game_options["source_command_index"] = command_index
	game_options["network_host_player_id"] = host_player_id
	var duel_seed := int(setup.get("seed", 1))
	var duel_label := "联机续战"
	_pending_start_duel_seed = duel_seed
	_network_session.broadcast_start_duel("history_resume_network", game_options, duel_label, duel_seed)
	_deferred_start_duel("history_resume_network", game_options, duel_label, duel_seed)


func _on_deck_builder_changed(_message: String) -> void:
	if _start_panel != null and _start_panel.visible and _start_panel_desc != null and _network_terminal_message.is_empty():
		_start_panel_desc.text = _default_start_panel_desc_text()
	_broadcast_local_formal_deck_selection()


func _ensure_deck_builder_ready() -> void:
	if _deck_builder_initialized or _deck_builder_view == null:
		return
	_deck_builder_view.setup(_card_definitions)
	_deck_builder_initialized = true


func _prewarm_deck_builder() -> void:
	if not _startup_ready:
		return
	_ensure_deck_builder_ready()
	if _deck_builder_view != null:
		_deck_builder_view.start_background_prewarm()


func _resolve_formal_duel_setup() -> Dictionary:
	var generated := {}
	if _network_mode_active and _network_is_host:
		generated = DeckBuilderStore.build_network_formal_duel(_card_definitions, FORMAL_DECK_PATH, _network_remote_formal_deck_selection)
	else:
		generated = DeckBuilderStore.build_local_formal_duel(_card_definitions, FORMAL_DECK_PATH)
	if not bool(generated.get("ok", false)):
		return generated
	var duel_path := str(generated.get("duel_path", FORMAL_DECK_PATH))
	var options := FORMAL_GAME_OPTIONS.duplicate(true)
	var duel_data = generated.get("duel_data", {})
	if duel_data is Dictionary and not duel_data.is_empty():
		options["inline_duel_data"] = duel_data.duplicate(true)
	return {
		"ok": true,
		"duel_path": duel_path,
		"game_options": options,
		"summary": str(generated.get("summary", ""))
	}


func _resolve_test_duel_setup() -> Dictionary:
	var generated = DeckBuilderStore.build_local_test_duel(_card_definitions, TEST_DECK_PATH)
	if not bool(generated.get("ok", false)):
		return generated
	var duel_path := str(generated.get("duel_path", TEST_DECK_PATH))
	var options := TEST_GAME_OPTIONS.duplicate(true)
	var duel_data = generated.get("duel_data", {})
	if duel_data is Dictionary and not duel_data.is_empty():
		options["inline_duel_data"] = duel_data.duplicate(true)
	return {
		"ok": true,
		"duel_path": duel_path,
		"game_options": options,
		"summary": str(generated.get("summary", ""))
	}


func _show_game_result_dialog(winner_logical_player: int) -> void:
	if _game_result_overlay == null or _game_result_panel == null:
		return
	var local_logical_player := _logical_player_for_display(PLAYER_BOTTOM)
	var is_victory := winner_logical_player == local_logical_player
	var winner_display_player := _display_player_for_logical(winner_logical_player)
	var winner_name := "玩家"
	if winner_display_player >= 0 and winner_display_player < _players.size():
		winner_name = str(_players[winner_display_player].get("name", "玩家"))
	_game_result_overlay.visible = true
	_game_result_overlay.modulate = Color(1, 1, 1, 0)
	_game_result_panel.scale = Vector2(0.92, 0.92)
	_game_result_panel.modulate = Color(1, 1, 1, 0.0)
	_game_result_badge.text = "对局结束"
	_game_result_title.text = "胜利" if is_victory else "失败"
	_game_result_desc.text = "%s%s。\n点击确认后返回主页面，可重新开始下一局。" % [
		winner_name,
		"赢下了这场对局" if is_victory else "取得了本局胜利"
	]
	var badge_normal := StyleBoxFlat.new()
	badge_normal.bg_color = Color(0.72, 0.56, 0.16, 0.32) if is_victory else Color(0.46, 0.18, 0.18, 0.36)
	badge_normal.border_color = Color(0.98, 0.86, 0.45, 0.88) if is_victory else Color(1.0, 0.55, 0.55, 0.88)
	badge_normal.border_width_left = 1
	badge_normal.border_width_top = 1
	badge_normal.border_width_right = 1
	badge_normal.border_width_bottom = 1
	badge_normal.corner_radius_top_left = 16
	badge_normal.corner_radius_top_right = 16
	badge_normal.corner_radius_bottom_left = 16
	badge_normal.corner_radius_bottom_right = 16
	_game_result_badge.add_theme_stylebox_override("normal", badge_normal)
	_game_result_badge.add_theme_stylebox_override("disabled", badge_normal)
	_game_result_badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	_game_result_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.52, 1.0) if is_victory else Color(1.0, 0.56, 0.56, 1.0))
	_game_result_desc.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.96))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	panel_style.border_color = Color(0.98, 0.86, 0.45, 0.92) if is_victory else Color(1.0, 0.48, 0.48, 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 8)
	_game_result_panel.add_theme_stylebox_override("panel", panel_style)
	var tween := create_tween()
	tween.tween_property(_game_result_overlay, "modulate", Color(1, 1, 1, 1), 0.18)
	tween.parallel().tween_property(_game_result_panel, "modulate", Color(1, 1, 1, 1), 0.18)
	tween.parallel().tween_property(_game_result_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_game_result_dialog() -> void:
	if _game_result_overlay == null:
		return
	_game_result_overlay.visible = false

func _show_network_sync_overlay(text: String) -> void:
	if _network_sync_overlay == null:
		return
	_network_sync_message = text
	_network_sync_overlay.visible = true
	_refresh_network_sync_overlay_text()
	_network_sync_overlay.move_to_front()

func _hide_network_sync_overlay() -> void:
	if _network_sync_overlay == null:
		return
	_network_sync_overlay.visible = false
	_network_sync_message = ""


func _loading_frame_text() -> String:
	if _hud_loading_frames.is_empty():
		return "..."
	return str(_hud_loading_frames[_hud_loading_frame % _hud_loading_frames.size()])


func _loading_badge_text() -> String:
	var frame := _loading_frame_text().strip_edges()
	if frame.is_empty():
		return ""
	return "[%s]" % frame


func _refresh_network_sync_overlay_text() -> void:
	if _network_sync_overlay == null or not _network_sync_overlay.visible or _network_sync_label == null:
		return
	var base_text := _network_sync_message.strip_edges()
	if base_text.is_empty():
		base_text = "正在同步联机状态..."
	var badge := _loading_badge_text()
	_network_sync_label.text = "%s %s" % [badge, base_text] if not badge.is_empty() else base_text


func _refresh_opening_waiting_overlay_text() -> void:
	if _opening_overlay == null or not _opening_overlay.visible:
		return
	var prompt := _opening_overlay_prompt.duplicate(true)
	if prompt.is_empty():
		return
	var title_text := str(prompt.get("title", "开局准备"))
	var description_text := str(prompt.get("description", ""))
	var status_text := str(prompt.get("status_text", ""))
	if str(prompt.get("choice_type", "")) == "waiting":
		var badge := _loading_badge_text()
		if not badge.is_empty():
			title_text = "%s %s" % [badge, title_text]
	if _opening_overlay_title != null:
		_opening_overlay_title.text = title_text
	if _opening_overlay_desc != null:
		_opening_overlay_desc.text = description_text
	if _opening_overlay_status != null:
		_opening_overlay_status.text = status_text


func _current_busy_status_snapshot() -> Dictionary:
	if _start_panel != null and _start_panel.visible:
		return {}
	if _network_sync_overlay != null and _network_sync_overlay.visible:
		return {}
	if _is_opening_status_active():
		return {}
	if _state == null or _game_over:
		return {}
	if _network_input_locked():
		return {
			"title": "正在同步本次操作",
			"detail": "命令已发送，正在等待联机确认，请稍候。"
		}
	var waiting_player := _waiting_display_player()
	if waiting_player < 0 or _is_locally_controllable_player(waiting_player):
		return {}
	var actor_text := _player_side_name(waiting_player)
	var detail_text := _top_status_detail_text()
	if detail_text.is_empty():
		detail_text = "当前轮到%s在%s行动" % [actor_text, _phase_display_text(str(_state.phase))]
	var title_text := "%s正在行动" % actor_text
	if not _state.pending_choices.is_empty():
		title_text = "%s正在处理选择" % actor_text
	elif not _state.pending_attack.is_empty():
		title_text = "%s正在响应攻击" % actor_text
	elif not _state.stack.is_empty():
		title_text = "%s正在响应效果" % actor_text
	elif _ai_enabled_for_player(waiting_player):
		title_text = "%s正在思考" % actor_text
	if waiting_player == _ai_async_waiting_player and _is_ai_async_in_flight():
		var runtime_mode_text := "快速模式：少重试、低输出、优先响应"
		if _selected_llm_runtime_mode() == "stable":
			runtime_mode_text = "稳定模式：保留重试、容错更强、速度更慢"
		title_text = "%s正在请求大模型" % actor_text
		detail_text = "正在后台等待模型返回。\n%s" % runtime_mode_text
	return {
		"title": title_text,
		"detail": detail_text
	}


func _refresh_busy_status_panel() -> void:
	if _busy_status_panel == null:
		return
	var snapshot := _current_busy_status_snapshot()
	if snapshot.is_empty():
		_busy_status_panel.visible = false
		return
	if _busy_status_spinner != null:
		_busy_status_spinner.text = _loading_frame_text()
	if _busy_status_title != null:
		_busy_status_title.text = str(snapshot.get("title", "对方正在操作"))
	if _busy_status_detail != null:
		_busy_status_detail.text = str(snapshot.get("detail", ""))
	var panel_width := clampf(size.x - 32.0, 280.0, 560.0)
	var top_offset := 44.0
	if _turn_label != null and _turn_label.visible:
		top_offset = _turn_label.offset_bottom + 8.0
	_busy_status_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_busy_status_panel.size = Vector2(panel_width, max(68.0, _busy_status_panel.get_combined_minimum_size().y))
	_busy_status_panel.position = Vector2((size.x - panel_width) * 0.5, top_offset)
	_busy_status_panel.visible = true


func _make_opening_rng(base_seed: int, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(hash([base_seed, salt])))
	return rng


func _shuffle_string_array(source: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var result := source.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		if swap_index == index:
			continue
		var buffer: String = result[index]
		result[index] = result[swap_index]
		result[swap_index] = buffer
	return result


func _opening_card_view(definition_id: String, selection_id: String = "") -> Dictionary:
	var definition: Dictionary = _card_definitions.get(definition_id, {
		"id": definition_id,
		"name": definition_id,
		"type": "legion",
		"cost": 0,
		"power": 0,
		"hp": 0,
		"text": ""
	}).duplicate(true)
	var resolved_selection_id := selection_id if not selection_id.is_empty() else definition_id
	return {
		"uid": resolved_selection_id,
		"definition_id": definition_id,
		"definition": definition,
		"owner": PLAYER_BOTTOM,
		"zone": "opening",
		"face": "face_up",
		"orientation": "active",
		"current_hp": int(definition.get("hp", definition.get("power", 0))),
		"current_cost": int(definition.get("cost", 0))
	}


func _opening_hand_slot_id(player_id: int, hand_index: int, definition_id: String) -> String:
	return "opening_slot_%s_%s_%s" % [str(player_id), str(hand_index), definition_id]


func _opening_prompt_card_entries(prompt: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var raw_entries = prompt.get("card_entries", [])
	if raw_entries is Array and not raw_entries.is_empty():
		for raw_entry in raw_entries:
			if not (raw_entry is Dictionary):
				continue
			var selection_id := str(raw_entry.get("selection_id", raw_entry.get("uid", "")))
			var card_id := str(raw_entry.get("card_id", raw_entry.get("definition_id", selection_id)))
			if selection_id.is_empty() or card_id.is_empty():
				continue
			entries.append({
				"selection_id": selection_id,
				"card_id": card_id
			})
		return entries
	var raw_cards = prompt.get("card_ids", [])
	if raw_cards is Array:
		for raw_id in raw_cards:
			var card_id := str(raw_id)
			if card_id.is_empty():
				continue
			entries.append({
				"selection_id": card_id,
				"card_id": card_id
			})
	return entries


func _opening_player_label(player_id: int) -> String:
	if player_id == PLAYER_BOTTOM:
		return "先手方" if _network_mode_active else "玩家"
	return "后手方" if _network_mode_active else "对手"


func _clear_opening_overlay_actions() -> void:
	if _opening_overlay_cards != null:
		_clear_children(_opening_overlay_cards)
	if _opening_overlay_action_box != null:
		_clear_children(_opening_overlay_action_box)
	_opening_overlay_selected_ids.clear()
	_opening_overlay_selected_option = ""


func _mulligan_waiting_prompt(source_prompt: Dictionary, waiting_actor_player_id: int, selected_count: int, total_count: int) -> Dictionary:
	var count_text := ""
	if total_count > 0:
		count_text = "%s/%s" % [str(selected_count), str(total_count)]
	else:
		count_text = str(selected_count)
	return _opening_waiting_prompt_for_actor(
		source_prompt,
		waiting_actor_player_id,
		"我方已完成",
		"我方已提交调度：%s 张。" % count_text
	)


func _refresh_opening_overlay_layout(prompt: Dictionary = {}) -> void:
	if _opening_overlay_panel == null or _opening_overlay_scroll == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var choice_type := str(prompt.get("choice_type", ""))
	var panel_width: float = clampf(viewport_size.x - 48.0, 320.0, 720.0)
	var body_height: float = 120.0
	var preferred_columns: int = 1
	var max_columns: int = 1
	if choice_type == "card_pick":
		var card_count: int = 0
		var raw_cards = prompt.get("card_ids", [])
		if raw_cards is Array:
			card_count = raw_cards.size()
		preferred_columns = max(1, int(prompt.get("columns", 4)))
		var usable_width: float = max(180.0, panel_width - 84.0)
		max_columns = max(1, int(floor((usable_width + 10.0) / 140.0)))
		var resolved_columns: int = max(1, min(preferred_columns, max_columns, max(1, card_count)))
		var row_count: int = max(1, int(ceil(float(card_count) / float(resolved_columns))))
		panel_width = clampf(float(resolved_columns) * 130.0 + float(max(0, resolved_columns - 1)) * 10.0 + 96.0, 360.0, min(viewport_size.x - 48.0, 760.0))
		body_height = clampf(float(row_count) * 182.0 + float(max(0, row_count - 1)) * 10.0 + 8.0, 140.0, min(viewport_size.y - 250.0, 420.0))
		if _opening_overlay_cards != null:
			_opening_overlay_cards.columns = resolved_columns
	else:
		var option_count: int = 0
		var raw_options = prompt.get("options", [])
		if raw_options is Array:
			option_count = raw_options.size()
		panel_width = clampf(min(viewport_size.x - 48.0, 620.0), 320.0, 620.0)
		body_height = clampf(24.0 + float(max(1, option_count)) * 56.0, 88.0, min(viewport_size.y - 280.0, 180.0))
	_opening_overlay_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_opening_overlay_scroll.custom_minimum_size = Vector2(0.0, body_height)


func _show_opening_overlay(prompt: Dictionary) -> void:
	var same_prompt := str(_opening_overlay_prompt.get("prompt_id", "")) == str(prompt.get("prompt_id", ""))
	var previous_selected_ids: Array[String] = []
	if same_prompt:
		previous_selected_ids = _opening_overlay_selected_ids.duplicate()
	var previous_selected_option := _opening_overlay_selected_option if same_prompt else ""
	_opening_overlay_prompt = prompt.duplicate(true)
	_clear_opening_overlay_actions()
	_opening_overlay_selected_ids = previous_selected_ids
	_opening_overlay_selected_option = previous_selected_option
	if _opening_overlay == null:
		return
	_opening_overlay.visible = true
	_opening_overlay.move_to_front()
	_refresh_opening_waiting_overlay_text()
	var choice_type := str(prompt.get("choice_type", ""))
	if _opening_overlay_confirm_button != null:
		_opening_overlay_confirm_button.text = str(prompt.get("confirm_text", "确认"))
		_opening_overlay_confirm_button.visible = choice_type == "card_pick"
	_opening_overlay_cancel_button.visible = bool(prompt.get("allow_cancel", false))
	var action_row := _opening_overlay_confirm_button.get_parent() if _opening_overlay_confirm_button != null else null
	if action_row is Control:
		action_row.visible = _opening_overlay_confirm_button.visible or _opening_overlay_cancel_button.visible
	_refresh_opening_overlay_layout(prompt)
	if choice_type == "option_pick":
		for option in prompt.get("options", []):
			if not (option is Dictionary):
				continue
			var option_id := str(option.get("id", ""))
			var button := _make_button(str(option.get("label", option_id)))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0, 46)
			_style_settings_button(button, bool(option.get("accent", false)))
			button.pressed.connect(func() -> void:
				_opening_overlay_selected_option = option_id
				_on_opening_overlay_confirm_pressed()
			)
			if _opening_overlay_action_box != null:
				_opening_overlay_action_box.add_child(button)
	elif choice_type == "card_pick":
		if _opening_overlay_cards != null:
			for entry in _opening_prompt_card_entries(prompt):
				var definition_id := str(entry.get("card_id", ""))
				var selection_id := str(entry.get("selection_id", definition_id))
				var card_view: Control = BattleCardScript.new()
				card_view.custom_minimum_size = Vector2(130.0, 182.0)
				card_view.size = Vector2(130.0, 182.0)
				card_view.set_use_overlay_long_press_preview(true)
				card_view.setup(_opening_card_view(definition_id, selection_id), false, _opening_overlay_selected_ids.has(selection_id), false)
				card_view.card_clicked.connect(_on_opening_overlay_card_clicked)
				card_view.long_press_preview_requested.connect(_show_overlay_card_preview)
				card_view.long_press_preview_finished.connect(_hide_overlay_card_preview)
				_opening_overlay_cards.add_child(card_view)


func _hide_opening_overlay() -> void:
	_opening_overlay_prompt.clear()
	_clear_opening_overlay_actions()
	_hide_overlay_card_preview()
	if _opening_overlay != null:
		_opening_overlay.visible = false


func _on_opening_overlay_card_clicked(card: Control) -> void:
	var required_count := int(_opening_overlay_prompt.get("count", 1))
	var max_count := int(_opening_overlay_prompt.get("max_count", max(1, required_count)))
	var selected_id := str(card.card_data.get("uid", ""))
	if selected_id.is_empty():
		return
	if required_count == 1 and max_count <= 1:
		if _opening_overlay_selected_ids.size() == 1 and _opening_overlay_selected_ids[0] == selected_id:
			_opening_overlay_selected_ids.clear()
		else:
			_opening_overlay_selected_ids = [selected_id]
	else:
		if _opening_overlay_selected_ids.has(selected_id):
			_opening_overlay_selected_ids.erase(selected_id)
		elif _opening_overlay_selected_ids.size() < max_count:
			_opening_overlay_selected_ids.append(selected_id)
	_show_opening_overlay(_opening_overlay_prompt)


func _on_opening_overlay_confirm_pressed() -> void:
	if _opening_overlay_prompt.is_empty():
		return
	var choice_type := str(_opening_overlay_prompt.get("choice_type", ""))
	var payload := {
		"prompt_id": str(_opening_overlay_prompt.get("prompt_id", "")),
		"stage": str(_opening_overlay_prompt.get("stage", "")),
	}
	if choice_type == "option_pick":
		if _opening_overlay_selected_option.is_empty():
			return
		payload["selected_option"] = _opening_overlay_selected_option
	elif choice_type == "card_pick":
		var required_count := int(_opening_overlay_prompt.get("count", 1))
		var min_count: int = max(0, required_count)
		if required_count < 0:
			min_count = int(_opening_overlay_prompt.get("min_count", 0))
		if _opening_overlay_selected_ids.size() < min_count:
			return
		payload["selected_card_ids"] = _opening_overlay_selected_ids.duplicate()
	_submit_opening_prompt_response(payload)


func _on_opening_overlay_cancel_pressed() -> void:
	if _opening_overlay_prompt.is_empty():
		_hide_opening_overlay()
		return
	if bool(_opening_overlay_prompt.get("allow_cancel", false)):
		_reset_battle_table(false, false, true)


func _submit_opening_prompt_response(payload: Dictionary) -> void:
	var current_prompt := _opening_overlay_prompt.duplicate(true)
	var actor_player_id := int(_opening_overlay_prompt.get("actor_player_id", PLAYER_BOTTOM))
	var stage := str(_opening_overlay_prompt.get("stage", ""))
	var total_count: int = 0
	var raw_cards = _opening_overlay_prompt.get("card_ids", [])
	if raw_cards is Array:
		total_count = raw_cards.size()
	_hide_opening_overlay()
	if _network_mode_active and not _network_is_host:
		_network_session.submit_opening_response(payload)
		if stage.begins_with("mulligan_"):
			var selected_ids = payload.get("selected_card_ids", [])
			var selected_count: int = 0
			if selected_ids is Array:
				selected_count = selected_ids.size()
			var waiting_prompt := _mulligan_waiting_prompt(current_prompt, 1 - actor_player_id, selected_count, total_count)
			_set_active_opening_prompt(waiting_prompt)
			_show_opening_overlay(waiting_prompt)
		return
	_handle_opening_prompt_response(actor_player_id, payload)


func _load_duel_data_for_start(duel_path: String, game_options: Dictionary) -> Dictionary:
	var inline_duel_data = game_options.get("inline_duel_data", null)
	if inline_duel_data is Dictionary:
		return inline_duel_data.duplicate(true)
	var deck_text := FileAccess.get_file_as_string(duel_path)
	var parsed_deck_data = JSON.parse_string(deck_text)
	return parsed_deck_data.duplicate(true) if parsed_deck_data is Dictionary else {}


func _resolved_opening_calamity_pool() -> Array[String]:
	var result: Array[String] = []
	for definition_id in _card_definitions.keys():
		var candidate_id := str(definition_id)
		if candidate_id == "sys_calamity_annihilation":
			continue
		var definition: Dictionary = _card_definitions.get(candidate_id, {})
		if str(definition.get("type", "")) != "calamity":
			continue
		result.append(candidate_id)
	result.sort()
	return result


func _build_formal_opening_session(duel_path: String, game_options: Dictionary, duel_label: String, duel_seed: int) -> Dictionary:
	var duel_data := _load_duel_data_for_start(duel_path, game_options)
	if duel_data.is_empty():
		return {}
	var raw_players: Array = duel_data.get("players", [])
	var deck_lists: Array = []
	var player_metadata: Array = []
	for player_index in range(2):
		var raw_player: Dictionary = raw_players[player_index] if player_index < raw_players.size() and raw_players[player_index] is Dictionary else {}
		var player_deck: Array[String] = []
		var raw_deck = raw_player.get("deck", [])
		if raw_deck is Array:
			for raw_card_id in raw_deck:
				player_deck.append(str(raw_card_id))
		deck_lists.append(player_deck)
		player_metadata.append({
			"name": str(raw_player.get("name", "Player %d" % (player_index + 1))),
			"master_name": str(raw_player.get("master_name", "Master")),
			"master_id": str(raw_player.get("master_id", ""))
		})
	var starting_decider := PLAYER_BOTTOM
	if _network_mode_active:
		var decider_rng := _make_opening_rng(duel_seed, "starting_decider")
		starting_decider = decider_rng.randi_range(PLAYER_BOTTOM, PLAYER_TOP)
	var shuffled_decks: Array = []
	for player_index in range(2):
		var player_rng := _make_opening_rng(duel_seed, "deck_shuffle_%s" % player_index)
		shuffled_decks.append(_shuffle_string_array(deck_lists[player_index], player_rng))
	var session := {
		"duel_path": duel_path,
		"duel_label": duel_label,
		"duel_seed": duel_seed,
		"duel_data": duel_data.duplicate(true),
		"base_game_options": game_options.duplicate(true),
		"deck_lists": deck_lists.duplicate(true),
		"player_metadata": player_metadata.duplicate(true),
		"battle_mode": _battle_mode,
		"starting_decider_player_id": starting_decider,
		"starting_player_id": -1,
		"base_shuffled_decks": shuffled_decks.duplicate(true),
		"shuffled_decks": shuffled_decks,
		"initial_hands": [
			shuffled_decks[0].slice(0, min(6, shuffled_decks[0].size())),
			shuffled_decks[1].slice(0, min(6, shuffled_decks[1].size()))
		],
		"final_player_deck_orders": {},
		"opening_setup_choices": [{}, {}],
		"calamity_pool": _resolved_opening_calamity_pool(),
		"banned_calamities": [],
		"revealed_calamity": "",
		"chosen_calamities": [],
		"offered_calamities": {},
		"active_prompt": {},
		"prompt_serial": 0
	}
	return session


func _opening_player_has_deck_definition(player_id: int, definition_id: String) -> bool:
	var deck_lists: Array = _opening_session.get("deck_lists", [])
	if player_id < 0 or player_id >= deck_lists.size():
		return false
	var raw_deck = deck_lists[player_id]
	if not (raw_deck is Array):
		return false
	for raw_id in raw_deck:
		if str(raw_id) == definition_id:
			return true
	return false


func _opening_player_has_master_definition(player_id: int, master_id: String) -> bool:
	var metadata: Array = _opening_session.get("player_metadata", [])
	if player_id < 0 or player_id >= metadata.size():
		return false
	var player_meta: Dictionary = metadata[player_id] if metadata[player_id] is Dictionary else {}
	return str(player_meta.get("master_id", "")) == master_id


func _opening_player_special_setup_capabilities(player_id: int) -> Dictionary:
	return {
		"andvaranot": _opening_player_has_deck_definition(player_id, "asgard_s02_0305"),
		"thor_hammer": _opening_player_has_master_definition(player_id, "asgard_s02_03m1") \
			and _opening_player_has_deck_definition(player_id, "asgard_s02_0301")
	}


func _opening_player_special_setup_choice(player_id: int) -> Dictionary:
	var raw_choices = _opening_session.get("opening_setup_choices", [])
	if not (raw_choices is Array) or player_id < 0 or player_id >= raw_choices.size():
		return {}
	return raw_choices[player_id] if raw_choices[player_id] is Dictionary else {}


func _set_opening_player_special_setup_choice(player_id: int, choice: Dictionary) -> void:
	var raw_choices = _opening_session.get("opening_setup_choices", [])
	var choices: Array = raw_choices.duplicate(true) if raw_choices is Array else [{}, {}]
	while choices.size() <= player_id:
		choices.append({})
	choices[player_id] = choice.duplicate(true)
	_opening_session["opening_setup_choices"] = choices


func _opening_player_uses_andvaranot_setup(player_id: int) -> bool:
	return bool(_opening_player_special_setup_choice(player_id).get("andvaranot_to_artifact", false))


func _opening_player_uses_thor_hammer_setup(player_id: int) -> bool:
	return bool(_opening_player_special_setup_choice(player_id).get("thor_add_hammer_to_hand", false))


func _rebuild_opening_special_setup_state_for_player(player_id: int) -> void:
	var raw_base_decks = _opening_session.get("base_shuffled_decks", [])
	if not (raw_base_decks is Array) or player_id < 0 or player_id >= raw_base_decks.size():
		return
	var base_deck: Array[String] = []
	var raw_base_deck = raw_base_decks[player_id]
	if raw_base_deck is Array:
		for raw_id in raw_base_deck:
			base_deck.append(str(raw_id))
	var effective_deck: Array[String] = base_deck.duplicate()
	var base_game_options: Dictionary = _opening_session.get("base_game_options", {})
	var opening_hand_size := int(base_game_options.get("opening_hand_size", 6))
	if _opening_player_uses_andvaranot_setup(player_id):
		effective_deck.erase("asgard_s02_0305")
		opening_hand_size = min(opening_hand_size, 4)
	var reserved_hand: Array[String] = []
	if _opening_player_uses_thor_hammer_setup(player_id):
		effective_deck.erase("asgard_s02_0301")
		reserved_hand.append("asgard_s02_0301")
	var draw_count: int = min(max(0, opening_hand_size - reserved_hand.size()), effective_deck.size())
	var initial_hand: Array[String] = reserved_hand.duplicate()
	initial_hand.append_array(effective_deck.slice(0, draw_count))
	var effective_order: Array[String] = initial_hand.duplicate()
	effective_order.append_array(effective_deck.slice(draw_count, effective_deck.size()))
	var raw_effective_decks = _opening_session.get("shuffled_decks", [])
	var effective_decks: Array = raw_effective_decks.duplicate(true) if raw_effective_decks is Array else [[], []]
	while effective_decks.size() <= player_id:
		effective_decks.append([])
	effective_decks[player_id] = effective_order
	_opening_session["shuffled_decks"] = effective_decks
	var raw_initial_hands = _opening_session.get("initial_hands", [])
	var initial_hands: Array = raw_initial_hands.duplicate(true) if raw_initial_hands is Array else [[], []]
	while initial_hands.size() <= player_id:
		initial_hands.append([])
	initial_hands[player_id] = initial_hand
	_opening_session["initial_hands"] = initial_hands


func _rebuild_opening_special_setup_state() -> void:
	for player_id in [PLAYER_BOTTOM, PLAYER_TOP]:
		_rebuild_opening_special_setup_state_for_player(player_id)


func _opening_special_setup_prompt(player_id: int) -> Dictionary:
	var capabilities := _opening_player_special_setup_capabilities(player_id)
	var can_andvaranot := bool(capabilities.get("andvaranot", false))
	var can_thor_hammer := bool(capabilities.get("thor_hammer", false))
	if not can_andvaranot and not can_thor_hammer:
		return {}
	var choice := _opening_player_special_setup_choice(player_id)
	if (not can_andvaranot or choice.has("andvaranot_to_artifact")) \
			and (not can_thor_hammer or choice.has("thor_add_hammer_to_hand")):
		return {}
	var options: Array[Dictionary] = [
		{"id": "normal_opening", "label": "正常开局", "accent": true}
	]
	var status_parts: Array[String] = []
	if can_andvaranot:
		status_parts.append("可改为将安德华拉诺特从牌库置入圣物区，起始手牌改为4张。")
	if can_thor_hammer:
		status_parts.append("可改为将1张雷神之锤加入起始手牌，其视为1张起始手牌。")
	if can_andvaranot and can_thor_hammer:
		options.append({"id": "andvaranot_only", "label": "置入安德华拉诺特", "accent": false})
		options.append({"id": "thor_hammer_only", "label": "只拿雷神之锤", "accent": false})
		options.append({"id": "andvaranot_and_thor_hammer", "label": "置入安德华拉诺特同时拿雷神之锤", "accent": false})
	elif can_andvaranot:
		options.append({"id": "andvaranot_only", "label": "置入安德华拉诺特", "accent": false})
	else:
		options.append({"id": "thor_hammer_only", "label": "拿雷神之锤", "accent": false})
	var status_text := "\n".join(status_parts)
	if status_text.is_empty():
		status_text = "可选择是否启用额外开局效果。"
	return {
		"prompt_id": _next_opening_prompt_id(),
		"stage": "opening_special_setup_%s" % player_id,
		"choice_type": "option_pick",
		"actor_player_id": player_id,
		"title": "起手额外规则",
		"description": "%s可选择是否启用以下开局效果。" % _opening_player_label(player_id),
		"status_text": status_text,
		"options": options
	}


func _opening_restore_setup_cards_to_deck_order(player_id: int, effective_final_deck: Array[String]) -> Array[String]:
	var result := effective_final_deck.duplicate()
	if _opening_player_uses_thor_hammer_setup(player_id):
		result.append("asgard_s02_0301")
	if _opening_player_uses_andvaranot_setup(player_id):
		result.append("asgard_s02_0305")
	return result


func _is_opening_ai_actor(player_id: int) -> bool:
	return not _network_mode_active and _ai_enabled_for_player(player_id)


func _is_opening_local_actor(player_id: int) -> bool:
	if _network_mode_active:
		return player_id == _local_player_id
	return not _is_opening_ai_actor(player_id)


func _set_active_opening_prompt(prompt: Dictionary) -> void:
	if _opening_session.is_empty():
		_opening_session = {}
	_opening_session["active_prompt"] = prompt.duplicate(true) if not prompt.is_empty() else {}
	if not prompt.is_empty():
		_hide_start_panel()
	_refresh_hud()


func _opening_prompt_candidates(prompt: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if str(prompt.get("choice_type", "")) == "option_pick":
		for option in prompt.get("options", []):
			if not (option is Dictionary):
				continue
			var option_id := str(option.get("id", ""))
			if option_id.is_empty():
				continue
			candidates.append({
				"candidate_id": option_id,
				"description": str(option.get("label", option_id)),
				"selected_option": option_id
			})
		return candidates
	match str(prompt.get("stage", "")):
		"mulligan_0", "mulligan_1":
			var hand_entries := _opening_prompt_card_entries(prompt)
			var hand_count := hand_entries.size()
			var max_mask := 1 << hand_entries.size()
			for mask in range(max_mask):
				var selected_ids: Array[String] = []
				var parts: Array[String] = []
				for bit in range(hand_entries.size()):
					if (mask & (1 << bit)) == 0:
						continue
					var hand_entry: Dictionary = hand_entries[bit]
					var selection_id := str(hand_entry.get("selection_id", ""))
					var card_id := str(hand_entry.get("card_id", ""))
					selected_ids.append(selection_id)
					parts.append(_card_name(card_id))
				var candidate_id := "keep_all" if selected_ids.is_empty() else "replace_%s" % "_".join(selected_ids)
				var description := "不调度，保留当前 %s 张起手。" % hand_count if selected_ids.is_empty() else "调度 %s。" % "、".join(parts)
				candidates.append({
					"candidate_id": candidate_id,
					"description": description,
					"selected_card_ids": selected_ids
				})
		_:
			for entry in _opening_prompt_card_entries(prompt):
				var definition_id := str(entry.get("card_id", ""))
				var selection_id := str(entry.get("selection_id", definition_id))
				candidates.append({
					"candidate_id": selection_id,
					"description": "%s：%s" % [_card_name(definition_id), _opening_card_reason(definition_id)],
					"selected_card_ids": [selection_id]
				})
	return candidates


func _opening_card_reason(definition_id: String) -> String:
	var definition: Dictionary = _card_definitions.get(definition_id, {})
	var parts: Array[String] = []
	var card_type := str(definition.get("type", "")).strip_edges()
	if not card_type.is_empty():
		parts.append(card_type)
	var cost := int(definition.get("cost", -1))
	if cost >= 0:
		parts.append("费用 %s" % cost)
	var power := int(definition.get("power", 0))
	if power > 0:
		parts.append("战力 %s" % power)
	var hp := int(definition.get("hp", 0))
	if hp > 0:
		parts.append("生命 %s" % hp)
	var text := str(definition.get("text", "")).strip_edges()
	if not text.is_empty():
		parts.append(text)
	return "；".join(parts)


func _opening_llm_conversation_messages(prompt: Dictionary, player_id: int) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	messages.append({
		"role": "system",
		"content": "\n".join([
			"你在为《十二军团》的开局准备阶段做决策。",
			"你只能从给定 candidates 里选择一个 candidate_id。",
			"优先考虑先后手节奏、起手曲线、天灾威胁与后续资源展开。"
		])
	})
	var ai_prompt := _current_ai_prompt_text()
	if not ai_prompt.is_empty():
		messages.append({
			"role": "user",
			"content": JSON.stringify({
				"kind": "ai_prompt",
				"content": ai_prompt
			})
		})
	messages.append({
		"role": "user",
		"content": JSON.stringify({
			"kind": "opening_context",
			"player_id": player_id,
			"player_label": _opening_player_label(player_id),
			"battle_mode": str(_opening_session.get("battle_mode", BATTLE_MODE_QUICK)),
			"stage": str(prompt.get("stage", "")),
			"title": str(prompt.get("title", "")),
			"description": str(prompt.get("description", "")),
			"status_text": str(prompt.get("status_text", "")),
			"revealed_calamity": str(_opening_session.get("revealed_calamity", "")),
			"banned_calamities": _opening_session.get("banned_calamities", []),
			"chosen_calamities": _opening_session.get("chosen_calamities", [])
		})
	})
	return messages


func _choose_opening_with_llm(player_id: int, prompt: Dictionary) -> Dictionary:
	var runtime_options := _decorate_game_options_with_ai_mode(_opening_session.get("base_game_options", {}))
	var llm_client = null
	if _ai_controller != null and _ai_controller.has_method("get_llm_client"):
		llm_client = _ai_controller.get_llm_client()
	if llm_client == null:
		llm_client = _build_runtime_llm_client(runtime_options)
	if llm_client == null or not llm_client.has_method("choose_candidate"):
		return {}
	var property_list: Array = []
	if llm_client != null and llm_client.has_method("get_property_list"):
		property_list = llm_client.get_property_list()
	var has_timeout_seconds := false
	var has_max_retries := false
	var has_retry_delay_ms := false
	for prop in property_list:
		if not (prop is Dictionary):
			continue
		var prop_name := str(prop.get("name", ""))
		if prop_name == "timeout_seconds":
			has_timeout_seconds = true
		elif prop_name == "max_retries":
			has_max_retries = true
		elif prop_name == "retry_delay_ms":
			has_retry_delay_ms = true
	var previous_timeout_seconds := 0.0
	var previous_max_retries := 0
	var previous_retry_delay_ms := 0
	if has_timeout_seconds:
		previous_timeout_seconds = float(llm_client.timeout_seconds)
		llm_client.timeout_seconds = min(float(llm_client.timeout_seconds), 5.0)
	if has_max_retries:
		previous_max_retries = int(llm_client.max_retries)
		llm_client.max_retries = 0
	if has_retry_delay_ms:
		previous_retry_delay_ms = int(llm_client.retry_delay_ms)
		llm_client.retry_delay_ms = 0
	var candidates := _opening_prompt_candidates(prompt)
	if candidates.is_empty():
		if has_timeout_seconds:
			llm_client.timeout_seconds = previous_timeout_seconds
		if has_max_retries:
			llm_client.max_retries = previous_max_retries
		if has_retry_delay_ms:
			llm_client.retry_delay_ms = previous_retry_delay_ms
		return {}
	var request := {
		"task": "choose_one_candidate",
		"observation": {
			"phase": "opening_setup",
			"stage": str(prompt.get("stage", "")),
			"title": str(prompt.get("title", "")),
			"description": str(prompt.get("description", "")),
			"status_text": str(prompt.get("status_text", "")),
			"player_id": player_id,
			"player_label": _opening_player_label(player_id),
			"battle_mode": str(_opening_session.get("battle_mode", BATTLE_MODE_QUICK))
		},
		"candidates": candidates.duplicate(true),
		"output_schema": {
			"candidate_id": "string",
			"confidence": "number",
			"brief_reason": "string"
		},
		"meta": {
			"player_id": player_id,
			"candidate_count": candidates.size(),
			"waiting_state": {"state": "OpeningPrompt", "stage": str(prompt.get("stage", ""))}
		},
		"conversation_messages": _opening_llm_conversation_messages(prompt, player_id)
	}
	var llm_response = llm_client.choose_candidate(request)
	if has_timeout_seconds:
		llm_client.timeout_seconds = previous_timeout_seconds
	if has_max_retries:
		llm_client.max_retries = previous_max_retries
	if has_retry_delay_ms:
		llm_client.retry_delay_ms = previous_retry_delay_ms
	if llm_response is Dictionary and llm_response.has("error"):
		print("[OPENING LLM] stage=%s player=%s error=%s" % [str(prompt.get("stage", "")), str(player_id), str(llm_response.get("error", ""))])
		_append_file_log("[OPENING LLM] stage=%s player=%s error=%s" % [str(prompt.get("stage", "")), str(player_id), str(llm_response.get("error", ""))])
		return {}
	var selected_candidate_id := str((llm_response as Dictionary).get("candidate_id", "")) if llm_response is Dictionary else ""
	if selected_candidate_id.is_empty():
		print("[OPENING LLM] stage=%s player=%s missing_candidate_id" % [str(prompt.get("stage", "")), str(player_id)])
		_append_file_log("[OPENING LLM] stage=%s player=%s missing_candidate_id" % [str(prompt.get("stage", "")), str(player_id)])
		return {}
	for candidate in candidates:
		if str(candidate.get("candidate_id", "")) != selected_candidate_id:
			continue
		var payload := {
			"prompt_id": str(prompt.get("prompt_id", "")),
			"stage": str(prompt.get("stage", "")),
		}
		if candidate.has("selected_option"):
			payload["selected_option"] = str(candidate.get("selected_option", ""))
		if candidate.has("selected_card_ids"):
			payload["selected_card_ids"] = candidate.get("selected_card_ids", []).duplicate(true)
		print("[OPENING LLM] stage=%s player=%s candidate_id=%s reason=%s" % [
			str(prompt.get("stage", "")),
			str(player_id),
			selected_candidate_id,
			str((llm_response as Dictionary).get("brief_reason", "")) if llm_response is Dictionary else ""
		])
		_append_file_log("[OPENING LLM] stage=%s player=%s candidate_id=%s reason=%s" % [
			str(prompt.get("stage", "")),
			str(player_id),
			selected_candidate_id,
			str((llm_response as Dictionary).get("brief_reason", "")) if llm_response is Dictionary else ""
		])
		return payload
	print("[OPENING LLM] stage=%s player=%s candidate_not_found=%s" % [str(prompt.get("stage", "")), str(player_id), selected_candidate_id])
	_append_file_log("[OPENING LLM] stage=%s player=%s candidate_not_found=%s" % [str(prompt.get("stage", "")), str(player_id), selected_candidate_id])
	return {}


func _next_opening_prompt_id() -> String:
	var next_serial := int(_opening_session.get("prompt_serial", 0)) + 1
	_opening_session["prompt_serial"] = next_serial
	return "opening_%03d" % next_serial


func _waiting_opening_prompt(title: String, description: String) -> Dictionary:
	return {
		"prompt_id": _next_opening_prompt_id(),
		"stage": "waiting",
		"choice_type": "waiting",
		"title": title,
		"description": description,
		"status_text": "等待另一方完成当前开局步骤。"
	}


func _opening_waiting_actor_text(waiting_actor_player_id: int) -> String:
	var actor_display := _display_player_for_logical(waiting_actor_player_id) if waiting_actor_player_id >= 0 else -1
	var actor_text := ""
	if actor_display >= 0:
		actor_text = _player_side_label(actor_display)
	elif _network_mode_active:
		actor_text = "对方"
	else:
		actor_text = "对方" if waiting_actor_player_id != _local_player_id else "我方"
	if _is_opening_ai_actor(waiting_actor_player_id):
		actor_text += "（大模型AI）" if _ai_use_llm else "（脚本型人机）"
	return actor_text if not actor_text.is_empty() else "对方"


func _opening_waiting_prompt_for_actor(prompt: Dictionary, waiting_actor_player_id: int, submitted_hint: String = "", extra_status: String = "") -> Dictionary:
	var stage := str(prompt.get("stage", ""))
	var title := str(prompt.get("title", "开局准备"))
	var stage_text := _opening_stage_status_label(stage, title)
	var actor_text := _opening_waiting_actor_text(waiting_actor_player_id)
	var normalized_hint := _single_line_status_text(submitted_hint).trim_suffix("。").trim_suffix("...").trim_suffix("…")
	var status_parts: Array[String] = []
	if not extra_status.is_empty():
		status_parts.append(extra_status)
	var prompt_status := _single_line_status_text(str(prompt.get("status_text", "")))
	if not prompt_status.is_empty():
		status_parts.append(prompt_status)
	if status_parts.is_empty():
		status_parts.append("等待另一方完成当前开局步骤。")
	var description := "等待%s完成%s..." % [actor_text, stage_text]
	if not normalized_hint.is_empty():
		description = "%s，等待%s完成%s..." % [normalized_hint, actor_text, stage_text]
	return {
		"prompt_id": str(prompt.get("prompt_id", "")) if not str(prompt.get("prompt_id", "")).is_empty() else _next_opening_prompt_id(),
		"stage": stage,
		"choice_type": "waiting",
		"actor_player_id": waiting_actor_player_id,
		"title": title,
		"description": description,
		"status_text": " ".join(status_parts)
	}


func _dispatch_opening_prompt(actor_player_id: int, prompt: Dictionary, remote_waiting_prompt: Dictionary = {}) -> void:
	var local_completed_hint := ""
	if int(_opening_session.get("last_completed_opening_actor", -1)) == _local_player_id:
		local_completed_hint = "我方已完成"
	if _network_mode_active and _network_is_host:
		if actor_player_id == _local_player_id:
			_set_active_opening_prompt(prompt)
			_show_opening_overlay(prompt)
			if _network_session != null:
				_network_session.send_opening_prompt(remote_waiting_prompt if not remote_waiting_prompt.is_empty() else _opening_waiting_prompt_for_actor(prompt, actor_player_id))
			return
		var waiting_prompt := _opening_waiting_prompt_for_actor(prompt, actor_player_id, local_completed_hint)
		_set_active_opening_prompt(waiting_prompt)
		_show_opening_overlay(waiting_prompt)
		if _network_session != null:
			_network_session.send_opening_prompt(prompt)
		return
	if _is_opening_ai_actor(actor_player_id):
		var waiting_prompt := _opening_waiting_prompt_for_actor(prompt, actor_player_id, local_completed_hint)
		_set_active_opening_prompt(waiting_prompt)
		_show_opening_overlay(waiting_prompt)
		_refresh()
		call_deferred("_begin_opening_ai_prompt_after_ui_tick", actor_player_id, prompt.duplicate(true))
		return
	_set_active_opening_prompt(prompt)
	_show_opening_overlay(prompt)


func _begin_opening_ai_prompt_after_ui_tick(actor_player_id: int, prompt: Dictionary) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.06).timeout
	_resolve_opening_ai_prompt(actor_player_id, prompt)


func _resolve_opening_ai_prompt(actor_player_id: int, prompt: Dictionary) -> void:
	var active_prompt: Dictionary = _opening_session.get("active_prompt", {})
	if active_prompt.is_empty():
		return
	if str(active_prompt.get("prompt_id", "")) != str(prompt.get("prompt_id", "")):
		return
	var llm_payload := _choose_opening_with_llm(actor_player_id, prompt) if _ai_use_llm else {}
	if llm_payload.is_empty():
		llm_payload = _auto_opening_response_for_prompt(actor_player_id, prompt)
	_handle_opening_prompt_response(actor_player_id, llm_payload)


func _auto_opening_response_for_prompt(player_id: int, prompt: Dictionary) -> Dictionary:
	var response := {
		"prompt_id": str(prompt.get("prompt_id", "")),
		"stage": str(prompt.get("stage", ""))
	}
	var rng := _make_opening_rng(int(_opening_session.get("duel_seed", 1)), "%s_%s" % [player_id, str(prompt.get("stage", ""))])
	match str(prompt.get("stage", "")):
		"mulligan_0", "mulligan_1":
			response["selected_card_ids"] = []
		"choose_starting_player":
			response["selected_option"] = "go_second" if player_id == PLAYER_TOP else "go_first"
		"opening_special_setup_0", "opening_special_setup_1":
			var options = prompt.get("options", [])
			if options is Array and not options.is_empty():
				response["selected_option"] = str(options[0].get("id", ""))
		_:
			var card_ids: Array[String] = []
			for raw_id in prompt.get("card_ids", []):
				card_ids.append(str(raw_id))
			if not card_ids.is_empty():
				response["selected_card_ids"] = [card_ids[rng.randi_range(0, card_ids.size() - 1)]]
	return response


func _handle_opening_prompt_response(actor_player_id: int, payload: Dictionary) -> void:
	var sync_mulligan_prompts: Dictionary = _opening_session.get("sync_mulligan_prompts", {})
	if _network_mode_active and _network_is_host and not sync_mulligan_prompts.is_empty():
		var stage := str(payload.get("stage", ""))
		if stage.begins_with("mulligan_"):
			var expected_prompt: Dictionary = sync_mulligan_prompts.get(actor_player_id, {})
			if expected_prompt.is_empty():
				return
			if str(payload.get("prompt_id", "")) != str(expected_prompt.get("prompt_id", "")):
				return
			_store_opening_mulligan_result(actor_player_id, payload.get("selected_card_ids", []))
			var responses: Dictionary = _opening_session.get("sync_mulligan_responses", {})
			if not (responses is Dictionary):
				responses = {}
			responses[actor_player_id] = true
			_opening_session["sync_mulligan_responses"] = responses
			if responses.has(PLAYER_BOTTOM) and responses.has(PLAYER_TOP):
				_opening_session.erase("sync_mulligan_prompts")
				_opening_session.erase("sync_mulligan_responses")
				_set_active_opening_prompt({})
				_advance_formal_opening_flow()
				return
			if actor_player_id == _local_player_id:
				var selected_ids = payload.get("selected_card_ids", [])
				var selected_count: int = 0
				if selected_ids is Array:
					selected_count = selected_ids.size()
				var raw_cards = expected_prompt.get("card_ids", [])
				var total_count: int = 0
				if raw_cards is Array:
					total_count = raw_cards.size()
				var waiting_prompt := _mulligan_waiting_prompt(expected_prompt, 1 - actor_player_id, selected_count, total_count)
				_set_active_opening_prompt(waiting_prompt)
				_show_opening_overlay(waiting_prompt)
			return
	var active_prompt: Dictionary = _opening_session.get("active_prompt", {})
	if active_prompt.is_empty():
		return
	if str(payload.get("prompt_id", "")) != str(active_prompt.get("prompt_id", "")):
		return
	_opening_session["last_completed_opening_actor"] = actor_player_id
	_set_active_opening_prompt({})
	match str(active_prompt.get("stage", "")):
		"choose_starting_player":
			var wants_first := str(payload.get("selected_option", "")) != "go_second"
			_opening_session["starting_player_id"] = actor_player_id if wants_first else 1 - actor_player_id
		"opening_special_setup_0", "opening_special_setup_1":
			var selected_option := str(payload.get("selected_option", "normal_opening"))
			var special_choice := {
				"andvaranot_to_artifact": selected_option == "andvaranot_only" or selected_option == "andvaranot_and_thor_hammer",
				"thor_add_hammer_to_hand": selected_option == "thor_hammer_only" or selected_option == "andvaranot_and_thor_hammer"
			}
			_set_opening_player_special_setup_choice(actor_player_id, special_choice)
			_rebuild_opening_special_setup_state_for_player(actor_player_id)
		"calamity_ban_1", "calamity_ban_2", "calamity_ban_3":
			var selected_cards = payload.get("selected_card_ids", [])
			var banned_id := ""
			if selected_cards is Array and not selected_cards.is_empty():
				banned_id = str(selected_cards[0])
			if not banned_id.is_empty():
				var pool: Array = _opening_session.get("calamity_pool", [])
				pool.erase(banned_id)
				_opening_session["calamity_pool"] = pool
				var banned: Array = _opening_session.get("banned_calamities", [])
				banned.append(banned_id)
				_opening_session["banned_calamities"] = banned
		"calamity_pick_first", "calamity_pick_second":
			var selected_cards = payload.get("selected_card_ids", [])
			var selected_id := ""
			if selected_cards is Array and not selected_cards.is_empty():
				selected_id = str(selected_cards[0])
			if not selected_id.is_empty():
				var chosen: Array = _opening_session.get("chosen_calamities", [])
				chosen.append(selected_id)
				_opening_session["chosen_calamities"] = chosen
		"mulligan_0", "mulligan_1":
			_store_opening_mulligan_result(actor_player_id, payload.get("selected_card_ids", []))
	_advance_formal_opening_flow()


func _store_opening_mulligan_result(player_id: int, raw_selected_ids) -> void:
	var selected_ids: Array[String] = []
	if raw_selected_ids is Array:
		for raw_id in raw_selected_ids:
			selected_ids.append(str(raw_id))
	var shuffled_decks: Array = _opening_session.get("shuffled_decks", [])
	var player_deck: Array[String] = shuffled_decks[player_id] if player_id < shuffled_decks.size() else []
	var initial_hands: Array = _opening_session.get("initial_hands", [])
	var initial_hand: Array[String] = initial_hands[player_id] if player_id < initial_hands.size() else []
	var kept: Array[String] = []
	var returned: Array[String] = []
	var remaining_selected_counts: Dictionary = {}
	for selected_id in selected_ids:
		remaining_selected_counts[selected_id] = int(remaining_selected_counts.get(selected_id, 0)) + 1
	var uses_slot_ids := false
	for selected_id in selected_ids:
		if selected_id.begins_with("opening_slot_"):
			uses_slot_ids = true
			break
	for hand_index in range(initial_hand.size()):
		var card_id := initial_hand[hand_index]
		var selection_id := _opening_hand_slot_id(player_id, hand_index, card_id)
		var lookup_id := selection_id if uses_slot_ids else card_id
		var remaining_count := int(remaining_selected_counts.get(lookup_id, 0))
		if remaining_count > 0:
			remaining_selected_counts[lookup_id] = remaining_count - 1
			returned.append(card_id)
		else:
			kept.append(card_id)
	var remaining_deck: Array[String] = []
	for index in range(initial_hand.size(), player_deck.size()):
		remaining_deck.append(str(player_deck[index]))
	var replacement_count := returned.size()
	var replacement: Array[String] = []
	for index in range(min(replacement_count, remaining_deck.size())):
		replacement.append(remaining_deck[index])
	var deck_after_draw := remaining_deck.slice(replacement.size(), remaining_deck.size())
	if not returned.is_empty():
		deck_after_draw.append_array(returned)
		deck_after_draw = _shuffle_string_array(deck_after_draw, _make_opening_rng(int(_opening_session.get("duel_seed", 1)), "mulligan_final_%s" % player_id))
	var final_hand := kept.duplicate()
	final_hand.append_array(replacement)
	var final_deck_order := final_hand.duplicate()
	final_deck_order.append_array(deck_after_draw)
	final_deck_order = _opening_restore_setup_cards_to_deck_order(player_id, final_deck_order)
	var finalized: Dictionary = _opening_session.get("final_player_deck_orders", {})
	finalized[player_id] = final_deck_order
	_opening_session["final_player_deck_orders"] = finalized


func _finalize_opening_calamity_deck() -> void:
	var seed := int(_opening_session.get("duel_seed", 1))
	var pool: Array[String] = []
	var raw_pool = _opening_session.get("calamity_pool", [])
	if raw_pool is Array:
		for raw_id in raw_pool:
			pool.append(str(raw_id))
	if pool.is_empty():
		_opening_session["final_calamity_deck"] = ["sys_calamity_annihilation"]
		return
	if str(_opening_session.get("battle_mode", BATTLE_MODE_QUICK)) == BATTLE_MODE_QUICK:
		pool = _shuffle_string_array(pool, _make_opening_rng(seed, "quick_calamity_pool"))
		var quick_result: Array[String] = []
		for index in range(min(3, pool.size())):
			quick_result.append(pool[index])
		quick_result = _shuffle_string_array(quick_result, _make_opening_rng(seed, "quick_calamity_order"))
		quick_result.append("sys_calamity_annihilation")
		_opening_session["final_calamity_deck"] = quick_result
		return
	var revealed := str(_opening_session.get("revealed_calamity", ""))
	if revealed.is_empty():
		var reveal_rng := _make_opening_rng(seed, "match_reveal_calamity")
		revealed = pool[reveal_rng.randi_range(0, pool.size() - 1)]
		pool.erase(revealed)
		_opening_session["revealed_calamity"] = revealed
		_opening_session["calamity_pool"] = pool
	var chosen: Array[String] = []
	var raw_chosen = _opening_session.get("chosen_calamities", [])
	if raw_chosen is Array:
		for raw_id in raw_chosen:
			chosen.append(str(raw_id))
	var final_cards: Array[String] = [revealed]
	final_cards.append_array(chosen)
	final_cards = _shuffle_string_array(final_cards, _make_opening_rng(seed, "match_final_calamity_order"))
	final_cards.append("sys_calamity_annihilation")
	_opening_session["final_calamity_deck"] = final_cards


func _advance_formal_opening_flow() -> void:
	if _opening_session.is_empty():
		return
	var starting_player_id := int(_opening_session.get("starting_player_id", -1))
	if starting_player_id < 0:
		var decider := int(_opening_session.get("starting_decider_player_id", PLAYER_BOTTOM))
		var prompt := {
			"prompt_id": _next_opening_prompt_id(),
			"stage": "choose_starting_player",
			"choice_type": "option_pick",
			"actor_player_id": decider,
			"title": "确定先后攻",
			"description": "选择由谁作为先攻开始本局对战。",
			"status_text": "本步骤完成后会继续处理天灾流程与起手调度。",
			"options": [
				{"id": "go_first", "label": "我方先攻", "accent": true},
				{"id": "go_second", "label": "我方后攻", "accent": false}
			]
		}
		if _network_mode_active and decider != _local_player_id:
			prompt["options"] = [
				{"id": "go_first", "label": "由你先攻", "accent": true},
				{"id": "go_second", "label": "由你后攻", "accent": false}
			]
		_dispatch_opening_prompt(decider, prompt)
		return
	if str(_opening_session.get("battle_mode", BATTLE_MODE_QUICK)) == BATTLE_MODE_MATCH:
		var banned: Array = _opening_session.get("banned_calamities", [])
		if banned.size() < 3:
			var ban_actor := starting_player_id if banned.size() == 0 or banned.size() == 2 else 1 - starting_player_id
			var pool: Array = _opening_session.get("calamity_pool", [])
			var banned_names: Array[String] = []
			for raw_banned_id in banned:
				banned_names.append(_card_name(str(raw_banned_id)))
			var prompt := {
				"prompt_id": _next_opening_prompt_id(),
				"stage": "calamity_ban_%s" % (banned.size() + 1),
				"choice_type": "card_pick",
				"actor_player_id": ban_actor,
				"title": "禁用天灾",
				"description": "%s请选择 1 张天灾禁用。" % _opening_player_label(ban_actor),
				"status_text": "已禁用：%s" % ("、".join(banned_names) if not banned_names.is_empty() else "暂无"),
				"card_ids": pool.duplicate(),
				"count": 1,
				"columns": 4,
				"confirm_text": "确认禁用"
			}
			_dispatch_opening_prompt(ban_actor, prompt)
			return
		if str(_opening_session.get("revealed_calamity", "")).is_empty():
			_finalize_opening_calamity_deck()
		var chosen: Array = _opening_session.get("chosen_calamities", [])
		if chosen.size() < 2:
			var offer_actor := starting_player_id if chosen.is_empty() else 1 - starting_player_id
			var offer_count := 3 if chosen.is_empty() else 2
			var offer_stage := "calamity_pick_first" if chosen.is_empty() else "calamity_pick_second"
			var pool_cards: Array[String] = []
			var raw_pool_cards = _opening_session.get("calamity_pool", [])
			if raw_pool_cards is Array:
				for raw_id in raw_pool_cards:
					pool_cards.append(str(raw_id))
			var offer_rng := _make_opening_rng(int(_opening_session.get("duel_seed", 1)), offer_stage)
			pool_cards = _shuffle_string_array(pool_cards, offer_rng)
			var offered: Array[String] = []
			for index in range(min(offer_count, pool_cards.size())):
				offered.append(pool_cards[index])
			for offered_id in offered:
				pool_cards.erase(offered_id)
			_opening_session["calamity_pool"] = pool_cards
			var prompt := {
				"prompt_id": _next_opening_prompt_id(),
				"stage": offer_stage,
				"choice_type": "card_pick",
				"actor_player_id": offer_actor,
				"title": "选择天灾",
				"description": "%s请从随机出现的天灾中选择 1 张。" % _opening_player_label(offer_actor),
				"status_text": "公开天灾：%s" % _card_name(str(_opening_session.get("revealed_calamity", ""))),
				"card_ids": offered,
				"count": 1,
				"columns": 3,
				"confirm_text": "确认选择"
			}
			_dispatch_opening_prompt(offer_actor, prompt)
			return
	_finalize_opening_calamity_deck()
	for player_id in [PLAYER_BOTTOM, PLAYER_TOP]:
		var special_prompt := _opening_special_setup_prompt(player_id)
		if not special_prompt.is_empty():
			_dispatch_opening_prompt(player_id, special_prompt)
			return
	var finalized: Dictionary = _opening_session.get("final_player_deck_orders", {})
	if _network_mode_active and _network_is_host and finalized.is_empty() and not _opening_session.has("sync_mulligan_prompts"):
		var prompt_map: Dictionary = {}
		for player_id in [PLAYER_BOTTOM, PLAYER_TOP]:
			var initial_hands: Array = _opening_session.get("initial_hands", [])
			var initial_hand: Array[String] = []
			var raw_hand: Array = initial_hands[player_id] if player_id < initial_hands.size() else []
			if raw_hand is Array:
				for raw_id in raw_hand:
					initial_hand.append(str(raw_id))
			var card_entries: Array[Dictionary] = []
			for hand_index in range(initial_hand.size()):
				var definition_id := str(initial_hand[hand_index])
				card_entries.append({
					"selection_id": _opening_hand_slot_id(player_id, hand_index, definition_id),
					"card_id": definition_id
				})
			var prompt := {
				"prompt_id": _next_opening_prompt_id(),
				"stage": "mulligan_%s" % player_id,
				"choice_type": "card_pick",
				"actor_player_id": player_id,
				"title": "起手调度",
				"description": "%s可选择任意数量的手牌进行调度。" % _opening_player_label(player_id),
				"status_text": "选中的卡牌会回到底部，补抽相同数量后重洗剩余牌库。",
				"card_ids": initial_hand.duplicate(),
				"card_entries": card_entries,
				"count": -1,
				"max_count": initial_hand.size(),
				"columns": 3,
				"confirm_text": "确认调度"
			}
			prompt_map[player_id] = prompt
		_opening_session["sync_mulligan_prompts"] = prompt_map.duplicate(true)
		_opening_session["sync_mulligan_responses"] = {}
		var local_prompt: Dictionary = prompt_map.get(_local_player_id, {})
		if not local_prompt.is_empty():
			_set_active_opening_prompt(local_prompt)
			_show_opening_overlay(local_prompt)
		var remote_player_id := 1 - _local_player_id
		var remote_prompt: Dictionary = prompt_map.get(remote_player_id, {})
		if _network_session != null and not remote_prompt.is_empty():
			_network_session.send_opening_prompt(remote_prompt)
		return
	for player_id in [PLAYER_BOTTOM, PLAYER_TOP]:
		if finalized.has(player_id):
			continue
		var initial_hands: Array = _opening_session.get("initial_hands", [])
		var initial_hand: Array = initial_hands[player_id] if player_id < initial_hands.size() else []
		var card_entries: Array[Dictionary] = []
		for hand_index in range(initial_hand.size()):
			var definition_id := str(initial_hand[hand_index])
			card_entries.append({
				"selection_id": _opening_hand_slot_id(player_id, hand_index, definition_id),
				"card_id": definition_id
			})
		var prompt := {
			"prompt_id": _next_opening_prompt_id(),
			"stage": "mulligan_%s" % player_id,
			"choice_type": "card_pick",
			"actor_player_id": player_id,
			"title": "起手调度",
			"description": "%s可选择任意数量的手牌进行调度。" % _opening_player_label(player_id),
			"status_text": "选中的卡牌会回到底部，补抽相同数量后重洗剩余牌库。",
			"card_ids": initial_hand.duplicate(),
				"card_entries": card_entries,
			"count": -1,
			"max_count": initial_hand.size(),
			"columns": 3,
			"confirm_text": "确认调度"
		}
		_dispatch_opening_prompt(player_id, prompt)
		return
	_finalize_opening_and_start_duel()


func _finalize_opening_and_start_duel() -> void:
	var final_decks_map: Dictionary = _opening_session.get("final_player_deck_orders", {})
	var final_decks: Array = [
		final_decks_map.get(PLAYER_BOTTOM, []),
		final_decks_map.get(PLAYER_TOP, [])
	]
	var final_options: Dictionary = _decorate_game_options_with_ai_mode(_opening_session.get("base_game_options", {}))
	final_options["shuffle_player_decks"] = false
	final_options["player_deck_orders"] = final_decks
	final_options["starting_active_player"] = int(_opening_session.get("starting_player_id", PLAYER_BOTTOM))
	final_options["opening_hand_size"] = 6
	final_options["opening_active_player_morale"] = 1
	final_options["opening_non_active_player_morale"] = 0
	var raw_opening_setup_choices = _opening_session.get("opening_setup_choices", [{}, {}])
	final_options["opening_setup_choices"] = raw_opening_setup_choices.duplicate(true) if raw_opening_setup_choices is Array else [{}, {}]
	var final_calamity_deck: Array[String] = []
	var raw_final_calamity_deck = _opening_session.get("final_calamity_deck", [])
	if raw_final_calamity_deck is Array:
		for raw_id in raw_final_calamity_deck:
			final_calamity_deck.append(str(raw_id))
	final_options["calamity_deck"] = final_calamity_deck
	if _network_mode_active:
		final_options["network_host_player_id"] = PLAYER_BOTTOM
	_hide_opening_overlay()
	var duel_path := str(_opening_session.get("duel_path", FORMAL_DECK_PATH))
	var duel_label := str(_opening_session.get("duel_label", "正式对局"))
	var duel_seed := int(_opening_session.get("duel_seed", _make_duel_seed()))
	_opening_session.clear()
	if _network_mode_active:
		_network_session.broadcast_start_duel(duel_path, final_options, duel_label, duel_seed)
		call_deferred("_deferred_start_duel", duel_path, final_options, duel_label, duel_seed)
		return
	call_deferred("_deferred_start_duel", duel_path, final_options, duel_label, duel_seed)


func _begin_formal_opening_flow(duel_path: String, game_options: Dictionary, duel_label: String, duel_seed: int) -> bool:
	var session := _build_formal_opening_session(duel_path, game_options, duel_label, duel_seed)
	if session.is_empty():
		_push_log("正式对局初始化失败：无法读取开局数据。")
		return false
	_opening_session = session
	_rebuild_opening_special_setup_state()
	_advance_formal_opening_flow()
	return true


func _on_game_result_confirmed() -> void:
	_return_to_main_page()


func _network_terminal_message_for_reason(reason_code: String, detail: String = "") -> String:
	match reason_code:
		NETWORK_TERMINATION_REASON_NORMAL_FINISH:
			return ""
		NETWORK_TERMINATION_REASON_LOCAL_DISCONNECT:
			return "已断开联机连接，返回开始页。"
		NETWORK_TERMINATION_REASON_SESSION_CLOSED:
			return "联机已断开，本局已终止，请重新开始对局。"
		NETWORK_TERMINATION_REASON_PEER_DISCONNECTED:
			return "对手已断开，本局已终止，请重新开始对局。"
		NETWORK_TERMINATION_REASON_COMMAND_TIMEOUT:
			return "联机命令确认超时，本局已终止，请重新开始对局。"
		NETWORK_TERMINATION_REASON_RESYNC_TIMEOUT:
			return "联机重同步超时，本局已终止，请重新开始对局。"
		NETWORK_TERMINATION_REASON_RESYNC_FAILED:
			if detail.is_empty():
				return "联机重同步失败，本局已终止。"
			return "联机重同步失败：%s，本局已终止。" % detail
		NETWORK_TERMINATION_REASON_HOST_REJECTED_COMMAND:
			if detail.is_empty():
				return "联机命令被房主拒绝。"
			return "联机命令被房主拒绝：%s" % detail
	return detail


func _reset_battle_table(preserve_terminal_message: bool = false, disconnect_session: bool = false, show_start_panel: bool = true) -> void:
	_detach_pending_ai_thread()
	_hide_game_result_dialog()
	_hide_network_sync_overlay()
	_stop_table_replay_auto_play()
	if _table_replay_overlay != null:
		_table_replay_overlay.visible = false
	if _zone_interaction_layer != null:
		_zone_interaction_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_overlay_card_preview()
	_clear_drag_highlights()
	_hide_drag_line()
	_clear_selection_state()
	_clear_action_focus()
	_active_choice_id = ""
	_choice_selected_card_ids.clear()
	_choice_reorder_dragging_card_id = ""
	_local_play_option_choice = {}
	_selected_target_action = {}
	_selected_stack_target_id = ""
	_selected_source_id = ""
	_selected_morale_filter = false
	_selected_master_guard_cards.clear()
	_selected_unit_defense_proposal_id = ""
	_master_guard_feedback_text = ""
	_master_guard_submit_pending = false
	_players.clear()
	_view_cards_by_uid.clear()
	_player_views_cache.clear()
	_master_view_cards_by_player.clear()
	_card_views_by_uid.clear()
	_card_view_seen_ids.clear()
	_selected_attacker_uid = ""
	_dragging_card_uid = ""
	_hover_slot_index = -1
	_hover_zone_kind = ""
	_ai_blocked_until_ms = 0
	_ai_stall_last_command_count = 0
	_ai_stall_last_progress_ms = Time.get_ticks_msec()
	_ai_stall_last_force_ms = 0
	_ai_override_players.clear()
	_pending_animations.clear()
	_last_logged_event_id = 0
	_last_card_orientation_by_id.clear()
	_last_master_hp_by_player.clear()
	_last_winner = -1
	_opening_animation_seeded = false
	_network_command_index = 0
	_pending_network_commands.clear()
	_network_resync_in_progress = false
	_network_resync_started_at_ms = 0
	_network_remote_formal_deck_selection.clear()
	_network_opening_response_cache.clear()
	_opening_session.clear()
	_hide_opening_overlay()
	if _busy_status_panel != null:
		_busy_status_panel.visible = false
	if not preserve_terminal_message:
		_network_terminal_message = ""
	_zone_static_signature = ""
	_zone_interaction_signature = ""
	_selection_highlight_signature = ""
	_action_panel_signature = ""
	_response_panel_signature = ""
	_choice_panel_signature = ""
	_stack_panel_signature = ""
	_deferred_refresh_pending = false
	_deferred_network_auto_pass_pending = false
	if _zone_static_layer != null:
		_clear_children(_zone_static_layer)
	if _zone_overlay_layer != null:
		_clear_children(_zone_overlay_layer)
	if _zone_interaction_layer != null:
		_clear_children(_zone_interaction_layer)
	if _selection_highlight_layer != null:
		_clear_children(_selection_highlight_layer)
	if _drag_highlight_layer != null:
		_clear_children(_drag_highlight_layer)
	if _drag_target_layer != null:
		_clear_children(_drag_target_layer)
	if _card_layer != null:
		_clear_children(_card_layer)
	if _action_panel_body != null:
		_clear_children(_action_panel_body)
	if _response_panel_body != null:
		_clear_children(_response_panel_body)
	if _choice_panel_body != null:
		_clear_children(_choice_panel_body)
	if _stack_panel_body != null:
		_clear_children(_stack_panel_body)
	_state = null
	_game_over = false
	if _turn_label != null:
		_turn_label.visible = false
	if _log_label != null:
		_log_label.visible = false
	if _end_turn_button != null:
		_end_turn_button.visible = false
	if _return_to_main_button != null:
		_return_to_main_button.visible = false
	if _action_panel != null:
		_action_panel.visible = false
	if _response_panel != null:
		_response_panel.visible = false
	if _choice_panel != null:
		_choice_panel.visible = false
	if _stack_panel != null:
		_stack_panel.visible = false
	if disconnect_session and _network_session != null and _network_session.is_network_active():
		_network_session.disconnect_session()
	if show_start_panel:
		_show_start_panel()
		if _start_panel_desc != null and not _network_terminal_message.is_empty():
			_start_panel_desc.text = _network_terminal_message
	if _network_status_label != null:
		if _network_terminal_message.is_empty():
			if not _network_mode_active:
				_network_status_label.text = "本地模式：可直接开始对局。\n联机模式需要在相同局域网环境。"
		else:
			_network_status_label.text = _network_terminal_message
	_refresh()


func _return_to_main_page() -> void:
	_append_file_log("[TABLE RESET] code=%s" % NETWORK_TERMINATION_REASON_NORMAL_FINISH)
	_save_current_match_to_history("interrupted")
	_reset_battle_table(false, true, true)

func _save_current_match_to_history(status: String) -> void:
	if _history_saved:
		return
	if _state == null:
		return
	if _state.command_log.is_empty():
		return
	if _history_store == null:
		_history_store = MatchHistoryStore.new()
	var now := int(Time.get_unix_time_from_system())
	var card_paths: Array[String] = [CARD_DATA_DIR]
	for path in EXTRA_CARD_DATA_PATHS:
		card_paths.append(str(path))
	var card_pool_hash := CardPoolHasher.hash_card_pool(card_paths)
	var meta := {
		"started_at": int(_duel_started_at),
		"finished_at": now,
		"created_at": now,
		"game_version": "",
		"card_pool_hash": card_pool_hash,
		"exported_by": "client"
	}
	var history_info := {
		"mode": _history_mode_tag(),
		"status": status,
		"source_record_id": str(_current_game_options.get("source_record_id", "")),
		"source_command_index": int(_current_game_options.get("source_command_index", -1)),
		"duel_log_path": _duel_log_path,
		"ai_log_path": _ai_raw_log_path
	}
	var replay_data := _engine.export_replay_data_v2(_state, meta, history_info, _current_game_options)
	var save_result = _history_store.save_match_record(replay_data, {})
	if bool(save_result.get("ok", false)):
		_history_saved = true
	else:
		_append_file_log("[HISTORY] save_failed code=%s message=%s" % [str(save_result.get("code", "")), str(save_result.get("message", ""))])

func _history_mode_tag() -> String:
	var base := str(_current_game_options.get("mode", "unknown"))
	if _network_mode_active:
		return "network_%s" % base
	return base


func _on_start_duel_pressed() -> void:
	if not _startup_ready:
		_push_log("资源尚未加载完成，请稍候。")
		return
	if _network_mode_active and _network_is_host and not _network_session.has_remote_peer():
		_push_log("联机房主仍在等待对手加入。")
		return
	var formal_setup := _resolve_formal_duel_setup()
	if not bool(formal_setup.get("ok", false)):
		if _start_panel_desc != null:
			_start_panel_desc.text = str(formal_setup.get("reason", "正式对局初始化失败。"))
		return
	var formal_duel_path := str(formal_setup.get("duel_path", FORMAL_DECK_PATH))
	var formal_game_options: Dictionary = _decorate_game_options_with_ai_mode(formal_setup.get("game_options", FORMAL_GAME_OPTIONS.duplicate(true)))
	var formal_summary := str(formal_setup.get("summary", ""))
	if _start_duel_button != null:
		_start_duel_button.disabled = true
	if _start_test_button != null:
		_start_test_button.disabled = true
	if _start_panel_desc != null:
		_start_panel_desc.text = "正在初始化正式对局...\n%s" % formal_summary
	_pending_start_duel_seed = _make_duel_seed()
	if _network_mode_active:
		if not _network_is_host:
			_push_log("加入方需等待房主开始对局。")
			_show_start_panel()
			return
		if not _begin_formal_opening_flow(formal_duel_path, formal_game_options, "联机正式对局", _pending_start_duel_seed):
			_show_start_panel()
		return
	if not _begin_formal_opening_flow(formal_duel_path, formal_game_options, "正式对局", _pending_start_duel_seed):
		_show_start_panel()


func _on_start_test_pressed() -> void:
	if not _is_test_mode_available():
		_push_log("当前发布版本未包含测试模式。")
		_show_start_panel()
		return
	if _network_mode_active and _network_is_host and not _network_session.has_remote_peer():
		_push_log("联机房主仍在等待对手加入。")
		return
	if _start_duel_button != null:
		_start_duel_button.disabled = true
	if _start_test_button != null:
		_start_test_button.disabled = true
	var test_setup := _resolve_test_duel_setup()
	if not bool(test_setup.get("ok", false)):
		if _start_panel_desc != null:
			_start_panel_desc.text = str(test_setup.get("reason", "测试对局初始化失败。"))
		_show_start_panel()
		return
	var test_duel_path := str(test_setup.get("duel_path", TEST_DECK_PATH))
	var test_game_options: Dictionary = _decorate_game_options_with_ai_mode(test_setup.get("game_options", TEST_GAME_OPTIONS.duplicate(true)))
	if _start_panel_desc != null:
		var test_summary := str(test_setup.get("summary", ""))
		_start_panel_desc.text = "正在初始化测试对局..." if test_summary.is_empty() else "正在初始化测试对局...\n%s" % test_summary
	_pending_start_duel_seed = _make_duel_seed()
	if _network_mode_active:
		if not _network_is_host:
			_push_log("加入方需等待房主开始测试对局。")
			_show_start_panel()
			return
		_network_session.broadcast_start_duel(test_duel_path, test_game_options, "联机测试对局", _pending_start_duel_seed)
		call_deferred("_deferred_start_duel", test_duel_path, test_game_options, "联机测试对局", _pending_start_duel_seed)
		return
	call_deferred("_deferred_start_duel", test_duel_path, test_game_options, "测试对局", _pending_start_duel_seed)


func _on_host_duel_pressed() -> void:
	if not _startup_ready:
		_push_log("资源尚未加载完成，请稍候。")
		return
	_network_terminal_message = ""
	_network_connect_hint = ""
	var result = _network_session.host_session()
	if not bool(result.get("ok", false)):
		return
	_network_connect_hint = _network_session.get_host_join_hint()
	_push_log("已开启联机房间，等待对手加入。")
	if _start_panel_desc != null:
		_start_panel_desc.text = "房间已创建，请让对方点击“加入房间”后输入房主地址连接。"
	if _network_status_label != null:
		_network_status_label.text = _host_waiting_status_text()
	_show_start_panel()
	_refresh()


func _on_join_duel_pressed() -> void:
	if not _startup_ready:
		_push_log("资源尚未加载完成，请稍候。")
		return
	if _join_address_dialog == null or _join_address_prompt_edit == null:
		return
	_show_join_address_dialog()


func _on_join_address_confirmed() -> void:
	if _join_address_prompt_edit == null:
		return
	var address := _join_address_prompt_edit.text.strip_edges()
	if address.is_empty():
		_push_log("请输入房主 IP。")
		return
	_hide_join_address_dialog()
	_network_terminal_message = ""
	var result = _network_session.join_session(address)
	if not bool(result.get("ok", false)):
		return
	_push_log("正在连接房主：%s" % address)
	_show_start_panel()
	_refresh()


func _on_disconnect_pressed() -> void:
	if _network_session == null or not _network_session.is_network_active():
		return
	if _state != null and not _game_over:
		_abort_network_duel(NETWORK_TERMINATION_REASON_LOCAL_DISCONNECT, "", true)
		return
	_network_terminal_message = _network_terminal_message_for_reason(NETWORK_TERMINATION_REASON_LOCAL_DISCONNECT)
	_append_file_log("[NET RESET] code=%s" % NETWORK_TERMINATION_REASON_LOCAL_DISCONNECT)
	_network_session.disconnect_session()
	_show_start_panel()
	if _start_panel_desc != null:
		_start_panel_desc.text = _network_terminal_message
	if _network_status_label != null:
		_network_status_label.text = _network_terminal_message
	_refresh()


func _deferred_start_duel(duel_path: String, game_options: Dictionary, duel_label: String, duel_seed: int = -1) -> void:
	_start_new_duel(duel_path, game_options, duel_label, duel_seed)
	call_deferred("_refresh")


func _make_duel_seed() -> int:
	return max(1, int(Time.get_ticks_usec() % 2147483647))


func _sync_from_engine() -> void:
	if _state == null:
		return
	_reconcile_master_guard_feedback_state()
	var sync_started_at := Time.get_ticks_msec()
	var previous_orientations: Dictionary = _last_card_orientation_by_id.duplicate(true)
	var previous_master_hp: Dictionary = _last_master_hp_by_player.duplicate(true)
	var previous_winner := _last_winner
	_active_player = _display_player_for_logical(int(_state.active_player))
	_turn_number = int(_state.turn_number)
	_game_over = int(_state.winner) != -1
	_waiting_state = _engine.get_waiting_state(_state)
	_invalidate_action_cache()
	var player_views_started_at := Time.get_ticks_msec()
	_players = []
	for display_player_index in range(2):
		_players.append(_build_player_view(display_player_index))
	_log_slow_perf("sync/player_views", player_views_started_at, NETWORK_PERF_WARN_MS)
	_maybe_capture_self_response_followup_signature()
	if _auto_pass_empty_response_window():
		_sync_from_engine()
		return
	if _auto_skip_response_window_active():
		_hide_auto_skipped_response_panels()
	_schedule_network_auto_pass_empty_response_window()
	_queue_orientation_change_animations(previous_orientations)
	_queue_master_hp_change_animations(previous_master_hp)
	_last_card_orientation_by_id = _snapshot_card_orientations()
	_last_master_hp_by_player = _snapshot_master_hp()
	_last_winner = int(_state.winner)
	if _state.winner != -1 and previous_winner != int(_state.winner):
		_pending_animations.append({
			"kind": "banner",
			"text": "%s 获胜" % str(_players[_display_player_for_logical(int(_state.winner))].get("name", "玩家")),
			"effect": "game_end",
			"delay": 0.0
		})
		if not _table_replay_active:
			_save_current_match_to_history("finished")
			_show_game_result_dialog(int(_state.winner))
	_append_new_event_logs()
	_sync_choice_selection_state()
	if _current_local_input_player() < 0:
		_clear_selection_state()
		_active_choice_id = ""
		_choice_selected_card_ids.clear()
		_choice_reorder_dragging_card_id = ""
		_local_play_option_choice = {}
	if _selected_attacker_uid != "" and not _has_attack_action(_current_input_player(), _selected_attacker_uid):
		_selected_attacker_uid = ""
	if not _selected_target_action.is_empty() and not _action_still_available(_current_input_player(), _selected_target_action):
		_selected_target_action = {}
	if not _selected_stack_target_id.is_empty() and not _stack_id_exists(_selected_stack_target_id):
		_selected_stack_target_id = ""
	if not _selected_source_id.is_empty() and _activation_actions_for_source(_current_input_player(), _selected_source_id).is_empty():
		_selected_source_id = ""
	if _selected_morale_filter and _morale_activation_actions(_current_input_player()).is_empty():
		_selected_morale_filter = false
	if _state.pending_attack.is_empty():
		_selected_master_guard_cards.clear()
		_selected_unit_defense_proposal_id = ""
	elif _matching_master_guard_action(_master_guard_actions_for_pending_attack_target(), _selected_master_guard_cards).is_empty():
		_selected_master_guard_cards.clear()
		if _selected_unit_defense_action_for_current_player().is_empty():
			_selected_unit_defense_proposal_id = ""
	_log_slow_perf("sync/total", sync_started_at, NETWORK_PERF_WARN_MS)
	if not _opening_animation_seeded:
		# Startup was stalling on large first-frame tween batches in formal duel.
		_opening_animation_seeded = true


func _seed_opening_animations() -> void:
	if _state == null or _players.is_empty():
		return
	for display_player_index in range(2):
		var hand: Array = _players[display_player_index].get("hand", [])
		for card in hand:
			_pending_animations.append({
				"kind": "deck_to_hand",
				"player": display_player_index,
				"card_uid": str(card.get("uid", "")),
				"delay": 0.06 * float(_pending_animations.size())
			})
		var morale_count := int(_players[display_player_index].get("cost_area", []).size())
		for morale_index in range(morale_count):
			_pending_animations.append({
				"kind": "cost_to_area",
				"player": display_player_index,
				"target_index": morale_index,
				"delay": 0.06 * float(_pending_animations.size())
			})


func _build_player_view(display_player_index: int) -> Dictionary:
	var logical_player_index := _logical_player_for_display(display_player_index)
	var player_state = _state.get_player(logical_player_index)
	var player: Dictionary = _player_views_cache.get(display_player_index, {})
	if player.is_empty():
		player = {
			"name": "",
			"master_name": "",
			"hp": 0,
			"max_hp": 0,
			"deck": [],
			"hand": [],
			"board": [],
			"artifact": null,
			"master": {},
			"cost_deck": [],
			"cost_area": [],
			"cost_area_cards": [],
			"spent_cost_area_cards": [],
			"grave": [],
			"grave_cards": [],
		}
		_player_views_cache[display_player_index] = player
	player["name"] = player_state.name
	player["master_name"] = player_state.master_name
	player["hp"] = int(player_state.master_hp)
	player["max_hp"] = int(player_state.master_max_hp)
	player["deck"] = player_state.deck.cards.duplicate()
	player["cost_deck"] = player_state.cost_deck.cards.duplicate()
	player["cost_area"] = player_state.cost_area.cards.duplicate()
	player["grave"] = player_state.grave.cards.duplicate()
	var grave_views: Array = player.get("grave_cards", [])
	grave_views.clear()
	player["master"] = _build_master_view_card(display_player_index)
	player["artifact"] = null
	var hand_views: Array = player.get("hand", [])
	hand_views.clear()
	var board_views: Array = player.get("board", [])
	board_views.clear()
	board_views.resize(BOARD_SLOT_COUNT)
	var cost_area_views: Array = player.get("cost_area_cards", [])
	cost_area_views.clear()
	var spent_cost_area_views: Array = player.get("spent_cost_area_cards", [])
	spent_cost_area_views.clear()
	var hide_hand := _should_hide_hand_from_local_player(display_player_index)
	for card_id in player_state.hand.cards:
		var hand_view := _build_view_card(card_id)
		if hide_hand:
			hand_view = _view_card_for_hidden_hand(hand_view)
		hand_views.append(hand_view)
	for card_id in player_state.cost_area.cards:
		cost_area_views.append(_build_view_card(card_id))
	for card_id in player_state.spent_cost_area.cards:
		spent_cost_area_views.append(_build_view_card(card_id))
	for card_id in player_state.grave.cards:
		var grave_view_card := _build_view_card(card_id).duplicate(true)
		grave_view_card["face"] = "face_up"
		grave_view_card["orientation"] = "active"
		grave_views.append(grave_view_card)
	for card_id in player_state.artifact_zone.cards:
		player["artifact"] = _build_view_card(card_id)
	for col in range(3):
		var front_slot = player_state.get_slot("front", col)
		if front_slot != null and not front_slot.occupant.is_empty():
			board_views[_slot_index_from_row_col("front", col)] = _build_view_card(front_slot.occupant)
		var back_slot = player_state.get_slot("back", col)
		if back_slot != null and not back_slot.occupant.is_empty():
			board_views[_slot_index_from_row_col("back", col)] = _build_view_card(back_slot.occupant)
	return player


func _build_view_card(card_id: String) -> Dictionary:
	if _is_morale_source_id(card_id):
		var morale_view: Dictionary = _view_cards_by_uid.get(card_id, {})
		if morale_view.is_empty():
			morale_view = {"uid": card_id, "definition_id": "sys_morale", "definition": {"id": "sys_morale", "name": "阵营士气", "type": "morale"}}
			_view_cards_by_uid[card_id] = morale_view
		morale_view["owner"] = _display_player_for_logical(int(card_id.trim_prefix("morale_")))
		morale_view["zone"] = "cost_area"
		return morale_view
	var instance = _state.card_instances.get(card_id)
	if instance == null:
		var direct_definition: Dictionary = _card_definitions.get(card_id, {})
		if direct_definition is Dictionary and not direct_definition.is_empty():
			var preview_definition := direct_definition.duplicate(true)
			var preview_type := str(preview_definition.get("type", ""))
			var preview_owner := PLAYER_BOTTOM if preview_type == "calamity" else _current_input_player()
			var preview_zone := "calamity" if preview_type == "calamity" else "preview"
			return {
				"uid": card_id,
				"definition_id": card_id,
				"definition": preview_definition,
				"owner": preview_owner,
				"zone": preview_zone,
				"face": "face_up",
				"orientation": "active",
				"current_hp": int(preview_definition.get("hp", preview_definition.get("power", 0))),
				"current_cost": int(preview_definition.get("cost", 0))
			}
		return {"uid": card_id, "definition_id": "", "definition": {"id": "", "name": card_id, "type": "legion"}, "owner": _current_input_player(), "zone": ""}
	var definition_id: String = str(instance.definition_id)
	var definition: Dictionary = _card_definitions.get(definition_id, {
		"id": definition_id,
		"name": definition_id,
		"type": "legion",
		"cost": 0,
		"power": 0,
		"hp": 0,
		"text": ""
	}).duplicate(true)
	if definition_id == "sys_morale" or str(instance.zone) == "cost_deck":
		definition = _morale_definition_for_player(int(instance.owner))
	var view_card: Dictionary = _view_cards_by_uid.get(card_id, {})
	if view_card.is_empty():
		view_card = {"uid": card_id}
		_view_cards_by_uid[card_id] = view_card
	var base_hp: int = int(definition.get("hp", definition.get("power", 0)))
	var uses_battlefield_power := str(definition.get("type", "")) == "legion" or (str(instance.zone).begins_with("battle_") and int(instance.flags.get("manifested_power", 0)) > 0)
	var current_hp: int = _engine.get_display_card_power(_state, card_id) if uses_battlefield_power else max(0, base_hp - int(instance.damage_marked))
	var base_cost := int(definition.get("cost", 0))
	var current_cost: int = _engine._get_effective_card_cost(_state, card_id)
	view_card["definition_id"] = definition_id
	view_card["definition"] = definition
	view_card["owner"] = _display_player_for_logical(int(instance.controller))
	view_card["zone"] = str(instance.zone)
	view_card["face"] = str(instance.face)
	view_card["orientation"] = str(instance.orientation)
	view_card["current_hp"] = current_hp
	view_card["current_cost"] = current_cost
	view_card["status_badges"] = _active_status_badges_for_card(instance, definition)
	view_card["can_attack"] = _has_attack_action(_current_input_player(), card_id)
	view_card["can_move"] = _has_move_action(_current_input_player(), card_id)
	return view_card

func _active_status_badges_for_card(instance, definition: Dictionary) -> Array[String]:
	var badges: Array[String] = []
	if instance == null:
		return badges
	if str(instance.face) == "face_down" or not str(instance.zone).begins_with("battle_"):
		return badges
	if _card_has_active_status_keyword(instance, definition, "strong_attack"):
		badges.append("强攻")
	if _card_has_active_cannot_die_badge(instance):
		badges.append("免死")
	if _card_has_active_status_keyword(instance, definition, "must_hit"):
		badges.append("必中")
	if _card_has_active_status_keyword(instance, definition, "taunt"):
		badges.append("嘲讽")
	if _card_has_active_status_keyword(instance, definition, "shock"):
		badges.append("震击")
	if _card_has_active_status_keyword(instance, definition, "pierce"):
		badges.append("贯穿")
	return badges

func _card_has_active_cannot_die_badge(instance) -> bool:
	if instance == null:
		return false
	if int(instance.flags.get("cannot_die_until_turn_end_turn", -1)) == int(_state.turn_number):
		return true
	if int(instance.flags.get("cannot_die_until_next_own_turn_start_player", -1)) >= 0:
		return true
	return bool(instance.flags.get("bijie_excalibur_substitute_enabled", false))

func _card_has_active_status_keyword(instance, definition: Dictionary, keyword: String) -> bool:
	if instance == null or keyword.is_empty():
		return false
	if keyword == "strong_attack" and _state != null:
		var instance_id := str(instance.instance_id)
		if not instance_id.is_empty() and _engine._has_attack_keyword(_state, instance_id, keyword):
			return true
		if int(instance.flags.get("master_damage_bonus_turn", -1)) == int(_state.turn_number) and int(instance.flags.get("master_damage_bonus_amount", 0)) > 0:
			return true
	var definition_keywords = definition.get("keywords", [])
	if definition_keywords is Array and definition_keywords.has(keyword):
		return true
	var definition_traits = definition.get("traits", [])
	if definition_traits is Array and definition_traits.has(keyword):
		return true
	if _definition_grants_keyword_in_current_state(instance, definition, keyword):
		return true
	var persistent_keywords = instance.flags.get("persistent_keywords", [])
	if persistent_keywords is Array and persistent_keywords.has(keyword):
		return true
	if int(instance.flags.get("temporary_keyword_%s_turn" % keyword, -1)) == int(_state.turn_number):
		return true
	if keyword == "taunt" and int(instance.flags.get("taunt_until_next_own_turn_start_player", -1)) >= 0:
		return true
	if keyword == "must_hit" and int(instance.flags.get("temporary_keyword_must_hit_turn", -1)) == int(_state.turn_number):
		return true
	return false

func _definition_grants_keyword_in_current_state(instance, definition: Dictionary, keyword: String) -> bool:
	var effects = definition.get("effects", [])
	if not (effects is Array):
		return false
	for effect in effects:
		if not (effect is Dictionary):
			continue
		if str(effect.get("kind", "")) != "continuous":
			continue
		var resolution = effect.get("resolution", {})
		if not (resolution is Dictionary):
			continue
		if str(resolution.get("action", "")) != "grant_keyword":
			continue
		if str(resolution.get("target_scope", "self")) != "self":
			continue
		if str(resolution.get("keyword", "")) != keyword:
			continue
		var required_row := str(resolution.get("required_row", ""))
		if not required_row.is_empty() and str(instance.position.get("row", "")) != required_row:
			continue
		var required_orientation := str(resolution.get("required_orientation", ""))
		if not required_orientation.is_empty() and str(instance.orientation) != required_orientation:
			continue
		if bool(resolution.get("only_during_opponent_turn", false)) and int(instance.controller) == int(_state.active_player):
			continue
		return true
	return false

func _view_card_for_hidden_hand(card: Dictionary) -> Dictionary:
	var hidden := card.duplicate(true)
	var definition_id := str(hidden.get("definition_id", "hidden_hand_card"))
	hidden["face"] = "face_down"
	hidden["current_cost"] = 0
	hidden["current_hp"] = 0
	hidden["definition"] = {
		"id": definition_id,
		"name": "未知手牌",
		"type": "hidden_hand",
		"cost": 0,
		"power": 0,
		"hp": 0,
		"text": ""
	}
	return hidden


func _morale_definition_for_player(player_index: int) -> Dictionary:
	var image_path := ""
	var logical_player_index := _logical_player_for_display(player_index)
	if logical_player_index >= 0 and logical_player_index < _state.players.size():
		var master_id := str(_state.get_player(logical_player_index).master_definition_id)
		image_path = str(MORALE_IMAGE_BY_MASTER_ID.get(master_id, ""))
	return {
		"id": "sys_morale",
		"name": "士气",
		"type": "morale",
		"image_path": image_path,
		"text": ""
	}


func _build_master_view_card(player_index: int) -> Dictionary:
	var logical_player_index := _logical_player_for_display(player_index)
	var player_state = _state.get_player(logical_player_index)
	var definition_id := str(player_state.master_definition_id)
	var definition: Dictionary = _card_definitions.get(definition_id, {
		"id": definition_id,
		"name": player_state.master_name,
		"type": "master",
		"text": ""
	}).duplicate(true)
	var master_uid := "master_%d" % logical_player_index
	var master_view: Dictionary = _master_view_cards_by_player.get(player_index, {})
	if master_view.is_empty():
		master_view = {"uid": master_uid}
		_master_view_cards_by_player[player_index] = master_view
	master_view["uid"] = master_uid
	master_view["definition_id"] = definition_id
	master_view["definition"] = definition
	master_view["owner"] = player_index
	master_view["zone"] = "master"
	master_view["orientation"] = "active"
	return master_view


func _append_new_event_logs() -> void:
	if _state == null:
		return
	for event in _state.event_log:
		var event_id = int(event.event_id)
		if event_id <= _last_logged_event_id:
			continue
		_last_logged_event_id = event_id
		var line := _format_event_log_line(event)
		if not line.is_empty():
			_push_log(line)
		_queue_animation_for_event(event)


func _queue_animation_for_event(event) -> void:
	if event == null:
		return
	if str(event.created_by_command) == "setup":
		return
	match str(event.type):
		"CardDrawn":
			_pending_animations.append({
				"kind": "deck_to_hand",
				"player": _display_player_for_logical(int(event.player_id)),
				"card_uid": str(event.payload.get("card_id", "")),
				"delay": 0.0
			})
		"MoraleAdded":
			var player_index := _display_player_for_logical(int(event.player_id))
			if player_index < 0 or player_index >= _players.size():
				return
			var target_index: int = max(0, _players[player_index]["cost_area"].size() - 1)
			_pending_animations.append({
				"kind": "cost_to_area",
				"player": player_index,
				"target_index": target_index,
				"delay": 0.0
			})
		"CalamityRevealed":
			_pending_animations.append({
				"kind": "calamity_reveal",
				"player": _display_player_for_logical(int(event.player_id)),
				"calamity_id": str(event.payload.get("calamity_id", "")),
				"delay": 0.0
			})
		"AttackDeclared":
			_pending_animations.append({
				"kind": "attack_declared",
				"attacker_id": str(event.payload.get("attacker_id", "")),
				"target_kind": str(event.payload.get("target_kind", "card")),
				"defender_id": str(event.payload.get("defender_id", "")),
				"target_player": int(event.payload.get("target_player", -1)),
				"delay": 0.0
			})
			var attack_notice_text := _attack_declared_notice_text(event.payload)
			if not attack_notice_text.is_empty():
				_pending_animations.append({
					"kind": "banner",
					"text": attack_notice_text,
					"effect": "attack_notice",
					"delay": 0.0
				})
		"CardPlayed":
			var played_card_id := str(event.payload.get("card_id", ""))
			_pending_animations.append({
				"kind": "card_focus",
				"card_id": played_card_id,
				"effect": "play",
				"delay": 0.0
			})
			var play_notice_text := _played_card_notice_banner_text(played_card_id, int(event.player_id))
			if not play_notice_text.is_empty():
				_pending_animations.append({
					"kind": "banner",
					"text": play_notice_text,
					"effect": "card_play_notice",
					"delay": 0.0
				})
		"EffectPutOnStack":
			var put_source_id := str(event.payload.get("source_id", event.payload.get("source_instance_id", "")))
			var put_notice_text := _effect_notice_banner_text(put_source_id, str(event.payload.get("effect_id", "")), int(event.player_id), false)
			if not put_notice_text.is_empty():
				_pending_animations.append({
					"kind": "banner",
					"text": put_notice_text,
					"effect": "effect_notice",
					"delay": 0.0
				})
		"EffectResolved":
			var resolved_source_id := str(event.payload.get("source_id", event.payload.get("source_instance_id", "")))
			var resolved_notice_text := _effect_notice_banner_text(resolved_source_id, str(event.payload.get("effect_id", "")), int(event.player_id), true)
			if not resolved_notice_text.is_empty():
				_pending_animations.append({
					"kind": "banner",
					"text": resolved_notice_text,
					"effect": "effect_notice",
					"delay": 0.0
				})
		"DamageDealt":
			_pending_animations.append({
				"kind": "attack_exchange",
				"attacker_id": str(event.payload.get("attacker_id", "")),
				"defender_id": str(event.payload.get("defender_id", "")),
				"delay": 0.0
			})
		"CardMoved":
			_pending_animations.append({
				"kind": "card_focus",
				"card_id": str(event.payload.get("card_id", "")),
				"effect": "move",
				"delay": 0.0
			})
		"CardDamaged":
			_pending_animations.append({
				"kind": "card_focus",
				"card_id": str(event.payload.get("target_card_id", event.payload.get("card_id", ""))),
				"effect": "damage",
				"delay": 0.0
			})
		"CardReadied":
			_pending_animations.append({
				"kind": "card_focus",
				"card_id": str(event.payload.get("card_id", "")),
				"effect": "ready",
				"delay": 0.0
			})
		"MoraleConsumed":
			_pending_animations.append({
				"kind": "card_focus",
				"card_id": str(event.payload.get("card_id", "")),
				"effect": "morale_spent",
				"delay": 0.0
			})
		"MoraleReadied":
			_pending_animations.append({
				"kind": "card_focus",
				"card_id": str(event.payload.get("card_id", "")),
				"effect": "morale_ready",
				"delay": 0.0
			})
		"MasterDamaged":
			_pending_animations.append({
				"kind": "master_focus",
				"player": _display_player_for_logical(int(event.player_id)),
				"effect": "master_damage",
				"amount": int(event.payload.get("amount", 0)),
				"delay": 0.0
			})
		"DiceRolled":
			_pending_animations.append({
				"kind": "dice_roll",
				"player": _display_player_for_logical(int(event.player_id)),
				"result": int(event.payload.get("result", 0)),
				"sides": int(event.payload.get("sides", 6)),
				"card_id": str(event.payload.get("card_id", "")),
				"delay": 0.0
			})
		"MasterGuarded":
			_pending_animations.append({
				"kind": "master_focus",
				"player": int(event.player_id),
				"effect": "master_guard",
				"delay": 0.0
			})
		"AttackCountered":
			_pending_animations.append({
				"kind": "banner",
				"text": "进攻无效",
				"effect": "attack_countered",
				"delay": 0.0
			})
		"SupportPreventedDeath":
			_pending_animations.append({
				"kind": "support_save",
				"defender_id": str(event.payload.get("defender_id", "")),
				"supporter_id": str(event.payload.get("supporter_id", "")),
				"delay": 0.0
			})
		"AttackFinished":
			_pending_animations.append({
				"kind": "banner",
				"text": "攻击结算",
				"effect": "attack_finish",
				"delay": 0.0
			})
		"CardsRevealedToOpponent", "CardsRevealedToAll", "CardsViewedPrivately":
			if _should_show_revealed_cards_animation(event):
				_pending_animations.append({
					"kind": "reveal_cards_popup",
					"title": str(event.payload.get("title", "展示的卡牌")),
					"card_ids": event.payload.get("card_ids", []).duplicate() if event.payload.get("card_ids", []) is Array else [],
					"delay": 0.0
				})


func _format_event_log_line(event) -> String:
	var player_name := ""
	var display_player_id := _display_player_for_logical(int(event.player_id))
	if display_player_id >= 0 and display_player_id < _players.size():
		player_name = str(_players[display_player_id].get("name", "玩家"))
	var payload: Dictionary = {}
	if event.payload is Dictionary:
		payload = event.payload
	match str(event.type):
		"GameStarted":
			return "对局开始。"
		"PhaseChanged":
			return "阶段进入：%s。" % str(payload.get("phase", ""))
		"CardPlayed":
			var played_notice := _played_card_notice_banner_text(str(payload.get("card_id", "")), int(event.player_id))
			if not played_notice.is_empty():
				return "%s。" % played_notice
			return "%s 打出 %s。" % [player_name, _card_name(str(payload.get("card_id", "")))]
		"EffectPutOnStack":
			var put_notice := _effect_notice_banner_text(str(payload.get("source_id", payload.get("source_instance_id", ""))), str(payload.get("effect_id", "")), int(event.player_id), false)
			if not put_notice.is_empty():
				return "%s。" % put_notice
			return "%s 的效果进入堆叠。" % _card_name(str(payload.get("source_id", "")))
		"EffectResolved":
			var resolved_notice := _effect_notice_banner_text(str(payload.get("source_id", payload.get("source_instance_id", ""))), str(payload.get("effect_id", "")), int(event.player_id), true)
			if not resolved_notice.is_empty():
				return "%s。" % resolved_notice
			return "%s 的效果已结算。" % _card_name(str(payload.get("source_id", "")))
		"AttackDeclared":
			var attack_notice := _attack_declared_notice_text(payload)
			if not attack_notice.is_empty():
				return "%s。" % attack_notice
			return "%s 宣告进攻。" % _card_name(str(payload.get("attacker_id", "")))
		"DamageDealt":
			return "%s 与 %s 交战。" % [
				_card_name(str(payload.get("attacker_id", ""))),
				_card_name(str(payload.get("defender_id", "")))
			]
		"CardMoved":
			return "%s 移动到%s排%d号位。" % [
				_card_name(str(payload.get("card_id", ""))),
				"前" if str(payload.get("to_row", "")) == "front" else "后",
				int(payload.get("to_col", payload.get("col", 0))) + 1
			]
		"AttackFinished":
			if bool(payload.get("canceled_by_dice", false)):
				return "本次进攻因掷骰失败结束。"
			return "本次攻击结算完毕。"
		"CardDrawn":
			return "%s 抽 1 张牌。" % player_name
		"MoraleAdded":
			return "%s 获得 1 点士气。" % player_name
		"MoraleConsumed":
			return "%s 消耗 1 点士气。" % player_name
		"MoraleReadied":
			return "%s 的 1 点士气恢复可用。" % player_name
		"CalamityValueChanged":
			return "天灾值变为 %d。" % int(payload.get("value", 0))
		"CalamityRevealed":
			return "翻开天灾：%s。" % _card_name(str(payload.get("calamity_id", "")))
		"CardDamaged":
			return "%s 受到伤害。" % _card_name(str(payload.get("target_card_id", payload.get("card_id", ""))))
		"CardReadied":
			return "%s 恢复活跃。" % _card_name(str(payload.get("card_id", "")))
		"CardRested":
			return "%s 转为休整。" % _card_name(str(payload.get("card_id", "")))
		"MasterDamaged":
			return "%s 受到 %d 点伤害。" % [str(_players[_display_player_for_logical(int(event.player_id))].get("master_name", "主宰")), int(payload.get("amount", 0))]
		"DiceRolled":
			var roller := player_name if not player_name.is_empty() else "玩家"
			var source_card_id := str(payload.get("card_id", ""))
			if not source_card_id.is_empty():
				roller = _card_name(source_card_id)
			return "%s 掷出 %d 点。" % [roller, int(payload.get("result", 0))]
		"MasterGuarded":
			return "%s 弃置手牌抵掉了这次对主宰的进攻。" % player_name
		"AttackCountered":
			return "%s 使本次进攻无效。" % player_name
		"SupportPreventedDeath":
			return "%s 的支援使 %s 没有被击破。" % [
				_card_name(str(payload.get("supporter_id", ""))),
				_card_name(str(payload.get("defender_id", "")))
			]
		"CardDied", "CardSentToGrave":
			return "%s 进入墓地。" % _card_name(str(payload.get("card_id", "")))
		"CardsRevealedToOpponent", "CardsRevealedToAll":
			var revealing_player := _display_player_for_logical(int(payload.get("revealing_player_id", -1)))
			var reveal_owner := "对手"
			if revealing_player >= 0 and revealing_player < _players.size():
				reveal_owner = str(_players[revealing_player].get("name", "对手"))
			var card_ids: Array = payload.get("card_ids", [])
			var shown_name := ""
			if card_ids is Array and not card_ids.is_empty():
				shown_name = _card_name(str(card_ids[0]))
			return "%s 展示了 %s。" % [reveal_owner, shown_name if not shown_name.is_empty() else "卡牌"]
		"CardsViewedPrivately":
			var viewing_player := _display_player_for_logical(int(payload.get("viewing_player_id", -1)))
			var viewer_name := "对手"
			if viewing_player >= 0 and viewing_player < _players.size():
				viewer_name = str(_players[viewing_player].get("name", "对手"))
			return "%s 查看了下一张待开启的天灾卡。" % viewer_name
		"ChoiceRequested":
			return _choice_requested_log_text(display_player_id, player_name, payload)
		"ChoiceResolved":
			return _choice_resolved_log_text(display_player_id, player_name, payload)
		"GameEnded":
			return "对局结束。"
	return ""


func _card_name(card_id: String) -> String:
	if card_id.is_empty():
		return ""
	if card_id.begins_with("master_"):
		var display_player_index := _display_player_for_logical(int(card_id.trim_prefix("master_")))
		if display_player_index >= 0 and display_player_index < _players.size():
			return str(_players[display_player_index].get("master_name", "主宰"))
	if _is_morale_source_id(card_id):
		return "阵营士气"
	var direct_definition: Dictionary = _card_definitions.get(card_id, {})
	if not direct_definition.is_empty():
		return str(direct_definition.get("name", card_id))
	if _state == null:
		return card_id
	var instance = _state.card_instances.get(card_id)
	if instance == null:
		var definition = _state.get_definition(card_id)
		if definition != null:
			return str(definition.name)
		return card_id
	var definition = _card_definitions.get(str(instance.definition_id), {})
	return str(definition.get("name", str(instance.definition_id)))


func _definition_dict_for_card(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	var direct_definition = _card_definitions.get(card_id, {})
	if direct_definition is Dictionary and not direct_definition.is_empty():
		return direct_definition
	if _state == null:
		return {}
	var instance = _state.card_instances.get(card_id)
	if instance == null:
		return {}
	var instance_definition = _card_definitions.get(str(instance.definition_id), {})
	if instance_definition is Dictionary:
		return instance_definition
	return {}


func _definition_dict_for_source(source_id: String) -> Dictionary:
	if source_id.is_empty() or source_id.begins_with("master_") or _is_morale_source_id(source_id):
		return {}
	return _definition_dict_for_card(source_id)


func _played_card_notice_banner_text(card_id: String, player_id: int) -> String:
	var definition := _definition_dict_for_card(card_id)
	var card_type := str(definition.get("type", ""))
	var type_name := ""
	match card_type:
		"tactic":
			type_name = "战术"
		"counter_tactic":
			type_name = "反击"
		_:
			return ""
	var display_player := _display_player_for_logical(player_id)
	if display_player < 0:
		display_player = _display_player_for_source(card_id)
	return "%s使用%s「%s」" % [_player_side_name(display_player), type_name, _card_name(card_id)]


func _effect_notice_banner_text(source_id: String, effect_id: String, player_id: int, resolved: bool) -> String:
	var definition := _definition_dict_for_source(source_id)
	var card_type := str(definition.get("type", ""))
	if card_type != "tactic" and card_type != "counter_tactic":
		return ""
	var effect_text := _effect_text_for_source(source_id, effect_id)
	var display_player := _display_player_for_logical(player_id)
	if display_player < 0:
		display_player = _display_player_for_source(source_id)
	var owner_text := _player_side_name(display_player)
	var source_name := _card_name(source_id)
	var state_text := "开始结算" if not resolved else "生效"
	if effect_text.is_empty():
		return "%s的%s%s" % [owner_text, source_name, state_text]
	return "%s的%s%s：%s" % [owner_text, source_name, state_text, effect_text]


func _slot_index_from_row_col(row: String, col: int) -> int:
	if row == "front":
		return col
	return 3 + col


func _row_col_from_slot_index(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= BOARD_SLOT_COUNT:
		return {}
	var row := "back"
	if slot_index < 3:
		row = "front"
	return {
		"row": row,
		"col": slot_index % 3
	}


func _phase_display_text(phase: String) -> String:
	match phase:
		"calamity":
			return "天灾阶段"
		"ready":
			return "整备阶段"
		"draw":
			return "抽牌阶段"
		"morale":
			return "士气阶段"
		"main":
			return "主阶段"
		"end":
			return "结束阶段"
	return phase


func _display_player_for_logical(logical_player_id: int) -> int:
	if not _network_mode_active or _local_player_id == PLAYER_BOTTOM:
		return logical_player_id
	return PLAYER_TOP if logical_player_id == PLAYER_BOTTOM else PLAYER_BOTTOM


func _logical_player_for_display(display_player_id: int) -> int:
	if not _network_mode_active or _local_player_id == PLAYER_BOTTOM:
		return display_player_id
	return PLAYER_TOP if display_player_id == PLAYER_BOTTOM else PLAYER_BOTTOM


func _waiting_display_player() -> int:
	return _display_player_for_logical(int(_waiting_state.get("player_id", _state.active_player if _state != null else PLAYER_BOTTOM)))


func _is_locally_controllable_player(display_player_id: int) -> bool:
	if display_player_id < 0:
		return false
	if _table_replay_active:
		return false
	if _network_mode_active:
		return _logical_player_for_display(display_player_id) == _local_player_id
	return not _ai_enabled_for_player(display_player_id)

func _should_hide_hand_from_local_player(display_player_id: int) -> bool:
	if display_player_id < 0:
		return false
	if _table_replay_active:
		return false
	if _network_mode_active:
		return not _is_locally_controllable_player(display_player_id)
	if _is_current_test_duel():
		return false
	return _ai_enabled_for_player(display_player_id)


func _is_current_test_duel() -> bool:
	return _current_duel_path == TEST_DECK_PATH or bool(_current_game_options.get("test_mode", false))


func _master_source_id_for_display(display_player_id: int) -> String:
	return "master_%d" % _logical_player_for_display(display_player_id)


func _display_target_player_from_variant(value) -> int:
	return _display_player_for_logical(int(value))


func _current_input_player() -> int:
	var waiting_player := _waiting_display_player()
	if _network_mode_active and _logical_player_for_display(waiting_player) != _local_player_id:
		return -1
	return waiting_player


func _current_local_input_player() -> int:
	var waiting_player := _current_input_player()
	if not _is_locally_controllable_player(waiting_player):
		return -1
	return waiting_player


func _player_actions(player_index: int) -> Array:
	_ensure_player_actions(player_index)
	return _actions_by_player.get(player_index, [])


func _invalidate_action_cache() -> void:
	_actions_dirty_by_player[PLAYER_BOTTOM] = true
	_actions_dirty_by_player[PLAYER_TOP] = true


func _ensure_player_actions(player_index: int) -> void:
	if _state == null or player_index < 0:
		return
	if not bool(_actions_dirty_by_player.get(player_index, true)):
		return
	var logical_player_id := _logical_player_for_display(player_index)
	var started_at := Time.get_ticks_msec()
	_actions_by_player[player_index] = _engine.get_legal_actions(_state, logical_player_id)
	_actions_dirty_by_player[player_index] = false
	_log_slow_perf("sync/legal_actions/p%s" % player_index, started_at, NETWORK_PERF_WARN_MS)


func _has_attack_action(player_index: int, attacker_id: String) -> bool:
	for action in _player_actions(player_index):
		if str(action.get("kind", "")) == "declare_attack" and str(action.get("payload_template", {}).get("attacker_id", "")) == attacker_id:
			return true
	return false


func _has_move_action(player_index: int, card_id: String) -> bool:
	for action in _player_actions(player_index):
		if str(action.get("kind", "")) == "move_legion" and str(action.get("payload_template", {}).get("card_id", "")) == card_id:
			return true
	return false


func _can_drag_hand_card(player_index: int, card_id: String) -> bool:
	if _choice_allows_drag_hand_card(player_index, card_id):
		return true
	for action in _player_actions(player_index):
		if str(action.get("kind", "")) == "play_card" and str(action.get("payload_template", {}).get("card_id", "")) == card_id:
			return true
	return _can_offer_relaxed_rollo_drag(player_index, card_id)


func _sync_choice_selection_state() -> void:
	var choice_action := _current_local_choice_action()
	var next_choice_id := str(choice_action.get("choice_id", ""))
	if next_choice_id == _active_choice_id:
		_sync_choice_selection_for_current_action(choice_action)
		return
	_active_choice_id = next_choice_id
	_choice_selected_card_ids.clear()
	_choice_reorder_dragging_card_id = ""
	_sync_choice_selection_for_current_action(choice_action)


func _sync_choice_selection_for_current_action(choice_action: Dictionary) -> void:
	var operation := str(choice_action.get("operation", ""))
	var candidate_card_ids := _string_array_from_variant_array(choice_action.get("candidate_card_ids", []))
	if operation == "search_deck_reorder_bottom" or _choice_uses_full_candidate_reorder(choice_action):
		_sync_reorder_choice_selection(candidate_card_ids)
		return
	var synced: Array[String] = []
	for card_id in _choice_selected_card_ids:
		if candidate_card_ids.has(card_id) and not synced.has(card_id):
			synced.append(card_id)
	var required_count: int = max(1, int(choice_action.get("count", 1)))
	while synced.size() > required_count:
		synced.pop_back()
	_choice_selected_card_ids = synced


func _choice_uses_full_candidate_reorder(choice_action: Dictionary) -> bool:
	var operation := str(choice_action.get("operation", ""))
	if operation == "recycle_grave_then_revive_source_from_grave":
		# Thor's hammer should always be "pick 3, then reorder the picked 3",
		# even if stale data accidentally marks the choice as full-candidate reorder.
		return false
	return bool(choice_action.get("drag_reorder_all_candidates", false))


func _find_action(actions: Array, kind: String, play_kind: String = "") -> Dictionary:
	for action in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if not play_kind.is_empty() and str(action.get("play_kind", "")) != play_kind:
			continue
		return action
	return {}


func _action_still_available(player_id: int, action: Dictionary) -> bool:
	if action.is_empty():
		return false
	var proposal_id := str(action.get("proposal_id", ""))
	if proposal_id.is_empty():
		return false
	for candidate in _player_actions(player_id):
		if str(candidate.get("proposal_id", "")) == proposal_id:
			return true
	return false


func _auto_pass_empty_response_window() -> bool:
	if _network_mode_active:
		# In network mode, implicit pass during sync can mutate state before both peers
		# finish applying the same command, which risks hash divergence.
		return false
	var did_pass := false
	var guard := 0
	while _state != null and not _game_over and _response_window_active() and _state.pending_choices.is_empty() and guard < 32:
		guard += 1
		_waiting_state = _engine.get_waiting_state(_state)
		_invalidate_action_cache()
		var player_id := _current_input_player()
		var actions := _player_actions(player_id)
		var pass_action := _find_action(actions, "pass_priority")
		if not _should_auto_skip_empty_response_window(actions, pass_action):
			break
		var result = _engine.apply_command(_state, GameCommand.create(player_id, "PassPriority"))
		if not bool(result.get("ok", false)):
			break
		_clear_self_response_followup_signature_if_matches(player_id)
		_invalidate_action_cache()
		did_pass = true
		_game_over = int(_state.winner) != -1
	return did_pass


func _should_auto_skip_empty_response_window(actions: Array = [], pass_action: Dictionary = {}) -> bool:
	if _state == null or _game_over or not _response_window_active():
		return false
	if not _state.pending_choices.is_empty():
		return false
	var response_player_id := _current_input_player()
	if response_player_id < 0:
		return false
	if _free_master_morale_prompt_active(response_player_id):
		return false
	if _network_mode_active:
		if _network_resync_in_progress or _has_pending_network_command():
			return false
	var response_actions: Array = actions
	if response_actions.is_empty():
		response_actions = _player_actions(response_player_id)
	var response_pass_action: Dictionary = pass_action
	if response_pass_action.is_empty():
		response_pass_action = _find_action(response_actions, "pass_priority")
	if response_pass_action.is_empty():
		return false
	if _self_response_followup_should_auto_pass(response_player_id):
		return true
	if _should_auto_finish_committed_master_guard(response_player_id):
		return true
	if _should_auto_finish_committed_unit_defense(response_player_id):
		return true
	return _visible_response_actions(response_actions).is_empty()


func _auto_skip_response_window_active() -> bool:
	if not _response_window_active():
		return false
	var response_player_id := _current_input_player()
	if response_player_id < 0:
		return false
	var response_actions := _player_actions(response_player_id)
	var response_pass_action := _find_action(response_actions, "pass_priority")
	return _should_auto_skip_empty_response_window(response_actions, response_pass_action)


func _hide_auto_skipped_response_panels() -> void:
	if _action_panel != null:
		_action_panel.visible = false
	if _response_panel != null:
		_response_panel.visible = false
	if _stack_panel != null:
		_stack_panel.visible = false


func _schedule_network_auto_pass_empty_response_window() -> void:
	if not _network_mode_active or _deferred_network_auto_pass_pending:
		return
	if not _should_auto_skip_empty_response_window():
		return
	_deferred_network_auto_pass_pending = true
	call_deferred("_flush_network_auto_pass_empty_response_window")


func _flush_network_auto_pass_empty_response_window() -> void:
	_deferred_network_auto_pass_pending = false
	if not _should_auto_skip_empty_response_window():
		return
	var player_id := _current_input_player()
	if player_id < 0:
		return
	if _queue_network_command(player_id, "PassPriority", {}):
		_clear_self_response_followup_signature_if_matches(player_id)
		_request_deferred_refresh()


func _response_window_active() -> bool:
	return _state != null and (not _state.pending_attack.is_empty() or not _state.stack.is_empty())


func _meaningful_response_actions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in actions:
		if _action_requires_response_choice(action):
			result.append(action)
	return result


func _visible_response_actions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in _meaningful_response_actions(actions):
		if _response_action_has_visible_source(action):
			result.append(action)
	return result


func _current_visible_response_actions() -> Array[Dictionary]:
	if not _response_window_active():
		return []
	return _visible_response_actions(_player_actions(_current_input_player()))


func _manual_response_window_active() -> bool:
	return not _current_visible_response_actions().is_empty()


func _response_action_has_visible_source(action: Dictionary) -> bool:
	for source_id in _response_action_source_ids(action):
		var rect := _source_highlight_rect(source_id)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			return true
	return false


func _direct_response_actions(actions: Array[Dictionary], exclude_actions: Array[Dictionary] = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in actions:
		if exclude_actions.has(action):
			continue
		var kind := str(action.get("kind", ""))
		if kind == "activate_effect":
			result.append(action)
			continue
		if kind != "play_card":
			continue
		var play_kind := str(action.get("play_kind", ""))
		if play_kind == "hand_response" or play_kind == "counter_tactic":
			result.append(action)
	return result


func _response_action_source_ids(action: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var kind := str(action.get("kind", ""))
	var payload: Dictionary = action.get("payload_template", {})
	if kind == "play_card":
		var card_id := str(payload.get("card_id", ""))
		if not card_id.is_empty():
			result.append(card_id)
	elif kind == "choose_defense":
		var defense_kind := str(action.get("source", {}).get("defense_kind", ""))
		for key in ["blocker_id", "supporter_id"]:
			var card_id := str(payload.get(key, ""))
			if not card_id.is_empty() and not result.has(card_id):
				result.append(card_id)
		for card_id in _string_array_from_variant_array(payload.get("master_guard_card_ids", [])):
			if defense_kind == "master_guard" and not _master_guard_card_is_currently_selectable(card_id):
				continue
			if not result.has(card_id):
				result.append(card_id)
	elif kind == "activate_effect":
		var source_id := str(payload.get("source_id", ""))
		if not source_id.is_empty():
			result.append(source_id)
	return result


func _response_highlight_actions() -> Array[Dictionary]:
	var guard_actions := _master_guard_actions_for_current_player()
	var result: Array[Dictionary] = []
	var visible_actions := _current_visible_response_actions()
	var defense_actions := _unit_defense_actions_from_list(visible_actions)
	var selected_defense_action := _selected_unit_defense_action_for_current_player()
	if not selected_defense_action.is_empty() and _selected_source_id.is_empty():
		result.append_array(guard_actions)
		if not result.has(selected_defense_action):
			result.append(selected_defense_action)
		return result
	if not defense_actions.is_empty() and _selected_source_id.is_empty():
		result.append_array(guard_actions)
		for action in defense_actions:
			if not result.has(action):
				result.append(action)
		return result
	result.append_array(guard_actions)
	for action in visible_actions:
		if not result.has(action):
			result.append(action)
	return result


func _free_master_morale_prompt_active(player_id: int) -> bool:
	if _state == null or player_id < 0 or player_id >= _state.players.size():
		return false
	var player = _state.get_player(_logical_player_for_display(player_id))
	return int(player.flags.get("free_master_morale_effect_activation_turn", -1)) == int(_state.turn_number) \
		and int(player.flags.get("free_master_morale_effect_activation_count", 0)) > 0


func _action_matches_free_master_morale_prompt(action: Dictionary, player_id: int) -> bool:
	if str(action.get("kind", "")) != "activate_effect":
		return false
	var source_id := str(action.get("payload_template", {}).get("source_id", ""))
	if source_id != _master_source_id_for_display(player_id):
		return false
	var effect_id := str(action.get("payload_template", {}).get("effect_id", ""))
	var original_cost := _effect_cost_for_source(source_id, effect_id)
	return int(original_cost.get("morale", 0)) > 0


func _collect_free_master_morale_prompt_actions(player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in _player_actions(player_id):
		if _action_matches_free_master_morale_prompt(action, player_id):
			result.append(action)
	return result


func _action_requires_response_choice(action: Dictionary) -> bool:
	var kind := str(action.get("kind", ""))
	if kind == "pass_priority" or kind == "end_phase":
		return false
	if kind == "play_card":
		var play_kind := str(action.get("play_kind", ""))
		return play_kind == "hand_response" or play_kind == "counter_tactic"
	if kind == "choose_defense":
		return true
	if kind == "activate_effect":
		# During a response window, get_activatable_effects() has already filtered out
		# non-respondable activations. Treat every remaining activation as a visible
		# response choice so set counter tactics like 复仇血鹰 stay highlighted.
		return true
	return false


func _execute_command(player_id: int, command_type: String, payload: Dictionary) -> bool:
	if _state == null or player_id < 0:
		return false
	if _network_mode_active:
		return _queue_network_command(player_id, command_type, payload)
	var logical_player_id := _logical_player_for_display(player_id)
	var result := _apply_engine_command(logical_player_id, command_type, payload)
	if not bool(result.get("ok", false)):
		_push_log("操作失败：%s" % str(result.get("error_code", "UNKNOWN")))
		_sync_from_engine()
		_refresh()
		return false
	_sync_from_engine()
	if _should_auto_continue_turn_flow():
		_continue_local_end_phase_sequence()
	_refresh()
	return true


func _should_auto_continue_turn_flow() -> bool:
	if _state == null or _game_over:
		return false
	if not _state.pending_choices.is_empty() or not _state.stack.is_empty() or not _state.pending_attack.is_empty():
		return false
	if _state.phase == "main":
		return false
	var active_player_id := int(_state.active_player)
	var active_actions: Array = _engine.get_legal_actions(_state, active_player_id)
	return not _find_action(active_actions, "end_phase").is_empty()


func _continue_local_end_phase_sequence() -> void:
	var guard := 0
	while _state != null and not _game_over and guard < 8:
		if not _state.pending_choices.is_empty() or not _state.stack.is_empty() or not _state.pending_attack.is_empty():
			break
		if _state.phase == "main":
			break
		var active_player_id := int(_state.active_player)
		var active_actions: Array = _engine.get_legal_actions(_state, active_player_id)
		if _find_action(active_actions, "end_phase").is_empty():
			break
		var result := _apply_engine_command(active_player_id, "EndPhase", {})
		if not bool(result.get("ok", false)):
			break
		_sync_from_engine()
		guard += 1


func _execute_command_locally(player_id: int, command_type: String, payload: Dictionary, push_fail_log: bool = true, player_id_is_logical: bool = false, refresh_mode: int = REFRESH_MODE_IMMEDIATE, sync_from_engine_after: bool = true) -> bool:
	if _table_replay_active:
		if push_fail_log:
			_push_log("回放模式不可操作。")
		return false
	if _state == null or player_id < 0:
		return false
	var logical_player_id := player_id if player_id_is_logical else _logical_player_for_display(player_id)
	var result := _apply_engine_command(logical_player_id, command_type, payload)
	if not bool(result.get("ok", false)):
		if push_fail_log:
			_push_log(_command_failure_text(command_type, payload, result))
		if sync_from_engine_after:
			_sync_from_engine()
		_apply_refresh_mode(refresh_mode)
		return false
	if sync_from_engine_after:
		_sync_from_engine()
	_apply_refresh_mode(refresh_mode)
	return true


func _apply_refresh_mode(refresh_mode: int) -> void:
	if refresh_mode == REFRESH_MODE_NONE:
		return
	if refresh_mode == REFRESH_MODE_DEFERRED:
		_request_deferred_refresh()
		return
	_refresh()


func _apply_engine_command(logical_player_id: int, command_type: String, payload: Dictionary) -> Dictionary:
	_append_file_log("[CMD] P%s %s %s" % [logical_player_id, command_type, JSON.stringify(payload)])
	var started_at := Time.get_ticks_msec()
	var result = _engine.apply_command(_state, GameCommand.create(logical_player_id, command_type, payload))
	_log_slow_perf("apply/%s" % command_type, started_at, NETWORK_PERF_WARN_MS)
	if not bool(result.get("ok", false)):
		_append_file_log("[FAIL] P%s %s code=%s message=%s payload=%s" % [
			logical_player_id,
			command_type,
			str(result.get("code", result.get("error_code", "UNKNOWN"))),
			str(result.get("message", "")),
			JSON.stringify(payload)
		])
	else:
		_append_file_log("[OK] P%s %s" % [logical_player_id, command_type])
	return result


func _queue_network_command(player_id: int, command_type: String, payload: Dictionary) -> bool:
	if _table_replay_active:
		_push_log("回放模式不可操作。")
		return false
	if not _network_mode_active:
		return _execute_command_locally(player_id, command_type, payload)
	var logical_player_id := _logical_player_for_display(player_id)
	if logical_player_id != _local_player_id:
		_push_log("当前联机模式下不能操作对手一侧。")
		return false
	if _has_pending_network_command():
		_push_log("联机同步中：请等待上一条操作确认后再继续。")
		if _network_status_label != null:
			_network_status_label.text = "联机同步中：正在等待房主确认上一条命令。"
		return false
	_network_command_index += 1
	var normalized_payload := _normalize_payload_for_network(payload)
	_pending_network_commands[_network_command_index] = {
		"player_id": logical_player_id,
		"command_type": command_type,
		"payload": normalized_payload.duplicate(true),
		"summary": _network_command_summary(command_type, normalized_payload),
		"sent_at_ms": Time.get_ticks_msec()
	}
	_append_file_log("[NET SEND] #%s %s" % [_network_command_index, _network_command_summary(command_type, normalized_payload)])
	if _network_is_host:
		_on_network_host_command_requested(1, logical_player_id, command_type, normalized_payload, _network_command_index)
		return true
	_network_session.request_command(logical_player_id, command_type, normalized_payload, _network_command_index)
	_push_log("已发送操作，等待房主确认。")
	return true


func _refresh_action_panel() -> void:
	if _action_panel == null:
		return
	if _auto_skip_response_window_active():
		_action_panel.visible = false
		_panel_signature_changed("action", "hidden:auto_skip")
		return
	var player_id := _current_local_input_player()
	if player_id < 0:
		_action_panel.visible = false
		_panel_signature_changed("action", "hidden:not_local_controller")
		return
	var choice_action := _current_choice_action()
	var free_master_prompt_active := _free_master_morale_prompt_active(player_id)
	if _should_use_master_attack_response_confirm_panel() and not free_master_prompt_active:
		_refresh_master_attack_response_confirm_panel(player_id)
		return
	if _manual_response_window_active() and choice_action.is_empty() and not free_master_prompt_active:
		_action_panel.visible = false
		_panel_signature_changed("action", "hidden:single_response_panel")
		return
	if _should_use_board_card_choice_confirm_panel(choice_action):
		_refresh_board_card_choice_confirm_panel(player_id, choice_action)
		return
	if _should_use_inline_move_choice_instruction_panel(choice_action):
		_refresh_inline_move_choice_instruction_panel(choice_action)
		return
	if _should_use_sacred_shackle_release_confirm_panel(player_id):
		_refresh_sacred_shackle_release_confirm_panel(player_id)
		return
	if _is_direct_hand_choice_action(choice_action):
		var direct_size := Vector2(340, 112)
		var direct_position := _popup_column_position(1, direct_size)
		var direct_title := str(choice_action.get("title", "手牌选择"))
		_action_panel.visible = true
		_action_panel.size = direct_size
		_action_panel.position = direct_position
		_action_panel_title.text = direct_title
		var required_count: int = max(1, int(choice_action.get("count", 1)))
		var direct_signature := JSON.stringify({
			"visible": true,
			"mode": "direct_hand_choice",
			"title": direct_title,
			"size": [direct_size.x, direct_size.y],
			"position": [direct_position.x, direct_position.y],
			"choice_action": choice_action,
			"selected_card_ids": _choice_selected_card_ids,
			"network_locked": _network_input_locked(),
		})
		if not _panel_signature_changed("action", direct_signature):
			return
		_clear_children(_action_panel_body)
		var confirm_button := _make_button("确认选择")
		confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var min_selected_count := _choice_min_selected_count_for_confirm(choice_action)
		confirm_button.disabled = _choice_selected_card_ids.size() < min_selected_count or _choice_selected_card_ids.size() > required_count
		confirm_button.pressed.connect(func() -> void:
			var payload = choice_action.get("payload_template", {}).duplicate(true)
			payload["selected_card_ids"] = _choice_selected_card_ids.duplicate()
			_execute_command(player_id, str(choice_action.get("command_type", "")), payload)
		)
		_action_panel_body.add_child(confirm_button)
		return
	var actions := _collect_free_master_morale_prompt_actions(player_id) if free_master_prompt_active else _collect_panel_actions(player_id)
	var prompt_action: Dictionary = _selected_target_action
	var prompt_uses_board_click := _selected_action_uses_board_click(prompt_action)
	var has_focus := _selected_morale_filter or not _selected_source_id.is_empty() or free_master_prompt_active
	var should_show: bool = (not prompt_action.is_empty() and not prompt_uses_board_click) or (has_focus and prompt_action.is_empty())
	_action_panel.visible = should_show
	var panel_size := Vector2(340, 320)
	var panel_position := _popup_column_position(1, panel_size)
	var panel_title := "可用动作"
	if _selected_morale_filter:
		panel_title = "选择阵营效果"
	elif free_master_prompt_active:
		panel_title = "免费发动主宰效果"
	elif not _selected_source_id.is_empty():
		panel_title = "选择技能：%s" % _card_name(_selected_source_id)
	elif _state != null and not _state.pending_attack.is_empty():
		panel_title = "攻击响应"
	elif _state != null and not _state.stack.is_empty():
		panel_title = "堆叠响应"
	var action_signature := JSON.stringify({
		"visible": should_show,
		"title": panel_title,
		"size": [panel_size.x, panel_size.y],
		"position": [panel_position.x, panel_position.y],
		"actions": actions,
		"focus_source_id": _selected_source_id,
		"free_master_prompt_active": free_master_prompt_active,
		"network_locked": _network_input_locked(),
		"pending_attack": _state.pending_attack if _state != null else {},
		"prompt_action": prompt_action,
		"selected_morale_filter": _selected_morale_filter,
		"stack_size": _state.stack.size() if _state != null else 0,
	})
	if not _panel_signature_changed("action", action_signature):
		return
	if not should_show:
		return
	_action_panel.size = panel_size
	_action_panel.position = panel_position
	_action_panel_title.text = panel_title
	_clear_children(_action_panel_body)
	if not prompt_action.is_empty():
		var prompt := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prompt.text = _selected_action_prompt(prompt_action)
		_action_panel_body.add_child(prompt)
		var cancel_button := _make_button("取消当前选择")
		cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel_button.pressed.connect(func() -> void:
			_clear_selection_state()
			_refresh()
		)
		_action_panel_body.add_child(cancel_button)
	elif has_focus:
		var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if _selected_morale_filter:
			hint.text = "请直接选择要发动的阵营效果。双击士气牌也会打开这里。"
		elif free_master_prompt_active:
			hint.text = "信仰狂热者效果已生效：本次可无视士气消耗发动1次主宰效果。这里只显示原本需要消耗士气的主宰效果，选择后不会消耗士气。"
		else:
			hint.text = _source_action_focus_hint(_selected_source_id, actions)
		_action_panel_body.add_child(hint)
		var back_button := _make_button("稍后再说" if free_master_prompt_active else "返回")
		back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back_button.pressed.connect(func() -> void:
			_clear_action_focus()
			_selected_attacker_uid = ""
			_selected_stack_target_id = ""
			_refresh()
		)
		_action_panel_body.add_child(back_button)
	if not actions.is_empty():
		if not prompt_action.is_empty() or has_focus:
			var separator := HSeparator.new()
			_action_panel_body.add_child(separator)
		for action in actions:
			var action_copy: Dictionary = action
			var button := _make_button(_action_button_text(action_copy))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = _network_input_locked()
			button.pressed.connect(func() -> void:
				_on_panel_action_pressed(action_copy)
			)
			_action_panel_body.add_child(button)


func _refresh_response_panel() -> void:
	if _response_panel == null:
		return
	if _should_use_master_attack_response_confirm_panel():
		_response_panel.visible = false
		_panel_signature_changed("response", "hidden:master_attack_confirm_panel")
		return
	if _selected_action_uses_board_click(_selected_target_action):
		_response_panel.visible = false
		_panel_signature_changed("response", "hidden:board_target_selection")
		return
	if not _current_choice_action().is_empty():
		_response_panel.visible = false
		_panel_signature_changed("response", "hidden:choice")
		return
	if not _response_window_active():
		_response_panel.visible = false
		_panel_signature_changed("response", "hidden:inactive")
		return
	var response_player_id := _current_local_input_player()
	if response_player_id < 0:
		_response_panel.visible = false
		_panel_signature_changed("response", "hidden:not_local_controller")
		return
	var response_actions := _player_actions(response_player_id)
	var response_meaningful_actions := _visible_response_actions(response_actions)
	var response_pass_action := _find_action(response_actions, "pass_priority")
	if _should_auto_skip_empty_response_window(response_actions, response_pass_action):
		_response_panel.visible = false
		_panel_signature_changed("response", "hidden:auto_skip")
		return
	var has_manual_response_ui := not response_meaningful_actions.is_empty() or not response_pass_action.is_empty()
	if not has_manual_response_ui:
		_response_panel.visible = false
		_panel_signature_changed("response", "hidden:empty")
		return
	_response_panel.visible = true
	var response_size := Vector2(360, 260)
	var response_position := _popup_column_position(2, response_size)
	var response_title := "【%s】是否回应" % _player_side_label(response_player_id)
	_response_panel.size = response_size
	_response_panel.position = response_position
	_response_panel_title.text = response_title
	var response_defense_actions := _unit_defense_actions_from_list(response_meaningful_actions)
	var response_guard_actions := _master_guard_actions_from_list(response_meaningful_actions)
	var focused_response_actions := _focused_response_actions(response_actions)
	var direct_response_actions := _direct_response_actions(response_meaningful_actions, focused_response_actions)
	var response_signature := JSON.stringify({
		"visible": true,
		"title": response_title,
		"size": [response_size.x, response_size.y],
		"position": [response_position.x, response_position.y],
		"current_choice_action": _current_choice_action(),
		"network_pending": _network_mode_active and _has_pending_network_command(),
		"pending_attack": _state.pending_attack if _state != null else {},
		"response_actions": response_actions,
		"response_defense_actions": response_defense_actions,
		"response_guard_actions": response_guard_actions,
		"direct_response_actions": direct_response_actions,
		"focused_response_actions": focused_response_actions,
		"selected_master_guard_cards": _selected_master_guard_cards,
		"selected_unit_defense_proposal_id": _selected_unit_defense_proposal_id,
		"stack_size": _state.stack.size() if _state != null else 0,
	})
	if not _panel_signature_changed("response", response_signature):
		return
	_clear_children(_response_panel_body)
	var owner_banner := _make_label(12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	owner_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_banner.text = "当前由你代操作：%s" % _player_side_name(response_player_id)
	_response_panel_body.add_child(owner_banner)
	var summary := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = _response_summary_text(response_player_id)
	_response_panel_body.add_child(summary)
	var response_hint_text := _response_hint_text(response_player_id, response_meaningful_actions, response_guard_actions, focused_response_actions, response_pass_action)
	if not response_hint_text.is_empty():
		var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.text = response_hint_text
		_response_panel_body.add_child(hint)
	if _network_mode_active and _has_pending_network_command():
		var waiting_hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		waiting_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		waiting_hint.text = "联机同步中：正在等待房主确认上一条响应。"
		_response_panel_body.add_child(waiting_hint)
	if not response_defense_actions.is_empty() or not response_guard_actions.is_empty():
		_add_response_section_separator()
		_build_defense_response_section(response_meaningful_actions)
	if not direct_response_actions.is_empty():
		_add_response_section_separator()
		var direct_title := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		direct_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		direct_title.text = "%s 可直接发动以下回应：" % _response_owner_tag(response_player_id)
		_response_panel_body.add_child(direct_title)
		_build_response_action_buttons(direct_response_actions)
	if not focused_response_actions.is_empty():
		_add_response_section_separator()
		var focus_title := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		focus_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		focus_title.text = "%s 已选择回应：%s" % [_response_owner_tag(response_player_id), _card_name(_selected_source_id)]
		_response_panel_body.add_child(focus_title)
		_build_response_action_buttons(focused_response_actions)
	if not response_pass_action.is_empty():
		_add_response_section_separator()
		var pass_button := _make_button(_response_action_button_text(response_pass_action, response_player_id))
		pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pass_button.disabled = _network_input_locked()
		pass_button.pressed.connect(func() -> void:
			_selected_master_guard_cards.clear()
			_selected_unit_defense_proposal_id = ""
			_on_panel_action_pressed(response_pass_action)
		)
		_response_panel_body.add_child(pass_button)


func _add_response_section_title(text: String) -> void:
	var title := _make_label(12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	title.text = text
	_response_panel_body.add_child(title)


func _add_response_section_separator() -> void:
	var separator := HSeparator.new()
	_response_panel_body.add_child(separator)


func _defense_actions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in actions:
		if str(action.get("kind", "")) == "choose_defense":
			result.append(action)
	return result


func _response_card_actions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in actions:
		if str(action.get("kind", "")) != "play_card":
			continue
		var play_kind := str(action.get("play_kind", ""))
		if play_kind == "hand_response" or play_kind == "counter_tactic":
			result.append(action)
	return result


func _stack_response_actions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in actions:
		var kind := str(action.get("kind", ""))
		if kind == "play_card" and str(action.get("play_kind", "")) == "counter_tactic":
			result.append(action)
			continue
		if kind == "activate_effect" and _targets_are_stack_only(action.get("targets", [])):
			result.append(action)
	return result


func _build_defense_response_section(actions: Array[Dictionary]) -> void:
	var guard_actions := _master_guard_actions_from_list(actions)
	var response_player_id := _current_input_player()
	var unit_defense_actions := _unit_defense_actions_from_list(actions)
	if not unit_defense_actions.is_empty():
		_build_unit_defense_picker(unit_defense_actions, response_player_id)
	if not guard_actions.is_empty():
		if not unit_defense_actions.is_empty():
			_add_response_section_separator()
		_build_master_guard_picker(guard_actions)


func _build_master_guard_picker(actions: Array[Dictionary]) -> void:
	var response_player_id := _current_input_player()
	var required_power := _current_pending_attack_required_guard_power()
	var selected_power := _selected_master_guard_power_total()
	var title := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = "%s 主宰护主：从高亮手牌中选择要弃置的牌" % _response_owner_tag(response_player_id)
	_response_panel_body.add_child(title)
	var unique_card_ids: Array[String] = []
	for action in actions:
		var guard_ids: Array = action.get("payload_template", {}).get("master_guard_card_ids", [])
		for raw_guard_id in guard_ids:
			var guard_id := str(raw_guard_id)
			if not unique_card_ids.has(guard_id):
				unique_card_ids.append(guard_id)
	for guard_id in unique_card_ids:
		var prefix := "[已选] " if _selected_master_guard_cards.has(guard_id) else ""
		var button := _make_button("%s%s %s（兵力%d）" % [prefix, _response_owner_tag(response_player_id), _card_name(guard_id), _card_power_value(guard_id)])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = _network_input_locked() or (not _selected_master_guard_cards.has(guard_id) and not _master_guard_card_is_currently_selectable(guard_id))
		button.pressed.connect(func() -> void:
			_toggle_master_guard_card(guard_id)
		)
		_response_panel_body.add_child(button)
	var selected_text := "当前未选择护主手牌。"
	if not _selected_master_guard_cards.is_empty():
		selected_text = "当前选择：%s" % _join_card_names_by_ids(_selected_master_guard_cards)
	var selected_label := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.text = "%s %s\n已选兵力：%d / 需要抵挡：%d" % [_response_owner_tag(response_player_id), selected_text, selected_power, required_power]
	_response_panel_body.add_child(selected_label)
	var matched_action := _matching_master_guard_action(actions, _selected_master_guard_cards)
	if matched_action.is_empty():
		var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.text = "%s 继续选择手牌；当已选兵力足以挡住这次攻击时，就会视为选完，不能再多选。" % _response_owner_tag(response_player_id)
		_response_panel_body.add_child(hint)
	else:
		var confirm_button := _make_button("%s 确认弃牌护主" % _response_owner_tag(response_player_id))
		confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		confirm_button.disabled = _network_input_locked()
		confirm_button.pressed.connect(func() -> void:
			_on_panel_action_pressed(matched_action)
		)
		_response_panel_body.add_child(confirm_button)
	if not _selected_master_guard_cards.is_empty():
		var clear_button := _make_button("%s 清空护主选择" % _response_owner_tag(response_player_id))
		clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clear_button.disabled = _network_input_locked()
		clear_button.pressed.connect(func() -> void:
			_selected_master_guard_cards.clear()
			_refresh()
		)
		_response_panel_body.add_child(clear_button)


func _toggle_master_guard_card(card_id: String) -> void:
	if _master_guard_feedback_locked():
		return
	if _selected_master_guard_cards.has(card_id):
		_selected_master_guard_cards.erase(card_id)
	else:
		if not _master_guard_card_is_currently_selectable(card_id):
			return
		_selected_master_guard_cards.append(card_id)
	_master_guard_feedback_text = ""
	_refresh()


func _unit_defense_actions_from_list(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in actions:
		if str(action.get("kind", "")) != "choose_defense":
			continue
		var defense_kind := str(action.get("source", {}).get("defense_kind", ""))
		if defense_kind == "master_guard":
			continue
		result.append(action)
	return result


func _selected_unit_defense_action_for_current_player() -> Dictionary:
	var selected_id := _selected_unit_defense_proposal_id
	if selected_id.is_empty():
		return {}
	for action in _unit_defense_actions_from_list(_player_actions(_current_input_player())):
		if str(action.get("proposal_id", "")) == selected_id:
			return action
	return {}


func _toggle_unit_defense_action(action: Dictionary) -> void:
	if action.is_empty():
		return
	var proposal_id := str(action.get("proposal_id", ""))
	if proposal_id.is_empty():
		return
	if _selected_unit_defense_proposal_id == proposal_id:
		_selected_unit_defense_proposal_id = ""
	else:
		_selected_unit_defense_proposal_id = proposal_id
	_selected_master_guard_cards.clear()
	_refresh()


func _selected_unit_defense_text(action: Dictionary) -> String:
	if action.is_empty():
		return "当前未选择防守牌。"
	var payload: Dictionary = action.get("payload_template", {})
	var defense_kind := str(action.get("source", {}).get("defense_kind", ""))
	if defense_kind == "supporter":
		return "当前选择：%s 为被攻击军团提供后排支援。" % _card_name(str(payload.get("supporter_id", "")))
	if defense_kind == "blocker":
		return "当前选择：%s 作为前排防守军团承受这次攻击。" % _card_name(str(payload.get("blocker_id", "")))
	return "当前选择：%s" % _action_button_text(action)


func _build_unit_defense_picker(actions: Array[Dictionary], response_player_id: int) -> void:
	var title := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = "%s 军团防守：请直接点击棋盘上的高亮军团。" % _response_owner_tag(response_player_id)
	_response_panel_body.add_child(title)
	var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "%s 后排支援只会高亮被攻击前排同列、且兵力合计足够的后排军团；点中高亮军团后会直接按当前防守方式提交。" % _response_owner_tag(response_player_id)
	_response_panel_body.add_child(hint)


func _master_guard_actions_for_current_player() -> Array[Dictionary]:
	return _master_guard_actions_from_list(_player_actions(_current_input_player()))


func _master_guard_actions_from_list(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in actions:
		if str(action.get("kind", "")) != "choose_defense":
			continue
		if str(action.get("source", {}).get("defense_kind", "")) != "master_guard":
			continue
		result.append(action)
	return result


func _matching_master_guard_action(actions: Array, selected_cards: Array[String]) -> Dictionary:
	if selected_cards.is_empty():
		return {}
	for action in actions:
		var payload: Dictionary = action.get("payload_template", {})
		var guard_ids: Array = payload.get("master_guard_card_ids", [])
		if _same_card_id_sets(_string_array_from_variant_array(guard_ids), selected_cards):
			return action
	return {}


func _master_guard_actions_for_pending_attack_target() -> Array[Dictionary]:
	if _state == null or _state.pending_attack.is_empty():
		return []
	if str(_state.pending_attack.get("target_kind", "card")) != "master":
		return []
	var guard_player := _display_target_player_from_variant(_state.pending_attack.get("target_player", -1))
	if guard_player < 0:
		return []
	return _master_guard_actions_from_list(_player_actions(guard_player))


func _pending_attack_has_committed_master_guard_for_player(player_id: int) -> bool:
	if _state == null or _state.pending_attack.is_empty() or player_id < 0:
		return false
	var attack: Dictionary = _state.pending_attack
	if str(attack.get("target_kind", "card")) != "master":
		return false
	if _display_target_player_from_variant(attack.get("target_player", -1)) != player_id:
		return false
	return not _string_array_from_variant_array(attack.get("master_guard_card_ids", [])).is_empty()


func _should_auto_finish_committed_master_guard(player_id: int) -> bool:
	if _state == null or _game_over or player_id < 0:
		return false
	if not _state.stack.is_empty():
		return false
	return _pending_attack_has_committed_master_guard_for_player(player_id)


func _pending_attack_has_committed_unit_defense_for_player(player_id: int) -> bool:
	if _state == null or _state.pending_attack.is_empty() or player_id < 0:
		return false
	var attack: Dictionary = _state.pending_attack
	if str(attack.get("target_kind", "card")) == "master":
		return false
	var defender_id := str(attack.get("defender_id", ""))
	if _display_player_for_source(defender_id) != player_id:
		return false
	return not str(attack.get("blocker_id", "")).is_empty() or not str(attack.get("supporter_id", "")).is_empty()


func _should_auto_finish_committed_unit_defense(player_id: int) -> bool:
	if _state == null or _game_over or player_id < 0:
		return false
	if not _state.stack.is_empty():
		return false
	return _pending_attack_has_committed_unit_defense_for_player(player_id)


func _master_guard_card_is_currently_selectable(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	if _master_guard_feedback_locked():
		return false
	var actions := _master_guard_actions_for_current_player()
	if actions.is_empty():
		return false
	if _selected_master_guard_cards.has(card_id):
		return true
	if not _matching_master_guard_action(actions, _selected_master_guard_cards).is_empty():
		return false
	for action in actions:
		var payload: Dictionary = action.get("payload_template", {})
		var guard_ids := _string_array_from_variant_array(payload.get("master_guard_card_ids", []))
		if not guard_ids.has(card_id):
			continue
		var matches_selection := true
		for selected_card_id in _selected_master_guard_cards:
			if not guard_ids.has(selected_card_id):
				matches_selection = false
				break
		if matches_selection:
			return true
	return false


func _same_card_id_sets(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	var left_copy: Array[String] = left.duplicate()
	var right_copy: Array[String] = right.duplicate()
	left_copy.sort()
	right_copy.sort()
	for i in range(left_copy.size()):
		if left_copy[i] != right_copy[i]:
			return false
	return true


func _string_array_from_variant_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _join_card_names_by_ids(card_ids: Array[String]) -> String:
	var names: Array[String] = []
	for card_id in card_ids:
		names.append(_card_name(card_id))
	return " + ".join(names)


func _build_response_action_buttons(actions: Array[Dictionary]) -> void:
	var response_player_id := _current_input_player()
	for action in actions:
		var action_copy: Dictionary = action
		var button := _make_button(_response_action_button_text(action_copy, response_player_id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = _network_input_locked()
		button.pressed.connect(func() -> void:
			_on_panel_action_pressed(action_copy)
		)
		_response_panel_body.add_child(button)


func _collect_panel_actions(player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in _player_actions(player_id):
		var kind := str(action.get("kind", ""))
		if kind == "activate_effect":
			var action_source_id := str(action.get("payload_template", {}).get("source_id", ""))
			if not _selected_source_id.is_empty() and action_source_id != _selected_source_id:
				continue
			if _selected_morale_filter and not _is_morale_source_id(action_source_id):
				continue
			result.append(action)
			continue
		if not _selected_source_id.is_empty() or _selected_morale_filter:
			continue
		if kind == "pass_priority" or kind == "choose_defense":
			result.append(action)
		elif kind == "play_card":
			var play_kind := str(action.get("play_kind", ""))
			if play_kind == "hand_response" or play_kind == "counter_tactic":
				result.append(action)
	return result


func _action_requires_morale_cost(action: Dictionary) -> bool:
	var payload: Dictionary = action.get("payload_template", {})
	var source_id := str(payload.get("source_id", ""))
	var effect_id := str(payload.get("effect_id", ""))
	if source_id.is_empty() or effect_id.is_empty():
		return false
	var cost: Dictionary = action.get("cost", {})
	if cost.is_empty():
		cost = _effect_cost_for_source(source_id, effect_id)
	return int(cost.get("morale", 0)) > 0


func _is_morale_source_id(source_id: String) -> bool:
	return source_id.begins_with("morale_") and source_id.trim_prefix("morale_").is_valid_int()


func _action_button_text(action: Dictionary) -> String:
	var kind := str(action.get("kind", ""))
	var source: Dictionary = action.get("source", {})
	var card_name := str(source.get("card_name", ""))
	var effect_text := _action_effect_text(action)
	match kind:
		"pass_priority":
			if not _state.pending_attack.is_empty():
				if str(_state.pending_attack.get("target_kind", "card")) == "master":
					return "放弃护主，直接承受本次攻击"
				return "放弃响应，继续结算攻击"
			if not _state.stack.is_empty():
				return "放弃响应，继续结算效果"
			return "让过优先权"
		"activate_effect":
			var cost_text := _action_cost_suffix(action)
			if _targets_are_stack_only(action.get("targets", [])):
				return "反制：%s%s" % [_join_non_empty([card_name, effect_text], " - "), _stack_target_selection_suffix(action)]
			return "发动：%s%s" % [_join_non_empty([card_name, effect_text], " - "), cost_text]
		"play_card":
			if effect_text.is_empty():
				return "打出：%s" % card_name
			var play_kind := str(action.get("play_kind", ""))
			if play_kind == "counter_tactic":
				return "反制打出：%s" % _join_non_empty([card_name, effect_text], " - ")
			if play_kind == "hand_response":
				return "响应打出：%s" % _join_non_empty([card_name, effect_text], " - ")
			return "打出：%s - %s" % [card_name, effect_text]
		"choose_defense":
			var defense_kind := str(action.get("source", {}).get("defense_kind", ""))
			var suffix := _choose_defense_action_suffix()
			if defense_kind == "supporter":
				return "后排支援：%s%s" % [card_name, suffix]
			if defense_kind == "master_guard":
				return "手牌护主：%s%s" % [card_name, suffix]
			return "前排防守：%s%s" % [card_name, suffix]
	return str(action.get("label", "动作"))


func _action_effect_text(action: Dictionary) -> String:
	var source: Dictionary = action.get("source", {})
	var effect_text := str(action.get("effect_text", source.get("effect_text", action.get("label", ""))))
	return _clean_display_text(effect_text)


func _selected_action_prompt(action: Dictionary) -> String:
	var targets = action.get("targets", [])
	if _targets_are_stack_only(targets):
		return "请在堆叠面板中选择要响应的效果。"
	var target_parts: Array[String] = []
	var has_slot := false
	var has_card := false
	var has_master := false
	for target in targets:
		if not (target is Dictionary):
			continue
		if target.has("row"):
			has_slot = true
			continue
		match str(target.get("target_kind", "")):
			"card":
				has_card = true
			"master":
				has_master = true
	if has_slot:
		target_parts.append("落位")
	if has_card:
		target_parts.append("单位")
	if has_master:
		target_parts.append("主宰")
	if target_parts.is_empty():
		return "请点击目标。"
	return "请点击目标%s。" % " / ".join(target_parts)


func _source_action_focus_hint(source_id: String, actions: Array) -> String:
	var action_count := actions.size()
	if source_id.begins_with("master_"):
		if action_count > 1:
			return "该主宰有多个可用技能。请先选择要发动的技能，再点击目标。"
		return "该主宰技能已就绪。若需要指定目标，点击发亮单位即可。"
	if action_count > 1:
		return "该来源当前有多个可用效果。请先选择其一，再点击目标。"
	return "该来源效果已就绪。若需要指定目标，点击发亮对象即可。"


func _action_cost_suffix(action: Dictionary) -> String:
	var payload: Dictionary = action.get("payload_template", {})
	var source_id := str(payload.get("source_id", ""))
	var effect_id := str(payload.get("effect_id", ""))
	var cost: Dictionary = action.get("cost", {})
	if cost.is_empty():
		cost = _effect_cost_for_source(source_id, effect_id)
	if cost.is_empty():
		return ""
	var cost_parts: Array[String] = []
	var morale_cost := int(cost.get("morale", 0))
	if morale_cost > 0:
		cost_parts.append("消耗%d士气" % morale_cost)
	var discard_cost := int(cost.get("discard_cards", 0))
	if discard_cost > 0:
		cost_parts.append("弃%d张牌" % discard_cost)
	if cost_parts.is_empty():
		return ""
	return "（%s）" % "，".join(cost_parts)


func _on_panel_action_pressed(action: Dictionary) -> void:
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	var player_id := _current_input_player()
	var targets = action.get("targets", [])
	if targets.is_empty():
		if _response_submission_should_suppress_followup(action) or str(action.get("kind", "")) == "activate_effect":
			_clear_action_focus()
		_maybe_mark_pending_self_response_followup(action, player_id)
		_execute_command(player_id, str(action.get("command_type", "")), action.get("payload_template", {}))
		return
	if _targets_require_click_selection(targets):
		_selected_target_action = action
		_selected_stack_target_id = ""
		_selected_attacker_uid = ""
		_refresh()
		return
	if _targets_are_stack_only(targets):
		var default_stack_target_id := _default_response_stack_target_id_for_targets(targets)
		if _selected_stack_target_id.is_empty() and not default_stack_target_id.is_empty():
			_selected_stack_target_id = default_stack_target_id
		if not _selected_stack_target_id.is_empty():
			for target in targets:
				if str(target.get("target_stack_id", "")) == _selected_stack_target_id:
					_execute_action_with_target(player_id, action, target)
					return
		if targets.size() == 1:
			_execute_action_with_target(player_id, action, targets[0])
			return
		_push_log("当前没有可自动锁定的回应目标。")
		return
	_execute_action_with_target(player_id, action, targets[0])


func _targets_require_click_selection(targets: Array) -> bool:
	for target in targets:
		if not (target is Dictionary):
			continue
		if target.has("row"):
			return true
		var target_kind := str(target.get("target_kind", ""))
		if target_kind == "card" or target_kind == "master" or target_kind == "morale_area":
			return true
	return false


func _targets_are_stack_only(targets: Array) -> bool:
	if targets.is_empty():
		return false
	for target in targets:
		if not (target is Dictionary):
			return false
		if str(target.get("target_kind", "")) != "stack":
			return false
	return true


func _stack_target_text(target: Dictionary) -> String:
	var source_id := str(target.get("target_source_id", ""))
	if source_id == "__pending_attack__":
		return "本次进攻"
	if source_id.is_empty():
		return "堆叠项"
	return _card_name(source_id)


func _refresh_choice_panel() -> void:
	if _choice_panel == null:
		return
	_hide_overlay_card_preview()
	var player_id := _current_local_input_player()
	if player_id < 0:
		_choice_panel.visible = false
		_panel_signature_changed("choice", "hidden:not_local_controller")
		return
	var choice_action := _current_local_choice_action()
	if _is_board_slot_choice_action(choice_action) or _is_board_card_choice_action(choice_action) or _is_hand_deploy_choice_action(choice_action) or _is_direct_hand_choice_action(choice_action):
		_choice_panel.visible = false
		_panel_signature_changed("choice", "hidden:inline_choice")
		return
	var should_show := not choice_action.is_empty()
	_choice_panel.visible = should_show
	var choice_size := Vector2(340, 320)
	if _is_optional_stack_choice_action(choice_action):
		choice_size = Vector2(360, 380)
	if str(choice_action.get("operation", "")) == "frontline_scout_confirm_enemy_hand":
		choice_size = Vector2(380, 430)
	if str(choice_action.get("operation", "")) == "search_top_for_artifact_and_named_legion":
		choice_size = Vector2(420, 430)
	if str(choice_action.get("operation", "")) == "revealed_top_card_play_or_hand":
		choice_size = Vector2(360, 395)
	var choice_position := _popup_column_position(1, choice_size)
	if _action_panel != null and _action_panel.visible:
		choice_position = _popup_below_center_panel(1, choice_size, _action_panel.size)
	var resolved_choice_title := _resolved_choice_panel_title(choice_action)
	var choice_signature := JSON.stringify({
		"visible": should_show,
		"title": resolved_choice_title,
		"size": [choice_size.x, choice_size.y],
		"position": [choice_position.x, choice_position.y],
		"action_panel_visible": _action_panel != null and _action_panel.visible,
		"action_panel_size": [_action_panel.size.x, _action_panel.size.y] if _action_panel != null else [0, 0],
		"choice_action": choice_action,
		"context_card_id": str(choice_action.get("context", {}).get("card_id", "")),
		"choice_reorder_dragging_card_id": _choice_reorder_dragging_card_id,
		"network_pending": _network_mode_active and _has_pending_network_command(),
		"selected_card_ids": _choice_selected_card_ids,
	})
	if not _panel_signature_changed("choice", choice_signature):
		return
	if not should_show:
		return
	_choice_panel.size = choice_size
	_choice_panel.position = choice_position
	_choice_panel_title.text = resolved_choice_title
	_clear_children(_choice_panel_body)
	var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = _choice_panel_hint_text(choice_action)
	_choice_panel_body.add_child(hint)
	if _network_mode_active and _has_pending_network_command():
		var waiting_hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		waiting_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		waiting_hint.text = "联机同步中：正在等待房主确认上一条选择。"
		_choice_panel_body.add_child(waiting_hint)
	match str(choice_action.get("choice_type", "")):
		"option_pick":
			_build_option_choice_buttons(player_id, choice_action)
		"candidate_cards_pick":
			_build_card_choice_buttons(player_id, choice_action)
		_:
			_build_card_choice_buttons(player_id, choice_action)


func _build_option_choice_buttons(player_id: int, choice_action: Dictionary) -> void:
	if _is_board_slot_choice_action(choice_action):
		return
	_add_revealed_choice_preview_if_needed(choice_action)
	_add_option_choice_card_preview_if_needed(choice_action)
	for option in choice_action.get("options", []):
		var option_id := str(option.get("id", ""))
		var text := str(option.get("text", option.get("label", option_id)))
		if _is_optional_stack_choice_action(choice_action):
			if option_id == "yes":
				text = "确认发动"
			elif option_id == "no":
				text = "本次不发动"
		var button := _make_button(text)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = _network_input_locked()
		button.pressed.connect(func() -> void:
			if str(choice_action.get("operation", "")) == "play_card_option_pick" or str(choice_action.get("operation", "")) == "play_card_effect_pick":
				_execute_local_play_option_choice(player_id, choice_action, option_id)
				return
			if str(choice_action.get("operation", "")) == "test_mode_choose_calamity":
				var payload = choice_action.get("payload_template", {}).duplicate(true)
				payload["definition_id"] = option_id
				_local_play_option_choice = {}
				_execute_command(player_id, "DebugCommand", payload)
				return
			var payload = choice_action.get("payload_template", {}).duplicate(true)
			payload["selected_option"] = option_id
			_execute_command(player_id, str(choice_action.get("command_type", "")), payload)
		)
		_choice_panel_body.add_child(button)


func _add_revealed_choice_preview_if_needed(choice_action: Dictionary) -> void:
	if str(choice_action.get("operation", "")) != "revealed_top_card_play_or_hand":
		return
	var preview_card_id := str(choice_action.get("context", {}).get("card_id", ""))
	if preview_card_id.is_empty():
		return
	var preview_title := _make_label(12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	preview_title.text = "展示的卡牌"
	_choice_panel_body.add_child(preview_title)
	var preview_wrap := CenterContainer.new()
	preview_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_wrap.custom_minimum_size = Vector2(0.0, 226.0)
	_choice_panel_body.add_child(preview_wrap)
	var preview_card: Control = BattleCardScript.new()
	preview_card.custom_minimum_size = Vector2(158.0, 221.0)
	preview_card.size = preview_card.custom_minimum_size
	preview_card.set_use_overlay_long_press_preview(true)
	preview_card.setup(_build_revealed_view_card(preview_card_id), false, false, false)
	preview_card.long_press_preview_requested.connect(_show_overlay_card_preview)
	preview_card.long_press_preview_finished.connect(_hide_overlay_card_preview)
	preview_wrap.add_child(preview_card)

func _add_option_choice_card_preview_if_needed(choice_action: Dictionary) -> void:
	var context: Dictionary = choice_action.get("context", {})
	if not context.has("display_card_ids"):
		return
	var display_card_ids := _string_array_from_variant_array(context.get("display_card_ids", []))
	var preview_title := _make_label(12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	preview_title.text = "展示的卡牌"
	_choice_panel_body.add_child(preview_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 235.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_panel_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for card_id in display_card_ids:
		var card_view: Control = BattleCardScript.new()
		card_view.custom_minimum_size = Vector2(82.0, 115.0)
		card_view.size = card_view.custom_minimum_size
		card_view.set_use_overlay_long_press_preview(true)
		card_view.setup(_build_revealed_view_card(card_id), false, false, false)
		card_view.long_press_preview_requested.connect(_show_overlay_card_preview)
		card_view.long_press_preview_finished.connect(_hide_overlay_card_preview)
		grid.add_child(card_view)


func _build_card_choice_buttons(player_id: int, choice_action: Dictionary) -> void:
	var count: int = max(1, int(choice_action.get("count", 1)))
	var operation := str(choice_action.get("operation", ""))
	var candidate_card_ids := _string_array_from_variant_array(choice_action.get("candidate_card_ids", []))
	var drag_reorder_all := _choice_uses_full_candidate_reorder(choice_action)
	var min_selected_count := _choice_min_selected_count_for_confirm(choice_action)
	var supports_drag_reorder := operation == "search_deck_reorder_bottom" or operation == "recycle_grave_to_deck" or operation == "recycle_grave_then_revive_source_from_grave" or operation == "bjorn_recycle_then_maybe_revive" or drag_reorder_all
	if operation == "search_deck_reorder_bottom" or drag_reorder_all:
		_sync_reorder_choice_selection(candidate_card_ids)
	if operation == "deploy_from_hand_to_battlefield":
		var deploy_hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		deploy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		deploy_hint.text = _choice_panel_hint_text(choice_action)
		_choice_panel_body.add_child(deploy_hint)
		return
	var display_card_ids: Array = candidate_card_ids.duplicate()
	var context: Dictionary = choice_action.get("context", {})
	if bool(context.get("hide_candidate_panel_cards", false)):
		return
	if context.has("display_card_ids"):
		display_card_ids = _string_array_from_variant_array(context.get("display_card_ids", []))
	elif operation == "search_deck":
		display_card_ids = _string_array_from_variant_array(choice_action.get("looked_cards", []))
	elif operation == "search_top_for_artifact_and_named_legion":
		display_card_ids = _string_array_from_variant_array(choice_action.get("looked_cards", []))
	elif operation == "search_deck_reorder_bottom" or drag_reorder_all:
		display_card_ids = _choice_selected_card_ids.duplicate()
	elif operation == "recycle_grave_to_deck" or operation == "recycle_grave_then_revive_source_from_grave" or operation == "bjorn_recycle_then_maybe_revive":
		display_card_ids = _ordered_display_ids_for_grave_recycle_choice(candidate_card_ids)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 235.0 if operation == "search_top_for_artifact_and_named_legion" else 145.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_panel_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3 if operation == "search_top_for_artifact_and_named_legion" else 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var card_size := Vector2(82.0, 115.0)
	if operation == "search_top_for_artifact_and_named_legion":
		card_size = Vector2(96.0, 134.0)
	for raw_card_id in display_card_ids:
		var card_id := str(raw_card_id)
		var selected := _choice_selected_card_ids.has(card_id)
		var selectable := candidate_card_ids.has(card_id) or operation == "search_deck_reorder_bottom" or drag_reorder_all
		if selectable and operation == "hijikata_entry_destroy_combo":
			selectable = _is_hijikata_entry_choice_card_selectable(choice_action, card_id)
		if selectable and operation == "search_top_for_artifact_and_named_legion":
			selectable = _is_artifact_and_named_legion_choice_card_selectable(choice_action, card_id)
		var card_view: Control = BattleCardScript.new()
		card_view.custom_minimum_size = card_size
		card_view.size = card_size
		card_view.set_use_overlay_long_press_preview(true)
		var can_drag_reorder := operation == "search_deck_reorder_bottom" or drag_reorder_all or ((operation == "recycle_grave_to_deck" or operation == "recycle_grave_then_revive_source_from_grave" or operation == "bjorn_recycle_then_maybe_revive") and selected)
		card_view.setup(_build_view_card(card_id), can_drag_reorder, selected, not selectable)
		card_view.card_clicked.connect(_on_choice_panel_card_clicked.bind(count))
		card_view.long_press_preview_requested.connect(_show_overlay_card_preview)
		card_view.long_press_preview_finished.connect(_hide_overlay_card_preview)
		if can_drag_reorder:
			card_view.drag_started.connect(_on_choice_reorder_card_drag_started)
			card_view.drag_finished.connect(_on_choice_reorder_card_drag_finished.bind(grid, supports_drag_reorder))
		grid.add_child(card_view)
	var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if operation == "hijikata_entry_destroy_combo":
		hint.text = ""
	elif bool(choice_action.get("allow_up_to_count", false)):
		hint.text = "可选择 %d 至 %d 张。" % [min_selected_count, count]
	else:
		hint.text = "需要选择 %d 张。" % count
	if _choice_requires_confirm(choice_action) and operation != "hijikata_entry_destroy_combo":
		hint.text += " 选中后还需点击确认。"
	if operation == "search_deck":
		hint.text = "先从本次查看的牌中选择 1 张加入手牌，再点确认。灰掉的牌本次不能加入手牌。"
	if operation == "search_top_for_artifact_and_named_legion":
		hint.text = "选择最多1张圣物和最多1张上杉谦信加入手牌；同类牌只能选择1张。"
	if operation == "search_deck_reorder_bottom":
		hint.text = "拖动卡牌调整回底顺序，越靠前表示越先放到底部。"
	if operation == "return_hand_to_deck_bottom" and drag_reorder_all:
		hint.text = "全部手牌都会返回牌库底部；请直接拖动卡牌调整整手回底顺序，然后确认。"
	if operation == "recycle_grave_to_deck":
		hint.text = "先选择 %d 张墓地卡牌，再拖动已选卡牌调整返回牌库底部的顺序。" % count
	if operation == "recycle_grave_then_revive_source_from_grave":
		hint.text = "先选择 %d 张其他墓地卡牌，再拖动已选卡牌调整返回牌库底部的顺序，然后确认。" % count
	if operation == "bjorn_recycle_then_maybe_revive":
		hint.text = "先选择 %d 张墓地卡牌，再拖动已选卡牌调整返回牌库底部的顺序。" % count
	if operation == "deploy_from_hand_to_battlefield":
		hint.text = "高亮的天灾等级2手牌必须拖到我方高亮空位上登场；没有符合手牌或没有空位时会直接跳过。"
	_choice_panel_body.add_child(hint)
	if supports_drag_reorder and not _choice_selected_card_ids.is_empty():
		var order_hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		order_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var ordered_names := _choice_selected_card_ids
		if (operation == "recycle_grave_to_deck" or operation == "recycle_grave_then_revive_source_from_grave" or operation == "bjorn_recycle_then_maybe_revive") and _choice_selected_card_ids.size() > count:
			ordered_names = _choice_selected_card_ids.slice(0, count)
		order_hint.text = "当前回底顺序：%s" % _join_card_names_by_ids(ordered_names)
		_choice_panel_body.add_child(order_hint)
	var show_confirm_button := operation == "search_deck_reorder_bottom" or drag_reorder_all or _choice_requires_confirm(choice_action) or (_choice_selected_card_ids.size() >= min_selected_count and _choice_selected_card_ids.size() <= count)
	if show_confirm_button:
		var confirm_button := _make_button("确认选择")
		confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		confirm_button.disabled = _network_input_locked() or (operation != "search_deck_reorder_bottom" and not drag_reorder_all and (_choice_selected_card_ids.size() < min_selected_count or _choice_selected_card_ids.size() > count))
		confirm_button.pressed.connect(func() -> void:
			if operation == "local_play_option_grave_pick":
				_execute_local_play_option_grave_choice(player_id, choice_action)
				return
			var payload = choice_action.get("payload_template", {}).duplicate(true)
			if operation == "search_deck_reorder_bottom" or drag_reorder_all:
				_sync_reorder_choice_selection(candidate_card_ids)
			if operation == "recycle_grave_to_deck" or operation == "recycle_grave_then_revive_source_from_grave" or operation == "bjorn_recycle_then_maybe_revive":
				payload["selected_card_ids"] = _choice_selected_card_ids.slice(0, count)
			else:
				payload["selected_card_ids"] = _choice_selected_card_ids.duplicate()
			_execute_command(player_id, str(choice_action.get("command_type", "")), payload)
		)
		_choice_panel_body.add_child(confirm_button)
	if _choice_supports_cancel(choice_action):
		var cancel_button := _make_button("取消")
		cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel_button.disabled = _network_input_locked()
		cancel_button.pressed.connect(func() -> void:
			if str(choice_action.get("operation", "")) == "local_play_option_grave_pick":
				_local_play_option_choice = {}
				_clear_selection_state()
				_refresh()
				return
			var payload = choice_action.get("payload_template", {}).duplicate(true)
			payload["cancelled"] = true
			payload.erase("selected_card_ids")
			payload.erase("selected_option")
			_execute_command(player_id, str(choice_action.get("command_type", "")), payload)
		)
		_choice_panel_body.add_child(cancel_button)


func _build_revealed_view_card(card_id: String) -> Dictionary:
	var view_card := _build_view_card(card_id).duplicate(true)
	view_card["face"] = "face_up"
	view_card["zone"] = "preview"
	return view_card


func _sync_reorder_choice_selection(candidate_card_ids: Array[String]) -> void:
	var synced: Array[String] = []
	for card_id in _choice_selected_card_ids:
		if candidate_card_ids.has(card_id) and not synced.has(card_id):
			synced.append(card_id)
	for card_id in candidate_card_ids:
		if not synced.has(card_id):
			synced.append(card_id)
	_choice_selected_card_ids = synced


func _ordered_display_ids_for_grave_recycle_choice(candidate_card_ids: Array[String]) -> Array[String]:
	var ordered: Array[String] = []
	for card_id in _choice_selected_card_ids:
		if candidate_card_ids.has(card_id) and not ordered.has(card_id):
			ordered.append(card_id)
	for card_id in candidate_card_ids:
		if not ordered.has(card_id):
			ordered.append(card_id)
	return ordered


func _toggle_choice_card(card_id: String, required_count: int) -> void:
	if _network_input_locked():
		return
	var choice_action := _current_choice_action()
	if str(choice_action.get("operation", "")) == "hijikata_entry_destroy_combo" and not _is_hijikata_entry_choice_card_selectable(choice_action, card_id):
		return
	if str(choice_action.get("operation", "")) == "search_top_for_artifact_and_named_legion" and not _is_artifact_and_named_legion_choice_card_selectable(choice_action, card_id):
		return
	if _choice_selected_card_ids.has(card_id):
		_choice_selected_card_ids.erase(card_id)
	elif _choice_selected_card_ids.size() < required_count:
		_choice_selected_card_ids.append(card_id)
	_refresh()


func _is_artifact_and_named_legion_choice_card_selectable(choice_action: Dictionary, card_id: String) -> bool:
	if choice_action.is_empty():
		return false
	var context: Dictionary = choice_action.get("context", {})
	var artifact_ids := _string_array_from_variant_array(context.get("artifact_candidates", []))
	var named_legion_ids := _string_array_from_variant_array(context.get("named_legion_candidates", []))
	if _choice_selected_card_ids.has(card_id):
		return true
	if _choice_selected_card_ids.size() >= max(1, int(choice_action.get("count", 1))):
		return false
	var candidate_is_artifact := artifact_ids.has(card_id)
	var candidate_is_named_legion := named_legion_ids.has(card_id)
	if not candidate_is_artifact and not candidate_is_named_legion:
		return false
	for selected_id in _choice_selected_card_ids:
		if candidate_is_artifact and artifact_ids.has(selected_id):
			return false
		if candidate_is_named_legion and named_legion_ids.has(selected_id):
			return false
	return true


func _is_hijikata_entry_choice_card_selectable(choice_action: Dictionary, card_id: String) -> bool:
	if choice_action.is_empty():
		return false
	var context: Dictionary = choice_action.get("context", {})
	var cost_one_or_less_ids := _string_array_from_variant_array(context.get("cost_one_or_less_ids", []))
	var cost_two_only_ids := _string_array_from_variant_array(context.get("cost_two_only_ids", []))
	if _choice_selected_card_ids.has(card_id):
		return true
	if _choice_selected_card_ids.size() >= max(1, int(choice_action.get("count", 1))):
		return false
	if _choice_selected_card_ids.is_empty():
		return cost_one_or_less_ids.has(card_id) or cost_two_only_ids.has(card_id)
	var selected_cost_two_only := false
	for selected_id in _choice_selected_card_ids:
		if cost_two_only_ids.has(selected_id):
			selected_cost_two_only = true
			break
	if selected_cost_two_only:
		return cost_one_or_less_ids.has(card_id)
	return cost_one_or_less_ids.has(card_id) or cost_two_only_ids.has(card_id)


func _select_single_choice_card(card_id: String) -> void:
	if _network_input_locked():
		return
	if _choice_selected_card_ids.size() == 1 and _choice_selected_card_ids[0] == card_id:
		_choice_selected_card_ids.clear()
	else:
		_choice_selected_card_ids = [card_id]
	_refresh()


func _on_choice_panel_card_clicked(card: Control, required_count: int) -> void:
	if _network_input_locked():
		return
	var card_id := str(card.card_data.get("uid", ""))
	if card_id.is_empty():
		return
	var choice_action := _current_choice_action()
	var candidate_card_ids := _string_array_from_variant_array(choice_action.get("candidate_card_ids", []))
	if not candidate_card_ids.has(card_id) and str(choice_action.get("operation", "")) != "search_deck_reorder_bottom" and not _choice_uses_full_candidate_reorder(choice_action):
		return
	if str(choice_action.get("operation", "")) == "search_deck_reorder_bottom" or str(choice_action.get("operation", "")) == "deploy_from_hand_to_battlefield" or _choice_uses_full_candidate_reorder(choice_action):
		return
	if required_count <= 1:
		if not choice_action.is_empty() and not _choice_requires_confirm(choice_action):
			var payload = choice_action.get("payload_template", {}).duplicate(true)
			payload["selected_card_ids"] = [card_id]
			_execute_command(_current_input_player(), str(choice_action.get("command_type", "")), payload)
			return
		_select_single_choice_card(card_id)
		return
	_toggle_choice_card(card_id, required_count)


func _on_choice_reorder_card_drag_started(card: Control) -> void:
	if _network_input_locked():
		return
	_choice_reorder_dragging_card_id = str(card.card_data.get("uid", ""))


func _on_choice_reorder_card_drag_finished(_card: Control, global_drop_position: Vector2, grid: GridContainer, supports_drag_reorder: bool = true) -> void:
	if _network_input_locked():
		_choice_reorder_dragging_card_id = ""
		_refresh()
		return
	var dragged_card_id := _choice_reorder_dragging_card_id
	_choice_reorder_dragging_card_id = ""
	if dragged_card_id.is_empty() or not supports_drag_reorder:
		_refresh()
		return
	var from_index := _choice_selected_card_ids.find(dragged_card_id)
	if from_index == -1:
		_refresh()
		return
	var insert_index := _choice_reorder_insert_index_from_drop(grid, global_drop_position, dragged_card_id, from_index)
	if insert_index == -1:
		_refresh()
		return
	var choice_action := _find_action(_player_actions(_current_input_player()), "resolve_choice")
	if str(choice_action.get("operation", "")) == "recycle_grave_to_deck" or str(choice_action.get("operation", "")) == "recycle_grave_then_revive_source_from_grave" or str(choice_action.get("operation", "")) == "bjorn_recycle_then_maybe_revive":
		insert_index = min(insert_index, _choice_selected_card_ids.size() - 1)
	_choice_selected_card_ids.remove_at(from_index)
	if insert_index > _choice_selected_card_ids.size():
		insert_index = _choice_selected_card_ids.size()
	_choice_selected_card_ids.insert(insert_index, dragged_card_id)
	_refresh()


func _choice_reorder_insert_index_from_drop(grid: GridContainer, global_drop_position: Vector2, dragged_card_id: String, fallback_index: int) -> int:
	var cards: Array[Control] = []
	for child in grid.get_children():
		if child is Control:
			cards.append(child)
	if cards.is_empty():
		return fallback_index
	for index in range(cards.size()):
		var view := cards[index]
		var view_card_id := str(view.card_data.get("uid", ""))
		if view_card_id == dragged_card_id:
			continue
		var rect := view.get_global_rect()
		if not rect.has_point(global_drop_position):
			continue
		var before_target := global_drop_position.x <= rect.get_center().x
		return index if before_target else index + 1
	var nearest_index := fallback_index
	var nearest_distance := INF
	for index in range(cards.size()):
		var view := cards[index]
		var view_card_id := str(view.card_data.get("uid", ""))
		if view_card_id == dragged_card_id:
			continue
		var distance := view.get_global_rect().get_center().distance_squared_to(global_drop_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	if nearest_distance == INF:
		return fallback_index
	if nearest_index >= cards.size() - 1:
		return _choice_selected_card_ids.size()
	return nearest_index


func _choice_panel_hint_text(choice_action: Dictionary) -> String:
	var context: Dictionary = choice_action.get("context", {})
	var custom_hint := str(choice_action.get("hint_text", context.get("hint_text", "")))
	if not custom_hint.is_empty():
		return custom_hint
	var choice_type := str(choice_action.get("choice_type", ""))
	var count: int = max(1, int(choice_action.get("count", 1)))
	if choice_type == "option_pick":
		if _is_board_slot_choice_action(choice_action):
			var slot_operation := str(choice_action.get("operation", ""))
			if slot_operation == "move_selected_battlefield_card_to_slot" or slot_operation == "tsukuyomi_choose_move_slot" or slot_operation == "takamagahara_morale_choose_move_slot":
				return "请点击高亮位置完成位移，也可以直接把这张军团拖到高亮位置。"
			return "直接点击我方场上的高亮空位即可确认登场位置。"
		if str(choice_action.get("operation", "")) == "play_card_option_pick" or str(choice_action.get("operation", "")) == "play_card_effect_pick":
			return _play_option_choice_hint_text(choice_action)
		if _is_optional_stack_choice_action(choice_action):
			return _optional_stack_choice_hint_text(choice_action)
		return "请选择是否发动，未决定前不会继续结算。"
	if choice_type == "candidate_cards_pick":
		if _is_board_card_choice_action(choice_action):
			var board_operation := str(choice_action.get("operation", ""))
			if board_operation == "choose_battlefield_cards_to_move":
				return "请先选择1张高亮的可位移军团，再选择高亮位置；也可以直接把该军团拖到目标位置。"
			if board_operation == "forged_order_choose_enemy_move_card":
				return "请直接拖拽高亮的对方军团进行前后位移；做其他操作会直接结束这次伪造密令。"
			if board_operation == "tsukuyomi_choose_move_card":
				return "请先选择1张高亮的可位移军团，再选择高亮位置；也可以直接把该军团拖到目标位置。"
			if board_operation == "takamagahara_morale_choose_move_card":
				return "请先选择1张高亮的活跃军团，再选择高亮位置；也可以直接把该军团拖到目标位置。"
			if _choice_requires_confirm(choice_action):
				return "请直接点击对方场上的高亮卡牌，选好后点击确认。"
			return "直接点击场上的高亮卡牌即可确认目标。"
		if str(choice_action.get("operation", "")) == "search_deck":
			return "先在这次查看的牌里选 1 张加入手牌，再点确认；随后会进入其余牌回底排序。"
		if str(choice_action.get("operation", "")) == "search_deck_reorder_bottom":
			return "在选择框内拖动卡牌调整回底顺序，再确认选择。"
		if str(choice_action.get("operation", "")) == "return_hand_to_deck_bottom" and _choice_uses_full_candidate_reorder(choice_action):
			return "请在选择框内拖动全部手牌，调整整手回底顺序后再确认。"
		if str(choice_action.get("operation", "")) == "deploy_from_hand_to_battlefield":
			return "请把高亮的手牌拖到我方高亮空位上，未完成前不会继续结算。"
		if _choice_requires_confirm(choice_action):
			return "先点击目标，再点确认选择。"
		if count <= 1:
			return "直接点击目标即可确认。"
		return "请先点亮目标，再确认选择。需要选择 %d 张。未选定前不会继续结算。" % count
	return "请选择要结算的结果。"


func _resolved_choice_panel_title(choice_action: Dictionary) -> String:
	var choice_title := str(choice_action.get("title", ""))
	if str(choice_action.get("operation", "")) == "play_card_option_pick":
		var payload: Dictionary = choice_action.get("payload_template", {})
		return "%s：选择登场方式" % _card_name(str(payload.get("card_id", "")))
	if str(choice_action.get("operation", "")) == "play_card_effect_pick":
		var payload: Dictionary = choice_action.get("payload_template", {})
		return "%s：选择发动效果" % _card_name(str(payload.get("card_id", "")))
	if _is_optional_stack_choice_action(choice_action):
		var stack_item := _stack_item_from_choice_action(choice_action)
		if not stack_item.is_empty():
			return _optional_stack_choice_title(choice_action)
	if not choice_title.is_empty():
		return choice_title
	return "待选择"


func _top_status_hint_text() -> String:
	if _state == null:
		return ""
	var choice_action := _current_local_choice_action()
	var context: Dictionary = choice_action.get("context", {})
	var custom_top_hint := str(choice_action.get("top_hint_text", context.get("top_hint_text", "")))
	if not custom_top_hint.is_empty():
		return custom_top_hint
	if str(choice_action.get("operation", "")) == "modify_cost_until_next_own_turn_end":
		return "切腹仪式：请直接点击对方场上高亮军团，直到下个我方回合结束前费用-2。"
	if _is_board_card_choice_action(choice_action):
		var operation := str(choice_action.get("operation", ""))
		if operation == "choose_battlefield_cards_to_move":
			return "位移效果：请点击高亮军团再点目标位置，或直接把该军团拖到高亮位置。"
		if operation == "forged_order_choose_enemy_move_card":
			return "伪造密令：拖拽高亮的对方军团进行前后位移，最多移动两张；若改做其他操作，本次位移会直接结束。"
		if operation == "tsukuyomi_choose_move_card":
			return "月读效果：请点击高亮军团再点目标位置，或直接把该军团拖到高亮位置。"
		if operation == "takamagahara_morale_choose_move_card":
			return "高天原阵营效果：请点击高亮军团再点目标位置，或直接把该军团拖到高亮位置。"
		return "源博雅进攻时效果：请直接点击对方场上高亮的伏置反击牌。"
	if _is_board_slot_choice_action(choice_action):
		var slot_operation := str(choice_action.get("operation", ""))
		if slot_operation == "move_selected_battlefield_card_to_slot" or slot_operation == "tsukuyomi_choose_move_slot" or slot_operation == "takamagahara_morale_choose_move_slot":
			return "请直接点击高亮位置完成位移，也可以把当前军团拖到高亮位置。"
		return "请直接点击场上的高亮位置完成当前落位选择。"
	if _is_hand_deploy_choice_action(choice_action):
		return "阿尔维达效果：请把高亮的2级天灾手牌直接拖到我方高亮空位。"
	return ""


func _top_status_state_text() -> String:
	if _is_opening_status_active():
		if str(_active_opening_prompt().get("choice_type", "")) == "waiting":
			return "等待中"
		return "开局准备"
	if _state == null:
		return ""
	if not _state.pending_choices.is_empty():
		return "选择中"
	if not _state.pending_attack.is_empty():
		return "响应中"
	if not _state.stack.is_empty():
		return "堆叠中"
	return "行动中"


func _single_line_status_text(text: String) -> String:
	var resolved := str(text).replace("\r", " ").replace("\n", " ").strip_edges()
	while resolved.contains("  "):
		resolved = resolved.replace("  ", " ")
	return resolved


func _waiting_actor_label() -> String:
	if _state == null:
		return ""
	return _player_side_name(_waiting_display_player())


func _choice_operation_status_label(operation: String, choice_type: String) -> String:
	match operation:
		"truce_offer":
			return "决定是否同意议和谈判"
		"prayer_reveal_offer":
			return "决定是否公开下一张天灾"
		"optional_stack_effect":
			return "决定是否发动当前效果"
		"resolve_option_with_shared_cost":
			return "决定当前效果的结算选项"
		"play_card_option_pick":
			return "选择登场方式"
		"search_deck":
			return "从查看结果中选牌"
		"search_deck_reorder_bottom":
			return "调整回到牌库底部的顺序"
		"recycle_grave_to_deck", "bjorn_recycle_then_maybe_revive":
			return "选择并调整回底顺序"
		"return_hand_to_deck_bottom":
			return "调整整手回底顺序"
		"deploy_from_hand_to_battlefield":
			return "决定登场目标与位置"
		"manifest_kusanagi_to_slot":
			return "决定草薙剑的登场位置"
		"choose_battlefield_cards_to_move":
			return "决定要位移的军团"
		"forged_order_choose_enemy_move_card":
			return "决定要前后位移的对方军团"
		"move_selected_battlefield_card_to_slot":
			return "决定位移的目标位置"
		"tsukuyomi_choose_move_card":
			return "决定月读要位移的军团"
		"tsukuyomi_choose_move_slot":
			return "决定月读位移的目标位置"
		"takamagahara_morale_choose_move_card":
			return "决定要位移的活跃军团"
		"takamagahara_morale_choose_move_slot":
			return "决定位移的目标位置"
		"modify_cost_until_next_own_turn_end":
			return "选择切腹仪式减费目标"
	if choice_type == "option_pick":
		return "做出选项决定"
	if choice_type == "candidate_cards_pick":
		return "选择卡牌目标"
	return "处理当前选择"


func _waiting_choice_status_text() -> String:
	if _state == null or _state.pending_choices.is_empty():
		return ""
	var choice: Dictionary = _state.pending_choices[0]
	var actor_text := _player_side_name(_display_player_for_logical(int(choice.get("player_id", -1))))
	var title_text := _single_line_status_text(str(choice.get("title", "")))
	if not title_text.is_empty():
		return "%s正在处理：%s" % [actor_text, title_text]
	return "%s正在%s" % [
		actor_text,
		_choice_operation_status_label(str(choice.get("operation", "")), str(choice.get("type", "")))
	]


func _pending_attack_waiting_status_text() -> String:
	if _state == null or _state.pending_attack.is_empty():
		return ""
	var attack: Dictionary = _state.pending_attack
	var attacker_id := str(attack.get("attacker_id", ""))
	var attacker_text := "%s的%s" % [_player_side_name(_display_player_for_source(attacker_id)), _card_name(attacker_id)]
	var target_text := ""
	if str(attack.get("target_kind", "card")) == "master":
		var target_player := _display_target_player_from_variant(attack.get("target_player", -1))
		var master_name := "主宰"
		if target_player >= 0 and target_player < _players.size():
			master_name = str(_players[target_player].get("master_name", "主宰"))
		target_text = "%s的%s" % [_player_side_name(target_player), master_name]
	else:
		var defender_id := str(attack.get("defender_id", ""))
		target_text = "%s的%s" % [_player_side_name(_display_player_for_source(defender_id)), _card_name(defender_id)]
	var waiting_text := _waiting_actor_label()
	var summary := "%s正在攻击%s，当前由%s响应" % [attacker_text, target_text, waiting_text]
	var defense_text := _pending_attack_defense_summary(attack)
	if not defense_text.is_empty():
		summary += "\n已选防守：%s" % defense_text
	return summary


func _stack_waiting_status_text() -> String:
	if _state == null or _state.stack.is_empty():
		return ""
	var top_item: Dictionary = _state.stack[_state.stack.size() - 1]
	var source_id := str(top_item.get("source_instance_id", ""))
	var owner_text := _player_side_name(_display_player_for_logical(int(top_item.get("controller", -1))))
	var source_text := ""
	if source_id.begins_with("master_"):
		source_text = "%s主宰（%s）" % [owner_text, _card_name(source_id)]
	else:
		source_text = "%s的%s" % [owner_text, _card_name(source_id)]
	var effect_text := _single_line_status_text(_effect_text_for_stack_item(top_item))
	var summary := "%s的效果正在等待回应" % source_text
	if not effect_text.is_empty():
		summary += "\n%s" % effect_text
	var waiting_text := _waiting_actor_label()
	if not waiting_text.is_empty():
		summary += "\n当前由%s决定是否回应" % waiting_text
	return summary


func _active_opening_prompt() -> Dictionary:
	if _opening_session.is_empty():
		return {}
	var prompt = _opening_session.get("active_prompt", {})
	return prompt.duplicate(true) if prompt is Dictionary else {}


func _is_opening_status_active() -> bool:
	return not _active_opening_prompt().is_empty()


func _opening_stage_status_label(stage: String, title: String = "") -> String:
	if stage == "waiting":
		return "操作"
	if stage.begins_with("calamity_ban_"):
		return "禁用天灾"
	if stage == "calamity_pick_first" or stage == "calamity_pick_second":
		return "选择天灾"
	if stage.begins_with("mulligan_"):
		return "调度手牌"
	if stage == "choose_starting_player":
		return "决定先后攻"
	var normalized_title := _single_line_status_text(title)
	if not normalized_title.is_empty():
		return normalized_title
	return "处理开局步骤"


func _opening_status_detail_text() -> String:
	var prompt := _active_opening_prompt()
	if prompt.is_empty():
		return ""
	var logical_actor := int(prompt.get("actor_player_id", -1))
	var actor_display := _display_player_for_logical(logical_actor) if logical_actor >= 0 else -1
	var actor_text := ""
	if actor_display >= 0:
		actor_text = _player_side_label(actor_display)
	elif _network_mode_active:
		actor_text = "对方"
	else:
		actor_text = "人机"
	var choice_type := str(prompt.get("choice_type", ""))
	var stage_text := _opening_stage_status_label(str(prompt.get("stage", "")), str(prompt.get("title", "")))
	var summary := ""
	if choice_type == "waiting":
		summary = _single_line_status_text(str(prompt.get("description", "")))
		if summary.is_empty():
			summary = "等待%s完成%s..." % [_opening_waiting_actor_text(logical_actor), stage_text]
	else:
		summary = "%s正在%s" % [actor_text, stage_text]
	if choice_type != "waiting" and logical_actor >= 0 and _is_opening_ai_actor(logical_actor):
		summary += "（大模型AI）" if _ai_use_llm else "（脚本型人机）"
	var status_text := _single_line_status_text(str(prompt.get("status_text", "")))
	if status_text.is_empty():
		return summary
	return "%s\n%s" % [summary, status_text]


func _top_status_detail_text() -> String:
	if _is_opening_status_active():
		return _opening_status_detail_text()
	if _state == null:
		return ""
	if not _state.pending_choices.is_empty():
		return _waiting_choice_status_text()
	if not _state.pending_attack.is_empty():
		return _pending_attack_waiting_status_text()
	if not _state.stack.is_empty():
		return _stack_waiting_status_text()
	var waiting_text := _waiting_actor_label()
	if waiting_text.is_empty():
		return ""
	return "当前轮到%s在%s行动" % [waiting_text, _phase_display_text(str(_state.phase))]


func _attack_declared_notice_text(payload: Dictionary) -> String:
	var attacker_id := str(payload.get("attacker_id", ""))
	if attacker_id.is_empty():
		return ""
	var attacker_text := "%s的%s" % [
		_player_side_name(_display_player_for_source(attacker_id)),
		_card_name(attacker_id)
	]
	if str(payload.get("target_kind", "card")) == "master":
		var target_player := _display_target_player_from_variant(payload.get("target_player", -1))
		var master_name := "主宰"
		if target_player >= 0 and target_player < _players.size():
			master_name = str(_players[target_player].get("master_name", "主宰"))
		return "%s进攻了%s的%s" % [attacker_text, _player_side_name(target_player), master_name]
	var defender_id := str(payload.get("defender_id", ""))
	if defender_id.is_empty():
		return "%s宣告进攻" % attacker_text
	var defender_text := "%s%s" % [
		_player_side_name(_display_player_for_source(defender_id)),
		_card_name(defender_id)
	]
	return "%s进攻了%s" % [attacker_text, defender_text]


func _refresh_stack_panel() -> void:
	if _stack_panel == null:
		return
	_stack_panel.visible = false
	_panel_signature_changed("stack", "hidden:single_response_panel")


func _pending_attack_defense_summary(attack: Dictionary) -> String:
	var blocker_id := str(attack.get("blocker_id", ""))
	if not blocker_id.is_empty():
		return "前排防守 %s" % _card_name(blocker_id)
	var supporter_id := str(attack.get("supporter_id", ""))
	if not supporter_id.is_empty():
		return "后排支援 %s" % _card_name(supporter_id)
	var guard_card_ids: Array = attack.get("master_guard_card_ids", [])
	if guard_card_ids is Array and not guard_card_ids.is_empty():
		var guard_names: Array[String] = []
		for raw_card_id in guard_card_ids:
			guard_names.append(_card_name(str(raw_card_id)))
		return "弃牌抵伤 %s" % " + ".join(guard_names)
	return ""


func _pending_attack_summary() -> String:
	var attack: Dictionary = _state.pending_attack
	var attacker_id := str(attack.get("attacker_id", ""))
	var attacker_name := _card_name(str(attack.get("attacker_id", "")))
	var attacker_side := _player_side_name(_display_player_for_source(attacker_id))
	var target_text := ""
	var target_side := ""
	if str(attack.get("target_kind", "card")) == "master":
		var target_player := _display_target_player_from_variant(attack.get("target_player", -1))
		if target_player >= 0 and target_player < _players.size():
			target_text = str(_players[target_player].get("master_name", "主宰"))
			target_side = _player_side_name(target_player)
	else:
		var defender_id := str(attack.get("defender_id", ""))
		target_text = _card_name(defender_id)
		target_side = _player_side_name(_display_player_for_source(defender_id))
	var opened := bool(attack.get("response_window_opened", false))
	var status_text := "即将打开"
	if opened:
		status_text = "等待响应"
	var defense_text := _pending_attack_defense_summary(attack)
	var lines: Array[String] = [
		"攻击响应窗",
		"攻击方：%s %s" % [attacker_side, attacker_name],
		"目标：%s %s" % [target_side, target_text],
		"状态：%s" % status_text
	]
	if not defense_text.is_empty():
		lines.append("已选防守：%s" % defense_text)
	return "\n".join(lines)


func _stack_item_summary(stack_item: Dictionary, is_top: bool) -> String:
	var source_name := _card_name(str(stack_item.get("source_instance_id", "")))
	var effect_text := _effect_text_for_stack_item(stack_item)
	var effect_type := _stack_effect_context_label(stack_item)
	var controller_id := int(stack_item.get("controller", -1))
	var controller_text := "%s %s" % [_response_owner_tag(controller_id), _player_side_name(controller_id)]
	var target_text := ""
	var targets = stack_item.get("targets", {})
	if targets is Dictionary and not targets.is_empty():
		target_text = "目标：%s" % _stack_targets_summary(targets)
	var top_prefix := ""
	if is_top:
		top_prefix = "[顶] "
	var target_suffix := ""
	if not target_text.is_empty():
		target_suffix = "\n" + target_text
	return "%s%s %s\n%s：%s%s" % [
		top_prefix,
		controller_text,
		source_name,
		effect_type,
		effect_text,
		target_suffix
	]


func _stack_effect_type_label(effect_type: String) -> String:
	match effect_type:
		"tactic":
			return "战术"
		"counter_tactic":
			return "反击"
		"triggered":
			return "触发"
	return "效果"


func _stack_effect_context_label(stack_item: Dictionary) -> String:
	if _state != null and not _state.pending_attack.is_empty():
		if str(_state.pending_attack.get("attacker_id", "")) == str(stack_item.get("source_instance_id", "")):
			return "进攻时效果"
	return _stack_effect_type_label(str(stack_item.get("effect_type", "")))


func _effect_text_for_stack_item(stack_item: Dictionary) -> String:
	var source_id := str(stack_item.get("source_instance_id", ""))
	var effect_id := str(stack_item.get("effect_id", ""))
	var embedded_text := _clean_display_text(str(stack_item.get("effect_text", "")))
	if not embedded_text.is_empty():
		return embedded_text
	var effect_text := _effect_text_for_source(source_id, effect_id)
	if not effect_text.is_empty():
		return effect_text
	return "未命名效果"


func _stack_item_from_choice_action(choice_action: Dictionary) -> Dictionary:
	var stack_item: Dictionary = choice_action.get("stack_item", {})
	if not stack_item.is_empty():
		return stack_item
	var context: Dictionary = choice_action.get("context", {})
	if context is Dictionary:
		return context.get("stack_item", {})
	return {}


func _is_optional_stack_choice_action(choice_action: Dictionary) -> bool:
	var operation := str(choice_action.get("operation", ""))
	return operation == "optional_stack_effect" or operation == "pre_stack_optional_attack_trigger"


func _trigger_event_type_for_stack_item(stack_item: Dictionary) -> String:
	if _state == null or stack_item.is_empty():
		return ""
	var created_from_event_id := int(stack_item.get("created_from_event_id", 0))
	if created_from_event_id <= 0:
		return ""
	for event in _state.event_log:
		if int(event.event_id) == created_from_event_id:
			return str(event.type)
	return ""


func _optional_trigger_reason_label(choice_action: Dictionary) -> String:
	var stack_item := _stack_item_from_choice_action(choice_action)
	var trigger_event_type := _trigger_event_type_for_stack_item(stack_item)
	match trigger_event_type:
		"AttackDeclared":
			return "宣告进攻时"
		"AttackFinished":
			return "完成进攻后"
		"CardPlayed", "CardEnteredBattlefield":
			return "登场时"
		"CardDied":
			return "阵亡时"
		"EffectResolved":
			return "效果结算后"
		"MasterWouldBeDamaged":
			return "主宰将要受伤时"
		_:
			return "当前事件结算时"


func _optional_stack_choice_title(choice_action: Dictionary) -> String:
	var choice_title := _single_line_status_text(str(choice_action.get("title", "")))
	if not choice_title.is_empty():
		return choice_title
	var stack_item := _stack_item_from_choice_action(choice_action)
	if stack_item.is_empty():
		return "是否发动当前可选效果"
	return "%s：是否发动%s效果" % [
		_card_name(str(stack_item.get("source_instance_id", ""))),
		_optional_trigger_reason_label(choice_action)
	]


func _effect_text_for_source(source_id: String, effect_id: String) -> String:
	if source_id.is_empty() or effect_id.is_empty() or _state == null:
		return ""
	if _is_morale_source_id(source_id):
		match effect_id:
			"takamagahara_morale_draw":
				return "高天原阵营效果：回合1次，可消耗2士气，抽取1张牌；随后可选择我方1张活跃军团进行1格位移。"
			"asgard_morale_draw":
				return "阿斯加德阵营效果：回合1次，可消耗2士气，抽取1张牌；若我方主宰血量不高于5，可额外消耗1士气，我方主宰增加1点血量。"
	var definition = _definition_for_source(source_id)
	if source_id.begins_with("master_"):
		pass
	if definition == null:
		return ""
	var effect_text := _find_effect_text_in_entries(definition.effects, effect_id)
	if not effect_text.is_empty():
		return effect_text
	for play_option in definition.play_options:
		var option_effects = play_option.get("effects", [])
		effect_text = _find_effect_text_in_entries(option_effects, effect_id)
		if not effect_text.is_empty():
			return effect_text
	return ""


func _choice_actor_text(display_player_id: int, fallback_player_name: String) -> String:
	if display_player_id >= 0 and display_player_id < _players.size():
		return _player_side_name(display_player_id)
	if not fallback_player_name.is_empty():
		return fallback_player_name
	return "该玩家"


func _choice_title_one_line(payload: Dictionary) -> String:
	return _single_line_status_text(str(payload.get("title", "")))


func _choice_requested_log_text(display_player_id: int, fallback_player_name: String, payload: Dictionary) -> String:
	var actor_text := _choice_actor_text(display_player_id, fallback_player_name)
	var operation := str(payload.get("operation", ""))
	var title_text := _choice_title_one_line(payload)
	match operation:
		"truce_offer":
			return "%s正在决定是否同意议和谈判。" % actor_text
		"prayer_reveal_offer":
			return "%s正在决定是否同意公开下一张天灾。" % actor_text
		"optional_stack_effect":
			if not title_text.is_empty():
				return "%s正在决定是否发动效果：%s。" % [actor_text, title_text]
			return "%s正在决定是否发动当前效果。" % actor_text
	if not title_text.is_empty():
		return "%s需要做出选择：%s。" % [actor_text, title_text]
	return "%s需要做出选择。" % actor_text


func _choice_resolved_log_text(display_player_id: int, fallback_player_name: String, payload: Dictionary) -> String:
	var actor_text := _choice_actor_text(display_player_id, fallback_player_name)
	var operation := str(payload.get("operation", ""))
	var selected_option := str(payload.get("selected_option", ""))
	match operation:
		"truce_offer":
			if selected_option == "agree":
				return "%s同意了议和谈判，双方各抽1张牌。" % actor_text
			if selected_option == "decline":
				return "%s拒绝了议和谈判，后续不再额外抽牌。" % actor_text
		"prayer_reveal_offer":
			if selected_option == "agree":
				return "%s同意公开下一张天灾。" % actor_text
			if selected_option == "decline":
				return "%s拒绝公开下一张天灾。" % actor_text
		"optional_stack_effect":
			if selected_option == "yes":
				return "%s选择发动该效果。" % actor_text
			if selected_option == "no":
				return "%s选择不发动该效果。" % actor_text
	var title_text := _choice_title_one_line(payload)
	if not selected_option.is_empty():
		if not title_text.is_empty():
			return "%s完成了选择：%s（%s）。" % [actor_text, title_text, selected_option]
		return "%s完成了选择（%s）。" % [actor_text, selected_option]
	if not title_text.is_empty():
		return "%s完成了选择：%s。" % [actor_text, title_text]
	return "%s完成了选择。" % actor_text


func _effect_cost_for_source(source_id: String, effect_id: String) -> Dictionary:
	if source_id.is_empty() or effect_id.is_empty():
		return {}
	if _is_morale_source_id(source_id):
		match effect_id:
			"takamagahara_morale_draw", "asgard_morale_draw":
				return {"morale": 2}
	var definition = _definition_for_source(source_id)
	if definition == null:
		return {}
	var effect_cost := _find_effect_cost_in_entries(definition.effects, effect_id)
	if not effect_cost.is_empty():
		return effect_cost
	for play_option in definition.play_options:
		var option_effects = play_option.get("effects", [])
		effect_cost = _find_effect_cost_in_entries(option_effects, effect_id)
		if not effect_cost.is_empty():
			return effect_cost
	return {}


func _definition_for_source(source_id: String):
	if _state == null or source_id.is_empty():
		return null
	if source_id.begins_with("master_"):
		var player_index := int(source_id.trim_prefix("master_"))
		if player_index >= 0 and player_index < _state.players.size():
			return _state.get_definition(_state.get_player(player_index).master_definition_id)
		return null
	var instance = _state.card_instances.get(source_id)
	if instance != null:
		return _state.get_definition(str(instance.definition_id))
	return null


func _find_effect_text_in_entries(entries, effect_id: String) -> String:
	if not (entries is Array):
		return ""
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if str(entry.get("id", "")) != effect_id:
			continue
		return _clean_display_text(str(entry.get("text", "")))
	return ""


func _find_effect_cost_in_entries(entries, effect_id: String) -> Dictionary:
	if not (entries is Array):
		return {}
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if str(entry.get("id", "")) != effect_id:
			continue
		var cost = entry.get("cost", {})
		if cost is Dictionary:
			return cost.duplicate(true)
		return {}
	return {}


func _clean_display_text(text: String) -> String:
	return text.replace("\n", " ").replace("\r", " ").strip_edges()


func _join_non_empty(parts: Array[String], separator: String) -> String:
	var filtered: Array[String] = []
	for part in parts:
		var value := part.strip_edges()
		if value.is_empty():
			continue
		filtered.append(value)
	return separator.join(filtered)


func _player_side_label(player_id: int) -> String:
	if player_id == 0:
		return "我方"
	if player_id == 1:
		return "对方"
	return "玩家%s" % str(player_id + 1)


func _player_side_name(player_id: int) -> String:
	if player_id < 0 or player_id >= _players.size():
		return _player_side_label(player_id)
	var master_name := str(_players[player_id].get("master_name", "主宰"))
	return "%s（%s）" % [_player_side_label(player_id), master_name]


func _response_owner_tag(player_id: int) -> String:
	return "【%s】" % _player_side_label(player_id)


func _response_action_button_text(action: Dictionary, player_id: int) -> String:
	return "%s %s" % [_response_owner_tag(player_id), _action_button_text(action)]


func _display_player_for_source(source_id: String, fallback_player_id: int = -1) -> int:
	var logical_player_id := _source_controller(source_id, fallback_player_id)
	if logical_player_id < 0:
		return fallback_player_id
	return _display_player_for_logical(logical_player_id)


func _source_controller(source_id: String, fallback_player_id: int = -1) -> int:
	if source_id.begins_with("master_"):
		var suffix := source_id.trim_prefix("master_")
		if suffix.is_valid_int():
			return int(suffix)
	if _state != null and _state.card_instances.has(source_id):
		return int(_state.card_instances[source_id].controller)
	return fallback_player_id


func _normalize_payload_for_network(payload: Dictionary) -> Dictionary:
	# Action proposal targets already use logical player ids. Re-mapping here flips
	# master targets for the joining side and can turn "attack enemy master" into
	# "attack your own master".
	return payload.duplicate(true)


func _has_pending_network_command() -> bool:
	return not _pending_network_commands.is_empty()


func _network_input_locked() -> bool:
	return _network_mode_active and (_has_pending_network_command() or _network_resync_in_progress)


func _oldest_pending_network_command_index() -> int:
	var oldest_index := -1
	var oldest_sent_at := Time.get_ticks_msec()
	for raw_index in _pending_network_commands.keys():
		var command_index := int(raw_index)
		var pending_info: Dictionary = _pending_network_commands.get(command_index, {})
		var sent_at := int(pending_info.get("sent_at_ms", 0))
		if oldest_index == -1 or sent_at < oldest_sent_at:
			oldest_index = command_index
			oldest_sent_at = sent_at
	return oldest_index


func _begin_network_resync(reason: String, command_index: int) -> void:
	if not _network_mode_active or _network_session == null:
		_abort_network_duel(NETWORK_TERMINATION_REASON_RESYNC_FAILED, "无法请求房主恢复", false)
		return
	if _network_is_host:
		return
	if _network_resync_in_progress:
		return
	_pending_network_commands.clear()
	_network_resync_in_progress = true
	_network_resync_started_at_ms = Time.get_ticks_msec()
	_clear_selection_state()
	_append_file_log("[NET RESYNC] request reason=%s command=%s" % [reason, str(command_index)])
	_push_log("联机同步异常：已请求房主重同步。")
	if _network_status_label != null:
		_network_status_label.text = "联机同步异常：正在请求房主重同步..."
	_network_session.request_resync(reason, command_index)
	_refresh()


func _build_network_resync_package(reason: String, command_index: int) -> Dictionary:
	var replay_data: Dictionary = {}
	var expected_hash := ""
	if _state != null:
		replay_data = _engine.export_replay_data(_state)
		expected_hash = _state_hash_with_profile("hash/resync_package")
	return {
		"ok": true,
		"reason": reason,
		"command_index": command_index,
		"duel_path": _current_duel_path,
		"game_options": _current_game_options.duplicate(true),
		"duel_label": _current_duel_label,
		"duel_seed": _current_duel_seed,
		"replay_data": replay_data.duplicate(true),
		"expected_hash": expected_hash
	}


func _apply_network_resync_package(payload: Dictionary) -> Dictionary:
	var duel_path := str(payload.get("duel_path", ""))
	var duel_label := str(payload.get("duel_label", "联机恢复对局"))
	var duel_seed := int(payload.get("duel_seed", -1))
	var game_options: Dictionary = payload.get("game_options", {}).duplicate(true)
	var replay_data: Dictionary = payload.get("replay_data", {})
	var expected_hash := str(payload.get("expected_hash", ""))
	if duel_path.is_empty() or replay_data.is_empty():
		return {
			"ok": false,
			"code": "INVALID_RESYNC_PAYLOAD",
			"message": "missing duel setup or replay data"
		}
	_append_file_log("[NET RESYNC] apply command=%s replay_count=%s" % [
		str(int(payload.get("command_index", -1))),
		str(replay_data.get("commands", []).size())
	])
	_start_new_duel(duel_path, game_options, duel_label, duel_seed)
	if _state == null:
		return {
			"ok": false,
			"code": "RESYNC_RESTART_FAILED",
			"message": "failed to restart duel locally"
		}
	for row in replay_data.get("commands", []):
		var command_row: Dictionary = row
		var player_id := int(command_row.get("player_id", -1))
		var command_type := str(command_row.get("type", ""))
		var command_payload: Dictionary = command_row.get("payload", {})
		if command_type.is_empty():
			return {
				"ok": false,
				"code": "RESYNC_COMMAND_INVALID",
				"message": "replay command is missing type"
			}
		var command_result := _apply_engine_command(player_id, command_type, command_payload)
		if not bool(command_result.get("ok", false)):
			return {
				"ok": false,
				"code": "RESYNC_COMMAND_FAILED",
				"message": "failed to replay host command locally",
				"failed_command": command_row.duplicate(true)
			}
		var command_hash := _state_hash_with_profile("hash/resync_step")
		var expected_after := str(command_row.get("state_hash_after", ""))
		if not expected_after.is_empty() and command_hash != expected_after:
			return {
				"ok": false,
				"code": "RESYNC_HASH_MISMATCH",
				"message": "replayed state hash does not match host replay",
				"failed_command": command_row.duplicate(true)
			}
	if _state != null and not expected_hash.is_empty():
		var rebuilt_hash := _state_hash_with_profile("hash/resync_final")
		if rebuilt_hash != expected_hash:
			return {
				"ok": false,
				"code": "RESYNC_FINAL_HASH_MISMATCH",
				"message": "rebuilt state hash does not match host state"
			}
	_sync_from_engine()
	_request_deferred_refresh()
	return {
		"ok": true,
		"command_index": int(payload.get("command_index", -1))
	}


func _abort_network_duel(reason_code: String, detail: String = "", disconnect_session: bool = false) -> void:
	var message := _network_terminal_message_for_reason(reason_code, detail)
	_network_terminal_message = message
	_append_file_log("[NET ABORT] code=%s detail=%s" % [reason_code, detail])
	_push_log(message)
	_reset_battle_table(true, disconnect_session, true)


func _network_command_summary(command_type: String, payload: Dictionary) -> String:
	var parts: Array[String] = [command_type]
	match command_type:
		"ChooseDefense":
			if not str(payload.get("blocker_id", "")).is_empty():
				parts.append("防守=%s" % _card_name(str(payload.get("blocker_id", ""))))
			if not str(payload.get("supporter_id", "")).is_empty():
				parts.append("支援=%s" % _card_name(str(payload.get("supporter_id", ""))))
			var guard_ids := _string_array_from_variant_array(payload.get("master_guard_card_ids", []))
			if not guard_ids.is_empty():
				parts.append("护主=%s" % _join_card_names_by_ids(guard_ids))
		"ActivateEffect":
			parts.append("来源=%s" % _card_name(str(payload.get("source_id", ""))))
			parts.append("效果=%s" % str(payload.get("effect_id", "")))
		"ResolveChoice":
			parts.append("choice=%s" % str(payload.get("choice_id", "")))
			if payload.has("selected_option"):
				parts.append("option=%s" % str(payload.get("selected_option", "")))
			var selected_ids := _string_array_from_variant_array(payload.get("selected_card_ids", []))
			if not selected_ids.is_empty():
				parts.append("cards=%s" % _join_card_names_by_ids(selected_ids))
		"PlayCard":
			parts.append("卡牌=%s" % _card_name(str(payload.get("card_id", ""))))
		"DeclareAttack":
			parts.append("攻击者=%s" % _card_name(str(payload.get("attacker_id", ""))))
		"EndPhase":
			parts.append("结束阶段")
	return " | ".join(parts)


func _top_stack_controller() -> int:
	if _state == null or _state.stack.is_empty():
		return -1
	return int(_state.stack[_state.stack.size() - 1].get("controller", -1))


func _stack_targets_include_pending_attack(targets: Array) -> bool:
	for target in targets:
		if not (target is Dictionary):
			continue
		if str(target.get("target_stack_id", "")) == "__pending_attack__":
			return true
	return false


func _stack_targets_include_stack_item(targets: Array) -> bool:
	for target in targets:
		if not (target is Dictionary):
			continue
		var target_stack_id := str(target.get("target_stack_id", ""))
		if not target_stack_id.is_empty() and target_stack_id != "__pending_attack__":
			return true
	return false


func _stack_target_selection_suffix(action: Dictionary) -> String:
	var targets = action.get("targets", [])
	if not (targets is Array):
		return ""
	var can_target_attack := _stack_targets_include_pending_attack(targets)
	var can_target_effect := _stack_targets_include_stack_item(targets)
	if can_target_attack and can_target_effect:
		return "（先选“本次进攻”或具体效果）"
	if can_target_attack:
		return "（先选“本次进攻”）"
	if can_target_effect:
		return "（先选具体效果）"
	return ""


func _stack_targets_summary(targets: Dictionary) -> String:
	if targets.has("target_stack_id"):
		var target_stack_id := str(targets.get("target_stack_id", ""))
		if target_stack_id == "__pending_attack__":
			return "本次进攻"
		return "堆叠项 %s" % target_stack_id
	if targets.has("target_player"):
		var player_index := _display_target_player_from_variant(targets.get("target_player", -1))
		if player_index >= 0 and player_index < _players.size():
			return _player_side_name(player_index)
	if targets.has("target_card_id"):
		var target_card_id := str(targets.get("target_card_id", ""))
		return "%s %s" % [_player_side_name(_display_player_for_source(target_card_id)), _card_name(target_card_id)]
	if targets.has("defender_id"):
		var defender_id := str(targets.get("defender_id", ""))
		return "%s %s" % [_player_side_name(_display_player_for_source(defender_id)), _card_name(defender_id)]
	return "无"


func _on_stack_item_pressed(stack_id: String) -> void:
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	_selected_stack_target_id = stack_id
	if _selected_target_action.is_empty() or not _targets_are_stack_only(_selected_target_action.get("targets", [])):
		_refresh()
		return
	for target in _selected_target_action.get("targets", []):
		if str(target.get("target_stack_id", "")) != stack_id:
			continue
		var action := _selected_target_action
		_selected_target_action = {}
		_selected_stack_target_id = ""
		_execute_action_with_target(_current_input_player(), action, target)
		return
	_refresh()


func _stack_item_is_selectable_target(stack_id: String) -> bool:
	if stack_id.is_empty():
		return false
	if _selected_target_action.is_empty():
		return true
	if not _targets_are_stack_only(_selected_target_action.get("targets", [])):
		return true
	for target in _selected_target_action.get("targets", []):
		if str(target.get("target_stack_id", "")) == stack_id:
			return true
	return false


func _pending_attack_is_selectable_target() -> bool:
	if _state == null or _state.pending_attack.is_empty():
		return false
	if _selected_target_action.is_empty():
		return false
	if not _targets_are_stack_only(_selected_target_action.get("targets", [])):
		return false
	for target in _selected_target_action.get("targets", []):
		if str(target.get("target_stack_id", "")) == "__pending_attack__":
			return true
	return false


func _pending_attack_target_button_text() -> String:
	return "本次进攻（抵挡攻击本体）\n%s" % _pending_attack_summary().replace("攻击响应窗\n", "")


func _response_action_panel_context() -> String:
	if _state == null:
		return ""
	if not _state.pending_attack.is_empty():
		return _pending_attack_summary()
	if not _state.stack.is_empty():
		return "当前存在待响应的堆叠效果，可选择反制或让过优先权。"
	return ""


func _choose_defense_action_suffix() -> String:
	if _state == null or _state.pending_attack.is_empty():
		return ""
	var attack: Dictionary = _state.pending_attack
	var attacker_name := _card_name(str(attack.get("attacker_id", "")))
	var defender_name := ""
	if str(attack.get("target_kind", "card")) == "master":
		var target_player := _display_target_player_from_variant(attack.get("target_player", -1))
		if target_player >= 0 and target_player < _players.size():
			defender_name = str(_players[target_player].get("master_name", "主宰"))
	else:
		defender_name = _card_name(str(attack.get("defender_id", "")))
	if attacker_name.is_empty() or defender_name.is_empty():
		return ""
	return "（%s -> %s）" % [attacker_name, defender_name]


func _stack_id_exists(stack_id: String) -> bool:
	for stack_item in _state.stack:
		if str(stack_item.get("stack_id", "")) == stack_id:
			return true
	return false


func _refresh() -> void:
	if _players.is_empty():
		return
	_update_table_replay_overlay_layout()
	_hide_grave_popup()
	var started_at := Time.get_ticks_msec()
	var step_started_at := started_at
	_begin_card_view_refresh()
	_refresh_zones()
	_log_slow_perf("refresh/zones", step_started_at, NETWORK_PERF_WARN_MS)
	step_started_at = Time.get_ticks_msec()
	_refresh_selection_highlights()
	_log_slow_perf("refresh/highlights", step_started_at, NETWORK_PERF_WARN_MS)
	step_started_at = Time.get_ticks_msec()
	_refresh_cards()
	_finish_card_view_refresh()
	_log_slow_perf("refresh/cards", step_started_at, NETWORK_PERF_WARN_MS)
	step_started_at = Time.get_ticks_msec()
	_refresh_hud()
	_refresh_busy_status_panel()
	_log_slow_perf("refresh/hud", step_started_at, NETWORK_PERF_WARN_MS)
	step_started_at = Time.get_ticks_msec()
	if _auto_skip_response_window_active():
		_hide_auto_skipped_response_panels()
	_refresh_stack_panel()
	_refresh_response_panel()
	_refresh_action_panel()
	_refresh_choice_panel()
	_log_slow_perf("refresh/panels", step_started_at, NETWORK_PERF_WARN_MS)
	step_started_at = Time.get_ticks_msec()
	_run_pending_animations()
	_log_slow_perf("refresh/animations", step_started_at, NETWORK_PERF_WARN_MS)
	_log_slow_perf("refresh/full", started_at, NETWORK_PERF_WARN_MS)


func _begin_card_view_refresh() -> void:
	_card_view_seen_ids.clear()


func _finish_card_view_refresh() -> void:
	var stale_ids: Array[String] = []
	for raw_uid in _card_views_by_uid.keys():
		var uid := str(raw_uid)
		if _card_view_seen_ids.has(uid):
			continue
		stale_ids.append(uid)
	for uid in stale_ids:
		var view = _card_views_by_uid.get(uid, null)
		if view != null and is_instance_valid(view):
			if view.get_parent() == _card_layer:
				_card_layer.remove_child(view)
			view.queue_free()
		_card_views_by_uid.erase(uid)


func _request_deferred_refresh() -> void:
	if _deferred_refresh_pending:
		return
	_deferred_refresh_pending = true
	call_deferred("_flush_deferred_refresh")


func _flush_deferred_refresh() -> void:
	_deferred_refresh_pending = false
	_refresh()


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _clear_drag_highlights() -> void:
	if _drag_highlight_layer != null:
		_clear_children(_drag_highlight_layer)
	if _drag_target_layer != null:
		_clear_children(_drag_target_layer)


func _refresh_zones() -> void:
	_refresh_zone_static_visuals()
	_refresh_zone_interaction_layer()
	for player_index in range(2):
		_refresh_zone_attached_cards(player_index)
		_add_cost_area(player_index)


func _refresh_zone_static_visuals() -> void:
	var next_signature := _zone_static_visual_signature()
	if next_signature == _zone_static_signature:
		return
	_zone_static_signature = next_signature
	_clear_children(_zone_static_layer)
	_clear_children(_zone_overlay_layer)
	_add_calamity_track(_zone_static_layer)
	for player_index in range(2):
		_add_player_zone_frames(player_index, _zone_static_layer)
		_add_calamity_zone(player_index, _zone_static_layer)
		_add_zone_label(_map_table_rect(ARTIFACT_RECTS[player_index]), player_index, "圣物", _zone_static_layer)
		_add_master_hp_badge(_map_table_rect(MASTER_RECTS[player_index]), player_index, int(_players[player_index]["hp"]), int(_players[player_index]["max_hp"]), _zone_static_layer)
		_add_pile_zone_visuals(_map_table_rect(DECK_RECTS[player_index]), player_index, "牌库", _players[player_index]["deck"].size(), _zone_static_layer)
		_add_pile_zone_visuals(_map_table_rect(COST_DECK_RECTS[player_index]), player_index, "士气牌库", _players[player_index]["cost_deck"].size(), _zone_static_layer)
		_add_grave_count_label(_map_table_rect(GRAVE_RECTS[player_index]), player_index, _players[player_index]["grave"].size())


func _refresh_zone_interaction_layer() -> void:
	var next_signature := _zone_interaction_state_signature()
	if next_signature == _zone_interaction_signature:
		return
	_zone_interaction_signature = next_signature
	if _zone_interaction_layer != null:
		_clear_children(_zone_interaction_layer)
	for player_index in range(2):
		_add_pile_zone_hit_area(_map_table_rect(DECK_RECTS[player_index]), player_index, "deck")
		_add_pile_zone_hit_area(_map_table_rect(GRAVE_RECTS[player_index]), player_index, "grave")
		_add_calamity_zone_hit_area(player_index)
		_add_board_slot_choice_hit_areas(player_index)
		_add_master_zone_hit_area(player_index)


func _zone_interaction_state_signature() -> String:
	var choice_action := _active_board_slot_choice_action()
	var option_signature: Array = []
	for option in choice_action.get("options", []):
		option_signature.append({
			"id": str(option.get("id", "")),
			"row": str(option.get("row", "")),
			"col": int(option.get("col", -1)),
		})
	return JSON.stringify({
		"size": [size.x, size.y],
		"choice_action_empty": choice_action.is_empty(),
		"current_input_player": _current_input_player(),
		"slot_choice_display_player": _board_slot_choice_display_player(choice_action),
		"current_calamity": str(_state.current_calamity) if _state != null else "",
		"calamity_deck_count": _state.calamity_deck.size() if _state != null else 0,
		"options": option_signature,
	})


func _zone_static_visual_signature() -> String:
	var players_signature: Array = []
	for player_index in range(min(2, _players.size())):
		var player: Dictionary = _players[player_index]
		var artifact = player.get("artifact", null)
		players_signature.append({
			"artifact_uid": str(artifact.get("uid", "")) if artifact != null else "",
			"deck_count": player.get("deck", []).size(),
			"cost_deck_count": player.get("cost_deck", []).size(),
			"grave_count": player.get("grave", []).size(),
			"grave_top_ids": player.get("grave", []).slice(0, min(3, player.get("grave", []).size())),
			"hp": int(player.get("hp", 0)),
			"max_hp": int(player.get("max_hp", 0)),
		})
	return JSON.stringify({
		"size": [size.x, size.y],
		"calamity_value": int(_state.calamity_value) if _state != null else 0,
		"current_calamity": str(_state.current_calamity) if _state != null else "",
		"calamity_deck_count": _state.calamity_deck.size() if _state != null else 0,
		"players": players_signature,
	})


func _refresh_zone_attached_cards(player_index: int) -> void:
	var player: Dictionary = _players[player_index]
	if player["artifact"] != null:
		var artifact_rect := _map_table_rect(ARTIFACT_RECTS[player_index])
		var artifact_card_size := _card_size()
		var artifact_position := artifact_rect.position + (artifact_rect.size - artifact_card_size) * 0.5
		var artifact_source_id := str(player["artifact"].get("uid", ""))
		var can_activate_artifact := player_index == _current_input_player() and not _activation_actions_for_source(_current_input_player(), artifact_source_id).is_empty() and not _game_over and _selected_target_action.is_empty()
		var can_drag_artifact := player_index == _current_input_player() and _source_has_drag_activation(_current_input_player(), artifact_source_id) and not _game_over and not _selection_mode_active()
		_add_card_view(player["artifact"], artifact_position, artifact_card_size, can_drag_artifact, can_activate_artifact, false)
	var master_rect := _map_table_rect(MASTER_RECTS[player_index])
	var master_card_size := _card_size()
	var master_position := master_rect.position + (master_rect.size - master_card_size) * 0.5
	var master_id := _master_source_id_for_display(player_index)
	var can_activate_master := player_index == _current_input_player() and _source_has_click_activation_panel(_current_input_player(), master_id) and not _game_over and _selected_target_action.is_empty()
	var can_drag_master := player_index == _current_input_player() and _source_has_drag_activation(_current_input_player(), master_id) and not _game_over and not _selection_mode_active()
	var selectable_target := _master_is_clickable_target(player_index)
	var response_available := _card_has_response_action(master_id)
	var is_pending_target: bool = _state != null and not _state.pending_attack.is_empty() and str(_state.pending_attack.get("target_kind", "card")) == "master" and _display_target_player_from_variant(_state.pending_attack.get("target_player", -1)) == player_index
	_add_card_view(player["master"], master_position, master_card_size, can_drag_master, can_activate_master or selectable_target or response_available or is_pending_target, _response_window_active() and player_index == _current_input_player() and not response_available and not is_pending_target)


func _add_pile_zone_visuals(rect: Rect2, player_index: int, label_text: String, count: int, layer: Control) -> void:
	_add_card_back_stack(rect, player_index, count, layer)
	_add_zone_label(rect, player_index, "%s\n%d" % [label_text, count], layer)

func _add_player_zone_frames(player_index: int, layer: Control) -> void:
	var frame_color := Color(0.92, 0.95, 1.0, 0.34)
	_add_zone_frame(_map_table_rect(MASTER_RECTS[player_index]), frame_color, layer)
	_add_zone_frame(_map_table_rect(ARTIFACT_RECTS[player_index]), frame_color, layer)
	_add_zone_frame(_map_table_rect(DECK_RECTS[player_index]), frame_color, layer)
	_add_zone_frame(_map_table_rect(COST_DECK_RECTS[player_index]), frame_color, layer)
	_add_zone_frame(_map_table_rect(GRAVE_RECTS[player_index]), frame_color, layer)
	_add_zone_frame(_map_table_rect(CALAMITY_RECTS[player_index]), frame_color, layer)

func _add_zone_frame(rect: Rect2, border_color: Color, layer: Control) -> void:
	var frame := Panel.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	frame.add_theme_stylebox_override("panel", style)
	layer.add_child(frame)

func _add_board_slot_choice_hit_areas(player_index: int) -> void:
	var choice_action := _active_board_slot_choice_action()
	if choice_action.is_empty() or player_index != _board_slot_choice_display_player(choice_action):
		return
	for option in choice_action.get("options", []):
		var row := str(option.get("row", ""))
		var col := int(option.get("col", -1))
		var slot_index := _slot_index_from_row_col(row, col)
		if slot_index < 0 or slot_index >= BOARD_SLOT_COUNT:
			continue
		var hit_area := Control.new()
		hit_area.position = _map_table_rect(BOARD_RECTS[player_index][slot_index]).position
		hit_area.size = _map_table_rect(BOARD_RECTS[player_index][slot_index]).size
		hit_area.mouse_filter = Control.MOUSE_FILTER_STOP
		_zone_interaction_layer.add_child(hit_area)
		hit_area.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				if _try_click_board_choice_option(str(option.get("id", ""))):
					hit_area.accept_event()
		)

func _active_board_slot_choice_action() -> Dictionary:
	var choice_action := _find_action(_player_actions(_current_input_player()), "resolve_choice")
	if choice_action.is_empty():
		return {}
	var choice_type := str(choice_action.get("choice_type", choice_action.get("type", "")))
	if choice_type != "option_pick":
		return {}
	var operation := str(choice_action.get("operation", ""))
	if operation != "revive_selected_grave_to_slot" and operation != "manifest_kusanagi_to_slot" and operation != "deploy_selected_hand_to_slot" and operation != "set_counter_tactic_from_hand_to_slot" and operation != "play_revealed_deck_card_to_slot" and operation != "set_revealed_deck_counter_to_slot" and operation != "move_selected_battlefield_card_to_slot" and operation != "tsukuyomi_choose_move_slot" and operation != "takamagahara_morale_choose_move_slot" and operation != "hand_response_deploy_to_front_and_redirect_pending_attack":
		return {}
	return choice_action


func _board_slot_choice_display_player(choice_action: Dictionary) -> int:
	if choice_action.is_empty():
		return _current_input_player()
	var operation := str(choice_action.get("operation", ""))
	if operation == "move_selected_battlefield_card_to_slot" or operation == "tsukuyomi_choose_move_slot" or operation == "takamagahara_morale_choose_move_slot":
		var card_id := str(choice_action.get("context", {}).get("card_id", ""))
		if not card_id.is_empty():
			return _display_player_for_source(card_id, _current_input_player())
	return _current_input_player()

func _try_click_board_choice_option(option_id: String) -> bool:
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return false
	if option_id.is_empty():
		return false
	var choice_action := _active_board_slot_choice_action()
	if choice_action.is_empty():
		return false
	var payload = choice_action.get("payload_template", {}).duplicate(true)
	payload["selected_option"] = option_id
	return _execute_command(_current_input_player(), str(choice_action.get("command_type", "")), payload)


func _add_empty_zone(rect: Rect2) -> void:
	var hit_area := Control.new()
	hit_area.position = rect.position
	hit_area.size = rect.size
	hit_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_interaction_layer.add_child(hit_area)


func _add_calamity_track(layer: Control = null) -> void:
	if layer == null:
		layer = _zone_static_layer
	var lit_count: int = clamp(int(_state.calamity_value), 0, CALAMITY_TRACK_STARS)
	if lit_count <= 0:
		return
	var texture := _get_calamity_star_overlay_texture()
	if texture == null:
		return
	var table_rect := _map_table_rect(Rect2(Vector2.ZERO, TABLE_AREA_SIZE))
	var scale := _axis_scale()
	var clip_right := float(CALAMITY_STAR_CLIP_RIGHTS[min(lit_count, CALAMITY_STAR_CLIP_RIGHTS.size() - 1)])
	var clipper := Control.new()
	clipper.position = table_rect.position
	clipper.size = Vector2(clip_right * scale.x, table_rect.size.y)
	clipper.clip_contents = true
	clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipper.z_index = 25
	var overlay := TextureRect.new()
	overlay.texture = texture
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.position = Vector2.ZERO
	overlay.size = table_rect.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipper.add_child(overlay)
	layer.add_child(clipper)


func _add_calamity_zone(player_index: int, layer: Control = null) -> void:
	if layer == null:
		layer = _zone_static_layer
	var rect := _map_table_rect(CALAMITY_RECTS[player_index])
	if _state == null:
		_add_zone_label(rect, player_index, "天灾", layer)
		return
	var hidden_display_player := _hidden_calamity_display_player()
	var revealed_display_player := _revealed_calamity_display_player()
	if player_index == hidden_display_player and not _state.calamity_deck.is_empty():
		var hidden_card := _make_hidden_calamity_card_view(rect.size)
		hidden_card.position = rect.position
		hidden_card.z_index = 16
		layer.add_child(hidden_card)
		return
	if player_index != revealed_display_player or str(_state.current_calamity).is_empty():
		_add_zone_label(rect, player_index, "天灾", layer)
		return
	var card := _make_calamity_card_view(str(_state.current_calamity), rect.size, true)
	card.position = rect.position
	card.z_index = 16
	layer.add_child(card)


func _hidden_calamity_display_player() -> int:
	if _network_mode_active:
		return _display_player_for_logical(PLAYER_BOTTOM)
	return PLAYER_BOTTOM


func _revealed_calamity_display_player() -> int:
	if _network_mode_active:
		return _display_player_for_logical(PLAYER_TOP)
	return PLAYER_TOP


func _build_calamity_view_card(calamity_id: String) -> Dictionary:
	var definition: Dictionary = _card_definitions.get(calamity_id, {
		"id": calamity_id,
		"name": calamity_id,
		"type": "calamity",
		"cost": 0,
		"power": 0,
		"hp": 0,
		"text": ""
	}).duplicate(true)
	return {
		"uid": calamity_id,
		"definition_id": calamity_id,
		"definition": definition,
		"owner": PLAYER_BOTTOM,
		"zone": "calamity",
		"face": "face_up"
	}


func _build_hidden_calamity_view_card() -> Dictionary:
	return {
		"uid": "hidden_calamity_back",
		"definition_id": "hidden_calamity_back",
		"definition": {
			"id": "hidden_calamity_back",
			"name": "未开启天灾",
			"type": "calamity",
			"cost": 0,
			"power": 0,
			"hp": 0,
			"text": "",
			"card_back_path": CALAMITY_CARD_BACK_PATH
		},
		"owner": PLAYER_BOTTOM,
		"zone": "calamity",
		"face": "face_down",
		"card_back_path": CALAMITY_CARD_BACK_PATH
	}



func _make_calamity_card_view(calamity_id: String, panel_size: Vector2, enable_long_press_preview: bool) -> Control:
	var card_view: Control = BattleCardScript.new()
	card_view.size = panel_size
	card_view.custom_minimum_size = panel_size
	card_view.setup(_build_calamity_view_card(calamity_id), false, false, false)
	card_view.set_use_overlay_long_press_preview(enable_long_press_preview)
	if enable_long_press_preview:
		card_view.long_press_preview_requested.connect(_show_overlay_card_preview)
		card_view.long_press_preview_finished.connect(_hide_overlay_card_preview)
	return card_view


func _make_hidden_calamity_card_view(panel_size: Vector2) -> Control:
	var card_view: Control = BattleCardScript.new()
	card_view.size = panel_size
	card_view.custom_minimum_size = panel_size
	card_view.setup(_build_hidden_calamity_view_card(), false, false, false)
	card_view.set_use_overlay_long_press_preview(false)
	return card_view


func _get_calamity_star_overlay_texture() -> Texture2D:
	if _calamity_star_overlay_texture != null:
		return _calamity_star_overlay_texture
	var texture := _load_texture_resource(CALAMITY_STAR_OVERLAY_PATH)
	if texture == null:
		push_warning("Unable to load calamity star overlay: %s" % CALAMITY_STAR_OVERLAY_PATH)
		return null
	_calamity_star_overlay_texture = texture
	return _calamity_star_overlay_texture


func _get_rule_card_back_texture() -> Texture2D:
	if _rule_card_back_texture != null:
		return _rule_card_back_texture
	var texture := _load_texture_resource(RULE_CARD_BACK_PATH)
	if texture == null:
		push_warning("Unable to load rule card back image: %s" % RULE_CARD_BACK_PATH)
		return null
	_rule_card_back_texture = texture
	return _rule_card_back_texture


func _get_rule_start_background_texture() -> Texture2D:
	if _rule_start_background_texture != null:
		return _rule_start_background_texture
	var texture := _load_texture_resource(RULE_START_BACKGROUND_PATH)
	if texture == null:
		push_warning("Unable to load rule start background image: %s" % RULE_START_BACKGROUND_PATH)
		return null
	_rule_start_background_texture = texture
	return _rule_start_background_texture

func _get_battlefield_background_texture() -> Texture2D:
	if _battlefield_background_texture != null:
		return _battlefield_background_texture
	var texture := _load_texture_resource(BACKGROUND_PATH)
	if texture == null:
		push_warning("Unable to load battlefield background image: %s" % BACKGROUND_PATH)
		return null
	_battlefield_background_texture = texture
	return _battlefield_background_texture


func _get_active_background_texture() -> Texture2D:
	if not DeckBuilderStore.get_selected_background_card_id().is_empty():
		var user_texture := _get_user_background_texture()
		if user_texture != null:
			return user_texture
	return _get_rule_start_background_texture()


func _get_user_background_texture() -> Texture2D:
	if _user_background_texture != null:
		return _user_background_texture
	if not FileAccess.file_exists(USER_BACKGROUND_OUTPUT_PATH):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(USER_BACKGROUND_OUTPUT_PATH))
	if image == null or image.is_empty():
		return null
	_user_background_texture = ImageTexture.create_from_image(image)
	return _user_background_texture


func _reload_user_background_texture() -> Texture2D:
	_user_background_texture = null
	return _get_user_background_texture()


func _apply_active_background_to_scene() -> void:
	var start_texture := _get_active_background_texture()
	if start_texture == null:
		start_texture = _get_rule_start_background_texture()
	var battlefield_texture := _get_battlefield_background_texture()
	if battlefield_texture == null:
		battlefield_texture = start_texture
	if _background != null:
		_background.texture = battlefield_texture
	if _start_panel_background != null:
		_start_panel_background.texture = start_texture
	if _history_view != null:
		_history_view.set_background_texture(start_texture)
	if _deck_builder_view != null:
		_deck_builder_view.sync_background_from_store()


func _on_background_changed(_message: String) -> void:
	_refresh_custom_background_from_selection()


func _refresh_custom_background_from_selection() -> void:
	var selected_card_id := DeckBuilderStore.get_selected_background_card_id()
	if selected_card_id.is_empty():
		_user_background_texture = null
		if _background != null or _start_panel_background != null:
			_apply_active_background_to_scene()
		return
	if not _generate_background_from_card(selected_card_id):
		push_warning("Unable to generate custom background for %s" % selected_card_id)
	_apply_active_background_to_scene()


func _generate_background_from_card(card_id: String) -> bool:
	var source_path := _background_source_path_for_id(card_id)
	if source_path.is_empty():
		return false
	var image := _load_image_from_asset(source_path)
	if image == null or image.is_empty():
		return false
	var processed := _build_background_image_from_card(image)
	if processed == null or processed.is_empty():
		return false
	_user_background_texture = ImageTexture.create_from_image(processed)
	var output_path := ProjectSettings.globalize_path(USER_BACKGROUND_OUTPUT_PATH)
	var output_dir := output_path.get_base_dir()
	if not output_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(output_dir)
	var png_buffer := processed.save_png_to_buffer()
	if png_buffer.is_empty():
		return _user_background_texture != null
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return _user_background_texture != null
	file.store_buffer(png_buffer)
	file.flush()
	file.close()
	_reload_user_background_texture()
	return _user_background_texture != null


func _background_source_path_for_id(card_id: String) -> String:
	var illustration_path := _illustration_source_path_for_id(card_id)
	if not illustration_path.is_empty():
		return illustration_path
	var definition: Dictionary = _card_definitions.get(card_id, {})
	if definition is Dictionary:
		var local_path := str(definition.get("card_face_path", ""))
		if _path_has_texture_resource(local_path):
			return local_path
	var entry := CardGalleryCatalog.get_entry(card_id)
	if not entry.is_empty():
		var face_path := str(entry.get("face_path", ""))
		if _path_has_texture_resource(face_path):
			return face_path
		var thumb_path := str(entry.get("thumb_path", ""))
		if _path_has_texture_resource(thumb_path):
			return thumb_path
	return ""


func _illustration_source_path_for_id(card_id: String) -> String:
	var candidate_names: Array[String] = []
	var definition: Dictionary = _card_definitions.get(card_id, {})
	if definition is Dictionary:
		var definition_name := str(definition.get("name", "")).strip_edges()
		if not definition_name.is_empty():
			candidate_names.append(definition_name)
	var entry := CardGalleryCatalog.get_entry(card_id)
	if not entry.is_empty():
		var entry_name := str(entry.get("name", "")).strip_edges()
		var source_code := str(entry.get("source_code", "")).strip_edges()
		if not entry_name.is_empty() and not candidate_names.has(entry_name):
			candidate_names.append(entry_name)
		if not source_code.is_empty() and not candidate_names.has(source_code):
			candidate_names.append(source_code)
	if not candidate_names.has(card_id):
		candidate_names.append(card_id)
	for candidate_name in candidate_names:
		for extension in ["png", "jpg", "jpeg", "webp"]:
			var thumb_path := "%s/%s.%s" % [RULE_ILLUSTRATION_THUMB_DIR, candidate_name, extension]
			if _path_has_texture_resource(thumb_path):
				return thumb_path
			var path := "%s/%s.%s" % [RULE_ILLUSTRATION_DIR, candidate_name, extension]
			if _path_has_texture_resource(path):
				return path
	return ""


func _build_background_image_from_card(source_image: Image) -> Image:
	var working := source_image.duplicate()
	if working == null or working.is_empty():
		return null
	working.convert(Image.FORMAT_RGBA8)
	var width: int = working.get_width()
	var height: int = working.get_height()
	if width <= 0 or height <= 0:
		return null
	var source_ratio: float = float(width) / float(height)
	var crop_width: int = width
	var crop_height: int = height
	if source_ratio > DESIGN_ASPECT_RATIO:
		crop_width = int(round(height * DESIGN_ASPECT_RATIO))
	else:
		crop_height = int(round(width / DESIGN_ASPECT_RATIO))
	crop_width = clampi(crop_width, 1, width)
	crop_height = clampi(crop_height, 1, height)
	var crop_x := int((width - crop_width) * 0.5)
	var crop_y := int((height - crop_height) * 0.20)
	crop_y = clampi(crop_y, 0, max(0, height - crop_height))
	working = working.get_region(Rect2i(crop_x, crop_y, crop_width, crop_height))
	working.resize(int(DESIGN_SIZE.x), int(DESIGN_SIZE.y), Image.INTERPOLATE_LANCZOS)
	return working


func _add_artifact_zone(player_index: int) -> void:
	var rect := _map_table_rect(ARTIFACT_RECTS[player_index])
	var player: Dictionary = _players[player_index]
	_add_zone_label(rect, player_index, "圣物", _zone_static_layer)
	if player["artifact"] == null:
		return
	var card_size := _card_size()
	var position := rect.position + (rect.size - card_size) * 0.5
	var source_id := str(player["artifact"].get("uid", ""))
	var can_activate := player_index == _current_input_player() and not _activation_actions_for_source(_current_input_player(), source_id).is_empty() and not _game_over and _selected_target_action.is_empty()
	var can_drag_artifact := player_index == _current_input_player() and _source_has_drag_activation(_current_input_player(), source_id) and not _game_over and not _selection_mode_active()
	_add_card_view(player["artifact"], position, card_size, can_drag_artifact, can_activate, false)


func _add_master_zone(player_index: int) -> void:
	_add_master_zone_hit_area(player_index)
	var rect := _map_table_rect(MASTER_RECTS[player_index])
	var player: Dictionary = _players[player_index]
	_add_master_hp_badge(rect, player_index, int(player["hp"]), int(player["max_hp"]), _zone_static_layer)
	var card_size := _card_size()
	var position := rect.position + (rect.size - card_size) * 0.5
	var master_id := _master_source_id_for_display(player_index)
	var can_activate := player_index == _current_input_player() and _source_has_click_activation_panel(_current_input_player(), master_id) and not _game_over and _selected_target_action.is_empty()
	var can_drag_master := player_index == _current_input_player() and _source_has_drag_activation(_current_input_player(), master_id) and not _game_over and not _selection_mode_active()
	var selectable_target := _master_is_clickable_target(player_index)
	var response_available := _card_has_response_action(master_id)
	var is_pending_target: bool = _state != null and not _state.pending_attack.is_empty() and str(_state.pending_attack.get("target_kind", "card")) == "master" and _display_target_player_from_variant(_state.pending_attack.get("target_player", -1)) == player_index
	_add_card_view(player["master"], position, card_size, can_drag_master, can_activate or selectable_target or response_available or is_pending_target, _response_window_active() and player_index == _current_input_player() and not response_available and not is_pending_target)


func _add_master_zone_hit_area(player_index: int) -> void:
	var hit_area := Control.new()
	var rect := _map_table_rect(MASTER_RECTS[player_index])
	hit_area.position = rect.position
	hit_area.size = rect.size
	hit_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_zone_interaction_layer.add_child(hit_area)
	hit_area.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.double_click:
				_master_double_click_consumed = true
				_on_master_double_clicked(player_index)
				hit_area.accept_event()
			elif not event.pressed:
				if _master_double_click_consumed:
					_master_double_click_consumed = false
					hit_area.accept_event()
					return
				_on_master_clicked(player_index)
				hit_area.accept_event()
	)


func _add_master_hp_badge(rect: Rect2, player_index: int, hp: int, max_hp: int, layer: Control = null) -> void:
	if layer == null:
		layer = _zone_static_layer
	var badge_rect := _master_hp_badge_rect(rect)

	var panel := Panel.new()
	panel.position = badge_rect.position
	panel.size = badge_rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.86)
	style.border_color = Color(0.82, 0.88, 1.0, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)

	var label := _make_label(13, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	label.text = "%d/%d" % [hp, max_hp]
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)
	_orient_control(panel, player_index)
	layer.add_child(panel)


func _master_hp_badge_rect(master_rect: Rect2) -> Rect2:
	var axis: Vector2 = _axis_scale()
	var badge_size: Vector2 = Vector2(min(master_rect.size.x, 84.0 * axis.x), max(18.0, 24.0 * axis.y))
	var gap: float = max(3.0, 6.0 * axis.y)
	var badge_position: Vector2 = Vector2(
		master_rect.position.x + (master_rect.size.x - badge_size.x) * 0.5,
		master_rect.position.y - badge_size.y - gap
	)
	if badge_position.y < gap:
		badge_position.y = master_rect.position.y + master_rect.size.y + gap
	return Rect2(badge_position, badge_size)


func _add_deck_zone(player_index: int) -> void:
	var rect := _map_table_rect(DECK_RECTS[player_index])
	_add_pile_zone(rect, player_index, "牌库", _players[player_index]["deck"].size(), "deck")


func _add_pile_zone_hit_area(rect: Rect2, player_index: int, zone_kind: String) -> void:
	var hit_area := Control.new()
	hit_area.position = rect.position
	hit_area.size = rect.size
	hit_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_zone_interaction_layer.add_child(hit_area)
	hit_area.gui_input.connect(_on_pile_zone_gui_input.bind(hit_area, player_index, zone_kind))
	hit_area.mouse_exited.connect(_on_pile_zone_mouse_exited.bind(hit_area))


func _add_calamity_zone_hit_area(player_index: int) -> void:
	if _state == null or str(_state.current_calamity).is_empty():
		return
	if player_index != _revealed_calamity_display_player():
		return
	var rect := _map_table_rect(CALAMITY_RECTS[player_index])
	_add_pile_zone_hit_area(rect, player_index, "calamity")


func _add_pile_zone(rect: Rect2, player_index: int, label_text: String, count: int, zone_kind: String) -> void:
	var clickable := zone_kind == "deck" or zone_kind == "grave"
	var hit_area := Control.new()
	hit_area.position = rect.position
	hit_area.size = rect.size
	hit_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if clickable:
		hit_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_zone_interaction_layer.add_child(hit_area)
	hit_area.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if zone_kind == "deck" and clickable:
				_on_draw_pressed()
			elif zone_kind == "grave" and clickable:
				_toggle_grave_popup(player_index)
	)
	_add_card_back_stack(rect, player_index, count, _zone_static_layer)
	_add_zone_label(rect, player_index, "%s\n%d" % [label_text, count], _zone_static_layer)


func _on_pile_zone_gui_input(event: InputEvent, hit_area: Control, player_index: int, zone_kind: String) -> void:
	if hit_area == null or not is_instance_valid(hit_area):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if zone_kind == "grave" and event.double_click:
				_end_pile_zone_press(hit_area)
				_hide_overlay_card_preview()
				_toggle_grave_popup(player_index)
				hit_area.accept_event()
				return
			_begin_pile_zone_press(hit_area, player_index, zone_kind)
			hit_area.accept_event()
			return
		var preview_active := bool(hit_area.get_meta("pile_long_press_preview_active", false))
		_end_pile_zone_press(hit_area)
		if preview_active:
			_hide_overlay_card_preview()
		elif zone_kind == "calamity":
			_open_test_mode_calamity_picker()
		elif zone_kind == "deck":
			_on_draw_pressed()
		hit_area.accept_event()


func _begin_pile_zone_press(hit_area: Control, player_index: int, zone_kind: String) -> void:
	_pile_long_press_token_seed += 1
	var token := _pile_long_press_token_seed
	hit_area.set_meta("pile_long_press_token", token)
	hit_area.set_meta("pile_pressing", true)
	hit_area.set_meta("pile_long_press_preview_active", false)
	var timer := get_tree().create_timer(PILE_LONG_PRESS_SECONDS)
	timer.timeout.connect(_on_pile_zone_long_press_timeout.bind(hit_area, player_index, zone_kind, token))


func _end_pile_zone_press(hit_area: Control) -> void:
	if hit_area == null or not is_instance_valid(hit_area):
		return
	hit_area.set_meta("pile_pressing", false)
	hit_area.set_meta("pile_long_press_token", -1)


func _on_pile_zone_mouse_exited(hit_area: Control) -> void:
	_end_pile_zone_press(hit_area)
	if hit_area != null and is_instance_valid(hit_area):
		hit_area.set_meta("pile_long_press_preview_active", false)
	_hide_overlay_card_preview()


func _on_pile_zone_long_press_timeout(hit_area: Control, player_index: int, zone_kind: String, token: int) -> void:
	if hit_area == null or not is_instance_valid(hit_area):
		return
	if int(hit_area.get_meta("pile_long_press_token", -1)) != token:
		return
	if not bool(hit_area.get_meta("pile_pressing", false)):
		return
	var preview_source := _pile_zone_preview_source(player_index, zone_kind)
	if preview_source.is_empty():
		return
	hit_area.set_meta("pile_long_press_preview_active", true)
	_show_overlay_card_preview_from_source(preview_source)


func _pile_zone_preview_source(player_index: int, zone_kind: String) -> Dictionary:
	if zone_kind == "calamity":
		if _state == null:
			return {}
		if player_index != _revealed_calamity_display_player():
			return {}
		var calamity_id := str(_state.current_calamity)
		if calamity_id.is_empty():
			return {}
		return _build_calamity_view_card(calamity_id)
	if zone_kind != "grave":
		return {}
	if player_index < 0 or player_index >= _players.size():
		return {}
	var grave_ids: Array = _players[player_index].get("grave", [])
	if grave_ids.is_empty():
		return {}
	var top_grave_id := str(grave_ids[0])
	for grave_card in _players[player_index].get("grave_cards", []):
		if grave_card is Dictionary and str((grave_card as Dictionary).get("uid", "")) == top_grave_id:
			return (grave_card as Dictionary).duplicate(true)
	return {}


func _open_test_mode_calamity_picker() -> void:
	if not _is_current_test_duel() or _state == null:
		return
	var player_id := _current_local_input_player()
	if player_id < 0:
		return
	var allowed_calamity_ids := {
		"calamity_s01_ds01": true,
		"sys_calamity_silence": true,
		"calamity_s01_ds05": true,
		"calamity_s01_ds07": true,
		"calamity_s01_ds08": true,
		"calamity_s01_ds09": true,
		"calamity_s02_ds03": true
	}
	var options: Array[Dictionary] = []
	for definition_id in _card_definitions.keys():
		var definition: Dictionary = _card_definitions.get(definition_id, {})
		if str(definition.get("type", "")) != "calamity":
			continue
		if not bool(allowed_calamity_ids.get(str(definition_id), false)):
			continue
		options.append({
			"id": str(definition_id),
			"label": _card_name(str(definition_id))
		})
	if options.is_empty():
		_push_log("当前没有可选天灾。")
		return
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("label", a.get("id", ""))) < str(b.get("label", b.get("id", "")))
	)
	_local_play_option_choice = {
		"proposal_id": "test_mode_choose_calamity",
		"kind": "resolve_choice",
		"command_type": "DebugCommand",
		"title": "选择要触发的天灾",
		"choice_type": "option_pick",
		"operation": "test_mode_choose_calamity",
		"payload_template": {
			"action": "reveal_calamity"
		},
		"options": options,
		"hint_text": "测试模式：请选择本次要触发的天灾。",
		"top_hint_text": "测试模式：选择 1 张天灾并立即触发。"
	}
	_selected_target_action = {}
	_selected_stack_target_id = ""
	_selected_attacker_uid = ""
	_clear_action_focus()
	_refresh()


func _toggle_grave_popup(player_index: int) -> void:
	if _grave_popup_overlay != null and is_instance_valid(_grave_popup_overlay):
		_hide_grave_popup()
		return
	_show_grave_popup(player_index)


func _show_grave_popup(player_index: int) -> void:
	_hide_grave_popup()
	if player_index < 0 or player_index >= _players.size():
		return
	var ordered_grave_cards: Array[Dictionary] = []
	var grave_card_views_by_id := {}
	for grave_card in _players[player_index].get("grave_cards", []):
		if grave_card is Dictionary:
			grave_card_views_by_id[str((grave_card as Dictionary).get("uid", ""))] = (grave_card as Dictionary).duplicate(true)
	for grave_id in _players[player_index].get("grave", []):
		var card_view: Dictionary = grave_card_views_by_id.get(str(grave_id), {})
		if not card_view.is_empty():
			ordered_grave_cards.append(card_view)
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 970
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_hide_grave_popup()
			overlay.accept_event()
	)
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.06, 0.72)
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(min(size.x * 0.34, 290.0), min(size.y * 0.78, 980.0))
	panel.size = panel.custom_minimum_size
	panel.position = Vector2((size.x - panel.size.x) * 0.5, (size.y - panel.size.y) * 0.5)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			panel.accept_event()
	)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.11, 0.18, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.83, 0.75, 0.56, 0.95)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.content_margin_left = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 12)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(content)
	var title := _make_label(18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	title.text = "%s墓地" % _player_side_name(player_index)
	content.add_child(title)
	var subtitle := _make_label(12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	subtitle.text = "从上到下对应墓地顶到墓地底"
	subtitle.modulate = Color(0.83, 0.88, 0.95, 0.84)
	content.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, panel.size.y - 88.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(list)
	if ordered_grave_cards.is_empty():
		var empty_label := _make_label(14, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
		empty_label.text = "墓地为空"
		list.add_child(empty_label)
	else:
		for grave_card in ordered_grave_cards:
			var card_view: Control = BattleCardScript.new()
			card_view.custom_minimum_size = Vector2(180.0, 252.0)
			card_view.size = card_view.custom_minimum_size
			card_view.set_use_overlay_long_press_preview(true)
			card_view.setup((grave_card as Dictionary).duplicate(true), false, false, false)
			card_view.long_press_preview_requested.connect(_show_overlay_card_preview)
			card_view.long_press_preview_finished.connect(_hide_overlay_card_preview)
			list.add_child(card_view)
	overlay.add_child(panel)
	_ui_layer.add_child(overlay)
	_grave_popup_overlay = overlay


func _hide_grave_popup() -> void:
	if _grave_popup_overlay != null and is_instance_valid(_grave_popup_overlay):
		_grave_popup_overlay.queue_free()
	_grave_popup_overlay = null


func _add_card_back_stack(rect: Rect2, player_index: int, count: int, layer: Control = null) -> void:
	if layer == null:
		layer = _zone_static_layer
	if count <= 0:
		return
	var pile_size := Vector2(rect.size.x * 0.76, rect.size.y * 0.82)
	var start := rect.position + (rect.size - pile_size) * 0.5
	var layers: int = min(3, count)
	var back_texture := _get_rule_card_back_texture()
	for i in range(layers):
		var card_back := TextureRect.new()
		card_back.position = start + Vector2(i * 3.0, -i * 3.0)
		card_back.size = pile_size
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_SCALE
		card_back.texture = back_texture
		_orient_control(card_back, player_index)
		layer.add_child(card_back)


func _grave_card_positions(player_index: int, count: int, card_size: Vector2) -> Array:
	var positions: Array = []
	if count <= 0:
		return positions
	var rect := _map_table_rect(GRAVE_RECTS[player_index])
	var x_step: float = 3.0
	var y_step: float = -2.0
	var stack_width: float = card_size.x + float(max(0, count - 1)) * x_step
	var stack_height: float = card_size.y + float(max(0, count - 1)) * absf(y_step)
	var start: Vector2 = Vector2(
		rect.position.x + (rect.size.x - stack_width) * 0.5,
		rect.position.y + 10.0
	)
	for i in range(count):
		var visual_index := count - 1 - i
		positions.append(start + Vector2(visual_index * x_step, float(visual_index) * y_step))
	return positions


func _morale_display_entries(player_index: int) -> Array:
	var entries: Array = []
	if player_index < 0 or player_index >= _players.size():
		return entries
	var active_cards: Array = _players[player_index]["cost_area_cards"]
	var spent_cards: Array = _players[player_index]["spent_cost_area_cards"]
	var sequence := 0
	for i in range(active_cards.size()):
		entries.append(_morale_display_entry(active_cards[i], "cost_area", i, true, sequence))
		sequence += 1
	for i in range(spent_cards.size()):
		entries.append(_morale_display_entry(spent_cards[i], "spent_cost_area", i, false, sequence))
		sequence += 1
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a := int(a.get("rank", 0))
		var rank_b := int(b.get("rank", 0))
		if rank_a != rank_b:
			return rank_a < rank_b
		return int(a.get("sequence", 0)) < int(b.get("sequence", 0))
	)
	return entries


func _morale_display_entry(card: Dictionary, zone: String, zone_index: int, is_active: bool, sequence: int) -> Dictionary:
	var rank := MORALE_DISPLAY_RANK_ACTIVE if is_active else MORALE_DISPLAY_RANK_SPENT
	if _is_black_lotus_morale_card(card):
		rank = MORALE_DISPLAY_RANK_BLACK_LOTUS
	return {
		"card": card,
		"zone": zone,
		"zone_index": zone_index,
		"is_active": is_active,
		"rank": rank,
		"sequence": sequence
	}


func _is_black_lotus_morale_card(card: Dictionary) -> bool:
	if str(card.get("definition_id", "")) == BLACK_LOTUS_DEFINITION_ID:
		return true
	var definition = card.get("definition", {})
	return definition is Dictionary and str(definition.get("id", "")) == BLACK_LOTUS_DEFINITION_ID


func _add_cost_area(player_index: int) -> void:
	var rect := _map_table_rect(COST_AREA_RECTS[player_index])
	var display_entries := _morale_display_entries(player_index)
	var card_size := _card_size()
	var positions := _cost_card_positions(rect, display_entries.size(), card_size)
	for i in range(display_entries.size()):
		var entry: Dictionary = display_entries[i]
		var card: Dictionary = entry.get("card", {})
		var is_active_morale := bool(entry.get("is_active", false))
		var is_selected := is_active_morale and _selected_morale_filter and player_index == _current_input_player()
		var view: Control = _add_card_view(card, positions[i], card_size, false, is_selected, false)
		view.z_index = 12 + i


func _add_zone_label(rect: Rect2, player_index: int, text: String, layer: Control = null) -> void:
	if layer == null:
		layer = _zone_static_layer
	var label := _make_label(12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	label.text = text
	label.position = rect.position + Vector2(4, 4)
	label.size = rect.size - Vector2(8, 8)
	_orient_control(label, player_index)
	layer.add_child(label)


func _add_grave_count_label(rect: Rect2, player_index: int, count: int) -> void:
	var label := _make_label(12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	label.text = "墓地\n%d" % count
	label.size = Vector2(rect.size.x - 8.0, 42.0)
	label.position = Vector2(rect.position.x + 4.0, rect.position.y + rect.size.y - label.size.y - 4.0)
	label.z_index = 181
	_orient_control(label, player_index)
	_zone_overlay_layer.add_child(label)


func _orient_control(node: Control, player_index: int) -> void:
	pass


func _refresh_cards() -> void:
	var card_size := _card_size()
	var input_player := _current_input_player()
	var choice_action := _current_choice_action()
	for player_index in range(2):
		for slot_index in range(BOARD_SLOT_COUNT):
			var card = _players[player_index]["board"][slot_index]
			if card == null:
				continue
			var slot_rect: Rect2 = _map_table_rect(BOARD_RECTS[player_index][slot_index])
			var position := slot_rect.position + (slot_rect.size - card_size) * 0.5
			var uid := str(card.get("uid", ""))
			var can_attack := bool(card.get("can_attack", false))
			var can_move := bool(card.get("can_move", false))
			var can_select := player_index == input_player and can_attack and not _game_over and _selected_target_action.is_empty()
			var response_available := _card_has_response_action(uid)
			var is_pending_operation_card := _card_is_pending_attack_participant(uid)
			var board_choice_selected := _is_board_card_choice_action(choice_action) and _choice_selected_card_ids.has(uid)
			var choice_move_draggable := _choice_allows_drag_board_card(choice_action, uid)
			var is_selected := str(card.get("uid", "")) == _selected_attacker_uid or response_available or is_pending_operation_card or board_choice_selected
			var selectable_target := _card_is_clickable_target(uid)
			var can_drag := not _game_over and (choice_move_draggable or (player_index == input_player and (can_attack or can_move) and not _selection_mode_active()))
			var is_dimmed := _manual_response_window_active() and player_index == input_player and not response_available and not is_pending_operation_card
			if _is_board_card_choice_action(choice_action):
				var board_choice_candidates := _string_array_from_variant_array(choice_action.get("candidate_card_ids", []))
				var is_board_choice_candidate := board_choice_candidates.has(uid)
				if str(choice_action.get("operation", "")) == "hijikata_entry_destroy_combo":
					is_board_choice_candidate = is_board_choice_candidate and _is_hijikata_entry_choice_card_selectable(choice_action, uid)
				is_dimmed = not is_board_choice_candidate
			_add_card_view(card, position, card_size, can_drag, is_selected or selectable_target or choice_move_draggable, is_dimmed)

		var hand: Array = _players[player_index]["hand"]
		var sorted_hand := _sorted_hand_cards(hand)
		var positions := _hand_positions(player_index, sorted_hand.size(), card_size)
		var deploy_candidates: Array[String] = []
		if _is_hand_deploy_choice_action(choice_action):
			deploy_candidates = _string_array_from_variant_array(choice_action.get("candidate_card_ids", []))
		for i in range(sorted_hand.size()):
			var card: Dictionary = sorted_hand[i]
			var hand_uid := str(card.get("uid", ""))
			var response_available := _card_has_response_action(hand_uid)
			var guard_selected := _selected_master_guard_cards.has(hand_uid)
			var deploy_candidate := deploy_candidates.has(hand_uid)
			var hand_choice_selected := _is_direct_hand_choice_action(choice_action) and _choice_selected_card_ids.has(hand_uid)
			var active_hand := player_index == input_player and _can_drag_hand_card(player_index, hand_uid) and not _game_over
			var is_dimmed := false
			if _is_hand_deploy_choice_action(choice_action) and player_index == input_player:
				is_dimmed = not deploy_candidate
			elif _is_direct_hand_choice_action(choice_action) and player_index == input_player:
				is_dimmed = not _string_array_from_variant_array(choice_action.get("candidate_card_ids", [])).has(hand_uid)
			elif _manual_response_window_active() and player_index == input_player and not response_available and not guard_selected:
				is_dimmed = true
			var allow_hand_drag := active_hand and (not _selection_mode_active() or _is_hand_deploy_choice_action(choice_action))
			var view: Control = _add_card_view(card, positions[i], card_size, allow_hand_drag, response_available or guard_selected or deploy_candidate or hand_choice_selected, is_dimmed)
			view.z_index = 40 + i
		var grave_cards: Array = _players[player_index].get("grave_cards", [])
		var grave_card_size: Vector2 = Vector2(card_size.x * 0.78, card_size.y * 0.78)
		var grave_positions: Array = _grave_card_positions(player_index, min(3, grave_cards.size()), grave_card_size)
		for i in range(grave_positions.size()):
			var grave_card: Dictionary = grave_cards[i]
			var grave_view: Control = _add_card_view(grave_card, grave_positions[i], grave_card_size, false, false, false)
			grave_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grave_view.z_index = 10 + (grave_positions.size() - i)


func _refresh_selection_highlights() -> void:
	var next_signature := _selection_highlight_state_signature()
	if next_signature == _selection_highlight_signature:
		return
	_selection_highlight_signature = next_signature
	_clear_children(_selection_highlight_layer)
	if _game_over or _dragging_card_uid != "":
		return
	var choice_action := _current_choice_action()
	if _is_hand_deploy_choice_action(choice_action):
		for raw_card_id in choice_action.get("candidate_card_ids", []):
			var hand_rect := _source_highlight_rect(str(raw_card_id))
			if hand_rect.size.x > 0.0 and hand_rect.size.y > 0.0:
				_add_highlight_rect(hand_rect, Color(1.0, 0.92, 0.38, 0.98), Color(1.0, 0.86, 0.16, 0.16))
		for option in _current_deploy_choice_slot_options():
			var row := str(option.get("row", ""))
			var col := int(option.get("col", -1))
			var slot_index := _slot_index_from_row_col(row, col)
			if slot_index < 0 or slot_index >= BOARD_SLOT_COUNT:
				continue
			_add_highlight_rect(_map_table_rect(BOARD_RECTS[_current_input_player()][slot_index]), Color(0.66, 0.92, 1.0, 0.96), Color(0.52, 0.82, 1.0, 0.16))
	if _is_board_slot_choice_action(choice_action):
		var slot_display_player := _board_slot_choice_display_player(choice_action)
		for option in choice_action.get("options", []):
			var row := str(option.get("row", ""))
			var col := int(option.get("col", -1))
			var slot_index := _slot_index_from_row_col(row, col)
			if slot_index < 0 or slot_index >= BOARD_SLOT_COUNT:
				continue
			_add_highlight_rect(_map_table_rect(BOARD_RECTS[slot_display_player][slot_index]), Color(0.66, 0.92, 1.0, 0.96), Color(0.52, 0.82, 1.0, 0.16))
		return
	if not choice_action.is_empty() and str(choice_action.get("choice_type", "")) == "candidate_cards_pick":
		var operation := str(choice_action.get("operation", ""))
		for raw_card_id in choice_action.get("highlight_card_ids", []):
			var highlight_rect := _choice_source_highlight_rect(choice_action, str(raw_card_id))
			if highlight_rect.size.x > 0.0 and highlight_rect.size.y > 0.0:
				_add_highlight_rect(highlight_rect, Color(0.92, 0.86, 1.0, 0.96), Color(0.70, 0.58, 1.0, 0.12))
		for selected_card_id in _choice_selected_card_ids:
			var selected_rect := _choice_source_highlight_rect(choice_action, selected_card_id)
			if selected_rect.size.x > 0.0 and selected_rect.size.y > 0.0:
				_add_highlight_rect(selected_rect, Color(1.0, 0.86, 0.28, 0.99), Color(1.0, 0.78, 0.08, 0.18))
		for raw_card_id in choice_action.get("candidate_card_ids", []):
			var candidate_id := str(raw_card_id)
			if operation == "hijikata_entry_destroy_combo" and not _is_hijikata_entry_choice_card_selectable(choice_action, candidate_id):
				continue
			var rect := _choice_source_highlight_rect(choice_action, candidate_id)
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				_add_highlight_rect(rect, Color(0.66, 0.92, 1.0, 0.96), Color(0.52, 0.82, 1.0, 0.16))
		return
	if _manual_response_window_active():
		_add_response_window_highlights()
	if not _selected_target_action.is_empty():
		for target in _selected_target_action.get("targets", []):
			_add_target_highlight(target, Color(0.66, 0.92, 1.0, 0.96), Color(0.52, 0.82, 1.0, 0.14))
		return
	if not _selected_source_id.is_empty():
		var source_rect := _source_highlight_rect(_selected_source_id)
		if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
			_add_highlight_rect(source_rect, Color(0.72, 1.0, 0.78, 0.98), Color(0.34, 0.82, 0.42, 0.14))
		return
	if _selected_morale_filter:
		_add_highlight_rect(_map_table_rect(COST_AREA_RECTS[_current_input_player()]), Color(0.72, 1.0, 0.78, 0.98), Color(0.34, 0.82, 0.42, 0.12))
		return
	if _selected_attacker_uid.is_empty():
		return
	var attack_action := _attack_action_for_attacker(_current_input_player(), _selected_attacker_uid)
	if attack_action.is_empty():
		return
	for target in attack_action.get("targets", []):
		_add_target_highlight(target, Color(1.0, 0.78, 0.46, 0.96), Color(1.0, 0.62, 0.20, 0.14))


func _selection_highlight_state_signature() -> String:
	var layout_signature: Array = []
	for player_index in range(min(2, _players.size())):
		var player: Dictionary = _players[player_index]
		var artifact = player.get("artifact", null)
		var board_ids: Array[String] = []
		for card in player.get("board", []):
			board_ids.append("" if card == null else str(card.get("uid", "")))
		var hand_ids: Array[String] = []
		for card in _sorted_hand_cards(player.get("hand", [])):
			hand_ids.append(str(card.get("uid", "")))
		layout_signature.append({
			"artifact_uid": str(artifact.get("uid", "")) if artifact != null else "",
			"board_ids": board_ids,
			"hand_ids": hand_ids,
			"master_uid": str(player.get("master", {}).get("uid", "")),
		})
	return JSON.stringify({
		"size": [size.x, size.y],
		"game_over": _game_over,
		"dragging_card_uid": _dragging_card_uid,
		"input_player": _current_input_player(),
		"choice_action": _current_choice_action(),
		"manual_response_window": _manual_response_window_active(),
		"pending_attack": _state.pending_attack if _state != null else {},
		"response_actions": _response_highlight_actions(),
		"selected_attacker_uid": _selected_attacker_uid,
		"selected_morale_filter": _selected_morale_filter,
		"selected_source_id": _selected_source_id,
		"selected_target_action": _selected_target_action,
		"layout": layout_signature,
	})


func _panel_signature_changed(panel_kind: String, next_signature: String) -> bool:
	match panel_kind:
		"action":
			if next_signature == _action_panel_signature:
				return false
			_action_panel_signature = next_signature
			return true
		"response":
			if next_signature == _response_panel_signature:
				return false
			_response_panel_signature = next_signature
			return true
		"choice":
			if next_signature == _choice_panel_signature:
				return false
			_choice_panel_signature = next_signature
			return true
		"stack":
			if next_signature == _stack_panel_signature:
				return false
			_stack_panel_signature = next_signature
			return true
	return true


func _add_response_window_highlights() -> void:
	if _state != null and not _state.pending_attack.is_empty():
		var attack: Dictionary = _state.pending_attack
		var attacker_rect := _source_highlight_rect(str(attack.get("attacker_id", "")))
		var target_rect := _pending_attack_target_rect()
		if attacker_rect.size.x > 0.0 and attacker_rect.size.y > 0.0:
			_add_highlight_rect(attacker_rect, Color(1.0, 0.66, 0.36, 0.96), Color(1.0, 0.52, 0.18, 0.12))
		if target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
			_add_highlight_rect(target_rect, Color(1.0, 0.82, 0.42, 0.98), Color(1.0, 0.74, 0.28, 0.16))
		if attacker_rect.size.x > 0.0 and target_rect.size.x > 0.0:
			var line := Line2D.new()
			line.width = 5.0
			line.default_color = Color(1.0, 0.68, 0.22, 0.84)
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.add_point(attacker_rect.get_center())
			line.add_point(target_rect.get_center())
			_selection_highlight_layer.add_child(line)
	for action in _response_highlight_actions():
		_add_response_action_relation_highlight(action)
		for source_id in _response_action_source_ids(action):
			if source_id.is_empty():
				continue
			var source_rect := _source_highlight_rect(source_id)
			if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
				var colors := _response_action_highlight_colors(action)
				_add_highlight_rect(source_rect, colors.get("border", Color(0.76, 1.0, 0.78, 0.95)), colors.get("fill", Color(0.46, 1.0, 0.48, 0.12)))


func _response_action_highlight_colors(action: Dictionary) -> Dictionary:
	var kind := str(action.get("kind", ""))
	if kind != "choose_defense":
		return {
			"border": Color(0.76, 1.0, 0.78, 0.95),
			"fill": Color(0.46, 1.0, 0.48, 0.12),
		}
	var proposal_id := str(action.get("proposal_id", ""))
	var is_selected := not proposal_id.is_empty() and proposal_id == _selected_unit_defense_proposal_id
	var defense_kind := str(action.get("source", {}).get("defense_kind", ""))
	if defense_kind == "supporter":
		return {
			"border": Color(0.62, 0.88, 1.0, 0.98) if not is_selected else Color(0.84, 0.96, 1.0, 0.99),
			"fill": Color(0.26, 0.62, 1.0, 0.14) if not is_selected else Color(0.42, 0.78, 1.0, 0.22),
		}
	if defense_kind == "blocker":
		return {
			"border": Color(1.0, 0.78, 0.48, 0.98) if not is_selected else Color(1.0, 0.90, 0.64, 0.99),
			"fill": Color(1.0, 0.56, 0.18, 0.12) if not is_selected else Color(1.0, 0.66, 0.20, 0.20),
		}
	return {
		"border": Color(0.76, 1.0, 0.78, 0.95),
		"fill": Color(0.46, 1.0, 0.48, 0.12),
	}


func _add_response_action_relation_highlight(action: Dictionary) -> void:
	if str(action.get("kind", "")) != "choose_defense" or _state == null or _state.pending_attack.is_empty():
		return
	var payload: Dictionary = action.get("payload_template", {})
	var defense_kind := str(action.get("source", {}).get("defense_kind", ""))
	var source_id := ""
	if defense_kind == "supporter":
		source_id = str(payload.get("supporter_id", ""))
	elif defense_kind == "blocker":
		source_id = str(payload.get("blocker_id", ""))
	if source_id.is_empty():
		return
	var source_rect := _source_highlight_rect(source_id)
	var target_rect := _pending_attack_target_rect()
	if source_rect.size.x <= 0.0 or target_rect.size.x <= 0.0:
		return
	var colors := _response_action_highlight_colors(action)
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = colors.get("border", Color(0.76, 1.0, 0.78, 0.88))
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(source_rect.get_center())
	line.add_point(target_rect.get_center())
	_selection_highlight_layer.add_child(line)


func _pending_attack_target_rect() -> Rect2:
	if _state == null or _state.pending_attack.is_empty():
		return Rect2()
	var attack: Dictionary = _state.pending_attack
	if str(attack.get("target_kind", "card")) == "master":
		var target_player := int(attack.get("target_player", -1))
		if target_player >= 0 and target_player < 2:
			return _map_table_rect(MASTER_RECTS[_display_target_player_from_variant(target_player)])
		return Rect2()
	return _source_highlight_rect(str(attack.get("defender_id", "")))


func _add_target_highlight(target: Dictionary, border_color: Color, fill_color: Color) -> void:
	var rect := _target_highlight_rect(target)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_add_highlight_rect(rect, border_color, fill_color)


func _add_highlight_rect(rect: Rect2, border_color: Color, fill_color: Color, layer: Control = null) -> void:
	if layer == null:
		layer = _selection_highlight_layer
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)


func _target_highlight_rect(target: Dictionary) -> Rect2:
	if target.has("row"):
		var row := str(target.get("row", ""))
		var board_player := _display_target_player_from_variant(target.get("host_player", _current_input_player()))
		if row == "artifact":
			return _map_table_rect(ARTIFACT_RECTS[board_player])
		var slot_index := _slot_index_from_row_col(row, int(target.get("col", -1)))
		if slot_index >= 0 and slot_index < BOARD_SLOT_COUNT:
			return _map_table_rect(BOARD_RECTS[board_player][slot_index])
		return Rect2()
	match str(target.get("target_kind", "")):
		"card":
			var target_id := str(target.get("defender_id", target.get("target_card_id", "")))
			var located := _find_card(target_id)
			if located.is_empty() or str(located.get("zone", "")) != "board":
				return Rect2()
			var owner := int(located.get("owner", -1))
			var index := int(located.get("index", -1))
			if owner < 0 or index < 0 or index >= BOARD_SLOT_COUNT:
				return Rect2()
			return _map_table_rect(BOARD_RECTS[owner][index])
		"master":
			var player_index := int(target.get("target_player", -1))
			if player_index < 0 or player_index >= 2:
				return Rect2()
			return _map_table_rect(MASTER_RECTS[player_index])
		"morale_area":
			var morale_player := _display_target_player_from_variant(target.get("target_player", -1))
			if morale_player < 0 or morale_player >= 2:
				return Rect2()
			return _map_table_rect(COST_AREA_RECTS[morale_player])
	return Rect2()


func _selection_mode_active() -> bool:
	return not _selected_target_action.is_empty() or not _selected_attacker_uid.is_empty()


func _card_has_response_action(card_id: String) -> bool:
	if card_id.is_empty() or not _manual_response_window_active():
		return false
	for action in _response_highlight_actions():
		var kind := str(action.get("kind", ""))
		var payload: Dictionary = action.get("payload_template", {})
		if kind == "play_card" and str(payload.get("card_id", "")) == card_id:
			return true
		if kind == "choose_defense":
			if str(payload.get("blocker_id", "")) == card_id:
				return true
			if str(payload.get("supporter_id", "")) == card_id:
				return true
			if str(action.get("source", {}).get("defense_kind", "")) == "master_guard" and _master_guard_card_is_currently_selectable(card_id) and _string_array_from_variant_array(payload.get("master_guard_card_ids", [])).has(card_id):
				return true
		if kind == "activate_effect" and str(payload.get("source_id", "")) == card_id:
			return true
	return false


func _card_is_pending_attack_participant(card_id: String) -> bool:
	if _state == null or _state.pending_attack.is_empty():
		return false
	var attack: Dictionary = _state.pending_attack
	if str(attack.get("attacker_id", "")) == card_id:
		return true
	if str(attack.get("defender_id", "")) == card_id:
		return true
	return false


func _attack_action_for_attacker(player_id: int, attacker_id: String) -> Dictionary:
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "declare_attack":
			continue
		if str(action.get("payload_template", {}).get("attacker_id", "")) != attacker_id:
			continue
		return action
	return {}


func _card_is_clickable_target(card_id: String) -> bool:
	if _selected_target_action.is_empty():
		if _selected_attacker_uid.is_empty():
			return false
		var attack_action := _attack_action_for_attacker(_current_input_player(), _selected_attacker_uid)
		for target in attack_action.get("targets", []):
			if str(target.get("target_kind", "")) != "card":
				continue
			if str(target.get("defender_id", target.get("target_card_id", ""))) == card_id:
				return true
		return false
	for target in _selected_target_action.get("targets", []):
		if str(target.get("target_kind", "")) != "card":
			continue
		if str(target.get("defender_id", target.get("target_card_id", ""))) == card_id:
			return true
	return false


func _master_is_clickable_target(player_index: int) -> bool:
	if _selected_target_action.is_empty():
		if _selected_attacker_uid.is_empty():
			return false
		var attack_action := _attack_action_for_attacker(_current_input_player(), _selected_attacker_uid)
		for target in attack_action.get("targets", []):
			if str(target.get("target_kind", "")) != "master":
				continue
			if _display_target_player_from_variant(target.get("target_player", -1)) == player_index:
				return true
		return false
	for target in _selected_target_action.get("targets", []):
		if str(target.get("target_kind", "")) != "master":
			continue
		if _display_target_player_from_variant(target.get("target_player", -1)) == player_index:
			return true
	return false


func _add_card_view(card: Dictionary, position: Vector2, card_size: Vector2, can_drag: bool, is_selected: bool, is_dimmed: bool) -> Control:
	var uid := str(card.get("uid", ""))
	if uid.is_empty():
		var fallback_view: Control = BattleCardScript.new()
		fallback_view.position = position
		fallback_view.size = card_size
		fallback_view.pivot_offset = card_size * 0.5
		fallback_view.mouse_filter = Control.MOUSE_FILTER_STOP
		fallback_view.set_use_overlay_long_press_preview(true)
		fallback_view.setup(card, can_drag, is_selected, is_dimmed)
		fallback_view.card_clicked.connect(_on_card_clicked)
		fallback_view.card_double_clicked.connect(_on_card_double_clicked)
		fallback_view.drag_started.connect(_on_card_drag_started)
		fallback_view.drag_moved.connect(_on_card_drag_moved)
		fallback_view.drag_finished.connect(_on_card_drag_finished)
		fallback_view.long_press_preview_requested.connect(_show_overlay_card_preview)
		fallback_view.long_press_preview_finished.connect(_hide_overlay_card_preview)
		_card_layer.add_child(fallback_view)
		return fallback_view
	_card_view_seen_ids[uid] = true
	var view: Control = _card_views_by_uid.get(uid, null)
	var is_new_view := view == null or not is_instance_valid(view)
	if is_new_view:
		view = BattleCardScript.new()
		view.set_use_overlay_long_press_preview(true)
		view.card_clicked.connect(_on_card_clicked)
		view.card_double_clicked.connect(_on_card_double_clicked)
		view.drag_started.connect(_on_card_drag_started)
		view.drag_moved.connect(_on_card_drag_moved)
		view.drag_finished.connect(_on_card_drag_finished)
		view.long_press_preview_requested.connect(_show_overlay_card_preview)
		view.long_press_preview_finished.connect(_hide_overlay_card_preview)
		_card_views_by_uid[uid] = view
	if view.get_parent() != _card_layer:
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		_card_layer.add_child(view)
	view.visible = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.position = position
	view.size = card_size
	view.pivot_offset = card_size * 0.5
	view.setup(card, can_drag, is_selected, is_dimmed)
	return view


func _hand_positions(player_index: int, count: int, card_size: Vector2) -> Array:
	var positions := []
	if count <= 0:
		return positions
	var area: Rect2 = _map_rect(HAND_RECTS[player_index])
	var max_step := card_size.x * 0.78
	var step := max_step
	if count > 1:
		step = min(max_step, max(18.0, (area.size.x - card_size.x) / float(count - 1)))
	var total_width := card_size.x + step * float(count - 1)
	var start_x := area.position.x + (area.size.x - total_width) * 0.5
	var y := area.position.y + (area.size.y - card_size.y) * 0.5
	for i in range(count):
		positions.append(Vector2(start_x + step * i, y))
	return positions


func _resolved_hand_click_uid(player_index: int, clicked_uid: String) -> String:
	if clicked_uid.is_empty() or player_index < 0 or player_index >= _players.size():
		return clicked_uid
	if _should_hide_hand_from_local_player(player_index):
		return clicked_uid
	var hand: Array = _players[player_index]["hand"]
	var sorted_hand := _sorted_hand_cards(hand)
	if sorted_hand.is_empty():
		return clicked_uid
	var local_position := get_local_mouse_position()
	var card_size := _card_size()
	var positions := _hand_positions(player_index, sorted_hand.size(), card_size)
	if positions.is_empty():
		return clicked_uid
	var hand_rect := _map_rect(HAND_RECTS[player_index])
	if not hand_rect.has_point(local_position):
		return clicked_uid
	for index in range(sorted_hand.size()):
		var left := float(positions[index].x)
		var right := left + card_size.x
		if index < sorted_hand.size() - 1:
			right = float(positions[index + 1].x)
		var visible_rect := Rect2(Vector2(left, float(positions[index].y)), Vector2(max(1.0, right - left), card_size.y))
		if visible_rect.has_point(local_position):
			return str(sorted_hand[index].get("uid", clicked_uid))
	return clicked_uid


func _sorted_hand_cards(hand: Array) -> Array:
	var sorted_hand: Array = hand.duplicate()
	sorted_hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var definition_a: Dictionary = a.get("definition", {})
		var definition_b: Dictionary = b.get("definition", {})
		var cost_a := int(definition_a.get("cost", 0))
		var cost_b := int(definition_b.get("cost", 0))
		if cost_a != cost_b:
			return cost_a < cost_b
		var name_a := str(definition_a.get("name", str(a.get("uid", ""))))
		var name_b := str(definition_b.get("name", str(b.get("uid", ""))))
		if name_a != name_b:
			return name_a < name_b
		return str(a.get("uid", "")) < str(b.get("uid", ""))
	)
	return sorted_hand


func _on_hud_loading_timer_timeout() -> void:
	if _hud_loading_frames.is_empty():
		return
	_hud_loading_frame = (_hud_loading_frame + 1) % _hud_loading_frames.size()
	var should_refresh_hud := false
	if _is_opening_status_active() and str(_active_opening_prompt().get("choice_type", "")) == "waiting":
		should_refresh_hud = true
	if _network_sync_overlay != null and _network_sync_overlay.visible:
		should_refresh_hud = true
	if not _current_busy_status_snapshot().is_empty():
		should_refresh_hud = true
	if should_refresh_hud:
		_refresh_hud()
	_refresh_network_sync_overlay_text()
	_refresh_opening_waiting_overlay_text()
	_refresh_busy_status_panel()


func _refresh_hud() -> void:
	if (_start_panel != null and _start_panel.visible):
		_turn_label.visible = false
		_log_label.visible = false
		_end_turn_button.visible = false
		if _return_to_main_button != null:
			_return_to_main_button.visible = false
		return
	var opening_active := _is_opening_status_active()
	if _state == null and not opening_active:
		_turn_label.visible = false
		_log_label.visible = false
		_end_turn_button.visible = false
		if _return_to_main_button != null:
			_return_to_main_button.visible = false
		return
	var active: Dictionary = _players[_active_player] if _active_player >= 0 and _active_player < _players.size() else {}
	var input_player := _current_local_input_player()
	_turn_label.visible = true
	_log_label.visible = false
	_end_turn_button.visible = not opening_active
	if _return_to_main_button != null:
		_return_to_main_button.visible = true
	var turn_status_text := ""
	if opening_active:
		var opening_prefix := ""
		if str(_active_opening_prompt().get("choice_type", "")) == "waiting" and not _hud_loading_frames.is_empty():
			opening_prefix = "[%s] " % _hud_loading_frames[_hud_loading_frame % _hud_loading_frames.size()]
		turn_status_text = "%s开局阶段 | 正式对局 | %s | %s" % [
			opening_prefix,
			_top_status_state_text(),
			_current_ai_type_badge_text()
		]
	else:
		turn_status_text = "第 %d 回合 | %s | %s | %s" % [
			_turn_number,
			str(active.get("master_name", "主宰")),
			_top_status_state_text(),
			_current_ai_type_badge_text()
		]
	var top_detail_text := str(_top_status_detail_text()).strip_edges()
	if not top_detail_text.is_empty():
		turn_status_text += "\n" + top_detail_text
	_turn_label.text = turn_status_text
	var hud_width := clampf(size.x - 32.0, 320.0, 760.0)
	var hud_height := 72.0 if not top_detail_text.is_empty() else 34.0
	if not top_detail_text.is_empty() and top_detail_text.contains("\n"):
		hud_height = 92.0
	_turn_label.offset_left = (size.x - hud_width) * 0.5
	_turn_label.offset_right = -((size.x - hud_width) * 0.5)
	_turn_label.offset_top = 2.0
	_turn_label.offset_bottom = 2.0 + hud_height
	var end_turn_size := Vector2(112.0, 40.0)
	var bottom_calamity_rect: Rect2 = _map_table_rect(CALAMITY_RECTS[PLAYER_BOTTOM])
	_end_turn_button.size = end_turn_size
	_end_turn_button.custom_minimum_size = end_turn_size
	_end_turn_button.scale = Vector2.ONE
	if _return_to_main_button != null:
		var return_button_size := Vector2(96.0, 40.0)
		_return_to_main_button.size = return_button_size
		_return_to_main_button.custom_minimum_size = return_button_size
		_return_to_main_button.scale = Vector2.ONE
		_return_to_main_button.position = Vector2(0.0, 18.0)
	_end_turn_button.position = Vector2(
		size.x - end_turn_size.x,
		bottom_calamity_rect.position.y - end_turn_size.y - 12.0
	)
	_end_turn_button.disabled = _game_over \
		or opening_active \
		or (_state != null and not _state.pending_choices.is_empty()) \
		or _find_action(_player_actions(input_player), "end_phase").is_empty()

	if _game_over:
		_end_turn_button.visible = false
		if _return_to_main_button != null:
			_return_to_main_button.visible = false
		return


func _current_ai_type_badge_text() -> String:
	if _ai_mode == 0:
		return "人机：未启用"
	var base := "人机：大模型AI" if _ai_use_llm else "人机：脚本型人机"
	if _ai_last_decision_status.is_empty():
		return base
	return "%s（%s）" % [base, _ai_last_decision_status]


func _record_ai_decision_status(decision: Dictionary, result: Dictionary = {}) -> void:
	var source := str(decision.get("source", ""))
	var fallback_reason := str(decision.get("fallback_reason", result.get("fallback_reason", "")))
	var status := ""
	if source == "llm":
		status = "最近：修复后大模型" if bool(decision.get("repair_attempted", false)) else "最近：大模型直出"
	elif source.contains("fallback"):
		status = "最近：脚本回退"
	elif not source.is_empty():
		status = "最近：脚本决策"
	if not fallback_reason.is_empty():
		_ai_last_decision_detail = "fallback=%s" % fallback_reason
	elif bool(decision.get("repair_attempted", false)):
		_ai_last_decision_detail = "repair=%s" % str(decision.get("repaired_from", ""))
	else:
		_ai_last_decision_detail = str(decision.get("candidate_id", ""))
	_ai_last_decision_status = status
	if not _ai_last_decision_detail.is_empty():
		_append_file_log("[AI STATUS] %s detail=%s" % [_ai_last_decision_status, _ai_last_decision_detail])


func _append_ai_raw_log_from_decision(display_player_id: int, decision: Dictionary, result: Dictionary = {}) -> void:
	if _ai_raw_log_path.is_empty() or decision.is_empty():
		return
	var llm_response: Dictionary = decision.get("llm_response", {})
	var response_summary := str(decision.get("llm_response_summary", ""))
	var source := str(decision.get("source", ""))
	if source != "llm" and llm_response.is_empty() and response_summary.is_empty():
		return
	var waiting: Dictionary = {}
	if _engine != null and _state != null:
		waiting = _engine.get_waiting_state(_state)
	var entry := {
		"timestamp": int(Time.get_unix_time_from_system()),
		"duel_label": _current_duel_label,
		"duel_seed": _current_duel_seed,
		"display_player_id": display_player_id,
		"logical_player_id": _logical_player_for_display(display_player_id),
		"turn_number": int(_state.turn_number) if _state != null else -1,
		"phase": str(_state.phase) if _state != null else "",
		"waiting_state": waiting.duplicate(true),
		"decision": {
			"source": source,
			"candidate_id": str(decision.get("candidate_id", "")),
			"command_type": str(decision.get("command_type", "")),
			"payload": decision.get("payload", {}).duplicate(true),
			"brief_reason": str(decision.get("brief_reason", "")),
			"repair_attempted": bool(decision.get("repair_attempted", false)),
			"repaired_from": str(decision.get("repaired_from", "")),
			"fallback_reason": str(decision.get("fallback_reason", result.get("fallback_reason", ""))),
			"llm_response_summary": response_summary,
			"timing_summary": str(decision.get("timing_summary", "")),
			"timing_trace": decision.get("timing_trace", {}).duplicate(true)
		},
		"result": {
			"ok": bool(result.get("ok", false)),
			"code": str(result.get("code", "")),
			"message": str(result.get("message", "")),
			"fallback_reason": str(result.get("fallback_reason", ""))
		},
		"llm_response": llm_response.duplicate(true)
	}
	_ai_raw_log_buffer.append("=== AI RAW BEGIN ===")
	for line in JSON.stringify(entry, "\t").split("\n"):
		_ai_raw_log_buffer.append(line)
	_ai_raw_log_buffer.append("=== AI RAW END ===")


func _snapshot_master_hp() -> Dictionary:
	var snapshot: Dictionary = {}
	for player_index in range(_players.size()):
		var player: Dictionary = _players[player_index]
		snapshot[player_index] = int(player.get("hp", 0))
	return snapshot


func _snapshot_card_orientations() -> Dictionary:
	var snapshot: Dictionary = {}
	for player in _players:
		for hand_card in player.get("hand", []):
			snapshot[str(hand_card.get("uid", ""))] = {
				"orientation": str(hand_card.get("orientation", "active")),
				"zone": str(hand_card.get("zone", "")),
				"card": hand_card.duplicate(true)
			}
		for board_card in player.get("board", []):
			if board_card == null:
				continue
			snapshot[str(board_card.get("uid", ""))] = {
				"orientation": str(board_card.get("orientation", "active")),
				"zone": str(board_card.get("zone", "")),
				"card": board_card.duplicate(true)
			}
		var artifact = player.get("artifact", null)
		if artifact != null:
			snapshot[str(artifact.get("uid", ""))] = {
				"orientation": str(artifact.get("orientation", "active")),
				"zone": str(artifact.get("zone", "")),
				"card": artifact.duplicate(true)
			}
		for morale_card in player.get("cost_area_cards", []):
			snapshot[str(morale_card.get("uid", ""))] = {
				"orientation": str(morale_card.get("orientation", "active")),
				"zone": str(morale_card.get("zone", "")),
				"card": morale_card.duplicate(true)
			}
		for morale_card in player.get("spent_cost_area_cards", []):
			snapshot[str(morale_card.get("uid", ""))] = {
				"orientation": str(morale_card.get("orientation", "active")),
				"zone": str(morale_card.get("zone", "")),
				"card": morale_card.duplicate(true)
			}
	return snapshot


func _queue_orientation_change_animations(previous_orientations: Dictionary) -> void:
	if previous_orientations.is_empty():
		return
	var current_orientations := _snapshot_card_orientations()
	for card_id in current_orientations.keys():
		if not previous_orientations.has(card_id):
			continue
		var previous_entry: Dictionary = previous_orientations[card_id]
		var current_entry: Dictionary = current_orientations[card_id]
		var previous_zone := str(previous_entry.get("zone", ""))
		var current_zone := str(current_entry.get("zone", ""))
		if previous_zone != current_zone:
			continue
		if previous_zone != "board" and previous_zone != "cost_area" and previous_zone != "spent_cost_area":
			continue
		var previous_orientation := str(previous_entry.get("orientation", "active"))
		var current_orientation := str(current_entry.get("orientation", "active"))
		if previous_orientation == current_orientation:
			continue
		_pending_animations.append({
			"kind": "orientation_change",
			"card_id": str(card_id),
			"previous_orientation": previous_orientation,
			"current_orientation": current_orientation,
			"card": current_entry.get("card", {}),
			"delay": 0.0
		})


func _queue_master_hp_change_animations(previous_master_hp: Dictionary) -> void:
	if previous_master_hp.is_empty():
		return
	for player_index in range(_players.size()):
		if not previous_master_hp.has(player_index):
			continue
		var previous_hp := int(previous_master_hp[player_index])
		var current_hp := int(_players[player_index].get("hp", previous_hp))
		if previous_hp == current_hp:
			continue
		_pending_animations.append({
			"kind": "master_hp_change",
			"player": player_index,
			"delta": current_hp - previous_hp,
			"new_hp": current_hp,
			"delay": 0.0
		})


func _run_pending_animations() -> void:
	if _pending_animations.is_empty():
		return
	var animations: Array[Dictionary] = _pending_animations.duplicate()
	_pending_animations.clear()
	var started_at_ms := Time.get_ticks_msec()
	var max_delay := 0.0
	for animation in animations:
		var kind := str(animation.get("kind", ""))
		var player_index := int(animation.get("player", PLAYER_BOTTOM))
		var delay := float(animation.get("delay", 0.0))
		if delay > max_delay:
			max_delay = delay
		match kind:
			"deck_to_hand":
				_animate_deck_to_hand(player_index, str(animation.get("card_uid", "")), delay)
			"cost_to_area":
				_animate_cost_to_area(player_index, int(animation.get("target_index", 0)), delay)
			"calamity_reveal":
				_animate_calamity_reveal(str(animation.get("calamity_id", "")), delay)
			"attack_declared":
				_animate_attack_declared(
					str(animation.get("attacker_id", "")),
					str(animation.get("target_kind", "card")),
					str(animation.get("defender_id", "")),
					int(animation.get("target_player", -1)),
					delay
				)
			"attack_exchange":
				_animate_attack_exchange(
					str(animation.get("attacker_id", "")),
					str(animation.get("defender_id", "")),
					delay
				)
			"card_focus":
				_animate_card_focus(
					str(animation.get("card_id", "")),
					str(animation.get("effect", "")),
					delay
				)
			"master_focus":
				_animate_master_focus(
					int(animation.get("player", -1)),
					str(animation.get("effect", "")),
					int(animation.get("amount", 0)),
					delay
				)
			"support_save":
				_animate_support_save(
					str(animation.get("defender_id", "")),
					str(animation.get("supporter_id", "")),
					delay
				)
			"banner":
				_animate_banner(
					str(animation.get("text", "")),
					str(animation.get("effect", "")),
					delay
				)
			"orientation_change":
				_animate_orientation_change(
					str(animation.get("card_id", "")),
					str(animation.get("previous_orientation", "active")),
					str(animation.get("current_orientation", "active")),
					animation.get("card", {}),
					delay
				)
			"master_hp_change":
				_animate_master_hp_change(
					int(animation.get("player", -1)),
					int(animation.get("delta", 0)),
					int(animation.get("new_hp", 0)),
					delay
				)
			"dice_roll":
				_animate_dice_roll(
					int(animation.get("player", -1)),
					int(animation.get("result", 0)),
					int(animation.get("sides", 6)),
					str(animation.get("card_id", "")),
					delay
				)
			"reveal_cards_popup":
				_animate_revealed_cards_popup(
					str(animation.get("title", "")),
					animation.get("card_ids", []),
					delay
				)
	_ai_blocked_until_ms = max(_ai_blocked_until_ms, started_at_ms + int(max_delay * 1000.0) + 220)


func _animate_deck_to_hand(player_index: int, card_uid: String, delay: float = 0.0) -> void:
	var hand: Array = _sorted_hand_cards(_players[player_index]["hand"])
	var target_index := -1
	var card: Dictionary = {}
	for i in range(hand.size()):
		if str(hand[i].get("uid", "")) == card_uid:
			target_index = i
			card = hand[i]
			break
	if target_index == -1:
		return

	var card_size := _card_size()
	var source_rect := _map_table_rect(DECK_RECTS[player_index])
	var start_position := source_rect.position + (source_rect.size - card_size) * 0.5
	var targets := _hand_positions(player_index, hand.size(), card_size)
	if target_index >= targets.size():
		return
	var target_position: Vector2 = targets[target_index]

	var view: Control = BattleCardScript.new()
	view.position = start_position
	view.size = card_size
	view.pivot_offset = card_size * 0.5
	view.scale = Vector2(0.7, 0.7)
	view.z_index = 600
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup(card, false, false, false)
	_preview_layer.add_child(view)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(view, "position", target_position, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(view.queue_free)


func _animate_cost_to_area(player_index: int, target_index: int, delay: float = 0.0) -> void:
	var source_rect := _map_table_rect(COST_DECK_RECTS[player_index])
	var target_rect := _map_table_rect(COST_AREA_RECTS[player_index])
	var card_size := _card_size()
	var start_position := source_rect.position + (source_rect.size - card_size) * 0.5
	var positions := _cost_card_positions(target_rect, max(target_index + 1, _players[player_index]["cost_area"].size()), card_size)
	var target_position: Vector2 = positions[min(target_index, positions.size() - 1)]

	var card_back := _make_card_back(card_size)
	card_back.position = start_position
	card_back.pivot_offset = card_size * 0.5
	card_back.z_index = 610
	_preview_layer.add_child(card_back)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(card_back, "position", target_position, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_back, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(card_back.queue_free)


func _animate_calamity_reveal(calamity_id: String, delay: float = 0.0) -> void:
	if calamity_id.is_empty():
		return
	var card_size := Vector2(min(220.0, size.x * 0.20), min(308.0, size.y * 0.24))
	var card := _make_calamity_card_view(calamity_id, card_size, true)
	card.position = Vector2((size.x - card_size.x) * 0.5, size.y * 0.12)
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card.scale = Vector2(0.84, 0.84)
	card.pivot_offset = card_size * 0.5
	card.z_index = 950
	_preview_layer.add_child(card)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(card, "modulate", Color.WHITE, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(1.15)
	tween.set_parallel(true)
	tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(card.queue_free)


func _animate_revealed_cards_popup(title: String, raw_card_ids, delay: float = 0.0) -> void:
	var card_ids: Array[String] = []
	if raw_card_ids is Array:
		for raw_card_id in raw_card_ids:
			var card_id := str(raw_card_id)
			if card_id.is_empty():
				continue
			card_ids.append(card_id)
	if card_ids.is_empty():
		return
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 970
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.04, 0.42)
	overlay.add_child(shade)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var single_card_preview := card_ids.size() == 1
	panel.size = Vector2(min(680.0, size.x * 0.7), min(520.0, size.y * 0.62))
	if single_card_preview:
		panel.size = Vector2(min(430.0, size.x * 0.5), min(640.0, size.y * 0.8))
	panel.position = Vector2((size.x - panel.size.x) * 0.5, (size.y - panel.size.y) * 0.18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.95)
	style.border_color = Color(0.98, 0.86, 0.45, 0.84)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var title_label := _make_label(16, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	title_label.text = title if not title.is_empty() else "展示给对方的卡牌"
	title_label.position = Vector2(20.0, 16.0)
	title_label.size = Vector2(panel.size.x - 40.0, 28.0)
	panel.add_child(title_label)
	var cards_grid := GridContainer.new()
	cards_grid.columns = 1 if single_card_preview else (3 if card_ids.size() > 3 else max(1, card_ids.size()))
	cards_grid.add_theme_constant_override("h_separation", 14)
	cards_grid.add_theme_constant_override("v_separation", 14)
	cards_grid.position = Vector2(20.0, 58.0)
	cards_grid.size = Vector2(panel.size.x - 40.0, panel.size.y - 78.0)
	panel.add_child(cards_grid)
	var preview_card_size: Vector2 = Vector2(112.0, 157.0 if card_ids.size() > 3 else 168.0)
	if single_card_preview:
		var preview_width: float = panel.size.x - 56.0
		preview_card_size = Vector2(preview_width, preview_width / 0.713)
		panel.size.y = min(size.y * 0.8, preview_card_size.y + 96.0)
		panel.position = Vector2((size.x - panel.size.x) * 0.5, (size.y - panel.size.y) * 0.18)
		cards_grid.size = Vector2(panel.size.x - 40.0, preview_card_size.y + 12.0)
	for card_id in card_ids.slice(0, 5):
		var preview_card: Control = BattleCardScript.new()
		preview_card.custom_minimum_size = preview_card_size
		preview_card.size = preview_card.custom_minimum_size
		preview_card.set_use_overlay_long_press_preview(true)
		preview_card.setup(_build_revealed_view_card(str(card_id)), false, false, false)
		preview_card.long_press_preview_requested.connect(_show_overlay_card_preview)
		preview_card.long_press_preview_finished.connect(_hide_overlay_card_preview)
		cards_grid.add_child(preview_card)
	_preview_layer.add_child(overlay)
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(overlay, "modulate", Color.WHITE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.4)
	tween.tween_property(overlay, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(overlay.queue_free)


func _should_show_revealed_cards_animation(event) -> bool:
	if event == null:
		return false
	if bool(event.payload.get("suppress_auto_popup", false)):
		return false
	if not _network_mode_active:
		return true
	if str(event.type) == "CardsRevealedToAll":
		return true
	if str(event.type) == "CardsViewedPrivately":
		return int(event.payload.get("viewing_player_id", -1)) == _local_player_id
	return int(event.player_id) == _local_player_id


func _animate_attack_declared(attacker_id: String, target_kind: String, defender_id: String, target_player: int, delay: float = 0.0) -> void:
	var attacker_rect := _source_highlight_rect(attacker_id)
	var target_rect := Rect2()
	if target_kind == "master":
		target_rect = _source_highlight_rect("master_%d" % target_player)
	else:
		target_rect = _source_highlight_rect(defender_id)
	if attacker_rect.size.x <= 0.0 or target_rect.size.x <= 0.0:
		return
	_flash_rect(attacker_rect, Color(1.0, 0.85, 0.36, 0.95), Color(1.0, 0.72, 0.20, 0.14), 0.40, delay)
	_flash_rect(target_rect, Color(1.0, 0.70, 0.42, 0.95), Color(1.0, 0.48, 0.24, 0.14), 0.40, delay)
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = Color(1.0, 0.82, 0.38, 0.94)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 920
	line.add_point(attacker_rect.get_center())
	line.add_point(target_rect.get_center())
	_preview_layer.add_child(line)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	line.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tween.tween_property(line, "modulate", Color.WHITE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.22)
	tween.tween_property(line, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(line.queue_free)


func _animate_attack_exchange(attacker_id: String, defender_id: String, delay: float = 0.0) -> void:
	var attacker_rect := _source_highlight_rect(attacker_id)
	var defender_rect := _source_highlight_rect(defender_id)
	if attacker_rect.size.x <= 0.0 or defender_rect.size.x <= 0.0:
		return
	_flash_rect(attacker_rect, Color(1.0, 0.74, 0.48, 0.96), Color(1.0, 0.44, 0.18, 0.14), 0.24, delay)
	_flash_rect(defender_rect, Color(1.0, 0.74, 0.48, 0.96), Color(1.0, 0.44, 0.18, 0.14), 0.24, delay + 0.04)


func _animate_card_focus(card_id: String, effect: String, delay: float = 0.0) -> void:
	if card_id.is_empty():
		return
	var rect := _source_highlight_rect(card_id)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	match effect:
		"play":
			_flash_rect(rect, Color(0.82, 0.94, 1.0, 0.95), Color(0.48, 0.74, 1.0, 0.14), 0.30, delay)
		"move":
			_flash_rect(rect, Color(0.58, 0.88, 1.0, 0.95), Color(0.36, 0.72, 1.0, 0.16), 0.32, delay)
		"damage":
			_flash_rect(rect, Color(1.0, 0.50, 0.42, 0.96), Color(1.0, 0.20, 0.12, 0.18), 0.40, delay)
		"ready":
			_flash_rect(rect, Color(0.54, 1.0, 0.66, 0.96), Color(0.22, 0.82, 0.38, 0.16), 0.34, delay)
		"morale_spent":
			_flash_rect(rect, Color(1.0, 0.82, 0.42, 0.96), Color(1.0, 0.60, 0.16, 0.16), 0.28, delay)
		"morale_ready":
			_flash_rect(rect, Color(0.80, 1.0, 0.52, 0.96), Color(0.54, 0.88, 0.12, 0.14), 0.28, delay)


func _animate_master_focus(player_index: int, effect: String, amount: int = 0, delay: float = 0.0) -> void:
	if player_index < 0 or player_index >= 2:
		return
	var rect := _source_highlight_rect(_master_source_id_for_display(player_index))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	match effect:
		"master_damage":
			_flash_rect(rect, Color(1.0, 0.42, 0.42, 0.98), Color(0.96, 0.16, 0.16, 0.18), 0.46, delay)
			_animate_banner("主宰 -%d" % max(0, amount), "master_damage", delay)
		"master_guard":
			_flash_rect(rect, Color(0.82, 0.96, 1.0, 0.98), Color(0.46, 0.76, 1.0, 0.14), 0.34, delay)
			_animate_banner("护主成功", "master_guard", delay)


func _animate_support_save(defender_id: String, supporter_id: String, delay: float = 0.0) -> void:
	if not supporter_id.is_empty():
		_animate_card_focus(supporter_id, "ready", delay)
	if not defender_id.is_empty():
		_flash_rect(
			_source_highlight_rect(defender_id),
			Color(0.88, 1.0, 0.62, 0.96),
			Color(0.60, 0.94, 0.22, 0.16),
			0.34,
			delay
		)
	_animate_banner("支援保命", "support_save", delay)


func _animate_banner(text: String, effect: String, delay: float = 0.0) -> void:
	if text.is_empty():
		return
	if not _should_show_center_banner(effect):
		return
	var banner_width := clampf(size.x - 96.0, 300.0, 540.0)
	var banner_height := 68.0
	var banner_y := 8.0
	var label := _make_label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2((size.x - banner_width) * 0.5, banner_y)
	label.size = Vector2(banner_width, banner_height)
	label.z_index = 930
	match effect:
		"game_start":
			label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
		"phase_change":
			label.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0, 1.0))
		"turn_end":
			label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68, 1.0))
		"attack_finish":
			label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50, 1.0))
		"attack_countered":
			label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 1.0))
		"master_damage":
			label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.72, 1.0))
		"master_guard":
			label.add_theme_color_override("font_color", Color(0.84, 0.96, 1.0, 1.0))
		"support_save":
			label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.72, 1.0))
		"card_play_notice":
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68, 1.0))
		"effect_notice":
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(0.86, 0.97, 1.0, 1.0))
		"attack_notice":
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
		"game_end":
			label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	_preview_layer.add_child(label)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.scale = Vector2(0.92, 0.92)
	label.pivot_offset = label.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", Color.WHITE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.28)
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "position:y", label.position.y - 12.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


func _should_show_center_banner(effect: String) -> bool:
	return effect == "game_end" \
		or effect == "card_play_notice" \
		or effect == "effect_notice" \
		or effect == "attack_notice"


func _flash_rect(rect: Rect2, border_color: Color, fill_color: Color, duration: float, delay: float = 0.0) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 915
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_preview_layer.add_child(panel)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(panel, "modulate", Color.WHITE, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 0.0), duration * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(panel.queue_free)


func _animate_orientation_change(card_id: String, previous_orientation: String, current_orientation: String, card: Dictionary, delay: float = 0.0) -> void:
	if card_id.is_empty() or not (card is Dictionary):
		return
	var rect := _source_highlight_rect(card_id)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var overlay: Control = BattleCardScript.new()
	overlay.position = rect.position
	overlay.size = rect.size
	overlay.pivot_offset = rect.size * 0.5
	overlay.z_index = 918
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_card: Dictionary = card.duplicate(true)
	overlay_card["orientation"] = previous_orientation
	overlay.setup(overlay_card, false, false, false)
	overlay.rotation_degrees = _rotation_for_orientation(previous_orientation)
	_preview_layer.add_child(overlay)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate", Color(1.0, 1.0, 1.0, 0.88), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "rotation_degrees", _rotation_for_orientation(current_orientation), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "scale", Vector2(1.03, 1.03), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(overlay, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(overlay, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(overlay.queue_free)


func _rotation_for_orientation(orientation: String) -> float:
	return 90.0 if orientation == "rested" else 0.0


func _animate_master_hp_change(player_index: int, delta: int, new_hp: int, delay: float = 0.0) -> void:
	if player_index < 0 or player_index >= _players.size() or delta == 0:
		return
	var master_rect := _map_table_rect(MASTER_RECTS[player_index])
	var badge_rect := _master_hp_badge_rect(master_rect)
	var border_color := Color(0.82, 0.96, 0.72, 0.98) if delta > 0 else Color(1.0, 0.48, 0.48, 0.98)
	var fill_color := Color(0.34, 0.82, 0.22, 0.16) if delta > 0 else Color(0.92, 0.18, 0.18, 0.18)
	_flash_rect(badge_rect, border_color, fill_color, 0.44, delay)
	var label := _make_label(18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	label.text = "%s%d" % ["+" if delta > 0 else "", delta]
	label.position = Vector2(badge_rect.position.x, badge_rect.position.y - 18.0)
	label.size = Vector2(badge_rect.size.x, 28)
	label.z_index = 932
	label.add_theme_color_override("font_color", border_color)
	_preview_layer.add_child(label)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", Color.WHITE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 12.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.10)
	tween.tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)
	_animate_banner("%s %d/%d" % [str(_players[player_index].get("master_name", "主宰")), new_hp, int(_players[player_index].get("max_hp", new_hp))], "master_damage" if delta < 0 else "master_guard", delay)

func _animate_dice_roll(player_index: int, result: int, sides: int, card_id: String, delay: float = 0.0) -> void:
	var normalized_sides: int = max(2, sides)
	var final_result := clampi(result, 1, normalized_sides)
	var panel := Panel.new()
	panel.size = Vector2(142.0, 168.0)
	panel.pivot_offset = panel.size * 0.5
	panel.z_index = 935
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.94)
	style.border_color = Color(0.88, 0.92, 1.0, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	var anchor_rect := Rect2(Vector2((size.x - panel.size.x) * 0.5, size.y * 0.24), panel.size)
	if not card_id.is_empty():
		var card_rect := _source_highlight_rect(card_id)
		if card_rect.size.x > 0.0 and card_rect.size.y > 0.0:
			anchor_rect = Rect2(card_rect.get_center() - panel.size * 0.5 + Vector2(0.0, -76.0), panel.size)
	elif player_index >= 0 and player_index < _players.size():
		var master_rect := _source_highlight_rect(_master_source_id_for_display(player_index))
		if master_rect.size.x > 0.0 and master_rect.size.y > 0.0:
			anchor_rect = Rect2(master_rect.get_center() - panel.size * 0.5 + Vector2(0.0, -86.0), panel.size)
	panel.position = Vector2(
		clampf(anchor_rect.position.x, 10.0, max(10.0, size.x - panel.size.x - 10.0)),
		clampf(anchor_rect.position.y, 10.0, max(10.0, size.y - panel.size.y - 10.0))
	)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(0.72, 0.72)
	_preview_layer.add_child(panel)
	var title := _make_label(13, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	title.text = "掷骰"
	title.position = Vector2(0.0, 10.0)
	title.size = Vector2(panel.size.x, 20.0)
	title.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.92))
	panel.add_child(title)
	var dice_face := Panel.new()
	dice_face.position = Vector2(26.0, 34.0)
	dice_face.size = Vector2(90.0, 90.0)
	dice_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face_style := StyleBoxFlat.new()
	face_style.bg_color = Color(0.96, 0.97, 1.0, 0.98)
	face_style.border_color = Color(0.78, 0.84, 0.96, 0.98)
	face_style.border_width_left = 2
	face_style.border_width_top = 2
	face_style.border_width_right = 2
	face_style.border_width_bottom = 2
	face_style.corner_radius_top_left = 14
	face_style.corner_radius_top_right = 14
	face_style.corner_radius_bottom_left = 14
	face_style.corner_radius_bottom_right = 14
	dice_face.add_theme_stylebox_override("panel", face_style)
	panel.add_child(dice_face)
	var pip_nodes := _create_dice_pip_nodes(dice_face)
	_set_dice_face_value(pip_nodes, final_result)
	var caption := _make_label(11, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	caption.text = _card_name(card_id) if not card_id.is_empty() else (_players[player_index].get("name", "玩家") if player_index >= 0 and player_index < _players.size() else "玩家")
	caption.position = Vector2(10.0, 130.0)
	caption.size = Vector2(panel.size.x - 20.0, 28.0)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.84))
	panel.add_child(caption)
	var sequence := _dice_roll_preview_sequence(final_result, normalized_sides)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_method(Callable(self, "_update_dice_roll_preview").bind(pip_nodes, sequence), 0.0, 1.0, 0.90)
	tween.tween_interval(0.55)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position:y", panel.position.y - 18.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(panel.queue_free)

func _update_dice_roll_preview(progress: float, pip_nodes: Array, sequence: Array) -> void:
	if pip_nodes.is_empty() or sequence.is_empty():
		return
	var index := mini(sequence.size() - 1, int(floor(progress * float(sequence.size()))))
	_set_dice_face_value(pip_nodes, int(sequence[index]))

func _dice_roll_preview_sequence(result: int, sides: int) -> Array:
	var sequence: Array = []
	var normalized_sides: int = max(2, sides)
	var seed := posmod(result + 1, normalized_sides)
	for offset in range(12):
		sequence.append(posmod(seed + offset, normalized_sides) + 1)
	sequence.append(result)
	return sequence

func _create_dice_pip_nodes(dice_face: Panel) -> Array:
	var pip_nodes: Array = []
	var pip_positions := [
		Vector2(20.0, 20.0),
		Vector2(45.0, 20.0),
		Vector2(70.0, 20.0),
		Vector2(20.0, 45.0),
		Vector2(45.0, 45.0),
		Vector2(70.0, 45.0),
		Vector2(20.0, 70.0),
		Vector2(45.0, 70.0),
		Vector2(70.0, 70.0)
	]
	for pip_position in pip_positions:
		var pip := Panel.new()
		pip.size = Vector2(12.0, 12.0)
		pip.position = pip_position - pip.size * 0.5
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.visible = false
		var pip_style := StyleBoxFlat.new()
		pip_style.bg_color = Color(0.12, 0.16, 0.24, 0.98)
		pip_style.corner_radius_top_left = 6
		pip_style.corner_radius_top_right = 6
		pip_style.corner_radius_bottom_left = 6
		pip_style.corner_radius_bottom_right = 6
		pip.add_theme_stylebox_override("panel", pip_style)
		dice_face.add_child(pip)
		pip_nodes.append(pip)
	return pip_nodes

func _set_dice_face_value(pip_nodes: Array, value: int) -> void:
	var visible_indices: Array[int] = []
	match clampi(value, 1, 6):
		1:
			visible_indices = [4]
		2:
			visible_indices = [0, 8]
		3:
			visible_indices = [0, 4, 8]
		4:
			visible_indices = [0, 2, 6, 8]
		5:
			visible_indices = [0, 2, 4, 6, 8]
		6:
			visible_indices = [0, 2, 3, 5, 6, 8]
	for index in range(pip_nodes.size()):
		var pip = pip_nodes[index]
		if pip == null:
			continue
		pip.visible = visible_indices.has(index)


func _make_card_back(card_size: Vector2) -> Panel:
	var card_back := Panel.new()
	card_back.size = card_size
	card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.92)
	style.border_color = Color(0.75, 0.79, 0.92, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card_back.add_theme_stylebox_override("panel", style)
	return card_back


func _cost_card_positions(rect: Rect2, count: int, card_size: Vector2) -> Array:
	var positions := []
	if count <= 0:
		return positions
	var visible_count: int = count
	var step := card_size.x * 0.30
	if visible_count > 1:
		step = min(step, max(1.0, (rect.size.x - card_size.x) / float(visible_count - 1)))
	var total_width := card_size.x + step * float(visible_count - 1)
	var start_x := rect.position.x + (rect.size.x - total_width) * 0.5
	var y := rect.position.y + (rect.size.y - card_size.y) * 0.5
	for i in range(visible_count):
		positions.append(Vector2(start_x + step * i, y))
	return positions


func _on_card_drag_started(card: Control) -> void:
	if _network_input_locked():
		_hide_drag_line()
		return
	card.z_index = 200
	_dragging_card_uid = str(card.card_data.get("uid", ""))
	_drag_origin_global = card.get_last_pointer_global_position() if card.has_method("get_last_pointer_global_position") else card.get_global_rect().get_center()
	if _dragged_card_shows_drag_line():
		_update_drag_line(_drag_origin_global, _drag_origin_global)
	else:
		_hide_drag_line()
	_update_drop_highlight(_drag_origin_global)


func _on_card_drag_moved(_card: Control, global_drag_position: Vector2) -> void:
	if _network_input_locked():
		_hide_drag_line()
		return
	if _dragged_card_shows_drag_line():
		_update_drag_line(_drag_origin_global, global_drag_position)
	else:
		_hide_drag_line()
	_update_drop_highlight(global_drag_position)


func _on_card_drag_finished(card: Control, global_drop_position: Vector2) -> void:
	_clear_drag_highlights()
	_hide_drag_line()
	_dragging_card_uid = ""
	_drag_origin_global = Vector2.ZERO
	_hover_slot_index = -1
	_hover_zone_kind = ""
	if _game_over:
		_refresh()
		return
	if _network_input_locked():
		_refresh()
		return
	var uid := str(card.card_data.get("uid", ""))
	var located := _find_card(uid)
	var handled := false
	if not located.is_empty() and str(located.get("zone", "")) == "board":
		handled = _try_board_drag_action(uid, global_drop_position)
	elif not located.is_empty() and (str(located.get("zone", "")) == "master" or str(located.get("zone", "")) == "artifact"):
		handled = _try_source_drag_action(uid, global_drop_position)
	else:
		handled = _try_play_card(uid, global_drop_position)
	if not handled:
		_refresh()


func _update_drop_highlight(global_drag_position: Vector2) -> void:
	if _dragging_card_uid == "" or _game_over:
		_clear_drag_highlights()
		_hide_drag_line()
		return

	var target_match := {}
	var located := _find_card(_dragging_card_uid)
	if not located.is_empty() and str(located.get("zone", "")) == "board":
		target_match = _find_matching_board_drag_target(_current_input_player(), _dragging_card_uid, global_drag_position)
	elif not located.is_empty() and (str(located.get("zone", "")) == "master" or str(located.get("zone", "")) == "artifact"):
		target_match = _find_matching_activation_target(_current_input_player(), _dragging_card_uid, global_drag_position)
	else:
		target_match = _find_matching_choice_deploy_target(_current_input_player(), _dragging_card_uid, global_drag_position)
		if target_match.is_empty():
			target_match = _find_matching_play_target(_current_input_player(), _dragging_card_uid, global_drag_position)
		if target_match.is_empty():
			target_match = _find_matching_relaxed_rollo_play_target(_current_input_player(), _dragging_card_uid, global_drag_position)
		if target_match.is_empty():
			var drag_cast_action := _find_drag_cast_tactic_action(_current_input_player(), _dragging_card_uid, global_drag_position)
			if not drag_cast_action.is_empty():
				var rect := _battlefield_hover_rect_at_global_position(global_drag_position)
				if rect.size.x > 0.0 and rect.size.y > 0.0:
					target_match = {"zone_kind": "battlefield_cast", "slot_index": -1, "rect": rect}
	var next_zone_kind := str(target_match.get("zone_kind", ""))
	var next_hover_slot := int(target_match.get("slot_index", -1))
	var highlight_rect: Rect2 = target_match.get("rect", Rect2())
	if next_hover_slot == _hover_slot_index and next_zone_kind == _hover_zone_kind:
		return
	_hover_slot_index = next_hover_slot
	_hover_zone_kind = next_zone_kind
	_clear_drag_highlights()
	if not located.is_empty() and (str(located.get("zone", "")) == "master" or str(located.get("zone", "")) == "artifact"):
		_add_drag_source_target_highlights(_current_input_player(), _dragging_card_uid)
	if _hover_zone_kind == "":
		return

	var panel := Panel.new()
	panel.position = highlight_rect.position
	panel.size = highlight_rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	var is_target_object := _hover_zone_kind == "target_card" or _hover_zone_kind == "master"
	if is_target_object:
		style.bg_color = Color(1.0, 0.92, 0.42, 0.24)
		style.border_color = Color(1.0, 0.97, 0.72, 1.0)
	else:
		style.bg_color = Color(0.52, 0.82, 1.0, 0.12)
		style.border_color = Color(0.66, 0.92, 1.0, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	if is_target_object:
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_drag_highlight_layer.add_child(panel)
	if is_target_object:
		_add_drag_target_bright_overlay(highlight_rect)
	if is_target_object:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(panel, "modulate", Color.WHITE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _add_drag_source_target_highlights(player_id: int, source_id: String) -> void:
	for action in _activation_actions_for_source(player_id, source_id):
		for target in action.get("targets", []):
			var rect := _target_highlight_rect(target)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			var colors := _drag_source_target_colors(player_id, target)
			_add_highlight_rect(rect, colors.get("border", Color(0.90, 1.0, 0.76, 0.86)), colors.get("fill", Color(0.42, 0.88, 0.34, 0.10)), _drag_highlight_layer)


func _drag_source_target_colors(player_id: int, target: Dictionary) -> Dictionary:
	var is_enemy_target := false
	if target.has("target_player"):
		is_enemy_target = _display_target_player_from_variant(target.get("target_player", player_id)) != player_id
	elif target.has("host_player"):
		is_enemy_target = _display_target_player_from_variant(target.get("host_player", player_id)) != player_id
	elif str(target.get("target_kind", "")) == "card":
		var target_id := str(target.get("defender_id", target.get("target_card_id", "")))
		var located := _find_card(target_id)
		if not located.is_empty():
			is_enemy_target = int(located.get("owner", player_id)) != player_id
	if is_enemy_target:
		return {
			"border": Color(1.0, 0.86, 0.58, 0.88),
			"fill": Color(1.0, 0.64, 0.18, 0.12)
		}
	return {
		"border": Color(0.90, 1.0, 0.76, 0.86),
		"fill": Color(0.42, 0.88, 0.34, 0.10)
	}


func _add_drag_target_bright_overlay(rect: Rect2) -> void:
	if _drag_target_layer == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 950
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.72, 0.24)
	style.border_color = Color(1.0, 0.86, 0.34, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	_drag_target_layer.add_child(panel)


func _update_drag_line(global_start: Vector2, global_end: Vector2) -> void:
	if _drag_line == null:
		return
	var local_start := get_global_transform_with_canvas().affine_inverse() * global_start
	var local_end := get_global_transform_with_canvas().affine_inverse() * global_end
	_drag_origin_local = local_start
	_drag_line.clear_points()
	_drag_line.add_point(local_start)
	_drag_line.add_point(local_end)
	_drag_line.visible = true


func _hide_drag_line() -> void:
	if _drag_line == null:
		return
	_drag_line.visible = false
	_drag_line.clear_points()


func _dragging_card_origin_global() -> Vector2:
	if _dragging_card_uid == "":
		return Vector2.ZERO
	var located := _find_card(_dragging_card_uid)
	if located.is_empty():
		return Vector2.ZERO
	if str(located.get("zone", "")) == "board":
		var owner := int(located.get("owner", -1))
		var index := int(located.get("index", -1))
		if owner >= 0 and owner < 2 and index >= 0 and index < BOARD_SLOT_COUNT:
			return _map_table_rect(BOARD_RECTS[owner][index]).get_center()
	if str(located.get("zone", "")) == "hand":
		return Vector2.ZERO
	return Vector2.ZERO


func _on_card_clicked(card: Control) -> void:
	if _game_over:
		return
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	var uid := str(card.card_data.get("uid", ""))
	var located := _find_card(uid)
	if located.is_empty():
		return
	var owner := int(located["owner"])
	var zone := str(located["zone"])
	var input_player := _current_input_player()
	if _try_click_choice_candidate(uid):
		return
	if not _selected_target_action.is_empty() and _try_selected_target_action_on_card(uid):
		return
	if not _local_play_option_choice.is_empty():
		return
	if zone == "hand":
		if owner == input_player:
			uid = _resolved_hand_click_uid(owner, uid)
			if _try_quick_play_card(uid):
				return
			if _try_quick_choose_defense(uid):
				return
			_try_quick_response_play(uid)
		return
	if zone == "artifact":
		if owner == input_player:
			if _source_requires_double_click_to_open_panel(uid):
				return
			_try_activate_source(uid)
		return
	if zone == "master":
		_on_master_clicked(owner)
		return
	if zone == "cost_area":
		if not _selected_target_action.is_empty() and _try_selected_target_action_on_morale_area(owner):
			return
		return
	if zone != "board":
		return
	if owner == input_player:
		var board_card: Dictionary = located["card"]
		if _try_quick_choose_defense(uid):
			return
		if (str(board_card.get("face", "face_up")) == "face_down" or _card_has_response_action(uid)) and _try_activate_source(uid):
			return
		if bool(board_card.get("can_attack", false)):
			if _selected_attacker_uid == uid:
				_selected_attacker_uid = ""
			else:
				_selected_attacker_uid = uid
			_refresh()
	else:
		_attack_card(uid)


func _on_card_double_clicked(card: Control) -> void:
	if _game_over:
		return
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	var uid := str(card.card_data.get("uid", ""))
	var located := _find_card(uid)
	if located.is_empty():
		return
	var input_player := _current_input_player()
	if int(located.get("owner", -1)) != input_player and not _source_has_click_activation_panel(input_player, uid):
		return
	var zone := str(located.get("zone", ""))
	if zone == "cost_area":
		_on_morale_card_clicked(int(located.get("owner", -1)), true)
		return
	if zone != "board" and zone != "master" and zone != "artifact":
		return
	_try_activate_source(uid, true)


func _source_requires_double_click_to_open_panel(source_id: String) -> bool:
	if _state == null or source_id.is_empty():
		return false
	var instance = _state.card_instances.get(source_id, null)
	if instance == null:
		return false
	var definition_id := str(instance.definition_id)
	return definition_id == "takamagahara_s02_0404" or definition_id == "asgard_s01_0317" or definition_id == "neutral_s02_0013"


func _activation_unavailable_hint(source_id: String) -> String:
	if _state == null or source_id.is_empty():
		return ""
	var instance = _state.card_instances.get(source_id, null)
	if instance == null:
		return "当前没有可发动的效果。"
	var definition_id := str(instance.definition_id)
	if definition_id == "asgard_s01_0317":
		return _gram_activation_unavailable_hint(instance)
	if not _state.pending_choices.is_empty():
		return "请先完成当前选择。"
	if not _state.stack.is_empty() or not _state.pending_attack.is_empty():
		return "请先处理当前堆叠或攻击响应。"
	return "当前没有可发动的效果。"


func _gram_activation_unavailable_hint(instance) -> String:
	if not _state.pending_choices.is_empty():
		return "神剑格拉墨：请先完成当前选择。"
	if not _state.stack.is_empty() or not _state.pending_attack.is_empty():
		return "神剑格拉墨：请先处理当前堆叠或攻击响应。"
	var controller := int(instance.controller)
	if _state.active_player != controller or _state.priority_player != controller:
		return "神剑格拉墨：只能在我方主阶段并拥有优先权时发动。"
	var orientation := str(instance.orientation)
	if orientation == "active":
		var asgard_legion_count := _grave_card_count_matching(controller, "asgard", "legion")
		if asgard_legion_count < 4:
			return "神剑格拉墨：墓地需要至少4张【阿斯加德】军团，目前%d张。" % asgard_legion_count
		return "神剑格拉墨：当前没有可发动的主动效果。"
	if orientation == "rested":
		var active_morale := _active_morale_count_for_player(controller)
		if active_morale < 2:
			return "神剑格拉墨：转为活跃需要2点可用士气，目前%d点。" % active_morale
		return "神剑格拉墨：当前不能转为活跃。"
	return "神剑格拉墨：当前状态不能发动。"


func _grave_card_count_matching(logical_player_id: int, faction: String, card_type: String) -> int:
	if _state == null or logical_player_id < 0 or logical_player_id >= _state.players.size():
		return 0
	var count := 0
	for card_id in _state.get_player(logical_player_id).grave.cards:
		var grave_instance = _state.card_instances.get(str(card_id), null)
		if grave_instance == null:
			continue
		var definition = _state.get_definition(str(grave_instance.definition_id))
		if definition == null:
			continue
		if not faction.is_empty() and str(definition.faction) != faction:
			continue
		if not card_type.is_empty() and str(definition.type) != card_type:
			continue
		count += 1
	return count


func _active_morale_count_for_player(logical_player_id: int) -> int:
	if _state == null or logical_player_id < 0 or logical_player_id >= _state.players.size():
		return 0
	var count := 0
	var player = _state.get_player(logical_player_id)
	for card_id in player.cost_area.cards:
		var morale_instance = _state.card_instances.get(str(card_id), null)
		if morale_instance != null and str(morale_instance.orientation) == "active":
			count += 1
	if int(player.flags.get("temporary_morale_turn", -1)) == int(_state.turn_number):
		count += int(player.flags.get("temporary_morale_count", 0))
	return count


func _try_click_choice_candidate(card_id: String) -> bool:
	if _network_input_locked():
		return true
	var choice_action := _current_choice_action()
	if choice_action.is_empty() or str(choice_action.get("choice_type", "")) != "candidate_cards_pick":
		return false
	if _is_hand_deploy_choice_action(choice_action):
		return false
	var candidates: Array = choice_action.get("candidate_card_ids", [])
	if not candidates.has(card_id):
		return false
	if max(1, int(choice_action.get("count", 1))) <= 1 and not _choice_requires_confirm(choice_action):
		var payload = choice_action.get("payload_template", {}).duplicate(true)
		payload["selected_card_ids"] = [card_id]
		return _execute_command(_current_input_player(), str(choice_action.get("command_type", "")), payload)
	_toggle_choice_card(card_id, max(1, int(choice_action.get("count", 1))))
	return true

func _is_board_slot_choice_action(choice_action: Dictionary) -> bool:
	var choice_type := str(choice_action.get("choice_type", choice_action.get("type", "")))
	var operation := str(choice_action.get("operation", ""))
	return not choice_action.is_empty() \
		and choice_type == "option_pick" \
		and (operation == "revive_selected_grave_to_slot" or operation == "manifest_kusanagi_to_slot" or operation == "deploy_selected_hand_to_slot" or operation == "set_counter_tactic_from_hand_to_slot" or operation == "play_revealed_deck_card_to_slot" or operation == "set_revealed_deck_counter_to_slot" or operation == "move_selected_battlefield_card_to_slot" or operation == "tsukuyomi_choose_move_slot" or operation == "takamagahara_morale_choose_move_slot" or operation == "hand_response_deploy_to_front_and_redirect_pending_attack")


func _is_board_card_choice_action(choice_action: Dictionary) -> bool:
	if choice_action.is_empty() or str(choice_action.get("choice_type", "")) != "candidate_cards_pick":
		return false
	var operation := str(choice_action.get("operation", ""))
	if operation == "choose_battlefield_cards_to_move":
		return max(1, int(choice_action.get("count", 1))) == 1
	if operation == "destroy_battlefield_cards":
		return max(1, int(choice_action.get("count", 1))) == 1
	return not choice_action.is_empty() \
		and str(choice_action.get("choice_type", "")) == "candidate_cards_pick" \
		and (operation == "target_set_counter_tactic_then_stack_effect" \
			or operation == "hijikata_entry_destroy_combo" \
			or operation == "destroy_battlefield_card" \
			or operation == "modify_cost_until_next_own_turn_end" \
			or operation == "modify_power_until_next_own_turn_end" \
			or operation == "tsukuyomi_choose_move_card" \
			or operation == "forged_order_choose_enemy_move_card" \
			or operation == "takamagahara_morale_choose_move_card")


func _should_use_board_card_choice_confirm_panel(choice_action: Dictionary) -> bool:
	return _is_board_card_choice_action(choice_action) and _choice_requires_confirm(choice_action)


func _refresh_board_card_choice_confirm_panel(player_id: int, choice_action: Dictionary) -> void:
	var panel_size := Vector2(340, 118)
	var panel_position := _popup_opponent_morale_position(panel_size)
	var panel_title := _choice_operation_status_label(str(choice_action.get("operation", "")), str(choice_action.get("choice_type", "")))
	_action_panel.visible = true
	_action_panel.size = panel_size
	_action_panel.position = panel_position
	_action_panel_title.text = panel_title
	var required_count: int = max(1, int(choice_action.get("count", 1)))
	var min_selected_count := _choice_min_selected_count_for_confirm(choice_action)
	var panel_signature := JSON.stringify({
		"visible": true,
		"mode": "board_card_choice_confirm",
		"title": panel_title,
		"size": [panel_size.x, panel_size.y],
		"position": [panel_position.x, panel_position.y],
		"choice_action": choice_action,
		"selected_card_ids": _choice_selected_card_ids,
		"network_locked": _network_input_locked(),
	})
	if not _panel_signature_changed("action", panel_signature):
		return
	_clear_children(_action_panel_body)
	var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = _choice_panel_hint_text(choice_action)
	_action_panel_body.add_child(hint)
	var confirm_button := _make_button("确认选择")
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.disabled = _network_input_locked() or _choice_selected_card_ids.size() < min_selected_count or _choice_selected_card_ids.size() > required_count
	confirm_button.pressed.connect(func() -> void:
		var payload = choice_action.get("payload_template", {}).duplicate(true)
		payload["selected_card_ids"] = _choice_selected_card_ids.duplicate()
		_execute_command(player_id, str(choice_action.get("command_type", "")), payload)
	)
	_action_panel_body.add_child(confirm_button)


func _is_inline_move_choice_instruction_panel_operation(operation: String) -> bool:
	return operation == "choose_battlefield_cards_to_move" \
		or operation == "forged_order_choose_enemy_move_card" \
		or operation == "move_selected_battlefield_card_to_slot" \
		or operation == "tsukuyomi_choose_move_card" \
		or operation == "tsukuyomi_choose_move_slot" \
		or operation == "takamagahara_morale_choose_move_card" \
		or operation == "takamagahara_morale_choose_move_slot"


func _choice_allows_drag_board_card(choice_action: Dictionary, card_id: String) -> bool:
	if choice_action.is_empty() or card_id.is_empty():
		return false
	var operation := str(choice_action.get("operation", ""))
	if operation == "choose_battlefield_cards_to_move" and max(1, int(choice_action.get("count", 1))) != 1:
		return false
	if operation == "choose_battlefield_cards_to_move" or operation == "forged_order_choose_enemy_move_card" or operation == "tsukuyomi_choose_move_card" or operation == "takamagahara_morale_choose_move_card":
		return _string_array_from_variant_array(choice_action.get("candidate_card_ids", [])).has(card_id)
	if operation == "move_selected_battlefield_card_to_slot" or operation == "tsukuyomi_choose_move_slot" or operation == "takamagahara_morale_choose_move_slot":
		return str(choice_action.get("context", {}).get("card_id", "")) == card_id
	return false


func _should_use_inline_move_choice_instruction_panel(choice_action: Dictionary) -> bool:
	if choice_action.is_empty():
		return false
	if _should_use_board_card_choice_confirm_panel(choice_action):
		return false
	if str(choice_action.get("operation", "")) == "choose_battlefield_cards_to_move" and max(1, int(choice_action.get("count", 1))) != 1:
		return false
	return _is_inline_move_choice_instruction_panel_operation(str(choice_action.get("operation", "")))


func _refresh_inline_move_choice_instruction_panel(choice_action: Dictionary) -> void:
	var panel_size := Vector2(340, 120)
	var panel_position := _popup_opponent_morale_position(panel_size)
	var panel_title := _choice_operation_status_label(str(choice_action.get("operation", "")), str(choice_action.get("choice_type", "")))
	_action_panel.visible = true
	_action_panel.size = panel_size
	_action_panel.position = panel_position
	_action_panel_title.text = panel_title
	var panel_signature := JSON.stringify({
		"visible": true,
		"mode": "inline_move_choice_instruction",
		"title": panel_title,
		"size": [panel_size.x, panel_size.y],
		"position": [panel_position.x, panel_position.y],
		"choice_action": choice_action,
		"selected_card_ids": _choice_selected_card_ids,
		"network_locked": _network_input_locked(),
	})
	if not _panel_signature_changed("action", panel_signature):
		return
	_clear_children(_action_panel_body)
	var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = _choice_panel_hint_text(choice_action)
	_action_panel_body.add_child(hint)
	var card_id := str(choice_action.get("context", {}).get("card_id", ""))
	if not card_id.is_empty():
		var current := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		current.text = "当前军团：%s" % _card_name(card_id)
		_action_panel_body.add_child(current)


func _popup_opponent_morale_position(panel_size: Vector2) -> Vector2:
	var x := (size.x - panel_size.x) * 0.5
	var y := size.y * 0.10
	var max_x: float = max(12.0, size.x - panel_size.x - 12.0)
	var max_y: float = max(12.0, size.y - panel_size.y - 12.0)
	return Vector2(clampf(x, 12.0, max_x), clampf(y, 12.0, max_y))

func _choice_requires_confirm(choice_action: Dictionary) -> bool:
	if choice_action.is_empty():
		return false
	return bool(choice_action.get("requires_confirm", false)) or str(choice_action.get("operation", "")) == "search_deck"

func _choice_min_selected_count_for_confirm(choice_action: Dictionary) -> int:
	if choice_action.is_empty():
		return 0
	if choice_action.has("min_select_count"):
		return max(0, int(choice_action.get("min_select_count", 0)))
	return max(1, int(choice_action.get("count", 1)))


func _choice_supports_cancel(choice_action: Dictionary) -> bool:
	if choice_action.is_empty():
		return false
	var operation := str(choice_action.get("operation", ""))
	return operation == "search_deck" or operation == "search_deck_reorder_bottom" or operation == "local_play_option_grave_pick" or operation == "forged_order_choose_enemy_move_card" or operation == "landlord_coercion_extra_discard"

func _is_hand_deploy_choice_action(choice_action: Dictionary) -> bool:
	return not choice_action.is_empty() \
		and str(choice_action.get("choice_type", "")) == "candidate_cards_pick" \
		and str(choice_action.get("operation", "")) == "deploy_from_hand_to_battlefield"

func _is_direct_hand_choice_action(choice_action: Dictionary) -> bool:
	return not choice_action.is_empty() \
		and str(choice_action.get("choice_type", "")) == "candidate_cards_pick" \
		and str(choice_action.get("operation", "")) == "discard_from_hand"

func _choice_allows_drag_hand_card(player_index: int, card_id: String) -> bool:
	if player_index != _current_input_player():
		return false
	var choice_action := _find_action(_player_actions(player_index), "resolve_choice")
	if not _is_hand_deploy_choice_action(choice_action):
		return false
	return _string_array_from_variant_array(choice_action.get("candidate_card_ids", [])).has(card_id)

func _current_deploy_choice_slot_options() -> Array:
	var result: Array = []
	var choice_action := _find_action(_player_actions(_current_input_player()), "resolve_choice")
	if choice_action.has("slot_options"):
		return choice_action.get("slot_options", []).duplicate(true)
	return result

func _find_matching_choice_deploy_target(player_id: int, card_id: String, global_position: Vector2) -> Dictionary:
	if not _choice_allows_drag_hand_card(player_id, card_id):
		return {}
	for slot in _current_deploy_choice_slot_options():
		var row := str(slot.get("row", ""))
		var col := int(slot.get("col", -1))
		var slot_index := _slot_index_from_row_col(row, col)
		if slot_index < 0 or slot_index >= BOARD_SLOT_COUNT:
			continue
		var rect := _map_table_rect(BOARD_RECTS[player_id][slot_index])
		if rect.has_point(global_position):
			return {
				"row": row,
				"col": col,
				"slot_index": slot_index,
				"zone_kind": "choice_deploy_slot",
				"rect": rect
			}
	return {}

func _execute_choice_deploy_drag(player_id: int, card_id: String, target: Dictionary) -> bool:
	var choice_action := _find_action(_player_actions(player_id), "resolve_choice")
	if not _is_hand_deploy_choice_action(choice_action):
		return false
	var payload: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	payload["selected_card_ids"] = [card_id]
	payload["row"] = str(target.get("row", ""))
	payload["col"] = int(target.get("col", -1))
	return _execute_command(player_id, str(choice_action.get("command_type", "")), payload)

func _selected_action_uses_board_click(action: Dictionary) -> bool:
	if action.is_empty():
		return false
	return _targets_require_click_selection(action.get("targets", [])) and not _targets_are_stack_only(action.get("targets", []))


func _on_master_double_clicked(player_index: int) -> void:
	if _game_over:
		return
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	if player_index != _current_local_input_player():
		return
	if not _source_has_click_activation_panel(_current_input_player(), _master_source_id_for_display(player_index)):
		return
	_try_activate_source(_master_source_id_for_display(player_index), true)


func _on_master_clicked(player_index: int) -> void:
	if _game_over:
		return
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	if not _selected_target_action.is_empty() and _try_selected_target_action_on_master(player_index):
		return
	if not _selected_attacker_uid.is_empty() and _master_is_clickable_target(player_index):
		_attack_master(player_index)
		return
	if player_index == _current_local_input_player():
		return
	_attack_master(player_index)


func _try_play_card(uid: String, global_drop_position: Vector2) -> bool:
	var player_id := _current_local_input_player()
	if player_id < 0:
		return false
	var choice_deploy_match := _find_matching_choice_deploy_target(player_id, uid, global_drop_position)
	if not choice_deploy_match.is_empty():
		return _execute_choice_deploy_drag(player_id, uid, choice_deploy_match)
	var target_match := _find_matching_play_target(player_id, uid, global_drop_position)
	if target_match.is_empty():
		target_match = _find_matching_relaxed_rollo_play_target(player_id, uid, global_drop_position)
	if target_match.is_empty():
		var none_match := _find_drag_cast_tactic_action(player_id, uid, global_drop_position)
		if none_match.is_empty():
			return false
		return _execute_action_with_target(player_id, none_match, {"target_kind": "none"})
	return _execute_action_with_target(player_id, target_match.get("action", {}), target_match.get("target", {}))


func _try_board_drag_action(uid: String, global_drop_position: Vector2) -> bool:
	var player_id := _current_local_input_player()
	if player_id < 0:
		return false
	var choice_move_match := _find_matching_inline_move_choice_target(player_id, uid, global_drop_position)
	if not choice_move_match.is_empty():
		return _execute_choice_move_drag(player_id, uid, choice_move_match)
	var move_match := _find_matching_move_target(player_id, uid, global_drop_position)
	if not move_match.is_empty():
		return _execute_action_with_target(player_id, move_match.get("action", {}), move_match.get("target", {}))
	var attack_match := _find_matching_attack_target(player_id, uid, global_drop_position)
	if not attack_match.is_empty():
		return _execute_action_with_target(player_id, attack_match.get("action", {}), attack_match.get("target", {}))
	return false


func _execute_choice_move_drag(player_id: int, card_id: String, target: Dictionary) -> bool:
	var choice_action := _find_action(_player_actions(player_id), "resolve_choice")
	if choice_action.is_empty():
		return false
	if not _is_inline_move_choice_instruction_panel_operation(str(choice_action.get("operation", ""))):
		return false
	var payload: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	var row := str(target.get("row", ""))
	var col := int(target.get("col", -1))
	if str(choice_action.get("choice_type", choice_action.get("type", ""))) == "option_pick":
		payload["selected_option"] = "%s:%d" % [row, col]
	else:
		payload["selected_card_ids"] = [card_id]
		payload["row"] = row
		payload["col"] = col
	return _execute_command(player_id, str(choice_action.get("command_type", "")), payload)


func _try_source_drag_action(source_id: String, global_drop_position: Vector2) -> bool:
	var player_id := _current_local_input_player()
	if player_id < 0:
		return false
	var target_match := _find_matching_activation_target(player_id, source_id, global_drop_position)
	if target_match.is_empty():
		return false
	return _execute_action_with_target(player_id, target_match.get("action", {}), target_match.get("target", {}))


func _try_quick_play_card(uid: String) -> bool:
	var player_id := _current_local_input_player()
	if player_id < 0:
		return false
	var action := _find_none_target_play_action(player_id, uid)
	if action.is_empty():
		return false
	if _open_local_play_option_choice(player_id, action, {"target_kind": "none"}):
		return true
	return _execute_action_with_target(player_id, action, {"target_kind": "none"})


func _try_quick_response_play(card_id: String) -> bool:
	var player_id := _current_local_input_player()
	if player_id < 0:
		return false
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("payload_template", {}).get("card_id", "")) != card_id:
			continue
		var play_kind := str(action.get("play_kind", ""))
		if play_kind != "hand_response" and play_kind != "counter_tactic":
			continue
		if _selected_source_id == card_id:
			_clear_action_focus()
			_selected_stack_target_id = ""
			_refresh()
			return true
		_selected_source_id = card_id
		_selected_morale_filter = false
		_selected_target_action = {}
		_selected_stack_target_id = _default_response_stack_target_id_for_targets(action.get("targets", []))
		_selected_attacker_uid = ""
		_refresh()
		return true
	return false


func _try_quick_choose_defense(card_id: String) -> bool:
	var player_id := _current_local_input_player()
	if player_id < 0:
		return false
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "choose_defense":
			continue
		var defense_kind := str(action.get("source", {}).get("defense_kind", ""))
		var payload: Dictionary = action.get("payload_template", {})
		if str(payload.get("blocker_id", "")) == card_id:
			if _should_use_master_attack_response_confirm_panel():
				return false
			return _submit_choose_defense_response(player_id, payload, action)
		if str(payload.get("supporter_id", "")) == card_id:
			if _should_use_master_attack_response_confirm_panel():
				return false
			return _submit_choose_defense_response(player_id, payload, action)
		var guard_card_ids: Array = payload.get("master_guard_card_ids", [])
		if guard_card_ids.size() == 1 and str(guard_card_ids[0]) == card_id:
			if _should_use_master_attack_response_confirm_panel():
				_toggle_master_guard_card(card_id)
				return true
			return _submit_choose_defense_response(player_id, payload, action)
		if _string_array_from_variant_array(guard_card_ids).has(card_id):
			_toggle_master_guard_card(card_id)
			return true
	return false

func _find_none_target_play_action(player_id: int, card_id: String) -> Dictionary:
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("payload_template", {}).get("card_id", "")) != card_id:
			continue
		var targets = action.get("targets", [])
		if targets.size() == 1 and str(targets[0].get("target_kind", "none")) == "none":
			return action
	return {}


func _find_drag_cast_tactic_action(player_id: int, card_id: String, global_position: Vector2) -> Dictionary:
	if not _is_global_position_over_battlefield_play_area(global_position):
		return {}
	var action := _find_none_target_play_action(player_id, card_id)
	if action.is_empty():
		return {}
	if not _is_drag_castable_tactic_action(action):
		return {}
	return action


func _find_matching_play_target(player_id: int, card_id: String, global_position: Vector2) -> Dictionary:
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("payload_template", {}).get("card_id", "")) != card_id:
			continue
		for target in action.get("targets", []):
			var target_match := _match_target(global_position, target)
			if target_match.is_empty():
				continue
			target_match["action"] = action
			target_match["target"] = target
			return target_match
	return {}


func _find_matching_relaxed_rollo_play_target(player_id: int, card_id: String, global_position: Vector2) -> Dictionary:
	var slots := _relaxed_rollo_play_slots(player_id, card_id)
	if slots.is_empty():
		return {}
	var synthetic_action := {
		"kind": "play_card",
		"command_type": "PlayCard",
		"play_kind": "board_or_artifact",
		"payload_template": {
			"card_id": card_id
		}
	}
	for slot in slots:
		var row := str(slot.get("row", ""))
		var col := int(slot.get("col", -1))
		var slot_index := _slot_index_from_row_col(row, col)
		if slot_index < 0 or slot_index >= BOARD_SLOT_COUNT:
			continue
		var rect := _map_table_rect(BOARD_RECTS[player_id][slot_index])
		if not rect.has_point(global_position):
			continue
		return {
			"row": row,
			"col": col,
			"slot_index": slot_index,
			"zone_kind": "play_slot",
			"rect": rect,
			"action": synthetic_action,
			"target": {
				"row": row,
				"col": col
			}
		}
	return {}


func _source_has_drag_activation(player_id: int, source_id: String) -> bool:
	for action in _activation_actions_for_source(player_id, source_id):
		if _action_supports_drag_activation(action):
			return true
	return false


func _action_supports_drag_activation(action: Dictionary) -> bool:
	if action.is_empty():
		return false
	if str(action.get("kind", "")) != "activate_effect":
		return false
	return _targets_require_click_selection(action.get("targets", [])) and not _targets_are_stack_only(action.get("targets", []))


func _source_has_click_activation_panel(player_id: int, source_id: String) -> bool:
	var activations := _activation_actions_for_source(player_id, source_id)
	if activations.is_empty():
		return false
	if not source_id.begins_with("master_"):
		return true
	if activations.size() > 1:
		return true
	return not _action_supports_drag_activation(activations[0])


func _find_matching_activation_target(player_id: int, source_id: String, global_position: Vector2) -> Dictionary:
	for action in _activation_actions_for_source(player_id, source_id):
		for target in action.get("targets", []):
			var target_match := _match_target(global_position, target)
			if target_match.is_empty():
				continue
			target_match["action"] = action
			target_match["target"] = target
			return target_match
	return {}


func _is_drag_castable_tactic_action(action: Dictionary) -> bool:
	if action.is_empty():
		return false
	if str(action.get("kind", "")) != "play_card":
		return false
	var play_kind := str(action.get("play_kind", ""))
	return play_kind == "tactic"


func _find_matching_board_drag_target(player_id: int, card_id: String, global_position: Vector2) -> Dictionary:
	var choice_move_match := _find_matching_inline_move_choice_target(player_id, card_id, global_position)
	if not choice_move_match.is_empty():
		return choice_move_match
	var move_match := _find_matching_move_target(player_id, card_id, global_position)
	if not move_match.is_empty():
		return move_match
	return _find_matching_attack_target(player_id, card_id, global_position)


func _find_matching_inline_move_choice_target(player_id: int, card_id: String, global_position: Vector2) -> Dictionary:
	var choice_action := _find_action(_player_actions(player_id), "resolve_choice")
	if choice_action.is_empty():
		return {}
	var operation := str(choice_action.get("operation", ""))
	if not _is_inline_move_choice_instruction_panel_operation(operation):
		return {}
	if operation == "choose_battlefield_cards_to_move" and max(1, int(choice_action.get("count", 1))) != 1:
		return {}
	if operation == "choose_battlefield_cards_to_move" or operation == "forged_order_choose_enemy_move_card" or operation == "tsukuyomi_choose_move_card" or operation == "takamagahara_morale_choose_move_card":
		if not _string_array_from_variant_array(choice_action.get("candidate_card_ids", [])).has(card_id):
			return {}
	elif str(choice_action.get("context", {}).get("card_id", "")) != card_id:
		return {}
	var located := _find_card(card_id)
	if located.is_empty() or str(located.get("zone", "")) != "board":
		return {}
	var owner := int(located.get("owner", -1))
	if owner < 0 or owner >= 2:
		return {}
	var hovered_slot_index := _board_slot_at_global_position(owner, global_position)
	if hovered_slot_index < 0:
		return {}
	for target in _inline_move_choice_target_options(card_id):
		if int(target.get("slot_index", -1)) != hovered_slot_index:
			continue
		return target
	return {}


func _inline_move_choice_target_options(card_id: String) -> Array:
	var result: Array = []
	var located := _find_card(card_id)
	if located.is_empty() or str(located.get("zone", "")) != "board":
		return result
	var choice_action := _find_action(_player_actions(_current_input_player()), "resolve_choice")
	if choice_action.is_empty():
		return result
	var owner := int(located.get("owner", -1))
	var slot_index := int(located.get("index", -1))
	if owner < 0 or owner >= 2 or slot_index < 0 or slot_index >= BOARD_SLOT_COUNT:
		return result
	var row_col := _row_col_from_slot_index(slot_index)
	if row_col.is_empty():
		return result
	var row := str(row_col.get("row", ""))
	var col := int(row_col.get("col", -1))
	if (row != "front" and row != "back") or col < 0:
		return result
	var choice_type := str(choice_action.get("choice_type", choice_action.get("type", "")))
	var operation := str(choice_action.get("operation", ""))
	if choice_type == "option_pick":
		for option in choice_action.get("options", []):
			if not (option is Dictionary):
				continue
			var target_row := str(option.get("row", ""))
			var target_col := int(option.get("col", -1))
			if target_row.is_empty() or target_col < 0:
				continue
			_append_inline_move_choice_target_if_legal(owner, row, col, target_row, target_col, result)
		return result
	if operation == "choose_battlefield_cards_to_move":
		for target_row in ["front", "back"]:
			for target_col in range(3):
				_append_inline_move_choice_target_if_legal(owner, row, col, target_row, target_col, result)
		return result
	if operation == "forged_order_choose_enemy_move_card":
		_append_inline_move_choice_target_if_legal(owner, row, col, "back" if row == "front" else "front", col, result)
		return result
	_append_inline_move_choice_target_if_legal(owner, row, col, "back" if row == "front" else "front", col, result)
	_append_inline_move_choice_target_if_legal(owner, row, col, row, col - 1, result)
	_append_inline_move_choice_target_if_legal(owner, row, col, row, col + 1, result)
	return result


func _append_inline_move_choice_target_if_legal(owner: int, from_row: String, from_col: int, to_row: String, to_col: int, result: Array) -> void:
	if owner < 0 or owner >= 2 or to_col < 0 or to_col >= 3:
		return
	if to_row == "back" and from_row != "back" and _state != null and str(_state.current_calamity) == "sys_calamity_silence":
		return
	var target_index := _slot_index_from_row_col(to_row, to_col)
	if target_index < 0 or target_index >= BOARD_SLOT_COUNT:
		return
	var board: Array = _players[owner].get("board", [])
	if target_index < board.size():
		var occupant = board[target_index]
		if occupant is Dictionary and not str(occupant.get("uid", "")).is_empty():
			return
	result.append({
		"row": to_row,
		"col": to_col,
		"slot_index": target_index,
		"owner": owner,
		"zone_kind": "choice_move_slot",
		"rect": _map_table_rect(BOARD_RECTS[owner][target_index]),
		"from_row": from_row,
		"from_col": from_col,
	})


func _find_matching_move_target(player_id: int, card_id: String, global_position: Vector2) -> Dictionary:
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "move_legion":
			continue
		if str(action.get("payload_template", {}).get("card_id", "")) != card_id:
			continue
		for target in action.get("targets", []):
			var target_match := _match_target(global_position, target)
			if target_match.is_empty():
				continue
			target_match["action"] = action
			target_match["target"] = target
			return target_match
	return {}


func _find_matching_attack_target(player_id: int, attacker_id: String, global_position: Vector2) -> Dictionary:
	var action := _attack_action_for_attacker(player_id, attacker_id)
	if action.is_empty():
		return {}
	for target in action.get("targets", []):
		var target_match := _match_target(global_position, target)
		if target_match.is_empty():
			continue
		target_match["action"] = action
		target_match["target"] = target
		return target_match
	return {}


func _try_activate_source(source_id: String, force_panel: bool = false) -> bool:
	var player_id := _current_input_player()
	var activations := _activation_actions_for_source(player_id, source_id)
	if activations.is_empty():
		if force_panel:
			var hint := _activation_unavailable_hint(source_id)
			if not hint.is_empty():
				_push_log(hint)
			_refresh()
		return false
	if _selected_source_id == source_id:
		_clear_action_focus()
		_refresh()
		return true
	if activations.size() == 1 and not force_panel and not _response_window_active():
		_clear_action_focus()
		_on_panel_action_pressed(activations[0])
		return true
	_selected_source_id = source_id
	_selected_morale_filter = false
	_selected_attacker_uid = ""
	_selected_target_action = {}
	_selected_stack_target_id = _default_response_stack_target_id_for_actions(activations)
	_refresh()
	return true


func _should_use_sacred_shackle_release_confirm_panel(player_id: int) -> bool:
	if _state == null or player_id < 0 or _selected_source_id.is_empty():
		return false
	if not _selected_target_action.is_empty():
		return false
	if _selected_source_definition_id(_selected_source_id) != "neutral_s02_0013":
		return false
	var activations := _activation_actions_for_source(player_id, _selected_source_id)
	if activations.size() != 1:
		return false
	return _is_sacred_shackle_release_action(activations[0])


func _refresh_sacred_shackle_release_confirm_panel(player_id: int) -> void:
	var activations := _activation_actions_for_source(player_id, _selected_source_id)
	var release_action: Dictionary = activations[0] if not activations.is_empty() else {}
	var should_show := not release_action.is_empty()
	_action_panel.visible = should_show
	var panel_size := Vector2(360, 185)
	var panel_position := _popup_column_position(1, panel_size)
	var panel_title := "神圣枷锁"
	var action_signature := JSON.stringify({
		"visible": should_show,
		"mode": "sacred_shackle_release_confirm",
		"title": panel_title,
		"size": [panel_size.x, panel_size.y],
		"position": [panel_position.x, panel_position.y],
		"focus_source_id": _selected_source_id,
		"release_action": release_action,
		"network_locked": _network_input_locked(),
	})
	if not _panel_signature_changed("action", action_signature):
		return
	if not should_show:
		return
	_action_panel.size = panel_size
	_action_panel.position = panel_position
	_action_panel_title.text = panel_title
	_clear_children(_action_panel_body)
	var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "是否确认消耗3士气，弃置这张神圣枷锁？"
	_action_panel_body.add_child(hint)
	var confirm_button := _make_button("确认消耗3士气")
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.disabled = _network_input_locked()
	confirm_button.pressed.connect(func() -> void:
		_on_panel_action_pressed(release_action)
	)
	_action_panel_body.add_child(confirm_button)
	var cancel_button := _make_button("取消")
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.disabled = _network_input_locked()
	cancel_button.pressed.connect(func() -> void:
		_clear_action_focus()
		_refresh()
	)
	_action_panel_body.add_child(cancel_button)


func _is_sacred_shackle_release_action(action: Dictionary) -> bool:
	return str(action.get("kind", "")) == "activate_effect" \
		and str(action.get("payload_template", {}).get("effect_id", "")) == "sacred_shackle_release"


func _selected_source_definition_id(source_id: String) -> String:
	if _state == null or source_id.is_empty():
		return ""
	var instance = _state.card_instances.get(source_id, null)
	if instance == null:
		return ""
	return str(instance.definition_id)


func _should_use_master_attack_response_confirm_panel() -> bool:
	if _state == null or _game_over:
		return false
	if _selected_action_uses_board_click(_selected_target_action):
		return false
	if not _current_choice_action().is_empty():
		return false
	if not _state.stack.is_empty():
		return false
	if _state.pending_attack.is_empty():
		return false
	if str(_state.pending_attack.get("target_kind", "card")) != "master":
		return false
	var response_player := _current_input_player()
	if response_player < 0:
		return false
	if _should_auto_finish_committed_master_guard(response_player):
		return false
	return _display_target_player_from_variant(_state.pending_attack.get("target_player", -1)) == response_player


func _refresh_master_attack_response_confirm_panel(player_id: int) -> void:
	var response_actions := _player_actions(player_id)
	var pass_action := _find_action(response_actions, "pass_priority")
	var guard_actions := _master_guard_actions_from_list(response_actions)
	var focused_actions := _focused_response_actions(response_actions)
	var should_show := not pass_action.is_empty()
	_action_panel.visible = should_show
	var panel_size := Vector2(360, 210)
	var panel_position := _popup_column_position(1, panel_size)
	var panel_title := "主宰受击响应"
	var action_signature := JSON.stringify({
		"visible": should_show,
		"mode": "master_attack_confirm",
		"title": panel_title,
		"size": [panel_size.x, panel_size.y],
		"position": [panel_position.x, panel_position.y],
		"pending_attack": _state.pending_attack if _state != null else {},
		"focus_source_id": _selected_source_id,
		"selected_master_guard_cards": _selected_master_guard_cards,
		"focused_response_actions": focused_actions,
		"master_guard_feedback_text": _master_guard_feedback_text,
		"master_guard_submit_pending": _master_guard_submit_pending,
		"network_locked": _network_input_locked(),
	})
	if not _panel_signature_changed("action", action_signature):
		return
	if not should_show:
		return
	_action_panel.size = panel_size
	_action_panel.position = panel_position
	_action_panel_title.text = panel_title
	_clear_children(_action_panel_body)
	var summary := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = _response_summary_text(player_id)
	_action_panel_body.add_child(summary)
	var hint := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = _master_attack_confirm_hint_text(guard_actions, focused_actions)
	_action_panel_body.add_child(hint)
	var selection := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection.text = _master_attack_confirm_selection_text(guard_actions, focused_actions)
	_action_panel_body.add_child(selection)
	if not _master_guard_feedback_text.is_empty():
		var feedback := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feedback.text = _master_guard_feedback_text
		_action_panel_body.add_child(feedback)
	var confirm_button := _make_button("确认")
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var confirm_action := _master_attack_confirm_action(guard_actions, focused_actions)
	confirm_button.disabled = _master_guard_feedback_locked() or confirm_action.is_empty()
	confirm_button.pressed.connect(func() -> void:
		_execute_master_attack_confirm_selection(player_id)
	)
	_action_panel_body.add_child(confirm_button)
	var pass_button := _make_button("放弃")
	pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_button.disabled = _master_guard_feedback_locked() or pass_action.is_empty()
	pass_button.pressed.connect(func() -> void:
		_execute_master_attack_abandon(player_id, pass_action)
	)
	_action_panel_body.add_child(pass_button)


func _master_attack_confirm_action(guard_actions: Array[Dictionary], focused_actions: Array[Dictionary]) -> Dictionary:
	var matched_guard_action := _matching_master_guard_action(guard_actions, _selected_master_guard_cards)
	if not matched_guard_action.is_empty():
		return matched_guard_action
	if focused_actions.size() == 1:
		return focused_actions[0]
	if not _selected_stack_target_id.is_empty():
		for action in focused_actions:
			for target in action.get("targets", []):
				if str(target.get("target_stack_id", "")) == _selected_stack_target_id:
					return action
	return {}


func _execute_master_attack_confirm_selection(player_id: int) -> void:
	if _master_guard_feedback_locked():
		return
	var response_actions := _player_actions(player_id)
	var guard_actions := _master_guard_actions_from_list(response_actions)
	var focused_actions := _focused_response_actions(response_actions)
	var matched_guard_action := _matching_master_guard_action(guard_actions, _selected_master_guard_cards)
	if not matched_guard_action.is_empty():
		var guard_payload: Dictionary = matched_guard_action.get("payload_template", {}).duplicate(true)
		if _selected_master_guard_cards.is_empty():
			return
		guard_payload["master_guard_card_ids"] = _selected_master_guard_cards.duplicate()
		_set_master_guard_feedback("已提交护主，正在继续结算。", _network_mode_active)
		_submit_choose_defense_response(player_id, guard_payload, matched_guard_action)
		return
	var confirm_action := _master_attack_confirm_action(guard_actions, focused_actions)
	if confirm_action.is_empty():
		return
	if _network_mode_active:
		_on_panel_action_pressed(confirm_action)
		return
	_on_panel_action_pressed(confirm_action)
	_refresh()


func _execute_master_attack_abandon(player_id: int, pass_action: Dictionary) -> void:
	if _network_input_locked() or pass_action.is_empty():
		return
	_clear_selection_state()
	if _network_mode_active:
		_execute_command(player_id, str(pass_action.get("command_type", "")), pass_action.get("payload_template", {}))
		return
	if not _execute_command_locally(player_id, str(pass_action.get("command_type", "")), pass_action.get("payload_template", {}), true, false, REFRESH_MODE_NONE):
		_refresh()
		return
	_auto_pass_empty_response_window()
	_refresh()


func _submit_choose_defense_response(player_id: int, payload: Dictionary, action: Dictionary = {}) -> bool:
	if _network_input_locked():
		return false
	var is_master_guard := str(action.get("source", {}).get("defense_kind", "")) == "master_guard"
	if _network_mode_active:
		var queued := _execute_command(player_id, "ChooseDefense", payload)
		if not queued and is_master_guard:
			var failed_text := _master_guard_submit_failed_message()
			_set_master_guard_feedback(failed_text)
			_push_log(failed_text)
			_refresh()
		return queued
	var suppress_action := action if not action.is_empty() else {
		"kind": "choose_defense"
	}
	_maybe_mark_pending_self_response_followup(suppress_action, player_id)
	if not _execute_command_locally(player_id, "ChooseDefense", payload, true, false, REFRESH_MODE_NONE):
		if is_master_guard:
			var failed_text := _master_guard_submit_failed_message()
			_set_master_guard_feedback(failed_text)
			_push_log(failed_text)
		_refresh()
		return false
	if is_master_guard:
		_set_master_guard_feedback("已提交护主，正在继续结算。")
	_maybe_capture_self_response_followup_signature()
	_auto_pass_empty_response_window()
	_refresh()
	return true


func _master_attack_confirm_selection_text(guard_actions: Array[Dictionary], focused_actions: Array[Dictionary]) -> String:
	var lines: Array[String] = []
	if not _selected_master_guard_cards.is_empty():
		lines.append("已选护主手牌：%s" % _join_card_names_by_ids(_selected_master_guard_cards))
		lines.append("已选兵力：%d / 需要抵挡：%d" % [_selected_master_guard_power_total(), _current_pending_attack_required_guard_power()])
	else:
		lines.append("已选护主手牌：无")
	if not focused_actions.is_empty() and not _selected_source_id.is_empty():
		lines.append("已选反击牌：%s" % _card_name(_selected_source_id))
		if focused_actions.size() == 1:
			lines.append("确认后将发动：%s" % _response_action_button_text(focused_actions[0], _current_input_player()))
		else:
			lines.append("该牌有多个可发动效果，请先进一步选择。")
	else:
		lines.append("已选反击牌：无")
	return "\n".join(lines)


func _master_attack_confirm_hint_text(guard_actions: Array[Dictionary], focused_actions: Array[Dictionary]) -> String:
	if not focused_actions.is_empty():
		return "现在只需要点“确认”或“放弃”。高亮反击牌后，会在这里显示要发动的效果；如果改主意，再点一次该牌取消。"
	if not guard_actions.is_empty():
		return "请直接点击高亮手牌选择护主牌；窗口里会显示当前已选内容。选够后点“确认”，不想护主就点“放弃”。"
	return "当前没有可用护主或反击；点“放弃”后直接承受本次攻击。"


func _optional_stack_choice_hint_text(choice_action: Dictionary) -> String:
	var stack_item := _stack_item_from_choice_action(choice_action)
	if stack_item.is_empty():
		return "请选择是否发动该可选效果，未决定前不会继续结算。"
	var controller_id := int(stack_item.get("controller", -1))
	var source_name := _card_name(str(stack_item.get("source_instance_id", "")))
	var effect_text := _effect_text_for_stack_item(stack_item)
	var trigger_reason := _optional_trigger_reason_label(choice_action)
	return "%s 的 %s 因为%s触发了可选效果。若点“确认发动”，会执行：%s；若点“本次不发动”，就直接跳过这次触发。" % [
		_player_side_name(_display_player_for_logical(controller_id)),
		source_name,
		trigger_reason,
		effect_text
	]


func _focused_response_actions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _selected_source_id.is_empty():
		return result
	for action in actions:
		var kind := str(action.get("kind", ""))
		var payload: Dictionary = action.get("payload_template", {})
		if kind == "activate_effect":
			if str(payload.get("source_id", "")) != _selected_source_id:
				continue
			result.append(action)
			continue
		if kind == "play_card":
			var play_kind := str(action.get("play_kind", ""))
			if play_kind != "hand_response" and play_kind != "counter_tactic":
				continue
			if str(payload.get("card_id", "")) != _selected_source_id:
				continue
			result.append(action)
	return result


func _default_response_stack_target_id_for_actions(actions: Array) -> String:
	for action in actions:
		var stack_target_id := _default_response_stack_target_id_for_targets(action.get("targets", []))
		if not stack_target_id.is_empty():
			return stack_target_id
	return ""


func _default_response_stack_target_id_for_targets(targets: Array) -> String:
	var top_stack_id := ""
	if _state != null and not _state.stack.is_empty():
		top_stack_id = str(_state.stack[_state.stack.size() - 1].get("stack_id", ""))
	for target in targets:
		if not (target is Dictionary):
			continue
		if str(target.get("target_stack_id", "")) == top_stack_id and not top_stack_id.is_empty():
			return top_stack_id
	for target in targets:
		if not (target is Dictionary):
			continue
		if str(target.get("target_stack_id", "")) == "__pending_attack__":
			return "__pending_attack__"
	for target in targets:
		if not (target is Dictionary):
			continue
		var target_stack_id := str(target.get("target_stack_id", ""))
		if not target_stack_id.is_empty():
			return target_stack_id
	return ""


func _card_power_value(card_id: String) -> int:
	if _engine == null or _state == null or card_id.is_empty():
		return 0
	return _engine.get_card_power(_state, card_id)


func _selected_master_guard_power_total() -> int:
	var total := 0
	for card_id in _selected_master_guard_cards:
		total += _card_power_value(card_id)
	return total


func _current_pending_attack_required_guard_power() -> int:
	if _state == null or _state.pending_attack.is_empty():
		return 0
	return _card_power_value(str(_state.pending_attack.get("attacker_id", "")))


func _response_summary_text(response_player_id: int) -> String:
	if _state == null:
		return ""
	if not _state.pending_attack.is_empty():
		var attack: Dictionary = _state.pending_attack
		var attacker_id := str(attack.get("attacker_id", ""))
		var attacker_name := _card_name(attacker_id)
		var attacker_side := _player_side_name(_display_player_for_source(attacker_id))
		if str(attack.get("target_kind", "card")) == "master":
			var target_player := _display_target_player_from_variant(attack.get("target_player", response_player_id))
			var master_name := "主宰"
			if target_player >= 0 and target_player < _players.size():
				master_name = str(_players[target_player].get("master_name", "主宰"))
			return "%s 的 %s 正在攻击 %s 的 %s，所以现在触发主宰攻击响应。" % [attacker_side, attacker_name, _player_side_name(target_player), master_name]
		var defender_id := str(attack.get("defender_id", ""))
		return "%s 的 %s 正在攻击 %s，因此现在触发攻击响应。" % [attacker_side, attacker_name, _card_name(defender_id)]
	if _state.stack.is_empty():
		return ""
	var top_item: Dictionary = _state.stack[_state.stack.size() - 1]
	var controller_id := int(top_item.get("controller", -1))
	var trigger_reason := _optional_trigger_reason_label({"stack_item": top_item})
	return "%s 的 %s 因为%s触发了效果“%s”，现在可以选择是否回应。" % [
		_player_side_name(_display_player_for_logical(controller_id)),
		_card_name(str(top_item.get("source_instance_id", ""))),
		trigger_reason,
		_effect_text_for_stack_item(top_item)
	]


func _response_hint_text(response_player_id: int, response_meaningful_actions: Array, response_guard_actions: Array, focused_response_actions: Array, response_pass_action: Dictionary) -> String:
	if _state == null:
		return ""
	if not _state.pending_attack.is_empty() and str(_state.pending_attack.get("target_kind", "card")) == "master":
		if not focused_response_actions.is_empty():
			return "已选中的高亮反击牌属于 %s；请在本窗内确认要发动的效果。若不想用它，再点一次该牌取消。" % _player_side_name(response_player_id)
		return "高亮手牌可用于护主；高亮反击牌可点选后在本窗确认发动；如果什么都不做，就点“放弃”。"
	if not focused_response_actions.is_empty():
		return "对方这次操作可被回应。你已选中高亮的回应牌；确认后就会按当前这次事件进行回应。"
	if not _state.pending_attack.is_empty() and str(_state.pending_attack.get("target_kind", "card")) != "master" and not _unit_defense_actions_from_list(response_meaningful_actions).is_empty():
		return "请直接点击高亮军团进行防守；后排支援只会出现在被攻击前排的同列后排，不想防守就点“不回应”。"
	if not response_meaningful_actions.is_empty():
		return "对方这次操作可以回应。可直接在本窗点击要发动的回应；也可以先点高亮回应牌再确认。不想回应就点“不回应”。"
	if not response_guard_actions.is_empty():
		return "当前可通过高亮手牌进行护主；不想护主就点“放弃”。"
	if not response_pass_action.is_empty():
		return "当前没有其他可用回应；点“不回应”后将继续结算这次事件。"
	return ""


func _activation_actions_for_source(player_id: int, source_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "activate_effect":
			continue
		if str(action.get("payload_template", {}).get("source_id", "")) != source_id:
			continue
		result.append(action)
	return result


func _morale_activation_actions(player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "activate_effect":
			continue
		var source_id := str(action.get("payload_template", {}).get("source_id", ""))
		if not _is_morale_source_id(source_id):
			continue
		result.append(action)
	return result


func _on_morale_card_clicked(player_index: int, force_open: bool = false) -> void:
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	if _game_over or player_index != _current_local_input_player():
		return
	var actions := _morale_activation_actions(player_index)
	if actions.is_empty():
		_push_log("当前没有需要通过士气发动的主动效果。")
		_refresh()
		return
	if _selected_morale_filter:
		if not force_open:
			_refresh()
			return
	else:
		_selected_source_id = ""
		_selected_morale_filter = true
		_selected_attacker_uid = ""
		_selected_target_action = {}
		_selected_stack_target_id = ""
	_refresh()


func _clear_action_focus() -> void:
	_selected_source_id = ""
	_selected_morale_filter = false


func _master_guard_feedback_locked() -> bool:
	return _master_guard_submit_pending or _network_input_locked()


func _set_master_guard_feedback(text: String, submit_pending: bool = false) -> void:
	_master_guard_feedback_text = text
	_master_guard_submit_pending = submit_pending


func _clear_master_guard_feedback() -> void:
	_master_guard_feedback_text = ""
	_master_guard_submit_pending = false


func _reconcile_master_guard_feedback_state() -> void:
	if _state == null:
		_clear_master_guard_feedback()
		return
	if _state.pending_attack.is_empty():
		_clear_master_guard_feedback()
		return
	if str(_state.pending_attack.get("target_kind", "card")) != "master":
		_clear_master_guard_feedback()
		return
	if _master_guard_submit_pending and _network_mode_active:
		if _has_pending_network_command():
			return
		# Keep the master-guard panel locked while the submitted defense is still
		# waiting for stack resolution on the synchronized host state.
		if not _state.stack.is_empty():
			return
	_master_guard_submit_pending = false


func _master_guard_submit_failed_message() -> String:
	return "护主提交失败：当前这次防守已变化，请重新选择护主手牌后再确认。"


func _clear_selection_state() -> void:
	_selected_attacker_uid = ""
	_selected_target_action = {}
	_selected_stack_target_id = ""
	_selected_master_guard_cards.clear()
	_clear_master_guard_feedback()
	_clear_action_focus()


func _clear_local_interaction_state_for_ai_turn() -> bool:
	var had_local_state := _dragging_card_uid != "" \
		or not _selected_target_action.is_empty() \
		or not _selected_attacker_uid.is_empty() \
		or not _selected_source_id.is_empty() \
		or _selected_morale_filter \
		or not _local_play_option_choice.is_empty() \
		or not _active_choice_id.is_empty() \
		or not _choice_selected_card_ids.is_empty() \
		or not _choice_reorder_dragging_card_id.is_empty() \
		or not _selected_unit_defense_proposal_id.is_empty()
	if not had_local_state:
		return false
	_dragging_card_uid = ""
	_hover_slot_index = -1
	_hover_zone_kind = ""
	_clear_selection_state()
	_active_choice_id = ""
	_choice_selected_card_ids.clear()
	_choice_reorder_dragging_card_id = ""
	_local_play_option_choice = {}
	_selected_unit_defense_proposal_id = ""
	return true


func _try_selected_target_action_on_card(card_id: String) -> bool:
	var player_id := _current_input_player()
	for target in _selected_target_action.get("targets", []):
		var target_id := str(target.get("defender_id", target.get("target_card_id", "")))
		if target_id != card_id:
			continue
		var action := _selected_target_action
		_selected_target_action = {}
		return _execute_action_with_target(player_id, action, target)
	return false


func _try_selected_target_action_on_master(player_index: int) -> bool:
	var player_id := _current_input_player()
	for target in _selected_target_action.get("targets", []):
		if str(target.get("target_kind", "")) != "master":
			continue
		if _display_target_player_from_variant(target.get("target_player", -1)) != player_index:
			continue
		var action := _selected_target_action
		_selected_target_action = {}
		return _execute_action_with_target(player_id, action, target)
	return false


func _try_selected_target_action_on_morale_area(player_index: int) -> bool:
	var player_id := _current_input_player()
	for target in _selected_target_action.get("targets", []):
		if str(target.get("target_kind", "")) != "morale_area":
			continue
		if _display_target_player_from_variant(target.get("target_player", -1)) != player_index:
			continue
		var action := _selected_target_action
		_selected_target_action = {}
		return _execute_action_with_target(player_id, action, target)
	return false


func _match_target(global_position: Vector2, target: Dictionary) -> Dictionary:
	if target.has("row"):
		var row := str(target.get("row", ""))
		var board_player := _display_target_player_from_variant(target.get("host_player", _current_input_player()))
		if row == "artifact":
			if _artifact_slot_at_global_position(board_player, global_position):
				return {"zone_kind": "artifact", "slot_index": -1, "rect": _map_table_rect(ARTIFACT_RECTS[board_player])}
			return {}
		var slot_index := _slot_index_from_row_col(row, int(target.get("col", -1)))
		if slot_index >= 0 and _board_slot_at_global_position(board_player, global_position) == slot_index:
			return {"zone_kind": "board", "slot_index": slot_index, "rect": _map_table_rect(BOARD_RECTS[board_player][slot_index])}
		return {}
	match str(target.get("target_kind", "")):
		"card":
			var defender_id := str(target.get("defender_id", target.get("target_card_id", "")))
			var located := _find_card(defender_id)
			if located.is_empty() or str(located.get("zone", "")) != "board":
				return {}
			var slot_index = int(located.get("index", -1))
			var owner = int(located.get("owner", -1))
			var rect := _map_table_rect(BOARD_RECTS[owner][slot_index])
			var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
			if rect.has_point(local_position):
				return {"zone_kind": "target_card", "slot_index": slot_index, "rect": rect}
		"master":
			var target_player := int(target.get("target_player", -1))
			if target_player >= 0 and target_player < 2:
				var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
				var rect := _map_table_rect(MASTER_RECTS[_display_player_for_logical(target_player)])
				if rect.has_point(local_position):
					return {"zone_kind": "master", "slot_index": -1, "rect": rect}
		"morale_area":
			var target_player := _display_target_player_from_variant(target.get("target_player", -1))
			if target_player >= 0 and target_player < 2:
				var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
				var rect := _map_table_rect(COST_AREA_RECTS[target_player])
				if rect.has_point(local_position):
					return {"zone_kind": "morale_area", "slot_index": -1, "rect": rect}
	return {}


func _source_highlight_rect(source_id: String) -> Rect2:
	if source_id.is_empty():
		return Rect2()
	if source_id.begins_with("master_"):
		var player_index := _display_player_for_logical(int(source_id.trim_prefix("master_")))
		if player_index >= 0 and player_index < 2:
			return _map_table_rect(MASTER_RECTS[player_index])
		return Rect2()
	if _is_morale_source_id(source_id):
		var player_index := _display_player_for_logical(int(source_id.trim_prefix("morale_")))
		if player_index >= 0 and player_index < 2:
			return _map_table_rect(COST_AREA_RECTS[player_index])
		return Rect2()
	var located := _find_card(source_id)
	if located.is_empty():
		return Rect2()
	var owner := int(located.get("owner", -1))
	if owner < 0 or owner >= 2:
		return Rect2()
	match str(located.get("zone", "")):
		"hand":
			if _should_hide_hand_from_local_player(owner):
				return Rect2()
			var hand: Array = _players[owner]["hand"]
			var sorted_hand := _sorted_hand_cards(hand)
			var card_size := _card_size()
			var positions := _hand_positions(owner, sorted_hand.size(), card_size)
			for i in range(sorted_hand.size()):
				if str(sorted_hand[i].get("uid", "")) == source_id and i < positions.size():
					return Rect2(positions[i], card_size)
			return Rect2()
		"artifact":
			return _map_table_rect(ARTIFACT_RECTS[owner])
		"cost_area", "spent_cost_area":
			return _cost_card_rect(owner, str(located.get("zone", "")), int(located.get("index", -1)))
		"board":
			var index := int(located.get("index", -1))
			if index >= 0 and index < BOARD_SLOT_COUNT:
				return _map_table_rect(BOARD_RECTS[owner][index])
	return Rect2()


func _choice_source_highlight_rect(choice_action: Dictionary, source_id: String) -> Rect2:
	if bool(choice_action.get("context", {}).get("allow_hidden_hand_highlight", false)):
		return _source_highlight_rect_allow_hidden_hand(source_id)
	return _source_highlight_rect(source_id)


func _source_highlight_rect_allow_hidden_hand(source_id: String) -> Rect2:
	if source_id.is_empty():
		return Rect2()
	var located := _find_card(source_id)
	if located.is_empty():
		return _source_highlight_rect(source_id)
	if str(located.get("zone", "")) != "hand":
		return _source_highlight_rect(source_id)
	var owner := int(located.get("owner", -1))
	if owner < 0 or owner >= 2:
		return Rect2()
	var hand: Array = _players[owner]["hand"]
	var sorted_hand := _sorted_hand_cards(hand)
	var card_size := _card_size()
	var positions := _hand_positions(owner, sorted_hand.size(), card_size)
	for i in range(sorted_hand.size()):
		if str(sorted_hand[i].get("uid", "")) == source_id and i < positions.size():
			return Rect2(positions[i], card_size)
	return Rect2()


func _cost_card_rect(player_index: int, zone: String, index: int) -> Rect2:
	if player_index < 0 or player_index >= 2 or index < 0:
		return Rect2()
	var active_cards: Array = _players[player_index]["cost_area_cards"]
	var spent_cards: Array = _players[player_index]["spent_cost_area_cards"]
	var target_uid := ""
	if zone == "cost_area":
		if index >= active_cards.size():
			return Rect2()
		target_uid = str(active_cards[index].get("uid", ""))
	elif zone == "spent_cost_area":
		if index >= spent_cards.size():
			return Rect2()
		target_uid = str(spent_cards[index].get("uid", ""))
	if target_uid.is_empty():
		return Rect2()
	var display_entries := _morale_display_entries(player_index)
	if display_entries.is_empty():
		return Rect2()
	var rect := _map_table_rect(COST_AREA_RECTS[player_index])
	var card_size := _card_size()
	var positions := _cost_card_positions(rect, display_entries.size(), card_size)
	for visual_index in range(display_entries.size()):
		var entry: Dictionary = display_entries[visual_index]
		var card: Dictionary = entry.get("card", {})
		if str(card.get("uid", "")) == target_uid and visual_index < positions.size():
			return Rect2(positions[visual_index], card_size)
	return Rect2()


func _execute_action_with_target(player_id: int, action: Dictionary, target: Dictionary) -> bool:
	if action.is_empty():
		return false
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return false
	if _open_local_play_option_choice(player_id, action, target):
		return true
	if _response_submission_should_suppress_followup(action) or str(action.get("kind", "")) == "activate_effect":
		_clear_action_focus()
	_maybe_mark_pending_self_response_followup(action, player_id)
	var payload: Dictionary = action.get("payload_template", {}).duplicate(true)
	for key in target.keys():
		if key in ["defense_options"]:
			continue
		payload[key] = target.get(key)
	return _execute_command(player_id, str(action.get("command_type", "")), payload)


func _current_choice_action() -> Dictionary:
	var choice_action := _find_action(_player_actions(_current_input_player()), "resolve_choice")
	if not choice_action.is_empty():
		_local_play_option_choice = {}
		return choice_action
	if _local_play_option_choice_still_available():
		return _local_play_option_choice
	_local_play_option_choice = {}
	return {}


func _current_local_choice_action() -> Dictionary:
	var player_id := _current_local_input_player()
	if player_id < 0:
		return {}
	var choice_action := _find_action(_player_actions(player_id), "resolve_choice")
	if not choice_action.is_empty():
		_local_play_option_choice = {}
		return choice_action
	if _local_play_option_choice_still_available():
		return _local_play_option_choice
	_local_play_option_choice = {}
	return {}


func _local_play_option_choice_still_available() -> bool:
	if _local_play_option_choice.is_empty():
		return false
	if str(_local_play_option_choice.get("operation", "")) == "test_mode_choose_calamity":
		return _is_current_test_duel() and _state != null and _current_local_input_player() >= 0
	var payload: Dictionary = _local_play_option_choice.get("payload_template", {})
	var card_id := str(payload.get("card_id", ""))
	if card_id.is_empty():
		return false
	if str(_local_play_option_choice.get("operation", "")) == "play_card_effect_pick":
		return _play_effect_menu_entries_for_card(_current_input_player(), card_id).size() > 1
	return not _play_option_menu_entries_for_card(_current_input_player(), card_id).is_empty()


func _play_option_actions_for_card(player_id: int, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("play_kind", "")) != "board_or_artifact":
			continue
		if str(action.get("payload_template", {}).get("card_id", "")) != card_id:
			continue
		if str(action.get("payload_template", {}).get("play_option_id", "")).is_empty():
			continue
		result.append(action)
	return result


func _play_option_menu_entries_for_card(player_id: int, card_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var option_actions := _play_option_actions_for_card(player_id, card_id)
	var seen_option_ids: Dictionary = {}
	for option_action in option_actions:
		var option_id := str(option_action.get("payload_template", {}).get("play_option_id", ""))
		if option_id.is_empty() or seen_option_ids.has(option_id):
			continue
		seen_option_ids[option_id] = true
		var option_label := str(option_action.get("play_option_label", option_action.get("source", {}).get("play_option_label", "")))
		if option_label.is_empty():
			option_label = "正常登场" if option_id == "default" else option_id
		entries.append({
			"id": option_id,
			"text": option_label
		})
	if not entries.is_empty():
		return entries
	if not _can_offer_relaxed_rollo_drag(player_id, card_id):
		return entries
	var definition = _definition_for_source(card_id)
	if definition == null:
		return entries
	entries.append({
		"id": "default",
		"text": "正常登场"
	})
	for raw_option in definition.play_options:
		if not (raw_option is Dictionary):
			continue
		var option_id := str(raw_option.get("id", ""))
		if option_id.is_empty() or seen_option_ids.has(option_id):
			continue
		seen_option_ids[option_id] = true
		entries.append({
			"id": option_id,
			"text": str(raw_option.get("label", option_id))
		})
	return entries


func _play_effect_actions_for_card(player_id: int, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "play_card":
			continue
		if str(action.get("play_kind", "")) != "tactic":
			continue
		if str(action.get("payload_template", {}).get("card_id", "")) != card_id:
			continue
		if str(action.get("payload_template", {}).get("effect_id", "")).is_empty():
			continue
		result.append(action)
	return result


func _play_effect_menu_entries_for_card(player_id: int, card_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen_effect_ids: Dictionary = {}
	for effect_action in _play_effect_actions_for_card(player_id, card_id):
		var effect_id := str(effect_action.get("payload_template", {}).get("effect_id", ""))
		if effect_id.is_empty() or seen_effect_ids.has(effect_id):
			continue
		seen_effect_ids[effect_id] = true
		var effect_text := str(effect_action.get("effect_text", effect_action.get("source", {}).get("effect_text", "")))
		if effect_text.is_empty():
			effect_text = effect_id
		entries.append({
			"id": effect_id,
			"text": effect_text
		})
	return entries


func _find_play_effect_action(player_id: int, card_id: String, effect_id: String) -> Dictionary:
	if effect_id.is_empty():
		return {}
	for action in _play_effect_actions_for_card(player_id, card_id):
		if str(action.get("payload_template", {}).get("effect_id", "")) == effect_id:
			return action
	return {}


func _can_offer_relaxed_rollo_drag(player_index: int, card_id: String) -> bool:
	if _state == null or _game_over:
		return false
	if player_index != _current_local_input_player():
		return false
	if not _relaxed_rollo_play_slots(player_index, card_id).is_empty():
		return true
	return false


func _relaxed_rollo_play_slots(player_index: int, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _state == null or _game_over or card_id.is_empty():
		return result
	if player_index != _current_local_input_player():
		return result
	if not _state.stack.is_empty() or not _state.pending_attack.is_empty() or not _state.pending_choices.is_empty():
		return result
	if int(_state.active_player) != _logical_player_for_display(player_index):
		return result
	if str(_state.phase) != "main":
		return result
	var logical_player_id := _logical_player_for_display(player_index)
	if logical_player_id < 0 or logical_player_id >= _state.players.size():
		return result
	if not _state.get_player(logical_player_id).hand.has_card(card_id):
		return result
	var definition = _definition_for_source(card_id)
	if definition == null or str(definition.id) != "asgard_s02_0302":
		return result
	for slot in _engine.get_legal_play_slots(_state, logical_player_id, card_id):
		result.append(slot.duplicate(true))
	if not result.is_empty():
		return result
	for row in ["front", "back"]:
		for col in range(3):
			var state_slot = _state.get_player(logical_player_id).get_slot(row, col)
			if state_slot == null or not str(state_slot.occupant).is_empty():
				continue
			result.append({
				"row": row,
				"col": col
			})
	return result


func _open_local_play_option_choice(player_id: int, action: Dictionary, target: Dictionary) -> bool:
	if str(action.get("kind", "")) != "play_card":
		return false
	var payload: Dictionary = action.get("payload_template", {})
	var card_id := str(payload.get("card_id", ""))
	if card_id.is_empty():
		return false
	var play_kind := str(action.get("play_kind", ""))
	var operation := "play_card_option_pick"
	var title := "选择登场方式"
	var options: Array[Dictionary] = []
	if play_kind == "board_or_artifact":
		options = _play_option_menu_entries_for_card(player_id, card_id)
	elif play_kind == "tactic" and str(target.get("target_kind", "none")) == "none":
		options = _play_effect_menu_entries_for_card(player_id, card_id)
		if options.size() <= 1:
			return false
		operation = "play_card_effect_pick"
		title = "选择发动效果"
	else:
		return false
	if options.is_empty():
		return false
	options.append({
		"id": "__cancel__",
		"text": "取消"
	})
	_local_play_option_choice = {
		"proposal_id": "local_play_choice:%s:%s" % [operation, card_id],
		"kind": "resolve_choice",
		"command_type": "PlayCard",
		"title": title,
		"choice_type": "option_pick",
		"operation": operation,
		"payload_template": {
			"card_id": card_id
		},
		"options": options,
		"selected_target": target.duplicate(true),
		"top_hint_text": _play_option_choice_hint_text({
			"operation": operation,
			"payload_template": {"card_id": card_id},
			"options": options
		})
	}
	_selected_target_action = {}
	_selected_stack_target_id = ""
	_selected_attacker_uid = ""
	_clear_action_focus()
	_refresh()
	return true


func _execute_local_play_option_choice(player_id: int, choice_action: Dictionary, option_id: String) -> bool:
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条选择。")
		return false
	if option_id == "__cancel__":
		_local_play_option_choice = {}
		_clear_selection_state()
		_refresh()
		return true
	var payload: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	var target: Dictionary = choice_action.get("selected_target", {}).duplicate(true)
	for key in target.keys():
		if key in ["defense_options"]:
			continue
		payload[key] = target.get(key)
	var operation := str(choice_action.get("operation", ""))
	if operation == "play_card_option_pick" and option_id == "rollo_recycle_up_to_8":
		return _open_local_rollo_grave_choice(player_id, payload, target)
	if operation == "play_card_option_pick":
		payload["play_option_id"] = option_id
		_local_play_option_choice = {}
		return _execute_command(player_id, "PlayCard", payload)
	if operation == "play_card_effect_pick":
		var card_id := str(payload.get("card_id", ""))
		var selected_action := _find_play_effect_action(player_id, card_id, option_id)
		_local_play_option_choice = {}
		if selected_action.is_empty():
			_refresh()
			return false
		var selected_targets = selected_action.get("targets", [])
		if _targets_require_click_selection(selected_targets):
			_selected_target_action = selected_action
			_selected_stack_target_id = ""
			_selected_attacker_uid = ""
			_clear_action_focus()
			_refresh()
			return true
		var selected_payload: Dictionary = selected_action.get("payload_template", {}).duplicate(true)
		if not selected_targets.is_empty() and selected_targets[0] is Dictionary:
			for key in selected_targets[0].keys():
				if key in ["defense_options"]:
					continue
				selected_payload[key] = selected_targets[0].get(key)
		_clear_action_focus()
		return _execute_command(player_id, str(selected_action.get("command_type", "PlayCard")), selected_payload)
	return false


func _open_local_rollo_grave_choice(player_id: int, payload: Dictionary, target: Dictionary) -> bool:
	if _state == null:
		return false
	var logical_player_id := _logical_player_for_display(player_id)
	if logical_player_id < 0 or logical_player_id >= _state.players.size():
		return false
	var grave_display_ids: Array[String] = []
	var grave_candidate_ids: Array[String] = []
	for raw_card_id in _state.get_player(logical_player_id).grave.cards:
		var grave_card_id = str(raw_card_id)
		if grave_card_id.is_empty():
			continue
		grave_display_ids.append(grave_card_id)
		var definition = _definition_for_source(grave_card_id)
		if definition != null and str(definition.faction) == "asgard":
			grave_candidate_ids.append(grave_card_id)
	_local_play_option_choice = {
		"proposal_id": "local_play_option_grave:%s" % str(payload.get("card_id", "")),
		"kind": "resolve_choice",
		"command_type": "PlayCard",
		"title": "选择要回底的墓地卡牌",
		"choice_type": "candidate_cards_pick",
		"operation": "local_play_option_grave_pick",
		"payload_template": {
			"card_id": str(payload.get("card_id", "")),
			"play_option_id": "rollo_recycle_up_to_8"
		},
		"candidate_card_ids": grave_candidate_ids.duplicate(),
		"highlight_card_ids": grave_candidate_ids.duplicate(),
		"count": 8,
		"allow_up_to_count": true,
		"min_select_count": 0,
		"requires_confirm": true,
		"context": {
			"display_card_ids": grave_display_ids.duplicate()
		},
		"selected_target": target.duplicate(true),
		"hint_text": "请选择墓地中最多8张高亮的【阿斯加德】卡牌；点击顺序就是回到底部的顺序，每返回2张费用-1。",
		"top_hint_text": "步行者罗洛：请选择最多8张【阿斯加德】墓地卡牌，按选择顺序回到底部；每返回2张，登场费用-1。"
	}
	_selected_target_action = {}
	_selected_stack_target_id = ""
	_selected_attacker_uid = ""
	_clear_action_focus()
	_refresh()
	return true


func _execute_local_play_option_grave_choice(player_id: int, choice_action: Dictionary) -> bool:
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条选择。")
		return false
	var payload: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	var target: Dictionary = choice_action.get("selected_target", {}).duplicate(true)
	for key in target.keys():
		if key in ["defense_options"]:
			continue
		payload[key] = target.get(key)
	payload["selected_grave_card_ids"] = _choice_selected_card_ids.duplicate()
	_local_play_option_choice = {}
	return _execute_command(player_id, "PlayCard", payload)


func _command_failure_text(command_type: String, payload: Dictionary, result: Dictionary) -> String:
	var code := str(result.get("error_code", result.get("code", "UNKNOWN")))
	if command_type == "PlayCard":
		var card_id := str(payload.get("card_id", ""))
		var definition = _definition_for_source(card_id)
		if definition != null and str(definition.id) == "asgard_s02_0302" and code == "NOT_ENOUGH_MORALE":
			return "士气不足，无法登场"
		if definition != null and str(definition.id) == "asgard_s02_0306":
			if code == "EFFECT_ALREADY_USED":
				return "每回合只可使用1次"
			if code == "INSUFFICIENT_MASTER_DAMAGE" or code == "INSUFFICIENT_MASTER_EFFECT_DAMAGE":
				return "未满足使用条件"
	return "操作失败：%s" % code


func _play_option_choice_hint_text(choice_action: Dictionary) -> String:
	var payload: Dictionary = choice_action.get("payload_template", {})
	var card_id := str(payload.get("card_id", ""))
	var card_name := _card_name(card_id)
	var option_labels: Array[String] = []
	for option in choice_action.get("options", []):
		var option_id := str(option.get("id", ""))
		if option_id == "__cancel__":
			continue
		option_labels.append(str(option.get("text", option.get("label", option_id))))
	if str(choice_action.get("operation", "")) == "play_card_effect_pick":
		if option_labels.is_empty():
			return "%s 打出前，需要先确认本次要发动哪个效果。" % card_name
		if option_labels.size() == 1:
			return "%s 打出前，可选效果需要你先明确确认；若要发动，请点“%s”，不想发动就点“取消”。" % [card_name, option_labels[0]]
		return "%s 打出前，请先确认这次要发动哪个效果。" % card_name
	if option_labels.is_empty():
		return "%s 打出前，需要先确认本次采用哪种登场方式。" % card_name
	if option_labels.size() == 1:
		return "%s 打出前，可选效果需要你先明确确认；若要发动，请点“%s”，不想发动就点“取消”。" % [card_name, option_labels[0]]
	return "%s 打出前，请先确认这次要使用哪种登场方式。" % card_name


func _response_submission_should_suppress_followup(action: Dictionary) -> bool:
	if action.is_empty() or not _response_window_active():
		return false
	var kind := str(action.get("kind", ""))
	return kind == "play_card" or kind == "activate_effect" or kind == "choose_defense"


func _maybe_mark_pending_self_response_followup(action: Dictionary, player_id: int) -> void:
	if not _response_submission_should_suppress_followup(action):
		return
	_pending_self_response_followup_player = player_id
	_suppressed_self_response_followup_signature = ""


func _maybe_capture_self_response_followup_signature() -> void:
	if _pending_self_response_followup_player == -1:
		if _state != null and _state.stack.is_empty() and _state.pending_attack.is_empty():
			_suppressed_self_response_followup_signature = ""
		return
	var player_id := _pending_self_response_followup_player
	_pending_self_response_followup_player = -1
	if _state == null:
		_suppressed_self_response_followup_signature = ""
		return
	if not _state.pending_attack.is_empty():
		var attack_signature := _pending_attack_followup_signature_for_player(player_id)
		if not attack_signature.is_empty():
			_suppressed_self_response_followup_signature = attack_signature
			return
	if _state.stack.is_empty():
		_suppressed_self_response_followup_signature = ""
		return
	var top_stack: Dictionary = _state.stack[_state.stack.size() - 1]
	var top_controller := _display_player_for_logical(int(top_stack.get("controller", -1)))
	if top_controller != player_id:
		_suppressed_self_response_followup_signature = ""
		return
	_suppressed_self_response_followup_signature = _self_response_followup_signature_for_player(player_id)


func _self_response_followup_signature_for_player(player_id: int) -> String:
	if _state == null or _state.stack.is_empty() or player_id < 0:
		return ""
	var top_stack: Dictionary = _state.stack[_state.stack.size() - 1]
	if _display_player_for_logical(int(top_stack.get("controller", -1))) != player_id:
		return ""
	return "stack:%s:player:%d" % [str(top_stack.get("stack_id", "")), player_id]


func _self_response_followup_should_auto_pass(player_id: int) -> bool:
	if _suppressed_self_response_followup_signature.is_empty():
		return false
	var stack_signature := _self_response_followup_signature_for_player(player_id)
	if stack_signature == _suppressed_self_response_followup_signature and not stack_signature.is_empty():
		return true
	var attack_signature := _pending_attack_followup_signature_for_player(player_id)
	return attack_signature == _suppressed_self_response_followup_signature and not attack_signature.is_empty()


func _clear_self_response_followup_signature_if_matches(player_id: int) -> void:
	if _self_response_followup_should_auto_pass(player_id):
		_suppressed_self_response_followup_signature = ""


func _pending_attack_followup_signature_for_player(player_id: int) -> String:
	if _state == null or _state.pending_attack.is_empty() or player_id < 0:
		return ""
	var attack: Dictionary = _state.pending_attack
	if str(attack.get("target_kind", "card")) == "master":
		var target_player := _display_target_player_from_variant(attack.get("target_player", -1))
		if target_player != player_id:
			return ""
	elif _display_player_for_source(str(attack.get("defender_id", ""))) != player_id:
		return ""
	var attacker_id := str(attack.get("attacker_id", ""))
	return "pending_attack:%s:%s:%s:%s" % [
		attacker_id,
		str(attack.get("target_kind", "card")),
		str(attack.get("defender_id", "")),
		str(attack.get("target_player", -1))
	]


func _attack_card(target_uid: String) -> void:
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	if _selected_attacker_uid == "":
		return
	var player_id := _current_input_player()
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "declare_attack":
			continue
		if str(action.get("payload_template", {}).get("attacker_id", "")) != _selected_attacker_uid:
			continue
		for target in action.get("targets", []):
			if str(target.get("target_kind", "")) == "card" and str(target.get("defender_id", "")) == target_uid:
				_selected_attacker_uid = ""
				_execute_action_with_target(player_id, action, target)
				return
		return


func _attack_master(target_player: int) -> void:
	if _network_input_locked():
		_push_log("联机同步中：请等待房主确认上一条操作。")
		return
	if _selected_attacker_uid == "":
		return
	if _state != null and not _state.pending_attack.is_empty():
		var pending_target_kind := str(_state.pending_attack.get("target_kind", ""))
		var pending_target_player := _display_target_player_from_variant(_state.pending_attack.get("target_player", -1))
		if pending_target_kind == "master" and pending_target_player == target_player:
			var attacker_id := str(_state.pending_attack.get("attacker_id", _selected_attacker_uid))
			_append_file_log("[UI] master click uses pending attack attacker=%s target_player=%s" % [attacker_id, str(_state.pending_attack.get("target_player", target_player))])
			_selected_attacker_uid = ""
			_execute_command(_current_input_player(), "DeclareAttack", {
				"attacker_id": attacker_id,
				"target_kind": "master",
				"target_player": int(_state.pending_attack.get("target_player", target_player))
			})
			return
	var player_id := _current_input_player()
	var direct_target := _direct_master_attack_target(player_id, _selected_attacker_uid, target_player)
	if not direct_target.is_empty():
		var attacker_id := _selected_attacker_uid
		_append_file_log("[UI] master click direct attack attacker=%s target_player=%s" % [attacker_id, str(direct_target.get("target_player", target_player))])
		_selected_attacker_uid = ""
		_execute_command(player_id, "DeclareAttack", {
			"attacker_id": attacker_id,
			"target_kind": "master",
			"target_player": int(direct_target.get("target_player", target_player))
		})
		return
	for action in _player_actions(player_id):
		if str(action.get("kind", "")) != "declare_attack":
			continue
		if str(action.get("payload_template", {}).get("attacker_id", "")) != _selected_attacker_uid:
			continue
		for target in action.get("targets", []):
			if str(target.get("target_kind", "")) == "master" and _display_target_player_from_variant(target.get("target_player", -1)) == target_player:
				_selected_attacker_uid = ""
				_execute_action_with_target(player_id, action, target)
				return
		return

func _direct_master_attack_target(player_id: int, attacker_id: String, target_player: int) -> Dictionary:
	for target in _engine.get_legal_attack_targets(_state, attacker_id):
		if not (target is Dictionary):
			continue
		if str(target.get("target_kind", "")) != "master":
			continue
		if _display_target_player_from_variant(target.get("target_player", -1)) != target_player:
			continue
		return target
	return {}


func _find_card(uid: String) -> Dictionary:
	for player_index in range(2):
		var master = _players[player_index]["master"]
		if master != null and str(master.get("uid", "")) == uid:
			return {"owner": player_index, "zone": "master", "index": 0, "card": master}
		var hand: Array = _players[player_index]["hand"]
		for i in range(hand.size()):
			if str(hand[i].get("uid", "")) == uid:
				return {"owner": player_index, "zone": "hand", "index": i, "card": hand[i]}
		var active_morale: Array = _players[player_index]["cost_area_cards"]
		for i in range(active_morale.size()):
			if str(active_morale[i].get("uid", "")) == uid:
				return {"owner": player_index, "zone": "cost_area", "index": i, "card": active_morale[i]}
		var spent_morale: Array = _players[player_index]["spent_cost_area_cards"]
		for i in range(spent_morale.size()):
			if str(spent_morale[i].get("uid", "")) == uid:
				return {"owner": player_index, "zone": "spent_cost_area", "index": i, "card": spent_morale[i]}
		var artifact = _players[player_index]["artifact"]
		if artifact != null and str(artifact.get("uid", "")) == uid:
			return {"owner": player_index, "zone": "artifact", "index": 0, "card": artifact}
		var board: Array = _players[player_index]["board"]
		for i in range(board.size()):
			var card = board[i]
			if card != null and str(card.get("uid", "")) == uid:
				return {"owner": player_index, "zone": "board", "index": i, "card": card}
	return {}


func _board_slot_at_global_position(player_index: int, global_position: Vector2) -> int:
	var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
	for slot_index in range(BOARD_SLOT_COUNT):
		var rect: Rect2 = _map_table_rect(BOARD_RECTS[player_index][slot_index])
		if rect.has_point(local_position):
			return slot_index
	return -1


func _artifact_slot_at_global_position(player_index: int, global_position: Vector2) -> bool:
	var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
	return _map_table_rect(ARTIFACT_RECTS[player_index]).has_point(local_position)


func _is_global_position_over_battlefield_play_area(global_position: Vector2) -> bool:
	var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
	return _battlefield_play_area_rect().has_point(local_position)


func _battlefield_hover_rect_at_global_position(global_position: Vector2) -> Rect2:
	var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
	var play_area := _battlefield_play_area_rect()
	if play_area.has_point(local_position):
		return play_area
	return Rect2()


func _battlefield_play_area_rect() -> Rect2:
	var area := Rect2()
	var initialized := false
	for player_index in range(2):
		var rects: Array[Rect2] = [
			_map_table_rect(MASTER_RECTS[player_index]),
			_map_table_rect(ARTIFACT_RECTS[player_index])
		]
		for slot_index in range(BOARD_SLOT_COUNT):
			rects.append(_map_table_rect(BOARD_RECTS[player_index][slot_index]))
		for rect in rects:
			if not initialized:
				area = rect
				initialized = true
				continue
			area = area.merge(rect)
	if not initialized:
		return Rect2()
	return area.grow(18.0)


func _dragged_card_shows_drag_line() -> bool:
	if _dragging_card_uid.is_empty():
		return false
	var located := _find_card(_dragging_card_uid)
	if located.is_empty():
		return false
	var zone := str(located.get("zone", ""))
	return zone == "board" or zone == "master" or zone == "artifact"


func _dragging_card_type() -> String:
	if _dragging_card_uid == "":
		return ""
	var located := _find_card(_dragging_card_uid)
	if located.is_empty():
		return ""
	var card: Dictionary = located["card"]
	var definition: Dictionary = card.get("definition", {})
	return str(definition.get("type", ""))


func _on_draw_pressed() -> void:
	_push_log("当前牌桌已改为规则核驱动，抽牌由阶段流程自动处理。")
	_refresh()


func _on_end_turn_pressed() -> void:
	if _game_over:
		return
	var input_player := _current_local_input_player()
	if input_player < 0:
		_push_log("当前不是你的回合。")
		_refresh()
		return
	if _state != null and not _state.pending_choices.is_empty():
		_push_log("当前仍有待完成的选择，不能结束回合。")
		_refresh()
		return
	_selected_attacker_uid = ""
	var active_player_before := _logical_player_for_display(_active_player)
	if not _execute_command(input_player, "EndPhase", {}):
		return
	if _network_mode_active:
		return
	while not _game_over and _state != null and _state.pending_choices.is_empty() and _state.stack.is_empty() and _state.pending_attack.is_empty():
		if _state.phase == "main" and int(_state.active_player) != active_player_before:
			break
		if _find_action(_player_actions(_current_input_player()), "end_phase").is_empty():
			break
		if not _execute_command(_current_input_player(), "EndPhase", {}):
			break


func _host_continue_end_phase_sequence(_initial_player_id: int, command_index: int) -> void:
	if not _network_is_host or _state == null:
		return
	var step_index := command_index
	while not _game_over and _state != null and _state.pending_choices.is_empty() and _state.stack.is_empty() and _state.pending_attack.is_empty():
		if _state.phase == "main":
			break
		var active_player_id := int(_state.active_player)
		var active_actions: Array = _engine.get_legal_actions(_state, active_player_id)
		if _find_action(active_actions, "end_phase").is_empty():
			break
		step_index += 1
		if not _execute_command_locally(active_player_id, "EndPhase", {}, true, true, REFRESH_MODE_DEFERRED):
			break
		var expected_hash := _state_hash_with_profile("hash/host_end_phase")
		_network_session.broadcast_applied_command(active_player_id, "EndPhase", {}, expected_hash, step_index)


func _push_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 6:
		_log_lines.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)
	_append_file_log("[EVENT] %s" % line)


func _initialize_duel_log(duel_label: String, duel_path: String) -> void:
	_duel_log_path = ""
	_ai_raw_log_path = ""
	var absolute_dir := ProjectSettings.globalize_path(BATTLE_LOG_DIR)
	var dir_result := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_result != OK:
		return
	var opened_at := int(Time.get_unix_time_from_system())
	var file_name := "duel_%s_%s.log" % [str(opened_at), duel_label.replace(" ", "_")]
	var ai_file_name := "ai_%s_%s.log" % [str(opened_at), duel_label.replace(" ", "_")]
	_duel_log_path = "%s/%s" % [BATTLE_LOG_DIR, file_name]
	var file := FileAccess.open(_duel_log_path, FileAccess.WRITE)
	if file == null:
		_duel_log_path = ""
		return
	file.store_line("== 十二军团对局日志 ==")
	file.store_line("label=%s" % duel_label)
	file.store_line("deck=%s" % duel_path)
	file.store_line("opened_at=%s" % str(opened_at))
	file.close()
	_ai_raw_log_path = "%s/%s" % [BATTLE_LOG_DIR, ai_file_name]
	var ai_file := FileAccess.open(_ai_raw_log_path, FileAccess.WRITE)
	if ai_file == null:
		_ai_raw_log_path = ""
		return
	ai_file.store_line("== 十二军团 AI 原始输出日志 ==")
	ai_file.store_line("label=%s" % duel_label)
	ai_file.store_line("deck=%s" % duel_path)
	ai_file.store_line("opened_at=%s" % str(opened_at))
	ai_file.close()


func _append_file_log(line: String) -> void:
	if _duel_log_path.is_empty():
		return
	_duel_log_buffer.append(line)


func _flush_duel_log_buffer() -> void:
	if not _duel_log_path.is_empty() and not _duel_log_buffer.is_empty():
		var file := FileAccess.open(_duel_log_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
			for line in _duel_log_buffer:
				file.store_line(line)
			file.close()
			_duel_log_buffer.clear()
	_flush_ai_raw_log_buffer()


func _flush_ai_raw_log_buffer() -> void:
	if _ai_raw_log_path.is_empty() or _ai_raw_log_buffer.is_empty():
		return
	var file := FileAccess.open(_ai_raw_log_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	for line in _ai_raw_log_buffer:
		file.store_line(line)
	file.close()
	_ai_raw_log_buffer.clear()


func _map_rect(rect: Rect2) -> Rect2:
	var scale := _axis_scale()
	return Rect2(
		Vector2(rect.position.x * scale.x, rect.position.y * scale.y),
		Vector2(rect.size.x * scale.x, rect.size.y * scale.y)
	)


func _map_table_rect(rect: Rect2) -> Rect2:
	return _map_rect(Rect2(Vector2(rect.position.x, rect.position.y + TABLE_TOP_PAD), rect.size))


func _axis_scale() -> Vector2:
	if size.x <= 0 or size.y <= 0:
		return Vector2.ONE
	return Vector2(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)


func _popup_column_position(column: int, panel_size: Vector2) -> Vector2:
	var total_width := POPUP_LEFT_WIDTH + POPUP_MIDDLE_WIDTH + POPUP_RIGHT_WIDTH + POPUP_GAP * 2.0
	var x := (size.x - total_width) * 0.5
	if column == 1:
		x += POPUP_LEFT_WIDTH + POPUP_GAP
	elif column == 2:
		x += POPUP_LEFT_WIDTH + POPUP_GAP + POPUP_MIDDLE_WIDTH + POPUP_GAP
	var y := (size.y - panel_size.y) * 0.5
	var max_x: float = max(12.0, size.x - panel_size.x - 12.0)
	var max_y: float = max(12.0, size.y - panel_size.y - 12.0)
	return Vector2(clampf(x, 12.0, max_x), clampf(y, 12.0, max_y))


func _popup_below_center_panel(column: int, panel_size: Vector2, above_size: Vector2) -> Vector2:
	var base_position := _popup_column_position(column, panel_size)
	var y := size.y * 0.5 + above_size.y * 0.5 + POPUP_GAP
	var max_y: float = max(12.0, size.y - panel_size.y - 12.0)
	base_position.y = clampf(y, 12.0, max_y)
	return base_position


func _show_overlay_card_preview(card: Control) -> void:
	_hide_overlay_card_preview()
	if card == null:
		return
	var preview_source = card.get("card_data")
	if typeof(preview_source) != TYPE_DICTIONARY:
		return
	_show_overlay_card_preview_from_source(preview_source)


func _show_overlay_card_preview_from_source(preview_source: Dictionary) -> void:
	_hide_overlay_card_preview()
	if preview_source.is_empty():
		return
	var resolved_preview_source := _resolved_overlay_preview_source(preview_source)
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 975
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.04, 0.52)
	overlay.add_child(shade)
	var preview_texture := _load_overlay_preview_texture(resolved_preview_source)
	if preview_texture != null:
		var preview_bounds := Vector2(size.x * 0.84, size.y * 0.84)
		var preview_size := _fit_overlay_preview_size(preview_texture.get_size(), preview_bounds)
		var preview_rect := TextureRect.new()
		preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_rect.texture = preview_texture
		preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_rect.stretch_mode = TextureRect.STRETCH_SCALE
		preview_rect.size = preview_size
		preview_rect.position = Vector2((size.x - preview_size.x) * 0.5, (size.y - preview_size.y) * 0.5)
		overlay.add_child(preview_rect)
	else:
		var preview_size := Vector2(min(420.0, size.x * 0.42), min(588.0, size.y * 0.78))
		var preview_card: Control = BattleCardScript.new()
		preview_card.size = preview_size
		preview_card.custom_minimum_size = preview_size
		preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_card.z_index = 980
		preview_card.setup((resolved_preview_source as Dictionary).duplicate(true), false, false, false)
		preview_card.position = Vector2((size.x - preview_size.x) * 0.5, (size.y - preview_size.y) * 0.5)
		overlay.add_child(preview_card)
	_preview_layer.add_child(overlay)
	_overlay_card_preview = overlay


func _resolved_overlay_preview_source(preview_source: Dictionary) -> Dictionary:
	var resolved := preview_source.duplicate(true)
	if _can_reveal_face_down_overlay_preview(preview_source):
		resolved["face"] = "face_up"
	return resolved


func _can_reveal_face_down_overlay_preview(preview_source: Dictionary) -> bool:
	if str(preview_source.get("face", "face_up")) != "face_down":
		return false
	if not str(preview_source.get("zone", "")).begins_with("battle_"):
		return false
	return _is_locally_controllable_player(int(preview_source.get("owner", -1)))


func _load_overlay_preview_texture(preview_source: Dictionary) -> Texture2D:
	if str(preview_source.get("face", "face_up")) == "face_down":
		return null
	var definition: Dictionary = preview_source.get("definition", {})
	var face_path := str(definition.get("card_face_path", ""))
	if face_path.is_empty():
		face_path = str(definition.get("image_path", ""))
	if face_path.is_empty():
		return null
	return _load_texture_resource(face_path)


func _load_texture_resource(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		var global_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_path):
			var image := Image.load_from_file(global_path)
			if image != null and not image.is_empty():
				texture = ImageTexture.create_from_image(image)
	return texture


func _load_image_from_asset(path: String) -> Image:
	if path.is_empty():
		return null
	var texture := _load_texture_resource(path)
	if texture != null:
		var image := texture.get_image()
		if image != null and not image.is_empty():
			return image
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	var file_image := Image.load_from_file(global_path)
	if file_image == null or file_image.is_empty():
		return null
	return file_image


func _path_has_texture_resource(path: String) -> bool:
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


func _fit_overlay_preview_size(source_size: Vector2, max_size: Vector2) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return max_size
	var scale: float = minf(max_size.x / source_size.x, max_size.y / source_size.y)
	return source_size * scale


func _hide_overlay_card_preview(_card: Control = null) -> void:
	if _overlay_card_preview != null and is_instance_valid(_overlay_card_preview):
		_overlay_card_preview.queue_free()
	_overlay_card_preview = null


func _card_size() -> Vector2:
	var scale := _axis_scale()
	return Vector2(118.0 * scale.x, 165.0 * scale.y)


func _make_label(font_size: int, horizontal: HorizontalAlignment, vertical: VerticalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	var display_text := _button_display_text(text)
	button.text = display_text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.custom_minimum_size = Vector2(0.0, _button_min_height_for_text(display_text))
	button.add_theme_font_size_override("font_size", 13)
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
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.16, 0.20, 0.92)
	hover.border_color = Color(0.66, 0.92, 1.0, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.04, 0.06, 0.08, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _style_settings_button(button: BaseButton, accent: bool = false) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.99, 0.95, 0.84, 1.0) if accent else Color(0.94, 0.97, 1.0, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.15, 0.08, 0.94) if accent else Color(0.07, 0.08, 0.11, 0.84)
	normal.border_color = Color(0.96, 0.82, 0.40, 0.96) if accent else Color(0.78, 0.84, 1.0, 0.52)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.24, 0.19, 0.10, 0.98) if accent else Color(0.12, 0.16, 0.20, 0.92)
	hover.border_color = Color(1.0, 0.89, 0.56, 1.0) if accent else Color(0.66, 0.92, 1.0, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.12, 0.10, 0.06, 1.0) if accent else Color(0.04, 0.06, 0.08, 0.96)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


func _make_settings_surface(bg: Color, border: Color, radius: int, border_width: int = 1, shadow_size: int = 0) -> StyleBoxFlat:
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
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0, 6)
	return style


func _make_settings_header(title: String, description: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.03, 0.05, 0.07, 0.94),
		Color(0.96, 0.82, 0.40, 0.78),
		16,
		2,
		14
	))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var title_alignment := HORIZONTAL_ALIGNMENT_CENTER if description.strip_edges().is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	var title_label := _make_label(22, title_alignment, VERTICAL_ALIGNMENT_CENTER)
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	box.add_child(title_label)
	if not description.strip_edges().is_empty():
		var desc_label := _make_label(13, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		desc_label.text = description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.97, 0.94))
		box.add_child(desc_label)
	return panel


func _make_blurred_backdrop(alpha: float = 0.9) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.4;
uniform vec4 tint_color : source_color = vec4(0.03, 0.05, 0.08, 0.84);

void fragment() {
	vec4 screen = textureLod(screen_texture, SCREEN_UV, blur_lod);
	vec3 mixed = mix(screen.rgb, tint_color.rgb, tint_color.a);
	COLOR = vec4(mixed, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("blur_lod", 2.4)
	material.set_shader_parameter("tint_color", Color(0.03, 0.05, 0.08, alpha))
	backdrop.material = material
	return backdrop


func _make_settings_section(title: String, description: String = "") -> Dictionary:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 8)
	var title_label := _make_label(16, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	wrapper.add_child(title_label)
	if not description.is_empty():
		var desc_label := _make_label(12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		desc_label.text = description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.92, 0.92))
		wrapper.add_child(desc_label)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.04, 0.06, 0.08, 0.86),
		Color(0.74, 0.82, 0.98, 0.24),
		14,
		1,
		8
	))
	wrapper.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	return {"panel": wrapper, "body": body}


func _make_settings_field(title: String, description: String, field: Control) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.06, 0.08, 0.11, 0.92),
		Color(0.74, 0.82, 0.98, 0.18),
		12
	))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title_label := _make_label(13, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	box.add_child(title_label)
	if not description.is_empty():
		var desc_label := _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		desc_label.text = description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.92))
		box.add_child(desc_label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(field)
	return panel


func _style_settings_input(field: Control) -> void:
	if field == null:
		return
	if field is BaseButton:
		_style_settings_button(field, field == _ai_llm_settings_button)
		field.custom_minimum_size = Vector2(field.custom_minimum_size.x, max(field.custom_minimum_size.y, 42.0))
	if field is LineEdit:
		var line_edit := field as LineEdit
		line_edit.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
		line_edit.add_theme_color_override("font_placeholder_color", Color(0.63, 0.69, 0.80, 0.86))
		var normal := _make_settings_surface(Color(0.05, 0.07, 0.10, 0.96), Color(0.74, 0.82, 0.98, 0.24), 10)
		var focus := _make_settings_surface(Color(0.06, 0.09, 0.12, 0.98), Color(0.96, 0.82, 0.40, 0.72), 10, 2)
		line_edit.add_theme_stylebox_override("normal", normal)
		line_edit.add_theme_stylebox_override("focus", focus)
		line_edit.add_theme_stylebox_override("read_only", normal)
		line_edit.custom_minimum_size = Vector2(line_edit.custom_minimum_size.x, max(line_edit.custom_minimum_size.y, 42.0))
	elif field is TextEdit:
		var text_edit := field as TextEdit
		text_edit.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
		text_edit.add_theme_color_override("font_placeholder_color", Color(0.63, 0.69, 0.80, 0.84))
		text_edit.add_theme_color_override("background_color", Color(0.05, 0.07, 0.10, 0.96))
		var normal := _make_settings_surface(Color(0.05, 0.07, 0.10, 0.96), Color(0.74, 0.82, 0.98, 0.24), 12)
		var focus := _make_settings_surface(Color(0.06, 0.09, 0.12, 0.98), Color(0.96, 0.82, 0.40, 0.72), 12, 2)
		text_edit.add_theme_stylebox_override("normal", normal)
		text_edit.add_theme_stylebox_override("focus", focus)
	elif field is OptionButton:
		var option_button := field as OptionButton
		_style_settings_button(option_button, false)
		option_button.custom_minimum_size = Vector2(option_button.custom_minimum_size.x, max(option_button.custom_minimum_size.y, 42.0))


func _style_settings_tabs(tabs: TabContainer) -> void:
	if tabs == null:
		return
	tabs.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.02, 0.04, 0.06, 0.52),
		Color(0.74, 0.82, 0.98, 0.16),
		14
	))
	var tab_bar := tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.add_theme_color_override("font_selected_color", Color(1.0, 0.92, 0.58, 1.0))
	tab_bar.add_theme_color_override("font_unselected_color", Color(0.82, 0.88, 0.96, 0.92))
	tab_bar.add_theme_color_override("font_hovered_color", Color(0.97, 0.98, 1.0, 1.0))
	tab_bar.add_theme_stylebox_override("tab_selected", _make_settings_surface(
		Color(0.16, 0.13, 0.07, 0.98),
		Color(0.96, 0.82, 0.40, 0.96),
		10,
		1
	))
	tab_bar.add_theme_stylebox_override("tab_unselected", _make_settings_surface(
		Color(0.07, 0.08, 0.11, 0.86),
		Color(0.74, 0.82, 0.98, 0.26),
		10,
		1
	))
	tab_bar.add_theme_stylebox_override("tab_hovered", _make_settings_surface(
		Color(0.11, 0.14, 0.18, 0.92),
		Color(0.66, 0.92, 1.0, 0.58),
		10,
		1
	))


func _apply_settings_dialog_theme(dialog: ConfirmationDialog) -> void:
	if dialog == null:
		return
	if dialog.get_ok_button() != null:
		_style_settings_button(dialog.get_ok_button(), true)
		dialog.get_ok_button().custom_minimum_size = Vector2(128, 42)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().visible = true
		dialog.get_cancel_button().text = "返回"
		_style_settings_button(dialog.get_cancel_button(), false)
		dialog.get_cancel_button().custom_minimum_size = Vector2(108, 42)


func _build_startup_notice_dialog() -> void:
	_startup_notice_dialog = PopupPanel.new()
	_startup_notice_dialog.transparent = true
	_startup_notice_dialog.transparent_bg = true
	add_child(_startup_notice_dialog)
	_startup_notice_dialog.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		0
	))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	_startup_notice_dialog.add_child(margin)
	var content_box := VBoxContainer.new()
	content_box.custom_minimum_size = Vector2(420, 0)
	content_box.add_theme_constant_override("separation", 10)
	margin.add_child(content_box)
	var main_panel := PanelContainer.new()
	main_panel.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.03, 0.05, 0.07, 0.96),
		Color(0.96, 0.82, 0.40, 0.82),
		16,
		2,
		12
	))
	content_box.add_child(main_panel)
	var main_margin := MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 18)
	main_margin.add_theme_constant_override("margin_top", 16)
	main_margin.add_theme_constant_override("margin_right", 18)
	main_margin.add_theme_constant_override("margin_bottom", 16)
	main_panel.add_child(main_margin)
	var main_box := VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 8)
	main_margin.add_child(main_box)
	var title_label := _make_label(21, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	title_label.text = "当前版本测试说明"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.66, 1.0))
	main_box.add_child(title_label)
	var desc_label := _make_label(14, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.96))
	desc_label.text = "目前高天原、阿斯加德、通用阵营卡牌已基本测试完成，其他卡牌暂不保证效果完全正确。"
	main_box.add_child(desc_label)
	var tip_panel := PanelContainer.new()
	tip_panel.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.10, 0.12, 0.16, 0.96),
		Color(0.66, 0.92, 1.0, 0.34),
		14,
		1
	))
	main_box.add_child(tip_panel)
	var tip_margin := MarginContainer.new()
	tip_margin.add_theme_constant_override("margin_left", 14)
	tip_margin.add_theme_constant_override("margin_top", 10)
	tip_margin.add_theme_constant_override("margin_right", 14)
	tip_margin.add_theme_constant_override("margin_bottom", 10)
	tip_panel.add_child(tip_margin)
	var tip_box := VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 4)
	tip_margin.add_child(tip_box)
	var tip_title := _make_label(12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	tip_title.text = "功能提示"
	tip_title.add_theme_color_override("font_color", Color(0.68, 0.94, 1.0, 1.0))
	tip_box.add_child(tip_title)
	var tip_desc := _make_label(13, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_desc.add_theme_color_override("font_color", Color(0.86, 0.92, 0.99, 0.94))
	tip_desc.text = "可在系统设置中配置 API，将大模型接入人机对战。"
	tip_box.add_child(tip_desc)
	var action_center := CenterContainer.new()
	main_box.add_child(action_center)
	var confirm_button := Button.new()
	confirm_button.text = "确认"
	_style_settings_button(confirm_button, true)
	confirm_button.custom_minimum_size = Vector2(136, 42)
	confirm_button.add_theme_font_size_override("font_size", 14)
	confirm_button.pressed.connect(_on_startup_notice_confirmed)
	action_center.add_child(confirm_button)


func _maybe_show_startup_notice() -> void:
	if _startup_notice_opened_this_session:
		return
	if not _startup_ready:
		return
	if _start_panel == null or not _start_panel.visible:
		return
	if _startup_notice_dialog == null:
		return
	_startup_notice_opened_this_session = true
	_startup_notice_dialog.popup_centered(Vector2i(430, 286))


func _on_startup_notice_confirmed() -> void:
	_startup_notice_opened_this_session = true
	if _startup_notice_dialog != null:
		_startup_notice_dialog.hide()


func _button_display_text(text: String) -> String:
	return text.replace(" - ", "\n")


func _button_min_height_for_text(text: String) -> float:
	var estimated_lines := 1
	for line in text.split("\n"):
		estimated_lines += max(0, int(ceil(float(line.length()) / 18.0)) - 1)
	return max(34.0, 18.0 + 18.0 * float(estimated_lines))


func _make_panel() -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.07, 0.88)
	style.border_color = Color(0.74, 0.82, 0.98, 0.36)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _on_network_status_changed(text: String) -> void:
	if _network_status_label != null:
		if _network_mode_active and _network_is_host and (_network_session == null or not _network_session.has_remote_peer()):
			_network_status_label.text = _host_waiting_status_text()
		elif _network_mode_active and _network_is_host:
			_network_status_label.text = _host_connected_status_text()
		elif _network_mode_active:
			_network_status_label.text = _join_connected_status_text()
		elif not _network_mode_active and not _network_terminal_message.is_empty():
			_network_status_label.text = _network_terminal_message
		else:
			_network_status_label.text = text
	_push_log(text)


func _on_network_session_changed(active: bool, is_host: bool, local_player_id: int) -> void:
	var was_active := _network_mode_active
	_network_mode_active = active
	_network_is_host = is_host
	_local_player_id = local_player_id
	_refresh_start_panel_network_buttons()
	if not active:
		_pending_network_commands.clear()
		_network_resync_in_progress = false
		_network_resync_started_at_ms = 0
		_network_connect_hint = ""
		_network_remote_formal_deck_selection.clear()
	if was_active and not active:
		if (_state != null or not _players.is_empty()) and not _game_over and _network_terminal_message.is_empty():
			_network_terminal_message = _network_terminal_message_for_reason(NETWORK_TERMINATION_REASON_SESSION_CLOSED)
			_append_file_log("[NET ABORT] code=%s detail=session_changed" % NETWORK_TERMINATION_REASON_SESSION_CLOSED)
		if _state != null or not _players.is_empty():
			_reset_battle_table(true, false, true)
		else:
			_show_start_panel()
	if _network_status_label != null and not active:
		if _network_terminal_message.is_empty():
			_network_status_label.text = "本地模式：可直接开始对局。\n联机模式需要在相同局域网环境。"
		else:
			_network_status_label.text = _network_terminal_message
	elif _network_status_label != null and active and is_host and (_network_session == null or not _network_session.has_remote_peer()):
		_network_status_label.text = _host_waiting_status_text()
	elif _network_status_label != null and active and is_host:
		_network_status_label.text = _host_connected_status_text()
	elif _network_status_label != null and active:
		_network_status_label.text = _join_connected_status_text()
	if active and not is_host and _network_session != null and _network_session.has_remote_peer():
		_broadcast_local_formal_deck_selection()
	_refresh()


func _on_network_remote_peer_changed(peer_count: int) -> void:
	if _network_mode_active and _network_is_host and peer_count == 0 and _state != null and not _game_over:
		_abort_network_duel(NETWORK_TERMINATION_REASON_PEER_DISCONNECTED, "", true)
		return
	if _network_mode_active and _network_is_host and peer_count == 0:
		_network_remote_formal_deck_selection.clear()
	if _network_mode_active and _network_status_label != null:
		if _network_is_host:
			if peer_count == 0:
				_network_status_label.text = _host_waiting_status_text()
			else:
				_network_status_label.text = _host_connected_status_text(peer_count)
		else:
			_network_status_label.text = _join_connected_status_text()


	if _network_mode_active and not _network_is_host and peer_count > 0:
		_broadcast_local_formal_deck_selection()

func _host_waiting_status_text() -> String:
	var base_text := "房主模式：已创建房间，等待对手加入。"
	if _network_connect_hint.is_empty():
		return base_text
	return "%s\n%s" % [base_text, _network_connect_hint]


func _host_connected_status_text(peer_count: int = -1) -> String:
	var resolved_peer_count := peer_count
	if resolved_peer_count < 0 and _network_session != null:
		resolved_peer_count = _network_session.remote_peer_count()
	resolved_peer_count = max(1, resolved_peer_count)
	return "房主模式：已连接 %s 名对手，可开始对局。\n%s" % [resolved_peer_count, _remote_formal_deck_status_text()]


func _remote_formal_deck_status_text() -> String:
	if _network_remote_formal_deck_selection.is_empty():
		return "对方卡组：未检测到，开始正式对局时将默认使用高天原预组。"
	if int(_network_remote_formal_deck_selection.get("protocol_version", -1)) != DeckBuilderStore.NETWORK_DECK_SELECTION_VERSION:
		return "对方卡组：版本不一致，开始正式对局时将默认使用高天原预组。"
	if not bool(_network_remote_formal_deck_selection.get("has_deck", false)):
		return "对方卡组：未设置有效玩家卡组，开始正式对局时将默认使用高天原预组。"
	var remote_deck = _network_remote_formal_deck_selection.get("deck", {})
	if not (remote_deck is Dictionary):
		return "对方卡组：数据异常，开始正式对局时将默认使用高天原预组。"
	var remote_name := str(remote_deck.get("name", "对方玩家卡组")).strip_edges()
	if remote_name.is_empty():
		remote_name = "对方玩家卡组"
	return "对方卡组：已检测到 %s。" % remote_name


func _join_connected_status_text() -> String:
	return "加入房间：已连接房主，等待房主开始对局。\n%s" % _local_formal_deck_sync_status_text()


func _local_formal_deck_sync_status_text() -> String:
	var payload := DeckBuilderStore.build_local_network_player_deck_selection(_card_definitions)
	if not bool(payload.get("has_deck", false)):
		return "我方卡组：未设置有效玩家卡组，房主将可能按默认流程处理。"
	var local_deck = payload.get("deck", {})
	if not (local_deck is Dictionary):
		return "我方卡组：当前同步数据异常，请重新选择玩家卡组。"
	var local_name := str(local_deck.get("name", "玩家卡组")).strip_edges()
	if local_name.is_empty():
		local_name = "玩家卡组"
	return "我方卡组：已同步 %s。" % local_name


func _broadcast_local_formal_deck_selection() -> void:
	if _network_session == null or not _network_mode_active or _network_is_host:
		return
	if not _network_session.has_remote_peer():
		return
	var payload := DeckBuilderStore.build_local_network_player_deck_selection(_card_definitions)
	_network_session.submit_formal_deck_selection(payload)
	if _network_status_label != null:
		_network_status_label.text = _join_connected_status_text()


func _on_network_remote_formal_deck_selection_received(_sender_peer_id: int, payload: Dictionary) -> void:
	if not _network_is_host:
		return
	_network_remote_formal_deck_selection = payload.duplicate(true)
	if _network_status_label != null and _network_mode_active:
		_network_status_label.text = _host_connected_status_text() if _network_session != null and _network_session.has_remote_peer() else _host_waiting_status_text()


func _on_network_opening_prompt_received(payload: Dictionary) -> void:
	if _network_is_host:
		return
	if _opening_session.is_empty():
		_opening_session = {}
	_set_active_opening_prompt(payload)
	_show_opening_overlay(payload)


func _on_network_opening_response_received(_sender_peer_id: int, payload: Dictionary) -> void:
	if not _network_is_host:
		return
	_handle_opening_prompt_response(PLAYER_TOP, payload)


func _on_network_start_duel_received(duel_path: String, game_options: Dictionary, duel_label: String, duel_seed: int) -> void:
	if _network_is_host:
		return
	_hide_opening_overlay()
	_opening_session.clear()
	if game_options is Dictionary and game_options.has("network_host_player_id"):
		var host_player_id := int(game_options.get("network_host_player_id", PLAYER_BOTTOM))
		_local_player_id = PLAYER_TOP if host_player_id == PLAYER_BOTTOM else PLAYER_BOTTOM
	_pending_start_duel_seed = duel_seed
	if _start_panel_desc != null:
		_start_panel_desc.text = "房主已开始对局，正在同步初始化..."
	if game_options is Dictionary and game_options.has("resume_commands"):
		_show_network_sync_overlay("房主已发起联机续战，正在同步并重建局面...")
	call_deferred("_deferred_start_duel", duel_path, game_options, duel_label, duel_seed)


func _on_network_host_command_requested(_sender_peer_id: int, player_id: int, command_type: String, payload: Dictionary, command_index: int) -> void:
	if not _network_is_host:
		return
	_append_file_log("[NET RECV] #%s P%s %s | %s" % [command_index, player_id, command_type, _network_command_summary(command_type, payload)])
	var result := _apply_engine_command(player_id, command_type, payload)
	if not bool(result.get("ok", false)):
		if _sender_peer_id == 1 and _pending_network_commands.has(command_index):
			_pending_network_commands.erase(command_index)
		_sync_from_engine()
		_request_deferred_refresh()
		if _sender_peer_id != 1:
			_network_session.send_command_failed(
				_sender_peer_id,
				command_type,
				command_index,
				str(result.get("error_code", result.get("code", "COMMAND_REJECTED"))),
				str(result.get("message", "host rejected command"))
			)
		return
	if _sender_peer_id == 1 and _pending_network_commands.has(command_index):
		_pending_network_commands.erase(command_index)
	_sync_from_engine()
	_request_deferred_refresh()
	var expected_hash := _state_hash_with_profile("hash/host_apply")
	_network_session.broadcast_applied_command(player_id, command_type, payload, expected_hash, command_index)
	if _network_status_label != null:
		_network_status_label.text = "联机同步成功，最新命令 #%s 已广播。" % command_index
	if _should_auto_continue_turn_flow():
		_host_continue_end_phase_sequence(player_id, command_index)


func _on_network_command_applied_received(player_id: int, command_type: String, payload: Dictionary, expected_hash: String, command_index: int) -> void:
	if _network_is_host:
		return
	_network_resync_in_progress = false
	_network_resync_started_at_ms = 0
	if _pending_network_commands.has(command_index):
		_pending_network_commands.erase(command_index)
	if not _execute_command_locally(player_id, command_type, payload, true, true, REFRESH_MODE_DEFERRED):
		return
	_request_deferred_refresh()
	var local_hash := _state_hash_with_profile("hash/client_apply")
	if local_hash != expected_hash:
		_push_log("联机状态校验失败：本地哈希与房主不一致。")
		if _network_status_label != null:
			_network_status_label.text = "联机异常：命令 #%s 后状态不一致，正在请求重同步。" % command_index
		_begin_network_resync("hash_mismatch", command_index)
		return
	if _network_status_label != null:
		_network_status_label.text = "已同步命令 #%s，状态校验通过。" % command_index


func _on_network_command_failed_received(command_type: String, command_index: int, code: String, message: String) -> void:
	_network_resync_in_progress = false
	_network_resync_started_at_ms = 0
	var pending_info: Dictionary = _pending_network_commands.get(command_index, {})
	if _pending_network_commands.has(command_index):
		_pending_network_commands.erase(command_index)
	var payload_text := ""
	var summary_text := command_type
	if not pending_info.is_empty():
		payload_text = JSON.stringify(pending_info.get("payload", {}))
		summary_text = str(pending_info.get("summary", command_type))
	_push_log("联机命令失败：#%s %s | %s" % [command_index, code, summary_text])
	_append_file_log("[NET FAIL] #%s code=%s message=%s payload=%s" % [command_index, code, message, payload_text])
	if _network_status_label != null:
		_network_status_label.text = _network_terminal_message_for_reason(
			NETWORK_TERMINATION_REASON_HOST_REJECTED_COMMAND,
			"%s (%s)" % [code, message]
		)
	_request_deferred_refresh()


func _on_network_resync_requested(sender_peer_id: int, reason: String, command_index: int) -> void:
	if not _network_is_host or _network_session == null:
		return
	var payload := _build_network_resync_package(reason, command_index)
	_append_file_log("[NET RESYNC] host send reason=%s command=%s" % [reason, str(command_index)])
	_network_session.send_resync_payload(sender_peer_id, payload)


func _on_network_resync_payload_received(payload: Dictionary) -> void:
	if _network_is_host:
		return
	_network_resync_in_progress = false
	_network_resync_started_at_ms = 0
	if not bool(payload.get("ok", false)):
		_abort_network_duel(NETWORK_TERMINATION_REASON_RESYNC_FAILED, "房主未提供有效恢复数据", true)
		return
	var result := _apply_network_resync_package(payload)
	if not bool(result.get("ok", false)):
		_abort_network_duel(NETWORK_TERMINATION_REASON_RESYNC_FAILED, str(result.get("code", "UNKNOWN")), true)
		return
	var command_index := int(result.get("command_index", -1))
	_push_log("联机已通过房主重同步恢复。")
	if _network_status_label != null:
		_network_status_label.text = "联机已恢复同步，当前重建到命令 #%s。" % command_index
	_request_deferred_refresh()


func _state_hash_with_profile(label: String) -> String:
	if _state == null:
		return ""
	var started_at := Time.get_ticks_msec()
	var hash := StateHasher.hash_public_and_private_state(_state)
	_log_slow_perf(label, started_at, NETWORK_HASH_PERF_WARN_MS)
	return hash


func _log_slow_perf(step: String, started_at_ms: int, warn_ms: int = NETWORK_PERF_WARN_MS) -> void:
	var elapsed_ms := Time.get_ticks_msec() - started_at_ms
	if elapsed_ms < warn_ms:
		return
	_append_file_log("[PERF] %s %sms" % [step, str(elapsed_ms)])


func _on_network_watchdog_timeout() -> void:
	if not _network_mode_active:
		return
	var now_ms := Time.get_ticks_msec()
	if _network_resync_in_progress:
		if now_ms - _network_resync_started_at_ms >= NETWORK_RESYNC_TIMEOUT_MS:
			_abort_network_duel(NETWORK_TERMINATION_REASON_RESYNC_TIMEOUT, "", true)
		return
	if _network_is_host or _pending_network_commands.is_empty():
		return
	var oldest_command_index := _oldest_pending_network_command_index()
	if oldest_command_index < 0:
		return
	var pending_info: Dictionary = _pending_network_commands.get(oldest_command_index, {})
	var sent_at := int(pending_info.get("sent_at_ms", 0))
	if sent_at <= 0 or now_ms - sent_at < NETWORK_COMMAND_TIMEOUT_MS:
		return
	_append_file_log("[NET TIMEOUT] #%s %s" % [
		str(oldest_command_index),
		str(pending_info.get("summary", "UNKNOWN"))
	])
	_begin_network_resync("command_timeout", oldest_command_index)


func _on_ai_mode_selected(index: int) -> void:
	_ai_mode = index
	_ai_override_players.clear()
	_update_ai_mode_controls()
	_persist_ui_runtime_settings()


func _on_ai_llm_toggled(button_pressed: bool) -> void:
	_ai_use_llm = button_pressed
	_apply_ai_policy_mode({
		"ai_policy_mode": _current_requested_ai_policy_mode(),
		"ai_use_llm": _ai_use_llm
	})
	_persist_ui_runtime_settings()


func _on_ai_llm_settings_pressed() -> void:
	if _system_settings_tabs != null:
		_system_settings_tabs.current_tab = 2


func _on_system_settings_pressed() -> void:
	_open_system_settings_view()


func _open_system_settings_view() -> void:
	_load_llm_runtime_settings()
	_refresh_system_settings_dialog()
	if _start_panel != null:
		_start_panel.visible = false
	if _system_settings_tabs != null:
		_system_settings_tabs.current_tab = 0
	if _system_settings_view != null:
		_system_settings_view.visible = true
		_system_settings_view.move_to_front()


func _close_system_settings_view() -> void:
	_load_llm_runtime_settings()
	if _system_settings_view != null:
		_system_settings_view.visible = false
	if _start_panel != null:
		_start_panel.visible = true
	if _start_panel != null and _start_panel.visible and _start_panel_desc != null and _network_terminal_message.is_empty():
		_start_panel_desc.text = _default_start_panel_desc_text()


func _show_join_address_dialog() -> void:
	if _join_address_dialog == null:
		return
	_join_address_dialog.visible = true
	_join_address_dialog.move_to_front()
	if _join_address_prompt_edit != null:
		_join_address_prompt_edit.grab_focus()
		_join_address_prompt_edit.caret_column = _join_address_prompt_edit.text.length()


func _hide_join_address_dialog() -> void:
	if _join_address_dialog != null:
		_join_address_dialog.visible = false


func _build_join_address_dialog() -> void:
	_join_address_dialog = Control.new()
	_join_address_dialog.visible = false
	_join_address_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_join_address_dialog.z_index = 995
	_join_address_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_join_address_dialog)
	var backdrop := _make_blurred_backdrop(0.74)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_join_address_dialog()
	)
	_join_address_dialog.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_join_address_dialog.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(456, 0)
	card.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.04, 0.06, 0.08, 0.98),
		Color(0.96, 0.82, 0.40, 0.52),
		20,
		2,
		20
	))
	center.add_child(card)
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 18)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_right", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	card.add_child(outer)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(420, 0)
	root.add_theme_constant_override("separation", 14)
	outer.add_child(root)
	root.add_child(_make_settings_header(
		"加入房间",
		""
	))
	_join_address_prompt_edit = LineEdit.new()
	_join_address_prompt_edit.placeholder_text = "例如 192.168.1.23"
	_join_address_prompt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_address_prompt_edit.text_submitted.connect(func(_text: String) -> void:
		_on_join_address_confirmed()
	)
	_style_settings_input(_join_address_prompt_edit)
	root.add_child(_make_settings_field(
		"房主地址",
		"只输入 IP 即可，端口会按当前联机逻辑自动处理。",
		_join_address_prompt_edit
	))
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 10)
	root.add_child(action_row)
	_join_address_back_button = _make_button("取消")
	_join_address_back_button.custom_minimum_size = Vector2(104, 42)
	_style_settings_button(_join_address_back_button, false)
	_join_address_back_button.pressed.connect(_hide_join_address_dialog)
	action_row.add_child(_join_address_back_button)
	_join_address_confirm_button = _make_button("连接房间")
	_join_address_confirm_button.custom_minimum_size = Vector2(128, 42)
	_style_settings_button(_join_address_confirm_button, true)
	_join_address_confirm_button.pressed.connect(_on_join_address_confirmed)
	action_row.add_child(_join_address_confirm_button)


func _current_requested_ai_policy_mode() -> String:
	return AI_POLICY_MODE_LLM if _ai_use_llm else AI_POLICY_MODE_SCRIPTED


func _decorate_game_options_with_ai_mode(base_game_options: Dictionary) -> Dictionary:
	var resolved_options := base_game_options.duplicate(true)
	resolved_options["battle_mode"] = _battle_mode
	resolved_options["ai_policy_mode"] = _current_requested_ai_policy_mode()
	resolved_options["ai_use_llm"] = _ai_use_llm
	var provider_name := _selected_llm_provider_name()
	var provider_settings := _resolved_llm_settings_for_provider(provider_name)
	resolved_options["llm_provider"] = provider_name
	resolved_options["llm_api_key"] = str(provider_settings.get("api_key", "")).strip_edges()
	resolved_options["llm_base_url"] = str(provider_settings.get("base_url", "")).strip_edges()
	resolved_options["llm_model"] = str(provider_settings.get("model", "")).strip_edges()
	resolved_options["llm_runtime_mode"] = str(provider_settings.get("runtime_mode", "stable")).strip_edges().to_lower()
	resolved_options["llm_timeout_seconds"] = float(provider_settings.get("timeout_seconds", 20.0))
	resolved_options["llm_use_external_helper"] = bool(provider_settings.get("use_external_helper", true))
	resolved_options["llm_enable_thinking"] = bool(provider_settings.get("enable_thinking", false))
	resolved_options["llm_response_max_tokens"] = int(provider_settings.get("response_max_tokens", 512))
	resolved_options["llm_max_retries"] = int(provider_settings.get("max_retries", 2))
	resolved_options["llm_retry_delay_ms"] = int(provider_settings.get("retry_delay_ms", 1200))
	return resolved_options


func _apply_ai_policy_mode(game_options: Dictionary) -> void:
	var requested_mode := str(game_options.get("ai_policy_mode", ""))
	if requested_mode.is_empty():
		requested_mode = AI_POLICY_MODE_LLM if bool(game_options.get("ai_use_llm", _ai_use_llm)) else AI_POLICY_MODE_SCRIPTED
	_ai_use_llm = requested_mode == AI_POLICY_MODE_LLM
	if _ai_llm_toggle != null and _ai_llm_toggle.button_pressed != _ai_use_llm:
		_ai_llm_toggle.button_pressed = _ai_use_llm
	_update_ai_mode_controls()
	if _ai_controller != null:
		var policy_options := {
			"enabled": requested_mode == AI_POLICY_MODE_LLM
		}
		if requested_mode == AI_POLICY_MODE_LLM:
			var llm_client = _build_runtime_llm_client(game_options)
			if llm_client != null:
				policy_options["llm_client"] = llm_client
				_ai_controller.set_llm_client(llm_client)
			else:
				_ai_controller.set_llm_client(null)
		_ai_controller.set_policy_mode(requested_mode, policy_options)

func _build_runtime_llm_client(game_options: Dictionary):
	var registry := LlmProviderRegistry.new()
	var resolved: Dictionary = registry.resolve_runtime_options(game_options)
	if str(resolved.get("api_key", "")).is_empty():
		return null
	var client := OpenAICompatibleLlmClient.new()
	client.configure(resolved)
	return client


func _build_system_settings_dialog() -> void:
	_system_settings_view = Control.new()
	_system_settings_view.visible = false
	_system_settings_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_system_settings_view.z_index = 990
	_system_settings_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_system_settings_view)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_system_settings_view.add_child(backdrop)
	var shell := PanelContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 14
	shell.offset_top = 14
	shell.offset_right = -14
	shell.offset_bottom = -14
	shell.add_theme_stylebox_override("panel", _make_settings_surface(
		Color(0.03, 0.05, 0.07, 0.98),
		Color(0.74, 0.82, 0.98, 0.24),
		18,
		1,
		16
	))
	_system_settings_view.add_child(shell)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	shell.add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var header_left := VBoxContainer.new()
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_left.add_theme_constant_override("separation", 6)
	header.add_child(header_left)
	var title := _make_label(24, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	title.text = "系统设置"
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	header_left.add_child(title)
	var header_actions := VBoxContainer.new()
	header_actions.add_theme_constant_override("separation", 8)
	header.add_child(header_actions)
	_system_settings_save_button = _make_button("保存")
	_system_settings_save_button.custom_minimum_size = Vector2(112, 42)
	_style_settings_button(_system_settings_save_button, true)
	_system_settings_save_button.pressed.connect(_on_system_settings_confirmed)
	header_actions.add_child(_system_settings_save_button)
	_system_settings_back_button = _make_button("返回")
	_system_settings_back_button.custom_minimum_size = Vector2(112, 42)
	_style_settings_button(_system_settings_back_button, false)
	_system_settings_back_button.pressed.connect(_close_system_settings_view)
	header_actions.add_child(_system_settings_back_button)
	_system_settings_tabs = TabContainer.new()
	_system_settings_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_settings_tabs(_system_settings_tabs)
	root.add_child(_system_settings_tabs)
	var battle_scroll := ScrollContainer.new()
	battle_scroll.name = "对战设置"
	battle_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_system_settings_tabs.add_child(battle_scroll)
	var battle_tab := VBoxContainer.new()
	battle_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_tab.custom_minimum_size = Vector2(0, 420)
	battle_tab.add_theme_constant_override("separation", 12)
	battle_scroll.add_child(battle_tab)
	var battle_section := _make_settings_section("对战流程")
	battle_tab.add_child(battle_section["panel"])
	var battle_body: VBoxContainer = battle_section["body"]
	_battle_mode_option = OptionButton.new()
	_battle_mode_option.add_item("赛制模式", 0)
	_battle_mode_option.add_item("快速模式", 1)
	_battle_mode_option.item_selected.connect(_on_battle_mode_selected)
	_style_settings_input(_battle_mode_option)
	battle_body.add_child(_make_settings_field(
		"模式选择",
		"快速模式使用当前直接开局流程；赛制模式会加入天灾禁选与构筑式开局步骤。",
		_battle_mode_option
	))
	var ai_scroll := ScrollContainer.new()
	ai_scroll.name = "人机设置"
	ai_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_system_settings_tabs.add_child(ai_scroll)
	var ai_tab := VBoxContainer.new()
	ai_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_tab.custom_minimum_size = Vector2(0, 560)
	ai_tab.add_theme_constant_override("separation", 12)
	ai_scroll.add_child(ai_tab)
	var duel_section := _make_settings_section("对局模式", "控制默认的 AI 参与方式与决策引擎。")
	ai_tab.add_child(duel_section["panel"])
	var duel_body: VBoxContainer = duel_section["body"]
	_ai_mode_option = OptionButton.new()
	_ai_mode_option.custom_minimum_size = Vector2(160, 40)
	_ai_mode_option.add_item("无人机", 0)
	_ai_mode_option.add_item("对战人机", 1)
	_ai_mode_option.add_item("双方人机", 2)
	_ai_mode_option.selected = _ai_mode
	_ai_mode_option.item_selected.connect(_on_ai_mode_selected)
	_style_settings_input(_ai_mode_option)
	duel_body.add_child(_make_settings_field(
		"人机模式",
		"",
		_ai_mode_option
	))
	_ai_llm_toggle = CheckBox.new()
	_ai_llm_toggle.text = "接入大模型"
	_ai_llm_toggle.button_pressed = _ai_use_llm
	_ai_llm_toggle.tooltip_text = "启用 LLM 决策链；若当前未配置客户端，将自动回退到脚本 AI"
	_ai_llm_toggle.toggled.connect(_on_ai_llm_toggled)
	_style_settings_input(_ai_llm_toggle)
	duel_body.add_child(_make_settings_field(
		"决策引擎",
		"启用后优先使用大模型决策，未完成配置时会自动回退到脚本 AI。",
		_ai_llm_toggle
	))
	var api_section := _make_settings_section("API配置")
	ai_tab.add_child(api_section["panel"])
	var api_body: VBoxContainer = api_section["body"]
	_llm_provider_option = OptionButton.new()
	_llm_provider_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_llm_provider_option.item_selected.connect(_on_llm_provider_selected)
	_style_settings_input(_llm_provider_option)
	api_body.add_child(_make_settings_field("Provider", "选择当前要编辑的模型服务商。", _llm_provider_option))
	_llm_api_key_edit = LineEdit.new()
	_llm_api_key_edit.placeholder_text = "sk-..."
	_llm_api_key_edit.secret = true
	_llm_api_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_settings_input(_llm_api_key_edit)
	api_body.add_child(_make_settings_field("API Key", "可留空，此时会继续尝试读取环境变量中的密钥。", _llm_api_key_edit))
	_llm_base_url_edit = LineEdit.new()
	_llm_base_url_edit.placeholder_text = "https://api.deepseek.com"
	_llm_base_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_settings_input(_llm_base_url_edit)
	api_body.add_child(_make_settings_field("Base URL", "通常使用 Provider 默认地址；只有自定义网关时才需要修改。", _llm_base_url_edit))
	_llm_model_edit = LineEdit.new()
	_llm_model_edit.placeholder_text = "deepseek-v4-flash"
	_llm_model_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_settings_input(_llm_model_edit)
	api_body.add_child(_make_settings_field("模型", "填写接口实际使用的模型名。", _llm_model_edit))
	api_body.add_child(_make_settings_field("请求模式", "快速模式：少重试、低输出、优先响应。稳定模式：保留重试、容错更强、速度更慢。", _build_llm_runtime_mode_field()))
	_llm_timeout_edit = LineEdit.new()
	_llm_timeout_edit.placeholder_text = "20"
	_llm_timeout_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_settings_input(_llm_timeout_edit)
	api_body.add_child(_make_settings_field("超时（秒）", "请求超时下限为 5 秒，建议保留在 20 秒左右。", _llm_timeout_edit))
	_llm_enable_thinking_toggle = CheckBox.new()
	_llm_enable_thinking_toggle.text = "开启思考"
	_style_settings_input(_llm_enable_thinking_toggle)
	api_body.add_child(_make_settings_field("思考模式", "开启后会向支持推理的模型请求更充分的内部思考。", _llm_enable_thinking_toggle))
	api_body.add_child(_make_settings_field("最大输出", "控制模型单次响应的输出预算；可直接选择常用档位，也可手动输入自定义值。", _build_llm_max_output_field()))
	var prompt_scroll := ScrollContainer.new()
	prompt_scroll.name = "AI提示词"
	prompt_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_system_settings_tabs.add_child(prompt_scroll)
	var prompt_tab := VBoxContainer.new()
	prompt_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_tab.custom_minimum_size = Vector2(0, 560)
	prompt_tab.add_theme_constant_override("separation", 12)
	prompt_scroll.add_child(prompt_tab)
	var prompt_section := _make_settings_section(
		"AI 提示词",
		"这里填写的内容会在开局时发送给模型。发送顺序为：规则原文、知识库卡牌信息、这里的 AI 提示词、再到逐步对局信息。"
	)
	prompt_tab.add_child(prompt_section["panel"])
	var prompt_body: VBoxContainer = prompt_section["body"]
	_ai_prompt_edit = TextEdit.new()
	_ai_prompt_edit.custom_minimum_size = Vector2(0, 320)
	_ai_prompt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_prompt_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ai_prompt_edit.placeholder_text = "例如：优先保证出牌合法性；有确定斩杀时不要保守；无法确定时先解释你的判断。"
	_style_settings_input(_ai_prompt_edit)
	prompt_body.add_child(_ai_prompt_edit)
	_refresh_system_settings_dialog()


func _build_llm_settings_dialog() -> void:
	_llm_settings_dialog = ConfirmationDialog.new()
	_llm_settings_dialog.title = "LLM API 设置"
	_llm_settings_dialog.exclusive = false
	_llm_settings_dialog.confirmed.connect(_on_llm_settings_confirmed)
	_llm_settings_dialog.canceled.connect(func() -> void:
		_load_llm_runtime_settings()
		_llm_settings_dialog.hide()
	)
	_llm_settings_dialog.close_requested.connect(func() -> void:
		_load_llm_runtime_settings()
		_llm_settings_dialog.hide()
	)
	_llm_settings_dialog.min_size = Vector2i(500, 0)
	add_child(_llm_settings_dialog)
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 14)
	outer.add_theme_constant_override("margin_top", 14)
	outer.add_theme_constant_override("margin_right", 14)
	outer.add_theme_constant_override("margin_bottom", 14)
	_llm_settings_dialog.add_child(outer)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(452, 0)
	root.add_theme_constant_override("separation", 12)
	outer.add_child(root)
	root.add_child(_make_settings_header(
		"LLM API 设置",
		"填写 Provider、API Key、Base URL、模型和超时秒数。API Key 留空时仍会继续尝试读取环境变量。"
	))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(452, 0)
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var form_section := _make_settings_section("连接参数", "建议只修改你正在使用的 Provider；未填写项会沿用该 Provider 的默认预设。")
	content.add_child(form_section["panel"])
	var form_body: VBoxContainer = form_section["body"]
	_llm_provider_option = OptionButton.new()
	_llm_provider_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_llm_provider_option.item_selected.connect(_on_llm_provider_selected)
	_style_settings_input(_llm_provider_option)
	form_body.add_child(_make_settings_field("Provider", "选择当前要编辑的模型服务商。", _llm_provider_option))
	_llm_api_key_edit = LineEdit.new()
	_llm_api_key_edit.placeholder_text = "sk-..."
	_llm_api_key_edit.secret = true
	_llm_api_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_settings_input(_llm_api_key_edit)
	form_body.add_child(_make_settings_field("API Key", "可留空，此时会继续尝试读取环境变量中的密钥。", _llm_api_key_edit))
	_llm_base_url_edit = LineEdit.new()
	_llm_base_url_edit.placeholder_text = "https://api.deepseek.com"
	_llm_base_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_settings_input(_llm_base_url_edit)
	form_body.add_child(_make_settings_field("Base URL", "通常使用 Provider 默认地址；只有自定义网关时才需要修改。", _llm_base_url_edit))
	_llm_model_edit = LineEdit.new()
	_llm_model_edit.placeholder_text = "deepseek-v4-flash"
	_llm_model_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_settings_input(_llm_model_edit)
	form_body.add_child(_make_settings_field("模型", "填写接口实际使用的模型名。", _llm_model_edit))
	form_body.add_child(_make_settings_field("请求模式", "快速模式：少重试、低输出、优先响应。稳定模式：保留重试、容错更强、速度更慢。", _build_llm_runtime_mode_field()))
	_llm_timeout_edit = LineEdit.new()
	_llm_timeout_edit.placeholder_text = "20"
	_llm_timeout_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_settings_input(_llm_timeout_edit)
	form_body.add_child(_make_settings_field("超时（秒）", "请求超时下限为 5 秒，建议保留在 20 秒左右。", _llm_timeout_edit))
	_llm_enable_thinking_toggle = CheckBox.new()
	_llm_enable_thinking_toggle.text = "开启思考"
	_style_settings_input(_llm_enable_thinking_toggle)
	form_body.add_child(_make_settings_field("思考模式", "开启后会向支持推理的模型请求更充分的内部思考。", _llm_enable_thinking_toggle))
	form_body.add_child(_make_settings_field("最大输出", "控制模型单次响应的输出预算；可直接选择常用档位，也可手动输入自定义值。", _build_llm_max_output_field()))
	if _llm_settings_dialog.get_ok_button() != null:
		_llm_settings_dialog.get_ok_button().text = "保存"
	_apply_settings_dialog_theme(_llm_settings_dialog)
	_refresh_llm_settings_dialog()


func _refresh_llm_settings_dialog() -> void:
	if _llm_provider_option == null:
		return
	var registry := LlmProviderRegistry.new()
	var providers := registry.get_supported_providers()
	var selected_provider := _selected_llm_provider_name()
	_llm_provider_option.clear()
	var selected_index := 0
	for provider in providers:
		var option_index := _llm_provider_option.get_item_count()
		_llm_provider_option.add_item(_display_llm_provider_name(provider))
		_llm_provider_option.set_item_metadata(option_index, provider)
		if provider == selected_provider:
			selected_index = option_index
	_llm_provider_option.select(selected_index)
	_llm_settings_editing_provider = selected_provider
	_fill_llm_settings_fields(selected_provider)


func _refresh_system_settings_dialog() -> void:
	if _battle_mode_option != null:
		_battle_mode_option.select(0 if _battle_mode == BATTLE_MODE_MATCH else 1)
	if _ai_mode_option != null and _ai_mode_option.selected != _ai_mode:
		_ai_mode_option.select(_ai_mode)
	if _ai_llm_toggle != null and _ai_llm_toggle.button_pressed != _ai_use_llm:
		_ai_llm_toggle.button_pressed = _ai_use_llm
	if _ai_prompt_edit != null:
		_ai_prompt_edit.text = _current_ai_prompt_text()
	_refresh_llm_settings_dialog()
	_update_ai_mode_controls()


func _on_llm_provider_selected(index: int) -> void:
	if _llm_provider_option == null or index < 0:
		return
	_capture_current_llm_provider_settings(_llm_settings_editing_provider)
	var provider_name := str(_llm_provider_option.get_item_metadata(index)).strip_edges().to_lower()
	if provider_name.is_empty():
		provider_name = "deepseek"
	_llm_settings_editing_provider = provider_name
	_llm_runtime_settings["default_provider"] = provider_name
	_fill_llm_settings_fields(provider_name)


func _capture_current_llm_provider_settings(provider_name: String) -> void:
	var normalized_provider := provider_name.strip_edges().to_lower()
	if normalized_provider.is_empty():
		return
	var registry := LlmProviderRegistry.new()
	var settings := _llm_runtime_settings.duplicate(true)
	if settings.is_empty():
		settings = {}
	var providers = settings.get("providers", {})
	if not (providers is Dictionary):
		providers = {}
	var provider_settings = providers.get(normalized_provider, {})
	if not (provider_settings is Dictionary):
		provider_settings = {}
	var preset := registry.get_preset(normalized_provider)
	var runtime_mode := _selected_llm_runtime_mode()
	var runtime_defaults := registry.get_runtime_mode_defaults(normalized_provider, runtime_mode)
	provider_settings["runtime_mode"] = runtime_mode
	provider_settings["api_key"] = _llm_api_key_edit.text.strip_edges() if _llm_api_key_edit != null else str(provider_settings.get("api_key", ""))
	provider_settings["base_url"] = _llm_base_url_edit.text.strip_edges() if _llm_base_url_edit != null else str(provider_settings.get("base_url", preset.get("base_url", "")))
	provider_settings["model"] = _llm_model_edit.text.strip_edges() if _llm_model_edit != null else str(provider_settings.get("model", preset.get("model", "")))
	var timeout_default := float(provider_settings.get("timeout_seconds", runtime_defaults.get("timeout_seconds", preset.get("timeout_seconds", 20.0))))
	provider_settings["timeout_seconds"] = _parse_llm_timeout_value(_llm_timeout_edit.text if _llm_timeout_edit != null else "", timeout_default)
	provider_settings["enable_thinking"] = _llm_enable_thinking_toggle.button_pressed if _llm_enable_thinking_toggle != null else bool(provider_settings.get("enable_thinking", runtime_defaults.get("enable_thinking", preset.get("enable_thinking", false))))
	var max_tokens_default := int(provider_settings.get("response_max_tokens", provider_settings.get("max_tokens", runtime_defaults.get("response_max_tokens", preset.get("response_max_tokens", 512)))))
	provider_settings["response_max_tokens"] = _parse_llm_max_tokens_value(_llm_response_max_tokens_edit.text if _llm_response_max_tokens_edit != null else "", max_tokens_default)
	provider_settings["max_retries"] = int(runtime_defaults.get("max_retries", provider_settings.get("max_retries", 2)))
	provider_settings["retry_delay_ms"] = int(runtime_defaults.get("retry_delay_ms", provider_settings.get("retry_delay_ms", 1200)))
	if str(provider_settings.get("api_key_env", "")).is_empty():
		provider_settings["api_key_env"] = str(preset.get("api_key_env", "")).strip_edges()
	if not provider_settings.has("use_external_helper"):
		provider_settings["use_external_helper"] = bool(preset.get("use_external_helper", true))
	if normalized_provider == "deepseek":
		provider_settings["use_external_helper"] = false
	providers[normalized_provider] = provider_settings
	settings["providers"] = providers
	_llm_runtime_settings = settings


func _on_battle_mode_selected(index: int) -> void:
	_battle_mode = BATTLE_MODE_MATCH if index == 0 else BATTLE_MODE_QUICK


func _fill_llm_settings_fields(provider_name: String) -> void:
	var resolved := _resolved_llm_settings_for_provider(provider_name)
	_select_llm_runtime_mode_option(str(resolved.get("runtime_mode", "stable")))
	if _llm_api_key_edit != null:
		_llm_api_key_edit.text = str(resolved.get("api_key", "")).strip_edges()
	if _llm_base_url_edit != null:
		_llm_base_url_edit.text = str(resolved.get("base_url", "")).strip_edges()
	if _llm_model_edit != null:
		_llm_model_edit.text = str(resolved.get("model", "")).strip_edges()
	if _llm_timeout_edit != null:
		_llm_timeout_edit.text = str(resolved.get("timeout_seconds", 20.0))
	if _llm_enable_thinking_toggle != null:
		_llm_enable_thinking_toggle.button_pressed = bool(resolved.get("enable_thinking", false))
	if _llm_response_max_tokens_edit != null:
		_llm_response_max_tokens_edit.text = str(resolved.get("response_max_tokens", resolved.get("max_tokens", 512)))
	_sync_llm_max_output_preset_selection()


func _on_llm_settings_confirmed() -> void:
	var provider_name := _selected_llm_provider_name()
	_capture_current_llm_provider_settings(provider_name)
	var settings := _llm_runtime_settings.duplicate(true)
	if settings.is_empty():
		settings = {}
	settings["default_provider"] = provider_name
	_capture_persisted_ui_settings(settings)
	if not _save_runtime_settings(settings, "LLM 设置保存失败"):
		return
	_push_log("LLM 设置已保存：%s" % _display_llm_provider_name(provider_name))
	_apply_ai_policy_mode(_decorate_game_options_with_ai_mode({}))


func _on_system_settings_confirmed() -> void:
	_on_llm_settings_confirmed()
	var settings := _llm_runtime_settings.duplicate(true)
	if settings.is_empty():
		settings = {}
	settings["ai_prompt"] = _ai_prompt_edit.text if _ai_prompt_edit != null else ""
	_capture_persisted_ui_settings(settings)
	if not _save_runtime_settings(settings, "系统设置保存失败"):
		return
	_push_log("系统设置已保存")
	_apply_ai_policy_mode(_decorate_game_options_with_ai_mode({}))
	_close_system_settings_view()


func _load_llm_runtime_settings() -> void:
	var registry := LlmProviderRegistry.new()
	var loaded := registry.load_settings()
	_llm_runtime_settings = loaded.duplicate(true) if loaded is Dictionary else {}
	_llm_settings_editing_provider = ""
	_apply_persisted_ui_settings()


func _apply_persisted_ui_settings() -> void:
	var table_settings = _llm_runtime_settings.get("battle_table", {})
	if not (table_settings is Dictionary):
		return
	var persisted_battle_mode := str(table_settings.get("battle_mode", _battle_mode)).strip_edges().to_lower()
	if persisted_battle_mode == BATTLE_MODE_MATCH:
		_battle_mode = BATTLE_MODE_MATCH
	else:
		_battle_mode = BATTLE_MODE_QUICK
	_ai_mode = clampi(int(table_settings.get("ai_mode", _ai_mode)), 0, 2)
	_ai_use_llm = bool(table_settings.get("ai_use_llm", _ai_use_llm))


func _capture_persisted_ui_settings(settings: Dictionary) -> void:
	settings["battle_table"] = {
		"battle_mode": _battle_mode,
		"ai_mode": _ai_mode,
		"ai_use_llm": _ai_use_llm
	}


func _save_runtime_settings(settings: Dictionary, failure_message: String = "", success_message: String = "") -> bool:
	var registry := LlmProviderRegistry.new()
	if not registry.save_settings(settings):
		if not failure_message.is_empty():
			_push_log(failure_message)
		return false
	_llm_runtime_settings = settings.duplicate(true)
	if not success_message.is_empty():
		_push_log(success_message)
	return true


func _persist_ui_runtime_settings() -> void:
	var settings := _llm_runtime_settings.duplicate(true)
	if settings.is_empty():
		settings = {}
	_capture_persisted_ui_settings(settings)
	_save_runtime_settings(settings)


func _selected_llm_provider_name() -> String:
	if _llm_provider_option != null and _llm_provider_option.selected >= 0 and _llm_provider_option.get_item_count() > 0:
		var provider_name := str(_llm_provider_option.get_item_metadata(_llm_provider_option.selected)).strip_edges().to_lower()
		if not provider_name.is_empty():
			return provider_name
	var provider_name := str(_llm_runtime_settings.get("default_provider", "deepseek")).strip_edges().to_lower()
	return provider_name if not provider_name.is_empty() else "deepseek"


func _resolved_llm_settings_for_provider(provider_name: String) -> Dictionary:
	var registry := LlmProviderRegistry.new()
	var normalized_provider := provider_name.strip_edges().to_lower()
	if normalized_provider.is_empty():
		normalized_provider = "deepseek"
	var resolved := registry.get_preset(normalized_provider)
	var runtime_mode := "stable"
	var providers = _llm_runtime_settings.get("providers", {})
	if providers is Dictionary:
		var stored = providers.get(normalized_provider, {})
		if stored is Dictionary:
			for key in stored.keys():
				resolved[key] = stored.get(key)
			runtime_mode = str(stored.get("runtime_mode", runtime_mode))
	runtime_mode = str(registry.get_runtime_mode_defaults(normalized_provider, runtime_mode).get("runtime_mode", "stable"))
	resolved["runtime_mode"] = runtime_mode
	resolved["provider_name"] = normalized_provider
	return resolved


func _display_llm_provider_name(provider_name: String) -> String:
	var normalized := provider_name.strip_edges().to_lower()
	match normalized:
		"glm":
			return "GLM"
		"openai":
			return "OpenAI"
		"qwen":
			return "Qwen"
		"kimi":
			return "Kimi"
		_:
			return normalized.capitalize()


func _current_ai_prompt_text() -> String:
	return str(_llm_runtime_settings.get("ai_prompt", ""))


func _build_llm_max_output_field() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_llm_response_max_tokens_edit = LineEdit.new()
	_llm_response_max_tokens_edit.placeholder_text = "512"
	_llm_response_max_tokens_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_llm_response_max_tokens_edit.text_changed.connect(_on_llm_response_max_tokens_text_changed)
	_style_settings_input(_llm_response_max_tokens_edit)
	row.add_child(_llm_response_max_tokens_edit)
	_llm_response_max_tokens_preset_option = OptionButton.new()
	_llm_response_max_tokens_preset_option.custom_minimum_size = Vector2(160, 0)
	_llm_response_max_tokens_preset_option.item_selected.connect(_on_llm_response_max_tokens_preset_selected)
	_style_settings_input(_llm_response_max_tokens_preset_option)
	row.add_child(_llm_response_max_tokens_preset_option)
	_populate_llm_max_output_preset_option()
	_sync_llm_max_output_preset_selection()
	return row

func _build_llm_runtime_mode_field() -> Control:
	_llm_runtime_mode_option = OptionButton.new()
	_llm_runtime_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_llm_runtime_mode_option.item_selected.connect(_on_llm_runtime_mode_selected)
	_style_settings_input(_llm_runtime_mode_option)
	_populate_llm_runtime_mode_option()
	_select_llm_runtime_mode_option("stable")
	return _llm_runtime_mode_option

func _populate_llm_runtime_mode_option() -> void:
	if _llm_runtime_mode_option == null:
		return
	_llm_runtime_mode_option.clear()
	for mode_name in ["fast", "stable"]:
		var item_index := _llm_runtime_mode_option.get_item_count()
		_llm_runtime_mode_option.add_item("快速模式" if mode_name == "fast" else "稳定模式")
		_llm_runtime_mode_option.set_item_metadata(item_index, mode_name)

func _select_llm_runtime_mode_option(mode_name: String) -> void:
	if _llm_runtime_mode_option == null:
		return
	var normalized := "fast" if mode_name.strip_edges().to_lower() == "fast" else "stable"
	var matched_index := 0
	for index in range(_llm_runtime_mode_option.get_item_count()):
		if str(_llm_runtime_mode_option.get_item_metadata(index)).strip_edges().to_lower() == normalized:
			matched_index = index
			break
	_llm_runtime_mode_option.set_block_signals(true)
	_llm_runtime_mode_option.select(matched_index)
	_llm_runtime_mode_option.set_block_signals(false)

func _selected_llm_runtime_mode() -> String:
	if _llm_runtime_mode_option != null and _llm_runtime_mode_option.selected >= 0 and _llm_runtime_mode_option.get_item_count() > 0:
		var mode_name := str(_llm_runtime_mode_option.get_item_metadata(_llm_runtime_mode_option.selected)).strip_edges().to_lower()
		if mode_name == "fast":
			return "fast"
	return "stable"

func _on_llm_runtime_mode_selected(index: int) -> void:
	if _llm_runtime_mode_option == null or index < 0:
		return
	var provider_name := _selected_llm_provider_name()
	var registry := LlmProviderRegistry.new()
	var mode_name := str(_llm_runtime_mode_option.get_item_metadata(index)).strip_edges().to_lower()
	var defaults := registry.get_runtime_mode_defaults(provider_name, mode_name)
	if _llm_timeout_edit != null:
		_llm_timeout_edit.text = _format_llm_timeout_text(float(defaults.get("timeout_seconds", 20.0)))
	if _llm_enable_thinking_toggle != null:
		_llm_enable_thinking_toggle.button_pressed = bool(defaults.get("enable_thinking", false))
	if _llm_response_max_tokens_edit != null:
		_llm_response_max_tokens_edit.text = str(int(defaults.get("response_max_tokens", 512)))
	_sync_llm_max_output_preset_selection()


func _populate_llm_max_output_preset_option() -> void:
	if _llm_response_max_tokens_preset_option == null:
		return
	_llm_response_max_tokens_preset_option.clear()
	_llm_response_max_tokens_preset_option.add_item("自定义")
	_llm_response_max_tokens_preset_option.set_item_metadata(0, 0)
	for value in [512, 1024, 1536, 2048, 4096]:
		var item_index := _llm_response_max_tokens_preset_option.get_item_count()
		_llm_response_max_tokens_preset_option.add_item(str(value))
		_llm_response_max_tokens_preset_option.set_item_metadata(item_index, value)


func _on_llm_response_max_tokens_preset_selected(index: int) -> void:
	if _llm_response_max_tokens_preset_option == null or _llm_response_max_tokens_edit == null or index < 0:
		return
	var selected_value := int(_llm_response_max_tokens_preset_option.get_item_metadata(index))
	if selected_value <= 0:
		return
	if _llm_response_max_tokens_edit.text.strip_edges() != str(selected_value):
		_llm_response_max_tokens_edit.text = str(selected_value)


func _on_llm_response_max_tokens_text_changed(_new_text: String) -> void:
	_sync_llm_max_output_preset_selection()


func _sync_llm_max_output_preset_selection() -> void:
	if _llm_response_max_tokens_preset_option == null or _llm_response_max_tokens_edit == null:
		return
	var matched_index := 0
	var trimmed := _llm_response_max_tokens_edit.text.strip_edges()
	if trimmed.is_valid_int():
		var parsed_value := int(trimmed)
		for index in range(_llm_response_max_tokens_preset_option.get_item_count()):
			if int(_llm_response_max_tokens_preset_option.get_item_metadata(index)) == parsed_value:
				matched_index = index
				break
	_llm_response_max_tokens_preset_option.select(matched_index)

func _format_llm_timeout_text(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	if absf(rounded - round(rounded)) < 0.001:
		return str(int(round(rounded)))
	return str(rounded)


func _format_ms(value: float) -> String:
	return "%.1f" % max(0.0, value)


func _format_wait_seconds(value: float) -> String:
	return "%.1f" % max(0.0, value)


func _parse_llm_timeout_value(timeout_text: String, default_value: float) -> float:
	var trimmed := timeout_text.strip_edges()
	if trimmed.is_empty():
		return max(5.0, default_value)
	if not trimmed.is_valid_float():
		return max(5.0, default_value)
	return max(5.0, float(trimmed))


func _parse_llm_max_tokens_value(tokens_text: String, default_value: int) -> int:
	var trimmed := tokens_text.strip_edges()
	if trimmed.is_empty():
		return max(1, default_value)
	if not trimmed.is_valid_int():
		return max(1, default_value)
	return max(1, int(trimmed))


func _update_ai_mode_controls() -> void:
	if _ai_llm_toggle == null:
		return
	var ai_enabled := _ai_mode != 0
	_ai_llm_toggle.disabled = not ai_enabled
	if _ai_llm_settings_button != null:
		_ai_llm_settings_button.disabled = false
	if ai_enabled:
		_ai_llm_toggle.tooltip_text = "启用 LLM 决策链；若当前未配置客户端，将自动回退到脚本 AI"
		return
	_ai_llm_toggle.tooltip_text = "仅在“对战人机”或“双方人机”模式下生效"


func _ai_enabled_for_player(player_id: int) -> bool:
	if not _ai_override_players.is_empty():
		return _ai_override_players.has(player_id)
	if _ai_mode == 2:
		return true
	if _ai_mode == 1:
		return player_id == PLAYER_TOP
	return false


func _trace_ai_timer(reason: String, detail: String = "") -> void:
	if _duel_log_path.is_empty():
		return
	if reason == _ai_trace_last_reason and detail == _ai_trace_last_detail:
		return
	_ai_trace_last_reason = reason
	_ai_trace_last_detail = detail
	_append_file_log("[AI TRACE] %s %s" % [reason, detail])


func _on_ai_timer_timeout() -> void:
	_reap_detached_ai_threads()
	if _state == null:
		_trace_ai_timer("skip/no_state")
		return
	if _game_over:
		_trace_ai_timer("skip/game_over", "winner=%s" % str(_state.winner))
		return
	if _start_panel != null and _start_panel.visible:
		# In headless/UI soak runs, a stale visible start panel can block AI forever
		# even after the duel state has been created successfully.
		_trace_ai_timer("hide/start_panel")
		_hide_start_panel()
	if _network_mode_active or _network_input_locked():
		_trace_ai_timer("skip/network_locked", "mode=%s locked=%s pending=%s resync=%s" % [
			str(_network_mode_active),
			str(_network_input_locked()),
			str(_has_pending_network_command()),
			str(_network_resync_in_progress)
		])
		return
	var now_ms: int = Time.get_ticks_msec()
	var command_count: int = _state.command_log.size()
	if command_count != _ai_stall_last_command_count:
		_ai_stall_last_command_count = command_count
		_ai_stall_last_progress_ms = now_ms
	elif _ai_stall_last_progress_ms == 0:
		_ai_stall_last_progress_ms = now_ms
	_waiting_state = _engine.get_waiting_state(_state)
	_invalidate_action_cache()
	var player_id := _waiting_display_player()
	if player_id < 0 or not _ai_enabled_for_player(player_id):
		_trace_ai_timer("skip/player_not_ai", "waiting=%s display=%s ai_mode=%s" % [
			str(_waiting_state.get("player_id", -1)),
			str(player_id),
			str(_ai_mode)
		])
		if _ai_async_thread != null:
			_detach_pending_ai_thread()
		return
	if now_ms < _ai_blocked_until_ms:
		_trace_ai_timer("skip/blocked", "now=%s until=%s waiting=%s" % [
			str(now_ms),
			str(_ai_blocked_until_ms),
			str(_waiting_state.get("state", ""))
		])
		return
	if _clear_local_interaction_state_for_ai_turn():
		_trace_ai_timer("clear/local_state", "waiting=%s player=%s" % [
			str(_waiting_state.get("state", "")),
			str(player_id)
		])
		_refresh()
	var actions: Array = _player_actions(player_id)
	if actions.is_empty():
		var logical_player_id := _logical_player_for_display(player_id)
		actions = _engine.get_legal_actions(_state, logical_player_id)
		if actions.is_empty():
			_trace_ai_timer("skip/no_actions", "waiting=%s player=%s" % [
				str(_waiting_state.get("state", "")),
				str(logical_player_id)
			])
			return
		if has_method("_append_file_log"):
			_append_file_log("[AI CACHE MISS] use direct engine actions waiting=%s player=%s count=%s" % [
				str(_waiting_state.get("state", "")),
				str(logical_player_id),
				str(actions.size())
			])
	if actions.is_empty():
		_trace_ai_timer("skip/no_actions_after_cache", "waiting=%s player=%s" % [
			str(_waiting_state.get("state", "")),
			str(player_id)
		])
		return
	if _ai_controller == null:
		_trace_ai_timer("skip/no_controller")
		return
	if _ai_async_thread != null:
		if _poll_ai_async_drive(now_ms):
			return
	if _should_run_ai_async(player_id):
		if _start_ai_async_drive(player_id, actions, command_count):
			return
	_trace_ai_timer("drive/attempt", "waiting=%s player=%s actions=%s commands=%s" % [
		str(_waiting_state.get("state", "")),
		str(player_id),
		str(actions.size()),
		str(command_count)
	])
	if _ai_controller.drive_table_step(self, player_id, actions):
		_trace_ai_timer("drive/success", "waiting=%s player=%s actions=%s" % [
			str(_waiting_state.get("state", "")),
			str(player_id),
			str(actions.size())
		])
		_ai_blocked_until_ms = max(_ai_blocked_until_ms, now_ms + 80)
		return
	_trace_ai_timer("drive/no_progress", "waiting=%s player=%s actions=%s" % [
		str(_waiting_state.get("state", "")),
		str(player_id),
		str(actions.size())
	])
	_maybe_force_ai_stall_progress(player_id, actions, now_ms)


func _should_run_ai_async(player_id: int) -> bool:
	if player_id < 0 or _network_mode_active:
		return false
	if not _ai_use_llm or _ai_controller == null:
		return false
	if _ai_controller.has_method("get_policy_mode"):
		return str(_ai_controller.get_policy_mode()) == AiController.POLICY_MODE_LLM
	return false


func _start_ai_async_drive(display_player_id: int, actions: Array, command_count: int) -> bool:
	if _ai_controller == null or _engine == null or _state == null or actions.is_empty():
		return false
	if _ai_async_thread != null:
		return false
	var request := {
		"controller": _ai_controller,
		"engine": _engine,
		"state": _state,
		"display_player_id": display_player_id,
		"logical_player_id": _logical_player_for_display(display_player_id),
		"actions": actions.duplicate(true),
		"command_count": command_count,
		"state_hash": _state_hash_with_profile("hash/ai_async_start"),
		"waiting_state": _waiting_state.duplicate(true)
	}
	var thread := Thread.new()
	var error := thread.start(Callable(self, "_run_ai_async_drive").bind(request))
	if error != OK:
		_trace_ai_timer("drive/async_start_failed", "error=%s player=%s" % [str(error), str(display_player_id)])
		return false
	_ai_async_thread = thread
	_ai_async_started_ms = Time.get_ticks_msec()
	_ai_async_waiting_player = display_player_id
	_ai_async_waiting_state = str(_waiting_state.get("state", ""))
	_ai_async_expected_command_count = command_count
	_ai_async_expected_state_hash = str(request.get("state_hash", ""))
	_ai_async_actions = actions.duplicate(true)
	_trace_ai_timer("drive/async_start", "waiting=%s player=%s actions=%s commands=%s" % [
		str(_waiting_state.get("state", "")),
		str(display_player_id),
		str(actions.size()),
		str(command_count)
	])
	_refresh_busy_status_panel()
	return true


func _run_ai_async_drive(request: Dictionary) -> Dictionary:
	var controller = request.get("controller", null)
	var engine = request.get("engine", null)
	var state = request.get("state", null)
	var logical_player_id := int(request.get("logical_player_id", -1))
	var actions: Array = request.get("actions", []).duplicate(true)
	var started_us := Time.get_ticks_usec()
	var decision: Dictionary = {}
	if controller != null:
		decision = controller.drive_engine_step(engine, state, logical_player_id, actions)
	return {
		"display_player_id": int(request.get("display_player_id", -1)),
		"logical_player_id": logical_player_id,
		"actions": actions.duplicate(true),
		"command_count": int(request.get("command_count", -1)),
		"state_hash": str(request.get("state_hash", "")),
		"waiting_state": request.get("waiting_state", {}).duplicate(true),
		"decision": decision.duplicate(true),
		"elapsed_ms": max(0.0, float(Time.get_ticks_usec() - started_us) / 1000.0)
	}


func _poll_ai_async_drive(now_ms: int) -> bool:
	if _ai_async_thread == null:
		return false
	if _ai_async_thread.is_alive():
		_refresh_busy_status_panel()
		return true
	var result_variant = _ai_async_thread.wait_to_finish()
	_ai_async_thread = null
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var actions: Array = _ai_async_actions.duplicate(true)
	var stale_reason := _ai_async_result_stale_reason(result)
	_clear_ai_async_request_state()
	if not stale_reason.is_empty():
		_trace_ai_timer("drive/async_drop", stale_reason)
		return true
	return _apply_ai_async_result(result, actions, now_ms)


func _ai_async_result_stale_reason(result: Dictionary) -> String:
	if _state == null:
		return "no_state"
	if _game_over:
		return "game_over"
	if _network_mode_active or _network_input_locked():
		return "network_locked"
	if int(result.get("command_count", -1)) != _state.command_log.size():
		return "command_count_changed"
	if str(result.get("state_hash", "")) != _state_hash_with_profile("hash/ai_async_finish"):
		return "state_hash_changed"
	var waiting := _engine.get_waiting_state(_state)
	if int(waiting.get("player_id", -1)) != int(result.get("logical_player_id", -2)):
		return "waiting_player_changed"
	if str(waiting.get("state", "")) != str(result.get("waiting_state", {}).get("state", "")):
		return "waiting_state_changed"
	return ""


func _apply_ai_async_result(result: Dictionary, actions: Array, now_ms: int) -> bool:
	var player_id := int(result.get("display_player_id", -1))
	var decision: Dictionary = result.get("decision", {}).duplicate(true)
	var command_type := str(decision.get("command_type", ""))
	var payload: Dictionary = decision.get("payload", {})
	var decision_elapsed_ms := float(result.get("elapsed_ms", 0.0))
	if decision.is_empty():
		_trace_ai_timer("drive/async_empty", "player=%s elapsed=%sms" % [str(player_id), _format_ms(decision_elapsed_ms)])
		_maybe_force_ai_stall_progress(player_id, actions, now_ms)
		return true
	if not str(decision.get("debug_summary", "")).is_empty():
		_append_file_log(str(decision.get("debug_summary", "")))
	if command_type.is_empty() or (payload.is_empty() and command_type != "PassPriority" and command_type != "EndPhase"):
		_trace_ai_timer("drive/async_invalid", "player=%s elapsed=%sms command=%s" % [
			str(player_id),
			_format_ms(decision_elapsed_ms),
			command_type
		])
		if _ai_controller != null and _ai_controller.has_method("_fallback_table_step"):
			if _ai_controller._fallback_table_step(self, player_id, actions, "async_invalid_decision", command_type, payload, decision):
				_ai_blocked_until_ms = max(_ai_blocked_until_ms, now_ms + 80)
				return true
		_maybe_force_ai_stall_progress(player_id, actions, now_ms)
		return true
	if _execute_command(player_id, command_type, payload):
		_append_ai_raw_log_from_decision(player_id, decision.duplicate(true), {"ok": true})
		_record_ai_decision_status(decision.duplicate(true), {"ok": true})
		if _ai_controller != null and _ai_controller.has_method("record_engine_execution"):
			_ai_controller.record_engine_execution(_engine, _state, decision.duplicate(true), {"ok": true})
		_trace_ai_timer("drive/async_success", "player=%s elapsed=%sms command=%s" % [
			str(player_id),
			_format_ms(decision_elapsed_ms),
			command_type
		])
		_ai_blocked_until_ms = max(_ai_blocked_until_ms, now_ms + 80)
		return true
	_trace_ai_timer("drive/async_failed_execute", "player=%s elapsed=%sms command=%s" % [
		str(player_id),
		_format_ms(decision_elapsed_ms),
		command_type
	])
	if _ai_controller != null and _ai_controller.has_method("_fallback_table_step"):
		if _ai_controller._fallback_table_step(self, player_id, actions, "async_failed_execute", command_type, payload, decision):
			_ai_blocked_until_ms = max(_ai_blocked_until_ms, now_ms + 80)
			return true
	_maybe_force_ai_stall_progress(player_id, actions, now_ms)
	return true


func _clear_ai_async_request_state() -> void:
	_ai_async_started_ms = 0
	_ai_async_waiting_player = -1
	_ai_async_waiting_state = ""
	_ai_async_expected_command_count = -1
	_ai_async_expected_state_hash = ""
	_ai_async_actions.clear()


func _detach_pending_ai_thread() -> void:
	if _ai_async_thread == null:
		_clear_ai_async_request_state()
		return
	if _ai_async_thread.is_alive():
		_ai_async_detached_threads.append(_ai_async_thread)
	else:
		_ai_async_thread.wait_to_finish()
	_ai_async_thread = null
	_clear_ai_async_request_state()


func _reap_detached_ai_threads(wait_all: bool = false) -> void:
	var remaining: Array[Thread] = []
	for thread in _ai_async_detached_threads:
		if thread == null:
			continue
		if wait_all or not thread.is_alive():
			thread.wait_to_finish()
		else:
			remaining.append(thread)
	_ai_async_detached_threads = remaining


func _wait_for_ai_threads_on_exit() -> void:
	_reap_detached_ai_threads(true)
	if _ai_async_thread != null:
		_ai_async_thread.wait_to_finish()
	_ai_async_thread = null
	_clear_ai_async_request_state()


func _is_ai_async_in_flight() -> bool:
	return _ai_async_thread != null


func _ai_async_elapsed_ms() -> int:
	if _ai_async_started_ms <= 0:
		return 0
	return max(0, Time.get_ticks_msec() - _ai_async_started_ms)


func _maybe_force_ai_stall_progress(player_id: int, actions: Array, now_ms: int) -> bool:
	if _state == null or _game_over or player_id < 0:
		return false
	if now_ms - _ai_stall_last_progress_ms < AI_STALL_THRESHOLD_MS:
		return false
	if now_ms - _ai_stall_last_force_ms < AI_STALL_FORCE_COOLDOWN_MS:
		return false
	var waiting_state := str(_waiting_state.get("state", ""))
	if waiting_state != "WaitingForPriority" and waiting_state != "WaitingForAction":
		return false
	for action in actions:
		var kind := str(action.get("kind", ""))
		if waiting_state == "WaitingForPriority" and kind != "pass_priority":
			continue
		if waiting_state == "WaitingForAction" and kind != "end_phase":
			continue
		_ai_stall_last_force_ms = now_ms
		if has_method("_append_file_log"):
			_append_file_log("[AI STALL] force %s after %s ms waiting=%s" % [
				kind,
				str(now_ms - _ai_stall_last_progress_ms),
				waiting_state
			])
		var fallback_command_type := "PassPriority" if waiting_state == "WaitingForPriority" else "EndPhase"
		if _execute_command(player_id, str(action.get("command_type", fallback_command_type)), action.get("payload_template", {})):
			_ai_blocked_until_ms = max(_ai_blocked_until_ms, now_ms + 80)
			return true
		return false
	return false
