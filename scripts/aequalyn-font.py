#!/usr/bin/env python3
"""Builds the Aequalyn fonts from the lowercase of the original Aequalyn-Regular.ttf.

  scripts/aequalyn-font.py <original.ttf> <output dir>

The original's letters are copied point for point. Capitals, digits, punctuation and
accents are drawn here in the same way: an 80 unit stroke, plain circles and straight
stems. Aequalyn Mono holds the same glyphs, centred in one fixed width, for terminals.
Needs fonttools and skia-pathops.
"""
import math, sys, unicodedata
from pathlib import Path
import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

W, H, X, SB = 80, 639, 424, 42          # stroke, capital height, x height, side bearing
A, Z = W / 2, H - W / 2                 # the centre lines of the bottom and top strokes
VERSION = "0.2.0"


class G:
    """A glyph drawn as centre lines."""
    def __init__(self): self.p = pathops.Path()

    def _stroke(self, draw, cap="butt", join="miter", w=W):
        s = pathops.Path(); draw(s.getPen())
        s.stroke(w, getattr(pathops.LineCap, cap.upper() + "_CAP"), getattr(pathops.LineJoin, join.upper() + "_JOIN"), 10)
        s.convertConicsToQuads()
        self.add(s); return self

    def add(self, q): self.p = pathops.op(self.p, q, pathops.PathOp.UNION)

    def line(self, *pts, **k):
        closed = k.pop("closed", False)
        def d(pen):
            pen.moveTo(pts[0])
            for q in pts[1:]: pen.lineTo(q)
            pen.closePath() if closed else pen.endPath()
        return self._stroke(d, **k)

    def path(self, *parts, **k):
        """("L", pt) and ("A", cx, cy, rx, ry, from, to) in degrees, one after the other."""
        closed = k.pop("closed", False)
        def d(pen):
            first = True
            for q in parts:
                if q[0] == "L":
                    pen.moveTo(q[1]) if first else pen.lineTo(q[1])
                else:
                    _, cx, cy, rx, ry, a0, a1 = q
                    n = max(1, math.ceil(abs(a1 - a0) / 45)); st = math.radians((a1 - a0) / n); t = math.radians(a0)
                    f = 4 / 3 * math.tan(st / 4)
                    at = lambda t: (cx + rx * math.cos(t), cy + ry * math.sin(t))
                    pen.moveTo(at(t)) if first else pen.lineTo(at(t))
                    for _ in range(n):
                        (x0, y0), (x1, y1) = at(t), at(t + st)
                        pen.curveTo((x0 - f * rx * math.sin(t), y0 + f * ry * math.cos(t)),
                                    (x1 + f * rx * math.sin(t + st), y1 - f * ry * math.cos(t + st)), (x1, y1))
                        t += st
                first = False
            pen.closePath() if closed else pen.endPath()
        return self._stroke(d, **k)

    def arc(self, *a, **k): return self.path(("A",) + a, **k)
    def oval(self, cx, cy, rx, ry, **k): return self.arc(cx, cy, rx, ry, 0, 360, closed=True, **k)

    def dot(self, x, y, r=49.5):
        q = pathops.Path(); pen = q.getPen(); f = 0.5523 * r
        pen.moveTo((x + r, y)); pen.curveTo((x + r, y + f), (x + f, y + r), (x, y + r)); pen.curveTo((x - f, y + r), (x - r, y + f), (x - r, y))
        pen.curveTo((x - r, y - f), (x - f, y - r), (x, y - r)); pen.curveTo((x + f, y - r), (x + r, y - f), (x + r, y)); pen.closePath()
        self.add(q); return self

    def clip(self, y0=0, y1=H, x0=-2000, x1=3000):
        q = pathops.Path(); pen = q.getPen()
        pen.moveTo((x0, y0)); pen.lineTo((x1, y0)); pen.lineTo((x1, y1)); pen.lineTo((x0, y1)); pen.closePath()
        self.p = pathops.op(self.p, q, pathops.PathOp.INTERSECTION); return self


