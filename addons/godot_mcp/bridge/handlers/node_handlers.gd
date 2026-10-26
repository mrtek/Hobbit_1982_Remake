@tool
extends RefCounted

var _editor_interface
var _variant_serializer = preload("res://addons/godot_mcp/serialization/variant_serializer.gd")
const PropertyValue = preload("res://addons/godot_mcp/serialization/property_value.gd")

func _init(editor_interface) -> void:
	_editor_interface = editor_interface

func _error(code: String, message: String) -> Dictionary:
	return {
		"__error": {
			"code": code,
			"message": message
		}
	}

func _get_logical_path(scene_root: Node, node: Node) -> String:
	var relative := scene_root.get_path_to(node)
	var logical_path := "/%s" % scene_root.name
	if relative != NodePath("."):
		logical_path += "/%s" % str(relative)
	return logical_path

func _resolve_node(scene_root: Node, path_str: String) -> Node:
	if path_str.is_empty() or path_str == "." or path_str == "/%s" % scene_root.name:
		return scene_root
	var target := scene_root.get_node_or_null(path_str)
	if target:
		return target
	if path_str.begins_with("/%s/" % scene_root.name):
		var rel := path_str.substr(len(scene_root.name) + 2)
		return scene_root.get_node_or_null(rel)
	if path_str.begins_with("/"):
		var rel := path_str.substr(1)
		return scene_root.get_node_or_null(rel)
	return null

