# Margin Zero: Deuda Orbital — Plan de diseño y desarrollo (Godot 4.7, local primero)

## Context

Pediste un plan de diseño y desarrollo accionable para un cooperativo de 1–4 robots chatarra que pagan la deuda de una compañía de envíos espaciales. Tus respuestas fijan cuatro cosas: se parte **desde cero** (el repo solo tiene `project.godot` y el addon `godot_ai`; no existen `game/sim/`, `data/nasa/` ni `docs/`), la estructura es **campaña roguelite**, el juego es **local primero** (el online irá después contra **tu servidor propio**) y "solo hazlo": tras aprobar, se construye.

Etiquetas usadas: **[NASA]** = dato real de los anexos; **[DIS]** = licencia de diseño. Todos los números de economía y probabilidad son valores iniciales a calibrar en el hito H0.

### Contradicciones detectadas y cómo se resuelven

| # | Conflicto | Resolución |
|---|---|---|
| 1 | El Anexo A no llegó. | Se reconstruye desde el Anexo C (§1 subsistemas, §2 incidentes) en `docs/ANEXO-A-RECONSTRUIDO.md`, marcado como supuesto. |
| 2 | Los anexos citan `game/sim/`, `data/nasa/*.json`, `docs/DISEÑO-UI-NAVES-25D.md`, que no existen aquí. | Se recrean con esos mismos nombres; la paleta "NASAPunk + Rhine Lab" queda como pregunta abierta. |
| 3 | Los anexos modelan O₂/CO₂/hipoxia para humanos; los jugadores son robots. | [DIS] El aire de cabina es el **refrigerante por convección** de los robots (coherente con el Mito 1: el vacío aísla y sobrecalienta). Sala sin aire: 15 s hasta "estrangulamiento térmico" (guiño al TUC de 12–15 s [NASA]), 30 s hasta apagado. El CO₂/LiOH solo importa en contratos de "carga viva". |
| 4 | Anexo C dice "2.5D"; tú pides dos vistas 2D. | "2.5D" = sprites 2D con bisel y luz fija a 315°. No hay 3D. El proyecto está en Forward+ con Jolt 3D; se pasa a renderer Compatibility. |
| 5 | Anexo B llama "Fase 2" al despegue; en tu loop es la fase 3. | Se usa tu numeración. |
| 6 | `P_explosion` llega a 0.95 como tirada; el pilar 4 prohíbe muerte instantánea. | La tirada fallida abre una **alerta roja de 4 s** [Anexo B] con salidas (jettison, abortar). Solo si nadie actúa explota, y eso cuesta deuda, no la campaña. |
| 7 | `DamageMatrix` cubre 6 salas fijas; pides nave modular. | Cada módulo nuevo declara su cuadrante (`top/middle/bottom/radial`) en `modules.json`. |
| 8 | RTLT real de Marte = 1501 s: injugable. | [DIS] retardo de juego `d = RTLT^0.35` (ver §4.1). |
| 9 | El DSN impide pilotar desde Tierra [NASA]; pides evaluar CAPCOM. | CAPCOM solo asesora, con retardo; nunca controla. En local es un NPC (ver fase 4). |
| 10 | Los 12 perks no incluyen paneles, RTG, antena, paracaídas ni patas. | [DIS] Catálogo de módulos base nuevo en `data/design/modules.json`. |
| 11 | Júpiter es un gigante gaseoso (g = 24.79 m/s²): no hay superficie donde aterrizar ni explorar. | Los contratos de tier 3 entregan en **Ganímedes** [NASA: g = 1.428 m/s², sin atmósfera, radio 2 634 km]. Viaje, irradiancia (5.2 AU), RTLT y cinturón de radiación siguen siendo los de Júpiter. `ganymede` en `planetary_catalog.json` con `parent: jupiter`. |
| 12 | Un NEO (g ≈ 0.00008 m/s²) no permite "aterrizar" ni caminar. | [DIS] El aterrizaje es un acople en microgravedad (frenar a < 0.5 m/s con RCS). En superficie los robots van atados con cable: un salto que rompe el cable deja al robot a la deriva (recuperarlo cuesta 150 cr). |

---

## 1. Resumen ejecutivo

**Qué es.** Roguelite cooperativo local (1–4 jugadores en una pantalla, mando o teclado) de 8–12 misiones por run. Cada misión dura 25–40 min y recorre 7 fases: tablero, taller, despegue, navegación, aterrizaje, exploración y regreso con pago. La run se gana con deuda = 0 y se pierde por embargo.

**Gancho.** Un jugador pilota con mecánica orbital real simplificada (nodos, prograde/retrograde, Hohmann) mientras el resto mantiene viva una nave hecha de chatarra. La información solo aparece en pantalla si un robot atiende la consola que la produce, así que coordinar quién mira qué es el juego.

**Tensión central.** Más nave reduce fallas internas pero sube masa, costo y sobrecarga Ω. Más lejos paga más pero escala amenazas, retardo y falta de luz solar. Las fórmulas están en §4.1.

**Suerte.** Solo moneda del juego. Suerte que ayuda (piezas LEGENDARY, botón misterioso, salvage) y que sabotea (cláusulas ocultas, mutadores, patada que empeora). Una variable `luck ∈ [-0.5, 1.0]` [Anexo B] con compensación tras rachas malas.

**Arquitectura.** Simulación autoritativa en GDScript puro (`game/sim/`, sin nodos, RNG con semilla, tick fijo 30 Hz) que consume comandos de jugador. Hoy la alimenta una `LocalSession`; mañana, el mismo código corre *headless* en tu servidor dedicado. La vista nunca muta la simulación.

**Ruta.** H0 papel + Monte Carlo → H1 interior jugable → H2 piloto orbital → H3 vertical slice lunar → H4 alpha (Marte, NEO, Júpiter, bots, online).

---

## 2. Loop principal

### Primera misión de práctica (implementación del 15 de noviembre de 2026)

Antes de arriesgar una nave, el menú y el hangar ofrecen una práctica opcional y
repetible: Tierra → órbita → Tierra. No acepta contratos ni usa créditos o piezas
del perfil. Solo guarda `training_completed` después del aterrizaje; salir o
saltar conserva ese indicador sin marcar nuevas lecciones como completadas.

El montaje enseña una receta de abajo hacia arriba: Trueno, tanque gordo,
desacoplador, Susurro, tanque largo, escudo, cabina, paracaídas, panel y batería.
Es una receta educativa, no una restricción universal de construcción. Cada
colocación, retirada y movimiento recalcula el primer paso pendiente. Se verifican
motor y combustible por etapa, TWR, delta-v y energía. Los extras añaden capacidad
a cambio de masa y coste; el ensayo incluye una variante con antena.

