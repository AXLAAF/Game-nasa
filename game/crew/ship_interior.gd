class_name ShipInterior
extends CanvasLayer

## El tripulante camina sobre la nave diseñada: dentro de la cabina y, al salir, pegado al casco.

const EXTERIOR: Array[StringName] = [&"solar", &"radiator", &"antenna", &"sensor", &"rtg", &"heatshield", &"parachute", &"legs", &"rcs", &"escape"]
const PANEL_W := 280.0
const HATCH_REACH := 28.0
const HULL_OUT := 14.0
const REPAIR_REACH := 40.0
const MAP_SCRIPT := preload("res://game/crew/room_map.gd")
const CREW_SCRIPT := preload("res://game/crew/crew_body.gd")

var busy: bool = false
var on_hull: bool = false
var _panel: Control
var _rooms: Node2D
var _map: Node2D
var _crew: CharacterBody2D
var _title: Label
var _hint: Label
var _walls: Array[Node] = []


static func spawn(host: Node) -> void:
	if Run.crew < 2 or Run.ship.parts.is_empty():
		return
	var interior: Node = (load("res://game/crew/ship_interior.gd") as GDScript).new()
	host.add_child(interior)


static func panel_width() -> float:
	return PANEL_W if Run.crew >= 2 else 0.0


## Desplaza la cámara para que el marcador quede en el centro del vuelo que el panel no tapa.
static func view_shift(zoom: float) -> Vector2:
	var w := panel_width()
	if w <= 0.0:
		return Vector2.ZERO
	return Vector2(w * 0.5 / maxf(zoom, 0.001), 0.0)


static func is_exterior(kind: StringName) -> bool:
	return kind in EXTERIOR


static func can_repair(kind: StringName, in_airlock: bool, at_part: bool, hull: bool = false) -> bool:
	if is_exterior(kind):
		return hull or in_airlock
	return at_part and not hull


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -PANEL_W
	_panel.offset_top = 64.0
	_panel.offset_bottom = -64.0
	_panel.clip_contents = true
	add_child(_panel)
	_shift_lamps()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg)
	_title = Label.new()
	_title.add_theme_font_override("font", Ui.legend_font())
	_title.add_theme_font_size_override("font_size", Ui.SIZE_LEGEND)
	_title.add_theme_color_override("font_color", Ui.IVORY)
	_title.position = Vector2(12, 6)
	_panel.add_child(_title)
	_hint = Label.new()
	_hint.add_theme_font_override("font", Ui.legend_font())
	_hint.add_theme_font_size_override("font_size", Ui.SIZE_LEGEND)
	_hint.add_theme_color_override("font_color", Ui.INFO)
	_hint.position = Vector2(12, 24)
	_hint.size = Vector2(PANEL_W - 24.0, 36)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_hint)
	_rooms = Node2D.new()
	_panel.add_child(_rooms)
	_rebuild(false)
	Kinetic.enter_deferred(_panel, 0.02, {"slide": true, "slide_offset": Vector2(34.0, -8.0), "scale": Vector2(0.95, 0.94), "tilt": -0.02, "beam": true, "beam_color": Color(0.45, 0.92, 1.0, 0.24), "duration": 0.30})


func _process(_delta: float) -> void:
	_fit()
	_refresh_hint()
	if _map != null:
		_map.queue_redraw()
	if _crew != null:
		_crew.queue_redraw()


func interact(at: Vector2) -> void:
	if busy:
		return
	if on_hull:
		_interact_hull(at)
	else:
		_interact_inside(at)


func stick_to_hull(at: Vector2) -> Vector2:
	var box := ShipRenderer.bounds(Run.ship.parts)
	var x := clampf(at.x, box.position.x, box.end.x)
	var y := clampf(at.y, box.position.y, box.end.y)
	var dl := at.x - box.position.x
	var dr := box.end.x - at.x
	var dt := at.y - box.position.y
	var db := box.end.y - at.y
	if box.has_point(at) or (is_equal_approx(x, at.x) and is_equal_approx(y, at.y)):
		var m := minf(minf(dl, dr), minf(dt, db))
		if is_equal_approx(m, dl):
			x = box.position.x
		elif is_equal_approx(m, dr):
			x = box.end.x
		elif is_equal_approx(m, dt):
			y = box.position.y
		else:
			y = box.end.y
	var edge := Vector2(x, y)
	return edge + _outward_normal(edge, box) * HULL_OUT


