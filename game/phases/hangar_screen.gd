class_name HangarScreen
extends Control

signal launch_requested(body: Dictionary)
signal mode_toggled(coop_enabled: bool)
signal credits_spent(amount: int)
signal live_nasa_requested

var _loader: NasaDataLoader
var _build: ShipBuildState
var _credits: int = 2200
var _loan_debt: int = 0
var _selected_body_id: String = "moon"
var _selected_socket: StringName = &"port_nacelle"
var _cutaway_open: bool = false
var _coop_mode: bool = false
var _active_tab: int = 0

var _ship_view: ModularShip25D
var _ship_holder: Control
var _lbl_credits: Label
var _lbl_mode: Label
var _lbl_live_status: Label
var _tab_container: VBoxContainer
var _validator_box: VBoxContainer
var _planet_preview: OrbitalMap25D
var _preview_solver: OrbitalSolver
var _btn_insurance: Button
var _lbl_crate_result: Label
var _rng := RandomNumberGenerator.new()


func setup(loader: NasaDataLoader, build: ShipBuildState, credits: int, loan_debt: int, body_id: String, coop: bool) -> void:
	_loader = loader
	_build = build
	_credits = credits
	_loan_debt = loan_debt
	_selected_body_id = body_id
	_coop_mode = coop
	_refresh_all()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_preview_solver = OrbitalSolver.new()
	_build_layout()
	if _build != null:
		_refresh_all()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sp_sh := load("res://game/shaders/pixel_space_bg.gdshader") as Shader
	if sp_sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = sp_sh
		bg.material = mat
	else:
		bg.color = SpaceTheme.COL_VOID
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	# Franja superior (44 px) con banda tricolor retro-NASA (pin_18)
	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 44)
	root_vbox.add_child(top_bar)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_h)

	top_h.add_child(SpaceTheme.make_nasa_stripe(7.0, 22.0))

	var brand := Label.new()
	brand.text = "MARGIN ZERO | DIQUE SECO: MZ-1 LIBERTY"
	brand.add_theme_color_override("font_color", SpaceTheme.COL_CREAM)
	brand.add_theme_font_size_override("font_size", 14)
	top_h.add_child(brand)

	_lbl_credits = Label.new()
	_lbl_credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_credits.add_theme_color_override("font_color", SpaceTheme.COL_AMBER)
	SpaceTheme.apply_mono(_lbl_credits, 13)
	top_h.add_child(_lbl_credits)

	var btn_view := Button.new()
	btn_view.text = "Vista: Casco / FTL"
	btn_view.pressed.connect(func() -> void:
		_cutaway_open = not _cutaway_open
		if _ship_view != null:
			_ship_view.set_cutaway_open(_cutaway_open)
	)
	top_h.add_child(btn_view)

	var btn_coop := Button.new()
	btn_coop.text = "Modo: 1P / 2P"
	btn_coop.pressed.connect(func() -> void:
		_coop_mode = not _coop_mode
		mode_toggled.emit(_coop_mode)
		_refresh_header()
	)
	top_h.add_child(btn_coop)

	_lbl_mode = Label.new()
	top_h.add_child(_lbl_mode)

	var btn_live := Button.new()
	btn_live.text = "Live NASA"
	btn_live.pressed.connect(func() -> void:
		live_nasa_requested.emit()
	)
	top_h.add_child(btn_live)

	_lbl_live_status = Label.new()
	_lbl_live_status.text = "Snapshot OK"
	_lbl_live_status.add_theme_color_override("font_color", SpaceTheme.COL_CYAN)
	SpaceTheme.apply_mono(_lbl_live_status, 11)
	top_h.add_child(_lbl_live_status)

	var guide := Label.new()
	guide.text = "FLUJO: 1. Elige Destino -> 2. Equipa Nave/Instrumentos -> 3. Verifica Semaforo -> 4. Despegar"
	guide.add_theme_color_override("font_color", SpaceTheme.COL_CYAN)
	guide.add_theme_font_size_override("font_size", 12)
	root_vbox.add_child(guide)

	# Cuerpo principal (Izquierda 31%, Centro 41%, Derecha 28%)
	var body_h := HBoxContainer.new()
	body_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_h.add_theme_constant_override("separation", 8)
	root_vbox.add_child(body_h)

	# Panel izquierdo de configuracion por pestañas
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.31
	body_h.add_child(left_panel)

	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_v)

	var tabs_h := HBoxContainer.new()
	tabs_h.add_theme_constant_override("separation", 4)
	left_v.add_child(tabs_h)
	var tab_names := ["1. Contrato", "2. Lanzador", "3. Sockets", "4. Perks"]
	for i: int in range(tab_names.size()):
		var tb := Button.new()
		tb.text = tab_names[i]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		tb.pressed.connect(func() -> void:
			_active_tab = idx
			_rebuild_tab_content()
		)
		tabs_h.add_child(tb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_child(scroll)
	_tab_container = VBoxContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_tab_container)

	# Escena central unica: Fondo Blueprint Rhine Lab + Nave Orbital Mule Mk-I + Vista previa orbital arriba derecha
	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 0.41
	body_h.add_child(center_panel)

	var center_overlay := Control.new()
	center_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_overlay.clip_contents = true
	center_panel.add_child(center_overlay)

	var blueprint := _BlueprintCanvas.new()
	blueprint.set_anchors_preset(Control.PRESET_FULL_RECT)
	blueprint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_overlay.add_child(blueprint)

	_ship_holder = Control.new()
	_ship_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ship_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_overlay.add_child(_ship_holder)

	_ship_view = ModularShip25D.new()
	_ship_view.scale = Vector2(1.45, 1.45)
	_ship_holder.add_child(_ship_view)
	_ship_holder.resized.connect(_center_ship_view)

	_planet_preview = OrbitalMap25D.new()
	_planet_preview.anchor_left = 1.0
	_planet_preview.anchor_right = 1.0
	_planet_preview.anchor_top = 0.0
	_planet_preview.anchor_bottom = 0.0
	_planet_preview.offset_left = -144.0
	_planet_preview.offset_right = -8.0
	_planet_preview.offset_top = 8.0
	_planet_preview.offset_bottom = 144.0
	center_overlay.add_child(_planet_preview)

	# Panel derecho unico: Validadores de Ingenieria y Lanzamiento
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.28
	body_h.add_child(right_panel)

	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_v)

	var r_title := Label.new()
	r_title.text = "VALIDADORES DE INGENIERIA NASA"
	r_title.add_theme_color_override("font_color", SpaceTheme.COL_CYAN)
	r_title.add_theme_font_size_override("font_size", 13)
	right_v.add_child(r_title)

	_validator_box = VBoxContainer.new()
	_validator_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_validator_box.add_theme_constant_override("separation", 6)
	right_v.add_child(_validator_box)

	var risk_h := HBoxContainer.new()
	risk_h.add_theme_constant_override("separation", 6)
	right_v.add_child(risk_h)

	_btn_insurance = Button.new()
	_btn_insurance.text = "Seguro Mision (12%): OFF"
	_btn_insurance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_insurance.pressed.connect(func() -> void:
		if _build == null:
			return
		_build.insured = not _build.insured
		_refresh_validators()
	)
	risk_h.add_child(_btn_insurance)

	var btn_crate := Button.new()
	btn_crate.text = "Caja Desguace ($%d)" % ShipBuildState.CRATE_COST
	btn_crate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_crate.pressed.connect(func() -> void:
		if _build == null:
			return
		var res := _build.roll_scrapyard_crate(_rng, _credits)
		if bool(res["ok"]):
			var spent := int(res["cost"])
			_credits -= spent
			credits_spent.emit(spent)
			var qname := str(ShipBuildState.QUALITY_MULT[res["quality"]]["label"])
			var extra := ""
			if res["bonus_perk"] != &"":
				extra = " + Perk!"
			_lbl_crate_result.text = "Caja: %s -> %s LVL %d%s" % [String(res["socket"]), qname, int(res["level"]), extra]
			_lbl_crate_result.add_theme_color_override("font_color", SpaceTheme.COL_OK)
			_refresh_all()
		else:
			_lbl_crate_result.text = str(res["reason"])
			_lbl_crate_result.add_theme_color_override("font_color", SpaceTheme.COL_TERRA)
	)
	risk_h.add_child(btn_crate)

	_lbl_crate_result = Label.new()
	_lbl_crate_result.text = "Seguro cubre 60% si falla. Caja da calidad aleatoria o perk."
	_lbl_crate_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_crate_result.add_theme_color_override("font_color", SpaceTheme.COL_MUTED)
	_lbl_crate_result.add_theme_font_size_override("font_size", 11)
	right_v.add_child(_lbl_crate_result)

	var btn_launch := Button.new()
	btn_launch.text = "A RAMPA DE LANZAMIENTO"
	SpaceTheme.style_cta_button(btn_launch, SpaceTheme.COL_AMBER)
	btn_launch.pressed.connect(func() -> void:
		var body := _current_body()
		launch_requested.emit(body)
	)
	right_v.add_child(btn_launch)


