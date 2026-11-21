---------------------------------------------------------------------- keybinds
-- dofile'd chunks don't see hyprland.lua's locals, so this file needs its own.
local HOME = os.getenv("HOME") or ""
local M      = "SUPER"
-- Resolve the default terminal / file manager / browser from the XDG defaults
-- so the keybinds below follow the choices made in Settings -> Default apps.
local function _xdg_default(mime, fallback)
    local f = io.popen("xdg-mime query default " .. mime .. " 2>/dev/null")
    local id = f and f:read("*l") or ""
    if f then f:close() end
    id = id and id:gsub("%s+", "") or ""
    if id ~= "" then return "gtk-launch " .. id:gsub("%.desktop$", "") end
    return fallback
end
local function _terminal_default(fallback)
    local path = os.getenv("HOME") .. "/.config/xdg-terminals.list"
    local f = io.open(path, "r")
    local id = ""
    if f then id = f:read("*l") or ""; f:close() end
    id = id:gsub("%s+", "")
    if id ~= "" then return "gtk-launch " .. id:gsub("%.desktop$", "") end
    return fallback
end
local term    = _terminal_default("kitty")
local files   = _xdg_default("inode/directory", "nautilus")
local browser = _xdg_default("text/html", "chromium")

-- Apps & Aequalyn shell
hl.bind(M .. " + RETURN",  hl.dsp.exec_cmd(term))
hl.bind(M .. " + E",       hl.dsp.exec_cmd(files))
hl.bind(M .. " + ALT + F", hl.dsp.exec_cmd("qs ipc call -- aequalyn-fm open " .. HOME)) -- Aequalyn FM
hl.bind(M .. " + B",       hl.dsp.exec_cmd(browser))
hl.bind(M .. " + SPACE",   hl.dsp.exec_cmd("qs ipc call programs toggle"))  -- Programs menu
hl.bind(M .. " + D",       hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind(M .. " + G",       hl.dsp.exec_cmd("qs ipc call snap toggle"))       -- Snap layouts on floating windows
hl.bind(M .. " + ALT + A", hl.dsp.exec_cmd("qs ipc call defaults toggle")) -- Default apps launcher
hl.bind(M .. " + ALT + S",       hl.dsp.exec_cmd("qs ipc call store toggle"))   -- Store: plugins, themes, cursors, looks
hl.bind(M .. " + COMMA",   hl.dsp.exec_cmd("qs ipc call aequalyn settings"))
-- Window layouts: Super + L steps through them, the control center shows them all
hl.bind(M .. " + L",         hl.dsp.exec_cmd("aequalyn-layout next"))
hl.bind(M .. " + SHIFT + L", hl.dsp.exec_cmd("aequalyn-layout prev"))
hl.bind(M .. " + ALT + L",   hl.dsp.exec_cmd("qs ipc call aequalyn page arrange"))
hl.bind(M .. " + CTRL + left",  hl.dsp.layout("swapprev"))
hl.bind(M .. " + CTRL + right", hl.dsp.layout("swapnext"))
-- Super + Ctrl + L (pick a layout), Super + Z, Super + - / =, Alt + Tab and the arrow
-- keys below are made layout-aware in aequalyn/keys.lua.

-- The theme and wallpaper picker, over the blurred desktop
hl.bind(M .. " + T",       hl.dsp.exec_cmd("qs ipc call atelier toggle themes"))
hl.bind(M .. " + W",       hl.dsp.exec_cmd("qs ipc call atelier toggle wallpapers"))
hl.bind(M .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call aequalyn page rotation"))
hl.bind(M .. " + CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("qs ipc call atelier toggle themes"))
hl.bind(M .. " + CTRL + SPACE", hl.dsp.exec_cmd("aequalyn-wallpaper next"))
hl.bind(M .. " + O",       hl.dsp.exec_cmd("qs ipc call monitors toggle"))
hl.bind(M .. " + SHIFT + O", hl.dsp.exec_cmd("qs ipc call monitors refresh"))
hl.bind(M .. " + SHIFT + C", hl.dsp.exec_cmd("qs ipc call idle toggle"))
hl.bind(M .. " + I",       hl.dsp.exec_cmd("sudo aequalyn-install"))
hl.bind(M .. " + N",       hl.dsp.exec_cmd("qs ipc call notifications dismiss_all"))
hl.bind(M .. " + SHIFT + N", hl.dsp.exec_cmd("qs ipc call notifications dnd_toggle"))
hl.bind(M .. " + SHIFT + R", hl.dsp.exec_cmd("aequalyn-record toggle"))

-- Windows
hl.bind(M .. " + Q", hl.dsp.window.close())
hl.bind(M .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(M .. " + P", hl.dsp.window.pseudo())
hl.bind(M .. " + F", hl.dsp.window.fullscreen())
hl.bind(M .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(M .. " + SHIFT + M", hl.dsp.exec_cmd("qs ipc call power toggle"))

-- The built-in pack (shell plugins). Each key does something only while its plugin is
-- on: control center › Plugins.
hl.bind(M .. " + SLASH",          hl.dsp.exec_cmd("qs ipc call keyHints toggle"))     -- Key hints
hl.bind(M .. " + SHIFT + SPACE",  hl.dsp.exec_cmd("qs ipc call palette toggle"))      -- Command palette
hl.bind(M .. " + EQUAL",          hl.dsp.exec_cmd("qs ipc call calculator toggle"))   -- Calculator
hl.bind(M .. " + PERIOD",         hl.dsp.exec_cmd("qs ipc call emoji toggle"))        -- Emoji
hl.bind(M .. " + SHIFT + P",      hl.dsp.exec_cmd("qs ipc call colorPicker pick"))    -- Pick a colour on the screen
hl.bind(M .. " + ALT + N",        hl.dsp.exec_cmd("qs ipc call notes toggle"))        -- Quick notes
hl.bind(M .. " + SHIFT + ESCAPE", hl.dsp.exec_cmd("qs ipc call sysmon toggle"))       -- System monitor
hl.bind(M .. " + ALT + X",        hl.dsp.exec_cmd("qs ipc call screenText capture"))  -- Copy text from the screen
hl.bind(M .. " + ALT + T",        hl.dsp.exec_cmd("qs ipc call timer toggle"))        -- Timer
-- NOTE: Super + Alt + F is already bound to Aequalyn FM above, so the Focus toggle
-- (Super + Alt + F in upstream) is intentionally not added to avoid an overlap.

-- Focus / move
-- Super + arrows (focus) and Super + Shift + arrows (swap): aequalyn/keys.lua

-- Workspaces
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(M .. " + " .. key,        hl.dsp.focus({ workspace = "r~" .. i }))
    hl.bind(M .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = "r~" .. i }))
end
hl.bind(M .. " + S",        hl.dsp.workspace.toggle_special("magic"))
hl.bind(M .. " + SHIFT + S",  hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(M .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse
hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots and recording: Print, or Super + Ctrl + S on a keyboard without one.
-- Every screenshot is saved to ~/Pictures/Screenshots; "copied" also puts it on the clipboard.
hl.bind("PRINT",                   hl.dsp.exec_cmd("aequalyn-screenshot region-clip"))   -- A part, saved and copied
hl.bind("SHIFT + PRINT",           hl.dsp.exec_cmd("aequalyn-screenshot full-clip"))     -- The whole screen, saved and copied
hl.bind(M .. " + PRINT",           hl.dsp.exec_cmd("aequalyn-screenshot region-file"))   -- A part, saved only
hl.bind(M .. " + CTRL + S",        hl.dsp.exec_cmd("aequalyn-screenshot region-clip"))   -- A part, saved and copied
hl.bind(M .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("aequalyn-screenshot full-clip"))    -- The whole screen, saved and copied
hl.bind(M .. " + CTRL + R",        hl.dsp.exec_cmd("aequalyn-record toggle"))            -- Record the screen: start or stop
hl.bind("XF86SelectiveScreenshot", hl.dsp.exec_cmd("aequalyn-screenshot region-clip"))

-- Media / brightness
local media = {
    { "XF86AudioRaiseVolume",   "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" },
    { "XF86AudioLowerVolume",   "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
    { "XF86AudioMute",          "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    { "XF86AudioMicMute",       "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
    { "XF86MonBrightnessUp",    "brightnessctl -e4 -n2 set 5%+" },
    { "XF86MonBrightnessDown",  "brightnessctl -e4 -n2 set 5%-" },
    { "XF86AudioPlay",          "playerctl play-pause" },
    { "XF86AudioPause",         "playerctl play-pause" },
    { "XF86AudioNext",          "playerctl next" },
    { "XF86AudioPrev",          "playerctl previous" },
}
for _, b in ipairs(media) do
    hl.bind(b[1], hl.dsp.exec_cmd(b[2]), { locked = true, repeating = true })
end

-- The window switcher keys (Alt + Tab / Super + Tab) are not in here: the
-- Altscape plugin manages them in a marked block at the end of hyprland.lua,
-- so they always load after these and win. Change them in the control
-- center's Window switcher page.

-- Load the optional floating titlebar plugin on demand (avoids startup crashes).
if hl.bind and hl.timer then
  pcall(hl.bind, "SUPER + SHIFT + T", function()
    hl.exec_cmd("hyprctl plugin load " .. HOME .. "/.local/lib/aequalyn/hyprbars.so")
    pcall(hl.timer, function()
      if _G.aequalyn_floating then _G.aequalyn_floating.load_decorations() end
    end, { timeout = 1000, type = "oneshot" })
  end, { description = "Load floating titlebar" })
end
