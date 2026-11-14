extends Node

## Estado de una partida. La logica de reglas vive aqui y en sim/; las fases solo
## leen input y dibujan, asi el estado podria volverse autoritativo en un host.

const NO_PART: Dictionary = {&"map": 0.35, &"comms": 0.4, &"vision": 0.85, &"mobility": 0.7}
const NO_POWER: Dictionary = {&"map": 0.3, &"comms": 0.2, &"light": 0.35, &"vision": 0.6}
const CHANNELS: Array[StringName] = [&"thrust", &"mobility", &"vision", &"audio", &"light", &"map", &"comms"]
## Velocidades de tiempo compartidas: 1=pausa suave, 2=normal, ... 6=maximo.
const TIME_SCALES: Array[float] = [0.5, 1.0, 2.0, 5.0, 20.0, 50.0]

var rng := RandomNumberGenerator.new()
var contract: Contract
var ship := ShipModel.new()
var mods: Dictionary = {}
var earnings: int = 0
var science: int = 0
var boxes: int = 0
var streak: int = 0
var best_streak: int = 0
var kits: int = 1
var salvage: Array[ShipPart] = []
var side_bets: Array = []
var temp: float = 0.5
var battery: float = 1.0 ## unidades de energia guardada
var spent: int = 0
var premium: int = 0
var insurance: int = 0
var free_inspections: int = 0
var outcome: StringName = &""
var outcome_text: String = ""
var grade: String = ""
var launch_grade: String = ""
var landed_body: StringName = &""
var space_state: Dictionary = {}
var pois: Array = []
var log_lines: PackedStringArray = PackedStringArray()
var respite: float = 0.0 ## segundos reales sin otro fallo critico


func begin(chosen: Contract) -> void:
	rng.randomize()
	contract = chosen
	ship = ShipModel.new()
	mods.clear()
	earnings = 0
	science = 0
	boxes = 0
	streak = 0
	best_streak = 0
	kits = 2 if Profile.has_lesson("kit") else 1
	if Profile.assist:
		kits += 1
	salvage.clear()
	side_bets.clear()
	temp = 0.5
	battery = 1.0
	spent = 0
	premium = 0
	insurance = Profile.insurance
	free_inspections = 1 if Profile.has_lesson("inspector") else 0
	if Profile.assist:
		free_inspections += 1
	outcome = &""
	outcome_text = ""
	grade = ""
	launch_grade = ""
	landed_body = &""
	space_state.clear()
	pois.clear()
	log_lines.clear()
	respite = 0.0


func _process(delta: float) -> void:
	respite = maxf(respite - delta, 0.0)


func target() -> BodyDef:
	return contract.body() if contract != null else null


func powered() -> bool:
	return battery > 0.001


func time_scale(index: int) -> float:
	return TIME_SCALES[clampi(index, 0, TIME_SCALES.size() - 1)]


func time_label(index: int) -> String:
	var scale := time_scale(index)
	if scale < 1.0:
		return "x%.1f" % scale
	return "x%d" % int(scale)


func assist_fail_mult() -> float:
	return 0.55 if Profile.assist else 1.0


func assist_payout_mult() -> float:
	return 0.85 if Profile.assist else 1.0


func channel(channel_id: StringName) -> float:
	var base := 1.0
	if NO_PART.has(channel_id):
		var have := ship.kind_channel(channel_id)
		base = NO_PART[channel_id] if have <= 0.0 else lerpf(NO_PART[channel_id], 1.0, have)
	if not powered() and NO_POWER.has(channel_id):
		base *= NO_POWER[channel_id]
	var value := clampf(base + float(mods.get(channel_id, 0.0)), 0.0, 1.0)
	if Profile.assist and channel_id in [&"map", &"vision", &"comms", &"mobility"]:
		value = maxf(value, 0.7)
	return value


func streak_mult() -> float:
	return Odds.streak_mult(streak)


func win_streak() -> void:
	streak += 1
	best_streak = maxi(best_streak, streak)
	Events.streak_changed.emit(streak)


