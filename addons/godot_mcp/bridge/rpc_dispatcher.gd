@tool
extends RefCounted

var _compatibility
var _project_info
var _scene_tree
var _object_handlers
var _scene_handlers
var _node_handlers
var _resource_handlers
var _script_handlers
var _signal_handlers
var _project_handlers
var _editor_handlers
var _visual_handlers
var _ui_handlers
var _animation_handlers
var _tilemap_handlers
var _tileset_handlers
var _power2d_handlers
var _power3d_handlers
var _material3d_handlers
var _navigation_handlers
var _runtime
var _recovery
var _batch
var _dependencies
var _geometry

func _init(editor_interface, runtime = null) -> void:
    _batch = preload("res://addons/godot_mcp/bridge/handlers/batch_handlers.gd").new(editor_interface)
    _dependencies = preload("res://addons/godot_mcp/bridge/handlers/dependency_handlers.gd").new(editor_interface)
    _geometry = preload("res://addons/godot_mcp/bridge/handlers/geometry_handlers.gd").new(editor_interface)
    _runtime = runtime
    _compatibility = preload("res://addons/godot_mcp/bridge/compatibility/compatibility_core.gd").new(editor_interface)
    _recovery = preload("res://addons/godot_mcp/bridge/handlers/recovery_handlers.gd").new(editor_interface)
    _project_info = preload("res://addons/godot_mcp/bridge/handlers/project_info.gd").new(editor_interface)
    _scene_tree = preload("res://addons/godot_mcp/bridge/handlers/scene_tree.gd").new(editor_interface)
    _object_handlers = preload("res://addons/godot_mcp/bridge/handlers/object_handlers.gd").new(editor_interface)
    _scene_handlers = preload("res://addons/godot_mcp/bridge/handlers/scene_handlers.gd").new(editor_interface)
    _node_handlers = preload("res://addons/godot_mcp/bridge/handlers/node_handlers.gd").new(editor_interface)
    _resource_handlers = preload("res://addons/godot_mcp/bridge/handlers/resource_handlers.gd").new(editor_interface)
    _script_handlers = preload("res://addons/godot_mcp/bridge/handlers/script_handlers.gd").new(editor_interface)
    _signal_handlers = preload("res://addons/godot_mcp/bridge/handlers/signal_handlers.gd").new(editor_interface)
    _project_handlers = preload("res://addons/godot_mcp/bridge/handlers/project_handlers.gd").new(editor_interface)
    _editor_handlers = preload("res://addons/godot_mcp/bridge/handlers/editor_handlers.gd").new(editor_interface)
    _visual_handlers = preload("res://addons/godot_mcp/bridge/handlers/visual_handlers.gd").new(editor_interface, _compatibility)
    _ui_handlers = preload("res://addons/godot_mcp/bridge/handlers/ui_handlers.gd").new(editor_interface)
    _animation_handlers = preload("res://addons/godot_mcp/bridge/handlers/animation_handlers.gd").new(editor_interface)
    _tilemap_handlers = preload("res://addons/godot_mcp/bridge/handlers/tilemap_handlers.gd").new(editor_interface)
    _tileset_handlers = preload("res://addons/godot_mcp/bridge/handlers/tileset_handlers.gd").new(editor_interface)
    _power2d_handlers = preload("res://addons/godot_mcp/bridge/handlers/power2d_handlers.gd").new(editor_interface)
    _power3d_handlers = preload("res://addons/godot_mcp/bridge/handlers/power3d_handlers.gd").new(editor_interface)
    _material3d_handlers = preload("res://addons/godot_mcp/bridge/handlers/material3d_handlers.gd").new(editor_interface)
    _navigation_handlers = preload("res://addons/godot_mcp/bridge/handlers/navigation_handlers.gd").new(editor_interface, _compatibility)

const SerializationBudget = preload("res://addons/godot_mcp/serialization/serialization_budget.gd")
const INPUT_LIMITS = {"depth":64, "items":50000, "bytes":8*1024*1024, "string":1024*1024, "container":50000}

func compatibility_manifest() -> Dictionary:
    return _compatibility.manifest()

func compatibility_core():
    return _compatibility

func _failure(request_id: String, code: String, message: String, details: Dictionary = {}) -> Dictionary:
    var response = {
        "id": request_id if not request_id.is_empty() else "invalid-request",
        "ok": false,
        "error": { "code": code, "message": message }
    }
    if not details.is_empty(): response.error["details"] = details
    return response

