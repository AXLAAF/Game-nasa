extends Node2D

## Entrada atmosferica y aterrizaje. Mismo modelo plano que el despegue: si vas mas
## rapido que la orbita la gravedad aparente se invierte y rebotas al espacio.

const SIM_SPEED := 4.0
const PAD_EVERY := 1800.0
const PAD_HALF := 28.0
const G_LIMIT := 8.0
const SHIELD_RATE := 0.6 ## calor por segundo que un escudo puede absorber
const SHIELD_USE := 0.22 ## ablativo gastado por unidad de calor
const DESCENT_WARPS: Array[float] = [0.5, 1.0, 2.0, 4.0]

enum State { APPROACH, ENTRY, FLIGHT, LANDED, OVER }

var body: BodyDef
var state: State = State.APPROACH
var x: float = 0.0
var h: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var pitch: float = 0.0 ## grados desde la vertical; el empuje apunta hacia ahi
var throttle: float = 0.0
var gamma: float = -5.0
var corridor: Vector2 = Vector2(-9.0, -3.0)
var lift: float = 0.0
var v0: float = 0.0
var v_orb: float = 0.0
var top: float = 0.0
var hull_heat: float = 0.0
var heat: float = 0.0
var g_load: float = 0.0
var chute: int = 0
var wind: float = 0.0
var ejected: bool = false
var explored: bool = false
var grade: String = ""
var warp_i: int = 1
var hold_retro: bool = false
var _seed: float = 0.0
var _amp: float = 200.0
var _stress_clock: float = 0.0
var _burn_clock: float = 0.0
var _over_timer: float = -1.0
var _cam: Camera2D
var _stars: Starfield
var _plasma: CPUParticles2D
var _scale: float = 1.0
var _gauges: Dictionary = {}
var _info: Label
var _readouts: Dictionary = {}
var _banner: Label
var _prompt: Label
var _panel: PanelContainer


func _ready() -> void:
	if Run.contract == null or Run.ship.parts.is_empty():
		Run.debug_setup()
	if Run.landed_body == &"":
		Run.landed_body = Run.contract.target
	body = Catalog.body(Run.landed_body)
	v_orb = RocketMath.orbit_speed(body)
	top = RocketMath.atmosphere_top(body) if body.atmosphere > 0.0 else 15000.0
	_seed = float(hash(body.id) % 1000)
	_amp = 120.0 + body.surface_gravity * 25.0
	var excess: float = Run.space_state.get("entry_excess", v_orb * 0.3)
	v0 = minf(sqrt(v_orb * v_orb + excess * excess * (0.6 if body.atmosphere > 0.0 else 0.4)), v_orb * 1.6)
	h = top
	wind = Run.rng.randf_range(-12.0, 12.0) * body.atmosphere
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_stars = Starfield.new()
	add_child(_stars)
	_plasma = Fx.plasma()
	_plasma.emitting = false
	add_child(_plasma)
	_build_hud()
	_hidden_hazard()
	if body.atmosphere <= 0.0:
		gamma = -2.0
		_commit()
	else:
		var edge := RocketMath.skip_edge(Run.ship, body, v0) - 0.5
		var width := 5.5 if Profile.assist else 4.0
		corridor = Vector2(edge - width, edge)
		if Run.channel(&"map") < 0.6 and not Profile.assist:
			corridor += Vector2.ONE * Run.rng.randf_range(-2.0, 2.0)
		gamma = edge - width * 0.5
		_say("CORREDOR DE ENTRADA", Ui.INFO)


func _hidden_hazard() -> void:
	if body != Run.target() or Run.contract.hidden_hazard == &"":
		return
	var hazard := Run.contract.hidden_hazard
	var text := ""
	match hazard:
		&"storms":
			wind *= 3.0
			wind += 18.0 * signf(wind + 0.01)
			text = "TORMENTA en la zona de aterrizaje"
		&"dust":
			Run.apply({"vision": -0.35})
			text = "POLVO: visibilidad reducida"
		&"radiation":
			text = "RADIACION en superficie"
			_raise(Run.roll_stress(0.6, [&"computer", &"sensor", &"antenna", &"battery"]))
		&"cold":
			Run.temp = 0.05
			text = "FRIO EXTREMO: el combustible se espesa"
			_raise(Run.roll_stress(0.4, [&"tank", &"engine"]))
		&"heat":
			hull_heat = 0.35
			text = "CALOR EXTREMO: el casco ya viene caliente"
	Events.toast.emit("PELIGRO OCULTO: " + text, Ui.LAMP_WARNING)
	Run.note("Peligro oculto: " + text)
	Synth.play(&"alarm")


