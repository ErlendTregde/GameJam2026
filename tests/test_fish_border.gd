extends SceneTree
## Spawned fish keep swimming around their spawner instead of getting stuck against their border
## (the shallows or the deep drop-off), for every spawner, also ones away from the world origin.

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	p.set_physics_process(false)
	for spawner: Node3D in main.get_node("Fish").get_children():
		p.global_position = spawner.global_position + Vector3.UP * 5.0
		await create_timer(0.3).timeout
		var fishes: Array = spawner.get_children().filter(func(n: Node) -> bool: return n is Fish)
		assert(not fishes.is_empty(), "%s spawned fish" % spawner.name)
		for fish: Fish in fishes:
			fish.get_node("PauseOffScreen").free()  # headless: nothing is ever on screen
			fish.process_mode = Node.PROCESS_MODE_INHERIT
		var before := fishes.map(func(f: Fish) -> Vector3: return f.global_position)
		var least := INF
		for window in 5:  # every 3 s, how far each fish got; a stuck fish wiggles in place
			await create_timer(3.0).timeout
			for i in fishes.size():
				least = minf(least, fishes[i].global_position.distance_to(before[i]))
				before[i] = fishes[i].global_position
		print("%s: least progress per 3 s %.1f m" % [spawner.name, least])
		assert(least > 0.8, "%s: no fish stuck at its border" % spawner.name)
		# Each fish stays near its spawner.
		for fish: Fish in fishes:
			var d := Vector2(fish.global_position.x - spawner.global_position.x, fish.global_position.z - spawner.global_position.z).length()
			assert(d < spawner.radius + 20.0, "%s: fish stays near its spawner (%.0f m)" % [spawner.name, d])
	print("PASS test_fish_border")
	quit()
