------------------------------------------------------------------ environment

-- The display manager starts Hyprland with a base PATH that omits ~/.local/bin.

-- Keybinds call the aequalyn-* helpers by name, so add it here or every such

-- bind (Print, XF86SelectiveScreenshot, aequalyn-lock, ...) fails silently.

local HOME_DIR = os.getenv("HOME") or ""

local USER_BIN = HOME_DIR .. "/.local/bin"

local CURRENT_PATH = os.getenv("PATH") or ""

if not (":" .. CURRENT_PATH .. ":"):find(":" .. USER_BIN .. ":", 1, true) then

    local new_path = USER_BIN

    if CURRENT_PATH ~= "" then new_path = new_path .. ":" .. CURRENT_PATH end

    hl.env("PATH", new_path)

end



hl.env("XCURSOR_SIZE", "24")

hl.env("HYPRCURSOR_SIZE", "24")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

hl.env("XDG_SESSION_TYPE", "wayland")

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Aequalyn FM serves every app's Open/Save dialog through the portal; GTK 3

-- only asks the portal when this is set

hl.env("GTK_USE_PORTAL", "1")

hl.env("GTK_THEME", "adw-gtk3-dark")

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")


