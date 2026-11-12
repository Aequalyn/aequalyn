"""Checks every layout in config/hypr/aequalyn/geometry.lua for 1..12 windows:
the right number of rectangles, all inside the screen, none empty, and no two
overlapping (Cascade overlaps on purpose). Run: python3 tests/test_layouts.py"""
import pathlib, sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
G = lua.execute((ROOT / "config/hypr/aequalyn/geometry.lua").read_text())
area = lua.table_from({"x": 0, "y": 0, "w": 2560, "h": 1440})
opts = lua.table_from({"pane": 0.62, "middle": 0.56, "gap": 24})
OVERLAP_OK = {"cascade"}
fail = 0
ids = [G.catalogue[i].id for i in range(1, len(G.catalogue) + 1)]
for lid in ids:
    for n in range(1, 13):
        rects = G[lid](n, area, opts)
        rs = [(rects[i].x, rects[i].y, rects[i].w, rects[i].h) for i in range(1, len(rects) + 1)]
        problems = []
        if len(rs) != n:
            problems.append(f"{len(rs)} rects")
        for (x, y, w, h) in rs:
            if w < 40 or h < 30:
                problems.append(f"tiny {w}x{h}")
            if x < 0 or y < 0 or x + w > 2560 + 0.5 or y + h > 1440 + 0.5:
                problems.append(f"outside {x},{y},{w},{h}")
        if lid not in OVERLAP_OK:
            for i in range(len(rs)):
                for j in range(i + 1, len(rs)):
                    a, b = rs[i], rs[j]
                    if a[0] < b[0] + b[2] - 0.5 and b[0] < a[0] + a[2] - 0.5 and a[1] < b[1] + b[3] - 0.5 and b[1] < a[1] + a[3] - 0.5:
                        problems.append(f"overlap {i+1}/{j+1}")
        if problems:
            fail += 1
            print(f"FAIL {lid} n={n}: {sorted(set(problems))[:4]}")
print(f"{len(ids)} layouts x 12 window counts, {fail} failures")
sys.exit(1 if fail else 0)
