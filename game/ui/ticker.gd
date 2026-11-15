class_name Ticker
extends VBoxContainer

## Lista de avisos que se desvanecen. Sin comunicaciones, el texto llega corrupto.

const MAX_LINES := 4
const GLYPHS := "#%&@$*?!"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	Events.toast.connect(push)


func push(text: String, color: Color = Ui.IVORY) -> void:
	var line := Label.new()
	line.text = _garble(text)
	line.add_theme_font_size_override("font_size", Ui.SIZE_TEXT)
	line.add_theme_color_override("font_color", color)
	line.add_theme_stylebox_override("normal", Ui.box(Color(Ui.BAKELITE, 0.9), color, 0, 3))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(360, 0)
	add_child(line)
	move_child(line, 0)
	while get_child_count() > MAX_LINES:
		get_child(get_child_count() - 1).free()
	Kinetic.sync_pivot(line)
	if not Kinetic.is_reduced():
		line.modulate = Color(1.7, 1.7, 1.8, 0.0)
		line.scale = Vector2(0.92, 0.86)
		line.rotation = -0.028
	var tween := line.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if Kinetic.is_reduced():
		tween.tween_interval(5.0)
		tween.tween_property(line, "modulate:a", 0.0, 0.5)
	else:
		tween.set_parallel(true)
		tween.tween_property(line, "modulate", Color(1, 1, 1, 1), 0.26).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(line, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(line, "rotation", 0.0, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.chain().tween_interval(4.8)
		tween.chain().tween_property(line, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(line, "scale", Vector2(0.96, 0.90), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(line.queue_free)


func _garble(text: String) -> String:
	var comms := Run.channel(&"comms")
	if comms >= 0.6 or not Synth.FLIGHT_PHASES.has(Router.current):
		return text
	var chars := text.split("")
	var rng := RandomNumberGenerator.new()
	for i: int in chars.size():
		if chars[i] != " " and rng.randf() > comms + 0.2:
			chars[i] = GLYPHS[rng.randi_range(0, GLYPHS.length() - 1)]
	return "".join(chars)
