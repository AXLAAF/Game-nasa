class_name Minigame
extends CanvasLayer

## Minijuegos de encuentro y de reparación. El comandante sigue volando.

const AREA := Vector2(900, 480)
const BOX := Rect2(10, 40, 256, 292)
const PART_GAME := {
	&"engine": &"thrust",
	&"tank": &"valve",
	&"capsule": &"seal",
	&"heatshield": &"tile",
	&"shielding": &"tile",
	&"solar": &"align",
	&"radiator": &"vent",
	&"antenna": &"signal",
	&"parachute": &"fold",
	&"legs": &"gear",
	&"rcs": &"spin",
	&"battery": &"cells",
	&"rtg": &"pellet",
	&"computer": &"reboot",
	&"sensor": &"calibrate",
	&"decoupler": &"bolt",
	&"insulation": &"wrap",
	&"escape": &"arm",
}

var mode: StringName = &"asteroids"
var on_done: Callable
var for_crew: bool = false
var _view: Control
var _time: float = 0.0
var _done: bool = false
var _rng := RandomNumberGenerator.new()
var _msg: String = ""
# asteroids
var _ship := Vector2(120, 240)
var _rocks: Array = []
var _lives: int = 3
var _invuln: float = 0.0
var _spawn: float = 0.0
var _crystals: int = 0
# drill
var _round: int = 0
var _hits: int = 0
var _needle: float = 0.0
var _zone := Vector2(0.4, 0.6)
var _flash: float = 0.0
# dock
var _vel := Vector2.ZERO
var _drift := Vector2.ZERO
var _job: Dictionary = {}
var _pace := 1.0
var _phase := 0.0
var _flip := 1.0


static func for_part(kind: StringName) -> StringName:
	if PART_GAME.has(kind):
		return PART_GAME[kind]
	return &"seal"


static func start(game_mode: StringName, callback: Callable, crew: bool = false) -> void:
	var game := Minigame.new()
	game.mode = game_mode
	game.on_done = callback
	game.for_crew = crew
	(Engine.get_main_loop() as SceneTree).root.add_child(game)


