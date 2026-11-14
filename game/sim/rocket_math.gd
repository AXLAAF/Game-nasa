class_name RocketMath
extends RefCounted

const G0 := 9.81
const SPACE_SCALE := 0.05 ## unidades de juego por metro
const BURN_COMPRESS := 4.0 ## los encendidos en el espacio duran 4 veces menos
const RADIUS_M := 6000.0 ## metros reales por unidad de radio del cuerpo
const SCALE_HEIGHT := 3800.0
const LAUNCH_DV := 2450.0 ## medido con el piloto automatico de tests/sim_tests.gd


static func density(body: BodyDef, altitude: float) -> float:
	if body.atmosphere <= 0.0:
		return 0.0
	return 1.225 * body.atmosphere * exp(-maxf(altitude, 0.0) / SCALE_HEIGHT)


## Altitud donde la atmosfera ya casi no frena.
static func atmosphere_top(body: BodyDef) -> float:
	if body.atmosphere <= 0.0:
		return 0.0
	return SCALE_HEIGHT * log(1.225 * body.atmosphere / 0.0003)


static func orbit_speed(body: BodyDef) -> float:
	return sqrt(body.surface_gravity * body.radius * RADIUS_M)


## Gravedad aparente en el modelo plano: la velocidad horizontal "cae alrededor" del planeta.
static func effective_gravity(body: BodyDef, horizontal_speed: float) -> float:
	var ratio := horizontal_speed / orbit_speed(body)
	return maxf(body.surface_gravity * (1.0 - ratio * ratio), -body.surface_gravity)


static func hohmann(mu: float, r1: float, r2: float) -> Vector2:
	var a := (r1 + r2) * 0.5
	var v1 := sqrt(mu / r1)
	var v2 := sqrt(mu / r2)
	var dv1 := absf(sqrt(mu * (2.0 / r1 - 1.0 / a)) - v1)
	var dv2 := absf(v2 - sqrt(mu * (2.0 / r2 - 1.0 / a)))
	return Vector2(dv1, dv2)


## Guiado de interceptacion: velocidad deseada hacia el objetivo y vector de empuje.
## Devuelve need, aim, phase (boost/brake/coast/capture), v_want, closing, dir, dist.
static func nav_burn(pos: Vector2, vel: Vector2, target_pos: Vector2, target_vel: Vector2, capture_r: float = 40.0) -> Dictionary:
	var offset := target_pos - pos
	var dist := offset.length()
	if dist < 0.01:
		return {"need": 0.0, "aim": 0.0, "phase": &"capture", "v_want": 0.0, "closing": 0.0, "dir": Vector2.ZERO, "dist": 0.0}
	var toward := offset / dist
	var vrel := vel - target_vel
	var closing := -vrel.dot(toward)
	var v_want := clampf(dist * 0.06, 1.5, 40.0)
	if dist < capture_r * 3.0:
		v_want = minf(v_want, 6.0)
	if dist < capture_r * 1.2:
		v_want = minf(v_want, 2.5)
	var burn: Vector2 = target_vel + toward * v_want - vel
	var need := burn.length()
	var phase: StringName = &"coast"
	if dist < capture_r and need < 2.5:
		phase = &"capture"
	elif need >= 0.8:
		phase = &"boost" if burn.dot(toward) > 0.0 else &"brake"
	return {
		"need": need, "aim": burn.angle() if need > 0.05 else toward.angle(),
		"phase": phase, "v_want": v_want, "closing": closing,
		"dir": burn.normalized() if need > 0.05 else toward, "dist": dist,
	}


## Delta-v estimado del contrato en m/s: despegue + transferencia + descenso.
static func mission_dv(target: BodyDef) -> float:
	var home := Catalog.home()
	var star := Catalog.star()
	if home == null or star == null or target == null:
		return LAUNCH_DV
	var park := home.radius * 2.0
	var v_park := sqrt(home.mu / park)
	var depart := 0.0
	var arrive := 0.0
	if target.parent_id == home.id:
		var local := hohmann(home.mu, park, target.orbit_radius)
		depart = local.x
		arrive = local.y
	else:
		var system := target
		if target.parent_id != star.id:
			system = Catalog.body(target.parent_id)
		var helio := hohmann(star.mu, home.orbit_radius, system.orbit_radius)
		depart = sqrt(helio.x * helio.x + 2.0 * home.mu / park) - v_park
		arrive = helio.y
		if system != target:
			arrive += sqrt(system.mu / target.orbit_radius) * 0.6
	var transfer := (depart + arrive * 0.35) / SPACE_SCALE
	var landing := 220.0
	if target.atmosphere <= 0.0:
		var excess := arrive / SPACE_SCALE
		landing = sqrt(orbit_speed(target) ** 2 + excess * excess * 0.4) + 160.0
	return LAUNCH_DV + transfer + landing


