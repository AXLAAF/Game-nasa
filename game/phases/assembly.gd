extends Node

## Ensamblaje: arrastra piezas a la pila. Las radiales (paneles, antenas, sensores…)
## se anclan a cualquier bloque: altura con el raton, lado izq/der/ambos.

const INSPECT_COST := 25
const BOX_COST := 90
const HAZARD_NAMES := {&"heat": "calor", &"cold": "frío", &"radiation": "radiación", &"dust": "polvo", &"storms": "tormentas"}
const GROUPS: Array = [
	["Lo básico", [&"capsule", &"engine", &"tank"]],
	["Segunda etapa", [&"decoupler"]],
	["Aterrizaje", [&"heatshield", &"parachute", &"legs"]],
	["Energía", [&"solar", &"battery", &"rtg"]],
	["Calor, frío y radiación", [&"radiator", &"insulation", &"shielding"]],
	["Navegación y control", [&"computer", &"sensor", &"antenna", &"rcs"]],
	["Seguridad", [&"escape"]],
]

var _quality: int = ShipPart.Quality.NEW
var _selected: int = -1
var _inventory: Array[ShipPart] = []
var _view: ShipView
var _catalog: VBoxContainer
var _quality_buttons: Array[Button] = []
var _part_lamps: Array = []
var _quality_note: Label
var _budget_label: Label
var _dv: Gauge
var _twr_label: Label
var _stages_label: Label
var _req_box: VBoxContainer
var _risk_label: Label
var _part_box: VBoxContainer
var _launch: Button
var _contract_label: Label
var _next_label: Label
var _launch_note: Label
var _hover_card: PanelContainer
var _hover_title: Label
var _hover_badge: Lamp
var _hover_role: Label
var _hover_reason: Label
var _hover_stats: Label
var _hover_owner: Control


class PartButton extends Button:
	var phase: Node
	var def: PartDef
	var stock: ShipPart

	func _get_drag_data(_at: Vector2) -> Variant:
		if phase != null:
			phase.hide_part_hover(null)
		var preview := Label.new()
		preview.text = "  + " + def.display_name
		preview.add_theme_color_override("font_color", Ui.IVORY)
		set_drag_preview(preview)
		return {"def": def, "stock": stock}


class DropZone extends PanelContainer:
	var phase: Node

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("from")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		phase.remove_part(int(data.from))


