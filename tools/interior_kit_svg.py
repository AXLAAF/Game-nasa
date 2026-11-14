#!/usr/bin/env python3
"""Kit interior de Contratista Orbital en estilo comic entintado (tinta gruesa, cel shading, chatarra).

Escribe un SVG por pieza en assets/interior/ (para Godot) y la lamina docs/art/interior_kit.svg
(para editar en VectorCraft). Mismos nombres y tamanos que la version CRT (interior_kit_crt_svg.py).
Sin clipPath ni texto dentro de las piezas: las sombras y tramas se recortan aqui, con geometria.
Uso: python3 tools/interior_kit_svg.py
"""
import math
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "interior"
SHEET = ROOT / "docs" / "art" / "interior_kit.svg"
FONT = "Ubuntu, DejaVu Sans, sans-serif"

INK, BONE, RUST, MUSTARD, TEAL, STEEL, STEEL_D = "#1A1410", "#EFE3C8", "#C8552B", "#E8B23A", "#3F9C96", "#6F7A80", "#3D4347"
BONE_D, RUST_D, MUSTARD_D, TEAL_D, LIME, LIME_D = "#C9B88F", "#8A3719", "#B07F1E", "#256661", "#8FB04A", "#5F7A2B"
SHADE = {BONE: BONE_D, RUST: RUST_D, MUSTARD: MUSTARD_D, TEAL: TEAL_D, STEEL: STEEL_D, LIME: LIME_D, STEEL_D: "#24282B"}

_ui = (ROOT / "game" / "ui" / "ui.gd").read_text(encoding="utf-8")
RARITY = ["#" + "".join(f"{round(float(v) * 255):02x}" for v in m.split(",")[:3])
          for m in re.findall(r"Color\(([^)]*)\)", re.search(r"const RARITY:.*", _ui).group(0))]
PURPLE = RARITY[1]
SHADE[PURPLE] = "#7B45AD"


# --- geometria -------------------------------------------------------------------------------
def wob(pts, rnd, amp=1.3):
    return [(x + rnd.uniform(-amp, amp), y + rnd.uniform(-amp, amp)) for x, y in pts]


def clip_half(poly, a, b, c):
    """Parte del poligono convexo donde a*x + b*y + c >= 0."""
    out = []
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        dp, dq = a * p[0] + b * p[1] + c, a * q[0] + b * q[1] + c
        if dp >= 0:
            out.append(p)
        if (dp >= 0) != (dq >= 0):
            t = dp / (dp - dq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def clip_seg(p, q, poly):
    """Recorta el segmento p-q a un poligono convexo. Devuelve (p', q') o None."""
    if len(poly) < 3:
        return None
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    o = 1 if area > 0 else -1
    d = (q[0] - p[0], q[1] - p[1])
    t0, t1 = 0.0, 1.0
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        e = (b[0] - a[0], b[1] - a[1])
        num = o * (e[0] * (p[1] - a[1]) - e[1] * (p[0] - a[0]))
        den = o * (e[0] * d[1] - e[1] * d[0])
        if abs(den) < 1e-9:
            if num < 0:
                return None
            continue
        t = -num / den
        if den > 0:
            t0 = max(t0, t)
        else:
            t1 = min(t1, t)
    if t0 >= t1:
        return None
    return (p[0] + d[0] * t0, p[1] + d[1] * t0), (p[0] + d[0] * t1, p[1] + d[1] * t1)


# --- primitivas SVG --------------------------------------------------------------------------
def P(pts, fill="none", stroke=None, sw=2, close=True, op=None):
    if len(pts) < 2:
        return ""
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + (" Z" if close else "")
    s = f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"' if stroke else ""
    o = f' opacity="{op}"' if op is not None else ""
    return f'<path d="{d}" fill="{fill}"{s}{o}/>'


def Ln(a, b, stroke=INK, sw=2, op=None):
    return P([a, b], "none", stroke, sw, False, op)


def C(x, y, r, fill="none", stroke=INK, sw=2):
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{fill}"{s}/>'


def D(d, fill="none", stroke=INK, sw=2):
    s = f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}"{s}/>'


def rectpts(x, y, w, h):
    return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]


