@tool
extends RefCounted

const MAX_TILES := 4096
const MAX_SOURCES := 512
const MAX_VECTOR2I := 2147483647

var _editor_interface

func _init(editor_interface) -> void:
	_editor_interface = editor_interface

func _error(code: String, message: String) -> Dictionary:
	return {"__error": {"code": code, "message": message}}

func _root() -> Node:
	return _editor_interface.get_edited_scene_root()

func _logical_path(root: Node, node: Node) -> String:
	var relative := root.get_path_to(node)
	var logical := "/%s" % root.name
	if relative != NodePath("."):
		logical += "/%s" % str(relative)
	return logical

func _resolve_node(root: Node, path_str: String) -> Node:
	if path_str.is_empty() or path_str == "." or path_str == "/%s" % root.name:
		return root
	var target := root.get_node_or_null(path_str)
	if target:
		return target
	if path_str.begins_with("/%s/" % root.name):
		return root.get_node_or_null(path_str.substr(len(root.name) + 2))
	if path_str.begins_with("/"):
		return root.get_node_or_null(path_str.substr(1))
	return null

func _resolve_layer(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is TileMapLayer:
		return _error("INVALID_NODE_TYPE", "Node is not a TileMapLayer: %s" % path_str)
	return node

func _undo_redo() -> EditorUndoRedoManager:
	return _editor_interface.get_editor_undo_redo()

func _nonnegative_int(value, label: String):
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return _error("INVALID_ARGUMENT", "%s must be a non-negative integer" % label)
	var raw := float(value)
	if not is_finite(raw) or raw != floor(raw) or raw < 0.0 or raw > MAX_VECTOR2I:
		return _error("INVALID_ARGUMENT", "%s must be a non-negative integer" % label)
	return int(raw)

func _vector2i(value, label: String, positive: bool = false):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with x/y" % label)
	var x = _nonnegative_int(value.get("x"), "%s.x" % label)
	if typeof(x) == TYPE_DICTIONARY:
		return x
	var y = _nonnegative_int(value.get("y"), "%s.y" % label)
	if typeof(y) == TYPE_DICTIONARY:
		return y
	if positive and (int(x) <= 0 or int(y) <= 0):
		return _error("INVALID_ARGUMENT", "%s x/y must be positive" % label)
	return Vector2i(int(x), int(y))

func _vector2i_dict(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _tileset(layer: TileMapLayer):
	if not layer.tile_set:
		return _error("TILESET_NOT_FOUND", "TileMapLayer has no TileSet")
	return layer.tile_set

func _source(tile_set: TileSet, source_id: int):
	if not tile_set.has_source(source_id):
		return _error("SOURCE_NOT_FOUND", "TileSet source not found: %d" % source_id)
	return tile_set.get_source(source_id)

func _atlas_source(tile_set: TileSet, source_id: int):
	var source = _source(tile_set, source_id)
	if typeof(source) == TYPE_DICTIONARY:
		return source
	if not source is TileSetAtlasSource:
		return _error("INVALID_SOURCE_TYPE", "TileSet source is not a TileSetAtlasSource: %d" % source_id)
	return source

func _atlas_summary(source_id: int, source: TileSetAtlasSource) -> Dictionary:
	var texture := source.texture
	return {
		"source_id": source_id,
		"type": source.get_class(),
		"texture_path": texture.resource_path if texture else "",
		"texture_region_size": _vector2i_dict(source.texture_region_size),
		"margins": _vector2i_dict(source.margins),
		"separation": _vector2i_dict(source.separation),
		"atlas_grid_size": _vector2i_dict(source.get_atlas_grid_size()),
		"tile_count": source.get_tiles_count()
	}

func inspect(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var layer := resolved as TileMapLayer
	if not layer.tile_set:
		return {"node_path": _logical_path(root, layer), "exists": false, "resource_path": "", "tile_size": null, "source_count": 0, "sources": []}
	var tile_set := layer.tile_set
	var source_count := tile_set.get_source_count()
	if source_count > MAX_SOURCES:
		return _error("LIMIT_EXCEEDED", "TileSet has %d sources; inspection limit is %d" % [source_count, MAX_SOURCES])
	var sources: Array = []
	for index in range(source_count):
		var source_id := tile_set.get_source_id(index)
		var source := tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			sources.append(_atlas_summary(source_id, source))
		else:
			sources.append({"source_id": source_id, "type": source.get_class()})
	sources.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.source_id) < int(b.source_id))
	return {
		"node_path": _logical_path(root, layer),
		"exists": true,
		"resource_path": tile_set.resource_path,
		"tile_size": _vector2i_dict(tile_set.tile_size),
		"source_count": source_count,
		"sources": sources
	}

func ensure_for_layer(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var layer := resolved as TileMapLayer
	if layer.tile_set:
		return {"node_path": _logical_path(root, layer), "created": false, "tile_size": _vector2i_dict(layer.tile_set.tile_size)}
	var tile_size = _vector2i(params.get("tile_size"), "tile_size", true)
	if typeof(tile_size) == TYPE_DICTIONARY:
		return tile_size
	var tile_set := TileSet.new()
	tile_set.tile_size = tile_size
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Create Embedded TileSet", 0, layer)
		undo_redo.add_do_property(layer, "tile_set", tile_set)
		undo_redo.add_undo_property(layer, "tile_set", null)
		undo_redo.commit_action()
	else:
		layer.tile_set = tile_set
	return {"node_path": _logical_path(root, layer), "created": true, "tile_size": _vector2i_dict(tile_size)}

func add_atlas_source(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var layer := resolved as TileMapLayer
	var tile_set_value = _tileset(layer)
	if typeof(tile_set_value) == TYPE_DICTIONARY:
		return tile_set_value
	var tile_set := tile_set_value as TileSet
	var texture_path := str(params.get("texture_path", ""))
	if texture_path.is_empty():
		return _error("INVALID_ARGUMENT", "texture_path is required")
	var texture = ResourceLoader.load(texture_path)
	if not texture:
		return _error("RESOURCE_NOT_FOUND", "Texture resource not found: %s" % texture_path)
	if not texture is Texture2D:
		return _error("INVALID_RESOURCE_TYPE", "Resource is not a Texture2D: %s" % texture_path)
	var region_size = _vector2i(params.get("texture_region_size"), "texture_region_size", true)
	if typeof(region_size) == TYPE_DICTIONARY:
		return region_size
	if region_size.x < tile_set.tile_size.x or region_size.y < tile_set.tile_size.y:
		return _error("INVALID_ARGUMENT", "texture_region_size must be at least TileSet.tile_size")
	var margins = _vector2i(params.get("margins", {"x": 0, "y": 0}), "margins")
	if typeof(margins) == TYPE_DICTIONARY:
		return margins
	var separation = _vector2i(params.get("separation", {"x": 0, "y": 0}), "separation")
	if typeof(separation) == TYPE_DICTIONARY:
		return separation
	var source_id := tile_set.get_next_source_id()
	if params.has("source_id"):
		var parsed_id = _nonnegative_int(params.source_id, "source_id")
		if typeof(parsed_id) == TYPE_DICTIONARY:
			return parsed_id
		source_id = parsed_id
	if tile_set.has_source(source_id):
		return _error("ALREADY_EXISTS", "TileSet source ID already exists: %d" % source_id)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = region_size
	source.margins = margins
	source.separation = separation
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Add TileSet Atlas Source", 0, layer)
		undo_redo.add_do_method(tile_set, "add_source", source, source_id)
		undo_redo.add_undo_method(tile_set, "remove_source", source_id)
		undo_redo.commit_action()
	else:
		tile_set.add_source(source, source_id)
	return {"node_path": _logical_path(root, layer), "source_id": source_id}

func inspect_atlas_source(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var layer := resolved as TileMapLayer
	var tile_set_value = _tileset(layer)
	if typeof(tile_set_value) == TYPE_DICTIONARY:
		return tile_set_value
	var parsed_id = _nonnegative_int(params.get("source_id", -1), "source_id")
	if typeof(parsed_id) == TYPE_DICTIONARY:
		return parsed_id
	var atlas_value = _atlas_source(tile_set_value as TileSet, parsed_id)
	if typeof(atlas_value) == TYPE_DICTIONARY:
		return atlas_value
	var source := atlas_value as TileSetAtlasSource
	var tile_count := source.get_tiles_count()
	if tile_count > MAX_TILES:
		return _error("LIMIT_EXCEEDED", "Atlas has %d base tiles; inspection limit is %d" % [tile_count, MAX_TILES])
	var tiles: Array = []
	for index in range(tile_count):
		var atlas_coords := source.get_tile_id(index)
		tiles.append({"atlas_coords": _vector2i_dict(atlas_coords), "size": _vector2i_dict(source.get_tile_size_in_atlas(atlas_coords))})
	tiles.sort_custom(func(a: Dictionary, b: Dictionary):
		var ac: Dictionary = a.atlas_coords
		var bc: Dictionary = b.atlas_coords
		return int(ac.y) < int(bc.y) or (int(ac.y) == int(bc.y) and int(ac.x) < int(bc.x)))
	var result := _atlas_summary(parsed_id, source)
	result["node_path"] = _logical_path(root, layer)
	result["tiles"] = tiles
	return result

func _tile_key(coords: Vector2i) -> String:
	return "%d:%d" % [coords.x, coords.y]

func create_atlas_tiles(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	if typeof(params.get("tiles")) != TYPE_ARRAY or params.tiles.is_empty() or params.tiles.size() > MAX_TILES:
		return _error("INVALID_ARGUMENT", "tiles must contain 1..%d entries" % MAX_TILES)
	var layer := resolved as TileMapLayer
	var tile_set_value = _tileset(layer)
	if typeof(tile_set_value) == TYPE_DICTIONARY:
		return tile_set_value
	var parsed_id = _nonnegative_int(params.get("source_id", -1), "source_id")
	if typeof(parsed_id) == TYPE_DICTIONARY:
		return parsed_id
	var atlas_value = _atlas_source(tile_set_value as TileSet, parsed_id)
	if typeof(atlas_value) == TYPE_DICTIONARY:
		return atlas_value
	var source := atlas_value as TileSetAtlasSource
	var validated: Array = []
	var occupied := {}
	for raw in params.tiles:
		if typeof(raw) != TYPE_DICTIONARY:
			return _error("INVALID_ARGUMENT", "Each tile must be an object")
		var atlas_coords = _vector2i(raw.get("atlas_coords"), "atlas_coords")
		if typeof(atlas_coords) == TYPE_DICTIONARY:
			return atlas_coords
		var size = _vector2i(raw.get("size", {"x": 1, "y": 1}), "size", true)
		if typeof(size) == TYPE_DICTIONARY:
			return size
		if source.has_tile(atlas_coords):
			return _error("ALREADY_EXISTS", "Atlas tile already exists at %s" % str(atlas_coords))
		if atlas_coords.x > MAX_VECTOR2I - size.x + 1 or atlas_coords.y > MAX_VECTOR2I - size.y + 1:
			return _error("INVALID_ARGUMENT", "Atlas tile extent exceeds Vector2i range")
		if not source.has_room_for_tile(atlas_coords, size, 1, Vector2i.ZERO, 1):
			return _error("INVALID_ARGUMENT", "Atlas has no room for tile at %s with size %s" % [str(atlas_coords), str(size)])
		for y in range(atlas_coords.y, atlas_coords.y + size.y):
			for x in range(atlas_coords.x, atlas_coords.x + size.x):
				var key := "%d:%d" % [x, y]
				if occupied.has(key):
					return _error("INVALID_ARGUMENT", "Requested atlas tiles overlap at %s" % key)
				occupied[key] = true
		validated.append({"atlas_coords": atlas_coords, "size": size})
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Create TileSet Atlas Tiles", 0, layer)
		for tile in validated:
			undo_redo.add_do_method(source, "create_tile", tile.atlas_coords, tile.size)
		for tile in validated:
			undo_redo.add_undo_method(source, "remove_tile", tile.atlas_coords)
		undo_redo.commit_action()
	else:
		for tile in validated:
			source.create_tile(tile.atlas_coords, tile.size)
	return {"node_path": _logical_path(root, layer), "source_id": parsed_id, "created_count": validated.size()}

func _collect_tilemap_layers(node: Node, tile_set: TileSet, out: Array) -> void:
	if node is TileMapLayer and node.tile_set == tile_set:
		out.append(node)
	for child in node.get_children():
		_collect_tilemap_layers(child, tile_set, out)

func _source_in_use(root: Node, tile_set: TileSet, source_id: int) -> bool:
	var layers: Array = []
	_collect_tilemap_layers(root, tile_set, layers)
	for layer in layers:
		for coords in (layer as TileMapLayer).get_used_cells():
			if (layer as TileMapLayer).get_cell_source_id(coords) == source_id:
				return true
	return false

func remove_source(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var layer := resolved as TileMapLayer
	var tile_set_value = _tileset(layer)
	if typeof(tile_set_value) == TYPE_DICTIONARY:
		return tile_set_value
	var tile_set := tile_set_value as TileSet
	var parsed_id = _nonnegative_int(params.get("source_id", -1), "source_id")
	if typeof(parsed_id) == TYPE_DICTIONARY:
		return parsed_id
	var source_value = _source(tile_set, parsed_id)
	if typeof(source_value) == TYPE_DICTIONARY:
		return source_value
	if _source_in_use(root, tile_set, parsed_id):
		return _error("SOURCE_IN_USE", "TileSet source is referenced by at least one TileMapLayer cell: %d" % parsed_id)
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Remove TileSet Source", 0, layer)
		undo_redo.add_do_method(tile_set, "remove_source", parsed_id)
		undo_redo.add_undo_method(tile_set, "add_source", source_value, parsed_id)
		undo_redo.commit_action()
	else:
		tile_set.remove_source(parsed_id)
	return {"node_path": _logical_path(root, layer), "source_id": parsed_id}
