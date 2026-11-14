extends SceneTree

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_reactor_power()
	_test_room_hazards()
	_test_nasa_data_loader()
	_test_mission_evaluator()
	_test_station_input()
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
	var rp := ReactorPower.new(7)
	_check(rp.used_bars() <= 7, "Reactor respeta presupuesto inicial de barras")
	rp.allocate(&"science_bay", 1)
	_check(rp.effective_bars(&"science_bay") == 1 or rp.available_bars() == 0, "Asignacion de barras respeta disponible")
	rp.allocate(&"life_support", -1)
	_check(rp.allocate(&"engines", 1), "Quitar barra de life_support libera energia para engines")
	var eff_unmanned := rp.efficiency(&"engines")
	rp.set_manned(&"engines", true)
	var eff_manned := rp.efficiency(&"engines")
	_check(eff_manned > eff_unmanned, "Manning bonus estilo FTL aumenta eficiencia")
	rp.set_damage_bars(&"engines", 3)
	_check(rp.effective_bars(&"engines") == 0, "Dano total en sala corta energia efectiva a 0")


func _test_room_hazards() -> void:
	var rh := RoomHazards.new()
	rh.trigger_hazard(&"engines", 0.35, 0.8, 0.0, true)
	_check(bool(rh.get_room(&"engines")["critical_active"]), "Incendio activa cuenta regresiva critica")
	# Probar mecanica FTL de abrir airlock para apagar incendio al vacio
	rh.set_airlock(&"engines", true)
	for i: int in 4:
		rh.step(0.5, 1.0, {&"engines": false})
	_check(float(rh.get_room(&"engines")["oxygen"]) < 0.15, "Airlock abierto drena oxigeno rapidamente")
	var step_res := rh.step(0.8, 1.0, {&"engines": true})
	_check(float(rh.get_room(&"engines")["fire"]) < 0.2, "Falta de oxigeno sofoca incendio en la sala")
	_check((step_res["suffocating_rooms"] as Array).has(&"engines"), "Tripulante en sala sin O2 recibe alerta de asfixia")

	# Probar vencimiento de crisis de 5s si no se repara
	var rh2 := RoomHazards.new()
	rh2.trigger_hazard(&"reactor", 0.1, 0.0, 0.6, true)
	var expired := false
	for i: int in 12:
		var res := rh2.step(0.5, 1.0, {})
		if (res["expired_crises"] as Array).has(&"reactor"):
			expired = true
			break
	_check(expired, "Crisis no atendida en 5 segundos escala y dispara evento de fallo")

	var rh3 := RoomHazards.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var imp := rh3.apply_impact_zone(&"bottom", 12000.0, rng)
	_check(imp["severity"] == "critica" and imp["room_id"] == &"engines", "Impacto critico en zona bottom afecta a sala engines")


func _test_nasa_data_loader() -> void:
	var loader := NasaDataLoader.new()
	_check(loader.load_all(), "Carga de los 4 JSON de datos NASA/JPL exitosa")
	var contracts := loader.get_contracts()
	_check(contracts.size() >= 3, "Al menos 3 contratos planetarios reales cargados")
	_check(loader.dsn_one_way_latency_s("jupiter") > 2000.0, "Latencia DSN unidireccional de Jupiter > 2000 s")
	_check(loader.solar_irradiance_at_body("mars") < 650.0, "Irradiancia real en Marte < 650 W/m2")
	_check(loader.get_asteroids().size() == 4, "4 asteroides JPL SBDB cargados")
	_check(loader.get_solar_events().size() == 4, "4 tormentas solares DONKI cargadas")
	_check(loader.get_debris_regimes().size() == 3, "3 regimenes de basura espacial LEO cargados")
	_check(loader.source_citations().size() == 4, "4 citas oficiales NASA/JPL presentes")


func _test_mission_evaluator() -> void:
	var loader := NasaDataLoader.new()
	loader.load_all()
	var jupiter := loader.get_body("jupiter")
	var ev := MissionEvaluator.new()
	ev.set_sources(loader.source_citations())
	ev.audit_preflight(jupiter, {
		"solar_power": 10.0,
		"rtg_power": 0.0,
		"required_power": 2.0,
		"has_rad_shield": false,
		"overload": 0.25,
		"scrap_count": 2,
	})
	var report := ev.build_report(&"failed", 100, 40, 6200, 900)
	_check((report["bad_items"] as Array).size() >= 3, "Auditor detecta error solar en Jupiter, sin blindaje rad, sobrecarga y chatarra")
	_check(report["grade"] == "F" and int(report["net_credits"]) < 0, "Mision fallida genera saldo negativo de quiebra")

	var mars := loader.get_body("mars")
	var ev_ok := MissionEvaluator.new()
	ev_ok.audit_preflight(mars, {
		"solar_power": 6.0,
		"rtg_power": 2.0,
		"required_power": 2.0,
		"has_heatshield": true,
		"has_parachute": true,
		"overload": 0.0,
		"scrap_count": 0,
	})
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


func _test_no_forbidden_font() -> void:
	var forbidden := "JetBrains" + " Mono"
	var files := [
		"res://project.godot",
		"res://game/main.gd",
		"res://game/sim/reactor_power.gd",
		"res://game/sim/room_hazards.gd",
		"res://game/sim/nasa_data_loader.gd",
		"res://game/sim/mission_evaluator.gd",
		"res://game/sim/station_input.gd",
	]
	for p: String in files:
		var txt := FileAccess.get_file_as_string(p)
		_check(not txt.contains(forbidden), "Sin fuente prohibida en " + p)
