# Investigación Técnica: Arquitectura de Naves Espaciales, Física de Fallos e Incidentes Reales Documentados

> Anexo C del proyecto, transcrito literal.

**Proyecto:** `Margin Zero: Deuda Orbital` (*Margin Zero: Orbital Debt* — Nave `MZ-1 BALLAST`, programa `BALLAST-1..N`)  
**Propósito:** Respaldar con ingeniería aeroespacial real y reportes oficiales (NASA, ESA, Roscosmos, NOAA SWPC) cada subsistema, mecánica de avería, peligro ambiental y *perk* del simulador.

## 1. Arquitectura de Naves Espaciales Reales y los 7 Subsistemas Críticos

Todo vehículo espacial tripulado o no tripulado que opera fuera de la atmósfera integra siete subsistemas acoplados definidos en el estándar *NASA Systems Engineering Handbook* (NASA/SP-2016-6105 Rev. 2) y *Space Mission Engineering: The New SMAD*. Un fallo en cualquiera de ellos propaga efectos en cadena sobre los demás.

### 1.1 Estructuras, Materiales y Protección contra Impactos (MMOD)

- **Estructuras primarias:** Las etapas criogénicas y módulos presurizados emplean aleaciones de aluminio-litio como **Al-Li 2195** ($\rho \approx 2.71\text{ g/cm}^3$, adoptada en el Tanque Externo *Super Lightweight* del Transbordador Espacial, ahorrando $\sim 3400\text{ kg}$ respecto al Al 2219), paneles sándwich de caras de aluminio o compuesto carbono/epoxi sobre núcleo alveolar (*honeycomb*), y ventanas multicapa de sílice fundida.
- **Cargas de lanzamiento:** Durante el ascenso atmosférico la nave atraviesa la zona de máxima presión dinámica (**Max-Q**, típicamente $28\text{--}35\text{ kPa}$ en vehículos tripulados, $q = \frac{1}{2}\rho v^2$), presión acústica superior a $140\text{ dB}$ SPL y aceleración axial creciente al agotarse el propelente.
- **Escudo Whipple y *Stuffed Whipple* (*NASA/TM-2009-214786*):** A velocidades orbitales relativas de $7\text{--}15\text{ km/s}$, un fragmento de apenas $1\text{ cm}$ posee energía cinética equivalente a decenas de kilojoules. El escudo Whipple consta de una lámina sacrificial frontal de aluminio (Al 6061-T6) separada entre $10\text{ y }30\text{ cm}$ del casco presurizado; al chocar, el proyectil se fragmenta y vaporiza en una nube de escombros que dispersa la energía sobre un área amplia. La Estación Espacial Internacional (ISS) añade telas cerámicas **Nextel AF62** y fibra **Kevlar KM2** (*Stuffed Whipple*) en el espacio intermedio para detener proyectiles de aluminio de hasta $\sim 1.0\text{--}1.4\text{ cm}$ a $7\text{ km/s}$.

### 1.2 Propulsión Química y Eléctrica Comparada

La capacidad de maniobra queda gobernada por la ecuación del cohete de Tsiolkovsky ($\Delta v = I_{sp} \cdot g_0 \cdot \ln(m_{wet}/m_{dry})$) y la relación empuje-peso ($\text{TWR}$):

