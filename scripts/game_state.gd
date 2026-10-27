class_name HobbitGameState
extends Node

# Глобальное состояние игры The Hobbit (1982)

var rooms: Dictionary = {}
var items: Dictionary = {}
var npcs: Dictionary = {}

var current_room_id: int = 1 # Локация 1 - Уютная прихожая норы хоббита
var game_time: int = 0
var turn_count: int = 0

# Суточный цикл: 0 - День, 1 - Закат (Dusk), 2 - Ночь, 3 - Рассвет (Dawn)
var day_phase: int = 0 
const PHASE_LENGTH: int = 15

# Параметры Бильбо
var player_strength: int = 100
var player_health: int = 100
var player_max_mass: int = 100
var player_max_volume: int = 100
var is_invisible: bool = false # Носит Кольцо
var inside_container_id: int = -1 # Сидит внутри (бочка = 19, лодка = 41)
var carried_by_npc_id: int = -1 # Торин несет Бильбо

# Флаги сюжета
var trolls_are_stone: bool = false
var thrush_knocked: bool = false
var smaug_revealed_weakness: bool = false
var smaug_slain: bool = false
var game_won: bool = false
var game_over: bool = false

# Компоненты
const ParserClass = preload("res://scripts/parser.gd")
var parser: ParserClass
const WorldSimClass = preload("res://scripts/world_sim.gd")
var world_sim: WorldSimClass

# Режимы игры: Modern, VGA, ZX
enum GameMode {
	MODERN,
	VGA,
	ZX
}
var game_mode: GameMode = GameMode.MODERN

# Сигналы
signal text_printed(text: String, color: Color)
signal room_changed(new_room_id: int)
signal inventory_changed()
signal world_updated()
signal game_mode_changed(new_mode: GameMode)
signal accessibility_mode_changed(enabled: bool)
signal language_changed(new_lang: Language)

# Языки интерфейса и текста
enum Language {
	RU = 0,
	EN = 1
}
var current_language: Language = Language.RU

func set_language(lang: Language) -> void:
	if current_language != lang:
		current_language = lang
		language_changed.emit(lang)

func is_english() -> bool:
	return current_language == Language.EN

func tr_text(ru_text: String, en_text: String) -> String:
	return en_text if current_language == Language.EN else ru_text

func get_item_name(it: Dictionary) -> String:
	return it.get("name", "") if current_language == Language.EN else it.get("name_ru", it.get("name", ""))

func get_npc_name(n: Dictionary) -> String:
	return n.get("name", "") if current_language == Language.EN else n.get("name_ru", n.get("name", ""))

func get_room_name(r: Dictionary) -> String:
	return r.get("name", "") if current_language == Language.EN else r.get("name_ru", r.get("name", ""))

func get_room_desc(r: Dictionary) -> String:
	if current_language == Language.EN:
		return r.get("description_en", r.get("description", r.get("description_ru", "")))
	return r.get("description_ru", r.get("description", ""))

func get_item_desc(it: Dictionary) -> String:
	if current_language == Language.EN:
		return it.get("desc_en", it.get("desc_ru", ""))
	return it.get("desc_ru", "")

func get_npc_desc(n: Dictionary) -> String:
	if current_language == Language.EN:
		return n.get("desc_en", n.get("desc_ru", ""))
	return n.get("desc_ru", "")

var is_accessibility_mode: bool = false

func set_accessibility_mode(enabled: bool) -> void:
	if is_accessibility_mode != enabled:
		is_accessibility_mode = enabled
		accessibility_mode_changed.emit(enabled)

func set_game_mode(mode: GameMode) -> void:
	if game_mode != mode:
		game_mode = mode
		game_mode_changed.emit(mode)

func get_image_file_for_mode(base_file_name: String) -> String:
	if base_file_name.is_empty():
		return ""
	match game_mode:
		GameMode.VGA:
			return base_file_name.replace(".png", " VGA.png")
		GameMode.ZX:
			return base_file_name.replace(".png", " ZX.png")
		_:
			return base_file_name

func get_current_mode_name() -> String:
	match game_mode:
		GameMode.VGA:
			return tr_text("Ретро (VGA)", "Retro (VGA)")
		GameMode.ZX:
			return tr_text("Классический (ZX)", "Classic (ZX)")
		_:
			return tr_text("Современный (Modern)", "Modern")

var _mode_fonts_cache: Dictionary = {}

func get_font_path_for_mode(mode: GameMode = game_mode) -> String:
	match mode:
		GameMode.VGA:
			return "res://assets/fonts/DOS/dos2000-ru-en.ttf"
		GameMode.ZX:
			return "res://assets/fonts/ZX/zx_spectrum-7.ttf"
		_:
			return "res://assets/fonts/MODERN/Greengoth_Regular.ttf"

func get_font_for_mode(mode: GameMode = game_mode) -> Font:
	if _mode_fonts_cache.has(mode):
		return _mode_fonts_cache[mode]
	var path = get_font_path_for_mode(mode)
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		_mode_fonts_cache[mode] = f
		return f
	return null

var cached_audio_manager: Node = null

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

func _ready() -> void:
	parser = ParserClass.new()
	world_sim = WorldSimClass.new(self)
	_load_game_data()
	print("The Hobbit GameState initialized.")

func _load_game_data() -> void:
	# Загрузка локаций
	var f_locs = FileAccess.open("res://data/original_locations.json", FileAccess.READ)
	if f_locs:
		var parsed = JSON.parse_string(f_locs.get_as_text())
		for r in parsed:
			var rid = int(r["id"])
			r["id"] = rid
			for ex in r.get("exits", []):
				ex["dest"] = int(ex.get("dest", 0))
				ex["via_obj"] = int(ex.get("via_obj", 0))
			rooms[rid] = r
			
	# Загрузка предметов
	var f_items = FileAccess.open("res://data/original_objects.json", FileAccess.READ)
	if f_items:
		var parsed = JSON.parse_string(f_items.get_as_text())
		for i in parsed:
			var obj_id = int(i["id"])
			if obj_id == 0:
				continue
			i["id"] = obj_id
			if i.has("location"):
				i["location"] = int(i["location"])
			if i.has("key_id"):
				i["key_id"] = int(i["key_id"])
			if i.has("mass"):
				i["mass"] = int(i["mass"])
			if i.has("volume"):
				i["volume"] = int(i["volume"])
			if i.has("strength"):
				i["strength"] = int(i["strength"])
			items[obj_id] = i
			if not items[obj_id].has("container_items"):
				items[obj_id]["container_items"] = []
				
	# Загрузка NPC
	var f_npcs = FileAccess.open("res://data/npcs.json", FileAccess.READ)
	if f_npcs:
		var parsed = JSON.parse_string(f_npcs.get_as_text())
		for n in parsed:
			var nid = int(n["id"])
			n["id"] = nid
			if n.has("location"):
				n["location"] = int(n["location"])
			if n.has("health"):
				n["health"] = int(n["health"])
			if n.has("max_health"):
				n["max_health"] = int(n["max_health"])
			if n.has("strength"):
				n["strength"] = int(n["strength"])
			npcs[nid] = n

func reset_game() -> void:
	current_room_id = 1
	game_time = 0
	turn_count = 0
	day_phase = 0
	player_strength = 100
	player_health = 100
	player_max_mass = 100
	player_max_volume = 100
	is_invisible = false
	inside_container_id = -1
	carried_by_npc_id = -1
	trolls_are_stone = false
	thrush_knocked = false
	smaug_revealed_weakness = false
	smaug_slain = false
	game_won = false
	game_over = false
	rooms.clear()
	items.clear()
	npcs.clear()
	_load_game_data()
	world_sim = WorldSimClass.new(self)

func start_game() -> void:
	look()

func print_to_log(text: String, color: Color = Color.WHITE) -> void:
	text_printed.emit(text, color)

func are_trolls_stone() -> bool:
	return trolls_are_stone

func is_dark_here() -> bool:
	var room = rooms.get(current_room_id, {})
	if not room.get("is_dark", false):
		return false
	# Проверка источника света (факел 28 или светящееся Жало 14)
	for it_id in items.keys():
		var it = items[it_id]
		if (it["location"] == 0 or it["location"] == current_room_id) and it.get("gives_light", false):
			return false
	return true

