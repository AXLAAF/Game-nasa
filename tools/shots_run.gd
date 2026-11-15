extends RefCounted

var tree: SceneTree
var _dir := "user://shots"


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	if OS.get_environment("SHOTS_DIR") != "":
		_dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	for phase: StringName in Tutorial.ORDER:
		if not Profile.tutorial_seen.has(String(phase)):
			Profile.tutorial_seen.append(String(phase))
	tree.root.add_child(load("res://game/main.tscn").instantiate())
	await _wait(1.0)
	await _shot("0_title")
	await _go(&"hangar")
	await _wait(1.0)
	await _shot("1_hangar")
	Run.debug_setup()
	var built: Array[ShipPart] = Run.ship.parts.duplicate()
	Run.ship.parts.clear()
	await _go(&"assembly")
	await _wait(1.5)
	await _shot("2_assembly_vacio")
	Run.ship.parts.assign(built)
	for phase: StringName in [&"assembly", &"launch", &"space"]:
		await _go(phase)
		await _wait(2.5)
		await _shot("%d_%s" % [Tutorial.ORDER.find(phase) + 1, phase])
	Card.malfunction(Run.ship.parts[0])
	await _wait(0.6)
	await _shot("7_carta")
	await _go(&"descent")
	await _wait(2.0)
	await _shot("5_descent_entrada")
	tree.get_first_node_in_group("phase")._commit()
	await _wait(3.0)
	Card.clear_queue()
	tree.paused = false
	await _shot("5_descent_vuelo")
	Run.outcome = &"delivered"
	Run.grade = "A"
	await _go(&"debrief")
	await _wait(5.0)
	await _shot("6_debrief")
	await _go(&"hangar")
	await _wait(1.0)
	Tutorial.replay()
	await _wait(0.5)
	await _shot("8_tutorial")
	Tutorial._open._skip()
	await _wait(0.5)
	Pause.open()
	await _wait(0.6)
	await _shot("9_pausa")
	SettingsPanel.show_panel()
	await _wait(0.6)
	await _shot("10_ajustes")
	Modal.close_all()
	print("SHOTS ", ProjectSettings.globalize_path(_dir))


## Router ignora go() mientras dura un fundido: se espera a que termine.
func _go(phase: StringName) -> void:
	while Router._busy:
		await tree.process_frame
	Router.go(phase)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	if tree.root.use_hdr_2d:
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb() # con HDR 2D la textura del viewport es lineal; la pantalla no
	image.save_png(_dir.path_join(name + ".png"))


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout
