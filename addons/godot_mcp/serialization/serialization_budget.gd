@tool
extends RefCounted

const ERROR_KEY = "__godot_mcp_serialization_error__"

static func failure(reason: String) -> Dictionary:
    return {ERROR_KEY: reason}

static func check(value, overrides: Dictionary = {}) -> String:
    var limits = {"depth":16, "items":4096, "bytes":256*1024, "string":65536, "container":4096}
    limits.merge(overrides, true)
    var budget = {"items":int(limits.items), "bytes":int(limits.bytes)}
    return _visit(value, 0, [], limits, budget)

static func _visit(value, depth: int, ancestors: Array, limits: Dictionary, budget: Dictionary) -> String:
    if depth > int(limits.depth):
        return "Maximum serialization depth exceeded"
    budget.items -= 1
    # Conservative space for typed wrappers, numeric fields and punctuation.
    budget.bytes -= 128
    if budget.items < 0 or budget.bytes < 0:
        return "Serialization item or byte budget exceeded"
    var type = typeof(value)
    if type == TYPE_FLOAT and not is_finite(value):
        return "Non-finite numbers cannot be serialized"
    if type == TYPE_STRING or type == TYPE_STRING_NAME or type == TYPE_NODE_PATH:
        var text = str(value)
        if text.length() > int(limits.string):
            return "Maximum serialization string length exceeded"
        # JSON escaping can expand a byte into six characters.
        budget.bytes -= text.to_utf8_buffer().size() * 6
    elif type == TYPE_ARRAY or type == TYPE_DICTIONARY:
        if value.size() > int(limits.container):
            return "Maximum serialization container length exceeded"
        if type == TYPE_DICTIONARY and value.has(ERROR_KEY):
            return "Nested value exceeds serialization limits"
        for ancestor in ancestors:
            if is_same(ancestor, value):
                return "Cyclic value cannot be serialized"
        ancestors.append(value)
        for item in value:
            var issue = _visit(item, depth + 1, ancestors, limits, budget)
            if issue.is_empty() and type == TYPE_DICTIONARY:
                issue = _visit(value[item], depth + 1, ancestors, limits, budget)
            if not issue.is_empty():
                ancestors.pop_back()
                return issue
        ancestors.pop_back()
    elif type >= TYPE_PACKED_BYTE_ARRAY:
        if value.size() > int(limits.container):
            return "Maximum serialization packed-array length exceeded"
        for item in value:
            var issue = _visit(item, depth + 1, ancestors, limits, budget)
            if not issue.is_empty():
                return issue
    elif type == TYPE_OBJECT and is_instance_valid(value):
        var text: String = value.get_class()
        if value is Resource:
            text += value.resource_path
        elif value is Node and value.is_inside_tree():
            text += str(value.get_path())
        var issue = _visit(text, depth + 1, ancestors, limits, budget)
        if not issue.is_empty():
            return issue
    elif type >= TYPE_VECTOR2 and type <= TYPE_PROJECTION:
        budget.bytes -= 512
    return "Serialization byte budget exceeded" if budget.bytes < 0 else ""
