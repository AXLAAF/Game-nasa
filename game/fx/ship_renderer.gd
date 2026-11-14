class_name ShipRenderer
extends RefCounted

## Dibuja la pila con poligonos. Origen = centro de la base, y negativo hacia arriba.
## Las piezas radiales se anclan a un bloque de la pila (altura mount, lado side).


## Indice del bloque de pila al que se ancla la pieza i (ella misma si no es radial).
static func host_index(parts: Array, index: int) -> int:
	for i: int in range(index, -1, -1):
		if not parts[i].def.radial:
			return i
	return -1


static func layout(parts: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var hosts: Array[Rect2] = []
	var y := 0.0
	for part: ShipPart in parts:
		if part.def.radial:
			rects.append(Rect2())
			hosts.append(Rect2())
			continue
		var s: Vector2 = part.def.size
		y -= s.y
		var host := Rect2(-s.x * 0.5, y, s.x, s.y)
		rects.append(host)
		hosts.append(host)
	for i: int in parts.size():
		var part: ShipPart = parts[i]
		if not part.def.radial:
			continue
		var hi := host_index(parts, i)
		var host: Rect2 = hosts[hi] if hi >= 0 else Rect2(-20, -20, 40, 20)
		var s: Vector2 = part.def.size
		var mount := clampf(part.mount, 0.0, 1.0)
		var ry := host.end.y - s.y - (host.size.y - s.y) * mount
		if part.def.kind == &"legs":
			ry = host.end.y - s.y * 0.6
		var gap := 1.0
		var x := host.end.x + gap
		if part.side < 0:
			x = host.position.x - gap - s.x
		rects[i] = Rect2(x, ry, s.x, s.y)
	return rects


static func mirror(r: Rect2) -> Rect2:
	return Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)


static func bounds(parts: Array) -> Rect2:
	var rects := layout(parts)
	if rects.is_empty():
		return Rect2(-10, -10, 20, 10)
	var total := rects[0]
	for i: int in rects.size():
		total = total.merge(rects[i])
		if parts[i].def.radial and parts[i].side == 0:
			total = total.merge(mirror(rects[i]))
	return total


## Indice de pieza bajo un punto local (o -1).
static func pick(parts: Array, local: Vector2) -> int:
	var rects := layout(parts)
	for i: int in range(rects.size() - 1, -1, -1):
		if rects[i].grow(2).has_point(local):
			return i
		if parts[i].def.radial and parts[i].side == 0 and mirror(rects[i]).grow(2).has_point(local):
			return i
	return -1


## Bloque de pila bajo un punto local (o -1).
static func pick_host(parts: Array, local: Vector2) -> int:
	var rects := layout(parts)
	var best := -1
	var best_d := INF
	for i: int in parts.size():
		if parts[i].def.radial:
			continue
		var r: Rect2 = rects[i]
		var band := Rect2(r.position.x - 80.0, r.position.y, r.size.x + 160.0, r.size.y)
		if band.has_point(local):
			return i
		var d := absf(local.y - r.get_center().y)
		if d < best_d:
			best_d = d
			best = i
	return best


## Rectangulo de montaje previsto (lado derecho si side >= 0).
static func mount_rect(host: Rect2, part_size: Vector2, mount: float, side: int, kind: StringName) -> Rect2:
	var ry := host.end.y - part_size.y - (host.size.y - part_size.y) * clampf(mount, 0.0, 1.0)
	if kind == &"legs":
		ry = host.end.y - part_size.y * 0.6
	var x := host.end.x + 1.0 if side >= 0 else host.position.x - 1.0 - part_size.x
	return Rect2(x, ry, part_size.x, part_size.y)


## Toberas de los motores de la etapa activa (coordenadas locales).
static func nozzles(parts: Array, active: Array) -> PackedVector2Array:
	var rects := layout(parts)
	var out := PackedVector2Array()
	for i: int in parts.size():
		var part: ShipPart = parts[i]
		if part.def.kind == &"engine" and active.has(part) and not part.broken:
			out.append(Vector2(rects[i].get_center().x, rects[i].end.y))
	return out


