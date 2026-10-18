extends SubViewportContainer
## Shows the held item at the bottom right of the view (no hands). It is drawn in its own
## viewport on top of the game, so it never clips into walls. Two hold styles (ItemData):
## FLOAT - small items float in view, sway with mouse look, bob while walking, punch forward.
## POLEARM - spears are held low at real length, pointing at the crosshair, and stab straight
##   along the shaft (short wind-up, fast drive, brief hold, slower pull back).
## GUN - held pointing forward at the hip; right mouse brings it to the middle (scoped), it kicks
##   on a shot, and its spear slides back in while it reloads.
## All dip in from below when swapped and pull back while a throw is charged.

## Where a FLOAT item rests in front of the camera (m), and how it is turned (degrees).
@export var rest_position := Vector3(0.3, -0.24, -0.7)
@export var rest_rotation := Vector3(12, -32, -6)
@export_group("Motion")
## Sway per pixel of mouse motion, and the most it can lag behind (m).
@export var sway_amount := 0.0012
@export var max_sway := 0.06
## How fast the item springs back to rest.
@export var follow_speed := 10.0
@export var bob_amount := 0.012
@export var bob_speed := 10.0
## Walking speed (m/s) at which the bob is strongest.
@export var full_bob_speed := 4.0
## Seconds the swap dip takes.
@export var swap_time := 0.25
@export_group("Swing")
## FLOAT items: seconds one punch takes, and the pose at its peak (offset m, turn degrees).
@export var swing_time := 0.3
@export var swing_offset := Vector3(-0.14, 0.08, -0.4)
@export var swing_rotation := Vector3(8, 14, 0)
@export_group("Polearm")
## Where the hand grips the shaft, relative to the camera (m).
@export var grip_position := Vector3(0.34, -0.36, -0.22)
## The point the weapon aims at (m, camera space): just below and ahead of the crosshair.
@export var aim_point := Vector3(0.03, -0.1, -1.9)
## Seconds one stab takes.
@export var thrust_time := 0.45
## How far it pulls back before the stab, and how far the stab reaches (m, along the shaft).
@export var wind_up := 0.12
@export var thrust_reach := 0.55
## Walking: the tip dips this much (degrees) with each step.
@export var polearm_bob_pitch := 1.2
@export_group("Gun")
## Where a gun rests (hip) and where it goes when scoped (m, camera space).
@export var gun_rest_position := Vector3(0.2, -0.16, -0.72)
@export var gun_aim_position := Vector3(0.0, -0.1, -0.36)
## How much a gun turns and lags with mouse look (FLOAT items use 1).
@export var gun_sway := 0.3
## How far back the spear starts while reloading (model units, along the gun).
@export var reload_slide := 12.0
@export_group("Drink")
## Where the opening of a drink goes: the mouth, just below the view (m, camera space).
@export var mouth_position := Vector3(0.0, -0.16, -0.2)
## How a drink is tipped at its peak (degrees): past level, so the bottom rises up and away.
@export var drink_rotation := Vector3(125, 0, 6)
## Small gulp bobs while drinking.
@export var gulps := 3
@export_group("Charge")
## Pose at full throw charge (offset m, turn degrees): pulled back and raised.
@export var charge_offset := Vector3(0.05, 0.18, 0.3)
@export var charge_rotation := Vector3(-12, 0, -8)

## The world's sun, so the item is lit from the same direction as everything else.
var sun: DirectionalLight3D

var _item: ItemData
var _model_item: ItemData  # whose model is shown; differs from _item while a drink shows its cracked form
var _sway := Vector2.ZERO
var _bob_time := 0.0
var _walk := 0.0
var _dip := 0.0
var _swing := 1.0  # 0 -> 1 over one attack; 1 = resting
var _charge := 0.0
var _shown_charge := 0.0
var _drink := 1.0  # 0 -> 1 over one drink; 1 = not drinking
var _drink_time := 1.6
var _aim := 0.0
var _shown_aim := 0.0
var _loaded := 1.0
var _spear: Node3D  # a gun's loaded spear, if its model has one
var _spear_rest := Vector3.ZERO

@onready var _camera: Camera3D = $SubViewport/Camera3D
@onready var _holder: Node3D = $SubViewport/Camera3D/Holder
@onready var _light: DirectionalLight3D = $SubViewport/Light
@onready var _viewport: SubViewport = $SubViewport


