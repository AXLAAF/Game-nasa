# 01. Catálogo de Módulos, Hardpoints y Evolución de Nave (`Orbital Mule Mk-I`)

**Objeto:** Especificación numérica y visual del chasis maestro predeterminado `Orbital Mule Mk-I` (`160 x 224 px` nominales, rejilla interna `5 x 7` celdas de `32 x 32 px`) y sus 7 puntos de acople tipados con evolución progresiva **`LVL 1` a `LVL 5 MAX`**.

## 1. Principios de Diseño Modular Coherente

- **Cero piezas sueltas flotando:** Ningún módulo se coloca en coordenadas libres. Todo componente entra en uno de los **7 hardpoints tipados** definido sobre el fuselaje maestro `Z=0`.
- **Unificación visual automática:**
  - Luz direccional fija a **315 grados** (superior-izquierda $+25\%$ luminancia, bisel inferior de `3 a 4 px` a $-40\%$ luminancia).
  - Oclusión de contacto de `2 px` en tonos `#0b0e17` / `#334155` donde la pieza intercepta el casco.
  - Abrazaderas estructurales horizontales (`#f1f5f9` con borde `#334155`) generadas automáticamente al acoplar módulos en `SOCKET_PORT_NACELLE` y `SOCKET_STBD_NACELLE`.
  - Contorno exterior único de `1 a 2 px` en `#0b0e17` aplicado sobre el nodo padre `CanvasGroup` del casco completo.

## 2. Mapa de Hardpoints del Chasis Base (`Orbital Mule Mk-I`)

```text
                       [ SOCKET_BOW ] (Z=2, anillo frontal 48px)
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
[ SOCKET_WING_PORT ]                    [ SOCKET_WING_STBD ]
 (Z=2, rotula babor)                    (Z=2, rotula estribor)
        │                                         │
[ SOCKET_PORT_NACELLE ]──(Abrazadera)──[ CHASIS Z=0 ]──(Abrazadera)──[ SOCKET_STBD_NACELLE ]
       (Z=1, 32x96 px)  + AO 2px      (160x224 px,     + AO 2px        (Z=1, 32x96 px)
                                        6 salas FTL)
                                              │
                                    [ SOCKET_DORSAL_TURRET ] (Z=3, sombra +2,+2 px)
                                              │
                                  ┌───────────┴───────────┐
                          [ SOCKET_AFT_ENGINES (Babor / Estribor) ]
                            (Z=-1, anclado -4 px bajo faldon trasero)
```

## 3. Especificación Numérica de Módulos por Hardpoint (`LVL 1` -> `LVL 5 MAX`)

Valores base en condición `NEW` (multiplicador `1.05`). Las propiedades de desgaste se modulan por calidad (`SCRAP`, `USED`, `NEW`, `LEGENDARY` definidos en [MECANICAS-REFERENCIA.md](MECANICAS-REFERENCIA.md)).

### 3.1 `SOCKET_BOW` (`Z = 2`, anillo frontal `48 px`)

| Módulo / Rol | LVL 1 (Chatarra) | LVL 2 (Usada) | LVL 3 (Estándar) | LVL 4 (NASA) | LVL 5 MAX (Exp.) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Escudo Térmico PICA / HRSI** | Masa `1.6 t`, HeatRes `0.55`, Costo `120` | Masa `1.4 t`, HeatRes `0.70`, Costo `210` | Masa `1.3 t`, HeatRes `0.85`, Costo `320` | Masa `1.2 t`, HeatRes `0.95`, Costo `480` | Masa `1.0 t`, HeatRes `0.99`, Costo `720` |
| **Domo Radar Doppler Ku** | Aviso `6 s`, `-1` barra `sensors` | Aviso `9 s`, rango medio | Aviso `12 s`, `radar_doppler` base | Aviso `14 s`, anti-ruido solar | Aviso `18 s`, predice trayectoria debris |
| **Torre de Escape (LES)** | Salva `35%` créditos en aborto | Salva `50%` créditos | Salva `65%` créditos + tripulación | Salva `80%` créditos + módulos Proa | Salva `95%` + separación sin daño |

### 3.2 `SOCKET_PORT_NACELLE` y `SOCKET_STBD_NACELLE` (`Z = 1`, abrazaderas automáticas)

