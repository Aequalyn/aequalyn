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
  { address = "0x2", mapped = true, workspace = { id = 2 }, floating = false, tags = {} },
}
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
      end
    end
  end
end

hl = {
  get_windows = function() return windows end,
  get_active_window = function() return nil end,
  get_active_workspace = function() return { id = 2 } end,
  timer = function(fn) fn() end,
  dispatch = function(d) apply(d) end,
  dsp = { window = {
    tag = function(o) return { op = "tag", window = o.window, tag = o.tag } end,
    float = function(o) return { op = "float", window = o.window, action = o.action } end,
    move = function(o) return { op = "move", window = o.window, workspace = o.workspace } end,
  } },
}

local F = assert(dofile(path))
check(type(aequalyn_minimize_active) == "function", "minimize button helper exists")
check(type(aequalyn_maximize_active) == "function", "maximize button helper exists")
check(type(aequalyn_close_active) == "function", "close button helper exists")
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
# reverse of the wanted left-to-right order: close, maximize, minimize.
registered = re.findall(r'button\("rgb\(([0-9a-f]{6})\)"', float_lua)
check(registered[:3] == ["ff5f57", "28c840", "febc2e"],
      "titlebar buttons register reversed to display minimize, maximize, close")

snap_qml = text_of(SHELL / "plugins/snap/Snap.qml")
check('function zoneAt(preset, px, py)' in snap_qml and
      'root.zoneAt(modelData, root.pickX, root.pickY)' in snap_qml,
      "pointer position preselects a zone in the area chooser")
check('Row {' in snap_qml and 'columns: 4' not in snap_qml,
      "all layouts are offered in a single row")
check('property var selectedPreset' in snap_qml and
      'root.selectedPreset = modelData' in snap_qml and
      'root.apply(root.selectedPreset, index)' in snap_qml,
      "a layout opens an area chooser inside the same popup")
check('aequalyn_snap_preview' not in snap_qml and 'previewPreset' not in snap_qml,
      "no second full-screen preview popup is shown")
check('function pick(' not in snap_qml and 'function state(' not in snap_qml and
      'function mark(' not in snap_qml and 'trace' not in snap_qml,
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
      'if (moved) root.reapplySnap()' in snap_qml,
      "snapped windows re-place themselves when the bar changes edge")
check('function placeZones(preset, chosen, list)' in snap_qml and
      'placeZones(preset, s.chosen, list)' in snap_qml,
      "fresh snaps and bar-driven re-snaps share the same placement math")
check('Number(mon.width) / scale' in snap_qml and 'Number(mon.height) / scale' in snap_qml,
      "snap zones use logical pixels from the live monitor resolution and scale")
check('hl.dsp.window.resize' in snap_qml and
      snap_qml.index('hl.dsp.window.resize') < snap_qml.index('hl.dsp.window.move'),
      "windows are resized before being moved into the zone")
check('hyprctl -j cursorpos' in snap_qml and 'cursorProc.running = true' in snap_qml,
      "cursor position is polled with a working process")
check('triggeredOnStart: true' in snap_qml,
      "poll timer starts immediately")
check('on_double_click = "hyprctl eval' in float_lua,
      "titlebar double-click uses the working Lua dispatcher path")
check('function snapTopLine(mon)' in snap_qml and 'reservedTop + root.titleHeight' in snap_qml,
      "drag trigger follows the usable top edge, including a top bar")
check('atEdge && onWindow && !root.wasAtEdge' in snap_qml and
      'root.beginDragSnap()' in snap_qml,
      "drag-to-top is detected from live window geometry")
check('Date.now() - root.blockedAt > 1200 && !atEdge' in snap_qml,
      "the post-snap latch re-arms only after a cooldown and a real move away")
check('bottom_gap' not in snap_qml and 'pointerBottom' not in snap_qml and
      'snapEdge(' not in snap_qml,
      "off-screen bottom/pointer triggers are gone")
check('function snap_top_line(mon)' in float_lua and 'reserved_top + 28' in float_lua,
      "compositor drag tracking uses the same usable top edge")
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
