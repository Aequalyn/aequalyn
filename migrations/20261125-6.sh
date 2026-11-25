#!/usr/bin/env bash
# 20261125-6.sh -- migration for existing installs: the bar's other widgets.
#
# Installs from the ISO came with ten of the bar's widgets switched off (screen recorder,
# screenshot, layouts, title, brightness, CPU, temperature and more). Where all ten are still
# off, as they came, they are switched on; a bar that was changed is left alone.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

for home in "${homes[@]}"; do
    f="$home/.config/aequalyn/settings.json"
    [[ -f "$f" ]] || continue
    python3 - "$f" "$home" <<'PY'
import json, os, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
    a = d["appearance"]
    off = ["showLayouts", "showAtelier", "showTitle", "showBrightness", "showCpu", "showTemperature",
           "showCaffeine", "showScreenRecorder", "showScreenshot", "showClipscape"]
    if not all(a.get(k) is False for k in off):
        raise SystemExit(0)
except (OSError, ValueError, KeyError, TypeError, AttributeError):
    raise SystemExit(0)
for k in off:
    a[k] = True
st = os.stat(p)
tmp = p + ".aq-mig"
with open(tmp, "w") as f:
    f.write(json.dumps(d, indent=2) + "\n")
os.chmod(tmp, st.st_mode & 0o777)
try:
    os.chown(tmp, st.st_uid, st.st_gid)
except PermissionError:
    pass
os.replace(tmp, p)
print(f"\033[0;34m[20261125-6]\033[0m {sys.argv[2]}: the bar's widgets are on")
PY
done
printf '\033[0;32m[20261125-6]\033[0m %s\n' "migration 20261125-6 complete"
