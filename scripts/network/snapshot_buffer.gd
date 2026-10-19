class_name SnapshotBuffer
extends RefCounted
## Replays a body someone else simulates. Snapshots arrive stamped with the
## sender's physics time and are drawn DELAY in the past, so there are always
## two of them to blend between. Shared by player.gd and vehicle.gd.

## How far in the past the body is drawn. Has to cover a couple of snapshot
## intervals plus network jitter, or it stalls waiting for the next one.
const DELAY := 0.1

## Received [sent_at, ...data], oldest first.
var _snapshots: Array[Array] = []
## Our physics time minus the sender's, averaged over snapshots.
var _clock_offset: float = NAN
## The moment on the sender's clock currently shown.
var _render_time: float = NAN

## Seconds of simulated physics time. Wall-clock time would be wrong here:
## several physics steps often run back to back within one rendered frame.
static func now() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)

## Stores one snapshot. [param data] is whatever the owner blends; it comes back
## from sample() and latest() in the same order.
func push(sent_at: float, data: Array) -> void:
	# Unreliable packets can arrive out of order; an older one would pull the body back.
	if not _snapshots.is_empty() and sent_at <= _snapshots[-1][0]:
		return
	# The two physics clocks started at different moments. Averaging the gap keeps
	# one late packet from shifting the whole timeline.
	var gap := now() - sent_at
	_clock_offset = gap if is_nan(_clock_offset) else lerpf(_clock_offset, gap, 0.05)
	_snapshots.append([sent_at] + data)

## Forgets everything, e.g. when the sender changes and its clock with it.
func clear() -> void:
	_snapshots.clear()
	_clock_offset = NAN
	_render_time = NAN

func is_empty() -> bool:
	return _snapshots.is_empty()

## The newest snapshot, [sent_at, ...data]. Only call when not empty.
func latest() -> Array:
	return _snapshots[-1]

## Advances the shown time by [param delta] and returns [from, to, t]: the two
## snapshots either side of it, each [sent_at, ...data], and how far between
## them it is. Empty when nothing has arrived yet.
func sample(delta: float) -> Array:
	if _snapshots.is_empty():
		return []
	var target := now() - _clock_offset - DELAY
	if is_nan(_render_time) or absf(target - _render_time) > 0.25:
		_render_time = target  # first snapshot, or hopelessly off: jump
	else:
		# The offset estimate wobbles with every packet's delay. Chase it by running
		# the shown time up to 10% fast or slow, so the wobble never shows as speed.
		_render_time += delta * clampf(1.0 + (target - _render_time), 0.9, 1.1)
	while _snapshots.size() > 2 and _snapshots[1][0] <= _render_time:
		_snapshots.pop_front()
	var from: Array = _snapshots[0]
	var to: Array = _snapshots[mini(1, _snapshots.size() - 1)]
	var span: float = to[0] - from[0]
	var t := clampf((_render_time - from[0]) / span, 0.0, 1.0) if span > 0.0 else 1.0
	return [from, to, t]
