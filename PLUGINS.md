# Aequalyn — plugins (core side)

The core repo does not ship plugins. The plugin system lives in
[`aequalyn-shell`](https://github.com/Aequalyn/aequalyn-shell) (registry `Plugins.js`,
metadata `PluginInfo.js`, manager `PluginManager.qml`, sandbox via
`tools/watchdog/`). This document describes how the core interacts with plugins.

## Plugin roots (scanned by the shell)

- `~/.config/quickshell/plugins/` — shipped with the shell (`Plugins.js` stays as the
  built-ins' entry).
- `~/.local/share/aequalyn/plugins/` — installed by the Store.

## Install / uninstall (core helpers)

- `bin/aequalyn-store` (and the Store plugin) drives install/update/remove.
- Pipeline: clone → check files → `qmllint` → install → `qs ipc call plugins rescan`.
- `aequalyn-settings` persists `enabledPlugins` in `~/.config/aequalyn/settings.json`.

## Root gate (core side)

- `bin/aequalyn-watchdog` / `aequalyn-askpass` integrate with the shell's gate.
- Plugins declare `needsRoot` actions; the gate pins the caller via `SO_PEERCRED`.

## Plugin lifecycle notes for core maintainers

- Turning a plugin off runs `Component.onDestruction`: stop processes, give back what
  it changed, clear its host.
- Bar widgets owned by a plugin are not loaded while that plugin is off.
- See `aequalyn-shell/PLUGINS.md` for the authoring standard and `aequalyn-store`
  guidelines (`guidelines/plugin.md`) for submission rules.

## Security

See `Security.md` (plugin root access, sandbox limits, tripwire) and
`aequalyn-shell/SECURITY.md`.
