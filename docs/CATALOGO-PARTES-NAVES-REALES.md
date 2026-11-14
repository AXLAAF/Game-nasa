# Catálogo Técnico de Partes y Hardware de Naves Espaciales Reales

**Proyecto:** `Margin Zero: Deuda Orbital` (*Margin Zero: Orbital Debt*)  
**Nave Insignia:** `MZ-1 BALLAST` (Chasis `Orbital Mule Mk-I`)  
**Programa de Misiones:** `BALLAST-1` a `BALLAST-N`  
**Fuentes de Datos del Juego:** [data/design/parts.json](../data/design/parts.json), [data/design/modules.json](../data/design/modules.json), [data/design/stack_parts.json](../data/design/stack_parts.json)

Este documento mapea cada componente jugable de **Margin Zero: Deuda Orbital** con su equivalente físico en ingeniería aeroespacial real (NASA, JPL, ESA y vehículos comerciales certificados), explicando los parámetros que gobiernan la simulación y el porqué técnico de cada ventaja y contrapartida. Las cifras institucionales verificables se marcan `[NASA]` y los parámetros escalados de balance del juego se marcan `[DIS]`.

---

## 1. Los 12 Perks y Subsistemas Especializados (`data/design/parts.json`)

Cada perk se acopla a uno de los 7 *hardpoints* tipados de `MZ-1 BALLAST` definidos en [01-CATALOGO-MODULOS-Y-EVOLUCION-NAVE.md](01-CATALOGO-MODULOS-Y-EVOLUCION-NAVE.md).

| ID en juego | Nombre | Hardpoint | Masa / Costo `[DIS]` | Fragilidad `[DIS]` | Efectos clave en simulación `[DIS]` |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `shield_hrsi` | Losetas Cerámicas HRSI | `SOCKET_BOW` | `1.8 t` / `320 cr` | `0.65` | `heat_absorb: 0.85`, `passive_cooling: 0.40` |
| `shield_pica` | Escudo Ablativo PICA-X | `SOCKET_BOW` | `1.2 t` / `280 cr` | `0.00` | `heat_absorb: 0.95`, `wear_per_use: 0.28` |
| `nozzle_niobium` | Tobera C-103 Niobio | `SOCKET_AFT_ENGINES` | `0.9 t` / `450 cr` | `1.00` | `isp_vac_add_s: +38 s`, `thrust_vac_mult: 1.18`, `atmo_cooling_penalty: 0.35`, `wear_mult: 2.2` |
| `staged_preburner` | Turbobomba Ciclo Escalonado | `SOCKET_AFT_ENGINES` | `2.4 t` / `600 cr` | `1.00` | `thrust_mult: 1.28`, `twr_mult: 1.22`, `ignition_risk_mult: 1.40`, `wear_per_use: 0.20` |
| `telemetry_strain` | Telemetría Analógica Galgas | `SOCKET_DORSAL_TURRET` | `0.5 t` / `140 cr` | `0.50` | `emp_immunity: 1.0`, `read_error: 0.06` |
| `damper_cryo_he` | Amortiguador Criogénico Pogo | `SOCKET_PORT_NACELLE` | `1.6 t` / `260 cr` | `0.50` | `maxq_stress_mult: 0.30`, `power_drain_kw: 0.12` |
| `insulation_mli` | Manta Multicapa Kapton | `SOCKET_WING_PORT` | `0.2 t` / `180 cr` | `0.80` | `cold_resist: 0.90`, `tear_q_pa: 12000.0` |
| `winch_uhmwpe` | Cabrestante Polímero UHMWPE | `SOCKET_STBD_NACELLE` | `0.7 t` / `290 cr` | `0.50` | `pull_kn: 55.0`, `speed_mult: 1.40`, `reach_m: 120.0`, `soften_temp: 0.70` |
| `net_supercond` | Red Colectora Superconductora | `SOCKET_STBD_NACELLE` | `1.4 t` / `480 cr` | `0.50` | `capture_radius_m: 35.0`, `battery_drain_s: 0.40`, `audio_noise: 0.25` |
| `radar_doppler` | Radar Doppler Pulso Ku | `SOCKET_BOW` | `0.6 t` / `310 cr` | `0.60` | `debris_warning_s: 14.0`, `power_drain_s: 0.08` |
| `cmg_stabilizer` | Giroscopio Momento Inercial | `SOCKET_DORSAL_TURRET` | `1.5 t` / `390 cr` | `0.50` | `turn_mult: 1.45`, `gimbal_lock_s: 4.0` |
| `radiator_ammonia` | Radiador Plegable Amoníaco | `SOCKET_WING_STBD` | `1.1 t` / `340 cr` | `1.00` | `cooling: 0.18` |