En vuelo se verifican ignición, orientación, reducción y recuperación de potencia
ante carga aerodinámica, reparación de un desacoplador atascado, separación manual de la
etapa agotada, empuje superior, orientación retrógrada, frenado, corredor de entrada
y dos despliegues de paracaídas. El combustible activo se muestra separado del total.
Las lecciones críticas congelan la física hasta actuar; el rumbo se asiste al
soltar el giro. El tramo de costa hasta la entrada se resume explícitamente [DIS].
Al fallar se restaura el último punto de control, incluidos combustible, escudo,
energía, estado físico y RNG, con objetos independientes. La avería programada
se repite al restaurar su punto de control.

La implementación está aislada del flujo legado: `TrainingSession` es RefCounted,
consume `PlayerCommand` y avanza a 30 Hz con `SimRng`; la vista solo envía comandos
y lee resultados. Reutiliza las funciones de integración de RocketMath y las
estadísticas de ShipModel sin llamar a sus rutas dependientes de autoloads.
No migra toda la campaña a esta arquitectura ni modifica su balance.

Los pasos, umbrales y escalas de práctica están en `data/design/training.json`
[DIS]. La gravedad terrestre procede de `data/nasa/training_earth.json` [NASA],
con fuente NASA; el radio reducido y la atmósfera simplificada son parámetros de
juego separados. El catálogo legado conserva sus Resources de piezas.

Validación: suite McpTestSuite `training` mediante `test_run` del addon, y runner
`tests/training_runner.gd` que adapta el mismo handler al runtime sin editor.
Incluye dos vuelos completos, repetición determinista, errores de montaje,
separación temprana, etapa superior inválida, avería y reintento, corredor inseguro,
ventanas congeladas, vuelo de principiante sin ajustes de potencia no explicados y
aislamiento de campaña. Los runners deshabilitan la persistencia del perfil antes
de probar; las pruebas antiguas de smoke reinician su estado en memoria.
`tools/training_walkthrough.gd`
recorre la práctica y captura estados sin guardar progreso.

```
        ┌──────────────────────── RUN (8–12 misiones, deuda inicial 8 000 cr) ───────────────────────┐
        │                                                                                              │
 HUB ─▶ 1 PLANEACIÓN ─▶ 2 TALLER ─▶ 3 DESPEGUE ─▶ 4 NAVEGACIÓN ─▶ 5 ATERRIZAJE ─▶ 6 EXPLORACIÓN ─▶ 7 REGRESO/PAGO ─┐
 cenital   cenital+UI    cenital     lateral+PiP   cenital 62 %     lateral+PiP      lateral          lateral → UI   │
          2–3 min        4–6 min     60–90 s       + mapa 38 %      60–120 s         4–6 min          3–6 min        │
                                                    6–14 min                                                          │
        ▲                                                                                                             │
        └──── deuda > 0: interés 5 %, desgaste acumulado, reputación ◀───────────────────────────────────────────────┘
              deuda = 0 → victoria │ 2 impagos seguidos o deuda ≥ 20 000 → embargo (fin de run) → desbloqueos
```

**Vistas y transiciones.** Cenital para todo lo que ocurre dentro (hub, taller, interior de nave). Lateral para todo lo que ocurre fuera (ascenso, mapa orbital, descenso, superficie). Transición única: fundido de 0.5 s en el que la silueta lateral de la nave se "abre" en corte cenital.

**Ambas vistas a la vez en navegación (pantalla compartida).** Viewport lógico 1920×1080: interior cenital a la izquierda (1184 px) y mapa orbital a la derecha (736 px), siempre visibles. El mapa es diegético (la pantalla del timón): si ningún robot está en el timón se muestra con estática y sin nodos. En ventanas de maniobra (T−20 s) el mapa crece a 60 %. En despegue y aterrizaje se invierte: lateral a pantalla completa y el interior en un recuadro PiP de 35 %. En el online posterior cada cliente elige su reparto (piloto: mapa grande; tripulación: interior grande con minimapa).

---

## 3. Diseño por fase

### Fase 1 — Planeación (tablero de misiones)
- **Objetivo:** elegir 1 de 4 contratos (designación de vuelo `BALLAST-1` a `BALLAST-4`; en reintentos de campaña el contador correlativo asciende a `BALLAST-5 .. BALLAST-N`) y, opcionalmente, apuestas previas.
- **Vista:** hub cenital (oficina en quiebra) con consolas; el tablero abre un panel UI.
- **Roles:** Comandante firma el contrato (los demás votan con *ping*; sin unanimidad en 60 s decide el Comandante). Comunicaciones ve el parte de clima espacial y conjunción. Navegación ve Δv requerido. Sistemas ve la irradiancia `f(r)` en destino.
- **Controles:** moverse, `A` interactuar con consola, cruceta para recorrer contratos.
- **Mecánicas:** cada contrato = destino + carga (masa, tipo: inerte / frágil / viva / "no preguntes") + pago + plazo + requisitos (p. ej. "escudo térmico", "≥ 2 t de bodega"). Pago en §4.1.
- **Gambling:** 1 de cada 4 contratos es **sospechoso**: paga ×2.2 con cláusula oculta que se revela con d6 al llegar (1–2 mala: multa 40 % o carga inestable; 3–4 neutra; 5–6 propina +25 %). **Seguro de misión** (cuesta 12 % del pago; cubre 60 % si falla). **Bitácora de apuestas:** el equipo apuesta hasta 200 cr a "llegamos sin jettison".
- **Éxito/fracaso:** no se falla; decisión mala = misión imposible para la nave actual (el tablero avisa en rojo si Δv o energía no alcanzan).
- **Duración:** 2–3 min.
- **Conecta con:** fija destino, masa de carga y requisitos del taller.
- **Datos:** `planetary_catalog.json` (f(r), RTLT, atmósfera), `neo_curated_missions.json`, `solar_events_scenarios.json`.

