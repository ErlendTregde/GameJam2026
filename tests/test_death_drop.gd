extends RefCounted
## Dying drops everything in your hotbar where you died (you, or a friend, can dive back for it).
## Money and worn gear are kept.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var tooth: ItemData = load("res://items/shark_tooth.tres")
	var fish: ItemData = load("res://items/yellow_fish.tres")
	p.items.fill(null)
	p.give(tooth)
	p.give(fish, 0.8)
	p.add_money(50)
	p.wear(load("res://items/goggles.tres"))
	var where := Vector3(20, -6, 40)
	p.global_position = where
	await tree.physics_frame
	p.take_damage(9999.0)
	assert(p.items.all(func(i: ItemData) -> bool: return i == null), "the hotbar is empty after dying")
	assert(p.money == 50 and p.worn.size() == 1, "money and gear are kept")
	await tree.create_timer(0.5).timeout
	var dropped := []
	for n in main.get_children():
		if n is WorldItem and n.global_position.distance_to(where) < 4.0:
			dropped.append(n.item)
	assert(dropped.has(tooth) and dropped.has(fish), "the items lie where you died (%s)" % [dropped])
	print("PASS test_death_drop")
	tree.quit()
