extends Node
## Scene router. The only place in the project that calls change_scene_to_file, plus a one-shot
## status message handed to whichever scene opens next. (From the Modbit-Studios templates.)

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu/main_menu.tscn"
const WORLD_SCENE := "res://scenes/main.tscn"

var _pending_status_message: String = ""

## Read once by the destination scene's _ready(); clears itself.
func consume_status_message() -> String:
	var message := _pending_status_message
	_pending_status_message = ""
	return message

func open_main_menu(status_message: String = "") -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_go(MAIN_MENU_SCENE, status_message)

func open_world(status_message: String = "") -> void:
	_go(WORLD_SCENE, status_message)

func _go(scene_path: String, status_message: String) -> void:
	_pending_status_message = status_message
	var tree := get_tree()
	if tree == null:
		return
	if tree.current_scene and tree.current_scene.scene_file_path == scene_path:
		return
	tree.change_scene_to_file.call_deferred(scene_path)
