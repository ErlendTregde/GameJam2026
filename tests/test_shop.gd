extends RefCounted
## Buying costs the price, fails when poor, fills a slot, and drops at your feet when full.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var spear_hook: ShopItem
	for hook in main.find_children("*", "ShopItem", true, false):
		if hook.item.name == "Spear":
			spear_hook = hook
	assert(spear_hook and spear_hook.price == 40, "board sells a spear for $40")
	p.add_money(30)
	spear_hook.interact(p)
	assert(p.money == 30 and not p.items.has(spear_hook.item), "too poor: nothing happens")
	p.add_money(20)
	spear_hook.interact(p)
	assert(p.money == 10 and p.items.has(spear_hook.item), "bought into a slot")
	var rock: ItemData = load("res://items/rock.tres")
	for i in p.items.size():
		if p.items[i] == null:
			p.items[i] = rock
	p.add_money(40)
	spear_hook.interact(p)
	await tree.physics_frame
	var on_ground := main.get_children().filter(func(n: Node) -> bool: return n is WorldItem and n.item == spear_hook.item)
	assert(p.money == 10 and on_ground.size() == 1, "full hotbar: paid once, dropped at feet")
	print("PASS test_shop")
	tree.quit()
