class_name Harvestable
extends StaticBody3D
## The collision body of scattered trees (made by a Scatter node). Hitting a tree shakes it and
## sometimes drops loot from its crown, a few times per tree.

## What can fall out.
var loot: LootTable
## Chance per hit that something falls.
var drop_chance := 0.35
## How many times each tree can drop before it is empty.
var drops_per_tree := 3
## Height of the crown above the tree's base, at scale 1 (m).
var crown_height := 4.5

var _trees := []  # [world base position, MultiMesh, instance index, local transform, drops left]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func add_tree(base: Vector3, multimesh: MultiMesh, index: int, local: Transform3D) -> void:
	_trees.append([base, multimesh, index, local, drops_per_tree])


func take_damage(_amount: float, at := Vector3.ZERO) -> void:
	var tree := _nearest(at)
	if tree.is_empty():
		return
	_shake(tree)
	if tree[4] <= 0 or loot == null or _rng.randf() > drop_chance:
		return
	tree[4] -= 1
	var picks := loot.roll(_rng)
	if picks.is_empty():
		return
	var item: RigidBody3D = load(picks[_rng.randi() % picks.size()].scene_path).instantiate()
	var world: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	world.add_child(item)
	var scale: float = (tree[3] as Transform3D).basis.get_scale().x
	var side := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * 0.8
	item.global_position = tree[0] + Vector3.UP * crown_height * scale + side
	item.linear_velocity = side * 0.5


func _nearest(at: Vector3) -> Array:
	var best := []
	var best_d := INF
	for tree in _trees:
		var d := Vector2(at.x - tree[0].x, at.z - tree[0].z).length()
		if d < best_d:
			best_d = d
			best = tree
	return best


## Rocks the tree briefly, as if it was struck.
func _shake(tree: Array) -> void:
	var multimesh: MultiMesh = tree[1]
	var index: int = tree[2]
	var rest: Transform3D = tree[3]
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var angle := sin(t * TAU * 3.0) * (1.0 - t) * 0.06
		multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.RIGHT, angle) * rest.basis, rest.origin)), 0.0, 1.0, 0.6)