func _center_ship_view() -> void:
	if _ship_holder != null and _ship_view != null:
		_ship_view.position = (_ship_holder.size * 0.5 + Vector2(0.0, 12.0)).round()


func set_live_status(msg: String) -> void:
	if _lbl_live_status != null:
		_lbl_live_status.text = msg


func _current_body() -> Dictionary:
	if _loader == null:
		return {}
	var b := _loader.get_body(_selected_body_id)
	if b.is_empty():
		var contracts := _loader.get_contracts()
		if not contracts.is_empty():
			return contracts[0]
	return b


func _refresh_all() -> void:
	if _ship_view == null or _build == null or _loader == null:
		return
	_center_ship_view()
	_refresh_header()
	_ship_view.apply_build(_build)
	_ship_view.set_cutaway_open(_cutaway_open)
	var body := _current_body()
	_preview_solver.configure_for_body(body, _build.compute_metrics(body))
	_planet_preview.bind_solver(_preview_solver)
	_rebuild_tab_content()
	_refresh_validators()


func _refresh_header() -> void:
	if _lbl_credits == null or _build == null:
		return
	var debt_txt := (" | DEUDA: $%d" % _loan_debt) if _loan_debt > 0 else ""
	_lbl_credits.text = "SALDO: $%d%s | CASCO LVL %d" % [_credits, debt_txt, _build.hull_level]
	_lbl_mode.text = "2P Local" if _coop_mode else "1P Solo"


