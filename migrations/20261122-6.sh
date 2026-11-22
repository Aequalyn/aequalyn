#!/usr/bin/env bash
# 20261122-6.sh -- migration for existing installs: Super + R opens the remove chooser.
#
# Super + I opens the install chooser. This pair adds the matching remove key,
# using the shell's two-list picker without touching any other binding.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261122-6]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261122-6]\033[0m %s\n' "$*"; }

for home in "${homes[@]}"; do
    [[ -d "$home" ]] || continue
    f="$home/.config/hypr/keybinds.lua"
    [[ -f "$f" ]] || continue
    if grep -Fq 'qs ipc call removeMenu toggle' "$f"; then
        continue
    fi
    if grep -Fq 'hl.bind(M .. " + R"' "$f"; then
        info "$home: keeping the existing Super + R binding"
        continue
    fi
    if grep -F 'hl.bind(M .. " + I"' "$f" | grep -Fq 'qs ipc call installMenu toggle'; then
        awk -v line='hl.bind(M .. " + R", hl.dsp.exec_cmd("qs ipc call removeMenu toggle")) -- Remove chooser' '
            !done && index($0, "hl.bind(M .. \" + I\"") { print; print line; done = 1; next }
            { print }
        ' "$f" > "$f.tmp"
        cat "$f.tmp" > "$f"
        rm -f "$f.tmp"
        info "$home: Super + R now opens the remove chooser"
    fi
done

ok "migration 20261122-6 complete"
