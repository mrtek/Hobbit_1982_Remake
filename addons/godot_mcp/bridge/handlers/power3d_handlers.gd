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

func _resolve_typed(root: Node, path_str: String, expected_class_name: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node.is_class(expected_class_name):
		return _error("INVALID_NODE_TYPE", "Node is not a %s: %s" % [expected_class_name, path_str])
	return node

func _undo_redo() -> EditorUndoRedoManager:
	return _editor_interface.get_editor_undo_redo()

func _vector2(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with x/y" % label)
	var dict: Dictionary = value
	if not dict.has("x") or not dict.has("y"):
		return _error("INVALID_ARGUMENT", "%s must contain x/y" % label)
	var x := float(dict.get("x", 0.0))
	var y := float(dict.get("y", 0.0))
	if not is_finite(x) or not is_finite(y):
		return _error("INVALID_ARGUMENT", "%s.x/y must be finite" % label)
	return Vector2(x, y)

func _vector3(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with x/y/z" % label)
	var dict: Dictionary = value
	if not dict.has("x") or not dict.has("y") or not dict.has("z"):
		return _error("INVALID_ARGUMENT", "%s must contain x/y/z" % label)
	var x := float(dict.get("x", 0.0))
	var y := float(dict.get("y", 0.0))
	var z := float(dict.get("z", 0.0))
	if not is_finite(x) or not is_finite(y) or not is_finite(z):
		return _error("INVALID_ARGUMENT", "%s.x/y/z must be finite" % label)
	return Vector3(x, y, z)

func _color(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with r/g/b/a" % label)
	var dict: Dictionary = value
	for key in ["r", "g", "b"]:
		if not dict.has(key):
			return _error("INVALID_ARGUMENT", "%s must contain r/g/b" % label)
	var r := float(dict.get("r", 0.0))
	var g := float(dict.get("g", 0.0))
	var b := float(dict.get("b", 0.0))
	var a := float(dict.get("a", 1.0))
	if not is_finite(r) or not is_finite(g) or not is_finite(b) or not is_finite(a):
		return _error("INVALID_ARGUMENT", "%s channels must be finite" % label)
	if a < 0.0 or a > 1.0:
		return _error("INVALID_ARGUMENT", "%s.a must be in [0,1]" % label)
	return Color(r, g, b, a)

func _vector2_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _vector3_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}

func _color_dict(value: Color) -> Dictionary:
	return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}

func _snapshot_vector2(value) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var dict: Dictionary = value
	return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))

func _snapshot_vector3(value, fallback := Vector3.ZERO) -> Vector3:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var dict: Dictionary = value
	return Vector3(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)), float(dict.get("z", fallback.z)))

func _snapshot_color(value) -> Color:
	if typeof(value) != TYPE_DICTIONARY:
		return Color.WHITE
	var dict: Dictionary = value
	return Color(float(dict.get("r", 1.0)), float(dict.get("g", 1.0)), float(dict.get("b", 1.0)), float(dict.get("a", 1.0)))

func _stable_scale(scale: Vector3) -> bool:
	if scale.x == 0.0 or scale.y == 0.0 or scale.z == 0.0:
		return false
	return (scale.x > 0.0 and scale.y > 0.0 and scale.z > 0.0) or (scale.x < 0.0 and scale.y < 0.0 and scale.z < 0.0)

# Node3D
func _node3d_snapshot(node: Node3D) -> Dictionary:
	return {
		"position": _vector3_dict(node.position),
		"rotation_degrees": _vector3_dict(node.rotation_degrees),
		"scale": _vector3_dict(node.scale)
	}

func _restore_node3d(node: Node3D, snapshot: Dictionary) -> void:
	node.position = _snapshot_vector3(snapshot.get("position", {}))
	node.rotation_degrees = _snapshot_vector3(snapshot.get("rotation_degrees", {}))
	node.scale = _snapshot_vector3(snapshot.get("scale", {}), Vector3.ONE)

func _node3d_result(root: Node, node: Node3D) -> Dictionary:
	return {
		"node_path": _logical_path(root, node),
		"type": node.get_class(),
		"position": _vector3_dict(node.position),
		"rotation_degrees": _vector3_dict(node.rotation_degrees),
		"scale": _vector3_dict(node.scale),
		"global_position": _vector3_dict(node.global_position),
		"global_rotation_degrees": _vector3_dict(node.global_rotation_degrees),
		"global_scale": _vector3_dict(node.global_basis.get_scale())
	}

