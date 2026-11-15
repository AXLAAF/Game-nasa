extends CharacterBody2D
## Camina por las salas y, en el casco, rodea la nave con los pies sobre el contorno.

const SHEET := preload("res://assets/crew/robot_mule_sheet.png")
const SCALE := 2.0
const FRAME := Vector2(32, 48)
const FEET := FRAME.y * SCALE * 0.5

var host: Node
var _sprite: Sprite2D
var _anim := 0.0
var _intro := 0.0
var _intro_out := false
var _face_left := false


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = 6
	_sprite.vframes = 3
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(SCALE, SCALE)
	add_child(_sprite)
	if host != null:
		_intro = 0.3
		_intro_out = host.on_hull


func _physics_process(delta: float) -> void:
	_anim += delta
	if _intro > 0.0:
		_intro = maxf(_intro - delta, 0.0)
	var moving := false
	if host == null:
		velocity = Vector2.ZERO
		move_and_slide()
	elif host.busy:
		velocity = Vector2.ZERO
		if host.on_hull:
			_plant(host.hull_normal(host.hull_param(position)))
		else:
			rotation = 0.0
			_sprite.position = Vector2.ZERO
			move_and_slide()
	else:
		var wish := Controls.crew_vector() * 150.0
		if host.on_hull:
			var tangent: Vector2 = host.hull_normal(host.hull_param(position)).rotated(PI * 0.5)
			var along := wish.dot(tangent)
			moving = absf(along) > 8.0
			position = host.slide_hull(position, wish * delta)
			_plant(host.hull_normal(host.hull_param(position)))
			if moving:
				_face_left = along < 0.0
		else:
			velocity = wish
			move_and_slide()
			rotation = 0.0
			_sprite.position = Vector2.ZERO
			moving = wish.length() > 8.0
			if absf(wish.x) > 8.0:
				_face_left = wish.x < 0.0
		if Controls.crew_interact_just():
			host.interact(position)
	_paint_frame(moving)


func _plant(normal: Vector2) -> void:
	rotation = normal.angle() + PI * 0.5
	_sprite.position = Vector2(0.0, -FEET)
	velocity = Vector2.ZERO


func _paint_frame(moving: bool) -> void:
	if _sprite == null:
		return
	_sprite.flip_h = _face_left
	if _intro > 0.0:
		_sprite.frame = 4 if _intro_out else 0
		_sprite.flip_h = false
	elif host != null and host.busy:
		_sprite.frame = 14 + int(_anim * 8.0) % 4
	elif moving:
		_sprite.frame = 6 + int(_anim * 10.0) % 6
	else:
		_sprite.frame = 13 if fmod(_anim, 1.4) > 1.15 else 12
