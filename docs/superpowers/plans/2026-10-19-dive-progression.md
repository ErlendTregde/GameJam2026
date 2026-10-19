# Dive Deeper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "kill the boss to pass" gate with patrolling bosses that give up, swim gear
(goggles and flippers), and a glowing deep chest that you can only reach with that gear. The
ground moves to Terrain3D.

**Architecture:**
- The `Terrain` node stays the API that every creature and test calls (`get_floor_height`), but
  its heights and collision come from a `Terrain3D` node.
- `SharkZone` owns one shark that is always there. The shark patrols a `Path3D`, hunts players
  who come near, and goes back to its path when they escape.
- Gear is an `ItemData` flag. Buying gear wears it at once, and the local `Player` applies its
  stat changes.

**Tech Stack:** Godot 4.7.2 GDScript, the Terrain3D 1.0.2 addon (already in `addons/terrain_3d`,
enabled, and loads), and the existing autoloads (`CreatureService`, `WorldEvents`,
`ItemService`).

**Spec:** `docs/superpowers/specs/2026-10-19-dive-progression-design.md`

## Global Constraints

- Build with nodes and the inspector: tunables are `@export`, and placement is done in
  `scenes/main.tscn`. Keep scripts small.
- No AI-made 3D models or audio. Use only `assets/flippers/flippers.glb`,
  `assets/googles/stylized_swimming_goggles.glb`,
  `assets/statue/polygonal_venus_statue_-_low_poly.glb` and existing assets.
- Multiplayer: the host simulates creatures and chests. Money and gear belong to each player.
- No caves. The boat stays locked; nothing unlocks it.
- Tests: `./tests/run.sh <name>` (headless) and `./tests/net_run.sh`. Every task ends with all
  `tests/test_*.gd` passing, except `test_fish_border`, which is already flaky (about 1 in 5).
- When editing files with Python, use `encoding="utf-8"` and `newline="\n"`.
- Do not commit the addon's `demo/` folder.
- End every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A hole in Terrain3D.** `get_height` returns NaN there, and every caller does arithmetic on
   the floor height. Expected: `get_floor_height` returns a finite deep value (-100) instead.
   Test it in Task 1.
2. **Ground collision far from the camera.** The default Terrain3D collision is built only around
   the camera. Expected: items and players collide with the ground anywhere on the 1000 m map.
   Test it in Task 1 with a raycast 300 m from the player.
3. **A hunted player dies on land, or leaves the game, while the shark is mid-hunt.** Expected: it
   picks the next nearby player or goes back to patrolling. It never freezes and never despawns.
   Test it in Task 2.
4. **Buying gear you already wear.** Expected: no charge, and the label flashes red. Test it in
   Task 3.
5. **The deep chest is opened by one player while another is swimming down.** Expected: it opens
   once, and closes again after `reset_time`, as the gamble chest does. This is existing chest
   behaviour, so no new test is needed; the review only checks that `cost = 0` and `reset_time`
   are set.

---

### Task 1: Terrain3D under the Terrain API

**Files:**
- Modify: `scripts/terrain.gd`
- Modify: `scenes/main.tscn` (add a `Terrain3D` node, link it on `Terrain`)
- Create: `terrain_data/` (Terrain3D region files, committed)
- Test: `tests/test_terrain3d.gd`

**Interfaces:**
- Produces:
  - `Terrain.get_floor_height(x: float, z: float) -> float`. Same signature as now. It returns
    `terrain3d.data.get_height(Vector3(x, 0, z))`, or `-100.0` when that is NaN (a hole or
    outside the regions).
  - `Terrain.procedural_height(x: float, z: float) -> float`. The current body of
    `get_floor_height`, renamed. It is used only for baking.
  - `@export var terrain3d: Terrain3D`. When this is set, `build()` makes no mesh and no
    collision of its own.
  - `@export_tool_button("Bake to Terrain3D") var bake_button := bake`.
  - `func bake() -> void`, editor only. It samples `procedural_height` every 1 m over `size`
    into an `Image` (`FORMAT_RF`, absolute metres). It loads the image with
    `terrain3d.data.import_images([img, null, null], Vector3(-size / 2, 0, -size / 2), 0.0, 1.0)`,
    then saves with `terrain3d.data.save_directory(terrain3d.data_directory)`.
- Terrain3D node settings:
  - `data_directory = "res://terrain_data"`, `vertex_spacing = 1.0`.
  - `collision_mode = FULL_GAME`, `collision_layer = 1`.
  - The material uses the existing ground look: the same albedo colour as `Terrain.material`,
    painted with texture 0.

