# 04. Guion de Misiones, Contratos NASA, Economía de Deuda y *Debrief Causal*

**Objeto:** Detallar los 4 contratos basados en `data/nasa/*.json`, la estructura de tramos/nodos, la economía de agencia en quiebra (progresión `LVL 1..5`) y las reglas exactas del reporte final en `MissionEvaluator`.

## 1. Los 4 Contratos Oficiales — Programa `BALLAST-1` a `BALLAST-4` (`planetary_catalog.json` + `neo_curated_missions.json`)

| Vuelo | Contrato (`id`) | Dificultad | Parámetros NASA embebidos | Requisito crítico en Dique Seco | Riesgos dominantes en vuelo | Recompensa base + meta Ciencia |
| :---: | :--- | :---: | :--- | :--- | :--- | :--- |
| **`BALLAST-1`** | **Luna — Misión Artemis Relay** (`moon`) | `1` | Dist. `384 400 km`, $g = 1.6\text{ m/s}^2$, $P = 0.0\text{ bar}$, $\Delta v = 4100\text{ m/s}$, DSN $\text{RTLT} = 2.56\text{ s}$, flujo solar `100%` | Paneles solares suficientes; **sin escudo térmico ni paracaídas** (peso muerto si los instalas) | Detritos LEO (`leo_iss_420`, $7.66\text{ km/s}$), fulguración moderada `M5.4` y descenso 100% propulsado | `$1800` + `120` Ciencia (`+$5/pt` transmitido) |
| **`BALLAST-2`** | **LEO / NEO — Desvío DART, 2024 PDC25 & Limpieza Kessler** (`neo_curated_missions`) | `2–3` | Asteroides `101955 Bennu`, `65803 Didymos`, `433 Eros`, `16 Psyche` + cinturones `790 km` y `850 km` (`debris_leo_catalog.json`) | **Radar Doppler Ku**, **Brazo / Red Colectora**, escudo Whipple lateral en góndolas | Enjambres hiperveloces `11.7–14.2 km/s` (`Cosmos-Iridium`, `Fengyun-1C`) y capturas con transferencia de momento | `$2800–$5400` + bonos NEO (`120–260` Ciencia) |
| **`BALLAST-3`** | **Marte — Mars Sample Return** (`mars`) | `2` | $1.52\text{ AU}$, flujo solar **`~43.3%`**, $g = 3.7\text{ m/s}^2$, $P = 0.0064\text{ bar}$, $H = 11.1\text{ km}$, $\Delta v = 6300\text{ m/s}$, DSN $\text{RTLT} = 1501\text{ s}$ | Obligatorio **Escudo PICA / HRSI** + **Paracaídas**; paneles ampliados o RTG de apoyo | Corredor atmosférico estrecho (`[-5.2, -3.8] deg`), evento `donki_sep_2017_x9` (`X9.3`), retardo de señal | `$3400` + `260` Ciencia |
| **`BALLAST-4`** | **Júpiter / Europa — Sonda Clipper** (`jupiter`) | `3` | $5.20\text{ AU}$, flujo solar **`~3.7%`**, $g = 23.1\text{ m/s}^2$, $\Delta v = 10800\text{ m/s}$, `radiation_hazard = true`, DSN $\text{RTLT} = 5193\text{ s}$ | Obligatorio **MMRTG** (paneles solares fallan por flujo `3.7%`) + **Blindaje anti-radiación** | Reinicios SEU constantes (`donki_halloween_2003` / cinturón joviano), fuga térmica si falla radiador $\text{NH}_3$ | `$6200` + `480` Ciencia |

## 2. Flujo Tramo por Tramo de una Partida (4 a 6 Minutos)

1. **Briefing en Mapa Astrofísico (`45 s`):**
   - El equipo lee las 3 cifras críticas del contrato (irradiancia solar `%`, atmósfera `bar`, `RTLT`) y elige destino.
2. **Dique Seco Modular (`45–60 s`):**
   - Compran o actualizan módulos de `MZ-1 BALLAST` (chasis `Orbital Mule Mk-I`, `LVL 1..5`) con su saldo disponible y revisan las 3 barras: **$\Delta v$**, **Energía en Destino** y **Riesgo de Despegue**.
3. **Despegue Max-Q (`15 s`):**
   - Mini-secuencia de ignición; si la sobrecarga $\Omega$ supera margen nominal, dispara alerta roja de **4 s** para ejecutar **`jettison_cargo`** (soltar carga auxiliar) o abortar con Torre de Escape (`LES`).
