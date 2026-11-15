extends Node2D

## Adaptador de entrada y presentación. La práctica jugable es solo el montaje.
const BRIEF := "Ignición: pulsa Espacio cuando la aguja entre en el verde del reloj. Antes de tiempo no enciende.\n\nInclina la nave hacia el arco verde. Ese giro da velocidad de lado; sin ella sube y vuelve a caer.\n\nSepara con Espacio cuando se acabe el combustible de la etapa activa. Hacerlo antes tira combustible que aún servía. La etapa de arriba usa su propio motor y su propio tanque.\n\nEn el espacio, modo realista: la nave no se frena sola. Cae siempre; si vas bastante de lado, el planeta se curva y no lo tocas. Eso es una órbita. Empujar a favor del movimiento sube el lado opuesto. Empujar en contra lo baja y puedes volver a caer."
var session: TrainingSession
var _pending: Array[PlayerCommand] = []
var _accumulator := 0.0
var _title: Label
var _instructions: Label
var _feedback: Label
var _telemetry: Label
var _progress: Label
var _catalog: VBoxContainer
var _catalog_scroll: ScrollContainer
var _part_buttons: Dictionary = {}
var _stack: ItemList
var _stack_controls: HBoxContainer
var _canvas: Control
var _confirm: Button
var _repair: Button
var _chute: Button
var _flight_controls: HBoxContainer
var _axis_down: Button
var _axis_up: Button
var _report: Label
var _report_scroll: ScrollContainer
var _selected := -1
var _stack_signature := ""
var _suggested := ""
var _saved_completion := false
var _button_axis := 0.0
var _button_steer := 0.0
var _leaving := false

func _ready() -> void:
	session = TrainingData.create_session()
	get_viewport().size_changed.connect(queue_redraw)
	_build_ui()
	_refresh()

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("080e1b"))

