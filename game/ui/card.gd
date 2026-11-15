class_name Card
extends CanvasLayer

## Carta de decision: averias, encuentros y apuestas.
## En 1 jugador la avería pausa. En 2, el vuelo sigue: aviso, marca y tirada con V.
## data: title, text, tone (malfunction/encounter/bet/info), choices, part, rarity, scanned.

const QUICK_ODDS := 0.55 ## decisión rápida del comandante: más fracaso

static var _queue: Array = []
static var _open: Card
static var _faults: Array[Dictionary] = []
static var _watch: FaultWatch

var data: Dictionary = {}
var on_done: Callable
var _root: Control
var _panel: PanelContainer
var _body: VBoxContainer
var _choices_box: VBoxContainer
var _scanned: bool = false
var _roll: float = 0.0
var _needle: float = 0.0
var _odds: float = 1.0
var _bar: Control
var _last_side: int = -1
var _locked: bool = false


static func show_card(card_data: Dictionary, callback: Callable = Callable()) -> void:
	if _open != null and is_instance_valid(_open):
		_queue.append([card_data, callback])
		return
	var tree := Engine.get_main_loop() as SceneTree
	var card := Card.new()
	card.data = card_data
	card.on_done = callback
	_open = card
	tree.root.add_child(card)


static func busy() -> bool:
	return _open != null and is_instance_valid(_open)


static func clear_queue() -> void:
	_queue.clear()
	_faults.clear()
	if _open != null and is_instance_valid(_open):
		_open.queue_free()
	_open = null
	_drop_watch()


static func open_faults() -> Array[ShipPart]:
	var out: Array[ShipPart] = []
	for row: Dictionary in _faults:
		var part: ShipPart = row.get("part") as ShipPart
		if part != null:
			out.append(part)
	return out


## El jugador 2 ya reparó la pieza. El callback de la fase recibe ese resultado.
static func release_fault(part: ShipPart, success: bool) -> void:
	var pending: Array[Callable] = []
	for i: int in range(_faults.size() - 1, -1, -1):
		var row: Dictionary = _faults[i]
		if row.get("part") != part:
			continue
		var callback: Callable = row.get("callback", Callable())
		_faults.remove_at(i)
		if callback.is_valid():
			pending.append(callback)
	_sync_watch()
	for callback: Callable in pending:
		callback.call(success)


## Tira la avería más antigua. roll < 0 usa Run.rng. No pausa el árbol.
static func roll_fault(roll: float = -1.0) -> bool:
	_prune_fixed()
	if _faults.is_empty():
		return false
	var row: Dictionary = _faults.pop_front()
	var part: ShipPart = row.get("part") as ShipPart
	var choice: ChoiceDef = row.get("choice") as ChoiceDef
	var callback: Callable = row.get("callback", Callable())
	var odds := _fault_odds(row)
	var sample := Run.rng.randf() if roll < 0.0 else roll
	var ok := sample < odds
	if choice != null and not choice.cost.is_empty():
		Run.apply(choice.cost, part)
	if ok:
		if choice != null:
			Run.apply(choice.win, part)
		Run.win_streak()
		if part != null and part.broken:
			Run.apply({"fix": true}, part)
	else:
		if choice != null:
			Run.apply(choice.lose, part)
		Run.lose_streak()
		if part != null and not part.broken:
			Run.apply({"break": true}, part)
	Events.toast.emit("Tirada %.0f%% → %s" % [odds * 100.0, "éxito" if ok else "fallo"], Ui.LAMP_GO if ok else Ui.LAMP_WARNING)
	if ok:
		Synth.play(&"win")
	else:
		Synth.play(&"lose")
	_sync_watch()
	if callback.is_valid():
		callback.call(ok)
	return true


static func _service_faults() -> void:
	_prune_fixed()
	if _watch != null and is_instance_valid(_watch):
		_watch.set_text(_banner_text() if not _faults.is_empty() else "")
	if _faults.is_empty() or busy():
		return
	if Controls.cmd_just(&"cmd_snap"):
		roll_fault()


static func _fault_odds(row: Dictionary) -> float:
	var choice: ChoiceDef = row.get("choice") as ChoiceDef
	if choice != null and choice.odds < 1.0 and choice.minigame == &"":
		return clampf(choice.odds * QUICK_ODDS, 0.05, 0.95)
	return QUICK_ODDS


static func _banner_text() -> String:
	if _faults.is_empty():
		return ""
	var row: Dictionary = _faults[0]
	var part: ShipPart = row.get("part") as ShipPart
	var name := part.def.display_name if part != null else "Pieza"
	var odds := _fault_odds(row)
	var where := "en el casco" if part != null and ShipInterior.is_exterior(part.def.kind) else "en la cabina"
	if _faults.size() == 1:
		return "%s averiada, %s. V o Y: tirada al %.0f%%." % [name, where, odds * 100.0]
	return "%d averías. V tira %s al %.0f%%. El tripulante va a la marca." % [_faults.size(), name, odds * 100.0]


