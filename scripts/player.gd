class_name Player
extends CharacterBody3D

## Health ran out (just before respawning).
signal died
## First-person walker and swimmer. Standing on a "platform" body (the boat deck) makes it
## a child of that body, so it rides along with every roll and pitch of the boat.

@export var speed := 4.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.002

@export_group("Swimming")
@export var ocean: Ocean
@export var swim_speed := 2.5
## How quickly swimming reaches its speed and glides to a stop (m/s per s): water has momentum.
@export var swim_acceleration := 5.0
## Sinking speed when not holding jump.
@export var sink_speed := 0.8
@export var rise_speed := 2.0
## Swimming down while holding dive (Ctrl), m/s: about as fast as rising.
@export var dive_speed := 2.0
## How hard the water stops vertical motion, e.g. a fall or jump back in (m/s per s).
@export var water_brake := 14.0
## Swimming starts when the water reaches this high above the feet...
@export var chest_height := 0.9
## ...and ends again only this much lower, so bobbing on waves doesn't flip in and out of swimming.
@export var swim_exit_margin := 0.35
## Within this much below floating depth you float on the waves; deeper you sink slowly (m).
@export var surface_band := 4.0
## How fast you drift back up to the surface when floating (m/s): gentle, like real buoyancy.
@export var float_up_speed := 1.0
## Pressing jump while floating gives a small hop this fast (you can't jump far out of water).
@export var climb_velocity := 3.5
## ...unless an edge (the boat deck, land) is right in front of you and at most this high above
## the water: then you pull yourself up onto it.
@export var climb_reach := 2.4
## Seconds the pull-up takes.
@export var climb_time := 0.5
## Seconds before you can push out of the water again.
@export var climb_cooldown := 0.8
## Swapped in for the WorldEnvironment's environment while the camera is under water.
@export var world_environment: WorldEnvironment
@export var underwater_environment: Environment
@export_subgroup("Swim camera")
## Slow up-down bob per swim stroke while moving (m), and strokes per second.
@export var stroke_bob := 0.045
@export var stroke_rate := 0.75
## Gentle roll while floating at the surface (degrees).
@export var float_roll := 1.6
## Field of view under water (water magnifies, so slightly narrower).
@export var underwater_fov := 72.0
## The world's sun, so the held item is lit the same way as the world.
@export var sun: DirectionalLight3D

## In the hotbar from the start (e.g. for testing).
@export var starting_items: Array[ItemData] = []
@export_group("Health")
@export var max_health := 100.0
## Seconds you can stay under water before you start drowning.
@export var breath_time := 15.0
## Health lost per drowning pulse once out of oxygen.
@export var drown_damage := 10.0
## Seconds between drowning pulses.
@export var drown_interval := 1.0
## Where you come back after losing all health (a marker on the boat).
@export var respawn_point: Node3D
## Slow health regeneration (per second), only while stamina is full and you're out of water.
@export var health_regen := 0.5

@export_group("Stamina")
## Sprinting (shift) on land and fast swimming (shift in water) share this.
@export var max_stamina := 100.0
@export var sprint_multiplier := 1.7
@export var sprint_drain := 18.0
@export var swim_sprint_multiplier := 1.6
@export var swim_sprint_drain := 22.0
## Recovered per second, after not sprinting for `regen_delay` seconds.
@export var stamina_regen := 3.0
@export var regen_delay := 2.0
## After running completely out, sprinting is locked until stamina is back above this share.
@export_range(0.0, 1.0) var exhausted_until := 0.25
## Walking speed while drinking.
@export var drinking_speed_multiplier := 0.5

