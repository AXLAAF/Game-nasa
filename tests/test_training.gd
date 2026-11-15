@tool
extends McpTestSuite

func suite_name() -> String:
	return "training"

static func built(extra: bool = false) -> TrainingSession:
	var sim := TrainingData.create_session()
	for step: Dictionary in sim.design.recipe:
		sim.tick([PlayerCommand.new(&"add", 0, StringName(step.id))])
	if extra:
		sim.tick([PlayerCommand.new(&"add", 0, &"antena")])
	return sim

## Piloto de prueba: usa los mismos comandos y condiciones visibles al jugador.
static func pilot(sim: TrainingSession) -> Array[PlayerCommand]:
	match sim.phase():
		"assembly", "countdown", "stage_ready", "stage_repaired", "orbit":
			return [PlayerCommand.new(&"confirm")]
		"steering":
			return [PlayerCommand.new(&"steer", 1)]
		"maxq":
			return [PlayerCommand.new(&"throttle", -1)]
		"jammed":
			return [PlayerCommand.new(&"repair")]
		"power_restore", "upper_power", "deorbit":
			return [PlayerCommand.new(&"throttle", 1)]
		"ascent":
			var value := -1.0 if sim.state.flight.q > float(sim.design.maxq) else 1.0
			return [PlayerCommand.new(&"throttle", value)]
		"retrograde":
			return [PlayerCommand.new(&"steer", -1)]
		"entry":
			if sim.state.entry_angle > -12.0:
				return [PlayerCommand.new(&"throttle", -1)]
			return [PlayerCommand.new(&"confirm")]
		"drogue_ready", "main_ready":
			return [PlayerCommand.new(&"parachute")]
	return []

static func fly_to(sim: TrainingSession, target: String, limit: int = 50000) -> void:
	for i: int in limit:
		if sim.phase() in [target, "failed", "complete"]:
			return
		sim.tick(pilot(sim))

func test_recipe_and_wrong_order() -> void:
	var sim := TrainingData.create_session()
	sim.tick([PlayerCommand.new(&"add", 0, &"capsula")])
	assert_eq(sim.assembly().index, 0, "cabina no sustituye motor inicial")
	assert_false(sim.assembly().ready)
	sim.tick([PlayerCommand.new(&"remove", 0, &"", 0)])
	for step: Dictionary in sim.design.recipe:
		sim.tick([PlayerCommand.new(&"add", 0, StringName(step.id))])
	assert_true(sim.assembly().ready, str(sim.assembly()))
	sim.tick([PlayerCommand.new(&"move", 1, &"", 0)])
	assert_false(sim.assembly().ready, "mover invalida y recalcula")
	sim.tick([PlayerCommand.new(&"move", 0, &"", 1)])
	assert_true(sim.assembly().ready)
	sim.tick([PlayerCommand.new(&"remove", 0, &"", 4)])
	assert_eq(sim.assembly().index, 4, "tanque superior eliminado")

func test_each_stage_requires_working_engine_and_fuel() -> void:
	var sim := built()
	sim.ship.parts[4].fuel = 0
	assert_false(sim.assembly().ready)
	assert_false(sim.can_separate())
	sim.ship.parts[1].fuel = 0
	assert_false(sim.can_separate(), "tanque de arriba vacío")
	sim.ship.parts[4].refill()
	sim.ship.parts[3].broken = true
	assert_false(sim.can_separate(), "motor de arriba roto")
	assert_false(sim.assembly().ready)

func test_early_separation_and_jammed_retry() -> void:
	var sim := built()
	fly_to(sim, "ascent")
	var before := sim.ship.parts.size()
	sim.tick([PlayerCommand.new(&"confirm")])
	assert_eq(sim.ship.parts.size(), before, "no descartar combustible útil")
	assert_contains(sim.state.message, "Espera")
	fly_to(sim, "stage_ready")
	assert_eq(sim.phase(), "stage_ready", str(sim.state))
	var upper_fuel := sim.ship.parts[4].fuel
	var snapshot := sim.snapshot()
	sim.tick([PlayerCommand.new(&"confirm"), PlayerCommand.new(&"confirm")])
	assert_eq(sim.phase(), "jammed")
	sim.tick([PlayerCommand.new(&"confirm")])
	assert_eq(sim.ship.parts.size(), before)
	sim.tick([PlayerCommand.new(&"repair")])
	sim.tick([PlayerCommand.new(&"confirm"), PlayerCommand.new(&"confirm")])
	assert_eq(sim.ship.stages().size(), 1, "una separación por acción")
	assert_eq(sim.ship.fuel_total(), upper_fuel, "preserva combustible superior")
	var discarded_ship := sim.ship
	sim.tick([PlayerCommand.new(&"retry")])
	assert_eq(sim.phase(), "stage_ready")
	assert_ne(sim.ship, discarded_ship, "restaura objetos independientes")
	assert_eq(sim.snapshot().parts, snapshot.parts)
	sim.tick([PlayerCommand.new(&"confirm")])
	assert_eq(sim.phase(), "jammed", "avería reproducible después de reintentar")

