class_name SettingsPanel
extends Modal

## Ajustes: volumen y idioma (Settings) y accesibilidad (Profile). El mismo panel en title, pausa y engranaje.

## Nombre de cada idioma en su propio idioma: no se traduce.
const LANGUAGE_NAMES: Dictionary = {"en": "English", "es": "Español"}


static func show_panel() -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel.open()
	return panel


func _init() -> void:
	super(tr("Ajustes"))
	Ui.legend(col, tr("Audio"))
	_slider(tr("General"), &"master")
	_slider(tr("Música"), &"music")
	_slider(tr("Efectos"), &"sfx")
	Ui.legend(col, tr("Idioma"))
	_language_row()
	Ui.legend(col, tr("Accesibilidad"))
	_switch(tr("Movimiento reducido"), &"reduced_motion", tr("Sin sacudidas, destellos ni lámparas intermitentes."))
	var arcade := _switch(tr("Modo Fácil Arcade"), &"arcade", tr("Navegación espacial con WASD sin gravedad (con inercia) y aterrizaje directo ajustando trayectoria con motores WASD."))
	var assist := _switch(tr("Modo asistido"), &"assist", tr("Menos averías, más kits, corredores más anchos y navegación asistida (N). El contrato paga un 15 % menos."))
	# Con un contrato en curso no se cambia: se podria volar asistido y cobrar el pago completo.
	if Router.current != &"title" and Router.current != &"hangar":
		arcade.disabled = true
		assist.disabled = true
		var hint := Ui.label(col, tr("El modo asistido se cambia en el hangar, no con un contrato en curso."), Ui.SIZE_LEGEND, Ui.IVORY_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_back()
	closed.connect(Settings.save)


## Selector de idioma: una tecla por idioma, la activa marcada. Solo se cambia en el titulo o el hangar:
## ahi la pantalla se reconstruye entera y no se ven textos mezclados ni se reinicia una fase.
func _language_row() -> void:
	var can_change := Router.current == &"title" or Router.current == &"hangar"
	var row := Ui.hbox(col, 6)
	for code: String in Settings.LANGUAGES:
		var b := Ui.button(row, LANGUAGE_NAMES[code], _pick_language.bind(code))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not can_change
		Ui.mark_selected(b, code == Settings.language)
	if not can_change:
		var hint := Ui.label(col, tr("El idioma se cambia en el título o en el hangar, no con un contrato en curso."), Ui.SIZE_LEGEND, Ui.IVORY_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _pick_language(code: String) -> void:
	if Router.is_busy() or not Settings.set_language(code):
		return
	Settings.save()
	# Se recarga la pantalla actual (los contratos viven en el Profile, no se vuelven a sortear) y se
	# reabre este panel ya en el idioma nuevo.
	Events.phase_changed.connect(func(_id: StringName) -> void: SettingsPanel.show_panel(), CONNECT_ONE_SHOT)
	Router.go(Router.current)


func _slider(text: String, key: StringName) -> void:
	var row := Ui.hbox(col, 6)
	Ui.label(row, text, Ui.SIZE_TEXT, Ui.IVORY).custom_minimum_size = Vector2(90, 0)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.get(key))
	slider.custom_minimum_size.x = 220
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := Ui.label(row, "%d %%" % roundi(slider.value * 100.0), Ui.SIZE_TEXT, Ui.IVORY)
	value.add_theme_font_override("font", Ui.mono())
	value.custom_minimum_size.x = 52
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set(key, v)
		Settings.apply_audio()
		value.text = "%d %%" % roundi(v * 100.0)
		Synth.play(&"tick"))
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.save())


## Interruptor de un bool de Profile: tecla con su lampara de estado al lado.
func _switch(text: String, key: StringName, tip: String) -> Button:
	var row := Ui.hbox(col, 6)
	var lamp := Lamp.new()
	lamp.custom_minimum_size = Vector2(84, 26)
	lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var paint := func() -> void:
		var on: bool = Profile.get(key)
		lamp.text = (tr("Activo") if on else tr("Apagado")).to_upper()
		lamp.state = Lamp.GO if on else Lamp.OFF
	var button := Ui.button(row, text, func() -> void:
		Profile.set(key, not Profile.get(key))
		Profile.save_profile()
		paint.call())
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = tip
	row.add_child(lamp)
	paint.call()
	return button
