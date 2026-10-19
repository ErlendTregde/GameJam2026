extends RefCounted
## The canal through the mountains is the way out, by boat only: a swimmer is held back by an
## invisible wall and told they need the boat. The boat waits at island 3, the closest to it.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var terrain: Terrain = main.get_node("Terrain")
	var ocean: Ocean = main.get_node("Ocean")
	var p: Player = main.get_node("Player")
	var gate: CanalGate = main.get_node("CanalGate")
	var out := Vector2.from_angle(deg_to_rad(terrain.ring_gap_angle))
	var at := Vector2(gate.global_position.x, gate.global_position.z)
	assert(absf((at - terrain.ring_center).length() - terrain.ring_radius) < 30.0, "the gate is in the canal")
	# A swimmer heading out through the canal gets stopped at the gate.
	var start := at - out * 6.0
	p.global_position = Vector3(start.x, ocean.sea_level - 1.0, start.y)
	var message: Label = p.get_node("HUD/Message")
	for i in 240:
		var pushed := Vector2(p.global_position.x, p.global_position.z) + out * 0.15  # trying hard to swim out
		p.global_position = Vector3(pushed.x, p.global_position.y, pushed.y)
		await tree.physics_frame
	var now := Vector2(p.global_position.x, p.global_position.z)
	assert((now - at).dot(out) <= 0.5, "the swimmer can't get past the gate")
	assert(message.visible and message.text.contains("boat"), "told they need the boat")
	# The boat waits at island 3, the island closest to the canal.
	var boat: Boat = main.get_node("Boat")
	var big: IslandShape = main.get_node("Terrain/BigIsland")
	var boat_at := Vector2(boat.global_position.x, boat.global_position.z)
	assert(boat_at.distance_to(Vector2(big.position.x, big.position.z)) < big.radius + 25.0, "the boat is at island 3")
	assert(ocean.sea_level - terrain.get_floor_height(boat_at.x, boat_at.y) > 2.0, "in water deep enough to float")
	print("PASS test_canal")
	tree.quit()
