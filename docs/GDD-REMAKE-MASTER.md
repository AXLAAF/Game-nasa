# Documento Maestro de Diseño y Arquitectura (GDD): Space (Deuda Orbital)

**Proyecto:** Simulador Cooperativo de Misiones Espaciales (Agencia en Quiebra)  
**Reto Objetivo:** NASA International Space Apps Challenge — *Space Mission Design Game*  
**Referencias Centrales:** *FTL: Faster Than Light* (interior 2.5D) + *Kerbal Space Program* (vista orbital 2.5D) + *Overcooked* (cooperativo sin pausa) + *Rhine Lab / Lone Trail*  
**Público Objetivo:** Adolescentes (+12 años) y adultos  
**Estado:** Planificación maestra desde cero basada en tablero Pinterest (`AXL_MC/game`) y requisitos oficiales de la NASA

---

## 1. Principios de Arquitectura Limpia

El proyecto nace con arquitectura modular pura en Godot 4.7 (`gl_compatibility`) enfocada en exportacion Web directa, datos NASA/JPL embebidos y cero bloqueo por pausa global.

| Pilar Técnico | Decisión | Justificación |
| :--- | :--- | :--- |
| Simulación matemática (`MECANICAS-REFERENCIA.md`) | **INTEGRADA POR DISEÑO** | Tsiolkovsky, flujo solar $1/r^2$, $P_{explosion}$, matriz de daño por 4 cuadrantes y 12 perks NASA integrados directamente en las salas FTL y la órbita KSP. |
| Arte 2.5D unificado (`DISEÑO-UI-NAVES-25D.md`) | **PRODUCCIÓN PROPIA** | Rejilla cenital `32x32 px`, luz fija a 315°, abrazaderas en góndolas y contorno único `CanvasGroup`. |
| Tipografía y paleta NASAPunk + *Rhine Lab* | **ESTÁNDAR ACTIVO** | Contraste alto, diegesis instrumental y prohibición total de `JetBrains Mono`. |
| Ritmo cooperativo en tiempo real | **SIN PAUSA GLOBAL** | Comunicación por voz y alertas de 5 s sin `get_tree().paused = true`. |
| Datos abiertos NASA/JPL embebidos | **OBLIGATORIO** | Destinos, asteroides NEO, tormentas DONKI, DSN y basura LEO reales en `data/nasa/*.json`. |
---

## 2. Pilares de Diseño: Fusión FTL + KSP 2.5D + Overcooked + NASA

El juego equilibra precisión y velocidad: ofrece una **Vista Orbital 2.5D inspirada en *Kerbal Space Program* (con estética *Rhine Lab*)** simplificada para ser legible en 3 minutos (órbitas AP/PE, nodos de maniobra $\Delta v$ y corredor de reentrada), combinada con la gestión caótica de salas interiores de *FTL* y física real NASA/JPL.

### 2.1 Qué rescatamos exactamente de *FTL: Faster Than Light*

1. **Nave en corte cenital dividida en Salas Funcionales:** El jugador ve el interior de la nave desde arriba organizado en salas conectadas por compuertas: **Puente (Timón)**, **Reactor / Energía**, **Motores (Popa)**, **Sensores y Antena (Proa)**, **Soporte Vital (O2 / Térmico)** y **Bahía Científica**. Los tripulantes caminan físicamente de una sala a otra para operar consolas o contener emergencias.
2. **Asignación dinámica de Energía del Reactor (Barras de Poder):** Como el reactor de una agencia en quiebra tiene capacidad limitada (ej. 6 a 8 barras totales cuando las salas piden 12), el equipo no puede tener todo al 100%. Deben **reasignar barras en vivo**: apagar temporalmente la Antena o reducir Soporte Vital para dar potencia extra a Motores o Escudo Deflector durante una tormenta solar o cruce de escombros. Esto convierte el presupuesto energético en una decisión táctica palpable cada 10 segundos.
3. **Bono de Estación (Manning Bonus):** Parar a un tripulante frente a una consola mejora el sistema (Timón da +estabilidad/evasión, Sensores desbloquea el radar lejano y tiempos de impacto, Motores acelera la recarga de encendido). Cuando estalla una crisis en Popa, quien abandona su consola para ir a reparar sacrifica ese bono hasta regresar a su puesto.
4. **Peligros internos por sala (Fuego, Brecha al Vacío y Nivel de Salud 3 colores):** Cada sala muestra su integridad en verde (operativa), ámbar (degradada) o rojo (fuera de línea). Un impacto genera:
   - **Incendio:** Se propaga, daña la sala y consume oxígeno local.
   - **Brecha de casco:** Drena el oxígeno de la sala y ralentiza reparaciones.
   - **Ventilación táctica de compuertas (Airlock Venting):** Mecánica icónica de FTL: abrir las escotillas exteriores de una sala vacía al espacio **apaga incendios al instante** al eliminar el oxígeno, pero asfixia o eyecta a cualquier tripulante que siga adentro si no cierran la compuerta a tiempo.
