#!/usr/bin/env python3
"""aequalyn-lock starts one locker only. Stubbed commands: nothing is ever locked."""
import os, shutil, subprocess, tempfile, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

def run(style, reply="ok", hyprlock=False, plugin=False, held=False, works=True, times=1, slow=0):
    d = pathlib.Path(tempfile.mkdtemp())
    (d / "home/.local/bin").mkdir(parents=True); (d / "home/.config/hypr").mkdir(parents=True)
    (d / "home/.config/aequalyn").mkdir()
    (d / "home/.config/hypr/hyprlock.conf").write_text("x")
    (d / "home/.config/aequalyn/settings.json").write_text('{"power":{"lockStyle":"%s"}}' % style)
    log = d / "log"; log.touch()
    if hyprlock: (d / "hl").touch()
    if plugin: (d / "pl").touch()
    if held: (d / "held").touch()
    def stub(name, body):
        f = d / "home/.local/bin" / name; f.write_text("#!/bin/bash\n" + body + "\n"); f.chmod(0o755)
    stub("qs", f'm="${{@: -1}}"; if [[ $m == status ]]; then [[ -e {d}/pl ]] && b=true || b=false; echo "{{\\"locked\\":true,\\"requested\\":$b,\\"sessionLocked\\":$b,\\"secure\\":$b}}"; exit; fi; '
               f'echo plugin >> {log}; [[ -z "{reply}" ]] && exit 255; [[ "{reply}" == ok ]] && touch {d}/pl {d}/held; echo "{reply}"')
    stub("pgrep", f'[[ -e {d}/hl ]]')
    stub("pkill", f'rm -f {d}/hl')
    stub("hyprlock", f'echo hyprlock >> {log}; sleep {slow}; ' + (f'touch {d}/hl {d}/held; sleep 2; rm -f {d}/hl {d}/held' if works else 'exit 1'))
    stub("aequalyn-lockscreen", f'echo "design $2" >> {log}')
    stub("aequalyn-lock-wake", "true"); stub("aequalyn-lock-face", "true")
    stub("aequalyn-lock-stranded", f'[[ -e {d}/held ]]')
    env = {"HOME": str(d / "home"), "PATH": "/usr/bin", "XDG_RUNTIME_DIR": str(d)}
    procs = [subprocess.Popen(["bash", str(ROOT / "bin/aequalyn-lock"), "lock"], env=env,
                              stdout=subprocess.PIPE, text=True) for _ in range(times)]
    out = sorted(p.communicate(timeout=40)[0].strip() for p in procs)
    text = log.read_text().split("\n"); shutil.rmtree(d, ignore_errors=True)
    return out, text.count("hyprlock"), text.count("plugin"), [l for l in text if l.startswith("design")]

# custom: the plugin, never hyprlock; a design: hyprlock with it, never the plugin
assert run("custom") == (["ok"], 0, 1, [])
assert run("pill") == (["ok"], 1, 0, ["design pill"])
assert run("zen") == (["ok"], 1, 0, ["design zen"])
# slow to start (a hard disk): still hyprlock alone
assert run("pill", slow=3) == (["ok"], 1, 0, ["design pill"])
# nothing over a lock that is already there
for st in ("custom", "pill"):
    assert run(st, hyprlock=True, held=True) == (["already-locked"], 0, 0, [])
    assert run(st, plugin=True, held=True) == (["already-locked"], 0, 0, [])
# hyprlock still there after an unlock holds nothing: locks again
assert run("custom", hyprlock=True) == (["ok"], 0, 1, [])
assert run("pill", hyprlock=True) == (["ok"], 1, 0, ["design pill"])
# asked three times at once (idle, sleep and a key): one locker
for st, want in (("custom", (0, 1)), ("pill", (1, 0))):
    out, h, p, _ = run(st, times=3)
    assert (h, p) == want and out.count("already-locked") == 2, (st, out, h, p)
# the chosen one cannot: the other, so the session is not left open
assert run("pill", works=False)[:3] == (["ok"], 1, 1)
assert run("custom", reply="missing-pam") == (["fallback"], 1, 1, ["design classic"])
assert run("custom", reply="") == (["fallback"], 1, 3, ["design classic"])
assert run("custom", reply="", held=True) == (["already-locked"], 0, 3, [])
print("ok: lock")
