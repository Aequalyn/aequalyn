#!/usr/bin/env bash
# 20261126-1.sh -- migration for existing installs: the Aequalyn SDDM session.
#
# Installs /usr/share/wayland-sessions/aequalyn.desktop (bin/aequalyn-session)
# and points SDDM autologin at it with Relogin=false. Log out with autologin on
# then starts a fresh desktop without the greeter (aequalyn-logout), while a
# desktop that crashes or cannot start lands on the greeter instead of looping.
# Without autologin (no aequalyn-autologin.conf) only the session file is added.
#
# Usage:  sudo bash 20261126-1.sh        (run by aequalyn-update, or by hand)

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

root=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
src=$root/assets/wayland-sessions/aequalyn.desktop
[[ -f $src && -x $root/bin/aequalyn-session ]] || { echo "aequalyn session files missing in $root" >&2; exit 1; }
install -Dm644 "$src" /usr/share/wayland-sessions/aequalyn.desktop

conf=/etc/sddm.conf.d/aequalyn-autologin.conf
if [[ -f $conf ]]; then
    sed -i -e 's/^Session=.*/Session=aequalyn/' -e 's/^Relogin=.*/Relogin=false/' "$conf"
    grep -q '^Session=' "$conf" || sed -i '/^\[Autologin\]$/a Session=aequalyn' "$conf"
    grep -q '^Relogin=' "$conf" || sed -i '/^\[Autologin\]$/a Relogin=false' "$conf"
fi
printf '\033[0;32m[20261126-1]\033[0m %s\n' "Aequalyn SDDM session installed"
