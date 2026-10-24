extends RefCounted
## Island 2 looks and plays different from island 1: mostly sand with only a little grass, a beach
## umbrella by Coco's table, and its own shop (no spear or speargun; the water bottle is fine).
## The water bottle heals a good chunk.

var tree: SceneTree


## Grass tufts per square metre on an island.
func _grass_density(grass: Node, island: IslandShape) -> float:
	var n := 0
	for mmi: MultiMeshInstance3D in grass.find_children("*", "MultiMeshInstance3D", true, false):
		for i in mmi.multimesh.instance_count:
			var at := mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin
			if Vector2(at.x - island.position.x, at.z - island.position.z).length() < island.radius:
				n += 1
	return n / (PI * island.radius * island.radius)


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(0.5).timeout
	var one: IslandShape = main.get_node("Terrain/MainIsland")
	var two: IslandShape = main.get_node("Terrain/SmallIsland")
	var grass: Node = main.get_node("Decor/Grass")
	assert(_grass_density(grass, two) < _grass_density(grass, one) * 0.4, "island 2 has much less grass (%.3f vs %.3f)" % [_grass_density(grass, two), _grass_density(grass, one)])
	assert(two.grass < 1.0, "island 2 is a sandy island")
	var board: Node3D = main.get_node("Shop/ShopBoard2")
	var sold := board.find_children("*", "ShopItem", true, false).map(func(s: ShopItem) -> String: return s.item.name)
	assert(not sold.has("Spear") and not sold.has("Speargun"), "no spear or speargun on island 2 (%s)" % [sold])
	assert(sold.has("Water Bottle"), "the water bottle is sold there")
	var umbrella: Node3D = main.find_child("Umbrella", true, false)
	assert(umbrella and umbrella.global_position.distance_to(board.get_node("SellScale").global_position) < 4.0, "a beach umbrella next to the table")
	var bottle: ItemData = load("res://items/bottle.tres")
	assert(bottle.heal >= 25.0, "the water bottle heals a good chunk (%.0f)" % bottle.heal)
	print("PASS test_island2")
	tree.quit()