| Tecnología / Propelente | $I_{sp}$ en vacío ($\text{s}$) | Empuje / Rol típico | Ventaja operativa | Desventaja o fallo real | Referencia NASA / Misión |
| :--- | :---: | :--- | :--- | :--- | :--- |
| **Gas frío ($\text{N}_2$)** | $65\text{--}75$ | Muy bajo / RCS fino | Cero contaminación sobre ópticas y sensores | Muy baja densidad energética; exige tanques de alta presión | RCS de unidades MMU y CubeSats |
| **Monopropelente ($\text{N}_2\text{H}_4$)** | $220\text{--}235$ | Bajo–Medio / RCS | Un solo tanque, catalizador Ir/$\text{Al}_2\text{O}_3$ simple y reiniciable | Alta toxicidad; degradación térmica del lecho catalítico | Voyager, Mars Reconnaissance Orbiter |
| **Bipropelente hipergólico ($\text{MMH}/\text{N}_2\text{O}_4$)** | $310\text{--}320$ | Medio–Alto / OMS | Ignición espontánea al contacto; almacenable meses a temperatura ambiente | Altamente corrosivo y tóxico; fugas generan nube reactiva | Apollo SPS ($314.5\text{ s}$), Shuttle OMS ($316\text{ s}$), Orion ESM |
| **Criogénico Metano ($\text{LCH}_4/\text{LOX}$)** | $360\text{--}380$ | Alto / Ascenso e interplanetario | Temperaturas cercanas ($111.7\text{ K}$ y $90.2\text{ K}$); menor hollín (*coking*) | Pérdida por evaporación si carece de aislamiento o criocoolers | Motores de próxima generación / ISRU marciano |
| **Criogénico Hidrógeno ($\text{LH}_2/\text{LOX}$)** | $450\text{--}465$ | Muy alto / Etapas superiores | Máximo $I_{sp}$ químico ($452.3\text{ s}$ RS-25; $465.5\text{ s}$ RL10B-2) | Baja densidad ($\sim 70.8\text{ kg/m}^3$); *boil-off* rápido a $20.28\text{ K}$ | Centaur RL10, SLS Core RS-25 |
| **Eléctrico Hall / Iónico ($\text{Xe}$)** | $1800\text{--}4190$ | Milinewtons ($\text{TWR} \ll 1$) | Ahorro extremo de masa de propelente en espacio profundo | Requiere kilovatios continuos; empuje lento (meses de encendido) | NEXT-C en *DART* ($4190\text{ s}$); SPT-140 en *Psyche* ($\sim 1800\text{ s}$) |

Las toberas enfriadas por radiación usadas en motores de vacío emplean aleaciones de **niobio C-103** ($\text{Nb}-10\text{Hf}-1\text{Ti}$), capaces de operar hasta $\sim 1370\text{--}1650^\circ\text{C}$ con masa mínima (Apollo LM, MVac de Falcon 9), pero sufren oxidación acelerada y desgaste mecánico si operan dentro de atmósferas densas sin recubrimiento siliciuro o refrigeración regenerativa.

### 1.3 Sistema de Potencia Eléctrica (EPS)

- **Paneles fotovoltaicos multijuntura ($\text{GaInP/GaAs/Ge}$):** Eficiencia típica en espacio de $29\text{--}32\%$ al inicio de misión (BOL), con degradación progresiva por radiación ionizante ($\sim 1\text{--}2\%$/año en LEO; drásticamente mayor en los cinturones de Van Allen o alrededor de Júpiter).
- **Colapso por ley del inverso del cuadrado ($S(r) = 1361 / r_{\text{AU}}^2\text{ W/m}^2$):** Según el *NASA Planetary Fact Sheet* (NSSDCA):
  - **Tierra ($1.00\text{ AU}$):** $1361\text{ W/m}^2$ ($100.0\%$).
  - **Marte ($1.52\text{ AU}$):** $\approx 589\text{ W/m}^2$ ($\sim 43.3\%$). Exige paneles de mayor área y limpieza/márgenes ante polvo atmosférico.
  - **16 Psyche ($2.92\text{ AU}$):** $\approx 160\text{ W/m}^2$ ($11.7\%$).
  - **Júpiter ($5.20\text{ AU}$):** $\approx 50.3\text{ W/m}^2$ ($3.70\%$). Los arreglos solares convencionales pierden viabilidad y exigen áreas masivas (como *Juno*) o fuentes nucleares.
- **Generadores Radioisotópicos MMRTG (*Multi-Mission RTG*):** Alimentados con $4.8\text{ kg}$ de dióxido de plutonio ($\text{PuO}_2$, isótopo $^{238}\text{Pu}$ con vida media de $87.7\text{ años}$). Producen $\sim 2000\text{ W}$ térmicos convertidos mediante termopares $\text{PbTe/TAGS}$ en $\sim 110\text{ W}$ eléctricos continuos (decaimiento $\sim 1.6\%$/año), independientes de la luz solar, a cambio de disipar $\sim 1890\text{ W}_{th}$ constantes en forma de calor residual.
- **Pilas de combustible ($\text{H}_2/\text{O}_2$):** Usadas en Apollo y Transbordador Espacial (tres unidades alcalinas de hasta $12\text{ kW}$ pico cada una en el *Shuttle*), generan electricidad y agua potable, pero dependen íntegramente de reservas finitas de oxígeno e hidrógeno criogénicos.

