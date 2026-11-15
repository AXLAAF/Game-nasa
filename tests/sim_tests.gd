extends RefCounted

var passed := 0
var failed := 0
var rng := RandomNumberGenerator.new()
var root: Window


func run(tree_root: Window) -> int:
	root = tree_root
	rng.seed = 7
	_test_catalog()
	_test_auto_index()
	_test_checklist()
	_test_ship_math()
	_test_staging()
	_test_reliability()
	_test_part_states()
	_test_assist_and_time()
	_test_arcade()
	_test_nav_burn()
	_test_tutorial()
	_test_part_viability()
	_test_starfield_palettes()
	_test_kinetic()
	_test_thermal()
	_test_gravity()
	_test_odds()
	_test_contracts()
	_test_atmosphere()
	_test_ascent()
	_test_entry()
	print("Results: %d passed, %d failed" % [passed, failed])
	return failed


func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)


func near(a: float, b: float, tolerance: float, label: String) -> void:
	check(absf(a - b) <= tolerance, "%s (got %.3f, want %.3f)" % [label, a, b])


func _catalog() -> Node:
	return root.get_node("Catalog")


func _make(ids: Array, quality: int = ShipPart.Quality.NEW) -> ShipModel:
	var ship := ShipModel.new()
	for id: Variant in ids:
		var def: PartDef = _catalog().part(StringName(str(id)))
		check(def != null, "part exists: %s" % id)
		if def != null:
			ship.parts.append(ShipPart.create(def, quality, rng))
	return ship


func _test_catalog() -> void:
	var catalog := _catalog()
	check(catalog.parts.size() >= 23, "catalog parts loaded")
	check(catalog.bodies.size() >= 7, "catalog bodies loaded")
	check(catalog.star() != null and catalog.home() != null, "star and home exist")
	check(catalog.body(&"titan") != null and catalog.body(&"titan").parent_id == &"saturno", "titan orbits saturn")
	check(catalog.body(&"tierra") != null and catalog.body(&"tierra").is_home, "earth is home")
	check(catalog.part(&"giroscopio") != null and catalog.part(&"escudo_ligero") != null, "new parts exist")
	check(not catalog.malfunctions_for(&"engine").is_empty(), "engine malfunctions")
	check(not catalog.malfunctions_for(&"rtg").is_empty(), "generic malfunction fallback")
	check(not catalog.encounters_for(&"signal", 2).is_empty(), "legendary signal encounter")
	check(not catalog.encounters_for(&"derelict", 1).is_empty(), "pirate cache rarity")
	check(not catalog.encounters_for(&"comet", 1).is_empty(), "crystal comet")


func _test_auto_index() -> void:
	var ship := ShipModel.new()
	var add_auto := func(def: PartDef) -> void:
		ship.parts.insert(ship.auto_index(def), ShipPart.create(def, ShipPart.Quality.NEW, rng))
	add_auto.call(_catalog().part(&"capsula"))
	add_auto.call(_catalog().part(&"motor_trueno"))
	add_auto.call(_catalog().part(&"tanque_largo"))
	check(ship.parts.map(func(part: ShipPart) -> StringName: return part.def.kind) == [&"engine", &"tank", &"capsule"], "auto index starter stack")
	add_auto.call(_catalog().part(&"paracaidas"))
	add_auto.call(_catalog().part(&"escudo_termico"))
	check(ship.parts.map(func(part: ShipPart) -> StringName: return part.def.kind) == [&"engine", &"tank", &"heatshield", &"capsule", &"parachute"], "auto index landing stack")
	add_auto.call(_catalog().part(&"desacoplador"))
	add_auto.call(_catalog().part(&"motor_susurro"))
	add_auto.call(_catalog().part(&"tanque_corto"))
	check(ship.parts.map(func(part: ShipPart) -> StringName: return part.def.kind) == [&"engine", &"tank", &"decoupler", &"engine", &"tank", &"heatshield", &"capsule", &"parachute"], "auto index second stage")
	check(ship.can_stage() and ship.stage_thrust(ship.stages().back()) > 0.0, "auto index creates active upper stage")
	var radial: PartDef = _catalog().part(&"panel_solar")
	check(ship.auto_index(radial) == ship.parts.size(), "auto index radial goes last")


