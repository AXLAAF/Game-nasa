class_name Minigame
extends CanvasLayer

## Minijuegos de encuentro: asteroids (esquivar), drill (timing), dock (acoplar).
## Corren con el arbol pausado y devuelven exito/fallo.

const AREA := Vector2(900, 480)

var mode: StringName = &"asteroids"
var on_done: Callable
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


static func start(game_mode: StringName, callback: Callable) -> void:
	var game := Minigame.new()
	game.mode = game_mode
	game.on_done = callback
	(Engine.get_main_loop() as SceneTree).root.add_child(game)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = Run.rng.randi()
	var root := Ui.root(self, 60)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	root.add_child(_view)
	_zone = _new_zone(0.22)
	if mode == &"dock":
		_ship = Vector2(80, AREA.y * 0.5 + _rng.randf_range(-120, 120))
		_drift = Vector2(0, _rng.randf_range(-30, 30))
	Synth.play(&"whoosh")


func _origin() -> Vector2:
	return (_view.size - AREA) * 0.5


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	match mode:
		&"asteroids":
			_tick_asteroids(delta)
		&"drill":
			_needle = pingpong(_time * (0.9 + _round * 0.45), 1.0)
		&"dock":
			_tick_dock(delta)
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done or mode != &"drill":
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_SPACE:
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
		get_viewport().set_input_as_handled()


func _new_zone(width: float) -> Vector2:
	var zone_start := _rng.randf_range(0.05, 0.95 - width)
	return Vector2(zone_start, zone_start + width)


func _tick_asteroids(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): move.y -= 1
	if Input.is_physical_key_pressed(KEY_S): move.y += 1
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1
	if Input.is_physical_key_pressed(KEY_D): move.x += 1
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
					_finish(false, "El casco no aguanto mas golpes")
					return
	if _time >= 15.0:
		_finish(true, "Cruzaste el campo. Cristales: %d (+%s)" % [_crystals, Ui.money(_crystals * 40)])


func _tick_dock(delta: float) -> void:
	var acc := _drift
	if Input.is_physical_key_pressed(KEY_W): acc.y -= 90
	if Input.is_physical_key_pressed(KEY_S): acc.y += 90
	if Input.is_physical_key_pressed(KEY_D): acc.x += 70
	if Input.is_physical_key_pressed(KEY_A): acc.x -= 70
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
		_finish(false, "Se acabo el tiempo de acople")


func _finish(success: bool, message: String) -> void:
	_done = true
	_msg = message
	_view.queue_redraw()
	Synth.play(&"win" if success else &"lose")
	await get_tree().create_timer(1.3, true).timeout
	queue_free()
	if on_done.is_valid():
		on_done.call(success)


func _draw_view() -> void:
	var o := _origin()
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0, 0, 0, 0.75))
	_view.draw_rect(Rect2(o, AREA), Color(0.02, 0.04, 0.09))
	_view.draw_rect(Rect2(o, AREA), Ui.CYAN, false, 2.0)
	var font := Ui.mono()
	var title := {&"asteroids": "CAMPO DE ASTEROIDES  W/A/S/D", &"drill": "PERFORACION  ESPACIO en la zona verde", &"dock": "ACOPLE  W/S alinear, D avanzar, A frenar"}
	_view.draw_string(font, o + Vector2(0, -12), str(title.get(mode, "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Ui.GOLD)
	match mode:
		&"asteroids":
			_draw_asteroids(o, font)
		&"drill":
			_draw_drill(o, font)
		&"dock":
			_draw_dock(o, font)
	if _done:
		_view.draw_string(font, o + Vector2(0, AREA.y + 34), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ui.TEXT)


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
		_view.draw_colored_polygon(PackedVector2Array([ship + Vector2(16, 0), ship + Vector2(-10, -9), ship + Vector2(-10, 9)]), Ui.CYAN)
		_view.draw_circle(ship + Vector2(-14, 0), 4.0 + randf() * 3.0, Color(2.5, 1.2, 0.3))
	_view.draw_string(font, o + Vector2(12, 24), "Casco %s   Tiempo %d" % ["#".repeat(maxi(_lives, 0)), maxi(15 - int(_time), 0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ui.TEXT)


func _draw_drill(o: Vector2, font: Font) -> void:
	var bar := Rect2(o + Vector2(60, AREA.y * 0.5 - 30), Vector2(AREA.x - 120, 60))
	_view.draw_rect(bar, Color(0.25, 0.12, 0.08))
	_view.draw_rect(Rect2(bar.position.x + bar.size.x * _zone.x, bar.position.y, bar.size.x * (_zone.y - _zone.x), bar.size.y), Color(0.2, 0.9 + _flash, 0.4))
	var x := bar.position.x + bar.size.x * _needle
	_view.draw_line(Vector2(x, bar.position.y - 20), Vector2(x, bar.end.y + 20), Color(2.0, 1.8, 1.0), 4.0)
	_view.draw_string(font, o + Vector2(60, 60), "Ronda %d/3   Limpias %d" % [mini(_round + 1, 3), _hits], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Ui.TEXT)


func _draw_dock(o: Vector2, font: Font) -> void:
	var port := o + Vector2(AREA.x - 60, AREA.y * 0.5)
	_view.draw_rect(Rect2(port + Vector2(0, -60), Vector2(60, 120)), Color(0.4, 0.42, 0.5))
	_view.draw_rect(Rect2(port + Vector2(-8, -16), Vector2(8, 32)), Ui.GREEN)
	_view.draw_dashed_line(Vector2(o.x, port.y), port, Color(0.4, 1, 0.55, 0.3), 2.0, 10.0)
	var ship := o + _ship
	_view.draw_rect(Rect2(ship + Vector2(-24, -10), Vector2(40, 20)), Color(0.8, 0.85, 0.9))
	_view.draw_rect(Rect2(ship + Vector2(16, -5), Vector2(6, 10)), Ui.CYAN)
	var speed := _vel.length()
	_view.draw_string(font, o + Vector2(12, 24), "Velocidad %d  (max 70)   Desvio %d" % [int(speed), int(absf(_ship.y - AREA.y * 0.5))], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ui.RED if speed > 70 else Ui.TEXT)
