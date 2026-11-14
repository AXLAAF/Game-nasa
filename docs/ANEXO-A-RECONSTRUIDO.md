# Anexo A (reconstruido): dificultades de navegación y roles de Mission Control

> **Supuesto.** El Anexo A original no llegó al proyecto. Este documento lo reconstruye a partir del
> Anexo C (`docs/INVESTIGACION-TECNICA.md`, §1 subsistemas y §2 incidentes) y del plan
> (`docs/PLAN-DISENO.md`). Si aparece el original, este archivo se sustituye y se revisa la tabla de
> eventos de `data/design/events.json`.

## 1. Dificultades externas (vienen de fuera de la nave)

| # | Dificultad | Base real (Anexo C) | Evento de juego |
|---|---|---|---|
| X1 | Basura orbital y micrometeoritos | Iridium 33–Cosmos 2251; escudo Whipple; 3 200–16 500 J | E1, E3 |
| X2 | Clima espacial: fulguraciones, CME, SEU | Halloween 2003, Starlink 2022; RAD750, EDAC | E2 |
| X3 | Retardo de comunicación (RTLT) | DSN: 2.56 s Luna, 1 501 s Marte, 5 193 s Júpiter | `CommsLink`, retardo `d` |
| X4 | Conjunción solar (sin enlace) | Conjunción de Marte, ≈ 2 semanas cada ≈ 26 meses | E4 |
| X5 | Caída de irradiancia con la distancia | 1361/r² W/m²; Júpiter 3.7 % | E6 |
| X6 | Frío profundo sin aislamiento | Mito 1; MLI | E5 |
| X7 | Cinturones de radiación | Van Allen; Juno en Júpiter | E7 |
| X8 | Trayectoria hacia la atmósfera (periapsis bajo) | Mars Climate Orbiter (57 km) | E8 |
| X9 | Atmósfera en descenso: calor y frenado | Columbia STS-107; Marte 0.0064 bar | Fases 5 y 7 |
| X10 | Polvo en superficie | Fact Sheet de Marte | E10 |

## 2. Dificultades internas (nacen dentro de la nave)

| # | Dificultad | Base real (Anexo C) | Evento de juego |
|---|---|---|---|
| N1 | Incendio alimentado por ventilación | Mir 1997, Saffire (Mito 4) | I1 |
| N2 | Generador químico de oxígeno con oxidante propio | Vela Vika | I2 |
| N3 | Brecha lenta y despresurización | Mir–Spektr (Mito 2) | I3 |
| N4 | Fuga de propelente | Cuadrante `bottom` de la `DamageMatrix` | I4 |
| N5 | Pogo en encendidos largos | Apollo 6, Apollo 13 S-II | I5 |
| N6 | Propulsor atascado / giro descontrolado | Gemini 8, Nauka | I6 |
| N7 | Saturación de giroscopios y gimbal lock | CMG de la ISS, IMU Apollo | I7 |
| N8 | Error de software o de unidades | Mars Climate Orbiter (factor 4.4482) | I8 |
| N9 | Pérdida de potencia eléctrica | Apollo 13 (3 pilas perdidas) | I9 |
| N10 | Fallos en cadena | Anexo C §3.2: ventana de 5 s | I10 |

## 3. Los 4 roles de Mission Control

| Rol de juego | Puesto real | Responsabilidad | Consola en la nave |
|---|---|---|---|
| Comandante | FLIGHT (Flight Director) | Decide riesgos, contratos, jettison y aborto; desempata | Reactor (7 barras), jettison, aborto |
| Navegación | FDO / GUIDO | Trayectoria, nodos, quemados, RCS | Timón |
| Sistemas Vitales | EECOM | Potencia, térmico, ventilación, esclusas | Soporte vital |
| Comunicaciones y Datos | INCO / CAPCOM | Enlace con Tierra, sensores, diagnóstico, auditoría de nodos | Sensores |

Los roles no son fijos: se eligen en la sala antes de cada misión. Cualquier robot puede hacerlo todo
a velocidad ×1 y su rol le da ×1.5 en lo propio. Con menos de 4 jugadores, un robot lleva 2 roles a ×1.25.
