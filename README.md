# Margin Zero: Deuda Orbital

Juego cooperativo caotico en tiempo real (1 jugador o 2-4 jugadores locales) desarrollado en Godot 4.7 (`gl_compatibility`) para el reto **NASA Space Apps Challenge — Space Mission Design Game** (*Margin Zero: Orbital Debt*).

## Premisa y Mecanicas

Diriges a **Margen Cero Astrologistica**, una naviera espacial privada en sindico de quiebra con tripulacion robotica/antropomorfica. Evolucionas tu nave insignia **`MZ-1 BALLAST`** (chasis modular `Orbital Mule Mk-I`, `LVL 1..5`) acoplando piezas coherentes por hardpoints, vuelas el programa de misiones **`BALLAST-1` a `BALLAST-N`**, navegas en **Vista Orbital 2.5D estilo KSP / Rhine Lab** (`AP`/`PE`, nodos $\Delta v$, NavBall 2.5D) y gestionas el caos interno en tiempo real con salas **FTL** y datos abiertos de la NASA/JPL.

## Documentacion

- **Identidad de Marca y Nomenclatura:** `docs/BRANDING-MARGIN-ZERO.md` (`Margin Zero: Deuda Orbital`, nave `MZ-1 BALLAST`, programa `BALLAST-1..N`)
- **Planificacion Numerada del Hackathon (`docs/00` a `docs/05`):**
  - `docs/00-INDICE-Y-PLAN-MAESTRO-HACKATHON.md` (indice maestro, horarios, roles, Go/No-Go y riesgos)
  - `docs/01-CATALOGO-MODULOS-Y-EVOLUCION-NAVE.md` (`MZ-1 BALLAST` / chasis `Orbital Mule Mk-I`, 7 hardpoints y tablas `LVL 1..5`)
  - `docs/02-SISTEMA-ORBITAL-KSP-25D-Y-FISICA.md` (orbita `AP/PE`, nodos $\Delta v$, NavBall, corredor atmosferico y Radar 3D)
  - `docs/03-INTERIOR-FTL-TRIPULACION-Y-CRISIS.md` (6 salas, esclusas, *Manning Bonus*, controles 1P/2-4P y 10 crisis de 5 s)
  - `docs/04-GUION-MISIONES-Y-CONTRATOS-NASA.md` (4 contratos NASA/JPL, economia de deuda y *Debrief Causal*)
  - `docs/05-ARQUITECTURA-GODOT-ESCENAS-Y-SHADERS.md` (escenas `.tscn`, shaders WebGL2 y guion video pitch <= 30 s)
- **GDD Maestro:** `docs/GDD-REMAKE-MASTER.md`
- **Interfaz 2.5D, Naves Modulares y Vista Orbital KSP:** `docs/DISEÑO-UI-NAVES-25D.md`
- **Mockups visuales 1280x720:** `docs/mockups/mockup_1_dique_modular_25d.png` y `docs/mockups/mockup_2_hud_ftl_ksp_orbital.png`
- **Especificacion Fisica y Catalogo NASA:** `docs/MECANICAS-REFERENCIA.md`
- **Catalogo Tecnico de Partes de Naves Reales:** `docs/CATALOGO-PARTES-NAVES-REALES.md` (12 perks, 9 modulos base, 14 piezas de lanzador y hardware de las 6 salas)
- **Investigacion Tecnica de Naves e Incidentes NASA/NOAA:** `docs/INVESTIGACION-NAVES-INCIDENTES-NASA.md`
- **Arte:** `assets/` inicia vacio para producir recursos propios pixel art 2.5D sin dependencias externas.

## Fuentes Oficiales de Datos Abiertos (NASA & Partner Data)

- **NASA Planetary Fact Sheet (NSSDCA):** `https://nssdc.gsfc.nasa.gov/planetary/factsheet/`
- **JPL Small-Body Database (SBDB / CAD):** `https://ssd-api.jpl.nasa.gov/doc/sbdb.html`
- **NASA DONKI (Space Weather):** `https://api.nasa.gov/`
- **NASA Deep Space Network (DSN Now):** `https://eyes.nasa.gov/dsn/data/dsn.xml`
- **NASA Orbital Debris Program Office / CelesTrak GP:** `https://orbitaldebris.jsc.nasa.gov/`

## Pruebas

```bash
godot --headless --path . --script res://tests/test_runner.gd
```
