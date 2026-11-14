#!/usr/bin/env python3
"""Genera los mockups SVG (1280x720) de Space siguiendo DISEÑO-UI-NAVES-25D.md."""

from pathlib import Path
from xml.sax.saxutils import escape

OUT_DIR = Path(__file__).resolve().parent

FONT_SANS = "'Noto Sans', 'Liberation Sans', 'DejaVu Sans', sans-serif"
FONT_MONO = "'Liberation Mono', 'DejaVu Sans Mono', monospace"

PAL = {
    "void": "#080c16",
    "crt": "#05070b",
    "chassis": "#0f1726",
    "raised": "#172236",
    "active": "#1e2d47",
    "seam": "#24344d",
    "cream": "#f4ebd9",
    "muted": "#8b9bb4",
    "terracotta": "#c83e2b",
    "amber": "#f09c14",
    "cyan": "#38bdf8",
    "ok": "#22c55e",
    "outline": "#0b0e17",
    "hull_hi": "#9aa5b8",
    "hull_mid": "#606a80",
    "hull_lo": "#384152",
    "mylar": "#fbbf24",
    "white_band": "#f1f5f9",
}


def txt(x, y, content, size=13, color=PAL["cream"], weight="500", mono=False, anchor="start"):
    fam = FONT_MONO if mono else FONT_SANS
    return (
        f'<text x="{x}" y="{y}" font-family="{fam}" font-size="{size}" '
        f'font-weight="{weight}" fill="{color}" text-anchor="{anchor}">{escape(content)}</text>'
    )


def rect(x, y, w, h, fill, rx=4, stroke="none", sw=0, opacity=1.0):
    op = f' fill-opacity="{opacity}"' if opacity < 1.0 else ""
    st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke != "none" else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"{op}{st}/>'


