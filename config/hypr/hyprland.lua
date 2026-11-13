-- Aequalyn -- Hyprland configuration (Hyprland 0.57+ Lua config).
--
-- Generated files live under ~/.config/hypr/aequalyn/:
--   look.lua    -- from ~/.config/aequalyn/settings.json (aequalyn-hypr-apply)
--   colors.lua  -- from the wallpaper (matugen) or the selected theme
--   layouts.lua / geometry.lua -- Aequalyn's window layouts (shipped)
--   workspace-layouts.lua      -- which layout each workspace uses (aequalyn-layout)
--   user.lua    -- hand overrides, loaded last
-- The display manager writes monitors.lua; the `dofile` call below is what its
-- persistence check looks for.

local HOME = os.getenv("HOME") or ""

local function include(rel)
    local path = HOME .. "/.config/hypr/" .. rel
    local ok, err = pcall(dofile, path)
    if not ok then
        print("[aequalyn] could not load " .. path .. ": " .. tostring(err))
    end
end

-- Fallback first, then the generated monitors.lua (written by the Aequalyn
-- display manager). dofile (not require) so `hyprctl reload` re-reads it.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
pcall(dofile, (os.getenv("HOME") or "") .. "/.config/hypr/monitors.lua")

-- Generated + user config (dofile, not require, so `hyprctl reload` re-reads
-- them even though Lua caches modules).
include("aequalyn/clipboard.lua")
include("aequalyn/look.lua")
include("aequalyn/layouts.lua")            -- 33 window layouts (geometry.lua)
include("aequalyn/workspace-layouts.lua")  -- per-workspace choices (aequalyn-layout)
include("aequalyn/colors.lua")
include("aequalyn/user.lua")

------------------------------------------------------------------ environment
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_THEME", "adw-gtk3-dark")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")

-------------------------------------------------------------------- autostart
-- Absolute path + `bash`: Hyprland's executor does not inherit the login
-- shell's PATH, and mkarchiso can strip the exec bit from ~/.local/bin files.
local session_start = "bash " .. HOME .. "/.local/bin/aequalyn-session-start"

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd(session_start)
end)

------------------------------------------------------------------------ input
hl.config({
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = { natural_scroll = true },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---------------------------------------------------------------------- keybinds
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
local menu    = "fuzzel"

-- Apps & Aequalyn shell
hl.bind(M .. " + RETURN",  hl.dsp.exec_cmd(term))
hl.bind(M .. " + E",       hl.dsp.exec_cmd(files))
hl.bind(M .. " + B",       hl.dsp.exec_cmd(browser))
hl.bind(M .. " + SPACE",   hl.dsp.exec_cmd(menu))
hl.bind(M .. " + D",       hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind(M .. " + COMMA",   hl.dsp.exec_cmd("qs ipc call aequalyn settings"))
-- Window layouts: Super + L steps through them, Atelier shows them all
hl.bind(M .. " + L",         hl.dsp.exec_cmd("aequalyn-layout next"))
hl.bind(M .. " + SHIFT + L", hl.dsp.exec_cmd("aequalyn-layout prev"))
hl.bind(M .. " + ALT + L",   hl.dsp.exec_cmd("qs ipc call atelier toggle layouts"))
hl.bind(M .. " + CTRL + left",  hl.dsp.layout("swapprev"))
hl.bind(M .. " + CTRL + right", hl.dsp.layout("swapnext"))
-- Super + Ctrl + L (pick a layout), Super + Z, Super + - / =, Alt + Tab and the arrow
-- keys below are made layout-aware in aequalyn/keys.lua, as in Tableau.

-- Atelier: themes, wallpapers, rotation and palette in one picker
hl.bind(M .. " + T",       hl.dsp.exec_cmd("qs ipc call atelier toggle themes"))
hl.bind(M .. " + W",       hl.dsp.exec_cmd("qs ipc call atelier toggle wallpapers"))
hl.bind(M .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call atelier toggle rotation"))
hl.bind(M .. " + CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("qs ipc call atelier toggle themes"))
hl.bind(M .. " + CTRL + SPACE", hl.dsp.exec_cmd("aequalyn-wallpaper next"))
hl.bind(M .. " + O",       hl.dsp.exec_cmd("qs ipc call monitors toggle"))
hl.bind(M .. " + SHIFT + O", hl.dsp.exec_cmd("qs ipc call monitors refresh"))
hl.bind(M .. " + SHIFT + C", hl.dsp.exec_cmd("qs ipc call idle toggle"))
hl.bind(M .. " + I",       hl.dsp.exec_cmd("kitty -e sudo aequalyn-install"))
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

-- Focus / move
-- Super + arrows (focus) and Super + Shift + arrows (swap): aequalyn/keys.lua

-- Workspaces
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(M .. " + " .. key,        hl.dsp.focus({ workspace = i }))
    hl.bind(M .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i }))
end
hl.bind(M .. " + S",        hl.dsp.workspace.toggle_special("magic"))
hl.bind(M .. " + SHIFT + S",  hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(M .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse
hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots
-- hl.bind(M .. " + PRINT",       hl.dsp.exec_cmd("aequalyn-screenshot full-clip"))
-- hl.bind("PRINT",               hl.dsp.exec_cmd("aequalyn-screenshot region-clip"))
-- hl.bind(M .. " + SHIFT + PRINT", hl.dsp.exec_cmd("aequalyn-screenshot region-file"))
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

------------------------------------------------------------------------- rules
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true,
              fullscreen = false, pin = false },
    no_focus = true,
})

hl.layer_rule({ name = "aequalyn-blur-shell",  match = { namespace = "quickshell-.*" }, blur = true })
hl.layer_rule({ name = "aequalyn-blur-aequalyn",   match = { namespace = "aequalyn-.*" },      blur = true })
hl.layer_rule({ name = "aequalyn-noanim-osd",  match = { namespace = "quickshell-osd" }, no_anim = true })
hl.layer_rule({ name = "aequalyn-ignorezero",  match = { namespace = "quickshell-.*" }, ignore_alpha = true })
hl.layer_rule({ name = "aequalyn-dock-noblur", match = { namespace = "aequalyn-dock-plain" }, blur = false, ignore_alpha = true })

-------------------------------------------------------------------------- misc
hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
    layers = {
        allow_new_top_layers_over_existing_fullscreen = true,
    },
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
})
