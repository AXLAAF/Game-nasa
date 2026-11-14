# Chuleta de ingeniería de misiones `[real]`

Valores aproximados para diseñar y explicar. `~` = orden de magnitud; los marcados *verificar*
cambian con el tiempo (precios, capacidades) y hay que confirmarlos antes de presentarlos.

## Propulsión y delta-v

- **Tsiolkovsky**: `Δv = Isp · g0 · ln(m0 / mf)`, `g0 = 9.81 m/s²`. Cada m/s extra cuesta
  exponencialmente más combustible: por eso se usan etapas.
- **Isp típico**: sólido ~250–290 s; RP-1/LOX ~280–350 s; metano/LOX ~330–380 s;
  LH2/LOX ~420–465 s; hidracina monopropelente ~220–235 s; iónico ~1500–4000 s (empuje mínimo).
- **TWR** = empuje / (masa · g local). Despegue necesita TWR > 1 (en la práctica ~1.2–1.5).
  En el vacío basta TWR bajo, pero los encendidos son más largos.
- **Pérdidas de ascenso** (gravedad + arrastre + direccionamiento): ~1.5–2 km/s en la Tierra.
- **Mapa de Δv** (km/s, aprox.):
  | Tramo | Δv |
  |---|---|
  | Superficie Tierra → LEO | ~9.3–9.5 |
  | LEO → GTO | ~2.4 |
  | GTO → GEO | ~1.5–1.8 |
  | LEO → inyección translunar (TLI) | ~3.1 |
  | Captura en órbita lunar baja | ~0.8–0.9 |
  | Órbita lunar baja → superficie | ~1.7–1.9 |
  | LEO → transferencia a Marte | ~3.6 |
  | Captura en Marte | ~0.9–2 (menos con aerofrenado) |
- **Vis-viva**: `v² = μ (2/r − 1/a)`. **Periodo**: `T = 2π √(a³/μ)`.
  **Escape**: `v_esc = √(2μ/r)` (Tierra 11.2 km/s). μ Tierra = 3.986e14 m³/s².
- **Hohmann**: dos encendidos, el más eficiente entre órbitas circulares coplanarias; tarda medio
  periodo de la elipse de transferencia (Tierra → Marte ~8–9 meses, ventana cada ~26 meses).
- Cambiar de plano orbital es carísimo: `Δv = 2 v sin(Δi/2)` (30° en LEO ≈ 4 km/s).

## Órbitas

| Órbita | Altitud / dato | Bueno para | Pega |
|---|---|---|---|
| LEO | 200–2000 km, ~90–100 min | Observación de alta resolución, latencia baja, barato de alcanzar | Arrastre, eclipses frecuentes, pases cortos sobre estación |
| SSO (heliosíncrona) | ~600–800 km, i ≈ 97–98° | Misma hora solar en cada pasada: ideal para imágenes comparables | Algo más de Δv que LEO ecuatorial |
| MEO | ~20 200 km (GPS), 12 h | Navegación, cobertura amplia | Cinturones de radiación |
| GEO | 35 786 km, 23 h 56 min | Fija sobre un punto: telecom, meteo continua | Mucho Δv, resolución baja, latencia ~0.25 s |
| Molniya / HEO | i = 63.4°, ~12 h | Latitudes altas | Pasa por los cinturones de radiación |
| L1 / L2 Sol-Tierra | ~1.5 millones km | Vigilancia solar (L1), telescopios fríos y estables (L2, JWST) | Enlace lejano, mantenimiento de órbita |
| Lunar / interplanetaria | — | Ciencia de otros cuerpos | Δv alto, enlace lento, entorno térmico extremo |

- **Eclipse en LEO**: hasta ~35 min por órbita (~35–40 % del tiempo): las baterías mandan.
- **Vida por arrastre** (muy dependiente de la actividad solar y del área/masa):
  300 km semanas–meses; 400 km ~1–2 años sin reimpulso (la ISS reimpulsa); 500 km ~años;
  600 km ~décadas; > 800 km siglos (basura espacial persistente).
- **Revisita vs resolución**: más alto = más cobertura pero menos detalle (resolución ∝ altitud / apertura).

## Lanzadores *(verificar)*

| Vehículo | LEO | GTO | Precio aprox. |
|---|---|---|---|
| Rocket Lab Electron | ~0.3 t | — | ~7–8 M$ |
| Falcon 9 (reutilizado) | ~17 t (~22.8 t desechable) | ~5.5 t (~8.3 desechable) | ~70 M$ |
| Falcon Heavy | ~64 t desechable | ~27 t | ~100–150 M$ |
| Vulcan Centaur (VC6) | ~27 t | ~14 t | ~100+ M$ |
| SLS Block 1 | ~95 t | >27 t a TLI | ~2 000+ M$ |

La capacidad cae mucho con órbitas más energéticas: comprobar siempre masa de la nave ≤ capacidad
del lanzador **para esa órbita**, con margen.

## Energía

- **Constante solar** 1361 W/m² a 1 UA; cae con `1/r²`: Marte (1.52 UA) ~43 %, Júpiter (5.2 UA) ~3.7 %.
  Juno funciona con paneles en Júpiter gracias a ~60 m² de área.
- Células de triple unión ~28–32 % de eficiencia; degradación ~0.5–3 %/año según radiación.
  Paneles demasiado cerca del Sol se sobrecalientan y rinden menos.
- **RTG** (MMRTG de Curiosity/Perseverance): ~110 W eléctricos al inicio, ~45 kg, ~2 kW de calor
  (útil para calentar la nave), pierde unos pocos % al año. Caro y de suministro limitado (plutonio-238).