## One entry per hotbar slot (null = empty). Add a Slot under HUD/Hotbar for more room.
var items: Array[ItemData] = []
## Weight (kg) of the item in each slot; 0 = no size.
var weights: Array[float] = []
var money := 0
## Gear being worn (goggles, flippers): kept for good, also through death.
var worn: Array[ItemData] = []
var selected_slot := 0
var health := 0.0
## True while swimming (not walking on land or a deck); read by the SharkZone.
var in_water := false
## Swimming, or just above the water with nothing solid underfoot (jumping in, climbing out).
## Read by the SharkZone: only standing on the boat or land is out of the sea.
var exposed_to_sea := false
var _swim_time := 0.0
var _climb_timer := 0.0
var _vault_time := -1.0  # >= 0 while pulling up onto an edge
var _vault_from := Vector3.ZERO
var _vault_on: Node3D  # what we climb onto; the target follows it (the boat bobs)
var _vault_to_local := Vector3.ZERO
var _vault_over := 0.0  # height the pull-up arcs over
var _swim_sway := 0.0  # 0..1, how much of the swim camera motion is applied
var _base_fov := 80.0
var stamina := 0.0
var exhausted := false
var _since_sprint := 0.0
var oxygen := 1.0  # 0..1
var _underwater := false
var _drown_timer := 0.0

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _health_bar: ProgressBar = $HUD/Status/HealthBar
@onready var _oxygen_row: Control = $HUD/Status/OxygenRow
@onready var _oxygen_bar: ProgressBar = $HUD/Status/OxygenRow/OxygenBar
@onready var _animations: AnimationPlayer = $AnimationPlayer
@onready var _ray: ShapeCast3D = $Head/Camera3D/InteractRay  # a fat ray: small items are easy to aim at
@onready var _prompt: Label = $HUD/Prompt
@onready var _hotbar: HBoxContainer = $HUD/Hotbar
@onready var _held: SubViewportContainer = $HUD/HeldView
@onready var _combat: Combat = $Combat
@onready var _item_use: ItemUse = $ItemUse
@onready var _stamina_bar: ProgressBar = $HUD/Status/StaminaBar
@onready var _money_label: Label = $HUD/Status/Money
@onready var _gear_label: Label = $HUD/Status/Gear
@onready var _world := get_parent()
@onready var _surface_environment := world_environment.environment if world_environment else null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_base_fov = _camera.fov
	health = max_health
	_health_bar.max_value = max_health
	_health_bar.value = health
	stamina = max_stamina
	_stamina_bar.max_value = max_stamina
	_stamina_bar.value = stamina
	_held.sun = sun
	items.resize(_hotbar.get_child_count())
	weights.resize(items.size())
	for item in starting_items:
		give(item)
	for i in items.size():
		_hotbar.get_child(i).set_number(i + 1)
	_refresh_hotbar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not PauseMenu.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif is_physics_processing() and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_head.rotation.x = clampf(_head.rotation.x - event.relative.y * mouse_sensitivity, -1.5, 1.5)
		_held.add_look(event.relative)
	elif is_physics_processing():
		_inventory_input(event)


func _inventory_input(event: InputEvent) -> void:
	var target := _target()
	if event.is_action_pressed("interact") and target:
		if target is WorldItem:
			_pick_up(target)
		else:
			target.interact(self)
		get_viewport().set_input_as_handled()  # so the same E doesn't also take the helm
	elif event.is_action_pressed("drop"):
		_drop()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		_select(posmod(selected_slot + step, items.size()))
	else:
		for i in items.size():
			if event.is_action_pressed("slot_%d" % (i + 1)):
				_select(i)


func _physics_process(delta: float) -> void:
	# The parent (boat) may have tilted us: stay upright, keep facing the same way.
	var forward := -global_basis.z
	forward.y = 0.0
	global_basis = Basis.looking_at(forward.normalized())
	if _vault_time >= 0.0:
		_update_vault(delta)
		return

	var water_depth := ocean.get_height(global_position) - global_position.y if ocean else -INF
	var swimming := water_depth > (chest_height - swim_exit_margin if in_water else chest_height)
	in_water = swimming
	exposed_to_sea = swimming or (not is_on_floor() and water_depth > -2.5)
	if not swimming and not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_speed := swim_speed if swimming else speed
	var sprinting := _update_stamina(delta, input != Vector2.ZERO, swimming)
	if sprinting:
		move_speed *= swim_sprint_multiplier if swimming else sprint_multiplier
	elif _item_use.is_using():
		move_speed *= drinking_speed_multiplier
	if swimming:
		_swim(delta, water_depth, input, move_speed)
	else:
		var direction := global_basis * Vector3(input.x, 0.0, input.y)
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	_update_swim_camera(delta, swimming, input != Vector2.ZERO, water_depth)
	# Swimming: slide along underwater slopes in any direction instead of treating them as walls.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING if swimming else CharacterBody3D.MOTION_MODE_GROUNDED
	move_and_slide()
	_held.set_walk_speed(Vector2(velocity.x, velocity.z).length() if is_on_floor() else 0.0)

	var ground := _floor_body()
	if ground:
		var carrier: Node = ground if ground.is_in_group("platform") else _world
		if carrier != get_parent():
			reparent(carrier)

	_update_underwater()
	_update_breath(delta)
	_update_prompt()


