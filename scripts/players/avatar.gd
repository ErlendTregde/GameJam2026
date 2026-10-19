class_name Avatar
extends CharacterBody3D
## A player's body as the others see it: a diver in their seat colour with their name and the
## item in their hand. Every peer has one per seated player, named "Avatar_<seat>" under the
## world, so RPCs on it resolve everywhere (the MultiplayerTemplate's player-body contract).
##
## Our own avatar is hidden: it mirrors the local Player and sends its state to the others at
## 20 Hz. The others replay those snapshots slightly in the past (SnapshotBuffer), so there are
## always two to blend between. On the host, sharks hunt avatars like the local Player: a bite is
## forwarded to the avatar's owner, and an owner's death is announced to everyone.

const SYNC_INTERVAL := 1.0 / 20.0

var seat_index := -1
var peer_id := 0
var steam_id := 0
var is_local := false
## Swimming (or about to be): shark zones read it, like Player.exposed_to_sea.
var exposed_to_sea := false

var _remote := SnapshotBuffer.new()
var _sync_timer := 0.0
var _held_path := ""

@onready var _head: Node3D = $Head
@onready var _hand: Node3D = $Head/Hand
@onready var _name_label: Label3D = $NameLabel
@onready var _talk: MeshInstance3D = $TalkIndicator


func setup(seat: int, p_peer_id: int, p_steam_id: int, display_name: String, color: Color, local: bool) -> void:
	seat_index = seat
	peer_id = p_peer_id
	steam_id = p_steam_id
	is_local = local
	add_to_group(&"avatars")
	_name_label.text = display_name
	var suit := StandardMaterial3D.new()
	suit.albedo_color = color
	($Body as MeshInstance3D).material_override = suit
	if is_local:
		visible = false
		collision_layer = 0  # the local Player is the one shark zones see
	else:
		add_to_group(&"remote_avatars")


func _physics_process(delta: float) -> void:
	if is_local:
		_send(delta)
	else:
		_follow(delta)


func _send(delta: float) -> void:
	var player := WorldService.local_player
	if not is_instance_valid(player):
		return
	global_position = player.global_position
	rotation.y = player.global_rotation.y
	if not P2P.is_online():
		return
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_INTERVAL
		sync_state.rpc(SnapshotBuffer.now(), player.global_position, player.global_rotation.y, player.look_pitch(), player.exposed_to_sea)
	var held := player.held_item().resource_path if player.held_item() else ""
	if held != _held_path:
		_held_path = held
		set_held.rpc(held)


## Places a remote body where its owner was SnapshotBuffer.DELAY ago.
func _follow(delta: float) -> void:
	var sample := _remote.sample(delta)
	if sample.is_empty():
		return
	var from: Array = sample[0]
	var to: Array = sample[1]
	var t: float = sample[2]
	global_position = (from[1] as Vector3).lerp(to[1], t)
	rotation.y = lerp_angle(from[2], to[2], t)
	_head.rotation.x = lerpf(from[3], to[3], t)
	exposed_to_sea = to[4]


@rpc("any_peer", "unreliable")
func sync_state(sent_at: float, pos: Vector3, yaw: float, pitch: float, exposed: bool) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return  # a peer may only move its own body
	_remote.push(sent_at, [pos, yaw, pitch, exposed])


## Shows the held item in the avatar's hand ("" = empty hand).
@rpc("any_peer", "reliable")
func set_held(path: String) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_held_path = path
	for child in _hand.get_children():
		child.queue_free()
	var item := load(path) as ItemData if path.begins_with("res://items/") else null
	if item == null:
		return
	var model := item.make_model()
	_hand.add_child(model)
	var bounds := ItemData.model_bounds(model)
	model.scale = Vector3.ONE * minf(item.held_size, 0.9) / maxf(bounds.get_longest_axis_size(), 0.01)
	model.position = -(model.basis * bounds.get_center())


## A shark bit this player (called on the host): the owner's Player takes the damage.
func take_damage(amount: float, at := Vector3.ZERO) -> void:
	if is_local:
		WorldService.local_player.take_damage(amount, at)
	else:
		_hurt.rpc_id(peer_id, amount)


@rpc("authority", "reliable")
func _hurt(amount: float) -> void:
	if is_instance_valid(WorldService.local_player):
		WorldService.local_player.take_damage(amount)


## Our own avatar: tells everyone this player died (the host's sharks look for their next target).
func announce_death() -> void:
	_died.rpc()


@rpc("any_peer", "reliable")
func _died() -> void:
	if multiplayer.get_remote_sender_id() == peer_id:
		WorldService.player_died.emit(self)


## Called by VoicePlayer3D while this player talks.
func set_talking_indicator(talking: bool) -> void:
	_talk.visible = talking