func _ready() -> void:
	add_to_group(&"minigame")
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = Run.rng.randi()
	_pace = _rng.randf_range(0.72, 1.4)
	_phase = _rng.randf() * TAU
	_flip = -1.0 if _rng.randf() < 0.5 else 1.0
	var root := Ui.root(self, 90)
	_view = Control.new()
	_view.draw.connect(_draw_view)
	root.add_child(_view)
	if for_crew:
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_view.pivot_offset = Vector2.ZERO
		_view.clip_contents = true
		var vp := get_viewport().get_visible_rect().size
		if _repair():
			_view.scale = Vector2.ONE
			_view.size = Vector2(276, 368)
			_view.position = Vector2(vp.x - 284.0, 68.0)
			Kinetic.enter(_view, 0.0, {"slide": true, "slide_offset": Vector2(28.0, -6.0), "scale": Vector2(0.92, 0.88), "tilt": -0.024, "beam": true, "beam_color": Color(0.55, 0.85, 1.0, 0.24), "duration": 0.26})
		else:
			_view.custom_minimum_size = AREA
			_view.size = AREA
			_view.scale = Vector2(0.22, 0.22)
			_view.position = Vector2(vp.x - AREA.x * 0.22 - 12.0, 78.0)
			Kinetic.sweep(_view, Color(0.55, 0.88, 1.0, 0.24), 0.28)
			if not Kinetic.is_reduced():
				_view.modulate.a = 0.0
				var tw := _view.create_tween()
				tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				tw.tween_property(_view, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		_view.clip_contents = true
		Kinetic.enter_deferred(_view, 0.0, {"scale": Vector2(0.94, 0.90), "tilt": -0.02, "beam": true, "beam_color": Color(0.55, 0.85, 1.0, 0.22), "duration": 0.28})
	_zone = _new_zone(0.22)
	if mode == &"dock":
		_ship = Vector2(80, AREA.y * 0.5 + _rng.randf_range(-120, 120))
		_drift = Vector2(0, _rng.randf_range(-30, 30))
	if _repair():
		_boot_repair()
	Synth.play(&"whoosh")


func _origin() -> Vector2:
	return (_view.size - AREA) * 0.5


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	if _repair():
		_tick_repair(delta)
		_view.queue_redraw()
		return
	match mode:
		&"asteroids":
			_tick_asteroids(delta)
		&"drill":
			_needle = pingpong(_time * (0.9 + _round * 0.45) * _pace, 1.0)
			if _confirm():
				_drill_tap()
		&"dock":
			_tick_dock(delta)
	_view.queue_redraw()


func _confirm() -> bool:
	if for_crew:
		return Controls.crew_interact_just()
	return Controls.cmd_just(&"cmd_confirm")


func _move() -> Vector2:
	if for_crew:
		return Controls.crew_vector()
	return Vector2(Controls.steer(), -Controls.throttle_axis())


func _drill_tap() -> void:
	var hit := _needle >= _zone.x and _needle <= _zone.y
	if hit:
		_hits += 1
		Synth.play(&"coin")
		_flash = 1.0
	else:
		Synth.play(&"deny")
		Juice.shake(0.3)
	_round += 1
	_zone = _new_zone(0.22 - _round * 0.05)
	if _round >= 3:
		_finish(_hits >= 2, "%d de 3 perforaciones limpias" % _hits)


func _new_zone(width: float) -> Vector2:
	var zone_start := _rng.randf_range(0.05, 0.95 - width)
	return Vector2(zone_start, zone_start + width)


func _tick_asteroids(delta: float) -> void:
	var move := _move()
	_ship += move * Vector2(220, 330) * delta
	_ship = _ship.clamp(Vector2(30, 20), Vector2(AREA.x * 0.5, AREA.y - 20))
	_invuln = maxf(_invuln - delta, 0.0)
	_spawn -= delta
	if _spawn <= 0.0 and _time < 14.0:
		_spawn = maxf(0.55 - _time * 0.025, 0.18)
		var crystal := _rng.randf() < 0.18
		_rocks.append({
			"pos": Vector2(AREA.x + 30, _rng.randf_range(20, AREA.y - 20)),
			"vel": Vector2(-_rng.randf_range(220, 420 + _time * 12.0), _rng.randf_range(-40, 40)),
			"r": 10.0 if crystal else _rng.randf_range(12, 32),
			"crystal": crystal, "spin": _rng.randf() * TAU,
		})
	for rock: Dictionary in _rocks.duplicate():
		rock.pos += rock.vel * delta
		rock.spin += delta * 2.0
		if rock.pos.x < -40:
			_rocks.erase(rock)
			continue
		if rock.pos.distance_to(_ship) < rock.r + 10.0:
			_rocks.erase(rock)
			if rock.crystal:
				_crystals += 1
				Run.earnings += 40
				Synth.play(&"coin")
			elif _invuln <= 0.0:
				_lives -= 1
				_invuln = 1.0
				Synth.play(&"thud")
				Juice.hit(0.5)
				if _lives <= 0:
					_finish(false, "El casco no aguantó más golpes")
					return
	if _time >= 15.0:
		_finish(true, "Cruzaste el campo. Cristales: %d (+%s)" % [_crystals, Ui.money(_crystals * 40)])


func _tick_dock(delta: float) -> void:
	var move := _move()
	var acc := _drift + Vector2(move.x * 70.0, move.y * 90.0)
	_drift = _drift.rotated(delta * 0.7)
	_vel += acc * delta * Run.channel(&"mobility")
	_ship += _vel * delta
	_ship.y = clampf(_ship.y, 10, AREA.y - 10)
	var port := Vector2(AREA.x - 60, AREA.y * 0.5)
	if _ship.x >= port.x - 20:
		var aligned := absf(_ship.y - port.y) < 16.0
		var soft := _vel.length() < 70.0
		if aligned and soft:
			_finish(true, "Acople perfecto a %d m/s" % int(_vel.length()))
		else:
			Juice.hit(0.6)
			_finish(false, "Choque contra el puerto" if not soft else "Desalineado: rebotaste")
	elif _ship.x < 0.0 or _time > 25.0:
		_finish(false, "Se acabó el tiempo de acople")


func _finish(success: bool, message: String) -> void:
	if _done:
		return
	_done = true
	_msg = message
	_view.queue_redraw()
	Synth.play(&"win" if success else &"lose")
	await get_tree().create_timer(1.3, true).timeout
	queue_free()
	if on_done.is_valid():
		on_done.call(success)


func _draw_view() -> void:
	var font := Ui.sans()
	if _repair():
		_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0.02, 0.04, 0.08, 0.94))
		_view.draw_rect(BOX, Color(0.04, 0.06, 0.1))
		_view.draw_rect(BOX, Ui.INFO, false, 2.0)
		_view.draw_string(font, Vector2(10, 22), str(_repair_titles().get(mode, "")), HORIZONTAL_ALIGNMENT_LEFT, 256, Ui.SIZE_LEGEND, Ui.IVORY)
		_draw_repair(font)
		if _done:
			_view.draw_string(font, Vector2(10, 352), _msg, HORIZONTAL_ALIGNMENT_LEFT, 256, Ui.SIZE_LEGEND, Ui.IVORY)
		return
	var o := _origin()
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0, 0, 0, 0.75))
	_view.draw_rect(Rect2(o, AREA), Color(0.02, 0.04, 0.09))
	_view.draw_rect(Rect2(o, AREA), Ui.INFO, false, 2.0)
	var title := {&"asteroids": "Campo de asteroides, W/A/S/D", &"drill": "Perforación, espacio en la zona verde", &"dock": "Acople, W/S alinear, D avanzar, A frenar"}
	_view.draw_string(font, o + Vector2(0, -12), str(title.get(mode, "")), HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_HEAD, Ui.IVORY)
	match mode:
		&"asteroids":
			_draw_asteroids(o, font)
		&"drill":
			_draw_drill(o, font)
		&"dock":
			_draw_dock(o, font)
	if _done:
		_view.draw_string(font, o + Vector2(0, AREA.y + 34), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_TEXT, Ui.IVORY)