func is_enemy_nearby() -> bool:
	var check_rooms = [current_room_id]
	var cur_room = rooms.get(current_room_id, {})
	for ex in cur_room.get("exits", []):
		var d = ex.get("dest", 0)
		if d > 0 and rooms.has(d):
			check_rooms.append(d)
		
	for n_id in npcs.keys():
		var n = npcs[n_id]
		if not n.get("friendly", false) and not n.get("is_dead", false) and n.get("location", -1) in check_rooms:
			return true
	return false

func process_command(cmd_text: String) -> void:
	cmd_text = cmd_text.strip_edges()
	if cmd_text == "" or game_over:
		return
		
	print_to_log("\n> " + cmd_text, Color.GRAY)
	
	# Особые команды для взаимодействия с лодкой через Черную реку на берегу 66
	var cmd_l = cmd_text.to_lower()
	if current_room_id == 66 and ("лодк" in cmd_l or "веревк" in cmd_l or "boat" in cmd_l or "rope" in cmd_l):
		if "притян" in cmd_l or "тян" in cmd_l or "кинь" in cmd_l or "брос" in cmd_l or "пойма" in cmd_l or "зацеп" in cmd_l or "pull" in cmd_l or "throw" in cmd_l:
			_pull_boat_with_rope()
			_end_turn()
			return
	
	var parsed = parser.parse(cmd_text)
	
	# Если это приказ спутнику
	if parsed["target_npc"] != "":
		_process_companion_command(parsed["target_npc"], parsed)
		_end_turn()
		return
		
	if parsed["verb"] == "":
		print_to_log(tr_text("Я не понимаю команду '" + cmd_text + "'.", "I do not understand the command '" + cmd_text + "'."), Color.SALMON)
		return
		
	match parsed["verb"]:
		"go":
			_go(parsed["direction"])
		"look":
			if parsed["object"] == "":
				look()
			else:
				_examine(parsed["object"], parsed.get("indirect_object", ""), parsed.get("preposition", ""))
		"examine":
			_examine(parsed["object"], parsed.get("indirect_object", ""), parsed.get("preposition", ""))
		"inventory":
			_show_inventory()
		"take":
			_take(parsed["object"], parsed["indirect_object"])
		"drop":
			_drop(parsed["object"], parsed["indirect_object"])
		"open":
			_open(parsed["object"], parsed["indirect_object"])
		"close":
			_close(parsed["object"])
		"read":
			_read(parsed["object"])
		"wear":
			_wear(parsed["object"])
		"unwear":
			_unwear(parsed["object"])
		"eat":
			_eat(parsed["object"])
		"drink":
			_drink(parsed["object"])
		"enter":
			_enter(parsed["object"])
		"exit":
			_exit_container()
		"attack":
			_attack(parsed["object"], parsed["indirect_object"])
		"give":
			_give(parsed["object"], parsed["indirect_object"])
		"wait":
			_wait()
		"shoot":
			_shoot_dragon()
		"save":
			_save_game()
		"load":
			_load_game()
		"help":
			_show_help()
		_:
			print_to_log("Вы не можете сделать это сейчас.", Color.GRAY)
			
	_end_turn()

func _end_turn() -> void:
	turn_count += 1
	game_time += 1
	
	# Обновление суточного цикла
	var old_phase = day_phase
	day_phase = (game_time / PHASE_LENGTH) % 4
	if day_phase != old_phase:
		match day_phase:
			0:
				print_to_log(tr_text("\n[color=yellow]Встает солнце. Наступает ясный день.[/color]", "\n[color=yellow]The sun rises. Day dawns.[/color]"), Color.YELLOW)
				_trigger_trolls_dawn()
			1:
				print_to_log(tr_text("\n[color=orange]Солнце клонится к закату. Наступают сумерки.[/color]", "\n[color=orange]The sun sinks in the west. Dusk falls.[/color]"), Color.ORANGE)
				if current_room_id == 42 or current_room_id == 47:
					_trigger_thrush_event()
			2:
				print_to_log(tr_text("\n[color=royalblue]Сгущается тьма. Настала глухая ночь.[/color]", "\n[color=royalblue]Darkness gathers. It is night.[/color]"), Color.ROYAL_BLUE)
			3:
				print_to_log(tr_text("\n[color=cornflowerblue]Небо на востоке начинает светлеть. Близится рассвет.[/color]", "\n[color=cornflowerblue]The sky lightens in the east. Dawn approaches.[/color]"), Color.CORNFLOWER_BLUE)
				
	# Проверка свечения меча Жало
	var sting = items.get(14)
	if sting and (sting["location"] == 0 or sting["location"] == current_room_id):
		if is_enemy_nearby():
			print_to_log(tr_text("[color=cyan]Клинок меча Жало ярко сияет холодным голубым пламенем![/color]", "[color=cyan]The blade of Sting glows with a bright cold blue light![/color]"), Color.CYAN)
			
	if world_sim:
		world_sim.process_turn()
		
	world_updated.emit()

func _trigger_trolls_dawn() -> void:
	if not trolls_are_stone:
		trolls_are_stone = true
		for t_id in [71, 72]:
			var t = npcs.get(t_id)
			if t:
				t["is_stone"] = true
				t["is_dead"] = true
				t["name_ru"] = "Каменное изваяние тролля"
				t["name"] = "Stone statue of troll"
		if current_room_id == 5:
			print_to_log(tr_text("[color=yellow]Первый луч солнца падает на троллей! Они застывают и превращаются в неподвижные каменные глыбы![/color]", "[color=yellow]The first rays of sunlight fall upon the trolls! They turn to stone![/color]"), Color.YELLOW)
		var key = items.get(4)
		if key:
			key["location"] = 5

func _trigger_thrush_event() -> void:
	thrush_knocked = true
	print_to_log(tr_text("[color=yellow]Старый дрозд громко застучал улиткой о серый камень![/color]", "[color=yellow]An old thrush knocks a snail loudly against the grey rock![/color]"), Color.YELLOW)
	print_to_log(tr_text("[color=gold]Последний луч заходящего солнца пронзает скалу и озаряет замочную скважину потайной двери![/color]", "[color=gold]The last ray of the setting sun shines upon the rock, illuminating the hidden keyhole![/color]"), Color.GOLD)