func _clear_box(box: Container) -> void:
	for ch: Node in box.get_children():
		ch.queue_free()


func _rebuild_tab_content() -> void:
	if _tab_container == null or _loader == null or _build == null:
		return
	_clear_box(_tab_container)

	if _active_tab == 0:
		_build_contracts_tab()
	elif _active_tab == 1:
		_build_launcher_science_tab()
	elif _active_tab == 2:
		_build_sockets_tab()
	else:
		_build_perks_tab()


func _build_contracts_tab() -> void:
	for c: Dictionary in _loader.get_contracts():
		var cid := str(c.get("id", "moon"))
		var au := float(c.get("semi_major_axis_au", 1.0))
		var sf := NasaDataLoader.solar_factor(au) * 100.0
		var btn := Button.new()
		var mark := "[ACTIVO] " if cid == _selected_body_id else ""
		btn.text = "%s%s\nPago $%d | dV %.0f m/s | Sol %.1f%% | P %.4f bar" % [
			mark, str(c.get("name", cid)), int(c.get("base_payout", 1800)),
			float(c.get("mission_dv_m_s", 4100.0)), sf, float(c.get("surface_pressure_bar", 0.0))
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void:
			_selected_body_id = cid
			_refresh_all()
		)
		_tab_container.add_child(btn)

	var b := _current_body()
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = str(b.get("briefing", "")) + "\nLatencia DSN RTLT: %.2f s" % float(b.get("dsn_rtlt_s", 2.5))
	note.add_theme_color_override("font_color", SpaceTheme.COL_CYAN)
	_tab_container.add_child(note)


