class_name WorldSim
extends RefCounted

var game_state

const GANDALF = 62
const THORIN = 63
const ELROND = 65
const GOLLUM = 68
const BARD = 70
const BUTLER = 66
const TROLL1 = 71
const TROLL2 = 72
const DRAGON = 60

var butler_wine_sips: int = 0

func _init(state) -> void:
	game_state = state

func _get_npc(id: int) -> Dictionary:
	return game_state.npcs.get(id, {})

func _print_if_visible(npc_or_loc: int, text: String, color: Color = Color.ORANGE) -> void:
	if npc_or_loc == game_state.current_room_id:
		game_state.print_to_log(text, color)

func process_turn() -> void:
	_process_thorin()
	_process_gandalf()
	_process_elrond()
	_process_butler()
	_process_gollum()
	_process_trolls()
	_process_smaug()
	_process_goblins()

func _process_thorin() -> void:
	var th = _get_npc(THORIN)
	if th.is_empty() or th.get("is_dead", false):
		return
		
	var loc = th.get("location", 1)
	var roll = randi() % 100
	
	if loc == game_state.current_room_id:
		# Торин рядом с Бильбо
		if roll < 25:
			_print_if_visible(loc, "Торин садится и затягивает песню о золоте и сокровищах предков.", Color.ORANGE)
		elif roll < 45:
			_print_if_visible(loc, "Торин поправляет свой капюшон и внимательно оглядывает окрестности.", Color.ORANGE)
	else:
		# Торин пытается догнать Бильбо
		if roll < 40:
			_move_npc_towards_player(th)

func _process_gandalf() -> void:
	var g = _get_npc(GANDALF)
	if g.is_empty() or g.get("is_dead", false):
		return
		
	var loc = g.get("location", 1)
	var roll = randi() % 100
	
	if loc == game_state.current_room_id:
		if roll < 20:
			_print_if_visible(loc, "Гэндальф пускает кольца сизого дыма из трубки, задумчиво глядя вдаль.", Color.CYAN)
		elif roll < 35:
			_print_if_visible(loc, "Гэндальф опирается на посох: 'Средиземье полно опасностей, держи меч наготове.'", Color.CYAN)
	else:
		if roll < 30:
			_move_npc_randomly(g)

func _process_elrond() -> void:
	var el = _get_npc(ELROND)
	if el.is_empty():
		return
	if el.get("location") == game_state.current_room_id and game_state.current_room_id == 9:
		# В Ривенделле угощает обедом
		var lunch = game_state.items.get(38)
		if lunch and lunch.get("location") != 0 and not lunch.get("given", false):
			lunch["location"] = 0 # В инвентарь игроку
			lunch["given"] = true
			game_state.print_to_log("[color=cyan]Элронд приветливо улыбается и протягивает вам сытный эльфийский обед.[/color]", Color.CYAN)
			game_state.inventory_changed.emit()

func _process_butler() -> void:
	var b = _get_npc(BUTLER)
	if b.is_empty() or b.get("is_dead", false):
		return
		
	if b.get("location") == 32: # В винном погребе
		if not b.get("is_sleeping", false):
			butler_wine_sips += 1
			if butler_wine_sips == 2 and game_state.current_room_id == 32:
				game_state.print_to_log("Королевский дворецкий с наслаждением дегустирует кубок дорвинионского вина.", Color.ORANGE)
			elif butler_wine_sips >= 4:
				b["is_sleeping"] = true
				var keys = game_state.items.get(15)
				if keys:
					keys["location"] = 32 # Ключи падают на пол погреба!
				if game_state.current_room_id == 32:
					game_state.print_to_log("[color=yellow]Дворецкий тяжело роняет голову на стол и засыпает мертвецким сном! Связка ключей звякает об пол![/color]", Color.YELLOW)

func _process_gollum() -> void:
	var gol = _get_npc(GOLLUM)
	if gol.is_empty() or gol.get("is_dead", false):
		return
	if gol.get("location") == game_state.current_room_id and game_state.current_room_id == 17:
		if game_state.is_invisible:
			game_state.print_to_log("[color=yellow]Голлум в панике мечется по камням, вопя: 'Потеряли! Прелесссть пропала! Где оно?!'[/color]", Color.YELLOW)
		else:
			game_state.print_to_log("[color=red]Голлум злобно шипит из полумрака: 'Что у него в кармашках, моя прелесссть?! Отдай нам!'[/color]", Color.RED)

