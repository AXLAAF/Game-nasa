extends Node2D

## Despegue: ventana de ignicion, ascenso con giro gravitatorio, max-Q, etapas y averias.
## Modelo plano: la velocidad horizontal reduce la gravedad aparente hasta la orbita.

const SIM_SPEED := 2.5
const S := 4.0 ## px por metro
const PITCH_RATE := 30.0
const Q_SAFE := 28000.0
const LAUNCH_WARPS: Array[float] = [0.5, 1.0, 2.0, 4.0]

enum State { COUNTDOWN, ASCENT, ORBIT, OVER }

var body: BodyDef
var state: State = State.COUNTDOWN
var countdown: float = 4.0
var x: float = 0.0
var h: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var pitch: float = 0.0
var throttle: float = 1.0
var stress: float = 0.0
var q: float = 0.0
var lifted: bool = false
var stuck_time: float = 0.0
var burn_clock: float = 0.0
var corridor_time: float = 0.0
var flight_time: float = 0.0
var overloads: int = 0
var ignition_bonus: float = 1.0
var v_orb: float = 0.0
var top: float = 0.0
var _cam: Camera2D
var _stars: Starfield
var _exhausts: Array[CPUParticles2D] = []
var _smoke: CPUParticles2D
var _debris: Array = []
var _clouds: Array = []
var _banner: Label
var _gauges: Dictionary = {}
var _info: Label
var _readouts: Dictionary = {}
var _pad_drop: float = 0.0
var _dial: Control
var _over_timer: float = -1.0
var _maxq_warned: bool = false
var warp_i: int = 1


func _ready() -> void:
	if Run.contract == null or Run.ship.parts.is_empty():
		Run.debug_setup()
	body = Catalog.home()
	v_orb = RocketMath.orbit_speed(body)
	top = RocketMath.atmosphere_top(body)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.3, 1.3)
	add_child(_cam)
	_cam.make_current()
	_stars = Starfield.new()
	add_child(_stars)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i: int in 160:
		_clouds.append(Vector3(rng.randf_range(-3000, 90000), rng.randf_range(1200, 7000), rng.randf_range(0.6, 1.8)))
	_smoke = Fx.smoke()
	_smoke.emitting = false
	add_child(_smoke)
	_rebuild_exhausts()
	_build_hud()
	_pad_drop = Run.ship.height_px() * 0.5
	Run.ship.auto_stage()
	ShipInterior.spawn(self) ## segundo jugador, si la partida lo pide


func _build_hud() -> void:
	var root := Ui.root(self)
	var row := Ui.console(root)
	for key: Array in [["alt", "Altitud", "km"], ["speed", "Velocidad", "m/s"], ["dv_readout", "Delta-v", "m/s"]]:
		_readouts[key[0]] = Ui.readout(row, key[1], key[2], 100.0)
	var well := Ui.well(row)
	well.custom_minimum_size = Vector2(170, 0)
	_info = Ui.label(well, "", Ui.SIZE_LEGEND, Ui.IVORY)
	var gauges := Ui.console_gauges(row, 3)
	for key: Array in [["orbit", "Vel. orbital", Ui.LAMP_GO], ["q", "Presión (Q)", Ui.LAMP_CAUTION], ["stress", "Estrés", Ui.LAMP_WARNING], ["throttle", "Acelerador (W/S)", Ui.INFO], ["fuel", "Combustible", Ui.IVORY]]:
		_gauges[key[0]] = Ui.console_gauge(gauges, key[1], key[2])
	var actions := Ui.console_keys(row, 1)
	Ui.compact(Ui.button(actions, "Estado (C)", func() -> void: Ui.toggle_status(self)))
	Ui.compact(Ui.button(actions, "Ignición o etapa (espacio)", func() -> void:
		if state == State.COUNTDOWN: _ignite()
		elif state == State.ASCENT: _try_stage()))
	Ui.compact(Ui.button(actions, "Abortar (retroceso)", _abort))
	Ui.annunciator(root)
	var ticker := Ticker.new()
	Ui.place(ticker, Ui.TICKER_RECT)
	root.add_child(ticker)
	_banner = Ui.banner(root, Ui.SIZE_HERO, 80)
	_dial = Control.new()
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.draw.connect(_draw_dial)
	root.add_child(_dial)
	Ui.keys(root, "W/S acelerador   A/D cabeceo   1-4 tiempo   Espacio ignición o etapa   C estado   Retroceso abortar")
	_place_dial()