### Fase 2 — Diseño de nave (taller)
- **Objetivo:** adaptar la nave al destino con el dinero disponible.
- **Vista:** cenital, editor sobre rejilla de 32 px, con vista previa lateral de la silueta y sus *hardpoints* (`SOCKET_BOW`, `PORT/STBD_NACELLE`, `WING_PORT/STBD`, `DORSAL_TURRET`, `AFT_ENGINES`).
- **Roles:** cualquiera compra; el Comandante confirma el lanzamiento. Cada rol ve su medidor en vivo: Navegación Δv (Tsiolkovsky) y TWR; Sistemas balance de barras y `temp_norm` previsto; Comunicaciones aviso y cobertura; Comandante Ω y `P_explosion`.
- **Controles:** cursor por jugador (color propio), `A` colocar, `X` quitar/vender (50 % del valor), `Y` abrir caja.
- **Mecánicas:**
  - Nave insignia **MZ-1 BALLAST** (chasis **Orbital Mule Mk-I**) [DIS]: 12×8 celdas, 6 salas (`helm`, `sensors`, `reactor`, `life_support`, `engines`, `science_bay`), seco 11 t, propelente 17 t, bodega 2 t, empuje 420 kN, Isp 316 s (hipergólico [NASA]). `M_rated = 420 000 / (1.25·9.80665) = 34.3 t`.
  - Los 12 perks y 4 calidades del Anexo B, sin cambios.
  - Módulos base [DIS]: panel solar (120 cr, 0.4 t, 2.0 u a 1 AU), RTG (700 cr, 1.0 t, 1.5 u constantes, +calor), batería, antena de alta ganancia (220, 0.3 t), paracaídas (160, 0.3 t), patas (140, 0.5 t), tanque extra (180, 0.6 t seco + 4 t), bodega (+2 t, 100, 0.8 t), sala de respaldo (redundancia R).
  - Adaptación forzada por datos: solar en Júpiter rinde 3.7 % [NASA]; paracaídas en Luna inútil (`P_bar = 0`) [NASA]; MLI se desgarra si `q > 12 000 Pa`.
- **Gambling:** **cajas del desguace** (pieza al azar con los pesos de calidad del Anexo B; 60 % del precio medio), **ruleta del chatarrero** (volver a tirar: 50·2ⁿ cr), piezas LEGENDARY con mutador.
- **Éxito/fracaso:** no se falla; se puede despegar con Ω > 0 si el Comandante acepta el riesgo mostrado.
- **Duración:** 4–6 min. Reloj blando de ventana de lanzamiento: pasados 6 min, −5 % de pago por minuto.
- **Conecta con:** masa, `H_struct`, `R_prop`, redundancia y energía alimentan todas las fases.
- **Datos:** Anexo B §1, §2, §3, §5.

### Fase 3 — Despegue
- **Objetivo:** llegar a órbita baja sin perder nave ni carga.
- **Vista:** lateral a pantalla completa + interior en PiP de 35 %.
- **Roles y segundos críticos (60–90 s):**

| t | Evento | Quién | Qué hace |
|---|---|---|---|
| T−10…0 | Cuenta atrás | Navegación | Pulsa ignición; error ≤ 0.15 s anula `τ_eff` [Anexo B] |
| T−10…0 | Precarga | Sistemas | Mantiene 2 válvulas en verde (pulsos alternos) → sube `R_prop` efectivo hasta +0.05 |
| T+0…5 | Tirada `P_ign` | — | Fallo = alerta roja 4 s |
| T+20…40 | Max-Q | Navegación | Baja gases para que `q ≤ 28 000 Pa` (σ_q = 0) |
| T+20…40 | Vibración/pogo | Comunicaciones | Lee galgas y canta la frecuencia; Sistemas activa `damper_cryo_he` |
| T+30 | Tirada `P_ascent` | — | Fallo = alerta roja 4 s |
| Alerta | Decisión | Comandante | `jettison_cargo` (recalcula Ω y repite la tirada una vez) o abortar |
| T+50…70 | Separación de etapa | Todos | Dos robots pulsan a la vez (ventana 1 s); fallo = asimetría `asym` |

- **Mecánicas:** fórmulas de `TakeoffRisk` tal cual. Ejemplos: nave toda SCRAP (`cond` media 0.475) → `P_ign ≈ 19 %`; toda NEW (0.92) → `≈ 3 %`. Con 41 t, Ω = 0.197 y `0.42·Ω² = 1.6 %`; con Ω = 0.5, 10.5 %.
- **Gambling:** apuesta de bitácora; "saltarse la lista de comprobación" (−20 s de fase, +5 % de pago por puntualidad, +0.04 a `P_ign`).
- **Éxito:** órbita con PE ≥ 100 km. **Fracaso:** aborto (misión fallida, robots intactos, 50 % de las piezas degradadas a SCRAP) o explosión (Mule de reemplazo toda SCRAP y +3 000 cr de deuda).
- **Conecta con:** propelente restante = Δv de navegación; piezas dañadas entran rotas a la fase 4.
- **Datos:** Anexo B §1 (ρ(h), q), §3; Pogo SP-8055 y Max-Q [NASA].

### Fase 4 — Navegación espacial
- **Objetivo:** llegar al destino con PE y Δv válidos y la nave funcional.
- **Vista:** cenital 62 % + mapa orbital lateral 38 %.
- **Estructura temporal [DIS]:** el interior siempre corre en tiempo real. El viaje se parte en tramos: *ventanas de maniobra* (30–90 s, sin aceleración temporal) y *travesías* (2–4 min de juego que comprimen días; ahí cae la mayoría de eventos). Luna 6–8 min, NEO 8–10, Marte 10–12, Júpiter 12–14.
- **Piloto (Navegación):**
  - Mapa 2D coplanar con cónicas enlazadas y propagación analítica de Kepler (órbitas "sobre raíles").
  - Nodo de maniobra: `A` lo coloca sobre la órbita, stick ajusta prograde/retrograde y radial; muestra Δv, AP y PE resultantes. `RT` acelera; una barra indica el Δv pendiente.
  - Asistencias: el botón "Hohmann" pide la solución a Tierra (tarda `d`, y puede venir mal, evento I8). Sin Tierra, se hace a mano.
  - Escala [DIS]: radios y distancias 1:10 con gravedad superficial real, de modo que todo Δv ≈ real/√10 (TLI real ≈ 3.1 km/s [NASA] → ≈ 1.0 km/s en juego). Irradiancia y RTLT usan los valores reales del catálogo.
  - Mito 3 como mecánica: en encuentros (salvage E10) acelerar prograde te aleja.
