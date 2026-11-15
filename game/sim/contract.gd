class_name Contract
extends RefCounted

const CARGO: Array[String] = ["Muestras de ciencia", "Paquetes urgentes", "Fauna exótica", "Satélite averiado", "Sonda geológica"]
const HIDDEN: Array[StringName] = [&"storms", &"dust", &"radiation", &"cold", &"heat"]

var target: StringName = &""
var cargo: String = "" ## texto original (msgid); se traduce al mostrarlo
var _legacy_title: String = "" ## titulo ya compuesto de partidas guardadas antiguas, solo si el cuerpo ya no existe
var payout: int = 0
var advance: int = 0
var dv_estimate: float = 0.0
var deadline: float = 0.0 ## segundos de juego en el espacio
var hidden_hazard: StringName = &""


static func generate(rng: RandomNumberGenerator, count: int) -> Array[Contract]:
	var targets: Array[BodyDef] = []
	for planet: BodyDef in Catalog.body_list():
		if planet.landable and not planet.is_home and not planet.is_star:
			targets.append(planet)
	var out: Array[Contract] = []
	for i: int in count:
		if targets.is_empty():
			break
		var planet: BodyDef = targets[rng.randi_range(0, targets.size() - 1)]
		var c := Contract.new()
		c.target = planet.id
		c.cargo = CARGO[rng.randi_range(0, CARGO.size() - 1)]
		c.dv_estimate = RocketMath.mission_dv(planet)
		var risk := rng.randf_range(0.85, 1.35)
		if rng.randf() < 0.45:
			c.hidden_hazard = HIDDEN[rng.randi_range(0, HIDDEN.size() - 1)]
			risk += 0.3
		c.payout = int(round(((c.dv_estimate - RocketMath.LAUNCH_DV) * 0.9 + 600.0) * planet.payout * risk / 10.0) * 10)
		c.advance = int(round(c.payout * 0.3 / 10.0) * 10)
		c.deadline = 120.0 + (c.dv_estimate - RocketMath.LAUNCH_DV) * 0.18
		out.append(c)
	return out


func body() -> BodyDef:
	return Catalog.body(target)


## Titulo en el idioma activo. No se guarda en el perfil: asi un contrato de una partida guardada
## sigue el idioma que elijas, en vez de quedarse en el que tenia al sortearse.
var title: String:
	get:
		var planet := body()
		if planet == null and _legacy_title != "":
			return _legacy_title
		return tr("%s a %s") % [tr(cargo), planet.display_name if planet != null else ""]


func to_dict() -> Dictionary:
	return {
		"target": String(target), "cargo": cargo, "payout": payout,
		"advance": advance, "dv": dv_estimate, "deadline": deadline, "hidden": String(hidden_hazard),
	}


static func from_dict(data: Dictionary) -> Contract:
	var c := Contract.new()
	c.target = StringName(str(data.get("target", "")))
	c.cargo = _canonical_cargo(str(data.get("cargo", "")))
	c._legacy_title = str(data.get("title", ""))
	c.payout = int(data.get("payout", 0))
	c.advance = int(data.get("advance", 0))
	c.dv_estimate = float(data.get("dv", 0.0))
	c.deadline = float(data.get("deadline", 200.0))
	c.hidden_hazard = StringName(str(data.get("hidden", "")))
	return c


## Las partidas guardadas por versiones antiguas escribian la carga sin tilde ("Satelite averiado"):
## se compara sin tildes ni mayusculas para reconocerla y poder traducirla.
static func _canonical_cargo(text: String) -> String:
	var plain := _plain(text)
	for known: String in CARGO:
		if _plain(known) == plain:
			return known
	return text


static func _plain(text: String) -> String:
	var out := text.strip_edges().to_lower()
	for pair: Array in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"]]:
		out = out.replace(pair[0], pair[1])
	return out