func _build_launcher_science_tab() -> void:
	var h1 := Label.new()
	h1.text = "Vehiculo de Lanzamiento (Presupuesto vs Masa):"
	h1.add_theme_color_override("font_color", SpaceTheme.COL_AMBER)
	_tab_container.add_child(h1)

	for lid: StringName in ShipBuildState.LAUNCHERS.keys():
		var linfo: Dictionary = ShipBuildState.LAUNCHERS[lid]
		var btn := Button.new()
		var mark := "[OK] " if lid == _build.launcher_id else ""
		btn.text = "%s%s ($%d | Max %.1f t | +%.0f m/s)" % [
			mark, linfo["name"], int(linfo["cost"]), float(linfo["max_payload_t"]), float(linfo["dv_boost_m_s"])
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void:
			_build.set_launcher(lid)
			_refresh_all()
		)
		_tab_container.add_child(btn)

	var h2 := Label.new()
	h2.text = "Instrumentos Cientificos (Peso + W vs Ciencia + Mbps):"
	h2.add_theme_color_override("font_color", SpaceTheme.COL_CYAN)
	_tab_container.add_child(h2)

	for iid: StringName in ShipBuildState.INSTRUMENTS.keys():
		var inst: Dictionary = ShipBuildState.INSTRUMENTS[iid]
		var on := iid in _build.selected_instruments
		var btn := Button.new()
		btn.text = "%s %s (%.2f t | %.1fW | +$%d | +%d Sci)" % [
			"[ON]" if on else "[  ]", inst["name"], float(inst["mass_t"]),
			float(inst["power_eq"]), int(inst["cost"]), int(inst["science_value"])
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void:
			_build.toggle_instrument(iid)
			_refresh_all()
		)
		_tab_container.add_child(btn)


func _build_sockets_tab() -> void:
	var socket_options := {
		&"bow": [&"bow_shield", &"bow_radar", &"bow_les"],
		&"port_nacelle": [&"nacelle_tank", &"nacelle_rtg", &"nacelle_armor"],
		&"stbd_nacelle": [&"nacelle_tank", &"nacelle_rtg", &"nacelle_armor"],
		&"wing_port": [&"wing_solar", &"wing_radiator"],
		&"wing_stbd": [&"wing_solar", &"wing_radiator"],
		&"dorsal_turret": [&"dorsal_dsn", &"dorsal_arm", &"dorsal_cmg"],
		&"aft_engines": [&"aft_hypergolic", &"aft_cryo", &"aft_ion"],
	}
	var qual_cycle: Array[StringName] = [&"SCRAP", &"USED", &"NEW", &"LEGENDARY"]

	for sk: StringName in ShipBuildState.SOCKET_ORDER:
		var slot: Dictionary = _build.sockets[sk]
		var mod_id: StringName = slot["module"]
		var lvl := int(slot["level"])
		var qual: StringName = slot["quality"]
		var mod_name := str(ShipBuildState.MODULE_CATALOG[mod_id]["name"])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_tab_container.add_child(row)

		var btn_mod := Button.new()
		btn_mod.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_mod.text = "%s\nLVL %d | %s" % [mod_name, lvl, ShipBuildState.QUALITY_MULT[qual]["label"]]
		btn_mod.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_mod.pressed.connect(func() -> void:
			_selected_socket = sk
			var opts: Array = socket_options[sk]
			var idx := opts.find(mod_id)
			var nxt: StringName = opts[(idx + 1) % opts.size()]
			_build.set_socket_module(sk, nxt, qual)
			_refresh_all()
		)
		row.add_child(btn_mod)

		var btn_q := Button.new()
		btn_q.text = "Calidad"
		btn_q.pressed.connect(func() -> void:
			_selected_socket = sk
			var qi := qual_cycle.find(qual)
			var nq: StringName = qual_cycle[(qi + 1) % qual_cycle.size()]
			_build.set_socket_module(sk, mod_id, nq)
			_refresh_all()
		)
		row.add_child(btn_q)

		var upg_cost := 180 * (lvl + 1)
		var btn_up := Button.new()
		btn_up.text = "MAX" if lvl >= 5 else ("+LVL ($%d)" % upg_cost)
		btn_up.disabled = lvl >= 5 or _credits < upg_cost
		btn_up.pressed.connect(func() -> void:
			_selected_socket = sk
			var res := _build.upgrade_socket(sk, _credits)
			if bool(res["ok"]):
				var spent := int(res["cost"])
				_credits -= spent
				credits_spent.emit(spent)
				_refresh_all()
		)
		row.add_child(btn_up)

	# Tarjetas de progresion LVL 1..5 MAX estilo pin_08 para el hardpoint activo
	if _build.sockets.has(_selected_socket):
		var sel_slot: Dictionary = _build.sockets[_selected_socket]
		var sel_mod_id: StringName = sel_slot["module"]
		var sel_name := str(ShipBuildState.MODULE_CATALOG[sel_mod_id]["name"])
		var ladder := _LevelLadderView.new(sel_name, int(sel_slot["level"]))
		ladder.custom_minimum_size = Vector2(0, 82)
		_tab_container.add_child(ladder)


