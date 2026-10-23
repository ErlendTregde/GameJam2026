extends RefCounted
## A big fish looks clearly bigger than a small one when swimming and in the hand (also when you
## switch straight from one fish to another of the same kind). In the hotbar every fish is drawn
## the same size, framed to fit the slot.

func _held_size(p: Player) -> float:
	var holder: Node3D = p.get_node("HUD/HeldView/SubViewport/Camera3D/Holder")
	var model: Node3D = holder.get_child(holder.get_child_count() - 1)
	return model.scale.x


func _slot_size(p: Player, i: int) -> float:
	var vp: SubViewport = p.get_node("HUD/Hotbar").get_child(i).get_node("Frame/Preview/SubViewport")
	var model: Node3D = vp.get_child(vp.get_child_count() - 1)
	var cam: Camera3D = vp.get_node("Camera3D")
	return ItemData.model_bounds(model).size.length() * model.scale.x / cam.size


var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var fish: ItemData = load("res://items/yellow_fish.tres")
	assert(fish.size_scale(fish.weight_range.y) / fish.size_scale(fish.weight_range.x) > 2.5, "biggest yellow fish is much bigger than the smallest")
	# Swimming: the fish you meet differ visibly in size (not all near the same weight).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sizes := []
	for i in 60:
		sizes.append(fish.size_scale(fish.roll_weight(rng)))
	sizes.sort()
	assert(sizes[48] / sizes[12] > 1.45, "a big swimming fish is clearly bigger than a small one (%.2f)" % (sizes[48] / sizes[12]))
	# Hand and hotbar: a small and a big yellow fish side by side, switching straight between them.
	var p: Player = main.get_node("Player")
	p.items.fill(null)
	p.weights.fill(0.0)
	p.give(fish, fish.weight_range.x)
	p.give(fish, fish.weight_range.y)
	var small := p.weights.find(fish.weight_range.x)
	var big := p.weights.find(fish.weight_range.y)
	p._select(small)
	await tree.process_frame
	var small_hand := _held_size(p)
	p._select(big)
	await tree.process_frame
	assert(_held_size(p) > small_hand * 2.0, "big fish is bigger in the hand (%.2f vs %.2f)" % [_held_size(p), small_hand])
	assert(absf(_slot_size(p, small) - _slot_size(p, big)) < 0.01, "the hotbar shows every fish the same size")
	print("PASS test_fish_size")
	tree.quit()
