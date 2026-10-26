@tool
extends RefCounted

var _editor_interface

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

func _undo_redo() -> EditorUndoRedoManager:
	return _editor_interface.get_editor_undo_redo()

func _color(value, label: String):
	if typeof(value) != TYPE_DICTIONARY:
		return _error("INVALID_ARGUMENT", "%s must be an object with r/g/b/a" % label)
	var dict: Dictionary = value
	for key in ["r", "g", "b"]:
		if not dict.has(key):
			return _error("INVALID_ARGUMENT", "%s must contain r/g/b" % label)
	var r := float(dict.get("r", 0.0))
	var g := float(dict.get("g", 0.0))
	var b := float(dict.get("b", 0.0))
	var a := float(dict.get("a", 1.0))
	if not is_finite(r) or not is_finite(g) or not is_finite(b) or not is_finite(a):
		return _error("INVALID_ARGUMENT", "%s channels must be finite" % label)
	if a < 0.0 or a > 1.0:
		return _error("INVALID_ARGUMENT", "%s.a must be in [0,1]" % label)
	return Color(r, g, b, a)

func _color_dict(value: Color) -> Dictionary:
	return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}

func _load_texture(value, label: String):
	if value == null:
		return null
	var resource_path := str(value)
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		return _error("RESOURCE_NOT_FOUND", "%s resource not found: %s" % [label, resource_path])
	var loaded = ResourceLoader.load(resource_path)
	if not loaded:
		return _error("RESOURCE_NOT_FOUND", "%s resource not found: %s" % [label, resource_path])
	if not loaded is Texture2D:
		return _error("INVALID_RESOURCE_TYPE", "%s is not a Texture2D: %s" % [label, resource_path])
	return loaded as Texture2D

func _resolve_target(root: Node, params: Dictionary) -> Dictionary:
	var path_str := str(params.get("node_path", ""))
	var node := _resolve_node(root, path_str)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % path_str)
	if not node is GeometryInstance3D:
		return _error("INVALID_NODE_TYPE", "Node is not a GeometryInstance3D: %s" % path_str)
	var geometry := node as GeometryInstance3D
	if not params.has("surface_index"):
		var surface_count := 0
		if geometry is MeshInstance3D and (geometry as MeshInstance3D).mesh:
			surface_count = (geometry as MeshInstance3D).mesh.get_surface_count()
		return {
			"node": geometry,
			"surface_index": -1,
			"slot": "override",
			"surface_count": surface_count,
			"material": geometry.material_override
		}
	if not geometry is MeshInstance3D:
		return _error("INVALID_NODE_TYPE", "surface_index requires a MeshInstance3D")
	var mesh_instance := geometry as MeshInstance3D
	if not mesh_instance.mesh:
		return _error("SURFACE_NOT_FOUND", "MeshInstance3D has no mesh surfaces")
	var surface_index := int(params.get("surface_index", -1))
	var surface_count := mesh_instance.mesh.get_surface_count()
	if surface_index < 0 or surface_index >= surface_count:
		return _error("SURFACE_NOT_FOUND", "surface_index %d is outside mesh surface count %d" % [surface_index, surface_count])
	return {
		"node": mesh_instance,
		"surface_index": surface_index,
		"slot": "surface",
		"surface_count": surface_count,
		"material": mesh_instance.get_surface_override_material(surface_index)
	}

func _assign_material(target_node: GeometryInstance3D, surface_index: int, material: Material) -> void:
	if surface_index < 0:
		target_node.material_override = material
	else:
		(target_node as MeshInstance3D).set_surface_override_material(surface_index, material)

func _commit_material_change(action_name: String, target: Dictionary, next_material: Material) -> void:
	var target_node := target.get("node") as GeometryInstance3D
	var surface_index := int(target.get("surface_index", -1))
	var previous := target.get("material") as Material
	var undo_redo := _undo_redo()
	if undo_redo:
		undo_redo.create_action(action_name, 0, target_node)
		undo_redo.add_do_method(self, "_assign_material", target_node, surface_index, next_material)
		undo_redo.add_undo_method(self, "_assign_material", target_node, surface_index, previous)
		undo_redo.commit_action()
	else:
		_assign_material(target_node, surface_index, next_material)

func _cull_name(value: int) -> String:
	match value:
		BaseMaterial3D.CULL_FRONT: return "front"
		BaseMaterial3D.CULL_DISABLED: return "disabled"
		_: return "back"

func _transparency_name(value: int) -> String:
	match value:
		BaseMaterial3D.TRANSPARENCY_ALPHA: return "alpha"
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: return "alpha_scissor"
		BaseMaterial3D.TRANSPARENCY_ALPHA_HASH: return "alpha_hash"
		BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: return "alpha_depth_pre_pass"
		_: return "disabled"