func inspect_node3d_transform(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "Node3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _node3d_result(root, resolved as Node3D)

func set_node3d_transform(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "Node3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var node := resolved as Node3D
	if not params.has("position") and not params.has("rotation_degrees") and not params.has("scale"):
		return _error("INVALID_ARGUMENT", "At least one transform field is required")
	var before := _node3d_snapshot(node)
	var after := before.duplicate(true)
	if params.has("position"):
		var parsed_position = _vector3(params.get("position"), "position")
		if typeof(parsed_position) == TYPE_DICTIONARY:
			return parsed_position
		after["position"] = _vector3_dict(parsed_position)
	if params.has("rotation_degrees"):
		var parsed_rotation = _vector3(params.get("rotation_degrees"), "rotation_degrees")
		if typeof(parsed_rotation) == TYPE_DICTIONARY:
			return parsed_rotation
		after["rotation_degrees"] = _vector3_dict(parsed_rotation)
	if params.has("scale"):
		var parsed_scale = _vector3(params.get("scale"), "scale")
		if typeof(parsed_scale) == TYPE_DICTIONARY:
			return parsed_scale
		var scale: Vector3 = parsed_scale
		if not _stable_scale(scale):
			return _error("INVALID_ARGUMENT", "scale components must be non-zero and all have the same sign")
		after["scale"] = _vector3_dict(scale)
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set Node3D Transform", 0, node)
		undo_redo.add_do_method(self, "_restore_node3d", node, after)
		undo_redo.add_undo_method(self, "_restore_node3d", node, before)
		undo_redo.commit_action()
	else:
		_restore_node3d(node, after)
	return _node3d_result(root, node)

# MeshInstance3D
func _mesh_primitive(mesh: Mesh) -> Dictionary:
	if mesh is BoxMesh:
		return {"kind": "box", "size": _vector3_dict((mesh as BoxMesh).size)}
	if mesh is SphereMesh:
		var sphere := mesh as SphereMesh
		return {"kind": "sphere", "radius": sphere.radius, "height": sphere.height, "hemisphere": sphere.is_hemisphere}
	if mesh is CapsuleMesh:
		var capsule := mesh as CapsuleMesh
		return {"kind": "capsule", "radius": capsule.radius, "height": capsule.height}
	if mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		return {"kind": "cylinder", "top_radius": cylinder.top_radius, "bottom_radius": cylinder.bottom_radius, "height": cylinder.height}
	if mesh is PlaneMesh:
		var plane := mesh as PlaneMesh
		var orientation := "y"
		if plane.orientation == PlaneMesh.FACE_X:
			orientation = "x"
		elif plane.orientation == PlaneMesh.FACE_Z:
			orientation = "z"
		return {"kind": "plane", "size": _vector2_dict(plane.size), "orientation": orientation}
	return {"kind": "other", "type": mesh.get_class(), "resource_path": mesh.resource_path}

func _mesh_result(root: Node, mesh_instance: MeshInstance3D) -> Dictionary:
	var mesh := mesh_instance.mesh
	return {
		"node_path": _logical_path(root, mesh_instance),
		"type": mesh_instance.get_class(),
		"mesh_type": mesh.get_class() if mesh else "",
		"mesh_path": mesh.resource_path if mesh else "",
		"surface_count": mesh.get_surface_count() if mesh else 0,
		"primitive": _mesh_primitive(mesh) if mesh else {"kind": "none"},
		"material_override_type": mesh_instance.material_override.get_class() if mesh_instance.material_override else ""
	}

func inspect_mesh3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "MeshInstance3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _mesh_result(root, resolved as MeshInstance3D)

func _create_mesh_primitive(value):
	if value == null:
		return null
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "primitive must be an object or null")
	var primitive: Dictionary = value
	var kind := str(primitive.get("kind", ""))
	match kind:
		"box":
			var parsed_size = _vector3(primitive.get("size"), "primitive.size")
			if typeof(parsed_size) == TYPE_DICTIONARY:
				return parsed_size
			var size: Vector3 = parsed_size
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
				return _error("INVALID_ARGUMENT", "BoxMesh size components must be positive")
			var mesh := BoxMesh.new()
			mesh.size = size
			return mesh
		"sphere":
			var radius := float(primitive.get("radius", 0.0))
			var height := float(primitive.get("height", 0.0))
			if radius <= 0.0 or height <= 0.0:
				return _error("INVALID_ARGUMENT", "SphereMesh radius and height must be positive")
			var mesh := SphereMesh.new()
			mesh.radius = radius
			mesh.height = height
			mesh.is_hemisphere = bool(primitive.get("hemisphere", false))
			return mesh
		"capsule":
			var radius := float(primitive.get("radius", 0.0))
			var height := float(primitive.get("height", 0.0))
			if radius <= 0.0 or height < radius * 2.0:
				return _error("INVALID_ARGUMENT", "CapsuleMesh height must be at least twice its positive radius")
			var mesh := CapsuleMesh.new()
			mesh.radius = radius
			mesh.height = height
			return mesh
		"cylinder":
			var top_radius := float(primitive.get("top_radius", 0.0))
			var bottom_radius := float(primitive.get("bottom_radius", 0.0))
			var height := float(primitive.get("height", 0.0))
			if top_radius < 0.0 or bottom_radius < 0.0 or (top_radius <= 0.0 and bottom_radius <= 0.0) or height <= 0.0:
				return _error("INVALID_ARGUMENT", "CylinderMesh radii must be nonnegative with at least one positive, and height positive")
			var mesh := CylinderMesh.new()
			mesh.top_radius = top_radius
			mesh.bottom_radius = bottom_radius
			mesh.height = height
			return mesh
		"plane":
			var parsed_size = _vector2(primitive.get("size"), "primitive.size")
			if typeof(parsed_size) == TYPE_DICTIONARY:
				return parsed_size
			var size: Vector2 = parsed_size
			if size.x <= 0.0 or size.y <= 0.0:
				return _error("INVALID_ARGUMENT", "PlaneMesh size components must be positive")
			var mesh := PlaneMesh.new()
			mesh.size = size
			match str(primitive.get("orientation", "y")):
				"x": mesh.orientation = PlaneMesh.FACE_X
				"z": mesh.orientation = PlaneMesh.FACE_Z
				_: mesh.orientation = PlaneMesh.FACE_Y
			return mesh
		_:
			return _error("INVALID_ARGUMENT", "Unsupported mesh primitive kind: %s" % kind)

func set_mesh3d_primitive(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "MeshInstance3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var mesh_instance := resolved as MeshInstance3D
	var created = _create_mesh_primitive(params.get("primitive", null))
	if typeof(created) == TYPE_DICTIONARY:
		return created
	var next_mesh: Mesh = created as Mesh
	var previous := mesh_instance.mesh
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set Mesh3D Primitive", 0, mesh_instance)
		undo_redo.add_do_property(mesh_instance, "mesh", next_mesh)
		undo_redo.add_undo_property(mesh_instance, "mesh", previous)
		undo_redo.commit_action()
	else:
		mesh_instance.mesh = next_mesh
	return _mesh_result(root, mesh_instance)

# Camera3D
func _projection_name(value: int) -> String:
	match value:
		Camera3D.PROJECTION_ORTHOGONAL: return "orthogonal"
		Camera3D.PROJECTION_FRUSTUM: return "frustum"
		_: return "perspective"

func _keep_aspect_name(value: int) -> String:
	return "height" if value == Camera3D.KEEP_HEIGHT else "width"

func _camera_snapshot(camera: Camera3D) -> Dictionary:
	return {
		"projection": camera.projection,
		"fov": camera.fov,
		"size": camera.size,
		"near": camera.near,
		"far": camera.far,
		"keep_aspect": camera.keep_aspect,
		"frustum_offset": _vector2_dict(camera.frustum_offset),
		"h_offset": camera.h_offset,
		"v_offset": camera.v_offset,
		"cull_mask": camera.cull_mask
	}

func _restore_camera(camera: Camera3D, snapshot: Dictionary) -> void:
	var near_value := float(snapshot.get("near", 0.05))
	var far_value := float(snapshot.get("far", 4000.0))
	var size_value := float(snapshot.get("size", 1.0))
	var fov_value := float(snapshot.get("fov", 75.0))
	var frustum_offset := _snapshot_vector2(snapshot.get("frustum_offset", {}))
	match int(snapshot.get("projection", Camera3D.PROJECTION_PERSPECTIVE)):
		Camera3D.PROJECTION_ORTHOGONAL:
			camera.set_orthogonal(size_value, near_value, far_value)
		Camera3D.PROJECTION_FRUSTUM:
			camera.set_frustum(size_value, frustum_offset, near_value, far_value)
		_:
			camera.set_perspective(fov_value, near_value, far_value)
	camera.keep_aspect = int(snapshot.get("keep_aspect", Camera3D.KEEP_HEIGHT))
	camera.frustum_offset = frustum_offset
	camera.h_offset = float(snapshot.get("h_offset", 0.0))
	camera.v_offset = float(snapshot.get("v_offset", 0.0))
	camera.cull_mask = int(snapshot.get("cull_mask", 1048575))

func _camera_result(root: Node, camera: Camera3D) -> Dictionary:
	return {
		"node_path": _logical_path(root, camera),
		"type": camera.get_class(),
		"current": camera.current,
		"projection": _projection_name(camera.projection),
		"fov": camera.fov,
		"size": camera.size,
		"near": camera.near,
		"far": camera.far,
		"keep_aspect": _keep_aspect_name(camera.keep_aspect),
		"frustum_offset": _vector2_dict(camera.frustum_offset),
		"h_offset": camera.h_offset,
		"v_offset": camera.v_offset,
		"cull_mask": camera.cull_mask
	}

func inspect_camera3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "Camera3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _camera_result(root, resolved as Camera3D)

func configure_camera3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "Camera3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var camera := resolved as Camera3D
	var before := _camera_snapshot(camera)
	var after := before.duplicate(true)
	if params.has("projection"):
		match str(params.get("projection")):
			"orthogonal": after["projection"] = Camera3D.PROJECTION_ORTHOGONAL
			"frustum": after["projection"] = Camera3D.PROJECTION_FRUSTUM
			"perspective": after["projection"] = Camera3D.PROJECTION_PERSPECTIVE
			_: return _error("INVALID_ARGUMENT", "Unsupported Camera3D projection")
	if params.has("fov"):
		after["fov"] = float(params.get("fov"))
	if params.has("size"):
		after["size"] = float(params.get("size"))
	if params.has("near"):
		after["near"] = float(params.get("near"))
	if params.has("far"):
		after["far"] = float(params.get("far"))
	if params.has("keep_aspect"):
		after["keep_aspect"] = Camera3D.KEEP_WIDTH if str(params.get("keep_aspect")) == "width" else Camera3D.KEEP_HEIGHT
	if params.has("frustum_offset"):
		var parsed_offset = _vector2(params.get("frustum_offset"), "frustum_offset")
		if typeof(parsed_offset) == TYPE_DICTIONARY:
			return parsed_offset
		after["frustum_offset"] = _vector2_dict(parsed_offset)
	for field in ["h_offset", "v_offset"]:
		if params.has(field):
			after[field] = float(params.get(field))
	if params.has("cull_mask"):
		after["cull_mask"] = int(params.get("cull_mask"))
	var near_value := float(after.get("near", 0.05))
	var far_value := float(after.get("far", 4000.0))
	var fov_value := float(after.get("fov", 75.0))
	var size_value := float(after.get("size", 1.0))
	var mask := int(after.get("cull_mask", 1048575))
	if near_value <= 0.0 or far_value <= near_value:
		return _error("INVALID_ARGUMENT", "Camera3D requires near > 0 and far > near")
	if fov_value < 1.0 or fov_value >= 180.0 or size_value <= 0.0:
		return _error("INVALID_ARGUMENT", "Camera3D requires fov in [1,180) and size > 0")
	if mask < 0 or mask > 1048575:
		return _error("INVALID_ARGUMENT", "Camera3D cull_mask must fit 20 bits")
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Configure Camera3D", 0, camera)
		undo_redo.add_do_method(self, "_restore_camera", camera, after)
		undo_redo.add_undo_method(self, "_restore_camera", camera, before)
		undo_redo.commit_action()
	else:
		_restore_camera(camera, after)
	return _camera_result(root, camera)

# CollisionShape3D
func _shape_result(shape: Shape3D) -> Dictionary:
	if shape is BoxShape3D:
		return {"kind": "box", "resource_path": shape.resource_path, "size": _vector3_dict((shape as BoxShape3D).size)}
	if shape is SphereShape3D:
		return {"kind": "sphere", "resource_path": shape.resource_path, "radius": (shape as SphereShape3D).radius}
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return {"kind": "capsule", "resource_path": shape.resource_path, "radius": capsule.radius, "height": capsule.height}
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return {"kind": "cylinder", "resource_path": shape.resource_path, "radius": cylinder.radius, "height": cylinder.height}
	return {"kind": "other", "resource_path": shape.resource_path, "type": shape.get_class()}

func _collision_result(root: Node, collision: CollisionShape3D) -> Dictionary:
	return {
		"node_path": _logical_path(root, collision),
		"type": collision.get_class(),
		"shape": _shape_result(collision.shape) if collision.shape else {"kind": "none"},
		"disabled": collision.disabled
	}

func inspect_collision3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "CollisionShape3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _collision_result(root, resolved as CollisionShape3D)

func _create_collision_shape(value):
	if value == null:
		return null
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "shape must be an object or null")
	var shape_data: Dictionary = value
	match str(shape_data.get("kind", "")):
		"box":
			var parsed_size = _vector3(shape_data.get("size"), "shape.size")
			if typeof(parsed_size) == TYPE_DICTIONARY:
				return parsed_size
			var size: Vector3 = parsed_size
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
				return _error("INVALID_ARGUMENT", "BoxShape3D size components must be positive")
			var shape := BoxShape3D.new()
			shape.size = size
			return shape
		"sphere":
			var radius := float(shape_data.get("radius", 0.0))
			if radius <= 0.0:
				return _error("INVALID_ARGUMENT", "SphereShape3D radius must be positive")
			var shape := SphereShape3D.new()
			shape.radius = radius
			return shape
		"capsule":
			var radius := float(shape_data.get("radius", 0.0))
			var height := float(shape_data.get("height", 0.0))
			if radius <= 0.0 or height < radius * 2.0:
				return _error("INVALID_ARGUMENT", "CapsuleShape3D height must be at least twice its positive radius")
			var shape := CapsuleShape3D.new()
			shape.radius = radius
			shape.height = height
			return shape
		"cylinder":
			var radius := float(shape_data.get("radius", 0.0))
			var height := float(shape_data.get("height", 0.0))
			if radius <= 0.0 or height <= 0.0:
				return _error("INVALID_ARGUMENT", "CylinderShape3D radius and height must be positive")
			var shape := CylinderShape3D.new()
			shape.radius = radius
			shape.height = height
			return shape
		_:
			return _error("INVALID_ARGUMENT", "Unsupported CollisionShape3D kind")

func set_collision3d_shape(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "CollisionShape3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var collision := resolved as CollisionShape3D
	var created = _create_collision_shape(params.get("shape", null))
	if typeof(created) == TYPE_DICTIONARY:
		return created
	var next_shape: Shape3D = created as Shape3D
	var previous := collision.shape
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Set CollisionShape3D Shape", 0, collision)
		undo_redo.add_do_property(collision, "shape", next_shape)
		undo_redo.add_undo_property(collision, "shape", previous)
		undo_redo.commit_action()
	else:
		collision.shape = next_shape
	return _collision_result(root, collision)

# Light3D
func _light_snapshot(light: Light3D) -> Dictionary:
	var snapshot := {
		"color": _color_dict(light.light_color),
		"energy": light.light_energy,
		"indirect_energy": light.light_indirect_energy,
		"specular": light.light_specular,
		"shadow_enabled": light.shadow_enabled
	}
	if light is OmniLight3D:
		snapshot["range"] = (light as OmniLight3D).omni_range
		snapshot["attenuation"] = (light as OmniLight3D).omni_attenuation
	elif light is SpotLight3D:
		var spot := light as SpotLight3D
		snapshot["range"] = spot.spot_range
		snapshot["attenuation"] = spot.spot_attenuation
		snapshot["spot_angle"] = spot.spot_angle
		snapshot["spot_angle_attenuation"] = spot.spot_angle_attenuation
	elif light is DirectionalLight3D:
		snapshot["shadow_max_distance"] = (light as DirectionalLight3D).directional_shadow_max_distance
	return snapshot

func _restore_light(light: Light3D, snapshot: Dictionary) -> void:
	light.light_color = _snapshot_color(snapshot.get("color", {}))
	light.light_energy = float(snapshot.get("energy", 1.0))
	light.light_indirect_energy = float(snapshot.get("indirect_energy", 1.0))
	light.light_specular = float(snapshot.get("specular", 0.5))
	light.shadow_enabled = bool(snapshot.get("shadow_enabled", false))
	if light is OmniLight3D:
		var omni := light as OmniLight3D
		omni.omni_range = float(snapshot.get("range", omni.omni_range))
		omni.omni_attenuation = float(snapshot.get("attenuation", omni.omni_attenuation))
	elif light is SpotLight3D:
		var spot := light as SpotLight3D
		spot.spot_range = float(snapshot.get("range", spot.spot_range))
		spot.spot_attenuation = float(snapshot.get("attenuation", spot.spot_attenuation))
		spot.spot_angle = float(snapshot.get("spot_angle", spot.spot_angle))
		spot.spot_angle_attenuation = float(snapshot.get("spot_angle_attenuation", spot.spot_angle_attenuation))
	elif light is DirectionalLight3D:
		var directional := light as DirectionalLight3D
		directional.directional_shadow_max_distance = float(snapshot.get("shadow_max_distance", directional.directional_shadow_max_distance))

func _light_result(root: Node, light: Light3D) -> Dictionary:
	var result := {
		"node_path": _logical_path(root, light),
		"type": light.get_class(),
		"color": _color_dict(light.light_color),
		"energy": light.light_energy,
		"indirect_energy": light.light_indirect_energy,
		"specular": light.light_specular,
		"shadow_enabled": light.shadow_enabled
	}
	if light is OmniLight3D:
		result["range"] = (light as OmniLight3D).omni_range
		result["attenuation"] = (light as OmniLight3D).omni_attenuation
	elif light is SpotLight3D:
		var spot := light as SpotLight3D
		result["range"] = spot.spot_range
		result["attenuation"] = spot.spot_attenuation
		result["spot_angle"] = spot.spot_angle
		result["spot_angle_attenuation"] = spot.spot_angle_attenuation
	elif light is DirectionalLight3D:
		result["shadow_max_distance"] = (light as DirectionalLight3D).directional_shadow_max_distance
	return result

func inspect_light3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "Light3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _light_result(root, resolved as Light3D)

func configure_light3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_typed(root, str(params.get("node_path", "")), "Light3D")
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var light := resolved as Light3D
	var before := _light_snapshot(light)
	var after := before.duplicate(true)
	if params.has("color"):
		var parsed_color = _color(params.get("color"), "color")
		if typeof(parsed_color) == TYPE_DICTIONARY:
			return parsed_color
		after["color"] = _color_dict(parsed_color)
	for field in ["energy", "indirect_energy", "specular"]:
		if params.has(field):
			after[field] = float(params.get(field))
	if params.has("shadow_enabled"):
		after["shadow_enabled"] = bool(params.get("shadow_enabled"))
	var subtype_fields := ["range", "attenuation", "spot_angle", "spot_angle_attenuation", "shadow_max_distance"]
	for field in subtype_fields:
		if not params.has(field):
			continue
		if field in ["range", "attenuation"] and not (light is OmniLight3D or light is SpotLight3D):
			return _error("INVALID_ARGUMENT", "%s is only valid for OmniLight3D or SpotLight3D" % field)
		if field in ["spot_angle", "spot_angle_attenuation"] and not light is SpotLight3D:
			return _error("INVALID_ARGUMENT", "%s is only valid for SpotLight3D" % field)
		if field == "shadow_max_distance" and not light is DirectionalLight3D:
			return _error("INVALID_ARGUMENT", "shadow_max_distance is only valid for DirectionalLight3D")
		after[field] = float(params.get(field))
	var energy := float(after.get("energy", 0.0))
	var indirect := float(after.get("indirect_energy", 0.0))
	var specular := float(after.get("specular", 0.0))
	if energy < 0.0 or indirect < 0.0 or specular < 0.0 or specular > 1.0:
		return _error("INVALID_ARGUMENT", "Light energy values must be nonnegative and specular in [0,1]")
	if after.has("range") and float(after.range) <= 0.0:
		return _error("INVALID_ARGUMENT", "Light range must be positive")
	if after.has("attenuation") and (float(after.attenuation) < 0.0 or float(after.attenuation) > 10.0):
		return _error("INVALID_ARGUMENT", "Light attenuation must be in [0,10]")
	if after.has("spot_angle") and (float(after.spot_angle) <= 0.0 or float(after.spot_angle) > 90.0):
		return _error("INVALID_ARGUMENT", "Spot angle must be in (0,90]")
	if after.has("spot_angle_attenuation") and (float(after.spot_angle_attenuation) < 0.0 or float(after.spot_angle_attenuation) > 10.0):
		return _error("INVALID_ARGUMENT", "Spot angle attenuation must be in [0,10]")
	if after.has("shadow_max_distance") and float(after.shadow_max_distance) <= 0.0:
		return _error("INVALID_ARGUMENT", "Directional shadow max distance must be positive")
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Configure Light3D", 0, light)
		undo_redo.add_do_method(self, "_restore_light", light, after)
		undo_redo.add_undo_method(self, "_restore_light", light, before)
		undo_redo.commit_action()
	else:
		_restore_light(light, after)
	return _light_result(root, light)
