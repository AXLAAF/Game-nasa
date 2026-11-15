extends RefCounted

const SPANISH_ACCENTS := "áéíóúñ¿¡"
const SPANISH_WORDS := ["el", "la", "los", "las", "del", "con", "para", "que", "una", "tu", "te", "se", "por", "hay", "más", "sin", "al", "su", "pulsa", "elige", "nave", "pieza", "piezas", "misión", "combustible"]

var tree: SceneTree
var lang := "en"
var dir := "user://i18n_shots"
var shots := false
var seen: Dictionary = {}
var suspicious: Array[String] = []


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	if OS.get_environment("I18N_LANG") != "":
		lang = OS.get_environment("I18N_LANG")
	if OS.get_environment("I18N_DIR") != "":
		dir = OS.get_environment("I18N_DIR")
	shots = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	Profile.persistence_enabled = false # no tocar el perfil guardado: esto juega una partida de prueba
	var original_language := Settings.language
	Settings.language = lang
	Settings.apply_language()
	for phase: StringName in Tutorial.ORDER:
		if not Profile.tutorial_seen.has(String(phase)):
			Profile.tutorial_seen.append(String(phase))
	tree.root.add_child(load("res://game/main.tscn").instantiate())
	await _wait(1.0)
	await _snap("0_title")
	var title := tree.get_first_node_in_group("phase")
	title._new_game()
	await _wait(0.5)
	await _snap("0_title_new_game")
	Modal.close_all()
	title._credits()
	await _wait(0.5)
	await _snap("0_title_credits")
	Modal.close_all()
	await _go(&"hangar")
	await _wait(1.0)
	await _snap("1_hangar")
	Run.debug_setup()
	var built: Array[ShipPart] = Run.ship.parts.duplicate()
	Run.ship.parts.clear()
	await _go(&"assembly")
	await _wait(1.5)
	await _snap("2_assembly_empty")
	Run.ship.parts.assign(built)
	for phase: StringName in [&"assembly", &"launch", &"space"]:
		await _go(phase)
		await _wait(2.5)
		await _snap("%d_%s" % [Tutorial.ORDER.find(phase) + 1, phase])
	var space := tree.get_first_node_in_group("phase")
	for card_id: StringName in Catalog.encounters:
		var def: EncounterDef = Catalog.encounters[card_id]
		Card.show_card({"title": def.title, "text": def.text, "tone": &"encounter", "rarity": 1, "choices": def.choices, "scanned": true})
		await _wait(0.15)
		_collect("card_encounter", tree.root)
		Card.clear_queue()
	for card_id: StringName in Catalog.malfunctions:
		var mal: MalfunctionDef = Catalog.malfunctions[card_id]
		Card.show_card({"title": mal.title, "text": mal.text.replace("%part%", Run.ship.parts[0].def.display_name), "tone": &"malfunction", "part": Run.ship.parts[0], "choices": mal.choices, "scanned": true})
		await _wait(0.15)
		_collect("card_malfunction", tree.root)
		Card.clear_queue()
	for method: String in ["_stranded_card", "_repair_card", "_encounter"]:
		if method == "_encounter":
			space._encounter({"kind": &"relic", "name": "Opportunity", "text": "Opportunity dejó de llamar el 10 de junio de 2018, cubierto por una tormenta de polvo en Meridiani. La NASA no volvió a oírlo.", "id": 1, "rarity": 1, "scanned": false})
		elif space.has_method(method):
			space.call(method)
		await _wait(0.2)
		_collect("card_" + method, tree.root)
		Card.clear_queue()
	Card.malfunction(Run.ship.parts[0])
	await _wait(0.6)
	await _snap("7_card")
	Card.clear_queue()
	await _go(&"descent")
	await _wait(2.0)
	await _snap("5_descent_entry")
	tree.get_first_node_in_group("phase")._commit()
	await _wait(3.0)
	Card.clear_queue()
	tree.paused = false
	await _snap("5_descent_flight")
	Run.outcome = &"delivered"
	Run.grade = "A"
	await _go(&"debrief")
	await _wait(5.0)
	await _snap("6_debrief")
	await _go(&"hangar")
	await _wait(1.0)
	Tutorial.replay()
	await _wait(0.5)
	await _snap("8_tutorial")
	Tutorial._open._skip()
	await _wait(0.5)
	Pause.open()
	await _wait(0.6)
	await _snap("9_pause")
	SettingsPanel.show_panel()
	await _wait(0.6)
	await _snap("10_settings")
	Modal.close_all()
	await _go(&"training")
	await _wait(1.5)
	await _snap("11_training")
	await _go(&"title")
	await _wait(1.0)
	_write()
	Settings.language = original_language # el panel de ajustes guarda al cerrarse: se deja como estaba
	Settings.apply_language()
	Settings.save()
	return 0


func _go(phase: StringName) -> void:
	while Router.is_busy():
		await tree.process_frame
	Router.go(phase)


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout


func _snap(name: String) -> void:
	_collect(name, tree.root)
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	if tree.root.use_hdr_2d:
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
	image.save_png(dir.path_join("%s_%s.png" % [lang, name]))


func _collect(screen: String, node: Node) -> void:
	var texts: Array[String] = []
	if node is Label or node is Button or node is RichTextLabel or node.get_script() != null and "text" in node:
		var raw: Variant = node.get("text")
		if raw is String and not (raw as String).strip_edges().is_empty():
			texts.append(raw)
	if node is Control and (node as Control).tooltip_text != "":
		texts.append((node as Control).tooltip_text)
	for raw_text: String in texts:
		var shown := tree.root.tr(raw_text)
		var key := "%s\t%s" % [screen, shown]
		if seen.has(key):
			continue
		seen[key] = true
		if lang == "en" and _looks_spanish(shown):
			suspicious.append("%s: %s" % [screen, shown.replace("\n", "\\n")])
	for child in node.get_children():
		_collect(screen, child)


func _looks_spanish(text: String) -> bool:
	for ch in SPANISH_ACCENTS:
		if text.contains(ch):
			return true
	var hits := 0
	for word: String in text.to_lower().replace(",", " ").replace(".", " ").split(" ", false):
		if SPANISH_WORDS.has(word):
			hits += 1
	return hits >= 2


func _write() -> void:
	var lines: Array[String] = []
	for key: String in seen:
		lines.append(key)
	var f := FileAccess.open(dir.path_join("i18n_%s.txt" % lang), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("I18N ", lang, ": ", seen.size(), " textos, ", suspicious.size(), " sospechosos de ser espanol")
	for s in suspicious:
		print("  ?? ", s)
