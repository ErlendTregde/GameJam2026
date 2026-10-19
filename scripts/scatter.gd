@tool
class_name Scatter
extends Node3D
## Scatters copies of `meshes` around the Terrain's islands where the ground is between the given
## heights and flat enough (on the island, or out on the reef with `area`). Drawn as MultiMeshes
## per chunk, so thousands of copies stay cheap and far chunks are skipped. `scenes` places real
## nodes instead (e.g. starfish you can pick up).
## Click Rebuild in the inspector after changing values (or after rebuilding the Terrain).

@export_tool_button("Rebuild") var rebuild_button := build

@export var terrain: Terrain
## Picked at random per copy.
@export var meshes: Array[Mesh] = []
## Instead of (or as well as) meshes: scenes placed as real nodes, e.g. pick-up items.
@export var scenes: Array[PackedScene] = []
## Tries per island; copies landing outside the height/slope limits are skipped.
@export var count := 50
@export var random_seed := 1
## Off for small things like grass: their shadows are barely visible but cost a lot.
@export var cast_shadows := true
## Not drawn beyond this distance (m); 0 = always.
@export var visible_distance := 0.0
## Copies are batched in squares of this size (m), so far squares can be skipped; 0 = per island.
@export var chunk_size := 0.0
@export_group("Placement")
## Where around each island, in island radii from its center: (0, 1) = on the island,
## (1.1, 3) = a ring out on the reef.
@export var area := Vector2(0.0, 1.0)
## Only on ground between these world heights (m).
@export var min_height := 1.0
@export var max_height := 50.0
## 1 = flat ground only, 0 = anywhere.
@export_range(0.0, 1.0) var min_flatness := 0.7
@export var scale_range := Vector2(0.8, 1.2)
## Pushed this far into the ground so nothing floats on slopes.
@export var sink := 0.1
## Tilt with the ground (grass, stones) instead of standing straight up (trees).
@export var follow_ground := false
@export_group("Collision")
## 0 = no collision. Otherwise a cylinder of this radius per copy (times its scale).
@export var collision_radius := 0.0
@export var collision_height := 2.0
@export_group("Harvest")
## When set (and collision is on), hitting a copy with a weapon can drop these, e.g. coconuts
## falling out of a palm.
@export var harvest_loot: LootTable
## Chance per hit that something falls.
@export_range(0.0, 1.0) var harvest_chance := 0.35
## How many times each copy can drop.
@export var drops_per_copy := 3
## Where drops fall from, above the base at scale 1 (m), e.g. a palm's crown.
@export var drop_height := 4.5


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children(true):
		if child.owner == null:  # only what a previous build made
			child.queue_free()
	var kinds := meshes.size() + scenes.size()
	if terrain == null or kinds == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var body: StaticBody3D
	if collision_radius > 0.0:
		body = Harvestable.new() if harvest_loot else StaticBody3D.new()
		if body is Harvestable:
			body.collision_layer = 1 | 32  # world + creatures: weapons can hit it
			body.loot = harvest_loot
			body.drop_chance = harvest_chance
			body.drops_per_tree = drops_per_copy
			body.crown_height = drop_height
		body.name = "Bodies"  # a fixed name: multiplayer hits find it by path on every peer
		add_child(body, false, INTERNAL_MODE_FRONT)
	var placed_count := 0
	for island in terrain.find_children("*", "IslandShape", false):
		var placed: Array[Array] = []  # one list of transforms per mesh / scene, on this island
		placed.resize(kinds)
		for i in placed.size():
			placed[i] = []
		for k in count:
			var r: float = island.radius * sqrt(lerpf(area.x * area.x, area.y * area.y, rng.randf()))
			var a := rng.randf() * TAU
			var x: float = island.position.x + cos(a) * r
			var z: float = island.position.z + sin(a) * r
			var y := terrain.get_floor_height(x, z)
			var normal := Vector3(terrain.get_floor_height(x - 0.5, z) - terrain.get_floor_height(x + 0.5, z), 1.0,
					terrain.get_floor_height(x, z - 0.5) - terrain.get_floor_height(x, z + 0.5)).normalized()
			if y < min_height or y > max_height or normal.y < min_flatness:
				continue
			var s := rng.randf_range(scale_range.x, scale_range.y)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
			if follow_ground:
				basis = Basis(Quaternion(Vector3.UP, normal)) * basis
			placed[rng.randi() % kinds].append(Transform3D(basis, Vector3(x, y - sink * s, z)))
		for i in scenes.size():
			for t: Transform3D in placed[meshes.size() + i]:
				var node: Node3D = scenes[i].instantiate()
				if node is RigidBody3D:
					node.freeze = true  # lies where it was placed until picked up
				# Fixed names (same seed, same order on every peer): items are identified by path.
				node.name = "Placed%d" % placed_count
				placed_count += 1
				add_child(node, false, INTERNAL_MODE_FRONT)
				node.global_transform = t
		for m in meshes.size():
			for chunk in _chunks(placed[m], island.position):
				_add_batch(meshes[m], chunk[0], chunk[1], body)


## Splits transforms into [center, transforms] batches by chunk (or one batch at `fallback`).
func _chunks(transforms: Array, fallback: Vector3) -> Array:
	if chunk_size <= 0.0:
		return [[fallback, transforms]]
	var groups := {}
	for t: Transform3D in transforms:
		var key := Vector2i(floori(t.origin.x / chunk_size), floori(t.origin.z / chunk_size))
		if key not in groups:
			groups[key] = []
		groups[key].append(t)
	var out := []
	for key: Vector2i in groups:
		out.append([Vector3((key.x + 0.5) * chunk_size, 0.0, (key.y + 0.5) * chunk_size), groups[key]])
	return out


## One MultiMesh of `mesh` at `center`, so the batch is skipped as a whole when far away.
func _add_batch(mesh: Mesh, center: Vector3, transforms: Array, body: StaticBody3D) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		multimesh.set_instance_transform(i, t.translated(-center))
		if body is Harvestable:
			body.add_tree(t.origin, multimesh, i, t.translated(-center))
		if body:
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = collision_radius * t.basis.get_scale().x
			cylinder.height = collision_height * t.basis.get_scale().x
			shape.shape = cylinder
			shape.position = t.origin + Vector3.UP * cylinder.height * 0.5
			body.add_child(shape)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.position = center
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = visible_distance
	add_child(instance, false, INTERNAL_MODE_FRONT)
