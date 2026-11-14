import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "assets"

# Paleta industrial con hue-shifting (ref. pin_25 + pin_08 + pin_22)
PAL_TIERS = {
    1: {
        "base": (71, 85, 105),
        "hi": (108, 125, 148),
        "lo": (38, 46, 62),
        "ext": (24, 30, 44),
        "trim": (133, 62, 24),
        "led": (200, 62, 43),
    },
    2: {
        "base": (96, 110, 136),
        "hi": (142, 158, 184),
        "lo": (50, 61, 82),
        "ext": (31, 39, 56),
        "trim": (224, 142, 24),
        "led": (240, 156, 20),
    },
    3: {
        "base": (162, 176, 198),
        "hi": (218, 228, 242),
        "lo": (88, 102, 126),
        "ext": (48, 58, 78),
        "trim": (249, 115, 22),
        "led": (56, 189, 248),
    },
    4: {
        "base": (203, 213, 225),
        "hi": (248, 250, 252),
        "lo": (108, 122, 146),
        "ext": (56, 68, 90),
        "trim": (234, 179, 8),
        "led": (56, 189, 248),
    },
    5: {
        "base": (218, 228, 240),
        "hi": (255, 255, 255),
        "lo": (116, 132, 158),
        "ext": (60, 74, 98),
        "trim": (251, 191, 36),
        "led": (254, 240, 138),
    },
}

OUTLINE = (11, 14, 23, 255)
AO_DARK = (14, 20, 34, 255)
SLATE_DARK = (22, 32, 50, 255)
SLATE_WALL = (30, 45, 71, 255)
SLATE_TOP = (100, 116, 139, 255)
CLAMP_WHITE = (241, 245, 249, 255)
CLAMP_HI = (255, 255, 255, 255)
CLAMP_EDGE = (51, 65, 85, 255)
CREAM = (244, 235, 217, 255)
CYAN = (56, 189, 248, 255)
CYAN_BRIGHT = (224, 242, 254, 255)
AMBER = (240, 156, 20, 255)
TERRA = (200, 62, 43, 255)
OK = (34, 197, 94, 255)
KAPTON = (234, 179, 8, 255)
KAPTON_HI = (254, 240, 138, 255)


def ensure_dirs() -> None:
    for sub in ("ship", "modules", "crew", "fx"):
        (ROOT / sub).mkdir(parents=True, exist_ok=True)


def save_clean(img: Image.Image, rel_path: str) -> None:
    p = ROOT / rel_path
    img.save(p, format="PNG", optimize=True)


def rgba(rgb: tuple[int, int, int], a: int = 255) -> tuple[int, int, int, int]:
    return (rgb[0], rgb[1], rgb[2], a)


def draw_bevel_plate(
    d: ImageDraw.ImageDraw,
    x: int,
    y: int,
    w: int,
    h: int,
    pal: dict,
    ext_h: int = 4,
    bevel: int = 2,
    border: bool = True,
    rivets: bool = False,
) -> None:
    """Dibuja una placa industrial 2.5D con luz 315 deg, extrusion inferior y costura."""
    base = rgba(pal["base"])
    hi = rgba(pal["hi"])
    lo = rgba(pal["lo"])
    ext = rgba(pal["ext"])

    # Extrusion 2.5D inferior
    if ext_h > 0:
        d.rectangle([x, y + h - ext_h, x + w - 1, y + h - 1], fill=ext)
    body_h = max(h - ext_h, 2)
    d.rectangle([x, y, x + w - 1, y + body_h - 1], fill=base)

    # Luz direccional a 315 grados (borde superior e izquierdo)
    d.rectangle([x, y, x + w - 1, y + bevel - 1], fill=hi)
    d.rectangle([x, y, x + bevel - 1, y + body_h - 1], fill=hi)

    # Sombra derecha e inferior de la cara superior
    d.rectangle([x + w - bevel, y + bevel, x + w - 1, y + body_h - 1], fill=lo)
    d.rectangle([x + bevel, y + body_h - bevel, x + w - 1, y + body_h - 1], fill=lo)

    if border:
        d.rectangle([x, y, x + w - 1, y + h - 1], outline=OUTLINE)

    if rivets and w >= 16 and body_h >= 14:
        for rx in (x + 4, x + w - 5):
            for ry in (y + 4, y + body_h - 5):
                d.point((rx, ry), fill=lo)


