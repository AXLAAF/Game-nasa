class_name Fx
extends RefCounted

## Particulas sin assets: textura de punto suave generada con un gradiente radial.

static var _dot: GradientTexture2D


static func dot() -> Texture2D:
	if _dot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = gradient
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot


static func ramp(colors: Array[Color]) -> Gradient:
	var offsets := PackedFloat32Array()
	for i: int in colors.size():
		offsets.append(float(i) / float(maxi(colors.size() - 1, 1)))
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colors)
	return gradient


static func exhaust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 140
	p.lifetime = 0.55
	p.local_coords = false
	p.direction = Vector2(0, 1)
	p.spread = 9.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 360.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1, 1.8))
	p.scale_amount_curve = curve
	p.color_ramp = ramp([
		Color(3.0, 2.6, 1.8, 1.0), Color(2.2, 0.9, 0.25, 0.9),
		Color(0.6, 0.35, 0.3, 0.45), Color(0.4, 0.4, 0.45, 0.0),
	])
	return p


static func smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 90
	p.lifetime = 2.6
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, -20)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 160.0
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color_ramp = ramp([Color(0.9, 0.85, 0.8, 0.5), Color(0.6, 0.6, 0.65, 0.25), Color(0.5, 0.5, 0.55, 0.0)])
	return p


static func plasma() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 120
	p.lifetime = 0.4
	p.local_coords = false
	p.spread = 30.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color_ramp = ramp([Color(3.0, 1.6, 0.6, 1.0), Color(2.0, 0.5, 0.2, 0.7), Color(1.0, 0.2, 0.4, 0.0)])
	return p


## Explosion o chispas de un solo disparo que se liberan solas.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 60, speed: float = 300.0, life: float = 0.8) -> void:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.5
	p.damping_max = speed
	p.scale_amount_min = 0.3
	p.scale_amount_max = 1.2
	p.color_ramp = ramp([Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, 1.0), color, Color(color.r, color.g, color.b, 0.0)])
	p.global_position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
