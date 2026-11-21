"""Offline checks for Floating workspaces.

Covers the two things that broke a live session before:
  * no generated rule may ever ask Hyprland for `layout = "floating"`;
  * the Lua module must be inert when compositor APIs are missing.

Uses the system `lua` interpreter, so it needs no Python Lua bindings.
Run: python3 tests/test_floating.py
"""
import json, os, pathlib, re, shutil, subprocess, sys, tempfile, textwrap

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHELL = pathlib.Path(os.environ.get("AQ_SHELL_SRC", ROOT.parent / "aequalyn-shell"))
CLI = ROOT / "bin/aequalyn-layout"
CATALOGUE = ROOT / "config/aequalyn/layouts.json"
MIGRATION = ROOT / "migrations/20261121-1.sh"
fail = 0


def check(ok, label):
    global fail
    if not ok:
        print("FAIL " + label)
        fail += 1


LUA_TEST = r"""
local path = os.getenv("HOME") .. "/.config/hypr/aequalyn/floating.lua"
local results = {}
local function check(ok, label) results[#results + 1] = (ok and "ok " or "FAIL ") .. label end
local function has(t, name)
  for _, v in ipairs(t or {}) do if v == name then return true end end
  return false
end

windows = {
  { address = "0x1", mapped = true, workspace = { id = 1 }, floating = false, tags = {} },
  { address = "0x2", mapped = true, workspace = { id = 2 }, floating = false, tags = {},
    monitor = { width = 1920, height = 1080, scale = 1, reserved = {0, 0, 0, 0} } },
  { address = "0x3", mapped = true, workspace = { id = 1 }, floating = false, tags = {},
    monitor = { width = 1920, height = 1080, scale = 0.75, reserved = {0, 0, 0, 42} } },
}
local sizes = {}
local function apply(d)
  if not d then return end
  local addr = d.window and d.window:match("address:(.+)") or nil
  for _, w in ipairs(windows) do
    if w.address == addr then
      if d.op == "tag" then
        local name = d.tag:sub(2)
        local found = false
        for i, tag in ipairs(w.tags) do
          if tag == name then
            found = true
            if d.tag:sub(1, 1) == "-" then table.remove(w.tags, i) end
            break
          end
        end
        if not found and d.tag:sub(1, 1) == "+" then w.tags[#w.tags + 1] = name end
      elseif d.op == "float" then
        w.floating = (d.action == "set")
      elseif d.op == "move" then
        local target = d.workspace
        if type(target) == "table" then
          w.workspace = { id = target.id, name = target.name }
        elseif tostring(target) == "special:minimized" then
          w.workspace = { id = "special:minimized", name = "special:minimized", special = true }
        else
          w.workspace = { id = tonumber(target) or target }
        end
      elseif d.op == "resize" then
        sizes[d.window] = { x = d.x, y = d.y }
      end
    end
  end
end

hooks = {}
hl = {
  get_windows = function() return windows end,
  get_active_window = function() return nil end,
  get_active_workspace = function() return { id = 2 } end,
  timer = function(fn) fn() end,
  on = function(name, cb) hooks[name] = cb end,
  dispatch = function(d) apply(d) end,
  dsp = { window = {
    tag = function(o) return { op = "tag", window = o.window, tag = o.tag } end,
    float = function(o) return { op = "float", window = o.window, action = o.action } end,
    move = function(o) return { op = "move", window = o.window, workspace = o.workspace } end,
    resize = function(o) return { op = "resize", window = o.window, x = o.x, y = o.y } end,
  } },
}

local F = assert(dofile(path))
check(type(aequalyn_minimize_active) == "function", "minimize button helper exists")
check(type(aequalyn_maximize_active) == "function", "maximize button helper exists")
check(type(aequalyn_close_active) == "function", "close button helper exists")

-- minimize/restore must leave the workspace and the minimized tag in sync,
-- otherwise a restored window stays in the minimized set and steals the next
-- Super+M from the other windows.
hl.get_active_window = function() return windows[1] end
hl.get_active_workspace = function() return { id = 1 } end
aequalyn_minimize_active()
check(tostring(windows[1].workspace.id) == "special:minimized",
      "minimize moves the active window to the hidden workspace")
check(has(windows[1].tags, "minimized"), "minimize tags the hidden window")
aequalyn_restore_minimized()
check(tostring(windows[1].workspace.id) == "1",
      "restore brings the window back to the workspace it left")
check(not has(windows[1].tags, "minimized"),
      "restore clears the tag so other windows remain manageable")

windows[1].tags[#windows[1].tags + 1] = "minimized"
aequalyn_minimize_active()
aequalyn_restore_minimized()
check(not has(windows[1].tags, "minimized"),
      "a stale tag on a visible window is cleaned up on the next restore")

-- A dock or switcher click only focuses a hidden window. Without a real move
-- back to a normal workspace the special overlay stays active and every other
-- window becomes unreachable. The focus hook must finish the restore.
check(type(hooks["window.active"]) == "function",
      "focus hook is registered to catch dock/switcher restores")
hl.get_active_workspace = function() return { id = 2 } end
hl.get_active_window = function() return windows[1] end
aequalyn_minimize_active()
check(tostring(windows[1].workspace.id) == "special:minimized",
      "window is hidden before the dock activation")
hooks["window.active"](windows[1])
check(tostring(windows[1].workspace.id) == "2",
      "focusing a hidden window restores it to its original workspace")
check(not has(windows[1].tags, "minimized"),
      "focus-driven restore clears the minimized tag")
hl.get_active_window = function() return nil end
windows[1].workspace = { id = 1 }

F.set_ws("1", true)
check(windows[1].floating == true, "Floating workspace floats its windows")
check(has(windows[1].tags, "aq-float-mode"), "floated window is tagged")
check(windows[2].floating == false, "other workspace is untouched")

F.set_ws("1", false)
check(windows[1].floating == false, "leaving Floating unfloats managed windows")
check(not has(windows[1].tags, "aq-float-mode"), "tag removed on leave")

F.set_default(true)
check(windows[2].floating == true, "Floating default floats unmarked workspaces")
check(windows[1].floating == false, "explicit non-Floating workspace beats the default")

F.set_default(false)
check(windows[2].floating == false, "leaving Floating default unfloats managed windows")

-- A new window on Floating starts at half the live logical monitor size, with
-- the titlebar counted inside that rectangle. Other workspaces are untouched.
F.set_ws("1", true)
F.decorations.loaded = true
hooks["window.open"](windows[3])
local half = sizes["address:0x3"]
check(half and half.x == 1280 and half.y == 671,
      "new Floating window is half the logical screen, titlebar included")
hooks["window.open"](windows[3])
check(sizes["address:0x3"] == half,
      "a new window is resized once, not on every window event")
hooks["window.open"](windows[2])
check(sizes["address:0x2"] == nil,
      "windows outside Floating keep the size their app chose")
F.set_ws("1", false)
F.decorations.loaded = false

hl = {}
local ok_load, bare = pcall(dofile, path)
local ok_calls = false
if ok_load then
  ok_calls = pcall(function()
    bare.set_ws("1", true)
    bare.set_default(true)
    bare.load_decorations()
  end)
end
check(ok_load and ok_calls, "module is inert without compositor APIs")

for _, line in ipairs(results) do print(line) end
"""

