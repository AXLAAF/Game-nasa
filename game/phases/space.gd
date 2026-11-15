extends Node2D

## Vuelo newtoniano entre planetas sobre rieles. La nave arranca en orbita baja de casa.
## Aqui viven los puntos de interes, los peligros del espacio y las apuestas en ruta.

const ROT_SPEED := 2.6
const ARCADE_ACCEL_MULT := 4.5
const ARCADE_MIN_ACCEL := 50.0
const ARCADE_MAX_ACCEL := 110.0
const POI_RADIUS := 40.0
const BELT := Vector2(4400.0, 6800.0) ## cinturón de asteroides, unas 2,2 a 3,4 UA [juego]
const ELECTRONICS: Array[StringName] = [&"computer", &"sensor", &"antenna", &"battery", &"solar"]
const POI_ICON := {&"asteroid": "A", &"derelict": "D", &"signal": "?", &"comet": "C", &"moon": "L", &"relic": "N"}
const RELICS: Array[Dictionary] = [
	{"body": &"luna", "alt": 4.5, "phase": 0.4, "name": "Eagle, Apolo 11", "text": "La etapa de descenso del Eagle sigue en la Base de la Tranquilidad. La NASA la dejó el 20 de julio de 1969."},
	{"body": &"luna", "alt": 4.5, "phase": 2.2, "name": "Rover del Apolo 15", "text": "El vehículo lunar del Apolo 15 sigue en el valle de Hadley. La NASA lo apagó al marcharse, en 1971."},
	{"body": &"marte", "alt": 4.5, "phase": 0.8, "name": "Opportunity", "text": "Opportunity dejó de llamar el 10 de junio de 2018, cubierto por una tormenta de polvo en Meridiani. La NASA no volvió a oírlo."},
	{"body": &"marte", "alt": 4.5, "phase": 2.6, "name": "InSight", "text": "InSight se apagó el 15 de diciembre de 2022: el polvo tapó sus paneles en Elysium. Sigue en el suelo."},
	{"body": &"marte", "alt": 4.5, "phase": 4.4, "name": "Viking 1", "text": "Viking 1 calló el 11 de noviembre de 1982 en Chryse Planitia. El aterrizador de la NASA sigue ahí."},
	{"body": &"mercurio", "alt": 4.5, "phase": 1.1, "name": "Impacto de MESSENGER", "text": "MESSENGER chocó contra Mercurio el 30 de abril de 2015, cerca del cráter Shakespeare. No quedó posado: son restos del impacto."},
	{"body": &"venus", "alt": 4.5, "phase": 3.0, "name": "Pioneer Venus", "text": "En diciembre de 1978 las sondas Pioneer Venus de la NASA llegaron al suelo y callaron en menos de una hora. El calor y la presión las apagaron."},
	{"body": &"titan", "alt": 4.5, "phase": 0.9, "name": "Huygens", "text": "Huygens, de la ESA, viajó en el Cassini de la NASA y se posó en Titán el 14 de enero de 2005. Sigue en ese suelo frío."},
	{"r": 2920.0, "phase": 1.3, "name": "NEAR Shoemaker", "text": "NEAR Shoemaker se posó en el asteroide Eros el 12 de febrero de 2001. La NASA lo dejó ahí al acabar la misión. Eros orbita a unas 1,46 UA."},
]
const PLANET_MIN_PX := 14.0

var bodies: Array[BodyDef] = []
var st: Dictionary = {}
var heading: float = 0.0
var warp_i: int = 1 ## TIME_SCALES[1] = tiempo normal
var zoom: float = 1.0
var target_zoom: float = 1.0
var target: Variant = null ## BodyDef o Dictionary (poi)
var hold: int = 0 ## 0 libre, 1 prograde, -1 retrograde
var nav_assist: bool = false ## alinea el morro al empuje recomendado
var burning: bool = false
var overdrive: float = 0.0
var approach: BodyDef = null
var _nav: Dictionary = {}
var flare_timer: float = 0.0
var flare_warn: float = -1.0
var _pred: Dictionary = {}
var _pred_timer: float = 0.0
var _od_clock: float = 0.0
var _belt_clock: float = 0.0
var _env_clock: float = 0.0
var _wear_clock: float = 0.0
var _rad_clock: float = 0.0
var _stranded_offered: bool = false
var _deadline_warned: bool = false
var _leaving: bool = false
var _event_freeze: bool = false ## la llamarada no cambia el warp; el reloj para solo con la carta
var _belt_rocks: PackedVector3Array = PackedVector3Array()
var _cam: Camera2D
var _stars: Starfield
var _info: Label
var _readouts: Dictionary = {}
var _prompt: Label
var _gauges: Dictionary = {}
var _rescue_button: Button
var _repair_button: Button
var _salvage_button: Button
var _planets: Dictionary = {} ## id de cuerpo -> Planet


func _ready() -> void:
	if Run.contract == null or Run.ship.parts.is_empty():
		Run.debug_setup()
	bodies = Catalog.body_list()
	for body: BodyDef in bodies:
		if not body.is_star:
			var planet := Planet.make(body, body.radius * 2.0)
			planet.show_behind_parent = true
			add_child(planet)
			_planets[body.id] = planet
	_place_ship()
	if Run.pois.is_empty():
		_spawn_pois()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 420:
		_belt_rocks.append(Vector3(rng.randf_range(BELT.x, BELT.y), rng.randf() * TAU, rng.randf_range(0.6, 2.2)))
	flare_timer = Run.rng.randf_range(70.0, 140.0)
	target = Run.target()
	nav_assist = Profile.assist and not Profile.arcade
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_stars = Starfield.new()
	add_child(_stars)
	_stars.set_sky(Color(0.015, 0.022, 0.058), 1.0)
	_build_hud()
	Synth.play(&"chime")
	ShipInterior.spawn(self) ## segundo jugador, si la partida lo pide


func _place_ship() -> void:
	st = Run.space_state
	var back: StringName = st.get("return_body", &"")
	if st.has("pos") and back == &"":
		heading = (st.vel as Vector2).angle() if (st.vel as Vector2).length_squared() > 0.0001 else -PI * 0.5
		return
	var t: float = st.get("t", 0.0)
	var home := Catalog.body(back) if back != &"" else Catalog.home()
	var r := home.radius * 3.0
	var a := Run.rng.randf() * TAU
	var radial := Vector2(cos(a), sin(a))
	var speed := sqrt(home.mu / r) * float(st.get("return_boost", 1.0))
	st.pos = Gravity.body_pos(home, t) + radial * r
	st.vel = Gravity.body_vel(home, t) + (Vector2.ZERO if Profile.arcade else Vector2(-radial.y, radial.x) * speed)
	st.t = t
	st.erase("return_body")
	st.erase("return_boost")
	if not st.has("dv0"):
		st.dv0 = maxf(Run.ship.delta_v(), 1.0)
	heading = -PI * 0.5 if Profile.arcade else Vector2(-radial.y, radial.x).angle()
	zoom = 2.0
	target_zoom = 2.0