- [ ] **Step 1: Write the failing test** `tests/test_terrain3d.gd`, in the same shape as
  `tests/test_shark_land.gd`. Load `main.tscn` and wait 1 s. Get `terrain: Terrain`, then:
  ```
  assert(terrain.terrain3d != null, "the ground is a Terrain3D")
  for p in [Vector2(0, 17), Vector2(40, 60), Vector2(-130, -60), Vector2(300, -300)]:
  	var h := terrain.get_floor_height(p.x, p.y)
  	assert(is_finite(h), "floor height is a number at %s" % p)
  	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 200, p.y), Vector3(p.x, -300, p.y), 1))
  	assert(not hit.is_empty() and absf(hit.position.y - h) < 0.5, "collision matches the height at %s" % p)
  assert(terrain.get_floor_height(900, 900) == -100.0, "outside the terrain is deep water, not NaN")
  ```
  Here `space` is `main.get_world_3d().direct_space_state`. At the end, print
  `PASS test_terrain3d` and call `tree.quit()`.
- [ ] **Step 2: Run it:** `./tests/run.sh test_terrain3d`. Expected: FAIL with
  "the ground is a Terrain3D".
- [ ] **Step 3: Implement** in `scripts/terrain.gd`: the rename, the export, `bake()`, the NaN
  fallback, and `build()` returning early when `terrain3d` is set. Leave the `IslandShape`
  children in place, because `bake` reads them.
- [ ] **Step 4: Add the node and bake:**
  1. Add a `Terrain3D` node under the `main.tscn` root with the settings above, and set
     `Terrain.terrain3d` to it.
  2. Run the bake once from a headless script:
     `$G --headless --path . -s <scratch>/bake.gd`. The script loads `main.tscn`, calls
     `Terrain.bake()` on the instance, and quits. Because `bake` is `@tool` code, it can run
     outside the editor too.
  3. Commit the files written to `terrain_data/`.
- [ ] **Step 5: Run** `./tests/run.sh test_terrain3d`, then every other `tests/test_*.gd`.
  Expected: all PASS (`test_fish_border` may flake). Then run `./tests/net_run.sh`. Expected:
  `fails=0` on both sides.
- [ ] **Step 6: Take a windowed screenshot** of the spawn view
  (`--path . -s tests/boot.gd -- <script> <outprefix>`) and compare it with the old look. The
  island shapes and beach should be the same. Fix the material if it is off.
- [ ] **Step 7: Commit:** `feat: ground is Terrain3D (baked from the island shapes), same Terrain API`.

### Task 2: Bosses patrol, hunt nearby players, give up and return

**Files:**
- Modify: `scripts/shark.gd`, `scripts/shark_zone.gd`
- Modify: `scenes/main.tscn`:
  - Add a `Patrol` (`Path3D`) under `SharkZone`, a closed loop in deep water off island 1. It
    must stay at least 40 m from the deep chest spot chosen in Task 4, and must not cross the
    shallows in front of the spawn.
  - Add a `Patrol` under `SharkZone2`, a loop around island 2's deep water.
  - Delete `SharkZone2/Island2Water` and `SharkZone2.unlocks`.
  - Set `Boat.locked_text = "The boat isn't ready yet"`.
- Delete: `tests/test_shark_spawn.gd` (it tested the spawn-point search, which is removed)
- Modify tests: `test_shark_boss.gd`, `test_shark_land.gd`, `test_level1_loop.gd`,
  `test_level2.gd`, `net_host.gd`, `net_client.gd`
- Create test: `tests/test_shark_patrol.gd`

**Interfaces:**
- `Shark`:
  - `var patrol: Path3D`, set by the zone. A shark with no target, or that is leaving, follows the
    path. It goes to the nearest point on `patrol.curve` (`get_closest_offset`), then moves
    forward along it at `patrol_speed` (`@export var patrol_speed := 4.0`), as an offset that
    wraps with `curve.get_baked_length()`. It looks ahead with `sample_baked(offset + 4.0)` and
    stays at the path's Y.
  - `leave()` keeps its name and meaning ("stop hunting"). It no longer despawns: the
    `despawn_distance` branch and `gone` are removed. `is_leaving()` is true whenever it isn't
    hunting, so the boss bar and the `CreatureService` mirror keep working unchanged.
  - `hunt()` also resets `_circled = 0.0`, so every new hunt starts with the fin warning.