func look() -> void:
	if current_room_id <= 0 or not rooms.has(current_room_id):
		current_room_id = 1
	var room = rooms.get(current_room_id)
	if not room:
		print_to_log(tr_text("Вы находитесь в пустоте.", "You are in the void."), Color.RED)
		return
		
	if is_dark_here():
		print_to_log(tr_text("[color=gray]Здесь абсолютно темно. Вы ничего не видите во мраке.[/color]", "[color=gray]It is pitch dark. You see nothing in the shadows.[/color]"), Color.GRAY)
		return
		
	# Заголовок локации
	var title = "[color=gold][b]" + get_room_name(room) + "[/b][/color]"
	if current_language == Language.RU:
		var orig_name = room.get("name", "")
		if orig_name != "":
			title += " [color=dim_gray](" + orig_name + ")[/color]"
	print_to_log(title)
	
	# Описание
	var desc = get_room_desc(room)
	if desc != "":
		print_to_log(desc, Color.ANTIQUE_WHITE)
		
	# Особая подсказка для переправы через Заколдованную реку
	if current_room_id == 66:
		var boat = items.get(41)
		if boat and boat.get("location") == 67:
			print_to_log(tr_text(
				"[color=cyan]На противоположном (восточном) берегу виднеется пустая лодка. Если зацепить ее веревкой, можно притянуть ее сюда.[/color]",
				"[color=cyan]An empty boat is moored on the opposite (eastern) bank. If you snag it with a rope, you can pull it here.[/color]"
			), Color.CYAN)
		
	# Выходы
	var exits_text = []
	for ex in room.get("exits", []):
		var dest_id = int(ex.get("dest", 0))
		var dir_str = ex["direction"] if current_language == Language.EN else ex.get("direction_ru", ex["direction"])
		var via_id = int(ex.get("via_obj", 0))
		if dest_id > 0 and rooms.has(dest_id):
			if via_id > 0:
				var via_obj = items.get(via_id)
				var via_name = get_item_name(via_obj) if via_obj else tr_text("дверь", "door")
				var is_open = via_obj and via_obj.get("is_open", true)
				var state = tr_text("открыто", "open") if is_open else tr_text("закрыто", "closed")
				exits_text.append("%s [%s (%s)]" % [dir_str, via_name, state])
			else:
				exits_text.append(dir_str)
		elif via_id > 0:
			var via_obj = items.get(via_id)
			var via_name = get_item_name(via_obj) if via_obj else tr_text("преграда", "obstacle")
			exits_text.append("%s [%s (%s)]" % [dir_str, via_name, tr_text("преграждает путь", "blocks the way")])
	if exits_text.size() > 0:
		print_to_log("[color=sea_green]" + tr_text("Видимые пути: ", "Visible paths: ") + ", ".join(exits_text) + "[/color]")
		
	# Предметы на локации
	var room_items = []
	for it_id in items.keys():
		var it = items[it_id]
		if it["location"] == current_room_id:
			var item_title = get_item_name(it)
			if it.get("is_container", false):
				if it.get("is_open", false):
					var inside_items = []
					for sub_id in items.keys():
						if items[sub_id]["location"] == -it["id"]:
							inside_items.append(get_item_name(items[sub_id]))
					if inside_items.size() > 0:
						item_title += " [" + tr_text("открыт, внутри: ", "open, inside: ") + ", ".join(inside_items) + "]"
					else:
						item_title += " [" + tr_text("открыт, внутри пусто", "open, empty inside") + "]"
				else:
					item_title += " [" + tr_text("закрыт", "closed") + "]"
			elif it.get("is_locked", false):
				item_title += " [" + tr_text("заперто", "locked") + "]"
			room_items.append(item_title)
			
	if room_items.size() > 0:
		print_to_log("[color=deep_sky_blue]" + tr_text("Вы видите здесь: ", "You see here: ") + ", ".join(room_items) + "[/color]")
		
	# Персонажи на локации
	var room_npcs = []
	for n_id in npcs.keys():
		var n = npcs[n_id]
		if n["location"] == current_room_id:
			room_npcs.append(get_npc_name(n))
	if room_npcs.size() > 0:
		print_to_log("[color=coral]" + tr_text("Здесь находится: ", "Here is: ") + ", ".join(room_npcs) + "[/color]")

func _go(direction: String) -> void:
	if direction == "":
		print_to_log(tr_text("Куда именно вы хотите пойти?", "Which way do you want to go?"), Color.KHAKI)
		return
		
	# Особый случай: переправа на лодке (id=41) через Заколдованную реку (между Западным берегом 66 и Восточным берегом 67)
	if inside_container_id == 41:
		var dir_l = direction.to_lower()
		if current_room_id == 66 and (dir_l == "east" or dir_l == "восток" or dir_l == "в" or dir_l == "e"):
			current_room_id = 67
			items[41]["location"] = 67
			print_to_log(tr_text(
				"[color=cyan]Вы на веслах переплываете быструю темную реку на лодке и благополучно причаливаете к восточному берегу.[/color]",
				"[color=cyan]You row across the swift dark river in the boat and land safely on the eastern bank.[/color]"
			), Color.CYAN)
			room_changed.emit(current_room_id)
			look()
			return
		elif current_room_id == 67 and (dir_l == "west" or dir_l == "запад" or dir_l == "з" or dir_l == "w"):
			current_room_id = 66
			items[41]["location"] = 66
			print_to_log(tr_text(
				"[color=cyan]Вы на веслах переплываете быструю темную реку на лодке и благополучно причаливаете к западному берегу.[/color]",
				"[color=cyan]You row across the swift dark river in the boat and land safely on the western bank.[/color]"
			), Color.CYAN)
			room_changed.emit(current_room_id)
			look()
			return
		else:
			print_to_log(tr_text(
				"Вы находитесь в лодке! Чтобы идти пешком, сначала выберитесь наружу ('вылезти').",
				"You are in the boat! To walk on foot, first climb out ('exit')."
			), Color.KHAKI)
			return

	if inside_container_id != -1:
		print_to_log(tr_text(
			"Вы находитесь внутри бочки/лодки! Сначала выберитесь наружу ('вылезти').",
			"You are inside a barrel or boat! First climb out ('exit')."
		), Color.KHAKI)
		return
		
	var room = rooms.get(current_room_id, {})
	var exits = room.get("exits", [])
	
	for ex in exits:
		if ex["direction"] == direction or ex.get("direction_ru", "") == direction:
			var dest_id = int(ex.get("dest", 0))
			var via_id = int(ex.get("via_obj", 0))
			
			# Защита от несуществующей комнаты 0 (тупики, люки в потолке, реки без прохода)
			if dest_id <= 0 or not rooms.has(dest_id):
				if via_id > 0:
					var via_obj = items.get(via_id)
					var via_name = get_item_name(via_obj) if via_obj else tr_text("Препятствие", "Obstacle")
					print_to_log(via_name + tr_text(" преграждает путь.", " blocks the way."), Color.SALMON)
				else:
					print_to_log(tr_text("Вы не можете идти в этом направлении.", "You cannot go in that direction."), Color.KHAKI)
				return
				
			# Проверка закрытых дверей
			if via_id > 0:
				var via_obj = items.get(via_id)
				if via_obj and not via_obj.get("is_open", true):
					var via_name = get_item_name(via_obj)
					print_to_log(via_name + tr_text(" преграждает путь (закрыто).", " blocks the way (closed)."), Color.SALMON)
					return
					
			# Особая проверка для смертоносной Заколдованной реки на берегах 66 и 67 без лодки
			if via_id == 9:
				print_to_log(tr_text(
					"Заколдованная Черная река преграждает путь! Ее темные воды смертоносны — вам нужна лодка, чтобы переправиться.",
					"The Enchanted Black River blocks the way! Its waters carry a magic slumber — you need a boat to cross."
				), Color.SALMON)
				return
					
			current_room_id = dest_id
			room_changed.emit(current_room_id)
			look()
			return
			
	print_to_log(tr_text("Вы не можете идти в этом направлении.", "You cannot go in that direction."), Color.KHAKI)

func _show_inventory() -> void:
	var carrying = []
	var total_mass = 0
	for it_id in items.keys():
		var it = items[it_id]
		if it["location"] == 0:
			var note = ""
			if it_id == 16 and is_invisible:
				note = tr_text(" [надето, вы невидимы!]", " [worn, you are invisible!]")
			carrying.append(get_item_name(it) + note)
			total_mass += it.get("mass", 0)
			
	if carrying.size() > 0:
		print_to_log("[color=sky_blue]" + tr_text("Вы несете:", "You are carrying:") + "[/color]\n- " + "\n- ".join(carrying), Color.SKY_BLUE)
		print_to_log(tr_text("Общий вес: %d / %d", "Total weight: %d / %d") % [total_mass, player_max_mass], Color.GRAY)
	else:
		print_to_log(tr_text("У вас ничего нет в руках.", "You are not carrying anything."), Color.SKY_BLUE)

func _find_item_by_alias(alias: String, search_loc: int) -> Dictionary:
	alias = alias.to_lower().strip_edges()
	for it_id in items.keys():
		var it = items[it_id]
		if search_loc == -999 or it["location"] == search_loc:
			for a in it.get("aliases", []):
				if a in alias or alias in a:
					return it
	return {}

func _find_npc_by_alias(alias: String, search_loc: int) -> Dictionary:
	alias = alias.to_lower().strip_edges()
	for n_id in npcs.keys():
		var n = npcs[n_id]
		if search_loc == -999 or n["location"] == search_loc:
			for a in n.get("aliases", []):
				if a in alias or alias in a:
					return n
	return {}

