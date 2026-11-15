extends SceneTree

## Uso: godot --headless --path . --script res://tests/smoke_runner.gd
## Recorre todas las fases llamando a sus metodos; los errores salen como SCRIPT ERROR.
## En cada parada pasa el lint de maquetacion (tests/layout_lint.gd) y sale con 1 si hay hallazgos.
## Tamano y jugadores por entorno, una ejecucion por combinacion:
##   SMOKE_SIZE=1355x720 SMOKE_CREW=2 godot --headless --path . --script res://tests/smoke_runner.gd


func _initialize() -> void:
	await process_frame
	root.get_node("Profile").persistence_enabled = false
	var size_text := OS.get_environment("SMOKE_SIZE")
	if size_text != "":
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.size = Vector2i(int(size_text.get_slice("x", 0)), int(size_text.get_slice("x", 1)))
		await process_frame
	var smoke: RefCounted = load("res://tests/smoke.gd").new()
	smoke.crew = maxi(int(OS.get_environment("SMOKE_CREW")), 1)
	await smoke.run(self)
	var view := root.get_visible_rect().size
	for line: String in smoke.findings:
		print("LAYOUT %dx%d p%d [%s] %s" % [int(view.x), int(view.y), smoke.crew, smoke.findings[line], line])
	print("LAYOUT: %d hallazgos" % smoke.findings.size())
	print("SMOKE DONE")
	quit(1 if not smoke.findings.is_empty() else 0)
