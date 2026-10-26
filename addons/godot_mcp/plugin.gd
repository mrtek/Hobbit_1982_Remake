@tool
extends EditorPlugin

var _bridge: Node = null
var _debugger = null

func _enter_tree() -> void:
    if OS.get_environment("GODOT_MCP_HEADLESS_CHILD") == "1":
        return
    _debugger = preload("res://addons/godot_mcp/debugger/editor_debugger.gd").new()
    _debugger.configure(EditorInterface)
    add_debugger_plugin(_debugger)
    _bridge = preload("res://addons/godot_mcp/bridge/bridge_client.gd").new()
    add_child(_bridge)
    _bridge.start(EditorInterface,_debugger)
    scene_changed.connect(_project_scene_changed)
    scene_saved.connect(_project_scene_saved)
    var filesystem = EditorInterface.get_resource_filesystem()
    filesystem.filesystem_changed.connect(_project_filesystem_changed)
    filesystem.resources_reimported.connect(_project_reimported)

func _project_scene_changed(scene: Node) -> void:
    if is_instance_valid(_bridge):
        _bridge.queue_project_event("scene.changed", scene.scene_file_path if scene else null)

func _project_scene_saved(path_value: String) -> void:
    if is_instance_valid(_bridge):
        _bridge.queue_project_event("scene.saved", path_value)

func _project_filesystem_changed() -> void:
    if is_instance_valid(_bridge):
        _bridge.queue_project_event("filesystem.changed")

func _project_reimported(_paths: PackedStringArray) -> void:
    if is_instance_valid(_bridge):
        _bridge.queue_project_event("import.finished")

func _exit_tree() -> void:
    if is_instance_valid(_bridge):
        _bridge.stop()
        _bridge.queue_free()
    if _debugger != null:
        remove_debugger_plugin(_debugger)
