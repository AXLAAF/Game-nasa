# Puente física real ↔ NasaSpaceGame

Lee el código antes de proponer números: esta guía resume el estado a noviembre de 2026 y puede
quedarse vieja. Si algo no coincide, manda el código.

## Arquitectura

- Contenido como `Resource` en `res://content/{parts,bodies,malfunctions,encounters}`, cargado por
  `Catalog` (`game/autoload/catalog.gd`: `part()`, `body()`, `part_list()`, `star()`, `home()`,
  `encounters_for()`, `malfunctions_for()`).
- Simulación pura y testeable en `game/sim/`; fases jugables en `game/phases/`
  (hangar → assembly → launch → space → descent → debrief). Detalle en `docs/ciclo-jugable.md`.
- Estado de la partida: `Run` (`game/autoload/run.gd`); persistente: `Profile` (créditos,
  lecciones, `budget(contract)`).

## Unidades y escalas

| Dónde | Unidad / escala |
|---|---|
| `PartDef` (`game/data/part_def.gd`) | `mass` y `fuel` en toneladas, `thrust` kN, `isp` s, `drag` m² de paracaídas, `size` px (1 px = 0.25 m) |
| `PartDef` sin unidad física | `solar`, `power`, `battery`, `cooling`, `heat/cold/rad_resist`, `ablative`, `fragility` (valores de juego) |
| `BodyDef` (`game/data/body_def.gd`) | `surface_gravity` m/s² real; `atmosphere` densidad relativa (1 = Tierra, 0 = vacío); `mu`, `radius`, `orbit_radius` en unidades de juego |
| `rocket_math.gd` | `SPACE_SCALE = 0.05` unidades de juego por metro; `RADIUS_M = 6000` m reales por unidad de radio; `SCALE_HEIGHT = 3800` m; `BURN_COMPRESS = 4` (encendidos 4× más cortos); `LAUNCH_DV = 2450` m/s medido con piloto automático |
| `thermal.gd` | `flux(r) = (2000/r)²`: 1.0 en Terra (= 1 UA). `HOT = 0.85`, `COLD = 0.15` sobre temperatura normalizada (0.5 cómodo) |

El juego es un "sistema solar de bolsillo": la Tierra real necesita ~9.4 km/s a LEO y aquí el
despegue cuesta 2450 m/s. Para comparar con la realidad usa **proporciones** (Δv de transferencia /
Δv de despegue, flujo relativo), no valores absolutos.

## Cuerpos (análogos reales aproximados, por distancia `orbit_radius` / 2000 ≈ UA)

| Cuerpo | orbit_radius | ≈ UA | Análogo |
|---|---|---|---|
| Ignea | 950 | 0.48 | Mercurio/Venus: calor extremo, paneles se queman |
| Terra (hogar) | 2000 | 1.0 | Tierra |
| Rubra | 3300 | 1.65 | Marte: paneles al ~37 % |
| Glacia | 5600 | 2.8 | Gigante lejano con cinturones de radiación, frío, solar débil |
| Luna (de Terra), Hielo (de Glacia), Ceniza (de Rubra) | 140 / 260 / 95 | — | Lunas: `orbit_radius` es respecto a su planeta |

## Funciones clave para cuantificar

- `RocketMath.hohmann(mu, r1, r2)` → Δv de los dos encendidos.
- `RocketMath.mission_dv(target)` → Δv del contrato: despegue + transferencia + aterrizaje
  (con atmósfera ~220 m/s por paracaídas; sin atmósfera, frenado propulsado).
- `RocketMath.skip_edge(ship, body, v0)` → borde del corredor de reentrada; `entry_heat()`.
- `ShipModel` (`game/sim/ship_model.gd`): `delta_v()`, `stage_dvs()`, `twr(g)`, `stage_twr()`,
  `mass()`, `dry_mass()`, `sum_stat(name)`.
- `Thermal` (`game/sim/thermal.gd`): `equilibrium()`, `power_gen()` (solar × min(flux, 2.5) + RTG),
  `power_use()` (0.35 base + 0.15 por ordenador/sensor/antena/cápsula), `battery_capacity()`,
  `requirements(ship, target)` (lista que ve el jugador en el ensamblaje).
- Fiabilidad: `Odds.ship_reliability()`, `Run.roll_stress()`; fórmula
  `fail_chance = ((1-condición)*0.55 + desgaste*0.3) * estrés * fragilidad`.
- Canales de sistema (`Run.CHANNELS`): thrust, mobility, vision, audio, light, map, comms.
  Las piezas los sostienen vía `PartDef.channels`; sin pieza o sin energía se degradan.

## Inventario actual

25 piezas (motores chispa/susurro/trueno, 4 tanques, cápsula, desacoplador, escudos, paracaídas,
patas, radiador, aislante, panel solar, RTG, batería, antena, computadora, sensores, blindaje, RCS,
giroscopio, torre de escape), 8 cuerpos, 13 averías, 17 encuentros.

## Huecos frente al reto NASA (priorizar)

Lo que el reto pide y el juego todavía no modela de forma explícita (verifica en el código antes de
afirmarlo, puede haber avanzado):

1. **Objetivo científico → instrumentos**: los contratos pagan por llegar/aterrizar; falta elegir
   instrumentos con valor científico, masa, potencia y datos (usar la tabla de instrumentos de
   `physics.md` y la STM).
2. **Datos y enlace**: existe la pieza antena y el canal `comms`, pero no un volumen de datos que
   generar y descargar (`tasa ∝ 1/d²`, ventanas de contacto).
3. **Lanzador y órbita como decisión**: hoy el despegue lo hace la propia nave; el reto sugiere elegir
   lanzador (capacidad/coste) y órbita (cobertura, eclipse, vida útil) con comprobación de compatibilidad.
4. **Vida útil y operaciones**: tiempo de misión, degradación de paneles/RTG, coste por año operando.
5. **Presupuesto completo**: créditos de `Profile` cubren piezas; falta separar desarrollo,
   lanzamiento y operaciones, y márgenes.
6. **Informe post-misión con causas**: la liquidación cobra línea a línea; el reto valora explicar
   *por qué* salió bien o mal (qué subsistema, qué decisión).
7. **Coop de 4**: puestos Piloto / Navegante / Ingeniero / Comandante (`docs/multijugador.md`);
   buenas negociaciones de recursos entre puestos (masa vs ciencia vs energía).

## Reglas al proponer números de juego

- Parte del valor `[real]`, aplica la escala (indícala) y ajusta para que el trade-off se *note* en
  partida; documenta el factor en el `.tres` o en el PR.
- Mantén las proporciones entre piezas: si un motor tiene más Isp, debe pagar en empuje, masa o coste.
- Tras cambiar contenido: tests headless y comprobar que una nave barata aún cubre `mission_dv()`
  para cada destino con al menos un diseño.
