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

var _target := Vector3.ZERO
var _wait := 0.0


func _ready() -> void:
	if item:
		weight = item.roll_weight(RandomNumberGenerator.new())
		$Model.scale *= item.size_scale(weight)
	_target = global_position


func _physics_process(delta: float) -> void:
	var move_speed := speed
	if player and global_position.distance_to(player.global_position) < scare_distance:
		var away := (global_position - player.global_position) * Vector3(1, 0, 1)
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
	if health > 0.0:
		HitFlash.flash($Model)
		_wait = 0.0
		return
	if item:
		var dropped: WorldItem = load(item.scene_path).instantiate()
		dropped.weight = weight
		var world := get_tree().current_scene if get_tree().current_scene else get_tree().root.get_child(-1)
		world.add_child(dropped)  # tests run without a current_scene: main is the root's last child
		dropped.global_position = global_position + Vector3.UP * 0.3
		HitFlash.flash(dropped.get_node("Model"), 1.0, 0.5)  # dead: redder, then back to normal
	queue_free()
