class_name ItemData
extends Resource
## One kind of item. Make a new item by saving one of these as a .tres in res://items/.

@export var name := ""
## The item lying in the world (a WorldItem scene). Its "Model" child is also what the
## hotbar slot and the hand show. A path, not a PackedScene, so the scene can point back here.
@export_file("*.tscn") var scene_path := ""

enum HoldStyle { FLOAT, POLEARM }

@export_group("In hand")
## FLOAT: small item floating in view. POLEARM: a spear held low at real length, pointing at
## the crosshair, stabbing along the shaft.
@export var hold_style := HoldStyle.FLOAT
## Longest side of the model when held (m); for a polearm its real length.
@export var held_size := 0.17
## Extra turn when held (degrees). For a polearm: turn around its shaft (y), e.g. to tilt prongs.
@export var held_rotation := Vector3.ZERO
## Extra offset when held (m). FLOAT only.
@export var held_offset := Vector3.ZERO
## POLEARM: where the hand grips the shaft, 0 = butt, 1 = tip.
@export_range(0.0, 1.0) var grip := 0.3

@export_group("Weapon")
## Damage per hit; 0 = not a weapon.
@export var damage := 0.0
## How far a hit reaches (m).
@export var reach := 2.0
## Seconds between swings.
@export var cooldown := 0.5
## Set for weapons that can be thrown by holding attack (the trident): what flies.
@export var thrown_scene: PackedScene

@export_group("Consumable")
## Use (left click) to drink or eat it. Common items restore a little, rare ones more.
@export var consumable := false
@export var heal := 0.0
@export var restore_stamina := 0.0
## Seconds the drink / eat animation takes; the effect lands at the end.
@export var use_time := 1.6
## Moves it while drinking (m, camera space), e.g. a big round coconut sits lower than a bottle.
@export var drink_offset := Vector3.ZERO
## What is left in the hand afterwards (a cracked coconut); empty = used up.
@export var becomes: ItemData


## The item's model on its own, ready to show anywhere (e.g. in a hotbar slot).
func make_model() -> Node3D:
	var whole := (load(scene_path) as PackedScene).instantiate()
	var model := whole.get_node("Model") as Node3D
	whole.remove_child(model)
	whole.free()
	model.transform = Transform3D.IDENTITY
	return model


## Bounds of every visible mesh in a model (in the model's own space), however it is built.
static func model_bounds(model: Node3D) -> AABB:
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		var xf := Transform3D.IDENTITY
		var shown := true
		var node: Node = mesh
		while node != model:
			if node is Node3D:
				shown = shown and node.visible
				xf = node.transform * xf
			node = node.get_parent()
		if shown:
			var b := xf * mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box
