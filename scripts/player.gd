class_name Player
extends CharacterBody3D
## First-person walker and swimmer. Standing on a "platform" body (the boat deck) makes it
## a child of that body, so it rides along with every roll and pitch of the boat.

@export var speed := 4.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.002

@export_group("Swimming")
@export var ocean: Ocean
@export var swim_speed := 2.5
## Sinking speed when not holding jump.
@export var sink_speed := 0.8
@export var rise_speed := 2.0
## Swimming starts when the water reaches this high above the feet.
@export var chest_height := 0.9
## Pressing jump at the surface launches you this fast, e.g. to climb onto the boat.
@export var climb_velocity := 6.5
## Swapped in for the WorldEnvironment's environment while the camera is under water.
@export var world_environment: WorldEnvironment
@export var underwater_environment: Environment
## The world's sun, so the held item is lit the same way as the world.
@export var sun: DirectionalLight3D

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
var selected_slot := 0
var health := 0.0
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
@onready var _world := get_parent()
@onready var _surface_environment := world_environment.environment if world_environment else null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health = max_health
	_health_bar.max_value = max_health
	_health_bar.value = health
	stamina = max_stamina
	_stamina_bar.max_value = max_stamina
	_stamina_bar.value = stamina
	_held.sun = sun
	items.resize(_hotbar.get_child_count())
	for i in items.size():
		_hotbar.get_child(i).set_number(i + 1)
	_refresh_hotbar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("ui_cancel"):
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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

	var water_depth := ocean.get_height(global_position) - global_position.y if ocean else -INF
	var swimming := water_depth > chest_height
	if swimming:
		_swim(delta, water_depth)
	elif not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_basis * Vector3(input.x, 0.0, input.y)
	var move_speed := swim_speed if swimming else speed
	var sprinting := _update_stamina(delta, input != Vector2.ZERO, swimming)
	if sprinting:
		move_speed *= swim_sprint_multiplier if swimming else sprint_multiplier
	elif _item_use.is_using():
		move_speed *= drinking_speed_multiplier
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
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
		_refresh_hotbar()


func _swim(delta: float, water_depth: float) -> void:
	var target := -sink_speed
	if Input.is_action_pressed("jump"):
		if Input.is_action_just_pressed("jump") and water_depth < chest_height + 0.3:
			velocity.y = climb_velocity
			return
		# Rise, settling with the head just above the surface.
		target = clampf((water_depth - chest_height) * 4.0, -sink_speed, rise_speed)
	velocity.y = move_toward(velocity.y, target, 10.0 * delta)


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
	return hit if hit is WorldItem or (hit and hit.has_method("interact")) else null


func _select(slot: int) -> void:
	selected_slot = slot
	_refresh_hotbar()


func _pick_up(world_item: WorldItem) -> void:
	# The selected slot if it is free, otherwise the first free one.
	var slot := selected_slot if items[selected_slot] == null else items.find(null)
	if slot == -1:
		return
	items[slot] = world_item.item
	world_item.queue_free()
	_refresh_hotbar()


func _drop() -> void:
	var item := items[selected_slot]
	if item == null or item == _combat.thrown_item:  # can't drop what is still flying
		return
	items[selected_slot] = null
	var dropped: WorldItem = load(item.scene_path).instantiate()
	_world.add_child(dropped)
	dropped.global_position = _camera.global_position - _camera.global_basis.z * 0.8
	dropped.linear_velocity = velocity - _camera.global_basis.z * 2.5
	_refresh_hotbar()


func _refresh_hotbar() -> void:
	for i in items.size():
		var slot := _hotbar.get_child(i)
		slot.set_item(items[i])
		slot.set_selected(i == selected_slot)
	_held.show_item(items[selected_slot])
	_combat.item = items[selected_slot]
	_item_use.item = items[selected_slot]


func _update_prompt() -> void:
	var target := _target()
	if target == null:
		_prompt.text = ""
	elif not target is WorldItem:
		_prompt.text = target.get_prompt()
	elif items.has(null):
		_prompt.text = "E  pick up %s" % target.item.name
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
		_respawn()


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
	_combat.set_process_unhandled_input(value)
	_item_use.set_process_unhandled_input(value)
	velocity = Vector3.ZERO
	_hud.visible = value
	if value:
		_camera.make_current()
