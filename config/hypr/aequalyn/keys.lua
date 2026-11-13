-- Aequalyn's layout keys, as in Tableau (github.com/qempexe/omarchy-tableau).
--
--   SUPER + L / SHIFT + L       the next / previous layout in your cycle (hyprland.lua)
--   SUPER + CTRL + L, then 1-9  Dwindle, Scrolling, Master, Portrait, Landscape,
--                               Centerpiece, Diptych Left, Diptych Right, Mosaic
--   SUPER + CTRL + L, 0, then   Strip, Column, Spiral, Gallery Right, Gallery Bottom,
--     1-9, 0, -, =              Gallery Left, Gallery Top, Spread, Diptych Top,
--                               Diptych Bottom, Triptych, Bento        (ESC: cancel)
--   SUPER + arrows              focus the nearest window that way
--   SUPER + SHIFT + arrows      swap with the nearest window that way
--   ALT + TAB / SHIFT + TAB     step through the windows; let go of ALT to bring
--                               that one forward (make it the main window)
--   SUPER + Z                   bring the focused window forward
--   SUPER + - / =               the main window larger / smaller, a step at a time,
--                               and on while held (ALT: finer, CTRL: coarser)
--
-- On Aequalyn's own layouts these go by where the windows are on screen and by the
-- layout's order; on Hyprland's (Dwindle, Master, Scrolling, Monocle) they do what
-- those normally do. hyprland.lua is loaded after this file and binds some of the same
-- keys, so the bindings are (re)made once the config has loaded, replacing those.

local hl = _G.hl
local L = _G.aequalyn_layouts
local K = {}
_G.aequalyn_keys = K

-- the step of the resize keys, a share of the screen; layouts.lua's options can change it
local function step() return (L and L.opts and tonumber(L.opts.step)) or 0.01 end

-- the focused tiled window, and its workspace when that is on one of Aequalyn's layouts
local function focused()
  local w = hl.get_active_window()
  if not (w and w.mapped and not w.floating and w.workspace) then return nil, w end
  if L and L.is_aq(w.workspace) then return w.workspace, w end
  return nil, w
end

