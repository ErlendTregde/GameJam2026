@tool
class_name IslandShape
extends Marker3D
## One island of the Terrain, placed where this node is. Child of Terrain; click Rebuild on the
## Terrain after changing it.

## Distance from the center to the shoreline (m).
@export var radius := 20.0
## How high the island's hill rises above the beach (m).
@export var height := 5.0
## How wobbly the coastline is (0 = round, 0.4 = very irregular).
@export_range(0.0, 0.6) var roughness := 0.25
## Changes the coastline and hill shape without moving the island.
@export var shape_seed := 0
