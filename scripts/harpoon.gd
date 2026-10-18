class_name Harpoon
extends RigidBody3D
## A speargun shot: the spear flies on a line, slowed by the water. It damages what it hits; a
## fish it kills stays on the spear. Then (or when the line runs out) the line pulls it back to
## `catcher`, and whatever it carries goes to `player` (into the hotbar).

signal returned

@export var damage := 25.0
## How fast the line pulls it back (m/s).
@export var reel_speed := 12.0
## Line length (m): the spear stops and comes back here.
@export var max_range := 9.0
@export var line_color := Color(0.12, 0.12, 0.12)

## The camera it is pulled back to, and who gets the catch; set by whoever fires it.
var catcher: Node3D
var player: Node
## Where the line leaves the gun, in the catcher's (camera) space; kept up to date by the gun.
var muzzle := Vector3(0.15, -0.15, -0.5)

var _reeling := false
var _catch: WorldItem
var _line := ImmediateMesh.new()
var _line_material := StandardMaterial3D.new()

@onready var _tip: Marker3D = $Tip


func _ready() -> void:
	body_entered.connect(_on_hit)
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = line_color
	var line := MeshInstance3D.new()
	line.mesh = _line
	line.top_level = true  # drawn in world space
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)


func _physics_process(delta: float) -> void:
	if not _reeling:
		if linear_velocity.length() > 1.0:
			look_at(global_position + linear_velocity, Vector3.UP)
		if global_position.distance_to(catcher.global_position) > max_range or linear_velocity.length() < 3.0:
			_reel()
	else:
		var to := catcher.global_position - global_position
		if to.length() < 0.8:
			_deliver()
			return
		global_position += to.normalized() * minf(reel_speed * delta, to.length())
		look_at(catcher.global_position, Vector3.UP)
		rotate_object_local(Vector3.UP, PI)  # point first, as if dragged by its tail
	_draw_line()


func _on_hit(body: Node) -> void:
	if _reeling:
		return
	var target := body
	while target and not target.has_method("take_damage"):
		target = target.get_parent()
	if target:
		if target.has_signal("killed"):
			target.killed.connect(_grab, CONNECT_ONE_SHOT)
		target.take_damage(damage, global_position)
	_reel()


## A fish (or crab) killed by the spear: it rides back on the tip.
func _grab(drop: WorldItem) -> void:
	_catch = drop
	drop.freeze = true
	drop.collision_layer = 0
	drop.collision_mask = 0
	drop.reparent.call_deferred(self)
	drop.set_deferred("position", _tip.position)


func _reel() -> void:
	_reeling = true
	freeze = true
	collision_mask = 0


func _deliver() -> void:
	if is_instance_valid(_catch) and player:
		player.give(_catch.item, _catch.weight)
		_catch.queue_free()
	returned.emit()
	queue_free()


## The line from the gun's muzzle to the spear.
func _draw_line() -> void:
	var from := catcher.global_position + catcher.global_basis * muzzle
	_line.clear_surfaces()
	_line.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	_line.surface_add_vertex(from)
	_line.surface_add_vertex(global_position)
	_line.surface_end()
