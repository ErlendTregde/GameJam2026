# Level 1 — Spearfishing economy and first boss

Jam theme: "Hold your breath". The game is about spearfishing: every hunt and every boss fight happens
underwater on one breath. You progress by selling your catch, buying better gear, and killing each
island's boss to open the way to the next island. This spec covers **Level 1 (the start island)** only.

## Player loop (Level 1)
1. Start on the island with nothing: punch (weak) or pick up the rocks lying around.
2. Catch fish on the reef and crabs on the beach. Punch palms for coconuts and planks.
3. Carry it all to the dock scale. Drop the items onto the tray with **Q**, then press **E** to sell.
4. Spend money at the shop wall (spear, water bottle) or gamble at the paid chest.
5. Swim into the deep water: the shark comes. It has a health bar, and the spear is needed to kill it.
6. The shark dies → the shark zone switches off → the way to island 2 is open.

## Features

### Inventory: 5 slots and item sizes
- The hotbar has 5 slots (Slot4 and Slot5 added in `player.tscn`, plus the `slot_4` and `slot_5` input actions).
- Each slot remembers a **weight** (kg) next to its `ItemData` (`player.weights`, which parallels `items`).
- `WorldItem` gets `weight`. Its Model and collision are scaled by `size_scale(weight)`, so a big fish looks big.
- `ItemData` gets an `@export_group("Selling")`:
  - `price` ($ per item, or per kg when `sold_by_weight`)
  - `sold_by_weight`
  - `weight_range` (Vector2, kg)
  - `base_weight` (the weight at which the model has scale 1)
- Weight is rolled when a fish or crab spawns (mostly normal, sometimes small, rarely big; this lives in an `ItemData` helper), carried to its drop, kept through pick up and drop again.
- Coconuts, planks and other items without a weight range have weight 0 and are sold per item.

### Money
- `player.money` (int) and a `$ 0` label in the HUD next to the status bars, in the same white-outline style.
- `player.add_money(amount)` and `player.spend(amount) -> bool`.
- Money is kept on death.

### The scale and Coco
- **`scenes/shop/scale.tscn`**, built from simple meshes in the editor:
  - A post and a flat tray with a low rim (StaticBody), so items stay on it.
  - An `Area3D` over the tray that finds the `WorldItem`s lying on it.
  - A `Label3D` above showing the total weight and price, e.g. `7.8 kg  —  $31`.
  - Interact prompt: `E  sell $31`. Pressing E removes the items, adds the money, and shows a floating `+$31`.
- **Dropping (Q)** throws the held item toward the crosshair, so it lands where you aim (tested to land on the tray).
- **`scenes/shop/coco.tscn`:** the coconut model with a **drawn face** (eyes and a mouth as meshes or a decal) on a crate.
  - On a sale it wobbles and shows a speech bubble (`Label3D`) with a random line from `@export var lines: Array[String]`.
  - A big catch (any single item worth `big_value` or more, $15 by default, set on the scale) uses `big_lines`.

### The shop wall
- **`scenes/shop/shop_board.tscn`:** a plank board (box meshes).
- **`scenes/shop/shop_item.tscn`:** one hook, with `@export item: ItemData` and `@export price: int`.
  - It shows the item's model on the board and has a collider so the interact ray finds it.
  - Prompt: a `Label3D` above it showing `Spear\n$40\n[E]` while looked at.
  - E: if you can afford it, the money is spent and the item goes into a free slot, or drops at your feet if the hotbar is full.
- Island 1 stock: **spear ($40)** and **water bottle ($8)**. More hooks can be added in the editor.

### The gamble chest
- `Chest` gets `@export var cost := 0` and `@export var reset_time := 0.0`.
  - When `cost > 0`, the prompt is `E  gamble $15`. Opening it spends the money, rolls the loot and closes again after `reset_time`, so you can gamble again.
- The island 1 chest becomes the gamble chest:
  - New loot table `loot/gamble_1.tres`: mostly coconuts, planks and rocks, sometimes a bottle, rarely a spear.
  - The trident is removed from island 1 loot.

### Weapons and damage
- **Fist:** empty hand damage 2 (`player` exports `fist_damage`). It hits palms, fish, crabs and the shark through `Combat`.
- **Rock** damage 5. **Spear** damage 20. The values live in the `.tres` files.

### Crabs
- **`scenes/crab/crab.tscn` + `scripts/crab.gd`:** walks on the beach between `min_height`/`max_height` around its island and scuttles away sideways when the player is close.
  - It has `take_damage` and drops `scenes/items/crab.tscn` (an item with a weight) on death.
  - It uses placeholder box/sphere meshes until a non-AI crab model is found.
- Placed by a `CrabSpawner` (or the Scatter `scenes` list) on island 1's beach, with about 6 crabs.

### The shark boss
- `Shark` gets `@export var max_health := 200.0` and `@export var display_name := "Great White"`.
  - `take_damage` lowers its health (and still makes it back off). At 0 it dies: it rolls belly-up, sinks, drops a **shark tooth** item (`price` $60) and emits `died`.
- **Boss bar:** a HUD `ProgressBar` at the top center with the name. It is shown while a shark is hunting, and the `SharkZone` drives it.
- `SharkZone` gets `@export var defeated := false`.
  - When its shark dies it sets `defeated = true`, shows "The way is open" for a few seconds, and stops spawning.
  - If the player escapes or dies, the shark leaves, and the next one comes back at full health.

## Out of scope (later levels)
- Island 2 boss, the boat unlock, the slot machine, flippers, a flashlight, the trident, sound, goal text, and real crab and plank models.

## Testing
Headless test scripts (as before, `--path . -s <test>.gd`), one per build step:
- slots and weight survive a pick up and drop
- Q-dropped items land on the tray, and the label total is right
- E sells, money goes up, and the items are gone
- shop: buying costs the price, fails when poor, and the item ends up in a slot
- gamble chest: charges, rolls and re-closes
- crab: flees, dies and drops a crab with a weight
- shark: 10 spear hits kill it, the zone is defeated and stops spawning

Then a windowed screenshot check of the HUD money, the scale label, the shop labels and Coco's face.
