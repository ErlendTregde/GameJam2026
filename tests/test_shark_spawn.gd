extends RefCounted
## Wherever the player swims and whichever way they face (even with the island behind them),
## the shark appears in water deep enough to swim in, and gets moving.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	p.set_physics_process(false)
	var ocean: Ocean = main.get_node("Ocean")
	var terrain: Terrain = main.get_node("Terrain")
	var stuck := []
	var tries := 0
	for zone_name in ["SharkZone", "SharkZone2"]:
		var zone: SharkZone = main.get_node(zone_name)
		var island: IslandShape = main.get_node("Terrain/MainIsland" if zone_name == "SharkZone" else "Terrain/SmallIsland")
		for i in 8:
			var out := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 8.0)
			for facing_out in [true, false]:
				var pos := island.position + out * (island.radius + 25.0)
				p.global_position = Vector3(pos.x, ocean.sea_level - 2.0, pos.z)
				var look := out if facing_out else -out
				p.rotation = Vector3(0, atan2(-look.x, -look.z), 0)
				await tree.process_frame
				zone._spawn()
				var shark: Shark = zone._shark
				var start := shark.global_position
				var depth := ocean.sea_level - terrain.get_floor_height(start.x, start.z)
				for f in 120:
					await tree.physics_frame
				tries += 1
				if depth < shark.min_depth or shark.global_position.distance_to(start) < 3.0:
					stuck.append("%s dir %d %s: depth %.1f moved %.1f" % [zone_name, i, "out" if facing_out else "in", depth, shark.global_position.distance_to(start)])
				shark.queue_free()
				zone._shark = null
				await tree.process_frame
	print("stuck: ", stuck.size(), "/", tries, " ", stuck)
	assert(stuck.is_empty(), "every shark spawns in open water and swims")
	print("PASS test_shark_spawn")
	tree.quit()
