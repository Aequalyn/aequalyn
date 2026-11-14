#!/usr/bin/env bash
# install.sh -- install the Aequalyn desktop into a home directory.
#
# Used three ways:
#   ./install.sh                         install into the current $HOME
#   ./install.sh --target /home/alice    install into another user's home
#   ./install.sh --target /etc/skel --skel   populate the ISO skeleton
#                                            (paths stay HOME-relative)
#   --skip-hypr / --with-hypr                force skip / install Hyprland config
#
# The desktop is spread over several repositories of the Aequalyn
# organisation. The shell and the themes are looked up, in order, at
# $AEQUALYN_SHELL_DIR / $AEQUALYN_THEMES_DIR, inside this tree (an assembled
# ISO tree has shell/ and themes/), next to it (../aequalyn-shell,
# ../aequalyn-themes), and finally cloned from GitHub into the cache.
#
# Safe to re-run: what the user changed is kept (settings, layouts, default apps,
# terminal and GTK preferences, colours, wallpaper and theme), and a copy of it is
# saved first. --force also refreshes the generated colour files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}"
SKEL=0
FORCE=0
OWNER=""
SKIP_HYPR=0
WITH_HYPR=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET=$2; shift 2 ;;
        --skel)   SKEL=1; shift ;;
        --force)  FORCE=1; shift ;;
        --owner)  OWNER=$2; shift 2 ;;
        --skip-hypr) SKIP_HYPR=1; shift ;;
        --with-hypr) WITH_HYPR=1; shift ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

# By default, never clobber an existing user's Hyprland config on re-runs:
# treat a present hyprland.lua as "this is an update, keep the user's setup".
# Fresh installs (--skel, or targets without hyprland.lua) still get the
# shipped defaults. --with-hypr forces installing them; --skip-hypr forces skipping.
if [[ $WITH_HYPR -eq 1 ]]; then
    SKIP_HYPR=0
elif [[ $SKEL -eq 1 ]]; then
    SKIP_HYPR=0
elif [[ -f "$TARGET/.config/hypr/hyprland.lua" ]]; then
    SKIP_HYPR=1
fi

info() { printf '\033[0;34m[aequalyn-install]\033[0m %s\n' "$*"; }

