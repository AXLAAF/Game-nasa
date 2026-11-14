class_name FlightScreen
extends Control

signal mission_finished(outcome: StringName, hull_hp: float, repair_cost: int, science_collected: int, science_transmitted: int, extra_goods: Array[String], extra_bads: Array[String])

var _loader: NasaDataLoader
var _build: ShipBuildState
var _body: Dictionary = {}
var _metrics: Dictionary = {}
var _coop_mode: bool = false
var _sfx: SynthSfx

var _reactor: ReactorPower
var _hazards: RoomHazards
var _crew: CrewController
var _input_bus: StationInput
var _solver: OrbitalSolver

var _ship_view: ModularShip25D
var _orbital_map: OrbitalMap25D
var _navball: NavBall25D
var _radar_view: RadarWireframe3D

var _lbl_telemetry: Label
var _lbl_orbital_info: Label
var _lbl_station_hint: Label
var _crisis_box: VBoxContainer
var _reactor_rows: Dictionary = {}
var _route_modal: PanelContainer
var _btn_finish: Button

var _met_s: float = 0.0
var _hull_hp: float = 100.0
var _throttle: float = 0.0
var _storm_safe: bool = false
var _hazard_timer_s: float = 7.0
var _route_chosen: bool = false
var _neo_bonus_active: bool = false
var _repair_cost: int = 0
var _finished: bool = false
var _radar_contacts: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

var _extra_goods: Array[String] = []
var _extra_bads: Array[String] = []
var _fires_vented_count: int = 0
var _debris_avoided_count: int = 0


func setup(loader: NasaDataLoader, build: ShipBuildState, body: Dictionary, coop: bool, sfx: SynthSfx) -> void:
	_loader = loader
	_build = build
	_body = body
	_coop_mode = coop
	_sfx = sfx
	_metrics = _build.compute_metrics(_body)

	_reactor = ReactorPower.new(int(_metrics.get("reactor_bars", 7)))
	_hazards = RoomHazards.new()
	_crew = CrewController.new()
	_input_bus = StationInput.new()
	_input_bus.set_mode(StationInput.Mode.COOP_LOCAL if _coop_mode else StationInput.Mode.SOLO)
	_solver = OrbitalSolver.new()
	_solver.configure_for_body(_body, _metrics)
	_rng.randomize()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if _ship_view != null and _build != null:
		_ship_view.apply_build(_build)
		_ship_view.set_cutaway_open(true)
		_ship_view.bind_simulation(_hazards, _crew)
		_ship_view.room_clicked.connect(_on_room_clicked)
		_ship_view.airlock_clicked.connect(_on_airlock_clicked)
	if _orbital_map != null:
		_orbital_map.bind_solver(_solver)
	if _navball != null:
		_navball.bind_solver(_solver)
	if _radar_view != null:
		_radar_view.warn_lead_s = float(_metrics.get("radar_warn_s", 12.0))


