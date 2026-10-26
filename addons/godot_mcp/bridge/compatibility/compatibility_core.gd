@tool
extends RefCounted

const STATUS_SUPPORTED := "supported"
const STATUS_RESTRICTED := "restricted"
const STATUS_UNSUPPORTED := "unsupported"

const KEEP_Y_CAPABILITY := "navigation.agent3d.keep_y_velocity"
const KEEP_Y_QUIRK := "navigation.agent3d.keep_y_velocity.hidden_with_3d_avoidance"

var _probe
var _quirks
var _manifest: Dictionary

func _init(editor_interface) -> void:
    _probe = preload("res://addons/godot_mcp/bridge/compatibility/feature_probe.gd").new(editor_interface)
    var engine := _engine_version()
    _quirks = preload("res://addons/godot_mcp/bridge/compatibility/quirk_registry.gd").new(engine, _probe)
    _manifest = {
        "schemaVersion": 1,
        "engine": engine,
        "capabilities": _build_capabilities(),
        "quirks": _quirks.manifest()
    }

func _engine_version() -> Dictionary:
    var info := Engine.get_version_info()
    return {
        "major": int(info.get("major", 0)),
        "minor": int(info.get("minor", 0)),
        "patch": int(info.get("patch", 0)),
        "status": str(info.get("status", "")),
        "build": str(info.get("build", "")),
        "hash": str(info.get("hash", "")),
        "string": str(info.get("string", "unknown"))
    }

func _entry(status_value: String, reason: String = "") -> Dictionary:
    var entry := {"status": status_value}
    if not reason.is_empty():
        entry.reason = reason
    return entry

func _class_capability(godot_class: String) -> Dictionary:
    if _probe.class_exists(godot_class):
        return _entry(STATUS_SUPPORTED)
    return _entry(STATUS_UNSUPPORTED, "%s is unavailable in this Godot build" % godot_class)

func _bake_capability(dimension: String) -> Dictionary:
    var resource_class := "NavigationPolygon" if dimension == "2d" else "NavigationMesh"
    var server_class := "NavigationServer2D" if dimension == "2d" else "NavigationServer3D"
    if not _probe.class_exists(resource_class):
        return _entry(STATUS_UNSUPPORTED, "%s is unavailable in this Godot build" % resource_class)
    for method_name in ["parse_source_geometry_data", "bake_from_source_geometry_data"]:
        if not _probe.class_has_method(server_class, method_name):
            return _entry(STATUS_UNSUPPORTED, "%s.%s is unavailable in this Godot build" % [server_class, method_name])
    return _entry(STATUS_SUPPORTED)

func _keep_y_velocity_capability() -> Dictionary:
    if not _probe.class_exists("NavigationAgent3D") or not _probe.class_has_property("NavigationAgent3D", "keep_y_velocity"):
        return _entry(STATUS_UNSUPPORTED, "NavigationAgent3D.keep_y_velocity is unavailable in this Godot build")
    if _quirks.active(KEEP_Y_QUIRK):
        return _entry(STATUS_RESTRICTED, "Only authorable while use_3d_avoidance is false in this Godot build")
    return _entry(STATUS_SUPPORTED)

func _viewport_capability(is_3d: bool) -> Dictionary:
    if _probe.is_headless():
        return _entry(STATUS_UNSUPPORTED, "Headless editor has no graphical viewport")
    var method_name := "get_editor_viewport_3d" if is_3d else "get_editor_viewport_2d"
    if not _probe.editor_has_method(method_name):
        return _entry(STATUS_UNSUPPORTED, "EditorInterface.%s is unavailable" % method_name)
    return _entry(STATUS_SUPPORTED)

func _build_capabilities() -> Dictionary:
    return {
        "navigation.region.2d": _class_capability("NavigationRegion2D"),
        "navigation.region.3d": _class_capability("NavigationRegion3D"),
        "navigation.mesh.bake.2d": _bake_capability("2d"),
        "navigation.mesh.bake.3d": _bake_capability("3d"),
        "navigation.agent.2d": _class_capability("NavigationAgent2D"),
        "navigation.agent.3d": _class_capability("NavigationAgent3D"),
        KEEP_Y_CAPABILITY: _keep_y_velocity_capability(),
        "visual.viewport2d.capture": _viewport_capability(false),
        "visual.viewport3d.capture": _viewport_capability(true)
    }

func manifest() -> Dictionary:
    return _manifest.duplicate(true)

func status(capability_id: String) -> String:
    var capabilities: Dictionary = _manifest.get("capabilities", {})
    var entry: Dictionary = capabilities.get(capability_id, {})
    return str(entry.get("status", STATUS_UNSUPPORTED))

func reason(capability_id: String) -> String:
    var capabilities: Dictionary = _manifest.get("capabilities", {})
    var entry: Dictionary = capabilities.get(capability_id, {})
    return str(entry.get("reason", "Unknown capability"))

func supports(capability_id: String) -> bool:
    return status(capability_id) != STATUS_UNSUPPORTED

func quirk_active(quirk_id: String) -> bool:
    return _quirks.active(quirk_id)
