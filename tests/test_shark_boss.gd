extends SceneTree
## 10 spear hits kill the shark; the zone is defeated and never spawns again; a new shark is at full health.

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
	var zone: SharkZone = main.get_node("SharkZone")
	var spear: ItemData = load("res://items/spear.tres")
	assert(spear.damage == 20.0 and load("res://items/rock.tres").damage == 5.0, "damage balance")
	zone._spawn()
	var shark: Shark = zone._shark
	assert(shark.health == shark.max_health and shark.max_health == 200.0, "full health")
	shark.take_damage(50.0)
	shark.leave()
	zone._shark = null  # escaped: the next shark is a new one
	zone._spawn()
	assert(zone._shark.health == 200.0, "new shark at full health")
	shark = zone._shark
	for i in 10:
		shark.take_damage(spear.damage)
	assert(zone.defeated, "zone defeated after 10 spear hits")
	await create_timer(3.0).timeout
	assert(zone._shark == null, "dead shark removed")
	# Put the player in deep water: no new shark.
	var p: Player = main.get_node("Player")
	p.global_position = Vector3(0, 0, 0) + Vector3(60, -2, 60)
	zone._danger_time = 99.0
	for i in 30:
		await physics_frame
	assert(zone._shark == null, "defeated zone never spawns again")
	print("PASS test_shark_boss")
	quit()