| Módulo / Rol | LVL 1 | LVL 2 | LVL 3 | LVL 4 | LVL 5 MAX |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Góndola Tanque $\text{LH}_2/\text{LOX}$** | $+1.8\text{ t}$ combustible, $+0.4\text{ t}$ seca, fuga base alta, Costo `150` | $+2.6\text{ t}$ comb., $+0.5\text{ t}$ seca, Costo `260` | $+3.6\text{ t}$ comb., $+0.6\text{ t}$ seca, Costo `420` | $+4.8\text{ t}$ comb., aislamiento MLI oro, Costo `650` | $+6.2\text{ t}$ comb., zero boil-off activo, Costo `950` |
| **Banco Nuclear MMRTG ($\text{PuO}_2$)** | $+2$ barras reactor, $+0.25$ calor/s, Masa `1.2 t`, Costo `380` | $+3$ barras reactor, $+0.22$ calor/s, Costo `520` | $+4$ barras reactor, $+0.18$ calor/s, Costo `700` | $+5$ barras reactor, blindaje Kapton, Costo `920` | $+6$ barras reactor, estable a $5.2\text{ AU}$, Costo `1300` |
| **Góndola Blindada de Carga / Whipple** | $+2$ ranuras carga, Masa `1.4 t`, $-15\%$ daño `radial` | $+3$ ranuras carga, $-25\%$ daño `radial` | $+4$ ranuras carga, Nextel/Kevlar $-40\%$ daño | $+5$ ranuras carga, $-55\%$ daño hiperveloz | $+6$ ranuras carga, amortiguador activo $-70\%$ daño |

### 3.3 `SOCKET_WING_PORT` y `SOCKET_WING_STBD` (`Z = 2`, rótula lateral)

| Módulo / Rol | LVL 1 | LVL 2 | LVL 3 | LVL 4 | LVL 5 MAX |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Arreglo Solar $\text{GaInP/GaAs/Ge}$** | $+2$ barras a $1\text{ AU}$ ($0.8$ a Marte, $0$ a Júpiter), Masa `0.6 t`, Costo `140` | $+3$ barras a $1\text{ AU}$, Masa `0.7 t`, Costo `240` | $+4$ barras a $1\text{ AU}$, retracción parcial, Costo `380` | $+5$ barras a $1\text{ AU}$, *Storm Safe* rápido, Costo `580` | $+6$ barras a $1\text{ AU}$, autorrotación y $+15\%$ a $1.52\text{ AU}$, Costo `860` |
| **Radiador Plegable de Amoníaco ($\text{NH}_3$)** | Rechaza `0.10` calor/s, fragilidad `1.0`, Costo `160` | Rechaza `0.15` calor/s, fragilidad `0.85`, Costo `280` | Rechaza `0.20` calor/s, válvula doble, Costo `420` | Rechaza `0.28` calor/s, lazo redundante, Costo `620` | Rechaza `0.38` calor/s, autosellante ante micro-impacto, Costo `900` |

### 3.4 `SOCKET_DORSAL_TURRET` (`Z = 3`, sombra `+2, +2 px`)

| Módulo / Rol | LVL 1 | LVL 2 | LVL 3 | LVL 4 | LVL 5 MAX |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Antena Parabólica DSN (S/X/Ka)** | Tx Ciencia `18 pts/s`, sensible a corte | Tx `28 pts/s`, seguimiento básico | Tx `42 pts/s`, banda X estabilizada | Tx `60 pts/s`, banda Ka alta ganancia | Tx `85 pts/s`, compensación automática de cabeceo |
| **Brazo Canadarm / Red Colectora** | Alcance `45 m`, captura lenta `4.0 s` | Alcance `65 m`, captura `3.0 s` | Alcance `85 m`, muestreo NEO preciso | Alcance `110 m`, `winch_uhmwpe` integrado | Alcance `135 m`, `net_supercond` con imán pasivo |
| **Giroscopio CMG / Telescopio** | $+15\%$ tasa de giro, saturación `6 s` | $+25\%$ giro, bloqueo `5 s` | $+35\%$ giro, escaneo óptico NEO | $+45\%$ giro (`cmg_stabilizer`), bloqueo `4 s` | $+60\%$ giro, desaturación automática RCS |

### 3.5 `SOCKET_AFT_ENGINES` (`Z = -1`, `-4 px` bajo faldón trasero)

