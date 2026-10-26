extends SceneTree

const PLUGIN_PATH := "res://addons/godot_mcp/plugin.cfg"

func _init() -> void:
    var runtime_path := "*res://addons/godot_mcp/runtime/runtime_agent.gd"
    var existing := str(ProjectSettings.get_setting("autoload/GodotMcpRuntime",""))
    if not existing.is_empty() and existing != runtime_path:
        printerr("AUTOLOAD_NAME_CONFLICT")
        quit(1)
        return
    if ClassDB.class_exists("Logger") and OS.has_method("add_logger") and Engine.get_version_info().minor >= 6:
        var generated := "res://.godot-mcp/generated"
        if DirAccess.make_dir_recursive_absolute(generated) != OK:
            quit(1)
            return
        var source := FileAccess.get_file_as_string("res://addons/godot_mcp/runtime/runtime_logger_46.gd.txt")
        var output := FileAccess.open(generated+"/runtime_logger.gd",FileAccess.WRITE)
        if output == null or source.is_empty():
            quit(1)
            return
        output.store_string(source)
        output.close()
    ProjectSettings.set_setting("autoload/GodotMcpRuntime",runtime_path)
    var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
    if not enabled.has(PLUGIN_PATH):
        enabled.append(PLUGIN_PATH)
        ProjectSettings.set_setting("editor_plugins/enabled", enabled)
    var save_error := ProjectSettings.save()
    if save_error != OK:
        printerr("GODOT_MCP_PLUGIN_ENABLE_FAILED:%d" % save_error)
        quit(1)
        return
    print("GODOT_MCP_PLUGIN_ENABLED")
    quit(0)
