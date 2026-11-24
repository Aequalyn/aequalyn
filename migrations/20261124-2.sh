#!/usr/bin/env bash
# 20261124-2.sh -- migration for existing installs: one lock screen.
#
# Older homes still carry a hypridle.conf that starts hyprlock on idle and sleep, next to
# the shell's own lock. Its commands go through aequalyn-lock now. A restarted shell may
# also take back the lock a crashed one left (fresh installs already ship this).

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261124-2]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261124-2]\033[0m %s\n' "$*"; }

for home in "${homes[@]}"; do
    [[ -d "$home" ]] || continue
    f="$home/.config/hypr/hypridle.conf"
    if [[ -f "$f" ]] && grep -qE 'hyprlock|loginctl lock-session' "$f"; then
        sed -E \
            -e 's#^([[:space:]]*lock_cmd[[:space:]]*=).*hyprlock.*#\1 aequalyn-lock lock#' \
            -e 's#^([[:space:]]*unlock_cmd[[:space:]]*=).*hyprlock.*#\1 aequalyn-lock wake#' \
            -e 's#^([[:space:]]*before_sleep_cmd[[:space:]]*=)[[:space:]]*loginctl lock-session[[:space:]]*$#\1 aequalyn-lock lockForSleep; aequalyn-lock wait-secure 12#' \
            -e 's#^([[:space:]]*on-timeout[[:space:]]*=)[[:space:]]*loginctl lock-session[[:space:]]*$#\1 aequalyn-lock lock#' \
            "$f" > "$f.tmp"
        cat "$f.tmp" > "$f"
        rm -f "$f.tmp"
        info "$home: idle and sleep lock through aequalyn-lock"
    fi
    f="$home/.config/hypr/input.lua"
    if [[ -f "$f" ]] && ! grep -rq 'allow_session_lock_restore' "$home/.config/hypr" --include=*.lua; then
        awk '{ print }
             !done && /disable_hyprland_logo[[:space:]]*=[[:space:]]*true,/ {
                 print "        allow_session_lock_restore = true,"; done = 1
             }' "$f" > "$f.tmp"
        cat "$f.tmp" > "$f"
        rm -f "$f.tmp"
        info "$home: a restarted shell can take its lock back"
    fi
done

ok "migration 20261124-2 complete"
