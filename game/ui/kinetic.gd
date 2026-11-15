class_name Kinetic
extends Object

## Capa cinetica underground: fisicas de resorte tipo motion-dom (stiffness=200, damping=25),
## entradas diagonales a ~13 grados, barrido optico y colapso elastico respetando reduced_motion.

const SPRING_STIFFNESS := 200.0
const SPRING_DAMPING := 25.0
const UNDERGROUND_TILT_RAD := 0.042 ## micro-inclinacion inicial al asentar (~2.4 grados)
const UNDERGROUND_SLIDE := Vector2(-30.0, 16.0) ## eje ~13 grados respecto a la horizontal

static var _sweep_shader: Shader


static func is_reduced() -> bool:
	return Profile.reduced_motion


## Sincroniza pivot_offset al centro (u otro ratio) tras cambios de tamano sin deformar bordes.
static func sync_pivot(control: Control, ratio: Vector2 = Vector2(0.5, 0.5)) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.set_meta("_kinetic_pivot_ratio", ratio)
	var id := control.get_instance_id()
	_update_pivot(id)
	if not control.has_meta("_kinetic_pivot_bound"):
		control.set_meta("_kinetic_pivot_bound", true)
		var cb := Callable(Kinetic, &"_update_pivot").bind(id)
		control.resized.connect(cb)
		cb.call_deferred()


static func _update_pivot(id: int) -> void:
	var obj := instance_from_id(id)
	if obj is Control and is_instance_valid(obj):
		var c := obj as Control
		var r: Vector2 = c.get_meta("_kinetic_pivot_ratio", Vector2(0.5, 0.5))
		c.pivot_offset = c.size * r


## Integrador de resorte amortiguado de segundo orden: devuelve Vector2(valor, velocidad).
static func spring_step(value: float, velocity: float, target: float, dt: float, stiffness: float = SPRING_STIFFNESS, damping: float = SPRING_DAMPING) -> Vector2:
	if is_reduced() or dt <= 0.0:
		return Vector2(target, 0.0)
	var step_dt := minf(dt, 0.033)
	var disp := value - target
	var accel := -stiffness * disp - damping * velocity
	velocity += accel * step_dt
	value += velocity * step_dt
	if absf(value - target) < 0.0005 and absf(velocity) < 0.001:
		return Vector2(target, 0.0)
	return Vector2(value, velocity)


static func _kill_tween(control: Control, slot: String = "_kinetic_tween") -> void:
	if control != null and is_instance_valid(control) and control.has_meta(slot):
		var old: Variant = control.get_meta(slot)
		if old is Tween and is_instance_valid(old):
			(old as Tween).kill()


## Entrada underground: escala, micro-inclinacion, fade y deslizamiento opcional (para nodos fuera de BoxContainer).
static func enter(control: Control, delay: float = 0.0, opts: Dictionary = {}) -> void:
	if control == null or not is_instance_valid(control):
		return
	_kill_tween(control)
	sync_pivot(control)
	if is_reduced():
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		control.rotation = 0.0
		return
	var duration := float(opts.get("duration", 0.34))
	var start_scale: Vector2 = opts.get("scale", Vector2(0.92, 0.88))
	var tilt := float(opts.get("tilt", -UNDERGROUND_TILT_RAD))
	var elastic := bool(opts.get("elastic", false))
	var slide := bool(opts.get("slide", false))
	var slide_vec: Vector2 = opts.get("slide_offset", UNDERGROUND_SLIDE)
	var beam := bool(opts.get("beam", false))

	var target_pos := control.position
	if opts.has("target_pos"):
		target_pos = Vector2(opts.target_pos)
	elif control.has_meta("_kinetic_rest_pos"):
		target_pos = Vector2(control.get_meta("_kinetic_rest_pos"))
	else:
		control.set_meta("_kinetic_rest_pos", target_pos)

	control.modulate.a = 0.0
	control.scale = start_scale
	control.rotation = tilt
	# Mover por position fija los offsets con el tamano de ese instante: un panel anclado que aun
	# no tenia su tamano final quedaba deformado (el taller perdia el boton Despegar). Se restauran al llegar.
	var home := PackedFloat32Array()
	if slide:
		if target_pos.is_equal_approx(control.position):
			home = [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom]
		control.position = target_pos + slide_vec

	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	control.set_meta("_kinetic_tween", tween)
	var trans := Tween.TRANS_BACK if elastic else Tween.TRANS_EXPO
	tween.tween_property(control, "modulate:a", 1.0, minf(duration * 0.65, 0.20)).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(trans).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "rotation", 0.0, duration).set_delay(delay).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if slide:
		tween.tween_property(control, "position", target_pos, duration).set_delay(delay).set_trans(trans).set_ease(Tween.EASE_OUT)
		if not home.is_empty():
			tween.chain().tween_callback(Callable(Kinetic, &"_restore_offsets").bind(control.get_instance_id(), home))
	if beam:
		var beam_color: Color = opts.get("beam_color", Color(0.76, 0.90, 1.0, 0.24))
		sweep(control, beam_color, 0.36, delay + 0.03)


