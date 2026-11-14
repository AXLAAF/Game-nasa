extends Node

## Sensacion: sacudida por trauma, hitstop, camara lenta, destello y el filtro de pantalla
## que reacciona a los canales vision/light de la nave.

const FLIGHT_PHASES: Array[StringName] = [&"launch", &"space", &"descent"]

var trauma: float = 0.0
var plasma: float = 0.0
var heat: float = 0.0
var damage: float = 0.0
var _noise := FastNoiseLite.new()
var _overlay: ColorRect
var _flash: ColorRect
var _last_ticks: int = 0
var _slow_left: float = 0.0
var _stop_left: float = 0.0
var _slow_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.frequency = 2.5
	# El filtro degrada la ventana (capa 5), no el tablero (capas 10+).
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/fx/screen.gdshader")
	_overlay.material = mat
	layer.add_child(_overlay)
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 100
	add_child(flash_layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	flash_layer.add_child(_flash)
	_last_ticks = Time.get_ticks_msec()
	Events.phase_changed.connect(func(_id: StringName) -> void: reset())


func reset() -> void:
	trauma = 0.0
	plasma = 0.0
	heat = 0.0
	damage = 0.0
	_slow_left = 0.0
	_stop_left = 0.0
	Engine.time_scale = 1.0


func shake(amount: float) -> void:
	if Profile.reduced_motion:
		return
	trauma = minf(trauma + amount, 1.0)


func hit(amount: float) -> void:
	shake(amount)
	damage = minf(damage + amount, 1.0)


func hitstop(duration: float) -> void:
	_stop_left = maxf(_stop_left, duration)


func slowmo(scale: float, duration: float) -> void:
	_slow_scale = scale
	_slow_left = maxf(_slow_left, duration)


func flash(color: Color, strength: float = 0.6) -> void:
	if Profile.reduced_motion:
		return
	_flash.color = Color(color.r, color.g, color.b, strength)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real := minf((now - _last_ticks) / 1000.0, 0.1)
	_last_ticks = now
	trauma = maxf(trauma - real * 0.9, 0.0)
	damage = maxf(damage - real * 1.5, 0.0)
	_flash.color.a = maxf(_flash.color.a - real * 2.5, 0.0)
	if not get_tree().paused:
		if _stop_left > 0.0:
			_stop_left -= real
			Engine.time_scale = 0.03
		elif _slow_left > 0.0:
			_slow_left -= real
			Engine.time_scale = _slow_scale
		else:
			Engine.time_scale = 1.0
	var flying := FLIGHT_PHASES.has(Router.current)
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var t := now / 1000.0 * 40.0
		var power := trauma * trauma * 22.0
		# En vuelo la consola tapa la franja inferior: el centro util de la ventana sube.
		var bias := Vector2(0, Ui.CONSOLE_H * 0.5 / cam.zoom.y) if flying else Vector2.ZERO
		cam.offset = bias + Vector2(_noise.get_noise_1d(t), _noise.get_noise_1d(t + 500.0)) * power
	var mat := _overlay.material as ShaderMaterial
	mat.set_shader_parameter("vision", Run.channel(&"vision") if flying else 1.0)
	mat.set_shader_parameter("light", Run.channel(&"light") if flying else 1.0)
	mat.set_shader_parameter("plasma", plasma)
	mat.set_shader_parameter("heat", heat)
	mat.set_shader_parameter("damage", damage)
