# Aequalyn architecture

## The desktop

```
wallpaper change (awww)
   │
   ├─> ~/.config/quickshell/wallpaper.conf           (current image)
   │
   └─> qs ipc call theme wallpaper <img>
          │
          └─> set.sh -> aequalyn-theme --colors-only <img>
                   │
                   ├─> matugen (config.toml) ─────────────┐
                   │      ├─ quickshell palette JSON ──────┼─> Theme.qml (FileView)
                   │      ├─ hypr/aequalyn/colors.lua ─────────┼─> hyprctl reload
                   │      ├─ kitty / foot / fuzzel / btop ─┤
                   │      ├─ qt6ct / hyprlock ─────────────┤
                   │      └─ ~/.cache/aequalyn/colors.json ────┘
                   │
                   └─> optional matugen (apps.toml) -> GTK 3/4 CSS
                          (gated by settings.json appearance.themeApps)
```

`Theme.qml` is the shared palette object. Every module gets it as
`theme: ts.theme`, so one recolour repaints the bar, launcher, notifications,
OSD, wallpaper picker, display manager and settings page at once. The Settings
page also writes `aequalyn/colors.lua` when a *curated* theme is chosen, so the
compositor border colours always agree with the shell.

## Atelier: themes, wallpapers, rotation, palette

```
Atelier (shell/atelier)                 aequalyn-wallpaper (bin)
  Themes ──> Theme.qml ──────────────┐    set / next / prev / random / tick
  Wallpapers ─┐                      │    modes: static theme slideshow
  Rotation ───┼─> AtelierService ────┼──>        daytime workspace live
  Palette ────┘     (queue, tick,    │    awww per output (transitions)
                     workspaces)     │    mpvpaper for video
                                     │      │
                                     │      └─> aequalyn-theme --colors-only
                                     │          only when theme.conf = wallpaper
                                     │          and .palette.locked is false
                                     └──> aequalyn-themes set <id> --from-shell
                                          (current/theme symlink + background)
```

`theme.conf` decides where colours come from: `wallpaper` (matugen), a curated
palette index, or `theme:<id>` for a folder theme with its own palette. A
folder theme without a palette is a wallpaper pack: it sets backgrounds and
keeps wallpaper colours. The shell runs `aequalyn-wallpaper tick` every minute
while a timed mode (slideshow, time of day, auto light/dark) is active, and
`aequalyn-wallpaper workspace <id>` on workspace changes in per-workspace mode.

## Window layouts

`config/hypr/aequalyn/geometry.lua` holds every layout as a pure function
`(n, area, opts) -> rectangles`, slot 1 being the main window. It has no
Hyprland calls, so the same file is used three ways:

```
geometry.lua ──> layouts.lua (Hyprland)   hl.layout.register("aq-<id>"), window
             │                            order per workspace, promote / swap / grow
             ├─> scripts/layouts-json.py  config/aequalyn/layouts.json: names,
             │                            groups, a picture of each (Atelier, CLI)
             └─> tests/test_layouts.py    1..12 windows: count, bounds, overlap
```

`aequalyn-layout` stores choices in settings.json (`.layouts`) and writes
`hypr/aequalyn/workspace-layouts.lua` (`hl.workspace_rule` per workspace plus
pane / gap), which hyprland.lua loads after layouts.lua; a change reloads
Hyprland so the rule takes effect.

## Configuration contract

`~/.config/aequalyn/settings.json` is the single source of truth for the desktop:

| Consumer | Reads | Writes |
| --- | --- | --- |
| `Settings.qml` | all keys | via `AequalynSettings.save()` |
| `aequalyn-hypr-apply` | `hyprland.*` | `hypr/aequalyn/look.lua` |
| `aequalyn-theme` | `appearance.themeMode`, `themeApps` | matugen outputs |
| `aequalyn-idle` | `power.*` | `~/.config/aequalyn/hypridle.conf` |
| Bar / Time / settings UI | `appearance.*` | — |
| `install.toml [aequalyn]` | — | `settings.json` at install time |

Anything edited by hand (or by an agent) in `settings.json` is live-reloaded by
a `FileView` and immediately re-applied. `install.toml` is the equivalent
contract for the install: propose → show diff → approve → apply.

## Hyprland 0.57+ (Lua)

Hyprland no longer parses `.conf`; it executes `hyprland.lua` with the `hl.*`
API. The main file `dofile`s three generated modules (fresh on every reload):

```
hyprland.lua
  dofile monitors.lua        # display manager persistence
  dofile aequalyn/look.lua       # from settings.json
  dofile aequalyn/colors.lua     # from matugen / theme switcher
  dofile aequalyn/user.lua       # hand overrides, last
```

`hyprctl keyword` is gone; `hyprctl eval` and `hyprctl reload` are used instead.

## Install flow

```
aequalyn-install (gum/dialog/plain TUI)
  ├─ aequalyn-detect (L1) -> hardware + proposed profiles
  ├─ six-step wizard -> install.toml
  ├─ show diff, optionally edit, approve
  └─ apply.sh
       ├─ validate UEFI + disk, resolve offline/online repo
       ├─ package list = base + desktop + hardware + profiles + extras
       ├─ optional btrfs snapshot
       ├─ partition (fullwipe | dualboot | manual), LUKS2, btrfs subvols
       ├─ pacstrap -> genfstab -> crypttab
       ├─ chroot: locale/time/user/mkinitcpio/Limine/services/snapper
       ├─ install.sh -> target home, settings.json from [aequalyn]
       └─ first-boot service (optional AUR set + palette regeneration)
```

Btrfs subvolume names match `System_Repair/system_repair.sh`:
`@ @home @log @pkg @.snapshots @var @root`.

## ISO

`archiso` releng is the base. Adding a UID-1000 `live` user to
`airootfs/etc/passwd` makes `mkarchiso` copy `airootfs/etc/skel` into
`/home/live` automatically — that is how the shell, wallpaper and all configs
reach the live desktop. SDDM (enabled as `display-manager.service`) autologs
`live` into the `aequalyn` Wayland session, which runs the guarded
`aequalyn-live-session` wrapper → `start-hyprland` exactly once; tty2 keeps a
root autologin for rescue. The offline repo is a local pacman repo generated
with `repo-add` from `pacman -Sw`, so `pacstrap -C /etc/pacman-offline.conf`
works with no network.

## Bluetooth

`shell/bluetooth/BluetoothService.qml` wraps Quickshell's native
`Quickshell.Bluetooth` singleton (`defaultAdapter`, `devices`, adapter
`enabled`/`discovering`, device `connected`, `pair()`, `forget()`). The bar has a
compact icon-only pill (hover tooltip / right-click → Settings), and Settings →
Bluetooth shows the adapter toggle, scan, device list, and an **Audio profile**
row per headset. Profiles come from `bin/aequalyn-bluetooth-audio`, which parses
`pactl list cards` for `bluez_card.*` entries and switches with
`pactl set-card-profile <card> <profile>`.

## Agent levels (from message.txt)

- **L0** — classic installer, no AI.
- **L1 (implemented)** — hardware detection + profile proposal, `install.toml`
  shown as a diff for approval, Btrfs snapshot before changes. No model in the
  ISO; cloud proposal is optional and off by default.
- **L2/L3** — first-boot wizard / permanent agent. Not in v1; `install.toml`
  and `settings.json` are designed to be their interfaces.
