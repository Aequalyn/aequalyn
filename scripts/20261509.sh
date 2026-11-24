#!/usr/bin/env bash
# 20261509.sh -- migration for existing Aequalyn installs.
#
# Fixes:
#   1. Replaces the old (crash-prone, in-place) aequalyn-update with the safe
#      version that wraps itself in main() and swaps helper scripts via rename.
#   2. Installs SDDM if it is missing.
#   3. Seeds the default "Aequalyn" SDDM theme into /usr/share/sddm/themes.
#   4. Sets "Aequalyn" as the default SDDM theme.
#   5. Offers to download + install the optional lock-screen theme pack
#      (aequalyn-lockscreens), asking the user first.
#
# Usage:  sudo bash 20261509.sh

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

AQ_ROOT=/usr/share/aequalyn
SDDM_THEMES=/usr/share/sddm/themes
MARKER=/usr/share/aequalyn/lockscreens.enabled
LOCKSCREENS_URL=https://github.com/Aequalyn/aequalyn-lockscreens.git

info() { printf '\033[0;34m[20261509]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261509]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261509]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------- 1. updater ---
info "fixing aequalyn-update (safe version)"
NEW_UPDATER=/tmp/aequalyn-update.new.$$
if curl -fsSL https://raw.githubusercontent.com/Aequalyn/aequalyn/main/bin/aequalyn-update -o "$NEW_UPDATER" 2>/dev/null; then
    chmod 755 "$NEW_UPDATER"
    cp "$NEW_UPDATER" /usr/local/bin/.aequalyn-update.new
    mv -f /usr/local/bin/.aequalyn-update.new /usr/local/bin/aequalyn-update
    chmod 755 /usr/local/bin/aequalyn-update
    rm -f "$NEW_UPDATER"
    ok "aequalyn-update replaced with safe version"
else
    warn "could not download updater (offline?); skipping"
fi

# ---------------------------------------------------------------- 2. SDDM ----
if ! command -v sddm >/dev/null 2>&1; then
    info "SDDM not found; installing"
    if command -v pacman >/dev/null 2>&1; then
        pacman -S --noconfirm sddm
    else
        warn "pacman not available; install SDDM manually"
    fi
fi

# ---------------------------------------------------------------- 3. default theme (Aequalyn) ---
info "seeding default Aequalyn SDDM theme"
mkdir -p "$SDDM_THEMES"
if [[ ! -d "$SDDM_THEMES/aequalyn" ]]; then
    # Try local lockscreens repo first, then download
    SRC=""
    for cand in /usr/share/aequalyn/lockscreens /home/*/Projects/aequalyn-lockscreens /tmp/aequalyn-lockscreens; do
        if [[ -d "$cand/aequalyn" ]]; then SRC="$cand/aequalyn"; break; fi
    done
    if [[ -z "$SRC" ]]; then
        info "downloading aequalyn-lockscreens (for the default theme)"
        rm -rf /tmp/aequalyn-lockscreens
        git clone -q --depth 1 "$LOCKSCREENS_URL" /tmp/aequalyn-lockscreens 2>/dev/null || true
        [[ -d /tmp/aequalyn-lockscreens/aequalyn ]] && SRC=/tmp/aequalyn-lockscreens/aequalyn
    fi
    if [[ -n "$SRC" && -d "$SRC" ]]; then
        rm -rf "$SDDM_THEMES/aequalyn"
        cp -r "$SRC" "$SDDM_THEMES/aequalyn"
        ok "Aequalyn SDDM theme seeded"
    else
        warn "could not obtain the Aequalyn theme; skipping"
    fi
fi

# set as default
mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=aequalyn\n' > /etc/sddm.conf.d/aequalyn-theme.conf
ok "default SDDM theme set to Aequalyn"

# ---------------------------------------------------------------- 4. offer lockscreens ---
if [[ -f "$MARKER" ]]; then
    info "lock screens already installed; skipping prompt"
else
    # estimate size
    echo
    echo "The optional SDDM lock-screen theme pack contains ~50 themes (echo, pixie,"
    echo "qylock, abstractdark, ...)."
    echo "  Download: ~400 MB     Disk usage: ~600 MB"
    echo
    read -r -p "Do you want to download and use the lock screens? [y/N] " ans
    if [[ "$ans" =~ ^[Yy] ]]; then
        if command -v aequalyn-sddm >/dev/null 2>&1; then
            aequalyn-sddm install
        else
            info "aequalyn-sddm not found; downloading lockscreens directly"
            rm -rf /tmp/aequalyn-lockscreens
            git clone -q --depth 1 "$LOCKSCREENS_URL" /tmp/aequalyn-lockscreens
            mkdir -p "$SDDM_THEMES" /usr/share/fonts/qylock
            for t in /tmp/aequalyn-lockscreens/*/; do
                [[ -d "$t" ]] || continue
                n=$(basename "$t")
                rm -rf "$SDDM_THEMES/$n"
                cp -r "$t" "$SDDM_THEMES/$n"
            done
            find /tmp/aequalyn-lockscreens -type f \( -name "*.ttf" -o -name "*.otf" \) -exec cp -n {} /usr/share/fonts/qylock/ \; 2>/dev/null || true
            fc-cache -f 2>/dev/null || true
            mkdir -p /usr/share/aequalyn
            printf '1\n' > "$MARKER"
            ok "lock screens installed"
        fi
    else
        info "skipping lock screens; the Lock Screens page will be hidden in Settings"
    fi
fi

echo
ok "migration 20261509 complete"