### 1.4 Control Térmico (TCS)

En el vacío no existe convección ni aire para transferir calor: toda disipación térmica hacia el espacio profundo ($T_{deep} \approx 2.7\text{ K}$) ocurre exclusivamente por radiación infrarroja según la ley de Stefan-Boltzmann:

$$Q = \epsilon\,\sigma\,A\,T^4, \quad \sigma = 5.6704 \times 10^{-8}\text{ W/m}^2\text{K}^4$$

- **Control pasivo (MLI y recubrimientos):** El aislamiento multicapa **MLI** (*Multi-Layer Insulation*) alterna entre 10 y 30 láminas de **Kapton** o **Mylar** aluminizado separadas por mallas de baja conductancia para frenar el intercambio radiativo tanto frente al Sol ($\sim +120^\circ\text{C}$ en superficies iluminadas) como en sombra ($\sim -150^\circ\text{C}$). El Kapton tolera de $-269^\circ\text{C}$ a $+400^\circ\text{C}$, pero carece de resistencia aerodinámica y se desgarra bajo presión dinámica elevada.
- **Control activo (ATCS y radiadores de amoníaco):** En naves de alta potencia como la ISS, circuitos internos de agua recogen calor de la aviónica y la tripulación hacia intercambiadores externos por donde circula **amoníaco anhidro ($\text{NH}_3$)** líquido hacia paneles radiadores desplegables. Si un micrometeoroide perfora el radiador, el $\text{NH}_3$ hierve y escapa al vacío, forzando el apagado de módulos para evitar fallos térmicos.

### 1.5 Soporte Vital y Control Ambiental (ECLSS — *NASA-STD-3001 Vol. 2*)

- **Presión y composición de cabina:** La arquitectura moderna (ISS, Crew Dragon, Orion) opera a $101.3\text{ kPa}$ ($14.7\text{ psi}$) con $21\%\ \text{O}_2$ y $79\%\ \text{N}_2$ para reducir riesgos de incendio y compatibilizar experimentos terrestres; naves antiguas como Apollo volaban a $\sim 34.5\text{ kPa}$ ($5\text{ psi}$) con atmósfera enriquecida en oxígeno (abandonada en tierra tras el incendio mortal de Apollo 1 en 1967).
- **Generación de oxígeno:** Electrólisis continua del agua en el **OGS** ($2\text{H}_2\text{O} \to 2\text{H}_2 + \text{O}_2$), reservas criogénicas/gaseosas a alta presión y generadores químicos sólidos de respaldo (**SFOG / velas de perclorato de litio $\text{LiClO}_4$** o clorato sódico), cuya descomposición exotérmica supera los $400^\circ\text{C}$.
- **Captura de $\text{CO}_2$:** Cartuchos desechables de hidróxido de litio ($2\text{LiOH} + \text{CO}_2 \to \text{Li}_2\text{CO}_3 + \text{H}_2\text{O}$, aprox. $1\text{ kg}$ de $\text{LiOH}$ por tripulante/día) o sistemas regenerables de tamices moleculares de zeolita (**CDRA** en la ISS).
- **Umbrales fisiológicos reales (*NASA-STD-3001*):**
  - **Hipercapnia ($\text{CO}_2$):** Nominal $<3\text{ mmHg}$ (objetivo ISS $<2\text{ mmHg}$ para evitar cefaleas); deterioro cognitivo y disnea entre $4\text{ y }15\text{ mmHg}$; confusión severa e incapacitación por encima de $30\text{ mmHg}$.
  - **Hipoxia / Descompresión:** Si $P_{\text{O}_2}$ cae por debajo de $100\text{ mmHg}$ disminuye el rendimiento cognitivo; ante exposición súbita al vacío el **Tiempo de Conciencia Útil (TUC)** humano es de solo **$12\text{--}15\text{ segundos}$** debido a la desoxigenación inversa en los pulmones (ebullismo en mucosas e inconsciencia por anoxia cerebral, sin explosión corporal).

### 1.6 Guiado, Navegación y Control de Actitud (GNC / ADCS)

