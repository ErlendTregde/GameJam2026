extends RefCounted
## Two-player test, host side (run with tests/net_run.sh, which also starts tests/net_client.gd).
## The client does things; the host checks that its own copy of the world saw them.

var _fails := 0


func _check(what: String, ok: bool) -> void:
	print("NET host %s %s" % ["PASS" if ok else "FAIL", what])
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


var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	await tree.process_frame
	var room: Node = tree.root.get_node("RoomService")
	var world_service: Node = tree.root.get_node("WorldService")
	room.host(true)
	await _wait_for(func() -> bool: return world_service.in_world(), 20.0)
	var main: Node = world_service.world
	var me: Player = world_service.local_player
	_check("client joined (its avatar appears)", await _wait_for(func() -> bool: return main.has_node("Avatar_1"), 40.0))
	var them: Node3D = main.get_node_or_null("Avatar_1")
	_check("client avatar follows the client", await _wait_for(func() -> bool:
		return them != null and them.global_position.distance_to(Vector3(4, 8, 12)) < 0.5, 15.0))
	# Pickup: the rock the client took is gone here too.
	_check("rock picked up by the client is gone", await _wait_for(func() -> bool:
		return not main.has_node("Items/Rocks/MainIslandRock1"), 10.0))
	# Drop: the client dropped it again; the host has the new item.
	_check("rock dropped by the client exists here", await _wait_for(func() -> bool:
		for n in main.get_children():
			if n is WorldItem and n.item.name == "Rock" and n.uid >= 1 << 40:
				return true
		return false, 10.0))
	# A fish for the client to spear: host-simulated, held still.
	var fish: Fish = load("res://scenes/fish/yellow_fish.tscn").instantiate()
	fish.name = "TestFish"
	fish.position = Vector3(4, 6, 6)
	main.add_child(fish)
	fish.set_physics_process(false)
	_check("speared fish dies on the host", await _wait_for(func() -> bool: return not is_instance_valid(fish), 15.0))
	# Shark: the client swims into deep water and the shark hunts the client.
	var zone: SharkZone = main.get_node("SharkZone")
	_check("shark hunts the client in deep water", await _wait_for(func() -> bool:
		return zone._shark != null and zone._shark.target == them, 25.0))
	# Host goes in too; when the shark kills the client, it comes for the host.
	var shark: Shark = zone._shark
	var retargeted := false
	var t := 0.0
	while t < 20.0 and not retargeted:
		me.global_position = Vector3(64, -2, 60)
		me.velocity = Vector3.ZERO
		await tree.physics_frame
		t += 1.0 / 60.0
		retargeted = is_instance_valid(shark) and shark.target == me
	_check("after killing the client the shark follows the host", retargeted)
	# The host kills it: the zone is beaten everywhere (the client checks).
	if is_instance_valid(shark):
		shark.take_damage(9999.0)
	_check("boss beaten", zone.defeated)
	me.global_position = Vector3(0, 3, 17)
	# Gamble chest opened by the client.
	var chest: Chest = main.get_node("Chests/WoodenChest")
	_check("chest opened by the client", await _wait_for(func() -> bool: return chest.opened, 20.0))
	# Money is per player: the client's sale pays the client, not us.
	await _wait_for(func() -> bool: return tree.root.multiplayer.get_peers().is_empty(), 60.0)
	_check("host money untouched by the client's sale", me.money == 0)
	print("NET host DONE fails=%d" % _fails)
	tree.quit()
