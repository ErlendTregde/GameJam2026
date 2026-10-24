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
## > 0 makes it a gamble chest: opening costs this much, and it closes again after reset_time.
@export var cost := 0
@export var reset_time := 0.0
## Its loot is the treasure: each item counts toward the gold that unlocks the boat (WorldEvents).
@export var treasure := false

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
	if opened:
		return ""
	return "[E] $%d" % cost if cost > 0 else "[E] open chest"


func interact(player: Node) -> void:
	if opened or (cost > 0 and not player.spend(cost)):
		return
	if P2P.acts_as_host():
		open()
	else:
		WorldEvents.request_open_chest(self, cost)  # refunded if someone else got there first


## Host only: opens it for everyone and throws the loot out (closes again for a gamble chest).
func open() -> void:
	if opened:
		return
	WorldEvents.set_chest_lid(self, true)
	await get_tree().create_timer(0.3).timeout  # lid is up
	var rng := RandomNumberGenerator.new()
	for item in loot.roll(rng) if loot else []:
		var sideways := global_basis.x * rng.randf_range(-1.2, 1.2)
		var spawned := ItemService.spawn(item, 0.0, _spawn.global_position, global_basis.z * toss.x + Vector3.UP * toss.y + sideways)
		if treasure and spawned:
			spawned.set_meta(&"treasure", true)  # counted when first picked up (on the host)
		await get_tree().create_timer(item_interval).timeout
	if reset_time > 0.0:
		await get_tree().create_timer(reset_time).timeout
		WorldEvents.set_chest_lid(self, false)


## Opens or closes the lid (every peer); `opened` follows it, so the prompt matches.
func show_lid(open_lid: bool) -> void:
	if open_lid == opened:
		return
	opened = open_lid
	var animation := $Model/AnimationPlayer as AnimationPlayer
	if open_lid:
		animation.play(KIT[tier][2])
	else:
		animation.play_backwards(KIT[tier][2])