func test_complete_two_configurations_and_replay() -> void:
	for extra: bool in [false, true]:
		var sim := built(extra)
		var replay := built(extra)
		assert_true(sim.assembly().ready)
		var visited: Dictionary = {}
		for i: int in 50000:
			visited[sim.phase()] = true
			if sim.phase() in ["complete", "failed"]: break
			var commands := pilot(sim)
			sim.tick(commands)
			replay.tick(commands)
		assert_eq(sim.phase(), "complete", "variante %s: %s" % [extra, sim.state])
		assert_eq(sim.snapshot(), replay.snapshot(), "misma semilla y comandos")
		for phase: String in ["steering", "maxq", "jammed", "stage_repaired", "upper_power", "orbit", "retrograde", "deorbit", "entry", "drogue_ready", "main_ready"]:
			assert_true(visited.has(phase), "lección realizada: %s" % phase)
		assert_gt(sim.ship.fuel_total(), 0.0, "reserva al aterrizar")
		print("Training variant=", extra, " ticks=", sim.state.tick, " fuel=", sim.ship.fuel_total(), " h=", sim.state.flight.h)

func test_frozen_prompts_and_unsafe_entry() -> void:
	var sim := built()
	fly_to(sim, "stage_ready")
	var flight: Dictionary = sim.state.flight.duplicate()
	for i: int in 90: sim.tick()
	assert_eq(sim.state.flight, flight, "leer no deja caer el cohete")
	fly_to(sim, "entry")
	sim.tick([PlayerCommand.new(&"confirm")])
	assert_eq(sim.phase(), "entry", "ángulo inseguro interceptado")
	assert_contains(sim.state.message, "fuera")

func test_campaign_isolation() -> void:
	if Engine.is_editor_hint():
		skip("La comprobación del perfil requiere runtime")
		return
	var before := [Profile.credits, Profile.inventory.duplicate(true), Profile.contracts.duplicate(true), Profile.runs, Profile.lessons.duplicate(), Run.ship, Run.spent, Profile.training_completed]
	var sim := built()
	fly_to(sim, "complete")
	sim.tick([PlayerCommand.new(&"retry")])
	var after := [Profile.credits, Profile.inventory.duplicate(true), Profile.contracts.duplicate(true), Profile.runs, Profile.lessons.duplicate(), Run.ship, Run.spent, Profile.training_completed]
	assert_eq(before, after, "simular y reintentar no escribe en la campaña")

func test_unsafe_chute_and_retry_after_failure() -> void:
	var sim := built()
	fly_to(sim, "entry")
	sim.tick([PlayerCommand.new(&"parachute")])
	assert_eq(sim.state.chute, 0, "no abrir antes de entrar")
	fly_to(sim, "descent")
	sim.tick([PlayerCommand.new(&"parachute")])
	assert_eq(sim.state.chute, 0, "no abrir por encima del límite")
	var saved := sim._checkpoint.duplicate(true)
	# Inyección de daño para verificar la recuperación del fallo térmico.
	for part: ShipPart in sim.ship.parts:
		part.ablative = 0.0
	sim.tick()
	assert_eq(sim.phase(), "failed")
	sim.tick([PlayerCommand.new(&"retry")])
	assert_eq(sim.phase(), "descent")
	assert_eq(sim.snapshot().parts, saved.parts, "escudo y combustible restaurados")
	assert_eq(sim.state.flight, saved.state.flight, "sin avance físico al restaurar")

func test_view_catalog_uses_commands() -> void:
	if Engine.is_editor_hint():
		skip("La vista requiere runtime")
		return
	var view: Node = load("res://game/phases/training.gd").new()
	track(view)
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.set_process(false)
	var before := Profile.credits
	view._part_buttons["motor_trueno"].pressed.emit()
	assert_eq(view.session.ship.parts.size(), 0, "el botón solo encola")
	view._process(TrainingSession.DT)
	assert_eq(view.session.ship.parts.size(), 1, "la sesión procesa el comando")
	assert_eq(view.session.assembly().index, 1)
	assert_eq(Profile.credits, before)
	assert_true(view._confirm.disabled, "despegue incompleto bloqueado")

func test_novice_follows_only_prompted_power_changes() -> void:
	var sim := built()
	for i: int in 50000:
		if sim.phase() in ["complete", "failed"]: break
		var commands := pilot(sim)
		if sim.phase() == "ascent": commands.clear()
		sim.tick(commands)
	assert_eq(sim.phase(), "complete", "sin piloto automático de potencia: %s" % sim.state)

func test_completion_is_separate_and_runner_does_not_write_profile() -> void:
	if Engine.is_editor_hint():
		skip("La persistencia requiere runtime")
		return
	var enabled := Profile.persistence_enabled
	var completed := Profile.training_completed
	var seen: Array = Profile.tutorial_seen.duplicate()
	var before := FileAccess.get_file_as_string(Profile.PATH) if FileAccess.file_exists(Profile.PATH) else ""
	Profile.persistence_enabled = false
	Profile.training_completed = false
	Profile.complete_training()
	assert_true(Profile.training_completed)
	assert_eq(Profile.tutorial_seen, seen, "completar práctica no marca páginas vistas")
	var after := FileAccess.get_file_as_string(Profile.PATH) if FileAccess.file_exists(Profile.PATH) else ""
	assert_eq(after, before, "el runner no escribe en el perfil real")
	Profile.training_completed = completed
	Profile.persistence_enabled = enabled
