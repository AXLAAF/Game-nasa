# 03. Interior FTL 2.5D, Tripulación y Catálogo de Crisis de 5 Segundos

**Objeto:** Especificar el mapa interior caminable de las 6 salas de la nave `MZ-1 BALLAST` (chasis `Orbital Mule Mk-I`), el grafo de compuertas y esclusas, los bonos de estación (`Manning Bonus`), los controles 1P y 2–4P sin pausa global y las 10 tarjetas de incidentes de 5 segundos respaldadas por [INVESTIGACION-NAVES-INCIDENTES-NASA.md](INVESTIGACION-NAVES-INCIDENTES-NASA.md).

## 1. Plano de las 6 Salas, Compuertas y Esclusas (`160 x 224 px` = `5 x 7` celdas)

Cada celda mide `32 x 32 px` (`1.0 m`). Los tabiques 2.5D muestran `3 px` de arista superior y `6 px` de muro vertical visible:

```text
          +-------------------+---------------+
          | sensors (1x2)     | helm (2x2)    |  <- Cuadrante top (Proa)
          | Consolas + Bus    | Timon NavBall |
          +--------+----------+-------+-------+
                   | puerta A         | puerta B
+------------------+------------------+------------------+
| life_support (1x2) | reactor (2x2)  | science_bay (2x2)| <- Cuadrantes middle / radial
| O2 + Lazo NH3      | Nucleo Barras  | Brazo + Muestras |
| [AIRLOCK BABOR]    +--------+-------+                  |
+-----------------------------+--------------------------+
                              | puerta C
                   +----------+----------+
                   | engines (3x1)       |  <- Cuadrante bottom (Popa)
                   | Bombas + Inyectores |
                   | [AIRLOCK POPA]      |
                   +---------------------+
```

### Relación Sala -> Sistema `ReactorPower` -> Cuadrante `RoomHazards`

| Sala (`RoomHazards`) | Sistema (`ReactorPower`) | Barras Máx. | Cuadrante | Canales degradados al dañarse (`DamageMatrix`) |
| :--- | :--- | :---: | :--- | :--- |
| `helm` | `&"helm"` | `2` | `top` | `vision`, precisión de giro y tolerancia NavBall |
| `sensors` | `&"sensors"` | `2` | `top` | `map`, cono Radar 3D Wireframe y `comms` |
| `reactor` | *(Fuente total: `total_bars = 7+`)* | N/A | `middle` | `light` (apagón de cabina), caída temporal de barras totales disponibles |
| `life_support` | `&"life_support"` + `&"shields_thermal"` | `2` / `3` | `middle` | `mobility`, regeneración de $\text{O}_2$ (`0.22 * eff`) y refrigeración $\text{NH}_3$ |
| `science_bay` | `&"science_bay"` | `2` | `radial` | `audio` (estática en alertas), `comms` (bajada DSN) y captura de muestras |
| `engines` | `&"engines"` | `3` | `bottom` | `thrust` (sube $t_{burn}$) y dispara fuga de propelente (`fuel_leak_rate = 0.25/s`) |

## 2. Bono de Estación (`Manning Bonus`) y Flujo de Energía sin Pausa

- **Presupuesto inicial restringido:** El reactor arranca con `total_bars = 7` mientras las 6 salas demandan hasta `14` barras combinadas. Es imposible alimentar todo al máximo simultáneamente.
- **Efecto mecánico exacto (`ReactorPower.efficiency`):**
  - Cada barra asignada aporta `1 / max_bars` (`33.3%` en `engines` y `shields_thermal`, `50%` en las demás salas).
  - Mantener un tripulante frente a la consola con $\ge 1$ barra activa añade **`+0.25` (`+25%`) de eficiencia máxima (hasta `1.25`)**:
    - En **`helm`:** $+25\%$ velocidad angular y estabilización NavBall.
    - En **`sensors`:** Desbloquea telemetría predictiva completa en Radar 3D y $+25\%$ velocidad de transferencia DSN.
    - En **`engines`:** Reduce $25\%$ el tiempo de ignición orbital y amortigua errores de mezcla.
    - En **`life_support`:** Acelera recarga de oxígeno tras ventear esclusas.
    - En **`science_bay`:** Acelera $25\%$ el escaneo de anomalías y recolección NEO.
- **Compromiso táctico:** Cuando estalla un incendio en `engines`, si el Piloto o el Oficial de Radar abandona su consola para ayudar al Ingeniero, pierde de inmediato el `+25%` de su consola.

## 3. Dinámica de Oxígeno, Fuego, Brechas y Venteo Táctico (*Airlock Venting*)

Implementado exactamente sobre las tasas de `RoomHazards.step(dt, life_support_eff, crew_in_rooms)`:

1. **Incendio activo (`fire > 0`):** Consume oxígeno a `0.14 * fire / s` y reduce integridad `hp` de la sala a `0.08 * fire / s` hasta inutilizar barras de reactor cuando `hp < 0.70` o `hp < 0.35`.
2. **Brecha al vacío (`breach > 0`):** Drena oxígeno a `0.32 * breach / s` e impide que `life_support` recargue aire en la sala mientras `breach > 0.05`.
3. **Asfixia de tripulantes (`oxygen < 0.20`):** Todo tripulante en sala hipóxica sufre daño/aturdimiento acelerado y riesgo de inconsciencia (modelando el TUC real de $12\text{--}15\text{ s}$ comprimido a escala de partido).
4. **Esclusa de venteo (`set_airlock(room_id, true)`):**
   - Vacía el oxígeno a `0.60 / s`.
   - En cuanto **`oxygen < 0.15`**, el fuego cae a razón de `0.85 / s` hasta extinguirse de forma automática (`vented_fires`), evitando que el ingeniero arriesgue salud apagando manualmente una llama violenta.
   - Regla crítica de seguridad: si el operador olvida sacar al compañero o cerrar las puertas interiores antes de ventear, la succión empuja o asfixia al tripulante dentro de la sala drenada.

