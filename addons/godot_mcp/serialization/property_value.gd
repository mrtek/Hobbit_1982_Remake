@tool
extends RefCounted

const Serializer = preload("res://addons/godot_mcp/serialization/variant_serializer.gd")
const Budget = preload("res://addons/godot_mcp/serialization/serialization_budget.gd")

static func _error(code: String, message: String, details: Dictionary = {}) -> Dictionary:
    details["applied"] = false
    return {"__error":{"code":code,"message":message,"details":details}}

static func _matches_class(value: Object, expected: String) -> bool:
    if expected.is_empty() or value.is_class(expected): return true
    var script: Script = value.get_script()
    for _depth in range(32):
        if script == null: break
        if script.get_global_name() == expected: return true
        script = script.get_base_script()
    return false

static func _packed(value: Array, expected: int):
    if expected == TYPE_PACKED_VECTOR2_ARRAY and value.all(func(v): return v is Vector2): return PackedVector2Array(value)
    if expected == TYPE_PACKED_VECTOR3_ARRAY and value.all(func(v): return v is Vector3): return PackedVector3Array(value)
    if expected == TYPE_PACKED_COLOR_ARRAY and value.all(func(v): return v is Color): return PackedColorArray(value)
    if expected == TYPE_PACKED_STRING_ARRAY and value.all(func(v): return typeof(v) in [TYPE_STRING,TYPE_STRING_NAME]): return PackedStringArray(value)
    if expected == TYPE_PACKED_FLOAT32_ARRAY and value.all(func(v): return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v))): return PackedFloat32Array(value)
    if expected == TYPE_PACKED_FLOAT64_ARRAY and value.all(func(v): return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v))): return PackedFloat64Array(value)
    if expected == TYPE_PACKED_BYTE_ARRAY and value.all(func(v): return typeof(v) == TYPE_INT and v >= 0 and v <= 255): return PackedByteArray(value)
    if expected == TYPE_PACKED_INT32_ARRAY and value.all(func(v): return typeof(v) == TYPE_INT and v >= -2147483648 and v <= 2147483647): return PackedInt32Array(value)
    if expected == TYPE_PACKED_INT64_ARRAY and value.all(func(v): return typeof(v) == TYPE_INT): return PackedInt64Array(value)
    return null

static func prepare(target: Object, property: String, raw) -> Dictionary:
    var found: Dictionary = {}
    for entry in target.get_property_list():
        if str(entry.name) == property:
            found = entry
            break
    if found.is_empty(): return _error("PROPERTY_NOT_FOUND", "Property not found: " + property)
    if (int(found.get("usage",0)) & PROPERTY_USAGE_READ_ONLY) != 0:
        return _error("PROPERTY_READ_ONLY", "Property is read-only: " + property)
    var issue := Budget.check(raw)
    if not issue.is_empty(): return _error("ARGUMENT_TOO_LARGE", issue)
    var decoded = Serializer.decode(raw)
    issue = Budget.check(decoded)
    if not issue.is_empty(): return _error("ARGUMENT_TOO_LARGE",issue)
    var expected: int = int(found.type)
    var expected_name := type_string(expected)
    var resource_class := str(found.get("class_name",""))
    if resource_class.is_empty() and int(found.get("hint",0)) == PROPERTY_HINT_RESOURCE_TYPE:
        resource_class = str(found.get("hint_string",""))
    if expected == TYPE_OBJECT and not resource_class.is_empty(): expected_name = resource_class
    var explicit_null: bool = raw == null or (raw is Dictionary and raw.get("type") == "null" and raw.has("value") and raw.value == null)
    if decoded == null and not explicit_null and expected == TYPE_OBJECT:
        return _error("PROPERTY_RESOURCE_LOAD_FAILED", "Resource could not be loaded; use an imported resource path or explicit null",
            {"property":property,"expectedType":expected_name,"receivedType":"unresolved resource"})
    if expected == TYPE_FLOAT and typeof(decoded) == TYPE_INT: decoded = float(decoded)
    if expected == TYPE_INT and typeof(decoded) == TYPE_FLOAT and is_finite(decoded) and decoded == floor(decoded) and absf(decoded) <= 9007199254740991.0:
        decoded = int(decoded)
    if expected == TYPE_STRING_NAME and decoded is String: decoded = StringName(decoded)
    if expected == TYPE_NODE_PATH and decoded is String: decoded = NodePath(decoded)
    if decoded is Array and expected >= TYPE_PACKED_BYTE_ARRAY:
        var packed = _packed(decoded,expected)
        if packed != null: decoded = packed
    issue = Budget.check(decoded)
    if not issue.is_empty(): return _error("ARGUMENT_TOO_LARGE",issue)
    var compatible: bool = expected == TYPE_NIL or typeof(decoded) == expected or (expected == TYPE_OBJECT and explicit_null)
    if compatible and expected == TYPE_OBJECT and decoded != null and not resource_class.is_empty():
        compatible = false
        for name_value in resource_class.split(","):
            if _matches_class(decoded,str(name_value).strip_edges()): compatible = true; break
    if not compatible:
        var received: String = decoded.get_class() if decoded is Object else type_string(typeof(decoded))
        var details := {"property":property,"expectedType":expected_name,"receivedType":received}
        if expected == TYPE_OBJECT: details.example = {"type":"Resource","value":{"path":"res://path/to/imported_resource.tres"}}
        elif expected == TYPE_PACKED_VECTOR2_ARRAY: details.example = {"type":"PackedVector2Array","value":[{"x":0,"y":0},{"x":32,"y":0}]}
        elif expected == TYPE_VECTOR2: details.example = {"type":"Vector2","value":{"x":0,"y":0}}
        elif expected == TYPE_COLOR: details.example = {"type":"Color","value":{"r":1,"g":1,"b":1,"a":1}}
        return _error("PROPERTY_TYPE_MISMATCH", "Property %s expects %s; received %s" % [property,expected_name,received], details)
    if not Budget.check(target.get(property)).is_empty(): return _error("RESULT_TOO_LARGE", "Previous property exceeds the Undo snapshot budget")
    return {"value":decoded,"expectedType":expected_name}

static func equal(a,b) -> bool:
    if typeof(a) != typeof(b): return false
    if typeof(a) == TYPE_FLOAT: return is_equal_approx(a,b)
    if typeof(a) in [TYPE_VECTOR2,TYPE_VECTOR3,TYPE_COLOR,TYPE_QUATERNION]: return a.is_equal_approx(b)
    return a == b
