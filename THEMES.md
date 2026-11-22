# Aequalyn — themes (core side)

The core repo ships theme application commands and config; the theme *format* and the
shell's theme provider live elsewhere. See `aequalyn-themes` and
`aequalyn-shell/THEMES.md`.

## Commands

- `aequalyn-theme <image>` — apply a wallpaper and regenerate the palette systemwide
  (shell, Hyprland, GTK, Qt, terminals, btop, hyprlock).
- `aequalyn-themes list|set|install|remove` — manage folder themes.
- `aequalyn-apply-palette` — apply a palette to terminals/lock screen/etc.
- `aequalyn-wallpaper ...` — wallpaper modes (static, theme, slideshow, daytime,
  workspace, live).

## Config

- `~/.config/aequalyn/settings.json` — appearance/palette settings.
- `~/.config/quickshell/theme.conf` — `theme:<id>` or `wallpaper`.
- `~/.config/aequalyn/current/theme` — symlink to active theme folder.
- `~/.config/hypr/aequalyn/colors.lua` — window-border colours.

## Security

- Arbitrary Git theme install supply chain (`aequalyn-themes install <url>`).
- Path traversal in `aequalyn-themes remove <id>` (validate ids).
- QML palette strings interpolated into shell commands (sanitize to hex).
- See `Security.md` and `aequalyn-shell/SECURITY.md`.
