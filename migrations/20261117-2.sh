#!/usr/bin/env bash
# 20261117-2.sh -- deliver the new Clipscape clipboard app, the new Settings app
# and clipboard.lua to existing installs.
#
# aequalyn-update normally brings these in by git-fetching aequalyn-shell. When
# that GitHub pull fails on a machine, the new files never arrive. This migration
# fetches just the needed files over HTTPS raw.githubusercontent.com (the same
# host the README's standalone migration recipe uses), once, and copies them to:
#
#   ~/.config/quickshell/                          the running shell
#   /usr/share/aequalyn/shell/                     system template, so a later
#                                                  `aequalyn-update --no-pull`
#                                                  doesn't replace them
#   ~/.config/hypr/aequalyn/clipboard.lua          the Super+Ctrl+V keybind
#   /usr/share/aequalyn/config/hypr/aequalyn/      system template
#
# Existing settings.json files gain the clipscape plugin, showClipscape and a
# bar slot; existing hyprland.lua files gain the clipboard.lua include. Nothing
# else the user changed is overwritten.
#
# Pinned to the shell commit that introduced Clipscape so the fetched files are
# a consistent set. Override AEQUALYN_SHELL_REF / AEQUALYN_REF (or the two raw
# base URLs) to fetch a different revision.
#
# Safe to run twice. Exit 3 on a download failure so aequalyn-update retries.
#
# Usage:  sudo bash 20261117-2.sh        (run by aequalyn-update, or by hand)

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }

# Commit that shipped Clipscape + the new Settings app (aequalyn-shell 68f352e)
# and the matching core config (aequalyn 724f0a5).
SHELL_REF=${AEQUALYN_SHELL_REF:-68f352ea17bcd8d947ce51fbdb497ca571ec0467}
AQ_REF=${AEQUALYN_REF:-724f0a50d78d13bf2281f24e7ae5ece10c0551b3}
SHELL_RAW=${AEQUALYN_SHELL_RAW:-https://raw.githubusercontent.com/Aequalyn/aequalyn-shell/$SHELL_REF}
AQ_RAW=${AEQUALYN_AQ_RAW:-https://raw.githubusercontent.com/Aequalyn/aequalyn/$AQ_REF}
AQ_ROOT=${AEQUALYN_ROOT:-/usr/share/aequalyn}

info() { printf '\033[0;34m[20261117-2]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261117-2]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[20261117-2]\033[0m %s\n' "$*"; }

# This migration's files are pinned to the revision that introduced Clipscape
# and the new Settings app. A tree that already has them -- a fresh install,
# or any machine aequalyn-update has synced since (the sync runs before the
# migrations) -- is at or past that revision, and copying the pinned files
# over it would roll it BACK: old Settings pages over new ones, an old
# Plugins.js over a new BarSlot.qml, the lot. Only a tree still missing them
# (this run by hand on a machine that could not pull) needs the download.
if [[ -f "$AQ_ROOT/shell/plugins/clipscape/qmldir" && -f "$AQ_ROOT/shell/settings/center/Cc.qml" ]]; then
    ok "the shell already has Clipscape and the new Settings app; nothing to do"
    exit 0
fi

# The complete set of shell files that make up the new clipboard app and the
# Settings app: plugin registry + Clipscape widget/entry, the whole Clipscape
# plugin, and the whole settings/ tree.
SHELL_FILES=(
    Plugins.js
    plugins/bar/widgets/ClipscapeButton.qml
    plugins/bar/widgets/Widgets.js
    plugins/clipscape/Clipscape.qml
    plugins/clipscape/LICENSE
    plugins/clipscape/README.md
    plugins/clipscape/assets/logo-dark.png
    plugins/clipscape/assets/logo-dark.svg
    plugins/clipscape/assets/logo.png
    plugins/clipscape/assets/logo.svg
    plugins/clipscape/bin/clipscape
    plugins/clipscape/manifest.json
    plugins/clipscape/qml/Picker.qml
    plugins/clipscape/qml/Service.qml
    plugins/clipscape/qml/controls/Btn.qml
    plugins/clipscape/qml/controls/Chip.qml
    plugins/clipscape/qml/controls/Frame.qml
    plugins/clipscape/qml/controls/Sw.qml
    plugins/clipscape/qml/controls/TextBox.qml
    plugins/clipscape/qml/controls/Txt.qml
    plugins/clipscape/qml/core/ClipStore.qml
    plugins/clipscape/qml/core/SettingsStore.qml
    plugins/clipscape/qml/core/UiState.qml
    plugins/clipscape/qml/js/Clips.js
    plugins/clipscape/qml/js/Schema.js
    plugins/clipscape/qml/js/Theme.js
    plugins/clipscape/qml/panel/AboutPage.qml
    plugins/clipscape/qml/panel/Panel.qml
    plugins/clipscape/qml/panel/PanelView.qml
    plugins/clipscape/qml/panel/PopoutWindow.qml
    plugins/clipscape/qml/panel/SettingRow.qml
    plugins/clipscape/qml/panel/SettingsView.qml
    plugins/clipscape/qml/panel/TileArt.qml
    plugins/clipscape/qml/panel/qmldir
    plugins/clipscape/qml/picker/ActionMenu.qml
    plugins/clipscape/qml/picker/ClipRow.qml
    plugins/clipscape/qml/picker/ClipView.qml
    plugins/clipscape/qml/picker/KindIcon.qml
    plugins/clipscape/qml/picker/PreviewPane.qml
    plugins/clipscape/qmldir
    plugins/clipscape/tests/test_helper.py
    plugins/clipscape/tests/test_model.js
    settings/AequalynDefaultTheme.qml
    settings/AequalynSettings.qml
    settings/ControlCenter.qml
    settings/center/AppsService.qml
    settings/center/BackupService.qml
    settings/center/Cc.qml
    settings/center/CcButton.qml
    settings/center/CcCard.qml
    settings/center/CcChoice.qml
    settings/center/CcField.qml
    settings/center/CcMore.qml
    settings/center/CcNote.qml
    settings/center/CcPage.qml
    settings/center/CcRow.qml
    settings/center/CcSection.qml
    settings/center/CcSlider.qml
    settings/center/CcSwitch.qml
    settings/center/CcToggle.qml
    settings/center/Pages.js
    settings/center/UpdatesService.qml
    settings/center/WebappsService.qml
    settings/center/pages/About.qml
    settings/center/pages/AiTools.qml
    settings/center/pages/Apps.qml
    settings/center/pages/Arrange.qml
    settings/center/pages/Backup.qml
    settings/center/pages/Bar.qml
    settings/center/pages/Bluetooth.qml
    settings/center/pages/Clipboard.qml
    settings/center/pages/Clock.qml
    settings/center/pages/Cursor.qml
    settings/center/pages/Dock.qml
    settings/center/pages/Home.qml
    settings/center/pages/Input.qml
    settings/center/pages/LockScreens.qml
    settings/center/pages/Picker.qml
    settings/center/pages/Plugins.qml
    settings/center/pages/Screens.qml
    settings/center/pages/Sleep.qml
    settings/center/pages/Sound.qml
    settings/center/pages/Store.qml
    settings/center/pages/Theme.qml
    settings/center/pages/Updates.qml
    settings/center/pages/Wallpaper.qml
    settings/center/pages/Webapps.qml
    settings/center/pages/Wifi.qml
    settings/center/pages/WindowSwitcher.qml
    settings/center/pages/Windows.qml
    settings/center/qmldir
    settings/qmldir
)

LUA_REL=config/hypr/aequalyn/clipboard.lua

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Download to a temp tree first: nothing on the machine changes until every
# file has been fetched successfully.
info "downloading Clipscape, the Settings app and clipboard.lua from GitHub"
fail=0
get() { # <url> <dest>
    local url=$1 dest=$2
    mkdir -p "$(dirname "$dest")"
    if curl -fsSL --retry 3 --connect-timeout 15 "$url" -o "$dest.part"; then
        mv -f "$dest.part" "$dest"
    else
        rm -f "$dest.part"
        warn "could not download $url"
        fail=1
    fi
}

for rel in "${SHELL_FILES[@]}"; do
    get "$SHELL_RAW/$rel" "$TMP/shell/$rel"
done
get "$AQ_RAW/$LUA_REL" "$TMP/aequalyn/$LUA_REL"

if [[ $fail -ne 0 ]]; then
    echo "20261117-2: downloads failed; nothing was installed, will retry next update." >&2
    exit 3
fi
chmod 755 "$TMP/shell/plugins/clipscape/bin/clipscape"

# The user's settings.json predates Clipscape; AequalynSettings.qml doesn't add
# it automatically, so enable it here while leaving every other setting alone.
patch_settings() { # <file> <owner>
    local f=$1 owner=$2
    [[ -f "$f" ]] || return 0
    if python3 - "$f" <<'PY'
import json, shutil, sys

p = sys.argv[1]
with open(p, encoding="utf-8") as fh:
    d = json.load(fh)
changed = False

plugins = d.get("plugins")
if isinstance(plugins, list) and "clipscape" not in plugins:
    try:
        i = plugins.index("powerMenu")
    except ValueError:
        i = len(plugins)
    plugins.insert(i, "clipscape")
    changed = True

app = d.get("appearance")
if not isinstance(app, dict):
    app = {}
    d["appearance"] = app
    changed = True
if app.get("showClipscape") is not True:
    app["showClipscape"] = True
    changed = True
for key in ("barRight", "pluginOrder"):
    arr = app.get(key)
    if isinstance(arr, list) and "clipscape" not in arr:
        try:
            i = arr.index("settingsbutton")
        except ValueError:
            i = len(arr)
        arr.insert(i, "clipscape")
        changed = True

if changed:
    shutil.copy2(p, p + ".bak.20261117-2")
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(d, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
PY
    then
        chown "$owner" "$f" "$f.bak.20261117-2" 2>/dev/null || true
    else
        warn "could not update $f; original left in place"
        mv -f "$f.bak.20261117-2" "$f" 2>/dev/null || true
    fi
}

# An older hyprland.lua may not include the clipboard module yet.
patch_hyprland() { # <file> <owner>
    local f=$1 owner=$2
    [[ -f "$f" ]] || return 0
    grep -qF 'aequalyn/clipboard.lua' "$f" && return 0
    if python3 - "$f" <<'PY'
import sys

p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "aequalyn/clipboard.lua" in s:
    sys.exit(0)
line = 'include("aequalyn/clipboard.lua")\n'
anchor = 'include("aequalyn/look.lua")'
if anchor in s:
    s = s.replace(anchor, line + anchor, 1)
else:
    s = s.rstrip("\n") + "\n" + line
open(p, "w", encoding="utf-8").write(s)
PY
    then
        chown "$owner" "$f" 2>/dev/null || true
    else
        warn "could not update $f; original left in place"
    fi
}

# Refresh the system copies first so a later `aequalyn-update --no-pull`
# (which re-applies install.sh from these templates) keeps the new files.
if [[ -d "$AQ_ROOT/shell" ]]; then
    info "refreshing $AQ_ROOT/shell"
    cp -rf "$TMP/shell/." "$AQ_ROOT/shell/"
    chmod 755 "$AQ_ROOT/shell/plugins/clipscape/bin/clipscape" 2>/dev/null || true
fi
if [[ -d "$AQ_ROOT/config/hypr/aequalyn" ]]; then
    cp -f "$TMP/aequalyn/$LUA_REL" "$AQ_ROOT/$LUA_REL"
fi

homes=(/home/* /root)
if [[ -n ${AEQUALYN_MIGRATION_HOMES:-} ]]; then
    read -r -a homes <<< "$AEQUALYN_MIGRATION_HOMES"
fi

updated=0
for home in "${homes[@]}"; do
    [[ -d "$home" ]] || continue
    qs="$home/.config/quickshell"
    [[ -d "$qs" ]] || continue

    owner=$(stat -c '%u:%g' "$qs")
    info "installing the clipboard app and Settings app into $qs"
    cp -rf "$TMP/shell/." "$qs/"
    chown -R "$owner" "$qs/plugins/clipscape" "$qs/settings" 2>/dev/null || true
    chown "$owner" "$qs/Plugins.js" \
        "$qs/plugins/bar/widgets/Widgets.js" \
        "$qs/plugins/bar/widgets/ClipscapeButton.qml" 2>/dev/null || true
    chmod 755 "$qs/plugins/clipscape/bin/clipscape" 2>/dev/null || true

    if [[ -d "$home/.config/hypr" ]]; then
        hypr="$home/.config/hypr/aequalyn"
        mkdir -p "$hypr"
        cp -f "$TMP/aequalyn/$LUA_REL" "$hypr/clipboard.lua"
        chown "$owner" "$hypr/clipboard.lua" 2>/dev/null || true
        patch_hyprland "$home/.config/hypr/hyprland.lua" "$owner"
    fi
    patch_settings "$home/.config/aequalyn/settings.json" "$owner"
    updated=$((updated + 1))
done

if [[ $updated -eq 0 ]]; then
    warn "no user shell directory was updated"
else
    ok "clipboard app, Settings app and clipboard.lua installed for $updated user(s)"
fi
echo "   QuickShell reloads its config automatically. If the bar button is still"
echo "   missing, run: aequalyn-update --no-pull   (restarts the shell, no GitHub)."
