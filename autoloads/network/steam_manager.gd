extends Node
## Steam lobby layer. Owns Steam initialisation and translates raw Steam
## callbacks into the signals the rest of the project listens to.
##
## Set your own Steam App ID in Project Settings under
## steam/initialization/app_data/app_id before shipping. 480 is Spacewar, Valve's
## public test app — fine for development, not for release.

## Fallback for when the setting is missing, e.g. the addon has not registered it
## yet. The real value lives in project.godot.
const DEFAULT_APP_ID: int = 480
const APP_ID_SETTING := "steam/initialization/app_data/app_id"

const PRIVATE_LOBBY = 0
const FRIENDS_ONLY_LOBBY = 1
const PUBLIC_LOBBY = 2
const INVISIBLE_LOBBY = 3

signal steam_availability_changed(is_available: bool, reason: String)
signal lobby_created(lobby_id: int, lobby_name: String)
signal lobby_joined(lobby_id: int, lobby_name: String)
signal lobby_left(lobby_id: int)
signal lobby_join_failed(lobby_id: int, response: int)
signal lobby_members_updated(lobby_id: int, members: Dictionary)
signal lobby_data_updated(lobby_id: int, member_id: int)
signal join_request_pending(lobby_id: int, friend_id: int, source: String)

var _steam = null
var last_init_error: String = ""

func _ready() -> void:
	_steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	initialize_steam()
	if _steam == null:
		return

	_steam.lobby_created.connect(_on_lobby_created)
	_steam.lobby_chat_update.connect(_on_lobby_chat_update)
	_steam.lobby_data_update.connect(_on_lobby_data_update)
	_steam.lobby_joined.connect(_on_lobby_joined)
	_steam.join_requested.connect(_on_lobby_join_requested)
	_check_command_line()

func is_steam_available() -> bool:
	return _steam != null and SteamState.steam_initialized

## Human-readable explanation of why Steam is unavailable. Empty when it is.
func get_unavailable_reason() -> String:
	return last_init_error

func initialize_steam() -> void:
	if _steam == null:
		_fail_init("Steam singleton not available. Is godotsteam.gdextension loaded? Restart Godot.")
		return

	# project.godot sets initialize_on_startup=false so we control init ourselves.
	# steamInitEx() exports SteamAppId/SteamGameId itself, which is what a
	# steam_appid.txt file would otherwise be there to provide.
	var app_id := int(ProjectSettings.get_setting(APP_ID_SETTING, DEFAULT_APP_ID))
	var init: Dictionary = _steam.steamInitEx(app_id, true)
	if init["status"] > _steam.STEAM_API_INIT_RESULT_OK:
		_fail_init("Failed to initialize Steam: %s" % init)
		return

	if not _steam.isSubscribed():
		_fail_init("The local Steam user does not own this app.")
		return

	SteamState.user_data.steam_id = _steam.getSteamID()
	SteamState.user_data.steam_username = _steam.getPersonaName()
	SteamState.steam_initialized = true
	last_init_error = ""
	print("[SteamManager] Initialized OK  steam_id=%d  username='%s'" % [
		SteamState.local_steam_id(), SteamState.local_display_name()])
	steam_availability_changed.emit(true, "")

func _fail_init(reason: String) -> void:
	last_init_error = reason
	SteamState.steam_initialized = false
	push_warning("[SteamManager] %s" % reason)
	steam_availability_changed.emit(false, reason)

# ---------------------------------------------------------------------------
# Lobby operations
# ---------------------------------------------------------------------------

func create_lobby(lobby_name: String = "", max_players: int = RoomState.MAX_PLAYERS) -> void:
	if not is_steam_available() or SteamState.lobby_data.id != 0:
		return
	if lobby_name == "":
		lobby_name = "%s's lobby" % SteamState.local_display_name()
	var size := clampi(max_players, 1, RoomState.MAX_PLAYERS)
	SteamState.lobby_data.name = lobby_name
	SteamState.lobby_data.lobby_size = size
	print("[SteamManager] Creating lobby '%s'  max=%d" % [lobby_name, size])
	_steam.createLobby(FRIENDS_ONLY_LOBBY, size)

func join_lobby(lobby_id: int) -> void:
	if not is_steam_available():
		return
	SteamState.lobby_data.id = lobby_id
	SteamState.lobby_data.started = false
	SteamState.lobby_data.peer_members.clear()
	_steam.joinLobby(lobby_id)

func leave_lobby(lobby_id: int) -> void:
	if _steam == null or SteamState.lobby_data.id == 0:
		return
	_steam.leaveLobby(lobby_id)
	for member in SteamState.lobby_data.members:
		_steam.closeP2PSessionWithUser(member)
	P2P.reset_transport_state()
	SteamState.reset_lobby_state()
	SteamState.clear_pending_join_request()
	print("[SteamManager] Left lobby %d" % lobby_id)
	lobby_left.emit(lobby_id)

