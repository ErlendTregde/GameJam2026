extends RefCounted
## Hit flash fades back to normal; Coco tips when you're close; the table hint plays once;
## reef shells are items you can pick up and sell.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	p.set_physics_process(false)
	# Hit flash on a fish.
	var fish: Fish = load("res://scenes/fish/yellow_fish.tscn").instantiate()
	main.add_child(fish)
	fish.take_damage(1.0)
	await tree.process_frame
	var meshes := fish.get_node("Model").find_children("*", "GeometryInstance3D", true, false)
	var tint := func(m: GeometryInstance3D) -> float: return (m.get_instance_shader_parameter("hit_tint") as Color).a
	assert(meshes.all(func(m: GeometryInstance3D) -> bool: return tint.call(m) > 0.2), "hit tints the fish")
	await tree.create_timer(0.6).timeout
	assert(meshes.all(func(m: GeometryInstance3D) -> bool: return tint.call(m) == 0.0), "tint fades back to normal")
	# Coco gives a tip when you stand close.
	var coco: Coco = main.find_child("Coco", true, false)
	var bubble: Label3D = coco.get_node("Bubble")
	assert(not bubble.visible, "quiet while you're far away")
	p.global_position = coco.global_position + coco.global_basis.z * 2.0
	await tree.create_timer(0.3).timeout
	assert(bubble.visible and bubble.text in coco.tips, "tip when close")
	# The table hint, once.
	var table: SellScale = main.find_child("SellScale", true, false)
	table.get_prompt()
	assert(bubble.text == table.hint, "hint the first time you look at the table")
	bubble.text = ""
	table.get_prompt()
	assert(bubble.text == "", "only once")
	# Shells on the reef are pick-up items with a price.
	var shells := main.get_node("Reef/Shells").get_children(true).filter(func(n: Node) -> bool: return n is WorldItem)
	assert(shells.size() > 20 and shells[0].item.price > 0, "shells are sellable items")
	print("PASS test_feedback")
	tree.quit()