def cel(pts, base, rnd, sw=5, amp=1.3, hatch=True, side=0.66, foot=0.84):
    """Relleno plano + sombra abajo-derecha con trama. Devuelve (relleno, contorno)."""
    p = wob(pts, rnd, amp)
    xs, ys = [a for a, _ in p], [b for _, b in p]
    x0, y0, w, h = min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)
    shade = SHADE.get(base, STEEL_D)
    right = clip_half(p, 1, 0, -(x0 + side * w))
    out = P(p, base) + P(right, shade) + P(clip_half(p, 0, 1, -(y0 + foot * h)), shade)
    if hatch and w * (1 - side) > 8:
        k = x0 + side * w - h
        while k < x0 + w + h:
            seg = clip_seg((k + h, y0), (k, y0 + h), right)
            if seg:
                out += Ln(*seg, INK, 1.2, 0.5)
            k += 7
    hi = clip_seg((x0, y0 + sw + 4), (x0 + w * 0.42, y0 + sw + 4), p)
    if hi and base != BONE and hi[1][0] - hi[0][0] > 16:
        out += Ln((hi[0][0] + sw + 3, hi[0][1]), (hi[1][0], hi[1][1]), BONE, 2.5, 0.55)
    return out, P(p, "none", INK, sw)


def box(x, y, w, h, base, rnd, sw=3, **kw):
    f, o = cel(rectpts(x, y, w, h), base, rnd, sw, 0.8, **kw)
    return f + o


def rivets(points, r=2.2):
    return "".join(C(x, y, r, BONE_D, INK, 1.2) for x, y in points)


def scratch(x, y, rnd, n=3, ln=14):
    return "".join(Ln((x + i * 5, y + rnd.uniform(-2, 2)), (x + i * 5 + ln * 0.5, y - ln + rnd.uniform(-3, 3)), INK, 1.1, 0.55) for i in range(n))


def patch(x, y, w, h, rnd, col=STEEL):
    return box(x, y, w, h, col, rnd, 2.5, hatch=False) + rivets([(x + 5, y + 5), (x + w - 5, y + 5), (x + 5, y + h - 5), (x + w - 5, y + h - 5)], 1.6)


def stain(x, y, rnd, col=RUST_D):
    pts = [(x + math.cos(a) * rnd.uniform(5, 11), y + math.sin(a) * rnd.uniform(4, 8)) for a in [i * math.tau / 7 for i in range(7)]]
    return P(pts, col, None, 0, True, 0.55)


def burst(col, rnd, cx=32, cy=32, r1=30, r2=22, n=11):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n + rnd.uniform(-0.07, 0.07)
        r = (r1 if i % 2 == 0 else r2) + rnd.uniform(-2.5, 1.0)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    shade = [(x + 3, y + 3) for x, y in pts]
    return P(shade, INK) + P(pts, col, INK, 3)


ASSET = {}


def rng(name):
    return random.Random(name)


# --- Salas -----------------------------------------------------------------------------------
r = rng("cabina"); w, h = 160, 144
f, o = cel([(10, h - 4), (w - 10, h - 4), (w * 0.69, 4), (w * 0.31, 4)][::-1], BONE, r)
ASSET["sala_cabina"] = (w, h, f + P([(46, 30), (114, 30), (118, 44), (42, 44)], RUST, INK, 2)            # franja de la naviera
    + C(80, 70, 17, TEAL, INK, 4) + D("M70,64 A12,12 0 0 1 82,58", "none", BONE, 3)                       # ventanilla
    + box(60, 98, 40, 34, RUST, r) + box(66, 86, 28, 14, RUST, r, hatch=False)                            # asiento
    + box(22, 112, 26, 18, TEAL, r, 2.5, hatch=False) + box(112, 112, 26, 18, MUSTARD, r, 2.5, hatch=False)
    + rivets([(30, 100), (130, 100), (52, 20), (108, 20)]) + scratch(118, 84, r) + o)

