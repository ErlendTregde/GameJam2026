class_name HitFlash
## Hit feedback: tints a model red for a moment, then fades back to its normal colour
## (through the toon shader's per-object `hit_tint`).


static func flash(model: Node3D, strength := 0.8, time := 0.3) -> void:
	var meshes := model.find_children("*", "GeometryInstance3D", true, false)
	if model is GeometryInstance3D:
		meshes.append(model)
	var tint := func(a: float) -> void:
		for mesh in meshes:  # untyped: some may have been freed meanwhile
			if is_instance_valid(mesh):
				mesh.set_instance_shader_parameter("hit_tint", Color(1, 0, 0, a))
	tint.call(strength)
	# On the tree, not the model: keeps fading even if the model pauses off screen.
	model.get_tree().create_tween().tween_method(tint, strength, 0.0, time)
