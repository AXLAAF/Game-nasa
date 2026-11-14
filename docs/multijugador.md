# Multijugador

Contexto de diseño obligatorio. Cualquier trabajo de red o cooperativo debe seguir esto.

## Premisa

Este juego es un roguelite espacial de una sola nave con aceleración de tiempo (x0.5–x50) y cartas que hoy pausan el árbol. Por eso:

- **No** empezar con varias naves en el mismo sistema en tiempo real.
- **Sí** cooperativa de 2–4 jugadores en la misma nave (puestos).
- **Sí** competencia asíncrona entre agencias más adelante.

Varias naves chocan con el warp y con `Card` / tutorial (`get_tree().paused = true`). Un reloj compartido o no compartir reloj.

## Opción principal: cooperativa en la misma nave

Inspiración: *FTL*, *Lovers in a Dangerous Spacetime*, *Spaceteam*. Una nave, varios puestos.

| Puesto | Controla | Sistemas actuales |
|---|---|---|
| **Piloto** | A/D, empuje W, cabeceo, ángulo de entrada | `_steer`, `_thrust`, `launch`, `descent` |
| **Navegante** | Objetivo, escaneo, nav assist, warp | `_cycle_target`, `_scan_target`, `nav_burn`, `TIME_SCALES` |
| **Ingeniero** | Reparar, kits, batería, estado | `_repair_card`, `roll_stress`, `admit`, `StatusBoard` |
| **Comandante** | Cartas, encuentros, contrato, seguro | `Card`, `EncounterDef`, hangar |

Con 2 jugadores: piloto+navegante y ingeniero+comandante.

### Lo que debe sentirse natural

1. **Información repartida.** El navegante ve trayectoria y «falta»; el piloto ve la nave y la flecha. Tienen que hablar.
2. **Canales como puestos.** Si se rompe la computadora, el mapa del navegante baja (`Run.channel`). Una pieza rota es un problema de equipo.
3. **Una sola avería a la vez.** El ingeniero trabaja sin congelar al piloto.
4. **Cartas sin pausa global.** La carta va al comandante (nave en x0.5) o hay voto con timer; si se acaba, decide el comandante.
5. **Warp por consenso.** El navegante propone; el piloto confirma soltando el motor (ya no se acelera con motor encendido).
6. **Fracaso compartido.** Rebote, paracaídas roto y debrief son historia del grupo.

## Opción secundaria: agencias asíncronas

Sin latencia de vuelo:

- Tablero diario con semilla compartida (mismos contratos, se compara nota/pago).
- Restos de otros jugadores como encuentros `derelict`.
- Fantasmas de trayectoria de la mejor corrida.

## Arquitectura técnica (Godot 4.7)

Host con autoridad. `ENetMultiplayerPeer` + `@rpc`.

```
Clientes (intenciones: girar, empujar, votar)
    -> Host (Run, Gravity, Router, cartas, RNG)
    -> Clientes (estado 15–20 Hz: pos, vel, rumbo, piezas)
```

### Cambios obligatorios en el código

1. **Separar entrada de simulación.** Hoy `space.gd`, `launch.gd` y `descent.gd` leen `Input.is_physical_key_pressed` directo. Pasar a intenciones por puesto (`{turn, throttle, hold}`) locales o por RPC. Primer paso, también para prototipo local 2 teclados.
2. **RNG solo en el host.** `Run.roll_stress`, `Run.admit`, ruleta de `Card`. El host tira y envía el resultado.
3. **Sincronizar poco.** Los planetas van en rails (`Gravity.body_pos(body, t)`): basta `st.t`. Enviar nave: `st.pos`, `st.vel`, rumbo, combustible, piezas. Clientes interpolan.
4. **`Router.go` solo desde el host.** RPC a todos; limpia cartas y pausa igual en cada máquina.
5. **Sin pausa global en multi.** `Card` y `Tutorial` no usan `get_tree().paused`; usan espera / x0.5 / hold.
6. **`Profile` local.** Contrato del host; pago repartido; lecciones e inventario personales.

## Orden de implementación

1. Prototipo local 2 teclados (piloto WASD, navegante flechas/TAB), sin red.
2. Cooperativa en red con host, solo fase espacio.
3. Despegue y descenso cooperativos.
4. Asíncrono: tablero diario, restos, fantasmas.

Validar el diseño en el paso 1 antes de pagar el costo de red. El aterrizaje con latencia es el riesgo más alto para el piloto.
