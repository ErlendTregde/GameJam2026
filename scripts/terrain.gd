@tool
class_name Terrain
extends StaticBody3D
## The ground: sea floor everywhere, rising above the water as an island at every IslandShape
## child. Off the coast the height follows `profile` (height over distance from the nearest
## shoreline), roughened by `noise` into sandbars and holes. Builds its mesh and collision on
## load (click Rebuild in the inspector to preview changes).

@export_tool_button("Rebuild") var rebuild_button := build

@export var size := 1000.0
## Meters between grid points.
@export var spacing := 2.5
@export var noise: FastNoiseLite
@export var material: Material
## Off saves a lot of GPU time: the ground is big and its own shadows add little.
@export var cast_shadows := false
## The ground is drawn as square chunks of this many cells, so off-screen chunks are skipped.
@export var chunk_cells := 40
## Chunks farther than this are not drawn (m); 0 = always. Fog and water hide them anyway.
@export var visible_distance := 300.0

@export_group("Profile")
## Height (m) by distance (m) from the nearest shoreline.
@export var profile: Curve
## Noise height (+/- m) on the shallow shelf and in deep water (none right at the shore).
@export var shallow_variation := 2.5
@export var deep_variation := 10.0
@export var deep_from := 85.0

var _islands: Array[IslandShape] = []
var _chunks: Array[MeshInstance3D] = []
var _shape := CollisionShape3D.new()


func _ready() -> void:
	# Internal children: generated every load, never saved into the scene file.
	add_child(_shape, false, INTERNAL_MODE_FRONT)
	build()


func get_floor_height(x: float, z: float) -> float:
	if _islands.is_empty():
		_islands.assign(find_children("*", "IslandShape", false))
	var shore := INF  # distance to the nearest shoreline; negative = on an island
	var top := -INF
	for island in _islands:
		var offset := Vector2(x - island.position.x, z - island.position.z)
		var angle := offset.angle()
		var wobble := noise.get_noise_2d(cos(angle) * 120.0 + island.shape_seed * 97.0, sin(angle) * 120.0) if noise else 0.0
		var r := island.radius * (1.0 + island.roughness * wobble)
		var d := offset.length() - r
		if d < 0.0:
			var hill := island.height * smoothstep(0.0, r * 0.75, -d)
			if noise:  # gentle bumps, none at the waterline
				hill += noise.get_noise_2d(x * 3.0 + island.shape_seed * 31.0, z * 3.0) * minf(-d * 0.15, 1.2)
			top = maxf(top, profile.sample(0.0) + hill)
		shore = minf(shore, d)
	if shore < 0.0:
		return top
	var h := profile.sample(shore)
	if noise:
		var amount := lerpf(shallow_variation, deep_variation, smoothstep(deep_from - 20.0, deep_from + 20.0, shore))
		h += noise.get_noise_2d(x, z) * amount * smoothstep(5.0, 30.0, shore)
	return h


func build() -> void:
	_islands.assign(find_children("*", "IslandShape", false))
	var n := int(size / spacing) + 1
	var half := (n - 1) * spacing * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = get_floor_height(i * spacing - half, j * spacing - half)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			verts[j * n + i] = Vector3(i * spacing - half, h, j * spacing - half)
			var dx := heights[j * n + mini(i + 1, n - 1)] - heights[j * n + maxi(i - 1, 0)]
			var dz := heights[mini(j + 1, n - 1) * n + i] - heights[maxi(j - 1, 0) * n + i]
			normals[j * n + i] = Vector3(-dx, 2.0 * spacing, -dz).normalized()
	for chunk in _chunks:
		chunk.queue_free()
	_chunks.clear()
	for cj in range(0, n - 1, chunk_cells):
		for ci in range(0, n - 1, chunk_cells):
			_add_chunk(verts, normals, n, ci, cj, mini(ci + chunk_cells, n - 1), mini(cj + chunk_cells, n - 1))

	# Height map cells are 1 unit, so scale the shape (uniformly) to the grid spacing.
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	for k in heights.size():
		heights[k] /= spacing
	shape.map_data = heights
	_shape.shape = shape
	_shape.scale = Vector3.ONE * spacing


## One chunk of the ground mesh: grid points i0..i1 by j0..j1.
func _add_chunk(verts: PackedVector3Array, normals: PackedVector3Array, n: int, i0: int, j0: int, i1: int, j1: int) -> void:
	var w := i1 - i0 + 1
	# Placed at its own center, so visibility distance is measured to the chunk, not the world origin.
	var center := (verts[j0 * n + i0] + verts[j1 * n + i1]) * 0.5 * Vector3(1, 0, 1)
	var chunk_verts := PackedVector3Array()
	var chunk_normals := PackedVector3Array()
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			chunk_verts.append(verts[j * n + i] - center)
			chunk_normals.append(normals[j * n + i])
	var indices := PackedInt32Array()
	for j in j1 - j0:
		for i in i1 - i0:
			var a := j * w + i
			indices.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = chunk_verts
	arrays[Mesh.ARRAY_NORMAL] = chunk_normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var chunk := MeshInstance3D.new()
	chunk.mesh = mesh
	chunk.position = center
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.visibility_range_end = visible_distance
	add_child(chunk, false, INTERNAL_MODE_FRONT)
	_chunks.append(chunk)
