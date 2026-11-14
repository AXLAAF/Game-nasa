# Deuda Orbital (Space)

Juego cooperativo caotico en tiempo real (1 jugador o 2-4 jugadores locales) desarrollado en Godot 4.7 (`gl_compatibility`) para el reto **NASA Space Apps Challenge — Space Mission Design Game**.

## Premisa y Mecanicas

Diriges una agencia espacial privada al borde de la quiebra con tripulacion robotica/antropomorfica. Evolucionas una nave modular base (`Orbital Mule Mk-I`, `LVL 1..5`) acoplando piezas coherentes por hardpoints, navegas en **Vista Orbital 2.5D estilo KSP / Rhine Lab** (`AP`/`PE`, nodos $\Delta v$, NavBall 2.5D) y gestionas el caos interno en tiempo real con salas **FTL** y datos abiertos de la NASA/JPL.

## Documentacion

- **GDD Maestro:** `docs/GDD-REMAKE-MASTER.md`
- **Interfaz 2.5D, Naves Modulares y Vista Orbital KSP:** `docs/DISEÑO-UI-NAVES-25D.md`
- **Mockups visuales 1280x720:** `docs/mockups/mockup_1_dique_modular_25d.png` y `docs/mockups/mockup_2_hud_ftl_ksp_orbital.png`
- **Especificacion Fisica y Catalogo NASA:** `docs/MECANICAS-REFERENCIA.md`
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
