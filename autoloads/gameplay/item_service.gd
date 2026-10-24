extends Node
## Host-authoritative world items: everything lying around that can be picked up (rocks, shells,
## catch, coconuts, chest loot, dropped items). The farm-my-life InventoryService pattern: the host
## owns which items exist; clients send requests and apply what the host broadcasts. Hotbars stay
## per player (each player's own), only the world copy of an item is shared.
##
## Ids: items placed in the scene (or by a seeded Scatter) are the same on every peer, so their id is
## a hash of their path; items spawned during play get the next id from the host.

## Spawned ids start above any path hash collision worry and above each other.
const FIRST_SPAWNED_UID := 1 << 40

var _items: Dictionary = {}  # uid -> WorldItem on this peer
var _removed_static: Dictionary = {}  # host: uids of scene items that are gone (for late joiners)
var _next_uid := FIRST_SPAWNED_UID

func _ready() -> void:
	WorldService.world_left.connect(func() -> void:
		_items.clear()
		_removed_static.clear())

# ---------------------------------------------------------------------------
# Registry (WorldItem calls these)
# ---------------------------------------------------------------------------

func register(item: WorldItem) -> void:
	if item.uid == 0:
		item.uid = static_uid(item)
	_items[item.uid] = item

func unregister(item: WorldItem) -> void:
	if _items.get(item.uid) == item:
		_items.erase(item.uid)

## Same on every peer for an item that is part of the scene: the world is /root/Main everywhere.
func static_uid(item: Node) -> int:
	return absi(str(item.get_path()).hash()) + 1

func find(uid: int) -> WorldItem:
	var item: WorldItem = _items.get(uid)
	return item if is_instance_valid(item) else null

# ---------------------------------------------------------------------------
# Spawning and removing
# ---------------------------------------------------------------------------

## Puts an item into the world for everyone. Returns it on the host (or offline), null on a client,
## where the host's broadcast creates it a moment later.
func spawn(item: ItemData, weight: float, pos: Vector3, velocity := Vector3.ZERO) -> WorldItem:
	if not P2P.acts_as_host():
		_server_spawn.rpc_id(1, item.resource_path, weight, pos, velocity)
		return null
	var uid := _next_uid
	_next_uid += 1
	var node := _create(uid, item.resource_path, weight, pos, velocity)
	if P2P.is_online():
		_client_spawn.rpc(uid, item.resource_path, weight, pos, velocity)
	return node

## Removes an item for everyone (sold, eaten by a spear...). Host only.
func remove(item: WorldItem) -> void:
	if not is_instance_valid(item) or not P2P.acts_as_host():
		return
	_destroy(item.uid)
	if P2P.is_online():
		_client_remove.rpc(item.uid)

func _create(uid: int, path: String, weight: float, pos: Vector3, velocity: Vector3) -> WorldItem:
	var data := load(path) as ItemData
	if data == null or not WorldService.in_world():
		return null
	var node: WorldItem = load(data.scene_path).instantiate()
	node.uid = uid
	node.weight = weight
	WorldService.world.add_child(node)
	node.global_position = pos
	node.linear_velocity = velocity
	return node

func _destroy(uid: int) -> void:
	var item := find(uid)
	if item == null:
		return
	if uid < FIRST_SPAWNED_UID:
		_removed_static[uid] = true
	_items.erase(uid)
	item.queue_free()

@rpc("any_peer", "reliable")
func _server_spawn(path: String, weight: float, pos: Vector3, velocity: Vector3) -> void:
	if not multiplayer.is_server() or not path.begins_with("res://items/"):
		return
	var data := load(path) as ItemData
	if data:
		spawn(data, weight, pos, velocity)

@rpc("authority", "reliable")
func _client_spawn(uid: int, path: String, weight: float, pos: Vector3, velocity: Vector3) -> void:
	if find(uid) == null:
		_create(uid, path, weight, pos, velocity)

@rpc("authority", "reliable")
func _client_remove(uid: int) -> void:
	_destroy(uid)

