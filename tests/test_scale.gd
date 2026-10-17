extends SceneTree
## Items aimed with Q land on the tray; the label totals them; E sells; tools aren't sold.

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.5).timeout
	var p: Player = main.get_node("Player")
	var scale: SellScale = main.find_child("SellScale", true, false)
	var tray: Node3D = scale.get_node("Tray")
	# Stand 2 m from the tray and aim at it.
	p.global_position = tray.global_position + scale.global_basis.z * 2.0 + Vector3.DOWN * 0.3
	await physics_frame
	var cam: Camera3D = p.get_node("Head/Camera3D")
	var to := tray.global_position - cam.global_position
	p.rotation.y = atan2(-to.x, -to.z)
	p.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	var fish: ItemData = load("res://items/yellow_fish.tres")
	var spear: ItemData = load("res://items/spear.tres")
	p.give(fish, 2.0)
	p._drop()
	p.give(spear)
	p._drop()
	await create_timer(2.0).timeout
	assert(scale.total() == fish.value(2.0), "fish landed on the tray and is counted; spear isn't")
	# Looking at the catch on the tray targets the scale: E sells, it doesn't pick the fish back up.
	var on_tray: WorldItem = scale.tray_area.get_overlapping_bodies().filter(func(b: Node) -> bool: return b is WorldItem and b.item == fish)[0]
	for f in 5:
		var aim := on_tray.global_position - cam.global_position
		p.rotation.y = atan2(-aim.x, -aim.z)
		p.get_node("Head").rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
		await physics_frame
	assert(p._target() == scale, "aiming at catch on the tray targets the scale")
	assert(scale.get_prompt() == "E  sell $%d" % fish.value(2.0), "sell prompt")
	scale.interact(p)
	await physics_frame
	assert(p.money == fish.value(2.0), "paid")
	assert(scale.total() == 0, "sold items are gone")
	print("PASS test_scale")
	quit()
