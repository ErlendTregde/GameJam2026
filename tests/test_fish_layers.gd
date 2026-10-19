extends RefCounted
## Fish live in depth layers: yellow fish near the surface, blue fish a bit deeper, red snappers and
## groupers deep down. Each stays inside its own band (m below the surface), and deeper fish are
## worth more.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var ocean: Ocean = main.get_node("Ocean")
	var terrain: Terrain = main.get_node("Terrain")
	var kinds := ["yellow_fish", "blue_fish", "red_snapper", "deep_grouper"]
	var price := func(k: String) -> int: return (load("res://items/%s.tres" % k) as ItemData).price
	assert(price.call("yellow_fish") < price.call("blue_fish") and price.call("blue_fish") < price.call("deep_grouper") \
			and price.call("deep_grouper") <= price.call("red_snapper"), "deeper fish are worth more")
	# Deep open water, so every band fits; each fish starts on the wrong side of its band.
	var spot := Vector3.INF
	for x in range(-200, 201, 20):
		for z in range(-200, 201, 20):
			if spot == Vector3.INF and ocean.sea_level - terrain.get_floor_height(x, z) > 38.0 					and ocean.sea_level - terrain.get_floor_height(x + 9, z) > 38.0:
				spot = Vector3(x, 0, z)
	assert(spot != Vector3.INF, "found deep open water")
	var fishes: Array[Fish] = []
	for k: String in kinds:
		var fish: Fish = load("res://scenes/fish/%s.tscn" % k).instantiate()
		fish.ocean = ocean
		fish.terrain = terrain
		fish.max_depth = 100.0
		fish.get_node("PauseOffScreen").free()  # no screen in a headless test: keep it swimming
		var wrong := fish.swim_bottom + 5.0 if fish.swim_top < 1.0 else 1.0  # shallow fish deep, deep fish shallow
		fish.position = spot + Vector3(kinds.find(k) * 3.0, ocean.sea_level - wrong, 0)
		main.add_child(fish)
		fishes.append(fish)
	assert(fishes[0].swim_bottom <= fishes[1].swim_bottom and fishes[1].swim_bottom <= fishes[2].swim_top + 6.0, "bands go deeper")
	await tree.physics_frame
	await tree.physics_frame  # one step to settle into its layer
	for i in 600:
		await tree.physics_frame
		for f in fishes:
			var depth := ocean.sea_level - f.global_position.y
			assert(depth >= f.swim_top - 0.3 and depth <= f.swim_bottom + 0.3, "%s stays in its band (at %.1f m, band %.0f-%.0f)" % [f.name, depth, f.swim_top, f.swim_bottom])
	print("PASS test_fish_layers")
	tree.quit()
