# Documentacion de Mecanicas de Referencia (Rescatadas del prototipo v1)

Este documento define las **especificaciones matematicas, matriz de danos y catalogo de tecnologias NASA** que gobiernan la simulacion de *Margin Zero: Deuda Orbital* (nave `MZ-1 LIBERTY`, programa `LIBERTY-1` a `LIBERTY-N`) en Godot 4.7.

---

## 1. Propulsión y Fisica Orbital

- **Ecuacion del Cohete de Tsiolkovsky:**
  $$\Delta v = I_{sp} \cdot g_0 \cdot \ln\left(\frac{m_{wet}}{m_{dry}}\right), \quad g_0 = 9.80665\text{ m/s}^2$$
  Si $I_{sp} \le 0$, $m_{dry} \le 0$ o $m_{wet} \le m_{dry}$, entonces $\Delta v = 0$.
- **Relacion Empuje-Peso (TWR):**
  $$\text{TWR} = \frac{T}{m_{total} \cdot g}$$
- **Velocidad Orbital Circular:**
  $$v_{orb} = \sqrt{\frac{g \cdot R^2}{R + h}}$$
- **Transferencia de Hohmann ($\Delta v_1, \Delta v_2$):**
  $$a = \frac{r_1 + r_2}{2}, \quad \Delta v_1 = \left|\sqrt{\mu \left(\frac{2}{r_1} - \frac{1}{a}\right)} - \sqrt{\frac{\mu}{r_1}}\right|, \quad \Delta v_2 = \left|\sqrt{\frac{\mu}{r_2}} - \sqrt{\mu \left(\frac{2}{r_2} - \frac{1}{a}\right)}\right|$$
- **Densidad Atmosferica Exponencial y Presion Dinamica (Max-Q):**
  $$\rho(h) = (1.225 \cdot P_{bar}) \cdot e^{-h / H_{km}}, \quad q = \frac{1}{2} \rho v^2$$
  En la Luna ($P_{bar} = 0$), $\rho = 0$. En Marte ($P_{bar} \approx 0.0064$, $H \approx 11.1\text{ km}$), exige combinacion de escudo ablativo y paracaidas para frenado.

---

## 2. Irradiancia Solar y Balance Termico

- **Ley del Inverso del Cuadrado:**
  $$f(r) = \frac{1}{\max(r_{AU}, 0.2)^2}, \quad S(r) = 1361.0 \cdot f(r)\text{ W/m}^2$$
- **Generacion Electrica (Solar vs RTG):**
  $$P_{gen} = P_{solar\_base} \cdot \min(f(r), 2.5) + P_{rtg\_base}$$
  A 5.20 AU (Jupiter), $f(r) \approx 0.037$ (3.7% respecto a la Tierra), por lo que los paneles solares colapsan y obligan a usar RTG.
- **Temperatura Normalizada (`temp_norm` en `[0.0, 1.2]`):**
  - Termo caliente: $\max(f - 1, 0) \cdot \frac{0.14}{1 + \text{cooling}} \cdot (1 - 0.7 \cdot \text{heat\_resist})$.
  - Termo frio: $\text{clamp}(1 - f, 0, 1) \cdot 0.5 \cdot (1 - \text{cold\_resist})$.
  - `temp_norm = clamp(0.5 + hot_term - cold_term, 0.0, 1.2)`.
  - Umbrales: `overheated` si $\ge 0.85$; `frozen` si $\le 0.15$.

---

## 3. Riesgo de Despegue (`TakeoffRisk`)

Modelo para la Fase 2 (despegue con alerta critica de sobrecarga y opcion de *jettison*):

- **Masa Nominal Segura ($M_{rated}$):**
  $$M_{rated} = \frac{T_{total}}{1.25 \cdot 9.80665}$$
- **Sobrecarga ($\Omega$):**
  $$\Omega = \max\left(0, \frac{m_{total} - M_{rated}}{M_{rated}}\right)$$
