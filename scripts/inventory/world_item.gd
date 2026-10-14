class_name WorldItem
extends RigidBody3D
## An item lying in the world, picked up when the player looks at it and presses interact.
## Its look ("Model") and collider are authored in its scene; this only says which item it is.
## It falls normally, but once it lands it stays put instead of rolling away. Landing on a
## moving platform (the boat deck) makes it ride along.

@export var item: ItemData
## Comes to rest as soon as it touches the ground.
@export var settle_on_landing := true

var _settling := false


func _ready() -> void:
	if settle_on_landing and not freeze:
		contact_monitor = true
		max_contacts_reported = 1
		body_entered.connect(_on_landed)


func _on_landed(body: Node) -> void:
	if _settling:
		return
	_settling = true
	# Let it tip over and lie flat (long items land end-first), but kill rolling and sliding.
	angular_damp = 6.0
	linear_damp = 3.0
	var waited := 0.0
	while waited < 1.5 and (linear_velocity.length() > 0.15 or angular_velocity.length() > 0.3 or waited < 0.2):
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		waited += get_physics_process_delta_time()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var ground := body
	if ground is Node3D and ground.is_in_group("platform"):
		reparent(ground)
