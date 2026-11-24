#!/usr/bin/env bash
# 20261121-1.sh -- migration for existing installs: safe Floating rules.
#
# Floating is an Aequalyn arrangement, not a Hyprland layout name. A stale
# workspace-layouts.lua can still contain `layout = "floating"`, which Hyprland
# cannot load. This rewrites only those generated lines into the guarded shim
# that floating.lua understands, using the user's saved layout choices.
#
# Nothing else in the generated file is touched; user files and /etc are not
# changed. The next reload/login applies it.
#
# Usage:  sudo bash 20261121-1.sh        (run by aequalyn-update, or by hand)
#         AEQUALYN_MIGRATION_HOMES=/tmp/homes bash 20261121-1.sh  (tests)

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261121-1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261121-1]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261121-1]\033[0m %s\n' "$*"; }

SUPER_G='hl.bind(M .. " + G",       hl.dsp.exec_cmd("qs ipc call snap toggle"))       -- Snap layouts on floating windows'

for home in "${homes[@]}"; do
    rules="$home/.config/hypr/aequalyn/workspace-layouts.lua"
    settings="$home/.config/aequalyn/settings.json"
    keybinds="$home/.config/hypr/keybinds.lua"

    # Updates leave the user's keybinds.lua alone. Add the snap key only when
    # it is missing and Super + G is not already bound to something else.
    if [[ -f "$keybinds" ]] && ! grep -q 'qs ipc call snap toggle' "$keybinds"; then
        if grep -q '" + G"' "$keybinds"; then
            warn "$keybinds already binds Super + G; left as it is"
        else
            tmp=$(mktemp "$keybinds.XXXXXX")
            if grep -q '" + D"' "$keybinds"; then
                awk -v line="$SUPER_G" '{ print } /" \+ D"/ && !done { print line; done = 1 }' "$keybinds" > "$tmp"
            else
                { cat "$keybinds"; printf '%s\n' "$SUPER_G"; } > "$tmp"
            fi
            chown --reference="$keybinds" "$tmp" 2>/dev/null || true
            chmod --reference="$keybinds" "$tmp" 2>/dev/null || true
            mv -f "$tmp" "$keybinds"
            info "$keybinds: Super + G opens snap layouts"
        fi
    fi

    [[ -f "$rules" ]] || continue

    tmp=$(mktemp "$rules.XXXXXX")
    if ! python3 - "$settings" "$rules" > "$tmp" <<'PY'
import json, pathlib, re, sys

settings, rules = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
try:
    state = json.loads(settings.read_text()) if settings.is_file() else {}
except Exception:
    state = {}
layouts = state.get("layouts") if isinstance(state, dict) else {}
layouts = layouts if isinstance(layouts, dict) else {}
workspaces = layouts.get("workspaces") if isinstance(layouts, dict) else {}
workspaces = workspaces if isinstance(workspaces, dict) else {}
floating = {str(k) for k, v in workspaces.items() if v == "floating"}
default = layouts.get("default")

def shim(call):
    return f'if _G.aequalyn_floating then _G.aequalyn_floating.{call} end'

def has_ws(ws, value=None):
    needle = f'set_ws("{ws}"'
    return any(needle in line and (value is None or f', {value})' in line) for line in out)

text = rules.read_text()
out = []
for line in text.splitlines():
    match = re.match(r'^hl\.workspace_rule\(\{ workspace = "([^"]+)", layout = "floating" \}\)\s*$', line)
    if match:
        ws = match.group(1)
        if ws in floating and not has_ws(ws, "true"):
            out.append(shim(f'set_ws("{ws}", true)'))
        elif ws not in floating:
            out.append('-- stale Floating rule removed by migration 20261121-1')
            if default == "floating" and not has_ws(ws, "false"):
                out.append(shim(f'set_ws("{ws}", false)'))
        continue
    if line.strip() == 'hl.config({ general = { layout = "floating" } })':
        if default == "floating":
            if not any("set_default(true)" in item for item in out):
                out.append(shim("set_default(true)"))
        else:
            out.append('-- stale Floating default removed by migration 20261121-1')
        continue
    out.append(line)
    rule = re.match(r'^hl\.workspace_rule\(\{ workspace = "([^"]+)", layout = "([^"]+)" \}\)\s*$', line)
    if default == "floating" and rule and rule.group(1) not in floating:
        ws = rule.group(1)
        if not has_ws(ws, "false"):
            out.append(shim(f'set_ws("{ws}", false)'))

if default == "floating" and not any("set_default(true)" in line for line in out):
    out.append(shim("set_default(true)"))

sys.stdout.write("\n".join(out) + "\n")
PY
    then
        rm -f "$tmp"
        warn "$rules could not be read; left as it is"
        continue
    fi

    if cmp -s "$tmp" "$rules"; then
        rm -f "$tmp"
    else
        chown --reference="$rules" "$tmp" 2>/dev/null || true
        chmod --reference="$rules" "$tmp" 2>/dev/null || true
        mv -f "$tmp" "$rules"
        info "$rules: Floating rules made safe"
    fi

    # An explicit Super + L cycle does not learn new catalogue entries by
    # itself. Add Floating once; a cycle that already has it is left alone.
    if [[ -f "$settings" ]] && command -v jq >/dev/null 2>&1 \
       && jq -e '.layouts.cycle | type == "array"' "$settings" >/dev/null 2>&1 \
       && ! jq -e '.layouts.cycle | index("floating")' "$settings" >/dev/null 2>&1; then
        tmp=$(mktemp "$settings.XXXXXX")
        if jq '.layouts.cycle += ["floating"]' "$settings" > "$tmp"; then
            chown --reference="$settings" "$tmp" 2>/dev/null || true
            chmod --reference="$settings" "$tmp" 2>/dev/null || true
            mv -f "$tmp" "$settings"
            info "$settings: Floating added to the layout cycle"
        else
            rm -f "$tmp"
            warn "$settings could not be updated; left as it is"
        fi
    fi
done

ok "Floating workspace rules are safe"