func _build_ui() -> void:
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

	var root_v := VBoxContainer.new()
	root_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_v.add_theme_constant_override("separation", 6)
	add_child(root_v)

	# Franja superior de telemetria (44 px)
	var top := PanelContainer.new()
	top.custom_minimum_size = Vector2(0, 44)
	root_v.add_child(top)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 8)
	top.add_child(top_h)

	_lbl_telemetry = Label.new()
	_lbl_telemetry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(_lbl_telemetry)

	var btn_storm := Button.new()
	btn_storm.text = "Storm Safe"
	btn_storm.pressed.connect(func() -> void:
		_storm_safe = not _storm_safe
		btn_storm.text = "Storm Safe [ON]" if _storm_safe else "Storm Safe"
	)
	top_h.add_child(btn_storm)

	_btn_finish = Button.new()
	_btn_finish.text = "Completar Mision"
	SpaceTheme.style_cta_button(_btn_finish, SpaceTheme.COL_OK)
	_btn_finish.pressed.connect(func() -> void:
		_finish_flight(&"success")
	)
	top_h.add_child(_btn_finish)

	# Cuerpo principal: Izquierda FTL Interior (36%), Centro Orbita KSP (38%), Derecha Radar+Crisis (26%)
	var main_h := HBoxContainer.new()
	main_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_h.add_theme_constant_override("separation", 6)
	root_v.add_child(main_h)

	# 1) Columna FTL Interior
	var ftl_panel := PanelContainer.new()
	ftl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ftl_panel.size_flags_stretch_ratio = 0.36
	main_h.add_child(ftl_panel)

	var ftl_v := VBoxContainer.new()
	ftl_v.add_theme_constant_override("separation", 4)
	ftl_panel.add_child(ftl_v)

	var ftl_title := Label.new()
	ftl_title.text = "INTERIOR FTL 2.5D (Clic en sala mueve tripulante)"
	ftl_title.add_theme_color_override("font_color", SpaceTheme.COL_CYAN)
	ftl_title.add_theme_font_size_override("font_size", 12)
	ftl_v.add_child(ftl_title)

	var ship_area := Control.new()
	ship_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ftl_v.add_child(ship_area)

	_ship_view = ModularShip25D.new()
	_ship_view.position = Vector2(215, 195)
	_ship_view.scale = Vector2(1.45, 1.45)
	ship_area.add_child(_ship_view)

	# Botonera de puestos (1-4) y esclusas de aire
	var st_h := HBoxContainer.new()
	st_h.add_theme_constant_override("separation", 4)
	ftl_v.add_child(st_h)
	var st_labels := {&"pilot": "1 Piloto", &"radar": "2 Radar", &"engineer": "3 Ing.", &"mission": "4 Ciencia"}
	for st_id: StringName in StationInput.STATIONS:
		var b := Button.new()
		b.text = st_labels[st_id]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sref := st_id
		b.pressed.connect(func() -> void:
			_input_bus.select_solo_station(sref)
		)
		st_h.add_child(b)

	var air_h := HBoxContainer.new()
	air_h.add_theme_constant_override("separation", 4)
	ftl_v.add_child(air_h)
	var b_air1 := Button.new()
	b_air1.text = "Esclusa O2 (V)"
	b_air1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_air1.pressed.connect(func() -> void: _on_airlock_clicked(&"life_support"))
	air_h.add_child(b_air1)

	var b_air2 := Button.new()
	b_air2.text = "Esclusa Motores"
	b_air2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_air2.pressed.connect(func() -> void: _on_airlock_clicked(&"engines"))
	air_h.add_child(b_air2)

	_lbl_station_hint = Label.new()
	_lbl_station_hint.add_theme_font_size_override("font_size", 11)
	_lbl_station_hint.add_theme_color_override("font_color", SpaceTheme.COL_MUTED)
	ftl_v.add_child(_lbl_station_hint)

	# 2) Columna Central: Orbita KSP 2.5D + NavBall + Barras Reactor
	var ksp_v := VBoxContainer.new()
	ksp_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ksp_v.size_flags_stretch_ratio = 0.38
	ksp_v.add_theme_constant_override("separation", 6)
	main_h.add_child(ksp_v)

	var orb_panel := PanelContainer.new()
	orb_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	orb_panel.size_flags_stretch_ratio = 0.58
	ksp_v.add_child(orb_panel)
	_orbital_map = OrbitalMap25D.new()
	_orbital_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	orb_panel.add_child(_orbital_map)

	var bot_panel := PanelContainer.new()
	bot_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_panel.size_flags_stretch_ratio = 0.42
	ksp_v.add_child(bot_panel)

	var bot_h := HBoxContainer.new()
	bot_h.add_theme_constant_override("separation", 8)
	bot_panel.add_child(bot_h)

	var nav_v := VBoxContainer.new()
	nav_v.custom_minimum_size = Vector2(150, 0)
	bot_h.add_child(nav_v)
	_navball = NavBall25D.new()
	_navball.custom_minimum_size = Vector2(120, 120)
	_navball.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_v.add_child(_navball)

	var th_h := HBoxContainer.new()
	nav_v.add_child(th_h)
	var b_burn := Button.new()
	b_burn.text = "Quema Δv"
	b_burn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SpaceTheme.style_cta_button(b_burn, SpaceTheme.COL_AMBER)
	b_burn.pressed.connect(func() -> void:
		_throttle = 0.0 if _throttle > 0.1 else 1.0
	)
	th_h.add_child(b_burn)

	_lbl_orbital_info = Label.new()
	_lbl_orbital_info.add_theme_font_size_override("font_size", 11)
	nav_v.add_child(_lbl_orbital_info)

	# Barras del Reactor FTL (6 sistemas)
	var react_v := VBoxContainer.new()
	react_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	react_v.add_theme_constant_override("separation", 3)
	bot_h.add_child(react_v)

	var sys_titles := {
		&"helm": "Timon (F1)",
		&"engines": "Motores (F2)",
		&"sensors": "Sensores (F3)",
		&"shields_thermal": "Escudo/NH3 (F4)",
		&"life_support": "Soporte O2 (F5)",
		&"science_bay": "Ciencia (F6)",
	}
	for sys_id: StringName in ReactorPower.SYSTEMS:
		var r_h := HBoxContainer.new()
		r_h.add_theme_constant_override("separation", 4)
		react_v.add_child(r_h)

		var b_min := Button.new()
		b_min.text = "-"
		b_min.custom_minimum_size = Vector2(24, 0)
		var sid := sys_id
		b_min.pressed.connect(func() -> void: _reactor.allocate(sid, -1))
		r_h.add_child(b_min)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.text = sys_titles[sys_id]
		r_h.add_child(lbl)

		var b_plus := Button.new()
		b_plus.text = "+"
		b_plus.custom_minimum_size = Vector2(24, 0)
		b_plus.pressed.connect(func() -> void: _reactor.allocate(sid, 1))
		r_h.add_child(b_plus)

		_reactor_rows[sys_id] = lbl

	# 3) Columna Derecha: Radar 3D Wireframe + Alertas de 5 s + Nodo Intermedio
	var right_v := VBoxContainer.new()
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.size_flags_stretch_ratio = 0.26
	right_v.add_theme_constant_override("separation", 6)
	main_h.add_child(right_v)

	_radar_view = RadarWireframe3D.new()
	_radar_view.custom_minimum_size = Vector2(0, 210)
	_radar_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_radar_view.size_flags_stretch_ratio = 0.45
	right_v.add_child(_radar_view)

	var alert_panel := PanelContainer.new()
	alert_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	alert_panel.size_flags_stretch_ratio = 0.55
	right_v.add_child(alert_panel)

	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	alert_panel.add_child(av)

	var atitle := Label.new()
	atitle.text = "ALERTAS DE CRISIS (5.0 s)"
	atitle.add_theme_color_override("font_color", SpaceTheme.COL_AMBER)
	atitle.add_theme_font_size_override("font_size", 12)
	av.add_child(atitle)

	_crisis_box = VBoxContainer.new()
	_crisis_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crisis_box.add_theme_constant_override("separation", 4)
	av.add_child(_crisis_box)

	_route_modal = PanelContainer.new()
	_route_modal.visible = false
	av.add_child(_route_modal)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	_route_modal.add_child(rv)
	var rl := Label.new()
	rl.text = "NODO INTERMEDIO: Elige tramo 2"
	rl.add_theme_color_override("font_color", SpaceTheme.COL_CYAN)
	rv.add_child(rl)

	var b_dir := Button.new()
	b_dir.text = "Ruta Directa (Cinturon Kessler)"
	b_dir.pressed.connect(func() -> void:
		_route_chosen = true
		_route_modal.visible = false
	)
	rv.add_child(b_dir)

	var b_neo := Button.new()
	b_neo.text = "Desvio NEO Bennu (+140 Sci)"
	b_neo.pressed.connect(func() -> void:
		_route_chosen = true
		_neo_bonus_active = true
		_solver.science_collected += 140.0
		_route_modal.visible = false
	)
	rv.add_child(b_neo)


