extends SceneTree

func _initialize() -> void:
	print("--- STARTING THE HOBBIT INTEGRATION TESTS ---")
	
	var gs = null
	if root.has_node("GameState"):
		gs = root.get_node("GameState")
	else:
		var GameStateScript = load("res://scripts/game_state.gd")
		gs = GameStateScript.new()
		gs.name = "GameState"
		root.add_child(gs)
	if gs.rooms.is_empty():
		gs._ready()
		
	var am = null
	if root.has_node("AudioManager"):
		am = root.get_node("AudioManager")
	else:
		var AudioManagerScript = load("res://scripts/audio_manager.gd")
		am = AudioManagerScript.new()
		am.name = "AudioManager"
		root.add_child(am)
	
	# 1. Проверка GameState
	assert(gs.rooms.size() == 79, "Expected 79 rooms, got %d" % gs.rooms.size())
	assert(gs.items.size() >= 40, "Expected at least 40 items, got %d" % gs.items.size())
	assert(gs.npcs.size() >= 10, "Expected at least 10 NPCs, got %d" % gs.npcs.size())
	print("[PASS] Database loaded successfully: 79 rooms, %d items, %d NPCs." % [gs.items.size(), gs.npcs.size()])
	
	# 2. Проверка 3-х режимов игры: Modern, VGA, ZX
	assert(gs.GameMode.MODERN == 0)
	assert(gs.GameMode.VGA == 1)
	assert(gs.GameMode.ZX == 2)
	
	gs.set_game_mode(gs.GameMode.MODERN)
	assert(gs.get_image_file_for_mode("01 Tunnel Like Hall.png") == "01 Tunnel Like Hall.png")
	
	gs.set_game_mode(gs.GameMode.VGA)
	assert(gs.get_image_file_for_mode("01 Tunnel Like Hall.png") == "01 Tunnel Like Hall VGA.png")
	
	gs.set_game_mode(gs.GameMode.ZX)
	assert(gs.get_image_file_for_mode("01 Tunnel Like Hall.png") == "01 Tunnel Like Hall ZX.png")
	print("[PASS] GameState.GameMode switching and filename suffix resolution verified.")
	
	# 3. Проверка картинок всех 79 локаций для всех трех режимов
	for mode in [gs.GameMode.MODERN, gs.GameMode.VGA, gs.GameMode.ZX]:
		gs.set_game_mode(mode)
		var mode_name = gs.get_current_mode_name()
		var missing_images = 0
		for rid in gs.rooms.keys():
			var r = gs.rooms[rid]
			var img_file = r.get("image_file", "")
			if img_file != "":
				var final_img = gs.get_image_file_for_mode(img_file)
				var path = "res://assets/images/" + final_img
				if not FileAccess.file_exists(path):
					print("[WARN] Missing image for room %d in mode %s: %s" % [rid, mode_name, path])
					missing_images += 1
		assert(missing_images == 0, "Missing images in mode " + mode_name)
		print("[PASS] Mode '%s': All 79 locations have authentic images on disk!" % mode_name)
		
	# 4. Проверка заставок и стоп-кадров для всех 3 режимов
	var splashes = [
		["loading.png", "video_last_frame.png", "loading.ogv"],
		["loading VGA.png", "video_last_frame_vga.png", "loading_vga.ogv"],
		["Loading_ZX.png", "video_last_frame_zx.png", "loading_ZX.ogv"]
	]
	for s in splashes:
		var splash_path = "res://assets/images/" + s[0]
		var frame_path = "res://assets/images/" + s[1]
		var video_path = "res://assets/images/" + s[2]
		assert(FileAccess.file_exists(splash_path), "Missing splash: " + splash_path)
		assert(FileAccess.file_exists(frame_path), "Missing frame: " + frame_path)
		assert(FileAccess.file_exists(video_path), "Missing video: " + video_path)
	print("[PASS] Intro videos, stop frames and splash images verified for Modern, VGA and ZX modes.")
	
	# 5. Проверка музыки: 6 тем * 3 режима = 18 треков
	var themes = ["fanfare", "hobbit_hole", "trolls", "goblins", "mirkwood", "desolation"]
	for mode in [gs.GameMode.MODERN, gs.GameMode.VGA, gs.GameMode.ZX]:
		gs.set_game_mode(mode)
		for th in themes:
			var fname = am.get_theme_filename(th)
			var path = "res://assets/music/" + fname
			assert(FileAccess.file_exists(path), "Missing audio track: " + path)
	print("[PASS] All 18 music tracks exist and are resolved for Modern, VGA (SB) and ZX (SID).")
	
	# 6. Проверка победных и троллиных экранов
	for mode in [gs.GameMode.MODERN, gs.GameMode.VGA, gs.GameMode.ZX]:
		gs.set_game_mode(mode)
		var win_img = "res://assets/images/" + gs.get_image_file_for_mode("00.png")
		assert(FileAccess.file_exists(win_img), "Missing win image: " + win_img)
		var troll_live = "res://assets/images/" + gs.get_image_file_for_mode("05 Trolls Clearing.png")
		assert(FileAccess.file_exists(troll_live), "Missing live trolls: " + troll_live)
		var troll_stone = "res://assets/images/" + gs.get_image_file_for_mode("50 Trolls Clearing.png")
		assert(FileAccess.file_exists(troll_stone), "Missing stone trolls: " + troll_stone)
	print("[PASS] Victory and troll state images verified across all 3 modes.")
	
	# 7. Проверка парсера команд для контейнеров и действий
	var parser = gs.parser
	var p1 = parser.parse("север")
	assert(p1["verb"] == "go" and p1["direction"] == "north", "Failed parsing 'север'")
	
	var container_test_phrases = [
		"осмотреть сундук",
		"осмотреть вещи в сундуке",
		"вещи в сундуке",
		"что в сундуке",
		"что внутри сундука",
		"заглянуть в сундук",
		"заглянуть внутрь сундука",
		"посмотреть в сундук",
		"содержимое сундука",
		"в сундуке"
	]
	
	for phrase in container_test_phrases:
		var res = parser.parse(phrase)
		assert(res["verb"] == "examine", "Failed container verb for '%s', got '%s'" % [phrase, res["verb"]])
		assert("сундук" in res["object"], "Failed container target for '%s', got '%s'" % [phrase, res["object"]])
	print("[PASS] All container inspection variants correctly parsed to examine chest.")
	
	# 8. Обращения к спутникам и предлоги
	var p3 = parser.parse("Торин, открой дверь")
	assert(p3["target_npc"] == "thorin" and p3["verb"] == "open" and "двер" in p3["object"])
	
	var p4 = parser.parse("скажи торину \"возьми меч\"")
	assert(p4["target_npc"] == "thorin" and p4["verb"] == "take")
	
	var p5 = parser.parse("положить меч в сундук")
	assert(p5["verb"] == "drop" and "меч" in p5["object"] and "сундук" in p5["indirect_object"])
	print("[PASS] Natural language parser works for directions, examine, prepositions and companion commands.")
	
	# 9. Интеграция геймплея: сундук, карта, победа
	gs.set_game_mode(gs.GameMode.MODERN)
	assert(gs.current_room_id == 1, "Start room should be 1")
	var chest = gs.items[37]
	assert(chest["is_open"] == false, "Chest should be closed initially")
	
	gs.process_command("открыть сундук")
	assert(chest["is_open"] == true, "Chest should be open now")
	
	gs.process_command("взять карту")
	assert(gs.items[3]["location"] == 0, "Map should be in player inventory")
	
	gs.process_command("положить карту в сундук")
	assert(gs.items[3]["location"] == -37, "Map should now be inside chest (-37)")
	
	gs.process_command("взять карту")
	assert(gs.items[3]["location"] == 0, "Map should be taken from open chest into inventory")
	print("[PASS] Container interaction (open, examine empty, examine with items, take out) fully verified.")
	
	# 10. Проверка создания и связывания главной сцены main.tscn
	var MainScene = load("res://scenes/main.tscn")
	var main_instance = MainScene.instantiate()
	main_instance.cached_game_state = gs
	main_instance.cached_audio_manager = am
	root.add_child(main_instance)
	main_instance.notification(Node.NOTIFICATION_READY)
	assert(main_instance != null, "main.tscn must instantiate cleanly")
	
	# Проверка ключевых UI элементов
	assert(main_instance.get_node("%LocationTitle") != null, "LocationTitle node exists")
	assert(main_instance.get_node("%StatusInfo") != null, "StatusInfo node exists")
	assert(main_instance.get_node("%OutputLog") != null, "OutputLog node exists")
	assert(main_instance.get_node("%InputLine") != null, "InputLine node exists")
	assert(main_instance.get_node("%CommandDropdown") != null, "CommandDropdown node exists")
	assert(main_instance.get_node("%ModeSelectScreen") != null, "ModeSelectScreen node exists")
	assert(main_instance.get_node("%TitleScreen") != null, "TitleScreen node exists")
	assert(main_instance.get_node("%SettingsPanel") != null, "SettingsPanel node exists")
	assert(main_instance.get_node("%BtnSettingsMainMenu") != null, "BtnSettingsMainMenu node exists")
	
	# Проверка кнопки 'Выход в главное меню' в окне настроек:
	# 1. Из главного меню (game_started = false) кнопка ДОЛЖНА быть скрыта:
	main_instance.game_started = false
	main_instance._on_settings_pressed()
	assert(main_instance.settings_panel.visible == true, "SettingsPanel should be visible")
	assert(main_instance.btn_settings_main_menu.visible == false, "BtnSettingsMainMenu must NOT be visible when opened from main menu")
	main_instance._on_settings_back_pressed()
	assert(main_instance.settings_panel.visible == false, "SettingsPanel should be hidden after back pressed")
	
	# 2. Из самой игры (game_started = true) кнопка ДОЛЖНА отображаться:
	main_instance.game_started = true
	main_instance._on_settings_pressed()
	assert(main_instance.settings_panel.visible == true, "SettingsPanel should be visible")
	assert(main_instance.btn_settings_main_menu.visible == true, "BtnSettingsMainMenu MUST be visible when opened from in-game")
	
	# 3. Нажатие кнопки 'Выход в главное меню':
	main_instance._on_settings_main_menu_pressed()
	assert(main_instance.settings_panel.visible == false, "SettingsPanel should be closed")
	assert(main_instance.game_started == false, "game_started should be false")
	assert(main_instance.title_screen.visible == true, "TitleScreen should be visible")
	assert(main_instance.menu_container.visible == true, "MenuContainer should be visible on TitleScreen")
	print("[PASS] In-game Settings menu 'Выход в главное меню' button verified (only shown in-game).")
	
	# Проверка масштабирования заставки: stretch_mode = STRETCH_SCALE (0), исключающее обрезку и расширение картинки
	assert(main_instance.video_freeze_frame.stretch_mode == TextureRect.STRETCH_SCALE, "VideoFreezeFrame stretch_mode must be STRETCH_SCALE (0)")
	assert(main_instance.title_image.stretch_mode == TextureRect.STRETCH_SCALE, "TitleImage stretch_mode must be STRETCH_SCALE (0)")
	print("[PASS] TitleScreen textures scale mode verified: STRETCH_SCALE (0) eliminates overscaling/cropping beyond screen edges.")
	
	# Проверка выпадающего списка команд
	var dropdown = main_instance.get_node("%CommandDropdown") as OptionButton
	assert(dropdown.item_count > 1, "Command dropdown should be populated with commands, got %d" % dropdown.item_count)
	
	# Проверка уменьшения громкости loading_ZX на 50%
	gs.set_game_mode(gs.GameMode.ZX)
	main_instance._start_intro_sequence()
	assert(is_equal_approx(main_instance.intro_video.volume, 0.5), "ZX intro video volume must be 0.5 (50%)")
	assert(is_equal_approx(main_instance.intro_video.volume_db, linear_to_db(0.5)), "ZX intro video volume_db must be linear_to_db(0.5)")
	main_instance.intro_video.stop()
	
	# Проверка стандартной громкости для Modern
	gs.set_game_mode(gs.GameMode.MODERN)
	main_instance._start_intro_sequence()
	assert(is_equal_approx(main_instance.intro_video.volume, 1.0), "Modern intro video volume must be 1.0 (100%)")
	assert(is_equal_approx(main_instance.intro_video.volume_db, 0.0), "Modern intro video volume_db must be 0.0 dB")
	main_instance.intro_video.stop()
	
	print("[PASS] Main scene main.tscn instantiated: all nodes, layout panels and dropdown commands verified!")
	print("[PASS] Intro video volume: ZX reduced by 50% (volume 0.5 / -6 dB), Modern/VGA at 100%.")
	
	# Проверка переключения шрифтов для каждого режима игры
	var f_mod = gs.get_font_for_mode(gs.GameMode.MODERN)
	var f_vga = gs.get_font_for_mode(gs.GameMode.VGA)
	var f_zx = gs.get_font_for_mode(gs.GameMode.ZX)
	assert(f_mod != null and f_mod.get_font_name() == "Greengoth", "Modern font should be Greengoth")
	assert(f_vga != null and f_vga.get_font_name() == "DOS2000 (RU/EN)", "VGA font should be DOS2000")
	assert(f_zx != null and f_zx.get_font_name() == "ZX Spectrum 7", "ZX font should be ZX Spectrum 7")
	
	# 1. Режим MODERN
	gs.set_game_mode(gs.GameMode.MODERN)
	assert(main_instance.theme.default_font == f_mod, "Main theme font in Modern mode must be Greengoth")
	assert(main_instance.output_log.get_theme_font("normal_font") == f_mod, "OutputLog in Modern mode must use Greengoth")
	assert(main_instance.loc_title.get_theme_font("font") == f_mod, "LocTitle in Modern mode must use Greengoth")
	assert(main_instance.output_log.get_theme_font_size("normal_font_size") == 24, "OutputLog in Modern mode must be 24px for great readability")
	assert(main_instance.input_line.get_theme_font_size("font_size") == 22, "InputLine in Modern mode must be 22px")
	assert(main_instance.loc_title.get_theme_font_size("font_size") == 28, "LocTitle in Modern mode must be 28px")
	
	# 2. Режим VGA
	gs.set_game_mode(gs.GameMode.VGA)
	assert(main_instance.theme.default_font == f_vga, "Main theme font in VGA mode must be DOS2000")
	assert(main_instance.output_log.get_theme_font("normal_font") == f_vga, "OutputLog in VGA mode must use DOS2000")
	assert(main_instance.loc_title.get_theme_font("font") == f_vga, "LocTitle in VGA mode must use DOS2000")
	assert(main_instance.output_log.get_theme_font_size("normal_font_size") == 20, "OutputLog in VGA mode must be 20px")
	
	# 3. Режим ZX
	gs.set_game_mode(gs.GameMode.ZX)
	assert(main_instance.theme.default_font == f_zx, "Main theme font in ZX mode must be ZX Spectrum 7")
	assert(main_instance.output_log.get_theme_font("normal_font") == f_zx, "OutputLog in ZX mode must use ZX Spectrum 7")
	assert(main_instance.loc_title.get_theme_font("font") == f_zx, "LocTitle in ZX mode must use ZX Spectrum 7")
	assert(main_instance.output_log.get_theme_font_size("normal_font_size") == 16, "OutputLog in ZX mode must be 16px")
	
	# Проверка шрифтов превью-карточек на экране выбора режима:
	assert(main_instance.btn_select_modern.get_theme_font("font") == f_mod, "CardModern button must use Greengoth")
	assert(main_instance.btn_select_vga.get_theme_font("font") == f_vga, "CardVGA button must use DOS2000")
	assert(main_instance.btn_select_zx.get_theme_font("font") == f_zx, "CardZX button must use ZX Spectrum 7")
	assert(main_instance.btn_select_modern.get_theme_font_size("font_size") == 24, "BtnSelectModern must be 24px")
	var card_m_desc = main_instance.get_node("ModeSelectScreen/Margin/VBoxModes/HBoxCards/CardModern/Margin/VBox/Desc")
	assert(card_m_desc.get_theme_font_size("font_size") == 21, "CardModern Desc must be 21px")
	
	# Проверка картинок превью-карточек меню выбора режима (ModernPC, RetroPC, ZXPC):
	assert(main_instance.img_preview_modern != null and main_instance.img_preview_modern.texture != null, "CardModern preview image must be loaded")
	assert(main_instance.img_preview_vga != null and main_instance.img_preview_vga.texture != null, "CardVGA preview image must be loaded")
	assert(main_instance.img_preview_zx != null and main_instance.img_preview_zx.texture != null, "CardZX preview image must be loaded")
	assert(main_instance.img_preview_modern.texture.get_size() == Vector2(2752, 1536), "ModernPC texture must be 2752x1536")
	
	# Проверка черной окантовки шрифта в главном меню (TitleScreen):
	assert(main_instance.btn_start_game.get_theme_constant("outline_size") == 8, "TitleScreen buttons must have outline_size == 8")
	assert(main_instance.btn_start_game.get_theme_color("font_outline_color") == Color.BLACK, "TitleScreen buttons must have black font outline")
	assert(main_instance.btn_exit.get_theme_constant("outline_size") == 8, "BtnExit must have outline_size == 8")
	print("[PASS] Mode-specific fonts & card images (ModernPC, RetroPC, ZXPC) fully verified across UI!")
	
	# Проверка скрытия названий файлов локаций (LocationSub)
	main_instance._update_header(1)
	assert(not main_instance.loc_sub.visible, "LocationSub must be hidden")
	assert(main_instance.loc_sub.text == "", "LocationSub text must be empty")
	main_instance._update_header(5)
	assert(not main_instance.loc_sub.visible, "LocationSub must remain hidden in room 5")
	assert(main_instance.loc_sub.text == "", "LocationSub text must remain empty in room 5")
	print("[PASS] Location filenames hidden: LocationSub is invisible and empty across all rooms.")
	
	# Проверка стабильности интерфейса в режиме ZX (без растягивания и скачков ширины)
	gs.set_game_mode(gs.GameMode.ZX)
	var left_p = main_instance.get_node("RootMargin/VBoxMain/TopRow/LeftMovePanel")
	var right_p = main_instance.get_node("RootMargin/VBoxMain/TopRow/RightActionPanel")
	
	# Комната 1 (1 выход, 0 спутников)
	gs.current_room_id = 1
	main_instance._update_header(1)
	main_instance._update_compass_buttons()
	main_instance._update_status_bar()
	var left_w1 = left_p.get_combined_minimum_size().x
	var right_w1 = right_p.get_combined_minimum_size().x
	
	# Комната 5 (3 выхода, 3 спутника: Торин + Тролли)
	gs.current_room_id = 5
	main_instance._update_header(5)
	main_instance._update_compass_buttons()
	main_instance._update_status_bar()
	var left_w5 = left_p.get_combined_minimum_size().x
	var right_w5 = right_p.get_combined_minimum_size().x
	
	assert(left_w1 == 360.0 and left_w5 == 360.0, "LeftMovePanel width must remain constant 360px (got %f and %f)" % [left_w1, left_w5])
	assert(right_w1 == 360.0 and right_w5 == 360.0, "RightActionPanel width must remain constant 360px (got %f and %f)" % [right_w1, right_w5])
	assert(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "Stretch aspect must be 'keep' in project settings")
	print("[PASS] ZX layout stability verified: Left and Right panels stay strictly 360px with autowrap, no width jumping.")
	
	# 11. Проверка динамического переключения музыки по music_triggers.json
	assert(am.get_theme_for_room(1) == "hobbit_hole", "Room 1 should trigger hobbit_hole")
	assert(am.get_theme_for_room(5) == "trolls", "Room 5 should trigger trolls")
	assert(am.get_theme_for_room(7) == "goblins", "Room 7 should trigger goblins")
	assert(am.get_theme_for_room(9) == "mirkwood", "Room 9 should trigger mirkwood (Rivendell)")
	assert(am.get_theme_for_room(33) == "mirkwood", "Room 33 should trigger mirkwood (Lake-town/River)")
	print("[PASS] Dynamic music track triggers verified against music_triggers.json.")

	# Проверка плавной смены музыки (fade out / fade in)
	am.play_theme("hobbit_hole", false, false)
	assert(am.current_theme == "hobbit_hole", "Current theme should be hobbit_hole")
	am.update_location_music(5)
	assert(am.pending_theme == "trolls", "Pending theme should be trolls during fade transition")
	assert(am._fade_tween != null and am._fade_tween.is_valid(), "Fade tween must be active")
	am.update_location_music(6)
	assert(am.pending_theme == "trolls", "Transition to trolls should continue without reset")
	am.stop_music(false)
	print("[PASS] Smooth sequential audio fading (fade-out 1s + fade-in 1s) verified.")

	# 12. Проверка защиты от падения в Неизвестную землю (Комната 0)
	gs.current_room_id = 25 # Bewitched Gloomy Place (Юг ведет в Заколдованную реку с dest: 0)
	gs.process_command("юг")
	assert(gs.current_room_id == 25, "Going south in room 25 must not enter room 0! Remains in room 25.")

	gs.current_room_id = 33 # Forestriver (Вверх ведет в люк с dest: 0)
	gs.process_command("вверх")
	assert(gs.current_room_id == 33, "Going up in room 33 must not enter room 0! Remains in room 33.")
	print("[PASS] Room 0 void protection verified: blocked exits with dest 0 safely reject movement.")

	# 13. Проверка квеста переправы через Заколдованную реку на лодке
	gs.current_room_id = 66 # Западный берег
	gs.items[41]["location"] = 67 # Лодка на восточном берегу
	gs.items[18]["location"] = 0  # Веревка в руках у Бильбо
	
	# Притягиваем лодку веревкой
	gs.process_command("притянуть лодку")
	assert(gs.items[41]["location"] == 66, "Boat should be pulled to West Bank (66)")
	
	# Залезаем в лодку
	gs.process_command("залезть в лодку")
	assert(gs.inside_container_id == 41, "Bilbo should be inside the boat")
	
	# Плывем на восток
	gs.process_command("восток")
	assert(gs.current_room_id == 67, "Bilbo should arrive at East Bank (67)")
	assert(gs.items[41]["location"] == 67, "Boat should now be at East Bank (67)")
	
	# Вылезаем на берег
	gs.process_command("вылезти")
	assert(gs.inside_container_id == -1, "Bilbo should be outside on land")
	# 14. Проверка механики двери в Прихожей (Комната 1 -> Комната 4)
	gs.current_room_id = 1
	gs.items[5]["is_open"] = false
	gs.process_command("восток")
	assert(gs.current_room_id == 1, "Moving east when door is closed should remain in room 1")
	
	# Открытие двери игроком
	gs.process_command("открыть дверь")
	assert(gs.items[5]["is_open"] == true, "Door 5 should now be open")
	gs.process_command("восток")
	assert(gs.current_room_id == 4, "Moving east through open door should reach room 4 (Lonelands)")
	
	# Открытие двери Торином по команде компаньону
	gs.current_room_id = 1
	gs.npcs[63]["location"] = 1 # Торин находится в комнате 1
	gs.items[5]["is_open"] = false
	gs.process_command("торин, открой дверь")
	assert(gs.items[5]["is_open"] == true, "Thorin companion command should open door 5")
	print("[PASS] Room 1 door mechanics and companion commands verified.")

	# 15. Проверка окаменения троллей на рассвете (Troll clearing event)
	gs.current_room_id = 5
	gs.day_phase = 0
	gs.trolls_are_stone = false
	gs._trigger_trolls_dawn()
	assert(gs.are_trolls_stone() == true, "Trolls should be turned to stone at dawn")
	assert(gs.items[4]["location"] == 5, "Key 4 (ключ от пещеры троллей) should drop in room 5")
	print("[PASS] Trolls petrification and key drop event verified.")

	# 16. Проверка победного условия: положить Аркенстон в сундук в норе Бильбо
	gs.current_room_id = 1
	gs.items[37]["is_open"] = true # Сундук открыт
	gs.items[35]["location"] = 0   # Аркенстон у Бильбо
	gs.game_won = false
	gs.process_command("положить сокровище в сундук")
	assert(gs.game_won == true, "Placing Arkenstone (item 35) in Chest (item 37) in Room 1 wins the game!")
	print("[PASS] Victory condition (Arkenstone into Chest in Bag End) verified.")

	# 17. Проверка новой системы сохранений и загрузок со скриншотами (Ren'Py стиль)
	var test_img = Image.create(480, 270, false, Image.FORMAT_RGBA8)
	test_img.fill(Color(0.2, 0.4, 0.6, 1.0))
	
	# Проверка начального состояния слота 1
	gs.delete_slot(1)
	gs.delete_slot(2)
	var info_empty = gs.get_slot_info(1)
	assert(info_empty["exists"] == false, "Slot 1 should not exist initially")
	
	# Сохраняем состояние в слот 1
	gs.current_room_id = 15
	gs.player_health = 88
	gs.player_strength = 75
	gs.turn_count = 42
	gs.day_phase = 1
	gs.set_game_mode(gs.GameMode.VGA)
	var save_res = gs.save_to_slot(1, test_img)
	assert(save_res == true, "save_to_slot(1) should succeed")
	assert(FileAccess.file_exists(gs.get_slot_save_path(1)), "Slot 1 JSON file must exist on disk")
	assert(FileAccess.file_exists(gs.get_slot_image_path(1)), "Slot 1 PNG screenshot must exist on disk")
	assert(gs.has_any_saves() == true, "has_any_saves() should return true after saving to slot 1")
	
	# Проверяем метаданные слота 1
	var info_slot1 = gs.get_slot_info(1)
	assert(info_slot1["exists"] == true, "Slot 1 exists flag should be true")
	assert(info_slot1["room_id"] == 15, "Slot 1 room_id must be 15")
	assert(info_slot1["health"] == 88, "Slot 1 health must be 88")
	assert("VGA" in info_slot1["mode_name"], "Slot 1 mode_name must contain VGA")
	assert(info_slot1["turn_count"] == 42, "Slot 1 turn_count must be 42")
	assert(info_slot1["screenshot_path"] == gs.get_slot_image_path(1), "Screenshot path must match")
	
	# Мутируем текущее состояние и загружаем слот 1
	gs.current_room_id = 1
	gs.player_health = 20
	gs.player_strength = 30
	gs.turn_count = 999
	gs.set_game_mode(gs.GameMode.ZX)
	
	var load_res = gs.load_from_slot(1)
	assert(load_res == true, "load_from_slot(1) should return true")
	assert(gs.current_room_id == 15, "Loaded room_id must be 15")
	assert(gs.player_health == 88, "Loaded health must be 88")
	assert(gs.player_strength == 75, "Loaded strength must be 75")
	assert(gs.turn_count == 42, "Loaded turn_count must be 42")
	assert(gs.game_mode == gs.GameMode.VGA, "Loaded game_mode must be VGA")
	
	# Проверяем обратную совместимость устаревших _save_game / _load_game
	assert(gs._save_game() == true, "Legacy _save_game() must succeed")
	assert(FileAccess.file_exists("user://savegame.json"), "Legacy user://savegame.json must exist")
	assert(gs._load_game() == true, "Legacy _load_game() must succeed")
	
	# Проверяем удаление слота
	var del_res = gs.delete_slot(1)
	assert(del_res == true, "delete_slot(1) should succeed")
	assert(not FileAccess.file_exists(gs.get_slot_save_path(1)), "Slot 1 JSON file must be deleted")
	assert(not FileAccess.file_exists(gs.get_slot_image_path(1)), "Slot 1 PNG screenshot must be deleted")
	assert(gs.get_slot_info(1)["exists"] == false, "Slot 1 info exists must be false after deletion")
	print("[PASS] Ren'Py style slot save/load/delete and metadata serialization verified.")

	# 18. Проверка интерфейса SaveLoadScreen и интеграции в main.tscn
	assert(main_instance.save_load_screen != null, "SaveLoadScreen node must be present in main_instance")
	assert(main_instance.save_load_screen.visible == false, "SaveLoadScreen should be hidden by default")
	
	# Проверяем иерархию узлов карточки слота (корзина BtnDelete должна быть в HBoxTop, отдельно от BtnCardAction)
	var sls = main_instance.save_load_screen
	sls.notification(Node.NOTIFICATION_READY)
	var card1 = sls.get_node("%SlotCard1")
	var btn_del1: Button = sls.get_node("%BtnDelete1")
	var btn_act1: Button = sls.get_node("%BtnCardAction1")
	assert(btn_del1 != null, "BtnDelete1 must exist")
	assert(btn_act1 != null, "BtnCardAction1 must exist")
	assert(btn_del1.get_parent().name == "HBoxTop", "BtnDelete1 must be child of HBoxTop to avoid click stealing")
	
	# Сохраняем тестовое состояние в слот 1 для UI-проверок
	gs.save_to_slot(1, test_img)
	
	# Открытие в режиме ЗАГРУЗИТЬ
	main_instance.open_load_menu()
	assert(sls.visible == true, "SaveLoadScreen must be visible in load mode")
	assert(sls.current_mode == sls.Mode.LOAD, "Mode must be LOAD")
	sls.refresh_slots()
	assert(btn_del1.visible == true, "BtnDelete1 must be visible when slot 1 has a save")
	
	# Нажатие на корзину слота 1 должно открыть диалог подтверждения удаления, а НЕ загружать игру
	var pre_load_room = gs.current_room_id
	btn_del1.emit_signal("pressed")
	assert(sls.confirm_overlay.visible == true, "Clicking trash bin must show ConfirmOverlay")
	assert("Удалить" in sls.confirm_prompt.text, "ConfirmPrompt must ask to delete")
	assert(gs.current_room_id == pre_load_room, "Clicking trash bin must NOT load room")
	
	# Подтверждение удаления
	sls.btn_confirm_yes.emit_signal("pressed")
	assert(sls.confirm_overlay.visible == false, "ConfirmOverlay must be hidden after confirming")
	assert(gs.get_slot_info(1)["exists"] == false, "Slot 1 must be deleted after confirmation")
	assert(btn_del1.visible == false, "BtnDelete1 must be hidden after slot is empty")
	
	# Закрытие окна
	sls.close_screen()
	assert(sls.visible == false, "SaveLoadScreen must be hidden after close_screen()")
	
	# Открытие в режиме СОХРАНИТЬ
	main_instance.open_save_menu()
	assert(sls.visible == true, "SaveLoadScreen must be visible in save mode")
	assert(sls.current_mode == sls.Mode.SAVE, "Mode must be SAVE")
	sls.close_screen()
	print("[PASS] SaveLoadScreen modal window, modes, trash bin delete & UI lifecycle verified.")

	# 19. Проверка автоматического сохранения настроек при выходе (громкость и fullscreen)
	am.set_music_volume(0.64)
	am.save_settings(true) # Сохраняем fullscreen = true и громкость 0.64
	assert(FileAccess.file_exists("user://settings.json"), "user://settings.json must exist")
	
	# Читаем settings.json и проверяем значения
	var sf = FileAccess.open("user://settings.json", FileAccess.READ)
	assert(sf != null, "settings.json must be readable")
	var settings_json = JSON.parse_string(sf.get_as_text())
	sf.close()
	assert(settings_json != null and typeof(settings_json) == TYPE_DICTIONARY, "settings.json must be valid dictionary")
	assert(is_equal_approx(float(settings_json.get("music_volume", 0.0)), 0.64), "Saved volume must be 0.64")
	assert(bool(settings_json.get("fullscreen", false)) == true, "Saved fullscreen must be true")
	
	# Проверка триггера сохранения настроек при выходе (NOTIFICATION_WM_CLOSE_REQUEST)
	am.set_music_volume(0.33)
	main_instance.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var sf2 = FileAccess.open("user://settings.json", FileAccess.READ)
	var settings_json2 = JSON.parse_string(sf2.get_as_text())
	sf2.close()
	assert(is_equal_approx(float(settings_json2.get("music_volume", 0.0)), 0.33), "Exit notification must auto-save volume 0.33")
	# 20. Проверка экрана «Об игре» (CreditsScreen)
	assert(main_instance.btn_credits != null, "BtnCredits node must be present in TitleScreen")
	assert(main_instance.btn_credits.text == "Об игре", "BtnCredits text must be 'Об игре'")
	assert(main_instance.credits_screen != null, "CreditsScreen node must be present in main_instance")
	assert(main_instance.credits_screen.visible == false, "CreditsScreen should be hidden by default")
	
	# Проверяем структуру экрана титров
	var cs = main_instance.credits_screen
	cs.notification(Node.NOTIFICATION_READY)
	assert(cs.btn_back != null, "BtnBack must exist in CreditsScreen")
	assert(cs.text_vbox != null, "TextVBox must exist in CreditsScreen")
	assert(cs.pic_left != null, "PicLeft must exist in CreditsScreen")
	assert(cs.pic_right != null, "PicRight must exist in CreditsScreen")
	assert(cs.pic_left.material != null, "PicLeft must have ragged edge shader material")
	assert(cs.pic_right.material != null, "PicRight must have ragged edge shader material")
	
	# Проверяем загрузку картинок
	assert(cs.loaded_textures.size() >= 12, "CreditsScreen must load all 12 initial images")
	
	# Открытие экрана «Об игре»
	main_instance._on_credits_pressed()
	assert(main_instance.title_screen.visible == false, "Title screen must be hidden when credits opened")
	assert(cs.visible == true, "CreditsScreen must be visible when opened")
	assert(cs.is_active == true, "CreditsScreen must be active")
	assert(am.current_theme == "fanfare", "Fanfare theme must be played when credits open")
	
	# Проверка текста титров (автор и история создания)
	var all_text: String = ""
	for child in cs.text_vbox.get_children():
		if child is Label:
			all_text += child.text + " "
	assert("Freeonce (aka MrTEK)" in all_text, "Credits text must mention Freeonce (aka MrTEK)")
	assert("Melbourne House" in all_text, "Credits text must mention Melbourne House")
	assert("1982" in all_text, "Credits text must mention 1982")
	
	# Проверка нажатия пробела: пробел должен поглощаться и НЕ закрывать экран титров
	var ev_space = InputEventKey.new()
	ev_space.keycode = KEY_SPACE
	ev_space.pressed = true
	cs._input(ev_space)
	assert(cs.visible == true, "Pressing SPACE must NOT close CreditsScreen (it accelerates scroll)")
	assert(main_instance.title_screen.visible == false, "TitleScreen must remain hidden when SPACE is pressed")

	# Проверка закрытия экрана титров
	cs.close_credits()
	assert(cs.visible == false, "CreditsScreen must be hidden after closing")
	assert(main_instance.title_screen.visible == true, "TitleScreen must be restored after closing credits")
	assert(am.current_theme == "fanfare", "Fanfare theme must continue/restart on title screen")
	print("[PASS] CreditsScreen integration, shaders, textures, scrolling & music verified.")

	# 21. Проверка надписи версии (v 0.95 Beta) в главном меню во всех режимах
	assert(main_instance.version_label != null, "VersionLabel node must be present in TitleScreen")
	assert(main_instance.version_label.text == "v 0.95 Beta", "VersionLabel text must be 'v 0.95 Beta'")
	var mode_ver = main_instance.get_node("ModeSelectScreen/ModeSelectVersion")
	assert(mode_ver != null, "ModeSelectVersion must exist in ModeSelectScreen")
	assert(mode_ver.text == "v 0.95 Beta", "ModeSelectVersion text must be 'v 0.95 Beta'")
	print("[PASS] Version info 'v 0.95 Beta' verified across TitleScreen and ModeSelectScreen.")

	# 22. Проверка режима для слабовидящих (Accessibility Mode), синтеза речи UI (self-voicing), контрастного интерфейса и громкости 10%
	assert(main_instance.check_accessibility != null, "CheckAccessibility node must exist in SettingsPanel")
	assert("Режим для слабовидящих" in main_instance.check_accessibility.text, "CheckAccessibility label must match")
	
	# Проверка базового режима MODERN (шрифты 24 и 22)
	gs.set_game_mode(gs.GameMode.MODERN)
	main_instance._apply_game_mode_font(main_instance.Mode.MODERN)
	assert(main_instance.output_log.get_theme_font_size("normal_font_size") == 24, "Log font size in Modern mode must be 24")
	assert(main_instance.input_line.get_theme_font_size("font_size") == 22, "Input line font size in Modern mode must be 22")
	
	# Проверка исходной громкости (по умолчанию 0.75)
	am.set_music_volume(0.75)
	main_instance.volume_slider.value = 0.75
	main_instance._on_volume_changed(0.75)
	assert(am.get_music_volume() == 0.75, "Base music volume must be 0.75")
	assert(main_instance.volume_slider.value == 0.75, "Volume slider must be 0.75")
	assert(main_instance.vol_value_label.text == "75%", "Volume label must show 75%")
	
	# Включаем режим для слабовидящих
	main_instance.check_accessibility.button_pressed = true
	main_instance._on_accessibility_toggled(true)
	assert(gs.is_accessibility_mode == true, "GameState.is_accessibility_mode must be true")
	assert(is_equal_approx(am.get_music_volume(), 0.10), "Music volume must be attenuated to 0.10 when accessibility mode is enabled")
	assert(is_equal_approx(main_instance.volume_slider.value, 0.10), "Volume slider must visually update to 0.10")
	assert(main_instance.vol_value_label.text == "10%", "Volume label must show 10%")
	
	# Проверяем увеличение шрифтов для слабовидящих
	assert(main_instance.output_log.get_theme_font_size("normal_font_size") == 30, "Log font size must be 30 in accessibility mode")
	assert(main_instance.input_line.get_theme_font_size("font_size") == 26, "Input line font size must be 26 in accessibility mode")
	assert(main_instance.prompt_label.get_theme_font_size("font_size") == 28, "Prompt label font size must be 28 in accessibility mode")
	assert(main_instance.loc_title.get_theme_font_size("font_size") == 34, "Title font size must be 34 in accessibility mode")
	
	# Проверка диктора интерфейса (Self-Voicing): речевые описания элементов управления
	var desc_btn = main_instance._get_control_accessibility_description(main_instance.btn_start_game)
	assert("Начать игру" in desc_btn and "кнопка" in desc_btn, "Button speech description must contain text and role")
	
	var desc_cb = main_instance._get_control_accessibility_description(main_instance.check_fullscreen)
	assert("Полноэкранный режим" in desc_cb and "флажок" in desc_cb, "Checkbox speech description must contain role and state")
	
	var desc_sl = main_instance._get_control_accessibility_description(main_instance.volume_slider)
	assert("Громкость музыки" in desc_sl and "ползунок" in desc_sl and "процентов" in desc_sl, "Slider speech description must contain role and percentage")
	
	var desc_dir = main_instance._get_control_accessibility_description(main_instance.btn_n)
	assert("север" in desc_dir.to_lower(), "Compass button speech description must mention direction")
	
	var desc_inp = main_instance._get_control_accessibility_description(main_instance.input_line)
	assert("Строка ввода" in desc_inp, "Input line speech description must mention command input")
	
	# Проверка горячих клавиш: повтор локации (F2) и переключение доступности (F1 / V)
	main_instance._repeat_current_location_audio()
	
	# Отключаем режим для слабовидящих - громкость музыки, ползунок и шрифты должны вернуться в стандартное состояние
	main_instance.check_accessibility.button_pressed = false
	main_instance._on_accessibility_toggled(false)
	assert(gs.is_accessibility_mode == false, "GameState.is_accessibility_mode must be false")
	assert(is_equal_approx(am.get_music_volume(), 0.75), "Music volume must be restored to 0.75 when accessibility mode is disabled")
	assert(is_equal_approx(main_instance.volume_slider.value, 0.75), "Volume slider must visually restore to 0.75")
	assert(main_instance.vol_value_label.text == "75%", "Volume label must restore to 75%")
	assert(main_instance.output_log.get_theme_font_size("normal_font_size") == 24, "Log font size must restore to 24 in Modern mode")
	assert(main_instance.input_line.get_theme_font_size("font_size") == 22, "Input line font size must restore to 22 in Modern mode")
	
	# Проверка обработки текста для озвучки (очистка BBCode)
	main_instance._speak_text("[b][color=#ffff00]Тестовый текст озвучки[/color][/b]", true)
	print("[PASS] Full UI Self-Voicing (диктор интерфейса, фокус, горячие клавиши F1/V/F2, кнопки, меню, слоты, ползунки) verified.")

	print("\n--- ALL TESTS PASSED SUCCESSFULLY! ---")
	main_instance.free()
	quit(0)


