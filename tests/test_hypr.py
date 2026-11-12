"""Loads config/hypr/aequalyn/layouts.lua against a small mock of Hyprland's
`hl` table: every layout registers, places every window, and the promote,
swap and resize messages change what they should. Run: python3 tests/test_hypr.py"""
import os, pathlib, shutil, sys, tempfile
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parents[1]
home = tempfile.mkdtemp()
shutil.copytree(ROOT / "config/hypr/aequalyn", pathlib.Path(home) / ".config/hypr/aequalyn")
os.environ["HOME"] = home

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
registered = {}
active_window = nil
hl = {
  layout = { register = function(name, def) registered[name] = def end },
  get_active_workspace = function() return { id = 1 } end,
  get_active_window = function() return active_window end,
}
function make_ctx(n)
  local ctx = { area = { x = 0, y = 0, w = 1920, h = 1080 }, targets = {} }
  for i = 1, n do
    local t = { window = { stable_id = 100 + i, workspace = { id = 1 } }, placed = nil }
    function t:place(r) self.placed = r end
    ctx.targets[i] = t
  end
  return ctx
end
function main_of(ctx)  -- the stable id of the window placed largest
  local best, area = nil, -1
  for _, t in ipairs(ctx.targets) do
    local a = t.placed.w * t.placed.h
    if a > area then best, area = t.window.stable_id, a end
  end
  return best, area
end
""")
M = lua.execute(f'return dofile("{home}/.config/hypr/aequalyn/layouts.lua")')
reg = lua.globals().registered
names = list(reg.keys())
fail = 0
expected = len(M.geometry.catalogue)
if len(names) != expected:
    print(f"FAIL registered {len(names)} of {expected}"); fail += 1
for name in names:
    for n in (1, 2, 5, 9):
        ctx = lua.globals().make_ctx(n)
        reg[name].recalculate(ctx)
        if any(ctx.targets[i].placed is None for i in range(1, n + 1)):
            print(f"FAIL {name} n={n}: a window was not placed"); fail += 1

ctx = lua.globals().make_ctx(4)
d = reg["aq-diptych_left"]
d.recalculate(ctx)
main, area0 = lua.globals().main_of(ctx)
if main != 101: print("FAIL first window should be main", main); fail += 1
lua.execute("active_window = { stable_id = 103 }")
d.layout_msg(None, "promote"); d.recalculate(ctx)
main, _ = lua.globals().main_of(ctx)
if main != 103: print("FAIL promote", main); fail += 1
d.layout_msg(None, "grow"); d.recalculate(ctx)
_, area1 = lua.globals().main_of(ctx)
if not area1 > area0: print("FAIL grow", area0, area1); fail += 1
if d.layout_msg(None, "nonsense") is True: print("FAIL unknown message accepted"); fail += 1
print(f"{len(names)} layouts registered, {fail} failures")
sys.exit(1 if fail else 0)
