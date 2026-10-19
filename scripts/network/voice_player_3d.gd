extends AudioStreamPlayer3D
class_name VoicePlayer3D

## Per-player 3D voice playback node. Attached as a direct child of a remote player
## body, which must expose set_talking_indicator(bool).
## Receives decompressed PCM audio and pushes it into an AudioStreamGenerator
## for spatialized playback. Includes optional raycast-based occlusion.

var _playback: AudioStreamGeneratorPlayback = null
var _generator: AudioStreamGenerator = null

# Silence / talking detection
var _silence_timer: float = 0.0
var _is_talking: bool = false
const SILENCE_THRESHOLD: float = 0.25  # seconds without data = not talking

# Reusable buffer to avoid per-call allocation
var _frame_buffer: PackedVector2Array = PackedVector2Array()

# Proximity falloff. Godot's inverse-distance model is physically correct and
# wrong for voice: gain is unit_size/distance, so it blows up as you close in and
# loses 6 dB per doubling on the way out — deafening at arm's length, inaudible a
# few metres later. We turn it off and roll off linearly in dB instead: full
# volume out to FULL_VOLUME_RADIUS, then a straight line down to EDGE_VOLUME_DB
# at VOICE_MAX_DISTANCE, where max_distance culls the voice entirely.
const FULL_VOLUME_RADIUS: float = 9.0
const VOICE_MAX_DISTANCE: float = 45.0
const EDGE_VOLUME_DB: float = -26.0

# Noise suppression. Steam ships whatever the microphone hears, so this tracks
# each speaker's own noise floor and fades the signal out as it approaches it —
# an expander, not a fixed gate, so it adapts to the mic instead of needing a
# hand-tuned threshold per player. The floor drops fast and rises slowly, which
# is what makes it settle on the quiet background rather than on speech.
#
# Knobs, in the order worth touching: SNR_SILENT (raise it if background still
# comes through), SNR_CLEAR (lower it if quiet talkers get chopped), GATE_HOLD
# (raise it if word endings are clipped).
const NOISE_FLOOR_MIN: float = 0.002   # never trust a floor estimate below this
const FLOOR_FALL: float = 0.5          # per packet, toward a quieter estimate
const FLOOR_RISE: float = 0.01         # per packet, toward a louder one
const SNR_SILENT: float = 1.5          # at or below the floor's level: silence
const SNR_CLEAR: float = 3.0           # clearly above it: full volume
const GAIN_ATTACK: float = 0.5         # per packet, opening up
const GAIN_RELEASE: float = 0.08       # per packet, closing down
const GATE_HOLD: float = 0.35
var _gate_open_for: float = 0.0
var _noise_floor: float = NOISE_FLOOR_MIN
var _gain: float = 0.0

# Occlusion
var _occlusion_enabled: bool = true
var _occlusion_ray: RayCast3D = null
var _is_occluded: bool = false
const OCCLUDED_VOLUME_REDUCTION: float = 12.0  # dB
const OCCLUDED_FILTER_CUTOFF: float = 2000.0   # Hz (muffled)
const NORMAL_FILTER_CUTOFF: float = 20500.0     # Hz (full range — the bypass value)
const FILTER_SWEEP_HZ_PER_SEC: float = 60000.0  # ~0.3s to open the filter fully
const LERP_SPEED: float = 8.0

var _base_volume_db: float = 0.0

func _ready() -> void:
	# Configure AudioStreamGenerator
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = float(VoiceChatService.get_sample_rate())
	_generator.buffer_length = 0.1  # 100ms — low latency while tolerating jitter
	stream = _generator

	# 3D audio properties for proximity voice. Attenuation is disabled because
	# _physics_process drives volume_db from distance itself; panning still works.
	max_distance = VOICE_MAX_DISTANCE
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	attenuation_filter_cutoff_hz = NORMAL_FILTER_CUTOFF
	attenuation_filter_db = -24.0
	bus = &"Voice"

	_base_volume_db = volume_db

	# Start the stream so we can get the playback reference
	play()
	_playback = get_stream_playback()

	# Setup occlusion raycast
	if _occlusion_enabled:
		_setup_occlusion_ray()

func _process(delta: float) -> void:
	_gate_open_for = maxf(_gate_open_for - delta, 0.0)
	_silence_timer += delta
	if _is_talking and _silence_timer > SILENCE_THRESHOLD:
		_is_talking = false
		var body := get_parent()
		if body != null and body.has_method("set_talking_indicator"):
			body.set_talking_indicator(false)

