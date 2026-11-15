extends Node2D

## Liquidacion tipo tragamonedas: cada linea entra contando, luego los rodillos de cajas.

const GRADE_MULT := {"S": 1.5, "A": 1.25, "B": 1.0, "C": 0.8, "": 1.0}
const SCIENCE_VALUE := 120

var _lines: Array = [] ## [texto, monto, color]
var _list: VBoxContainer
var _total_label: Label
var _total: int = 0
var _shown_total: float = 0.0
var _col: VBoxContainer
var _reels: Array[Label] = []


func _ready() -> void:
	var stars := Starfield.new()
	add_child(stars)
	stars.set_sky(Color(0.01, 0.012, 0.03), 0.7)
	_settle()
	var root := Ui.root(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := Ui.panel(center)
	panel.custom_minimum_size = Vector2(640, 0)
	_col = Ui.vbox(panel, 8)
	var good := Run.outcome == &"delivered" or Run.outcome == &"partial"
	var head := Ui.hbox(_col, 8)
	head.add_child(Lamp.new(tr("Entrega") if good else tr("Pérdida"), Lamp.GO if good else Lamp.WARNING))
	var headline := Ui.label(head, _headline(), Ui.SIZE_READOUT, Ui.IVORY)
	headline.add_theme_font_override("font", Ui.bold())
	var why := Ui.label(_col, Run.outcome_text, Ui.SIZE_TEXT, Ui.IVORY)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(600, 0)
	_list = Ui.vbox(_col, 2)
	var total_well := Ui.well(_col)
	var total_col := Ui.vbox(total_well, 2)
	Ui.legend(total_col, tr("Total"))
	_total_label = Ui.label(total_col, "", Ui.SIZE_HERO, Ui.IVORY)
	_total_label.add_theme_font_override("font", Ui.mono())
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Kinetic.enter_deferred(panel, 0.02, {"scale": Vector2(0.88, 0.84), "tilt": -0.028, "elastic": true, "beam": true, "duration": 0.34})
	_play()


func _headline() -> String:
	match Run.outcome:
		&"delivered": return tr("Entrega completa")
		&"partial": return tr("Entrega parcial")
		&"aborted": return tr("Misión abortada")
		&"stranded": return tr("A la deriva")
	return tr("Nave perdida")


## Calcula todas las lineas y aplica el resultado al perfil antes de animar.
func _settle() -> void:
	var contract := Run.contract
	var delivered := Run.outcome == &"delivered" or Run.outcome == &"partial"
	if contract != null and delivered:
		var base := contract.payout - contract.advance
		if Run.outcome == &"partial":
			base = int(base * 0.5)
		_add(tr("Pago del contrato"), base, Ui.IVORY)
		if Profile.assist:
			var cut := int(base * (1.0 - Run.assist_payout_mult()))
			_add(tr("Modo asistido, -15 %"), -cut, Ui.LAMP_CAUTION)
			base -= cut
		var grade_mult: float = GRADE_MULT.get(Run.grade, 1.0)
		if grade_mult != 1.0:
			_add(tr("Aterrizaje %s  x%.2f") % [Run.grade, grade_mult], int(base * (grade_mult - 1.0)), Ui.INFO)
		var t: float = Run.space_state.get("t", 0.0)
		if t <= contract.deadline:
			_add(tr("A tiempo, +15 %"), int(base * 0.15), Ui.LAMP_GO)
		else:
			_add(tr("Fuera de plazo  -30%"), -int(base * 0.3), Ui.LAMP_WARNING)
		if Run.streak > 0:
			_add(tr("Racha x%.2f") % Run.streak_mult(), int(base * (Run.streak_mult() - 1.0)), Ui.IVORY)
	elif contract != null:
		_add(tr("Adelanto ya cobrado"), 0, Ui.IVORY_DIM)
	if Run.earnings != 0:
		_add(tr("Botín en ruta"), Run.earnings, Ui.IVORY)
	if Run.science > 0:
		_add(tr("Ciencia  %d x %d") % [Run.science, SCIENCE_VALUE], Run.science * SCIENCE_VALUE, Ui.MYSTERY)
	for bet: Dictionary in Run.side_bets:
		var won := _bet_won(str(bet.kind), delivered)
		var prize := int(bet.stake * bet.mult) if won else 0
		_add(tr("Apuesta %s  (%d)") % [_bet_name(str(bet.kind)), int(bet.stake)], prize, Ui.LAMP_GO if won else Ui.LAMP_WARNING)
	if not delivered and Run.insurance > 0:
		var cover := int((Run.spent - Run.premium) * Profile.INSURANCE_COVER[Run.insurance])
		_add(tr("Seguro %s") % tr(Profile.INSURANCE_NAMES[Run.insurance]), cover, Ui.INFO)
	for part: ShipPart in Run.salvage:
		part.reveal()
		Profile.inventory.append(part.to_dict())
	if not Run.salvage.is_empty():
		_add(tr("Chatarra al inventario  (%d)") % Run.salvage.size(), 0, Ui.IVORY_DIM)
	for line: Array in _lines:
		_total += int(line[1])
	Profile.credits += _total
	if delivered:
		Profile.wins += 1
	Profile.best_payout = maxi(Profile.best_payout, _total)
	if not delivered:
		var lesson := Profile.learn_random(Run.rng)
		if lesson != "":
			_add(tr("Lección: ") + tr(str(Profile.LESSONS[lesson])), 0, Ui.LAMP_GO)
	Profile.save_profile()


func _add(text: String, amount: int, color: Color) -> void:
	_lines.append([text, amount, color])


func _bet_won(kind: String, delivered: bool) -> bool:
	match kind:
		"fuel":
			return delivered and Run.ship.fuel_total() >= Run.ship.fuel_capacity() * 0.25
		"deadline":
			return delivered and float(Run.space_state.get("t", 0.0)) <= Run.contract.deadline
		"perfect":
			return delivered and Run.grade == "S"
	return false


func _bet_name(kind: String) -> String:
	match kind:
		"fuel": return tr("combustible")
		"deadline": return tr("plazo")
	return tr("aterrizaje perfecto")


func _play() -> void:
	await get_tree().create_timer(0.5).timeout
	for line: Array in _lines:
		var row := Ui.hbox(_list)
		var title := Ui.label(row, str(line[0]), 15, line[2])
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var amount := Ui.label(row, "", 15, Ui.IVORY if int(line[1]) >= 0 else Ui.LAMP_WARNING)
		Kinetic.enter(row, 0.0, {"scale": Vector2(0.94, 0.88), "tilt": -0.016, "duration": 0.24})
		var target := int(line[1])
		var tween := create_tween()
		tween.tween_method(func(v: float) -> void: amount.text = Ui.money(int(v)) if target != 0 else "", 0.0, float(target), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_shown_total += target
		_total_label.text = Ui.money(int(_shown_total))
		Kinetic.pop(_total_label, Vector2(1.06, 0.92), 0.20)
		Synth.play(&"coin" if target > 0 else (&"deny" if target < 0 else &"tick"), -4.0, 1.0 + _list.get_child_count() * 0.05)
		if target > 500:
			Juice.shake(0.15)
		await get_tree().create_timer(0.45).timeout
	_total_label.text = Ui.money(_total)
	Kinetic.pop(_total_label, Vector2(1.12, 0.88), 0.28)
	Synth.play(&"jackpot" if _total > 2000 else (&"win" if _total > 0 else &"lose"))
	Juice.flash(Ui.IVORY if _total > 0 else Ui.LAMP_WARNING, 0.3)
	if Run.boxes > 0:
		await _open_boxes()
	Ui.label(_col, tr("Créditos: %s") % Ui.money(Profile.credits), Ui.SIZE_TEXT, Ui.IVORY)
	var actions := Ui.hbox(_col, 8)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var to_menu := Ui.button(actions, tr("Volver al menú principal"), func() -> void: Router.go(&"title"))
	to_menu.custom_minimum_size = Vector2(220, 44)
	var back := Ui.primary(Ui.button(actions, tr("Volver al hangar"), func() -> void: Router.go(&"hangar")))
	back.custom_minimum_size = Vector2(220, 44)
	Kinetic.enter(actions, 0.04, {"scale": Vector2(0.92, 0.86), "elastic": true, "beam": true, "duration": 0.30})
	back.grab_focus()


func _open_boxes() -> void:
	Ui.legend(_col, tr("Cajas misteriosas x%d") % Run.boxes)
	var row := Ui.hbox(_col, 12)
	for i: int in 3:
		var reel := Ui.label(row, "?", 28, Ui.MYSTERY)
		reel.custom_minimum_size = Vector2(190, 40)
		reel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_reels.append(reel)
	Kinetic.cascade(_reels, 0.04, 0.12, {"elastic": true, "duration": 0.26})
	for box: int in Run.boxes:
		var prize := _box_prize()
		var reel: Label = _reels[box % 3]
		var names := Catalog.part_list()
		for k: int in 14:
			reel.text = names[Run.rng.randi_range(0, names.size() - 1)].display_name
			Synth.play(&"tick", -8.0, 1.0 + k * 0.04)
			await get_tree().create_timer(0.04 + k * 0.012).timeout
		reel.text = prize[0]
		reel.add_theme_color_override("font_color", prize[1])
		Kinetic.pop(reel, Vector2(1.16, 0.84), 0.30)
		Synth.play(&"jackpot" if prize[1] == Ui.IVORY else &"coin")
		Juice.flash(prize[1], 0.25)
	Profile.save_profile()


## Devuelve [texto, color] y aplica el premio al perfil.
func _box_prize() -> Array:
	var roll := Run.rng.randf()
	if roll < 0.12:
		var part := Run.random_part(ShipPart.Quality.LEGENDARY)
		Profile.inventory.append(part.to_dict())
		return [part.def.display_name + " legendaria", Ui.IVORY]
	if roll < 0.55:
		var part := Run.random_part(ShipPart.Quality.MYSTERY)
		part.reveal()
		Profile.inventory.append(part.to_dict())
		return ["%s (%s)" % [part.def.display_name, part.quality_text()], Ui.INFO]
	var amount := Run.rng.randi_range(5, 40) * 10
	if roll > 0.96:
		amount = 1500
	Profile.credits += amount
	return [Ui.money(amount), Ui.IVORY if amount >= 1500 else Ui.LAMP_GO]
