@tool
extends RefCounted

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

func _resolve_control(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is Control:
		return _error("INVALID_NODE_TYPE", "Node is not a Control: %s" % path_str)
	return node

func _undo_redo() -> EditorUndoRedoManager:
	return _editor_interface.get_editor_undo_redo()

func _rect_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}

func _vector2_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _anchors(control: Control) -> Dictionary:
	return {
		"left": control.get_anchor(SIDE_LEFT),
		"top": control.get_anchor(SIDE_TOP),
		"right": control.get_anchor(SIDE_RIGHT),
		"bottom": control.get_anchor(SIDE_BOTTOM)
	}

func _offsets(control: Control) -> Dictionary:
	return {
		"left": control.get_offset(SIDE_LEFT),
		"top": control.get_offset(SIDE_TOP),
		"right": control.get_offset(SIDE_RIGHT),
		"bottom": control.get_offset(SIDE_BOTTOM)
	}

func _layout_snapshot(control: Control) -> Dictionary:
	return {"anchors": _anchors(control), "offsets": _offsets(control)}

func _restore_layout(control: Control, snapshot: Dictionary) -> void:
	var anchors: Dictionary = snapshot.get("anchors", {})
	control.set_anchor(SIDE_LEFT, float(anchors.get("left", 0.0)), true, false)
	control.set_anchor(SIDE_TOP, float(anchors.get("top", 0.0)), true, false)
	control.set_anchor(SIDE_RIGHT, float(anchors.get("right", 0.0)), true, false)
	control.set_anchor(SIDE_BOTTOM, float(anchors.get("bottom", 0.0)), true, false)
	var offsets: Dictionary = snapshot.get("offsets", {})
	control.set_offset(SIDE_LEFT, float(offsets.get("left", 0.0)))
	control.set_offset(SIDE_TOP, float(offsets.get("top", 0.0)))
	control.set_offset(SIDE_RIGHT, float(offsets.get("right", 0.0)))
	control.set_offset(SIDE_BOTTOM, float(offsets.get("bottom", 0.0)))

func _preset(value: String) -> int:
	match value:
		"top_left": return Control.PRESET_TOP_LEFT
		"center_top": return Control.PRESET_CENTER_TOP
		"top_right": return Control.PRESET_TOP_RIGHT
		"center_left": return Control.PRESET_CENTER_LEFT
		"center": return Control.PRESET_CENTER
		"center_right": return Control.PRESET_CENTER_RIGHT
		"bottom_left": return Control.PRESET_BOTTOM_LEFT
		"center_bottom": return Control.PRESET_CENTER_BOTTOM
		"bottom_right": return Control.PRESET_BOTTOM_RIGHT
		"left_wide": return Control.PRESET_LEFT_WIDE
		"top_wide": return Control.PRESET_TOP_WIDE
		"right_wide": return Control.PRESET_RIGHT_WIDE
		"bottom_wide": return Control.PRESET_BOTTOM_WIDE
		"vcenter_wide": return Control.PRESET_VCENTER_WIDE
		"hcenter_wide": return Control.PRESET_HCENTER_WIDE
		"full_rect": return Control.PRESET_FULL_RECT
		_: return -1

func _resize_mode(value: String) -> int:
	match value:
		"min_size": return Control.PRESET_MODE_MINSIZE
		"keep_width": return Control.PRESET_MODE_KEEP_WIDTH
		"keep_height": return Control.PRESET_MODE_KEEP_HEIGHT
		"keep_size": return Control.PRESET_MODE_KEEP_SIZE
		_: return -1

func _side(value: String) -> int:
	match value:
		"left": return SIDE_LEFT
		"top": return SIDE_TOP
		"right": return SIDE_RIGHT
		"bottom": return SIDE_BOTTOM
		_: return -1

func _size_flags_to_names(flags: int) -> Array:
	var result: Array = []
	if (flags & Control.SIZE_FILL) != 0:
		result.append("fill")
	if (flags & Control.SIZE_EXPAND) != 0:
		result.append("expand")
	if (flags & Control.SIZE_SHRINK_CENTER) != 0:
		result.append("shrink_center")
	if (flags & Control.SIZE_SHRINK_END) != 0:
		result.append("shrink_end")
	return result

