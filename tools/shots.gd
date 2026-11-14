extends SceneTree

## Uso: SHOTS_DIR=/ruta godot --path . --script res://tools/shots.gd
## Guarda una captura por fase (mas carta y tutorial) para revisar el diseno. No toca el perfil guardado.
## El cuerpo se carga en ejecucion para que los autoloads ya existan (igual que tests/test_runner.gd).


func _initialize() -> void:
	await process_frame
	var body: Script = load("res://tools/shots_run.gd")
	await body.new().run(self)
	quit(0)