- `SharkZone`:
  - Exports kept: `player`, `ocean`, `terrain`, `shark_scene`, `warning_time`, `boss_bar`,
    `message`, `defeated_text`, `defeated`.
  - New exports: `@export var patrol: Path3D`, `@export var aggro_radius := 18.0` (m from the
    shark), `@export var give_up_distance := 45.0` (m from the shark).
  - Removed: `use_depth`, `dive_depth`, `danger_depth`, `spawn_delay`, `spawn_distance`,
    `unlocks`, `in_zone`, `_spawn_point`, `_boss_health`, the Area3D handling, and the editor
    preview (`refresh_button`, `show_preview`, `preview_spacing`, `_build_preview`). The script
    no longer needs `@tool`.
  - `_ready` (host only, when not `defeated`): instantiates the shark at
    `patrol.curve.sample_baked(0)` in global space, sets `patrol`, `ocean`, `terrain` and
    `warning_time`, then calls `leave()`, so it starts out patrolling.
  - `_physics_process` (host):
    - While patrolling, pick `_nearest_swimmer()`: the nearest `WorldService.player_bodies()`
      entry (or `player`, when the list is empty) with `exposed_to_sea`, within `aggro_radius`
      of the shark. Set it as the target and call `hunt()`.
    - While hunting, if the target is invalid or farther than `give_up_distance`, call `leave()`.
  - `_on_player_died`: it keeps its current next-victim logic, except that "no one is left"
    calls `leave()`, which now means patrol.
  - On the shark's death: `defeat()` and `WorldEvents.zone_defeated` as now. The trophy still
    drops.
  - `func spawned_shark() -> Shark` returns `_shark`, for tests.

- [ ] **Step 1: Write the failing test** `tests/test_shark_patrol.gd`. Load `main.tscn`, wait
  1 s, get `zone: SharkZone` and `p: Player`. Then:
  ```
  var shark := zone.spawned_shark()
  assert(shark != null and shark.is_leaving(), "the boss is already out there, patrolling")
  var start := shark.global_position
  # wait 3 s
  assert(shark.global_position.distance_to(start) > 5.0, "it swims its patrol")
  p.global_position = shark.global_position + Vector3(8, 0, 0)  # in the water, inside aggro_radius; hold here each frame
  # wait up to 3 s for: shark.target == p and not shark.is_leaving()
  assert(shark.target == p and not shark.is_leaving(), "a swimmer close by gets hunted")
  p.global_position = Vector3(0, 3, 17)  # back on the beach, far away
  # wait up to 15 s for shark.is_leaving()
  assert(shark.is_leaving(), "it gives up when you escape")
  # wait up to 20 s for: distance from the shark to the nearest point of patrol.curve < 4
  assert(<that distance> < 4.0, "and swims back to its patrol")
  assert(is_instance_valid(shark), "it never despawns")
  ```
  At the end, print `PASS test_shark_patrol`.
- [ ] **Step 2: Run it:** `./tests/run.sh test_shark_patrol`. Expected: FAIL (`spawned_shark`
  does not exist).
- [ ] **Step 3: Implement** the `Shark` and `SharkZone` changes, then add the two `Patrol`
  paths and delete `Island2Water` and `unlocks` in `main.tscn`. Look at the paths in a
  screenshot to check they are in deep water. Hold each `Path3D` point at Y = -4 (below the
  surface).
- [ ] **Step 4: Run** `./tests/run.sh test_shark_patrol`. Expected: PASS.
- [ ] **Step 5: Update the old tests to the new rules** (replace `zone._spawn(...)` with
  `zone.spawned_shark()`, then move the player next to it or set `target` and call `hunt()`):
  - `test_shark_boss`: the `in_zone` assert goes. It keeps "health is kept between hunts",
    which now holds with no despawn.
  - `test_shark_land`: unchanged otherwise. Also assert that it gives up after the player runs
    more than `give_up_distance` inland.
  - `test_level2`:
    - Drop "killing it unlocks the boat". Assert that `boat.locked` stays true after
      `zone.defeat()`.
    - Update the header comment.
    - Add the Review Focus #3 check: with 2 players, kill the target via `WorldService` death
      while the shark hunts. Expected: it targets the other one, or it is leaving. It is still
      valid.
  - `test_level1_loop`: use `spawned_shark()`.
  - `net_host` and `net_client`:
    - The client swims to the shark (host: `zone.spawned_shark().global_position + (8, 0, 0)`;
      send it to the client the way the test already sends positions, or hard-code a point on
      the patrol path).
    - Remove the boat-unlock and boat-drive checks. Keep the checks that the boat stays locked
      on both sides.
