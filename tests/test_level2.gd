extends SceneTree
## Level 2: island 2's water is deeper; its boat is locked; swimming there is safe, but diving
## deep brings the Giant Shark (a bigger, tougher shark); killing it unlocks the boat.

func _hold(p: Player, pos: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		p.global_position = pos
		p.velocity = Vector3.ZERO
		await physics_frame
		t += 1.0 / 60.0


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
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
	# Level 1 done: its shark zone is cleared.
	main.get_node("SharkZone").defeated = true
	var zone: SharkZone = main.get_node("SharkZone2")
	var water := isl2.position + Vector3(isl2.radius + 35.0, 0, 0)
	# Swimming near the surface there is safe.
	await _hold(p, Vector3(water.x, ocean.sea_level - 1.5, water.z), 3.0)
	assert(zone._shark == null, "no boss while swimming near the surface")
	# Diving deep brings the Giant Shark.
	await _hold(p, Vector3(water.x, ocean.sea_level - 10.0, water.z), 2.0)
	var shark: Shark = zone._shark
	assert(shark != null and shark.display_name == "Giant Shark", "diving deep brings the Giant Shark")
	assert(shark.health == 400.0 and shark.get_node("Model").scale.length() > Vector3(0.68, 0.68, 0.68).length() * 1.5, "bigger and tougher")
	shark.take_damage(400.0)
	assert(zone.defeated and not boat.locked, "killing it unlocks the boat")
	print("PASS test_level2")
	quit()
