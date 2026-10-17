class_name SellScale
extends StaticBody3D
## A dock scale. Drop catch onto the tray (Q); the sign shows the total weight and price; press E
## on the scale to sell everything on it. Items that can't be sold (price 0, e.g. tools) stay.

## Finds the items lying on the tray.
@export var tray_area: Area3D
@export var sign_label: Label3D
@export var coco: Coco
## A sale pays this much or more per item when it counts as a big catch ("chonker" lines).
@export var big_value := 15

var _sold := 0.0  # seconds the "+$" text is still shown


func _ready() -> void:
	add_to_group("sell_scale")


func holds(item: WorldItem) -> bool:
	return item in _on_tray()


func _process(delta: float) -> void:
	_sold -= delta
	if _sold > 0.0:
		return
	var items := _on_tray()
	var kg := 0.0
	for it in items:
		kg += it.weight
	sign_label.text = "%.1f kg\n$%d" % [kg, total()] if items else "Drop catch here\n[Q]"


func _on_tray() -> Array[WorldItem]:
	var out: Array[WorldItem] = []
	for body in tray_area.get_overlapping_bodies():
		if body is WorldItem and body.item.price > 0:
			out.append(body)
	return out


func total() -> int:
	var sum := 0
	for it in _on_tray():
		sum += it.item.value(it.weight)
	return sum


func get_prompt() -> String:
	var sum := total()
	return "E  sell $%d" % sum if sum > 0 else ""


func interact(player: Node) -> void:
	var sum := total()
	if sum == 0:
		return
	var big := false
	for it in _on_tray():
		big = big or it.item.value(it.weight) >= big_value
		it.queue_free()
	player.add_money(sum)
	sign_label.text = "+$%d" % sum
	_sold = 1.5
	if coco:
		coco.say(big)
