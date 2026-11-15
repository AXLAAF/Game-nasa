extends Node

## Temas de res://music. Un directorio en stems/ es procedural: sus capas
## (pads, bass, perc, tex) suenan juntas y entran segun el caos de la partida.
## El resto, en ejemplos/, son temas enteros en bucle. Si un nombre existe en
## los dos sitios, mandan los stems.

const STEM_DIR := "res://music/stems"
const SIMPLE_DIR := "res://music/ejemplos"
const AUDIO_EXT: PackedStringArray = ["ogg", "mp3", "wav"]
const STEM_ORDER: Array[StringName] = [&"pads", &"bass", &"perc", &"tex"]
const LAYER_IN: Dictionary = {
	&"pads": Vector2(0.0, 0.0),
	&"bass": Vector2(0.08, 0.40),
	&"perc": Vector2(0.28, 0.70),
	&"tex": Vector2(0.52, 0.90),
}
const PHASE_CUE: Dictionary = {
	&"title": &"1_planeacion",
	&"hangar": &"1_planeacion",
	&"assembly": &"2_taller",
	&"launch": &"3_despegue",
	&"descent": &"5_aterrizaje",
	&"debrief": &"7_regreso_pago",
}
const CHAOS_ENTER := 0.62
const CHAOS_EXIT := 0.40
const FADE_SEC := 1.2
const SILENCE_DB := -60.0
const REST_MUSIC_DB := -3.0
const LAUNCH_MUSIC_DB := 0.0
const LAUNCH_SFX_DB := -12.0

var chaos: float = 0.0
var current_cue: StringName = &""
var follow_phase: bool = true
var _cues: Dictionary = {}
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _live: AudioStreamPlayer
var _fade: Tween
var _chaos_bed: bool = false
var _near_poi: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan()
	_a = _make_player("MusicA")
	_b = _make_player("MusicB")


func _process(delta: float) -> void:
	chaos = lerpf(chaos, _sample_chaos(), 1.0 - exp(-1.5 * delta))
	_duck(delta)
	if follow_phase:
		play_cue(_desired())
	_apply_layers()


func play_cue(cue_id: StringName) -> void:
	if cue_id == current_cue and (cue_id == &"" or (_live != null and _live.playing)):
		return
	current_cue = cue_id
	_kill_fade()
	if cue_id == &"" or not _cues.has(cue_id):
		if cue_id != &"":
			push_warning("Music: no existe el tema %s" % cue_id)
		_fade_out(_live)
		return
	var nxt := _b if _live == _a else _a
	nxt.stream = _make_stream(cue_id)
	nxt.volume_db = -40.0
	nxt.play()
	var prev := _live
	_live = nxt
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.set_parallel(true)
	_fade.tween_property(nxt, "volume_db", 0.0, FADE_SEC)
	if prev != null and prev.playing:
		_fade.tween_property(prev, "volume_db", -40.0, FADE_SEC)
		_fade.chain().tween_callback(prev.stop)


func stop() -> void:
	current_cue = &""
	_kill_fade()
	for player: AudioStreamPlayer in [_a, _b]:
		if player != null:
			player.stop()
	_live = null


func is_playing() -> bool:
	return _live != null and _live.playing


func live_stream() -> AudioStream:
	return null if _live == null else _live.stream


func kind(cue_id: StringName) -> StringName:
	if not _cues.has(cue_id):
		return &""
	return _cues[cue_id].kind


func layer_count(cue_id: StringName) -> int:
	if kind(cue_id) != &"stems":
		return 0
	return (_cues[cue_id].layers as Dictionary).size()


static func stem_gain(stem: StringName, amount: float) -> float:
	var span: Vector2 = LAYER_IN.get(stem, Vector2(0.0, 1.0))
	if span.y <= span.x:
		return 1.0
	return smoothstep(span.x, span.y, clampf(amount, 0.0, 1.0))


static func gain_db(gain: float) -> float:
	if gain <= 0.001:
		return SILENCE_DB
	return linear_to_db(gain)


## En despegue la musica va delante: el bus Music sube y SFX baja.
## Con el juego en pausa (carta, tutorial) no se aplica, para que el efecto de la carta se oiga.
static func launch_mix(launch: bool, paused: bool) -> Vector2:
	if launch and not paused:
		return Vector2(LAUNCH_MUSIC_DB, LAUNCH_SFX_DB)
	return Vector2(REST_MUSIC_DB, 0.0)


static func space_cue(exploring: bool, amount: float, chaos_bed: bool) -> StringName:
	if exploring:
		return &"6_exploracion"
	if chaos_bed:
		return &"4_navegacion" if amount < CHAOS_EXIT else &"4b_navegacion_caos"
	return &"4b_navegacion_caos" if amount > CHAOS_ENTER else &"4_navegacion"


func _desired() -> StringName:
	if Router.current == &"space":
		var cue := space_cue(_exploring(), chaos, _chaos_bed)
		if cue != &"6_exploracion":
			_chaos_bed = cue == &"4b_navegacion_caos"
		return cue
	_chaos_bed = false
	return StringName(PHASE_CUE.get(Router.current, &""))


