extends RefCounted
## Goggles and flippers are sold in island 2's shop (not the first one). Buying gear wears it at
## once (no hotbar slot): goggles give a longer breath and clearer water, flippers faster swimming.
## You can't buy the same gear twice.

var tree: SceneTree


func _shop_item(board: Node, item_name: String) -> ShopItem:
	for s in board.find_children("*", "ShopItem", true, false):
		if s.item and s.item.name == item_name:
			return s
	return null


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var goggles := _shop_item(main.get_node("Shop/ShopBoard2"), "Goggles")
	var flippers := _shop_item(main.get_node("Shop/ShopBoard2"), "Flippers")
	assert(goggles != null and flippers != null, "island 2's shop sells goggles and flippers")
	for s in main.get_node("Shop/ShopBoard").find_children("*", "ShopItem", true, false):
		assert(not s.item.worn, "no gear in the first shop")
	p.add_money(-p.money)
	goggles.interact(p)
	assert(not p.wears(goggles.item), "can't buy without money")
	p.add_money(500)
	var breath := p.breath_time
	var fog := p.underwater_environment.fog_density
	var items_before := p.items.duplicate()
	goggles.interact(p)
	assert(p.wears(goggles.item) and p.money == 500 - goggles.price, "bought and worn")
	assert(p.breath_time == breath + 10.0 and p.underwater_environment.fog_density < fog, "longer breath, clearer water")
	assert(p.items == items_before, "it takes no hotbar slot")
	var money := p.money
	goggles.interact(p)
	assert(p.money == money, "no paying twice for the same gear")
	var swim := p.swim_speed
	flippers.interact(p)
	assert(is_equal_approx(p.swim_speed, swim * 1.5), "flippers: faster swimming")
	var shown: Node = p.get_node("HUD/Status/Gear")
	assert(shown.get_child_count() == 2, "worn gear shows as two pictures on the HUD")
	assert(shown.find_children("*", "Label", true, false).all(func(l: Label) -> bool: return not l.is_visible_in_tree()), "pictures only, no text")
	print("PASS test_gear")
	tree.quit()
