---
name: aequalyn
description: Use this skill when working on the Aequalyn project (Arch Linux + Hyprland + QuickShell desktop/ISO). Covers how to install Aequalyn, create/extend bar plugins and shell modules, debug and test the shell and helpers, and build/test the live/install ISO.
---

# Aequalyn Skill

Aequalyn is an Arch Linux live/install ISO and desktop built around a **QuickShell (QML)** shell for **Hyprland 0.57+ (Lua config)** with wallpaper-driven **matugen** theming. This skill summarizes how the repo is structured and how to install, extend, debug, and build it.

## Repositories

The project is split across github.com/Aequalyn: `aequalyn` (core: bin/, config/, install.sh), `aequalyn-shell` (the `shell/` tree below), `aequalyn-themes`, `aequalyn-installer`, `aequalyn-iso`, `aequalyn-pkgs`. `aequalyn-iso-make` assembles them into the single tree described below (the layout the installer sees in `/opt/aequalyn`); paths in this file refer to that assembled tree.

## Repository layout

- `shell/` — QuickShell desktop shell (QML). Installed to `~/.config/quickshell` (and `/etc/skel/.config/quickshell` on the ISO).
  - `shell.qml` — entry point; instantiates all modules and shares `ThemeSwitcher` palette as `theme: ts.theme`.
  - `bar/` — top bar (`Bar.qml`) with **left / center / right** regions, clock (`Time.qml`), polled metrics (`SystemInfo.qml`).
  - `settings/` — `AequalynSettings.qml` (persistent singleton/config contract) and `Settings.qml` (UI). Fallback theme `AequalynDefaultTheme.qml`.
  - `docks/` (up to 16 docks), `style/` (painter, looks, ensembles), `power-menu/`, `app-launcher/`, `clipboard/`, `notifications/`, `osd/`, `idle-inhibitor/`, `wallpaper/`, `theme-switcher/`, `monitor-manager/`, `bluetooth/` — shell modules/services/panels (dock, power menu, etc.).
  - Most modules have a `DefaultTheme.qml` fallback; at runtime they receive the shared active theme.
- `config/` — user config templates installed to `~/.config` (Hyprland Lua `hyprland.lua` + modules, matugen, kitty, foot, fuzzel, qt6ct, btop, hyprlock, etc.). Shipped defaults include `config/aequalyn/settings.json`.
- `bin/` — helper scripts installed to `~/.local/bin` (and system paths on ISO): `aequalyn-theme`, `aequalyn-hypr-apply`, `aequalyn-idle`, `aequalyn-dpms`, `aequalyn-repaint`, `aequalyn-session-start`, `aequalyn-wallpaper`, `aequalyn-temperature`, `aequalyn-record`, `aequalyn-bluetooth-audio`, `aequalyn-clipboard-*`, etc.
- `assets/` — default assets (e.g. `beach.jpg` wallpaper).
- `packages/` — package lists and profiles: `base.packages`, `desktop.packages`, `aur.packages`, `profiles/*.packages`, `offline-extra.packages`, `aur-cache/` (prebuilt AUR packages for offline repo).
- `installer/` — `aequalyn-install` (TUI wizard/applier), `aequalyn-detect` (L1 hardware/profile proposal), `apply.sh`, `install.toml.example` (install contract).
- `aequalyn-iso` repo — archiso overlay and scripts: `bin/aequalyn-iso-make`, `bin/aequalyn-iso-test`, `overlay/`.
- `themes/` — folder themes (`theme.json` or `colors.toml`, `backgrounds/`, `preview.jpg`).
- `install.sh` — installs Aequalyn into a target home (or `--skel` for `/etc/skel`).
- `docs/architecture.md` — architecture notes; `README.md` — overview/keybinds/usage.
- `Aequalyn.md` (in parent workspace `` when present) — detailed change log.

## Key concepts

