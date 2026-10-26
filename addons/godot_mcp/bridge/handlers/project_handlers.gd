@tool
extends RefCounted

var _editor_interface
var _variant_serializer = preload("res://addons/godot_mcp/serialization/variant_serializer.gd")

func _init(editor_interface) -> void:
	_editor_interface = editor_interface

func _error(code: String, message: String) -> Dictionary:
	return {
		"__error": {
			"code": code,
			"message": message
		}
	}

func get_setting(params: Dictionary) -> Dictionary:
	var setting: String = params.get("setting", "")
	if setting.is_empty():
		return _error("INVALID_ARGUMENT", "setting is required")

	if not ProjectSettings.has_setting(setting):
		return _error("NOT_FOUND", "Project setting not found: %s" % setting)

	var val = ProjectSettings.get_setting(setting)
	return {
		"setting": setting,
		"value": _variant_serializer.encode(val)
	}

func set_setting(params: Dictionary) -> Dictionary:
	var setting: String = params.get("setting", "")
	if setting.is_empty():
		return _error("INVALID_ARGUMENT", "setting is required")

	var prev = null
	if ProjectSettings.has_setting(setting):
		prev = ProjectSettings.get_setting(setting)

	var decoded = _variant_serializer.decode(params.get("value"))
	ProjectSettings.set_setting(setting, decoded)

	var do_save: bool = params.get("save", true)
	var saved := false
	if do_save:
		var err = ProjectSettings.save()
		saved = (err == OK)

	return {
		"setting": setting,
		"previous_value": _variant_serializer.encode(prev),
		"new_value": _variant_serializer.encode(decoded),
		"saved": saved
	}

func list_input_actions(_params: Dictionary) -> Dictionary:
	var actions: Array = []
	for act in InputMap.get_actions():
		var act_name := str(act)
		var deadzone: float = InputMap.action_get_deadzone(act)
		var events: Array = []
		for ev in InputMap.action_get_events(act):
			var ev_info: Dictionary = { "type": ev.get_class() }
			if ev is InputEventKey:
				ev_info["keycode"] = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			elif ev is InputEventMouseButton:
				ev_info["button_index"] = ev.button_index
			events.append(ev_info)
		actions.append({
			"name": act_name,
			"deadzone": deadzone,
			"events": events
		})
	return { "actions": actions }

func add_input_action(params: Dictionary) -> Dictionary:
	var action: String = params.get("action", "")
	if action.is_empty():
		return _error("INVALID_ARGUMENT", "action is required")

	var deadzone: float = float(params.get("deadzone", 0.5))
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)

	var events_param: Array = params.get("events", [])
	for ev_dict in events_param:
		if typeof(ev_dict) == TYPE_DICTIONARY:
			var ev_type: String = str(ev_dict.get("type", ""))
			if ev_type == "InputEventKey":
				var iek := InputEventKey.new()
				if ev_dict.has("keycode"):
					iek.physical_keycode = int(ev_dict["keycode"])
				InputMap.action_add_event(action, iek)
			elif ev_type == "InputEventMouseButton":
				var iemb := InputEventMouseButton.new()
				if ev_dict.has("button_index"):
					iemb.button_index = int(ev_dict["button_index"])
				InputMap.action_add_event(action, iemb)

	var setting_key := "input/" + action
	var events_arr: Array = []
	for ev in InputMap.action_get_events(action):
		events_arr.append(ev)
	ProjectSettings.set_setting(setting_key, {
		"deadzone": deadzone,
		"events": events_arr
	})
	ProjectSettings.save()

	return {
		"action": action,
		"added": true
	}

func remove_input_action(params: Dictionary) -> Dictionary:
	var action: String = params.get("action", "")
	if action.is_empty():
		return _error("INVALID_ARGUMENT", "action is required")

	if InputMap.has_action(action):
		InputMap.erase_action(action)

	var setting_key := "input/" + action
	if ProjectSettings.has_setting(setting_key):
		ProjectSettings.set_setting(setting_key, null)
		ProjectSettings.save()

	return {
		"action": action,
		"removed": true
	}
