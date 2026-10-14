class_name ItemUse
extends Node
## Drinking and eating: using (left click) a consumable held item plays the drink animation and,
## when it finishes, gives its health and stamina to the player and leaves what it becomes
## (a cracked coconut) or nothing in the hand. Switching away cancels it.

signal used(item: ItemData)

@export var player: Node
@export var held_view: Node

## The held item; set by the player whenever it changes. Switching cancels a drink.
var item: ItemData:
	set(value):
		if value != item and _using:
			_cancel()
		item = value

var _using := false
var _run := 0  # bumps on every start/cancel, so a cancelled drink can't finish later


func is_using() -> bool:
	return _using


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		use()


func use() -> void:
	if item == null or not item.consumable or _using or not player.needs(item):
		return
	_using = true
	_run += 1
	var run := _run
	var consumed := item
	held_view.drink(consumed.use_time)
	if consumed.becomes:
		held_view.show_model(consumed.becomes)  # cracks open as you raise it
	await get_tree().create_timer(consumed.use_time).timeout
	if run != _run:
		return  # cancelled
	_using = false
	player.consume(consumed)
	used.emit(consumed)


func _cancel() -> void:
	_using = false
	_run += 1
	held_view.stop_drink()  # the hand shows the newly selected item, so no need to un-crack
