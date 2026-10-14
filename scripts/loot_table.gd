class_name LootTable
extends Resource
## What a chest drops: everything in `always`, plus a few random picks from `pool`.

## Always dropped (e.g. the trident in the gold chest).
@export var always: Array[ItemData] = []
## Random picks come from here; list an item twice to make it twice as likely.
@export var pool: Array[ItemData] = []
## How many random picks (min, max).
@export var picks := Vector2i(2, 3)


func roll(rng: RandomNumberGenerator) -> Array[ItemData]:
	var loot := always.duplicate()
	if not pool.is_empty():
		for i in rng.randi_range(picks.x, picks.y):
			loot.append(pool[rng.randi() % pool.size()])
	return loot
