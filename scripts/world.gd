extends Node3D
## The island level. Tells the gameplay services the world is here (and gone), so they can place
## and replicate what lives in it. When this scene is only the main menu's backdrop it stays quiet.


func _ready() -> void:
	if get_parent() == get_tree().root:
		WorldService.world_ready(self, $Player)


func _exit_tree() -> void:
	if WorldService.world == self:
		WorldService.world_exiting()
