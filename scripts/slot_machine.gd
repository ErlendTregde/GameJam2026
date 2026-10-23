class_name SlotMachine
extends StaticBody3D
## A slot machine: [E] pays `cost` and spins the four reels; they stop one after another, left to
## right, and matching symbols on the middle row (counted from the left: 2, 3 or 4 of a kind)
## drop those items out of the machine. Each reel is a curved panel over the model's painted reel
## whose strip of symbols scrolls (shaders/slot_reel.gdshader). Played locally: your spin.

## The symbols, in the icon atlas's order (assets/slot/reel_icons.png): what each one drops.
@export var prizes: Array[ItemData] = []
## The reel strip, top to bottom: how often a symbol is on it sets how often it lands, so the
## valuable prizes are on it less.
@export var strip := PackedInt32Array([0, 1, 0, 2, 1, 0, 3, 1, 0, 4, 1, 0, 2, 1, 0, 5, 1, 0, 3, 2, 4])
@export var cost := 10
## How many of a symbol's item drop for 2, 3 and 4 of a kind from the left (prizes order).
@export var drops_two := PackedInt32Array([1, 1, 1, 0, 0, 0])
@export var drops_three := PackedInt32Array([2, 2, 3, 1, 1, 1])
@export var drops_four := PackedInt32Array([4, 3, 6, 2, 1, 1])
## Seconds between the prizes popping out, and how hard they are tossed (forward, up), m/s.
@export var drop_interval := 0.15
@export var toss := Vector2(1.6, 2.5)
## Seconds the first reel spins; each next reel stops this much later.
@export var spin_time := 1.6
@export var reel_delay := 0.45
@export_group("Reel window")
## The model's curved reel surface: a circle arc (center y and x, radius) between these heights.
@export var arc_center := Vector2(-0.613, 1.171)
@export var arc_radius := 0.668
@export var arc_heights := Vector2(0.9275, 1.414)
## Each reel's edges across the machine (z), left to right as seen from the front (+X).
@export var reel_edges: Array[Vector2] = [Vector2(0.216, 0.398), Vector2(0.017, 0.183), Vector2(-0.183, -0.017), Vector2(-0.398, -0.216)]

var _offsets: Array[float] = []
var _spinning := false

@onready var _reels: Array[Node] = $Reels.get_children()
@onready var _result: Label3D = $Result
@onready var _tray: Marker3D = $Tray


func _ready() -> void:
	for i in _reels.size():
		_reels[i].mesh = _arc(reel_edges[i])
		_offsets.append(float(randi() % strip.size()))
		_show(_offsets[i], i)
	_upload_strip()


func get_prompt() -> String:
	return "" if _spinning else "[E] spin $%d" % cost


func is_spinning() -> bool:
	return _spinning


func interact(player: Node) -> void:
	if _spinning or not player.spend(cost):
		return
	_spinning = true
	_result.visible = false
	_upload_strip()  # it may have been changed
	var last: Tween
	for i in _reels.size():
		# Land a random strip position in the middle row, after a few full turns.
		var landing := float(posmod(1 - randi() % strip.size(), strip.size()))
		var end := landing
		while end < _offsets[i] + strip.size() * (2 + i):
			end += strip.size()
		last = create_tween()
		last.tween_method(_show.bind(i), _offsets[i], end + 0.2, spin_time + i * reel_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		last.tween_method(_show.bind(i), end + 0.2, end, 0.15).set_trans(Tween.TRANS_SINE)  # settles back: a little bounce
		_offsets[i] = end
	await last.finished
	_spinning = false
	var won := prize(middle_symbols())
	_result.text = "%s x%d!" % [won[0].name, won.size()] if won else "No luck"
	_result.visible = true
	var hide_at := Time.get_ticks_msec() + 2500
	for item in won:  # out of the tray in front, one by one
		var sideways := global_basis.z * randf_range(-0.6, 0.6)
		ItemService.spawn(item, 0.0, _tray.global_position, global_basis.x * toss.x + Vector3.UP * toss.y + sideways)
		await get_tree().create_timer(drop_interval).timeout
	await get_tree().create_timer(maxf((hide_at - Time.get_ticks_msec()) / 1000.0, 0.0)).timeout
	if not _spinning:
		_result.visible = false


## The symbols on the middle row (the pay line), left to right.
func middle_symbols() -> Array:
	var shown := []
	for offset in _offsets:
		shown.append(strip[posmod(1 - roundi(offset), strip.size())])
	return shown


## What a pay line wins: the first symbol's item, as many as 2, 3 or 4 in a row from the left give.
func prize(line: Array) -> Array[ItemData]:
	var same := 1
	while same < line.size() and line[same] == line[0]:
		same += 1
	var count := 0
	match same:
		2: count = drops_two[line[0]]
		3: count = drops_three[line[0]]
		4: count = drops_four[line[0]]
	var won: Array[ItemData] = []
	for i in count:
		won.append(prizes[line[0]])
	return won


## The reel strip to the shared reel material (its array holds up to 64 symbols).
func _upload_strip() -> void:
	var padded := strip.duplicate()
	padded.resize(64)
	var material: ShaderMaterial = _reels[0].material_override
	material.set_shader_parameter("strip", padded)
	material.set_shader_parameter("strip_length", strip.size())


func _show(offset: float, reel: int) -> void:
	_reels[reel].set_instance_shader_parameter("reel_offset", offset)


## A curved panel over one painted reel, a hair in front of it; UV y runs top to bottom.
func _arc(edges: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := asin((arc_heights.y - arc_center.y) / arc_radius)
	var bottom := asin((arc_heights.x - arc_center.y) / arc_radius)
	var steps := 12
	for k in steps:
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var v := float(k + corner.y) / steps
			var a := lerpf(top, bottom, v)
			var normal := Vector3(cos(a), sin(a), 0.0)
			st.set_normal(normal)
			st.set_uv(Vector2(corner.x, v))
			var z := edges.y if corner.x == 0 else edges.x  # u = 0 on the left as seen from the front (+X)
			st.add_vertex(Vector3(arc_center.x, arc_center.y, z) + normal * (arc_radius + 0.004))
	return st.commit()
