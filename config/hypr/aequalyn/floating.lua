-- Aequalyn's floating workspaces.
--
-- A workspace can be set to "Floating" just like any other Aequalyn layout.
-- Windows on it become real Hyprland floating windows (move and resize them
-- from any edge). Decorations are applied only when the optional builder's
-- plugin is present, and AEQUALYN_NO_FLOAT_DECORATIONS=1 skips them entirely.
--
-- This file is loaded by layouts.lua. Every compositor call is guarded: an
-- older Hyprland, a missing plugin, or a partial config must leave the desktop
-- working, just without this feature.

local hl = _G.hl
local HOME = os.getenv("HOME") or ""
local F = {}
_G.aequalyn_floating = F

local TAG = "aq-float-mode"
local DECOR_PLUGIN = HOME .. "/.local/lib/aequalyn/hyprbars.so"
local NO_DECORATIONS = os.getenv("AEQUALYN_NO_FLOAT_DECORATIONS") == "1"

F.workspaces = {}                 -- workspace id -> true
F.default = false
F.decorations = { loaded = false, attempted = false }
F._pending = false

local function fn(name)
  return type(hl[name]) == "function"
end

local function report(where, err)
  print("[aequalyn] floating: " .. where .. ": " .. tostring(err))
end

local function dispatch(...)
  if fn("dispatch") then
    local ok, err = pcall(hl.dispatch, ...)
    if not ok then report("dispatch", err) end
  end
end

local function dsp(group, method)
  local g = type(hl.dsp) == "table" and hl.dsp[group] or nil
  return type(g) == "table" and g[method] or nil
end

local function has_tag(window, name)
  for _, tag in ipairs(type(window.tags) == "table" and window.tags or {}) do
    if tag == name or tag == name .. "*" then return true end
  end
  return false
end

local function tag(window, name, on)
  local make = dsp("window", "tag")
  if not make or not window or not window.address then return end
  dispatch(make({
    window = "address:" .. window.address,
    tag = (on and "+" or "-") .. name,
  }))
end

-- ---------------------------------------------------------------- workspaces
function F.set_ws(ws, on)
  local id = tostring(ws)
  if on == nil then F.workspaces[id] = nil
  else F.workspaces[id] = on and true or false end
  F.apply()
end

function F.set_default(on)
  F.default = on and true or false
  F.apply()
end

function F.is_ws(ws)
  if not ws then return F.default end
  local explicit = F.workspaces[tostring(ws.id or ws)]
  if explicit ~= nil then return explicit end
  return F.default
end

function F.apply()
  if F._pending then return end
  if fn("timer") then
    F._pending = true
    local ok, err = pcall(hl.timer, function()
      F._pending = false
      pcall(F.sweep)
    end, { timeout = 60, type = "oneshot" })
    if not ok then
      F._pending = false
      report("timer", err)
      pcall(F.sweep)
    end
  else
    pcall(F.sweep)
  end
end

function F.sweep()
  if not fn("get_windows") then return end
  local ok, windows = pcall(hl.get_windows)
  if not ok or type(windows) ~= "table" then return end
  -- Without tags we cannot tell our windows from ones the user floated by
  -- hand, so leave every window alone on older compositors.
  local can_tag = dsp("window", "tag") ~= nil
  local set_float = dsp("window", "float")
  for _, w in ipairs(windows) do
    if w and w.address and w.mapped ~= false and w.workspace and not w.workspace.special then
      local want = F.is_ws(w.workspace)
      local tagged = has_tag(w, TAG)
      if want and can_tag and set_float and not tagged and not w.floating then
        tag(w, TAG, true)
        dispatch(set_float({ window = "address:" .. w.address, action = "set" }))
      elseif not want and tagged then
        if set_float then dispatch(set_float({ window = "address:" .. w.address, action = "unset" })) end
        tag(w, TAG, false)
      end
    end
  end
end

