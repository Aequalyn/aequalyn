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
local plugin_loaded
function F.set_ws(ws, on)
  local id = tostring(ws)
  if on == nil then F.workspaces[id] = nil
  else F.workspaces[id] = on and true or false end
  if fn("window_rule") and plugin_loaded() then
    local floating = (on == nil) and F.default or (on and true or false)
    pcall(hl.window_rule, {
      name = "aequalyn-hyprbar-ws-" .. id,
      match = { workspace = id },
      ["hyprbars:no_bar"] = not floating,
    })
  end
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
      if fn("window_rule") and plugin_loaded() then
        local wsid = tostring(w.workspace.id or w.workspace)
        pcall(hl.window_rule, {
          name = "aequalyn-hyprbar-ws-" .. wsid,
          match = { workspace = wsid },
          ["hyprbars:no_bar"] = not want,
        })
      end
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
function plugin_loaded()
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

-- The titlebar's text in the desktop's UI font (settings.json); aequalyn-apply-fonts
-- reloads Hyprland after a change while the titlebar is loaded.
local function ui_font()
  local file = io.open((os.getenv("HOME") or "") .. "/.config/aequalyn/settings.json", "r")
  if not file then return "JetBrainsMono Nerd Font" end
  local text = file:read("*a") or ""
  file:close()
  return text:match('"uiFont"%s*:%s*"([^"\\]+)"') or "JetBrainsMono Nerd Font"
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
        bar_text_font = ui_font(),
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

  -- The titlebar belongs to floating workspaces only. Per-workspace rules
  -- (F.set_ws, and F.sweep for any workspace a window lands on) decide it;
  -- there is no catch-all, so a floating workspace is never disabled by a
  -- broader rule.
end

function F.load_decorations()
  if NO_DECORATIONS then return end
  if F.decorations.loaded then return end
  if plugin_loaded() then
    F.decorations.loaded = true
    configure_decorations()
    pcall(F.apply)
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
    pcall(F.apply)
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

-- Hyprland exposes monitor fields under a few names depending on the version.
local function num_field(t, names)
  local kind = type(t)
  if kind ~= "table" and kind ~= "userdata" then return nil end
  for _, n in ipairs(names) do
    if type(t[n]) == "number" then return t[n] end
  end
  return nil
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