static func draw(ci: CanvasItem, parts: Array, opts: Dictionary = {}) -> void:
	var rects := layout(parts)
	var selected: int = opts.get("selected", -1)
	var t: float = Time.get_ticks_msec() / 1000.0
	var flame: float = opts.get("flame", 0.0)
	var active: Array = opts.get("active", [])
	for i: int in parts.size():
		var part: ShipPart = parts[i]
		_draw_part(ci, part, rects[i], part.side < 0, t)
		if part.def.radial and part.side == 0:
			_draw_part(ci, part, mirror(rects[i]), true, t)
		if flame > 0.0 and part.def.kind == &"engine" and not part.broken and active.has(part):
			var r := rects[i]
			var flame_len := r.size.y * (1.2 + flame * 2.8) * (0.85 + 0.15 * sin(t * 40.0 + i))
			var c := r.get_center().x
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(c - r.size.x * 0.42, r.end.y), Vector2(c + r.size.x * 0.42, r.end.y), Vector2(c, r.end.y + flame_len),
			]), Color(2.6, 1.3, 0.45, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(c - r.size.x * 0.2, r.end.y), Vector2(c + r.size.x * 0.2, r.end.y), Vector2(c, r.end.y + flame_len * 0.55),
			]), Color(3.5, 3.2, 2.6, 0.95))
		if i == selected:
			ci.draw_rect(rects[i].grow(3), Ui.IVORY, false, 2.0)
			if part.def.radial and part.side == 0:
				ci.draw_rect(mirror(rects[i]).grow(3), Ui.IVORY, false, 2.0)
	var chute: int = opts.get("chute", 0)
	if chute > 0 and not rects.is_empty():
		var top := bounds(parts).position.y
		var span := 26.0 if chute == 1 else 90.0
		var lift := 60.0 if chute == 1 else 150.0
		var canopy := PackedVector2Array()
		for k: int in 13:
			var a := PI + PI * k / 12.0
			canopy.append(Vector2(cos(a) * span, top - lift + sin(a) * span * 0.45))
		canopy.append(Vector2(span, top - lift))
		ci.draw_colored_polygon(canopy, Color(1.0, 0.45, 0.2) if chute == 2 else Color(1.0, 0.85, 0.3))
		for k: int in 5:
			var x := -span + span * 2.0 * k / 4.0
			ci.draw_line(Vector2(x, top - lift), Vector2(0, top), Color(0.9, 0.9, 0.9, 0.7), 1.0)


