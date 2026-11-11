#!/usr/bin/env python3
"""Set text in a real font and write a complete liquid glass GLSL shader.

The letter outlines become exact signed distance functions (lines + quadratic
Beziers, nonzero winding), laid out with the font's own advances and kerning.
Marks (the dot of i/j/!/?, accents) can be replaced by shapes from the
glsl-sdf-shapes library.

Examples
  python3 font_to_glsl.py --google "DM Serif Display" --text "I love/Playful Design!" \
      --mark "i@Design=star" --mark "!=heart" --bg "#B5A0D0" --out i-love.glsl
  python3 font_to_glsl.py --font ~/fonts/MyFont.ttf --axis wght=700 --text "Mia" --mark "i=heart"
  python3 font_to_glsl.py --vibe cartoon --text "Once upon a time" --mark "i=star" --out once.glsl
  python3 font_to_glsl.py --vibe romantic --text "Mia" --image photo.jpg --out mia.glsl

Vibes (vibes.json next to the templates) bundle a font and its settings: --vibe NAME.
Image: --image PATH puts the text on that picture (iChannel0) and also writes a
ready-to-open NAME.html that plays the shader with the picture built in.

Text: "/" starts a new line.
Marks: CHAR[@WORD|:N|:all]=SHAPE[*SCALE]
  i=heart          every i
  i:2=star         the 2nd i of the whole text
  i@Design=star    the i's inside the word "Design"
  !=heart*1.2      the dot of every !, 20% bigger
Requires fontTools (pip install fonttools).
"""
import argparse, json, math, os, re, sys, unicodedata, urllib.error, urllib.request
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.basePen import decomposeQuadraticSegment, decomposeSuperBezierSegment
from fontTools.cu2qu import curve_to_quadratic

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "..", "templates", "liquid-glass-text.glsl")
TEMPLATE_SURFACE = os.path.join(HERE, "..", "templates", "liquid-glass-text-surface.glsl")
PREVIEW = os.path.join(HERE, "..", "templates", "preview.html")
VIBES = os.path.join(HERE, "..", "vibes.json")
SHAPES_CANDIDATES = [
    os.path.join(HERE, "..", "..", "glsl-sdf-shapes", "shapes.glsl"),
    os.path.expanduser("~/.claude/skills/glsl-sdf-shapes/shapes.glsl"),
]
CACHE = os.path.expanduser("~/.cache/liquid-glass-fonts")


