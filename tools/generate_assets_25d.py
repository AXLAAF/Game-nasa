#!/usr/bin/env python3
"""
Generador procedural de assets cenitales (top-down) + Planetas & Espacio 2D pixel-art
para Margin Zero: Deuda Orbital (MZ-1 LIBERTY / Orbital Mule Mk-I).

Referencias visuales integradas:
- Deep-Fold PixelPlanets & PixelSpace: mapeo esferico normalizado a 315°, fBm multi-octava,
  terminador cuantizado con matriz Bayer 4x4 hacia #080c16 y nebulosas dithered (pin_11, pin_15).
- FTL / Starsector / pin_22: nave cenital esculpida con mandibulas bifurcadas, espina y
  sponsons cilindricos, abrazaderas blancas con hebillas oscuras y 4 gondolas traseras.
- pin_08 / pin_25: evolucion mecanica real LVL 1..5 con hue-shifting y sin barras de UI.
"""

from __future__ import annotations

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "assets"

# Matriz ordenada Bayer 4x4 normalizada en [0, 1)
BAYER_4X4 = (
    (0.03125, 0.53125, 0.15625, 0.65625),
    (0.78125, 0.28125, 0.90625, 0.40625),
    (0.21875, 0.71875, 0.09375, 0.59375),
    (0.96875, 0.46875, 0.84375, 0.34375),
)

# Direccion solar uniforme a 315 grados (arriba-izquierda hacia camara)
_LX, _LY, _LZ = -0.62, -0.58, 0.528
_LL = math.sqrt(_LX * _LX + _LY * _LY + _LZ * _LZ)
LIGHT_DIR = (_LX / _LL, _LY / _LL, _LZ / _LL)

# Tokens cromaticos con hue-shifting frio/calido (ref. pin_25 + pin_22)
OUTLINE = (12, 11, 22, 255)
SPACE_BLACK = (5, 7, 13, 255)
ORBIT_NIGHT = (8, 12, 22, 255)
CLAMP_WHITE = (241, 245, 249, 255)
CLAMP_HI = (255, 255, 255, 255)
CLAMP_SHADE = (148, 163, 184, 255)
CYAN = (56, 189, 248, 255)
CYAN_BRIGHT = (186, 230, 253, 255)
CYAN_DEEP = (14, 116, 144, 255)
AMBER = (240, 156, 20, 255)
TERRA = (214, 72, 48, 255)
KAPTON = (234, 179, 8, 255)
KAPTON_HI = (254, 240, 138, 255)
KAPTON_LO = (161, 98, 7, 255)
STEEL_DARK = (30, 34, 52, 255)
OK_GREEN = (34, 197, 94, 255)

# Paletas por tier LVL 1..5 (sombras viran a indigo/violeta frio, luces a acero/marfil)
TIERS = {
    1: {
        "deep": (26, 28, 44),
        "lo": (46, 51, 74),
        "mid": (74, 82, 110),
        "hi": (116, 126, 156),
        "spec": (160, 172, 198),
        "trim": (168, 76, 36),
        "trim_hi": (224, 118, 60),
        "glow": (235, 110, 40),
    },
    2: {
        "deep": (29, 32, 52),
        "lo": (54, 62, 90),
        "mid": (92, 102, 134),
        "hi": (146, 158, 188),
        "spec": (198, 210, 230),
        "trim": (217, 134, 22),
        "trim_hi": (251, 191, 36),
        "glow": (245, 160, 32),
    },
    3: {
        "deep": (34, 40, 62),
        "lo": (68, 80, 110),
        "mid": (132, 146, 174),
        "hi": (196, 208, 226),
        "spec": (236, 242, 249),
        "trim": (234, 108, 24),
        "trim_hi": (253, 186, 116),
        "glow": (56, 189, 248),
    },
    4: {
        "deep": (38, 46, 70),
        "lo": (84, 98, 128),
        "mid": (168, 180, 202),
        "hi": (226, 234, 244),
        "spec": (255, 255, 255),
        "trim": (212, 156, 10),
        "trim_hi": (253, 224, 71),
        "glow": (56, 189, 248),
    },
    5: {
        "deep": (40, 50, 78),
        "lo": (92, 110, 144),
        "mid": (184, 198, 220),
        "hi": (240, 245, 252),
        "spec": (255, 255, 255),
        "trim": (234, 179, 8),
        "trim_hi": (254, 249, 195),
        "glow": (125, 211, 252),
    },
}


def ensure_dirs() -> None:
    for sub in ("planets", "space", "ship", "modules", "crew", "fx"):
        (ROOT / sub).mkdir(parents=True, exist_ok=True)


def save_clean(im: Image.Image, rel_path: str) -> None:
    im.save(ROOT / rel_path, "PNG")


def hex_rgb(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def lerp_c(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
    )


def clamp01(v: float) -> float:
    return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


# ---------------------------------------------------------------------------
# Ruido determinista 2D / 3D para Deep-Fold PixelPlanets y PixelSpace
# ---------------------------------------------------------------------------
def _hash3(ix: int, iy: int, iz: int, seed: int) -> float:
    n = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1597334677) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFF) / 16777215.0


def noise3(x: float, y: float, z: float, seed: int = 7) -> float:
    ix = math.floor(x)
    iy = math.floor(y)
    iz = math.floor(z)
    fx = x - ix
    fy = y - iy
    fz = z - iz
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    uz = fz * fz * (3.0 - 2.0 * fz)

    c000 = _hash3(ix, iy, iz, seed)
    c100 = _hash3(ix + 1, iy, iz, seed)
    c010 = _hash3(ix, iy + 1, iz, seed)
    c110 = _hash3(ix + 1, iy + 1, iz, seed)
    c001 = _hash3(ix, iy, iz + 1, seed)
    c101 = _hash3(ix + 1, iy, iz + 1, seed)
    c011 = _hash3(ix, iy + 1, iz + 1, seed)
    c111 = _hash3(ix + 1, iy + 1, iz + 1, seed)

    x00 = c000 + (c100 - c000) * ux
    x10 = c010 + (c110 - c010) * ux
    x01 = c001 + (c101 - c001) * ux
    x11 = c011 + (c111 - c011) * ux
    y0 = x00 + (x10 - x00) * uy
    y1 = x01 + (x11 - x01) * uy
    return y0 + (y1 - y0) * uz


def fbm3(x: float, y: float, z: float, seed: int = 7, octaves: int = 4) -> float:
    val = 0.0
    amp = 0.5
    freq = 1.0
    norm = 0.0
    for i in range(octaves):
        val += amp * noise3(x * freq, y * freq, z * freq, seed + i * 31)
        norm += amp
        amp *= 0.5
        freq *= 2.03
    return val / norm


def fbm2(x: float, y: float, seed: int = 11, octaves: int = 4) -> float:
    return fbm3(x, y, 0.37, seed=seed, octaves=octaves)


# ---------------------------------------------------------------------------
# 1.1 ASSETS DE PLANETAS Y ASTEROIDES (assets/planets/)
# ---------------------------------------------------------------------------
def quantize_terminator(ndotl: float, bx: int, by: int, steps: int = 4) -> int:
    """Convierte iluminacion continua [0,1] en banda discreta con dithering Bayer 4x4."""
    bayer = BAYER_4X4[by & 3][bx & 3]
    scaled = clamp01(ndotl) * steps
    band = int(math.floor(scaled + (bayer - 0.5) * 0.85))
    return max(0, min(steps, band))


def shade_with_terminator(base_rgb: tuple[int, int, int], ndotl: float, bx: int, by: int, night_rgb=(8, 12, 22)) -> tuple[int, int, int]:
    band = quantize_terminator(ndotl, bx, by, steps=4)
    factors = (0.04, 0.24, 0.54, 0.82, 1.0)
    f = factors[band]
    return lerp_c(night_rgb, base_rgb, f)


def render_pixel_planet(logical_size: int, final_size: int, shader_fn, radius_ratio: float = 0.42, atmo_rgb: tuple[int, int, int] | None = None, outline_col=(5, 7, 13)) -> Image.Image:
    im = Image.new("RGBA", (logical_size, logical_size), (0, 0, 0, 0))
    px = im.load()
    cx = (logical_size - 1) * 0.5
    cy = (logical_size - 1) * 0.5
    r = logical_size * radius_ratio
    lx, ly, lz = LIGHT_DIR

    for y in range(logical_size):
        dy = (y - cy) / r
        for x in range(logical_size):
            dx = (x - cx) / r
            d2 = dx * dx + dy * dy
            d = math.sqrt(d2)
            bayer = BAYER_4X4[y & 3][x & 3]
            if d2 <= 1.0:
                nz = math.sqrt(max(0.0, 1.0 - d2))
                nx, ny = dx, dy
                ndotl = nx * lx + ny * ly + nz * lz
                # Terminador desplazado ligeramente hacia delante para mayor volumen esferico
                lit = clamp01(ndotl * 0.92 + 0.16)
                surf_rgb, alpha = shader_fn(nx, ny, nz, lit, x, y, bayer)
                # Halo atmosferico interno en el limbo iluminado
                if atmo_rgb is not None and d > 0.84:
                    rim_t = clamp01((d - 0.84) / 0.16) * clamp01(ndotl * 1.15 + 0.35)
                    if rim_t > bayer * 0.85:
                        surf_rgb = lerp_c(surf_rgb, atmo_rgb, 0.55)
                px[x, y] = (surf_rgb[0], surf_rgb[1], surf_rgb[2], alpha)
            elif d <= 1.0 + (1.3 / r):
                # Contorno oscuro 1px del planeta
                if atmo_rgb is not None and (dx * lx + dy * ly) > 0.15 and bayer < 0.25:
                    px[x, y] = (atmo_rgb[0], atmo_rgb[1], atmo_rgb[2], 180)
                else:
                    px[x, y] = (outline_col[0], outline_col[1], outline_col[2], 255)
            elif atmo_rgb is not None and d <= 1.14:
                # Corona o halo atmosferico cuantizado Bayer 4x4
                side = clamp01((dx * lx + dy * ly) * 0.7 + 0.55)
                falloff = clamp01(1.0 - (d - 1.0) / 0.14) * side
                if falloff > bayer * 0.95:
                    px[x, y] = (atmo_rgb[0], atmo_rgb[1], atmo_rgb[2], 150 if falloff > 0.55 else 85)

    if final_size != logical_size:
        im = im.resize((final_size, final_size), Image.NEAREST)
    return im