func _draw_asteroids(o: Vector2, font: Font) -> void:
	for rock: Dictionary in _rocks:
		var p: Vector2 = o + rock.pos
		if rock.crystal:
			var r: float = rock.r
			_view.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0)]), Color(2.0, 1.6, 0.4))
		else:
			var pts := PackedVector2Array()
			for i: int in 7:
				var a: float = rock.spin + i * TAU / 7.0
				pts.append(p + Vector2(cos(a), sin(a)) * rock.r * (0.75 + 0.25 * sin(i * 2.3)))
			_view.draw_colored_polygon(pts, Color(0.45, 0.4, 0.38))
	var ship := o + _ship
	if _invuln <= 0.0 or int(_time * 12.0) % 2 == 0:
		_view.draw_colored_polygon(PackedVector2Array([ship + Vector2(16, 0), ship + Vector2(-10, -9), ship + Vector2(-10, 9)]), Ui.INFO)
		_view.draw_circle(ship + Vector2(-14, 0), 4.0 + randf() * 3.0, Color(2.5, 1.2, 0.3))
	_view.draw_string(font, o + Vector2(12, 24), "Casco %s   Tiempo %d" % ["#".repeat(maxi(_lives, 0)), maxi(15 - int(_time), 0)], HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_TEXT, Ui.IVORY)


func _draw_drill(o: Vector2, font: Font) -> void:
	var bar := Rect2(o + Vector2(60, AREA.y * 0.5 - 30), Vector2(AREA.x - 120, 60))
	_view.draw_rect(bar, Color(0.25, 0.12, 0.08))
	_view.draw_rect(Rect2(bar.position.x + bar.size.x * _zone.x, bar.position.y, bar.size.x * (_zone.y - _zone.x), bar.size.y), Color(0.2, 0.9 + _flash, 0.4))
	var x := bar.position.x + bar.size.x * _needle
	_view.draw_line(Vector2(x, bar.position.y - 20), Vector2(x, bar.end.y + 20), Color(2.0, 1.8, 1.0), 4.0)
	_view.draw_string(font, o + Vector2(60, 60), "Ronda %d/3   Limpias %d" % [mini(_round + 1, 3), _hits], HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_HEAD, Ui.IVORY)


func _draw_dock(o: Vector2, font: Font) -> void:
	var port := o + Vector2(AREA.x - 60, AREA.y * 0.5)
	_view.draw_rect(Rect2(port + Vector2(0, -60), Vector2(60, 120)), Color(0.4, 0.42, 0.5))
	_view.draw_rect(Rect2(port + Vector2(-8, -16), Vector2(8, 32)), Ui.LAMP_GO)
	_view.draw_dashed_line(Vector2(o.x, port.y), port, Color(0.4, 1, 0.55, 0.3), 2.0, 10.0)
	var ship := o + _ship
	_view.draw_rect(Rect2(ship + Vector2(-24, -10), Vector2(40, 20)), Color(0.8, 0.85, 0.9))
	_view.draw_rect(Rect2(ship + Vector2(16, -5), Vector2(6, 10)), Ui.INFO)
	var speed := _vel.length()
	_view.draw_string(font, o + Vector2(12, 24), "Velocidad %d (máx. 70)   Desvío %d" % [int(speed), int(absf(_ship.y - AREA.y * 0.5))], HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_TEXT, Ui.LAMP_WARNING if speed > 70 else Ui.IVORY)


func _osc(speed: float) -> float:
	return sin(_time * speed * _pace + _phase)


func _repair() -> bool:
	return mode != &"asteroids" and mode != &"drill" and mode != &"dock"


