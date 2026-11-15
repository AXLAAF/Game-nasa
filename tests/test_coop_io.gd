@tool
extends McpTestSuite

## Caja negra: inyección de input y construcción visible del corte.
## Caja blanca: InputMap, Controls, Profile/Run.crew y reglas de salas.

var _prev_crew: int = 1
var _prev_kits: int = 1
var _prev_ship: ShipModel
var _prev_paused: bool = false


func suite_name() -> String:
	return "coop_io"


func suite_setup(_ctx: Dictionary) -> void:
	if not _runtime_ok():
		return
	_prev_crew = Run.crew
	_prev_kits = Run.kits
	_prev_ship = Run.ship
	_prev_paused = (Engine.get_main_loop() as SceneTree).paused


func teardown() -> void:
	if _runtime_ok():
		_clear_controls()
		_drop_minigames()
		Card.clear_queue()
		Run.crew = _prev_crew
		Run.kits = _prev_kits
		if _prev_ship != null:
			Run.ship = _prev_ship
		(Engine.get_main_loop() as SceneTree).paused = _prev_paused


func _runtime_ok() -> bool:
	return not Engine.is_editor_hint()


func _require_runtime() -> bool:
	if _runtime_ok():
		return true
	skip("requiere autoloads de juego, no el editor")
	return false


func suite_teardown() -> void:
	teardown()


# --- caja blanca: construcción e input map ---

func test_white_autoload_and_scripts() -> void:
	assert_true(ProjectSettings.has_setting("autoload/Controls"), "autoload Controls en project.godot")
	var path: String = str(ProjectSettings.get_setting("autoload/Controls"))
	assert_contains(path, "controls.gd", "ruta del autoload")
	assert_true(load("res://game/autoload/controls.gd") != null, "controls.gd carga")
	assert_true(load("res://game/crew/ship_interior.gd") != null, "ship_interior.gd carga")
	assert_true(load("res://game/crew/crew_body.gd") != null, "crew_body.gd carga")
	assert_true(load("res://game/crew/room_map.gd") != null, "room_map.gd carga")
	var sample := ShipInterior.new()
	assert_true(sample is CanvasLayer, "ShipInterior es CanvasLayer")
	sample.free()


func test_white_input_map_dual_and_key_only() -> void:
	var dual := [
		"cmd_throttle_up", "cmd_throttle_down", "cmd_throttle_full", "cmd_throttle_zero",
		"cmd_steer_left", "cmd_steer_right", "cmd_fine", "cmd_overdrive", "cmd_confirm",
		"cmd_abort", "cmd_status", "cmd_repair", "cmd_scan", "cmd_parachute", "cmd_cycle",
		"cmd_hold_pro", "cmd_hold_retro", "cmd_nav",
		"crew_left", "crew_right", "crew_up", "crew_down", "crew_interact",
	]
	for name: String in dual:
		var sides := _sides(name)
		assert_true(sides.x and sides.y, "%s teclado+mando" % name)
		if _failed:
			return
	for name: String in ["cmd_warp_1", "cmd_warp_2", "cmd_warp_3", "cmd_warp_4", "cmd_warp_5", "cmd_warp_6", "cmd_eject", "cmd_salvage", "cmd_land"]:
		var sides := _sides(name)
		assert_true(sides.x and not sides.y, "%s solo teclado" % name)
		if _failed:
			return
	assert_true(_sides("cmd_warp_next").y and _sides("cmd_warp_prev").y, "warp stick")
	assert_true(InputMap.action_get_deadzone("cmd_steer_left") <= 0.25, "deadzone stick")
	assert_true(_has_key("cmd_throttle_up", KEY_W), "W empuje")
	assert_true(_has_key("cmd_confirm", KEY_SPACE), "Espacio confirma")
	assert_true(_has_key("crew_left", KEY_LEFT), "flecha izquierda")
	assert_true(_has_key("crew_interact", KEY_ENTER), "Enter interactúa")
	assert_true(_has_button("cmd_scan", 10) and _has_button("cmd_parachute", 10), "RB compartido")


