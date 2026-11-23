#!/usr/bin/env bash
# 20261122-1.sh -- migration for existing installs: ship the hyprbars plugin.
#
# The floating titlebar needs the third-party hyprbars compositor plugin
# (~/.local/lib/aequalyn/hyprbars.so). It is now shipped with Aequalyn, so
# this migration copies it into place for existing users.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

SRC="/usr/share/aequalyn/bin/hyprbars.so"

info() { printf '\033[0;34m[20261122-1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261122-1]\033[0m %s\n' "$*"; }

[[ -f "$SRC" ]] || { echo "source plugin not found: $SRC" >&2; exit 1; }

for home in "${homes[@]}"; do
    [[ -d "$home" ]] || continue
    dst="$home/.local/lib/aequalyn/hyprbars.so"
    mkdir -p "$(dirname "$dst")"
    cp -f "$SRC" "$dst"
    chown --reference="$home" "$dst" 2>/dev/null || true
    chmod 755 "$dst"
    info "$dst: installed"
done

ok "migration 20261122-1 complete"