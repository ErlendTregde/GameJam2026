extends SceneTree
## Speargun: right mouse scopes (zooms); a shot spears a fish and the line pulls it back into the
## hotbar; a miss comes back on its own; it can't fire again until it has reloaded.

func _wait_for(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await physics_frame
		t += 1.0 / 60.0
	return cond.call()


func _harpoons() -> int:
	return get_root().find_children("*", "Harpoon", true, false).size()


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	p.get_node("Head").rotation = Vector3.ZERO  # standing at the spawn, looking out to sea
	var gun: ItemData = load("res://items/speargun.tres")
	p.give(gun)
	p._select(p.items.find(gun))
	var combat: Combat = p.get_node("Combat")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	# Scope: hold right mouse to zoom in.
	var fov := cam.fov
	Input.action_press("aim")
	await create_timer(0.6).timeout
	assert(cam.fov < fov * 0.8, "scoping zooms in (%.0f -> %.0f)" % [fov, cam.fov])
	Input.action_release("aim")
	await create_timer(0.6).timeout
	# A fish straight ahead.
	var fish: Fish = load("res://scenes/fish/yellow_fish.tscn").instantiate()
	fish.get_node("PauseOffScreen").free()
	main.add_child(fish)
	fish.set_physics_process(false)
	fish.global_position = cam.global_position - cam.global_basis.z * 5.0
	await physics_frame
	combat._fire()
	assert(_harpoons() == 1, "fired a spear")
	combat._fire()
	assert(_harpoons() == 1, "only one spear at a time")
	assert(await _wait_for(func() -> bool: return combat.thrown_item == null, 3.0), "spear came back")
	assert(not is_instance_valid(fish), "fish was speared")
	var caught := p.items.find(fish.item if is_instance_valid(fish) else load("res://items/yellow_fish.tres"))
	assert(caught != -1 and p.weights[caught] > 0.0, "the fish was pulled into the hotbar")
	# Reload before the next shot.
	combat._fire()
	assert(_harpoons() == 0, "can't fire while reloading")
	await create_timer(gun.reload_time + 0.1).timeout
	combat._fire()
	assert(_harpoons() == 1, "fires again after reloading")
	# That one misses and comes back on its own.
	assert(await _wait_for(func() -> bool: return combat.thrown_item == null, 3.0), "a miss comes back too")
	print("PASS test_speargun")
	quit()
