extends SceneTree
## Runs one test: `godot --headless --path . -s tests/boot.gd -- <test name>`.
## Tests are loaded only once the autoloads exist (a script given to -s is compiled before them, and
## game scripts refer to the autoloads), then run(tree) is called on them.


func _init() -> void:
	await process_frame
	var name := OS.get_cmdline_user_args()[0]
	var test: Object = load("res://tests/%s.gd" % name).new()
	await test.run(self)
