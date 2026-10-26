@tool
extends RefCounted

const KEEP_Y_CAPABILITY := "navigation.agent3d.keep_y_velocity"
const KEEP_Y_QUIRK := "navigation.agent3d.keep_y_velocity.hidden_with_3d_avoidance"

var _editor_interface
var _compatibility

func _init(editor_interface, compatibility) -> void:
	_editor_interface = editor_interface
	_compatibility = compatibility

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

func _resolve_region(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not (node is NavigationRegion2D) and not (node is NavigationRegion3D):
		return _error("NAVIGATION_TYPE_MISMATCH", "Node is not a NavigationRegion2D/3D: %s" % path_str)
	return node

func _resolve_agent(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not (node is NavigationAgent2D) and not (node is NavigationAgent3D):
		return _error("NAVIGATION_TYPE_MISMATCH", "Node is not a NavigationAgent2D/3D: %s" % path_str)
	return node

func _undo_redo() -> EditorUndoRedoManager:
	return _editor_interface.get_editor_undo_redo()

func _vector2_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _vector3_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}

func _resource_for_region(region: Node):
	if region is NavigationRegion2D:
		return (region as NavigationRegion2D).navigation_polygon
	return (region as NavigationRegion3D).navigation_mesh

func _resource_property(region: Node) -> String:
	return "navigation_polygon" if region is NavigationRegion2D else "navigation_mesh"

func _dimension(region_or_agent: Node) -> String:
	return "2d" if (region_or_agent is NavigationRegion2D or region_or_agent is NavigationAgent2D) else "3d"

func _commit_resource_change(action_name: String, target_node: Node, property_name: String, previous_resource, new_resource) -> void:
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action(action_name, 0, target_node)
		undo_redo.add_do_property(target_node, property_name, new_resource)
		undo_redo.add_undo_property(target_node, property_name, previous_resource)
		undo_redo.commit_action()
	else:
		target_node.set(property_name, new_resource)

func _region_snapshot(region) -> Dictionary:
	return {
		"enabled": region.enabled,
		"navigation_layers": region.navigation_layers,
		"enter_cost": region.enter_cost,
		"travel_cost": region.travel_cost,
		"use_edge_connections": region.use_edge_connections
	}

func _restore_region(region, state: Dictionary) -> void:
	region.enabled = bool(state.get("enabled", true))
	region.navigation_layers = int(state.get("navigation_layers", 1))
	region.enter_cost = float(state.get("enter_cost", 0.0))
	region.travel_cost = float(state.get("travel_cost", 1.0))
	region.use_edge_connections = bool(state.get("use_edge_connections", true))

func _commit_region_change(action_name: String, target_node: Node, before: Dictionary, after: Dictionary) -> void:
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action(action_name, 0, target_node)
		undo_redo.add_do_method(self, "_restore_region", target_node, after)
		undo_redo.add_undo_method(self, "_restore_region", target_node, before)
		undo_redo.commit_action()
	else:
		_restore_region(target_node, after)

func _region_result(root: Node, region) -> Dictionary:
	var resource = _resource_for_region(region)
	var summary = null
	if resource:
		summary = {
			"type": resource.get_class(),
			"resource_path": resource.resource_path,
			"polygon_count": resource.get_polygon_count(),
			"vertex_count": resource.get_vertices().size()
		}
	return {
		"node_path": _logical_path(root, region),
		"type": region.get_class(),
		"dimension": _dimension(region),
		"enabled": region.enabled,
		"navigation_layers": region.navigation_layers,
		"enter_cost": region.enter_cost,
		"travel_cost": region.travel_cost,
		"use_edge_connections": region.use_edge_connections,
		"resource": summary
	}

func inspect_region(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_region(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _region_result(root, resolved)

func configure_region(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_region(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var region = resolved
	var before := _region_snapshot(region)
	var after := before.duplicate(true)
	for key in ["enabled", "navigation_layers", "enter_cost", "travel_cost", "use_edge_connections"]:
		if params.has(key):
			after[key] = params[key]
	if float(after.enter_cost) < 0.0 or float(after.travel_cost) <= 0.0:
		return _error("INVALID_ARGUMENT", "Navigation region enter_cost must be nonnegative and travel_cost must be positive")
	_commit_region_change("Configure Navigation Region", region, before, after)
	return _region_result(root, region)

func _parsed_geometry_name(value: int) -> String:
	match value:
		0: return "mesh_instances"
		1: return "static_colliders"
		_: return "both"

func _parsed_geometry_value(value: String) -> int:
	match value:
		"mesh_instances": return 0
		"static_colliders": return 1
		_: return 2

func _source_mode_name(value: int) -> String:
	match value:
		0: return "root_children"
		1: return "groups_with_children"
		_: return "groups_explicit"

func _source_mode_value(value: String) -> int:
	match value:
		"root_children": return 0
		"groups_with_children": return 1
		_: return 2

func _mesh_result(root: Node, region: Node) -> Dictionary:
	var resource = _resource_for_region(region)
	var base := {
		"node_path": _logical_path(root, region),
		"type": region.get_class(),
		"dimension": _dimension(region),
		"resource": null,
		"vertex_count": 0,
		"polygon_count": 0
	}
	if not resource:
		return base
	base.resource = {"type": resource.get_class(), "resource_path": resource.resource_path}
	base.vertex_count = resource.get_vertices().size()
	base.polygon_count = resource.get_polygon_count()
	if resource is NavigationPolygon:
		var polygon := resource as NavigationPolygon
		var outlines: Array = []
		var total := 0
		for i in range(min(polygon.get_outline_count(), 64)):
			var packed := polygon.get_outline(i)
			var encoded: Array = []
			for point in packed:
				if total >= 8192:
					break
				encoded.append(_vector2_dict(point))
				total += 1
			outlines.append(encoded)
			if total >= 8192:
				break
		base.outline_count = polygon.get_outline_count()
		base.outlines = outlines
		base.agent_radius = polygon.agent_radius
		base.cell_size = polygon.cell_size
		base.border_size = polygon.border_size
		base.parsed_collision_mask = polygon.parsed_collision_mask
		base.parsed_geometry_type = _parsed_geometry_name(polygon.parsed_geometry_type)
		base.source_geometry_mode = _source_mode_name(polygon.source_geometry_mode)
		base.source_group_name = str(polygon.source_geometry_group_name)
		base.sample_partition_type = "triangulate" if polygon.sample_partition_type == NavigationPolygon.SAMPLE_PARTITION_TRIANGULATE else "convex"
	else:
		var mesh := resource as NavigationMesh
		base.agent_height = mesh.agent_height
		base.agent_radius = mesh.agent_radius
		base.agent_max_climb = mesh.agent_max_climb
		base.agent_max_slope = mesh.agent_max_slope
		base.cell_size = mesh.cell_size
		base.cell_height = mesh.cell_height
		base.border_size = mesh.border_size
		base.collision_mask = mesh.geometry_collision_mask
		base.parsed_geometry_type = _parsed_geometry_name(mesh.geometry_parsed_geometry_type)
		base.source_geometry_mode = _source_mode_name(mesh.geometry_source_geometry_mode)
		base.source_group_name = str(mesh.geometry_source_group_name)
		match mesh.sample_partition_type:
			NavigationMesh.SAMPLE_PARTITION_MONOTONE: base.sample_partition_type = "monotone"
			NavigationMesh.SAMPLE_PARTITION_LAYERS: base.sample_partition_type = "layers"
			_: base.sample_partition_type = "watershed"
		base.region_min_size = mesh.region_min_size
		base.region_merge_size = mesh.region_merge_size
		base.vertices_per_polygon = mesh.vertices_per_polygon
	return base

func inspect_mesh(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_region(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _mesh_result(root, resolved)

func set_mesh(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_region(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var region = resolved
	var previous = _resource_for_region(region)
	var fresh = NavigationPolygon.new() if region is NavigationRegion2D else NavigationMesh.new()
	_commit_resource_change("Set Navigation Mesh", region, _resource_property(region), previous, fresh)
	return _mesh_result(root, region)

func _require_resource(region: Node):
	var resource = _resource_for_region(region)
	if not resource:
		return _error("NAVIGATION_RESOURCE_MISSING", "Navigation region has no navigation resource")
	return resource

func configure_mesh(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_region(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var region = resolved
	var current = _require_resource(region)
	if typeof(current) == TYPE_DICTIONARY:
		return current
	var copy = current.duplicate(true)
	if region is NavigationRegion2D:
		for forbidden in ["agent_height", "agent_max_climb", "agent_max_slope", "cell_height", "collision_mask", "region_min_size", "region_merge_size", "vertices_per_polygon"]:
			if params.has(forbidden):
				return _error("NAVIGATION_DIMENSION_MISMATCH", "%s is only supported for 3D navigation meshes" % forbidden)
		if params.has("sample_partition_type") and str(params.sample_partition_type) not in ["convex", "triangulate"]:
			return _error("NAVIGATION_DIMENSION_MISMATCH", "2D sample_partition_type must be convex or triangulate")
		var polygon := copy as NavigationPolygon
		if params.has("agent_radius"): polygon.agent_radius = float(params.agent_radius)
		if params.has("cell_size"): polygon.cell_size = float(params.cell_size)
		if params.has("border_size"): polygon.border_size = float(params.border_size)
		if params.has("parsed_collision_mask"): polygon.parsed_collision_mask = int(params.parsed_collision_mask)
		if params.has("parsed_geometry_type"): polygon.parsed_geometry_type = _parsed_geometry_value(str(params.parsed_geometry_type))
		if params.has("source_geometry_mode"): polygon.source_geometry_mode = _source_mode_value(str(params.source_geometry_mode))
		if params.has("source_group_name"): polygon.source_geometry_group_name = StringName(str(params.source_group_name))
		if params.has("sample_partition_type"):
			polygon.sample_partition_type = NavigationPolygon.SAMPLE_PARTITION_TRIANGULATE if str(params.sample_partition_type) == "triangulate" else NavigationPolygon.SAMPLE_PARTITION_CONVEX_PARTITION
	else:
		if params.has("parsed_collision_mask"):
			return _error("NAVIGATION_DIMENSION_MISMATCH", "parsed_collision_mask is only supported for 2D navigation polygons")
		if params.has("sample_partition_type") and str(params.sample_partition_type) not in ["watershed", "monotone", "layers"]:
			return _error("NAVIGATION_DIMENSION_MISMATCH", "3D sample_partition_type must be watershed, monotone, or layers")
		var mesh := copy as NavigationMesh
		if params.has("agent_height"): mesh.agent_height = float(params.agent_height)
		if params.has("agent_radius"): mesh.agent_radius = float(params.agent_radius)
		if params.has("agent_max_climb"): mesh.agent_max_climb = float(params.agent_max_climb)
		if params.has("agent_max_slope"): mesh.agent_max_slope = float(params.agent_max_slope)
		if params.has("cell_size"): mesh.cell_size = float(params.cell_size)
		if params.has("cell_height"): mesh.cell_height = float(params.cell_height)
		if params.has("border_size"): mesh.border_size = float(params.border_size)
		if params.has("collision_mask"): mesh.geometry_collision_mask = int(params.collision_mask)
		if params.has("parsed_geometry_type"): mesh.geometry_parsed_geometry_type = _parsed_geometry_value(str(params.parsed_geometry_type))
		if params.has("source_geometry_mode"): mesh.geometry_source_geometry_mode = _source_mode_value(str(params.source_geometry_mode))
		if params.has("source_group_name"): mesh.geometry_source_group_name = StringName(str(params.source_group_name))
		if params.has("sample_partition_type"):
			match str(params.sample_partition_type):
				"monotone": mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_MONOTONE
				"layers": mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_LAYERS
				_: mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_WATERSHED
		if params.has("region_min_size"): mesh.region_min_size = float(params.region_min_size)
		if params.has("region_merge_size"): mesh.region_merge_size = float(params.region_merge_size)
		if params.has("vertices_per_polygon"): mesh.vertices_per_polygon = float(params.vertices_per_polygon)
	_commit_resource_change("Configure Navigation Mesh", region, _resource_property(region), current, copy)
	return _mesh_result(root, region)

func set_outlines(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_region(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var region = resolved
	if region is NavigationRegion3D:
		return _error("NAVIGATION_OUTLINES_UNSUPPORTED", "Navigation outlines are only supported for NavigationRegion2D")
	var current = _require_resource(region)
	if typeof(current) == TYPE_DICTIONARY:
		return current
	var raw = params.get("outlines", [])
	if typeof(raw) != TYPE_ARRAY or raw.size() > 64:
		return _error("INVALID_ARGUMENT", "outlines must be an array with at most 64 entries")
	var parsed: Array = []
	var total := 0
	for outline_value in raw:
		if typeof(outline_value) != TYPE_ARRAY or outline_value.size() < 3 or outline_value.size() > 4096:
			return _error("INVALID_ARGUMENT", "each navigation outline must contain 3..4096 points")
		var packed := PackedVector2Array()
		for point_value in outline_value:
			if typeof(point_value) != TYPE_DICTIONARY or not point_value.has("x") or not point_value.has("y"):
				return _error("INVALID_ARGUMENT", "outline points must contain finite x/y")
			var x := float(point_value.x)
			var y := float(point_value.y)
			if not is_finite(x) or not is_finite(y):
				return _error("INVALID_ARGUMENT", "outline points must contain finite x/y")
			packed.append(Vector2(x, y))
			total += 1
			if total > 8192:
				return _error("INVALID_ARGUMENT", "navigation outlines may contain at most 8192 points total")
		parsed.append(packed)
	var copy := (current as NavigationPolygon).duplicate(true) as NavigationPolygon
	copy.clear()
	copy.clear_outlines()
	for packed_outline in parsed:
		copy.add_outline(packed_outline)
	_commit_resource_change("Set Navigation Outlines", region, "navigation_polygon", current, copy)
	return _mesh_result(root, region)

func clear_mesh(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_region(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var region = resolved
	var current = _require_resource(region)
	if typeof(current) == TYPE_DICTIONARY:
		return current
	var copy = current.duplicate(true)
	copy.clear()
	_commit_resource_change("Clear Navigation Mesh", region, _resource_property(region), current, copy)
	return _mesh_result(root, region)

func bake_mesh(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_region(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var region = resolved
	var current = _require_resource(region)
	if typeof(current) == TYPE_DICTIONARY:
		return current
	var source_root := _resolve_node(root, str(params.get("source_root_path", "")))
	if not source_root:
		return _error("NAVIGATION_SOURCE_ROOT_NOT_FOUND", "Navigation bake source root was not found")
	if region is NavigationRegion2D:
		var copy2d := (current as NavigationPolygon).duplicate(true) as NavigationPolygon
		if copy2d.get_outline_count() <= 0:
			return _error("NAVIGATION_BAKE_FAILED", "NavigationPolygon needs at least one outline before baking")
		copy2d.clear()
		var data2d := NavigationMeshSourceGeometryData2D.new()
		NavigationServer2D.parse_source_geometry_data(copy2d, data2d, source_root)
		NavigationServer2D.bake_from_source_geometry_data(copy2d, data2d)
		if copy2d.get_polygon_count() <= 0:
			return _error("NAVIGATION_BAKE_FAILED", "2D navigation bake produced no polygons")
		_commit_resource_change("Bake Navigation Mesh", region, "navigation_polygon", current, copy2d)
	else:
		var copy3d := (current as NavigationMesh).duplicate(true) as NavigationMesh
		copy3d.clear()
		var data3d := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(copy3d, data3d, source_root)
		NavigationServer3D.bake_from_source_geometry_data(copy3d, data3d)
		if copy3d.get_polygon_count() <= 0:
			return _error("NAVIGATION_BAKE_FAILED", "3D navigation bake produced no polygons")
		_commit_resource_change("Bake Navigation Mesh", region, "navigation_mesh", current, copy3d)
	return _mesh_result(root, region)

func _agent_snapshot(agent) -> Dictionary:
	var state := {
		"navigation_layers": agent.navigation_layers,
		"path_desired_distance": agent.path_desired_distance,
		"target_desired_distance": agent.target_desired_distance,
		"path_max_distance": agent.path_max_distance,
		"radius": agent.radius,
		"neighbor_distance": agent.neighbor_distance,
		"max_neighbors": agent.max_neighbors,
		"max_speed": agent.max_speed,
		"avoidance_enabled": agent.avoidance_enabled,
		"avoidance_layers": agent.avoidance_layers,
		"avoidance_mask": agent.avoidance_mask,
		"avoidance_priority": agent.avoidance_priority,
		"time_horizon_agents": agent.time_horizon_agents,
		"time_horizon_obstacles": agent.time_horizon_obstacles,
		"simplify_path": agent.simplify_path,
		"simplify_epsilon": agent.simplify_epsilon
	}
	if agent is NavigationAgent3D:
		state.height = agent.height
		state.use_3d_avoidance = agent.use_3d_avoidance
		if _compatibility.status(KEEP_Y_CAPABILITY) != "unsupported":
			state.keep_y_velocity = agent.keep_y_velocity
		state.path_height_offset = agent.path_height_offset
	return state

func _restore_agent(agent, state: Dictionary) -> void:
	for key in ["navigation_layers", "path_desired_distance", "target_desired_distance", "path_max_distance", "radius", "neighbor_distance", "max_neighbors", "max_speed", "avoidance_enabled", "avoidance_layers", "avoidance_mask", "avoidance_priority", "time_horizon_agents", "time_horizon_obstacles", "simplify_path", "simplify_epsilon"]:
		if state.has(key):
			agent.set(key, state[key])
	if agent is NavigationAgent3D:
		for key in ["height", "use_3d_avoidance", "keep_y_velocity", "path_height_offset"]:
			if state.has(key):
				agent.set(key, state[key])

func _commit_agent_change(action_name: String, target_node: Node, before: Dictionary, after: Dictionary) -> void:
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action(action_name, 0, target_node)
		undo_redo.add_do_method(self, "_restore_agent", target_node, after)
		undo_redo.add_undo_method(self, "_restore_agent", target_node, before)
		undo_redo.commit_action()
	else:
		_restore_agent(target_node, after)

func _agent_result(root: Node, agent) -> Dictionary:
	var result := _agent_snapshot(agent)
	if agent is NavigationAgent3D and (_compatibility.status(KEEP_Y_CAPABILITY) == "unsupported" or (agent.use_3d_avoidance and _compatibility.quirk_active(KEEP_Y_QUIRK))):
		result.erase("keep_y_velocity")
	result.node_path = _logical_path(root, agent)
	result.type = agent.get_class()
	result.dimension = _dimension(agent)
	if agent is NavigationAgent2D:
		result.target_position = _vector2_dict(agent.target_position)
		result.velocity = _vector2_dict(agent.velocity)
	else:
		result.target_position = _vector3_dict(agent.target_position)
		result.velocity = _vector3_dict(agent.velocity)
	return result

func inspect_agent(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_agent(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	return _agent_result(root, resolved)

func configure_agent(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_agent(root, str(params.get("node_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var agent = resolved
	if agent is NavigationAgent2D:
		for field in ["height", "use_3d_avoidance", "keep_y_velocity", "path_height_offset"]:
			if params.has(field):
				return _error("NAVIGATION_DIMENSION_MISMATCH", "%s is only supported for NavigationAgent3D" % field)
	var effective_use_3d_avoidance := false
	if agent is NavigationAgent3D:
		effective_use_3d_avoidance = bool(params.get("use_3d_avoidance", agent.use_3d_avoidance))
		if params.has("keep_y_velocity") and _compatibility.status(KEEP_Y_CAPABILITY) == "unsupported":
			return _error("CAPABILITY_UNAVAILABLE", _compatibility.reason(KEEP_Y_CAPABILITY))
		if effective_use_3d_avoidance and params.has("keep_y_velocity") and _compatibility.quirk_active(KEEP_Y_QUIRK):
			return _error("INVALID_ARGUMENT", "keep_y_velocity is unavailable when use_3d_avoidance is true because this Godot build does not persist it in that mode")
	var before := _agent_snapshot(agent)
	var after := before.duplicate(true)
	for key in before.keys():
		if params.has(key):
			after[key] = params[key]
	if agent is NavigationAgent3D:
		for key in ["height", "use_3d_avoidance", "keep_y_velocity", "path_height_offset"]:
			if params.has(key):
				after[key] = params[key]
		if effective_use_3d_avoidance and _compatibility.quirk_active(KEEP_Y_QUIRK):
			after.keep_y_velocity = true
	_commit_agent_change("Configure Navigation Agent", agent, before, after)
	return _agent_result(root, agent)
