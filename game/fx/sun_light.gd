class_name SunLight
extends RefCounted

## Umbra del sol en el mapa. El sol esta en el origen.
## Un punto cae en sombra si queda detras de un cuerpo, a menos de un radio del eje que sale del sol.
## Es el mismo test que apaga el flujo durante la llamarada.


static func in_umbra(point: Vector2, bodies: Array[BodyDef], t: float, ignore: StringName = &"") -> bool:
	for body: BodyDef in bodies:
		if body.is_star or body.id == ignore:
			continue
		var bp := Gravity.body_pos(body, t)
		var away := bp.normalized()
		var d := point - bp
		var along := d.dot(away)
		if along > 0.0 and (d - away * along).length() < body.radius:
			return true
	return false


## 0 a pleno sol, 1 si el disco cabe entero en la umbra. El borde queda en medio para el dither del shader.
static func cover(point: Vector2, radius: float, bodies: Array[BodyDef], t: float, ignore: StringName = &"") -> float:
	var amount := 0.0
	for body: BodyDef in bodies:
		if body.is_star or body.id == ignore:
			continue
		var bp := Gravity.body_pos(body, t)
		var away := bp.normalized()
		var d := point - bp
		var along := d.dot(away)
		if along <= 0.0:
			continue
		var lateral := (d - away * along).length()
		var outer := body.radius + radius
		if lateral >= outer:
			continue
		if radius <= 0.0:
			amount = 1.0 if lateral < body.radius else amount
			continue
		var inner := maxf(body.radius - radius, 0.0)
		if lateral <= inner:
			return 1.0
		var span := outer - inner
		amount = maxf(amount, clampf(1.0 - (lateral - inner) / span, 0.0, 1.0))
	return amount