- **Sensores:** Rastreadores estelares (*Star Trackers*, precisión de pocos segundos de arco, susceptibles a cegamiento por destellos solares o lluvia de protones en tormentas solares), unidades de medición inercial (**IMU** con giroscopios láser/MEMS y acelerómetros) y sensores solares gruesos.
- **Actuadores y fallos clásicos:** Ruedas de reacción (**RWA**) y giroscopios de momento de control (**CMG**). La ISS emplea 4 CMG de doble cardán ($\sim 258\text{ N}\cdot\text{m}$ de par combinado) para mantener actitud sin gastar propelente. Sin embargo, los torques gravitacionales y aerodinámicos acumulan momento angular hasta provocar **saturación**, requiriendo disparos de los propulsores **RCS** (*Reaction Control System*) para desaturarlos. En plataformas inerciales de tres cardanes (como la IMU de Apollo), alinear el cardán interno con el externo produce **gimbal lock**, perdiendo un grado de libertad y bloqueando la referencia de actitud.

### 1.7 Computación (C&DH) y Red de Espacio Profundo (DSN)

- **Aviónica tolerante a radiación:** Los rayos cósmicos galácticos (GCR) y las partículas energéticas solares (SEP) atraviesan circuitos integrados e inducen cambios de bit (**SEU**, *Single Event Upsets*) o enclavamientos destructivos (*latch-up*). Naves como *Curiosity*, *Perseverance*, *Juno* y *JWST* utilizan procesadores endurecidos **BAE RAD750** (hasta $200\text{--}1000\text{ krad}$ de dosis total), buses deterministas MIL-STD-1553B, memorias con corrección **EDAC** y votación triple modular (**TMR**) para aislar cálculos corruptos.
- **NASA Deep Space Network (DSN):** Compuesta por tres complejos distanciados $\sim 120^\circ$ en longitud (Goldstone en California, Madrid en España y Canberra en Australia) con antenas parabólicas de $34\text{ m}$ y $70\text{ m}$ en bandas S ($2.2\text{ GHz}$), X ($8.4\text{ GHz}$) y Ka ($32\text{ GHz}$). La velocidad finita de la luz ($c = 299\,792.458\text{ km/s}$) impone latencias bidireccionales ($\text{RTLT} = 2d/c$) crecientes:
  - **Luna ($384\,400\text{ km}$):** $\text{RTLT} \approx 2.56\text{ s}$.
  - **Marte (media de misión $\sim 225\times 10^6\text{ km}$):** $\text{RTLT} \approx 1501\text{ s}$ ($\sim 25\text{ min}$; rango real $6\text{--}44\text{ min}$ ida y vuelta según geometría orbital).
  - **Júpiter ($778.5\times 10^6\text{ km}$):** $\text{RTLT} \approx 5193\text{ s}$ ($\sim 86.5\text{ min}$).
  Debido a este retardo, ninguna nave interplanetaria puede ser pilotada en vivo desde Tierra y depende de rutinas autónomas de *Fault Protection* y *Safe Mode*.

---

## 2. Catálogo de 10 Incidentes Espaciales Reales Documentados

