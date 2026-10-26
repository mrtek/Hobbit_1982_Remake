@tool
extends RefCounted

const Budget = preload("res://addons/godot_mcp/serialization/serialization_budget.gd")

var _editor_interface

func _init(editor_interface) -> void:
    _editor_interface = editor_interface

func serialize_node(scene_root: Node, node: Node, depth: int = 0, budget: Dictionary = {}) -> Dictionary:
    if budget.is_empty():
        budget = {"left":2000, "bytes":1024*1024}
    budget.left -= 1
    if depth > 32 or budget.left < 0 or node.get_child_count() > budget.left:
        return {"__error":{"code":"RESULT_TOO_LARGE", "message":"Editor scene tree exceeds depth/node limits"}}
    var script_path = null
    var script = node.get_script()
    if script is Script and not script.resource_path.is_empty():
        script_path = script.resource_path
    var relative := scene_root.get_path_to(node)
    var logical_path := "/%s" % scene_root.name
    if relative != NodePath("."):
        logical_path += "/%s" % str(relative)
    var result = {
        "name": node.name,
        "type": node.get_class(),
        "path": logical_path,
        "script": script_path,
        "children": []
    }
    var issue = Budget.check(result)
    if not issue.is_empty():
        return {"__error":{"code":"RESULT_TOO_LARGE", "message":issue}}
    budget.bytes -= JSON.stringify(result).to_utf8_buffer().size()
    if budget.bytes < 0:
        return {"__error":{"code":"RESULT_TOO_LARGE", "message":"Editor scene tree exceeds byte limits"}}
    for i in range(node.get_child_count()):
        var child = serialize_node(scene_root, node.get_child(i), depth + 1, budget)
        if child.has("__error"):
            return child
        result.children.append(child)
    return result

func run(_params: Dictionary) -> Dictionary:
    var root: Node = _editor_interface.get_edited_scene_root()
    var serialized = serialize_node(root, root) if root else null
    if serialized is Dictionary and serialized.has("__error"):
        return serialized
    return {
        "scenePath": root.scene_file_path if root else null,
        "root": serialized
    }
