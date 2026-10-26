@tool
extends RefCounted

const MAX_PNG_BYTES := 16 * 1024 * 1024
const VIEWPORT2D_CAPABILITY := "visual.viewport2d.capture"
const VIEWPORT3D_CAPABILITY := "visual.viewport3d.capture"

var _editor_interface
var _compatibility

class FrameWait:
    extends RefCounted
    signal completed(drawn: bool)
    var done := false
    var frames := 0
    var timer: SceneTreeTimer
    var scene_tree: SceneTree

    func start(tree: SceneTree) -> void:
        scene_tree = tree
        timer = tree.create_timer(2.0)
        timer.timeout.connect(_timeout)
        RenderingServer.frame_post_draw.connect(_drawn)
        tree.process_frame.connect(_request_draw)

    func _request_draw() -> void:
        # An idle/occluded editor can stop drawing while it continues processing.
        # Request native rendering on the main thread, without changing scene state.
        RenderingServer.force_draw(false)

    func _drawn() -> void:
        frames += 1
        # The first frame may still contain the previous editor tab.
        if frames >= 2:
            _finish(true)

    func _timeout() -> void:
        _finish(false)

    func _finish(drawn: bool) -> void:
        if done:
            return
        done = true
        if scene_tree.process_frame.is_connected(_request_draw):
            scene_tree.process_frame.disconnect(_request_draw)
        if RenderingServer.frame_post_draw.is_connected(_drawn):
            RenderingServer.frame_post_draw.disconnect(_drawn)
        if timer.timeout.is_connected(_timeout):
            timer.timeout.disconnect(_timeout)
        completed.emit(drawn)

func _init(editor_interface, compatibility) -> void:
    _editor_interface = editor_interface
    _compatibility = compatibility

func _error(code: String, message: String) -> Dictionary:
    return {"__error": {"code": code, "message": message}}

func handle_capture_viewport_2d(params: Dictionary) -> Dictionary:
    if not params.is_empty():
        return _error("INVALID_REQUEST", "2D capture does not accept bridge parameters")
    return await _capture(false, 0)

func handle_capture_viewport_3d(params: Dictionary) -> Dictionary:
    for key in params:
        if key != "viewport_index":
            return _error("INVALID_REQUEST", "Unknown capture parameter")
    var index = params.get("viewport_index", 0)
    if (typeof(index) != TYPE_INT and typeof(index) != TYPE_FLOAT) or float(index) != floor(float(index)) or index < 0 or index > 3:
        return _error("INVALID_REQUEST", "viewport_index must be an integer from 0 to 3")
    return await _capture(true, int(index))

func _capture(is_3d: bool, index: int) -> Dictionary:
    var capability_id := VIEWPORT3D_CAPABILITY if is_3d else VIEWPORT2D_CAPABILITY
    if not _compatibility.supports(capability_id):
        return _error("CAPTURE_UNSUPPORTED", _compatibility.reason(capability_id))
    var method := "get_editor_viewport_3d" if is_3d else "get_editor_viewport_2d"
    var root = _editor_interface.get_edited_scene_root()
    if root == null:
        return _error("NO_OPEN_SCENE", "No edited scene is open")
    _editor_interface.set_main_screen_editor("3D" if is_3d else "2D")
    var viewport = _editor_interface.call(method, index) if is_3d else _editor_interface.call(method)
    if viewport == null:
        return _error("VIEWPORT_UNAVAILABLE", "Requested editor viewport is unavailable")
    var waiter := FrameWait.new()
    waiter.start(_editor_interface.get_base_control().get_tree())
    var drawn: bool = await waiter.completed
    if not drawn:
        return _error("CAPTURE_TIMEOUT", "Editor render deadline exceeded")
    if not is_instance_valid(viewport) or not is_instance_valid(root) or root != _editor_interface.get_edited_scene_root():
        return _error("CAPTURE_FAILED", "Edited scene changed during capture")
    var container = viewport.get_parent()
    if container is Control and not container.is_visible_in_tree():
        return _error("VIEWPORT_UNAVAILABLE", "Requested editor viewport is hidden")
    if viewport.size.x <= 0 or viewport.size.y <= 0:
        return _error("VIEWPORT_UNAVAILABLE", "Requested editor viewport is empty")
    if viewport.size.x > 4096 or viewport.size.y > 4096:
        return _error("CAPTURE_TOO_LARGE", "Viewport exceeds 4096 pixels per axis")
    var texture = viewport.get_texture()
    if texture == null:
        return _error("CAPTURE_FAILED", "Viewport has no texture")
    var image: Image = texture.get_image()
    if image == null or image.is_empty():
        return _error("CAPTURE_FAILED", "Viewport returned an empty image")
    image.convert(Image.FORMAT_RGBA8)
    var png: PackedByteArray = image.save_png_to_buffer()
    if png.is_empty():
        return _error("CAPTURE_FAILED", "PNG encoding failed")
    if png.size() > MAX_PNG_BYTES:
        return _error("CAPTURE_TOO_LARGE", "PNG exceeds 16 MiB")
    return {"png_base64": Marshalls.raw_to_base64(png), "width": image.get_width(), "height": image.get_height(),
        "scene": root.scene_file_path if not root.scene_file_path.is_empty() else null,
        "captured_at": Time.get_datetime_string_from_system(true) + "Z",
        "viewport_index": index if is_3d else null}