func lose_streak() -> void:
	if streak > 0:
		Events.toast.emit("Racha perdida (x%.2f)" % streak_mult(), Color(1, 0.4, 0.3))
	streak = 0
	Events.streak_changed.emit(streak)


func note(text: String) -> void:
	log_lines.append(text)


## Una averia a la vez: el resto se salva o solo se gasta, y hay tregua despues.
func roll_stress(stress: float, kinds: Array = [], pool: Array = []) -> Array[ShipPart]:
	var hit: Array[ShipPart] = []
	var source: Array = pool if not pool.is_empty() else ship.parts
	for part: ShipPart in source:
		if not kinds.is_empty() and not kinds.has(part.def.kind):
			continue
		if part.reveal():
			Events.toast.emit("%s era %s" % [part.def.display_name, part.quality_text()], Color(0.8, 0.55, 1.0))
		if rng.randf() < part.fail_chance(stress):
			hit.append(part)
	if hit.is_empty():
		return []
	hit.sort_custom(func(a: ShipPart, b: ShipPart) -> bool:
		return a.fail_chance(stress) > b.fail_chance(stress))
	var spared: PackedStringArray = PackedStringArray()
	var worn: PackedStringArray = PackedStringArray()
	for i: int in range(1, hit.size()):
		var extra: ShipPart = hit[i]
		if rng.randf() < 0.55:
			spared.append(extra.def.display_name)
		else:
			extra.wear = minf(extra.wear + 0.08, 1.0)
			worn.append(extra.def.display_name)
	if not spared.is_empty() or not worn.is_empty():
		var msg := ""
		if not spared.is_empty():
			msg = "Suerte, aguantaron: %s." % ", ".join(spared)
		if not worn.is_empty():
			msg += (" " if not msg.is_empty() else "") + "Se gastaron: %s." % ", ".join(worn)
		Events.toast.emit(msg, Color(1.0, 0.82, 0.3))
	if not admit(hit[0]):
		return []
	return [hit[0]]


## True si esta pieza puede ser el fallo critico de este momento.
func admit(part: ShipPart) -> bool:
	if part == null or part.broken:
		return false
	if respite > 0.0 or _has_broken():
		part.wear = minf(part.wear + 0.06, 1.0)
		return false
	respite = 20.0
	return true


func _has_broken() -> bool:
	for part: ShipPart in ship.parts:
		if part.broken:
			return true
	return false


func wear_all(amount: float) -> void:
	for part: ShipPart in ship.parts:
		part.wear = minf(part.wear + amount, 1.0)


func destroy(reason: String) -> void:
	if outcome == &"lost":
		return
	outcome = &"lost"
	outcome_text = reason
	note(reason)
	Events.ship_destroyed.emit(reason)