func _on_room_clicked(room_id: StringName) -> void:
	if _crew == null or _input_bus == null:
		return
	var target_crew := _input_bus.active_solo_station
	_crew.command_move(target_crew, room_id)
	if _sfx != null:
		_sfx.play_click()


func _on_airlock_clicked(room_id: StringName) -> void:
	if _hazards == null:
		return
	var cur := bool(_hazards.get_room(room_id).get("airlock_open", false))
	_hazards.set_airlock(room_id, not cur)
	if _sfx != null:
		_sfx.play_airlock()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _input_bus.select_solo_station(&"pilot")
			KEY_2: _input_bus.select_solo_station(&"radar")
			KEY_3: _input_bus.select_solo_station(&"engineer")
			KEY_4: _input_bus.select_solo_station(&"mission")
			KEY_TAB: _input_bus.cycle_solo_station()
			KEY_V:
				var cur_r: StringName = _crew.crew[_input_bus.active_solo_station]["room"]
				if cur_r in [&"life_support", &"engines"]:
					_on_airlock_clicked(cur_r)
			KEY_F1: _reactor.allocate(&"helm", -1 if event.shift_pressed else 1)
			KEY_F2: _reactor.allocate(&"engines", -1 if event.shift_pressed else 1)
			KEY_F3: _reactor.allocate(&"sensors", -1 if event.shift_pressed else 1)
			KEY_F4: _reactor.allocate(&"shields_thermal", -1 if event.shift_pressed else 1)
			KEY_F5: _reactor.allocate(&"life_support", -1 if event.shift_pressed else 1)
			KEY_F6: _reactor.allocate(&"science_bay", -1 if event.shift_pressed else 1)