func _test_checklist() -> void:
	var assembly_script: GDScript = load("res://game/phases/assembly.gd")
	var c := Contract.new()
	c.target = &"luna"
	c.dv_estimate = 3500.0
	var luna: BodyDef = _catalog().body(&"luna")
	var marte: BodyDef = _catalog().body(&"marte")
	var empty := ShipModel.new()
	var rows: Array[Dictionary] = assembly_script.checklist(empty, c, luna, 0)
	check(String(rows[0].label) == "Cápsula" and int(rows[0].state) == Lamp.WARNING and bool(rows[0].blocks), "checklist capsule blocks")
	var lift: Dictionary = {}
	for row: Dictionary in rows:
		if row.label == "Levanta el vuelo":
			lift = row
	check(int(lift.state) == Lamp.OFF, "checklist lift waits for propulsion")
	var over: Array[Dictionary] = assembly_script.checklist(empty, c, luna, -1)
	var budget: Dictionary = {}
	for row: Dictionary in over:
		if row.label == "Presupuesto":
			budget = row
	check(bool(budget.blocks), "checklist budget blocks")
	var ready := ShipModel.new()
	for id: StringName in [&"capsula", &"motor_trueno", &"tanque_largo"]:
		var def: PartDef = _catalog().part(id)
		ready.parts.insert(ready.auto_index(def), ShipPart.create(def, ShipPart.Quality.NEW, rng))
	var ready_rows: Array[Dictionary] = assembly_script.checklist(ready, c, luna, 0)
	var blocked := false
	for row: Dictionary in ready_rows:
		blocked = blocked or bool(row.blocks)
	check(not blocked, "checklist starter ship can launch")
	var marte_rows: Array[Dictionary] = assembly_script.checklist(ready, c, marte, 0)
	var shield: Dictionary = {}
	for row: Dictionary in marte_rows:
		if row.label == "Escudo térmico":
			shield = row
	check(int(shield.state) == Lamp.WARNING and String(shield.hint) != "", "checklist atmosphere explains heat shield")


func _test_ship_math() -> void:
	var ship := _make(["motor_trueno", "tanque_largo", "tanque_largo", "escudo_termico", "capsula", "paracaidas"])
	var m0 := ship.mass()
	near(m0, 3.0 + 2 * 10.0 + 0.7 + 2.2 + 0.2, 0.01, "wet mass")
	var expected := 270.0 * 9.81 * log(m0 / (m0 - 18.0))
	near(ship.delta_v(), expected, 1.0, "rocket equation")
	check(ship.twr(9.81) > 1.2, "starter ship lifts off")
	var acc := ship.burn(1.0, 1.0)
	near(acc, 460.0 / m0, 0.01, "burn acceleration")
	check(ship.fuel_total() < 18.0, "burn consumes fuel")
	var leak_before := ship.fuel_total()
	ship.leak(0.5)
	near(ship.fuel_total(), leak_before * 0.5, 0.01, "leak halves fuel")


func _test_staging() -> void:
	var ship := _make(["motor_trueno", "tanque_ancho", "desacoplador", "motor_susurro", "tanque_corto", "capsula"])
	check(ship.stages().size() == 2, "two stages")
	var dvs := ship.stage_dvs()
	check(dvs[0] > 0.0 and dvs[1] > 0.0, "both stages have dv")
	var top_mass := 0.6 + 0.5 + 4.0 + 2.2
	near(dvs[1], 360.0 * 9.81 * log(top_mass / (top_mass - 4.0)), 1.0, "upper stage dv")
	var dropped := ship.drop_stage()
	check(dropped.size() == 3 and ship.parts.size() == 3, "drop stage removes bottom + decoupler")
	check(not ship.can_stage(), "single stage left")
	var dry := _make(["motor_trueno", "tanque_corto", "desacoplador", "motor_chispa", "tanque_corto", "capsula"])
	dry.active_stage()[1].fuel = 0.0
	check(dry.auto_stage(), "auto stage drops a dry stage")
	var no_engine := _make(["tanque_corto", "capsula"])
	check(no_engine.burn(1.0, 1.0) == 0.0, "no engine, no thrust")
	var pod := _make(["motor_trueno", "tanque_largo", "escudo_termico", "capsula", "paracaidas", "torre_escape"])
	check(pod.eject_capsule() and pod.parts.size() == 4, "eject keeps capsule, shield, chute and tower")
	var mount := _make(["tanque_largo", "panel_solar", "sensores", "antena", "capsula"])
	mount.parts[1].mount = 0.2
	mount.parts[1].side = -1
	mount.parts[2].mount = 0.8
	mount.parts[2].side = 1
	mount.parts[3].mount = 0.5
	mount.parts[3].side = 0
	var rects := ShipRenderer.layout(mount.parts)
	check(rects[1].end.x <= 0.0, "left-side solar sits on the left")
	check(rects[2].position.x >= 0.0, "right-side sensor sits on the right")
	check(rects[2].position.y < rects[1].position.y, "higher mount sits higher on the tank")
	check(ShipRenderer.host_index(mount.parts, 2) == 0, "radials anchor to the tank below them")