4. **Tramo 1 — Órbita Terrestre / Cruce de Detritos (`50–60 s`):**
   - Generado con `debris_leo_catalog.json`. Radar canta carriles con 10–14 s de margen; primera maniobra *Prograde* en nodo $\Delta v$.
5. **Nodo de Ruta Intermedio (`12 s` de respiro sin combate):**
   - Única ventana natural de decisión táctica: elegir **Ruta Directa** (menor gasto $\Delta v$, cruza nube Kessler o tormenta solar prevista) vs **Ruta de Desvío NEO** (mayor gasto $\Delta v$, permite muestrear `101955 Bennu` o `433 Eros` con el brazo dorsal).
6. **Tramo 2 — Crucero Profundo / Evento DONKI (`50–60 s`):**
   - Se activa evento de `solar_events_scenarios.json`: cuenta regresiva visual de CME (`10–14 s`); el equipo decide cortar barras de `sensors` (*Storm Safe*) o confiar en `telemetry_strain` y absorber el golpe en `middle`.
7. **Tramo 3 — Inserción Orbital / Corredor Atmosférico (`45–60 s`):**
   - Quema *Retrograde* sobre `PE` con NavBall 2.5D y descarga de paquetes de Ciencia durante ventana DSN antes de perder línea de vista.

## 3. Economía de "Agencia en Quiebra" y Bucle de Campaña

- **Saldo inicial:** `$2200` créditos y nave base totalmente en `LVL 1 (Chatarra)`.
- **Ingresos:** `net_credits = base_payout + science_transmitted * 5 - repair_cost` (`MissionEvaluator.build_report`).
- **Deuda / Penalización por fracaso:** Si la nave explota o agota el casco, solo se recupera el porcentaje protegido por la Torre de Escape (`LES`), descontando costo de reconstrucción sobre el saldo; si el saldo cae bajo `$400`, el banco espacial otorga un **Préstamo Predatorio de Rescate (`+$1000`, interés del 20% descontado en la siguiente victoria)**.
- **Contador correlativo de vuelos (`BALLAST-N`):** Cada lanzamiento de `MZ-1 BALLAST` consume un número de vuelo (`BALLAST-1 .. BALLAST-4` en los contratos iniciales; `BALLAST-5 .. BALLAST-N` cada vez que se reintenta una misión tras pérdida del casco o aborto en Max-Q), dejando registro histórico de cuántos intentos costó liquidar la deuda.
- **Progresión duradera (`LVL 1 -> LVL 5 MAX`):** Las mejoras desbloqueadas sobre el casco `MZ-1 BALLAST` (`Orbital Mule Mk-I`) permanecen guardadas en el hangar entre misiones para que en 3–4 contratos los jugadores pasen de chatarra oxidada a nave espacial grado NASA.

## 4. Auditoría Causal Final (`MissionEvaluator`)

La pantalla final no muestra una tabla plana de puntos: presenta dos columnas contrastadas generadas en `game/sim/mission_evaluator.gd`:

- **Lo que hiciste bien (`good_items`):**
  - `POWER_BUDGET_OK`: Balance energético suficiente en destino según $1/r^2$.
  - `EDL_SHIELD_OK`: Escudo térmico equipado para cuerpo con atmósfera.
  - `RAD_SHIELD_OK`: Blindaje activo ante radiación joviana.
  - `RAMP_MASS_SAFE`: Masa en rampa dentro de margen estructural ($\Omega \le 1\%$).
  - Eventos en vuelo agregados dinámicamente: detección anticipada de basura por Radar, extinción de fuego por esclusa sin bajas, transmisión del 100% de Ciencia por DSN.
- **Lo que salió mal (`bad_items`):**
  - `SOLAR_AT_JUPITER`: Solo paneles solares a $\ge 3.0\text{ AU}$.
  - `NO_HEATSHIELD` / `NO_PARACHUTE`: Falta de equipo EDL en Marte.
  - `NO_RAD_SHIELD`: Exposición directa en entorno hostil.
  - `RAMP_OVERLOAD`: Sobrecarga $>15\%$ sobre $M_{rated}$.
  - `CHEAP_SCRAP_RISK`: $\ge 2$ módulos `SCRAP` elevando incendios y fugas.
- **Calificación final:** Rango **`S / A / B / C / F`** derivado de `raw_score` (`88 / 72 / 55 / <55`), más listado explícito de URLs NASA/JPL/DONKI/CelesTrak empleadas en esa misión.
