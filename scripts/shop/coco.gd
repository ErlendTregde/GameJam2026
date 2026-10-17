class_name Coco
extends Node3D
## Coco, the coconut who runs the shop. Wobbles and says a line when you sell.

@export var lines: Array[String] = [
	"Fresh fish! Smells like profit.",
	"I'm technically fruit, but I'll allow it.",
	"Pleasure doing business.",
	"Keep 'em coming!",
]
## Said instead when the sale has a big catch in it.
@export var big_lines: Array[String] = [
	"Now THAT's a chonker!",
	"Whoa. Did you wrestle that one?",
]
@export var bubble: Label3D
## Seconds a line stays up.
@export var talk_time := 3.0

var _tween: Tween


func say(big: bool) -> void:
	var pool := big_lines if big and not big_lines.is_empty() else lines
	bubble.text = pool.pick_random()
	bubble.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	for i in 3:  # wobble side to side
		_tween.tween_property(self, "rotation:z", 0.25, 0.08)
		_tween.tween_property(self, "rotation:z", -0.25, 0.08)
	_tween.tween_property(self, "rotation:z", 0.0, 0.08)
	_tween.tween_interval(talk_time)
	_tween.tween_callback(func() -> void: bubble.visible = false)