func _repair_titles() -> Dictionary:
	return {
		&"thrust": "Motor: llama en la banda",
		&"valve": "Tanque: cierra la fuga",
		&"seal": "Cápsula: sella la escotilla",
		&"tile": "Casco: asienta la loseta",
		&"align": "Panel: apunta al sol",
		&"vent": "Radiador: purga en verde",
		&"signal": "Antena: sostén el enlace",
		&"fold": "Paracaídas: pliega en la marca",
		&"gear": "Patas: extiende y confirma",
		&"spin": "RCS: anula el giro",
		&"cells": "Batería: conecta la celda",
		&"pellet": "RTG: abrazadera en el zócalo",
		&"reboot": "Computadora: repite",
		&"calibrate": "Sensores: centra y fija",
		&"bolt": "Desacoplador: corta el perno",
		&"wrap": "Aislante: esquinas en orden",
		&"arm": "Escape: carga y dispara",
	}


func _boot_repair() -> void:
	var mid := BOX.get_center()
	match mode:
		&"thrust":
			_job = {"marker": _rng.randf_range(0.2, 0.8), "held": 0.0}
		&"valve":
			_job = {"x": mid.x, "closed": 0}
		&"seal":
			_job = {"cursor": mid, "pressure": 1.0, "done": 0, "hatch": mid}
		&"tile":
			_job = {"cursor": mid, "tiles": [], "got": 0, "miss": 0, "spawn": 0.4}
		&"align":
			_job = {"sun": _rng.randf_range(0.15, 0.85), "held": 0.0, "locks": 0}
		&"vent":
			_job = {"temp": 0.15, "good": 0, "strikes": 0}
		&"signal":
			_job = {"cursor": mid, "lock": 0.0}
		&"fold":
			_job = {"folds": 0, "strikes": 0, "slot": _rng.randf_range(0.18, 0.72)}
		&"gear":
			_job = {"ext": 0.0, "legs": 0, "target": _rng.randf_range(0.35, 0.82), "strikes": 0}
		&"spin":
			_job = {"rate": _rng.randf_range(0.9, 2.2) * _flip, "locks": 0, "strikes": 0}
		&"cells":
			_job = {"cursor": mid, "lit": 0, "left": 3.2}
		&"pellet":
			_job = {"socket": _rng.randf_range(0.2, 0.8), "clamps": 0, "strikes": 0}
		&"reboot":
			_job = {"seq": [_rng.randi() % 4, _rng.randi() % 4, _rng.randi() % 4], "step": 0, "show": 1.7, "armed": false}
		&"calibrate":
			_job = {"fix": Vector2.ZERO, "locks": 0}
		&"bolt":
			_job = {"x": mid.x, "step": 0, "strikes": 0}
		&"wrap":
			_job = {"cursor": mid, "step": 0}
		&"arm":
			_job = {"charge": 0.0}
		_:
			_job = {}


func _tick_repair(delta: float) -> void:
	match mode:
		&"thrust":
			_tick_thrust(delta)
		&"valve":
			_tick_valve(delta)
		&"seal":
			_tick_seal(delta)
		&"tile":
			_tick_tile(delta)
		&"align":
			_tick_align(delta)
		&"vent":
			_tick_vent(delta)
		&"signal":
			_tick_signal(delta)
		&"fold":
			_tick_fold(delta)
		&"gear":
			_tick_gear(delta)
		&"spin":
			_tick_spin(delta)
		&"cells":
			_tick_cells(delta)
		&"pellet":
			_tick_pellet(delta)
		&"reboot":
			_tick_reboot(delta)
		&"calibrate":
			_tick_calibrate(delta)
		&"bolt":
			_tick_bolt(delta)
		&"wrap":
			_tick_wrap(delta)
		&"arm":
			_tick_arm(delta)
		_:
			_finish(false, "No hay procedimiento para esta pieza")


func _pressed() -> bool:
	if _time < 0.35:
		return false
	if float(_job.get("lock_t", 0.0)) > _time:
		return false
	if not _confirm():
		return false
	_job.lock_t = _time + 0.4
	return true


func _steer_cursor(delta: float) -> Vector2:
	var c: Vector2 = _job.cursor
	c += _move() * 240.0 * delta
	c.x = clampf(c.x, BOX.position.x + 10.0, BOX.end.x - 10.0)
	c.y = clampf(c.y, BOX.position.y + 10.0, BOX.end.y - 10.0)
	_job.cursor = c
	return c


func _tick_thrust(delta: float) -> void:
	var marker := clampf(float(_job.marker) - _move().y * delta * 0.85, 0.08, 0.92)
	_job.marker = marker
	var band := 0.5 + _osc(1.7) * 0.26
	_job.band = band
	if absf(marker - band) < 0.09:
		_job.held = float(_job.held) + delta
	if float(_job.held) >= 3.0:
		_finish(true, "La cámara aguanta el régimen")
	elif _time > 10.0:
		_finish(false, "El motor no entró en régimen")