func _test_reliability() -> void:
	var def: PartDef = _catalog().part(&"motor_trueno")
	var scrap := ShipPart.create(def, ShipPart.Quality.SCRAP, rng)
	var fresh := ShipPart.create(def, ShipPart.Quality.NEW, rng)
	check(scrap.fail_chance(1.0) > fresh.fail_chance(1.0), "scrap fails more than new")
	check(scrap.price() < fresh.price(), "scrap is cheaper")
	fresh.broken = true
	check(fresh.fail_chance(1.0) == 0.0 and fresh.thrust() == 0.0, "broken part has no thrust and cannot fail again")
	var mystery := ShipPart.create(def, ShipPart.Quality.MYSTERY, rng)
	check(not mystery.revealed and mystery.quality_text() == "?", "mystery hidden")
	check(mystery.reveal() and mystery.quality_text() != "?", "mystery reveals")
	var restored := ShipPart.from_dict(scrap.to_dict())
	check(restored != null and is_equal_approx(restored.condition, scrap.condition) and restored.owned, "inventory round trip")
	var ship := _make(["motor_trueno", "tanque_largo", "capsula"], ShipPart.Quality.SCRAP)
	var span := Odds.ship_reliability(ship)
	check(span.x <= span.y and span.y <= 1.0, "reliability range ordered")


func _test_part_states() -> void:
	var def: PartDef = _catalog().part(&"motor_trueno")
	var part := ShipPart.create(def, ShipPart.Quality.NEW, rng)
	part.condition = 0.95
	part.wear = 0.0
	var full := part.thrust()
	check(part.health() == ShipPart.Health.SOUND and is_equal_approx(part.output(), 1.0), "sound part at full output")
	part.wear = 0.3
	check(part.health() == ShipPart.Health.WORN and part.thrust() < full and part.thrust() > full * 0.7, "wear steps to worn and cuts thrust")
	part.wear = 0.6
	check(part.health() == ShipPart.Health.FAULTY and part.thrust() < full * 0.7, "more wear steps to faulty")
	part.broken = true
	check(part.health() == ShipPart.Health.BROKEN and part.thrust() == 0.0, "broken is the last state")
	var run := root.get_node("Run")
	run.rng.seed = 3
	run.respite = 0.0
	run.ship = _make(["computadora", "sensores", "antena", "bateria", "capsula"], ShipPart.Quality.SCRAP)
	for p: ShipPart in run.ship.parts:
		p.condition = 0.05
		p.wear = 1.0
		p.broken = false
	var hits := 0
	for _i: int in 30:
		run.respite = 0.0
		for p: ShipPart in run.ship.parts:
			p.broken = false
		var failed: Array = run.roll_stress(1.0)
		check(failed.size() <= 1, "a critical moment breaks at most one part")
		hits += failed.size()
	check(hits > 0, "a wreck can still fail")
	run.respite = 5.0
	check(run.roll_stress(1.0).is_empty(), "respite skips the next critical")
	run.respite = 0.0
	run.ship.parts[0].broken = true
	check(run.roll_stress(1.0).is_empty(), "an open failure blocks the next one")
	var computer: ShipPart = run.ship.parts[0]
	computer.broken = false
	computer.condition = 0.3
	computer.wear = 0.0
	check(computer.health() == ShipPart.Health.FAULTY and Run.channel(&"map") < 0.85, "faulty computer degrades the map")