-- ---------------------------------------------------------------- decorations
local function plugin_loaded()
  -- Never trust a successful load call alone: only configure bars once
  -- Hyprland itself reports the plugin as loaded, or its config keys do not
  -- exist yet and the whole config load fills the log with errors.
  if not fn("get_loaded_plugins") then return false end
  local ok, list = pcall(hl.get_loaded_plugins)
  if not ok or type(list) ~= "table" then return false end
  for _, p in ipairs(list) do
    local name = type(p) == "table" and (p.name or p.id) or p
    if name == "hyprbars" then return true end
  end
  return false
end

local function rgb_of(opt)
  local colours = type(opt) == "table" and opt.colors or nil
  local argb = type(colours) == "table" and colours[1] or nil
  if type(argb) == "number" then return string.format("%06x", argb % 0xffffff) end
  if type(argb) == "string" then
    return argb:match("^0[xX]%x%x(%x%x%x%x%x%x)$")
        or argb:match("^(%x%x%x%x%x%x)$")
        or "ffffff"
  end
  return "ffffff"
end

local function accent(alpha)
  local colour = "ffffff"
  if fn("get_config") then
    local ok, opt = pcall(hl.get_config, "general.col.active_border")
    if ok then colour = rgb_of(opt) end
  end
  return "rgba(" .. colour .. (alpha or "ff") .. ")"
end

local function configure_decorations()
  if not F.decorations.loaded or not fn("config") then return end
  local ok, err = pcall(hl.config, {
    plugin = {
      hyprbars = {
        bar_height = 26,
        bar_color = accent("e6"),
        col = { text = "rgba(f2f2f2ff)" },
        bar_text_size = 11,
        bar_text_font = "JetBrainsMono Nerd Font",
        bar_text_align = "left",
        bar_buttons_alignment = "right",
        bar_padding = 10,
        bar_button_padding = 4,
        bar_part_of_window = true,
        bar_precedence_over_border = true,
        on_double_click = "hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen())'",
      },
    },
  })
  if not ok then report("bar config", err) end

  local bars = type(hl.plugin) == "table" and hl.plugin.hyprbars or nil
  local add = type(bars) == "table" and bars.add_button or nil
  if type(add) == "function" then
    local button = function(bg, icon, action)
      pcall(add, {
        bg_color = bg, fg_color = "rgb(101010)", size = 15, icon = icon, action = action,
      })
    end
    -- hyprbars lays right-aligned buttons out right-to-left, so register them
    -- in reverse to read green minimize (_), yellow maximize (square), red close
    -- from left to right.
    button("rgb(ff5f57)", "󰖭", "hyprctl eval 'aequalyn_close_active()'")
    button("rgb(febc2e)", "□", "hyprctl eval 'aequalyn_maximize_active()'")
    button("rgb(28c840)", "_", "hyprctl eval 'aequalyn_minimize_active()'")
  end

  -- tiled windows keep the compositor's own decoration; bars belong to floaters
  if fn("window_rule") then
    pcall(hl.window_rule, {
      name = "aq-no-bar-tiled",
      match = { float = false },
      ["hyprbars:no_bar"] = true,
    })
  end
end

function F.load_decorations()
  if NO_DECORATIONS then return end
  if plugin_loaded() then
    F.decorations.loaded = true
    configure_decorations()
    return
  end
  if F.decorations.attempted then return end

  -- Never load the plugin here: doing so during startup crashes Hyprland.
  -- The plugin is loaded on demand (Super + Shift + T) via hyprctl, and
  -- load_decorations() then only configures the already-loaded plugin.

  local file = io.open(DECOR_PLUGIN, "r")
  if file then file:close() end

  -- If the plugin is already loaded, configure it; otherwise do nothing.
  if plugin_loaded() then
    F.decorations.loaded = true
    configure_decorations()
  else
    F.decorations.loaded = false
  end
end

