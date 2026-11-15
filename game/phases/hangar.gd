extends Node2D

## Hangar: tablero de contratos, seguro, lecciones e inventario entre partidas.

const REROLL_COST := 100
const CONTENT_W := 1320.0 ## ancho maximo de la columna de contenido; lo que sobra va a los margenes
const SIDE_MIN := 48.0 ## margen lateral minimo: deja libre la esquina del engranaje de Pause

var _rng := RandomNumberGenerator.new()
var _page: MarginContainer
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
var _reset_armed: bool = false


func _ready() -> void:
	_rng.randomize()
	Run.crew = clampi(Profile.crew, 1, 2)
	var stars := Starfield.new()
	add_child(stars)
	stars.set_sky(Color(0.016, 0.024, 0.06), 1.0)
	var root := Ui.root(self)
	_page = MarginContainer.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.add_theme_constant_override("margin_top", 14)
	_page.add_theme_constant_override("margin_bottom", 20)
	root.add_child(_page)
	get_viewport().size_changed.connect(_fit)
	_fit()
	var page := Ui.vbox(_page, 14)
	var header := _build_header(page)
	var body := Ui.hbox(page, 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var crew := _build_crew(body)
	var board := _build_board(body)
	_refresh()
	_focus_menu()
	# Sin deslizamiento: estas piezas viven en contenedores y Kinetic solo desliza nodos anclados.
	Kinetic.enter_deferred(header, 0.0, {"scale": Vector2(0.98, 0.92), "tilt": 0.0, "duration": 0.30})
	Kinetic.enter_deferred(crew, 0.05, {"scale": Vector2(0.96, 0.94), "tilt": -0.01, "duration": 0.32})
	Kinetic.enter_deferred(board, 0.09, {"scale": Vector2(0.97, 0.95), "tilt": 0.008, "beam": true, "duration": 0.34})
	Synth.play(&"chime", -6.0)


## Columna de contenido centrada: en ventanas anchas crecen los margenes, no los paneles.
func _fit() -> void:
	var side := int(maxf(SIDE_MIN, (get_viewport_rect().size.x - CONTENT_W) * 0.5))
	_page.add_theme_constant_override("margin_left", side)
	_page.add_theme_constant_override("margin_right", side)


## Marca a la izquierda, lecturas del perfil a la derecha, todo centrado en vertical.
func _build_header(page: Node) -> Control:
	var band := Ui.panel(page)
	var style := Ui.box(Color(Ui.BAKELITE, Ui.GLASS_TINT), Ui.RIM, 1, 12)
	style.border_width_top = 2
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	band.add_theme_stylebox_override("panel", style)
	var row := Ui.hbox(band, 14)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/logo_orbita_64.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(logo)
	var brand := Ui.vbox(row, 0)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := Ui.label(brand, tr("Margin Zero"), Ui.SIZE_HERO, Ui.IVORY)
	title.add_theme_font_override("font", Ui.title_font())
	Ui.legend(brand, tr("Deuda orbital"))
	var stats := Ui.hbox(row, 16)
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_credit_label = Ui.readout(stats, tr("Créditos"), "", 130.0)
	_runs_label = Ui.readout(stats, tr("Partidas"), "", 90.0)
	_deliveries_label = Ui.readout(stats, tr("Entregas"), "", 90.0)
	_best_label = Ui.readout(stats, tr("Mejor pago"), "", 130.0)
	_players_label = Ui.readout(stats, tr("Jugadores"), "", 90.0)
	return band


## Columna izquierda: tripulacion, seguro, lecciones y, al pie, el perfil.
func _build_crew(body: Node) -> Control:
	var panel := Ui.panel(body)
	panel.custom_minimum_size.x = 336
	var col := Ui.vbox(panel, 8)
	Ui.legend(col, tr("Tripulación"))
	_build_player_slots(col)
	Ui.legend(col, tr("Seguro de la nave"))
	_insurance_box = Ui.hbox(col, 4)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var lessons := Ui.vbox(scroll, 8)
	lessons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.legend(lessons, tr("Lecciones"))
	if Profile.lessons.is_empty():
		_wrapped(lessons, tr("Ninguna todavía. Se aprenden perdiendo naves."), Ui.SIZE_TEXT, Ui.IVORY_DIM)
	for id: String in Profile.lessons:
		_wrapped(lessons, str(Profile.LESSONS[id]), Ui.SIZE_TEXT, Ui.IVORY)
	Ui.label(col, tr("Inventario: %d piezas guardadas") % Profile.inventory.size(), Ui.SIZE_TEXT, Ui.IVORY)
	Ui.button(col, tr("Manual de vuelo"), func() -> void: Tutorial.replay())
	Ui.button(col, tr("Práctica: armar la nave"), func() -> void: Router.go(&"training"))
	var reset := Ui.button(col, tr("Reiniciar perfil"), func() -> void: pass)
	reset.pressed.connect(func() -> void:
		if _reset_armed:
			Profile.reset()
			Router.go(&"hangar")
		else:
			_reset_armed = true
			reset.text = tr("Pulsa otra vez para borrar todo"))
	return panel


## Tablero de contratos: ocupa el resto del ancho y reparte su alto entre las fichas.
func _build_board(body: Node) -> Control:
	var panel := Ui.panel(body)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var board_col := Ui.vbox(panel, 10)
	var head := Ui.hbox(board_col)
	var heading := Ui.label(head, tr("Contratos"), Ui.SIZE_HEAD, Ui.IVORY)
	heading.add_theme_font_override("font", Ui.bold())
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.button(head, tr("Pedir contratos nuevos (%s)") % Ui.money(REROLL_COST), _reroll)
	var board_scroll := ScrollContainer.new()
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_col.add_child(board_scroll)
	_board = Ui.vbox(board_scroll, 10)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return panel


## Texto que se ajusta al ancho que le de su contenedor, sin anchos fijos.
func _wrapped(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Ui.label(parent, text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _build_player_slots(col: Node) -> void:
	_p1_lamp = _player_row(col, tr("P1 Comandante"))
	_p2_lamp = _player_row(col, tr("P2 Tripulante"))
	_p2_hint = _wrapped(col, "", Ui.SIZE_LEGEND, Ui.INFO)
	_join_button = Ui.button(col, tr("Unirse (jugador 2)"), _toggle_join_button)
	_join_button.tooltip_text = tr("El segundo jugador pulsa A en el mando o J en el teclado. P1 pilota con el teclado.")


## Nombre a la izquierda y lampara de estado alineada a la derecha.
func _player_row(col: Node, text: String) -> Lamp:
	var row := Ui.hbox(col, 8)
	Ui.label(row, text, Ui.SIZE_TEXT, Ui.IVORY).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lamp := Lamp.new(tr("Ausente"), Lamp.OFF)
	lamp.custom_minimum_size = Vector2(118, 26)
	lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lamp)
	return lamp


func _refresh() -> void:
	_credit_label.text = Ui.money(Profile.credits)
	_runs_label.text = str(Profile.runs)
	_deliveries_label.text = str(Profile.wins)
	_best_label.text = Ui.money(Profile.best_payout)
	for child: Node in _insurance_box.get_children():
		child.queue_free()
	for i: int in Profile.INSURANCE_NAMES.size():
		var b := Ui.button(_insurance_box, Profile.INSURANCE_NAMES[i], _set_insurance.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = tr("Prima %d %% del valor de la nave, cubre %d %% si la pierdes.") % [int(Profile.INSURANCE_PREMIUM[i] * 100.0 * (0.5 if Profile.has_lesson("seguro") else 1.0)), int(Profile.INSURANCE_COVER[i] * 100.0)]
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
	_p1_lamp.text = tr("Conectado").to_upper()
	_p1_lamp.state = Lamp.GO
	if duo:
		_p2_lamp.text = tr("Conectado").to_upper()
		_p2_lamp.state = Lamp.GO
		_p2_hint.text = tr("Tripulante listo. En vuelo usa flechas o el mando. P1 pilota con el teclado. Pulsa B / K para salir.")
		_p2_hint.add_theme_color_override("font_color", Ui.LAMP_GO)
		_join_button.text = tr("Desconectar jugador 2")
	else:
		_p2_lamp.text = tr("Esperando").to_upper()
		_p2_lamp.state = Lamp.CAUTION
		_p2_hint.text = tr("Pulsa A en el mando o J para unirte. P1 pilota con el teclado, como en un jugador.")
		_p2_hint.add_theme_color_override("font_color", Ui.LAMP_CAUTION)
		_join_button.text = tr("Unirse (jugador 2)")


## Ficha de contrato: filo de estado, destino, texto y, a la derecha, el dinero y la tecla.
func _contract_card(contract: Contract) -> PanelContainer:
	var body := contract.body()
	var risky := contract.hidden_hazard != &""
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rest_style := Ui.box(Color(Ui.BAKELITE_RAISED, 0.5), Ui.RIM, 1, 8)
	var hover_style := Ui.box(Color(Ui.BAKELITE_EDGE, 0.75), Ui.INFO, 1, 8)
	for style: StyleBoxFlat in [rest_style, hover_style]:
		style.content_margin_left = 0
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", rest_style)
	Kinetic.sync_pivot(card)
	card.mouse_entered.connect(func() -> void:
		card.add_theme_stylebox_override("panel", hover_style)
		Kinetic.pop(card, Vector2(1.01, 1.01), 0.16))
	card.mouse_exited.connect(func() -> void:
		card.add_theme_stylebox_override("panel", rest_style))
	_board.add_child(card)
	var row := Ui.hbox(card, 14)
	var edge := ColorRect.new()
	edge.color = Ui.LAMP_CAUTION if risky else Ui.INFO
	edge.custom_minimum_size.x = 4
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(edge)
	row.add_child(_planet_icon(body))
	var info := Ui.vbox(row, 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	_wrapped(info, contract.title, 20, Ui.IVORY).add_theme_font_override("font", Ui.bold())
	if body != null:
		_wrapped(info, body.description, Ui.SIZE_LEGEND, Ui.IVORY_DIM)
		var facts := Ui.hbox(info, 18)
		_fact(facts, tr("Delta-v"), tr("%d m/s") % int(contract.dv_estimate))
		_fact(facts, tr("Plazo"), tr("%d días") % int(contract.deadline))
	if risky:
		var rumor := Lamp.new(tr("Rumores de peligro"), Lamp.CAUTION)
		rumor.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		info.add_child(rumor)
	var money := Ui.vbox(row, 2)
	money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money.custom_minimum_size.x = 184
	var payout := Ui.label(money, Ui.money(contract.payout), 28, Ui.IVORY)
	payout.add_theme_font_override("font", Ui.mono())
	payout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for line: Array in [[tr("Adelanto %s") % Ui.money(contract.advance), Ui.IVORY_DIM], [tr("Presupuesto %s") % Ui.money(Profile.budget(contract)), Ui.LAMP_GO]]:
		Ui.label(money, line[0], Ui.SIZE_LEGEND, line[1]).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	money.add_child(gap)
	var accept := Ui.primary(Ui.button(money, tr("Aceptar contrato"), _accept.bind(contract)))
	accept.custom_minimum_size.y = 44
	if _first_focus == null:
		_first_focus = accept
	return card


## Dato del contrato: leyenda apagada y cifra en cian (dato real).
func _fact(parent: Node, legend_text: String, value: String) -> void:
	var pair := Ui.hbox(parent, 6)
	Ui.label(pair, legend_text, Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	Ui.label(pair, value, Ui.SIZE_LEGEND, Ui.INFO).add_theme_font_override("font", Ui.mono())


func _focus_menu() -> void:
	if _first_focus != null and is_instance_valid(_first_focus):
		_first_focus.grab_focus()
	elif _join_button != null:
		_join_button.grab_focus()


func _planet_icon(body: BodyDef) -> Control:
	if body == null:
		var blank := Control.new()
		blank.custom_minimum_size = Vector2(72, 72)
		return blank
	var icon := Planet.make(body, 56.0)
	icon.custom_minimum_size = Vector2(72, 72)
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
	Events.toast.emit(tr("2 jugadores conectados") if next >= 2 else tr("1 jugador conectado"), Ui.LAMP_GO if next >= 2 else Ui.IVORY_DIM)
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


func _process(_delta: float) -> void:
	if Controls.join_just() and Run.crew < 2:
		_set_crew(2)
	elif Controls.leave_just() and Run.crew >= 2:
		_set_crew(1)