- [ ] **Step 6: Run all tests and `./tests/net_run.sh`.** Expected: all PASS and `fails=0`.
- [ ] **Step 7: Commit:** `feat: sharks patrol their waters, hunt swimmers who come close, give up and go back`.

### Task 3: Worn gear: goggles and flippers in island 2's shop

**Files:**
- Modify: `scripts/inventory/item_data.gd` (new export group "Gear")
- Modify: `scripts/player.gd` (`wear`, applying the stats, the HUD label)
- Modify: `scripts/shop/shop_item.gd` (worn items call `wear` instead of `give`)
- Create: `scenes/items/goggles.tscn`, `scenes/items/flippers.tscn` (WorldItem scenes with a
  `Model` child from the glb files, made the same way as `scenes/items/bottle.tscn`),
  `items/goggles.tres`, `items/flippers.tres`
- Modify: `scenes/player.tscn` (a `HUD/Status/Gear` Label), `scenes/main.tscn` (two
  `shop_item` instances on `Shop/ShopBoard2`)
- Test: `tests/test_gear.gd`

**Interfaces:**
- `ItemData`, export group "Gear":
  - `@export var worn := false`
  - `@export var extra_breath := 0.0` (s)
  - `@export var swim_multiplier := 1.0`
  - `@export var underwater_fog_multiplier := 1.0`
- `Player`:
  - `var worn: Array[ItemData] = []`
  - `func wears(item: ItemData) -> bool`
  - `func wear(item: ItemData) -> void`: appends it, then applies the stats:
    - `breath_time += item.extra_breath`
    - `swim_speed`, `dive_speed` and `rise_speed` are each multiplied by `item.swim_multiplier`
    - the underwater fog: on the first `wear`, `underwater_environment` is duplicated so each
      player has their own copy, then its `fog_density` is multiplied by
      `item.underwater_fog_multiplier`
    - the `HUD/Status/Gear` label shows the names, joined with `"  "`
  - Gear is kept on death.
- `ShopItem.interact`: if `item.worn and player.wears(item)`, flash red and return before
  `spend`. If it is worn and was bought, call `player.wear(item)`; otherwise call
  `player.give(item)`.
- Values (the spec leaves the numbers to the builder):
  - `goggles.tres`: name "Goggles", `worn`, `extra_breath = 10.0` (15 → 25 s),
    `underwater_fog_multiplier = 0.4`. Shop price 120.
  - `flippers.tres`: name "Flippers", `worn`, `swim_multiplier = 1.5`. Shop price 100.
  - Task 4's gate test may move these values; whatever it settles on is the source of truth.

- [ ] **Step 1: Write the failing test** `tests/test_gear.gd`. Load `main.tscn` and wait 1 s.
  ```
  var goggles: ShopItem = <the ShopBoard2 shop item whose item.name == "Goggles">
  var flippers: ShopItem = <same for "Flippers">
  assert(main.get_node("Shop/ShopBoard").find_children("*", "ShopItem").all(func(s): return not s.item.worn), "not in the first shop")
  p.money = 0; goggles.interact(p)
  assert(not p.wears(goggles.item), "can't buy without money")
  p.add_money(500)
  var breath := p.breath_time; var fog := p.underwater_environment.fog_density
  goggles.interact(p)
  assert(p.wears(goggles.item) and p.money == 500 - goggles.price, "bought and worn")
  assert(p.breath_time == breath + 10.0 and p.underwater_environment.fog_density < fog, "longer breath, clearer water")
  assert(p.held_item() == null or not p.held_item().worn, "it takes no hotbar slot")
  var money := p.money; goggles.interact(p)
  assert(p.money == money, "no paying twice for the same gear")
  var swim := p.swim_speed; flippers.interact(p)
  assert(is_equal_approx(p.swim_speed, swim * 1.5), "flippers: faster swimming")
  ```
  At the end, print `PASS test_gear`. To check the hotbar, look through `p` slots the same way
  `test_shop.gd` does.
- [ ] **Step 2: Run it:** `./tests/run.sh test_gear`. Expected: FAIL (no "Goggles" item on
  ShopBoard2).
- [ ] **Step 3: Implement** the `ItemData` exports, `Player.wear` and `Player.wears`, the
  `ShopItem` branch, the two item scenes and `.tres` files, the HUD label, and the two shop
  items on `ShopBoard2`. Pick `display_size` and `model_rotation` from a screenshot.
- [ ] **Step 4: Run** `./tests/run.sh test_gear`, `test_shop` and `test_inventory`. Expected:
  PASS.
- [ ] **Step 5: Commit:** `feat: goggles and flippers in island 2's shop: worn gear for longer breath, clearer water, faster swimming`.