func _build_hud() -> void:
	var root := Ui.root(self)
	var row := Ui.console(root)
	for key: Array in [["alt", "Altitud", "km"], ["vertical", "Vel. vertical", "m/s"], ["horizontal", "Vel. horizontal", "m/s"]]:
		_readouts[key[0]] = Ui.readout(row, key[1], key[2], 110.0)
	var well := Ui.well(row)
	well.custom_minimum_size = Vector2(200, 0)
	_info = Ui.label(well, "", Ui.SIZE_LEGEND, Ui.IVORY)
	var gauges := Ui.console_gauges(row, 3)
	for key: Array in [["heat", "Calor del casco", Ui.LAMP_WARNING], ["shield", "Escudo ablativo", Ui.LAMP_CAUTION], ["g", "Carga G", Ui.IVORY], ["burn", "Frenado", Ui.LAMP_GO], ["fuel", "Combustible", Ui.INFO]]:
		_gauges[key[0]] = Ui.console_gauge(gauges, key[1], key[2])
	var buttons := Ui.console_keys(row, 1)
	Ui.compact(Ui.button(buttons, "Estado (C)", func() -> void: Ui.toggle_status(self)))
	Ui.compact(Ui.button(buttons, "Paracaídas (P)", _deploy_chute))
	Ui.compact(Ui.button(buttons, "Eyectar (E)", _eject))
	Ui.annunciator(root)
	var ticker := Ticker.new()
	Ui.place(ticker, Rect2(12, 12, 380, 200))
	root.add_child(ticker)
	_banner = Ui.banner(root, Ui.SIZE_HERO, 80)
	_prompt = Ui.keys(root, "")
	_panel = Ui.panel(root)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position += Vector2(-200, -120)
	_panel.custom_minimum_size = Vector2(400, 0)
	_panel.visible = false


func _say(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	var tween := _banner.create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _raise(failed: Array[ShipPart]) -> void:
	for part: ShipPart in failed:
		Card.malfunction(part)


# ---------------------------------------------------------------- terreno

func terrain(px: float) -> float:
	var base := _amp * (1.0 + sin(px * 0.0011 + _seed) * 0.6 + sin(px * 0.0037 + _seed * 2.0) * 0.3 + sin(px * 0.013 + _seed * 3.0) * 0.1)
	var k := roundf((px - _pad_offset(roundf(px / PAD_EVERY))) / PAD_EVERY)
	var center := k * PAD_EVERY + _pad_offset(k)
	var d := absf(px - center)
	if d < PAD_HALF * 2.5:
		var flat := _amp * (1.0 + sin(center * 0.0011 + _seed) * 0.6 + sin(center * 0.0037 + _seed * 2.0) * 0.3 + sin(center * 0.013 + _seed * 3.0) * 0.1)
		return lerpf(flat, base, clampf((d - PAD_HALF) / (PAD_HALF * 1.5), 0.0, 1.0))
	return base


func _pad_offset(k: float) -> float:
	return sin(k * 12.9898 + _seed) * 500.0


func nearest_pad(px: float) -> float:
	var k := roundf(px / PAD_EVERY)
	var best := INF
	for j: float in [k - 1.0, k, k + 1.0]:
		var c := j * PAD_EVERY + _pad_offset(j)
		if absf(c - px) < absf(best - px):
			best = c
	return best


func agl() -> float:
	return h - terrain(x)


# ---------------------------------------------------------------- input

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).physical_keycode:
		KEY_SPACE:
			if state == State.APPROACH:
				_commit()
			elif state == State.FLIGHT or state == State.ENTRY:
				_stage()
		KEY_P:
			if state == State.ENTRY or state == State.FLIGHT:
				_deploy_chute()
		KEY_E:
			if state == State.ENTRY or state == State.FLIGHT:
				_eject()
		KEY_C:
			Ui.toggle_status(self)
		KEY_T:
			hold_retro = not hold_retro
		KEY_1, KEY_2, KEY_3, KEY_4:
			var next := (event as InputEventKey).physical_keycode - KEY_1
			if next >= 2 and (heat > 0.05 or agl() < 3000.0):
				Events.toast.emit("Demasiado bajo o caliente para acelerar", Ui.LAMP_CAUTION)
				warp_i = 1
			else:
				warp_i = next
				Events.toast.emit("Tiempo %s" % ("x%.1f" % DESCENT_WARPS[warp_i] if DESCENT_WARPS[warp_i] < 1.0 else "x%d" % int(DESCENT_WARPS[warp_i])), Ui.INFO)