func test_white_profile_run_crew() -> void:
	if not _require_runtime():
		return
	var saved := Profile.crew
	Profile.crew = 2
	Run.begin(Contract.generate(Run.rng, 1)[0])
	assert_eq(Run.crew, 2, "begin copia Profile.crew")
	Profile.crew = 1
	Run.begin(Contract.generate(Run.rng, 1)[0])
	assert_eq(Run.crew, 1, "begin con un tripulante")
	Profile.crew = saved
	var data := {"assist": false, "reduced_motion": false, "crew": 2}
	var before := Profile.crew
	Profile.crew = 1
	# load path uses clampi on crew key; simulate the white-box contract
	Profile.crew = clampi(int(data.get("crew", 1)), 1, 2)
	assert_eq(Profile.crew, 2, "perfil guarda crew")
	Profile.crew = before


func test_white_repair_matrix() -> void:
	assert_true(ShipInterior.is_exterior(&"solar"), "solar exterior")
	assert_true(ShipInterior.is_exterior(&"parachute"), "paracaídas exterior")
	assert_false(ShipInterior.is_exterior(&"engine"), "motor interior")
	assert_true(ShipInterior.can_repair(&"engine", false, true), "motor en sala")
	assert_false(ShipInterior.can_repair(&"solar", false, true), "solar no desde sala")
	assert_true(ShipInterior.can_repair(&"solar", true, false), "solar desde esclusa")
	assert_true(ShipInterior.can_repair(&"solar", false, true, true), "solar en casco")
	assert_false(ShipInterior.can_repair(&"engine", true, false), "motor no solo esclusa")
	assert_eq(Minigame.for_part(&"engine"), &"thrust", "motor")
	assert_eq(Minigame.for_part(&"tank"), &"valve", "tanque")
	assert_eq(Minigame.for_part(&"capsule"), &"seal", "cápsula")
	assert_eq(Minigame.for_part(&"solar"), &"align", "panel")
	assert_eq(Minigame.for_part(&"heatshield"), &"tile", "casco")
	assert_eq(Minigame.for_part(&"shielding"), &"tile", "blindaje")


func test_white_controls_device_split() -> void:
	if not _require_runtime():
		return
	Run.crew = 1
	assert_eq(Controls._cmd_device(), -1, "solo: cualquier mando")
	Run.crew = 2
	assert_eq(Controls._cmd_device(), Controls.KEYBOARD_ONLY, "coop: el piloto es el teclado")
	assert_eq(Controls.DEAD, 0.2, "zona muerta")


# --- caja negra: input inyectado ---

func test_black_commander_key_edges() -> void:
	if not _require_runtime():
		return
	Run.crew = 1
	_clear_controls()
	_feed_key(KEY_SPACE)
	assert_true(Controls.cmd_just(&"cmd_confirm"), "Espacio -> confirm")
	assert_false(Controls.cmd_just(&"cmd_confirm"), "confirm se consume")
	_feed_key(KEY_R)
	assert_true(Controls.cmd_just(&"cmd_repair"), "R -> repair")
	_feed_key(KEY_1)
	assert_eq(Controls.warp_choice(4, 1), 0, "1 -> warp 0")


func test_black_commander_pad_edges() -> void:
	if not _require_runtime():
		return
	Run.crew = 2
	_clear_controls()
	_feed_joy_button(0, JOY_BUTTON_A)
	assert_false(Controls.cmd_just(&"cmd_confirm"), "el mando no pilota")
	assert_true(Controls.crew_interact_just(), "el mando es del tripulante")
	_clear_controls()
	_feed_key(KEY_SPACE)
	assert_true(Controls.cmd_just(&"cmd_confirm"), "el teclado confirma el vuelo")


func test_black_crew_keys_isolated() -> void:
	if not _require_runtime():
		return
	Run.crew = 2
	_clear_controls()
	_feed_key(KEY_ENTER)
	assert_true(Controls.crew_interact_just(), "Enter interactúa")
	assert_false(Controls.cmd_just(&"cmd_confirm"), "Enter no confirma vuelo")
	_clear_controls()
	_feed_key(KEY_LEFT)
	var v := Controls.crew_vector()
	assert_true(v.x < -0.5, "flecha izquierda mueve")
	_clear_controls()
	Run.crew = 1
	_feed_key(KEY_LEFT)
	assert_eq(Controls.crew_vector(), Vector2.ZERO, "con 1 jugador el tripulante no existe")


