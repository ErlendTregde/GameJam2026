@tool
extends EditorScenePostImport
## Import script (Import dock > Import Script): swaps every material of an imported model for
## the shared toon shader, keeping the model's own textures, so all assets share one style.

const TOON := preload("res://shaders/toon.gdshader")


func _post_import(scene: Node) -> Object:
	var converted := {}
	for mesh_instance in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_instance.mesh
		for i in mesh.get_surface_count():
			var original := mesh.surface_get_material(i) as BaseMaterial3D
			if original:
				if original not in converted:
					converted[original] = _toon(original)
				mesh.surface_set_material(i, converted[original])
	return scene


func _toon(original: BaseMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TOON
	material.resource_name = original.resource_name
	material.set_shader_parameter("albedo_color", original.albedo_color)
	material.set_shader_parameter("albedo_tex", original.albedo_texture)
	material.set_shader_parameter("use_vertex_color", original.vertex_color_use_as_albedo)
	if original.normal_enabled and original.normal_texture:
		material.set_shader_parameter("use_normal_map", true)
		material.set_shader_parameter("normal_tex", original.normal_texture)
	return material
