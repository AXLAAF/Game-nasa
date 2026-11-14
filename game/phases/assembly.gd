extends Node

## Ensamblaje: arrastra piezas a la pila. Las radiales (paneles, antenas, sensores…)
## se anclan a cualquier bloque: altura con el raton, lado izq/der/ambos.

const INSPECT_COST := 25
const BOX_COST := 90
const HAZARD_NAMES := {&"heat": "calor", &"cold": "frío", &"radiation": "radiación", &"dust": "polvo", &"storms": "tormentas"}
const GROUPS: Array = [
	["Propulsión", [&"engine", &"tank", &"decoupler", &"rcs"]],
	["Mando", [&"capsule", &"computer", &"sensor", &"antenna", &"battery"]],
	["Energía y térmico", [&"solar", &"rtg", &"radiator", &"insulation", &"shielding"]],
	["Descenso y seguridad", [&"heatshield", &"parachute", &"legs", &"escape"]],
]

var _quality: int = ShipPart.Quality.NEW
var _selected: int = -1
var _inventory: Array[ShipPart] = []
var _view: ShipView
var _catalog: VBoxContainer
var _quality_buttons: Array[Button] = []
var _budget_label: Label
var _dv: Gauge
var _twr_label: Label
var _stages_label: Label
var _req_box: VBoxContainer
var _risk_label: Label
var _part_box: VBoxContainer
var _launch: Button
var _contract_label: Label


class PartButton extends Button:
	var phase: Node
	var def: PartDef
	var stock: ShipPart

	func _get_drag_data(_at: Vector2) -> Variant:
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
		var room := size.y - 140.0
		scale_factor = clampf(room / maxf(-b.position.y, 1.0), 0.6, 1.8)

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
				draw_string(Ui.sans(), Vector2(rects[i].end.x + 40, rects[i].get_center().y + 4), "etapa %d" % (stage + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.IVORY)
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
			var tag := "ambos lados" if hint.side == 0 else ("izquierda" if hint.side < 0 else "derecha")
			draw_string(Ui.sans(), Vector2(hr.end.x + 12, ghost.get_center().y), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.IVORY)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not hint.is_empty() and not hint.get("radial", false):
			draw_line(Vector2(o.x - 120, float(hint.y)), Vector2(o.x + 120, float(hint.y)), Ui.IVORY, 2.0)
		if Run.ship.parts.is_empty():
			draw_string(Ui.sans(), Vector2(o.x - 200, o.y - 200), "Arrastra piezas aquí (motor abajo, cápsula arriba)", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_TEXT, Ui.IVORY_DIM)
			draw_string(Ui.sans(), Vector2(o.x - 200, o.y - 176), "Paneles, antenas y sensores: suelta a lo largo del casco", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.INFO)
		draw_string(Ui.sans(), Vector2(12, size.y - 12), "Pila: centro | Montaje: izquierda/derecha del bloque | Clic derecho/Supr: quitar", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.IVORY_DIM)


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
	stars.set_sky(Color(0.01, 0.015, 0.035), 0.4)
	var root := Ui.root(self)
	_build_left(root)
	_build_center(root)
	_build_right(root)
	_refresh()


func _build_left(root: Control) -> void:
	var zone := DropZone.new()
	zone.phase = self
	zone.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	zone.offset_left = 10
	zone.offset_right = 340
	zone.offset_top = 10
	zone.offset_bottom = -10
	root.add_child(zone)
	var col := Ui.vbox(zone, 8)
	Ui.plate(col, "Catálogo")
	Ui.legend(col, "Calidad de compra")
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	col.add_child(row)
	for q: int in [ShipPart.Quality.SCRAP, ShipPart.Quality.USED, ShipPart.Quality.NEW, ShipPart.Quality.MYSTERY]:
		var b := Ui.button(row, ShipPart.NAMES[q], _set_quality.bind(q))
		b.toggle_mode = true
		b.tooltip_text = "%s: precio x%.2f, estado %d-%d%%" % [ShipPart.NAMES[q], ShipPart.PRICE[q], int(ShipPart.CONDITION[q].x * 100), int(ShipPart.CONDITION[q].y * 100)]
		b.add_theme_font_size_override("font_size", Ui.SIZE_LEGEND)
		Ui.mark_selected(b, q == _quality)
		_quality_buttons.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_catalog = Ui.vbox(scroll, 4)
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_catalog()


func _fill_catalog() -> void:
	for child: Node in _catalog.get_children():
		child.queue_free()
	for i: int in _quality_buttons.size():
		_quality_buttons[i].button_pressed = [ShipPart.Quality.SCRAP, ShipPart.Quality.USED, ShipPart.Quality.NEW, ShipPart.Quality.MYSTERY][i] == _quality
		Ui.mark_selected(_quality_buttons[i], _quality_buttons[i].button_pressed)
	if not _inventory.is_empty():
		Ui.legend(_catalog, "Inventario (gratis)")
		for part: ShipPart in _inventory:
			_catalog_button(part.def, "%s  [%s]" % [part.def.display_name, part.quality_text()], part)
	var box := Ui.button(_catalog, "Caja misteriosa  %s" % Ui.money(BOX_COST), _buy_box)
	box.tooltip_text = "Una pieza al azar de calidad oculta. Puede ser legendaria. O basura."
	box.add_theme_color_override("font_color", Ui.MYSTERY)
	for group: Array in GROUPS:
		Ui.legend(_catalog, String(group[0]))
		for def: PartDef in Catalog.part_list():
			if (group[1] as Array).has(def.kind):
				var price := int(round(def.cost * ShipPart.PRICE[_quality]))
				_catalog_button(def, "%s  %s" % [def.display_name, Ui.money(price)], null)


func _catalog_button(def: PartDef, text: String, stock: ShipPart) -> void:
	var b := PartButton.new()
	b.phase = self
	b.def = def
	b.stock = stock
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.tooltip_text = "%s\n%s" % [def.description, stats_text(def)]
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func() -> void:
		Synth.play(&"click")
		add_part(def, Run.ship.parts.size(), stock))
	_catalog.add_child(b)


