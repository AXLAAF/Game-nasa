extends RefCounted

## Acciones de mando, reglas de reparación y averías en cooperativo.

const COMMAND := [
	"cmd_throttle_up", "cmd_throttle_down", "cmd_throttle_full", "cmd_throttle_zero",
	"cmd_steer_left", "cmd_steer_right", "cmd_fine", "cmd_overdrive", "cmd_confirm",
	"cmd_abort", "cmd_status", "cmd_repair", "cmd_scan", "cmd_parachute", "cmd_cycle",
	"cmd_hold_pro", "cmd_hold_retro", "cmd_nav", "cmd_warp_next", "cmd_warp_prev",
	"cmd_warp_1", "cmd_warp_2", "cmd_warp_3", "cmd_warp_4", "cmd_warp_5", "cmd_warp_6",
	"cmd_eject", "cmd_salvage", "cmd_land", "cmd_snap",
]
const CREW := ["crew_left", "crew_right", "crew_up", "crew_down", "crew_interact", "crew_join", "crew_leave"]
const DUAL := [
	"cmd_throttle_up", "cmd_throttle_down", "cmd_throttle_full", "cmd_throttle_zero",
	"cmd_steer_left", "cmd_steer_right", "cmd_fine", "cmd_overdrive", "cmd_confirm",
	"cmd_abort", "cmd_status", "cmd_repair", "cmd_scan", "cmd_parachute", "cmd_cycle",
	"cmd_hold_pro", "cmd_hold_retro", "cmd_nav",
	"crew_left", "crew_right", "crew_up", "crew_down", "crew_interact", "crew_join", "crew_leave",
]
const KEY_ONLY := ["cmd_warp_1", "cmd_warp_2", "cmd_warp_3", "cmd_warp_4", "cmd_warp_5", "cmd_warp_6", "cmd_eject", "cmd_salvage", "cmd_land"]
const SHARED_BUTTONS := {
	10: [&"cmd_scan", &"cmd_parachute"],
	0: [&"cmd_confirm", &"crew_interact", &"crew_join"],
	1: [&"cmd_abort", &"crew_leave"],
	3: [&"cmd_throttle_full", &"cmd_snap"],
}
const SHARED_AXES := {
	"0:-1": [&"cmd_steer_left", &"crew_left"],
	"0:1": [&"cmd_steer_right", &"crew_right"],
	"1:-1": [&"cmd_throttle_up", &"crew_up"],
	"1:1": [&"cmd_throttle_down", &"crew_down"],
}


func run() -> int:
	var failed := 0
	failed += _bindings()
	failed += _repair_rules()
	failed += _coop_break()
	failed += _event_card()
	failed += _hull_motion()
	failed += await _walk_repair()
	print("Coop: %d failed" % failed)
	return failed


func _bindings() -> int:
	var failed := 0
	for name: String in COMMAND + CREW:
		if not InputMap.has_action(name) or InputMap.action_get_events(name).is_empty():
			push_error("FAIL sin acción %s" % name)
			failed += 1
	if InputMap.action_get_deadzone("cmd_steer_left") > 0.25:
		push_error("FAIL zona muerta del giro")
		failed += 1
	for name: String in DUAL:
		var sides := _sides(name)
		if not sides.x or not sides.y:
			push_error("FAIL %s necesita teclado y mando" % name)
			failed += 1
	for name: String in KEY_ONLY:
		var sides := _sides(name)
		if not sides.x or sides.y:
			push_error("FAIL %s debía ser solo teclado" % name)
			failed += 1
	if _sides("cmd_warp_next").y < 1 or _sides("cmd_warp_prev").y < 1:
		push_error("FAIL el tiempo no tiene mando")
		failed += 1
	if not _has_key("cmd_throttle_up", KEY_W) or not _has_key("cmd_confirm", KEY_SPACE):
		push_error("FAIL el teclado del comandante cambió")
		failed += 1
	if not _has_key("crew_interact", KEY_ENTER) or not _has_key("crew_left", KEY_LEFT):
		push_error("FAIL el teclado del tripulante")
		failed += 1
	failed += _conflicts()
	return failed


func _sides(action: String) -> Vector2:
	var key := 0.0
	var pad := 0.0
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			key = 1.0
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			pad = 1.0
	return Vector2(key, pad)