class ShipView extends Control:
	var phase: Node
	var hint: Dictionary = {} ## preview de soltar: host, mount, side, radial, size, kind
	var scale_factor: float = 1.6

	func origin() -> Vector2:
		return Vector2(size.x * 0.5, size.y - 70.0)

	func fit() -> void:
		var b := ShipRenderer.bounds(Run.ship.parts)
		var room_y := maxf(size.y - 110.0, 40.0)
		var room_x := maxf(size.x - 36.0, 40.0)
		var height := maxf(b.size.y, 1.0)
		var width := maxf(b.size.x, 1.0)
		scale_factor = clampf(minf(room_y / height, room_x / width), 0.35, 1.8)

	func to_local_ship(p: Vector2) -> Vector2:
		return (p - origin()) / scale_factor

	## Donde insertar una pieza de pila segun la altura.
	func stack_index(local_y: float) -> int:
		var rects := ShipRenderer.layout(Run.ship.parts)
		for i: int in Run.ship.parts.size():
			if not Run.ship.parts[i].def.radial and local_y > rects[i].get_center().y:
				return i
		return Run.ship.parts.size()

	## Ancla una radial a un bloque: indice de insercion, altura 0-1 y lado.
	func attach_plan(local: Vector2, def: PartDef) -> Dictionary:
		var parts := Run.ship.parts
		if parts.is_empty():
			return {"index": 0, "mount": 0.5, "side": 0, "host": -1}
		var host := ShipRenderer.pick_host(parts, local)
		if host < 0:
			return {"index": parts.size(), "mount": 0.5, "side": 0, "host": -1}
		var rects := ShipRenderer.layout(parts)
		var hr: Rect2 = rects[host]
		var mount := 0.5 if hr.size.y <= 1.0 else clampf((hr.end.y - local.y) / hr.size.y, 0.0, 1.0)
		var side := 0
		if local.x < hr.position.x - 4.0:
			side = -1
		elif local.x > hr.end.x + 4.0:
			side = 1
		var index := host + 1
		while index < parts.size() and parts[index].def.radial:
			index += 1
		return {"index": index, "mount": mount, "side": side, "host": host, "host_rect": hr, "size": def.size, "kind": def.kind}

	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and data.has("def")):
			return false
		var def: PartDef = data.def
		var local := to_local_ship(at)
		if def.radial:
			hint = attach_plan(local, def)
			hint.radial = true
		else:
			hint = {"radial": false, "y": at.y, "index": stack_index(local.y)}
		queue_redraw()
		return true

	func _drop_data(at: Vector2, data: Variant) -> void:
		var local := to_local_ship(at)
		if data.has("from"):
			var from := int(data.from)
			var moved: ShipPart = Run.ship.parts[from]
			if moved.def.radial:
				var plan := attach_plan(local, moved.def)
				phase.relocate_part(from, plan.index, plan.mount, plan.side)
			else:
				phase.relocate_part(from, stack_index(local.y))
		else:
			var def: PartDef = data.def
			if def.radial:
				var plan2 := attach_plan(local, def)
				phase.add_part(def, plan2.index, data.get("stock"), plan2.mount, plan2.side)
			else:
				phase.add_part(def, stack_index(local.y), data.get("stock"))
		hint.clear()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			hint.clear()
			queue_redraw()

	func _get_drag_data(at: Vector2) -> Variant:
		var index := ShipRenderer.pick(Run.ship.parts, to_local_ship(at))
		if index < 0:
			return null
		var part: ShipPart = Run.ship.parts[index]
		var preview := Label.new()
		preview.text = "  - " + part.def.display_name
		preview.add_theme_color_override("font_color", Ui.LAMP_WARNING)
		set_drag_preview(preview)
		return {"from": index, "def": part.def}

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			var index := ShipRenderer.pick(Run.ship.parts, to_local_ship(event.position))
			if event.button_index == MOUSE_BUTTON_LEFT:
				phase.select(index)
			elif event.button_index == MOUSE_BUTTON_RIGHT and index >= 0:
				phase.remove_part(index)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var o := origin()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.06, 0.12, 0.85))
		for x: int in range(0, int(size.x), 32):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.45, 0.7, 0.08), 1.0)
		for y: int in range(0, int(size.y), 32):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.45, 0.7, 0.08), 1.0)
		draw_rect(Rect2(0, o.y, size.x, size.y - o.y), Color(0.08, 0.09, 0.11))
		draw_line(Vector2(0, o.y), Vector2(size.x, o.y), Ui.LAMP_CAUTION * Color(1, 1, 1, 0.6), 2.0)
		for k: int in 12:
			var x := o.x - 300.0 + k * 50.0
			draw_line(Vector2(x, o.y + 4), Vector2(x - 20, size.y), Color(1.0, 0.8, 0.1, 0.15), 6.0)
		draw_set_transform(o, 0.0, Vector2(scale_factor, scale_factor))
		ShipRenderer.draw(self, Run.ship.parts, {"selected": phase.selected_index()})
		var rects := ShipRenderer.layout(Run.ship.parts)
		var stage := 1
		for i: int in Run.ship.parts.size():
			if Run.ship.parts[i].def.kind == &"decoupler":
				draw_string(Ui.sans(), Vector2(rects[i].end.x + 40, rects[i].get_center().y + 4), tr("etapa %d") % (stage + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.IVORY)
				stage += 1
		if hint.get("radial", false) and hint.get("host", -1) >= 0:
			var hr: Rect2 = hint.host_rect
			draw_rect(hr.grow(3), Color(Ui.INFO, 0.35), false, 2.0)
			var ghost := ShipRenderer.mount_rect(hr, hint.size, hint.mount, hint.side, hint.kind)
			draw_rect(ghost, Color(Ui.IVORY, 0.35))
			draw_rect(ghost, Ui.IVORY, false, 1.5)
			if int(hint.side) == 0:
				draw_rect(ShipRenderer.mirror(ghost), Color(Ui.IVORY, 0.35))
				draw_rect(ShipRenderer.mirror(ghost), Ui.IVORY, false, 1.5)
			var tag := tr("ambos lados") if hint.side == 0 else (tr("izquierda") if hint.side < 0 else tr("derecha"))
			draw_string(Ui.sans(), Vector2(hr.end.x + 12, ghost.get_center().y), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.IVORY)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not hint.is_empty() and not hint.get("radial", false):
			draw_line(Vector2(o.x - 120, float(hint.y)), Vector2(o.x + 120, float(hint.y)), Ui.IVORY, 2.0)
		if Run.ship.parts.is_empty():
			var hint_w := minf(440.0, maxf(size.x - 48.0, 200.0))
			var hx := o.x - hint_w * 0.5
			draw_multiline_string(Ui.sans(), Vector2(hx, o.y - 208), tr("Empieza por la cápsula, un motor y un tanque."), HORIZONTAL_ALIGNMENT_CENTER, hint_w, Ui.SIZE_TEXT, -1, Ui.IVORY)
			draw_multiline_string(Ui.sans(), Vector2(hx, o.y - 178), tr("Haz clic en el catálogo y se colocan solas. Arrastra para moverlas."), HORIZONTAL_ALIGNMENT_CENTER, hint_w, Ui.SIZE_LEGEND, -1, Ui.INFO)
		var bar_rect := Rect2(8, size.y - 30, size.x - 16, 22)
		draw_rect(bar_rect, Color(Ui.BAKELITE, 0.88))
		draw_string(Ui.sans(), Vector2(14, size.y - 14), tr("Pila: centro | Montaje: izquierda/derecha del bloque | Clic derecho/Supr: quitar"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, Ui.SIZE_LEGEND, Ui.IVORY_DIM)


func _ready() -> void:
	if Run.contract == null:
		Run.debug_setup()
		Run.ship.parts.clear()
	for data: Variant in Profile.inventory:
		var part := ShipPart.from_dict(data)
		if part != null:
			_inventory.append(part)
	var stars := Starfield.new()
	add_child(stars)
	stars.set_sky(Color(0.014, 0.02, 0.052), 0.65)
	var root := Ui.root(self)
	_build_left(root)
	_build_center(root)
	_build_right(root)
	_build_hover_card(root)
	_refresh()


func _build_left(root: Control) -> void:
	var zone := DropZone.new()
	zone.phase = self
	Ui.glass(zone)
	zone.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	zone.offset_left = 10
	zone.offset_right = 340
	zone.offset_top = Pause.GEAR_RECT.end.y + 8.0 # el catalogo empieza debajo del engranaje
	zone.offset_bottom = -10
	root.add_child(zone)
	var col := Ui.vbox(zone, 8)
	Ui.plate(col, tr("Catálogo"))
	Ui.legend(col, tr("Calidad de compra"))
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	col.add_child(row)
	for q: int in [ShipPart.Quality.SCRAP, ShipPart.Quality.USED, ShipPart.Quality.NEW, ShipPart.Quality.MYSTERY]:
		var b := Ui.button(row, tr(ShipPart.NAMES[q]), _set_quality.bind(q))
		b.toggle_mode = true
		b.tooltip_text = tr("%s: precio x%.2f, estado %d-%d %%") % [tr(ShipPart.NAMES[q]), ShipPart.PRICE[q], int(ShipPart.CONDITION[q].x * 100), int(ShipPart.CONDITION[q].y * 100)]
		b.add_theme_font_size_override("font_size", Ui.SIZE_LEGEND)
		Ui.mark_selected(b, q == _quality)
		_quality_buttons.append(b)
	_quality_note = Ui.label(col, "", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	_quality_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quality_note.custom_minimum_size = Vector2(300, 0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_catalog = Ui.vbox(scroll, 4)
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_catalog()
	Kinetic.enter_deferred(zone, 0.02, {"slide": true, "slide_offset": Vector2(-30.0, 16.0), "scale": Vector2(0.95, 0.92), "tilt": -0.016, "duration": 0.34})


func _fill_catalog() -> void:
	_part_lamps.clear()
	for child: Node in _catalog.get_children():
		child.queue_free()
	for i: int in _quality_buttons.size():
		_quality_buttons[i].button_pressed = [ShipPart.Quality.SCRAP, ShipPart.Quality.USED, ShipPart.Quality.NEW, ShipPart.Quality.MYSTERY][i] == _quality
		Ui.mark_selected(_quality_buttons[i], _quality_buttons[i].button_pressed)
	if not _inventory.is_empty():
		Ui.legend(_catalog, tr("Inventario (gratis)"))
		for part: ShipPart in _inventory:
			_catalog_button(part.def, "%s  [%s]" % [part.def.display_name, part.quality_text()], part)
	var added: Array = []
	for group: Array in GROUPS:
		added.append(Ui.legend(_catalog, tr(String(group[0]))))
		for kind: StringName in group[1]:
			for def: PartDef in Catalog.part_list():
				if def.kind == kind:
					var price := int(round(def.cost * ShipPart.PRICE[_quality]))
					added.append(_catalog_button(def, "%s  %s" % [def.display_name, Ui.money(price)], null))
	Ui.legend(_catalog, tr("Apuesta"))
	var box := Ui.button(_catalog, tr("Caja misteriosa  %s") % Ui.money(BOX_COST), _buy_box)
	box.add_theme_color_override("font_color", Ui.MYSTERY)
	box.mouse_entered.connect(_show_box_hover.bind(box))
	box.mouse_exited.connect(hide_part_hover.bind(box))
	box.focus_entered.connect(_show_box_hover.bind(box))
	box.focus_exited.connect(hide_part_hover.bind(box))
	_quality_note.text = _quality_note_text()
	_paint_part_lamps()
	Kinetic.cascade(added, 0.012, 0.22, {"scale": Vector2(0.94, 0.88), "tilt": -0.012, "duration": 0.24})


func _catalog_button(def: PartDef, text: String, stock: ShipPart) -> PartButton:
	var row := Ui.hbox(_catalog, 4)
	var b := PartButton.new()
	b.phase = self
	b.def = def
	b.stock = stock
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_size_override("font_size", 13)
	b.mouse_entered.connect(show_part_hover.bind(b, def, stock))
	b.mouse_exited.connect(hide_part_hover.bind(b))
	b.focus_entered.connect(show_part_hover.bind(b, def, stock))
	b.focus_exited.connect(hide_part_hover.bind(b))
	b.pressed.connect(func() -> void:
		Synth.play(&"click")
		add_part(def, Run.ship.auto_index(def), stock))
	Kinetic.bind_button(b, 0.7, 1.025)
	row.add_child(b)
	var lamp := Lamp.new("", Lamp.OFF)
	lamp.custom_minimum_size = Vector2(64, 24)
	lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lamp)
	_part_lamps.append([lamp, def, stock])
	return b


func _quality_note_text() -> String:
	match _quality:
		ShipPart.Quality.SCRAP: return tr("Chatarra: 65 % más barata, falla seguido.")
		ShipPart.Quality.USED: return tr("Usada: 35 % más barata, puede venir gastada.")
		ShipPart.Quality.NEW: return tr("Nueva: precio completo, casi no falla.")
		ShipPart.Quality.MYSTERY: return tr("Misteriosa: mitad de precio, calidad oculta hasta inspeccionarla.")
	return ""


func _paint_part_lamps() -> void:
	for entry: Array in _part_lamps:
		var lamp: Lamp = entry[0]
		var def: PartDef = entry[1]
		var stock: ShipPart = entry[2]
		var v: Dictionary = part_viability(def, stock)
		var badge := String(v.badge)
		var state := Lamp.OFF
		var legend := ""
		if not bool(v.affordable):
			legend = tr("Cara")
			state = Lamp.WARNING
		elif badge == tr("NECESARIA"):
			legend = tr("Vital")
			state = Lamp.GO
		elif int(v.tone) == Lamp.GO:
			legend = tr("Útil")
			state = Lamp.GO
		elif badge == tr("NO NECESARIA"):
			legend = tr("Sobra")
			state = Lamp.CAUTION
		elif int(v.tone) == Lamp.CAUTION:
			legend = tr("Ojo")
			state = Lamp.CAUTION
		elif badge == tr("YA CUBIERTA"):
			legend = tr("Ya hay")
			state = Lamp.OFF
		lamp.text = legend.to_upper()
		lamp.state = state
		lamp.modulate.a = 0.0 if legend == "" else 1.0


func _build_center(root: Control) -> void:
	_view = ShipView.new()
	_view.phase = self
	_view.clip_contents = true
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.offset_left = 350
	_view.offset_top = 10
	_view.offset_right = -350
	_view.offset_bottom = -10
	root.add_child(_view)
	Kinetic.enter_deferred(_view, 0.05, {"scale": Vector2(0.93, 0.90), "tilt": -0.012, "beam": true, "duration": 0.36})


func _build_right(root: Control) -> void:
	var panel := Ui.panel(root)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -340
	panel.offset_right = -10
	panel.offset_top = 10
	panel.offset_bottom = -10
	panel.clip_contents = true
	var col := Ui.vbox(panel, 6)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var info := Ui.vbox(scroll, 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.plate(info, tr("Ingeniería"))
	_contract_label = Ui.label(info, "", 13, Ui.IVORY)
	_fit_copy(_contract_label)
	Ui.legend(info, tr("Presupuesto libre / total"))
	_budget_label = Ui.label(info, "", Ui.SIZE_HEAD, Ui.IVORY)
	_budget_label.add_theme_font_override("font", Ui.mono())
	Ui.legend(info, tr("Siguiente paso"))
	_next_label = Ui.label(info, "", Ui.SIZE_TEXT, Ui.IVORY)
	_fit_copy(_next_label)
	_req_box = Ui.vbox(info, 1)
	_dv = Gauge.new(tr("Delta-v"), Ui.INFO)
	info.add_child(_dv)
	_twr_label = Ui.label(info, "", 14)
	_stages_label = Ui.label(info, "", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	_fit_copy(_stages_label)
	_risk_label = Ui.label(info, "", 14)
	var sep := HSeparator.new()
	info.add_child(sep)
	_part_box = Ui.vbox(info, 4)
	_launch_note = Ui.label(col, "", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	_fit_copy(_launch_note)
	_launch = Ui.primary(Ui.button(col, tr("Despegar"), _on_launch))
	_launch.custom_minimum_size = Vector2(0, 48)
	_launch.add_theme_font_size_override("font_size", 22)
	Ui.button(col, tr("Volver al hangar"), func() -> void:
		Run.ship.parts.clear()
		Router.go(&"hangar"))
	Kinetic.enter_deferred(panel, 0.08, {"slide": true, "slide_offset": Vector2(24.0, 14.0), "scale": Vector2(0.95, 0.92), "tilt": 0.016, "beam": true, "duration": 0.34})


func _unhandled_input(_event: InputEvent) -> void:
	if Controls.cmd_just(&"cmd_abort") and _selected >= 0:
		remove_part(_selected)
		get_viewport().set_input_as_handled()


func selected_index() -> int:
	return _selected


func _set_quality(q: int) -> void:
	_quality = q
	_fill_catalog()


func _spent() -> int:
	var total := Run.ship.value() + Run.spent
	return total + _premium(Run.ship.value())


func _premium(value: int) -> int:
	return int(round(value * Profile.premium_rate()))


func _remaining() -> int:
	return Profile.budget(Run.contract) - _spent()


## Lista de despegue en orden de armado. Fila: label, state (Lamp.*), hint y blocks (impide despegar).
static func checklist(ship: ShipModel, contract: Contract, target: BodyDef, remaining: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var has_capsule := ship.has_kind(&"capsule")
	var has_thrust := ship.thrust() > 0.0
	var has_fuel := ship.fuel_capacity() > 0.0
	rows.append({"label": Loc.t("Cápsula"), "state": Lamp.GO if has_capsule else Lamp.WARNING, "hint": "" if has_capsule else Loc.t("Sin cápsula no hay tripulación ni mando. Agrega la cápsula Apolo."), "blocks": not has_capsule})
	rows.append({"label": Loc.t("Motor"), "state": Lamp.GO if has_thrust else Lamp.WARNING, "hint": "" if has_thrust else Loc.t("Sin motor la nave no se mueve. Agrega un motor de Lo básico."), "blocks": not has_thrust})
	rows.append({"label": Loc.t("Combustible"), "state": Lamp.GO if has_fuel else Lamp.WARNING, "hint": "" if has_fuel else Loc.t("Un motor sin tanque no tiene qué quemar. Agrega un tanque."), "blocks": false})
	var home := Catalog.home()
	var twr := ship.twr(home.surface_gravity) if home != null else 0.0
	var lift_state := Lamp.OFF
	var lift_hint := ""
	if has_thrust and has_fuel:
		if twr < 1.0:
			lift_state = Lamp.WARNING
			lift_hint = Loc.t("Los motores no levantan el peso de la nave (empuje entre peso %.2f, hace falta más de 1). Pon un motor más fuerte o quita peso.") % twr
		elif twr < 1.2:
			lift_state = Lamp.CAUTION
			lift_hint = Loc.t("Despega justo (empuje entre peso %.2f). Con más de 1.2 sube con margen.") % twr
		else:
			lift_state = Lamp.GO
	rows.append({"label": Loc.t("Levanta el vuelo"), "state": lift_state, "hint": lift_hint, "blocks": false})
	var destination := Loc.t("Alcanza el destino") if target == null else Loc.t("Alcanza %s") % target.display_name
	var reach_state := Lamp.OFF
	var reach_hint := ""
	if has_thrust and has_fuel:
		var dv := ship.delta_v()
		var need := contract.dv_estimate
		if dv < need * 0.85:
			reach_state = Lamp.WARNING
			reach_hint = Loc.t("El combustible alcanza para %d de %d m/s. Agrega un tanque o una segunda etapa con pernos de etapa.") % [int(dv), int(need)]
		elif dv < need:
			reach_state = Lamp.CAUTION
			reach_hint = Loc.t("Vas justo de combustible: %d de %d m/s.") % [int(dv), int(need)]
		else:
			reach_state = Lamp.GO
	rows.append({"label": destination, "state": reach_state, "hint": reach_hint, "blocks": false})
	for req: Array in Thermal.requirements(ship, target):
		var req_label: String = String(req[0])
		var req_ok: bool = bool(req[1])
		var req_hint: String = String(req[2])
		rows.append({"label": req_label, "state": Lamp.GO if req_ok else Lamp.WARNING, "hint": "" if req_ok else req_hint, "blocks": false})
	var budget_ok := remaining >= 0
	rows.append({"label": Loc.t("Presupuesto"), "state": Lamp.GO if budget_ok else Lamp.WARNING, "hint": "" if budget_ok else Loc.t("Te pasaste por %s. Quita piezas o compra calidad Usada o Chatarra.") % Ui.money(-remaining), "blocks": not budget_ok})
	return rows


func add_part(def: PartDef, index: int, stock: ShipPart = null, mount: float = 0.5, side: int = 0) -> void:
	var part: ShipPart = stock
	if part == null:
		part = ShipPart.create(def, _quality, Run.rng)
		if _remaining() - part.price() - _premium(part.price()) < 0:
			Synth.play(&"deny")
			Events.toast.emit(tr("Sin presupuesto para %s") % def.display_name, Ui.LAMP_WARNING)
			return
	else:
		_inventory.erase(part)
		_fill_catalog()
	if def.radial:
		part.mount = clampf(mount, 0.0, 1.0)
		part.side = clampi(side, -1, 1)
	Run.ship.parts.insert(clampi(index, 0, Run.ship.parts.size()), part)
	_selected = Run.ship.parts.find(part)
	Synth.play(&"thud", -6.0, 1.4)
	Kinetic.pop(_view, Vector2(1.02, 0.985), 0.20)
	_refresh()


func _buy_box() -> void:
	var part := Run.random_part(ShipPart.Quality.MYSTERY)
	part.paid = BOX_COST
	if _remaining() - BOX_COST - _premium(BOX_COST) < 0:
		Synth.play(&"deny")
		return
	Run.ship.parts.append(part)
	_selected = Run.ship.parts.size() - 1
	Synth.play(&"whoosh")
	Events.toast.emit(tr("La caja contenia: %s") % part.def.display_name, Ui.MYSTERY)
	_refresh()


func relocate_part(from: int, to: int, mount: float = 0.5, side: int = 0) -> void:
	if from < 0 or from >= Run.ship.parts.size():
		return
	var part: ShipPart = Run.ship.parts[from]
	Run.ship.parts.remove_at(from)
	if to > from:
		to -= 1
	if part.def.radial:
		part.mount = clampf(mount, 0.0, 1.0)
		part.side = clampi(side, -1, 1)
	Run.ship.parts.insert(clampi(to, 0, Run.ship.parts.size()), part)
	_selected = Run.ship.parts.find(part)
	Synth.play(&"tick")
	_refresh()


func remove_part(index: int) -> void:
	if index < 0 or index >= Run.ship.parts.size():
		return
	var part: ShipPart = Run.ship.parts[index]
	Run.ship.parts.remove_at(index)
	if part.owned:
		_inventory.append(part)
		_fill_catalog()
	_selected = -1
	Synth.play(&"whoosh", -8.0)
	_refresh()


func select(index: int) -> void:
	_selected = index
	_refresh()


func _inspect() -> void:
	if _selected < 0:
		return
	var part: ShipPart = Run.ship.parts[_selected]
	if Run.free_inspections > 0:
		Run.free_inspections -= 1
	elif _remaining() >= INSPECT_COST:
		Run.spent += INSPECT_COST
	else:
		Synth.play(&"deny")
		return
	part.inspected = true
	part.revealed = true
	Synth.play(&"beep")
	var color := Ui.LAMP_GO if part.condition > 0.8 else (Ui.LAMP_CAUTION if part.condition > 0.55 else Ui.LAMP_WARNING)
	Events.toast.emit("%s: %s, %d %%" % [part.def.display_name, part.health_text(), int(part.condition * 100.0)], color)
	_refresh()


func stats_text(def: PartDef) -> String:
	var bits: PackedStringArray = PackedStringArray([tr("Masa %.1f t") % def.mass])
	if def.thrust > 0.0: bits.append(tr("Empuje %d kN  Isp %d s") % [int(def.thrust), int(def.isp)])
	if def.fuel > 0.0: bits.append(tr("Propelente %.0f t") % def.fuel)
	if def.solar > 0.0: bits.append(tr("Solar %.1f") % def.solar)
	if def.power > 0.0: bits.append(tr("Energía %.1f") % def.power)
	if def.battery > 0.0: bits.append(tr("Batería %.1f") % def.battery)
	if def.cooling > 0.0: bits.append(tr("Enfriamiento %.1f") % def.cooling)
	if def.cold_resist > 0.0: bits.append(tr("Aislamiento %d %%") % int(def.cold_resist * 100))
	if def.heat_resist > 0.0: bits.append(tr("Resist. calor %d %%") % int(def.heat_resist * 100))
	if def.rad_resist > 0.0: bits.append(tr("Blindaje %d %%") % int(def.rad_resist * 100))
	if def.ablative > 0.0: bits.append(tr("Ablativo %.0f") % def.ablative)
	bits.append(tr("Fragilidad x%.1f") % def.fragility)
	return "  ".join(bits)


func _refresh() -> void:
	var ship := Run.ship
	var target := Run.target()
	var remaining := _remaining()
	var rows: Array[Dictionary] = checklist(ship, Run.contract, target, remaining)
	_view.fit()
	var hazards: PackedStringArray = PackedStringArray()
	for h: StringName in target.hazards:
		hazards.append(tr(String(HAZARD_NAMES.get(h, h))))
	if Run.contract.hidden_hazard != &"":
		hazards.append(tr("rumores sin confirmar"))
	_contract_label.text = tr("%s\nPago %s, adelanto %s\nPeligros: %s") % [
		Run.contract.title, Ui.money(Run.contract.payout), Ui.money(Run.contract.advance),
		", ".join(hazards) if not hazards.is_empty() else tr("ninguno conocido")]
	_budget_label.text = "%s / %s" % [Ui.money(remaining), Ui.money(Profile.budget(Run.contract))]
	_budget_label.add_theme_color_override("font_color", Ui.IVORY if remaining >= 0 else Ui.LAMP_WARNING)
	var dv := ship.delta_v()
	var need := Run.contract.dv_estimate
	var top := maxf(need * 1.6, dv)
	_dv.set_value(dv / top, tr("%d de %d m/s") % [int(dv), int(need)], dv < need * 0.85)
	_dv.band = Vector2(need * 0.85 / top, need * 1.15 / top)
	var home := Catalog.home()
	var twr := ship.twr(home.surface_gravity)
	_twr_label.text = tr("TWR al despegar %.2f%s") % [twr, tr(" (no despega)") if twr < 1.0 else ""]
	_twr_label.add_theme_color_override("font_color", Ui.LAMP_GO if twr >= 1.2 else (Ui.LAMP_CAUTION if twr >= 1.0 else Ui.LAMP_WARNING))
	var lines: PackedStringArray = PackedStringArray()
	var dvs := ship.stage_dvs()
	for i: int in dvs.size():
		lines.append(tr("Etapa %d   %5d m/s   TWR %.2f") % [i + 1, int(dvs[i]), ship.stage_twr(i, home.surface_gravity)])
	lines.append(tr("Masa %.1f t   Valor %s   Prima seguro %s") % [ship.mass(), Ui.money(ship.value()), Ui.money(_premium(ship.value()))])
	_stages_label.text = "\n".join(lines)
	for child: Node in _req_box.get_children():
		child.queue_free()
	Ui.legend(_req_box, tr("Lista de despegue"))
	var first_warning := ""
	var first_caution := ""
	var blocked_hint := ""
	var has_warning := false
	var has_caution := false
	var has_block := false
	for row: Dictionary in rows:
		var state: int = int(row.state)
		var legend := "OK" if state == Lamp.GO else (tr("Falta") if state == Lamp.WARNING else (tr("Justo") if state == Lamp.CAUTION else tr("Luego")))
		var req_row := Ui.hbox(_req_box, 6)
		var lamp := Lamp.new(legend, state)
		lamp.custom_minimum_size.x = 64
		req_row.add_child(lamp)
		var row_label := Ui.label(req_row, String(row.label), Ui.SIZE_LEGEND, Ui.IVORY)
		_fit_copy(row_label)
		row_label.tooltip_text = String(row.hint)
		row_label.mouse_filter = Control.MOUSE_FILTER_PASS
		if state == Lamp.WARNING:
			has_warning = true
			if first_warning == "":
				first_warning = String(row.hint)
		elif state == Lamp.CAUTION:
			has_caution = true
			if first_caution == "":
				first_caution = String(row.hint)
		if bool(row.blocks):
			has_block = true
			if blocked_hint == "":
				blocked_hint = String(row.hint)
	if first_warning != "":
		_next_label.text = first_warning
		_next_label.add_theme_color_override("font_color", Ui.LAMP_WARNING)
	elif first_caution != "":
		_next_label.text = first_caution
		_next_label.add_theme_color_override("font_color", Ui.LAMP_CAUTION)
	else:
		_next_label.text = tr("La nave cumple la lista. Puedes despegar.")
		_next_label.add_theme_color_override("font_color", Ui.LAMP_GO)
	var rel := Odds.ship_reliability(ship)
	_risk_label.text = tr("Fiabilidad estimada: %d a %d %%") % [int(rel.x * 100.0), int(rel.y * 100.0)]
	_risk_label.add_theme_color_override("font_color", Odds.risk_color((rel.x + rel.y) * 0.5))
	_refresh_part()
	_launch.disabled = has_block
	if has_block:
		_launch_note.text = tr("No puedes despegar todavía. ") + blocked_hint
		_launch_note.add_theme_color_override("font_color", Ui.LAMP_WARNING)
	elif has_warning or has_caution:
		_launch_note.text = tr("Puedes despegar, pero la lista tiene avisos.")
		_launch_note.add_theme_color_override("font_color", Ui.LAMP_CAUTION)
	else:
		_launch_note.text = tr("Lista para despegar.")
		_launch_note.add_theme_color_override("font_color", Ui.LAMP_GO)
	_paint_part_lamps()
	if _hover_card != null and _hover_card.visible and is_instance_valid(_hover_owner):
		if _hover_owner is PartButton:
			var pb := _hover_owner as PartButton
			show_part_hover(pb, pb.def, pb.stock)
		else:
			_show_box_hover(_hover_owner)


func _refresh_part() -> void:
	for child: Node in _part_box.get_children():
		child.queue_free()
	if _selected < 0 or _selected >= Run.ship.parts.size():
		Ui.label(_part_box, tr("Selecciona una pieza para ver su estado."), Ui.SIZE_LEGEND, Ui.IVORY_DIM)
		return
	var part: ShipPart = Run.ship.parts[_selected]
	Ui.label(_part_box, part.def.display_name, 17, Ui.IVORY)
	var place := tr("pila / %s") % Run.ship.zone_of(part)
	if part.def.radial:
		var side := tr("ambos") if part.side == 0 else (tr("izq") if part.side < 0 else tr("der"))
		place = tr("montaje %s  altura %d %%") % [side, int(part.mount * 100.0)]
	var detail := Ui.label(_part_box, tr("Calidad %s   %s   Estado %s   %s") % [part.quality_text(), part.health_text(true), part.condition_text(), place], Ui.SIZE_LEGEND)
	_fit_copy(detail)
	var stats := Ui.label(_part_box, stats_text(part.def), Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	_fit_copy(stats)
	var row := Ui.hbox(_part_box, 6)
	if not part.inspected:
		var cost := tr("gratis") if Run.free_inspections > 0 else Ui.money(INSPECT_COST)
		Ui.button(row, tr("Inspeccionar (%s)") % cost, _inspect)
	Ui.button(row, tr("Quitar"), remove_part.bind(_selected))


func _fit_copy(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 0)


func _on_launch() -> void:
	var total := _spent()
	Run.premium = _premium(Run.ship.value())
	Run.spent = total
	Profile.credits = Profile.budget(Run.contract) - total
	var remaining_inventory: Array = []
	for part: ShipPart in _inventory:
		remaining_inventory.append(part.to_dict())
	Profile.inventory = remaining_inventory
	Profile.runs += 1
	Profile.clear_board()
	Profile.save_profile()
	Synth.play(&"ignite", -6.0)
	Router.go(&"launch")


func _build_hover_card(root: Control) -> void:
	_hover_card = PanelContainer.new()
	Ui.glass(_hover_card)
	_hover_card.visible = false
	_hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_card.custom_minimum_size = Vector2(310, 0)
	_hover_card.set_meta(&"layout_overlay", true)
	_hover_card.add_theme_stylebox_override("panel", Ui.bezel(Ui.INFO))
	root.add_child(_hover_card)
	var col := Ui.vbox(_hover_card, 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := Ui.hbox(col, 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_title = Ui.label(head, "", 16, Ui.IVORY)
	_hover_title.add_theme_font_override("font", Ui.bold())
	_hover_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hover_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_badge = Lamp.new("", Lamp.OFF)
	_hover_badge.custom_minimum_size = Vector2(126, 24)
	_hover_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_hover_badge)
	_hover_role = Ui.label(col, "", 13, Ui.IVORY)
	_hover_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_role.custom_minimum_size = Vector2(286, 0)
	_hover_role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_reason = Ui.label(col, "", 13, Ui.INFO)
	_hover_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_reason.custom_minimum_size = Vector2(286, 0)
	_hover_reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_stats = Ui.label(col, "", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	_hover_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_stats.custom_minimum_size = Vector2(286, 0)
	_hover_stats.add_theme_font_override("font", Ui.mono())
	_hover_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_part_hover(anchor: Control, def: PartDef, stock: ShipPart = null) -> void:
	if _hover_card == null or def == null:
		return
	_hover_owner = anchor
	var v := part_viability(def, stock)
	_hover_title.text = "%s (%s)" % [def.display_name, tr("gratis") if stock != null else Ui.money(int(v.price))]
	_hover_badge.text = String(v.badge)
	_hover_badge.state = int(v.tone)
	var accent := Lamp.color_of(int(v.tone)) if int(v.tone) != Lamp.OFF else Ui.INFO
	_hover_card.add_theme_stylebox_override("panel", Ui.bezel(accent))
	_hover_role.text = String(v.role)
	_hover_reason.text = String(v.reason)
	_hover_reason.add_theme_color_override("font_color", Ui.LAMP_WARNING if not bool(v.affordable) else (Ui.LAMP_GO if int(v.tone) == Lamp.GO else (Ui.LAMP_CAUTION if int(v.tone) == Lamp.CAUTION else Ui.INFO)))
	_hover_stats.text = stats_text(def)
	_present_hover_card(anchor, accent)


func _show_box_hover(anchor: Control) -> void:
	if _hover_card == null:
		return
	_hover_owner = anchor
	var need := BOX_COST + _premium(BOX_COST)
	var affordable := _remaining() >= need
	_hover_title.text = tr("Caja misteriosa (%s)") % Ui.money(BOX_COST)
	_hover_badge.text = tr("APUESTA") if affordable else tr("SIN SALDO")
	_hover_badge.state = Lamp.CAUTION if affordable else Lamp.WARNING
	var accent := Ui.MYSTERY if affordable else Ui.LAMP_WARNING
	_hover_card.add_theme_stylebox_override("panel", Ui.bezel(accent))
	_hover_role.text = tr("Entrega una pieza aleatoria de calidad oculta.")
	_hover_reason.text = tr("Viable si quieres arriesgar para ahorrar o sacar piezas raras.") if affordable else tr("No viable: supera el presupuesto libre (%s).") % Ui.money(_remaining())
	_hover_reason.add_theme_color_override("font_color", accent)
	_hover_stats.text = tr("Costo %s (+ prima %s)") % [Ui.money(BOX_COST), Ui.money(_premium(BOX_COST))]
	_present_hover_card(anchor, accent)


func _present_hover_card(anchor: Control, accent: Color) -> void:
	if _hover_card == null:
		return
	var was_open := _hover_card.visible and _hover_card.modulate.a > 0.35
	_hover_card.visible = true
	_place_hover_card.call_deferred(anchor, was_open, accent)


func hide_part_hover(anchor: Control) -> void:
	if _hover_card == null:
		return
	if anchor == null or anchor == _hover_owner:
		_hover_owner = null
		if anchor == null:
			_hover_card.visible = false
		else:
			Kinetic.fold_toggle(_hover_card, false, 0.14)


func _place_hover_card(anchor: Control, was_open: bool = false, accent: Color = Ui.INFO) -> void:
	if _hover_card == null or not _hover_card.visible or not is_instance_valid(anchor):
		return
	var vp := get_viewport().get_visible_rect().size
	var h := _hover_card.get_combined_minimum_size().y
	var y := clampf(anchor.global_position.y - 10.0, 12.0, maxf(12.0, vp.y - h - 12.0))
	var dest := Vector2(348.0, y)
	_hover_card.set_meta("_kinetic_rest_pos", dest)
	if Kinetic.is_reduced():
		_hover_card.position = dest
		_hover_card.modulate.a = 1.0
		_hover_card.scale = Vector2.ONE
		_hover_card.rotation = 0.0
		return
	if not was_open:
		_hover_card.position = dest
		Kinetic.enter(_hover_card, 0.0, {
			"slide": true,
			"slide_offset": Vector2(-20.0, 12.0),
			"target_pos": dest,
			"scale": Vector2(0.90, 0.84),
			"tilt": -0.028,
			"elastic": true,
			"duration": 0.24,
			"beam": true,
			"beam_color": Color(accent.r, accent.g, accent.b, 0.24),
		})
	else:
		Kinetic.sync_pivot(_hover_card)
		var tw := _hover_card.create_tween()
		tw.tween_property(_hover_card, "position", dest, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		Kinetic.pop(_hover_card, Vector2(1.025, 0.96), 0.16)


## Resume funcion y viabilidad de una pieza para el contrato y nave actuales.
func part_viability(def: PartDef, stock: ShipPart = null) -> Dictionary:
	var ship := Run.ship
	var target := Run.target()
	var price := 0 if stock != null else int(round(def.cost * ShipPart.PRICE[_quality]))
	var total_cost := price + _premium(price)
	var affordable := _remaining() >= total_cost
	var role := def.description
	var badge := tr("OPCIONAL")
	var tone := Lamp.OFF
	var reason := tr("Suma capacidad adicional a la nave.")

	var r := target.orbit_radius if target != null else Thermal.HOME_R
	if target != null and target.parent_id != &"" and Catalog.body(target.parent_id) != null and not Catalog.body(target.parent_id).is_star:
		r = Catalog.body(target.parent_id).orbit_radius
	var f_target := Thermal.flux(r)
	var f_min := minf(f_target, 1.0)
	var f_max := maxf(f_target, 1.0)
	var t_hot := Thermal.equilibrium(f_max, ship)
	var t_cold := Thermal.equilibrium(f_min, ship)
	var power_deficit := Thermal.power_gen(f_min, ship) < Thermal.power_use(ship)
	var dv_missing := Run.contract != null and ship.delta_v() < Run.contract.dv_estimate * 0.9

	match def.kind:
		&"capsule":
			if not ship.has_kind(&"capsule"):
				badge = tr("NECESARIA")
				tone = Lamp.GO
				reason = tr("Obligatoria: centro de mando sin el cual no puedes despegar.")
			else:
				badge = tr("YA CUBIERTA")
				reason = tr("Ya llevas cápsula; otra añade masa extra y consumo eléctrico.")
		&"engine":
			var home := Catalog.home()
			var twr := ship.twr(home.surface_gravity) if home != null else 0.0
			if ship.thrust() <= 0.0:
				if def.id == &"motor_susurro":
					badge = tr("POCO VIABLE")
					tone = Lamp.CAUTION
					reason = tr("Empuje muy bajo para despegar desde la Tierra; úsalo arriba tras un motor grande.")
				else:
					badge = tr("NECESARIA")
					tone = Lamp.GO
					reason = tr("Indispensable para tener empuje en el despegue.")
			elif twr < 1.2 and def.thrust >= 300.0:
				badge = tr("RECOMENDADA")
				tone = Lamp.GO
				reason = tr("Tu empuje inicial aún es justo (TWR %.2f); este motor ayuda a despegar.") % twr
			elif def.id == &"motor_susurro" and ship.can_stage():
				badge = tr("VIABLE ARRIBA")
				tone = Lamp.GO
				reason = tr("Muy eficiente en el vacío para segunda etapa y ahorro de combustible.")
			else:
				badge = tr("VIABLE")
				reason = tr("Añade empuje para etapa superior o aterrizaje en cuerpos sin aire.")
		&"tank":
			if dv_missing:
				badge = tr("NECESARIA")
				tone = Lamp.GO
				reason = tr("Te falta Delta-v (%d / %d m/s); agrega propelente.") % [int(ship.delta_v()), int(Run.contract.dv_estimate)]
			else:
				badge = tr("OPCIONAL")
				reason = tr("Ya cubres el Delta-v del contrato; más masa baja el TWR al despegar.")
		&"decoupler":
			if ship.of_kind(&"engine").size() >= 1 and ship.of_kind(&"tank").size() >= 1 and not ship.can_stage():
				badge = tr("RECOMENDADA")
				tone = Lamp.GO
				reason = tr("Separa los tanques vacíos del despegue para ganar mucho Delta-v.")
			else:
				badge = tr("VIABLE")
				reason = tr("Útil si quieres dividir la nave en dos etapas independientes.")
		&"heatshield":
			if target != null and target.atmosphere > 0.0:
				if not ship.has_kind(&"heatshield"):
					badge = tr("NECESARIA")
					tone = Lamp.GO
					reason = tr("%s tiene atmósfera: sin escudo te quemas al reentrar.") % target.display_name
				else:
					badge = tr("YA CUBIERTA")
					reason = tr("Ya tienes protección térmica de entrada.")
			else:
				badge = tr("NO NECESARIA")
				tone = Lamp.CAUTION
				reason = tr("Este destino no tiene atmósfera; el escudo solo suma peso muerto.")
		&"parachute":
			if target != null and target.atmosphere > 0.0:
				if not ship.has_kind(&"parachute"):
					badge = tr("NECESARIA")
					tone = Lamp.GO
					reason = tr("%s tiene aire: frena la caída gratis sin gastar combustible.") % target.display_name
				else:
					badge = tr("YA CUBIERTA")
					reason = tr("Ya llevas paracaídas para el descenso.")
			else:
				badge = tr("NO NECESARIA")
				tone = Lamp.CAUTION
				reason = tr("Sin atmósfera no abre el paracaídas; necesitarás motor en la última etapa.")
		&"legs":
			if not ship.has_kind(&"legs"):
				badge = tr("RECOMENDADA")
				tone = Lamp.GO
				reason = tr("Suaviza el golpe al tocar suelo y evita que se dañe el motor al aterrizar.")
			else:
				badge = tr("YA CUBIERTA")
				reason = tr("Ya llevas tren de aterrizaje instalado.")
		&"solar":
			if f_max > 2.5:
				badge = tr("RIESGOSA")
				tone = Lamp.CAUTION
				reason = tr("Cerca del Sol (%s) puede sobrecalentarse; considera un MMRTG o un radiador de amoníaco.") % (target.display_name if target != null else "destino")
			elif f_min < 0.2:
				badge = tr("POCO VIABLE")
				tone = Lamp.CAUTION
				reason = tr("Tan lejos del Sol rinde menos del 20 %; conviene usar un MMRTG.")
			elif power_deficit:
				badge = tr("NECESARIA")
				tone = Lamp.GO
				reason = tr("Genera energía barata para cubrir la electrónica en ruta.")
			else:
				badge = tr("YA CUBIERTA")
				reason = tr("Tu generación eléctrica actual ya alcanza en ruta.")
		&"rtg":
			if f_min < 0.25 or power_deficit:
				badge = tr("MUY VIABLE")
				tone = Lamp.GO
				reason = tr("Energía continua sin depender del Sol; ideal para viajes lejanos o sombra.")
			else:
				badge = tr("VIABLE")
				reason = tr("Cara en presupuesto, pero nunca falla por falta de luz solar.")
		&"battery":
			if ship.sum_stat(&"battery") < 0.5:
				badge = tr("RECOMENDADA")
				tone = Lamp.GO
				reason = tr("Da reserva eléctrica para usar el escáner y cruzar zonas de sombra.")
			else:
				badge = tr("OPCIONAL")
				reason = tr("Ya llevas buena reserva de batería.")
		&"radiator":
			if t_hot >= Thermal.HOT:
				badge = tr("NECESARIA")
				tone = Lamp.GO
				reason = tr("La ruta sobrecalienta la nave (%d %%): sin radiador fallarán piezas.") % int(t_hot * 100.0)
			else:
				badge = tr("OPCIONAL")
				reason = tr("No pasas el límite térmico en esta ruta, salvo que te acerques al Sol.")
		&"insulation":
			if t_cold <= Thermal.COLD:
				badge = tr("NECESARIA")
				tone = Lamp.GO
				reason = tr("Ruta muy fría (%d %%): evita que la nave se congele.") % int(t_cold * 100.0)
			else:
				badge = tr("OPCIONAL")
				reason = tr("La temperatura mínima en esta ruta sigue dentro de rango.")
		&"shielding":
			if target != null and target.hazards.has(&"radiation") and ship.sum_stat(&"rad_resist") < 0.5:
				badge = tr("NECESARIA")
				tone = Lamp.GO
				reason = tr("%s tiene radiación alta; sin blindaje se fríe la electrónica.") % target.display_name
			else:
				badge = tr("OPCIONAL")
				reason = tr("Protege frente a llamaradas solares, aunque añade bastante masa.")
		&"sensor":
			if not ship.has_kind(&"sensor"):
				badge = tr("RECOMENDADA")
				tone = Lamp.GO
				reason = tr("Avisa antes de llamaradas solares y muestra probabilidades de eventos.")
			else:
				badge = tr("YA CUBIERTA")
				reason = tr("Ya llevas sensores activos.")
		&"antenna":
			if not ship.has_kind(&"antenna"):
				badge = tr("RECOMENDADA")
				tone = Lamp.GO
				reason = tr("Evita que los mensajes y alertas de vuelo lleguen cortados.")
			else:
				badge = tr("YA CUBIERTA")
				reason = tr("Ya tienes enlace de comunicaciones.")
		&"computer":
			if not ship.has_kind(&"computer"):
				badge = tr("RECOMENDADA")
				tone = Lamp.GO
				reason = tr("Mantiene precisa la línea de trayectoria en el mapa espacial.")
			else:
				badge = tr("YA CUBIERTA")
				reason = tr("Ya llevas computadora de navegación.")
		&"rcs":
			badge = tr("ÚTIL")
			reason = tr("Mejora el giro y la estabilidad cuando la nave es larga o pesada.")
		&"escape":
			badge = tr("SEGURIDAD")
			reason = tr("Permite abortar el despegue salvando la cápsula si algo sale mal.")

	if not affordable:
		badge = tr("NO VIABLE")
		tone = Lamp.WARNING
		reason = tr("Supera tu presupuesto libre (%s). Prueba calidad Chatarra o quita piezas.") % Ui.money(_remaining())

	return {
		"badge": badge,
		"tone": tone,
		"role": role,
		"reason": reason,
		"price": price,
		"affordable": affordable,
	}