- **Config contract:** `~/.config/aequalyn/settings.json` is the live source of truth for shell/UI/Hyprland-related settings. `AequalynSettings.qml` loads, migrates, saves, and applies it (FileView/live reload). `install.toml` is the install-time contract (`aequalyn-install --config install.toml` applies it).
- **Hyprland 0.57 Lua:** config is `hyprland.lua` using `hl.*` API, `dofile`-ing generated modules (e.g. `monitors.lua`, `aequalyn/look.lua`, `aequalyn/colors.lua`, `aequalyn/user.lua`). `hyprctl keyword` is gone; use `hyprctl reload`, `hyprctl eval`, and Lua dispatch forms.
- **Theming:** `ThemeSwitcher` provides `ts.theme`. Wallpaper/curated themes flow through `aequalyn-theme`/matugen to generate shell palette JSON, Hyprland colors, GTK/Qt/terminal configs, etc. (see `docs/architecture.md`).
- **IPC:** modules expose `IpcHandler` targets callable via `qs ipc call <target> <function> [args]` (e.g. `bar toggle`, `launcher toggle`, `aequalyn settings`, `dock toggle|show|hide|add|settings <n>`, `power toggle|open|close`, `clipscape picker|toggle|copy|paste|pause|status`, `idle toggle`, `theme`/`wallpaper`/`monitors`/`notifications` actions as implemented).
- **Idle/power:** `bin/aequalyn-idle` generates `~/.config/aequalyn/hypridle.conf` from `settings.json` `power.*` and (re)starts `hypridle`; `aequalyn-session-start` wires session startup. DPMS/renderer helpers: `bin/aequalyn-dpms`, `bin/aequalyn-repaint` (Hyprland 0.57 `hl.dsp.*` dispatch). Caffeine inhibits idle and persists state in `~/.local/state/aequalyn/caffeine`. Power menu actions: lock/log out/reboot/shutdown.

## Install Aequalyn

### On an existing Arch + Hyprland system

1. Install runtime/build dependencies (QuickShell, Hyprland 0.57+, matugen, awww, jq, brightnessctl, playerctl, PipeWire stack, Nerd font, Qt6/GTK deps, etc.). See `packages/desktop.packages` and `README.md`.
2. From repo root:
   ```sh
   ./install.sh                 # installs shell/config/bin/assets into $HOME
   # or: ./install.sh --target /path --skel
   ```
3. Start/restart the shell and apply a theme/wallpaper:
   ```sh
   qs -n -d                     # start Aequalyn QuickShell config
   aequalyn-theme ~/Pictures/Wallpapers/beach.jpg
   ```
4. Ensure Hyprland uses Aequalyn's Lua config and session helpers as appropriate for the host (`config/hypr/hyprland.lua`, `aequalyn-session-start`, keybinds). On a host with custom Hyprland config, integrate carefully (keep changes minimal/reversible).

`install.sh` copies `shell -> ~/.config/quickshell`, `config -> ~/.config` (preserving existing where appropriate per script behavior), `bin -> ~/.local/bin`, and assets. Re-run after pulling changes to refresh installed copies.

### From the live ISO (installer)

- Boot the ISO: SDDM autologins `live` into the guarded Aequalyn Hyprland + QuickShell session. TTY2 is rescue/root per ISO setup.
- Inspect hardware/proposal (L1): `aequalyn-install --detect`
- Run installer: `sudo aequalyn-install` (or keybind shown in live session, e.g. `Super+I`) — TUI wizard builds/edits `install.toml`, shows diff, applies on approval.
- Non-interactive/apply contract: `aequalyn-install --config install.toml`
- Repair/chroot existing install: `sudo aequalyn-repair`

Installer modes: `fullwipe | dualboot | manual` on Btrfs (subvols `@ @home @log @pkg @.snapshots @var @root`), optional LUKS2, Limine bootloader, offline/online package source, profiles/extra/AUR options. See `installer/install.toml.example` and `docs/architecture.md`.

## Create and extend plugins / modules

Aequalyn has two main extension points: **top bar plugins** (reorderable/toggleable slots in `Bar.qml`) and **shell modules** (independent QML components/services/overlays).

### Add a bar plugin

Bar layout is split into **left / center / right** regions. Placement/order is persisted as `appearance.barLeft`, `appearance.barCenter`, `appearance.barRight` (with `pluginOrder` kept as a derived/compat view) and migrated from older flat configs.

1. **State/config (`shell/settings/AequalynSettings.qml`)**
   - Add a visibility flag (e.g. `property bool showMyPlugin: true`) under Appearance if it should be toggleable.
   - Add the plugin id to the appropriate default region array(s) and/or defaults, and update migration logic so existing configs gain the new plugin/flags.
   - Add a label in `pluginLabels` and map id → toggle key in `pluginToggleKey` (empty string if no toggle).
   - Include the flag in `_data().appearance`, load it in settings parsing, and persist via existing save/apply flow.
2. **UI component (`shell/bar/Bar.qml`)**
   - Implement a `Component { id: cMyPlugin ... }` using `root.theme`/`root.font` and services/helpers as needed.
   - Map the id in `componentFor(id)` → `cMyPlugin`.
   - Add any backing state, `Process`/`Timer`/service tracking, and IPC helper functions required by the plugin.
3. **Settings UI (`shell/settings/Settings.qml`)**
   - If it has a `show*` toggle mapped in `pluginToggleKey`, it will appear in Top bar “Show plugins”. Arrange plugins supports reorder within and drag between regions.
