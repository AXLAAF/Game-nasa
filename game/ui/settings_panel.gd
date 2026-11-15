class_name SettingsPanel
extends Modal

## Ajustes: volumen (Settings) y accesibilidad (Profile). El mismo panel en title, pausa y engranaje.


static func show_panel() -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel.open()
	return panel


func _init() -> void:
	super("Ajustes")
	Ui.legend(col, "Audio")
	_slider("General", &"master")
	_slider("Música", &"music")
	_slider("Efectos", &"sfx")
	Ui.legend(col, "Accesibilidad")
	_switch("Movimiento reducido", &"reduced_motion", "Sin sacudidas, destellos ni lámparas intermitentes.")
	var assist := _switch("Modo asistido", &"assist", "Menos averías, más kits, corredores más anchos y navegación asistida (N). El contrato paga un 15 % menos.")
	# Con un contrato en curso no se cambia: se podria volar asistido y cobrar el pago completo.
	if Router.current != &"title" and Router.current != &"hangar":
		assist.disabled = true
		var hint := Ui.label(col, "El modo asistido se cambia en el hangar, no con un contrato en curso.", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_back()
	closed.connect(Settings.save)


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
		lamp.text = ("Activo" if on else "Apagado").to_upper()
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