func _build_perks_tab() -> void:
	for pid: StringName in ShipBuildState.PERKS.keys():
		var pk: Dictionary = ShipBuildState.PERKS[pid]
		var on := pid in _build.selected_perks
		var btn := Button.new()
		btn.text = "%s %s ($%d | %.1f t)" % [
			"[EQUIPADO]" if on else "[  ]", pk["name"], int(pk["cost"]), float(pk["mass_t"])
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void:
			_build.toggle_perk(pid)
			_refresh_all()
		)
		_tab_container.add_child(btn)


func _refresh_validators() -> void:
	_clear_box(_validator_box)
	var body := _current_body()
	var m := _build.compute_metrics(body)
	if _btn_insurance != null:
		var payout := int(body.get("base_payout", 1800))
		var ins_fee := int(round(float(payout) * 0.12))
		_btn_insurance.text = "Seguro (%s $%d)" % ["ON" if _build.insured else "OFF", ins_fee]
		_btn_insurance.add_theme_color_override("font_color", SpaceTheme.COL_OK if _build.insured else SpaceTheme.COL_CREAM)

	var budget_ok := int(m["total_cost"]) <= _credits
	_add_bar("Presupuesto", "$%d / $%d" % [int(m["total_cost"]), _credits], float(m["total_cost"]) / float(maxi(_credits, 1)), budget_ok)

	var dv_ratio := float(m["delta_v_m_s"]) / maxf(float(m["required_dv_m_s"]), 1.0)
	_add_bar("Alcance Delta-V", "%.0f / %.0f m/s" % [float(m["delta_v_m_s"]), float(m["required_dv_m_s"])], dv_ratio, dv_ratio >= 1.0)

	var p_ratio := float(m["power_at_dest"]) / maxf(float(m["required_power"]), 0.1)
	_add_bar("Energia Destino", "%.1f / %.1f eq" % [float(m["power_at_dest"]), float(m["required_power"])], p_ratio, p_ratio >= 1.0)

	var p_exp := float(m["p_explosion"]) * 100.0
	_add_bar("Riesgo Despegue", "%.1f%% | %.1f t" % [p_exp, float(m["wet_mass_t"])], p_exp / 60.0, p_exp < 18.0)

	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var alerts: Array[String] = []
	if float(body.get("semi_major_axis_au", 1.0)) >= 3.0 and float(m["rtg_power"]) <= 0.0:
		alerts.append("CRITICO: Flujo solar %.1f%% en destino exige Banco MMRTG." % (float(m["solar_factor"]) * 100.0))
	if bool(body.get("requires_heatshield", false)) and not bool(m["has_heatshield"]):
		alerts.append("ALERTA: Destino con atmosfera requiere Escudo PICA / HRSI.")
	if not budget_ok:
		alerts.append("PRESUPUESTO EXCEDIDO: Quita instrumentos o usa piezas Chatarra.")
	if alerts.is_empty():
		alerts.append("Telemetria DSN %.0f kbps | Potencial Ciencia +%d pts" % [float(m["dsn_kbps"]), int(m["science_potential"])])
	summary.text = "\n".join(alerts)
	summary.add_theme_color_override("font_color", SpaceTheme.COL_TERRA if alerts.size() > 0 and not alerts[0].begins_with("Telemetria") else SpaceTheme.COL_OK)
	_validator_box.add_child(summary)


