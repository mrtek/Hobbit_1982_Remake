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
	apply_language(is_en)

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

func apply_language(is_en: bool) -> void:
	if btn_back:
		btn_back.text = "← MENU" if is_en else "← В МЕНЮ"
	if speed_hint:
		speed_hint.text = "[SPACE] Speed up / [ESC] Exit" if is_en else "[ПРОБЕЛ] Ускорить / [ESC] Выйти"
	var subtitle = get_node_or_null("ScrollArea/ScrollContent/TextVBox/GameSubtitle")
	if subtitle:
		subtitle.text = "REMAKE OF THE CULT ADVENTURE (1982)" if is_en else "РЕМЕЙК КУЛЬТОВОГО ПРИКЛЮЧЕНИЯ (1982)"
	var ha = get_node_or_null("ScrollArea/ScrollContent/TextVBox/HeaderAuthor")
	if ha:
		ha.text = "REMAKE AUTHOR" if is_en else "АВТОР РЕМЕЙКА"
	var hh = get_node_or_null("ScrollArea/ScrollContent/TextVBox/HeaderHistory")
	if hh:
		hh.text = "ABOUT THE ORIGINAL GAME" if is_en else "О СОЗДАНИИ ЭТОЙ ИГРЫ"
	var ht = get_node_or_null("ScrollArea/ScrollContent/TextVBox/HistoryText")
	if ht:
		ht.text = ("This project is both a tribute to one of the most revolutionary and significant games in computer gaming history, and a way to fulfill a lifelong personal dream — ever since childhood, I wanted to beat this game :)\n\nReleased in 1982 by Melbourne House for the ZX Spectrum, Commodore 64 and other platforms, 'The Hobbit' became a true masterpiece of the golden age of interactive fiction.\n\nThe original creators — Philip Mitchell and Veronika Megler — were decades ahead of their time. Their natural language parser 'Inglish' allowed players to formulate complex commands, converse with companions, and interact with a living physics-driven world like no other game of that era." if is_en else "Этот проект — дань уважения одной из самых революционных и значимых игр в истории компьютерных развлечений, а также для закрытия личного гештальта, с детства хотел пройти эту игру :)\n\nВыпущенная в 1982 году австралийской студией Melbourne House для ZX Spectrum, Commodore 64 и других платформ, «The Hobbit» стала настоящим шедевром золотого века интерактивной литературы.\n\nСоздатели оригинала — Филип Митчелл (Philip Mitchell) и Вероника Меглер (Veronika Megler) — опередили своё время на десятилетия. Их парсер естественного языка «Inglish» позволял формулировать сложные команды, общаться со спутниками и взаимодействовать с физическим миром так, как не могла ни одна другая игра той эпохи.")
	var hr = get_node_or_null("ScrollArea/ScrollContent/TextVBox/HeaderRemake")
	if hr:
		hr.text = "REMAKE PHILOSOPHY" if is_en else "ФИЛОСОФИЯ РЕМЕЙКА"
	var rt = get_node_or_null("ScrollArea/ScrollContent/TextVBox/RemakeText")
	if rt:
		rt.text = ("The goal of this Godot 4.3 remake is to preserve the unforgettable atmosphere of the original while pairing authentic simulation with modern conveniences:\n\n- Living Autonomous World (WorldSim): Thorin Oakenshield, Gandalf, Elrond, Bard the Bowman, Gollum and ferocious trolls live their own lives, moving across Middle-earth and reacting to events independently of Bilbo.\n\n- Physics Model: Every item has weight, size and unique properties. Containers can be opened, examined, used to store items, or even climbed into!\n\n- Bilingual Natural Language Parser: Full support for both English (the authentic 1982 syntax) and Russian grammar.\n\n- 79 canonical locations, 43 interactive items and 17 characters from the Professor's timeless tale." if is_en else "Цель ремейка на движке Godot 4.3 — сохранить ту самую неповторимую атмосферу оригинала, соединив аутентичную симуляцию с комфортом современных технологий:\n\n- Живой автономный мир (WorldSim): Торин Оукеншильд, Гэндальф, Элронд, Бард Лучник, Голлум и свирепые тролли живут своей жизнью, перемещаются по Средиземью и реагируют на события независимо от присутствия игрока.\n\n- Физическая модель: каждый предмет обладает весом, объёмом и уникальными свойствами. Контейнеры можно открывать, заглядывать внутрь, прятать в них вещи и даже залезать в них самому!\n\n- Умный двуязычный парсер: поддержка оригинального синтаксиса 1982 года и русской грамматики.\n\n- 79 канонических локаций, 43 интерактивных предмета и 17 персонажей из повести Профессора.")
	var hm = get_node_or_null("ScrollArea/ScrollContent/TextVBox/HeaderModes")
	if hm:
		hm.text = "THREE ERAS IN ONE GAME" if is_en else "ТРИ ЭПОХИ В ОДНОЙ ИГРЕ"
	var mt = get_node_or_null("ScrollArea/ScrollContent/TextVBox/ModesText")
	if mt:
		mt.text = ("Players can switch between three eras at any time:\n\n- 'MODERN EDITION'\nHigh-definition detailed artwork, Greengoth fantasy typography and an orchestral score.\n\n- 'RETRO (VGA)'\nThe atmosphere of the 90s MS-DOS golden era: 256-color palette, DOS2000 font and Sound Blaster music.\n\n- 'CLASSIC (ZX SPECTRUM)'\nPrimal 1982 nostalgia: genuine 8-bit graphics, ZX Spectrum font and warm analog SID / AY chiptunes." if is_en else "Игрок может в любой момент переключиться между тремя эпохами:\n\n- «СОВРЕМЕННЫЙ (MODERN)»\nДетализированные полноцветные HD-иллюстрации, фэнтезийный шрифт Greengoth и богатый оркестровый саундтрек.\n\n- «РЕТРО (VGA)»\nАтмосфера золотой эры MS-DOS 90-х: 256-цветная палитра, шрифт DOS2000 и аутентичное звучание звуковых карт Sound Blaster.\n\n- «КЛАССИЧЕСКИЙ (ZX SPECTRUM)»\nПервозданная романтика 1982 года: подлинная 8-битная графика, шрифт ZX Spectrum 7 и тёплый аналоговый чиптюн-звук SID / AY.")
	var ht_th = get_node_or_null("ScrollArea/ScrollContent/TextVBox/HeaderThanks")
	if ht_th:
		ht_th.text = "SPECIAL THANKS" if is_en else "БЛАГОДАРНОСТИ"
	var tt = get_node_or_null("ScrollArea/ScrollContent/TextVBox/ThanksText")
	if tt:
		tt.text = ("To J.R.R. Tolkien — for the immortal world of Middle-earth, a realm one wishes to return to again and again.\n\nTo Philip Mitchell and Veronika Megler — for their pioneering daring and for crafting the 1982 masterpiece.\n\nTo the creators and community of the Godot Engine.\n\nTo the creator of the portable YuE2-Studio build: https://github.com/timoncool/YuE2-Studio\n\nTo all the wonderful people thanks to whom I have access to Antigravity (you know who you are :) )\n\nTo the retro-gaming community and all devoted fans of interactive adventures.\n\nAnd to YOU, dear player, for embarking on this journey There and Back Again!" if is_en else "Дж. Р. Р. Толкину — за бессмертный мир Средиземья, в который хочется возвращаться снова и снова.\n\nФилипу Митчеллу и Веронике Меглер — за дерзость первопроходцев и создание шедевра 1982 года.\n\nСоздателям и сообществу игрового движка Godot Engine.\n\nСоздателю портативной сборки YuE2-Studio https://github.com/timoncool/YuE2-Studio\n\nВсем людям, благодаря кому у меня есть доступ к Antigravity (вы поняли о чем я :) )\n\nРетро-сообществу и всем преданным любителям текстовых квестов.\n\nИ тебе, дорогой игрок, за то, что отправился в это приключение «Туда и Обратно»!")
	var qt = get_node_or_null("ScrollArea/ScrollContent/TextVBox/QuoteText")
	if qt:
		qt.text = ("«In a hole in the ground there lived a hobbit.\nNot a nasty, dirty, wet hole, filled with the ends of worms,\nnor yet a dry, bare, sandy hole with nothing in it to sit down on...\nIt was a hobbit-hole, and that means comfort.»" if is_en else "«В норе под землёй жил хоббит.\nНе в сырой и затхлой норе, где полно червей,\nи не в сухой песчаной, где не на что сесть...\nЭто была хоббичья нора, а значит — уютная во всех отношениях.»")
	var ft = get_node_or_null("ScrollArea/ScrollContent/TextVBox/FooterText")
	if ft:
		ft.text = "— End of Records —" if is_en else "— Конец записей —"