5. **Mapa de Ruta por Nodos / Saltos de Sector:** Entre tramos de vuelo de 45–60 s, la nave alcanza un nodo de salto donde el equipo elige en 10–15 s el siguiente tramo: ruta directa a través de basura espacial Kessler (alto riesgo, ahorra combustible) vs desvío por asteroide NEO (consume más $\Delta v$, permite extraer Ciencia extra).

### 2.2 Qué rescatamos de *Overcooked* y del Audio de Diseño

1. **Cero pausa táctica en vuelo:** A diferencia de FTL, aquí **no existe barra espaciadora para pausar**. La presión nace de la comunicación verbal en vivo ("¡Basura por estribor en 4 segundos!", "¡Fuego en motores, corta oxígeno!", "¡Transmite datos antes de perder línea de vista!").
2. **Premisa cómica de "Agencia Privada en Quiebra":** Todo es de segunda mano. Las piezas compradas como *Chatarra* explican de forma coherente y graciosa por qué la nave echa chispas y exige reparaciones constantes con cinta Kapton y llaves inglesas.
3. **Tripulación de Robots Desechables o Animales Antropomórficos:** Evita la crudeza de mostrar muertes humanas en pantalla; cuando la nave colapsa o alguien sale eyectado por una compuerta, el resultado es humor físico (muñecos/bots saliendo volando con alertas de "Pérdida contable menor").
4. **Temporizadores de crisis cortos (5 segundos):** Las averías críticas dan avisos urgentes y breves antes de escalar a fallo en cadena (ej. fuga en tanque que explota si no se sella en 5 s antes de encender el motor).

---

## 3. Loop Completo de Partida (4 a 6 minutos)

### Fase 1: Briefing y Hangar en Quiebra (60–90 s)
1. **Selección de Contrato NASA:** Se muestran 4 misiones reales con su presupuesto inicial, pago por Ciencia y advertencias físicas reales:
   - **Misión 1 — Órbita Lunar (Artemis Relay):** Baja dificultad, $\Delta v$ moderado, latencia 1.3 s, radiación solar media. Ideal para aprender los puestos.
   - **Misión 2 — Muestras en Marte (Mars Sample Return):** Dificultad media, irradiancia solar ~43% (paneles rinden menos), atmósfera tenue ($0.006\text{ bar}$) que exige escudo ablativo PICA + paracaídas, latencia de antena (3–22 min simulada como *buffer* de comandos).
   - **Misión 3 — Sonda a Júpiter / Europa (Clipper):** Dificultad alta, irradiancia solar ~3.7% (paneles solares prácticamente inútiles; obliga a equipar **RTG**), radiación joviana extrema en cinturones.
   - **Misión 4 — Mantenimiento de Telescopio / Desvío NEO (JWST / DART):** Enfoque en evasión de detritos orbitales LEO (CelesTrak) y tormentas solares DONKI.
2. **Dique Seco y Nave Base Evolucionable (`Orbital Mule Mk-I` -> `LVL 1..5`):**
   - En lugar de armar cohetes sueltos desde cero, toda campaña conserva un **Chasis Maestro predeterminado (`160x224 px`, 6 salas FTL)** con **7 Hardpoints tipados** (`SOCKET_BOW`, góndolas babor/estribor con **abrazaderas automáticas**, alas laterales, torreta dorsal y popa remetida).
   - Los módulos acoplados se ven como una sola nave coherente mediante iluminación fija a 315 grados, oclusión de contacto de 2 px y contorno exterior único en `CanvasGroup`, y evolucionan visualmente de **`LVL 1` (Chatarra)** a **`LVL 5 MAX` (Experimental)** conforme avanza la partida.
   - El tablero muestra en vivo tres barras claras (sin exceso de números): **Alcance $\Delta v$ vs Requerido**, **Balance Energético en Destino** y **Riesgo de Despegue ($P_{explosion}$)**.