func _examine(object_name: String, indirect_object: String = "", prep: String = "") -> void:
	var target_query = object_name
	if indirect_object != "" and prep in ["в", "во", "внутрь", "из", "in", "into"]:
		target_query = indirect_object
		
	if target_query == "":
		look()
		return
		
	# Если игрок ввел обобщенное "вещи" / "предметы"
	if target_query in ["вещи", "вещей", "предметы", "предметов"]:
		# Если в комнате есть открытый контейнер, осматриваем его содержимое
		for cont_id in items.keys():
			var cont = items[cont_id]
			if cont["location"] == current_room_id and cont.get("is_container", false) and cont.get("is_open", false):
				_examine(cont.get("name_ru", cont["name"]))
				return
		_show_inventory()
		return
		
	# 1. Поиск предмета в текущей комнате или инвентаре
	var it = _find_item_by_alias(target_query, current_room_id)
	if it.is_empty():
		it = _find_item_by_alias(target_query, 0)
	if it.is_empty():
		# Поиск внутри открытых контейнеров текущей локации
		for cont_id in items.keys():
			var cont = items[cont_id]
			if cont["location"] == current_room_id and cont.get("is_container", false) and cont.get("is_open", false):
				for sub_id in items.keys():
					if items[sub_id]["location"] == -cont["id"]:
						for a in items[sub_id].get("aliases", []):
							if a in target_query or target_query in a:
								it = items[sub_id]
								break
					if not it.is_empty():
						break
			if not it.is_empty():
				break
		
	if not it.is_empty():
		# Если это контейнер (сундук, шкаф, бочка, тайник)
		if it.get("is_container", false):
			var it_name = get_item_name(it)
			var is_open = it.get("is_open", false)
			if not is_open:
				print_to_log(tr_text(
					it_name + " закрыт. Сначала откройте его командой: ОТКРЫТЬ " + it_name.to_upper() + ".",
					it_name + " is closed. First open it with command: OPEN " + it_name.to_upper() + "."
				), Color.KHAKI)
				return
				
			var inside_items = []
			for sub_id in items.keys():
				if items[sub_id]["location"] == -it["id"]:
					inside_items.append(get_item_name(items[sub_id]))
					
			if inside_items.size() > 0:
				print_to_log(tr_text(
					"[color=deep_sky_blue]Вы заглядываете в " + it_name + ".\nВнутри лежит: " + ", ".join(inside_items) + ".[/color]",
					"[color=deep_sky_blue]You look inside " + it_name + ".\nInside you see: " + ", ".join(inside_items) + ".[/color]"
				), Color.DEEP_SKY_BLUE)
			else:
				print_to_log(tr_text(
					"[color=deep_sky_blue]Вы заглядываете в " + it_name + ".\nВнутри сейчас пусто.[/color]",
					"[color=deep_sky_blue]You look inside " + it_name + ".\nIt is currently empty inside.[/color]"
				), Color.DEEP_SKY_BLUE)
			return
			
		# Если это дверь / преграда
		var nm_l = it.get("name", "").to_lower() + " " + it.get("name_ru", "").to_lower()
		if "двер" in nm_l or "door" in nm_l or "люк" in nm_l or "trapdoor" in nm_l or "gate" in nm_l or "врата" in nm_l:
			var it_name = get_item_name(it)
			var is_op = it.get("is_open", false)
			var is_loc = it.get("is_locked", false)
			var state_str = tr_text("открыта", "open") if is_op else tr_text("закрыта", "closed")
			if is_loc:
				state_str += tr_text(" (заперта на ключ)", " (locked)")
			print_to_log(it_name + ": " + state_str + ".", Color.WHITE)
			return
			
		# Обычный предмет
		var desc = get_item_desc(it)
		var it_name = get_item_name(it)
		if desc != "":
			print_to_log(it_name + ": " + desc, Color.WHITE)
		else:
			print_to_log(tr_text("Вы внимательно осматриваете " + it_name + ". Ничего необычного.", "You examine the " + it_name + ". Nothing unusual."), Color.WHITE)
		return
		
	# 2. Поиск персонажа
	var npc = _find_npc_by_alias(target_query, current_room_id)
	if not npc.is_empty():
		var desc = get_npc_desc(npc)
		var n_name = get_npc_name(npc)
		if desc != "":
			print_to_log("[color=coral]" + n_name + ": " + desc + "[/color]", Color.CORAL)
		else:
			print_to_log(tr_text("Вы осматриваете " + n_name + ".", "You look at " + n_name + "."), Color.CORAL)
		return
		
	print_to_log(tr_text("Вы не видите здесь ничего с названием '" + target_query + "'.", "You do not see '" + target_query + "' here."), Color.KHAKI)

func _take(object_name: String, from_container: String = "") -> void:
	if object_name == "":
		print_to_log(tr_text("Что именно вы хотите взять?", "What do you want to take?"), Color.KHAKI)
		return
		
	if is_dark_here():
		print_to_log(tr_text("В кромешной тьме ничего не видно.", "You see nothing in the dark."), Color.GRAY)
		return
		
	# Если игрок указал конкретный контейнер
	if from_container != "":
		var cont = _find_item_by_alias(from_container, current_room_id)
		if cont.is_empty():
			cont = _find_item_by_alias(from_container, 0)
		if cont.is_empty():
			print_to_log(tr_text("Вы не видите здесь " + from_container + ".", "You do not see " + from_container + " here."), Color.KHAKI)
			return
		if not cont.get("is_open", true):
			print_to_log(get_item_name(cont) + tr_text(" закрыт! Сначала откройте его.", " is closed! Open it first."), Color.KHAKI)
			return
			
		for sub_id in items.keys():
			var sub_it = items[sub_id]
			if sub_it["location"] == -cont["id"]:
				for a in sub_it.get("aliases", []):
					if a in object_name or object_name in a:
						sub_it["location"] = 0
						print_to_log(tr_text("Вы достали " + get_item_name(sub_it) + " из " + get_item_name(cont) + ".", "You take the " + get_item_name(sub_it) + " from the " + get_item_name(cont) + "."), Color.WHITE)
						inventory_changed.emit()
						return
		print_to_log(tr_text("Внутри " + get_item_name(cont) + " нет такого предмета.", "There is no such item in " + get_item_name(cont) + "."), Color.KHAKI)
		return

	# Команда "взять всё"
	if object_name in ["всё", "все", "all"]:
		var count = 0
		for it_id in items.keys():
			var it = items[it_id]
			if it["location"] == current_room_id:
				it["location"] = 0
				print_to_log(tr_text("Вы взяли " + get_item_name(it) + ".", "You take the " + get_item_name(it) + "."), Color.WHITE)
				count += 1
		if count == 0:
			print_to_log(tr_text("Здесь нечего брать.", "There is nothing to take here."), Color.KHAKI)
		else:
			inventory_changed.emit()
		return
		
	# Ищем предмет на полу
	var it = _find_item_by_alias(object_name, current_room_id)
	if it.is_empty():
		# Если на полу нет, проверяем открытые контейнеры в комнате
		for cont_id in items.keys():
			var cont = items[cont_id]
			if cont["location"] == current_room_id and cont.get("is_container", false) and cont.get("is_open", false):
				for sub_id in items.keys():
					var sub_it = items[sub_id]
					if sub_it["location"] == -cont["id"]:
						for a in sub_it.get("aliases", []):
							if a in object_name or object_name in a:
								sub_it["location"] = 0
								print_to_log(tr_text("Вы достали " + get_item_name(sub_it) + " из " + get_item_name(cont) + ".", "You take the " + get_item_name(sub_it) + " from the " + get_item_name(cont) + "."), Color.WHITE)
								inventory_changed.emit()
								return
		print_to_log(tr_text("Вы не видите здесь такого предмета.", "You do not see that item here."), Color.KHAKI)
		return
		
	if it.get("mass", 0) > player_max_mass:
		print_to_log(tr_text("Это слишком тяжело для хоббита!", "That is too heavy for a hobbit to carry!"), Color.SALMON)
		return
		
	it["location"] = 0
	print_to_log(tr_text("Вы взяли " + get_item_name(it) + ".", "You take the " + get_item_name(it) + "."), Color.WHITE)
	inventory_changed.emit()

