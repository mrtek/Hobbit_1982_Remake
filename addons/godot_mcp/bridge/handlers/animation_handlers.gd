@tool
extends RefCounted

var _editor_interface
var _variant_serializer = preload("res://addons/godot_mcp/serialization/variant_serializer.gd")
const MAX_INSPECTED_KEYS := 2048

func _init(editor_interface) -> void:
	_editor_interface = editor_interface

func _error(code: String, message: String) -> Dictionary:
	return {"__error": {"code": code, "message": message}}

func _root() -> Node:
	return _editor_interface.get_edited_scene_root()

func _logical_path(root: Node, node: Node) -> String:
	var relative := root.get_path_to(node)
	var logical := "/%s" % root.name
	if relative != NodePath("."):
		logical += "/%s" % str(relative)
	return logical

func _resolve_node(root: Node, path_str: String) -> Node:
	if path_str.is_empty() or path_str == "." or path_str == "/%s" % root.name:
		return root
	var target := root.get_node_or_null(path_str)
	if target:
		return target
	if path_str.begins_with("/%s/" % root.name):
		return root.get_node_or_null(path_str.substr(len(root.name) + 2))
	if path_str.begins_with("/"):
		return root.get_node_or_null(path_str.substr(1))
	return null

func _resolve_mixer(root: Node, path_str: String):
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is AnimationMixer:
		return _error("INVALID_NODE_TYPE", "Node is not an AnimationMixer: %s" % path_str)
	return node

func _undo_redo() -> EditorUndoRedoManager:
	return _editor_interface.get_editor_undo_redo()

func _library_name(params: Dictionary) -> String:
	return str(params.get("library", ""))

func _animation_name(params: Dictionary) -> String:
	return str(params.get("animation", ""))

func _qualified_name(library_name: String, animation_name: String) -> String:
	return animation_name if library_name.is_empty() else "%s/%s" % [library_name, animation_name]

func _target_result(root: Node, mixer: AnimationMixer, library_name: String, animation_name: String) -> Dictionary:
	return {
		"player_path": _logical_path(root, mixer),
		"library": library_name,
		"animation": animation_name,
		"qualified_name": _qualified_name(library_name, animation_name)
	}

func _get_library(mixer: AnimationMixer, library_name: String):
	if not mixer.has_animation_library(library_name):
		return _error("ANIMATION_LIBRARY_NOT_FOUND", "Animation library not found: %s" % library_name)
	return mixer.get_animation_library(library_name)

func _get_animation(library: AnimationLibrary, animation_name: String):
	if animation_name.is_empty():
		return _error("INVALID_ARGUMENT", "animation is required")
	if not library.has_animation(animation_name):
		return _error("ANIMATION_NOT_FOUND", "Animation not found: %s" % animation_name)
	return library.get_animation(animation_name)

func _loop_mode_name(value: int) -> String:
	match value:
		Animation.LOOP_NONE: return "none"
		Animation.LOOP_LINEAR: return "linear"
		Animation.LOOP_PINGPONG: return "pingpong"
		_: return "none"

func _loop_mode(value: String) -> int:
	match value:
		"none": return Animation.LOOP_NONE
		"linear": return Animation.LOOP_LINEAR
		"pingpong": return Animation.LOOP_PINGPONG
		_: return -1

func _track_type_name(value: int) -> String:
	match value:
		Animation.TYPE_VALUE: return "value"
		Animation.TYPE_POSITION_3D: return "position_3d"
		Animation.TYPE_ROTATION_3D: return "rotation_3d"
		Animation.TYPE_SCALE_3D: return "scale_3d"
		Animation.TYPE_BLEND_SHAPE: return "blend_shape"
		Animation.TYPE_METHOD: return "method"
		Animation.TYPE_BEZIER: return "bezier"
		Animation.TYPE_AUDIO: return "audio"
		Animation.TYPE_ANIMATION: return "animation"
		_: return "value"

func _editable_track_type(value: String) -> int:
	match value:
		"value": return Animation.TYPE_VALUE
		"position_3d": return Animation.TYPE_POSITION_3D
		"rotation_3d": return Animation.TYPE_ROTATION_3D
		"scale_3d": return Animation.TYPE_SCALE_3D
		"blend_shape": return Animation.TYPE_BLEND_SHAPE
		"method": return Animation.TYPE_METHOD
		"bezier": return Animation.TYPE_BEZIER
		"animation": return Animation.TYPE_ANIMATION
		_: return -1

