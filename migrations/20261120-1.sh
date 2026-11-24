#!/usr/bin/env bash
# 20261120-1.sh -- migration for existing installs: the Store's key, Super + Alt + S.
#
# The Store opens with Super + Alt + S (`qs ipc call store toggle`). The shipped
# keybinds.lua has the line, but updates leave a user's hypr folder alone, so machines
# installed before it never got it. This adds that one line to every user's
# ~/.config/hypr/keybinds.lua that lacks it, right after the default apps launcher's
# (Super + Alt + A), or at the end, and changes nothing else. A user who already bound
# Super + Alt + S to something of their own keeps it.
#
# Usage:  sudo bash 20261120-1.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261120-1.sh  (tests: those homes)

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261120-1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261120-1]\033[0m %s\n' "$*"; }

LINE='hl.bind(M .. " + ALT + S",       hl.dsp.exec_cmd("qs ipc call store toggle"))   -- Store: plugins, themes, cursors, looks'

for home in "${homes[@]}"; do
    f="$home/.config/hypr/keybinds.lua"
    [[ -f "$f" ]] || continue
    if grep -q 'qs ipc call store' "$f"; then
        ok "$f already opens the Store"
        continue
    fi
    if grep -q '" + ALT + S"' "$f"; then
        info "$f binds Super + Alt + S to something else: left as it is"
        continue
    fi
    tmp=$(mktemp "$f.XXXXXX")
    if grep -q '" + ALT + A"' "$f"; then
        awk -v line="$LINE" '{ print } /" \+ ALT \+ A"/ && !done { print line; done = 1 }' "$f" > "$tmp"
    else
        { cat "$f"; printf '%s\n' "$LINE"; } > "$tmp"
    fi
    chown --reference="$f" "$tmp" 2>/dev/null || true
    chmod --reference="$f" "$tmp"
    mv -f "$tmp" "$f"
    ok "$f: Super + Alt + S opens the Store"
done
