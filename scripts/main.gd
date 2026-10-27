class_name HobbitMain
extends Control

# Режимы игры
enum Mode { MODERN = 0, VGA = 1, ZX = 2 }

# Основные ссылки на интерфейс игры
@onready var output_log: RichTextLabel = %OutputLog
@onready var input_line: LineEdit = %InputLine
@onready var command_dropdown: OptionButton = %CommandDropdown
@onready var loc_title: Label = %LocationTitle
@onready var loc_sub: Label = %LocationSub
@onready var status_info: Label = %StatusInfo
@onready var exits_info_label: Label = %ExitsInfoLabel

# Панель состояния хоббита справа
@onready var mode_info_label: Label = %ModeInfoLabel
@onready var health_info_label: Label = %HealthInfoLabel
@onready var vis_info_label: Label = %VisInfoLabel
@onready var companion_info_label: Label = %CompanionInfoLabel

# Экран выбора режима игры (перед заставкой)
@onready var mode_select_screen: Control = %ModeSelectScreen
@onready var btn_select_modern: Button = %BtnSelectModern
@onready var btn_select_vga: Button = %BtnSelectVGA
@onready var btn_select_zx: Button = %BtnSelectZX

# Картинки для меню выбора режима игры
const CARD_IMG_MODERN: String = "res://assets/images/mode_menu/ModernPC.jpg"
const CARD_IMG_VGA: String = "res://assets/images/mode_menu/RetroPC.jpg"
const CARD_IMG_ZX: String = "res://assets/images/mode_menu/ZXPC.jpg"

@onready var img_preview_modern: TextureRect = %ImagePreviewModern
@onready var img_preview_vga: TextureRect = %ImagePreviewVGA
@onready var img_preview_zx: TextureRect = %ImagePreviewZX

# Шрифты для каждого режима игры
const FONT_PATH_MODERN: String = "res://assets/fonts/MODERN/Greengoth_Regular.ttf"
const FONT_PATH_VGA: String = "res://assets/fonts/DOS/dos2000-ru-en.ttf"
const FONT_PATH_ZX: String = "res://assets/fonts/ZX/zx_spectrum-7.ttf"

# Экран загрузки / заставка
@onready var title_screen: Control = %TitleScreen
@onready var video_freeze_frame: TextureRect = %VideoFreezeFrame
@onready var intro_video: VideoStreamPlayer = %IntroVideo
@onready var title_image: TextureRect = %TitleImage
@onready var menu_container: VBoxContainer = %MenuContainer
@onready var btn_start_game: Button = %BtnStartGame
@onready var btn_title_load: Button = %BtnTitleLoad
@onready var btn_change_mode: Button = %BtnChangeMode
@onready var btn_settings: Button = %BtnSettings
@onready var btn_credits: Button = %BtnCredits
@onready var btn_exit: Button = %BtnExit
@onready var version_label: Label = %VersionLabel

# Окно сохранения / загрузки (Ren'Py style)
@onready var save_load_screen: Control = %SaveLoadScreen

# Экран «Об игре» (Credits)
@onready var credits_screen: Control = %CreditsScreen

# Окно настроек
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var vol_value_label: Label = %VolValue
@onready var check_fullscreen: CheckBox = %CheckFullscreen
@onready var check_accessibility: CheckBox = %CheckAccessibility
@onready var btn_settings_main_menu: Button = %BtnSettingsMainMenu
@onready var btn_settings_back: Button = %BtnSettingsBack
@onready var btn_settings_game: Button = %BtnSettingsGame

enum IntroPhase { VIDEO, FADING, READY }
var intro_phase: IntroPhase = IntroPhase.VIDEO
var intro_tween: Tween = null
var current_video_cutoff: float = 9.85

# Кнопки компаса (слева) и действий (справа)
@onready var btn_nw: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/CompassGrid/BtnNW
@onready var btn_n: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/CompassGrid/BtnN
@onready var btn_ne: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/CompassGrid/BtnNE
@onready var btn_w: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/CompassGrid/BtnW
@onready var btn_e: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/CompassGrid/BtnE
@onready var btn_sw: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/CompassGrid/BtnSW
@onready var btn_s: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/CompassGrid/BtnS
@onready var btn_se: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/CompassGrid/BtnSE
@onready var btn_up: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/VerticalGrid/BtnUP
@onready var btn_dn: Button = $RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/VerticalGrid/BtnDN

@onready var btn_look: Button = $RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/ActionGrid/BtnLook
@onready var btn_inv: Button = $RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/ActionGrid/BtnInv
@onready var btn_wait: Button = $RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/ActionGrid/BtnWait
@onready var btn_take_all: Button = $RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/ActionGrid/BtnTakeAll
@onready var btn_save: Button = $RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/ActionGrid/BtnSave
@onready var btn_load: Button = $RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/ActionGrid/BtnLoad

# Панели для высококонтрастного режима слабовидящих
@onready var left_move_panel: PanelContainer = $RootMargin/VBoxMain/TopRow/LeftMovePanel
@onready var right_action_panel: PanelContainer = $RootMargin/VBoxMain/TopRow/RightActionPanel
@onready var center_image_panel: PanelContainer = $RootMargin/VBoxMain/TopRow/CenterImagePanel
@onready var output_log_panel: PanelContainer = $RootMargin/VBoxMain/BottomSection/OutputLogPanel
@onready var prompt_label: Label = $RootMargin/VBoxMain/BottomSection/HBoxInput/PromptLabel
@onready var status_card: PanelContainer = $RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/StatusCard

var _orig_left_panel_style: StyleBox = null
var _orig_right_panel_style: StyleBox = null
var _orig_output_panel_style: StyleBox = null
var _orig_center_panel_style: StyleBox = null
var _orig_status_card_style: StyleBox = null
var _orig_input_line_style: StyleBox = null
var _orig_settings_panel_style: StyleBox = null

var history: Array[String] = []
var history_index: int = -1
var game_started: bool = false

var cached_game_state: Node = null
var cached_audio_manager: Node = null

func _get_game_state() -> Node:
	if cached_game_state:
		return cached_game_state
	if not is_inside_tree():
		return null
	var t = get_tree()
	if t and t.root:
		if t.root.has_node("GameState"):
			cached_game_state = t.root.get_node("GameState")
			return cached_game_state
		for child in t.root.get_children():
			if "rooms" in child and "current_room_id" in child:
				cached_game_state = child
				return cached_game_state
	return null

func _get_audio_manager() -> Node:
	if cached_audio_manager:
		return cached_audio_manager
	if not is_inside_tree():
		return null
	var t = get_tree()
	if t and t.root:
		if t.root.has_node("AudioManager"):
			cached_audio_manager = t.root.get_node("AudioManager")
			return cached_audio_manager
		for child in t.root.get_children():
			if "play_theme" in child and "current_theme" in child:
				cached_audio_manager = child
				return cached_audio_manager
	return null

var _main_ready_done: bool = false