static func _prune_fixed() -> void:
	var pending: Array[Callable] = []
	for i: int in range(_faults.size() - 1, -1, -1):
		var row: Dictionary = _faults[i]
		var part: ShipPart = row.get("part") as ShipPart
		if part != null and part.broken:
			continue
		var callback: Callable = row.get("callback", Callable())
		_faults.remove_at(i)
		if callback.is_valid():
			pending.append(callback)
	if not pending.is_empty():
		_sync_watch()
	for callback: Callable in pending:
		callback.call(true)


static func _sync_watch() -> void:
	if _faults.is_empty():
		_drop_watch()
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _watch == null or not is_instance_valid(_watch):
		_watch = FaultWatch.new()
		tree.root.add_child(_watch)
	_watch.set_text(_banner_text())


static func _drop_watch() -> void:
	if _watch != null and is_instance_valid(_watch):
		_watch.queue_free()
	_watch = null


static func _remember_fault(part: ShipPart, choice: ChoiceDef, callback: Callable) -> void:
	for row: Dictionary in _faults:
		if row.get("part") == part:
			return
	_faults.append({"part": part, "choice": choice, "callback": callback})
	_sync_watch()


## Elige una averia del catalogo para la pieza y la muestra.
static func malfunction(part: ShipPart, callback: Callable = Callable()) -> void:
	if Run.crew >= 2:
		Run.apply({"break": true}, part)
		var options := Catalog.malfunctions_for(part.def.kind)
		var def: MalfunctionDef = null
		var choice: ChoiceDef = null
		if not options.is_empty():
			def = options[Run.rng.randi_range(0, options.size() - 1)]
			for candidate: ChoiceDef in def.choices:
				if candidate.odds < 1.0 and candidate.minigame == &"":
					choice = candidate
					break
		var title := def.title if def != null else "Avería"
		Events.malfunction.emit(part.def.display_name, title)
		Synth.play(&"alarm")
		Juice.hit(0.5)
		_remember_fault(part, choice, callback)
		Events.toast.emit(_banner_text(), Ui.LAMP_WARNING)
		return
	var options := Catalog.malfunctions_for(part.def.kind)
	if options.is_empty():
		Run.apply({"break": true}, part)
		return
	var def: MalfunctionDef = options[Run.rng.randi_range(0, options.size() - 1)]
	Events.malfunction.emit(part.def.display_name, def.title)
	Synth.play(&"alarm")
	Juice.hit(0.5)
	show_card({
		"title": def.title,
		"text": def.text.replace("%part%", part.def.display_name),
		"tone": &"malfunction",
		"choices": def.choices,
		"part": part,
		"scanned": Profile.has_lesson("odds") or Profile.assist,
	}, callback)


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var coop := Run.crew >= 2
	if coop:
		get_tree().paused = false
		Engine.time_scale = 1.0
	else:
		get_tree().paused = true
	_scanned = bool(data.get("scanned", false))
	_root = Ui.root(self, 50)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE if coop else Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0 if coop else 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE if coop else Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE if coop else Control.MOUSE_FILTER_STOP
	if coop:
		center.offset_right = -300.0
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(600, 0)
	if coop:
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)
	_body = Ui.vbox(_panel, 10)
	_build()
	if Run.crew >= 2 and _has_risk(data.get("choices", [])):
		var tip := Ui.label(_body, "Elige una opción. V o Y la apura con peores probabilidades.", Ui.SIZE_LEGEND, Ui.LAMP_CAUTION)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(560, 0)
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	_panel.pivot_offset = Vector2(300, 150)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _accent() -> Color:
	match data.get("tone", &"info"):
		&"malfunction":
			return Ui.LAMP_WARNING
		&"encounter":
			return Ui.RARITY[clampi(int(data.get("rarity", 0)), 0, 2)]
		&"bet":
			return Ui.IVORY
	return Ui.INFO


