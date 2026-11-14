#!/usr/bin/env python3
"""Un cohete de una sola columna, armado como lo hace el juego, con sus variaciones.

- Cohete de referencia: las 12 piezas de Run.debug_setup, colocadas con las reglas de
  ShipRenderer.layout (pila vertical desde la base; piezas radiales ancladas a su bloque).
- Estados: el mismo cohete con las 7 variantes de estado de las piezas (parts_ink.py).
- Variaciones de armado: otras 4 configuraciones, todas con piezas de content/parts.
Salida: docs/art/cohete_variantes.svg    Uso: python3 tools/cohete_variantes_svg.py
"""
import contextlib
import io
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
with contextlib.redirect_stdout(io.StringIO()):
    import moodboard_svg as mb
    import parts_ink as pi
    import interior_kit_svg as ik

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "art" / "cohete_variantes.svg"
S, PAD = 2.0, pi.PAD
INK, BONE, RUST, MUSTARD = ik.INK, ik.BONE, ik.RUST, ik.MUSTARD
BY = {p["id"]: p for p in mb.flat}
FONT = ik.FONT
W = 3000

# --- armados: lista en orden de juego; las radiales (id, lado, montaje) se anclan al bloque anterior ---
REF = [("motor_trueno",), ("tanque_ancho",), ("radiador", 0, 0.5), ("patas", 0, 0.0), ("desacoplador",), ("motor_susurro",),
       ("tanque_largo",), ("panel_solar", 0, 0.5), ("computadora",), ("escudo_termico",), ("capsula",), ("paracaidas",)]
VARIANTS = [
    ("Ligero", [("motor_chispa",), ("tanque_corto",), ("patas", 0, 0.0), ("tanque_corto",), ("panel_solar", 0, 0.5),
                ("computadora",), ("capsula",), ("paracaidas",)]),
    ("Pesado", [("motor_trueno",), ("tanque_ancho",), ("radiador", 0, 0.5), ("tanque_ancho",), ("radiador", 0, 0.5), ("desacoplador",),
                ("motor_susurro",), ("tanque_largo",), ("rcs", 0, 0.5), ("escudo_termico",), ("capsula",), ("torre_escape",)]),
    ("Largo alcance", [("motor_susurro",), ("tanque_gota",), ("rtg", 0, 0.5), ("desacoplador",), ("motor_susurro",), ("tanque_largo",),
                       ("antena", 0, 0.8), ("aislante",), ("blindaje",), ("computadora",), ("sensores", 0, 0.5), ("capsula",)]),
    ("Retorno", [("motor_susurro",), ("tanque_corto",), ("patas", 0, 0.0), ("bateria",), ("giroscopio", 0, 0.5), ("computadora",),
                 ("escudo_ligero",), ("capsula",), ("paracaidas",)]),
]
STATE_LABEL = {"normal": "normal", "desgastada": "desgastada", "defectuosa": "defectuosa", "rota": "rota",
               "sin_revelar": "sin revelar", "chatarra": "chatarra", "legendaria": "legendaria"}

ids = {}


def size(pid):
    return BY[pid]["size"][0] * S, BY[pid]["size"][1] * S


def uid(base):
    ids[base] = ids.get(base, 0) + 1
    return f"{base}_{ids[base]}"


def layout(spec):
    """Reglas de ShipRenderer.layout: rect (x, y, w, h) por pieza; origen = centro de la base, y hacia arriba negativa."""
    rects, y = [None] * len(spec), 0.0
    for i, e in enumerate(spec):
        if not BY[e[0]]["radial"]:
            w, h = size(e[0])
            y -= h
            rects[i] = (-w / 2, y, w, h)
    for i, e in enumerate(spec):
        if BY[e[0]]["radial"]:
            hi = max(j for j in range(i + 1) if not BY[spec[j][0]]["radial"])
            hx, hy, hw, hh = rects[hi]
            w, h = size(e[0])
            mount = max(0.0, min(1.0, e[2]))
            ry = hy + hh - h - (hh - h) * mount
            if BY[e[0]]["kind"] == "legs":
                ry = hy + hh - h * 0.6
            rects[i] = (hx + hw + 2, ry, w, h)
    return rects


def part(pid, rect, state, flip, gid):
    p = BY[pid]
    x, y, w, h = rect
    _, _, body = pi.draw_part_ink(pid, p["kind"], p["color"], w, h, state, flip)
    return f'<g id="{gid}" transform="translate({x - PAD:.1f} {y - PAD:.1f})">{body}</g>'


def flame(w, ln, rnd):
    j = lambda v: v + rnd.uniform(-3, 3)
    pts = [(-w / 2, 0), (w / 2, 0), (j(w * 0.22), ln * 0.62), (j(4), ln), (j(-w * 0.22), ln * 0.6)]
    return (pi.P(pts, RUST, INK, 5) + pi.P([(-w * 0.3, 0), (w * 0.3, 0), (3, ln * 0.5), (-3, ln * 0.46)], MUSTARD, None)
            + pi.P([(-w * 0.14, 0), (w * 0.14, 0), (0, ln * 0.28)], BONE, None))


def rocket(spec, state="normal", tag="cohete", with_flame=True):
    """SVG del cohete con el origen en el centro de su base."""
    rects = layout(spec)
    out = []
    if with_flame and BY[spec[0][0]]["kind"] == "engine":
        ew = size(spec[0][0])[0]
        out.append(f'<g id="{uid(tag + "_llama")}">{flame(ew * 0.7, ew * 1.7, random.Random(tag))}</g>')
    for i, e in enumerate(spec):
        if not BY[e[0]]["radial"]:
            out.append(part(e[0], rects[i], state, False, uid(f"{tag}_{e[0]}")))
    for i, e in enumerate(spec):
        if BY[e[0]]["radial"]:
            x, y, w, h = rects[i]
            out.append(part(e[0], rects[i], state, False, uid(f"{tag}_{e[0]}")))
            out.append(part(e[0], (-(x + w), y, w, h), state, True, uid(f"{tag}_{e[0]}_espejo")))
    return "".join(out)


