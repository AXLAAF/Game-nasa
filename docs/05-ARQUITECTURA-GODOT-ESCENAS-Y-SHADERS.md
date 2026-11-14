# 05. Arquitectura de Escenas en Godot 4.7, Shaders WebGL2 y Guion Pitch (30 s)

**Objeto:** Definir el árbol definitivo de escenas `.tscn`, las interfaces entre la simulación pura (`game/sim/`) y la capa visual (`game/ui/`, `game/phases/`), los 3 shaders obligatorios compatibles con `gl_compatibility` y el guion exacto del video demo $\le 30\text{ s}$ para NASA Space Apps.

## 1. Estructura de Escenas y Nodos en Godot 4.7 (`gl_compatibility`)

```text
game/
├── main.tscn                        # Root StateMachine (cambia entre pantallas sin bloquear arbol)
├── main.gd
├── sim/                             # Capa pura RefCounted ya existente (32/32 tests headless)
│   ├── nasa_data_loader.gd
│   ├── reactor_power.gd
│   ├── room_hazards.gd
│   ├── mission_evaluator.gd
│   ├── station_input.gd
│   ├── orbital_solver.gd            # [Hito 1B] Conicas 2D (AP/PE, vis-viva, delta-v nodos)
│   └── ship_build_state.gd          # [Hito 2] 7 sockets + LVL 1..5 + calculo Delta-V / TWR / Omega
├── actors/                          # Entidades 2.5D de nave y tripulantes
│   ├── modular_ship_25d.tscn        # CanvasGroup (contorno unico) + 7 sockets + ExteriorRoofLayer
│   ├── modular_ship_25d.gd
│   ├── crew_bot.tscn                # Bot/animal con pathfinding simple entre las 6 salas
│   └── hazard_beacon_25d.tscn       # Alerta 5.0 s, particulas de fuego y succion de brecha
├── phases/                          # Las 5 pantallas definidas en DISEÑO-UI-NAVES-25D.md
│   ├── contract_map.tscn            # Pantalla 1: Mapa Astrofisico Rhine Lab (4 contratos)
│   ├── dry_dock.tscn                # Pantalla 2: Dique Seco 2.5D + evolucion LVL 1..5
│   ├── takeoff_sequence.tscn        # Pantalla 4A: Ascenso Max-Q + alerta Jettison 4 s
│   ├── flight_dual_hud.tscn         # Pantalla 3 + 4B: FTL 2.5D + KSP 2.5D + Radar 3D + NavBall
│   └── debrief_report.tscn          # Pantalla 5: Expediente Causal + citas NASA
├── ui/
│   ├── orbital_map_25d.gd           # Dibujo de planeta Bayer, conica crema, AP/PE y nodos Delta-V
│   ├── navball_25d.gd               # Esfera rotatoria con pipas Prograde/Retrograde/Node
│   ├── radar_wireframe_3d.gd        # Proyeccion 3D wireframe isométrica (pin_26) de detritos/CME
│   ├── reactor_bar_dock.gd          # Barras clicables FTL para los 6 sistemas
│   └── space_theme.tres             # Tema UI NASAPunk + Rhine Lab (sans >= 12px, tabular mono >= 11px)
├── audio/
│   └── synth_sfx_bus.gd             # Sintesis procedural con AudioStreamGenerator (alarmas, thruster, DSN)
└── shaders/
    ├── ship_outline_canvasgroup.gdshader
    ├── planet_bayer_terminator.gdshader
    └── wireframe_scanline.gdshader
```

## 2. Contrato de Datos entre Simulación Pura (`game/sim/`) y Escenas (`game/`)

Regla de arquitectura: **ningún script en `game/sim/` referencia `Node`, `SceneTree` o rutas visuales**; las escenas leen diccionarios de estado en `_process(delta)` o vía callbacks explícitos:

| Emisor en `game/sim/` | Método invocado por `flight_dual_hud.gd` | Receptor visual en pantalla |
| :--- | :--- | :--- |
| `StationInput` | `build_station_intents(raw_inputs, auto_steer)` | Movimiento de timón, consola activa por jugador y opacidad de piloto automático (`45%`) |
| `ReactorPower` | `allocate(sys_id, +/-1)` + `efficiency(sys_id)` | Relleno de barras ámbar (`#f09c14`) en `reactor_bar_dock.gd` y velocidad de empuje / O2 / radar |
| `RoomHazards` | `step(dt, life_eff, crew_map)` + `set_airlock()` | Color de pisos en las 6 salas, llama animada, trama roja de sala venteada y temporizador `5.0 s` |
| `OrbitalSolver` | `propagate(dt, thrust_vec, throttle)` | Curva cónica crema (`#f4ebd9`), posición de `AP`/`PE`, arco previsto del nodo y actitud NavBall |
| `NasaDataLoader` | `get_body()`, `get_solar_events()`, `get_debris_regimes()` | Etiquetas reales en HUD (latencia `RTLT`, flujo solar `%`, clase de fulguración) y spawn de peligros |
| `MissionEvaluator` | `audit_preflight()` + `record_*()` + `build_report()` | Columnas verde/terracota en `debrief_report.tscn` y ficha oficial *NASA & Partner Data* |