func _ready() -> void:
	if _main_ready_done:
		return
	_main_ready_done = true
	var gs = _get_game_state()
	var am = _get_audio_manager()
	
	# 1. Сигналы GameState
	if gs:
		gs.text_printed.connect(_on_text_printed)
		gs.room_changed.connect(_on_room_changed)
		gs.world_updated.connect(_on_world_updated)
		gs.inventory_changed.connect(_on_inventory_changed)
		gs.game_mode_changed.connect(_on_game_mode_changed)
	
	input_line.text_submitted.connect(_on_input_submitted)
	command_dropdown.item_selected.connect(_on_dropdown_command_selected)
	
	_connect_buttons()
	if gs:
		_update_header(gs.current_room_id)
	_update_compass_buttons()
	_update_status_bar()
	_update_command_dropdown()
	
	# 2. Инициализация картинок, шрифтов и меню выбора режима игры
	_setup_mode_select_card_images()
	_setup_mode_select_card_fonts()
	var init_mode = int(gs.game_mode) if gs else Mode.MODERN
	_apply_game_mode_font(init_mode)
	
	btn_select_modern.pressed.connect(func(): _on_mode_card_selected(Mode.MODERN))
	btn_select_vga.pressed.connect(func(): _on_mode_card_selected(Mode.VGA))
	btn_select_zx.pressed.connect(func(): _on_mode_card_selected(Mode.ZX))
	
	# 3. Инициализация титульного экрана
	_update_title_load_button()
		
	btn_start_game.pressed.connect(_on_start_pressed)
	btn_title_load.pressed.connect(_on_title_load_pressed)
	btn_change_mode.pressed.connect(_on_change_mode_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_settings_game.pressed.connect(_on_settings_pressed)
	if btn_credits:
		btn_credits.pressed.connect(_on_credits_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	if OS.has_feature("web"):
		btn_exit.visible = false
	
	# 4. Инициализация окна настроек
	_setup_fullscreen_checkbox()
	_setup_accessibility_checkbox()
	
	if am:
		_is_syncing_volume_slider = true
		volume_slider.value = am.get_music_volume()
		_update_volume_label(volume_slider.value)
		_is_syncing_volume_slider = false
	volume_slider.value_changed.connect(_on_volume_changed)
	
	var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	check_fullscreen.button_pressed = is_fs
	check_fullscreen.toggled.connect(_on_fullscreen_toggled)
	
	if gs:
		check_accessibility.button_pressed = gs.is_accessibility_mode
		if gs.is_accessibility_mode:
			_apply_accessibility_theme(true)
	check_accessibility.toggled.connect(_on_accessibility_toggled)
		
	btn_settings_back.pressed.connect(_on_settings_back_pressed)
	btn_settings_main_menu.pressed.connect(_on_settings_main_menu_pressed)
	
	# 5. Инициализация экрана сохранения / загрузки (Ren'Py style)
	if save_load_screen:
		save_load_screen.main_ref = self
		save_load_screen.cached_game_state = gs
		save_load_screen.cached_audio_manager = am
		save_load_screen.game_loaded.connect(_on_save_load_game_loaded)
		save_load_screen.closed.connect(_on_save_load_closed)
		
	# 6. Инициализация экрана «Об игре» (Credits)
	if credits_screen:
		credits_screen.cached_audio_manager = am
		credits_screen.closed.connect(_on_credits_closed)
	
	# Стартовое состояние: показываем меню выбора из 3-х режимов!
	mode_select_screen.visible = true
	title_screen.visible = false
	if is_inside_tree():
		btn_select_modern.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		var am = _get_audio_manager()
		if am and am.has_method("save_current_settings"):
			am.save_current_settings()

func _process(_delta: float) -> void:
	if intro_phase == IntroPhase.VIDEO and intro_video and intro_video.is_playing():
		var pos = intro_video.get_stream_position()
		if pos >= current_video_cutoff:
			_freeze_and_fade()

func _on_mode_card_selected(selected_mode: int) -> void:
	var gs = _get_game_state()
	var am = _get_audio_manager()
	if gs:
		gs.set_game_mode(selected_mode)
	if am:
		am.save_current_settings()
	
	mode_select_screen.visible = false
	title_screen.visible = true
	_start_intro_sequence()

func _on_change_mode_pressed() -> void:
	if intro_video:
		intro_video.stop()
		intro_video.visible = false
	var am = _get_audio_manager()
	if am:
		am.stop_music()
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
		
	title_screen.visible = false
	mode_select_screen.visible = true
	var gs = _get_game_state()
	if gs:
		match int(gs.game_mode):
			Mode.VGA:
				btn_select_vga.grab_focus()
			Mode.ZX:
				btn_select_zx.grab_focus()
			_:
				btn_select_modern.grab_focus()
	else:
		btn_select_modern.grab_focus()

func _start_intro_sequence() -> void:
	var am = _get_audio_manager()
	if am:
		am.stop_music()
		
	_load_title_assets_for_mode()
	
	title_image.modulate.a = 0.0
	menu_container.modulate.a = 0.0
	menu_container.visible = false
	if version_label:
		version_label.modulate.a = 0.0
		version_label.visible = false
	intro_phase = IntroPhase.VIDEO
	
	if video_freeze_frame:
		video_freeze_frame.visible = false
	
	if not intro_video.finished.is_connected(_on_intro_video_finished):
		intro_video.finished.connect(_on_intro_video_finished)
	
	var stream: VideoStream = _get_video_stream_for_mode()
	if stream:
		intro_video.stream = stream
		intro_video.visible = true
		var gs = _get_game_state()
		var mode = int(gs.game_mode) if gs else Mode.MODERN
		if mode == Mode.ZX:
			# Громкость loading_ZX.mp4 уменьшена на 80%
			intro_video.volume = 0.2
			intro_video.volume_db = linear_to_db(0.5)
		else:
			intro_video.volume = 1.0
			intro_video.volume_db = 0.0
		if intro_video.is_inside_tree():
			intro_video.play()
	else:
		_freeze_and_fade()

func _get_video_stream_for_mode() -> VideoStream:
	var ogv_file = ""
	var mp4_file = ""
	var gs = _get_game_state()
	var mode = int(gs.game_mode) if gs else Mode.MODERN
	
	match mode:
		Mode.VGA:
			ogv_file = "res://assets/images/loading_vga.ogv"
			mp4_file = "res://assets/images/loading_vga.mp4"
			current_video_cutoff = 9.95
		Mode.ZX:
			ogv_file = "res://assets/images/loading_ZX.ogv"
			mp4_file = "res://assets/images/loading_ZX.mp4"
			current_video_cutoff = 19.75
		_:
			ogv_file = "res://assets/images/loading.ogv"
			mp4_file = "res://assets/images/loading.mp4"
			current_video_cutoff = 9.85
			
	if ResourceLoader.exists(ogv_file):
		return load(ogv_file)
	if ResourceLoader.exists(mp4_file):
		return load(mp4_file)
	if FileAccess.file_exists(ogv_file):
		var theora = VideoStreamTheora.new()
		theora.file = ProjectSettings.globalize_path(ogv_file)
		return theora
	return null

func _load_title_assets_for_mode() -> void:
	var title_img_name = "loading.png"
	var freeze_img_name = "video_last_frame.png"
	var gs = _get_game_state()
	var mode = int(gs.game_mode) if gs else Mode.MODERN
	
	match mode:
		Mode.VGA:
			title_img_name = "loading VGA.png"
			freeze_img_name = "video_last_frame_vga.png"
		Mode.ZX:
			title_img_name = "Loading_ZX.png"
			freeze_img_name = "video_last_frame_zx.png"
		_:
			title_img_name = "loading.png"
			freeze_img_name = "video_last_frame.png"
			
	if title_image:
		var p_title = "res://assets/images/" + title_img_name
		title_image.texture = _load_texture_file(p_title)
		
	if video_freeze_frame:
		var p_freeze = "res://assets/images/" + freeze_img_name
		var tex_f = _load_texture_file(p_freeze)
		if tex_f:
			video_freeze_frame.texture = tex_f
		elif title_image and title_image.texture:
			video_freeze_frame.texture = title_image.texture

func _load_texture_file(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is Texture2D:
			return res
	var global_p = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_p):
		var img = Image.load_from_file(global_p)
		if img:
			return ImageTexture.create_from_image(img)
	return null

func _on_intro_video_finished() -> void:
	if intro_phase == IntroPhase.VIDEO:
		_freeze_and_fade()

func _freeze_and_fade() -> void:
	if intro_phase != IntroPhase.VIDEO:
		return
	intro_phase = IntroPhase.FADING
	
	if intro_video:
		intro_video.stop()
		intro_video.visible = false
		
	if video_freeze_frame:
		video_freeze_frame.visible = true
		
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
		
	intro_tween = create_tween()
	intro_tween.tween_property(title_image, "modulate:a", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro_tween.tween_callback(_on_title_image_fully_shown)

func _on_title_image_fully_shown() -> void:
	if intro_phase == IntroPhase.READY:
		return
	intro_phase = IntroPhase.READY
	
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
		
	title_image.modulate.a = 1.0
	
	if intro_video:
		intro_video.stop()
		intro_video.visible = false
		
	if video_freeze_frame:
		video_freeze_frame.visible = false
		
	var am = _get_audio_manager()
	if am:
		am.play_theme("fanfare")
	
	menu_container.visible = true
	var tween = create_tween()
	tween.tween_property(menu_container, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	if version_label:
		version_label.visible = true
		tween.parallel().tween_property(version_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	btn_start_game.grab_focus()

func _skip_intro() -> void:
	if intro_phase == IntroPhase.READY:
		return
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
	_on_title_image_fully_shown()

func _input(event: InputEvent) -> void:
	if credits_screen and credits_screen.visible:
		# Экран титров самостоятельно обрабатывает свои клавиши (Space, ESC, стрелки, колесо)
		return
		
	if save_load_screen and save_load_screen.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				save_load_screen.close()
				get_viewport().set_input_as_handled()
		return
		
	if mode_select_screen.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode in [KEY_1, KEY_KP_1]:
				_on_mode_card_selected(Mode.MODERN)
				get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_2, KEY_KP_2]:
				_on_mode_card_selected(Mode.VGA)
				get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_3, KEY_KP_3]:
				_on_mode_card_selected(Mode.ZX)
				get_viewport().set_input_as_handled()
		return
		
	if not game_started and title_screen.visible:
		if event is InputEventKey and event.pressed:
			if settings_panel and settings_panel.visible:
				if event.keycode == KEY_ESCAPE:
					_on_settings_back_pressed()
					get_viewport().set_input_as_handled()
				return
				
			if intro_phase != IntroPhase.READY:
				if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
					_skip_intro()
					get_viewport().set_input_as_handled()
				return
			else:
				if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
					if btn_start_game.has_focus():
						_on_start_pressed()
					elif btn_title_load.has_focus() and not btn_title_load.disabled:
						_on_title_load_pressed()
					elif btn_change_mode.has_focus():
						_on_change_mode_pressed()
					elif btn_settings.has_focus():
						_on_settings_pressed()
					elif btn_credits and btn_credits.has_focus():
						_on_credits_pressed()
					elif btn_exit.has_focus():
						_on_exit_pressed()
					get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed:
		if settings_panel and settings_panel.visible:
			if event.keycode == KEY_ESCAPE:
				_on_settings_back_pressed()
				get_viewport().set_input_as_handled()
			return
			
		if event.keycode == KEY_UP:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_navigate_history(1)
			get_viewport().set_input_as_handled()

func _on_start_pressed() -> void:
	if game_started:
		return
	game_started = true
	title_screen.visible = false
	input_line.grab_focus()
	var gs = _get_game_state()
	var am = _get_audio_manager()
	if gs:
		if gs.has_method("reset_game"):
			gs.reset_game()
		if output_log:
			output_log.clear()
		gs.start_game()
	_update_compass_buttons()
	_update_command_dropdown()
	_update_status_bar()
	if am:
		am.play_initial_music()

func _on_title_load_pressed() -> void:
	open_load_menu(true)

func open_save_menu() -> void:
	if save_load_screen:
		var thumb = _capture_screenshot()
		save_load_screen.open_save(thumb)

func open_load_menu(from_title: bool = false) -> void:
	if save_load_screen:
		save_load_screen.open_load(from_title)

func _capture_screenshot() -> Image:
	var vp = get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var full_img = tex.get_image()
			if full_img:
				var thumb = full_img.duplicate()
				thumb.resize(480, 270, Image.INTERPOLATE_BILINEAR)
				return thumb
	var fallback = Image.create(480, 270, false, Image.FORMAT_RGBA8)
	fallback.fill(Color(0.06, 0.08, 0.12, 1.0))
	return fallback

func _on_save_load_game_loaded(_slot_id: int) -> void:
	game_started = true
	title_screen.visible = false
	if intro_video:
		intro_video.stop()
		intro_video.visible = false
	if video_freeze_frame:
		video_freeze_frame.visible = false
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
		
	if input_line and input_line.is_inside_tree():
		input_line.grab_focus()
		
	var gs = _get_game_state()
	if gs:
		_apply_game_mode_font(int(gs.game_mode))
		_update_header(gs.current_room_id)
		
	_update_compass_buttons()
	_update_command_dropdown()
	_update_status_bar()
	_update_title_load_button()

func _on_save_load_closed() -> void:
	_update_title_load_button()
	if game_started:
		if input_line and input_line.is_inside_tree():
			input_line.grab_focus()
	else:
		if btn_title_load and btn_title_load.is_inside_tree():
			btn_title_load.grab_focus()

func _update_title_load_button() -> void:
	if not btn_title_load:
		return
	var gs = _get_game_state()
	var has_save = false
	if gs and gs.has_method("has_any_saves"):
		has_save = gs.has_any_saves()
	else:
		has_save = FileAccess.file_exists("user://savegame.json")
		
	btn_title_load.disabled = not has_save
	if not has_save:
		btn_title_load.modulate = Color(0.5, 0.55, 0.6, 0.4)
	else:
		btn_title_load.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_settings_pressed() -> void:
	settings_panel.visible = true
	if btn_settings_main_menu:
		btn_settings_main_menu.visible = game_started
	var gs = _get_game_state()
	var am = _get_audio_manager()
	if am:
		_is_syncing_volume_slider = true
		volume_slider.value = am.get_music_volume()
		_update_volume_label(volume_slider.value)
		_is_syncing_volume_slider = false
	if gs and check_accessibility:
		check_accessibility.button_pressed = gs.is_accessibility_mode
	var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	check_fullscreen.button_pressed = is_fs
	if btn_settings_back.is_inside_tree():
		btn_settings_back.grab_focus()

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	if not game_started:
		if btn_settings and btn_settings.is_inside_tree():
			btn_settings.grab_focus()
	else:
		if input_line and input_line.is_inside_tree():
			input_line.grab_focus()

func _on_settings_main_menu_pressed() -> void:
	settings_panel.visible = false
	game_started = false
	
	if intro_video:
		intro_video.stop()
		intro_video.visible = false
	if video_freeze_frame:
		video_freeze_frame.visible = false
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
		
	_load_title_assets_for_mode()
	title_image.visible = true
	title_image.modulate.a = 1.0
	menu_container.visible = true
	menu_container.modulate.a = 1.0
	if version_label:
		version_label.visible = true
		version_label.modulate.a = 1.0
	intro_phase = IntroPhase.READY
	title_screen.visible = true
	
	_update_title_load_button()
		
	var am = _get_audio_manager()
	if am:
		am.play_theme("fanfare")
		
	if btn_start_game and btn_start_game.is_inside_tree():
		btn_start_game.grab_focus()

func _on_credits_pressed() -> void:
	if intro_video:
		intro_video.stop()
		intro_video.visible = false
	if video_freeze_frame:
		video_freeze_frame.visible = false
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
		
	title_screen.visible = false
	if credits_screen:
		credits_screen.cached_audio_manager = _get_audio_manager()
		credits_screen.open_credits()

func _on_credits_closed() -> void:
	if credits_screen:
		credits_screen.visible = false
	title_screen.visible = true
	if version_label:
		version_label.visible = true
		version_label.modulate.a = 1.0
	var am = _get_audio_manager()
	if am:
		am.play_theme("fanfare")
	if btn_credits and btn_credits.is_inside_tree():
		btn_credits.grab_focus()

func _on_exit_pressed() -> void:
	var am = _get_audio_manager()
	if am:
		am.save_current_settings()
	if not OS.has_feature("web"):
		get_tree().quit()

var _is_syncing_volume_slider: bool = false

func _on_volume_changed(val: float) -> void:
	_update_volume_label(val)
	if _is_syncing_volume_slider:
		return
	var am = _get_audio_manager()
	var gs = _get_game_state()
	var is_acc = gs.is_accessibility_mode if gs else false
	if am:
		if not is_acc:
			am.set_pre_accessibility_volume(val)
		am.set_music_volume(val)
		am.save_settings(check_fullscreen.button_pressed)

func _update_volume_label(val: float) -> void:
	if vol_value_label:
		vol_value_label.text = "%d%%" % int(round(val * 100))

func _on_fullscreen_toggled(is_fs: bool) -> void:
	var am = _get_audio_manager()
	if am:
		am.apply_fullscreen(is_fs)
		am.save_settings(is_fs)
	else:
		if is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

func _on_accessibility_toggled(enabled: bool) -> void:
	var gs = _get_game_state()
	var am = _get_audio_manager()
	_stop_tts()
	if gs:
		gs.set_accessibility_mode(enabled)
		gs.print_to_log("Режим для слабовидящих: " + ("ВКЛ" if enabled else "ВЫКЛ"), Color.YELLOW)
	if am:
		_is_syncing_volume_slider = true
		if enabled:
			am._on_accessibility_mode_changed(true)
			volume_slider.value = 0.10
			_update_volume_label(0.10)
		else:
			am._on_accessibility_mode_changed(false)
			var restored_vol = am.get_music_volume()
			volume_slider.value = restored_vol
			_update_volume_label(restored_vol)
		_is_syncing_volume_slider = false
		am.save_settings(check_fullscreen.button_pressed)
		
	_apply_accessibility_theme(enabled)
	
	if enabled:
		_speak_text("Режим для слабовидящих включен.")

func _save_original_panel_styles() -> void:
	if _orig_left_panel_style != null:
		return
	if left_move_panel:
		_orig_left_panel_style = left_move_panel.get_theme_stylebox("panel")
	if right_action_panel:
		_orig_right_panel_style = right_action_panel.get_theme_stylebox("panel")
	if center_image_panel:
		_orig_center_panel_style = center_image_panel.get_theme_stylebox("panel")
	if output_log_panel:
		_orig_output_panel_style = output_log_panel.get_theme_stylebox("panel")
	if status_card:
		_orig_status_card_style = status_card.get_theme_stylebox("panel")
	if input_line:
		_orig_input_line_style = input_line.get_theme_stylebox("normal")
	if settings_panel:
		_orig_settings_panel_style = settings_panel.get_theme_stylebox("panel")

func _apply_accessibility_theme(enabled: bool) -> void:
	_save_original_panel_styles()
	var gs = _get_game_state()
	var mode = int(gs.game_mode) if gs else Mode.MODERN
	
	if enabled:
		# Высококонтрастные сплошные черные панели с четкими рамками цвета яркого золота (3px)
		var hc_panel = StyleBoxFlat.new()
		hc_panel.bg_color = Color(0.0, 0.0, 0.0, 1.0)
		hc_panel.set_border_width_all(3)
		hc_panel.border_color = Color(1.0, 0.88, 0.1, 1.0)
		hc_panel.set_corner_radius_all(8)
		hc_panel.shadow_size = 0
		
		var hc_center = StyleBoxFlat.new()
		hc_center.bg_color = Color(0.0, 0.0, 0.0, 1.0)
		hc_center.set_border_width_all(3)
		hc_center.border_color = Color(1.0, 0.88, 0.1, 1.0)
		hc_center.set_corner_radius_all(8)
		hc_center.shadow_size = 0
		
		var hc_log = StyleBoxFlat.new()
		hc_log.bg_color = Color(0.0, 0.0, 0.0, 1.0)
		hc_log.set_border_width_all(3)
		hc_log.border_color = Color(1.0, 0.88, 0.1, 1.0)
		hc_log.set_corner_radius_all(8)
		hc_log.shadow_size = 0
		
		var hc_card = StyleBoxFlat.new()
		hc_card.bg_color = Color(0.0, 0.0, 0.0, 1.0)
		hc_card.set_border_width_all(2)
		hc_card.border_color = Color(0.25, 0.9, 1.0, 1.0)
		hc_card.set_corner_radius_all(6)
		
		var hc_input = StyleBoxFlat.new()
		hc_input.bg_color = Color(0.0, 0.0, 0.0, 1.0)
		hc_input.set_border_width_all(3)
		hc_input.border_color = Color(1.0, 0.88, 0.1, 1.0)
		hc_input.set_corner_radius_all(6)
		
		if left_move_panel:
			left_move_panel.add_theme_stylebox_override("panel", hc_panel)
		if right_action_panel:
			right_action_panel.add_theme_stylebox_override("panel", hc_panel)
		if center_image_panel:
			center_image_panel.add_theme_stylebox_override("panel", hc_center)
		if output_log_panel:
			output_log_panel.add_theme_stylebox_override("panel", hc_log)
		if status_card:
			status_card.add_theme_stylebox_override("panel", hc_card)
		if input_line:
			input_line.add_theme_stylebox_override("normal", hc_input)
			input_line.add_theme_stylebox_override("focus", hc_input)
			input_line.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			input_line.add_theme_color_override("caret_color", Color(1.0, 0.9, 0.0, 1.0))
		if settings_panel:
			settings_panel.add_theme_stylebox_override("panel", hc_panel)
	else:
		if left_move_panel and _orig_left_panel_style:
			left_move_panel.add_theme_stylebox_override("panel", _orig_left_panel_style)
		if right_action_panel and _orig_right_panel_style:
			right_action_panel.add_theme_stylebox_override("panel", _orig_right_panel_style)
		if center_image_panel and _orig_center_panel_style:
			center_image_panel.add_theme_stylebox_override("panel", _orig_center_panel_style)
		if output_log_panel and _orig_output_panel_style:
			output_log_panel.add_theme_stylebox_override("panel", _orig_output_panel_style)
		if status_card and _orig_status_card_style:
			status_card.add_theme_stylebox_override("panel", _orig_status_card_style)
		if input_line:
			if _orig_input_line_style:
				input_line.add_theme_stylebox_override("normal", _orig_input_line_style)
				input_line.add_theme_stylebox_override("focus", _orig_input_line_style)
			else:
				input_line.remove_theme_stylebox_override("normal")
				input_line.remove_theme_stylebox_override("focus")
			input_line.remove_theme_color_override("font_color")
			input_line.remove_theme_color_override("caret_color")
		if settings_panel and _orig_settings_panel_style:
			settings_panel.add_theme_stylebox_override("panel", _orig_settings_panel_style)
			
	_apply_game_mode_font(mode)
	_update_compass_buttons()
	_update_status_bar()

func _setup_fullscreen_checkbox() -> void:
	var tex_un: Texture2D = _load_texture_file("res://assets/images/checkbox_unchecked.png")
	if not tex_un:
		tex_un = _create_fallback_checkbox_texture(false)
		
	var tex_ck: Texture2D = _load_texture_file("res://assets/images/checkbox_checked.png")
	if not tex_ck:
		tex_ck = _create_fallback_checkbox_texture(true)
		
	check_fullscreen.add_theme_icon_override("unchecked", tex_un)
	check_fullscreen.add_theme_icon_override("unchecked_disabled", tex_un)
	check_fullscreen.add_theme_icon_override("checked", tex_ck)
	check_fullscreen.add_theme_icon_override("checked_disabled", tex_ck)
	
	var empty_sb = StyleBoxEmpty.new()
	check_fullscreen.add_theme_stylebox_override("focus", empty_sb)
	check_fullscreen.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3, 1.0))
	check_fullscreen.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.3, 1.0))
	check_fullscreen.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.3, 1.0))
	check_fullscreen.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1.0))

