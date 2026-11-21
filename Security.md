# Security notes for Aequalyn

This document collects security concerns identified during a review of the
Aequalyn codebase and installer. It is intended as a working checklist for
hardening. Findings are grouped by severity.

## High

### Plugin code could reach for root on its own (addressed)

Any plugin -- sandboxed or not -- could spawn `sudo`/`pkexec` through
QuickShell's `Process`, and the shared askpass (`aequalyn-askpass`) showed a
generic "Aequalyn" password box, so a third-party plugin could ask for the
user's password looking exactly like the system asking. On machines with
passwordless sudo it was worse: no prompt at all.

Mitigation now in the tree (see `tools/watchdog/README.md`, "Root: one
gate, declared up front"):

* root actions must be **declared** in the plugin's manifest, command
  pinned, and the Store prints them before installing anything;
* the only door is `aequalyn-watchdog exec-root`, pinned to the caller by
  `SO_PEERCRED`, approved in a window that names the plugin and the exact
  command, run as `sudo -S` with the password on stdin;
* the supervisor watches every plugin's process tree for
  sudo/pkexec/su/doas outside the gate, kills the attempt, and turns the
  plugin off after three;
* `aequalyn-askpass` names the process asking for the password;
* the supervisor refuses to run as root.

Honest limits: the tripwire samples every few seconds (a fast run can slip
between samples), and same-user code can do anything the user can -- this
is explicit, audited consent, not a hard sandbox. A hard wall would need
bubblewrap/seccomp around every plugin process.

### Installed system autologins into the desktop

`/etc/sddm.conf.d/aequalyn-autologin.conf` logs the installed user in with no
password. Combined with the fact that the installer sets the same password for
the user and root, anyone who can boot an unencrypted system gets a shell as a
sudo-capable user. This is acceptable only with LUKS plus a boot password.

### Unverified update path can overwrite system code

`aequalyn-update` runs `git fetch`/`reset --hard` from GitHub, then
`sudo cp -a "$AQ_ROOT/bin/." /usr/local/bin/`. There is no signature, hash, or
allow-list check, so a compromised repo account or a TLS bypass can replace
`/usr/local/bin/aequalyn-*` and the user's dotfiles. The same concern applies
to `aequalyn-live-update`, which extracts tarballs as root into `/opt/aequalyn`.

### First-boot AUR bootstrap is unverified and automatic

`aequalyn-first-boot` clones `https://aur.archlinux.org/yay-bin.git` and runs
`makepkg -si --noconfirm`, then installs AUR packages through `yay` with
`--noconfirm`. No PKGBUILD review or signature verification is performed.

## Medium

### Offline package repository disables signatures

The bundled offline repo is configured with `SigLevel = Never`. If the ISO or
repo media is tampered with, pacman will install unverified packages. Online
installs correctly use `SigLevel = Required DatabaseOptional`.

### Password is passed as a command-line argument

`aequalyn-install` invokes `lib/apply.sh "$CONFIG" "$PASSWORD" "$LOGFILE"`, so
the password is visible in the process list during installation and may be
captured by audit tools or logs. Prefer `--password-file` with `chmod 600` and
avoid exporting `AEQUALYN_PASSWORD`.

### Arbitrary Git theme installation (supply chain)

`aequalyn-themes install <url>` clones any URL into
`~/.config/aequalyn/themes` and then triggers `qs ipc call theme reload`. There
is no verification. A malicious theme can ship executable hooks or exploit the
QML/shell side.

### Path traversal in theme removal

`aequalyn-themes remove <id>` does `rm -rf "${USER_DIR:?}/$id"` after only
checking that `$USER_DIR/$id` is a directory. An id such as `../something` can
delete files outside the user theme directory. Add strict id validation
(`^[A-Za-z0-9._-]+$`).

### Installer placeholder injection

`apply.sh` substitutes values into `setup.sh` with
`sed "s|__KEY__|${v}|g"`. Values such as hostname, timezone, disk, and cmdline
are not strictly validated or escaped, so a crafted config can inject shell lines
into the chroot setup script.

### Autologin plus optional encryption

LUKS encryption is optional and the installer does not strongly warn when it is
disabled. On a non-encrypted disk the contents are readable offline, and
autologin then gives immediate access.

## Low

### Command injection in `aequalyn-dpms`

`monitor="${2:-}"` is interpolated directly into
`hyprctl dispatch "hl.dsp.dpms({..., monitor = \"$monitor\"})"`. A monitor
name containing quotes can inject a Lua expression. Monitor names normally come
from Hyprland, so impact is low, but the value should be escaped or validated.

### QML shell strings built from palette values

`Theme.qml` interpolates colors (`t.bgSurface`, etc.) directly into
`kwriteconfig6 ... '...'` shell commands. Colors are expected to be hex, but
there is no validation. A malformed theme could break out of the quoted
argument. Sanitize to `^#[0-9A-Fa-f]{6}$`.

### Clipboard history trust

`ClipboardService.qml` pastes entries from
`~/.local/state/aequalyn/clipboard-history.json`. If that file is tampered with,
an image entry can point at an arbitrary local path and be copied as an image.
Impact is low, but untrusted local data is being fed to `wl-copy`.

### Global git config modification

`aequalyn-update` runs `git config --global --add safe.directory ...`,
mutating the user's global Git config. Minor integrity/hygiene issue.

### `aequalyn-settings` accepts arbitrary jq filters

The path argument is passed directly to `jq` as a filter. This is not shell
injection, but it allows arbitrary jq expressions. Restrict input to a validated
path grammar.

## Recommendations

1. Enable LUKS2 on any machine that leaves your desk; keep SDDM autologin only
   behind full-disk encryption.
2. Harden the update flow: pin a known Git commit/tag, verify tags with GPG or at
   least compare hashes, and never `reset --hard` from an untrusted remote
   without review. Consider disabling automatic helper overwrite
   (`sudo cp ... /usr/local/bin`).
3. Disable or gate AUR bootstrapping; require explicit user approval and show the
   PKGBUILD.
4. Re-enable signature verification for offline repos or document clearly that
   offline installs are only as trustworthy as the ISO media.
5. Pass secrets via files, not argv; chmod 600 password files; scrub logs.
6. Validate all ids and inputs in `aequalyn-themes` and installer config
   (hostname, timezone, disk, monitor names, colors).
7. Escape interpolated values in QML-generated shell commands and
   `aequalyn-dpms`.
8. Treat themes as untrusted: install from Git only from trusted sources;
   consider a checksum/manifest.