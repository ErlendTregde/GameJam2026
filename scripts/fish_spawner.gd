class_name FishSpawner
extends Node3D
## Spawns fish in the water around this node, only where the water is deep enough, and only
## while the camera is near: they appear within `active_distance` and are removed again
## beyond `inactive_distance`, so far-away fish cost nothing.

@export var fish_scenes: Array[PackedScene] = []
@export var count := 8
## Spawns within this distance (m).
@export var radius := 30.0
## Only where the water is at least this deep (m)...
@export var min_depth := 2.5
## ...and at most this deep (m): keep fish on the shelf, out of the sharks' deep water
## (just under the SharkZone's danger depth).
@export var max_depth := 8.5
@export var ocean: Ocean
@export var terrain: Terrain
## Fish appear when the camera is this close to the spawner's area edge (m).
@export var active_distance := 70.0
## ...and are removed when it is farther than this (m).
@export var inactive_distance := 100.0

var _active := false


func _physics_process(_delta: float) -> void:
	if not CreatureService.simulates():
		return  # the host spawns; clients get its fish
	# Active while any player is near (the host simulates fish for everyone).
	var nearest: Node3D = WorldService.nearest_player(global_position) if WorldService.in_world() else get_viewport().get_camera_3d()
	if nearest == null:
		return
	var d := Vector2(nearest.global_position.x - global_position.x, nearest.global_position.z - global_position.z).length() - radius
	if not _active and d < active_distance:
		_active = true
		_spawn_all()
	elif _active and d > inactive_distance:
		_active = false
		for fish in get_children():
			fish.queue_free()


func _spawn_all() -> void:
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
		if surface - floor_y < min_depth or surface - floor_y > max_depth:
			continue
		var fish: Fish = fish_scenes[spawned % fish_scenes.size()].instantiate()
		fish.ocean = ocean
		fish.terrain = terrain
		fish.max_depth = max_depth + 1.0
		fish.position = to_local(Vector3(x, randf_range(floor_y + 1.0, surface - 1.0), z))  # set before _ready: it is the fish's home
		fish.rotation.y = randf() * TAU
		add_child(fish)
		spawned += 1
