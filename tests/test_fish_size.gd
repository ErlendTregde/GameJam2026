extends RefCounted
## A big fish looks clearly bigger than a small one: swimming, in the hand and in the hotbar.

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
	var p: Player = main.get_node("Player")
	p.items.fill(null)
	p.give(fish, fish.weight_range.x)
	p._select(p.items.find(fish))
	await tree.process_frame
	var small_hand := _held_size(p)
	var small_slot := _slot_size(p, p.selected_slot)
	p.items.fill(null)
	p.weights.fill(0.0)
	p._refresh_hotbar()
	await tree.process_frame
	p.give(fish, fish.weight_range.y)
	p._select(p.items.find(fish))
	await tree.process_frame
	assert(_held_size(p) > small_hand * 2.0, "big fish is bigger in the hand (%.2f vs %.2f)" % [_held_size(p), small_hand])
	assert(_slot_size(p, p.selected_slot) > small_slot * 1.5, "big fish is bigger in the hotbar")
	print("PASS test_fish_size")
	tree.quit()
