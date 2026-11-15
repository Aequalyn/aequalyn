#!/usr/bin/env bash
# 20261509-1.sh -- migration for existing Aequalyn installs: Plymouth theming.
#
# Brings an already-installed Aequalyn system onto the Aequalyn Plymouth boot
# splash: animated mark, circular loader, LUKS password dialog with hidden
# characters, retry/failure handling, resolution scaling and shutdown animation.
#
# Fixes:
#   1. Ensures `plymouth` is installed.
#   2. Downloads the Aequalyn Plymouth theme from git.
#   3. Checks the mkinitcpio HOOKS line and fixes it if needed, handling both
#      encrypted (LUKS) and unencrypted (plain) root setups.
#   4. Applies the theme, rebuilds the initramfs, and offers to reboot.
#
# Usage:  sudo bash 20261509-1.sh

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

THEME_NAME=aequalyn
THEME_DIR=/usr/share/plymouth/themes/$THEME_NAME
PLYMOUTH_URL=https://github.com/Aequalyn/aequalyn.git
WORK=/tmp/aequalyn-plymouth-mig

info() { printf '\033[0;34m[20261509-1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261509-1]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261509-1]\033[0m %s\n' "$*"; }

# -------------------------------------------------------------- 1. plymouth ---
if ! command -v plymouth >/dev/null 2>&1; then
    info "plymouth not found; installing"
    if command -v pacman >/dev/null 2>&1; then
        pacman -S --noconfirm plymouth
    else
        warn "pacman not available; install plymouth manually"
        exit 1
    fi
else
    ok "plymouth already installed"
fi

# -------------------------------------------------------------- 2. theme ------
info "downloading Aequalyn Plymouth theme from git"
rm -rf "$WORK"
THEME_SRC=""
if git clone -q --depth 1 "$PLYMOUTH_URL" "$WORK" 2>/dev/null; then
    if [[ -d "$WORK/plymouth/$THEME_NAME" ]]; then
        THEME_SRC="$WORK/plymouth/$THEME_NAME"
    fi
fi
# fallback: already present locally
if [[ -z "$THEME_SRC" ]]; then
    for cand in /usr/share/aequalyn/plymouth/$THEME_NAME /home/*/Projects/aequalyn/plymouth/$THEME_NAME /tmp/aequalyn/plymouth/$THEME_NAME; do
        if [[ -d "$cand" ]]; then THEME_SRC="$cand"; break; fi
    done
fi
if [[ -z "$THEME_SRC" || ! -d "$THEME_SRC" ]]; then
    warn "could not obtain the Plymouth theme; aborting"
    exit 1
fi
mkdir -p "$THEME_DIR"
rm -rf "$THEME_DIR"/*
cp -r "$THEME_SRC/." "$THEME_DIR/"
plymouth-set-default-theme "$THEME_NAME" >/dev/null 2>&1 || true
ok "Aequalyn Plymouth theme applied"

# ------------------------------------------------ 2b. progress-bar timing ----
# The bar fills over BOOT_SECONDS from the passphrase answer; most of that is
# the LUKS key derivation, which varies per machine. Measure it here.
CAL="$WORK/bin/aequalyn-plymouth-calibrate"
if [[ ! -x $CAL ]]; then
    CAL="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)/aequalyn-plymouth-calibrate"
fi
if [[ -x $CAL ]]; then
    info "calibrating the boot progress bar to this machine"
    "$CAL" --theme-dir "$THEME_DIR" || warn "calibration failed; keeping the theme default"
else
    warn "calibration helper not found; keeping the theme default"
fi

# -------------------------------------------------------------- 3. hooks -------
info "checking mkinitcpio HOOKS"
CONF=/etc/mkinitcpio.conf
if [[ ! -f "$CONF" ]]; then
    warn "$CONF not found; skipping hook fix"
else
    # Detect whether this install is LUKS-encrypted.
    ENCRYPTED=0
    if grep -q 'cryptdevice=' /etc/kernel/cmdline 2>/dev/null; then ENCRYPTED=1; fi
    if grep -q '^[[:space:]]*encrypt\|sd-encrypt' "$CONF" 2>/dev/null; then ENCRYPTED=1; fi
    if [[ -s /etc/crypttab ]] && grep -qv '^[[:space:]]*#' /etc/crypttab 2>/dev/null; then ENCRYPTED=1; fi

    # Ensure plymouth is present exactly once, right after 'block'.
    cp -a "$CONF" "$CONF.bak.plymouth" 2>/dev/null || true
    # remove any existing plymouth tokens
    sed -i '/^HOOKS=/ s/[[:space:]]*plymouth//g' "$CONF"
    # insert plymouth after block
    sed -i '/^HOOKS=/ s/block/block plymouth/' "$CONF"

    if [[ $ENCRYPTED -eq 1 ]]; then
        ok "encrypted setup detected: HOOKS now contain 'block plymouth encrypt'"
    else
        ok "unencrypted setup detected: HOOKS now contain 'block plymouth'"
    fi
    grep '^HOOKS=' "$CONF"
fi

# ensure quiet splash in kernel cmdline (needed for Plymouth)
if [[ -f /etc/kernel/cmdline ]]; then
    if ! grep -q 'splash' /etc/kernel/cmdline; then
        sed -i 's/^/quiet splash /' /etc/kernel/cmdline
        ok "added 'quiet splash' to /etc/kernel/cmdline"
    fi
fi

# -------------------------------------------------------------- 4. rebuild ----
info "rebuilding initramfs (mkinitcpio -P)"
if command -v mkinitcpio >/dev/null 2>&1; then
    if command -v ionice >/dev/null 2>&1; then
        ionice -c2 -n7 nice -n 10 mkinitcpio -P
    else
        nice -n 10 mkinitcpio -P
    fi
    ok "initramfs rebuilt"
else
    warn "mkinitcpio not found; rebuild manually: sudo mkinitcpio -P"
fi

# update Limine entries if available
if command -v limine-update >/dev/null 2>&1; then
    limine-update >/dev/null 2>&1 || true
fi
if command -v limine-mkinitcpio >/dev/null 2>&1; then
    limine-mkinitcpio >/dev/null 2>&1 || true
fi

# cleanup
rm -rf "$WORK"

echo
ok "Plymouth migration 20261509-1 complete"
echo
if [[ -t 0 ]]; then
    read -r -p "Reboot now to see the new boot splash? [y/N] " ans || ans=""
    if [[ "$ans" =~ ^[Yy] ]]; then
        reboot
        exit 0
    fi
fi
info "reboot later with: sudo reboot"
