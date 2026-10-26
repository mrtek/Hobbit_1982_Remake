extends RefCounted
var tree: SceneTree
var agent: Node
var serializer = preload("res://addons/godot_mcp/serialization/variant_serializer.gd")
const SerializationBudget = preload("res://addons/godot_mcp/serialization/serialization_budget.gd")
func _init(scene_tree: SceneTree, runtime_agent: Node) -> void:
    tree = scene_tree
    agent = runtime_agent
func _error(code: String, message: String) -> Dictionary:
    return {"__error":{"code":code,"message":message}}
func _allowed(value, depth: int = 0) -> bool:
    return SerializationBudget.check(value, {"depth":8-depth, "string":4096, "container":256}).is_empty()
func _resolve(raw: String) -> Node:
    if not raw.begins_with("/root/") or raw.contains("..") or raw.contains("\\") or raw.begins_with("/root/GodotMcpRuntime"):
        return null
    var node := tree.root.get_node_or_null(NodePath(raw))
    if node == agent or (node != null and agent.is_ancestor_of(node)):
        return null
    return node
func _info(node: Node) -> Dictionary:
    return {"name":str(node.name),"type":node.get_class(),"path":str(node.get_path())}
func _walk(node: Node, depth: int, max_depth: int, budget: Dictionary) -> Dictionary:
    budget.left -= 1
    var result := _info(node)
    var children: Array = []
    for child in node.get_children():
        if child == agent:
            continue
        if depth >= max_depth or budget.left <= 0:
            budget.truncated = true
            break
        children.append(_walk(child,depth+1,max_depth,budget))
    result["children"] = children
    return result
func run(method: String, params: Dictionary) -> Dictionary:
    if method == "runtime.pause" or method == "runtime.resume":
        tree.paused = method == "runtime.pause"
        return {"paused":tree.paused}
    if method == "debug.performance":
        var fps := Engine.get_frames_per_second()
        return {"sampledAt":Time.get_datetime_string_from_system(true)+"Z","fps":fps,
            "frameTimeMs":1000.0/fps if fps>0 else null,"nodeCount":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
            "objectCount":int(Performance.get_monitor(Performance.OBJECT_COUNT))}
    if method == "runtime.scene_tree":
        var budget := {"left":clampi(int(params.get("max_nodes",500)),1,2000),"truncated":false}
        var root := _walk(tree.root,0,clampi(int(params.get("max_depth",16)),0,32),budget)
        return {"root":root,"scenePath":tree.current_scene.scene_file_path if tree.current_scene else null,"truncated":budget.truncated}
    if method != "runtime.get_property" and method != "runtime.inspect_node":
        return _error("METHOD_NOT_FOUND","Unsupported runtime operation")
    var node := _resolve(str(params.get("node_path","")))
    if node == null:
        return _error("NODE_NOT_FOUND","Runtime node does not exist")
    var requested: Array = [params.get("property","")] if method == "runtime.get_property" else params.get("properties",[])
    if requested.size() > 64:
        return _error("RESULT_TOO_LARGE","Too many properties")
    var names: Dictionary = {}
    for property in node.get_property_list():
        names[str(property.name)] = true
    var values: Dictionary = {}
    for property in requested:
        if not names.has(str(property)):
            return _error("PROPERTY_NOT_FOUND","Runtime property does not exist")
        var value = node.get(str(property))
        if not _allowed(value):
            return _error("RESULT_TOO_LARGE","Runtime value exceeds inspection limits")
        values[str(property)] = serializer.serialize(value)
        if not SerializationBudget.check(values, {"depth":40, "container":10000}).is_empty():
            return _error("RESULT_TOO_LARGE","Combined runtime properties exceed serialization limits")
    var result := {"property":str(requested[0]),"value":values[str(requested[0])]} if method == "runtime.get_property" else {"node":_info(node),"properties":values}
    if JSON.stringify(result).to_utf8_buffer().size() > 256*1024:
        return _error("RESULT_TOO_LARGE","Runtime result exceeds 256 KiB")
    return result
