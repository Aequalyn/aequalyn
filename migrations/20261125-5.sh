#!/usr/bin/env bash
# 20261125-5.sh -- migration for existing installs: pacman's database, for every user to read.
#
# Installed under a private file mode, its version file was root's alone: pacman run by a user
# (the Store, yay) said "database is incorrect version" and ended with 255.

set -euo pipefail

db=${AEQUALYN_PACMAN_DB:-/var/lib/pacman}
[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
for d in "$db" "$db/local" "$db/sync"; do
    [[ -d "$d" ]] && chmod a+rx "$d"
done
[[ -d "$db/local" ]] && find "$db/local" \( -type d ! -perm -0555 -exec chmod a+rx {} + \) -o \( -type f ! -perm -0444 -exec chmod a+r {} + \)
[[ -d "$db/sync" ]] && find "$db/sync" -maxdepth 1 -type f ! -perm -0444 -exec chmod a+r {} +
printf '\033[0;32m[20261125-5]\033[0m %s\n' "migration 20261125-5 complete"