func _place_dial() -> void:
	if Run.crew >= 2:
		# Centro del vuelo que el panel interior no tapa; anclado, para seguir a la ventana al redimensionar.
		var shift := ShipInterior.panel_width() * 0.5
		_dial.set_anchors_preset(Control.PRESET_CENTER)
		_dial.offset_left = -90.0 - shift
		_dial.offset_top = -90.0
		_dial.offset_right = 90.0 - shift
		_dial.offset_bottom = 90.0
	else:
		_dial.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_dial.offset_left = -200.0
		_dial.offset_right = -20.0
		_dial.offset_top = -Ui.CONSOLE_H - 210.0
		_dial.offset_bottom = -Ui.CONSOLE_H - 30.0


func _rebuild_exhausts() -> void:
	for p: CPUParticles2D in _exhausts:
		p.queue_free()
	_exhausts.clear()
	for nozzle: Vector2 in ShipRenderer.nozzles(Run.ship.parts, Run.ship.active_stage()):
		var p := Fx.exhaust()
		p.emitting = false
		p.set_meta("nozzle", nozzle)
		add_child(p)
		_exhausts.append(p)


func _unhandled_input(_event: InputEvent) -> void:
	if Controls.cmd_just(&"cmd_confirm"):
		if state == State.COUNTDOWN:
			_ignite()
		elif state == State.ASCENT:
			_try_stage()
	if Controls.cmd_just(&"cmd_abort") and state == State.ASCENT:
		_abort()
	if Controls.cmd_just(&"cmd_status"):
		Ui.toggle_status(self)
	var next := Controls.warp_choice(LAUNCH_WARPS.size(), warp_i)
	if next != warp_i:
		warp_i = next
		Events.toast.emit("Tiempo %s" % ("x%.1f" % LAUNCH_WARPS[warp_i] if LAUNCH_WARPS[warp_i] < 1.0 else "x%d" % int(LAUNCH_WARPS[warp_i])), Ui.INFO)
	if Controls.cmd_just(&"cmd_repair") and state == State.ASCENT and not lifted and stuck_time > 2.5:
		_scrub()


func _ignite() -> void:
	var timing := absf(countdown)
	var failed: Array[ShipPart]
	if timing <= 0.3:
		_say("Ignición perfecta", Ui.LAMP_GO)
		ignition_bonus = 1.05
		failed = Run.roll_stress(0.3, [&"engine"], Run.ship.active_stage())
		Juice.flash(Ui.LAMP_GO, 0.3)
	else:
		_say("Arranque duro" if countdown > 0.0 else "Ignición tardía", Ui.LAMP_CAUTION)
		stress += 0.25
		failed = Run.roll_stress(0.9, [&"engine"], Run.ship.active_stage())
		Juice.shake(0.5)
	state = State.ASCENT
	Synth.play(&"ignite")
	_smoke.emitting = true
	_raise(failed)


func _raise(failed: Array[ShipPart]) -> void:
	for part: ShipPart in failed:
		Card.malfunction(part, func(_ok: bool) -> void: _rebuild_exhausts())


