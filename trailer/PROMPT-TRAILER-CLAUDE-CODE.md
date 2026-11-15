# Prompt Maestro y Documentacion del Trailer: Margin Zero: Orbital Debt

## 1. Resumen de Entregables en `trailer/`

- `MarginZero_Final_SpaceApps2026.mp4`: Trailer final entregado para NASA Space Apps Challenge 2026 (`1920x1080`, `30 fps`, `891 fotogramas`, `29.700000 s`, H.264 + AAC 48 kHz estereo, `-14.04 LUFS` integrados, `-1.66 dBTP` de pico verdadero).
- `MarginZero_Guion_EN_ES.pdf`: Guion oficial bilingue y tabla de tiempos obligatoria (`29.7 s`).
- `MarginZero_Final_ContactSheet_30s.jpg`: Hoja de contacto de 30 fotogramas (`1 fps`).
- `project/margin_zero_trailer_v2.ecproj`: Proyecto editable de EffectCraft con composicion `Main`, fuentes del repositorio (`Pixelta`, `Exo 2`, `Space Mono`) y desenfoque de movimiento nativo con obturador de `240 grados`.
- `project/margin_zero_trailer.fcproj`: Proyecto multipista editable de FilmCraft (`V1` video, `A1` locucion ElevenLabs, `A2` musica original 120 BPM Re menor, `A3` efectos cinematograficos ElevenLabs, `A4` mezcla maestra de referencia y 18 marcadores de programa).
- `project/vo/`, `project/music/`, `project/sfx/`, `project/audio_trailer_master.wav`: Todos los audios originales generados con el MCP de ElevenLabs y sus stems sincronizados.
- `project/assets/` y `project/scripts/`: Clips de gameplay en movimiento en ingles (`I18N_LANG=en`), capturas base, emblema vectorial y scripts de automatizacion (`build_visual_v2.jsx`, `mix_audio.py`, `audio_pipeline.py`, `assemble_filmcraft.py`).

## 2. Prompt Maestro Completo (ElevenLabs + Remotion + EffectCraft + FilmCraft + ArtCraft)

