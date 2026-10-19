extends Node
## The room: who is playing, which seat (colour, spawn offset, body name) each holds, and the
## host-authoritative snapshot that keeps every peer's RoomState identical.
## (From the Modbit-Studios MultiplayerTemplate, minus the lobby: there is no ready-up. Hosting
## starts the game at once, and joining goes straight into the island as soon as the host's
## snapshot arrives. Players can join at any time.)
##
## The host is the only writer. Clients apply whatever snapshot comes back.

signal room_state_changed
signal status_message_changed(message: String)
signal room_error(message: String)

var room_state: RoomState = null
var status_message: String = ""

func _ready() -> void:
	_reset_room_state()
	call_deferred("_connect_dependencies")

func _connect_dependencies() -> void:
	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined.connect(_on_lobby_joined)
	SteamManager.lobby_join_failed.connect(_on_lobby_join_failed)
	SteamManager.lobby_members_updated.connect(_on_roster_changed)
	SteamManager.join_request_pending.connect(_on_join_request_pending)
	SteamManager.steam_availability_changed.connect(_on_steam_availability_changed)
	P2P.peer_registered_signal.connect(_on_peer_registered)
	P2P.player_left_signal.connect(_on_player_left)
	P2P.host_disconnected_signal.connect(_on_host_disconnected)
	P2P.connection_failed_signal.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_host)

# ---------------------------------------------------------------------------
# Public API — called by the menus
# ---------------------------------------------------------------------------

## Play alone, offline: no peer at all, so every service acts as host.
func start_solo() -> void:
	P2P.reset_transport_state()
	_reset_room_state()
	room_state.game_active = true
	var me := SteamState.local_steam_id()
	room_state.members_by_steam_id[me] = RoomMemberState.new().configure(
		me, 1, 0, SteamState.local_display_name(), RoomState.seat_color(0), true, true)
	room_state_changed.emit()
	AppFlow.open_world()

## Host: a friends-only Steam lobby when Steam is running, otherwise (or with [param lan]) a LAN game.
func host(lan := false) -> void:
	_reset_room_state()
	if SteamManager.is_steam_available() and not lan:
		_set_status("Creating Steam room...")
		SteamManager.create_lobby()
		return
	if not P2P.host_lan():
		_emit_room_error("Could not open a LAN game (port %d busy?)." % P2P.LAN_PORT)
		return
	room_state.room_name = "LAN"
	_start_hosted_game()

## Join by Steam Lobby ID (a long number) or a LAN host's IP address.
func join(code: String) -> void:
	_reset_room_state()
	code = code.strip_edges()
	if code.is_valid_int() and code.length() > 6:
		if not SteamManager.is_steam_available():
			_emit_room_error("Steam is not running: join by IP address instead.")
			return
		_set_status("Joining Steam room...")
		SteamManager.join_lobby(code.to_int())
		return
	if code.is_empty() or not P2P.join_lan(code):
		_emit_room_error("Enter a Lobby ID or the host's IP address.")
		return
	_set_status("Connecting to %s..." % code)

func get_room_state() -> RoomState:
	return room_state

func is_local_host() -> bool:
	return P2P.acts_as_host()

## The local player's seat (0 when playing solo or not yet seated).
func local_seat() -> int:
	return maxi(room_state.get_local_seat_index(SteamState.local_steam_id()), 0)

func request_leave_room() -> void:
	if SteamState.lobby_data.id != 0:
		SteamManager.leave_current_lobby()
	P2P.reset_transport_state()
	_reset_room_state()
	AppFlow.open_main_menu("Left the game.")

# ---------------------------------------------------------------------------
# State plumbing
# ---------------------------------------------------------------------------

func _reset_room_state() -> void:
	room_state = RoomState.new()
	status_message = ""
	room_state_changed.emit()

func _set_status(message: String) -> void:
	status_message = message
	status_message_changed.emit(status_message)

func _emit_room_error(message: String) -> void:
	_set_status(message)
	room_error.emit(message)

func _start_hosted_game() -> void:
	room_state.game_active = true
	room_state.lobby_id = int(SteamState.lobby_data.id)
	room_state.host_steam_id = SteamState.local_steam_id()
	if SteamState.lobby_data.id != 0:
		SteamManager.start_session_for_all()
	_rebuild_host_room_state()
	_set_status("In game")
	AppFlow.open_world()

