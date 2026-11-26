#!/usr/bin/env bash
# 20261126-2.sh -- migration for existing installs: no tty1 desktop inside SDDM.
#
# The installer's ~/.bash_profile starts aequalyn-desktop on tty1 as a fallback
# for a raw console login. SDDM's wayland-session runs a bash login shell on
# that same tty1, so the fallback fired there too: the Aequalyn session wrapper
# never ran, log out fell back to loginctl terminate-session, sddm-helper was
# killed with it, and SDDM never brought its greeter back (a black screen).
# The guard now also needs XDG_SESSION_TYPE=tty, which SDDM sets to wayland.
#
# Usage:  sudo bash 20261126-2.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261126-2.sh  (tests)

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
            || printf '\033[0;33m[%s]\033[0m %s\n' "20261126-2" "$home: could not be updated; it is left as it was" >&2
    done
    printf '\033[0;32m[%s]\033[0m %s\n' "20261126-2" "migration 20261126-2 complete"
    exit 0
fi

old='if [[ -z ${WAYLAND_DISPLAY:-} && ${XDG_VTNR:-0} -eq 1 ]] && command -v aequalyn-desktop >/dev/null; then'
new='if [[ -z ${WAYLAND_DISPLAY:-} && ${XDG_SESSION_TYPE:-tty} == tty && ${XDG_VTNR:-0} -eq 1 ]] && command -v aequalyn-desktop >/dev/null; then'

for home in "${homes[@]}"; do
    f=$home/.bash_profile
    [[ -f $f ]] && grep -Fxq "$old" "$f" || continue
    tmp=$(mktemp)
    awk -v o="$old" -v n="$new" '$0 == o { print n; next } { print }' "$f" > "$tmp"
    cat "$tmp" > "$f"   # keeps owner and mode
    rm -f "$tmp"
    printf '\033[0;34m[20261126-2]\033[0m %s\n' "$home: tty1 desktop fallback no longer runs inside SDDM"
done
[[ -n ${AEQUALYN_MIGRATION_AS_USER:-} ]] || printf '\033[0;32m[20261126-2]\033[0m %s\n' "migration 20261126-2 complete"
