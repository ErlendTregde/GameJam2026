extends RefCounted
class_name RoomMemberState
## One player in the room. The host builds these from the Steam lobby roster and
## replicates them to everyone inside a RoomState snapshot.

var steam_id: int = 0
var peer_id: int = 0
var seat_index: int = -1
var display_name: String = ""
var color: Color = Color.WHITE
var is_host: bool = false
var is_local: bool = false
var is_ready: bool = false

func configure(
	new_steam_id: int,
	new_peer_id: int,
	new_seat_index: int,
	new_display_name: String,
	new_color: Color,
	new_is_host: bool,
	new_is_local: bool
) -> RoomMemberState:
	steam_id = new_steam_id
	peer_id = new_peer_id
	seat_index = new_seat_index
	display_name = new_display_name
	color = new_color
	is_host = new_is_host
	is_local = new_is_local
	return self

func to_dict() -> Dictionary:
	return {
		"steam_id": steam_id,
		"peer_id": peer_id,
		"seat_index": seat_index,
		"display_name": display_name,
		"color": color.to_html(),
		"is_host": is_host,
		"is_local": is_local,
		"is_ready": is_ready,
	}

static func from_dict(data: Dictionary) -> RoomMemberState:
	var state := RoomMemberState.new().configure(
		int(data.get("steam_id", 0)),
		int(data.get("peer_id", 0)),
		int(data.get("seat_index", -1)),
		String(data.get("display_name", "")),
		Color(data.get("color", "#ffffff")),
		bool(data.get("is_host", false)),
		bool(data.get("is_local", false))
	)
	state.is_ready = bool(data.get("is_ready", false))
	return state