| # | Misión / Año | Subsistema raíz | Modo de fallo cuantificado | Consecuencia operativa y rescate | Fuente oficial |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **1** | **Apollo 13** (1970) | EPS / Criogenia ($\text{LOX}$ #2) | Termostatos de $28\text{ V}$ soldados con $65\text{ V}$ DC en pruebas en tierra ($>530^\circ\text{C}$); arco en cable de Teflón a $321\,860\text{ km}$ | Explosión de tanque #2, vaciado de ambos $\text{LOX}$ en $\sim 130\text{ min}$, pérdida de las 3 pilas de combustible; adaptación de filtros $\text{LiOH}$ en el LM | *Cortright Commission Report* (NASA, 1970) |
| **2** | **Estación Mir** (23 feb 1997) | ECLSS (Vela *Vika* $\text{LiClO}_4$) | Combustión defectuosa en generador sólido de oxígeno: llama tipo soplete de $\sim 90\text{--}120\text{ s}$ en módulo Kvant-1 | Humo tóxico en toda la estación en $<1\text{ min}$; tripulación con respiradores apagó ventilación para frenar propagación hasta agotarse el cartucho | *NASA RP-1357* & *NASA Safety Center* |
| **3** | **Mir – Spektr / Progress M-34** (25 jun 1997) | Estructuras / Acoplamiento TORU | Colisión de nave de carga de $\sim 7000\text{ kg}$ a $\sim 3\text{ m/s}$ en prueba manual sin radar Kurs; brecha $\sim 2\text{ cm}^2$ | Presión cayó de $\sim 755$ a $675\text{ mmHg}$; corte de cables y cierre de escotilla en $<8\text{ min}$; pérdida del $40\text{--}50\%$ de potencia solar y giro en sombra | *NASA OIG Report IG-98-018* |
| **4** | **Gemini 8** (1966) y **ISS Nauka** (2021) | GNC / Propulsión RCS | Gemini 8: cortocircuito mantuvo abierto propulsor OAMS #8 ($\sim 111\text{ N}$). Nauka: fallo de software encendió motores tras acople | Gemini 8 rotó a $360^\circ/\text{s}$ ($60\text{ rpm}$); Armstrong recuperó control con RCS de reentrada y abortó. Nauka giró la ISS ($420\text{ t}$) $540^\circ$ antes de compensarse con Zvezda/Progress | *NASA MSC-G-R-66-4* & *NASA ISS Updates* (2021) |
| **5** | **Mars Climate Orbiter** (23 sep 1999) | GNC / Software de Tierra | Desajuste de interfaz $\text{lbf}\cdot\text{s}$ vs $\text{N}\cdot\text{s}$ (factor $4.4482\times$) en cálculo de desaturación de RWA durante 9 meses | Trayectoria desviada $\sim 170\text{ km}$ hacia el planeta; periapsis real a $57\text{ km}$ en vez de $140\text{--}150\text{ km}$, causando pérdida total por entrada atmosférica | *MCO Mishap Investigation Board* (NASA, 1999) |
| **6** | **Columbia STS-107** (1 feb 2003) | Protección Térmica (TPS) | Espuma SOFI del Tanque Externo ($\sim 0.76\text{ kg}$ a $\sim 240\text{ m/s}$ a $81.7\text{ s}$) perforó panel RCC #8 del ala izquierda ($\sim 15\text{--}25\text{ cm}$) | Entrada de plasma a $\text{Mach } 24.5$ ($\sim 1650^\circ\text{C}$) durante la reentrada; fallo hidráulico y desintegración a $\sim 61\text{ km}$ de altitud | *CAIB Report Vol. 1* (NASA, 2003) |
| **7** | **Apollo 6 (1968) / Apollo 13 S-II (1970)** | Estructura–Propulsión (*Pogo*) | Resonancia acoplada entre presión en ductos de $\text{LOX}$ y flexión longitudinal ($\sim 5\text{ Hz}$ en S-IC; $\sim 16\text{ Hz}$ en S-II de Apollo 13) | Aceleración de $\pm 34\text{ g}$ en motor central J-2 de S-II y apagado prematuro $132\text{ s}$ antes; mitigado con acumuladores de helio criogénico | *NASA SP-8055* (octubre 1970) |
| **8** | **Iridium 33–Cosmos 2251** (2009) y **Soyuz MS-22** (dic 2022) | MMOD / TCS Radiadores | Colisión orbital a $11.7\text{ km/s}$ ($789\text{ km}$ alt.) dejó $>1800$ fragmentos rastreables. En 2022 impacto de $\sim 0.8\text{ mm}$ en radiador Soyuz MS-22 | Soyuz vació $\sim 44\text{ L}$ de refrigerante en $\sim 3\text{ h}$, elevando temperatura interna $>30\text{--}40^\circ\text{C}$ y obligando a enviar Soyuz MS-23 vacía de rescate | *NASA ODPO ODQN* Vol. 13(2) & Vol. 27(1) |
| **9** | **Tormentas Halloween** (oct–nov 2003) y **Starlink** (feb 2022) | Clima Espacial (SEP/CME) | Fulguraciones X17.2 ($2459\text{ km/s}$) y X28+ ($Kp=9$); en feb 2022 tormenta $Kp=5\text{--}6$ aumentó $\sim 50\%$ la densidad a $210\text{ km}$ | $59\%$ de naves NASA registraron SEU/anomalías; se perdió el instrumento MARIE de *Mars Odyssey*; 38 satélites Starlink reentraron por arrastre térmico | *NOAA TM OAR SEC-88* & *NASA DONKI* |
| **10** | **Columbia STS-75 / TSS-1R** (25 feb 1996) | EPS / Plasma Ionosférico | A $19.7\text{ km}$ de cable desplegado a $7.6\text{ km/s}$, el voltaje inducido alcanzó $\sim 3500\text{ V}$; defecto puntual en aislamiento | Arco eléctrico de $\sim 1.1\text{ A}$ cerrado con el plasma ionosférico fundió el cable conductor en $\sim 9\text{ s}$, perdiendo el satélite atado | *TSS-1R Investigation Board Report* (NASA, 1996) |

