class_name SellScale
extends StaticBody3D
## The selling table. Drop catch onto it (Q); the price of everything on it shows above; press E
## on the table to sell it all. Items that can't be sold (price 0) stay.

## Finds the items lying on the tray.
@export var tray_area: Area3D
@export var sign_label: Label3D
@export var coco: Coco
## A sale pays this much or more per item when it counts as a big catch ("chonker" lines).
@export var big_value := 15
## Coco says this the first time you look at the table.
@export var hint := "Drop your catch on the table with [Q], then press [E] to sell!"

var _sold := 0.0  # seconds the "+$" text is still shown
var _hinted := false


func _ready() -> void:
	add_to_group("sell_scale")


func holds(item: WorldItem) -> bool:
	return item in _on_tray()


func _process(delta: float) -> void:
	_sold -= delta
	if _sold > 0.0:
		return
	var sum := total()
	sign_label.text = "$%d" % sum if sum > 0 else ""


func _on_tray() -> Array[WorldItem]:
	var out: Array[WorldItem] = []
	for body in tray_area.get_overlapping_bodies():
		if body is WorldItem and body.item and body.item.price > 0:
			out.append(body)
	return out


func total() -> int:
	var sum := 0
	for it in _on_tray():
		sum += it.item.value(it.weight)
	return sum


func get_prompt() -> String:
	if not _hinted and coco:
		_hinted = true
		coco.say_line(hint)
	var sum := total()
	return "[E] sell $%d" % sum if sum > 0 else ""


func interact(_player: Node) -> void:
	if total() > 0:
		ItemService.request_sell(self)  # the host counts its copy of the table and pays the seller


## Host: everything sellable on the table, as [total, has a big catch, items] (ItemService removes them).
func take_all() -> Array:
	var big := false
	var items := _on_tray()
	for it in items:
		big = big or it.item.value(it.weight) >= big_value
	return [total(), big, items]


## The seller's side of a sale: money in, ka-ching, Coco's line.
func pay(player: Node, amount: int, big: bool) -> void:
	player.add_money(amount)
	sign_label.text = "+$%d" % amount
	_sold = 1.5
	if coco:
		coco.say(big)
