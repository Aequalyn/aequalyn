#!/usr/bin/env bash
# 20261121-2.sh -- migration for existing installs: floating titlebar on demand.
#
# The optional hyprbars titlebar plugin now loads on demand (Super + Shift + T)
# or automatically 10 seconds after the session starts, instead of during
# Hyprland startup (which crashed the compositor). This migration:
#   * refreshes the user's floating.lua from the shipped (post-fix) version,
#   * adds the Super + Shift + T keybind to keybinds.lua when missing,
#   * adds the deferred titlebar load to aequalyn-session-start when missing.
#
# Usage:  sudo bash 20261121-2.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261121-2.sh  (tests)

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261121-2]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261121-2]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261121-2]\033[0m %s\n' "$*"; }

SRC_FLOATING="/usr/share/aequalyn/config/hypr/aequalyn/floating.lua"

KEYBIND_BLOCK='
-- Load the optional floating titlebar plugin on demand (avoids startup crashes).
if hl.bind and hl.timer then
  pcall(hl.bind, "SUPER + SHIFT + T", function()
    hl.exec_cmd("hyprctl plugin load " .. (os.getenv("HOME") or "") .. "/.local/lib/aequalyn/hyprbars.so")
    pcall(hl.timer, function()
      if _G.aequalyn_floating then _G.aequalyn_floating.load_decorations() end
    end, { timeout = 1000, type = "oneshot" })
  end, { description = "Load floating titlebar" })
end
'

SESSION_BLOCK='
# Load the optional floating titlebar plugin only after Hyprland and the shell
# are fully up. Loading it earlier (config parse / startup) crashes Hyprland.
if [ -f "$HOME/.local/lib/aequalyn/hyprbars.so" ]; then
    ( sleep 10; hyprctl plugin load "$HOME/.local/lib/aequalyn/hyprbars.so" >/dev/null 2>&1; sleep 1; hyprctl eval "_G.aequalyn_floating.load_decorations()" >/dev/null 2>&1; sleep 1; aequalyn-shell-restart >/dev/null 2>&1 ) &
fi
'

for home in "${homes[@]}"; do
    [[ -d "$home" ]] || continue
    cfg="$home/.config/hypr"
    floating="$cfg/aequalyn/floating.lua"
    keybinds="$cfg/keybinds.lua"
    session_start="$home/.local/bin/aequalyn-session-start"

    # Refresh floating.lua from the shipped version when available.
    if [[ -f "$SRC_FLOATING" ]]; then
        mkdir -p "$(dirname "$floating")"
        cp -f "$SRC_FLOATING" "$floating"
        chown --reference="$home" "$floating" 2>/dev/null || chown "$(stat -c %u:%g "$home" 2>/dev/null || echo 0:0)" "$floating" 2>/dev/null || true
        chmod 644 "$floating"
        info "$floating: refreshed from shipped version"
    fi

    # Add the on-demand keybind when missing.
    if [[ -f "$keybinds" ]] && ! grep -q 'Load the optional floating titlebar plugin on demand' "$keybinds"; then
        tmp=$(mktemp "$keybinds.XXXXXX")
        { cat "$keybinds"; printf '%s\n' "$KEYBIND_BLOCK"; } > "$tmp"
        chown --reference="$keybinds" "$tmp" 2>/dev/null || true
        chmod --reference="$keybinds" "$tmp" 2>/dev/null || true
        mv -f "$tmp" "$keybinds"
        info "$keybinds: added Super + Shift + T titlebar keybind"
    fi

    # Add the deferred titlebar load to session-start when missing.
    if [[ -f "$session_start" ]] && ! grep -q 'Load the optional floating titlebar plugin only after' "$session_start"; then
        tmp=$(mktemp "$session_start.XXXXXX")
        awk -v block="$SESSION_BLOCK" '
            /^log "session started at/ { print block }
            { print }
        ' "$session_start" > "$tmp"
        chown --reference="$session_start" "$tmp" 2>/dev/null || true
        chmod --reference="$session_start" "$tmp" 2>/dev/null || true
        mv -f "$tmp" "$session_start"
        info "$session_start: added deferred titlebar load"
    fi
done

ok "migration 20261121-2 complete"