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


const TEXEL := 2.0
const OUTLINE := Color("0d1014")
const FIRE: Texture2D = preload("res://assets/fx/fire_sheet.png")


static func _snap(r: Rect2) -> Rect2:
	var p := (r.position / TEXEL).round() * TEXEL
	var e := (r.end / TEXEL).round() * TEXEL
	return Rect2(p, (e - p).max(Vector2(TEXEL, TEXEL)))


## Rect dentro de r en fracciones (0-1), ajustado a la rejilla.
static func _sub(r: Rect2, x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return _snap(Rect2(r.position + r.size * Vector2(x0, y0), r.size * Vector2(x1 - x0, y1 - y0)))


## Silueta de la pieza como bloques escalonados: sirve para el contorno y para el relleno.
static func _slabs(part: ShipPart, r: Rect2, flipped: bool) -> Array[Rect2]:
	match part.def.kind:
		&"engine":
			return [_sub(r, 0.22, 0.0, 0.78, 0.4), _sub(r, 0.26, 0.4, 0.74, 0.6), _sub(r, 0.14, 0.6, 0.86, 0.8), _sub(r, 0.0, 0.8, 1.0, 1.0)]
		&"capsule":
			return [_sub(r, 0.3, 0.0, 0.7, 0.3), _sub(r, 0.18, 0.3, 0.82, 0.65), _sub(r, 0.05, 0.65, 0.95, 1.0)]
		&"heatshield":
			return [_sub(r, 0.0, 0.0, 1.0, 0.6), _sub(r, 0.12, 0.6, 0.88, 1.0)]
		&"parachute":
			return [_sub(r, 0.25, 0.0, 0.75, 0.35), _sub(r, 0.08, 0.35, 0.92, 0.6), _sub(r, 0.0, 0.6, 1.0, 1.0)]
		&"legs":
			var out: Array[Rect2] = []
			for k: int in 4:
				var fx := k / 4.0 if not flipped else 0.75 - k / 4.0
				out.append(_sub(r, fx, k / 4.0, fx + 0.3, (k + 1) / 4.0))
			out.append(_snap(Rect2(r.position.x - 2.0, r.end.y - TEXEL, r.size.x + 4.0, TEXEL)))
			return out
		&"antenna":
			return [_sub(r, 0.4, 0.3, 0.6, 1.0), _sub(r, 0.0, 0.1, 1.0, 0.3), _sub(r, 0.3, 0.0, 0.7, 0.1)]
		&"escape":
			return [_sub(r, 0.35, 0.3, 0.65, 1.0), _sub(r, 0.2, 0.0, 0.8, 0.3)]
	return [_snap(r)]


static func _tone(part: ShipPart) -> Color:
	var c := part.def.color
	match part.health():
		ShipPart.Health.WORN:
			c = c.darkened(0.22)
		ShipPart.Health.FAULTY:
			c = c.lerp(Color(0.9, 0.32, 0.08), 0.5)
		ShipPart.Health.BROKEN:
			c = c.darkened(0.55)
	return c


## Pieza y su espejo (radiales a ambos lados): [rect, volteada].
static func _placements(part: ShipPart, r: Rect2) -> Array:
	var out: Array = [[r, part.side < 0]]
	if part.def.radial and part.side == 0:
		out.append([mirror(r), true])
	return out


static func draw(ci: CanvasItem, parts: Array, opts: Dictionary = {}) -> void:
	if ci.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rects := layout(parts)
	var selected: int = opts.get("selected", -1)
	var t: float = Time.get_ticks_msec() / 1000.0
	var flame: float = opts.get("flame", 0.0)
	var active: Array = opts.get("active", [])
	# Primera pasada: todas las siluetas crecidas un texel. Da un solo contorno sin lineas dobles entre piezas.
	for i: int in parts.size():
		for place: Array in _placements(parts[i], rects[i]):
			for slab: Rect2 in _slabs(parts[i], place[0], place[1]):
				ci.draw_rect(slab.grow(TEXEL), OUTLINE)
	for i: int in parts.size():
		var part: ShipPart = parts[i]
		if flame > 0.0 and part.def.kind == &"engine" and not part.broken and active.has(part):
			_draw_flame(ci, _snap(rects[i]), flame, t + i)
		for place: Array in _placements(part, rects[i]):
			_draw_part(ci, part, place[0], place[1], t)
			if i == selected:
				ci.draw_rect(_snap(place[0]).grow(TEXEL * 2.0), Ui.IVORY, false, TEXEL)
	var chute: int = opts.get("chute", 0)
	if chute > 0 and not rects.is_empty():
		_draw_chute(ci, bounds(parts).position.y, chute)


static func _draw_flame(ci: CanvasItem, r: Rect2, flame: float, t: float) -> void:
	var length := r.size.y * (1.2 + flame * 2.8) * (0.85 + 0.15 * sin(t * 40.0))
	var cx := r.get_center().x
	var steps := 5
	for k: int in steps:
		var f := float(k) / steps
		var w := r.size.x * 0.8 * (1.0 - f)
		ci.draw_rect(_snap(Rect2(cx - w * 0.5, r.end.y + length * f, w, length / steps)), Color(2.6, 1.3 - f * 0.5, 0.45, 0.9))
		if k < 3:
			var core := w * 0.45
			ci.draw_rect(_snap(Rect2(cx - core * 0.5, r.end.y + length * f * 0.6, core, length * 0.6 / steps)), Color(3.5, 3.2, 2.6, 0.95))


static func _draw_chute(ci: CanvasItem, top: float, chute: int) -> void:
	var span := 26.0 if chute == 1 else 90.0
	var lift := 60.0 if chute == 1 else 150.0
	var color := Color(1.0, 0.45, 0.2) if chute == 2 else Color(1.0, 0.85, 0.3)
	var rows := 5
	for k: int in rows:
		var w := span * 2.0 * sin(PI * 0.5 * (k + 1.0) / rows)
		var slab := _snap(Rect2(-w * 0.5, top - lift - span * 0.45 * (1.0 - float(k) / rows), w, span * 0.45 / rows))
		ci.draw_rect(slab.grow(TEXEL), OUTLINE)
	for k: int in rows:
		var w := span * 2.0 * sin(PI * 0.5 * (k + 1.0) / rows)
		ci.draw_rect(_snap(Rect2(-w * 0.5, top - lift - span * 0.45 * (1.0 - float(k) / rows), w, span * 0.45 / rows)), color if k % 2 == 0 else color.lightened(0.25))
	for k: int in 5:
		var x := -span + span * 2.0 * k / 4.0
		ci.draw_line(Vector2(x, top - lift), Vector2(0, top), Color(0.9, 0.9, 0.9, 0.7), 1.0)


## Bloque con luz fija arriba-izquierda: borde claro arriba e izquierda, oscuro abajo y derecha.
static func _block(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_rect(r, c)
	if r.size.x < TEXEL * 3.0 or r.size.y < TEXEL * 2.0:
		return
	ci.draw_rect(Rect2(r.position.x, r.end.y - TEXEL, r.size.x, TEXEL), c.darkened(0.3))
	ci.draw_rect(Rect2(r.end.x - TEXEL, r.position.y, TEXEL, r.size.y), c.darkened(0.3))
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x - TEXEL, TEXEL), c.lightened(0.25))
	ci.draw_rect(Rect2(r.position.x, r.position.y, TEXEL, r.size.y - TEXEL), c.lightened(0.25))


