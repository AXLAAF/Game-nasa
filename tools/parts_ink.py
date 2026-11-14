#!/usr/bin/env python3
"""Las 25 piezas de content/parts en estilo comic entintado, con sus 7 estados.

Misma paleta, ayudantes y semillas que tools/interior_kit_svg.py (kit de chatarra). Cada pieza conserva
su id, kind, tamano y color del juego; el estado solo cambia el tono y anade capas de desgaste.
Uso desde otro script: draw_part_ink(pid, kind, color, w, h, estado, espejo) -> (ancho, alto, svg)
"""
import contextlib
import io
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
with contextlib.redirect_stdout(io.StringIO()):
    import interior_kit_svg as ik

INK, BONE, RUST, MUSTARD, TEAL, STEEL, STEEL_D, PURPLE = ik.INK, ik.BONE, ik.RUST, ik.MUSTARD, ik.TEAL, ik.STEEL, ik.STEEL_D, ik.PURPLE
STATES = ["normal", "desgastada", "defectuosa", "rota", "sin_revelar", "chatarra", "legendaria"]
PAD = 10
P, Ln, C, D, rectpts = ik.P, ik.Ln, ik.C, ik.D, ik.rectpts


def hx(c):
    return "#" + "".join(f"{round(max(0.0, min(1.0, v)) * 255):02x}" for v in c[:3])


def dark(c, a):
    return [v * (1 - a) for v in c[:3]]


def lerp(c, to, t):
    return [c[i] + (to[i] - c[i]) * t for i in range(3)]


def reg(h):
    """Registra el tono de sombra de un color nuevo para cel()."""
    if h not in ik.SHADE:
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
        ik.SHADE[h] = hx(dark([r, g, b], 0.34))
    return h


def star4(x, y, r, fill, stroke=INK):
    pts = [(x, y - r), (x + r * 0.28, y - r * 0.28), (x + r, y), (x + r * 0.28, y + r * 0.28),
           (x, y + r), (x - r * 0.28, y + r * 0.28), (x - r, y), (x - r * 0.28, y - r * 0.28)]
    return P(pts, fill, stroke, 1.4)


# --- una funcion por kind: (w, h, color_hex, rnd, sw, espejo, id) -> svg ---------------------------
def k_engine(w, h, c, r, sw, fl, pid):
    cx = w / 2
    tf, to = ik.cel(rectpts(cx - 0.3 * w, 0, 0.6 * w, 0.42 * h), STEEL_D, r, sw, 0.6)
    bf, bo = ik.cel([(cx - 0.22 * w, 0.4 * h), (cx + 0.22 * w, 0.4 * h), (w, h), (0, h)], c, r, sw, 0.8, side=0.68)
    return (bf + bo + Ln((cx - 0.3 * w, 0.64 * h), (cx + 0.3 * w, 0.64 * h), INK, 1.5, 0.55)
            + P([(0.05 * w, 0.9 * h), (0.95 * w, 0.9 * h), (w, h), (0, h)], INK) + tf + to
            + ik.rivets([(cx - 0.2 * w, 0.12 * h), (cx + 0.2 * w, 0.12 * h)], 1.6))


def k_tank(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.7)
    cap = 0.07 * h
    gx, gw, gy, gh = 0.1 * w, max(5, 0.09 * w), 0.15 * h, 0.7 * h
    return (f + P(rectpts(0, 0, w, cap), hx(dark(_rgb(c), 0.35))) + P(rectpts(0, h - cap, w, cap), hx(dark(_rgb(c), 0.35)))
            + Ln((0, cap), (w, cap), INK, 1.6) + Ln((0, h - cap), (w, h - cap), INK, 1.6)
            + P(rectpts(gx, gy, gw, gh), "#2a2420", INK, 1.6) + P(rectpts(gx + 1, gy + gh * 0.55, gw - 2, gh * 0.45 - 1), MUSTARD)
            + Ln((0.74 * w, 0.12 * h), (0.74 * w, 0.88 * h), BONE, 2.5, 0.5)
            + ik.rivets([(0.14 * w, cap / 2), (0.86 * w, cap / 2), (0.14 * w, h - cap / 2), (0.86 * w, h - cap / 2)], 1.6) + o)


