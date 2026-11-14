class_name Ticker
extends VBoxContainer

## Lista de avisos que se desvanecen. Sin comunicaciones, el texto llega corrupto.

const MAX_LINES := 7
const GLYPHS := "#%&@$*?!"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	Events.toast.connect(push)


func push(text: String, color: Color = Ui.TEXT) -> void:
	var line := Label.new()
	line.text = _garble(text)
	line.add_theme_font_size_override("font_size", 14)
	line.add_theme_color_override("font_color", color)
	line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	line.add_theme_constant_override("outline_size", 4)
	add_child(line)
	move_child(line, 0)
	while get_child_count() > MAX_LINES:
		get_child(get_child_count() - 1).free()
	line.modulate = Color(2, 2, 2, 1)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate", Color(1, 1, 1, 1), 0.25)
	tween.tween_interval(5.0)
	tween.tween_property(line, "modulate:a", 0.0, 1.0)
	tween.tween_callback(line.queue_free)


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
