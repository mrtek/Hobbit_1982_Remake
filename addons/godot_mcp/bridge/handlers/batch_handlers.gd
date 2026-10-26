@tool
extends RefCounted
const Scope = preload("res://addons/godot_mcp/bridge/scene_scope.gd")
const Serializer = preload("res://addons/godot_mcp/serialization/variant_serializer.gd")
const Budget = preload("res://addons/godot_mcp/serialization/serialization_budget.gd")
var _editor
func _init(editor): _editor = editor
func _error(code: String, message: String, details: Dictionary = {}) -> Dictionary:
    return {"__error":{"code":code,"message":message,"details":details}}
func _parent(ctx: Dictionary, node: Node): return ctx.parents.get(node.get_instance_id(), node.get_parent())
func _name(ctx: Dictionary, node: Node): return ctx.names.get(node.get_instance_id(), str(node.name))
func _key(ctx: Dictionary, node: Node): return ctx.keys.get(node.get_instance_id(), str(node.get_instance_id())) if node != null else "none"
func _active(ctx: Dictionary, node: Node) -> bool:
    var current = node
    for i in range(2001):
        if current == null or ctx.removed.has(current.get_instance_id()): return false
        if current == ctx.root: return true
        current = _parent(ctx, current)
    return false
func _node(ctx: Dictionary, reference: String):
    var node = ctx.aliases.get(reference.substr(1)) if reference.begins_with("@") else Scope.resolve(ctx.root, reference)
    return node if node != null and _active(ctx,node) else null
func _children(ctx: Dictionary, parent: Node) -> Array:
    var children: Array = []
    for node in ctx.nodes:
        if node != ctx.root and not ctx.removed.has(node.get_instance_id()) and _parent(ctx,node) == parent:
            children.append(node)
    return children
func _unique(ctx: Dictionary, parent: Node, name_value: String, except = null) -> bool:
    if name_value.is_empty() or name_value.validate_node_name() != name_value: return false
    for child in _children(ctx,parent):
        if child != except and _name(ctx,child) == name_value: return false
    return true
func _dispose(ctx: Dictionary):
    for node in ctx.created:
        if is_instance_valid(node) and node.get_parent() == null: node.free()
func _property(target: Object, property: String, value) -> Dictionary:
    if target is Script or property in ["script","owner","name","scene_file_path","resource_path"]:
        return _error("BATCH_PROPERTY_BLOCKED","Use a dedicated structured operation for this property")
    var script: Script = target.get_script() as Script
    if script != null:
        for entry in script.get_script_property_list():
            if str(entry.name) == property: return _error("BATCH_PROPERTY_BLOCKED","Batch setters require native properties")
    var found = null
    for entry in target.get_property_list():
        if str(entry.name) == property: found = entry; break
    if found == null: return _error("PROPERTY_NOT_FOUND","Batch property not found: " + property)
    var decoded = Serializer.decode(value)
    var issue = Budget.check(decoded)
    if not issue.is_empty(): return _error("ARGUMENT_TOO_LARGE",issue)
    var expected: int = int(found.type)
    if expected == TYPE_FLOAT and typeof(decoded) == TYPE_INT: decoded = float(decoded)
    if expected == TYPE_INT and typeof(decoded) == TYPE_FLOAT and is_finite(decoded) and decoded == floor(decoded): decoded = int(decoded)
    if expected == TYPE_STRING_NAME and decoded is String: decoded = StringName(decoded)
    if expected == TYPE_NODE_PATH and decoded is String: decoded = NodePath(decoded)
    if expected != TYPE_NIL and typeof(decoded) != expected and not (expected == TYPE_OBJECT and decoded == null):
        var expected_name := type_string(expected)
        var received_name := type_string(typeof(decoded))
        var details := {"property": property, "expectedType": expected_name, "receivedType": received_name}
        if expected == TYPE_PACKED_VECTOR2_ARRAY:
            details["example"] = {"type":"PackedVector2Array","value":[{"x":0,"y":0},{"x":32,"y":0},{"x":32,"y":32}]}
        return _error("BATCH_TYPE_MISMATCH",
            "Batch property %s expects %s; received %s" % [property, expected_name, received_name], details)
    if not Budget.check(target.get(property)).is_empty(): return _error("RESULT_TOO_LARGE","Existing property exceeds undo snapshot limits")
    return {"value":decoded}
