#!/usr/bin/env bash
# 20261125-2.sh -- migration for existing installs: the built-in themes.
#
# The updater that runs this one has already got the newest aequalyn-themes, but does not
# know yet that some of its themes are built in: they are linked here, the first time.

set -euo pipefail

root=${AEQUALYN_ROOT:-/usr/share/aequalyn}
[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
[[ -x "$root/bin/aequalyn-builtin-themes" ]] || exit 3
bash "$root/bin/aequalyn-builtin-themes"
printf '\033[0;32m[20261125-2]\033[0m %s\n' "migration 20261125-2 complete"