func dispatch(raw_text: String) -> Dictionary:
    var parsed = JSON.parse_string(raw_text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return _failure("invalid-request", "INVALID_REQUEST", "Request must be a JSON object")

    var request: Dictionary = parsed
    var request_id := str(request.get("id", ""))
    if request_id.is_empty() or int(request.get("protocol", 0)) != 1:
        return _failure(request_id, "INVALID_REQUEST", "Request id and protocol=1 are required")
    if typeof(request.get("method")) != TYPE_STRING or typeof(request.get("params", {})) != TYPE_DICTIONARY:
        return _failure(request_id, "INVALID_REQUEST", "Request method and params are invalid")

    var method: String = request.method
    var params: Dictionary = request.get("params", {})
    # Bulk requests have the server's bounded envelope; decoded values keep their stricter limits below.
    var input_issue = SerializationBudget.check(params, INPUT_LIMITS)
    if not input_issue.is_empty():
        return _failure(request_id, "ARGUMENT_TOO_LARGE", input_issue, {"applied":false, "limits":INPUT_LIMITS})
    # Validate fields that handlers will decode before any editor mutation.
    for field in ["value", "args", "properties", "binds"]:
        if params.has(field):
            var value_issue = SerializationBudget.check(params[field])
            if not value_issue.is_empty():
                return _failure(request_id, "ARGUMENT_TOO_LARGE", value_issue, {"applied":false, "field":field})
    var result
    match method:
        "geometry.validate_walkways":
            result = _geometry.validate_walkways(params)
        "resource.dependencies":
            result = _dependencies.dependencies(params)
        "resource.impact":
            result = _dependencies.impact(params)
        "editor.import_resources":
            result = await _dependencies.import_resources(params)
        "scene.batch.preview":
            result = _batch.preview(params)
        "scene.batch":
            result = _batch.apply(params)
        "recovery.prepare":
            result = _recovery.prepare(params)
        "recovery.editor_state":
            result = _recovery.editor_state()
        "recovery.validate":
            result = _recovery.validate(params)
        "editor.close_scene":
            result = _recovery.close_scene(params)
        "debugger.info":
            result = _runtime.debugger_info()
        "debugger.breakpoint.set":
            result = _runtime.set_mcp_breakpoint(params)
        "debugger.breakpoint.remove":
            result = _runtime.remove_mcp_breakpoint(params)
        "debugger.dap_sync.begin":
            result = _runtime.begin_dap_sync()
        "debugger.dap_sync.end":
            result = _runtime.end_dap_sync()
        "debugger.step_out":
            result = _runtime.step_out()
        "runtime.status":
            result = _runtime.snapshot()
        "runtime.start":
            result = await _runtime.launch(params)
        "runtime.stop", "project.stop":
            result = await _runtime.stop_run()
        "runtime.scene_tree", "runtime.inspect_node", "runtime.get_property", "runtime.pause", "runtime.resume", "debug.performance", "visual.capture_game":
            result = await _runtime.forward(method,params)
        "visual.capture_viewport_2d":
            result = await _visual_handlers.handle_capture_viewport_2d(params)
        "visual.capture_viewport_3d":
            result = await _visual_handlers.handle_capture_viewport_3d(params)
        "animation.list":
            result = _animation_handlers.list(params)
        "animation.inspect":
            result = _animation_handlers.inspect(params)
        "animation.create":
            result = _animation_handlers.create(params)
        "animation.remove":
            result = _animation_handlers.remove(params)
        "animation.configure":
            result = _animation_handlers.configure(params)
        "animation.add_track":
            result = _animation_handlers.add_track(params)
        "animation.insert_key":
            result = _animation_handlers.insert_key(params)
        "animation.remove_key":
            result = _animation_handlers.remove_key(params)
        "tilemap.inspect":
            result = _tilemap_handlers.inspect(params)
        "tilemap.get_cells":
            result = _tilemap_handlers.get_cells(params)
        "tilemap.set_cell":
            result = _tilemap_handlers.set_cell(params)
        "tilemap.set_cells":
            result = _tilemap_handlers.set_cells(params)
        "tilemap.erase_cells":
            result = _tilemap_handlers.erase_cells(params)
        "tilemap.clear":
            result = _tilemap_handlers.clear(params)
        "tilemap.map_to_local":
            result = _tilemap_handlers.map_to_local(params)
        "tilemap.local_to_map":
            result = _tilemap_handlers.local_to_map(params)
        "tileset.inspect":
            result = _tileset_handlers.inspect(params)
        "tileset.ensure_for_layer":
            result = _tileset_handlers.ensure_for_layer(params)
        "tileset.add_atlas_source":
            result = _tileset_handlers.add_atlas_source(params)
        "tileset.inspect_atlas_source":
            result = _tileset_handlers.inspect_atlas_source(params)
        "tileset.create_atlas_tiles":
            result = _tileset_handlers.create_atlas_tiles(params)
        "tileset.remove_source":
            result = _tileset_handlers.remove_source(params)
        "node2d.inspect_transform":
            result = _power2d_handlers.inspect_node2d_transform(params)
        "node2d.set_transform":
            result = _power2d_handlers.set_node2d_transform(params)
        "sprite2d.inspect":
            result = _power2d_handlers.inspect_sprite2d(params)
        "sprite2d.set_texture":
            result = _power2d_handlers.set_sprite2d_texture(params)
        "sprite2d.configure":
            result = _power2d_handlers.configure_sprite2d(params)
        "camera2d.inspect":
            result = _power2d_handlers.inspect_camera2d(params)
        "camera2d.configure":
            result = _power2d_handlers.configure_camera2d(params)
        "collision2d.inspect":
            result = _power2d_handlers.inspect_collision2d(params)
        "collision2d.set_shape":
            result = _power2d_handlers.set_collision2d_shape(params)
        "parallax2d.inspect":
            result = _power2d_handlers.inspect_parallax2d(params)
        "parallax2d.configure":
            result = _power2d_handlers.configure_parallax2d(params)
        "node3d.inspect_transform":
            result = _power3d_handlers.inspect_node3d_transform(params)
        "node3d.set_transform":
            result = _power3d_handlers.set_node3d_transform(params)
        "mesh3d.inspect":
            result = _power3d_handlers.inspect_mesh3d(params)
        "mesh3d.set_primitive":
            result = _power3d_handlers.set_mesh3d_primitive(params)
        "camera3d.inspect":
            result = _power3d_handlers.inspect_camera3d(params)
        "camera3d.configure":
            result = _power3d_handlers.configure_camera3d(params)
        "collision3d.inspect":
            result = _power3d_handlers.inspect_collision3d(params)
        "collision3d.set_shape":
            result = _power3d_handlers.set_collision3d_shape(params)
        "light3d.inspect":
            result = _power3d_handlers.inspect_light3d(params)
        "light3d.configure":
            result = _power3d_handlers.configure_light3d(params)
        "navigation.region.inspect":
            result = _navigation_handlers.inspect_region(params)
        "navigation.region.configure":
            result = _navigation_handlers.configure_region(params)
        "navigation.mesh.inspect":
            result = _navigation_handlers.inspect_mesh(params)
        "navigation.mesh.set":
            result = _navigation_handlers.set_mesh(params)
        "navigation.mesh.configure":
            result = _navigation_handlers.configure_mesh(params)
        "navigation.mesh.set_outlines":
            result = _navigation_handlers.set_outlines(params)
        "navigation.mesh.bake":
            result = _navigation_handlers.bake_mesh(params)
        "navigation.mesh.clear":
            result = _navigation_handlers.clear_mesh(params)
        "navigation.agent.inspect":
            result = _navigation_handlers.inspect_agent(params)
        "navigation.agent.configure":
            result = _navigation_handlers.configure_agent(params)
        "material3d.inspect":
            result = _material3d_handlers.inspect_material3d(params)
        "material3d.set_standard":
            result = _material3d_handlers.set_standard_material3d(params)
        "material3d.configure_standard":
            result = _material3d_handlers.configure_standard_material3d(params)
        "material3d.clear":
            result = _material3d_handlers.clear_material3d(params)
        "shader3d.inspect":
            result = _material3d_handlers.inspect_shader3d(params)
        "shader3d.set_code":
            result = _material3d_handlers.set_shader3d_code(params)
        "shader3d.set_parameter":
            result = _material3d_handlers.set_shader3d_parameter(params)
        "ui.inspect_layout":
            result = _ui_handlers.inspect_layout(params)
        "ui.set_layout_preset":
            result = _ui_handlers.set_layout_preset(params)
        "ui.set_anchors":
            result = _ui_handlers.set_anchors(params)
        "ui.set_offsets":
            result = _ui_handlers.set_offsets(params)
        "ui.set_size_flags":
            result = _ui_handlers.set_size_flags(params)
        "ui.set_focus_neighbor":
            result = _ui_handlers.set_focus_neighbor(params)
        "project.info":
            result = _project_info.run(params)
        "scene.get_tree":
            result = _scene_tree.run(params)
        "object.get_class":
            result = _object_handlers.handle_get_class(params)
        "object.get_property_list":
            result = _object_handlers.handle_get_property_list(params)
        "object.get_method_list":
            result = _object_handlers.handle_get_method_list(params)
        "object.get_signal_list":
            result = _object_handlers.handle_get_signal_list(params)
        "object.get":
            result = _object_handlers.get_property(params)
        "object.set":
            result = _object_handlers.set_property(params)
        "object.call":
            result = _object_handlers.call_method(params)
        "scene.create":
            result = _scene_handlers.create(params)
        "scene.open":
            result = _scene_handlers.open(params)
        "scene.save":
            result = _scene_handlers.save(params)
        "scene.save_as":
            result = _scene_handlers.save_as(params)
        "scene.reload":
            result = _scene_handlers.reload(params)
        "scene.instantiate":
            result = _scene_handlers.instantiate(params)
        "scene.get_root":
            result = _scene_handlers.get_root(params)
        "node.create":
            result = _node_handlers.create(params)
        "node.delete":
            result = _node_handlers.delete(params)
        "node.duplicate":
            result = _node_handlers.duplicate(params)
        "node.rename":
            result = _node_handlers.rename(params)
        "node.reparent":
            result = _node_handlers.reparent(params)
        "node.move":
            result = _node_handlers.move(params)
        "node.inspect":
            result = _node_handlers.inspect(params)
        "node.list_children":
            result = _node_handlers.list_children(params)
        "node.get_property":
            result = _node_handlers.get_property(params)
        "node.set_property":
            result = _node_handlers.set_property(params)
        "node.get_properties":
            result = _node_handlers.get_properties(params)
        "resource.load":
            result = _resource_handlers.load_resource(params)
        "resource.inspect":
            result = _resource_handlers.inspect(params)
        "resource.create":
            result = _resource_handlers.create(params)
        "resource.set_property":
            result = _resource_handlers.set_property(params)
        "resource.save":
            result = _resource_handlers.save(params)
        "resource.duplicate":
            result = _resource_handlers.duplicate(params)
        "script.create":
            result = _script_handlers.create(params)
        "script.attach":
            result = _script_handlers.attach(params)
        "script.detach":
            result = _script_handlers.detach(params)
        "script.inspect":
            result = _script_handlers.inspect(params)
        "script.validate":
            result = _script_handlers.validate(params)
        "signal.list":
            result = _signal_handlers.list(params)
        "signal.connections":
            result = _signal_handlers.connections(params)
        "signal.connect":
            result = _signal_handlers.connect_signal(params)
        "signal.disconnect":
            result = _signal_handlers.disconnect_signal(params)
        "project.settings.get":
            result = _project_handlers.get_setting(params)
        "project.settings.set":
            result = _project_handlers.set_setting(params)
        "project.input.list":
            result = _project_handlers.list_input_actions(params)
        "project.input.add_action":
            result = _project_handlers.add_input_action(params)
        "project.input.remove_action":
            result = _project_handlers.remove_input_action(params)
        "editor.get_active_scene":
            result = _editor_handlers.get_active_scene(params)
        "editor.get_open_scenes":
            result = _editor_handlers.get_open_scenes(params)
        "editor.get_selected_nodes":
            result = _editor_handlers.get_selected_nodes(params)
        "editor.select_node":
            result = _editor_handlers.select_node(params)
        "editor.change_scene":
            result = _editor_handlers.change_scene(params)
        "editor.undo":
            result = _editor_handlers.undo(params)
        "editor.redo":
            result = _editor_handlers.redo(params)
        "editor.get_filesystem":
            result = _editor_handlers.get_filesystem(params)
        "editor.scan_filesystem":
            result = _editor_handlers.scan_filesystem(params)
        _:
            return _failure(request_id, "METHOD_NOT_FOUND", "Unknown method: %s" % method)

    if typeof(result) == TYPE_DICTIONARY and result.has("__error"):
        var err: Dictionary = result["__error"]
        return _failure(request_id, str(err.get("code", "INTERNAL_ERROR")), str(err.get("message", "Error occurred")), err.get("details",{}))

    # PNG/base64 responses have separate pixel, byte and checksum bounds.
    if not method.begins_with("visual.capture_"):
        var issue = SerializationBudget.check(result, {"depth":80, "items":30000, "bytes":4*1024*1024, "container":10000})
        if not issue.is_empty():
            return _failure(request_id, "RESULT_TOO_LARGE", issue)

    return { "id": request_id, "ok": true, "result": result }
