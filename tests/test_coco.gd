extends RefCounted
## Coco turns to face the player when close, from either side.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	p.set_physics_process(false)
	var coco: Coco = main.find_child("Coco", true, false)
	var head: Node3D = coco.get_node("Head")
	for side: Vector3 in [coco.global_basis.x, -coco.global_basis.x]:
		p.global_position = coco.global_position + side * 2.5
		await tree.create_timer(1.5).timeout
		var face := head.global_basis.z.normalized()
		var to := (p.global_position - head.global_position) * Vector3(1, 0, 1)
		assert(face.dot(to.normalized()) > 0.9, "Coco faces the player")
	print("PASS test_coco")
	tree.quit()