func _material_summary(material: Material) -> Dictionary:
	if not material:
		return {"kind": "none", "type": "", "resource_path": ""}
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		return {
			"kind": "standard",
			"type": standard.get_class(),
			"resource_path": standard.resource_path,
			"albedo_color": _color_dict(standard.albedo_color),
			"albedo_texture_path": standard.albedo_texture.resource_path if standard.albedo_texture else null,
			"metallic": standard.metallic,
			"roughness": standard.roughness,
			"emission_enabled": standard.emission_enabled,
			"emission": _color_dict(standard.emission),
			"emission_energy_multiplier": standard.emission_energy_multiplier,
			"normal_enabled": standard.normal_enabled,
			"normal_texture_path": standard.normal_texture.resource_path if standard.normal_texture else null,
			"normal_scale": standard.normal_scale,
			"cull_mode": _cull_name(standard.cull_mode),
			"transparency": _transparency_name(standard.transparency)
		}
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		return {
			"kind": "shader",
			"type": shader_material.get_class(),
			"resource_path": shader_material.resource_path,
			"shader_path": shader_material.shader.resource_path if shader_material.shader else ""
		}
	return {"kind": "other", "type": material.get_class(), "resource_path": material.resource_path}

func _material_result(root: Node, target: Dictionary) -> Dictionary:
	var target_node := target.get("node") as GeometryInstance3D
	return {
		"node_path": _logical_path(root, target_node),
		"surface_index": null if int(target.get("surface_index", -1)) < 0 else int(target.get("surface_index")),
		"slot": str(target.get("slot", "override")),
		"surface_count": int(target.get("surface_count", 0)),
		"material": _material_summary(target.get("material") as Material)
	}

func _refresh_target_material(target: Dictionary) -> void:
	var node := target.get("node") as GeometryInstance3D
	var surface_index := int(target.get("surface_index", -1))
	target["material"] = node.material_override if surface_index < 0 else (node as MeshInstance3D).get_surface_override_material(surface_index)

func inspect_material3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root:
		return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var target := _resolve_target(root, params)
	if target.has("__error"):
		return target
	return _material_result(root, target)

func _apply_standard_fields(material: StandardMaterial3D, params: Dictionary):
	if params.has("albedo_color"):
		var parsed_albedo = _color(params.get("albedo_color"), "albedo_color")
		if typeof(parsed_albedo) == TYPE_DICTIONARY:
			return parsed_albedo
		material.albedo_color = parsed_albedo
	if params.has("albedo_texture_path"):
		var albedo_texture = _load_texture(params.get("albedo_texture_path"), "albedo_texture_path")
		if typeof(albedo_texture) == TYPE_DICTIONARY:
			return albedo_texture
		material.albedo_texture = albedo_texture as Texture2D
	if params.has("metallic"):
		var metallic := float(params.get("metallic"))
		if metallic < 0.0 or metallic > 1.0: return _error("INVALID_ARGUMENT", "metallic must be in [0,1]")
		material.metallic = metallic
	if params.has("roughness"):
		var roughness := float(params.get("roughness"))
		if roughness < 0.0 or roughness > 1.0: return _error("INVALID_ARGUMENT", "roughness must be in [0,1]")
		material.roughness = roughness
	if params.has("emission_enabled"):
		material.emission_enabled = bool(params.get("emission_enabled"))
	if params.has("emission"):
		var parsed_emission = _color(params.get("emission"), "emission")
		if typeof(parsed_emission) == TYPE_DICTIONARY:
			return parsed_emission
		material.emission = parsed_emission
	if params.has("emission_energy_multiplier"):
		var emission_energy := float(params.get("emission_energy_multiplier"))
		if emission_energy < 0.0: return _error("INVALID_ARGUMENT", "emission_energy_multiplier must be nonnegative")
		material.emission_energy_multiplier = emission_energy
	if params.has("normal_enabled"):
		material.normal_enabled = bool(params.get("normal_enabled"))
	if params.has("normal_texture_path"):
		var normal_texture = _load_texture(params.get("normal_texture_path"), "normal_texture_path")
		if typeof(normal_texture) == TYPE_DICTIONARY:
			return normal_texture
		material.normal_texture = normal_texture as Texture2D
	if params.has("normal_scale"):
		var normal_strength := float(params.get("normal_scale"))
		if normal_strength < 0.0: return _error("INVALID_ARGUMENT", "normal_scale must be nonnegative")
		material.normal_scale = normal_strength
	if params.has("cull_mode"):
		match str(params.get("cull_mode")):
			"front": material.cull_mode = BaseMaterial3D.CULL_FRONT
			"disabled": material.cull_mode = BaseMaterial3D.CULL_DISABLED
			"back": material.cull_mode = BaseMaterial3D.CULL_BACK
			_: return _error("INVALID_ARGUMENT", "Unsupported cull_mode")
	if params.has("transparency"):
		match str(params.get("transparency")):
			"alpha": material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"alpha_scissor": material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			"alpha_hash": material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			"alpha_depth_pre_pass": material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			"disabled": material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_: return _error("INVALID_ARGUMENT", "Unsupported transparency")
	return true

func set_standard_material3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root: return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var target := _resolve_target(root, params)
	if target.has("__error"): return target
	var material := StandardMaterial3D.new()
	var applied = _apply_standard_fields(material, params)
	if typeof(applied) == TYPE_DICTIONARY: return applied
	var target_node := target.get("node") as GeometryInstance3D
	_commit_material_change("Set StandardMaterial3D", target, material)
	_refresh_target_material(target)
	return _material_result(root, target)

