class_name Shark
extends Node3D
## A shark that swims its `patrol` path until it is told to hunt a swimmer: it first circles
## them near the surface with its fin showing (the warning), then chases, bites, backs off and
## comes around again. When told to leave (the swimmer got away), it swims back to its patrol.
## Hitting it scares it off for a moment. Spawned and controlled by a SharkZone.

## After it died and sank (then it is freed).
signal gone
signal died

@export var display_name := "Great White"
@export var max_health := 200.0
## Scales the model, mouth and hitbox (the body itself stays unscaled: its turning re-normalizes it).
@export var size := 1.0
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
## Swimming its patrol path (m/s); it heads back to the path at `leave_speed`.
@export var patrol_speed := 4.0
@export_group("On land")
## Water shallower than this (m) counts as land: the shark flops after you in hops.
@export var beach_depth := 0.8
@export var land_speed := 3.5
## How high each hop goes (m), and hops per second.
@export var hop_height := 0.9
@export var hop_rate := 1.6
## Side-to-side rock while flopping (radians).
@export var flop_roll := 0.35
@export_group("Warning")
## Circles this far from the swimmer before attacking (m), this fast (m/s).
@export var circle_radius := 9.0
@export var circle_speed := 4.5
## While circling it swims this shallow, so the dorsal fin cuts the surface (m below).
@export var circle_depth := 0.45

## Seconds it circles before attacking; set by the SharkZone.
var warning_time := 5.0

var target: Node3D
## The loop it swims while not hunting; set by the SharkZone.
var patrol: Path3D
var ocean: Ocean
var terrain: Terrain

var _leaving := false
var _back_off := 0.0
var _circled := 0.0
var _hop := 0.0  # hop phase while on land
var health := 0.0
var _dead := false

@onready var _animations: AnimationPlayer = $Model/AnimationPlayer
@onready var _mouth: Marker3D = $Mouth


func _ready() -> void:
	health = max_health
	$Model.scale *= size
	$Hitbox.scale *= size
	_mouth.position *= size
	_animations.get_animation("Swim").loop_mode = Animation.LOOP_LINEAR
	_animations.play("Swim")
	CreatureService.register(self)


func _exit_tree() -> void:
	CreatureService.unregister(self)


## A client's puppet: the host's health and mood, for the boss bar.
func mirror(new_health: float, leaving: bool, dead: bool) -> void:
	health = new_health
	_leaving = leaving
	_dead = dead


## Hunt `target` (starting with the warning circle).
func hunt() -> void:
	_leaving = false
	_circled = 0.0


## Give up and swim back to the patrol.
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
	CreatureService.flashed(self)
	if health == 0.0:
		_die()
		return
	_back_off = maxf(_back_off, 1.2)  # stabbed: veers off, but only briefly


func _die() -> void:
	_dead = true
	died.emit()
	if trophy:
		ItemService.spawn(trophy, 0.0, global_position + Vector3.UP)
	_animations.speed_scale = 0.2
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "rotation:z", PI, 1.2)  # belly up
	tween.tween_property(self, "global_position:y", global_position.y - 4.0, 2.5)
	tween.chain().tween_callback(func() -> void:
		gone.emit()
		queue_free())


func _physics_process(delta: float) -> void:
	if _dead or not CreatureService.simulates():
		return
	if target == null or not is_instance_valid(target):
		_leaving = true
	var to_target := (target.global_position + Vector3.UP * 0.9 - global_position) if is_instance_valid(target) else -global_basis.z
	var speed := chase_speed
	var want := to_target
	if _leaving:
		want = _patrol_heading()
		speed = leave_speed if want.length() > 6.0 else patrol_speed
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
	var floor_here := terrain.get_floor_height(global_position.x, global_position.z) if terrain else -50.0
	var beached := ocean != null and ocean.sea_level - floor_here < beach_depth
	if beached:
		want.y = 0.0  # level, nose along the ground
		speed = minf(speed, land_speed)
	if want.length() > 0.01:
		var turn := Basis.looking_at(want.normalized())
		global_basis = global_basis.slerp(turn, minf(turn_speed * delta, 1.0)).orthonormalized()
	global_position -= global_basis.z * speed * delta
	if beached:
		_flop(delta)
		return
	_hop = 0.0
	# In the water: under the surface, above the sea floor.
	var margin := circle_depth if is_circling() else surface_margin
	var surface := ocean.get_height(global_position) - margin if ocean else 0.0
	var floor_y := terrain.get_floor_height(global_position.x, global_position.z) + 0.8 if terrain else -50.0
	global_position.y = clampf(global_position.y, minf(floor_y, surface), surface)
	_animations.speed_scale = speed / chase_speed * 1.6


## Toward a point a little ahead along the patrol path, from the closest point on it (so far
## off it heads back to the path, and on it, follows it round).
func _patrol_heading() -> Vector3:
	if patrol == null or patrol.curve.point_count < 2:
		return -global_basis.z
	var curve := patrol.curve
	var along := curve.get_closest_offset(patrol.to_local(global_position)) + 4.0
	return patrol.to_global(curve.sample_baked(fposmod(along, curve.get_baked_length()))) - global_position


## Out of the water: it hops along the ground after its target, rocking from side to side.
func _flop(delta: float) -> void:
	_hop += delta * hop_rate
	var ground := terrain.get_floor_height(global_position.x, global_position.z) if terrain else global_position.y
	global_position.y = ground + 0.6 * size + absf(sin(_hop * PI)) * hop_height
	# Level with the ground, facing where it goes, rocking (set fresh each frame, so it never builds up).
	var heading := -global_basis.z * Vector3(1, 0, 1)
	if heading.length() > 0.01:
		global_basis = Basis.looking_at(heading.normalized()) * Basis(Vector3.FORWARD, sin(_hop * TAU) * flop_roll)
	_animations.speed_scale = 2.5