- **Tripulación:** mover, `A` mantener para reparar (6–10 s con herramienta), `X` cargar/soltar (extintor, parche, repuesto, cartucho), `B` patada, `Y` *ping*. Consolas: energía (7 barras de `ReactorPower` a repartir), ventilación, esclusas, válvulas.
- **Eventos:** un `EventDirector` reparte externos (telegrafiados) e internos (en cascada) según §4.1; toda avería crítica sin atender escala en 5 s [Anexo C §3.2]. Catálogo en §6.
- **Retardo y conjunción:** servicios de Tierra (diagnóstico de causa raíz, solución de maniobra, parche de software, cobro de apuestas, alerta de seguimiento) tardan `d` en responder y los avisos externos llegan `d/2` tarde. En conjunción (60–90 s) no hay Tierra; antes, Comunicaciones descarga un **paquete de contingencia** con 2 servicios a elección.
- **CAPCOM (3 + 1):** evaluado y **pospuesto al online**. En pantalla compartida no hay asimetría de información posible. Diseño previsto: el cuarto jugador ve esquema completo, causas raíz y cola de eventos a 10 s, pero ve la nave con `d/2` de atraso y sus mensajes llegan `d/2` tarde; en conjunción queda cortado. Riesgo: trivial en Luna (1.4 s), frustrante en Júpiter (20 s); por eso será modo opcional. En local lo sustituye el NPC "Control de Deudas".
- **Gambling:** botón misterioso (G1), patada (G2), mutadores LEGENDARY (G3), apuestas entre robots (G4).
- **Éxito:** captura en destino con PE dentro de ±15 % del objetivo. **Fracaso:** PE < 100 km en cuerpo con atmósfera (entrada no planeada, daño en `top`), sin Δv (deriva: remolque de la compañía, −60 % de pago y +800 cr) o los 4 robots apagados a la vez (remolque).
- **Conecta con:** propelente, integridad del escudo y averías abiertas condicionan el aterrizaje.
- **Datos:** Anexo B §1, §2, §4; Anexo C §1.3–1.7, §2, §3.

### Fase 5 — Aterrizaje
- **Objetivo:** posar la nave cerca de la baliza de entrega.
- **Vista:** lateral + interior PiP 35 %.
- **Roles:** Navegación (gases e inclinación), Comandante (elige trayectoria y canta el despliegue), Sistemas (reparte energía a escudo/motores y enfría), Comunicaciones (altímetro radar: sin él, la altitud se muestra con ±15 % de error).
- **Mecánicas:**
  - **Luna** (`P_bar = 0`, g = 1.62 m/s² [NASA]): retropropulsión total; paracaídas y escudo no aportan nada.
  - **Marte** (0.0064 bar, H = 11.1 km [NASA]): escudo → paracaídas (ventana de despliegue de 3 s) → retro en los últimos 500 m.
  - **Tierra** (regreso): escudo + paracaídas.
  - Trayectoria: *tendida* (pico térmico bajo, más tiempo, riesgo de rebote), *nominal*, *picada* (ahorra Δv, pico térmico ×1.6). `shield_pica` pierde 0.28 por uso; `shield_hrsi` no se gasta pero puede romperse [Anexo B].
  - Toque [DIS]: vertical < 3 m/s y horizontal < 2 m/s e inclinación < 10° = perfecto; 3–5 leve, 5–8 grave, 8–12 crítica, > 12 catastrófica, aplicado al cuadrante `bottom` de la `DamageMatrix`.
- **Gambling:** la trayectoria picada es la apuesta; "aterrizaje de exhibición" (declarar toque < 1 m/s: +10 % de pago, o −10 % si falla).
- **Éxito/fracaso:** posada y con `engines` operables = éxito. Nave posada sin motores = hay que repararla en superficie con salvage antes de despegar.
- **Duración:** 60–120 s.
- **Conecta con:** distancia a la baliza = tiempo de caminata en fase 6; daño y Δv restante condicionan el regreso.
- **Datos:** `planetary_catalog.json`; Columbia STS-107 [NASA].

### Fase 6 — Exploración de superficie
- **Objetivo:** entregar el envío y traer todo el valor extra que la nave pueda levantar.
- **Vista:** lateral, mapa de 600–900 m con la nave como base.
- **Roles:** cualquiera hace todo; especialidades ×1.5: Comandante carga pesada, Navegación conduce el carrito, Sistemas recarga/repara robots, Comunicaciones escanea (revela valor de restos a 40 m).
- **Controles:** mover, saltar, `A` interactuar, `X` cargar (cajas pesadas: 2 robots), `RT` cabrestante/red.
- **Mecánicas:** batería de EVA de 240 s (recarga en la nave en 8 s); entrega en baliza a 150–300 m; muestras (30–120 cr); restos con `winch_uhmwpe` (120 m, 55 kN) y `net_supercond` (35 m, drena 0.40/s) [Anexo B]. Peligros: cráteres y saltos largos en baja gravedad, regolito cortante (rompe piernas), oscuridad (radio de luz), tormenta de polvo en Marte (solar a 0, aviso 20 s). Cada kilo recogido resta Δv de ascenso: el taller portátil muestra el Δv restante en vivo.
- **Gambling:** **cajas sin identificar** (G5), "una carrera más" con el reloj de ventana de regreso (5 min; después −10 % de pago por minuto).
- **Éxito:** envío entregado y todos a bordo. **Fracaso parcial:** robot sin batería queda en superficie (se recupera pagando 150 cr de "reensamblaje" o cargándolo otro jugador).
- **Duración:** 4–6 min.
- **Conecta con:** masa extra y piezas recogidas entran al regreso y a la economía.
- **Datos:** Anexo B §5.1 (salvage); gravedad y atmósfera del catálogo.

### Fase 7 — Regreso, pago y deuda
- **Objetivo:** volver, cobrar y decidir cuánto pagar.
- **Vista:** lateral (ascenso corto, travesía de vuelta de 3–5 min con la fase 4 reducida, reentrada terrestre) y luego UI de liquidación en el hub.
- **Roles:** como en fases 3–5. En la liquidación el Comandante reparte: pago de deuda, reparaciones y caja.
- **Mecánicas:** liquidación = pago × modificadores (puntualidad, estado de la carga, cláusulas) + ventas de salvage − combustible − alquiler de lanzador − reparaciones. Luego interés y cuota (§4.2). `MissionEvaluator` muestra la cadena causal de lo que salió mal ("la brecha vino del radiador que nadie parchó").
- **Gambling:** **doble o nada** con el prestamista (G7); vender o quedarse piezas no identificadas.
- **Éxito/fracaso:** condiciones de run en §4.2.
- **Duración:** 3–6 min de vuelo + 1–2 min de liquidación.
- **Conecta con:** nuevo tablero con contratos según reputación; el desgaste (`wear`) persiste.
- **Datos:** Anexo B §2 (escudos), Anexo C §2 (incidentes en `MissionEvaluator`).

---

## 4. Sistemas transversales

### 4.1 Tensión central: fórmulas

**Nave (interno).** `H_struct` es el del Anexo B. `R` ∈ [0,1] = fracción de los 6 sistemas críticos con respaldo. `k_p` = 0.55 / 0.75 / 0.90 / 1.00 para 1–4 jugadores.

