extends RefCounted
class_name RoomState
## The full replicated state of a room: who is in it, which seat they hold, and
## what phase the room is in. The host owns the authoritative copy and broadcasts
## it as a dictionary; clients rebuild theirs with from_dict().

## Bumped whenever the dict schema changes so from_dict() can flag stale snapshots.
const SCHEMA_VERSION := 3

## Raising this is the main knob for a bigger session. Remember to add a matching
## colour below; everyone spawns on the same point, so there is nothing else.
const MAX_PLAYERS := 4

## Canonical phase values. Compare with get_phase(), not raw strings.
enum RoomPhase { IDLE, CONNECTING, LOBBY, IN_GAME }

## One colour per seat, used to tint player capsules and the lobby list.
const SEAT_COLORS: Array[Color] = [
	Color(0.2, 0.7, 0.2),
	Color(0.7, 0.2, 0.2),
	Color(0.2, 0.4, 0.8),
	Color(0.8, 0.7, 0.2),
]

var lobby_id: int = 0
var room_name: String = ""
var host_steam_id: int = 0
var phase_name: String = "IDLE"
var game_active: bool = false
## Picked by the host when the room is created, so every peer generates the same world.
var world_seed: int = 0
## The in-game clock read time_of_day_hour at the host's unix time
## time_of_day_set_at. Every peer runs it forward from that pair, so the sun
## matches everywhere without sending the time every frame.
var time_of_day_hour: float = 8.0
var time_of_day_set_at: float = 0.0
var members_by_steam_id: Dictionary = {}

func reset() -> void:
	lobby_id = 0
	room_name = ""
	host_steam_id = 0
	phase_name = "IDLE"
	game_active = false
	world_seed = 0
	time_of_day_hour = 8.0
	time_of_day_set_at = 0.0
	members_by_steam_id.clear()

func get_phase() -> RoomPhase:
	match phase_name:
		"CONNECTING": return RoomPhase.CONNECTING
		"LOBBY": return RoomPhase.LOBBY
		"IN_GAME": return RoomPhase.IN_GAME
		_: return RoomPhase.IDLE

static func seat_color(seat_index: int) -> Color:
	if seat_index < 0 or seat_index >= SEAT_COLORS.size():
		return Color(0.8, 0.8, 0.8)
	return SEAT_COLORS[seat_index]

func get_member(steam_id: int) -> RoomMemberState:
	return members_by_steam_id.get(steam_id, null)

## Seats are derived from members rather than stored separately — one source of
## truth, nothing to keep in sync.
func get_member_at_seat(seat_index: int) -> RoomMemberState:
	if seat_index < 0:
		return null
	for member in members_by_steam_id.values():
		if member.seat_index == seat_index:
			return member
	return null

func is_seat_occupied(seat_index: int) -> bool:
	return get_member_at_seat(seat_index) != null

func get_local_seat_index(local_steam_id: int) -> int:
	var member := get_member(local_steam_id)
	return member.seat_index if member != null else -1

func get_seated_member_count() -> int:
	var count := 0
	for member in members_by_steam_id.values():
		if member.seat_index >= 0:
			count += 1
	return count

func get_ready_count() -> int:
	var count := 0
	for member in members_by_steam_id.values():
		if member.seat_index >= 0 and member.is_ready:
			count += 1
	return count

func clear_ready_states() -> void:
	for member in members_by_steam_id.values():
		member.is_ready = false

func can_start_game() -> bool:
	var seated := get_seated_member_count()
	if seated < 1 or seated > MAX_PLAYERS:
		return false
	return get_ready_count() == seated

func to_dict() -> Dictionary:
	var members: Dictionary = {}
	for steam_id in members_by_steam_id:
		members[steam_id] = members_by_steam_id[steam_id].to_dict()
	return {
		"v": SCHEMA_VERSION,
		"lobby_id": lobby_id,
		"room_name": room_name,
		"host_steam_id": host_steam_id,
		"phase_name": phase_name,
		"game_active": game_active,
		"world_seed": world_seed,
		"time_of_day_hour": time_of_day_hour,
		"time_of_day_set_at": time_of_day_set_at,
		"members_by_steam_id": members,
	}

static func from_dict(data: Dictionary) -> RoomState:
	var incoming := int(data.get("v", 0))
	if incoming != SCHEMA_VERSION:
		push_warning("RoomState schema mismatch: got v%d, expected v%d — snapshot may be stale" % [
			incoming, SCHEMA_VERSION])
	var state := RoomState.new()
	state.lobby_id = int(data.get("lobby_id", 0))
	state.room_name = String(data.get("room_name", ""))
	state.host_steam_id = int(data.get("host_steam_id", 0))
	state.phase_name = String(data.get("phase_name", "IDLE"))
	state.game_active = bool(data.get("game_active", false))
	state.world_seed = int(data.get("world_seed", 0))
	state.time_of_day_hour = float(data.get("time_of_day_hour", 8.0))
	state.time_of_day_set_at = float(data.get("time_of_day_set_at", 0.0))
	var members: Dictionary = data.get("members_by_steam_id", {})
	for steam_id in members:
		state.members_by_steam_id[int(steam_id)] = RoomMemberState.from_dict(members[steam_id])
	return state