## 3. Especificación de los 3 Shaders WebGL2 (`gl_compatibility`)

Todos deben compilar bajo `shader_type canvas_item;` evitando aritmética compleja de texturas 3D o cómputo no soportado en WebGL2 Single-Threaded:

1. **`ship_outline_canvasgroup.gdshader` (en nodo `CanvasGroup` del casco exterior):**
   - Muestra `texture(screen_texture, SCREEN_UV)` donde `CanvasGroup` ya compuso `Z=-1` a `Z=3`.
   - Para cada fragmento con `a <= 0.01`, muestrea los 4 vecinos ortogonales a distancia `TEXTURE_PIXEL_SIZE * outline_px` (`outline_px = 1.5`). Si cualquier vecino tiene `a > 0.5`, pinta `#0b0e17` (`alpha = 1.0`).
   - Resultado garantizado: **contorno exterior único continuo** alrededor de chasis + góndolas + alas + toberas sin costuras internas entre piezas.
2. **`planet_bayer_terminator.gdshader` (en esfera planetaria `OrbitalMap25D`):**
   - Calcula producto punto normalizado entre vector normal esférico 2D y dirección solar `vec2 light_dir`.
   - Cuantiza la transición día/noche contra una **matriz ordenada de Bayer 4x4** en coordenadas enteras de texel (`mod(floor(FRAGCOORD.xy / pixel_scale), 4.0)`), produciendo bandas pixel-art limpias entre atmósfera iluminada y sombra nocturna (`#080c16`).
3. **`wireframe_scanline.gdshader` (sutil sobre Radar 3D y CRT de Sensores):**
   - Aplica atenuación horizontal ligera (`6%` de modulación cada `2 px`) en `#38bdf8` únicamente dentro del visor del radar derecho para reforzar legibilidad instrumental sin degradar texto.

## 4. Reglas de Exportación WebGL2 y Tipografía Obligatoria

- **Perfil de exportación (`export_presets.cfg`):** Web (`HTML5`), variante **Single-Threaded** (sin `Threads` / `SharedArrayBuffer`) para alojarse directamente en GitHub Pages o itch.io sin errores de cabeceras `COOP/COEP`.
- **Resolución y pixel art:** Viewport `1280 x 720`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, `default_texture_filter=0` (`NEAREST`).
- **Tipografía del tema `space_theme.tres`:** Empaquetar dos fuentes TTF ligeras en `res://assets/fonts/`: una sans-serif limpia (`Noto Sans` / `Inter`, mínimo `12 px`) para rótulos, botones y narrativa, y una monospace tabular (`IBM Plex Mono` / `Liberation Mono`, mínimo `11 px`) exclusivamente para telemetría numérica (`m/s`, `AP/PE`, `RTLT`, `P_exp`). Validado por `tests/test_runner.gd`.

## 5. Guion del Video Demo de <= 30 Segundos (Elegibilidad NASA Space Apps)

Duración objetivo: **28 segundos** exactos, relación `16:9` (`1280x720`), subtítulos en inglés integrados:

| Ventana | Escena en pantalla | Voz / Subtítulo en inglés (breve y verificable) | Evidencia NASA visible en UI |
| :---: | :--- | :--- | :--- |
| **`00 – 05 s`** | Pantalla 1 (`ContractMap`) -> clic en **Júpiter / Europa (`LIBERTY-4`, `5.2 AU`)** -> Dique Seco rechaza paneles solares (`3.7%` flujo) e instala **MMRTG** sobre `MZ-1 LIBERTY` (`Orbital Mule Mk-I`, `LVL 1 -> LVL 4`). | *"Bankrupt agency, real NASA physics: solar drops to 3.7% at Jupiter — swap to RTG or fail."* | `NASA NSSDCA: 5.20 AU | Solar 3.7%` |
| **`05 – 12 s`** | Pantalla 3 (`FlightDualHUD`): 2 jugadores en vivo — Radar canta detritos en el **Wireframe 3D**; Piloto gira con **NavBall 2.5D** y ejecuta quema **$\Delta v$** en órbita **KSP**. | *"Radar gets 14s CelesTrak debris warning while Pilot burns the delta-V node in real time."* | `CelesTrak / ODPO: 790 km 11.7 km/s` |
| **`12 – 21 s`** | Impacta tormenta/escombro -> techo translúcido **FTL** muestra incendio en `engines` (`5.0 s` crisis) -> Ingeniero corre, cierra puerta y abre **airlock al vacío** salvando el motor justo a tiempo. | *"No pause button! Vent the engine room to vacuum in 5 seconds before propellant leaks out."* | `NASA DONKI SEP / FTL Crisis 5.0s` |
| **`21 – 28 s`** | Pantalla 5 (`DebriefReport`): columnas **"What went right / wrong"** con calificación **S**, más mosaico rápido de enlaces de datasets NASA/JPL y URL jugable WebGL2. | *"Every mistake traced to real NASA, JPL & DONKI data. Play Margin Zero: Orbital Debt in browser."* | Tabla de 5 fuentes oficiales NASA/JPL |