func _test_nav_burn() -> void:
	var tip := RocketMath.nav_burn(Vector2.ZERO, Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 20.0)
	check(tip.phase == &"boost" and tip.need > 1.0 and absf(tip.aim) < 0.2, "far target asks for a boost toward +X")
	var hot := RocketMath.nav_burn(Vector2.ZERO, Vector2(30, 0), Vector2(40, 0), Vector2.ZERO, 20.0)
	check(hot.phase == &"brake" and hot.need > 0.5, "fast closing asks for a brake")
	var soft := RocketMath.nav_burn(Vector2(10, 0), Vector2(1, 0), Vector2(12, 0), Vector2.ZERO, 20.0)
	check(soft.phase == &"capture" or soft.need < 3.0, "near and slow is capture/coast")


func _tutorial_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text = (node as Label).text
	for child: Node in node.get_children():
		text += " " + _tutorial_text(child)
	return text


func _test_tutorial() -> void:
	var total := 0
	for phase: StringName in Tutorial.ORDER:
		var steps: Array = Tutorial.STEPS[phase]
		check(steps.size() >= 2, "tutorial chapter %s" % phase)
		total += steps.size()
		for step: Array in steps:
			check(String(step[0]).length() > 0 and String(step[1]).length() > 40, "tutorial step has text")
	check(total >= 10 and total <= 14, "tutorial covers the whole loop concisely")
	var seen: Array[String] = Profile.tutorial_seen.duplicate()
	Tutorial.replay()
	var panel := Tutorial._open as Tutorial
	check(panel != null, "tutorial panel opens")
	if panel != null:
		var text := _tutorial_text(panel)
		check(text.contains("Contratos"), "first step explains contracts")
		check(text.contains("1 / "), "step counter is visible")
		panel._advance()
		check(_tutorial_text(panel).contains("Seguro"), "next step explains insurance")
		panel._back()
		check(_tutorial_text(panel).contains("Contratos"), "tutorial can step back")
		panel._jump_to(&"descent")
		check(_tutorial_text(panel).contains("Corredor"), "tutorial can jump to chapter")
		panel.get_parent().remove_child(panel)
		panel.free()
	Tutorial._open = null
	root.get_tree().paused = false
	Profile.tutorial_seen.erase("hangar")
	Tutorial.offer(&"hangar")
	var chapter := Tutorial._open as Tutorial
	check(chapter != null and _tutorial_text(chapter).contains("Contratos"), "a phase opens only its own chapter")
	if chapter != null:
		chapter.get_parent().remove_child(chapter)
		chapter.free()
	Tutorial._open = null
	root.get_tree().paused = false
	Profile.tutorial_seen = seen
	Profile.tutorial_seen.append("hangar")
	Tutorial.offer(&"hangar")
	check(Tutorial._open == null, "a finished chapter does not reopen")
	Profile.tutorial_seen = seen


func _test_part_viability() -> void:
	var run := root.get_node("Run")
	var profile := root.get_node("Profile")
	var old_credits := int(profile.credits)
	var old_contract: Contract = run.contract
	var old_parts: Array[ShipPart] = run.ship.parts.duplicate()
	var assembly_script: GDScript = load("res://game/phases/assembly.gd")
	var asm: Node = assembly_script.new()
	var c := Contract.new()
	c.target = &"luna"
	c.dv_estimate = 3500.0
	c.payout = 1000
	c.advance = 300
	run.begin(c)
	profile.credits = 2000
	var chute: PartDef = _catalog().part(&"paracaidas")
	var v_luna: Dictionary = asm.part_viability(chute)
	check(v_luna.badge == "NO NECESARIA" and v_luna.affordable, "parachute not needed on airless moon")
	c.target = &"marte"
	var v_marte: Dictionary = asm.part_viability(chute)
	check(v_marte.badge == "NECESARIA" and v_marte.affordable, "parachute needed on Mars")
	c.target = &"titan"
	var solar: PartDef = _catalog().part(&"panel_solar")
	var v_ice: Dictionary = asm.part_viability(solar)
	check(v_ice.badge == "POCO VIABLE", "solar panel warned on distant ice moon")
	run.spent = profile.budget(c)
	var rtg: PartDef = _catalog().part(&"rtg")
	var v_broke: Dictionary = asm.part_viability(rtg)
	check(v_broke.badge == "NO VIABLE" and not v_broke.affordable, "over-budget part flagged non-viable")
	asm.free()
	profile.credits = old_credits
	run.contract = old_contract
	run.ship.parts = old_parts


