# AGENTS.md

NasaSpaceGame: roguelite 2D de misiones espaciales en Godot 4 / GDScript para el reto
NASA Space Apps "Space Mission Design Game". Ciclo jugable en `docs/ciclo-jugable.md`.

## Diseño de misión, física y balance

Para cualquier trabajo sobre delta-v, órbitas, piezas, instrumentos, energía, térmico, datos,
presupuesto, fiabilidad o contenido en `content/`, sigue
`.claude/skills/aerospace-mission-design/SKILL.md` y sus `references/`.

## Multijugador

Obligatorio seguir `docs/multijugador.md` (coop 2–4 en una sola nave con puestos, host con autoridad).

## Tests

```
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/smoke_runner.gd
```
