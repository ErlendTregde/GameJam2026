class_name Ocean
extends MeshInstance3D
## Keeps the ocean mesh under the camera and mirrors the shader's Gerstner waves
## on the CPU so floating bodies can ask for the water height. Builds its own mesh: a grid
## that is dense around the camera and coarse toward the horizon, so far water costs little.

## World height of the calm water surface.
@export var sea_level := 0.0
@export_group("Mesh")
## Width of the water around the camera (m).
@export var size := 800.0
## Grid cells along each side.
@export var resolution := 160
## Cell size at the center compared to an even grid (smaller = denser near the camera).
@export_range(0.05, 1.0) var center_detail := 0.25

var _material: ShaderMaterial
var _waves: Array[Vector4] = []


func _ready() -> void:
	_material = material_override
	mesh = _build_mesh()
	for wave in ["wave_a", "wave_b", "wave_c", "wave_d"]:
		_waves.append(_material.get_shader_parameter(wave))


func _process(_delta: float) -> void:
	_material.set_shader_parameter("wave_time", wave_time())
	var camera := get_viewport().get_camera_3d()
	if camera:
		# Move in whole center cells, so the dense grid near the camera doesn't swim.
		global_position = (camera.global_position * Vector3(1, 0, 1)).snapped(Vector3.ONE * _center_cell())
		global_position.y = sea_level


func wave_time() -> float:
	return Time.get_ticks_msec() * 0.001


## World-space water height at pos (x/z).
func get_height(pos: Vector3) -> float:
	var t := wave_time()
	var target := Vector2(pos.x, pos.z)
	var p := target
	# Gerstner waves move points sideways: find the undisplaced point that ends up at target.
	for i in 3:
		var d := _displace(p, t)
		p = target - Vector2(d.x, d.z)
	return sea_level + _displace(p, t).y


func _displace(p: Vector2, t: float) -> Vector3:
	var d := Vector3.ZERO
	for w in _waves:
		var k := TAU / w.w
		var dir := Vector2(w.x, w.y).normalized()
		var f := k * (dir.dot(p) - sqrt(9.8 / k) * t)
		var a := w.z / k
		d += Vector3(dir.x * a * cos(f), a * sin(f), dir.y * a * cos(f))
	return d


func _center_cell() -> float:
	return size * 0.5 * center_detail * 2.0 / resolution


## Position along one axis for grid coordinate u in -1..1: fine near 0, coarse at the edges.
func _warp(u: float) -> float:
	return size * 0.5 * u * (center_detail + (1.0 - center_detail) * u * u)


func _build_mesh() -> ArrayMesh:
	var n := resolution + 1
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in n:
		for i in n:
			verts[j * n + i] = Vector3(_warp(i * 2.0 / resolution - 1.0), 0.0, _warp(j * 2.0 / resolution - 1.0))
	var indices := PackedInt32Array()
	for j in resolution:
		for i in resolution:
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	built.custom_aabb = AABB(Vector3(-size * 0.5, -5.0, -size * 0.5), Vector3(size, 10.0, size))  # waves move it
	return built
