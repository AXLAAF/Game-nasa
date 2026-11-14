# Especificacion Integral de Interfaz 2.5D, Naves Modulares Evolucionables y Vista Orbital KSP + FTL

**Proyecto:** `Space: Deuda Orbital`  
**Motor:** Godot 4.7+ (`gl_compatibility`, WebGL2)  
**Estetica Objetivo:** Pixel Art 2.5D Modular (*FTL* + *Rhine Lab / Lone Trail* + *Kerbal Space Program*)  
**Tablero Analizado:** `https://mx.pinterest.com/AXL_MC/game/` (`pin_06`, `pin_08`, `pin_11`, `pin_14`, `pin_18`, `pin_22`, `pin_25`, `pin_26`)

---

## 1. Sintesis de Referencias del Tablero Pinterest (`AXL_MC/game`)

| Pin de referencia | Elemento analizado | Que aporta a `Space` |
| :--- | :--- | :--- |
| **`pin_22.jpg`** | Nave cenital pixel art 2.5D estilo *FTL Kestrel* | Define el **Chasis Maestro predeterminado**: proa biseccionada con cabina abovedada oscura, nucleo biselado, gondolas laterales fijadas con **abrazaderas blancas horizontales**, motores gemelos remetidos bajo el faldon trasero con pluma naranja y **contorno exterior unico oscuro** de 1 px que funde todas las piezas en una sola silueta. |
| **`pin_08.jpg`** | Hoja de evolucion modular `LVL 0` a `LVL 5 MAX` y ondas de choque | Define el sistema de **mejora progresiva sin romper el ensamblaje**: cada modulo conserva su huella de anclaje base pero suma remaches, luces LED contadoras (`1..5`), refuerzos dorsales y anillos de escape escalonados conforme la agencia invierte creditos entre misiones. |
| **`pin_18.jpg`** | Diagrama astrofisico *Rhine Lab / Lone Trail* | Define el lenguaje de la **Vista Orbital KSP 2.5D**: lienzo azul-vacio profundo (`#0b0f19`), orbitas elipticas finas en crema tecnico (`#f4ebd9`), escalas radiales (`100`, `5000`, `10000`), estaciones numeradas (`01..07`) y banda tricolor retro-NASA (`#c83e2b`, `#f09c14`, `#f4ebd9`, `#38bdf8`). |
| **`pin_26.jpg`** | Radar topografico 3D *wireframe* | Interfaz CRT negra para el **Oficial de Radar**: malla de terreno/asteroide en naranja `#ff6a00`, agujas verticales de elevacion en cian `#00d2ff`, nodos de amenaza `#ff8c00` y bloque tabular compacto inferior izquierdo (`seed`, `gain`, `spread`). |
| **`pin_25.jpg`** | Paleta lineal TLP (31 tonos normalizados) | Rampas coherentes de luz/sombra/oclusion para materiales aeroespaciales, fuego de plasma, energia cian y oxido sin manchas grisaceas al sombrear. |
| **`pin_14.jpg` / `pin_11.jpg`** | Dithering Bayer y tramado *halftone* | Sombras de terminador planetario y nieblas orbitales resueltas en trama ordenada pixel art en lugar de gradientes difusos incompatibles con pixel art. |
| **`pin_06.jpg`** | Retro UI tactil con biseles bajorrelieve | Controles diegeticos legibles: conmutadores de palanca, deslizadores de carril dentado y listas de seleccion con contraste limpio. |

---

## 2. Investigacion y Reglas de Ingenieria Visual para Naves Modulares Coherentes (2.5D Pixel Art)

### 2.1 Por que suelen verse mal las naves modulares y como lo resolvemos
Cuando un juego deja combinar modulos libremente en 2D, aparecen cuatro defectos que rompen la credibilidad visual:
1. **Uniones planas ("pegotes"):** Los bordes rectangulares de dos sprites chocan sin oclusion ni collar mecanico.
2. **Densidad de texel inconsistente:** Un motor reescalado al `0.75x` junto a una cabina al `1.0x` mezcla pixeles de distinto tamano.
3. **Iluminacion contradictoria:** Una pieza iluminada desde arriba a la izquierda toca otra iluminada desde abajo.
4. **Contornos internos rotos:** Cada sprite trae su propio borde negro grueso alrededor, formando lineas dobles artificiales donde dos piezas deben verse soldadas.