func _process(delta: float) -> void:
	if _finished or _solver == null:
		return
	_met_s += delta

	# Leer teclado continuo 1P / 2P sin pausa global
	var steer_x := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		steer_x -= 1.0
	if Input.is_key_pressed(KEY_D):
		steer_x += 1.0
	steer_x = clampf(steer_x, -1.0, 1.0)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE):
		_throttle = 1.0
	elif Input.is_key_pressed(KEY_S):
		_throttle = 0.0

	var p_intent := StationInput.empty_intent(false)
	p_intent["steer"] = Vector2(steer_x, 0.0)
	p_intent["thrust"] = _throttle
	var intents := _input_bus.build_station_intents({
		_input_bus.active_solo_station: p_intent,
		&"pilot": p_intent,
	}, Vector2(-_solver.ship_angle_rad * 0.5, 0.0))

	var eff_steer := float((intents[&"pilot"]["steer"] as Vector2).x)
	var eff_throt := _throttle if not bool(intents[&"pilot"]["autopilot"]) else float(intents[&"pilot"]["thrust"])

	# Paso de simulacion en Crew, RoomHazards y OrbitalSolver
	_crew.step(delta, _hazards, _reactor, _input_bus.active_solo_station, not _coop_mode)
	var life_eff := _reactor.efficiency(&"life_support")
	var haz_res := _hazards.step(delta, life_eff, _crew.station_crew_map())

	for vr: StringName in haz_res["vented_fires"]:
		_fires_vented_count += 1
		if _fires_vented_count == 1:
			_extra_goods.append("Fuego extinguido al vacio sin bajas mediante esclusa en %s." % String(vr))
	for exp_r: StringName in haz_res["expired_crises"]:
		_hull_hp = maxf(_hull_hp - 12.0, 0.0)
		_repair_cost += 280
		if _sfx != null:
			_sfx.play_alarm()

	# Aplicar dano en barras de reactor por salud de sala
	for pair: Array in [[&"helm", &"helm"], [&"sensors", &"sensors"], [&"engines", &"engines"], [&"life_support", &"life_support"], [&"science_bay", &"science_bay"]]:
		var rd := _hazards.get_room(pair[0])
		var max_b := 3 if pair[1] == &"engines" else 2
		_reactor.set_damage_bars(pair[1], _hazards.damage_bars_for(pair[0], max_b))

	var orb := _solver.step(
		delta,
		eff_steer,
		eff_throt,
		_reactor.efficiency(&"engines"),
		_reactor.efficiency(&"sensors"),
		_reactor.efficiency(&"science_bay"),
		_reactor.efficiency(&"shields_thermal"),
		_metrics,
		float(haz_res["fuel_leak_rate"])
	)

	_ship_view.set_thruster_power(eff_throt * _reactor.efficiency(&"engines"))
	_navball.set_manned(_reactor.is_manned(&"helm"))
	_radar_view.sensors_online = _reactor.effective_bars(&"sensors") > 0

	# Generador periodico de eventos NASA (CelesTrak debris & DONKI CME)
	_step_hazards_timeline(delta, eff_steer)

	if _met_s >= 32.0 and not _route_chosen and not _route_modal.visible:
		_route_modal.visible = true

	_refresh_hud_labels(orb)

	if _hull_hp <= 0.0:
		_extra_bads.append("Casco colapsado por cascada de averias no contenidas a tiempo.")
		_finish_flight(&"failed")


