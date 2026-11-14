# 02. Sistema Orbital KSP 2.5D y Física de Vuelo

**Objeto:** Definir el modelo matemático simplificado, la visual 2.5D inspirada en *Kerbal Space Program* + *Rhine Lab / Lone Trail* (`pin_18`) y la integración operativa entre el timón, los nodos de maniobra $\Delta v$, la NavBall 2.5D, el corredor de reentrada y el Radar 3D Wireframe (`pin_26`).

## 1. Modelo Kepleriano Simplificado en 2.5D

Aunque la simulación corre en 2D plano orbital (con inclinación escalar para conjunciones y reentrada), la órbita mostrada sobre el lienzo central se calcula exactamente con ecuaciones cónicas de dos cuerpos alrededor del cuerpo activo ($\mu = G M_{cuerpo}$):

- **Parámetro gravitacional efectivo escalado de juego ($\mu_{sim}$):** Normalizado por cuerpo desde `planetary_catalog.json` (`gravity_m_s2` y radio planetario efectivo $R_p$) para que una órbita baja dure entre `35 y 65 segundos` de tiempo jugable real.
- **Ecuación Vis-Viva (velocidad instantánea):**
  $$v = \sqrt{\mu_{sim} \left(\frac{2}{r} - \frac{1}{a}\right)}$$
- **Apoapsis (`AP`), Periapsis (`PE`) y Excentricidad ($e$):**
  $$r_{AP} = a(1 + e), \qquad r_{PE} = a(1 - e), \qquad h_{AP} = r_{AP} - R_p, \qquad h_{PE} = r_{PE} - R_p$$
  - Si $h_{PE} \le h_{atmo}$ (ej. `100 km` Tierra o `80 km` Marte), el marcador `PE` cambia a ámbar/terracota (`#f09c14` / `#c83e2b`) indicando entrada al anillo de frenado aerodinámico o riesgo de impacto si $h_{PE} \le 0$.
  - Si $e \ge 1.0$, la cónica pasa de elipse cerrada a hipérbola de escape interplanetario (línea crema abierta hacia el borde del mapa).

## 2. Nodos de Maniobra ($\Delta v$ Burn) y Acoplamiento con el Reactor FTL

El **Oficial de Radar/Navegación** (o el jugador en modo `SOLO`) coloca un nodo interactivo sobre la elipse crema actual (`#f4ebd9`):

1. **Tres ejes de ajuste directo:**
   - **Prograde / Retrograde ($\Delta v_t$):** Estira o encoge el lado opuesto de la órbita (`AP` o `PE`). Respeta la paradoja orbital real: acelerar en `PE` eleva `AP` con máxima eficiencia (**Efecto Oberth**).
   - **Radial In / Out ($\Delta v_r$):** Rota el eje de los ápsides para alinear ventana de descenso o esquivar un cinturón de detritos `debris_leo_catalog.json`.
2. **Cálculo en vivo de duración del encendido:**
   $$t_{burn} = \frac{m_{total} \cdot |\Delta v_{nodo}|}{T_{efectivo}}$$
   donde $T_{efectivo} = T_{nominal} \cdot \text{ReactorPower.efficiency}(\text{\&"engines"})$ penalizado por fugas o daño en la sala `engines`.
3. **Tensión cooperativa en la cuenta regresiva `T-Node`:**
   - Si el **Ingeniero** asigna solo 1 barra a `engines`, $t_{burn}$ se duplica y la nave no completa la quema dentro de la ventana de transferencia.
   - Si estalla una fuga en `engines` (`fuel_leak_rate > 0` en `RoomHazards`) mientras el **Piloto** quema, la elipse punteada dorada (`#f09c14`) tiembla y pierde $\Delta v$ en tiempo real.

## 3. NavBall 2.5D y Marcadores de Orientación

Anclada en el centro de la consola inferior (`84 px` de alto en [mockup_2_hud_ftl_ksp_orbital.png](mockups/mockup_2_hud_ftl_ksp_orbital.png)), la **NavBall 2.5D** proyecta una esfera pixel-art rotatoria con horizonte artificial:

