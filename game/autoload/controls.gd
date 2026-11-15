extends Node

## Lee acciones por jugador. P1 pilota con el teclado, el mismo de un jugador.
## Con dos jugadores el mando no pilota: es del tripulante, junto con las flechas.

const DEAD := 0.2
const KEYBOARD_ONLY := -2

var _key_just: Dictionary = {}
var _joy_just: Dictionary = {}
var _axis_just: Dictionary = {}
var _axis_dir: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_flush.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode != KEY_NONE:
			_key_just[key.physical_keycode] = true
		if key.keycode != KEY_NONE:
			_key_just[key.keycode] = true
	elif event is InputEventJoypadButton and event.pressed:
		var button := event as InputEventJoypadButton
		_joy_just["%d:%d" % [button.device, int(button.button_index)]] = true
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var dir := 0
		if motion.axis_value > DEAD:
			dir = 1
		elif motion.axis_value < -DEAD:
			dir = -1
		var id := "%d:%d" % [motion.device, int(motion.axis)]
		var prev := int(_axis_dir.get(id, 0))
		if dir != 0 and dir != prev:
			_axis_just["%s:%d" % [id, dir]] = true
		if dir == 0:
			_axis_dir.erase(id)
		else:
			_axis_dir[id] = dir


func steer() -> float:
	var stick := _left_stick(_cmd_device())
	if stick != Vector2.ZERO:
		return clampf(stick.x, -1.0, 1.0)
	var keys := 0.0
	if _key_down(&"cmd_steer_left"):
		keys -= 1.0
	if _key_down(&"cmd_steer_right"):
		keys += 1.0
	return clampf(keys, -1.0, 1.0)


func throttle_axis() -> float:
	var stick := _left_stick(_cmd_device())
	if stick != Vector2.ZERO:
		return clampf(-stick.y, -1.0, 1.0)
	var keys := 0.0
	if _key_down(&"cmd_throttle_up"):
		keys += 1.0
	if _key_down(&"cmd_throttle_down"):
		keys -= 1.0
	return clampf(keys, -1.0, 1.0)


func cmd_held(action: StringName) -> bool:
	return _key_down(action) or _joy_down(action, _cmd_device())


func cmd_just(action: StringName) -> bool:
	var device := _cmd_device()
	if _key_edge(action) or _joy_edge(action, device):
		_consume(action, device)
		return true
	return false


func warp_choice(count: int, current: int) -> int:
	for i: int in count:
		if cmd_just(StringName("cmd_warp_%d" % [i + 1])):
			return i
	if cmd_just(&"cmd_warp_next"):
		return mini(current + 1, count - 1)
	if cmd_just(&"cmd_warp_prev"):
		return maxi(current - 1, 0)
	return current


func crew_vector() -> Vector2:
	if Run.crew < 2:
		return Vector2.ZERO
	var v := Vector2.ZERO
	if _key_down(&"crew_left"):
		v.x -= 1.0
	if _key_down(&"crew_right"):
		v.x += 1.0
	if _key_down(&"crew_up"):
		v.y -= 1.0
	if _key_down(&"crew_down"):
		v.y += 1.0
	var stick := Vector2(_axis_value(_crew_device(), JOY_AXIS_LEFT_X), _axis_value(_crew_device(), JOY_AXIS_LEFT_Y))
	if stick.length() > DEAD:
		v += stick
	return v.limit_length(1.0)


func crew_interact_just() -> bool:
	if Run.crew < 2:
		return false
	if _key_edge(&"crew_interact"):
		_consume(&"crew_interact", _crew_device())
		return true
	if _joy_edge(&"crew_interact", _crew_device()):
		_consume(&"crew_interact", _crew_device())
		return true
	return false


## El segundo jugador pulsa A en su mando o J para unirse en el hangar.
func join_just() -> bool:
	if _key_edge(&"crew_join"):
		_consume(&"crew_join", _crew_device())
		return true
	if _joy_edge(&"crew_join", _crew_device()):
		_consume(&"crew_join", _crew_device())
		return true
	return false