-- ------------------------------------------------------------- resize hooks
-- A floating window is resized by grabbing its edge/corner. Hyprland's border
-- resize gives the same drag handles on every floating window: hovering near an
-- edge shows the resize cursor (the visual hook) and the extended grab area
-- makes the corner easy to catch. Tiled windows are laid out by Aequalyn, so an
-- edge drag there only ever nudges a split if the user wants it.
function F.setup_resize_hooks()
  if not fn("config") then return end
  local ok, err = pcall(hl.config, {
    general = {
      resize_on_border       = true,
      extend_border_grab_area = 15,
      hover_icon_on_border    = true,
    },
  })
  if not ok then report("resize hooks", err) end
end

-- ------------------------------------------------------------- drag to snap
-- The primary button is tracked through press/release binds so a floating
-- window dragged to the top of the usable area can arm the on-screen snap grid.
-- A top bar shifts that line below itself, so the window stays on screen. Mouse
-- binds are non-consuming, so normal dragging and in-app clicks keep working.
local drag = { down = false, addr = nil, start_x = nil, start_y = nil,
               armed = false, poll = nil, regtimer = nil }

local function snap_ipc(cmd)
  if not fn("dispatch") or type(hl.dsp) ~= "table" then return end
  local ok, d = pcall(function() return hl.dsp.exec_cmd(cmd) end)
  if not ok or not d then return end
  pcall(hl.dispatch, d)
end

local function drag_stop_poll()
  if drag.poll then
    pcall(function() drag.poll:set_enabled(false) end)
    drag.poll = nil
  end
end

local function drag_reset()
  drag.down = false
  drag.addr = nil
  drag.start_x = nil
  drag.start_y = nil
  drag.armed = false
  drag_stop_poll()
end

-- Hyprland exposes monitor fields under a few names depending on the version.
local function num_field(t, names)
  local kind = type(t)
  if kind ~= "table" and kind ~= "userdata" then return nil end
  for _, n in ipairs(names) do
    if type(t[n]) == "number" then return t[n] end
  end
  return nil
end

-- reserved is [left, top, right, bottom]. The first usable row is below any
-- bar or dock that owns the top edge; the decoration sits above the client, so
-- the pointer strip extends a little further down than that edge.
local function snap_top_line(mon)
  local ok, r = pcall(function() return mon.reserved end)
  local reserved_top = num_field(r, { "top", 2 }) or 0
  local oky, my = pcall(function() return mon.y end)
  if not oky then return nil end
  return tonumber(my or 0) + reserved_top
end

local function snap_top_strip(line)
  return line + 56
end

local function drag_check()
  if not drag.down or not drag.addr then return end
  local ok, w = pcall(hl.get_window, "address:" .. drag.addr)
  if not ok or not w then return end
  local okf, floating = pcall(function() return w.floating end)
  if not okf or floating ~= true then return end
  local oka, at = pcall(function() return w.at end)
  if not oka or type(at) ~= "table" then return end

  local mon = nil
  local okm, m = pcall(function() return w.monitor end)
  if okm then mon = m end
  if not mon and fn("get_monitor_at_cursor") then
    local okc, c = pcall(hl.get_monitor_at_cursor)
    if okc then mon = c end
  end
  if not mon then return end
  local top_line = snap_top_line(mon)
  if not top_line then return end
  local strip = snap_top_strip(top_line)
  local mon_y = tonumber(mon.y) or top_line

  -- A click on the picker can reposition the window while the button is still
  -- logically down. Require real upward pointer travel, not just proximity.
  local px, py = nil, nil
  if drag.start_x and drag.start_y and fn("get_cursor_pos") then
    local okp, pos = pcall(hl.get_cursor_pos)
    if okp and type(pos) == "table" then
      px = tonumber(pos.x) or drag.start_x
      py = tonumber(pos.y) or drag.start_y
      local dx, dy = px - drag.start_x, py - drag.start_y
      if dx * dx + dy * dy < 30 * 30 then return end
      if drag.start_y - py <= 12 then return end
    end
  end
  if not py then return end

  -- The flyout appears only when the pointer itself touches the top strip.
  -- With a bar and/or dock on top, top_line already sits below them; allowing
  -- a small margin above it also covers a pointer resting on that panel.
  if py < mon_y - 12 or py > strip then return end

  local ay = tonumber(at.y or 0)
  local top = ay - top_line
  -- The dragged window must actually be at the top, not merely pointed at.
  if top < -240 or top > 120 then return end

  if not drag.armed then
    drag.armed = true
    snap_ipc("qs ipc call snap dragTop")
  end
  -- Re-arm only after the pointer and the window have both left the strip.
  if py > strip + 64 or top > 160 then
    drag.armed = false
  end
