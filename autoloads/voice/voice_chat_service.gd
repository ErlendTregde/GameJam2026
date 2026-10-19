extends Node
## Proximity voice chat over Steam Voice.
##
## Captures the microphone via Steam, broadcasts compressed Opus frames to peers
## on RPC channel 2, and routes what comes back into each player's VoicePlayer3D
## for spatialised playback. Players are keyed by seat index.
##
## Voice RPCs need multiplayer_peer/max_channels >= 3 in project.godot — without
## it channel 2 does not exist and voice vanishes with no error. GodotSteam
## registers that setting with a default of 4, so it usually just works.

signal player_talking(seat_index: int, is_talking: bool)

## Compressed bytes to pull per getVoice() poll. Passed explicitly because the
## default differs between GodotSteam builds (0 on older, 1024 on 4.22.x).
const VOICE_CAPTURE_BUFFER := 8192

## Output buffer for decompressVoice(). 20480 bytes = ~213ms at 48kHz mono.
const VOICE_DECOMPRESS_BUFFER := 20480

var _is_recording: bool = false
var _is_muted: bool = false
var _push_to_talk: bool = false
var _ptt_held: bool = false

## seat_index -> VoicePlayer3D
var _voice_players: Dictionary = {}

## seat_index -> playback gain (1.0 = untouched). Kept here rather than on the
## node because bodies are respawned on reconnect, which throws the node away.
var _voice_volumes: Dictionary = {}
var _local_seat_index: int = -1

var _steam = null
var _sample_rate: int = 48000
var _warned_unknown_voice_keys: bool = false

func _ready() -> void:
	_steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if _steam != null and _steam.has_method("getVoiceOptimalSampleRate"):
		var rate: int = _steam.getVoiceOptimalSampleRate()
		if rate > 0:
			_sample_rate = rate
	P2P.player_left_signal.connect(_on_player_left)
	P2P.host_disconnected_signal.connect(stop_voice)
	P2P.connection_failed_signal.connect(stop_voice)

func _process(_delta: float) -> void:
	if not _is_recording or _steam == null or _is_muted:
		return
	if _push_to_talk and not _ptt_held:
		return
	if not _can_broadcast_voice():
		return

	# Poll every frame — Steam internally buffers ~20ms Opus frames, so draining
	# once per frame keeps latency low without extra bookkeeping.
	var voice_data: Dictionary = _steam.getVoice(VOICE_CAPTURE_BUFFER)
	if int(voice_data.get("result", -1)) != 0:
		return
	var written := _captured_byte_count(voice_data)
	if written > 0:
		_broadcast_voice.rpc(voice_data["buffer"].slice(0, written), _local_seat_index)

## GodotSteam renamed getVoice()'s byte-count key from "written" to "size" in
## 4.22. Reading both keeps this working whichever build a player has installed —
## otherwise the mismatch is silent: no error, just no outgoing audio.
func _captured_byte_count(voice_data: Dictionary) -> int:
	if voice_data.has("size"):
		return int(voice_data["size"])
	if voice_data.has("written"):
		return int(voice_data["written"])
	if not _warned_unknown_voice_keys:
		_warned_unknown_voice_keys = true
		push_error("VoiceChatService: getVoice() returned no known byte-count key (got %s). "
			% [voice_data.keys()] + "GodotSteam probably renamed it again — outgoing voice is dead until this is updated.")
	return 0

func _input(event: InputEvent) -> void:
	# This is an autoload, so it sees every key. Without this guard, typing a
	# lobby ID that contains "m" would toggle mute.
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return

	if event.is_action_pressed("voice_toggle_mute"):
		toggle_mute()
	if not _push_to_talk:
		return
	if event.is_action_pressed("voice_push_to_talk"):
		_ptt_held = true
		if not _is_muted and _steam != null:
			_steam.startVoiceRecording()
	elif event.is_action_released("voice_push_to_talk"):
		_ptt_held = false
		if _steam != null:
			_steam.stopVoiceRecording()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func start_voice() -> void:
	if _steam == null:
		push_warning("VoiceChatService: Steam singleton unavailable — voice disabled.")
		return
	# Voice rides RPC channel 2, so anything below 3 channels drops it silently.
	var channels := int(ProjectSettings.get_setting("steam/multiplayer_peer/max_channels", 4))
	if channels < 3:
		push_error("VoiceChatService: steam/multiplayer_peer/max_channels is %d; voice needs at least 3. Voice will not be heard." % channels)
	if not _push_to_talk:
		_steam.startVoiceRecording()
	_is_recording = true

func stop_voice() -> void:
	if _steam != null:
		_steam.stopVoiceRecording()
	_is_recording = false
	_voice_players.clear()
	_local_seat_index = -1

func set_local_seat(seat_index: int) -> void:
	_local_seat_index = seat_index

func register_voice_player(seat_index: int, player: Node) -> void:
	_voice_players[seat_index] = player
	player.set_voice_volume(get_player_volume(seat_index))

func set_player_volume(seat_index: int, gain: float) -> void:
	_voice_volumes[seat_index] = gain
	var player = _voice_players.get(seat_index)
	if player != null and is_instance_valid(player):
		player.set_voice_volume(gain)

func get_player_volume(seat_index: int) -> float:
	return float(_voice_volumes.get(seat_index, 1.0))

func unregister_voice_player(seat_index: int) -> void:
	_voice_players.erase(seat_index)

func set_muted(muted: bool) -> void:
	_is_muted = muted
	if _steam == null:
		return
	if muted:
		_steam.stopVoiceRecording()
	elif _is_recording and not _push_to_talk:
		_steam.startVoiceRecording()

func toggle_mute() -> void:
	set_muted(not _is_muted)

func is_muted() -> bool:
	return _is_muted

func set_push_to_talk(enabled: bool) -> void:
	_push_to_talk = enabled
	if _steam == null or not _is_recording:
		return
	if enabled:
		_steam.stopVoiceRecording()
		_ptt_held = false
	elif not _is_muted:
		_steam.startVoiceRecording()

func is_push_to_talk() -> bool:
	return _push_to_talk

func get_sample_rate() -> int:
	return _sample_rate

func _can_broadcast_voice() -> bool:
	if _local_seat_index < 0 or not multiplayer.has_multiplayer_peer():
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

# ---------------------------------------------------------------------------
# Transport — unreliable_ordered on channel 2 so voice never blocks game state
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _broadcast_voice(compressed_data: PackedByteArray, sender_seat: int) -> void:
	if _steam == null:
		return

	# All three arguments passed explicitly — older builds require sample_rate,
	# and the buffer-size default is not consistent across versions.
	var pcm: Dictionary = _steam.decompressVoice(
		compressed_data, _sample_rate, VOICE_DECOMPRESS_BUFFER)
	if int(pcm.get("result", -1)) != 0 or int(pcm.get("size", 0)) <= 0:
		return

	var player = _voice_players.get(sender_seat)
	if player != null and is_instance_valid(player):
		player.push_audio(pcm["uncompressed"].slice(0, pcm["size"]))
		player_talking.emit(sender_seat, true)

func _on_player_left(_peer_id: int, steam_id: int) -> void:
	var room_state := RoomService.get_room_state()
	if room_state == null:
		return
	var member := room_state.get_member(steam_id)
	if member != null and member.seat_index >= 0:
		unregister_voice_player(member.seat_index)
