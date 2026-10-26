@tool
extends RefCounted
static func resolve(root: Node, value: String) -> Node:
    if not is_instance_valid(root):
        return null
    if value in ["", ".", str(root.name), "/" + str(root.name)]:
        return root
    if value.contains(":") or value.contains("\\") or value.split("/").has(".."):
        return null
    if value.begins_with("/" + str(root.name) + "/"):
        value = value.substr(str(root.name).length() + 2)
    elif value.begins_with(str(root.name) + "/"):
        value = value.substr(str(root.name).length() + 1)
    elif value.begins_with("/"):
        return null
    var node = root.get_node_or_null(NodePath(value))
    return node if node != null and root.is_ancestor_of(node) else null
