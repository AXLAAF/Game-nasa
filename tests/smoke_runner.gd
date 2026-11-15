extends SceneTree

## Uso: godot --headless --path . --script res://tests/smoke_runner.gd
## Recorre todas las fases llamando a sus metodos; los errores salen como SCRIPT ERROR.


func _initialize() -> void:
	await process_frame
	root.get_node("Profile").persistence_enabled = false
	var smoke: Script = load("res://tests/smoke.gd")
	await smoke.new().run(self)
	print("SMOKE DONE")
	quit(0)
