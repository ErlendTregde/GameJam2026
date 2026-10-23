extends RefCounted
## Island 3 is a stone island (no palms or grass) with small rocks around, a lighthouse (without
## its blue base) and Coco's selling table. Every island has a table to sell at, and the islands
## have no chests any more.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(0.5).timeout
	var terrain: Terrain = main.get_node("Terrain")
	var big: IslandShape = main.get_node("Terrain/BigIsland")
	assert(big.rocky and big.radius == 28.0, "island 3 is stone, the same size as before")
	var near := func(node: Node3D, island: IslandShape, extra: float) -> bool:
		return Vector2(node.global_position.x - island.position.x, node.global_position.z - island.position.z).length() < island.radius + extra
	assert(main.get_node("Decor/Palms").rocky_islands == Scatter.Rocky.SKIP, "no palms on the stone island")
	var stones: Scatter = main.get_node("Decor/IslandStones")
	assert(stones.rocky_islands == Scatter.Rocky.ONLY and stones.get_children(true).size() > 0, "small rocks around island 3")
	var lighthouse: Node3D = main.get_node("Lighthouse")
	assert(near.call(lighthouse, big, 0.0), "the lighthouse is on island 3")
	assert(not lighthouse.find_child("Cylinder_000", true, false).visible, "without the blue base")
	var tower_foot := lighthouse.global_position.y + 0.4 * lighthouse.scale.y  # the tower starts 0.4 up in the model, above the hidden base
	assert(absf(tower_foot - terrain.get_floor_height(lighthouse.global_position.x, lighthouse.global_position.z)) < 0.6, "standing on the ground")
	for island: IslandShape in terrain.find_children("*", "IslandShape", false):
		var table := main.find_children("*", "SellScale", true, false).filter(func(s: Node3D) -> bool: return near.call(s, island, 10.0))
		assert(not table.is_empty(), "%s has a table to sell to Coco" % island.name)
	for chest: Chest in main.find_children("*", "Chest", true, false):
		for island: IslandShape in terrain.find_children("*", "IslandShape", false):
			assert(not near.call(chest, island, 5.0), "no chest on %s (%s)" % [island.name, chest.name])
	print("PASS test_island3")
	tree.quit()
