class_name HobbitCreditsScreen
extends Control

signal closed()

@onready var btn_back: Button = %BtnBack
@onready var scroll_content: Control = %ScrollContent
@onready var text_vbox: VBoxContainer = %TextVBox
@onready var pic_left: TextureRect = %PicLeft
@onready var pic_right: TextureRect = %PicRight
@onready var speed_hint: Label = %SpeedHint

const BASE_SPEED: float = 46.0
const BOOST_SPEED: float = 230.0

var is_active: bool = false
var scroll_pos_y: float = 1080.0
var content_height: float = 2400.0

var loaded_textures: Array[Texture2D] = []
var current_img_index: int = 0
var cycle_timer: float = 0.0
var active_side_is_left: bool = true

var tween_left: Tween = null
var tween_right: Tween = null

const Y_POSITIONS_LEFT: Array[float] = [120.0, 360.0, 600.0]
const Y_POSITIONS_RIGHT: Array[float] = [160.0, 400.0, 640.0]
var y_index_left: int = 0
var y_index_right: int = 0

var cached_audio_manager: Node = null

func _get_audio_manager() -> Node:
	if cached_audio_manager:
		return cached_audio_manager
	if is_inside_tree() and get_tree().root:
		if get_tree().root.has_node("AudioManager"):
			cached_audio_manager = get_tree().root.get_node("AudioManager")
			return cached_audio_manager
		for child in get_tree().root.get_children():
			if "play_theme" in child and "current_theme" in child:
				cached_audio_manager = child
				return cached_audio_manager
	return null

func _ready() -> void:
	visible = false
	if btn_back:
		btn_back.focus_mode = Control.FOCUS_ALL
		if not btn_back.pressed.is_connected(close_credits):
			btn_back.pressed.connect(close_credits)
	_load_all_credits_images()

func open_credits() -> void:
	visible = true
	is_active = true
	scroll_pos_y = 1080.0
	if scroll_content:
		scroll_content.position.y = scroll_pos_y
		
	var gs = null
	if is_inside_tree() and get_tree().root and get_tree().root.has_node("GameState"):
		gs = get_tree().root.get_node("GameState")
	var is_en = gs.is_english() if (gs and gs.has_method("is_english")) else false
	if btn_back:
		btn_back.text = "← MENU" if is_en else "← В МЕНЮ"
	if speed_hint:
		speed_hint.text = "[SPACE] Speed up / [ESC] Exit" if is_en else "[ПРОБЕЛ] Ускорить / [ESC] Выйти"

	if btn_back and btn_back.is_inside_tree():
		btn_back.grab_focus()
	
	if text_vbox:
		# Force layout update to know exact content height
		content_height = text_vbox.get_combined_minimum_size().y
		if content_height < 1500.0:
			content_height = 2400.0
			
	# Start music
	var am = _get_audio_manager()
	if am and am.has_method("play_theme"):
		am.play_theme("fanfare")
		
	# Refresh image list if new ones were added
	if loaded_textures.is_empty():
		_load_all_credits_images()
		
	# Reset pictures
	if pic_left:
		pic_left.modulate.a = 0.0
	if pic_right:
		pic_right.modulate.a = 0.0
		
	cycle_timer = 0.5 # Start first picture almost immediately
	active_side_is_left = true
	
	# Release any UI focus so Space won't trigger buttons
	var vp = get_viewport()
	if vp:
		var focused = vp.gui_get_focus_owner()
		if focused:
			focused.release_focus()

func close_credits() -> void:
	is_active = false
	visible = false
	if tween_left and tween_left.is_valid():
		tween_left.kill()
	if tween_right and tween_right.is_valid():
		tween_right.kill()
	closed.emit()

