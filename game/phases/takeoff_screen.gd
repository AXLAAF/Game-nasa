class_name TakeoffScreen
extends Control

signal takeoff_completed(aborted: bool, exploded: bool)

var _build: ShipBuildState
var _body: Dictionary = {}
var _metrics: Dictionary = {}
var _sfx: SynthSfx

var _ship: ModularShip25D
var _bg_mat: ShaderMaterial
var _bg_scroll: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _duration: float = 11.0
var _alert_active: bool = false
var _alert_timer: float = 4.0
var _aborted: bool = false
var _finished: bool = false

var _lbl_status: Label
var _pb_alt: ProgressBar
var _pb_maxq: ProgressBar
var _heading_view: _HeadingBandView
var _btn_throttle: Button
var _alert_panel: PanelContainer
var _lbl_alert: Label

var _heading: float = 0.0
var _wind_drift: float = 0.14
var _throttle_low: bool = false
var _steer_btn: float = 0.0


func setup(build: ShipBuildState, body: Dictionary, sfx: SynthSfx) -> void:
	_build = build
	_body = body
	_sfx = sfx
	_metrics = _build.compute_metrics(_body)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if _build != null and _ship != null:
		_ship.apply_build(_build)
		_ship.set_cutaway_open(false)
		_ship.set_thruster_power(1.0)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := load("res://game/shaders/pixel_space_bg.gdshader") as Shader
	if sh != null:
		_bg_mat = ShaderMaterial.new()
		_bg_mat.shader = sh
		bg.material = _bg_mat
	else:
		bg.color = SpaceTheme.COL_VOID
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(560, 0)
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var head_h := HBoxContainer.new()
	head_h.alignment = BoxContainer.ALIGNMENT_CENTER
	head_h.add_theme_constant_override("separation", 10)
	vbox.add_child(head_h)
	head_h.add_child(SpaceTheme.make_nasa_stripe(7.0, 22.0))

	var title := Label.new()
	title.text = "MARGIN ZERO | ASCENSO MAX-Q: MZ-1 LIBERTY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", SpaceTheme.COL_AMBER)
	head_h.add_child(title)

	var guide := Label.new()
	guide.text = "OBJETIVO: Manten el rumbo en la franja verde [A/D] y reduce gases [S] durante el pico Max-Q."
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_color_override("font_color", SpaceTheme.COL_CYAN)
	guide.add_theme_font_size_override("font_size", 12)
	vbox.add_child(guide)

	var ship_box := PanelContainer.new()
	ship_box.custom_minimum_size = Vector2(560, 290)
	vbox.add_child(ship_box)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(540, 270)
	ship_box.add_child(holder)
	_ship = ModularShip25D.new()
	_ship.position = Vector2(270, 135)
	_ship.scale = Vector2(1.0, 1.0)
	holder.add_child(_ship)

	_lbl_status = Label.new()
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SpaceTheme.apply_mono(_lbl_status, 12)
	vbox.add_child(_lbl_status)

	var l1 := Label.new()
	l1.text = "Altitud Orbital (0 -> 115 km):"
	vbox.add_child(l1)
	_pb_alt = ProgressBar.new()
	_pb_alt.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(_pb_alt)

	var l2 := Label.new()
	l2.text = "Presion Dinamica Max-Q / Vibracion Pogo:"
	vbox.add_child(l2)
	_pb_maxq = ProgressBar.new()
	_pb_maxq.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(_pb_maxq)

	var l3 := Label.new()
	l3.text = "Giro Gravitacional (Rumbo vs Viento Lateral):"
	vbox.add_child(l3)
	_heading_view = _HeadingBandView.new()
	_heading_view.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(_heading_view)

	var ctrl_h := HBoxContainer.new()
	ctrl_h.add_theme_constant_override("separation", 6)
	vbox.add_child(ctrl_h)

	var btn_left := Button.new()
	btn_left.text = "<- Rumbo [A]"
	btn_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_left.button_down.connect(func() -> void: _steer_btn = -1.0)
	btn_left.button_up.connect(func() -> void: _steer_btn = 0.0)
	ctrl_h.add_child(btn_left)

	_btn_throttle = Button.new()
	_btn_throttle.text = "[S] Reducir Gases (55%): OFF"
	_btn_throttle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_throttle.pressed.connect(func() -> void:
		_toggle_throttle()
	)
	ctrl_h.add_child(_btn_throttle)

	var btn_right := Button.new()
	btn_right.text = "Rumbo [D] ->"
	btn_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_right.button_down.connect(func() -> void: _steer_btn = 1.0)
	btn_right.button_up.connect(func() -> void: _steer_btn = 0.0)
	ctrl_h.add_child(btn_right)

	_alert_panel = PanelContainer.new()
	_alert_panel.visible = false
	vbox.add_child(_alert_panel)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	_alert_panel.add_child(av)

	_lbl_alert = Label.new()
	_lbl_alert.add_theme_color_override("font_color", SpaceTheme.COL_TERRA)
	SpaceTheme.apply_mono(_lbl_alert, 12)
	av.add_child(_lbl_alert)

	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 8)
	av.add_child(ah)

	var btn_jet := Button.new()
	btn_jet.text = "DESCARTAR CARGA AUXILIAR (-2.2 t)"
	btn_jet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SpaceTheme.style_cta_button(btn_jet, SpaceTheme.COL_AMBER)
	btn_jet.pressed.connect(func() -> void:
		_build.jettison_aux_cargo()
		_metrics = _build.compute_metrics(_body)
		_alert_active = false
		_alert_panel.visible = false
		if _sfx != null:
			_sfx.play_airlock()
	)
	ah.add_child(btn_jet)

	var btn_les := Button.new()
	btn_les.text = "TORRE DE ESCAPE (ABORTAR)"
	btn_les.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SpaceTheme.style_cta_button(btn_les, SpaceTheme.COL_TERRA)
	btn_les.pressed.connect(func() -> void:
		_aborted = true
		_finish_takeoff(true, false)
	)
	ah.add_child(btn_les)