func _tick_valve(delta: float) -> void:
	var leak := BOX.position.x + 24.0 + (0.5 + 0.42 * _osc(2.1 + float(_job.closed) * 0.15)) * (BOX.size.x - 48.0)
	var x := clampf(float(_job.x) + _move().x * 220.0 * delta, BOX.position.x + 12.0, BOX.end.x - 12.0)
	_job.x = x
	_job.leak = leak
	if _pressed() and absf(x - leak) < 20.0:
		_job.closed = int(_job.closed) + 1
		if int(_job.closed) >= 3:
			_finish(true, "El tanque deja de perder propelente")
	elif _time > 12.0:
		_finish(false, "El propelente sigue escapando")


func _tick_seal(delta: float) -> void:
	var pressure := float(_job.pressure) - delta * 0.11 * _pace
	var cursor := _steer_cursor(delta)
	var hatch: Vector2 = _job.hatch
	if _pressed() and cursor.distance_to(hatch) < 24.0:
		pressure += 0.38
		_job.done = int(_job.done) + 1
		_job.hatch = Vector2(_rng.randf_range(BOX.position.x + 28.0, BOX.end.x - 28.0), _rng.randf_range(BOX.position.y + 28.0, BOX.end.y - 28.0))
		if int(_job.done) >= 3:
			_finish(true, "La cabina recupera presión")
			return
	_job.pressure = pressure
	if pressure <= 0.0:
		_finish(false, "La cabina se quedó sin aire")


func _tick_tile(delta: float) -> void:
	_job.spawn = float(_job.spawn) - delta
	var tiles: Array = _job.tiles
	if float(_job.spawn) <= 0.0 and int(_job.got) < 4:
		_job.spawn = 0.95
		tiles.append({"x": _rng.randf_range(BOX.position.x + 24.0, BOX.end.x - 24.0), "y": BOX.position.y + 16.0})
	var cursor := _steer_cursor(delta)
	if _pressed():
		for tile: Dictionary in tiles:
			if cursor.distance_to(Vector2(float(tile.x), float(tile.y))) < 26.0:
				tiles.erase(tile)
				_job.got = int(_job.got) + 1
				break
	for tile: Dictionary in tiles.duplicate():
		tile.y = float(tile.y) + 78.0 * _pace * delta
		if float(tile.y) > BOX.end.y:
			tiles.erase(tile)
			_job.miss = int(_job.miss) + 1
	if int(_job.got) >= 4:
		_finish(true, "El escudo vuelve a ser continuo")
	elif int(_job.miss) >= 3:
		_finish(false, "Las losetas se perdieron")


func _tick_align(delta: float) -> void:
	var aim := clampf(0.5 + _move().x * 0.48, 0.04, 0.96)
	_job.aim = aim
	if absf(aim - float(_job.sun)) < 0.08:
		_job.held = float(_job.held) + delta
	else:
		_job.held = 0.0
	if float(_job.held) >= 1.15:
		_job.locks = int(_job.locks) + 1
		_job.held = 0.0
		_job.sun = _rng.randf_range(0.15, 0.85)
		if int(_job.locks) >= 2:
			_finish(true, "El panel ve el sol de frente")
	elif _time > 12.0:
		_finish(false, "El panel sigue de canto")


func _tick_vent(delta: float) -> void:
	var temp := clampf(float(_job.temp) + delta * 0.22 * _pace, 0.0, 1.2)
	if _pressed():
		if temp > 0.34 and temp < 0.62:
			temp -= 0.3
			_job.good = int(_job.good) + 1
		else:
			_job.strikes = int(_job.strikes) + 1
	_job.temp = temp
	if int(_job.good) >= 3:
		_finish(true, "El radiador suelta el calor")
	elif temp >= 1.0 or int(_job.strikes) >= 2:
		_finish(false, "El lazo térmico se pasó")


func _tick_signal(delta: float) -> void:
	var dot := BOX.get_center() + Vector2(_osc(1.3) * 90.0 * _flip, cos(_time * 0.9 * _pace + _phase) * 70.0)
	var cursor := _steer_cursor(delta)
	var lock := float(_job.lock)
	if cursor.distance_to(dot) < 26.0:
		lock += delta
	else:
		lock = maxf(lock - delta * 0.35, 0.0)
	_job.lock = lock
	_job.dot = dot
	if lock >= 2.6:
		_finish(true, "La antena recupera el enlace")
	elif _time > 11.0:
		_finish(false, "Se perdió el enlace")


func _tick_fold(_delta: float) -> void:
	var needle := pingpong(_time * 0.65 * _pace, 1.0)
	_job.needle = needle
	var slot := float(_job.slot)
	if _pressed():
		if needle >= slot and needle <= slot + 0.14:
			_job.folds = int(_job.folds) + 1
			_job.slot = _rng.randf_range(0.15, 0.75)
			if int(_job.folds) >= 4:
				_finish(true, "El paracaídas queda plegado")
		else:
			_job.strikes = int(_job.strikes) + 1
			if int(_job.strikes) >= 3:
				_finish(false, "La tela quedó mal plegada")


