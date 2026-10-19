class_name CanalGate
extends Node3D
## The way out through the canal is by boat only: a swimmer can't get past this point (an
## invisible wall across the canal, facing out along -Z) and is told why. The boat, and anyone on
## its deck, goes through.

@export var player: Player
## Half the canal's width (m): the wall spans this far to each side.
@export var half_width := 12.0
@export var text := "You need the boat to leave"

var _shown := 0.0
var _message: Label


func _physics_process(delta: float) -> void:
	if _shown > 0.0:
		_shown -= delta
		if _shown <= 0.0 and _message and _message.text == text:
			_message.visible = false
	if player == null or player.get_parent().is_in_group(&"platform"):
		return  # on the boat
	var out := -global_basis.z
	var rel := player.global_position - global_position
	var past := rel.dot(out)
	if past > 0.0 and past < 40.0 and absf(rel.dot(global_basis.x)) < half_width:
		player.global_position -= out * past
		player.velocity -= out * maxf(player.velocity.dot(out), 0.0)
		_message = player.get_node("HUD/Message")
		_message.text = text
		_message.visible = true
		_shown = 2.0
