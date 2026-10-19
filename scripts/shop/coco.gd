class_name Coco
extends Node3D
## Coco, the coconut who runs the shop. Watches you, gives tips when you stand close, and says a
## line when you sell.

@export var lines: Array[String] = [
	"Fresh fish! Smells like profit.",
	"I'm technically fruit, but I'll allow it.",
	"Pleasure doing business.",
	"Keep 'em coming!",
]
## Said instead when the sale has a big catch in it.
@export var big_lines: Array[String] = [
	"Now THAT's a chonker!",
	"Whoa. Did you wrestle that one?",
]
## Said one after another while you stand close, now and then.
@export var tips: Array[String] = [
	"Catch fish and crabs, then sell them on my table!",
	"Punch the palm trees. Coconuts and planks fall out.",
	"Save up for a spear. Rocks barely scratch a shark.",
	"The deep water past the reef? Shark territory.",
	"Hold your breath down there. Watch your air!",
	"Feeling lucky? That chest is $15 a go.",
]
@export var tip_distance := 4.0
## Seconds between tips.
@export var tip_interval := 14.0
@export var bubble: Label3D
## Seconds a line stays up.
@export var talk_time := 3.0
## Turns its head to watch you within this distance (m), this fast.
@export var watch_distance := 8.0
@export var turn_speed := 6.0

## When set, Coco looks at this point (e.g. the cursor on the main menu) instead of the player.
var look_target: Variant = null
var _hide: SceneTreeTimer
var _tip := 0
var _tip_wait := 0.0

@onready var _head: Node3D = $Head


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var yaw := 0.0  # facing forward when nobody is near
	var pitch := 0.0
	if look_target != null:
		var to := to_local(look_target) - _head.position
		yaw = atan2(to.x, to.z)  # the face is on +Z
		pitch = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6)
	elif camera and global_position.distance_to(camera.global_position) < watch_distance:
		var to := to_local(camera.global_position)
		yaw = atan2(to.x, to.z)
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw, minf(turn_speed * delta, 1.0))
	_head.rotation.x = lerpf(_head.rotation.x, pitch, minf(turn_speed * delta, 1.0))
	_tip_wait -= delta
	var near := camera != null and global_position.distance_to(camera.global_position) < tip_distance
	if near and not tips.is_empty() and _tip_wait <= 0.0 and not bubble.visible:
		say_line(tips[_tip % tips.size()])
		_tip += 1


func say(big: bool) -> void:
	say_line((big_lines if big and not big_lines.is_empty() else lines).pick_random())


func say_line(text: String) -> void:
	bubble.text = text
	bubble.visible = true
	_tip_wait = tip_interval
	var timer := get_tree().create_timer(talk_time)
	_hide = timer
	timer.timeout.connect(func() -> void:
		if _hide == timer:  # not replaced by a newer line
			bubble.visible = false)