func _size_flags_from_names(values) -> int:
	if typeof(values) != TYPE_ARRAY:
		return -1
	var result := 0
	for raw in values:
		match str(raw):
			"fill": result |= Control.SIZE_FILL
			"expand": result |= Control.SIZE_EXPAND
			"shrink_center": result |= Control.SIZE_SHRINK_CENTER
			"shrink_end": result |= Control.SIZE_SHRINK_END
			_: return -1
	return result

func _focus_neighbor(root: Node, control: Control, side: int):
	var path := control.get_focus_neighbor(side)
	if path == NodePath(""):
		return null
	var neighbor := control.get_node_or_null(path)
	if neighbor and (root.is_ancestor_of(neighbor) or neighbor == root):
		return _logical_path(root, neighbor)
	return str(path)

func _layout_result(root: Node, control: Control) -> Dictionary:
	var parent := control.get_parent()
	return {
		"node_path": _logical_path(root, control),
		"type": control.get_class(),
		"parent_type": parent.get_class() if parent else null,
		"container_managed": parent is Container,
		"rect": _rect_dict(control.get_rect()),
		"global_rect": _rect_dict(control.get_global_rect()),
		"anchors": _anchors(control),
		"offsets": _offsets(control),
		"custom_minimum_size": _vector2_dict(control.custom_minimum_size),
		"minimum_size": _vector2_dict(control.get_combined_minimum_size()),
		"size_flags_horizontal": _size_flags_to_names(control.size_flags_horizontal),
		"size_flags_vertical": _size_flags_to_names(control.size_flags_vertical),
		"size_flags_stretch_ratio": control.size_flags_stretch_ratio,
		"focus_neighbors": {
			"left": _focus_neighbor(root, control, SIDE_LEFT),
			"top": _focus_neighbor(root, control, SIDE_TOP),
			"right": _focus_neighbor(root, control, SIDE_RIGHT),
			"bottom": _focus_neighbor(root, control, SIDE_BOTTOM)
		}
	}

