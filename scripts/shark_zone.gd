@tool
class_name SharkZone
extends Node
## Keeps swimmers from crossing between islands. The shark zone is:
##  - all water deeper than `danger_depth` (the deep channels between the islands' shelves), and
##  - any Area3D you add as a child of this node (drag / resize it in the editor to add a zone).
## Swimming there for `spawn_delay` seconds brings a shark. It first circles you near the surface
## for `warning_time` (fin showing); stay and it attacks. Once it hunts, only
## swimming back toward the island you came from (or leaving the water) makes it give up.
## In the editor the depth zone is previewed in red (never shown in the game).

@export_tool_button("Refresh preview") var refresh_button := _build_preview

@export var player: Player
@export var ocean: Ocean
@export var terrain: Terrain
@export var shark_scene: PackedScene
## Water deeper than this (m below sea level) is shark water.
@export var danger_depth := 10.0:
	set(value):
		danger_depth = value
		if Engine.is_editor_hint() and is_inside_tree():
			_build_preview()
## Seconds in shark water before the shark comes.
@export var spawn_delay := 1.0
## Seconds it circles (the warning) before it attacks.
@export var warning_time := 5.0
## Where the shark appears: this far from the player, behind them (m).
@export var spawn_distance := 25.0
## Seconds you must be safe before the shark gives up (so a jump or a wave doesn't end it).
@export var give_up_delay := 0.75
@export_group("Editor preview")
@export var show_preview := true:
	set(value):
		show_preview = value
		if Engine.is_editor_hint() and is_inside_tree():
			_build_preview()
## Grid spacing of the preview (m).
@export var preview_spacing := 5.0

var _shark: Shark
var _danger_time := 0.0
var _safe_time := 0.0
var _home: IslandShape  # the island whose safe water the player was last in
var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_preview.call_deferred()  # after the Terrain has built its islands
		return
	for area in get_children():
		if area is Area3D:
			area.collision_mask |= 8  # detect the player (layer 4)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	var pos := player.global_position
	var hunting := _shark != null and not _shark.is_leaving()
	var deep := in_zone(pos)
	if not deep and not hunting:
		_home = nearest_island(pos)
	# While hunted, only water near home is safe: the other island's shelf doesn't save you.
	var safe := not deep and (not hunting or nearest_island(pos) == _home)
	var danger := player.exposed_to_sea and not safe
	_danger_time = _danger_time + delta if danger else 0.0
	_safe_time = 0.0 if danger else _safe_time + delta
	if danger:
		if _shark == null and _danger_time >= spawn_delay:
			_spawn()
		elif _shark:
			_shark.hunt()
	elif _shark and _safe_time >= give_up_delay:
		_shark.leave()


## Whether `pos` is in shark water: deep, or inside one of the Area3D zones.
func in_zone(pos: Vector3) -> bool:
	if ocean and terrain and ocean.sea_level - terrain.get_floor_height(pos.x, pos.z) > danger_depth:
		return true
	for area in get_children():
		if area is Area3D and area.overlaps_body(player):
			return true
	return false


func nearest_island(pos: Vector3) -> IslandShape:
	var best: IslandShape
	var best_d := INF
	for island: IslandShape in terrain.find_children("*", "IslandShape", false):
		var d := Vector2(pos.x - island.position.x, pos.z - island.position.z).length() - island.radius
		if d < best_d:
			best_d = d
			best = island
	return best


func _spawn() -> void:
	_shark = shark_scene.instantiate()
	_shark.target = player
	_shark.ocean = ocean
	_shark.terrain = terrain
	_shark.warning_time = warning_time
	add_child(_shark)
	# Out of sight: behind the player, deeper down.
	var camera := get_viewport().get_camera_3d()
	var back := camera.global_basis.z if camera else Vector3.BACK
	back.y = 0.0
	_shark.global_position = player.global_position + back.normalized() * spawn_distance + Vector3.DOWN * 2.5
	_shark.look_at(player.global_position, Vector3.UP)
	_shark.gone.connect(func() -> void: _shark = null)


## Red overlay at sea level over the deep (shark) water, editor only.
func _build_preview() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null
	if not Engine.is_editor_hint() or not show_preview or terrain == null or ocean == null:
		return
	var half := terrain.size * 0.5
	var n := int(terrain.size / preview_spacing)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := ocean.sea_level + 0.3
	for j in n:
		for i in n:
			var x := -half + (i + 0.5) * preview_spacing
			var z := -half + (j + 0.5) * preview_spacing
			if ocean.sea_level - terrain.get_floor_height(x, z) <= danger_depth:
				continue
			var h := preview_spacing * 0.5
			for v in [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(-h, 0, h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]:
				st.add_vertex(Vector3(x, y, z) + v)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.1, 0.1, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview = MeshInstance3D.new()
	_preview.mesh = st.commit()
	_preview.material_override = material
	add_child(_preview, false, INTERNAL_MODE_FRONT)
