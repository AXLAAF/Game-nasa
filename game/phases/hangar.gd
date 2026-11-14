extends Node2D

## Hangar: tablero de contratos, seguro, lecciones e inventario entre partidas.

const REROLL_COST := 100

var _rng := RandomNumberGenerator.new()
var _board: VBoxContainer
var _credit_label: Label
var _runs_label: Label
var _deliveries_label: Label
var _best_label: Label
var _insurance_box: HBoxContainer
var _reset_armed: bool = false
var _time: float = 0.0
var _home: Planet
var _moon: Planet


func _ready() -> void:
	_rng.randomize()
	var stars := Starfield.new()
	add_child(stars)
	stars.set_sky(Color(0.01, 0.015, 0.04), 1.0)
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
	var left := Ui.panel(root)
	Ui.place(left, Rect2(40, 170, 330, 0))
	var col := Ui.vbox(left, 8)
	Ui.legend(col, "Seguro de la nave")
	_insurance_box = Ui.hbox(col, 4)
	Ui.legend(col, "Ajustes")
	_switch(col, "Modo asistido", Profile.assist, _toggle_assist).tooltip_text = "Menos averías, más kits, corredores más anchos y navegación asistida (N). El contrato paga un 15 % menos."
	_switch(col, "Movimiento reducido", Profile.reduced_motion, _toggle_motion).tooltip_text = "Sin sacudidas, destellos ni lámparas intermitentes."
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
	var reset := Ui.button(col, "Reiniciar perfil", func() -> void: pass)
	reset.pressed.connect(func() -> void:
		if _reset_armed:
			Profile.reset()
			Router.go(&"hangar")
		else:
			_reset_armed = true
			reset.text = "¿Seguro? Pulsa otra vez para borrar todo")
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
	Synth.play(&"chime", -6.0)


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
	for contract: Contract in Profile.board(_rng):
		_contract_card(contract)


func _contract_card(contract: Contract) -> void:
	var body := contract.body()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.box(Ui.BAKELITE_RAISED, Ui.BAKELITE_EDGE, 1, 4))
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


## Interruptor: tecla con su lampara de estado al lado.
func _switch(parent: Node, text: String, on: bool, callback: Callable) -> Button:
	var row := Ui.hbox(parent, 6)
	var b := Ui.button(row, text, callback)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var lamp := Lamp.new("Activo" if on else "Apagado", Lamp.GO if on else Lamp.OFF)
	lamp.custom_minimum_size = Vector2(84, 26)
	lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lamp)
	return b


func _planet_icon(body: BodyDef) -> Control:
	if body == null:
		var blank := Control.new()
		blank.custom_minimum_size = Vector2(56, 56)
		return blank
	var icon := Planet.make(body, 56.0)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _toggle_motion() -> void:
	Profile.reduced_motion = not Profile.reduced_motion
	Profile.save_profile()
	Router.go(&"hangar")


func _set_insurance(level: int) -> void:
	Profile.insurance = level
	Profile.save_profile()
	_refresh()


func _toggle_assist() -> void:
	Profile.assist = not Profile.assist
	Profile.save_profile()
	Synth.play(&"beep")
	Events.toast.emit("Modo asistido %s" % ("activado" if Profile.assist else "desactivado"), Ui.LAMP_GO if Profile.assist else Ui.IVORY_DIM)
	Router.go(&"hangar")


func _reroll() -> void:
	if Profile.credits < REROLL_COST:
		Synth.play(&"deny")
		return
	Profile.credits -= REROLL_COST
	Profile.clear_board()
	Synth.play(&"coin")
	_refresh()


func _accept(contract: Contract) -> void:
	Run.begin(contract)
	Synth.play(&"ignite", -6.0)
	Router.go(&"assembly")


func _process(delta: float) -> void:
	_time += delta
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
	var ship := center + Vector2(cos(-a * 2.3), sin(-a * 2.3) * 0.3) * 320.0
	draw_circle(ship, 3.0, Color(3.0, 2.4, 1.6))