func _drop(object_name: String, into_container: String = "") -> void:
	if object_name == "":
		print_to_log(tr_text("Что вы хотите положить или бросить?", "What do you want to drop or put down?"), Color.KHAKI)
		return
		
	if object_name in ["всё", "все", "all"]:
		var count = 0
		for it_id in items.keys():
			var it = items[it_id]
			if it["location"] == 0:
				it["location"] = current_room_id
				if it["id"] == 16:
					is_invisible = false
				print_to_log(tr_text("Вы бросили " + get_item_name(it) + ".", "You drop the " + get_item_name(it) + "."), Color.WHITE)
				count += 1
		if count == 0:
			print_to_log(tr_text("У вас ничего нет.", "You are carrying nothing."), Color.KHAKI)
		else:
			inventory_changed.emit()
		return
		
	var it = _find_item_by_alias(object_name, 0)
	if it.is_empty():
		print_to_log(tr_text("У вас нет этого предмета.", "You are not carrying that item."), Color.KHAKI)
		return
		
	# Если кладем в контейнер
	if into_container != "":
		var cont = _find_item_by_alias(into_container, current_room_id)
		if not cont.is_empty() and cont.get("is_container", false):
			if not cont.get("is_open", true):
				print_to_log(get_item_name(cont) + tr_text(" закрыт!", " is closed!"), Color.SALMON)
				return
			it["location"] = -cont["id"]
			print_to_log(tr_text("Вы положили " + get_item_name(it) + " в " + get_item_name(cont) + ".", "You put the " + get_item_name(it) + " into the " + get_item_name(cont) + "."), Color.WHITE)
			
			if it["id"] == 35 and cont["id"] == 37 and current_room_id == 1:
				_win_game()
				
			inventory_changed.emit()
			return
			
	it["location"] = current_room_id
	if it["id"] == 16:
		is_invisible = false
	print_to_log(tr_text("Вы бросили " + get_item_name(it) + ".", "You drop the " + get_item_name(it) + "."), Color.WHITE)
	inventory_changed.emit()

func _open(object_name: String, with_key_name: String = "") -> void:
	if object_name == "":
		print_to_log(tr_text("Что вы хотите открыть?", "What do you want to open?"), Color.KHAKI)
		return
		
	var it = _find_item_by_alias(object_name, current_room_id)
	if it.is_empty():
		print_to_log(tr_text("Вы не видите этого здесь.", "You do not see that here."), Color.KHAKI)
		return
		
	var it_name = get_item_name(it)
	if it.get("is_open", false):
		print_to_log(tr_text("Это уже открыто.", "It is already open."), Color.WHITE)
		return
		
	# Если заперто на ключ
	if it.get("is_locked", false):
		var req_key = it.get("key_id", 0)
		var has_key = false
		for k_id in items.keys():
			if items[k_id]["location"] == 0 and items[k_id]["id"] == req_key:
				has_key = true
				break
				
		if has_key:
			it["is_locked"] = false
			it["is_open"] = true
			print_to_log(tr_text("Вы вставили ключ в замочную скважину. Раздался щелчок, и " + it_name + " распахнулась!", "You turn the key in the lock. With a click, the " + it_name + " opens!"), Color.GREEN)
		else:
			print_to_log(tr_text("Заперто! Вам нужен подходящий ключ.", "It is locked! You need the right key."), Color.SALMON)
			return
	else:
		it["is_open"] = true
		print_to_log(tr_text("Вы открыли " + it_name + ".", "You open the " + it_name + "."), Color.WHITE)
		
	# Если это контейнер, сразу сообщаем, что внутри!
	if it.get("is_container", false):
		var inside_items = []
		for sub_id in items.keys():
			if items[sub_id]["location"] == -it["id"]:
				inside_items.append(get_item_name(items[sub_id]))
		if inside_items.size() > 0:
			print_to_log(tr_text("[color=deep_sky_blue]Внутри лежит: " + ", ".join(inside_items) + ".[/color]", "[color=deep_sky_blue]Inside you see: " + ", ".join(inside_items) + ".[/color]"), Color.DEEP_SKY_BLUE)
		else:
			print_to_log(tr_text("[color=deep_sky_blue]Внутри пока пусто.[/color]", "[color=deep_sky_blue]It is empty inside.[/color]"), Color.DEEP_SKY_BLUE)

func _close(object_name: String) -> void:
	if object_name == "":
		print_to_log(tr_text("Что вы хотите закрыть?", "What do you want to close?"), Color.KHAKI)
		return
	var it = _find_item_by_alias(object_name, current_room_id)
	if it.is_empty():
		print_to_log(tr_text("Вы не видите этого здесь.", "You do not see that here."), Color.KHAKI)
		return
	it["is_open"] = false
	print_to_log(tr_text("Вы закрыли " + get_item_name(it) + ".", "You close the " + get_item_name(it) + "."), Color.WHITE)

func _read(object_name: String) -> void:
	var it = _find_item_by_alias(object_name, 0)
	if it.is_empty():
		it = _find_item_by_alias(object_name, current_room_id)
	if it.is_empty():
		print_to_log(tr_text("Что вы хотите прочесть?", "What do you want to read?"), Color.KHAKI)
		return
		
	if it["id"] == 13 or it["id"] == 3: # Карта Трора
		if day_phase == 2 and current_room_id == 9: # Ночь в Ривенделле
			print_to_log(tr_text(
				"[color=cyan]При серебряном свете луны на карте проявляются тайные лунные руны:\n'Встань у серого камня, когда застучит дрозд, и заходящее солнце осветит замочную скважину.'[/color]",
				"[color=cyan]By the silver light of the moon, secret moon-runes appear on the map:\n'Stand by the grey stone when the thrush knocks, and the setting sun with the last light of Durin's Day will shine upon the key-hole.'[/color]"
			), Color.CYAN)
		else:
			print_to_log(tr_text(
				"На карте гномов начертаны контуры Одинокой Горы, река и рунические надписи на древнем наречии.",
				"The dwarven map shows the contours of the Lonely Mountain, the River Running, and ancient runes."
			), Color.WHITE)
	else:
		print_to_log(tr_text("Здесь нет текста для чтения.", "There is no text to read on this."), Color.WHITE)

func _wear(object_name: String) -> void:
	var it = _find_item_by_alias(object_name, 0)
	if it.is_empty() or it["id"] != 16:
		print_to_log(tr_text("Вы можете надеть только волшебное Кольцо.", "You can only wear the magic Ring."), Color.KHAKI)
		return
		
	is_invisible = true
	print_to_log(tr_text(
		"[color=gold]Вы надели волшебное Кольцо на палец! Воздух задрожал, и вы стали абсолютно невидимы для окружающих![/color]",
		"[color=gold]You slip the magic Ring onto your finger! The world shimmers, and you vanish from sight![/color]"
	), Color.GOLD)

func _unwear(object_name: String) -> void:
	if not is_invisible:
		print_to_log(tr_text("Вы ничего не носите.", "You are not wearing anything."), Color.KHAKI)
		return
	is_invisible = false
	print_to_log(tr_text("Вы сняли Кольцо и вновь стали видимы для всех.", "You take off the Ring and reappear before everyone."), Color.WHITE)

func _eat(object_name: String) -> void:
	var it = _find_item_by_alias(object_name, 0)
	if it.is_empty() or not it["id"] in [34, 38]:
		print_to_log(tr_text("Это нельзя съесть.", "You cannot eat that."), Color.KHAKI)
		return
	it["location"] = -999
	player_health = min(100, player_health + 30)
	player_strength = min(100, player_strength + 30)
	print_to_log(tr_text("Вы с наслаждением подкрепились. Силы вернулись к вам!", "You eat with relish. Your strength returns!"), Color.GREEN)
	inventory_changed.emit()

