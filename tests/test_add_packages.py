#!/usr/bin/env python3
"""python3 tests/test_add_packages.py -- the installer's chosen apps, added at the first start with internet"""
import os, pathlib, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print("FAIL", what)


def run(pending, args=(), net=True, unknown="", broken="", sync=True):
    with tempfile.TemporaryDirectory() as t:
        t = pathlib.Path(t)
        (t / "bin").mkdir(); (t / "aq/packages/profiles").mkdir(parents=True)
        (t / "aq/packages/profiles/creative.packages").write_text("# art\ngimp\nkrita   # paint\n")
        if pending is not None:
            (t / "pending").write_text(pending)
        (t / "have").write_text("")
        stubs = {
            "ping": f"exit {0 if net else 1}", "pacman-key": "exit 0", "runuser": "exit 0", "sleep": "exit 0",
            "pacman": f'''echo "$*" >> {t}/calls
case "$1" in
  -Sy) exit {0 if sync else 1} ;;
  -Sp) case " {unknown} " in *" $4 "*) exit 1 ;; esac ;;
  -Su|-S) shift; for p in "$@"; do case "$p" in --*) ;; *) case " {broken} " in *" $p "*) exit 1 ;; esac ;; esac; done
          for p in "$@"; do case "$p" in --*) ;; *) echo "$p" >> {t}/have ;; esac; done ;;
  -Qq) grep -qx -- "$2" {t}/have ;;
  -Qqg) exit 1 ;;
esac'''}
        for k, v in stubs.items():
            (t / "bin" / k).write_text("#!/bin/bash\n" + v + "\n")
            (t / "bin" / k).chmod(0o755)
        r = subprocess.run(["unshare", "-r", "bash", str(ROOT / "bin/aequalyn-add-packages"), *args], capture_output=True, text=True, timeout=60,
                           env=dict(os.environ, PATH=f"{t}/bin:/usr/bin", AEQUALYN_PENDING=str(t / "pending"), AEQUALYN_ROOT=str(t / "aq")))
        left = (t / "pending").read_text().split() if (t / "pending").exists() else None
        return r.returncode, set((t / "have").read_text().split()), left, r.stdout + r.stderr


ok(run("gimp\nkrita\n")[:3] == (0, {"gimp", "krita"}, None), "all that waits is installed, once")
ok(run(None)[:3] == (0, set(), None), "nothing waiting, nothing done")
ok(run("gimp\n", net=False)[:3] == (1, set(), ["gimp"]), "without internet it stays waiting")
ok(run("gimp\n", sync=False)[:3] == (1, set(), ["gimp"]), "and when the mirrors fail")
ok(run("gimp\ngone\n", unknown="gone")[:3] == (0, {"gimp"}, None), "a name nobody knows is left out")
ok(run("gimp\nbad\nkrita\n", broken="bad")[:3] == (1, {"gimp", "krita"}, ["bad"]), "one that fails does not keep the others out, and is tried again")
ok(run("--config\n-x\nrm -rf\n;id\ngimp\n")[1] == {"gimp"}, "only package names are taken")
ok(run(None, ["--profile", "creative"])[:3] == (0, {"gimp", "krita"}, None), "a profile at any time")
ok(run(None, ["--profile", "../x"])[0] == 2 and run(None, ["--profile", "none"])[0] == 2, "no other profile")
print("add packages:", fails, "failures")
sys.exit(1 if fails else 0)
