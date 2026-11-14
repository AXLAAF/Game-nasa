class_name Gravity
extends RefCounted

## N cuerpos "sobre rieles" (orbitas circulares) que atraen a la nave.
## La nave se integra con Euler semi-implicito y subpasos.

const MAX_STEP := 0.04


static func angular_speed(body: BodyDef) -> float:
	if body.is_star or body.parent_id == &"":
		return 0.0
	var parent := Catalog.body(body.parent_id)
	if parent == null or body.orbit_radius <= 0.0:
		return 0.0
	return sqrt(parent.mu / pow(body.orbit_radius, 3.0))


static func body_pos(body: BodyDef, t: float) -> Vector2:
	if body.is_star or body.parent_id == &"":
		return Vector2.ZERO
	var parent := Catalog.body(body.parent_id)
	var angle := body.orbit_phase + angular_speed(body) * t
	return body_pos(parent, t) + Vector2(cos(angle), sin(angle)) * body.orbit_radius


static func body_vel(body: BodyDef, t: float) -> Vector2:
	if body.is_star or body.parent_id == &"":
		return Vector2.ZERO
	var parent := Catalog.body(body.parent_id)
	var w := angular_speed(body)
	var angle := body.orbit_phase + w * t
	return body_vel(parent, t) + Vector2(-sin(angle), cos(angle)) * body.orbit_radius * w


static func accel(pos: Vector2, t: float, bodies: Array[BodyDef]) -> Vector2:
	var total := Vector2.ZERO
	for body: BodyDef in bodies:
		var d := body_pos(body, t) - pos
		var dist2 := maxf(d.length_squared(), body.radius * body.radius * 0.25)
		total += d * (body.mu / (dist2 * sqrt(dist2)))
	return total


## Avanza pos/vel. Devuelve el id del cuerpo con el que choca, o &"".
static func step(state: Dictionary, dt: float, bodies: Array[BodyDef], thrust_acc: Vector2, max_step: float = MAX_STEP) -> StringName:
	var steps := maxi(1, ceili(dt / max_step))
	var h := dt / steps
	var pos: Vector2 = state.pos
	var vel: Vector2 = state.vel
	var t: float = state.t
	var hit := &""
	for i: int in steps:
		vel += (accel(pos, t, bodies) + thrust_acc) * h
		pos += vel * h
		t += h
		hit = collision(pos, t, bodies)
		if hit != &"":
			break
	state.pos = pos
	state.vel = vel
	state.t = t
	return hit


static func collision(pos: Vector2, t: float, bodies: Array[BodyDef]) -> StringName:
	for body: BodyDef in bodies:
		if pos.distance_squared_to(body_pos(body, t)) < body.radius * body.radius:
			return body.id
	return &""


## Cuerpo dominante: el planeta/luna mas interno cuya esfera de Hill contiene la nave.
static func dominant(pos: Vector2, t: float, bodies: Array[BodyDef]) -> BodyDef:
	var best: BodyDef = null
	var best_hill := INF
	for body: BodyDef in bodies:
		if body.is_star:
			continue
		var hill := hill_radius(body)
		if pos.distance_to(body_pos(body, t)) < hill and hill < best_hill:
			best = body
			best_hill = hill
	if best == null:
		return Catalog.star()
	return best


static func hill_radius(body: BodyDef) -> float:
	var parent := Catalog.body(body.parent_id)
	if parent == null:
		return INF
	return body.orbit_radius * pow(body.mu / (3.0 * parent.mu), 1.0 / 3.0)


## Predice la trayectoria relativa al cuerpo dominante actual.
## Devuelve {points, hit, closest_dist, closest_time, closest_point}.
static func predict(pos: Vector2, vel: Vector2, t: float, steps: int, dt: float,
		bodies: Array[BodyDef], frame: BodyDef, target_pos: Callable, max_step: float = 0.2) -> Dictionary:
	var points := PackedVector2Array()
	var state := {"pos": pos, "vel": vel, "t": t}
	var frame_now := body_pos(frame, t)
	var closest := INF
	var closest_time := 0.0
	var closest_point := pos
	var hit := &""
	for i: int in steps:
		hit = step(state, dt, bodies, Vector2.ZERO, max_step)
		var p: Vector2 = state.pos
		var tt: float = state.t
		points.append(p - body_pos(frame, tt) + frame_now)
		if target_pos.is_valid():
			var tp: Vector2 = target_pos.call(tt)
			var d := p.distance_to(tp)
			if d < closest:
				closest = d
				closest_time = tt - t
				closest_point = tp - body_pos(frame, tt) + frame_now
		if hit != &"":
			break
	return {
		"points": points, "hit": hit, "closest_dist": closest,
		"closest_time": closest_time, "closest_point": closest_point,
	}