func _build() -> void:
	for child: Node in _body.get_children():
		child.queue_free()
	var header := Ui.hbox(_body)
	var tag := "Avería" if data.get("tone") == &"malfunction" else ("Apuesta" if data.get("tone") == &"bet" else "Encuentro")
	if data.get("tone") == &"malfunction" and data.get("part") == null:
		tag = "Evento"
	if data.get("tone") == &"encounter":
		tag = "%s: %s" % [tag, Ui.RARITY_NAMES[clampi(int(data.get("rarity", 0)), 0, 2)]]
	if data.get("tone") == &"info":
		tag = "Aviso"
	var lamp := Lamp.new(tag, Lamp.GO)
	lamp.tint = _accent()
	lamp.blink = data.get("tone") == &"malfunction"
	lamp.custom_minimum_size = Vector2(200, 28)
	header.add_child(lamp)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	if Run.streak > 0:
		Ui.label(header, "Racha x%.2f" % Run.streak_mult(), Ui.SIZE_TEXT, Ui.IVORY)
	Ui.label(_body, str(data.get("title", "")), Ui.SIZE_READOUT, Ui.IVORY).add_theme_font_override("font", Ui.bold())
	var text := Ui.label(_body, str(data.get("text", "")), Ui.SIZE_TEXT, Ui.IVORY)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	_choices_box = Ui.vbox(_body, 8)
	var choices: Array = data.get("choices", [])
	for i: int in choices.size():
		_add_choice(choices[i], i)
	if choices.is_empty():
		Ui.button(_choices_box, "Continuar", _close.bind(true))
	elif not _scanned and _has_risk(choices):
		var scan := Ui.button(_body, "Escanear probabilidades (gasta 15 % de batería)", _scan)
		scan.disabled = Run.battery < 0.15 * Thermal.battery_capacity(Run.ship)


func _has_risk(choices: Array) -> bool:
	for choice: ChoiceDef in choices:
		if choice.odds < 1.0 and choice.minigame == &"":
			return true
	return false


func _add_choice(choice: ChoiceDef, index: int) -> void:
	var row := Ui.hbox(_choices_box, 10)
	var b := Ui.button(row, choice.label, _choose.bind(index))
	b.custom_minimum_size = Vector2(330, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var need := int(choice.cost.get("credits", 0))
	var stake := int(choice.cost.get("stake", 0))
	if (need < 0 and Run.earnings < -need) or (stake > 0 and Profile.credits < stake):
		b.disabled = true
	if choice.cost.has("kits") and Run.kits < -int(choice.cost.kits):
		b.disabled = true
	var info := Ui.vbox(row, 0)
	var odds_text := "Minijuego" if choice.minigame != &"" else Odds.fog_text(choice.odds, _scanned)
	var odds_color := Ui.INFO if choice.minigame != &"" else Odds.risk_color(choice.odds if _scanned else 0.5 + (choice.odds - 0.5) * 0.4)
	if choice.odds >= 1.0:
		odds_color = Odds.risk_color(1.0)
	Ui.label(info, odds_text, 15, odds_color)
	var detail := ""
	if not choice.cost.is_empty():
		detail += "Costo: %s  " % Run.describe(choice.cost)
	if not choice.win.is_empty():
		detail += "Éxito: %s  " % Run.describe(choice.win)
	if not choice.lose.is_empty() and choice.odds < 1.0:
		detail += "Fallo: %s" % Run.describe(choice.lose)
	var d := Ui.label(info, detail, Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(220, 0)


func _scan() -> void:
	Run.apply({"battery": -0.15})
	_scanned = true
	Synth.play(&"beep")
	_build()


func _choose(index: int) -> void:
	var choices: Array = data.get("choices", [])
	var choice: ChoiceDef = choices[index]
	for child: Node in _body.get_children():
		if child is Button:
			child.disabled = true
	for row: Node in _choices_box.get_children():
		for child: Node in row.get_children():
			if child is Button:
				child.disabled = true
	if not choice.cost.is_empty():
		Run.apply(choice.cost, data.get("part"))
	if choice.minigame != &"":
		visible = false
		Minigame.start(choice.minigame, func(success: bool) -> void:
			visible = true
			_resolve(choice, success))
		return
	if choice.odds >= 1.0:
		_resolve(choice, true)
		return
	_odds = choice.odds
	_roll = Run.rng.randf()
	_spin(choice)


func _process(_delta: float) -> void:
	if Run.crew < 2 or _bar != null:
		return
	if not Controls.cmd_just(&"cmd_snap"):
		return
	_quick_decide()


func _quick_decide() -> void:
	if _locked:
		return
	var choices: Array = data.get("choices", [])
	var pick: ChoiceDef = null
	for i: int in choices.size():
		var choice: ChoiceDef = choices[i]
		if choice.odds < 1.0 and choice.minigame == &"":
			pick = choice
			break
	if pick == null:
		Events.toast.emit("No hay apuesta pendiente", Ui.IVORY_DIM)
		return
	_locked = true
	for row: Node in _choices_box.get_children():
		for child: Node in row.get_children():
			if child is Button:
				child.disabled = true
	if not pick.cost.is_empty():
		Run.apply(pick.cost, data.get("part"))
	var odds := clampf(pick.odds * QUICK_ODDS, 0.05, 0.95)
	var roll := Run.rng.randf()
	var ok := roll < odds
	Events.toast.emit("Decisión rápida %.0f%% → %s" % [odds * 100.0, "éxito" if ok else "fallo"], Ui.LAMP_GO if ok else Ui.LAMP_WARNING)
	_resolve(pick, ok)


func _spin(choice: ChoiceDef) -> void:
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(560, 46)
	_bar.draw.connect(_draw_bar)
	_body.add_child(_bar)
	var tween := create_tween()
	tween.tween_method(_set_needle, 0.0, 4.0 + _roll, 1.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.tween_callback(func() -> void: _resolve(choice, _roll < _odds))


func _set_needle(value: float) -> void:
	_needle = pingpong(value, 1.0)
	var side := 0 if _needle < _odds else 1
	if side != _last_side:
		_last_side = side
		Synth.play(&"tick", -4.0, 1.0 + side * 0.4)
	if _bar != null:
		_bar.queue_redraw()


func _draw_bar() -> void:
	var w := _bar.size.x
	var h := 26.0
	_bar.draw_rect(Rect2(0, 10, w, h), Ui.BAKELITE)
	_bar.draw_rect(Rect2(0, 10, w * _odds, h).grow(-2), Ui.LAMP_GO)
	_bar.draw_rect(Rect2(w * _odds, 10, w * (1.0 - _odds), h).grow(-2), Ui.LAMP_WARNING)
	_bar.draw_string(Ui.legend_font(), Vector2(10, 28), "Éxito", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.BAKELITE)
	_bar.draw_string(Ui.legend_font(), Vector2(0, 28), "Fallo", HORIZONTAL_ALIGNMENT_RIGHT, w - 10, Ui.SIZE_LEGEND, Ui.BAKELITE)
	var x := w * _needle
	_bar.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, 0), Vector2(x + 8, 0), Vector2(x, 12)]), Ui.IVORY)
	_bar.draw_line(Vector2(x, 8), Vector2(x, 12 + h), Ui.BAKELITE, 5.0)
	_bar.draw_line(Vector2(x, 8), Vector2(x, 12 + h), Ui.IVORY, 3.0)