def capitals():
    S, M, O = 82, 330, (332, H / 2, 250, 279.5)      # stem, middle bar, the big round
    g = {}
    g["A"] = G().line((20, -60), (282, 690), (544, -60)).clip().line((110, 190), (454, 190))
    g["B"] = G().path(("L", (S, A)), ("L", (S, Z)), ("A", 250, 467, 132, 132, 90, -90), ("L", (S, 335))).path(
        ("L", (S, 335)), ("A", 262, 187.5, 147.5, 147.5, 90, -90), ("L", (S, A)), ("L", (S, 200)))
    g["C"] = G().arc(*O, 46, 314)
    g["D"] = G().path(("L", (S, A)), ("L", (S, Z)), ("A", 230, H / 2, 260, 279.5, 90, -90), closed=True)
    g["E"] = G().line((450, Z), (S, Z), (S, A), (450, A)).line((S, M), (410, M))
    g["F"] = G().line((430, Z), (S, Z), (S, 0)).line((S, M), (390, M))
    g["G"] = G().path(("A", *O, 46, 360), ("L", (345, H / 2)))
    g["H"] = G().line((S, 0), (S, H)).line((464, 0), (464, H)).line((S, M), (464, M))
    g["I"] = G().line((S, 0), (S, H))
    g["J"] = G().path(("L", (350, H)), ("A", 200, 190, 150, 150, 0, -165))
    g["K"] = G().line((S, 0), (S, H)).line((70, 195), (500, 705)).line((205, 365), (498, -60)).clip()
    g["L"] = G().line((S, H), (S, A), (410, A))
    g["M"] = G().line((S, 0), (S, H)).line((540, 0), (540, H)).line((40, 712), (311, 190), (582, 712)).clip(x0=SB, x1=580)
    g["N"] = G().line((S, 0), (S, H)).line((482, 0), (482, H)).line((30, 715), (534, -76)).clip(x0=SB, x1=522)
    g["O"] = G().oval(*O)
    g["P"] = G().path(("L", (S, 0)), ("L", (S, Z)), ("A", 265, 449.5, 149.5, 149.5, 90, -90), ("L", (S, 300)))
    g["Q"] = G().oval(*O).line((350, 215), (560, -15))
    g["R"] = G().path(("L", (S, 0)), ("L", (S, Z)), ("A", 265, 449.5, 149.5, 149.5, 90, -90), ("L", (S, 300))).line((235, 320), (450, -50)).clip()
    g["S"] = G().path(("A", 240, 459.25, 158, 139.75, 28, 270), ("A", 240, 179.75, 158, 139.75, 90, -152))
    g["T"] = G().line((SB, Z), (502, Z)).line((272, 0), (272, Z))
    g["U"] = G().path(("L", (S, H)), ("A", 277, 235, 195, 195, 180, 360), ("L", (472, H)))
    g["V"] = G().line((20, 700), (277, -52), (534, 700)).clip()
    g["W"] = G().line((30, 715), (182, -40), (326, 560), (470, -40), (622, 715)).clip()
    g["X"] = G().line((28, -70), (502, 709)).line((502, -70), (28, 709)).clip()
    g["Y"] = G().line((22, 705), (265, 300), (508, 705)).line((265, 0), (265, 310)).clip()
    g["Z"] = G().line((60, Z), (470, Z)).line((440, 680), (84, -41)).clip().line((56, A), (470, A)).clip(x0=SB, x1=480)
    g["Æ"] = G().line((10, -60), (330, 690)).line((150, 190), (400, 190)).line((720, Z), (330, Z)).line((400, H), (400, 0)).line((400, A), (720, A)).line((400, M), (680, M)).clip()
    return g


def digits():
    c, g = 254, {}
    g["0"] = G().oval(c, H / 2, 172, 279.5)
    g["1"] = G().line((300, 0), (300, H)).line((70, 440), (310, 625)).clip(x1=340)
    g["2"] = G().path(("A", c, 439, 160, 160, 165, -38), ("L", (105, 62))).line((82, A), (424, A)).clip(x0=70)
    g["3"] = G().arc(240, 467, 145, 132, 150, -90).arc(240, 187.5, 168, 147.5, 90, -150).line((200, 335), (250, 335))
    g["4"] = G().line((352, 0), (352, H)).line((470, 160), (72, 160)).line((46, 130), (370, 650)).clip(x0=SB)
    g["5"] = G().line((410, Z), (126, Z), (112, 330)).path(("A", 238, 215, 182, 175, 138, -145))
    g["6"] = G().oval(c, 212, 172, 172).path(("A", 350, 260, 266, 339, 100, 188)).clip()
    g["7"] = G().line((70, Z), (440, Z)).line((425, 680), (150, -60)).clip(x1=456)
    g["8"] = G().oval(c, 469, 130, 130).oval(c, 189.5, 168, 149.5)
    g["9"] = G().oval(c, 427, 172, 172).path(("A", 158, 379, 266, 339, 8, -80)).clip()
    return g


