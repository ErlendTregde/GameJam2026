extends RefCounted
## Under water you stay where you are when you don't swim (no floating up, no sinking), and
## swimming forward while looking up takes you up.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var ocean: Ocean = main.get_node("Ocean")
	p.global_position = Vector3(60, ocean.sea_level - 3.0, 60)  # deep water, a few metres down
	p.velocity = Vector3.ZERO
	await tree.create_timer(0.3).timeout
	var start := p.global_position.y
	await tree.create_timer(3.0).timeout
	assert(absf(p.global_position.y - start) < 0.3, "stays put under water (moved %.2f m)" % (p.global_position.y - start))
	p.get_node("Head").rotation.x = 1.2  # look up
	Input.action_press("move_forward")
	await tree.create_timer(1.0).timeout
	Input.action_release("move_forward")
	assert(p.global_position.y > start + 1.0, "swimming while looking up goes up")
	print("PASS test_swim_hover")
	tree.quit()