- **Baterías** Li-ion: ~100–200 Wh/kg. Dimensionar: `E = P_eclipse · t_eclipse / (DoD · eficiencia)`;
  en LEO se limita la profundidad de descarga (~20–40 %) porque hay miles de ciclos.
- Potencias típicas: CubeSat 5–50 W; observación terrestre ~0.5–2 kW; satélite telecom GEO 10–20 kW.

## Térmico

- Equilibrio radiativo: `T = ( α · S · A_abs / (ε · σ · A_rad) )^(1/4)`, σ = 5.67e-8 W/m²K⁴.
  α = absortividad solar, ε = emisividad. Pintura blanca: α bajo, ε alto (fría); oro/MLI: lo contrario.
- Herramientas: MLI (manta multicapa) para conservar calor, radiadores para expulsarlo,
  calentadores eléctricos (cuestan potencia), heat pipes, RTG como fuente de calor.
- Rangos típicos: electrónica ~−20…+50 °C; baterías ~0…+30 °C (las más exigentes);
  la hidracina se congela a ~2 °C.
- Reentrada: el escudo ablativo se consume para llevarse el calor; entrar demasiado plano rebota,
  demasiado empinado supera el flujo térmico o la carga G admisible.

## Comunicaciones y datos

- **Ecuación de enlace (Friis)**: `Pr = Pt · Gt · Gr · (λ / 4πd)²`. La tasa de datos es
  proporcional a `Pr`: doble distancia → ¼ de tasa. Más ganancia = antena más grande o banda más alta.
- Bandas: S (robusta, lenta), X (estándar espacio profundo), Ka (mucha tasa, sensible a la lluvia).
- Ejemplos: LEO en banda X ~100–1000 Mbps durante el pase; MRO en Marte hasta ~6 Mbps;
  New Horizons en Plutón ~1–2 kbps; Voyager ~160 bps.
- **Deep Space Network**: Goldstone, Madrid y Canberra (separadas ~120°), antenas de 34 m y 70 m;
  tiempo de antena escaso y compartido entre misiones.
- Pase LEO sobre una estación: ~5–15 min, pocos pases al día por estación.
  `Volumen descargable = tasa · minutos de contacto`. Si los instrumentos generan más, se pierde ciencia
  (memoria a bordo llena).
- Retardo de la luz: Luna ~1.3 s; Marte ~3–22 min (no se puede pilotar en directo: autonomía).

## Presupuesto de masa y márgenes

- Fracción típica de masa seca: carga útil ~15–40 %, estructura ~15–25 %, potencia ~15–30 %,
  propulsión seca ~5–10 %, ADCS ~5–8 %, térmico ~3–5 %, comunicaciones ~3–6 %, ordenador ~3–5 %.
- Márgenes de contingencia: ~25–30 % en fase conceptual, bajando hacia ~0 al lanzar.
  Lo mismo para potencia. Diseño sin margen = la masa siempre crece y la misión no cierra.

## Coste, tiempo y riesgo

- Escala NASA aprox. *(verificar topes actuales)*: CubeSat ~1–10 M$; Discovery ~500 M$;
  New Frontiers ~900 M$; Flagship 2–5+ G$ (JWST ~10 G$). Las operaciones cuestan cada año que la
  misión sigue viva.
- **Ciclo de vida NASA**: Pre-A (conceptos), A (concepto y tecnología), B (diseño preliminar),
  C (diseño final y fabricación), D (integración, pruebas y lanzamiento), E (operaciones), F (cierre).
  Revisiones: MCR, SRR, MDR, PDR, CDR, SIR, ORR, FRR.
- **TRL 1–9**: madurez tecnológica. Tecnología con TRL bajo = barata en masa o capacidad pero con
  riesgo de retrasos y sobrecoste. Regla habitual: TRL ≥ 6 en PDR.
- **Fiabilidad**: en serie `R = R1·R2·…` (dos piezas al 90 % = 81 %); redundancia en paralelo
  `R = 1 − (1−R1)(1−R2)` (dos al 90 % = 99 %, pero el doble de masa). Curva de bañera: fallos al
  principio (mortalidad infantil), meseta, desgaste al final. Evitar puntos únicos de fallo.
- **Matriz de trazabilidad científica (STM)**: objetivo científico → medida física → requisito del
  instrumento → requisito de misión (órbita, vida útil, apuntado, datos). Es el hilo para que el
  jugador "defina el objetivo antes de la nave".

## Instrumentos típicos *(rangos amplios)*

| Instrumento | Masa | Potencia | Datos | Mide |
|---|---|---|---|---|
| Cámara multiespectral | ~5–50 kg | ~10–50 W | Alto | Superficie, color, cambios |
| Espectrómetro | ~5–30 kg | ~10–40 W | Medio–alto | Composición química/mineral |
| Radar de apertura sintética | ~100–500+ kg | ~0.5–2 kW pico | Muy alto | Relieve, a través de nubes y de noche |
| LIDAR / altímetro láser | ~10–50 kg | ~30–100 W | Medio | Topografía precisa |
| Magnetómetro | ~1–5 kg | ~1–5 W | Bajo | Campo magnético, interior del planeta |
| Detector de partículas/radiación | ~2–15 kg | ~2–10 W | Bajo | Entorno de radiación, viento solar |
| Cámara térmica IR | ~5–30 kg | ~10–40 W (+ refrigeración) | Medio–alto | Temperatura, volcanes, hielo |