def signs():
    g = {}
    b, t = -100, 700
    g['"'] = G().line((82, 427), (82, 619)).line((222, 427), (222, 619))
    g["#"] = G().line((150, 0), (210, H)).line((350, 0), (410, H)).line((50, 215), (490, 215)).line((70, 425), (510, 425)).clip()
    g["$"] = capitals()["S"].line((240, -70), (240, 60)).line((240, 580), (240, 709))
    g["%"] = G().oval(160, 490, 98, 98, w=70).oval(490, 149, 98, 98, w=70).line((130, -20), (520, 659), w=70).clip()
    g["&"] = G().path(("L", (520, 0)), ("L", (150, 440)), ("A", 250, 500, 110, 99, 205, -25), ("L", (130, 260)), ("A", 225, 170, 145, 130, 130, 300), ("L", (470, 300)), join="round").clip()
    g["("] = G().arc(332, 300, 250, 430, 112, 248)
    g[")"] = G().arc(0, 300, 250, 430, 68, -68)
    g["*"] = G().line((190, 370), (190, 639), w=70).line((73, 437), (307, 572), w=70).line((307, 437), (73, 572), w=70)
    g["+"] = G().line((60, 320), (440, 320)).line((250, 130), (250, 510))
    g[";"] = None
    g["<"] = G().line((420, 530), (100, 320), (420, 110))
    g["="] = G().line((60, 230), (440, 230)).line((60, 410), (440, 410))
    g[">"] = G().line((80, 530), (400, 320), (80, 110))
    g["?"] = G().path(("A", 222, 459, 140, 140, 165, -55), ("L", (222, 270)), ("L", (222, 165)), join="round").dot(222, 49.5)
    g["@"] = G().oval(420, 230, 120, 120, w=64).path(("L", (548, 350)), ("L", (548, 190)), ("A", 626, 190, 78, 78, 180, 360), ("L", (704, 250)), ("A", 420, 250, 284, 284, 0, 300), w=64, join="round")
    g["["] = G().line((230, t), (82, t), (82, b), (230, b))
    g["]"] = G().line((60, t), (208, t), (208, b), (60, b))
    g["\\"] = G().line((70, 720), (330, -200)).clip(-130, 650)
    g["^"] = G().line((60, 390), (230, 620), (400, 390))
    g["_"] = G().line((20, -90), (480, -90))
    g["`"] = G().line((80, 640), (190, 510), w=70)
    for ch, f in (("{", 1), ("}", -1)):
        q = lambda x: x if f > 0 else 330 - x
        g[ch] = G().line((q(270), t), (q(165), t), (q(165), 370), (q(82), 300), (q(165), 230), (q(165), b), (q(270), b), join="round")
    g["|"] = G().line((82, -150), (82, 720))
    g["~"] = G().path(("A", 150, 290, 95, 75, 180, 30), ("A", 330, 350, 95, 75, 210, 360), join="round")
    g["–"] = G().line((42, 212), (472, 212)); g["—"] = G().line((42, 212), (772, 212))
    g["…"] = G().dot(92, 49.5).dot(272, 49.5).dot(452, 49.5)
    g["•"] = G().dot(170, 300, 100)
    g["°"] = G().oval(160, 500, 98, 98, w=70)
    g["×"] = G().line((90, 160), (410, 480)).line((410, 160), (90, 480))
    g["÷"] = G().line((60, 320), (440, 320)).dot(250, 490).dot(250, 150)
    g["±"] = G().line((60, 380), (440, 380)).line((250, 200), (250, 560)).line((60, 90), (440, 90))
    g["€"] = G().arc(332, H / 2, 230, 279.5, 46, 314).line((30, 390), (400, 390), w=64).line((30, 250), (400, 250), w=64)
    g["£"] = G().path(("A", 270, 460, 139, 139, 25, 180), ("L", (131, A))).line((50, A), (440, A)).line((50, 300), (330, 300))
    g["←"] = G().line((90, 320), (600, 320)).line((300, 530), (100, 320), (300, 110))
    g["→"] = G().line((60, 320), (570, 320)).line((360, 530), (560, 320), (360, 110))
    return g