r = rng("tanque"); w, h = 160, 320
f, o = cel(rectpts(4, 4, w - 8, h - 8), STEEL, r)
ASSET["sala_tanque"] = (w, h, f
    + D("M28,58 Q28,22 64,22 H96 Q132,22 132,58 V262 Q132,298 96,298 H64 Q28,298 28,262 Z", BONE, INK, 4)  # deposito
    + D("M30,160 H130 V262 Q130,296 96,296 H64 Q30,296 30,262 Z", RUST, None)                              # combustible
    + D("M108,160 H130 V262 Q130,296 96,296 H108 Z", RUST_D, None)
    + D("M30,160 Q48,152 64,160 T98,160 T130,160", "none", INK, 2.5)
    + "".join(Ln((112 + i * 6, 290 - i * 6), (128, 274 - i * 12), INK, 1.1, 0.5) for i in range(3))
    + D("M28,58 Q28,22 64,22 H96 Q132,22 132,58 V262 Q132,298 96,298 H64 Q28,298 28,262 Z", "none", INK, 4)
    + D("M40,60 Q40,34 62,32", "none", "#FFFFFF", 4)
    + "".join(Ln((138, y), (148, y), INK, 2) for y in range(46, 290, 24))
    + box(8, 150, 14, 26, MUSTARD, r, 2.5, hatch=False) + patch(96, 96, 30, 24, r) + stain(52, 250, r) + scratch(44, 120, r)
    + rivets([(14, 14), (146, 14), (14, 306), (146, 306)]) + o)

r = rng("motor"); w, h = 200, 176
f1, o1 = cel(rectpts(42, 4, 116, 68), STEEL, r)
f2, o2 = cel([(42, 70), (158, 70), (195, 172), (5, 172)], STEEL_D, r, side=0.7)
ASSET["sala_motor"] = (w, h, f2 + "".join(Ln((60 + i * 20 - (3 - i) * 7, 166), (72 + i * 14, 78), INK, 1.6, 0.6) for i in range(5))
    + P([(14, 150), (186, 150), (190, 162), (10, 162)], RUST, INK, 2.5) + o2 + f1
    + C(100, 38, 18, RUST, INK, 4) + C(100, 38, 6, INK, None) + "".join(Ln((100 + 9 * math.cos(a), 38 + 9 * math.sin(a)), (100 + 16 * math.cos(a), 38 + 16 * math.sin(a)), INK, 2.5) for a in [i * math.tau / 6 for i in range(6)])
    + D("M58,24 H74 M58,34 H70", "none", INK, 2.5) + box(128, 20, 20, 30, MUSTARD, r, 2.5, hatch=False)
    + rivets([(50, 12), (150, 12), (50, 62), (150, 62)]) + scratch(132, 124, r, 4, 18) + o1)

r = rng("avionica"); w, h = 128, 40
f, o = cel(rectpts(4, 4, w - 8, h - 8), STEEL_D, r, 4, side=0.8)
ASSET["sala_avionica"] = (w, h, f + "".join(box(11 + k * 19, 10, 14, 20, BONE, r, 2, hatch=False) + C(18 + k * 19, 17, 2.6, [TEAL, MUSTARD, TEAL, RUST][k], INK, 1) for k in range(4))
    + D("M90,26 L96,14 L102,24 L108,12 L116,22", "none", MUSTARD, 2.5) + o)

r = rng("anillo"); w, h = 160, 32
f, o = cel(rectpts(4, 4, w - 8, h - 8), MUSTARD, r, 4, hatch=False, side=2, foot=2)
ASSET["sala_anillo"] = (w, h, f + "".join(P([(12 + k * 18, 27), (21 + k * 18, 5), (30 + k * 18, 5), (21 + k * 18, 27)], INK) for k in range(8)) + o)

r = rng("escudo"); w, h = 192, 48
f, o = cel([(5, 5), (187, 5), (176, 32), (96, 44), (16, 32)], RUST, r, side=0.72, foot=0.7)
ASSET["sala_escudo"] = (w, h, f + "".join(Ln((22 + k * 20, 10), (27 + k * 20, 24 + (4 if 2 < k < 6 else 0)), INK, 1.6, 0.6) for k in range(8)) + stain(60, 22, r, INK) + o)

r = rng("modulo"); w, h = 64, 96
f, o = cel(rectpts(4, 4, w - 8, h - 8), STEEL, r, 4)
ASSET["sala_modulo"] = (w, h, f + C(30, 34, 13, TEAL, INK, 3.5) + D("M23,30 A8,8 0 0 1 31,25", "none", BONE, 2.5)
    + box(14, 62, 30, 14, MUSTARD, r, 2.5, hatch=False) + rivets([(12, 12), (52, 12), (12, 84), (52, 84)], 1.8) + o)

