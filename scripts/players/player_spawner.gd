extends Node3D
## Spawns one Avatar per seated player and keeps them reconciled against the room state, as the
## MultiplayerTemplate's spawner does: every peer builds the same bodies from the same replicated
## snapshot and names them "Avatar_<seat>", so RPCs on them resolve identically everywhere. They
## go into this node's parent (the world root), so those paths stay short and fixed.
##
## The local player is the world's Player node; when this peer is seated, it is moved here (side by
## side by seat) the first time. Everyone spawns at this node: move it to move the spawn.

const AVATAR_SCENE := preload("res://scenes/players/avatar.tscn")
## Players stand this far apart at the spawn (m), side by side.
@export var spacing := 1.5

var _placed_local := false


func _ready() -> void:
	RoomService.room_state_changed.connect(sync_bodies)
	sync_bodies.call_deferred()


func sync_bodies() -> void:
	if not is_inside_tree():
		return
	var room_state := RoomService.get_room_state()
	for seat in RoomState.MAX_PLAYERS:
		var member := room_state.get_member_at_seat(seat) if room_state else null
		var body: Node = get_parent().get_node_or_null("Avatar_%d" % seat)
		# A reconnecting player keeps their seat but gets a new peer_id; the old body would freeze.
		if body != null and (member == null or body.peer_id != member.peer_id):
			VoiceChatService.unregister_voice_player(seat)
			get_parent().remove_child(body)  # out of the tree now, so the new one gets the name
			body.queue_free()
			body = null
		if member == null or body != null:
			continue
		_spawn_body(seat, member)


func _spawn_body(seat: int, member: RoomMemberState) -> void:
	var body: Avatar = AVATAR_SCENE.instantiate()
	body.name = "Avatar_%d" % seat
	get_parent().add_child(body)
	body.setup(seat, member.peer_id, member.steam_id, member.display_name, member.color, member.is_local)
	body.global_position = _spawn_point(seat)
	if member.is_local:
		VoiceChatService.set_local_seat(seat)
		if not _placed_local and is_instance_valid(WorldService.local_player):
			_placed_local = true
			WorldService.local_player.global_position = _spawn_point(seat)
		return
	var voice := VoicePlayer3D.new()
	voice.position = Vector3(0, 1.6, 0)
	body.add_child(voice)
	VoiceChatService.register_voice_player(seat, voice)


func _spawn_point(seat: int) -> Vector3:
	return global_position + global_basis.x * spacing * (seat - (RoomState.MAX_PLAYERS - 1) * 0.5)