func _toggle_throttle() -> void:
	_throttle_low = not _throttle_low
	if _btn_throttle != null:
		_btn_throttle.text = "[S] Reducir Gases (55%%): %s" % ("ON" if _throttle_low else "OFF")
		_btn_throttle.add_theme_color_override("font_color", SpaceTheme.COL_OK if _throttle_low else SpaceTheme.COL_CREAM)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S:
			_toggle_throttle()


func _process(delta: float) -> void:
	if _finished or _build == null:
		return
	var steer_in := _steer_btn
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer_in -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer_in += 1.0
	steer_in = clampf(steer_in, -1.0, 1.0)

	var thr := 0.55 if _throttle_low else 1.0
	var rate := 0.72 if _throttle_low else 1.0
	_elapsed += delta * rate
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	_pb_alt.value = progress * 100.0

	_wind_drift = sin(_elapsed * 1.1) * 0.24
	_heading = clampf(_heading + (_wind_drift + steer_in * 0.65) * delta, -1.0, 1.0)
	if _heading_view != null:
		_heading_view.heading = _heading
		_heading_view.wind_dir = _wind_drift
		_heading_view.queue_redraw()
	if _ship != null:
		_ship.rotation = _heading * 0.22
		_ship.set_thruster_power(thr)

	# Desplazamiento estelar vertical acelerado en ascenso
	if _bg_mat != null:
		_bg_scroll.y -= (120.0 + progress * 460.0) * delta * rate
		_bg_mat.set_shader_parameter("scroll_offset", _bg_scroll)

	# Curva acampanada de Max-Q centrada en t=5.0 s, modulada por empuje
	var maxq_curve := exp(-pow((progress - 0.45) * 3.8, 2.0))
	var overload := float(_metrics.get("overload", 0.0))
	var eff_q := clampf(maxq_curve * (72.0 + overload * 60.0) * thr, 0.0, 100.0)
	_pb_maxq.value = eff_q

	# Vibracion visual proporcional a Max-Q
	var shake := maxq_curve * (2.5 + overload * 8.0) * thr
	_ship.position = Vector2(270.0 + randf_range(-shake, shake), 135.0 + randf_range(-shake, shake))

	var off_corridor := maxf(absf(_heading) - 0.28, 0.0)
	var maxq_pen := 0.14 if (eff_q > 62.0 and not _throttle_low) else 0.0
	var p_exp := clampf(float(_metrics.get("p_explosion", 0.01)) + off_corridor * 0.35 + maxq_pen - (0.04 if _throttle_low else 0.0), 0.01, 0.92)
	var rumbo_ok := absf(_heading) <= 0.28
	_lbl_status.text = "ALT: %.1f km | GASES: %d%% | RUMBO: %s | P_EXP: %.1f%%" % [
		progress * 115.0, int(round(thr * 100.0)), "EN ZONA" if rumbo_ok else "DESVIADO", p_exp * 100.0
	]

	if _elapsed >= 3.2 and not _alert_active and _build.auxiliary_cargo_attached and (overload > 0.12 or p_exp >= 0.16):
		_alert_active = true
		_alert_panel.visible = true
		if _sfx != null:
			_sfx.play_alarm()

	if _alert_active:
		_alert_timer = maxf(_alert_timer - delta, 0.0)
		_lbl_alert.text = "ALERTA MAX-Q / SOBRECARGA (+%d%%) | VENTANA: %.1f s" % [
			int(round(overload * 100.0)), _alert_timer
		]
		if _alert_timer <= 0.0:
			_alert_active = false
			_alert_panel.visible = false

	if _elapsed >= _duration:
		var exploded := randf() < clampf(p_exp * 0.65, 0.0, 0.85)
		_finish_takeoff(false, exploded)


func _finish_takeoff(aborted: bool, exploded: bool) -> void:
	if _finished:
		return
	_finished = true
	takeoff_completed.emit(aborted, exploded)


class _HeadingBandView extends Control:
	var heading: float = 0.0
	var wind_dir: float = 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), SpaceTheme.COL_RAISED, true)
		var zone_w := size.x * 0.28
		var zone_x := (size.x - zone_w) * 0.5
		draw_rect(Rect2(Vector2(zone_x, 2.0), Vector2(zone_w, size.y - 4.0)), Color(0.18, 0.62, 0.42, 0.38), true)
		draw_rect(Rect2(Vector2(zone_x, 2.0), Vector2(zone_w, size.y - 4.0)), SpaceTheme.COL_OK, false, 1.5)
		draw_rect(Rect2(Vector2.ZERO, size), SpaceTheme.COL_SEAM, false, 1.0)
		var marker_x := clampf((heading * 0.5 + 0.5) * size.x, 8.0, size.x - 8.0)
		var mcol := SpaceTheme.COL_OK if absf(heading) <= 0.28 else SpaceTheme.COL_TERRA
		draw_rect(Rect2(Vector2(marker_x - 4.0, 4.0), Vector2(8.0, size.y - 8.0)), mcol, true)
		var mono := SpaceTheme.mono_font()
		draw_string(mono, Vector2(8.0, size.y - 9.0), "VIENTO %+.2f" % wind_dir, HORIZONTAL_ALIGNMENT_LEFT, 140.0, 11, SpaceTheme.COL_MUTED)
