# AGENTS.md

Margin Zero: Deuda Orbital (`Margin Zero: Orbital Debt`). Roguelite cooperativo local de 1 a 4 robots (nave `MZ-1 BALLAST`, chasis `Orbital Mule Mk-I`, misiones `BALLAST-1` a `BALLAST-N`) en Godot 4.7 (GDScript, renderer `gl_compatibility`) para NASA Space Apps Challenge ("Space Mission Design Game").

## Reglas obligatorias

1. **Documento maestro:** Seguir `docs/PLAN-DISENO.md`.
2. **Simulacion pura y determinista:** Todo codigo en `game/sim/` es `RefCounted` sin nodos de escena ni autoloads, usa `SimRng` sembrado y tick fijo de 30 Hz. La vista nunca muta la simulacion; la entrada llega solo como `PlayerCommand`.
3. **Datos NASA reales:** Cualquier destino, tormenta solar, asteroide o latencia se lee de `res://data/nasa/*.json` (con `source`). Los valores de diseno van en `res://data/design/*.json`. Etiquetar cifras como `[NASA]` o `[DIS]`.
4. **Tipografia:** Prohibido usar `JetBrains Mono`. Rotulos en sans-serif (`>= 12 px`); telemetria numerica en monospace tabular (`>= 11 px`).
5. **Sin adornos ni emojis:** Codigo y documentacion sin emojis ni separadores visuales decorativos.
6. **Diseno de mision, fisica y balance:** Para cualquier trabajo sobre delta-v, orbitas, despegue, aterrizaje, energia (reactor, solar, RTG), termico, retardo DSN, economia y deuda, eventos y averias, perks, calidades, contratos o balance, seguir `.claude/skills/aerospace-mission-design/SKILL.md` y sus `references/`.

## Idioma (ingles por defecto, espanol opcional)

El texto original del codigo y de `content/` esta en espanol y es el `msgid` de `localization/en.po`; el ingles es la traduccion. El idioma se elige en Ajustes (solo en el titulo y el hangar) y se guarda en `user://settings.cfg`; sin ajuste guardado es siempre ingles.

- Texto con formato o dibujado: `tr("Plazo %d dias") % n`. En codigo estatico, donde `tr()` no existe, usar `Loc.t("...")`. Un `Label` o `Button` con un texto fijo se traduce solo, pero envolverlo tambien esta bien.
- Constantes (`const`): no admiten `tr()`. Se dejan en espanol y se traducen donde se muestran: `tr(Profile.INSURANCE_NAMES[i])`.
- Los campos de texto de los recursos de `content/` (`display_name`, `description`, `title`, `text`, `label`, `win_text`, `lose_text`) se traducen solos al leerlos. Los textos de `data/design/training.json` se traducen al cargar la sesion.
- Nunca comparar contra un texto traducido: usar ids o enums (si hace falta comparar texto, `x == tr("...")` en ambos lados).
- Palabras sueltas en minuscula que si ve el jugador (`derecha`, `plazo`): anotarlas en `localization/extra.txt`. Lo que no es texto de jugador (ids, avisos de consola): `localization/ignore.txt`.
- Antes de abrir un PR: `python3 tools/i18n_extract.py --update` (anade los textos nuevos con la traduccion vacia), rellenar los `msgstr` y comprobar con `python3 tools/i18n_extract.py --check`.
- Revision visual y de textos sobrantes: `I18N_LANG=en godot --path . --script res://tools/i18n_scan.gd` (con ventana guarda capturas; marca con `??` lo que en ingles aun parece espanol).
- Las etiquetas cortas (lamparas) se cortan si la traduccion es mas larga: mantenerlas en 6 letras o menos.

## Pruebas

- Suites `McpTestSuite` en `tests/`, ejecutadas con la herramienta `test_run` del addon `godot_ai` (requiere `addons/godot_ai/`).
- Balance: `tools/balance_montecarlo.gd` (`BalanceSim.run`), informe en `docs/balance_report.json`.
