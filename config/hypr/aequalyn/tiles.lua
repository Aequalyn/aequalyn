-- How the windows of Aequalyn's layouts look, as in Tableau.
--
-- Every tiled window on one of Aequalyn's layouts carries the "aq-tile" tag; named window
-- rules give those windows
--   outline   their border, in px ("theme": the border Hyprland has, Settings -> Hyprland)
--   others    what the windows you're not using wear: "theme" (the theme's inactive
--             border), "same" (the focused window's outline, its gradient included)
--             or "hidden" (no outline)
-- Both come from layouts.lua's options (aequalyn-layout option outline / others).
-- The rules are made once the config has loaded, so they use the theme's colors
-- (colors.lua loads after the layouts).

local hl = _G.hl
local L = _G.aequalyn_layouts
local T = {}
_G.aequalyn_tiles = T

local TAG = "aq-tile"

local function has_tag(window, name)
  for _, tag in ipairs(type(window.tags) == "table" and window.tags or {}) do
    if tag == name or tag == name .. "*" then return true end
  end
  return false
end

local function tag_window(window, tag, on)
  hl.dispatch(hl.dsp.window.tag({ window = "address:" .. window.address, tag = (on and "+" or "-") .. tag }))
end

-- the theme's active border as a border_color gradient: "rgba(..) rgba(..) 45deg"
local function accent(alpha)
  local ok, opt = pcall(hl.get_config, "general.col.active_border")
  local argb = ok and type(opt) == "table" and type(opt.colors) == "table" and opt.colors[1]
  local rgb = type(argb) == "string" and argb:match("^0[xX]%x%x(%x%x%x%x%x%x)$") or "ffffff"
  return "rgba(" .. rgb .. alpha .. ")"
end
local function active_gradient()
  local ok, opt = pcall(hl.get_config, "general.col.active_border")
  local parts = {}
  if ok and type(opt) == "table" and type(opt.colors) == "table" then
    for _, color in ipairs(opt.colors) do
      local alpha, rgb
      if type(color) == "string" then alpha, rgb = color:match("^0[xX](%x%x)(%x%x%x%x%x%x)$") end
      if rgb then parts[#parts + 1] = "rgba(" .. rgb .. alpha .. ")" end
      if #parts == 10 then break end
    end
  end
  if #parts == 0 then return accent("ff") .. " 0deg" end
  local angle = ok and type(opt) == "table" and tonumber(opt.angle) or 0
  parts[#parts + 1] = string.format("%ddeg", math.floor(angle + 0.5))
  return table.concat(parts, " ")
end

local function opts() return (L and L.opts) or {} end
local function outline() return tonumber(opts().outline) end      -- nil: as the theme
local function others() return opts().others or "theme" end
-- anything to change about these windows?
function T.styled() return outline() ~= nil or others() ~= "theme" end

-- the rules; a config reload starts a fresh Lua state, so they're made once per load
function T.rules()
  local tile = { name = "aequalyn-tile", match = { tag = TAG } }
  if outline() then tile.border_size = outline() end
  local active = active_gradient()
  if others() == "same" then
    tile.border_color = active .. " " .. active
  elseif others() == "hidden" then
    tile.border_color = active .. " rgba(00000000) 0deg"
  end
  pcall(hl.window_rule, tile)
end

-- tag the windows that should wear it, untag the rest (left from another layout or a
-- reload, or turned off)
function T.sweep()
  local on = T.styled()
  for _, w in ipairs(hl.get_windows()) do
    local want = on and w.mapped and not w.floating and L ~= nil and L.is_aq(w.workspace)
    if w.address and has_tag(w, TAG) ~= want then tag_window(w, TAG, want) end
  end
end

-- windows come, go, float and move between workspaces; settle first, then sweep once
local pending = false
local function sweep_soon()
  if pending then return end
  pending = true
  hl.timer(function() pending = false; pcall(T.sweep) end, { timeout = 60, type = "oneshot" })
end

local function loaded() pcall(T.rules); sweep_soon() end
hl.on("config.reloaded", loaded)
hl.on("hyprland.start", loaded)
for _, ev in ipairs({ "window.open", "window.move_to_workspace", "window.update_state", "workspace.active" }) do
  pcall(hl.on, ev, sweep_soon)
end

return T