func _step_hazards_timeline(delta: float, steer_x: float) -> void:
	_hazard_timer_s -= delta
	if _hazard_timer_s <= 0.0:
		_hazard_timer_s = 12.0
		var ev_roll := _rng.randf()
		if ev_roll < 0.55:
			var regs := _loader.get_debris_regimes()
			var reg: Dictionary = regs[_rng.randi_range(0, regs.size() - 1)] if not regs.is_empty() else {}
			_radar_contacts.append({
				"kind": "debris",
				"short": "DEBRIS",
				"lane_x": _rng.randf_range(-0.85, 0.85),
				"eta_s": float(_metrics.get("radar_warn_s", 11.0)),
				"energy_j": float(reg.get("impact_energy_j", 4500.0)),
			})
		else:
			var sevs := _loader.get_solar_events()
			var sev: Dictionary = sevs[_rng.randi_range(0, sevs.size() - 1)] if not sevs.is_empty() else {}
			_radar_contacts.append({
				"kind": "solar",
				"short": str(sev.get("class_type", "CME")),
				"lane_x": 0.0,
				"eta_s": 10.0,
				"energy_j": float(sev.get("impact_energy_j", 8500.0)),
			})

	var alive: Array[Dictionary] = []
	for hz: Dictionary in _radar_contacts:
		hz["eta_s"] = float(hz["eta_s"]) - delta
		if float(hz["eta_s"]) <= 0.0:
			_resolve_hazard_impact(hz, steer_x)
		else:
			alive.append(hz)
	_radar_contacts = alive
	_radar_view.hazards_queue = _radar_contacts


func _resolve_hazard_impact(hz: Dictionary, steer_x: float) -> void:
	if str(hz["kind"]) == "debris":
		# Si el piloto esquiva activamente con timon alimentado, evita el golpe
		if absf(steer_x) > 0.35 and _reactor.efficiency(&"helm") > 0.3:
			_debris_avoided_count += 1
			if _debris_avoided_count == 1:
				_extra_goods.append("Radar detecto detritos CelesTrak con antelacion evitando impacto.")
			return
		var zones := [&"top", &"middle", &"bottom", &"radial"]
		var z: StringName = zones[_rng.randi_range(0, 3)]
		_hazards.apply_impact_zone(z, float(hz["energy_j"]), _rng)
		_hull_hp = maxf(_hull_hp - 14.0, 0.0)
		_repair_cost += 220
		if _sfx != null:
			_sfx.play_alarm()
	else:
		# Tormenta solar DONKI
		if _storm_safe or bool(_metrics.get("emp_immune", false)):
			_extra_goods.append("Proteccion efectiva frente a tormenta solar DONKI sin daño SEU.")
			return
		_radar_view.emp_glitch_s = 5.0
		_hazards.apply_impact_zone(&"middle", float(hz["energy_j"]), _rng)
		_hull_hp = maxf(_hull_hp - 10.0, 0.0)
		_repair_cost += 240
		if _sfx != null:
			_sfx.play_alarm()


