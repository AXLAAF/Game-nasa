extends RefCounted

var passed := 0
var failed := 0


func run() -> int:
	_test_settings()
	_test_pause_single_player()
	_test_pause_coop()
	_test_title()
	_test_arcade_menu()
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
	check(_find_button(panel, "Modo Fácil Arcade").disabled, "modo arcade bloqueado con contrato en curso")
	_press_escape(tree)
	check(Modal._stack.size() == 1 and tree.paused, "Esc cierra solo ajustes")
	_press_escape(tree)
	check(not Modal.busy() and not tree.paused, "otro Esc reanuda")
	Router.current = &"title"
	_press_escape(tree)
	check(not Modal.busy(), "Esc no abre pausa en title")
	Router.current = original_current
	Run.crew = original_crew


func _test_arcade_menu() -> void:
	var had_file := FileAccess.file_exists(Profile.PATH)
	var prev_json := FileAccess.get_file_as_string(Profile.PATH) if had_file else ""
	var prev_persist := bool(Profile.persistence_enabled)
	var original_current := Router.current
	var tree := Engine.get_main_loop() as SceneTree
	Router.current = &"title"
	var panel := SettingsPanel.show_panel()
	var arcade_btn := _find_button(panel, "Modo Fácil Arcade")
	check(arcade_btn != null and not arcade_btn.disabled, "modo arcade habilitado en portada")
	Modal.close_all()
	Profile.persistence_enabled = true
	Profile.arcade = true
	Profile.save_profile()
	Profile.arcade = false
	Profile.load_profile()
	Profile.persistence_enabled = prev_persist
	check(Profile.arcade, "Profile persiste modo arcade")
	var TitleScript: GDScript = load("res://game/phases/title.gd") as GDScript
	var title: Node2D = TitleScript.new()
	tree.root.add_child(title)
	title.call(&"_new_game")
	check(Modal.busy(), "Nueva partida abre selector de modo")
	var top_modal: Node = Modal._stack.back() as Node
	var pick_arcade := _find_button(top_modal, "Modo Fácil Arcade (Recomendado)")
	var pick_sim := _find_button(top_modal, "Simulación original")
	var pick_back := _find_button(top_modal, "Cancelar")
	check(pick_arcade != null and pick_sim != null and pick_back != null, "selector muestra Arcade, Simulacion y Cancelar")
	pick_arcade.pressed.emit()
	check(Profile.arcade and Profile.credits == Profile.START_CREDITS, "elegir Arcade activa modo sin alterar creditos")
	Modal.close_all()
	tree.root.remove_child(title)
	title.free()
	if had_file and not prev_json.is_empty():
		var f := FileAccess.open(Profile.PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(prev_json)
			f.close()
		Profile.load_profile()
	else:
		Profile.reset()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.PATH))
	Router.current = original_current


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
