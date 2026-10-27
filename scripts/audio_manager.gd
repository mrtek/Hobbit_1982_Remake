class_name HobbitAudioManager
extends Node

var audio_player: AudioStreamPlayer
var current_theme: String = ""

const OST_DIR = "res://assets/music/"

const THEMES = {
	"fanfare": "01 Fanfare.mp3",
	"hobbit_hole": "02 Hobbit Hole.mp3",
	"trolls": "03 Trolls.mp3",
	"goblins": "04 Goblins.mp3",
	"mirkwood": "05 Mirkwood.mp3",
	"desolation": "06 Desolation of Smaug.mp3"
}

var music_volume: float = 0.75
var settings_fullscreen: bool = false

var pending_theme: String = ""
var _fade_tween: Tween = null
var _pre_accessibility_volume: float = 0.75

const FADE_OUT_DURATION: float = 1.0
const FADE_IN_DURATION: float = 1.0

var cached_game_state: Node = null

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

func _ensure_player() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		if is_inside_tree():
			add_child(audio_player)
	elif not audio_player.is_inside_tree() and is_inside_tree():
		add_child(audio_player)
	set_music_volume(music_volume)

func _ready() -> void:
	_ensure_player()
	_load_settings()
	set_music_volume(music_volume)
	
	var gs = _get_game_state()
	if gs:
		gs.room_changed.connect(_on_room_changed)
		gs.game_mode_changed.connect(_on_game_mode_changed)
		gs.accessibility_mode_changed.connect(_on_accessibility_mode_changed)

func _on_accessibility_mode_changed(enabled: bool) -> void:
	if enabled:
		if music_volume > 0.25:
			_pre_accessibility_volume = music_volume
		set_music_volume(0.20)
	else:
		set_music_volume(_pre_accessibility_volume)

func get_pre_accessibility_volume() -> float:
	return _pre_accessibility_volume