func _commit() -> void:
	var rad := deg_to_rad(gamma)
	vx = v0 * cos(rad)
	vy = v0 * sin(rad)
	pitch = rad_to_deg(atan2(-vx, -vy))
	state = State.ENTRY if body.atmosphere > 0.0 else State.FLIGHT
	Synth.play(&"whoosh")
	if body.atmosphere > 0.0:
		_say("INTERFAZ DE ENTRADA  %.1f grados" % gamma, Ui.LAMP_CAUTION)
	else:
		_say("SIN ATMOSFERA: frena con el motor (T retro)", Ui.LAMP_CAUTION)


func _stage() -> void:
	if not Run.ship.can_stage():
		Synth.play(&"deny")
		return
	Run.ship.drop_stage()
	Synth.play(&"thud")
	Juice.shake(0.3)
	Events.toast.emit("Etapa separada", Ui.INFO)


func _deploy_chute() -> void:
	var chutes := Run.ship.of_kind(&"parachute")
	var live: Array[ShipPart] = []
	for part: ShipPart in chutes:
		if not part.broken and not part.deployed:
			live.append(part)
	if live.is_empty() or chute >= 2:
		Synth.play(&"deny")
		return
	var speed := Vector2(vx, vy).length()
	var limit := 450.0 if chute == 0 else 120.0
	Synth.play(&"whoosh", 0.0, 1.3)
	if chute == 1 and agl() > 6000.0:
		Events.toast.emit("Demasiado alto para el principal", Ui.LAMP_CAUTION)
		return
	if speed > limit and Run.rng.randf() < clampf((speed - limit) / 250.0, 0.15, 0.95):
		var torn := live[0]
		torn.broken = true
		_say("PARACAIDAS DESGARRADO", Ui.LAMP_WARNING)
		Juice.hit(0.6)
		Run.lose_streak()
		return
	var failed := Run.roll_stress(0.4, [&"parachute"], live)
	chute += 1
	Juice.shake(0.5)
	if chute == 2:
		for part: ShipPart in live:
			part.deployed = true
	_say("FRENO DESPLEGADO" if chute == 1 else "PRINCIPAL DESPLEGADO", Ui.LAMP_GO)
	for part: ShipPart in failed:
		Card.malfunction(part, func(ok: bool) -> void:
			if not ok:
				chute = 0
				Events.toast.emit("Paracaidas perdido", Ui.LAMP_WARNING))


func _eject() -> void:
	if ejected or not Run.ship.eject_capsule():
		Synth.play(&"deny")
		return
	ejected = true
	throttle = 0.0
	Synth.play(&"boom", -8.0)
	Juice.hit(0.6)
	Fx.burst(self, Vector2.ZERO, Ui.LAMP_CAUTION, 70, 260)
	_say("CAPSULA EYECTADA", Ui.LAMP_CAUTION)
	Run.note("Capsula eyectada en %s" % body.display_name)


# ---------------------------------------------------------------- simulacion

func _process(delta: float) -> void:
	if Run.outcome == &"lost" and state != State.OVER:
		_explode()
	match state:
		State.APPROACH:
			if Input.is_physical_key_pressed(KEY_W): gamma = minf(gamma + delta * 3.0, -0.5)
			if Input.is_physical_key_pressed(KEY_S): gamma = maxf(gamma - delta * 3.0, -15.0)
		State.ENTRY, State.FLIGHT:
			_fly(delta)
	if _over_timer > 0.0:
		_over_timer -= delta
		if _over_timer <= 0.0:
			Router.go(&"debrief")
	_update_view(delta)
	_update_hud()
	queue_redraw()


func _corridor() -> Vector2:
	return corridor