## Un paso del ascenso en el modelo plano. s: {x, h, vx, vy, q}. Devuelve la aceleracion del motor.
static func ascent_step(s: Dictionary, ship: ShipModel, body: BodyDef, throttle: float, pitch_deg: float, dt: float, thrust_mult: float = 1.0) -> float:
	var acc := ship.burn(throttle, dt) * thrust_mult
	var rad := deg_to_rad(pitch_deg)
	var dir := Vector2(sin(rad), cos(rad))
	var vel := Vector2(s.vx, s.vy)
	var speed := vel.length()
	s.q = 0.5 * density(body, s.h) * speed * speed
	var drag: float = s.q * 0.45 * ship.area() / (ship.mass() * 1000.0)
	var vel_dir := vel / speed if speed > 1.0 else dir
	var g := effective_gravity(body, s.vx)
	s.vx += (dir.x * acc - vel_dir.x * drag) * dt
	s.vy += (dir.y * acc - vel_dir.y * drag - g) * dt
	s.x += s.vx * dt
	s.h += s.vy * dt
	return acc


## Un paso del descenso. s: {x, h, vx, vy}; deja s.q y s.g (carga G). lift en [-1, 1].
static func descent_step(s: Dictionary, ship: ShipModel, body: BodyDef, throttle: float, pitch_deg: float,
		lift: float, chute_area: float, wind: float, dt: float, thrust_mult: float = 1.0) -> float:
	var air := Vector2(s.vx - wind * clampf(1.0 - s.h / 8000.0, 0.0, 1.0), s.vy)
	var speed := air.length()
	s.q = 0.5 * density(body, s.h) * speed * speed
	var area := ship.area() * (1.3 if ship.has_kind(&"heatshield") else 1.0)
	var drag: float = s.q * (1.1 * area + chute_area) / maxf(ship.mass() * 1000.0, 1.0)
	var air_dir := air / speed if speed > 0.5 else Vector2.ZERO
	var lift_dir := Vector2(-air_dir.y, air_dir.x) * (signf(air_dir.x) if absf(air_dir.x) > 0.01 else 1.0)
	var acc := ship.burn(throttle, dt) * thrust_mult
	var rad := deg_to_rad(pitch_deg)
	var push := -air_dir * drag + lift_dir * drag * 0.3 * lift + Vector2(sin(rad), cos(rad)) * acc
	s.g = push.length() / G0
	s.vx += push.x * dt
	s.vy += (push.y - effective_gravity(body, s.vx)) * dt
	s.x += s.vx * dt
	s.h += s.vy * dt
	return acc


## Calor de reentrada normalizado a la velocidad orbital del cuerpo.
static func entry_heat(body: BodyDef, altitude: float, speed: float) -> float:
	var rho := density(body, altitude)
	return sqrt(rho / 1.225) * pow(speed / orbit_speed(body), 3.0) * 12.0 if rho > 0.0 else 0.0


## Angulo de entrada mas plano (grados, negativo) que no rebota fuera de la atmosfera.
static func skip_edge(ship: ShipModel, body: BodyDef, v0: float) -> float:
	var top := atmosphere_top(body)
	var lo := -20.0
	var hi := -0.5
	for i: int in 6:
		var mid := (lo + hi) * 0.5
		var rad := deg_to_rad(mid)
		var s := {"x": 0.0, "h": top, "vx": v0 * cos(rad), "vy": v0 * sin(rad)}
		var skipped := false
		for k: int in 900:
			descent_step(s, ship, body, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5)
			if s.h > top * 1.03 and s.vy > 0.0:
				skipped = true
				break
			if s.h < top * 0.3:
				break
		if skipped:
			hi = mid
		else:
			lo = mid
	return lo


static func ascent_pitch(h: float, top: float) -> float:
	return 90.0 * pow(clampf(h / (top * 0.72), 0.0, 1.0), 0.5)


static func ascent_dv(body: BodyDef) -> float:
	var losses := 1.15 if body.atmosphere > 0.0 else 1.08
	return orbit_speed(body) * losses + body.surface_gravity * 15.0
