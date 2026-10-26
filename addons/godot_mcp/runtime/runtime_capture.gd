extends RefCounted
var _busy := false
func send_capture(agent: Node, packet: Dictionary) -> Dictionary:
    if _busy:
        return {"__error":{"code":"BUSY","message":"A game capture is already active"}}
    if DisplayServer.get_name()=="headless":
        return {"__error":{"code":"CAPTURE_UNSUPPORTED","message":"Game has no graphical renderer"}}
    _busy = true
    var result: Dictionary = await _capture(agent,packet)
    _busy = false
    return result

func _error(code: String, message: String) -> Dictionary:
    return {"__error":{"code":code,"message":message}}

func _requested_framing(params: Dictionary) -> Dictionary:
    if not params.has("framing"):
        return {}
    var framing = params.framing
    if typeof(framing) != TYPE_DICTIONARY or framing.size() != 2 or not framing.has("center") or not framing.has("zoom"):
        return _error("INVALID_ARGUMENT","Framing requires center and zoom")
    var center = framing.center
    var zoom = framing.zoom
    if typeof(center) != TYPE_DICTIONARY or typeof(zoom) != TYPE_DICTIONARY or center.size() != 2 or zoom.size() != 2:
        return _error("INVALID_ARGUMENT","Framing center and zoom require x/y")
    for value in [center.get("x"),center.get("y"),zoom.get("x"),zoom.get("y")]:
        if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):
            return _error("INVALID_ARGUMENT","Framing coordinates must be finite numbers")
    var position := Vector2(float(center.x),float(center.y))
    var scale := Vector2(float(zoom.x),float(zoom.y))
    if abs(position.x)>10000000.0 or abs(position.y)>10000000.0 or scale.x<0.05 or scale.y<0.05 or scale.x>64.0 or scale.y>64.0:
        return _error("INVALID_ARGUMENT","Framing center or zoom is outside limits")
    return {"center":position,"zoom":scale,"public":{"center":{"x":position.x,"y":position.y},"zoom":{"x":scale.x,"y":scale.y}}}

func _frame_image(agent: Node, viewport: Viewport, scene: Node) -> Dictionary:
    if viewport.size.x>4096 or viewport.size.y>4096:
        return _error("CAPTURE_TOO_LARGE","Game viewport exceeds image bounds")
    var waiter = preload("res://addons/godot_mcp/bridge/handlers/visual_handlers.gd").FrameWait.new()
    waiter.start(agent.get_tree())
    var drawn: bool = await waiter.completed
    if not drawn:
        return _error("CAPTURE_TIMEOUT","Game render deadline exceeded")
    if not is_instance_valid(scene) or scene!=agent.get_tree().current_scene:
        return _error("CAPTURE_FAILED","Game scene changed during capture")
    var image := viewport.get_texture().get_image()
    if image==null or image.is_empty():
        return _error("CAPTURE_FAILED","Game returned an empty viewport")
    return {"image":image}

func _capture(agent: Node, packet: Dictionary) -> Dictionary:
    var viewport := agent.get_tree().root
    var scene := agent.get_tree().current_scene
    if scene == null:
        return _error("NO_OPEN_SCENE","Game has no active scene")
    var requested := _requested_framing(packet.get("params",{}))
    if requested.has("__error"):
        return requested
    var previous_camera: Camera2D = viewport.get_camera_2d()
    var temporary_camera: Camera2D = null
    if requested.has("center"):
        temporary_camera = Camera2D.new()
        temporary_camera.name = "GodotMcpCaptureCamera"
        temporary_camera.process_mode = Node.PROCESS_MODE_ALWAYS
        temporary_camera.zoom = requested.zoom
        viewport.add_child(temporary_camera)
        temporary_camera.global_position = requested.center
        temporary_camera.make_current()
        temporary_camera.force_update_scroll()
    var frame: Dictionary = await _frame_image(agent,viewport,scene)
    if temporary_camera != null:
        if is_instance_valid(previous_camera) and previous_camera.is_inside_tree():
            previous_camera.make_current()
        temporary_camera.free()
    if frame.has("__error"):
        return frame
    var image: Image = frame.image
    image.convert(Image.FORMAT_RGBA8)
    var bytes := image.save_png_to_buffer()
    if bytes.is_empty() or bytes.size()>16*1024*1024:
        return {"__error":{"code":"CAPTURE_TOO_LARGE","message":"Game PNG exceeds byte limit"}}
    var encoded := Marshalls.raw_to_base64(bytes)
    var hashing := HashingContext.new()
    hashing.start(HashingContext.HASH_SHA256)
    hashing.update(bytes)
    var capture_id := str(packet.runId)+"_"+str(packet.requestId)
    var common := {"mcpSessionId":packet.mcpSessionId,"runId":packet.runId,"requestId":packet.requestId,"captureId":capture_id}
    var meta := common.duplicate()
    meta.merge({"width":image.get_width(),"height":image.get_height(),"scene":scene.scene_file_path,"captured_at":Time.get_datetime_string_from_system(true)+"Z","totalBytes":bytes.size(),"totalChunks":int(ceil(encoded.length()/65536.0)),"sha256":hashing.finish().hex_encode(),"framing":requested.get("public")})
    EngineDebugger.send_message("godot_mcp:capture_begin",[meta])
    for index in range(meta.totalChunks):
        var chunk := common.duplicate()
        chunk.merge({"index":index,"data":encoded.substr(index*65536,65536)})
        EngineDebugger.send_message("godot_mcp:capture_chunk",[chunk])
        if index%4==3:
            await agent.get_tree().process_frame
    EngineDebugger.send_message("godot_mcp:capture_end",[common])
    return {}
