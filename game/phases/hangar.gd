extends Node2D

## Hangar: tablero de contratos, seguro, lecciones e inventario entre partidas.

const REROLL_COST := 100

var _rng := RandomNumberGenerator.new()
var _board: VBoxContainer
var _credit_label: Label
var _runs_label: Label
var _deliveries_label: Label
var _best_label: Label
var _players_label: Label
var _insurance_box: HBoxContainer
var _p1_lamp: Lamp
var _p2_lamp: Lamp
var _p2_hint: Label
var _join_button: Button
var _first_focus: Control
var _time: float = 0.0
var _home: Planet
var _moon: Planet


func _ready() -> void:
	_rng.randomize()
	Run.crew = clampi(Profile.crew, 1, 2)
	var stars := Starfield.new()
	add_child(stars)
	stars.set_sky(Color(0.016, 0.024, 0.06), 1.0)
	_build_backdrop()
	var root := Ui.root(self)
	var maker := Ui.panel(root)
	maker.add_theme_stylebox_override("panel", Ui.enamel())
	maker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	maker.offset_left = 40
	maker.offset_right = -40
	maker.offset_top = 24
	maker.offset_bottom = 134
	var maker_row := Ui.hbox(maker, 24)
	var brand := Ui.vbox(maker_row, 0)
	var title := Ui.label(brand, "Contratista Orbital", Ui.SIZE_HERO, Ui.BAKELITE)
	title.add_theme_font_override("font", Ui.bold())
	Ui.label(brand, "Arma barato. Vuela lejos. Apuesta todo.", Ui.SIZE_TEXT, Ui.BAKELITE)
	var maker_spacer := Control.new()
	maker_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maker_row.add_child(maker_spacer)
	_credit_label = Ui.readout(maker_row, "Créditos", "", 120.0)
	_runs_label = Ui.readout(maker_row, "Partidas", "", 100.0)
	_deliveries_label = Ui.readout(maker_row, "Entregas", "", 100.0)
	_best_label = Ui.readout(maker_row, "Mejor pago", "", 120.0)
	_players_label = Ui.readout(maker_row, "Jugadores", "", 110.0)
	var left := Ui.panel(root)
	Ui.place(left, Rect2(40, 170, 330, 0))
	var col := Ui.vbox(left, 8)
	Ui.legend(col, "Jugadores")
	_build_player_slots(col)
	Ui.legend(col, "Seguro de la nave")
	_insurance_box = Ui.hbox(col, 4)
	Ui.button(col, "Manual de vuelo", func() -> void: Tutorial.replay())
	Ui.legend(col, "Lecciones")
	if Profile.lessons.is_empty():
		var none := Ui.label(col, "Ninguna todavía. Se aprenden perdiendo naves.", Ui.SIZE_TEXT, Ui.IVORY_DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(300, 0)
	for id: String in Profile.lessons:
		var l := Ui.label(col, str(Profile.LESSONS[id]), Ui.SIZE_TEXT, Ui.IVORY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
	Ui.label(col, "Inventario: %d piezas guardadas" % Profile.inventory.size(), Ui.SIZE_TEXT, Ui.IVORY)
	var right := Ui.panel(root)
	right.set_anchors_preset(Control.PRESET_TOP_WIDE)
	right.offset_left = 400
	right.offset_right = -40
	right.offset_top = 170
	var board_col := Ui.vbox(right, 10)
	var head := Ui.hbox(board_col)
	Ui.plate(head, "Contratos")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	Ui.button(head, "Pedir contratos nuevos (%s)" % Ui.money(REROLL_COST), _reroll)
	_board = Ui.vbox(board_col, 10)
	_refresh()
	_update_players_ui()
	_focus_menu()
	Kinetic.enter_deferred(maker, 0.0, {"slide": true, "slide_offset": Vector2(-24.0, -14.0), "scale": Vector2(0.95, 0.90), "tilt": -0.015, "beam": true, "duration": 0.34})
	Kinetic.enter_deferred(left, 0.05, {"slide": true, "slide_offset": Vector2(-28.0, 16.0), "scale": Vector2(0.94, 0.90), "tilt": -0.022, "duration": 0.34})
	Kinetic.enter_deferred(right, 0.09, {"slide": true, "slide_offset": Vector2(-22.0, 20.0), "scale": Vector2(0.95, 0.91), "tilt": 0.016, "beam": true, "duration": 0.36})
	Synth.play(&"chime", -6.0)


func _build_player_slots(col: Node) -> void:
	var p1 := Ui.hbox(col, 8)
	Ui.label(p1, "P1 Comandante", Ui.SIZE_TEXT, Ui.IVORY)
	_p1_lamp = Lamp.new("Conectado", Lamp.GO)
	_p1_lamp.custom_minimum_size = Vector2(110, 26)
	_p1_lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p1.add_child(_p1_lamp)
	var p2 := Ui.hbox(col, 8)
	Ui.label(p2, "P2 Tripulante", Ui.SIZE_TEXT, Ui.IVORY)
	_p2_lamp = Lamp.new("Ausente", Lamp.OFF)
	_p2_lamp.custom_minimum_size = Vector2(110, 26)
	_p2_lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p2.add_child(_p2_lamp)
	_p2_hint = Ui.label(col, "", Ui.SIZE_LEGEND, Ui.INFO)
	_p2_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_p2_hint.custom_minimum_size = Vector2(300, 0)
	_join_button = Ui.button(col, "Unirse (jugador 2)", _toggle_join_button)
	_join_button.tooltip_text = "El segundo jugador pulsa A en el mando o J en el teclado. P1 pilota con el teclado."


func _refresh() -> void:
	_credit_label.text = Ui.money(Profile.credits)
	_runs_label.text = str(Profile.runs)
	_deliveries_label.text = str(Profile.wins)
	_best_label.text = Ui.money(Profile.best_payout)
	for child: Node in _insurance_box.get_children():
		child.queue_free()
	for i: int in Profile.INSURANCE_NAMES.size():
		var b := Ui.button(_insurance_box, Profile.INSURANCE_NAMES[i], _set_insurance.bind(i))
		b.tooltip_text = "Prima %d %% del valor de la nave, cubre %d %% si la pierdes." % [int(Profile.INSURANCE_PREMIUM[i] * 100.0 * (0.5 if Profile.has_lesson("seguro") else 1.0)), int(Profile.INSURANCE_COVER[i] * 100.0)]
		Ui.mark_selected(b, i == Profile.insurance)
	for child: Node in _board.get_children():
		child.queue_free()
	_first_focus = null
	var cards: Array = []
	for contract: Contract in Profile.board(_rng):
		cards.append(_contract_card(contract))
	Kinetic.cascade(cards, 0.045, 0.24, {"scale": Vector2(0.93, 0.86), "elastic": true, "beam": true, "duration": 0.32})
	_update_players_ui()


func _update_players_ui() -> void:
	var duo := Run.crew >= 2
	_players_label.text = str(Run.crew)
	_players_label.add_theme_color_override("font_color", Ui.LAMP_GO if duo else Ui.IVORY)
	_p1_lamp.text = "Conectado".to_upper()
	_p1_lamp.state = Lamp.GO
	if duo:
		_p2_lamp.text = "Conectado".to_upper()
		_p2_lamp.state = Lamp.GO
		_p2_hint.text = "Tripulante listo. En vuelo usa flechas o el mando. P1 pilota con el teclado. Pulsa B / K para salir."
		_p2_hint.add_theme_color_override("font_color", Ui.LAMP_GO)
		_join_button.text = "Desconectar jugador 2"
	else:
		_p2_lamp.text = "Esperando".to_upper()
		_p2_lamp.state = Lamp.CAUTION
		_p2_hint.text = "Pulsa A en el mando o J para unirte. P1 pilota con el teclado, como en un jugador."
		_p2_hint.add_theme_color_override("font_color", Ui.LAMP_CAUTION)
		_join_button.text = "Unirse (jugador 2)"


func _contract_card(contract: Contract) -> PanelContainer:
	var body := contract.body()
	var card := PanelContainer.new()
	var rest_style := Ui.box(Ui.BAKELITE_RAISED, Ui.BAKELITE_EDGE, 1, 4)
	var hover_style := Ui.box(Color(0.20, 0.21, 0.24), Ui.INFO, 1, 4)
	card.add_theme_stylebox_override("panel", rest_style)
	Kinetic.sync_pivot(card)
	card.mouse_entered.connect(func() -> void:
		card.add_theme_stylebox_override("panel", hover_style)
		Kinetic.pop(card, Vector2(1.015, 1.015), 0.16))
	card.mouse_exited.connect(func() -> void:
		card.add_theme_stylebox_override("panel", rest_style))
	_board.add_child(card)
	var row := Ui.hbox(card, 16)
	row.add_child(_planet_icon(body))
	var info := Ui.vbox(row, 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.label(info, contract.title, 18, Ui.IVORY)
	if body != null:
		Ui.label(info, body.description, 13, Ui.IVORY_DIM)
		Ui.label(info, "Delta-v estimado %d m/s, plazo %d días" % [int(contract.dv_estimate), int(contract.deadline)], Ui.SIZE_LEGEND, Ui.INFO)
	if contract.hidden_hazard != &"":
		info.add_child(Lamp.new("Rumores de peligro", Lamp.CAUTION))
	var money := Ui.vbox(row, 2)
	Ui.label(money, Ui.money(contract.payout), 24, Ui.IVORY)
	Ui.label(money, "Adelanto %s" % Ui.money(contract.advance), 13, Ui.IVORY_DIM)
	Ui.label(money, "Presupuesto %s" % Ui.money(Profile.budget(contract)), 13, Ui.LAMP_GO)
	var accept := Ui.primary(Ui.button(row, "Aceptar contrato", _accept.bind(contract)))
	accept.custom_minimum_size = Vector2(170, 44)
	accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _first_focus == null:
		_first_focus = accept
	return card


func _focus_menu() -> void:
	if _first_focus != null and is_instance_valid(_first_focus):
		_first_focus.grab_focus()
	elif _join_button != null:
		_join_button.grab_focus()


func _planet_icon(body: BodyDef) -> Control:
	if body == null:
		var blank := Control.new()
		blank.custom_minimum_size = Vector2(56, 56)
		return blank
	var icon := Planet.make(body, 46.0)
	icon.custom_minimum_size = Vector2(58, 58)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _set_insurance(level: int) -> void:
	Profile.insurance = level
	Profile.save_profile()
	_refresh()
	_focus_menu()


func _toggle_join_button() -> void:
	_set_crew(1 if Run.crew >= 2 else 2)


func _set_crew(count: int) -> void:
	var next := clampi(count, 1, 2)
	if next == Run.crew:
		return
	Run.crew = next
	Profile.crew = next
	Profile.save_profile()
	Synth.play(&"chime" if next >= 2 else &"beep")
	Events.toast.emit("2 jugadores conectados" if next >= 2 else "1 jugador conectado", Ui.LAMP_GO if next >= 2 else Ui.IVORY_DIM)
	Juice.flash(Ui.LAMP_GO if next >= 2 else Ui.IVORY, 0.25)
	_update_players_ui()


func _reroll() -> void:
	if Profile.credits < REROLL_COST:
		Synth.play(&"deny")
		return
	Profile.credits -= REROLL_COST
	Profile.clear_board()
	Synth.play(&"coin")
	_refresh()
	_focus_menu()


func _accept(contract: Contract) -> void:
	Run.begin(contract)
	Synth.play(&"ignite", -6.0)
	Router.go(&"assembly")


func _process(delta: float) -> void:
	_time += delta
	if Controls.join_just() and Run.crew < 2:
		_set_crew(2)
	elif Controls.leave_just() and Run.crew >= 2:
		_set_crew(1)
	queue_redraw()


## Casa al fondo de la ventana, con su luna pasando por delante y por detras.
func _build_backdrop() -> void:
	var home := Catalog.home()
	var moon_def := Catalog.body(&"luna")
	if home == null or moon_def == null:
		return
	_home = Planet.make(home, 560.0)
	add_child(_home)
	_moon = Planet.make(moon_def, 48.0)
	add_child(_moon)


func _draw() -> void:
	if _home == null:
		return
	var view := get_viewport_rect().size
	var center := Vector2(view.x * 0.82, view.y * 1.05)
	_home.position = center - _home.size * 0.5
	var a := _time * 0.25
	var moon := center + Vector2(cos(a), sin(a) * 0.35) * 420.0
	_moon.position = moon - _moon.size * 0.5
	_moon.visible = sin(a) < 0.0 or absf(moon.x - center.x) > 280.0
	for k: int in 4:
		var ta := -a * 2.3 + float(k + 1) * 0.08
		var trail := center + Vector2(cos(ta), sin(ta) * 0.3) * 320.0
		draw_circle(trail, 2.2 - float(k) * 0.35, Color(1.4, 1.9, 2.6, 0.45 - float(k) * 0.1))
	var ship := center + Vector2(cos(-a * 2.3), sin(-a * 2.3) * 0.3) * 320.0
	draw_circle(ship, 3.0, Color(3.0, 2.4, 1.6))