### 1.1 Protección Térmica y Entrada Atmosférica (`SOCKET_BOW`)

1. **Losetas Cerámicas HRSI (`shield_hrsi`)**
   - **Equivalente real `[NASA]`:** *High-Temperature Reusable Surface Insulation* (losetas LI-900 y LI-2200 del Sistema de Protección Térmica del Transbordador Espacial). Están compuestas en ~90% por aire atrapado dentro de una matriz rígida de fibras de sílice amorfa pura ($\sim 0.144\text{ g/cm}^3$ en LI-900) sellada con esmalte negro vítreo RCG (*Reaction Cured Glass*). Soportan temperaturas sostenidas de hasta $\sim 1260^\circ\text{C}$ ($2300^\circ\text{F}$) irradiando de vuelta más del 90% del calor convectivo hacia el exterior sin consumirse.
   - **Por qué tiene esa contrapartida en juego:** Su bajísima densidad las vuelve mecánicamente frágiles (`fragility: 0.65`) ante impactos de hielo, espuma aislante durante el ascenso o micrometeoroides (causa raíz de daños críticos documentada en el informe *CAIB Vol. 1* del Columbia STS-107 `[NASA]`). A cambio, ofrece enfriamiento pasivo por radiación (`passive_cooling: 0.40`) y reutilización entre misiones sin desgaste ablativo fijo.

2. **Escudo Ablativo PICA-X (`shield_pica`)**
   - **Equivalente real `[NASA]`:** *Phenolic-Impregnated Carbon Ablator* (desarrollado por NASA Ames Research Center para la cápsula *Stardust*, que reentró a $12.9\text{ km/s}$ en 2006 `[NASA]`, y adaptado en su variante PICA-X para Dragon y en el escudo monolítico/en losetas de *Curiosity* y *Perseverance* en Marte). Es una preforma de fibra de carbono de baja densidad impregnada con resina fenólica.
   - **Por qué tiene esa contrapartida en juego:** Resiste vibraciones de lanzamiento e impactos menores mucho mejor que la sílice cerámica (`fragility: 0.00`) y absorbe el pico térmico extremo (`heat_absorb: 0.95`), pero disipa el calor mediante **pirólisis y sublimación sacrificial** de la resina y del carbón superficial. Cada entrada atmosférica reduce el espesor útil del escudo (`wear_per_use: 0.28`), obligando a inspeccionar y reponer el activo entre vuelos.

### 1.2 Propulsión de Alto Rendimiento (`SOCKET_AFT_ENGINES`)

3. **Tobera de Niobio C-103 (`nozzle_niobium`)**
   - **Equivalente real `[NASA]`:** Campanas de expansión enfriadas por radiación fabricadas en aleación refractaria **C-103** ($\text{Nb}-10\text{Hf}-1\text{Ti}$), empleadas en el motor de descenso/ascenso del Módulo Lunar Apollo (LMDE/LMAE), el SPS de Apollo y la extensión del Falcon 9 Merlin Vacuum (`MVac`). Operan al rojo blanco ($\sim 1370\text{--}1650^\circ\text{C}$ `[NASA]`) sin requerir tubos pesados de refrigeración regenerativa, permitiendo relaciones de expansión altas en vacío.
   - **Por qué tiene esa contrapartida en juego:** En vacío puro entrega $+38\text{ s}$ de $I_{sp}$ y $+18\%$ de empuje, pero en presencia de atmósfera sufre **oxidación acelerada** de la aleación (si pierde su recubrimiento de disiliciuro) y **separación de flujo supersónico** dentro de una campana diseñada para vacío, generando cargas laterales violentas y sobrecalentamiento (`atmo_cooling_penalty: 0.35`, `wear_mult: 2.2`, `fragility: 1.00`).

4. **Turbobomba de Ciclo Escalonado (`staged_preburner`)**
   - **Equivalente real `[NASA]`:** Motores de combustión escalonada de alta presión como el **RS-25** del Transbordador Espacial / SLS (prequemadores duales ricos en combustible con presión de cámara $>20.6\text{ MPa}$ `[NASA]`) o ciclos cerrados ricos en oxígeno (RD-180). A diferencia de los motores de ciclo abierto (*gas generator*) que descargan el gas de turbina por la borda, el ciclo escalonado reinyecta el flujo completo en la cámara principal.
   - **Por qué tiene esa contrapartida en juego:** Sube el empuje y la relación empuje-peso (`thrust_mult: 1.28`, `twr_mult: 1.22`), pero exige `2.4 t` de turbomaquinaria masiva sometida a gradientes térmicos extremos, cavitación y sellos criogénicos críticos al arrancar (`ignition_risk_mult: 1.40`, `wear_per_use: 0.20`).

