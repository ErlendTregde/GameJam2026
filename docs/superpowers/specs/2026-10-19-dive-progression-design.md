# Dive deeper: progression without boss gates

Spearfish with me, "Hold your breath" jam. Replaces "kill the island's shark to move on".

## Why

Having to kill the boss to move on felt bad. The game should instead pull you
deeper, one step at a time:

1. Spear small fish near the shore, then sell them to Coco.
2. Buy better weapons, which catch bigger fish, which earn more money.
3. Buy swim gear (goggles, flippers), which lets you dive deeper and swim faster.
4. Deeper water has bigger fish and a reward chest.

The player should understand this loop from the world itself, without quest text. (The user
already removed the goal text.)

## What the research says (summary)

- **Depth is the progression, gear is the key.** In Subnautica and Dave the Diver, each piece of
  gear lets you reach the next depth. The ocean itself (darkness, fog, danger) tells you where
  you are not ready to go yet.
- **Landmarks you can see.** Show the player something visible that they want. A glowing thing
  in the deep works as a magnet.
- **Breadcrumbs.** Put small rewards along the path toward the landmark.
- **Gear gates.** Let the player see the goal before they can reach it, then come back with the
  right gear. Never lock them out for good.
- **Keep dives short.** Critics of Dave the Diver say long dives become tiring. Breath is our
  timer, and that is the jam theme.

Sources: radiator.debacle.us (Subnautica sea floors), feedme.design (Designing with Depth),
epiloguegaming.com and thexboxhub.com (Dave the Diver), GMTK (Zelda landmarks), gamedev.net
(hand-holding), bugnet.io (Metroidvania gating).

## Goals

- **Bosses patrol, they don't gate.** Each boss swims a fixed patrol in its own part of the sea.
  It is dangerous to swim through, but you never have to kill it to progress.
  - The great white patrols one place and the giant shark patrols another.
  - When you come close, it hunts you. This includes following you onto land, as it does now.
- **Depth is gated by gear, not by bosses.** Breath (`breath_time`, now 15 s) is the main limit.
  You can't reach the deep reward before you have the gear.
- **The lure, visible from island 1:**
  - Bigger fish swim near the bottom of the deeper water.
  - A glowing chest sits on the deep sea floor, with the statue (`assets/statue`) standing next
    to it as a landmark you can spot from the surface.
- **Flippers and goggles** (`assets/flippers`, `assets/googles`) are sold in island 2's shop
  (`ShopBoard2`). The user decided this.
- **The boat is disabled for now.** The user decided this. Nothing unlocks it, and `SharkZone2.unlocks` goes
  away.

## Non-goals

- Quest log, map, waypoint arrows, goal text.
- Oxygen tanks, a pressure system, a flashlight. They can come later; this plan is goggles and
  flippers only.
- Island 3, the final boss.
- **Caves.** The user said to stay away from them for now, and a later plan covers them. The Terrain3D
  switch still goes ahead, for sculpting the sea floor (trenches, drop-offs, a deep basin for the
  chest).
- AI-made 3D models or audio. Only the given assets plus simple Godot primitives (CSG/boxes) are
  used.

## Anti-goals (fails even if it "works")

- The player swims straight to the deep chest on the first dive and grabs it. The gate must hold.
- The player doesn't know what to do after the first sale (no visible next step).
- A boss blocks the only route, which brings back "kill to pass".
- Dives turn long and tedious.

## Constraints

- One developer, about a week for the whole jam (some already spent). Godot 4.7, built with
  nodes and the inspector, small scripts.
- Multiplayer: the host owns the world. Patrolling bosses, the deep chest and gear purchases must
  sync (`CreatureService`, `WorldEvents`, `ItemService`). Money stays separate for each player,
  and gear is per player too.
- Every heightmap terrain (ours and Terrain3D) is heightfield-only, so cave roofs have to be
  placed meshes.

## The how (proposed; the user decides the open points)

