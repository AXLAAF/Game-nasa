class_name ShipPart
extends RefCounted

enum Quality { SCRAP, USED, NEW, MYSTERY, LEGENDARY }
enum Health { SOUND, WORN, FAULTY, BROKEN }
const NAMES: Array[String] = ["Chatarra", "Usada", "Nueva", "Misteriosa", "Legendaria"]
const HEALTH_NAME: Array[String] = ["Sano", "Gastado", "Defectuoso", "Roto"]
const HEALTH_NOTE: Array[String] = ["pleno rendimiento", "rinde menos", "a medias, falla fácil", "fuera de servicio"]
const HEALTH_COLOR: Array[String] = ["#6dff9a", "#ffd15a", "#ff7a32", "#ff4d45"]
const OUTPUT: Array[float] = [1.0, 0.82, 0.55, 0.0]
const PRICE: Array[float] = [0.35, 0.65, 1.0, 0.5, 1.0]
const CONDITION: Array[Vector2] = [
	Vector2(0.30, 0.70), Vector2(0.60, 0.88), Vector2(0.86, 0.99), Vector2(0.30, 0.99), Vector2(1.0, 1.0),
]

var def: PartDef
var quality: int = Quality.NEW ## lo que el jugador compro
var hidden_quality: int = Quality.NEW ## la real (solo difiere en misteriosas)
var condition: float = 0.9
var wear: float = 0.0
var broken: bool = false
var inspected: bool = false
var revealed: bool = true
var owned: bool = false
var paid: int = -1 ## precio fijo (cajas misteriosas)
var fuel: float = 0.0
var ablative: float = 0.0
var thrust_mult: float = 1.0
var boost: float = 1.0
var tuned: bool = false
var deployed: int = 0 ## paracaidas: 0 guardado, 1 frenado, 2 principal
var mount: float = 0.5 ## 0 = base del bloque ancla, 1 = cima (solo radiales)
var side: int = 0 ## -1 izquierda, 0 ambos lados, 1 derecha


static func create(part_def: PartDef, bought: int, rng: RandomNumberGenerator) -> ShipPart:
	var part := ShipPart.new()
	part.def = part_def
	part.quality = bought
	part.hidden_quality = bought
	if bought == Quality.MYSTERY:
		var roll := rng.randf()
		if roll < 0.12:
			part.hidden_quality = Quality.LEGENDARY
		elif roll < 0.5:
			part.hidden_quality = Quality.SCRAP
		elif roll < 0.8:
			part.hidden_quality = Quality.USED
		else:
			part.hidden_quality = Quality.NEW
		part.revealed = false
	var span: Vector2 = CONDITION[part.hidden_quality]
	part.condition = rng.randf_range(span.x, span.y)
	if part.hidden_quality == Quality.LEGENDARY:
		part.boost = 1.3
	part.refill()
	return part


func refill() -> void:
	fuel = def.fuel * boost
	ablative = def.ablative * boost * (0.6 + 0.4 * condition)


func health() -> int:
	if broken:
		return Health.BROKEN
	var life := condition * (1.0 - wear)
	if life >= 0.78:
		return Health.SOUND
	if life >= 0.5:
		return Health.WORN
	return Health.FAULTY


func output() -> float:
	return OUTPUT[health()]


func health_text(fog: bool = false) -> String:
	if fog and not inspected and not revealed:
		return "?"
	return tr(HEALTH_NAME[health()])


func status_bbcode() -> String:
	var h := health()
	return "[color=%s]%s[/color]   %s,   %s,   %s" % [HEALTH_COLOR[h], tr(HEALTH_NAME[h]), def.display_name, quality_text(), tr(HEALTH_NOTE[h])]


func fail_chance(stress: float) -> float:
	if broken:
		return 0.0
	var chance := ((1.0 - condition) * 0.55 + wear * 0.3) * stress * def.fragility
	chance *= Run.assist_fail_mult()
	return clampf(chance, 0.0, 0.95)


## Valor de una estadistica del PartDef con bono y averia aplicados.
func stat(name: StringName) -> float:
	return float(def.get(name)) * boost * output()


func thrust() -> float:
	return stat(&"thrust") * thrust_mult


func price() -> int:
	if owned:
		return 0
	return paid if paid >= 0 else int(round(def.cost * PRICE[quality]))


func quality_text() -> String:
	if revealed or inspected:
		return tr(NAMES[hidden_quality])
	return "?"


func condition_text() -> String:
	if inspected:
		return "%d %%" % int(round(condition * 100.0))
	if not revealed:
		return "??"
	var span: Vector2 = CONDITION[hidden_quality]
	return "%d-%d %%" % [int(span.x * 100.0), int(span.y * 100.0)]


func reveal() -> bool:
	if revealed:
		return false
	revealed = true
	return true


## Una prueba del segundo jugador. [juego] +20 % de rendimiento, tope 1.45, y la pieza queda más justa.
const EXPERIMENT_MULT := 1.2
const EXPERIMENT_CAP := 1.45


func can_experiment() -> bool:
	return not broken and not tuned


## Acierto: sube el rendimiento y el desgaste. Fallo: la pieza se rompe. No crea combustible.
func apply_experiment(ok: bool) -> void:
	tuned = true
	if not ok:
		broken = true
		wear = minf(wear + 0.25, 1.0)
		return
	var before := boost
	boost = minf(boost * EXPERIMENT_MULT, EXPERIMENT_CAP)
	wear = minf(wear + 0.08, 0.4)
	if def.ablative > 0.0 and before > 0.0 and boost > before:
		ablative = minf(ablative * (boost / before), def.ablative * boost)


func to_dict() -> Dictionary:
	return {
		"id": String(def.id), "q": quality, "hq": hidden_quality, "c": condition,
		"w": wear, "i": inspected, "r": revealed, "b": boost, "t": tuned,
		"m": mount, "s": side,
	}


static func from_dict(data: Dictionary) -> ShipPart:
	var part_def := Catalog.part(StringName(str(data.get("id", ""))))
	if part_def == null:
		return null
	var part := ShipPart.new()
	part.def = part_def
	part.quality = int(data.get("q", Quality.USED))
	part.hidden_quality = int(data.get("hq", part.quality))
	part.condition = float(data.get("c", 0.7))
	part.wear = float(data.get("w", 0.0))
	part.inspected = bool(data.get("i", false))
	part.revealed = bool(data.get("r", true))
	part.boost = float(data.get("b", 1.0))
	part.tuned = bool(data.get("t", false))
	part.mount = float(data.get("m", 0.5))
	part.side = int(data.get("s", 0))
	part.owned = true
	part.refill()
	return part