def k_capsule(w, h, c, r, sw, fl, pid):
    cx = w / 2
    f, o = ik.cel([(0.05 * w, h), (0.95 * w, h), (cx + 0.2 * w, 0), (cx - 0.2 * w, 0)], c, r, sw, 0.8)
    wr = max(5.0, w * 0.17)
    return (f + P([(0.1 * w, 0.8 * h), (0.9 * w, 0.8 * h), (0.93 * w, 0.92 * h), (0.07 * w, 0.92 * h)], RUST, INK, 1.6)
            + C(cx, 0.46 * h, wr, TEAL, INK, sw * 0.9) + D(f"M{cx - wr * 0.5:.1f},{0.46 * h - wr * 0.2:.1f} A{wr * 0.6:.1f},{wr * 0.6:.1f} 0 0 1 {cx + wr * 0.1:.1f},{0.46 * h - wr * 0.6:.1f}", "none", BONE, 2)
            + ik.rivets([(0.2 * w, 0.7 * h), (0.8 * w, 0.7 * h)], 1.6) + o)


def k_decoupler(w, h, c, r, sw, fl, pid):
    body = P(rectpts(0, 0, w, h), STEEL_D)
    x0 = -h
    while x0 < w:
        poly = [(x0, h), (x0 + h, 0), (x0 + 2 * h, 0), (x0 + h, h)]
        poly = ik.clip_half(ik.clip_half(poly, 1, 0, 0), -1, 0, w)
        if len(poly) > 2:
            body += P(poly, MUSTARD)
        x0 += 2 * h
    return body + P(rectpts(0, 0, w, h), "none", INK, max(2.5, sw))


def k_heatshield(w, h, c, r, sw, fl, pid):
    cx = w / 2
    f, o = ik.cel([(0, 0), (w, 0), (0.94 * w, 0.78 * h), (cx, h), (0.06 * w, 0.78 * h)], c, r, sw, 0.8, side=0.62)
    return f + "".join(Ln((0.15 * w + k * 0.15 * w, 0.15 * h), (0.2 * w + k * 0.15 * w, 0.6 * h), INK, 1.3, 0.45) for k in range(5)) + o


def k_parachute(w, h, c, r, sw, fl, pid):
    cx = w / 2
    pf, po = ik.cel(rectpts(0, 0.42 * h, w, 0.58 * h), hx(dark(_rgb(c), 0.35)), r, sw * 0.8, 0.5, hatch=False)
    R = 0.42 * w
    cy = 0.42 * h
    return (pf + po + C(cx, cy, R, c, INK, sw * 0.8)
            + D(f"M{cx:.1f},{cy - R:.1f} A{R:.1f},{R:.1f} 0 0 1 {cx:.1f},{cy + R:.1f} Z", ik.SHADE.get(c, STEEL_D), None)
            + C(cx, cy, R, "none", INK, sw * 0.8) + Ln((cx - R * 0.5, cy - R * 0.5), (cx - R * 0.15, cy - R * 0.8), BONE, 2, 0.6))


def k_legs(w, h, c, r, sw, fl, pid):
    hip = (w, 0) if fl else (0, 0)
    foot = (0, h) if fl else (w, h)
    return (Ln(hip, foot, INK, 8) + Ln(hip, foot, c, 4) + Ln((foot[0] - 10, foot[1]), (foot[0] + 10, foot[1]), INK, 8)
            + Ln((foot[0] - 9, foot[1]), (foot[0] + 9, foot[1]), BONE, 3.2) + C(hip[0], hip[1], 5, STEEL_D, INK, 2.2)
            + ik.rivets([hip], 1.5))


def k_radiator(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.6, hatch=False, side=0.7)
    return (f + "".join(Ln((1.5, y), (w - 1.5, y), INK, 1.3, 0.65) for y in range(8, int(h), 12))
            + ik.rivets([(w / 2, 5), (w / 2, h - 5)], 1.5) + o)


def k_solar(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.6, hatch=False, side=0.7)
    return (f + "".join(Ln((1, y), (w - 1, y), BONE, 1.2, 0.55) for y in range(16, int(h), 16)) + Ln((w / 2, 1), (w / 2, h - 1), BONE, 1.2, 0.55)
            + Ln((0.15 * w, 0.92 * h), (0.85 * w, 0.08 * h), "#FFFFFF", 3, 0.18) + o)