func _test_starfield_palettes() -> void:
	var seen_idx := {}
	for i: int in 7:
		var c := Contract.new()
		c.title = "Misión %d" % i
		c.cargo = "Carga %d" % i
		c.payout = 1000 + i * 250
		c.target = [&"luna", &"mercurio", &"marte", &"jupiter", &"titan", &"venus", &"tierra"][i]
		var p := Starfield.palette_for(c, i)
		check(p.col is Color and p.accent is Color and p.warm is Color, "palette %d returns colors" % i)
		seen_idx[int(p.index)] = true
	check(seen_idx.size() >= 3, "mission starfield palettes vary across contracts")


func _test_kinetic() -> void:
	var was_reduced := bool(Profile.reduced_motion)
	Profile.reduced_motion = false
	var pos := 0.0
	var vel := 0.0
	for _i: int in 45:
		var step := Kinetic.spring_step(pos, vel, 1.0, 0.016)
		pos = step.x
		vel = step.y
	check(absf(pos - 1.0) < 0.05 and absf(vel) < 0.25, "kinetic spring converges toward target")
	Profile.reduced_motion = true
	var snap := Kinetic.spring_step(0.0, 4.0, 1.0, 0.016)
	check(is_equal_approx(snap.x, 1.0) and is_equal_approx(snap.y, 0.0), "reduced_motion snaps spring immediately")
	var btn := Button.new()
	var panel := PanelContainer.new()
	root.add_child(panel)
	root.add_child(btn)
	Kinetic.bind_button(btn)
	Kinetic.enter(panel, 0.0, {"beam": true})
	check(panel.visible and is_equal_approx(panel.modulate.a, 1.0), "reduced_motion enter shows panel cleanly")
	Kinetic.fold_toggle(panel, false)
	check(not panel.visible, "reduced_motion fold_toggle hides immediately")
	Kinetic.fold_toggle(panel, true)
	check(panel.visible, "reduced_motion fold_toggle reveals immediately")
	root.remove_child(btn)
	btn.free()
	root.remove_child(panel)
	panel.free()
	Profile.reduced_motion = was_reduced


func _test_assist_and_time() -> void:
	var profile := root.get_node("Profile")
	var run := root.get_node("Run")
	check(Run.TIME_SCALES.size() >= 6, "six time scales")
	near(Run.time_scale(0), 0.5, 0.001, "slow time")
	near(Run.time_scale(1), 1.0, 0.001, "normal time")
	near(Run.time_scale(5), 50.0, 0.001, "max time")
	check(Run.time_label(0) == "x0.5" and Run.time_label(3).begins_with("x"), "time labels")
	var was := bool(profile.assist)
	var was_arcade := bool(profile.arcade)
	profile.arcade = false
	profile.assist = false
	var def: PartDef = _catalog().part(&"motor_trueno")
	var part := ShipPart.create(def, ShipPart.Quality.SCRAP, rng)
	part.condition = 0.4
	part.wear = 0.4
	var hard := part.fail_chance(1.0)
	profile.assist = true
	var soft := part.fail_chance(1.0)
	check(soft < hard and is_equal_approx(soft, hard * 0.55), "assist cuts fail chance")
	near(run.assist_payout_mult(), 0.85, 0.001, "assist payout cut")
	profile.assist = was
	profile.arcade = was_arcade


