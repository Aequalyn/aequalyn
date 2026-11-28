#!/usr/bin/env bash
# 20261128-1.sh -- migration for existing installs: the Wi-Fi password reveal's root half.
#
# Settings > Wi-Fi > Reveal password asks the watchdog gate to run
# /usr/local/bin/aequalyn-wifi-secrets as root (pinned in the shell's Plugins.js). The
# installer puts it there on a fresh install, but an update did not, so on a machine
# installed before it the button had nothing to run. This copies it from the root-owned
# shell tree; from now on aequalyn-update refreshes it with every update.
#
# Usage:  sudo bash 20261128-1.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_ROOT=/tmp/aq AEQUALYN_BIN_DIR=/tmp/bin bash 20261128-1.sh  (tests)

set -euo pipefail

ROOT=${AEQUALYN_ROOT:-/usr/share/aequalyn}
BIN=${AEQUALYN_BIN_DIR:-/usr/local/bin}
SRC=$ROOT/shell/tools/wifi/aequalyn-wifi-secrets

if [[ -z ${AEQUALYN_BIN_DIR:-} ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
fi

if [[ ! -f $SRC ]]; then
    # a shell from before the helper: try again with the next update
    printf '\033[0;33m[20261128-1]\033[0m %s\n' "$SRC not found yet; trying again on the next update" >&2
    exit 3
fi
install -d -m 0755 "$BIN"
install -m 0755 "$SRC" "$BIN/.aequalyn-wifi-secrets.new"
mv -f "$BIN/.aequalyn-wifi-secrets.new" "$BIN/aequalyn-wifi-secrets"
printf '\033[0;34m[20261128-1]\033[0m %s\n' "$BIN/aequalyn-wifi-secrets installed"
printf '\033[0;32m[20261128-1]\033[0m %s\n' "migration 20261128-1 complete"
