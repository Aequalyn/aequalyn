#!/usr/bin/env bash
# 20261126-5.sh -- migration for existing installs: kitty's remote control off.
#
# kitty.conf shipped with allow_remote_control yes and a socket in /tmp, only so a
# theme change could recolour open windows (kitty @ set-colors). Any program could
# use that socket to type into or run commands in the terminal. Open windows now
# follow colour changes by SIGUSR1 (kitty reads its config again), and the theme
# picker's live preview goes in theme-preview.conf, which kitty.conf includes last.
# This turns the shipped two lines off in ~/.config/kitty/kitty.conf and adds the
# include; a remote control the user set up some other way is left as it is.
#
# Usage:  sudo bash 20261126-5.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261126-5.sh  (tests)

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
            || printf '\033[0;33m[%s]\033[0m %s\n' "20261126-5" "$home: could not be updated; it is left as it was" >&2
    done
    printf '\033[0;32m[%s]\033[0m %s\n' "20261126-5" "migration 20261126-5 complete"
    exit 0
fi

info() { printf '\033[0;34m[20261126-5]\033[0m %s\n' "$*"; }

for home in "${homes[@]}"; do
    f=$home/.config/kitty/kitty.conf
    [[ -f $f ]] || continue
    tmp=$(mktemp)
    awk '
        /^allow_remote_control[ \t]+yes[ \t]*$/ { print "allow_remote_control no"; next }
        /^listen_on[ \t]+unix:\/tmp\/kitty-\{kitty_pid\}[ \t]*$/ { next }
        { print }
    ' "$f" > "$tmp"
    if ! grep -q 'theme-preview\.conf' "$tmp"; then
        printf '\n%s\n%s\n%s\n' \
            "# The theme picker's live preview, while it is open. Colour changes reach open windows" \
            "# by SIGUSR1 (kitty reads its config again), so remote control stays off." \
            "globinclude theme-preview.conf" >> "$tmp"
    fi
    if cmp -s "$f" "$tmp"; then
        rm -f "$tmp"
        continue
    fi
    cat "$tmp" > "$f"   # keeps owner and mode
    rm -f "$tmp"
    info "$f: remote control off"
done
[[ -n ${AEQUALYN_MIGRATION_AS_USER:-} ]] || printf '\033[0;32m[20261126-5]\033[0m %s\n' "migration 20261126-5 complete"