func _fly(delta: float) -> void:
	var dt := minf(delta, 0.05) * SIM_SPEED * DESCENT_WARPS[warp_i]
	var ship := Run.ship
	var mobility := Run.channel(&"mobility")
	if state == State.ENTRY:
		lift = 0.0
		if Input.is_physical_key_pressed(KEY_W): lift = 1.0
		if Input.is_physical_key_pressed(KEY_S): lift = -1.0
		lift *= mobility
		throttle = 0.0
		pitch = rad_to_deg(atan2(-vx, -vy))
		if Vector2(vx, vy).length() < v_orb * 0.45 or agl() < 7000.0:
			state = State.FLIGHT
			_say("CONTROL MANUAL", Ui.INFO)
	else:
		lift = 0.0
		if Input.is_physical_key_pressed(KEY_W): throttle = minf(throttle + delta * 1.2, 1.0)
		if Input.is_physical_key_pressed(KEY_S): throttle = maxf(throttle - delta * 1.2, 0.0)
		if Input.is_physical_key_pressed(KEY_Z): throttle = 1.0
		if Input.is_physical_key_pressed(KEY_X): throttle = 0.0
		var turn := 0.0
		if Input.is_physical_key_pressed(KEY_A): turn -= 1.0
		if Input.is_physical_key_pressed(KEY_D): turn += 1.0
		if turn != 0.0:
			hold_retro = false
			pitch = clampf(pitch + turn * 50.0 * mobility * delta, -100.0, 100.0)
		elif hold_retro:
			pitch = move_toward(pitch, clampf(rad_to_deg(atan2(-vx, -vy)), -100.0, 100.0), 60.0 * mobility * delta)
		if ship.stage_fuel(ship.active_stage()) <= 0.0:
			ship.auto_stage()
	if throttle > 0.0 or heat > 0.05:
		warp_i = mini(warp_i, 1)
	var chute_area := 0.0
	if chute > 0:
		for part: ShipPart in ship.of_kind(&"parachute"):
			if not part.broken:
				chute_area += part.def.drag * (0.3 if chute == 1 else 3.0)
	var s := {"x": x, "h": h, "vx": vx, "vy": vy}
	var acc := RocketMath.descent_step(s, ship, body, throttle, pitch, lift, chute_area, wind, dt, Run.channel(&"thrust"))
	x = s.x
	h = s.h
	vx = s.vx
	vy = s.vy
	g_load = s.g
	var q: float = s.q
	if acc > 0.0:
		_burn_clock += dt
		if _burn_clock > 15.0:
			_burn_clock = 0.0
			_raise(Run.roll_stress(0.2, [&"engine"], ship.active_stage()))
	_heat(Vector2(vx, vy).length(), dt)
	var g_cap := G_LIMIT + (2.0 if Profile.assist else 0.0)
	if g_load > g_cap:
		_stress_clock += delta
		Juice.shake(delta * 2.0)
		if _stress_clock > 0.8:
			_stress_clock = 0.0
			_say("SOBRECARGA %.1f G" % g_load, Ui.LAMP_WARNING)
			Synth.play(&"alarm", -6.0)
			_raise(Run.roll_stress((g_load - g_cap) / g_cap + 0.4))
	Juice.shake(clampf(q / 30000.0, 0.0, 1.0) * delta * 1.5)
	if h > top * 1.03 and vy > 0.0:
		_skip_out()
		return
	if agl() <= 0.0:
		_touchdown()


func _heat(speed: float, dt: float) -> void:
	heat = RocketMath.entry_heat(body, h, speed)
	Juice.plasma = clampf(heat * 2.0, 0.0, 1.0)
	var resist := clampf(Run.ship.sum_stat(&"heat_resist"), 0.0, 0.9)
	var load := heat * dt
	for part: ShipPart in Run.ship.of_kind(&"heatshield"):
		if part.broken or part.ablative <= 0.0 or load <= 0.0:
			continue
		var absorbed := minf(minf(load, SHIELD_RATE * dt), part.ablative / SHIELD_USE)
		part.ablative -= absorbed * SHIELD_USE
		load -= absorbed
		if part.ablative <= 0.0:
			Events.toast.emit("ESCUDO TERMICO AGOTADO", Ui.LAMP_WARNING)
	hull_heat = maxf(hull_heat + load * 0.6 * (1.0 - resist * 0.6) - dt * 0.012, 0.0)
	if hull_heat > 1.0:
		_stress_clock += dt
		if _stress_clock > 2.0:
			_stress_clock = 0.0
			var victims: Array[ShipPart] = []
			for part: ShipPart in Run.ship.parts:
				if not part.broken and part.def.kind != &"capsule":
					victims.append(part)
			if victims.is_empty() or hull_heat > 1.5:
				Run.destroy("La nave se desintegro en la reentrada de %s." % body.display_name)
				return
			var victim: ShipPart = victims[Run.rng.randi_range(0, victims.size() - 1)]
			if Run.admit(victim):
				victim.broken = true
				Events.toast.emit("%s se fundio" % victim.def.display_name, Ui.LAMP_WARNING)
			Juice.hit(0.4)