AEQUALYN_GIT=${AEQUALYN_GIT:-https://github.com/Aequalyn}

# resolve_repo <repo-name> <subdir-in-assembled-tree> <override>
resolve_repo() {
    local name=$1 sub=$2 override=$3 cand cache
    for cand in "$override" "$ROOT/$sub" "$ROOT/../$name"; do
        [[ -n "$cand" && -d "$cand" ]] && { (cd "$cand" && pwd); return 0; }
    done
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/aequalyn/src/$name"
    if [[ -d "$cache/.git" ]]; then
        git -C "$cache" pull --ff-only -q >/dev/null 2>&1 || true
    else
        mkdir -p "$(dirname "$cache")"
        git clone -q --depth 1 "$AEQUALYN_GIT/$name.git" "$cache" >&2 || return 1
    fi
    printf '%s' "$cache"
}

[[ -d "$ROOT/config" ]] || { echo "Aequalyn core tree not found at $ROOT" >&2; exit 1; }
SHELL_SRC=$(resolve_repo aequalyn-shell shell "${AEQUALYN_SHELL_DIR:-}") \
    || { echo "aequalyn-shell not found (set AEQUALYN_SHELL_DIR)" >&2; exit 1; }
THEMES_SRC=$(resolve_repo aequalyn-themes themes "${AEQUALYN_THEMES_DIR:-}" || true)
mkdir -p "$TARGET"

# 0. Before an update changes anything, a copy of what the user set: their settings,
#    layouts, docks, default apps, Hyprland, terminal and GTK configs, wallpaper and
#    theme choice. In ~/.local/state/aequalyn/backups, the last 5 kept; bring one back
#    with:  tar -xzf <file> -C ~
if [[ $SKEL -eq 0 && -f "$TARGET/.config/aequalyn/settings.json" ]]; then
    _bk="$TARGET/.local/state/aequalyn/backups"
    mkdir -p "$_bk"
    _items=()
    for p in .config/aequalyn .config/mimeapps.list .config/hypr .config/kitty .config/foot \
             .config/fuzzel .config/qt6ct .config/gtk-3.0 .config/gtk-4.0 \
             .config/quickshell/wallpaper.conf .config/quickshell/theme.conf \
             .config/quickshell/theme-switcher/wallpaper-theme.json; do
        [[ -e "$TARGET/$p" ]] && _items+=("$p")
    done
    if tar -C "$TARGET" -czf "$_bk/before-update-$(date +%Y%m%d-%H%M%S).tar.gz" "${_items[@]}" 2>/dev/null; then
        info "your settings, as they were -> $_bk"
    fi
    ls -1t "$_bk"/before-update-*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
fi

# Files people change after the first install: settings the shell saves, terminal /
# launcher / Qt / GTK preferences (mimeapps.list, the default apps, has its own rule below). An update leaves each alone once it differs
# from what Aequalyn shipped last time (it was changed, by hand or by a setting), and
# still brings new defaults to one nobody touched. What was shipped is remembered in
# ~/.local/state/aequalyn/shipped. --force never applies to these.
USER_FILES=" aequalyn/settings.json aequalyn/layouts.json kitty/kitty.conf foot/foot.ini fuzzel/fuzzel.ini qt6ct/qt6ct.conf gtk-3.0/settings.ini "
SHIPPED="$TARGET/.local/state/aequalyn/shipped"
user_file() { # <shipped file> <path under .config>
    local src=$1 rel=$2 dst="$TARGET/.config/$2" stamp="$SHIPPED/$2"
    if [[ ! -e "$dst" ]] || { [[ -f "$stamp" ]] && cmp -s "$dst" "$stamp"; }; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    fi
    mkdir -p "$(dirname "$stamp")"
    cp "$src" "$stamp"
}

# 1. QuickShell config (real copy, not a symlink: /etc/skel must be portable)
# Preserve the user's current wallpaper/theme selection across updates.
_saved_wp=""
_saved_th=""
if [[ -f "$TARGET/.config/quickshell/wallpaper.conf" ]]; then
    _saved_wp=$(cat "$TARGET/.config/quickshell/wallpaper.conf" 2>/dev/null || true)
fi
if [[ -f "$TARGET/.config/quickshell/theme.conf" ]]; then
    _saved_th=$(cat "$TARGET/.config/quickshell/theme.conf" 2>/dev/null || true)
fi
# Built next to the old one and swapped in only once it's complete, so a failed copy
# leaves the working shell as it was. The shell is a git clone owned by root: its .git
# isn't copied (parts of it are unreadable to the user, and it isn't needed here).
# What the user made carries over: the wallpaper and theme choice and the colours
# generated from the wallpaper (the clone ships a default wallpaper-theme.json).
_qs="$TARGET/.config/quickshell"
_qs_new="$TARGET/.config/.quickshell.new.$$"
rm -rf "$_qs_new"
mkdir -p "$_qs_new"
tar -C "$SHELL_SRC" --exclude=./.git -cf - . | tar -C "$_qs_new" -xf -
for _keep in wallpaper.conf theme.conf theme-switcher/wallpaper-theme.json; do
    if [[ -f "$_qs/$_keep" ]]; then
        mkdir -p "$(dirname "$_qs_new/$_keep")"
        cp -f "$_qs/$_keep" "$_qs_new/$_keep"
    fi
done
rm -rf "$_qs"
mv "$_qs_new" "$_qs"
# Clipboard capture helper is invoked by wl-paste; keep it executable here and
# in the skel copy (archiso strips modes, so customize_airootfs.sh repeats it).
chmod 755 "$TARGET/.config/quickshell/clipboard/capture.sh" 2>/dev/null || true
info "shell -> $TARGET/.config/quickshell"

# 2. Desktop config tree. Generated colour files are only installed on a
#    fresh home or with --force, so a user's current palette survives updates.
for dir in hypr kitty foot fuzzel qt6ct gtk-3.0 gtk-4.0 btop matugen aequalyn quickshell mimeapps.list; do
    # Never touch the user's hand-tuned hyprland config on updates.
    [[ "$SKIP_HYPR" -eq 1 && "$dir" == "hypr" ]] && continue
    src="$ROOT/config/$dir"
    [[ -e "$src" ]] || continue
    dst="$TARGET/.config/$dir"
    # config/quickshell only holds first-run seeds (theme.conf, the default
    # theme-switcher/wallpaper-theme.json) next to the shell copied above: never
    # overwrite what's there, at any depth, or every update resets the user's colours
    if [[ "$dir" == quickshell && $FORCE -eq 0 ]]; then
        mkdir -p "$dst"
        cp -rn "$src/." "$dst/"
        continue
    fi
    # mimeapps.list is user state: default apps are chosen in Settings. Only
    # install the shipped list on a fresh home (or --force); otherwise just
    # repair the legacy Nautilus id, so updates never reset the user's choices
    # (and never make kitty-open, which also claims inode/directory, win again).
    if [[ "$dir" == mimeapps.list ]]; then
        if [[ $FORCE -eq 1 || ! -e "$dst" ]]; then
            cp "$src" "$dst"
        else
            sed -i 's|^inode/directory=nautilus\.desktop$|inode/directory=org.gnome.Nautilus.desktop|' "$dst"
        fi
        continue
    fi
    if [[ -d "$src" ]]; then
        mkdir -p "$dst"
        for f in "$src"/* "$src"/.[!.]*; do
            [[ -e "$f" ]] || continue
            base=$(basename "$f")
            if [[ "$USER_FILES" == *" $dir/$base "* ]]; then user_file "$f" "$dir/$base"; continue; fi
            case "$base" in
                aequalyn-colors.conf|aequalyn-colors.ini|aequalyn.conf|aequalyn.theme|gtk.css|colors.lua|look.lua|workspace-layouts.lua|wallpaper-theme.json|hyprlock.conf)
                    if [[ $FORCE -eq 1 || ! -e "$dst/$base" ]]; then cp -r "$f" "$dst/$base"; fi
                    ;;
                *) cp -r "$f" "$dst/" ;;
            esac
        done
    else
        cp "$src" "$dst"
    fi
done
info "config -> $TARGET/.config (what you changed stays as it is)"

# 2b. Updates leave the user's hyprland.lua alone (above), but Aequalyn's own layout
#     modules are part of Aequalyn, not something people tune by hand (that's user.lua):
#     keep them current, and reload Hyprland so the running session uses them.
if [[ "$SKIP_HYPR" -eq 1 && -d "$TARGET/.config/hypr/aequalyn" ]]; then
    for f in geometry.lua layouts.lua keys.lua tiles.lua; do
        [[ -f "$ROOT/config/hypr/aequalyn/$f" ]] && cp "$ROOT/config/hypr/aequalyn/$f" "$TARGET/.config/hypr/aequalyn/$f"
    done
    # Backfill the generated webapps.lua include for installs that predate Web apps.
    if [[ -f "$TARGET/.config/hypr/hyprland.lua" ]] && ! grep -q 'include_optional("webapps.lua")' "$TARGET/.config/hypr/hyprland.lua"; then
        python3 - "$TARGET/.config/hypr/hyprland.lua" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
helper = ("local function include_optional(rel)\n"
          "    local path = HOME .. \"/.config/hypr/\" .. rel\n"
          "    if not io.open(path, \"r\") then return end\n"
          "    local ok, err = pcall(dofile, path)\n"
          "    if not ok then\n"
          "        print(\"[aequalyn] could not load \" .. path .. \": \" .. tostring(err))\n"
          "    end\n"
          "end\n")
if "local function include_optional" not in s:
    needle = "local function include(rel)"
    idx = s.find(needle)
    end_idx = s.find("\nend\n", idx) if idx >= 0 else -1
    if end_idx >= 0:
        at = end_idx + len("\nend\n")
        s = s[:at] + "\n" + helper + s[at:]
if 'include("aequalyn/colors.lua")' in s:
    s = s.replace('include("aequalyn/colors.lua")\n',
                  'include("aequalyn/colors.lua")\ninclude_optional("webapps.lua")             -- generated by aequalyn-webapp\n', 1)
elif 'include("aequalyn/user.lua")' in s:
    s = s.replace('include("aequalyn/user.lua")',
                  'include_optional("webapps.lua")             -- generated by aequalyn-webapp\ninclude("aequalyn/user.lua")', 1)
open(p, "w").write(s)
PY
    fi
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
    info "layouts -> $TARGET/.config/hypr/aequalyn"
fi

# 3. CLI helpers (only regular files: skip __pycache__ and other stray dirs)
mkdir -p "$TARGET/.local/bin"
for _f in "$ROOT/bin/"*; do
    [[ -f "$_f" ]] || continue
    cp "$_f" "$TARGET/.local/bin/"
done
chmod 755 "$TARGET/.local/bin/"* 2>/dev/null || true
info "bin -> $TARGET/.local/bin"

# 4. Wallpaper + first-run state
# the sample wallpaper only on a first install: one you deleted stays deleted
mkdir -p "$TARGET/Pictures/Wallpapers"
if [[ $SKEL -eq 1 || -z "$_saved_wp" ]]; then
    cp -n "$ROOT/assets/beach.jpg" "$TARGET/Pictures/Wallpapers/" 2>/dev/null || true
fi
if [[ $SKEL -eq 0 ]]; then
    if [[ -n "$_saved_wp" ]]; then
        printf '%s' "$_saved_wp" > "$TARGET/.config/quickshell/wallpaper.conf"
    else
        printf '%s' "$TARGET/Pictures/Wallpapers/beach.jpg" > "$TARGET/.config/quickshell/wallpaper.conf"
    fi
else
    # /etc/skel has no absolute path yet; aequalyn-session-start falls back to
    # $HOME/Pictures/Wallpapers/beach.jpg.
    rm -f "$TARGET/.config/quickshell/wallpaper.conf"
fi
if [[ -n "$_saved_th" ]]; then
    printf '%s' "$_saved_th" > "$TARGET/.config/quickshell/theme.conf"
else
    printf 'wallpaper' > "$TARGET/.config/quickshell/theme.conf"
fi

# 4b. Themes (folder themes with palettes + backgrounds). Packaged installs
#     ship them in /usr/share/aequalyn/themes; a home install keeps a copy in
#     ~/.local/share/aequalyn/themes. User themes live in
#     ~/.config/aequalyn/themes and are never touched.
if [[ -n "${THEMES_SRC:-}" && -d "$THEMES_SRC/themes" ]]; then
    mkdir -p "$TARGET/.local/share/aequalyn/themes" "$TARGET/.config/aequalyn/themes"
    cp -r "$THEMES_SRC/themes/." "$TARGET/.local/share/aequalyn/themes/"
    info "themes -> $TARGET/.local/share/aequalyn/themes"
fi

# 5. A default settings.json if none exists
if [[ ! -f "$TARGET/.config/aequalyn/settings.json" ]]; then
    mkdir -p "$TARGET/.config/aequalyn"
    cp "$ROOT/config/aequalyn/settings.json" "$TARGET/.config/aequalyn/settings.json"
fi

# 6. Desktop entry for the installer (live session convenience).
# Only created on the live ISO (/etc/skel) and not on a real target home,
# so it doesn't linger after install. Skip on --skel (the ISO image carries
# its own copy in /usr/share/applications).
if [[ $SKEL -eq 1 ]]; then
    # issue 1: the live ISO keeps the "Install Aequalyn" launcher in
    # /etc/skel so the live session can start the installer from the menu.
    mkdir -p "$TARGET/.local/share/applications"
    cat > "$TARGET/.local/share/applications/aequalyn-install.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Install Aequalyn
Comment=Install Aequalyn to this machine
Exec=sudo aequalyn-install
Icon=system-software-install
Terminal=false
Categories=System;
EOF
else
    # issue 1: a real install targets a user's home, not /etc/skel, so the
    # installer's desktop entry must never be created there -- and a stale
    # one left by an older/live install is removed so it doesn't linger
    # in ~/.local/share/applications after install.
    rm -f "$TARGET/.local/share/applications/aequalyn-install.desktop"
fi

# 7. Nautilus palette extension (live-reloaded by Aequalyn theme tools)
if [[ -f "$ROOT/config/nautilus-python/extensions/aequalyn_palette.py" ]]; then
    mkdir -p "$TARGET/.local/share/nautilus-python/extensions"
    cp "$ROOT/config/nautilus-python/extensions/aequalyn_palette.py" "$TARGET/.local/share/nautilus-python/extensions/"
    info "nautilus extension -> $TARGET/.local/share/nautilus-python/extensions"
fi

# 7b. Web app seed icons (used by aequalyn-webapp when it creates launchers).
if [[ -d "$ROOT/assets/webapps" ]]; then
    mkdir -p "$TARGET/.local/share/aequalyn/assets/webapps"
    cp -f "$ROOT/assets/webapps/"* "$TARGET/.local/share/aequalyn/assets/webapps/" 2>/dev/null || true
    info "webapp icons -> $TARGET/.local/share/aequalyn/assets/webapps"
fi

# 7c. Seed web apps (Reddit, ChatGPT, YouTube Music) unless the installer
#     asked us not to. The browser chosen at install time becomes the default.
SEED_WEBAPPS="${AEQUALYN_SEED_WEBAPPS:-1}"
WEBAPP_BROWSER="${AEQUALYN_WEBAPP_BROWSER:-auto}"
case "$SEED_WEBAPPS" in
    0|false|False|no|NO) SEED_WEBAPPS=0 ;;
    *) SEED_WEBAPPS=1 ;;
esac
if [[ "$SEED_WEBAPPS" -eq 1 && -x "$TARGET/.local/bin/aequalyn-webapp" ]]; then
    info "seeding web apps (browser: $WEBAPP_BROWSER) ..."
    HOME="$TARGET" AEQUALYN_ASSETS="$TARGET/.local/share/aequalyn/assets" \
        "$TARGET/.local/bin/aequalyn-webapp" seed --browser "$WEBAPP_BROWSER" >/dev/null 2>&1 || true
fi

# 8. Ownership (installing into a target home from the live ISO)
if [[ -n "$OWNER" ]]; then
    chown -R "$OWNER" "$TARGET/.config" "$TARGET/.local" "$TARGET/Pictures" 2>/dev/null || true
    info "chowned to $OWNER"
elif [[ $SKEL -eq 0 && $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
    u=$(id -u "$SUDO_USER" 2>/dev/null || true); g=$(id -g "$SUDO_USER" 2>/dev/null || true)
    [[ -n "$u" && -n "$g" ]] && chown -R "$u:$g" "$TARGET/.config" "$TARGET/.local" "$TARGET/Pictures" 2>/dev/null || true
fi

info "done. Start with: qs -n -d   (or log into the Aequalyn Hyprland session)"