---

## 3. Mitos de Ciencia Ficción vs. Física Espacial Real (Falsos Positivos Evitados)

Para que la simulación de `Space` conserve tensión jugable sin caer en clichés falsos de Hollywood, se documentan cuatro contrastes físicos verificados:

1. **Mito del "espacio congelante instantáneo":** El vacío es un aislante térmico casi absoluto. Una nave con tripulación, electrónica y reactor acumula calor interno y **sobrecalienta primero** si falla su circuito de refrigeración y radiadores (como ocurrió en la Soyuz MS-22 en 2022), en lugar de congelarse al instante. El frío extremo ($2.7\text{ K}$ de fondo) solo congela tanques o circuitos expuestos tras horas en sombra sin aporte energético o cuando la nave viaja más allá de Marte sin aislamiento MLI o calefactores.
2. **Mito de la "descompresión total en 1 segundo por un agujero pequeño":** Modelando la fuga por flujo sónico estrangulado (*choked flow* isentrópico para aire a $101.3\text{ kPa}$, $293\text{ K}$ en una cabina de $\sim 50\text{ m}^3$), una brecha de $1\text{ cm}^2$ expulsa $\sim 0.023\text{ kg/s}$ y tarda decenas de minutos en vaciar el módulo; una brecha de $10\text{ cm}^2$ deja varios minutos para cerrar la compuerta o parcharla (caso Mir Spektr en 1997). Únicamente perforaciones estructurales mayores ($\ge 0.1\text{ m}^2$) exigen respuestas en segundos. En `Space`, el temporizador de **5 segundos** tras avería crítica representa la ventana táctica comprimida de reacción antes de que escale a daño en cadena.
3. **Mito de "acelerar directo hacia adelante para alcanzar otra nave":** Por las leyes de Kepler, aplicar un impulso *Prograde* eleva el apoapsis y agranda el semieje mayor $a$; dado que el periodo orbital crece como $T = 2\pi\sqrt{a^3/\mu}$, acelerar hacia adelante hace subir a una órbita más alta y **más lenta angularmente**, alejándose hacia atrás del objetivo. El encuentro orbital (*rendezvous*) exige maniobras contraintuitivas en las que el piloto desciende brevemente a una órbita inferior más rápida (*Retrograde*) antes de volver a elevarse.
4. **Mito del "fuego que sube como vela y siempre se apaga quitando aire":** Los experimentos espaciales **NASA Saffire I–VI** a bordo de naves Cygnus comprobaron que en microgravedad no existe flotabilidad convectiva: las llamas tienden a ser esféricas, tenues y frías, pero la **ventilación forzada del ECLSS** las alimenta y propaga a través de cables y conductos ocultos. Además, si la combustión involucra un generador químico o propelente hipergólico con oxidante propio (como la vela *Vika* en Mir), cortar oxígeno ambiental no detiene la reacción inicial; es necesario cortar ventilación/energía y enfriar o ventear los gases tóxicos resultantes.

---

## 4. Matriz de Trazabilidad Directa hacia `Margin Zero: Deuda Orbital`

Cada hallazgo institucional de este documento se traduce directamente en elementos implementables de la arquitectura actual en `game/sim/`, `docs/DISEÑO-UI-NAVES-25D.md`, `docs/MECANICAS-REFERENCIA.md` y `data/nasa/*.json`:

