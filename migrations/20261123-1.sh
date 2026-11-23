#!/usr/bin/env bash
# 20261123-1.sh -- migration for existing installs: finish FM and lock setup.
#
# The ISO's mkarchiso step strips executable bits from the shell tree in
# /opt/aequalyn, and install.sh used to copy those stripped modes into the
# user's ~/.config/quickshell. The FM launcher is exec'd directly by its
# desktop entry and by the D-Bus service that serves Open/Save dialogs, so a
# mode of 644 made it fail with "Permission denied". aequalyn-session-start
# also skips creating the desktop entry when it sees a non-executable launcher,
# which left the FM out of the app menu and out of the dock's app list.
#
# Separately, dock pins live in ~/.config/aequalyn/docks.json once that file
# exists; settings.json's dock.pinned is only the seed for a fresh home. Older
# installs therefore kept their Nautilus pin and never gained the FM even
# though the shipped settings.json already named it.
#
# This migration:
#   1. restores executable modes on plugin bins/daemons and the watchdog;
#   2. creates the FM's desktop entry if the session start skipped it, without
#      changing the user's choice of default file manager or portal;
#   3. adds aequalyn.fm to the settings.json seed if it is missing there;
#   4. adds aequalyn.fm to every existing docks.json, so the pin survives;
#   5. installs the root-owned PAM stacks the Quickshell lock plugin needs;
#   6. fixes /usr/share/aequalyn's mode and a stale "undefined" lock style.
#
# A running shell does not need a restart: the dock watches docks.json, and
# the .desktop entry is picked up on the next desktop-entry rescan.
#
# Usage:  sudo bash 20261123-1.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261123-1.sh  (tests)

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

# pacstrap can leave the nested pacman dirs without a+rx when the live
# environment has a restrictive umask. Restore the standard modes here so an
# update also repairs an install made from an older ISO.
for d in /var/lib/pacman /var/lib/pacman/local /var/lib/pacman/sync \
         /var/cache/pacman /var/cache/pacman/pkg; do
    [[ -d $d ]] && chmod 755 "$d" 2>/dev/null || true
done
# The shell watches /usr/share/aequalyn/lockscreens.enabled; a mode-700
# directory makes that FileView fail with "Permission denied".
chmod 755 /usr/share/aequalyn 2>/dev/null || true
[[ -e /usr/share/aequalyn/lockscreens.enabled ]] \
    && chmod 644 /usr/share/aequalyn/lockscreens.enabled 2>/dev/null || true

info() { printf '\033[0;34m[20261123-1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261123-1]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261123-1]\033[0m %s\n' "$*"; }

homes=(/home/* /root)
if [[ -n ${AEQUALYN_MIGRATION_HOMES:-} ]]; then
    read -r -a homes <<< "$AEQUALYN_MIGRATION_HOMES"
fi

for home in "${homes[@]}"; do
    [[ -d $home ]] || continue
    qs=$home/.config/quickshell
    fm_dir=$qs/plugins/aequalynfm
    [[ -d $fm_dir ]] || continue          # no Aequalyn FM on this machine

    owner=$(stat -c '%u:%g' "$fm_dir")
    uid=${owner%%:*}

    # 1. modes stripped by mkarchiso (or by a tar copy made before install.sh
    # learned to fix them). All of these are exec'd, never sourced.
    chmod 755 "$qs/plugins/clipboard/capture.sh" \
              "$qs/tools/watchdog/aequalyn-watchdog" 2>/dev/null || true
    for d in "$qs"/plugins/*/bin "$qs"/plugins/*/daemon; do
        [[ -d $d ]] && chmod 755 "$d"/* 2>/dev/null || true
    done

    # The lock plugin refuses to lock without /etc/pam.d/aequalyn-lock-password.
    # Fresh ISO installs stamp migration 20261122-4 as done and never ran it, so
    # install the stacks here. SUDO_USER makes the helper read this user's
    # templates instead of root's.
    apply_lock=$home/.local/bin/aequalyn-apply-lock
    [[ -x $apply_lock ]] || apply_lock=/usr/local/bin/aequalyn-apply-lock
    if [[ -x $apply_lock ]]; then
        user=$(stat -c '%U' "$home" 2>/dev/null || true)
        if [[ -n $user && $user != root ]] && SUDO_USER="$user" "$apply_lock" >/dev/null 2>&1; then
            info "installed Aequalyn lock PAM stacks for $user"
        else
            warn "could not install Aequalyn lock PAM stacks for $home"
        fi
    fi

    bin=$fm_dir/bin/aequalyn-fm
    [[ -f $bin ]] || continue

    # 2. a mode-stripped launcher made aequalyn-session-start skip --install.
    # Only the menu entry is restored here; default-app and portal choices stay
    # exactly as the user left them.
    entry=$home/.local/share/applications/aequalyn.fm.desktop
    if [[ ! -f $entry ]]; then
        if runuser -u "#$uid" -- env HOME="$home" "$bin" --install >/dev/null 2>&1; then
            chown "$owner" "$entry" 2>/dev/null || true
            info "registered Aequalyn FM's desktop entry for $home"
        else
            warn "could not register Aequalyn FM's desktop entry for $home"
        fi
    fi

    # 3. the seed used when no docks.json exists yet.
    settings=$home/.config/aequalyn/settings.json
    if [[ -f $settings ]]; then
        python3 - "$settings" <<'PY'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception:
    raise SystemExit(0)
dock = d.get("dock")
if not isinstance(dock, dict):
    dock = {}
    d["dock"] = dock
pinned = dock.get("pinned")
if not isinstance(pinned, list):
    pinned = []
changed = False
if "aequalyn.fm" not in [str(x).removesuffix(".desktop") for x in pinned]:
    pinned.insert(0, "aequalyn.fm")
    dock["pinned"] = pinned
    changed = True
# Some look/theme writes left the literal string "undefined" here. The shell
# accepts it (it matches [a-z0-9-]+) but LockView falls back to classic anyway;
# store the real default so the setting says what is actually shown.
power = d.get("power")
if isinstance(power, dict) and str(power.get("lockStyle", "")) in ("undefined", ""):
    power["lockStyle"] = "classic"
    changed = True
if changed:
    open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY
        chown "$owner" "$settings" 2>/dev/null || true
    fi

    # 4. docks.json is authoritative once present. Without the desktop entry
    # from step 2 the shell would prune this pin again after ~20 seconds.
    docks_file=$home/.config/aequalyn/docks.json
    if [[ -f $docks_file ]]; then
        python3 - "$docks_file" <<'PY'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception:
    raise SystemExit(0)
docks = d.get("docks")
if not isinstance(docks, list):
    raise SystemExit(0)
changed = False
for dock in docks:
    apps = dock.get("apps")
    if not isinstance(apps, list):
        continue
    if "aequalyn.fm" not in [str(a).removesuffix(".desktop") for a in apps]:
        apps.append("aequalyn.fm")
        dock["apps"] = apps
        changed = True
if changed:
    open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY
        chown "$owner" "$docks_file" 2>/dev/null || true
        ok "pinned Aequalyn FM in $docks_file"
    fi
done