func _ready() -> void:
	_update_rendering()


## Only render the extra view while there is something to show.
func _update_rendering() -> void:
	var showing := _item != null and _holder.visible
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	visible = showing


func show_item(item: ItemData) -> void:
	if item == _item:
		return
	if item != null and item == _model_item:
		_item = item  # already showing it (e.g. the cracked coconut after a drink): no swap dip
		_update_rendering()
		return
	_item = item
	_dip = 1.0
	_update_rendering()
	_set_model(item)


## Shows `item`'s model in the hand without changing the pose or playing the swap dip,
## e.g. the coconut cracking open as you start to drink it.
func show_model(item: ItemData) -> void:
	if item != _model_item:
		_set_model(item)


func _set_model(item: ItemData) -> void:
	_model_item = item
	for child in _holder.get_children():
		child.queue_free()
	_spear = null
	if item == null:
		return
	var model := item.make_model()
	_spear = model.find_child("Spear", true, false)
	if _spear:
		_spear_rest = _spear.position
	_holder.add_child(model)
	var bounds := ItemData.model_bounds(model)
	var s := item.held_size / maxf(bounds.get_longest_axis_size(), 0.01)
	model.scale = Vector3.ONE * s
	if item.hold_style == ItemData.HoldStyle.POLEARM:
		# Shaft (model +Y) along the holder's -Z, gripped `grip` of the way up from the butt.
		model.basis = Basis.from_euler(Vector3(-PI / 2, 0, 0)) * Basis.from_euler(item.held_rotation * PI / 180.0) * Basis.from_scale(Vector3.ONE * s)
		model.position = Vector3(0, 0, -(0.5 - item.grip) * item.held_size) - model.basis * bounds.get_center()
	else:
		model.rotation_degrees = item.held_rotation
		model.position = item.held_offset - model.basis * bounds.get_center()


## Plays one melee attack.
func swing() -> void:
	_swing = 0.0


## Plays the drink animation over `seconds`.
func drink(seconds: float) -> void:
	_drink_time = seconds
	_drink = 0.0


## Stops a drink early (e.g. the item was switched away).
func stop_drink() -> void:
	_drink = 1.0


## How far a throw is charged (0..1); the item pulls back to match.
func set_charge(charge: float) -> void:
	_charge = charge


## Gun state: scoped in or not, and how loaded it is (0 = spear out, 1 = ready).
func set_gun(aiming: bool, loaded: float) -> void:
	_aim = 1.0 if aiming else 0.0
	_loaded = loaded


## Where the held item's front end (a gun's muzzle) is, in camera space.
func muzzle() -> Vector3:
	return _holder.transform * Vector3(0.0, 0.0, -_item.held_size * 0.5) if _item else Vector3(0.15, -0.15, -0.5)


## Hides the item while it is away (thrown).
func set_hidden(hidden: bool) -> void:
	if _holder.visible == hidden:
		_holder.visible = not hidden
		_update_rendering()


## Mouse look in pixels; the item lags the other way.
func add_look(relative: Vector2) -> void:
	_sway = (_sway + relative * sway_amount).limit_length(max_sway)


## Horizontal walking speed (0 when airborne or swimming).
func set_walk_speed(speed: float) -> void:
	_walk = clampf(speed / full_bob_speed, 0.0, 1.0)


