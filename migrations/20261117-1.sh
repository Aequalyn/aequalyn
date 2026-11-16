#!/usr/bin/env bash
# 20261117-1.sh -- keep per-monitor workspace numbers stable on existing installs.
#
# Updates deliberately leave the user's ~/.config/hypr/hyprland.lua alone, so the
# persistent workspace slots added to the shipped config never reach existing
# machines. Without them Hyprland destroys empty workspaces, which shifts the
# per-monitor positions that `r~N` and the bar's pills resolve against (a window
# moved to workspace 5 can end up labelled 2).
#
# Adds the same "reserve 10 workspaces per monitor" block to each user's
# hyprland.lua and aligns the workspace keybinds with the shipped `r~N` form.
# Idempotent: files with the marker are left untouched.
#
# Usage:  sudo bash 20261117-1.sh        (run by aequalyn-update, or by hand)

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

MARKER='Reserve 10 numbered workspaces'

info() { printf '\033[0;34m[20261117-1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261117-1]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261117-1]\033[0m %s\n' "$*"; }

patched=0

for home in /home/* /root; do
    [[ -d "$home" ]] || continue
    f="$home/.config/hypr/hyprland.lua"
    [[ -f "$f" ]] || continue
    grep -qF "$MARKER" "$f" && continue

    owner=$(stat -c '%u:%g' "$f" 2>/dev/null || true)
    info "patching $f"

    if ! python3 - "$f" <<'PY'
import sys

p = sys.argv[1]
block = """-- Reserve 10 numbered workspaces per monitor with stable global ids
-- (1-10 on the first monitor, 11-20 on the second, ...). `persistent` keeps
-- empty slots alive: Hyprland otherwise destroys them, which shifts the
-- per-monitor positions that `r~N` and the bar's pills both use.
do
  local mons = hl.get_monitors()
  table.sort(mons, function(a, b) return a.id < b.id end)
  for idx, mon in ipairs(mons) do
    local base = (idx - 1) * 10
    for n = 1, 10 do
      hl.workspace_rule({ workspace = tostring(base + n), monitor = mon.name, persistent = true })
    end
  end
end
"""

with open(p, encoding="utf-8") as fh:
    s = fh.read()

if "Reserve 10 numbered workspaces" in s:
    sys.exit(0)

# Prefer the workspace section of the shipped config. Fall back to the
# workspace keybind comment, then to the end of the file -- top-level Lua can
# register the rules at any point after the monitors are configured.
banner = "-" * 70 + " workspaces"
idx = s.find(banner)
if idx >= 0:
    nl = s.find("\n", idx)
    at = nl + 1 if nl >= 0 else len(s)
    s = s[:at] + block + s[at:]
elif "-- Workspaces\n" in s:
    s = s.replace("-- Workspaces\n", block + "\n-- Workspaces\n", 1)
else:
    s = s.rstrip("\n") + "\n\n" + block

# The shipped config uses r~N; older copies used m~N. Persistent slots make
# both work, but keep existing configs consistent with the current default.
s = s.replace('"m~" .. i', '"r~" .. i')

with open(p, "w", encoding="utf-8") as fh:
    fh.write(s)
PY
    then
        warn "could not patch $f; leaving it for the next update"
        continue
    fi

    [[ -n "$owner" ]] && chown "$owner" "$f" 2>/dev/null || true
    patched=$((patched + 1))
    ok "workspace slots added to $f"
done

if [[ $patched -eq 0 ]]; then
    ok "workspace slots already in place (nothing to do)"
else
    ok "patched $patched Hyprland config(s)"
fi
