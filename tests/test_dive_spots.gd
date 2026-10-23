extends RefCounted
## Dive spots around the map: a buoy on the surface and a chest of gold coins on the sea floor below
## it. The deeper the spot, the more coins. Corals and fish around each; no boss near them. A
## super rare pink fish lives at the deepest one.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var terrain: Terrain = main.get_node("Terrain")
	var ocean: Ocean = main.get_node("Ocean")
	var coin: ItemData = load("res://items/coin.tres")
	var spots: Array = main.get_node("DiveSpots").get_children()
	assert(spots.size() >= 3 and spots.size() <= 4, "3-4 dive spots (%d)" % spots.size())
	var zone: SharkZone = main.get_node("SharkZone")
	var by_depth := []
	for spot: Node3D in spots:
		var chest: Chest = spot.get_node("Chest")
		var buoy: Node3D = spot.get_node("Buoy")
		var at := Vector2(chest.global_position.x, chest.global_position.z)
		assert(Vector2(buoy.global_position.x, buoy.global_position.z).distance_to(at) < 4.0, "%s: the buoy marks the chest" % spot.name)
		var floor_y := terrain.get_floor_height(at.x, at.y)
		assert(absf(chest.global_position.y - floor_y) < 0.4, "%s: the chest is on the sea floor" % spot.name)
		assert(chest.cost == 0 and chest.reset_time > 0.0, "%s: free, and it fills up again" % spot.name)
		var coins := chest.loot.always.count(coin)
		assert(coins > 0 and chest.loot.always.size() == coins, "%s: a chest of coins" % spot.name)
		var depth := ocean.sea_level - floor_y
		by_depth.append([depth, coins])
		var boss := zone.patrol.to_global(zone.patrol.curve.get_closest_point(zone.patrol.to_local(chest.global_position)))
		assert(boss.distance_to(chest.global_position) > 60.0, "%s: no boss there" % spot.name)
	by_depth.sort()
	for i in range(1, by_depth.size()):
		assert(by_depth[i][0] > by_depth[i - 1][0] + 5.0, "the spots are of different depths")
		assert(by_depth[i][1] > by_depth[i - 1][1], "deeper spots hold more coins (%s)" % [by_depth])
	assert(by_depth[0][0] < 16.0 and by_depth[-1][0] > 38.0, "from easy to very deep (%.0f-%.0f m)" % [by_depth[0][0], by_depth[-1][0]])
	# Life around them.
	assert(main.get_node("Reef/SpotCorals").get_children(true).size() > 0, "corals at the dive spots")
	var pink: ItemData = load("res://items/pink_fish.tres")
	for fish_item: String in ["red_snapper", "blue_fish", "deep_grouper"]:
		assert(pink.price > (load("res://items/%s.tres" % fish_item) as ItemData).price * 2, "the pink fish is worth much more than a %s" % fish_item)
	var pinks := main.find_children("*", "FishSpawner", true, false).filter(func(s: FishSpawner) -> bool:
		return s.fish_scenes.any(func(f: PackedScene) -> bool: return f.resource_path.ends_with("pink_fish.tscn")))
	assert(pinks.size() == 1 and pinks[0].count <= 2, "pink fish only in one place, and few of them")
	print("PASS test_dive_spots")
	tree.quit()