**Solucion arquitectonica en `Space`:** Toda nave parte de una **plataforma maestra coherente** que crece y se transforma mediante **hardpoints estandarizados**, **collares/abrazaderas automaticos**, **iluminacion fija a 315 grados** y un **post-proceso de contorno unico en `CanvasGroup`**.

### 2.2 El Chasis Maestro Predeterminado: `Orbital Mule Mk-I`
En lugar de construir un cohete descartable desde cero en cada partida, la agencia posee y evoluciona su propia nave insignia:

- **Dimensiones base del fuselaje:** `160 x 224 px` nominales (`5 x 7` celdas en rejilla interna de `32 x 32 px`).
- **Malla interna walkable (*FTL Cutaway*):** 6 salas fijas siempre accesibles para la tripulacion sin importar el equipamiento exterior:
  1. `helm` (Puente, Proa-Centro): 2x2 celdas, consolas de vuelo orientadas a proa.
  2. `sensors` (Sensores / Comms, Proa-Babor): 1x2 celdas, consola CRT y bus de antena.
  3. `science_bay` (Bahia Cientifica, Centro-Estribor): 2x2 celdas, puerta lateral al brazo/carga.
  4. `reactor` (Nucleo de Energia, Centro): 2x2 celdas, nucleo central y distribucion de barras.
  5. `life_support` (Soporte Vital O2 / Termico, Centro-Babor): 1x2 celdas, escotilla de aire y radiador.
  6. `engines` (Sala de Motores, Popa): 3x1 celdas, bancada trasera con dos esclusas de venteo al vacio (*airlocks*).

### 2.3 Los 7 Sockets / Hardpoints con Collar de Transicion Automatico
Todo modulo externo se acopla unicamente a ranuras tipadas con **superposicion mecanica** y generacion automatica de juntas:

```text
                       [ SOCKET_BOW ] (Z=2, anillo 48px)
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
[ SOCKET_WING_PORT ]                    [ SOCKET_WING_STBD ]
  (Z=2, bisagra)                           (Z=2, bisagra)
        │                                         │
[ SOCKET_PORT_NACELLE ]──(Abrazadera)──[ CHASIS MAESTRO ]──(Abrazadera)──[ SOCKET_STBD_NACELLE ]
       (Z=1)            + AO 2px            (Z=0 + Z=3 Dorsal)     + AO 2px         (Z=1)
                                                  │
                                          [ SOCKET_DORSAL_TURRET ] (Z=3, sombra +2,+2)
                                                  │
                                      ┌───────────┴───────────┐
                                  [ SOCKET_AFT_PORT ]   [ SOCKET_AFT_STBD ]
                                    (Z=-1, -4px bajo faldon trasero)
```

| Socket | Capa Z | Piezas compatibles | Regla fisica de acople coherente |
| :--- | :---: | :--- | :--- |
| `SOCKET_BOW` | `Z = 2` | Escudo PICA curvo, Domo Radar Doppler, Torre de Escape LES | Encaja **dentro** de un anillo frontal biselado de `48 px` con collar oscuro de 2 px; la proa nunca termina en corte recto. |
| `SOCKET_PORT_NACELLE` / `STBD_NACELLE` | `Z = 1` | Tanques LH2 extra, Gondolas blindadas, Bancos RTG, Carga auxiliar | Al instalarse dibujan automaticamente **2 abrazaderas horizontales** (`#f1f5f9` con borde `#334155`, estilo `pin_22`) sobre la junta y una franja de oclusion de contacto de `2 px`. |
| `SOCKET_WING_PORT` / `STBD` | `Z = 2` | Paneles solares articulados, Radiadores plegables de amoniaco | Nacen desde una rotula/bisagra metalica montada sobre la gondola o el costado del casco; siempre mantienen angulo ortogonal uniforme. |
| `SOCKET_DORSAL_TURRET` | `Z = 3` | Antena parabolica DSN, Brazo robotico Canadarm, Telescopio | Proyecta sombra desplazada `(+2 px, +2 px)` sobre el techo dorsal para enfatizar altura 2.5D sobre el fuselaje. |
| `SOCKET_AFT_ENGINES` | `Z = -1` | Motores quimicos principales, Tobera Niobio C-103, Boosters | Anclan `4 px` **por debajo** del borde inferior del faldon trasero para ocultar la raiz de la campana y proyectar oclusion desde `Z=0`. |