func _refresh_hud_labels(orb: Dictionary) -> void:
	var mins := int(_met_s) / 60
	var secs := int(_met_s) % 60
	_lbl_telemetry.text = "MET %02d:%02d | Casco %.0f%% | Comb %.0f%% | Temp %.2f | Sci %.0f (DSN %.0f)" % [
		mins, secs, _hull_hp, float(orb["fuel_ratio"]) * 100.0, float(orb["temp_norm"]),
		float(orb["science_collected"]), float(orb["science_transmitted"])
	]
	_lbl_orbital_info.text = "AP %.0f | PE %.0f\n%s" % [
		float(orb["apoapsis_km"]), float(orb["periapsis_km"]),
		"DSN OK" if bool(orb["dsn_window_open"]) else "SIN DSN"
	]
	_lbl_station_hint.text = "Activo: %s (%s) | Libres Reactor: %d" % [
		String(_input_bus.active_solo_station).to_upper(),
		"2P COOP" if _coop_mode else "1P [1-4/Tab]",
		_reactor.available_bars()
	]

	for sys_id: StringName in ReactorPower.SYSTEMS:
		var lbl := _reactor_rows.get(sys_id) as Label
		if lbl != null:
			var eff := _reactor.effective_bars(sys_id)
			var max_b := _reactor.max_usable_bars(sys_id)
			var man := " *" if _reactor.is_manned(sys_id) else ""
			lbl.text = "%s [%d/%d]%s" % [String(sys_id), eff, max_b, man]

	for ch: Node in _crisis_box.get_children():
		ch.queue_free()
	var any_crisis := false
	for rid: StringName in _hazards.rooms.keys():
		var rd := _hazards.get_room(rid)
		if float(rd["fire"]) > 0.05 or float(rd["breach"]) > 0.05:
			any_crisis = true
			var l := Label.new()
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.text = "%s: %s%s (O2 %.0f%% | %.1fs)" % [
				String(rid).to_upper(),
				"FUEGO " if float(rd["fire"]) > 0.05 else "",
				"BRECHA " if float(rd["breach"]) > 0.05 else "",
				float(rd["oxygen"]) * 100.0,
				float(rd["critical_timer_s"]),
			]
			l.add_theme_color_override("font_color", SpaceTheme.COL_TERRA if bool(rd["critical_active"]) else SpaceTheme.COL_AMBER)
			l.add_theme_font_size_override("font_size", 11)
			_crisis_box.add_child(l)
	if not any_crisis:
		var ok_l := Label.new()
		ok_l.text = "Sin emergencias activas. Usa Quema dV y apunta antena DSN."
		ok_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ok_l.add_theme_color_override("font_color", SpaceTheme.COL_OK)
		ok_l.add_theme_font_size_override("font_size", 11)
		_crisis_box.add_child(ok_l)

	_btn_finish.text = "Cerrar Mision" if _met_s >= 50.0 or _solver.progress_to_capture >= 0.9 else "Retorno Anticipado"


func _finish_flight(outcome: StringName) -> void:
	if _finished:
		return
	_finished = true
	var final_out := outcome
	if outcome == &"success" and _met_s < 45.0 and _solver.progress_to_capture < 0.7:
		final_out = &"partial"
	mission_finished.emit(
		final_out,
		_hull_hp,
		_repair_cost,
		int(round(_solver.science_collected)),
		int(round(_solver.science_transmitted)),
		_extra_goods,
		_extra_bads
	)
