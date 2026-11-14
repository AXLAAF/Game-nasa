# Identidad de Marca y Nomenclatura: Margin Zero

**Proyecto:** `Margin Zero: Deuda Orbital` (`Margin Zero: Orbital Debt`)  
**Nave Insignia:** `MZ-1 LIBERTY` (Chasis serie `Orbital Mule Mk-I`)  
**Programa de Vuelos:** `LIBERTY-1` a `LIBERTY-N`  
**Reto Objetivo:** NASA International Space Apps Challenge — *Space Mission Design Game*

## 1. Arquitectura Verbal y Nomenclatura Oficial

La identidad separa claramente la marca del juego, la matrícula física del casco único que evoluciona en el Dique Seco y el código secuencial de cada misión asignada.

| Nivel | Español (Local / UI) | Inglés (NASA Global Judging) | Uso en el proyecto |
| :--- | :--- | :--- | :--- |
| **Nombre principal** | **Margin Zero** | **Margin Zero** | Portada, ejecutable, título de ventana y cabecera de repositorio. |
| **Título completo** | **Margin Zero: Deuda Orbital** | **Margin Zero: Orbital Debt** | Pantalla de inicio, cápsula de presentación, pitch y documentación maestra. |
| **Tagline** | *Ingeniería de misiones espaciales sin margen de error ni de presupuesto* | *Space Mission Design with Zero Engineering or Financial Margin* | Subtítulo para la ficha pública de NASA Space Apps Challenge. |
| **Naviera (Lore)** | **Margen Cero Astrologística (En Síndico de Quiebra)** | **Margin Zero Astrologistics (In Receivership)** | Membrete de contratos en Pantalla 1 y de liquidación financiera en Pantalla 5. |
| **Nave (Casco único)** | `MZ-1 LIBERTY` *(Chasis `Orbital Mule Mk-I`)* | `MZ-1 LIBERTY` *(Chassis `Orbital Mule Mk-I`)* | Matrícula de activo embargado (`MZ-1`). Es un único casco persistente que evoluciona de `LVL 1` a `LVL 5 MAX`. |
| **Misiones base** | `LIBERTY-1` a `LIBERTY-4` | `LIBERTY-1` to `LIBERTY-4` | Designación oficial de los 4 contratos NASA asignados al casco `MZ-1 LIBERTY`. |
| **Reintentos de campaña** | `LIBERTY-5 .. LIBERTY-N` | `LIBERTY-5 .. LIBERTY-N` | Contador correlativo que incrementa `N` tras pérdida total o aborto en Max-Q; registra en cuántos vuelos se liquidó la deuda. |
| **Protocolo de parches** | **Protocolo Poliimida-Au** *(Cinta Dorada)* | **Polyimide-Au Protocol** *(Gold Tape Patch)* | Mecánica interna de reparación de emergencia que evita usar marcas comerciales registradas de terceros en el título. |

### 1.1 Mapa de Misiones del Programa `LIBERTY-N`

| Código de Vuelo | Contrato NASA y Dataset | Reto Físico Principal |
| :--- | :--- | :--- |
| **`LIBERTY-1`** | **Órbita Lunar** (*Artemis Relay*) | $\Delta v$ moderado (`4100 m/s`), retardo DSN `2.56 s` RTLT, calibración de las 7 barras del reactor. |
| **`LIBERTY-2`** | **Órbita Baja / NEO** (*JWST, DART & 2024 PDC25*) | Enjambres de basura espacial LEO (CelesTrak), tormentas solares DONKI y desvío o muestreo de asteroides (`Bennu`, `Didymos`, `Eros`, `Psyche`). |
| **`LIBERTY-3`** | **Marte** (*Mars Sample Return*) | Irradiancia solar al `~43.3%`, corredor de reentrada atmosférica (`0.0064 bar`) con escudo PICA + paracaídas y latencia DSN media (`1501 s`). |
| **`LIBERTY-4`** | **Júpiter / Europa** (*Clipper*) | Irradiancia solar crítica al `~3.7%` (`5.20 AU`, exige MMRTG obligatorio), cinturones de radiación joviana y latencia DSN (`5193 s`). |
| **`LIBERTY-5..N`** | **Vuelos de Recuperación** | Cualquier contrato reintentado tras pérdida o aborto de `MZ-1 LIBERTY` incrementa el número de vuelo `N` en el expediente de quiebra. |

## 2. Respaldo Histórico de `LIBERTY` en Ingeniería Aeroespacial

El nombre de la nave y del programa conecta con tres antecedentes reales relevantes para la cultura técnica de la NASA y para el humor seco de una agencia en quiebra:

1. **Cápsula `Liberty Bell 7` (NASA Mercury-Redstone 4, 1961):** Pilotada por Virgil "Gus" Grissom, llevaba pintada una grieta simbólica; su escotilla explosiva se activó prematuramente tras el amarizaje e inundó el vehículo, referencia directa a las mecánicas de brecha de casco y ventilación de esclusas (*airlocks*).
2. **Cohete `Liberty` (ATK / Astrium para NASA CCDev, 2011):** Propuesta comercial real presentada ante la NASA que buscaba abatir costos reutilizando segmentos de impulsores del Transbordador Espacial combinados con etapas del Ariane 5.
3. **Buques `Liberty` (*Liberty Ships*, década de 1940):** Cargueros producidos en serie bajo presupuesto restringido y soldadura rápida, célebres por sufrir fracturas estructurales bajo tensión extrema y depender de reparaciones continuas en tránsito.

## 3. Isotipo, Tokens Cromáticos y Reglas Tipográficas

### 3.1 Isotipo: Cota de Tolerancia Cero (`PE 0.0`)

