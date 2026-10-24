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
## How deep the sea around this island gets, relative to the Terrain profile (2 = twice as deep).
## Blends smoothly toward the neighbouring islands' value.
@export var depth_scale := 1.0
## Changes the coastline and hill shape without moving the island.
@export var shape_seed := 0
## A stone island: rock instead of sand and grass (one per Terrain), no palms or grass on it.
@export var rocky := false
## How grassy it is: 1 = full grass on the hill, lower = mostly sand with patches of grass (one
## sandy island per Terrain).
@export_range(0.0, 1.0) var grass := 1.0