func _resolve(choice: ChoiceDef, success: bool) -> void:
	var part: ShipPart = data.get("part")
	var effects: Dictionary = choice.win if success else choice.lose
	var risky := choice.odds < 1.0 or choice.minigame != &""
	if risky:
		if success:
			Run.win_streak()
		else:
			Run.lose_streak()
	Run.apply(effects, part)
	if success:
		Synth.play(&"win" if risky else &"beep")
		Juice.flash(Ui.LAMP_GO, 0.25 if risky else 0.0)
	else:
		Synth.play(&"lose")
		Juice.flash(Ui.LAMP_WARNING, 0.35)
		Juice.hit(0.4)
	for child: Node in _choices_box.get_children():
		child.queue_free()
	var verdict := choice.win_text if success else choice.lose_text
	if verdict == "":
		verdict = "Salió bien." if success else "Salió mal."
	Ui.label(_body, ("Éxito. " if success else "Fallo. ") + verdict, Ui.SIZE_HEAD, Ui.LAMP_GO if success else Ui.LAMP_WARNING)
	var summary := Run.describe(effects)
	if summary != "":
		Ui.label(_body, summary, Ui.SIZE_TEXT, Ui.IVORY)
	if risky and success:
		Ui.label(_body, "Racha x%.2f" % Run.streak_mult(), Ui.SIZE_TEXT, Ui.IVORY)
	var done := Ui.primary(Ui.button(_body, "Continuar", _close.bind(success)))
	done.grab_focus()


func _close(success: bool) -> void:
	_open = null
	var callback := on_done
	queue_free()
	if _queue.is_empty():
		get_tree().paused = false
		if Run.crew >= 2:
			Engine.time_scale = 1.0
	else:
		var next: Array = _queue.pop_front()
		show_card(next[0], next[1])
	if callback.is_valid():
		callback.call(success)


class FaultWatch extends CanvasLayer:
	var _label: Label

	func _ready() -> void:
		layer = 40
		process_mode = Node.PROCESS_MODE_ALWAYS
		var bg := ColorRect.new()
		bg.color = Color(0.08, 0.05, 0.04, 0.92)
		bg.position = Vector2(16, 72)
		bg.size = Vector2(456, 64)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		_label = Label.new()
		_label.position = Vector2(24, 80)
		_label.size = Vector2(440, 48)
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_override("font", Ui.sans())
		_label.add_theme_font_size_override("font_size", Ui.SIZE_TEXT)
		_label.add_theme_color_override("font_color", Ui.LAMP_WARNING)
		add_child(_label)

	func _process(_delta: float) -> void:
		Card._service_faults()

	func set_text(text: String) -> void:
		if _label == null:
			return
		_label.text = text