### Fase 2: Despegue de Tensión (15 s)
- Usa el modelo de `TakeoffRisk` (`calculate_p_explosion` en `[0.005, 0.95]`): combina sobrecarga de masa $\Omega$, presión dinámica *max-Q* y condición estructural.
- Si el equipo sobrecargó la nave por avaricia de presupuesto, durante el ascenso aparece una alerta roja de **4 segundos** para activar el **descarte de carga auxiliar (`jettison_cargo`)** o jalar la **Torre de Escape** y salvar la mitad de los créditos.

### Fase 3: Vuelo Dual (Interior FTL 2.5D + Órbita KSP 2.5D) en Tiempo Real (2.5–3.5 min)
La pantalla principal integra dos vistas sincronizadas en tiempo real (ver [DISEÑO-UI-NAVES-25D.md](DISEÑO-UI-NAVES-25D.md) y [mockup_2_hud_ftl_ksp_orbital.png](mockups/mockup_2_hud_ftl_ksp_orbital.png)):
- **Vista Táctica Interior (FTL 2.5D):** El techo del casco se vuelve translúcido revelando las 6 salas, barras del reactor, incendios, brechas y tripulantes moviéndose por compuertas y esclusas.
- **Vista Orbital (KSP 2.5D + estilo *Rhine Lab*):** Muestra el planeta en 2.5D con terminador Bayer 4x4, la órbita elíptica actual con marcadores **`AP` / `PE`**, **Nodos de Maniobra ($\Delta v$)** con arco previsto, **NavBall 2.5D** y **Radar Topográfico 3D Wireframe** en el panel derecho.

#### Los 4 Puestos Operativos (1 a 4 jugadores)

| Puesto | Sala principal | Qué controla y qué información ve |
| :--- | :--- | :--- |
| **1. Piloto (Timonel)** | Puente (Proa-Centro) | Conduce la nave (`WASD` / stick) para esquivar asteroides y basura espacial en el carril de vuelo, mantiene la nave dentro del **Corredor de Reentrada** y regula el empuje. **Ceguera táctica:** solo ve peligros muy cercanos; depende de los gritos del Radar. |
| **2. Oficial de Radar y Datos** | Sensores y Comms (Proa) | **Único con visibilidad del radar de largo alcance** (aviso de 10–14 s en basura espacial Kessler y fulguraciones DONKI), canta izquierda/derecha al Piloto, orienta la antena parabólica hacia la Tierra para transmitir paquetes de Ciencia (`dataRate` DSN) y escanea anomalías. |
| **3. Ingeniero de A Bordo** | Reactor y Motores (Centro-Popa) | Redistribuye las **barras de energía del reactor** (estilo FTL), corre entre salas para apagar incendios, sellar brechas de casco, abrir/cerrar escotillas de venteo al vacío y resolver micro-reparaciones de 2–4 s antes de que expire la cuenta regresiva de 5 s. |
| **4. Operador de Carga y Térmico** | Bahía Científica y Soporte Vital | Activa el brazo robótico/cámara al pasar sobre objetivos científicos, regula radiadores/calor en *Storm Safe Mode* durante CMEs solares y opera el O2 de emergencia. *(En 2 jugadores, el Piloto asume Carga/Térmico o el Radar asume Sensores+Carga).* |

**Soporte para 1 Jugador (Solo Mode):**
- El jugador controla directamente al tripulante activo y cambia entre puestos con `1-4` o `Tab` (o click en la sala, igual que en FTL).
- Los puestos sin jugador humano activan un **piloto automático barato de agencia en quiebra** (esquiva tarde, repara al 40% de velocidad, no optimiza energía), incentivando saltar de sala en sala para corregir errores.

### Fase 4: Descenso / Extracción y Reporte Causal de Misión (45 s)
Al llegar al destino, ejecutan la maniobra final (descenso por corredor con escudo + paracaídas en Marte, inserción orbital en Júpiter o acoplamiento en Telescopio) y entran a **Liquidación y Reporte Científico**:

