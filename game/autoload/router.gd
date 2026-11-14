extends Node

const PHASES: Dictionary = {
	&"hangar": "res://game/phases/hangar.gd",
	&"assembly": "res://game/phases/assembly.gd",
	&"launch": "res://game/phases/launch.gd",
	&"space": "res://game/phases/space.gd",
	&"descent": "res://game/phases/descent.gd",
	&"debrief": "res://game/phases/debrief.gd",
}
const DEBUG_KEYS: Dictionary = {
	KEY_F1: &"hangar", KEY_F2: &"assembly", KEY_F3: &"launch",
	KEY_F4: &"space", KEY_F5: &"descent", KEY_F6: &"debrief",
}

var host: Node
var current: StringName = &""
var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func mount(node: Node) -> void:
	host = node
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func go(phase_id: StringName) -> void:
	if _busy or host == null:
		return
	_busy = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", 1.0, 0.22 if current != &"" else 0.0)
	tween.tween_callback(_swap.bind(phase_id))
	tween.tween_property(_fade, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: _busy = false)


func _swap(phase_id: StringName) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Card.clear_queue()
	for child: Node in host.get_children():
		if child.is_in_group("phase"):
			host.remove_child(child)
			child.queue_free()
	var script: GDScript = load(PHASES[phase_id])
	var phase: Node = script.new()
	phase.name = String(phase_id).capitalize()
	phase.add_to_group("phase")
	host.add_child(phase)
	current = phase_id
	Events.phase_changed.emit(phase_id)
	Tutorial.offer(phase_id)


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).physical_keycode
	if DEBUG_KEYS.has(key):
		var phase_id: StringName = DEBUG_KEYS[key]
		if Run.contract == null or Run.ship.parts.is_empty():
			Run.debug_setup()
		if phase_id == &"debrief" and Run.outcome == &"":
			Run.outcome = &"delivered"
			Run.grade = "A"
		go(phase_id)
