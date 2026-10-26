@tool
extends RefCounted

const KEEP_Y_VELOCITY_HIDDEN := "navigation.agent3d.keep_y_velocity.hidden_with_3d_avoidance"

var _engine: Dictionary
var _probe
var _active: Dictionary = {}

func _init(engine: Dictionary, probe) -> void:
    _engine = engine
    _probe = probe
    _active[KEEP_Y_VELOCITY_HIDDEN] = _detect_keep_y_velocity_hidden()

func _detect_keep_y_velocity_hidden() -> bool:
    if not _probe.class_can_instantiate("NavigationAgent3D"):
        return false
    if not _probe.class_has_property("NavigationAgent3D", "keep_y_velocity"):
        return false
    return not _probe.property_has_storage_with_overrides(
        "NavigationAgent3D",
        "keep_y_velocity",
        {"use_3d_avoidance": true}
    )

func active(quirk_id: String) -> bool:
    return bool(_active.get(quirk_id, false))

func manifest() -> Dictionary:
    return {
        KEEP_Y_VELOCITY_HIDDEN: {
            "active": active(KEEP_Y_VELOCITY_HIDDEN),
            "reason": "Live NavigationAgent3D property-usage probe in Godot %s" % str(_engine.get("string", "unknown"))
        }
    }
