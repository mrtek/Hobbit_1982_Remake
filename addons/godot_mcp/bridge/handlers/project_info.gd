@tool
extends RefCounted

var _editor_interface

func _init(editor_interface) -> void:
    _editor_interface = editor_interface

func run(_params: Dictionary) -> Dictionary:
    var root: Node = _editor_interface.get_edited_scene_root()
    return {
        "name": str(ProjectSettings.get_setting("application/config/name", "")),
        "projectRoot": ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/"),
        "projectFile": ProjectSettings.globalize_path("res://project.godot").replace("\\", "/"),
        "godotVersion": Engine.get_version_info().string,
        "activeScene": root.scene_file_path if root else null
    }