```
λ_int  = 0.50 · (1.6 − H_struct) · (1 − 0.45·R) · k_p        averías internas por minuto   [DIS]
Ω      = max(0, (m_total − M_rated) / M_rated)                                             [Anexo B]
Δv     = Isp · g0 · ln(m_wet / m_dry)                                                      [Anexo B]
```
Ejemplo: toda SCRAP sin respaldo → 0.56/min (≈ 5–6 averías en 10 min). Toda NEW con respaldo total → 0.19/min (≈ 2), pero +6 a +9 t: Ω sube de 0 a 0.15–0.25 y el Δv baja ≈ 12–18 %.

**Destino (externo).** `tier` = 0 Luna, 1 NEO, 2 Marte, 3 Júpiter.

```
Pago_base = 1000 · (1 + tier)^1.5                                                          [DIS]
λ_ext     = 0.20 · (1 + 0.5·tier) · k_p        eventos externos por minuto                 [DIS]
d         = RTLT^0.35                          retardo de juego en segundos                [DIS sobre dato NASA]
f(r)      = 1 / max(r_AU, 0.2)²                                                            [Anexo B]
P_gen     = P_solar · min(f, 2.5) + P_rtg                                                  [Anexo B]
```

| Destino | r (AU) [NASA] | f(r) [NASA] | RTLT real [NASA] | d juego | Pago base | λ_ext/min | P(conjunción) [DIS] |
|---|---|---|---|---|---|---|---|
| Luna | 1.00 | 1.000 | 2.56 s | 1.4 s | 1 000 | 0.20 | 0 |
| NEO (Bennu, Didymos, Eros) | ≈ 1.1–1.6 | 0.39–0.83 | variable (≈ 300 s típico) | ≈ 7 s | 2 828 | 0.30 | 0.10 |
| Marte | 1.52 | 0.433 | 1 501 s | 12.9 s | 5 196 | 0.40 | 0.25 |
| Júpiter | 5.20 | 0.037 | 5 193 s | 20.0 s | 8 000 | 0.50 | 0.30 |

Conjunción solar de Marte: real, cada ≈ 26 meses con ≈ 2 semanas sin comandos [NASA]; la probabilidad por misión es [DIS] y el tablero la anuncia (+20 % de pago).

### 4.2 Economía y deuda [DIS]
- **Inicio:** deuda 8 000 cr, caja 1 200 cr, Mule Mk-I toda SCRAP.
- **Ingresos:** contrato, propinas de cláusula, salvage, muestras, apuestas ganadas.
- **Costos:** propelente 20 cr/t; alquiler de lanzador 100 cr por cada 10 t; reparación = 40 % del precio de la pieza × daño; reensamblaje de robot 150 cr; seguro.
- **Deuda:** interés 5 % compuesto por misión. Cuota mínima 8 % de la deuda. Impago: recargo del 10 % y una "falta".
- **Embargo (fin de run):** 2 faltas seguidas o deuda ≥ 20 000 cr.
- **Victoria:** deuda = 0. Objetivo de calibración: 35–50 % de victorias con política media en el Monte Carlo de H0.
- **Reputación** (0–5 estrellas): sube con entregas puntuales; abre contratos lejanos y baja el precio de piezas NEW 5 % por estrella.
- **Meta-progresión entre runs:** cascos iniciales alternativos (3), tipos de contrato, 1 tirada gratis de ruleta, cosméticos de chasis. Amplía opciones; no sube estadísticas.

### 4.3 Roles
Reconstruidos del Anexo C (supuesto hasta tener el Anexo A):

| Rol | Referencia Mission Control | Consola propia | Ventaja |
|---|---|---|---|
| Comandante | FLIGHT | energía (7 barras), jettison, abortar, contratos | decide empates; carga pesada ×1.5 |
| Navegación | FDO / GUIDO | timón, nodos, RCS | maniobra con error de ejecución −50 % |
| Sistemas Vitales | EECOM | ventilación, esclusas, térmico | repara y apaga fuego ×1.5 |
| Comunicaciones y Datos | INCO / CAPCOM | sensores, antena, enlace a Tierra | diagnóstico y auditoría de nodos ×1.5 |

**Ni fijos ni por fase:** se eligen en el hub antes de cada misión. Todo robot puede hacer todo a velocidad ×1; el rol da ×1.5 en lo suyo. Con menos de 4 jugadores un robot lleva 2 roles (a ×1.25).

### 4.4 Escalado 1–4

| Jugadores | Salas | Averías simultáneas máx. | k_p | Ayuda |
|---|---|---|---|---|
| 1 | 4 | 1 | 0.55 | 2 bots chatarra con órdenes por sala; piloto automático ejecuta nodos con ±8 % de error |
| 2 | 5 | 2 | 0.75 | 1 bot; piloto automático opcional |
| 3 | 6 | 3 | 0.90 | — |
| 4 | 6+ | 3 | 1.00 | — |

Los bots reparan a ×0.6 y nunca usan el botón misterioso ni patean.

### 4.5 Robots como personaje
- **4 partes intercambiables:** cabeza (radio de visión propio), brazos (reparar/cargar), piernas (velocidad), batería (EVA).
- **Daño:** cada golpe suelta una parte, que rueda por el suelo. Sin cabeza el robot camina a ciegas y choca; sin brazos empuja con el cuerpo; sin piernas se arrastra a 40 %. Nunca muere: un torso se rearma en el banco (10 s con ayuda, 20 s solo) o un compañero le presta una parte.
- **Personalidad:** 1 manía al azar por robot y run, de un mazo de 6 (cleptómano: recoge objetos solo 5 % de las veces; optimista: su consola muestra probabilidades 10 % mejores de lo real; etc.).
- **Humor físico:** resbalones con fugas, chispazos al tocar agua, cabezas usadas como balón.

### 4.6 Entrada y sesión (local) y red (después)
- **Local ahora:** `PlayerInput` por dispositivo (4 mandos, o 2 en teclado: WASD+E/Q/F/R y flechas+,/./M/N) emite `PlayerCommand`. `LocalSession` los entrega a `SimWorld.step(dt, commands)` a 30 Hz. La vista lee instantáneas y eventos.
- **Online después (tu servidor):** **servidor dedicado autoritativo**, el mismo `game/sim/` exportado *headless*, ENet. Se elige sobre host autoritativo porque ya tienes servidor, elimina la ventaja y la migración de host, y la simulación ya está separada de la vista.