func _skip_out() -> void:
	state = State.OVER
	_say("REBOTE EN LA ATMOSFERA", Ui.LAMP_CAUTION)
	Run.lose_streak()
	Run.space_state.return_body = body.id
	Run.space_state.return_boost = 1.12
	Synth.play(&"whoosh")
	await get_tree().create_timer(1.5).timeout
	Router.go(&"space")


func _touchdown() -> void:
	var ship := Run.ship
	h = terrain(x)
	var vs := absf(vy)
	var slope := rad_to_deg(atan((terrain(x + 2.0) - terrain(x - 2.0)) / 4.0))
	var tilt := absf(pitch) + absf(slope) * 0.6
	var tol := 9.0 if ship.has_kind(&"legs") else 4.5
	if Profile.assist:
		tol *= 1.35
	var on_pad := absf(x - nearest_pad(x)) < PAD_HALF
	var impact := vs + absf(vx) * 0.5
	if tilt > 35.0:
		impact += (tilt - 35.0) * 0.3
	if impact > tol * 2.5:
		Run.destroy("Impacto a %d m/s contra %s." % [int(vs), body.display_name])
		return
	state = State.LANDED
	throttle = 0.0
	vx = 0.0
	vy = 0.0
	Juice.shake(clampf(impact / tol, 0.2, 1.0))
	Synth.play(&"thud", 0.0, 0.7)
	if impact < 2.5 and tilt < 8.0 and on_pad:
		grade = "S"
	elif impact < tol * 0.5 and tilt < 15.0:
		grade = "A"
	elif impact < tol:
		grade = "B"
	else:
		grade = "C"
	if impact > tol * 0.6:
		var stress := impact / tol
		for part: ShipPart in Run.roll_stress(stress, [], ship.parts_in_zone(&"bottom")):
			part.broken = true
			Events.toast.emit("%s cedio en el impacto" % part.def.display_name, Ui.LAMP_WARNING)
		if impact > tol:
			for part: ShipPart in Run.roll_stress(stress * 0.6, [], ship.parts_in_zone(&"middle")):
				part.broken = true
	if on_pad and body == Run.target():
		Run.apply({"credits": 200})
		Events.toast.emit("Aterrizaje en plataforma: +$200", Ui.IVORY)
	Run.landed_body = body.id
	Run.grade = grade
	_say("ATERRIZAJE %s" % grade, Ui.LAMP_GO if grade in ["S", "A"] else Ui.IVORY)
	Synth.play(&"jackpot" if grade == "S" else &"chime")
	if grade == "S":
		Run.win_streak()
	Juice.plasma = 0.0
	_show_surface()


func _explode() -> void:
	state = State.OVER
	Synth.play(&"boom")
	Synth.engine_level = 0.0
	Fx.burst(self, Vector2.ZERO, Ui.LAMP_CAUTION, 160, 700, 1.4)
	Juice.hit(1.0)
	Juice.hitstop(0.2)
	Juice.plasma = 0.0
	Run.ship.parts.clear()
	_over_timer = 2.2


# ---------------------------------------------------------------- superficie

