class_name ThrownWeapon
extends RigidBody3D
## A thrown weapon (the trident): flies point-first, damages the first thing it hits, then flies
## back to `catcher` and emits `returned`. Turns around on its own after `max_flight_time`.

signal returned

@export var damage := 40.0
## How fast it flies back (m/s).
@export var return_speed := 28.0
@export var max_flight_time := 1.6

## Where it flies back to (the player's camera), set by whoever throws it.
var catcher: Node3D

var _returning := false
var _flight := 0.0


func _ready() -> void:
	body_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	_flight += delta
	if not _returning:
		if linear_velocity.length() > 1.0:
			look_at(global_position + linear_velocity, Vector3.UP)
		if _flight > max_flight_time:
			_return()
		return
	var to := catcher.global_position - global_position
	if to.length() < 0.8:
		returned.emit()
		queue_free()
		return
	global_position += to.normalized() * minf(return_speed * delta, to.length())
	look_at(catcher.global_position, Vector3.UP)
	rotate_object_local(Vector3.UP, PI)  # handle first on the way back


func _on_hit(body: Node) -> void:
	if _returning:
		return
	var target := body
	while target and not target.has_method("take_damage"):
		target = target.get_parent()
	if target:
		WorldService.hit(target, damage, global_position)
	_return()


func _return() -> void:
	_returning = true
	freeze = true
	collision_mask = 0
