extends RefCounted
## Level 2: island 2's water is deeper; the boat is locked for now; the Giant Shark (a bigger,
## tougher shark, circling the crater) is optional to kill (the boat stays locked).

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var terrain: Terrain = main.get_node("Terrain")
	var ocean: Ocean = main.get_node("Ocean")
	var home: IslandShape = main.get_node("Terrain/MainIsland")
	var isl2: IslandShape = main.get_node("Terrain/SmallIsland")
	var out := Vector3(1, 0, 0)
	var d1 := terrain.get_floor_height(home.position.x + home.radius + 30.0, home.position.z)
	var d2 := terrain.get_floor_height(isl2.position.x + isl2.radius + 30.0, isl2.position.z)
	assert(d2 < d1 - 4.0, "island 2's water is deeper (%.1f vs %.1f)" % [d2, d1])
	# The boat is locked.
	var boat: Boat = main.get_node("Boat")
	var p: Player = main.get_node("Player")
	assert(boat.locked, "boat starts locked")
	boat._on_helm_body_entered(p)
	var e := InputEventAction.new()
	e.action = "interact"
	e.pressed = true
	boat._unhandled_input(e)
	assert(not boat.driving, "can't take the helm while locked")
	boat._on_helm_body_exited(p)
	# Island 2 has its own shop.
	assert(main.has_node("Shop/ShopBoard2/Coco") and main.has_node("Shop/ShopBoard2/SellScale"), "island 2 shop with Coco and table")
	var zone: SharkZone = main.get_node("SharkZone")
	var shark: Shark = zone.spawned_shark()
	assert(shark != null and shark.display_name == "Giant Shark", "the Giant Shark is out there")
	assert(shark.health == 400.0 and shark.get_node("Model").scale.length() > Vector3(0.68, 0.68, 0.68).length() * 1.5, "bigger and tougher")
	shark.take_damage(400.0)
	assert(zone.defeated and boat.locked, "killing it is optional and unlocks nothing (the boat stays locked)")
	print("PASS test_level2")
	tree.quit()
