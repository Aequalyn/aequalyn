#!/usr/bin/env python3
"""python3 tests/test_keyring.py -- a keyring that opens by itself, on an automatic login only"""
import os, pathlib, stat, subprocess, sys, tempfile

BIN = pathlib.Path(__file__).resolve().parent.parent / "bin/aequalyn-keyring"
fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print("FAIL", what)


def run(service, files=(), twice=False):
    with tempfile.TemporaryDirectory() as t:
        t = pathlib.Path(t)
        (t / "bin").mkdir(); d = t / "data/keyrings"
        if files:
            d.mkdir(parents=True)
            for n, c in files:
                (d / n).write_bytes(c)
        for k, v in {"loginctl": f'[ "$1" = show-user ] && echo 3 || echo {service}', "systemctl": f"echo $* >> {t}/sys", "notify-send": f"echo x >> {t}/told"}.items():
            (t / "bin" / k).write_text("#!/bin/sh\n" + v + "\n"); (t / "bin" / k).chmod(0o755)
        env = dict(os.environ, PATH=f"{t}/bin:/usr/bin", XDG_DATA_HOME=str(t / "data"), XDG_STATE_HOME=str(t / "state"), XDG_SESSION_ID="")
        for _ in range(2 if twice else 1):
            ok(subprocess.run(["bash", str(BIN), "session"], env=env).returncode == 0, "it runs")
        got = {p.name: p.read_bytes() for p in d.glob("*")} if d.exists() else {}
        modes = {stat.S_IMODE(p.stat().st_mode) for p in d.glob("*")} | ({stat.S_IMODE(d.stat().st_mode)} if d.exists() and not files else set())
        return got, modes, (t / "told").exists() and len((t / "told").read_text().split()), (t / "sys").exists()


got, modes, told, restarted = run("sddm-autologin", twice=True)
ok(got.get("default") == b"Default_keyring" and got["Default_keyring.keyring"].startswith(b"[keyring]\ndisplay-name="), "an automatic login gets one without a password")
ok(modes == {0o600, 0o700} and restarted and not told, f"only its owner can read it, and the daemon reads it {modes}")
ok(run("sddm")[0] == {}, "a login with a password is left alone")
LOCK = (b"GnomeKeyring\n\r\0\n" + b"x" * 40)
got, _, told, _ = run("sddm-autologin", [("login.keyring", LOCK)], twice=True)
ok(got == {"login.keyring": LOCK} and told == 1, "a locked one is never touched, and said once")
ok(run("sddm-autologin", [("login.keyring", b"[keyring]\n")])[2] is False, "one without a password needs nothing")
ok(run("sddm-autologin", [("login.keyring", LOCK), ("default", b"Other"), ("Other.keyring", b"[keyring]\n")])[2] is False, "nor one that is not the default")
print("keyring:", fails, "failures")
sys.exit(1 if fails else 0)
