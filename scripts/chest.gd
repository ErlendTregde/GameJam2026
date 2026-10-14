@tool
class_name Chest
extends StaticBody3D
## A loot chest. Interact (E) to open it: it plays its open animation and its loot pops out
## and lands on the ground in front of it. The tier picks which chest of the kit is shown.

enum Tier { WOODEN, SILVER, GOLD }

## The chest kit holds all three chests side by side: [node name, x position, animation].
const KIT := {
	Tier.WOODEN: ["WoodenChest", 3.964, "WoodenChest|OpenChest"],
	Tier.SILVER: ["SilverChest[", 1.992, "SilverChest_|OpenChest"],
	Tier.GOLD: ["GoldenChest", 0.0, "GoldenChest|OpenChest"],
}

@export var tier := Tier.WOODEN:
	set(value):
		tier = value
		if is_inside_tree():
			_show_tier()
@export var loot: LootTable
## How hard the loot is tossed out of the chest (forward, up), m/s.
@export var toss := Vector2(1.5, 3.0)
## Seconds between each item popping out.
@export var item_interval := 0.15

var opened := false

@onready var _spawn: Marker3D = $LootSpawn


func _ready() -> void:
	_show_tier()


func _show_tier() -> void:
	var model := $Model
	for t in KIT:
		var chest := model.find_child(KIT[t][0], true, false) as Node3D
		if chest:
			chest.visible = t == tier
	model.position.x = -KIT[tier][1] * model.scale.x


func get_prompt() -> String:
	return "" if opened else "E  open chest"


func interact(_player: Node) -> void:
	if opened:
		return
	opened = true
	($Model/AnimationPlayer as AnimationPlayer).play(KIT[tier][2])
	await get_tree().create_timer(0.3).timeout  # lid is up
	var rng := RandomNumberGenerator.new()
	for item in loot.roll(rng) if loot else []:
		var dropped: RigidBody3D = load(item.scene_path).instantiate()
		get_parent().add_child(dropped)
		dropped.global_position = _spawn.global_position
		var sideways := global_basis.x * rng.randf_range(-1.2, 1.2)
		dropped.linear_velocity = global_basis.z * toss.x + Vector3.UP * toss.y + sideways
		dropped.angular_velocity = Vector3(rng.randf(), rng.randf(), rng.randf()) * 4.0
		await get_tree().create_timer(item_interval).timeout
