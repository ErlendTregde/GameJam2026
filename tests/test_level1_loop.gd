extends SceneTree
## Earn $40 from catch, buy the spear, kill the shark with it.

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.5).timeout
	var p: Player = main.get_node("Player")
	var scale: SellScale = main.find_child("SellScale", true, false)
	var fish: ItemData = load("res://items/blue_fish.tres")
	# Put catch on the tray until it's worth $40.
	while scale.total() < 40:
		var it: WorldItem = load(fish.scene_path).instantiate()
		it.weight = 2.5
		main.add_child(it)
		it.global_position = scale.get_node("Tray").global_position + Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.1, 0.1))
		await create_timer(0.4).timeout
	scale.interact(p)
	assert(p.money >= 40, "earned enough for a spear")
	var hook: ShopItem
	for h in main.find_children("*", "ShopItem", true, false):
		if h.item.name == "Spear":
			hook = h
	hook.interact(p)
	assert(p.items.has(hook.item), "bought the spear")
	var zone: SharkZone = main.get_node("SharkZone")
	zone._spawn()
	var hits := 0
	while not zone.defeated:
		zone._shark.take_damage(hook.item.damage)
		hits += 1
	assert(hits == 10, "spear kills the shark in 10 hits")
	print("PASS test_level1_loop")
	quit()
