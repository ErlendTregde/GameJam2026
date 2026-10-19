extends RefCounted
## The shark comes in deep water, keeps hunting even when you reach land, leaves only when it
## kills you, keeps its damage for the next fight, and stays dead once killed.

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
	var deep := Vector3(60, -2, 60)
	assert(zone.in_zone(deep), "test point is shark water")
	var land: Vector3 = p.global_position
	# Swim in deep water: the shark comes.
	p.global_position = deep
	assert(await _wait_for(func() -> bool: return zone._shark != null, 5.0), "shark spawns in deep water")
	var shark: Shark = zone._shark
	assert(shark.health == 200.0, "first shark at full health")
	shark.take_damage(60.0)
	# Back on land: it keeps hunting.
	p.global_position = land
	await tree.create_timer(3.0).timeout
	assert(is_instance_valid(shark) and not shark.is_leaving(), "reaching land doesn't make it give up")
	# It kills you: it leaves, keeping its damage.
	p.take_damage(9999.0)
	assert(shark.is_leaving(), "leaves after killing you")
	assert(await _wait_for(func() -> bool: return zone._shark == null, 20.0), "swims off and despawns")
	# Back into deep water: it returns with the health it had left.
	p.global_position = deep
	assert(await _wait_for(func() -> bool: return zone._shark != null, 5.0), "shark comes back")
	shark = zone._shark
	assert(shark.health == 140.0, "kept its damage (%.0f)" % shark.health)
	for i in 7:
		shark.take_damage(spear.damage)
	assert(zone.defeated, "killed")
	await tree.create_timer(3.0).timeout
	assert(zone._shark == null, "dead shark removed")
	zone._danger_time = 99.0
	for i in 30:
		await tree.physics_frame
	assert(zone._shark == null, "defeated zone never spawns again")
	print("PASS test_shark_boss")
	tree.quit()