func _spawn_pois() -> void:
	var rng := Run.rng
	var id := 0
	var plan: Array = [[&"asteroid", 8, BELT.x + 30.0, BELT.y - 30.0], [&"derelict", 4, 1200.0, 5200.0], [&"signal", 5, 1100.0, 5800.0], [&"comet", 2, 2600.0, 5000.0]]
	for row: Array in plan:
		for i: int in int(row[1]):
			var roll := rng.randf()
			var rarity := 2 if roll < 0.07 else (1 if roll < 0.32 else 0)
			Run.pois.append({
				"id": id, "kind": row[0], "r": rng.randf_range(row[2], row[3]), "phase": rng.randf() * TAU,
				"dir": -1.0 if row[0] == &"comet" else 1.0, "rarity": rarity, "done": false, "scanned": false,
			})
			id += 1
	for body: BodyDef in bodies:
		var parent := Catalog.body(body.parent_id)
		if parent != null and not parent.is_star:
			Run.pois.append({"id": id, "kind": &"moon", "body": body.id, "rarity": 0, "done": false, "scanned": true})
			id += 1
	for relic: Dictionary in RELICS:
		var poi := relic.duplicate()
		poi["id"] = id
		poi["kind"] = &"relic"
		poi["rarity"] = 1
		poi["done"] = false
		poi["scanned"] = false
		if not poi.has("dir"):
			poi["dir"] = 1.0
		Run.pois.append(poi)
		id += 1


func poi_pos(t: float, poi: Dictionary) -> Vector2:
	if poi.kind == &"moon":
		return Gravity.body_pos(Catalog.body(poi.body), t)
	if poi.kind == &"relic" and poi.has("body"):
		var host := Catalog.body(poi.body)
		if host == null:
			return Vector2.ZERO
		var ang := float(poi.phase)
		return Gravity.body_pos(host, t) + Vector2(cos(ang), sin(ang)) * host.radius * float(poi.alt)
	var r: float = poi.r
	var a: float = poi.phase + sqrt(Catalog.star().mu / (r * r * r)) * t * float(poi.dir)
	return Vector2(cos(a), sin(a)) * r


