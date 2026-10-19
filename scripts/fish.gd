class_name Fish
extends CharacterBody3D

## A fish swimming around under water near where it started. Wanders between the sea floor and
## the surface, darts away when hit, and leaves `item` (a fish of its size) behind when killed.
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
## What it leaves behind when killed (a fish item); its weight range sets this fish's size.
@export var item: ItemData

var weight := 0.0
## Peer whose speargun spear hit it last: if it dies of that, the catch rides back to them.
var caught_by := 0

var ocean: Ocean
var terrain: Terrain

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _flee := 0.0
var _floor := -30.0
var _turning := false  # blocked by the shallows or the drop-off: turning around

@onready var _model: Node3D = $Model


func _ready() -> void:
	if item:
		if CreatureService.simulates():  # a client's puppet gets its size from the host
			weight = item.roll_weight(RandomNumberGenerator.new())
		$Model.scale *= item.size_scale(weight)
	_home = global_position
	_floor = _floor_y()
	_pick_target()
	_model.swim()
	CreatureService.register(self)


func _exit_tree() -> void:
	CreatureService.unregister(self)


func _physics_process(delta: float) -> void:
	if not CreatureService.simulates():
		return  # a puppet: CreatureService moves it
	_flee = maxf(_flee - delta, 0.0)
	var current_speed := flee_speed if _flee > 0.0 else speed
	var to := _target - global_position
	if to.length() < 1.0:
		_pick_target()
		to = _target - global_position
	# Turn smoothly toward the target, then swim forward (-Z, where the head is).
	var want := Basis.looking_at(to.normalized())
	var turn := 3.0 if _turning else (2.0 if _flee > 0.0 else 1.0)
	global_basis = global_basis.slerp(want, minf(turn_speed * delta * turn, 1.0)).orthonormalized()
	var next := global_position - global_basis.z * current_speed * delta
	var next_floor := _floor_y_at(next.x, next.z)
	if not _depth_ok(_surface_y() - next_floor):
		# Shallows, an island or the deep drop-off ahead: pick somewhere reachable once and turn to it.
		if not _turning:
			_pick_target()
			_flee = 0.0
		_turning = true
	else:
		_turning = false
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
	# Nowhere reachable found: head home, or turn around if already there.
	_target = _home if _home.distance_to(global_position) > 2.0 else global_position + global_basis.z * 4.0


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
	HitFlash.flash(_model)
	CreatureService.flashed(self)
	if health <= 0.0:
		_die()
		return
	# Dart away from the nearest player.
	var player := WorldService.nearest_player(global_position)
	var away := (global_position - player.global_position) * Vector3(1, 0, 1) if player else Vector3.FORWARD
	_target = global_position + away.normalized() * 8.0
	_target.y = clampf(_target.y, _floor_y() + floor_margin, _surface_y() - surface_margin)
	_flee = 2.5


func _die() -> void:
	if item:
		if caught_by != 0:
			CreatureService.deliver_catch(caught_by, item, weight)  # speared: rides back on the line
		else:
			var dropped := ItemService.spawn(item, weight, global_position, Vector3.UP * 1.0)
			if dropped:
				dropped.global_basis = global_basis
				HitFlash.flash(dropped.get_node("Model"), 1.0, 0.5)  # dead: redder, then back to normal
	queue_free()


func _surface_y() -> float:
	return ocean.sea_level if ocean else 0.0


func _floor_y() -> float:
	return _floor_y_at(global_position.x, global_position.z)


func _floor_y_at(x: float, z: float) -> float:
	return terrain.get_floor_height(x, z) if terrain else -30.0