| Subsistema o Incidente Real | Sala FTL (`RoomHazards` / `ReactorPower`) | Hardpoint 2.5D (`MZ-1 BALLAST` / `Orbital Mule Mk-I`) | Perk NASA / Dato Oficial vinculado (`MECANICAS-REFERENCIA.md` & `data/nasa/*.json`) | Comportamiento verificado en simulación |
| :--- | :--- | :--- | :--- | :--- |
| **Impacto MMOD / Basura orbital (Iridium–Cosmos, Fengyun-1C)** | `science_bay` (`radial`) o casco general | `SOCKET_PORT_NACELLE` / `STBD_NACELLE` | `debris_leo_catalog.json` (7.66 a $14.2\text{ km/s}$, energías de $3200\text{ a }16\,500\text{ J}$) + `radar_doppler` (aviso de 14 s) | Brecha al vacío dominante en cuadrante `radial` (`DamageMatrix`); exige sellado o aislamiento antes de que caiga el $\text{O}_2$ bajo umbral |
| **Fallo de Radiador / MLI (Soyuz MS-22, pérdida de $\text{NH}_3$)** | `life_support` + sistema `shields_thermal` | `SOCKET_WING_PORT` / `STBD` | `radiator_ammonia` (fragilidad 1.0, pierde refrigerante al romperse) e `insulation_mli` (desgarro si $q > 12\,000\text{ Pa}$) | Embalamiento térmico (`temp_norm >= 0.85`) si cae refrigeración cerca de $1\text{ AU}$; congelación (`<= 0.15`) en espacio profundo sin MLI |
| **Crisis Criogénica y de Filtros (Apollo 13 $\text{LOX}$ #2 / $\text{LiOH}$)** | `reactor` (`middle`) y `life_support` (`middle`) | `SOCKET_PORT_NACELLE` (tanques $\text{LH}_2$) + núcleo interno | Recorte agresivo de barras en `ReactorPower` (`total_bars = 7`) + `RoomHazards` (caída de $\text{O}_2$ y luz en `middle`) | Obliga a desactivar sistemas no esenciales (sensores/ciencia) para sostener soporte vital y timón hasta retorno |
| **Incendio con Ventilación Activa (Mir 1997, *NASA Saffire*)** | Cualquier sala con fuego activo en `RoomHazards` | N/A (corte interior *FTL Cutaway*) | `trigger_hazard(..., fire_add)` y mitigación por `set_airlock(room_id, true)` | El incendio consume $\text{O}_2$ y daña salas/barras; abrir la esclusa al vacío extingue la llama rápidamente a costa de vaciar el aire del módulo |
| **Oscilación Pogo y Max-Q (Apollo 6 / 13 S-II, STS-107)** | `engines` (`bottom`) y estructura | `SOCKET_AFT_ENGINES` y `SOCKET_BOW` | `TakeoffRisk` ($P_{ign}$, $P_{ascent}$ con umbral $q_{max} = 28\,000\text{ Pa}$), `damper_cryo_he`, `shield_hrsi`, `shield_pica`, `staged_preburner` | Sobrecarga $\Omega > 0$ o vibración en Max-Q elevan $P_{explosion}$; `damper_cryo_he` reduce estrés un $70\%$ a cambio de drenaje eléctrico |
| **Reentrada Térmica (STS-107 Columbia, Marte tenue)** | `helm` / `sensors` (`top`) y casco | `SOCKET_BOW` (Escudo PICA / Losetas HRSI) | `planetary_catalog.json` (`mars`: $0.0064\text{ bar}$, $H=11.1\text{ km}$) + `shield_hrsi` / `shield_pica` | Marte exige escudo ablativo + paracaídas; Luna ($P_{bar}=0$) vuelve inútil el paracaídas y exige 100% retropropulsión en Popa |
| **Supertormentas Solares y SEU (Halloween 2003, SEP 2017, G5 2024)** | `sensors` (`top`) y `reactor` (`middle`) | `SOCKET_BOW` (Radar) / `SOCKET_DORSAL_TURRET` (Antena) | `solar_events_scenarios.json` ($M5.4$ a $X17.2$, CME $720\text{--}2459\text{ km/s}$, $Kp=5\text{--}9$) + `telemetry_strain` | Degradación temporal de `vision`, `map` y `comms` (SEU) salvo activar protección o contar con telemetría analógica inmune a EMP |
| **Caída de Irradiancia 5.2 AU y Latencia DSN (Júpiter / Marte)** | `reactor` (`middle`) y `sensors` (`top`) | `SOCKET_WING_*` (Solar vs RTG) y `SOCKET_DORSAL_TURRET` | `planetary_catalog.json` ($f(5.2\text{ AU}) \approx 0.037$, `dsn_rtlt_s`: $2.56\text{ s}$ Luna, $1501\text{ s}$ Marte, $5193\text{ s}$ Júpiter) + `NasaDataLoader` | Misiones a Júpiter colapsan con energía solar ($3.7\%$); el retardo DSN justifica autonomía local de la nave en lugar de telecontrol terrestre |
| **Giro Descontrolado y Saturación CMG (Gemini 8, ISS Nauka)** | `helm` (`top`) | `SOCKET_DORSAL_TURRET` / módulo de control | `cmg_stabilizer` (+45% giro sin consumo RCS, riesgo de *gimbal lock* de $4.0\text{ s}$) | Durante eventos de saturación o impacto asimétrico, el timón exige estabilización manual rápida o desaturación por RCS |
| **Error de Unidades / Maniobra Orbital (Mars Climate Orbiter, Kepler)** | `helm` y `sensors` (`top`) | N/A (Vista Orbital 2.5D estilo KSP) | `MissionEvaluator` (auditoría causal de errores de ingeniería) + `neo_curated_missions.json` (Bennu, Didymos, Eros, Psyche) | Errores pequeños en nodos $\Delta v$ desplazan el periapsis (`PE`) hacia destrucción atmosférica (`PE < 100 km`) o escape orbital |

---

## 5. Fuentes Institucionales y Referencias Bibliográficas Verificables

1. **NASA Systems Engineering Handbook:** NASA/SP-2016-6105 Rev. 2 (`https://www.nasa.gov/reference/systems-engineering-handbook/`).
2. **NASA Planetary Fact Sheet (NSSDCA / Goddard Space Flight Center):** `https://nssdc.gsfc.nasa.gov/planetary/factsheet/`.
3. **NASA Space Flight Human-System Standard Vol. 2 (ECLSS, Hipoxia y $\text{CO}_2$):** NASA-STD-3001 Vol. 2 (`https://www.nasa.gov/ochmo/human-spaceflight-standards/`).
4. **NASA MMOD Shielding Design Handbook (Christiansen, JSC):** NASA/TM-2009-214786.
5. **Apollo 13 Accident Review Board (Cortright Commission):** *Report of the Apollo 13 Review Board*, NASA, junio de 1970.
6. **Incendio y Colisión en la Estación Mir (1997):** *Shuttle-Mir History / Fire on Mir* (NASA RP-1357) & NASA Office of Inspector General Report **IG-98-018** (*Spektr Collision*).
7. **Gemini VIII Mission Report (OAMS #8 Stuck Thruster):** NASA **MSC-G-R-66-4**, mayo de 1966.
8. **Mars Climate Orbiter Mishap Investigation Board:** *Phase I Report*, NASA, noviembre de 1999.
9. **Columbia Accident Investigation Board (CAIB):** *Report Volume 1*, NASA, agosto de 2003.
10. **Coupled Structure-Propulsion Instability (Pogo):** NASA **SP-8055**, *Prevention of Coupled Structure-Propulsion Instability (Pogo)*, octubre de 1970.
11. **NASA Orbital Debris Program Office (ODPO):** *Orbital Debris Quarterly News* Vol. 13 Issue 2 (Iridium 33–Cosmos 2251) y Vol. 27 Issue 1 (Soyuz MS-22 Coolant Leak), `https://orbitaldebris.jsc.nasa.gov/`.
12. **NOAA Space Weather Prediction Center & NASA DONKI:** *NOAA Technical Memorandum OAR SEC-88 (Halloween Space Weather Storms of 2003)* y base DONKI (`https://api.nasa.gov/`).
13. **TSS-1R Tether Failure Investigation Board:** *Final Report on STS-75 Tethered Satellite System Failure*, NASA, mayo de 1996.
14. **NASA JPL Small-Body Database & Deep Space Network:** `https://ssd-api.jpl.nasa.gov/doc/sbdb.html` y DSN Now (`https://eyes.nasa.gov/dsn/data/dsn.xml`).
15. **NASA Saffire Microgravity Combustion Experiments & Nuclear Power (MMRTG):** NASA Glenn Research Center (`https://www.nasa.gov/space-technology-mission-directorate/`).
