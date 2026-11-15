extends RefCounted

var passed := 0
var failed := 0


func run() -> int:
	_test_settings()
	_test_pause_single_player()
	_test_pause_coop()
	_test_title()
	_test_tutorial()
	_test_escape()
	print("Menu: %d passed, %d failed" % [passed, failed])
	return failed


func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)


func _test_settings() -> void:
	var original_master := Settings.master
	var original_music := Settings.music
	var original_sfx := Settings.sfx
	Settings.music = 0.25
	Settings.save()
	Settings.music = 1.0
	Settings.load_settings()
	check(is_equal_approx(Settings.music, 0.25), "Settings persiste musica")
	Settings.master = original_master
	Settings.music = original_music
	Settings.sfx = original_sfx
	Settings.save()


func _test_pause_single_player() -> void:
	var original_current := Router.current
	var original_crew := Run.crew
	var tree := Engine.get_main_loop() as SceneTree
	var original_paused := tree.paused
	Router.current = &"hangar"
	Run.crew = 1
	tree.paused = false
	Pause.open()
	check(tree.paused, "pausa congela en un jugador")
	check(Modal.busy(), "pausa abre modal en un jugador")
	Modal.close_all()
	check(not tree.paused, "cerrar pausa descongela")
	check(not Modal.busy(), "cerrar pausa vacia la pila")
	Router.current = original_current
	Run.crew = original_crew
	tree.paused = original_paused


func _test_pause_coop() -> void:
	var original_current := Router.current
	var original_crew := Run.crew
	var tree := Engine.get_main_loop() as SceneTree
	var original_paused := tree.paused
	Router.current = &"hangar"
	Run.crew = 2
	tree.paused = false
	Pause.open()
	check(Modal.busy(), "pausa abre modal cooperativo")
	check(not tree.paused, "pausa cooperativa no congela")
	Modal.close_all()
	Router.current = original_current
	Run.crew = original_crew
	tree.paused = original_paused


func _test_title() -> void:
	var original_current := Router.current
	Router.current = &"title"
	check(not Pause.can_open(), "pausa no abre en title")
	Router.current = original_current


func _test_tutorial() -> void:
	var original_current := Router.current
	var tree := Engine.get_main_loop() as SceneTree
	var original_paused := tree.paused
	Router.current = &"hangar"
	Tutorial.replay()
	check(not Pause.can_open(), "pausa bloqueada durante tutorial")
	if Tutorial._open != null and is_instance_valid(Tutorial._open):
		tree.root.remove_child(Tutorial._open)
		Tutorial._open.free()
	Tutorial._open = null
	tree.paused = false
	Router.current = original_current
	tree.paused = original_paused


## Esc real por el viewport: abre la pausa y, con ajustes encima, cada Esc cierra solo la ventana de arriba.
func _test_escape() -> void:
	var original_current := Router.current
	var original_crew := Run.crew
	var tree := Engine.get_main_loop() as SceneTree
	Router.current = &"space"
	Run.crew = 1
	tree.paused = false
	_press_escape(tree)
	check(Modal._stack.size() == 1 and tree.paused, "Esc abre la pausa")
	var panel := SettingsPanel.show_panel()
	check(_find_button(panel, "Modo asistido").disabled, "modo asistido bloqueado con contrato en curso")
	_press_escape(tree)
	check(Modal._stack.size() == 1 and tree.paused, "Esc cierra solo ajustes")
	_press_escape(tree)
	check(not Modal.busy() and not tree.paused, "otro Esc reanuda")
	Router.current = &"title"
	_press_escape(tree)
	check(not Modal.busy(), "Esc no abre pausa en title")
	Router.current = original_current
	Run.crew = original_crew


func _press_escape(tree: SceneTree) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	tree.root.push_input(event)


func _find_button(node: Node, text: String) -> Button:
	for child: Node in node.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