# --- Escotillas ------------------------------------------------------------------------------
r = rng("esc")
ASSET["escotilla_cerrada"] = (48, 16, box(3, 3, 42, 10, MUSTARD, r, 3, hatch=False) + Ln((24, 3), (24, 13), INK, 2.5) + rivets([(11, 8), (37, 8)], 1.6))
ASSET["escotilla_abierta"] = (48, 16, box(3, 3, 11, 10, TEAL, r, 3, hatch=False) + box(34, 3, 11, 10, TEAL, r, 3, hatch=False) + Ln((18, 8), (30, 8), INK, 1.5, 0.4))
ASSET["escotilla_sellada"] = (48, 16, box(3, 3, 42, 10, RUST, r, 3, hatch=False) + Ln((10, 4), (38, 12), INK, 3) + Ln((38, 4), (10, 12), INK, 3))

# --- Drones ----------------------------------------------------------------------------------
for name, col in (("dron_tecnico", TEAL), ("dron_alerta", MUSTARD), ("dron_caido", STEEL)):
    r = rng(name)
    hexp = [(32 + 19 * math.cos(math.pi / 6 + k * math.pi / 3), 31 + 19 * math.sin(math.pi / 6 + k * math.pi / 3)) for k in range(6)]
    f, o = cel(hexp, col, r, 4, 1.0, side=0.62, foot=0.78)
    eye = C(32, 30, 3.2, BONE, None) if name != "dron_caido" else Ln((28, 27), (36, 33), BONE, 2) + Ln((36, 27), (28, 33), BONE, 2)
    ASSET[name] = (64, 64, Ln((19, 46), (10, 59), INK, 4) + Ln((45, 46), (54, 59), INK, 4) + Ln((6, 59), (15, 59), INK, 4) + Ln((49, 59), (58, 59), INK, 4)
        + Ln((32, 12), (32, 5), INK, 3) + C(32, 5, 3, RUST if name == "dron_alerta" else BONE, INK, 2) + f
        + D("M20,25 H44 Q47,30 44,35 H20 Q17,30 20,25 Z", INK, INK, 1) + eye + rivets([(24, 42), (40, 42)], 1.5) + o)


# --- Averias: estallido + glifo en tinta -----------------------------------------------------
def nozzle(tilt=0):
    return f'<g transform="rotate({tilt} 32 32)">' + P(rectpts(25, 13, 14, 10), BONE, INK, 3) + P([(27, 23), (17, 46), (47, 46), (37, 23)], BONE, INK, 3) + "</g>"


G = {
    "apagon_motor": (RUST, nozzle() + Ln((22, 49), (42, 59), INK, 4) + Ln((42, 49), (22, 59), INK, 4)),
    "motor_desbalanceado": (MUSTARD, nozzle(-16) + D("M48,20 Q56,30 50,42 M14,20 Q8,32 14,44", "none", INK, 3)),
    "cortocircuito": (MUSTARD, P([(37, 8), (19, 35), (30, 35), (25, 57), (46, 27), (35, 27)], BONE, INK, 3)),
    "desacople_trabado": (MUSTARD, P(rectpts(11, 15, 42, 9), BONE, INK, 3) + P(rectpts(11, 41, 42, 9), BONE, INK, 3) + D("M27,27 V20 H37 V27", "none", INK, 3) + P(rectpts(24, 26, 16, 14), INK, INK, 2)),
    "error_navegacion": (PURPLE, C(32, 32, 19, BONE, INK, 3) + P([(32, 15), (38, 32), (32, 49), (26, 32)], RUST, INK, 2.5) + C(32, 32, 2.5, INK, None)),
    "falla_misteriosa": (PURPLE, D("M24,25 Q24,14 32,14 Q41,14 41,23 Q41,29 32,33 V40", "none", INK, 5.5) + C(32, 49, 3.6, INK, None)
        + D("M24,25 Q24,14 32,14 Q41,14 41,23 Q41,29 32,33 V40", "none", BONE, 2)),
    "fuga_cabina": (RUST, C(25, 34, 15, BONE, INK, 3) + C(25, 34, 5, INK, None) + D("M40,25 L56,16 M43,34 H59 M40,43 L56,52", "none", INK, 3.5)),
    "fuga_combustible": (RUST, D("M32,8 Q48,32 46,40 Q44,54 32,54 Q20,54 18,40 Q16,32 32,8 Z", BONE, INK, 3) + D("M22,40 Q32,58 42,40 Z", INK, None) + C(52, 52, 3.4, INK, None) + C(12, 54, 2.4, INK, None)),
    "sobrepresion": (RUST, D("M11,44 A21,21 0 0 1 53,44 Z", BONE, INK, 3) + Ln((32, 44), (48, 28), INK, 4) + C(32, 44, 4, INK, None) + D("M44,10 V18 M53,14 L49,21", "none", INK, 3)),
    "grieta_escudo": (MUSTARD, P([(9, 19), (55, 19), (49, 38), (32, 49), (15, 38)], BONE, INK, 3) + D("M29,19 L36,28 L27,34 L34,48", "none", INK, 3.5)),
    "panel_danado": (TEAL, P(rectpts(14, 11, 36, 42), BONE, INK, 3) + D("M32,11 V53 M14,25 H50 M14,39 H50", "none", INK, 1.8) + D("M19,13 L30,30 L23,36 L41,51", "none", RUST, 4) + D("M19,13 L30,30 L23,36 L41,51", "none", INK, 1.5)),
    "paracaidas_enredado": (MUSTARD, D("M11,28 A21,15 0 0 1 53,28 Z", BONE, INK, 3) + D("M11,28 L39,40 L25,46 L32,56 M53,28 L25,40 L39,46 L32,56", "none", INK, 2.2)),
    "pata_atascada": (STEEL, Ln((21, 11), (40, 46), INK, 6) + Ln((21, 11), (40, 46), BONE, 2.5) + Ln((31, 47), (50, 47), INK, 6) + P(rectpts(12, 22, 22, 13), RUST, INK, 2.5) + Ln((17, 28), (29, 28), INK, 2.5)),
}
for k, (col, g) in G.items():
    ASSET["averia_" + k] = (64, 64, burst(col, rng(k)) + f'<g transform="translate(32 32) scale(0.72) translate(-32 -32)">{g}</g>')


