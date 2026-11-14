import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "assets"

PAL_TIERS = {
    1: {"base": (71, 85, 105), "hi": (100, 116, 139), "lo": (40, 49, 64), "trim": (120, 53, 15), "led": (200, 62, 43)},
    2: {"base": (100, 116, 139), "hi": (148, 163, 184), "lo": (51, 65, 85), "trim": (240, 156, 20), "led": (240, 156, 20)},
    3: {"base": (203, 213, 225), "hi": (241, 245, 249), "lo": (100, 116, 139), "trim": (249, 115, 22), "led": (56, 189, 248)},
    4: {"base": (241, 245, 249), "hi": (255, 255, 255), "lo": (148, 163, 184), "trim": (234, 179, 8), "led": (56, 189, 248)},
    5: {"base": (248, 250, 252), "hi": (255, 255, 255), "lo": (100, 116, 139), "trim": (251, 191, 36), "led": (254, 240, 138)},
}

OUTLINE = (11, 14, 23, 255)
SLATE_DARK = (22, 32, 50, 255)
SLATE_WALL = (30, 45, 71, 255)
SLATE_TOP = (71, 85, 105, 255)
CLAMP_WHITE = (241, 245, 249, 255)
CLAMP_EDGE = (51, 65, 85, 255)
CYAN = (56, 189, 248, 255)
AMBER = (240, 156, 20, 255)
TERRA = (200, 62, 43, 255)
OK = (34, 197, 94, 255)


def ensure_dirs() -> None:
    for sub in ("ship", "modules", "crew", "fx"):
        (ROOT / sub).mkdir(parents=True, exist_ok=True)


def save_clean(img: Image.Image, rel_path: str) -> None:
    p = ROOT / rel_path
    img.save(p, format="PNG", optimize=True)


def draw_bevel_rect(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, pal: dict, border: int = 2) -> None:
    base = pal["base"] + (255,)
    hi = pal["hi"] + (255,)
    lo = pal["lo"] + (255,)
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=base)
    draw.rectangle([x, y, x + w - 1, y + border], fill=hi)
    draw.rectangle([x, y, x + border, y + h - 1], fill=hi)
    draw.rectangle([x, y + h - 4, x + w - 1, y + h - 1], fill=lo)
    draw.rectangle([x + w - 3, y, x + w - 1, y + h - 1], fill=lo)


def build_hulls_and_roof() -> None:
    for lvl in range(1, 6):
        pal = PAL_TIERS[lvl]
        img = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        # Proa biseccionada (y: 12..68)
        d.polygon([(56, 14), (104, 14), (132, 64), (28, 64)], fill=pal["base"] + (255,))
        d.polygon([(56, 14), (80, 14), (80, 64), (28, 64)], fill=pal["hi"] + (255,))
        # Cabina oscura frontal
        d.polygon([(62, 22), (98, 22), (108, 46), (52, 46)], fill=(15, 23, 42, 255))
        d.rectangle([58, 28, 102, 34], fill=CYAN if lvl >= 3 else (51, 65, 85, 255))

        # Casco medio principal (y: 62..166)
        draw_bevel_rect(d, 10, 62, 140, 104, pal, border=3)
        # Faldon popa (y: 164..192)
        draw_bevel_rect(d, 28, 162, 104, 28, pal, border=2)

        # Lineas tecnicas y franja industrial
        trim = pal["trim"] + (255,)
        d.rectangle([14, 148, 145, 154], fill=trim)
        d.rectangle([78, 50, 81, 184], fill=pal["lo"] + (255,))

        # Rieles de montaje lateral
        d.rectangle([10, 74, 15, 134], fill=OUTLINE)
        d.rectangle([144, 74, 149, 134], fill=OUTLINE)

        # Detalles por evolucion LVL 1..5
        if lvl == 1:
            d.rectangle([24, 82, 46, 98], fill=trim)
            d.rectangle([110, 118, 130, 136], fill=trim)
        if lvl >= 3:
            d.rectangle([28, 68, 42, 74], fill=pal["led"] + (255,))
            d.rectangle([118, 68, 132, 74], fill=pal["led"] + (255,))
        if lvl >= 4:
            # Paneles Kapton oro en proa y popa
            d.rectangle([42, 52, 62, 60], fill=trim)
            d.rectangle([98, 52, 118, 60], fill=trim)
            d.rectangle([38, 168, 56, 180], fill=trim)
            d.rectangle([104, 168, 122, 180], fill=trim)
        if lvl == 5:
            # Ribetes dorados y canal luminiscente central
            d.rectangle([76, 62, 84, 160], fill=(14, 165, 233, 255))
            d.rectangle([78, 62, 82, 160], fill=(224, 242, 254, 255))

        # Indicadores LED de nivel en el borde trasero (pin_08)
        for idx in range(lvl):
            lx = 56 + idx * 10
            d.rectangle([lx, 182, lx + 6, 186], fill=pal["led"] + (255,))

        save_clean(img, f"ship/hull_base_lvl{lvl}.png")

    # Techo cutaway translucible
    roof = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
    dr = ImageDraw.Draw(roof)
    dr.polygon([(52, 22), (108, 22), (126, 62), (34, 62)], fill=(148, 163, 184, 220))
    dr.rectangle([18, 66, 142, 160], fill=(100, 116, 139, 230))
    dr.rectangle([20, 66, 140, 70], fill=(203, 213, 225, 235))
    dr.rectangle([34, 162, 126, 186], fill=(71, 85, 105, 230))
    dr.rectangle([64, 88, 96, 120], fill=(51, 65, 85, 240))
    dr.rectangle([70, 94, 90, 114], fill=(148, 163, 184, 240))
    save_clean(roof, "ship/roof_cutaway.png")