func _build_ui() -> void:
	var root := Ui.root(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	for edge: String in ["left", "right"]: # la cabecera empieza a la derecha del engranaje
		margin.add_theme_constant_override("margin_" + edge, int(Pause.GEAR_RECT.end.x) + 12)
	root.add_child(margin)
	var page := Ui.vbox(margin, 12)
	var header := Ui.hbox(page, 16)
	var heading := Ui.vbox(header, 4)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.label(heading, "BALLAST-1: Primera misión", 24, Ui.IVORY)
	_progress = Ui.label(heading, "", 13, Ui.INFO)
	Ui.button(header, "Reiniciar montaje", func() -> void: _send(&"retry"))
	Ui.button(header, "Salir de práctica", func() -> void: Router.go(&"hangar"))
	var columns := Ui.hbox(page, 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := Ui.panel(columns)
	left.custom_minimum_size.x = 320
	var lesson := Ui.vbox(left, 10)
	_title = Ui.label(lesson, "", 20, Ui.INFO)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instructions = Ui.label(lesson, "", 15, Ui.IVORY)
	_instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback = Ui.label(lesson, "", 14, Ui.LAMP_CAUTION)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lesson.add_child(_catalog_scroll)
	_catalog = Ui.vbox(_catalog_scroll, 4)
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in session.design.catalog:
		var def: PartDef = session.definitions[id]
		var button := Ui.button(_catalog, def.display_name, func() -> void: _pending.append(PlayerCommand.new(&"add", 0, StringName(id))))
		button.custom_minimum_size.y = 34
		button.tooltip_text = "%s\nMasa %.1f t; coste %d cr [DIS]." % [def.description, def.mass, def.cost]
		_part_buttons[id] = button
	var middle := Ui.vbox(columns, 8)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(300, 180)
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_ship)
	middle.add_child(_canvas)
	_stack = ItemList.new()
	_stack.custom_minimum_size.y = 200
	_stack.add_theme_font_size_override("font_size", 13)
	_stack.item_selected.connect(func(index: int) -> void: _selected = index)
	middle.add_child(_stack)
	_stack_controls = Ui.hbox(middle, 4)
	Ui.button(_stack_controls, "Hacia la base", func() -> void: _move(-1))
	Ui.button(_stack_controls, "Hacia la cima", func() -> void: _move(1))
	Ui.button(_stack_controls, "Retirar", func() -> void:
		if _selected >= 0:
			_pending.append(PlayerCommand.new(&"remove", 0, &"", _selected)))
	var right := Ui.panel(columns)
	right.custom_minimum_size.x = 260
	var readouts := Ui.vbox(right, 10)
	Ui.label(readouts, "Telemetría de práctica [DIS]", 14, Ui.INFO)
	_telemetry = Ui.label(readouts, "", 13, Ui.IVORY)
	_telemetry.add_theme_font_override("font", Ui.mono())
	_report_scroll = ScrollContainer.new()
	_report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	readouts.add_child(_report_scroll)
	_report = Ui.label(_report_scroll, "", 13, Ui.IVORY_DIM)
	_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := Ui.vbox(page, 6)
	_flight_controls = Ui.hbox(footer, 6)
	_axis_down = _hold_button(_flight_controls, "Menos potencia", -1, false)
	_axis_up = _hold_button(_flight_controls, "Más potencia", 1, false)
	_hold_button(_flight_controls, "Girar izquierda (%s)" % _binding(&"cmd_steer_left"), -1, true)
	_hold_button(_flight_controls, "Girar derecha (%s)" % _binding(&"cmd_steer_right"), 1, true)
	var actions := Ui.hbox(footer, 8)
	_confirm = Ui.primary(Ui.button(actions, "", _on_confirm))
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_repair = Ui.button(actions, "Reparar", func() -> void: _send(&"repair"))
	_chute = Ui.button(actions, "Paracaídas", func() -> void: _send(&"parachute"))
	Ui.label(footer, "Solo se arma la nave. No gasta créditos ni piezas del perfil.", 12, Ui.IVORY_DIM)

func _hold_button(parent: Node, text: String, direction: float, steering: bool) -> Button:
	var button := Ui.button(parent, text, func() -> void: pass)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.button_down.connect(func() -> void:
		if steering: _button_steer = direction
		else: _button_axis = direction)
	button.button_up.connect(func() -> void:
		if steering: _button_steer = 0.0
		else: _button_axis = 0.0)
	return button

func _move(offset: int) -> void:
	if _selected >= 0:
		_pending.append(PlayerCommand.new(&"move", _selected + offset, &"", _selected))

func _send(action: StringName) -> void:
	_pending.append(PlayerCommand.new(action))

func _on_confirm() -> void:
	if _leaving:
		return
	if session.phase() == "assembly" and session.assembly().ready:
		_leaving = true
		Profile.complete_training()
		Router.go(&"hangar")
		return
	if session.phase() != "assembly":
		_send(&"confirm")

func _process(delta: float) -> void:
	if _leaving or Modal.busy():
		_accumulator = 0.0
		return
	# La entrada discreta se consume una vez; los ejes se muestrean por tick.
	if Controls.cmd_just(&"cmd_confirm"):
		_on_confirm()
	for pair: Array in [[&"cmd_repair", &"repair"], [&"cmd_parachute", &"parachute"]]:
		if Controls.cmd_just(pair[0]):
			_send(pair[1])
	_accumulator += delta * float(session.design.play_speed)
	while _accumulator >= TrainingSession.DT:
		var commands: Array[PlayerCommand] = _pending.duplicate()
		_pending.clear()
		commands.append(PlayerCommand.new(&"throttle", clampf(Controls.throttle_axis() + _button_axis, -1.0, 1.0)))
		commands.append(PlayerCommand.new(&"steer", clampf(Controls.steer() + _button_steer, -1.0, 1.0)))
		session.tick(commands)
		_accumulator -= TrainingSession.DT
	_refresh()
	if session.phase() == "complete" and not _saved_completion:
		_saved_completion = true
		Profile.complete_training()

func _binding(action: StringName) -> String:
	var names: PackedStringArray = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			names.append(event.as_text().replace(" (Physical)", ""))
			break
	return " / ".join(names)

func _refresh() -> void:
	var phase := session.phase()
	var assembling := phase == "assembly"
	var lesson: Dictionary = session.design.lessons[phase]
	_title.text = lesson.title
	_instructions.text = lesson.text
	var guide := session.assembly()
	if assembling and guide.ready:
		_title.text = "Nave lista"
		_instructions.text = "El montaje cumple. A la derecha está, en corto, la ignición, el arco verde, la separación y la órbita del modo realista."
		_feedback.text = ""
	elif assembling:
		_title.text = "%d. %s" % [mini(int(guide.index) + 1, session.design.recipe.size()), guide.title]
		_instructions.text = "%s\n\nPosiciones desde la base hacia la cima." % guide.why
		_feedback.text = guide.error
	else:
		_feedback.text = session.state.message
		if phase == "ascent" and session.ship.can_stage() and _feedback.text.is_empty():
			var capacity := 0.0
			for part: ShipPart in session.ship.active_stage():
				capacity += part.def.fuel * part.boost
			if session.ship.stage_fuel(session.ship.active_stage()) <= capacity * float(session.design.low_fuel_fraction):
				_feedback.text = "Queda poco combustible ACTIVO. Prepara la separación; espera a que se agote."
	_catalog_scroll.visible = assembling
	_stack.visible = assembling
	_stack_controls.visible = assembling
	_flight_controls.visible = not assembling and phase not in ["complete", "failed"]
	_axis_down.text = "%s (%s)" % ["Entrada más inclinada" if phase == "entry" else "Menos potencia", _binding(&"cmd_throttle_down")]
	_axis_up.text = "%s (%s)" % ["Entrada más plana" if phase == "entry" else "Más potencia", _binding(&"cmd_throttle_up")]
	_progress.text = "Práctica de montaje | %s" % ("Completada" if Profile.training_completed else "Arma la nave sin arriesgar la campaña")
	for id: String in _part_buttons:
		var button: Button = _part_buttons[id]
		Ui.mark_selected(button, id == guide.part)
		button.text = ("Siguiente: " if id == guide.part else "") + session.definitions[id].display_name
	if assembling and guide.part != _suggested:
		_suggested = guide.part
		if _part_buttons.has(_suggested):
			_catalog_scroll.ensure_control_visible.call_deferred(_part_buttons[_suggested])
	var signature := ""
	for part: ShipPart in session.ship.parts:
		signature += String(part.def.id) + ";"
	if signature != _stack_signature:
		_stack_signature = signature
		_stack.clear()
		for i: int in session.ship.parts.size():
			_stack.add_item("%d. %s" % [i + 1, session.ship.parts[i].def.display_name])
		_selected = -1
	var actions := {"countdown": "Ignición", "ascent": "Separar etapa", "stage_ready": "Separar etapa", "stage_repaired": "Reintentar separación", "orbit": "Iniciar regreso", "entry": "Entrar en atmósfera"}
	var label := "Terminar práctica" if guide.ready else "Completa el montaje"
	if not assembling:
		label = String(actions.get(phase, "Completa la acción indicada"))
	_confirm.text = "%s (%s)" % [label, _binding(&"cmd_confirm")]
	_confirm.disabled = (assembling and not guide.ready) or (not assembling and not actions.has(phase))
	_confirm.visible = phase not in ["complete", "failed"]
	_repair.text = "Reparar (%s)" % _binding(&"cmd_repair")
	_repair.disabled = phase != "jammed"
	_repair.visible = not assembling and phase not in ["complete", "failed"]
	_chute.text = "Paracaídas (%s)" % _binding(&"cmd_parachute")
	_chute.disabled = phase not in ["descent", "drogue_ready", "main_ready"]
	_chute.visible = not assembling and phase not in ["complete", "failed"]
	var ship := session.ship
	var flight: Dictionary = session.state.flight
	var cost := 0
	var shield := 0.0
	for part: ShipPart in ship.parts:
		cost += part.def.cost
		shield += part.ablative
	_telemetry.text = "Etapas: %d\nMasa: %.1f t\nTWR: %.2f\nDelta-v: %d m/s\nCoste de diseño: %d cr\n\nCombustible ACTIVO: %.2f t\nCombustible TOTAL: %.2f t\n\nAltitud: %.1f km\nVelocidad: %.0f m/s\nPresión: %.1f kPa\nPotencia: %d %%\nCabeceo: %.0f°\nObjetivo: %.0f°\nBatería: %.1f\nEscudo: %.1f\nT-%.1f" % [ship.stages().size(), ship.mass(), ship.twr(session.body.surface_gravity), int(ship.delta_v()), cost, ship.stage_fuel(ship.active_stage()), ship.fuel_total(), float(flight.h) / 1000.0, Vector2(flight.vx, flight.vy).length(), float(flight.q) / 1000.0, int(session.state.throttle * 100), session.state.pitch, -90.0 if phase in ["retrograde", "deorbit"] else session.target_pitch(), session.state.battery, shield, session.state.countdown]
	if phase == "entry":
		_telemetry.text += "\nEntrada: %.1f°\nCorredor: %.0f° a %.0f°" % [session.state.entry_angle, session.design.entry_min, session.design.entry_max]
	var notes := "\n".join(session.state.log)
	var show_brief: bool = bool(assembling) and bool(guide.ready)
	_report.text = BRIEF + "\n\n" + notes if show_brief else notes
	_report.add_theme_font_size_override("font_size", 15 if show_brief else 13)
	_report.add_theme_color_override("font_color", Ui.IVORY if show_brief else Ui.IVORY_DIM)
	_canvas.queue_redraw()

func _draw_ship() -> void:
	var rect := Rect2(Vector2.ZERO, _canvas.size)
	_canvas.draw_rect(rect, Color("101b28"))
	var center := _canvas.size * Vector2(0.5, 0.55)
	if session.ship.parts.is_empty():
		_canvas.draw_string(Ui.sans(), center - Vector2(130, 0), "Coloca el motor en la base", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.INFO)
		return
	var bounds := ShipRenderer.bounds(session.ship.parts)
	var scale_factor := minf((_canvas.size.y - 60.0) / maxf(bounds.size.y, 1.0), 1.0)
	var angle := 0.0 if session.phase() == "assembly" else deg_to_rad(session.state.pitch)
	var transform := Transform2D(angle, center).scaled_local(Vector2.ONE * scale_factor)
	transform = transform.translated_local(-bounds.get_center())
	_canvas.draw_set_transform_matrix(transform)
	var flying := session.phase() in ["ascent", "deorbit", "descent"]
	ShipRenderer.draw(_canvas, session.ship.parts, {"active": session.ship.active_stage(), "flame": session.state.throttle if flying else 0.0, "chute": session.state.chute})
	if session.phase() == "assembly":
		var index := int(session.assembly().index)
		var layouts := ShipRenderer.layout(session.ship.parts)
		var slot: Rect2 = layouts[index] if index < layouts.size() else Rect2(bounds.position.x, bounds.position.y - 28.0, bounds.size.x, 24.0)
		if not session.assembly().ready:
			_canvas.draw_rect(slot.grow(4), Ui.INFO, false, 2.0)
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	_canvas.draw_string(Ui.sans(), Vector2(12, 24), "Base abajo, cabina arriba" if session.phase() == "assembly" else "MZ-1 BALLAST: práctica", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.IVORY)
	if session.phase() == "assembly":
		var guide := session.assembly()
		_canvas.draw_string(Ui.sans(), Vector2(12, _canvas.size.y - 12), "Montaje listo" if guide.ready else "Siguiente posición: %d desde la base" % (int(guide.index) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Ui.INFO)
	elif session.phase() == "entry":
		var start := Vector2(20, _canvas.size.y - 55)
		var width := _canvas.size.x - 40.0
		_canvas.draw_line(start, start + Vector2(width, 0), Ui.IVORY_DIM, 4)
		var lo := (float(session.design.entry_min) + 30.0) / 29.0
		var hi := (float(session.design.entry_max) + 30.0) / 29.0
		_canvas.draw_line(start + Vector2(width * lo, 0), start + Vector2(width * hi, 0), Ui.LAMP_GO, 12)
		var marker := start + Vector2(width * (session.state.entry_angle + 30.0) / 29.0, 0)
		_canvas.draw_line(marker - Vector2(0, 15), marker + Vector2(0, 15), Ui.IVORY, 3)
		_canvas.draw_string(Ui.sans(), start + Vector2(0, 35), "Inclinado                     Plano", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.IVORY)
	elif session.phase() in ["ascent", "steering", "retrograde", "deorbit"]:
		var dial := Vector2(_canvas.size.x - 80, _canvas.size.y - 90)
		var target := deg_to_rad(-90.0 if session.phase() in ["retrograde", "deorbit"] else session.target_pitch()) - PI * 0.5
		var actual := deg_to_rad(session.state.pitch) - PI * 0.5
		_canvas.draw_arc(dial, 50, 0, TAU, 48, Ui.IVORY_DIM, 2)
		var tolerance := deg_to_rad(float(session.design.corridor_tolerance))
		_canvas.draw_arc(dial, 45, target - tolerance, target + tolerance, 12, Ui.LAMP_GO, 8)
		_canvas.draw_line(dial, dial + Vector2.from_angle(actual) * 45, Ui.IVORY, 3)
		_canvas.draw_string(Ui.sans(), dial + Vector2(-45, 70), "Corredor", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.IVORY)
