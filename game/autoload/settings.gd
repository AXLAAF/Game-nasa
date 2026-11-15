extends Node

const PATH := "user://settings.cfg"

var master: float = 1.0
var music: float = 0.8
var sfx: float = 1.0


func _ready() -> void:
	load_settings()
	apply_audio()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	master = clampf(float(config.get_value("audio", "master", master)), 0.0, 1.0)
	music = clampf(float(config.get_value("audio", "music", music)), 0.0, 1.0)
	sfx = clampf(float(config.get_value("audio", "sfx", sfx)), 0.0, 1.0)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master)
	config.set_value("audio", "music", music)
	config.set_value("audio", "sfx", sfx)
	if config.save(PATH) != OK:
		push_warning("Settings: no se pudo guardar en %s" % PATH)


func apply_audio() -> void:
	# Music y SFX no se tocan aqui: Music._duck los mezcla cada frame sobre estas preferencias.
	AudioServer.set_bus_volume_linear(0, master)
