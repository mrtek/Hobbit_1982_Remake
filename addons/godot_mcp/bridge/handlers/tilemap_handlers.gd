@tool
extends RefCounted

const MAX_BATCH := 4096
const MAX_INSPECTION := 100000
const Budget = preload("res://addons/godot_mcp/serialization/serialization_budget.gd")
const MIN_MAP_COORD := -32768
const MAX_MAP_COORD := 32767

var _editor_interface

func _init(editor_interface) -> void:
	_editor_interface = editor_interface

func _error(code: String, message: String) -> Dictionary:
	return {"__error": {"code": code, "message": message,"details":{"applied":false}}}

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
	if not is_finite(raw) or raw != floor(raw) or raw < 0.0 or raw > 2147483647.0:
		return _error("INVALID_ARGUMENT", "%s must be a non-negative integer" % label)
	return int(raw)

func _coord(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with x/y" % label)
	var x_value = value.get("x")
	var y_value = value.get("y")
	if (typeof(x_value) != TYPE_INT and typeof(x_value) != TYPE_FLOAT) or (typeof(y_value) != TYPE_INT and typeof(y_value) != TYPE_FLOAT):
		return _error("INVALID_ARGUMENT", "%s x/y must be numbers" % label)
	var x_float := float(x_value)
	var y_float := float(y_value)
	if not is_finite(x_float) or not is_finite(y_float) or x_float != floor(x_float) or y_float != floor(y_float):
		return _error("INVALID_ARGUMENT", "%s x/y must be finite integers" % label)
	var x := int(x_float)
	var y := int(y_float)
	if x < MIN_MAP_COORD or x > MAX_MAP_COORD or y < MIN_MAP_COORD or y > MAX_MAP_COORD:
		return _error("INVALID_ARGUMENT", "%s is outside the serializable TileMapLayer coordinate range" % label)
	return Vector2i(x, y)


func _atlas_coord(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with x/y" % label)
	var x_value = value.get("x")
	var y_value = value.get("y")
	if (typeof(x_value) != TYPE_INT and typeof(x_value) != TYPE_FLOAT) or (typeof(y_value) != TYPE_INT and typeof(y_value) != TYPE_FLOAT):
		return _error("INVALID_ARGUMENT", "%s x/y must be numbers" % label)
	var x_float := float(x_value)
	var y_float := float(y_value)
	if not is_finite(x_float) or not is_finite(y_float) or x_float != floor(x_float) or y_float != floor(y_float):
		return _error("INVALID_ARGUMENT", "%s x/y must be finite integers" % label)
	if x_float < 0.0 or y_float < 0.0 or x_float > 2147483647.0 or y_float > 2147483647.0:
		return _error("INVALID_ARGUMENT", "%s x/y must fit non-negative Vector2i coordinates" % label)
	return Vector2i(int(x_float), int(y_float))

func _vector2(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with x/y" % label)
	var x_value = value.get("x")
	var y_value = value.get("y")
	if (typeof(x_value) != TYPE_INT and typeof(x_value) != TYPE_FLOAT) or (typeof(y_value) != TYPE_INT and typeof(y_value) != TYPE_FLOAT):
		return _error("INVALID_ARGUMENT", "%s x/y must be numbers" % label)
	var x := float(x_value)
	var y := float(y_value)
	if not is_finite(x) or not is_finite(y):
		return _error("INVALID_ARGUMENT", "%s x/y must be finite" % label)
	return Vector2(x, y)

func _coord_dict(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _vector2_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _snapshot_vector2i(value) -> Vector2i:
	return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))

func _cell(layer: TileMapLayer, coords: Vector2i) -> Dictionary:
	return {
		"coords": _coord_dict(coords),
		"source_id": layer.get_cell_source_id(coords),
		"atlas_coords": _coord_dict(layer.get_cell_atlas_coords(coords)),
		"alternative_tile": layer.get_cell_alternative_tile(coords)
	}

func _cell_is_empty(cell: Dictionary) -> bool:
	return int(cell.get("source_id", -1)) < 0

func _cell_key(coords: Vector2i) -> String:
	return "%d:%d" % [coords.x, coords.y]

func _validate_write_cell(layer: TileMapLayer, cell: Dictionary):
	var coords = _coord(cell.get("coords"), "coords")
	if typeof(coords) == TYPE_DICTIONARY:
		return coords
	var atlas_coords = _atlas_coord(cell.get("atlas_coords"), "atlas_coords")
	if typeof(atlas_coords) == TYPE_DICTIONARY:
		return atlas_coords
	var source_id = _nonnegative_int(cell.get("source_id", -1), "source_id")
	if typeof(source_id) == TYPE_DICTIONARY:
		return source_id
	var alternative_tile = _nonnegative_int(cell.get("alternative_tile", 0), "alternative_tile")
	if typeof(alternative_tile) == TYPE_DICTIONARY:
		return alternative_tile
	var tile_set := layer.tile_set
	if not tile_set:
		return _error("TILESET_NOT_FOUND", "TileMapLayer has no TileSet")
	if not tile_set.has_source(source_id):
		return _error("SOURCE_NOT_FOUND", "TileSet source not found: %d" % source_id)
	var source := tile_set.get_source(source_id)
	if not source.has_tile(atlas_coords):
		return _error("TILE_NOT_FOUND", "Tile source has no tile at atlas coordinates %s" % str(atlas_coords))
	var stored_alternative: int = int(alternative_tile)
	if source is TileSetAtlasSource:
		stored_alternative &= ~TileSetAtlasSource.TRANSFORM_FLIP_H
		stored_alternative &= ~TileSetAtlasSource.TRANSFORM_FLIP_V
		stored_alternative &= ~TileSetAtlasSource.TRANSFORM_TRANSPOSE
	if not source.has_alternative_tile(atlas_coords, stored_alternative):
		return _error("TILE_NOT_FOUND", "Tile alternative not found: %d" % alternative_tile)
	return {
		"coords": coords,
		"source_id": source_id,
		"atlas_coords": atlas_coords,
		"alternative_tile": alternative_tile
	}

func inspect(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var layer := resolved as TileMapLayer
	var used_rect := layer.get_used_rect()
	var tile_set := layer.tile_set
	return {
		"node_path": _logical_path(root, layer),
		"type": layer.get_class(),
		"has_tileset": tile_set != null,
		"tile_size": _coord_dict(tile_set.tile_size) if tile_set else null,
		"used_cell_count": layer.get_used_cells().size(),
		"used_rect": {"position": _coord_dict(used_rect.position), "size": _coord_dict(used_rect.size)},
		"enabled": layer.enabled,
		"collision_enabled": layer.collision_enabled,
		"navigation_enabled": layer.navigation_enabled
	}

func get_cells(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var layer := resolved as TileMapLayer
	var coords_values: Array = []
	if params.has("coords"):
		if typeof(params.coords) != TYPE_ARRAY or params.coords.size() > MAX_BATCH:
			return _error("LIMIT_EXCEEDED", "coords must contain at most %d entries" % MAX_BATCH)
		for raw in params.coords:
			var parsed = _coord(raw, "coords")
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed
			coords_values.append(parsed)
	else:
		coords_values = layer.get_used_cells()
		if coords_values.size() > MAX_INSPECTION:
			return _error("LIMIT_EXCEEDED", "TileMapLayer inspection supports at most %d cells" % MAX_INSPECTION)
	coords_values.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var limit := int(params.get("limit",128))
	var max_bytes := int(params.get("max_bytes",224*1024))
	if limit < 1 or limit > 512 or max_bytes < 16384 or max_bytes > 224*1024:
		return _error("INVALID_ARGUMENT", "Cell page requires limit 1..512 and max_bytes 16384..229376")
	var fingerprint := PackedInt64Array()
	for coord in coords_values:
		var atlas := layer.get_cell_atlas_coords(coord)
		fingerprint.append_array(PackedInt64Array([coord.x,coord.y,layer.get_cell_source_id(coord),atlas.x,atlas.y,layer.get_cell_alternative_tile(coord)]))
	var snapshot := fingerprint.to_byte_array().hex_encode().sha256_text()
	var node_id := str(layer.get_instance_id())
	var offset := 0
	if params.has("cursor"):
		var raw := str(params.cursor)
		if raw.length()>2048 or raw.is_empty(): return _error("INVALID_TILEMAP_CURSOR", "Invalid cell cursor")
		var cursor = JSON.parse_string(Marshalls.base64_to_utf8(raw))
		if not cursor is Dictionary or cursor.get("version") != 1 or not typeof(cursor.get("offset")) in [TYPE_INT,TYPE_FLOAT]:
			return _error("INVALID_TILEMAP_CURSOR", "Invalid cell cursor")
		if cursor.get("node") != node_id or cursor.get("snapshot") != snapshot:
			return _error("TILEMAP_CURSOR_STALE", "Layer or inspected cells changed; restart enumeration")
		var raw_offset = cursor.offset
		if not is_finite(float(raw_offset)) or float(raw_offset) != floor(float(raw_offset)) or raw_offset < 0 or raw_offset > coords_values.size():
			return _error("INVALID_TILEMAP_CURSOR", "Cell cursor offset is outside this selection")
		offset = int(raw_offset)
	var cells: Array = []
	while cells.size() < limit and offset+cells.size() < coords_values.size():
		cells.append(_cell(layer,coords_values[offset+cells.size()]))
		var candidate := _cell_page(root,layer,cells,offset,coords_values.size(),snapshot,node_id)
		if not Budget.check(candidate,{"bytes":max_bytes}).is_empty():
			cells.pop_back()
			if cells.is_empty(): return _error("RESULT_TOO_LARGE", "One cell and page metadata exceed the requested byte budget")
			break
	return _cell_page(root,layer,cells,offset,coords_values.size(),snapshot,node_id)

func _cell_page(root: Node, layer: TileMapLayer, cells: Array, offset: int, total: int, snapshot: String, node_id: String) -> Dictionary:
	var end := offset + cells.size()
	var has_more := end < total
	var cursor = Marshalls.utf8_to_base64(JSON.stringify({"version":1,"node":node_id,"snapshot":snapshot,"offset":end})) if has_more else null
	return {"node_path":_logical_path(root,layer),"count":cells.size(),"total_count":total,"cells":cells,
		"has_more":has_more,"next_cursor":cursor,"snapshot":snapshot,"complete":not has_more}

func _apply_cell(layer: TileMapLayer, cell: Dictionary) -> void:
	layer.set_cell(cell.coords, int(cell.source_id), cell.atlas_coords, int(cell.alternative_tile))

func _restore_cell(layer: TileMapLayer, cell: Dictionary) -> void:
	var coords := _snapshot_vector2i(cell.coords)
	if _cell_is_empty(cell):
		layer.erase_cell(coords)
	else:
		var atlas_coords := _snapshot_vector2i(cell.atlas_coords)
		layer.set_cell(coords, int(cell.source_id), atlas_coords, int(cell.alternative_tile))

func _set_cells_internal(root: Node, layer: TileMapLayer, raw_cells: Array) -> Dictionary:
	if raw_cells.is_empty() or raw_cells.size() > MAX_BATCH:
		return _error("INVALID_ARGUMENT", "cells must contain 1..%d entries" % MAX_BATCH)
	var cells: Array = []
	var seen := {}
	for raw in raw_cells:
		if typeof(raw) != TYPE_DICTIONARY:
			return _error("INVALID_ARGUMENT", "Each cell must be an object")
		var parsed = _validate_write_cell(layer, raw)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("__error"):
			return parsed
		var key := _cell_key(parsed.coords)
		if seen.has(key):
			return _error("INVALID_ARGUMENT", "Duplicate cell coordinate: %s" % key)
		seen[key] = true
		cells.append(parsed)
	var before: Array = []
	for cell in cells:
		before.append(_cell(layer, cell.coords))
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set TileMapLayer Cells", 0, layer)
		for cell in cells:
			undo_redo.add_do_method(self, "_apply_cell", layer, cell)
		for previous in before:
			undo_redo.add_undo_method(self, "_restore_cell", layer, previous)
		undo_redo.commit_action()
	else:
		for cell in cells:
			_apply_cell(layer, cell)
	if not is_instance_valid(layer):
		return {"__error":{"code":"TILEMAP_WRITE_UNCONFIRMED","message":"Layer became unavailable during the edit",
			"details":{"executionOutcome":"unknown","appliedCount":null,"requestedCount":cells.size()}}}
	var confirmed := 0
	for cell in cells:
		if layer.get_cell_source_id(cell.coords) == cell.source_id and layer.get_cell_atlas_coords(cell.coords) == cell.atlas_coords and layer.get_cell_alternative_tile(cell.coords) == cell.alternative_tile:
			confirmed += 1
	return {"node_path": _logical_path(root, layer), "changed_count": confirmed,"requested_count":cells.size(),
		"applied_count":confirmed,"confirmation":"applied" if confirmed == cells.size() else "partial","saved":false}

func set_cell(params: Dictionary) -> Dictionary:
	var raw := params.duplicate(true)
	raw.erase("node_path")
	return set_cells({"node_path": params.get("node_path", ""), "cells": [raw]})

func set_cells(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	if typeof(params.get("cells")) != TYPE_ARRAY:
		return _error("INVALID_ARGUMENT", "cells must be an array")
	return _set_cells_internal(root, resolved as TileMapLayer, params.cells)

func erase_cells(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	if typeof(params.get("coords")) != TYPE_ARRAY or params.coords.is_empty() or params.coords.size() > MAX_BATCH:
		return _error("INVALID_ARGUMENT", "coords must contain 1..%d entries" % MAX_BATCH)
	var layer := resolved as TileMapLayer
	var coords_values: Array = []
	var seen := {}
	for raw in params.coords:
		var coords = _coord(raw, "coords")
		if typeof(coords) == TYPE_DICTIONARY:
			return coords
		var key := _cell_key(coords)
		if seen.has(key):
			return _error("INVALID_ARGUMENT", "Duplicate cell coordinate: %s" % key)
		seen[key] = true
		coords_values.append(coords)
	var before: Array = []
	for coords in coords_values:
		before.append(_cell(layer, coords))
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Erase TileMapLayer Cells", 0, layer)
		for coords in coords_values:
			undo_redo.add_do_method(layer, "erase_cell", coords)
		for previous in before:
			undo_redo.add_undo_method(self, "_restore_cell", layer, previous)
		undo_redo.commit_action()
	else:
		for coords in coords_values:
			layer.erase_cell(coords)
	return {"node_path": _logical_path(root, layer), "changed_count": coords_values.size()}

func clear(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var layer := resolved as TileMapLayer
	var coords_values := layer.get_used_cells()
	if coords_values.size() > MAX_BATCH:
		return _error("LIMIT_EXCEEDED", "TileMapLayer has %d used cells; clear limit is %d" % [coords_values.size(), MAX_BATCH])
	var before: Array = []
	for coords in coords_values:
		before.append(_cell(layer, coords))
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Clear TileMapLayer", 0, layer)
		undo_redo.add_do_method(layer, "clear")
		for previous in before:
			undo_redo.add_undo_method(self, "_restore_cell", layer, previous)
		undo_redo.commit_action()
	else:
		layer.clear()
	return {"node_path": _logical_path(root, layer), "changed_count": before.size()}

func map_to_local(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var coords = _coord(params.get("coords"), "coords")
	if typeof(coords) == TYPE_DICTIONARY:
		return coords
	var layer := resolved as TileMapLayer
	return {"node_path": _logical_path(root, layer), "coords": _coord_dict(coords), "position": _vector2_dict(layer.map_to_local(coords))}

func local_to_map(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_layer(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var position = _vector2(params.get("position"), "position")
	if typeof(position) == TYPE_DICTIONARY:
		return position
	var layer := resolved as TileMapLayer
	var coords := layer.local_to_map(position)
	if coords.x < MIN_MAP_COORD or coords.x > MAX_MAP_COORD or coords.y < MIN_MAP_COORD or coords.y > MAX_MAP_COORD:
		return _error("INVALID_ARGUMENT", "local_to_map result is outside the serializable TileMapLayer coordinate range")
	return {"node_path": _logical_path(root, layer), "position": _vector2_dict(position), "coords": _coord_dict(coords)}
