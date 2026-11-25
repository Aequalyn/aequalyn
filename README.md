# Aequalyn

Aequalyn is an Arch Linux ISO and desktop built around a [QuickShell](https://quickshell.org/)
shell for [Hyprland](https://hyprland.org/), with wallpaper-driven
[matugen](https://github.com/InioX/matugen) colours applied systemwide.

![The desktop](https://raw.githubusercontent.com/Aequalyn/aequalyn-shell/main/docs/screenshots/desktop.jpg)

- **Bar and docks** — a bar on any edge, its widgets in three regions (**left / center /
  right**) you reorder by dragging, with a quick panel under most of them. It is painted as
  a band, a pill, isles or a pebble per widget in 58 looks; up to 16 docks (4 per edge of
  each screen) wear the bar's look or one of 32 of their own, and 8 ensembles dress both at
  once. `settings.json` → `barStyle`, `~/.config/aequalyn/docks.json`.
- **Control center** (`Super + ,`) — every setting with a search over all of them, in five
  groups: **Look** (wallpaper, theme, theme picker, text, cursor, login screen), **Desktop**
  (bar, dock, media, clipboard, showcase), **Windows** (arranging, look, switcher),
  **Devices** (screens, sound, keyboard and mouse, shortcuts, Bluetooth, Wi-Fi) and
  **System** (lock and sleep, clock, plugins, updates, backup, about). Backed by
  `~/.config/aequalyn/settings.json`.
- **Store** (`Super + Alt + S`) — plugins, themes, cursors, wallpapers and looks, apps from
  Arch, the AUR, Flathub and Snap, web apps, AI tools and AppImages. What others made comes
  from the [Market](https://github.com/Aequalyn/aequalyn-market): reviewed, and installed and
  updated only to the exact commit that was. `Super + I` and `Super + R` are quick choosers to
  install and remove.
- **Plugins** — more than forty, each on or off at once: launchers, notifications, Aequalyn
  FM (the file manager and every app's open and save dialogs), Clipscape clipboard, Showcase
  desktop widgets, media, window switcher, cursor effects, calculator, emoji, notes, timer,
  weather, system monitor and more. Others' plugins may bring a bar widget of their own. A
  watchdog restarts what crashes or hangs and turns off what keeps failing.
- **Lock screen and login screen** — thirty lock screen designs, and SDDM
  [login themes](https://github.com/Aequalyn/aequalyn-lockscreens). Lock, display-off and suspend each have their own timeout (Lock and sleep);
  `Super + Shift + C` toggles Caffeine.
- **Themes and wallpapers** (`Super + T`, `Super + W`) — eight layouts per collection (slices,
  showcase, carousel, grid, filmstrip, radial, list, spotlight) with the whole shell previewing the theme
  under the cursor. Wallpapers can be static, cycle through the theme's backgrounds, run as a
  slideshow, follow the time of day, differ per workspace or play as video (`mpvpaper`), with
  awww transitions on every monitor. Colours follow the wallpaper or stay pinned to a theme,
  with a choice of matugen scheme, contrast and dark / light / auto.
- **Fonts** (`Super + Ctrl + .`) — one for the interface, one for code, or one for both,
  applied at once to the shell, GTK, Qt, kitty, fuzzel and every open foot window.
- **Quick looks** — the bar, the docks, the lock screen and the login screen change from a
  list: `Super + Ctrl + B / D / K / G`.
- **38 window layouts** — 33 of Aequalyn's own (Portrait, Landscape,
  Centerpiece, Stage, Theatre, four Galleries, four Diptychs, Triptych, Bento,
  Hero, Corner, Panels, Ultrawide, Mosaic, Spread, Ledger, Shelves, Masonry,
  Quadrant, Twin Columns, Strip, Column, Spiral, Fibonacci, Golden, Pinwheel,
  Cascade) plus Hyprland's Dwindle, Master, Scrolling and Monocle, and Floating. One per
  workspace, kept across reboots; `Super + L` steps through the ones you keep in the cycle,
  `Super + Alt + L` shows them all, `Super + G` snaps floating windows.
- **Universal clipboard** — `Super + C / V / X / A` copy, paste, cut and select all in every
  app (terminals get `Ctrl+Shift+C/V` automatically). `Super + Ctrl + V` opens the searchable
  history (text **and** images).
- **Screen capture** — screenshots (`Print`, `Super + Ctrl + S`) are saved to
  `~/Pictures/Screenshots` and copied; recording (`Super + Ctrl + R`) saves to
  `~/Videos`; `Super + Alt + X` copies text off the screen.
- **Bluetooth** — adapter power, scanning, connect / disconnect / forget, and the **audio
  profile** (A2DP or HSP/HFP) of a connected headset.
- **Snapshots** — `snapper` on Btrfs plus
  [`limine-mkinitcpio-hook`](https://aur.archlinux.org/packages/limine-mkinitcpio-hook) and
  [`limine-snapper-sync`](https://aur.archlinux.org/packages/limine-snapper-sync), so
  snapshots appear in the Limine boot menu. Both are pre-built into the ISO's offline
  repository.
- **Colours** — one wallpaper change repaints the shell, Hyprland borders, kitty, foot,
  fuzzel, GTK 3/4, qt6ct, btop and the lock screen.
- **Installer** — offline or online, dual boot, LUKS2, Btrfs subvolumes, Limine, eight
  package profiles, config-first `install.toml`, a hardware proposal.

The full change log is the git history of this and the sibling repos
(`aequalyn-shell`, `aequalyn-installer`, `aequalyn-iso`, `aequalyn-pkgs`,
`aequalyn-themes`, `aequalyn-lockscreens`, `aequalyn-market`).

## Repositories

Aequalyn is split across the [Aequalyn](https://github.com/Aequalyn) organisation:

| Repository | What it holds | Installed to |
| --- | --- | --- |
| [aequalyn](https://github.com/Aequalyn/aequalyn) | `aequalyn-*` commands, default config, `install.sh` | `~/.local/bin`, `~/.config` |
| [aequalyn-shell](https://github.com/Aequalyn/aequalyn-shell) | Quickshell desktop: bar, up to 16 docks, control center, Store, lock screen, plugins | `~/.config/quickshell` |
| [aequalyn-themes](https://github.com/Aequalyn/aequalyn-themes) | Folder themes (palette + backgrounds) | `~/.local/share/aequalyn/themes` |
| [aequalyn-lockscreens](https://github.com/Aequalyn/aequalyn-lockscreens) | Login screens for SDDM | `/usr/share/sddm/themes` |
| [aequalyn-market](https://github.com/Aequalyn/aequalyn-market) | The Store's catalog of what others made | read by `aequalyn-store` |
| [aequalyn-installer](https://github.com/Aequalyn/aequalyn-installer) | `aequalyn-install` wizard, `aequalyn-detect`, `install.toml` | live ISO `/opt/aequalyn/installer` |
| [aequalyn-iso](https://github.com/Aequalyn/aequalyn-iso) | archiso profile, `aequalyn-iso-make`, `aequalyn-iso-test` | — |
| [aequalyn-pkgs](https://github.com/Aequalyn/aequalyn-pkgs) | Package lists, install profiles, PKGBUILDs, cached AUR builds | — |

This repository:

```
aequalyn/
├── bin/              -> ~/.local/bin           (aequalyn, aequalyn-wallpaper, aequalyn-themes, ...)
├── config/           -> ~/.config              (hypr, matugen, kitty, ...)
├── assets/           default wallpaper
├── docs/             architecture notes
├── migrations/       changes an update makes to an existing system
├── scripts/          generators (layout pictures, ...)
├── systemd/ plymouth/  units and the boot splash
├── tests/            python3 tests/test_<name>.py
├── install.sh        install Aequalyn into a home directory / /etc/skel
└── VERSION
```

`install.sh` finds the shell and themes next to this checkout
(`../aequalyn-shell`, `../aequalyn-themes`) or clones them.

## Install onto an existing Arch + Hyprland system

```sh
./install.sh                 # installs into $HOME
qs -n -d                     # start the shell
aequalyn-theme ~/Pictures/Wallpapers/beach.jpg
```

Dependencies: `quickshell`, `matugen`, `awww`, `hyprland`, `jq`, `brightnessctl`,
`playerctl`, `ttf-jetbrains-mono-nerd`, plus the Qt6/GTK runtime. See
`aequalyn-pkgs` (`lists/desktop.packages`); in the assembled ISO tree this is
`packages/desktop.packages`.

## Updating and migrations

```sh
aequalyn-update                 # get the newest Aequalyn and shell, re-apply, run pending migrations
```

Changes that have to touch an existing system (removing old files, stopping a
service, fixing config) live in `migrations/`, named by date and number, for
example `migrations/20261116-2.sh`. `aequalyn-update` downloads the newest
Aequalyn, then runs every migration not yet recorded in
`/var/lib/aequalyn/migrations.done`, in name order, as root. Each one runs once.

A migration exits `0` when done, or `3` to be tried again on the next update
(for example while a package it needs is still missing). Any other exit code
stops the update, and the migration runs again next time.

To run one by hand:

```sh
curl -fsSL https://raw.githubusercontent.com/Aequalyn/aequalyn/main/migrations/20261116-2.sh | sudo bash
```

Migrations must be safe to run twice: check first, then change.

## Build the ISO

See [aequalyn-iso](https://github.com/Aequalyn/aequalyn-iso):

```sh
sudo ./bin/aequalyn-iso-make        # uses sibling checkouts of the other repos
```

The ISO boots into the live Aequalyn desktop (user `live`). Run `sudo aequalyn-install`
(or `Super + I`) to install, `sudo aequalyn-repair` to chroot into an existing
system, or `aequalyn-install --detect` to see the hardware proposal.

Boot it in a VM (requires `qemu-full` + `edk2-ovmf`):

```sh
./bin/aequalyn-iso-test                 # newest aequalyn-*.iso, UEFI + KVM + virtio-gpu
RAM=8192 CPUS=6 ./bin/aequalyn-iso-test
```

## Installer contract

`installer/install.toml.example` documents every option. The agent (L1) proposes
a config, the user sees it as a list of differences and approves or edits it,
and `aequalyn-install --config install.toml` applies it identically every time.
Everything works without AI.

## AI and development tools

The Store's **AI tools** page can install, update and remove Claude Code, Codex CLI,
GitHub Copilot CLI, Antigravity CLI, OpenCode, Qwen Code, Kilo Code CLI, Cline CLI, Crush
and Amp CLI for the current user. They come from their publishers (npm, or the vendor's own
installer) and live under `~/.local/share/aequalyn/ai-tools`; their commands are linked into
`~/.local/bin`. The npm ones need Node.js and npm. Sign-in and configuration stay with each
provider. **Super + Alt + A** chooses the default browser, terminal, file manager, text and
video apps, and the AI coding tool.

The same manager is available in a terminal as `aequalyn-ai-tool list`,
`aequalyn-ai-tool install codex`, `aequalyn-ai-tool update codex`,
`aequalyn-ai-tool remove codex`, and `aequalyn-ai-tool set-default opencode`.
Removing a tool leaves its settings and
sign-in data in place. The optional Developer profile includes programming
languages, mise, npm and uv; the Store can add packages to an existing system.

## Keybinds

| Key | Action |
| --- | --- |
| `Super + Return` | Terminal |
| `Super + D` | App launcher |
| `Super + Space` | Programs menu: browse applications and CLI tools by category |
| `Super + ,` / gear in bar | Control center |
| `Super + Alt + S` | Store |
| `Super + I` / `Super + R` | Install / remove chooser (the installer on the live ISO) |
| `Super + E` / `Super + Alt + F` | File manager / Aequalyn FM |
| `Super + B` | Browser |
| `Super + Ctrl + B` / `D` / `K` / `G` | Quick looks: bar / docks / lock screen / login screen |
| `Super + Ctrl + .` | Fonts |
| `Super + /` | Key hints |
| `Super + Shift + Space` | Command palette |
| `Super + G` | Snap layouts |
| `Super + Ctrl + Shift + L` | Lock |
| `apps-menu` Arch logo in bar | App launcher |
| `Super + T` / `Super + Ctrl + Shift + Space` | Themes and wallpapers: themes |
| `Super + W` | Themes and wallpapers: wallpapers |
| `Super + Shift + W` | Wallpaper: change it over time |
| `Super + Ctrl + Space` | Next wallpaper |
| `Super + L` / `Super + Shift + L` | Next / previous window layout |
| `Super + Alt + L` | Arranging windows: every layout |
| `Super + Ctrl + L`, then `1`–`9` | Dwindle, Scrolling, Master, Portrait, Landscape, Centerpiece, Diptych Left, Diptych Right, Mosaic |
| `Super + Ctrl + L`, `0`, then `1`–`0`, `-`, `=` | Strip, Column, Spiral, Gallery Right, Gallery Bottom, Gallery Left, Gallery Top, Spread, Diptych Top, Diptych Bottom, Triptych, Bento |
| `Super + Z` | Make the focused window the main one |
| `Super + ←/→/↑/↓` | Focus the nearest window that way |
| `Super + Shift + ←/→/↑/↓` | Swap with the nearest window that way |
| `Alt + Tab` / `Alt + Shift + Tab` | Step through the windows; let go of Alt to make that one the main window |
| `Super + Ctrl + ←/→` | Swap the focused window with the previous / next in the layout |
| `Super + -` / `=` | Main pane larger / smaller, held to keep going (`Alt`: finer, `Ctrl`: coarser) |
| `Super + O` | Display manager |
| `Super + C` / `V` / `X` / `A` | Universal copy / paste / cut / select-all |
| `Super + Ctrl + V` | Clipscape clipboard history (search, pins, previews) |
| `Super + Shift + C` | Caffeine (idle inhibit) |
| `Super + Shift + V` | Toggle floating |
| `Super + Ctrl + R` / `Super + Shift + R` | Start or stop recording |
| `Print` / `Super + Ctrl + S`, `Super + Ctrl + Shift + S` | Screenshot: a part, the whole screen |
| `Super + Alt + X` | Copy text off the screen |
| `Super + Shift + P` | Pick a colour on the screen |
| `Super + Alt + C` / `Super + .` / `Super + Alt + N` / `Super + Alt + T` | Calculator / emoji / notes / timer |
| `Super + Shift + Escape` | System monitor |
| `Super + N` / `Super + Shift + N` | Dismiss notifications / do not disturb |
| `Super + M` | Minimize the window, or bring the minimized ones back |
| `Super + Shift + M` | Power menu |
| `Super + Q` | Close window |

> They are in `config/hypr/keybinds.lua` and `config/hypr/aequalyn/keys.lua`; Keyboard shortcuts in the control center changes them. Many actions are also available via `qs ipc call ...`.

## Wallpapers and themes from the command line

```sh
aequalyn-wallpaper next                     # Super + Ctrl + Space
aequalyn-wallpaper mode slideshow           # static | theme | slideshow | daytime | workspace | live
aequalyn-settings set .wallpaper.interval 15
aequalyn-wallpaper generate aurora          # paint one from the current palette
aequalyn-themes list
aequalyn-themes set tidal
aequalyn-settings set-str .palette.scheme scheme-expressive
```

```sh
aequalyn-layout list                        # all 38, including Floating
aequalyn-layout set portrait                # focused workspace
aequalyn-layout set floating --workspace 2  # windows you place yourself
aequalyn-layout set mosaic --workspace 3
aequalyn-layout cycle portrait mosaic spiral dwindle   # what Super + L goes through
aequalyn-layout option pane 0.66
```

![Every layout with five windows](docs/layouts/all-layouts.jpg)

Everything the picker does goes through these commands, so a keybind, a script
or an agent gets the same result as the picker.

## Credits

[nightdevil00](https://github.com/nightdevil00) contributed to the code here.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
See [LICENSE](LICENSE) for the full text.

## Documentation

- `Security.md` — security model and concerns.
- `SKILL.md` — development/install skill reference.
- `PLUGINS.md` — plugins (core side).
- `THEMES.md` — themes (core side).
- `docs/architecture.md`, `docs/lock.md`, `docs/floating.md`, `docs/quickshell-base.md` — how it works inside.
