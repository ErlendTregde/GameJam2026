class_name Combat
extends Node
## Melee with the held item: attack (left click) swings it and damages whatever the AttackCast
## finds within the item's reach. Anything with a take_damage(amount, at) method, on the body
## hit or one of its parents, can be hurt (`at` is where the hit landed). The player sets `item` whenever the held item changes.
## Throwable weapons (ItemData.thrown_scene): a tap is melee, holding charges a throw and
## letting go throws it, farther the longer it was held; it flies back to the hand after.

## Finds what a swing hits; its length is set to the weapon's reach.
@export var cast: ShapeCast3D
## Plays the swing and the charge pose.
@export var held_view: Node
## Seconds into the swing when the hit lands.
@export var hit_delay := 0.13
## Used when the hand is empty (punching).
@export var fist: ItemData

@export_group("Throw")
## Holding attack longer than this starts a throw instead of a melee hit.
@export var tap_time := 0.2
## Seconds of holding for the strongest throw.
@export var full_charge_time := 1.2
@export var min_throw_speed := 10.0
@export var max_throw_speed := 32.0

## The held item; only items with damage > 0 can attack. Switching cancels a charging throw.
var item: ItemData:
	set(value):
		item = value
		_hold = -1.0
		if held_view:
			held_view.set_charge(0.0)
## The item currently flying (it is back in the hand when this is null again).
var thrown_item: ItemData

var _cooldown := 0.0
var _hold := -1.0  # seconds attack has been held for a throwable; -1 = not holding


func _process(delta: float) -> void:
	_cooldown -= delta
	held_view.set_hidden(thrown_item != null and item == thrown_item)
	if _hold >= 0.0:
		_hold += delta
		held_view.set_charge(_charge())


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not event.is_action("attack"):
		return
	var can_throw := item != null and item.thrown_scene != null and thrown_item == null
	if event.is_pressed():
		if can_throw:
			_hold = 0.0
		else:
			attack()
	elif _hold >= 0.0:
		var held := _hold
		_hold = -1.0
		held_view.set_charge(0.0)
		if held < tap_time:
			attack()
		else:
			_throw(_charge_for(held))


func attack() -> void:
	var weapon := item if item else fist
	if weapon == null or weapon.damage <= 0.0 or _cooldown > 0.0 or (item and item == thrown_item):
		return
	_cooldown = weapon.cooldown
	held_view.swing()
	await get_tree().create_timer(hit_delay).timeout
	cast.target_position = Vector3(0, 0, -weapon.reach)
	cast.force_shapecast_update()
	var hit := []
	for i in cast.get_collision_count():
		var target := _damageable(cast.get_collider(i))
		if target and target not in hit:
			hit.append(target)
			target.take_damage(weapon.damage, cast.get_collision_point(i))


func _charge() -> float:
	return _charge_for(_hold)


func _charge_for(held: float) -> float:
	return clampf((held - tap_time) / (full_charge_time - tap_time), 0.0, 1.0)


func _throw(charge: float) -> void:
	thrown_item = item
	var camera := cast.get_parent() as Node3D
	var thrown: ThrownWeapon = item.thrown_scene.instantiate()
	thrown.damage = item.damage
	thrown.catcher = camera
	(get_tree().current_scene if get_tree().current_scene else get_tree().root).add_child(thrown)
	thrown.global_position = camera.global_position - camera.global_basis.z * 0.8 + camera.global_basis.x * 0.2
	thrown.linear_velocity = -camera.global_basis.z * lerpf(min_throw_speed, max_throw_speed, charge)
	thrown.look_at(thrown.global_position + thrown.linear_velocity, Vector3.UP)
	thrown.returned.connect(func() -> void: thrown_item = null)


## The node that takes damage for this collider: itself or the nearest parent that can.
func _damageable(node: Node) -> Node:
	while node and not node.has_method("take_damage"):
		node = node.get_parent()
	return node
