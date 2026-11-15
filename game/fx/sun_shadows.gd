class_name SunShadows
extends Node2D

## Cunas de umbra detras de los discos. El alfa muere en la punta, pasado el hijo mas lejano.

var bodies: Array[BodyDef] = []
var time: float = 0.0


func _draw() -> void:
	for body: BodyDef in bodies:
		if body.is_star:
			continue
		var bp := Gravity.body_pos(body, time)
		if bp.length_squared() < 1.0:
			continue
		var away := bp.normalized()
		var side := away.orthogonal() * body.radius
		var base := bp + away * body.radius
		var tip := bp + away * _reach(body)
		var wide := side * 1.15
		var ink := Color(0.0, 0.0, 0.02, 0.62)
		var fade := Color(0.0, 0.0, 0.02, 0.0)
		draw_polygon(
			PackedVector2Array([base + side, tip + wide, tip - wide, base - side]),
			PackedColorArray([ink, fade, fade, ink]),
		)


func _reach(body: BodyDef) -> float:
	var far := body.radius * 8.0
	for other: BodyDef in bodies:
		if other.parent_id == body.id:
			far = maxf(far, other.orbit_radius * 1.15)
	return far
