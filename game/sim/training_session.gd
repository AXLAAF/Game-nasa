class_name TrainingSession
extends RefCounted

## Sesión aislada: no conoce Run, Profile, Catalog, nodos ni reloj de pared.
## Las ecuaciones existentes se ejecutan con un paso fijo de 30 Hz.
const DT := 1.0 / 30.0
const PART_FIELDS := ["quality", "hidden_quality", "condition", "wear", "broken", "inspected", "revealed", "owned", "paid", "fuel", "ablative", "thrust_mult", "boost", "tuned", "deployed", "mount", "side"]

var design: Dictionary
var body: BodyDef
var definitions: Dictionary
var ship := ShipModel.new()
var rng: SimRng
var state: Dictionary = {
	"phase": "assembly", "tick": 0, "countdown": 0.0, "throttle": 1.0,
	"pitch": 0.0, "entry_angle": 0.0, "steered": false, "maxq_done": false,
	"separated": false, "jam_triggered": false, "repair_done": false,
	"upper_verified": false, "chute": 0, "battery": 1.0,
	"message": "", "log": [], "attempts": 0,
	"flight": {"x": 0.0, "h": 0.0, "vx": 0.0, "vy": 0.0, "q": 0.0, "g": 0.0},
}
var _checkpoint: Dictionary = {}

func _init(config: Dictionary, earth: BodyDef, parts: Dictionary) -> void:
	design = config.duplicate(true)
	body = earth.duplicate(true)
	definitions = parts.duplicate()
	rng = SimRng.new(int(design.seed))
	state.countdown = float(design.countdown)
	state.entry_angle = float(design.entry_default)
	_checkpoint = snapshot()

func assembly() -> Dictionary:
	return TrainingAssembly.evaluate(ship, design, body.surface_gravity)

func phase() -> String:
	return state.phase

func target_pitch() -> float:
	return RocketMath.ascent_pitch(state.flight.h, RocketMath.atmosphere_top(body))

func can_separate() -> bool:
	if not ship.can_stage() or ship.stage_fuel(ship.active_stage()) > float(design.fuel_epsilon):
		return false
	var upper: Array = ship.stages()[1]
	return ship.stage_thrust(upper) > 0.0 and ship.stage_fuel(upper) > float(design.fuel_epsilon)

func tick(commands: Array[PlayerCommand] = []) -> void:
	var axis := 0.0
	var steer := 0.0
	var acted := false
	for command: PlayerCommand in commands:
		if command.action == &"throttle":
			axis = clampf(command.value, -1.0, 1.0)
		elif command.action == &"steer":
			steer = clampf(command.value, -1.0, 1.0)
		elif not acted:
			# Una acción discreta por tick impide que doble clic salte una lección.
			acted = true
			if command.action == &"retry":
				var attempts := int(state.attempts) + 1
				_restore(_checkpoint)
				state.attempts = attempts
				return
			_act(command)
	state.tick += 1
	if phase() in ["ascent", "maxq", "power_restore", "upper_power", "deorbit", "descent"]:
		state.throttle = clampf(state.throttle + axis * float(design.throttle_rate) * DT, 0.0, 1.0)
	match phase():
		"countdown":
			state.countdown = maxf(0.0, state.countdown - DT)
		"steering":
			state.pitch += steer * float(design.turn_rate) * DT
			if steer != 0.0 and absf(state.pitch - target_pitch()) < float(design.corridor_tolerance):
				state.steered = true
				_record(tr("Orientaste el motor dentro del corredor de ascenso."))
				_enter("ascent")
		"maxq":
			if state.throttle <= float(design.q_throttle):
				state.maxq_done = true
				_record(tr("Redujiste potencia para limitar la carga aerodinámica."))
				_enter("power_restore")
		"power_restore":
			if state.throttle >= float(design.restore_throttle):
				_record(tr("Recuperaste potencia para sostener el ascenso tras el aviso preventivo."))
				_enter("ascent")
		"upper_power":
			if state.throttle >= float(design.upper_throttle) and ship.thrust() > 0.0:
				state.upper_verified = true
				_record(tr("Confirmaste motor y combustible de la segunda etapa."))
				_enter("ascent", true)
		"ascent":
			_ascent(steer)
		"retrograde":
			state.pitch = clampf(state.pitch + steer * float(design.turn_rate) * DT, -180.0, 180.0)
			if steer != 0.0 and absf(state.pitch + 90.0) < float(design.corridor_tolerance):
				state.pitch = -90.0
				_enter("deorbit", true)
		"deorbit":
			var acc := ship.burn(state.throttle, DT)
			state.flight.vx = maxf(0.0, state.flight.vx - acc * DT)
			if ship.stage_fuel(ship.active_stage()) <= float(design.fuel_epsilon):
				_fail(tr("Gastaste la reserva antes de terminar el frenado retrógrado."))
			elif state.flight.vx <= RocketMath.orbit_speed(body) * float(design.deorbit_speed_fraction):
				state.throttle = 0.0
				_record(tr("Frenaste contra el movimiento para iniciar el regreso."))
				_enter("entry", true)
		"entry":
			state.entry_angle = clampf(state.entry_angle + axis * DT * float(design.entry_rate), -30.0, -1.0)
		"descent":
			_descent()

