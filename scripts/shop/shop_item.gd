@tool
class_name ShopItem
extends StaticBody3D
## One item hanging on a shop board. Shows the item's model; look at it to see its name and price
## above it; E buys it (into a free slot, or at your feet if the hotbar is full).

@export var item: ItemData:
	set(value):
		item = value
		if is_inside_tree():
			_show_model()
@export var price := 10
## Longest side of the model on the board (m).
@export var display_size := 0.6
## Turns just the model (degrees), e.g. to lay a spear across the board; the label stays upright.
@export var model_rotation := Vector3.ZERO:
	set(value):
		model_rotation = value
		if is_inside_tree():
			_show_model()
@export var label: Label3D

var _hovered := 0.0  # > 0 while the player looks at it
var _model: Node3D


func _ready() -> void:
	_show_model()
	if label:
		label.visible = Engine.is_editor_hint()


func _show_model() -> void:
	if _model:
		_model.queue_free()
		_model = null
	if item == null:
		return
	_model = item.make_model()
	add_child(_model, false, INTERNAL_MODE_FRONT)
	var bounds := ItemData.model_bounds(_model)
	var s := display_size / maxf(bounds.get_longest_axis_size(), 0.01)
	var turn := Basis.from_euler(model_rotation * PI / 180.0)
	_model.basis = turn.scaled(Vector3.ONE * s)
	_model.position = turn * -bounds.get_center() * s
	if label:
		label.text = "%s\n$%d\n[E]" % [item.name, price]


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or label == null:
		return
	_hovered -= delta
	label.visible = _hovered > 0.0


## Called every frame the player looks at it: shows the floating label (the HUD prompt stays empty).
func get_prompt() -> String:
	_hovered = 0.1
	return ""


func interact(player: Node) -> void:
	if item == null or not player.spend(price):
		if label:
			label.modulate = Color(1, 0.3, 0.3)  # can't afford: flash red
			create_tween().tween_property(label, "modulate", Color.WHITE, 0.6)
		return
	player.give(item)
