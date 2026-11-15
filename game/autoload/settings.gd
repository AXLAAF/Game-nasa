extends Node

const PATH := "user://settings.cfg"
## Idiomas del juego. El texto original del codigo esta en espanol; el ingles vive en localization/en.po.
const LANGUAGES: Array[String] = ["en", "es"]
const DEFAULT_LANGUAGE := "en"

var master: float = 1.0
var music: float = 0.8
var sfx: float = 1.0
var language: String = DEFAULT_LANGUAGE ## "en" o "es"; no se usa el idioma del sistema operativo


func _ready() -> void:
	load_settings()
	apply_audio()
	apply_language()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	master = clampf(float(config.get_value("audio", "master", master)), 0.0, 1.0)
	music = clampf(float(config.get_value("audio", "music", music)), 0.0, 1.0)
	sfx = clampf(float(config.get_value("audio", "sfx", sfx)), 0.0, 1.0)
	var saved := str(config.get_value("general", "language", DEFAULT_LANGUAGE))
	language = saved if LANGUAGES.has(saved) else DEFAULT_LANGUAGE


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master)
	config.set_value("audio", "music", music)
	config.set_value("audio", "sfx", sfx)
	config.set_value("general", "language", language)
	if config.save(PATH) != OK:
		push_warning("Settings: no se pudo guardar en %s" % PATH)


func apply_audio() -> void:
	# Music y SFX no se tocan aqui: Music._duck los mezcla cada frame sobre estas preferencias.
	AudioServer.set_bus_volume_linear(0, master)


func apply_language() -> void:
	TranslationServer.set_locale(language)


## Cambia el idioma y lo aplica. Devuelve false si el codigo no existe o ya estaba activo.
func set_language(code: String) -> bool:
	if not LANGUAGES.has(code) or code == language:
		return false
	language = code
	apply_language()
	return true
