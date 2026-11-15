#!/usr/bin/env python3
"""Extrae los textos del juego (espanol) y mantiene localization/en.po (ingles).

El texto original del codigo y de content/ esta en espanol; ese texto es el msgid del catalogo.
Uso:
  python3 tools/i18n_extract.py --update   anade al .po los textos nuevos (msgstr vacio)
  python3 tools/i18n_extract.py --check    falla si algun texto no tiene traduccion (para PR / CI)
  python3 tools/i18n_extract.py --list     imprime los textos encontrados con su archivo y linea
Los textos que NO son para el jugador (ids, nombres de fuente...) van en localization/ignore.txt y las
palabras en minuscula que SI se muestran (derecha, plazo...) en localization/extra.txt; una por linea, como cadena JSON.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PO = ROOT / "localization" / "en.po"
IGNORE = ROOT / "localization" / "ignore.txt"
EXTRA = ROOT / "localization" / "extra.txt"
TRES_KEYS = ("label", "win_text", "lose_text", "display_name", "description", "title", "text")
ESC = {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}


# --- lectura de GDScript -----------------------------------------------------------------------
def gd_strings(src):
    """Devuelve [(linea, valor)] de los literales "..." (no &"..." ni ^"...") fuera de comentarios."""
    out, i, n, line = [], 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
        elif c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        elif c == '"':
            prefixed = i > 0 and src[i - 1] in "&^"
            start_line, buf, i = line, [], i + 1
            while i < n and src[i] != '"':
                if src[i] == "\\" and i + 1 < n:
                    nxt = src[i + 1]
                    buf.append(ESC.get(nxt, "\\" + nxt))
                    i += 2
                    continue
                if src[i] == "\n":
                    line += 1
                buf.append(src[i])
                i += 1
            if not prefixed:
                out.append((start_line, "".join(buf)))
        i += 1
    return out


def tres_strings(src):
    """Textos de los campos de texto de un .tres. Devuelve [(linea, valor)]."""
    out = []
    for m in re.finditer(r'^(%s) = "((?:[^"\\]|\\.)*)"' % "|".join(TRES_KEYS), src, re.M | re.S):
        raw = m.group(2)
        val = re.sub(r"\\(.)", lambda e: ESC.get(e.group(1), "\\" + e.group(1)), raw)
        out.append((src.count("\n", 0, m.start()) + 1, val))
    return out


# --- que cuenta como texto para el jugador -------------------------------------------------------
def looks_like_text(v):
    s = v.strip()
    if len(s) < 2 or not re.search(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]", s):   # vacio, una letra o sin letras
        return False
    if s.startswith(("res://", "user://", "uid://", "http")):
        return False
    if re.fullmatch(r"[a-z0-9_./:#\-]+", s):          # ids, rutas, nombres de archivo
        return False
    if re.fullmatch(r"[%0-9 .,:;+\-*/()\[\]xX$€@#sdf]*", s):  # solo formato o simbolos
        return False
    if re.fullmatch(r"[A-Z0-9_]{1,5}", s):             # siglas: TWR, RCS...
        return False
    if re.fullmatch(r"[a-z]+", s) and s.isascii():     # palabra suelta en minuscula: clave
        return False
    return True


def _load_list(path):
    if not path.exists():
        return set()
    return {json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("//")}


def load_ignore():
    return _load_list(IGNORE)


def load_extra():
    return _load_list(EXTRA)


def is_candidate(v, ignore=None, extra=None):
    """Texto para el jugador: lo que parece texto, mas las palabras de extra.txt, menos ignore.txt."""
    ignore = load_ignore() if ignore is None else ignore
    extra = load_extra() if extra is None else extra
    return v not in ignore and (v in extra or looks_like_text(v))


JSON_TEXT = {"data/design/training.json": ("title", "why", "text")}  # archivo -> claves que son texto


def json_strings(data, keys):
    """Textos de las claves indicadas, en cualquier nivel del JSON."""
    out = []
    if isinstance(data, dict):
        for k, v in data.items():
            if k in keys and isinstance(v, str):
                out.append(v)
            else:
                out += json_strings(v, keys)
    elif isinstance(data, list):
        for v in data:
            out += json_strings(v, keys)
    return out


def collect():
    """{texto: [(archivo, linea), ...]} de todo el juego, sin los ignorados."""
    ignore, extra, found = load_ignore(), load_extra(), {}
    files = [(p, gd_strings) for p in sorted((ROOT / "game").rglob("*.gd"))]
    files += [(p, tres_strings) for p in sorted((ROOT / "content").rglob("*.tres"))]
    for path, fn in files:
        for line, val in fn(path.read_text(encoding="utf-8")):
            if is_candidate(val, ignore, extra):
                found.setdefault(val, []).append((str(path.relative_to(ROOT)), line))
    for rel, keys in JSON_TEXT.items():
        for val in json_strings(json.loads((ROOT / rel).read_text(encoding="utf-8")), keys):
            if is_candidate(val, ignore, extra):
                found.setdefault(val, []).append((rel, 1))
    return found


# --- catalogo .po --------------------------------------------------------------------------------
def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(s):
    return re.sub(r"\\(.)", lambda e: {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(e.group(1), e.group(0)), s)


def read_po():
    """{msgid: msgstr} del .po actual (sin la cabecera)."""
    if not PO.exists():
        return {}
    entries, cur, field = {}, {}, None
    for raw in PO.read_text(encoding="utf-8").splitlines() + [""]:
        line = raw.strip()
        m = re.match(r'(msgid|msgstr) "(.*)"$', line)
        if m:
            field = m.group(1)
            cur[field] = po_unescape(m.group(2))
            continue
        m = re.match(r'"(.*)"$', line)
        if m and field:
            cur[field] += po_unescape(m.group(1))
            continue
        if not line and "msgid" in cur:
            if cur["msgid"]:
                entries[cur["msgid"]] = cur.get("msgstr", "")
            cur, field = {}, None
    return entries


def write_po(entries, refs):
    head = 'msgid ""\nmsgstr ""\n"Language: en\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Project-Id-Version: Contratista Orbital\\n"\n'
    body = []
    for msgid in sorted(entries, key=lambda k: (refs.get(k, [("~", 0)])[0], k)):
        where = " ".join("%s:%d" % r for r in refs.get(msgid, [])[:3])
        body.append("#: %s\nmsgid \"%s\"\nmsgstr \"%s\"\n" % (where, po_escape(msgid), po_escape(entries[msgid])) if where
                    else "msgid \"%s\"\nmsgstr \"%s\"\n" % (po_escape(msgid), po_escape(entries[msgid])))
    PO.parent.mkdir(parents=True, exist_ok=True)
    PO.write_text(head + "\n" + "\n".join(body), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--update", action="store_true")
    g.add_argument("--check", action="store_true")
    g.add_argument("--list", action="store_true")
    a = ap.parse_args()
    found, po = collect(), read_po()
    if a.list:
        for text, refs in sorted(found.items(), key=lambda kv: kv[1][0]):
            print("%s:%d\t%s" % (refs[0][0], refs[0][1], text.replace("\n", "\\n")))
        print("\n%d textos" % len(found), file=sys.stderr)
        return 0
    missing = [t for t in found if not po.get(t, "").strip()]
    obsolete = [t for t in po if t not in found]
    if a.update:
        merged = {t: po.get(t, "") for t in found}
        write_po(merged, found)
        print("%d textos | %d sin traducir | %d obsoletos eliminados" % (len(found), len(missing), len(obsolete)))
        return 0
    if missing:
        print("Faltan %d traducciones en localization/en.po:" % len(missing))
        for t in missing[:40]:
            r = found[t][0]
            print("  %s:%d  %s" % (r[0], r[1], t.replace("\n", "\\n")[:90]))
        print("Ejecuta: python3 tools/i18n_extract.py --update  y traduce los msgstr vacios.")
        return 1
    print("OK: %d textos, todos traducidos (%d obsoletos en el .po)" % (len(found), len(obsolete)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
