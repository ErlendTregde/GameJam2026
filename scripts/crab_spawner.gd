class_name CrabSpawner
extends Node3D
## Puts `count` crabs on the beach of `island` (ground between the crab's min/max height).

@export var terrain: Terrain
@export var island: IslandShape
@export var player: Node3D
@export var crab_scene: PackedScene
@export var count := 6
@export var random_seed := 3


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var placed := 0
	for attempt in count * 30:
		if placed == count:
			break
		var a := rng.randf() * TAU
		var r := island.radius * rng.randf_range(0.5, 1.1)
		var x := island.position.x + cos(a) * r
		var z := island.position.z + sin(a) * r
		var h := terrain.get_floor_height(x, z)
		var crab: Crab = crab_scene.instantiate()
		if h < crab.min_height or h > crab.max_height:
			crab.free()
			continue
		crab.terrain = terrain
		crab.player = player
		add_child(crab)
		crab.global_position = Vector3(x, h, z)
		placed += 1