## Avanza por el perímetro. En la esquina sigue de largo: la otra cara deja de quedar aislada.
func slide_hull(from: Vector2, delta: Vector2) -> Vector2:
	var box := ShipRenderer.bounds(Run.ship.parts)
	if _hull_span(box) < 1.0:
		return from
	var t := _hull_t(box, from)
	return _hull_point(box, t + delta.dot(_hull_tangent(t, box)))


func _outward_normal(edge: Vector2, box: Rect2) -> Vector2:
	var dl := absf(edge.x - box.position.x)
	var dr := absf(edge.x - box.end.x)
	var dt := absf(edge.y - box.position.y)
	var db := absf(edge.y - box.end.y)
	var nearest := minf(minf(dl, dr), minf(dt, db))
	if is_equal_approx(nearest, dl):
		return Vector2.LEFT
	if is_equal_approx(nearest, dr):
		return Vector2.RIGHT
	if is_equal_approx(nearest, dt):
		return Vector2.UP
	return Vector2.DOWN


func _hull_span(box: Rect2) -> float:
	return 2.0 * (box.size.x + box.size.y)


func _hull_tangent(t: float, box: Rect2) -> Vector2:
	var w := box.size.x
	var h := box.size.y
	var p := fposmod(t, _hull_span(box))
	if p < w:
		return Vector2.RIGHT
	if p < w + h:
		return Vector2.DOWN
	if p < w + h + w:
		return Vector2.LEFT
	return Vector2.UP


func _hull_edge(box: Rect2, t: float) -> Vector2:
	var w := box.size.x
	var h := box.size.y
	var p := fposmod(t, _hull_span(box))
	if p < w:
		return Vector2(box.position.x + p, box.position.y)
	p -= w
	if p < h:
		return Vector2(box.end.x, box.position.y + p)
	p -= h
	if p < w:
		return Vector2(box.end.x - p, box.end.y)
	p -= w
	return Vector2(box.position.x, box.end.y - p)


func _hull_point(box: Rect2, t: float) -> Vector2:
	var tangent := _hull_tangent(t, box)
	return _hull_edge(box, t) + Vector2(tangent.y, -tangent.x) * HULL_OUT


func _hull_t(box: Rect2, at: Vector2) -> float:
	var w := box.size.x
	var h := box.size.y
	var dl := at.x - box.position.x
	var dr := box.end.x - at.x
	var dt := at.y - box.position.y
	var db := box.end.y - at.y
	var x := clampf(at.x, box.position.x, box.end.x)
	var y := clampf(at.y, box.position.y, box.end.y)
	var side := 3
	if dl < 0.0 or dr < 0.0 or dt < 0.0 or db < 0.0:
		var best := 0.0
		var chosen := false
		if dl < 0.0:
			best = dl
			side = 3
			chosen = true
		if dr < 0.0 and (not chosen or dr < best):
			best = dr
			side = 1
			chosen = true
		if dt < 0.0 and (not chosen or dt < best):
			best = dt
			side = 0
			chosen = true
		if db < 0.0 and (not chosen or db < best):
			best = db
			side = 2
	else:
		var m := minf(minf(dl, dr), minf(dt, db))
		if is_equal_approx(m, dt):
			side = 0
		elif is_equal_approx(m, dr):
			side = 1
		elif is_equal_approx(m, db):
			side = 2
	match side:
		0:
			return x - box.position.x
		1:
			return w + (y - box.position.y)
		2:
			return w + h + (box.end.x - x)
		_:
			return w + h + w + (box.end.y - y)


## Las lamparas de la nave viven en la misma esquina. Se corren para no tapar el corte.
func _shift_lamps() -> void:
	var board := Annunciator.current
	if board == null or not is_instance_valid(board):
		return
	board.offset_right = -(PANEL_W + 20.0)
	board.offset_left = board.offset_right