- **Hemisferio superior (cielo/espacio exterior `#1e3a5f`)** y **hemisferio inferior (superficie `#5c3317`)** divididos por línea de horizonte `#f4ebd9`.
- **Cuatro pipas vectoriales de color inequívoco:**
  - **Prograde (`#22c55e`, círculo con 3 aletas):** Sentido exacto del vector velocidad orbital.
  - **Retrograde (`#86efac`, círculo con X):** Sentido opuesto para frenado de captura o deorbitado.
  - **Vector de Nodo (`#38bdf8`, diamante técnico):** Dirección exacta exigida por el nodo $\Delta v$ programado.
  - **Normal / Antinormal (`#f09c14`):** Corrección lateral contra fragmentos de basura espacial o nubes de tormenta.
- **Bono de Puente (`helm`):** Cuando el Piloto permanece en consola con potencia activa (`manning_bonus = +0.25` en `ReactorPower`), la respuesta angular de la NavBall acelera un 25% y muestra un cono verde de tolerancia ampliada. Sin piloto activo (`SOLO` en otra sala), la NavBall oscila con banda muerta del piloto automático al `45%` (`StationInput`).

## 4. Corredor de Reentrada Atmosférica y Max-Q (Marte y Tierra)

Durante el descenso hacia cuerpos con `surface_pressure_bar > 0` (`planetary_catalog.json`), la esquina orbital cambia a **Perfil de Corredor Atmosférico 2.5D**:

- **Densidad exponencial:** $\rho(h) = (1.225 \cdot P_{bar}) \cdot e^{-h/H_{km}}$ (`earth`: $1.0\text{ bar}, H=8.5\text{ km}$; `mars`: $0.0064\text{ bar}, H=11.1\text{ km}$).
- **Banda angular segura (`[-5.2 deg, -3.8 deg]`):**
  - Ángulo **demasiado plano ($> -3.8^\circ$):** La nave rebota fuera de la atmósfera (*skip-out*) consumiendo reserva de propelente extra para un segundo intento.
  - Ángulo **demasiado empinado ($< -5.2^\circ$):** El flujo térmico crece con $\frac{1}{2}\rho v^3$, dispara temperatura sobre `0.85` (`overheated`) y destruye paneles solares o manta MLI (`q > 12000 Pa`) salvo contar con escudo `shield_hrsi` o `shield_pica`.
- **Apertura de paracaídas en Marte:** A $0.0064\text{ bar}$, el aire tenue no frena por sí solo; requiere despliegue de paracaídas entre Mach 2.0 y Mach 0.8 combinado con pulso final de retropropulsión en `engines`. En la **Luna** (`surface_pressure_bar = 0.0`), el corredor desaparece y muestra perfil balístico puro de descenso propulsado 100%.

## 5. Radar Topográfico 3D Wireframe (`pin_26`) y Ventanas de Downlink DSN

El panel derecho único (`26%` del ancho) aloja en su mitad superior la proyección isométrica wireframe en líneas `#38bdf8` (malla de sector) y vectores `#f09c14` / `#c83e2b` (objetos entrantes):

- **Asimetría intencional de información:** Solo el **Oficial de Radar** (consola `sensors` operativa con $\ge 1$ barra) recibe el trazado predictivo con **10 a 14 s** de ventaja (expandible a `14 s` con `radar_doppler` o `18 s` en `LVL 5`). El Piloto únicamente percibe objetos dentro de los últimos `2.5 a 3.0 s` en el carril frontal.
- **Objetos representados en el wireframe:**
  - Enjambres de fragmentos orbitales (`debris_leo_catalog.json`: ISS `420 km`, Cosmos–Iridium `790 km`, Fengyun-1C `850 km`).
  - Trayectorias de encuentro cercano NEO (`neo_curated_missions.json`: Bennu, Didymos, Eros, Psyche) marcando distancia segura para muestreo sin colisión.
  - Frente de eyección de masa coronal (`solar_events_scenarios.json`) mostrando temporizador exacto hasta impacto magnético.
- **Indicador de Línea de Vista DSN:** Arco verde sobre la esfera 2.5D que muestra cuándo la antena dorsal (`SOCKET_DORSAL_TURRET`) apunta hacia la estación terrestre activa (Goldstone, Madrid o Canberra) para descargar ciencia antes del apagón tras la cara oculta del planeta.
