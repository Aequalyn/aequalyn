#!/usr/bin/env bash
# 20261128-2.sh -- migration for existing installs: Super + Ctrl + N, the notification history.
#
# The shipped keybinds.lua binds Super + Ctrl + N to the saved notifications (qs ipc call
# notifications history), but updates leave a user's hypr folder alone, so a machine
# installed before it never got the key. This adds the line to ~/.config/hypr/keybinds.lua,
# after the other notification keys, and changes nothing else. A Super + Ctrl + N the user
# already bound to something of their own is left as it is.
#
# Usage:  sudo bash 20261128-2.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261128-2.sh  (tests)

set -euo pipefail

if [[ -z ${AEQUALYN_MIGRATION_HOMES:-} ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    read -r -a homes <<< "$AEQUALYN_MIGRATION_HOMES"
fi

# As root, each home is edited by its owner (this script again, for that home alone): a
# symlink planted in a home can then only lead to what its owner may write anyway.
if [[ $EUID -eq 0 && -z ${AEQUALYN_MIGRATION_AS_USER:-} ]]; then
    for home in "${homes[@]}"; do
        [[ -d $home ]] || continue
        owner=$(stat -c %U "$home" 2>/dev/null) || continue
        runuser -u "$owner" -- env AEQUALYN_MIGRATION_AS_USER=1 AEQUALYN_MIGRATION_HOMES="$home" bash "$(readlink -f "$0")" \
            || printf '\033[0;33m[%s]\033[0m %s\n' "20261128-2" "$home: could not be updated; it is left as it was" >&2
    done
    printf '\033[0;32m[%s]\033[0m %s\n' "20261128-2" "migration 20261128-2 complete"
    exit 0
fi

info() { printf '\033[0;34m[20261128-2]\033[0m %s\n' "$*"; }

LINE='hl.bind(M .. " + CTRL + N",  hl.dsp.exec_cmd("qs ipc call notifications history")) -- Re-read saved notifications'

for home in "${homes[@]}"; do
    f=$home/.config/hypr/keybinds.lua
    [[ -f $f ]] || continue
    grep -q 'qs ipc call notifications history' "$f" && continue
    grep -qE '"[[:space:]]*\+[[:space:]]*CTRL[[:space:]]*\+[[:space:]]*N"' "$f" && continue
    tmp=$(mktemp "$f.XXXXXX")
    if grep -q 'qs ipc call notifications' "$f"; then
        # after the last notification key
        n=$(grep -n 'qs ipc call notifications' "$f" | tail -1 | cut -d: -f1)
        awk -v line="$LINE" -v n="$n" '{ print } NR == n { print line }' "$f" > "$tmp"
    else
        { cat "$f"; printf '%s\n' "$LINE"; } > "$tmp"
    fi
    chmod --reference="$f" "$tmp"
    mv -f "$tmp" "$f"
    info "$f: Super + Ctrl + N opens the notification history"
done
[[ -n ${AEQUALYN_MIGRATION_AS_USER:-} ]] || printf '\033[0;32m[20261128-2]\033[0m %s\n' "migration 20261128-2 complete"
