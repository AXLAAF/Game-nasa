class_name SynthSfx
extends Node

var _player: AudioStreamPlayer
var _gen: AudioStreamGenerator
var _sample_rate: float = 22050.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = _sample_rate
	_gen.buffer_length = 0.25
	_player = AudioStreamPlayer.new()
	_player.stream = _gen
	_player.volume_db = -10.0
	add_child(_player)
	_player.play()


func _exit_tree() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null
	_gen = null


func play_tone(freq_hz: float, dur_s: float = 0.12, wave: StringName = &"sine", amp: float = 0.25) -> void:
	if _player == null or not _player.playing:
		return
	var pb := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var frames := mini(int(dur_s * _sample_rate), pb.get_frames_available())
	var phase := 0.0
	var inc := freq_hz / _sample_rate
	for i: int in range(frames):
		var env := 1.0 - float(i) / float(maxi(frames, 1))
		var sample := 0.0
		if wave == &"square":
			sample = 1.0 if phase < 0.5 else -1.0
		elif wave == &"noise":
			sample = randf_range(-1.0, 1.0)
		else:
			sample = sin(phase * TAU)
		pb.push_frame(Vector2.ONE * sample * amp * env)
		phase = fposmod(phase + inc, 1.0)


func play_alarm() -> void:
	play_tone(780.0, 0.14, &"square", 0.18)


func play_airlock() -> void:
	play_tone(180.0, 0.22, &"noise", 0.26)


func play_dsn_chime() -> void:
	play_tone(1046.5, 0.10, &"sine", 0.20)


func play_click() -> void:
	play_tone(520.0, 0.05, &"sine", 0.16)
