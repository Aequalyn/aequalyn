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
# Safe to re-run: user-owned files are never deleted, only overwritten with
# the shipped defaults. Use --force to also refresh generated colour files.
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
    if [[ -d "$src" ]]; then
        mkdir -p "$dst"
        for f in "$src"/* "$src"/.[!.]*; do
            [[ -e "$f" ]] || continue
            base=$(basename "$f")
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
info "config -> $TARGET/.config"

# 2b. Updates leave the user's hyprland.lua alone (above), but Aequalyn's own layout
#     modules are part of Aequalyn, not something people tune by hand (that's user.lua):
#     keep them current, and reload Hyprland so the running session uses them.
if [[ "$SKIP_HYPR" -eq 1 && -d "$TARGET/.config/hypr/aequalyn" ]]; then
    for f in geometry.lua layouts.lua keys.lua tiles.lua; do
        [[ -f "$ROOT/config/hypr/aequalyn/$f" ]] && cp "$ROOT/config/hypr/aequalyn/$f" "$TARGET/.config/hypr/aequalyn/$f"
    done
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
    info "layouts -> $TARGET/.config/hypr/aequalyn"
fi

# 3. CLI helpers
mkdir -p "$TARGET/.local/bin"
cp "$ROOT/bin/"* "$TARGET/.local/bin/"
chmod 755 "$TARGET/.local/bin/"*
info "bin -> $TARGET/.local/bin"

# 4. Wallpaper + first-run state
mkdir -p "$TARGET/Pictures/Wallpapers"
cp "$ROOT/assets/beach.jpg" "$TARGET/Pictures/Wallpapers/"
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
Exec=kitty -e sudo aequalyn-install
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

# 8. Ownership (installing into a target home from the live ISO)
if [[ -n "$OWNER" ]]; then
    chown -R "$OWNER" "$TARGET/.config" "$TARGET/.local" "$TARGET/Pictures" 2>/dev/null || true
    info "chowned to $OWNER"
elif [[ $SKEL -eq 0 && $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
    u=$(id -u "$SUDO_USER" 2>/dev/null || true); g=$(id -g "$SUDO_USER" 2>/dev/null || true)
    [[ -n "$u" && -n "$g" ]] && chown -R "$u:$g" "$TARGET/.config" "$TARGET/.local" "$TARGET/Pictures" 2>/dev/null || true
fi

info "done. Start with: qs -n -d   (or log into the Aequalyn Hyprland session)"