func _try_stage() -> void:
	if not Run.ship.can_stage():
		Synth.play(&"deny")
		return
	var decouplers: Array = []
	for part: ShipPart in Run.ship.active_stage():
		if part.def.kind == &"decoupler":
			decouplers.append(part)
	var stuck := Run.roll_stress(0.5, [&"decoupler"], decouplers)
	if stuck.is_empty():
		_do_stage()
	else:
		Card.malfunction(stuck[0], func(ok: bool) -> void:
			if ok:
				_do_stage()
			else:
				Events.toast.emit("Desacoplador trabado: pulsa Espacio para reintentar", Ui.LAMP_CAUTION))


func _do_stage() -> void:
	var dropped := Run.ship.drop_stage()
	if dropped.is_empty():
		return
	_debris.append({"parts": dropped, "x": x, "h": h, "vx": vx, "vy": vy - 15.0, "rot": pitch, "spin": randf_range(-40, 40)})
	Synth.play(&"whoosh")
	Synth.play(&"thud", -4.0)
	Juice.shake(0.35)
	_rebuild_exhausts()
	_raise(Run.roll_stress(0.5, [&"engine"], Run.ship.active_stage()))
	Events.toast.emit("Separación de etapa", Ui.INFO)


func _abort() -> void:
	if not Run.ship.has_kind(&"escape") or not Run.ship.has_kind(&"capsule"):
		if Run.ship.fuel_total() <= 0.01:
			Run.destroy("Autodestrucción tras quedarse sin combustible.")
			return
		Synth.play(&"deny")
		Events.toast.emit("Sin torre de escape funcional", Ui.LAMP_WARNING)
		return
	Run.outcome = &"aborted"
	Run.outcome_text = "Abortaste el despegue. La torre salvó la cápsula."
	Synth.play(&"boom", -6.0)
	Fx.burst(self, Vector2.ZERO, Ui.LAMP_CAUTION, 90, 500)
	Juice.shake(0.8)
	_finish(State.OVER)


func _scrub() -> void:
	Profile.credits += Run.spent
	for part: ShipPart in Run.ship.parts.duplicate():
		if part.owned:
			Profile.inventory.append(part.to_dict())
			Run.ship.parts.erase(part)
	Run.spent = 0
	Run.premium = 0
	Profile.save_profile()
	Router.go(&"assembly")


