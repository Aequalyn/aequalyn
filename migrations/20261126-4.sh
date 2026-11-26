#!/usr/bin/env bash
# 20261126-4.sh -- migration for existing installs: the manual's and the shortcuts page's keys.
#
# Super + F1 (the manual) and Super + Alt + K (the Keyboard shortcuts page) were shown
# by their plugins but bound nowhere: Super + Alt + K only came with the block the
# shortcuts page writes once a key is changed there. The shipped keybinds.lua now has
# both, but updates leave a user's hypr folder alone, so this adds each line that is
# missing to ~/.config/hypr/keybinds.lua and changes nothing else. A key the user
# already bound to something of their own is left as it is.
#
# Usage:  sudo bash 20261126-4.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261126-4.sh  (tests)

set -euo pipefail

if [[ -z ${AEQUALYN_MIGRATION_HOMES:-} ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    read -r -a homes <<< "$AEQUALYN_MIGRATION_HOMES"
fi

info() { printf '\033[0;34m[20261126-4]\033[0m %s\n' "$*"; }

MANUAL='hl.bind(M .. " + F1",             hl.dsp.exec_cmd("qs ipc call manual toggle"))       -- Manual'
PAGE='pcall(hl.bind, M .. " + ALT + K", hl.dsp.exec_cmd("qs ipc call aequalyn page keybinds"), { description = "Keyboard shortcuts" })'

# add <file> <line> <after-pattern>: after the first line matching the pattern, or at the end
add() {
    local f=$1 line=$2 after=$3 tmp
    tmp=$(mktemp "$f.XXXXXX")
    if grep -qE "$after" "$f"; then
        awk -v line="$line" -v re="$after" '{ print } $0 ~ re && !done { print line; done = 1 }' "$f" > "$tmp"
    else
        { cat "$f"; printf '%s\n' "$line"; } > "$tmp"
    fi
    chown --reference="$f" "$tmp" 2>/dev/null || true
    chmod --reference="$f" "$tmp"
    mv -f "$tmp" "$f"
}

for home in "${homes[@]}"; do
    f=$home/.config/hypr/keybinds.lua
    [[ -f $f ]] || continue
    if ! grep -q 'qs ipc call manual' "$f" && ! grep -q '" + F1"' "$f"; then
        add "$f" "$MANUAL" 'qs ipc call keyHints'
        info "$f: Super + F1 opens the manual"
    fi
    if ! grep -q 'qs ipc call aequalyn page keybinds' "$f" && ! grep -q '" + ALT + K"' "$f"; then
        add "$f" "$PAGE" 'qs ipc call timer'
        info "$f: Super + Alt + K opens the keyboard shortcuts"
    fi
done
printf '\033[0;32m[20261126-4]\033[0m %s\n' "migration 20261126-4 complete"