func _conflicts() -> int:
	var failed := 0
	var buttons := {}
	var axes := {}
	for name: String in COMMAND + CREW:
		for event: InputEvent in InputMap.action_get_events(name):
			if event is InputEventJoypadButton:
				var button := int((event as InputEventJoypadButton).button_index)
				if not buttons.has(button):
					buttons[button] = []
				buttons[button].append(StringName(name))
			elif event is InputEventJoypadMotion:
				var motion := event as InputEventJoypadMotion
				var sign := -1 if motion.axis_value < 0.0 else 1
				var id := "%d:%d" % [int(motion.axis), sign]
				if not axes.has(id):
					axes[id] = []
				axes[id].append(StringName(name))
	for button: int in buttons:
		var owners: Array = buttons[button]
		if owners.size() < 2:
			continue
		var allowed: Array = SHARED_BUTTONS.get(button, [])
		if not _same_names(owners, allowed):
			push_error("FAIL botón %d compartido: %s" % [button, owners])
			failed += 1
	for id: String in axes:
		var owners: Array = axes[id]
		if owners.size() < 2:
			continue
		var allowed: Array = SHARED_AXES.get(id, [])
		if not _same_names(owners, allowed):
			push_error("FAIL eje %s compartido: %s" % [id, owners])
			failed += 1
	return failed


func _same_names(owners: Array, allowed: Array) -> bool:
	if owners.size() != allowed.size():
		return false
	for name: StringName in owners:
		if not allowed.has(name):
			return false
	return true