func _act(command: PlayerCommand) -> void:
	state.message = ""
	if phase() == "assembly":
		match command.action:
			&"add":
				if definitions.has(String(command.part_id)):
					var part := ShipPart.new()
					part.def = definitions[String(command.part_id)]
					part.condition = rng.between(0.9, 0.99)
					part.refill()
					ship.parts.insert(clampi(command.index if command.index >= 0 else ship.parts.size(), 0, ship.parts.size()), part)
			&"remove":
				if command.index >= 0 and command.index < ship.parts.size():
					ship.parts.remove_at(command.index)
			&"move":
				if command.index >= 0 and command.index < ship.parts.size():
					var part: ShipPart = ship.parts.pop_at(command.index)
					ship.parts.insert(clampi(int(command.value), 0, ship.parts.size()), part)
			&"confirm":
				if assembly().ready:
					state.battery = Thermal.battery_capacity(ship)
					_record(tr("Montaste dos etapas con tanques independientes y protección de regreso."))
					_enter("countdown", true)
				else:
					state.message = tr("Completa el montaje y la revisión antes de despegar.")
		return
	if command.action == &"repair" and phase() == "jammed":
		state.repair_done = true
		_record(tr("Reparaste el cierre atascado antes de reintentar la separación."))
		_enter("stage_repaired")
	elif command.action == &"parachute":
		_deploy()
	elif command.action == &"confirm":
		match phase():
			"countdown":
				if state.countdown > 0.0:
					state.message = tr("Espera a T-0. Encender antes aumenta el esfuerzo del arranque.")
				else:
					_enter("ascent", true)
			"ascent", "stage_ready", "stage_repaired":
				_separate()
			"orbit":
				state.throttle = 0.0
				_enter("retrograde", true)
			"entry":
				if state.entry_angle < float(design.entry_min) or state.entry_angle > float(design.entry_max):
					state.message = tr("Ángulo fuera del corredor: ajusta antes de entrar.")
				else:
					var speed := float(state.flight.vx)
					state.flight.h = RocketMath.atmosphere_top(body)
					state.flight.vx = speed * cos(deg_to_rad(state.entry_angle))
					state.flight.vy = speed * sin(deg_to_rad(state.entry_angle))
					state.pitch = 0.0
					_record(tr("Elegiste un corredor de entrada dentro del margen de práctica."))
					_enter("descent", true)

func _separate() -> void:
	if not can_separate():
		state.message = tr("Espera: la etapa activa conserva combustible o la siguiente no tiene motor y tanque operativos. Mira combustible ACTIVO, no total.")
		return
	if not state.jam_triggered:
		_enter("stage_ready", true)
		state.jam_triggered = true
		_enter("jammed")
	elif state.repair_done and not state.separated:
		ship.drop_stage()
		state.separated = true
		state.throttle = 0.0
		_record(tr("Descartaste la etapa vacía sin perder el combustible superior."))
		_enter("upper_power")

func _ascent(steer: float) -> void:
	if not state.steered and state.flight.h >= float(design.steering_height):
		state.pitch = target_pitch() - float(design.corridor_tolerance) * 2.0
		_enter("steering")
		return
	if not state.maxq_done and state.flight.q >= float(design.maxq_warning):
		_enter("maxq")
		return
	if ship.stage_fuel(ship.active_stage()) <= float(design.fuel_epsilon):
		if can_separate():
			_enter("stage_ready", true)
		else:
			_fail(tr("Sin combustible en la etapa activa antes de alcanzar órbita."))
		return
	if steer == 0.0:
		state.pitch = target_pitch()
	else:
		state.pitch = clampf(state.pitch + steer * float(design.turn_rate) * DT, -30.0, 120.0)
	RocketMath.ascent_step(state.flight, ship, body, state.throttle, state.pitch, DT)
	_power()
	if phase() == "failed":
		return
	if state.flight.h < 0.0:
		_fail(tr("La nave perdió altura. Mantén suficiente potencia y sigue el corredor."))
	elif state.flight.h >= RocketMath.atmosphere_top(body) * float(design.orbit_height_fraction) and state.flight.vx >= RocketMath.orbit_speed(body) * float(design.orbit_speed_fraction) and state.flight.vy > float(design.orbit_min_vy):
		if state.separated and state.upper_verified:
			state.throttle = 0.0
			_record(tr("Alcanzaste órbita con reserva para el regreso."))
			_enter("orbit", true)

