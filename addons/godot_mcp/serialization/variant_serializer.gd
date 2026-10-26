@tool
class_name VariantSerializer
extends RefCounted

const Budget = preload("res://addons/godot_mcp/serialization/serialization_budget.gd")

static func serialize(value) -> Dictionary:
    var issue = Budget.check(value)
    return Budget.failure(issue) if not issue.is_empty() else _unchecked_serialize(value)

static func deserialize(value):
    var issue = Budget.check(value)
    return Budget.failure(issue) if not issue.is_empty() else _unchecked_deserialize(value)

static func encode(value):
    var issue = Budget.check(value)
    return Budget.failure(issue) if not issue.is_empty() else _unchecked_encode(value)

static func decode(value):
    var issue = Budget.check(value)
    return Budget.failure(issue) if not issue.is_empty() else _unchecked_decode(value)

static func _unchecked_serialize(val) -> Dictionary:
    match typeof(val):
        TYPE_NIL:
            return {"type": "null", "value": null}
        TYPE_BOOL:
            return {"type": "bool", "value": val}
        TYPE_INT:
            return {"type": "int", "value": val}
        TYPE_FLOAT:
            return {"type": "float", "value": val}
        TYPE_STRING:
            return {"type": "String", "value": val}
        TYPE_STRING_NAME:
            return {"type": "StringName", "value": str(val)}
        TYPE_NODE_PATH:
            return {"type": "NodePath", "value": str(val)}
        TYPE_VECTOR2:
            return {"type": "Vector2", "value": {"x": val.x, "y": val.y}}
        TYPE_VECTOR2I:
            return {"type": "Vector2i", "value": {"x": val.x, "y": val.y}}
        TYPE_RECT2:
            return {"type": "Rect2", "value": {"x": val.position.x, "y": val.position.y, "width": val.size.x, "height": val.size.y}}
        TYPE_RECT2I:
            return {"type": "Rect2i", "value": {"x": val.position.x, "y": val.position.y, "width": val.size.x, "height": val.size.y}}
        TYPE_VECTOR3:
            return {"type": "Vector3", "value": {"x": val.x, "y": val.y, "z": val.z}}
        TYPE_VECTOR3I:
            return {"type": "Vector3i", "value": {"x": val.x, "y": val.y, "z": val.z}}
        TYPE_VECTOR4:
            return {"type": "Vector4", "value": {"x": val.x, "y": val.y, "z": val.z, "w": val.w}}
        TYPE_VECTOR4I:
            return {"type": "Vector4i", "value": {"x": val.x, "y": val.y, "z": val.z, "w": val.w}}
        TYPE_COLOR:
            return {"type": "Color", "value": {"r": val.r, "g": val.g, "b": val.b, "a": val.a}}
        TYPE_QUATERNION:
            return {"type": "Quaternion", "value": {"x": val.x, "y": val.y, "z": val.z, "w": val.w}}
        TYPE_BASIS:
            return {
                "type": "Basis",
                "value": {
                    "x": {"x": val.x.x, "y": val.x.y, "z": val.x.z},
                    "y": {"x": val.y.x, "y": val.y.y, "z": val.y.z},
                    "z": {"x": val.z.x, "y": val.z.y, "z": val.z.z}
                }
            }
        TYPE_TRANSFORM2D:
            return {
                "type": "Transform2D",
                "value": {
                    "x": {"x": val.x.x, "y": val.x.y},
                    "y": {"x": val.y.x, "y": val.y.y},
                    "origin": {"x": val.origin.x, "y": val.origin.y}
                }
            }
        TYPE_TRANSFORM3D:
            return {
                "type": "Transform3D",
                "value": {
                    "basis": {
                        "x": {"x": val.basis.x.x, "y": val.basis.x.y, "z": val.basis.x.z},
                        "y": {"x": val.basis.y.x, "y": val.basis.y.y, "z": val.basis.y.z},
                        "z": {"x": val.basis.z.x, "y": val.basis.z.y, "z": val.basis.z.z}
                    },
                    "origin": {"x": val.origin.x, "y": val.origin.y, "z": val.origin.z}
                }
            }
        TYPE_ARRAY:
            var arr: Array = []
            for item in val:
                arr.append(_unchecked_serialize(item))
            return {"type": "Array", "value": arr}
        TYPE_DICTIONARY:
            var entries: Array = []
            for k in val.keys():
                entries.append({"key": _unchecked_serialize(k), "value": _unchecked_serialize(val[k])})
            return {"type": "Dictionary", "value": entries}
        TYPE_PACKED_BYTE_ARRAY:
            return {"type": "PackedByteArray", "value": Array(val)}
        TYPE_PACKED_INT32_ARRAY:
            return {"type": "PackedInt32Array", "value": Array(val)}
        TYPE_PACKED_INT64_ARRAY:
            return {"type": "PackedInt64Array", "value": Array(val)}
        TYPE_PACKED_FLOAT32_ARRAY:
            return {"type": "PackedFloat32Array", "value": Array(val)}
        TYPE_PACKED_FLOAT64_ARRAY:
            return {"type": "PackedFloat64Array", "value": Array(val)}
        TYPE_PACKED_STRING_ARRAY:
            return {"type": "PackedStringArray", "value": Array(val)}
        TYPE_PACKED_VECTOR2_ARRAY:
            var p2: Array = []
            for v in val:
                p2.append({"x": v.x, "y": v.y})
            return {"type": "PackedVector2Array", "value": p2}
        TYPE_PACKED_VECTOR3_ARRAY:
            var p3: Array = []
            for v in val:
                p3.append({"x": v.x, "y": v.y, "z": v.z})
            return {"type": "PackedVector3Array", "value": p3}
        TYPE_PACKED_COLOR_ARRAY:
            var pc: Array = []
            for c in val:
                pc.append({"r": c.r, "g": c.g, "b": c.b, "a": c.a})
            return {"type": "PackedColorArray", "value": pc}
        TYPE_OBJECT:
            if val == null:
                return {"type": "null", "value": null}
            if val is Resource:
                return {"type": "Resource", "value": {"path": val.resource_path, "type": val.get_class()}}
            if val is Node:
                return {"type": "Node", "value": {"path": str(val.get_path()), "type": val.get_class()}}
            return {"type": "Object", "value": {"id": val.get_instance_id(), "type": val.get_class()}}
        _:
            return {"type": "String", "value": str(val)}

