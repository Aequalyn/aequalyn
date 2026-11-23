#!/usr/bin/env bash
# 20261123-2.sh -- migration for existing installs: ~/.local/bin on Hyprland's PATH.
#
# SDDM launches /usr/bin/start-hyprland directly, so neither /etc/profile.d nor
# aequalyn-desktop runs for the graphical login. Hyprland inherits a base PATH
# that does not contain ~/.local/bin, and every bind calling an aequalyn-*
# helper by name (Print, XF86SelectiveScreenshot, aequalyn-lock, ...) fails
# silently. Fresh installs already ship the fix in config/hypr/environment.lua;
# this backfills that block into existing homes without discarding user edits.
#
# Usage:  sudo bash 20261123-2.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261123-2.sh  (tests)

set -euo pipefail

if [[ -z ${AEQUALYN_MIGRATION_HOMES:-} ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    read -r -a homes <<< "$AEQUALYN_MIGRATION_HOMES"
fi

info() { printf '\033[0;34m[20261123-2]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261123-2]\033[0m %s\n' "$*"; }

marker='local USER_BIN = HOME_DIR .. "/.local/bin"'

for home in "${homes[@]}"; do
    [[ -d $home ]] || continue
    f="$home/.config/hypr/environment.lua"
    [[ -f $f ]] || continue
    if grep -Fq "$marker" "$f"; then
        continue
    fi

    tmp="${f}.aq-path.$$"
    python3 - "$f" "$tmp" <<'PY'
import sys

src, dst = sys.argv[1:]
block = '''-- The display manager starts Hyprland with a base PATH that omits ~/.local/bin.
-- Keybinds call the aequalyn-* helpers by name, so add it here or every such
-- bind (Print, XF86SelectiveScreenshot, aequalyn-lock, ...) fails silently.
local HOME_DIR = os.getenv("HOME") or ""
local USER_BIN = HOME_DIR .. "/.local/bin"
local CURRENT_PATH = os.getenv("PATH") or ""
if not (":" .. CURRENT_PATH .. ":"):find(":" .. USER_BIN .. ":", 1, true) then
    local new_path = USER_BIN
    if CURRENT_PATH ~= "" then new_path = new_path .. ":" .. CURRENT_PATH end
    hl.env("PATH", new_path)
end

'''

with open(src, encoding="utf-8") as fh:
    lines = fh.readlines()
at = 0
for i, line in enumerate(lines):
    if line.lstrip().startswith("-") and "environment" in line:
        at = i + 1
        break
lines.insert(at, block)
with open(dst, "w", encoding="utf-8") as fh:
    fh.writelines(lines)
PY
    cat "$tmp" > "$f"
    rm -f "$tmp"
    info "$home: ~/.local/bin added to Hyprland's PATH"

    # Pick up the change in a running session, if this user has one.
    uid=$(stat -c '%u' "$home" 2>/dev/null || true)
    user=$(stat -c '%U' "$home" 2>/dev/null || true)
    [[ -n ${uid:-} && -n ${user:-} && $user != root ]] || continue
    runtime="/run/user/$uid"
    sig=""
    for lock in "$runtime"/hypr/*/hyprland.lock; do
        [[ -f $lock ]] || continue
        pid=$(head -n 1 "$lock" 2>/dev/null || true)
        [[ ${pid:-} =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null || continue
        sig=${lock%/hyprland.lock}
        sig=${sig##*/}
        break
    done
    if [[ -n $sig ]] && command -v runuser >/dev/null 2>&1; then
        runuser -u "$user" -- env XDG_RUNTIME_DIR="$runtime" \
            HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl reload >/dev/null 2>&1 || true
    fi
done

ok "migration 20261123-2 complete"
