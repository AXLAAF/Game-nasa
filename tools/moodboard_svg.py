#!/usr/bin/env python3
"""Genera docs/art/moodboard.svg para Contratista Orbital.

Fuentes (todo se lee del proyecto, nada inventado):
  - capturas reales de cada fase en docs/art/screens/ (tools/capture_screens.tscn)
  - paleta de UI de game/ui/ui.gd
  - cuerpos celestes de content/bodies/*.tres
  - piezas de content/parts/*.tres, dibujadas con la geometria de game/fx/ship_renderer.gd
Uso: python3 tools/moodboard_svg.py
"""
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "art" / "moodboard.svg"
SCREENS = ROOT / "docs" / "art" / "screens"

W, H = 3200, 2080
MONO = "Consolas, Cascadia Mono, DejaVu Sans Mono, Courier New, monospace"


# --- utilidades de color (semantica de Godot) ---------------------------------------------
def parse_color(s):
    v = [float(x) for x in s.split(",")]
    return v + [1.0] * (4 - len(v))


def hexc(c):
    return "#" + "".join(f"{round(max(0.0, min(1.0, x)) * 255):02x}" for x in c[:3])


def darkened(c, a):
    return [x * (1 - a) for x in c[:3]] + c[3:]


def lightened(c, a):
    return [x + (1 - x) * a for x in c[:3]] + c[3:]


# --- datos del proyecto -------------------------------------------------------------------
ui_src = (ROOT / "game" / "ui" / "ui.gd").read_text(encoding="utf-8")
UI = {k: parse_color(v) for k, v in re.findall(r"const (\w+) := Color\(([^)]*)\)", ui_src)}
RARITY = [parse_color(m) for m in re.findall(r"Color\(([^)]*)\)", re.search(r"const RARITY:.*", ui_src).group(0))]
RARITY_NAMES = re.findall(r'"(\w+)"', re.search(r"const RARITY_NAMES.*", ui_src).group(0))


def tres(path):
    t = path.read_text(encoding="utf-8")
    return dict(re.findall(r"^(\w+) = (.+)$", t, re.M))


PARTS = []
for p in sorted((ROOT / "content" / "parts").glob("*.tres")):
    d = tres(p)
    size = [float(x) for x in re.search(r"Vector2\(([^)]*)\)", d["size"]).group(1).split(",")]
    PARTS.append({
        "id": p.stem,
        "name": d["display_name"].strip('"'),
        "kind": d.get("kind", '&"tank"').split('"')[1],
        "size": size,
        "color": parse_color(re.search(r"Color\(([^)]*)\)", d["color"]).group(1)),
        "cost": int(d.get("cost", "0")),
        "radial": d.get("radial", "false") == "true",
    })
BODIES = []
for p in sorted((ROOT / "content" / "bodies").glob("*.tres")):
    d = tres(p)
    BODIES.append({
        "name": d["display_name"].strip('"'),
        "color": parse_color(re.search(r"Color\(([^)]*)\)", d["color"]).group(1)),
        "atmo": parse_color(re.search(r"Color\(([^)]*)\)", d["atmo_color"]).group(1)) if "atmo_color" in d else None,
        "radius": float(d.get("radius", "10")),
        "orbit": float(d.get("orbit_radius", "0")),
        "atm": float(d.get("atmosphere", "0")),
    })

out = []
add = out.append


