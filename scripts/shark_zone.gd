class_name SharkZone
extends Node
## A boss's waters: its shark is always out there swimming the `patrol` path (a Path3D you draw
## in the editor). A swimmer who comes within `aggro_radius` gets hunted: it circles them first
## (fin showing), then attacks, even following them onto land. Once they are `give_up_distance`
## away it gives up and swims back to its patrol. It keeps its damage, so the next fight picks up
## where the last one ended. Killing it is optional: it drops its trophy and stays dead.

@export var player: Player
@export var ocean: Ocean
@export var terrain: Terrain
@export var shark_scene: PackedScene
## The loop the shark swims (keep it in deep water, under the surface).
@export var patrol: Path3D
## A swimmer this close to the shark gets hunted (m).
@export var aggro_radius := 18.0
## It gives up once its target is this far away (m).
@export var give_up_distance := 45.0
## Seconds it circles (the warning) before it attacks.
@export var warning_time := 5.0
## Boss health bar (HUD) shown while the shark hunts; its child Label shows the name.
@export var boss_bar: ProgressBar
## Shown when the shark dies.
@export var message: Label
@export var defeated_text := "Boss beaten!"
## Set when its shark is killed: it is gone for good.
@export var defeated := false

var _shark: Shark
var _bar_mine := false


func _ready() -> void:
	WorldService.player_died.connect(_on_player_died)


func _physics_process(_delta: float) -> void:
	if not CreatureService.simulates():
		_update_bar(_puppet())  # the host simulates it; we only show its boss bar
		return
	_update_bar(_shark)
	if defeated:
		return
	if _shark == null:
		_spawn()
		return
	if _shark.is_dead():
		return
	if _shark.is_leaving():
		var near := _nearest_swimmer(aggro_radius)
		if near:
			_shark.target = near
			_shark.hunt()
	elif not is_instance_valid(_shark.target) or _shark.target.global_position.distance_to(_shark.global_position) > give_up_distance:
		_shark.leave()


## The nearest player in the sea within [param radius] of the shark, except [param skip].
func _nearest_swimmer(radius: float, skip: Node3D = null) -> Node3D:
	var bodies := WorldService.player_bodies()
	if bodies.is_empty() and player:
		bodies = [player]
	var best: Node3D = null
	var best_d := radius
	for body in bodies:
		if body == null or body == skip or not body.exposed_to_sea:
			continue
		var d := body.global_position.distance_to(_shark.global_position)
		if d < best_d:
			best = body
			best_d = d
	return best


## A player died: the shark that killed them goes after the next player nearby, or back to patrol.
func _on_player_died(body: Node3D) -> void:
	if not CreatureService.simulates() or _shark == null or _shark.target != body:
		return
	var next := _nearest_swimmer(give_up_distance, body)
	if next:
		_shark.target = next
		_shark.hunt()
	else:
		_shark.leave()


## The shark (host), for tests and tools.
func spawned_shark() -> Shark:
	return _shark


## A client's copy of this zone's shark (its puppet child), for the boss bar.
func _puppet() -> Shark:
	for child in get_children():
		if child is Shark:
			return child
	return null


func _update_bar(shark: Shark) -> void:
	var showing := shark != null and not shark.is_leaving() and not shark.is_dead()
	if boss_bar and (showing or _bar_mine):  # several zones share one bar: only touch it for our shark
		_bar_mine = showing
		boss_bar.visible = showing
		if showing:
			boss_bar.max_value = shark.max_health
			boss_bar.value = shark.health
			(boss_bar.get_node("Name") as Label).text = shark.display_name


func _spawn() -> void:
	_shark = shark_scene.instantiate()
	_shark.patrol = patrol
	_shark.ocean = ocean
	_shark.terrain = terrain
	_shark.warning_time = warning_time
	add_child(_shark)
	_shark.global_position = patrol.to_global(patrol.curve.sample_baked(0.0))
	_shark.leave()
	_shark.gone.connect(func() -> void: _shark = null)
	_shark.died.connect(_on_shark_died)


func _on_shark_died() -> void:
	defeat()
	WorldEvents.zone_defeated(self)


## The boss is dead (here, and on every peer when the host says so).
func defeat() -> void:
	if defeated:
		return
	defeated = true
	if message:
		message.text = defeated_text
		message.visible = true
		await get_tree().create_timer(4.0).timeout
		message.visible = false