func apply(effects: Dictionary, part: ShipPart = null) -> void:
	for key: Variant in effects:
		var value: Variant = effects[key]
		match str(key):
			"explode":
				destroy("%s explotó." % (part.def.display_name if part != null else "La nave"))
			"break":
				if part != null:
					part.broken = true
			"fix":
				if part != null:
					part.broken = false
					part.wear = 0.0
					part.thrust_mult = maxf(part.thrust_mult, 1.0)
					respite = maxf(respite, 12.0)
			"wear":
				if part != null:
					part.wear = clampf(part.wear + float(value), 0.0, 1.0)
			"thrust":
				if part != null:
					part.thrust_mult = maxf(part.thrust_mult + float(value), 0.1)
			"leak":
				ship.leak(float(value))
			"fuel":
				ship.refuel(float(value))
			"credits":
				earnings += int(value)
			"science":
				science += int(value)
			"kits":
				kits = maxi(kits + int(value), 0)
			"battery":
				battery = clampf(battery + float(value) * Thermal.battery_capacity(ship), 0.0, Thermal.battery_capacity(ship))
			"heat":
				temp = clampf(temp + float(value), 0.0, 1.2)
			"salvage":
				for i: int in int(value):
					salvage.append(random_part(ShipPart.Quality.MYSTERY))
			"boxes":
				boxes += int(value)
			"rand_break":
				var intact: Array[ShipPart] = []
				for p: ShipPart in ship.parts:
					if not p.broken and p.def.kind != &"capsule":
						intact.append(p)
				if not intact.is_empty():
					var victim: ShipPart = intact[rng.randi_range(0, intact.size() - 1)]
					if admit(victim):
						victim.broken = true
						Events.toast.emit("%s se rompió" % victim.def.display_name, Color(1, 0.35, 0.3))
					else:
						Events.toast.emit("La suerte salvó %s" % victim.def.display_name, Color(1.0, 0.82, 0.3))
			"restore":
				for mod_name: Variant in mods.keys():
					mods[mod_name] = maxf(float(mods[mod_name]), 0.0)
			"install":
				if part != null and salvage.has(part):
					salvage.erase(part)
					var capsule_index := ship.parts.find(ship.capsule())
					ship.parts.insert(capsule_index if capsule_index >= 0 else ship.parts.size(), part)
					part.reveal()
			"discard":
				salvage.erase(part)
			"rescue":
				outcome = &"stranded"
				outcome_text = "Rescate pagado por la agencia. La carga se perdió."
			"stake":
				Profile.credits -= int(value)
			"bet":
				side_bets.append({"kind": str(value), "stake": int(effects.get("amount", 0)), "mult": float(effects.get("mult", 2.0))})
			_:
				var channel_name := StringName(str(key))
				if CHANNELS.has(channel_name):
					mods[channel_name] = clampf(float(mods.get(channel_name, 0.0)) + float(value), -1.0, 0.5)


func describe(effects: Dictionary) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for key: Variant in effects:
		var value: Variant = effects[key]
		match str(key):
			"explode": bits.append("explota")
			"break": bits.append("se rompe")
			"fix": bits.append("reparada")
			"wear": bits.append("desgaste %+d %%" % int(float(value) * 100.0))
			"thrust": bits.append("empuje %+d %%" % int(float(value) * 100.0))
			"leak": bits.append("pierdes %d %% combustible" % int(float(value) * 100.0))
			"fuel": bits.append("+%d %% combustible" % int(float(value) * 100.0))
			"credits": bits.append("%+d $" % int(value))
			"science": bits.append("+%d ciencia" % int(value))
			"kits": bits.append("%+d kit" % int(value))
			"battery": bits.append("batería %+d %%" % int(float(value) * 100.0))
			"heat": bits.append("calor %+d" % int(float(value) * 100.0))
			"salvage": bits.append("+%d pieza misteriosa" % int(value))
			"boxes": bits.append("+%d caja" % int(value))
			"rand_break": bits.append("rompe una pieza al azar")
			"restore": bits.append("sistemas restaurados")
			"install": bits.append("pieza instalada")
			"discard": bits.append("pieza perdida")
			"rescue": bits.append("fin de la misión")
			"stake": bits.append("apuestas %d $" % int(value))
			"bet": bits.append("apuesta registrada")
			"mult", "amount": pass
			_: bits.append("%s %+d %%" % [str(key), int(float(value) * 100.0)])
	return ", ".join(bits)


func random_part(quality: int) -> ShipPart:
	var defs := Catalog.part_list()
	var def: PartDef = defs[rng.randi_range(0, defs.size() - 1)]
	return ShipPart.create(def, quality, rng)


## Nave y contrato de prueba para saltar fases con las teclas de depuracion.
func debug_setup() -> void:
	var contracts := Contract.generate(rng, 1)
	begin(contracts[0])
	for id: StringName in [&"motor_trueno", &"tanque_ancho", &"desacoplador", &"motor_susurro", &"tanque_largo", &"escudo_termico", &"capsula", &"paracaidas", &"panel_solar", &"radiador", &"patas", &"computadora"]:
		var def := Catalog.part(id)
		if def != null:
			ship.parts.append(ShipPart.create(def, ShipPart.Quality.USED, rng))