func _has_key(action: String, code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var bound := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if bound == code:
				return true
	return false


func _repair_rules() -> int:
	var failed := 0
	if not ShipInterior.can_repair(&"engine", false, true):
		push_error("FAIL el motor se repara en su sala")
		failed += 1
	if ShipInterior.can_repair(&"solar", false, true):
		push_error("FAIL el panel solar no se repara desde dentro")
		failed += 1
	if not ShipInterior.can_repair(&"solar", true, false):
		push_error("FAIL el casco se repara desde la esclusa")
		failed += 1
	if not ShipInterior.can_repair(&"solar", true, false, true):
		push_error("FAIL el casco se repara en el exterior")
		failed += 1
	if ShipInterior.can_repair(&"engine", true, false):
		push_error("FAIL el motor no se repara desde la esclusa si no estás en su sala")
		failed += 1
	return failed


func _coop_break() -> int:
	var failed := 0
	var previous := Run.crew
	Run.crew = 2
	var tree := Engine.get_main_loop() as SceneTree
	var was_paused := tree.paused
	tree.paused = false
	var part := _part(&"motor_chispa")
	if part == null:
		Run.crew = previous
		return 1
	part.broken = false
	var seen := [false, false]
	Card.malfunction(part, func(ok: bool) -> void:
		seen[0] = true
		seen[1] = ok
	)
	if not part.broken or seen[0] or tree.paused or Card.busy() or Card.open_faults().size() != 1:
		push_error("FAIL la avería de dos jugadores pausó, resolvió sola o no rompió la pieza")
		failed += 1
	if not Card.roll_fault(0.0) or not seen[0] or not seen[1] or part.broken or tree.paused or Card.busy():
		push_error("FAIL la tirada del comandante no arregló en tiempo real")
		failed += 1
	var previous_ship := Run.ship
	var previous_respite := Run.respite
	var held := _part(&"motor_chispa")
	var nxt := _part(&"panel_solar")
	if held == null or nxt == null:
		failed += 1
	else:
		Run.ship = ShipModel.new()
		held.broken = true
		nxt.broken = false
		Run.ship.parts = [held, nxt]
		Run.crew = 2
		Run.respite = 0.0
		if not Run.admit(nxt):
			push_error("FAIL con dos jugadores una avería abierta bloquea la siguiente")
			failed += 1
		Run.crew = 1
		Run.respite = 0.0
		nxt.broken = false
		if Run.admit(nxt):
			push_error("FAIL con un jugador admitió otra crítica")
			failed += 1
	Run.ship = previous_ship
	Run.respite = previous_respite
	Run.crew = 1
	tree.paused = false
	part.broken = false
	Card.clear_queue()
	Card.malfunction(part, func(_ok: bool) -> void: pass)
	if not tree.paused or not Card.busy():
		push_error("FAIL con un jugador la carta de avería no detuvo el vuelo")
		failed += 1
	Card.clear_queue()
	tree.paused = was_paused
	Run.crew = previous
	return failed


func _event_card() -> int:
	var failed := 0
	var previous := Run.crew
	var tree := Engine.get_main_loop() as SceneTree
	var was_paused := tree.paused
	var was_scale := Engine.time_scale
	Run.crew = 2
	tree.paused = true
	Engine.time_scale = 0.03
	var choice := ChoiceDef.new()
	choice.label = "Aguantar la llamarada"
	choice.odds = 0.4
	choice.lose = {"rand_break": true}
	Card.show_card({
		"title": "Llamarada solar",
		"text": "Una tormenta de protones.",
		"tone": &"malfunction",
		"choices": [choice],
	})
	if tree.paused or is_equal_approx(Engine.time_scale, 0.03) or not Card.busy():
		push_error("FAIL el evento de dos jugadores dejó el juego parado")
		failed += 1
	var button := _find_button(Card._open, "Aguantar la llamarada")
	if button == null or button.disabled:
		push_error("FAIL el comandante no puede elegir el evento")
		failed += 1
	Card.clear_queue()
	tree.paused = was_paused
	Engine.time_scale = was_scale
	Run.crew = previous
	return failed


func _hull_motion() -> int:
	var failed := 0
	var previous_crew := Run.crew
	var previous_ship := Run.ship
	Run.crew = 2
	Run.ship = ShipModel.new()
	var capsule := _part(&"capsula")
	var engine := _part(&"motor_trueno")
	if capsule == null or engine == null:
		_restore(previous_crew, Run.kits, previous_ship, false)
		return 1
	Run.ship.parts = [engine, capsule]
	var box := ShipRenderer.bounds(Run.ship.parts)
	var interior := ShipInterior.new()
	var top := interior.stick_to_hull(Vector2(box.get_center().x, box.position.y))
	var moved := interior.stick_to_hull(top + Vector2(24.0, 0.0))
	if moved.distance_to(top) < 8.0:
		push_error("FAIL el tripulante no avanza por el casco")
		failed += 1
	Run.crew = previous_crew
	Run.ship = previous_ship
	return failed


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _walk_repair() -> int:
	var failed := 0
	var previous_crew := Run.crew
	var previous_kits := Run.kits
	var previous_ship := Run.ship
	var tree := Engine.get_main_loop() as SceneTree
	var was_paused := tree.paused
	tree.paused = false
	Run.crew = 2
	Run.kits = 1
	Run.ship = ShipModel.new()
	var engine := _part(&"motor_trueno")
	var capsule := _part(&"capsula")
	var solar := _part(&"panel_solar")
	if engine == null or capsule == null or solar == null:
		_restore(previous_crew, previous_kits, previous_ship, was_paused)
		return 1
	engine.broken = true
	solar.broken = true
	Run.ship.parts = [engine, capsule, solar]
	var interior := ShipInterior.new()
	tree.root.add_child(interior)
	await tree.process_frame
	interior.interact(interior._center(0))
	var games := _minigames()
	if not interior.busy or tree.paused or games.is_empty() or interior.layer != 70 or _view_layer(games[0]) != 90:
		push_error("FAIL llegar al motor no abrió la reparación por encima del corte")
		failed += 1
	_drop_minigames()
	interior._finished(true, engine)
	if engine.broken or Run.kits != 0 or tree.paused:
		push_error("FAIL ganar la reparación no arregló el motor")
		failed += 1
	interior.busy = false
	interior.interact(interior._center(2))
	if interior.busy or not solar.broken:
		push_error("FAIL el panel se reparó desde el interior")
		failed += 1
	interior.interact(interior._center(1))
	if not interior.on_hull or tree.paused:
		push_error("FAIL la esclusa no abrió el casco")
		failed += 1
	var station: Dictionary = {}
	for row: Dictionary in interior._exterior_stations():
		if row.part == solar:
			station = row
			break
	if station.is_empty():
		push_error("FAIL no hay estación del panel en el casco")
		failed += 1
	else:
		interior.interact((station.rect as Rect2).get_center())
		var hull_games := _minigames()
		if not interior.busy or hull_games.is_empty() or (hull_games[0] as Node).get("mode") != &"align" or tree.paused:
			push_error("FAIL el panel no abrió su alineación, o el vuelo se detuvo")
			failed += 1
		_drop_minigames()
	interior.busy = false
	interior.interact(interior.stick_to_hull(interior._center(1)))
	if interior.on_hull or interior.busy or tree.paused:
		push_error("FAIL no se vuelve a la cabina desde el casco")
		failed += 1
	interior.interact(interior._center(1))
	if not interior.on_hull:
		push_error("FAIL la cápsula sana no abrió el casco otra vez")
		failed += 1
	capsule.broken = true
	interior.interact(interior.stick_to_hull(interior._center(1)))
	if interior.on_hull or interior.busy:
		push_error("FAIL la cápsula rota impide volver")
		failed += 1
	capsule.broken = false
	interior.queue_free()
	_restore(previous_crew, previous_kits, previous_ship, was_paused)
	return failed


func _part(id: StringName) -> ShipPart:
	var def := Catalog.part(id)
	if def == null:
		push_error("FAIL no existe %s" % id)
		return null
	return ShipPart.create(def, ShipPart.Quality.NEW, Run.rng)


func _view_layer(game: Node) -> int:
	for child: Node in game.get_children():
		if child is CanvasLayer:
			return (child as CanvasLayer).layer
	return -1


func _minigames() -> Array:
	var live: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	for node: Node in tree.get_nodes_in_group(&"minigame"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			live.append(node)
	return live


func _drop_minigames() -> void:
	for node: Node in _minigames():
		node.set("on_done", Callable())
		node.queue_free()


func _restore(crew: int, kits: int, ship: ShipModel, paused: bool) -> void:
	Card.clear_queue()
	Run.crew = crew
	Run.kits = kits
	Run.ship = ship
	(Engine.get_main_loop() as SceneTree).paused = paused