| Fase | Qué se sincroniza | Frecuencia |
|---|---|---|
| Hub / tablero / taller | estado discreto (votos, compras, plano) | por evento |
| Despegue / aterrizaje | estado del vehículo + entradas de consola | 30 Hz |
| Navegación interior | posiciones de robots, salas, averías | 20 Hz con interpolación de 100 ms; robot propio con predicción |
| Navegación orbital | **elementos orbitales + época**, solo al cambiar (quemado, cambio de esfera) | por evento |
| Superficie | posiciones, objetos cargados, cable | 20 Hz |

Latencia en la física orbital: al ir sobre raíles, cada cliente propaga la misma órbita de forma analítica y no hay deriva. Solo el quemado es sensible: el piloto predice localmente y el servidor confirma los elementos resultantes. La aceleración temporal la dicta el servidor.

---

## 5. Trazabilidad

| Mecánica | Caso o dato NASA | Archivo / sistema |
|---|---|---|
| Δv, TWR, Hohmann, nodos | Tsiolkovsky, Kepler; Mito 3 | `game/sim/orbital_math.gd`, `game/view/orbital/` |
| Error de unidades en nodo (I8) | Mars Climate Orbiter 1999 | `game/sim/mission_evaluator.gd`, `event_director.gd` |
| Riesgo de despegue, jettison | Max-Q 28–35 kPa; Pogo Apollo 6/13 | `game/sim/takeoff_risk.gd` |
| Daño por cuadrante | Energías de escombros 3 200–16 500 J | `game/sim/damage_matrix.gd`, `data/nasa/debris_leo_catalog.json` |
| Brecha lenta, parcheo | Mir–Spektr 1997; Mito 2 | `game/sim/room_hazards.gd` |
| Fuego con ventilación | Mir 1997 (vela Vika), Saffire; Mito 4 | `room_hazards.gd` (`trigger_hazard`, `set_airlock`) |
| Reparto de 7 barras | Apollo 13 (pérdida de pilas) | `game/sim/reactor_power.gd` |
| Fuga de radiador, sobrecalentamiento | Soyuz MS-22; Stefan-Boltzmann; Mito 1 | `game/sim/thermal.gd` (`temp_norm`) |
| Aire como refrigerante de robots | Mito 1; TUC 12–15 s | `thermal.gd`, `robot_model.gd` [DIS] |
| Irradiancia, solar vs RTG | 1361/r² W/m²; MMRTG | `thermal.gd`, `data/nasa/planetary_catalog.json` |
| Retardo y conjunción | RTLT DSN; conjunción de Marte | `game/sim/comms_link.gd`, `planetary_catalog.json` |
| Tormenta solar, SEU | Halloween 2003; RAD750/EDAC | `event_director.gd`, `data/nasa/solar_events_scenarios.json` |
| Giro descontrolado, gimbal lock | Gemini 8, Nauka; CMG ISS | `event_director.gd`, perk `cmg_stabilizer` |
| Aterrizaje por atmósfera | Fact Sheet (Luna 0 bar, Marte 0.0064 bar) | `game/sim/landing.gd` |
| Escudo térmico | Columbia STS-107 | perks `shield_hrsi`, `shield_pica` |
| Calidades, mutadores, suerte | — [DIS, Anexo B §5.2] | `game/sim/shop_roller.gd`, `data/design/parts.json` |
| Destinos NEO | Bennu, Didymos, Eros, Psyche (JPL SBDB) | `data/nasa/neo_curated_missions.json` |
| Carga de datos | — | `game/sim/nasa_data_loader.gd` |

---

## 6. Catálogo inicial de eventos

"Peso" = peso relativo dentro de su grupo en el `EventDirector`. Todos los avisos externos se acortan `d/2`.

### Externos

| ID | Evento | Peso / prob. | Aviso | Efecto | Solución | Fuente |
|---|---|---|---|---|---|---|
| E1 | Impacto de escombro | 25 (LEO y Luna) | 4 s; 14 s con `radar_doppler` | Energía 3 200–16 500 J → `DamageMatrix` (60 % `radial`): brecha | Parche (6 s) o cerrar compuerta; piloto puede esquivar con quemado | Iridium–Cosmos |
| E2 | Tormenta solar | 15 + 5·tier | 20 s; +45 s con `entropic_sensor` | `vision`, `map`, `comms` degradados 30–60 s; consolas con controles cruzados | Popa al Sol, apagar aviónica, refugio; `telemetry_strain` inmune | Halloween 2003 |
| E3 | Micrometeorito en radiador | 10 | 4 s | Pierde refrigerante: `temp_norm` +0.02/s | Cerrar válvula (10 s), apagar sistemas, puente con manguera | Soyuz MS-22 |
| E4 | Conjunción solar | ver §4.1 | Anunciada + cuenta de 30 s | Sin Tierra 60–90 s | Paquete de contingencia | Conjunción de Marte |
| E5 | Frío profundo | pasivo si f < 0.3 sin MLI | Indicador térmico | `temp_norm ≤ 0.15`: válvulas congeladas, robots −30 % | Calefactores (cuestan barras), `insulation_mli` | Anexo B §2 |
| E6 | Caída de irradiancia | pasivo | Medidor de barras | Barras solares se apagan con f(r) | RTG, apagar salas | Fact Sheet |
| E7 | Cinturón de radiación | 100 % al cruzar (Júpiter) | Zona visible en el mapa | SEU ×3, desgaste de paneles | Ruta alta (más Δv) o cruce rápido | Juno / Van Allen |
| E8 | Periapsis bajo | por trayectoria | PE en rojo en el mapa | Calentamiento y daño en `top` | Quemado prograde | MCO |
| E9 | Resto a la deriva (bueno) | 8 | Eco de radar 20 s | Pieza o caja capturable | Encuentro + cabrestante o red | TSS-1R (cable) |
| E10 | Polvo en panel / tormenta de polvo | 12 (solo Marte) | 20 s | Solar a 0 en superficie | Limpiar paneles, esperar con batería | Fact Sheet Marte |

### Internos