func _setup_accessibility_checkbox() -> void:
	if not check_accessibility:
		return
	var tex_un: Texture2D = _load_texture_file("res://assets/images/checkbox_unchecked.png")
	if not tex_un:
		tex_un = _create_fallback_checkbox_texture(false)
		
	var tex_ck: Texture2D = _load_texture_file("res://assets/images/checkbox_checked.png")
	if not tex_ck:
		tex_ck = _create_fallback_checkbox_texture(true)
		
	check_accessibility.add_theme_icon_override("unchecked", tex_un)
	check_accessibility.add_theme_icon_override("unchecked_disabled", tex_un)
	check_accessibility.add_theme_icon_override("checked", tex_ck)
	check_accessibility.add_theme_icon_override("checked_disabled", tex_ck)
	
	var empty_sb = StyleBoxEmpty.new()
	check_accessibility.add_theme_stylebox_override("focus", empty_sb)
	check_accessibility.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3, 1.0))
	check_accessibility.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.3, 1.0))
	check_accessibility.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.3, 1.0))
	check_accessibility.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1.0))

func _create_fallback_checkbox_texture(is_checked: bool) -> ImageTexture:
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var border_col = Color(0.92, 0.80, 0.37, 1.0)
	var bg_col = Color(0.08, 0.10, 0.14, 0.9)
	var check_col = Color(1.0, 0.92, 0.51, 1.0)
	
	for y in range(2, 22):
		for x in range(2, 22):
			if x == 2 or x == 21 or y == 2 or y == 21:
				img.set_pixel(x, y, border_col)
			elif x == 3 or x == 20 or y == 3 or y == 20:
				img.set_pixel(x, y, border_col)
			else:
				img.set_pixel(x, y, bg_col)
				
	if is_checked:
		var pts = [
			Vector2i(6, 12), Vector2i(7, 13), Vector2i(8, 14), Vector2i(9, 15), Vector2i(10, 16),
			Vector2i(11, 15), Vector2i(12, 14), Vector2i(13, 13), Vector2i(14, 12), Vector2i(15, 11),
			Vector2i(16, 10), Vector2i(17, 9), Vector2i(18, 8)
		]
		for p in pts:
			for dy in range(-1, 2):
				img.set_pixel(p.x, p.y + dy, check_col)
				
	return ImageTexture.create_from_image(img)