### Task 4: The deep chest, the statue and the trail of bigger fish

**Files:**
- Modify: `scenes/main.tscn`:
  - `Chests/DeepChest`: a `chest.tscn` instance with `tier = GOLD`, `cost = 0` and
    `reset_time = 300.0`, using a `LootTable` with rare and expensive items (shark tooth, big
    fish).
  - A child `OmniLight3D`: warm gold, `omni_range = 12`, `light_energy = 3`.
  - `Statue`: the statue glb, with a `StaticBody3D` box on layer 1, standing next to the chest.
  - `Fish/DeepFish`: a `fish_spawner` with `red_snapper` and `deep_grouper`, around the chest
    with `min_depth`/`max_depth` near the floor there. Add one more spawner halfway between the
    shore and the chest with the bigger shallow fish (the breadcrumbs).
- Create: `scenes/statue.tscn` (the glb plus collision)
- Test: `tests/test_dive_gate.gd`

**Interfaces:**
- Consumes: `Player.wear`, `goggles.tres` and `flippers.tres` (Task 3); `Terrain.get_floor_height`
  (Task 1); `SharkZone.patrol` (Task 2, which must keep the chest ≥ 40 m from both patrols).
- The chest spot: off island 1, within about 60 m of the beach, so the glow can be seen from
  the spawn. Choose the depth `D` from the test below: the depth where a geared round trip just
  survives and a bare one doesn't. If the existing floor isn't that deep there, lower it with
  Terrain3D (`terrain3d.data.set_height` in a one-off script, or by hand), then save
  `terrain_data/`.

- [ ] **Step 1: Write the failing test** `tests/test_dive_gate.gd`. It plays a real dive:
  ```
  ## Swim from the surface above the chest down to it and back up, as a player would:
  ## look straight down, hold move_forward + sprint (+ dive), then look up and swim to the air.
  ## Returns true if the player is still alive at the surface.
  func dive_round_trip(p: Player, chest: Chest) -> bool
  ```
  - Head pitch is set through `p.get_node("Head").rotation.x = -1.5` (down) and `+1.5` (up).
  - Use `Input.action_press` for "move_forward", "sprint" and "dive". Hold the player's X and Z
    over the chest, and go down until within 1.5 m of `chest.global_position.y`.
  - Before each attempt, reset `health`, `oxygen` and `stamina` to full.

  ```
  var chest: Chest = main.get_node("Chests/DeepChest")
  assert(not await dive_round_trip(p, chest), "without gear the deep chest is out of reach")
  p.wear(load("res://items/goggles.tres")); p.wear(load("res://items/flippers.tres"))
  assert(await dive_round_trip(p, chest), "with goggles and flippers you make it there and back")
  var beach := Vector3(0, 3, 17)
  assert(beach.distance_to(chest.global_position) < 70.0, "close enough to see from the spawn beach")
  for zone in [main.get_node("SharkZone"), main.get_node("SharkZone2")]:
  	var c: Curve3D = zone.patrol.curve
  	var nearest := zone.patrol.to_global(c.get_closest_point(zone.patrol.to_local(chest.global_position)))
  	assert(nearest.distance_to(chest.global_position) > 40.0, "no boss guards the chest")
  ```
  At the end, print `PASS test_dive_gate`.
- [ ] **Step 2: Run it:** `./tests/run.sh test_dive_gate`. Expected: FAIL (no `DeepChest`).
- [ ] **Step 3: Place** the chest, light, statue and spawners. Then tune `D` (and, if needed,
  `extra_breath` or `swim_multiplier` in the `.tres` files) until both asserts hold, with at
  least 3 s of margin either way. Print the times from inside `dive_round_trip` while you tune.
- [ ] **Step 4: Run** `./tests/run.sh test_dive_gate` and then all tests. Expected: all PASS.
- [ ] **Step 5: Take a windowed screenshot** from the spawn beach looking at the chest. The glow
  or the statue must be visible from the surface; if it is not, raise `light_energy` or move the
  chest closer.
- [ ] **Step 6: Commit:** `feat: glowing deep chest with a statue off island 1, reachable only with goggles and flippers`.

### Task 5: Docs

**Files:** `README.md` (the intro line: "beat each island's shark boss to reach the next island"
becomes "buy gear to dive deeper; sharks patrol the deep water").

- [ ] **Step 1:** Edit the line. Run all tests once more and `./tests/net_run.sh`.
- [ ] **Step 2: Commit:** `docs: README matches the dive-deeper loop`.
