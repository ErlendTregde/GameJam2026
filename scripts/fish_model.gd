@tool
extends Node3D
## One fish from the fish kit (the kit holds a yellow and a blue fish side by side), centered
## on this node, facing -Z and scaled to `length`. Used by the live fish and the fish item.

enum Variant { YELLOW, BLUE }

## [nodes of that fish, center in the kit, length in the kit]
const KIT := {
	Variant.YELLOW: [["Armature_001", "Sphere", "Sphere_001"], Vector3(0.0, 4.75, 2.6), 8.0],
	Variant.BLUE: [["Armature_000", "Sphere_002", "Sphere_003"], Vector3(-3.43, 4.35, 5.4), 5.1],
}

@export var variant := Variant.YELLOW:
	set(value):
		variant = value
		if is_inside_tree():
			_apply()
## Nose-to-tail length (m).
@export var length := 0.55:
	set(value):
		length = value
		if is_inside_tree():
			_apply()


## Recolours the fish (white = its own colours), so one model makes several kinds.
@export var tint := Color.WHITE
## Fish are small and mostly under water: their shadows are invisible but cost a lot.
@export var cast_shadows := false
## Not drawn beyond this distance (m); 0 = always.
@export var visible_distance := 60.0


func _ready() -> void:
	_apply()
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = visible_distance
		mesh.set_instance_shader_parameter("tint", tint)


## Swim animation per variant with only that fish's tracks; built once, shared by all fish.
static var _trimmed := {}


func _apply() -> void:
	var kit := $Kit as Node3D
	var parts: Array = KIT[variant][0]
	var removed := []
	for node in kit.find_child("Root", true, false).get_children():
		node.visible = String(node.name) in parts
		if not node.visible and not Engine.is_editor_hint():
			removed.append(String(node.name))
			node.queue_free()  # the other fish: gone in game, so its skeleton isn't animated for nothing
	if not removed.is_empty():
		_use_trimmed_animation(kit.get_node("AnimationPlayer"), removed)
	var s: float = length / KIT[variant][2]
	kit.scale = Vector3.ONE * s
	kit.position = -KIT[variant][1] * s


## The swim animation, looping. Speed 0 pauses it (e.g. when the fish is too far to see).
func swim(speed_scale := 1.0) -> void:
	var player := $Kit/AnimationPlayer as AnimationPlayer
	if not player.is_playing():
		player.get_animation("Take 01").loop_mode = Animation.LOOP_LINEAR
		player.play("Take 01")
	player.active = speed_scale > 0.0
	if player.speed_scale != speed_scale:
		player.speed_scale = speed_scale


func _use_trimmed_animation(player: AnimationPlayer, removed: Array) -> void:
	if variant not in _trimmed:
		var anim: Animation = player.get_animation("Take 01").duplicate()
		for t in range(anim.get_track_count() - 1, -1, -1):
			var path := String(anim.track_get_path(t))
			if removed.any(func(node_name: String) -> bool: return "/" + node_name + "/" in path or path.ends_with("/" + node_name)):
				anim.remove_track(t)
		anim.loop_mode = Animation.LOOP_LINEAR
		var library := AnimationLibrary.new()
		library.add_animation("Take 01", anim)
		_trimmed[variant] = library
	player.remove_animation_library("")
	player.add_animation_library("", _trimmed[variant])
