#!/usr/bin/env bash
# 20261116-2.sh -- migration for existing Aequalyn installs: retire first-boot.
#
# The first-boot helper used to stay enabled after installing and ran on every
# boot while /etc/aequalyn/install.toml existed. This removes the config, stops
# and disables aequalyn-first-boot, and deletes its unit and script.
#
# It waits (exit 3, tried again on the next update) while the snapshot tooling
# is missing, so the first-boot helper can still install it.
#
# Usage:  sudo bash 20261116-2.sh        (run by aequalyn-update, or by hand)

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

CONF=/etc/aequalyn/install.toml
UNIT=/etc/systemd/system/aequalyn-first-boot.service
SCRIPT=/usr/local/bin/aequalyn-first-boot

info() { printf '\033[0;34m[20261116-2]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261116-2]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261116-2]\033[0m %s\n' "$*"; }

for p in limine-mkinitcpio-hook limine-snapper-sync; do
    if ! pacman -Q "$p" >/dev/null 2>&1; then
        warn "$p is not installed yet; first-boot must finish first. Trying again on the next update."
        exit 3
    fi
done

info "stopping and disabling aequalyn-first-boot"
systemctl disable --now aequalyn-first-boot.service >/dev/null 2>&1 || true

info "removing the install config and first-boot files"
rm -f "$CONF" "$UNIT" "$SCRIPT"
systemctl daemon-reload >/dev/null 2>&1 || true

ok "first-boot retired"