func _prepare(params: Dictionary) -> Dictionary:
    var root: Node = _editor.get_edited_scene_root()
    if root == null: return _error("NO_OPEN_SCENE","Open a scene before batching edits")
    var manager = _editor.get_editor_undo_redo()
    if manager == null: return _error("CAPABILITY_UNAVAILABLE","Editor Undo is required")
    var operations: Array = params.get("operations",[])
    if operations.is_empty() or operations.size() > 64: return _error("INVALID_ARGUMENT","Batch requires 1..64 operations")
    var ctx = {"root":root,"manager":manager,"nodes":[root],"created":[],"aliases":{},"keys":{},"parents":{},"names":{},"removed":{},"plan":[],"signature":[]}
    var cursor = 0
    while cursor < ctx.nodes.size():
        var node = ctx.nodes[cursor]; cursor += 1
        if ctx.nodes.size() + node.get_child_count() > 2000: return _error("RESULT_TOO_LARGE","Batch scene exceeds node limit")
        for child in node.get_children(): ctx.nodes.append(child)
    for operation in operations:
        var op = str(operation.get("op",""))
        var step = {"op":op}
        var error = {}
        if op == "create":
            var parent = _node(ctx,str(operation.get("parent",".")))
            var id = str(operation.get("id","")); var type = str(operation.get("type","")); var name_value = str(operation.get("name",""))
            if parent == null or id.is_empty() or ctx.aliases.has(id) or not _unique(ctx,parent,name_value): error = _error("BATCH_INVALID_NODE","Invalid parent, alias or colliding name")
            elif not ClassDB.class_exists(type) or not ClassDB.can_instantiate(type) or not ClassDB.is_parent_class(type,"Node") and type != "Node": error = _error("BATCH_INVALID_NODE","Batch class must be an instantiable native Node")
            else:
                var node: Node = ClassDB.instantiate(type); node.name = name_value
                ctx.created.append(node); ctx.nodes.append(node); ctx.aliases[id]=node;ctx.keys[node.get_instance_id()]="@"+id;ctx.parents[node.get_instance_id()]=parent
                step.merge({"node":node,"parent":parent,"id":id,"desired_name":name_value})
                ctx.signature.append({"op":op,"parent":_key(ctx,parent),"name":name_value,"type":type,"siblings":_children(ctx,parent).map(func(n):return _name(ctx,n))})
        elif op in ["set_property","resource_set_property"]:
            var target: Object = _node(ctx,str(operation.get("node",""))) if op == "set_property" else ResourceLoader.load(str(operation.get("path","")))
            if target == null: error = _error("OBJECT_NOT_FOUND","Batch target not found")
            else:
                var property = str(operation.get("property","")); var checked = _property(target,property,operation.get("value"))
                if checked.has("__error"): error=checked
                else:
                    step.merge({"target":target,"property":property,"value":checked.value})
                    ctx.signature.append({"op":op,"target":_key(ctx,target) if target is Node else str(operation.get("path","")),"property":property,"before":Serializer.serialize(target.get(property))})
        elif op in ["delete","rename","reparent","move"]:
            var node = _node(ctx,str(operation.get("node","")))
            if node == null or node == root: error = _error("BATCH_INVALID_NODE","Batch hierarchy edits require an existing non-root node")
            else:
                var parent = _parent(ctx,node)
                step.node=node
                ctx.signature.append({"op":op,"node":_key(ctx,node),"parent":_key(ctx,parent),"name":_name(ctx,node),"index":node.get_index()})
                if op == "delete": ctx.removed[node.get_instance_id()]=true
                elif op == "rename":
                    var name_value = str(operation.get("name",""))
                    if not _unique(ctx,parent,name_value,node): error=_error("BATCH_NAME_CONFLICT","Invalid or colliding batch name: "+name_value)
                    else: step.name=name_value;ctx.names[node.get_instance_id()]=name_value
                elif op == "move":
                    var index = int(operation.get("index",-1))
                    if index < 0 or index >= _children(ctx,parent).size(): error=_error("BATCH_INVALID_INDEX","Move index is outside the planned parent")
                    else: step.index=index
                else:
                    var next = _node(ctx,str(operation.get("parent","")));var ancestor=next
                    while ancestor != null and ancestor != node and ancestor != root: ancestor=_parent(ctx,ancestor)
                    if next == null or ancestor == node or not _unique(ctx,next,_name(ctx,node),node): error=_error("BATCH_INVALID_PARENT","Reparent would create a cycle or name collision")
                    else: step.parent=next;ctx.parents[node.get_instance_id()]=next
        else: error=_error("INVALID_ARGUMENT","Unsupported batch operation")
        if not error.is_empty(): _dispose(ctx);return error
        ctx.plan.append(step)
    if not Budget.check(ctx.signature, {"bytes":1024*1024}).is_empty(): _dispose(ctx);return _error("RESULT_TOO_LARGE","Batch preconditions exceed limits")
    var history = manager.get_history_undo_redo(manager.get_object_history_id(root))
    ctx.expected=JSON.stringify({"scene":root.scene_file_path,"root":str(root.get_instance_id()),"version":history.get_version() if history else 0,"operations":operations,"before":ctx.signature},"",true,true).sha256_text()
    return ctx
