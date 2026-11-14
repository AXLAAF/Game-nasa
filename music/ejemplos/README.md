# Ejemplos de musica por etapa

Bocetos generados con ElevenLabs Music (`eleven_music_v2_5`) el 2026-11-14 para fijar la direccion musical. No son definitivos.

Referencia de estilo: "Inhale" de John Luther (7CULT, 2026), melodic house / melodic techno. Ideas de musica espacial por etapa tomadas de "Que hace a la musica espacial sonar asi?" (Ludofonia) y de Sean Atkinson, "Soaring Through the Sky" (Music Theory Online 25.2, 2019).

| Archivo | Etapa | Duracion | LUFS | Prompt |
|---|---|---|---|---|
| `1_planeacion.mp3` | 1 Planeacion (tablero) | 2:00 | -14.8 | Melodic house 118 BPM, calmo y algo melancolico: pads analogicos, bajo suave, kick apagado, arpegio pulsado, wobble de cinta. Empieza escaso como una inhalacion y se abre con barridos de filtro. |
| `2_taller.mp3` | 2 Taller | 1:50 | -12.2 | Melodic techno 122 BPM, juguetón y mecanico: ostinato de arpegiador analogico, percusion metalica, bajo acid. |
| `3_despegue.mp3` | 3 Despegue | 1:30 | -12.1 | Melodic techno 126 BPM: cuenta atras tensa, arpegios ascendentes, melodia en modo lidio con saltos de quinta, risers y climax triunfal. |
| `4_navegacion.mp3` | 4 Navegacion | 2:00 | -13.5 | Melodic house downtempo 100 BPM, ingravido: arpegio en ternario, pads amplios, reverb y delay largos que suenan lejanos. |
| `4b_navegacion_caos.mp3` | 4 Navegacion, con tareas acumuladas | 2:00 | -11.7 | Melodic techno a 100 BPM en Do menor (misma tonica y tempo que `4_navegacion`, ~99 BPM en Do mayor): mismo arpegio ternario y pads, ahora con hi-hats al doble, bajo distorsionado, percusion de chatarra, glitches y stabs de alarma. Panico juguetón. |
| `5_aterrizaje.mp3` | 5 Aterrizaje | 1:30 | -12.3 | Melodic techno 128 BPM en menor, urgente: arpegios descendentes, stabs de alarma, presion creciente y alivio final. |
| `6_exploracion.mp3` | 6 Exploracion de superficie | 2:00 | -16.3 | Ambient melodic house 110 BPM, misterioso: dron en nota pedal, plucks lejanos con eco, frases que no resuelven. |
| `7_regreso_pago.mp3` | 7 Regreso, pago y deuda | 2:00 | -13.1 | Melodic house 120 BPM, regreso agridulce: acordes emotivos en mayor, lead brillante, final euforico y fade. |

Notas:
- Revisados con earshot: ninguno lee como cancion con voz; `2_taller` dio una lectura debil de voz, confirmar a oido.
- `4b_navegacion_caos` medido con earshot: 99.4 BPM y tonica Do igual que `4_navegacion` (cruce limpio); suena mas oscuro y agresivo ("techno agresivo con bajo distorsionado" z +2.6 frente a +1.2 del base), 2 dB mas fuerte y mas brillante, pero no lee como "frenetico con alarmas" ni es mas denso en golpes. Si falta caos, reforzarlo en el juego con capas de SFX de averias.
- `4b_navegacion_caos` entra cuando se acumulan tareas: propuesta `EventDirector.active_count(world) >= max_simultaneous()` (1, 2, 3, 3 averias segun 1-4 jugadores), y vuelve a `4_navegacion` al bajar. Mismo tempo y tonica para cruzarlos en el compas sin corte.
- `4_navegacion` lee mas "pop corporativo energico" que ingravido: candidato a regenerar.
- Volumen dispar (-12 a -16 LUFS): normalizar antes de integrar.
- MP3 no hace loop sin hueco en Godot; para musica en bucle usar OGG Vorbis en la version final.