func set_pre_accessibility_volume(val: float) -> void:
	_pre_accessibility_volume = clamp(val, 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_current_settings()

func _on_game_mode_changed(_new_mode: int) -> void:
	if current_theme != "":
		play_theme(current_theme, true)
	save_current_settings()

func get_theme_filename(theme_name: String) -> String:
	var base_name = THEMES.get(theme_name, "")
	if base_name.is_empty():
		return ""
		
	var mode_val = 0
	var gs = _get_game_state()
	if gs:
		mode_val = int(gs.game_mode)
		
	match mode_val:
		1: # VGA
			return base_name.replace(".mp3", " SB.mp3")
		2: # ZX
			return base_name.replace(".mp3", " SID.mp3")
		_:
			return base_name

func _get_target_db() -> float:
	if music_volume <= 0.001:
		return -80.0
	return linear_to_db(music_volume)

func set_music_volume(linear_val: float) -> void:
	music_volume = clamp(linear_val, 0.0, 1.0)
	if audio_player:
		if _fade_tween == null or not _fade_tween.is_valid():
			audio_player.volume_db = _get_target_db()

func get_music_volume() -> float:
	return music_volume

func is_fullscreen() -> bool:
	return settings_fullscreen

func save_current_settings() -> void:
	var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	settings_fullscreen = is_fs
	save_settings(is_fs)

func save_settings(fullscreen: bool) -> void:
	settings_fullscreen = fullscreen
	var f = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		var mode_val = 0
		var gs = _get_game_state()
		var is_acc = false
		if gs:
			mode_val = int(gs.game_mode)
			is_acc = gs.is_accessibility_mode
		var d = {
			"music_volume": _pre_accessibility_volume if is_acc else music_volume,
			"pre_accessibility_volume": _pre_accessibility_volume,
			"fullscreen": fullscreen,
			"game_mode": mode_val,
			"accessibility": is_acc
		}
		f.store_string(JSON.stringify(d))

func _load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var f = FileAccess.open("user://settings.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed and parsed is Dictionary:
			if parsed.has("pre_accessibility_volume"):
				_pre_accessibility_volume = float(parsed["pre_accessibility_volume"])
			elif parsed.has("music_volume"):
				_pre_accessibility_volume = float(parsed["music_volume"])
				
			if parsed.has("music_volume"):
				music_volume = float(parsed["music_volume"])
			if parsed.has("fullscreen"):
				settings_fullscreen = bool(parsed["fullscreen"])
				call_deferred("apply_fullscreen", settings_fullscreen)
			if parsed.has("game_mode"):
				var m = int(parsed["game_mode"])
				var gs = _get_game_state()
				if gs and m in [0, 1, 2]:
					gs.set_game_mode(m)
			if parsed.has("accessibility"):
				var is_acc = bool(parsed["accessibility"])
				var gs = _get_game_state()
				if gs:
					gs.is_accessibility_mode = is_acc
				if is_acc:
					music_volume = 0.20

func apply_fullscreen(fs: bool) -> void:
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		var screen_id = DisplayServer.window_get_current_screen()
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
		var target_w = min(1280, int(screen_rect.size.x * 0.75))
		var target_h = int(target_w * 9.0 / 16.0)
		var win_size = Vector2i(target_w, target_h)
		DisplayServer.window_set_size(win_size)
		var win_pos = screen_rect.position + (screen_rect.size - win_size) / 2
		DisplayServer.window_set_position(win_pos)

func _apply_fullscreen(fs: bool) -> void:
	apply_fullscreen(fs)

# Room ID to theme mapping according to music_triggers.json (Commodore 64 & ZX original specifications)
const ROOM_THEMES = {
	"hobbit_hole": [1, 2, 3, 4, 46, 47],
	"mirkwood": [9, 28, 30, 32, 66, 67, 33, 34, 35, 38, 40, 74],
	"trolls": [5, 6, 8, 10, 11, 12, 20, 21, 22, 23, 24, 25, 48, 49, 50, 68, 70, 71, 72, 73, 75, 76, 77, 78, 79],
	"goblins": [7, 13, 14, 15, 16, 17, 18, 19, 26, 27, 29, 31, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 69],
	"desolation": [36, 37, 39, 41, 42, 43, 44, 45, 51]
}

func get_theme_for_room(room_id: int) -> String:
	for theme in ROOM_THEMES.keys():
		if room_id in ROOM_THEMES[theme]:
			return theme
	return "hobbit_hole"

func play_initial_music() -> void:
	var gs = _get_game_state()
	if gs and gs.current_room_id > 0:
		update_location_music(gs.current_room_id)
	else:
		play_theme("hobbit_hole")

func _on_room_changed(new_room_id: int) -> void:
	update_location_music(new_room_id)

func _load_audio_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	var p = path
	if not FileAccess.file_exists(p):
		p = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(p):
		var f = FileAccess.open(p, FileAccess.READ)
		if f:
			var bytes = f.get_buffer(f.get_length())
			var stream = AudioStreamMP3.new()
			stream.data = bytes
			return stream
	return null

func _create_tween_safe() -> Tween:
	if is_inside_tree():
		return create_tween()
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		return loop.create_tween()
	return null

func _apply_theme_now(theme_name: String) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	var file_name = get_theme_filename(theme_name)
	var path = OST_DIR + file_name
	var stream = _load_audio_stream(path)
	if stream:
		if stream is AudioStreamMP3:
			stream.loop = true
		audio_player.stream = stream
		audio_player.volume_db = _get_target_db()
		if audio_player.is_inside_tree():
			audio_player.play()
		current_theme = theme_name
		pending_theme = ""
	else:
		print("AudioManager: Failed to load mp3 at ", path)
		stop_music(false)

func _fade_in_theme(theme_name: String) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	var file_name = get_theme_filename(theme_name)
	var path = OST_DIR + file_name
	var stream = _load_audio_stream(path)
	if not stream:
		print("AudioManager: Failed to load mp3 at ", path)
		stop_music(false)
		return

	if stream is AudioStreamMP3:
		stream.loop = true
	audio_player.stream = stream
	audio_player.volume_db = -80.0
	if audio_player.is_inside_tree():
		audio_player.play()
	current_theme = theme_name
	pending_theme = ""

	_fade_tween = _create_tween_safe()
	if not _fade_tween:
		audio_player.volume_db = _get_target_db()
		return

	_fade_tween.tween_property(audio_player, "volume_db", _get_target_db(), FADE_IN_DURATION)\
		.from(-80.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func play_theme(theme_name: String, force_reload: bool = false, fade: bool = true) -> void:
	_ensure_player()
	
	if not THEMES.has(theme_name):
		print("AudioManager: Unknown theme '", theme_name, "'")
		stop_music(fade)
		return

	# Если эта музыка уже активна или уже идет переход к ней — ничего не делаем
	if not force_reload:
		if current_theme == theme_name and (pending_theme == "" or pending_theme == theme_name):
			return
		if pending_theme == theme_name:
			return

	pending_theme = theme_name

	if not fade:
		_apply_theme_now(theme_name)
		return

	# Если музыка не играла — сразу запускаем новую с плавным проявлением
	if current_theme.is_empty():
		_fade_in_theme(theme_name)
		return

	# Плавная последовательная смена (fade):
	# 1) Старая мелодия плавно затухает до полной тишины (1.0 сек)
	# 2) В момент тишины подменяется трек и запускается с -80 dB
	# 3) Новая мелодия плавно проявляется из тишины (1.0 сек)
	# Суммарное время перехода = 2.0 секунды
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = _create_tween_safe()
	if not _fade_tween:
		_apply_theme_now(theme_name)
		return

	# Шаг 1: Затухание текущего трека
	_fade_tween.tween_property(audio_player, "volume_db", -80.0, FADE_OUT_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Шаг 2: Подмена потока в тишине
	_fade_tween.tween_callback(func():
		var target = pending_theme
		if target.is_empty():
			if audio_player.is_inside_tree():
				audio_player.stop()
			current_theme = ""
			return
		var file_name = get_theme_filename(target)
		var path = OST_DIR + file_name
		var stream = _load_audio_stream(path)
		if stream:
			if stream is AudioStreamMP3:
				stream.loop = true
			audio_player.stream = stream
			audio_player.volume_db = -80.0
			if audio_player.is_inside_tree():
				audio_player.play()
			current_theme = target
		else:
			print("AudioManager: Failed to load mp3 at ", path)
			if audio_player.is_inside_tree():
				audio_player.stop()
			current_theme = ""
	)
	
	# Шаг 3: Проявление нового трека из тишины
	_fade_tween.tween_property(audio_player, "volume_db", _get_target_db(), FADE_IN_DURATION)\
		.from(-80.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	_fade_tween.tween_callback(func():
		pending_theme = ""
		if audio_player:
			audio_player.volume_db = _get_target_db()
	)

func stop_music(fade: bool = true) -> void:
	_ensure_player()
	pending_theme = ""
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if current_theme.is_empty():
		return
	if fade:
		_fade_tween = _create_tween_safe()
		if _fade_tween:
			_fade_tween.tween_property(audio_player, "volume_db", -80.0, FADE_OUT_DURATION)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_fade_tween.tween_callback(func():
				if audio_player.is_inside_tree():
					audio_player.stop()
				current_theme = ""
			)
			return
	if audio_player.is_inside_tree():
		audio_player.stop()
	current_theme = ""

func update_location_music(param) -> void:
	var new_theme = ""
	if param is int:
		new_theme = get_theme_for_room(param)
	elif param is String:
		if THEMES.has(param):
			new_theme = param
		else:
			var ln = param.to_lower()
			if "тролл" in ln or "troll" in ln:
				new_theme = "trolls"
			elif "гоблин" in ln or "goblin" in ln or "пещер" in ln or "dungeon" in ln or "озер" in ln or "lake" in ln or "паук" in ln or "spider" in ln:
				new_theme = "goblins"
			elif "лихолес" in ln or "forest" in ln or "эльф" in ln or "ривенделл" in ln or "rivendell" in ln or "беорн" in ln or "beorn" in ln or "озерн" in ln or "lake-town" in ln:
				new_theme = "mirkwood"
			elif "смог" in ln or "smaug" in ln or "дракон" in ln or "dragon" in ln or "одинокая" in ln or "lonely" in ln or "пустош" in ln or "desolation" in ln:
				new_theme = "desolation"
			else:
				new_theme = "hobbit_hole"
				
	if new_theme != "":
		var already_active = (new_theme == current_theme and (pending_theme == "" or pending_theme == new_theme))
		var already_pending = (new_theme == pending_theme)
		if not already_active and not already_pending:
			play_theme(new_theme)