## El tripulante se va con B en su mando o K.
func leave_just() -> bool:
	if _key_edge(&"crew_leave"):
		_consume(&"crew_leave", _crew_device())
		return true
	if _joy_edge(&"crew_leave", _crew_device()):
		_consume(&"crew_leave", _crew_device())
		return true
	return false


func _cmd_device() -> int:
	return KEYBOARD_ONLY if Run.crew >= 2 else -1


func _crew_device() -> int:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return 0
	return int(pads[0])


func _has_crew_pad() -> bool:
	return Input.get_connected_joypads().has(1)


func _left_stick(device: int) -> Vector2:
	var value := Vector2(_axis_value(device, JOY_AXIS_LEFT_X), _axis_value(device, JOY_AXIS_LEFT_Y))
	if value.length() < DEAD:
		return Vector2.ZERO
	return value


func _key_down(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and _key_held(event as InputEventKey):
			return true
	return false


func _key_edge(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and _key_pressed(event as InputEventKey):
			return true
	return false


func _key_code(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


func _key_held(event: InputEventKey) -> bool:
	var code := _key_code(event)
	if code == KEY_NONE:
		return false
	return Input.is_physical_key_pressed(code) or Input.is_key_pressed(code) or _key_just.has(code)


func _key_pressed(event: InputEventKey) -> bool:
	var code := _key_code(event)
	return code != KEY_NONE and _key_just.has(code)


func _joy_down(action: StringName, device: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var button := (event as InputEventJoypadButton).button_index
			if _button_down(device, button):
				return true
		elif event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if _axis_held(device, motion.axis, motion.axis_value):
				return true
	return false


func _joy_edge(action: StringName, device: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var button := (event as InputEventJoypadButton).button_index
			if _button_edge(device, button):
				return true
		elif event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			var dir := 1 if motion.axis_value > 0.0 else -1
			if _axis_edge(device, motion.axis, dir):
				return true
	return false


func _button_down(device: int, button: JoyButton) -> bool:
	for dev: int in _devices(device):
		if Input.is_joy_button_pressed(dev, button):
			return true
	return false


func _button_edge(device: int, button: JoyButton) -> bool:
	for dev: int in _devices(device):
		if _joy_just.has("%d:%d" % [dev, int(button)]):
			return true
	return false


func _axis_held(device: int, axis: JoyAxis, direction: float) -> bool:
	var sign_dir := 1.0 if direction > 0.0 else -1.0
	for dev: int in _devices(device):
		if Input.get_joy_axis(dev, axis) * sign_dir > DEAD:
			return true
	return false


func _axis_edge(device: int, axis: JoyAxis, dir: int) -> bool:
	for dev: int in _devices(device):
		if _axis_just.has("%d:%d:%d" % [dev, int(axis), dir]):
			return true
	return false


func _axis_value(device: int, axis: JoyAxis) -> float:
	var best := 0.0
	for dev: int in _devices(device):
		var value := Input.get_joy_axis(dev, axis)
		if absf(value) > absf(best):
			best = value
	return best


func _devices(device: int) -> Array[int]:
	var out: Array[int] = []
	if device == KEYBOARD_ONLY:
		return out
	if device >= 0:
		out.append(device)
		return out
	for dev: int in Input.get_connected_joypads():
		out.append(dev)
	return out


func _consume(action: StringName, device: int) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			_key_just.erase(key.physical_keycode)
			_key_just.erase(key.keycode)
		elif event is InputEventJoypadButton:
			var button := int((event as InputEventJoypadButton).button_index)
			if device < 0:
				var drop: Array[String] = []
				for key: String in _joy_just:
					if key.ends_with(":%d" % button):
						drop.append(key)
				for key: String in drop:
					_joy_just.erase(key)
			else:
				_joy_just.erase("%d:%d" % [device, button])


func _flush() -> void:
	_key_just.clear()
	_joy_just.clear()
	_axis_just.clear()
