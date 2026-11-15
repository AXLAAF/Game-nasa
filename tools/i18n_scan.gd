extends SceneTree

## Recorre las fases en un idioma y vuelca los textos visibles para revisar la traduccion.
##   I18N_LANG=en I18N_DIR=/ruta godot --path . --script res://tools/i18n_scan.gd
## Con ventana (no --headless) tambien guarda una captura por pantalla. Escribe user://i18n_<idioma>.txt
## y marca con "??" lo que en ingles todavia parece espanol. Juega una partida de prueba: cambia el perfil.


func _initialize() -> void:
	await process_frame
	var body: Script = load("res://tools/i18n_scan_run.gd")
	var code: int = await body.new().run(self)
	quit(code)