## Spends stamina while sprinting and recovers it otherwise. Returns whether we sprint now.
func _update_stamina(delta: float, moving: bool, swimming: bool) -> bool:
	var wants := Input.is_action_pressed("sprint") and moving and not _item_use.is_using()
	var sprinting := wants and not exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(stamina - (swim_sprint_drain if swimming else sprint_drain) * delta, 0.0)
		_since_sprint = 0.0
		if stamina == 0.0:
			exhausted = true
	else:
		_since_sprint += delta
		if _since_sprint >= regen_delay:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
	if exhausted and stamina >= max_stamina * exhausted_until:
		exhausted = false
	if stamina >= max_stamina and not _underwater and health < max_health and health > 0.0:
		health = minf(health + health_regen * delta, max_health)
		_health_bar.value = health
	_stamina_bar.value = stamina
	# Dimmed while exhausted, so it's clear why you can't sprint.
	_stamina_bar.modulate = Color(1, 1, 1, 0.45) if exhausted else Color.WHITE
	return sprinting


## Whether consuming `item` would do anything (no drinking at full health and stamina).
func needs(item: ItemData) -> bool:
	return (item.heal > 0.0 and health < max_health) or (item.restore_stamina > 0.0 and stamina < max_stamina)


## Eats or drinks an item (called by ItemUse when the animation ends).
func consume(item: ItemData) -> void:
	health = minf(health + item.heal, max_health)
	stamina = minf(stamina + item.restore_stamina, max_stamina)
	_health_bar.value = health
	_stamina_bar.value = stamina
	var slot := items.find(item)
	if slot != -1:
		items[slot] = item.becomes
		weights[slot] = 0.0
		_refresh_hotbar()


## Swimming: move where you look (look down + forward to dive), with momentum. At the surface
## you float on the waves; below it you sink slowly unless you swim or hold jump to rise.
func _swim(delta: float, water_depth: float, input: Vector2, move_speed: float) -> void:
	var at_surface := water_depth < chest_height + surface_band
	_climb_timer -= delta
	# Push out of the water (e.g. onto the boat) only when floating at the surface, not mid-plunge.
	if Input.is_action_just_pressed("jump") and _climb_timer <= 0.0 and water_depth < chest_height + 0.8:
		if _start_vault():
			_climb_timer = climb_cooldown
			return
		if water_depth < chest_height + 0.35:  # nothing to climb onto: just a small hop
			_climb_timer = climb_cooldown
			velocity.y = climb_velocity
			return
	var want := _camera.global_basis * Vector3(input.x, 0.0, input.y) * move_speed
	var float_y := clampf((water_depth - chest_height) * 4.0, -rise_speed, float_up_speed)  # head above the surface
	if Input.is_action_pressed("dive"):
		want.y = -dive_speed
	elif Input.is_action_pressed("jump"):
		want.y = minf((water_depth - chest_height) * 4.0, rise_speed)  # swim up, settle at the surface
	elif at_surface and want.y > -0.6:
		want.y = float_y  # floating: ride the waves unless clearly diving
	elif at_surface:
		want.y = minf(want.y, float_y)
	else:
		want.y -= sink_speed * (1.0 - absf(input.y))  # drifting down slowly when not swimming
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2(want.x, want.z), swim_acceleration * delta)
	var pushing_off := _climb_timer > climb_cooldown - 0.35 and velocity.y > 0.0  # just jumped: let it carry
	var vy := velocity.y if pushing_off else move_toward(velocity.y, want.y, water_brake * delta)
	velocity = Vector3(flat.x, vy, flat.y)


