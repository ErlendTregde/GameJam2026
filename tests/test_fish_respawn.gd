extends RefCounted
## Fish come back: after some are caught, a spawner tops itself up again over time.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var spawner: FishSpawner = main.get_node("Fish/MainIslandFish")
	spawner.respawn_time = 0.5
	var fish := func() -> Array: return spawner.get_children().filter(func(n: Node) -> bool: return n is Fish and not n.is_queued_for_deletion())
	assert(fish.call().size() == spawner.count, "full to start with")
	for f: Fish in fish.call().slice(0, 3):
		f.take_damage(999.0)
	await tree.process_frame
	assert(fish.call().size() == spawner.count - 3, "three caught")
	await tree.create_timer(3.0).timeout
	assert(fish.call().size() == spawner.count, "new fish swam in (%d of %d)" % [fish.call().size(), spawner.count])
	print("PASS test_fish_respawn")
	tree.quit()
