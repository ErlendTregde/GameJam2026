class_name Shark
extends Node3D
## A shark that hunts a swimmer: it comes in from out of sight and first circles them near the
## surface with its fin showing (the warning), then chases, bites, backs off and comes around
## again. When told to leave (the swimmer is safe), it swims away and disappears.
## Hitting it scares it off for a moment. Spawned and controlled by a SharkZone.

signal gone
signal died

@export var display_name := "Great White"
@export var max_health := 200.0
## Dropped where it dies (a trophy worth a lot at the scale).
@export var trophy: ItemData

@export var chase_speed := 8.0
@export var lunge_speed := 11.0
@export var leave_speed := 6.0
@export var turn_speed := 3.2
## Bites when its head gets this close (m).
@export var bite_range := 2.5
@export var bite_damage := 40.0
## How far above its mouth it can still bite, e.g. a swimmer jumping at the surface (m).
@export var breach_height := 3.2
## After a bite it swims past and away for this long before turning back (s).
@export var back_off_time := 0.9
## Stays at least this far under the surface (m).
@export var surface_margin := 0.8
## Gone once it is this far from the target while leaving (m).
@export var despawn_distance := 45.0
@export_group("Warning")
## Circles this far from the swimmer before attacking (m), this fast (m/s).
@export var circle_radius := 9.0
@export var circle_speed := 4.5
## While circling it swims this shallow, so the dorsal fin cuts the surface (m below).
@export var circle_depth := 0.45

## Seconds it circles before attacking; set by the SharkZone.
var warning_time := 5.0

var target: Node3D
var ocean: Ocean
var terrain: Terrain

var _leaving := false
var _back_off := 0.0
var _circled := 0.0
var health := 0.0
var _dead := false

@onready var _animations: AnimationPlayer = $Model/AnimationPlayer
@onready var _mouth: Marker3D = $Mouth


func _ready() -> void:
	health = max_health
	_animations.get_animation("Swim").loop_mode = Animation.LOOP_LINEAR
	_animations.play("Swim")


## Hunt `target` again (after leaving).
func hunt() -> void:
	_leaving = false


## Give up and swim away.
func leave() -> void:
	_leaving = true


func is_leaving() -> bool:
	return _leaving


## Still giving its warning (circling), not attacking yet.
func is_circling() -> bool:
	return not _leaving and _circled < warning_time


func is_dead() -> bool:
	return _dead


func take_damage(amount: float, _at := Vector3.ZERO) -> void:
	if _dead:
		return
	health = maxf(health - amount, 0.0)
	if health == 0.0:
		_die()
		return
	_back_off = maxf(_back_off, 1.2)  # stabbed: veers off, but only briefly


func _die() -> void:
	_dead = true
	died.emit()
	if trophy:
		var drop: WorldItem = load(trophy.scene_path).instantiate()
		var world := get_tree().current_scene if get_tree().current_scene else get_tree().root.get_child(-1)
		world.add_child(drop)  # tests run without a current_scene: main is the root's last child
		drop.global_position = global_position + Vector3.UP
	_animations.speed_scale = 0.2
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "rotation:z", PI, 1.2)  # belly up
	tween.tween_property(self, "global_position:y", global_position.y - 4.0, 2.5)
	tween.chain().tween_callback(func() -> void:
		gone.emit()
		queue_free())


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if target == null or not is_instance_valid(target):
		_leaving = true
	var to_target := (target.global_position + Vector3.UP * 0.9 - global_position) if is_instance_valid(target) else -global_basis.z
	var speed := chase_speed
	var want := to_target
	if _leaving:
		want = -to_target
		want.y = 0.0
		speed = leave_speed
		if to_target.length() > despawn_distance:
			gone.emit()
			queue_free()
			return
	elif _circled < warning_time:
		# Warning: circle the swimmer, near the surface.
		_circled += delta
		var flat := Vector3(-to_target.x, 0.0, -to_target.z)  # from swimmer to shark
		var around := flat.normalized().rotated(Vector3.UP, 0.7) * circle_radius if flat.length() > 0.1 else Vector3.FORWARD * circle_radius
		want = target.global_position + around - global_position
		want.y = 0.0
		var up := (ocean.get_height(global_position) - circle_depth if ocean else 0.0) - global_position.y
		global_position.y += clampf(up, -2.0 * delta, 2.0 * delta)  # rise until the fin shows
		speed = circle_speed
	elif _back_off > 0.0:
		_back_off -= delta
		want = -global_basis.z + global_basis.x * 0.6  # swim on past, curving away
	else:
		var close := to_target.length()
		if close < 6.0:
			speed = lunge_speed
		# Bites what is close, including a swimmer just above the water (it lunges up at them).
		var reach := target.global_position + Vector3.UP * 0.9 - _mouth.global_position
		if Vector2(reach.x, reach.z).length() < bite_range and reach.y < breach_height:
			target.take_damage(bite_damage, global_position)
			_back_off = back_off_time
	if want.length() > 0.01:
		var turn := Basis.looking_at(want.normalized())
		global_basis = global_basis.slerp(turn, minf(turn_speed * delta, 1.0)).orthonormalized()
	global_position += -global_basis.z * speed * delta
	# Stay in the water: under the surface, above the sea floor.
	var margin := circle_depth if is_circling() else surface_margin
	var surface := ocean.get_height(global_position) - margin if ocean else 0.0
	var floor_y := terrain.get_floor_height(global_position.x, global_position.z) + 0.8 if terrain else -50.0
	global_position.y = clampf(global_position.y, minf(floor_y, surface), surface)
	_animations.speed_scale = speed / chase_speed * 1.6
