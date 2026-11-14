extends SceneTree

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_reactor_power()
	_test_room_hazards()
	_test_nasa_data_loader()
	_test_mission_evaluator()
	_test_station_input()
	_test_ship_build_state()
	_test_orbital_solver()
	_test_crew_controller()
	_test_rescued_mechanics()
	_test_main_scene_loads()
	_test_no_forbidden_font()

	print("Space Tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: " + msg)


func _test_reactor_power() -> void:
	var rp := ReactorPower.new(6)
	_check(rp.used_bars() == 5, "Reactor inicia con 5 barras asignadas")
	_check(rp.available_bars() == 1, "Reactor inicia con 1 barra libre")
	_check(rp.allocate(&"engines", 1), "Asigna barra libre a Motores")
	_check(not rp.allocate(&"helm", 1), "Bloquea asignacion sin barras libres")
	rp.set_manned(&"helm", true)
	_check(is_equal_approx(rp.efficiency(&"helm"), 0.75), "Manning bonus suma +0.25 a Timon")
	rp.set_damage_bars(&"engines", 2)
	_check(rp.max_usable_bars(&"engines") == 1, "Dano reduce barras utilizables")


func _test_room_hazards() -> void:
	var rh := RoomHazards.new()
	rh.trigger_hazard(&"engines", 0.30, 0.80, 0.0, true)
	var eng := rh.get_room(&"engines")
	_check(bool(eng["critical_active"]) and is_equal_approx(float(eng["critical_timer_s"]), 5.0), "Crisis inicia ventana de 5 s")

	rh.set_airlock(&"engines", true)
	var vented := false
	for _i: int in range(30):
		var res := rh.step(0.1, 1.0, {})
		if &"engines" in res["vented_fires"]:
			vented = true
			break
	_check(vented, "Abrir compuerta al vacio extingue incendio al drenar oxigeno")

	rh.trigger_hazard(&"life_support", 0.1, 0.0, 0.8, true)
	rh.step(5.5, 0.0, {&"life_support": true})
	var ls := rh.get_room(&"life_support")
	_check(float(ls["oxygen"]) < 0.20, "Brecha drena oxigeno bajo umbral de asfixia")


func _test_nasa_data_loader() -> void:
	var loader := NasaDataLoader.new()
	_check(loader.load_all(), "Carga todos los JSON NASA/JPL")
	_check(loader.get_contracts().size() == 3, "Existen 3 contratos planetarios")
	_check(loader.get_asteroids().size() == 4, "Existen 4 asteroides NEO curados")
	_check(loader.get_solar_events().size() == 4, "Existen 4 tormentas solares DONKI")
	_check(loader.get_debris_regimes().size() == 3, "Existen 3 regimenes de escombros LEO")

	var f_jup := NasaDataLoader.solar_factor(5.20)
	_check(f_jup < 0.04 and f_jup > 0.035, "Irradiancia en Jupiter cae a ~3.7%")
	_check(loader.dsn_one_way_latency_s("moon") > 1.2, "Latencia DSN unidireccional lunar > 1.2 s")


func _test_mission_evaluator() -> void:
	var loader := NasaDataLoader.new()
	loader.load_all()
	var jupiter := loader.get_body("jupiter")
	var mars := loader.get_body("mars")

	var ev_fail := MissionEvaluator.new()
	ev_fail.audit_preflight(jupiter, {"solar_power": 1.0, "rtg_power": 0.0, "required_power": 1.0, "radiation_hazard": true, "has_rad_shield": false, "overload": 0.25, "scrap_count": 2})
	var rep_fail := ev_fail.build_report(&"failed", 100, 10, 6200, 900)
	_check(rep_fail["grade"] == "F", "Mision a Jupiter sin RTG y fallida recibe rango F")
	_check((rep_fail["bad_items"] as Array).size() >= 3, "Auditoria explica multiples fallos causales")

	var ev_ok := MissionEvaluator.new()
	ev_ok.audit_preflight(mars, {"solar_power": 2.0, "rtg_power": 1.0, "required_power": 1.2, "has_heatshield": true, "has_parachute": true, "overload": 0.0, "scrap_count": 0})
	var rep_ok := ev_ok.build_report(&"success", 260, 260, 3400, 100)
	_check(rep_ok["grade"] == "S" and (rep_ok["bad_items"] as Array).is_empty(), "Mision bien equipada y ejecutada obtiene rango S")


func _test_station_input() -> void:
	var si := StationInput.new()
	si.set_mode(StationInput.Mode.SOLO)
	si.select_solo_station(&"pilot")
	var intents := si.build_station_intents({
		&"pilot": {"steer": Vector2(1.0, 0.0), "thrust": 1.0, "action": false, "vent": false, "autopilot": false}
	}, Vector2(-1.0, 0.0))
	_check(not bool(intents[&"pilot"]["autopilot"]), "Puesto activo en SOLO responde al jugador")
	_check(bool(intents[&"engineer"]["autopilot"]) and bool(intents[&"engineer"]["action"]), "Puesto sin jugador usa piloto automatico degradado")
	_check(si.cycle_solo_station() == &"radar", "Cambio rapido de puesto avanza a radar")


