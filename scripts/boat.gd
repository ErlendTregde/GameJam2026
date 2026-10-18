class_name Boat
extends RigidBody3D
## Floats using the Marker3D children of $Probes and can be driven from the helm.
## Water drag comes from the body's linear/angular damping (set in the inspector).

@export var ocean: Ocean
## Equilibrium depth of the probes is 1 / float_force meters.
@export var float_force := 3.0
@export var engine_force := 9000.0
@export var turn_torque := 4500.0
## Resists sliding sideways, like a keel.
@export var keel_drag := 1.5
@export var mouse_sensitivity := 0.003
## Can't be steered until unlocked (e.g. by beating the island's boss).
@export var locked := false
@export var locked_text := "Locked: beat the boss in the deep water"

var driving := false
var _player: Player

@onready var _probes := $Probes.get_children()
@onready var _propeller: Marker3D = $Propeller
@onready var _pivot: Node3D = $CameraPivot
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _deck: Node3D = $Deck
@onready var _prompt: Label = $HUD/Prompt


func _physics_process(_delta: float) -> void:
	var lift := float_force * get_gravity().length() * mass / _probes.size()
	for probe: Marker3D in _probes:
		var depth := ocean.get_height(probe.global_position) - probe.global_position.y
		if depth > 0.0:
			apply_force(Vector3.UP * lift * depth, probe.global_position - global_position)

	var side := global_basis.x
	apply_central_force(-side * side.dot(linear_velocity) * keel_drag * mass)

	if driving:
		if ocean.get_height(_propeller.global_position) > _propeller.global_position.y:
			var throttle := Input.get_axis("move_back", "move_forward")
			apply_force(-global_basis.z * throttle * engine_force, _propeller.global_position - global_position)
		apply_torque(global_basis.y * Input.get_axis("move_right", "move_left") * turn_torque)

	_pivot.global_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if driving:
			_set_driving(false)
		elif _player and not locked:
			_set_driving(true)
	elif driving and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		_arm.rotation.x = clampf(_arm.rotation.x - event.relative.y * mouse_sensitivity, -1.3, 0.2)


func _set_driving(value: bool) -> void:
	driving = value
	if _player.get_parent() != _deck:
		_player.reparent(_deck)  # make sure the player rides along while steering
	_player.set_controlled(not value)
	if value:
		_camera.make_current()
	_prompt.text = "[E] leave helm   [W/S] throttle   [A/D] steer" if value else "[E] take the helm"


func _on_helm_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body
		_prompt.text = locked_text if locked else "[E] take the helm"
		_prompt.visible = true


func _on_helm_body_exited(body: Node3D) -> void:
	if body == _player and not driving:
		_player = null
		_prompt.visible = false