func _tick_gear(delta: float) -> void:
	var ext := clampf(float(_job.ext) + _move().y * delta * 0.55, 0.0, 1.0)
	_job.ext = ext
	if _pressed():
		if absf(ext - float(_job.target)) < 0.08:
			_job.legs = int(_job.legs) + 1
			_job.ext = 0.0
			_job.target = 0.4 if int(_job.legs) == 1 else 0.72
			if int(_job.legs) >= 2:
				_finish(true, "Las patas quedan trabadas")
		else:
			_job.strikes = int(_job.strikes) + 1
			if int(_job.strikes) >= 2:
				_finish(false, "La pata no entró en el tope")


func _tick_spin(delta: float) -> void:
	var rate := clampf(float(_job.rate) - _move().x * delta * 2.4, -3.0, 3.0)
	_job.rate = rate
	if _pressed():
		if absf(rate) < 0.22:
			_job.locks = int(_job.locks) + 1
			_job.rate = -1.7 if int(_job.locks) == 1 else rate
			if int(_job.locks) >= 2:
				_finish(true, "El giro está anulado")
		else:
			_job.strikes = int(_job.strikes) + 1
			if int(_job.strikes) >= 2:
				_finish(false, "El pulso de RCS quedó a medias")
	elif _time > 10.0:
		_finish(false, "La nave sigue girando")


func _tick_cells(delta: float) -> void:
	_job.left = float(_job.left) - delta
	var cursor := _steer_cursor(delta)
	var cell := _cell_pos(int(_job.lit))
	if _pressed() and cursor.distance_to(cell) < 28.0:
		_job.lit = int(_job.lit) + 1
		_job.left = 3.2
		if int(_job.lit) >= 3:
			_finish(true, "El banco vuelve a dar tensión")
	elif float(_job.left) <= 0.0:
		_finish(false, "La celda se descargó")


func _tick_pellet(_delta: float) -> void:
	var t := pingpong(_time * 0.7 * _pace, 1.0)
	var x := BOX.position.x + 18.0 + t * (BOX.size.x - 36.0)
	var socket := BOX.position.x + 18.0 + float(_job.socket) * (BOX.size.x - 36.0)
	_job.pellet = x
	if _pressed():
		if absf(x - socket) < 16.0:
			_job.clamps = int(_job.clamps) + 1
			_job.socket = 0.55 if int(_job.clamps) == 1 else 0.78
			if int(_job.clamps) >= 3:
				_finish(true, "El RTG queda sujeto")
		else:
			_job.strikes = int(_job.strikes) + 1
			if int(_job.strikes) >= 2:
				_finish(false, "La abrazadera mordió fuera")


func _tick_reboot(_delta: float) -> void:
	if _time < float(_job.show):
		return
	var code := _flick()
	if code < 0:
		return
	var seq: Array = _job.seq
	if code == int(seq[int(_job.step)]):
		_job.step = int(_job.step) + 1
		if int(_job.step) >= seq.size():
			_finish(true, "La computadora arranca")
	else:
		_finish(false, "La secuencia no coincide")


func _tick_calibrate(delta: float) -> void:
	var drift := Vector2(_osc(1.1 + float(_job.locks)), cos(_time * 0.8 * _pace + _phase)) * (18.0 + float(_job.locks) * 10.0) * _flip
	var fix: Vector2 = _job.fix
	fix += _move() * 70.0 * delta
	fix = fix.limit_length(80.0)
	_job.fix = fix
	var error := drift + fix
	_job.error = error
	if _pressed() and error.length() < 14.0:
		_job.locks = int(_job.locks) + 1
		_job.fix = Vector2.ZERO
		if int(_job.locks) >= 3:
			_finish(true, "El sensor vuelve a cero")
	elif _time > 12.0:
		_finish(false, "El sensor sigue desviado")


func _tick_bolt(delta: float) -> void:
	var x := clampf(float(_job.x) + _move().x * 220.0 * delta, BOX.position.x + 16.0, BOX.end.x - 16.0)
	_job.x = x
	var target := _bolt_x(int(_job.step))
	if _pressed():
		if absf(x - target) < 18.0:
			_job.step = int(_job.step) + 1
			if int(_job.step) >= 3:
				_finish(true, "Los pernos quedan cortados")
		else:
			_job.strikes = int(_job.strikes) + 1
			if int(_job.strikes) >= 2:
				_finish(false, "Cortaste el perno equivocado")


func _tick_wrap(delta: float) -> void:
	var cursor := _steer_cursor(delta)
	var corner := _corner(int(_job.step))
	if _pressed() and cursor.distance_to(corner) < 28.0:
		_job.step = int(_job.step) + 1
		if int(_job.step) >= 4:
			_finish(true, "El aislante cubre el tanque")
	elif _time > 12.0:
		_finish(false, "El aislante quedó suelto")


