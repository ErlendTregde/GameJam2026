extends RefCounted
## A hunting shark follows the player out of the water and onto the beach, flopping along the
## ground in hops, and can still bite them there.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var ocean: Ocean = main.get_node("Ocean")
	var terrain: Terrain = main.get_node("Terrain")
	var zone: SharkZone = main.get_node("SharkZone")
	# The player stands on the beach, a few metres up from the water.
	p.global_position = Vector3(0, 3, 17)
	await tree.create_timer(1.0).timeout
	zone._spawn(p)
	var shark: Shark = zone._shark
	shark._circled = shark.warning_time  # skip the warning: straight to the hunt
	var on_land := false
	var heights := []
	var t := 0.0
	while t < 20.0 and p.health == p.max_health:
		await tree.physics_frame
		t += 1.0 / 60.0
		var floor_y := terrain.get_floor_height(shark.global_position.x, shark.global_position.z)
		if floor_y > ocean.sea_level:
			on_land = true
			heights.append(shark.global_position.y - floor_y)
	assert(on_land, "the shark came up onto the land")
	assert(not heights.is_empty() and heights.max() - heights.min() > 0.4, "it hops along the ground")
	assert(p.health < p.max_health, "it bit the player on land")
	print("PASS test_shark_land")
	tree.quit()