func _show_surface() -> void:
	for child: Node in _panel.get_children():
		child.queue_free()
	_panel.visible = true
	var col := Ui.vbox(_panel, 8)
	Ui.plate(col, "Superficie de %s" % body.display_name)
	var at_target := body == Run.target()
	if at_target:
		var text := "Entregar %s" % Run.contract.cargo.to_lower()
		if ejected:
			text += "  (capsula sola: entrega parcial)"
		Ui.primary(Ui.button(col, text, _deliver))
	if not explored:
		Ui.button(col, "Explorar la zona", _explore)
	if not Run.ship.broken_parts().is_empty():
		var fix := Ui.button(col, "Reparar con kit (%d)" % Run.kits, _repair)
		fix.disabled = Run.kits <= 0
	var need := RocketMath.ascent_dv(body)
	var dv := Run.ship.delta_v()
	var can_fly := not ejected and dv >= need and Run.ship.twr(body.surface_gravity) > 1.0
	var takeoff := Ui.button(col, "Despegar a órbita (%d / %d m/s)" % [int(dv), int(need)], _take_off)
	takeoff.disabled = not can_fly
	if body.is_home:
		Ui.button(col, "Terminar la mision en casa", _go_home)
	elif not at_target:
		Ui.button(col, "Abandonar y pedir rescate", _abandon)


func _deliver() -> void:
	Run.outcome = &"partial" if ejected else &"delivered"
	Run.outcome_text = "Entrega %s en %s. Aterrizaje %s." % ["parcial" if ejected else "completa", body.display_name, grade]
	Synth.play(&"win")
	Juice.flash(Ui.IVORY, 0.5)
	Router.go(&"debrief")


func _explore() -> void:
	explored = true
	var deep := ChoiceDef.new()
	deep.label = "Expedicion profunda"
	deep.odds = 0.45
	deep.win = {"science": 3, "boxes": 1}
	deep.lose = {"rand_break": true, "battery": -0.3}
	deep.win_text = "Cuevas llenas de minerales."
	deep.lose_text = "El rover volvio a rastras."
	var short := ChoiceDef.new()
	short.label = "Paseo corto"
	short.odds = 0.85
	short.win = {"science": 1}
	short.lose = {"battery": -0.2}
	var stay := ChoiceDef.new()
	stay.label = "Quedarse en la nave"
	Card.show_card({
		"title": "Exploracion de %s" % body.display_name,
		"text": body.description,
		"tone": &"encounter",
		"rarity": 1 if body.payout > 1.5 else 0,
		"choices": [deep, short, stay],
	}, func(_ok: bool) -> void: _show_surface())


func _repair() -> void:
	var broken := Run.ship.broken_parts()
	if broken.is_empty() or Run.kits <= 0:
		return
	Run.kits -= 1
	Run.apply({"fix": true}, broken[0])
	Synth.play(&"coin")
	Events.toast.emit("%s reparada" % broken[0].def.display_name, Ui.LAMP_GO)
	_show_surface()


func _take_off() -> void:
	var ship := Run.ship
	var need := RocketMath.ascent_dv(body)
	var spent := 0.0
	for i: int in 4000:
		if spent >= need:
			break
		var acc := ship.burn(1.0, 0.25)
		if acc <= 0.0:
			if not ship.auto_stage():
				break
			continue
		spent += acc * 0.25
	Run.space_state.return_body = body.id
	Run.space_state.return_boost = 1.0
	Synth.play(&"ignite")
	Router.go(&"space")


func _go_home() -> void:
	Run.outcome = &"aborted"
	Run.outcome_text = "Volviste a %s sin entregar la carga." % body.display_name
	Router.go(&"debrief")


func _abandon() -> void:
	Run.apply({"rescue": true})
	Router.go(&"debrief")


# ---------------------------------------------------------------- vista

func _update_view(delta: float) -> void:
	var ground := agl()
	var target_scale := clampf(320.0 / maxf(ground, 40.0), 0.004, 6.0)
	_scale = lerpf(_scale, target_scale, minf(delta * 3.0, 1.0))
	var density := clampf(RocketMath.density(body, h) / 1.225 * 4.0, 0.0, 1.0) if body.atmosphere > 0.0 else 0.0
	var sky := Color(0.01, 0.015, 0.04).lerp(Color(body.atmo_color.r, body.atmo_color.g, body.atmo_color.b), density * 0.8)
	_stars.set_sky(sky, 1.0 - density)
	_stars.set_view(Vector2(x, -h) * 0.002)
	var flying := state == State.ENTRY or state == State.FLIGHT
	Synth.engine_level = throttle if flying and Run.ship.stage_fuel(Run.ship.active_stage()) > 0.0 else 0.0
	Synth.roar_level = clampf(heat * 1.5, 0.0, 1.0) if flying else 0.0
	_plasma.emitting = flying and heat > 0.08
	if _plasma.emitting:
		var dir := Vector2(vx, -vy).normalized()
		_plasma.position = dir * 30.0
		_plasma.direction = -dir
		_plasma.modulate.a = clampf(heat * 2.0, 0.2, 1.0)


