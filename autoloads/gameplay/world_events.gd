extends Node
## Shared world events: chests, beaten bosses, the treasure and the boat. Host-authoritative like the other
## services: clients ask, the host decides and tells everyone. Nodes are addressed by their path
## under the world, which is the same on every peer.

const BOAT_SEND_INTERVAL := 1.0 / 20.0

## Treasure coins found so far (whole team), and the total; all found unlocks the boat.
signal treasure_changed(found: int, total: int)
var treasure_found := 0

var _boat_timer := 0.0

func _ready() -> void:
	WorldService.world_left.connect(func() -> void: treasure_found = 0)  # a new game starts with none
	# A driver who leaves the game lets go of the helm.
	P2P.player_left_signal.connect(func(peer_id: int, _steam_id: int) -> void:
		if not P2P.is_host() or not WorldService.in_world():
			return
		for boat: Boat in get_tree().get_nodes_in_group(&"boats"):
			if boat.driver == peer_id:
				_set_driver(_path(boat), 0))

func _path(node: Node) -> NodePath:
	return WorldService.world.get_path_to(node)

func _node(path: NodePath) -> Node:
	return WorldService.world.get_node_or_null(path) if WorldService.in_world() else null

# ---------------------------------------------------------------------------
# Chests
# ---------------------------------------------------------------------------

## A client paid [param paid] and wants [param chest] open; refunded if someone beat them to it.
func request_open_chest(chest: Chest, paid: int) -> void:
	_server_open_chest.rpc_id(1, _path(chest), paid)

@rpc("any_peer", "reliable")
func _server_open_chest(path: NodePath, paid: int) -> void:
	if not multiplayer.is_server():
		return
	var chest := _node(path) as Chest
	if chest == null:
		return
	if chest.opened:
		_refund.rpc_id(multiplayer.get_remote_sender_id(), clampi(paid, 0, chest.cost))
	else:
		chest.open()

@rpc("authority", "reliable")
func _refund(amount: int) -> void:
	if amount > 0 and is_instance_valid(WorldService.local_player):
		WorldService.local_player.add_money(amount)

## Host: opens or closes a chest's lid everywhere.
func set_chest_lid(chest: Chest, open: bool) -> void:
	chest.show_lid(open)
	if P2P.is_online() and P2P.is_host():
		_client_chest_lid.rpc(_path(chest), open)

@rpc("authority", "reliable")
func _client_chest_lid(path: NodePath, open: bool) -> void:
	var chest := _node(path) as Chest
	if chest:
		chest.show_lid(open)

# ---------------------------------------------------------------------------
# Bosses
# ---------------------------------------------------------------------------

## Host: a zone's boss died; every peer marks the zone beaten (and unlocks what it unlocks).
func zone_defeated(zone: SharkZone) -> void:
	if P2P.is_online() and P2P.is_host():
		_client_zone_defeated.rpc(_path(zone))

@rpc("authority", "reliable")
func _client_zone_defeated(path: NodePath) -> void:
	var zone := _node(path) as SharkZone
	if zone:
		zone.defeat()

# ---------------------------------------------------------------------------
# The boat: one driver at a time. Whoever drives simulates it (the host when nobody does) and
# streams its transform; everyone else follows.
# ---------------------------------------------------------------------------

func request_helm(boat: Boat) -> void:
	if P2P.acts_as_host():
		_host_take_helm(_path(boat), P2P.local_peer_id())
	else:
		_server_take_helm.rpc_id(1, _path(boat))

func release_helm(boat: Boat) -> void:
	if P2P.acts_as_host():
		_host_release_helm(_path(boat), P2P.local_peer_id())
	else:
		_server_release_helm.rpc_id(1, _path(boat))

