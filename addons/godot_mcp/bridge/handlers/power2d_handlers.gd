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

func _resolve_node2d(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is Node2D:
		return _error("INVALID_NODE_TYPE", "Node is not a Node2D: %s" % path_str)
	return node

func _resolve_sprite(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is Sprite2D:
		return _error("INVALID_NODE_TYPE", "Node is not a Sprite2D: %s" % path_str)
	return node

func _undo_redo() -> EditorUndoRedoManager:
	return _editor_interface.get_editor_undo_redo()

func _vector2(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with x/y" % label)
	if not value.has("x") or not value.has("y"):
		return _error("INVALID_ARGUMENT", "%s must contain x/y" % label)
	var x := float(value.x)
	var y := float(value.y)
	if not is_finite(x) or not is_finite(y):
		return _error("INVALID_ARGUMENT", "%s.x/y must be finite" % label)
	return Vector2(x, y)

func _rect2(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object" % label)
	for key in ["x", "y", "width", "height"]:
		if not value.has(key):
			return _error("INVALID_ARGUMENT", "%s must contain x/y/width/height" % label)
	var x := float(value.x)
	var y := float(value.y)
	var width := float(value.width)
	var height := float(value.height)
	if not is_finite(x) or not is_finite(y) or not is_finite(width) or not is_finite(height) or width < 0.0 or height < 0.0:
		return _error("INVALID_ARGUMENT", "%s must contain finite x/y and nonnegative width/height" % label)
	return Rect2(x, y, width, height)

func _vector2_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _vector2i_dict(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _rect2_dict(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}

func _node2d_snapshot(node: Node2D) -> Dictionary:
	return {
		"position": _vector2_dict(node.position),
		"rotation_degrees": node.rotation_degrees,
		"scale": _vector2_dict(node.scale),
		"skew_degrees": rad_to_deg(node.skew)
	}

func _restore_node2d(node: Node2D, snapshot: Dictionary) -> void:
	var position: Dictionary = snapshot.get("position", {})
	var scale: Dictionary = snapshot.get("scale", {})
	node.position = Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
	node.rotation_degrees = float(snapshot.get("rotation_degrees", 0.0))
	node.scale = Vector2(float(scale.get("x", 1.0)), float(scale.get("y", 1.0)))
	node.skew = deg_to_rad(float(snapshot.get("skew_degrees", 0.0)))

func _node2d_result(root: Node, node: Node2D) -> Dictionary:
	return {
		"node_path": _logical_path(root, node),
		"type": node.get_class(),
		"position": _vector2_dict(node.position),
		"rotation_degrees": node.rotation_degrees,
		"scale": _vector2_dict(node.scale),
		"skew_degrees": rad_to_deg(node.skew),
		"global_position": _vector2_dict(node.global_position),
		"global_rotation_degrees": node.global_rotation_degrees,
		"global_scale": _vector2_dict(node.global_scale)
	}

func inspect_node2d_transform(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_node2d(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _node2d_result(root, resolved as Node2D)

func set_node2d_transform(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_node2d(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var node := resolved as Node2D
	if not params.has("position") and not params.has("rotation_degrees") and not params.has("scale") and not params.has("skew_degrees"):
		return _error("INVALID_ARGUMENT", "At least one transform field is required")
	var before := _node2d_snapshot(node)
	var after := before.duplicate(true)
	if params.has("position"):
		var position = _vector2(params.position, "position")
		if typeof(position) == TYPE_DICTIONARY:
			return position
		after["position"] = _vector2_dict(position)
	if params.has("rotation_degrees"):
		var rotation := float(params.rotation_degrees)
		if not is_finite(rotation):
			return _error("INVALID_ARGUMENT", "rotation_degrees must be finite")
		after["rotation_degrees"] = rotation
	if params.has("scale"):
		var scale = _vector2(params.scale, "scale")
		if typeof(scale) == TYPE_DICTIONARY:
			return scale
		after["scale"] = _vector2_dict(scale)
	if params.has("skew_degrees"):
		var skew := float(params.skew_degrees)
		if not is_finite(skew):
			return _error("INVALID_ARGUMENT", "skew_degrees must be finite")
		after["skew_degrees"] = skew
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set Node2D Transform", 0, node)
		undo_redo.add_do_method(self, "_restore_node2d", node, after)
		undo_redo.add_undo_method(self, "_restore_node2d", node, before)
		undo_redo.commit_action()
	else:
		_restore_node2d(node, after)
	return _node2d_result(root, node)

func _sprite_snapshot(sprite: Sprite2D) -> Dictionary:
	return {
		"centered": sprite.centered,
		"offset": _vector2_dict(sprite.offset),
		"flip_h": sprite.flip_h,
		"flip_v": sprite.flip_v,
		"hframes": sprite.hframes,
		"vframes": sprite.vframes,
		"frame": sprite.frame,
		"region_enabled": sprite.region_enabled,
		"region_rect": _rect2_dict(sprite.region_rect),
		"region_filter_clip_enabled": sprite.region_filter_clip_enabled
	}

func _restore_sprite(sprite: Sprite2D, snapshot: Dictionary) -> void:
	var offset: Dictionary = snapshot.get("offset", {})
	var region: Dictionary = snapshot.get("region_rect", {})
	sprite.centered = bool(snapshot.get("centered", true))
	sprite.offset = Vector2(float(offset.get("x", 0.0)), float(offset.get("y", 0.0)))
	sprite.flip_h = bool(snapshot.get("flip_h", false))
	sprite.flip_v = bool(snapshot.get("flip_v", false))
	sprite.hframes = int(snapshot.get("hframes", 1))
	sprite.vframes = int(snapshot.get("vframes", 1))
	sprite.frame = int(snapshot.get("frame", 0))
	sprite.region_enabled = bool(snapshot.get("region_enabled", false))
	sprite.region_rect = Rect2(float(region.get("x", 0.0)), float(region.get("y", 0.0)), float(region.get("width", 0.0)), float(region.get("height", 0.0)))
	sprite.region_filter_clip_enabled = bool(snapshot.get("region_filter_clip_enabled", false))

func _sprite_result(root: Node, sprite: Sprite2D) -> Dictionary:
	return {
		"node_path": _logical_path(root, sprite),
		"type": sprite.get_class(),
		"texture_path": sprite.texture.resource_path if sprite.texture else "",
		"centered": sprite.centered,
		"offset": _vector2_dict(sprite.offset),
		"flip_h": sprite.flip_h,
		"flip_v": sprite.flip_v,
		"hframes": sprite.hframes,
		"vframes": sprite.vframes,
		"frame": sprite.frame,
		"frame_coords": _vector2i_dict(sprite.frame_coords),
		"region_enabled": sprite.region_enabled,
		"region_rect": _rect2_dict(sprite.region_rect),
		"region_filter_clip_enabled": sprite.region_filter_clip_enabled
	}

func inspect_sprite2d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_sprite(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _sprite_result(root, resolved as Sprite2D)

func set_sprite2d_texture(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_sprite(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var sprite := resolved as Sprite2D
	var texture: Texture2D = null
	if params.get("texture_path") != null:
		var texture_path := str(params.get("texture_path", ""))
		if not texture_path.is_empty():
			if not ResourceLoader.exists(texture_path):
				return _error("RESOURCE_NOT_FOUND", "Texture resource not found: %s" % texture_path)
			var loaded = ResourceLoader.load(texture_path)
			if not loaded:
				return _error("RESOURCE_NOT_FOUND", "Texture resource not found: %s" % texture_path)
			if not loaded is Texture2D:
				return _error("INVALID_RESOURCE_TYPE", "Resource is not a Texture2D: %s" % texture_path)
			texture = loaded as Texture2D
	var previous := sprite.texture
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set Sprite2D Texture", 0, sprite)
		undo_redo.add_do_property(sprite, "texture", texture)
		undo_redo.add_undo_property(sprite, "texture", previous)
		undo_redo.commit_action()
	else:
		sprite.texture = texture
	return _sprite_result(root, sprite)

func configure_sprite2d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_sprite(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var sprite := resolved as Sprite2D
	var before := _sprite_snapshot(sprite)
	var after := before.duplicate(true)
	var changed := false
	for key in ["centered", "flip_h", "flip_v", "region_enabled", "region_filter_clip_enabled"]:
		if params.has(key):
			after[key] = bool(params[key])
			changed = true
	if params.has("offset"):
		var offset = _vector2(params.offset, "offset")
		if typeof(offset) == TYPE_DICTIONARY:
			return offset
		after["offset"] = _vector2_dict(offset)
		changed = true
	if params.has("region_rect"):
		var region = _rect2(params.region_rect, "region_rect")
		if typeof(region) == TYPE_DICTIONARY:
			return region
		after["region_rect"] = _rect2_dict(region)
		changed = true
	var hframes := int(after.hframes)
	var vframes := int(after.vframes)
	if params.has("hframes"):
		hframes = int(params.hframes)
		if hframes < 1 or hframes > 4096:
			return _error("INVALID_ARGUMENT", "hframes must be in 1..4096")
		after["hframes"] = hframes
		changed = true
	if params.has("vframes"):
		vframes = int(params.vframes)
		if vframes < 1 or vframes > 4096:
			return _error("INVALID_ARGUMENT", "vframes must be in 1..4096")
		after["vframes"] = vframes
		changed = true
	if params.has("frame") and params.has("frame_coords"):
		return _error("INVALID_ARGUMENT", "frame and frame_coords are mutually exclusive")
	if params.has("frame"):
		var frame := int(params.frame)
		if frame < 0 or frame >= hframes * vframes:
			return _error("FRAME_OUT_OF_RANGE", "frame must fit the prospective hframes/vframes grid")
		after["frame"] = frame
		changed = true
	if params.has("frame_coords"):
		if typeof(params.frame_coords) != TYPE_DICTIONARY:
			return _error("INVALID_ARGUMENT", "frame_coords must contain x/y")
		var frame_x := int(params.frame_coords.get("x", -1))
		var frame_y := int(params.frame_coords.get("y", -1))
		if frame_x < 0 or frame_y < 0 or frame_x >= hframes or frame_y >= vframes:
			return _error("FRAME_OUT_OF_RANGE", "frame_coords must fit the prospective hframes/vframes grid")
		after["frame"] = frame_y * hframes + frame_x
		changed = true
	if not changed:
		return _error("INVALID_ARGUMENT", "At least one Sprite2D field is required")
	if int(after.frame) >= hframes * vframes:
		return _error("FRAME_OUT_OF_RANGE", "Existing frame does not fit the prospective hframes/vframes grid")
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Configure Sprite2D", 0, sprite)
		undo_redo.add_do_method(self, "_restore_sprite", sprite, after)
		undo_redo.add_undo_method(self, "_restore_sprite", sprite, before)
		undo_redo.commit_action()
	else:
		_restore_sprite(sprite, after)
	return _sprite_result(root, sprite)

func _resolve_camera(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is Camera2D:
		return _error("INVALID_NODE_TYPE", "Node is not a Camera2D: %s" % path_str)
	return node

func _camera_snapshot(camera: Camera2D) -> Dictionary:
	return {
		"enabled": camera.enabled,
		"zoom": _vector2_dict(camera.zoom),
		"offset": _vector2_dict(camera.offset),
		"ignore_rotation": camera.ignore_rotation,
		"limit_enabled": camera.limit_enabled,
		"limit_smoothed": camera.limit_smoothed,
		"limit_left": camera.limit_left,
		"limit_top": camera.limit_top,
		"limit_right": camera.limit_right,
		"limit_bottom": camera.limit_bottom,
		"position_smoothing_enabled": camera.position_smoothing_enabled,
		"position_smoothing_speed": camera.position_smoothing_speed,
		"rotation_smoothing_enabled": camera.rotation_smoothing_enabled,
		"rotation_smoothing_speed": camera.rotation_smoothing_speed,
		"drag_horizontal_enabled": camera.drag_horizontal_enabled,
		"drag_vertical_enabled": camera.drag_vertical_enabled,
		"drag_left_margin": camera.drag_left_margin,
		"drag_top_margin": camera.drag_top_margin,
		"drag_right_margin": camera.drag_right_margin,
		"drag_bottom_margin": camera.drag_bottom_margin
	}

func _restore_camera(camera: Camera2D, snapshot: Dictionary) -> void:
	var zoom: Dictionary = snapshot.get("zoom", {})
	var offset: Dictionary = snapshot.get("offset", {})
	camera.enabled = bool(snapshot.get("enabled", true))
	camera.zoom = Vector2(float(zoom.get("x", 1.0)), float(zoom.get("y", 1.0)))
	camera.offset = Vector2(float(offset.get("x", 0.0)), float(offset.get("y", 0.0)))
	camera.ignore_rotation = bool(snapshot.get("ignore_rotation", true))
	camera.limit_enabled = bool(snapshot.get("limit_enabled", true))
	camera.limit_smoothed = bool(snapshot.get("limit_smoothed", false))
	camera.limit_left = int(snapshot.get("limit_left", -10000000))
	camera.limit_top = int(snapshot.get("limit_top", -10000000))
	camera.limit_right = int(snapshot.get("limit_right", 10000000))
	camera.limit_bottom = int(snapshot.get("limit_bottom", 10000000))
	camera.position_smoothing_enabled = bool(snapshot.get("position_smoothing_enabled", false))
	camera.position_smoothing_speed = float(snapshot.get("position_smoothing_speed", 5.0))
	camera.rotation_smoothing_enabled = bool(snapshot.get("rotation_smoothing_enabled", false))
	camera.rotation_smoothing_speed = float(snapshot.get("rotation_smoothing_speed", 5.0))
	camera.drag_horizontal_enabled = bool(snapshot.get("drag_horizontal_enabled", false))
	camera.drag_vertical_enabled = bool(snapshot.get("drag_vertical_enabled", false))
	camera.set_drag_margin(SIDE_LEFT, float(snapshot.get("drag_left_margin", 0.2)))
	camera.set_drag_margin(SIDE_TOP, float(snapshot.get("drag_top_margin", 0.2)))
	camera.set_drag_margin(SIDE_RIGHT, float(snapshot.get("drag_right_margin", 0.2)))
	camera.set_drag_margin(SIDE_BOTTOM, float(snapshot.get("drag_bottom_margin", 0.2)))

func _camera_result(root: Node, camera: Camera2D) -> Dictionary:
	var result := _camera_snapshot(camera)
	result["node_path"] = _logical_path(root, camera)
	result["type"] = camera.get_class()
	return result

func inspect_camera2d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_camera(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _camera_result(root, resolved as Camera2D)

func _validate_camera_number(value, label: String, nonnegative: bool = false):
	var number := float(value)
	if not is_finite(number) or (nonnegative and number < 0.0):
		return _error("INVALID_ARGUMENT", "%s is invalid" % label)
	return number

func configure_camera2d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_camera(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var camera := resolved as Camera2D
	var before := _camera_snapshot(camera)
	var after := before.duplicate(true)
	var changed := false
	for key in ["enabled", "ignore_rotation", "limit_enabled", "limit_smoothed", "position_smoothing_enabled", "rotation_smoothing_enabled", "drag_horizontal_enabled", "drag_vertical_enabled"]:
		if params.has(key):
			after[key] = bool(params[key])
			changed = true
	if params.has("zoom"):
		var zoom = _vector2(params.zoom, "zoom")
		if typeof(zoom) == TYPE_DICTIONARY:
			return zoom
		if zoom.x <= 0.0 or zoom.y <= 0.0:
			return _error("INVALID_ARGUMENT", "zoom.x/y must be greater than zero")
		after["zoom"] = _vector2_dict(zoom)
		changed = true
	if params.has("offset"):
		var offset = _vector2(params.offset, "offset")
		if typeof(offset) == TYPE_DICTIONARY:
			return offset
		after["offset"] = _vector2_dict(offset)
		changed = true
	for key in ["position_smoothing_speed", "rotation_smoothing_speed"]:
		if params.has(key):
			var speed = _validate_camera_number(params[key], key, true)
			if typeof(speed) == TYPE_DICTIONARY:
				return speed
			after[key] = speed
			changed = true
	for key in ["drag_left_margin", "drag_top_margin", "drag_right_margin", "drag_bottom_margin"]:
		if params.has(key):
			var margin = _validate_camera_number(params[key], key)
			if typeof(margin) == TYPE_DICTIONARY:
				return margin
			if float(margin) < 0.0 or float(margin) > 1.0:
				return _error("INVALID_ARGUMENT", "%s must be in 0..1" % key)
			after[key] = margin
			changed = true
	for key in ["limit_left", "limit_top", "limit_right", "limit_bottom"]:
		if params.has(key):
			var limit := int(params[key])
			if limit < -2147483648 or limit > 2147483647:
				return _error("INVALID_ARGUMENT", "%s must fit signed 32-bit range" % key)
			after[key] = limit
			changed = true
	if int(after.limit_left) > int(after.limit_right) or int(after.limit_top) > int(after.limit_bottom):
		return _error("CAMERA_LIMITS_INVALID", "Camera limits require left <= right and top <= bottom")
	if not changed:
		return _error("INVALID_ARGUMENT", "At least one Camera2D field is required")
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Configure Camera2D", 0, camera)
		undo_redo.add_do_method(self, "_restore_camera", camera, after)
		undo_redo.add_undo_method(self, "_restore_camera", camera, before)
		undo_redo.commit_action()
	else:
		_restore_camera(camera, after)
	return _camera_result(root, camera)

func _resolve_collider(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is CollisionShape2D:
		return _error("INVALID_NODE_TYPE", "Node is not a CollisionShape2D: %s" % path_str)
	return node

func _shape_result(shape: Shape2D) -> Dictionary:
	if not shape:
		return {"kind": "none"}
	if shape is RectangleShape2D:
		return {"kind": "rectangle", "resource_path": shape.resource_path, "size": _vector2_dict((shape as RectangleShape2D).size)}
	if shape is CircleShape2D:
		return {"kind": "circle", "resource_path": shape.resource_path, "radius": (shape as CircleShape2D).radius}
	if shape is CapsuleShape2D:
		return {"kind": "capsule", "resource_path": shape.resource_path, "radius": (shape as CapsuleShape2D).radius, "height": (shape as CapsuleShape2D).height}
	return {"kind": "other", "resource_path": shape.resource_path, "type": shape.get_class()}

func _collision_result(root: Node, collider: CollisionShape2D) -> Dictionary:
	return {
		"node_path": _logical_path(root, collider),
		"type": collider.get_class(),
		"shape": _shape_result(collider.shape),
		"disabled": collider.disabled,
		"one_way_collision": collider.one_way_collision,
		"one_way_collision_margin": collider.one_way_collision_margin
	}

func inspect_collision2d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_collider(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _collision_result(root, resolved as CollisionShape2D)

func _create_shape(value):
	if value == null:
		return null
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "shape must be an object or null")
	var kind := str(value.get("kind", ""))
	match kind:
		"rectangle":
			var size = _vector2(value.get("size"), "shape.size")
			if typeof(size) == TYPE_DICTIONARY:
				return size
			if size.x <= 0.0 or size.y <= 0.0:
				return _error("INVALID_ARGUMENT", "Rectangle size must be positive")
			var rectangle := RectangleShape2D.new()
			rectangle.size = size
			return rectangle
		"circle":
			if not value.has("radius"):
				return _error("INVALID_ARGUMENT", "Circle radius is required")
			var radius := float(value.radius)
			if not is_finite(radius) or radius <= 0.0:
				return _error("INVALID_ARGUMENT", "Circle radius must be positive")
			var circle := CircleShape2D.new()
			circle.radius = radius
			return circle
		"capsule":
			if not value.has("radius") or not value.has("height"):
				return _error("INVALID_ARGUMENT", "Capsule radius and height are required")
			var radius := float(value.radius)
			var height := float(value.height)
			if not is_finite(radius) or not is_finite(height) or radius <= 0.0 or height <= 0.0:
				return _error("INVALID_ARGUMENT", "Capsule radius and height must be positive")
			if height < radius * 2.0:
				return _error("INVALID_ARGUMENT", "Capsule height must be at least twice its radius")
			var capsule := CapsuleShape2D.new()
			capsule.height = height
			capsule.radius = radius
			return capsule
		_:
			return _error("INVALID_ARGUMENT", "Unsupported CollisionShape2D shape kind: %s" % kind)

func set_collision2d_shape(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_collider(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	if not params.has("shape"):
		return _error("INVALID_ARGUMENT", "shape is required")
	var collider := resolved as CollisionShape2D
	var created = _create_shape(params.shape)
	if typeof(created) == TYPE_DICTIONARY:
		return created
	var next_shape: Shape2D = null
	if created != null:
		next_shape = created as Shape2D
	var previous := collider.shape
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set CollisionShape2D Shape", 0, collider)
		undo_redo.add_do_property(collider, "shape", next_shape)
		undo_redo.add_undo_property(collider, "shape", previous)
		undo_redo.commit_action()
	else:
		collider.shape = next_shape
	return _collision_result(root, collider)

func _resolve_parallax(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is Parallax2D:
		return _error("INVALID_NODE_TYPE", "Node is not a Parallax2D: %s" % path_str)
	return node

func _parallax_snapshot(parallax: Parallax2D) -> Dictionary:
	return {
		"repeat_size": _vector2_dict(parallax.repeat_size),
		"repeat_times": parallax.repeat_times,
		"scroll_scale": _vector2_dict(parallax.scroll_scale),
		"autoscroll": _vector2_dict(parallax.autoscroll),
		"scroll_offset": _vector2_dict(parallax.scroll_offset),
		"screen_offset": _vector2_dict(parallax.screen_offset),
		"follow_viewport": parallax.follow_viewport,
		"limit_begin": _vector2_dict(parallax.limit_begin),
		"limit_end": _vector2_dict(parallax.limit_end)
	}

func _restore_parallax(parallax: Parallax2D, snapshot: Dictionary) -> void:
	for key in ["repeat_size", "scroll_scale", "autoscroll", "scroll_offset", "screen_offset", "limit_begin", "limit_end"]:
		var value: Dictionary = snapshot.get(key, {})
		parallax.set(key, Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0))))
	parallax.repeat_times = int(snapshot.get("repeat_times", 1))
	parallax.follow_viewport = bool(snapshot.get("follow_viewport", true))

func _parallax_result(root: Node, parallax: Parallax2D) -> Dictionary:
	var result := _parallax_snapshot(parallax)
	result["node_path"] = _logical_path(root, parallax)
	result["type"] = parallax.get_class()
	return result

func inspect_parallax2d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_parallax(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _parallax_result(root, resolved as Parallax2D)

func configure_parallax2d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_parallax(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var parallax := resolved as Parallax2D
	var before := _parallax_snapshot(parallax)
	var after := before.duplicate(true)
	var changed := false
	for key in ["repeat_size", "scroll_scale", "autoscroll", "scroll_offset", "screen_offset", "limit_begin", "limit_end"]:
		if params.has(key):
			var parsed = _vector2(params[key], key)
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed
			if key == "repeat_size" and (parsed.x < 0.0 or parsed.y < 0.0):
				return _error("INVALID_ARGUMENT", "repeat_size.x/y must be nonnegative")
			after[key] = _vector2_dict(parsed)
			changed = true
	if params.has("repeat_times"):
		var repeat_times := int(params.repeat_times)
		if repeat_times < 1 or repeat_times > 1024:
			return _error("INVALID_ARGUMENT", "repeat_times must be in 1..1024")
		after["repeat_times"] = repeat_times
		changed = true
	if params.has("follow_viewport"):
		after["follow_viewport"] = bool(params.follow_viewport)
		changed = true
	var begin: Dictionary = after.limit_begin
	var end: Dictionary = after.limit_end
	if float(begin.x) > float(end.x) or float(begin.y) > float(end.y):
		return _error("PARALLAX_LIMITS_INVALID", "Parallax limits require begin <= end on both axes")
	if not changed:
		return _error("INVALID_ARGUMENT", "At least one Parallax2D field is required")
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Configure Parallax2D", 0, parallax)
		undo_redo.add_do_method(self, "_restore_parallax", parallax, after)
		undo_redo.add_undo_method(self, "_restore_parallax", parallax, before)
		undo_redo.commit_action()
	else:
		_restore_parallax(parallax, after)
	return _parallax_result(root, parallax)