### 1.3 Aviónica, Estructura y Control Térmico

5. **Telemetría Analógica por Galgas (`telemetry_strain`)**
   - **Equivalente real `[NASA]`:** Puentes de Wheatstone con galgas extensiométricas resistivas (*strain gauges*) cableadas directamente a condicionadores analógicos FM/FM, estándar histórico en vuelos de prueba X-15, etapas Saturn V y monitoreo estructural de carga en lanzadores.
   - **Por qué tiene esa contrapartida en juego:** Al no depender de memoria RAM ni lógica CMOS digital de alta densidad, es inmune a cambios de bit por radiación (**SEU**) o pulsos electromagnéticos de tormentas solares DONKI (`emp_immunity: 1.0`). Sin embargo, sufre deriva térmica de cero e imprecisión de lectura analógica (`read_error: 0.06`).

6. **Amortiguador Criogénico Pogo (`damper_cryo_he`)**
   - **Equivalente real `[NASA]`:** Acumuladores de gas helio instalados en las líneas de succión de oxígeno líquido ($\text{LOX}$) de las etapas **S-IC** y **S-II** del Saturn V tras las oscilaciones longitudinales severas de Apollo 6 y Apollo 13 (monografía **NASA SP-8055** `[NASA]`). Introducen un volumen compresible de helio para desacoplar la frecuencia resonante de la columna de propelente respecto a la frecuencia estructural del fuselaje ($5\text{--}16\text{ Hz}$ `[NASA]`).
   - **Por qué tiene esa contrapartida en juego:** Reduce un $70\%$ el estrés estructural en Max-Q (`maxq_stress_mult: 0.30`), pero añade `1.6 t` de peso muerto y exige calentamiento/control continuo de válvulas (`power_drain_kw: 0.12`).

7. **Manta Multicapa Kapton / MLI (`insulation_mli`)**
   - **Equivalente real `[NASA]`:** *Multi-Layer Insulation* compuesto por 10 a 30 láminas de película de poliimida (Kapton, estable de $-269^\circ\text{C}$ a $+400^\circ\text{C}$ `[NASA]`) o Mylar aluminizado separadas por mallas de dacrón de baja conductancia. Es la "lámina dorada" visible en el módulo lunar Apollo, el parasol del JWST y la cara externa de satélites interplanetarios.
   - **Por qué tiene esa contrapartida en juego:** Aísla casi por completo la radiación infrarroja en espacio profundo (`cold_resist: 0.90`) con apenas `0.2 t`, pero carece de resistencia al cizallamiento aerodinámico: fuera de cofia y bajo presión dinámica $q > 12\,000\text{ Pa}$ (`tear_q_pa: 12000.0`), las láminas delgadas se desgarran.

8. **Radiador Plegable de Amoníaco (`radiator_ammonia`)**
   - **Equivalente real `[NASA]`:** Paneles radiadores desplegables del *External Active Thermal Control System* (EATCS) de la Estación Espacial Internacional, por los que circula **amoníaco anhidro ($\text{NH}_3$)** líquido hacia tubos de pared delgada de alta emisividad infrarroja.
   - **Por qué tiene esa contrapartida en juego:** Como en el vacío no existe convección externa, toda disipación térmica obedece la ley de Stefan-Boltzmann ($Q = \epsilon\sigma A T^4$). Su gran superficie expuesta con conductos presurizados lo convierte en el blanco más vulnerable a micrometeoroides y basura orbital (`fragility: 1.00`), tal como ocurrió en la fuga de refrigerante de la **Soyuz MS-22** en diciembre de 2022 (`NASA ODPO` `[NASA]`).

### 1.4 Sensores, Actitud y Captura Orbital