static func _unchecked_deserialize(data):
    if typeof(data) != TYPE_DICTIONARY:
        return data
    var type_str: String = str(data.get("type", ""))
    if type_str.is_empty():
        return data
    var val = data.get("value")

    match type_str:
        "null": return null
        "bool": return bool(val)
        "int": return int(val)
        "float": return float(val)
        "String": return str(val)
        "StringName": return StringName(str(val))
        "NodePath": return NodePath(str(val))
        "Vector2": return Vector2(float(val.get("x", 0)), float(val.get("y", 0)))
        "Vector2i": return Vector2i(int(val.get("x", 0)), int(val.get("y", 0)))
        "Rect2": return Rect2(float(val.get("x", 0)), float(val.get("y", 0)), float(val.get("width", 0)), float(val.get("height", 0)))
        "Rect2i": return Rect2i(int(val.get("x", 0)), int(val.get("y", 0)), int(val.get("width", 0)), int(val.get("height", 0)))
        "Vector3": return Vector3(float(val.get("x", 0)), float(val.get("y", 0)), float(val.get("z", 0)))
        "Vector3i": return Vector3i(int(val.get("x", 0)), int(val.get("y", 0)), int(val.get("z", 0)))
        "Vector4": return Vector4(float(val.get("x", 0)), float(val.get("y", 0)), float(val.get("z", 0)), float(val.get("w", 0)))
        "Vector4i": return Vector4i(int(val.get("x", 0)), int(val.get("y", 0)), int(val.get("z", 0)), int(val.get("w", 0)))
        "Color": return Color(float(val.get("r", 0)), float(val.get("g", 0)), float(val.get("b", 0)), float(val.get("a", 1)))
        "Quaternion": return Quaternion(float(val.get("x", 0)), float(val.get("y", 0)), float(val.get("z", 0)), float(val.get("w", 1)))
        "Basis":
            var bx = val.get("x", {})
            var by = val.get("y", {})
            var bz = val.get("z", {})
            return Basis(
                Vector3(float(bx.get("x", 0)), float(bx.get("y", 0)), float(bx.get("z", 0))),
                Vector3(float(by.get("x", 0)), float(by.get("y", 0)), float(by.get("z", 0))),
                Vector3(float(bz.get("x", 0)), float(bz.get("y", 0)), float(bz.get("z", 0)))
            )
        "Transform2D":
            var tx = val.get("x", {})
            var ty = val.get("y", {})
            var to = val.get("origin", {})
            return Transform2D(
                Vector2(float(tx.get("x", 0)), float(tx.get("y", 0))),
                Vector2(float(ty.get("x", 0)), float(ty.get("y", 0))),
                Vector2(float(to.get("x", 0)), float(to.get("y", 0)))
            )
        "Transform3D":
            var b = val.get("basis", {})
            var o = val.get("origin", {})
            var basis = Basis(
                Vector3(float(b.get("x", {}).get("x", 0)), float(b.get("x", {}).get("y", 0)), float(b.get("x", {}).get("z", 0))),
                Vector3(float(b.get("y", {}).get("x", 0)), float(b.get("y", {}).get("y", 0)), float(b.get("y", {}).get("z", 0))),
                Vector3(float(b.get("z", {}).get("x", 0)), float(b.get("z", {}).get("y", 0)), float(b.get("z", {}).get("z", 0)))
            )
            var origin = Vector3(float(o.get("x", 0)), float(o.get("y", 0)), float(o.get("z", 0)))
            return Transform3D(basis, origin)
        "Array":
            var arr: Array = []
            if typeof(val) == TYPE_ARRAY:
                for item in val:
                    arr.append(_unchecked_deserialize(item))
            return arr
        "Dictionary":
            var dict: Dictionary = {}
            if typeof(val) == TYPE_ARRAY:
                for entry in val:
                    if typeof(entry) == TYPE_DICTIONARY:
                        var k = _unchecked_deserialize(entry.get("key"))
                        var v = _unchecked_deserialize(entry.get("value"))
                        dict[k] = v
            elif typeof(val) == TYPE_DICTIONARY:
                for k in val.keys():
                    dict[k] = _unchecked_deserialize(val[k])
            return dict
        "PackedByteArray": return PackedByteArray(val if typeof(val) == TYPE_ARRAY else [])
        "PackedInt32Array": return PackedInt32Array(val if typeof(val) == TYPE_ARRAY else [])
        "PackedInt64Array": return PackedInt64Array(val if typeof(val) == TYPE_ARRAY else [])
        "PackedFloat32Array": return PackedFloat32Array(val if typeof(val) == TYPE_ARRAY else [])
        "PackedFloat64Array": return PackedFloat64Array(val if typeof(val) == TYPE_ARRAY else [])
        "PackedStringArray": return PackedStringArray(val if typeof(val) == TYPE_ARRAY else [])
        "PackedVector2Array":
            var p2 := PackedVector2Array()
            if typeof(val) == TYPE_ARRAY:
                for item in val:
                    p2.append(Vector2(float(item.get("x", 0)), float(item.get("y", 0))))
            return p2
        "PackedVector3Array":
            var p3 := PackedVector3Array()
            if typeof(val) == TYPE_ARRAY:
                for item in val:
                    p3.append(Vector3(float(item.get("x", 0)), float(item.get("y", 0)), float(item.get("z", 0))))
            return p3
        "PackedColorArray":
            var pc := PackedColorArray()
            if typeof(val) == TYPE_ARRAY:
                for item in val:
                    pc.append(Color(float(item.get("r", 0)), float(item.get("g", 0)), float(item.get("b", 0)), float(item.get("a", 1))))
            return pc
        "Resource":
            var res_path: String = str(val.get("path", ""))
            if not res_path.is_empty() and ResourceLoader.exists(res_path):
                return ResourceLoader.load(res_path)
            return null
        _:
            return val