# ---------------------------------------------------------------------------
# Pickup: the host decides who gets it (two players pressing E on the same fish)
# ---------------------------------------------------------------------------

## The local player wants [param item]; it lands in their hotbar if the host still has it.
func request_pickup(item: WorldItem) -> void:
	if P2P.acts_as_host():
		_host_pickup(item.uid, P2P.local_peer_id())
	else:
		_server_pickup.rpc_id(1, item.uid)

@rpc("any_peer", "reliable")
func _server_pickup(uid: int) -> void:
	if multiplayer.is_server():
		_host_pickup(uid, multiplayer.get_remote_sender_id())

func _host_pickup(uid: int, peer_id: int) -> void:
	var item := find(uid)
	if item == null or item.is_queued_for_deletion():
		return
	var path := item.item.resource_path
	var weight := item.weight
	if item.has_meta(&"treasure"):
		WorldEvents.treasure_picked_up()
	remove(item)
	if peer_id == P2P.local_peer_id():
		_grant(path, weight)
	else:
		_grant.rpc_id(peer_id, path, weight)

@rpc("authority", "reliable")
func _grant(path: String, weight: float) -> void:
	var data := load(path) as ItemData
	if data and is_instance_valid(WorldService.local_player):
		WorldService.local_player.give(data, weight)

# ---------------------------------------------------------------------------
# Selling at a table: the host counts what is on its copy of the table and pays the seller
# ---------------------------------------------------------------------------

func request_sell(table: SellScale) -> void:
	var path := WorldService.world.get_path_to(table)
	if P2P.acts_as_host():
		_host_sell(path, P2P.local_peer_id())
	else:
		_server_sell.rpc_id(1, path)

@rpc("any_peer", "reliable")
func _server_sell(path: NodePath) -> void:
	if multiplayer.is_server():
		_host_sell(path, multiplayer.get_remote_sender_id())

func _host_sell(path: NodePath, peer_id: int) -> void:
	var table := WorldService.world.get_node_or_null(path) as SellScale if WorldService.in_world() else null
	if table == null:
		return
	var sale := table.take_all()
	if sale[0] <= 0:
		return
	for item: WorldItem in sale[2]:
		remove(item)
	if peer_id == P2P.local_peer_id():
		_paid(path, sale[0], sale[1])
	else:
		_paid.rpc_id(peer_id, path, sale[0], sale[1])

@rpc("authority", "reliable")
func _paid(path: NodePath, amount: int, big: bool) -> void:
	if not WorldService.in_world():
		return
	var table := WorldService.world.get_node_or_null(path) as SellScale
	if table and is_instance_valid(WorldService.local_player):
		table.pay(WorldService.local_player, amount, big)

# ---------------------------------------------------------------------------
# Landing: physics differs a little between peers, so the host's resting spot wins
# ---------------------------------------------------------------------------

## A host item came to rest (WorldItem calls this).
func settled(item: WorldItem) -> void:
	if P2P.is_online() and P2P.is_host():
		_client_settle.rpc(item.uid, item.global_transform)

@rpc("authority", "reliable")
func _client_settle(uid: int, xform: Transform3D) -> void:
	var item := find(uid)
	if item:
		item.rest_at(xform)

# ---------------------------------------------------------------------------
# Late join
# ---------------------------------------------------------------------------

func send_state_to(peer_id: int) -> void:
	var spawned := []
	for uid: int in _items:
		var item := find(uid)
		if item and uid >= FIRST_SPAWNED_UID:
			spawned.append([uid, item.item.resource_path, item.weight, item.global_transform])
	_client_state.rpc_id(peer_id, _removed_static.keys(), spawned)

@rpc("authority", "reliable")
func _client_state(removed: Array, spawned: Array) -> void:
	for uid: int in removed:
		_destroy(uid)
	for row: Array in spawned:
		if find(row[0]) == null:
			var item := _create(row[0], row[1], row[2], (row[3] as Transform3D).origin, Vector3.ZERO)
			if item:
				item.rest_at(row[3])
