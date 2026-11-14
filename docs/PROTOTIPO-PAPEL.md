# Prototipo de papel: Margin Zero: Deuda Orbital

Reglas imprimibles para jugar una run en mesa con 1–4 personas, un d6, un d20 y fichas. Sirve para
probar la economía y la suerte antes de tocar el motor. Los números salen de `data/design/*.json`;
si cambian allí, cambian aquí.

## Material

- 1 d6 y 1 d20. Monedas o fichas de 100 cr.
- Hoja de compañía: deuda (empieza en **12 000 cr**), caja (**1 200 cr**), faltas (0/3), reputación (0–5), suerte (0).
- Hoja de nave MZ-1 BALLAST (chasis Orbital Mule Mk-I, vuelos BALLAST-1 a BALLAST-N): 6 salas (Timón, Sensores, Reactor, Soporte vital, Motores, Bodega), 7 barras de energía, casco 10/10, carga 10/10.
- Mazos: contratos (16), piezas (12 perks + 9 módulos), eventos (27). Recortables al final.

## Turno de misión

1. **Tablero.** Roba 4 contratos y marca 1 como sospechoso (d6 = 1). Pago base por destino: Luna 1 000, NEO 2 000, Marte 3 000, Júpiter 4 000 (`pay_base × (1 + tier)^pay_exponent`). El sospechoso paga ×1.5. Se pueden asegurar: cuesta 12 % del pago y cubre 60 % si falla.
2. **Taller.** Tienda de 6 piezas. Calidad de cada una con d20: 1–8 SCRAP, 9–15 USED, 16–19 NEW, 20 LEGENDARY. Cada punto de suerte desplaza la tirada +1. Caja del desguace: 60 % del precio medio, pieza al azar. Ruleta: 50, 100, 200… cr para renovar la tienda.
3. **Despegue.** Riesgo de explosión = (SCRAP en la nave × 2 %) + (2 % por tonelada sobre 34.3 t). Tira d20: si sale ≤ riesgo/5, **alerta roja**: la mesa tiene 10 segundos reales para decir "soltamos carga" (repite la tirada sin carga) o "abortamos" (misión fallida, nave intacta). Si nadie habla, explota: +3 000 cr de deuda y nave nueva toda SCRAP.
4. **Navegación.** 6 rondas (Luna) a 12 rondas (Júpiter). Cada ronda roba 1 evento por jugador (máx. 3 activos). Cada evento pide una acción concreta (reparar, extintor, fusible, cerrar válvula). Un evento sin atender al final de la ronda **escala** (casco −1 o se copia a la sala vecina). Casco 0 = remolque: pago ×0.4 y −800 cr.
5. **Aterrizaje.** d6 + piloto (1 si el piloto no atendió eventos esta misión): 1–2 grave (casco −2), 3–4 leve, 5–6 perfecto.
6. **Superficie.** Cada jugador elige: entregar (obligatorio una vez), muestra (d6 × 20 cr), caja sin identificar (d20: 1–10 chatarra 40 cr, 11–15 USED, 16–17 NEW, 18 LEGENDARY, 19–20 estalla: −1 casco).
7. **Liquidación.** Ingreso = pago × (0.5 + 0.5 × carga/10) + salvage − costes (propelente 20 cr/t, lanzador 100 cr por 10 t, reparaciones). Interés 6 % sobre la deuda. Cuota mínima 6 % de la deuda; si no se paga, +10 % de recargo y una falta.

## Cláusula sospechosa (d6 al llegar)

1–2 mala (multa 50 % del pago) · 3–4 neutra · 5–6 propina (+25 %).

## Botón misterioso (d20, una vez por ronda)

1 purga la carga opcional · 2–4 molestia · 5–12 nada · 13–17 repara 1 evento leve · 18–19 sella una sala · 20 una pieza sube a NEW o +300 cr. Cada pulsación extra en la misión resta 1.

## Patada de mantenimiento (d6)

1 empeora · 2–3 nada · 4–6 arregla. Con suerte ≥ 0.5, el 2 también arregla.

## Doble o nada (moneda)

Una vez por liquidación: cara se perdona el interés de la misión, cruz se duplica.

## Fin de la run

- **Victoria:** deuda = 0.
- **Embargo:** 3 faltas seguidas o deuda ≥ 20 000 cr.

## Qué medir en mesa

- Tasa de victoria de 10 runs por grupo (objetivo 35–50 %).
- Cuántas veces se usó cada apuesta voluntaria y si alguien dijo "esto no fue justo".
- Si alguna estrategia (siempre sospechoso, nunca comprar, todo NEW) gana siempre.
