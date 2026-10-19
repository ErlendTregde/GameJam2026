# Multiplayer — "Spearfish with me"

Built on the Modbit-Studios MultiplayerTemplate (Steam lobbies, Steam P2P, room snapshot, proximity
voice) with the farm-my-life pattern for gameplay (host-authoritative services, clients send requests).

## Flow
- Main menu: background is the island with Coco on the selling table; Coco's face follows the cursor.
  Buttons: **Host**, **Join** (Steam Lobby ID, or a LAN host's IP), **Play Solo**, **Quit**.
- No lobby or waiting room: hosting opens the island at once; joining loads the island as soon as the
  host's room snapshot arrives. Late join is supported.
- Without Steam (not running) hosting falls back to LAN (ENet, port 24680). LAN also makes
  local two-instance testing possible.
- Esc opens a pause menu (lobby id + copy, invite friend, mute, leave).

## Authority
The host is the only writer of shared world state. Clients send a request RPC; the host validates and
broadcasts. Offline (solo) the local game acts as host, so the singleplayer code path is unchanged.

| Shared (host-owned) | Per player (local) |
|---|---|
| Items lying in the world (spawn, pickup, drop, settle, sell) | Money |
| Fish, crabs, sharks (host simulates; others see puppets) | Hotbar / held item |
| Damage to creatures and palms | Health, oxygen, stamina |
| Shark zones (defeated), boss health, boat lock | Shop purchases |
| Chests (open/loot), the boat (driver simulates) | Coco's lines |

## Players
- Every peer spawns one `Avatar_<seat>` per member under the world root (same path everywhere, as in the
  template). The local seat's avatar is hidden and mirrors the local `Player`, sending
  position/yaw/pitch/held item/`exposed_to_sea` at 20 Hz; remote avatars replay it with `SnapshotBuffer`.
- Avatars are on the player physics layer so shark zones' areas see them.
- Shark bites on a remote avatar are forwarded to its owner, whose `Player` takes the damage. A player
  dying tells the host; a shark whose target died retargets the next player in the zone, else leaves.

## Services (autoloads, so `/root/<Name>` is a valid RPC path everywhere)
- `WorldService` — the live world: local player, player bodies, `hit()` routing, client state request.
- `ItemService` — world items by uid (static items: hash of scene path; spawned: host counter).
- `CreatureService` — fish, crabs, sharks by id; 10 Hz transform batches; harpoon catches.

## Testing
Offline: the existing headless tests. Online: two headless instances over LAN (`tests/net_*.gd`).
Steam lobbies and voice need two Steam accounts and are not covered by automated tests.