static func _restore_offsets(id: int, home: PackedFloat32Array) -> void:
	var control := instance_from_id(id) as Control
	if control != null:
		control.offset_left = home[0]
		control.offset_top = home[1]
		control.offset_right = home[2]
		control.offset_bottom = home[3]


## Programa una entrada underground segura por instance_id para evitar errores si el nodo se libera antes del frame diferido.
static func enter_deferred(control: Control, delay: float = 0.0, opts: Dictionary = {}) -> void:
	if control == null or not is_instance_valid(control):
		return
	Callable(Kinetic, &"_enter_id").call_deferred(control.get_instance_id(), delay, opts)


static func _enter_id(id: int, delay: float, opts: Dictionary) -> void:
	var obj := instance_from_id(id)
	if obj is Control and is_instance_valid(obj):
		var c := obj as Control
		if c.is_inside_tree() and not c.is_queued_for_deletion():
			enter(c, delay, opts)


## Cascada escalonada de elementos en listas/tableros (14-28 ms entre elementos).
static func cascade(controls: Array, step: float = 0.022, max_delay: float = 0.24, opts: Dictionary = {}) -> void:
	for i: int in controls.size():
		var c: Variant = controls[i]
		if c is Control and is_instance_valid(c):
			var local_opts := opts.duplicate()
			if not local_opts.has("tilt"):
				local_opts["tilt"] = -0.022 if i % 2 == 0 else 0.018
			enter(c as Control, minf(i * step, max_delay), local_opts)


## Barrido optico diagonal (-13 deg) que cruza un panel sin bloquear entrada de raton.
static func sweep(control: Control, color: Color = Color(0.75, 0.90, 1.0, 0.24), duration: float = 0.36, delay: float = 0.0) -> void:
	if control == null or not is_instance_valid(control) or is_reduced():
		return
	if _sweep_shader == null:
		_sweep_shader = load("res://game/shaders/optical_sweep.gdshader")
	var beam := ColorRect.new()
	beam.name = "_kinetic_beam"
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.custom_minimum_size = Vector2.ZERO
	beam.color = Color.WHITE
	beam.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _sweep_shader
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("beam_color", color)
	beam.material = mat
	control.add_child(beam)
	var mat_id := mat.get_instance_id()
	var beam_id := beam.get_instance_id()
	var tween := beam.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(Callable(Kinetic, &"_set_sweep").bind(mat_id), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(Kinetic, &"_free_node").bind(beam_id))


static func _set_sweep(v: float, mat_id: int) -> void:
	var obj := instance_from_id(mat_id)
	if obj is ShaderMaterial and is_instance_valid(obj):
		(obj as ShaderMaterial).set_shader_parameter("progress", v)


static func _free_node(node_id: int) -> void:
	var obj := instance_from_id(node_id)
	if obj is Node and is_instance_valid(obj):
		(obj as Node).queue_free()


## Rebote tactil de resorte para pulsos puntuales (agregar pieza, jackpot, cambio de paso).
static func pop(control: Control, boost: Vector2 = Vector2(1.06, 0.94), duration: float = 0.24) -> void:
	if control == null or not is_instance_valid(control) or is_reduced():
		return
	_kill_tween(control, "_kinetic_pop_tween")
	sync_pivot(control)
	control.scale = boost
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	control.set_meta("_kinetic_pop_tween", tween)
	tween.tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Colapso/despliegue elastico para fichas tecnicas, paneles auxiliares y detalles plegables.
