# AGENTS.md

Margin Zero: Deuda Orbital (`Margin Zero: Orbital Debt`). Roguelite cooperativo local de 1 a 4 robots (nave `MZ-1 BALLAST`, chasis `Orbital Mule Mk-I`, misiones `BALLAST-1` a `BALLAST-N`) en Godot 4.7 (GDScript, renderer `gl_compatibility`) para NASA Space Apps Challenge ("Space Mission Design Game").

## Reglas obligatorias

1. **Documento maestro:** Seguir `docs/PLAN-DISENO.md`.
2. **Simulacion pura y determinista:** Todo codigo en `game/sim/` es `RefCounted` sin nodos de escena ni autoloads, usa `SimRng` sembrado y tick fijo de 30 Hz. La vista nunca muta la simulacion; la entrada llega solo como `PlayerCommand`.
3. **Datos NASA reales:** Cualquier destino, tormenta solar, asteroide o latencia se lee de `res://data/nasa/*.json` (con `source`). Los valores de diseno van en `res://data/design/*.json`. Etiquetar cifras como `[NASA]` o `[DIS]`.
4. **Tipografia:** Prohibido usar `JetBrains Mono`. Rotulos en sans-serif (`>= 12 px`); telemetria numerica en monospace tabular (`>= 11 px`).
5. **Sin adornos ni emojis:** Codigo y documentacion sin emojis ni separadores visuales decorativos.
6. **Diseno de mision, fisica y balance:** Para cualquier trabajo sobre delta-v, orbitas, despegue, aterrizaje, energia (reactor, solar, RTG), termico, retardo DSN, economia y deuda, eventos y averias, perks, calidades, contratos o balance, seguir `.claude/skills/aerospace-mission-design/SKILL.md` y sus `references/`.

## Pruebas

- Suites `McpTestSuite` en `tests/`, ejecutadas con la herramienta `test_run` del addon `godot_ai` (requiere `addons/godot_ai/`).
- Balance: `tools/balance_montecarlo.gd` (`BalanceSim.run`), informe en `docs/balance_report.json`.
