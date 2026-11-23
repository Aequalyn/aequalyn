#!/usr/bin/env bash
# 20261122-5.sh -- migration for existing installs: Super + I opens the install chooser.
#
# The key used to start the system installer directly. It now opens the shell's
# curated install chooser, with AI, Service, Development, Editor, Style, Gaming,
# Browser and Terminal groups. Only the exact old command is replaced, so any
# user edits to the rest of keybinds.lua stay put.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261122-5]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261122-5]\033[0m %s\n' "$*"; }

for home in "${homes[@]}"; do
    [[ -d "$home" ]] || continue
    f="$home/.config/hypr/keybinds.lua"
    [[ -f "$f" ]] || continue
    if grep -F 'hl.bind(M .. " + I"' "$f" | grep -Fq 'sudo aequalyn-install'; then
        sed -i '/hl.bind(M .. " + I"/s|sudo aequalyn-install|qs ipc call installMenu toggle|' "$f"
        info "$home: Super + I now opens the install chooser"
    fi
done

ok "migration 20261122-5 complete"