9. **Radar Doppler de Pulso Banda Ku (`radar_doppler`)**
   - **Equivalente real `[NASA]`:** Radares de encuentro y descenso terminal en banda Ku / Ka (radar del Módulo Lunar Apollo, sistema de encuentro Ku-band del Transbordador Espacial y el *Terminal Descent Sensor* de *Curiosity* y *Perseverance*). Mide distancia y velocidad radial relativa mediante desplazamiento Doppler.
   - **Por qué tiene esa contrapartida en juego:** Brinda al Oficial de Radar `14 s` de alerta anticipada sobre fragmentos hiperveloces CelesTrak (`debris_warning_s: 14.0`), pero la emisión activa de microondas exige potencia continua del reactor (`power_drain_s: 0.08`) y expone el domo frontal en `SOCKET_BOW`.

10. **Giroscopio de Momento de Control (`cmg_stabilizer`)**
    - **Equivalente real `[NASA]`:** *Control Moment Gyroscopes* de doble cardán (la ISS opera 4 CMG girando a $6600\text{ rpm}$ con un par combinado de $\sim 258\text{ N}\cdot\text{m}$ `[NASA]`; también usados en Skylab y telescopios espaciales). Permiten rotar la nave intercambiando momento angular con electricidad solar/RTG sin gastar propelente RCS.
    - **Por qué tiene esa contrapartida en juego:** Los torques externos continuos acumulan momento hasta llevar los cardanes a alineación coplanar (**saturación / gimbal lock**). Cuando esto sucede, el sistema queda bloqueado `4.0 s` (`gimbal_lock_s: 4.0`) mientras los propulsores RCS queman para desaturar el giroscopio.

11. **Cabrestante de Polímero UHMWPE (`winch_uhmwpe`)**
    - **Equivalente real `[NASA]`:** Cables trenzados de polietileno de peso molecular ultraalto (fibras tipo Spectra/Dyneema usadas en experimentos de cables orbitales como **NASA SEDS-1 / SEDS-2** y líneas de anclaje EVA). Tienen una relación resistencia-peso $\sim 10\times$ superior al acero.
    - **Por qué tiene esa contrapartida en juego:** A pesar de su tenacidad en frío, los polímeros de polietileno pierden resistencia mecánica por fluencia térmica mucho antes que los metales (reblandecimiento notable por encima de $\sim 80\text{--}120^\circ\text{C}$, modelado como `soften_temp: 0.70`).

12. **Red Colectora Superconductora (`net_supercond`)**
    - **Equivalente real `[NASA]` / `[DIS]`:** Redes activas de captura orbital no cooperativa (demostrador *RemoveDEBRIS* en LEO, amarres electrodinámicos *KITE* y conceptos NASA NIAC de frenado por corrientes de Foucault mediante bobinas superconductoras).
    - **Por qué tiene esa contrapartida en juego:** Amplía el radio efectivo de captura (`capture_radius_m: 35.0`), pero alimentar las bobinas y el criostato/actuadores consume `0.40/s` de batería e induce interferencia electromagnética sobre las comunicaciones (`audio_noise: 0.25`).

---

## 2. Los 9 Módulos Base del Vehículo Orbital y EDL (`data/design/modules.json`)

Además de los 12 perks, el taller equipa subsistemas fundamentales de potencia, propulsión auxiliar y descenso planetario sobre `MZ-1 BALLAST` (chasis base `Orbital Mule Mk-I`: `11.0 t` en seco, `17.0 t` de propelente hipergólico a $I_{sp} = 316\text{ s}$ y `420 kN` de empuje).

