class_name Crab
extends Node3D

## A beach crab: wanders along the sand, scuttles away sideways when the player comes close,
## and leaves `item` (with its size) behind when killed. Sticks to the terrain height.

@export var item: ItemData
@export var health := 6.0
@export var speed := 0.8
@export var flee_speed := 3.5
## Flees when the player is closer than this (m).
@export var scare_distance := 4.0
## Stays on ground between these heights (the beach).
@export var min_height := 0.7
@export var max_height := 2.5

var terrain: Terrain
var player: Node3D
var weight := 0.0
## Peer whose speargun spear hit it last: if it dies of that, the catch rides back to them.
var caught_by := 0

var _target := Vector3.ZERO
var _wait := 0.0


func _ready() -> void:
	if item:
		if CreatureService.simulates():  # a client's puppet gets its size from the host
			weight = item.roll_weight(RandomNumberGenerator.new())
		$Model.scale *= item.size_scale(weight)
	_target = global_position
	CreatureService.register(self)


func _exit_tree() -> void:
	CreatureService.unregister(self)


func _physics_process(delta: float) -> void:
	if not CreatureService.simulates() or terrain == null:
		return  # a puppet (CreatureService moves it), or one left over while leaving a game
	var scarer := WorldService.nearest_player(global_position) if WorldService.in_world() else (player if is_instance_valid(player) else null)
	var move_speed := speed
	if scarer and global_position.distance_to(scarer.global_position) < scare_distance:
		var away := (global_position - scarer.global_position) * Vector3(1, 0, 1)
		_target = global_position + away.normalized() * 3.0
		move_speed = flee_speed
	elif global_position.distance_to(_target) < 0.2:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
		return
	var step := (_target - global_position) * Vector3(1, 0, 1)
	if step.length() < 0.01:
		return
	var next := global_position + step.normalized() * minf(move_speed * delta, step.length())
	var h := terrain.get_floor_height(next.x, next.z)
	if h < min_height or h > max_height:
		_pick_target()  # don't walk into the sea or up the hill
		return
	global_position = Vector3(next.x, h, next.z)
	# Crabs walk sideways: face across the direction of travel.
	look_at(global_position + step.normalized().cross(Vector3.UP), Vector3.UP)


func _pick_target() -> void:
	_wait = randf_range(0.5, 2.5)
	var a := randf() * TAU
	_target = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 4.0)


func take_damage(amount: float, _at := Vector3.ZERO) -> void:
	health -= amount
	CreatureService.flashed(self)
	if health > 0.0:
		HitFlash.flash($Model)
		_wait = 0.0
		return
	if item:
		if caught_by != 0:
			CreatureService.deliver_catch(caught_by, item, weight)  # speared: rides back on the line
		else:
			var dropped := ItemService.spawn(item, weight, global_position + Vector3.UP * 0.3)
			if dropped:
				HitFlash.flash(dropped.get_node("Model"), 1.0, 0.5)  # dead: redder, then back to normal
	queue_free()