func _say(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	var tween := _banner.create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func target_pitch() -> float:
	return RocketMath.ascent_pitch(h, top)


func _process(delta: float) -> void:
	if Run.outcome == &"lost" and state != State.OVER:
		_explode()
	match state:
		State.COUNTDOWN:
			countdown -= delta
			if countdown < -0.6:
				_ignite()
		State.ASCENT:
			_fly(delta)
		State.ORBIT:
			_coast(delta)
		State.OVER:
			_coast(delta)
	if _over_timer > 0.0:
		_over_timer -= delta
		if _over_timer <= 0.0:
			_leave()
	_update_debris(delta)
	_update_fx()
	_update_hud()
	queue_redraw()
	_dial.queue_redraw()


func _fly(delta: float) -> void:
	var dt := minf(delta, 0.05) * SIM_SPEED * LAUNCH_WARPS[warp_i]
	flight_time += delta
	var axis := Controls.throttle_axis()
	if axis > 0.0:
		throttle = minf(throttle + delta * 0.8 * axis, 1.0)
	elif axis < 0.0:
		throttle = maxf(throttle + delta * 0.8 * axis, 0.0)
	if Controls.cmd_held(&"cmd_throttle_full"):
		throttle = 1.0
	if Controls.cmd_held(&"cmd_throttle_zero"):
		throttle = 0.0
	var turn := Controls.steer()
	if Profile.assist and turn == 0.0 and lifted:
		pitch = move_toward(pitch, target_pitch(), PITCH_RATE * 0.55 * delta)
	pitch += turn * PITCH_RATE * Run.channel(&"mobility") * delta + _asymmetry() * delta
	pitch = clampf(pitch, -30.0, 120.0)
	var ship := Run.ship
	if not lifted:
		if ship.thrust() * throttle * ignition_bonus * Run.channel(&"thrust") / ship.mass() > body.surface_gravity:
			lifted = true
			Synth.play(&"thud", 0.0, 0.6)
			Juice.shake(0.4)
		else:
			ship.burn(throttle, dt)
			stuck_time += delta
			if stuck_time > 2.5:
				_banner.text = "TWR INSUFICIENTE - R para volver al ensamblaje"
				_banner.modulate.a = 1.0
			return
	var s := {"x": x, "h": h, "vx": vx, "vy": vy, "q": q}
	var acc := RocketMath.ascent_step(s, ship, body, throttle, pitch, dt, ignition_bonus * Run.channel(&"thrust"))
	x = s.x
	h = s.h
	vx = s.vx
	vy = s.vy
	q = s.q
	if acc > 0.0:
		burn_clock += dt
	if absf(pitch - target_pitch()) < 8.0:
		corridor_time += delta
	if q > Q_SAFE:
		stress += (q - Q_SAFE) / Q_SAFE * delta * (0.85 if Profile.assist else 1.4)
		if not _maxq_warned:
			_maxq_warned = true
			_say("MAX-Q  baja el acelerador", Ui.LAMP_CAUTION)
			Synth.play(&"beep")
	else:
		stress = maxf(stress - delta * 0.12, 0.0)
	if stress >= 1.0:
		stress = 0.45
		overloads += 1
		_say("Sobrecarga estructural", Ui.LAMP_WARNING)
		Synth.play(&"alarm")
		Juice.hit(0.8)
		Juice.hitstop(0.12)
		_raise(Run.roll_stress(1.0))
	if burn_clock > 20.0:
		burn_clock = 0.0
		_raise(Run.roll_stress(0.15, [&"engine"], ship.active_stage()))
	Juice.shake(clampf(q / Q_SAFE, 0.0, 1.5) * delta * 1.6 + throttle * acc * 0.0006)
	if h <= 0.0 and vy < 0.0 and flight_time > 1.0:
		h = 0.0
		Run.destroy("La nave se estrelló contra el suelo.")
		return
	if h >= top * 0.8 and vx >= v_orb * 0.97 and vy > -60.0:
		_reach_orbit()


func _asymmetry() -> float:
	var engines := Run.ship.of_kind(&"engine")
	var active := Run.ship.active_stage()
	var live: Array[float] = []
	for part: ShipPart in engines:
		if active.has(part):
			live.append(0.0 if part.broken else part.thrust_mult)
	if live.size() < 2:
		return 0.0
	return (live.max() - live.min()) * 10.0 * throttle


func _coast(delta: float) -> void:
	var dt := delta * SIM_SPEED
	x += vx * dt
	h += vy * dt * (0.0 if state == State.ORBIT else 1.0)


func _reach_orbit() -> void:
	state = State.ORBIT
	throttle = 0.0
	var ratio := corridor_time / maxf(flight_time, 1.0)
	var grade := "C"
	if ratio > 0.7 and overloads == 0:
		grade = "S"
	elif ratio > 0.5 and overloads <= 1:
		grade = "A"
	elif ratio > 0.3:
		grade = "B"
	Run.launch_grade = grade
	_say("En órbita, ascenso %s" % grade, Ui.LAMP_GO)
	Synth.play(&"chime")
	Juice.slowmo(0.35, 0.8)
	Juice.flash(Ui.INFO, 0.4)
	await get_tree().create_timer(1.6).timeout
	_offer_bets()


func _offer_bets() -> void:
	Card.show_card({
		"title": "Mesa de apuestas",
		"text": "La agencia acepta apuestas laterales sobre tu propia misión. Se cobran en la liquidación. Tienes %s." % Ui.money(Profile.credits),
		"tone": &"bet",
		"choices": [
			_bet("Sin apuesta", 0, "", 0.0),
			_bet("Llegar con 25%% de combustible  (100, paga x3)", 100, "fuel", 3.0),
			_bet("Entregar antes del plazo  (150, paga x2.5)", 150, "deadline", 2.5),
			_bet("Aterrizaje perfecto S  (200, paga x4)", 200, "perfect", 4.0),
		],
	}, func(_ok: bool) -> void: _leave())


func _bet(label: String, stake: int, kind: String, mult: float) -> ChoiceDef:
	var c := ChoiceDef.new()
	c.label = label
	if stake > 0:
		c.cost = {"stake": stake}
		c.win = {"bet": kind, "amount": stake, "mult": mult}
		c.win_text = "Apuesta registrada."
	else:
		c.win_text = "Sin riesgo extra."
	return c


func _explode() -> void:
	Synth.play(&"boom")
	Synth.engine_level = 0.0
	Fx.burst(self, Vector2.ZERO, Ui.LAMP_CAUTION, 160, 700, 1.4)
	Fx.burst(self, Vector2.ZERO, Color(0.5, 0.5, 0.5), 80, 300, 2.0)
	Juice.hit(1.0)
	Juice.hitstop(0.2)
	Run.ship.parts.clear()
	_rebuild_exhausts()
	_finish(State.OVER)


func _finish(new_state: State) -> void:
	state = new_state
	_over_timer = 2.2


func _leave() -> void:
	if Run.outcome == &"lost" or Run.outcome == &"aborted":
		Router.go(&"debrief")
	else:
		Router.go(&"space")


func _update_debris(delta: float) -> void:
	for d: Dictionary in _debris.duplicate():
		var dt := delta * SIM_SPEED
		d.vy -= body.surface_gravity * dt
		d.x += d.vx * dt * 0.97
		d.h += d.vy * dt
		d.rot += d.spin * delta
		if d.h < -200.0 or absf(d.h - h) > 6000.0:
			_debris.erase(d)


func _update_fx() -> void:
	var zoom := clampf(1.3 - h / 5000.0, 0.55, 1.3)
	_cam.zoom = _cam.zoom.lerp(Vector2(zoom, zoom), 0.05)
	var alt := clampf(h / (top * 0.7), 0.0, 1.0)
	var sky := Color(0.32, 0.58, 0.95).lerp(Color(0.015, 0.022, 0.058), alt)
	_stars.set_sky(sky, clampf((h - 9000.0) / 15000.0, 0.0, 1.0))
	_stars.set_view(Vector2(x, -h) * 0.05)
	var burning := state == State.ASCENT and throttle > 0.0 and Run.ship.stage_fuel(Run.ship.active_stage()) > 0.0
	Synth.engine_level = throttle if burning else 0.0
	Synth.roar_level = clampf(q / Q_SAFE * 0.6, 0.0, 1.0)
	var xf := _ship_xf()
	var flow := Vector2(-vx, vy) * S * 0.12
	for p: CPUParticles2D in _exhausts:
		var nozzle: Vector2 = p.get_meta("nozzle")
		p.position = xf * nozzle
		var out := Vector2(0, 1).rotated(deg_to_rad(pitch)) * 320.0 * (0.5 + throttle) + flow
		p.direction = out.normalized()
		p.initial_velocity_min = out.length() * 0.8
		p.initial_velocity_max = out.length()
		p.emitting = burning
	_smoke.position = Vector2(0, h * S)
	_smoke.emitting = burning and h < 300.0


func _ship_xf() -> Transform2D:
	var height := Run.ship.height_px()
	return Transform2D(deg_to_rad(pitch), Vector2.ZERO) * Transform2D(0.0, Vector2(0, height * 0.5))


## La nave se dibuja centrada en la camara: el suelo queda media nave por debajo.
func _world(wx: float, wh: float) -> Vector2:
	return Vector2((wx - x) * S, -(wh - h) * S + _pad_drop)


func _draw() -> void:
	var view := get_viewport_rect().size / _cam.zoom
	if h * S < view.y:
		var ground := _world(x, 0.0).y
		draw_rect(Rect2(-view.x, ground, view.x * 2.0, view.y), Color("2b3d30"))
		draw_rect(Rect2(-view.x, ground, view.x * 2.0, 6.0), Color("486b4c"))
		for k: int in 40:
			var hx := -view.x + k * view.x / 20.0
			var wx := x + hx / S
			var hill := 40.0 + 30.0 * sin(wx * 0.004) + 20.0 * sin(wx * 0.011 + 1.0)
			draw_rect(Rect2(hx, ground - hill, view.x / 20.0 + 1.0, hill), Color("22332c"))
		var pad := _world(0.0, 0.0)
		draw_rect(Rect2(pad.x - 90, pad.y - 10, 180, 10), Color(0.35, 0.35, 0.38))
		draw_rect(Rect2(pad.x - 70, pad.y - 260, 14, 250), Color(0.55, 0.25, 0.15))
		for k: int in 10:
			draw_line(Vector2(pad.x - 70, pad.y - 10 - k * 25), Vector2(pad.x - 56, pad.y - 35 - k * 25), Color(0.75, 0.4, 0.2), 2.0)
	for c: Vector3 in _clouds:
		var p := _world(c.x, c.y)
		if absf(p.x) < view.x and absf(p.y) < view.y:
			var a := 0.52 * (1.0 - clampf(h / 20000.0, 0.0, 0.85))
			for k: int in 4:
				var offset := Vector2(k * 40.0 * c.z - 60.0 * c.z, sin(k * 1.7) * 10.0)
				draw_circle(p + offset + Vector2(0.0, 6.0), 35.0 * c.z, Color(0.55, 0.68, 0.85, a * 0.35))
				draw_circle(p + offset, 34.0 * c.z, Color(1, 1, 1, a))
	if h < 4500.0:
		var mist_alpha := 0.30 * (1.0 - clampf(h / 4500.0, 0.0, 1.0))
		var drift := sin(Time.get_ticks_msec() * 0.0004) * 90.0
		var ground_mist := _world(x, 0.0).y - 12.0
		var mist := Ui.mist_texture()
		for m: int in 6:
			var mx := fposmod(m * 360.0 + drift - x * 0.14, view.x * 2.2) - view.x * 1.1
			var rx := 290.0 + float(m % 3) * 85.0
			var ry := 64.0 + float(m % 2) * 28.0
			var my := ground_mist - float(m % 3) * 28.0
			draw_texture_rect(mist, Rect2(mx - rx, my - ry, rx * 2.0, ry * 2.0), false, Color(0.82, 0.92, 1.06, mist_alpha))
	if h > 9000.0:
		var curve := clampf((h - 9000.0) / 25000.0, 0.0, 1.0)
		var horizon := view.y * lerpf(0.55, 0.85, curve)
		draw_rect(Rect2(-view.x, horizon, view.x * 2.0, view.y), Color(0.15, 0.35, 0.75, 0.55 * (1.0 - curve * 0.7)))
		draw_line(Vector2(-view.x, horizon), Vector2(view.x, horizon), Color(0.85, 1.45, 2.4, 0.75), 4.0)
	for d: Dictionary in _debris:
		var p := _world(d.x, d.h)
		var height := 0.0
		for part: ShipPart in d.parts:
			if not part.def.radial:
				height += part.def.size.y
		draw_set_transform_matrix(Transform2D(deg_to_rad(d.rot), p) * Transform2D(0.0, Vector2(0, height * 0.5)))
		ShipRenderer.draw(self, d.parts)
	draw_set_transform_matrix(_ship_xf())
	if not Run.ship.parts.is_empty():
		var burning := state == State.ASCENT and throttle > 0.0
		ShipRenderer.draw(self, Run.ship.parts, {"flame": throttle if burning else 0.0, "active": Run.ship.active_stage()})
		if q > Q_SAFE * 0.7:
			var b := ShipRenderer.bounds(Run.ship.parts)
			var a := clampf((q - Q_SAFE * 0.7) / Q_SAFE, 0.0, 0.6)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, b.position.y - 6), Vector2(b.size.x * 0.9, b.position.y + 50), Vector2(-b.size.x * 0.9, b.position.y + 50),
			]), Color(1, 1, 1, a))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _update_hud() -> void:
	_place_dial()
	var ship := Run.ship
	var ap := h + (vy * vy / (2.0 * maxf(RocketMath.effective_gravity(body, vx), 0.5)) if vy > 0.0 else 0.0)
	var warp_txt := "x%.1f" % LAUNCH_WARPS[warp_i] if LAUNCH_WARPS[warp_i] < 1.0 else "x%d" % int(LAUNCH_WARPS[warp_i])
	(_readouts.alt as Label).text = "%.1f" % (h / 1000.0)
	(_readouts.speed as Label).text = "%d" % int(Vector2(vx, vy).length())
	(_readouts.dv_readout as Label).text = "%d" % int(ship.delta_v())
	_info.text = "Apoapsis %.1f km\nTWR %.2f\nCabeceo %d, objetivo %d\nTiempo %s" % [ap / 1000.0, ship.twr(body.surface_gravity), int(pitch), int(target_pitch()), warp_txt]
	(_gauges.orbit as Gauge).set_value(vx / v_orb, "%d %%" % int(vx / v_orb * 100.0))
	(_gauges.q as Gauge).set_value(q / (Q_SAFE * 1.6), "%.0f kPa" % (q / 1000.0), q > Q_SAFE)
	(_gauges.stress as Gauge).set_value(stress, "%d %%" % int(stress * 100.0), stress > 0.7)
	(_gauges.throttle as Gauge).set_value(throttle, "%d %%" % int(throttle * 100.0))
	var stage := ship.active_stage()
	var cap := 0.0
	for part: ShipPart in stage:
		cap += part.def.fuel * part.boost
	var fuel := ship.stage_fuel(stage)
	(_gauges.fuel as Gauge).set_value(fuel / maxf(cap, 0.001), "%.1f t" % fuel, cap > 0.0 and fuel / cap < 0.1 and ship.can_stage())
	if state == State.COUNTDOWN:
		_banner.text = "T-%d. Pulsa Espacio en T-0" % maxi(ceili(countdown), 0) if countdown > 0.3 else "Ahora"
		_banner.modulate.a = 1.0
		_banner.add_theme_color_override("font_color", Ui.LAMP_GO if absf(countdown) <= 0.3 else Ui.IVORY)