func _navigate_history(delta: int) -> void:
	if history.is_empty():
		return
	history_index = clamp(history_index + delta, 0, history.size())
	if history_index < history.size():
		input_line.text = history[history_index]
		input_line.caret_column = input_line.text.length()
	else:
		input_line.clear()

func _connect_buttons() -> void:
	btn_n.pressed.connect(func(): _execute_quick("север"))
	btn_s.pressed.connect(func(): _execute_quick("юг"))
	btn_e.pressed.connect(func(): _execute_quick("восток"))
	btn_w.pressed.connect(func(): _execute_quick("запад"))
	btn_ne.pressed.connect(func(): _execute_quick("северо-восток"))
	btn_nw.pressed.connect(func(): _execute_quick("северо-запад"))
	btn_se.pressed.connect(func(): _execute_quick("юго-восток"))
	btn_sw.pressed.connect(func(): _execute_quick("юго-запад"))
	btn_up.pressed.connect(func(): _execute_quick("вверх"))
	btn_dn.pressed.connect(func(): _execute_quick("вниз"))
	
	btn_look.pressed.connect(func(): _execute_quick("осмотреться"))
	btn_wait.pressed.connect(func(): _execute_quick("ждать"))
	btn_inv.pressed.connect(func(): _execute_quick("инвентарь"))
	btn_take_all.pressed.connect(func(): _execute_quick("взять всё"))
	btn_save.pressed.connect(open_save_menu)
	btn_load.pressed.connect(func(): open_load_menu(false))