def die(msg):
    print("error: " + msg, file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------- fonts
def http_get(url):
    """Download with urllib; fall back to curl when Python has no SSL certificates
    (common with the python.org installer on macOS)."""
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            return r.read()
    except urllib.error.HTTPError:
        raise
    except Exception:
        import subprocess
        res = subprocess.run(["curl", "-sSfL", "--max-time", "60", url], capture_output=True)
        if res.returncode != 0:
            raise OSError(res.stderr.decode(errors="replace").strip() or f"curl failed for {url}")
        return res.stdout


def download(url, dest):
    data = http_get(url)
    with open(dest, "wb") as f:
        f.write(data)


def fetch_google_font(family, style):
    """Download a font family from github.com/google/fonts into the cache."""
    os.makedirs(CACHE, exist_ok=True)
    slug = re.sub(r"[^a-z0-9]", "", family.lower())
    for lic in ("ofl", "apache", "ufl"):
        api = f"https://api.github.com/repos/google/fonts/contents/{lic}/{slug}"
        try:
            files = json.loads(http_get(api))
        except Exception:
            continue
        ttfs = [f for f in files if f["name"].endswith(".ttf")]
        if not ttfs:
            continue
        want = style.replace(" ", "").lower()
        static = [f for f in ttfs if "[" not in f["name"]
                  and f["name"].rsplit("-", 1)[-1][:-4].lower() == want]
        var = [f for f in ttfs if "[" in f["name"] and "italic" not in f["name"].lower()]
        if "italic" in want:
            var = [f for f in ttfs if "[" in f["name"] and "italic" in f["name"].lower()]
        pick = (static or var or ttfs)[0]
        dest = os.path.join(CACHE, pick["name"])
        if not os.path.exists(dest):
            download(pick["download_url"], dest)
        for f in files:   # keep the licence next to the font
            if f["name"] in ("OFL.txt", "LICENSE.txt"):
                lp = os.path.join(CACHE, slug + "-" + f["name"])
                if not os.path.exists(lp):
                    download(f["download_url"], lp)
        return dest, lic
    die(f'font family "{family}" not found on Google Fonts')


def load_font(path, axes):
    font = TTFont(path)
    if "fvar" in font:
        from fontTools.varLib import instancer
        loc = {a.axisTag: a.defaultValue for a in font["fvar"].axes}
        loc.update(axes)
        font = instancer.instantiateVariableFont(font, loc)
    return font


def font_metrics(font, gs, cmap):
    os2 = font["OS/2"]
    def top_of(ch):
        g = cmap.get(ord(ch))
        if not g:
            return None
        pts = [p for c in contours_of(gs, g) for s in c for p in s[1:]]
        return max(p[1] for p in pts) if pts else None
    cap = getattr(os2, "sCapHeight", 0) or top_of("H") or font["head"].unitsPerEm * 0.7
    xh = getattr(os2, "sxHeight", 0) or top_of("x") or cap * 0.68
    hh = font["hhea"]
    return cap, xh, hh.ascent, hh.descent


# ---------------------------------------------------------------- outlines
def contours_of(gs, gname):
    """Decomposed outline as a list of contours of ('L',a,b) / ('Q',a,c,b) segments."""
    pen = DecomposingRecordingPen(gs)
    gs[gname].draw(pen)
    contours, segs, cur, start = [], [], None, None
    close = lambda a, b: abs(a[0] - b[0]) < 1e-6 and abs(a[1] - b[1]) < 1e-6
    for op, args in pen.value:
        if op == "moveTo":
            start = cur = tuple(args[0]); segs = []
        elif op == "lineTo":
            p = tuple(args[0])
            if not close(cur, p):
                segs.append(("L", cur, p))
            cur = p
        elif op == "qCurveTo":
            pts = [tuple(p) if p is not None else None for p in args]
            if pts[-1] is None:                       # contour made only of off-curve points
                pts = pts[:-1]
                start = cur = ((pts[-1][0] + pts[0][0]) / 2, (pts[-1][1] + pts[0][1]) / 2)
                segs = []
                pts = pts + [start]
            for off, on in decomposeQuadraticSegment(pts):
                segs.append(("Q", cur, tuple(off), tuple(on))); cur = tuple(on)
        elif op == "curveTo":
            for c1, c2, p in decomposeSuperBezierSegment([tuple(a) for a in args]):
                q = curve_to_quadratic([cur, c1, c2, p], 0.5)
                for off, on in decomposeQuadraticSegment([tuple(x) for x in q[1:]]):
                    segs.append(("Q", cur, tuple(off), tuple(on))); cur = tuple(on)
        elif op in ("closePath", "endPath"):
            if cur is not None and start is not None and not close(cur, start):
                segs.append(("L", cur, start))
            if segs:
                contours.append(segs)
            segs, cur, start = [], None, None
    return contours


def bbox(contour):
    pts = [p for s in contour for p in s[1:]]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return [min(xs), min(ys), max(xs), max(ys)]


def area(contour):
    """Absolute area (polygon through the on-curve points; enough to rank contours)."""
    a = 0.0
    for sg in contour:
        p, q = sg[1], sg[-1]
        a += p[0] * q[1] - q[0] * p[1]
    return abs(a) / 2


def inside(bi, bo):
    return bi[0] >= bo[0] and bi[1] >= bo[1] and bi[2] <= bo[2] and bi[3] <= bo[3]


def union_bbox(bbs):
    return [min(b[0] for b in bbs), min(b[1] for b in bbs), max(b[2] for b in bbs), max(b[3] for b in bbs)]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def monotone_segments(contours, scale, eps):
    """Scale, turn flat quads into lines, split quads at their y extremum."""
    lines, quads = [], []
    sc = lambda p: (p[0] * scale, p[1] * scale)
    for c in contours:
        for s in c:
            if s[0] == "L":
                a, b = sc(s[1]), sc(s[2])
                if abs(a[0] - b[0]) + abs(a[1] - b[1]) > 1e-7:
                    lines.append((a, b))
                continue
            a, m, b = sc(s[1]), sc(s[2]), sc(s[3])
            ab = (b[0] - a[0], b[1] - a[1]); am = (m[0] - a[0], m[1] - a[1])
            L = math.hypot(*ab)
            dev = abs(ab[0] * am[1] - ab[1] * am[0]) / L if L > 1e-9 else math.hypot(*am)
            if dev < eps:
                if L > 1e-7:
                    lines.append((a, b))
                continue
            den = a[1] - 2 * m[1] + b[1]
            t = (a[1] - m[1]) / den if abs(den) > 1e-12 else -1
            if 1e-6 < t < 1 - 1e-6:
                p1, p2 = lerp(a, m, t), lerp(m, b, t)
                mid = lerp(p1, p2, t)
                quads.append((a, (p1[0], mid[1]), mid))
                quads.append((mid, (p2[0], mid[1]), b))
            else:
                quads.append((a, m, b))
    return lines, quads


def scan_widths(lines, quads, y):
    """Inside widths along a horizontal line (to estimate the stem width)."""
    xs = []
    for a, b in lines:
        if (a[1] <= y < b[1]) or (b[1] <= y < a[1]):
            xs.append(a[0] + (y - a[1]) / (b[1] - a[1]) * (b[0] - a[0]))
    for A, B, C in quads:
        y0, y1 = min(A[1], C[1]), max(A[1], C[1])
        if not (y0 <= y < y1):
            continue
        qa, qb, qc = A[1] - 2 * B[1] + C[1], 2 * (B[1] - A[1]), A[1] - y
        if abs(qa) < 1e-12:
            t = -qc / qb
        else:
            disc = math.sqrt(max(qb * qb - 4 * qa * qc, 0))
            t = (-qb + disc) / (2 * qa)
            if not (0 <= t <= 1):
                t = (-qb - disc) / (2 * qa)
        p = lerp(lerp(A, B, t), lerp(B, C, t), t)
        xs.append(p[0])
    xs.sort()
    return [xs[i + 1] - xs[i] for i in range(0, len(xs) - 1, 2)]


# ---------------------------------------------------------------- kerning
class Kerning:
    def __init__(self, font):
        self.subtables, self.flat = [], {}
        if "GPOS" in font:
            gpos = font["GPOS"].table
            idx = set()
            for fr in gpos.FeatureList.FeatureRecord if gpos.FeatureList else []:
                if fr.FeatureTag == "kern":
                    idx.update(fr.Feature.LookupListIndex)
            for li in sorted(idx):
                lk = gpos.LookupList.Lookup[li]
                for st in lk.SubTable:
                    if lk.LookupType == 9:
                        if st.ExtensionLookupType != 2:
                            continue
                        st = st.ExtSubTable
                    elif lk.LookupType != 2:
                        continue
                    self.subtables.append(st)
        if not self.subtables and "kern" in font:
            for kt in font["kern"].kernTables:
                self.flat.update(getattr(kt, "kernTable", {}))

    @staticmethod
    def _xadv(v):
        return getattr(v, "XAdvance", 0) or 0 if v is not None else 0

    def __call__(self, left, right):
        if left is None:
            return 0
        if self.flat:
            return self.flat.get((left, right), 0)
        for st in self.subtables:
            cov = st.Coverage.glyphs
            if left not in cov:
                continue
            if st.Format == 1:
                ps = st.PairSet[cov.index(left)]
                for rec in ps.PairValueRecord:
                    if rec.SecondGlyph == right:
                        return self._xadv(rec.Value1)
            elif st.Format == 2:
                c1 = st.ClassDef1.classDefs.get(left, 0) if st.ClassDef1 else 0
                c2 = st.ClassDef2.classDefs.get(right, 0) if st.ClassDef2 else 0
                return self._xadv(st.Class1Record[c1].Class2Record[c2].Value1)
        return 0


# ---------------------------------------------------------------- marks
def split_marks(ch, contours, xh, cap):
    """Indices of the contours that form the replaceable mark of `ch`."""
    bbs = [bbox(c) for c in contours]
    nfd = unicodedata.normalize("NFD", ch)
    tol = 0.03 * xh
    if ch in "ij":                    # the dot sits above the stem (the contour reaching lowest)
        stem = min(range(len(bbs)), key=lambda k: bbs[k][1])
        marks = [k for k, b in enumerate(bbs) if b[1] > bbs[stem][3] - tol]
    elif ch in "!?":                  # the dot sits below the stroke (the contour reaching highest)
        stem = max(range(len(bbs)), key=lambda k: bbs[k][3])
        marks = [k for k, b in enumerate(bbs) if b[3] < bbs[stem][1] + tol]
    elif ch in ".:":
        marks = list(range(len(contours)))
    elif ch == ";":
        marks = [k for k, b in enumerate(bbs) if b[1] > 0]
    elif len(nfd) > 1:
        if "̧" in nfd:                                   # cedilla, below
            marks = [k for k, b in enumerate(bbs) if b[3] < 0.02 * xh]
        else:                                                  # accents above
            thr = 0.98 * cap if nfd[0].isupper() else 0.9 * xh
            marks = [k for k, b in enumerate(bbs) if b[1] > thr]
    else:
        marks = []
    # Ignore specks (texture, splatter): a mark is a contour of real size, plus what lies inside it
    big = max(area(c) for c in contours)
    solid = [k for k in marks if area(contours[k]) >= 0.04 * big]
    marks = [k for k in marks if k in solid or any(inside(bbs[k], bbs[o]) for o in solid)]
    if not marks:
        die(f'"{ch}" has no detachable dot or accent in this font')
    return marks


def mark_groups(contours, idx):
    """Mark contours that do not overlap horizontally become separate shapes (e.g. a diaeresis)."""
    items = sorted(((bbox(contours[k]), k) for k in idx), key=lambda t: t[0][0])
    groups = []
    for bb, k in items:
        if groups and bb[0] <= groups[-1]["bb"][2]:
            groups[-1]["bb"] = union_bbox([groups[-1]["bb"], bb]); groups[-1]["k"].append(k)
        else:
            groups.append({"bb": bb, "k": [k]})
    return groups


def parse_mark(spec):
    m = re.fullmatch(r"(.)(?:@(.+?)|:(\d+|all))?=([A-Za-z]+)(?:\*([0-9.]+))?", spec)
    if not m:
        die(f'cannot read mark "{spec}" (expected CHAR[@WORD|:N|:all]=SHAPE[*SCALE])')
    ch, word, occ, shape, scl = m.groups()
    return {"ch": ch, "word": word, "occ": occ, "shape": shape.lower(), "scale": float(scl or 1.0)}


# ---------------------------------------------------------------- GLSL
def f4(v):
    s = f"{v:.4f}"
    return "0.0" if s in ("-0.0000", "0.0000") else s


def v2(p):
    return f"vec2({f4(p[0])}, {f4(p[1])})"


GLYPH_HELPERS = """// Signed distance to a glyph outline: exact distance to its lines and quadratic
// Beziers, inside/outside from the nonzero winding rule (outlines are split so that
// every curve is monotonic in y).
float qbDot2(vec2 v) { return dot(v, v); }

// Squared distance to a quadratic Bezier (Inigo Quilez)
float udBezier2(vec2 pos, vec2 A, vec2 B, vec2 C)
{
    vec2 a = B - A;
    vec2 b = A - 2.0 * B + C;
    vec2 c = a * 2.0;
    vec2 d = A - pos;
    float kk = 1.0 / dot(b, b);
    float kx = kk * dot(a, b);
    float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
    float kz = kk * dot(d, a);
    float p  = ky - kx * kx;
    float p3 = p * p * p;
    float q  = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
    float h  = q * q + 4.0 * p3;
    if (h >= 0.0)
    {
        h = sqrt(h);
        vec2 x  = (vec2(h, -h) - q) / 2.0;
        vec2 uv = sign(x) * pow(abs(x), vec2(1.0 / 3.0));
        float t = clamp(uv.x + uv.y - kx, 0.0, 1.0);
        return qbDot2(d + (c + b * t) * t);
    }
    float z = sqrt(-p);
    float v = acos(q / (p * z * 2.0)) / 3.0;
    float m = cos(v);
    float n = sin(v) * 1.732050808;
    vec3  t = clamp(vec3(m + m, -n - m, n - m) * z - kx, 0.0, 1.0);
    return min(qbDot2(d + (c + b * t.x) * t.x), qbDot2(d + (c + b * t.y) * t.y));
}

void segLine(vec2 p, vec2 a, vec2 b, inout float d2, inout int w)
{
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    vec2 e = pa - ba * h;
    d2 = min(d2, dot(e, e));
    float cr = ba.x * pa.y - ba.y * pa.x;
    if (a.y <= p.y) { if (b.y > p.y && cr > 0.0) w++; }
    else            { if (b.y <= p.y && cr < 0.0) w--; }
}

void segQuad(vec2 p, vec2 A, vec2 B, vec2 C, inout float d2, inout int w)
{
    d2 = min(d2, udBezier2(p, A, B, C));
    float y0 = min(A.y, C.y), y1 = max(A.y, C.y);
    if (p.y >= y0 && p.y < y1)
    {
        float qa = A.y - 2.0 * B.y + C.y, qb = 2.0 * (B.y - A.y), qc = A.y - p.y;
        float t;
        if (abs(qa) < 1e-6) t = -qc / qb;
        else
        {
            float disc = sqrt(max(qb * qb - 4.0 * qa * qc, 0.0));
            t = (-qb + disc) / (2.0 * qa);
            if (t < 0.0 || t > 1.0) t = (-qb - disc) / (2.0 * qa);
        }
        float x = mix(mix(A.x, B.x, t), mix(B.x, C.x, t), t);
        if (x > p.x) w += (C.y > A.y) ? 1 : -1;
    }
}
"""


def glyph_glsl(name, label, lines, quads):
    out = [f"// {label}"]
    if lines:
        out.append(f"const vec4 {name}_L[{len(lines)}] = vec4[{len(lines)}](")
        out.append(",\n".join(f"    vec4({f4(a[0])}, {f4(a[1])}, {f4(b[0])}, {f4(b[1])})" for a, b in lines) + ");")
    if quads:
        n = 3 * len(quads)
        out.append(f"const vec2 {name}_Q[{n}] = vec2[{n}](")
        out.append(",\n".join(f"    {v2(A)}, {v2(B)}, {v2(C)}" for A, B, C in quads) + ");")
    out.append(f"float {name}(vec2 p)\n{{\n    float d2 = 1e20; int w = 0;")
    if lines:
        out.append(f"    for (int i = 0; i < {len(lines)}; i++) segLine(p, {name}_L[i].xy, {name}_L[i].zw, d2, w);")
    if quads:
        out.append(f"    for (int i = 0; i < {len(quads)}; i++) segQuad(p, {name}_Q[3 * i], {name}_Q[3 * i + 1], {name}_Q[3 * i + 2], d2, w);")
    out.append("    return (w != 0 ? -1.0 : 1.0) * sqrt(d2);\n}")
    return "\n".join(out)


def shape_library(names):
    path = next((p for p in SHAPES_CANDIDATES if os.path.exists(p)), None)
    if not path:
        die("shapes.glsl not found (glsl-sdf-shapes skill)")
    src = open(path).read()
    blocks = dict(re.findall(r"// @shape (\w+)\n(.*?)// @end", src, re.S))
    out = []
    for n in names:
        if n not in blocks:
            die(f'shape "{n}" is not in the library ({", ".join(sorted(blocks))})')
        out.append(blocks[n].rstrip())
    return "\n\n".join(out) if out else "// (no shapes)"


def parse_color(c):
    named = {"black": "#000000", "white": "#FFFFFF", "cream": "#F2EEE6", "lightgrey": "#D9D9DE",
             "darkgrey": "#1E1E22", "navy": "#0B1430", "blue": "#2747A8", "lightblue": "#BFD9F2",
             "purple": "#6B40A1", "lilac": "#C9B6E8", "lavender": "#C9B6E8", "pink": "#F2A7C3",
             "hotpink": "#E0408A", "red": "#B3202A", "orange": "#E8772E", "yellow": "#F2D04A",
             "green": "#2E8B57", "mint": "#BDECD6", "teal": "#1F7A7A"}
    key = c.replace(" ", "").lower()
    hexc = named.get(key, c)
    if not re.fullmatch(r"#?[0-9A-Fa-f]{6}", hexc):
        die(f'unknown color "{c}": use a hex code like #B5A0D0')
    hexc = hexc.lstrip("#").upper()
    rgb = [int(hexc[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return "#" + hexc, f"vec3({rgb[0]:.3f}, {rgb[1]:.3f}, {rgb[2]:.3f})"


def image_data_uri(path):
    """The picture as a data: URI for the preview page. Browsers cannot show HEIC and big
    photos make heavy pages, so on macOS those go through `sips` (JPEG, 2048 px max)."""
    import base64, mimetypes, shutil, subprocess, tempfile
    ext = os.path.splitext(path)[1].lower()
    web = ext in (".jpg", ".jpeg", ".png", ".webp", ".gif")
    if (not web or os.path.getsize(path) > 3_000_000) and shutil.which("sips"):
        tmp = os.path.join(tempfile.mkdtemp(), "image.jpg")
        r = subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "85", "-Z", "2048", path, "--out", tmp],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if r.returncode == 0 and os.path.exists(tmp):
            path, web = tmp, True
    if not web:
        die(f"cannot use {os.path.basename(path)} in a browser: convert it to JPEG or PNG")
    mt = mimetypes.guess_type(path)[0] or "image/jpeg"
    return f"data:{mt};base64," + base64.b64encode(open(path, "rb").read()).decode()


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--font", help="path to a .ttf/.otf file")
    src.add_argument("--google", help='Google Fonts family name, e.g. "DM Serif Display"')
    src.add_argument("--vibe", help="a vibe from vibes.json (font + settings), e.g. romantic, cloud")
    ap.add_argument("--style", default=None, help="static style when downloading (Regular, Bold, Italic…)")
    ap.add_argument("--axis", action="append", default=[], help="variable font axis, e.g. wght=700")
    ap.add_argument("--text", required=True, help='text; "/" starts a new line')
    ap.add_argument("--mark", action="append", default=[], help="CHAR[@WORD|:N|:all]=SHAPE[*SCALE]")
    ap.add_argument("--replace", action="append", default=[],
                    help="replace the WHOLE letter by a shape, same syntax as --mark (e.g. o@love=fullmoon)")
    ap.add_argument("--bg", default=None, help="background color: hex or name (default black, or the vibe's)")
    ap.add_argument("--image", help="background picture (png/jpg); the glass letters sit on it and refract it")
    ap.add_argument("--photo-in-glass", type=float, default=0.35,
                    help="image mode: how much of the picture the letters show (0 = only liquid, 1 = clear glass)")
    ap.add_argument("--html", action="store_true", help="(default) a live preview NAME.html is always written")
    ap.add_argument("--look", choices=["surface", "objects"], default="surface",
                    help="surface: one liquid glass surface cut into the text (default); objects: each letter a 3D glass object")
    ap.add_argument("--palette", choices=["pastel", "liquid"], default=None,
                    help="surface look: soft pastel glass or the original deep iridescent liquid glass "
                         "(default: liquid on a dark background, pastel on a light one or on an image)")
    ap.add_argument("--tint", default=None, help="pastel palette: main hue of the glass (default: from the background)")
    ap.add_argument("--puff", type=float, default=None, help="glass rounding radius in glyph units (default: from the stem width)")
    ap.add_argument("--tracking", type=float, default=None, help="extra letter spacing, in em")
    ap.add_argument("--line-height", type=float, default=0.9, help="baseline to baseline, in multiples of the font line height")
    ap.add_argument("--simplify", type=float, default=None,
                    help="drop contours (specks, texture holes) smaller than this share of the cap height squared, "
                         "e.g. 0.002; makes heavy decorative fonts faster")
    ap.add_argument("--out", required=True, help="output .glsl file (never overwritten)")
    a = ap.parse_args()

    if os.path.exists(a.out):
        die(f"{a.out} already exists")
    html_out = os.path.splitext(a.out)[0] + ".html"
    if os.path.exists(html_out):
        die(f"{html_out} already exists")
    if a.image and not os.path.isfile(a.image):
        die(f"image not found: {a.image}")
    vibe_name = None
    if a.vibe:                                   # a vibe fills every setting the user did not give
        vibes = json.load(open(VIBES))["vibes"]
        key = a.vibe.strip().lower()
        name = next((n for n, v in vibes.items() if key == n or key in v.get("aliases", [])), None)
        if not name:
            die(f'unknown vibe "{a.vibe}" ({", ".join(sorted(vibes))})')
        v = vibes[name]; vibe_name = name
        a.google = v["google"]
        a.style = a.style or v.get("style")
        if not a.axis:
            a.axis = [f"{k}={x}" for k, x in v.get("axes", {}).items()]
        for opt in ("bg", "puff", "tracking", "simplify"):
            if getattr(a, opt) is None and opt in v:
                setattr(a, opt, v[opt])
    a.style = a.style or "Regular"
    a.bg = a.bg or "#000000"
    a.tracking = a.tracking or 0.0
    a.simplify = a.simplify or 0.0
    lic = None
    path = a.font
    if a.google:
        path, lic = fetch_google_font(a.google, a.style)
    axes = {}
    for s in a.axis:
        k, v = s.split("="); axes[k] = float(v)
    font = load_font(path, axes)
    gs = font.getGlyphSet()
    cmap = font.getBestCmap()
    upm = font["head"].unitsPerEm
    cap, xh, asc, desc = font_metrics(font, gs, cmap)
    scale = 2.0 / cap                                  # capital letters are 2 glyph units tall
    kern = Kerning(font)
    family = font["name"].getDebugName(1) or os.path.basename(path)
    style = font["name"].getDebugName(2) or ""
    if axes:                                     # instanced variable font: name the instance
        style = " ".join(f"{k}={v:g}" for k, v in axes.items())

    # ---- text and mark targets
    lines_txt = [l.strip() for l in a.text.split("/")]
    chars = [(li, ci, ch) for li, l in enumerate(lines_txt) for ci, ch in enumerate(l)]
    marks = [parse_mark(s) for s in a.mark] + [dict(parse_mark(s), whole=True) for s in a.replace]
    target = {}                                        # (line, index) -> mark spec
    for mk in marks:
        hits = []
        if mk["word"]:
            for li, l in enumerate(lines_txt):
                for m in re.finditer(r"\S+", l):
                    if m.group().strip(".,;:!?'\"()") == mk["word"]:
                        hits += [(li, m.start() + k) for k, c in enumerate(m.group()) if c == mk["ch"]]
        else:
            occ = [(li, ci) for li, ci, ch in chars if ch == mk["ch"]]
            if mk["occ"] in (None, "all"):
                hits = occ
            elif int(mk["occ"]) <= len(occ):
                hits = [occ[int(mk["occ"]) - 1]]
        if not hits:
            die(f'mark target "{mk["ch"]}" not found in the text')
        for h in hits:
            target[h] = mk

    # ---- glyph variants
    eps = 0.0015
    variants, var_order = {}, []
    def variant(ch, gname, drop):
        key = (gname, tuple(drop))
        if key not in variants:
            cs = contours_of(gs, gname)
            keep = [c for k, c in enumerate(cs) if k not in drop and area(c) >= a.simplify * cap * cap]
            L, Q = monotone_segments(keep, scale, eps)
            bb = union_bbox([bbox(c) for c in keep]) if keep else None
            bb = [v * scale for v in bb] if bb else None
            name = f"glyph{len(var_order)}"
            label = f"'{ch}'" + (" without its mark" if drop else "") + f"  ({gname}: {len(L)} lines, {len(Q)} curves)"
            variants[key] = {"name": name, "L": L, "Q": Q, "bb": bb, "label": label}
            var_order.append(key)
        return variants[key]

    # ---- layout
    line_height = (asc - desc) * scale * a.line_height
    placed, mark_calls, shapes_used = [], [], []
    for li, l in enumerate(lines_txt):
        x, prev, row = 0.0, None, []
        for ci, ch in enumerate(l):
            g = cmap.get(ord(ch))
            if g is None:
                die(f'"{ch}" is not in the font {family}')
            x += kern(prev, g) * scale
            mk = target.get((li, ci))
            if mk and mk.get("whole"):                 # the whole letter becomes the shape, same place and size
                cs = contours_of(gs, g)
                if not cs:
                    die(f'"{ch}" has no outline to replace')
                b = union_bbox([bbox(c) for c in cs])
                s = max(b[2] - b[0], b[3] - b[1]) / 2 * scale * mk["scale"]
                cx, cy = (b[0] + b[2]) / 2 * scale + x, (b[1] + b[3]) / 2 * scale
                if mk["shape"] not in shapes_used:
                    shapes_used.append(mk["shape"])
                row.append(("mark", "sdf" + mk["shape"].capitalize(), cx, cy, s, ch))
                v = None
            elif mk:
                cs = contours_of(gs, g)
                idx = split_marks(ch, cs, xh, cap)
                base = [k for k in range(len(cs)) if k not in idx]
                v = variant(ch, g, idx) if base else None
                base_bb = union_bbox([bbox(cs[k]) for k in base]) if base else None
                for grp in mark_groups(cs, idx):
                    b = grp["bb"]
                    h0 = max(b[2] - b[0], b[3] - b[1]) / 2 * scale
                    gap = 1e9
                    if base_bb:
                        gap = max(b[1] - base_bb[3], base_bb[1] - b[3], 0.0) * scale
                    s1 = min(1.6 * h0, h0 + 0.6 * gap)
                    s = s1 * mk["scale"]
                    cx, cy = (b[0] + b[2]) / 2 * scale + x, (b[1] + b[3]) / 2 * scale
                    if base_bb and s > s1:            # a bigger shape moves away from its letter, keeping the gap
                        away = 1.0 if (b[1] + b[3]) >= (base_bb[1] + base_bb[3]) else -1.0
                        cy += away * (s - s1)
                    shp = "sdf" + mk["shape"].capitalize()
                    if mk["shape"] not in shapes_used:
                        shapes_used.append(mk["shape"])
                    row.append(("mark", shp, cx, cy, s, ch))
            else:
                v = variant(ch, g, []) if contours_of(gs, g) else None
            if v:
                row.append(("glyph", v, x, ch))
            x += (font["hmtx"][g][0] + a.tracking * upm) * scale
            prev = g
        placed.append(row)

    # ink bounds per line, then centre lines horizontally and the block vertically
    line_info = []
    for li, row in enumerate(placed):
        xs0, xs1, ys0, ys1 = [], [], [], []
        for it in row:
            if it[0] == "glyph" and it[1]["bb"]:
                bb = it[1]["bb"]; xs0.append(it[2] + bb[0]); xs1.append(it[2] + bb[2]); ys0.append(bb[1]); ys1.append(bb[3])
            elif it[0] == "mark":
                xs0.append(it[2] - it[4]); xs1.append(it[2] + it[4]); ys0.append(it[3] - it[4]); ys1.append(it[3] + it[4])
        if not xs0:
            die("a line of the text is empty")
        line_info.append({"x0": min(xs0), "x1": max(xs1), "y0": min(ys0), "y1": max(ys1)})
    base_y = [-li * line_height for li in range(len(placed))]
    top = max(base_y[i] + line_info[i]["y1"] for i in range(len(placed)))
    bot = min(base_y[i] + line_info[i]["y0"] for i in range(len(placed)))
    shift_y = -(top + bot) / 2
    text_w = max(li["x1"] - li["x0"] for li in line_info)
    text_h = top - bot

    # ---- emit sdfText
    body = []
    for li, row in enumerate(placed):
        inf = line_info[li]
        sx = -(inf["x0"] + inf["x1"]) / 2
        by = base_y[li] + shift_y
        cx, hx = (inf["x0"] + inf["x1"]) / 2 + sx, (inf["x1"] - inf["x0"]) / 2
        cy, hy = (inf["y0"] + inf["y1"]) / 2, (inf["y1"] - inf["y0"]) / 2
        body.append(f'\n    // Line {li + 1}: "{lines_txt[li]}"')
        body.append(f"    q = p - vec2({f4(sx)}, {f4(by)});")
        body.append(f"    if (sdBox(q - vec2({f4(cx - sx)}, {f4(cy)}), vec2({f4(hx + 0.05)}, {f4(hy + 0.05)})) < min(d, dM))\n    {{")
        for it in row:
            if it[0] == "glyph":
                v, gx = it[1], it[2]
                bb = v["bb"]
                body.append(f"        GLYPH({v['name']}, {f4(gx)}, {f4((bb[0] + bb[2]) / 2)}, {f4((bb[1] + bb[3]) / 2)}, "
                            f"{f4((bb[2] - bb[0]) / 2 + 0.02)}, {f4((bb[3] - bb[1]) / 2 + 0.02)})   // {it[3]}")
            else:
                _, shp, mx, my, s, ch = it
                body.append(f"        MARK({shp}, {f4(mx)}, {f4(my)}, {f4(s)})   // mark of '{ch}'")
        body.append("    }")
    text_block = [GLYPH_HELPERS]
    for key in var_order:
        v = variants[key]
        text_block.append(glyph_glsl(v["name"], v["label"], v["L"], v["Q"]))
    text_block.append("""// Glyphs go into d (puffy glass), shapes replacing marks into dM (rounded slab).
// A glyph is evaluated only if its box is closer than the best distance so far (exact culling).
#define GLYPH(fn, x, cx, cy, hx, hy) { vec2 g = q - vec2(x, 0.0); if (sdBox(g - vec2(cx, cy), vec2(hx, hy)) < d) d = min(d, fn(g)); }
#define MARK(fn, x, y, s) { vec2 g = q - vec2(x, y); if (sdBox(g, vec2((s) + 0.05)) < dM) dM = min(dM, fn(g / (s)) * (s)); }

vec2 sdfText(vec2 p)
{
    float d = 1e10, dM = 1e10;
    vec2 q;""" + "\n".join(body) + "\n    return vec2(d, dM);\n}")

    # ---- glass puffiness from the stem width
    puff = a.puff
    stem = None
    if puff is None:
        for ch in "lIinH":
            g = cmap.get(ord(ch))
            if not g:
                continue
            L, Q = monotone_segments(contours_of(gs, g), scale, eps)
            w = scan_widths(L, Q, xh * scale * 0.5)
            if w:
                stem = min(w); break
        puff = 0.9 * (stem / 2 if stem else 0.12)
        puff = max(0.05, min(puff, 0.3))

    # ---- header + template
    hex_bg, vec_bg = parse_color(a.bg)
    if a.palette is None:                        # dark background: the deep iridescent liquid; light: pastel
        r0, g0, b0 = [int(hex_bg[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        a.palette = "liquid" if (not a.image and 0.2126 * r0 + 0.7152 * g0 + 0.0722 * b0 < 0.35) else "pastel"
    mk_lines = []
    for mk in marks:
        where = f' in "{mk["word"]}"' if mk["word"] else (f" #{mk['occ']}" if mk["occ"] not in (None, "all") else " (all)")
        mk_lines.append(("whole letter " if mk.get("whole") else "mark of ") + f"'{mk['ch']}'{where} -> {mk['shape']}" + (f" x{mk['scale']}" if mk["scale"] != 1 else ""))
    header = [
        f'//  "{a.text.replace("/", " / ")}" in liquid glass  (/liquid-glass-skill, lettering mode)',
        "//",
        f"//  Text        : {' '.join(lines_txt)}",
        f"//  Lines       : {len(lines_txt)}  ->  " + " / ".join(f'"{l}"' for l in lines_txt),
        "//  Mark edits  : " + ("\n//                ".join(mk_lines) if mk_lines else "none"),
        f"//  Font        : {family} {style}" + (f" (Google Fonts, {lic.upper()} licence)" if lic else "")
        + (f", vibe \"{vibe_name}\"" if vibe_name else ""),
        "//  Inside      : the liquid glass surface, visible only through the letters",
        (f"//  Background  : the image in iChannel0 ({os.path.basename(a.image)}), refracted by the letters"
         if a.image else f"//  Background  : solid {hex_bg} (change bgColor below)"),
        f"//  Layout      : ink W = {text_w:.2f}, H = {text_h:.2f} glyph units (cap height = 2)",
        (f"//  Look        : one liquid glass surface cut into the text, {a.palette} palette, rim width {puff:.3f}"
         if a.look == "surface" else
        f"//  Profile     : puffy glass, PUFF = {puff:.3f}; rounded slabs for the shapes; text fixed, liquid moving"
        + (f"; specks below {a.simplify:g} cap² dropped" if a.simplify else "")),
        "//  Generated by glsl-sdf-typography/scripts/font_to_glsl.py",
    ]
    tpl = open(TEMPLATE_SURFACE if a.look == "surface" else TEMPLATE).read()
    if a.tint:
        tint_vec = parse_color(a.tint)[1]
    else:                                        # the background's hue, kept colorful
        r, g, b = [int(hex_bg[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        mx, mn = max(r, g, b), min(r, g, b)
        if mx - mn < 0.08:                       # grey, white or black background: a soft lilac
            r, g, b = 0.79, 0.71, 0.91
        else:                                    # same hue, pastel strength
            sat = 0.35 / (mx - mn)
            r, g, b = [min(1.0, 0.85 + (c - (r + g + b) / 3) * sat) for c in (r, g, b)]
        tint_vec = f"vec3({r:.3f}, {g:.3f}, {b:.3f})"
    out = (tpl.replace("{{HEADER}}", "\n".join(header))
              .replace("{{BG_COLOR}}", vec_bg)
              .replace("{{BG_IMAGE}}", "1" if a.image else "0")
              .replace("{{PHOTO_IN_GLASS}}", f"{max(0.0, min(a.photo_in_glass, 1.0)):.2f}")
              .replace("{{SHADOW}}", ("0.40" if a.image else "0.25") if a.look == "objects" else ("0.30" if a.image else "0.18"))
              .replace("{{PASTEL}}", "1" if a.palette == "pastel" else "0")
              .replace("{{TINT}}", tint_vec)
              .replace("{{PUFF}}", f"{puff:.4f}")
              .replace("{{TEXT_W}}", f"{text_w:.4f}")
              .replace("{{TEXT_H}}", f"{text_h:.4f}")
              .replace("{{SHAPES}}", shape_library(shapes_used))
              .replace("{{TEXT_BLOCK}}", "\n\n".join(text_block)))
    with open(a.out, "x") as f:
        f.write(out)
    if True:  # the live preview page is always written
        img = ""
        if a.image:
            img = image_data_uri(a.image)
        file_stem = os.path.splitext(os.path.basename(a.out))[0]
        page = (open(PREVIEW).read()
                .replace("{{TITLE}}", " ".join(lines_txt).replace("&", "&amp;").replace("<", "&lt;"))
                .replace("{{FILE_STEM}}", file_stem)
                .replace("{{HINT}}", ("Drop an image here to change the background · " if a.image else "") + "Space: pause · S: save a PNG")
                .replace("{{SHADER_JSON}}", json.dumps(out).replace("</", "<\\/"))
                .replace("{{IMAGE_JSON}}", json.dumps(img)))
        with open(html_out, "x") as f:
            f.write(page)

    segs = sum(len(variants[k]["L"]) + len(variants[k]["Q"]) for k in var_order)
    print(json.dumps({
        "out": a.out, "font": f"{family} {style}".strip(), "font_file": path, "licence": lic,
        "lines": lines_txt, "text_w": round(text_w, 3), "text_h": round(text_h, 3),
        "puff": round(puff, 4), "stem_width": round(stem, 4) if stem else None,
        "glyph_functions": len(var_order), "segments": segs,
        "marks": [{"char": it[5], "shape": it[1], "x": round(it[2], 3), "y": round(it[3], 3), "size": round(it[4], 3)}
                  for row in placed for it in row if it[0] == "mark"],
        "background": os.path.abspath(a.image) if a.image else hex_bg,
        "warning": (f"{segs} segments is heavy: browsers may fail to run it; use --simplify 0.008 (or higher) "
                    "or a shorter text") if segs > 4000 else None,
        "vibe": vibe_name, "preview_html": os.path.abspath(html_out),
    }, indent=2))


if __name__ == "__main__":
    main()
