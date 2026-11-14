class_name Odds
extends RefCounted

## Probabilidades, niebla y racha. Todo el azar pasa por el rng de la partida.


static func roll(chance: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < chance


## Rango que ve el jugador si no escaneo.
static func fog(chance: float, scanned: bool) -> Vector2:
	if scanned or chance >= 1.0:
		return Vector2(chance, chance)
	return Vector2(clampf(chance - 0.18, 0.02, 0.98), clampf(chance + 0.18, 0.02, 0.98))


static func fog_text(chance: float, scanned: bool) -> String:
	if chance >= 1.0:
		return "Seguro"
	var span := fog(chance, scanned)
	if is_equal_approx(span.x, span.y):
		return "%d %%" % int(round(chance * 100.0))
	return "%d-%d %%" % [int(round(span.x * 100.0)), int(round(span.y * 100.0))]


static func streak_mult(streak: int) -> float:
	return 1.0 + 0.25 * streak


static func risk_color(chance: float) -> Color:
	if chance >= 0.999:
		return Color("8fd6ce")
	if chance >= 0.7:
		return Color("58c96b")
	if chance >= 0.45:
		return Color("ffb000")
	return Color("f46452")


## Fiabilidad estimada de la nave en un viaje: rango [peor, mejor] segun lo que se sabe.
static func ship_reliability(ship: ShipModel) -> Vector2:
	var worst := 1.0
	var best := 1.0
	for part: ShipPart in ship.parts:
		var lo: float
		var hi: float
		if part.inspected:
			lo = part.condition
			hi = part.condition
		elif not part.revealed:
			lo = 0.3
			hi = 0.99
		else:
			var span: Vector2 = ShipPart.CONDITION[part.hidden_quality]
			lo = span.x
			hi = span.y
		worst *= 1.0 - _fatal(lo, part)
		best *= 1.0 - _fatal(hi, part)
	return Vector2(worst, best)


static func _fatal(condition: float, part: ShipPart) -> float:
	return clampf((1.0 - condition) * 0.55 * part.def.fragility * 0.9, 0.0, 0.9)