def k_rtg(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.6, side=0.68)
    fins = "".join(ik.box(-3, 6 + k * 12, w + 6, 6, STEEL, r, 2, hatch=False) for k in range(3))
    return f + o + fins + C(w / 2, h * 0.5, max(3.5, w * 0.24), RUST, INK, 1.8) + C(w / 2, h * 0.5, max(1.5, w * 0.1), MUSTARD, None)


def k_battery(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.5, hatch=False, side=0.7)
    cy = h / 2
    return (f + Ln((w / 2 - 8, cy), (w / 2 + 8, cy), INK, 3.4) + Ln((w / 2, cy - 6), (w / 2, cy + 6), INK, 3.4)
            + Ln((0.2 * w, 2), (0.2 * w, h - 2), INK, 1.2, 0.5) + Ln((0.8 * w, 2), (0.8 * w, h - 2), INK, 1.2, 0.5) + o)


def k_antenna(w, h, c, r, sw, fl, pid):
    base = (w if fl else 0, h)
    tip = (w / 2, 0.22 * h)
    rr = w * 0.5
    a0, a1 = (math.pi * 0.85, math.pi * 1.85) if fl else (math.pi * 0.15, math.pi * 0.85)
    arc = f"M{tip[0] + rr * math.cos(a0):.1f},{tip[1] + rr * math.sin(a0):.1f} A{rr:.1f},{rr:.1f} 0 0 1 {tip[0] + rr * math.cos(a1):.1f},{tip[1] + rr * math.sin(a1):.1f}"
    return (Ln(base, tip, INK, 6) + Ln(base, tip, c, 2.4) + D(arc, "none", INK, 6) + D(arc, "none", BONE, 2.4)
            + C(tip[0], tip[1], 3.4, RUST, INK, 1.6) + P(rectpts(base[0] - 5, h - 3, 10, 4), STEEL_D, INK, 1.6))


def k_computer(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.5, hatch=False, side=0.78)
    cy = h / 2
    leds = "".join(C(0.14 * w + k * 0.1 * w, cy, 2.4, [TEAL, MUSTARD, TEAL][k], INK, 1) for k in range(3))
    vents = "".join(Ln((0.55 * w + k * 0.1 * w, 0.28 * h), (0.55 * w + k * 0.1 * w, 0.72 * h), INK, 1.4, 0.6) for k in range(4))
    return f + leds + vents + o


def k_sensor(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.5, side=0.7)
    cx, cy = w / 2, h / 2
    lr = min(w, h) * 0.32
    inward = 0 if not fl else w
    return (f + C(cx, cy, lr, TEAL, INK, 2.4) + Ln((cx - lr * 0.4, cy - lr * 0.4), (cx, cy - lr * 0.7), BONE, 1.6, 0.8)
            + Ln((inward, cy), (inward + (-5 if not fl else 5), cy), INK, 3) + o)


def k_shielding(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.5, hatch=False, side=0.8)
    body = f
    k = -h
    while k < w:
        seg = ik.clip_seg((k, h), (k + h, 0), rectpts(0, 0, w, h))
        if seg:
            body += Ln(*seg, INK, 1.4, 0.6)
        k += 9
    return body + ik.rivets([(5, h / 2), (w - 5, h / 2)], 1.5) + o


def k_insulation(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.5, hatch=False, side=0.8)
    zig = [(x, 0.3 * h if (i % 2) else 0.7 * h) for i, x in enumerate(range(3, int(w), 8))]
    return f + P(zig, "none", INK, 1.5, False, 0.55) + o


def k_rcs(w, h, c, r, sw, fl, pid):
    f, o = ik.cel(rectpts(0, 0, w, h), c, r, sw, 0.5, side=0.7)
    if "giro" in pid:
        return f + C(w / 2, h / 2, min(w, h) * 0.3, TEAL, INK, 2) + Ln((w / 2, h / 2), (w / 2 + 3, h / 2 - 3), BONE, 1.4) + o
    a, b = ((w, 2), (w + 4, -2)), ((0, h - 2), (-4, h + 2))
    if fl:
        a, b = ((0, 2), (-4, -2)), ((w, h - 2), (w + 4, h + 2))
    return f + o + Ln(*a, INK, 3.5) + Ln(*b, INK, 3.5)


