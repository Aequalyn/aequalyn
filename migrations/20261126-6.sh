#!/usr/bin/env bash
# 20261126-6.sh -- migration for existing installs: the legacy 20261509 scripts go.
#
# bin/20261509.sh and bin/20261509-1.sh were one-off fixes from before migrations/
# existed. Run as root, they took an SDDM or Plymouth theme from the first of
# /tmp/aequalyn-lockscreens, /tmp/aequalyn or /home/*/Projects/... that existed, so
# anyone who could write there chose what root installed. Nothing runs them any more;
# they are gone from the repository, and this removes the copies an install put in
# /usr/local/bin and in each ~/.local/bin (as that home's owner).
#
# Usage:  sudo bash 20261126-6.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes AEQUALYN_BIN_DIR=/tmp/bin bash 20261126-6.sh  (tests)

set -euo pipefail

if [[ -z ${AEQUALYN_MIGRATION_HOMES:-} ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    read -r -a homes <<< "$AEQUALYN_MIGRATION_HOMES"
fi

info() { printf '\033[0;34m[20261126-6]\033[0m %s\n' "$*"; }
OLD=(20261509.sh 20261509-1.sh)

bin=${AEQUALYN_BIN_DIR:-/usr/local/bin}
for f in "${OLD[@]}"; do
    [[ -e $bin/$f || -L $bin/$f ]] || continue
    rm -f -- "${bin:?}/$f"
    info "$bin/$f removed"
done

for home in "${homes[@]}"; do
    [[ -d $home/.local/bin ]] || continue
    run=()
    [[ $EUID -eq 0 ]] && run=(runuser -u "$(stat -c %U "$home")" --)
    for f in "${OLD[@]}"; do
        [[ -e $home/.local/bin/$f || -L $home/.local/bin/$f ]] || continue
        "${run[@]}" rm -f -- "$home/.local/bin/$f" && info "$home/.local/bin/$f removed"
    done
done
printf '\033[0;32m[20261126-6]\033[0m %s\n' "migration 20261126-6 complete"
