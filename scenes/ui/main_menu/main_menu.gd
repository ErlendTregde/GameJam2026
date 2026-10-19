extends Node3D
## Entry scene: the island as the backdrop, Coco on his table watching the cursor, and the menu.
## Host (a Steam room, or LAN without Steam), join by Steam Lobby ID or a LAN host's IP, or play
## solo. There is no lobby: hosting and joining go straight onto the island.

## Where the camera sits relative to Coco (his space: +Z is where his face points), and what it
## looks at, a little to his right so the menu has the left side of the screen.
@export var camera_offset := Vector3(-0.9, 0.55, 2.4)
@export var look_offset := Vector3(-0.75, 0.35, 0.0)
## How far along the camera-to-Coco distance the cursor point sits (small = he looks at the viewer).
@export var cursor_depth := 0.3

@onready var _world: Node3D = $World
@onready var _camera: Camera3D = $Camera
@onready var _status: Label = %Status
@onready var _join_code: LineEdit = %JoinCode

var _coco: Coco


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The island is only scenery here: no player, no sharks, no pause menu.
	for path in ["Player", "SharkZone", "SharkZone2", "Players", "PauseMenu"]:
		var node := _world.get_node_or_null(path)
		if node:
			node.free()
	_coco = _world.find_child("Coco", true, false) as Coco
	if _coco:
		_coco.tip_distance = 0.0
		var face := _coco.global_transform
		_camera.global_position = face * camera_offset
		_camera.look_at(face * look_offset, Vector3.UP)
	_camera.make_current()
	RoomService.status_message_changed.connect(_show_status)
	var carried := AppFlow.consume_status_message()
	_show_status(carried if not carried.is_empty() else _signed_in_text())


func _process(_delta: float) -> void:
	if _coco == null:
		return
	# Coco looks out at us, toward the cursor: at the point under it, a little in front of the camera.
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var distance := origin.distance_to(_coco.global_position) * cursor_depth
	_coco.look_target = origin + _camera.project_ray_normal(mouse) * distance


func _signed_in_text() -> String:
	if SteamManager.is_steam_available():
		return "Signed in as %s" % SteamState.local_display_name()
	return "Steam is not running: Host makes a LAN game"


func _show_status(message: String) -> void:
	_status.text = message


func _on_host_pressed() -> void:
	RoomService.host()


func _on_join_pressed() -> void:
	RoomService.join(_join_code.text)


func _on_solo_pressed() -> void:
	RoomService.start_solo()


func _on_quit_pressed() -> void:
	get_tree().quit()