func _poi_known(poi: Dictionary) -> bool:
	return poi.scanned or Run.ship.kind_output(&"sensor") >= 0.7 or Profile.has_lesson("sensors") \
		or (st.pos as Vector2).distance_to(poi_pos(st.t, poi)) < 500.0


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var root := Ui.root(self)
	var row := Ui.console(root)
	for key: Array in [["distance", "Distancia", ""], ["relative", "Vel. relativa", "m/s"], ["deadline", "Plazo", "días"]]:
		_readouts[key[0]] = Ui.readout(row, key[1], key[2], 88.0)
	var well := Ui.well(row)
	well.custom_minimum_size = Vector2(270, 0)
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.clip_contents = true
	_info = Ui.label(well, "", Ui.SIZE_LEGEND, Ui.IVORY)
	_info.add_theme_constant_override("line_spacing", 0)
	var gauges := Ui.console_gauges(row, 2)
	for key: Array in [["dv", "Delta-v", Ui.IVORY], ["battery", "Batería", Ui.LAMP_GO], ["temp", "Temperatura", Ui.LAMP_CAUTION], ["od", "Sobrecarga", Ui.LAMP_WARNING]]:
		_gauges[key[0]] = Ui.console_gauge(gauges, key[1], key[2])
	var buttons := Ui.console_keys(row, 2)
	_repair_button = Ui.compact(Ui.button(buttons, "Reparar (R)", _repair_card))
	Ui.compact(Ui.button(buttons, "Estado (C)", func() -> void: Ui.toggle_status(self)))
	_salvage_button = Ui.compact(Ui.button(buttons, "Instalar (I)", _salvage_card))
	if not Profile.arcade:
		Ui.compact(Ui.button(buttons, "Navegación (N)", _toggle_nav))
	_rescue_button = Ui.compact(Ui.button(buttons, "Pedir rescate", _stranded_card))
	Ui.annunciator(root)
	var ticker := Ticker.new()
	Ui.place(ticker, Ui.TICKER_RECT)
	root.add_child(ticker)
	_prompt = Ui.banner(root, Ui.SIZE_READOUT, 0, false)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_top = -Ui.CONSOLE_H - 70
	_prompt.offset_bottom = -Ui.CONSOLE_H - 70
	_prompt.offset_right = -ShipInterior.panel_width() # centrado en el vuelo que el panel interior no tapa
	Ui.keys(root, "WASD moverse (inercia, sin gravedad)   Mayús sobrecarga   Ctrl fino   1-6 tiempo   Tab objetivo   F escanear   L entrar   rueda zoom" if Profile.arcade else "A/D girar   W empuje   Mayús sobrecarga   Ctrl fino   T/G pro/retro   1-6 tiempo   Tab objetivo   F escanear   L entrar   rueda zoom")


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = minf(target_zoom * 1.2, 12.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = maxf(target_zoom / 1.2, _zoom_floor())
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_pick_target(get_global_mouse_position())
		return
	if Controls.cmd_just(&"cmd_cycle"):
		_cycle_target()
	if not Profile.arcade:
		if Controls.cmd_just(&"cmd_hold_pro"):
			hold = 0 if hold == 1 else 1
		if Controls.cmd_just(&"cmd_hold_retro"):
			hold = 0 if hold == -1 else -1
		if Controls.cmd_just(&"cmd_nav"):
			_toggle_nav()
	if Controls.cmd_just(&"cmd_repair"):
		_repair_card()
	if Controls.cmd_just(&"cmd_status"):
		Ui.toggle_status(self)
	if Controls.cmd_just(&"cmd_salvage"):
		_salvage_card()
	if Controls.cmd_just(&"cmd_scan"):
		_scan_target()
	if Controls.cmd_just(&"cmd_land"):
		_start_descent()
	var next := Controls.warp_choice(Run.TIME_SCALES.size(), warp_i)
	if next != warp_i:
		_set_warp(next)


func _toggle_nav() -> void:
	if Profile.arcade:
		return
	nav_assist = not nav_assist
	if nav_assist:
		hold = 0
	Synth.play(&"beep")
	Events.toast.emit("Navegación asistida %s" % ("ON" if nav_assist else "OFF"), Ui.LAMP_GO if nav_assist else Ui.IVORY_DIM)


func _set_warp(index: int) -> void:
	var cap := _warp_cap()
	if index > cap:
		Synth.play(&"deny")
		Events.toast.emit("Suelta el motor para acelerar el tiempo", Ui.LAMP_CAUTION)
	warp_i = mini(index, cap)


func _warp_cap() -> int:
	if burning:
		return 1 if Profile.arcade else 0
	return Run.TIME_SCALES.size() - 1


func _targets() -> Array:
	var list: Array = []
	if Run.target() != null:
		list.append(Run.target())
	for body: BodyDef in bodies:
		if body != Run.target() and not body.is_star:
			list.append(body)
	for poi: Dictionary in Run.pois:
		if not poi.done and poi.kind != &"moon":
			list.append(poi)
	return list


func _target_pos(t: float, item: Variant) -> Vector2:
	if item is BodyDef:
		return Gravity.body_pos(item, t)
	return poi_pos(t, item)


func _cycle_target() -> void:
	var list := _targets()
	if list.is_empty():
		return
	var index := list.find(target)
	target = list[(index + 1) % list.size()]
	_pred_timer = 0.0
	Synth.play(&"tick")


func _pick_target(world: Vector2) -> void:
	var best: Variant = null
	var best_d := 24.0 / zoom
	for item: Variant in _targets():
		var d := world.distance_to(_target_pos(st.t, item))
		var reach: float = best_d + (item.radius if item is BodyDef else 0.0)
		if d < reach:
			best = item
			best_d = d
	if best != null:
		target = best
		_pred_timer = 0.0
		Synth.play(&"tick")


func _scan_target() -> void:
	if not (target is Dictionary) or target.scanned:
		return
	if (st.pos as Vector2).distance_to(poi_pos(st.t, target)) > 1500.0:
		Events.toast.emit("Fuera de alcance del escaner (1500)", Ui.LAMP_CAUTION)
		return
	if Run.battery < 0.15 * Thermal.battery_capacity(Run.ship):
		Synth.play(&"deny")
		return
	Run.apply({"battery": -0.15})
	target.scanned = true
	Synth.play(&"beep")
	Events.toast.emit("Escaneo: %s %s" % [Ui.RARITY_NAMES[target.rarity], _poi_name(target)], Ui.RARITY[target.rarity])


func _poi_name(poi: Dictionary) -> String:
	if poi.has("name"):
		return String(poi.name)
	match poi.kind:
		&"asteroid": return "asteroide"
		&"derelict": return "nave abandonada"
		&"signal": return "señal"
		&"comet": return "cometa"
	return "luna"


# ---------------------------------------------------------------- simulacion

## Avanza la nave en modo arcade: solo inercia y empuje WASD, sin atraccion gravitatoria.
static func arcade_space_step(state: Dictionary, dt: float, bodies: Array[BodyDef], thrust_acc: Vector2, max_step: float = Gravity.MAX_STEP) -> StringName:
	var steps := maxi(1, ceili(dt / max_step))
	var h := dt / steps
	var pos: Vector2 = state.pos
	var vel: Vector2 = state.vel
	var t: float = state.t
	var hit := &""
	for i: int in steps:
		vel += thrust_acc * h
		pos += vel * h
		t += h
		hit = Gravity.collision(pos, t, bodies)
		if hit != &"":
			break
	state.pos = pos
	state.vel = vel
	state.t = t
	return hit


func _process(delta: float) -> void:
	if _leaving:
		return
	if Run.outcome == &"lost" or Run.outcome == &"stranded":
		_leave(&"debrief", 1.6 if Run.outcome == &"lost" else 0.4)
		return
	zoom = lerpf(zoom, target_zoom, minf(delta * 6.0, 1.0))
	if _event_freeze:
		_update_hud()
		_cam.position = st.pos + ShipInterior.view_shift(zoom)
		_cam.zoom = Vector2(zoom, zoom)
		queue_redraw()
		return
	if Profile.arcade and _wasd_dir() != Vector2.ZERO:
		warp_i = mini(warp_i, 1)
	warp_i = mini(warp_i, _warp_cap())
	var dt := minf(delta, 0.05) * Run.time_scale(warp_i)
	_steer(delta)
	var thrust := _thrust(delta, dt)
	var hit := arcade_space_step(st, dt, bodies, thrust) if Profile.arcade else Gravity.step(st, dt, bodies, thrust)
	if hit != &"":
		_collide(Catalog.body(hit))
		return
	_environment(dt)
	_hazards(dt)
	_check_pois()
	_check_approach()
	if Profile.arcade:
		_pred = {}
	else:
		_pred_timer -= delta
		if _pred_timer <= 0.0:
			_pred_timer = 0.15
			_predict()
	_update_hud()
	_cam.position = st.pos + ShipInterior.view_shift(zoom)
	_cam.zoom = Vector2(zoom, zoom)
	_stars.set_view((st.pos as Vector2) * (0.06 if Profile.arcade else 0.02))
	_place_planets()
	queue_redraw()


## Los planetas son nodos con shader: se colocan aqui y _draw_body solo anade anillos y nombre.
## Por debajo de PLANET_MIN_PX en pantalla no hay grano que mostrar y se dibuja un punto.
func _place_planets() -> void:
	for body: BodyDef in bodies:
		if body.is_star:
			continue
		var planet: Planet = _planets[body.id]
		var on_screen := body.radius * 2.0 * zoom
		planet.visible = on_screen >= PLANET_MIN_PX
		if planet.visible:
			var pos := Gravity.body_pos(body, st.t)
			planet.fit(body.radius * 2.0, on_screen)
			planet.position = pos - planet.size * 0.5
			planet.light_from(-pos)


func _wasd_dir() -> Vector2:
	return Vector2(Controls.steer(), -Controls.throttle_axis())


func _steer(delta: float) -> void:
	var mobility := Run.channel(&"mobility")
	if Profile.arcade:
		_nav = {}
		hold = 0
		var wasd := _wasd_dir()
		if wasd != Vector2.ZERO:
			heading = rotate_toward(heading, wasd.angle(), ROT_SPEED * 6.0 * mobility * delta)
		return
	_nav = _nav_guidance()
	var turn := Controls.steer()
	if turn != 0.0:
		hold = 0
		heading += turn * ROT_SPEED * mobility * delta
	elif nav_assist and not _nav.is_empty() and float(_nav.get("need", 0.0)) > 0.4:
		hold = 0
		heading = rotate_toward(heading, float(_nav.aim), ROT_SPEED * mobility * delta)
	elif hold != 0:
		var frame := Gravity.dominant(st.pos, st.t, bodies)
		var rel: Vector2 = st.vel - Gravity.body_vel(frame, st.t)
		var want := rel.angle() + (PI if hold < 0 else 0.0)
		heading = rotate_toward(heading, want, ROT_SPEED * mobility * delta)


func _nav_guidance() -> Dictionary:
	if target == null:
		return {}
	var tp := _target_pos(st.t, target)
	var tv := Gravity.body_vel(target, st.t) if target is BodyDef else Vector2.ZERO
	var capture: float = (target.radius * 2.6) if target is BodyDef else POI_RADIUS
	return RocketMath.nav_burn(st.pos, st.vel, tp, tv, capture)


func _nav_text() -> String:
	if _nav.is_empty():
		return ""
	var aligned := absf(angle_difference(heading, float(_nav.aim))) < 0.35
	match _nav.phase:
		&"boost":
			return ("Empuja con W: acelera hacia el objetivo" if aligned else "Gira hacia el marcador turquesa y luego W") + ", hasta %d" % int(_nav.v_want)
		&"brake":
			return ("Empuja con W: frena el cierre" if aligned else "Gira hacia el marcador ámbar para frenar") + ", cierre %d" % int(_nav.closing)
		&"capture":
			return "Cerca: baja la velocidad relativa y pulsa L si es un planeta"
		&"coast":
			return "Inercia: espera (cierre %d, falta %d)" % [int(_nav.closing), int(_nav.need)]
	return ""


func _thrust(delta: float, dt: float) -> Vector2:
	var ship := Run.ship
	var fine := 0.15 if Controls.cmd_held(&"cmd_fine") else 1.0
	var wasd := _wasd_dir() if Profile.arcade else Vector2.ZERO
	var throttle := 0.0
	if Profile.arcade:
		if wasd != Vector2.ZERO:
			throttle = fine * minf(wasd.length(), 1.0)
	else:
		var axis := Controls.throttle_axis()
		if axis > 0.0:
			throttle = fine * axis
	var over := throttle > 0.0 and Controls.cmd_held(&"cmd_overdrive")
	if over:
		overdrive = minf(overdrive + delta * 0.3, 1.0)
	else:
		overdrive = maxf(overdrive - delta * 0.15, 0.0)
	while ship.auto_stage():
		pass
	burning = throttle > 0.0 and ship.thrust() > 0.0 and ship.stage_fuel(ship.active_stage()) > 0.0
	Synth.engine_level = throttle * (1.4 if over else 1.0) if burning else 0.0
	if not burning:
		return Vector2.ZERO
	var mult := Run.channel(&"thrust") * (1.5 if over else 1.0)
	var acc := ship.burn(throttle * mult, dt * RocketMath.BURN_COMPRESS, 1.1 if over else 1.0)
	if acc <= 0.0:
		burning = false
		Synth.engine_level = 0.0
		return Vector2.ZERO
	if over:
		_od_clock += delta
		Juice.shake(delta * 0.6)
		if _od_clock > 0.5:
			_od_clock = 0.0
			if overdrive > 0.3 and Run.rng.randf() < overdrive * overdrive * 0.12:
				var engines: Array[ShipPart] = []
				for part: ShipPart in ship.active_stage():
					if part.def.kind == &"engine" and not part.broken:
						engines.append(part)
				if not engines.is_empty():
					var engine: ShipPart = engines[Run.rng.randi_range(0, engines.size() - 1)]
					if Run.admit(engine):
						overdrive = 0.4
						Card.malfunction(engine)
					else:
						Events.toast.emit("El motor tose, pero aguanta", Ui.LAMP_CAUTION)
	var push_dir := wasd.normalized() if Profile.arcade else Vector2.from_angle(heading)
	if Profile.arcade:
		var arcade_acc := clampf(acc * ARCADE_ACCEL_MULT, ARCADE_MIN_ACCEL * throttle, ARCADE_MAX_ACCEL) * (1.4 if over else 1.0)
		return push_dir * arcade_acc
	return push_dir * acc * RocketMath.BURN_COMPRESS * RocketMath.SPACE_SCALE


func _collide(body: BodyDef) -> void:
	if body.landable:
		_start_descent(body)
		return
	Synth.play(&"boom")
	Juice.hit(1.0)
	Fx.burst(self, st.pos, Ui.LAMP_CAUTION, 160, 40.0 / zoom, 1.4)
	if body.is_star:
		Run.destroy("La nave se fundio al caer en %s." % body.display_name)
	else:
		Run.destroy("La presión de %s aplastó la nave." % body.display_name)


func _sun_flux() -> float:
	var pos: Vector2 = st.pos
	for body: BodyDef in bodies:
		if body.is_star:
			continue
		var bp := Gravity.body_pos(body, st.t)
		var away := bp.normalized()
		var d := pos - bp
		var along := d.dot(away)
		if along > 0.0 and (d - away * along).length() < body.radius:
			return 0.0
	return Thermal.flux(pos.length())


func _environment(dt: float) -> void:
	var ship := Run.ship
	var f := _sun_flux()
	var eq := Thermal.equilibrium(f, ship)
	Run.temp = move_toward(Run.temp, eq, dt * 0.012)
	var cap := Thermal.battery_capacity(ship)
	Run.battery = clampf(Run.battery + (Thermal.power_gen(f, ship) - Thermal.power_use(ship)) * dt * 0.01, 0.0, cap)
	Juice.heat = clampf((Run.temp - 0.75) * 2.5, 0.0, 1.0)
	_env_clock += dt
	if _env_clock > 15.0:
		_env_clock = 0.0
		if Run.temp > Thermal.HOT:
			Events.toast.emit("Sobrecalentamiento: la electrónica sufre", Ui.LAMP_WARNING)
			_raise(Run.roll_stress(0.35 + (Run.temp - Thermal.HOT) * 2.0, ELECTRONICS))
		elif Run.temp < Thermal.COLD:
			Events.toast.emit("Congelación: líneas de combustible rígidas", Ui.INFO)
			ship.leak(0.03)
			_raise(Run.roll_stress(0.3 + (Thermal.COLD - Run.temp) * 2.0, [&"tank", &"engine", &"battery"]))
		if f > 2.5:
			_raise(Run.roll_stress(0.3, [&"solar"]))
	_wear_clock += dt
	if _wear_clock > 30.0:
		_wear_clock = 0.0
		Run.wear_all(0.01)


func _hazards(dt: float) -> void:
	var pos: Vector2 = st.pos
	var sensors := Run.ship.kind_output(&"sensor") >= 0.7 and Run.powered()
	flare_timer -= dt
	var warn_time := 25.0 if sensors else 8.0
	if flare_warn < 0.0 and flare_timer <= warn_time:
		flare_warn = flare_timer
		Synth.play(&"alarm")
		Events.toast.emit("Llamarada solar en %d s, escóndete tras un planeta" % int(warn_time), Ui.LAMP_CAUTION)
	if flare_timer <= 0.0:
		flare_warn = -1.0
		flare_timer = Run.rng.randf_range(90.0, 170.0)
		_flare()
	var dist := pos.length()
	if dist > BELT.x and dist < BELT.y:
		_belt_clock += dt
		if _belt_clock > 4.0:
			_belt_clock = 0.0
			var speed := ((st.vel as Vector2) - Vector2(-pos.y, pos.x).normalized() * sqrt(Catalog.star().mu / dist)).length()
			if Run.rng.randf() < 0.22 * clampf(speed / 25.0, 0.5, 2.5):
				_micrometeoroid()
	for body: BodyDef in bodies:
		if not body.hazards.has(&"radiation"):
			continue
		if pos.distance_to(Gravity.body_pos(body, st.t)) < maxf(body.radius * 8.0, 120.0):
			var shield := clampf(Run.ship.sum_stat(&"rad_resist"), 0.0, 0.9)
			Run.mods[&"vision"] = maxf(float(Run.mods.get(&"vision", 0.0)) - dt * 0.004 * (1.0 - shield), -0.5)
			Run.mods[&"map"] = maxf(float(Run.mods.get(&"map", 0.0)) - dt * 0.004 * (1.0 - shield), -0.5)
			_rad_clock += dt
			if _rad_clock > 10.0:
				_rad_clock = 0.0
				Events.toast.emit("Radiación de %s" % body.display_name, Ui.MYSTERY)
				_raise(Run.roll_stress(0.5 * (1.0 - shield), ELECTRONICS))
			break


func _flare() -> void:
	var f := _sun_flux()
	if f <= 0.0:
		Events.toast.emit("La llamarada pasó. A salvo en la sombra.", Ui.LAMP_GO)
		Run.apply({"science": 1})
		Run.win_streak()
		return
	Juice.flash(Ui.LAMP_CAUTION, 0.7)
	Juice.hit(0.5)
	var shield := clampf(Run.ship.sum_stat(&"rad_resist"), 0.0, 0.9)
	var hold_odds := clampf(0.85 - minf(f, 4.0) * 0.12 + shield * 0.5, 0.15, 0.97)
	var choices: Array = [
		_choice("Apagar sistemas", 0.9, {}, {"rand_break": true}, {"battery": -0.4}, "Todo volvió a encender.", "Algo no volvió a encender."),
		_choice("Aguantar", hold_odds, {}, {"rand_break": true, "map": -0.25, "comms": -0.25}, {}, "El blindaje aguanto.", "Circuitos fritos."),
	]
	if Run.ship.has_kind(&"solar"):
		choices.append(_choice("Absorber con los paneles", 0.4, {"battery": 1.0, "science": 2}, {"rand_break": true, "vision": -0.3}, {}, "Batería a tope.", "Los paneles se quemaron."))
	_event_freeze = true
	Card.show_card({
		"title": "Llamarada solar",
		"text": "Una tormenta de protones barre la nave. Flujo solar x%.1f." % f,
		"tone": &"malfunction",
		"choices": choices,
		"scanned": Run.ship.kind_output(&"sensor") >= 0.7 or Profile.has_lesson("odds") or Profile.assist,
	}, func(_ok: bool) -> void: _event_freeze = false)


func _micrometeoroid() -> void:
	Synth.play(&"thud", -2.0, 1.4)
	Juice.hit(0.35)
	Fx.burst(self, st.pos, Color(1.0, 0.8, 0.5), 30, 30.0 / zoom, 0.5)
	var intact: Array[ShipPart] = []
	for part: ShipPart in Run.ship.parts:
		if not part.broken:
			intact.append(part)
	if intact.is_empty():
		return
	var victim: ShipPart = intact[Run.rng.randi_range(0, intact.size() - 1)]
	var shield := clampf(Run.ship.sum_stat(&"rad_resist"), 0.0, 0.9)
	if Run.rng.randf() < victim.fail_chance(0.8 * (1.0 - shield * 0.5)) + 0.08:
		if Run.admit(victim):
			Card.malfunction(victim)
		else:
			Events.toast.emit("Impacto en %s. Aguanto." % victim.def.display_name, Ui.IVORY)
	else:
		Events.toast.emit("Micrometeoroide rebota en %s" % victim.def.display_name, Ui.IVORY_DIM)
		victim.wear = minf(victim.wear + 0.05, 1.0)


func _raise(failed: Array[ShipPart]) -> void:
	for part: ShipPart in failed:
		Card.malfunction(part)


func _check_pois() -> void:
	var pos: Vector2 = st.pos
	for poi: Dictionary in Run.pois:
		if poi.done or poi.kind != &"relic":
			continue
		if pos.distance_to(poi_pos(st.t, poi)) < POI_RADIUS:
			poi.done = true
			_encounter(poi)
			return
	for poi: Dictionary in Run.pois:
		if poi.done or poi.kind == &"relic":
			continue
		var reach := POI_RADIUS
		if poi.kind == &"moon":
			reach = Catalog.body(poi.body).radius * 6.0
		if pos.distance_to(poi_pos(st.t, poi)) < reach:
			poi.done = true
			_encounter(poi)
			return


func _encounter(poi: Dictionary) -> void:
	if poi.kind == &"relic":
		Synth.play(&"chime")
		Juice.slowmo(0.3, 0.4)
		warp_i = 0
		if target is Dictionary and target == poi:
			target = Run.target()
		Card.show_card({
			"title": String(poi.name),
			"text": String(poi.text),
			"tone": &"encounter",
			"rarity": 1,
			"choices": [
				_choice("Fotografiar y registrar", 1.0, {"science": 1}, {}, {}, "Queda en el informe de la misión.", ""),
				_choice("Seguir de largo", 1.0, {}),
			],
			"scanned": true,
		})
		return
	var options := Catalog.encounters_for(poi.kind, poi.rarity)
	if options.is_empty():
		return
	var def: EncounterDef = options[Run.rng.randi_range(0, options.size() - 1)]
	Synth.play(&"jackpot" if poi.rarity == 2 else &"chime")
	Juice.slowmo(0.3, 0.4)
	Juice.flash(Ui.RARITY[poi.rarity], 0.25)
	warp_i = 0
	if target is Dictionary and target == poi:
		target = Run.target()
	Card.show_card({
		"title": def.title,
		"text": def.text,
		"tone": &"encounter",
		"rarity": poi.rarity,
		"choices": def.choices,
		"scanned": poi.scanned or Profile.has_lesson("odds") or Profile.assist,
	})


func _check_approach() -> void:
	approach = null
	for body: BodyDef in bodies:
		if body.landable and (st.pos as Vector2).distance_to(Gravity.body_pos(body, st.t)) < body.radius * 2.6:
			approach = body
			return


func _start_descent(body: BodyDef = approach) -> void:
	if body == null:
		return
	var rel: Vector2 = st.vel - Gravity.body_vel(body, st.t)
	st.entry_body = body.id
	st.entry_excess = rel.length() / RocketMath.SPACE_SCALE
	Run.landed_body = body.id
	Synth.engine_level = 0.0
	Synth.play(&"whoosh")
	_leave(&"descent", 0.0)


func _leave(phase: StringName, wait: float) -> void:
	_leaving = true
	Synth.engine_level = 0.0
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	Router.go(phase)


func _predict() -> void:
	if Profile.arcade:
		_pred = {}
		return
	var map := Run.channel(&"map")
	var frame := Gravity.dominant(st.pos, st.t, bodies)
	var local := not frame.is_star
	var steps := int((300.0 if local else 420.0) * clampf(map, 0.15, 1.0))
	var dt := 0.12 if local else 1.2
	var target_fn := Callable()
	if target != null:
		target_fn = _target_pos.bind(target)
	_pred = Gravity.predict(st.pos, st.vel, st.t, steps, dt, bodies, frame, target_fn, 0.12 if local else 0.6)
	_pred.frame = frame
	_pred.t0 = st.t
	# El ruido viejo crecia con cada punto y la orbita se dibujaba como un rayo.
	var fog := clampf(1.0 - map, 0.0, 1.0)
	if fog > 0.05 and _pred.points.size() > 2:
		var points: PackedVector2Array = _pred.points
		var amp := fog * 6.0
		var last := points.size() - 1
		for i: int in points.size():
			var along := float(i) / float(last)
			var tangent: Vector2 = points[mini(i + 1, last)] - points[maxi(i - 1, 0)]
			if tangent.length_squared() < 0.0001:
				continue
			points[i] += tangent.orthogonal().normalized() * sin(along * TAU * 3.0) * amp * along
		_pred.points = points


# ---------------------------------------------------------------- cartas de la nave

func _choice(label: String, odds: float, win: Dictionary, lose: Dictionary = {}, cost: Dictionary = {}, win_text: String = "", lose_text: String = "") -> ChoiceDef:
	var c := ChoiceDef.new()
	c.label = label
	c.odds = odds
	c.win = win
	c.lose = lose
	c.cost = cost
	c.win_text = win_text
	c.lose_text = lose_text
	return c


func _repair_card() -> void:
	if Card.busy():
		return
	if Run.crew >= 2:
		Events.toast.emit("El tripulante repara en la nave. Tirada penalizada: V / Y", Ui.LAMP_CAUTION)
		return
	var part: ShipPart = null
	for p: ShipPart in Run.ship.parts:
		if p.broken:
			part = p
			break
	if part == null:
		for p: ShipPart in Run.ship.parts:
			if p.wear > 0.15 and (part == null or p.wear > part.wear):
				part = p
	var damaged := false
	for value: Variant in Run.mods.values():
		damaged = damaged or float(value) < 0.0
	if part == null and not damaged:
		Events.toast.emit("Nada que reparar", Ui.IVORY_DIM)
		return
	var choices: Array = []
	if part != null:
		choices.append(_choice("Kit: reparar %s" % part.def.display_name, 1.0, {"fix": true}, {}, {"kits": -1}, "Como nueva."))
		choices.append(_choice("Improvisar con cinta", 0.6, {"fix": true}, {"wear": 0.25, "battery": -0.2}, {}, "Aguanta. De milagro.", "Lo empeoraste."))
	if damaged:
		choices.append(_choice("Kit: recalibrar sensores", 1.0, {"restore": true}, {}, {"kits": -1}, "Sistemas limpios."))
		choices.append(_choice("Reiniciar a lo bruto", 0.5, {"restore": true}, {"rand_break": true}, {}, "Reinicio limpio.", "Algo salto en chispas."))
	choices.append(_choice("Dejarlo así", 1.0, {}))
	Card.show_card({
		"title": "Taller de a bordo",
		"text": ("%s. Estado: %s." % [part.def.display_name, part.health_text()]) if part != null else "Los sensores están degradados.",
		"tone": &"info",
		"part": part,
		"choices": choices,
		"scanned": true,
	})


func _salvage_card() -> void:
	if Card.busy():
		return
	if Run.salvage.is_empty():
		Events.toast.emit("No tienes chatarra para instalar", Ui.IVORY_DIM)
		return
	var part: ShipPart = Run.salvage[0]
	Card.show_card({
		"title": "Instalar chatarra",
		"text": "Una pieza misteriosa: %s. Montarla en pleno vuelo es una apuesta; si sale mal, se pierde y golpea la nave." % part.def.display_name,
		"tone": &"bet",
		"part": part,
		"choices": [
			_choice("Instalar ahora", 0.7, {"install": true}, {"discard": true, "rand_break": true}, {}, "Encaja.", "Se solto y reboto contra el casco."),
			_choice("Guardarla para vender", 1.0, {}),
		],
	})


func _stranded_card() -> void:
	if Card.busy():
		return
	Card.show_card({
		"title": "A la deriva",
		"text": "Tanques secos. La agencia puede enviar un remolque, pero la misión se da por perdida.",
		"tone": &"bet",
		"choices": [
			_choice("Pedir rescate", 1.0, {"rescue": true}),
			_choice("Esperar un carguero de paso", 0.25, {"fuel": 0.15}, {"battery": -0.3}, {}, "Te pasaron combustible.", "Nadie vino."),
			_choice("Seguir intentando", 1.0, {}),
		],
	})


# ---------------------------------------------------------------- HUD y dibujo

func _update_hud() -> void:
	var ship := Run.ship
	var t: float = st.t
	var lines := PackedStringArray()
	lines.append("Día %d, tiempo %s, racha x%.2f" % [int(t), Run.time_label(warp_i), Run.streak_mult()])
	if target != null:
		var tp := _target_pos(t, target)
		var tv := Gravity.body_vel(target, t) if target is BodyDef else Vector2.ZERO
		var label: String = target.display_name if target is BodyDef else _poi_name(target)
		lines.append("Objetivo: %s%s" % [label, " (guiado)" if nav_assist else ""])
		(_readouts.distance as Label).text = "%d" % int((st.pos as Vector2).distance_to(tp))
		(_readouts.relative as Label).text = "%d" % int(((st.vel as Vector2) - tv).length())
		if not _nav.is_empty():
			var phase_name := "inercia"
			match _nav.phase:
				&"boost": phase_name = "acelerar"
				&"brake": phase_name = "frenar"
				&"capture": phase_name = "capturar"
			lines.append("Guiado: %s a %d, falta %d, cierre %d" % [phase_name, int(_nav.v_want), int(_nav.need), int(_nav.closing)])
		if _pred.has("closest_dist") and is_finite(float(_pred.closest_dist)):
			lines.append("Paso más cercano: %d en %d s" % [int(_pred.closest_dist), int(_pred.closest_time)])
	var left := Run.contract.deadline - t
	(_readouts.deadline as Label).text = "%d" % maxi(int(left), 0)
	if left <= 0.0:
		lines.append("Plazo vencido: el pago baja")
	if left < 0.0 and not _deadline_warned:
		_deadline_warned = true
		Events.toast.emit("Plazo vencido: el pago bajará", Ui.LAMP_WARNING)
	var degraded := PackedStringArray()
	for ch: StringName in [&"map", &"vision", &"comms"]:
		if Run.channel(ch) < 0.8:
			degraded.append("%s %d %%" % [{&"map": "mapa", &"vision": "visión", &"comms": "comunicaciones"}[ch], int(Run.channel(ch) * 100.0)])
	if not degraded.is_empty():
		lines.append("Degradado: " + ", ".join(degraded))
	_info.text = "\n".join(lines)
	if target == null:
		(_readouts.distance as Label).text = "-"
		(_readouts.relative as Label).text = "-"
	var dv := ship.delta_v()
	(_gauges.dv as Gauge).set_value(dv / float(st.get("dv0", 1.0)), "%d m/s" % int(dv), dv < 300.0)
	var cap := Thermal.battery_capacity(ship)
	(_gauges.battery as Gauge).set_value(Run.battery / cap, "%d %%" % int(Run.battery / cap * 100.0), Run.battery < cap * 0.15)
	var temp_text := "Caliente" if Run.temp > Thermal.HOT else ("Helado" if Run.temp < Thermal.COLD else "%d %%" % int(Run.temp * 100.0))
	(_gauges.temp as Gauge).set_value(Run.temp / 1.2, temp_text, Run.temp > Thermal.HOT or Run.temp < Thermal.COLD)
	(_gauges.od as Gauge).set_value(overdrive, "%d %%" % int(overdrive * 100.0), overdrive > 0.5)
	# Kits y chatarra van en su tecla; el desgaste por pieza lo dice la matriz de lamparas.
	_repair_button.text = "Reparar (R): %d kits" % Run.kits
	_salvage_button.text = "Instalar (I): %d" % Run.salvage.size()
	var thrust_ok := ship.thrust() > 0.0
	var dry := ship.fuel_total() <= 0.05 or (thrust_ok and dv < 5.0)
	var empty := dry and approach == null
	_rescue_button.visible = empty
	if empty and not _stranded_offered:
		_stranded_offered = true
		_stranded_card()
	if approach != null:
		var rel := ((st.vel as Vector2) - Gravity.body_vel(approach, t)).length() / RocketMath.SPACE_SCALE
		_prompt.text = "Entrar a %s (L), %d m/s relativa" % [approach.display_name, int(rel)]
		_prompt.add_theme_color_override("font_color", Ui.LAMP_GO if approach == Run.target() else Ui.IVORY)
	elif flare_warn >= 0.0:
		_prompt.text = "Llamarada en %d s" % maxi(int(flare_timer), 0)
		_prompt.add_theme_color_override("font_color", Ui.LAMP_CAUTION)
	elif not _nav.is_empty() and (nav_assist or Profile.assist):
		_prompt.text = _nav_text()
		_prompt.add_theme_color_override("font_color", Ui.INFO)
	else:
		_prompt.text = "Manteniendo %s" % ("progrado" if hold == 1 else "retrógrado") if hold != 0 else ""
		_prompt.add_theme_color_override("font_color", Ui.INFO)


## Lo bastante lejos para que, con la nave en la orbita exterior, quepa el sistema entero.
func _zoom_floor() -> float:
	var outer := 0.0
	for body: BodyDef in bodies:
		if body.is_star:
			continue
		var reach := body.orbit_radius + body.radius
		var parent := Catalog.body(body.parent_id)
		if parent != null and not parent.is_star:
			reach += parent.orbit_radius
		outer = maxf(outer, reach)
	if outer <= 1.0:
		return 0.04
	var view := get_viewport_rect().size
	var span := minf(view.x, maxf(view.y - Ui.CONSOLE_H, 1.0))
	return minf(0.04, span / (outer * 4.0 * 1.08))


func _draw() -> void:
	var px := 1.0 / zoom
	var t: float = st.t
	var star := Catalog.star()
	var rot := sqrt(star.mu / pow((BELT.x + BELT.y) * 0.5, 3.0)) * t
	var belt_mid := (BELT.x + BELT.y) * 0.5
	var belt_w := BELT.y - BELT.x
	draw_arc(Vector2.ZERO, belt_mid, 0.0, TAU, 160, Color(0.28, 0.36, 0.55, 0.065), belt_w)
	draw_arc(Vector2.ZERO, belt_mid + belt_w * 0.12, 0.0, TAU, 160, Color(0.55, 0.48, 0.42, 0.045), belt_w * 0.45)
	for rock: Vector3 in _belt_rocks:
		var a := rock.y + rot
		draw_circle(Vector2(cos(a), sin(a)) * rock.x, rock.z * maxf(px, 1.0), Color(0.58, 0.52, 0.46, 0.65))
	for body: BodyDef in bodies:
		if body.is_star:
			continue
		var parent := Catalog.body(body.parent_id)
		var steps := clampi(int(TAU * body.orbit_radius * zoom / 10.0), 48, 180)
		draw_arc(Gravity.body_pos(parent, t), body.orbit_radius, 0.0, TAU, steps, Color(body.color, 0.25), px)
	var flaring := flare_warn >= 0.0 and int(Time.get_ticks_msec() / 200.0) % 2 == 0
	var now_s := Time.get_ticks_msec() * 0.001
	var pulse := 1.0 + 0.08 * sin(now_s * 3.0)
	var mist := Ui.mist_texture()
	var halo_r := star.radius * 5.2 * pulse
	draw_texture_rect(mist, Rect2(-halo_r, -halo_r, halo_r * 2.0, halo_r * 2.0), false, Color(1.4, 0.72, 0.24, 0.22 if not flaring else 0.34))
	for ray: int in 8:
		var ang := ray * TAU / 8.0 + now_s * 0.06
		var dir_r := Vector2.from_angle(ang)
		var perp := dir_r.orthogonal() * (star.radius * 0.38)
		var len_r := star.radius * (4.4 + 1.1 * sin(now_s * 1.3 + float(ray) * 1.7))
		draw_colored_polygon(PackedVector2Array([dir_r * star.radius * 0.7 + perp, dir_r * len_r, dir_r * star.radius * 0.7 - perp]), Color(1.5, 0.85, 0.3, 0.08 if not flaring else 0.16))
	for k: int in 6:
		var frac := float(k) / 5.0
		var ring_r := star.radius * (1.28 + k * 0.68) * pulse
		var ring_col := Color(1.35, 0.68, 0.24, 0.14 if not flaring else 0.24).lerp(Color(1.0, 0.35, 0.1, 0.03), frac)
		draw_circle(Vector2.ZERO, ring_r, ring_col)
	var sun_r := maxf(star.radius, 5.0 * px)
	draw_circle(Vector2.ZERO, sun_r * 1.12, Color(1.85, 1.05, 0.38, 0.85))
	draw_circle(Vector2.ZERO, sun_r, Color(2.2, 1.55, 0.75))
	draw_circle(Vector2.ZERO, sun_r * 0.62, Color(2.5, 2.05, 1.35))
	for body: BodyDef in bodies:
		if not body.is_star:
			_draw_body(body, Gravity.body_pos(body, t), px)
	for poi: Dictionary in Run.pois:
		if not poi.done and poi.kind != &"moon":
			_draw_poi(poi, px)
	if target != null:
		var tp := _target_pos(t, target)
		var r: float = (target.radius * 2.6) if target is BodyDef else POI_RADIUS
		draw_arc(tp, maxf(r, 10.0 * px), 0.0, TAU, 48, Color(Ui.LAMP_GO, 0.75), 1.6 * px)
	_draw_prediction(px)
	_draw_ship(px)


func _draw_body(body: BodyDef, pos: Vector2, px: float) -> void:
	var r := maxf(body.radius, 3.5 * px)
	var atmo := body.atmo_color if body.atmosphere > 0.0 else body.color
	var mist := Ui.mist_texture()
	if body.atmosphere > 0.0:
		var hr := r * 1.55
		draw_texture_rect(mist, Rect2(pos - Vector2(hr, hr), Vector2(hr * 2.0, hr * 2.0)), false, Color(atmo.r * 1.25, atmo.g * 1.25, atmo.b * 1.35, 0.22))
	elif body.hazards.has(&"heat") and body.atmosphere <= 0.0:
		var hr_lava := r * 1.5
		draw_texture_rect(mist, Rect2(pos - Vector2(hr_lava, hr_lava), Vector2(hr_lava * 2.0, hr_lava * 2.0)), false, Color(1.5, 0.55, 0.16, 0.22))
	# De cerca los anillos los pinta el shader de Planet; este arco solo acompana al punto lejano.
	if body.id == &"saturno" and body.radius * 2.0 * zoom < PLANET_MIN_PX:
		draw_set_transform(pos, -0.26, Vector2(2.15, 0.4))
		draw_arc(Vector2.ZERO, body.radius * 1.55, 0.0, TAU, 64, Color(0.93, 0.84, 0.62, 0.55), maxf(2.4 * px, 1.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if body.radius * 2.0 * zoom < PLANET_MIN_PX:
		var hr_dot := r * 2.2
		draw_texture_rect(mist, Rect2(pos - Vector2(hr_dot, hr_dot), Vector2(hr_dot * 2.0, hr_dot * 2.0)), false, Color(atmo.r * 1.35, atmo.g * 1.35, atmo.b * 1.45, 0.3))
		draw_circle(pos, r * 1.05, Color(body.color.r * 1.5, body.color.g * 1.5, body.color.b * 1.5))
	if body.hazards.has(&"radiation"):
		draw_arc(pos, maxf(body.radius * 8.0, 120.0), 0.0, TAU, 64, Color(Ui.MYSTERY, 0.32), 2.0 * px)
	if body.landable:
		draw_arc(pos, body.radius * 2.6, 0.0, TAU, 48, Color(1, 1, 1, 0.12), px)
	var parent := Catalog.body(body.parent_id)
	var separation := pos.distance_to(Gravity.body_pos(parent, st.t)) * zoom if parent != null else 80.0
	if separation >= 18.0:
		_text(pos + Vector2(r * 1.25 + 6.0 * px, -4.0 * px), body.display_name, Ui.IVORY if body == Run.target() else Ui.IVORY_DIM, px)


func _draw_poi(poi: Dictionary, px: float) -> void:
	var pos := poi_pos(st.t, poi)
	var known := _poi_known(poi)
	var color: Color = Ui.RARITY[poi.rarity] if known else Color(0.85, 0.85, 0.9)
	var s := 6.0 * px
	if known and poi.rarity > 0:
		var pulse := 1.0 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(pos, s * 2.2 * pulse, Color(color, 0.18))
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(s, 0), pos + Vector2(0, s), pos + Vector2(-s, 0)]), color)
	_text(pos + Vector2(s + 3.0 * px, -s), POI_ICON[poi.kind] if known else "?", color, px)