def build_planets() -> dict[str, Image.Image]:
    # 1. Sol (160x160 -> 80x80 logico x2): corona solar dithered + granulacion + manchas
    def render_sun() -> Image.Image:
        lsize = 80
        im = Image.new("RGBA", (lsize, lsize), (0, 0, 0, 0))
        px = im.load()
        cx = cy = (lsize - 1) * 0.5
        r = lsize * 0.36
        c_hot = hex_rgb("#fff7ed")
        c_yel = hex_rgb("#fde047")
        c_org = hex_rgb("#f97316")
        c_red = hex_rgb("#dc2626")
        c_spot = hex_rgb("#7c2d12")
        for y in range(lsize):
            dy = (y - cy) / r
            for x in range(lsize):
                dx = (x - cx) / r
                d = math.sqrt(dx * dx + dy * dy)
                bayer = BAYER_4X4[y & 3][x & 3]
                if d <= 1.0:
                    nz = math.sqrt(max(0.0, 1.0 - d * d))
                    gran = fbm3(dx * 4.8 + 1.2, dy * 4.8 - 0.7, nz * 4.8, seed=101, octaves=4)
                    spots = fbm3(dx * 3.1 - 2.0, dy * 3.1 + 1.5, nz * 3.1, seed=202, octaves=3)
                    limb = 0.25 + 0.75 * nz
                    val = gran * 0.6 + limb * 0.48
                    if spots < 0.33 and d < 0.85:
                        col = c_spot if spots < 0.27 else c_red
                    elif val > 0.78 + (bayer - 0.5) * 0.14:
                        col = c_hot
                    elif val > 0.62 + (bayer - 0.5) * 0.16:
                        col = c_yel
                    elif val > 0.44 + (bayer - 0.5) * 0.16:
                        col = c_org
                    else:
                        col = c_red
                    px[x, y] = (*col, 255)
                elif d <= 1.36:
                    ang = math.atan2(dy, dx)
                    flare = fbm2(math.cos(ang) * 3.0 + 4.0, math.sin(ang) * 3.0 - 2.0, seed=303, octaves=3)
                    falloff = clamp01((1.36 - d) / 0.36 + (flare - 0.5) * 0.35)
                    if falloff > bayer * 0.85 + 0.12:
                        col = c_yel if falloff > 0.78 else (c_org if falloff > 0.45 else c_red)
                        px[x, y] = (*col, 255 if falloff > 0.5 else 190)
        return im.resize((160, 160), Image.NEAREST)

    sun = render_sun()
    save_clean(sun, "planets/planet_sun.png")

    # 2. Tierra (128x128 -> 64x64 logico x2)
    def sh_earth(nx, ny, nz, lit, x, y, bayer):
        wx = nx + 0.35 * fbm3(nx * 2.2, ny * 2.2, nz * 2.2, seed=13)
        wy = ny + 0.35 * fbm3(nx * 2.2 + 5.0, ny * 2.2, nz * 2.2, seed=17)
        cont = fbm3(wx * 2.3 + 0.4, wy * 2.3 - 0.2, nz * 2.3, seed=21, octaves=5)
        lat = abs(ny)
        polar = lat + (cont - 0.5) * 0.22 > 0.78
        if polar:
            rgb = hex_rgb("#f8fafc")
        elif cont > 0.525:
            humid = fbm3(nx * 3.8 + 8.0, ny * 3.8, nz * 3.8, seed=29, octaves=3)
            if cont > 0.67:
                rgb = hex_rgb("#65a30d") if humid > 0.52 else hex_rgb("#ca8a04")
            elif humid < 0.42 and lat < 0.45:
                rgb = hex_rgb("#ca8a04")
            else:
                rgb = hex_rgb("#15803d") if cont < 0.60 else hex_rgb("#4d7c0f")
        elif cont > 0.485:
            rgb = hex_rgb("#0284c7")
        elif cont > 0.40:
            rgb = hex_rgb("#1d4ed8")
        else:
            rgb = hex_rgb("#0f294a")

        # Nubes en espiral con sombra desplazada
        swirl = nx * 1.7 + math.sin(ny * 3.2) * 0.35
        clouds = fbm3(swirl * 2.4 - 1.5, ny * 3.2 + 0.8, nz * 2.6, seed=44, octaves=4)
        cloud_shadow = fbm3((swirl - 0.08) * 2.4 - 1.5, (ny - 0.08) * 3.2 + 0.8, nz * 2.6, seed=44, octaves=4)
        if cloud_shadow > 0.59:
            rgb = lerp_c(rgb, (8, 15, 32), 0.35)
        if clouds > 0.595 + (bayer - 0.5) * 0.08:
            rgb = hex_rgb("#f8fafc")
        return shade_with_terminator(rgb, lit, x, y), 255

    earth = render_pixel_planet(64, 128, sh_earth, radius_ratio=0.41, atmo_rgb=hex_rgb("#38bdf8"))
    save_clean(earth, "planets/planet_earth.png")

    # 3. Luna (96x96 -> 48x48 logico x2) con 14 crateres NW/SE
    moon_rng = random.Random(3844)
    moon_craters = []
    for _ in range(14):
        ang = moon_rng.uniform(0.0, math.tau)
        dist = math.sqrt(moon_rng.uniform(0.02, 0.72))
        moon_craters.append((math.cos(ang) * dist, math.sin(ang) * dist, moon_rng.uniform(0.09, 0.22)))

    def sh_moon(nx, ny, nz, lit, x, y, bayer):
        mare = fbm3(nx * 2.1 + 1.3, ny * 2.1 - 0.4, nz * 2.1, seed=55, octaves=4)
        if mare < 0.43:
            rgb = hex_rgb("#334155")
        elif mare < 0.49:
            rgb = hex_rgb("#475569")
        elif mare < 0.62:
            rgb = hex_rgb("#94a3b8")
        else:
            rgb = hex_rgb("#cbd5e1")
        for cx_c, cy_c, cr in moon_craters:
            cdx = nx - cx_c
            cdy = ny - cy_c
            cd = math.sqrt(cdx * cdx + cdy * cdy)
            if cd < cr:
                if abs(cd - cr * 0.85) < 0.045:
                    # Borde iluminado al NW, sombra al SE
                    rgb = hex_rgb("#cbd5e1") if (cdx + cdy) > 0 else hex_rgb("#475569")
                elif cd < cr * 0.78:
                    # Interior hundido: pared NW en sombra, fondo SE iluminado
                    rgb = hex_rgb("#334155") if (cdx + cdy) < -0.02 else lerp_c(rgb, hex_rgb("#64748b"), 0.55)
        return shade_with_terminator(rgb, lit, x, y), 255

    moon = render_pixel_planet(48, 96, sh_moon, radius_ratio=0.42, atmo_rgb=None)
    save_clean(moon, "planets/planet_moon.png")

    # 4. Marte (112x112 -> 56x56 logico x2)
    def sh_mars(nx, ny, nz, lit, x, y, bayer):
        terr = fbm3(nx * 2.6 - 0.9, ny * 2.6 + 0.6, nz * 2.6, seed=71, octaves=4)
        canyon_band = math.exp(-((ny - 0.06 + 0.09 * math.sin(nx * 4.5)) ** 2) / 0.009)
        if abs(ny) + (terr - 0.5) * 0.16 > 0.84:
            rgb = hex_rgb("#f1f5f9")
        elif canyon_band > 0.52 and abs(nx) < 0.68:
            rgb = hex_rgb("#431407")
        elif terr < 0.44:
            rgb = hex_rgb("#9a3412")
        elif terr < 0.56:
            rgb = hex_rgb("#c2410c")
        elif terr < 0.68:
            rgb = hex_rgb("#ea580c")
        else:
            rgb = hex_rgb("#f59e0b")
        return shade_with_terminator(rgb, lit, x, y), 255

    mars = render_pixel_planet(56, 112, sh_mars, radius_ratio=0.41, atmo_rgb=hex_rgb("#f59e0b"))
    save_clean(mars, "planets/planet_mars.png")

    # 5. Jupiter (160x160 -> 80x80 logico x2)
    def sh_jupiter(nx, ny, nz, lit, x, y, bayer):
        turb = fbm3(nx * 3.8 + 1.0, ny * 6.5, nz * 3.8, seed=88, octaves=4)
        band_y = ny + (turb - 0.5) * 0.16 + 0.03 * math.sin(nx * 7.0 + ny * 9.0)
        zonal = 0.5 + 0.5 * math.sin(band_y * 19.0 + turb * 2.5)
        if zonal > 0.80:
            rgb = hex_rgb("#f8fafc")
        elif zonal > 0.60:
            rgb = hex_rgb("#e2cba4")
        elif zonal > 0.42:
            rgb = hex_rgb("#c27838")
        elif zonal > 0.24:
            rgb = hex_rgb("#8c421e")
        else:
            rgb = hex_rgb("#5c2814")
        # Gran Mancha Roja en hemisferio sur-este
        gx = (nx - 0.18) / 0.23
        gy = (ny - 0.24) / 0.13
        gd = math.sqrt(gx * gx + gy * gy)
        if gd < 1.0:
            if gd > 0.72:
                rgb = hex_rgb("#f97316")
            elif gd > 0.35:
                rgb = hex_rgb("#dc2626")
            else:
                rgb = hex_rgb("#fde047")
        return shade_with_terminator(rgb, lit, x, y), 255

    jupiter = render_pixel_planet(80, 160, sh_jupiter, radius_ratio=0.42, atmo_rgb=hex_rgb("#e2cba4"))
    save_clean(jupiter, "planets/planet_jupiter.png")

    # 6. Ganimedes (96x96 -> 48x48 logico x2)
    def sh_ganymede(nx, ny, nz, lit, x, y, bayer):
        base = fbm3(nx * 2.5 + 2.1, ny * 2.5 - 1.4, nz * 2.5, seed=99, octaves=4)
        groove1 = abs(math.sin((nx * 3.4 + ny * 2.1 + base * 1.4) * 5.2))
        groove2 = abs(math.sin((nx * -2.2 + ny * 3.9 + base * 1.1) * 4.8))
        if min(groove1, groove2) < 0.16 and base > 0.45:
            rgb = hex_rgb("#f1f5f9")
        elif min(groove1, groove2) < 0.30 and base > 0.42:
            rgb = hex_rgb("#cbd5e1")
        elif base < 0.46:
            rgb = hex_rgb("#3f3a36")
        else:
            rgb = hex_rgb("#57534e")
        return shade_with_terminator(rgb, lit, x, y), 255

    ganymede = render_pixel_planet(48, 96, sh_ganymede, radius_ratio=0.42, atmo_rgb=None)
    save_clean(ganymede, "planets/planet_ganymede.png")

    # 7-10. Cuatro Asteroides NEO en 64x64 nativo pixel-art
    def render_irregular_body(size: int, shape_fn, palette: list[tuple[int, int, int]], craters: list[tuple[float, float, float]], seed: int, metal_glint: bool = False) -> Image.Image:
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        px = im.load()
        lx, ly, lz = LIGHT_DIR
        mask = [[False] * size for _ in range(size)]
        heights = [[0.0] * size for _ in range(size)]

        for y in range(size):
            for x in range(size):
                val = shape_fn(x, y)
                if val > 0.0:
                    mask[y][x] = True
                    heights[y][x] = val

        for y in range(size):
            for x in range(size):
                if not mask[y][x]:
                    # Contorno oscuro 1 px
                    adj = (
                        (x > 0 and mask[y][x - 1])
                        or (x + 1 < size and mask[y][x + 1])
                        or (y > 0 and mask[y - 1][x])
                        or (y + 1 < size and mask[y + 1][x])
                    )
                    if adj:
                        px[x, y] = (*hex_rgb("#05070d"), 255)
                    continue
                hx = (heights[y][min(size - 1, x + 1)] - heights[y][max(0, x - 1)]) * 2.6
                hy = (heights[min(size - 1, y + 1)][x] - heights[max(0, y - 1)][x]) * 2.6
                nz = clamp01(heights[y][x] * 1.1 + 0.25)
                nn = math.sqrt(hx * hx + hy * hy + nz * nz) or 1.0
                nx, ny, nz = -hx / nn, -hy / nn, nz / nn
                ndotl = clamp01(nx * lx + ny * ly + nz * lz * 0.9 + 0.22)
                rock = fbm2(x * 0.16, y * 0.16, seed=seed, octaves=4)
                val = ndotl * 0.72 + rock * 0.28
                for cx_c, cy_c, cr in craters:
                    cd = math.sqrt((x - cx_c) ** 2 + (y - cy_c) ** 2)
                    if cd < cr:
                        if cd > cr * 0.72:
                            val += 0.14 if (x - cx_c + y - cy_c) > 0 else -0.18
                        else:
                            val -= 0.22
                bayer = BAYER_4X4[y & 3][x & 3]
                idx = int(clamp01(val) * (len(palette) - 1) + (bayer - 0.5) * 0.85)
                idx = max(0, min(len(palette) - 1, idx))
                col = palette[idx]
                if metal_glint and ndotl > 0.76 and rock > 0.66:
                    col = hex_rgb("#f8fafc")
                px[x, y] = (*col, 255)
        return im

    # Bennu (64x64): silueta de trompo/diamante carbonaceo tipo B
    def shape_bennu(x: int, y: int) -> float:
        dx = (x - 31.5) / 23.0
        dy = (y - 31.5) / 23.0
        l1 = abs(dx) * 0.88 + abs(dy) * 0.96
        ang = math.atan2(dy, dx)
        wobble = 0.08 * math.sin(ang * 5.0 + 0.7) + 0.05 * math.cos(ang * 3.0)
        dist = l1 + wobble
        if dist >= 1.0:
            return 0.0
        ridge = 0.14 * math.exp(-((dy * 6.0) ** 2))
        return clamp01(1.0 - dist + ridge)

    bennu = render_irregular_body(
        64,
        shape_bennu,
        [hex_rgb("#080c16"), hex_rgb("#1e293b"), hex_rgb("#334155"), hex_rgb("#475569"), hex_rgb("#64748b")],
        [(23, 24, 5.2), (38, 39, 4.4), (34, 21, 3.2), (24, 38, 3.5)],
        seed=401,
    )
    save_clean(bennu, "planets/asteroid_bennu.png")

    # Eros (64x64): cacahuate S-type alargado y curvado con depresion central Himeros
    def shape_eros(x: int, y: int) -> float:
        tx = (x - 31.5) * 0.88 - (y - 31.5) * 0.45
        ty = (x - 31.5) * 0.45 + (y - 31.5) * 0.88
        ty_curved = ty - 4.0 * math.cos(tx * 0.09)
        waist = 1.0 - 0.34 * math.exp(-((tx / 8.0) ** 2))
        r = math.sqrt((tx / 25.0) ** 2 + (ty_curved / (12.5 * waist)) ** 2)
        bump = 0.07 * math.sin(tx * 0.35 + ty * 0.4)
        if r + bump >= 1.0:
            return 0.0
        himeros = 0.25 * math.exp(-(((tx - 1.0) ** 2 + (ty_curved + 3.0) ** 2) / 28.0))
        return clamp01(1.0 - (r + bump) - himeros)

    eros = render_irregular_body(
        64,
        shape_eros,
        [hex_rgb("#1c1917"), hex_rgb("#57534e"), hex_rgb("#78716c"), hex_rgb("#a8a29e"), hex_rgb("#d6d3d1")],
        [(21, 34, 4.0), (41, 24, 4.5), (31, 28, 6.2)],
        seed=402,
    )
    save_clean(eros, "planets/asteroid_eros.png")

    # Didymos + Dimorphos (64x64): binario DART
    def shape_didymos(x: int, y: int) -> float:
        d1 = math.sqrt(((x - 24.0) / 18.0) ** 2 + ((y - 34.0) / 16.5) ** 2)
        d1 += 0.07 * math.sin(math.atan2(y - 34.0, x - 24.0) * 4.0)
        d2 = math.sqrt(((x - 51.0) / 7.2) ** 2 + ((y - 19.0) / 6.8) ** 2)
        d2 += 0.06 * math.cos(math.atan2(y - 19.0, x - 51.0) * 3.0)
        h1 = max(0.0, 1.0 - d1)
        h2 = max(0.0, 1.0 - d2)
        return max(h1, h2)

    didymos = render_irregular_body(
        64,
        shape_didymos,
        [hex_rgb("#0f172a"), hex_rgb("#334155"), hex_rgb("#64748b"), hex_rgb("#94a3b8"), hex_rgb("#cbd5e1")],
        [(19, 29, 4.5), (29, 39, 3.8), (50, 18, 2.5)],
        seed=403,
    )
    save_clean(didymos, "planets/asteroid_didymos.png")

    # Psyche (64x64): mundo metalico M-type con cuencas de impacto
    def shape_psyche(x: int, y: int) -> float:
        dx = (x - 31.5) / 23.0
        dy = (y - 31.5) / 20.5
        ang = math.atan2(dy, dx)
        d = math.sqrt(dx * dx + dy * dy) + 0.07 * math.sin(ang * 4.0 - 0.5)
        if d >= 1.0:
            return 0.0
        return clamp01(1.0 - d)

    psyche = render_irregular_body(
        64,
        shape_psyche,
        [hex_rgb("#0f172a"), hex_rgb("#334155"), hex_rgb("#64748b"), hex_rgb("#94a3b8"), hex_rgb("#e2e8f0")],
        [(23, 27, 7.5), (39, 36, 6.2), (34, 21, 3.2)],
        seed=404,
        metal_glint=True,
    )
    save_clean(psyche, "planets/asteroid_psyche.png")

    # Atlas de vista previa 640x360
    atlas = Image.new("RGBA", (640, 360), SPACE_BLACK)
    da = ImageDraw.Draw(atlas)
    rng_a = random.Random(2026)
    for _ in range(180):
        sx, sy = rng_a.randint(0, 639), rng_a.randint(0, 359)
        c = (148, 163, 184, 180) if rng_a.random() > 0.25 else (248, 250, 252, 240)
        da.point((sx, sy), fill=c)

    items_top = [
        ("SOL", sun.resize((120, 120), Image.NEAREST), 10, 20),
        ("TIERRA", earth.resize((108, 108), Image.NEAREST), 140, 26),
        ("LUNA", moon, 260, 32),
        ("MARTE", mars, 368, 24),
        ("JUPITER", jupiter.resize((128, 128), Image.NEAREST), 495, 16),
    ]
    items_bot = [
        ("GANIMEDES", ganymede, 28, 216),
        ("BENNU", bennu, 162, 232),
        ("EROS", eros, 282, 232),
        ("DIDYMOS", didymos, 402, 232),
        ("PSYCHE", psyche, 522, 232),
    ]
    for label, spr, x0, y0 in items_top + items_bot:
        atlas.alpha_composite(spr, (x0, y0))
        lx_t = x0 + spr.width // 2 - len(label) * 3
        ly_t = y0 + spr.height + 6
        da.text((lx_t, ly_t), label, fill=CLAMP_WHITE)
    save_clean(atlas, "planets/planets_atlas_preview.png")

    return {
        "sun": sun,
        "earth": earth,
        "moon": moon,
        "mars": mars,
        "jupiter": jupiter,
        "ganymede": ganymede,
        "bennu": bennu,
        "eros": eros,
        "didymos": didymos,
        "psyche": psyche,
    }