def build_interior_floor() -> None:
    img = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Silueta interior oscura unificada
    d.rectangle([28, 12, 132, 64], fill=OUTLINE)
    d.rectangle([8, 60, 152, 166], fill=OUTLINE)
    d.rectangle([30, 128, 130, 190], fill=OUTLINE)

    # Salas exactas en grilla 32x32 px (con muros 2.5D arriba 3px claro, frente 6px oscuro)
    rooms = [
        (32, 14, 32, 48, "sensors"),
        (64, 14, 64, 48, "helm"),
        (12, 64, 34, 62, "life_support"),
        (46, 64, 52, 62, "reactor"),
        (98, 64, 50, 62, "science_bay"),
        (34, 130, 92, 54, "engines"),
    ]
    for rx, ry, rw, rh, rid in rooms:
        d.rectangle([rx, ry, rx + rw - 1, ry + rh - 1], fill=SLATE_DARK)
        # Rejilla interna 16 px
        for gx in range(rx + 8, rx + rw, 16):
            d.line([(gx, ry + 6), (gx, ry + rh - 4)], fill=(28, 42, 64, 255))
        for gy in range(ry + 12, ry + rh, 16):
            d.line([(rx + 2, gy), (rx + rw - 3, gy)], fill=(28, 42, 64, 255))
        # Muro 2.5D superior (arista clara 2px + cara vertical 6px)
        d.rectangle([rx, ry, rx + rw - 1, ry + 1], fill=SLATE_TOP)
        d.rectangle([rx, ry + 2, rx + rw - 1, ry + 7], fill=SLATE_WALL)
        d.rectangle([rx, ry + rh - 2, rx + rw - 1, ry + rh - 1], fill=OUTLINE)

    # Consola puente (helm)
    d.rectangle([82, 22, 114, 34], fill=(30, 41, 59, 255))
    d.rectangle([86, 24, 96, 30], fill=CYAN)
    d.rectangle([100, 24, 110, 30], fill=AMBER)

    # Consola sensores (sensors)
    d.rectangle([38, 24, 56, 38], fill=(30, 41, 59, 255))
    d.rectangle([42, 26, 52, 33], fill=OK)

    # Nucleo reactor central
    d.rectangle([60, 84, 84, 108], fill=(30, 41, 59, 255))
    d.rectangle([64, 88, 80, 104], fill=AMBER)
    d.rectangle([68, 92, 76, 100], fill=(254, 240, 138, 255))

    # Tanques O2 en life_support + esclusa izquierda
    d.rectangle([16, 80, 26, 106], fill=CYAN)
    d.rectangle([12, 90, 15, 110], fill=AMBER)

    # Mesa ciencia en science_bay
    d.rectangle([114, 82, 138, 104], fill=(30, 58, 95, 255))
    d.rectangle([118, 86, 134, 94], fill=CYAN)

    # Bancadas motores en popa + esclusa trasera
    d.rectangle([42, 146, 62, 174], fill=(51, 65, 85, 255))
    d.rectangle([98, 146, 118, 174], fill=(51, 65, 85, 255))
    d.rectangle([48, 154, 56, 166], fill=AMBER)
    d.rectangle([104, 154, 112, 166], fill=AMBER)
    d.rectangle([70, 178, 90, 183], fill=AMBER)

    # Puertas de paso entre salas
    doors = [
        (62, 34, 66, 48),
        (38, 60, 54, 68),
        (74, 60, 92, 68),
        (44, 88, 48, 104),
        (96, 88, 100, 104),
        (68, 124, 92, 134),
    ]
    for x1, y1, x2, y2 in doors:
        d.rectangle([x1, y1, x2, y2], fill=(203, 213, 225, 255))
        d.rectangle([x1 + 2, y1 + 2, x2 - 2, y2 - 2], fill=(56, 189, 248, 200))

    save_clean(img, "ship/interior_floor_6rooms.png")


