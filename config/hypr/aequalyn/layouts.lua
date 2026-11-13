-- Aequalyn window layouts for Hyprland.
--
-- Registers every layout in geometry.lua as a Hyprland Lua layout named
-- "aq-<id>" and keeps, per workspace, the order windows sit in: slot 1 is
-- the main window, the others keep their place until you move them.
--
-- The keys that work on these layouts (Super + Shift + arrows, Alt + Tab, Super + Z,
-- the resize keys, the layout picker...) are in keys.lua, loaded at the end.
--
-- Which layout each workspace uses, and the pane / gap settings, come from
-- workspace-layouts.lua, written by `aequalyn-layout`.

if _G.aequalyn_layouts then return _G.aequalyn_layouts end

local hl = _G.hl
local HOME = os.getenv("HOME") or ""
local G = dofile(HOME .. "/.config/hypr/aequalyn/geometry.lua")

local M = { geometry = G }
_G.aequalyn_layouts = M

-- Defaults; workspace-layouts.lua replaces them through M.configure().
-- step: how much one press of Super + - / = changes the main pane (keys.lua);
-- outline (px, nil = as the theme) and others (theme | same | hidden): tiles.lua
M.opts = { pane = 0.62, middle = 0.56, gap = 24, step = 0.01 }
M.pane_by_ws = {}          -- workspace id -> pane share changed with the resize keys
local slots = {}           -- workspace id -> ordered list of window stable ids

function M.configure(opts)
  for k, v in pairs(opts or {}) do M.opts[k] = v end
end

local function index_of(list, v)
  for i, x in ipairs(list) do if x == v then return i end end
end

-- Keep the slot list in step with the windows that are there: windows that
-- left are dropped, new windows are added at the end.
local function sync(list, present)
  for i = #list, 1, -1 do
    if not present[list[i]] then table.remove(list, i) end
  end
  local new = {}
  for id in pairs(present) do
    if not index_of(list, id) then new[#new + 1] = id end
  end
  table.sort(new)
  for _, id in ipairs(new) do list[#list + 1] = id end
end

local function ordered(ctx)
  local by_id, present, other, ws = {}, {}, {}, nil
  for _, t in ipairs(ctx.targets) do
    local w = t.window
    if w and w.stable_id then
      by_id[w.stable_id] = t
      present[w.stable_id] = true
      ws = ws or (w.workspace and w.workspace.id)
    else
      other[#other + 1] = t
    end
  end
  local out = {}
  if ws then
    slots[ws] = slots[ws] or {}
    sync(slots[ws], present)
    for _, id in ipairs(slots[ws]) do out[#out + 1] = by_id[id] end
  end
  for _, t in ipairs(other) do out[#out + 1] = t end
  return out, ws
end

local function opts_for(ws)
  local o = {}
  for k, v in pairs(M.opts) do o[k] = v end
  if ws and M.pane_by_ws[ws] then
    o.pane = M.pane_by_ws[ws]
    o.middle = M.pane_by_ws[ws]
  end
  return o
end

-- is this workspace on one of these layouts?
function M.is_aq(ws)
  return ws ~= nil and not ws.special and tostring(ws.tiled_layout or ""):match("^lua:aq%-") ~= nil
end

-- the windows of a workspace in slot order (slot 1 is the main window), for keys.lua
function M.order(ws_id)
  local out = {}
  for i, id in ipairs(slots[ws_id] or {}) do out[i] = id end
  return out
end

local function active_ws()
  local w = hl.get_active_workspace()
  return w and w.id
end

local function message(msg)
  local ws = active_ws()
  if not ws then return true end
  local list = slots[ws] or {}
  local win = hl.get_active_window()
  local at = win and index_of(list, win.stable_id)
  if msg == "promote" then
    if at and at > 1 then list[1], list[at] = list[at], list[1] end
  elseif msg == "swapnext" or msg == "swapprev" then
    if at and #list > 1 then
      local to = msg == "swapnext" and (at % #list) + 1 or ((at - 2) % #list) + 1
      list[at], list[to] = list[to], list[at]
    end
  elseif msg:match("^swap ") then
    -- "swap <stable id>": the focused window and that one trade places
    -- stable ids are strings of digits ("18000003"), compared as they come
    local to = index_of(list, msg:sub(6))
    if at and to and at ~= to then list[at], list[to] = list[to], list[at] end
  elseif msg == "grow" or msg == "shrink" or msg:match("^resize ") then
    -- "resize <share>": the main pane by that share of the screen (+ larger, - smaller)
    local d = msg == "grow" and 0.04 or msg == "shrink" and -0.04 or (tonumber(msg:sub(8)) or 0)
    local cur = M.pane_by_ws[ws] or M.opts.pane
    M.pane_by_ws[ws] = math.max(0.3, math.min(0.85, cur + d))
  elseif msg == "refresh" then
    -- nothing to change: the layout is laid out again
  elseif msg == "reset" then
    M.pane_by_ws[ws] = nil
  else
    return "aequalyn layouts: unknown message " .. tostring(msg)
  end
  return true
end

for _, entry in ipairs(G.catalogue) do
  local fn = G[entry.id]
  local ok, err = pcall(hl.layout.register, "aq-" .. entry.id, {
    recalculate = function(ctx)
      local targets, ws = ordered(ctx)
      local n = #targets
      if n == 0 then return end
      local rects = fn(n, ctx.area, opts_for(ws))
      for i, t in ipairs(targets) do
        local rc = rects[i] or ctx.area
        t:place({ x = rc.x, y = rc.y, w = rc.w, h = rc.h })
      end
    end,
    layout_msg = function(_, msg) return message(msg) end,
  })
  if not ok and not tostring(err):find("already registered", 1, true) then
    print("[aequalyn] layout aq-" .. entry.id .. ": " .. tostring(err))
  end
end

-- the keys, and how these windows look (dofile, so `hyprctl reload` re-reads them too)
for _, file in ipairs({ "keys.lua", "tiles.lua" }) do
  local ok, err = pcall(dofile, HOME .. "/.config/hypr/aequalyn/" .. file)
  if not ok then print("[aequalyn] " .. file .. ": " .. tostring(err)) end
end

return M