El logotipo sustituye clichés de ciencia ficción militar por un diagrama astrofísico de precisión intervenido por una cota de embargo contable:

- **Geometría del isotipo:** Una órbita elíptica fina en crema técnico (`#f4ebd9`, grosor `2 px`) cuyo periapsis (`PE 0.0`) roza tangencialmente un círculo de límite atmosférico en terracota (`#c83e2b`). En el punto exacto de tangencia se cruza una cota de calibración `[ 0.0 ]` acompañada por la banda tricolor retro-NASA de tres trazos oblicuos (`#c83e2b`, `#f09c14`, `#38bdf8`) derivada de `pin_18` (*Rhine Lab / Lone Trail*).
- **Composición tipográfica (Opción Editorial):** `Margin Zero` en *sentence case* con sans geométrica SemiBold `600` en crema `#f4ebd9`, acompañado de telemetría numérica en monospace tabular terracota `#c83e2b` (`[Δv MARGIN: 0.00%]`).
- **Composición tipográfica (Opción Esténcil de Dique Seco):** Rótulo principal en un único nivel de mayúsculas con tracking `+0.06em` (`MARGIN ZERO`) y subtítulo inferior en *sentence case* sin tracking (`Deuda Orbital`, `#8b9bb4`).

### 3.2 Paleta Cromática de Marca

Reutiliza los tokens oficiales de [DISEÑO-UI-NAVES-25D.md](DISEÑO-UI-NAVES-25D.md):

| Token | Hex | Significado y Uso de Marca |
| :--- | :--- | :--- |
| `void_deep` | `#080c16` | Lienzo primario de marca; fondo espacial base y contraste APCA máximo con crema técnico. |
| `surface_chassis` | `#0f1726` | Bastidores diegéticos, encabezados de expediente y paneles de control. |
| `surface_raised` | `#172236` | Bloques de módulo activos, salas seleccionadas y estados elevados. |
| `surface_active_band` | `#1e2d47` | Banda de selección continua sin recuadros flotantes. |
| `ink_cream` | `#f4ebd9` | Logotipo `Margin Zero`, cónicas keplerianas, arcos orbitales y papel de informe técnico. |
| `ink_muted` | `#8b9bb4` | Unidades físicas, subtítulos secundarios y guías de escala. |
| `accent_terracotta` | `#c83e2b` | Color del margen cero y de la deuda: sellos de impago, límite Max-Q, corte atmosférico y alerta de `5.0 s`. |
| `accent_amber` | `#f09c14` | Color de energía y austeridad: barras de reactor (`7` disponibles), cinta dorada de poliimida y botón primario. |
| `accent_cyan` | `#38bdf8` | Color de rigor NASA/JPL: datos reales (`DSN`, `DONKI`, `SBDB`, `CelesTrak`), radar 3D wireframe y telemetría nominal. |
| `status_ok` | `#22c55e` | Sistema nominal, vector Prograde alineado en NavBall y estado validado en *Debrief*. |
| `outline_pixel` | `#0b0e17` | Contorno unificador `1 px` del `CanvasGroup` del casco `MZ-1 LIBERTY` y división de mamparos. |

### 3.3 Reglas Tipográficas y Anti-Patrones

- **Prohibición de fuente:** Se mantiene prohibida de forma absoluta la fuente vetada en [AGENTS.md](../AGENTS.md) en cualquier escena, tema `.tres`, script, SVG o documento.
- **Jerarquía de fuentes:**
  - **Marca, encabezados y rótulos operativos:** Sans-serif geométrica limpia (`Noto Sans`, `Inter` o `Liberation Sans`), mínimo `12 px` (`13–14 px` en controles y `28–36 px` en cabezal de portada).
  - **Telemetría numérica exclusivamente:** Monospace tabular (`IBM Plex Mono`, `Liberation Mono` o `DejaVu Sans Mono`), mínimo `11 px`, reservada solo a cifras reales (`4100 m/s`, `AP 340 km`, `P_exp 38.4%`, `T-04.8s`, `DEUDA: -42,500 CR`).
- **Anti-patrones bloqueados:** Cero tarjetas con borde blanco genérico, cero filas de KPIs flotantes, cero breadcrumbs, cero iconos sin etiqueta de texto y nunca más de un nivel de mayúsculas con tracking amplio.

## 4. Tono de Comunicación y Microcopy Diegético

La voz combina el lenguaje seco de los manuales de operaciones de vuelo del JPL con avisos de embargo financiero:

- **Pantalla 1 (Mapa Astrofísico):** *"Expedientes de Licitación Pública // Flota Hipotecada `MZ-1 LIBERTY` — Misión `LIBERTY-4` (Júpiter 5.20 AU): flujo solar al 3.7%. Operar sin MMRTG anula la póliza de cobertura."*
- **Pantalla 2 (Dique Seco Modular):** Barras de decisión etiquetadas como `Margen de Masa`, `Margen de Reactor (7/12 barras)` y `Riesgo de Pérdida en Rampa (P_exp)`; niveles desde `LVL 1 · Saldo de Chatarra` hasta `LVL 4 · Excedente NASA`.
- **Pantallas 3 y 4 (Vuelo Dual y Max-Q):** Alertas críticas breves de `5.0 s` (`"[T-04.9s] Margen térmico agotado en Motores — Ventilar esclusa o asumir pérdida del activo MZ-1"`).
- **Pantalla 5 (Expediente Causal Post-Misión):** *"Auditoría Física y Liquidación de Deuda — Vuelo `LIBERTY-N` (`MZ-1 LIBERTY`)"*, contrastando evidencia NASA/JPL contra el balance bancario de la agencia.
