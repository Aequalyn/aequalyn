#!/usr/bin/env bash
# 20261124-4.sh -- migration for existing installs: nudu with its icon.
#
# The nudu package first shipped had no icon, so the app menu and the dock drew nothing
# for it and looked for the file again and again.

set -euo pipefail

if [[ -n "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then homes_only=1; else homes_only=0; fi
[[ $EUID -eq 0 || $homes_only -eq 1 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

info() { printf '\033[0;34m[20261124-4]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261124-4]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261124-4]\033[0m %s\n' "$*" >&2; }

have=$(pacman -Q nudu 2>/dev/null | awk '{ print $2 }' || true)
if [[ -n "$have" ]]; then
    cache=${AEQUALYN_SRC:-/var/lib/aequalyn/src}/aequalyn-pkgs/aur-cache
    pkg=$(compgen -G "$cache/nudu-[0-9]*.pkg.tar.zst" | sort -V | tail -n1 || true)
    if [[ -z "$pkg" ]]; then
        # an older updater has not fetched the packages yet: the next update has them
        info "nudu's icon follows with the next update"
        exit 3
    fi
    new=$(basename "$pkg"); new=${new#nudu-}; new=${new%-x86_64.pkg.tar.zst}
    if [[ "$(vercmp "$new" "$have")" -gt 0 ]]; then
        if pacman -U --noconfirm --needed "$pkg"; then info "nudu $new installed"
        else warn "could not install nudu $new; nudu stays as it is"; fi
    fi
fi

ok "migration 20261124-4 complete"
