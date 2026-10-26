class_name HobbitCGARenderer
extends TextureRect

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

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var gs = _get_game_state()
	if gs:
		gs.room_changed.connect(_on_room_changed)
		gs.world_updated.connect(_on_world_updated)
		gs.game_mode_changed.connect(_on_game_mode_changed)
		if gs.current_room_id > 0:
			_on_room_changed(gs.current_room_id)

func _on_world_updated() -> void:
	var gs = _get_game_state()
	if gs:
		_on_room_changed(gs.current_room_id)

func _on_game_mode_changed(_mode: int) -> void:
	var gs = _get_game_state()
	if gs:
		_on_room_changed(gs.current_room_id)

func _on_room_changed(room_id: int) -> void:
	var gs = _get_game_state()
	if not gs:
		return

	# Настройка сглаживания в зависимости от режима:
	# Для ретро режимов (VGA, ZX) - строгий пиксельный NEAREST, для современного - линейная фильтрация
	if int(gs.game_mode) == 0:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Финал игры: экран победы (00.png)
	if gs.game_won:
		texture = _load_texture(gs.get_image_file_for_mode("00.png"))
		return
		
	var room = gs.rooms.get(room_id, {})
	if room.is_empty():
		texture = null
		return
		
	# Если в комнате темно и нет источника света, картинка скрыта во тьме
	if gs.is_dark_here():
		texture = null
		return
		
	var base_name = room.get("image_file", "")
	
	# Специфика локации 5 (Поляна троллей):
	# Если тролли окаменели на рассвете или побеждены, показываем каменную версию (50 Trolls Clearing.png)
	if room_id == 5:
		var trolls_stone = gs.are_trolls_stone()
		if trolls_stone:
			base_name = "50 Trolls Clearing.png"
		else:
			base_name = "05 Trolls Clearing.png"
			
	if base_name == "":
		texture = null
		return
		
	var final_name = gs.get_image_file_for_mode(base_name)
	texture = _load_texture(final_name)

func _load_texture(file_name: String) -> Texture2D:
	var full_path = "res://assets/images/" + file_name
	
	if ResourceLoader.exists(full_path):
		var res = load(full_path)
		if res is Texture2D:
			return res
			
	var global_p = ProjectSettings.globalize_path(full_path)
	var img = Image.new()
	if FileAccess.file_exists(global_p) and img.load(global_p) == OK:
		return ImageTexture.create_from_image(img)
	if FileAccess.file_exists(full_path) and img.load(full_path) == OK:
		return ImageTexture.create_from_image(img)
		
	push_warning("Failed to load image: " + full_path)
	return null