func _draw_prediction(px: float) -> void:
	if Profile.arcade or not _pred.has("points"):
		return
	var points: PackedVector2Array = _pred.points
	points = points.duplicate()
	if points.size() < 2:
		return
	var frame: BodyDef = _pred.frame
	var shift := Gravity.body_pos(frame, st.t) - Gravity.body_pos(frame, _pred.t0)
	var colors := PackedColorArray()
	var hit_color := Ui.LAMP_WARNING if _pred.hit != &"" else Ui.INFO
	for i: int in points.size():
		points[i] += shift
		colors.append(Color(hit_color, 0.85 * (1.0 - float(i) / points.size())))
	draw_polyline_colors(points, colors, 1.5 * px)
	if target != null and _pred.has("closest_point") and is_finite(float(_pred.closest_dist)):
		var cp: Vector2 = _pred.closest_point
		draw_arc(cp, 6.0 * px, 0.0, TAU, 16, Ui.IVORY, 1.5 * px)
		_text(cp + Vector2(8.0 * px, 0), "%d" % int(_pred.closest_dist), Ui.IVORY, px)


func _draw_ship(px: float) -> void:
	var pos: Vector2 = st.pos
	var dir := Vector2.from_angle(heading)
	var side := dir.orthogonal()
	var s := 9.0 * px
	if not _nav.is_empty() and float(_nav.get("need", 0.0)) > 0.4:
		var nd: Vector2 = _nav.dir
		var tip := pos + nd * s * 4.2
		var color := Ui.LAMP_CAUTION if _nav.phase == &"brake" else Ui.INFO
		draw_line(pos + nd * s * 1.4, tip, color, 2.2 * px)
		draw_colored_polygon(PackedVector2Array([
			tip, tip - nd * s * 0.9 + nd.orthogonal() * s * 0.45, tip - nd * s * 0.9 - nd.orthogonal() * s * 0.45,
		]), color)
	if burning:
		var flick := 1.0 + randf() * 0.4
		var flame_len := s * (2.0 + overdrive * 2.0) * flick
		draw_line(pos - dir * s * 0.8, pos - dir * (s * 4.5 + flame_len * 1.6), Color(1.2, 2.2, 3.0, 0.28), 2.4 * px)
		draw_colored_polygon(PackedVector2Array([pos - dir * s * 0.6 + side * s * 0.4, pos - dir * (s * 0.6 + flame_len), pos - dir * s * 0.6 - side * s * 0.4]), Color(3.0, 1.6 + overdrive, 0.5, 0.9))
	draw_colored_polygon(PackedVector2Array([pos + dir * s, pos - dir * s * 0.7 + side * s * 0.6, pos - dir * s * 0.4, pos - dir * s * 0.7 - side * s * 0.6]), Color(0.95, 0.97, 1.0))
	var frame := Gravity.dominant(pos, st.t, bodies)
	var rel: Vector2 = st.vel - Gravity.body_vel(frame, st.t)
	if rel.length() > 0.01:
		draw_line(pos + rel.normalized() * s * 1.6, pos + rel.normalized() * s * 2.6, Ui.LAMP_GO, 2.0 * px)


func _text(pos: Vector2, text: String, color: Color, px: float) -> void:
	draw_set_transform(pos, 0.0, Vector2(px, px))
	draw_string(Ui.mono(), Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
