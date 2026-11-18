-------------------------------------------------------------------- autostart
-- Absolute path + `bash`: Hyprland's executor does not inherit the login
-- shell's PATH, and mkarchiso can strip the exec bit from ~/.local/bin files.
-- dofile'd chunks don't see hyprland.lua's locals, so this file needs its own.
local HOME = os.getenv("HOME") or ""
local session_start = "bash " .. HOME .. "/.local/bin/aequalyn-session-start"

hl.on("hyprland.start", function()
    hl.exec_cmd("xhost +si:localuser:root")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    -- Start gnome-keyring so secrets are available even on autologin (where no
    -- password is typed). On a normal login pam_gnome_keyring unlocks it; with
    -- autologin the daemon still starts here and the keyring stays locked until
    -- the user's password is provided (or the keyring password is empty).
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
    hl.exec_cmd(session_start)
end)