func _tick_arm(delta: float) -> void:
	var charge := float(_job.charge)
	if _move().y < -0.45:
		charge += delta * 0.42
	else:
		charge = maxf(charge - delta * 0.18, 0.0)
	_job.charge = charge
	if charge > 1.02:
		_finish(false, "La carga se pasó de la ventana")
	elif _pressed():
		if charge >= 0.78 and charge <= 0.94:
			_finish(true, "La torre queda armada")
		else:
			_finish(false, "Disparo fuera de la ventana")
	elif _time > 8.0:
		_finish(false, "La torre no llegó a armarse")


func _flick() -> int:
	var m := _move()
	if bool(_job.get("armed", false)):
		if m.length() < 0.35:
			_job.armed = false
		return -1
	var code := -1
	if absf(m.x) > 0.65 and absf(m.y) < 0.45:
		code = 1 if m.x > 0.0 else 3
	elif absf(m.y) > 0.65 and absf(m.x) < 0.45:
		code = 2 if m.y > 0.0 else 0
	if code >= 0:
		_job.armed = true
	return code


func _cell_pos(index: int) -> Vector2:
	return Vector2(BOX.position.x + 42.0 + float(index) * 86.0, BOX.get_center().y)


func _bolt_x(index: int) -> float:
	return BOX.position.x + 36.0 + float(index) * 92.0


func _corner(index: int) -> Vector2:
	match index % 4:
		1:
			return Vector2(BOX.end.x - 22.0, BOX.position.y + 22.0)
		2:
			return Vector2(BOX.end.x - 22.0, BOX.end.y - 22.0)
		3:
			return Vector2(BOX.position.x + 22.0, BOX.end.y - 22.0)
		_:
			return Vector2(BOX.position.x + 22.0, BOX.position.y + 22.0)


func _draw_repair(font: Font) -> void:
	var mono := Ui.mono()
	match mode:
		&"thrust":
			_bar_v(float(_job.marker), float(_job.get("band", 0.5)), 0.09)
			_note(mono, "En banda %.1f s" % float(_job.held))
		&"valve":
			_hline(float(_job.x), float(_job.get("leak", BOX.get_center().x)))
			_note(mono, "Cierres %d/3" % int(_job.closed))
		&"seal":
			_cursor(font)
			_view.draw_rect(Rect2((_job.hatch as Vector2) - Vector2(14, 14), Vector2(28, 28)), Ui.LAMP_CAUTION, false, 3.0)
			_note(mono, "Presión %d %%" % int(float(_job.pressure) * 100.0))
		&"tile":
			for tile: Dictionary in _job.tiles:
				_view.draw_rect(Rect2(float(tile.x) - 10.0, float(tile.y) - 6.0, 20, 12), Ui.LAMP_WARNING)
			_cursor(font)
			_note(mono, "Losetas %d/4" % int(_job.got))
		&"align":
			_bar_h(float(_job.get("aim", 0.5)), float(_job.sun), 0.08)
			_note(mono, "Fijos %d/2" % int(_job.locks))
		&"vent":
			_thermo(float(_job.temp), 0.34, 0.62)
			_note(mono, "Purgas %d/3" % int(_job.good))
		&"signal":
			var dot: Vector2 = _job.get("dot", BOX.get_center())
			_view.draw_circle(dot, 10.0, Ui.INFO)
			_cursor(font)
			_note(mono, "Enlace %.1f s" % float(_job.lock))
		&"fold":
			_bar_h(float(_job.get("needle", 0.0)), float(_job.slot) + 0.07, 0.07)
			_note(mono, "Pliegues %d/4" % int(_job.folds))
		&"gear":
			_thermo(float(_job.ext), float(_job.target) - 0.08, float(_job.target) + 0.08)
			_note(mono, "Patas %d/2" % int(_job.legs))
		&"spin":
			_note(mono, "Giro %d" % int(float(_job.rate) * 10.0))
			var hub := BOX.get_center()
			_view.draw_line(hub, hub + Vector2.from_angle(float(_job.rate)) * 70.0, Ui.IVORY, 4.0)
		&"cells":
			for i: int in 3:
				var p := _cell_pos(i)
				_view.draw_circle(p, 16.0, Ui.LAMP_GO if i == int(_job.lit) else Color(0.2, 0.22, 0.26))
			_cursor(font)
			_note(mono, "Tiempo %.1f" % maxf(float(_job.left), 0.0))
		&"pellet":
			_hline(float(_job.get("pellet", BOX.position.x)), BOX.position.x + 18.0 + float(_job.socket) * (BOX.size.x - 36.0))
			_note(mono, "Abrazaderas %d/3" % int(_job.clamps))
		&"reboot":
			var seq: Array = _job.seq
			var shown := ""
			if _time < float(_job.show):
				for code: int in seq:
					shown += _dir_name(code) + "  "
			else:
				shown = "Ahora, paso %d" % (int(_job.step) + 1)
			_view.draw_string(font, BOX.position + Vector2(12, 80), shown, HORIZONTAL_ALIGNMENT_LEFT, 230, Ui.SIZE_TEXT, Ui.IVORY)
		&"calibrate":
			var err: Vector2 = _job.get("error", Vector2.ZERO)
			var c := BOX.get_center()
			_view.draw_line(c + Vector2(-18, 0), c + Vector2(18, 0), Ui.IVORY_DIM, 2.0)
			_view.draw_line(c + Vector2(0, -18), c + Vector2(0, 18), Ui.IVORY_DIM, 2.0)
			_view.draw_circle(c + err, 7.0, Ui.LAMP_CAUTION)
			_note(mono, "Fijos %d/3" % int(_job.locks))
		&"bolt":
			for i: int in 3:
				var bx := _bolt_x(i)
				_view.draw_circle(Vector2(bx, BOX.get_center().y), 12.0, Ui.LAMP_WARNING if i == int(_job.step) else Color(0.25, 0.27, 0.3))
			_view.draw_line(Vector2(float(_job.x), BOX.position.y + 8.0), Vector2(float(_job.x), BOX.end.y - 8.0), Ui.IVORY, 3.0)
			_note(mono, "Perno %d/3" % mini(int(_job.step) + 1, 3))
		&"wrap":
			for i: int in 4:
				_view.draw_circle(_corner(i), 10.0, Ui.LAMP_GO if i == int(_job.step) else Color(0.25, 0.27, 0.3))
			_cursor(font)
			_note(mono, "Esquina %d/4" % mini(int(_job.step) + 1, 4))
		&"arm":
			_thermo(float(_job.charge), 0.78, 0.94)
			_note(mono, "Mantén arriba y dispara")