## Punto del casco donde aparece el tripulante al salir. Enter aquí vuelve a entrar.
func hatch_point() -> Vector2:
	return stick_to_hull(_center(_airlock()))


func _near_hatch(at: Vector2) -> bool:
	return at.distance_to(hatch_point()) <= HATCH_REACH


func _interact_inside(at: Vector2) -> void:
	var index := _index_at(at)
	if index == _airlock():
		var hatch_part: ShipPart = Run.ship.parts[index]
		if _serviceable(hatch_part) and can_repair(hatch_part.def.kind, false, true, false):
			_begin(hatch_part)
			return
		_rebuild(true)
		Events.toast.emit("Saliste al casco", Ui.INFO)
		return
	if index < 0 and _hatch_rect().grow(6.0).has_point(at):
		_rebuild(true)
		Events.toast.emit("Saliste al casco", Ui.INFO)
		return
	if index < 0:
		return
	var part: ShipPart = Run.ship.parts[index]
	if _serviceable(part) and (can_repair(part.def.kind, false, true, false) or is_exterior(part.def.kind)):
		_begin(part)


func _interact_hull(at: Vector2) -> void:
	var part := _exterior_at(at)
	var repair := part != null and _serviceable(part)
	if repair and _near_hatch(at) and _station_distance(at, part) > at.distance_to(hatch_point()):
		repair = false
	if repair:
		_begin(part)
		return
	if _near_hatch(at):
		_rebuild(false)
		Events.toast.emit("Volviste a la cabina", Ui.INFO)
		return
	if part != null:
		Events.toast.emit("%s en orden" % part.def.display_name, Ui.IVORY_DIM)


func _station_distance(at: Vector2, part: ShipPart) -> float:
	var best := INF
	for row: Dictionary in _exterior_stations():
		if row.part != part:
			continue
		var rect: Rect2 = row.rect
		var closest := Vector2(clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y))
		best = minf(best, at.distance_to(closest))
	return best


func _begin(part: ShipPart) -> void:
	busy = true
	Minigame.start(Minigame.for_part(part.def.kind), _finished.bind(part), true)


func _serviceable(part: ShipPart) -> bool:
	return part.broken or part.health() == ShipPart.Health.FAULTY


func _finished(success: bool, part: ShipPart) -> void:
	busy = false
	if not is_instance_valid(self):
		return
	if not success:
		part.wear = minf(part.wear + 0.2, 1.0)
		Events.toast.emit("La reparación falló", Ui.LAMP_WARNING)
		return
	var was_broken := part.broken
	if was_broken and Run.kits > 0:
		Run.kits -= 1
		Run.apply({"fix": true}, part)
		Events.toast.emit("%s reparada" % part.def.display_name, Ui.LAMP_GO)
	elif was_broken:
		Run.apply({"fix": true, "wear": 0.15}, part)
		Events.toast.emit("Improvisada, sin kits", Ui.LAMP_CAUTION)
	else:
		Events.toast.emit("%s revisada" % part.def.display_name, Ui.LAMP_GO)
	_settle(part)
	Card.release_fault(part, true)


## Una reparación lograda deja la pieza al menos gastada. Si no, el aro naranja vuelve al instante.
func _settle(part: ShipPart) -> void:
	var life := part.condition * (1.0 - part.wear)
	if life >= 0.55:
		return
	var room := maxf(1.0 - part.wear, 0.2)
	part.condition = maxf(part.condition, 0.55 / room)