| ID | Evento | Peso / disparo | Aviso | Efecto | Solución | Fuente |
|---|---|---|---|---|---|---|
| I1 | Incendio | 20, o por `DamageMatrix` | Humo 3 s | Quita barras y daña la sala; salta por ventilación cada 8 s | Extintor (4 s), cortar ventilación, abrir esclusa (apaga en 2 s, vacía la sala) | Mir 1997, Saffire |
| I2 | Vela de oxígeno defectuosa | 4 | Chisporroteo 3 s | Llama 20 s que no se apaga sin aire | Aislar la sala y enfriar | Vela Vika |
| I3 | Brecha lenta | 12 | Silbido + medidor | Presión −2 %/s; sin aire los robots se sobrecalientan | Parche o compuerta | Mir–Spektr |
| I4 | Fuga de propelente | 10 | Charco + olor (icono) | −1 % de Δv por segundo; suelo resbaladizo | Cerrar válvula, trasvasar | Anexo B §4 `bottom` |
| I5 | Pogo en encendido largo | 8 por quemado > 20 s | Sacudida creciente 3 s | Daño en `engines` | Bajar gases, apagar motor central, `damper_cryo_he` | Apollo 6/13 |
| I6 | Propulsor atascado | 6 | Giro creciente | La nave rota: robots y objetos resbalan | Cortar el interruptor del RCS + contragiro del piloto | Gemini 8, Nauka |
| I7 | Saturación de giroscopios | 6 con `cmg_stabilizer` | Medidor al 90 % | Timón bloqueado 4 s | Desaturar con RCS antes | CMG de la ISS |
| I8 | Nodo con unidades erróneas | 5 % de soluciones de Tierra | Ninguno salvo auditoría | Δv ×4.45 o ÷4.45 | Comunicaciones audita (5 s); piloto compara con el mapa | MCO |
| I9 | Cortocircuito | 12 | Luces parpadean 2 s | Pierde 2–3 de 7 barras | Priorizar, cambiar fusible | Apollo 13 |
| I10 | Cascada | toda avería crítica a los 5 s | Temporizador sobre la sala | +1 de severidad o salta a la sala vecina | Atender antes de 5 s | Anexo C §3.2 |

### Gambling

| ID | Evento | Disparo | Resultado | Límite |
|---|---|---|---|---|
| G1 | Botón misterioso | Voluntario, enfriamiento 60 s | d20: 1 purga una carga opcional; 2–4 molestia (luces 10 s, controles invertidos 5 s); 5–12 cosmético; 13–17 repara una avería leve o +1 barra 30 s; 18–19 sella o enfría una sala; 20 una pieza sube a NEW o +300 cr | Cada pulsación extra en la misión resta 1 a la tirada; nunca destruye la nave |
| G2 | Patada de mantenimiento | `B` sobre avería | Arregla `clamp(0.50 + 0.20·luck, 0.3, 0.7)`; empeora `clamp(0.20 − 0.10·luck, 0.10, 0.25)`; resto nada | Enfriamiento 10 s por objeto |
| G3 | Mutador LEGENDARY | Al usar la pieza | Los 4 del Anexo B (p. ej. `gravimetric_injector`: 8 % de inversión en encendido largo) | Aviso de 2 s antes del efecto adverso |
| G4 | Apuesta entre robots | `Y`+`Y` propone | Hasta 50 cr de bolsillo: "quién repara antes", "PE dentro de ±10 km" | Dinero personal cosmético, no de la compañía |
| G5 | Caja sin identificar | Superficie o E9 | Abrir ya: 50 % chatarra (20–60 cr), 25 % pieza USED, 10 % NEW, 5 % LEGENDARY, 10 % batería que estalla (suelta partes) | Venderla cerrada: 80 cr fijos |
| G6 | Cláusula sospechosa | Contrato sospechoso | d6 (fase 1) | Máx. 1 por tablero |
| G7 | Doble o nada | Liquidación | Moneda: se perdona el interés de la misión o se duplica | 1 vez por misión; solo sobre el interés |

**Suerte:** `luck` empieza en 0; +0.10 por amuleto (máx. 3); +0.15 tras misión fallida (se disipa en 2 misiones); −0.10 tras cobrar un contrato sospechoso.

---

## 7. Roadmap

| Hito | Alcance | Depende de | Terminado cuando |
|---|---|---|---|
| **H0 Papel + núcleo** | `docs/PROTOTIPO-PAPEL.md` (reglas imprimibles con d6/d20 y mazos de contratos, piezas y eventos). `game/sim/` con las fórmulas de los anexos, `data/nasa/` y `data/design/`. `tools/balance_montecarlo.gd` | Nada | Tests reproducen los ejemplos numéricos de este plan; 10 000 campañas simuladas dan 35–50 % de victoria; ninguna estrategia única gana > 70 % |
| **H1 Interior jugable** | Navegación cenital local 1–4: Mule Mk-I, robots con 4 partes, 7 barras, eventos E1–E3, I1, I3, I9, I10, G1, G2. Viaje con temporizador, sin mapa | H0 | 4 mandos juegan 10 min a 60 fps; se puede ganar y perder; cada avería es identificable sin texto |
| **H2 Piloto orbital** | Mapa lateral, nodos, quemados, Tierra–Luna con cónicas enlazadas, pantalla partida con H1, retardo `d`, piloto automático | H0, H1 | Un jugador nuevo logra la transferencia lunar en ≤ 3 intentos; el Δv gastado difiere < 5 % del analítico |
| **H3 Vertical slice lunar** | Las 7 fases para la Luna, tablero con 4 contratos, taller con 12 perks, 4 calidades y cajas, despegue con `TakeoffRisk`, aterrizaje retro, superficie con entrega y salvage, liquidación y deuda en bucle | H1, H2 | Una run de solo misiones lunares se juega de principio a fin sin errores en consola; misión de 25–30 min; guardado entre misiones |
| **H4 Alpha** | NEO, Marte (escudo + paracaídas), Júpiter (RTG, cinturón), los 27 eventos, conjunción, bots para 1–2 jugadores, meta-progresión, dirección de arte aplicada. **H4b:** servidor dedicado *headless* + CAPCOM | H3 (H4b además: detalles de tu servidor) | Run completa ganable y perdible en cada tamaño de grupo; H4b: 4 clientes con 150 ms de latencia sin desincronización orbital |

---

## 8. Riesgos y mitigación