func _update_hud() -> void:
	var ship := Run.ship
	var blackout := Juice.plasma > 0.6
	var speed := Vector2(vx, vy).length()
	var lines := PackedStringArray()
	if state == State.APPROACH:
		var c := _corridor()
		lines.append("Ángulo %.1f" % gamma)
		lines.append("Corredor de %.1f a %.1f" % [c.x, c.y])
		lines.append("Velocidad de entrada %d m/s" % int(v0))
		_prompt.text = "W/S ajustar ángulo   Espacio confirmar   Muy plano rebotas; muy empinado, calor y G"
	elif blackout:
		lines.append("Apagón de plasma")
		lines.append("Sin telemetría")
		_prompt.text = "W/S sustentación arriba o abajo   P paracaídas   E eyectar"
	else:
		lines.append("Sobre el suelo %d m" % int(agl()))
		lines.append("Velocidad %d m/s" % int(speed))
		lines.append("Delta-v %d m/s, TWR %.2f" % [int(ship.delta_v()), ship.twr(body.surface_gravity)])
		var pad := nearest_pad(x)
		lines.append("Plataforma a %d m a la %s" % [int(absf(pad - x)), "izquierda" if pad < x else "derecha"])
		if absf(wind) > 1.0:
			lines.append("Viento %+d m/s" % int(wind))
		if state == State.ENTRY:
			_prompt.text = "W/S sustentación   P paracaídas (freno bajo 450 m/s, principal bajo 120)   E eyectar   1-4 tiempo"
		else:
			_prompt.text = "W/S acelerador   A/D inclinar   T retro   P paracaídas   Espacio etapa   E eyectar   1-4 tiempo"
	if state == State.LANDED:
		_prompt.text = ""
	_info.text = "\n".join(lines)
	(_readouts.alt as Label).text = "%.1f" % (agl() / 1000.0)
	(_readouts.vertical as Label).text = "%d" % int(vy)
	(_readouts.horizontal as Label).text = "%d" % int(vx)
	(_gauges.heat as Gauge).set_value(hull_heat / 1.5, "%d%%" % int(hull_heat / 1.5 * 100.0), hull_heat > 0.8)
	var ablative := 0.0
	var ablative_max := 0.0
	for part: ShipPart in ship.of_kind(&"heatshield"):
		ablative += part.ablative
		ablative_max += part.def.ablative
	(_gauges.shield as Gauge).set_value(ablative / maxf(ablative_max, 0.001), "SIN ESCUDO" if ablative_max <= 0.0 else "%d%%" % int(ablative / ablative_max * 100.0), ablative_max > 0.0 and ablative < ablative_max * 0.2)
	(_gauges.g as Gauge).set_value(g_load / 12.0, "%.1f G" % g_load, g_load > G_LIMIT)
	var max_acc := ship.thrust() * Run.channel(&"thrust") / maxf(ship.mass(), 0.01) - body.surface_gravity
	var stop := vy * vy / (2.0 * maxf(max_acc, 0.1)) if vy < 0.0 else 0.0
	var ratio := stop / maxf(agl(), 1.0)
	(_gauges.burn as Gauge).set_value(ratio, "QUEMAR YA" if ratio > 0.85 else "%d%%" % int(ratio * 100.0), ratio > 0.85)
	var stage := ship.active_stage()
	var cap := 0.0
	for part: ShipPart in stage:
		cap += part.def.fuel * part.boost
	(_gauges.fuel as Gauge).set_value(ship.stage_fuel(stage) / maxf(cap, 0.001), "%.1f t" % ship.stage_fuel(stage))
	for key: String in ["g", "burn", "fuel"]:
		(_gauges[key] as Gauge).modulate.a = 0.25 if blackout else 1.0


func _to_screen(wx: float, wh: float) -> Vector2:
	return Vector2((wx - x) * _scale, -(wh - h) * _scale)