# --- Interfaz: pegatinas con sombra de bloque ------------------------------------------------
def sticker(w, h, col, r, off=5, sw=4, pressed=False):
    pts = wob(rectpts(3, 3, w - 6 - off, h - 6 - off), r, 1.0)
    if pressed:
        pts = [(x + off - 1, y + off - 1) for x, y in pts]
        return P(pts, col, INK, sw)
    return P([(x + off, y + off) for x, y in pts], INK, INK, 2) + P(pts, col, INK, sw)


r = rng("ui")
ASSET["ui_panel"] = (320, 200, sticker(320, 200, BONE, r, 7, 5) + P([(6, 6), (310, 6), (310, 30), (6, 30)], INK) + rivets([(16, 18), (300, 18)], 2.4)
    + "".join(Ln((262 + i * 9, 186), (300, 148 + i * 9), INK, 1.2, 0.35) for i in range(4)))
ASSET["ui_boton"] = (200, 44, sticker(200, 44, MUSTARD, r))
ASSET["ui_boton_hover"] = (200, 44, sticker(200, 44, BONE, r))
ASSET["ui_boton_pulsado"] = (200, 44, sticker(200, 44, RUST, r, pressed=True))
ASSET["ui_barra_fondo"] = (240, 22, P(wob(rectpts(3, 3, 234, 16), r, 0.8), "#3A322B", INK, 4))
for name, col in (("cian", TEAL), ("naranja", MUSTARD), ("verde", LIME), ("roja", RUST)):
    ASSET[f"ui_barra_{name}"] = (240, 22, P(rectpts(5, 5, 230, 12), col) + P(rectpts(5, 12, 230, 5), SHADE[col]) + Ln((9, 8), (120, 8), BONE, 1.6, 0.6))
    ASSET[f"ui_pip_{name}"] = (18, 18, P(wob(rectpts(3, 3, 12, 12), r, 0.6), col, INK, 2.5) + Ln((6, 6), (10, 6), BONE, 1.4, 0.7))
ASSET["ui_pip_vacio"] = (18, 18, P(wob(rectpts(3, 3, 12, 12), r, 0.6), "#3A322B", INK, 2.5))
ASSET["ui_alerta"] = (360, 48, sticker(360, 48, RUST, r, 5, 4) + "".join(P([(10 + k * 34, 38), (26 + k * 34, 6), (40 + k * 34, 6), (24 + k * 34, 38)], INK, None, 0, True, 0.85) for k in range(10)))
corners = ([(4, 20), (4, 4), (20, 4)], [(52, 4), (68, 4), (68, 20)], [(68, 52), (68, 68), (52, 68)], [(20, 68), (4, 68), (4, 52)])
ASSET["ui_seleccion"] = (72, 72, "".join(P(c, "none", INK, 8, False) for c in corners) + "".join(P(c, "none", MUSTARD, 4, False) for c in corners))

