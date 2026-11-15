extends RefCounted

const LINT: Script = preload("res://tests/layout_lint.gd")

var tree: SceneTree
var crew := 1
var findings: Dictionary = {} ## linea del lint -> primera parada donde aparecio


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	Profile.reset()
	Profile.reduced_motion = true # las animaciones desplazan los rectangulos que mide el lint
	Profile.crew = crew
	tree.root.add_child(load("res://game/main.tscn").instantiate())
	await _until(&"title")
	SettingsPanel.show_panel()
	await _lint("title+ajustes")
	Modal.close_all()
	_phase()._credits()
	await _lint("title+creditos")
	Modal.close_all()
	_phase()._new_game()
	await _lint("title+nueva partida")
	Modal.close_all()
	_phase()._start()
	Profile.reduced_motion = true # _start reinicia el perfil
	Profile.crew = crew
	await _until(&"hangar")
	Tutorial.replay()
	await _lint("hangar+manual")
	if Tutorial.busy():
		Tutorial._open._finish(true)
	_phase()._accept(Profile.board(Run.rng)[0])
	await _until(&"assembly")
	for id: StringName in [&"motor_trueno", &"tanque_ancho", &"desacoplador", &"motor_susurro", &"tanque_largo", &"escudo_termico", &"capsula", &"paracaidas", &"patas", &"panel_solar"]:
		Run.ship.parts.append(ShipPart.create(Catalog.part(id), ShipPart.Quality.SCRAP, Run.rng))
	await _wait(0.3)
	if (_phase()._launch as Button).get_global_rect().end.y > tree.root.get_visible_rect().size.y:
		push_error("SMOKE: el boton Despegar queda fuera de pantalla")
	_phase()._on_launch()
	await _until(&"launch")
	await _wait(7.0)
	await _lint("launch+vuelo")
	_close_cards()
	_phase()._reach_orbit()
	await _wait(2.5)
	_close_cards()
	await _until(&"space")
	var space := _phase()
	await _wait(1.0)
	space._repair_card()
	await _lint("space+carta")
	_close_cards()
	Run.salvage.append(Run.random_part(ShipPart.Quality.MYSTERY))
	space._salvage_card()
	_close_cards()
	space._encounter(Run.pois[0])
	_close_cards()
	space.flare_timer = 0.01
	await _wait(0.3)
	_close_cards()
	space._micrometeoroid()
	_close_cards()
	space.warp_i = 3
	await _wait(1.0)
	_close_cards()
	space._start_descent(Run.target())
	await _until(&"descent")
	var descent := _phase()
	descent._commit()
	await _wait(2.0)
	_close_cards()
	descent.h = descent.terrain(descent.x) + 0.5
	descent.vx = 0.0
	descent.vy = -3.0
	descent.pitch = 0.0
	await _wait(0.5)
	_close_cards()
	print("aterrizaje: ", descent.grade, " estado ", descent.state, " outcome ", Run.outcome)
	descent._explore()
	_close_cards()
	await _wait(0.2)
	descent._deliver()
	await _until(&"debrief")
	await _wait(6.0)
	print("creditos tras la liquidacion: ", Profile.credits)
	Router.go(&"hangar")
	await _until(&"hangar")
	Profile.insurance = 2
	_phase()._accept(Profile.board(Run.rng)[1])
	await _until(&"assembly")
	Run.spent = 1200
	Run.boxes = 2
	Run.destroy("Prueba de perdida.")
	Router.go(&"debrief")
	await _until(&"debrief")
	await _wait(6.0)
	print("perdida: creditos ", Profile.credits, " lecciones ", Profile.lessons, " inventario ", Profile.inventory.size())
	Router.go(&"training")
	await _until(&"training")
	Profile.reset()


func _phase() -> Node:
	for node: Node in tree.get_nodes_in_group("phase"):
		return node
	return null


func _close_cards() -> void:
	while Card.busy():
		Card._open._close(true)


func _until(phase: StringName) -> void:
	for i: int in 100:
		if Router.current == phase and not Router._busy:
			break
		await _wait(0.1)
	print("fase: ", Router.current)
	if Router.current != phase:
		push_error("SMOKE: se esperaba la fase %s" % phase)
		return
	await _lint(String(phase))


func _lint(where: String) -> void:
	await _wait(0.4)
	for line: String in LINT.check(tree):
		if not findings.has(line):
			findings[line] = where


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout
