#!/usr/bin/env bash
# 20261124-5.sh -- migration for existing installs: the Quick looks keys (Super + Ctrl + B, D,
# K and G).
#
# Updates leave the user's keybinds alone, so the new keys are added here, after Super +
# comma, and only those the user has not given to something else.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261124-5]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261124-5]\033[0m %s\n' "$*"; }

for home in "${homes[@]}"; do
    f="$home/.config/hypr/keybinds.lua"
    [[ -f "$f" ]] || continue
    grep -Fq 'qs ipc call quickLooks' "$f" && continue
    grep -Fq 'hl.bind(M .. " + COMMA"' "$f" || continue
    lines=""
    for k in B:bar D:dock K:lock G:login; do
        key=${k%%:*}; verb=${k#*:}
        # taken by the user, here or in another file of theirs
        if grep -rqE "\"[^\"]*\+ *CTRL *\+ *$key\"" "$home/.config/hypr" --include='*.lua' 2>/dev/null; then
            info "$home: keeping the existing Super + Ctrl + $key binding"
            continue
        fi
        lines+="hl.bind(M .. \" + CTRL + $key\", hl.dsp.exec_cmd(\"qs ipc call quickLooks $verb\")) -- Quick looks"$'\n'
    done
    [[ -n "$lines" ]] || continue
    LINES_ADD="$lines" awk '
        { print }
        !done && index($0, "hl.bind(M .. \" + COMMA\"") { printf "%s", ENVIRON["LINES_ADD"]; done = 1 }
    ' "$f" > "$f.tmp"
    cat "$f.tmp" > "$f"
    rm -f "$f.tmp"
    info "$home: Quick looks keys added"
done

ok "migration 20261124-5 complete"