## Host only. Reconciles the roster (the Steam lobby, or the LAN peers) and broadcasts it.
func _rebuild_host_room_state() -> void:
	if not P2P.is_host():
		return
	var names := {}  # steam_id -> display name
	if SteamState.lobby_data.id != 0:
		for steam_id in SteamState.lobby_data.members:
			names[int(steam_id)] = String(SteamState.lobby_data.members[steam_id].get("steam_username", "Diver"))
	for peer_id in SteamState.lobby_data.peer_members:
		var steam_id := int(SteamState.lobby_data.peer_members[peer_id])
		if not names.has(steam_id):
			names[steam_id] = String(P2P.peer_names.get(peer_id, "Diver"))
	# Only players actually connected get a seat (a Steam lobby member may still be connecting).
	for existing in room_state.members_by_steam_id.keys().duplicate():
		if P2P.peer_id_of(int(existing)) == 0:
			room_state.members_by_steam_id.erase(existing)
	for steam_id: int in names:
		var peer_id := P2P.peer_id_of(steam_id)
		if peer_id == 0:
			continue
		var member := room_state.get_member(steam_id)
		if member == null:
			var seat := _first_free_seat()
			if seat < 0:
				continue  # full
			room_state.members_by_steam_id[steam_id] = RoomMemberState.new().configure(
				steam_id, peer_id, seat, names[steam_id], RoomState.seat_color(seat),
				steam_id == SteamState.local_steam_id(), steam_id == SteamState.local_steam_id())
		else:
			member.peer_id = peer_id
			member.display_name = names[steam_id]
	_broadcast_room_snapshot()

func _first_free_seat() -> int:
	for i in RoomState.MAX_PLAYERS:
		if not room_state.is_seat_occupied(i):
			return i
	return -1

func _broadcast_room_snapshot() -> void:
	var snapshot := room_state.to_dict()
	if not P2P.is_online():
		_client_apply_room_snapshot(snapshot)
		return
	_client_apply_room_snapshot.rpc(snapshot)

@rpc("authority", "call_local", "reliable")
func _client_apply_room_snapshot(snapshot: Dictionary) -> void:
	var was_active := room_state.game_active
	room_state = RoomState.from_dict(snapshot)
	_restamp_local_flags()
	room_state_changed.emit()
	if room_state.game_active and not was_active and not P2P.is_host():
		_set_status("In game")
		AppFlow.open_world()

## Snapshots are authored by the host, so every is_local flag in them reflects the
## host's perspective. Each client re-stamps them from its own point of view.
func _restamp_local_flags() -> void:
	var local_steam_id := SteamState.local_steam_id()
	for member in room_state.members_by_steam_id.values():
		member.is_local = member.steam_id == local_steam_id

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_steam_availability_changed(is_available: bool, reason: String) -> void:
	if not is_available:
		_set_status(reason)

func _on_lobby_created(_lobby_id: int, lobby_name: String) -> void:
	room_state.room_name = lobby_name
	_start_hosted_game()

func _on_lobby_joined(_lobby_id: int, _lobby_name: String) -> void:
	if not SteamState.is_lobby_owner():
		_set_status("Connecting to host...")

func _on_connected_to_host() -> void:
	_set_status("Waiting for the host...")

func _on_lobby_join_failed(_lobby_id: int, response: int) -> void:
	_emit_room_error("Failed to join the room (code %d)." % response)

func _on_roster_changed(_lobby_id: int, _members: Dictionary) -> void:
	_rebuild_host_room_state()

func _on_join_request_pending(lobby_id: int, _friend_id: int, _source: String) -> void:
	_reset_room_state()
	_set_status("Joining Steam room %d..." % lobby_id)

func _on_peer_registered(_peer_id: int, _steam_id: int) -> void:
	_rebuild_host_room_state()

## A player leaving does not end the game — the host drops them from the roster.
func _on_player_left(_peer_id: int, _steam_id: int) -> void:
	_rebuild_host_room_state()

func _on_host_disconnected() -> void:
	_reset_room_state()
	AppFlow.open_main_menu("The host left the game.")

func _on_connection_failed() -> void:
	_reset_room_state()
	AppFlow.open_main_menu("Could not connect.")
