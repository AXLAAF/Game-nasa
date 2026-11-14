class_name TakeoffScreen
extends Control

signal takeoff_completed(aborted: bool, exploded: bool)

var _build: ShipBuildState
var _body: Dictionary = {}
var _metrics: Dictionary = {}
var _sfx: SynthSfx

var _ship: ModularShip25D
var _elapsed: float = 0.0
var _duration: float = 11.0
var _alert_active: bool = false
var _alert_timer: float = 4.0
var _aborted: bool = false
var _finished: bool = false

var _lbl_status: Label
var _pb_alt: ProgressBar
var _pb_maxq: ProgressBar
var _alert_panel: PanelContainer
var _lbl_alert: Label


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
		var mat := ShaderMaterial.new()
		mat.shader = sh
		bg.material = mat
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

	var title := Label.new()
	title.text = "FASE 2: IGNICION Y ASCENSO MAX-Q"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", SpaceTheme.COL_AMBER)
	vbox.add_child(title)

	var ship_box := PanelContainer.new()
	ship_box.custom_minimum_size = Vector2(560, 290)
	vbox.add_child(ship_box)

	var holder := Control.new()
	ship_box.add_child(holder)
	_ship = ModularShip25D.new()
	_ship.position = Vector2(270, 145)
	_ship.scale = Vector2(1.0, 1.0)
	holder.add_child(_ship)

	_lbl_status = Label.new()
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

	_alert_panel = PanelContainer.new()
	_alert_panel.visible = false
	vbox.add_child(_alert_panel)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	_alert_panel.add_child(av)

	_lbl_alert = Label.new()
	_lbl_alert.add_theme_color_override("font_color", SpaceTheme.COL_TERRA)
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


func _process(delta: float) -> void:
	if _finished or _build == null:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	_pb_alt.value = progress * 100.0

	# Curva acampanada de Max-Q centrada en t=5.0 s
	var maxq_curve := exp(-pow((progress - 0.45) * 3.8, 2.0))
	var overload := float(_metrics.get("overload", 0.0))
	_pb_maxq.value = clampf(maxq_curve * (70.0 + overload * 60.0), 0.0, 100.0)

	# Vibracion visual proporcional a Max-Q
	var shake := maxq_curve * (2.5 + overload * 8.0)
	_ship.position = Vector2(270.0 + randf_range(-shake, shake), 145.0 + randf_range(-shake, shake))

	var p_exp := float(_metrics.get("p_explosion", 0.01))
	_lbl_status.text = "Alt: %.1f km | Masa: %.1f t | Riesgo P_exp: %.1f%%" % [
		progress * 115.0, float(_metrics.get("wet_mass_t", 10.0)), p_exp * 100.0
	]

	if _elapsed >= 3.2 and not _alert_active and _build.auxiliary_cargo_attached and (overload > 0.12 or p_exp >= 0.16):
		_alert_active = true
		_alert_panel.visible = true
		if _sfx != null:
			_sfx.play_alarm()

	if _alert_active:
		_alert_timer = maxf(_alert_timer - delta, 0.0)
		_lbl_alert.text = "ALERTA MAX-Q / SOBRECARGA (+%d%%) | Ventana: %.1f s" % [
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
