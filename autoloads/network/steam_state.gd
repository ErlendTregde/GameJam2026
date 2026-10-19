extends Node
## Shared Steam session state. Data only — no behaviour beyond simple derived queries.
## Everything here is filled in by SteamManager and P2P; read it from anywhere.

var steam_initialized: bool = false

var user_data: Dictionary = {
	"steam_id": 0,
	"steam_username": "",
}

var lobby_data: Dictionary = {
	"owner_id": 0,
	"id": 0,
	"members": {},       # steam_id -> {"steam_id": int, "steam_username": String}
	"peer_members": {},  # godot peer_id -> steam_id
	"name": "",
	"lobby_size": 4,
	"started": false,
}

## Set when a Steam overlay invite or +connect_lobby argument arrives before the
## UI is ready to act on it. The main menu drains this on _ready().
var pending_join_request: Dictionary = {
	"lobby_id": 0,
	"friend_id": 0,
	"source": "",
}

## Without Steam (LAN or solo) a made-up id and the computer's user name stand in; SteamManager
## overwrites both once Steam signs in.
func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	lan_id = rng.randi() + 1
	user_data.steam_id = lan_id
	var name := OS.get_environment("USERNAME") if OS.has_environment("USERNAME") else OS.get_environment("USER")
	user_data.steam_username = name.left(16) if not name.is_empty() else "Diver"

## A LAN game identifies players per running game, not per Steam account (two copies of the game on
## one computer, signed into the same Steam account, are still two players).
var lan_id := 0

func local_steam_id() -> int:
	return lan_id if P2P.is_lan() else int(user_data.steam_id)

func local_display_name() -> String:
	return String(user_data.steam_username)

func is_lobby_owner() -> bool:
	return local_steam_id() != 0 and local_steam_id() == int(lobby_data.owner_id)

func set_pending_join_request(lobby_id: int, source: String, friend_id: int = 0) -> void:
	pending_join_request.lobby_id = lobby_id
	pending_join_request.friend_id = friend_id
	pending_join_request.source = source

func clear_pending_join_request() -> void:
	pending_join_request.lobby_id = 0
	pending_join_request.friend_id = 0
	pending_join_request.source = ""

func reset_lobby_state() -> void:
	lobby_data.owner_id = 0
	lobby_data.id = 0
	lobby_data.members.clear()
	lobby_data.peer_members.clear()
	lobby_data.name = ""
	lobby_data.started = false
