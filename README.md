# Spearfish with me

A co-op spearfishing game for the "Hold your breath" game jam (Godot 4.7). Catch fish and crabs,
sell them to Coco, buy better weapons and swim gear (goggles, flippers) to dive deeper, and find
the chest at the bottom of the blue hole. Sharks patrol the deep water; beating them is
optional. The ground is a Terrain3D: sculpt it in the editor.

## Playing together

- **Host**: with Steam running, makes a friends-only Steam room and puts you straight on the island.
  Open the pause menu (**Esc**) to copy the Lobby ID or **Invite friend**.
  Without Steam, Host makes a LAN game instead.
- **Join**: paste the host's Lobby ID (Steam) or type the host's IP address (LAN), then **Join**.
  Accepting a Steam invite also joins. There is no lobby: you land on the island right away,
  even in the middle of a game.
- **Play solo**: no network at all.

Everyone shares the world (fish, crabs, sharks, items on the ground, chests, the boat, beaten
bosses); money, hotbars and worn gear are your own. When a shark kills a player it goes after the next player
nearby, or back to its patrol. Voice chat is proximity voice over Steam (**M** mutes, **V** push-to-talk if enabled).

Steam App ID is 480 (Valve's test app) in Project Settings → `steam/initialization/app_data/app_id`;
use your own before releasing.

## How the multiplayer is built

From the [Modbit-Studios MultiplayerTemplate](https://github.com/Modbit-Studios/MultiplayerTemplate)
(autoloads `AppFlow`, `SteamState`, `P2P`, `SteamManager`, `RoomService`, `VoiceChatService`) with the
[farm-my-life](https://github.com/Modbit-Studios/farm-my-life) gameplay pattern: the host owns the
shared world; clients send requests and apply what the host broadcasts.

| Autoload | Owns |
|---|---|
| `WorldService` | the live world, player bodies, routing every hit to the host, late join |
| `ItemService` | items in the world (spawn, pickup, drop, landing spot, selling) |
| `CreatureService` | fish, crabs, sharks: simulated on the host, puppets elsewhere |
| `WorldEvents` | chests, beaten bosses, the boat (the driver simulates it) |

Players are `Avatar_<seat>` nodes under the world (`scenes/players/avatar.tscn`); the local one is
hidden and sends the local `Player`'s state. Design notes: `docs/superpowers/specs/2026-10-18-multiplayer-design.md`.

## Tests

```sh
./tests/run.sh test_level1_loop   # one headless test (any tests/test_*.gd)
./tests/net_run.sh                # two copies of the game over LAN: host + client
```

Tests run through `tests/boot.gd`, which loads them after the autoloads exist. Steam lobbies and voice
need two Steam accounts on two machines and are not covered by the automated tests.
