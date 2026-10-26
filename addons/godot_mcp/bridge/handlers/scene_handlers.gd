@tool
extends RefCounted

var _editor_interface

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
	var root_type: String = params.get("root_type", "Node2D")
	if not ClassDB.class_exists(root_type):
		return _error("INVALID_ARGUMENT", "Class does not exist: %s" % root_type)
	if not ClassDB.is_parent_class(root_type, "Node") and root_type != "Node":
		return _error("INVALID_ARGUMENT", "Class is not a Node: %s" % root_type)
	if not ClassDB.can_instantiate(root_type):
		return _error("INVALID_ARGUMENT", "Cannot instantiate class: %s" % root_type)

	var root = ClassDB.instantiate(root_type)
	var root_name: String = params.get("root_name", "")
	if root_name.is_empty():
		root_name = root_type
	root.name = root_name

	var path: String = params.get("path", "")
	if path.is_empty():
		path = "res://%s.tscn" % root_name.to_snake_case()

	var dir = path.get_base_dir()
	if not dir.is_empty() and dir != "res://":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var packed = PackedScene.new()
	var pack_err = packed.pack(root)
	if pack_err != OK:
		root.free()
		return _error("PACK_FAILED", "Failed to pack scene (code %d)" % pack_err)

	var save_err = ResourceSaver.save(packed, path)
	root.free()
	if save_err != OK:
		return _error("SAVE_FAILED", "Failed to save scene to %s (code %d)" % [path, save_err])

	_editor_interface.open_scene_from_path(path)
	return {
		"path": path,
		"root_name": root_name,
		"root_type": root_type
	}

func open(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "path is required")
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return _error("NOT_FOUND", "Scene file does not exist: %s" % path)

	_editor_interface.open_scene_from_path(path)
	var root: Node = _editor_interface.get_edited_scene_root()
	return {
		"path": path,
		"root_name": root.name if root else "",
		"root_type": root.get_class() if root else ""
	}

func save(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if not path.is_empty():
		_editor_interface.save_scene_as(path)
		return { "path": path, "saved": true }

	var err = _editor_interface.save_scene()
	if err != OK:
		return _error("SAVE_FAILED", "Failed to save scene (code %d)" % err)
	var root: Node = _editor_interface.get_edited_scene_root()
	var current_path: String = root.scene_file_path if root else ""
	return { "path": current_path, "saved": true }

func save_as(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "path is required")
	_editor_interface.save_scene_as(path)
	return { "path": path, "saved": true }

func reload(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		var root = _editor_interface.get_edited_scene_root()
		if root and not root.scene_file_path.is_empty():
			path = root.scene_file_path
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "No scene open or path specified to reload")

	_editor_interface.reload_scene_from_path(path)
	return { "path": path, "reloaded": true }

func instantiate(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "path is required")
	if not ResourceLoader.exists(path):
		return _error("NOT_FOUND", "Scene file not found: %s" % path)

	var packed: PackedScene = load(path) as PackedScene
	if not packed:
		return _error("LOAD_FAILED", "Resource at path is not a PackedScene: %s" % path)

	var inst: Node = packed.instantiate()
	if not inst:
		return _error("INSTANTIATE_FAILED", "Failed to instantiate scene: %s" % path)

	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		inst.free()
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var parent_path: String = params.get("parent_path", "")
	var parent: Node = _resolve_node(root, parent_path)
	if not parent:
		inst.free()
		return _error("NODE_NOT_FOUND", "Parent node not found: %s" % parent_path)

	var node_name: String = params.get("name", "")
	if not node_name.is_empty():
		inst.name = node_name

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Instantiate Scene: " + path)
		undo_redo.add_do_method(parent, "add_child", inst)
		undo_redo.add_do_property(inst, "owner", root)
		undo_redo.add_do_reference(inst)
		undo_redo.add_undo_method(parent, "remove_child", inst)
		undo_redo.commit_action()
	else:
		parent.add_child(inst)
		inst.owner = root

	return {
		"name": inst.name,
		"type": inst.get_class(),
		"path": _get_logical_path(root, inst),
		"scene_file_path": path
	}

func get_root(_params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	return {
		"name": root.name,
		"type": root.get_class(),
		"path": "/%s" % root.name,
		"scene_file_path": root.scene_file_path if not root.scene_file_path.is_empty() else null
	}
