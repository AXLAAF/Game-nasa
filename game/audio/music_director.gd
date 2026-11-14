class_name MusicDirector
extends Node
## Controlador musical por fase con crossfade sincronizado en modo caos orbital.

const TRACKS := {
	&"hangar": "res://assets/music/ejemplos/1_planeacion.mp3",
	&"takeoff": "res://assets/music/ejemplos/3_despegue.mp3",
	&"flight": "res://assets/music/ejemplos/4_navegacion.mp3",
	&"flight_chaos": "res://assets/music/ejemplos/4b_navegacion_caos.mp3",
	&"debrief": "res://assets/music/ejemplos/7_regreso_pago.mp3",
}

const BASE_DB: float = -12.0
const SILENT_DB: float = -60.0

var active_phase: StringName = &""
var chaos_active: bool = false
var _chaos_blend: float = 0.0
var _muted: bool = false

var _main_player: AudioStreamPlayer
var _chaos_player: AudioStreamPlayer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_main_player = AudioStreamPlayer.new()
	_main_player.volume_db = BASE_DB
	add_child(_main_player)

	_chaos_player = AudioStreamPlayer.new()
	_chaos_player.volume_db = SILENT_DB
	add_child(_chaos_player)


func _exit_tree() -> void:
	if _main_player != null:
		_main_player.stop()
		_main_player.stream = null
	if _chaos_player != null:
		_chaos_player.stop()
		_chaos_player.stream = null


func set_phase(phase: StringName) -> void:
	if phase == active_phase:
		return
	active_phase = phase
	chaos_active = false
	_chaos_blend = 0.0
	if _main_player == null:
		return

	_main_player.stop()
	_chaos_player.stop()

	var main_stream := _load_loop_stream(str(TRACKS.get(phase, "")))
	if main_stream == null:
		return
	_main_player.stream = main_stream
	_main_player.volume_db = SILENT_DB if _muted else BASE_DB
	_main_player.play()

	if phase == &"flight":
		var chaos_stream := _load_loop_stream(str(TRACKS[&"flight_chaos"]))
		if chaos_stream != null:
			_chaos_player.stream = chaos_stream
			_chaos_player.volume_db = SILENT_DB
			_chaos_player.play()


func set_chaos_active(active: bool) -> void:
	chaos_active = active


func toggle_mute() -> bool:
	_muted = not _muted
	_apply_volumes()
	return _muted


func _process(delta: float) -> void:
	if _main_player == null or active_phase != &"flight":
		return
	var target := 1.0 if chaos_active else 0.0
	_chaos_blend = move_toward(_chaos_blend, target, delta * 1.6)
	_apply_volumes()


func _apply_volumes() -> void:
	if _main_player == null:
		return
	if _muted:
		_main_player.volume_db = SILENT_DB
		_chaos_player.volume_db = SILENT_DB
		return
	if active_phase == &"flight":
		_main_player.volume_db = lerpf(BASE_DB, SILENT_DB, _chaos_blend)
		_chaos_player.volume_db = lerpf(SILENT_DB, BASE_DB + 1.0, _chaos_blend)
	else:
		_main_player.volume_db = BASE_DB
		_chaos_player.volume_db = SILENT_DB


func _load_loop_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var st := ResourceLoader.load(path) as AudioStream
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	return st
