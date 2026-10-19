extends RefCounted
## The ground is a Terrain3D: the Terrain API reads its heights, and its collision covers the whole
## map (not only around the camera), matching those heights.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	await tree.physics_frame
	var terrain: Terrain = main.get_node("Terrain")
	assert(terrain.terrain3d != null, "the ground is a Terrain3D")
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for p: Vector2 in [Vector2(0, 17), Vector2(40, 60), Vector2(-130, -60), Vector2(300, -300)]:
		var h := terrain.get_floor_height(p.x, p.y)
		assert(is_finite(h), "floor height is a number at %s" % p)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 200, p.y), Vector3(p.x, -300, p.y), 1))
		assert(not hit.is_empty() and absf(hit.position.y - h) < 0.5, "collision matches the height at %s (%s vs %s)" % [p, hit.get("position"), h])
	assert(terrain.get_floor_height(900, 900) == -100.0, "outside the terrain is deep water, not NaN")
	print("PASS test_terrain3d")
	tree.quit()