func configure_standard_material3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root: return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var target := _resolve_target(root, params)
	if target.has("__error"): return target
	var current := target.get("material") as Material
	if not current is StandardMaterial3D:
		return _error("MATERIAL_TYPE_MISMATCH", "Selected material is not a StandardMaterial3D")
	var material := current.duplicate(true) as StandardMaterial3D
	var applied = _apply_standard_fields(material, params)
	if typeof(applied) == TYPE_DICTIONARY: return applied
	var target_node := target.get("node") as GeometryInstance3D
	_commit_material_change("Configure StandardMaterial3D", target, material)
	_refresh_target_material(target)
	return _material_result(root, target)

func clear_material3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root: return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var target := _resolve_target(root, params)
	if target.has("__error"): return target
	var target_node := target.get("node") as GeometryInstance3D
	_commit_material_change("Clear Material3D", target, null)
	_refresh_target_material(target)
	return _material_result(root, target)

func _shader_uniforms(material: ShaderMaterial):
	if not material.shader:
		return []
	var raw: Array = material.shader.get_shader_uniform_list(false)
	if raw.size() > 256:
		return _error("LIMIT_EXCEEDED", "Shader exposes more than 256 uniforms")
	var result: Array = []
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = item
		var name := str(info.get("name", ""))
		if name.is_empty():
			continue
		result.append({
			"name": name,
			"type": int(info.get("type", TYPE_NIL)),
			"hint": int(info.get("hint", 0)),
			"hint_string": str(info.get("hint_string", "")),
			"usage": int(info.get("usage", 0)),
			"value": VariantSerializer.serialize(material.get_shader_parameter(StringName(name)))
		})
	return result

func _shader_result(root: Node, target: Dictionary):
	var current := target.get("material") as Material
	if not current is ShaderMaterial:
		return _error("MATERIAL_TYPE_MISMATCH", "Selected material is not a ShaderMaterial")
	var material := current as ShaderMaterial
	if not material.shader:
		return _error("MATERIAL_TYPE_MISMATCH", "ShaderMaterial has no Shader")
	var uniforms = _shader_uniforms(material)
	if typeof(uniforms) == TYPE_DICTIONARY:
		return uniforms
	var base := _material_result(root, target)
	base["shader"] = {
		"mode": "spatial" if material.shader.get_mode() == Shader.MODE_SPATIAL else str(material.shader.get_mode()),
		"resource_path": material.shader.resource_path,
		"code": material.shader.code,
		"uniforms": uniforms
	}
	return base

func inspect_shader3d(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root: return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var target := _resolve_target(root, params)
	if target.has("__error"): return target
	return _shader_result(root, target)

func _spatial_code(code: String) -> bool:
	var regex := RegEx.new()
	if regex.compile("(?i)\\bshader_type\\s+spatial\\s*;") != OK:
		return false
	return regex.search(code) != null

func set_shader3d_code(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root: return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var target := _resolve_target(root, params)
	if target.has("__error"): return target
	var code := str(params.get("code", ""))
	if code.is_empty() or code.length() > 65536 or not _spatial_code(code):
		return _error("INVALID_ARGUMENT", "Shader code must be <= 65536 characters and declare shader_type spatial;")
	var current := target.get("material") as Material
	var material: ShaderMaterial = null
	if current is ShaderMaterial:
		material = current.duplicate(true) as ShaderMaterial
	else:
		material = ShaderMaterial.new()
	var shader: Shader = null
	if material.shader:
		shader = material.shader.duplicate(true) as Shader
	else:
		shader = Shader.new()
	shader.code = code
	material.shader = shader
	var target_node := target.get("node") as GeometryInstance3D
	_commit_material_change("Set Shader3D Code", target, material)
	_refresh_target_material(target)
	return _shader_result(root, target)

func _uniform_exists(shader: Shader, requested: String) -> bool:
	var raw: Array = shader.get_shader_uniform_list(false)
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = item
		if str(info.get("name", "")) == requested:
			return true
	return false

func set_shader3d_parameter(params: Dictionary) -> Dictionary:
	var root := _root()
	if not root: return _error("NO_OPEN_SCENE", "No scene is currently open in the editor")
	var target := _resolve_target(root, params)
	if target.has("__error"): return target
	var current := target.get("material") as Material
	if not current is ShaderMaterial or not (current as ShaderMaterial).shader:
		return _error("MATERIAL_TYPE_MISMATCH", "Selected material is not a ShaderMaterial with a Shader")
	var requested := str(params.get("name", ""))
	var shader := (current as ShaderMaterial).shader
	if not _uniform_exists(shader, requested):
		return _error("UNIFORM_NOT_FOUND", "Shader uniform not found: %s" % requested)
	var material := current.duplicate(true) as ShaderMaterial
	var decoded = VariantSerializer.deserialize(params.get("value"))
	material.set_shader_parameter(StringName(requested), decoded)
	var target_node := target.get("node") as GeometryInstance3D
	_commit_material_change("Set Shader3D Parameter", target, material)
	_refresh_target_material(target)
	return _shader_result(root, target)
