@tool
extends RefCounted

const Budget = preload("res://addons/godot_mcp/serialization/serialization_budget.gd")

static func begin() -> Dictionary:
    if not ClassDB.class_exists("Logger") or not OS.has_method("add_logger"):
        return {"available":false}
    var source := FileAccess.get_file_as_string("res://addons/godot_mcp/runtime/runtime_logger_46.gd.txt")
    if source.is_empty(): return {"available":false}
    var script := GDScript.new()
    script.source_code = "@tool\n" + source
    if script.reload() != OK: return {"available":false}
    var logger = script.new()
    OS.call("add_logger", logger)
    return {"available":true,"logger":logger}

static func finish(scope: Dictionary) -> Dictionary:
    if not scope.get("available",false): return {"available":false,"entries":[],"dropped":0}
    OS.call("remove_logger",scope.logger)
    var entries: Array = []
    var dropped := 0
    for _page in range(10):
        var batch: Dictionary = scope.logger.drain()
        dropped = maxi(dropped,int(batch.dropped))
        if batch.entries.is_empty(): break
        for entry in batch.entries:
            if entries.size() < 50: entries.append(entry)
            else: dropped += 1
    var result := {"available":true,"entries":entries,"dropped":dropped}
    while not Budget.check(result,{"bytes":192*1024}).is_empty() and not entries.is_empty():
        entries.pop_back()
        result.dropped += 1
    return result