- **Salud Estructural ($H_{struct}$) y Fiabilidad Propulsora ($R_{prop}$):**
  - Cada pieza aporta $\text{clamp}(\text{condition} \cdot (1 - \text{wear}), 0, 1)$ (0 si esta rota) al promedio $H_{struct}$.
  - Cada motor/booster aporta fallo $\text{fail} = \text{clamp}(((1 - \text{cond}) \cdot 0.55 + \text{wear} \cdot 0.3) \cdot \text{fragility}, 0, 0.95)$; $R_{prop} = \prod (1 - \text{fail})$ acotado en $[0.05, 1.0]$.
- **Probabilidad en Ignicion ($P_{ign}$):**
  $$P_{ign} = 0.005 + 0.18(1 - H_{struct})^2 + 0.28(1 - R_{prop}) + 0.08 \cdot \tau_{eff}^{1.6}$$
  donde $\tau_{eff} = 0$ si $|\text{timing\_error}| \le 0.15\text{ s}$.
- **Probabilidad en Ascenso Max-Q ($P_{ascent}$):**
  $$\sigma_q = \max\left(0, \frac{q_{max} - 28000}{28000}\right)$$
  $$P_{ascent} = 0.42\,\Omega^2 + 0.35\,\sigma_q(1 - H_{struct}) + 0.15\,\text{asym}^2$$
- **Probabilidad Combinada Acotada:**
  $$P_{explosion} = \text{clamp}\big(1 - (1 - P_{ign})(1 - P_{ascent}),\; 0.005,\; 0.95\big)$$
- **Mitigacion en Vuelo:** Durante los 4 s de alerta roja en ascenso, activar **Descarte de Carga (`jettison_cargo`)** suelta la masa auxiliar para reducir $\Omega$ al instante a cambio de parte de la recompensa opcional.

---

## 4. Matriz de Daño por 4 Cuadrantes (`DamageMatrix`)

Mapea la energia de impacto ($E$ en Joules) a severidad y a canales funcionales de las salas FTL:

- **Umbrales de Severidad:**
  - `leve`: $E < 2000\text{ J}$
  - `grave`: $2000 \le E < 8000\text{ J}$
  - `critica`: $8000 \le E < 20000\text{ J}$
  - `catastrofica`: $E \ge 20000\text{ J}$

| Cuadrante | Salas asociadas | Canales degradados (leve -> catastrofica) | Peligro dominante |
| :--- | :--- | :--- | :--- |
| **`top` (Proa)** | `helm`, `sensors` | `vision` (-0.25 a -1.0), `map` (0 a -1.0), `comms` (-0.10 a -0.80), `audio` (-0.40 cat.) | Incendio (15–60%) + Brecha (0–55%) + Explosion si catastrofica |
| **`middle` (Centro)** | `reactor`, `life_support` | `light` (-0.30 a -1.0), `mobility` (-0.10 a -0.80), `comms` (-0.20 grave) | Incendio (20–75%) + Brecha (0–50%) + Fuga en critica/catastrofica (0.15–0.40) |
| **`bottom` (Popa)** | `engines` | `thrust` (-0.15 a -1.0), `mobility` (-0.05 a -0.60) | Fuga de propelente (0.25 a 1.0) + Incendio (25–85%) + Brecha en critica (35%) |
| **`radial` (Flancos)** | `science_bay` | `audio` (-0.25 a -1.0), `comms` (-0.30 a -1.0), `light` (0 a -0.80), `mobility` (0 a -0.40) | Brecha al vacio dominante (20–100%) |

---

## 5. Catalogo de Tecnologias NASA y Mutadores Anomalos

### 5.1 Los 12 Perks Historicos NASA (con contrapartida real)

