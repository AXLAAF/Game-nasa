# 00. Índice Maestro y Plan Operativo del Hackathon

**Proyecto:** `Space: Deuda Orbital`  
**Motor:** Godot 4.7.2 (`gl_compatibility`, exportación WebGL2 Single-Threaded)  
**Reto Objetivo:** NASA International Space Apps Challenge — *Space Mission Design Game*

## 1. Índice Maestro de Documentación

| Doc | Archivo | Alcance y Contenido | Estado |
| :--- | :--- | :--- | :--- |
| `00` | [00-INDICE-Y-PLAN-MAESTRO-HACKATHON.md](00-INDICE-Y-PLAN-MAESTRO-HACKATHON.md) | Índice maestro, cronograma por bloques horarios, roles, puertas Go/No-Go y matriz de riesgos | Activo |
| `01` | [01-CATALOGO-MODULOS-Y-EVOLUCION-NAVE.md](01-CATALOGO-MODULOS-Y-EVOLUCION-NAVE.md) | Chasis `Orbital Mule Mk-I`, 7 hardpoints tipados, tablas numéricas `LVL 1..5`, calidades y reglas 2.5D | Activo |
| `02` | [02-SISTEMA-ORBITAL-KSP-25D-Y-FISICA.md](02-SISTEMA-ORBITAL-KSP-25D-Y-FISICA.md) | Mecánica orbital KSP 2.5D (*Rhine Lab*), elipses `AP/PE`, nodos $\Delta v$, NavBall 2.5D, corredor atmosférico y Radar 3D | Activo |
| `03` | [03-INTERIOR-FTL-TRIPULACION-Y-CRISIS.md](03-INTERIOR-FTL-TRIPULACION-Y-CRISIS.md) | 6 salas FTL, grafo de compuertas y esclusas, *Manning Bonus*, modo 1P vs 2–4P y 10 tarjetas de crisis de 5 s | Activo |
| `04` | [04-GUION-MISIONES-Y-CONTRATOS-NASA.md](04-GUION-MISIONES-Y-CONTRATOS-NASA.md) | Guion tramo por tramo de los 4 contratos NASA, eventos DONKI/CelesTrak, economía de deuda y *Debrief Causal* | Activo |
| `05` | [05-ARQUITECTURA-GODOT-ESCENAS-Y-SHADERS.md](05-ARQUITECTURA-GODOT-ESCENAS-Y-SHADERS.md) | Árbol de escenas `.tscn`, contratos de señales con `game/sim/`, 3 shaders WebGL2 y guion pitch de 30 s | Activo |
| `GDD` | [GDD-REMAKE-MASTER.md](GDD-REMAKE-MASTER.md) | Visión maestra consolidada, pilares *FTL + KSP 2.5D + Overcooked* y arquitectura base | Referencia |
| `UI` | [DISEÑO-UI-NAVES-25D.md](DISEÑO-UI-NAVES-25D.md) | Sistema visual 2.5D, tokens cromáticos NASAPunk + *Rhine Lab*, tipografía y mockups 1280x720 | Referencia |
| `SIM` | [MECANICAS-REFERENCIA.md](MECANICAS-REFERENCIA.md) | Ecuaciones matemáticas de propulsión, balance térmico, `TakeoffRisk`, `DamageMatrix` y 12 Perks NASA | Referencia |
| `NASA` | [INVESTIGACION-NAVES-INCIDENTES-NASA.md](INVESTIGACION-NAVES-INCIDENTES-NASA.md) | Respaldo institucional NASA/NOAA/ODPO/JPL sobre los 7 subsistemas, 10 incidentes históricos y física real | Referencia |

## 2. Cronograma Operativo del Hackathon y Puertas de Salida (Go/No-Go)

Formato de ejecución por bloque: **Se hará esto -> para esto -> en esto -> con esto**.

