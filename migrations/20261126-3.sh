#!/usr/bin/env bash
# 20261126-3.sh -- migration for existing installs: no web app on Aequalyn's own keys.
#
# YouTube was seeded on Super + Shift + T, which keybinds.lua also binds (load the
# floating titlebars) after webapps.lua, so Hyprland ran only the titlebars and the
# YouTube key did nothing. Super + Shift + P (the color picker) had the same problem.
# aequalyn-webapp now holds T and P, and its sync gives an app on one of them a free
# key (YouTube gets U), rewriting webapps.json, the launchers and webapps.lua.
#
# Usage:  sudo bash 20261126-3.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261126-3.sh  (tests)

set -euo pipefail

if [[ -z ${AEQUALYN_MIGRATION_HOMES:-} ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    read -r -a homes <<< "$AEQUALYN_MIGRATION_HOMES"
fi

info() { printf '\033[0;34m[20261126-3]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[20261126-3]\033[0m %s\n' "$*" >&2; }

for home in "${homes[@]}"; do
    tool=$home/.local/bin/aequalyn-webapp
    [[ -x $tool ]] || continue
    grep -qE '"key"[[:space:]]*:[[:space:]]*"[TtPp]"' "$home/.config/aequalyn/webapps.json" 2>/dev/null || continue
    user=$(stat -c %U "$home")
    run=(env -u XDG_CONFIG_HOME HOME="$home" USER="$user" PATH="$home/.local/bin:/usr/local/bin:/usr/bin")
    [[ $EUID -eq 0 ]] && run=(runuser -u "$user" -- "${run[@]}")
    if "${run[@]}" "$tool" sync >/dev/null 2>&1; then
        info "$home: web apps moved off Super + Shift + T and P"
    else
        warn "$home: could not move the web app keys; Settings -> Web apps can change them"
    fi
done
printf '\033[0;32m[20261126-3]\033[0m %s\n' "migration 20261126-3 complete"
