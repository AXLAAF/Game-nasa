extends Node2D

var _planet: Planet


func _ready() -> void:
	var stars := Starfield.new()
	add_child(stars)
	stars.set_sky(Color(0.016, 0.024, 0.06), 1.0)
	var home := Catalog.home()
	if home != null:
		_planet = Planet.make(home, 560.0)
		add_child(_planet)
	var root := Ui.root(self)
	var col := Ui.vbox(root, 10)
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 96
	col.offset_right = 96
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	var title := Ui.label(col, "Margin Zero", Ui.SIZE_HERO * 2, Ui.IVORY)
	title.add_theme_font_override("font", Ui.bold())
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	col.add_child(spacer)
	var training := Ui.button(col, "Repetir práctica de montaje" if Profile.training_completed else "Primera misión: armar la nave", func() -> void: Router.go(&"training"))
	if not Profile.training_completed:
		Ui.primary(training)
	var new_game := Ui.primary(Ui.button(col, "Nueva partida", _new_game))
	var settings := Ui.button(col, "Ajustes", func() -> void: SettingsPanel.show_panel())
	var credits := Ui.button(col, "Créditos", _credits)
	for button: Button in [training, new_game, settings, credits]:
		button.custom_minimum_size.x = 260
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not OS.has_feature("web"):
		var quit := Ui.button(col, "Salir", func() -> void: get_tree().quit())
		quit.custom_minimum_size.x = 260
		quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	(new_game if Profile.training_completed else training).grab_focus.call_deferred()
	Kinetic.enter_deferred(col, 0.0, {"duration": 0.36})
	Synth.play(&"chime", -6.0)


func _process(_delta: float) -> void:
	if _planet == null:
		return
	var view := get_viewport_rect().size
	_planet.position = Vector2(view.x * 0.82, view.y * 1.05) - _planet.size * 0.5


func _new_game() -> void:
	var modal := Modal.new("Nueva partida")
	var warn := Ui.label(modal.col, "Se reiniciará el perfil actual (créditos, lecciones, inventario y contratos). Elige un modo:", Ui.SIZE_TEXT, Ui.IVORY)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.custom_minimum_size = Vector2(460, 0)
	var arcade_btn := Ui.primary(Ui.button(modal.col, "Modo Fácil Arcade (Recomendado)", func() -> void:
		modal.close()
		_start(true)))
	var arcade_note := Ui.label(modal.col, "Navegación espacial libre con WASD sin gravedad (con inercia) y descenso directo ajustando tu trayectoria con los motores en WASD.", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	arcade_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arcade_note.custom_minimum_size = Vector2(460, 0)
	Ui.button(modal.col, "Simulación original", func() -> void:
		modal.close()
		_start(false))
	var sim_note := Ui.label(modal.col, "Física orbital original.", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	sim_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sim_note.custom_minimum_size = Vector2(460, 0)
	modal.add_back("Cancelar")
	modal.open()
	arcade_btn.grab_focus()


func _start(is_arcade: Variant = null) -> void:
	var arcade_mode := Profile.arcade if is_arcade == null else bool(is_arcade)
	var assist := Profile.assist if is_arcade == null else false
	var reduced_motion := Profile.reduced_motion
	var training_completed := Profile.training_completed
	Profile.reset()
	Profile.arcade = arcade_mode
	Profile.assist = assist
	Profile.reduced_motion = reduced_motion
	Profile.training_completed = training_completed
	Profile.save_profile()
	Router.go(&"hangar")


func _credits() -> void:
	var modal := Modal.new("Créditos")
	for text: String in [
		"Margin Zero",
		"Hecho para NASA Space Apps Challenge, reto Space Mission Design Game.",
		"Datos abiertos: NASA Planetary Fact Sheet (NSSDCA), JPL Small-Body Database, NASA DONKI y NASA Deep Space Network.",
		"Tipografía B612 y B612 Mono, SIL Open Font License.",
		"Hecho con Godot Engine, licencia MIT.",
	]:
		var label := Ui.label(modal.col, text, Ui.SIZE_TEXT, Ui.IVORY)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 440
	modal.add_back()
	modal.open()
