# Aequalyn session lock

Aequalyn no longer uses hyprlock for the running session. The lock is a first-party Quickshell plugin that owns the Wayland `ext-session-lock` client and authenticates through PAM directly. Hyprland grants the protocol and dispatches keys; sudo is not involved in locking or unlocking.

For the user-facing side, see Settings → Sleep and the lock hotkey `Super + Ctrl + Shift + L`.

## Layout

| Path | Role |
| --- | --- |
| `plugins/lock/Lock.qml` | Plugin entry point; injects the live theme into the service |
| `plugins/lock/LockService.qml` | Singleton: lock state, PAM conversations, Wayland lock, IPC target `lock` |
| `plugins/lock/LockView.qml` | Blurred wallpaper, clock, password field, fingerprint glyph |
| `plugins/lock/qmldir` | Registers `LockService` as a singleton and `LockView` as a component |
| `plugins/lock/pam/` | Templates for the two `/etc/pam.d` stacks |
| `~/.local/bin/aequalyn-lock` | CLI over `qs ipc call lock …` |
| `~/.local/bin/aequalyn-lock-wake` | Restores the display after unlock |
| `~/.local/bin/aequalyn-lock-stranded` | Detects an orphaned Hyprland session lock |
| `~/.local/bin/aequalyn-sleep-lock-monitor` | Holds a logind sleep-delay inhibitor and locks before suspend |
| `~/.config/systemd/user/aequalyn-sleep-lock.service` | Runs the sleep monitor for the user session |
| `~/.local/bin/aequalyn-apply-lock` | Sudo installer for the PAM stacks |
| `~/.local/bin/aequalyn-idle` | Generates hypridle listeners that call the plugin |
| `~/.config/hypr/input.lua` | `misc.allow_session_lock_restore = true` for restart recovery |
| `~/.config/hypr/keybinds.lua` | `Super + Ctrl + Shift + L` → `aequalyn-lock lock` |
| `Plugins.js` / `PluginInfo.js` / `settings/AequalynSettings.qml` | Plugin registration, card metadata, default enablement |
| `settings/center/pages/Sleep.qml` | Power settings and the “Lock now to see it” button |

## Startup and state

`Plugins.js` loads `plugins/lock/Lock.qml` in-process. It is deliberately not sandboxed: the lock needs the Wayland session-lock protocol and the shell's shared theme. `PluginManager` injects `theme` into the entry point, which forwards it to `LockService`.

`LockService` owns `lockRequested`, the `WlSessionLock` client, the `WlSessionLockSurface`, and both `PamContext` instances. `locked` is `lockRequested || sessionLock.locked || sessionLock.secure`. A successful PAM result clears the request, releases the Wayland lock and runs `aequalyn-lock-wake`.

The plugin exposes `qs ipc call lock <function>` with `lock`, `lockForSleep`, `status`, `isLocked`, `check`, `wake` and `noteSleep`. All lock UI actions (power menu, quick panel, palette, Sleep settings, hotkey) go through `aequalyn-lock`, which is a thin wrapper over that IPC.

## Hyprland

- `Super + Ctrl + Shift + L` calls `aequalyn-lock lock` directly.
- hypridle's `lock_cmd` is `aequalyn-lock lock`; `unlock_cmd` is `aequalyn-lock wake`; `before_sleep_cmd` locks and waits for `secure` before suspend.
- Media, brightness and lid keys remain `locked = true` in `keybinds.lua`, so they work while locked.
- `misc.allow_session_lock_restore = true` lets a restarted shell re-acquire a lock left by a dead client. `aequalyn-lock-stranded` checks `hyprctl -j monitors[].solitaryBlockedBy` for `LOCK` and refuses to take over when another locker process is alive.

## PAM

Root is needed once to install two service files. The plugin itself never calls sudo; it talks to PAM in-process through `Quickshell.Services.Pam`.

```sh
sudo "$HOME/.local/bin/aequalyn-apply-lock"
aequalyn-lock check
```

`aequalyn-apply-lock` installs `/etc/pam.d/aequalyn-lock-password` from `plugins/lock/pam/aequalyn-lock-password`. The stack is:

```pam
auth  required                    pam_faillock.so preauth silent deny=10 unlock_time=120
-auth [success=2 default=ignore]  pam_systemd_home.so
auth  [success=1 default=bad]     pam_unix.so try_first_pass nullok
auth  [default=die]               pam_faillock.so authfail deny=10 unlock_time=120
auth  optional                    pam_permit.so
auth  required                    pam_env.so
auth  required                    pam_faillock.so authsucc
account include                   system-local-login
```

`pam_faillock` rate-limits guesses, `pam_systemd_home` supports encrypted homes, `pam_unix` checks the password, and `pam_permit` terminates the homed success path.

The fingerprint stack is installed only when `pam_fprintd.so`, `fprintd-list` and an enrolled print are present:

```pam
auth    required  pam_fprintd.so
account include   system-local-login
```

Fingerprint authentication is a separate `PamContext`, started automatically when the session lock becomes `secure`; the password path is started on demand when the user types. A missing password stack makes `lock()` return `missing-pam`, so the shell stays usable but will not present a lock it cannot authenticate.

## Suspend

`aequalyn-sleep-lock.service` runs `aequalyn-sleep-lock-monitor` under `systemd-inhibit --what=sleep --mode=delay`. It watches logind's `PrepareForSleep` signal and, on `true`, calls `aequalyn-lock lockForSleep` then waits up to 12 s for `status.secure`. hypridle's `before_sleep_cmd` performs the same sequence as a second line of defence.

## What changed from hyprlock

- hypridle no longer starts `hyprlock`, and no UI calls `loginctl lock-session`.
- `aequalyn-lockscreen` keeps its design templates for reference and SDDM, but `try` now locks through the plugin.
- The lock wallpaper comes from `~/.cache/aequalyn/current-wallpaper` and is blurred by `QtQuick.Effects`, rather than rendered by a hyprlock config.
- Theme changes still refresh the palette file; they no longer affect the session-lock appearance through hyprlock.

## Verification

```sh
aequalyn-lock status                 # JSON: locked, secure, pam, fingerprint, event
aequalyn-lock check                  # ok / missing-pam
sudo "$HOME/.local/bin/aequalyn-apply-lock" --status   # installed / missing for both stacks
aequalyn-lock-stranded; echo $?      # 0 stranded, 1 unlocked, 2 undetermined
systemctl --user status aequalyn-sleep-lock.service
```

Backups of the files changed during the switchover are in `~/.local/state/aequalyn/lock-switchover-<timestamp>/`, with the latest path recorded in `~/.local/state/aequalyn/lock-switchover-latest`.
