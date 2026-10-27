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
		if roll < 25:
			_print_if_visible(loc, game_state.tr_text(
				"Торин садится и затягивает песню о золоте и сокровищах предков.",
				"Thorin sits down and starts singing about gold and ancient treasures."
			), Color.ORANGE)
		elif roll < 45:
			_print_if_visible(loc, game_state.tr_text(
				"Торин поправляет свой капюшон и внимательно оглядывает окрестности.",
				"Thorin adjusts his hood and looks carefully about."
			), Color.ORANGE)
	else:
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
			_print_if_visible(loc, game_state.tr_text(
				"Гэндальф пускает кольца сизого дыма из трубки, задумчиво глядя вдаль.",
				"Gandalf blows rings of blue-grey smoke from his pipe, gazing thoughtfully into the distance."
			), Color.CYAN)
		elif roll < 35:
			_print_if_visible(loc, game_state.tr_text(
				"Гэндальф опирается на посох: 'Средиземье полно опасностей, держи меч наготове.'",
				"Gandalf leans on his staff: 'Middle-earth is full of perils, keep your sword ready.'"
			), Color.CYAN)
	else:
		if roll < 30:
			_move_npc_randomly(g)

func _process_elrond() -> void:
	var el = _get_npc(ELROND)
	if el.is_empty():
		return
	if el.get("location") == game_state.current_room_id and game_state.current_room_id == 9:
		var lunch = game_state.items.get(38)
		if lunch and lunch.get("location") != 0 and not lunch.get("given", false):
			lunch["location"] = 0
			lunch["given"] = true
			game_state.print_to_log(game_state.tr_text(
				"[color=cyan]Элронд приветливо улыбается и протягивает вам сытный эльфийский обед.[/color]",
				"[color=cyan]Elrond smiles warmly and hands you a hearty elven lunch.[/color]"
			), Color.CYAN)
			game_state.inventory_changed.emit()

func _process_butler() -> void:
	var b = _get_npc(BUTLER)
	if b.is_empty() or b.get("is_dead", false):
		return
		
	if b.get("location") == 32:
		if not b.get("is_sleeping", false):
			butler_wine_sips += 1
			if butler_wine_sips == 2 and game_state.current_room_id == 32:
				game_state.print_to_log(game_state.tr_text(
					"Королевский дворецкий с наслаждением дегустирует кубок дорвинионского вина.",
					"The royal butler savours another goblet of heady Dorwinion wine."
				), Color.ORANGE)
			elif butler_wine_sips >= 4:
				b["is_sleeping"] = true
				var keys = game_state.items.get(15)
				if keys:
					keys["location"] = 32
				if game_state.current_room_id == 32:
					game_state.print_to_log(game_state.tr_text(
						"[color=yellow]Дворецкий тяжело роняет голову на стол и засыпает мертвецким сном! Связка ключей звякает об пол![/color]",
						"[color=yellow]The butler slumps forward onto the table fast asleep! A ring of keys clatters onto the stone floor![/color]"
					), Color.YELLOW)

func _process_gollum() -> void:
	var gol = _get_npc(GOLLUM)
	if gol.is_empty() or gol.get("is_dead", false):
		return
	if gol.get("location") == game_state.current_room_id and game_state.current_room_id == 17:
		if game_state.is_invisible:
			game_state.print_to_log(game_state.tr_text(
				"[color=yellow]Голлум в панике мечется по камням, вопя: 'Потеряли! Прелесссть пропала! Где оно?!'[/color]",
				"[color=yellow]Gollum frantically dashes across the rocks, wailing: 'Lost! Precious is lost! Where is it?!'[/color]"
			), Color.YELLOW)
		else:
			game_state.print_to_log(game_state.tr_text(
				"[color=red]Голлум злобно шипит из полумрака: 'Что у него в кармашках, моя прелесссть?! Отдай нам!'[/color]",
				"[color=red]Gollum hisses viciously from the darkness: 'What has it got in its pocketses, my precious?! Give it to us!'[/color]"
			), Color.RED)

func _process_trolls() -> void:
	if game_state.trolls_are_stone:
		return
	if game_state.current_room_id == 5:
		if not game_state.is_invisible:
			var roll = randi() % 100
			if roll < 30:
				game_state.print_to_log(game_state.tr_text(
					"[color=red]Тролль Уильям хватает вас за шиворот своей лапищей: 'Гляди-ка, Том, вот и закуска пожаловала!'[/color]",
					"[color=red]William the Troll grabs you by the collar with his great paw: 'Look here, Tom, here's a tasty titbit!'[/color]"
				), Color.RED)
				game_state.player_health -= 25
				if game_state.player_health <= 0:
					game_state._die()
			else:
				game_state.print_to_log(game_state.tr_text(
					"Тролли громко ругаются между собой, споря, как лучше приготовить баранину.",
					"The trolls bicker loudly amongst themselves, arguing how best to roast mutton."
				), Color.SALMON)

func _process_smaug() -> void:
	var sm = _get_npc(DRAGON)
	if sm.is_empty() or sm.get("is_dead", false):
		return
	if sm.get("location") == game_state.current_room_id and game_state.current_room_id == 41:
		if sm.get("is_sleeping", true):
			if not game_state.is_invisible:
				sm["is_sleeping"] = false
				game_state.print_to_log(game_state.tr_text(
					"[color=crimson]Дракон Смауг внезапно открывает один пылающий огнем глаз и чует запах вора![/color]",
					"[color=crimson]Smaug the Dragon suddenly opens a slit of smouldering eye and catches the scent of a thief![/color]"
				), Color.CRIMSON)
			else:
				game_state.print_to_log(game_state.tr_text(
					"[color=gold]Дракон крепко спит на золоте. Вы невидимы и можете заметить пустое место в его броне на груди![/color]",
					"[color=gold]The dragon sleeps soundly upon his gold. Invisible, you notice an unprotected hollow in his armored breast![/color]"
				), Color.GOLD)
				game_state.smaug_revealed_weakness = true
		else:
			game_state.print_to_log(game_state.tr_text(
				"[color=crimson]Смауг расправляет гигантские крылья и изрыгает смертоносный сноп пламени![/color]",
				"[color=crimson]Smaug unfurls his colossal wings and spews a lethal blast of flame![/color]"
			), Color.CRIMSON)
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
				game_state.print_to_log(game_state.tr_text(
					"[color=red]Гоблин набрасывается на вас с визгом и кривым клинком![/color]",
					"[color=red]A goblin lunges at you with a piercing screech and a curved scimitar![/color]"
				), Color.RED)
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
			var n_name = game_state.get_npc_name(npc)
			game_state.print_to_log(game_state.tr_text(
				n_name + " входит вслед за вами.",
				n_name + " follows you in."
			), Color.ORANGE)

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
		var n_name = game_state.get_npc_name(npc)
		if cur_loc == game_state.current_room_id:
			game_state.print_to_log(game_state.tr_text(
				n_name + " уходит.",
				n_name + " leaves."
			), Color.GRAY)
		npc["location"] = chosen["dest"]
		if npc["location"] == game_state.current_room_id:
			game_state.print_to_log(game_state.tr_text(
				n_name + " приходит сюда.",
				n_name + " arrives here."
			), Color.GRAY)
