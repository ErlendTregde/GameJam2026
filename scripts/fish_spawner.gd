class_name FishSpawner
extends Node3D
## Spawns fish in the water around this node, only where the water is deep enough.

@export var fish_scenes: Array[PackedScene] = []
@export var count := 8
## Spawns within this distance (m).
@export var radius := 30.0
## Only where the water is at least this deep (m).
@export var min_depth := 2.5
@export var ocean: Ocean
@export var terrain: Terrain


func _ready() -> void:
	if fish_scenes.is_empty():
		return
	var spawned := 0
	for attempt in count * 10:
		if spawned == count:
			break
		var offset := Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		var x := global_position.x + offset.x
		var z := global_position.z + offset.y
		var floor_y := terrain.get_floor_height(x, z)
		var surface := ocean.sea_level
		if surface - floor_y < min_depth:
			continue
		var fish: Fish = fish_scenes[spawned % fish_scenes.size()].instantiate()
		fish.ocean = ocean
		fish.terrain = terrain
		fish.position = Vector3(x, randf_range(floor_y + 1.0, surface - 1.0), z)
		fish.rotation.y = randf() * TAU
		add_child(fish)
		fish.global_position = Vector3(x, fish.position.y, z)
		spawned += 1