func _test_arcade() -> void:
	var profile := root.get_node("Profile")
	var run := root.get_node("Run")
	var cat := _catalog()
	var was_arcade := bool(profile.arcade)
	var was_assist := bool(profile.assist)
	profile.assist = false
	profile.arcade = false
	var sim_budget := float(profile.budget(null))
	var sim_rate := float(profile.premium_rate())
	var sim_payout := float(run.assist_payout_mult())
	profile.arcade = true
	near(float(profile.budget(null)), sim_budget, 0.001, "arcade keeps budget identical")
	near(float(profile.premium_rate()), sim_rate, 0.001, "arcade keeps insurance premium identical")
	near(float(run.assist_payout_mult()), sim_payout, 0.001, "arcade keeps payout multiplier identical")
	var bodies: Array[BodyDef] = cat.body_list()
	var tierra: BodyDef = cat.body(&"tierra")
	var SpaceScript := load("res://game/phases/space.gd") as GDScript
	var p0 := Gravity.body_pos(tierra, 0.0) + Vector2(tierra.radius * 3.0, 0.0)
	var v0 := Vector2(12.0, -8.0)
	var st := {"pos": p0, "vel": v0, "t": 0.0}
	SpaceScript.arcade_space_step(st, 2.0, bodies, Vector2.ZERO)
	check((st.vel as Vector2).is_equal_approx(v0), "arcade space preserves exact velocity with zero gravity")
	check((st.pos as Vector2).is_equal_approx(p0 + v0 * 2.0), "arcade space integrates pure inertia")
	SpaceScript.arcade_space_step(st, 1.0, bodies, Vector2(5.0, 0.0))
	check((st.vel as Vector2).is_equal_approx(v0 + Vector2(5.0, 0.0)), "arcade space accelerates along thrust")
	run.debug_setup()
	for p: ShipPart in run.ship.active_stage():
		if p.fuel > 0.0:
			p.fuel = 0.0
	var ctrl := root.get_node("Controls")
	var space: Node2D = SpaceScript.new()
	root.add_child(space)
	var v_start: Vector2 = space.st.vel
	for i: int in 15:
		ctrl._key_just[KEY_D] = true
		space._process(1.0 / 60.0)
	var dv_push := (space.st.vel as Vector2) - v_start
	check(space.burning and dv_push.x > 10.0, "arcade space pushes laterally with WASD even after dry stage 0")
	check(space.warp_i == 1, "arcade space keeps 1x time speed while burning instead of 0.5x")
	check(space._pred.is_empty(), "arcade space draws no ship orbit prediction")
	ctrl._key_just.clear()
	var v_coast: Vector2 = space.st.vel
	for i: int in 15:
		space._process(1.0 / 60.0)
	check((space.st.vel as Vector2).is_equal_approx(v_coast), "arcade space holds inertial velocity after releasing WASD")
	root.remove_child(space)
	space.free()
	var DescentScript := load("res://game/phases/descent.gd") as GDScript
	var ship := _make(["motor_trueno", "tanque_ancho", "capsula", "paracaidas"])
	var fuel0 := ship.fuel_total()
	var d_free := {"x": 0.0, "h": 3500.0, "vx": 0.0, "vy": -45.0}
	DescentScript.arcade_descent_step(d_free, ship, tierra, 0.0, 0.0, 0.0, 0.0, 1.0)
	check(float(d_free.vy) < -45.0, "arcade descent falls under local gravity without input")
	near(ship.fuel_total(), fuel0, 0.001, "arcade descent spends no fuel while falling idle")
	var d_brake := {"x": 0.0, "h": 3500.0, "vx": 0.0, "vy": -45.0}
	DescentScript.arcade_descent_step(d_brake, ship, tierra, 0.0, 1.0, 0.0, 0.0, 1.0)
	check(float(d_brake.vy) > float(d_free.vy), "arcade descent W brakes vertical fall with engines")
	var d_right := {"x": 0.0, "h": 3500.0, "vx": 0.0, "vy": -45.0}
	DescentScript.arcade_descent_step(d_right, ship, tierra, 1.0, 0.0, 0.0, 0.0, 1.0)
	check(float(d_right.vx) > 5.0, "arcade descent D steers trajectory right with engines")
	var d_left := {"x": 0.0, "h": 3500.0, "vx": 0.0, "vy": -45.0}
	DescentScript.arcade_descent_step(d_left, ship, tierra, -1.0, 0.0, 0.0, 0.0, 1.0)
	check(float(d_left.vx) < -5.0, "arcade descent A steers trajectory left with engines")
	profile.assist = was_assist
	profile.arcade = was_arcade


func _test_thermal() -> void:
	var bare := _make(["capsula"])
	near(Thermal.flux(2000.0), 1.0, 0.001, "flux at home")
	near(Thermal.equilibrium(1.0, bare), 0.5, 0.001, "comfortable at home")
	check(Thermal.equilibrium(Thermal.flux(950.0), bare) > Thermal.HOT, "too hot near Ignea without radiator")
	var cooled := _make(["capsula", "radiador", "radiador"])
	check(Thermal.equilibrium(Thermal.flux(950.0), cooled) < Thermal.HOT, "radiators fix Ignea")
	check(Thermal.equilibrium(Thermal.flux(5600.0), bare) < Thermal.COLD, "freezing at Glacia")
	var warm := _make(["capsula", "aislante", "rtg"])
	check(Thermal.equilibrium(Thermal.flux(5600.0), warm) > Thermal.COLD, "insulation + rtg fix Glacia")
	var solar := _make(["capsula", "panel_solar"])
	check(Thermal.power_gen(1.0, solar) > Thermal.power_gen(0.1, solar), "solar weaker far away")


