extends Node

const PATH := "user://profile.json"
const START_CREDITS := 1500
const MIN_BUDGET := 900
const INSURANCE_NAMES: Array[String] = ["Sin seguro", "Básico", "Premium"]
const INSURANCE_PREMIUM: Array[float] = [0.0, 0.12, 0.28]
const INSURANCE_COVER: Array[float] = [0.0, 0.45, 0.85]
const LESSONS: Dictionary = {
	"inspector": "Una inspección gratis por partida.",
	"odds": "Las averías muestran probabilidades exactas.",
	"seguro": "El seguro cuesta la mitad.",
	"kit": "Empiezas con un kit de reparación extra.",
	"budget": "La agencia suma 250 al presupuesto.",
	"sensors": "Ves la rareza de las señales desde lejos.",
}

var credits: int = START_CREDITS
var runs: int = 0
var wins: int = 0
var best_payout: int = 0
var lessons: Array[String] = []
var inventory: Array = [] ## diccionarios de ShipPart.to_dict()
var insurance: int = 0
var arcade: bool = false ## modo facil arcade: navegacion WASD sin gravedad y aterrizaje directo con motores WASD
var assist: bool = false ## modo asistido: mas facil, menos pago
var reduced_motion: bool = false ## sin sacudida, destellos ni lamparas intermitentes
var crew: int = 1
var tutorial_seen: Array[String] = []
var training_completed: bool = false
## Los runners desactivan la persistencia antes de ejecutar pruebas destructivas.
var persistence_enabled: bool = true
var contracts: Array = [] ## diccionarios de Contract.to_dict()


func _ready() -> void:
	load_profile()


func has_lesson(id: String) -> bool:
	return lessons.has(id)


func learn_random(rng: RandomNumberGenerator) -> String:
	var options: Array[String] = []
	for id: String in LESSONS:
		if not lessons.has(id):
			options.append(id)
	if options.is_empty():
		return ""
	var id := options[rng.randi_range(0, options.size() - 1)]
	lessons.append(id)
	return id


func budget(contract: Contract) -> int:
	var extra := 250 if has_lesson("budget") else 0
	var advance := contract.advance if contract != null else 0
	return maxi(credits + advance + extra, MIN_BUDGET + advance + extra)


func premium_rate() -> float:
	var rate := INSURANCE_PREMIUM[insurance]
	return rate * 0.5 if has_lesson("seguro") else rate


func board(rng: RandomNumberGenerator) -> Array[Contract]:
	var list: Array[Contract] = []
	for data: Dictionary in contracts:
		list.append(Contract.from_dict(data))
	if list.is_empty():
		list = Contract.generate(rng, 3)
		contracts.clear()
		for c: Contract in list:
			contracts.append(c.to_dict())
		save_profile()
	return list


func clear_board() -> void:
	contracts.clear()


func saw_tutorial(phase: String) -> bool:
	return tutorial_seen.has(phase)


func mark_tutorial(phase: String) -> void:
	if tutorial_seen.has(phase):
		return
	tutorial_seen.append(phase)
	save_profile()


func mark_tutorial_all() -> void:
	for phase: StringName in [&"hangar", &"assembly", &"launch", &"space", &"descent", &"debrief"]:
		if not tutorial_seen.has(String(phase)):
			tutorial_seen.append(String(phase))
	save_profile()


func complete_training() -> void:
	if not training_completed:
		training_completed = true
		save_profile()


func save_profile() -> void:
	if not persistence_enabled:
		return
	var data := {
		"credits": credits, "runs": runs, "wins": wins, "best": best_payout,
		"lessons": lessons, "inventory": inventory, "insurance": insurance, "arcade": arcade, "assist": assist, "reduced_motion": reduced_motion, "crew": crew,
		"tutorial": tutorial_seen, "contracts": contracts, "training_completed": training_completed,
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Profile: no se pudo guardar en %s" % PATH)
		return
	file.store_string(JSON.stringify(data, "  "))


func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_warning("Profile: archivo corrupto, se usa un perfil nuevo.")
		return
	var data: Dictionary = parsed
	credits = int(data.get("credits", START_CREDITS))
	runs = int(data.get("runs", 0))
	wins = int(data.get("wins", 0))
	best_payout = int(data.get("best", 0))
	lessons.clear()
	for id: Variant in data.get("lessons", []):
		lessons.append(str(id))
	inventory = data.get("inventory", [])
	insurance = clampi(int(data.get("insurance", 0)), 0, 2)
	arcade = bool(data.get("arcade", false))
	assist = bool(data.get("assist", false))
	reduced_motion = bool(data.get("reduced_motion", false))
	crew = clampi(int(data.get("crew", 1)), 1, 2)
	tutorial_seen.clear()
	for phase: Variant in data.get("tutorial", []):
		tutorial_seen.append(str(phase))
	contracts = data.get("contracts", [])
	training_completed = bool(data.get("training_completed", false))


func reset() -> void:
	credits = START_CREDITS
	runs = 0
	wins = 0
	best_payout = 0
	lessons.clear()
	inventory.clear()
	insurance = 0
	arcade = false
	assist = false
	reduced_motion = false
	crew = 1
	tutorial_seen.clear()
	contracts.clear()
	training_completed = false
	save_profile()
