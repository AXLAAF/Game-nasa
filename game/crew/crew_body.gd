extends CharacterBody2D
## Camina por las salas y, en el casco, rodea la nave en postura vertical sobre el contorno.

const SHEET := preload("res://assets/crew/robot_mule_sheet.png")
const SCALE := 1.5
const TURN_TIME := 0.35

var host: Node
var _sprite: Sprite2D
var _anim := 0.0
var _intro := 0.0
var _intro_out := false
var _face_left := false
var _hull_normal := Vector2.UP
var _wish_dir := Vector2.ZERO


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
		_intro = TURN_TIME
		_intro_out = host.on_hull
		if host.on_hull:
			_hull_normal = host.hull_normal(host.hull_param(position))
			_align_hull(_hull_normal)


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
			_hull_normal = host.hull_normal(host.hull_param(position))
			_align_hull(_hull_normal)
		else:
			rotation = 0.0
			_sprite.position = Vector2.ZERO
			move_and_slide()
	else:
		var wish := Controls.crew_vector() * 150.0
		_wish_dir = wish
		if host.on_hull:
			var param: float = host.hull_param(position)
			var normal: Vector2 = host.hull_normal(param)
			var tangent: Vector2 = normal.rotated(PI * 0.5)
			var along := wish.dot(tangent)
			moving = absf(along) > 8.0
			position = host.slide_hull(position, wish * delta)
			_hull_normal = host.hull_normal(host.hull_param(position))
			_align_hull(_hull_normal)
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


func _align_hull(normal: Vector2) -> void:
	rotation = 0.0
	velocity = Vector2.ZERO
	# Desplaza ligeramente el cuerpo hacia afuera de la linea del casco para que la mano toque la pared.
	_sprite.position = Vector2(normal.x * 10.0, normal.y * 6.0)
	if normal.x > 0.22:
		_face_left = true
	elif normal.x < -0.22:
		_face_left = false


func _paint_frame(moving: bool) -> void:
	if _sprite == null:
		return
	if _intro > 0.0:
		var t := clampf(1.0 - (_intro / TURN_TIME), 0.0, 0.999)
		var step := int(t * 5.0)
		_sprite.frame = step if _intro_out else (4 - step)
		_sprite.flip_h = _face_left
		return

	_sprite.flip_h = _face_left
	if host != null and host.busy:
		_sprite.frame = 14 + int(_anim * 8.0) % 4
		return

	if host != null and host.on_hull:
		var nx := absf(_hull_normal.x)
		if nx < 0.32:
			# En el arco superior (nariz) o inferior (tobera) muestra vista frontal/trasera del giro
			_sprite.frame = 4 if _hull_normal.y < 0.0 else 0
			_sprite.flip_h = false
		elif nx < 0.72:
			# En las curvas diagonales del casco muestra las vistas 3/4 de giro
			_sprite.frame = 3 if _hull_normal.y < 0.0 else 1
		elif moving:
			_sprite.frame = 6 + int(_anim * 10.0) % 6
		else:
			# En el flanco del casco extiende el brazo hacia la nave (cuadro 5) y parpadea ocasionalmente
			_sprite.frame = 13 if fmod(_anim, 2.2) > 1.95 else 5
		return

	if moving:
		if absf(_wish_dir.y) > absf(_wish_dir.x) * 1.35:
			_sprite.frame = (3 if int(_anim * 8.0) % 2 == 0 else 4) if _wish_dir.y < 0.0 else (0 if int(_anim * 8.0) % 2 == 0 else 1)
		else:
			_sprite.frame = 6 + int(_anim * 10.0) % 6
	else:
		_sprite.frame = 13 if fmod(_anim, 1.8) > 1.55 else 12