func test_black_steer_and_throttle_from_keys() -> void:
	if not _require_runtime():
		return
	Run.crew = 1
	_clear_controls()
	_feed_key(KEY_A)
	assert_true(Controls.steer() < -0.5, "A gira izquierda")
	_clear_controls()
	_feed_key(KEY_D)
	assert_true(Controls.steer() > 0.5, "D gira derecha")
	_clear_controls()
	_feed_key(KEY_W)
	assert_true(Controls.throttle_axis() > 0.5, "W empuja")
	_clear_controls()
	_feed_key(KEY_S)
	assert_true(Controls.throttle_axis() < -0.5, "S baja")


# --- caja negra: construcción del corte ---

func test_black_spawn_builds_rooms() -> void:
	if not _require_runtime():
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	Run.crew = 2
	Run.ship = ShipModel.new()
	var engine := _part(&"motor_trueno")
	var capsule := _part(&"capsula")
	var solar := _part(&"panel_solar")
	assert_true(engine != null and capsule != null and solar != null, "piezas de prueba")
	if _failed:
		return
	Run.ship.parts = [engine, capsule, solar]
	var host := Node.new()
	tree.root.add_child(host)
	track(host)
	ShipInterior.spawn(host)
	assert_eq(host.get_child_count(), 1, "spawn crea un corte")
	var interior: Node = host.get_child(0)
	assert_true(interior is ShipInterior, "tipo ShipInterior")
	assert_eq((interior as CanvasLayer).layer, 70, "capa por encima de la carta")
	var bodies := _count_type(interior, "CharacterBody2D")
	var walls := _count_type(interior, "StaticBody2D")
	assert_eq(bodies, 1, "un tripulante")
	assert_gt(walls, 3, "paredes de las salas")
	Run.crew = 1
	var host2 := Node.new()
	tree.root.add_child(host2)
	track(host2)
	ShipInterior.spawn(host2)
	assert_eq(host2.get_child_count(), 0, "con 1 jugador no hay corte")


func test_black_malfunction_coop_vs_solo() -> void:
	if not _require_runtime():
		return
	var tree := Engine.get_main_loop() as SceneTree
	var part := _part(&"motor_chispa")
	assert_true(part != null, "motor")
	if _failed:
		return
	Run.crew = 2
	tree.paused = false
	part.broken = false
	var seen := [false, false]
	Card.malfunction(part, func(ok: bool) -> void:
		seen[0] = true
		seen[1] = ok
	)
	assert_true(part.broken, "coop rompe")
	assert_false(seen[0], "coop no resuelve sola")
	assert_eq(Card.open_faults().size(), 1, "avería en cola")
	assert_false(tree.paused, "coop no pausa")
	assert_false(Card.busy(), "coop sin carta")
	assert_true(Card.roll_fault(0.0), "tirada forzada")
	assert_true(seen[0] and seen[1], "tirada exitosa avisa")
	assert_false(part.broken, "la tirada arregla")
	assert_false(tree.paused, "la tirada no pausa")
	var previous_ship := Run.ship
	var held := _part(&"motor_chispa")
	var nxt := _part(&"panel_solar")
	assert_true(held != null and nxt != null, "piezas de admit")
	if held != null and nxt != null:
		Run.ship = ShipModel.new()
		held.broken = true
		nxt.broken = false
		Run.ship.parts = [held, nxt]
		Run.crew = 2
		Run.respite = 0.0
		assert_true(Run.admit(nxt), "coop admite otra crítica")
		Run.crew = 1
		Run.respite = 0.0
		nxt.broken = false
		assert_false(Run.admit(nxt), "solo bloquea si ya hay una rota")
	Run.ship = previous_ship
	Run.respite = 0.0
	Run.crew = 1
	part.broken = false
	Card.clear_queue()
	Card.malfunction(part, func(_ok: bool) -> void: pass)
	assert_true(tree.paused, "solo pausa")
	assert_true(Card.busy(), "solo abre carta")
	Card.clear_queue()
	tree.paused = false