func _interpolation_name(value: int) -> String:
	match value:
		Animation.INTERPOLATION_NEAREST: return "nearest"
		Animation.INTERPOLATION_LINEAR: return "linear"
		Animation.INTERPOLATION_CUBIC: return "cubic"
		Animation.INTERPOLATION_LINEAR_ANGLE: return "linear_angle"
		Animation.INTERPOLATION_CUBIC_ANGLE: return "cubic_angle"
		_: return "linear"

func _interpolation(value: String) -> int:
	match value:
		"nearest": return Animation.INTERPOLATION_NEAREST
		"linear": return Animation.INTERPOLATION_LINEAR
		"cubic": return Animation.INTERPOLATION_CUBIC
		"linear_angle": return Animation.INTERPOLATION_LINEAR_ANGLE
		"cubic_angle": return Animation.INTERPOLATION_CUBIC_ANGLE
		_: return -1

func list(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_mixer(root, str(params.get("player_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var mixer := resolved as AnimationMixer
	var library_names: Array = Array(mixer.get_animation_library_list())
	library_names.sort()
	var libraries: Array = []
	for raw_library_name in library_names:
		var library_name := str(raw_library_name)
		var library: AnimationLibrary = mixer.get_animation_library(library_name)
		var names: Array = Array(library.get_animation_list())
		names.sort()
		var normalized: Array = []
		for value in names:
			normalized.append(str(value))
		libraries.append({"library": library_name, "animations": normalized})
	var flattened: Array = []
	for value in mixer.get_animation_list():
		flattened.append(str(value))
	flattened.sort()
	return {"player_path": _logical_path(root, mixer), "libraries": libraries, "flattened": flattened}

func inspect(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_mixer(root, str(params.get("player_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var mixer := resolved as AnimationMixer
	var library_name := _library_name(params)
	var library = _get_library(mixer, library_name)
	if typeof(library) == TYPE_DICTIONARY:
		return library
	var animation_name := _animation_name(params)
	var animation = _get_animation(library as AnimationLibrary, animation_name)
	if typeof(animation) == TYPE_DICTIONARY:
		return animation
	var anim := animation as Animation
	var total_keys := 0
	for track_index in range(anim.get_track_count()):
		total_keys += anim.track_get_key_count(track_index)
	if total_keys > MAX_INSPECTED_KEYS:
		return _error("LIMIT_EXCEEDED", "Animation has %d keys; limit is %d" % [total_keys, MAX_INSPECTED_KEYS])
	var tracks: Array = []
	for track_index in range(anim.get_track_count()):
		var keys: Array = []
		for key_index in range(anim.track_get_key_count(track_index)):
			keys.append({
				"index": key_index,
				"time": anim.track_get_key_time(track_index, key_index),
				"transition": anim.track_get_key_transition(track_index, key_index),
				"value": _variant_serializer.serialize(anim.track_get_key_value(track_index, key_index))
			})
		tracks.append({
			"index": track_index,
			"type": _track_type_name(anim.track_get_type(track_index)),
			"path": str(anim.track_get_path(track_index)),
			"enabled": anim.track_is_enabled(track_index),
			"interpolation": _interpolation_name(anim.track_get_interpolation_type(track_index)),
			"loop_wrap": anim.track_get_interpolation_loop_wrap(track_index),
			"keys": keys
		})
	var result := _target_result(root, mixer, library_name, animation_name)
	result["length"] = anim.length
	result["loop_mode"] = _loop_mode_name(anim.loop_mode)
	result["step"] = anim.step
	result["track_count"] = anim.get_track_count()
	result["tracks"] = tracks
	return result

func create(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_mixer(root, str(params.get("player_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var mixer := resolved as AnimationMixer
	var animation_name := _animation_name(params)
	if animation_name.is_empty():
		return _error("INVALID_ARGUMENT", "animation is required")
	var library_name := _library_name(params)
	var library: AnimationLibrary = mixer.get_animation_library(library_name) if mixer.has_animation_library(library_name) else null
	if library and library.has_animation(animation_name):
		return _error("ALREADY_EXISTS", "Animation already exists: %s" % _qualified_name(library_name, animation_name))
	var length := float(params.get("length", 1.0))
	var step := float(params.get("step", 1.0 / 30.0))
	var loop_mode := _loop_mode(str(params.get("loop_mode", "none")))
	if length < 0.0 or step <= 0.0 or loop_mode < 0:
		return _error("INVALID_ARGUMENT", "Invalid length, step, or loop mode")
	var created_library := false
	if not library:
		library = AnimationLibrary.new()
		created_library = true
	var anim := Animation.new()
	anim.length = length
	anim.step = step
	anim.loop_mode = loop_mode
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Create Animation: " + animation_name, 0, mixer)
		if created_library:
			undo_redo.add_do_method(mixer, "add_animation_library", StringName(library_name), library)
		undo_redo.add_do_method(library, "add_animation", StringName(animation_name), anim)
		undo_redo.add_undo_method(library, "remove_animation", StringName(animation_name))
		if created_library:
			undo_redo.add_undo_method(mixer, "remove_animation_library", StringName(library_name))
		undo_redo.commit_action()
	else:
		if created_library:
			mixer.add_animation_library(StringName(library_name), library)
		library.add_animation(StringName(animation_name), anim)
	return _target_result(root, mixer, library_name, animation_name)

func remove(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_mixer(root, str(params.get("player_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var mixer := resolved as AnimationMixer
	var library_name := _library_name(params)
	var library = _get_library(mixer, library_name)
	if typeof(library) == TYPE_DICTIONARY:
		return library
	var animation_name := _animation_name(params)
	var animation = _get_animation(library as AnimationLibrary, animation_name)
	if typeof(animation) == TYPE_DICTIONARY:
		return animation
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Remove Animation: " + animation_name, 0, mixer)
		undo_redo.add_do_method(library, "remove_animation", StringName(animation_name))
		undo_redo.add_undo_method(library, "add_animation", StringName(animation_name), animation)
		undo_redo.commit_action()
	else:
		(library as AnimationLibrary).remove_animation(StringName(animation_name))
	return _target_result(root, mixer, library_name, animation_name)

func configure(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_mixer(root, str(params.get("player_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var mixer := resolved as AnimationMixer
	var library_name := _library_name(params)
	var library = _get_library(mixer, library_name)
	if typeof(library) == TYPE_DICTIONARY:
		return library
	var animation_name := _animation_name(params)
	var animation = _get_animation(library as AnimationLibrary, animation_name)
	if typeof(animation) == TYPE_DICTIONARY:
		return animation
	var anim := animation as Animation
	if not params.has("length") and not params.has("loop_mode") and not params.has("step"):
		return _error("INVALID_ARGUMENT", "At least one animation setting is required")
	if params.has("length") and float(params.length) < 0.0:
		return _error("INVALID_ARGUMENT", "length must be non-negative")
	if params.has("step") and float(params.step) <= 0.0:
		return _error("INVALID_ARGUMENT", "step must be positive")
	var requested_loop := -1
	if params.has("loop_mode"):
		requested_loop = _loop_mode(str(params.loop_mode))
		if requested_loop < 0: return _error("INVALID_ARGUMENT", "Unknown loop mode")
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Configure Animation: " + animation_name, 0, mixer)
		if params.has("length"):
			undo_redo.add_do_property(anim, "length", float(params.length))
			undo_redo.add_undo_property(anim, "length", anim.length)
		if params.has("loop_mode"):
			undo_redo.add_do_property(anim, "loop_mode", requested_loop)
			undo_redo.add_undo_property(anim, "loop_mode", anim.loop_mode)
		if params.has("step"):
			undo_redo.add_do_property(anim, "step", float(params.step))
			undo_redo.add_undo_property(anim, "step", anim.step)
		undo_redo.commit_action()
	else:
		if params.has("length"): anim.length = float(params.length)
		if params.has("loop_mode"): anim.loop_mode = requested_loop
		if params.has("step"): anim.step = float(params.step)
	return _target_result(root, mixer, library_name, animation_name)

func add_track(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_mixer(root, str(params.get("player_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY:
		return resolved
	var mixer := resolved as AnimationMixer
	var library_name := _library_name(params)
	var library = _get_library(mixer, library_name)
	if typeof(library) == TYPE_DICTIONARY: return library
	var animation_name := _animation_name(params)
	var animation = _get_animation(library as AnimationLibrary, animation_name)
	if typeof(animation) == TYPE_DICTIONARY: return animation
	var anim := animation as Animation
	var track_type := _editable_track_type(str(params.get("type", "")))
	var interpolation := _interpolation(str(params.get("interpolation", "linear")))
	if track_type < 0 or interpolation < 0:
		return _error("INVALID_ARGUMENT", "Unknown or unsupported track type/interpolation")
	var path_str := str(params.get("path", ""))
	if path_str.is_empty(): return _error("INVALID_ARGUMENT", "path is required")
	var requested_position := int(params.get("at_position", -1))
	if requested_position < -1 or requested_position > anim.get_track_count():
		return _error("INVALID_ARGUMENT", "at_position is outside the track range")
	var track_index := anim.get_track_count() if requested_position == -1 else requested_position
	var loop_wrap := bool(params.get("loop_wrap", true))
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Add Animation Track: " + animation_name, 0, mixer)
		undo_redo.add_do_method(anim, "add_track", track_type, track_index)
		undo_redo.add_do_method(anim, "track_set_path", track_index, NodePath(path_str))
		undo_redo.add_do_method(anim, "track_set_interpolation_type", track_index, interpolation)
		undo_redo.add_do_method(anim, "track_set_interpolation_loop_wrap", track_index, loop_wrap)
		undo_redo.add_undo_method(anim, "remove_track", track_index)
		undo_redo.commit_action()
	else:
		anim.add_track(track_type, track_index)
		anim.track_set_path(track_index, NodePath(path_str))
		anim.track_set_interpolation_type(track_index, interpolation)
		anim.track_set_interpolation_loop_wrap(track_index, loop_wrap)
	var result := _target_result(root, mixer, library_name, animation_name)
	result["track_index"] = track_index
	return result

func _validate_track(anim: Animation, track_index: int):
	if track_index < 0 or track_index >= anim.get_track_count():
		return _error("TRACK_NOT_FOUND", "Track index not found: %d" % track_index)
	return null

func insert_key(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root: return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_mixer(root, str(params.get("player_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY: return resolved
	var mixer := resolved as AnimationMixer
	var library_name := _library_name(params)
	var library = _get_library(mixer, library_name)
	if typeof(library) == TYPE_DICTIONARY: return library
	var animation_name := _animation_name(params)
	var animation = _get_animation(library as AnimationLibrary, animation_name)
	if typeof(animation) == TYPE_DICTIONARY: return animation
	var anim := animation as Animation
	var track_index := int(params.get("track_index", -1))
	var track_error = _validate_track(anim, track_index)
	if track_error: return track_error
	var time := float(params.get("time", -1.0))
	var transition := float(params.get("transition", 1.0))
	if time < 0.0 or transition <= 0.0: return _error("INVALID_ARGUMENT", "Invalid key time or transition")
	if anim.track_find_key(track_index, time, Animation.FIND_MODE_EXACT) >= 0:
		return _error("KEY_EXISTS", "A key already exists at time %s" % time)
	var value = _variant_serializer.decode(params.get("value"))
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Insert Animation Key: " + animation_name, 0, mixer)
		undo_redo.add_do_method(anim, "track_insert_key", track_index, time, value, transition)
		undo_redo.add_undo_method(anim, "track_remove_key_at_time", track_index, time)
		undo_redo.commit_action()
	else:
		anim.track_insert_key(track_index, time, value, transition)
	var key_index := anim.track_find_key(track_index, time, Animation.FIND_MODE_EXACT)
	var result := _target_result(root, mixer, library_name, animation_name)
	result["track_index"] = track_index
	result["key_index"] = key_index
	result["time"] = time
	return result

func remove_key(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root: return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var resolved = _resolve_mixer(root, str(params.get("player_path", "")))
	if typeof(resolved) == TYPE_DICTIONARY: return resolved
	var mixer := resolved as AnimationMixer
	var library_name := _library_name(params)
	var library = _get_library(mixer, library_name)
	if typeof(library) == TYPE_DICTIONARY: return library
	var animation_name := _animation_name(params)
	var animation = _get_animation(library as AnimationLibrary, animation_name)
	if typeof(animation) == TYPE_DICTIONARY: return animation
	var anim := animation as Animation
	var track_index := int(params.get("track_index", -1))
	var track_error = _validate_track(anim, track_index)
	if track_error: return track_error
	var key_index := int(params.get("key_index", -1))
	if key_index < 0 or key_index >= anim.track_get_key_count(track_index):
		return _error("KEY_NOT_FOUND", "Key index not found: %d" % key_index)
	var time := anim.track_get_key_time(track_index, key_index)
	var value = anim.track_get_key_value(track_index, key_index)
	var transition := anim.track_get_key_transition(track_index, key_index)
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action("Remove Animation Key: " + animation_name, 0, mixer)
		undo_redo.add_do_method(anim, "track_remove_key", track_index, key_index)
		undo_redo.add_undo_method(anim, "track_insert_key", track_index, time, value, transition)
		undo_redo.commit_action()
	else:
		anim.track_remove_key(track_index, key_index)
	var result := _target_result(root, mixer, library_name, animation_name)
	result["track_index"] = track_index
	result["key_index"] = key_index
	result["time"] = time
	return result
