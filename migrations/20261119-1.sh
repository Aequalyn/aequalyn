#!/usr/bin/env bash
# 20261119-1.sh -- migration for existing installs: the boot splash's newer script.
#
# The Aequalyn splash theme is copied to /usr/share/plymouth/themes/aequalyn
# when a system is installed, and nothing updated it since. Its script now:
#   - lays itself out again when the screen changes resolution during boot
#     (hybrid graphics, or the real GPU driver taking over from the firmware's
#     framebuffer), so the mark no longer ends up off centre;
#   - shows only the mark when shutting down or restarting: no loader ring and
#     no progress bar.
#
# This copies the new script in, keeping this machine's own BOOT_SECONDS (set
# by aequalyn-plymouth-calibrate) and START_BAR_ON_SPLASH, then rebuilds the
# initramfs, which carries the theme for the boot splash. A machine without
# the Aequalyn splash is left alone.
#
# It defers (exit 3, tried again on the next update) while the new script is
# not in the tree yet, or when the initramfs could not be rebuilt.
#
# Usage:  sudo bash 20261119-1.sh        (run by aequalyn-update, or by hand)

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

AQ_ROOT=${AEQUALYN_ROOT:-/usr/share/aequalyn}
src=$AQ_ROOT/plymouth/aequalyn/aequalyn.script
dst=/usr/share/plymouth/themes/aequalyn/aequalyn.script
# set while the initramfs still has the old script, so a failed rebuild is retried
pending=/var/lib/aequalyn/plymouth-initramfs-pending

info() { printf '\033[0;34m[20261119-1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261119-1]\033[0m %s\n' "$*"; }

if [[ ! -f $dst ]]; then
    ok "this system does not use the Aequalyn boot splash; nothing to do"
    exit 0
fi
if [[ ! -f $src ]] || ! grep -q 'logo_only' "$src"; then
    info "the new splash script is not in the tree yet; trying again on the next update"
    exit 3
fi

boot_line=$(grep -m1 '^BOOT_SECONDS = ' "$dst" || true)
bar_line=$(grep -m1 '^START_BAR_ON_SPLASH = ' "$dst" || true)
new=$(mktemp)
trap 'rm -f "$new"' EXIT
cp "$src" "$new"
[[ -n $boot_line ]] && sed -i "s|^BOOT_SECONDS = .*|$boot_line|" "$new"
[[ -n $bar_line ]] && sed -i "s|^START_BAR_ON_SPLASH = .*|$bar_line|" "$new"

if cmp -s "$new" "$dst" && [[ ! -f $pending ]]; then
    ok "the splash script is already the newest"
    exit 0
fi

if ! cmp -s "$new" "$dst"; then
    info "installing the new splash script (keeping ${boot_line:-the default BOOT_SECONDS})"
    install -m 0644 "$new" "$dst"
fi
mkdir -p "$(dirname "$pending")"
touch "$pending"

info "rebuilding the initramfs, which carries the boot splash"
if ! mkinitcpio -P >/dev/null 2>&1; then
    info "mkinitcpio failed; the shutdown splash is already new, the boot one follows on the next update"
    exit 3
fi
rm -f "$pending"
ok "the splash stays centred when the screen changes, and shows only the mark at shutdown and restart"