func _draw_dial() -> void:
	var c := _dial.size * 0.5
	var r := 70.0
	_dial.draw_circle(c, r + 6, Color(0, 0, 0, 0.45))
	_dial.draw_arc(c, r, 0.0, TAU, 48, Color(0.3, 0.6, 0.8, 0.5), 2.0)
	if state == State.COUNTDOWN:
		var window := 0.3 / 4.0 * TAU
		_dial.draw_arc(c, r - 6, -PI * 0.5 - window, -PI * 0.5 + window, 16, Ui.LAMP_GO, 10.0)
		var a := -PI * 0.5 - countdown / 4.0 * TAU
		_dial.draw_line(c, c + Vector2(cos(a), sin(a)) * r, Ui.IVORY, 4.0)
		return
	var target := deg_to_rad(target_pitch()) - PI * 0.5
	_dial.draw_arc(c, r - 6, target - deg_to_rad(8), target + deg_to_rad(8), 12, Color(0.4, 1.0, 0.55, 0.7), 10.0)
	var a2 := deg_to_rad(pitch) - PI * 0.5
	_dial.draw_line(c, c + Vector2(cos(a2), sin(a2)) * r, Ui.IVORY, 4.0)
	_dial.draw_string(Ui.sans(), c + Vector2(-40, r + 22), "Corredor", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.IVORY_DIM)
