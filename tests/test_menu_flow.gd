extends RefCounted
## The menu: Play solo opens the island with our player and its (hidden) avatar; Esc opens and
## closes the pause menu; Leave goes back to the menu.

var tree: SceneTree


func _wait_for(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await tree.physics_frame
		t += 1.0 / 60.0
	return cond.call()


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	tree.change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
	assert(await _wait_for(func() -> bool: return tree.current_scene != null and tree.current_scene.name == "MainMenu", 10.0), "menu opens")
	await tree.create_timer(0.5).timeout
	assert(tree.current_scene.get_node_or_null("World/Player") == null, "menu backdrop has no player")
	tree.current_scene._on_solo_pressed()
	var ws: Node = tree.root.get_node("WorldService")
	assert(await _wait_for(func() -> bool: return ws.in_world(), 15.0), "Play solo opens the island")
	var main: Node = ws.world
	assert(await _wait_for(func() -> bool: return main.has_node("Avatar_0"), 5.0), "solo player is seated")
	assert(not main.get_node("Avatar_0").visible, "our own avatar is hidden")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	tree.root.push_input(esc)
	await tree.process_frame
	assert(PauseMenu.is_open(), "Esc opens the pause menu")
	tree.root.push_input(esc)
	await tree.process_frame
	assert(not PauseMenu.is_open(), "Esc closes it again")
	main.get_node("PauseMenu")._on_leave_pressed()
	assert(await _wait_for(func() -> bool: return tree.current_scene != null and tree.current_scene.name == "MainMenu", 10.0), "Leave goes back to the menu")
	print("PASS test_menu_flow")
	tree.quit()