static func _unchecked_encode(val):
    match typeof(val):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
            return val
        TYPE_STRING_NAME, TYPE_NODE_PATH:
            return str(val)
        TYPE_VECTOR2, TYPE_VECTOR2I:
            return {"x": val.x, "y": val.y}
        TYPE_VECTOR3, TYPE_VECTOR3I:
            return {"x": val.x, "y": val.y, "z": val.z}
        TYPE_VECTOR4, TYPE_VECTOR4I:
            return {"x": val.x, "y": val.y, "z": val.z, "w": val.w}
        TYPE_RECT2, TYPE_RECT2I:
            return {"x": val.position.x, "y": val.position.y, "width": val.size.x, "height": val.size.y}
        TYPE_COLOR:
            return {"r": val.r, "g": val.g, "b": val.b, "a": val.a}
        TYPE_QUATERNION:
            return {"x": val.x, "y": val.y, "z": val.z, "w": val.w}
        TYPE_BASIS:
            return {
                "x": {"x": val.x.x, "y": val.x.y, "z": val.x.z},
                "y": {"x": val.y.x, "y": val.y.y, "z": val.y.z},
                "z": {"x": val.z.x, "y": val.z.y, "z": val.z.z}
            }
        TYPE_TRANSFORM2D:
            return {
                "x": {"x": val.x.x, "y": val.x.y},
                "y": {"x": val.y.x, "y": val.y.y},
                "origin": {"x": val.origin.x, "y": val.origin.y}
            }
        TYPE_TRANSFORM3D:
            return {
                "basis": {
                    "x": {"x": val.basis.x.x, "y": val.basis.x.y, "z": val.basis.x.z},
                    "y": {"x": val.basis.y.x, "y": val.basis.y.y, "z": val.basis.y.z},
                    "z": {"x": val.basis.z.x, "y": val.basis.z.y, "z": val.basis.z.z}
                },
                "origin": {"x": val.origin.x, "y": val.origin.y, "z": val.origin.z}
            }
        TYPE_ARRAY:
            var arr: Array = []
            for item in val:
                arr.append(_unchecked_encode(item))
            return arr
        TYPE_DICTIONARY:
            var d: Dictionary = {}
            for k in val.keys():
                d[str(k)] = _unchecked_encode(val[k])
            return d
        TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
        TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
            return Array(val)
        TYPE_PACKED_VECTOR2_ARRAY:
            var arr: Array = []
            for v in val:
                arr.append({"x": v.x, "y": v.y})
            return arr
        TYPE_PACKED_VECTOR3_ARRAY:
            var arr: Array = []
            for v in val:
                arr.append({"x": v.x, "y": v.y, "z": v.z})
            return arr
        TYPE_PACKED_COLOR_ARRAY:
            var arr: Array = []
            for c in val:
                arr.append({"r": c.r, "g": c.g, "b": c.b, "a": c.a})
            return arr
        TYPE_OBJECT:
            if val == null:
                return null
            if val is Resource:
                if not val.resource_path.is_empty():
                    return val.resource_path
                return val.get_class()
            if val is Node:
                return str(val.get_path())
            return val.get_class()
        _:
            return str(val)

static func _unchecked_decode(data):
    if typeof(data) != TYPE_DICTIONARY:
        if typeof(data) == TYPE_ARRAY:
            var arr: Array = []
            for item in data:
                arr.append(_unchecked_decode(item))
            return arr
        return data

    if data.has("type") and data.has("value"):
        return _unchecked_deserialize(data)

    if data.has("x") and data.has("y"):
        if data.has("z"):
            if data.has("w"):
                return Vector4(float(data["x"]), float(data["y"]), float(data["z"]), float(data["w"]))
            return Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
        if data.has("width") and data.has("height"):
            return Rect2(float(data["x"]), float(data["y"]), float(data["width"]), float(data["height"]))
        return Vector2(float(data["x"]), float(data["y"]))

    if data.has("r") and data.has("g") and data.has("b"):
        return Color(float(data["r"]), float(data["g"]), float(data["b"]), float(data.get("a", 1.0)))

    var dict: Dictionary = {}
    for k in data.keys():
        dict[k] = _unchecked_decode(data[k])
    return dict