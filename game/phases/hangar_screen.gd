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
var _cutaway_open: bool = false
var _coop_mode: bool = false
var _active_tab: int = 0

var _ship_view: ModularShip25D
var _lbl_credits: Label
var _lbl_mode: Label
var _lbl_live_status: Label
var _tab_container: VBoxContainer
var _validator_box: VBoxContainer
var _planet_preview: OrbitalMap25D
var _preview_solver: OrbitalSolver


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

	# Franja superior (44 px)
	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 44)
	root_vbox.add_child(top_bar)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_h)

	var brand := Label.new()
	brand.text = "DEUDA ORBITAL | DIQUE MODULAR 2.5D"
	brand.add_theme_color_override("font_color", SpaceTheme.COL_AMBER)
	brand.add_theme_font_size_override("font_size", 15)
	top_h.add_child(brand)

	_lbl_credits = Label.new()
	_lbl_credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	top_h.add_child(_lbl_live_status)

	# Cuerpo principal (Izquierda 31%, Centro 41%, Derecha 28%)
	var body_h := HBoxContainer.new()
	body_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_h.add_theme_constant_override("separation", 8)
	root_vbox.add_child(body_h)

	# Panel izquierdo de configuracion por pestañas
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.32
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

	# Escena central unica: Nave Orbital Mule Mk-I + Mapa Astrofisico pequeño
	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 0.40
	body_h.add_child(center_panel)

	var center_overlay := Control.new()
	center_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_panel.add_child(center_overlay)

	_planet_preview = OrbitalMap25D.new()
	_planet_preview.position = Vector2(8, 8)
	_planet_preview.size = Vector2(150, 150)
	center_overlay.add_child(_planet_preview)

	var ship_anchor := CenterContainer.new()
	ship_anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_overlay.add_child(ship_anchor)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(360, 460)
	ship_anchor.add_child(holder)

	_ship_view = ModularShip25D.new()
	_ship_view.position = Vector2(180, 240)
	_ship_view.scale = Vector2(1.5, 1.5)
	holder.add_child(_ship_view)

	var center_hint := Label.new()
	center_hint.text = "Chasis: Orbital Mule Mk-I (7 Hardpoints + Abrazaderas 2.5D)"
	center_hint.add_theme_color_override("font_color", SpaceTheme.COL_MUTED)
	center_hint.position = Vector2(12, 595)
	center_overlay.add_child(center_hint)

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
	right_v.add_child(r_title)

	_validator_box = VBoxContainer.new()
	_validator_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_validator_box.add_theme_constant_override("separation", 6)
	right_v.add_child(_validator_box)

	var btn_launch := Button.new()
	btn_launch.text = "A RAMPA DE LANZAMIENTO"
	SpaceTheme.style_cta_button(btn_launch, SpaceTheme.COL_AMBER)
	btn_launch.pressed.connect(func() -> void:
		var body := _current_body()
		launch_requested.emit(body)
	)
	right_v.add_child(btn_launch)


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
	var debt_txt := (" | Deuda: $%d" % _loan_debt) if _loan_debt > 0 else ""
	_lbl_credits.text = "Saldo: $%d%s | Casco LVL %d" % [_credits, debt_txt, _build.hull_level]
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
	h1.text = "Vehiculo de Lanzamiento (Compite por Presupuesto vs Masa):"
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
			var res := _build.upgrade_socket(sk, _credits)
			if bool(res["ok"]):
				var spent := int(res["cost"])
				_credits -= spent
				credits_spent.emit(spent)
				_refresh_all()
		)
		row.add_child(btn_up)


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

	var budget_ok := int(m["total_cost"]) <= _credits
	_add_bar("Presupuesto ($%d / $%d)" % [int(m["total_cost"]), _credits], float(m["total_cost"]) / float(maxi(_credits, 1)), budget_ok)

	var dv_ratio := float(m["delta_v_m_s"]) / maxf(float(m["required_dv_m_s"]), 1.0)
	_add_bar("Alcance dV (%.0f / %.0f m/s)" % [float(m["delta_v_m_s"]), float(m["required_dv_m_s"])], dv_ratio, dv_ratio >= 1.0)

	var p_ratio := float(m["power_at_dest"]) / maxf(float(m["required_power"]), 0.1)
	_add_bar("Energia Destino (%.1f / %.1f eq)" % [float(m["power_at_dest"]), float(m["required_power"])], p_ratio, p_ratio >= 1.0)

	var p_exp := float(m["p_explosion"]) * 100.0
	_add_bar("Riesgo Despegue (%.1f%% | %.1f t)" % [p_exp, float(m["wet_mass_t"])], p_exp / 60.0, p_exp < 18.0)

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


func _add_bar(title_txt: String, ratio: float, good: bool) -> void:
	var lbl := Label.new()
	lbl.text = title_txt
	lbl.add_theme_font_size_override("font_size", 12)
	_validator_box.add_child(lbl)

	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 14)
	pb.max_value = 100.0
	pb.value = clampf(ratio * 100.0, 0.0, 100.0)
	pb.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = SpaceTheme.COL_OK if good else SpaceTheme.COL_TERRA
	pb.add_theme_stylebox_override("fill", sb)
	_validator_box.add_child(pb)
