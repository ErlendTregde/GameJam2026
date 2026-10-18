@tool
class_name SharkZone
extends Node
## Keeps swimmers from crossing between islands. The shark zone is:
##  - all water deeper than `danger_depth` (the deep channels between the islands' shelves), and
##  - any Area3D you add as a child of this node (drag / resize it in the editor to add a zone).
## Swimming there for `spawn_delay` seconds brings a shark. It first circles you near the surface
## for `warning_time` (fin showing), then attacks. Once it hunts it doesn't give up, even if you
## reach land (it waits at the shore); only killing you makes it leave. It keeps its damage, so
## the next fight picks up where the last one ended.
## In the editor the depth zone is previewed in red (never shown in the game).

@export_tool_button("Refresh preview") var refresh_button := _build_preview

@export var player: Player
@export var ocean: Ocean
@export var terrain: Terrain
@export var shark_scene: PackedScene
## Off: only the Area3D children are shark water (not all deep water).
@export var use_depth := true:
	set(value):
		use_depth = value
		if Engine.is_editor_hint() and is_inside_tree():
			_build_preview()
## > 0: the shark only comes once you dive this deep below the surface (m) in the zone.
@export var dive_depth := 0.0
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
## Boss health bar (HUD) shown while the shark hunts; its child Label shows the name.
@export var boss_bar: ProgressBar
## Shown when the shark dies.
@export var message: Label
@export var defeated_text := "The way is open!"
## Set when its shark is killed: the zone is safe for good.
@export var defeated := false
## Nodes with a `locked` property (e.g. the boat) unlocked when its shark is killed.
@export var unlocks: Array[Node] = []
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
var _bar_mine := false
var _boss_health := -1.0  # what the shark had left when it last swam off; -1 = never met
var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_preview.call_deferred()  # after the Terrain has built its islands
		return
	for area in get_children():
		if area is Area3D:
			area.collision_mask |= 8  # detect the player (layer 4)
	if player:
		player.died.connect(func() -> void:
			_danger_time = 0.0
			if _shark:
				_shark.leave())


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	var showing := _shark != null and not _shark.is_leaving() and not _shark.is_dead()
	if boss_bar and (showing or _bar_mine):  # several zones share one bar: only touch it for our shark
		_bar_mine = showing
		boss_bar.visible = showing
		if showing:
			boss_bar.max_value = _shark.max_health
			boss_bar.value = _shark.health
			(boss_bar.get_node("Name") as Label).text = _shark.display_name
	if defeated:
		return
	var dove := dive_depth <= 0.0 or (ocean and player.global_position.y < ocean.sea_level - dive_depth)
	var deep := player.exposed_to_sea and dove and in_zone(player.global_position)
	_danger_time = _danger_time + delta if deep else 0.0
	if _shark == null and _danger_time >= spawn_delay:
		_spawn()
	elif _shark and _shark.is_leaving() and deep:
		_shark.hunt()  # back in before it was gone


## Whether `pos` is in shark water: deep, or inside one of the Area3D zones.
func in_zone(pos: Vector3) -> bool:
	if use_depth and ocean and terrain and ocean.sea_level - terrain.get_floor_height(pos.x, pos.z) > danger_depth:
		return true
	for area in get_children():
		if area is Area3D and area.overlaps_body(player):
			return true
	return false


func _spawn() -> void:
	_shark = shark_scene.instantiate()
	_shark.target = player
	_shark.ocean = ocean
	_shark.terrain = terrain
	_shark.warning_time = warning_time
	add_child(_shark)
	if _boss_health > 0.0:
		_shark.health = _boss_health
	# Out of sight: behind the player, deeper down.
	var camera := get_viewport().get_camera_3d()
	var back := camera.global_basis.z if camera else Vector3.BACK
	back.y = 0.0
	_shark.global_position = player.global_position + back.normalized() * spawn_distance + Vector3.DOWN * 2.5
	_shark.look_at(player.global_position, Vector3.UP)
	_shark.gone.connect(func() -> void:
		_boss_health = _shark.health
		_shark = null)
	_shark.died.connect(_on_shark_died)


func _on_shark_died() -> void:
	defeated = true
	for node in unlocks:
		node.locked = false
	if message:
		message.text = defeated_text
		message.visible = true
		await get_tree().create_timer(4.0).timeout
		message.visible = false


## Red overlay at sea level over the deep (shark) water, editor only.
func _build_preview() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null
	if not Engine.is_editor_hint() or not show_preview or not use_depth or terrain == null or ocean == null:
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