static func _draw_part(ci: CanvasItem, part: ShipPart, raw: Rect2, flipped: bool, t: float) -> void:
	var r := _snap(raw)
	var c := _tone(part)
	var dark := c.darkened(0.35)
	var kind: StringName = part.def.kind
	var slabs := _slabs(part, raw, flipped)
	for k: int in slabs.size():
		var shade := c
		if kind == &"engine" and k == 0:
			shade = dark
		elif kind == &"escape" and k == 1:
			shade = Color(0.9, 0.3, 0.2)
		elif kind == &"parachute" and k == 2:
			shade = dark
		elif kind == &"heatshield" and part.ablative <= 0.5:
			shade = c.darkened(0.5)
		elif kind == &"solar":
			shade = Color(0.12, 0.22, 0.55) if not part.broken else Color(0.1, 0.1, 0.15)
		elif kind == &"decoupler":
			shade = Color(0.15, 0.15, 0.17)
		_block(ci, slabs[k], shade)
	match kind:
		&"tank":
			ci.draw_rect(Rect2(r.position.x, r.position.y + TEXEL * 2.0, r.size.x, TEXEL), dark)
			ci.draw_rect(Rect2(r.position.x, r.end.y - TEXEL * 3.0, r.size.x, TEXEL), dark)
			var cap := maxf(part.def.fuel * part.boost, 0.001)
			var frac := clampf(part.fuel / cap, 0.0, 1.0)
			var slot := _snap(Rect2(r.position.x + 4.0, r.position.y + 8.0, 4.0, r.size.y - 16.0))
			ci.draw_rect(slot, OUTLINE)
			ci.draw_rect(_snap(Rect2(slot.position.x, slot.end.y - slot.size.y * frac, slot.size.x, slot.size.y * frac)), Color(1.6, 0.8, 0.2))
		&"capsule":
			ci.draw_rect(_sub(r, 0.38, 0.38, 0.62, 0.58), Color(0.4, 1.4, 1.8) if not part.broken else Color(0.2, 0.2, 0.2))
		&"decoupler":
			for k: int in int(r.size.x / (TEXEL * 4.0)):
				ci.draw_rect(Rect2(r.position.x + k * TEXEL * 4.0, r.position.y, TEXEL * 2.0, r.size.y), Color(1.0, 0.8, 0.1))
		&"radiator":
			for k: int in int(r.size.y / 6.0):
				ci.draw_rect(_snap(Rect2(r.position.x + TEXEL, r.position.y + k * 6.0 + 2.0, r.size.x - TEXEL * 2.0, TEXEL)), dark)
		&"solar":
			for k: int in range(1, int(r.size.y / 8.0)):
				ci.draw_rect(_snap(Rect2(r.position.x, r.position.y + k * 8.0, r.size.x, TEXEL)), Color(0.5, 0.7, 1.0, 0.7))
		&"rtg":
			for k: int in 3:
				ci.draw_rect(_snap(Rect2(r.position.x - TEXEL, r.position.y + 4.0 + k * 6.0, r.size.x + TEXEL * 2.0, TEXEL)), Color(0.42, 0.42, 0.47))
			ci.draw_rect(_sub(r, 0.35, 0.42, 0.65, 0.58), Color(2.0, 0.4, 0.2, 0.6 + 0.4 * sin(t * 3.0)))
		&"battery":
			ci.draw_rect(_sub(r, 0.35, 0.4, 0.65, 0.6), OUTLINE)
			ci.draw_rect(_sub(r, 0.45, 0.2, 0.55, 0.8), OUTLINE)
		&"computer":
			for k: int in 3:
				var lit := not part.broken and int(t * 4.0 + k) % 3 != 0
				ci.draw_rect(_snap(Rect2(r.position.x + 6.0 + k * 6.0, r.get_center().y - TEXEL * 0.5, TEXEL, TEXEL)), Color(0.3, 2.0, 0.6) if lit else Color(0.1, 0.2, 0.1))
		&"sensor":
			ci.draw_rect(_sub(r, 0.25, 0.3, 0.75, 0.7), Color(0.6, 1.2, 1.8) if not part.broken else Color(0.1, 0.1, 0.1))
		&"shielding", &"insulation":
			for k: int in range(1, int(r.size.x / 8.0)):
				ci.draw_rect(_snap(Rect2(r.position.x + k * 8.0, r.position.y + TEXEL, TEXEL, r.size.y - TEXEL * 2.0)), c.darkened(0.25))
		&"rcs":
			ci.draw_rect(_snap(Rect2(r.position.x - TEXEL, r.position.y, TEXEL, TEXEL * 2.0)), dark)
			ci.draw_rect(_snap(Rect2(r.end.x, r.end.y - TEXEL * 2.0, TEXEL, TEXEL * 2.0)), dark)
	if part.revealed and part.hidden_quality == ShipPart.Quality.SCRAP:
		ci.draw_rect(_sub(r, 0.55, 0.2, 0.8, 0.38), Color(0.5, 0.25, 0.1, 0.6))
		ci.draw_rect(_sub(r, 0.15, 0.62, 0.35, 0.77), Color(0.5, 0.25, 0.1, 0.55))
	if part.revealed and part.hidden_quality == ShipPart.Quality.LEGENDARY:
		ci.draw_rect(r.grow(TEXEL), Color(1.6, 1.3, 0.4, 0.5 + 0.3 * sin(t * 4.0)), false, TEXEL)
	if not part.revealed:
		ci.draw_rect(r, Color(Ui.MYSTERY, 0.3 + 0.15 * sin(t * 5.0)))
		ci.draw_string(Ui.bold(), r.get_center() + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.IVORY)
	var h := part.health()
	if h == ShipPart.Health.WORN:
		ci.draw_rect(_sub(r, 0.15, 0.35, 0.45, 0.35), Color(0.12, 0.08, 0.05, 0.8))
		ci.draw_rect(_sub(r, 0.45, 0.42, 0.8, 0.42), Color(0.12, 0.08, 0.05, 0.8))
	elif h == ShipPart.Health.FAULTY:
		var frame := int(t * 8.0) % 4
		ci.draw_texture_rect_region(FIRE, Rect2(r.get_center().x - 8.0, r.position.y - 10.0, 16.0, 16.0), Rect2(frame * 24.0, 0, 24, 24))
	if part.broken:
		var n := int(minf(r.size.x, r.size.y) / TEXEL)
		for k: int in n:
			var f := (k + 0.5) / n
			ci.draw_rect(_snap(Rect2(r.position + r.size * Vector2(f, f) - Vector2(1, 1), Vector2(TEXEL, TEXEL))), Ui.LAMP_WARNING)
			ci.draw_rect(_snap(Rect2(r.position + r.size * Vector2(1.0 - f, f) - Vector2(1, 1), Vector2(TEXEL, TEXEL))), Ui.LAMP_WARNING)
