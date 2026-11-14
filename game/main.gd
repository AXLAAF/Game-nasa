extends Node2D

var _loader := NasaDataLoader.new()
var _build := ShipBuildState.new()
var _evaluator := MissionEvaluator.new()
var _sfx: SynthSfx
var _music: MusicDirector
var _http: HTTPRequest

var _ui_layer: CanvasLayer
var _ui_root: Control
var _current_screen: Control

var _credits: int = 2200
var _loan_debt: int = 0
var _active_body: Dictionary = {}
var _coop_mode: bool = false
var _live_dsn_note: String = ""


func _ready() -> void:
	_loader.load_all()
	var contracts := _loader.get_contracts()
	if not contracts.is_empty():
		_active_body = contracts[0]

	_sfx = SynthSfx.new()
	add_child(_sfx)

	_music = MusicDirector.new()
	add_child(_music)

	_http = HTTPRequest.new()
	_http.timeout = 4.0
	add_child(_http)
	_http.request_completed.connect(_on_live_nasa_completed)

	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.theme = SpaceTheme.build_theme()
	_ui_layer.add_child(_ui_root)

	_show_hangar()


func _swap_screen(node: Control) -> void:
	if _current_screen != null and is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = node
	_ui_root.add_child(node)


func _show_hangar() -> void:
	if _music != null:
		_music.set_phase(&"hangar")
	var h := HangarScreen.new()
	_swap_screen(h)
	var body_id := str(_active_body.get("id", "moon"))
	h.setup(_loader, _build, _credits, _loan_debt, body_id, _coop_mode)
	h.mode_toggled.connect(func(coop: bool) -> void: _coop_mode = coop)
	h.credits_spent.connect(func(amount: int) -> void: _credits = maxi(_credits - amount, 0))
	h.live_nasa_requested.connect(_on_live_nasa_requested)
	h.launch_requested.connect(_on_launch_requested)


func _on_live_nasa_requested() -> void:
	if _current_screen is HangarScreen:
		(_current_screen as HangarScreen).set_live_status("Consultando DSN...")
	_http.request("https://eyes.nasa.gov/dsn/data/dsn.xml")


func _on_live_nasa_completed(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	var msg := "Snapshot Local OK"
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and body_bytes.size() > 64:
		var xml := body_bytes.get_string_from_utf8()
		if xml.contains("<dsn>"):
			msg = "DSN Live Sync OK"
			_live_dsn_note = "Datos DSN sincronizados en vivo desde eyes.nasa.gov."
	if _current_screen is HangarScreen:
		(_current_screen as HangarScreen).set_live_status(msg)


func _on_launch_requested(body: Dictionary) -> void:
	_active_body = body
	_build.auxiliary_cargo_attached = true
	_build.jettisoned = false
	var m := _build.compute_metrics(_active_body)
	var launch_cost := mini(int(m["total_cost"]) / 4, _credits)
	_credits -= launch_cost
	if _build.insured:
		var payout := int(_active_body.get("base_payout", 1800))
		var ins_fee := mini(int(round(float(payout) * 0.12)), _credits)
		_credits -= ins_fee

	_evaluator.clear()
	_evaluator.set_sources(_loader.source_citations())
	_evaluator.audit_preflight(_active_body, _build.to_evaluator_config(m))
	if _build.insured:
		_evaluator.record_good("INSURANCE_ACTIVE", "Seguro de mision contratado (12% prima, 60% cobertura ante fallo).")
	if not _live_dsn_note.is_empty():
		_evaluator.record_good("LIVE_DSN", _live_dsn_note)

	if _music != null:
		_music.set_phase(&"takeoff")
	var t := TakeoffScreen.new()
	_swap_screen(t)
	t.setup(_build, _active_body, _sfx)
	t.takeoff_completed.connect(_on_takeoff_completed)


func _on_takeoff_completed(aborted: bool, exploded: bool) -> void:
	if _build.jettisoned:
		_evaluator.record_good("JETTISON_OK", "Descarte de carga auxiliar en ascenso redujo sobrecarga Max-Q.")
	if aborted:
		_evaluator.record_bad("ABORTED_LES", "Ascenso abortado mediante Torre de Escape antes de alcanzar orbita.")
		_credits += 350
		_show_debrief(&"partial", 0, 0, 180)
		return
	if exploded:
		_evaluator.record_bad("ASCENT_FAILURE", "Fallo catastrofico en rampa/Max-Q por sobrecarga o estado Chatarra.")
		_show_debrief(&"failed", 0, 0, 620)
		return

	if _music != null:
		_music.set_phase(&"flight")
	var f := FlightScreen.new()
	_swap_screen(f)
	f.setup(_loader, _build, _active_body, _coop_mode, _sfx, _music)
	f.mission_finished.connect(_on_flight_finished)


func _on_flight_finished(
	outcome: StringName,
	hull_hp: float,
	repair_cost: int,
	science_collected: int,
	science_transmitted: int,
	extra_goods: Array[String],
	extra_bads: Array[String]
) -> void:
	for idx: int in range(extra_goods.size()):
		_evaluator.record_good("FLIGHT_GOOD_%d" % idx, extra_goods[idx])
	for idx: int in range(extra_bads.size()):
		_evaluator.record_bad("FLIGHT_BAD_%d" % idx, extra_bads[idx])
	if hull_hp >= 75.0 and outcome == &"success":
		_evaluator.record_good("HULL_INTACT", "Regreso estructural integro (%.0f%% de casco)." % hull_hp)
	if science_collected > 0 and science_transmitted < int(round(float(science_collected) * 0.5)):
		_evaluator.record_bad("DSN_LOW_TX", "Ciencia recolectada (%d) quedo sin transmitirse por DSN (%d)." % [science_collected, science_transmitted])

	_show_debrief(outcome, science_collected, science_transmitted, repair_cost)


func _show_debrief(outcome: StringName, science_collected: int, science_transmitted: int, repair_cost: int) -> void:
	if _music != null:
		_music.set_phase(&"debrief")
	var payout := int(_active_body.get("base_payout", 1800))
	if outcome != &"success" and _build.insured:
		_evaluator.record_good("INSURANCE_PAYOUT", "Seguro de mision cubrio al menos 60%% del contrato tras incidente.")
	var report := _evaluator.build_report(outcome, science_collected, science_transmitted, payout, repair_cost)
	var net := int(report["net_credits"])
	var loan_msg := ""
	if outcome != &"success" and _build.insured:
		var floor_cover := int(round(float(payout) * 0.60))
		if net < floor_cover:
			var bonus_ins := floor_cover - net
			net = floor_cover
			loan_msg += " [+Seguro $%d]" % bonus_ins
	_credits += net

	if _loan_debt > 0 and net > 0:
		var pay := mini(_loan_debt, _credits)
		_loan_debt -= pay
		_credits -= pay
		loan_msg += " (-$%d amortizacion deuda)" % pay

	if _credits < 400:
		_credits += 1000
		_loan_debt += 1200
		loan_msg += " [+Prestamo Rescate $1000 / 20% int.]"

	var d := DebriefScreen.new()
	_swap_screen(d)
	d.setup(report, _credits, loan_msg)
	d.return_to_hangar.connect(_show_hangar)
