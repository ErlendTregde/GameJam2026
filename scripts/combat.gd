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

@export_group("Gun")
## Field of view while scoped (right mouse with a gun), as a share of the normal one.
@export var aim_fov_scale := 0.6

## The held item; only items with damage > 0 can attack. Switching cancels a charging throw.
var item: ItemData:
	set(value):
		item = value
		_hold = -1.0
		if held_view:
			held_view.set_charge(0.0)
## The item currently flying (it is back in the hand when this is null again).
var thrown_item: ItemData
## Scoped in with a gun (right mouse); the player zooms the camera.
var aiming := false

var _cooldown := 0.0
var _hold := -1.0  # seconds attack has been held for a throwable; -1 = not holding
var _loaded := 1.0  # gun: 1 = ready, 0 = spear out, in between = reloading
var _shot: Harpoon  # the gun's spear while it is out


func _process(delta: float) -> void:
	_cooldown -= delta
	var gun := item != null and item.fire_scene != null
	aiming = gun and Input.is_action_pressed("aim")
	if gun and thrown_item == null:
		_loaded = minf(_loaded + delta / item.reload_time, 1.0)
	held_view.set_gun(aiming, _loaded if gun else 1.0)
	if is_instance_valid(_shot):
		_shot.muzzle = held_view.muzzle()
	held_view.set_hidden(not gun and thrown_item != null and item == thrown_item)
	if _hold >= 0.0:
		_hold += delta
		held_view.set_charge(_charge())


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not event.is_action("attack"):
		return
	if item != null and item.fire_scene != null:
		if event.is_pressed():
			_fire()
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
			WorldService.hit(target, weapon.damage, cast.get_collision_point(i))


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


## A catch the host sent us (our spear killed it): it rides back on the spear if one is still
## out, otherwise straight into the hotbar.
func receive_catch(item: ItemData, weight: float) -> void:
	if is_instance_valid(_shot):
		_shot.carry(item, weight)
	else:
		get_parent().give(item, weight)


## Gun: fires the spear straight at the crosshair; it comes back on its line, then reloads.
func _fire() -> void:
	if item == null or item.fire_scene == null or thrown_item != null or _loaded < 1.0:
		return
	thrown_item = item
	_loaded = 0.0
	held_view.swing()  # recoil
	var camera := cast.get_parent() as Node3D
	var shot: Harpoon = item.fire_scene.instantiate()
	_shot = shot
	shot.muzzle = held_view.muzzle()
	shot.damage = item.damage
	shot.catcher = camera
	shot.player = get_parent()
	(get_tree().current_scene if get_tree().current_scene else get_tree().root).add_child(shot)
	shot.global_position = camera.global_position - camera.global_basis.z * 0.7
	shot.linear_velocity = -camera.global_basis.z * item.shot_speed
	shot.look_at(shot.global_position + shot.linear_velocity, Vector3.UP)
	shot.returned.connect(func() -> void: thrown_item = null)


## The node that takes damage for this collider: itself or the nearest parent that can.
func _damageable(node: Node) -> Node:
	while node and not node.has_method("take_damage"):
		node = node.get_parent()
	return node