1. **Bloque "Qué hiciste bien vs Qué hiciste mal" (Auditoría física):**
   - *"BIEN: Equipaste RTG rumbo a Júpiter (5.2 AU), manteniendo 100% de energía donde los paneles solares caen al 3.7%."*
   - *"BIEN: El Radar detectó la conjunción de detritos LEO con 12 s de margen evitando impacto en Popa."*
   - *"MAL: Sobrecargaste la masa en rampa (+24% sobre $M_{rated}$), elevando $P_{explosion}$ al 38%."*
   - *"MAL: Dejaste sin reparar 6 s la fuga en el cuadrante Popa (`bottom`), perdiendo 42% del empuje y 180 kg de propelente."*
2. **Retorno Científico y Estado de la Quiebra:** Ciencia capturada vs transmitida por DSN, costo de reparaciones, penalización/bono por tiempo y calificación (**S / A / B / C**).
3. **Ficha de Transparencia NASA:** Lista los datasets reales que gobernaron esa partida.

---

## 4. Integración Obligatoria de Datos Reales NASA/JPL

Para cumplir el mandato *NASA & Partner Data* sin sufrir bloqueos por límites de peticiones ni caídas de internet durante la evaluación del jurado, el juego opera con **snapshots JSON oficiales embebidos en `public/data/`** y un **botón opcional "Modo Live NASA"** para descargar el estado espacial real del día.

### Mapeo Dataset Oficial -> Ecuación -> Impacto en Gameplay

