@tool
extends RefCounted
var _editor
func _init(editor_interface) -> void:
    _editor = editor_interface
func _error(code: String, message: String) -> Dictionary:
    return {"__error":{"code":code,"message":message}}
func editor_state() -> Dictionary:
    var root = _editor.get_edited_scene_root()
    if root == null:
        return {"path":null,"instanceId":null,"version":0,"safeCloseSupported":true}
    var manager = _editor.get_editor_undo_redo()
    var history = manager.get_history_undo_redo(manager.get_object_history_id(root))
    return {"path":root.scene_file_path if not root.scene_file_path.is_empty() else null,"instanceId":str(root.get_instance_id()),"version":history.get_version() if history else 0,"safeCloseSupported":true}
func prepare(params: Dictionary) -> Dictionary:
    var paths: Array = params.get("paths",[])
    if _editor.is_playing_scene():
        return _error("RUNTIME_ACTIVE","Stop the game before file recovery")
    if not _editor.get_open_scenes().is_empty():
        return _error("EDITOR_STATE_CONFLICT","Close scene tabs before file publication; dependencies may be shared with other scenes")
    paths = paths.map(func(value): return str(value).to_lower())
    for scene in _editor.get_open_scenes():
        if paths.has(str(scene).to_lower()):
            return _error("EDITOR_STATE_CONFLICT","Close affected scene tabs before file publication or recovery: "+str(scene))
    for script in _editor.get_script_editor().get_open_scripts():
        if paths.has(script.resource_path.to_lower()):
            return _error("EDITOR_STATE_CONFLICT","Close affected script tabs before file publication or recovery")
    var edited = _editor.get_inspector().get_edited_object()
    if edited is Resource and paths.has(edited.resource_path.to_lower()):
        return _error("EDITOR_STATE_CONFLICT","Close the affected resource inspector before file recovery")
    return {"ready":true}
func validate(params: Dictionary) -> Dictionary:
    var errors: Array = []
    for value in params.get("paths",[]):
        var path := str(value)
        if not path.begins_with("res://") or path.contains("..") or path.contains("\\"):
            errors.append("Invalid project path")
            continue
        if path.ends_with(".gd"):
            var script = ResourceLoader.load(path,"GDScript",ResourceLoader.CACHE_MODE_IGNORE)
            if not script is GDScript or script.reload()!=OK:
                errors.append("GDScript compilation failed: "+path)
        elif path.ends_with(".tscn") or path.ends_with(".tres"):
            var resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
            if resource == null or (path.ends_with(".tscn") and not resource is PackedScene):
                errors.append("Resource validation failed: "+path)
        else:
            errors.append("Unsupported validation type: "+path)
    return {"valid":errors.is_empty(),"errors":errors}
func close_scene(params: Dictionary = {}) -> Dictionary:
    if not _editor.has_method("close_scene"):
        return _error("CAPABILITY_UNAVAILABLE","This editor cannot close scenes through the public API")
    if typeof(params.get("discard_changes", false)) != TYPE_BOOL:
        return _error("INVALID_ARGUMENT","discard_changes must be a boolean")
    var root = _editor.get_edited_scene_root()
    if root == null:
        return {"closed":false,"saved":false}
    var discard: bool = params.get("discard_changes", false)
    if not discard:
        if root.scene_file_path.is_empty():
            return _error("SCENE_SAVE_REQUIRED","Save this unnamed scene with scene.save_as before closing, or explicitly request discard_changes")
        if not _editor.has_method("save_scene"):
            return _error("CAPABILITY_UNAVAILABLE","This editor cannot save scenes; the scene was not closed")
        var save_error: int = _editor.call("save_scene")
        if save_error != OK:
            return _error("SCENE_SAVE_FAILED","Scene was not closed because saving failed (error %d)" % save_error)
    # Godot's public close_scene API discards changes, so saving must succeed first.
    var error: int = _editor.call("close_scene")
    return {"closed":true,"saved":not discard} if error==OK else _error("EDITOR_CLOSE_FAILED","Unable to close scene")