| ID en juego | Nombre | Masa / Costo `[DIS]` | Efecto en juego `[DIS]` | Hardware real equivalente y regla física NASA |
| :--- | :--- | :---: | :--- | :--- |
| `solar_panel` | Panel solar | `0.4 t` / `120 cr` | `solar_units: 2.0` | **Celdas fotovoltaicas multijuntura ($\text{GaInP/GaAs/Ge}$):** Eficiencia inicial BOL $29\text{--}32\%$ `[NASA]`. Su salida cae con la ley del inverso del cuadrado $S(r) = 1361 / r_{\text{AU}}^2$: `100%` en Tierra/Luna, `43.3%` en Marte ($1.52\text{ AU}$) y apenas `3.7%` en Júpiter ($5.20\text{ AU}$) `[NASA]`. |
| `rtg` | Generador RTG | `1.0 t` / `700 cr` | `rtg_units: 1.5`, `heat: +0.05` | **MMRTG (*Multi-Mission Radioisotope Thermoelectric Generator*):** Usa $4.8\text{ kg}$ de dióxido de plutonio ($\text{PuO}_2$, isótopo $^{238}\text{Pu}$, vida media $87.7\text{ años}$) y termopares $\text{PbTe/TAGS}$ para entregar $\sim 110\text{ W}$ eléctricos continuos independientes del Sol, generando $\sim 1890\text{ W}$ de calor residual constante (`Curiosity`, `Perseverance`, `Cassini`, `Galileo`) `[NASA]`. |
| `battery` | Batería | `0.5 t` / `150 cr` | `buffer_units: 1.0` | **Bancos secundarios Li-Ion calificados para espacio (estándar NASA JSC-20793):** Absorben picos de descarga durante eclipses planetarios, encendidos de radar o apagones temporales sin depender del generador principal. |
| `antenna_hg` | Antena de alta ganancia | `0.3 t` / `220 cr` | `delay_mult: 0.75` | **Antena Parabólica HGA en bandas X ($8.4\text{ GHz}$) y Ka ($32\text{ GHz}$):** Enlaza con las estaciones de $34\text{ m}$ y $70\text{ m}$ de la **NASA Deep Space Network (DSN)** en Goldstone, Madrid y Canberra. Aunque no acelera la velocidad de la luz $c$, reduce la pérdida por retransmisión y comprime la ventana de enlace/buffer (`delay_mult: 0.75` `[DIS]`). |
| `parachute` | Paracaídas | `0.3 t` / `160 cr` | `chute: 1.0` | **Paracaídas supersónico *Disk-Gap-Band* (DGB):** Usado en `Viking`, `Pathfinder`, `Curiosity` y `Perseverance` para frenar en la tenue atmósfera marciana ($P = 0.0064\text{ bar}$ `[NASA]`). Exige atmósfera; en la Luna o Ganímedes ($P = 0.0\text{ bar}$) es peso muerto inútil. |
| `landing_legs` | Patas de aterrizaje | `0.5 t` / `140 cr` | `touchdown_tolerance_ms: +1.5` | **Tren telescópico con panal de aluminio aplastable (*crushable honeycomb*):** Tecnología del Módulo Lunar Apollo (`LM`) y trenes compuestos de aterrizaje planetario. Absorbe energía cinética de impacto vertical deformando el núcleo alveolar interno de forma controlada. |
| `extra_tank` | Tanque extra | `0.6 t` / `180 cr` | `propellant_t: +4.0 t` | **Tanques auxiliares $\text{Al-Li 2195}$ / COPV:** Aleación aluminio-litio ($\rho \approx 2.71\text{ g/cm}^3$ `[NASA]`, heredada del *Super Lightweight Tank* del Shuttle) o tanques sobre-envueltos en fibra de carbono (COPV) con deflectores internos *anti-slosh* para evitar chapoteo del propelente. |
| `cargo_bay` | Bodega ampliada | `0.8 t` / `100 cr` | `cargo_t: +2.0 t` | **Módulo de carga paletizada (herencia MPLM / Spacehab):** Estructuras modulares presurizadas o palés externos con pernos pirotécnicos frangibles que permiten ejecutar `jettison_cargo` en emergencias de despegue. |
| `backup_system` | Sistema de respaldo | `1.2 t` / `260 cr` | `redundancy: 1.0` | **Computación endurecida contra radiación (BAE RAD750 + EDAC + TMR):** Procesadores resistentes a dosis totales de $200\text{--}1000\text{ krad}$ (`Juno`, `Curiosity`, `JWST` `[NASA]`) con memoria correctora de errores (EDAC) y votación triple modular (TMR) para aislar fallos lógicos tras tormentas solares. |

**Variantes estructurales de chasis en `modules.json`:** Además de `Orbital Mule Mk-I` (casco base de `MZ-1 BALLAST`), existen dos variantes de campaña: `Barcaza Ceres` (`dry_mass_t: 12.5`, `propellant_t: 19.0`, `cargo_capacity_t: 4.0`, `thrust_kn: 450.0`) inspirada en cargueros pesados de reabastecimiento (ATV/Cygnus/HTV) y `Saltamontes` (`dry_mass_t: 9.0`, `propellant_t: 15.0`, `cargo_capacity_t: 1.5`, `isp_s: 330.0`) inspirada en demostradores ligeros VTVL de alta eficiencia en vacío.

---

## 3. Las 14 Piezas del Vehículo Lanzador y Ensamblaje Vertical (`data/design/stack_parts.json`)

Para la fase de ensamblaje de cohete en rampa (masa máxima nominal en plataforma `80 000 kg`, $\Delta v$ objetivo a órbita baja `3400 m/s` `[DIS]`), las piezas representan elementos reales de arquitectura multietapa:

