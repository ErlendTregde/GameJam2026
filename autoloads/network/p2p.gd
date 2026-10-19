extends Node
## P2P transport. Wraps SteamMultiplayerPeer (or ENet on a LAN, when Steam is not running) and
## maintains the peer_id <-> steam_id registry that everything else uses for identity.
## (From the Modbit-Studios MultiplayerTemplate; ENet added for LAN play and local testing.)

signal session_started_signal
signal player_joined_signal(peer_id: int)
signal player_left_signal(peer_id: int, steam_id: int)
signal host_disconnected_signal
signal connection_failed_signal
signal peer_registered_signal(peer_id: int, steam_id: int)

const LAN_PORT := 24680
const LAN_MAX_CLIENTS := 3

var peer = null
## Display names of registered peers (peer_id -> String); on Steam they also come from the lobby.
var peer_names: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_host_disconnected)

## Close the connection before the engine tears everything down (quitting while connected).
func _exit_tree() -> void:
	reset_transport_state()

func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

## Whether host-side logic runs here: on the host, or offline with no peer at all.
func acts_as_host() -> bool:
	return is_host() or not is_online()

## Connected to anyone at all (host or client), not playing alone.
func is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer

## Our own peer id: 1 on the host and offline.
func local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1

## The peer_id registered for [param steam_id], or [param fallback] when none is.
func peer_id_of(steam_id: int, fallback: int = 0) -> int:
	for peer_id in SteamState.lobby_data.peer_members:
		if int(SteamState.lobby_data.peer_members[peer_id]) == steam_id:
			return int(peer_id)
	return fallback

func _new_peer_instance():
	# SteamMultiplayerPeer only exists once the GDExtension has loaded, which
	# happens at engine startup. If you dropped the DLLs into a running editor,
	# restart Godot or this stays null and hosting silently fails.
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		push_error("[P2P] SteamMultiplayerPeer not registered — is godotsteam.gdextension loaded? Restart Godot.")
		return null
	var instance = ClassDB.instantiate("SteamMultiplayerPeer")
	# Clients only hold a connection to the host, so without this Godot drops
	# every client-to-client RPC: voice and position sync reach the host and stop
	# there. GodotSteam defaults it to false, and nothing errors when it is.
	instance.server_relay = true
	return instance

func reset_transport_state() -> void:
	if peer != null and peer.has_method("close"):
		peer.close()
	multiplayer.set_multiplayer_peer(null)
	peer = null
	peer_names.clear()
	SteamState.lobby_data.started = false
	SteamState.lobby_data.peer_members.clear()

func create_socket() -> void:
	reset_transport_state()
	peer = _new_peer_instance()
	if peer == null:
		connection_failed_signal.emit()
		return
	peer.create_host(0)
	multiplayer.set_multiplayer_peer(peer)
	_register_self()
	print("[P2P] Listening as host")

func connect_socket(host_steam_id: int) -> void:
	reset_transport_state()
	peer = _new_peer_instance()
	if peer == null:
		connection_failed_signal.emit()
		return
	peer.create_client(host_steam_id, 0)
	multiplayer.set_multiplayer_peer(peer)
	print("[P2P] Connecting to host %d" % host_steam_id)

## LAN host (no Steam). False if the port is taken.
func host_lan(port: int = LAN_PORT) -> bool:
	reset_transport_state()
	var enet := ENetMultiplayerPeer.new()
	if enet.create_server(port, LAN_MAX_CLIENTS) != OK:
		return false
	peer = enet
	multiplayer.set_multiplayer_peer(enet)
	_register_self()
	print("[P2P] LAN host on port %d" % port)
	return true

## LAN client: joins the host at [param address] (an IP, e.g. 127.0.0.1).
func join_lan(address: String, port: int = LAN_PORT) -> bool:
	reset_transport_state()
	var enet := ENetMultiplayerPeer.new()
	if enet.create_client(address, port) != OK:
		return false
	peer = enet
	multiplayer.set_multiplayer_peer(enet)
	print("[P2P] Connecting to LAN host %s:%d" % [address, port])
	return true

func is_lan() -> bool:
	return peer is ENetMultiplayerPeer

func _register_self() -> void:
	SteamState.lobby_data.peer_members[1] = SteamState.local_steam_id()
	peer_names[1] = SteamState.local_display_name()

func start_session() -> void:
	if not multiplayer.is_server():
		return
	_mark_session_started.rpc()

func _host_disconnected() -> void:
	print("[P2P] Disconnected from host")
	reset_transport_state()
	host_disconnected_signal.emit()

func _connected_ok() -> void:
	print("[P2P] Connected to host")

func _connected_fail() -> void:
	print("[P2P] Connection failed")
	reset_transport_state()
	connection_failed_signal.emit()

func _player_connected(peer_id: int) -> void:
	# Hand our steam_id and name to the newcomer so both sides can map peer -> player.
	register_peer.rpc_id(peer_id, SteamState.local_steam_id(), SteamState.local_display_name())
	player_joined_signal.emit(peer_id)

func _player_disconnected(peer_id: int) -> void:
	var steam_id := int(SteamState.lobby_data.peer_members.get(peer_id, 0))
	SteamState.lobby_data.peer_members.erase(peer_id)
	peer_names.erase(peer_id)
	print("[P2P] Peer %d left" % peer_id)
	player_left_signal.emit(peer_id, steam_id)

@rpc("call_local", "reliable")
func _mark_session_started() -> void:
	SteamState.lobby_data.started = true
	session_started_signal.emit()

@rpc("any_peer", "reliable")
func register_peer(steam_id: int, display_name: String = "") -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	SteamState.lobby_data.peer_members[peer_id] = steam_id
	peer_names[peer_id] = display_name.left(24)
	print("[P2P] Registered peer %d = %d (%s)" % [peer_id, steam_id, display_name])
	peer_registered_signal.emit(peer_id, steam_id)