# --- Escritura -------------------------------------------------------------------------------
ASSETS.mkdir(parents=True, exist_ok=True)
for name, (w, h, body) in ASSET.items():
    (ASSETS / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n', encoding="utf-8")


def T(x, y, s, size=14, fill=INK, anchor="middle", weight="bold"):
    return f'<text x="{x:.1f}" y="{y:.1f}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{s}</text>'


W, H = 2400, 1500
r = rng("lamina")
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">', P(rectpts(0, 0, W, H), "#E4D5B3"),
       P(wob([(40, 34), (1010, 30), (1022, 128), (36, 134)], r, 3), INK), T(64, 104, "Kit de chatarra", 64, MUSTARD, "start"),
       T(560, 100, "Contratista Orbital, por dentro", 28, BONE, "start", "normal")]


def place(name, x, y, label=True):
    w, h, body = ASSET[name]
    out.append(f'<g id="{name}" transform="translate({x:.0f} {y:.0f})">{body}</g>')
    if label:
        out.append(T(x + w / 2, y + h + 20, name.replace("_", " "), 13, "#5A4A3A", "middle", "normal"))
    return w, h


def row(names, x, y, gap=28):
    for n in names:
        w, _ = place(n, x, y)
        x += max(w, 110) + gap


def head(x, y, s):
    out.append(T(x, y, s, 26, INK, "start"))
    out.append(Ln((x, y + 9), (x + len(s) * 15, y + 9), RUST, 5))


head(50, 190, "Salas del cohete")
row(["sala_cabina", "sala_tanque", "sala_motor", "sala_modulo"], 50, 220)
row(["sala_avionica", "sala_anillo", "sala_escudo"], 50, 590)
head(50, 700, "Escotillas y drones")
row(["escotilla_cerrada", "escotilla_abierta", "escotilla_sellada", "dron_tecnico", "dron_alerta", "dron_caido"], 50, 730)
head(50, 860, "Lo que se rompe")
names = ["averia_" + k for k in G]
row(names[:7], 50, 890, 50)
row(names[7:], 50, 1000, 50)
head(50, 1130, "Interfaz")
place("ui_panel", 50, 1160)
row(["ui_boton", "ui_boton_hover", "ui_boton_pulsado"], 400, 1160)
row(["ui_barra_fondo", "ui_barra_cian", "ui_barra_naranja", "ui_barra_verde", "ui_barra_roja"], 400, 1250)
row(["ui_pip_vacio", "ui_pip_cian", "ui_pip_naranja", "ui_pip_verde", "ui_pip_roja", "ui_seleccion"], 400, 1320)
place("ui_alerta", 1100, 1160)

# Cohete montado sobre un panel oscuro, como se veria en el juego.
out.append(P(wob(rectpts(1730, 150, 620, 1310), r, 4), INK))
out.append(P(wob(rectpts(1718, 138, 620, 1310), r, 4), "#2B3440", INK, 6))
for k in range(40):
    out.append(C(1730 + r.random() * 596, 150 + r.random() * 1286, r.uniform(1, 2.6), BONE, None))
out.append(T(1740, 126, "Un cohete armado con el kit", 24, INK, "start"))
cx, y = 2028, 186
for n in ["sala_cabina", "sala_avionica", "sala_escudo", "sala_tanque", "sala_anillo", "sala_tanque", "sala_motor"]:
    w, h, body = ASSET[n]
    out.append(f'<g transform="translate({cx - w / 2:.0f} {y})">{body}</g>')
    y += h - 4
for n, x0, y0 in (("sala_modulo", cx + 76, 470), ("sala_modulo", cx - 140, 470), ("escotilla_abierta", cx - 24, 320), ("escotilla_cerrada", cx - 24, 718),
                  ("dron_tecnico", cx - 110, 250), ("dron_alerta", cx - 150, 820), ("averia_fuga_combustible", cx + 92, 880),
                  ("averia_cortocircuito", cx + 76, 322), ("ui_seleccion", cx + 88, 876)):
    out.append(f'<g transform="translate({x0} {y0})">{ASSET[n][2]}</g>')
out.append("</svg>")
SHEET.write_text("\n".join(out), encoding="utf-8")
print(len(ASSET), "piezas ->", ASSETS, "| lamina ->", SHEET)
