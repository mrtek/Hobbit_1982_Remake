@tool
class_name SafetyPolicy
extends RefCounted

# Defense in depth. Keep this list aligned with the Node-side
# packages/server/src/security/reflection-safety.ts policy. The MCP server
# rejects these methods before an RPC is sent, and the addon rejects them
# again if a bridge call reaches Godot through another path.
const BLOCKED_METHODS: Array[String] = [
	"add_child",
	"add_sibling",
	"call",
	"call_deferred",
	"call_deferred_thread_group",
	"call_thread_safe",
	"callv",
	"crash",
	"create_process",
	"emit_signal",
	"execute",
	"free",
	"kill",
	"notification",
	"open_shell",
	"propagate_call",
	"propagate_notification",
	"queue_free",
	"remove_child",
	"reparent",
	"replace_by",
	"rpc",
	"rpc_config",
	"rpc_id",
	"set",
	"set_deferred",
	"set_deferred_thread_group",
	"set_indexed",
	"set_script",
	"set_thread_safe",
	"shell_open"
]

static func is_method_allowed(target: Object, method: String) -> bool:
	var normalized := method.strip_edges()
	if normalized.is_empty() or normalized.begins_with("_"):
		return false
	if BLOCKED_METHODS.has(normalized):
		return false
	# Script resources use meta-call dispatch; inspect them through script.inspect.
	if target is Script:
		return false
	if not is_instance_valid(target) or not target.has_method(normalized):
		return false
	return true