func _test_gravity() -> void:
	var home: BodyDef = _catalog().home()
	var bodies: Array[BodyDef] = _catalog().body_list()
	var r := home.radius * 2.0
	var pos := Gravity.body_pos(home, 0.0) + Vector2(r, 0)
	var vel := Gravity.body_vel(home, 0.0) + Vector2(0, sqrt(home.mu / r))
	var state := {"pos": pos, "vel": vel, "t": 0.0}
	var hit := &""
	for i: int in 300:
		hit = Gravity.step(state, 0.1, bodies, Vector2.ZERO)
		if hit != &"":
			break
	var dist: float = (state.pos as Vector2).distance_to(Gravity.body_pos(home, state.t))
	check(hit == &"", "parking orbit does not crash")
	near(dist, r, r * 0.3, "parking orbit roughly circular")
	check(Gravity.dominant(pos, 0.0, bodies) == home, "home dominates parking orbit")
	var fall := {"pos": Gravity.body_pos(home, 0.0) + Vector2(r, 0), "vel": Gravity.body_vel(home, 0.0), "t": 0.0}
	var crashed := &""
	for i: int in 400:
		crashed = Gravity.step(fall, 0.1, bodies, Vector2.ZERO)
		if crashed != &"":
			break
	check(crashed == home.id, "dropping from rest hits home")
	var luna: BodyDef = _catalog().body(&"luna")
	near(Gravity.body_pos(luna, 3.0).distance_to(Gravity.body_pos(home, 3.0)), luna.orbit_radius, 0.01, "moon rides its parent")


func _test_odds() -> void:
	var span := Odds.fog(0.5, false)
	check(span.x < 0.5 and span.y > 0.5, "fog widens odds")
	check(Odds.fog(0.5, true) == Vector2(0.5, 0.5), "scan clears fog")
	near(Odds.streak_mult(4), 2.0, 0.001, "streak multiplier")
	var hits := 0
	for i: int in 2000:
		if Odds.roll(0.3, rng):
			hits += 1
	near(hits / 2000.0, 0.3, 0.04, "roll matches chance")


func _test_contracts() -> void:
	var list := Contract.generate(rng, 3)
	check(list.size() == 3, "three contracts")
	for c: Contract in list:
		check(c.payout > 0 and c.advance < c.payout, "contract pays")
		check(c.dv_estimate > RocketMath.LAUNCH_DV, "contract dv above launch")
		var body := c.body()
		check(body != null and body.landable and not body.is_home, "contract target landable")
		var back := Contract.from_dict(c.to_dict())
		check(back.target == c.target and back.payout == c.payout, "contract round trip")
	var luna_dv := RocketMath.mission_dv(_catalog().body(&"luna"))
	var titan_dv := RocketMath.mission_dv(_catalog().body(&"titan"))
	check(titan_dv > luna_dv, "far targets need more dv")


## Piloto automatico que sigue el corredor: devuelve el dv que sobra en orbita, o -1.
func _autopilot(ship: ShipModel) -> float:
	var home: BodyDef = _catalog().home()
	var top := RocketMath.atmosphere_top(home)
	var v_orb := RocketMath.orbit_speed(home)
	var s := {"x": 0.0, "h": 0.0, "vx": 0.0, "vy": 0.0, "q": 0.0}
	for i: int in 20000:
		var throttle := 0.6 if s.q > 28000.0 else 1.0
		ship.auto_stage()
		RocketMath.ascent_step(s, ship, home, throttle, RocketMath.ascent_pitch(s.h, top), 0.05)
		if s.h >= top * 0.8 and s.vx >= v_orb * 0.97 and s.vy > -60.0:
			return ship.delta_v()
		if s.h < 0.0 and i > 20:
			return -1.0
	return -1.0


