-- Aequalyn window layouts: the geometry only.
--
-- Every layout is a function (n, area, opts) -> list of n rectangles
-- { x, y, w, h }. Slot 1 is the main window (the one you promote with
-- Super + Z); the others follow in the order windows opened. Nothing here
-- talks to Hyprland, so the same file draws the pictures in Atelier and
-- runs under a plain Lua interpreter in tests.
--
-- opts: pane   share of the screen the main pane gets (0.30 .. 0.85)
--       middle share of the width the middle window gets (Triptych, Portrait)
--       gap    pixels between tiles in Spread

local G = {}

local function r(x, y, w, h) return { x = x, y = y, w = w, h = h } end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- n equal slices of `a`, side by side (horizontal) or stacked.
local function split(a, n, horizontal, out)
  out = out or {}
  if n <= 0 then return out end
  for i = 0, n - 1 do
    if horizontal then
      local x0 = a.x + math.floor(a.w * i / n)
      local x1 = a.x + math.floor(a.w * (i + 1) / n)
      out[#out + 1] = r(x0, a.y, x1 - x0, a.h)
    else
      local y0 = a.y + math.floor(a.h * i / n)
      local y1 = a.y + math.floor(a.h * (i + 1) / n)
      out[#out + 1] = r(a.x, y0, a.w, y1 - y0)
    end
  end
  return out
end

-- Rows of `cols` cells; the last row's cells stretch to fill it.
local function grid(a, n, cols, out)
  out = out or {}
  if n <= 0 then return out end
  cols = clamp(cols, 1, n)
  local rows = math.ceil(n / cols)
  local rowsl = split(a, rows, false)
  local left = n
  for i = 1, rows do
    local k = math.min(cols, left)
    split(rowsl[i], k, true, out)
    left = left - k
  end
  return out
end

-- The column count whose cells come closest to the screen's own shape.
local function shape(a, n, target)
  target = target or (a.w / math.max(1, a.h))
  local best, best_cost = 1, math.huge
  for cols = 1, n do
    local rows = math.ceil(n / cols)
    local cell = (a.w / cols) / (a.h / rows)
    local empty = cols * rows - n
    local cost = math.abs(math.log(cell / target)) + empty * 0.35
    if cost < best_cost then best, best_cost = cols, cost end
  end
  return best
end

-- Miniatures in a strip: each `aspect` wide for its height, centred.
local function minis(a, n, horizontal, aspect, out)
  out = out or {}
  if n <= 0 then return out end
  aspect = aspect or 1.6
  if horizontal then
    local w = math.min(a.w / n, a.h * aspect)
    local h = math.min(a.h, w / aspect)
    local x0 = a.x + (a.w - w * n) / 2
    local y0 = a.y + (a.h - h) / 2
    for i = 0, n - 1 do out[#out + 1] = r(math.floor(x0 + i * w), math.floor(y0), math.floor(w), math.floor(h)) end
  else
    local h = math.min(a.h / n, a.w / aspect)
    local w = math.min(a.w, h * aspect)
    local x0 = a.x + (a.w - w) / 2
    local y0 = a.y + (a.h - h * n) / 2
    for i = 0, n - 1 do out[#out + 1] = r(math.floor(x0), math.floor(y0 + i * h), math.floor(w), math.floor(h)) end
  end
  return out
end

local function append(dst, src) for _, v in ipairs(src) do dst[#dst + 1] = v end return dst end

-- Split the extras between two sides alternately: 1st left, 2nd right, ...
local function alternate(k)
  local a, b = math.ceil(k / 2), math.floor(k / 2)
  return a, b
end

-- Re-order rectangles so that slot i of the result is the i-th extra,
-- taking extras alternately from list A and list B.
local function interleave(la, lb)
  local out, i, j = {}, 1, 1
  while i <= #la or j <= #lb do
    if i <= #la then out[#out + 1] = la[i]; i = i + 1 end
    if j <= #lb then out[#out + 1] = lb[j]; j = j + 1 end
  end
  return out
end

---------------------------------------------------------------- focus layouts
-- The main window large, the others as small windows around it.

function G.portrait(n, a, o)
  if n == 1 then return { a } end
  local mw = math.floor(a.w * clamp(o.middle or 0.56, 0.3, 0.8))
  local sw = math.floor((a.w - mw) / 2)
  local main = r(a.x + sw, a.y, mw, a.h)
  local nl, nr = alternate(n - 1)
  local left = minis(r(a.x, a.y, sw, a.h), nl, false, 1.6)
  local right = minis(r(a.x + sw + mw, a.y, a.w - sw - mw, a.h), nr, false, 1.6)
  return append({ main }, interleave(left, right))
end

function G.landscape(n, a, o)
  if n == 1 then return { a } end
  local mh = math.floor(a.h * clamp(o.pane or 0.62, 0.4, 0.85))
  local sh = math.floor((a.h - mh) / 2)
  local main = r(a.x, a.y + sh, a.w, mh)
  local nt, nb = alternate(n - 1)
  local top = minis(r(a.x, a.y, a.w, sh), nt, true, 1.6)
  local bottom = minis(r(a.x, a.y + sh + mh, a.w, a.h - sh - mh), nb, true, 1.6)
  return append({ main }, interleave(top, bottom))
end

function G.centerpiece(n, a, o)
  if n == 1 then return { a } end
  local mw, mh = math.floor(a.w * 0.56), math.floor(a.h * 0.62)
  local mx, my = a.x + math.floor((a.w - mw) / 2), a.y + math.floor((a.h - mh) / 2)
  local main = r(mx, my, mw, mh)
  -- clockwise: top, right, bottom, left
  local bands = {
    { a = r(a.x, a.y, a.w, my - a.y), h = true },
    { a = r(mx + mw, my, a.x + a.w - mx - mw, mh), h = false },
    { a = r(a.x, my + mh, a.w, a.y + a.h - my - mh), h = true },
    { a = r(a.x, my, mx - a.x, mh), h = false },
  }
  local counts = { 0, 0, 0, 0 }
  for i = 1, n - 1 do counts[(i - 1) % 4 + 1] = counts[(i - 1) % 4 + 1] + 1 end
  local per = {}
  for b = 1, 4 do per[b] = minis(bands[b].a, counts[b], bands[b].h, 1.6) end
  local out, idx = { main }, { 1, 1, 1, 1 }
  for i = 1, n - 1 do
    local b = (i - 1) % 4 + 1
    out[#out + 1] = per[b][idx[b]]; idx[b] = idx[b] + 1
  end
  return out
end

local function band_layout(n, a, o, where)
  if n == 1 then return { a } end
  local bh = math.floor(a.h * 0.2)
  local main, strip
  if where == "top" then
    strip, main = r(a.x, a.y, a.w, bh), r(a.x, a.y + bh, a.w, a.h - bh)
  else
    main, strip = r(a.x, a.y, a.w, a.h - bh), r(a.x, a.y + a.h - bh, a.w, bh)
  end
  return append({ main }, minis(strip, n - 1, true, 1.6))
end
function G.stage(n, a, o) return band_layout(n, a, o, "top") end
function G.theatre(n, a, o) return band_layout(n, a, o, "bottom") end

local function gallery(n, a, o, edge)
  if n == 1 then return { a } end
  local p = clamp(o.pane or 0.62, 0.3, 0.85)
  local main, rest
  if edge == "right" then
    local w = math.floor(a.w * p); main, rest = r(a.x, a.y, w, a.h), r(a.x + w, a.y, a.w - w, a.h)
  elseif edge == "left" then
    local w = math.floor(a.w * p); main, rest = r(a.x + a.w - w, a.y, w, a.h), r(a.x, a.y, a.w - w, a.h)
  elseif edge == "bottom" then
    local h = math.floor(a.h * p); main, rest = r(a.x, a.y, a.w, h), r(a.x, a.y + h, a.w, a.h - h)
  else
    local h = math.floor(a.h * p); main, rest = r(a.x, a.y + a.h - h, a.w, h), r(a.x, a.y, a.w, a.h - h)
  end
  -- A grid of miniatures: at least two across (or two rows) once there are
  -- three, each cell shrunk to a screen-shaped window in its middle.
  local k = n - 1
  local cols
  if edge == "left" or edge == "right" then
    cols = k >= 3 and math.max(2, shape(rest, k, 1.6)) or 1
  else
    cols = k >= 4 and math.max(math.ceil(k / 2), shape(rest, k, 1.6)) or k
  end
  local cells = grid(rest, k, cols)
  local pad = math.floor(math.min(rest.w, rest.h) * 0.03)
  for i, c in ipairs(cells) do
    local w, h = c.w - 2 * pad, c.h - 2 * pad
    if w / h > 1.6 then w = math.floor(h * 1.6) else h = math.floor(w / 1.6) end
    cells[i] = r(c.x + math.floor((c.w - w) / 2), c.y + math.floor((c.h - h) / 2), w, h)
  end
  return append({ main }, cells)
end
function G.gallery_right(n, a, o) return gallery(n, a, o, "right") end
function G.gallery_bottom(n, a, o) return gallery(n, a, o, "bottom") end
function G.gallery_left(n, a, o) return gallery(n, a, o, "left") end
function G.gallery_top(n, a, o) return gallery(n, a, o, "top") end

----------------------------------------------------------------- pane layouts
-- One large pane for the main window, the rest share what's left.

local function diptych(n, a, o, edge)
  if n == 1 then return { a } end
  local p = clamp(o.pane or 0.62, 0.3, 0.85)
  if edge == "left" or edge == "right" then
    local w = math.floor(a.w * p)
    local mx = edge == "left" and a.x or a.x + a.w - w
    local sx = edge == "left" and a.x + w or a.x
    return split(r(sx, a.y, a.w - w, a.h), n - 1, false, { r(mx, a.y, w, a.h) })
  end
  local h = math.floor(a.h * p)
  local my = edge == "top" and a.y or a.y + a.h - h
  local sy = edge == "top" and a.y + h or a.y
  return split(r(a.x, sy, a.w, a.h - h), n - 1, true, { r(a.x, my, a.w, h) })
end
function G.diptych_left(n, a, o) return diptych(n, a, o, "left") end
function G.diptych_right(n, a, o) return diptych(n, a, o, "right") end
function G.diptych_top(n, a, o) return diptych(n, a, o, "top") end
function G.diptych_bottom(n, a, o) return diptych(n, a, o, "bottom") end

function G.triptych(n, a, o)
  if n == 1 then return { a } end
  if n == 2 then return split(a, 2, true) end
  local mw = math.floor(a.w * clamp(o.middle or 0.5, 0.3, 0.8))
  local sw = math.floor((a.w - mw) / 2)
  local nl, nr = alternate(n - 1)
  local left = split(r(a.x, a.y, sw, a.h), nl, false)
  local right = split(r(a.x + sw + mw, a.y, a.w - sw - mw, a.h), nr, false)
  return append({ r(a.x + sw, a.y, mw, a.h) }, interleave(left, right))
end

function G.bento(n, a, o)
  if n <= 2 then return diptych(n, a, o, "left") end
  local w = math.floor(a.w * clamp(o.pane or 0.62, 0.3, 0.85))
  local side = r(a.x + w, a.y, a.w - w, a.h)
  local th = math.floor(side.h * 0.55)
  local out = { r(a.x, a.y, w, a.h), r(side.x, side.y, side.w, th) }
  return split(r(side.x, side.y + th, side.w, side.h - th), n - 2, true, out)
end

function G.hero(n, a, o)
  if n <= 2 then return diptych(n, a, o, "top") end
  local h = math.floor(a.h * clamp(o.pane or 0.62, 0.3, 0.85))
  local bottom = r(a.x, a.y + h, a.w, a.h - h)
  local half = math.floor(bottom.w / 2)
  local out = { r(a.x, a.y, a.w, h), r(bottom.x, bottom.y, half, bottom.h) }
  return split(r(bottom.x + half, bottom.y, bottom.w - half, bottom.h), n - 2, true, out)
end

function G.corner(n, a, o)
  if n <= 2 then return diptych(n, a, o, "left") end
  local p = clamp(o.pane or 0.62, 0.3, 0.85)
  local w, h = math.floor(a.w * p), math.floor(a.h * p)
  local k = n - 1
  local kr = math.ceil(k / 2)
  local out = { r(a.x, a.y, w, h) }
  split(r(a.x + w, a.y, a.w - w, a.h), kr, false, out)
  split(r(a.x, a.y + h, w, a.h - h), k - kr, true, out)
  return out
end

function G.panels(n, a, o)
  if n == 1 then return { a } end
  local w = math.floor(a.w * clamp(o.pane or 0.5, 0.3, 0.85))
  return split(r(a.x + w, a.y, a.w - w, a.h), n - 1, true, { r(a.x, a.y, w, a.h) })
end

----------------------------------------------------------------- grid layouts

function G.mosaic(n, a, o)
  return grid(a, n, shape(a, n))
end

function G.spread(n, a, o)
  local g = clamp(o.gap or 24, 0, 120)
  local inner = r(a.x + g, a.y + g, a.w - 2 * g, a.h - 2 * g)
  local cells = grid(inner, n, shape(inner, n))
  for i, c in ipairs(cells) do
    cells[i] = r(c.x + g / 2, c.y + g / 2, math.max(1, c.w - g), math.max(1, c.h - g))
  end
  return cells
end

function G.ledger(n, a, o) return grid(a, n, 2) end
function G.shelves(n, a, o) return grid(a, n, 3) end

function G.masonry(n, a, o)
  local cols = math.max(1, math.ceil(math.sqrt(n)))
  local colr = split(a, math.min(cols, n), true)
  local counts = {}
  for i = 1, #colr do counts[i] = 0 end
  for i = 1, n do local c = (i - 1) % #colr + 1; counts[c] = counts[c] + 1 end
  local per = {}
  for c = 1, #colr do per[c] = split(colr[c], counts[c], false) end
  local out, idx = {}, {}
  for c = 1, #colr do idx[c] = 1 end
  for i = 1, n do
    local c = (i - 1) % #colr + 1
    out[#out + 1] = per[c][idx[c]]; idx[c] = idx[c] + 1
  end
  return out
end

function G.quadrant(n, a, o)
  if n <= 2 then return split(a, n, true) end
  local hw, hh = math.floor(a.w / 2), math.floor(a.h / 2)
  if n == 3 then
    return { r(a.x, a.y, hw, a.h), r(a.x + hw, a.y, a.w - hw, hh), r(a.x + hw, a.y + hh, a.w - hw, a.h - hh) }
  end
  local out = { r(a.x, a.y, hw, hh), r(a.x + hw, a.y, a.w - hw, hh), r(a.x, a.y + hh, hw, a.h - hh) }
  local last = r(a.x + hw, a.y + hh, a.w - hw, a.h - hh)
  return append(out, grid(last, n - 3, shape(last, n - 3)))
end

function G.twin_columns(n, a, o)
  if n == 1 then return { a } end
  local cols = split(a, 2, true)
  local nl, nr = alternate(n)
  return interleave(split(cols[1], nl, false), split(cols[2], nr, false))
end

function G.ultrawide(n, a, o)
  if n == 1 then return { a } end
  local cols = split(a, 3, true)
  if n == 2 then return { cols[2], r(cols[3].x, a.y, cols[3].w, a.h) } end
  local k = n - 1
  local nl = math.ceil(k / 2)
  local out = { cols[2] }
  split(cols[1], nl, false, out)
  split(cols[3], k - nl, false, out)
  return out
end

----------------------------------------------------------------- flow layouts

function G.strip(n, a, o) return split(a, n, true) end
function G.column(n, a, o) return split(a, n, false) end

-- Each window takes `ratio` of what is left; `turns` lists the side it takes.
-- After six cuts (three at the golden ratio) the remaining windows share what's left as a grid, so a
-- crowded workspace never ends in slivers.
local function carve(n, a, ratio, turns)
  local out, rest = {}, r(a.x, a.y, a.w, a.h)
  for i = 1, n do
    if i == n then out[#out + 1] = rest; break end
    if i > (ratio > 0.55 and 3 or 6) then
      grid(rest, n - i + 1, shape(rest, n - i + 1), out)
      break
    end
    local side = turns[(i - 1) % #turns + 1]
    if side == "left" or side == "right" then
      local w = math.floor(rest.w * ratio)
      if side == "left" then
        out[#out + 1] = r(rest.x, rest.y, w, rest.h); rest = r(rest.x + w, rest.y, rest.w - w, rest.h)
      else
        out[#out + 1] = r(rest.x + rest.w - w, rest.y, w, rest.h); rest = r(rest.x, rest.y, rest.w - w, rest.h)
      end
    else
      local h = math.floor(rest.h * ratio)
      if side == "top" then
        out[#out + 1] = r(rest.x, rest.y, rest.w, h); rest = r(rest.x, rest.y + h, rest.w, rest.h - h)
      else
        out[#out + 1] = r(rest.x, rest.y + rest.h - h, rest.w, h); rest = r(rest.x, rest.y, rest.w, rest.h - h)
      end
    end
  end
  return out
end
function G.spiral(n, a, o) return carve(n, a, 0.5, { "left", "top", "right", "bottom" }) end
function G.fibonacci(n, a, o) return carve(n, a, 0.5, { "left", "top" }) end
function G.golden(n, a, o) return carve(n, a, 0.618, { "left", "top", "right", "bottom" }) end

function G.cascade(n, a, o)
  if n == 1 then return { a } end
  local w, h = math.floor(a.w * 0.68), math.floor(a.h * 0.68)
  local sx, sy = (a.w - w) / (n - 1), (a.h - h) / (n - 1)
  local out = {}
  -- main window front-most at the bottom-right end of the stair
  for i = 1, n do
    local step = n - i
    out[i] = r(a.x + math.floor(sx * step), a.y + math.floor(sy * step), w, h)
  end
  return out
end

function G.pinwheel(n, a, o)
  if n < 5 then return G.spiral(n, a, o) end
  local qw, qh = math.floor(a.w / 4), math.floor(a.h / 4)
  local main = r(a.x + qw, a.y + qh, a.w - 2 * qw, a.h - 2 * qh)
  local arms = {
    { a = r(a.x, a.y, a.w - qw, qh), h = true },                       -- top
    { a = r(a.x + a.w - qw, a.y, qw, a.h - qh), h = false },           -- right
    { a = r(a.x + qw, a.y + a.h - qh, a.w - qw, qh), h = true },       -- bottom
    { a = r(a.x, a.y + qh, qw, a.h - qh), h = false },                 -- left
  }
  local counts = { 0, 0, 0, 0 }
  for i = 1, n - 1 do counts[(i - 1) % 4 + 1] = counts[(i - 1) % 4 + 1] + 1 end
  local per = {}
  for k = 1, 4 do per[k] = split(arms[k].a, counts[k], arms[k].h) end
  local out, idx = { main }, { 1, 1, 1, 1 }
  for i = 1, n - 1 do
    local k = (i - 1) % 4 + 1
    out[#out + 1] = per[k][idx[k]]; idx[k] = idx[k] + 1
  end
  return out
end

-- Floating is applied as real floating windows, but a geometry is kept here so
-- callers that want a picture for the catalogue have something sane to draw.
function G.floating(n, a, o) return grid(a, n, shape(a, n, 1.6)) end

------------------------------------------------------------------- catalogue
-- The order Super + L goes through them, grouped for the picker.

G.catalogue = {
  { id = "portrait",       name = "Portrait",       group = "Focus", hint = "The main window in the middle, the others small at the sides" },
  { id = "landscape",      name = "Landscape",      group = "Focus", hint = "A wide main window, the others small above and below" },
  { id = "centerpiece",    name = "Centerpiece",    group = "Focus", hint = "The main window in the middle, the others all round it" },
  { id = "stage",          name = "Stage",          group = "Focus", hint = "The others in a slim row on top, the main window below" },
  { id = "theatre",        name = "Theatre",        group = "Focus", hint = "The main window on top, the others in a slim row below" },
  { id = "gallery_right",  name = "Gallery Right",  group = "Focus", hint = "A large pane, the others in a grid on the right" },
  { id = "gallery_bottom", name = "Gallery Bottom", group = "Focus", hint = "A large pane, the others in a grid below" },
  { id = "gallery_left",   name = "Gallery Left",   group = "Focus", hint = "A large pane, the others in a grid on the left" },
  { id = "gallery_top",    name = "Gallery Top",    group = "Focus", hint = "A large pane, the others in a grid above" },
  { id = "diptych_left",   name = "Diptych Left",   group = "Panes", hint = "A large pane on the left, the rest stacked on the right" },
  { id = "diptych_right",  name = "Diptych Right",  group = "Panes", hint = "A large pane on the right, the rest stacked on the left" },
  { id = "diptych_top",    name = "Diptych Top",    group = "Panes", hint = "A large pane on top, the rest side by side below" },
  { id = "diptych_bottom", name = "Diptych Bottom", group = "Panes", hint = "A large pane below, the rest side by side above" },
  { id = "triptych",       name = "Triptych",       group = "Panes", hint = "The main window in the middle, the rest stacked either side" },
  { id = "bento",          name = "Bento",          group = "Panes", hint = "A large pane, one window beside it, the rest in a row under that one" },
  { id = "hero",           name = "Hero",           group = "Panes", hint = "A wide pane on top, one half below, the rest sharing the other half" },
  { id = "corner",         name = "Corner",         group = "Panes", hint = "The main window in a corner, the rest in an L around it" },
  { id = "panels",         name = "Panels",         group = "Panes", hint = "Half the screen for the main window, tall panels for the rest" },
  { id = "ultrawide",      name = "Ultrawide",      group = "Panes", hint = "Three columns: the main window in the middle, the rest at the sides" },
  { id = "mosaic",         name = "Mosaic",         group = "Grids", hint = "Equal tiles in the grid that suits the screen best" },
  { id = "spread",         name = "Spread",         group = "Grids", hint = "A grid with room between the tiles" },
  { id = "ledger",         name = "Ledger",         group = "Grids", hint = "Two columns, filled row by row" },
  { id = "shelves",        name = "Shelves",        group = "Grids", hint = "Rows of three" },
  { id = "masonry",        name = "Masonry",        group = "Grids", hint = "Columns of different heights, like a brick wall" },
  { id = "quadrant",       name = "Quadrant",       group = "Grids", hint = "Four quarters; extra windows share the last one" },
  { id = "twin_columns",   name = "Twin Columns",   group = "Grids", hint = "Two columns, windows taking turns left and right" },
  { id = "strip",          name = "Strip",          group = "Flow",  hint = "Side by side in one row" },
  { id = "column",         name = "Column",         group = "Flow",  hint = "One above the other" },
  { id = "spiral",         name = "Spiral",         group = "Flow",  hint = "Each window halves what's left, turning as it goes" },
  { id = "fibonacci",      name = "Fibonacci",      group = "Flow",  hint = "Each window halves what's left, always toward the corner" },
  { id = "golden",         name = "Golden",         group = "Flow",  hint = "A spiral cut at the golden ratio" },
  { id = "pinwheel",       name = "Pinwheel",       group = "Flow",  hint = "The main window in the middle, four arms turning round it" },
  { id = "cascade",        name = "Cascade",        group = "Flow",  hint = "Overlapping like a stair, the main window in front" },
}

-- Hyprland's own layouts, listed so the picker and Super + L can use them too.
G.native = {
  { id = "dwindle",   name = "Dwindle",   group = "Hyprland", hint = "Every window splits the space it lands in" },
  { id = "master",    name = "Master",    group = "Hyprland", hint = "A master area and a stack" },
  { id = "scrolling", name = "Scrolling", group = "Hyprland", hint = "Columns on a strip that scrolls" },
  { id = "monocle",   name = "Monocle",   group = "Hyprland", hint = "One window at a time, full size" },
  { id = "floating",  name = "Floating",  group = "Hyprland", hint = "Windows float freely, with titlebars and snap zones" },
}

return G
