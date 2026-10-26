@tool
extends RefCounted

var _editor_interface
var _variant_serializer = preload("res://addons/godot_mcp/serialization/variant_serializer.gd")

func _init(editor_interface) -> void:
	_editor_interface = editor_interface

func _error(code: String, message: String) -> Dictionary:
	return {
		"__error": {
			"code": code,
			"message": message
		}
	}

func load_resource(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "path is required")
	if not ResourceLoader.exists(path):
		return _error("NOT_FOUND", "Resource does not exist: %s" % path)

	var type_hint: String = params.get("type_hint", "")
	var res = ResourceLoader.load(path, type_hint)
	if not res:
		return _error("LOAD_FAILED", "Failed to load resource: %s" % path)

	var props: Dictionary = {}
	for p in res.get_property_list():
		var pname = p["name"]
		var usage = p["usage"]
		if usage & PROPERTY_USAGE_EDITOR or usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props[pname] = _variant_serializer.encode(res.get(pname))

	return {
		"path": path,
		"type": res.get_class(),
		"properties": props
	}

func inspect(params: Dictionary) -> Dictionary:
	return load_resource(params)

func create(params: Dictionary) -> Dictionary:
	var type_str: String = params.get("type", "")
	if type_str.is_empty():
		return _error("INVALID_ARGUMENT", "type is required")
	if not ClassDB.class_exists(type_str):
		return _error("INVALID_ARGUMENT", "Class does not exist: %s" % type_str)
	if not ClassDB.is_parent_class(type_str, "Resource") and type_str != "Resource":
		return _error("INVALID_ARGUMENT", "Class is not a Resource: %s" % type_str)
	if not ClassDB.can_instantiate(type_str):
		return _error("INVALID_ARGUMENT", "Cannot instantiate class: %s" % type_str)

	var path: String = params.get("path", "")
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "path is required")

	var dir = path.get_base_dir()
	if not dir.is_empty() and dir != "res://":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var res: Resource = ClassDB.instantiate(type_str)
	var initial_props: Dictionary = params.get("properties", {})
	for k in initial_props.keys():
		res.set(str(k), _variant_serializer.decode(initial_props[k]))

	var err = ResourceSaver.save(res, path)
	if err != OK:
		return _error("SAVE_FAILED", "Failed to save resource to %s (code %d)" % [path, err])

	return {
		"path": path,
		"type": res.get_class()
	}

func set_property(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "path is required")
	var prop: String = params.get("property", "")
	if prop.is_empty():
		return _error("INVALID_ARGUMENT", "property is required")

	if not ResourceLoader.exists(path):
		return _error("NOT_FOUND", "Resource does not exist: %s" % path)

	var res = ResourceLoader.load(path)
	if not res:
		return _error("LOAD_FAILED", "Failed to load resource: %s" % path)

	var prev = res.get(prop)
	var decoded = _variant_serializer.decode(params.get("value"))
	res.set(prop, decoded)

	var err = ResourceSaver.save(res, path)
	if err != OK:
		return _error("SAVE_FAILED", "Failed to save resource after setting property (code %d)" % err)

	return {
		"path": path,
		"property": prop,
		"previous_value": _variant_serializer.encode(prev),
		"new_value": _variant_serializer.encode(res.get(prop))
	}

func save(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error("INVALID_ARGUMENT", "path is required")
	if not ResourceLoader.exists(path):
		return _error("NOT_FOUND", "Resource does not exist: %s" % path)

	var flags: int = int(params.get("flags", 0))
	var res = ResourceLoader.load(path)
	if not res:
		return _error("LOAD_FAILED", "Failed to load resource: %s" % path)

	var err = ResourceSaver.save(res, path, flags)
	if err != OK:
		return _error("SAVE_FAILED", "Failed to save resource: %s (code %d)" % [path, err])

	return {
		"path": path,
		"saved": true
	}

func duplicate(params: Dictionary) -> Dictionary:
	var source_path: String = params.get("source_path", "")
	if source_path.is_empty():
		return _error("INVALID_ARGUMENT", "source_path is required")
	var target_path: String = params.get("target_path", "")
	if target_path.is_empty():
		return _error("INVALID_ARGUMENT", "target_path is required")

	if not ResourceLoader.exists(source_path):
		return _error("NOT_FOUND", "Source resource does not exist: %s" % source_path)

	var subresources: bool = params.get("subresources", false)
	var res = ResourceLoader.load(source_path)
	if not res:
		return _error("LOAD_FAILED", "Failed to load source resource: %s" % source_path)

	var copy: Resource = res.duplicate(subresources)
	var dir = target_path.get_base_dir()
	if not dir.is_empty() and dir != "res://":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var err = ResourceSaver.save(copy, target_path)
	if err != OK:
		return _error("SAVE_FAILED", "Failed to save duplicate resource to %s (code %d)" % [target_path, err])

	return {
		"path": target_path,
		"type": copy.get_class()
	}
