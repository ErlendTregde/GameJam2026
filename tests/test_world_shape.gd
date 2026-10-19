extends RefCounted
## The world's shape: a ring of mountains all around the three islands (no swimming out of the
## world), and the crater halfway between island 1 and island 2 that gets gradually deeper toward
## its middle (a bowl, no cliff), with the deep chest and statue on its floor.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var terrain: Terrain = main.get_node("Terrain")
	var ocean: Ocean = main.get_node("Ocean")
	# Mountains: a closed wall all the way around, well above the water.
	var c := terrain.ring_center
	for i in 72:
		var dir := Vector2.from_angle(i * TAU / 72.0)
		var top := -INF
		for r in range(int(terrain.ring_radius), int(terrain.ring_radius + terrain.ring_width) + 1, 2):
			var p := c + dir * r
			top = maxf(top, terrain.get_floor_height(p.x, p.y))
		assert(top > ocean.sea_level + 15.0, "mountains block the way out at %d degrees (top %.1f)" % [i * 5, top])
	for island: IslandShape in terrain.find_children("*", "IslandShape", false):
		var at := Vector2(island.position.x, island.position.z)
		assert(at.distance_to(c) + island.radius < terrain.ring_radius - 20.0, "%s is inside the ring" % island.name)
	# Crater: halfway between island 1 and island 2, deepest in the middle, getting deeper smoothly.
	var mid := (Vector2(0, 0) + Vector2(-130, -60)) * 0.5
	assert(terrain.crater_center.distance_to(mid) < 10.0, "the crater is between island 1 and 2")
	var cc := terrain.crater_center
	assert(absf(terrain.get_floor_height(cc.x, cc.y) + terrain.crater_depth) < 1.0, "deepest in the middle")
	for i in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0)
		var last := terrain.get_floor_height(cc.x, cc.y)
		for r in range(2, int(terrain.crater_radius * 0.8), 2):
			var p := cc + dir * r
			var h := terrain.get_floor_height(p.x, p.y)
			assert(h - last < 4.0, "no cliff in the crater (%.1f m step at r=%d)" % [h - last, r])
			last = h
	var chest: Node3D = main.get_node("Chests/DeepChest")
	var chest_at := Vector2(chest.global_position.x, chest.global_position.z)
	assert(chest_at.distance_to(cc) < 4.0, "the chest is in the middle of the crater")
	assert(absf(chest.global_position.y - terrain.get_floor_height(chest_at.x, chest_at.y)) < 0.3, "on the floor")
	assert(main.get_node("Statue").global_position.distance_to(chest.global_position) < 6.0, "the statue is next to it")
	# The Giant Shark circles down in the crater.
	var zone2: SharkZone = main.get_node("SharkZone2")
	var loop := zone2.patrol.to_global(zone2.patrol.curve.sample_baked(0.0))
	assert(Vector2(loop.x, loop.z).distance_to(cc) < terrain.crater_radius * 0.5 and loop.y < ocean.sea_level - 15.0, "the Giant Shark patrols down in the crater")
	print("PASS test_world_shape")
	tree.quit()