func paint_map(canvas: Node2D) -> void:
	if Run.ship.parts.is_empty():
		return
	ShipRenderer.draw(canvas, Run.ship.parts)
	var pulse := 0.45 + 0.55 * sin(Time.get_ticks_msec() / 140.0)
	var rects := ShipRenderer.layout(Run.ship.parts)
	var urgent := Card.open_faults()
	for i: int in Run.ship.parts.size():
		var part: ShipPart = Run.ship.parts[i]
		var marked := part in urgent
		if part.health() < ShipPart.Health.FAULTY and not marked:
			continue
		_paint_damage(canvas, part, rects[i], pulse, marked)
		if part.def.radial and part.side == 0:
			_paint_damage(canvas, part, ShipRenderer.mirror(rects[i]), pulse, marked)
		if marked and _crew != null:
			var target := rects[i].get_center()
			if part.def.radial and part.side == 0:
				var other := ShipRenderer.mirror(rects[i]).get_center()
				if _crew.position.distance_to(other) < _crew.position.distance_to(target):
					target = other
			canvas.draw_line(_crew.position, target, Ui.LAMP_WARNING, 2.0)
	var hatch := _hatch_rect()
	canvas.draw_rect(hatch, Color(0.45, 1.3, 1.5, 0.9), false, 2.0)
	if on_hull:
		var door := hatch_point()
		canvas.draw_arc(door, 12.0, 0.0, TAU, 20, Color(0.45, 1.3, 1.5, 0.95), 2.5)
		canvas.draw_rect(ShipRenderer.bounds(Run.ship.parts), Color(0.55, 0.85, 1.0, 0.45), false, 1.5)


func _paint_damage(canvas: Node2D, part: ShipPart, rect: Rect2, pulse: float, urgent: bool) -> void:
	var color := Ui.LAMP_WARNING if part.broken or urgent else Ui.LAMP_CAUTION
	var c := rect.get_center()
	var radius := maxf(minf(rect.size.x, rect.size.y) * 0.55, 8.0)
	if urgent:
		radius *= 1.35
	canvas.draw_circle(c, radius * (0.85 + pulse * 0.35), Color(color, 0.28 + pulse * 0.25))
	canvas.draw_arc(c, radius, 0.0, TAU, 20, color, 2.0 if not urgent else 3.0)
	var note := "Aquí" if urgent else ("Roto" if part.broken else "Falla")
	canvas.draw_string(Ui.sans(), c + Vector2(-18, -radius - 2.0), note, HORIZONTAL_ALIGNMENT_LEFT, 48, 12, color)


func _rebuild(hull: bool) -> void:
	on_hull = hull
	for wall: Node in _walls:
		if is_instance_valid(wall):
			wall.queue_free()
	_walls.clear()
	for child: Node in _rooms.get_children():
		child.queue_free()
	_map = MAP_SCRIPT.new()
	_map.set("host", self)
	_rooms.add_child(_map)
	_crew = CREW_SCRIPT.new()
	_crew.set("host", self)
	_crew.collision_layer = 2
	_crew.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	_crew.add_child(shape)
	var hatch := _center(_airlock())
	if on_hull:
		_title.text = "Casco"
		_crew.position = stick_to_hull(hatch)
	else:
		_title.text = "Cabina"
		_crew.position = hatch
		_wall_frame(_stack_bounds())
	_refresh_hint()
	_rooms.add_child(_crew)
	_fit()
	if is_node_ready():
		Kinetic.pop(_panel, Vector2(1.03, 0.97), 0.22)
		Kinetic.sweep(_panel, Color(0.45, 0.95, 1.0, 0.26), 0.28)


func _refresh_hint() -> void:
	if _hint == null:
		return
	var outside := false
	var inside := false
	for part: ShipPart in Card.open_faults():
		if is_exterior(part.def.kind):
			outside = true
		else:
			inside = true
	if on_hull:
		if inside:
			_hint.text = "Falla en cabina. Enter en el anillo cian para entrar."
		elif _has_fault(true):
			_hint.text = "Rodea el casco hasta el aro y pulsa Enter."
		else:
			_hint.text = "Enter en el anillo cian para volver a la cabina."
	elif outside:
		_hint.text = "Enter sobre el aro naranja. Si no llegas, sal por el marco cian."
	else:
		var hatch := _airlock()
		if hatch >= 0 and hatch < Run.ship.parts.size() and Run.ship.parts[hatch].broken:
			_hint.text = "Cápsula rota: Enter sobre ella repara. El marco cian es la salida."
		elif _has_fault(false):
			_hint.text = "Falla naranja: Enter sobre el aro para repararla."
		else:
			_hint.text = "Enter en la cápsula (marco cian) para salir al casco."


