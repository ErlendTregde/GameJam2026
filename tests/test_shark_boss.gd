extends RefCounted
## The patrolling shark hunts you when you swim close, keeps hunting when you reach land nearby,
## goes back to its patrol when it kills you (keeping its damage for the next fight), and stays
## dead once killed.

func _wait_for(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await tree.physics_frame
		t += 1.0 / 60.0
	return cond.call()


var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var zone: SharkZone = main.get_node("SharkZone")
	var p: Player = main.get_node("Player")
	var spear: ItemData = load("res://items/spear.tres")
	assert(spear.damage == 20.0 and load("res://items/rock.tres").damage == 5.0, "damage balance")
	var shark: Shark = zone.spawned_shark()
	assert(shark.health == 200.0, "first shark at full health")
	# Swim up to it: it hunts you.
	var close := shark.global_position + Vector3(8, 0, 0)
	assert(await _wait_for(func() -> bool:
		p.global_position = close
		p.velocity = Vector3.ZERO
		return not shark.is_leaving(), 5.0), "it hunts a swimmer who comes close")
	shark.take_damage(60.0)
	# Out of the water but still close: it keeps hunting.
	p.global_position = close + Vector3(0, 30, 0)
	await tree.create_timer(2.0).timeout
	assert(not shark.is_leaving(), "it doesn't give up while you are close")
	# It kills you: back to its patrol, keeping its damage.
	p.take_damage(9999.0)
	assert(shark.is_leaving() and is_instance_valid(shark), "back to patrol after killing you, not gone")
	await tree.create_timer(3.0).timeout
	assert(zone.spawned_shark() == shark and shark.health == 140.0, "same shark, kept its damage (%.0f)" % shark.health)
	for i in 7:
		shark.take_damage(spear.damage)
	assert(zone.defeated, "killed")
	await tree.create_timer(3.0).timeout
	assert(zone.spawned_shark() == null, "dead shark removed")
	for i in 30:
		await tree.physics_frame
	assert(zone.spawned_shark() == null, "a beaten boss never comes back")
	print("PASS test_shark_boss")
	tree.quit()