func inspect_layout(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_control(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _layout_result(root, resolved as Control)

func _apply_layout_preset(control: Control, preset: int, resize_mode: int, margin: int) -> void:
	control.set_anchors_and_offsets_preset(preset, resize_mode, margin)

func set_layout_preset(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_control(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var control := resolved as Control
	var preset := _preset(str(params.get("preset", "")))
	var resize_mode := _resize_mode(str(params.get("resize_mode", "min_size")))
	if preset < 0 or resize_mode < 0:
		return _error("INVALID_ARGUMENT", "Unknown layout preset or resize mode")
	var margin := int(params.get("margin", 0))
	var before := _layout_snapshot(control)
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set UI Layout Preset: " + control.name, 0, control)
		undo_redo.add_do_method(self, "_apply_layout_preset", control, preset, resize_mode, margin)
		undo_redo.add_undo_method(self, "_restore_layout", control, before)
		undo_redo.commit_action()
	else:
		_apply_layout_preset(control, preset, resize_mode, margin)
	return {"node_path": _logical_path(root, control), "layout": _layout_result(root, control)}

func _apply_anchors(control: Control, values: Dictionary, keep_offsets: bool) -> void:
	control.set_anchor(SIDE_LEFT, float(values.left), keep_offsets, false)
	control.set_anchor(SIDE_TOP, float(values.top), keep_offsets, false)
	control.set_anchor(SIDE_RIGHT, float(values.right), keep_offsets, false)
	control.set_anchor(SIDE_BOTTOM, float(values.bottom), keep_offsets, false)

func set_anchors(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_control(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var control := resolved as Control
	var values := {"left": float(params.left), "top": float(params.top), "right": float(params.right), "bottom": float(params.bottom)}
	var keep_offsets := bool(params.get("keep_offsets", true))
	var before := _layout_snapshot(control)
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set UI Anchors: " + control.name, 0, control)
		undo_redo.add_do_method(self, "_apply_anchors", control, values, keep_offsets)
		undo_redo.add_undo_method(self, "_restore_layout", control, before)
		undo_redo.commit_action()
	else:
		_apply_anchors(control, values, keep_offsets)
	return {"node_path": _logical_path(root, control), "layout": _layout_result(root, control)}

func _apply_offsets(control: Control, values: Dictionary) -> void:
	if values.has("left"): control.set_offset(SIDE_LEFT, float(values.left))
	if values.has("top"): control.set_offset(SIDE_TOP, float(values.top))
	if values.has("right"): control.set_offset(SIDE_RIGHT, float(values.right))
	if values.has("bottom"): control.set_offset(SIDE_BOTTOM, float(values.bottom))

func set_offsets(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_control(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var control := resolved as Control
	var values: Dictionary = {}
	for key in ["left", "top", "right", "bottom"]:
		if params.has(key): values[key] = float(params[key])
	if values.is_empty():
		return _error("INVALID_ARGUMENT", "At least one offset is required")
	var before := _layout_snapshot(control)
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set UI Offsets: " + control.name, 0, control)
		undo_redo.add_do_method(self, "_apply_offsets", control, values)
		undo_redo.add_undo_method(self, "_restore_layout", control, before)
		undo_redo.commit_action()
	else:
		_apply_offsets(control, values)
	return {"node_path": _logical_path(root, control), "layout": _layout_result(root, control)}

func _apply_size_flags(control: Control, horizontal, vertical, stretch_ratio) -> void:
	if horizontal != null: control.size_flags_horizontal = int(horizontal)
	if vertical != null: control.size_flags_vertical = int(vertical)
	if stretch_ratio != null: control.size_flags_stretch_ratio = float(stretch_ratio)

func set_size_flags(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_control(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var control := resolved as Control
	var horizontal = null
	var vertical = null
	if params.has("horizontal"):
		horizontal = _size_flags_from_names(params.horizontal)
		if horizontal < 0: return _error("INVALID_ARGUMENT", "Unknown horizontal size flag")
	if params.has("vertical"):
		vertical = _size_flags_from_names(params.vertical)
		if vertical < 0: return _error("INVALID_ARGUMENT", "Unknown vertical size flag")
	var stretch_ratio = params.get("stretch_ratio", null)
	if stretch_ratio != null and float(stretch_ratio) <= 0.0:
		return _error("INVALID_ARGUMENT", "stretch_ratio must be greater than zero")
	if horizontal == null and vertical == null and stretch_ratio == null:
		return _error("INVALID_ARGUMENT", "At least one size flag or stretch_ratio is required")
	var before_h := control.size_flags_horizontal
	var before_v := control.size_flags_vertical
	var before_ratio := control.size_flags_stretch_ratio
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set UI Size Flags: " + control.name, 0, control)
		undo_redo.add_do_method(self, "_apply_size_flags", control, horizontal, vertical, stretch_ratio)
		undo_redo.add_undo_method(self, "_apply_size_flags", control, before_h, before_v, before_ratio)
		undo_redo.commit_action()
	else:
		_apply_size_flags(control, horizontal, vertical, stretch_ratio)
	return {"node_path": _logical_path(root, control), "layout": _layout_result(root, control)}

func set_focus_neighbor(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_control(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var control := resolved as Control
	var side := _side(str(params.get("side", "")))
	if side < 0:
		return _error("INVALID_ARGUMENT", "Unknown focus side")
	var raw_neighbor = params.get("neighbor_path", null)
	var neighbor_path := "" if raw_neighbor == null else str(raw_neighbor)
	var next_path := NodePath("")
	if not neighbor_path.is_empty():
		var neighbor = _resolve_control(root, neighbor_path)
		if typeof(neighbor) == TYPE_DICTIONARY:
			return neighbor
		next_path = control.get_path_to(neighbor as Control)
	var previous := control.get_focus_neighbor(side)
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set UI Focus Neighbor: " + control.name, 0, control)
		undo_redo.add_do_method(control, "set_focus_neighbor", side, next_path)
		undo_redo.add_undo_method(control, "set_focus_neighbor", side, previous)
		undo_redo.commit_action()
	else:
		control.set_focus_neighbor(side, next_path)
	return {"node_path": _logical_path(root, control), "layout": _layout_result(root, control)}
