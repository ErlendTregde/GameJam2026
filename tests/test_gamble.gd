extends RefCounted
## Charges once per open, does nothing when poor or already open, closes again.

var tree: SceneTree


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var chest: Chest = main.get_node("Chests/WoodenChest")
	assert(chest.cost == 15 and chest.get_prompt() == "[E] $15", "gamble prompt")
	var before := main.get_child_count()
	chest.interact(p)
	assert(not chest.opened and p.money == 0, "too poor: stays shut")
	p.add_money(20)
	chest.interact(p)
	chest.interact(p)  # spamming E while it opens
	assert(chest.opened and p.money == 5, "charged once")
	await tree.create_timer(1.5).timeout
	assert(main.get_child_count() > before, "loot popped out")
	await tree.create_timer(chest.reset_time).timeout
	assert(not chest.opened, "closed again for another go")
	print("PASS test_gamble")
	tree.quit()