with tempfile.TemporaryDirectory() as td:
    home = pathlib.Path(td)
    target = home / ".config/hypr/aequalyn/floating.lua"
    target.parent.mkdir(parents=True)
    shutil.copy(ROOT / "config/hypr/aequalyn/floating.lua", target)
    env = dict(os.environ, HOME=str(home), AEQUALYN_NO_FLOAT_DECORATIONS="1")
    out = subprocess.run(["lua"], input=LUA_TEST, text=True, env=env,
                         capture_output=True, check=True).stdout
    for line in out.splitlines():
        if line.startswith("FAIL "):
            print(line)
            fail += 1


def generated_rules(settings):
    td = pathlib.Path(tempfile.mkdtemp())
    conf = td / "aqconf"
    (conf / "aequalyn").mkdir(parents=True)
    (conf / "hypr/aequalyn").mkdir(parents=True)
    shutil.copy(CATALOGUE, conf / "aequalyn/layouts.json")
    (conf / "aequalyn/settings.json").write_text(json.dumps(settings))
    bindir = td / "bin"
    bindir.mkdir()
    jq = shutil.which("jq")
    if jq:
        (bindir / "jq").symlink_to(jq)
    fake = bindir / "hyprctl"
    fake.write_text("#!/bin/sh\nexit 0\n")
    fake.chmod(0o755)
    env = dict(os.environ, XDG_CONFIG_HOME=str(conf),
               PATH=str(bindir) + os.pathsep + os.environ.get("PATH", ""))
    subprocess.run([str(CLI), "apply"], env=env, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    text = (conf / "hypr/aequalyn/workspace-layouts.lua").read_text()
    shutil.rmtree(td, ignore_errors=True)
    return text


rules = generated_rules({"layouts": {"default": "floating",
                                     "workspaces": {"1": "dwindle", "2": "floating"}}})
check('layout = "floating"' not in rules, "generated rules never use floating as a Hyprland layout")
check('set_default(true)' in rules, "generated rules install the Floating default shim")
check('set_ws("1", false)' in rules, "generated rules opt non-Floating workspaces out")
check('set_ws("2", true)' in rules, "generated rules install per-workspace Floating shim")

rules = generated_rules({"layouts": {"default": "dwindle", "workspaces": {"1": "floating"}}})
check('layout = "floating"' not in rules, "per-workspace Floating never emits an invalid rule")
check('set_ws("1", true)' in rules, "per-workspace Floating shim is emitted")
check('set_default' not in rules, "non-Floating default emits no default shim")


# The migration must clean up a stale generated file without needing a reload.
with tempfile.TemporaryDirectory() as td:
    homes = pathlib.Path(td, "homes")
    home = homes / "user"
    rules_path = home / ".config/hypr/aequalyn/workspace-layouts.lua"
    rules_path.parent.mkdir(parents=True)
    (home / ".config/aequalyn").mkdir(parents=True)
    (home / ".config/hypr/keybinds.lua").write_text(
        'hl.bind(M .. " + D", hl.dsp.exec_cmd("qs ipc call launcher toggle"))\n')
    (home / ".config/aequalyn/settings.json").write_text(json.dumps(
        {"layouts": {"default": "dwindle", "workspaces": {"2": "floating"},
                     "cycle": ["dwindle", "mosaic"]}}))
    rules_path.write_text(textwrap.dedent("""\
        -- Written by aequalyn-layout from settings.json (.layouts). Do not edit.
        hl.config({ general = { layout = "floating" } })
        hl.workspace_rule({ workspace = "1", layout = "dwindle" })
        hl.workspace_rule({ workspace = "2", layout = "floating" })
    """))
    env = dict(os.environ, AEQUALYN_MIGRATION_HOMES=str(homes))
    subprocess.run(["bash", str(MIGRATION)], env=env, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    fixed = rules_path.read_text()
    check('layout = "floating"' not in fixed, "migration removes invalid layout names")
    check('set_ws("2", true)' in fixed, "migration keeps chosen Floating workspace")
    check('workspace = "1", layout = "dwindle"' in fixed, "migration keeps other rules")
    check('set_default' not in fixed, "migration adds no Floating default when not chosen")
    state = json.loads((home / ".config/aequalyn/settings.json").read_text())
    check(state["layouts"]["cycle"].count("floating") == 1,
          "migration adds Floating once to an explicit cycle")
    subprocess.run(["bash", str(MIGRATION)], env=env, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    state = json.loads((home / ".config/aequalyn/settings.json").read_text())
    check(state["layouts"]["cycle"].count("floating") == 1,
          "migration is idempotent for the layout cycle")
    keybinds = (home / ".config/hypr/keybinds.lua").read_text()
    check('qs ipc call snap toggle' in keybinds, "migration adds the Super + G key")
    check(keybinds.count('qs ipc call snap toggle') == 1, "migration adds the key once")

def text_of(path):
    return path.read_text() if path.is_file() else ""


check('target: "snap"' in text_of(SHELL / "plugins/snap/Snap.qml"),
      "snap plugin exposes its IPC target")
check('id: "snap"' in text_of(SHELL / "Plugins.js"), "snap plugin is registered")
check('snap:' in text_of(SHELL / "PluginInfo.js"), "snap plugin has settings copy")
settings_qml = text_of(SHELL / "settings/AequalynSettings.qml")
check('"snap"' in settings_qml,
      "snap plugin is enabled by default")
check('property var rawSettings' in settings_qml and
      'Object.assign({}, root.rawSettings || {})' in settings_qml and
      'root.rawSettings = d' in settings_qml,
      "settings saves preserve sections owned by other tools, including per-workspace layouts")
check('qs ipc call snap toggle' in (ROOT / "config/hypr/keybinds.lua").read_text(),
      "Super + G opens the snap flyout")

float_lua = (ROOT / "config/hypr/aequalyn/floating.lua").read_text()
check('resize_on_border' in float_lua and 'extend_border_grab_area' in float_lua,
      "floating windows get drag-to-resize edge hooks")
check('F.setup_resize_hooks()' in float_lua, "resize hooks are installed at load")
check('local sized_on_open = {}' in float_lua and
      'function on_window_open(event)' in float_lua and
      'pcall(hl.on, "window.open", function(w)' in float_lua,
      "new windows are sized when they open on a Floating workspace")
check('function usable_half_size(mon)' in float_lua and
      'w / scale' in float_lua and 'h / scale' in float_lua and
      'usable_w / 2' in float_lua and 'usable_h / 2' in float_lua,
      "half size uses the live monitor resolution, scale and reserved edges")
check('local kind = type(t)' in float_lua and
      'kind ~= "table" and kind ~= "userdata"' in float_lua,
      "monitor fields are read from the compositor's userdata objects")
check('titlebar_height()' in float_lua and
      'plugin:hyprbars:bar_height' in float_lua,
      "the decorated titlebar is included inside the starting half-screen size")
check('function F.setup_drag_snap()' in float_lua and 'F.setup_drag_snap()' in float_lua,
      "compositor tracks the primary button to detect drag-to-top")
check('snap dragTop' in float_lua,
      "drag gesture opens the shell snap picker")
check('snap drop' not in float_lua,
      "releasing the drag leaves the picker open for choices")
check('function window_at_cursor()' in float_lua,
      "drag tracks the window under the pointer, not just the focused one")
check('drag.start_x' in float_lua and 'drag.start_y' in float_lua and
      'dx * dx + dy * dy < 30 * 30' in float_lua,
      "a click on the picker cannot be mistaken for a drag after a snap")
check('hl.timer, register_drag_binds' in float_lua,
      "drag binds are registered after other config binds are cleared")
check('non_consuming = true' in float_lua and 'ignore_mods = true' in float_lua,
      "drag-tracking binds do not consume mouse input")

# Right-aligned bars paint buttons right-to-left, so registration must be the
# reverse of the wanted left-to-right order: red close, yellow maximize, green
# minimize.
registered = re.findall(r'button\("rgb\(([0-9a-f]{6})\)"', float_lua)
check(registered[:3] == ["ff5f57", "febc2e", "28c840"],
      "titlebar buttons register reversed to display green minimize, yellow maximize, red close")
check('button("rgb(28c840)", "_"' in float_lua and
      'button("rgb(febc2e)", "□"' in float_lua,
      "green minimize uses _, yellow maximize uses a square")
check('pcall(hl.on, "window.active", on_window_active)' in float_lua and
      'is_minimized_workspace(w.workspace)' in float_lua,
      "focusing a hidden window triggers a real restore, not just an overlay")
check('minimized_origin[addr] or current_workspace()' in float_lua,
      "focus-driven restore returns a window to its original workspace")

snap_qml = text_of(SHELL / "plugins/snap/Snap.qml")
check('function zoneAt(preset, px, py)' in snap_qml and
      'root.zoneAt(modelData, root.pickX, root.pickY)' in snap_qml,
      "pointer position preselects a zone in the area chooser")
check('Row {' in snap_qml and 'columns: 4' not in snap_qml,
      "all layouts are offered in a single row")
check('Flickable {' not in snap_qml and
      'root.presets.length' in snap_qml and 'Math.max(16,' in snap_qml,
      "all layouts fit in one visible row without scrolling")
check('Math.min(1400, win.width - 32)' in snap_qml,
      "the picker widens so the full row is visible at once")

preset_block = re.search(r"readonly property var presets: \[(.*?)\n    \]", snap_qml, re.S)
snap_zones = []
if preset_block:
    for raw in re.findall(r"zones: (\[\[.*?\]\])", preset_block.group(1)):
        try:
            snap_zones.append(json.loads(re.sub(r"(?<!\d)\.(\d+)", r"0.\1", raw)))
        except json.JSONDecodeError:
            pass
check(len(snap_zones) >= 20, "snap flyout offers an expanded layout catalogue")
canon_zone = lambda z: tuple(sorted(tuple(round(float(v), 4) for v in r) for r in z))
check(len({canon_zone(z) for z in snap_zones}) == len(snap_zones),
      "no snap layout repeats another partition with reordered zones")
check(any(len(z) >= 5 for z in snap_zones),
      "snap flyout includes layouts for sessions with many windows")
zones_valid = bool(snap_zones)
for zones in snap_zones:
    for r in zones:
        if (len(r) != 4 or not 0 <= r[0] <= 1 or not 0 <= r[1] <= 1 or
                r[2] <= 0 or r[3] <= 0 or r[0] + r[2] > 1.0001 or
                r[1] + r[3] > 1.0001):
            zones_valid = False
    for i, a in enumerate(zones):
        for b in zones[i + 1:]:
            ox = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
            oy = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
            if ox > 1e-6 and oy > 1e-6:
                zones_valid = False
check(zones_valid, "snap zones stay inside the screen and do not overlap")

check('property var selectedPreset' in snap_qml and
      'root.selectedPreset = modelData' in snap_qml and
      'root.apply(root.selectedPreset, index)' in snap_qml,
      "a layout opens an area chooser inside the same popup")
check('aequalyn_snap_preview' not in snap_qml and 'previewPreset' not in snap_qml,
      "no second full-screen preview popup is shown")
check('function pick(' not in snap_qml and 'function state(' not in snap_qml and
      'function mark(' not in snap_qml and 'trace' not in snap_qml and
      'SNAPDBG' not in snap_qml and 'SNAPCUR' not in snap_qml,
      "no temporary verification hooks are left in the flyout")
check('function beginDragSnap()' in snap_qml and 'function endDragSnap()' in snap_qml,
      "drag-to-top can open and close the snap picker")
check('onClicked: root.hide()' in snap_qml and 'anchors.fill: parent' in snap_qml,
      "clicking outside the picker dismisses it")
check('property bool snapArmBlocked' in snap_qml and
      'property double blockedAt' in snap_qml and
      'root.snapArmBlocked = true' in snap_qml and
      'root.blockedAt = Date.now()' in snap_qml and
      'Date.now() - root.blockedAt > 1200' in snap_qml,
      "one drag opens the picker once; a snap/cancel latches it through the async move")
check('function dragCandidate()' in snap_qml and 'const c = root.dragCandidate()' in snap_qml,
      "snap grid targets the window under the pointer")
check('property string dragAddr' in snap_qml and 'root.dragAddr = norm(c.address)' in snap_qml,
      "the dragged window stays the snap target while picking a zone")
check('function targetGeometry()' in snap_qml and 'root.targetGeometry()' in snap_qml,
      "snap zones use the live monitor geometry")
check('function zoneGeometry()' in snap_qml and 'const g = root.zoneGeometry()' in snap_qml,
      "pointer hit-testing and placement use the same work area")
check('hl.dispatch(hl.dsp.window.move' in snap_qml and
      'hl.dispatch(hl.dsp.window.resize' in snap_qml,
      "snap placement uses the working Lua dispatcher path")
check('z[2] * g.w - root.zoneGap' in snap_qml and
      'z[3] * g.h - root.zoneGap - root.titleHeight' in snap_qml,
      "placed windows include the titlebar inside the previewed zone")
check('mon.reserved' in snap_qml and 'res[0]' in snap_qml and 'res[1]' in snap_qml and
      'res[2]' in snap_qml and 'res[3]' in snap_qml,
      "bar reservation is respected on every side of the screen")
check('plugin:hyprbars:bar_height' in snap_qml and 'root.titleHeight = h' in snap_qml,
      "titlebar height is read from the live decoration setting")
check('property var lastSnap' in snap_qml and 'function reapplySnap()' in snap_qml and
      'root.reapplySnap()' in snap_qml,
      "snapped windows re-place themselves when the bar changes edge")
check('function placeZones(preset, chosen, list, monIdx)' in snap_qml and
      'placeZones(preset, s.chosen, list, monIdx)' in snap_qml and
      'root.zoneGeometryFor(monIdx === undefined ? root.targetMonitor : monIdx)' in snap_qml,
      "fresh snaps and bar-driven re-snaps share placement math on the right monitor")
check('function presetIndexOf(p)' in snap_qml and
      'root.presetIndexOf(preset)' in snap_qml and
      'root.presets[i].name === name' in snap_qml,
      "layout buttons resolve their preset by name, not by a copied object's identity")
check('function reflowFloating(previous, changed)' in snap_qml and
      'root.reflowFloating(previous, changed)' in snap_qml and
      'snapped.indexOf(addr) >= 0' in snap_qml,
      "free floaters are moved out from under a relocated bar without disturbing snapped ones")
check('g.y - root.titleHeight' in snap_qml and 'g.h + root.titleHeight' in snap_qml and
      'newU.x + maxW - w' in snap_qml and 'newU.y + maxH - hVis' in snap_qml,
      "free floaters keep their titlebar and whole body inside the usable area")
check('Number(mon.width) / scale' in snap_qml and 'Number(mon.height) / scale' in snap_qml,
      "snap zones use logical pixels from the live monitor resolution and scale")
check('hl.dsp.window.resize' in snap_qml and
      snap_qml.index('hl.dsp.window.resize') < snap_qml.index('hl.dsp.window.move'),
      "windows are resized before being moved into the zone")
check('hyprctl -j cursorpos' in snap_qml and
      'cursorProc.exec(cursorProc.command)' in snap_qml,
      "cursor position is polled with a process that actually restarts each tick")
check('hyprctl activewindow -j' in snap_qml and
      'property string focusedAddress' in snap_qml and
      'let addr = norm(root.focusedAddress)' in snap_qml,
      "focused window is polled directly because newer clients omit a focused flag")
check('triggeredOnStart: true' in snap_qml,
      "poll timer starts immediately")
check('on_double_click = "hyprctl eval' in float_lua,
      "titlebar double-click uses the working Lua dispatcher path")
check('function snapTopEdge(mon)' in snap_qml and
      'return Number((mon && mon.y) || 0) + reservedTop' in snap_qml and
      'function inTopStrip(mon)' in snap_qml and
      'root.cursorY >= monY - 12 && root.cursorY <= root.snapTopEdge(mon) + 56' in snap_qml,
      "top strip follows the usable top edge, including a top bar or dock")
check('function beginEdgeSnap(monIdx)' in snap_qml and
      'function monitorAtCursor()' in snap_qml and
      'readonly property int hoverDwellMs: 180' in snap_qml and
      'Date.now() - root.hoverEnteredAt >= root.hoverDwellMs' in snap_qml,
      "dwelling in the top strip opens the flyout without dragging anything")
check('atEdge && onWindow && !root.wasAtEdge' not in snap_qml and
      'const inMax =' not in snap_qml and 'y >= topLine - 8' not in snap_qml,
      "no maximize-corner or geometry-only opener remains")
check('function dragTop(): void' in snap_qml and 'snap dragTop' in float_lua,
      "drag-to-top still opens the snap list")
check('py < mon_y - 12 or py > strip' in float_lua and
      'drag.start_y - py <= 12' in float_lua,
      "drag-to-top requires an upward drag whose pointer reaches the top strip")
check('Date.now() - root.blockedAt > 1200 && !atEdge' in snap_qml,
      "the post-snap latch re-arms only after a cooldown and a real move away")
check('bottom_gap' not in snap_qml and 'pointerBottom' not in snap_qml and
      'snapEdge(' not in snap_qml,
      "off-screen bottom/pointer triggers are gone")
check('function snap_top_line(mon)' in float_lua and
      'return tonumber(my or 0) + reserved_top' in float_lua and
      'snap_top_strip(line)' in float_lua and 'line + 56' in float_lua and
      'reserved_top' in float_lua and 'mon.y' in float_lua,
      "compositor drag tracking uses the same usable top edge and pointer strip")
check('bottom_gap' not in float_lua and 'dbg_edge' not in float_lua,
      "compositor no longer tracks the off-screen bottom edge")
check('lastLayoutPoll' in snap_qml and 'root.refreshLayout()' in snap_qml,
      "layout changes made outside the shell reach the drag check")
check('function dragTop(): void' in snap_qml,
      "drag-to-top can be driven over IPC for verification")
check('function geom(c)' in snap_qml and 'c.at' in snap_qml and 'c.size' in snap_qml,
      "window geometry is read from hyprctl's at/size fields")
check('function wsId(c)' in snap_qml and 'root.wsId(c) === ws' in snap_qml,
      "floating windows are grouped by workspace id")

print(f"floating checks: {fail} failures")
sys.exit(1 if fail else 0)
