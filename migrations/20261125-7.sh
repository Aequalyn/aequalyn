#!/usr/bin/env bash
# 20261125-7.sh -- migration for existing installs: built-in themes are installed by choice.
#
# For a while every built-in theme was linked into every system. They are in the Store, to be
# installed by whoever wants one; aequalyn-builtin-themes takes the links away that nobody wears.

set -euo pipefail

root=${AEQUALYN_ROOT:-/usr/share/aequalyn}
[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
[[ -x "$root/bin/aequalyn-builtin-themes" ]] || exit 3
bash "$root/bin/aequalyn-builtin-themes"
printf '\033[0;32m[20261125-7]\033[0m %s\n' "migration 20261125-7 complete"