| Dataset / API Oficial | Variables extraídas | Archivo local / Endpoint | Regla exacta en el juego |
| :--- | :--- | :--- | :--- |
| **[NASA Planetary Fact Sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/)** | Gravedad ($g$), distancia solar ($r$ AU), presión superficial ($P$), altura de escala ($H$), $v_{esc}$ | `public/data/planetary_catalog.json` | Define el $\Delta v$ mínimo del contrato, la densidad atmosférica $\rho_0 e^{-h/H}$ en reentrada y la caída de irradiancia solar $S(r) = 1361 / r^2$ (obliga a cambiar paneles por RTG en Júpiter). |
| **[JPL SBDB / CAD](https://ssd-api.jpl.nasa.gov/doc/sbdb.html)** | Diámetro, masa, albedo, velocidad relativa de asteroides reales (Bennu, Didymos, Eros, Psyche) | `public/data/neo_curated_missions.json` | Alimenta los nodos de muestreo/desvío de asteroides y calcula la energía de impacto en `DamageMatrix` ($\frac{1}{2} m v_{rel}^2$). |
| **[NASA DONKI](https://api.nasa.gov/)** | Fulguraciones (`classType` M/X), velocidad de CME (`speed` km/s), eventos `SEP` y `kpIndex` | `public/data/solar_events_scenarios.json` | Dispara eventos reales (ej. Tormenta de Halloween 2003 o Mayo 2024): sin modo *Storm Safe* o perk `telemetry_strain`, provoca reinicios en la sala de Computadora/Sensores y degrada paneles. |
| **[NASA DSN Now](https://eyes.nasa.gov/dsn/data/dsn.xml)** | `rtlt` (Round-Trip Light Time), `downlegRange`, `dataRate` (bps) | `dsn.xml` (con fallback estático) | Define el ancho de banda al transmitir Ciencia desde la sala de Comms y el retardo real de señal (1.3 s Luna, 3–22 min Marte, 33–53 min Júpiter). |
| **[CelesTrak GP](https://celestrak.org/NORAD/elements/gp.php) / [NASA ODPO](https://orbitaldebris.jsc.nasa.gov/)** | Elementos orbitales TLE de fragmentos de basura espacial e inclinación | `public/data/debris_leo_catalog.json` | Genera enjambres reales de detritos hiperveloces en órbita terrestre baja que exigen lectura temprana del Radar y maniobra evasiva del Piloto. |

---

## 5. Integración de `DamageMatrix`, `TakeoffRisk` y `NasaPerks` en el Nuevo Juego

Las tres piezas matemáticas ya validadas en el repo anterior pasan a ser el corazón de la lógica de salas:

1. **`TakeoffRisk` -> Fase 2 (Despegue):**
   - `calculate_overload(total_mass, m_rated)` determina el riesgo en tiempo real mientras arman la nave en Hangar.
   - Si estalla una alerta en el segundo 6 del ascenso, `jettison_cargo` libera masa para bajar $P_{explosion}$ al instante a costa de perder parte de la recompensa opcional.
2. **`DamageMatrix` -> Salas y Canales en Fase 3:**
   - Todo impacto exterior golpea un cuadrante (`top`, `middle`, `bottom`, `radial`) según el ángulo de colisión.
   - `top` (Proa) degrada `vision` y `map` (apaga el cono del Radar y mancha el visor).
   - `middle` (Centro) degrada `light` y `mobility` (apaga luces de cabina, activa baliza ámbar de emergencia y frena al tripulante).
   - `bottom` (Popa) degrada `thrust` y dispara `leak` (fuga de combustible por segundo hasta que el Ingeniero selle la sala).
   - `radial` (Flancos) degrada `comms` y `audio` (corta la descarga científica DSN y mete estática en las alertas).
3. **`NasaPerks` -> Tienda de Tecnologías Reales en Hangar:**
   - Los 12 perks reales (Losetas `shield_hrsi`, Escudo `shield_pica`, Tobera `nozzle_niobium`, Turbobomba `staged_preburner`, Telemetría analógica `telemetry_strain`, Amortiguador `damper_cryo_he`, Manta `insulation_mli`, Cabrestante `winch_uhmwpe`, Red `net_supercond`, Radar Doppler `radar_doppler`, Giroscopio `cmg_stabilizer`, Radiador `radiator_ammonia`) y los 4 mutadores anómalos se compran en el Hangar. Cada uno tiene una ventaja clara y una contrapartida física real visible en el *Debrief*.

---

## 6. Dirección Visual, UI Diegética y Referencias Visuales

### 6.1 Estética: *FTL Cutaway* + *Worn Aerospace*
- **Capa exterior (Casco) — Referencias visuales en `assets/ships/ (en producción)` (no copiadas):**
  - Proa (`top`): cabinas 32x32, escudos curvos 32x16, torres de escape 16x32, antenas parabólicas 32x32.
  - Centro (`middle`): fuselajes pesados 48x48, bahías de carga 32x48, consolas CRT 32x32.
  - Popa (`bottom`): monturas traseras 32x32, toberas principales 32x32, plumas de escape 32x48.
  - Flancos (`radial`): alas solares desplegadas 48x24, generadores RTG 16x16, radiadores 48x16, brazos robóticos 32x48.
- **Capa interior (Salas FTL):** Al hacer zoom táctico durante el vuelo, la cubierta superior del casco se vuelve translúcida para mostrar las 6 salas, el nivel de oxígeno por color de piso, iconos de incendio/brecha y a los tripulantes robots/animales corriendo entre compuertas.
- **Entorno espacial — Referencias visuales en `assets/space/ (en producción)` (no copiadas):** Siluetas y paletas de cuerpos planetarios (Luna, Marte, Júpiter), asteroides metálicos/helados y fondos sin costuras 256x256 para producir el arte propio de `Space/assets/`.

### 6.2 Reglas de Interfaz (UI) y Documentación Visual
- **Especificación completa e imágenes de interfaz:** Todo el sistema de diseño 2.5D, sockets de nave coherentes, progresión `LVL 1..5`, vista orbital KSP 2.5D y radar 3D se detalla en [DISEÑO-UI-NAVES-25D.md](DISEÑO-UI-NAVES-25D.md) junto con [mockup_1_dique_modular_25d.png](mockups/mockup_1_dique_modular_25d.png) y [mockup_2_hud_ftl_ksp_orbital.png](mockups/mockup_2_hud_ftl_ksp_orbital.png).
- **Tipografía:** Prohibida `JetBrains Mono`. Rótulos, botones y narrativa en tipografía *sans-serif* limpia (`>= 12 px`); solo la telemetría numérica ($\Delta v$, $P_{explosion}$, `AP/PE`, tasa DSN) va en *monospace tabular* (`>= 11 px`).
- **HUD estilo tablero aeroespacial (sin cards SaaS):** Barra superior orbital/reactor, lienzo central único de vista dual FTL + KSP 2.5D (`74%` del ancho) y un solo panel lateral derecho (`26%`) con Radar 3D Wireframe y alertas críticas de 5 s.

---

## 7. Arquitectura Técnica en Godot 4.7 (Exportación Web Compatibility)

El proyecto se construye desde cero en **Godot 4.7+ (GDScript)** usando el renderer **`gl_compatibility`** (sin `Forward Plus` ni `Jolt Physics`) para exportar a WebGL2 Single-Threaded sin depender de cabeceras `COOP/COEP`.

```text
Space/
├── project.godot               # Godot 4.7, gl_compatibility, 1280x720, zero Jolt
├── AGENTS.md                   # Reglas del proyecto (Godot 4.7 Web, cero JetBrains Mono, cero emojis)
├── docs/
│   ├── 00-INDICE-Y-PLAN-MAESTRO-HACKATHON.md # Indice maestro, horarios, roles, Go/No-Go y trampas
│   ├── 01-CATALOGO-MODULOS-Y-EVOLUCION-NAVE.md # Chasis Orbital Mule Mk-I, 7 sockets y evolucion LVL 1..5
│   ├── 02-SISTEMA-ORBITAL-KSP-25D-Y-FISICA.md # Conicas AP/PE, nodos Delta-V, NavBall 2.5D y Radar 3D
│   ├── 03-INTERIOR-FTL-TRIPULACION-Y-CRISIS.md # 6 salas, esclusas, controles 1P/2-4P y 10 tarjetas de 5 s
│   ├── 04-GUION-MISIONES-Y-CONTRATOS-NASA.md # Guion de los 4 contratos NASA, deuda y Debrief Causal
│   ├── 05-ARQUITECTURA-GODOT-ESCENAS-Y-SHADERS.md # Escenas .tscn, shaders WebGL2 y guion video pitch <=30 s
│   ├── GDD-REMAKE-MASTER.md    # Copia canonica del documento maestro
│   ├── DISEÑO-UI-NAVES-25D.md  # Interfaz 2.5D, nave base evolucionable LVL 1..5 y vista KSP + FTL
│   ├── MECANICAS-REFERENCIA.md # Formulas, matriz de daño, perks NASA y guia de refs visuales (sin codigo heredado)
│   ├── INVESTIGACION-NAVES-INCIDENTES-NASA.md # Respaldo tecnico NASA/NOAA sobre subsistemas e incidentes reales
│   └── mockups/                # Mockups SVG/PNG 1280x720 (Dique Modular 2.5D + HUD FTL/KSP)
├── assets/
│   └── README.md               # Directorio limpio para arte propio (Directorio limpio para arte 2.5D propio)
├── data/
│   └── nasa/
│       ├── planetary_catalog.json
│       ├── neo_curated_missions.json
│       ├── solar_events_scenarios.json
│       └── debris_leo_catalog.json
├── game/
│   ├── main.tscn               # Escena raiz minima
│   ├── main.gd
│   ├── sim/                    # Logica pura RefCounted nueva desde cero (Lógica pura RefCounted nueva desde cero)
│   │   ├── reactor_power.gd    # Barras limitadas de reactor estilo FTL y manning bonus
│   │   ├── room_hazards.gd     # 6 salas, oxigeno, incendios, brechas y venteo de airlocks
│   │   ├── nasa_data_loader.gd # Carga y valida JSONs NASA/JPL + latencia DSN y flujo solar
│   │   ├── mission_evaluator.gd# Auditoria causal ("que hiciste bien / que hiciste mal")
│   │   └── station_input.gd    # Bus de intenciones desacoplado (1P y 2-4P locales sin pausa global)
│   ├── phases/                 # Fases jugables (Hangar, Despegue, Vuelo FTL/Overcooked, Debrief)
│   └── ui/                     # HUD diegetico NASAPunk sin JetBrains Mono
└── tests/
    └── test_runner.gd          # Suite headless determinista (godot --headless --script)
```

---

## 8. Plan de Acción por Hitos (Se hará esto -> para esto -> en esto -> con esto)

| Hito | Acción concreta | Responsable / Rol | Puerta de salida (Go/No-Go) |
| :--- | :--- | :--- | :--- |
| **Hito 0: Cimiento, Docs de Mecánicas, Datos NASA y Simulación Nueva** | **Se inicializará** `/home/axelmc/Documentos/Proyectos_JunDic/Space/` en Godot 4.7 (`gl_compatibility`), **se documentarán** en `docs/MECANICAS-REFERENCIA.md` las ecuaciones físicas, matriz de daño y catálogo de perks NASA, **se generarán** los 4 JSON de datos NASA/JPL y **se implementarán** desde cero los módulos base FTL/NASA en `game/sim/` **para garantizar** un arranque limpio y verificado **en** `Space/` **con** GDScript puro y snapshots oficiales NASA/JPL. | Simulación + Ciencia | `godot --headless --path Space --script res://tests/test_runner.gd` pasa al 100% (0 fallos, 0 scripts heredados de v1, `assets/` limpio). |
| **Hito 1: Vertical Slice Jugable (Misión Marte, 1P y 2P)** | **Se construirá** el flujo mínimo completo: Dique Seco simple -> Despegue -> HUD dual (corte interior FTL 2.5D + órbita KSP 2.5D con NavBall y nodo $\Delta v$) + barras reactor + incendio/fuga de 5 s -> Reporte final **para validar** en juego real si la mezcla *FTL + KSP 2.5D + Overcooked* es divertida **en** `game/phases/` y `game/ui/` **con** escenas Godot 2D + `CanvasGroup` silhouette + `StationInput`. | Gameplay + Core UI | Dos personas en un teclado (o 1 persona alternando `1-4`) despegan, apagan un incendio abriendo compuerta y ejecutan un nodo orbital mientras esquivan escombros. |
| **Hito 2: Nave Evolucionable (`LVL 1..5`) + 4 Destinos NASA + Perks** | **Se añadirán** las 4 misiones reales (Luna, Marte, Júpiter/Europa, Telescopio/NEO), la progresión `LVL 1..5` sobre los 7 hardpoints coherentes del chasis base, los 12 Perks NASA según `MECANICAS-REFERENCIA.md` y el Radar 3D Wireframe con downlink DSN **para obligar** a tomar compromisos reales de ingeniería **en** `DryDock`, `OrbitalMap25D` y `MissionEvaluator` **con** `planetary_catalog.json`, `solar_events_scenarios.json` y `neo_curated_missions.json`. | Sistemas + Contenido NASA | Ir a Júpiter con paneles solares falla por falta de energía (3.7%) y exige RTG; actualizar góndolas cambia su visual sin romper el casco. |
| **Hito 3: Tripulación Robot/Animal, Audio Reactivo y Pulido** | **Se integrarán** avatares de tripulación robótica/antropomórfica, alarmas de 5 s diferenciadas por cuadrante, efectos de eyección cómica, shader/overlay de falla en sensores (`vision`/`comms`) y descarga opcional Live NASA (`HTTPRequest` a NeoWs/DSN) **para maximizar** *Art & Technology*, *Storytelling* y legibilidad bajo estrés **en** `CrewEntity` y HUD **con** sprites propios de `assets/` + síntesis procedural (`AudioStreamGenerator`) + tipografía limpia sin `JetBrains Mono`. | Arte / Audio / UX | Partida completa a 60 FPS sin caídas; cada avería se identifica en <1 segundo sin leer párrafos largos. |
| **Hito 4: Exportación Web, Video 30s y Paquete Space Apps** | **Se instalarán** los export templates Web de Godot 4.7.2, **se compilará** el export HTML5 Single-Threaded (`gl_compatibility`), **se publicará** en URL pública y **se grabará** demo <=30 s con subtítulos en inglés + ficha *NASA & Partner Data* **para cumplir** el 100% de elegibilidad del jurado global **en** GitHub Pages / itch.io + portal Space Apps **con** Godot Web Export, OBS/FFmpeg y tabla de fuentes oficiales. | Integración + Pitch | URL pública abre el juego en navegador sin descarga + video <=30 s mostrando datos NASA en pantalla + repo abierto con citas completas. |

---

## 9. Riesgos y Trampas a Evitar durante el Desarrollo

1. **Trampa de la "Pausa Táctica":** Agregar pausa en tiempo real (`get_tree().paused`) para que sea más fiel a FTL destruirá el componente *Overcooked*; el respiro debe ocurrir únicamente en el **Mapa de Nodos** entre tramos.
2. **Trampa de la UI sobre-explicada:** Si cada módulo muestra 8 estadísticas en texto pequeño, nadie juega en modo caótico. Mostrar solo **3 barras en Hangar** ($\Delta v$, Energía en Destino, Riesgo de Despegue) y **estado Verde/Ámbar/Rojo + barra de energía FTL** en vuelo; el detalle numérico profundo va al **Reporte Final**.
3. **Trampa de red prematura:** Implementar `ENetMultiplayerPeer` antes de tener el Vertical Slice local divertido consume el 60% del tiempo. El diseño desacopla entradas en `station_input.gd` para que el juego funcione hoy en local (1P y 2–4P) y quede listo para red en una fase posterior.
4. **Trampa del video demo:** Exceder los **30 segundos** o no subtitular en inglés descalifica la entrega en evaluación global de NASA Space Apps. El video debe mostrar *gameplay* real en los segundos 6–18 con etiqueta visible del dataset NASA que controla la escena.
