extends SceneTree
## Charges once per open, does nothing when poor or already open, closes again.

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
	var p: Player = main.get_node("Player")
	var chest: Chest = main.get_node("Chests/WoodenChest")
	assert(chest.cost == 15 and chest.get_prompt() == "[E] gamble $15", "gamble prompt")
	var before := chest.get_parent().get_child_count()
	chest.interact(p)
	assert(not chest.opened and p.money == 0, "too poor: stays shut")
	p.add_money(20)
	chest.interact(p)
	chest.interact(p)  # spamming E while it opens
	assert(chest.opened and p.money == 5, "charged once")
	await create_timer(1.5).timeout
	assert(chest.get_parent().get_child_count() > before, "loot popped out")
	await create_timer(chest.reset_time).timeout
	assert(not chest.opened, "closed again for another go")
	print("PASS test_gamble")
	quit()