static func fold_toggle(control: Control, show: bool, duration: float = 0.24) -> void:
	if control == null or not is_instance_valid(control):
		return
	_kill_tween(control)
	sync_pivot(control, Vector2(0.5, 0.0))
	if is_reduced():
		control.visible = show
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		control.rotation = 0.0
		return
	if not show and not control.visible:
		return
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	control.set_meta("_kinetic_tween", tween)
	if show:
		control.visible = true
		control.modulate.a = 0.0
		control.scale = Vector2(0.95, 0.72)
		control.rotation = -0.02
		tween.tween_property(control, "modulate:a", 1.0, duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "rotation", 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(control, "modulate:a", 0.0, duration * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(control, "scale", Vector2(0.95, 0.72), duration * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(Callable(Kinetic, &"_finish_hide").bind(control.get_instance_id()))


static func _finish_hide(id: int) -> void:
	var obj := instance_from_id(id)
	if obj is Control and is_instance_valid(obj):
		var c := obj as Control
		c.visible = false
		c.modulate.a = 1.0
		c.scale = Vector2.ONE
		c.rotation = 0.0


## Conecta fisica elastica de hover y presion a cualquier boton.
static func bind_button(button: Button, tilt_deg: float = 1.2, hover_scale: float = 1.035) -> void:
	if button == null or not is_instance_valid(button) or button.has_meta("_kinetic_btn"):
		return
	button.set_meta("_kinetic_btn", true)
	button.set_meta("_kinetic_tilt", tilt_deg)
	button.set_meta("_kinetic_scale", hover_scale)
	sync_pivot(button)
	var id := button.get_instance_id()
	button.mouse_entered.connect(Callable(Kinetic, &"_btn_hover").bind(id))
	button.focus_entered.connect(Callable(Kinetic, &"_btn_focus").bind(id))
	button.mouse_exited.connect(Callable(Kinetic, &"_btn_rest").bind(id))
	button.focus_exited.connect(Callable(Kinetic, &"_btn_rest").bind(id))
	button.button_down.connect(Callable(Kinetic, &"_btn_down").bind(id))
	button.button_up.connect(Callable(Kinetic, &"_btn_up").bind(id))


static func _btn_animate(button: Button, target_scale: Vector2, target_rot: float, target_tint: Color, duration: float, trans: Tween.TransitionType) -> void:
	if not is_instance_valid(button):
		return
	_kill_tween(button, "_kinetic_btn_tween")
	if is_reduced():
		button.scale = Vector2.ONE
		button.rotation = 0.0
		button.self_modulate = Color.WHITE
		return
	sync_pivot(button)
	var tw := button.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	button.set_meta("_kinetic_btn_tween", tw)
	tw.tween_property(button, "scale", target_scale, duration).set_trans(trans).set_ease(Tween.EASE_OUT)
	tw.tween_property(button, "rotation", target_rot, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(button, "self_modulate", target_tint, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _btn_hover(id: int) -> void:
	var obj := instance_from_id(id)
	if not (obj is Button and is_instance_valid(obj)):
		return
	var b := obj as Button
	if b.disabled:
		return
	var hs := float(b.get_meta("_kinetic_scale", 1.035))
	var base_tilt := float(b.get_meta("_kinetic_tilt", 1.2))
	var scaled_tilt := base_tilt * clampf(160.0 / maxf(b.size.x, 160.0), 0.22, 1.0)
	_btn_animate(b, Vector2(hs, hs), deg_to_rad(-scaled_tilt), Color(1.08, 1.09, 1.12, 1.0), 0.16, Tween.TRANS_EXPO)


static func _btn_focus(id: int) -> void:
	var obj := instance_from_id(id)
	if not (obj is Button and is_instance_valid(obj)):
		return
	var b := obj as Button
	if b.disabled:
		return
	var hs := lerpf(1.0, float(b.get_meta("_kinetic_scale", 1.035)), 0.6)
	_btn_animate(b, Vector2(hs, hs), 0.0, Color(1.06, 1.07, 1.10, 1.0), 0.16, Tween.TRANS_EXPO)


static func _btn_rest(id: int) -> void:
	var obj := instance_from_id(id)
	if obj is Button and is_instance_valid(obj):
		_btn_animate(obj as Button, Vector2.ONE, 0.0, Color.WHITE, 0.22, Tween.TRANS_BACK)


static func _btn_down(id: int) -> void:
	var obj := instance_from_id(id)
	if not (obj is Button and is_instance_valid(obj)):
		return
	var b := obj as Button
	if not b.disabled:
		_btn_animate(b, Vector2(0.95, 0.92), 0.0, Color(0.94, 0.95, 0.98, 1.0), 0.06, Tween.TRANS_QUAD)


static func _btn_up(id: int) -> void:
	var obj := instance_from_id(id)
	if not (obj is Button and is_instance_valid(obj)):
		return
	var b := obj as Button
	if b.disabled:
		_btn_rest(id)
	elif Rect2(Vector2.ZERO, b.size).has_point(b.get_local_mouse_position()):
		var hs := float(b.get_meta("_kinetic_scale", 1.035))
		var td := float(b.get_meta("_kinetic_tilt", 1.2))
		_btn_animate(b, Vector2(hs, hs), deg_to_rad(-td * 0.6), Color(1.08, 1.09, 1.12, 1.0), 0.22, Tween.TRANS_BACK)
	else:
		_btn_rest(id)