# ---------------------------------------------------------------------------
# 1.2 ASSETS DE ESPACIO PROFUNDO (assets/space/)
# ---------------------------------------------------------------------------
def draw_cross_star(d: ImageDraw.ImageDraw, cx: int, cy: int, arm: int, col: tuple[int, int, int], core=(255, 255, 255)) -> None:
    for r in range(1, arm + 1):
        alpha = int(255 * (1.0 - r / (arm + 1.2)))
        c = (*col, alpha)
        d.rectangle([cx - r * 2, cy, cx - r * 2 + 1, cy + 1], fill=c)
        d.rectangle([cx + r * 2, cy, cx + r * 2 + 1, cy + 1], fill=c)
        d.rectangle([cx, cy - r * 2, cx + 1, cy - r * 2 + 1], fill=c)
        d.rectangle([cx, cy + r * 2, cx + 1, cy + r * 2 + 1], fill=c)
    if arm >= 3:
        d.rectangle([cx - 2, cy - 2, cx + 3, cy + 3], fill=(*col, 220))
    d.rectangle([cx - 1, cy - 1, cx + 2, cy + 2], fill=(*core, 255))


def render_space_bg(filename: str, stops: list[tuple[int, int, int]], seed: int, diag_bias: bool, num_pins: int, num_cross: int, cross_tint: tuple[int, int, int], streak_mode: bool = False) -> None:
    ls = 256
    im = Image.new("RGBA", (ls, ls), SPACE_BLACK)
    px = im.load()
    n_stops = len(stops) - 1

    for y in range(ls):
        ny = y / float(ls)
        for x in range(ls):
            nx = x / float(ls)
            wx = nx * 2.6 + 0.55 * fbm2(nx * 2.1, ny * 2.1, seed=seed + 3, octaves=3)
            wy = ny * 2.6 + 0.55 * fbm2(nx * 2.1 + 7.0, ny * 2.1 - 3.0, seed=seed + 9, octaves=3)
            dens = fbm2(wx, wy, seed=seed, octaves=4)
            if diag_bias:
                band = clamp01(1.0 - abs((nx * 0.9 - ny * 0.85) + (dens - 0.5) * 0.55) * 1.45)
                dens = clamp01(dens * 0.65 + band * 0.52 - 0.14)
            else:
                dens = clamp01((dens - 0.25) * 1.38)
            dust = fbm2(nx * 5.2 + 11.0, ny * 5.2 - 4.0, seed=seed + 97, octaves=3)
            if dust < 0.36:
                dens *= 0.45
            bayer = BAYER_4X4[y & 3][x & 3]
            idx = int(dens * n_stops + (bayer - 0.5) * 0.95)
            idx = max(0, min(n_stops, idx))
            col = stops[idx]
            px[x, y] = (col[0], col[1], col[2], 255)

    out = im.resize((512, 512), Image.NEAREST)
    d = ImageDraw.Draw(out)
    rng = random.Random(seed * 991)

    for _ in range(num_pins):
        sx = rng.randrange(0, 512, 2)
        sy = rng.randrange(0, 512, 2)
        bright = rng.random()
        if bright > 0.88:
            d.rectangle([sx, sy, sx + 3, sy + 3], fill=(248, 250, 252, 230))
        elif bright > 0.5:
            d.rectangle([sx, sy, sx + 1, sy + 1], fill=(226, 232, 240, 210))
        else:
            d.rectangle([sx, sy, sx + 1, sy + 1], fill=(*cross_tint, 175))

    for _ in range(num_cross):
        cx = rng.randrange(24, 488, 2)
        cy = rng.randrange(24, 488, 2)
        arm = rng.choice((3, 4, 5, 7))
        draw_cross_star(d, cx, cy, arm, cross_tint)

    if streak_mode:
        for _ in range(36):
            sx = rng.randrange(0, 480, 2)
            sy = rng.randrange(20, 490, 2)
            ln = rng.randint(12, 34)
            d.line([(sx, sy), (sx + ln, sy - ln // 3)], fill=hex_rgb("#fde047") + (180,), width=2)
            d.line([(sx + ln // 2, sy - ln // 6), (sx + ln, sy - ln // 3)], fill=(255, 247, 237, 235), width=2)

    save_clean(out, f"space/{filename}")


def build_space_assets() -> None:
    render_space_bg(
        "space_bg_deep_void.png",
        [hex_rgb("#05070d"), hex_rgb("#0a1122"), hex_rgb("#112240"), hex_rgb("#1e3a5f")],
        seed=501,
        diag_bias=False,
        num_pins=240,
        num_cross=18,
        cross_tint=hex_rgb("#93c5fd"),
    )
    render_space_bg(
        "space_bg_nebula_crimson.png",
        [hex_rgb("#09040e"), hex_rgb("#19071c"), hex_rgb("#3b0a37"), hex_rgb("#701a5c"), hex_rgb("#be185d"), hex_rgb("#f43f5e"), hex_rgb("#fda4af")],
        seed=502,
        diag_bias=True,
        num_pins=220,
        num_cross=22,
        cross_tint=hex_rgb("#fda4af"),
    )
    render_space_bg(
        "space_bg_nebula_teal.png",
        [hex_rgb("#040914"), hex_rgb("#061826"), hex_rgb("#0c3547"), hex_rgb("#0e6ba8"), hex_rgb("#38bdf8"), hex_rgb("#a5f3fc")],
        seed=503,
        diag_bias=True,
        num_pins=230,
        num_cross=20,
        cross_tint=hex_rgb("#7dd3fc"),
    )
    render_space_bg(
        "space_bg_solar_storm.png",
        [hex_rgb("#0c0605"), hex_rgb("#1c0d06"), hex_rgb("#451a03"), hex_rgb("#9a3412"), hex_rgb("#d97706"), hex_rgb("#fde047")],
        seed=504,
        diag_bias=False,
        num_pins=170,
        num_cross=14,
        cross_tint=hex_rgb("#fde047"),
        streak_mode=True,
    )

    # Hoja de sprites celestes 256x64 estilo pin_15.jpg
    sheet = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sheet)

    # 4 estrellas en cruz de tamanos crecientes en celulas 32x32 (y=0..31)
    for i, arm in enumerate((3, 5, 7, 9)):
        cx = 16 + i * 32
        cy = 16
        draw_cross_star(ds, cx, cy, max(2, arm // 2), hex_rgb("#bae6fd"))

    # Mini-planeta anillado (x=128..191, y=0..63)
    def sh_mini_ring(nx, ny, nz, lit, x, y, bayer):
        band = 0.5 + 0.5 * math.sin(ny * 8.0)
        rgb = hex_rgb("#93c5fd") if band > 0.5 else hex_rgb("#64748b")
        return shade_with_terminator(rgb, lit, x, y), 255

    mini_p = render_pixel_planet(26, 26, sh_mini_ring, radius_ratio=0.42)
    sheet.alpha_composite(mini_p, (147, 19))
    # Anillo inclinado pixel-art alrededor del mini-planeta
    for deg in range(-30, 210, 6):
        rad = math.radians(deg)
        rx = int(round(160 + math.cos(rad) * 20))
        ry = int(round(32 + math.sin(rad) * 6 - math.cos(rad) * 5))
        if 128 <= rx < 192 and 0 <= ry < 64:
            ds.rectangle([rx, ry, rx + 1, ry + 1], fill=CYAN_BRIGHT if deg % 12 == 0 else CLAMP_WHITE)

    # Luna azulada + esfera celeste (x=192..255)
    def sh_orb_b(nx, ny, nz, lit, x, y, bayer):
        return shade_with_terminator(hex_rgb("#cbd5e1"), lit, x, y), 255

    def sh_orb_c(nx, ny, nz, lit, x, y, bayer):
        c_n = fbm3(nx * 2.5, ny * 2.5, nz * 2.5, seed=808)
        rgb = hex_rgb("#7dd3fc") if c_n > 0.5 else hex_rgb("#38bdf8")
        return shade_with_terminator(rgb, lit, x, y), 255

    sheet.alpha_composite(render_pixel_planet(24, 24, sh_orb_b, radius_ratio=0.42), (200, 4))
    sheet.alpha_composite(render_pixel_planet(24, 24, sh_orb_c, radius_ratio=0.42), (228, 4))

    # 3 cometas pixel-art con cola dithered en y=34..61, x=0..127
    for idx in range(3):
        hx = 20 + idx * 42
        hy = 52
        for k in range(18):
            tx = hx + k
            ty = hy - int(k * 0.7)
            for off in (-2, -1, 0, 1, 2):
                if abs(off) == 2 and (tx + ty + off) % 2 == 0:
                    continue
                if 0 <= tx < 256 and 32 <= ty + off < 64 and k < 15:
                    col = CYAN_BRIGHT if k < 6 else (CYAN if k < 11 else CLAMP_SHADE)
                    sheet.putpixel((tx, ty + off), col)
        ds.ellipse([hx - 4, hy - 4, hx + 4, hy + 4], fill=CYAN_BRIGHT, outline=OUTLINE)
        ds.ellipse([hx - 2, hy - 2, hx + 2, hy + 2], fill=CLAMP_HI)

    save_clean(sheet, "space/stars_celestial_sheet.png")


# ---------------------------------------------------------------------------
# Utilidades de render cenital pixel-art (sin extrusion 3/4, sin barras UI)
# ---------------------------------------------------------------------------
def apply_pixel_outline(im: Image.Image, outline=OUTLINE) -> Image.Image:
    """Agrega contorno pixel-art uniforme 4-vecinos de 1 px a toda silueta opaca."""
    w, h = im.size
    src = im.load()
    out = im.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] >= 200:
                continue
            hit = False
            for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + ox, y + oy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] >= 200:
                    hit = True
                    break
            if hit:
                dst[x, y] = outline
    return out


def cyl_tone(pal: dict, t_across: float, t_along: float = 0.0, seam: bool = False) -> tuple[int, int, int, int]:
    """
    Sombreado cilindrico puro en vista cenital con luz key a 315° (izquierda-arriba).
    t_across in [-1, 1] desde borde babor a borde estribor; t_along in [0, 1] proa->popa.
    """
    if seam:
        return (*pal["deep"], 255)
    # Brillo maximo desplazado hacia -0.22 (arriba-izquierda a 315°)
    curve = 1.0 - abs(t_across + 0.22) * 0.92 - t_along * 0.14
    if t_across < -0.78 or t_across > 0.72:
        col = pal["deep"]
    elif curve > 0.86:
        col = pal["spec"]
    elif curve > 0.64:
        col = pal["hi"]
    elif curve > 0.34:
        col = pal["mid"]
    else:
        col = pal["lo"]
    return (*col, 255)


def paint_cylinder_x(im: Image.Image, x0: int, x1: int, y0: int, y1: int, pal: dict, seams_y: tuple[int, ...] = ()) -> None:
    px = im.load()
    w, h = im.size
    span = max(1.0, (x1 - x0) * 0.5)
    mid_x = (x0 + x1) * 0.5
    yspan = max(1, y1 - y0)
    for y in range(max(0, y0), min(h, y1 + 1)):
        seam = y in seams_y
        ty = (y - y0) / yspan
        for x in range(max(0, x0), min(w, x1 + 1)):
            tx = (x - mid_x) / span
            px[x, y] = cyl_tone(pal, tx, ty, seam=seam)


def draw_pin22_clamp(d: ImageDraw.ImageDraw, x0: int, x1: int, y_mid: int, buckle_x: int) -> None:
    """Abrazadera blanca doble con hebilla cuadrada oscura estilo pin_22.jpg."""
    d.rectangle([x0, y_mid - 3, x1, y_mid - 2], fill=CLAMP_WHITE)
    d.rectangle([x0, y_mid - 1, x1, y_mid - 1], fill=STEEL_DARK)
    d.rectangle([x0, y_mid + 1, x1, y_mid + 2], fill=CLAMP_WHITE)
    d.rectangle([x0, y_mid + 3, x1, y_mid + 3], fill=STEEL_DARK)
    # Hebilla central negra con interior plateado
    d.rectangle([buckle_x - 3, y_mid - 4, buckle_x + 3, y_mid + 4], fill=OUTLINE)
    d.rectangle([buckle_x - 2, y_mid - 2, buckle_x + 2, y_mid + 2], fill=CLAMP_WHITE)


# ---------------------------------------------------------------------------
# 1.3 CASCO CENITAL ESCULPIDO (pin_22.jpg), INTERIOR 6 SALAS Y TECHO (assets/ship/)
# ---------------------------------------------------------------------------
def _hull_geometry_mask() -> list[tuple[int, int, int, str]]:
    """Define la silueta exacta del Orbital Mule Mk-I cenital estilo pin_22 (160x224)."""
    return []


def render_sculpted_hull(lvl: int) -> Image.Image:
    pal = TIERS[lvl]
    im = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
    px = im.load()
    d = ImageDraw.Draw(im)
    cx = 79.5

    # 1. Cuatro gondolas de motor en la popa (ref. pin_22)
    # Exteriores auxiliares (cx ± 50)
    for sign in (-1, 1):
        mc = cx + sign * 50.0
        paint_cylinder_x(im, int(mc - 9), int(mc + 9), 152, 198, pal, seams_y=(168, 188, 193))
        d.rectangle([int(mc - 8), 192, int(mc + 8), 198], fill=STEEL_DARK, outline=OUTLINE)
        d.rectangle([int(mc - 5), 194, int(mc + 5), 197], fill=(*pal["glow"], 255))
    # Principales centrales (cx ± 17)
    for sign in (-1, 1):
        mc = cx + sign * 17.5
        paint_cylinder_x(im, int(mc - 10), int(mc + 10), 160, 208, pal, seams_y=(176, 196, 201))
        d.rectangle([int(mc - 8), 201, int(mc + 8), 208], fill=STEEL_DARK, outline=OUTLINE)
        d.rectangle([int(mc - 5), 204, int(mc + 5), 207], fill=(*pal["glow"], 255))

    # 2. Dos canones/tomas cilindricas verticales sobre los hombros laterales (pin_22)
    for sign in (-1, 1):
        tc = cx + sign * 42.0
        paint_cylinder_x(im, int(tc - 7), int(tc + 7), 44, 76, pal, seams_y=(50, 62))
        d.rectangle([int(tc - 5), 44, int(tc + 5), 47], fill=(*pal["trim"], 255))

    # 3. Sponsons laterales curvos con perfil ovoidal cenital (y=66..166)
    for y in range(66, 167):
        t = (y - 66) / 100.0
        # Curva organica mas ancha en el centro (x=10..54 y x=105..149)
        bulge = math.sin(t * math.pi) ** 0.58
        outer_off = 28.0 + bulge * 41.5
        inner_off = 22.0
        span = outer_off - inner_off
        for sign in (-1, 1):
            xs = int(round(cx + sign * inner_off))
            xe = int(round(cx + sign * outer_off))
            x_lo, x_hi = min(xs, xe), max(xs, xe)
            for x in range(x_lo, x_hi + 1):
                u = (abs(x - cx) - inner_off) / max(1.0, span)
                # Sombreado ovoidal: lado izquierdo iluminado a 315°, derecho mas profundo
                across = -u if sign < 0 else u
                seam = y in (82, 102, 148) or (abs(x - cx) > outer_off - 1.5)
                px[x, y] = cyl_tone(pal, across * 0.85, t * 0.7, seam=seam)

    # Placas y Kapton MLI por tier dentro de los sponsons
    if lvl >= 3:
        for sx0 in (24, 122):
            d.rectangle([sx0, 86, sx0 + 13, 100], fill=(*pal["trim"], 255), outline=OUTLINE)
            if lvl >= 4:
                d.rectangle([sx0 + 2, 88, sx0 + 7, 94], fill=(*pal["trim_hi"], 255))
    if lvl >= 4:
        for sx0 in (32, 118):
            d.rectangle([sx0, 134, sx0 + 9, 146], fill=KAPTON, outline=OUTLINE)
            d.rectangle([sx0 + 2, 136, sx0 + 5, 140], fill=KAPTON_HI)

    # Doble abrazadera blanca horizontal + hebilla cuadrada negra en ambos sponsons (pin_22)
    draw_pin22_clamp(d, 11, 52, 118, 32)
    draw_pin22_clamp(d, 107, 148, 118, 127)

    # 4. Nucleo central / espina dorsal cilindrica y mamparos (x=50..109, y=54..188)
    for y in range(54, 189):
        t = (y - 54) / 134.0
        half_w = 29.0 if y < 164 else 29.0 - (y - 164) * 0.35
        x0 = int(round(cx - half_w))
        x1 = int(round(cx + half_w))
        paint_cylinder_x(im, x0, x1, y, y, pal, seams_y=(74, 96, 136, 158, 174))

    # Canal dorsal de potencia / puente de avionica en la espina central
    d.rectangle([73, 62, 86, 182], fill=(*pal["deep"], 255))
    paint_cylinder_x(im, 75, 84, 63, 181, pal, seams_y=(78, 96, 136, 160))
    if lvl >= 3:
        d.line([(79, 64), (79, 180)], fill=CYAN if lvl >= 4 else (*pal["trim"], 255), width=2)

    # 5. Mandibulas frontales bifurcadas y foso central de sensores (y=12..66)
    for y in range(12, 67):
        t = (y - 12) / 54.0
        # Dos brazos que se ensanchan atras y enmarcan el foso central en x=70..89
        outer_x = 12.0 + t * 18.0 if y < 44 else 24.0 + (y - 44) * 0.32
        inner_x = 6.0 if y < 26 else (10.5 if y < 60 else 8.0 * (1.0 - (y - 60) / 7.0))
        for sign in (-1, 1):
            a = int(round(cx + sign * inner_x))
            b = int(round(cx + sign * outer_x))
            x_lo, x_hi = min(a, b), max(a, b)
            mid_prong = (x_lo + x_hi) * 0.5
            hw_p = max(1.0, (x_hi - x_lo) * 0.5)
            for x in range(x_lo, x_hi + 1):
                across = (x - mid_prong) / hw_p
                seam = y in (26, 44, 58)
                px[x, y] = cyl_tone(pal, across, t * 0.4, seam=seam)

    # Foso central oscuro de proa + travesano blanco/cian (pin_22)
    d.rectangle([70, 26, 89, 59], fill=(10, 14, 24, 255), outline=OUTLINE)
    d.ellipse([72, 30, 87, 45], fill=(16, 24, 42, 255), outline=OUTLINE)
    d.rectangle([68, 36, 91, 39], fill=CYAN_BRIGHT if lvl >= 4 else CLAMP_WHITE, outline=OUTLINE)

    # 6. Anillo central de torreta dorsal en (80, 114)
    d.ellipse([66, 100, 94, 128], fill=(*pal["deep"], 255), outline=OUTLINE)
    d.ellipse([69, 103, 91, 125], fill=(*pal["hi"], 255), outline=OUTLINE)
    d.ellipse([73, 107, 87, 121], fill=STEEL_DARK, outline=OUTLINE)
    d.rectangle([77, 111, 82, 117], fill=(*pal["trim"], 255))

    # Detalles unicos por tier para diferenciacion clara en Hangar LVL 1..5
    if lvl == 1:
        # Parche de soldadura oxidado en babor + junta remachada
        d.rectangle([55, 80, 66, 90], fill=TERRA, outline=OUTLINE)
        d.rectangle([88, 142, 101, 152], fill=AMBER, outline=OUTLINE)
    elif lvl == 2:
        d.rectangle([54, 138, 67, 148], fill=(*pal["trim"], 255), outline=OUTLINE)
        d.rectangle([92, 78, 105, 88], fill=(*pal["trim"], 255), outline=OUTLINE)
    elif lvl >= 4:
        # Aletas estabilizadoras dorsales en estribor/babor para LVL 4-5
        for sx in (52, 99):
            d.rectangle([sx, 68, sx + 8, 92], fill=KAPTON, outline=OUTLINE)
            d.rectangle([sx + 2, 71, sx + 4, 88], fill=KAPTON_HI)
    if lvl == 5:
        d.polygon([(49, 130), (34, 150), (49, 156)], fill=CLAMP_WHITE, outline=OUTLINE)
        d.polygon([(110, 130), (125, 150), (110, 156)], fill=CLAMP_WHITE, outline=OUTLINE)
        d.rectangle([75, 42, 84, 52], fill=CYAN_BRIGHT, outline=OUTLINE)

    return apply_pixel_outline(im)


def render_roof_cutaway(hull_ref: Image.Image) -> Image.Image:
    """Techo cenital superior derivado de la misma silueta del casco (cero salto visual)."""
    pal = TIERS[3]
    im = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = 79.5
    # Caparazon superior sobre el bloque central de las 6 salas (x=22..137, y=58..178)
    for y in range(58, 172):
        t = (y - 58) / 114.0
        half = 54.0 if y < 142 else 54.0 - (y - 142) * 0.65
        paint_cylinder_x(im, int(cx - half), int(cx + half), y, y, pal, seams_y=(88, 122, 152))
    # Puente frontal acristalado visto desde arriba
    d.polygon([(66, 44), (93, 44), (102, 72), (57, 72)], fill=(*pal["hi"], 255), outline=OUTLINE)
    d.rectangle([68, 52, 91, 61], fill=CYAN_BRIGHT, outline=OUTLINE)
    d.rectangle([71, 54, 79, 57], fill=CLAMP_HI)
    # Bandas de sujecion blancas y anillo de torreta abierto
    draw_pin22_clamp(d, 26, 62, 118, 44)
    draw_pin22_clamp(d, 97, 133, 118, 115)
    d.ellipse([66, 100, 94, 128], fill=(16, 22, 36, 255), outline=OUTLINE)
    d.ellipse([70, 104, 90, 124], fill=CYAN_DEEP, outline=OUTLINE)
    return apply_pixel_outline(im)


def render_interior_floor_6rooms() -> Image.Image:
    """Corte interior 100% CENITAL de las 6 salas FTL dentro de 160x224 (sin muros 3/4)."""
    im = Image.new("RGBA", (160, 224), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # Fondo exterior estructural oscuro dentro del contorno de salas
    d.rectangle([48, 22, 111, 68], fill=(15, 20, 32, 255), outline=OUTLINE)
    d.rectangle([16, 66, 143, 168], fill=(15, 20, 32, 255), outline=OUTLINE)
    d.rectangle([48, 164, 111, 202], fill=(15, 20, 32, 255), outline=OUTLINE)

    # 6 salas exactas en vista 100% ortogonal cenital (grosor de muro uniforme = 3 px)
    rooms = {
        "sensors": (52, 26, 78, 66),
        "helm": (80, 26, 108, 66),
        "life_support": (20, 70, 56, 158),
        "reactor": (58, 70, 101, 158),
        "science_bay": (103, 70, 139, 158),
        "engines": (52, 162, 107, 198),
    }

    floor_a = (28, 38, 56, 255)
    floor_b = (34, 46, 66, 255)
    grid_line = (46, 61, 86, 255)
    wall_top = (100, 116, 139, 255)

    for idx, (rid, (x0, y0, x1, y1)) in enumerate(rooms.items()):
        fcol = floor_a if idx % 2 == 0 else floor_b
        d.rectangle([x0, y0, x1, y1], fill=fcol)
        # Rejilla metalica cenital 8x8 px
        for gx in range(x0 + 8, x1, 8):
            d.line([(gx, y0), (gx, y1)], fill=grid_line, width=1)
        for gy in range(y0 + 8, y1, 8):
            d.line([(x0, gy), (x1, gy)], fill=grid_line, width=1)
        # Mamparo perimetral visto desde arriba (arista clara uniforme + contorno)
        d.rectangle([x0, y0, x1, y1], outline=wall_top, width=2)
        d.rectangle([x0 - 1, y0 - 1, x1 + 1, y1 + 1], outline=OUTLINE, width=1)

    # Compuertas neumaticas corredizas entre salas (cenitales)
    doors = [
        (77, 40, 81, 52),   # sensors <-> helm
        (60, 65, 72, 71),   # sensors <-> reactor
        (88, 65, 100, 71),  # helm <-> reactor
        (54, 108, 60, 122), # life_support <-> reactor
        (99, 108, 105, 122),# reactor <-> science_bay
        (72, 157, 87, 163), # reactor <-> engines
    ]
    for dx0, dy0, dx1, dy1 in doors:
        d.rectangle([dx0, dy0, dx1, dy1], fill=CYAN, outline=OUTLINE)
        d.line([(dx0 + 2, (dy0 + dy1) // 2), (dx1 - 2, (dy0 + dy1) // 2)], fill=CYAN_BRIGHT, width=1)

    # Esclusas al vacio (Norte-Oeste life_support y Sur engines)
    d.rectangle([18, 92, 22, 114], fill=AMBER, outline=OUTLINE)
    d.rectangle([70, 196, 89, 200], fill=AMBER, outline=OUTLINE)

    # Mobiliario 100% CENITAL detallado dentro de cada sala:
    # 1) SENSORS: mesa circular holo-radar vista desde arriba
    d.ellipse([57, 37, 73, 53], fill=STEEL_DARK, outline=OUTLINE)
    d.ellipse([60, 40, 70, 50], fill=CYAN_DEEP, outline=CYAN)
    d.line([(65, 45), (69, 41)], fill=CYAN_BRIGHT, width=1)

    # 2) HELM: consola frontal curva y 2 asientos de piloto vistos desde arriba
    d.rectangle([84, 30, 104, 38], fill=(51, 65, 85, 255), outline=OUTLINE)
    d.rectangle([86, 32, 94, 36], fill=CYAN)
    d.rectangle([96, 32, 102, 36], fill=AMBER)
    for sx in (87, 97):
        d.rectangle([sx, 43, sx + 5, 49], fill=(71, 85, 105, 255), outline=OUTLINE)
        d.rectangle([sx + 1, 47, sx + 4, 49], fill=CLAMP_WHITE)

    # 3) REACTOR: nucleo cilindrico central tokamak con 4 conductos radiales
    for lx0, ly0, lx1, ly1 in ((79, 76, 80, 152), (62, 113, 97, 114)):
        d.line([(lx0, ly0), (lx1, ly1)], fill=CYAN, width=2)
    d.rectangle([68, 101, 91, 126], fill=STEEL_DARK, outline=OUTLINE)
    d.ellipse([69, 102, 90, 125], fill=AMBER, outline=OUTLINE)
    d.ellipse([74, 107, 85, 118], fill=KAPTON_HI)

    # 4) LIFE SUPPORT: 2 tanques circulares O2/NH3 con volantes de valvula + consola
    for cy_t in (92, 118):
        d.ellipse([28, cy_t, 48, cy_t + 20], fill=CYAN_DEEP, outline=OUTLINE)
        d.ellipse([32, cy_t + 4, 44, cy_t + 16], fill=CYAN, outline=OUTLINE)
        d.line([(34, cy_t + 10), (42, cy_t + 10)], fill=CLAMP_WHITE, width=2)
        d.line([(38, cy_t + 6), (38, cy_t + 14)], fill=CLAMP_WHITE, width=2)
    d.rectangle([26, 142, 48, 151], fill=(51, 65, 85, 255), outline=OUTLINE)
    d.rectangle([29, 144, 38, 149], fill=OK_GREEN)

    # 5) SCIENCE BAY: mesa de muestreo + brazo analizador cenital
    d.rectangle([110, 88, 132, 120], fill=(51, 65, 85, 255), outline=OUTLINE)
    d.rectangle([114, 92, 128, 106], fill=CYAN)
    d.rectangle([115, 109, 127, 116], fill=OK_GREEN)
    d.line([(121, 122), (127, 138)], fill=KAPTON, width=3)
    d.ellipse([117, 119, 125, 127], fill=CLAMP_WHITE, outline=OUTLINE)

    # 6) ENGINES: 2 turbobombas cilindricas paralelas conectadas al colector
    for ex in (62, 87):
        d.rectangle([ex, 169, ex + 11, 190], fill=(71, 85, 105, 255), outline=OUTLINE)
        d.ellipse([ex + 2, 173, ex + 9, 180], fill=AMBER, outline=OUTLINE)
        d.rectangle([ex + 2, 183, ex + 9, 188], fill=CYAN_DEEP)

    return im


# ---------------------------------------------------------------------------
# MODULOS CENITALES LVL 1..5 (assets/modules/ - CERO barras UI)
# ---------------------------------------------------------------------------
def build_modules() -> None:
    for lvl in range(1, 6):
        pal = TIERS[lvl]

        # BOW_SHIELD (96x48): escudo frontal curvo cenital de losetas HRSI / PICA-X
        im = Image.new("RGBA", (96, 48), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        cx_s = 47.5
        span_w = 34 + lvl * 2
        for y in range(6, 40):
            t = (y - 6) / 34.0
            hw = span_w * math.sin(min(math.pi * 0.52, t * 1.6 + 0.18))
            inner = max(0.0, hw - (11 + lvl))
            for x in range(int(cx_s - hw), int(cx_s + hw) + 1):
                if y > 22 and abs(x - cx_s) < inner:
                    continue
                tile_seam = (x % 7 == 0) or (y % 6 == 0)
                across = (x - cx_s) / max(1.0, hw)
                im.putpixel((x, y), cyl_tone(pal, across * 0.8, t * 0.5, seam=tile_seam))
        # Borde frontal ablativo o losetas ceramicas en proa + collar Kapton trasero
        arc_box = [int(cx_s - span_w), 6, int(cx_s + span_w), 48]
        d.arc(arc_box, 190, 350, fill=KAPTON if lvl >= 4 else (*pal["trim"], 255), width=2)
        im = apply_pixel_outline(im)
        save_clean(im, f"modules/bow_shield_lvl{lvl}.png")

        # BOW_RADAR (64x48): domo circular Doppler cenital sin pips
        im = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        paint_cylinder_x(im, 14, 50, 26, 42, pal, seams_y=(32,))
        r_dom = 12 + lvl
        cx_r, cy_r = 32, 22
        d.ellipse([cx_r - r_dom, cy_r - r_dom, cx_r + r_dom, cy_r + r_dom], fill=(*pal["mid"], 255), outline=OUTLINE)
        d.arc([cx_r - r_dom + 2, cy_r - r_dom + 2, cx_r + r_dom - 2, cy_r + r_dom - 2], 180, 315, fill=(*pal["spec"], 255), width=2)
        for ring in range(2, 2 + lvl):
            rr = max(3, r_dom - ring * 2)
            d.ellipse([cx_r - rr, cy_r - rr, cx_r + rr, cy_r + rr], outline=CYAN if ring == 2 else (*pal["deep"], 255))
        d.ellipse([cx_r - 3, cy_r - 3, cx_r + 3, cy_r + 3], fill=CYAN_BRIGHT, outline=OUTLINE)
        im = apply_pixel_outline(im)
        save_clean(im, f"modules/bow_radar_lvl{lvl}.png")

        # BOW_LES (64x64): torre de escape vista 100% DESDE ARRIBA (ojiva + 4 toberas radiales)
        im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        # Collar de acoplamiento inferior octogonal/circular
        d.ellipse([14, 14, 50, 50], fill=(*pal["lo"], 255), outline=OUTLINE)
        d.ellipse([17, 17, 47, 47], fill=(*pal["mid"], 255), outline=OUTLINE)
        # 4 toberas de aborto orientadas a N/S/E/W en vista cenital
        arm_len = 13 + lvl * 2
        for nx_d, ny_d in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            x0, y0 = 32 + nx_d * 8, 32 + ny_d * 8
            x1, y1 = 32 + nx_d * arm_len, 32 + ny_d * arm_len
            d.line([(x0, y0), (x1, y1)], fill=OUTLINE, width=7)
            d.line([(x0, y0), (x1, y1)], fill=(*pal["trim"], 255), width=5)
            d.ellipse([x1 - 3, y1 - 3, x1 + 3, y1 + 3], fill=STEEL_DARK, outline=OUTLINE)
            d.point((x1, y1), fill=AMBER if lvl < 4 else KAPTON_HI)
        # Ojiva superior vista desde arriba (sombrea segun 315°)
        d.ellipse([23, 23, 41, 41], fill=(*pal["trim"], 255), outline=OUTLINE)
        d.arc([24, 24, 40, 40], 170, 310, fill=(*pal["trim_hi"], 255), width=2)
        d.ellipse([28, 28, 36, 36], fill=CLAMP_WHITE if lvl >= 3 else (*pal["hi"], 255), outline=OUTLINE)
        im = apply_pixel_outline(im)
        save_clean(im, f"modules/bow_les_lvl{lvl}.png")

        # NACELLES (40x96): tank / rtg / armor en vista cenital cilindrica (sin barras UI)
        for kind in ("tank", "rtg", "armor"):
            im = Image.new("RGBA", (40, 96), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            if kind == "tank":
                # Domos polares norte/sur y tanque criogenico cilindrico
                d.ellipse([11, 6, 29, 22], fill=(*pal["hi"], 255), outline=OUTLINE)
                d.ellipse([11, 74, 29, 90], fill=(*pal["lo"], 255), outline=OUTLINE)
                paint_cylinder_x(im, 9, 31, 12, 84, pal, seams_y=(26, 48, 70))
                if lvl >= 3:
                    d.rectangle([13, 18, 27, 25], fill=KAPTON if lvl >= 4 else (*pal["trim"], 255), outline=OUTLINE)
                    d.rectangle([13, 71, 27, 78], fill=KAPTON if lvl >= 4 else (*pal["trim"], 255), outline=OUTLINE)
                # Tuberia lateral + doble abrazadera blanca con hebilla negra (pin_22)
                d.line([(19, 14), (19, 82)], fill=CYAN if lvl >= 4 else (*pal["deep"], 255), width=2)
                draw_pin22_clamp(d, 7, 33, 36, 20)
                draw_pin22_clamp(d, 7, 33, 60, 20)
            elif kind == "rtg":
                # Cuerpo cilindrico blindado + 6..10 aletas radiadoras simetricas
                n_fins = 5 + lvl
                for fy in range(16, 80, max(6, 64 // n_fins)):
                    fin_c = (*pal["trim"], 255) if lvl >= 3 else (*pal["hi"], 255)
                    d.rectangle([3, fy, 37, fy + 3], fill=fin_c, outline=OUTLINE)
                paint_cylinder_x(im, 12, 28, 10, 86, pal, seams_y=(28, 68))
                d.ellipse([15, 40, 25, 56], fill=STEEL_DARK, outline=OUTLINE)
                d.ellipse([17, 43, 23, 53], fill=CYAN_BRIGHT if lvl >= 4 else AMBER)
                draw_pin22_clamp(d, 9, 31, 22, 20)
                draw_pin22_clamp(d, 9, 31, 74, 20)
            else:
                # Sponson de blindaje Whipple escalonado con placas anguladas cenitales
                for y in range(10, 86):
                    taper = 0 if 18 <= y <= 78 else (18 - y if y < 18 else y - 78) // 2
                    paint_cylinder_x(im, 7 + taper, 33 - taper, y, y, pal, seams_y=(28, 48, 68))
                for ry in range(18, 80, 12):
                    d.point((10, ry), fill=CLAMP_WHITE)
                    d.point((29, ry), fill=(*pal["deep"], 255))
                if lvl >= 4:
                    d.rectangle([14, 34, 26, 62], fill=KAPTON, outline=OUTLINE)
                    d.rectangle([16, 36, 20, 58], fill=KAPTON_HI)
                draw_pin22_clamp(d, 6, 34, 32, 20)
                draw_pin22_clamp(d, 6, 34, 64, 20)
            im = apply_pixel_outline(im)
            save_clean(im, f"modules/nacelle_{kind}_lvl{lvl}.png")

        # WINGS (64x36): solar / radiator con bisagra UNICA en borde derecho (x=52..63)
        for kind in ("solar", "radiator"):
            im = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            # Anclaje mecanico interior (x=52..62)
            paint_cylinder_x(im, 52, 62, 10, 26, pal, seams_y=(18,))
            d.rectangle([54, 14, 60, 22], fill=KAPTON if lvl >= 4 else (*pal["trim"], 255), outline=OUTLINE)
            if kind == "solar":
                w_left = max(2, 16 - lvl * 3)
                d.rectangle([w_left, 5, 52, 31], fill=STEEL_DARK, outline=OUTLINE)
                # Larguero estructural central
                d.rectangle([w_left, 16, 52, 20], fill=KAPTON if lvl >= 4 else (*pal["hi"], 255), outline=OUTLINE)
                # Celdas fotovoltaicas azul profundo con busbars
                cell_bg = (14, 48, 86, 255) if lvl < 4 else (12, 74, 110, 255)
                d.rectangle([w_left + 2, 7, 50, 15], fill=cell_bg, outline=OUTLINE)
                d.rectangle([w_left + 2, 21, 50, 29], fill=cell_bg, outline=OUTLINE)
                for cx_v in range(w_left + 6, 50, 7):
                    d.line([(cx_v, 7), (cx_v, 15)], fill=CYAN, width=1)
                    d.line([(cx_v, 21), (cx_v, 29)], fill=CYAN, width=1)
            else:
                w_left = max(3, 18 - lvl * 3)
                d.rectangle([w_left, 6, 52, 30], fill=(*pal["hi"], 255), outline=OUTLINE)
                # Colector longitudinal y serpentines NH3 cenitales
                d.rectangle([w_left + 1, 16, 51, 20], fill=CYAN if lvl >= 4 else (*pal["trim"], 255), outline=OUTLINE)
                for rx in range(w_left + 4, 50, 5):
                    d.line([(rx, 8), (rx, 15)], fill=(*pal["lo"], 255), width=2)
                    d.line([(rx, 21), (rx, 28)], fill=(*pal["lo"], 255), width=2)
            im = apply_pixel_outline(im)
            save_clean(im, f"modules/wing_{kind}_lvl{lvl}.png")

        # DORSAL (48x48): dsn / cmg / arm en vista cenital
        for kind in ("dsn", "cmg", "arm"):
            im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            if kind == "dsn":
                r_dish = 12 + lvl * 2
                d.ellipse([24 - r_dish, 24 - r_dish, 24 + r_dish, 24 + r_dish], fill=(*pal["hi"], 255), outline=OUTLINE)
                d.arc([24 - r_dish + 2, 24 - r_dish + 2, 24 + r_dish - 2, 24 + r_dish - 2], 150, 310, fill=(*pal["spec"], 255), width=2)
                d.ellipse([24 - r_dish + 5, 24 - r_dish + 5, 24 + r_dish - 5, 24 + r_dish - 5], fill=(*pal["mid"], 255), outline=(*pal["deep"], 255))
                # 3 brazos tripode cenitales convergentes
                for ang_deg in (30, 150, 270):
                    rad = math.radians(ang_deg)
                    ex = int(24 + math.cos(rad) * (r_dish - 2))
                    ey = int(24 + math.sin(rad) * (r_dish - 2))
                    d.line([(24, 24), (ex, ey)], fill=OUTLINE, width=3)
                    d.line([(24, 24), (ex, ey)], fill=CLAMP_WHITE if lvl >= 3 else (*pal["trim"], 255), width=1)
                d.ellipse([20, 20, 28, 28], fill=KAPTON if lvl >= 4 else (*pal["trim"], 255), outline=OUTLINE)
                d.ellipse([22, 22, 26, 26], fill=CYAN_BRIGHT)
            elif kind == "cmg":
                d.ellipse([9, 9, 39, 39], fill=(*pal["lo"], 255), outline=OUTLINE)
                d.ellipse([13, 13, 35, 35], fill=STEEL_DARK, outline=OUTLINE)
                # Dos rotores inerciales ortogonales vistos desde arriba
                d.rectangle([14, 21, 34, 27], fill=(*pal["hi"], 255), outline=OUTLINE)
                d.rectangle([21, 14, 27, 34], fill=KAPTON if lvl >= 4 else (*pal["trim"], 255), outline=OUTLINE)
                d.ellipse([20, 20, 28, 28], fill=CYAN_BRIGHT if lvl >= 4 else CLAMP_WHITE, outline=OUTLINE)
            else:
                # Torreta de brazo robotico y pinza doble plegada
                d.ellipse([14, 16, 34, 36], fill=(*pal["mid"], 255), outline=OUTLINE)
                d.line([(24, 26), (34, 15)], fill=OUTLINE, width=6)
                d.line([(24, 26), (34, 15)], fill=CLAMP_WHITE, width=4)
                d.line([(34, 15), (28, 6)], fill=OUTLINE, width=5)
                d.line([(34, 15), (28, 6)], fill=KAPTON if lvl >= 4 else (*pal["trim"], 255), width=3)
                # Pinza doble abierta en la punta
                d.line([(28, 6), (22, 4)], fill=CYAN, width=2)
                d.line([(28, 6), (33, 3)], fill=CYAN, width=2)
            im = apply_pixel_outline(im)
            save_clean(im, f"modules/dorsal_{kind}_lvl{lvl}.png")

        # AFT ENGINES (48x56): hypergolic / cryo / ion cenitales sin barras UI
        for kind in ("hypergolic", "cryo", "ion"):
            im = Image.new("RGBA", (48, 56), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            # Colector / turbobomba superior
            paint_cylinder_x(im, 11, 37, 4, 20, pal, seams_y=(10, 16))
            if kind == "hypergolic":
                # Dos toberas gemelas cilindricas vista cenital
                for cx_n in (17, 31):
                    paint_cylinder_x(im, cx_n - 6, cx_n + 6, 18, 44, pal, seams_y=(26, 36))
                    d.rectangle([cx_n - 5, 42, cx_n + 5, 47], fill=AMBER, outline=OUTLINE)
            elif kind == "cryo":
                # Gran tobera criogenica regenerativa con refuerzos circunferenciales
                for y in range(18, 49):
                    t = (y - 18) / 30.0
                    hw = 7.0 + t * 8.0
                    paint_cylinder_x(im, int(24 - hw), int(24 + hw), y, y, pal, seams_y=(24, 30, 36, 42))
                for sy in (24, 32, 40):
                    col_r = KAPTON if lvl >= 4 else (*pal["trim"], 255)
                    d.line([(24 - 11, sy), (24 + 11, sy)], fill=col_r, width=2)
                d.rectangle([12, 46, 36, 51], fill=STEEL_DARK, outline=OUTLINE)
                d.rectangle([15, 48, 33, 50], fill=CYAN_BRIGHT if lvl >= 4 else AMBER)
            else:
                # Anillo acelerador de iones cenital
                paint_cylinder_x(im, 9, 39, 18, 44, pal, seams_y=(28, 38))
                d.ellipse([10, 22, 38, 46], fill=STEEL_DARK, outline=OUTLINE)
                d.ellipse([13, 25, 35, 43], fill=CYAN_DEEP, outline=CYAN)
                d.ellipse([17, 29, 31, 39], fill=CYAN_BRIGHT)
            im = apply_pixel_outline(im)
            save_clean(im, f"modules/aft_{kind}_lvl{lvl}.png")


# ---------------------------------------------------------------------------
# COMPOSITES COMPLETOS DE PREVIEW CENITAL (assets/ship/ship_complete_lvl*.png)
# ---------------------------------------------------------------------------
def build_ship_composites(hull_imgs: dict[int, Image.Image], floor_img: Image.Image) -> None:
    crew_imgs: dict[str, Image.Image] = {}
    crew_defs = {
        "pilot": ((240, 156, 20, 255), CYAN_BRIGHT),
        "radar": ((56, 189, 248, 255), CLAMP_HI),
        "engineer": ((249, 115, 22, 255), KAPTON_HI),
        "mission": ((34, 197, 94, 255), CLAMP_HI),
    }

    # Chasis robotico 32x32 visto 100% DESDE ARRIBA (cenital)
    for role, (suit, visor) in crew_defs.items():
        cr = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        dc = ImageDraw.Draw(cr)
        # Dos brazos/pinzas articuladas hacia adelante (Norte, y=3..11)
        for sx in (6, 21):
            dc.rectangle([sx, 4, sx + 4, 13], fill=CLAMP_SHADE, outline=OUTLINE)
            dc.rectangle([sx + 1, 2, sx + 3, 6], fill=CYAN if role == "radar" else suit)
        # Hombreras blindadas izquierda y derecha
        dc.rectangle([4, 10, 10, 22], fill=suit, outline=OUTLINE)
        dc.rectangle([21, 10, 27, 22], fill=suit, outline=OUTLINE)
        # Torso central y mochila de bateria trasera (Sur, y=22..28)
        dc.rectangle([9, 10, 22, 23], fill=CLAMP_WHITE, outline=OUTLINE)
        dc.rectangle([10, 23, 21, 28], fill=(51, 65, 85, 255), outline=OUTLINE)
        dc.rectangle([12, 24, 19, 27], fill=suit)
        # Domo craneal cenital con visor orientado al Norte (arriba)
        dc.ellipse([10, 9, 21, 20], fill=CLAMP_HI, outline=OUTLINE)
        dc.rectangle([12, 10, 19, 13], fill=visor, outline=OUTLINE)
        cr = apply_pixel_outline(cr)
        save_clean(cr, f"crew/crew_{role}.png")
        crew_imgs[role] = cr

    # FX (fire_sheet, breach_icon, thruster_shock_sheet, debris_meteor)
    fire = Image.new("RGBA", (96, 24), (0, 0, 0, 0))
    df = ImageDraw.Draw(fire)
    for f in range(4):
        ox = f * 24
        dy = (f % 2) * 2
        sway = -1 if f in (1, 2) else 1
        df.polygon([(ox + 12 + sway, 2 + dy), (ox + 20, 19), (ox + 4, 19)], fill=TERRA, outline=OUTLINE)
        df.polygon([(ox + 12, 6 + dy), (ox + 17, 19), (ox + 7, 19)], fill=AMBER)
        df.ellipse([ox + 9, 12, ox + 15, 19], fill=KAPTON_HI)
    save_clean(fire, "fx/fire_sheet.png")

    breach = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    db = ImageDraw.Draw(breach)
    db.polygon([(3, 12), (10, 3), (19, 6), (21, 15), (12, 21), (4, 17)], fill=OUTLINE, outline=TERRA)
    db.line([(6, 6), (18, 18)], fill=CYAN, width=2)
    db.line([(18, 6), (6, 18)], fill=CYAN, width=2)
    db.ellipse([9, 9, 15, 15], fill=ORBIT_NIGHT, outline=CYAN_BRIGHT)
    save_clean(breach, "fx/breach_icon.png")

    shock = Image.new("RGBA", (144, 48), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shock)
    for f in range(4):
        ox = f * 36
        cx_s = ox + 18
        len_p = 20 + (f % 2) * 6
        ds.polygon([(cx_s - 8, 2), (cx_s + 8, 2), (cx_s, 2 + len_p + 8)], fill=AMBER)
        ds.polygon([(cx_s - 4, 2), (cx_s + 4, 2), (cx_s, 2 + len_p)], fill=KAPTON_HI)
        arc_y = 14 + f * 6
        ds.arc([cx_s - 13, arc_y, cx_s + 13, arc_y + 10], 10, 170, fill=CYAN_BRIGHT, width=2)
    save_clean(shock, "fx/thruster_shock_sheet.png")

    meteor = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    dm = ImageDraw.Draw(meteor)
    for step in range(4):
        dm.line([(12, 18), (18 + step * 3, 12 - step * 2)], fill=CYAN if step < 2 else (100, 116, 139, 180), width=2)
    dm.polygon([(6, 18), (11, 13), (18, 15), (17, 23), (9, 25)], fill=(100, 116, 139, 255), outline=OUTLINE)
    dm.polygon([(8, 18), (12, 15), (15, 17), (12, 21)], fill=(203, 213, 225, 255))
    save_clean(meteor, "fx/debris_meteor.png")

    # Composites 256x256 de la nave completa armada en LVL 1..5 + Cutaway Preview
    f0 = shock.crop((0, 0, 36, 48))
    for lvl in range(1, 6):
        comp = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        hull = hull_imgs[lvl]
        bow_sh = Image.open(ROOT / f"modules/bow_shield_lvl{lvl}.png")
        nac = Image.open(ROOT / f"modules/nacelle_tank_lvl{lvl}.png")
        wing_p = Image.open(ROOT / f"modules/wing_solar_lvl{lvl}.png")
        wing_s = wing_p.transpose(Image.FLIP_LEFT_RIGHT)
        aft = Image.open(ROOT / f"modules/aft_cryo_lvl{lvl}.png")
        dsn = Image.open(ROOT / f"modules/dorsal_dsn_lvl{lvl}.png")

        comp.alpha_composite(f0, (128 - 17 - 18, 206))
        comp.alpha_composite(f0, (128 + 17 - 18, 206))
        comp.alpha_composite(wing_p, (128 - 122, 110))
        comp.alpha_composite(wing_s, (128 + 122 - 64, 110))
        comp.alpha_composite(hull, (128 - 80, 16))
        comp.alpha_composite(nac, (128 - 68, 82))
        comp.alpha_composite(nac.transpose(Image.FLIP_LEFT_RIGHT), (128 + 68 - 40, 82))
        comp.alpha_composite(aft, (128 - 24, 184))
        comp.alpha_composite(bow_sh, (128 - 48, 8))
        comp.alpha_composite(dsn, (128 - 24, 102))
        save_clean(comp, f"ship/ship_complete_lvl{lvl}.png")

    cut = Image.new("RGBA", (256, 256), SPACE_BLACK)
    cut.alpha_composite(hull_imgs[3], (128 - 80, 16))
    cut.alpha_composite(floor_img, (128 - 80, 16))
    cut.alpha_composite(crew_imgs["pilot"], (128 + 1, 52))
    cut.alpha_composite(crew_imgs["radar"], (128 - 26, 52))
    cut.alpha_composite(crew_imgs["engineer"], (128 - 42, 104))
    cut.alpha_composite(crew_imgs["mission"], (128 + 20, 112))
    save_clean(cut, "ship/ship_cutaway_preview.png")


if __name__ == "__main__":
    ensure_dirs()
    build_planets()
    build_space_assets()

    hull_imgs: dict[int, Image.Image] = {}
    for lvl in range(1, 6):
        h_img = render_sculpted_hull(lvl)
        save_clean(h_img, f"ship/hull_base_lvl{lvl}.png")
        hull_imgs[lvl] = h_img

    floor_img = render_interior_floor_6rooms()
    save_clean(floor_img, "ship/interior_floor_6rooms.png")
    save_clean(render_roof_cutaway(hull_imgs[3]), "ship/roof_cutaway.png")

    build_modules()
    build_ship_composites(hull_imgs, floor_img)
    print("Generated zenithal assets, planets, and space backgrounds in:", ROOT)
