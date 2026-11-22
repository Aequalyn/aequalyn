#!/usr/bin/env bash
# 20261122-3.sh -- migration for existing installs: .desktop entries for
# console apps (btop, nudu).
#
# btop and nudu are terminal programs: clicking their icon must open them in
# a terminal emulator. Ship a .desktop entry for each that launches through
# xdg-terminal-exec, so the user's preferred installed terminal
# (foot, kitty, alacritty, ghostty, ...) is used.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
    homes=(/home/* /root)
else
    homes=("$AEQUALYN_MIGRATION_HOMES"/*)
fi

info() { printf '\033[0;34m[20261122-3]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261122-3]\033[0m %s\n' "$*"; }

BTOP_DESKTOP='[Desktop Entry]
Type=Application
Version=1.0
Name=btop++
GenericName=System Monitor
Comment=Resource monitor that shows usage and stats for processor, memory, disks, network and processes
Icon=btop
Exec=xdg-terminal-exec btop
Terminal=false
Categories=System;Monitor;ConsoleOnly;
Keywords=system;process;task;monitor;btop;
StartupNotify=false
'

NUDU_DESKTOP='[Desktop Entry]
Type=Application
Name=nudu
GenericName=Disk Usage Analyzer
Comment=See what is using your disk, in the terminal
Icon=drive-harddisk
Exec=xdg-terminal-exec nudu
Terminal=false
Categories=System;Utility;ConsoleOnly;
Keywords=disk;usage;du;space;storage;
StartupNotify=false
'

for home in "${homes[@]}"; do
    [[ -d "$home" ]] || continue
    apps="$home/.local/share/applications"
    mkdir -p "$apps"
    printf '%s' "$BTOP_DESKTOP" > "$apps/btop.desktop"
    printf '%s' "$NUDU_DESKTOP" > "$apps/nudu.desktop"
    chown --reference="$home" "$apps/btop.desktop" "$apps/nudu.desktop" 2>/dev/null || true
    chmod 644 "$apps/btop.desktop" "$apps/nudu.desktop"
    info "$home: btop.desktop, nudu.desktop installed"
done

# System-wide entries too, so package-less installs and the app menu see them.
if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    if [[ -f /usr/share/applications/btop.desktop ]]; then
        # keep the shipped btop entry but point it at a terminal
        printf '%s' "$BTOP_DESKTOP" > /usr/share/applications/btop.desktop
    else
        printf '%s' "$BTOP_DESKTOP" > /usr/share/applications/btop.desktop
    fi
    printf '%s' "$NUDU_DESKTOP" > /usr/share/applications/nudu.desktop
    chmod 644 /usr/share/applications/btop.desktop /usr/share/applications/nudu.desktop
    info "/usr/share/applications: btop.desktop, nudu.desktop installed"
fi

ok "migration 20261122-3 complete"