func _execute_quick(cmd: String) -> void:
	_stop_tts()
	var gs = _get_game_state()
	if gs:
		gs.process_command(cmd)
	_update_compass_buttons()
	_update_command_dropdown()
	input_line.grab_focus()

var _tts_voice_id: String = ""
var _tts_voice_checked: bool = false

func _stop_tts() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.speechSynthesis) window.speechSynthesis.cancel();")

func _get_tts_voice_id() -> String:
	if _tts_voice_checked:
		return _tts_voice_id
	_tts_voice_checked = true
	
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return ""
		
	var voices = DisplayServer.tts_get_voices()
	if voices.is_empty():
		return ""
		
	for v in voices:
		if v is Dictionary:
			var lang = str(v.get("language", "")).to_lower()
			var v_name = str(v.get("name", "")).to_lower()
			var v_id = str(v.get("id", "")).to_lower()
			if "ru" in lang or "ru" in v_name or "russian" in v_name or "irina" in v_name or "ru" in v_id:
				_tts_voice_id = str(v.get("id", ""))
				return _tts_voice_id
				
	if voices[0] is Dictionary:
		_tts_voice_id = str(voices[0].get("id", ""))
	return _tts_voice_id

func _speak_text(text: String) -> void:
	if text.is_empty():
		return
		
	# Очистка всех тегов BBCode [color=...], [b] и др.
	var regex = RegEx.new()
	regex.compile("\\[[^\\]]*\\]")
	var clean_text = regex.sub(text, "", true).strip_edges()
	
	# Очистка лишних пробелов
	var sp_regex = RegEx.new()
	sp_regex.compile("\\s+")
	clean_text = sp_regex.sub(clean_text, " ", true).strip_edges()
	
	if clean_text.is_empty():
		return
		
	# 1. Браузерная Web-версия (HTML5 Web Speech API)
	if OS.has_feature("web"):
		var js = """
		(function() {
			if (!window.speechSynthesis) return;
			var u = new SpeechSynthesisUtterance(%s);
			u.lang = 'ru-RU';
			u.rate = 1.0;
			u.pitch = 1.0;
			u.volume = 1.0;
			window.speechSynthesis.speak(u);
		})();
		""" % [JSON.stringify(clean_text)]
		JavaScriptBridge.eval(js)
		return
		
	# 2. Нативная десктопная версия (DisplayServer TTS)
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
		
	var v_id = _get_tts_voice_id()
	if v_id.is_empty():
		return
		
	# Godot 4: tts_speak(text, voice, volume=50, pitch=1.0, rate=1.0, utterance_id=0, interrupt=false)
	# volume = 100 для максимальной четкости и слышимости
	DisplayServer.tts_speak(clean_text, v_id, 100, 1.0, 1.0, 0, false)

func _on_text_printed(text: String, color: Color) -> void:
	var gs = _get_game_state()
	var final_color = color
	if gs and gs.is_accessibility_mode:
		# Высококонтрастная палитра: исключаем темные, блеклые или трудноразличимые оттенки
		if color.r < 0.5 and color.g < 0.5 and color.b < 0.5:
			final_color = Color(1.0, 1.0, 1.0, 1.0) # белый вместо темного
		elif color.r > 0.7 and color.g > 0.7 and color.b < 0.4:
			final_color = Color(1.0, 0.95, 0.1, 1.0) # сверхяркое золото
		elif color.g > 0.6 and color.r < 0.6:
			final_color = Color(0.2, 1.0, 0.45, 1.0) # яркий мятно-зеленый
		elif color.r > 0.7 and color.g < 0.4:
			final_color = Color(1.0, 0.35, 0.35, 1.0) # яркий красный
		elif color.b > 0.6 and color.r < 0.6:
			final_color = Color(0.4, 0.95, 1.0, 1.0) # яркий циан
			
	if text.begins_with("[color"):
		output_log.append_text(text + "\n")
	else:
		var hex = final_color.to_html(false)
		output_log.append_text("[color=#" + hex + "]" + text + "[/color]\n")
	
	if gs and gs.is_accessibility_mode:
		_speak_text(text)

func _on_input_submitted(new_text: String) -> void:
	var clean = new_text.strip_edges()
	if clean.is_empty():
		return
	_stop_tts()
		
	history.append(clean)
	history_index = history.size()
	
	var lower = clean.to_lower()
	if lower in ["сохранить", "сохранить игру", "save", "savegame"]:
		open_save_menu()
		input_line.clear()
		return
	elif lower in ["загрузить", "загрузить игру", "load", "loadgame"]:
		open_load_menu(false)
		input_line.clear()
		return
		
	var gs = _get_game_state()
	if gs:
		gs.process_command(clean)
	_update_compass_buttons()
	_update_command_dropdown()
	input_line.clear()
	input_line.grab_focus()

func _on_room_changed(room_id: int) -> void:
	_update_header(room_id)
	_update_compass_buttons()
	_update_status_bar()
	_update_command_dropdown()

func _on_world_updated() -> void:
	var gs = _get_game_state()
	if gs:
		_update_header(gs.current_room_id)
	_update_compass_buttons()
	_update_status_bar()
	_update_command_dropdown()

func _on_inventory_changed() -> void:
	_update_status_bar()
	_update_command_dropdown()

func _on_game_mode_changed(mode: int) -> void:
	_apply_game_mode_font(mode)
	var gs = _get_game_state()
	if gs:
		_update_header(gs.current_room_id)
	_update_status_bar()
	_update_command_dropdown()

func _get_font_for_mode(mode: int) -> Font:
	var gs = _get_game_state()
	if gs and gs.has_method("get_font_for_mode"):
		return gs.get_font_for_mode(mode)
	var p = FONT_PATH_MODERN
	match mode:
		Mode.VGA:
			p = FONT_PATH_VGA
		Mode.ZX:
			p = FONT_PATH_ZX
	if ResourceLoader.exists(p):
		return load(p)
	return null

func _setup_mode_select_card_images() -> void:
	if img_preview_modern:
		img_preview_modern.texture = _load_texture_file(CARD_IMG_MODERN)
	if img_preview_vga:
		img_preview_vga.texture = _load_texture_file(CARD_IMG_VGA)
	if img_preview_zx:
		img_preview_zx.texture = _load_texture_file(CARD_IMG_ZX)