| ID en juego | Nombre | Categoría | Specs (`mass` / `joint_n` / clave) `[DIS]` | Hardware real equivalente y principio físico |
| :--- | :--- | :---: | :--- | :--- |
| `capsule` | Cápsula de carga | `capsule` | `1200 kg`, `400 kN`, `cd: 0.20`, `escape: true` | **Vehículo de reentrada romo con Torre de Escape (LES):** Perfil aerodinámico de choque separado (*detached bow shock*, legado Mercury/Apollo/Orion) que disipa energía térmica en el aire comprimido delante del escudo y permite separar la carga en rampa ante explosión inminente. |
| `fairing` | Ojiva | `aero` | `280 kg`, `250 kN`, `cd: 0.15`, `area: 1.2` | **Cofia bipartita compuesta (*Payload Fairing*):** Carenado aerodinámico de fibra de carbono sobre núcleo alveolar que protege cargas frágiles y mantas MLI de la presión dinámica Max-Q ($q = \frac{1}{2}\rho v^2$) y del calentamiento acústico ($>140\text{ dB}$ SPL `[NASA]`) hasta superar los ~40–100 km. |
| `tank_s` | Tanque corto | `tank` | `400 kg` seco, `4000 kg` comb., `500 kN` | **Tanque estructural monobloque FSW:** Cilindro de aluminio-litio soldado por fricción-agitación (*Friction Stir Welding*), con mamparos semiesféricos para soportar presiones de tanque y carga axial de aceleración. |
| `tank_m` | Tanque medio | `tank` | `800 kg` seco, `12000 kg` comb., `700 kN` | **Tanque principal de primera/segunda etapa:** Incrementa la fracción de masa de propelente en la ecuación de Tsiolkovsky ($\Delta v = I_{sp} g_0 \ln(m_{wet}/m_{dry})$) aumentando el momento flector ante vientos en altura. |
| `tank_wide` | Tanque ancho | `tank` | `1400 kg` seco, `20000 kg` comb., `diam: 2.5 m`, `900 kN` | **Tanque de núcleo ancho (*Common Core Booster*):** Al pasar de `1.5 m` a `2.5 m` de diámetro incrementa el volumen útil cuadráticamente mientras reduce la esbeltez ($L/D$), disminuyendo el riesgo de pandeo estructural en ascenso. |
| `engine_mule` | Motor Mule | `engine` | `900 kg`, `280 kN`, `Isp SL 280 s / Vac 320 s` | **Motor atmosférico de primera etapa (*Sea-Level Booster*):** Tobera de relación de expansión moderada ($\epsilon \approx 12\text{--}20$) optimizada para operar a $101.3\text{ kPa}$ en despegue sin separación destructiva de flujo en las paredes de la campana. |
| `engine_vac` | Motor de vacío | `engine` | `350 kg`, `45 kN`, `Isp SL 180 s / Vac 340 s` | **Motor de etapa superior (*Vacuum Engine*, RL10 / MVac):** Campana ancha de alta expansión para aprovechar la presión ambiental nula en órbita (`Isp Vac 340 s`). Su rendimiento cae drásticamente al nivel del mar (`Isp SL 180 s`). |
| `engine_scrap` | Motor de chatarra | `engine` | `1100 kg`, `200 kN`, `Isp SL 240 s / Vac 270 s`, `rel: 0.62` | **Propulsor excedente sin recertificación NDT:** Basado en hardware almacenado de ciclo simple con toberas fatigadas o inyectores desalineados; baja fiabilidad de ignición (`0.62`) y alto peso muerto. |
| `coupler` | Acoplador de etapa | `coupler` | `180 kg`, `350 kN`, `rel: 0.90` | **Anillo interetapa con actuadores pirotécnicos / neumáticos:** Une etapas en serie y ejecuta separación limpia mediante pernos frangibles o iniciadores estándar NASA (*NSI*) tras el corte del motor principal (*MECO*). |
| `coupler_weak` | Acoplador flojo | `coupler` | `90 kg`, `80 kN`, `rel: 0.55` | **Unión estructural subdimensionada:** Limite de carga axial bajo (`80 kN`); susceptible a fallar por esfuerzo cortante durante el pico Max-Q o ante cabeceos bruscos. |
| `fin` | Aleta | `aero` | `40 kg`, `50 kN`, `cd: 0.90`, `simetría: 4` | **Estabilizadores aerodinámicos de cola:** Desplazan el **Centro de Presión (CP)** detrás del **Centro de Gravedad (CG)** para dar estabilidad estática pasiva al atravesar la tropopausa y ráfagas laterales. |
| `gyro` | Giroscopio | `control` | `80 kg`, `80 kN`, `torque: 12.0` | **Unidad de Ruedas de Reacción / IMU de guía:** Provee par de control fino y referencia inercial (*pitch/roll*) en fase exo-atmosférica cuando las aletas pierden aire para actuar. |
| `adapter` | Adaptador de diámetro | `structure` | `220 kg`, `600 kN`, `diam: 2.5 m`, `adapter: true` | **Cono interetapa SLA (*Spacecraft-to-Launch Vehicle Adapter*):** Transición cónica rígida (herencia Saturn V SLA / Ariane) que distribuye uniformemente los esfuerzos axiales entre cuerpos de `2.5 m` y etapas superiores de `1.5 m`. |
| `strut` | Refuerzo | `structure` | `260 kg`, `1200 kN`, `rel: 0.97` | **Puntales y cerchas estructurales de refuerzo:** Vigas tubulares de aluminio/titanio o compuesto que triplican la rigidez axial en juntas críticas (`joint_n: 1200 kN`) evitando el pandeo por compresión en Max-Q. |