def height(spec):
    return -min(r[1] for r in layout(spec))


def cost(spec):
    return sum(BY[e[0]]["cost"] for e in spec)


def text(x, y, s, size=20, fill=BONE, anchor="start", weight="normal"):
    return f'<text x="{x:.0f}" y="{y:.0f}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{s}</text>'


def head(x, y, s):
    return text(x, y, s, 34, MUSTARD, "start", "bold") + pi.Ln((x, y + 12), (x + len(s) * 17, y + 12), RUST, 5)


def at(x, y, k, body, gid):
    return f'<g id="{gid}" transform="translate({x:.0f} {y:.0f}) scale({k})">{body}</g>'


rnd = random.Random("variantes")
body = []
body_cap = []
Y_REF, K_REF = 1230, 1.5
Y_ST, Y_VAR = 2290, 3340
H = 3780

# fondo
bg = [pi.P([(0, 0), (W, 0), (W, H), (0, H)], "#101826")]
for i in range(420):
    bg.append(pi.C(rnd.uniform(0, W), rnd.uniform(0, H), rnd.choice([1.2, 1.6, 2.2, 3.0]), BONE, None))
for i in range(22):
    bg.append(pi.star4(rnd.uniform(60, W - 60), rnd.uniform(60, H - 60), rnd.choice([9, 12, 16]), BONE, INK))

body.append(text(60, 100, "Cohete del juego y sus variaciones", 64, BONE, "start", "bold"))
body.append(text(64, 148, "Una sola columna, armada con las reglas de ship_renderer.gd y solo piezas de content/parts", 24, "#8CA6BF"))

# 1) cohete de referencia
body.append(head(60, 230, "Cohete de referencia"))
body.append(at(520, Y_REF, K_REF, rocket(REF, "normal", "ref"), "cohete_referencia"))
body.append(head(1150, 230, "Sus 12 piezas"))
used = {}
for e in REF:
    used[e[0]] = used.get(e[0], 0) + 1
tot = cost(REF)
for i, pid in enumerate(sorted(used, key=lambda k: (BY[k]["kind"], k))):
    cx, cy = 1190, 300 + i * 78
    w, h = size(pid)
    k = min(56 / h, 84 / w, 1.0)
    p = BY[pid]
    _, _, b = pi.draw_part_ink(pid, p["kind"], p["color"], w, h, "normal", False)
    nx = cx + 54 - w * k / 2
    body.append(f'<g id="ficha_{pid}" transform="translate({nx:.1f} {cy + 30 - h * k / 2:.1f}) scale({k:.3f}) translate({-PAD} {-PAD})">{b}</g>')
    n = used[pid] * (2 if BY[pid]["radial"] else 1)
    body.append(text(cx + 130, cy + 26, f"{n} × {BY[pid]['name']}", 26, BONE, "start", "bold"))
    body.append(text(cx + 130, cy + 54, f"{BY[pid]['kind']} · ${BY[pid]['cost']}", 18, "#8CA6BF"))
body.append(text(1190, 300 + 12 * 78 + 40, f"Total en piezas: ${tot:,}", 26, MUSTARD, "start", "bold"))
body.append(text(1190, 300 + 12 * 78 + 72, "Las radiales (radiador, patas, panel solar) van una a cada lado", 18, "#8CA6BF"))

# 2) estados del mismo cohete
body.append(head(60, 1610, "El mismo cohete en cada estado"))
xs = 60 + 200
for i, st in enumerate(pi.STATES):
    x = 250 + i * 400
    body.append(at(x, Y_ST, 1.0, rocket(REF, st, f"estado_{st}", with_flame=False), f"estado_{st}"))
    body.append(text(x, Y_ST + 50, STATE_LABEL[st], 24, BONE, "middle", "bold"))

# 3) variaciones de armado
body.append(head(60, 2440, "Variaciones de armado"))
for i, (name, spec) in enumerate(VARIANTS):
    x = 340 + i * 700
    body.append(at(x, Y_VAR, 1.0, rocket(spec, "normal", "var_" + name.lower().replace(" ", "_")), "variacion_" + name.lower().replace(" ", "_")))
    body.append(text(x, Y_VAR + 215, name, 30, BONE, "middle", "bold"))
    body.append(text(x, Y_VAR + 246, f"{len(spec)} piezas · ${cost(spec):,}", 20, "#8CA6BF", "middle"))
    kinds = []
    for e in spec:
        nm = BY[e[0]]["name"]
        if nm not in kinds:
            kinds.append(nm)
    line, lines = "", []
    for nm in kinds:
        if len(line) + len(nm) > 38:
            lines.append(line.rstrip(", "))
            line = ""
        line += nm + ", "
    lines.append(line.rstrip(", "))
    for j, ln in enumerate(lines[:3]):
        body.append(text(x, Y_VAR + 278 + j * 24, ln, 16, "#8CA6BF", "middle"))

OUT.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "".join(bg) + "\n".join(body) + "</svg>\n", encoding="utf-8")
print(OUT, "| referencia:", len(REF), "piezas, altura", int(height(REF)), "| variaciones:", [len(v[1]) for v in VARIANTS])