func _setup_mode_select_card_fonts() -> void:
	var f_modern = _get_font_for_mode(Mode.MODERN)
	var f_vga = _get_font_for_mode(Mode.VGA)
	var f_zx = _get_font_for_mode(Mode.ZX)
	
	var card_m = get_node_or_null("ModeSelectScreen/Margin/VBoxModes/HBoxCards/CardModern")
	var card_v = get_node_or_null("ModeSelectScreen/Margin/VBoxModes/HBoxCards/CardVGA")
	var card_z = get_node_or_null("ModeSelectScreen/Margin/VBoxModes/HBoxCards/CardZX")
	
	if card_m and f_modern:
		_apply_font_to_subtree(card_m, f_modern)
		var badge = card_m.get_node_or_null("Margin/VBox/Badge")
		if badge:
			badge.add_theme_font_size_override("font_size", 16)
		var title = card_m.get_node_or_null("Margin/VBox/CardTitle")
		if title:
			title.add_theme_font_size_override("font_size", 34)
		var sub = card_m.get_node_or_null("Margin/VBox/CardSub")
		if sub:
			sub.add_theme_font_size_override("font_size", 18)
		var desc = card_m.get_node_or_null("Margin/VBox/Desc")
		if desc:
			desc.add_theme_font_size_override("font_size", 21)
			desc.add_theme_constant_override("line_spacing", 8)
		var btn = card_m.get_node_or_null("Margin/VBox/BtnSelectModern")
		if btn:
			btn.add_theme_font_size_override("font_size", 24)
			
	if card_v and f_vga:
		_apply_font_to_subtree(card_v, f_vga)
	if card_z and f_zx:
		_apply_font_to_subtree(card_z, f_zx)
		
	var title_sec = get_node_or_null("ModeSelectScreen/Margin/VBoxModes/TitleSection")
	if title_sec and f_modern:
		_apply_font_to_subtree(title_sec, f_modern)

func _apply_game_mode_font(mode: int) -> void:
	var font = _get_font_for_mode(mode)
	if not font:
		return
		
	if not self.theme:
		self.theme = Theme.new()
	self.theme.default_font = font
	self.theme.set_font("font", "Label", font)
	self.theme.set_font("font", "Button", font)
	self.theme.set_font("font", "LineEdit", font)
	self.theme.set_font("font", "OptionButton", font)
	self.theme.set_font("font", "PopupMenu", font)
	self.theme.set_font("font", "CheckBox", font)
	self.theme.set_font("normal_font", "RichTextLabel", font)
	self.theme.set_font("bold_font", "RichTextLabel", font)
	self.theme.set_font("italics_font", "RichTextLabel", font)
	self.theme.set_font("bold_italics_font", "RichTextLabel", font)
	self.theme.set_font("mono_font", "RichTextLabel", font)
	
	_apply_font_to_tree_except_mode_select(self, font)
	
	# Настройка масштаба и размеров шрифта под начертание каждого режима игры:
	var log_sz = 24
	var input_sz = 22
	var prompt_sz = 24
	var drop_sz = 18
	var title_sz = 28
	var status_sz = 17
	var exits_sz = 16
	var card_info_sz = 15
	var card_title_sz = 16
	var header_sz = 20
	var sub_sz = 14
	var btn_action_sz = 16
	var btn_dir_sz = 17
	var check_sz = 17
	var line_sep = 4
	
	if mode == Mode.ZX:
		log_sz = 16
		input_sz = 15
		prompt_sz = 16
		drop_sz = 14
		title_sz = 18
		status_sz = 13
		exits_sz = 12
		card_info_sz = 12
		card_title_sz = 13
		header_sz = 16
		sub_sz = 12
		btn_action_sz = 13
		btn_dir_sz = 14
		check_sz = 14
		line_sep = 2
	elif mode == Mode.VGA:
		log_sz = 20
		input_sz = 19
		prompt_sz = 20
		drop_sz = 16
		title_sz = 24
		status_sz = 15
		exits_sz = 14
		card_info_sz = 14
		card_title_sz = 15
		header_sz = 18
		sub_sz = 13
		btn_action_sz = 15
		btn_dir_sz = 16
		check_sz = 16
		line_sep = 3
	else: # Mode.MODERN (шрифт Greengoth_Regular.ttf)
		# В режиме Modern готический шрифт увеличен, чтобы текст читался легко, четко и без напряжения глаз
		log_sz = 24
		input_sz = 22
		prompt_sz = 24
		drop_sz = 18
		title_sz = 28
		status_sz = 17
		exits_sz = 16
		card_info_sz = 15
		card_title_sz = 16
		header_sz = 20
		sub_sz = 14
		btn_action_sz = 16
		btn_dir_sz = 17
		check_sz = 17
		line_sep = 4
		
	var gs = _get_game_state()
	var is_acc = gs.is_accessibility_mode if gs else false
	if is_acc:
		# Специально адаптированный крупный шрифт для слабовидящих
		log_sz = 30
		input_sz = 26
		prompt_sz = 28
		drop_sz = 22
		title_sz = 34
		status_sz = 22
		exits_sz = 20
		card_info_sz = 18
		card_title_sz = 20
		header_sz = 24
		sub_sz = 16
		btn_action_sz = 19
		btn_dir_sz = 22
		check_sz = 20
		line_sep = 6
		
	if version_label:
		version_label.add_theme_font_size_override("font_size", 16 if mode == Mode.ZX else 20)
		
	if output_log:
		output_log.add_theme_font_size_override("normal_font_size", log_sz)
		output_log.add_theme_font_size_override("bold_font_size", log_sz)
		output_log.add_theme_font_size_override("italics_font_size", log_sz)
		output_log.add_theme_font_size_override("bold_italics_font_size", log_sz)
		output_log.add_theme_font_size_override("mono_font_size", log_sz)
		output_log.add_theme_constant_override("line_separation", line_sep)
	if input_line:
		input_line.add_theme_font_size_override("font_size", input_sz)
	if prompt_label:
		prompt_label.add_theme_font_size_override("font_size", prompt_sz)
	if command_dropdown:
		command_dropdown.add_theme_font_size_override("font_size", drop_sz)
		var pop = command_dropdown.get_popup()
		if pop:
			pop.add_theme_font_size_override("font_size", drop_sz)
	if loc_title:
		loc_title.add_theme_font_size_override("font_size", title_sz)
	if status_info:
		status_info.add_theme_font_size_override("font_size", status_sz)
	if exits_info_label:
		exits_info_label.add_theme_font_size_override("font_size", exits_sz)
	if mode_info_label:
		mode_info_label.add_theme_font_size_override("font_size", card_info_sz)
	if health_info_label:
		health_info_label.add_theme_font_size_override("font_size", card_info_sz)
	if vis_info_label:
		vis_info_label.add_theme_font_size_override("font_size", card_info_sz)
	if companion_info_label:
		companion_info_label.add_theme_font_size_override("font_size", card_info_sz)
		
	var card_title_node = get_node_or_null("RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/StatusCard/Margin/VBoxCard/CardTitle")
	if card_title_node:
		card_title_node.add_theme_font_size_override("font_size", card_title_sz)
		
	var move_header = get_node_or_null("RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/MoveHeader")
	if move_header:
		move_header.add_theme_font_size_override("font_size", header_sz)
	var move_sub = get_node_or_null("RootMargin/VBoxMain/TopRow/LeftMovePanel/Margin/VBoxMove/MoveSub")
	if move_sub:
		move_sub.add_theme_font_size_override("font_size", sub_sz)
		
	var action_header = get_node_or_null("RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/ActionHeader")
	if action_header:
		action_header.add_theme_font_size_override("font_size", header_sz)
	var action_sub = get_node_or_null("RootMargin/VBoxMain/TopRow/RightActionPanel/Margin/VBoxAction/ActionSub")
	if action_sub:
		action_sub.add_theme_font_size_override("font_size", sub_sz)
		
	var dir_btns = [btn_nw, btn_n, btn_ne, btn_w, btn_e, btn_sw, btn_s, btn_se, btn_up, btn_dn]
	for b in dir_btns:
		if b:
			b.add_theme_font_size_override("font_size", btn_dir_sz)
			
	var act_btns = [btn_look, btn_inv, btn_wait, btn_take_all, btn_save, btn_load, btn_settings_game]
	for b in act_btns:
		if b:
			b.add_theme_font_size_override("font_size", btn_action_sz)
			
	if check_fullscreen:
		check_fullscreen.add_theme_font_size_override("font_size", check_sz)
	if check_accessibility:
		check_accessibility.add_theme_font_size_override("font_size", check_sz)
			
	# Черная окантовка шрифта для кнопок главного меню (чтобы шрифт четко читался на пестром фоне заставки)
	var title_btns = [btn_start_game, btn_title_load, btn_change_mode, btn_settings, btn_exit]
	for tb in title_btns:
		if tb:
			tb.add_theme_constant_override("outline_size", 8)
			tb.add_theme_color_override("font_outline_color", Color.BLACK)
			tb.add_theme_color_override("font_hover_outline_color", Color.BLACK)
			tb.add_theme_color_override("font_pressed_outline_color", Color.BLACK)
			tb.add_theme_color_override("font_focus_outline_color", Color.BLACK)
			tb.add_theme_color_override("font_disabled_outline_color", Color(0, 0, 0, 0.6))

