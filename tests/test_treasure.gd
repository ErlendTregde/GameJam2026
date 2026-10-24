extends RefCounted
## The ending: the treasure chests at the dive spots hold 1, 2, 3 and 4 gold coins (10 in all). A
## counter at the top right (a coin and "found / 10") counts each treasure coin the first time it is
## picked up; coins still go in the hotbar and can be sold. With all 10 found the boat unlocks.

var tree: SceneTree


func _coins_near(main: Node, at: Vector3) -> Array:
	return main.get_children().filter(func(n: Node) -> bool:
		return n is WorldItem and n.item.name == "Coin" and n.global_position.distance_to(at) < 8.0)


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(0.5).timeout
	var p: Player = main.get_node("Player")
	var events: Node = tree.root.get_node("WorldEvents")
	var items: Node = tree.root.get_node("ItemService")
	var boat: Boat = main.get_node("Boat")
	assert(events.treasure_total() == 10, "10 gold coins to find (%d)" % events.treasure_total())
	var counts := []
	for spot: Node in main.get_node("DiveSpots").get_children():
		var chest: Chest = spot.get_node("Chest")
		assert(chest.treasure and chest.reset_time == 0.0, "%s: a treasure chest, opened once" % spot.name)
		counts.append(chest.loot.always.size())
	counts.sort()
	assert(counts == [1, 2, 3, 4], "1, 2, 3 and 4 coins (%s)" % [counts])
	var label: Label = p.get_node("HUD/Treasure/Count")
	assert(label.text == "0 / 10" and p.get_node("HUD/Treasure/Icon"), "the counter shows a coin and 0 / 10")
	assert(boat.locked, "the boat waits for the gold")
	var coin: ItemData = load("res://items/coin.tres")
	var first := true
	for spot: Node in main.get_node("DiveSpots").get_children():
		var chest: Chest = spot.get_node("Chest")
		chest.open()
		await tree.create_timer(1.5).timeout
		for c: WorldItem in _coins_near(main, chest.global_position):
			p.items.fill(null)
			items.request_pickup(c)
			await tree.process_frame
			assert(p.items.has(coin), "the coin goes in the hotbar")
			if first:
				first = false
				# Dropping it and picking it up again doesn't count twice.
				var found: int = events.treasure_found
				p._select(p.items.find(coin))
				p._drop()
				await tree.create_timer(0.3).timeout
				for again: WorldItem in _coins_near(main, p.global_position):
					items.request_pickup(again)
				await tree.process_frame
				assert(events.treasure_found == found, "a dropped coin counts once")
	assert(events.treasure_found == 10 and label.text == "10 / 10", "all the gold found (%s)" % label.text)
	assert(not boat.locked, "the boat is unlocked: time to escape")
	assert(coin.price > 0, "coins can still be sold")
	print("PASS test_treasure")
	tree.quit()