func _process(delta: float) -> void:
	# Same view direction and sun direction as the game, so lighting matches.
	var view := get_viewport().get_camera_3d()
	if view:
		_camera.basis = view.global_basis
	if sun:
		_light.basis = sun.global_basis
		_light.light_color = sun.light_color
		_light.light_energy = sun.light_energy

	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-follow_speed * delta))
	_bob_time += delta * bob_speed * _walk
	_dip = move_toward(_dip, 0.0, delta / swap_time)
	_shown_charge = move_toward(_shown_charge, _charge, delta * 8.0)
	_swing = minf(_swing + delta / (thrust_time if _polearm() else swing_time), 1.0)
	# A little shake at full charge, so it feels ready to let go.
	var tremble := Vector3(randf() - 0.5, randf() - 0.5, 0.0) * 0.004 * smoothstep(0.9, 1.0, _shown_charge)
	var dip := Vector3(0.0, -0.25, 0.05) * _dip * _dip
	var lag := Vector3(-_sway.x, _sway.y, 0.0)
	var charge := Transform3D(Basis.from_euler(charge_rotation * _shown_charge * PI / 180.0), charge_offset * _shown_charge + tremble)

	if _polearm():
		# The whole weapon moves; it barely turns, so the tip doesn't whip around.
		var step := sin(_bob_time)
		var bob := Vector3(0.0, -absf(cos(_bob_time)) * bob_amount * 0.8, step * bob_amount * 0.4) * _walk
		var aim := Basis.looking_at(aim_point - grip_position)
		var tilt := Basis.from_euler(Vector3((step * polearm_bob_pitch * _walk + _sway.y * 60.0) * PI / 180.0, -_sway.x, 0.0))
		var basis := aim * tilt
		_holder.transform = charge * Transform3D(basis, grip_position + lag * 0.5 + bob + dip + basis * Vector3(0, 0, -_thrust()))
	elif _item and _item.hold_style == ItemData.HoldStyle.GUN:
		_shown_aim = move_toward(_shown_aim, _aim, delta * 6.0)
		var aim := smoothstep(0.0, 1.0, _shown_aim)
		var free := (1.0 - aim * 0.8) * gun_sway  # heavy, and steadier still when scoped
		var bob := Vector3(sin(_bob_time) * 0.6, -absf(cos(_bob_time)), 0.0) * bob_amount * _walk
		var kick := (1.0 - _swing) * (1.0 - _swing)  # recoil right after a shot, easing back
		var turn := Vector3(_sway.y * 300.0 * free + 6.0 * kick, -_sway.x * 300.0 * free, 0.0)
		var pos := gun_rest_position.lerp(gun_aim_position, aim) + (lag + bob) * free + Vector3(0.0, 0.015, 0.08) * kick + dip
		_holder.transform = Transform3D(Basis.from_euler(turn * PI / 180.0), pos)
		if _spear:
			_spear.visible = _loaded > 0.0
			_spear.position = _spear_rest + Vector3(0.0, (1.0 - _loaded) * reload_slide, 0.0)  # slides in from behind
	else:
		var bob := Vector3(sin(_bob_time) * 0.6, -absf(cos(_bob_time)), 0.0) * bob_amount * _walk
		var hit := sin(PI * pow(_swing, 0.6))  # fast out, slower back
		# Drink: raise to the mouth and tip up, a few gulps, then lower again.
		_drink = minf(_drink + delta / _drink_time, 1.0)
		var up := smoothstep(0.0, 0.22, _drink) * (1.0 - smoothstep(0.82, 1.0, _drink))
		var gulp := sin(clampf((_drink - 0.22) / 0.6, 0.0, 1.0) * PI * gulps) * up
		var rest := Basis.from_euler((rest_rotation + Vector3(_sway.y, -_sway.x, -_sway.x) * 300.0 + swing_rotation * hit) * PI / 180.0)
		var tipped := Basis.from_euler((drink_rotation + Vector3(5.0 * absf(gulp), 0.0, 0.0)) * PI / 180.0)
		# Put the item's top (its opening) at the mouth.
		var drink_pos := mouth_position + (_item.drink_offset if _item else Vector3.ZERO) + Vector3(0.0, 0.008 * absf(gulp), 0.0) - tipped * Vector3(0.0, _item.held_size * 0.5 if _item else 0.0, 0.0)
		var basis := rest.slerp(tipped, up)
		var pos := (rest_position + lag + bob + swing_offset * hit).lerp(drink_pos, up) + dip
		_holder.transform = charge * Transform3D(basis, pos)


func _polearm() -> bool:
	return _item != null and _item.hold_style == ItemData.HoldStyle.POLEARM


## How far along the shaft a stab has pushed the weapon right now (m; negative = wind-up).
func _thrust() -> float:
	var t := _swing
	if t < 0.15:  # wind-up: draw back
		return -wind_up * smoothstep(0.0, 1.0, t / 0.15)
	if t < 0.35:  # drive: fast, easing out at full reach
		var k := (t - 0.15) / 0.2
		return lerpf(-wind_up, thrust_reach, 1.0 - pow(1.0 - k, 3.0))
	if t < 0.5:  # hold at full reach
		return thrust_reach
	return thrust_reach * (1.0 - smoothstep(0.0, 1.0, (t - 0.5) / 0.5))  # pull back
