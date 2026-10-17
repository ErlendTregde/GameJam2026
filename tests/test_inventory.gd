extends SceneTree
## Five slots; weight survives pick up and drop; money spend/add.

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	assert(p.items.size() == 5, "hotbar has 5 slots")
	var fish_data: ItemData = load("res://items/yellow_fish.tres")
	var fish: WorldItem = load(fish_data.scene_path).instantiate()
	fish.weight = 3.0
	main.add_child(fish)
	fish.global_position = p.global_position + Vector3(0, 1, -1)
	await physics_frame
	var model_scale: float = fish.get_node("Model").scale.x
	assert(is_equal_approx(model_scale, fish_data.size_scale(3.0)), "big fish model is scaled")
	p._pick_up(fish)
	var slot := p.items.find(fish_data)
	assert(slot != -1 and is_equal_approx(p.weights[slot], 3.0), "slot keeps the weight")
	p._select(slot)
	p._drop()
	await physics_frame
	var dropped := main.get_children().filter(func(n: Node) -> bool: return n is WorldItem and n.item == fish_data)
	assert(dropped.size() == 1 and is_equal_approx(dropped[0].weight, 3.0), "dropped fish keeps the weight")
	assert(p.weights[slot] == 0.0, "slot weight cleared")
	assert(fish_data.value(3.0) == roundi(fish_data.price * 3.0), "sold by weight")
	assert(not p.spend(5), "can't spend money you don't have")
	p.add_money(12)
	assert(p.spend(5) and p.money == 7, "spend takes the money")
	assert(p.get_node("HUD/Status/Money").text == "$ 7", "HUD shows money")
	var rng := RandomNumberGenerator.new()
	for i in 50:
		var w := fish_data.roll_weight(rng)
		assert(w >= fish_data.weight_range.x and w <= fish_data.weight_range.y, "weight in range")
	print("PASS test_inventory")
	quit()
