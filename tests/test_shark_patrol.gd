extends RefCounted
## The boss is always out there swimming its patrol path; it hunts a swimmer who comes close,
## gives up when they escape, and swims back to its patrol (it never despawns).

var tree: SceneTree


func _wait(seconds: float, hold: Callable = Callable(), until: Callable = Callable()) -> void:
	var t := 0.0
	while t < seconds:
		if hold.is_valid():
			hold.call()
		if until.is_valid() and until.call():
			return
		await tree.physics_frame
		t += 1.0 / 60.0


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var zone: SharkZone = main.get_node("SharkZone")
	var shark := zone.spawned_shark()
	assert(shark != null and shark.is_leaving(), "the boss is already out there, patrolling")
	var start := shark.global_position
	await _wait(3.0)
	assert(shark.global_position.distance_to(start) > 5.0, "it swims its patrol")
	# A swimmer comes close.
	var spot := shark.global_position + Vector3(8, 0, 0)
	var hold_close := func() -> void:
		p.global_position = spot
		p.velocity = Vector3.ZERO
	await _wait(3.0, hold_close, func() -> bool: return shark.target == p and not shark.is_leaving())
	assert(shark.target == p and not shark.is_leaving(), "a swimmer close by gets hunted")
	# They escape: far away up on the beach.
	var hold_far := func() -> void:
		p.global_position = Vector3(0, 3, 17)
		p.velocity = Vector3.ZERO
	await _wait(15.0, hold_far, func() -> bool: return shark.is_leaving())
	assert(shark.is_leaving(), "it gives up when you escape")
	var to_path := func() -> float:
		var local := zone.patrol.to_local(shark.global_position)
		return zone.patrol.to_global(zone.patrol.curve.get_closest_point(local)).distance_to(shark.global_position)
	await _wait(25.0, hold_far, func() -> bool: return to_path.call() < 4.0)
	assert(to_path.call() < 4.0, "and swims back to its patrol")
	assert(is_instance_valid(shark), "it never despawns")
	print("PASS test_shark_patrol")
	tree.quit()