def marks():
    """Accents, around x = 0, standing at y = 0."""
    k = 64
    return {
        "́": G().line((-45, 0), (60, 130), w=k), "̀": G().line((45, 0), (-60, 130), w=k),
        "̂": G().line((-115, 5), (0, 115), (115, 5), w=k), "̌": G().line((-115, 125), (0, 15), (115, 125), w=k),
        "̆": G().arc(0, 130, 100, 98, 180, 360, w=k), "̈": G().dot(-95, 60, 45).dot(95, 60, 45),
        "̇": G().dot(0, 60, 45), "̊": G().oval(0, 85, 66, 66, w=54),
        "̃": G().path(("A", -62, 45, 62, 50, 180, 35), ("A", 62, 85, 62, 50, 215, 360), w=k, join="round"),
        "̄": G().line((-120, 60), (120, 60), w=k),
        "̦": G().line((20, -70), (-25, -190), w=k), "̧": G().line((10, -20), (-35, -170), w=k),
    }


def main(src, out):
    old = TTFont(src); gs, cm = old.getGlyphSet(), old.getBestCmap()
    glyphs, width, cmap, box = {}, {}, {}, {}

    def tt(draw, quad=False):
        pen = TTGlyphPen(None); draw(pen if quad else Cu2QuPen(pen, 0.6, reverse_direction=True)); return pen.glyph()

    def name(ch): return "uni%04X" % ord(ch)

    def bounds(gl):
        gl.recalcBounds({}) if hasattr(gl, "recalcBounds") else None
        return gl.xMin, gl.yMin, gl.xMax, gl.yMax

    # the original's own glyphs, untouched
    for code, gn in cm.items():
        ch = chr(code)
        if ch.isupper(): continue
        glyphs[name(ch)] = tt(lambda p: gs[gn].draw(p), True); width[name(ch)] = old["hmtx"][gn][0]; cmap[code] = name(ch)

    def put(ch, g, adv=None):
        g.p.simplify(fix_winding=True)
        bp = g.p.bounds; dx = SB - bp[0]
        if adv: dx = (adv - (bp[2] - bp[0])) / 2 - bp[0]
        glyphs[name(ch)] = tt(lambda p: g.p.draw(TransformPen(p, (1, 0, 0, 1, round(dx), 0))))
        width[name(ch)] = adv or round(bp[2] - bp[0]) + 2 * SB; cmap[ord(ch)] = name(ch)

    for ch, g in capitals().items(): put(ch, g)
    for ch, g in digits().items(): put(ch, g, 508)
    # a terminal needs I, l and 1, and O and 0, told apart
    bars = G().line((S0, Z), (S0 + 300, Z)).line((S0, A), (S0 + 300, A)).line((S0 + 150, 0), (S0 + 150, H))
    zero = G().oval(254, H / 2, 172, 279.5).line((190, 215), (318, 424), w=70)
    only_mono = {}
    for ch, g in (("I", bars), ("0", zero)):
        g.p.simplify(fix_winding=True); only_mono[name(ch)] = tt(lambda p: g.p.draw(p))
    for ch, g in signs().items():
        if g is not None: put(ch, g)

    def _draw(gl, pen, dx, dy):
        co, ends, flags = gl.coordinates, gl.endPtsOfContours, gl.flags
        i = 0
        for e in ends:
            pts = [((co[j][0] + round(dx), co[j][1] + round(dy)), flags[j] & 1) for j in range(i, e + 1)]; i = e + 1
            on = next((j for j, q in enumerate(pts) if q[1]), None)
            if on is None: pen.qCurveTo(*[q[0] for q in pts], None); pen.closePath(); continue
            pts = pts[on:] + pts[:on] + [pts[on]]
            pen.moveTo(pts[0][0]); off = []
            for q, f in pts[1:]:
                if f: (pen.qCurveTo(*off, q) if off else pen.lineTo(q)); off = []
                else: off.append(q)
            pen.closePath()

    u = lambda ch: name(ch)
    comma = glyphs[u(",")]
    pen = TTGlyphPen(None)          # the colon's upper dot over the comma
    _draw(glyphs[u(".")], pen, 36, X - 99); _draw(comma, pen, 0, 0); glyphs[u(";")] = pen.glyph(); width[u(";")] = width[u(",")]; cmap[ord(";")] = u(";")
    # the original's own closing quote, for the other three too
    for ch, n in (("‘", 1), ("“", 2), ("”", 2)):
        pen = TTGlyphPen(None)
        for i in range(n): _draw(glyphs[u("’")], pen, i * 140, 0)
        glyphs[u(ch)] = pen.glyph(); cmap[ord(ch)] = u(ch); width[u(ch)] = width[u("’")] + (n - 1) * 140

    # i and j without their dot, for the accents
    for ch, base in (("ı", "i"), ("ȷ", "j")):
        gl = glyphs[u(base)]; pen = TTGlyphPen(None); st = 0
        for e in gl.endPtsOfContours:
            pts = [tuple(gl.coordinates[j]) for j in range(st, e + 1)]; st = e + 1
            if min(q[1] for q in pts) > X: continue
            pen.moveTo(pts[0]); [pen.lineTo(q) for q in pts[1:]]; pen.closePath()
        glyphs[u(ch)] = pen.glyph(); cmap[ord(ch)] = u(ch); width[u(ch)] = width[u(base)]

    mk = {}
    for m, g in marks().items():
        g.p.simplify(fix_winding=True); mk[m] = tt(lambda p: g.p.draw(p))
    for code in list(range(0xC0, 0x180)) + [0x218, 0x219, 0x21A, 0x21B]:
        d = unicodedata.normalize("NFD", chr(code))
        if len(d) != 2 or d[1] not in mk or ord(d[0]) not in cmap: continue
        base = {"i": "ı", "j": "ȷ"}.get(d[0], d[0]) if d[1] < "̠" else d[0]
        gl = glyphs[u(base)]; x0, y0, x1, y1 = bounds(gl)
        # tall letters keep their accent at their own top; capitals sit a little closer
        dy = 0 if d[1] >= "̠" else y1 + (45 if d[0].isupper() else 70)
        pen = TTGlyphPen(None); _draw(gl, pen, 0, 0); _draw(mk[d[1]], pen, (x0 + x1) / 2, dy)
        glyphs[name(chr(code))] = pen.glyph(); cmap[code] = name(chr(code)); width[name(chr(code))] = width[u(base)]
    width[".notdef"] = 508
    nd = G().line((82, A), (82, Z), (426, Z), (426, A), closed=True); nd.p.simplify(fix_winding=True); glyphs[".notdef"] = tt(lambda p: nd.p.draw(p))
    cmap[0xA0] = u(" ")

    def build(family, file, mono):
        gl, hm = {}, {}
        order = [".notdef"] + sorted(n for n in glyphs if n != ".notdef")
        for n in order:
            g, w = glyphs[n], width[n]
            if mono: g = only_mono.get(n, g)
            if mono:
                if g.numberOfContours:
                    x0, y0, x1, y1 = bounds(g)
                    if x1 - x0 > CELL: continue              # too wide for a cell: another font's
                    pen = TTGlyphPen(None); _draw(g, pen, (CELL - (x1 - x0)) / 2 - x0, 0); g = pen.glyph()
                w = CELL
            gl[n] = g; hm[n] = w
        fb = FontBuilder(1000, isTTF=True); fb.setupGlyphOrder([n for n in order if n in gl])
        fb.setupCharacterMap({c: n for c, n in cmap.items() if n in gl}); fb.setupGlyf(gl)
        fb.setupHorizontalMetrics({n: (w, fb.font["glyf"][n].xMin if gl[n].numberOfContours else 0) for n, w in hm.items()})
        asc, desc = 850, -270
        fb.setupHorizontalHeader(ascent=asc, descent=desc)
        fb.setupNameTable({"copyright": "Copyright 2026 qempexe", "familyName": family, "styleName": "Regular",
                           "uniqueFontIdentifier": f"{family}-{VERSION}", "fullName": family, "psName": family.replace(" ", "") + "-Regular",
                           "version": f"Version {VERSION}"})
        fb.setupOS2(sTypoAscender=asc, sTypoDescender=desc, sTypoLineGap=0, usWinAscent=asc, usWinDescent=-desc, sxHeight=X, sCapHeight=H,
                    fsType=old["OS/2"].fsType, usWeightClass=400, fsSelection=0x40 | 0x80, version=4,
                    xAvgCharWidth=CELL if mono else 450, panose=_panose(mono))
        fb.setupPost(isFixedPitch=1 if mono else 0, underlinePosition=-120, underlineThickness=60)
        fb.font["head"].fontRevision = 0.2
        fb.save(Path(out) / file); print(file, len(gl), "glyphs")

    build("Aequalyn", "Aequalyn-Regular.ttf", False)
    build("Aequalyn Mono", "AequalynMono-Regular.ttf", True)


CELL = 660
S0 = 42


def _panose(mono):
    from fontTools.ttLib.tables.O_S_2f_2 import Panose
    return Panose(bFamilyType=2, bProportion=9 if mono else 0)


if __name__ == "__main__":
    if len(sys.argv) != 3: sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