func _process(delta: float) -> void:
	if not visible or not is_active:
		return
		
	# 1. Scrolling
	var is_space_pressed = Input.is_key_pressed(KEY_SPACE)
	var speed = BOOST_SPEED if is_space_pressed else BASE_SPEED
	
	scroll_pos_y -= speed * delta
	if scroll_content:
		scroll_content.position.y = scroll_pos_y
		
	# Loop back when entire text has scrolled out of view
	if scroll_pos_y < -content_height - 150.0:
		scroll_pos_y = 1080.0
		
	# 2. Image cycling
	if not loaded_textures.is_empty():
		cycle_timer += delta
		if cycle_timer >= 4.0:
			cycle_timer = 0.0
			_trigger_next_image()

func _input(event: InputEvent) -> void:
	if not visible or not is_active:
		return
	var vp = get_viewport()
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			# Поглощаем событие пробела, чтобы ни одна кнопка интерфейса не нажималась
			if vp:
				vp.set_input_as_handled()
			return
		if event.pressed:
			if event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
				close_credits()
				if vp:
					vp.set_input_as_handled()
			elif event.keycode == KEY_UP:
				scroll_pos_y += 80.0
				if vp:
					vp.set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				scroll_pos_y -= 80.0
				if vp:
					vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_pos_y += 60.0
			if vp:
				vp.set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_pos_y -= 60.0
			if vp:
				vp.set_input_as_handled()

func _trigger_next_image() -> void:
	if loaded_textures.is_empty():
		return
		
	var tex = loaded_textures[current_img_index % loaded_textures.size()]
	current_img_index += 1
	
	if active_side_is_left:
		_fade_picture(pic_left, tex, true)
	else:
		_fade_picture(pic_right, tex, false)
		
	active_side_is_left = not active_side_is_left

func _fade_picture(pic: TextureRect, new_tex: Texture2D, is_left: bool) -> void:
	if not pic:
		return
		
	var tw = create_tween()
	if is_left:
		if tween_left and tween_left.is_valid():
			tween_left.kill()
		tween_left = tw
	else:
		if tween_right and tween_right.is_valid():
			tween_right.kill()
		tween_right = tw
		
	# 1. Fade out current texture if visible
	if pic.modulate.a > 0.05:
		tw.tween_property(pic, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
		
	# 2. Swap texture and pick new position
	tw.tween_callback(func():
		pic.texture = new_tex
		var target_y = 0.0
		if is_left:
			target_y = Y_POSITIONS_LEFT[y_index_left % Y_POSITIONS_LEFT.size()]
			y_index_left += 1
		else:
			target_y = Y_POSITIONS_RIGHT[y_index_right % Y_POSITIONS_RIGHT.size()]
			y_index_right += 1
		pic.position.y = target_y
	)
	
	# 3. Fade in with subtle float animation
	tw.tween_property(pic, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(3.5)
	tw.tween_property(pic, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)

func _load_all_credits_images() -> void:
	loaded_textures.clear()
	var paths_to_scan: Array[String] = [
		OS.get_executable_path().get_base_dir().path_join("credits_images"),
		OS.get_executable_path().get_base_dir().path_join("assets_ 4_godot_ready/credits_images"),
		"G:/Coding/The Hobbit Remake/assets_ 4_godot_ready/credits_images/",
		ProjectSettings.globalize_path("res://../assets_ 4_godot_ready/credits_images/"),
		"res://assets/images/credits/"
	]
	
	var discovered_files: Dictionary = {}
	
	for dir_path in paths_to_scan:
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var ext = file_name.get_extension().to_lower()
					if ext in ["jpg", "jpeg", "png", "webp"]:
						var full_path = dir_path.path_join(file_name)
						discovered_files[file_name] = full_path
				file_name = dir.get_next()
			dir.list_dir_end()
			
	var sorted_names = discovered_files.keys()
	sorted_names.sort()
	
	for fname in sorted_names:
		var p = discovered_files[fname]
		var tex = _load_texture_from_path(p)
		if tex:
			loaded_textures.append(tex)
			
	print("[CreditsScreen] Successfully loaded %d credits images." % loaded_textures.size())

func _load_texture_from_path(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var global_p = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_p):
		var img = Image.load_from_file(global_p)
		if img:
			return ImageTexture.create_from_image(img)
	return null