## Looks for an edge right in front (deck or land, low enough to reach) and starts pulling up.
func _start_vault() -> bool:
	var water := ocean.get_height(global_position)
	for reach_ahead: float in [0.75, 1.1]:  # a little farther too, past a curved hull
		var ahead := global_position - global_basis.z * reach_ahead
		var top := water + climb_reach + 0.4
		var hit := {}
		var land := {}  # lowest place to stand found under the starting point (the floor inside the hull)
		var over := -INF  # highest thing passed on the way down (the side's rim): climb over it
		for i in 6:  # look down past the sail and the rounded rim
			# Down to below the water line: the floor inside the hull sits a little under it.
			var query := PhysicsRayQueryParameters3D.create(Vector3(ahead.x, top, ahead.z), Vector3(ahead.x, water - 0.8, ahead.z), 1 | 4)
			hit = get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				break
			if hit.position.y - water <= climb_reach:
				over = maxf(over, hit.position.y)
				if hit.normal.y >= 0.7:
					land = hit
			top = hit.position.y - 0.05
		if land.is_empty():
			continue
		hit = land
		_vault_over = maxf(over, hit.position.y) + 0.35
		_vault_on = hit.collider
		_vault_to_local = _vault_on.to_local(hit.position + Vector3.UP * 0.05)
		_vault_from = global_position
		_vault_time = 0.0
		velocity = Vector3.ZERO
		return true
	return false


## Pull-up: up first, then forward over the edge, landing on it.
func _update_vault(delta: float) -> void:
	_vault_time += delta
	var t := minf(_vault_time / climb_time, 1.0)
	var to := _vault_on.to_global(_vault_to_local) if is_instance_valid(_vault_on) else _vault_from
	var over := Vector3(_vault_from.x, maxf(_vault_over, to.y + 0.35), _vault_from.z)
	var a := _vault_from.lerp(over, t)
	var b := over.lerp(to, t)
	global_position = a.lerp(b, smoothstep(0.0, 1.0, t))
	if t >= 1.0:
		_vault_time = -1.0
		velocity = Vector3.ZERO
		in_water = false
		if _vault_on and _vault_on.is_in_group("platform") and get_parent() != _vault_on:
			reparent(_vault_on)


## Swim camera: slow stroke bob while moving, gentle roll while floating, narrower FOV below.
func _update_swim_camera(delta: float, swimming: bool, moving: bool, water_depth: float) -> void:
	_swim_sway = move_toward(_swim_sway, 1.0 if swimming else 0.0, delta * 2.0)
	_swim_time += delta
	var stroke := sin(_swim_time * TAU * stroke_rate) * stroke_bob * (1.0 if moving else 0.25)
	var floating := clampf(1.0 - absf(water_depth - chest_height), 0.0, 1.0)  # near the surface
	_camera.position.y = stroke * _swim_sway
	_camera.rotation.z = deg_to_rad(sin(_swim_time * 0.9) * float_roll * floating) * _swim_sway
	var fov := (underwater_fov if _underwater else _base_fov) * (_combat.aim_fov_scale if _combat.aiming else 1.0)
	var fast := _combat.aiming or _camera.fov < fov - 15.0  # scoping snaps; the underwater change eases
	_camera.fov = move_toward(_camera.fov, fov, delta * (160.0 if fast else 20.0))


func _update_underwater() -> void:
	var under := ocean != null and _camera.global_position.y < ocean.get_height(_camera.global_position)
	if under == _underwater:
		return
	_underwater = under
	_oxygen_row.visible = under
	if world_environment and underwater_environment:
		world_environment.environment = underwater_environment if under else _surface_environment


## The item, or anything with interact(player) like a chest, under the crosshair.
func _target() -> Node:
	var hit := _ray.get_collider(0) if _ray.is_colliding() else null
	if hit is WorldItem:
		for table: SellScale in get_tree().get_nodes_in_group("sell_scale"):
			if table.holds(hit):
				return table  # catch on the scale: E sells it instead of picking it back up
	return hit if hit is WorldItem or (hit and hit.has_method("interact")) else null


func _select(slot: int) -> void:
	selected_slot = slot
	_refresh_hotbar()


func _pick_up(world_item: WorldItem) -> void:
	if items.has(null):
		ItemService.request_pickup(world_item)  # the host decides who gets it; then give()


## Puts an item in the selected slot if free, else the first free one, else drops it at your feet.
func give(item: ItemData, weight := 0.0) -> void:
	var slot := selected_slot if items[selected_slot] == null else items.find(null)
	if slot == -1:
		_spawn_item(item, weight, global_position + Vector3.UP * 0.5, Vector3.ZERO)
		return
	items[slot] = item
	weights[slot] = weight
	_refresh_hotbar()


func _drop() -> void:
	var item := items[selected_slot]
	if item == null or item == _combat.thrown_item:  # can't drop what is still flying
		return
	var weight := weights[selected_slot]
	items[selected_slot] = null
	weights[selected_slot] = 0.0
	var from := _camera.global_position - _camera.global_basis.z * 0.8
	_spawn_item(item, weight, from, _toss_velocity(from))
	_refresh_hotbar()