func _drink(object_name: String) -> void:
	var it = _find_item_by_alias(object_name, 0)
	if it.is_empty():
		it = _find_item_by_alias(object_name, current_room_id)
	if it.is_empty() or not it["id"] in [20, 21, 23, 39]:
		print_to_log(tr_text("Вы не можете это выпить.", "You cannot drink that."), Color.KHAKI)
		return
	print_to_log(tr_text("Вы сделали большой глоток. Прекрасно утоляет жажду!", "You take a hearty drink. It quenches your thirst!"), Color.GREEN)

func _enter(object_name: String) -> void:
	var target_l = object_name.to_lower()
	if current_room_id == 66 and ("лодк" in target_l or "boat" in target_l):
		var boat = items.get(41)
		if boat and boat["location"] == 67:
			print_to_log(tr_text("Лодка находится на противоположном берегу! Сначала притяните ее веревкой.", "The boat is on the far bank! First pull it across with a rope."), Color.KHAKI)
			return

	var it = _find_item_by_alias(object_name, current_room_id)
	var item_id = int(it.get("id", -1))
	if it.is_empty() or not (item_id in [19, 41]):
		print_to_log(tr_text("Вы не можете забраться внутрь этого.", "You cannot enter that."), Color.KHAKI)
		return
	inside_container_id = item_id
	print_to_log(tr_text("Вы ловко залезли внутрь " + get_item_name(it) + ".", "You climb inside the " + get_item_name(it) + "."), Color.WHITE)
	
	if item_id == 19 and current_room_id == 32:
		var trapdoor = items.get(40) # люк в погребе
		if trapdoor and trapdoor.get("is_open", false):
			_trigger_barrel_escape()

func _pull_boat_with_rope() -> void:
	var rope = items.get(18)
	var boat = items.get(41)
	if not boat:
		return
	if boat["location"] == 66:
		print_to_log(tr_text("Лодка уже причалена к этому берегу.", "The boat is already moored at this bank."), Color.KHAKI)
		return
	if not rope or (rope["location"] != 0 and rope["location"] != current_room_id):
		print_to_log(tr_text(
			"Лодка находится на дальнем берегу. Вам нужна прочная веревка, чтобы зацепить ее и притянуть.",
			"The boat is on the far bank. You need a strong rope to snag and pull it across."
		), Color.KHAKI)
		return
	boat["location"] = 66
	print_to_log(tr_text(
		"[color=cyan]Вы ловко забрасываете веревку через реку. Крюк цепляется за борт лодки, и вы плавно подтягиваете ее к западному берегу![/color]",
		"[color=cyan]You skillfully cast the rope across the water. It catches the boat, and you pull it safely to the western bank![/color]"
	), Color.CYAN)
	print_to_log(tr_text(
		"[color=white]Теперь лодка у вашего берега. Вы можете залезть в нее ('сесть в лодку') и переправиться на восток.[/color]",
		"[color=white]The boat is now at your shore. You can climb in ('enter boat') and row east.[/color]"
	), Color.WHITE)
	world_updated.emit()

func _exit_container() -> void:
	if inside_container_id == -1:
		print_to_log(tr_text("Вы не находитесь ни в чем.", "You are not inside anything."), Color.KHAKI)
		return
	inside_container_id = -1
	print_to_log(tr_text("Вы выбрались наружу на твердую землю.", "You climb out onto solid ground."), Color.WHITE)

func _trigger_barrel_escape() -> void:
	print_to_log(tr_text(
		"\n[color=cyan]Бочка с грохотом падает сквозь открытый люк прямо в бурные воды Лесной реки![/color]",
		"\n[color=cyan]The barrel tumbles through the open trapdoor into the churning waters of Forest River![/color]"
	), Color.CYAN)
	print_to_log(tr_text(
		"[color=sky_blue]Течение подхватывает вас и несет мимо крутых берегов Лихолесья, сквозь Долгое озеро... прямо к Озерному городу![/color]",
		"[color=sky_blue]The current sweeps you past the steep banks of Mirkwood, across Long Lake... straight to Lake-town![/color]"
	), Color.SKY_BLUE)
	current_room_id = 35
	inside_container_id = -1
	room_changed.emit(current_room_id)
	look()

func _attack(target_name: String, weapon_name: String = "") -> void:
	if target_name == "":
		print_to_log(tr_text("Кого вы хотите атаковать?", "Who do you want to attack?"), Color.KHAKI)
		return
		
	var enemy = _find_npc_by_alias(target_name, current_room_id)
	if enemy.is_empty():
		print_to_log(tr_text("Здесь нет такого врага.", "You see no such enemy here."), Color.KHAKI)
		return
		
	if enemy.get("is_dead", false):
		print_to_log(tr_text("Враг уже повержен.", "The enemy is already slain."), Color.GRAY)
		return
		
	var has_sword = false
	for it_id in items.keys():
		if items[it_id]["location"] == 0 and (items[it_id]["id"] == 14 or items[it_id]["id"] == 12 or items[it_id]["id"] == 7):
			has_sword = true
			break
			
	if not has_sword:
		print_to_log(tr_text("Биться с врагом голыми руками без оружия — верная гибель!", "Fighting bare-handed without a weapon is certain death!"), Color.SALMON)
		_npc_attacks_player(enemy)
		return
		
	var roll = randi() % 100
	var enemy_name = get_npc_name(enemy)
	if roll > 35:
		print_to_log(tr_text(
			"[color=green]Вы наносите стремительный выпад мечом Жало и сражаете " + enemy_name + "![/color]",
			"[color=green]With a swift stroke of Sting, you cleave down the " + enemy_name + "![/color]"
		), Color.GREEN)
		enemy["is_dead"] = true
	else:
		print_to_log(tr_text("Ваш клинок со звоном отражен!", "Your blow is parried with a loud clang!"), Color.SALMON)
		_npc_attacks_player(enemy)

func _npc_attacks_player(npc: Dictionary) -> void:
	var n_name = get_npc_name(npc)
	if is_invisible:
		print_to_log(tr_text(
			n_name + " оглядывается в бешенстве, но не может увидеть невидимого хоббита!",
			n_name + " looks around furiously, but cannot see the invisible hobbit!"
		), Color.YELLOW)
		return
		
	var roll = randi() % 100
	if roll > 40:
		print_to_log(tr_text(
			"[color=red]" + n_name + " наносит вам сокрушительный удар![/color]",
			"[color=red]" + n_name + " lands a vicious blow upon you![/color]"
		), Color.RED)
		player_health -= 40
		if player_health <= 0:
			_die()
	else:
		print_to_log(tr_text(
			n_name + " свирепо атакует, но промахивается!",
			n_name + " attacks wildly, but misses!"
		), Color.YELLOW)

func _shoot_dragon() -> void:
	if current_room_id != 41 and current_room_id != 35:
		print_to_log(tr_text("Здесь не в кого стрелять.", "There is nothing to shoot at here."), Color.KHAKI)
		return
	var smaug = npcs.get(60)
	if not smaug or smaug.get("is_dead", false):
		print_to_log(tr_text("Дракон уже мертв.", "The dragon is already dead."), Color.WHITE)
		return
		
	var bard = npcs.get(70)
	if not bard or bard.get("location", -1) != current_room_id:
		print_to_log(tr_text(
			"Только меткий лучник Бард может поразить Смауга Черной стрелой!",
			"Only Bard the Bowman can slay Smaug with the Black Arrow!"
		), Color.SALMON)
		return
		
	print_to_log(tr_text(
		"[color=gold]Бард натягивает свой исполинский лук до самого уха и спускает тетиву!
Черная стрела с шипением вонзается прямо в незащищенное место под левой грудью Смауга!
Дракон издает душераздирающий вопль и замертво рушится на скалы! СМАУГ ПОВЕРЖЕН![/color]",
		"[color=gold]Bard draws his great bow to the ear and looses the cord!
The Black Arrow hisses into the hollow beneath Smaug's left breast!
With a terrifying screech, the mighty dragon crashes into the rocks! SMAUG IS DEAD![/color]"
	), Color.GOLD)
	smaug["is_dead"] = true
	smaug_slain = true