func _draw() -> void:
	var view := get_viewport_rect().size
	if state == State.APPROACH:
		_draw_corridor(view)
		return
	var ground_y := _to_screen(x, terrain(x)).y
	if ground_y < view.y:
		var span := view.x * 1.2 / maxf(_scale, 0.004)
		var step := maxf(span / 160.0, 1.0)
		var points := PackedVector2Array()
		var wx := x - span * 0.5
		while wx < x + span * 0.5:
			var p := _to_screen(wx, terrain(wx))
			points.append(Vector2(p.x, minf(p.y, view.y)))
			wx += step
		points.append(Vector2(view.x * 0.6, view.y + 10.0))
		points.append(Vector2(-view.x * 0.6, view.y + 10.0))
		var ground_color := body.color.darkened(0.45)
		if points.size() > 3:
			draw_colored_polygon(points, ground_color)
		var pad := nearest_pad(x)
		for p: float in [pad - PAD_EVERY, pad, pad + PAD_EVERY]:
			var a := _to_screen(p - PAD_HALF, terrain(p))
			var b := _to_screen(p + PAD_HALF, terrain(p))
			draw_line(a, b, Ui.LAMP_GO if body == Run.target() else Ui.IVORY, maxf(3.0, 1.0 * _scale))
			var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
			draw_circle(a, 3.0, Color(2.0, 0.3, 0.2, blink))
			draw_circle(b, 3.0, Color(2.0, 0.3, 0.2, blink))
	if Run.ship.parts.is_empty():
		return
	var ship_scale := clampf(_scale * 0.12, 0.16, 0.7)
	var landed := state == State.LANDED
	var xf := Transform2D(deg_to_rad(pitch), Vector2.ZERO) * Transform2D(0.0, Vector2.ZERO if landed else Vector2(0, Run.ship.height_px() * 0.5))
	draw_set_transform_matrix(Transform2D(0.0, Vector2(ship_scale, ship_scale), 0.0, Vector2(0, ground_y if landed else 0.0)) * xf)
	if heat > 0.05:
		var b := ShipRenderer.bounds(Run.ship.parts)
		draw_circle(Vector2(0, b.end.y), b.size.x * (0.8 + heat), Color(3.0, 1.2, 0.4, clampf(heat, 0.0, 0.7)))
	ShipRenderer.draw(self, Run.ship.parts, {"flame": throttle if (state == State.FLIGHT and Run.ship.stage_fuel(Run.ship.active_stage()) > 0.0) else 0.0, "active": Run.ship.active_stage(), "chute": chute})
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if not landed and state != State.APPROACH and agl() < 2000.0:
		var v := Vector2(vx, -vy)
		if v.length() > 1.0:
			draw_line(Vector2.ZERO, v.normalized() * minf(v.length(), 80.0), Color(Ui.LAMP_GO, 0.7), 2.0)


func _draw_corridor(view: Vector2) -> void:
	var c := _corridor()
	var origin := Vector2(-view.x * 0.22, -view.y * 0.02)
	var length := minf(view.x, view.y) * 0.38
	var horizon := view.y * 0.42
	draw_rect(Rect2(-view.x, horizon, view.x * 2.0, view.y), Color(body.color.r, body.color.g, body.color.b, 0.35))
	draw_line(Vector2(-view.x, horizon), Vector2(view.x, horizon), Color(body.atmo_color, 0.9), 4.0)
	for angle: float in [c.x, c.y]:
		draw_line(origin, origin + Vector2.from_angle(deg_to_rad(-angle)) * length, Color(Ui.LAMP_GO, 0.55), 2.0)
	var band := PackedVector2Array([origin, origin + Vector2.from_angle(deg_to_rad(-c.x)) * length, origin + Vector2.from_angle(deg_to_rad(-c.y)) * length])
	draw_colored_polygon(band, Color(0.3, 1.0, 0.5, 0.16))
	var inside := gamma >= c.x and gamma <= c.y
	var aim := origin + Vector2.from_angle(deg_to_rad(-gamma)) * length
	draw_line(origin, aim, Ui.IVORY if inside else Ui.LAMP_WARNING, 3.0)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-7, 14), origin + Vector2(7, 14), origin + Vector2(0, -16)]), Color(0.95, 0.97, 1.0))
	draw_string(Ui.sans(), origin + Vector2(length * 0.15, -36), "Plano: rebotas" if gamma > c.y else ("Empinado: calor" if gamma < c.x else "Dentro del corredor"), HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_TEXT, Ui.IVORY if inside else Ui.LAMP_WARNING)
