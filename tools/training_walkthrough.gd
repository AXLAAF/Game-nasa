extends SceneTree

## Capturas reproducibles del recorrido real, con comandos y sin guardar progreso.
func _initialize() -> void:
	await process_frame
	root.get_node("Profile").persistence_enabled = false
	await _run()
	quit()

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var view: Node = load("res://game/phases/training.gd").new()
	root.add_child(view)
	view.set_process(false)
	var pilot: Script = load("res://tests/test_training.gd")
	for i: int in 3:
		var part: String = view.session.design.recipe[i].id
		view._part_buttons[part].pressed.emit()
		view.session.tick(view._pending)
		view._pending.clear()
	view._refresh()
	await _shot("training_assembly")
	for i: int in range(3, view.session.design.recipe.size()):
		var part: String = view.session.design.recipe[i].id
		view._part_buttons[part].pressed.emit()
		view.session.tick(view._pending)
		view._pending.clear()
	pilot.fly_to(view.session, "stage_ready")
	view._refresh()
	await _shot("training_separation")
	pilot.fly_to(view.session, "entry")
	view._refresh()
	await _shot("training_entry")
	pilot.fly_to(view.session, "complete")
	assert(view.session.phase() == "complete", str(view.session.state))
	view._refresh()
	await _shot("training_complete")
	view.free()

func _shot(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if root.use_hdr_2d:
		picture.convert(Image.FORMAT_RGBA8)
		picture.linear_to_srgb()
	var directory := ProjectSettings.globalize_path("res://.godot/training_artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	picture.save_png(directory.path_join(filename + ".png"))
	print("CAPTURE ", filename)