func leave_current_lobby() -> void:
	leave_lobby(SteamState.lobby_data.id)

func open_invite_dialog() -> void:
	if not is_steam_available() or SteamState.lobby_data.id == 0:
		return
	_steam.activateGameOverlayInviteDialog(SteamState.lobby_data.id)

## Steam captures the microphone itself and offers no API for choosing the input
## device, so the device picker lives in Steam's own settings. Opens the overlay
## there; does nothing if the overlay is disabled.
func open_voice_settings() -> void:
	if not is_steam_available():
		return
	_steam.activateGameOverlay("Settings")

## Re-reads the Steam member roster into SteamState and announces it.
func get_lobby_members(lobby_id: int = -1) -> Dictionary:
	if lobby_id == -1:
		lobby_id = SteamState.lobby_data.id
	if _steam == null or lobby_id == 0:
		return {}

	var players := {}
	for i in _steam.getNumLobbyMembers(lobby_id):
		var member_steam_id: int = _steam.getLobbyMemberByIndex(lobby_id, i)
		players[member_steam_id] = {
			"steam_id": member_steam_id,
			"steam_username": _steam.getFriendPersonaName(member_steam_id),
		}

	SteamState.lobby_data.members = players
	lobby_members_updated.emit(lobby_id, players)
	return players

## Host-only: flip the lobby to "started" and tell every peer the session is live.
func start_session_for_all() -> void:
	if SteamState.lobby_data.id == 0:
		return
	SteamState.lobby_data.started = true
	if _steam != null:
		_steam.setLobbyData(SteamState.lobby_data.id, "started", "1")
	P2P.start_session()

# ---------------------------------------------------------------------------
# Steam callbacks
# ---------------------------------------------------------------------------

func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result != 1:
		_fail_init("Lobby creation failed (code %d)." % connect_result)
		return
	print("[SteamManager] Lobby created  id=%d" % lobby_id)
	SteamState.lobby_data.id = lobby_id
	SteamState.lobby_data.owner_id = SteamState.local_steam_id()
	SteamState.lobby_data.started = false
	_steam.setLobbyData(lobby_id, "name", SteamState.lobby_data.name)
	_steam.setLobbyData(lobby_id, "started", "0")
	P2P.create_socket()
	get_lobby_members(lobby_id)
	lobby_created.emit(lobby_id, SteamState.lobby_data.name)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != _steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		SteamState.reset_lobby_state()
		SteamState.clear_pending_join_request()
		lobby_join_failed.emit(lobby_id, response)
		return

	var owner_id: int = _steam.getLobbyOwner(lobby_id)
	SteamState.lobby_data.name = _steam.getLobbyData(lobby_id, "name")
	SteamState.lobby_data.owner_id = owner_id
	SteamState.lobby_data.started = _steam.getLobbyData(lobby_id, "started") == "1"
	get_lobby_members(lobby_id)
	SteamState.clear_pending_join_request()

	if SteamState.local_steam_id() != owner_id:
		P2P.connect_socket(owner_id)

	lobby_joined.emit(lobby_id, SteamState.lobby_data.name)

func _on_lobby_chat_update(lobby_id: int, _changed_id: int, _maker_id: int, _chat_state: int) -> void:
	# Someone joined, left or was kicked — the roster is stale, re-read it.
	get_lobby_members(lobby_id)

func _on_lobby_data_update(success: bool, lobby_id: int, member_id: int) -> void:
	if not success or lobby_id != SteamState.lobby_data.id:
		return
	SteamState.lobby_data.started = _steam.getLobbyData(lobby_id, "started") == "1"
	get_lobby_members(lobby_id)
	lobby_data_updated.emit(lobby_id, member_id)

func _on_lobby_join_requested(lobby_id: int, friend_id: int) -> void:
	print("[SteamManager] Invite received  lobby_id=%d  from=%d" % [lobby_id, friend_id])
	SteamState.set_pending_join_request(lobby_id, "steam_invite", friend_id)
	join_request_pending.emit(lobby_id, friend_id, "steam_invite")
	join_lobby(lobby_id)

## Handles launching via a Steam invite while the game is closed:
## Steam re-runs the executable with "+connect_lobby <id>".
func _check_command_line() -> void:
	var args: Array = OS.get_cmdline_args()
	if args.size() < 2 or args[0] != "+connect_lobby":
		return
	var lobby_id := int(args[1])
	if lobby_id <= 0:
		return
	print("[SteamManager] Command-line lobby id: %d" % lobby_id)
	SteamState.set_pending_join_request(lobby_id, "command_line")
	join_request_pending.emit(lobby_id, 0, "command_line")
	join_lobby(lobby_id)
