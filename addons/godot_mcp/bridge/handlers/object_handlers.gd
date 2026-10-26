@tool
extends RefCounted

const VariantSerializer = preload("res://addons/godot_mcp/serialization/variant_serializer.gd")
const SafetyPolicy = preload("res://addons/godot_mcp/bridge/safety_policy.gd")

var _editor_interface

func _init(editor_interface) -> void:
    _editor_interface = editor_interface

func _project_resource(path_value: String) -> bool:
    if not path_value.begins_with("res://") or path_value.contains("\\"):
        return false
    var relative = path_value.substr(6)
    if relative.is_empty() or relative.contains(":"):
        return false
    for segment in relative.split("/"):
        if segment in ["", ".", "..", ".godot", ".godot-mcp", ".git"]:
            return false
    return not relative.begins_with("addons/godot_mcp/")

func _owned_target(target: Object) -> bool:
    if not is_instance_valid(target):
        return false
    if target is Node:
        var scene_root = _editor_interface.get_edited_scene_root()
        return scene_root != null and (target == scene_root or scene_root.is_ancestor_of(target))
    if target is Resource:
        return _project_resource(target.resource_path.get_slice("::", 0))
    return false

func resolve_target(params: Dictionary) -> Object:
    if params.has("node_path"):
        var path_str: String = str(params["node_path"])
        var scene_root: Node = _editor_interface.get_edited_scene_root()
        if scene_root == null:
            return null
        if path_str == "." or path_str == "/" + scene_root.name or path_str == scene_root.name:
            return scene_root
        if path_str.begins_with("/" + scene_root.name + "/"):
            path_str = path_str.substr(scene_root.name.length() + 2)
        elif path_str.begins_with(scene_root.name + "/"):
            path_str = path_str.substr(scene_root.name.length() + 1)
        elif path_str.begins_with("/"):
            return null
        if path_str.contains(":") or path_str.contains("\\") or path_str.split("/").has(".."):
            return null
        var target = scene_root.get_node_or_null(NodePath(path_str))
        return target if _owned_target(target) else null
    elif params.has("resource_path"):
        var res_path: String = str(params["resource_path"])
        if _project_resource(res_path) and ResourceLoader.exists(res_path):
            return ResourceLoader.load(res_path)
    elif params.has("object_id"):
        var obj_id := int(params["object_id"])
        var target = instance_from_id(obj_id)
        return target if _owned_target(target) else null
    return null

func handle_get_class(params: Dictionary) -> Dictionary:
    var target := resolve_target(params)
    if target == null:
        return {"__error": {"code": "OBJECT_NOT_FOUND", "message": "Target object could not be resolved"}}
    return {"class": target.get_class()}

func handle_get_property_list(params: Dictionary) -> Dictionary:
    var target := resolve_target(params)
    if target == null:
        return {"__error": {"code": "OBJECT_NOT_FOUND", "message": "Target object could not be resolved"}}
    var props: Array = []
    for p in target.get_property_list():
        props.append({
            "name": p.get("name", ""),
            "type": type_string(p.get("type", 0)),
            "hint": p.get("hint", 0),
            "hint_string": p.get("hint_string", ""),
            "usage": p.get("usage", 0)
        })
    return {"properties": props}

func handle_get_method_list(params: Dictionary) -> Dictionary:
    var target := resolve_target(params)
    if target == null:
        return {"__error": {"code": "OBJECT_NOT_FOUND", "message": "Target object could not be resolved"}}
    var methods: Array = []
    for m in target.get_method_list():
        var args: Array = []
        for arg in m.get("args", []):
            args.append({
                "name": arg.get("name", ""),
                "type": type_string(arg.get("type", 0))
            })
        methods.append({
            "name": m.get("name", ""),
            "return_type": type_string(m.get("return", {}).get("type", 0)),
            "args": args
        })
    return {"methods": methods}

func handle_get_signal_list(params: Dictionary) -> Dictionary:
    var target := resolve_target(params)
    if target == null:
        return {"__error": {"code": "OBJECT_NOT_FOUND", "message": "Target object could not be resolved"}}
    var signals: Array = []
    for s in target.get_signal_list():
        var args: Array = []
        for arg in s.get("args", []):
            args.append({
                "name": arg.get("name", ""),
                "type": type_string(arg.get("type", 0))
            })
        signals.append({
            "name": s.get("name", ""),
            "args": args
        })
    return {"signals": signals}

func get_property(params: Dictionary) -> Dictionary:
    var target := resolve_target(params)
    if target == null:
        return {"__error": {"code": "OBJECT_NOT_FOUND", "message": "Target object could not be resolved"}}
    var prop_name := str(params.get("property", ""))
    return {
        "property": prop_name,
        "value": VariantSerializer.serialize(target.get(prop_name))
    }

func set_property(params: Dictionary) -> Dictionary:
    var target := resolve_target(params)
    if target == null:
        return {"__error": {"code": "OBJECT_NOT_FOUND", "message": "Target object could not be resolved"}}
    var prop_name := str(params.get("property", ""))
    var prev = target.get(prop_name)
    var new_val = VariantSerializer.deserialize(params.get("value"))
    target.set(prop_name, new_val)
    return {
        "property": prop_name,
        "previous_value": VariantSerializer.serialize(prev),
        "new_value": VariantSerializer.serialize(target.get(prop_name))
    }

func call_method(params: Dictionary) -> Dictionary:
    var target := resolve_target(params)
    if target == null:
        return {"__error": {"code": "OBJECT_NOT_FOUND", "message": "Target object could not be resolved"}}
    var method_name := str(params.get("method", ""))
    if not SafetyPolicy.is_method_allowed(target, method_name):
        return {
            "__error": {
                "code": "SAFETY_VIOLATION",
                "message": "Method '%s' is blocked by safety policy" % method_name
            }
        }
    var raw_args = params.get("args", [])
    var deserialized_args: Array = []
    if typeof(raw_args) == TYPE_ARRAY:
        for arg in raw_args:
            deserialized_args.append(VariantSerializer.deserialize(arg))
    var res = target.callv(method_name, deserialized_args)
    return {
        "result": VariantSerializer.serialize(res)
    }