func _build_center(root: Control) -> void:
	_view = ShipView.new()
	_view.phase = self
	Ui.place(_view, Rect2(350, 10, 580, 700))
	root.add_child(_view)


func _build_right(root: Control) -> void:
	var panel := Ui.panel(root)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -340
	panel.offset_right = -10
	panel.offset_top = 10
	panel.offset_bottom = -10
	var col := Ui.vbox(panel, 6)
	Ui.plate(col, "Ingeniería")
	_contract_label = Ui.label(col, "", 13, Ui.IVORY)
	_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contract_label.custom_minimum_size = Vector2(300, 0)
	Ui.legend(col, "Presupuesto libre / total")
	_budget_label = Ui.label(col, "", Ui.SIZE_HEAD, Ui.IVORY)
	_budget_label.add_theme_font_override("font", Ui.mono())
	_dv = Gauge.new("Delta-v", Ui.INFO)
	col.add_child(_dv)
	_twr_label = Ui.label(col, "", 14)
	_stages_label = Ui.label(col, "", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	_req_box = Ui.vbox(col, 1)
	_risk_label = Ui.label(col, "", 14)
	var sep := HSeparator.new()
	col.add_child(sep)
	_part_box = Ui.vbox(col, 4)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_launch = Ui.primary(Ui.button(col, "Despegar", _on_launch))
	_launch.custom_minimum_size = Vector2(0, 48)
	_launch.add_theme_font_size_override("font_size", 22)
	Ui.button(col, "Volver al hangar", func() -> void:
		Run.ship.parts.clear()
		Router.go(&"hangar"))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and (event as InputEventKey).physical_keycode in [KEY_DELETE, KEY_BACKSPACE] and _selected >= 0:
		remove_part(_selected)


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


func add_part(def: PartDef, index: int, stock: ShipPart = null, mount: float = 0.5, side: int = 0) -> void:
	var part: ShipPart = stock
	if part == null:
		part = ShipPart.create(def, _quality, Run.rng)
		if _remaining() - part.price() - _premium(part.price()) < 0:
			Synth.play(&"deny")
			Events.toast.emit("Sin presupuesto para %s" % def.display_name, Ui.LAMP_WARNING)
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
	Events.toast.emit("La caja contenia: %s" % part.def.display_name, Ui.MYSTERY)
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
	Events.toast.emit("%s: %s, %d%%" % [part.def.display_name, part.health_text(), int(part.condition * 100.0)], color)
	_refresh()


func stats_text(def: PartDef) -> String:
	var bits: PackedStringArray = PackedStringArray(["Masa %.1f t" % def.mass])
	if def.thrust > 0.0: bits.append("Empuje %d kN  Isp %d s" % [int(def.thrust), int(def.isp)])
	if def.fuel > 0.0: bits.append("Propelente %.0f t" % def.fuel)
	if def.solar > 0.0: bits.append("Solar %.1f" % def.solar)
	if def.power > 0.0: bits.append("Energía %.1f" % def.power)
	if def.battery > 0.0: bits.append("Batería %.1f" % def.battery)
	if def.cooling > 0.0: bits.append("Enfriamiento %.1f" % def.cooling)
	if def.cold_resist > 0.0: bits.append("Aislamiento %d%%" % int(def.cold_resist * 100))
	if def.heat_resist > 0.0: bits.append("Resist. calor %d%%" % int(def.heat_resist * 100))
	if def.rad_resist > 0.0: bits.append("Blindaje %d%%" % int(def.rad_resist * 100))
	if def.ablative > 0.0: bits.append("Ablativo %.0f" % def.ablative)
	bits.append("Fragilidad x%.1f" % def.fragility)
	return "  ".join(bits)


func _refresh() -> void:
	var ship := Run.ship
	var target := Run.target()
	_view.fit()
	var hazards: PackedStringArray = PackedStringArray()
	for h: StringName in target.hazards:
		hazards.append(String(HAZARD_NAMES.get(h, h)))
	if Run.contract.hidden_hazard != &"":
		hazards.append("rumores sin confirmar")
	_contract_label.text = "%s\nPago %s, adelanto %s\nPeligros: %s" % [
		Run.contract.title, Ui.money(Run.contract.payout), Ui.money(Run.contract.advance),
		", ".join(hazards) if not hazards.is_empty() else "ninguno conocido"]
	var remaining := _remaining()
	_budget_label.text = "%s / %s" % [Ui.money(remaining), Ui.money(Profile.budget(Run.contract))]
	_budget_label.add_theme_color_override("font_color", Ui.IVORY if remaining >= 0 else Ui.LAMP_WARNING)
	var dv := ship.delta_v()
	var need := Run.contract.dv_estimate
	var top := maxf(need * 1.6, dv)
	_dv.set_value(dv / top, "%d de %d m/s" % [int(dv), int(need)], dv < need * 0.85)
	_dv.band = Vector2(need * 0.85 / top, need * 1.15 / top)
	var home := Catalog.home()
	var twr := ship.twr(home.surface_gravity)
	_twr_label.text = "TWR al despegar %.2f%s" % [twr, " (no despega)" if twr < 1.0 else ""]
	_twr_label.add_theme_color_override("font_color", Ui.LAMP_GO if twr >= 1.2 else (Ui.LAMP_CAUTION if twr >= 1.0 else Ui.LAMP_WARNING))
	var lines: PackedStringArray = PackedStringArray()
	var dvs := ship.stage_dvs()
	for i: int in dvs.size():
		lines.append("Etapa %d   %5d m/s   TWR %.2f" % [i + 1, int(dvs[i]), ship.stage_twr(i, home.surface_gravity)])
	lines.append("Masa %.1f t   Valor %s   Prima seguro %s" % [ship.mass(), Ui.money(ship.value()), Ui.money(_premium(ship.value()))])
	_stages_label.text = "\n".join(lines)
	for child: Node in _req_box.get_children():
		child.queue_free()
	Ui.legend(_req_box, "Entorno del destino (%s)" % target.display_name)
	for req: Array in Thermal.requirements(ship, target):
		var req_row := Ui.hbox(_req_box, 6)
		var lamp := Lamp.new("OK" if req[1] else "Falta", Lamp.GO if req[1] else Lamp.WARNING)
		lamp.custom_minimum_size.x = 64
		req_row.add_child(lamp)
		Ui.label(req_row, str(req[0]), Ui.SIZE_LEGEND, Ui.IVORY)
	var rel := Odds.ship_reliability(ship)
	_risk_label.text = "Fiabilidad estimada: %d a %d %%" % [int(rel.x * 100.0), int(rel.y * 100.0)]
	_risk_label.add_theme_color_override("font_color", Odds.risk_color((rel.x + rel.y) * 0.5))
	_refresh_part()
	_launch.disabled = not ship.has_kind(&"capsule") or ship.thrust() <= 0.0 or remaining < 0


func _refresh_part() -> void:
	for child: Node in _part_box.get_children():
		child.queue_free()
	if _selected < 0 or _selected >= Run.ship.parts.size():
		Ui.label(_part_box, "Selecciona una pieza para ver su estado.", Ui.SIZE_LEGEND, Ui.IVORY_DIM)
		return
	var part: ShipPart = Run.ship.parts[_selected]
	Ui.label(_part_box, part.def.display_name, 17, Ui.IVORY)
	var place := "pila / %s" % Run.ship.zone_of(part)
	if part.def.radial:
		var side := "ambos" if part.side == 0 else ("izq" if part.side < 0 else "der")
		place = "montaje %s  altura %d%%" % [side, int(part.mount * 100.0)]
	Ui.label(_part_box, "Calidad %s   %s   Estado %s   %s" % [part.quality_text(), part.health_text(true), part.condition_text(), place], Ui.SIZE_LEGEND)
	var stats := Ui.label(_part_box, stats_text(part.def), Ui.SIZE_LEGEND, Ui.IVORY_DIM)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(300, 0)
	var row := Ui.hbox(_part_box, 6)
	if not part.inspected:
		var cost := "gratis" if Run.free_inspections > 0 else Ui.money(INSPECT_COST)
		Ui.button(row, "Inspeccionar (%s)" % cost, _inspect)
	Ui.button(row, "Quitar", remove_part.bind(_selected))


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