end

-- The window under the pointer, not the focused one: during a title-bar drag
-- focus can stay on a shell surface while a different window is being moved.
local function window_at_cursor()
  if not fn("get_cursor_pos") or not fn("get_windows") then return nil end
  local okp, pos = pcall(hl.get_cursor_pos)
  local okw, windows = pcall(hl.get_windows)
  if not okp or not okw or type(pos) ~= "table" or type(windows) ~= "table" then return nil end
  local found, best_area = nil, nil
  for _, w in ipairs(windows) do
    if w and w.address and w.mapped ~= false then
      local oka, at = pcall(function() return w.at end)
      local oks, sz = pcall(function() return w.size end)
      if oka and oks and type(at) == "table" and type(sz) == "table" then
        local x, y = tonumber(at.x or 0), tonumber(at.y or 0)
        local sw, sh = tonumber(sz.x or 0), tonumber(sz.y or 0)
        -- titles are decorations above the client geometry, so allow a margin
        if pos.x >= x and pos.x <= x + sw and pos.y >= y - 48 and pos.y <= y + sh then
          local area = sw * sh
          if not best_area or area < best_area then
            found, best_area = w, area
          end
        end
      end
    end
  end
  return found
end

local function drag_press()
  local w = window_at_cursor()
  drag.addr = (w and w.address) or nil
  drag.start_x = nil
  drag.start_y = nil
  drag.armed = false
  drag.down = true
  if fn("get_cursor_pos") then
    local okp, pos = pcall(hl.get_cursor_pos)
    if okp and type(pos) == "table" then
      drag.start_x = tonumber(pos.x)
      drag.start_y = tonumber(pos.y)
    end
  end
  if not drag.poll then
    local okt, t = pcall(hl.timer, drag_check, { timeout = 30, type = "repeat" })
    if okt then
      drag.poll = t
      pcall(function() t:set_enabled(true) end)
    end
  elseif drag.poll then
    pcall(function() drag.poll:set_enabled(true) end)
  end
end

local function drag_release()
  -- Releasing ends the drag only. The picker stays open so the arrangement and
  -- zone can be chosen with normal clicks.
  drag_reset()
end

local function register_drag_binds()
  drag.regtimer = nil
  if not fn("bind") or not fn("get_windows") then return end
  pcall(hl.bind, "mouse:272", drag_press, { non_consuming = true, ignore_mods = true })
  pcall(hl.bind, "mouse:272", drag_release,
        { release = true, non_consuming = true, ignore_mods = true })
end

function F.setup_drag_snap()
  if not fn("bind") or not fn("timer") or not fn("get_windows") then return end
  -- keys.lua clears plain mouse:272 while the config is being assembled. Defer
  -- our binds until after every load callback so they are the last registration.
  if drag.regtimer then return end
  local ok, t = pcall(hl.timer, register_drag_binds, { timeout = 10, type = "oneshot" })
  if ok then drag.regtimer = t end
end

-- Register on module load too: the reloaded hook does not run on the first pass.
F.setup_drag_snap()

-- ---------------------------------------------------------------- minimize
local function window_by_address(addr)
  if not addr or not fn("get_windows") then return nil end
  local ok, windows = pcall(hl.get_windows)
  if not ok or type(windows) ~= "table" then return nil end
  for _, w in ipairs(windows) do
    if w and w.address == addr then return w end
  end
  return nil