def draw_led_strip(d: ImageDraw.ImageDraw, cx: int, y: int, lvl: int, pal: dict) -> None:
    """Dibuja 1..5 indicadores LED contadores estilo pin_08."""
    total_w = 5 * 6 + 4 * 2
    x0 = cx - total_w // 2
    led = rgba(pal["led"])
    for idx in range(5):
        lx = x0 + idx * 8
        if idx < lvl:
            d.rectangle([lx, y, lx + 5, y + 3], fill=led, outline=OUTLINE)
        else:
            d.rectangle([lx, y, lx + 5, y + 3], fill=(24, 32, 48, 255), outline=OUTLINE)


def build_hulls_and_roof() -> None:
    for lvl in range(1, 6):
        pal = PAL_TIERS[lvl]
        img = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        base = rgba(pal["base"])
        hi = rgba(pal["hi"])
        lo = rgba(pal["lo"])
        ext = rgba(pal["ext"])
        trim = rgba(pal["trim"])

        # 1) Proa bifurcada en horquilla estilo pin_22 (y: 4..36)
        for px in (48, 94):
            draw_bevel_plate(d, px, 4, 18, 32, pal, ext_h=4, bevel=2, border=True, rivets=(lvl >= 2))
            # Franja central en horquilla
            d.rectangle([px + 7, 8, px + 10, 24], fill=hi if px == 48 else lo)
        # Sensores internos en la hendidura central (x: 70..90)
        d.rectangle([70, 12, 76, 30], fill=lo, outline=OUTLINE)
        d.rectangle([84, 12, 90, 30], fill=lo, outline=OUTLINE)
        d.rectangle([72, 14, 74, 20], fill=CYAN if lvl >= 3 else trim)
        d.rectangle([86, 14, 88, 20], fill=CYAN if lvl >= 3 else trim)

        # 2) Modulo de proa / puente (y: 14..64, cubre sensors+helm sin sobresalir)
        draw_bevel_plate(d, 28, 14, 104, 50, pal, ext_h=5, bevel=2, border=True, rivets=True)
        # Placa central biselada de cabina
        d.polygon([(50, 16), (110, 16), (124, 58), (36, 58)], fill=base, outline=OUTLINE)
        d.polygon([(50, 16), (80, 16), (80, 58), (36, 58)], fill=hi)
        # Cupula ovalada oscura con destello horizontal (pin_22)
        d.ellipse([58, 22, 102, 50], fill=(15, 23, 42, 255), outline=OUTLINE)
        d.rectangle([64, 31, 96, 35], fill=CYAN_BRIGHT if lvl >= 4 else (CYAN if lvl >= 2 else (148, 163, 184, 255)))
        d.rectangle([72, 25, 88, 27], fill=(51, 65, 85, 255))

        # 3) Casco maestro central por placas articuladas (x: 8..151, y: 60..168)
        draw_bevel_plate(d, 8, 60, 144, 108, pal, ext_h=5, bevel=2, border=True, rivets=True)

        # Costuras internas de mamparos y sub-placas (1 px OUTLINE + luz 315 deg)
        # Bloque babor, nucleo reactor, bloque estribor
        draw_bevel_plate(d, 14, 65, 32, 58, pal, ext_h=4, bevel=1, border=True, rivets=(lvl >= 2))
        draw_bevel_plate(d, 48, 65, 64, 58, pal, ext_h=4, bevel=2, border=True, rivets=True)
        draw_bevel_plate(d, 114, 65, 32, 58, pal, ext_h=4, bevel=1, border=True, rivets=(lvl >= 2))

        # Placas inferiores de casco medio (y: 125..160)
        draw_bevel_plate(d, 14, 125, 64, 34, pal, ext_h=4, bevel=1, border=True, rivets=(lvl >= 3))
        draw_bevel_plate(d, 82, 125, 64, 34, pal, ext_h=4, bevel=1, border=True, rivets=(lvl >= 3))

        # Franja industrial y rieles de oclusion para acoplamiento de gondolas
        d.rectangle([10, 148, 149, 153], fill=trim, outline=OUTLINE)
        d.rectangle([8, 70, 14, 136], fill=OUTLINE)
        d.rectangle([145, 70, 151, 136], fill=OUTLINE)
        # Espina central mecanica
        d.rectangle([77, 50, 82, 164], fill=lo, outline=OUTLINE)

        # 4) Faldon trasero articulado con dos vainas gemelas (y: 164..194)
        draw_bevel_plate(d, 30, 164, 100, 30, pal, ext_h=4, bevel=2, border=True, rivets=False)
        draw_bevel_plate(d, 38, 166, 28, 26, pal, ext_h=4, bevel=2, border=True, rivets=True)
        draw_bevel_plate(d, 94, 166, 28, 26, pal, ext_h=4, bevel=2, border=True, rivets=True)

        # 5) Detalles diferenciales por evolucion LVL 1..5
        if lvl == 1:
            # Parches remachados asimetricos de chatarra
            draw_bevel_plate(d, 18, 76, 22, 16, {"base": (120, 53, 15), "hi": (160, 82, 34), "lo": (76, 32, 10), "ext": (48, 20, 8)}, ext_h=2, bevel=1, border=True)
            draw_bevel_plate(d, 116, 130, 24, 16, {"base": (100, 58, 24), "hi": (140, 84, 40), "lo": (62, 34, 14), "ext": (40, 22, 10)}, ext_h=2, bevel=1, border=True)
        if lvl >= 2:
            # Rejillas de ventilacion laterales
            for vy in range(74, 106, 6):
                d.rectangle([19, vy, 40, vy + 2], fill=ext)
                d.rectangle([119, vy, 140, vy + 2], fill=ext)
        if lvl >= 3:
            # Aros protectores y luces de navegacion
            d.rectangle([28, 66, 40, 71], fill=rgba(pal["led"]), outline=OUTLINE)
            d.rectangle([120, 66, 132, 71], fill=rgba(pal["led"]), outline=OUTLINE)
            d.ellipse([68, 80, 92, 104], fill=lo, outline=OUTLINE)
            d.ellipse([72, 84, 88, 100], fill=base, outline=OUTLINE)
        if lvl >= 4:
            # Recubrimiento Kapton oro en proa y vainas traseras
            d.rectangle([34, 48, 52, 58], fill=KAPTON, outline=OUTLINE)
            d.rectangle([35, 49, 44, 52], fill=KAPTON_HI)
            d.rectangle([108, 48, 126, 58], fill=KAPTON, outline=OUTLINE)
            d.rectangle([109, 49, 118, 52], fill=KAPTON_HI)
            d.rectangle([42, 170, 62, 180], fill=KAPTON, outline=OUTLINE)
            d.rectangle([98, 170, 118, 180], fill=KAPTON, outline=OUTLINE)
        if lvl == 5:
            # Espina luminiscente cian/blanca y nucleo dorsal energizado
            d.rectangle([76, 58, 83, 164], fill=CYAN, outline=OUTLINE)
            d.rectangle([78, 60, 81, 162], fill=CYAN_BRIGHT)
            d.ellipse([72, 84, 88, 100], fill=CYAN, outline=OUTLINE)
            d.ellipse([76, 88, 84, 96], fill=CYAN_BRIGHT)

        # Indicadores LED de nivel (pin_08)
        draw_led_strip(d, 80, 184, lvl, pal)
        save_clean(img, f"ship/hull_base_lvl{lvl}.png")

    # Techo cutaway translucible (capa 3 del flujo FTL)
    roof = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
    dr = ImageDraw.Draw(roof)
    roof_pal = PAL_TIERS[3]
    draw_bevel_plate(dr, 32, 16, 96, 46, roof_pal, ext_h=4, bevel=2, border=True, rivets=True)
    dr.ellipse([60, 24, 100, 48], fill=(15, 23, 42, 240), outline=OUTLINE)
    dr.rectangle([66, 32, 94, 36], fill=CYAN)
    draw_bevel_plate(dr, 12, 64, 136, 98, roof_pal, ext_h=5, bevel=2, border=True, rivets=True)
    # Costuras internas de planchas de techo
    dr.line([(80, 64), (80, 158)], fill=OUTLINE, width=1)
    dr.line([(12, 112), (148, 112)], fill=OUTLINE, width=1)
    draw_bevel_plate(dr, 34, 164, 92, 26, roof_pal, ext_h=4, bevel=2, border=True, rivets=True)
    # Anillo dorsal de montaje
    dr.ellipse([62, 86, 98, 122], fill=rgba(roof_pal["lo"]), outline=OUTLINE)
    dr.ellipse([68, 92, 92, 116], fill=rgba(roof_pal["hi"]), outline=OUTLINE)
    save_clean(roof, "ship/roof_cutaway.png")