func _fit() -> void:
	if _rooms == null or _panel == null or Run.ship.parts.is_empty():
		return
	var box := ShipRenderer.bounds(Run.ship.parts).grow(18.0)
	var avail := _panel.size - Vector2(16.0, 78.0)
	if avail.x < 40.0 or avail.y < 40.0:
		avail = Vector2(PANEL_W - 16.0, 420.0)
	var fit := minf(avail.x / maxf(box.size.x, 1.0), avail.y / maxf(box.size.y, 1.0)) * 0.92
	_rooms.scale = Vector2(fit, fit)
	var area_center := Vector2(8.0, 66.0) + avail * 0.5
	_rooms.position = area_center - box.get_center() * fit


func _wall_frame(box: Rect2) -> void:
	var t := 5.0
	_wall(Rect2(box.position.x - t, box.position.y - t, box.size.x + t * 2.0, t))
	_wall(Rect2(box.position.x - t, box.end.y, box.size.x + t * 2.0, t))
	_wall(Rect2(box.position.x - t, box.position.y, t, box.size.y))
	_wall(Rect2(box.end.x, box.position.y, t, box.size.y))


func _wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size.max(Vector2(1, 1))
	col.shape = shape
	body.add_child(col)
	_rooms.add_child(body)
	_walls.append(body)


func _stack_bounds() -> Rect2:
	var rects := ShipRenderer.layout(Run.ship.parts)
	var box := Rect2()
	var any := false
	for i: int in Run.ship.parts.size():
		if Run.ship.parts[i].def.radial:
			continue
		var r: Rect2 = rects[i]
		box = r if not any else box.merge(r)
		any = true
	if not any:
		return ShipRenderer.bounds(Run.ship.parts).grow(6.0)
	return box.grow(6.0)


func _center(index: int) -> Vector2:
	var rects := ShipRenderer.layout(Run.ship.parts)
	if index < 0 or index >= rects.size():
		return Vector2.ZERO
	return rects[index].get_center()


func _has_fault(hull: bool) -> bool:
	for part: ShipPart in Run.ship.parts:
		if part.health() != ShipPart.Health.FAULTY:
			continue
		if is_exterior(part.def.kind) == hull:
			return true
	return false


func _index_at(at: Vector2) -> int:
	var hit := ShipRenderer.pick(Run.ship.parts, at)
	if hit >= 0:
		return hit
	var rects := ShipRenderer.layout(Run.ship.parts)
	var best := -1
	var best_d := 22.0
	for i: int in Run.ship.parts.size():
		if not _serviceable(Run.ship.parts[i]):
			continue
		var rect := rects[i]
		var reach := maxf(minf(rect.size.x, rect.size.y) * 0.7, 12.0)
		var d := at.distance_to(rect.get_center())
		if d <= reach and d < best_d:
			best = i
			best_d = d
	return best


func _airlock() -> int:
	var parts := Run.ship.parts
	for i: int in parts.size():
		if parts[i].def.kind == &"capsule":
			return i
	return parts.size() - 1


func _hatch_rect() -> Rect2:
	var rects := ShipRenderer.layout(Run.ship.parts)
	var hatch := _airlock()
	if hatch < 0 or hatch >= rects.size():
		return Rect2()
	return rects[hatch]


func _exterior_stations() -> Array:
	var rects := ShipRenderer.layout(Run.ship.parts)
	var out: Array = []
	for i: int in Run.ship.parts.size():
		var part: ShipPart = Run.ship.parts[i]
		if is_exterior(part.def.kind):
			out.append({"part": part, "rect": rects[i]})
			if part.def.radial and part.side == 0:
				out.append({"part": part, "rect": ShipRenderer.mirror(rects[i])})
	return out


func _exterior_at(at: Vector2) -> ShipPart:
	var best: ShipPart = null
	var best_d := REPAIR_REACH
	for row: Dictionary in _exterior_stations():
		var rect: Rect2 = row.rect
		var closest := Vector2(clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y))
		var d := at.distance_to(closest)
		if d < best_d:
			best_d = d
			best = row.part
	return best
