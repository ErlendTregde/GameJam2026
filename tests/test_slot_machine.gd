extends RefCounted
## The slot machine on island 3: pay to spin, the reels spin and stop one after another, and
## matching symbols on the middle row (from the left) drop those items out of the machine: rocks,
## coconuts, oysters and weapons. More of a kind drops more; the valuable ones are rarer on the reels.
## You can't spin again while it spins.

var tree: SceneTree


func _wait_done(machine: SlotMachine) -> void:
	var t := 0.0
	while machine.is_spinning() and t < 10.0:
		await tree.process_frame
		t += tree.root.get_process_delta_time()
	await tree.create_timer(1.5).timeout  # the prizes pop out one by one


func _dropped(main: Node, near: Vector3) -> Array:
	var found := []
	for n in main.get_children():
		if n is WorldItem and n.global_position.distance_to(near) < 6.0:
			found.append(n.item)
	return found


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(0.5).timeout
	var p: Player = main.get_node("Player")
	var machine: SlotMachine = main.get_node("SlotMachine")
	var big: IslandShape = main.get_node("Terrain/BigIsland")
	var at := Vector2(machine.global_position.x - big.position.x, machine.global_position.z - big.position.z)
	assert(at.length() < big.radius, "it stands on island 3")
	# The prizes: rocks, coconuts, coins and weapons; the valuable ones are rarer on the reels.
	var names := machine.prizes.map(func(i: ItemData) -> String: return i.name)
	for want in ["Rock", "Coconut", "Oyster", "Spear", "Speargun", "Trident"]:
		assert(not names.has("Coin"), "no gold coins from the slot machine: they are the treasure")
		assert(names.has(want), "%s can be won" % want)
	var how_often := func(k: int) -> int: return machine.strip.count(k)
	for a in machine.prizes.size():
		for b in machine.prizes.size():
			if machine.prizes[a].price > machine.prizes[b].price * 2:
				assert(how_often.call(a) < how_often.call(b), "%s is rarer than %s" % [machine.prizes[a].name, machine.prizes[b].name])
	assert(machine.prize([0, 1, 2, 3]).is_empty(), "nothing matching: nothing")
	assert(machine.prize([0, 1, 1, 1]).is_empty(), "matches count from the left")
	assert(machine.prize([2, 2, 2, 2]).size() > machine.prize([2, 2, 2, 0]).size(), "more of a kind drops more")
	p.add_money(100 - p.money)
	assert(machine.get_prompt().contains("$%d" % machine.cost), "the prompt shows the price")
	machine.interact(p)
	assert(machine.is_spinning() and p.money == 100 - machine.cost, "paid and spinning")
	machine.interact(p)
	assert(p.money == 100 - machine.cost, "no second spin while it spins")
	await _wait_done(machine)
	assert(machine.middle_symbols().size() == 4, "four reels")
	assert(p.money == 100 - machine.cost, "no money paid out, only items")
	# A reel strip of only oysters: four land and oysters come pouring out.
	var strip := PackedInt32Array()
	strip.resize(machine.strip.size())
	strip.fill(names.find("Oyster"))
	machine.strip = strip
	var before := _dropped(main, machine.global_position).size()
	machine.interact(p)
	await _wait_done(machine)
	var coin: ItemData = machine.prizes[names.find("Oyster")]
	var line := [names.find("Oyster"), names.find("Oyster"), names.find("Oyster"), names.find("Oyster")]
	assert(machine.middle_symbols() == line, "four oysters on the pay line")
	var now := _dropped(main, machine.global_position)
	assert(now.size() - before == machine.prize(line).size() and now.count(coin) >= machine.prize(line).size(), "the oysters dropped out of the machine")
	print("PASS test_slot_machine")
	tree.quit()