func _test_ascent() -> void:
	var two_stage := _make(["motor_trueno", "tanque_ancho", "desacoplador", "motor_susurro", "tanque_largo", "escudo_termico", "capsula", "paracaidas"])
	var left := _autopilot(two_stage)
	print("  ascenso 2 etapas: dv sobrante %d m/s" % int(left))
	check(left > 300.0, "two-stage ship reaches orbit with dv to spare")
	var starter := _make(["motor_trueno", "tanque_largo", "tanque_largo", "escudo_termico", "capsula", "paracaidas"])
	var full := starter.delta_v()
	var starter_left := _autopilot(starter)
	print("  ascenso inicial: dv total %d, sobrante %d m/s" % [int(full), int(starter_left)])
	check(starter_left > 0.0, "starter ship reaches orbit")
	print("  costo ascenso %d (LAUNCH_DV %d)" % [int(full - starter_left), int(RocketMath.LAUNCH_DV)])
	check(absf(full - starter_left - RocketMath.LAUNCH_DV) < 350.0, "ascent costs about LAUNCH_DV")


func _test_atmosphere() -> void:
	var home: BodyDef = _catalog().home()
	check(RocketMath.density(home, 0.0) > RocketMath.density(home, 10000.0), "air thins with altitude")
	check(RocketMath.atmosphere_top(home) > 25000.0, "atmosphere top")
	near(RocketMath.effective_gravity(home, RocketMath.orbit_speed(home)), 0.0, 0.01, "orbital speed cancels gravity")
	check(RocketMath.entry_heat(home, 20000.0, 2000.0) > RocketMath.entry_heat(home, 20000.0, 1000.0), "faster entry is hotter")
	var v := RocketMath.hohmann(2.88e7, 2000.0, 3300.0)
	check(v.x > 0.0 and v.y > 0.0, "hohmann burns positive")


## Entrada balistica sin motor con el modelo de escudo de descent.gd.
## Devuelve {skip, shield (ablativo gastado), hull (calor que pasa al casco)}.
func _entry(ship: ShipModel, body: BodyDef, gamma: float, v0: float) -> Dictionary:
	var top := RocketMath.atmosphere_top(body)
	var rad := deg_to_rad(gamma)
	var s := {"x": 0.0, "h": top, "vx": v0 * cos(rad), "vy": v0 * sin(rad)}
	var out := {"skip": false, "shield": 0.0, "hull": 0.0}
	var dt := 0.1
	for i: int in 40000:
		RocketMath.descent_step(s, ship, body, 0.0, 0.0, 0.0, 0.0, 0.0, dt)
		var rate := RocketMath.entry_heat(body, s.h, Vector2(s.vx, s.vy).length())
		out.shield += minf(rate, 0.6) * dt * 0.22
		out.hull += maxf(rate - 0.6, 0.0) * dt * 0.6
		if s.h > top * 1.03 and s.vy > 0.0:
			out.skip = true
			return out
		if s.h < 3000.0:
			break
	return out


func _test_entry() -> void:
	var ship := _make(["escudo_termico", "capsula", "paracaidas"])
	for id: StringName in [&"marte", &"venus", &"tierra"]:
		var body: BodyDef = _catalog().body(id)
		var v0 := RocketMath.orbit_speed(body) * 1.12
		var edge := RocketMath.skip_edge(ship, body, v0)
		var shallow := _entry(ship, body, edge + 1.0, v0)
		var good := _entry(ship, body, edge - 2.5, v0)
		var steep := _entry(ship, body, edge - 12.0, v0)
		var inner := _entry(ship, body, edge - 4.0, v0)
		check(not inner.skip and inner.hull < 1.0, "%s: steep edge of the corridor survives" % id)
		print("  entrada %s: borde %.1f | corredor escudo %.1f casco %.2f | empinada casco %.2f" % [id, edge, good.shield, good.hull, steep.hull])
		check(shallow.skip, "%s: shallower than the edge skips out" % id)
		check(not good.skip and good.shield < 30.0 and good.hull < 1.0, "%s: corridor entry survives on one shield" % id)
		check(steep.hull > good.hull, "%s: steep entry overheats the hull more" % id)
	var marte: BodyDef = _catalog().body(&"marte")
	var area := ship.area() * 1.3 * 1.1 + 300.0 * 3.0
	var terminal := sqrt(2.0 * ship.mass() * 1000.0 * marte.surface_gravity / (RocketMath.density(marte, 0.0) * area))
	print("  paracaidas en marte: %.1f m/s" % terminal)
	check(terminal < 11.0, "one main chute lands on Rubra without crashing")
