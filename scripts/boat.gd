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
## Multiplayer: the peer at the helm (0 = nobody). The driver simulates the boat, or the host
## when nobody drives; everyone else follows the transform they stream (WorldEvents).
var driver := 0
var _player: Player
var _follow_to := Transform3D()
var _following := false

@onready var _probes := $Probes.get_children()
@onready var _propeller: Marker3D = $Propeller
@onready var _pivot: Node3D = $CameraPivot
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _deck: Node3D = $Deck
@onready var _prompt: Label = $HUD/Prompt


func _ready() -> void:
	add_to_group(&"boats")


func authority_peer() -> int:
	return driver if driver != 0 else 1


func is_authority() -> bool:
	return not P2P.is_online() or authority_peer() == P2P.local_peer_id()


## Someone took (or left) the helm; only the authority simulates, the rest follow.
func set_driver(peer_id: int) -> void:
	driver = peer_id
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = not is_authority()
	_following = false
	var mine := peer_id != 0 and peer_id == P2P.local_peer_id()
	if mine and not driving and _player:
		_set_driving(true)
	elif not mine and driving:
		_set_driving(false)


## A transform from the authority (the driver, or the host).
func follow(xform: Transform3D, velocity: Vector3, snap := false) -> void:
	if is_authority():
		return
	_follow_to = xform
	_following = true
	linear_velocity = velocity
	if snap:
		global_transform = xform


func _physics_process(delta: float) -> void:
	_pivot.global_position = global_position
	if not is_authority():
		if _following:
			var k := minf(10.0 * delta, 1.0)
			global_transform = Transform3D(global_basis.slerp(_follow_to.basis, k).orthonormalized(), global_position.lerp(_follow_to.origin, k))
		return
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if driving:
			WorldEvents.release_helm(self)  # set_driver() then lets go everywhere
		elif _player and not locked:
			WorldEvents.request_helm(self)
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
