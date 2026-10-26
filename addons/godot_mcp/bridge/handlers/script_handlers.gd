@tool
extends RefCounted

var _editor_interface
const NativeDiagnostics = preload("res://addons/godot_mcp/serialization/native_diagnostics.gd")

func _init(editor_interface) -> void:
	_editor_interface = editor_interface

func _error(code: String, message: String) -> Dictionary:
	return {
		"__error": {
			"code": code,
			"message": message
		}
	}

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
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "path is required")

	var inherits: String = params.get("inherits", "Node")
	var template: String = params.get("template", "")
	if template.is_empty():
		template = "extends %s\n\nfunc _ready() -> void:\n\tpass\n" % inherits

	var dir = path.get_base_dir()
	if not dir.is_empty() and dir != "res://":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return _error("FILE_ERROR", "Cannot open file for writing: %s" % path)
	f.store_string(template)
	f.close()

	if _editor_interface.get_resource_filesystem():
		_editor_interface.get_resource_filesystem().update_file(path)

	return {
		"path": path,
		"created": true
	}

func attach(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error("INVALID_ARGUMENT", "node_path is required")

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	var script_path: String = params.get("script_path", "")
	if script_path.is_empty():
		return _error("INVALID_ARGUMENT", "script_path is required")

	if not ResourceLoader.exists(script_path):
		return _error("NOT_FOUND", "Script file not found: %s" % script_path)

	var script: Script = load(script_path) as Script
	if not script:
		return _error("LOAD_FAILED", "Resource is not a Script: %s" % script_path)

	var prev_script = node.get_script()
	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Attach Script: " + script_path)
		undo_redo.add_do_method(node, "set_script", script)
		undo_redo.add_undo_method(node, "set_script", prev_script)
		undo_redo.commit_action()
	else:
		node.set_script(script)

	return {
		"node_path": node_path,
		"script_path": script_path,
		"attached": true
	}

func detach(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error("INVALID_ARGUMENT", "node_path is required")

	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	var prev_script = node.get_script()
	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Detach Script")
		undo_redo.add_do_method(node, "set_script", null)
		undo_redo.add_undo_method(node, "set_script", prev_script)
		undo_redo.commit_action()
	else:
		node.set_script(null)

	return {
		"node_path": node_path,
		"detached": true
	}

func inspect(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var script: Script = null
	var inspection_source := "attached"
	if not path.is_empty():
		if not FileAccess.file_exists(path):
			return _error("NOT_FOUND", "Script not found: %s" % path)
		if path.get_extension().to_lower() == "gd":
			var file := FileAccess.open(path, FileAccess.READ)
			if not file:
				return _error("FILE_ERROR", "Cannot read script source: %s" % path)
			var fresh := GDScript.new()
			# ResourceLoader's IGNORE modes still reuse GDScript's separate script cache.
			# Compile a new resource; never reload or take over the cached live script.
			if fresh.has_method("set_path_cache"):
				fresh.call("set_path_cache", path)
			else:
				fresh.resource_path = path.get_base_dir().path_join("__godot_mcp_inspect_" + str(fresh.get_instance_id()) + ".gd")
			fresh.source_code = file.get_as_text()
			file.close()
			if fresh.reload() != OK:
				return _error("SCRIPT_COMPILE_FAILED", "Cannot inspect invalid script source: %s" % path)
			script = fresh
			inspection_source = "disk"
		else:
			# Other languages/binary scripts describe the engine's compiled resource.
			script = load(path) as Script
			inspection_source = "resource"
	else:
		var node_path: String = params.get("node_path", "")
		if node_path.is_empty():
			return _error("INVALID_ARGUMENT", "Either path or node_path is required")
		var root: Node = _editor_interface.get_edited_scene_root()
		if not root:
			return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
		var node: Node = _resolve_node(root, node_path)
		if not node:
			return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)
		script = node.get_script() as Script

	if not script:
		return _error("NOT_FOUND", "No script found on target")

	var methods: Array = []
	for m in script.get_script_method_list():
		var args: Array = []
		for a in m.get("args", []):
			args.append({ "name": a["name"], "type": type_string(a["type"]) })
		methods.append({
			"name": m["name"],
			"args": args,
			"return_type": type_string(m.get("return", {}).get("type", TYPE_NIL))
		})

	var properties: Array = []
	for p in script.get_script_property_list():
		properties.append({
			"name": p["name"],
			"type": type_string(p["type"])
		})

	var signals_list: Array = []
	for s in script.get_script_signal_list():
		var args: Array = []
		for a in s.get("args", []):
			args.append({ "name": a["name"], "type": type_string(a["type"]) })
		signals_list.append({
			"name": s["name"],
			"args": args
		})

	return {
		"path": path if not path.is_empty() else script.resource_path,
		"inspection_source": inspection_source,
		"base_type": script.get_instance_base_type(),
		"methods": methods,
		"properties": properties,
		"signals": signals_list
	}

func validate(params: Dictionary) -> Dictionary:
	var content: String = params.get("content", "")
	var source_path: String = params.get("path", "")
	if not source_path.is_empty() and (not source_path.begins_with("res://") or not source_path.ends_with(".gd") or source_path.contains("..") or source_path.contains("\\") or source_path.substr(6).contains(":")):
		return _error("INVALID_ARGUMENT", "Validation path must be a project GDScript path")
	var script: GDScript = GDScript.new()
	var base := source_path.get_base_dir() if not source_path.is_empty() else "res://"
	var validation_path := base.path_join("__godot_mcp_validate_" + str(script.get_instance_id()) + ".gd")
	script.resource_path = validation_path
	script.source_code = content
	var scope := NativeDiagnostics.begin()
	var err = script.reload()
	var captured := NativeDiagnostics.finish(scope)
	var errors: Array = []
	for entry in captured.entries:
		if entry.kind != "error": continue
		var file := str(entry.file) if entry.file != null else ""
		var script_location := file.ends_with(".gd")
		var display_path = (source_path if not source_path.is_empty() else null) if file == validation_path else (file if script_location else null)
		errors.append({"path":display_path,"line":int(entry.line) if script_location and int(entry.line)>0 else null,
			"column":null,"severity":"error","message":entry.message})
	if err != OK and errors.is_empty():
		errors.append({"path":source_path if not source_path.is_empty() else null,"line":null,"column":null,
			"severity":"error","message":"GDScript compilation failed with error code %d; native diagnostic location is unavailable" % err})
	return {"valid":err == OK and errors.is_empty(),"errors":errors,"error_code":err,
		"diagnostics_available":captured.available,"diagnostics_truncated":captured.dropped>0}