---

## 4. Hardware Real dentro de las 6 Salas Interiores de `MZ-1 BALLAST`

El interior caminable de `MZ-1 BALLAST` (`160 x 224 px` / `12 x 8` celdas lógicas en [data/design/modules.json](../data/design/modules.json) y [03-INTERIOR-FTL-TRIPULACION-Y-CRISIS.md](03-INTERIOR-FTL-TRIPULACION-Y-CRISIS.md)) distribuye los 7 subsistemas del *NASA Systems Engineering Handbook* (`NASA/SP-2016-6105`) en 6 compartimentos presurizados más el pasillo central:

| Sala (`id`) | Cuadrante `DamageMatrix` | Hardware real representado en cabina | Consecuencia física del daño en la sala |
| :--- | :---: | :--- | :--- |
| `helm` (Timón / Puente) | `top` | **FDAI ("8-Ball" NavBall)**, controladores manuales rotacional (**RHC**) y traslacional (**THC**), panel maestro de alarmas (*Caution & Warning*), pantallas de guiado GNC. | Pérdida de precisión de actitud, deterioro de `vision` y pérdida de estabilidad en corredor de reentrada. |
| `sensors` (Sensores / Comms) | `top` | **Rastreadores estelares (*Star Trackers*)**, transpondedor de espacio profundo (**SDST**), procesador de radar Ku y computadora de vuelo tolerante a radiación (**RAD750**). | Ceguera del radar de largo alcance (`map`), congelamiento por SEU en tormenta solar y caída de enlace DSN (`comms`). |
| `reactor` (Núcleo / Energía) | `middle` | **Bus eléctrico primario DC** ($28\text{ V} / 120\text{ V}$), módulos de control remoto de potencia (**RPCM**) y disyuntores de estado sólido que reparten las 7 barras disponibles. | Apagón de iluminación (`light`), pérdida de potencia asignable y sobrecarga en cadena sobre el resto de consolas. |
| `life_support` (Soporte Vital) | `middle` | **ECLSS y lazo térmico interno:** ventilación forzada (que también refrigera por convección a la tripulación robótica, evitando el estrangulamiento térmico en vacío), depuradores $\text{LiOH}$ / zeolita **CDRA**, electrólisis **OGS** e intercambiador agua-$\text{NH}_3$. | Caída de presión/refrigeración convectiva (`mobility`), acumulación térmica hacia umbral de apagado (15–30 s `[DIS]`) y riesgo de propagación de incendios por ductos (*NASA Saffire*). |
| `engines` (Motores / Popa) | `bottom` | **Colectores de propelente**, válvulas de aislamiento de MMH/N2O4 o criogénicos, botellas de helio de presurización, inyectores *pintle* y sensores de vibración pogo. | Caída de empuje (`thrust`) y fuga continua de combustible (`fuel_leak_rate`), reduciendo el $\Delta v$ disponible para inserción y regreso. |
| `science_bay` (Bahía / Bodega) | `radial` | **Controlador de brazo robótico (Canadarm)**, contenedores herméticos de retorno de muestras, consola de telemetría científica y **esclusas de venteo al vacío (*airlocks*)**. | Pérdida de captura científica, estática en alarmas (`audio`) y bloqueo de enlace de descarga de paquetes de ciencia (`comms`). |

---

## 5. Calidades de Pieza, Degradación Física y Mutadores

