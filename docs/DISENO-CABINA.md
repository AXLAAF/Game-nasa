# Diseno de interfaz: tablero Margin Zero

Direccion visual del juego jugable (`game/`). Usa la paleta de identidad de
`BRANDING-MARGIN-ZERO.md` y de los documentos VectorCraft de `docs/art/` (logo de la orbita,
`planetas_fondos`, hoja de robots) y las tipografias de `docs/art/fonts/`.

## Idea

La pantalla es una ventana y un tablero. El mundo en pixel art se ve por la ventana. La interfaz
es el tablero de una nave embargada: bastidores azul noche, tinta crema, una sola tecla ambar por
pantalla, cian para el dato real y terracota para la deuda y el fallo.

## Color

Los tokens viven en `game/ui/ui.gd`. No se escriben colores sueltos en la interfaz. Los nombres
vienen del tablero de cabina anterior; el papel de cada uno no cambio.

| Token | Hex | Marca | Uso |
|---|---|---|---|
| `BG` | `#080C16` | `void_deep` | Fondo y huecos de lectura. |
| `BAKELITE` | `#0F1726` | `surface_chassis` | Paneles y cartas. |
| `BAKELITE_RAISED`, `ENAMEL` | `#172236` | `surface_raised` | Teclas, filas elevadas, consola y placas. |
| `BAKELITE_EDGE` | `#1E2D47` | `surface_active_band` | Bordes, tecla bajo el cursor, lampara apagada. |
| `ENAMEL_SHADE` | `#0B0E17` | `outline_pixel` | Contornos y tecla hundida. |
| `IVORY` | `#F4EBD9` | `ink_cream` | Texto, cifras, seleccion, dinero. |
| `IVORY_DIM` | `#8B9BB4` | `ink_muted` | Texto secundario y leyendas. |
| `INFO`, `ENAMEL_LIGHT` | `#38BDF8` | `accent_cyan` | Dato real, telemetria nominal, filo de consola y placas. |
| `ACCENT`, `LAMP_CAUTION` | `#F09C14` | `accent_amber` | Tecla principal (rellena, con labio) y lampara de precaucion (ficha plana con leyenda). |
| `LAMP_GO` | `#22C55E` | `status_ok` | En orden. |
| `TERRACOTTA` | `#C83E2B` | `accent_terracotta` | Marca de deuda. Solo rellenos y bordes: como texto sobre el panel no llega a 4.5:1. |
| `LAMP_WARNING` | `#E8604A` | terracota encendido | Fallo, como texto o lampara (5.2:1 sobre el panel). |
| `MYSTERY` | `#B48CF2` | | Piezas misteriosas y radiacion. |

Lamparas: apagada no dice nada, verde en orden, ambar precaucion, rojo fallo. Una lampara lleva
siempre su leyenda; el color nunca es la unica senal. Su ancho sale de la leyenda: no se recorta.

## Tipografia

Exo 2 y Space Mono (SIL OFL, `assets/fonts/`). Pixelta solo para el rotulo "Margin Zero".

- `Ui.sans()` Exo 2 Regular para texto y botones, `Ui.bold()` Exo 2 SemiBold para titulos.
- `Ui.mono()` Space Mono, solo cifras (telemetria, dinero) en ventanas de lectura.
- `Ui.legend_font()` leyendas grabadas.
- `Ui.title_font()` Pixelta, el rotulo de marca en el titulo y en la cabecera del hangar.
- Escala: 13 leyenda, 15 texto, 18 subtitulo, 24 lectura, 36 lectura principal. Nada por debajo de 13.

## Vidrio

Los paneles son de vidrio liquido (`game/shaders/glass.gdshader`, `Ui.glass`): desenfocan lo que
tienen detras, le suben un poco la saturacion y lo tinen con su color de estilo. El alfa del
estilo es la opacidad del tinte (`Ui.GLASS_TINT`, 0.6; la consola de vuelo 0.72 porque va sobre
el cielo claro del despegue). El filo `Ui.RIM` hace de reflejo, mas marcado arriba. Sin sombras.

- Solo los paneles de primer nivel llevan el shader: `Ui.panel`, `Ui.console`, la matriz de
  lamparas, cartas, modales, tutorial, el catalogo del montaje y el panel interior de la nave.
  Godot copia la pantalla una vez por capa, asi que un vidrio dentro de otro no veria a su padre.
- Lo anidado (teclas, huecos de lectura, placas, fichas de contrato) es translucido sin shader.
- La tecla principal y las lamparas siguen opacas: son lo que hay que leer de un vistazo.

## Maquetacion

- Las pantallas de menu se montan con contenedores, no con posiciones a mano. La columna de
  contenido tiene un ancho maximo y se centra; en ventanas anchas crecen los margenes.
- La esquina superior izquierda es del engranaje de ajustes (`Pause.GEAR_RECT`): ninguna pantalla
  pone nada debajo.
- `tests/layout_lint.gd` recorre los controles visibles y falla si algo queda fuera de la ventana,
  con el texto cortado o pisando a otra pieza. `tests/smoke_runner.gd` lo pasa en cada fase;
  `SMOKE_SIZE` y `SMOKE_CREW` eligen ventana y jugadores. Un solape buscado (modal, carta,
  tutorial) se declara con el meta `layout_overlay`.

## Texto

- Mayusculas solo en la leyenda grabada de un instrumento (`Ui.legend`, `Lamp`, `Gauge`).
- Todo lo demas en minuscula normal, con tildes y enes.
- Un boton dice lo que hace: "Aceptar contrato", "Despegar". La tecla va al final: "Reparar (R)".
- Un error dice que paso y que hacer.

## Componentes

| Pieza | Donde | Para que |
|---|---|---|
| `Ui.panel` | bastidor oscuro de borde fino | contenedor por defecto |
| `Ui.plate` | banda elevada con filo cian | titulo de un panel |
| `Ui.readout` | leyenda + hueco con cifra en mono | una cifra clave |
| `Ui.console` | franja inferior de `Ui.CONSOLE_H` | instrumentos de las fases de vuelo |
| `Ui.primary` | tecla ambar | la accion principal |
| `Ui.mark_selected` | borde marfil | opcion elegida en un selector |
| `Lamp` | `game/ui/lamp.gd` | estado con leyenda |
| `Annunciator` | `game/ui/annunciator.gd` | una lampara por pieza de la nave; `C` despliega el detalle |
| `Gauge` | `game/ui/gauge.gd` | cinta de medida con marcas cada 10 % |
| `Modal` | `game/ui/modal.gd` | ventana de menu (pausa, ajustes, creditos, confirmaciones); Esc la cierra y devuelve el foco |

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
