extends RefCounted
## Spawned fish keep swimming around their spawner instead of getting stuck against their border
## (the shallows or the deep drop-off), for every spawner, also ones away from the world origin.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	p.set_physics_process(false)
	# Every spawner fills up at once (not only near the player), then all fish are watched together.
	var spawners: Array = main.get_node("Fish").get_children()
	for spawner: FishSpawner in spawners:
		spawner.active_distance = 100000.0
		spawner.inactive_distance = 200000.0
	await tree.create_timer(0.5).timeout
	var fishes := {}  # fish -> its spawner
	for spawner: FishSpawner in spawners:
		var own: Array = spawner.get_children().filter(func(n: Node) -> bool: return n is Fish)
		assert(not own.is_empty(), "%s spawned fish" % spawner.name)
		for fish: Fish in own:
			fish.get_node("PauseOffScreen").free()  # headless: nothing is ever on screen
			fish.process_mode = Node.PROCESS_MODE_INHERIT
			fishes[fish] = spawner
	var before := {}
	for fish: Fish in fishes:
		before[fish] = fish.global_position
	var least := {}
	for window in 5:  # every 3 s, how far each fish got; a stuck fish wiggles in place
		await tree.create_timer(3.0).timeout
		for fish: Fish in fishes:
			var spawner: FishSpawner = fishes[fish]
			least[spawner] = minf(least.get(spawner, INF), fish.global_position.distance_to(before[fish]))
			before[fish] = fish.global_position
	for spawner: FishSpawner in spawners:
		print("%s: least progress per 3 s %.1f m" % [spawner.name, least[spawner]])
		assert(least[spawner] > 0.8, "%s: no fish stuck at its border" % spawner.name)
	# Each fish stays near its spawner.
	for fish: Fish in fishes:
		var spawner: FishSpawner = fishes[fish]
		var d := Vector2(fish.global_position.x - spawner.global_position.x, fish.global_position.z - spawner.global_position.z).length()
		assert(d < spawner.radius + 20.0, "%s: fish stays near its spawner (%.0f m)" % [spawner.name, d])
	print("PASS test_fish_border")
	tree.quit()