func preview(params: Dictionary) -> Dictionary:
    var ctx = _prepare(params)
    if ctx.has("__error"): return ctx
    var result = {"expected":ctx.expected,"operations":ctx.plan.size(),"scenePath":ctx.root.scene_file_path,"undo":"one editor action; files are not saved"}
    _dispose(ctx);return result
func _method(target: Object, name_value: String, args: Array = []) -> Dictionary: return {"kind":"method","target":target,"name":name_value,"args":args}
func _property_action(target: Object, name_value: String, value) -> Dictionary: return {"kind":"property","target":target,"name":name_value,"value":value}
func _run(action: Dictionary) -> bool:
    if not is_instance_valid(action.target): return false
    if action.kind == "property": action.target.set(action.name,action.value)
    else: action.target.callv(action.name,action.args)
    return true
func _owners(node: Node) -> Array:
    var result: Array = [];var pending: Array = [node]
    while not pending.is_empty():
        var current: Node = pending.pop_back()
        result.append(_property_action(current,"owner",current.owner))
        pending.append_array(current.get_children())
    return result
func _equal(a,b) -> bool:
    if typeof(a) != typeof(b): return false
    if typeof(a) == TYPE_FLOAT: return is_equal_approx(a,b)
    if typeof(a) in [TYPE_VECTOR2,TYPE_VECTOR3,TYPE_COLOR,TYPE_QUATERNION]: return a.is_equal_approx(b)
    return a == b
func _before(ctx: Dictionary) -> Dictionary:
    var result = {"nodes":[],"properties":[]};var seen: Dictionary = {}
    for node in ctx.nodes:
        if not ctx.keys.has(node.get_instance_id()):
            result.nodes.append({"node":node,"parent":node.get_parent(),"index":node.get_index(),"name":node.name,"owner":node.owner})
    for step in ctx.plan:
        if step.op in ["set_property","resource_set_property"]:
            var key = str(step.target.get_instance_id())+":"+step.property
            if not seen.has(key):
                seen[key]=true
                var value=step.target.get(step.property)
                if value is Array or value is Dictionary: value=value.duplicate(true)
                result.properties.append({"target":step.target,"property":step.property,"value":value})
    return result
func _restored(before: Dictionary, ctx: Dictionary) -> bool:
    for entry in before.nodes:
        if not is_instance_valid(entry.node): return false
        if entry.node.get_parent()!=entry.parent or entry.node.get_index()!=entry.index or entry.node.name!=entry.name or entry.node.owner!=entry.owner: return false
    for entry in before.properties:
        if ctx.created.has(entry.target): continue
        if not is_instance_valid(entry.target) or not _equal(entry.target.get(entry.property),entry.value): return false
    return true
func _step_valid(step: Dictionary) -> bool:
    if step.has("node") and not is_instance_valid(step.node): return false
    if step.has("target") and not is_instance_valid(step.target): return false
    if step.has("parent") and not is_instance_valid(step.parent): return false
    return true