### 2.4 Evolucion Progresiva de Modulos (`LVL 1` a `LVL 5 MAX`, ref. `pin_08`)
En vez de reemplazar la nave en cada mision, las ganancias de contratos y ciencia permiten subir de nivel los sistemas y cambiar visualmente la pieza sin alterar su huella en el chasis:

| Nivel | Tratamiento visual (`pin_08` + Worn Aerospace) | Indicador LED | Cambio de silueta y FX permitido |
| :---: | :--- | :---: | :--- |
| **`LVL 1` (Chatarra)** | Chapa gris apagada (`#475569`), parches remachados asimetricos, ligera oxidacion (`#78350f`). | `1` punto rojo/ambar | Silueta base compacta, pluma de motor corta y erratica. |
| **`LVL 2` (Usada)** | Pintura desgastada en aristas (`#64748b`), rejilla lateral dual limpia. | `2` puntos ambar | Aparecen tomas de ventilacion laterales y abrazadera reforzada. |
| **`LVL 3` (Estandar)** | Esmalte ceramico blanco-gris (`#cbd5e1`), franja naranja industrial (`#f97316`). | `3` puntos cian | Puntales dorsales simetricos y aro protector en tobera/antena. |
| **`LVL 4` (Grado NASA)** | Blanco cabina `#f8fafc`, lineas tecnicas `#38bdf8`, detalles en aislamiento Kapton oro (`#eab308`). | `4` puntos cian | Doble colector expuesto y anillo de choque en encendido (`pin_08`). |
| **`LVL 5 MAX` (Experimental)** | Aletas termicas doradas (`#fbbf24`), nucleo luminiscente cian/mylar y blindaje escalonado. | `5` puntos oro/blanco | Emision de ondas de plasma concéntricas y halo energetico activo. |

### 2.5 Pipeline de Renderizado 2.5D en Godot 4.7 (`gl_compatibility`)
1. **Rejilla de texel bloqueada:** Filtrado `TEXTURE_FILTER_NEAREST` global en `project.godot`, coordenadas redondeadas a enteros al dibujar sprites y cero rotacion libre sobre elementos arquitectonicos del interior.
2. **Iluminacion unificada a 315 grados:** Todos los modulos comparten borde iluminado arriba/izquierda (`+25%` luminancia), superficie central neutra, bisel inferior de grosor **3 a 4 px** (*faux 2.5D extrusion*, `-40%` luminancia) y sombra proyectada en `(+2, +2) px`.
3. **Contorno unificado por `CanvasGroup`:**
   - Todos los modulos del casco exterior (`Z=-1` a `Z=3`) viven dentro de un unico nodo `CanvasGroup` cuyo material aplica un shader WebGL2 compatible que busca pixeles con `alpha == 0` adyacentes (4-vecindad) a pixeles con `alpha > 0.5` del conjunto compuesto, dibujando **un solo borde continuo `#0b0e17` de 1–2 px**. Resultado: sin bordes internos ni aspecto de sprites pegados.
4. **Transicion Exterior -> Interior *FTL Cutaway*:**
   - El nodo superior `ExteriorRoofLayer` contiene las planchas de techo de proa, centro y popa. Cuando la nave esta bajo control de tripulacion en vuelo o zoom interior, `ExteriorRoofLayer.modulate.a` transiciona a `0.0` (200 ms curva suave) dejando ver las 6 salas interiores iluminadas, el nivel de oxigeno y a los bots caminando entre compuertas mientras el contorno exterior de la nave, las gondolas, alas y motores permanecen 100% visibles alrededor.

---

## 3. Doble Vista Sincronizada: Interior FTL 2.5D + Orbita KSP 2.5D

El juego combina en pantalla una doble escala espacial que comunica causa y efecto en todo momento:

### 3.1 Vista Interior 2.5D (Referencia: *FTL: Faster Than Light*)
- **Muros 2.5D:** Cada sala muestra cara superior del tabique (`3 px` claro) y cara frontal vertical visible de `6 px` en tono oscuro para transmitir profundidad isometrica/cenital real.
- **Estado de salas en 1 vistazo (3 niveles cromaticos):**
  - **Nominal:** Suelo pizarra frio (`#162032`), consola azul/cian encendida, icono verde.
  - **Degradada:** Baliza ambar giratoria, chispas en consola, rayado diagonal sutil de advertencia.
  - **Critica (cuenta regresiva `5.0 s`):** Fuego animado (`halftone` naranja/rojo) o brecha al vacio con succion de particulas blancas, anillo rojo alrededor de la sala y barra regresiva de `5 s`.
