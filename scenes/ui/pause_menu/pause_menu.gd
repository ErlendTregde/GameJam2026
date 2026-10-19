class_name PauseMenu
extends CanvasLayer
## Esc menu for the island: room id and invite, mic mute, resume, leave. The game keeps running
## behind it (it is multiplayer); while it is open the mouse is free.

static var _open := false

@onready var _root: Control = $Root
@onready var _room_row: Control = %RoomRow
@onready var _room_label: Label = %RoomLabel
@onready var _copy_button: Button = %CopyButton
@onready var _invite_button: Button = %InviteButton
@onready var _mute_check: CheckBox = %MuteCheck


static func is_open() -> bool:
	return _open


func _ready() -> void:
	_set_open(false)


func _exit_tree() -> void:
	_open = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_open(not _root.visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_open = open
	_root.visible = open
	if open:
		var lobby: int = SteamState.lobby_data.id
		_room_row.visible = lobby != 0
		_room_label.text = "Lobby ID: %d" % lobby
		_invite_button.visible = lobby != 0
		_mute_check.visible = P2P.is_online() and not P2P.is_lan()
		_mute_check.set_pressed_no_signal(VoiceChatService.is_muted())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	_set_open(false)


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(str(SteamState.lobby_data.id))
	_copy_button.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_copy_button):
		_copy_button.text = "Copy"


func _on_invite_pressed() -> void:
	SteamManager.open_invite_dialog()


func _on_mute_toggled(muted: bool) -> void:
	VoiceChatService.set_muted(muted)


func _on_leave_pressed() -> void:
	_set_open(false)
	RoomService.request_leave_room()
