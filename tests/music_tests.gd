extends RefCounted

var passed := 0
var failed := 0


func run() -> int:
	_test_layers()
	_test_space_cue()
	_test_catalog()
	_test_chaos_without_flight()
	_test_launch_mix()
	await _test_playback()
	print("Music: %d passed, %d failed" % [passed, failed])
	return failed


func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)


func near(a: float, b: float, tolerance: float, label: String) -> void:
	check(absf(a - b) <= tolerance, "%s (got %.3f, want %.3f)" % [label, a, b])


func _test_layers() -> void:
	near(Music.stem_gain(&"pads", 0.0), 1.0, 0.001, "pads en calma")
	near(Music.stem_gain(&"bass", 0.0), 0.0, 0.001, "bass callado")
	near(Music.stem_gain(&"bass", 0.40), 1.0, 0.001, "bass lleno")
	near(Music.stem_gain(&"tex", 0.0), 0.0, 0.001, "tex callado")
	near(Music.stem_gain(&"tex", 1.0), 1.0, 0.001, "tex en caos")
	check(Music.gain_db(0.0) == -60.0, "silencio finito")
	near(Music.gain_db(1.0), 0.0, 0.001, "ganancia unidad")


func _test_space_cue() -> void:
	check(Music.space_cue(false, 0.2, false) == &"4_navegacion", "navegacion en calma")
	check(Music.space_cue(false, 0.5, false) == &"4_navegacion", "todavia no entra el caos")
	check(Music.space_cue(false, 0.7, false) == &"4b_navegacion_caos", "entra el caos")
	check(Music.space_cue(false, 0.5, true) == &"4b_navegacion_caos", "la histeresis sostiene el caos")
	check(Music.space_cue(false, 0.3, true) == &"4_navegacion", "sale del caos")
	check(Music.space_cue(true, 0.9, true) == &"6_exploracion", "explorar sustituye al caos")


func _test_catalog() -> void:
	check(Music.kind(&"1_planeacion") == &"simple", "planeacion es tema")
	check(Music.kind(&"2_taller") == &"simple", "taller es tema")
	check(Music.kind(&"5_aterrizaje") == &"simple", "aterrizaje es tema")
	check(Music.kind(&"7_regreso_pago") == &"simple", "regreso es tema")
	check(Music.kind(&"3_despegue") == &"stems", "despegue es procedural")
	check(Music.kind(&"4_navegacion") == &"stems", "navegacion usa stems")
	check(Music.kind(&"4b_navegacion_caos") == &"stems", "caos usa stems")
	check(Music.kind(&"6_exploracion") == &"stems", "exploracion usa stems")
	check(Music.layer_count(&"3_despegue") == 4, "despegue tiene 4 capas")


func _test_chaos_without_flight() -> void:
	var phase := Node.new()
	phase.add_to_group(&"phase")
	(Engine.get_main_loop() as SceneTree).root.add_child(phase)
	var value := Music._sample_chaos()
	check(value >= 0.0 and value <= 1.0, "caos sin datos de vuelo")
	phase.queue_free()


func _test_launch_mix() -> void:
	var saved_music := Settings.music
	var saved_sfx := Settings.sfx
	Settings.music = 1.0
	Settings.sfx = 1.0
	check(Music.launch_mix(true, false) == Vector2(0.0, -12.0), "despegue prioriza la musica")
	check(Music.launch_mix(false, false) == Vector2(-3.0, 0.0), "fuera de despegue la mezcla vuelve")
	check(Music.launch_mix(true, true) == Vector2(-3.0, 0.0), "en pausa no se entierran los efectos")
	var saved := Router.current
	Router.current = &"launch"
	Music._duck(10.0)
	var sfx := AudioServer.get_bus_index(&"SFX")
	var music := AudioServer.get_bus_index(&"Music")
	near(AudioServer.get_bus_volume_db(sfx), -12.0, 0.05, "SFX a -12 dB en despegue")
	near(AudioServer.get_bus_volume_db(music), 0.0, 0.05, "Music a 0 dB en despegue")
	Router.current = saved
	Music._duck(10.0)
	near(AudioServer.get_bus_volume_db(sfx), 0.0, 0.05, "SFX restaurado")
	near(AudioServer.get_bus_volume_db(music), -3.0, 0.05, "Music restaurado")
	Settings.music = 0.5
	Music._duck(10.0)
	near(AudioServer.get_bus_volume_db(music), -3.0 + linear_to_db(0.5), 0.05, "Music respeta el volumen elegido")
	var tree := (Engine.get_main_loop() as SceneTree)
	tree.paused = true
	Music._duck(10.0)
	near(AudioServer.get_bus_volume_db(music), -3.0 + linear_to_db(0.5), 0.05, "Music no cambia al pausar")
	near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"MusicDuck")), -10.0, 0.05, "MusicDuck aplica la pausa")
	tree.paused = false
	Settings.music = saved_music
	Settings.sfx = saved_sfx
	Music._duck(10.0)


func _test_playback() -> void:
	Music.follow_phase = false
	Music.play_cue(&"2_taller")
	await (Engine.get_main_loop() as SceneTree).create_timer(0.35).timeout
	check(Music.current_cue == &"2_taller", "suena el taller")
	check(Music.is_playing(), "el tema esta en play")
	Music.play_cue(&"3_despegue")
	await (Engine.get_main_loop() as SceneTree).create_timer(0.45).timeout
	check(Music.current_cue == &"3_despegue", "cambia a despegue")
	check(Music.is_playing(), "los stems estan en play")
	var sync := Music.live_stream() as AudioStreamSynchronized
	check(sync != null, "el procedural es un stream sincronizado")
	if sync != null:
		check(sync.get_stream_count() == 4, "cuatro capas en el player")
		Music.chaos = 0.0
		Music._apply_layers()
		near(sync.get_sync_stream_volume(0), 0.0, 0.05, "pads a 0 dB")
		check(sync.get_sync_stream_volume(3) <= -40.0, "tex callada con caos 0")
		Music.chaos = 1.0
		Music._apply_layers()
		near(sync.get_sync_stream_volume(3), 0.0, 0.05, "tex presente con caos 1")
	Music.stop()
	Music.follow_phase = true