local function tiled(ws)
  local out = {}
  for _, w in ipairs(hl.get_workspace_windows(tostring(ws.id))) do
    if w.mapped and not w.floating then out[#out + 1] = w end
  end
  return out
end

local function centre(w) return w.at.x + w.size.x / 2, w.at.y + w.size.y / 2 end

-- Hyprland's directional focus misses windows whose edges don't touch (a gap, a smaller
-- tile beside a larger one), so the nearest window within about 60 degrees of straight
-- ahead is used instead.
local DIRECTIONS = {
  left = { x = -1, y = 0 }, right = { x = 1, y = 0 }, up = { x = 0, y = -1 }, down = { x = 0, y = 1 },
}
local function nearest(ws, current, dir)
  local cx, cy = centre(current)
  local v = DIRECTIONS[dir]
  local best, best_score
  for _, w in ipairs(tiled(ws)) do
    if w.stable_id ~= current.stable_id then
      local x, y = centre(w)
      local along = (x - cx) * v.x + (y - cy) * v.y
      local across = math.abs((x - cx) * v.y + (y - cy) * v.x)
      if along > 1 and across <= 2 * along then
        local score = along + 2 * across
        if not best_score or score < best_score then best, best_score = w, score end
      end
    end
  end
  return best
end

-- both windows of a swap light up (flash.lua fills this in when it's there)
K.flashed = function(_) end

function K.focus(dir)
  return function()
    local ws, w = focused()
    if not ws then hl.dispatch(hl.dsp.focus({ direction = dir })); return end
    local to = nearest(ws, w, dir)
    if to then hl.dispatch(hl.dsp.focus({ window = to })) end
  end
end

function K.swap(dir)
  return function()
    local ws, w = focused()
    if not ws then hl.dispatch(hl.dsp.window.swap({ direction = dir })); return end
    local to = nearest(ws, w, dir)
    if not to then return end
    hl.dispatch(hl.dsp.layout("swap " .. to.stable_id))
    K.flashed({ w, to })
  end
end

-- the focused window becomes the main one
function K.promote()
  local ws, w = focused()
  if not ws then hl.dispatch(hl.dsp.layout("promote")); return end
  local main = L.order(ws.id)[1]
  if main == w.stable_id then return end
  hl.dispatch(hl.dsp.layout("promote"))
  for _, other in ipairs(tiled(ws)) do
    if other.stable_id == main then K.flashed({ w, other }) end
  end
end

-- ALT + TAB: while ALT is held each TAB focuses the next window in the layout's order;
-- letting go of ALT brings that one forward. Elsewhere: the next window, raised.
local switching = nil      -- { ws = id, p = position } while ALT is held
local function alt_down()
  local ok1, l = pcall(hl.is_key_down, "Alt_L")
  local ok2, r = pcall(hl.is_key_down, "Alt_R")
  return (ok1 and l) or (ok2 and r)
end
local function watch_alt()
  hl.timer(function()
    if not switching then return end
    if alt_down() then watch_alt(); return end
    local sw = switching
    switching = nil
    local ws = focused()
    if ws and ws.id == sw.ws then K.promote() end
  end, { timeout = 50, type = "oneshot" })
end

function K.tab(dir)
  return function()
    local ws, w = focused()
    if not ws then
      hl.dispatch(hl.dsp.window.cycle_next({ next = dir > 0 }))
      hl.dispatch(hl.dsp.window.bring_to_top())
      return
    end
    local order = L.order(ws.id)
    local n = #order
    if n < 2 then return end
    local fresh = not switching or switching.ws ~= ws.id
    if fresh then
      local at = 1
      for i, id in ipairs(order) do if id == w.stable_id then at = i end end
      switching = { ws = ws.id, p = at }
    end
    switching.p = (switching.p - 1 + dir) % n + 1
    local want = order[switching.p]
    for _, other in ipairs(tiled(ws)) do
      if other.stable_id == want then hl.dispatch(hl.dsp.focus({ window = other })) end
    end
    if fresh then watch_alt() end
  end
end

-- SUPER + - / =: `grow` 1 for minus, -1 for equal (as Tableau, after Omarchy's keys);
-- `scale` makes the step finer (ALT) or coarser (CTRL). On Aequalyn's layouts the main
-- pane changes by step() of the screen and keeps going while held; elsewhere the focused
-- window is resized by `px`.
function K.resize(grow, scale, px)
  return function()
    local ws = focused()
    if ws then
      hl.dispatch(hl.dsp.layout(string.format("resize %.4f", grow * step() * scale)))
    else
      hl.dispatch(hl.dsp.window.resize({ x = -grow * px, y = 0, relative = true }))
    end
  end
end

-- SUPER + CTRL + L: pick a layout with a number, Tableau's numbering
local PICK = { "dwindle", "scrolling", "master", "portrait", "landscape", "centerpiece",
               "diptych_left", "diptych_right", "mosaic" }
local MORE = { { "1", "strip" }, { "2", "column" }, { "3", "spiral" }, { "4", "gallery_right" },
               { "5", "gallery_bottom" }, { "6", "gallery_left" }, { "7", "gallery_top" },
               { "8", "spread" }, { "9", "diptych_top" }, { "0", "diptych_bottom" },
               { "minus", "triptych" }, { "equal", "bento" } }
local function pick(key)
  return function()
    hl.dispatch(hl.dsp.submap("reset"))
    hl.dispatch(hl.dsp.exec_cmd("aequalyn-layout set " .. key))
  end
end

local KEYS = {}            -- every combination bound here, so they can be cleared first
local function bind(keys, fn, opts)
  KEYS[#KEYS + 1] = keys
  hl.unbind(keys)
  hl.bind(keys, fn, opts)
end

local submaps_defined = false
function K.apply()
  for _, k in ipairs(KEYS) do pcall(hl.unbind, k) end
  KEYS = {}
  -- older keys these replace
  for _, k in ipairs({ "SUPER + ALT + minus", "SUPER + ALT + equal" }) do pcall(hl.unbind, k) end

  for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind("SUPER + " .. dir, K.focus(dir))
    bind("SUPER + SHIFT + " .. dir, K.swap(dir))
  end
  bind("ALT + TAB", K.tab(1))
  bind("ALT + SHIFT + TAB", K.tab(-1))
  bind("SUPER + Z", K.promote)
  for _, m in ipairs({ { "SUPER", 1, 100 }, { "SUPER + ALT", 0.25, 25 }, { "SUPER + CTRL", 4, 300 } }) do
    bind(m[1] .. " + code:20", K.resize(1, m[2], m[3]), { repeating = true })
    bind(m[1] .. " + code:21", K.resize(-1, m[2], m[3]), { repeating = true })
  end

  bind("SUPER + CTRL + L", function() hl.dispatch(hl.dsp.submap("aq-layout-picker")) end)
  if not submaps_defined then
    submaps_defined = true
    hl.define_submap("aq-layout-picker", function()
      for i, key in ipairs(PICK) do hl.bind(tostring(i), pick(key)) end
      hl.bind("0", function() hl.dispatch(hl.dsp.submap("aq-layout-picker-more")) end)
      hl.bind("Escape", hl.dsp.submap("reset"))
    end)
    hl.define_submap("aq-layout-picker-more", function()
      for _, item in ipairs(MORE) do hl.bind(item[1], pick(item[2])) end
      hl.bind("Escape", hl.dsp.submap("reset"))
    end)
  end
end

-- after the whole config has loaded (start and every reload), so hyprland.lua's own
-- bindings for these keys are replaced, not doubled
hl.on("config.reloaded", function() K.apply() end)
hl.on("hyprland.start", function() K.apply() end)

return K
