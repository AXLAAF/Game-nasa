extends Node2D

## Hangar: tablero de contratos, seguro, lecciones e inventario entre partidas.

const REROLL_COST := 100

var _rng := RandomNumberGenerator.new()
var _board: VBoxContainer
var _wallet: Label
var _insurance_box: HBoxContainer
var _reset_armed: bool = false
var _time: float = 0.0


func _ready() -> void:
	_rng.randomize()
	var stars := Starfield.new()
	add_child(stars)
	stars.set_sky(Color(0.01, 0.015, 0.04), 1.0)
	var root := Ui.root(self)
	var title := Ui.label(root, "CONTRATISTA ORBITAL", 42, Ui.INFO)
	Ui.place(title, Rect2(40, 26, 800, 60))
	title.add_theme_color_override("font_outline_color", Color(0, 0.2, 0.3))
	title.add_theme_constant_override("outline_size", 10)
	Ui.place(Ui.label(root, "Arma barato. Vuela lejos. Apuesta todo.", 16, Ui.IVORY_DIM), Rect2(44, 82, 800, 24))
	var left := Ui.panel(root)
	Ui.place(left, Rect2(40, 130, 330, 0))
	var col := Ui.vbox(left, 8)
	_wallet = Ui.label(col, "", 15)
	Ui.label(col, "SEGURO DE LA NAVE", 13, Ui.IVORY_DIM)
	_insurance_box = Ui.hbox(col, 4)
	Ui.button(col, "Tutorial completo", func() -> void: Tutorial.replay())
	Ui.label(col, "DIFICULTAD", 13, Ui.IVORY_DIM)
	var assist_row := Ui.hbox(col, 4)
	var assist_b := Ui.button(assist_row, "Modo asistido", _toggle_assist)
	assist_b.tooltip_text = "Menos averias, mas kits, corredores mas anchos y navegacion asistida (N). El pago del contrato baja un 15%."
	if Profile.assist:
		assist_b.add_theme_color_override("font_color", Ui.LAMP_GO)
		assist_b.text = "> Asistido ON"
	Ui.label(col, "LECCIONES", 13, Ui.IVORY_DIM)
	if Profile.lessons.is_empty():
		Ui.label(col, "Ninguna. Se aprenden perdiendo.", 13, Ui.IVORY_DIM)
	for id: String in Profile.lessons:
		var l := Ui.label(col, "- " + str(Profile.LESSONS[id]), 13, Ui.LAMP_GO)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
	Ui.label(col, "INVENTARIO: %d piezas guardadas" % Profile.inventory.size(), 13, Ui.IVORY)
	var reset := Ui.button(col, "Reiniciar perfil", func() -> void: pass)
	reset.pressed.connect(func() -> void:
		if _reset_armed:
			Profile.reset()
			Router.go(&"hangar")
		else:
			_reset_armed = true
			reset.text = "Seguro? Pulsa otra vez")
	var right := Ui.panel(root)
	Ui.place(right, Rect2(400, 130, 840, 0))
	var board_col := Ui.vbox(right, 10)
	var head := Ui.hbox(board_col)
	Ui.label(head, "TABLERO DE CONTRATOS", 18, Ui.IVORY)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	Ui.button(head, "Nuevos contratos (%s)" % Ui.money(REROLL_COST), _reroll)
	_board = Ui.vbox(board_col, 10)
	_refresh()
	Synth.play(&"chime", -6.0)


func _refresh() -> void:
	_wallet.text = "CREDITOS  %s\nPARTIDAS  %d   EXITOS %d\nMEJOR PAGO  %s" % [Ui.money(Profile.credits), Profile.runs, Profile.wins, Ui.money(Profile.best_payout)]
	for child: Node in _insurance_box.get_children():
		child.queue_free()
	for i: int in Profile.INSURANCE_NAMES.size():
		var b := Ui.button(_insurance_box, Profile.INSURANCE_NAMES[i], _set_insurance.bind(i))
		b.tooltip_text = "Prima %d%% del valor de la nave, cubre %d%% si la pierdes." % [int(Profile.INSURANCE_PREMIUM[i] * 100.0 * (0.5 if Profile.has_lesson("seguro") else 1.0)), int(Profile.INSURANCE_COVER[i] * 100.0)]
		if i == Profile.insurance:
			b.add_theme_color_override("font_color", Ui.IVORY)
			b.text = "> " + b.text
	for child: Node in _board.get_children():
		child.queue_free()
	for contract: Contract in Profile.board(_rng):
		_contract_card(contract)


func _contract_card(contract: Contract) -> void:
	var body := contract.body()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.box(Ui.BAKELITE_RAISED, body.color if body != null else Ui.INFO, 1, 6))
	_board.add_child(card)
	var row := Ui.hbox(card, 16)
	var swatch := ColorRect.new()
	swatch.color = body.color if body != null else Ui.INFO
	swatch.custom_minimum_size = Vector2(10, 0)
	row.add_child(swatch)
	var info := Ui.vbox(row, 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.label(info, contract.title, 18, Ui.IVORY)
	if body != null:
		Ui.label(info, body.description, 13, Ui.IVORY_DIM)
	Ui.label(info, "Delta-v estimado %d m/s   Plazo %d dias" % [int(contract.dv_estimate), int(contract.deadline)], 13, Ui.INFO)
	if contract.hidden_hazard != &"":
		Ui.label(info, "Rumores de peligro en la zona (+pago)", 13, Ui.LAMP_WARNING)
	var money := Ui.vbox(row, 2)
	Ui.label(money, Ui.money(contract.payout), 24, Ui.IVORY)
	Ui.label(money, "Adelanto %s" % Ui.money(contract.advance), 13, Ui.IVORY_DIM)
	Ui.label(money, "Presupuesto %s" % Ui.money(Profile.budget(contract)), 13, Ui.LAMP_GO)
	var accept := Ui.button(row, "ACEPTAR", _accept.bind(contract))
	accept.custom_minimum_size = Vector2(120, 0)


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


func _draw() -> void:
	var view := get_viewport_rect().size
	var center := Vector2(view.x * 0.82, view.y * 1.05)
	draw_circle(center, 260.0, Color(0.12, 0.3, 0.6))
	draw_arc(center, 272.0, PI * 1.05, PI * 1.95, 64, Color(0.5, 0.8, 1.6, 0.5), 18.0)
	var a := _time * 0.25
	var moon := center + Vector2(cos(a), sin(a) * 0.35) * 420.0
	if sin(a) < 0.0 or absf(moon.x - center.x) > 260.0:
		draw_circle(moon, 22.0, Color(0.7, 0.7, 0.72))
	var ship := center + Vector2(cos(-a * 2.3), sin(-a * 2.3) * 0.3) * 320.0
	draw_circle(ship, 3.0, Color(3.0, 2.4, 1.6))