4. **Shipped defaults:** update `config/aequalyn/settings.json` (and keep live-config migrations in `AequalynSettings`).

**Notes:** apps-menu and settings buttons are draggable bar items (`appsmenu`, `settingsbutton`) with visibility toggles. Examples of built-in plugins include `title`, `caffeine`, `screenrecorder`, `power`, `bluetooth`, etc. Keep plugins self-contained, bind to `theme`, respect region placement/visibility, and avoid blocking the UI (async `Process`, timers, services).

### Add a shell module (panel/service/overlay)

1. Create `shell/<module>/Name.qml` (and optional helpers/JS/service singletons). Add a `DefaultTheme.qml` if the module should be themeable standalone.
2. Add a clear header comment explaining purpose, inputs (`theme`), IPC targets, and lifecycle.
3. Register it in `shell/shell.qml`: `import "<module>"` and instantiate `<Name> { theme: ts.theme }` inside the root `Scope` (order matters only if dependencies exist).
4. If it needs IPC, add an `IpcHandler { target: "<name>" ... }` and call via `qs ipc call <name> <fn>`.
5. If configurable, extend `AequalynSettings.qml` (properties, defaults, load/save, migrations) and `config/aequalyn/settings.json`, and add controls in `shell/settings/Settings.qml`.
6. For Wayland surfaces, use `PanelWindow`/layer shell properties appropriately; set `mask`/regions when using large transparent windows so input doesn’t block other apps.

### Helpers and integration

- Put reusable scripts in `bin/` and wire them from QML (`Process`), Hyprland binds/config, or session startup.
- Hyprland 0.57 dispatch: prefer `hyprctl dispatch 'hl.dsp....(...)'` forms compatible with the Lua config (avoid deprecated string dispatch/eval paths known to misbehave).
- Keep changes consistent with existing style and module independence.

## Debug and test

### QuickShell / UI

- Run in foreground for logs: `qs -n` (or `qs -n -d` to detach). Restart by stopping existing `qs` and relaunching.
- Inspect logs: `qs log` (if available in your environment) and runtime logs under `/run/user/$UID/quickshell/.../log.qslog`.
- QML load errors prevent the shell from starting—read the first `ERROR: Failed to load configuration` and caused-by chain.
- List/call IPC: `qs ipc show`, `qs ipc call <target> <function>`.
- Many modules register per-screen layer surfaces; inspect with `hyprctl layers` (ensure correct `HYPRLAND_INSTANCE_SIGNATURE` when running outside the session env).

### Hyprland / session

- `hyprctl monitors`, `hyprctl clients`, `hyprctl version`, `hyprctl reload`, `hyprctl layers`.
- Use 0.57-compatible dispatch/eval forms; for DPMS/renderer issues use `aequalyn-dpms` and `aequalyn-repaint`.
- Idle/power: inspect generated `~/.config/aequalyn/hypridle.conf`, run `aequalyn-idle`, and check `hypridle` process/logs. Caffeine state persists in `~/.local/state/aequalyn/caffeine`.
- Session startup: `aequalyn-session-start` (awww/qs/idle wiring). Verify PATH includes `~/.local/bin` for helpers.

### Subsystems