func _give(object_name: String, target_npc: String) -> void:
	var it = _find_item_by_alias(object_name, 0)
	var npc = _find_npc_by_alias(target_npc, current_room_id)
	if it.is_empty() or npc.is_empty():
		print_to_log(tr_text("Кому и что вы хотите отдать?", "What do you want to give, and to whom?"), Color.KHAKI)
		return
		
	it["location"] = npc["id"]
	print_to_log(tr_text(
		"Вы отдали " + get_item_name(it) + " персонажу " + get_npc_name(npc) + ".",
		"You give the " + get_item_name(it) + " to " + get_npc_name(npc) + "."
	), Color.WHITE)
	inventory_changed.emit()

func _process_companion_command(comp_id: String, parsed: Dictionary) -> void:
	match comp_id:
		"thorin":
			var th = npcs.get(63)
			if th.get("location", -1) != current_room_id:
				print_to_log(tr_text("Торина нет рядом с вами.", "Thorin is not here."), Color.KHAKI)
				return
			if parsed["verb"] == "open":
				_open(parsed["object"], parsed["indirect_object"])
				print_to_log(tr_text("Торин с гномьей силой помог открыть " + parsed["object"] + ".", "Thorin lends dwarven strength to open the " + parsed["object"] + "."), Color.GREEN)
			elif parsed["verb"] == "take":
				var it = _find_item_by_alias(parsed["object"], current_room_id)
				if not it.is_empty():
					it["location"] = 63
					print_to_log(tr_text("Торин взял " + get_item_name(it) + ".", "Thorin takes the " + get_item_name(it) + "."), Color.GREEN)
			elif parsed["verb"] == "go":
				_go(parsed["direction"])
				th["location"] = current_room_id
				print_to_log(tr_text("Торин последовал за вами.", "Thorin follows you."), Color.GREEN)
			else:
				print_to_log(tr_text("Торин кивает и говорит: 'За золото Эребора!'", "Thorin nods: 'For the gold of Erebor!'"), Color.ORANGE)
		"gandalf":
			var g = npcs.get(62)
			if g.get("location", -1) != current_room_id:
				print_to_log(tr_text("Гэндальфа нет рядом.", "Gandalf is not here."), Color.KHAKI)
				return
			print_to_log(tr_text("Гэндальф пыхтит трубкой: 'Храбрость, Бильбо, храбрость приведет нас к победе!'", "Gandalf puffs his pipe: 'Courage, Bilbo, courage will see us through!'"), Color.CYAN)
		"elrond":
			var e = npcs.get(65)
			if e.get("location", -1) != current_room_id:
				print_to_log(tr_text("Элронда нет здесь.", "Elrond is not here."), Color.KHAKI)
				return
			_read("карта")
		"bard":
			var b = npcs.get(70)
			if b.get("location", -1) != current_room_id:
				print_to_log(tr_text("Барда нет рядом.", "Bard is not here."), Color.KHAKI)
				return
			_shoot_dragon()
		_:
			print_to_log(tr_text("Персонаж не реагирует на ваши слова.", "The character does not react to your words."), Color.GRAY)

func _wait() -> void:
	print_to_log(tr_text("Время идет... Вы выжидаете.", "Time passes... You wait."), Color.GRAY)

func _die() -> void:
	game_over = true
	print_to_log(tr_text(
		"\n[color=red]*** ВЫ ПОГИБЛИ В СРЕДИЗЕМЬЕ ***\nПриключение окончено. Перезапустите игру, чтобы попробовать снова.[/color]",
		"\n[color=red]*** YOU HAVE DIED IN MIDDLE-EARTH ***\nThe adventure is over. Restart the game to try again.[/color]"
	), Color.RED)

func _win_game() -> void:
	game_won = true
	game_over = true
	world_updated.emit()
	print_to_log(tr_text(
		"\n[color=gold]****************************************************\nПОЗДРАВЛЯЕМ! ВЕЛИКАЯ ПОБЕДА!\nВы принесли сокровища Одинокой Горы обратно в Хоббитон!\nБильбо Бэггинс вернулся героем и богачом, прожив долгую и счастливую жизнь!\n****************************************************[/color]\n",
		"\n[color=gold]****************************************************\nCONGRATULATIONS! A GLORIOUS VICTORY!\nYou have brought the treasures of the Lonely Mountain back to Hobbiton!\nBilbo Baggins returned home a hero and wealthy hobbit, living happily ever after!\n****************************************************[/color]\n"
	), Color.GOLD)

func get_slot_save_path(slot_id: int) -> String:
	return "user://saves/slot_%d.json" % slot_id

func get_slot_image_path(slot_id: int) -> String:
	return "user://saves/slot_%d.png" % slot_id

func has_any_saves() -> bool:
	if FileAccess.file_exists("user://savegame.json"):
		return true
	for s in range(1, 13):
		if FileAccess.file_exists(get_slot_save_path(s)):
			return true
	return false

func save_to_slot(slot_id: int, screenshot_img: Image = null) -> bool:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")
		
	var cur_theme = ""
	var am = _get_audio_manager()
	if am and "current_theme" in am:
		cur_theme = am.current_theme
		
	var r_name = rooms.get(current_room_id, {}).get("name", "Неизвестная локация")
	var phase_names = ["День", "Закат", "Ночь", "Рассвет"]
	var phase_name = phase_names[day_phase % 4]
	var mode_names = ["Современный (Modern)", "Ретро (VGA)", "Классический (ZX)"]
	var mode_name = mode_names[int(game_mode) % 3]
	
	var dt = Time.get_datetime_dict_from_system()
	var dt_str = "%02d.%02d.%04d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
	
	var sips = 0
	if world_sim and "butler_wine_sips" in world_sim:
		sips = world_sim.butler_wine_sips
		
	var data = {
		"slot_id": slot_id,
		"timestamp": dt_str,
		"room_name": r_name,
		"current_room_id": current_room_id,
		"game_time": game_time,
		"turn_count": turn_count,
		"day_phase": day_phase,
		"day_phase_name": phase_name,
		"game_mode": int(game_mode),
		"game_mode_name": mode_name,
		"language": int(current_language),
		"player_health": player_health,
		"player_strength": player_strength,
		"player_max_mass": player_max_mass,
		"player_max_volume": player_max_volume,
		"is_invisible": is_invisible,
		"inside_container_id": inside_container_id,
		"carried_by_npc_id": carried_by_npc_id,
		"trolls_are_stone": trolls_are_stone,
		"thrush_knocked": thrush_knocked,
		"smaug_revealed_weakness": smaug_revealed_weakness,
		"smaug_slain": smaug_slain,
		"game_won": game_won,
		"game_over": game_over,
		"butler_wine_sips": sips,
		"current_theme": cur_theme,
		"rooms": rooms,
		"items": items,
		"npcs": npcs
	}
	
	var json_str = JSON.stringify(data, "\t")
	var f = FileAccess.open(get_slot_save_path(slot_id), FileAccess.WRITE)
	if not f:
		return false
	f.store_string(json_str)
	f.close()
	
	var f_legacy = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if f_legacy:
		f_legacy.store_string(json_str)
		f_legacy.close()
		
	var img_to_save: Image = screenshot_img
	if not img_to_save:
		if is_inside_tree():
			var vp = get_viewport()
			if vp:
				var tex = vp.get_texture()
				if tex:
					var full_img = tex.get_image()
					if full_img:
						img_to_save = full_img.duplicate()
						img_to_save.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	if img_to_save:
		img_to_save.save_png(get_slot_image_path(slot_id))
		
	return true