- **Ventilacion de Esclusas (*Airlock Venting*):** Las compuertas exteriores brillan en cian/amarillo al seleccionarse; al abrirlas aparece trama diagonal roja sobre la sala drenada indicando `O2 -> 0%`, sofocando el fuego en ~2 s y empujando/asfixiando a cualquier bot rezagado si no se cierra la puerta interior.

### 3.2 Vista Orbital 2.5D (Referencia: *Kerbal Space Program* + *Rhine Lab `pin_18`*)
Mientras el interior muestra el caos del equipo, el **Mapa Orbital KSP 2.5D** (integrado como lienzo principal alternable o panel derecho/expandible sincronizado durante aproximaciones y maniobras) grafica la fisica real del vuelo espacial:
- **Cuerpo Celeste 2.5D (`PlanetarySphere25D`):** Esfera pixel-art de alta definicion con iluminacion solar direccional y terminador resuelto con **tramado Bayer 4x4** (`pin_14`), banda delgada de atmosfera (cuando `surface_pressure_bar > 0`) y anillos de altitud concentrica estilo *Rhine Lab* (`100 km`, `5000 km`, `10000 km`).
- **Conica Orbital en Crema Tecnico (`#f4ebd9`):** Dibuja la elipse/hiperbola actual de la nave con cheurones animados de sentido de movimiento y marcadores diegeticos anclados en orbita:
  - **`AP` (Apoapsis):** Altura maxima y tiempo restante hasta alcanzarlo (`T-00:42`).
  - **`PE` (Periapsis):** Altura minima; se torna **ambar/rojo** si cae dentro del anillo atmosferico (indicando frenado por friccion o peligro de impacto).
- **Nodo de Maniobra ($\Delta v$ Burn):** Punto interactivo en la orbita con vectores *Prograde* (acelerar / subir orbita) y *Retrograde* (frenar / entrar en orbita o descenso). Al planificar un nodo:
  - Se dibuja en linea punteada dorada/cian (`#f09c14` / `#38bdf8`) la **orbita resultante prevista**.
  - Se muestra `Burn Δv` requerido (`m/s`), duracion estimada segun potencia actual de `Motores` en el reactor FTL, y cuenta regresiva `T-Node`.
- **Corredor de Reentrada KSP (Marte / Tierra):** Arco degradado de terracota a rojo (`#f09c14 -> #c83e2b`) que indica si el angulo de entrada es seguro (con escudo PICA) o letal.

### 3.3 Sincronia entre los 4 Puestos (FTL Interior <-> KSP Orbital)

| Puesto | Que opera en el Interior FTL | Que opera en la Vista Orbital KSP 2.5D |
| :--- | :--- | :--- |
| **1. Piloto (Timonel)** | Mantiene su avatar en consola `helm` para activar el *Manning Bonus* de giro. | Orienta la nave con la **NavBall 2.5D** hacia el marcador *Prograde/Retrograde/Nodo* y dispara el acelerador en la ventana de ignicion; esquiva escombros cercanos en el carril tactico. |
| **2. Oficial de Radar y Comms** | Opera consola `sensors` (proa); reorienta antena tras tormentas DONKI. | Coloca/ajusta el **Nodo de Maniobra KSP**, lee el **Radar Topografico 3D Wireframe (`pin_26`)** con 10–14 s de ventaja y elige el momento de linea de vista para transmitir ciencia DSN en apoapsis. |
| **3. Ingeniero de A Bordo** | Reasigna barras del reactor FTL entre Motores/Escudo/O2/Sensores, sella fugas y abre esclusas de venteo en crisis de 5 s. | Garantiza que `Motores` tenga las barras requeridas **justo antes de `T-0`** del encendido orbital; si hay fuga en Popa durante la ignicion, la elipse proyectada KSP oscila en tiempo real alertando al equipo. |
| **4. Operador Cientifico y Termico** | Opera `science_bay` y `life_support`; activa *Storm Safe* y refrigeracion en radiadores. | Dispara muestreo orbital en `PE` / paso por asteroide NEO y monitoriza carga termica al cruzar el corredor de reentrada atmosferica. |