func _bar_v(marker: float, band: float, half: float) -> void:
	var bar := Rect2(BOX.get_center().x - 18.0, BOX.position.y + 16.0, 36.0, BOX.size.y - 48.0)
	_view.draw_rect(bar, Color(0.15, 0.1, 0.08))
	var y0 := bar.position.y + bar.size.y * (1.0 - (band + half))
	var y1 := bar.position.y + bar.size.y * (1.0 - (band - half))
	_view.draw_rect(Rect2(bar.position.x, y0, bar.size.x, y1 - y0), Color(0.25, 0.85, 0.4))
	var y := bar.position.y + bar.size.y * (1.0 - marker)
	_view.draw_line(Vector2(bar.position.x - 10.0, y), Vector2(bar.end.x + 10.0, y), Color(2.0, 1.6, 0.4), 4.0)


func _bar_h(marker: float, band: float, half: float) -> void:
	var bar := Rect2(BOX.position.x + 16.0, BOX.get_center().y - 16.0, BOX.size.x - 32.0, 32.0)
	_view.draw_rect(bar, Color(0.12, 0.14, 0.18))
	_view.draw_rect(Rect2(bar.position.x + bar.size.x * (band - half), bar.position.y, bar.size.x * half * 2.0, bar.size.y), Color(0.25, 0.85, 0.4))
	var x := bar.position.x + bar.size.x * marker
	_view.draw_line(Vector2(x, bar.position.y - 10.0), Vector2(x, bar.end.y + 10.0), Color(2.0, 1.6, 0.4), 4.0)


func _thermo(value: float, lo: float, hi: float) -> void:
	_bar_v(clampf(value, 0.0, 1.0), (lo + hi) * 0.5, maxf(hi - lo, 0.02) * 0.5)


func _hline(marker_x: float, target_x: float) -> void:
	var y := BOX.get_center().y
	_view.draw_line(Vector2(BOX.position.x + 8.0, y), Vector2(BOX.end.x - 8.0, y), Ui.IVORY_DIM, 2.0)
	_view.draw_circle(Vector2(target_x, y), 12.0, Ui.LAMP_WARNING)
	_view.draw_circle(Vector2(marker_x, y), 7.0, Ui.IVORY)


func _cursor(_font: Font) -> void:
	var c: Vector2 = _job.get("cursor", BOX.get_center())
	_view.draw_circle(c, 7.0, Ui.IVORY)


func _note(font: Font, text: String) -> void:
	_view.draw_string(font, Vector2(BOX.position.x, BOX.end.y - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, BOX.size.x, 13, Ui.IVORY)


func _dir_name(code: int) -> String:
	match code:
		0:
			return "arriba"
		1:
			return "derecha"
		2:
			return "abajo"
		_:
			return "izquierda"