## A lob that lands where the crosshair points (up to 4 m away), so you can aim drops onto the scale.
func _toss_velocity(from: Vector3) -> Vector3:
	var aim_from := _camera.global_position
	var aim_to := aim_from - _camera.global_basis.z * 4.0
	var query := PhysicsRayQueryParameters3D.create(aim_from, aim_to, 1 | 4 | 16, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.position if hit else aim_to
	var t := 0.45  # flight time
	return (target - from) / t - get_gravity() * t * 0.5


func _spawn_item(item: ItemData, weight: float, at: Vector3, toss: Vector3) -> void:
	ItemService.spawn(item, weight, at, toss)


## Head tilt (radians), for our avatar.
func look_pitch() -> float:
	return _head.rotation.x


func held_item() -> ItemData:
	return items[selected_slot] if not items.is_empty() else null


func add_money(amount: int) -> void:
	money += amount
	_money_label.text = "$ %d" % money


func spend(amount: int) -> bool:
	if amount > money:
		return false
	add_money(-amount)
	return true


func wears(item: ItemData) -> bool:
	return worn.has(item)


## Puts on gear: its effects apply right away.
func wear(item: ItemData) -> void:
	if worn.is_empty() and underwater_environment:
		underwater_environment = underwater_environment.duplicate()  # our own fog, not every player's
	worn.append(item)
	breath_time += item.extra_breath
	swim_speed *= item.swim_multiplier
	dive_speed *= item.swim_multiplier
	rise_speed *= item.swim_multiplier
	if underwater_environment:
		underwater_environment.fog_density *= item.underwater_fog_multiplier
	_gear_label.text = "  ".join(worn.map(func(g: ItemData) -> String: return g.name))


func _refresh_hotbar() -> void:
	for i in items.size():
		var slot := _hotbar.get_child(i)
		slot.set_item(items[i], weights[i])
		slot.set_selected(i == selected_slot)
	_held.show_item(items[selected_slot], weights[selected_slot])
	_combat.item = items[selected_slot]
	_item_use.item = items[selected_slot]


func _update_prompt() -> void:
	var target := _target()
	if target == null:
		_prompt.text = ""
	elif not target is WorldItem:
		_prompt.text = target.get_prompt()
	elif items.has(null):
		_prompt.text = "[E] pick up %s" % target.item.name
	else:
		_prompt.text = "Inventory full"


func _update_breath(delta: float) -> void:
	if _underwater:
		oxygen = maxf(oxygen - delta / breath_time, 0.0)
		if oxygen == 0.0:
			_drown_timer -= delta
			if _drown_timer <= 0.0:
				_drown_timer = drown_interval
				take_damage(drown_damage)
	else:
		_drown_timer = 0.0
		oxygen = minf(oxygen + delta / breath_time * 4.0, 1.0)  # catch your breath faster than you lose it
	_oxygen_bar.value = oxygen * _oxygen_bar.max_value


func take_damage(amount: float, _at := Vector3.ZERO) -> void:
	health = maxf(health - amount, 0.0)
	_health_bar.value = health
	_animations.stop()
	_animations.play("hurt")  # red vignette, camera shake, health bar flash
	if health == 0.0:
		died.emit()
		_drop_everything()
		_respawn()


## Dying: the hotbar spills out where you died, to dive back for.
func _drop_everything() -> void:
	for i in items.size():
		if items[i]:
			_spawn_item(items[i], weights[i], global_position + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5)), Vector3.ZERO)
			items[i] = null
			weights[i] = 0.0
	_refresh_hotbar()


func _respawn() -> void:
	health = max_health
	stamina = max_stamina
	exhausted = false
	oxygen = 1.0
	_health_bar.value = health
	velocity = Vector3.ZERO
	if respawn_point:
		global_position = respawn_point.global_position


func _floor_body() -> Node:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().dot(up_direction) > 0.7:
			return collision.get_collider()
	return null


## Turns walking and looking on/off (off while steering the boat).
func set_controlled(value: bool) -> void:
	set_physics_process(value)
	in_water = false
	exposed_to_sea = false
	_combat.set_process_unhandled_input(value)
	_item_use.set_process_unhandled_input(value)
	velocity = Vector3.ZERO
	_hud.visible = value
	if value:
		_camera.make_current()
