#!/usr/bin/env bash
# 20261118-3.sh -- migration for existing installs: the qt5 app's dialogs on
# the portal, today and whenever it is installed later.
#
# aequalyn fm answers every app's open and save dialog, but only apps that
# ask the portal get that window: gtk apps do (GTK_USE_PORTAL is set for the
# session) and qt6 apps do (QT_QPA_PLATFORMTHEME=qt6ct, whose standard_dialogs
# ask the portal). vlc is a qt5 app, and qt5 knows none of those names, so it
# kept its own grey dialog while every other app on the desktop asked fm.
#
# This:
#   1. installs bin/aequalyn-qt5-dialogs' pacman hook, so from now on every
#      install, upgrade or removal of vlc patches every aequalyn user's home
#      on the spot: a vlc installed months after the system gets the fm
#      dialog the moment pacman finishes, no update in sight;
#   2. runs that engine once now, so a vlc already on the machine is patched
#      today. a machine with no vlc yet only gets the hook; the hook does
#      the rest whenever vlc arrives.
#
# It defers (exit 3, tried again on the next update) while the engine is
# missing, so a half-updated tree never writes half the fix.
#
# Usage:  sudo bash 20261118-3.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261118-3.sh  (tests: those homes)

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

AQ_ROOT=${AEQUALYN_ROOT:-/usr/share/aequalyn}
engine=$AQ_ROOT/bin/aequalyn-qt5-dialogs

info() { printf '\033[0;34m[20261118-3]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261118-3]\033[0m %s\n' "$*"; }

if [[ ! -f $engine ]]; then
    info "bin/aequalyn-qt5-dialogs is not in the tree yet; trying again on the next update"
    exit 3
fi

info "installing the pacman hook (vlc installs from now on patch themselves)"
bash "$engine" --install-hook

info "patching the homes that have an aequalyn shell (a vlc already there gets it now)"
bash "$engine"

ok "vlc's open and save dialogs come from the fm window, whichever day it is installed"