| ID | Nombre | Cat. | Masa (t) | Costo | Ventaja principal | Contrapartida real |
| :--- | :--- | :--- | :---: | :---: | :--- | :--- |
| `shield_hrsi` | Losetas Ceramicas HRSI | `shield` | 1.8 | 320 | Absorcion termica 0.85, enfriamiento pasivo 0.40 | Alta fragilidad mecanica (0.65) |
| `shield_pica` | Escudo Ablativo PICA-X | `shield` | 1.2 | 280 | Proteccion termica 0.95, inmune a vibracion | Desgaste irreversible (0.28 por calor, no renovable) |
| `nozzle_niobium` | Tobera C-103 Niobio | `propulsion` | 0.9 | 450 | +38 s $I_{sp}$ en vacio, +18% empuje vacio | Penalidad de enfriamiento atmo (0.35), desgaste x2.2 |
| `staged_preburner` | Turbobomba Ciclo Escalonado | `propulsion` | 2.4 | 600 | +28% empuje en despegue, +22% TWR | +40% riesgo de ignicion, desgaste por pico de presion (0.20) |
| `telemetry_strain` | Telemetria Analogica Galgas | `avionics` | 0.5 | 140 | 100% inmunidad EMP y radiacion cosmica | Error de lectura analoga (6%) |
| `damper_cryo_he` | Amortiguador Criogenico Pogo | `structure` | 1.6 | 260 | -70% estres max-Q y vibracion acustica | Drena 0.12 kW |
| `insulation_mli` | Manta Multicapa Kapton | `thermal` | 0.2 | 180 | 90% aislamiento criogenico, evita congelacion | Se desgarra si $q > 12000\text{ Pa}$ |
| `winch_uhmwpe` | Cabrestante Polimero UHMWPE | `salvage` | 0.7 | 290 | Traccion 55 kN, +40% velocidad, alcance 120 m | Ablandamiento termico a partir de temp 0.70 |
| `net_supercond` | Red Colectora Superconductora | `salvage` | 1.4 | 480 | Captura magnetica pasiva en 35 m | Drena 0.40 bateria/s y ruido de audio (0.25) |
| `radar_doppler` | Radar Doppler Pulso Ku | `sensors` | 0.6 | 310 | 14 s de aviso temprano contra basura espacial | Drena 0.08 energia/s, depende de proa intacta |
| `cmg_stabilizer` | Giroscopio Momento Inercial | `control` | 1.5 | 390 | +45% giro sin consumo de propelente RCS | Saturacion / *gimbal lock* de 4.0 s |
| `radiator_ammonia` | Radiador Plegable Amoniaco | `thermal` | 1.1 | 340 | Rechaza 0.18 calor/s | Fragilidad ante impacto 1.0, pierde refrigerante al romperse |

### 5.2 Calidades de Piezas en Tienda ("Agencia en Quiebra")

Pesos base modulados por suerte `luck` en `[-0.5, 1.0]`:
- **`SCRAP` (Chatarra):** peso `clamp(0.38 - luck*0.15, 0.05, 0.55)`, condicion `[0.30, 0.65]`, multiplicador `0.85`.
- **`USED` (Usada):** peso `0.34`, condicion `[0.60, 0.85]`, multiplicador `1.00`.
- **`NEW` (Nueva):** peso `clamp(0.18 + luck*0.10, 0.10, 0.40)`, condicion `[0.86, 0.98]`, multiplicador `1.05`.
- **`LEGENDARY` (Anomala):** peso `clamp(0.10 + luck*0.05, 0.05, 0.25)`, condicion `[0.95, 1.00]`, multiplicador `1.40` + mutador aleatorio:
  1. `gravimetric_injector` (`engine`): +65% empuje, -30% consumo | 8% probabilidad de inversion transitoria en encendido largo.
  2. `crystalline_alloy` (`structure`): autoreparacion 0.04/min | fragilidad x3.0 bajo radiacion cosmica.
  3. `entropic_sensor` (`sensors`): revela POI + 45 s aviso solar | drena 0.05 energia/s + estatica de audio constante.
  4. `quantum_tether` (`winch`): resistencia a ruptura infinita | transferencia total de momento si la masa capturada supera la nave.

---

## 6. Reglas de Escala Visual 2.5D (`assets/`)

- **Rejilla cenital estandar:** `1 celda interior = 32 x 32 px` (`1.0 m`), luz clave fija a 315 grados, biselado inferior 3-4 px y contorno unico por `CanvasGroup`.
- **Paleta y tipografia:** Tokens NASAPunk + *Rhine Lab* definidos en `docs/DISEÑO-UI-NAVES-25D.md`, minimo legible `12 px` en sans-serif (`11 px` monospace tabular para cifras) y prohibicion total de `JetBrains Mono`.
