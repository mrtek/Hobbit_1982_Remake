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

func list(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	var signals_list: Array = []
	for s in node.get_signal_list():
		var args: Array = []
		for a in s.get("args", []):
			args.append({ "name": a["name"], "type": type_string(a["type"]) })
		signals_list.append({
			"name": s["name"],
			"args": args
		})

	return {
		"node_path": _get_logical_path(root, node),
		"signals": signals_list
	}

func connections(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var node_path: String = params.get("node_path", "")
	var node: Node = _resolve_node(root, node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)

	var target_signal: String = params.get("signal_name", "")
	var connections_list: Array = []

	var signals_to_check: Array = []
	if not target_signal.is_empty():
		signals_to_check.append(target_signal)
	else:
		for s in node.get_signal_list():
			signals_to_check.append(s["name"])

	for sig_name in signals_to_check:
		for conn in node.get_signal_connection_list(sig_name):
			var callable: Callable = conn.get("callable", Callable())
			var target_obj = callable.get_object()
			var target_path = ""
			if target_obj is Node:
				target_path = _get_logical_path(root, target_obj)
			elif target_obj != null:
				target_path = str(target_obj)

			connections_list.append({
				"signal": sig_name,
				"target_path": target_path,
				"method": callable.get_method(),
				"flags": conn.get("flags", 0)
			})

	return {
		"node_path": _get_logical_path(root, node),
		"connections": connections_list
	}

func connect_signal(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var src_path: String = params.get("source_node_path", "")
	var src_node: Node = _resolve_node(root, src_path)
	if not src_node:
		return _error("NODE_NOT_FOUND", "Source node not found: %s" % src_path)

	var sig_name: String = params.get("signal_name", "")
	if sig_name.is_empty():
		return _error("INVALID_ARGUMENT", "signal_name is required")
	if not src_node.has_signal(sig_name):
		return _error("SIGNAL_NOT_FOUND", "Node does not have signal: %s" % sig_name)

	var target_path: String = params.get("target_node_path", "")
	var target_node: Node = _resolve_node(root, target_path)
	if not target_node:
		return _error("NODE_NOT_FOUND", "Target node not found: %s" % target_path)

	var target_method: String = params.get("target_method", "")
	if target_method.is_empty():
		return _error("INVALID_ARGUMENT", "target_method is required")

	var flags: int = int(params.get("flags", Object.CONNECT_PERSIST))
	var callable := Callable(target_node, target_method)
	if src_node.is_connected(sig_name, callable):
		return _error("ALREADY_CONNECTED", "Signal %s is already connected to %s.%s" % [sig_name, target_path, target_method])

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Connect Signal: " + sig_name)
		undo_redo.add_do_method(src_node, "connect", sig_name, callable, flags)
		undo_redo.add_undo_method(src_node, "disconnect", sig_name, callable)
		undo_redo.commit_action()
	else:
		src_node.connect(sig_name, callable, flags)

	return {
		"connected": true,
		"source_node_path": _get_logical_path(root, src_node),
		"signal_name": sig_name,
		"target_node_path": _get_logical_path(root, target_node),
		"target_method": target_method
	}

func disconnect_signal(params: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")

	var src_path: String = params.get("source_node_path", "")
	var src_node: Node = _resolve_node(root, src_path)
	if not src_node:
		return _error("NODE_NOT_FOUND", "Source node not found: %s" % src_path)

	var sig_name: String = params.get("signal_name", "")
	if sig_name.is_empty():
		return _error("INVALID_ARGUMENT", "signal_name is required")

	var target_path: String = params.get("target_node_path", "")
	var target_node: Node = _resolve_node(root, target_path)
	if not target_node:
		return _error("NODE_NOT_FOUND", "Target node not found: %s" % target_path)

	var target_method: String = params.get("target_method", "")
	if target_method.is_empty():
		return _error("INVALID_ARGUMENT", "target_method is required")

	var callable := Callable(target_node, target_method)
	if not src_node.is_connected(sig_name, callable):
		return _error("NOT_CONNECTED", "Signal %s is not connected to %s.%s" % [sig_name, target_path, target_method])

	var undo_redo = _editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Disconnect Signal: " + sig_name)
		undo_redo.add_do_method(src_node, "disconnect", sig_name, callable)
		undo_redo.add_undo_method(src_node, "connect", sig_name, callable, Object.CONNECT_PERSIST)
		undo_redo.commit_action()
	else:
		src_node.disconnect(sig_name, callable)

	return {
		"disconnected": true,
		"source_node_path": _get_logical_path(root, src_node),
		"signal_name": sig_name,
		"target_node_path": _get_logical_path(root, target_node),
		"target_method": target_method
	}
