extends VBoxContainer
## One hotbar slot: renders the held item's model in its own little viewport and swaps
## to the "selected" frame style when chosen. Knows nothing about the inventory; whoever
## owns it calls set_item() and set_selected(). Styling lives in slot.tscn.

@export var normal_style: StyleBox
@export var selected_style: StyleBox
## Seen straight from the front (e.g. a coin icon) instead of the three-quarter view.
@export var front_view := false

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


## Every item fills the slot the same (a fish's weight doesn't change its icon).
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
	var radius := maxf(bounds.size.length() * 0.5, 0.01)  # every size of a fish fills the slot the same
	_camera.size = radius * 2.2
	_camera.far = radius * 8.0  # models in big units (e.g. the goggles) sit far away
	var from := Vector3(0, 0, 1) if front_view else Vector3(1.0, 0.8, 1.0).normalized()
	if front_view:
		_camera.size = maxf(bounds.size.x, bounds.size.y) * 1.05  # fills the icon
	_camera.look_at_from_position(bounds.get_center() + from * radius * 4.0, bounds.get_center())