def build_interior_floor() -> None:
    """Capa 2 FTL: 6 salas exactas con mamparos completos, muros 2.5D y consolas."""
    img = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Silueta estructural interior oscura ajustada al casco
    d.rectangle([28, 12, 131, 64], fill=OUTLINE)
    d.rectangle([8, 60, 151, 166], fill=OUTLINE)
    d.rectangle([30, 126, 129, 190], fill=OUTLINE)

    # Salas exactas coincidentes con ModularShip25D.ROOM_RECTS
    rooms = [
        (32, 14, 32, 48, "sensors", (20, 32, 50, 255)),
        (64, 14, 64, 48, "helm", (22, 34, 54, 255)),
        (12, 64, 34, 62, "life_support", (18, 30, 48, 255)),
        (46, 64, 52, 62, "reactor", (18, 36, 56, 255)),
        (98, 64, 50, 62, "science_bay", (20, 34, 54, 255)),
        (34, 130, 92, 54, "engines", (24, 30, 46, 255)),
    ]
    for rx, ry, rw, rh, rid, floor_col in rooms:
        x2 = rx + rw - 1
        y2 = ry + rh - 1
        d.rectangle([rx, ry, x2, y2], fill=floor_col)

        # Rejilla de piso 16x16 px con sutil sombreado
        for gx in range(rx + 16, x2, 16):
            d.line([(gx, ry + 8), (gx, y2 - 2)], fill=(30, 44, 68, 255))
        for gy in range(ry + 16, y2, 16):
            d.line([(rx + 2, gy), (x2 - 2, gy)], fill=(30, 44, 68, 255))

        # Muro 2.5D superior (arista 3px clara + cara vertical 6px oscura)
        d.rectangle([rx, ry, x2, ry + 2], fill=SLATE_TOP)
        d.rectangle([rx, ry + 3, x2, ry + 8], fill=SLATE_WALL)
        d.line([(rx, ry + 9), (x2, ry + 9)], fill=AO_DARK)

        # Mamparos perimetrales completos (incluyendo verticales entre salas contiguas)
        d.rectangle([rx, ry, rx + 1, y2], fill=OUTLINE)
        d.rectangle([x2 - 1, ry, x2, y2], fill=OUTLINE)
        d.rectangle([rx, y2 - 1, x2, y2], fill=OUTLINE)
        d.rectangle([rx, ry, x2, ry], fill=OUTLINE)

    # Consola sensores (sensors: 32..64, 14..62)
    d.rectangle([38, 26, 58, 40], fill=(36, 50, 74, 255), outline=OUTLINE)
    d.rectangle([41, 29, 55, 36], fill=(12, 22, 34, 255))
    d.rectangle([42, 30, 50, 35], fill=OK)
    d.rectangle([52, 30, 54, 35], fill=CYAN)

    # Consola puente dual (helm: 64..128, 14..62)
    d.rectangle([76, 25, 118, 39], fill=(36, 50, 74, 255), outline=OUTLINE)
    d.rectangle([80, 28, 94, 35], fill=CYAN)
    d.rectangle([98, 28, 114, 35], fill=AMBER)
    d.rectangle([84, 42, 92, 49], fill=(51, 65, 85, 255), outline=OUTLINE)
    d.rectangle([102, 42, 110, 49], fill=(51, 65, 85, 255), outline=OUTLINE)

    # Tanques O2 en life_support (12..46, 64..126) + esclusa izquierda
    d.rectangle([18, 78, 28, 112], fill=CYAN, outline=OUTLINE)
    d.rectangle([20, 80, 22, 108], fill=CYAN_BRIGHT)
    d.rectangle([30, 82, 38, 108], fill=(51, 65, 85, 255), outline=OUTLINE)
    d.rectangle([12, 88, 15, 110], fill=AMBER, outline=OUTLINE)

    # Nucleo reactor central octogonal (reactor: 46..98, 64..126)
    d.rectangle([56, 80, 88, 112], fill=(30, 41, 59, 255), outline=OUTLINE)
    d.line([(48, 96), (96, 96)], fill=CYAN, width=2)
    d.line([(72, 74), (72, 118)], fill=CYAN, width=2)
    d.ellipse([60, 84, 84, 108], fill=AMBER, outline=OUTLINE)
    d.ellipse([66, 90, 78, 102], fill=KAPTON_HI)

    # Mesa espectral en science_bay (98..148, 64..126)
    d.rectangle([110, 80, 138, 108], fill=(30, 58, 95, 255), outline=OUTLINE)
    d.rectangle([114, 84, 134, 95], fill=CYAN, outline=OUTLINE)
    d.rectangle([118, 98, 130, 104], fill=OK)

    # Bancadas de turbobombas en popa (engines: 34..126, 130..184) + esclusa trasera
    for bx in (42, 98):
        draw_bevel_plate(d, bx, 144, 20, 30, PAL_TIERS[2], ext_h=3, bevel=1, border=True)
        d.rectangle([bx + 5, 150, bx + 14, 164], fill=AMBER, outline=OUTLINE)
        d.rectangle([bx + 7, 152, bx + 12, 158], fill=KAPTON_HI)
    d.rectangle([66, 179, 94, 184], fill=AMBER, outline=OUTLINE)

    # Puertas presurizadas de paso entre las 6 salas
    doors = [
        (61, 34, 66, 50),   # sensors <-> helm
        (37, 59, 53, 66),   # sensors <-> life_support
        (73, 59, 91, 66),   # helm <-> reactor
        (43, 88, 48, 104),  # life_support <-> reactor
        (95, 88, 100, 104), # reactor <-> science_bay
        (69, 123, 91, 132), # reactor <-> engines
    ]
    for x1, y1, x2, y2 in doors:
        d.rectangle([x1, y1, x2, y2], fill=(203, 213, 225, 255), outline=OUTLINE)
        d.rectangle([x1 + 2, y1 + 2, x2 - 2, y2 - 2], fill=CYAN)

    save_clean(img, "ship/interior_floor_6rooms.png")