func _test_ship_build_state() -> void:
	var loader := NasaDataLoader.new()
	loader.load_all()
	var jupiter := loader.get_body("jupiter")
	var bs := ShipBuildState.new()
	var m_solar := bs.compute_metrics(jupiter)
	_check(float(m_solar["power_at_dest"]) < float(m_solar["required_power"]), "Panel solar base falla balance energetico en Jupiter")

	var res := bs.upgrade_socket(&"bow", 2000)
	_check(bool(res["ok"]) and int(bs.sockets[&"bow"]["level"]) == 2, "Sube hardpoint Proa a LVL 2 descontando creditos")
	bs.set_socket_module(&"port_nacelle", &"nacelle_rtg", &"NEW")
	bs.set_socket_module(&"stbd_nacelle", &"nacelle_rtg", &"NEW")
	var m_rtg := bs.compute_metrics(jupiter)
	_check(float(m_rtg["power_at_dest"]) > float(m_solar["power_at_dest"]), "Instalar MMRTG eleva energia disponible a 5.2 AU")

	var ov_before := float(m_rtg["overload"])
	bs.jettison_aux_cargo()
	var ov_after := float(bs.compute_metrics(jupiter)["overload"])
	_check(ov_after <= ov_before, "Jettison reduce masa y sobrecarga de lanzamiento")


func _test_orbital_solver() -> void:
	var loader := NasaDataLoader.new()
	loader.load_all()
	var mars := loader.get_body("mars")
	var bs := ShipBuildState.new()
	var metrics := bs.compute_metrics(mars)
	var os_sim := OrbitalSolver.new()
	os_sim.configure_for_body(mars, metrics)
	var ap0 := os_sim.apoapsis_km
	os_sim.ship_angle_rad = 0.0
	var out := os_sim.step(0.5, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, metrics, 0.0)
	_check(float(out["apoapsis_km"]) > ap0, "Quema prograde incrementa apoapsis orbital")
	_check(os_sim.orbit_points(32, Vector2.ZERO, 100.0).size() == 33, "Genera polilinea cerrada para OrbitalMap25D")
	_check(bool(out["in_reentry_corridor"]), "Angulo inicial -4.5 deg cae dentro del corredor marciano [-5.2, -3.8]")


func _test_crew_controller() -> void:
	var cc := CrewController.new()
	var path := cc.find_path(&"helm", &"engines")
	_check(path.size() == 2 and path[0] == &"reactor" and path[1] == &"engines", "BFS navega helm -> reactor -> engines")
	_check(cc.command_move(&"pilot", &"engines"), "Ordena movimiento de piloto hacia Motores")
	var rp := ReactorPower.new(7)
	var rh := RoomHazards.new()
	for _i: int in range(30):
		cc.step(0.1, rh, rp, &"pilot", true)
	_check(cc.crew[&"pilot"]["room"] == &"engines", "Piloto llega fisicamente a Motores en tiempo real")
	_check(rp.is_manned(&"engines"), "Ocupar Motores activa Manning Bonus en ReactorPower")


func _test_rescued_mechanics() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var bs := ShipBuildState.new()
	bs.insured = true
	_check(bs.insured, "ShipBuildState permite activar Seguro de Mision")
	var deny := bs.roll_scrapyard_crate(rng, 50)
	_check(not bool(deny["ok"]), "Caja Desguace bloquea si faltan creditos")
	var ok_crate := bs.roll_scrapyard_crate(rng, 1000)
	_check(bool(ok_crate["ok"]) and int(ok_crate["cost"]) == ShipBuildState.CRATE_COST, "Caja Desguace cobra 160 y devuelve calidad")

	var rh := RoomHazards.new()
	_check(rh.kick_repair(&"helm", rng) == &"none", "Patada en sala intacta retorna none")
	var fixed_cnt := 0
	var worse_cnt := 0
	for s: int in range(30):
		var krng := RandomNumberGenerator.new()
		krng.seed = 100 + s
		var r2 := RoomHazards.new()
		r2.trigger_hazard(&"engines", 0.30, 0.80, 0.20, true)
		var out := r2.kick_repair(&"engines", krng)
		if out == &"fixed":
			fixed_cnt += 1
		elif out == &"worse":
			worse_cnt += 1
	_check(fixed_cnt > 0 and worse_cnt > 0, "Patada de emergencia produce reparacion o empeoramiento segun RNG")

	var md := MusicDirector.new()
	md.set_phase(&"flight")
	md.set_chaos_active(true)
	_check(md.active_phase == &"flight" and md.chaos_active, "MusicDirector cambia fase a vuelo y activa caos")
	_check(md.toggle_mute(), "MusicDirector alterna silencio correctamente")
	md.free()


func _test_main_scene_loads() -> void:
	var packed := ResourceLoader.load("res://game/main.tscn") as PackedScene
	_check(packed != null, "Carga main.tscn sin errores de recursos o shaders")
	if packed != null:
		var inst := packed.instantiate()
		_check(inst != null, "Instancia escena principal completa")
		if inst != null:
			inst.free()


func _test_no_forbidden_font() -> void:
	var forbidden := "JetBrains" + " Mono"
	var files := [
		"res://project.godot",
		"res://game/main.gd",
		"res://game/audio/synth_sfx.gd",
		"res://game/audio/music_director.gd",
		"res://game/actors/modular_ship_25d.gd",
		"res://game/phases/hangar_screen.gd",
		"res://game/phases/takeoff_screen.gd",
		"res://game/phases/flight_screen.gd",
		"res://game/phases/debrief_screen.gd",
		"res://game/ui/space_theme.gd",
		"res://game/ui/orbital_map_25d.gd",
		"res://game/ui/navball_25d.gd",
		"res://game/ui/radar_wireframe_3d.gd",
		"res://game/sim/reactor_power.gd",
		"res://game/sim/room_hazards.gd",
		"res://game/sim/nasa_data_loader.gd",
		"res://game/sim/mission_evaluator.gd",
		"res://game/sim/station_input.gd",
		"res://game/sim/ship_build_state.gd",
		"res://game/sim/orbital_solver.gd",
		"res://game/sim/crew_controller.gd",
	]
	for p: String in files:
		var txt := FileAccess.get_file_as_string(p)
		_check(not txt.contains(forbidden), "Sin fuente prohibida en " + p)