---

## 4. Sistema Visual de Interfaz: Tokens, Tipografia y Layout Medido

### 4.1 Paleta Cromatica Definitiva (NASAPunk + *Rhine Lab `pin_18`* + Rampa `TLP `pin_25`)

| Token | Hex | Rol en UI / Render |
| :--- | :--- | :--- |
| `void_deep` | `#080c16` | Fondo espacial base y lienzo orbital KSP |
| `surface_chassis` | `#0f1726` | Bandejas y marco estructural de HUD |
| `surface_raised` | `#172236` | Salas activas, bloques de modulo, selecciones |
| `surface_active_band` | `#1e2d47` | Banda de estado seleccionado (sin bordes blancos flotantes) |
| `ink_cream` | `#f4ebd9` | Trazos de elipses orbitales, rotulos principales y arcos *Rhine Lab* |
| `ink_muted` | `#8b9bb4` | Unidades, rotulos secundarios, guias de escala |
| `accent_terracotta` | `#c83e2b` | Alertas criticas de casco/calor, banda tricolor NASA, limite atmosferico |
| `accent_amber` | `#f09c14` | Orbitas previstas, barras de reactor activas, fuego, advertencia |
| `accent_cyan` | `#38bdf8` | Progreso orbital, radar wireframe, LEDs de nivel 3-4, telemetria DSN |
| `status_ok` | `#22c55e` | Sistema integro, vector alineado en NavBall, oxigeno nominal |
| `outline_pixel` | `#0b0e17` | Contorno unificador 1 px de `CanvasGroup` y division de mamparos |

### 4.2 Reglas Tipograficas Estrictas (`design-kb`)
- **Fuente de marca / encabezados:** Sans geometrica (`Noto Sans` / `Inter` / `Liberation Sans`) en *sentence case*, peso `600`.
- **Fuente de rotulos / botones / descripciones:** Sans limpia minimo `12 px` (`13–14 px` recomendado en controles).
- **Fuente de telemetria numerica exclusivamente:** Monospace tabular (`IBM Plex Mono` / `Liberation Mono` / `DejaVu Sans Mono`), minimo `11 px`, reservada unicamente a cifras reales (`420 m/s`, `AP 340 km`, `T-00:14`, `14.2 W`, `P_exp 12%`).
- **Prohibicion total:** Prohibido utilizar `JetBrains Mono` en cualquier escena, tema, shader, CSS o SVG.
- **Anti-patrones vetados:** Cero tarjetas con borde blanco generico, cero iconos huerfanos sin etiqueta de texto, cero tablas de KPIs flotantes y maximo **un** panel lateral derecho (0/12 herramientas profesionales usan doble panel derecho).

---

## 5. Arquitectura de las 5 Pantallas de Juego (1280 x 720, Escala `expand`)

### Pantalla 1: Mapa Astrofisico de Contratos (Estilo *Rhine Lab `pin_18`*)
- **Distribucion:** Banda superior (`44 px`) con saldo de quiebra, nivel de chasis actual y progreso de agencia; **Lienzo central (74%)** mostrando el diagrama heliocéntrico estatico/animado con los 4 contratos reales (Luna, Marte, Jupiter/Europa, Telescopio LEO/NEO) conectados por arcos crema `#f4ebd9` y banda tricolor sobre la trayectoria seleccionada; **Panel derecho unico (26%)** con ficha fisica del destino (`planetary_catalog.json`: gravedad, irradiancia solar `%`, latencia DSN, requisitos de escudo/RTG) y boton primario naranja `#f09c14` **"Preparar Nave en Dique"**.

