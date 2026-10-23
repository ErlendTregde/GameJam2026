extends RefCounted
## Swimming along the surface you ride the waves: a crest passing over doesn't pull you under and
## leave you stuck below (you only go down by diving). Swims out through the canal's swell.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(0.5).timeout
	var p: Player = main.get_node("Player")
	var ocean: Ocean = main.get_node("Ocean")
	var gate: Node3D = main.get_node("CanalGate")
	var out: Vector3 = -gate.global_basis.z
	p.global_position = gate.global_position - out * 30.0 + Vector3(0, -0.3, 0)
	p.rotation.y = atan2(-out.x, -out.z)
	Input.action_press("move_forward")
	var under := 0.0
	var t := 0.0
	while t < 12.0:
		await tree.physics_frame
		t += 1.0 / 60.0
		if t > 2.0 and p._underwater:
			under += 1.0 / 60.0
	Input.action_release("move_forward")
	assert(under < 1.5, "stays floating on the waves (%.1f s under)" % under)
	print("PASS test_wave_float")
	tree.quit()