def build_modules() -> None:
    for lvl in range(1, 6):
        pal = PAL_TIERS[lvl]
        trim = pal["trim"] + (255,)
        led = pal["led"] + (255,)

        # BOW: Escudo PICA curvo (64x36)
        im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.chord([4, 4, 60, 52], 190, 350, fill=pal["lo"] + (255,))
        d.chord([8, 8, 56, 48], 195, 345, fill=trim if lvl >= 3 else (146, 64, 14, 255))
        d.rectangle([14, 26, 50, 34], fill=pal["base"] + (255,))
        save_clean(im, f"modules/bow_shield_lvl{lvl}.png")

        # BOW: Radar Doppler (64x36)
        im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        draw_bevel_rect(d, 16, 16, 32, 18, pal)
        d.ellipse([20, 4, 44, 24], fill=pal["hi"] + (255,), outline=OUTLINE)
        d.ellipse([26, 9, 38, 19], fill=CYAN)
        save_clean(im, f"modules/bow_radar_lvl{lvl}.png")

        # BOW: Torre de Escape LES (64x36)
        im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.polygon([(32, 2), (42, 28), (22, 28)], fill=TERRA)
        d.rectangle([20, 26, 44, 34], fill=pal["hi"] + (255,))
        d.rectangle([28, 14, 36, 18], fill=CLAMP_WHITE)
        save_clean(im, f"modules/bow_les_lvl{lvl}.png")

        # NACELLE: Tanque / MMRTG / Blindaje con abrazaderas blancas (44x104)
        for kind in ("tank", "rtg", "armor"):
            im = Image.new("RGBA", (44, 104), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            draw_bevel_rect(d, 8, 8, 28, 88, pal, border=2)
            # Dos abrazaderas horizontales blancas (estilo pin_22)
            for cy in (28, 66):
                d.rectangle([2, cy, 41, cy + 9], fill=CLAMP_EDGE)
                d.rectangle([3, cy + 1, 40, cy + 7], fill=CLAMP_WHITE)
            if kind == "tank":
                d.rectangle([13, 14, 31, 24], fill=trim)
                d.rectangle([13, 40, 31, 62], fill=pal["hi"] + (255,))
                d.rectangle([18, 42, 26, 60], fill=CYAN if lvl >= 4 else pal["lo"] + (255,))
            elif kind == "rtg":
                for fy in range(14, 90, 8):
                    d.rectangle([6, fy, 37, fy + 3], fill=(40, 49, 64, 255))
                d.rectangle([17, 14, 27, 88], fill=trim)
                d.rectangle([19, 44, 25, 58], fill=AMBER)
            else:
                draw_bevel_rect(d, 10, 12, 24, 80, pal, border=3)
                d.rectangle([14, 42, 30, 62], fill=trim)
            d.rectangle([18, 92, 26, 95], fill=led)
            save_clean(im, f"modules/nacelle_{kind}_lvl{lvl}.png")

        # WING: Solar vs Radiador (64x36)
        for kind in ("solar", "radiator"):
            im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            # Bisagra central
            d.rectangle([0, 12, 8, 24], fill=pal["lo"] + (255,))
            d.rectangle([56, 12, 63, 24], fill=pal["lo"] + (255,))
            if kind == "solar":
                d.rectangle([8, 6, 55, 29], fill=(15, 23, 42, 255))
                d.rectangle([10, 8, 53, 27], fill=(30, 58, 138, 255) if lvl < 4 else (14, 116, 144, 255))
                for sx in range(14, 52, 8):
                    d.line([(sx, 8), (sx, 27)], fill=CYAN if lvl >= 3 else (51, 65, 85, 255))
                d.line([(10, 17), (53, 17)], fill=trim)
            else:
                d.rectangle([8, 8, 55, 27], fill=pal["hi"] + (255,))
                for sx in range(12, 54, 6):
                    d.line([(sx, 10), (sx, 25)], fill=pal["lo"] + (255,))
                d.rectangle([8, 16, 55, 19], fill=CYAN if lvl >= 4 else trim)
            save_clean(im, f"modules/wing_{kind}_lvl{lvl}.png")

        # DORSAL: Antena DSN / Brazo / CMG (48x48)
        for kind in ("dsn", "arm", "cmg"):
            im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            d.ellipse([10, 12, 42, 44], fill=(11, 14, 23, 140))  # sombra +2,+2
            if kind == "dsn":
                d.ellipse([8, 8, 40, 40], fill=pal["hi"] + (255,), outline=OUTLINE)
                d.ellipse([13, 13, 35, 35], fill=pal["base"] + (255,))
                d.rectangle([22, 18, 26, 28], fill=CYAN)
                d.rectangle([20, 14, 28, 18], fill=trim)
            elif kind == "arm":
                d.rectangle([16, 16, 32, 32], fill=pal["base"] + (255,))
                d.line([(24, 24), (38, 10)], fill=CLAMP_WHITE, width=4)
                d.line([(38, 10), (42, 22)], fill=trim, width=3)
                d.rectangle([38, 20, 44, 26], fill=CYAN)
            else:
                d.ellipse([10, 10, 38, 38], fill=pal["base"] + (255,), outline=OUTLINE)
                d.ellipse([16, 16, 32, 32], fill=trim)
                d.ellipse([20, 20, 28, 28], fill=CYAN)
            save_clean(im, f"modules/dorsal_{kind}_lvl{lvl}.png")

        # AFT: Motores Hipergolico / Criogenico / Ionico (36x44)
        for kind in ("hypergolic", "cryo", "ion"):
            im = Image.new("RGBA", (36, 44), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            draw_bevel_rect(d, 8, 2, 20, 12, pal)
            if kind == "hypergolic":
                d.polygon([(8, 14), (28, 14), (32, 32), (4, 32)], fill=(51, 65, 85, 255))
                d.rectangle([6, 30, 30, 33], fill=AMBER)
            elif kind == "cryo":
                d.polygon([(7, 14), (29, 14), (34, 34), (2, 34)], fill=pal["lo"] + (255,))
                for ry in range(18, 32, 4):
                    d.line([(5, ry), (31, ry)], fill=trim)
                d.rectangle([6, 34, 30, 41], fill=(249, 115, 22, 200))
            else:
                d.ellipse([6, 14, 30, 32], fill=(30, 41, 59, 255), outline=CYAN)
                d.ellipse([10, 18, 26, 28], fill=CYAN)
                d.ellipse([13, 21, 23, 25], fill=(224, 242, 254, 255))
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
        d.ellipse([5, 16, 19, 22], fill=(11, 14, 23, 150))  # sombra suelo
        d.rectangle([6, 10, 18, 19], fill=suit, outline=OUTLINE)
        d.rectangle([7, 3, 17, 12], fill=(241, 245, 249, 255), outline=OUTLINE)
        d.rectangle([9, 6, 15, 10], fill=visor)
        save_clean(im, f"crew/crew_{role}.png")

    # Tira de fuego 4 frames (96x24)
    fire = Image.new("RGBA", (96, 24), (0, 0, 0, 0))
    df = ImageDraw.Draw(fire)
    for f in range(4):
        ox = f * 24
        dy = (f % 2) * 2
        df.polygon([(ox + 12, 2 + dy), (ox + 20, 18), (ox + 4, 18)], fill=TERRA)
        df.polygon([(ox + 12, 6 + dy), (ox + 17, 19), (ox + 7, 19)], fill=AMBER)
        df.ellipse([ox + 9, 12, ox + 15, 19], fill=(254, 240, 138, 255))
    save_clean(fire, "fx/fire_sheet.png")

    # Icono brecha al vacio (24x24)
    breach = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    db = ImageDraw.Draw(breach)
    db.polygon([(4, 12), (10, 4), (18, 7), (21, 15), (12, 20), (5, 17)], fill=OUTLINE, outline=TERRA)
    db.line([(6, 6), (18, 18)], fill=CYAN, width=1)
    db.line([(18, 6), (6, 18)], fill=CYAN, width=1)
    save_clean(breach, "fx/breach_icon.png")


if __name__ == "__main__":
    ensure_dirs()
    build_hulls_and_roof()
    build_interior_floor()
    build_modules()
    build_crew_and_fx()
    print("Generated 2.5D assets in:", ROOT)