### Gear
- Gear is worn, not held. **(My call.)** Buying it equips it at once for that player. It takes no
  hotbar slot and its name shows in the HUD (a label). It is a new kind of item resource, or a flag
  on `ItemData`.
- **Goggles:** make the underwater view clearer, by lowering the fog density of
  `underwater_environment` for that player (now 0.06), so the deep chest and fish become
  readable, **and** give a longer `breath_time`. The user decided both.
- **Flippers:** faster `swim_speed` and `dive_speed`, so you reach the bottom and back on one
  breath.
- **The gate math:** the deep chest is placed so that with the starting stats (15 s breath,
  2 m/s dive) the round trip is not possible, and with the gear it just is. A test checks this.

### Bosses
- `SharkZone` changes from "deep water spawns a shark" to "a shark lives here and patrols":
  - Each zone has a patrol path (`Path3D` or a ring of markers set in the editor) and an
    aggro radius.
  - It is always present, and it is visible as a fin and shadow, so the danger can be read.
  - It hunts when a player comes inside the radius. When the player escapes (gets far enough
    away), it gives up and goes back to its patrol. The user decided this, and it replaces "hunts
    until it kills you". It can still follow onto land while it hunts.
  - It keeps its damage between hunts, as now.
- Killing a boss is optional. It drops a big reward (the trophy, sold to Coco), so brave players
  have a reason to fight.
- The "every bit of deep water is shark water" rule (`use_depth`) goes away. The open sea is
  safe(ish), and the boss areas are where the danger is.

### The deep chest and statue
- Place it in deeper water off island 1, inside view of the beach.
  - It has a glow (an emissive material plus an `OmniLight3D`), so it can be seen through the
    surface at dusk.
  - The statue stands next to it as the landmark.
- **(My call.)** It is the existing chest with `cost = 0`: it opens for everyone and closes
  again after 5 minutes (`reset_time`), so the loot comes back. It holds rare, valuable items.
- Breadcrumbs lead from the shallows to it: shells, then bigger fish, then rarer fish.

### Terrain: switch to Terrain3D (user's choice, in scope now)
- The Terrain3D 1.0.2 addon is installed and enabled, and it loads in Godot 4.7.2 (checked).
- **What it gives:** hand-sculpting in the editor (trenches, shelves, drop-offs, cave mouths),
  painted textures, and **holes**.
- **What it does not give:** real caves. Like ours, it is a heightmap, so it can't make overhangs
  or a tunnel roof. In the docs, a hole only removes terrain (`get_height` returns NaN there); it
  doesn't make a ceiling. A cave is therefore:
  - sculpt a trench or pit in Terrain3D (or punch a hole),
  - put a roof over it built from rock meshes we already have, or CSG shapes with the toon
    material,
  - make it dark inside, so the goggles matter.
  Not in this plan (no caves for now); this is only kept as a note.
- **Migration:**
  1. Bake our current procedural islands to a height image.
  2. Load it with `Terrain3DData.import_images`, so the world starts out as it is now.
  3. Sculpt the deep parts by hand on top of that.
- **Keep the `Terrain` API.** `get_floor_height(x, z)` becomes a thin call to
  `Terrain3D.data.get_height(...)`. Fish, crabs, sharks, scatter, spawners and tests call it today
  and stay unchanged. Holes return NaN, so it needs a fallback (treat a hole as very deep).
- **Collision** comes from Terrain3D. Player, items and creatures already use physics layer 1
  (world), so the terrain collision goes on layer 1.
- **Risk:** this is the biggest change in the plan, and it touches every system that reads the
  ground. It is done first, on its own, with all existing tests passing before anything else
  starts.
- The addon's `demo/` folder is not committed.


## Build order

1. Terrain3D migration (no gameplay change; all tests pass).
2. Patrolling bosses that give up (the boat is disabled).
3. Worn gear: goggles and flippers in island 2's shop.
4. The deep chest, the statue and the breadcrumb fish, plus the gate test.

## Left to the builder

Exact numbers (breath, speeds, prices, depths), the patrol path shapes, glow colour and HUD icon
layout.
