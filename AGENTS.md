# AGENTS.md

Margin Zero: Deuda Orbital (`Margin Zero: Orbital Debt`) — simulador cooperativo caotico de misiones espaciales (nave `MZ-1 LIBERTY`, chasis `Orbital Mule Mk-I`, programa `LIBERTY-1` a `LIBERTY-N`) en Godot 4.7+ (GDScript, renderer `gl_compatibility` para exportacion Web) para NASA Space Apps Challenge ("Space Mission Design Game").

## Reglas obligatorias

1. **Documento maestro:** Seguir `docs/GDD-REMAKE-MASTER.md`.
2. **Simulacion pura:** Todo codigo en `game/sim/` debe ser `RefCounted` puro sin dependencias a nodos de escena ni autoloads globales.
3. **Cero pausa global en vuelo:** Prohibido usar `get_tree().paused = true` durante las fases activas; el ritmo cooperativo es en tiempo real.
4. **Datos NASA reales:** Cualquier destino, tormenta solar, asteroide o latencia debe leer de `res://data/nasa/*.json` (con citas oficiales).
5. **Tipografia:** Prohibido usar `JetBrains Mono` en cualquier escena, tema o script. Rotulos en sans-serif (`>= 12 px`); telemetria numerica en monospace tabular (`>= 11 px`).
6. **Sin adornos ni emojis:** Codigo y documentacion sin emojis ni separadores visuales decorativos.

## Pruebas headless

```bash
godot --headless --path . --script res://tests/test_runner.gd
```