end

-- A window move and a tag change are separate dispatches. Doing the tag in the
-- same tick as the move can lose the tag when Hyprland has not finished moving
-- the window yet, which leaves a restored window marked minimized forever.
local function mark_minimized(addr, on)
  local function apply()
    local w = window_by_address(addr)
    if w then tag(w, "minimized", on) end
  end
  if fn("timer") then
    local ok, t = pcall(hl.timer, apply, { timeout = 80, type = "oneshot" })
    if ok then return end
  end
  apply()
end

local function is_minimized_workspace(ws)
  if not ws then return false end
  return ws.name == "special:minimized"
      or tostring(ws.id) == "special:minimized"
end

-- Remember which normal workspace a window left so "bring it back" can put it
-- back there instead of only raising the special overlay.
local minimized_origin = {}

local function minimized_windows()
  local out = {}
  if not fn("get_windows") then return out end
  local ok, windows = pcall(hl.get_windows)
  if not ok or type(windows) ~= "table" then return out end
  for _, w in ipairs(windows) do
    if w and w.address then
      if is_minimized_workspace(w.workspace) then
        out[#out + 1] = w
      elseif has_tag(w, "minimized") then
        -- A window that is visible again must not keep a stale minimized tag.
        mark_minimized(w.address, false)
      end
    end
  end
  return out
end

local function restore_window(w, target)
  local move = dsp("window", "move")
  if not w or not w.address or not move or not target then return end
  local addr = w.address
  dispatch(move({
    workspace = target,
    window = "address:" .. addr,
  }))
  minimized_origin[addr] = nil
  mark_minimized(addr, false)
end

local function current_workspace()
  return fn("get_active_workspace") and hl.get_active_workspace() or nil
end

function _G.aequalyn_minimize_active()
  local w = fn("get_active_window") and hl.get_active_window() or nil
  local move = dsp("window", "move")
  if not w or not w.address or not move then return end
  local addr = w.address
  local here = current_workspace()
  minimized_origin[addr] = (here and not is_minimized_workspace(here)) and here or nil
  dispatch(move({
    workspace = "special:minimized",
    window = "address:" .. addr,
    follow = false,
  }))
  mark_minimized(addr, true)
end

function _G.aequalyn_restore_minimized()
  local here = current_workspace()
  for _, w in ipairs(minimized_windows()) do
    restore_window(w, minimized_origin[w.address] or here)
  end
end

-- The dock, the switcher, and every other activate-by-address path only focus
-- a hidden window. Hyprland then keeps special:minimized as an overlay, so the
-- normal windows stay underneath and cannot be focused or moved. Turn that
-- focus into a real restore on the focus event itself, whatever requested it.
local pending_restore = {}
local function on_window_active(w)
  if not w or not w.address then return end
  local addr = w.address
  if pending_restore[addr] then return end
  if not is_minimized_workspace(w.workspace) then return end
  local home = minimized_origin[addr] or current_workspace()
  if not home then return end
  pending_restore[addr] = true
  local function finish()
    pending_restore[addr] = nil
    local live = window_by_address(addr)
    if live and is_minimized_workspace(live.workspace) then
      restore_window(live, home)
    end
  end
  -- Defer so the move is not issued from inside the focus event dispatch.
  if fn("timer") then
    local ok, t = pcall(hl.timer, finish, { timeout = 50, type = "oneshot" })
    if ok then return end
  end
  finish()
end

-- ------------------------------------------------------------- new windows
-- A window opened on a Floating workspace starts at half the monitor's logical
-- resolution. Reserved edges and the decorated titlebar are removed from that
-- rectangle so the visible window, not just its client area, is half the screen.
local sized_on_open = {}

local function titlebar_height()
  if not F.decorations.loaded then return 0 end
  local h = 26
  if fn("get_config") then
    local ok, opt = pcall(hl.get_config, "plugin:hyprbars:bar_height")
    if ok then
      local value = type(opt) == "table" and (opt.int or opt.value or opt.num) or opt
      value = tonumber(value)
      if value and value >= 0 then h = value end
    end
  end
  return h + 2
end

local function usable_half_size(mon)
  local w = num_field(mon, { "width", "w" })
  local h = num_field(mon, { "height", "h" })
  if not w or not h or w <= 0 or h <= 0 then return nil end
  local scale = num_field(mon, { "scale" }) or 1
  if scale <= 0 then scale = 1 end

  local okr, r = pcall(function() return mon.reserved end)
  if not okr then r = nil end
  local left = num_field(r, { "left", 1 }) or 0
  local top = num_field(r, { "top", 2 }) or 0
  local right = num_field(r, { "right", 3 }) or 0
  local bottom = num_field(r, { "bottom", 4 }) or 0

  local usable_w = w / scale - left - right
  local usable_h = h / scale - top - bottom
  if usable_w < 320 or usable_h < 240 then return nil end

  local client_h = math.floor(usable_h / 2) - titlebar_height()
  if client_h < 120 then return nil end
  return math.floor(usable_w / 2), client_h
end

local function on_window_open(event)
  local addr = event and event.address or nil
  local function size()
    if not addr or sized_on_open[addr] then return end
    local w = window_by_address(addr)
    if not w or w.mapped == false or not F.is_ws(w.workspace) then return end

    local mon = w.monitor
    if not mon and fn("get_monitor_at_cursor") then
      local okm, m = pcall(hl.get_monitor_at_cursor)
      if okm then mon = m end
    end
    local width, height = usable_half_size(mon)
    local resize = dsp("window", "resize")
    if not width or not resize then return end

    dispatch(resize({
      window = "address:" .. addr,
      x = width,
      y = height,
    }))
    sized_on_open[addr] = true
  end

  -- Let the normal Floating sweep float the window first, then size the
  -- decorated result once.
  if fn("timer") then
    local ok, t = pcall(hl.timer, size, { timeout = 120, type = "oneshot" })
    if ok then return end
  end
  size()
end

local function on_window_close(event)
  if event and event.address then sized_on_open[event.address] = nil end
  pcall(F.apply)
end

function _G.aequalyn_maximize_active()
  local w = fn("get_active_window") and hl.get_active_window() or nil
  local fullscreen = dsp("window", "fullscreen")
  if not w or not w.address or not fullscreen then return end
  dispatch(fullscreen({
    window = "address:" .. w.address,
    mode = "maximized",
    action = "toggle",
  }))
end

function _G.aequalyn_close_active()
  local w = fn("get_active_window") and hl.get_active_window() or nil
  local close = dsp("window", "close")
  if not w or not w.address or not close then return end
  dispatch(close({ window = "address:" .. w.address }))
end

if fn("unbind") and fn("bind") then
  pcall(hl.unbind, "SUPER + M")
  pcall(hl.bind, "SUPER + M", function()
    if #minimized_windows() > 0 then _G.aequalyn_restore_minimized()
    else _G.aequalyn_minimize_active() end
  end, { description = "Minimize / restore the focused window" })
end

-- ---------------------------------------------------------------- lifecycle
local function loaded()
  if fn("workspace_rule") then
    pcall(hl.workspace_rule, { workspace = "special:minimized", persistent = false })
  end
  F.load_decorations()
  F.setup_resize_hooks()
  F.setup_drag_snap()
  F.apply()
end

if fn("on") then
  pcall(hl.on, "config.reloaded", loaded)
  pcall(hl.on, "hyprland.start", loaded)
  for _, ev in ipairs({ "window.move_to_workspace", "window.update_state",
                        "workspace.active" }) do
    pcall(hl.on, ev, F.apply)
  end
  pcall(hl.on, "window.open", function(w)
    pcall(F.apply)
    on_window_open(w)
  end)
  pcall(hl.on, "window.close", on_window_close)
  pcall(hl.on, "window.active", on_window_active)
end

return F
