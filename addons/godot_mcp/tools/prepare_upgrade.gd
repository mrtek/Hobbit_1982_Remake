extends SceneTree

func _init() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 3:
        printerr("GODOT_MCP_UPGRADE_ARGUMENTS")
        quit(1)
        return
    var runtime_path := "*res://addons/godot_mcp/runtime/runtime_agent.gd"
    var existing := str(ProjectSettings.get_setting("autoload/GodotMcpRuntime", ""))
    if not existing.is_empty() and existing != runtime_path:
        printerr("AUTOLOAD_NAME_CONFLICT")
        quit(1)
        return
    ProjectSettings.set_setting("autoload/GodotMcpRuntime", runtime_path)
    var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
    if not enabled.has("res://addons/godot_mcp/plugin.cfg"):
        enabled.append("res://addons/godot_mcp/plugin.cfg")
    ProjectSettings.set_setting("editor_plugins/enabled", enabled)
    if ProjectSettings.save_custom(args[0]) != OK:
        printerr("GODOT_MCP_UPGRADE_SETTINGS_FAILED")
        quit(1)
        return
    if ClassDB.class_exists("Logger") and OS.has_method("add_logger") and Engine.get_version_info().minor >= 6:
        var source := FileAccess.get_file_as_string(args[2])
        var output := FileAccess.open(args[1], FileAccess.WRITE)
        if source.is_empty() or output == null:
            printerr("GODOT_MCP_UPGRADE_LOGGER_FAILED")
            quit(1)
            return
        output.store_string(source)
        output.close()
    print("GODOT_MCP_UPGRADE_PREPARED")
    quit(0)
