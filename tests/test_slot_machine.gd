extends RefCounted
## The slot machine on island 3: pay to spin, the reels spin and stop one after another, and the
## middle row pays out for matching symbols from the left (more of a kind and rarer symbols pay
## more). You can't spin again while it spins.

var tree: SceneTree


func _wait_done(machine: SlotMachine) -> void:
	var t := 0.0
	while machine.is_spinning() and t < 10.0:
		await tree.process_frame
		t += tree.root.get_process_delta_time()


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
	p.add_money(100 - p.money)
	assert(machine.get_prompt().contains("$%d" % machine.cost), "the prompt shows the price")
	machine.interact(p)
	assert(machine.is_spinning() and p.money == 100 - machine.cost, "paid and spinning")
	machine.interact(p)
	assert(p.money == 100 - machine.cost, "no second spin while it spins")
	await _wait_done(machine)
	assert(not machine.is_spinning(), "the reels stop")
	var shown := machine.middle_symbols()
	assert(shown.size() == 4, "four reels")
	assert(p.money == 100 - machine.cost + machine.payout(shown), "paid out for what landed (%s)" % [shown])
	# Matching from the left pays; rarer symbols pay more.
	assert(machine.payout([0, 1, 2, 3]) == 0, "nothing matching: nothing")
	assert(machine.payout([2, 2, 0, 0]) > 0 and machine.payout([2, 2, 2, 0]) > machine.payout([2, 2, 0, 0]) \
			and machine.payout([2, 2, 2, 2]) > machine.payout([2, 2, 2, 0]), "more of a kind pays more")
	assert(machine.payout([5, 5, 5, 5]) > machine.payout([0, 0, 0, 0]), "rarer symbols pay more")
	assert(machine.payout([0, 1, 1, 1]) == 0, "matches count from the left")
	# A reel strip of only shark teeth: the jackpot lands, and it is shown on the reels.
	var strip := PackedInt32Array()
	strip.resize(machine.strip.size())
	strip.fill(5)
	machine.strip = strip
	var before := p.money
	machine.interact(p)
	await _wait_done(machine)
	assert(machine.middle_symbols() == [5, 5, 5, 5], "four shark teeth")
	assert(p.money == before - machine.cost + machine.payout([5, 5, 5, 5]), "jackpot paid")
	print("PASS test_slot_machine")
	tree.quit()
