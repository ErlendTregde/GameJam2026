extends VBoxContainer
## One hotbar slot: renders the held item's model in its own little viewport and swaps
## to the "selected" frame style when chosen. Knows nothing about the inventory; whoever
## owns it calls set_item() and set_selected(). Styling lives in slot.tscn.

@export var normal_style: StyleBox
@export var selected_style: StyleBox

var _item: ItemData
var _weight := 0.0
var _model: Node3D

@onready var _frame: PanelContainer = $Frame
@onready var _viewport: SubViewport = $Frame/Preview/SubViewport
@onready var _camera: Camera3D = $Frame/Preview/SubViewport/Camera3D
@onready var _number: Label = $Number


func set_number(number: int) -> void:
	_number.text = str(number)


func set_selected(selected: bool) -> void:
	_frame.add_theme_stylebox_override("panel", selected_style if selected else normal_style)


## `weight` (kg) shows a caught fish's size: the slot is framed for the biggest of its kind.
func set_item(item: ItemData, weight := 0.0) -> void:
	if item == _item and weight == _weight:
		return
	_item = item
	_weight = weight
	if _model:
		_model.queue_free()
		_model = null
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE  # icons don't move: draw on change only
	if item == null:
		return
	_model = item.make_model()
	_viewport.add_child(_model)
	# Frame the model from its bounds, three-quarter view, so any item fills the slot.
	var bounds := ItemData.model_bounds(_model)
	var grow := item.size_scale(weight) if weight > 0.0 else 1.0
	var biggest := item.size_scale(item.weight_range.y) if weight > 0.0 else 1.0
	_model.scale = Vector3.ONE * grow
	bounds = Transform3D.IDENTITY.scaled(Vector3.ONE * grow) * bounds
	var radius := maxf(bounds.size.length() * 0.5 * biggest / grow, 0.01)
	_camera.size = radius * 2.2
	_camera.look_at_from_position(bounds.get_center() + Vector3(1.0, 0.8, 1.0).normalized() * radius * 4.0, bounds.get_center())