```markdown
Vamos a producir el tráiler final oficial para la entrega del hackathon NASA Space Apps Challenge 2026 de nuestro proyecto Margin Zero: Orbital Debt (Team Skaar — Anáhuac Mayab, Mérida, Yucatán, México).

Tienes como referencia estos archivos base y el repositorio completo del juego en /home/alexykk/Game-nasa:
1. Guion oficial bilingüe y tabla de tiempos obligatoria (29.7 s): /home/alexykk/Downloads/MarginZero_Guion_EN_ES.pdf
2. Video borrador previo (29.70 s, 1920x1080 @ 30 fps): /home/alexykk/Downloads/demo video - game.mp4
3. Reglas acústicas de tráiler en /home/alexykk/.claude/skills/real-sound/references/sound-design.md

### Requisitos Visuales, Tipográficos y de Animación Obligatorios

1. Tipografía Oficial de Team Skaar (Pixelta + Exo 2 + Space Mono):
   - Mantén la misma tipografía de Team Skaar y Margin Zero usando la fuente del repositorio /home/alexykk/Game-nasa/assets/fonts/Pixelta.ttf (Pixelta) para Team Skaar, Margin Zero y los encabezados de cada paso (Contract, Build, Launch, Fly, Land, Debrief).
   - Usa /home/alexykk/Game-nasa/assets/fonts/Exo2-Regular.ttf y /home/alexykk/Game-nasa/assets/fonts/Exo2-SemiBold.ttf para subtítulos y descripciones, y /home/alexykk/Game-nasa/assets/fonts/SpaceMono-Regular.ttf para telemetría y numeración (01..06). Prohibido usar JetBrains Mono.

2. Motion Graphics con Remotion + EffectCraft y Motion Blur Real (240 grados Shutter):
   - Crea las capas de motion graphics, HUDs animados, anillos orbitales y transiciones combinando Remotion (remotion y @remotion/motion-blur con <CameraMotionBlur shutterAngle={240} samples={12}> y <Trail>) y EffectCraft (main.motionBlur = true; main.shutterAngle = 240; main.shutterPhase = -120;).
   - Todas las entradas de títulos (Team Skaar, Margin Zero, 01 Contract..06 Debrief), los barridos de cámara (whip-pans / scale slams) y las vibraciones de ignición/reentrada deben tener motion blur direccional activado, mientras que la caja de subtítulos inferiores permanece estática y nítida.

3. Planetas Rotando sobre su Propio Eje y Cambio Dinámico de Fondos de ArtCraft:
   - Usa exclusivamente los fondos y planetas subidos desde ArtCraft/VectorCraft en el repositorio:
     - Vector maestro ArtCraft: /home/alexykk/Game-nasa/docs/art/planetas_fondos.svg (y /home/alexykk/Game-nasa/docs/art/planetas_fondos.vectorcraft), /home/alexykk/Game-nasa/docs/art/logo_orbita.svg, /home/alexykk/Game-nasa/docs/art/cohete_variantes.svg.
     - Fondos espaciales por escena (/home/alexykk/Game-nasa/assets/space/):
       - 0:00–0:03 (Opening): space_bg_deep_void.png + stars_celestial_sheet.png en paralaje.
       - 0:03–0:07.85 (Challenge): transición a space_bg_nebula_teal.png.
       - 0:08.00–0:12.00 (Hero Title Drop): cambio dramático en el golpe de las 0:08.00 a space_bg_nebula_crimson.png.
       - 0:17.00–0:21.00 (04 Fly / Solar Storm): capa reactiva con space_bg_solar_storm.png.
       - 0:25.00–0:29.70 (Closing): combinación de space_bg_deep_void.png + space_bg_nebula_teal.png.
     - Planetas rotando continuamente sobre su propio eje (/home/alexykk/Game-nasa/assets/planets/ + capas extraídas de docs/art/planetas_fondos.svg):
       - En cada escena donde aparecen cuerpos celestes (planet_earth.png en 0:00–0:08, planet_moon.png y planet_mars.png en 0:08–0:12, planet_sun.png en 0:17–0:21, planet_jupiter.png y planet_ganymede.png en 0:25–0:29.7, más asteroid_bennu.png / asteroid_psyche.png), anima la rotación continua del planeta sobre su propio eje (desplazamiento de textura esférica con máscara circular, atmósfera/sombra de terminador fija y rotación axial suave con keyframes de principio a fin de la toma).

### Flujo de Ejecución en 4 Fases (ElevenLabs + Remotion + EffectCraft + FilmCraft)

#### Fase 1: Voz, Música Original (120 BPM) y Efectos de Tráiler con el MCP de ElevenLabs (mcp__elevenlabs__*)
1. Genera los 8 segmentos de voz en inglés exactos del guion /home/alexykk/Downloads/MarginZero_Guion_EN_ES.pdf con voz cinematográfica de tráiler y verifica con ffprobe y ElevenLabs Scribe (speech_to_text) que cada frase conserve el 100% de las palabras dentro de su ventana:
   - vo_01 (0:00.15–0:02.85, máx 2.70 s): "We are Team Skaar, from Mérida, Mexico."
   - vo_02 (0:03.10–0:07.75, máx 4.65 s): "Our challenge: Space Mission Design Game. Students rarely see how a real mission is designed."
   - vo_03 (0:08.12–0:11.80, máx 3.68 s): "So we built Margin Zero: mission design with zero margin for error."
   - vo_04 (0:12.10–0:14.85, máx 2.75 s): "Pick a contract. Build a rocket on a tight budget."
   - vo_05 (0:15.08–0:16.90, máx 1.82 s): "Launch, and fly it yourself."
   - vo_06 (0:17.10–0:20.85, máx 3.75 s): "Space fights back, modeled on NASA and JPL open data."
   - (Ventana 0:21.00–0:23.00: estrictamente (music only), cero voz).
   - vo_07 (0:23.08–0:24.90, máx 1.82 s): "Every flight ends with a debrief of what went wrong."
   - vo_08 (0:25.10–0:29.10, máx 4.00 s): "Training the next generation of mission designers."
2. Genera con ElevenLabs la música original del tráiler a 120 BPM en Re menor y los efectos cinematográficos (sfx_01_riser, sfx_01_drop en 0:08.00 tras silencio pre-drop 7.85–8.00 s, sfx_02_ignition_launch en 0:15.00, sfx_03_solar_warning en 0:17.00 y sfx_04_reentry_climax en 0:21.00–0:23.00).

#### Fase 2: Captura de Clips de Gameplay en Movimiento en Inglés (I18N_LANG=en)
1. Desde una copia aislada de origin/main y perfil aislado de Godot (1920x1080, I18N_LANG=en), graba secuencias a 30 fps de las 6 fases (contract.mp4, build.mp4, launch.mp4 con ignición y robot Orbital Mule Mk-I en cabina, space.mp4, solar.mp4 con evento real de tormenta solar en inglés, entry.mp4, reentry.mp4 en Marte y debrief.mp4 con 75 fotogramas / 2.50 s).

#### Fase 3: Motion Graphics en Remotion y Composición con Motion Blur en EffectCraft (mcp__effectcraft__*)
1. Renderiza en Remotion (1920x1080, 30 fps, con <CameraMotionBlur shutterAngle={240} samples={12}>) y/o en EffectCraft (shutterAngle = 240) las secuencias animadas asegurándote de que:
   - Los planetas de ArtCraft (planet_earth.png, planet_mars.png, planet_moon.png, planet_sun.png, planet_jupiter.png, planet_ganymede.png y capas de docs/art/planetas_fondos.svg) roten sobre su propio eje de forma continua con iluminación y sombra de terminador.
   - El fondo espacial cambie dinámicamente en cada sección (space_bg_deep_void.png -> space_bg_nebula_teal.png -> negro frames 236–239 -> space_bg_nebula_crimson.png en 0:08 -> space_bg_solar_storm.png en 0:17–0:21 -> space_bg_nebula_teal.png en 0:25–0:29.7).
   - Team Skaar, Margin Zero y Contract..Debrief usen Pixelta con entradas animadas con motion blur.
   - La tarjeta inferior izquierda (HOW IT PLAYS + 01..06) y la insignia superior centrada (MODELED ON NASA & JPL OPEN DATA) tengan respaldo oscuro de alto contraste sin tapar información crítica.
2. Renderiza el master visual en 3 segmentos (0–12 s, 12–21 s, 21–29.7 s) y únelos sin pérdida (ffmpeg concat -c copy) en visual_master_v2.mp4 (891 fotogramas, 29.700000 s).

#### Fase 4: Montaje Multipista en FilmCraft (mcp__filmcraft__*) y Verificación Final
1. Importa en FilmCraft visual_master_v2.mp4 (V1), voice_stem.wav (A1), music_stem.wav (A2), sfx_stem.wav (A3) y audio_trailer_master.wav (A4), añade los 18 marcadores de escena/locución y guarda margin_zero_trailer.fcproj.
2. Exporta /home/alexykk/Downloads/MarginZero_Final_SpaceApps2026.mp4 y verifica con ffprobe y ffmpeg loudnorm que cumpla exactamente 1920x1080, 30/1 fps, 891 fotogramas, 29.700000 s, -14.0 LUFS +- 0.5 LU y true peak <= -1.0 dBTP.
```