func load_from_slot(slot_id: int) -> bool:
	var path = get_slot_save_path(slot_id)
	if not FileAccess.file_exists(path):
		if slot_id == 1 and FileAccess.file_exists("user://savegame.json"):
			path = "user://savegame.json"
		else:
			return false
			
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed or not (parsed is Dictionary):
		return false
		
	current_room_id = int(parsed.get("current_room_id", 1))
	if current_room_id <= 0 or not rooms.has(current_room_id):
		current_room_id = 1
	game_time = int(parsed.get("game_time", 0))
	turn_count = int(parsed.get("turn_count", 0))
	day_phase = int(parsed.get("day_phase", 0))
	player_health = int(parsed.get("player_health", 100))
	player_strength = int(parsed.get("player_strength", 100))
	player_max_mass = int(parsed.get("player_max_mass", 100))
	player_max_volume = int(parsed.get("player_max_volume", 100))
	is_invisible = bool(parsed.get("is_invisible", false))
	inside_container_id = int(parsed.get("inside_container_id", -1))
	carried_by_npc_id = int(parsed.get("carried_by_npc_id", -1))
	trolls_are_stone = bool(parsed.get("trolls_are_stone", false))
	thrush_knocked = bool(parsed.get("thrush_knocked", false))
	smaug_revealed_weakness = bool(parsed.get("smaug_revealed_weakness", false))
	smaug_slain = bool(parsed.get("smaug_slain", false))
	game_won = bool(parsed.get("game_won", false))
	game_over = bool(parsed.get("game_over", false))
	
	if parsed.has("game_mode"):
		var m = int(parsed["game_mode"])
		set_game_mode(m as GameMode)
		
	if parsed.has("language"):
		var l = int(parsed["language"])
		if l in [0, 1]:
			set_language(l as Language)
		
	if world_sim:
		world_sim.butler_wine_sips = int(parsed.get("butler_wine_sips", 0))
		
	var raw_rooms = parsed.get("rooms", {})
	if not raw_rooms.is_empty():
		for k in raw_rooms.keys():
			var r = raw_rooms[k]
			var rid = int(k)
			r["id"] = rid
			for ex in r.get("exits", []):
				ex["dest"] = int(ex.get("dest", 0))
				ex["via_obj"] = int(ex.get("via_obj", 0))
			rooms[rid] = r
			
	var raw_items = parsed.get("items", {})
	if not raw_items.is_empty():
		items = {}
		for k in raw_items.keys():
			var i = raw_items[k]
			var iid = int(k)
			i["id"] = iid
			if i.has("location"):
				i["location"] = int(i["location"])
			if i.has("key_id"):
				i["key_id"] = int(i["key_id"])
			if i.has("mass"):
				i["mass"] = int(i["mass"])
			if i.has("volume"):
				i["volume"] = int(i["volume"])
			if i.has("strength"):
				i["strength"] = int(i["strength"])
			items[iid] = i
			
	var raw_npcs = parsed.get("npcs", {})
	if not raw_npcs.is_empty():
		npcs = {}
		for k in raw_npcs.keys():
			var n = raw_npcs[k]
			var nid = int(k)
			n["id"] = nid
			if n.has("location"):
				n["location"] = int(n["location"])
			if n.has("health"):
				n["health"] = int(n["health"])
			if n.has("max_health"):
				n["max_health"] = int(n["max_health"])
			if n.has("strength"):
				n["strength"] = int(n["strength"])
			npcs[nid] = n
			
	var am = _get_audio_manager()
	if am:
		var saved_theme = parsed.get("current_theme", "")
		if saved_theme != "":
			am.play_theme(saved_theme)
		else:
			am.play_theme(am.get_theme_for_room(current_room_id))
			
	room_changed.emit(current_room_id)
	world_updated.emit()
	inventory_changed.emit()
	look()
	print_to_log("[color=green]Игра успешно загружена из Слота %d![/color]" % slot_id, Color.GREEN)
	return true

func delete_slot(slot_id: int) -> bool:
	var j_path = get_slot_save_path(slot_id)
	var p_path = get_slot_image_path(slot_id)
	var ok = false
	if FileAccess.file_exists(j_path):
		var err = DirAccess.remove_absolute(j_path)
		if err == OK:
			ok = true
		else:
			var da = DirAccess.open("user://saves")
			if da:
				da.remove("slot_%d.json" % slot_id)
				ok = true
	if FileAccess.file_exists(p_path):
		var err_img = DirAccess.remove_absolute(p_path)
		if err_img != OK:
			var da_img = DirAccess.open("user://saves")
			if da_img:
				da_img.remove("slot_%d.png" % slot_id)
	if slot_id == 1 and FileAccess.file_exists("user://savegame.json"):
		var err_root = DirAccess.remove_absolute("user://savegame.json")
		if err_root == OK:
			ok = true
		else:
			var da_root = DirAccess.open("user://")
			if da_root:
				da_root.remove("savegame.json")
				ok = true
	return ok

func get_slot_info(slot_id: int) -> Dictionary:
	var path = get_slot_save_path(slot_id)
	if not FileAccess.file_exists(path):
		if slot_id == 1 and FileAccess.file_exists("user://savegame.json"):
			path = "user://savegame.json"
		else:
			return {"exists": false, "slot_id": slot_id}
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {"exists": false, "slot_id": slot_id}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed and parsed is Dictionary:
		parsed["exists"] = true
		parsed["slot_id"] = slot_id
		var rid = int(parsed.get("current_room_id", 1))
		parsed["room_id"] = rid
		parsed["room_name"] = get_room_name(rooms.get(rid, {}))
		parsed["health"] = int(parsed.get("player_health", 100))
		parsed["mode_name"] = str(parsed.get("game_mode_name", "Modern"))
		var img_path = get_slot_image_path(slot_id)
		if FileAccess.file_exists(img_path):
			parsed["screenshot_path"] = img_path
		return parsed
	return {"exists": false, "slot_id": slot_id}

func _save_game() -> bool:
	if save_to_slot(1):
		print_to_log(tr_text("[color=green]Игра успешно сохранена![/color]", "[color=green]Game successfully saved![/color]"), Color.GREEN)
		return true
	else:
		print_to_log(tr_text("Ошибка при сохранении игры.", "Error saving game."), Color.RED)
		return false

func _load_game() -> bool:
	if not load_from_slot(1):
		print_to_log(tr_text("Файл сохранения не найден.", "Save file not found."), Color.SALMON)
		return false
	return true

func _show_help() -> void:
	var help_text_ru = """
[color=yellow]СПРАВКА ПО УПРАВЛЕНИЮ:[/color]
- [b]Перемещение[/b]: СЕВЕР (С), ЮГ (Ю), ВОСТОК (В), ЗАПАД (З), СВ, СЗ, ЮВ, ЮЗ, ВВЕРХ, ВНИЗ.
- [b]Действия[/b]: ВЗЯТЬ <вещь>, БРОСИТЬ <вещь>, ОСМОТРЕТЬ <вещь>, ОСМОТРЕТЬСЯ (О), ИНВЕНТАРЬ (И), ЖДАТЬ (Ж).
- [b]Предметы[/b]: ОТКРЫТЬ <дверь/сундук> [КЛЮЧОМ], ЗАКРЫТЬ, ЧИТАТЬ КАРТУ, НАДЕТЬ КОЛЬЦО, СНЯТЬ КОЛЬЦО.
- [b]Еда и питье[/b]: СЪЕСТЬ ОБЕД, ВЫПИТЬ ВИНО.
- [b]Команды спутникам (Inglish)[/b]: ТОРИН, ОТКРОЙ ДВЕРЬ; ТОРИН, ВОЗЬМИ МЕЧ; БАРД, СТРЕЛЯЙ В ДРАКОНА.
- [b]Система[/b]: СОХРАНИТЬ, ЗАГРУЗИТЬ.
"""
	var help_text_en = """
[color=yellow]COMMAND HELP (INGLISH):[/color]
- [b]Movement[/b]: NORTH (N), SOUTH (S), EAST (E), WEST (W), NE, NW, SE, SW, UP (U), DOWN (D).
- [b]Actions[/b]: TAKE <item>, DROP <item>, EXAMINE <item> (X), LOOK (L), INVENTORY (I), WAIT (Z).
- [b]Objects[/b]: OPEN <door/chest> [WITH KEY], CLOSE, READ MAP, WEAR RING, REMOVE RING.
- [b]Eating & Drinking[/b]: EAT LUNCH, DRINK WINE.
- [b]Companion orders[/b]: THORIN, OPEN DOOR; THORIN, TAKE SWORD; BARD, SHOOT DRAGON.
- [b]System[/b]: SAVE, LOAD.
"""
	print_to_log(tr_text(help_text_ru, help_text_en), Color.KHAKI)