@rpc("any_peer", "reliable")
func _server_take_helm(path: NodePath) -> void:
	if multiplayer.is_server():
		_host_take_helm(path, multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable")
func _server_release_helm(path: NodePath) -> void:
	if multiplayer.is_server():
		_host_release_helm(path, multiplayer.get_remote_sender_id())

func _host_take_helm(path: NodePath, peer_id: int) -> void:
	var boat := _node(path) as Boat
	if boat == null or boat.locked or (boat.driver != 0 and boat.driver != peer_id):
		return
	_set_driver(path, peer_id)

func _host_release_helm(path: NodePath, peer_id: int) -> void:
	var boat := _node(path) as Boat
	if boat and boat.driver == peer_id:
		_set_driver(path, 0)

func _set_driver(path: NodePath, peer_id: int) -> void:
	_client_boat_driver(path, peer_id)
	if P2P.is_online():
		_client_boat_driver.rpc(path, peer_id)

@rpc("authority", "reliable")
func _client_boat_driver(path: NodePath, peer_id: int) -> void:
	var boat := _node(path) as Boat
	if boat:
		boat.set_driver(peer_id)

func _physics_process(delta: float) -> void:
	if not P2P.is_online() or not WorldService.in_world():
		return
	_boat_timer -= delta
	if _boat_timer > 0.0:
		return
	_boat_timer = BOAT_SEND_INTERVAL
	for boat: Boat in get_tree().get_nodes_in_group(&"boats"):
		if boat.is_authority():
			_client_boat_state.rpc(_path(boat), boat.global_transform, boat.linear_velocity)

@rpc("any_peer", "unreliable_ordered")
func _client_boat_state(path: NodePath, xform: Transform3D, velocity: Vector3) -> void:
	var boat := _node(path) as Boat
	if boat and multiplayer.get_remote_sender_id() == boat.authority_peer():
		boat.follow(xform, velocity)

# ---------------------------------------------------------------------------
# Treasure: the gold in the treasure chests. Finding it all unlocks the boat (the way out).
# ---------------------------------------------------------------------------

## How many treasure items there are: everything the treasure chests always drop.
func treasure_total() -> int:
	var total := 0
	if WorldService.in_world():
		for chest: Chest in WorldService.world.find_children("*", "Chest", true, false):
			if chest.treasure and chest.loot:
				total += chest.loot.always.size()
	return total


## Host: a treasure coin was picked up for the first time.
func treasure_picked_up() -> void:
	_set_treasure(treasure_found + 1)
	if P2P.is_online():
		_client_treasure.rpc(treasure_found)

@rpc("authority", "reliable")
func _client_treasure(found: int) -> void:
	_set_treasure(found)

func _set_treasure(found: int) -> void:
	treasure_found = found
	var total := treasure_total()
	treasure_changed.emit(found, total)
	if found >= total and total > 0:
		for boat: Boat in get_tree().get_nodes_in_group(&"boats"):
			boat.locked = false

# ---------------------------------------------------------------------------
# Late join
# ---------------------------------------------------------------------------

func send_state_to(peer_id: int) -> void:
	var chests := []
	for chest: Chest in WorldService.world.find_children("*", "Chest", true, false):
		if chest.opened:
			chests.append(_path(chest))
	var zones := []
	for zone: SharkZone in WorldService.world.find_children("*", "SharkZone", true, false):
		if zone.defeated:
			zones.append(_path(zone))
	var boats := []
	for boat: Boat in get_tree().get_nodes_in_group(&"boats"):
		boats.append([_path(boat), boat.driver, boat.global_transform])
	_client_state.rpc_id(peer_id, chests, zones, boats, treasure_found)

@rpc("authority", "reliable")
func _client_state(chests: Array, zones: Array, boats: Array, found: int) -> void:
	_set_treasure(found)
	for path: NodePath in chests:
		var chest := _node(path) as Chest
		if chest:
			chest.show_lid(true)
	for path: NodePath in zones:
		_client_zone_defeated(path)
	for row: Array in boats:
		var boat := _node(row[0]) as Boat
		if boat:
			boat.set_driver(row[1])
			boat.follow(row[2], Vector3.ZERO, true)
