#!/usr/bin/env bash
# 20261124-1.sh -- migration for existing installs: Super + Ctrl + . opens Fonts.
#
# Updates leave the user's keybinds alone, so the new key is added here, next to
# Super + comma, without touching any other binding.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261124-1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261124-1]\033[0m %s\n' "$*"; }

for home in "${homes[@]}"; do
    [[ -d "$home" ]] || continue
    f="$home/.config/hypr/keybinds.lua"
    [[ -f "$f" ]] || continue
    grep -Fq 'qs ipc call fonts toggle' "$f" && continue
    if grep -Fq 'hl.bind(M .. " + CTRL + PERIOD"' "$f"; then
        info "$home: keeping the existing Super + Ctrl + . binding"
        continue
    fi
    grep -Fq 'hl.bind(M .. " + COMMA"' "$f" || continue
    awk -v line='hl.bind(M .. " + CTRL + PERIOD", hl.dsp.exec_cmd("qs ipc call fonts toggle")) -- Fonts' '
        { print }
        !done && index($0, "hl.bind(M .. \" + COMMA\"") { print line; done = 1 }
    ' "$f" > "$f.tmp"
    cat "$f.tmp" > "$f"
    rm -f "$f.tmp"
    info "$home: Super + Ctrl + . now opens Fonts"
done

ok "migration 20261124-1 complete"
