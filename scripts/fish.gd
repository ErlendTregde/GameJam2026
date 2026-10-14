class_name Fish
extends CharacterBody3D
## A fish swimming around under water near where it started. Wanders between the sea floor and
## the surface, darts away when hit, and leaves `drop` (a fish item) behind when killed.
## The spawner sets `ocean` and `terrain`.

@export var health := 20.0
@export var speed := 1.4
@export var flee_speed := 4.5
## How fast it turns toward where it is going.
@export var turn_speed := 2.5
## Wanders within this distance of where it was spawned (m).
@export var wander_radius := 12.0
## Stays at least this far below the surface and above the sea floor (m).
@export var surface_margin := 0.8
@export var floor_margin := 0.6
## Never swims into water shallower than this (m), so it can't end up on the beach.
@export var min_depth := 1.2
## ...or deeper than this (m): fish stay on the island shelf, out of the sharks' deep water.
## Set by the spawner.
@export var max_depth := 9.0
## Left behind when it dies (a fish WorldItem scene).
@export var drop: PackedScene

var ocean: Ocean
var terrain: Terrain

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _flee := 0.0
var _floor := -30.0

@onready var _model: Node3D = $Model


func _ready() -> void:
	_home = global_position
	_floor = _floor_y()
	_pick_target()
	_model.swim()


func _physics_process(delta: float) -> void:
	_flee = maxf(_flee - delta, 0.0)
	var current_speed := flee_speed if _flee > 0.0 else speed
	var to := _target - global_position
	if to.length() < 1.0:
		_pick_target()
		to = _target - global_position
	# Turn smoothly toward the target, then swim forward (-Z, where the head is).
	var want := Basis.looking_at(to.normalized())
	global_basis = global_basis.slerp(want, minf(turn_speed * delta * (2.0 if _flee > 0.0 else 1.0), 1.0)).orthonormalized()
	var next := global_position - global_basis.z * current_speed * delta
	var next_floor := _floor_y_at(next.x, next.z)
	if not _depth_ok(_surface_y() - next_floor):
		# Shallows, an island or the deep drop-off ahead: don't go there, head back home.
		_target = _home
		_flee = 0.0
	else:
		global_position = next
		_floor = next_floor
	global_position.y = clampf(global_position.y, _floor + floor_margin, maxf(_floor + floor_margin, _surface_y() - surface_margin))
	# Too far to see: don't spend time animating it.
	var camera := get_viewport().get_camera_3d()
	var seen: bool = camera == null or camera.global_position.distance_squared_to(global_position) < _model.visible_distance * _model.visible_distance
	_model.swim(current_speed / speed if seen else 0.0)


func _pick_target() -> void:
	for attempt in 8:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(3.0, wander_radius)
		var x := _home.x + offset.x
		var z := _home.z + offset.y
		var low := _floor_y_at(x, z) + floor_margin
		var high := _surface_y() - surface_margin
		if high - low > 0.5 and _depth_ok(_surface_y() - _floor_y_at(x, z)) and _path_is_deep(x, z):
			_target = Vector3(x, randf_range(low, high), z)
			return
	_target = _home


func _depth_ok(depth: float) -> bool:
	return depth >= min_depth and depth <= max_depth


## Whether the straight swim from here to x/z stays in water of the right depth.
func _path_is_deep(x: float, z: float) -> bool:
	for i in range(1, 6):
		var p := global_position.lerp(Vector3(x, 0, z), i / 6.0)
		if not _depth_ok(_surface_y() - _floor_y_at(p.x, p.z)):
			return false
	return true


func take_damage(amount: float, _at := Vector3.ZERO) -> void:
	health -= amount
	if health <= 0.0:
		_die()
		return
	# Dart away from whoever is looking at it (the player).
	var camera := get_viewport().get_camera_3d()
	var away := (global_position - camera.global_position) * Vector3(1, 0, 1) if camera else Vector3.FORWARD
	_target = global_position + away.normalized() * 8.0
	_target.y = clampf(_target.y, _floor_y() + floor_margin, _surface_y() - surface_margin)
	_flee = 2.5


func _die() -> void:
	if drop:
		var item: RigidBody3D = drop.instantiate()
		var world: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		world.add_child(item)  # not the spawner: it removes its children when you swim away
		item.global_transform = global_transform
		item.linear_velocity = Vector3.UP * 1.0
	queue_free()


func _surface_y() -> float:
	return ocean.sea_level if ocean else 0.0


func _floor_y() -> float:
	return _floor_y_at(global_position.x, global_position.z)


func _floor_y_at(x: float, z: float) -> float:
	return terrain.get_floor_height(x, z) if terrain else -30.0
