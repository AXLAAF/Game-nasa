# Ciclo jugable

Roguelite de misiones espaciales. Cada partida es un contrato: armar una nave barata, despegar,
cruzar el sistema y aterrizar en el destino. Los creditos, el inventario, el seguro y las lecciones
persisten entre partidas (`user://profile.json`).

## Fases

| Fase | Script | Que decide el jugador |
|------|--------|-----------------------|
| Hangar | `game/phases/hangar.gd` | Contrato (pago, adelanto, plazo, rumor de peligro), seguro, rerollear el tablero |
| Ensamblaje | `game/phases/assembly.gd` | Piezas y su calidad (chatarra/usada/nueva/misteriosa), inspecciones, cajas misteriosas |
| Despegue | `game/phases/launch.gd` | Ventana de ignicion, acelerador en max-Q, cabeceo dentro del corredor, etapas, abortar |
| Espacio | `game/phases/space.gd` | Encendidos newtonianos, puntos de interes, sobrecarga del motor, reparar, instalar chatarra |
| Descenso | `game/phases/descent.gd` | Angulo de entrada, sustentacion, paracaidas, frenado suicida, plataforma, eyeccion |
| Liquidacion | `game/phases/debrief.gd` | Nada: cobra linea a linea y abre cajas |

Teclas de depuracion (solo builds de debug): F1 a F6 saltan a cada fase.

## Riesgo y apuestas

- Cada pieza tiene una condicion oculta segun su calidad. `fail_chance = ((1-condicion)*0.55 + desgaste*0.3) * estres * fragilidad`.
  Las misteriosas se revelan la primera vez que sufren estres.
- Momentos de estres: ignicion, max-Q, separacion, sobrecarga en el espacio, llamaradas, micrometeoroides,
  radiacion, calor o frio extremos, carga G, paracaidas, impacto al aterrizar (por zona de contacto).
- Una pieza que falla abre una carta de averia. Las cartas muestran probabilidades con niebla (+-18%)
  salvo que escanees (15% de bateria) o tengas la leccion "odds". Se resuelven con una ruleta.
- Racha: cada apuesta arriesgada ganada suma x0.25 al pago final; perder una la reinicia.
- Apuestas laterales al llegar a orbita: combustible al llegar, plazo, aterrizaje S.
- Puntos de interes con rareza (comun, rara, legendaria): asteroides en el cinturon, naves abandonadas,
  senales "?", un cometa retrogrado y sobrevuelos de lunas. Algunos abren minijuegos.

## Entorno segun la distancia a la estrella

Flujo solar `(2000/r)^2`. Cerca del sol hace falta radiador; lejos, manta termica o RTG.
Los paneles solares rinden menos lejos y se queman muy cerca. Glacia y Hielo tienen cinturones de radiacion.
La sombra de un planeta protege de las llamaradas. El ensamblaje lista los requisitos del destino.

## Entrada y aterrizaje

- El corredor se calcula simulando la nave real (`RocketMath.skip_edge`): mas plano rebota al espacio,
  mas empinado supera lo que el escudo absorbe por segundo y el calor pasa al casco.
- Escudo ablativo: absorbe hasta 0.6 de calor por segundo y se gasta 0.22 por unidad.
- Paracaidas: freno por debajo de 450 m/s, principal por debajo de 120 m/s y 6 km. Fuera de ventana se desgarran.
- Sin atmosfera hay que frenar con motor (T mantiene retrogrado). El indicador de frenado suicida avisa cuando quemar.
- Tolerancia de impacto: 4.5 m/s sin patas, 9 con patas. Plataforma + suave + recto = nota S.

## Datos

Todo el contenido son `Resource` en `res://content` (piezas, cuerpos, averias, encuentros) y lo carga `Catalog`.
La simulacion pura vive en `game/sim` y se prueba sin ventana:

```
godot --headless --path . --script res://tests/test_runner.gd   # simulacion + compilacion de todos los scripts
godot --headless --path . --script res://tests/smoke_runner.gd  # recorre todas las fases de una partida
```