func _sample_chaos() -> float:
	var moment := 0.0
	var parts := Run.ship.parts
	if not parts.is_empty():
		var broken := 0.0
		var wear := 0.0
		for part: ShipPart in parts:
			broken += 1.0 if part.broken else 0.0
			wear += part.wear
		var n := float(parts.size())
		moment = clampf(broken / n * 1.35 + wear / n * 0.45, 0.0, 1.0)
	if Run.respite > 0.0:
		moment = maxf(moment, 0.58)
	var phase := _phase()
	if phase != null:
		var stress: Variant = phase.get("stress")
		if stress != null:
			moment = maxf(moment, clampf(float(stress), 0.0, 1.0))
		var overdrive: Variant = phase.get("overdrive")
		if overdrive != null:
			moment = maxf(moment, clampf(float(overdrive), 0.0, 1.0))
		var flare: Variant = phase.get("flare_warn")
		if flare != null and float(flare) >= 0.0:
			moment = maxf(moment, 0.8)
		if phase.get("burning") == true:
			moment = maxf(moment, 0.18)
	var thermal := clampf(absf(Run.temp - 0.5) * 2.0, 0.0, 1.0)
	return clampf(moment * 0.78 + thermal * 0.35, 0.0, 1.0)


func _exploring() -> bool:
	if get_tree().get_first_node_in_group(&"minigame") != null:
		return true
	var phase := _phase()
	if phase == null:
		_near_poi = false
		return false
	var target: Variant = phase.get("target")
	if not (target is Dictionary):
		_near_poi = false
		return false
	var state: Variant = phase.get("st")
	if not (state is Dictionary) or not (state as Dictionary).has("pos") or not phase.has_method("poi_pos"):
		_near_poi = true
		return true
	var st: Dictionary = state
	var at: Vector2 = phase.poi_pos(float(st.get("t", 0.0)), target)
	var dist := (st.pos as Vector2).distance_to(at)
	_near_poi = dist < (1200.0 if _near_poi else 800.0)
	return _near_poi


func _apply_layers() -> void:
	for player: AudioStreamPlayer in [_a, _b]:
		if player == null or not player.playing:
			continue
		var sync := player.stream as AudioStreamSynchronized
		if sync == null or not sync.has_meta(&"stems"):
			continue
		var names: Array = sync.get_meta(&"stems")
		for i: int in names.size():
			sync.set_sync_stream_volume(i, gain_db(stem_gain(StringName(names[i]), chaos)))


func _scan() -> void:
	_cues.clear()
	var stem_count := 0
	var stem_root := DirAccess.open(STEM_DIR)
	if stem_root != null:
		for dir_name: String in stem_root.get_directories():
			var layers: Dictionary = {}
			var folder := STEM_DIR.path_join(dir_name)
			for stem: StringName in STEM_ORDER:
				var path := _find_audio(folder, String(stem))
				if path.is_empty():
					continue
				var stream := _load_loop(path)
				if stream != null:
					layers[stem] = stream
			if layers.is_empty():
				continue
			_cues[StringName(dir_name)] = {"kind": &"stems", "layers": layers}
			stem_count += 1
	var simple_root := DirAccess.open(SIMPLE_DIR)
	if simple_root != null:
		for file_name: String in simple_root.get_files():
			var ext := file_name.get_extension()
			if ext not in AUDIO_EXT:
				continue
			var cue_id := StringName(file_name.get_basename())
			if _cues.has(cue_id):
				continue
			var stream := _load_loop(SIMPLE_DIR.path_join(file_name))
			if stream != null:
				_cues[cue_id] = {"kind": &"simple", "stream": stream}
	print("Music: %d temas, %d procedurales" % [_cues.size(), stem_count])


func _find_audio(folder: String, base: String) -> String:
	for ext: String in AUDIO_EXT:
		var path := folder.path_join("%s.%s" % [base, ext])
		if FileAccess.file_exists(path):
			return path
	return ""


func _load_loop(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("Music: no carga %s" % path)
		return null
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _make_stream(cue_id: StringName) -> AudioStream:
	var cue: Dictionary = _cues[cue_id]
	if cue.kind == &"simple":
		return cue.stream
	var layers: Dictionary = cue.layers
	var names: Array[StringName] = []
	for stem: StringName in STEM_ORDER:
		if layers.has(stem):
			names.append(stem)
	var sync := AudioStreamSynchronized.new()
	sync.set_stream_count(names.size())
	for i: int in names.size():
		sync.set_sync_stream(i, layers[names[i]])
		sync.set_sync_stream_volume(i, gain_db(stem_gain(names[i], chaos)))
	sync.set_meta(&"stems", names)
	return sync


func _make_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = &"Music"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _duck(delta: float) -> void:
	var weight := 1.0 - exp(-8.0 * delta)
	var duck := AudioServer.get_bus_index(&"MusicDuck")
	if duck >= 0:
		var duck_target := -10.0 if get_tree().paused else 0.0
		var duck_now := AudioServer.get_bus_volume_db(duck)
		AudioServer.set_bus_volume_db(duck, lerpf(duck_now, duck_target, weight))
	var mix := launch_mix(Router.current == &"launch", get_tree().paused)
	var music := AudioServer.get_bus_index(&"Music")
	if music >= 0:
		var music_now := AudioServer.get_bus_volume_db(music)
		AudioServer.set_bus_volume_db(music, lerpf(music_now, mix.x + gain_db(Settings.music), weight))
	var sfx := AudioServer.get_bus_index(&"SFX")
	if sfx >= 0:
		var sfx_now := AudioServer.get_bus_volume_db(sfx)
		AudioServer.set_bus_volume_db(sfx, lerpf(sfx_now, mix.y + gain_db(Settings.sfx), weight))


func _fade_out(player: AudioStreamPlayer) -> void:
	if player == null or not player.playing:
		if _live == player:
			_live = null
		return
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(player, "volume_db", -40.0, FADE_SEC)
	_fade.tween_callback(func() -> void:
		player.stop()
		if _live == player:
			_live = null
	)


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()


func _phase() -> Node:
	var nodes := get_tree().get_nodes_in_group(&"phase")
	if nodes.is_empty():
		return null
	return nodes[0]