func _apply_font_to_tree_except_mode_select(node: Node, font: Font) -> void:
	if node == mode_select_screen:
		return
	if node is Control:
		if node is RichTextLabel:
			node.add_theme_font_override("normal_font", font)
			node.add_theme_font_override("bold_font", font)
			node.add_theme_font_override("italics_font", font)
			node.add_theme_font_override("bold_italics_font", font)
			node.add_theme_font_override("mono_font", font)
		else:
			node.add_theme_font_override("font", font)
		if node is OptionButton:
			var popup = node.get_popup()
			if popup:
				popup.add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_to_tree_except_mode_select(child, font)

func _apply_font_to_subtree(node: Node, font: Font) -> void:
	if node is Control:
		if node is RichTextLabel:
			node.add_theme_font_override("normal_font", font)
			node.add_theme_font_override("bold_font", font)
			node.add_theme_font_override("italics_font", font)
			node.add_theme_font_override("bold_italics_font", font)
			node.add_theme_font_override("mono_font", font)
		else:
			node.add_theme_font_override("font", font)
		if node is OptionButton:
			var popup = node.get_popup()
			if popup:
				popup.add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_to_subtree(child, font)


func _update_header(room_id: int) -> void:
	var gs = _get_game_state()
	if not gs:
		return
		
	if loc_sub:
		loc_sub.visible = false
		loc_sub.text = ""
		
	if gs.game_won:
		loc_title.text = "ВЕЛИКАЯ ПОБЕДА! ВОЗВРАЩЕНИЕ В ХОББИТОН"
		return
		
	var room = gs.rooms.get(room_id, {})
	if room.is_empty():
		loc_title.text = "Неизвестная земля"
		return
		
	loc_title.text = room.get("name_ru", room.get("name", ""))

func _update_status_bar() -> void:
	var gs = _get_game_state()
	if not gs:
		return
		
	var mode_str = gs.get_current_mode_name()
	if mode_info_label:
		mode_info_label.text = "Режим: %s" % mode_str
		
	if health_info_label:
		health_info_label.text = "Здоровье: %d / 100" % gs.player_health
		
	var vis_str = "Невидим (Кольцо)" if gs.is_invisible else "Обычная"
	if vis_info_label:
		vis_info_label.text = "Видимость: %s" % vis_str
		
	var comp_in_room = []
	for n_id in gs.npcs.keys():
		var n = gs.npcs[n_id]
		if n.get("location", -1) == gs.current_room_id and not n.get("is_dead", false):
			comp_in_room.append(n.get("name_ru", n["name"]))
	if companion_info_label:
		if comp_in_room.size() > 0:
			companion_info_label.text = "Спутники: " + ", ".join(comp_in_room)
		else:
			companion_info_label.text = "Спутники: Рядом нет"

	if gs.game_won:
		status_info.text = "Триумф! | Здоровье: %d | Путешествие успешно завершено!" % gs.player_health
		return
		
	var phases = ["День", "Закат", "Ночь", "Рассвет"]
	var phase_str = phases[gs.day_phase]
	status_info.text = "Время: %s | Здоровье: %d | Видимость: %s" % [phase_str, gs.player_health, vis_str]

func _update_compass_buttons() -> void:
	var gs = _get_game_state()
	if not gs:
		return
		
	var is_dark = gs.is_dark_here()
	var room = gs.rooms.get(gs.current_room_id, {})
	var exits = room.get("exits", [])
	
	var available_dirs = {}
	var exits_text_list = []
	for ex in exits:
		var dir_code = ex["direction"]
		var dir_ru = ex.get("direction_ru", dir_code)
		available_dirs[dir_code] = ex
		available_dirs[dir_ru] = ex
		
		var dest_id = ex.get("dest", 0)
		var is_valid_dest = dest_id > 0 and gs.rooms.has(dest_id)
		var via_id = ex.get("via_obj", 0)
		if via_id > 0:
			var via_obj = gs.items.get(via_id)
			var via_name = via_obj.get("name_ru", "дверь") if via_obj else "преграда"
			if not is_valid_dest:
				exits_text_list.append("%s [%s (преграждает путь)]" % [dir_ru, via_name])
			else:
				var state = "(закрыто)" if (via_obj and not via_obj.get("is_open", true)) else "(открыто)"
				exits_text_list.append("%s [%s %s]" % [dir_ru, via_name, state])
		elif is_valid_dest:
			exits_text_list.append(dir_ru)
			
	if exits_info_label:
		if exits_text_list.size() > 0:
			exits_info_label.text = "Выходы: " + ", ".join(exits_text_list)
		else:
			exits_info_label.text = "Выходы: Нет видимых путей"

	var dir_buttons = {
		btn_n: "north",
		btn_s: "south",
		btn_e: "east",
		btn_w: "west",
		btn_ne: "northeast",
		btn_nw: "northwest",
		btn_se: "southeast",
		btn_sw: "southwest",
		btn_up: "up",
		btn_dn: "down"
	}
	
	for btn in dir_buttons.keys():
		var dir_code = dir_buttons[btn]
		if dir_code in available_dirs:
			var ex = available_dirs[dir_code]
			var dest_id = ex.get("dest", 0)
			var is_valid_dest = dest_id > 0 and gs.rooms.has(dest_id)
			var via_id = ex.get("via_obj", 0)
			
			btn.disabled = false
			if not is_valid_dest:
				var via_obj = gs.items.get(via_id) if via_id > 0 else null
				var vname = via_obj.get("name_ru", "препятствие") if via_obj else "препятствие"
				btn.modulate = Color(1.0, 0.25, 0.25, 1.0) if gs.is_accessibility_mode else Color(0.9, 0.4, 0.4, 0.9)
				btn.tooltip_text = "Путь прегражден: " + vname
			elif via_id > 0:
				var via_obj = gs.items.get(via_id)
				if via_obj and not via_obj.get("is_open", true):
					btn.modulate = Color(1.0, 0.9, 0.0, 1.0) if gs.is_accessibility_mode else Color(1.0, 0.82, 0.2, 1.0)
					btn.tooltip_text = "Путь закрыт: " + via_obj.get("name_ru", "дверь") + " (закрыто)"
				else:
					btn.modulate = Color(0.2, 1.0, 0.4, 1.0) if gs.is_accessibility_mode else Color(0.3, 1.0, 0.5, 1.0)
					btn.tooltip_text = "Идти на " + ex.get("direction_ru", dir_code)
			else:
				btn.modulate = Color(0.2, 1.0, 0.4, 1.0) if gs.is_accessibility_mode else Color(0.3, 1.0, 0.5, 1.0)
				btn.tooltip_text = "Идти на " + ex.get("direction_ru", dir_code)
		else:
			btn.disabled = true
			btn.modulate = Color(0.3, 0.35, 0.4, 0.25) if gs.is_accessibility_mode else Color(0.4, 0.45, 0.5, 0.35)
			btn.tooltip_text = "Путь недоступен"


	if is_dark:
		btn_look.modulate = Color(1.0, 0.7, 0.1, 1.0) if gs.is_accessibility_mode else Color(0.8, 0.6, 0.3, 0.8)
		btn_look.tooltip_text = "Вокруг темнота (нужен свет)"
	else:
		btn_look.modulate = Color(0.4, 0.95, 1.0, 1.0) if gs.is_accessibility_mode else Color(0.6, 0.9, 1.0, 1.0)
		btn_look.tooltip_text = "Осмотреться вокруг (О)"
		
	btn_wait.modulate = Color(1.0, 1.0, 0.2, 1.0) if gs.is_accessibility_mode else Color(1.0, 0.95, 0.6, 1.0)
	btn_inv.modulate = Color(0.3, 0.8, 1.0, 1.0) if gs.is_accessibility_mode else Color(0.7, 0.85, 1.0, 1.0)
	btn_take_all.modulate = Color(0.4, 1.0, 0.5, 1.0) if gs.is_accessibility_mode else Color(0.75, 1.0, 0.75, 1.0)
	btn_save.modulate = Color(0.3, 1.0, 0.6, 1.0) if gs.is_accessibility_mode else Color(0.65, 1.0, 0.75, 1.0)
	
	var has_save: bool = false
	if gs and gs.has_method("has_any_saves"):
		has_save = gs.has_any_saves()
	else:
		has_save = FileAccess.file_exists("user://savegame.json")
	btn_load.disabled = not has_save
	if has_save:
		btn_load.modulate = Color(0.5, 0.85, 1.0, 1.0)
	else:
		btn_load.modulate = Color(0.4, 0.45, 0.5, 0.35)