func _physics_process(delta: float) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_3d()
	if camera == null:
		return

	if _occlusion_enabled and _occlusion_ray != null:
		_occlusion_ray.target_position = _occlusion_ray.to_local(camera.global_position)
		_occlusion_ray.force_raycast_update()
		_is_occluded = _occlusion_ray.is_colliding()

	# Lerp volume and filter for smooth transitions
	var target_vol := _base_volume_db + distance_db(global_position.distance_to(camera.global_position))
	if _is_occluded:
		target_vol -= OCCLUDED_VOLUME_REDUCTION
	var target_cutoff := OCCLUDED_FILTER_CUTOFF if _is_occluded else NORMAL_FILTER_CUTOFF
	volume_db = lerpf(volume_db, target_vol, delta * LERP_SPEED)
	# move_toward, not lerp: the filter is only bypassed at exactly 20500 Hz, and
	# a lerp approaches it forever without arriving — leaving every voice slightly
	# low-passed even with nothing in the way.
	attenuation_filter_cutoff_hz = move_toward(
		attenuation_filter_cutoff_hz, target_cutoff, FILTER_SWEEP_HZ_PER_SEC * delta)

## Flat inside FULL_VOLUME_RADIUS, then a straight dB ramp to EDGE_VOLUME_DB at
## VOICE_MAX_DISTANCE. Linear in dB is roughly linear in perceived loudness, which
## is what keeps a distant player quiet but still intelligible.
static func distance_db(distance: float) -> float:
	var span := maxf(VOICE_MAX_DISTANCE - FULL_VOLUME_RADIUS, 0.001)
	var t := clampf((distance - FULL_VOLUME_RADIUS) / span, 0.0, 1.0)
	return lerpf(0.0, EDGE_VOLUME_DB, t)

## Per-listener volume, 1.0 = unchanged. Occlusion lerps toward this, so it has
## to go through _base_volume_db rather than volume_db alone.
func set_voice_volume(gain: float) -> void:
	_base_volume_db = linear_to_db(maxf(gain, 0.0001))

## Tracks the speaker's noise floor and returns how much of this packet to keep:
## 0.0 at the floor, 1.0 once the packet is clearly above it, fading in between so
## quiet speech is attenuated instead of chopped off.
func _suppression_gain(rms: float) -> float:
	if rms < _noise_floor:
		_noise_floor = maxf(lerpf(_noise_floor, rms, FLOOR_FALL), NOISE_FLOOR_MIN)
	else:
		_noise_floor = maxf(lerpf(_noise_floor, rms, FLOOR_RISE), NOISE_FLOOR_MIN)
	var snr := rms / _noise_floor
	return clampf((snr - SNR_SILENT) / (SNR_CLEAR - SNR_SILENT), 0.0, 1.0)

## Push decompressed PCM audio data into the generator playback buffer.
## [param pcm_data] is a PackedByteArray of 16-bit signed mono PCM samples.
func push_audio(pcm_data: PackedByteArray) -> void:
	if _playback == null:
		return

	@warning_ignore("integer_division")  # 16-bit mono: 2 bytes per sample, exactly
	var frame_count: int = pcm_data.size() / 2
	if frame_count == 0:
		return

	# Clamp to available buffer space to avoid overrun
	var available: int = _playback.get_frames_available()
	if available <= 0:
		return
	if frame_count > available:
		frame_count = available

	# Build the entire frame buffer at once, then push in one call.
	# This is dramatically faster than pushing one frame at a time in GDScript.
	# The loop also sums the energy, so the gate costs one sqrt per packet.
	_frame_buffer.resize(frame_count)
	var sum_squares: float = 0.0
	for i in frame_count:
		var sample: float = pcm_data.decode_s16(i * 2) / 32768.0
		_frame_buffer[i] = Vector2(sample, sample)
		sum_squares += sample * sample

	var target_gain := _suppression_gain(sqrt(sum_squares / frame_count))
	if target_gain > 0.0:
		_gate_open_for = GATE_HOLD
	elif _gate_open_for <= 0.0 and _gain <= 0.0:
		return  # background noise, and nobody was speaking — drop it

	# Ramp rather than switch: a hard cut on a gain change clicks.
	_gain = move_toward(_gain, target_gain, GAIN_ATTACK if target_gain > _gain else GAIN_RELEASE)
	if _gain < 0.999:
		for i in frame_count:
			_frame_buffer[i] *= _gain

	_playback.push_buffer(_frame_buffer)

	# Update talking state
	if not _is_talking:
		_is_talking = true
		var body := get_parent()
		if body != null and body.has_method("set_talking_indicator"):
			body.set_talking_indicator(true)
	_silence_timer = 0.0

func _setup_occlusion_ray() -> void:
	_occlusion_ray = RayCast3D.new()
	_occlusion_ray.name = "OcclusionRay"
	# Layer 1 is the world. Players sit on layer 2 so they do not occlude each
	# other — the local body wraps the camera, so a player-hitting ray reports
	# occlusion permanently and every voice comes through muffled.
	_occlusion_ray.collision_mask = 1
	_occlusion_ray.enabled = true
	add_child(_occlusion_ray)