def rect(x, y, w, h, fill="none", stroke=None, sw=1, op=None, rx=0, sop=None):
    a = f' fill-opacity="{op:.2f}"' if op is not None else ""
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    s += f' stroke-opacity="{sop:.2f}"' if sop is not None else ""
    r = f' rx="{rx}"' if rx else ""
    add(f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" fill="{fill}"{a}{s}{r}/>')


def circle(x, y, r, fill="none", stroke=None, sw=1, op=None):
    a = f' fill-opacity="{op:.2f}"' if op is not None else ""
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    add(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.2f}" fill="{fill}"{a}{s}/>')


def poly(pts, fill, op=None):
    a = f' fill-opacity="{op:.2f}"' if op is not None else ""
    add(f'<polygon points="{" ".join(f"{x:.2f},{y:.2f}" for x, y in pts)}" fill="{fill}"{a}/>')


def line(x1, y1, x2, y2, stroke, sw=1, op=None):
    a = f' stroke-opacity="{op:.2f}"' if op is not None else ""
    add(f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" stroke="{stroke}" stroke-width="{sw}"{a}/>')


def text(x, y, s, size=16, fill=None, anchor="start", weight="normal"):
    fill = fill or hexc(UI["TEXT"])
    add(f'<text x="{x:.1f}" y="{y:.1f}" font-family="{MONO}" font-size="{size}" font-weight="{weight}" '
        f'fill="{fill}" text-anchor="{anchor}">{s}</text>')


def panel(x, y, w, h, title):
    rect(x, y, w, h, hexc(UI["PANEL"]), "#336b8c", 1.5, op=0.94, rx=8)
    text(x + 24, y + 42, title, 24, hexc(UI["CYAN"]))


# --- pieza: traduccion directa de ShipRenderer._draw_part ---------------------------------
def draw_part(kind, c, x, y, w, h, flipped=False, s=1.0):
    """Dibuja en el rectangulo (x,y,w,h) ya escalado; s = escala para grosores."""
    dark = darkened(c, 0.35)
    cx = x + w / 2
    ex, ey = x + w, y + h
    C, D = hexc(c), hexc(dark)
    if kind == "engine":
        rect(cx - w * 0.3, y, w * 0.6, h * 0.4, D)
        poly([(cx - w * 0.22, y + h * 0.4), (cx + w * 0.22, y + h * 0.4), (ex, ey), (x, ey)], C)
        line(x + 2 * s, ey - s, ex - 2 * s, ey - s, hexc(lightened(c, 0.4)), 2 * s)
    elif kind == "tank":
        rect(x, y, w, h, C)
        rect(x, y, w, 4 * s, D)
        rect(x, ey - 4 * s, w, 4 * s, D)
        gx, gy, gh = x + 4 * s, y + 7 * s, h - 14 * s
        rect(gx, gy, 4 * s, gh, "#000000", op=0.5)
        rect(gx, gy + gh * 0.3, 4 * s, gh * 0.7, "#ffcc33")
        line(cx + 6 * s, y + 6 * s, cx + 6 * s, ey - 6 * s, hexc(lightened(c, 0.25)), 2 * s)
    elif kind == "capsule":
        poly([(x + w * 0.05, ey), (ex - w * 0.05, ey), (cx + w * 0.2, y), (cx - w * 0.2, y)], C)
        circle(cx, y + h * 0.5, w * 0.12, "#66ffff")
    elif kind == "decoupler":
        rect(x, y, w, h, "#26262b")
        for k in range(int(w / (8 * s))):
            x0 = x + k * 8 * s
            poly([(x0, ey), (x0 + 4 * s, y), (x0 + 8 * s, y), (x0 + 4 * s, ey)], "#ffcc1a")
    elif kind == "heatshield":
        poly([(x, y), (ex, y), (ex - 3 * s, ey - 2 * s), (cx, ey + 3 * s), (x + 3 * s, ey - 2 * s)], C)
    elif kind == "parachute":
        rect(x, y + h * 0.4, w, h * 0.6, D)
        circle(cx, y + h * 0.45, w * 0.42, C)
    elif kind == "legs":
        foot = (ex if not flipped else x, ey)
        hip = (x if not flipped else ex, y)
        line(*hip, *foot, C, 3 * s)
        line(foot[0] - 5 * s, foot[1], foot[0] + 5 * s, foot[1], hexc(lightened(c, 0.3)), 3 * s)
    elif kind == "radiator":
        rect(x, y, w, h, C)
        for k in range(int(h / (6 * s))):
            line(x, y + (k * 6 + 3) * s, ex, y + (k * 6 + 3) * s, D, s)
    elif kind == "solar":
        rect(x, y, w, h, "#1a338c")
        for k in range(int(h / (8 * s))):
            line(x, y + k * 8 * s, ex, y + k * 8 * s, "#80b3ff", s, 0.6)
        line(cx, y, cx, ey, "#80b3ff", s, 0.6)
    elif kind == "rtg":
        rect(x, y, w, h, "#404047")
        for k in range(3):
            line(x - 2 * s, y + (4 + k * 6) * s, ex + 2 * s, y + (4 + k * 6) * s, "#666673", 2 * s)
        circle(cx, y + h / 2, 2.5 * s, "#ff6633", op=0.9)
    elif kind == "battery":
        rect(x, y, w, h, C)
        cy = y + h / 2
        line(cx - 4 * s, cy, cx + 4 * s, cy, "#1a1a1a", 2 * s)
        line(cx, cy - 3 * s, cx, cy + 3 * s, "#1a1a1a", 2 * s)
    elif kind == "antenna":
        bx = x if not flipped else ex
        tx, ty = cx, y + 4 * s
        line(bx, ey, tx, ty, C, 2 * s)
        r = w * 0.45
        a0, a1 = math.pi * 0.15, math.pi * 0.85
        add(f'<path d="M{tx + r * math.cos(a0):.2f},{ty + r * math.sin(a0):.2f} A{r:.2f},{r:.2f} 0 0 1 '
            f'{tx + r * math.cos(a1):.2f},{ty + r * math.sin(a1):.2f}" fill="none" stroke="{hexc(lightened(c, 0.3))}" stroke-width="{2 * s}"/>')
    elif kind == "computer":
        rect(x, y, w, h, C)
        for k in range(3):
            circle(x + (6 + k * 6) * s, y + h / 2, 1.6 * s, "#4dff99" if k != 2 else "#1a331a")
    elif kind == "sensor":
        rect(x, y, w, h, C)
        circle(cx, y + h / 2, min(w, h) * 0.35, "#99e6ff")
        line(x, y + h / 2, x - 4 * s, y + h / 2, D, 2 * s)
    elif kind in ("shielding", "insulation"):
        rect(x, y, w, h, C)
        for k in range(int(w / (6 * s))):
            line(x + k * 6 * s, y, x + (k * 6 + 4) * s, ey, hexc(darkened(c, 0.25)), s)
    elif kind == "rcs":
        rect(x, y, w, h, C)
        line(x, y + 2 * s, x - 3 * s, y - 2 * s, D, 2 * s)
        line(ex, ey - 2 * s, ex + 3 * s, ey + 2 * s, D, 2 * s)
    elif kind == "escape":
        line(cx - 3 * s, ey, cx, y + 12 * s, C, 1.5 * s)
        line(cx + 3 * s, ey, cx, y + 12 * s, C, 1.5 * s)
        rect(cx - 3 * s, y, 6 * s, 14 * s, "#e64d33")
    else:
        rect(x, y, w, h, C)
    if kind in ("tank", "computer", "sensor", "battery", "radiator", "shielding", "insulation", "decoupler"):
        rect(x, y, w, h, "none", "#000000", s, sop=0.55)


# ==========================================================================================
add(f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
add('<defs><radialGradient id="neb" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#5a1f7a" stop-opacity="0.55"/>'
    '<stop offset="1" stop-color="#5a1f7a" stop-opacity="0"/></radialGradient></defs>')
rect(0, 0, W, H, hexc(UI["BG"]))
add(f'<ellipse cx="{W * 0.55}" cy="{H * 0.55}" rx="{W * 0.45}" ry="{H * 0.4}" fill="url(#neb)"/>')
for k in range(260):
    sx, sy = (k * 7919) % W, (k * 3571) % H
    circle(sx, sy, 0.8 + (k % 4) * 0.5, "#ffffff", op=0.15 + 0.5 * abs(math.sin(k * 1.7)))

# Cabecera
text(60, 110, "CONTRATISTA ORBITAL", 84, hexc(UI["CYAN"]))
text(64, 158, "Arma barato. Vuela lejos. Apuesta todo.   ·   MOODBOARD — terminal CRT retrofuturista", 26, hexc(UI["DIM"]))
text(W - 60, 110, "Space: Deuda Orbital", 28, hexc(UI["ORANGE"]), "end")
text(W - 60, 150, "Godot 4.7 · capturas reales + vectores de ship_renderer.gd", 20, hexc(UI["DIM"]), "end")

# --- 01 Pantallas -------------------------------------------------------------------------
panel(40, 190, 2080, 1000, "01 · PANTALLAS DEL JUEGO  (capturas reales, debug_setup)")
shots = [("02_hangar_5s.png", "HANGAR · tablero de contratos"), ("04_assembly_5s.png", "ENSAMBLAJE · pila de piezas"),
         ("05_launch_2s.png", "DESPEGUE · Terra"), ("08_space_5s.png", "ESPACIO · navegación orbital"),
         ("09_descent_2s.png", "DESCENSO · corredor de reentrada"), ("12_debrief_5s.png", "DEBRIEF · liquidación")]
tw, th = 640, 360
for i, (fn, cap) in enumerate(shots):
    col, row = i % 3, i // 3
    x, y = 70 + col * (tw + 20), 250 + row * (th + 100)
    p = SCREENS / fn
    if p.exists():
        add(f'<image x="{x}" y="{y}" width="{tw}" height="{th}" preserveAspectRatio="xMidYMid slice" xlink:href="screens/{fn}"/>')
    rect(x, y, tw, th, "none", "#336b8c", 1.5)
    text(x, y + th + 36, f"{i + 1:02d}  {cap}", 20, hexc(UI["TEXT"]))

# --- 02 Paleta UI -------------------------------------------------------------------------
panel(2160, 190, 1000, 560, "02 · PALETA UI  (game/ui/ui.gd)")
keys = ["BG", "PANEL", "PANEL_LIGHT", "DIM", "TEXT", "CYAN", "ORANGE", "RED", "GREEN", "GOLD", "PURPLE"]
for i, k in enumerate(keys):
    col, row = i % 4, i // 4
    x, y = 2190 + col * 238, 256 + row * 140
    rect(x, y, 220, 64, hexc(UI[k]), "#ffffff", 1, sop=0.2, rx=6)
    text(x, y + 90, k, 18, hexc(UI["TEXT"]))
    text(x, y + 112, hexc(UI[k]).upper(), 16, hexc(UI["DIM"]))
y = 690
text(2190, y - 4, "RAREZA", 16, hexc(UI["DIM"]))
for i, c in enumerate(RARITY):
    rect(2190 + i * 320, y + 8, 40, 26, hexc(c), rx=4)
    text(2240 + i * 320, y + 28, f"{RARITY_NAMES[i]}  {hexc(c).upper()}", 17, hexc(c))

# --- 03 Cuerpos ---------------------------------------------------------------------------
panel(2160, 770, 1000, 420, "03 · CUERPOS  (content/bodies)")
for i, b in enumerate(sorted(BODIES, key=lambda b: b["orbit"])):
    col, row = i % 4, i // 4
    x, y = 2280 + col * 240, 880 + row * 160
    r = max(14.0, min(40.0, 10 + b["radius"] * 0.45))
    if b["name"] == "Sol":
        circle(x, y, r + 14, "#ffcc66", op=0.25)
    if b["atmo"]:
        circle(x, y, r + 8, hexc(b["atmo"]), op=b["atmo"][3])
    bc = b["color"][:3]
    m = max(bc)
    circle(x, y, r, hexc([v / m for v in bc] if m > 1 else bc))
    if b["name"] != "Sol":
        add(f'<path d="M{x:.1f},{y - r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x:.1f},{y + r:.1f} Z" fill="#000000" fill-opacity="0.28"/>')
    text(x + r + 16, y - 2, b["name"], 18, hexc(UI["TEXT"]))
    text(x + r + 16, y + 20, f"atm {b['atm']:g}" if b["atm"] else "sin aire", 14, hexc(UI["DIM"]))

# --- 04 Piezas ----------------------------------------------------------------------------
panel(40, 1220, 2380, 830, f"04 · PIEZAS  ({len(PARTS)} en content/parts · geometría de ship_renderer.gd)")
S = 2.0
groups = {}
for p in PARTS:
    groups.setdefault(p["kind"], []).append(p)
order_k = ["engine", "tank", "decoupler", "capsule", "heatshield", "parachute", "legs", "escape", "rcs",
           "solar", "rtg", "battery", "radiator", "insulation", "shielding", "computer", "sensor", "antenna"]
flat = [p for k in order_k for p in groups.get(k, [])] + [p for k, v in groups.items() if k not in order_k for p in v]
cols, cw, ch = 9, 258, 260
for i, p in enumerate(flat):
    col, row = i % cols, i // cols
    cx0, base = 70 + col * cw + cw / 2, 1290 + row * ch + 190
    w, h = p["size"][0] * S, p["size"][1] * S
    rect(cx0 - cw / 2 + 8, base - 196, cw - 16, 250, "#0b1220", "#1f3347", 1, rx=6)
    draw_part(p["kind"], p["color"], cx0 - w / 2, base - h - 8, w, h, s=S)
    text(cx0, base + 18, p["name"], 15, hexc(UI["TEXT"]), "middle")
    text(cx0, base + 38, f"{p['kind']} · ${p['cost']}", 13, hexc(UI["DIM"]), "middle")

# --- 05 Cohete completo -------------------------------------------------------------------
panel(2460, 1220, 700, 830, "05 · COHETE  (Run.debug_setup)")
byid = {p["id"]: p for p in PARTS}
stack_ids = ["motor_trueno", "tanque_ancho", "desacoplador", "motor_susurro", "tanque_largo", "escudo_termico", "capsula", "paracaidas"]
radial = [("panel_solar", "tanque_largo", 0.6), ("radiador", "tanque_ancho", 0.5), ("patas", "tanque_ancho", 0.0)]
S2 = 1.6
cx0, y = 2810, 1900
rects = {}
for pid in stack_ids:
    p = byid.get(pid)
    if not p:
        continue
    w, h = p["size"][0] * S2, p["size"][1] * S2
    y -= h
    rects[pid] = (cx0 - w / 2, y, w, h)
mx, my, mw, mh = rects["motor_trueno"]
fl = mh * 1.6
poly([(mx + mw / 2 - mw * 0.42, my + mh), (mx + mw / 2 + mw * 0.42, my + mh), (mx + mw / 2, my + mh + fl)], "#ff9933", op=0.85)
poly([(mx + mw / 2 - mw * 0.2, my + mh), (mx + mw / 2 + mw * 0.2, my + mh), (mx + mw / 2, my + mh + fl * 0.55)], "#fff2cc", op=0.95)
for pid in stack_ids:
    if pid in rects:
        draw_part(byid[pid]["kind"], byid[pid]["color"], *rects[pid], s=S2)
for pid, host, mount in radial:
    p, hr = byid.get(pid), rects.get(host)
    if not p or not hr:
        continue
    w, h = p["size"][0] * S2, p["size"][1] * S2
    hx, hy, hw, hh = hr
    ry = hy + hh - h - (hh - h) * mount if p["kind"] != "legs" else hy + hh - h * 0.6
    draw_part(p["kind"], p["color"], hx + hw + S2, ry, w, h, False, S2)
    draw_part(p["kind"], p["color"], hx - S2 - w, ry, w, h, True, S2)
top = min(r[1] for r in rects.values())
span, lift = 26 * S2, 60 * S2
pts = [(cx0 + math.cos(math.pi + math.pi * k / 12) * span, top - lift + math.sin(math.pi + math.pi * k / 12) * span * 0.45) for k in range(13)]
pts.append((cx0 + span, top - lift))
poly(pts, "#ffd94d")
for k in range(5):
    line(cx0 - span + span * 2 * k / 4, top - lift, cx0, top, "#e6e6e6", 1, 0.7)
text(2490, 2030, "pila + radiales espejados + llama + paracaídas", 15, hexc(UI["DIM"]))

add("</svg>")
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(out), encoding="utf-8")
print(OUT, f"{OUT.stat().st_size / 1e6:.1f} MB", f"{len(PARTS)} piezas", f"{len(BODIES)} cuerpos")