func _update_command_dropdown() -> void:
	if not command_dropdown:
		return
		
	command_dropdown.clear()
	command_dropdown.add_item("Выбрать команду...", 0)
	command_dropdown.set_item_disabled(0, true)
	
	var gs = _get_game_state()
	if not gs:
		return
		
	var room = gs.rooms.get(gs.current_room_id, {})
	var exits = room.get("exits", [])
	
	# 1. Доступные направления движения
	for ex in exits:
		var dest_id = ex.get("dest", 0)
		if dest_id > 0 and gs.rooms.has(dest_id):
			var dir_ru = ex.get("direction_ru", ex["direction"])
			var idx = command_dropdown.item_count
			command_dropdown.add_item("Идти: " + dir_ru, idx)
			command_dropdown.set_item_metadata(idx, dir_ru)
			
	# Особые действия у Заколдованной реки на берегу 66
	if gs.current_room_id == 66:
		var boat = gs.items.get(41)
		var rope = gs.items.get(18)
		if boat and boat.get("location") == 67 and rope and (rope.get("location") == 0 or rope.get("location") == 66):
			var idx_rope = command_dropdown.item_count
			command_dropdown.add_item("Зацепить и притянуть лодку веревкой", idx_rope)
			command_dropdown.set_item_metadata(idx_rope, "притянуть лодку веревкой")

	# Действия внутри лодки / бочки
	if gs.inside_container_id == 41:
		var idx_exit = command_dropdown.item_count
		command_dropdown.add_item("Вылезти из лодки на берег", idx_exit)
		command_dropdown.set_item_metadata(idx_exit, "вылезти")
		if gs.current_room_id == 66:
			var idx_row = command_dropdown.item_count
			command_dropdown.add_item("Плыть на восток (к восточному берегу)", idx_row)
			command_dropdown.set_item_metadata(idx_row, "восток")
		elif gs.current_room_id == 67:
			var idx_row = command_dropdown.item_count
			command_dropdown.add_item("Плыть на запад (к западному берегу)", idx_row)
			command_dropdown.set_item_metadata(idx_row, "запад")
	elif gs.inside_container_id != -1:
		var idx_exit = command_dropdown.item_count
		command_dropdown.add_item("Вылезти наружу", idx_exit)
		command_dropdown.set_item_metadata(idx_exit, "вылезти")
		
	# 2. Предметы в текущей локации
	var items_in_room = []
	for it_id in gs.items.keys():
		var it = gs.items[it_id]
		if it.get("location", -999) == gs.current_room_id:
			items_in_room.append(it)
			
	for it in items_in_room:
		var name_ru = it.get("name_ru", it["name"])
		var can_take = it.get("mass", 0) <= gs.player_max_mass and not it.get("is_fixed", false)
		
		if can_take:
			var idx_take = command_dropdown.item_count
			command_dropdown.add_item("Взять: " + name_ru, idx_take)
			command_dropdown.set_item_metadata(idx_take, "взять " + name_ru)
			
		var idx_look = command_dropdown.item_count
		command_dropdown.add_item("Осмотреть: " + name_ru, idx_look)
		command_dropdown.set_item_metadata(idx_look, "осмотреть " + name_ru)
		
		if it["id"] in [19, 41] and gs.inside_container_id == -1:
			var idx_enter = command_dropdown.item_count
			command_dropdown.add_item("Залезть в: " + name_ru, idx_enter)
			command_dropdown.set_item_metadata(idx_enter, "залезть в " + name_ru)
		
		if it.get("is_container", false) or "двер" in name_ru.to_lower():
			if not it.get("is_open", false):
				var idx_open = command_dropdown.item_count
				command_dropdown.add_item("Открыть: " + name_ru, idx_open)
				command_dropdown.set_item_metadata(idx_open, "открыть " + name_ru)
			else:
				var idx_close = command_dropdown.item_count
				command_dropdown.add_item("Закрыть: " + name_ru, idx_close)
				command_dropdown.set_item_metadata(idx_close, "закрыть " + name_ru)
				
				if it.get("is_container", false):
					var idx_in = command_dropdown.item_count
					command_dropdown.add_item("Заглянуть в: " + name_ru, idx_in)
					command_dropdown.set_item_metadata(idx_in, "осмотреть внутри " + name_ru)
					
	# 3. Предметы в инвентаре
	for it_id in gs.items.keys():
		var it = gs.items[it_id]
		if it.get("location", -999) == 0:
			var name_ru = it.get("name_ru", it["name"])
			var idx_drop = command_dropdown.item_count
			command_dropdown.add_item("Бросить: " + name_ru, idx_drop)
			command_dropdown.set_item_metadata(idx_drop, "бросить " + name_ru)
			
			var idx_ex = command_dropdown.item_count
			command_dropdown.add_item("Осмотреть в сумке: " + name_ru, idx_ex)
			command_dropdown.set_item_metadata(idx_ex, "осмотреть " + name_ru)
			
			if it_id == 16:
				var idx_ring = command_dropdown.item_count
				if not gs.is_invisible:
					command_dropdown.add_item("Надеть Кольцо (невидимость)", idx_ring)
					command_dropdown.set_item_metadata(idx_ring, "надеть кольцо")
				else:
					command_dropdown.add_item("Снять Кольцо (стать видимым)", idx_ring)
					command_dropdown.set_item_metadata(idx_ring, "снять кольцо")
					
	# 4. Персонажи в комнате
	for n_id in gs.npcs.keys():
		var n = gs.npcs[n_id]
		if n.get("location", -999) == gs.current_room_id and not n.get("is_dead", false):
			var n_name = n.get("name_ru", n["name"])
			var idx_talk = command_dropdown.item_count
			command_dropdown.add_item("Говорить с: " + n_name, idx_talk)
			command_dropdown.set_item_metadata(idx_talk, "говорить с " + n_name)
			
			var idx_ex_n = command_dropdown.item_count
			command_dropdown.add_item("Осмотреть: " + n_name, idx_ex_n)
			command_dropdown.set_item_metadata(idx_ex_n, "осмотреть " + n_name)
			
			if n_id == 1:
				var idx_th1 = command_dropdown.item_count
				command_dropdown.add_item("Торин, следуй за мной", idx_th1)
				command_dropdown.set_item_metadata(idx_th1, "Торин, следуй за мной")
				
				var idx_th2 = command_dropdown.item_count
				command_dropdown.add_item("Торин, открой дверь", idx_th2)
				command_dropdown.set_item_metadata(idx_th2, "Торин, открой дверь")
				
			elif n_id == 2:
				var idx_g = command_dropdown.item_count
				command_dropdown.add_item("Гэндальф, дай совет", idx_g)
				command_dropdown.set_item_metadata(idx_g, "Гэндальф, дай совет")
				
			elif n_id == 7:
				var idx_gol = command_dropdown.item_count
				command_dropdown.add_item("Загадать загадку Голлуму", idx_gol)
				command_dropdown.set_item_metadata(idx_gol, "загадать загадку")
				
	# 5. Базовые действия
	var base_actions = [
		["Осмотреться вокруг", "осмотреться"],
		["Инвентарь (вещи)", "инвентарь"],
		["Подождать ход", "ждать"],
		["Взять всё на локации", "взять всё"]
	]
	for ba in base_actions:
		var idx_ba = command_dropdown.item_count
		command_dropdown.add_item(ba[0], idx_ba)
		command_dropdown.set_item_metadata(idx_ba, ba[1])
		
	command_dropdown.selected = 0

func _on_dropdown_command_selected(index: int) -> void:
	if index <= 0:
		return
	var cmd = command_dropdown.get_item_metadata(index)
	if cmd is String and not cmd.is_empty():
		input_line.text = cmd
		_on_input_submitted(cmd)
	command_dropdown.selected = 0