### 5.1 Significado Físico de las 4 Calidades (`data/design/parts.json`)

En una naviera en quiebra (*Margen Cero Astrologística*), la condición `cond` representa la vida remanente ante fatiga cíclica, microfisuras térmicas y certificación de vuelo:

| Calidad | Peso base / Rango `cond` | Multiplicador efecto / precio `[DIS]` | Correlato real de ingeniería aeroespacial |
| :--- | :---: | :---: | :--- |
| `SCRAP` (Chatarra) | `w_base: 0.38`, `cond: 0.30–0.65` | `mult: 0.85`, `price: 0.45x` | Hardware sin trazabilidad, recuperado de chatarra o fuera de vida límite (*expired life-limited parts*), con sellos elastoméricos resecos, corrosión galvánica y sin ensayos no destructivos (ultrasonido/rayos X). |
| `USED` (Usada) | `w_base: 0.34`, `cond: 0.60–0.85` | `mult: 1.00`, `price: 0.75x` | Pieza **Flight-Proven** reutilizada dentro de márgenes comerciales (equivalente a componentes de clase C/D sometidos a ciclos térmicos y acústicos previos pero funcionales). |
| `NEW` (Nueva) | `w_base: 0.18`, `cond: 0.86–0.98` | `mult: 1.05`, `price: 1.00x` | Hardware nuevo de fábrica con pruebas de aceptación (**ATP**: vibración aleatoria, vacío térmico y prueba de fugas con helio), equivalente a estándares de calificación **NASA Class B/A**. |
| `LEGENDARY` (Anómala) | `w_base: 0.10`, `cond: 0.95–1.00` | `mult: 1.40`, `price: 1.60x` | Prototipos experimentales clasificados fuera de catálogo estándar que combinan tolerancia máxima con uno de los 4 mutadores de alto riesgo `[DIS]`. |

### 5.2 Los 4 Mutadores Experimentales `[DIS]` (`data/design/parts.json`)

1. **`gravimetric_injector` (Propulsión):** $+65\%$ empuje y $-30\%$ consumo, a cambio de $8\%$ de probabilidad de inversión transitoria de empuje en encendidos prolongados.
2. **`crystalline_alloy` (Estructura):** autorreparación estructural pasiva ($0.04/\text{min}$), pero triplica la fragilidad ante radiación ionizante (fragilización por desplazamiento atómico en red cristalina).
3. **`entropic_sensor` (Sensores):** revela puntos de interés y suma $+45\text{ s}$ de aviso ante eventos solares, drenando $0.05\text{ energía/s}$ constantes e inyectando estática.
4. **`quantum_tether` (Captura / Salvamento):** cable irrompible, con riesgo real de mecánica clásica de cuerpos acoplados: transfiere el momento lineal completo a `MZ-1 BALLAST` si la masa capturada supera la de la propia nave.

---

## 6. Referencias Técnicas Verificables

1. **NASA Systems Engineering Handbook:** NASA/SP-2016-6105 Rev. 2 (`https://www.nasa.gov/reference/systems-engineering-handbook/`).
2. **NASA Planetary Fact Sheet (NSSDCA):** `https://nssdc.gsfc.nasa.gov/planetary/factsheet/` (gravedad, presiones atmosféricas, alturas de escala e irradiancia solar).
3. **NASA MMOD Shielding Design Handbook:** NASA/TM-2009-214786 (escudos Whipple y Stuffed Whipple frente a hipervelocidad).
4. **Coupled Structure-Propulsion Instability (Pogo):** NASA SP-8055 (acumuladores criogénicos de helio en Saturn V).
5. **Columbia Accident Investigation Board (CAIB):** *Report Volume 1*, NASA, agosto de 2003 (fragilidad ante impactos de losetas HRSI y paneles RCC).
6. **NASA Space Flight Human-System Standard Vol. 2:** NASA-STD-3001 (ECLSS, presión de cabina, $\text{LiOH}$/CDRA y tiempos de descompresión).
7. **NASA Orbital Debris Program Office (ODPO):** *Orbital Debris Quarterly News* Vol. 27(1) (fuga de refrigerante en radiador de Soyuz MS-22) y Vol. 13(2) (Iridium 33–Cosmos 2251).
8. **NASA Glenn & Ames Research Centers:** Especificaciones públicas del generador **MMRTG** ($\text{PuO}_2$, $110\text{ W}_e$ / $2000\text{ W}_{th}$) y del ablativo **PICA** (*Stardust* / *MSL*).