- **Audio/brightness/OSD:** PipeWire/WP state, `brightnessctl`, and OSD reactions.
- **Bluetooth:** `Quickshell.Bluetooth` (BlueZ D-Bus) + `bin/aequalyn-bluetooth-audio` (`pactl`) for profiles.
- **Wallpaper/theme:** `aequalyn-theme` (matugen), `aequalyn-wallpaper` (modes, transitions, live, generated), `aequalyn-themes` (folder themes), `aequalyn-settings` (jq on settings.json). State: `~/.config/quickshell/wallpaper.conf`, `~/.config/quickshell/theme.conf` (`wallpaper` | palette index | `theme:<id>`), `~/.config/aequalyn/current/theme` symlink, `~/.local/state/aequalyn/wallpaper.json`. UI: `shell/atelier/` (Atelier picker, `AtelierService`, six layouts in `layouts/`). Settings keys: `.wallpaper.*`, `.palette.*`, `.atelier.*`.
- **Window layouts:** `config/hypr/aequalyn/geometry.lua` (pure geometry, 33 layouts + catalogue), `layouts.lua` (registers `lua:aq-<id>`, slots, `promote|swapnext|swapprev|grow|shrink|reset` layout messages), `workspace-layouts.lua` (generated by `aequalyn-layout`). After editing geometry run `python3 scripts/layouts-json.py` and `python3 tests/test_layouts.py tests/test_hypr.py` (need `lupa`). Shell side: `shell/atelier/LayoutsPane.qml`, `LayoutService.qml`, `LayoutArt.qml`.
- **Clipboard:** Clipscape (`plugins/clipscape/` in the shell repo): `wl-paste --watch` helper in `plugins/clipscape/bin/clipscape`; state in `~/.local/state/aequalyn-clipscape/`.
- **Screen recording:** `bin/aequalyn-record` (`gpu-screen-recorder`), outputs to `~/Videos/Aequalyn-*.mp4`, optional `intel-media-driver`/VAAPI or NVENC. Toggled by bar plugin `screenrecorder` and keybind (e.g. `Super+Shift+R`).
- **Docks:** `shell/docks/` (up to 16, 4 per edge; apps, edge, size, auto-hide effects, the bar's look or their own), saved in `~/.config/aequalyn/docks.json` (migrated once from the `settings.json` `dock` block), set in Atelier → Docks. **Bar look:** `settings.json` `barStyle`, painted by `shell/bar/BarDecor.qml`, set in Atelier → Bar; looks and ensembles in `shell/style/AequalynLooks.js`.
- **Power menu:** `shell/power-menu/` (IPC `power`), bar plugin `power`.
- **Monitor manager:** Hyprland monitor state and Aequalyn Lua monitor persistence (`monitors.lua`).

### Testing installs/ISO

- Reinstall into `$HOME` with `./install.sh` after source changes.
- Validate `~/.config/aequalyn/settings.json` schema/migrations when changing settings.
- VM boot: `./bin/aequalyn-iso-test [path/to.iso]` (needs `qemu-full` + `edk2-ovmf`, UEFI/OVMF, KVM, virtio-gpu/net; ISO attached read-only). Env: `RAM`, `CPUS`.
- After building, sanity-check installed files, exec bits (mkarchiso can strip), default configs, keybinds, and helper availability inside the image/live system.

## Building the ISO

### Prerequisites

- Arch Linux host, run as root: `sudo ./bin/aequalyn-iso-make`
- `archiso` and `pacman-contrib` (script installs if missing), releng profile at `/usr/share/archiso/configs/releng`
- Network/mirrors as needed for package downloads (unless using cached/offline inputs)

### Build

From repo root:

```sh
sudo ./bin/aequalyn-iso-make
# common variants:
sudo env KEEP_WORK=1 ./bin/aequalyn-iso-make            # keep work/ for inspection/debug
sudo env KEEP_WORK=1 SKIP_DOWNLOAD=1 ./bin/aequalyn-iso-make  # reuse cached downloads/work inputs when possible
```

### What the build does

1. Prepares `work/profile` from releng and overlays `overlay/airootfs`.
2. Populates `/etc/skel` via `./install.sh --target <skel> --skel` (becomes live user home).
3. Copies Aequalyn source/assets into the image (e.g. `/opt/aequalyn`) and installs live helpers.
4. Assembles package lists from `packages/*.packages` and profiles, generates/bundles an offline repo (`repo-add` over cached packages, including AUR cache handling where configured), and configures pacman for offline install.
5. Runs `mkarchiso` to produce the ISO.

### Outputs and logs

- **Log:** `build.log (in aequalyn-iso)` (and any tee target you use, e.g. `/tmp/aequalyn-iso-build-*.log`).
- **Work/output dirs:** `work/profile`, `iso/work/mkarchiso-work`, `iso/work/out` (and cached package dirs) — retained when `KEEP_WORK=1`.
- **Final ISO:** copied to repo root as `aequalyn-YYYY.MM.DD-x86_64.iso` (and present under `iso/work/out/...` during/after build). Verify with `ls -lh` and `sha256sum`.
- **QEMU test:** `./bin/aequalyn-iso-test [iso-path]` (defaults to newest `aequalyn-*.iso`).

### Notes

- Build is long-running and resource-intensive (package install, squashfs, ISO creation).
- mkarchiso may normalize permissions/exec bits; verify critical scripts and shipped configs in the resulting image when making installer/session changes.
- AUR packages for the offline repo are managed via `packages/aur-cache/` and related package/profile lists—keep cache, lists, and install steps in sync when adding dependencies.

## Working tips for agents

- Prefer editing **source** under `shell/`, `config/`, `bin/`, `installer/`, `packages/`, `iso/` (not generated `iso/work` artifacts) unless debugging build output.
- Keep `AequalynSettings.qml`, `config/aequalyn/settings.json`, and UI in sync; preserve migrations for existing user configs.
- Be explicit about Hyprland 0.57 Lua semantics when changing binds/dispatch/idle behavior.
- After QML/config/helper changes, reload/restart `qs` and retest the affected IPC path and user flow; for ISO-impacting changes, rebuild and verify in QEMU/live environment.
