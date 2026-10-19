extends Node
## Fish, crabs and sharks in multiplayer. The host simulates every creature (spawners, swimming,
## hunting, dying); clients show puppets: copies with the same name under the same parent, moved
## to the host's positions (10 Hz, smoothed). A client's hit on a puppet goes to the host through
## WorldService.hit(), and the same node path finds the host's real creature.
##
## Offline nothing here does anything: the creatures run as they always have.

const SEND_INTERVAL := 0.1
## How fast puppets catch up with the latest position (higher = snappier).
const FOLLOW := 10.0

var _creatures: Dictionary = {}  # id -> creature node (host: real ones, client: puppets)
var _targets: Dictionary = {}  # client: id -> [position, rotation]
var _next_id := 1
var _send_timer := 0.0

func _ready() -> void:
	WorldService.world_left.connect(func() -> void:
		_creatures.clear()
		_targets.clear())

## Whether creature logic runs here (host or offline). Creatures and spawners check this.
func simulates() -> bool:
	return P2P.acts_as_host()

# ---------------------------------------------------------------------------
# Host: creatures report in (from their _ready) and out (_exit_tree)
# ---------------------------------------------------------------------------

func register(creature: Node3D) -> void:
	if not P2P.is_online() or not P2P.is_host():
		return
	var id := _next_id
	_next_id += 1
	creature.set_meta(&"net_id", id)
	_creatures[id] = creature
	_client_spawn.rpc(_spawn_row(id, creature))

func unregister(creature: Node3D) -> void:
	if not creature.has_meta(&"net_id"):
		return
	var id: int = creature.get_meta(&"net_id")
	if _creatures.get(id) != creature:
		return
	_creatures.erase(id)
	if P2P.is_online() and P2P.is_host():
		_client_despawn.rpc(id)

func _spawn_row(id: int, creature: Node3D) -> Array:
	var parent := WorldService.world.get_path_to(creature.get_parent()) if WorldService.in_world() else NodePath()
	return [id, creature.scene_file_path, parent, String(creature.name), creature.global_transform,
			float(creature.get("weight")) if "weight" in creature else 0.0]

func _physics_process(delta: float) -> void:
	if not P2P.is_online():
		return
	if P2P.is_host():
		_send_timer -= delta
		if _send_timer <= 0.0 and not _creatures.is_empty():
			_send_timer = SEND_INTERVAL
			_client_states.rpc(_states())
		return
	for id: int in _targets:
		var puppet: Node3D = _creatures.get(id)
		if not is_instance_valid(puppet):
			continue
		var target: Array = _targets[id]
		var k := minf(FOLLOW * delta, 1.0)
		puppet.global_position = puppet.global_position.lerp(target[0], k)
		puppet.quaternion = puppet.quaternion.slerp(target[1], k)

## Positions, plus a shark's health and mood (for the boss bar everyone sees).
func _states() -> Dictionary:
	var out := {}
	for id: int in _creatures:
		var c: Node3D = _creatures[id]
		if not is_instance_valid(c):
			continue
		var row := [c.global_position, c.global_basis.get_rotation_quaternion()]
		if c is Shark:
			row.append_array([c.health, c.is_leaving(), c.is_dead()])
		out[id] = row
	return out

# ---------------------------------------------------------------------------
# Client: puppets
# ---------------------------------------------------------------------------

@rpc("authority", "reliable")
func _client_spawn(row: Array) -> void:
	var id: int = row[0]
	if _creatures.has(id) or not WorldService.in_world():
		return
	var parent := WorldService.world.get_node_or_null(row[2])
	if parent == null or not ResourceLoader.exists(row[1]):
		return
	var puppet: Node3D = load(row[1]).instantiate()
	puppet.name = row[3]
	puppet.set_meta(&"net_id", id)
	if "weight" in puppet:
		puppet.weight = row[5]
	_creatures[id] = puppet
	parent.add_child(puppet)
	puppet.global_transform = row[4]
	_targets[id] = [puppet.global_position, puppet.quaternion]

@rpc("authority", "reliable")
func _client_despawn(id: int) -> void:
	var puppet: Node3D = _creatures.get(id)
	_creatures.erase(id)
	_targets.erase(id)
	if is_instance_valid(puppet):
		puppet.queue_free()

@rpc("authority", "unreliable_ordered")
func _client_states(states: Dictionary) -> void:
	for id: int in states:
		var row: Array = states[id]
		var puppet: Node3D = _creatures.get(id)
		if not is_instance_valid(puppet):
			continue
		_targets[id] = [row[0], row[1]]
		if puppet is Shark and row.size() >= 5:
			puppet.mirror(row[2], row[3], row[4])

## A creature was hit on the host: flash it everywhere (the hitter already saw it).
func flashed(creature: Node3D) -> void:
	if P2P.is_online() and P2P.is_host() and creature.has_meta(&"net_id"):
		_client_flash.rpc(creature.get_meta(&"net_id"))

@rpc("authority", "unreliable")
func _client_flash(id: int) -> void:
	var puppet: Node3D = _creatures.get(id)
	if is_instance_valid(puppet) and puppet.has_node("Model"):
		HitFlash.flash(puppet.get_node("Model"))

# ---------------------------------------------------------------------------
# Speargun catches: the host tells the shooter what their spear killed
# ---------------------------------------------------------------------------

func deliver_catch(peer_id: int, item: ItemData, weight: float) -> void:
	if peer_id == P2P.local_peer_id():
		_catch(item.resource_path, weight)
	else:
		_catch.rpc_id(peer_id, item.resource_path, weight)

@rpc("authority", "reliable")
func _catch(path: String, weight: float) -> void:
	var item := load(path) as ItemData
	if item and is_instance_valid(WorldService.local_player):
		WorldService.local_player.get_node("Combat").receive_catch(item, weight)

# ---------------------------------------------------------------------------
# Late join
# ---------------------------------------------------------------------------

func send_state_to(peer_id: int) -> void:
	for id: int in _creatures:
		var c: Node3D = _creatures[id]
		if is_instance_valid(c):
			_client_spawn.rpc_id(peer_id, _spawn_row(id, c))