func _step_applied(step: Dictionary, root: Node) -> bool:
    if not _step_valid(step): return false
    match step.op:
        "create": return step.node.get_parent()==step.parent and step.node.name==step.desired_name and step.node.owner==root
        "delete": return step.node.get_parent()==null
        "rename": return step.node.name==step.name
        "reparent": return step.node.get_parent()==step.parent
        "move": return step.node.get_index()==step.index
        "set_property", "resource_set_property": return _equal(step.target.get(step.property),step.value)
    return false
func apply(params: Dictionary) -> Dictionary:
    var ctx = _prepare(params)
    if ctx.has("__error"): return ctx
    if str(params.get("expected","")) != ctx.expected: _dispose(ctx);return _error("BATCH_CONFLICT","Scene or operation preconditions changed; preview again")
    if _editor.get_edited_scene_root()!=ctx.root: _dispose(ctx);return _error("BATCH_CONFLICT","Active scene changed while preparing the batch")
    var before = _before(ctx)
    var actions: Array = [];var undo_groups: Array = [];var references: Array = []
    var failed = false
    for step in ctx.plan:
        if not _step_valid(step): failed=true;break
        var forward: Array = [];var inverse: Array = []
        if step.op == "create":
            forward=[_method(step.parent,"add_child",[step.node]),_property_action(step.node,"owner",ctx.root)]
            inverse=[_method(step.parent,"remove_child",[step.node])]
        elif step.op in ["set_property","resource_set_property"]:
            var previous = step.target.get(step.property)
            if previous is Array or previous is Dictionary: previous=previous.duplicate(true)
            forward=[_property_action(step.target,step.property,step.value)];inverse=[_property_action(step.target,step.property,previous)]
        elif step.op == "rename": forward=[_property_action(step.node,"name",step.name)];inverse=[_property_action(step.node,"name",step.node.name)]
        elif step.op == "move": forward=[_method(step.node.get_parent(),"move_child",[step.node,step.index])];inverse=[_method(step.node.get_parent(),"move_child",[step.node,step.node.get_index()])]
        elif step.op == "delete":
            inverse=[_method(step.node.get_parent(),"add_child",[step.node]),_method(step.node.get_parent(),"move_child",[step.node,step.node.get_index()])]
            inverse.append_array(_owners(step.node));forward=[_method(step.node.get_parent(),"remove_child",[step.node])];references.append(step.node)
        elif step.op == "reparent":
            inverse=[_method(step.node,"reparent",[step.node.get_parent(),false]),_method(step.node.get_parent(),"move_child",[step.node,step.node.get_index()])]
            inverse.append_array(_owners(step.node));forward=[_method(step.node,"reparent",[step.parent,false])]
        for action in forward:
            if not _run(action): failed=true;break
        actions.append_array(forward);undo_groups.push_front(inverse)
        if failed or not _step_applied(step,ctx.root): failed=true;break
    if failed:
        for group in undo_groups:
            for action in group: _run(action)
        var restored = _restored(before,ctx)
        _dispose(ctx)
        return _error("BATCH_APPLY_FAILED" if restored else "BATCH_RECOVERY_REQUIRED","Batch application failed; inverse operations executed",{"inverseExecuted":true,"rollbackVerified":restored,"manualRecoveryRequired":not restored})
    var manager=ctx.manager
    manager.create_action(str(params.get("label","MCP batch")),UndoRedo.MERGE_DISABLE,ctx.root)
    for action in actions:
        if action.kind == "property": manager.add_do_property(action.target,action.name,action.value)
        else: manager.callv("add_do_method",[action.target,action.name]+action.args)
    for group in undo_groups:
        for action in group:
            if action.kind == "property": manager.add_undo_property(action.target,action.name,action.value)
            else: manager.callv("add_undo_method",[action.target,action.name]+action.args)
    for node in ctx.created: manager.add_do_reference(node)
    for step in ctx.plan:
        if step.op == "resource_set_property": manager.add_do_reference(step.target)
    for node in references: manager.add_undo_reference(node)
    manager.commit_action(false)
    var aliases: Dictionary = {}
    for id in ctx.aliases:
        var node=ctx.aliases[id]
        aliases[id]="/"+str(ctx.root.name)+"/"+str(ctx.root.get_path_to(node)) if node.is_inside_tree() else null
    return {"applied":true,"operations":ctx.plan.size(),"aliases":aliases,"undoActions":1,"saved":false}