def k_escape(w, h, c, r, sw, fl, pid):
    cx = w / 2
    tf, to = ik.cel(rectpts(cx - 0.28 * w, 0, 0.56 * w, 0.36 * h), RUST, r, 2.5, 0.4, hatch=False)
    return (Ln((cx - 0.3 * w, h), (cx, 0.3 * h), INK, 5) + Ln((cx + 0.3 * w, h), (cx, 0.3 * h), INK, 5)
            + Ln((cx - 0.3 * w, h), (cx, 0.3 * h), c, 1.8) + Ln((cx + 0.3 * w, h), (cx, 0.3 * h), c, 1.8) + tf + to)


KINDS = {"engine": k_engine, "tank": k_tank, "capsule": k_capsule, "decoupler": k_decoupler, "heatshield": k_heatshield,
         "parachute": k_parachute, "legs": k_legs, "radiator": k_radiator, "solar": k_solar, "rtg": k_rtg, "battery": k_battery,
         "antenna": k_antenna, "computer": k_computer, "sensor": k_sensor, "shielding": k_shielding, "insulation": k_insulation,
         "rcs": k_rcs, "escape": k_escape}


def _rgb(h):
    return [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]


# --- capas de estado -------------------------------------------------------------------------
def overlay(state, w, h, r):
    if state == "desgastada":
        return ik.scratch(0.15 * w, 0.55 * h, r, 3, max(8, 0.25 * h)) + ik.stain(0.68 * w, 0.28 * h, r)
    if state == "defectuosa":
        crack = [(0.2 * w, 0.1 * h), (0.4 * w, 0.35 * h), (0.3 * w, 0.5 * h), (0.55 * w, 0.8 * h)]
        return P(crack, "none", INK, 2, False) + star4(0.14 * w, 0.14 * h + 4, max(6, min(w, h) * 0.2), MUSTARD)
    if state == "rota":
        return (Ln((0, 0), (w, h), INK, 8) + Ln((w, 0), (0, h), INK, 8) + Ln((0, 0), (w, h), RUST, 3.4) + Ln((w, 0), (0, h), RUST, 3.4)
                + C(w * 0.5, h * 0.5, 2.6, MUSTARD, INK, 1.2) + C(w * 0.2, h * 0.75, 1.8, MUSTARD, None) + C(w * 0.8, h * 0.25, 1.8, MUSTARD, None))
    if state == "sin_revelar":
        k = max(0.5, min(1.4, min(w, h) / 36))
        q = "M-6,-4 Q-6,-12 0,-12 Q7,-12 7,-5 Q7,0 0,2 V6"
        return (P(rectpts(0, 0, w, h), PURPLE, INK, 2.5, True, 0.62)
                + f'<g transform="translate({w / 2:.1f} {h / 2 - 2:.1f}) scale({k:.2f})">' + D(q, "none", INK, 5.5) + D(q, "none", BONE, 2)
                + C(0, 12, 3, INK, None) + C(0, 12, 1.3, BONE, None) + "</g>")
    if state == "chatarra":
        pw, ph = max(9, 0.28 * w), max(8, 0.2 * h)
        return ik.patch(0.55 * w, 0.18 * h, pw, ph, r) + ik.stain(0.28 * w, 0.72 * h, r) + ik.patch(0.12 * w, 0.58 * h, max(8, 0.2 * w), max(7, 0.15 * h), r, ik.RUST)
    if state == "legendaria":
        return (P(rectpts(-3, -3, w + 6, h + 6), "none", INK, 7) + P(rectpts(-3, -3, w + 6, h + 6), "none", MUSTARD, 3.2)
                + star4(w + 3, -3, 8, BONE) + star4(-3, h + 3, 6, BONE))
    return ""


def draw_part_ink(pid, kind, color, w, h, state="normal", flipped=False):
    col = list(color[:3])
    if state == "desgastada":
        col = dark(col, 0.22)
    elif state == "defectuosa":
        col = lerp(col, (0.9, 0.32, 0.08), 0.5)
    elif state == "rota":
        col = dark(col, 0.55)
    c = reg(hx(col))
    sw = max(2.0, min(4.5, min(w, h) * 0.11))
    r = random.Random(pid)
    body = KINDS[kind](w, h, c, r, sw, flipped, pid) + overlay(state, w, h, random.Random(pid + state))
    return int(w + 2 * PAD), int(h + 2 * PAD), f'<g transform="translate({PAD} {PAD})">{body}</g>'
