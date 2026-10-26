extends Node
var _run_id := ""
var _session_id := ""
var _ready_sent := false
var _logger
var _handlers
var _hello_elapsed := 1.0
var _log_elapsed := 0.0
var _enabled := false
var _capture_handler = preload("res://addons/godot_mcp/runtime/runtime_capture.gd").new()

func _enter_tree() -> void:
    if Engine.is_editor_hint() or not EngineDebugger.is_active():
        set_process(false)
        return
    process_mode = Node.PROCESS_MODE_ALWAYS
    _enabled = true
    _handlers = preload("res://addons/godot_mcp/runtime/runtime_handlers.gd").new(get_tree(),self)
    if ClassDB.class_exists("Logger") and OS.has_method("add_logger") and FileAccess.file_exists("res://.godot-mcp/generated/runtime_logger.gd"):
        var script = load("res://.godot-mcp/generated/runtime_logger.gd")
        if script != null and script.can_instantiate():
            _logger = script.new()
            OS.call("add_logger",_logger)
    EngineDebugger.register_message_capture("godot_mcp",_capture)
    set_process(true)

func features() -> Dictionary:
    return {"inspect":true,"scenePause":true,"gameCapture":DisplayServer.get_name()!="headless","diagnostics":_logger!=null,"performance":true}
func status() -> Dictionary:
    return {"state":"paused" if get_tree().paused else "running","runId":_run_id,
        "scenePath":get_tree().current_scene.scene_file_path if get_tree().current_scene else null,
        "connected":true,"ownership":"session","features":features(),"errorCode":null}
func _process(delta: float) -> void:
    if not _enabled:
        return
    if _run_id.is_empty():
        _hello_elapsed += delta
        if _hello_elapsed >= 1.0:
            _hello_elapsed = 0.0
            EngineDebugger.send_message("godot_mcp:hello",[{"protocol":1}])
        return
    if not _ready_sent and get_tree().current_scene != null:
        _ready_sent = true
        EngineDebugger.send_message("godot_mcp:ready",[{"runId":_run_id,"mcpSessionId":_session_id,"status":status()}])
    _log_elapsed += delta
    if _ready_sent and _log_elapsed >= 0.05:
        _log_elapsed = 0.0
        _drain_logs()
func _drain_logs() -> void:
    if _logger == null:
        return
    var batch: Dictionary = _logger.drain()
    if batch.entries.is_empty() and batch.dropped == 0:
        return
    batch["runId"] = _run_id
    for entry in batch.entries:
        entry["runId"] = _run_id
    EngineDebugger.send_message("godot_mcp:diagnostics",[{"mcpSessionId":_session_id,"batch":batch}])
func _capture(message: String, data: Array) -> bool:
    if data.size() != 1 or not data[0] is Dictionary:
        return false
    var packet: Dictionary = data[0]
    if message == "bind" and _run_id.is_empty():
        if str(packet.get("runId","")).length() != 36 or str(packet.get("mcpSessionId","")).is_empty():
            return false
        _run_id = packet.runId
        _session_id = packet.mcpSessionId
        return true
    if message != "request" or not _ready_sent or packet.get("runId") != _run_id or packet.get("mcpSessionId") != _session_id:
        return false
    _serve.call_deferred(packet)
    return true
func _serve(packet: Dictionary) -> void:
    var method := str(packet.get("method",""))
    var params: Dictionary = packet.get("params",{})
    var result: Dictionary
    if method == "visual.capture_game":
        result = await _capture_handler.send_capture(self,packet)
        if result.is_empty():
            return
    else:
        result = _handlers.run(method,params)
    if method == "runtime.pause" or method == "runtime.resume":
        result = status()
    if JSON.stringify(result).to_utf8_buffer().size()>256*1024:
        result = {"__error":{"code":"RESULT_TOO_LARGE","message":"Runtime response exceeds 256 KiB"}}
    var response := {"runId":_run_id,"mcpSessionId":_session_id,"requestId":packet.get("requestId",""),"ok":not result.has("__error")}
    if result.has("__error"):
        response["error"] = result.__error
    else:
        result["runId"] = _run_id
        response["result"] = result
    EngineDebugger.send_message("godot_mcp:response",[response])
func _exit_tree() -> void:
    if not _enabled:
        return
    if _ready_sent:
        _drain_logs()
    if _logger != null:
        OS.call("remove_logger",_logger)
    if EngineDebugger.has_capture("godot_mcp"):
        EngineDebugger.unregister_message_capture("godot_mcp")