def bayer_dither_circle(cx, cy, r, step=6, color="#080c16"):
    """Genera terminador pixel-art con trama ordenada Bayer 4x4 sobre el lado derecho del planeta."""
    bayer = [
        [0, 8, 2, 10],
        [12, 4, 14, 6],
        [3, 11, 1, 9],
        [15, 7, 13, 5],
    ]
    out = [f'<defs><clipPath id="planetClip"><circle cx="{cx}" cy="{cy}" r="{r}"/></clipPath></defs>']
    out.append('<g clip-path="url(#planetClip)">')
    for py in range(cy - r, cy + r, step):
        for px in range(cx - r, cx + r, step):
            dx = (px - cx) / float(r)
            dy = (py - cy) / float(r)
            # Luz solar desde arriba-izquierda (315 deg): sombra crece hacia derecha-abajo
            light_coord = dx * 0.78 + dy * 0.42
            if light_coord > -0.15:
                shade = min(max((light_coord + 0.15) / 0.95, 0.0), 1.0)
                bx = ((px // step) % 4)
                by = ((py // step) % 4)
                thresh = (bayer[by][bx] + 0.5) / 16.0
                if shade > thresh:
                    out.append(f'<rect x="{px}" y="{py}" width="{step}" height="{step}" fill="{color}" fill-opacity="0.88"/>')
    out.append("</g>")
    return "\n".join(out)


def draw_modular_ship(cx, cy, scale=1.0, cutaway=True, show_fire=False, level=4):
    """Dibuja Orbital Mule Mk-I (pin_22 + FTL cutaway + abrazaderas blancas + z-layering)."""
    s = scale
    parts = [f'<g transform="translate({cx},{cy}) scale({s})">']

    # Sombra 2.5D proyectada bajo la nave
    parts.append('<ellipse cx="6" cy="14" rx="76" ry="118" fill="#04070e" fill-opacity="0.55"/>')

    # Z=-1 Motores traseros remetidos bajo el faldon de popa
    for ex in (-26, 10):
        # Pluma naranja/halftone
        parts.append(f'<polygon points="{ex+2},102 {ex+14},102 {ex+18},136 {ex+8},148 {ex-2},136" fill="#f09c14" fill-opacity="0.72"/>')
        parts.append(f'<polygon points="{ex+4},102 {ex+12},102 {ex+12},126 {ex+8},134 {ex+4},126" fill="#fff1c2"/>')
        if level >= 4:
            parts.append(f'<ellipse cx="{ex+8}" cy="124" rx="14" ry="4" fill="none" stroke="#fff1c2" stroke-width="1.5" stroke-opacity="0.65"/>')
        # Tobera remetida (anclada 6px arriba del faldon para cubrir junta)
        parts.append(rect(ex, 84, 16, 20, "#334155", rx=2, stroke=PAL["outline"], sw=2))
        parts.append(rect(ex + 2, 92, 12, 10, "#1e293b", rx=1))
        parts.append(rect(ex + 3, 86, 10, 3, PAL["hull_hi"], rx=1))

    # Z=2 Alas / Apendices laterales articulados (paneles solares + radiador) con rotula mecanica
    for side in (-1, 1):
        # Rotula articulada conectando el borde exterior de la gondola (-60 / +60) al ala
        hx = -69 if side == -1 else 59
        parts.append(rect(hx, -4, 10, 18, "#475569", rx=1, stroke=PAL["outline"], sw=2))
        # Ala solar / radiador desplegado sin traslapar gondola
        wx = -117 if side == -1 else 69
        parts.append(rect(wx, -10, 48, 28, "#1e3a8a", rx=2, stroke=PAL["outline"], sw=2))
        parts.append(rect(wx + 3, -7, 42, 20, "#2563eb", rx=1))
        # Bisel 2.5D inferior de la ala
        parts.append(rect(wx + 2, 12, 44, 4, "#0f172a", rx=0))
        # Rejilla fotovoltaica pixel
        for gx in range(wx + 10, wx + 42, 10):
            parts.append(f'<line x1="{gx}" y1="-8" x2="{gx}" y2="12" stroke="#93c5fd" stroke-width="1" stroke-opacity="0.55"/>')
        parts.append(f'<line x1="{wx+3}" y1="2" x2="{wx+45}" y2="2" stroke="#93c5fd" stroke-width="1" stroke-opacity="0.55"/>')

    # Z=1 Gondolas laterales babor/estribor con abrazaderas blancas (estilo pin_22)
    for side in (-1, 1):
        nx = -60 if side == -1 else 32
        # Oclusion de contacto entre nucleo y gondola
        ax = -34 if side == -1 else 30
        parts.append(rect(ax, -16, 6, 84, "#05070b", rx=0, opacity=0.82))
        # Cuerpo de gondola con extrusión 2.5D inferior
        parts.append(rect(nx, -22, 28, 90, PAL["hull_mid"], rx=8, stroke=PAL["outline"], sw=2.5))
        parts.append(rect(nx + 3, -19, 10, 74, PAL["hull_hi"], rx=4, opacity=0.45))
        parts.append(rect(nx + 4, 52, 20, 13, PAL["hull_lo"], rx=3))
        # Toma frontal de gondola
        parts.append(rect(nx + 7, -34, 14, 14, "#475569", rx=2, stroke=PAL["outline"], sw=2))
        parts.append(rect(nx + 9, -32, 6, 8, PAL["hull_hi"], rx=1))
        # Aislamiento Kapton (LVL 4+)
        if level >= 4:
            parts.append(rect(nx + 5, 28, 18, 10, PAL["mylar"], rx=1))
        # Abrazaderas blancas estructurales que amarran la gondola al chasis (clave pin_22)
        for by in (-4, 38):
            bx = nx - 1 if side == -1 else nx - 10
            parts.append(rect(bx, by, 39, 9, PAL["white_band"], rx=1, stroke=PAL["outline"], sw=1.5))
            parts.append(rect(bx + 12, by + 1, 7, 7, "#334155", rx=1))
            parts.append(rect(bx + 14, by + 3, 3, 3, PAL["white_band"], rx=0))
        # LEDs indicadores de nivel (pin_08)
        for p in range(level):
            parts.append(rect(nx + 6 + p * 4, 16, 2, 4, PAL["cyan"], rx=0))

    # Z=0 Chasis Maestro Central (silueta unificada estilo pin_22)
    # Puntas frontales de proa (sensor prongs)
    parts.append(rect(-16, -112, 12, 34, PAL["hull_mid"], rx=2, stroke=PAL["outline"], sw=2))
    parts.append(rect(4, -112, 12, 34, PAL["hull_mid"], rx=2, stroke=PAL["outline"], sw=2))
    parts.append(rect(-14, -108, 4, 24, PAL["hull_hi"], rx=1))
    parts.append(rect(6, -108, 4, 24, PAL["hull_hi"], rx=1))

    # Anillo Escudo Termico Proa (SOCKET_BOW, encaja sobre cuello frontal)
    parts.append('<path d="M -28 -86 Q 0 -100 28 -86 L 26 -72 Q 0 -84 -26 -72 Z" fill="#853e33" stroke="#0b0e17" stroke-width="2.5"/>')
    parts.append('<path d="M -24 -84 Q 0 -95 24 -84" fill="none" stroke="#f5b97d" stroke-width="2"/>')

    # Casco central principal (contenedor de salas FTL 64x168 aprox)
    parts.append(rect(-32, -74, 64, 162, PAL["hull_lo"], rx=6, stroke=PAL["outline"], sw=2.5))

    if not cutaway:
        # Techo cerrado del casco exterior con biselado 2.5D y antena dorsal
        parts.append(rect(-28, -70, 56, 150, PAL["hull_mid"], rx=4))
        parts.append(rect(-24, -66, 20, 140, PAL["hull_hi"], rx=2, opacity=0.35))
        # Cupula oscura cabina
        parts.append('<ellipse cx="0" cy="-48" rx="14" ry="18" fill="#111827" stroke="#0b0e17" stroke-width="2"/>')
        parts.append('<line x1="-8" y1="-52" x2="8" y2="-52" stroke="#38bdf8" stroke-width="2.5"/>')
        # Antena dorsal Z=3 con sombra proyectada (+3, +3)
        parts.append('<circle cx="5" cy="18" r="14" fill="#04070e" fill-opacity="0.6"/>')
        parts.append('<circle cx="2" cy="15" r="14" fill="#cbd5e1" stroke="#0b0e17" stroke-width="2"/>')
        parts.append('<circle cx="2" cy="15" r="5" fill="#f09c14"/>')
    else:
        # Interior FTL Cutaway: 6 salas con muros 2.5D (cara superior + faldon frontal oscuro)
        rooms = [
            # (id, x, y, w, h, label, state)
            ("HELM", -26, -68, 28, 36, "TIMON", "ok"),
            ("SENS", 4, -68, 22, 36, "RADAR", "ok"),
            ("O2", -26, -28, 22, 42, "O2", "ok"),
            ("REAC", -2, -28, 28, 42, "REAC", "reactor"),
            ("SCI", -26, 18, 52, 30, "CIENCIA", "ok"),
            ("ENG", -26, 52, 52, 30, "MOTORES", "fire" if show_fire else "ok"),
        ]
        for rid, rx, ry, rw, rh, rlabel, rstate in rooms:
            floor_col = "#162032"
            if rstate == "fire":
                floor_col = "#3b1718"
            elif rstate == "reactor":
                floor_col = "#12263a"
            # Suelo de sala
            parts.append(rect(rx, ry, rw, rh, floor_col, rx=2, stroke="#64748b", sw=1.5))
            # Muro superior 2.5D (efecto profundidad de tabique interior)
            parts.append(rect(rx + 1, ry + 1, rw - 2, 4, "#475569", rx=0))
            if rstate == "reactor":
                parts.append('<circle cx="12" cy="-5" r="7" fill="#38bdf8" fill-opacity="0.85" stroke="#0b0e17" stroke-width="1.5"/>')
                parts.append('<circle cx="12" cy="-5" r="3" fill="#e0f2fe"/>')
            elif rstate == "fire":
                # Trama diagonal de peligro + fuego halftone pixel
                parts.append(f'<line x1="{rx+4}" y1="{ry+8}" x2="{rx+rw-4}" y2="{ry+rh-4}" stroke="#ef4444" stroke-width="1.5" stroke-dasharray="3 3"/>')
                parts.append(rect(rx + 8, ry + 10, 8, 8, "#f97316", rx=1))
                parts.append(rect(rx + 18, ry + 12, 6, 10, "#ef4444", rx=1))
                parts.append(rect(rx + 12, ry + 14, 4, 5, "#fef08a", rx=0))
            else:
                # Consola interior de puesto
                parts.append(rect(rx + 4, ry + 8, 10, 6, "#0f1726", rx=1, stroke="#38bdf8", sw=1))
            parts.append(txt(rx + rw / 2, ry + rh - 5, rlabel, size=6.5, color="#cbd5e1", weight="700", anchor="middle"))

        # Compuertas entre salas (amarillo naranja) y esclusas exteriores (cyan airlocks)
        for dx, dy in [(2, -52), (-14, -30), (10, -30), (0, 16), (0, 50)]:
            parts.append(rect(dx, dy, 6, 4, PAL["amber"], rx=0))
        # Esclusas al vacio en popa (airlocks)
        for ax in (-34, 28):
            parts.append(rect(ax, 62, 6, 10, PAL["cyan"], rx=1, stroke=PAL["outline"], sw=1))

        # Bots tripulantes dentro de salas
        bots = [(-12, -48, "#22c55e"), (14, -48, "#38bdf8"), (2, 34, "#f09c14")]
        for bx, by, bcol in bots:
            parts.append(f'<circle cx="{bx}" cy="{by}" r="4.5" fill="{bcol}" stroke="#0b0e17" stroke-width="1.5"/>')
            parts.append(f'<rect x="{bx-2}" y="{by-1.5}" width="4" height="2" fill="#0b0e17"/>')

        # Sombra sutil de antena dorsal superpuesta para no estorbar lectura FTL
        parts.append('<circle cx="24" cy="24" r="7" fill="#cbd5e1" fill-opacity="0.35" stroke="#0b0e17" stroke-width="1"/>')

    parts.append("</g>")
    return "\n".join(parts)


def build_mockup_1():
    """Mockup 1: Dique Seco Modular 2.5D + Evolucion LVL 1-5 + Tres Validadores."""
    svg = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">',
        rect(0, 0, 1280, 720, PAL["void"], rx=0),
    ]

    # Top Header Bar (48 px)
    svg.append(rect(0, 0, 1280, 48, PAL["chassis"], rx=0))
    svg.append('<line x1="0" y1="48" x2="1280" y2="48" stroke="#1e2d47" stroke-width="2"/>')
    # Banda tricolor retro-NASA estilo Rhine Lab (pin_18)
    for idx, col in enumerate([PAL["terracotta"], PAL["amber"], PAL["cream"], PAL["cyan"]]):
        svg.append(rect(16 + idx * 14, 10, 10, 28, col, rx=1))
    svg.append(txt(84, 30, "Dique Seco: Orbital Mule Mk-I", size=18, weight="600"))
    svg.append(rect(368, 10, 248, 28, PAL["raised"], rx=4))
    svg.append(txt(380, 29, "Contrato: Marte (0.43 Solar)", size=12, color=PAL["muted"]))
    svg.append(txt(640, 29, "Creditos: $4,250", size=13, color=PAL["amber"], weight="700", mono=True))

    # Toggle Casco 2.5D vs Corte FTL
    svg.append(rect(850, 9, 274, 30, PAL["void"], rx=4))
    svg.append(rect(853, 12, 134, 24, PAL["active"], rx=3))
    svg.append(rect(853, 33, 134, 3, PAL["amber"], rx=1))
    svg.append(txt(920, 29, "Casco + Corte FTL", size=12, weight="600", anchor="middle"))
    svg.append(txt(1055, 29, "Casco Exterior", size=12, color=PAL["muted"], anchor="middle"))

    svg.append(rect(1148, 10, 114, 28, PAL["raised"], rx=4))
    svg.append(txt(1205, 29, "Volver a Mapa", size=12, anchor="middle"))

    # Left Column: Hardpoints + Evolucion LVL 1-5 (x=16..312)
    svg.append(rect(16, 62, 296, 642, PAL["chassis"], rx=6))
    svg.append(txt(32, 88, "Hardpoints del Chasis", size=15, weight="600"))
    svg.append(txt(32, 106, "Los modulos evolucionan sobre la misma nave", size=12, color=PAL["muted"]))

    hardpoints = [
        ("Proa (BOW)", "Escudo PICA-X", 3, False),
        ("Babor (PORT_NAC)", "Tanque LH2 + Abrazadera", 4, True),
        ("Estribor (STBD_NAC)", "Banco RTG / Carga", 2, False),
        ("Alas (WINGS)", "Paneles Solares", 3, False),
        ("Dorsal (TURRET)", "Antena Parabolica DSN", 3, False),
        ("Popa (AFT_ENG)", "Toberas Niobio C-103", 4, False),
    ]
    y_cur = 122
    for hp_name, mod_name, lvl, active in hardpoints:
        bg = PAL["active"] if active else PAL["raised"]
        svg.append(rect(26, y_cur, 276, 52, bg, rx=4))
        if active:
            svg.append(rect(26, y_cur, 4, 52, PAL["amber"], rx=1))
        svg.append(txt(40, y_cur + 21, hp_name, size=13, weight="600" if active else "500"))
        svg.append(txt(40, y_cur + 40, mod_name, size=12, color=PAL["muted"]))
        svg.append(txt(288, y_cur + 21, f"LVL {lvl}", size=12, color=PAL["cyan"] if active else PAL["cream"], weight="700", mono=True, anchor="end"))
        for p in range(5):
            pcol = PAL["amber"] if (active and p < lvl) else (PAL["cyan"] if p < lvl else "#26344a")
            svg.append(rect(246 + p * 9, y_cur + 31, 6, 8, pcol, rx=1))
        y_cur += 58

    # Escalera visual de evolucion LVL 1..5 (inspirada en pin_08)
    svg.append(rect(26, 480, 276, 150, PAL["raised"], rx=4))
    svg.append(txt(38, 502, "Progresion visual (Tanque Babor)", size=13, weight="600"))
    for idx in range(5):
        lv = idx + 1
        bx = 38 + idx * 51
        by = 516
        is_sel = lv == 4
        svg.append(rect(bx, by, 44, 62, PAL["active"] if is_sel else PAL["chassis"], rx=3))
        if is_sel:
            svg.append(rect(bx, by, 44, 3, PAL["amber"], rx=1))
        # Icono progresivo estilo pin_08 (mas detalle y energia segun nivel)
        col_mod = ["#475569", "#64748b", "#94a3b8", "#e2e8f0", "#fbbf24"][idx]
        svg.append(rect(bx + 12, by + 10, 20, 28, col_mod, rx=4, stroke=PAL["outline"], sw=1.5))
        if lv >= 2:
            svg.append(rect(bx + 10, by + 16, 24, 4, PAL["white_band"], rx=0))
        if lv >= 3:
            svg.append(rect(bx + 10, by + 28, 24, 4, PAL["white_band"], rx=0))
        if lv >= 4:
            svg.append(rect(bx + 16, by + 21, 12, 5, PAL["amber"], rx=1))
        if lv == 5:
            svg.append(rect(bx + 18, by + 6, 8, 4, PAL["cyan"], rx=1))
        svg.append(txt(bx + 22, by + 54, f"L{lv}", size=11, color=PAL["amber"] if is_sel else PAL["muted"], mono=True, anchor="middle"))

    svg.append(txt(38, 606, "Calidad activa: Nueva | Costo L5: $850", size=12, color=PAL["muted"]))
    svg.append(rect(26, 642, 276, 46, PAL["cyan"], rx=4))
    svg.append(txt(164, 670, "Subir Babor a LVL 5 ($850)", size=13, color=PAL["void"], weight="700", anchor="middle"))

    # Center Canvas: Vista Unica Nave Ensamblada 2.5D (x=328..936)
    svg.append(rect(328, 62, 608, 642, "#070b14", rx=6))
    # Fondo blueprint estilo Rhine Lab (arcos finos crema/azul apagado y rejilla 32px)
    for gx in range(360, 936, 48):
        svg.append(f'<line x1="{gx}" y1="62" x2="{gx}" y2="704" stroke="#10192b" stroke-width="1"/>')
    for gy in range(96, 704, 48):
        svg.append(f'<line x1="328" y1="{gy}" x2="936" y2="{gy}" stroke="#10192b" stroke-width="1"/>')
    svg.append('<circle cx="632" cy="378" r="185" fill="none" stroke="#1b2840" stroke-width="1.2" stroke-dasharray="5 5"/>')
    svg.append('<circle cx="632" cy="378" r="245" fill="none" stroke="#162136" stroke-width="1"/>')

    svg.append(txt(348, 88, "Vista Combinada: Casco Modular 2.5D + Corte Interior FTL", size=14, weight="600"))
    svg.append(txt(348, 108, "Escala 1:1 texel | Luz fija 315° | Contorno unico CanvasGroup", size=12, color=PAL["muted"]))

    # Nave grande al centro
    svg.append(draw_modular_ship(632, 376, scale=1.78, cutaway=True, show_fire=False, level=4))

    # Callouts limpios con codo por debajo del texto (cero cruce sobre letras)
    callouts = [
        (586, 212, 344, 162, "Proa BOW (Z=2)", "Encaja en anillo 48px", "start", 118),
        (526, 372, 344, 256, "Abrazaderas + AO 2px", "Sueldan gondolas (pin_22)", "start", 136),
        (434, 372, 344, 514, "Rotula Lateral (Z=2)", "Paneles sin traslape", "start", 116),
        (678, 526, 920, 560, "Popa Remetida (Z=-1)", "Motores bajo faldon", "end", 122),
        (680, 412, 920, 276, "Corte 6 Salas FTL", "Techo a alpha 0 en vuelo", "end", 132),
    ]
    for sx, sy, tx, ty, ctitle, csub, align, span in callouts:
        ex = tx + span if align == "start" else tx - span
        ey = ty + 16
        svg.append(f'<polyline points="{tx},{ey} {ex},{ey} {sx},{sy}" fill="none" stroke="#8b9bb4" stroke-width="1.2" stroke-dasharray="3 2"/>')
        svg.append(f'<circle cx="{sx}" cy="{sy}" r="3" fill="{PAL["amber"]}"/>')
        svg.append(txt(tx, ty - 6, ctitle, size=12, color=PAL["cream"], weight="600", anchor=align))
        svg.append(txt(tx, ty + 10, csub, size=11, color=PAL["muted"], anchor=align))

    svg.append(txt(632, 686, "Huella base: 160x224 px (5x7 celdas de 32 px) — Cero saltos visuales al combinar modulos", size=12, color=PAL["muted"], anchor="middle"))

    # Right Single Panel: Tres Validadores + Perks NASA + Boton Lanzar (x=952..1264)
    svg.append(rect(952, 62, 312, 642, PAL["chassis"], rx=6))
    svg.append(txt(968, 88, "Validacion de Ingenieria", size=15, weight="600"))
    svg.append(txt(968, 106, "Balance NASA/JPL para Marte (1.52 AU)", size=12, color=PAL["muted"]))

    # 3 Barras Claras
    bars = [
        ("Alcance Delta-V", "4,820 / 4,100 m/s (+720)", 0.84, PAL["cyan"]),
        ("Energia en Destino", "9.6 / 6.0 kW (+3.6 kW)", 0.78, PAL["ok"]),
        ("Riesgo Despegue (P_exp)", "8.4% (Omega 0%)", 0.16, PAL["amber"]),
    ]
    by = 128
    for blabel, bval, bfrac, bcol in bars:
        svg.append(rect(968, by, 280, 66, PAL["raised"], rx=4))
        svg.append(txt(980, by + 22, blabel, size=13, weight="600"))
        svg.append(txt(980, by + 40, bval, size=12, color=bcol, mono=True))
        svg.append(rect(980, by + 50, 256, 7, PAL["void"], rx=2))
        svg.append(rect(980, by + 50, int(256 * bfrac), 7, bcol, rx=2))
        by += 78

    # Perks NASA y Contrapartidas
    svg.append(txt(968, 386, "Perks NASA Instalados", size=14, weight="600"))
    perks = [
        ("Escudo Ablativo PICA-X", "Reentrada 0.95 | Desgaste irreversible"),
        ("Radar Doppler Ku", "+14s aviso LEO | Drena energia"),
    ]
    py = 400
    for pname, pdesc in perks:
        svg.append(rect(968, py, 280, 56, PAL["raised"], rx=4))
        svg.append(txt(980, py + 21, pname, size=13, weight="600", color=PAL["cream"]))
        svg.append(txt(980, py + 41, pdesc, size=12, color=PAL["muted"]))
        py += 64

    # Presupuesto FTL de Reactor
    svg.append(rect(968, 536, 280, 82, PAL["raised"], rx=4))
    svg.append(txt(980, 558, "Reactor FTL Base (7 Barras)", size=13, weight="600"))
    svg.append(txt(980, 578, "Demanda total sistemas: 12 barras", size=12, color=PAL["muted"]))
    for i in range(7):
        svg.append(rect(980 + i * 24, 590, 18, 14, PAL["amber"], rx=2))
    svg.append(txt(1236, 601, "7/7", size=12, color=PAL["amber"], mono=True, anchor="end"))

    # CTA Primario
    svg.append(rect(968, 636, 280, 50, PAL["amber"], rx=5))
    svg.append(txt(1108, 667, "A Rampa de Despegue", size=15, color=PAL["void"], weight="700", anchor="middle"))

    svg.append("</svg>")
    out = OUT_DIR / "mockup_1_dique_modular_25d.svg"
    out.write_text("\n".join(svg), encoding="utf-8")
    return out


def build_mockup_2():
    """Mockup 2: HUD Principal Dual (FTL Interior 2.5D + KSP 2.5D Orbital + NavBall + Radar 3D Wireframe)."""
    svg = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">',
        rect(0, 0, 1280, 720, PAL["void"], rx=0),
    ]

    # Top Telemetry Bar (44 px)
    svg.append(rect(0, 0, 1280, 44, PAL["chassis"], rx=0))
    svg.append('<line x1="0" y1="44" x2="1280" y2="44" stroke="#1e2d47" stroke-width="2"/>')
    for idx, col in enumerate([PAL["terracotta"], PAL["amber"], PAL["cream"], PAL["cyan"]]):
        svg.append(rect(12 + idx * 11, 9, 8, 26, col, rx=1))

    top_items = [
        (72, "CASCO", "82%", PAL["ok"]),
        (164, "OXIGENO", "91%", PAL["cyan"]),
        (264, "PROPELENTE", "64%", PAL["amber"]),
        (384, "ORBITA AP / PE", "480 / 142 km", PAL["cream"]),
        (566, "NODO MANIOBRA", "T-00:18 | 310 m/s", PAL["cyan"]),
        (778, "SOLAR MARTE", "589 W/m2 (0.43x)", PAL["amber"]),
        (974, "DONKI CLIMA", "Kp 6 (Tormenta +9s)", PAL["terracotta"]),
        (1170, "MET", "03:42", PAL["cream"]),
    ]
    for tx, tlbl, tval, tcol in top_items:
        svg.append(txt(tx, 16, tlbl, size=11, color=PAL["muted"]))
        svg.append(txt(tx, 34, tval, size=13, color=tcol, weight="700", mono=True))

    # Central Dual Canvas Area (x=12..940, y=54..616)
    svg.append(rect(12, 54, 928, 562, "#060a12", rx=6))

    # Fondo sutil estelar y arcos tecnicos Rhine Lab (pin_18)
    stars = [(44, 94), (112, 188), (390, 108), (446, 480), (76, 512), (564, 98), (880, 144), (540, 560), (904, 520), (318, 574)]
    for sx, sy in stars:
        svg.append(f'<circle cx="{sx}" cy="{sy}" r="1.4" fill="#94a3b8" fill-opacity="0.7"/>')

    # Zona Izquierda del Lienzo: Interior FTL 2.5D en vuelo real
    svg.append(txt(28, 80, "Interior Tactico FTL (Tiempo Real — Sin Pausa)", size=14, weight="600"))
    svg.append(txt(28, 98, "Clic/Tab: cambiar puesto | E: reparar | V: ventear esclusa", size=12, color=PAL["muted"]))

    # Detrito espacial aproximandose por estribor
    svg.append('<polygon points="402,196 418,190 426,204 410,212" fill="#64748b" stroke="#0b0e17" stroke-width="2"/>')
    svg.append(txt(406, 182, "Escombro LEO #412", size=11, color=PAL["amber"], anchor="middle"))

    # Nave en corte FTL (centrada mas a la izquierda para dar aire a popup Popa)
    svg.append(draw_modular_ship(206, 344, scale=1.48, cutaway=True, show_fire=True, level=4))

    # Globo de crisis urgente 5s sobre la sala de Motores (sin tocar gondola ni divisor 504)
    svg.append(rect(318, 444, 174, 48, "#2a1215", rx=4, stroke=PAL["terracotta"], sw=1.5))
    svg.append(txt(330, 464, "Fuego + Brecha Popa", size=12, color=PAL["cream"], weight="600"))
    svg.append(txt(330, 482, "3.4 s | Ventear [V]", size=11, color=PAL["terracotta"], weight="700", mono=True))

    # Divisor optico suave
    svg.append('<line x1="508" y1="68" x2="508" y2="604" stroke="#18243a" stroke-width="1.5" stroke-dasharray="4 4"/>')

    # Zona Derecha del Lienzo: Vista Orbital KSP 2.5D + Rhine Lab (pin_18)
    svg.append(txt(524, 80, "Navegacion Orbital KSP 2.5D (Marte / Rhine Lab)", size=14, weight="600"))
    svg.append(txt(524, 98, "Nodo de Retroignicion programado para captura y reentrada", size=12, color=PAL["muted"]))

    # Planeta Marte 2.5D con anillos de altitud Rhine Lab y terminador Bayer 4x4
    px, py, pr = 758, 396, 84
    # Anillos de escala orbital
    svg.append(f'<circle cx="{px}" cy="{py}" r="112" fill="none" stroke="#c83e2b" stroke-width="1" stroke-dasharray="4 4" stroke-opacity="0.65"/>')
    svg.append(rect(570, 528, 126, 18, "#060a12", rx=2, opacity=0.92))
    svg.append(txt(633, 541, "Atmosfera 100 km", size=11, color="#ea580c", anchor="middle"))
    svg.append(f'<circle cx="{px}" cy="{py}" r="168" fill="none" stroke="#1c2a42" stroke-width="1"/>')
    svg.append(txt(874, 248, "5000 km", size=11, color=PAL["muted"], mono=True))

    # Esfera Marte + sombra Bayer 4x4
    svg.append(f'<circle cx="{px}" cy="{py}" r="{pr}" fill="#c2410c" stroke="#f97316" stroke-width="2" stroke-opacity="0.5"/>')
    svg.append(f'<circle cx="{px-20}" cy="{py-18}" r="{pr-22}" fill="#ea580c" fill-opacity="0.55"/>')
    svg.append(bayer_dither_circle(px, py, pr, step=5, color="#0c101d"))

    # Orbita Elipse Actual (Crema tecnico pin_18)
    svg.append('<ellipse cx="708" cy="364" rx="186" ry="126" transform="rotate(-18 708 364)" fill="none" stroke="#f4ebd9" stroke-width="1.8"/>')
    # Orbita Prevista Post-Burn KSP (Amarillo ambar punteada entrando en corredor atmosferico)
    svg.append('<path d="M 656 232 C 788 206 894 290 852 396 C 824 468 748 502 686 488" fill="none" stroke="#f09c14" stroke-width="2" stroke-dasharray="6 4"/>')

    # Corredor de reentrada destacado
    svg.append('<path d="M 852 396 C 842 432 820 458 790 474" fill="none" stroke="#c83e2b" stroke-width="4" stroke-opacity="0.85"/>')
    svg.append(txt(838, 480, "Corredor -4.6° OK", size=11, color=PAL["amber"], mono=True))

    # Marcadores AP / PE / Nave / Nodo KSP con pildora oscura anti-cruce
    svg.append('<polygon points="566,320 578,310 574,326" fill="#38bdf8" stroke="#080c16" stroke-width="1.5"/>')
    svg.append(txt(540, 304, "Mule Mk-I", size=11, color=PAL["cyan"], weight="700"))

    # Nodo de Maniobra
    svg.append('<circle cx="656" cy="232" r="7" fill="none" stroke="#f09c14" stroke-width="2.2"/>')
    svg.append('<circle cx="656" cy="232" r="2.5" fill="#f4ebd9"/>')
    svg.append(txt(656, 212, "NODO: -310 m/s (T-18s)", size=11, color=PAL["amber"], weight="700", mono=True, anchor="middle"))

    # AP y PE limpios fuera de las curvas
    svg.append('<polygon points="532,428 538,418 544,428" fill="#f4ebd9"/>')
    svg.append(rect(514, 452, 72, 18, "#060a12", rx=2, opacity=0.92))
    svg.append(txt(550, 465, "AP 480 km", size=11, color=PAL["cream"], mono=True, anchor="middle"))
    svg.append('<polygon points="862,306 868,316 874,306" fill="#38bdf8"/>')
    svg.append(rect(856, 276, 76, 18, "#060a12", rx=2, opacity=0.92))
    svg.append(txt(894, 289, "PE 142 km", size=11, color=PAL["cyan"], mono=True, anchor="middle"))

    # Enlace DSN hacia la Tierra
    svg.append('<line x1="758" y1="396" x2="926" y2="112" stroke="#38bdf8" stroke-width="1" stroke-dasharray="3 4" stroke-opacity="0.6"/>')
    svg.append(txt(920, 126, "DSN Tierra: 14.2 kbps | Retardo 11m40s", size=11, color=PAL["cyan"], mono=True, anchor="end"))

    # Bottom Console (x=12..940, y=624..710, h=86)
    svg.append(rect(12, 624, 928, 86, PAL["chassis"], rx=6))

    # Bloque 1: Barras Reactor FTL (6 sistemas)
    svg.append(txt(26, 642, "Reactor FTL (7/7 Barras)", size=12, weight="600"))
    sys_bars = [
        ("Timon", 1, 2, PAL["cyan"]),
        ("Motor", 3, 3, PAL["amber"]),
        ("Radar", 1, 2, PAL["cyan"]),
        ("Escudo", 1, 3, PAL["amber"]),
        ("O2", 1, 2, PAL["ok"]),
        ("Ciencia", 0, 2, PAL["muted"]),
    ]
    sx = 26
    for sname, act, cap, scol in sys_bars:
        for bi in range(cap):
            bcol = scol if bi < act else "#1f2c42"
            svg.append(rect(sx, 682 - bi * 9, 44, 7, bcol, rx=1))
        svg.append(txt(sx + 22, 702, sname, size=11, color=PAL["cream"] if act > 0 else PAL["muted"], anchor="middle"))
        sx += 60

    # Bloque 2: NavBall 2.5D + Throttle
    svg.append('<line x1="404" y1="634" x2="404" y2="700" stroke="#1c283d" stroke-width="1.5"/>')
    nx, ny, nr = 456, 667, 32
    svg.append(f'<circle cx="{nx}" cy="{ny}" r="{nr}" fill="#9a3412" stroke="#334155" stroke-width="3"/>')
    # Mitad superior cielo de NavBall
    svg.append(f'<path d="M {nx-nr} {ny} A {nr} {nr} 0 0 1 {nx+nr} {ny} Z" fill="#1d4ed8"/>')
    svg.append(f'<line x1="{nx-nr}" y1="{ny}" x2="{nx+nr}" y2="{ny}" stroke="#f4ebd9" stroke-width="1.5"/>')
    # Marcador prograde y vector nodo
    svg.append(f'<circle cx="{nx+10}" cy="{ny-10}" r="5" fill="none" stroke="#22c55e" stroke-width="2"/>')
    svg.append(f'<polygon points="{nx-12},{ny+6} {nx-6},{ny+12} {nx-12},{ny+18}" fill="#f09c14"/>')
    # Reticula central fija nave
    svg.append(f'<polyline points="{nx-10},{ny} {nx-4},{ny} {nx},{ny+5} {nx+4},{ny} {nx+10},{ny}" fill="none" stroke="#f09c14" stroke-width="2.2"/>')
    svg.append(txt(504, 646, "NavBall 2.5D", size=12, weight="600"))
    svg.append(txt(504, 664, "Alineado: Retrogrado", size=12, color=PAL["ok"]))
    svg.append(txt(504, 684, "Empuje: 80% [W/S]", size=12, color=PAL["amber"], mono=True))

    # Bloque 3: Botones de Accion Rapida Overcooked/FTL
    svg.append('<line x1="650" y1="634" x2="650" y2="700" stroke="#1c283d" stroke-width="1.5"/>')
    actions = [
        (666, "Ventear Popa [V]", PAL["terracotta"]),
        (802, "Tormenta Safe [B]", PAL["raised"]),
    ]
    for ax, albl, acol in actions:
        svg.append(rect(ax, 636, 126, 30, acol, rx=4))
        svg.append(txt(ax + 63, 656, albl, size=12, color=PAL["cream"], weight="600", anchor="middle"))
    svg.append(rect(666, 672, 262, 28, PAL["active"], rx=4))
    svg.append(txt(797, 691, "Puesto Activo: 3 Ingeniero [Tab / 1-4]", size=12, color=PAL["cyan"], weight="600", anchor="middle"))

    # Single Right Panel (x=952..1268, y=54..710): Radar Wireframe 3D (pin_26) + Crisis + Crew
    svg.append(rect(952, 54, 316, 656, PAL["chassis"], rx=6))
    svg.append(txt(968, 78, "Radar Topografico 3D (Puesto 2)", size=14, weight="600"))
    svg.append(txt(968, 96, "CelesTrak LEO + JPL SBDB (Solo Radar)", size=12, color=PAL["muted"]))

    # Pantalla CRT negra Wireframe estilo pin_26
    svg.append(rect(968, 108, 284, 240, PAL["crt"], rx=4, stroke="#24344d", sw=1.5))
    # Malla wireframe naranja isometrica (desplazada arriba para dejar libre telemetria inferior)
    for i in range(6):
        yoff = i * 14
        svg.append(f'<polyline points="992,{212+yoff} 1060,{184+yoff} 1120,{196+yoff} 1185,{172+yoff} 1236,{188+yoff}" fill="none" stroke="#ff6a00" stroke-width="1" stroke-opacity="0.8"/>')
    for j in range(6):
        xoff = j * 42
        svg.append(f'<polyline points="{1002+xoff},208 {1024+xoff},280" fill="none" stroke="#a94a28" stroke-width="1" stroke-opacity="0.7"/>')
    # Agujas verticales cian + nodos amenaza naranjas (pin_26)
    needles = [(1046, 198, 146, "LEO #412"), (1142, 186, 124, "AST-101955"), (1192, 210, 158, "DONKI")]
    for nx_p, y_base, y_top, ntag in needles:
        svg.append(f'<line x1="{nx_p}" y1="{y_base}" x2="{nx_p}" y2="{y_top}" stroke="#00d2ff" stroke-width="1.5"/>')
        svg.append(f'<circle cx="{nx_p}" cy="{y_top}" r="4.5" fill="#ff8c00" stroke="#fff1c2" stroke-width="1"/>')
        svg.append(txt(nx_p + 7, y_top + 4, ntag, size=10.5, color="#00d2ff", mono=True))
    svg.append(txt(980, 316, "dist 14.2 km | alt -12m", size=11, color="#ff8c00", mono=True))
    svg.append(txt(980, 334, "v_rel 7.8 km/s | 12s margen", size=11, color="#ff8c00", mono=True))

    # Alertas Activas de Sala (5 s Overcooked)
    svg.append(txt(968, 374, "Alertas de Sala y Tripulacion", size=14, weight="600"))
    alerts = [
        ("#291418", PAL["terracotta"], "Motores: Fuego + Brecha", "3.4 s", "Ingeniero en camino -> Reparar o Ventear"),
        ("#261d0f", PAL["amber"], "Tormenta Solar DONKI X2.2", "9.0 s", "Radar: activar Storm Safe en Sensores"),
        ("#142033", PAL["cyan"], "Ventana DSN Apoapsis", "38.0 s", "Carga: transmitir 140 MB Ciencia"),
    ]
    ay = 388
    for abg, abar, atitle, atime, adesc in alerts:
        svg.append(rect(968, ay, 284, 62, abg, rx=4))
        svg.append(rect(968, ay, 4, 62, abar, rx=1))
        svg.append(txt(982, ay + 22, atitle, size=13, weight="600"))
        svg.append(txt(1240, ay + 22, atime, size=12, color=abar, weight="700", mono=True, anchor="end"))
        svg.append(txt(982, ay + 44, adesc, size=11.5, color=PAL["muted"]))
        ay += 70

    # Estado Rapido de Tripulacion (1P / 4P)
    svg.append(txt(968, 616, "Puestos (Bot Autopilot en Puestos Libres)", size=12, color=PAL["muted"]))
    crew = [
        ("1 Piloto", "Timon", PAL["ok"]),
        ("2 Radar", "Auto 40%", PAL["cyan"]),
        ("3 Ing.", "TU ACTIVO", PAL["amber"]),
        ("4 Carga", "Auto 40%", PAL["muted"]),
    ]
    for idx, (cname, cstat, ccol) in enumerate(crew):
        cx_c = 968 + idx * 72
        svg.append(rect(cx_c, 626, 66, 68, PAL["active"] if idx == 2 else PAL["raised"], rx=4))
        if idx == 2:
            svg.append(rect(cx_c, 626, 66, 3, PAL["amber"], rx=1))
        svg.append(txt(cx_c + 33, 650, cname, size=11.5, weight="600", anchor="middle"))
        svg.append(txt(cx_c + 33, 676, cstat, size=10.5, color=ccol, anchor="middle"))

    svg.append("</svg>")
    out = OUT_DIR / "mockup_2_hud_ftl_ksp_orbital.svg"
    out.write_text("\n".join(svg), encoding="utf-8")
    return out


if __name__ == "__main__":
    p1 = build_mockup_1()
    p2 = build_mockup_2()
    print("Generated:", p1)
    print("Generated:", p2)
