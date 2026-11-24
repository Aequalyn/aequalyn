#!/usr/bin/env bash
# 20261118-2.sh -- migration for existing installs: bring Aequalyn FM up.
#
# Aequalyn FM -- the file manager plugin -- talks to a Python file daemon
# (plugins/aequalynfm/daemon/fmd.py) that needs PyGObject: it imports gi for
# its file work, and the same daemon serves every app's Open/Save dialog.
# The package lists install python-gobject with the shell now, but a machine
# set up earlier only got it by chance (nautilus-python happened to pull it
# in), and on the ones without it the daemon dies at its import: the file
# windows never come up, and the dialogs fall back to gtk's.
#
# The registrations the FM's own installer writes also pin absolute paths:
# `aequalyn-fm --install` / `--default` / `--portal` record the path of the
# copy they were run from, so a machine that first met the FM through the
# pre-plugin standalone, a repo clone or the system tree keeps calling the
# old one after the plugin arrived in the home's shell copy.
#
# This:
#   1. re-points each user's Aequalyn FM registrations -- the desktop entry
#      and the D-Bus service that xdg-desktop-portal starts -- at that
#      user's shell copy, and puts the shipped icon where the entry looks;
#   2. keeps every choice as it was: the open-folders default and the portal
#      preference stay, only the paths move. Nothing is written for a user
#      that never registered the FM, or whose registrations already point
#      at the copy in their home;
#   3. installs python-gobject, which the file daemon imports at its start.
#
# A running shell needs no restart: its plugin restarts the daemon on its
# own, which then finds gi and comes up; the re-pointed D-Bus service is
# reloaded best-effort, and a login later everything follows anyway.
#
# It defers (exit 3, tried again on the next update) while python-gobject
# cannot be installed, so the path fixes are never held back by it.
#
# Usage:  sudo bash 20261118-2.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261118-2.sh  (tests: those homes)

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

info() { printf '\033[0;34m[20261118-2]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261118-2]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261118-2]\033[0m %s\n' "$*"; }

# a path, safe to put in a sed replacement
esc() { printf '%s' "$1" | sed 's/[&/\]/\\&/g'; }

# re-point the Exec= lines that call an aequalyn-fm launcher at `new`, keeping
# their arguments and their quoting. Returns 0 when the file changed, 1 when it
# was already right, 2 when there is nothing to point.
repoint() { # file new-bin
    local f=$1 bin qbin ubin tmp
    [[ -f $f ]] || return 2
    bin=$(esc "$2")
    qbin="\"$bin\""
    # a path with a space must be quoted for both files
    [[ $2 == *[[:space:]]* ]] && ubin=$qbin || ubin=$bin
    tmp=$f.aequalyn-mig.$$
    sed -E \
        -e "s#^(Exec=)\"[^\"]*aequalyn-fm\"(.*)\$#\1$qbin\2#" \
        -e "s#^(Exec=)[^\" ]*aequalyn-fm(.*)\$#\1$ubin\2#" "$f" > "$tmp"
    if cmp -s "$f" "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$f"
    return 0
}

# ------------------------------------------------------- 1. the registrations ---
homes=(/home/* /root)
if [[ -n ${AEQUALYN_MIGRATION_HOMES:-} ]]; then
    read -r -a homes <<< "$AEQUALYN_MIGRATION_HOMES"
fi

moved=0
users=0
for home in "${homes[@]}"; do
    [[ -d $home ]] || continue
    fm_dir=$home/.config/quickshell/plugins/aequalynfm
    [[ -d $fm_dir ]] || continue          # no Aequalyn FM on this machine
    users=$((users + 1))
    bin=$fm_dir/bin/aequalyn-fm
    owner=$(stat -c '%u:%g' "$fm_dir")
    uid=${owner%%:*}
    data=$home/.local/share

    # the desktop entry and the D-Bus service run this file itself: the iso can
    # strip modes, so make sure it can run
    [[ -f $bin ]] && chmod 755 "$bin"

    # the desktop entry, written by `aequalyn-fm --install` or `--default`.
    # Only its Exec lines move; the open-folders default stays as it was.
    entry=$data/applications/aequalyn.fm.desktop
    if [[ -f $entry ]]; then
        if repoint "$entry" "$bin"; then
            chown "$owner" "$entry"
            info "re-pointed $entry at the shell copy in $home"
            moved=$((moved + 1))
        else
            ok "$entry already points at the shell copy in $home"
        fi
        # the entry says Icon=aequalyn-fm: put the shipped one where that is
        # looked up, without touching one already there
        if [[ -f $fm_dir/aequalyn-fm.svg && ! -f $data/icons/hicolor/scalable/apps/aequalyn-fm.svg ]]; then
            mkdir -p "$data/icons/hicolor/scalable/apps"
            cp "$fm_dir/aequalyn-fm.svg" "$data/icons/hicolor/scalable/apps/aequalyn-fm.svg"
            chown "$owner" "$data/icons/hicolor/scalable/apps/aequalyn-fm.svg"
            info "installed the FM's icon for $home"
        fi
    fi

    # the D-Bus service xdg-desktop-portal starts when an app asks for a
    # dialog, written by `aequalyn-fm --portal`. The portal preference stays.
    svc=$data/dbus-1/services/org.freedesktop.impl.portal.desktop.aequalyn.service
    if [[ -f $svc ]]; then
        if repoint "$svc" "$bin"; then
            chown "$owner" "$svc"
            info "re-pointed $svc at the shell copy in $home"
            moved=$((moved + 1))
            # a running session keeps the old activation command in memory
            if [[ -S /run/user/$uid/bus ]] && command -v runuser >/dev/null 2>&1; then
                runuser -u "#$uid" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
                    busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
                    org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
            fi
        else
            ok "$svc already points at the shell copy in $home"
        fi
    fi
done

if [[ $users -eq 0 ]]; then
    ok "no Aequalyn shell copies found; nothing to move"
elif [[ $moved -eq 0 ]]; then
    ok "every FM registration already points at its user's shell copy"
else
    ok "re-pointed $moved FM registration(s)"
fi

# ---------------------------------------------------------- 2. the dependency ---
info "checking python-gobject (the file daemon imports gi)"
if ! command -v pacman >/dev/null 2>&1; then
    warn "no pacman here: cannot install python-gobject; the file daemon needs it"
elif pacman -Q python-gobject >/dev/null 2>&1; then
    ok "python-gobject is installed"
elif pacman -S --needed --noconfirm python-gobject; then
    ok "python-gobject installed"
else
    warn "python-gobject could not be installed (offline?); trying again on the next update"
    exit 3
fi

ok "Aequalyn FM is set: a running shell brings its daemon up on its own restart"