| Riesgo | Tipo | Mitigación |
|---|---|---|
| Alcance: 7 fases con dos vistas | Producción | Superficie, ascenso y descenso comparten un solo controlador lateral; nada de contenido de Marte o Júpiter antes de cerrar H3 |
| El piloto se aburre o se frustra frente al caos del resto | Diseño | Ventanas de maniobra cortas; en travesía el piloto baja a reparar; piloto automático con error |
| Legibilidad en pantalla compartida con 4 robots y 3 averías | Diseño | Color e icono fijos por jugador, aro en el suelo, flecha en el borde si sale de cuadro; un icono y un sonido únicos por avería; máx. 3 simultáneas |
| La suerte anula la habilidad | Diseño | Ninguna tirada causa derrota directa; suerte compensatoria; toda apuesta es voluntaria y muestra su probabilidad |
| Estética de casino sube la clasificación por edad (PEGI trata el juego de azar simulado como 18) | Comercial | Dados, cajas y botones en lugar de tragaperras, ruletas o cartas; decisión tuya en §9 |
| Economía degenerada (bola de nieve o espiral de muerte) | Diseño | Monte Carlo en H0 antes de escribir vistas; interés y pagos en `economy.json` |
| Pasar de local a online obliga a reescribir | Técnico | Desde H0: simulación sin nodos, comandos como única entrada, RNG con semilla, tick fijo; un test ejecuta la simulación sin escena |
| Simulación orbital inestable o cara en GDScript | Técnico | Propagación analítica, no integración numérica; solo se integra durante el quemado |
| API de Godot 4.7 distinta de la que recuerdo | Técnico | Verificar cada API dudosa con el addon `godot_ai` (`api_manage`) y ejecutar tras cada sistema |
| Datos "NASA" mal transcritos | Contenido | Cada entrada JSON lleva `source`; solo se usan cifras de los anexos; lo demás se etiqueta `design` |

---

## 9. Preguntas abiertas (las decides tú; no bloquean H0–H1)

1. **"Local"** lo interpreté como una sola pantalla con mandos. Si querías LAN (una pantalla por jugador), cambia el reparto de vistas y adelanta CAPCOM.
2. **Aire = refrigerante de robots** (contradicción 3): ¿aceptas esta reinterpretación del soporte vital?
3. **Dirección de arte:** elige una de las tres de abajo. Hasta entonces uso formas planas de A como marcadores.
4. **Imaginería de azar:** ¿dados y cajas (recomendado) o casino explícito?
5. **Final de run:** ¿deuda = 0 gana (recomendado) o modo sin fin con deuda que se refinancia?
6. **Servidor propio:** sistema operativo, ¿expuesto por UDP?, jugadores concurrentes esperados. Solo hace falta para H4b.
7. **Paleta "NASAPunk + Rhine Lab":** ¿tienes el documento original o la defino yo?
8. **Idioma:** ¿solo español o ES/EN desde el principio?
9. **Git:** la carpeta no es un repositorio; ¿lo inicializo?

**Decisiones aplicadas para H4 (valores recomendados, revisables):** (1) una sola pantalla con mandos; (2) sí, aire = refrigerante; (3) dirección A; (4) dados y cajas; (5) deuda = 0 gana; (6) pendiente, H4b no se construye todavía; (7) se define aquí con la paleta A (`game/ui/palette.gd`); (8) solo español; (9) el proyecto ya vive en `github.com/AXLAAF/Game-nasa`.

### Direcciones de arte (todas: rejilla 32 px, luz a 315°, bisel inferior 3–4 px, texto ≥ 12 px sans y 11 px mono tabular, sin JetBrains Mono; propongo IBM Plex Sans / Plex Mono)

| | A. Vector plano de chatarra | B. Pixel art NASAPunk | C. Manual técnico recortado |
|---|---|---|---|
| Referencias | Overcooked, Lovers in a Dangerous Spacetime | FTL, Starbound | Manuales de la era Apolo, planos cianotipo, pegatinas |
| Paleta | Fondo `#10131C`, casco gris cálido, jugadores `#FF7A1A` `#19C3E6` `#E63E8C` `#A6E22E`; rojo, blanco azulado y amarillo reservados a fuego, brecha y electricidad | 32 colores, casco desaturado, mismos 4 colores de jugador con contorno de 1 px | Nave en línea cian sobre azul plano; robots y averías como recortes a todo color |
| Legibilidad en caos | La más alta: siluetas grandes, sin textura | Media-alta: exige contornos y disciplina de contraste | Alta: fondo monocromo, todo lo que importa tiene color |
| Costo | Bajo (formas + huesos 2D) | Medio-alto (animación cuadro a cuadro) | Bajo-medio (líneas procedurales + pocas ilustraciones) |

Recomendación: **A** para H1–H3; decidir entre A y C antes de H4.

---

## Ejecución tras aprobar

Orden de trabajo; cada hito se verifica antes de pasar al siguiente y no se detiene salvo bloqueo real.

1. **Documentación.** Guardar este plan como `docs/PLAN-DISENO.md`; transcribir los anexos a `docs/MECANICAS-REFERENCIA.md` (B) e `docs/INVESTIGACION-TECNICA.md` (C); crear `docs/ANEXO-A-RECONSTRUIDO.md`.
2. **Proyecto.** En `project.godot`: renderer Compatibility, viewport 1920×1080, mapa de entrada por dispositivo, escena principal. Estructura:
   ```
   game/sim/      orbital_math, takeoff_risk, damage_matrix, thermal, reactor_power, room_hazards,
                  ship_model, robot_model, shop_roller, event_director, comms_link, landing,
                  economy, mission_evaluator, sim_rng, sim_world, nasa_data_loader   (RefCounted, sin nodos)
   game/session/  session, local_session, player_command
   game/input/    player_input
   game/phases/   phase_machine + una escena por fase
   game/view/     interior/, orbital/, lateral/        game/ui/
   data/nasa/     planetary_catalog, debris_leo_catalog, solar_events_scenarios, neo_curated_missions (.json)
   data/design/   parts, modules, events, contracts, economy (.json)
   tests/         suites McpTestSuite        tools/  balance_montecarlo.gd
   ```
3. **H0**, luego **H1**, **H2**, **H3** según §7. H4 después de tus respuestas a §9.

## Verificación

- **Unidad:** suites `McpTestSuite` en `res://tests/` (base ya incluida en `addons/godot_ai/testing/test_suite.gd`), ejecutadas con la herramienta `test_run` del addon. Casos mínimos: Tsiolkovsky con los casos nulos del Anexo B; `M_rated` = 34.3 t para 420 kN; `P_ign` ≈ 0.19 (SCRAP) y ≈ 0.03 (NEW); `f(5.2)` ≈ 0.037; `d` = 1.4 / 12.9 / 20.0 s; umbrales de `DamageMatrix` en 2 000 / 8 000 / 20 000 J; `temp_norm` en 0.85 y 0.15; pesos de calidad con `luck` en −0.5, 0 y 1.0.
- **Balance:** `tools/balance_montecarlo.gd` en modo *headless*; informe de tasa de victoria y distribución de deuda.
- **Determinismo:** misma semilla + mismos comandos = mismo estado final (condición para el online).
- **Jugable:** `project_run` del addon, capturas con `editor_screenshot` y lectura de `logs_read` sin errores; prueba manual de 10 min con 1 y con 4 dispositivos al cerrar H1 y de misión lunar completa al cerrar H3.