func create(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var parent_path: String = params.get("parent_path", "")
	var parent: Node = _resolve_node(root, parent_path)
	if not parent:
		return _error("NODE_NOT_FOUND", "Parent node not found: %s" % parent_path)

	var type_str: String = params.get("type", "")
	if type_str.is_empty():
		return _error("INVALID_ARGUMENT", "type is required")
	if not ClassDB.class_exists(type_str):
		return _error("INVALID_ARGUMENT", "Class does not exist: %s" % type_str)
	if not ClassDB.is_parent_class(type_str, "Node") and type_str != "Node":
		return _error("INVALID_ARGUMENT", "Class is not a Node: %s" % type_str)
	if not ClassDB.can_instantiate(type_str):
		return _error("INVALID_ARGUMENT", "Cannot instantiate class: %s" % type_str)

	var node: Node = ClassDB.instantiate(type_str)
	var name_str: String = params.get("name", "")
	if not name_str.is_empty():
		node.name = name_str

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Create Node: " + node.name)
		undo_redo.add_do_method(parent, "add_child", node)
		undo_redo.add_do_property(node, "owner", root)
		undo_redo.add_do_reference(node)
		undo_redo.add_undo_method(parent, "remove_child", node)
		undo_redo.commit_action()
	else:
		parent.add_child(node)
		node.owner = root

	return {
		"name": node.name,
		"type": node.get_class(),
		"path": _get_logical_path(root, node)
	}

func delete(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error("INVALID_ARGUMENT", "node_path is required")

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)
	if node == root:
		return _error("OPERATION_NOT_ALLOWED", "Cannot delete root node of the active scene")

	var parent = node.get_parent()
	var node_owner = node.owner
	var node_index = node.get_index()
	var path_str = _get_logical_path(root, node)

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Delete Node: " + node.name)
		undo_redo.add_do_method(parent, "remove_child", node)
		undo_redo.add_undo_method(parent, "add_child", node)
		undo_redo.add_undo_method(parent, "move_child", node, node_index)
		undo_redo.add_undo_property(node, "owner", node_owner)
		undo_redo.add_undo_reference(node)
		undo_redo.commit_action()
	else:
		parent.remove_child(node)
		node.queue_free()

	return {
		"path": path_str,
		"deleted": true
	}

func duplicate(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error("INVALID_ARGUMENT", "node_path is required")

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)
	if node == root:
		return _error("OPERATION_NOT_ALLOWED", "Cannot duplicate root node directly into current scene")

	var copy: Node = node.duplicate()
	var new_name: String = params.get("new_name", "")
	if not new_name.is_empty():
		copy.name = new_name

	var parent = node.get_parent()
	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Duplicate Node: " + node.name)
		undo_redo.add_do_method(parent, "add_child", copy)
		undo_redo.add_do_property(copy, "owner", root)
		undo_redo.add_do_reference(copy)
		undo_redo.add_undo_method(parent, "remove_child", copy)
		undo_redo.commit_action()
	else:
		parent.add_child(copy)
		copy.owner = root

	return {
		"name": copy.name,
		"type": copy.get_class(),
		"path": _get_logical_path(root, copy)
	}

func rename(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error("INVALID_ARGUMENT", "node_path is required")

	var new_name: String = params.get("new_name", "")
	if new_name.is_empty():
		return _error("INVALID_ARGUMENT", "new_name is required")

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	var old_path = _get_logical_path(root, node)
	var old_name = node.name

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Rename Node: " + old_name)
		undo_redo.add_do_property(node, "name", new_name)
		undo_redo.add_undo_property(node, "name", old_name)
		undo_redo.commit_action()
	else:
		node.name = new_name

	var new_path = _get_logical_path(root, node)
	return {
		"old_path": old_path,
		"new_path": new_path,
		"name": str(node.name)
	}

func reparent(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error("INVALID_ARGUMENT", "node_path is required")

	var new_parent_path: String = params.get("new_parent_path", "")
	if new_parent_path.is_empty():
		return _error("INVALID_ARGUMENT", "new_parent_path is required")

	var keep_global: bool = params.get("keep_global_transform", true)

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)
	if node == root:
		return _error("OPERATION_NOT_ALLOWED", "Cannot reparent scene root node")

	var new_parent: Node = _resolve_node(root, new_parent_path)
	if not new_parent:
		return _error("NODE_NOT_FOUND", "New parent not found: %s" % new_parent_path)
	if node == new_parent or node.is_ancestor_of(new_parent):
		return _error("INVALID_OPERATION", "Cannot reparent node to itself or its own descendant")

	var old_path = _get_logical_path(root, node)
	var old_parent = node.get_parent()
	var old_index = node.get_index()

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Reparent Node: " + node.name)
		undo_redo.add_do_method(node, "reparent", new_parent, keep_global)
		undo_redo.add_undo_method(node, "reparent", old_parent, keep_global)
		undo_redo.add_undo_method(old_parent, "move_child", node, old_index)
		undo_redo.commit_action()
	else:
		node.reparent(new_parent, keep_global)

	var new_path = _get_logical_path(root, node)
	return {
		"old_path": old_path,
		"new_path": new_path
	}

func move(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error("INVALID_ARGUMENT", "node_path is required")

	var index: int = int(params.get("index", 0))

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)
	if node == root:
		return _error("OPERATION_NOT_ALLOWED", "Cannot move scene root node")

	var parent = node.get_parent()
	var old_index = node.get_index()

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Move Node: " + node.name)
		undo_redo.add_do_method(parent, "move_child", node, index)
		undo_redo.add_undo_method(parent, "move_child", node, old_index)
		undo_redo.commit_action()
	else:
		parent.move_child(node, index)

	return {
		"path": _get_logical_path(root, node),
		"index": node.get_index()
	}

func inspect(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	var script_path = null
	var script = node.get_script()
	if script is Script and not script.resource_path.is_empty():
		script_path = script.resource_path

	var groups: Array = []
	for g in node.get_groups():
		if not str(g).begins_with("_"):
			groups.append(str(g))

	var props: Dictionary = {}
	for p in node.get_property_list():
		var pname = p["name"]
		var usage = p["usage"]
		if usage & PROPERTY_USAGE_EDITOR or usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props[pname] = _variant_serializer.encode(node.get(pname))

	return {
		"name": node.name,
		"type": node.get_class(),
		"path": _get_logical_path(root, node),
		"scene_file_path": node.scene_file_path if not node.scene_file_path.is_empty() else null,
		"script": script_path,
		"groups": groups,
		"children_count": node.get_child_count(),
		"properties": props
	}

func list_children(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	var children: Array = []
	for c in node.get_children():
		children.append({
			"name": c.name,
			"type": c.get_class(),
			"path": _get_logical_path(root, c)
		})

	return {
		"node_path": _get_logical_path(root, node),
		"children": children
	}

func get_property(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	var prop: String = params.get("property", "")
	if prop.is_empty():
		return _error("INVALID_ARGUMENT", "property is required")

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	return {
		"property": prop,
		"value": _variant_serializer.encode(node.get(prop))
	}

func set_property(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	var prop: String = params.get("property", "")
	if prop.is_empty():
		return _error("INVALID_ARGUMENT", "property is required")

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	if not params.has("value"):
		return _error("INVALID_ARGUMENT", "value is required; send null explicitly to clear a nullable property")
	var prepared := PropertyValue.prepare(node,prop,params.value)
	if prepared.has("__error"): return prepared
	var prev = node.get(prop)
	var decoded = prepared.value

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Set " + prop + " on " + node.name)
		undo_redo.add_do_property(node, prop, decoded)
		undo_redo.add_undo_property(node, prop, prev)
		undo_redo.commit_action()
	else:
		node.set(prop, decoded)

	return {
		"property": prop,
		"previous_value": _variant_serializer.encode(prev),
		"new_value": _variant_serializer.encode(node.get(prop)),
		"expected_type": prepared.expectedType,
		"matches_requested": PropertyValue.equal(decoded,node.get(prop)),
		"applied":true,"saved":false
	}

func get_properties(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	var requested = params.get("properties", [])
	var props: Dictionary = {}
	if typeof(requested) == TYPE_ARRAY and requested.size() > 0:
		for p in requested:
			props[str(p)] = _variant_serializer.encode(node.get(str(p)))
	else:
		for p in node.get_property_list():
			var pname = p["name"]
			var usage = p["usage"]
			if usage & PROPERTY_USAGE_EDITOR or usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				props[pname] = _variant_serializer.encode(node.get(pname))

	return {
		"properties": props
	}
