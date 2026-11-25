#!/usr/bin/env bash
# 20261125-3.sh -- migration for existing installs: the Quick looks keys of the cursor,
# Showcase and all of them at once (Super + Ctrl + C, W and M).
#
# Updates leave the user's keybinds alone, so the new keys are added here, after the other
# Quick looks, and only those the user has not given to something else.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261125-3]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261125-3]\033[0m %s\n' "$*"; }

for home in "${homes[@]}"; do
    f="$home/.config/hypr/keybinds.lua"
    [[ -f "$f" ]] || continue
    # someone who took the Quick looks keys out does not want two more
    grep -Eq '^[^-]*qs ipc call quickLooks' "$f" || continue
    lines=""
    for k in C:cursor W:showcase M:all; do
        key=${k%%:*}; verb=${k#*:}
        grep -Fq "qs ipc call quickLooks $verb" "$f" && continue
        # taken by the user, here or in another file of theirs
        if grep -rqiE "\"[^\"]*\+ *CTRL *\+ *$key\"" "$home/.config/hypr" --include='*.lua' 2>/dev/null; then
            info "$home: keeping the existing Super + Ctrl + $key binding"
            continue
        fi
        lines+="hl.bind(M .. \" + CTRL + $key\", hl.dsp.exec_cmd(\"qs ipc call quickLooks $verb\")) -- Quick looks"$'\n'
    done
    [[ -n "$lines" ]] || continue
    # after the last of the others
    LINES_ADD="$lines" awk '
        { line[NR] = $0; if ($0 !~ /^[ \t]*--/ && index($0, "qs ipc call quickLooks")) last = NR }
        END { for (i = 1; i <= NR; i++) { print line[i]; if (i == last) printf "%s", ENVIRON["LINES_ADD"] } }
    ' "$f" > "$f.tmp"
    cat "$f.tmp" > "$f"
    rm -f "$f.tmp"
    info "$home: Quick looks keys added"
done

ok "migration 20261125-3 complete"
