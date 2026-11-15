extends SceneTree

## Uso: godot --headless --path . --script res://tests/test_runner.gd
## La suite se carga en tiempo de ejecucion para que los autoloads ya existan.


func _initialize() -> void:
	await process_frame
	root.get_node("Profile").persistence_enabled = false
	var broken := _compile("res://game")
	var suite: Script = load("res://tests/sim_tests.gd")
	if suite == null:
		push_error("FAIL: la suite no compila")
		quit(1)
		return
	var failed: int = suite.new().run(root)
	var music_suite: Script = load("res://tests/music_tests.gd")
	if music_suite == null:
		push_error("FAIL: los tests de musica no compilan")
		quit(1)
		return
	var music_failed: int = await music_suite.new().run()
	var menu_suite: Script = load("res://tests/menu_tests.gd")
	if menu_suite == null:
		push_error("FAIL: los tests de menu no compilan")
		quit(1)
		return
	var menu_failed: int = menu_suite.new().run()
	var coop_suite: Script = load("res://tests/coop_tests.gd")
	if coop_suite == null:
		push_error("FAIL: los tests de cooperativo no compilan")
		quit(1)
		return
	var coop_failed: int = await coop_suite.new().run()
	var io_suite: Script = load("res://tests/test_coop_io.gd")
	if io_suite == null:
		push_error("FAIL: los tests de caja negra/blanca no compilan")
		quit(1)
		return
	var io_failed: int = _run_mcp_suite(io_suite)
	var training_failed := _run_mcp_suite(load("res://tests/test_training.gd"))
	var layout_failed: int = load("res://tests/layout_lint_tests.gd").new().run(self)
	quit(1 if failed + broken + music_failed + menu_failed + coop_failed + io_failed + training_failed + layout_failed > 0 else 0)


func _run_mcp_suite(suite_script: Script) -> int:
	var suite: McpTestSuite = suite_script.new()
	var methods: Array = []
	for info: Dictionary in suite.get_method_list():
		var name: String = str(info.name)
		if name.begins_with("test_"):
			methods.append(name)
	methods.sort()
	suite.suite_setup({})
	if suite._suite_failed:
		push_error("FAIL setup: %s" % suite._suite_failed_message)
		return 1
	var failed := 0
	var passed := 0
	for name: String in methods:
		suite._reset()
		suite.setup()
		var returned: Variant = suite.call(name)
		if returned is Object and str(returned.get_class()) == "GDScriptFunctionState":
			failed += 1
			push_error("FAIL %s: el test no puede suspenderse" % name)
		elif suite._failed:
			failed += 1
			push_error("FAIL %s: %s" % [name, suite._message])
		elif suite._skipped:
			print("SKIP %s: %s" % [name, suite._skip_reason])
		else:
			passed += 1
		suite.teardown()
		suite._free_tracked()
	suite.suite_teardown()
	suite._free_tracked()
	print("%s: %d passed, %d failed" % [suite.suite_name(), passed, failed])
	return failed


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
