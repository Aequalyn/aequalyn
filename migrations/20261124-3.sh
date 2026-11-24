#!/usr/bin/env bash
# 20261124-3.sh -- migration for existing installs: any font, everywhere, at once.
#
# aequalyn-apply-fonts measures fonts with python-fonttools, and open foot windows follow
# a font change with Aequalyn's foot (aequalyn-pkgs, pkgbuilds/foot). Both are installed
# here, then the fonts already chosen are applied again the new way.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/*)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261124-3]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261124-3]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261124-3]\033[0m %s\n' "$*" >&2; }

later=0
if ! command -v pacman >/dev/null 2>&1; then
    warn "no pacman here: skipping the packages"
else
    if ! pacman -Q python-fonttools >/dev/null 2>&1; then
        info "installing python-fonttools"
        # 3: not ready (offline, or an old package database); the next update tries again
        pacman -S --needed --noconfirm python-fonttools || exit 3
    fi

    # Only over an older foot, and never required: without it, new windows still follow.
    cache=${AEQUALYN_SRC:-/var/lib/aequalyn/src}/aequalyn-pkgs/aur-cache
    pkg=$(compgen -G "$cache/foot-[0-9]*.pkg.tar.zst" | sort -V | tail -n1 || true)
    have=$(pacman -Q foot 2>/dev/null | awk '{ print $2 }' || true)
    # an older updater has not fetched the packages yet: the next update has them
    if [[ -z "$pkg" && -n "$have" ]]; then later=1; fi
    if [[ -n "$pkg" && -n "$have" ]]; then
        new=$(basename "$pkg"); new=${new#foot-}; new=${new%-x86_64.pkg.tar.zst}
        if [[ "$(vercmp "$new" "$have")" -gt 0 ]]; then
            if pacman -U --noconfirm --needed "$pkg"; then
                info "foot $new: open windows follow font changes once reopened"
            else
                warn "could not install foot $new; foot stays as it is"
            fi
        fi
    fi
fi

for home in "${homes[@]}"; do
    [[ -x "$home/.local/bin/aequalyn-apply-fonts" ]] || continue
    grep -qE '"(uiFont|monoFont)"[[:space:]]*:[[:space:]]*"' "$home/.config/aequalyn/settings.json" 2>/dev/null || continue
    user=$(stat -c %U "$home"); uid=$(stat -c %u "$home")
    run=(env -u XDG_CONFIG_HOME HOME="$home" USER="$user" PATH="$home/.local/bin:/usr/local/bin:/usr/bin")
    [[ -d "/run/user/$uid" ]] && run+=(XDG_RUNTIME_DIR="/run/user/$uid")
    [[ -S "/run/user/$uid/bus" ]] && run+=(DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus")
    [[ $EUID -eq 0 ]] && run=(runuser -u "$user" -- "${run[@]}")
    if "${run[@]}" "$home/.local/bin/aequalyn-apply-fonts" >/dev/null 2>&1; then
        info "$home: fonts applied again"
    else
        warn "$home: could not apply the fonts; changing the font in Settings does"
    fi
done

if (( later )); then
    info "foot follows with the next update"
    exit 3
fi
ok "migration 20261124-3 complete"
