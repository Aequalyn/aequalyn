#!/usr/bin/env bash
# 20261122-4.sh -- install Aequalyn lock PAM stacks for the Quickshell lock.
#
# The new Quickshell session lock authenticates through PAM services:
#   /etc/pam.d/aequalyn-lock-password
#   /etc/pam.d/aequalyn-lock-fingerprint (only when fprintd is enrolled)
#
# These are root-owned system files. aequalyn-apply-lock installs them from the
# user's Quickshell lock PAM templates. Without the password stack, the lock
# plugin refuses to lock so the desktop stays usable.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261122-4]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261122-4]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[20261122-4]\033[0m %s\n' "$*"; }

install_for_home() {
    local home=$1 user apply template
    [[ -d "$home" ]] || return 0
    user=$(stat -c '%U' "$home" 2>/dev/null || true)
    [[ -n "$user" && "$user" != "root" ]] || return 0

    template="$home/.config/quickshell/plugins/lock/pam/aequalyn-lock-password"
    if [[ ! -r "$template" ]]; then
        info "$home: lock PAM templates not present, skipping"
        return 0
    fi

    apply=""
    for candidate in "$home/.local/bin/aequalyn-apply-lock" /usr/local/bin/aequalyn-apply-lock; do
        if [[ -x "$candidate" ]]; then apply="$candidate"; break; fi
    done

    if [[ -n "$apply" ]]; then
        if SUDO_USER="$user" "$apply" >/dev/null 2>&1; then
            info "$user: installed Aequalyn lock PAM stacks"
        else
            warn "$user: aequalyn-apply-lock failed (run manually: sudo ~/.local/bin/aequalyn-apply-lock)"
        fi
        return 0
    fi

    # Fallback: install the password stack directly from templates.
    install -D -m 0644 -o root -g root \
        "$template" /etc/pam.d/aequalyn-lock-password
    info "$user: installed /etc/pam.d/aequalyn-lock-password from template"

    fp_template="$home/.config/quickshell/plugins/lock/pam/aequalyn-lock-fingerprint"
    if [[ -r "$fp_template" ]] && command -v fprintd-list >/dev/null 2>&1; then
        if runuser -u "$user" -- fprintd-list "$user" 2>/dev/null | grep -q -- '- #'; then
            install -D -m 0644 -o root -g root \
                "$fp_template" /etc/pam.d/aequalyn-lock-fingerprint
            info "$user: installed /etc/pam.d/aequalyn-lock-fingerprint"
        fi
    fi
}

for home in "${homes[@]}"; do
    install_for_home "$home"
done

ok "migration 20261122-4 complete"