## 4. Esquema de Controles: 1 Jugador (`SOLO`) y 2–4 Jugadores (`COOP_LOCAL`)

`StationInput` desacopla por completo los puestos `[&"pilot", &"radar", &"engineer", &"mission"]` de los dispositivos físicos:

| Puesto | Atajo `SOLO` | Teclado 2P (compartido) | Gamepad 2–4P | Bot automático en `SOLO` (cuando no lo controlas) |
| :--- | :---: | :--- | :--- | :--- |
| **`pilot`** | `1` / `Tab` | `W A S D` + `Space` (ignición/freno) | Stick Izq + `A/RT` | Dirección al `45%` (`autopilot_steer * 0.45`), empuje fijo `0.5` |
| **`radar`** | `2` / `Tab` | `Flechas` + `Enter` (fijar nodo / Tx) | Pad + Stick + `X` | Solo alertas tardías de corto alcance; no transmite ciencia |
| **`engineer`** | `3` / `Tab` | `I J K L` + `U/O` (reparar / airlock) + `F1-F6` barras | Stick + `Y/B` | Repara salas al `40%` de velocidad (`action = true`), no abre airlocks por riesgo |
| **`mission`** | `4` / `Tab` | Mouse/click directo o alternancia J2 (`Q/E`) | Gatillos `LB/RB` | Activa *Storm Safe* con retraso; no recolecta muestras NEO |

Regla invariable: **`get_tree().paused = true` queda prohibido durante la fase de vuelo**. En modo `SOLO`, cambiar de puesto con `1-4` o click de sala es instantáneo y mantiene el pulso en tiempo real.

## 5. Catálogo de 10 Tarjetas de Incidentes de 5 Segundos (`CRITICAL_WINDOW_S = 5.0`)

Cada avería grave activa un temporizador rojo de **5.0 segundos** en el panel derecho y sobre la sala afectada. Si expira sin intervención, aplica un castigo adicional de `-0.25 hp` y propaga un efecto secundario inspirado en incidentes reales:

| # | Tarjeta de Crisis (Título en HUD) | Sala afectada | Precedente real documentado | Acción para neutralizar antes de `0.0 s` | Consecuencia si expira el temporizador |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **1** | **Arco en Tanque Criogénico** | `reactor` | Apollo 13 (`LOX` #2, 1970) | Cortar 1 barra de sistemas no críticos y sellar con Ingeniero (`repair_room`) | Pierde `2` barras máximas del reactor por el resto del tramo + apagón (`light = 0`) |
| **2** | **Fuego de Vela Química $\text{LiClO}_4$** | `life_support` | Mir Kvant-1 (*Vika*, 1997) | Evacuar sala y abrir `AIRLOCK BABOR` hasta apagar llama | El humo reduce `vision` en todas las salas y daña `life_support` a rojo |
| **3** | **Brecha por Colisión de Acoplamiento** | `science_bay` | Mir Spektr / Progress M-34 (1997) | Cerrar compuerta adyacente y parchar brecha | $\text{O}_2$ cae a `0%` en la bahía, desconectando paneles laterales (`-2` barras) |
| **4** | **Propulsor RCS Atascado en Giro** | `helm` | Gemini 8 OAMS #8 / ISS Nauka | Mantener `helm` ocupado y pulsar contra-torque manual | Nave gira `360 deg` desalineando antena DSN y bloqueando ignición por `6 s` |
| **5** | **Sobretensión en Tormenta CME (SEU)** | `sensors` | Halloween 2003 / SEP 2017 | Conmutar consola a *Storm Safe* o bajar barra de `sensors` antes del impacto | Reinicio forzado de aviónica: Radar 3D ciego durante `8 s` (salvo `telemetry_strain`) |
| **6** | **Fuga en Lazo de Amoníaco ($\text{NH}_3$)** | `life_support` | Soyuz MS-22 (dic 2022) | Reparar conducto o reducir potencia de `engines`/`reactor` | Temperatura cruza `0.85` (`overheated`), dañando equipos activos por calor |
| **7** | **Fuga de Propelente en Campana** | `engines` | Riesgo de encendido en Popa | Sellar cámara con Ingeniero mientras Piloto corta empuje a `0%` | Pérdida continua de combustible (`fuel_leak_rate = 0.25/s`) y llama activa |
| **8** | **Oscilación Resonante Pogo en Ascenso** | `engines` | Apollo 6 / Apollo 13 S-II | Reducir acelerador brevemente o activar `damper_cryo_he` | Apagado de emergencia del motor central (`-40%` TWR por `5 s`) |
| **9** | **Saturación de Giróscopos (Gimbal Lock)** | `helm` | Apollo IMU / CMG en ISS | Ejecutar pulso de desaturación RCS con Piloto en `helm` | Bloqueo de orientación (`4.0 s`) durante aproximación orbital |
| **10** | **Sobrecalentamiento de Panel PICA en Corredor** | `helm` / Proa | Columbia STS-107 (2003) | Corregir cabeceo dentro de `[-5.2 deg, -3.8 deg]` | Desgaste acelerado de losetas/escudo y brecha térmica frontal si llega a `0%` |