def build_modules() -> None:
    for lvl in range(1, 6):
        pal = PAL_TIERS[lvl]
        trim = rgba(pal["trim"])
        led = rgba(pal["led"])
        hi = rgba(pal["hi"])
        lo = rgba(pal["lo"])
        ext = rgba(pal["ext"])

        # BOW: Escudo PICA curvo continuo sin brecha transparente (64x36)
        im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        # Collar de anclaje biselado inferior (y: 20..34) conectado al arco
        draw_bevel_plate(d, 12, 20, 40, 14, pal, ext_h=3, bevel=1, border=True)
        # Arco termico PICA continuo (y: 4..28)
        d.pieslice([4, 4, 59, 44], 180, 360, fill=(133, 62, 51, 255) if lvl < 3 else (180, 83, 9, 255), outline=OUTLINE)
        d.arc([7, 7, 56, 40], 195, 345, fill=KAPTON_HI if lvl >= 4 else (245, 185, 125, 255), width=2)
        # Costuras de losetas en escudo
        for sx in (22, 32, 42):
            d.line([(sx, 9), (sx, 22)], fill=OUTLINE, width=1)
        d.rectangle([16, 23, 47, 29], fill=rgba(pal["base"]), outline=OUTLINE)
        draw_led_strip(d, 32, 29, lvl, pal)
        save_clean(im, f"modules/bow_shield_lvl{lvl}.png")

        # BOW: Radar Doppler Ku (64x36)
        im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        draw_bevel_plate(d, 14, 16, 36, 18, pal, ext_h=3, bevel=1, border=True)
        d.ellipse([18, 2, 46, 24], fill=hi, outline=OUTLINE)
        d.ellipse([23, 6, 41, 20], fill=CYAN, outline=OUTLINE)
        d.ellipse([28, 9, 36, 15], fill=CYAN_BRIGHT)
        draw_led_strip(d, 32, 28, lvl, pal)
        save_clean(im, f"modules/bow_radar_lvl{lvl}.png")

        # BOW: Torre de Escape LES (64x36)
        im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        draw_bevel_plate(d, 16, 22, 32, 12, pal, ext_h=3, bevel=1, border=True)
        d.polygon([(32, 1), (42, 24), (22, 24)], fill=TERRA, outline=OUTLINE)
        d.polygon([(32, 3), (32, 23), (23, 23)], fill=(235, 92, 64, 255))
        d.rectangle([27, 13, 37, 17], fill=CLAMP_WHITE, outline=OUTLINE)
        draw_led_strip(d, 32, 28, lvl, pal)
        save_clean(im, f"modules/bow_les_lvl{lvl}.png")

        # NACELLE: Tanque / MMRTG / Blindaje con toma frontal y abrazaderas pin_22 (44x104)
        for kind in ("tank", "rtg", "armor"):
            im = Image.new("RGBA", (44, 104), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            # Toma cilindrica frontal superior (estilo pin_22)
            draw_bevel_plate(d, 14, 2, 16, 14, pal, ext_h=2, bevel=1, border=True)
            # Tobera secundaria trasera
            draw_bevel_plate(d, 12, 88, 20, 14, pal, ext_h=3, bevel=1, border=True)
            # Cuerpo principal de gondola con extrusion inferior
            draw_bevel_plate(d, 6, 12, 32, 78, pal, ext_h=5, bevel=2, border=True, rivets=(lvl >= 2))

            if kind == "tank":
                d.rectangle([12, 16, 31, 24], fill=trim, outline=OUTLINE)
                d.rectangle([12, 38, 31, 60], fill=hi, outline=OUTLINE)
                d.rectangle([17, 41, 26, 57], fill=CYAN if lvl >= 4 else lo, outline=OUTLINE)
            elif kind == "rtg":
                for fy in range(16, 84, 8):
                    d.rectangle([4, fy, 39, fy + 3], fill=ext, outline=OUTLINE)
                d.rectangle([16, 15, 27, 83], fill=trim, outline=OUTLINE)
                d.rectangle([18, 42, 25, 58], fill=AMBER, outline=OUTLINE)
            else:
                draw_bevel_plate(d, 8, 16, 28, 68, pal, ext_h=4, bevel=2, border=True, rivets=True)
                d.rectangle([14, 40, 29, 60], fill=trim, outline=OUTLINE)

            if lvl >= 4:
                d.rectangle([10, 74, 33, 81], fill=KAPTON, outline=OUTLINE)

            # Dos abrazaderas horizontales blancas + hebilla cuadrada oscura (pin_22)
            for cy in (26, 64):
                d.rectangle([1, cy, 42, cy + 9], fill=CLAMP_EDGE, outline=OUTLINE)
                d.rectangle([2, cy + 1, 41, cy + 6], fill=CLAMP_WHITE)
                d.rectangle([2, cy + 1, 41, cy + 2], fill=CLAMP_HI)
                # Hebilla cuadrada negra en el centro
                d.rectangle([17, cy + 1, 26, cy + 8], fill=OUTLINE)
                d.rectangle([19, cy + 3, 24, cy + 6], fill=CLAMP_WHITE)

            # LEDs de nivel verticales/horizontales en base
            for p_idx in range(5):
                lx = 10 + p_idx * 5
                col_led = led if p_idx < lvl else (28, 36, 52, 255)
                d.rectangle([lx, 93, lx + 3, 96], fill=col_led, outline=OUTLINE)
            save_clean(im, f"modules/nacelle_{kind}_lvl{lvl}.png")

        # WING: Solar / Radiador con rotula UNICA en el borde interior derecho (x=54..63) (64x36)
        # (wing_port usa flip_h=false -> rotula derecha toca gondola babor;
        #  wing_stbd usa flip_h=true  -> rotula flipped izquierda toca gondola estribor)
        for kind in ("solar", "radiator"):
            im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            # Rotula mecanica unica en borde interior derecho (x: 52..63)
            draw_bevel_plate(d, 52, 10, 11, 16, pal, ext_h=3, bevel=1, border=True)
            d.rectangle([55, 14, 59, 21], fill=trim, outline=OUTLINE)

            if kind == "solar":
                # Marco exterior + extrusion inferior 3px
                d.rectangle([2, 6, 53, 30], fill=OUTLINE)
                d.rectangle([2, 28, 53, 31], fill=ext)
                cell_col = (24, 52, 128, 255) if lvl < 4 else (14, 116, 144, 255)
                d.rectangle([4, 8, 51, 27], fill=cell_col, outline=OUTLINE)
                # Celulas fotovoltaicas
                grid_col = CYAN if lvl >= 3 else (96, 165, 250, 255)
                for sx in range(12, 49, 8):
                    d.line([(sx, 8), (sx, 27)], fill=grid_col, width=1)
                d.line([(4, 17), (51, 17)], fill=KAPTON if lvl >= 4 else trim, width=1)
                if lvl == 5:
                    d.rectangle([6, 10, 49, 12], fill=CYAN_BRIGHT)
            else:
                # Radiador plegable de amoniaco NH3
                draw_bevel_plate(d, 2, 7, 51, 24, pal, ext_h=3, bevel=1, border=True)
                for sx in range(8, 49, 6):
                    d.line([(sx, 9), (sx, 26)], fill=lo, width=2)
                    d.line([(sx + 2, 9), (sx + 2, 26)], fill=hi, width=1)
                d.rectangle([4, 15, 51, 19], fill=CYAN if lvl >= 4 else trim, outline=OUTLINE)
            save_clean(im, f"modules/wing_{kind}_lvl{lvl}.png")

        # DORSAL: Antena DSN / Brazo Canadarm / CMG (48x48)
        for kind in ("dsn", "arm", "cmg"):
            im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            # Sombra proyectada (+2, +2 px)
            d.ellipse([10, 12, 42, 44], fill=(11, 14, 23, 160))
            if kind == "dsn":
                d.ellipse([7, 7, 40, 40], fill=hi, outline=OUTLINE)
                d.ellipse([12, 12, 35, 35], fill=rgba(pal["base"]), outline=OUTLINE)
                d.ellipse([17, 17, 30, 30], fill=lo)
                d.rectangle([22, 16, 25, 29], fill=CYAN, outline=OUTLINE)
                d.ellipse([20, 12, 27, 18], fill=trim, outline=OUTLINE)
            elif kind == "arm":
                draw_bevel_plate(d, 14, 14, 20, 20, pal, ext_h=3, bevel=1, border=True)
                d.line([(24, 24), (38, 10)], fill=OUTLINE, width=6)
                d.line([(24, 24), (38, 10)], fill=CLAMP_WHITE, width=3)
                d.line([(38, 10), (42, 22)], fill=OUTLINE, width=5)
                d.line([(38, 10), (42, 22)], fill=trim, width=2)
                d.rectangle([38, 20, 45, 27], fill=CYAN, outline=OUTLINE)
            else:
                d.ellipse([8, 8, 40, 40], fill=hi, outline=OUTLINE)
                d.ellipse([12, 12, 36, 36], fill=rgba(pal["base"]), outline=OUTLINE)
                d.ellipse([17, 17, 31, 31], fill=trim, outline=OUTLINE)
                d.ellipse([21, 21, 27, 27], fill=CYAN)
            save_clean(im, f"modules/dorsal_{kind}_lvl{lvl}.png")

        # AFT: Motores Hipergolico / Criogenico / Ionico (36x44)
        for kind in ("hypergolic", "cryo", "ion"):
            im = Image.new("RGBA", (36, 44), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            draw_bevel_plate(d, 7, 2, 22, 14, pal, ext_h=2, bevel=1, border=True)
            if kind == "hypergolic":
                d.polygon([(8, 15), (28, 15), (33, 35), (3, 35)], fill=lo, outline=OUTLINE)
                d.polygon([(10, 16), (18, 16), (18, 34), (5, 34)], fill=rgba(pal["base"]))
                d.rectangle([6, 32, 30, 36], fill=AMBER, outline=OUTLINE)
            elif kind == "cryo":
                d.polygon([(7, 15), (29, 15), (34, 38), (2, 38)], fill=lo, outline=OUTLINE)
                d.polygon([(9, 16), (18, 16), (18, 37), (4, 37)], fill=rgba(pal["base"]))
                for ry in range(20, 35, 4):
                    d.line([(5, ry), (31, ry)], fill=trim, width=1)
                d.rectangle([6, 36, 30, 41], fill=KAPTON if lvl >= 4 else trim, outline=OUTLINE)
            else:
                d.ellipse([5, 14, 31, 36], fill=(24, 36, 56, 255), outline=OUTLINE)
                d.ellipse([8, 17, 28, 33], fill=CYAN, outline=OUTLINE)
                d.ellipse([12, 21, 24, 29], fill=CYAN_BRIGHT)
            save_clean(im, f"modules/aft_{kind}_lvl{lvl}.png")


def build_crew_and_fx() -> None:
    crew_colors = {
        "pilot": ((240, 156, 20, 255), CYAN),
        "radar": ((56, 189, 248, 255), (248, 250, 252, 255)),
        "engineer": ((249, 115, 22, 255), (254, 240, 138, 255)),
        "mission": ((34, 197, 94, 255), (248, 250, 252, 255)),
    }
    for role, (suit, visor) in crew_colors.items():
        im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        # Sombra suelo 2.5D
        d.ellipse([5, 16, 19, 22], fill=(11, 14, 23, 170))
        # Mochila EVA
        d.rectangle([4, 11, 8, 18], fill=(100, 116, 139, 255), outline=OUTLINE)
        # Torso y piernas
        d.rectangle([6, 11, 18, 19], fill=suit, outline=OUTLINE)
        d.rectangle([8, 17, 11, 20], fill=(51, 65, 85, 255), outline=OUTLINE)
        d.rectangle([13, 17, 16, 20], fill=(51, 65, 85, 255), outline=OUTLINE)
        # Casco y visor
        d.rectangle([7, 3, 17, 12], fill=CLAMP_WHITE, outline=OUTLINE)
        d.rectangle([9, 5, 15, 9], fill=visor, outline=OUTLINE)
        d.point((10, 6), fill=CLAMP_HI)
        save_clean(im, f"crew/crew_{role}.png")

    # Tira de fuego 4 frames (96x24) con contorno y nucleo amarillo
    fire = Image.new("RGBA", (96, 24), (0, 0, 0, 0))
    df = ImageDraw.Draw(fire)
    for f in range(4):
        ox = f * 24
        dy = (f % 2) * 2
        sway = -1 if f in (1, 2) else 1
        df.polygon([(ox + 12 + sway, 2 + dy), (ox + 20, 19), (ox + 4, 19)], fill=TERRA, outline=OUTLINE)
        df.polygon([(ox + 12, 6 + dy), (ox + 17, 19), (ox + 7, 19)], fill=AMBER)
        df.ellipse([ox + 9, 12, ox + 15, 19], fill=KAPTON_HI)
        df.point((ox + 8 + f, 4), fill=AMBER)
    save_clean(fire, "fx/fire_sheet.png")

    # Icono brecha al vacio (24x24)
    breach = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    db = ImageDraw.Draw(breach)
    db.polygon([(3, 12), (10, 3), (19, 6), (21, 15), (12, 21), (4, 17)], fill=OUTLINE, outline=TERRA)
    db.line([(6, 6), (18, 18)], fill=CYAN, width=2)
    db.line([(18, 6), (6, 18)], fill=CYAN, width=2)
    db.ellipse([9, 9, 15, 15], fill=(8, 12, 22, 255), outline=CYAN_BRIGHT)
    save_clean(breach, "fx/breach_icon.png")

    # Tira de pluma de motor + ondas de choque 4 frames (144x48) estilo pin_08
    shock = Image.new("RGBA", (144, 48), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shock)
    for f in range(4):
        ox = f * 36
        cx = ox + 18
        len_p = 20 + (f % 2) * 6
        ds.polygon([(cx - 8, 2), (cx + 8, 2), (cx, 2 + len_p + 8)], fill=AMBER)
        ds.polygon([(cx - 4, 2), (cx + 4, 2), (cx, 2 + len_p)], fill=KAPTON_HI)
        # Onda de choque en media luna blanca/cian (pin_08)
        arc_y = 14 + f * 6
        ds.arc([cx - 13, arc_y, cx + 13, arc_y + 10], 10, 170, fill=CYAN_BRIGHT, width=2)
        ds.point((cx - 6, arc_y + 12), fill=CLAMP_WHITE)
        ds.point((cx + 5, arc_y + 14), fill=AMBER)
    save_clean(shock, "fx/thruster_shock_sheet.png")

    # Meteoro / escombro LEO con cola pixelada estilo pin_15 (32x32)
    meteor = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    dm = ImageDraw.Draw(meteor)
    for step in range(4):
        tx = 18 + step * 3
        ty = 12 - step * 2
        dm.line([(12, 18), (tx, ty)], fill=CYAN if step < 2 else (100, 116, 139, 180), width=2)
    dm.polygon([(6, 18), (11, 13), (18, 15), (17, 23), (9, 25)], fill=(100, 116, 139, 255), outline=OUTLINE)
    dm.polygon([(8, 18), (12, 15), (15, 17), (12, 21)], fill=(203, 213, 225, 255))
    dm.point((15, 20), fill=AMBER)
    save_clean(meteor, "fx/debris_meteor.png")


if __name__ == "__main__":
    ensure_dirs()
    build_hulls_and_roof()
    build_interior_floor()
    build_modules()
    build_crew_and_fx()
    print("Generated 2.5D assets in:", ROOT)
