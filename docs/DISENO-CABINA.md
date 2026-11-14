# Diseno de interfaz: cabina de segunda mano

Direccion visual del juego jugable actual (`game/`, "Contratista Orbital"). Reemplaza en este
juego a la paleta y tipografia de `BRANDING-MARGIN-ZERO.md` y `DISEÑO-UI-NAVES-25D.md`, que
siguen describiendo el remake.

## Idea

La pantalla es una ventana y un tablero. El mundo en pixel art se ve por la ventana. La interfaz
es el tablero fisico de una nave usada: chapa esmaltada, ventanas de lectura oscuras, teclas de
baquelita y lamparas de aviso.

## Color

Los tokens viven en `game/ui/ui.gd`. No se escriben colores sueltos en la interfaz.

| Token | Hex | Uso |
|---|---|---|
| `ENAMEL` | `#3E8F8A` | Chapa del tablero y bisel de los paneles. Solo leyendas cortas en `BAKELITE`. |
| `ENAMEL_SHADE` | `#2C6B67` | Bisel inferior. |
| `BAKELITE` | `#16181A` | Ventanas de lectura, fondo de paneles y cartas. |
| `BAKELITE_RAISED` | `#24272A` | Teclas y filas elevadas. |
| `IVORY` | `#EFE6CF` | Texto, cifras, seleccion, dinero. |
| `IVORY_DIM` | `#A9A493` | Texto secundario. |
| `INFO` | `#8FD6CE` | Dato nominal o informativo. |
| `LAMP_GO` | `#58C96B` | En orden. |
| `LAMP_CAUTION` | `#FFB000` | Precaucion. |
| `LAMP_WARNING` | `#F0503F` | Fallo. |
| `MYSTERY` | `#B48CF2` | Piezas misteriosas y radiacion. |

El texto largo va siempre sobre fondo oscuro. Sobre esmalte el marfil no llega a 4.5:1, por eso
ahi solo se usa `BAKELITE`.

Lamparas: apagada no dice nada, verde en orden, ambar precaucion, rojo fallo. Una lampara lleva
siempre su leyenda; el color nunca es la unica senal.

## Tipografia

B612 y B612 Mono (SIL OFL, `assets/fonts/`), la familia que Airbus diseno para pantallas de cabina.

- `Ui.sans()` texto y botones, `Ui.bold()` titulos.
- `Ui.mono()` solo cifras de telemetria en ventanas de lectura.
- `Ui.legend_font()` leyendas grabadas.
- Escala: 13 leyenda, 15 texto, 18 subtitulo, 24 lectura, 36 lectura principal. Nada por debajo de 13.

## Texto

- Mayusculas solo en la leyenda grabada de un instrumento (`Ui.legend`, `Lamp`, `Gauge`).
- Todo lo demas en minuscula normal, con tildes y enes.
- Un boton dice lo que hace: "Aceptar contrato", "Despegar". La tecla va al final: "Reparar (R)".
- Un error dice que paso y que hacer.

## Componentes

| Pieza | Donde | Para que |
|---|---|---|
| `Ui.panel` | ventana oscura con bisel de esmalte | contenedor por defecto |
| `Ui.plate` | cabecera esmaltada | titulo de un panel |
| `Ui.readout` | leyenda + hueco con cifra en mono | una cifra clave |
| `Ui.console` | franja inferior de `Ui.CONSOLE_H` | instrumentos de las fases de vuelo |
| `Ui.primary` | tecla marfil | la accion principal |
| `Ui.mark_selected` | borde marfil | opcion elegida en un selector |
| `Lamp` | `game/ui/lamp.gd` | estado con leyenda |
| `Annunciator` | `game/ui/annunciator.gd` | una lampara por pieza de la nave; `C` despliega el detalle |
| `Gauge` | `game/ui/gauge.gd` | cinta de medida con marcas cada 10 % |

## Movimiento

El unico movimiento no provocado por el jugador es la prueba de lamparas al entrar en una fase de
vuelo. `Profile.reduced_motion` apaga sacudida, destellos, parpadeos y esa prueba.

## Mundo

- El filtro de pantalla (`game/fx/screen.gdshader`) degrada la ventana, no el tablero: va en la
  capa 5 y la interfaz en la 10 o superior.
- La nave se dibuja en una rejilla de 2 unidades, con luz fija arriba a la izquierda y un solo
  contorno para toda la silueta (`game/fx/ship_renderer.gd`).
- Con `hdr_2d` la textura del viewport es lineal: una captura hecha con `get_image()` hay que
  pasarla a sRGB (`tools/shots.gd` ya lo hace).