### Pantalla 2: Dique Seco Modular 2.5D y Evolucion (`LVL 1` a `LVL 5`)
*(Ver mockup de referencia: [mockup_1_dique_modular_25d.png](mockups/mockup_1_dique_modular_25d.png))*
- **Zona superior (`44 px`):** Contrato activo, creditos disponibles, botones de vista (**Casco Exterior 2.5D** / **Corte FTL 6 Salas**) y retorno.
- **Columna izquierda (`24%`):** Selector de los 7 Hardpoints del chasis predeterminado y botones de accion clara ("Instalar", "Subir a LVL N", "Calidad: Chatarra / Usada / Nueva") con indicador de costo e iconos + etiqueta sans legible (`>= 12 px`).
- **Escena central unica (`50%`):** Nave `Orbital Mule Mk-I` centrada en escala `2x` pixel-perfect, mostrando simultaneamente los modulos acoplados con sus abrazaderas 2.5D, anillos de nivel (`pin_08`) y corte translucido de las 6 salas interiores cuando se pasa el cursor o conmuta la vista.
- **Panel derecho unico (`26%`):** Tres barras esenciales de ingenieria (Alcance $\Delta v$ vs requerido, Energia solar/RTG en destino, Riesgo de despegue $P_{explosion}$) + ficha breve del perk NASA equipado y boton **"A Rampa de Lanzamiento"**.

### Pantalla 3: HUD Principal de Vuelo Dual (FTL Interior 2.5D + KSP 2.5D Orbital)
*(Ver mockup de referencia: [mockup_2_hud_ftl_ksp_orbital.png](mockups/mockup_2_hud_ftl_ksp_orbital.png))*
- **Franja superior (`44 px`):** Reloj `MET`, estado de casco y O2 global, combustible restante, `AP / PE` actuales, proximo nodo `T-Node` y distancia/flujo solar del dataset NASA activo.
- **Lienzo central (`74%` del ancho):** Dividido visualmente con fluidez espacial (sin recuadros rigidos):
  - **Mitad izquierda/central (Escena Tactica FTL):** Nave `Orbital Mule Mk-I` en corte 2.5D animado sobre fondo estelar/debris en movimiento; los 4 bots/tripulantes se desplazan por las 6 salas; salas con incendios/brechas muestran cuenta regresiva `5.0 s`; esclusas exteriores clicables/atajo.
  - **Incrustacion Orbital KSP 2.5D (Sector derecho del lienzo central o toggle rapido `M` para mapa orbital ampliado):** Planeta con terminador Bayer 4x4, orbita crema `#f4ebd9`, marcadores `AP` / `PE`, arco punteado de maniobra $\Delta v$ y posicion en tiempo real de la nave + ventana de comunicacion DSN.
  - **Consola inferior integrada (centrada bajo el lienzo, `84 px` de alto):** **NavBall 2.5D** (horizonte artificial con pipas Prograde/Retrograde/Maniobra), barra deslizante de empuje de motor, palanca de armado/descarga y barra discreta FTL de **Barras de Reactor** (`helm`, `engines`, `sensors`, `shields`, `O2`, `science`) con click/atajos para reasignar energia en vivo.
- **Panel derecho unico (`26%`):** Arriba el **Radar Topografico 3D Wireframe (`pin_26`)** exclusivo del puesto de Sensores/Radar (aviso anticipado de basura Kessler CelesTrak, asteroides NEO y tormentas solares DONKI) y debajo la lista limpia de **Alertas Activas de Sala (5 s)** con indicador de puesto sugerido y boton de venteo rapido.

### Pantalla 4: Maniobra Critica — Despegue Max-Q y Reentrada Atmosferica KSP 2.5D
- Reutiliza el HUD base sin romper la continuidad: sustituye la esquina orbital por el **Perfil de Corredor Atmosferico 2.5D** (altura vs temperatura de plasma y presion dinamica *max-Q*).
- Muestra en el centro-inferior el margen angular permitido (`[-5.2 deg, -3.8 deg]`) vinculado en vivo a la NavBall 2.5D, y en emergencias de ascenso activa la palanca protegida **"Descartar Carga Auxiliar (Jettison)"** o **"Torre de Escape (LES)"** con temporizador rojo de 4 s.

### Pantalla 5: Expediente Causal Post-Mision y Evolucion de Agencia
- Layout editorial limpio estilo informe tecnico NASA (*sin parrillas de KPIs sueltos*):
  - Columna izquierda (`55%`): Auditoria causal **"Que hiciste bien"** (verde) vs **"Que hiciste mal"** (terracota) con explicacion fisica exacta (ej. irradiancia `3.7%` en Jupiter vs RTG, fuga no reparada en `engines`, sobrecarga en rampa).
  - Columna derecha (`45%`): Balance financiero de la agencia en quiebra, avance de desbloqueo/credito para subir modulos de `LVL 1..5` en el Dique Seco y ficha oficial de citas NASA/JPL/DONKI/CelesTrak usadas en esa mision.