func _process_trolls() -> void:
	if game_state.trolls_are_stone:
		return
	if game_state.current_room_id == 5:
		if not game_state.is_invisible:
			var roll = randi() % 100
			if roll < 30:
				game_state.print_to_log("[color=red]Тролль Уильям хватает вас за шиворот своей лапищей: 'Гляди-ка, Том, вот и закуска пожаловала!'[/color]", Color.RED)
				game_state.player_health -= 25
				if game_state.player_health <= 0:
					game_state._die()
			else:
				game_state.print_to_log("Тролли громко ругаются между собой, споря, как лучше приготовить баранину.", Color.SALMON)

func _process_smaug() -> void:
	var sm = _get_npc(DRAGON)
	if sm.is_empty() or sm.get("is_dead", false):
		return
	if sm.get("location") == game_state.current_room_id and game_state.current_room_id == 41:
		if sm.get("is_sleeping", true):
			if not game_state.is_invisible:
				sm["is_sleeping"] = false
				game_state.print_to_log("[color=crimson]Дракон Смауг внезапно открывает один пылающий огнем глаз и чует запах вора![/color]", Color.CRIMSON)
			else:
				game_state.print_to_log("[color=gold]Дракон крепко спит на золоте. Вы невидимы и можете заметить пустое место в его броне на груди![/color]", Color.GOLD)
				game_state.smaug_revealed_weakness = true
		else:
			game_state.print_to_log("[color=crimson]Смауг расправляет гигантские крылья и изрыгает смертоносный сноп пламени![/color]", Color.CRIMSON)
			if not game_state.is_invisible:
				game_state.player_health -= 60
				if game_state.player_health <= 0:
					game_state._die()

func _process_goblins() -> void:
	for g_id in [61, 69, 73, 74, 75, 76]:
		var g = _get_npc(g_id)
		if g.is_empty() or g.get("is_dead", false):
			continue
		if g.get("location") == game_state.current_room_id and not game_state.is_invisible:
			var roll = randi() % 100
			if roll < 40:
				game_state.print_to_log("[color=red]Гоблин набрасывается на вас с визгом и кривым клинком![/color]", Color.RED)
				game_state.player_health -= 20
				if game_state.player_health <= 0:
					game_state._die()
				break

func _move_npc_towards_player(npc: Dictionary) -> void:
	var cur_loc = npc["location"]
	var room = game_state.rooms.get(cur_loc, {})
	var exits = room.get("exits", [])
	var valid_exits = []
	for ex in exits:
		var d = ex.get("dest", 0)
		if d > 0 and game_state.rooms.has(d):
			valid_exits.append(ex)
	if valid_exits.size() > 0:
		var chosen = valid_exits[randi() % valid_exits.size()]
		npc["location"] = chosen["dest"]
		if npc["location"] == game_state.current_room_id:
			game_state.print_to_log(npc.get("name_ru", npc["name"]) + " входит вслед за вами.", Color.ORANGE)

func _move_npc_randomly(npc: Dictionary) -> void:
	var cur_loc = npc["location"]
	var room = game_state.rooms.get(cur_loc, {})
	var exits = room.get("exits", [])
	var valid_exits = []
	for ex in exits:
		var d = ex.get("dest", 0)
		if d > 0 and game_state.rooms.has(d):
			valid_exits.append(ex)
	if valid_exits.size() > 0:
		var chosen = valid_exits[randi() % valid_exits.size()]
		if cur_loc == game_state.current_room_id:
			game_state.print_to_log(npc.get("name_ru", npc["name"]) + " уходит.", Color.GRAY)
		npc["location"] = chosen["dest"]
		if npc["location"] == game_state.current_room_id:
			game_state.print_to_log(npc.get("name_ru", npc["name"]) + " приходит сюда.", Color.GRAY)

