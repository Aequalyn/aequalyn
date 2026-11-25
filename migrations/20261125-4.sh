#!/usr/bin/env bash
# 20261125-4.sh -- migration for existing installs: no password for a theme change.
#
# The browsers' colour and the login screen's theme are set by scripts that check what they
# are given; aequalyn-gate-rules has sudo run just those without asking.

set -euo pipefail

root=${AEQUALYN_ROOT:-/usr/share/aequalyn}
[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
[[ -f "$root/bin/aequalyn-gate-rules" ]] || exit 3
bash "$root/bin/aequalyn-gate-rules"
printf '\033[0;32m[20261125-4]\033[0m %s\n' "migration 20261125-4 complete"
