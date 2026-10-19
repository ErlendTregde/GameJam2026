extends RefCounted
## The crater has coral growing down its sides, and valuable red coral to pick up, only on the
## deep floor (never near the top). Red coral is worth more than any fish.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var terrain: Terrain = main.get_node("Terrain")
	var red: ItemData = load("res://items/red_coral.tres")
	assert(red.price > (load("res://items/red_snapper.tres") as ItemData).price, "red coral is worth more than a red snapper")
	var deep: Node = main.get_node("Reef/DeepCorals")
	assert(deep.get_children(true).size() > 0, "corals grow in the crater")
	var found := 0
	for n in main.get_node("Reef/ValuableCorals").get_children(true):
		if n is WorldItem:
			found += 1
			assert(n.item == red, "valuable coral is red coral")
			assert(n.global_position.y < -35.0, "only on the deep floor (at %.1f)" % n.global_position.y)
			assert(Vector2(n.global_position.x, n.global_position.z).distance_to(terrain.crater_center) < terrain.crater_radius, "in the crater")
	assert(found >= 5, "a handful to find (%d)" % found)
	print("PASS test_deep_corals")
	tree.quit()