| Horario / Bloque | Hito | Acción concreta | Rol despersonalizado | Puerta de salida (Go/No-Go) |
| :--- | :--- | :--- | :--- | :--- |
| **Bloque 0 (09:00 – 09:45)** | **Cimiento Limpio y Planificación** | **Se inicializó** el repositorio limpio `/home/axelmc/Documentos/Proyectos_JunDic/Space/` en Godot 4.7 y **se documentaron** ecuaciones, UI 2.5D, respaldo NASA y la serie `docs/00..05` **para garantizar** trazabilidad completa antes de codificar vistas **en** `docs/` y `game/sim/` **con** GDScript puro `RefCounted` y datasets `data/nasa/*.json`. | Arquitectura + Documentación | `test_runner.gd` pasa `32 passed, 0 failed`; commit limpio en rama `axel`. |
| **Bloque 1 (09:45 – 12:30)** | **Hito 1A: Interior FTL 2.5D y Control 1P/2P** | **Se implementará** la escena del casco `Orbital Mule Mk-I` con las 6 salas caminables, barras de `ReactorPower`, eventos de `RoomHazards` (5 s) y esclusas **para validar** el ciclo caótico de reparación sin pausa global **en** `game/phases/flight_view.tscn` y `game/actors/` **con** `TileMapLayer`/polígonos `32x32 px` y `StationInput`. | Gameplay Core | Un jugador (alternando `1-4`) o dos en teclado apagan incendio abriendo esclusa y reasignan barras en vivo sin crasheos. |
| **Bloque 2 (12:30 – 15:00)** | **Hito 1B: Vista Orbital KSP 2.5D + NavBall + Despegue** | **Se construirá** el lienzo orbital 2.5D (*Rhine Lab*), nodo de maniobra $\Delta v$, NavBall 2.5D, corredor atmosférico y secuencia de despegue `TakeoffRisk` con botón `Jettison` **para acoplar** el vuelo interior FTL con navegación espacial legible **en** `game/ui/orbital_map_25d.gd` y `navball_25d.gd` **con** `CanvasItem._draw()`, shader Bayer 4x4 y cónicas keplerianas. | Gráficos + Física Orbital | Maniobra *Prograde/Retrograde* modifica `AP/PE` en tiempo real y el botón `Jettison` reduce sobrecarga $\Omega$ en despegue. |
| **Bloque 3 (15:00 – 17:30)** | **Hito 2: Dique Seco `LVL 1..5` + 4 Contratos NASA** | **Se construirá** el Mapa Astrofísico de Contratos y el Dique Seco Modular con los 7 hardpoints, evolución `LVL 1..5`, los 12 Perks NASA y lectura de los 4 JSON **para forzar** decisiones de ingeniería previas al vuelo **en** `game/phases/dry_dock.tscn` y `contract_map.tscn` **con** `CanvasGroup` silhouette shader y `NasaDataLoader` + `MissionEvaluator`. | Sistemas + Contenido NASA | Ir a Júpiter solo con solares falla auditoría de energía ($3.7\%$); cambiar góndolas/alas transforma el sprite coherente bajo contorno único. |
| **Bloque 4 (17:30 – 19:30)** | **Hito 3: Radar 3D Wireframe, Audio y *Debrief Causal*** | **Se integrará** el Radar 3D Wireframe (`pin_26`), eventos DONKI/CelesTrak/NEO, pantalla final causal ("qué hiciste bien/mal") y síntesis procedural de alarmas **para completar** el bucle de 4–6 minutos sin depender de texto largo **en** `game/ui/radar_wireframe.gd`, `debrief_view.tscn` y `game/audio/` **con** `AudioStreamGenerator` y `MissionEvaluator.build_report()`. | Audio + UX + Pulido | Partida completa Luna o Marte de principio a fin con informe causal exacto y citas NASA visibles. |
| **Bloque 5 (19:30 – 21:00)** | **Hito 4: Export WebGL2 + Video <= 30 s** | **Se instalarán** templates Web de Godot 4.7.2, **se compilará** export HTML5 Single-Threaded (`gl_compatibility`) y **se grabará** demo $\le 30\text{ s}$ subtitulado en inglés **para asegurar** entrega pública y elegibilidad en NASA Space Apps **en** GitHub Pages / `build/web/` **con** Godot Export, FFmpeg/OBS y tabla de fuentes oficiales. | Integración + Entrega | URL pública ejecuta el juego en navegador limpio + video $\le 30\text{ s}$ verifica *gameplay* real en segundos 6–18. |

## 3. Verificación de Premisas, Falsos Positivos, Líneas Rojas y Trampas

| Categoría | Elemento verificado | Decisión obligatoria |
| :--- | :--- | :--- |
| **Premisa verificada (Engine)** | Godot 4.7.2 está instalado y ejecuta `gl_compatibility` headless con `32/32` tests pasando (`test_runner.gd`). | Mantener cero dependencias de `Forward Plus` o `Jolt Physics` para no romper exportación WebGL2 sin cabeceras `COOP/COEP`. |
| **Premisa verificada (Datos NASA)** | Los 4 JSON en `res://data/nasa/` (`planetary_catalog`, `neo_curated_missions`, `solar_events_scenarios`, `debris_leo_catalog`) están validados en disco. | El modo por defecto lee siempre archivos locales; cualquier consulta en vivo (*Live NASA*) debe ser opcional y no bloqueante. |
| **Falso positivo descartado** | Creer que las APIs públicas NASA (`api.nasa.gov`, `dsn.xml`) siempre responden desde WebGL2 con CORS habilitado. | Trampa de evaluación: CORS o límites de cuota bloquean peticiones en navegador. Usar snapshots embebidos como fuente primaria garantiza 100% de disponibilidad ante el jurado. |
| **Falso positivo descartado** | Creer que en microgravedad el espacio congela al instante o cualquier pinchazo despresuriza en 1 segundo. | Corregido en `INVESTIGACION-NAVES-INCIDENTES-NASA.md`: sin radiadores la nave sobrecalienta; la ventana de 5 s representa escalado táctico de crisis estructural. |
| **Línea roja de alcance** | Prohibido implementar multijugador en red (`ENetMultiplayerPeer` / WebRTC) o editor libre tipo *Lego* sin sockets durante el hackathon. | `StationInput` ya aísla intenciones de 1P y 2–4P locales; las piezas solo acoplan en los 7 hardpoints tipados de `Orbital Mule Mk-I`. |
| **Línea roja de UI y código** | Cero `get_tree().paused = true` en vuelo; cero tipografías no autorizadas (`AGENTS.md`); cero emojis; todo `game/sim/` en `RefCounted` puro. | Auditable de forma automática mediante `tests/test_runner.gd` antes de cada hito y antes del export final. |
| **Trampa de entrega Space Apps** | Video demo superior a `30 segundos` o sin evidencia visible del dataset NASA que controla la partida. | El guion en [05-ARQUITECTURA-GODOT-ESCENAS-Y-SHADERS.md](05-ARQUITECTURA-GODOT-ESCENAS-Y-SHADERS.md) fija duración exacta de `28 s` con rótulo en pantalla. |
