extends Node
## The live world, as the gameplay services see it: the local player, every player body (local
## Player + remote avatars), and the one route all damage takes. An autoload, so /root/WorldService
## is a valid RPC path on every peer from startup (peers change scene independently).
##
## Hits: whoever hits something calls hit(). On the host (or offline) the target takes the damage
## right away; on a client the hit flashes locally for instant feedback and goes to the host, which
## applies it to its copy (fish, crabs, sharks and palms are simulated there).

## The world finished loading on this peer (its services can place their nodes now).
signal world_entered(world: Node3D)
signal world_left
## A player died (the local Player, or another player's avatar when its owner says so).
signal player_died(body: Node3D)

var world: Node3D = null
var local_player: Player = null

func world_ready(new_world: Node3D, player: Player) -> void:
	world = new_world
	local_player = player
	player.died.connect(func() -> void:
		player_died.emit(player)
		if P2P.is_online():
			var avatar := own_avatar()
			if avatar:
				avatar.announce_death())
	world_entered.emit(world)
	if P2P.is_online() and not P2P.is_host():
		_server_request_world_state.rpc_id(1)
	if P2P.is_online() and not P2P.is_lan():
		VoiceChatService.start_voice()

func world_exiting() -> void:
	world = null
	local_player = null
	VoiceChatService.stop_voice()
	world_left.emit()

func in_world() -> bool:
	return world != null and is_instance_valid(world)

## Every player in the world: the local Player and the other players' avatars.
func player_bodies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not in_world():
		return out
	if is_instance_valid(local_player):
		out.append(local_player)
	for avatar in get_tree().get_nodes_in_group(&"remote_avatars"):
		out.append(avatar)
	return out

## The player closest to [param pos] (horizontally), or null.
func nearest_player(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for body in player_bodies():
		var d := Vector2(body.global_position.x - pos.x, body.global_position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = body
	return best

## Our own avatar (hidden; it carries our state to the others), or null when offline.
func own_avatar() -> Node3D:
	for avatar in get_tree().get_nodes_in_group(&"avatars"):
		if avatar.is_local:
			return avatar
	return null


## The body of the player with [param peer_id] (the local Player for our own id).
func body_of_peer(peer_id: int) -> Node3D:
	if peer_id == P2P.local_peer_id():
		return local_player
	for avatar in get_tree().get_nodes_in_group(&"remote_avatars"):
		if avatar.peer_id == peer_id:
			return avatar
	return null

# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

## Damages [param target] (anything with take_damage). [param harpoon]: a speargun spear did it,
## so a creature it kills is caught by the shooter instead of dropping.
func hit(target: Node, amount: float, at: Vector3, harpoon := false) -> void:
	if not is_instance_valid(target):
		return
	if P2P.acts_as_host():
		_apply_hit(target, amount, at, P2P.local_peer_id() if harpoon else 0)
		return
	var model := target.get_node_or_null("Model") as Node3D
	if model:
		HitFlash.flash(model)
	if in_world() and world.is_ancestor_of(target):
		_server_hit.rpc_id(1, world.get_path_to(target), amount, at, harpoon)

func _apply_hit(target: Node, amount: float, at: Vector3, catcher_peer: int) -> void:
	if catcher_peer != 0 and "caught_by" in target:
		target.caught_by = catcher_peer
	target.take_damage(amount, at)

@rpc("any_peer", "reliable")
func _server_hit(path: NodePath, amount: float, at: Vector3, harpoon: bool) -> void:
	if not multiplayer.is_server() or not in_world():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not SteamState.lobby_data.peer_members.has(sender) or not is_finite(amount):
		return
	var target := world.get_node_or_null(path)
	if target and target.has_method("take_damage"):
		_apply_hit(target, clampf(amount, 0.0, 100.0), at, sender if harpoon else 0)

# ---------------------------------------------------------------------------
# Late join: a client entering the world asks the host for everything that already happened.
# ---------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _server_request_world_state() -> void:
	if not multiplayer.is_server() or not in_world():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	ItemService.send_state_to(peer_id)
	CreatureService.send_state_to(peer_id)
	WorldEvents.send_state_to(peer_id)