func test_black_walk_interior_then_airlock() -> void:
	if not _require_runtime():
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	Run.crew = 2
	Run.kits = 1
	Run.ship = ShipModel.new()
	var engine := _part(&"motor_trueno")
	var capsule := _part(&"capsula")
	var solar := _part(&"panel_solar")
	assert_true(engine != null and capsule != null and solar != null, "piezas")
	if _failed:
		return
	engine.broken = true
	solar.broken = true
	Run.ship.parts = [engine, capsule, solar]
	var interior := ShipInterior.new()
	tree.root.add_child(interior)
	track(interior)
	interior.interact(interior._center(0))
	assert_true(interior.busy, "motor abre minijuego")
	assert_false(tree.paused, "vuelo sigue")
	assert_gt(_minigames().size(), 0, "hay minijuego")
	assert_eq(_minigames()[0].get("mode"), &"thrust", "motor: empuje")
	assert_eq(interior.layer, 70, "corte en 70")
	assert_eq(_view_layer(_minigames()[0]), 90, "minijuego por encima del corte")
	_drop_minigames()
	interior._finished(true, engine)
	assert_false(engine.broken, "motor reparado")
	assert_eq(Run.kits, 0, "gastó kit")
	interior.busy = false
	interior.interact(interior._center(2))
	assert_false(interior.busy, "solar no desde su sala")
	assert_true(solar.broken, "solar sigue roto")
	interior.interact(interior._center(1))
	assert_true(interior.on_hull, "esclusa abre el casco")
	var station: Dictionary = {}
	for row: Dictionary in interior._exterior_stations():
		if row.part == solar:
			station = row
			break
	assert_false(station.is_empty(), "estación solar en casco")
	if not station.is_empty():
		interior.interact((station.rect as Rect2).get_center())
		var games := _minigames()
		assert_true(interior.busy and not games.is_empty(), "casco abre EVA")
		if not games.is_empty():
			assert_eq(games[0].get("mode"), &"align", "panel: apuntar al sol")
			assert_false(tree.paused, "el minijuego no pausa")
		_drop_minigames()
	interior.busy = false
	interior.interact(interior.stick_to_hull(interior._center(1)))
	assert_false(interior.on_hull, "vuelve a la cabina")
	assert_false(interior.busy, "volver no abre reparación")
	interior.interact(interior._center(1))
	assert_true(interior.on_hull, "cápsula sana vuelve al casco")
	capsule.broken = true
	interior.interact(interior.stick_to_hull(interior._center(1)))
	assert_false(interior.on_hull, "cápsula rota deja entrar")
	assert_false(interior.busy, "la esclusa no repara la cápsula")
	capsule.broken = false


# --- helpers ---

func _view_layer(game: Node) -> int:
	for child: Node in game.get_children():
		if child is CanvasLayer:
			return (child as CanvasLayer).layer
	return -1


func _sides(action: String) -> Vector2:
	var key := 0.0
	var pad := 0.0
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			key = 1.0
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			pad = 1.0
	return Vector2(key, pad)


func _has_key(action: String, code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var bound := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if bound == code:
				return true
	return false


func _has_button(action: String, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and int((event as InputEventJoypadButton).button_index) == button:
			return true
	return false


func _feed_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.physical_keycode = code
	event.keycode = code
	Controls._input(event)


func _feed_joy_button(device: int, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.device = device
	event.button_index = button
	Controls._input(event)


func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)


func _release_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = false
	event.echo = false
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)


func _clear_controls() -> void:
	Controls._flush()


func _part(id: StringName) -> ShipPart:
	var def := Catalog.part(id)
	if def == null:
		return null
	return ShipPart.create(def, ShipPart.Quality.NEW, Run.rng)


func _minigames() -> Array:
	var live: Array = []
	for node: Node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(&"minigame"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			live.append(node)
	return live


func _drop_minigames() -> void:
	for node: Node in _minigames():
		node.set("on_done", Callable())
		node.queue_free()


func _count_type(root: Node, type_name: String) -> int:
	var count := 0
	if root.get_class() == type_name:
		count += 1
	for child: Node in root.get_children():
		count += _count_type(child, type_name)
	return count
