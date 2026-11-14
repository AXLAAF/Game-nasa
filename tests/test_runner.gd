extends SceneTree

## Uso: godot --headless --path . --script res://tests/test_runner.gd
## La suite se carga en tiempo de ejecucion para que los autoloads ya existan.


func _initialize() -> void:
	await process_frame
	var broken := _compile("res://game")
	var suite: Script = load("res://tests/sim_tests.gd")
	if suite == null:
		push_error("FAIL: la suite no compila")
		quit(1)
		return
	var failed: int = suite.new().run(root)
	quit(1 if failed + broken > 0 else 0)


func _compile(path: String) -> int:
	var broken := 0
	for dir_name: String in DirAccess.get_directories_at(path):
		broken += _compile(path.path_join(dir_name))
	for file_name: String in DirAccess.get_files_at(path):
		if file_name.ends_with(".gd"):
			var script: GDScript = load(path.path_join(file_name))
			if script == null or not script.can_instantiate():
				push_error("FAIL: no compila %s" % path.path_join(file_name))
				broken += 1
	return broken