| Propulsor | LVL 1 | LVL 2 | LVL 3 | LVL 4 | LVL 5 MAX |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Químico Hipergólico ($\text{MMH}/\text{N}_2\text{O}_4$)** | Empuje `42 kN`, $I_{sp}$ `310 s`, Masa `1.1 t`, Costo `200` | Empuje `56 kN`, $I_{sp}$ `315 s`, Costo `340` | Empuje `74 kN`, $I_{sp}$ `320 s`, tobera robusta, Costo `510` | Empuje `96 kN`, $I_{sp}$ `335 s`, reinicio ilimitado, Costo `760` | Empuje `122 kN`, $I_{sp}$ `355 s`, ciclo dual sin fuga, Costo `1080` |
| **Criogénico Alto Empuje ($\text{LH}_2/\text{LOX}$)** | Empuje `65 kN`, $I_{sp}$ `410 s`, desgaste alto, Costo `280` | Empuje `88 kN`, $I_{sp}$ `428 s`, Costo `440` | Empuje `115 kN`, $I_{sp}$ `442 s`, `damper_cryo_he` compat., Costo `660` | Empuje `145 kN`, $I_{sp}$ `452 s`, tobera **C-103 Niobio**, Costo `940` | Empuje `185 kN`, $I_{sp}$ `465 s`, turbobomba escalonada estabilizada, Costo `1320` |
| **Motor Iónico / Hall (Xenón)** | Empuje `8 kN` (escalado jugable), $I_{sp}$ `1800 s`, drena `2` barras | Empuje `12 kN`, $I_{sp}$ `2400 s`, drena `2` barras | Empuje `16 kN`, $I_{sp}$ `3100 s`, drena `3` barras | Empuje `22 kN`, $I_{sp}$ `3700 s`, drena `3` barras | Empuje `28 kN`, $I_{sp}$ `4190 s`, drena `3` barras (eficiencia extrema en crucero) |

## 4. Calidades de Pieza ("Agencia en Quiebra") y Reglas Visuales de Nivel

Las piezas compradas en subasta heredan multiplicadores reales definidos en `docs/MECANICAS-REFERENCIA.md`:

| Calidad | Rango de condición | Multiplicador costo / masa | Impacto visual y mecánico en nave |
| :--- | :---: | :---: | :--- |
| **`SCRAP` (Chatarra)** | `[0.30, 0.65]` | `0.85x` costo | Planchas oxidadas (`#78350f`), chispas aleatorias en consola y $+40\%$ probabilidad de incendio/fuga |
| **`USED` (Usada)** | `[0.60, 0.85]` | `1.00x` costo | Pintura rayada en aristas (`#64748b`), desgaste normal por horas de vuelo |
| **`NEW` (Nueva)** | `[0.86, 0.98]` | `1.05x` costo | Esmalte cerámico `#cbd5e1` / `#f8fafc` limpio, garantía nominal en ignición |
| **`LEGENDARY` (Anómala)** | `[0.95, 1.00]` | `1.40x` costo | Acabado dorado Kapton/halo cian + uno de los 4 mutadores (`gravimetric_injector`, `crystalline_alloy`, `entropic_sensor`, `quantum_tether`) |

## 5. Integración en Dique Seco (3 Barras de Decisión sin Ruido)

Para evitar parálisis por tablas largas en el hangar (`Pantalla 2` en `docs/DISEÑO-UI-NAVES-25D.md`), toda combinación de los 7 sockets reduce sus cálculos en vivo a únicamente **3 indicadores en el panel derecho**:

1. **Alcance $\Delta v$:** Calculado con Tsiolkovsky ($\Delta v_{disp} / \Delta v_{mision}$); exige $\ge 100\%$ para desbloquear salida sin advertencia crítica.
2. **Balance Energético en Destino:** Usa $S(r) = 1361 / r_{\text{AU}}^2$ del contrato seleccionado; si la nave depende de paneles solares hacia Júpiter ($3.7\%$), marca estado rojo bloqueante de advertencia.
3. **Riesgo de Despegue ($P_{explosion}$):** Evaluado en vivo desde masa total vs empuje nominal $M_{rated}$ y salud estructural $H_{struct}$; sugiere retirar carga o instalar `damper_cryo_he` antes de ir a rampa.
