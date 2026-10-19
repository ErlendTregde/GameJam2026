extends Node3D
## Floats on the waves (a marker buoy).

@export var ocean: Ocean


func _process(_delta: float) -> void:
	if ocean:
		global_position.y = ocean.get_height(global_position)
