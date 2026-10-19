extends RefCounted
## Crabs walk on the beach, scuttle away from the player, and drop a crab item with a weight.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var crabs := main.find_children("*", "Crab", true, false)
	assert(crabs.size() >= 4, "crabs spawned on the beach")
	var crab: Crab = crabs[0]
	var p: Player = main.get_node("Player")
	p.global_position = crab.global_position + Vector3(1.5, 1.0, 0)
	var start := crab.global_position.distance_to(p.global_position)
	await tree.create_timer(1.0).timeout
	assert(crab.global_position.distance_to(p.global_position) > start, "crab flees")
	var item := crab.item
	crab.take_damage(100.0)
	await tree.physics_frame
	var drops := main.get_children().filter(func(n: Node) -> bool: return n is WorldItem and n.item == item)
	assert(drops.size() == 1 and drops[0].weight > 0.0, "crab item with a weight")
	print("PASS test_crab")
	tree.quit()
