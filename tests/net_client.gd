extends RefCounted
## Two-player test, client side (see tests/net_host.gd and tests/net_run.sh).

var _fails := 0


func _check(what: String, ok: bool) -> void:
	print("NET client %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _wait_for(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await tree.physics_frame
		t += 1.0 / 60.0
	return cond.call()


func _hold(body: Node3D, pos: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		body.global_position = pos
		body.velocity = Vector3.ZERO
		await tree.physics_frame
		t += 1.0 / 60.0


var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	await tree.process_frame
	var room: Node = tree.root.get_node("RoomService")
	var world_service: Node = tree.root.get_node("WorldService")
	var items: Node = tree.root.get_node("ItemService")
	room.join("127.0.0.1")
	_check("joined the host's island", await _wait_for(func() -> bool: return world_service.in_world(), 40.0))
	var main: Node = world_service.world
	var me: Player = world_service.local_player
	_check("host avatar is here", await _wait_for(func() -> bool: return main.has_node("Avatar_0"), 15.0))
	# Late join: what happened before we came is here too.
	await tree.create_timer(1.0).timeout
	_check("late join: the rock the host took is gone", not main.has_node("Items/Rocks/MainIslandRock2"))
	var dropped_bottle := false
	for n in main.get_children():
		dropped_bottle = dropped_bottle or (n is WorldItem and n.item.name == "Water Bottle")
	_check("late join: the bottle the host dropped is here", dropped_bottle)
	await _hold(me, Vector3(4, 8, 12), 3.0)
	# Pick up a rock: the host decides, then it lands in our hotbar.
	var rock_data: ItemData = load("res://items/rock.tres")
	me.items.fill(null)
	me._refresh_hotbar()
	me._pick_up(main.get_node("Items/Rocks/MainIslandRock1"))
	_check("picked-up rock is in the hotbar", await _wait_for(func() -> bool: return me.items.has(rock_data), 5.0))
	# A shell from the reef (placed by a Scatter): picked up through the host too.
	var shell: WorldItem = main.get_node("Reef/Shells").get_children(true).filter(func(n: Node) -> bool: return n is WorldItem)[0]
	tree.root.set_meta(&"net_shell", str(main.get_path_to(shell)))
	var shell_data := shell.item
	me._pick_up(shell)
	_check("reef shell picked up", await _wait_for(func() -> bool: return me.items.has(shell_data), 5.0))
	# Hit a palm until something falls (the host rolls the drop).
	var palms: Node = main.get_node("Decor/Palms").get_node("Bodies")
	var count_items := func() -> int:
		return main.get_children().filter(func(n: Node) -> bool: return n is WorldItem).size()
	var before_drop: int = count_items.call()
	var tree_at: Vector3 = palms.get_child(0).global_position
	for i in 30:
		world_service.hit(palms, 10.0, tree_at)
		await tree.create_timer(0.1).timeout
	_check("hitting a palm drops something (from the host)", await _wait_for(func() -> bool: return count_items.call() > before_drop, 5.0))
	# Drop the rock again.
	me._select(me.items.find(rock_data))
	me._drop()
	await tree.create_timer(2.0).timeout
	# Spear the host's fish: our puppet, hit through the host; the catch comes back to us.
	_check("host's fish shows up here", await _wait_for(func() -> bool: return main.has_node("TestFish"), 10.0))
	var puppet: Node3D = main.get_node_or_null("TestFish")
	var fish_data: ItemData = load("res://items/yellow_fish.tres")
	me.items.fill(null)
	me._refresh_hotbar()
	if puppet:
		world_service.hit(puppet, 100.0, puppet.global_position, true)
	_check("speared fish goes into our hotbar", await _wait_for(func() -> bool: return me.items.has(fish_data), 5.0))
	_check("the fish is gone here too", await _wait_for(func() -> bool: return not is_instance_valid(puppet), 5.0))
	# Swim up to the patrolling shark until it hunts us and the host is in the water near it too.
	var host_avatar: Node3D = main.get_node("Avatar_0")
	var zone: SharkZone = main.get_node("SharkZone")
	_check("the patrolling shark is here (puppet)", await _wait_for(func() -> bool: return zone._puppet() != null, 10.0))
	var t := 0.0
	var both_in := false
	while t < 40.0 and not both_in:
		var shark_here: Node3D = zone._puppet()
		if shark_here:
			me.global_position = shark_here.global_position + Vector3(8, 0, 0)
		me.velocity = Vector3.ZERO
		await tree.physics_frame
		t += 1.0 / 60.0
		both_in = shark_here != null and main.get_node("Player/HUD/BossBar").visible and host_avatar.exposed_to_sea \
				and host_avatar.global_position.distance_to(shark_here.global_position) < 40.0
	_check("the shark hunts us (boss bar) with the host nearby", both_in)
	me.take_damage(9999.0)  # killed: the host's shark should go for the host
	_check("boss beaten here too", await _wait_for(func() -> bool: return zone.defeated, 25.0))
	# Gamble at the chest.
	me.add_money(20)
	var chest: Chest = main.get_node("Chests/WoodenChest")
	chest.interact(me)
	_check("chest opens for us", await _wait_for(func() -> bool: return chest.opened, 10.0))
	_check("we paid for it", me.money == 5)
	# The host beat island 2's boss: beaten here too, and the boat stays locked (for now).
	var boat: Boat = main.get_node("Boat")
	var zone2: SharkZone = main.get_node("SharkZone2")
	_check("island 2's boss beaten here too", await _wait_for(func() -> bool: return zone2.defeated, 20.0))
	_check("the boat stays locked", boat.locked)
	# Sell a fish at the table: our money, not the host's.
	var table: SellScale = main.find_child("SellScale", true, false)
	items.spawn(fish_data, 2.0, table.get_node("Tray").global_position + Vector3.UP * 0.3)
	await _wait_for(func() -> bool: return table.total() > 0, 10.0)
	await tree.create_timer(1.0).timeout
	var before := me.money
	table.interact(me)
	_check("sale pays us", await _wait_for(func() -> bool: return me.money == before + fish_data.value(2.0), 10.0))
	print("NET client DONE fails=%d" % _fails)
	room.request_leave_room()
	await tree.create_timer(1.0).timeout
	tree.quit()