func _add_bar(title_txt: String, value_txt: String, ratio: float, good: bool) -> void:
	var row := HBoxContainer.new()
	_validator_box.add_child(row)

	var lbl := Label.new()
	lbl.text = title_txt
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = value_txt
	val_lbl.add_theme_color_override("font_color", SpaceTheme.COL_OK if good else SpaceTheme.COL_TERRA)
	SpaceTheme.apply_mono(val_lbl, 11)
	row.add_child(val_lbl)

	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 12)
	pb.max_value = 100.0
	pb.value = clampf(ratio * 100.0, 0.0, 100.0)
	pb.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = SpaceTheme.COL_OK if good else SpaceTheme.COL_TERRA
	pb.add_theme_stylebox_override("fill", sb)
	_validator_box.add_child(pb)


class _BlueprintCanvas extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#070b14"), true)
		var grid_col := Color("#10192b")
		var step := 32.0
		var gx := step
		while gx < size.x:
			draw_line(Vector2(gx, 0.0), Vector2(gx, size.y), grid_col, 1.0)
			gx += step
		var gy := step
		while gy < size.y:
			draw_line(Vector2(0.0, gy), Vector2(size.x, gy), grid_col, 1.0)
			gy += step

		var c := size * 0.5 + Vector2(0.0, 12.0)
		draw_arc(c, 150.0, 0.0, TAU, 64, Color("#1b2840"), 1.0)
		draw_arc(c, 210.0, 0.0, TAU, 64, Color("#142034"), 1.0)

		var sans := SpaceTheme.sans_font()
		var mono := SpaceTheme.mono_font()
		draw_string(sans, Vector2(12.0, 22.0), "CHASIS: ORBITAL MULE MK-I", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceTheme.COL_CREAM)
		draw_string(mono, Vector2(12.0, 38.0), "160x224 px | LUZ 315 DEG | 7 HARDPOINTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SpaceTheme.COL_MUTED)

		# Callouts tecnicos alrededor de la nave centrada
		var callouts := [
			[c + Vector2(-18.0, -135.0), Vector2(12.0, c.y - 145.0), "PROA BOW (Z=2)", "Anillo frontal 48px", true],
			[c + Vector2(-118.0, 4.0), Vector2(12.0, c.y - 54.0), "ABRAZADERAS + AO", "Gondolas simetricas", true],
			[c + Vector2(-185.0, 14.0), Vector2(12.0, c.y + 88.0), "ROTULA LATERAL (Z=2)", "Alas sin traslape", true],
			[c + Vector2(60.0, 30.0), Vector2(size.x - 12.0, c.y + 42.0), "CORTE 6 SALAS FTL", "Techo cutaway en vuelo", false],
			[c + Vector2(28.0, 136.0), Vector2(size.x - 12.0, c.y + 152.0), "POPA REMETIDA (Z=-1)", "Motores bajo faldon", false],
		]
		for co: Array in callouts:
			var target: Vector2 = co[0]
			var label_p: Vector2 = co[1]
			var title_s: String = co[2]
			var sub_s: String = co[3]
			var is_left: bool = co[4]
			var elbow_x := label_p.x + (116.0 if is_left else -116.0)
			var elbow := Vector2(elbow_x, label_p.y + 4.0)
			var start_l := Vector2(label_p.x, label_p.y + 4.0)
			draw_polyline(PackedVector2Array([start_l, elbow, target]), Color(0.55, 0.61, 0.71, 0.55), 1.0)
			draw_circle(target, 2.5, SpaceTheme.COL_AMBER)
			var align := HORIZONTAL_ALIGNMENT_LEFT if is_left else HORIZONTAL_ALIGNMENT_RIGHT
			var tx := label_p.x if is_left else label_p.x - 130.0
			var w := 130.0
			draw_string(sans, Vector2(tx, label_p.y - 2.0), title_s, align, w, 11, SpaceTheme.COL_CREAM)
			draw_string(mono, Vector2(tx, label_p.y + 16.0), sub_s, align, w, 11, SpaceTheme.COL_MUTED)


class _LevelLadderView extends Control:
	var _mod_name: String
	var _level: int

	func _init(mod_name: String, level: int) -> void:
		_mod_name = mod_name
		_level = level

	func _draw() -> void:
		var sans := SpaceTheme.sans_font()
		var mono := SpaceTheme.mono_font()
		draw_rect(Rect2(Vector2.ZERO, size), SpaceTheme.COL_RAISED, true)
		draw_rect(Rect2(Vector2.ZERO, size), SpaceTheme.COL_SEAM, false, 1.0)
		draw_string(sans, Vector2(8.0, 16.0), "PROGRESION PIN_08: %s" % _mod_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, 11, SpaceTheme.COL_CREAM)

		var gap := 6.0
		var pad_x := 8.0
		var card_w := (size.x - pad_x * 2.0 - gap * 4.0) / 5.0
		var card_y := 22.0
		var card_h := size.y - 28.0
		for lv: int in range(1, 6):
			var cx := pad_x + float(lv - 1) * (card_w + gap)
			var r := Rect2(cx, card_y, card_w, card_h)
			var is_cur := lv == _level
			var is_done := lv <= _level
			draw_rect(r, SpaceTheme.COL_ACTIVE if is_cur else SpaceTheme.COL_CHASSIS, true)
			draw_rect(r, SpaceTheme.COL_AMBER if is_cur else (SpaceTheme.COL_CYAN if is_done else SpaceTheme.COL_SEAM), false, 1.5 if is_cur else 1.0)
			if lv == 5:
				draw_string(mono, Vector2(cx + 2.0, card_y + 11.0), "MAX", HORIZONTAL_ALIGNMENT_CENTER, card_w - 4.0, 11, SpaceTheme.COL_AMBER if is_cur else SpaceTheme.COL_MUTED)
			# Reticula radial creciente estilo pin_08
			var rc := Vector2(cx + card_w * 0.5, card_y + card_h * 0.50)
			var rad := 4.0 + float(lv) * 1.3
			var col_r := SpaceTheme.COL_AMBER if is_cur else (SpaceTheme.COL_CYAN if is_done else SpaceTheme.COL_MUTED)
			for seg: int in range(4):
				var ang := float(seg) * PI * 0.25
				var off := Vector2(cos(ang), sin(ang)) * rad
				draw_line(rc - off, rc + off, col_r, 1.0)
			# 5 puntos LED en base
			for p: int in range(5):
				var lx := cx + (card_w - 20.0) * 0.5 + float(p) * 4.2
				var lcol := col_r if p < lv else Color("#24344d")
				draw_rect(Rect2(lx, card_y + card_h - 8.0, 3.0, 4.0), lcol, true)