func _deploy() -> void:
	var speed := Vector2(state.flight.vx, state.flight.vy).length()
	if phase() not in ["descent", "drogue_ready", "main_ready"]:
		state.message = tr("El paracaídas se usa durante el descenso, dentro de su ventana segura.")
		return
	if state.chute == 0 and speed <= float(design.drogue_speed):
		state.chute = 1
		_record(tr("Abriste el freno dentro de su límite de velocidad."))
		_enter("descent", true)
	elif state.chute == 1 and speed <= float(design.main_speed) and state.flight.h <= float(design.main_height):
		state.chute = 2
		_record(tr("Desplegaste el principal con velocidad y altura seguras."))
		_enter("descent", true)
	else:
		state.message = tr("Todavía no: abrir fuera de la ventana segura puede romper el paracaídas.")

func _descent() -> void:
	var speed := Vector2(state.flight.vx, state.flight.vy).length()
	if state.chute == 0 and speed <= float(design.drogue_speed):
		_enter("drogue_ready")
		return
	if state.chute == 1 and speed <= float(design.main_speed) and state.flight.h <= float(design.main_height):
		_enter("main_ready")
		return
	var area := ship.sum_stat(&"drag") * (float(design.main_area_mult) if state.chute == 2 else float(design.drogue_area_mult) if state.chute == 1 else 0.0)
	RocketMath.descent_step(state.flight, ship, body, state.throttle, 0.0, 0.0, area, 0.0, DT)
	var heat := RocketMath.entry_heat(body, state.flight.h, speed) * DT * float(design.shield_use)
	for part: ShipPart in ship.parts:
		if part.def.kind == &"heatshield":
			var absorbed := minf(part.ablative, heat)
			part.ablative -= absorbed
			heat -= absorbed
	if heat > 0.0:
		_fail(tr("Se agotó el escudo térmico durante la entrada. Repite desde el corredor."))
		return
	_power()
	if phase() == "failed":
		return
	if state.flight.h <= 0.0:
		state.flight.h = 0.0
		if speed <= float(design.safe_landing_speed) and state.chute == 2:
			_record(tr("Aterrizaste a %.1f m/s [DIS]. Reserva final: %.1f t de combustible.") % [speed, ship.fuel_total()])
			_enter("complete")
		else:
			_fail(tr("Impacto demasiado rápido. Despliega las dos fases del paracaídas en sus ventanas."))

func _power() -> void:
	state.battery = clampf(state.battery + (Thermal.power_gen(1.0, ship) - Thermal.power_use(ship)) * DT * float(design.power_time_scale), 0.0, Thermal.battery_capacity(ship))
	if state.battery <= 0.0:
		_fail(tr("Sin energía para la electrónica. Revisa generación y batería."))

func _fail(reason: String) -> void:
	_enter("failed")
	state.message = reason

func _record(message: String) -> void:
	state.log.append(message)

func _enter(next: String, checkpoint: bool = false) -> void:
	state.phase = next
	state.message = ""
	if checkpoint:
		_checkpoint = snapshot()

func snapshot() -> Dictionary:
	var parts: Array = []
	for part: ShipPart in ship.parts:
		var data := {"id": String(part.def.id)}
		for field: String in PART_FIELDS:
			data[field] = part.get(field)
		parts.append(data)
	return {"state": state.duplicate(true), "parts": parts, "rng": rng.generator.state}

func _restore(saved: Dictionary) -> void:
	state = saved.state.duplicate(true)
	rng.generator.state = saved.rng
	ship = ShipModel.new()
	for data: Dictionary in saved.parts:
		var part := ShipPart.new()
		part.def = definitions[data.id]
		for field: String in PART_FIELDS:
			part.set(field, data[field])
		ship.parts.append(part)