static func _draw_part(ci: CanvasItem, part: ShipPart, r: Rect2, flipped: bool, t: float) -> void:
	var c := part.def.color
	var h := part.health()
	if h == ShipPart.Health.WORN:
		c = c.darkened(0.22)
	elif h == ShipPart.Health.FAULTY:
		c = c.lerp(Color(0.9, 0.32, 0.08), 0.5)
	elif h == ShipPart.Health.BROKEN:
		c = c.darkened(0.55)
	var dark := c.darkened(0.35)
	var cx := r.get_center().x
	var outline := Color(0, 0, 0, 0.55)
	match part.def.kind:
		&"engine":
			ci.draw_rect(Rect2(cx - r.size.x * 0.3, r.position.y, r.size.x * 0.6, r.size.y * 0.4), dark)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(cx - r.size.x * 0.22, r.position.y + r.size.y * 0.4), Vector2(cx + r.size.x * 0.22, r.position.y + r.size.y * 0.4),
				Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y),
			]), c)
			ci.draw_line(Vector2(r.position.x + 2, r.end.y - 1), Vector2(r.end.x - 2, r.end.y - 1), c.lightened(0.4), 2.0)
		&"tank":
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), dark)
			ci.draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), dark)
			var cap := maxf(part.def.fuel * part.boost, 0.001)
			var frac := clampf(part.fuel / cap, 0.0, 1.0)
			var gauge := Rect2(r.position.x + 4, r.position.y + 7, 4, r.size.y - 14)
			ci.draw_rect(gauge, Color(0, 0, 0, 0.5))
			ci.draw_rect(Rect2(gauge.position.x, gauge.end.y - gauge.size.y * frac, 4, gauge.size.y * frac), Color(1.6, 0.8, 0.2))
			ci.draw_line(Vector2(cx + 6, r.position.y + 6), Vector2(cx + 6, r.end.y - 6), c.lightened(0.25), 2.0)
		&"capsule":
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(r.position.x + r.size.x * 0.05, r.end.y), Vector2(r.end.x - r.size.x * 0.05, r.end.y),
				Vector2(cx + r.size.x * 0.2, r.position.y), Vector2(cx - r.size.x * 0.2, r.position.y),
			]), c)
			ci.draw_circle(Vector2(cx, r.position.y + r.size.y * 0.5), r.size.x * 0.12, Color(0.4, 1.4, 1.8) if not part.broken else Color(0.2, 0.2, 0.2))
		&"decoupler":
			ci.draw_rect(r, Color(0.15, 0.15, 0.17))
			var stripes := int(r.size.x / 8.0)
			for k: int in stripes:
				var x0 := r.position.x + k * 8.0
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(x0, r.end.y), Vector2(x0 + 4, r.position.y), Vector2(x0 + 8, r.position.y), Vector2(x0 + 4, r.end.y),
				]), Color(1.0, 0.8, 0.1))
		&"heatshield":
			ci.draw_colored_polygon(PackedVector2Array([
				r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - 3, r.end.y - 2),
				Vector2(cx, r.end.y + 3), Vector2(r.position.x + 3, r.end.y - 2),
			]), c if part.ablative > 0.5 else c.darkened(0.5))
		&"parachute":
			ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.4, r.size.x, r.size.y * 0.6), dark)
			ci.draw_circle(Vector2(cx, r.position.y + r.size.y * 0.45), r.size.x * 0.42, c)
		&"legs":
			var foot := Vector2(r.end.x if not flipped else r.position.x, r.end.y)
			var hip := Vector2(r.position.x if not flipped else r.end.x, r.position.y)
			ci.draw_line(hip, foot, c, 3.0)
			ci.draw_line(foot - Vector2(5, 0), foot + Vector2(5, 0), c.lightened(0.3), 3.0)
		&"radiator":
			ci.draw_rect(r, c)
			for k: int in int(r.size.y / 6.0):
				ci.draw_line(Vector2(r.position.x, r.position.y + k * 6.0 + 3), Vector2(r.end.x, r.position.y + k * 6.0 + 3), dark, 1.0)
		&"solar":
			ci.draw_rect(r, Color(0.1, 0.2, 0.55) if not part.broken else Color(0.1, 0.1, 0.15))
			for k: int in int(r.size.y / 8.0):
				ci.draw_line(Vector2(r.position.x, r.position.y + k * 8.0), Vector2(r.end.x, r.position.y + k * 8.0), Color(0.5, 0.7, 1.0, 0.6), 1.0)
			ci.draw_line(Vector2(cx, r.position.y), Vector2(cx, r.end.y), Color(0.5, 0.7, 1.0, 0.6), 1.0)
		&"rtg":
			ci.draw_rect(r, Color(0.25, 0.25, 0.28))
			for k: int in 3:
				ci.draw_line(Vector2(r.position.x - 2, r.position.y + 4 + k * 6), Vector2(r.end.x + 2, r.position.y + 4 + k * 6), Color(0.4, 0.4, 0.45), 2.0)
			ci.draw_circle(r.get_center(), 2.5, Color(2.0, 0.4, 0.2, 0.6 + 0.4 * sin(t * 3.0)))
		&"battery":
			ci.draw_rect(r, c)
			ci.draw_line(Vector2(cx - 4, r.get_center().y), Vector2(cx + 4, r.get_center().y), Color(0.1, 0.1, 0.1), 2.0)
			ci.draw_line(Vector2(cx, r.get_center().y - 3), Vector2(cx, r.get_center().y + 3), Color(0.1, 0.1, 0.1), 2.0)
		&"antenna":
			var base := Vector2(r.position.x if not flipped else r.end.x, r.end.y)
			var tip := Vector2(r.get_center().x, r.position.y + 4)
			ci.draw_line(base, tip, c, 2.0)
			ci.draw_arc(tip, r.size.x * 0.45, PI * 0.15 if not flipped else PI * 0.85, PI * 0.85 if not flipped else PI * 1.85, 8, c.lightened(0.3), 2.0)
		&"computer":
			ci.draw_rect(r, c)
			for k: int in 3:
				var lit := not part.broken and int(t * 4.0 + k) % 3 != 0
				ci.draw_circle(Vector2(r.position.x + 6 + k * 6, r.get_center().y), 1.6, Color(0.3, 2.0, 0.6) if lit else Color(0.1, 0.2, 0.1))
		&"sensor":
			ci.draw_rect(r, c)
			ci.draw_circle(Vector2(cx, r.get_center().y), minf(r.size.x, r.size.y) * 0.35, Color(0.6, 1.2, 1.8) if not part.broken else Color(0.1, 0.1, 0.1))
			var inward := r.position.x if not flipped else r.end.x
			ci.draw_line(Vector2(inward, r.get_center().y), Vector2(inward + (-4.0 if not flipped else 4.0), r.get_center().y), dark, 2.0)
		&"shielding", &"insulation":
			ci.draw_rect(r, c)
			for k: int in int(r.size.x / 6.0):
				ci.draw_line(Vector2(r.position.x + k * 6.0, r.position.y), Vector2(r.position.x + k * 6.0 + 4, r.end.y), c.darkened(0.25), 1.0)
		&"rcs":
			ci.draw_rect(r, c)
			ci.draw_line(Vector2(r.position.x, r.position.y + 2), Vector2(r.position.x - 3, r.position.y - 2), dark, 2.0)
			ci.draw_line(Vector2(r.end.x, r.end.y - 2), Vector2(r.end.x + 3, r.end.y + 2), dark, 2.0)
		&"escape":
			ci.draw_line(Vector2(cx - 3, r.end.y), Vector2(cx, r.position.y + 12), c, 1.5)
			ci.draw_line(Vector2(cx + 3, r.end.y), Vector2(cx, r.position.y + 12), c, 1.5)
			ci.draw_rect(Rect2(cx - 3, r.position.y, 6, 14), Color(0.9, 0.3, 0.2))
		_:
			ci.draw_rect(r, c)
	if part.def.kind in [&"tank", &"computer", &"sensor", &"battery", &"radiator", &"shielding", &"insulation", &"decoupler"]:
		ci.draw_rect(r, outline, false, 1.0)
	if part.revealed and part.hidden_quality == ShipPart.Quality.SCRAP:
		ci.draw_rect(Rect2(r.position + r.size * Vector2(0.55, 0.2), r.size * Vector2(0.25, 0.18)), Color(0.5, 0.25, 0.1, 0.55))
		ci.draw_rect(Rect2(r.position + r.size * Vector2(0.15, 0.62), r.size * Vector2(0.2, 0.15)), Color(0.5, 0.25, 0.1, 0.5))
	if part.revealed and part.hidden_quality == ShipPart.Quality.LEGENDARY:
		ci.draw_rect(r.grow(1), Color(1.6, 1.3, 0.4, 0.5 + 0.3 * sin(t * 4.0)), false, 1.5)
	if not part.revealed:
		ci.draw_rect(r, Color(0.7, 0.3, 1.0, 0.25 + 0.15 * sin(t * 5.0)))
		ci.draw_string(Ui.mono(), r.get_center() + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.6, 1.0, 2.0))
	if h == ShipPart.Health.WORN:
		ci.draw_line(r.position + r.size * Vector2(0.15, 0.35), r.position + r.size * Vector2(0.8, 0.42), Color(0.12, 0.08, 0.05, 0.8), 1.0)
	elif h == ShipPart.Health.FAULTY:
		ci.draw_circle(r.position + Vector2(3, 3), 2.4, Color(1.5, 0.35, 0.05, 0.4 + 0.6 * absf(sin(t * 9.0))))
	if part.broken:
		ci.draw_line(r.position, r.end, Color(1, 0.2, 0.15), 2.0)
		ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(1, 0.2, 0.15), 2.0)
		if int(t * 10.0 + r.position.y) % 7 == 0:
			ci.draw_circle(r.get_center() + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 2.0, Color(3, 2, 0.5))

