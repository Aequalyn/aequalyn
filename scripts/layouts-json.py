"""Writes config/aequalyn/layouts.json from config/hypr/aequalyn/geometry.lua:
every layout's id, name, group, hint and a picture of it with five windows
(boxes in 0..1, the first one is the main window). The shell's layout picker
and `aequalyn-layout` read this file. Run after changing geometry.lua:
    python3 scripts/layouts-json.py"""
import json, pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
G = lua.execute((ROOT / "config/hypr/aequalyn/geometry.lua").read_text())
W, H = 1600, 900
area = lua.table_from({"x": 0, "y": 0, "w": W, "h": H})
opts = lua.table_from({"pane": 0.62, "middle": 0.56, "gap": 40})

def boxes(rects):
    return [[round(rects[i].x / W, 4), round(rects[i].y / H, 4), round(rects[i].w / W, 4), round(rects[i].h / H, 4)]
            for i in range(1, len(rects) + 1)]

NATIVE_ART = {
    "dwindle":   [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .25, .5], [.75, .5, .25, .25], [.75, .75, .25, .25]],
    "master":    [[0, 0, .55, 1], [.55, 0, .45, .25], [.55, .25, .45, .25], [.55, .5, .45, .25], [.55, .75, .45, .25]],
    "scrolling": [[.18, 0, .42, 1], [.6, 0, .42, 1], [-.26, 0, .42, 1], [1.02, 0, .42, 1], [-.7, 0, .42, 1]],
    "monocle":   [[0, 0, 1, 1], [.03, .04, .94, .92], [.06, .08, .88, .84], [.09, .12, .82, .76], [.12, .16, .76, .68]],
}
out = []
for i in range(1, len(G.catalogue) + 1):
    e = G.catalogue[i]
    out.append({"id": "lua:aq-" + e.id, "key": e.id, "name": e.name, "group": e.group, "hint": e.hint,
                "art": boxes(G[e.id](5, area, opts))})
for i in range(1, len(G.native) + 1):
    e = G.native[i]
    out.append({"id": e.id, "key": e.id, "name": e.name, "group": e.group, "hint": e.hint, "art": NATIVE_ART[e.id]})
dest = ROOT / "config/aequalyn/layouts.json"
dest.write_text(json.dumps(out, indent=1) + "\n")
print(f"{len(out)} layouts -> {dest.relative_to(ROOT)}")
