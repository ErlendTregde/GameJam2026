extends RefCounted
## The deep chest (the one by the statue, in the blue hole off island 1) is the reason to
## buy gear: diving down to it and back up as fast as you can, you drown without goggles and
## flippers, and make it with them. It can be seen from the spawn beach, and no boss guards it.

var tree: SceneTree


## Swims from the surface above the chest down to it and back up, as a player would: look
## straight down, hold forward + sprint; then look up and swim for the air. True if alive at the top.
func dive_round_trip(p: Player, chest: Chest, ocean: Ocean) -> bool:
	p.health = p.max_health
	p.oxygen = 1.0
	p.stamina = p.max_stamina
	p.exhausted = false
	var above := Vector3(chest.global_position.x, ocean.sea_level - 0.5, chest.global_position.z)
	p.global_position = above
	p.velocity = Vector3.ZERO
	var head: Node3D = p.get_node("Head")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var drowned := [false]
	var on_death := func() -> void: drowned[0] = true
	p.died.connect(on_death)
	var t := 0.0
	var going_down := true
	while not drowned[0] and t < 120.0:
		head.rotation.x = -1.5 if going_down else 1.5
		p.global_position.x = above.x  # straight down and up
		p.global_position.z = above.z
		await tree.physics_frame
		t += 1.0 / 60.0
		if going_down and p.global_position.y < chest.global_position.y + 2.5:  # at the chest (on its lid)
			going_down = false
		elif not going_down and not p._underwater:
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	p.died.disconnect(on_death)
	var alive: bool = not drowned[0] and not going_down
	print("  dive to %.1f m: %.1f s, %s" % [ocean.sea_level - chest.global_position.y, t, "made it" if alive else "drowned"])
	p.global_position = Vector3(0, 3, 17)
	p.health = p.max_health
	await tree.create_timer(0.5).timeout
	return alive


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var ocean: Ocean = main.get_node("Ocean")
	var chest: Chest = main.get_node_or_null("Chests/DeepChest")
	assert(chest != null, "there is a deep chest")
	assert(chest.cost == 0 and chest.reset_time > 0.0, "free, and it fills up again")
	assert(main.has_node("Statue"), "the statue stands next to it")
	var beach := Vector3(0, 3, 17)
	assert(Vector2(chest.global_position.x - beach.x, chest.global_position.z - beach.z).length() < 70.0, "close enough to see from the spawn beach")
	for zone: SharkZone in [main.get_node("SharkZone"), main.get_node("SharkZone2")]:
		var nearest := zone.patrol.to_global(zone.patrol.curve.get_closest_point(zone.patrol.to_local(chest.global_position)))
		assert(nearest.distance_to(chest.global_position) > 40.0, "no boss guards the chest")
	assert(not await dive_round_trip(p, chest, ocean), "without gear the deep chest is out of reach")
	p.wear(load("res://items/goggles.tres"))
	p.wear(load("res://items/flippers.tres"))
	assert(await dive_round_trip(p, chest, ocean), "with goggles and flippers you make it there and back")
	print("PASS test_dive_gate")
	tree.quit()
