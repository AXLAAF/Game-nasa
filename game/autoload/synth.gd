extends Node

## Audio sintetizado: efectos generados como WAV al arrancar y un rugido de motor
## continuo con AudioStreamGenerator. Van al bus SFX. El canal "audio" de la nave
## amortigua ese bus; la musica queda en el suyo.

const RATE := 22050
const FLIGHT_PHASES: Array[StringName] = [&"launch", &"space", &"descent"]

var engine_level: float = 0.0 ## 0..1 acelerador
var roar_level: float = 0.0 ## plasma / viento
var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _engine: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _lp1: float = 0.0
var _lp2: float = 0.0
var _phase: float = 0.0
var _level: float = 0.0
var _roar: float = 0.0
var _lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sounds()
	for i: int in 10:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_engine = AudioStreamPlayer.new()
	_engine.stream = gen
	_engine.bus = &"SFX"
	_engine.volume_db = -6.0
	add_child(_engine)
	_engine.play()
	_playback = _engine.get_stream_playback()
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	var sfx := AudioServer.get_bus_index(&"SFX")
	if sfx < 0:
		push_error("No existe el bus SFX")
		sfx = 0
	AudioServer.add_bus_effect(sfx, _lowpass)


func play(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _sounds.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _sounds[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _process(_delta: float) -> void:
	var flying := FLIGHT_PHASES.has(Router.current)
	if not flying:
		engine_level = 0.0
		roar_level = 0.0
	var audio := Run.channel(&"audio") if flying else 1.0
	_lowpass.cutoff_hz = lerpf(450.0, 20000.0, audio * audio)
	_fill_engine()


func _fill_engine() -> void:
	if _playback == null or not _engine.playing:
		return
	# Si el dispositivo de audio se cae, get_frames_available puede devolver un
	# numero enorme y este bucle congela el juego.
	var frames := mini(_playback.get_frames_available(), int(RATE / 5.0))
	for i: int in frames:
		_level = lerpf(_level, engine_level, 0.0008)
		_roar = lerpf(_roar, roar_level, 0.0008)
		var white := _rng.randf_range(-1.0, 1.0)
		var cutoff := 0.02 + _level * 0.08
		_lp1 += (white - _lp1) * cutoff
		_lp2 += (_lp1 - _lp2) * cutoff
		_phase = fmod(_phase + (38.0 + _level * 30.0) / RATE, 1.0)
		var rumble := _lp2 * 3.2 * _level + sin(_phase * TAU) * 0.18 * _level
		var hiss := (white - _lp1) * 0.35 * _roar + _lp1 * 0.6 * _roar
		var sample := clampf(rumble + hiss, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))


func _build_sounds() -> void:
	_sounds[&"click"] = _make(0.035, func(t: float, _d: float) -> float: return _square(t * 1800.0) * exp(-t * 90.0) * 0.4)
	_sounds[&"tick"] = _make(0.03, func(t: float, _d: float) -> float: return sin(t * 1300.0 * TAU) * exp(-t * 120.0) * 0.5)
	_sounds[&"beep"] = _make(0.14, func(t: float, d: float) -> float: return sin(t * 880.0 * TAU) * _env(t, d) * 0.45)
	_sounds[&"alarm"] = _make(0.6, func(t: float, d: float) -> float: return _square(t * (700.0 if fmod(t, 0.2) < 0.1 else 1000.0)) * _env(t, d) * 0.3)
	_sounds[&"boom"] = _make(1.4, _boom)
	_sounds[&"coin"] = _make(0.22, func(t: float, d: float) -> float: return _square(t * (988.0 if t < 0.07 else 1319.0)) * _env(t, d) * 0.3)
	_sounds[&"win"] = _make(0.7, _arpeggio.bind([523.0, 659.0, 784.0, 1047.0]))
	_sounds[&"lose"] = _make(0.8, func(t: float, d: float) -> float: return _saw(t * lerpf(420.0, 110.0, t / d)) * _env(t, d) * 0.35)
	_sounds[&"whoosh"] = _make(0.6, _whoosh)
	_sounds[&"thud"] = _make(0.3, func(t: float, _d: float) -> float: return (sin(t * 70.0 * TAU) * 0.8 + _rng.randf_range(-0.3, 0.3)) * exp(-t * 14.0))
	_sounds[&"ignite"] = _make(0.9, _ignite)
	_sounds[&"chime"] = _make(0.9, func(t: float, _d: float) -> float: return (sin(t * 1568.0 * TAU) + sin(t * 2093.0 * TAU) * 0.6) * exp(-t * 4.0) * 0.3 * minf(t * 200.0, 1.0))
	_sounds[&"jackpot"] = _make(1.2, _arpeggio.bind([784.0, 988.0, 1175.0, 1568.0, 1976.0, 2349.0]))
	_sounds[&"deny"] = _make(0.25, func(t: float, d: float) -> float: return _square(t * 160.0) * _env(t, d) * 0.3)


func _make(duration: float, fn: Callable) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t := float(i) / RATE
		var value := clampf(float(fn.call(t, duration)), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _env(t: float, d: float) -> float:
	return minf(t * 300.0, 1.0) * clampf((d - t) / (d * 0.6), 0.0, 1.0)


func _square(x: float) -> float:
	return 1.0 if fmod(x, 1.0) < 0.5 else -1.0


func _saw(x: float) -> float:
	return fmod(x, 1.0) * 2.0 - 1.0


func _boom(t: float, d: float) -> float:
	var noise := _rng.randf_range(-1.0, 1.0)
	_lp1 += (noise - _lp1) * lerpf(0.5, 0.03, t / d)
	return (_lp1 * 1.8 + sin(t * lerpf(90.0, 28.0, t / d) * TAU) * 0.6) * exp(-t * 3.0)


func _whoosh(t: float, d: float) -> float:
	var noise := _rng.randf_range(-1.0, 1.0)
	_lp1 += (noise - _lp1) * lerpf(0.02, 0.4, sin(t / d * PI))
	return _lp1 * sin(t / d * PI) * 0.8


func _ignite(t: float, d: float) -> float:
	var noise := _rng.randf_range(-1.0, 1.0)
	_lp1 += (noise - _lp1) * 0.15
	return _lp1 * minf(t * 6.0, 1.0) * clampf((d - t) / 0.4, 0.0, 1.0) * 1.4


func _arpeggio(t: float, d: float, notes: Array) -> float:
	var step := d / notes.size()
	var index := mini(int(t / step), notes.size() - 1)
	var local := t - index * step
	return _square(t * float(notes[index])) * exp(-local * 9.0) * 0.28 * minf(local * 300.0, 1.0)
